notch_env <- function() {
  env <- new.env(parent = globalenv())
  source_pipeline("diagnostics/behavioural_notch.R", env)
  env
}

notch_fixture <- function() {
  cells <- tibble::tribble(
    ~parent, ~affiliate, ~static_tau_low, ~qdmtt_flag, ~parent_iir_utpr_flag, ~sbs_exempt, ~topup_after_stage2, ~excess,
    "CAN", "DEU", .12,          TRUE,  FALSE, FALSE, 100, 4000,
    "USA", "FRA", .13,          TRUE,  FALSE, TRUE,  100, 4000,
    "FRA", "DEU", .130000001,   FALSE, TRUE,  FALSE, 100, 4000,
    "CAN", "NLD", .149999999,   FALSE, FALSE, FALSE, 100, 4000,
    "NZL", "NLD", .14,          FALSE, FALSE, FALSE, 100, 4000,
    "USA", "NLD", .14,          FALSE, TRUE,  TRUE,  100, 4000,
    "JPN", "ITA", .15,          FALSE, FALSE, FALSE,   0, 4000,
    "JPN", "IRL", .16,          FALSE, FALSE, FALSE,   0, 4000,
    "GBR", "ITA", NA_real_,     FALSE, TRUE,  FALSE,   0, NA_real_,
    "AUS", "IRL", .14,          FALSE, FALSE, FALSE,   0,    0,
    "KOR", "ESP", .11,          FALSE, TRUE,  FALSE,   0,    0
  ) |>
    dplyr::mutate(year = 2023L, scenario_id = "x10011", factor1_etr = "distributional",
      factor2_substance = "aggregate_sbie", factor3_rates = "initial", rate_scenario = "initial",
      factor4_sbs = "sbs", factor5_behaviour = "behavioural", x1_etr = 1L,
      x2_substance = 0L, x3_rates = 0L, x4_sbs = 1L, x5_behaviour = 1L,
      affiliate_jurisdiction_name = affiliate, parent_jurisdiction_name = parent,
      static_beta_raw = .2, stage2_excess_lowtax_profit_distributional = excess,
      stage2_excess_lowtax_profit_average = excess, stage1_lowtax_profit_average = excess,
      stage1_lowtax_profit_distributional = excess, stage1_distributional_low_share = 1,
      average_low_share = 1, stage2_phi = 0, act_ip_panelai = 0, act_holding_panelai = 0,
      act_igf_panelai = 0, analysis_profit_positive = 4000, employees_sbie = 0, assets_sbie = 1,
      affiliate_is_conduit_haven = FALSE)
  route <- tibble::tibble(parent = "CAN", year = 2023L, collector = "BEL", collector_name = "Belgium",
    collector_is_eu27 = TRUE, utpr_weight = 1, utpr_weight_source = "parent_year",
    collector_utpr_explicit_flag = TRUE, collector_utpr_ambiguous_flag = FALSE)
  weights <- list(parent_year_weights = route, fallback_weights = dplyr::select(route[0, ], -parent),
    policy = list(specification = "VERIFIED_PARENT_ONLY", eligible = "BEL"))
  list(cells = cells, weights = weights)
}

test_that("the original half-open threshold and the two no-notch responses are distinct", {
  env <- notch_env()
  tau <- c(.129999999, .13, .130000001, .149999999, .15, .16, NA_real_)
  baseline <- env$notch_schedule(tau, .2, "BASELINE_NOTCH")
  standard <- env$notch_schedule(tau, .2, "NO_NOTCH_STANDARD_RESPONSE")
  fixed <- env$notch_schedule(tau, .2, "NO_NOTCH_NO_BAND_RESPONSE")
  expect_equal(baseline$behavioural_liability_filter, c(.8, 0, 0, 0, 1, 1, 1))
  expect_equal(baseline$beta_applied, c(.2, 0, 0, 0, 0, 0, 0))
  expect_equal(standard$behavioural_liability_filter, c(.8, .8, .8, .8, 1, 1, 1))
  expect_equal(standard$beta_applied, c(.2, .2, .2, .2, 0, 0, 0))
  expect_equal(fixed$behavioural_liability_filter, c(.8, 1, 1, 1, 1, 1, 1))
  expect_equal(fixed$beta_applied, baseline$beta_applied)
  expect_equal(env$notch_schedule(.135, .2, "BANDWIDTH_1PP")$behavioural_liability_filter, .8)
  expect_equal(env$notch_schedule(.125, .2, "BANDWIDTH_3PP")$behavioural_liability_filter, 0)
})

test_that("the production default stays continuous at the two historical thresholds", {
  withr::local_envvar(GMT_BEHAVIOURAL_SPECIFICATION = NA)
  env <- notch_env()
  tau <- c(.129999999, .13, .14, .149999999, .15, .16, NA_real_, -Inf, Inf)
  expect_identical(env$behavioural_specification(), "NO_NOTCH_STANDARD_RESPONSE")
  expect_equal(env$behavioural_bandwidth(), 0)
  expect_equal(env$apply_behavioural_regime(tau, .2)$beta_applied, c(rep(.2, 4), rep(0, 5)))
  expect_equal(env$apply_behavioural_regime(rep(.14, 5), c(-.2, -Inf, Inf, NA, 1.2))$beta_applied,
    c(0, 0, 0, 0, 1))
  expect_false(any(env$apply_behavioural_regime(tau, .2)$behavioural_regime == "sesh_bunching_topup_zero"))
  expect_error(env$behavioural_specification("unknown"), "should be one of")

  withr::local_envvar(GMT_BEHAVIOURAL_SPECIFICATION = "BASELINE_NOTCH")
  expect_equal(env$behavioural_bandwidth(), .02)
  expect_equal(env$apply_behavioural_regime(tau, .2)$behavioural_liability_filter,
    c(.8, 0, 0, 0, rep(1, 5)))
})

test_that("notch relief, ordinary response, source liability and assigned receipts reconcile", {
  env <- notch_env()
  f <- notch_fixture()
  evaluate <- function(spec) env$notch_allocate(env$notch_response(f$cells, spec), f$weights)
  baseline <- evaluate("BASELINE_NOTCH")$source
  expect_equal(baseline$notch_relief_usd, c(0, rep(100, 5), rep(0, 5)))
  expect_equal(sum(baseline$reallocated_profit), 800)
  expect_equal(sum(baseline$assigned_usd), 80)
  standard <- evaluate("NO_NOTCH_STANDARD_RESPONSE")$source
  expect_equal(standard$topup_after_behaviour, c(rep(80, 5), 100, rep(0, 5)))
  expect_equal(standard$reallocated_profit, c(rep(800, 5), rep(0, 6)))
  expect_equal(standard$source_cit_lost_usd[2], 104)
  expect_equal(sum(standard$stage4_qdmtt_liability), 160)
  expect_equal(sum(standard$stage4_iir_liability), 80)
  expect_equal(sum(standard$stage4_utpr_pool), 160)
  expect_equal(sum(standard$assigned_usd), 320)
  expect_equal(sum(standard$unsupported_usd), 80)
  expect_equal(sum(standard$stage4_sbs_extinguished_liability), 100)
  fixed <- evaluate("NO_NOTCH_NO_BAND_RESPONSE")$source
  expect_equal(sum(fixed$assigned_usd), 380)
  expect_equal(sum(fixed$unsupported_usd), 100)
  expect_equal(fixed$reallocated_profit, baseline$reallocated_profit)
  expect_equal(fixed$notch_relief_usd, rep(0, nrow(fixed)))
  for (x in list(baseline, standard, fixed)) {
    expect_equal(x$topup_after_stage2, with(x, notch_relief_usd + response_relief_usd +
      assigned_usd + unsupported_usd + stage4_sbs_extinguished_liability))
  }
})

test_that("the transitional screen acts only on remaining liability", {
  env <- notch_env()
  f <- notch_fixture()
  tests <- f$cells |>
    dplyr::transmute(parent, affiliate, year, de_minimis = affiliate == "FRA",
      routine = FALSE, simplified = FALSE)
  evaluate <- function(spec, keep_qdmtt) {
    before <- env$notch_allocate(env$notch_response(f$cells, spec), f$weights)$source
    after <- env$bridge_apply_safe(list(source = dplyr::select(before, -unsupported)),
      tests, f$weights, keep_qdmtt)$source
    amount <- before$topup_after_behaviour - after$topup_after_behaviour
    expect_equal(before$topup_after_stage2, before$notch_relief_usd + before$response_relief_usd +
      amount + after$stage4_qdmtt_liability + after$stage4_iir_liability +
      after$stage4_utpr_pool + after$stage4_sbs_extinguished_liability)
    amount[2]
  }
  expect_equal(evaluate("BASELINE_NOTCH", FALSE), 0)
  expect_equal(evaluate("NO_NOTCH_NO_BAND_RESPONSE", FALSE), 100)
  expect_equal(evaluate("NO_NOTCH_STANDARD_RESPONSE", FALSE), 80)
  expect_equal(evaluate("NO_NOTCH_STANDARD_RESPONSE", TRUE), 0)
})

test_that("detailed and fast notch calculations agree on equivalent source keys", {
  withr::local_envvar(GMT_BEHAVIOURAL_SPECIFICATION = "BASELINE_NOTCH")
  env <- notch_env()
  f <- notch_fixture()
  rows <- dplyr::slice(f$cells, 1:6)
  n <- nrow(rows)
  gap <- .15 - rows$static_tau_low
  profit <- 100 / gap
  beta <- -2
  rows$static_beta_raw <- 1 - exp(beta * gap)
  rows$stage2_excess_lowtax_profit_distributional <- profit
  host_sum <- function(x) x
  sector <- list(host = 1L, ids = 1L, profit_share = 1, profit_share_sum = 1,
    sbie = 0, incentive = 0, reference = rep(NA_integer_, n))
  cells <- dplyr::mutate(rows, host_id = seq_len(n))
  universal <- dplyr::mutate(rows, sbs_exempt = FALSE)
  input <- list(cells = cells, host = cells, host_sum = host_sum, beta = beta,
    sector = list(sector, sector), sbie = matrix(0, n, 2),
    routes = list(env$step15_route(universal, f$weights), env$step15_route(rows, f$weights)))
  measure <- list(profit = profit, average = list(share = rep(1, n), gap = gap),
    distributional = list(share = rep(1, n), gap = gap))
  for (spec in env$NOTCH_ARMS) {
    engine <- notch_env()
    if (spec != "BASELINE_NOTCH") {
      original <- env$notch_schedule
      engine$apply_behavioural_regime <- function(tau_low, beta_raw) original(tau_low, beta_raw, spec)
    }
    fast <- env$notch_fast_source(engine, input, measure)
    dense <- env$notch_response(rows, spec)$topup_after_behaviour
    expect_equal(unname(fast[, "x10011"]), dense, tolerance = 1e-12)
    expect_equal(unname(fast[, "x10010"]), rep(100, n), tolerance = 1e-12)
  }

  design <- env$step15_design(TRUE)
  expect_equal(nrow(design), 64L)
  expect_equal(nrow(dplyr::distinct(design, scenario_id)), 64L)
  expect_setequal(substring(design$scenario_id[design$x6_accounting == 1], 1, 6),
    env$step15_design()$scenario_id)
})

test_that("legal commencement and numerical band membership answer different questions", {
  env <- notch_env()
  starts <- as.Date(c("2025-12-30", "2026-01-01", "2026-01-01", "2026-01-01",
    "2026-01-01", "2026-01-01", "2026-01-01", "2026-01-01", "2026-12-31", "2027-01-01"))
  expect_identical(env$sesh_start_available(starts,
    c(TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, NA, FALSE, FALSE),
    c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, NA, FALSE, FALSE, FALSE),
    c(1L, 1L, 3L, 1L, 3L, 3L, 3L, 1L, 3L, 3L),
    c(TRUE, TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE)),
    c(FALSE, FALSE, TRUE, TRUE, TRUE, FALSE, NA, NA, TRUE, TRUE))
  f <- notch_fixture()
  exposure <- env$notch_exposure(f$cells, .02, "fixture")
  expect_equal(dplyr::filter(exposure, window == "FY2023", source_area == "Global")$post_sbie_usd, 500)
  missing <- f$cells
  missing$stage1_lowtax_profit_distributional[c(2L, 10L)] <- c(NA, 0)
  candidates <- env$notch_exposure(missing, .02, "fixture") |>
    dplyr::filter(window == "FY2023", source_area == "Global")
  expect_equal(c(candidates$positive_lowtax_profit_rows, candidates$zero_lowtax_profit_rows,
    candidates$missing_lowtax_profit_rows), c(4, 1, 1))
  expect_false(any(grepl("elect|legally_eligible", names(exposure))))
  expect_equal(dplyr::filter(env$notch_exposure(f$cells, 0, "fixture"), window == "FY2023")$rows, 0)
})

test_that("the replay schedule selects one row per affiliate-year, measurement and model", {
  e <- notch_env()
  marker <- processed_path("diagnostics", e$BEHAVIOURAL_SPECIFICATION_FILE)
  continuous <- file.exists(marker)
  if (continuous) {
    active <- read.csv(marker)
    expect_identical(active$specification, "NO_NOTCH_STANDARD_RESPONSE")
    expect_equal(active$bandwidth, 0)
  }
  schedule <- readRDS(processed_path("stage3_behavioral_affiliate_year.rds"))
  expect_setequal(unique(schedule$eta), if (continuous) c(0, .01, .02, .03) else c(.01, .02, .03))
  for (width in unique(schedule$eta)) {
    selected <- subset(schedule, eta == width)
    expect_equal(anyDuplicated(selected[c("affiliate", "year", "etr_measurement", "model_spec")]), 0L)
  }
  band <- schedule$tau_low >= .13 & schedule$tau_low < .15 & !is.na(schedule$tau_low)
  expect_true(all(schedule$behavioural_regime[schedule$eta == .02 & band] == "sesh_bunching_topup_zero"))
  if (continuous) {
    expect_true(all(schedule$behavioural_regime[schedule$eta == 0 & band] == "semi_elasticity_reallocation"))
    e <- new.env(parent = globalenv())
    source_pipeline("diagnostics/behavioural_specification_comparison.R", e)
    parity <- e$behavioural_point_acceptance(processed_path(),
      repo_path("data", "diagnostics", "r06a_behavioural_notch"))
    expect_lt(max(parity$max_absolute_gap_usd), 1e-3)
  }
})
