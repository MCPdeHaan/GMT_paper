setwd(normalizePath(file.path("..", ".."), mustWork = TRUE))
source("code/03_stage1_etr.R")

library(testthat)

test_that("percentile conditioning clamps and orders quantiles", {
  q_raw <- c(-0.2, 0.10, 0.05, 1.20, 1.40)
  q_cond <- condition_stage1_percentiles(q_raw)

  expect_equal(q_cond, c(0, 0.10, 0.10, 1, 1))
  expect_true(all(diff(q_cond) >= 0))
})

test_that("constrained beta fit recovers a known beta distribution", {
  probs <- c(0.05, 0.25, 0.50, 0.75, 0.95)
  q <- stats::qbeta(probs, 2, 8)
  fit <- fit_constrained_beta_percentiles(q, target_mean = 0.20)

  expect_equal(fit$mean, 0.20, tolerance = 1e-10)
  expect_equal(fit$alpha, 2, tolerance = 1e-4)
  expect_equal(fit$beta, 8, tolerance = 1e-4)
  expect_lt(fit$mae, 1e-5)
})

test_that("beta integrals recover the hand-worked uniform example", {
  shares <- beta_bracket_shares(alpha = 1, beta = 1)

  expect_equal(beta_mass_below(1, 1, 0.15), 0.15, tolerance = 1e-10)
  expect_equal(beta_avg_topup_rate(1, 1, 0.15), 0.075, tolerance = 1e-10)
  expect_equal(unname(shares), c(0.15, 0.05, 0.10, 0.70),
    tolerance = 1e-10
  )
  expect_equal(sum(shares), 1, tolerance = 1e-10)
})

test_that("beta boundary cases behave as degenerate distributions", {
  fit_zero <- fit_constrained_beta_percentiles(rep(0, 5), target_mean = 0)
  fit_one <- fit_constrained_beta_percentiles(rep(1, 5), target_mean = 1)

  expect_true(fit_zero$boundary_flag)
  expect_equal(
    beta_mass_below(fit_zero$alpha, fit_zero$beta, 0.15, fit_zero$mean),
    1
  )
  expect_equal(
    beta_avg_topup_rate(fit_zero$alpha, fit_zero$beta, 0.15, fit_zero$mean),
    0.15
  )
  expect_true(fit_one$boundary_flag)
  expect_equal(
    beta_mass_below(fit_one$alpha, fit_one$beta, 0.15, fit_one$mean),
    0
  )
})

test_that("direct rule handles zero-low-share partitions", {
  metrics <- direct_rule_metrics(
    low_profit = 0, low_tax = 0,
    positive_profit_total = 100
  )

  expect_equal(unname(metrics["low_share"]), 0)
  expect_equal(unname(metrics["low_mean_etr"]), 0)
  expect_equal(unname(metrics["topup_rate"]), 0)
})

test_that("percentile source selection respects the EU and fallback rules", {
  expect_equal(
    choose_percentile_affiliate_year_source(
      affiliate_is_eu27 = TRUE,
      panelai_available = TRUE,
      t_fallback_available = TRUE
    ),
    "panelai"
  )

  expect_equal(
    choose_percentile_affiliate_year_source(
      affiliate_is_eu27 = TRUE,
      panelai_available = FALSE,
      t_fallback_available = TRUE
    ),
    "missing"
  )

  expect_equal(
    choose_percentile_affiliate_year_source(
      affiliate_is_eu27 = FALSE,
      panelai_available = FALSE,
      t_fallback_available = TRUE
    ),
    "t_fallback"
  )
})
