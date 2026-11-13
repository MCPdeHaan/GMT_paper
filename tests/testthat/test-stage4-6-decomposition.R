source_pipeline("07_stage4_6_revenue_pipeline_decomposition.R")

library(testthat)

toy_stage4_6_design <- function() {
  tidyr::expand_grid(
    rate_scenario = c("initial", "long_run"),
    factor1_etr = c("average", "distributional"),
    factor2_substance = c("aggregate_sbie", "sectoral_sbie_sbti"),
    factor4_sbs = c("universal", "sbs"),
    factor5_behaviour = c("mechanical", "behavioural")
  ) |>
    mutate(
      factor3_rates = rate_scenario,
      x1_etr = as.integer(factor1_etr == "distributional"),
      x2_substance = as.integer(factor2_substance == "sectoral_sbie_sbti"),
      x3_rates = as.integer(rate_scenario == "long_run"),
      x4_sbs = as.integer(factor4_sbs == "sbs"),
      x5_behaviour = as.integer(factor5_behaviour == "behavioural"),
      scenario_id = paste0(
        "x", x1_etr, x2_substance, x3_rates, x4_sbs,
        x5_behaviour
      )
    )
}

test_that("Stage 4.6 factorial effects recover one active main effect", {
  toy <- toy_stage4_6_design() |>
    mutate(revenue = 10 + 5 * x1_etr)

  effects <- compute_factorial_effects_one(toy)
  dominant <- effects |>
    arrange(desc(ss)) |>
    slice(1)

  expect_equal(dominant$effect, "x1_etr")
  expect_equal(sum(effects$eta_squared, na.rm = TRUE), 1, tolerance = 1e-12)
})

test_that("Stage 4.6 main-effect directions use high minus low levels", {
  toy <- toy_stage4_6_design() |>
    mutate(revenue = 100 - 20 * x4_sbs)

  main_effects <- compute_main_effects(toy)
  sbs_effect <- main_effects |>
    filter(effect == "x4_sbs")

  expect_equal(sbs_effect$level_0, 100, tolerance = 1e-12)
  expect_equal(sbs_effect$level_1, 80, tolerance = 1e-12)
  expect_equal(sbs_effect$high_minus_low, -20, tolerance = 1e-12)
})

test_that("Stage 4.6 H4 pairing compares SbS with universal regimes", {
  toy <- toy_stage4_6_design() |>
    mutate(
      country = "NLD",
      country_name = "Netherlands",
      year = 2022,
      revenue = 100 - 10 * x4_sbs
    )

  h4_pairs <- build_h4_pairs(toy)

  expect_equal(nrow(h4_pairs), 16)
  expect_true(all(h4_pairs$delta_sbs_minus_universal == -10))
})

test_that("Stage 4.6 Shapley attribution allocates interactions exactly once", {
  toy_anova <- tibble::tibble(
    effect = c("x1_etr", "x1_etr:x4_sbs"),
    interaction_order = c(1L, 2L),
    eta_squared = c(0.4, 0.6)
  )

  shapley <- build_shapley_factor_attribution(toy_anova)

  expect_equal(sum(shapley$shapley_eta_squared), 1, tolerance = 1e-12)
  expect_equal(
    shapley$shapley_eta_squared[shapley$effect == "x1_etr"],
    0.7,
    tolerance = 1e-12
  )
  expect_equal(
    shapley$shapley_eta_squared[shapley$effect == "x4_sbs"],
    0.3,
    tolerance = 1e-12
  )
})

test_that("country imputation exposure is weighted by row-level low-taxed profit", {
  stage1_toy <- tibble::tibble(
    affiliate = c("NLD", "NLD", "NLD", "USA"),
    affiliate_jurisdiction_name = c(
      "Netherlands", "Netherlands",
      "Netherlands", "United States"
    ),
    year = c(2017L, 2019L, 2021L, 2021L),
    stage1_distributional_source = c(
      "shape_transport", "direct_t4",
      "percentile_fit", "shape_transport"
    ),
    bspi_high_tv_flag = c(FALSE, FALSE, FALSE, FALSE),
    stage1_lowtax_profit_distributional = c(30, 70, 10, 100)
  )

  exposure <- build_stage1_imputation_exposure(stage1_toy)

  expect_equal(nrow(exposure), 1)
  expect_equal(exposure$country, "NLD")
  expect_equal(exposure$high_risk_imputation_share, 40 / 110)
  expect_equal(exposure$direct_t4_lowtax_share, 70 / 110)
})

test_that("typology feature preparation imputes missing values for scaling only", {
  feature_toy <- tibble::tibble(
    country = c("A", "B", "C"),
    country_name = c("A", "B", "C"),
    preferred_revenue = c(10, 20, 30),
    scenario_spread = c(4, 5, 6),
    revenue_to_cit_1200 = c(0.1, NA, 0.3),
    revenue_to_gdp = c(0.01, 0.02, 0.03),
    revenue_per_capita = c(100, 200, 300),
    etr_measurement_main_effect = c(1, 2, 3),
    sbs_regime_main_effect = c(1, 2, 3),
    substance_specification_main_effect = c(1, 2, 3),
    behavioural_response_main_effect = c(1, 2, 3),
    qdmtt_share = c(0.2, 0.3, NA),
    residual_iir_utpr_exposure = c(0.8, 0.7, NA),
    sbs_extinguished_share = c(0.1, NA, 0.3),
    high_risk_imputation_share = c(0.2, 0.3, 0.4)
  )

  prepared <- prepare_typology_matrix(feature_toy)

  expect_true(all(is.finite(prepared$scaled)))
  expect_equal(
    unname(prepared$imputation_summary$missing_values[
      prepared$imputation_summary$feature == "revenue_to_cit_1200"
    ]),
    1
  )
})
