rate_environment <- new.env(parent = globalenv())
source_pipeline("05_stage3_behavioral.R", envir = rate_environment)
rates <- rate_environment

test_that("the pinned OECD keys denote three different series in fractional units", {
  raw <- tibble::tibble(
    MEASURE = c("CIT", "CIT", "CIT_C", "CIT_SCG", "CIT_C", "CIT_C"),
    SECTOR = c("S1311", "S1311", "S13", "S13M", "S13", "S13"),
    TARGETING = c("TA", "ST", "ST", "ST", "ST", "ST"),
    REF_AREA = c(rep("DEU", 4), "CYM", "FRA"),
    TIME_PERIOD = rep(2023L, 6),
    OBS_VALUE = c(15.825, 15.825, 29.94, 14.12, 0, 120),
    FREQ = "A", UNIT_MEASURE = "PT_INC_TAX", UNIT_MULT = 0,
    DIV_TREATMENT = "_Z", RATE_STRUCTURE = "_Z", TAX_BASE = "_Z",
    OBS_STATUS = "A", DATAFLOW = "OECD.CTP.TPS:DSD_TAX_CIT@DF_CIT(2.0)"
  )
  long <- rates$read_statutory_rate_observations(raw, "fixture")
  expect_identical(nrow(long), 5L)
  expect_true(all(long$input_sha256 == "fixture" & long$observation_status == "A"))
  expect_identical(long$valid[long$jurisdiction == "FRA"], FALSE)
  expect_identical(long$rate[long$jurisdiction == "FRA"], NA_real_)
  wide <- rates$statutory_rate_panel(long)
  deu <- wide[wide$jurisdiction == "DEU", ]
  expect_equal(deu$cit_targeted_central, .15825)
  expect_equal(deu$cit_standard_central, .15825)
  expect_equal(deu$cit_standard_combined, .2994)
  expect_equal(deu$cit_statistical_ceiling, .3494)
  expect_equal(deu$cit_reconciliation_prior_rate, .15825)
  expect_equal(deu$cit_destination_gate_rate, .15825)
  expect_equal(deu$cit_destination_price_rate, .2994)
  expect_identical(wide$cit_destination_price_rate[wide$jurisdiction == "CYM"], 0)
  expect_identical(wide$cit_destination_price_rate[wide$jurisdiction == "FRA"], NA_real_)
  expect_identical(wide$cit_statistical_ceiling[wide$jurisdiction == "FRA"], 1)
  expect_error(rates$read_statutory_rate_observations(rbind(raw, raw[1, ]), "fixture"),
    "Statutory-rate observations")
})

test_that("an absent statutory observation and a zero rate have different meanings", {
  selected <- rates$standard_statutory_rate(c(0, NA, NA), c(.20, .22, NA))
  expect_identical(selected$source, c("standard_combined", "standard_central_fallback", "missing"))
  expect_identical(selected$rate, c(0, .22, NA_real_))
  expect_equal(rates$statistical_etr_ceiling(selected$rate, 0), c(0, .22, 1))
  expect_equal(rates$statistical_etr_ceiling(selected$rate, .05), c(.05, .27, 1))
  expect_equal(rates$statistical_etr_ceiling(selected$rate, .10), c(.10, .32, 1))
  expect_identical(rates$statistical_etr_ceiling(.98), 1)
  expect_equal(rates$regularise_bilateral_etr(c(-.051, -.05, -.01, .31, NA, 1.5),
    c(.3, .3, .3, .3, .3, 1)), c(NA_real_, 0, 0, .3, NA_real_, 1))
  expect_identical(rates$panel_statutory_rate(
    data.frame(affiliate_cit_rate_unit = .3, affiliate_cit_robustness_rate = NA_real_),
    "robustness"), NA_real_)
})

test_that("the statutory instrument uses the exact preceding observation year", {
  panel <- tibble::tibble(affiliate = c("DEU", "DEU", "DEU", "DEU", "FRA"),
    year = c(2019L, 2021L, 2022L, 2023L, 2022L),
    affiliate_cit_rate_unit = c(.31, .32, .33, .34, .35),
    affiliate_cit_robustness_rate = c(.20, 0, NA, .23, .24))
  expect_identical(rates$add_affiliate_cit_lag(panel)$affiliate_cit_rate_unit_lag1,
    c(NA_real_, NA_real_, 0, NA_real_, NA_real_))
  expect_identical(rates$add_affiliate_cit_lag(dplyr::select(panel, -affiliate_cit_robustness_rate))$
    affiliate_cit_rate_unit_lag1, c(NA_real_, NA_real_, .32, .33, NA_real_))
})

test_that("Rule B destination gate and price can be varied independently", {
  panel <- tibble::tibble(parent = "USA", affiliate = c("DEU", "FRA"), year = 2023L,
    affiliate_cit_rate_unit = c(.20, .10),
    affiliate_cit_destination_gate_rate = c(.20, .10),
    affiliate_cit_destination_price_rate = c(.25, .30),
    etr_panelai_stage1 = c(.20, .21), employees_sbie = c(20, 10),
    payroll_sbie = c(80, 40), upr_panelai = c(100, 50))
  host <- tibble::tibble(affiliate = panel$affiliate, year = 2023L, avg_etr_stage1 = .20)
  origin <- tibble::tibble(parent = "USA", affiliate = "IRL", year = 2023L, source_id = 1L,
    source_etr = .05, reallocated_profit = 300)
  route <- function(panel) {
    footprint <- rates$build_rule_b_footprint(panel)
    rates$allocate_rule_b_sources(origin, footprint, rates$build_rule_b_global_footprint(footprint, host))
  }
  legacy <- route(panel)
  standard <- route(dplyr::mutate(panel, affiliate_cit_destination_gate_rate = c(.25, .30)))
  expect_identical(legacy$destination, "DEU")
  expect_equal(standard$received, c(200, 100))
  price <- function(routes, role) {
    joined <- rates$attach_destination_prices(routes, rates$destination_price_lookup(panel, role),
      "received")
    sum(joined$received * joined$price_rate)
  }
  expect_equal(c(price(legacy, "historical"), price(legacy, "destination_price"),
    price(standard, "historical"), price(standard, "destination_price")), c(60, 75, 50, 80))
  expect_equal(sum(standard$received * standard$source_etr), 15)
  missing <- dplyr::mutate(panel, affiliate_cit_destination_price_rate = c(.25, NA))
  expect_error(rates$attach_destination_prices(standard, rates$destination_price_lookup(missing),
    "received"), "missing for positive destination profit")
  priced <- rates$attach_destination_prices(standard, rates$destination_price_lookup(missing),
    "received", require_support = FALSE)
  expect_equal(sum(priced$received[is.na(priced$price_rate)]), 100)
})

test_that("the R09b output names the canonical statistical policy and applied response", {
  processed <- processed_path()
  meta <- rates$statutory_rate_metadata(processed)
  if (is.null(meta)) {
    expect_false(file.exists(processed_path("cit_statutory_observations.rds")))
  } else {
    expect_identical(meta$specification, "STANDARD_ROLE_SPECIFIC")
    expect_equal(meta$allowance, .05)
    expect_equal(meta$applied_preferred_beta, -1.4651183078485985)
    expect_identical(meta$reconciliation_prior, "legacy_targeted_first")
    base <- readRDS(processed_path("base_panel.rds"))
    expected_mean <- rates$regularise_bilateral_etr(base$etr_panelai_raw,
      rates$panel_statistical_ceiling(base))
    expect_identical(base$etr_panelai_stage1, expected_mean)
    expect_true(all(is.na(base$affiliate_cit_statistical_rate) ==
      (is.na(base$affiliate_cit_standard_combined) & is.na(base$affiliate_cit_standard_central))))
    numeric_alias <- dplyr::coalesce(base$affiliate_cit_top_all, base$affiliate_cit_standard) / 100
    expect_identical(base$affiliate_cit_rate_unit, numeric_alias)
    expect_identical(base$affiliate_cit_reconciliation_prior_rate, numeric_alias)
    expect_identical(sprintf("%a", rates$applied_preferred_beta(-99, processed)),
      "-0x1.7711fe50fb08p+0")
    scenarios <- readRDS(processed_path("stage4_5_allocation_source_panel.rds"))
    design <- dplyr::distinct(scenarios, scenario_id, factor1_etr)
    expect_identical(nrow(design), 32L)
    expect_equal(unname(as.integer(table(design$factor1_etr))), c(16L, 16L))
  }
})

test_that("the accounting numerator variant uses the measurement ceiling", {
  bridge <- new.env(parent = globalenv())
  source_pipeline("10_accounting_bridge_and_conduit_wedge.R", envir = bridge)
  rates <- tibble::tibble(affiliate_cit_top_all_unit = c(.12, NA, NA, .12),
    affiliate_cit_standard_unit = c(.25, .26, NA, .25),
    affiliate_cit_statistical_ceiling = c(.30, .31, NA, .30))
  cash_base <- bridge$bridge_tax(c(20, 20, 50, -7), c(40, NA, 120, -9), "T2_cash") / 100
  expect_equal(cash_base, c(.40, .20, 1.20, -.09))
  expect_equal(bridge$bridge_bilateral_etr(rates, cash_base), c(.30, .20, 1, NA_real_))
  expect_equal(bridge$bridge_bilateral_etr(dplyr::select(rates, -affiliate_cit_statistical_ceiling),
    cash_base), c(.17, .20, 1, NA_real_))
})

test_that("the prior's missing-value encoding leaves the source rate unchanged", {
  recon <- new.env(parent = globalenv())
  source_pipeline("02a_profit_reconciliation_model.R", envir = recon)
  i <- seq_len(32)
  targets <- tibble::tibble(parent = rep(c("DEU", "FRA", "IRL", "USA"), each = 8),
    year = rep(2016:2023, 4), year_factor = factor(year),
    parent_group = factor(rep(c("residual", "investment_hub"), each = 16)),
    parent_is_investment_hub = parent_group == "investment_hub",
    parent_is_conduit_haven = FALSE, parent_is_zero_tax_or_low_tax = FALSE,
    parent_is_large_upe = FALSE,
    log_domestic_profit = sin(i), log_domestic_assets = cos(i * 0.9),
    log_domestic_employees = sin(i / 2), domestic_holding_share = (i %% 5) / 10,
    parent_cit_rate_unit = c(0, NA_real_, 0.20 + cos(i[-c(1, 2)]) / 50))
  evidence <- dplyr::transmute(targets, parent, year, signal_type = "official_country_note",
    rho_signal = 0.23 + sin(i / 3) / 20, source_se = 0.06)
  historical <- recon$fit_prior_reconciliation_model(evidence, targets)
  imputed <- recon$fit_prior_reconciliation_model(evidence, targets, "mean_imputed")
  omitted <- recon$fit_prior_reconciliation_model(evidence, targets, "omit")
  expect_identical(targets$parent_cit_rate_unit[1:2], c(0, NA_real_))
  expect_identical(historical$target_prior$parent_cit_rate_unit[1:2], c(0, 0))
  expect_identical(imputed$target_prior$parent_cit_rate_unit[1], 0)
  expect_gt(imputed$target_prior$parent_cit_rate_unit[2], 0)
  expect_false("parent_cit_rate_unit" %in% names(stats::coef(omitted$fit)))
  expect_true(all(is.finite(historical$target_prior$prior_rho)))
})
