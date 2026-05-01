source(file.path("..", "..", "code", "04_stage2_sbie.R"))

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

test_that("transition rates hit the 2024 and 2033 endpoints monotonically", {
  rates <- build_transition_rates()

  expect_equal(rates$sigma_w[1], 0.10, tolerance = 1e-12)
  expect_equal(rates$sigma_w[nrow(rates)], 0.05, tolerance = 1e-12)
  expect_equal(rates$sigma_a[1], 0.08, tolerance = 1e-12)
  expect_equal(rates$sigma_a[nrow(rates)], 0.05, tolerance = 1e-12)
  expect_true(all(diff(rates$sigma_w) < 0))
  expect_true(all(diff(rates$sigma_a) < 0))
})
