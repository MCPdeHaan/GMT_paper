source(file.path("..", "..", "code", "05_stage3_behavioral.R"))

library(testthat)

test_that("counterfactual ratios follow the hand-worked formulas", {
  expect_equal(
    counterfactual_profit_ratio(tau = 0.05, model_spec = "linear", beta3 = -2),
    exp(-2 * 0.10),
    tolerance = 1e-12
  )

  expect_equal(
    counterfactual_profit_ratio(
      tau = 0.05,
      model_spec = "quadratic",
      beta3 = -2,
      beta4 = 4
    ),
    exp(-2 * 0.10 + 4 * (0.15^2 - 0.05^2)),
    tolerance = 1e-12
  )

  expect_equal(
    counterfactual_profit_ratio(
      tau = 0.05,
      model_spec = "logarithmic",
      beta3 = -1,
      beta4 = -0.05,
      t0 = 0.01
    ),
    exp(-1 * 0.10 - 0.05 * (log(0.16) - log(0.06))),
    tolerance = 1e-12
  )
})

test_that("counterfactual ratios are sign restricted to the unit interval", {
  expect_equal(
    counterfactual_profit_ratio(tau = 0.05, model_spec = "linear", beta3 = 2),
    1
  )
})

test_that("SESH bunching extinguishes liability inside the band", {
  in_band <- apply_behavioural_regime(tau_low = 0.14, beta_raw = 0.20, eta = 0.02)
  below_band <- apply_behavioural_regime(tau_low = 0.10, beta_raw = 0.20, eta = 0.02)
  above_floor <- apply_behavioural_regime(tau_low = NA_real_, beta_raw = 0)

  expect_equal(in_band$beta_applied, 0)
  expect_equal(in_band$behavioural_liability_filter, 0)
  expect_equal(in_band$behavioural_regime, "sesh_bunching_topup_zero")

  expect_equal(below_band$beta_applied, 0.20)
  expect_equal(below_band$behavioural_liability_filter, 0.80)
  expect_equal(below_band$behavioural_regime, "semi_elasticity_reallocation")

  expect_equal(above_floor$behavioural_liability_filter, 1)
})

test_that("affiliate statutory CIT lag is constructed by affiliate-year", {
  toy <- tibble::tibble(
    parent = c("P1", "P2", "P1", "P2", "P1", "P2"),
    affiliate = c("A", "A", "A", "A", "B", "B"),
    year = c(2016, 2016, 2017, 2017, 2016, 2017),
    affiliate_cit_rate_unit = c(0.20, 0.20, 0.21, 0.21, 0.25, 0.26)
  )

  out <- add_affiliate_cit_lag(toy)

  expect_equal(
    out$affiliate_cit_rate_unit_lag1[
      out$affiliate == "A" & out$year == 2017
    ],
    c(0.20, 0.20)
  )
  expect_true(is.na(out$affiliate_cit_rate_unit_lag1[
    out$affiliate == "B" & out$year == 2016
  ]))
  expect_equal(out$affiliate_cit_rate_unit_lag1[
    out$affiliate == "B" & out$year == 2017
  ], 0.25)
})

test_that("strategic behaviour conserves channel shares and bounds beta", {
  toy <- tibble::tibble(
    scenario_id = "x00001",
    rate_scenario = "initial",
    factor1_etr = "distributional",
    factor2_substance = "aggregate_sbie",
    factor3_rates = "initial",
    factor4_sbs = "universal",
    factor5_behaviour = "behavioural",
    x1_etr = 1L,
    x2_substance = 0L,
    x3_rates = 0L,
    x4_sbs = 0L,
    x5_behaviour = 1L,
    year = 2022,
    average_low_share = 0,
    stage1_distributional_low_share = 0.8,
    stage2_excess_lowtax_profit_average = 0,
    stage2_excess_lowtax_profit_distributional = 100,
    stage1_lowtax_profit_average = 0,
    stage1_lowtax_profit_distributional = 120,
    topup_after_stage2 = 12,
    act_ip_panelai = 5,
    act_holding_panelai = 10,
    act_igf_panelai = 0,
    analysis_profit_positive = 200,
    employees_sbie = 2,
    assets_sbie = 20,
    stage2_phi = 0.1,
    affiliate_is_conduit_haven = TRUE,
    qdmtt_flag = TRUE,
    parent_iir_utpr_flag = TRUE,
    sbs_exempt = FALSE,
    static_behavioural_regime = "semi_elasticity_reallocation",
    static_beta_applied = 0.4,
    upr_panelai = 1000,
    affiliate = "IRL",
    affiliate_jurisdiction_name = "Ireland",
    affiliate_cit_rate_unit = 0.125,
    parent = "USA"
  )

  out <- add_strategic_behaviour(toy)

  expect_lte(out$beta_applied, STRATEGIC_MAX_REALLOCATION_SHARE)
  expect_gte(out$beta_applied, 0)
  expect_equal(
    out$channel_transfer_pricing_ip_share + out$channel_debt_share +
      out$channel_substance_planning_share,
    1,
    tolerance = 1e-12
  )
  expect_equal(
    out$reallocated_profit_transfer_pricing_ip + out$reallocated_profit_debt +
      out$reallocated_profit_substance_planning,
    out$reallocated_profit,
    tolerance = 1e-12
  )
})

test_that("semi-elasticity schedule reports positive magnitudes", {
  fake_fit <- list(
    model_spec = "linear",
    t0 = NA_real_,
    coefficients = c(tau = -2),
    vcov = matrix(0.04, nrow = 1, dimnames = list("tau", "tau")),
    n = 100,
    n_pairs = 20,
    n_affiliates = 10,
    n_parents = 8
  )

  schedule <- semielasticity_schedule_one(
    fake_fit,
    tau_grid = c(0.05),
    vcov = fake_fit$vcov,
    df_inference = 9
  )

  expect_equal(schedule$semi_elasticity, 2, tolerance = 1e-12)
  expect_equal(schedule$std_error, 0.2, tolerance = 1e-12)
  expect_true(schedule$reallocation_share_to_15 > 0)
})

test_that("factorial effects recover a single active main effect", {
  toy <- tidyr::expand_grid(
    x1_etr = c(0L, 1L),
    x2_substance = c(0L, 1L),
    x3_rates = c(0L, 1L),
    x4_sbs = c(0L, 1L),
    x5_behaviour = c(0L, 1L)
  ) |>
    mutate(
      scenario_id = paste0("x", x1_etr, x2_substance, x3_rates, x4_sbs,
                           x5_behaviour),
      revenue = 10 + 5 * x1_etr
    )

  effects <- compute_factorial_effects_one(toy)
  dominant <- effects |>
    arrange(desc(ss)) |>
    slice(1)

  expect_equal(dominant$effect, "x1_etr")
  expect_equal(sum(effects$eta_squared, na.rm = TRUE), 1, tolerance = 1e-12)
})
