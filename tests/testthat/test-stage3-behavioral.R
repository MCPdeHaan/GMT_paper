source_pipeline("05_stage3_behavioral.R")

library(testthat)

test_that("the J-test aligns fitted values by pair and year", {
  data <- tibble::as_tibble(expand.grid(pair = 1:6, year = 2017:2022)) |>
    dplyr::mutate(
      pair_id = paste0("pair", pair),
      parent = paste0("P", pair),
      affiliate = paste0("A", (pair - 1L) %% 3L),
      current = sin(pair * year),
      alternative = cos(pair * year),
      log_profit = current + alternative + sin(pair + year / 3)
    )
  fit <- fit_fe_ols(data, "alternative", "alternative")
  expected <- j_test(data, "current", fit, "current", "alternative")
  expect_equal(nrow(expected), 1L)
  order <- rev(seq_len(nrow(fit$model_data)))
  fit$model_data <- fit$model_data[order, ]
  fit$fitted_within <- fit$fitted_within[order]
  expect_identical(j_test(data, "current", fit, "current", "alternative"), expected)
  fit$model_data[2, c("pair_id", "year")] <- fit$model_data[1, c("pair_id", "year")]
  expect_error(j_test(data, "current", fit, "current", "alternative"),
    "J-test alternative fitted values")
})

test_that("Rule B retains eligible hubs and uses global activity for unsupported parents", {
  sources <- tibble(source_id = 1:2, parent = c("USA", "CHE"), affiliate = "IRL",
    year = 2023L, source_etr = 0.07, reallocated_profit = c(100, 200))
  footprint <- tibble(parent = "USA", year = 2023L,
    destination = c("NLD", "LUX", "DEU", "IRL"),
    statutory_rate = c(0.25, 0.25, 0.14, 0.20),
    destination_etr = c(0.22, 0.06, 0.20, 0.20), employees = 1, payroll = 1, upr = 1) |>
    filter(statutory_rate >= GMT_RATE)
  host <- tibble(affiliate = c("NLD", "LUX", "IRL"), year = 2023L,
    avg_etr_stage1 = c(0.22, 0.06, 0.20))
  routes <- allocate_rule_b_sources(sources, footprint, build_rule_b_global_footprint(footprint, host))
  expect_equal(routes$destination, c("NLD", "NLD"))
  expect_equal(routes$route, c("parent_activity", "global_activity"))
  expect_equal(routes$received, c(100, 200))
})

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

test_that("lower-tail ETR bands and tail-balance weights are transparent", {
  tau <- c(0.02, 0.05, 0.10, 0.16, NA_real_)
  expect_equal(
    classify_etr_tail_band(tau),
    c(
      "below_5pct", "five_to_15pct", "five_to_15pct",
      "at_or_above_15pct", "missing"
    )
  )

  tail <- c(TRUE, FALSE, FALSE, FALSE)
  weights <- tail_balance_weights(tail, target_tail_share = 0.50)

  expect_equal(mean(weights), 1, tolerance = 1e-12)
  expect_equal(weighted.mean(as.numeric(tail), weights), 0.50,
    tolerance = 1e-12
  )
  expect_equal(weights[tail], 2)
  expect_equal(unique(weights[!tail]), 2 / 3)
})

test_that("lower-tail support summaries conserve estimation rows", {
  toy <- tibble::tibble(
    pair_id = c("P1_A", "P1_A", "P2_B", "P3_C"),
    parent = c("P1", "P1", "P2", "P3"),
    affiliate = c("A", "A", "B", "C"),
    year = c(2021, 2022, 2022, 2022),
    tau = c(0.02, 0.08, 0.14, 0.18),
    analysis_profit_base = c(10, 20, 30, 40)
  )

  support <- summarise_stage3_etr_tail_support(toy)
  pooled <- support |>
    dplyr::filter(scope == "pooled")

  expect_equal(sum(pooled$rows), nrow(toy))
  expect_equal(sum(pooled$row_share), 1, tolerance = 1e-12)
  expect_equal(sum(pooled$profit_share), 1, tolerance = 1e-12)

  feasibility <- summarise_stage3_tail_reweighting_feasibility(toy)
  metric_value <- function(metric) {
    feasibility$value[feasibility$metric == metric][1]
  }

  expect_equal(metric_value("low_tail_rows"), 1)
  expect_equal(metric_value("tail_switching_pairs"), 1)
  expect_lt(metric_value("tail_balance_effective_n"), nrow(toy))
})

test_that("the historical stylised notch extinguishes liability inside the band", {
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

test_that("OECD simulated fixed-project EATR is selected and scaled", {
  etr_forward <- tibble::tibble(
    jurisdiction = c("A", "A", "A", "A", "B"),
    year = c(2017, 2018, 2018, 2018, 2017),
    measure = c("EATR", "EATR", "EMTR", "EATR", "EATR"),
    asset_type = c("BASELINE", "BASELINE", "BASELINE", "IBTI", "BASELINE"),
    etr_scenario = c("FIXED", "FIXED", "FIXED", "FIXED", "CS"),
    tax_type = c(
      "COMPOSITE", "COMPOSITE", "COMPOSITE", "COMPOSITE",
      "COMPOSITE"
    ),
    regime = c("_Z", "_Z", "_Z", "_N", "_Z"),
    value = c(25, 26, 30, 10, 40)
  )

  out <- build_simulated_tax_code_etr(etr_forward)

  expect_equal(nrow(out), 2)
  expect_equal(out$affiliate, c("A", "A"))
  expect_equal(out$affiliate_simulated_eatr_unit, c(0.25, 0.26))
})

test_that("tax instruments attach statutory lag and current simulated EATR", {
  base_panel <- tibble::tibble(
    parent = c("P1", "P1"),
    affiliate = c("A", "A"),
    year = c(2017, 2018),
    affiliate_cit_rate_unit = c(0.20, 0.21)
  )
  etr_forward <- tibble::tibble(
    jurisdiction = "A",
    year = 2018,
    measure = "EATR",
    asset_type = "BASELINE",
    etr_scenario = "FIXED",
    tax_type = "COMPOSITE",
    regime = "_Z",
    value = 24
  )

  out <- add_affiliate_tax_instruments(base_panel, etr_forward)

  expect_equal(
    out$affiliate_cit_rate_unit_lag1[out$year == 2018],
    0.20
  )
  expect_equal(
    out$affiliate_simulated_eatr_unit[out$year == 2018],
    0.24
  )
  expect_true(is.na(out$affiliate_simulated_eatr_unit[out$year == 2017]))
})

test_that("behavioural response conserves channel shares and bounds beta", {
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

  out <- add_behavioural_response(toy)

  expect_equal(out$beta_applied, 0.4)
  expect_lte(out$beta_applied, BEHAVIOURAL_MAX_REALLOCATION_SHARE)
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
  expect_equal(out$channel_substance_planning_share, 0)
  expect_equal(out$diagnostic_planning_intensity, 1)
  expect_equal(out$channel_transfer_pricing_ip_share, 0.72)
  expect_equal(out$channel_debt_share, 0.28)
})

test_that("the sectoral bridge uses same-year rates and preserves the reference fallback", {
  stage2 <- tibble::tibble(
    affiliate = "IRL", year = 2020:2023, rate_scenario = "initial",
    affiliate_is_eu27 = TRUE, analysis_profit_positive = 100,
    stage2_topup_tax_average = 10, stage2_topup_tax_distributional = 10
  )
  stage1 <- tibble::tibble(
    affiliate = "IRL", year = 2021:2023,
    average_low_share = 1, stage1_distributional_low_share = 1
  )
  sectors <- tibble::tibble(
    affiliate = "IRL", year = 2021:2023, rate_scenario = "initial",
    sectoral_profit_proxy = 100, sectoral_phi = c(0.1, 0.2, 0.3), sectoral_kappa = 0,
    average_topup_rate = 0.1, stage1_distributional_topup_rate = 0.1
  )

  bridge <- build_sectoral_factor2_bridge(stage2, stage1, sectors)
  static <- build_sectoral_factor2_bridge(stage2, stage1, sectors, use_contemporaneous = FALSE)

  expect_equal(nrow(bridge), 4L)
  expect_equal(bridge$sectoral_scale_distributional, c(0.8, 0.9, 0.8, 0.7))
  expect_equal(static$sectoral_scale_distributional, rep(0.8, 4))
  expect_equal(
    filter(summarise_sectoral_bridge_comparison(bridge), etr_measurement == "distributional")$difference,
    c(1, 0, -1)
  )
})

test_that("analytic-weight BIC agrees with the Gaussian lm likelihood", {
  data <- tibble::tibble(
    y = c(1, 4, 8, 10, 1, 4), weight = c(4, 2, 5, 1, 4, 1),
    x = c(2, 2, 1, 1, 5, 4)
  )
  fit <- fixest::feols(y ~ x, data = data, weights = ~ weight)
  expected <- stats::BIC(stats::lm(y ~ x, data = data, weights = weight))
  expect_equal(stage3_gaussian_bic(fit, data$weight), expected)
})

test_that("legal classification distinguishes an enacted Cyprus DMTT from OECD listing", {
  record <- tibble::tibble(
    jurisdiction = "SVK", jurisdiction_name = "Slovak Republic",
    rule_type = "qualified_qdmtt", effective_date = as.Date("2023-12-31"),
    table_current_as = as.Date("2026-05-01")
  )
  legal <- build_eu27_legal_regime_classification(record)
  expect_equal(nrow(legal), 27L)
  expect_setequal(legal$jurisdiction[legal$article50_iir_utpr_deferral],
    c("EST", "LTU", "LVA", "MLT", "SVK")
  )
  expect_true(legal$domestic_topup_tax_enacted[legal$jurisdiction == "CYP"])
  expect_false(legal$qdmtt_by_2026[legal$jurisdiction == "CYP"])
  expect_true(legal$qdmtt_by_2026[legal$jurisdiction == "SVK"])
  expect_false(legal$domestic_topup_tax_enacted[legal$jurisdiction == "EST"])
})

test_that("SbS exemption switches off the semi-elasticity response without QDMTT", {
  toy <- tibble::tibble(
    scenario_id = "x00011",
    rate_scenario = "initial",
    factor1_etr = "distributional",
    factor2_substance = "aggregate_sbie",
    factor3_rates = "initial",
    factor4_sbs = "sbs",
    factor5_behaviour = "behavioural",
    x1_etr = 1L,
    x2_substance = 0L,
    x3_rates = 0L,
    x4_sbs = 1L,
    x5_behaviour = 1L,
    year = 2022,
    average_low_share = 0,
    stage1_distributional_low_share = 0.8,
    stage2_excess_lowtax_profit_average = 0,
    stage2_excess_lowtax_profit_distributional = 100,
    stage1_lowtax_profit_average = 0,
    stage1_lowtax_profit_distributional = 120,
    topup_after_stage2 = 12,
    act_ip_panelai = 1,
    act_holding_panelai = 0,
    act_igf_panelai = 0,
    analysis_profit_positive = 200,
    employees_sbie = 2,
    assets_sbie = 20,
    stage2_phi = 0.1,
    affiliate_is_conduit_haven = FALSE,
    qdmtt_flag = FALSE,
    parent_iir_utpr_flag = TRUE,
    sbs_exempt = TRUE,
    static_behavioural_regime = "semi_elasticity_reallocation",
    static_beta_applied = 0.4,
    upr_panelai = 1000,
    affiliate = "IRL",
    affiliate_jurisdiction_name = "Ireland",
    affiliate_cit_rate_unit = 0.125,
    parent = "USA"
  )

  out <- add_behavioural_response(toy)

  expect_equal(out$policy_collection_exposure, 0)
  expect_equal(out$beta_applied, 0)
  expect_equal(out$topup_after_behaviour, out$topup_after_stage2)
})

test_that("behavioural design diagnostic separates baseline and structural extensions", {
  design <- build_behavioural_identification_design()

  expect_true(all(c(
    "reallocation_share", "reallocation_cap", "channel_split",
    "sesh_notch_bunching", "substance_relocation", "destination_matrix"
  ) %in% design$component))
  expect_true(any(grepl("unit interval", design$baseline_treatment)))
  expect_true(any(grepl("PPML", design$identification_status)))
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
      scenario_id = paste0(
        "x", x1_etr, x2_substance, x3_rates, x4_sbs,
        x5_behaviour
      ),
      revenue = 10 + 5 * x1_etr
    )

  effects <- compute_stage3_factorial_effects_one(toy)
  dominant <- effects |>
    arrange(desc(ss)) |>
    slice(1)

  expect_equal(dominant$effect, "x1_etr")
  expect_equal(sum(effects$eta_squared, na.rm = TRUE), 1, tolerance = 1e-12)
})
