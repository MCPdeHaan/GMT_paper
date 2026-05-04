source(file.path("..", "..", "code", "09_stage1_measurement_error_simulation.R"))

library(testthat)
library(tibble)

test_that("measurement-error calibration centres validation residuals", {
  crossval <- tibble(
    percentile_low_share = c(0.20, 0.40, 0.60),
    direct_low_share = c(0.30, 0.35, 0.50),
    percentile_topup_rate = c(0.05, 0.08, 0.10),
    direct_topup_rate = c(0.04, 0.07, 0.12)
  )

  calibration <- calibrate_stage1_measurement_error(crossval)

  expect_equal(mean(calibration$low_share_errors), 0, tolerance = 1e-12)
  expect_equal(mean(calibration$low_mean_etr_errors), 0, tolerance = 1e-12)
  expect_equal(
    calibration$summary$value[
      calibration$summary$metric == "calibration_affiliate_years"
    ],
    3
  )
})

test_that("measurement-error draws stay inside economic support", {
  stage1_affiliate_year <- tibble(
    affiliate = c("AAA", "BBB", "CCC"),
    year = c(2020, 2020, 2020),
    stage1_positive_profit_flag = c(TRUE, TRUE, FALSE),
    stage1_distributional_low_share = c(0.05, 0.95, NA_real_),
    stage1_distributional_topup_rate = c(0.04, 0.12, NA_real_)
  )
  calibration <- list(
    low_share_errors = c(-0.20, 0.20),
    low_mean_etr_errors = c(-0.10, 0.10)
  )

  draws <- draw_stage1_measurement_error(
    stage1_affiliate_year,
    calibration,
    n_draws = 20,
    seed = 1
  )

  expect_true(all(draws$draw_low_share >= 0 & draws$draw_low_share <= 1,
                  na.rm = TRUE))
  expect_true(all(draws$draw_topup_rate >= 0 & draws$draw_topup_rate <= GMT_RATE,
                  na.rm = TRUE))
  expect_true(all(draws$draw_low_mean_etr >= 0 &
                    draws$draw_low_mean_etr <= GMT_RATE,
                  na.rm = TRUE))
  expect_true(all(is.na(draws$draw_low_share[draws$affiliate == "CCC"])))
})

test_that("Stage 2 distributional tax is recomputed from drawn Stage 1 rates", {
  stage2_bilateral <- tibble(
    parent = c("P1", "P2"),
    affiliate = c("AAA", "BBB"),
    year = c(2020, 2020),
    analysis_profit_positive = c(100, 200),
    stage2_phi = c(0.25, 0.10),
    stage2_filter = c(0.75, 0.90),
    stage1_distributional_low_share = c(0.10, 0.20),
    stage1_distributional_topup_rate = c(0.05, 0.06),
    stage1_distributional_liability_rate = c(0.005, 0.012),
    stage1_lowtax_profit_distributional = c(10, 40),
    stage1_topup_tax_distributional = c(0.5, 2.4),
    stage2_sbie_shield_distributional = c(2.5, 4),
    stage2_excess_lowtax_profit_distributional = c(7.5, 36),
    stage2_topup_tax_distributional = c(0.375, 2.16),
    stage2_effective_floor_distributional = c(0.1375, 0.144)
  )
  stage1_draw <- tibble(
    affiliate = c("AAA", "BBB"),
    year = c(2020, 2020),
    stage1_distributional_low_share = c(0.50, 0.25),
    stage1_distributional_topup_rate = c(0.10, 0.04),
    stage1_distributional_liability_rate = c(0.05, 0.01)
  )

  recomputed <- recompute_stage2_distributional(stage2_bilateral, stage1_draw)

  expect_equal(recomputed$stage1_lowtax_profit_distributional, c(50, 50))
  expect_equal(recomputed$stage1_topup_tax_distributional, c(5, 2))
  expect_equal(recomputed$stage2_topup_tax_distributional, c(3.75, 1.8))
})
