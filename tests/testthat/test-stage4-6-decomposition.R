source(file.path("..", "..", "code",
                 "07_stage4_6_revenue_pipeline_decomposition.R"))

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
      scenario_id = paste0("x", x1_etr, x2_substance, x3_rates, x4_sbs,
                           x5_behaviour)
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
