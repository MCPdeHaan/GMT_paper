response_methods <- source_pipeline("behaviour/response_kernel.R", new.env())

test_that("the original response law integrates all three signed slopes and bounds relocation", {
  e <- response_methods
  expect_equal(e$compute_reallocation_share(.05, "linear", -2), 1 - exp(-.2))
  expect_equal(e$compute_reallocation_share(.05, "quadratic", -2, 1), 1 - exp(-.2 + .02))
  expect_equal(e$compute_reallocation_share(.05, "logarithmic", -2, -.1, .1),
    1 - exp(-.2 - .1 * log(.25 / .15)))
  tau <- c(.13 - 1e-10, .13, .14, .15 - 1e-10, .15, .16, NA, Inf, -Inf)
  raw <- e$compute_reallocation_share(tau, rep("linear", length(tau)), -2)
  leading <- e$apply_behavioural_regime(tau, raw,
    eta = e$behavioural_bandwidth("NO_NOTCH_STANDARD_RESPONSE"))
  historical <- e$apply_behavioural_regime(tau, raw,
    eta = e$behavioural_bandwidth("BASELINE_NOTCH"))
  expect_equal(leading$beta_applied, c(1 - exp(-2 * (.15 - tau[1:4])), rep(0, 5)))
  expect_equal(historical$beta_applied, c(raw[1], rep(0, 8)))
  expect_equal(historical$behavioural_liability_filter, c(1 - raw[1], rep(0, 3), rep(1, 5)))
  expect_equal(e$apply_behavioural_regime(rep(.1, 5), c(NA, Inf, -Inf, -.1, 1.1), eta = 0)$beta_applied,
    c(0, 0, 0, 0, 1))
  expect_equal(e$compute_reallocation_share(.1, "linear", 2), 0)
  expect_true(is.na(e$compute_reallocation_share(.1, "linear", NA_real_)))
  # The original exponent maps a negative infinite slope at a positive gap to full movement.
  expect_equal(e$compute_reallocation_share(.1, "linear", -Inf), 1)
})

test_that("positive legal exposure and supported collection are separate source contracts", {
  e <- response_methods
  allocator <- source_pipeline("06_stage4_5_revenue_allocation_sbs.R", new.env())
  panel <- tibble::tibble(scenario_id = "x10011", year = 2022L,
    parent = c("USA", "USA", "DEU", "BRA", "BRA", "BRA", "BRA"),
    affiliate = c("IRL", "NLD", "SGP", "ARG", "BEN", "CIV", "NGA"),
    factor1_etr = "distributional", factor5_behaviour = "behavioural",
    average_low_share = 0, stage1_distributional_low_share = .6,
    stage2_excess_lowtax_profit_average = 0,
    stage2_excess_lowtax_profit_distributional = c(100, 100, 100, 100, 0, 100, 100),
    stage1_lowtax_profit_average = 0, stage1_lowtax_profit_distributional = 120,
    topup_after_stage2 = c(12, 12, 12, 12, 12, 0, 12),
    act_ip_panelai = 1, act_holding_panelai = 0, act_igf_panelai = 0,
    analysis_profit_positive = 200, employees_sbie = 2, assets_sbie = 20,
    stage2_phi = .1, affiliate_is_conduit_haven = FALSE,
    qdmtt_flag = c(TRUE, rep(FALSE, 6)), sbs_exempt = c(TRUE, TRUE, rep(FALSE, 5)),
    parent_iir_utpr_flag = c(FALSE, FALSE, TRUE, rep(FALSE, 4)))
  out <- e$replace_behaviour_schedule(panel, c(rep(.1, 6), NA), rep(.25, 7))
  expect_equal(out$reallocated_profit, c(25, 0, 25, 25, 0, 0, 0))
  expect_equal(out$topup_after_behaviour, c(9, 12, 9, 9, 12, 0, 12))
  expect_equal(out$topup_after_behaviour + out$behavioural_avoided_topup, panel$topup_after_stage2)
  routes <- allocator$build_source_panel(out)
  expect_equal(routes$stage4_qdmtt_liability, c(9, rep(0, 6)))
  expect_equal(routes$stage4_iir_liability, c(0, 0, 9, rep(0, 4)))
  expect_equal(routes$stage4_sbs_extinguished_liability, c(0, 12, rep(0, 5)))
  expect_equal(routes$stage4_utpr_pool, c(0, 0, 0, 9, 12, 0, 12))
  expect_equal(routes$stage4_conservation_gap, rep(0, 7))
  routed <- dplyr::mutate(routes, rate_scenario = "initial", factor2_substance = "aggregate_sbie",
    factor3_rates = "initial", factor4_sbs = "sbs",
    x1_etr = 1L, x2_substance = 0L, x3_rates = 0L, x4_sbs = 1L, x5_behaviour = 1L,
    affiliate_jurisdiction_name = affiliate, parent_jurisdiction_name = parent)
  weights <- tibble::tibble(parent = "CAN", year = 2022L, collector = "FRA",
    collector_name = "FRA", collector_is_eu27 = TRUE, utpr_weight = 1,
    utpr_weight_source = "parent_year", collector_utpr_explicit_flag = TRUE,
    collector_utpr_ambiguous_flag = FALSE)
  receipts <- allocator$allocate_stage4_revenue(routed, list(parent_year_weights = weights,
    fallback_weights = dplyr::select(weights[0, ], -parent),
    policy = list(specification = "VERIFIED_PARENT_ONLY", eligible = "FRA")))
  expect_equal(receipts$unsupported_utpr$unsupported_utpr, 33)
  expect_equal(sum(receipts$revenue_by_channel_global$revenue), 18)
  expect_equal(allocator$build_conservation_diagnostics(routed,
    receipts$revenue_by_channel_global, receipts$unsupported_utpr)$residual_gap, 0)
})
