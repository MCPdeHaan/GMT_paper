setwd(normalizePath(file.path("..", ".."), mustWork = TRUE))
source("code/04_stage2_sbie.R")

library(testthat)

test_that("SBIE value combines payroll and assets at the stated rates", {
  expect_equal(
    compute_sbie_value(payroll = 200, assets = 500, sigma_w = 0.10, sigma_a = 0.08),
    60
  )
})

test_that("phi ratio is capped at one and undefined at non-positive profit", {
  expect_equal(compute_phi_ratio(sbie = 120, profit = 100), 1)
  expect_true(is.na(compute_phi_ratio(sbie = 50, profit = 0)))
})

test_that("effective floor follows the Schjelderup-style formula", {
  expect_equal(
    compute_effective_floor(topup_gap = 0.10, phi = 0.65, threshold = 0.15),
    0.085,
    tolerance = 1e-12
  )
})

test_that("SBTI overlay cannot push the effective floor below zero", {
  expect_equal(
    apply_sbti_capacity_overlay(floor_rate = 0.12, kappa = 0.03),
    0.09,
    tolerance = 1e-12
  )
  expect_equal(
    apply_sbti_capacity_overlay(floor_rate = 0.02, kappa = 0.03),
    0,
    tolerance = 1e-12
  )
})

test_that("sectoral liabilities distinguish the SBIE filter from the SBTI overlay", {
  sectors <- tibble::tibble(
    affiliate = "IRL", year = 2023L, rate_scenario = "initial",
    sectoral_profit_proxy = c(75, 25),
    average_topup_rate = 0.10, stage1_distributional_topup_rate = 0.10,
    sectoral_phi = c(0.2, 0.6), sectoral_kappa = c(0.03, 0.05)
  )
  stage1 <- tibble::tibble(
    affiliate = "IRL", year = 2023L, average_low_share = 1,
    stage1_distributional_low_share = 0.5
  )
  rates <- summarise_sectoral_sbie_rates(sectors, stage1)

  expect_equal(rates$sectoral_sbie_per_profit_average, 0.07)
  expect_equal(rates$sectoral_sbie_sbti_per_profit_average, 0.0375)
  expect_equal(rates$sectoral_sbie_per_profit_distributional, 0.035)
  expect_equal(rates$sectoral_sbie_sbti_per_profit_distributional, 0.01875)
})

test_that("BEA bridge classifier rejects weak total-asset alignment", {
  expect_equal(
    classify_bea_bridge_signal(
      measure = "total_assets",
      share_correlation = 0.150,
      mean_abs_share_gap = 0.108
    ),
    "reject_as_primary_asset_allocator"
  )
  expect_equal(
    classify_bea_bridge_signal(
      measure = "employment",
      share_correlation = 0.771,
      mean_abs_share_gap = 0.066
    ),
    "supportive_external_benchmark"
  )
})

test_that("transition rates hit the 2024 and 2033 endpoints monotonically", {
  rates <- build_transition_rates()

  expect_equal(rates$sigma_w[1], 0.10, tolerance = 1e-12)
  expect_equal(rates$sigma_w[nrow(rates)], 0.05, tolerance = 1e-12)
  expect_equal(rates$sigma_a[1], 0.08, tolerance = 1e-12)
  expect_equal(rates$sigma_a[nrow(rates)], 0.05, tolerance = 1e-12)
  expect_true(all(diff(rates$sigma_w) < 0))
  expect_true(all(diff(rates$sigma_a) < 0))
})
