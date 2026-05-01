source(file.path("..", "..", "code", "03_stage1_etr.R"))

library(testthat)

test_that("percentile conditioning clamps and orders quantiles", {
  q_raw <- c(-0.2, 0.10, 0.05, 1.20, 1.40)
  q_cond <- condition_stage1_percentiles(q_raw)

  expect_equal(q_cond, c(0, 0.10, 0.10, 1, 1))
  expect_true(all(diff(q_cond) >= 0))
})

test_that("shift solver matches the target mean after bounds", {
  q_cond <- condition_stage1_percentiles(c(0.05, 0.15, 0.25, 0.35, 0.45))
  shift <- solve_percentile_shift(q_cond, 0.20)
  q_shift <- apply_percentile_shift(q_cond, shift)

  expect_equal(mixture_mean_from_quantiles(q_shift), 0.20, tolerance = 1e-10)
})

test_that("mixture integrals recover the hand-worked example", {
  q <- c(0.05, 0.15, 0.25, 0.35, 0.45)

  expect_equal(mixture_mass_below(q, 0.15), 0.25, tolerance = 1e-10)
  expect_equal(mixture_avg_topup_rate(q, 0.15), 0.065, tolerance = 1e-10)
  expect_equal(sum(mixture_bracket_shares(q)), 1, tolerance = 1e-10)
})

test_that("direct rule handles zero-low-share partitions", {
  metrics <- direct_rule_metrics(low_profit = 0, low_tax = 0,
                                 positive_profit_total = 100)

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
