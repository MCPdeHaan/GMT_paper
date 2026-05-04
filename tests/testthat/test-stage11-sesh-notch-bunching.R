source(file.path("..", "..", "code", "11_sesh_notch_bunching_diagnostic.R"))

library(testthat)
library(tibble)

test_that("ETR density bins conserve weighted mass", {
  bins <- build_etr_density_bins(
    etr = c(0.01, 0.012, 0.151, 0.29),
    weight = c(1, 3, 2, 4),
    bin_width = 0.01,
    lower = 0,
    upper = 0.30
  )

  expect_equal(sum(bins$observed_weight), 10)
  expect_equal(sum(bins$observed_share), 1, tolerance = 1e-12)
  expect_equal(sum(bins$observed_count), 4)
})

test_that("counterfactual density is non-negative and normalised", {
  bins <- build_etr_density_bins(
    etr = seq(0.01, 0.29, by = 0.01),
    weight = rep(1, 29),
    bin_width = 0.01,
    lower = 0,
    upper = 0.30
  )

  fitted <- fit_notch_counterfactual_density(
    bins,
    threshold = 0.15,
    excluded_bandwidth = 0.02,
    polynomial_order = 3
  )

  expect_true(all(fitted$counterfactual_share >= 0, na.rm = TRUE))
  expect_equal(
    sum(fitted$counterfactual_share, na.rm = TRUE),
    sum(fitted$observed_share, na.rm = TRUE),
    tolerance = 1e-12
  )
})

test_that("notch summary separates missing and excess mass", {
  fitted <- tibble(
    bin_lower = c(0.12, 0.13, 0.14, 0.15, 0.16),
    bin_upper = c(0.13, 0.14, 0.15, 0.16, 0.17),
    observed_share = c(0.10, 0.02, 0.02, 0.20, 0.10),
    counterfactual_share = c(0.10, 0.08, 0.08, 0.08, 0.10)
  )

  summary <- summarise_notch_counterfactual(
    fitted,
    threshold = 0.15,
    bunching_bandwidth = 0.02
  )

  expect_equal(summary$placebo_missing_mass, 0.12, tolerance = 1e-12)
  expect_equal(summary$placebo_excess_mass, 0.12, tolerance = 1e-12)
  expect_equal(
    summary$implied_responsive_share_if_post_reform,
    0.75,
    tolerance = 1e-12
  )
})

test_that("distance-based bunching probability respects the SESH band", {
  p <- notch_bunching_probability(
    etr = c(0.12, 0.13, 0.14, 0.149, 0.15, NA_real_),
    threshold = 0.15,
    bunching_bandwidth = 0.02,
    responsive_share = 0.8
  )

  expect_equal(p[1], 0)
  expect_equal(p[2], 0)
  expect_equal(p[3], 0.4, tolerance = 1e-12)
  expect_gt(p[4], p[3])
  expect_equal(p[5], 0)
  expect_equal(p[6], 0)
})
