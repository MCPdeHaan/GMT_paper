audit <- source_pipeline("diagnostics/statutory_rate_audit.R", new.env())

toy_statutory_extract <- function() {
  tibble::tribble(
    ~REF_AREA, ~TIME_PERIOD, ~MEASURE, ~SECTOR, ~TARGETING, ~OBS_VALUE, ~OBS_STATUS,
    "DEU", 2022L, "CIT", "S1311", "TA", 12, "A",
    "DEU", 2022L, "CIT", "S1311", "ST", 16, "A",
    "DEU", 2022L, "CIT_C", "S13", "ST", 30, "A",
    "DEU", 2022L, "CIT_SCG", "S13M", "ST", 14, "A",
    "DEU", 2023L, "CIT", "S1311", "ST", 17, "A",
    "DEU", 2023L, "CIT", "S1311", "TA", 10, "I",
    "FRA", 2023L, "CIT_C", "S13", "ST", 25, "A",
    "XKX", 2023L, "CIT_C", "S13", "ST", 0, "A",
    "IRL", 2023L, "CIT_C", "S13", "ST", Inf, "A",
    "IRL", 2023L, "CIT", "S1311", "ST", -1, "A"
  ) |>
    dplyr::mutate(FREQ = "A", UNIT_MEASURE = "PT_INC_TAX", UNIT_MULT = 0L,
      DIV_TREATMENT = "_Z", RATE_STRUCTURE = "_Z", TAX_BASE = "_Z")
}

test_that("rate selection preserves units, provenance and exact country-years", {
  raw <- toy_statutory_extract()
  saved <- serialize(raw, NULL)
  series <- audit$audit_rate_series(raw)
  rates <- audit$audit_rate_lookup(series,
    tibble::tibble(affiliate = c("DEU", "IRL", "XKV"), year = c(2024L, 2023L, 2023L)))
  combined <- audit$audit_select_rate(rates, "STANDARD_COMBINED")
  central <- audit$audit_select_rate(rates, "STANDARD_CENTRAL")
  targeted <- audit$audit_select_rate(rates, "LEGACY")
  explicit <- audit$audit_select_rate(rates, "EXPLICIT_FALLBACK")
  row <- function(x, code, year) x[x$affiliate == code & x$year == year, ]
  expect_identical(row(combined, "DEU", 2022)$rate, .30)
  expect_identical(row(central, "DEU", 2022)$rate, .16)
  expect_identical(row(targeted, "DEU", 2022)$rate, .12)
  expect_identical(row(rates, "DEU", 2022)$rate_standard_subcentral, .14)
  expect_identical(row(rates, "DEU", 2023)$status_targeted_central, "I")
  expect_identical(row(combined, "DEU", 2023)$rate, NA_real_)
  expect_identical(row(explicit, "DEU", 2023)$rate, .17)
  expect_identical(row(explicit, "DEU", 2023)$rate_source, "standard_central")
  expect_identical(row(targeted, "DEU", 2023)$rate, .10)
  expect_identical(row(central, "FRA", 2023)$rate, NA_real_)
  expect_identical(row(explicit, "FRA", 2023)$rate, .25)
  expect_identical(row(explicit, "IRL", 2023)$rate, NA_real_)
  expect_identical(row(explicit, "DEU", 2024)$rate_source, "missing")
  expect_identical(row(combined, "XKV", 2023)$rate, 0)
  expect_identical(row(rates, "XKV", 2023)$oecd_code_standard_combined, "XKX")
  expect_false(row(rates, "IRL", 2023)$valid_standard_combined)
  expect_false(row(rates, "IRL", 2023)$valid_standard_central)
  expect_identical(serialize(raw, NULL), saved)
  expect_error(audit$audit_rate_series(rbind(raw, raw[1L, ])), "duplicate key")
  expect_error(audit$audit_rate_series(dplyr::mutate(raw, UNIT_MULT = 3L)), "UNIT_MULT")
  suspect_alias <- raw[raw$REF_AREA == "XKX", ]
  suspect_alias$REF_AREA <- "XKV"
  expect_error(audit$audit_rate_series(rbind(raw, suspect_alias)), "duplicate key")
})

test_that("clipping uses an allowance and preserves the independent negative rule", {
  rate <- c(.12, .12, .12, NA, 0, .98)
  raw <- c(.15, .20, -.051, 1.2, -.02, 1.1)
  expect_equal(audit$audit_cap(rate), c(.17, .17, .17, 1, .05, 1))
  expect_equal(audit$audit_bilateral_mean(raw, rate), c(.15, .17, NA, 1, 0, 1))
  expect_equal(audit$audit_bilateral_mean(-.05, .30), 0)
  expect_equal(audit$audit_bilateral_mean(NA_real_, .30), NA_real_)
  expect_equal(audit$audit_bilateral_mean(.08, .05), .08)
})

test_that("a cap changes the fitted knots while retaining the observed mean and original ranks", {
  host <- tibble::tibble(affiliate = "DEU", year = 2023L, avg_etr_stage1 = .20,
    affiliate_etr_cap_stage1 = .13, q5_raw = .01, q25_raw = .08,
    q50_raw = .19, q75_raw = .4, q95_raw = 1.1)
  tight <- audit$audit_fit_host(host)
  wide <- audit$audit_fit_host(dplyr::mutate(host, affiliate_etr_cap_stage1 = .35))
  expect_equal(tight$conditioned_q95_raw, .13)
  expect_equal(wide$conditioned_q95_raw, .35)
  expect_equal(tight$alpha / (tight$alpha + tight$beta), host$avg_etr_stage1)
  expect_equal(wide$alpha / (wide$alpha + wide$beta), host$avg_etr_stage1)
  expect_true(tight$share != wide$share)
  expect_true(tight$rank_share >= .25 && tight$rank_share <= .5)
  expect_true(wide$rank_share >= .25 && wide$rank_share <= .5)
  boundary <- audit$audit_fit_host(dplyr::mutate(host, avg_etr_stage1 = 0))
  expect_identical(boundary$share, 1)
  expect_identical(boundary$rank_share, .5)
  expect_true(boundary$rank_projection)
})

test_that("lag alignment never bridges a year and recovery pricing never adds a subcentral rate", {
  rate <- tibble::tibble(affiliate = c("DEU", "DEU", "FRA"),
    year = c(2020L, 2022L, 2022L), rate = c(.29, .30, .25))
  expected <- tibble::tibble(affiliate = c("DEU", "DEU", "FRA"),
    year = c(2021L, 2023L, 2023L), lagged_rate = rate$rate)
  expect_identical(audit$audit_rate_lag(rate), expected)

  rates <- audit$audit_rate_lookup(audit$audit_rate_series(toy_statutory_extract()), rate)
  combined <- audit$audit_select_rate(rates, "STANDARD_COMBINED")
  price <- combined$rate[combined$affiliate == "DEU" & combined$year == 2022]
  destination_tax <- audit$audit_price_ordinary(100, price)
  expect_equal(destination_tax, 30)
  expect_equal(destination_tax - audit$audit_price_ordinary(100, .06), 24)
  expect_identical(audit$audit_price_ordinary(c(100, 100, 0), c(NA_real_, 0, NA_real_)),
    c(NA_real_, 0, 0))
  legacy <- tibble::tibble(jurisdiction = "DEU", year = 2022L, cit_standard = 16, cit_top_all = 12)
  expect_identical(audit$audit_recon_rate_input(rates, legacy, "LEGACY"), legacy)
  candidate <- audit$audit_recon_rate_input(rates, legacy, "STANDARD_COMBINED")
  fixture <- candidate[candidate$jurisdiction == "DEU" & candidate$year == 2022L, ]
  expect_equal(fixture$cit_standard, 30)
  expect_true(is.na(fixture$cit_top_all))
})

test_that("the diagnostic module imports without filesystem or RNG effects", {
  dir <- withr::local_tempdir()
  withr::local_dir(dir)
  before <- get0(".Random.seed", envir = globalenv(), inherits = FALSE)
  imported <- source_pipeline("diagnostics/statutory_rate_audit.R", new.env())
  expect_true(is.function(imported$run_statutory_rate_audit))
  expect_identical(list.files(dir, all.files = TRUE, no.. = TRUE), character())
  expect_identical(get0(".Random.seed", envir = globalenv(), inherits = FALSE), before)
  expect_error(imported$run_statutory_rate_audit(processed_path()), "new diagnostic output")
})

test_that("coverage weights missing rates by observed exposure rather than cell counts", {
  exposure <- tibble::tibble(affiliate = c("DEU", "FRA"), year = 2023L,
    in_production_host_panel = TRUE, rate_standard_combined = c(.30, NA_real_),
    rate_standard_central = c(.20, NA_real_), rate_targeted_central = c(.12, NA_real_),
    legacy_rate = c(.12, NA_real_), combined_minus_legacy = c(.18, NA_real_),
    positive_profit = c(900, 100), low_taxed_profit = c(25, 75), pre_sbie_topup = c(4, 6))
  totals <- audit$audit_coverage_summary(exposure)
  x <- totals[totals$scope == "EU27" & totals$window == "FY2023", ]
  expect_equal(x$host_years, 2)
  expect_equal(x$combined_missing, 1)
  expect_equal(x$profit_missing_combined / x$positive_profit, .1)
  expect_equal(x$lowtax_missing_combined / x$low_taxed_profit, .75)
  expect_equal(x$topup_missing_combined / x$pre_sbie_topup, .6)
  expect_equal(x$disparate_rates_profit, 900)
})
