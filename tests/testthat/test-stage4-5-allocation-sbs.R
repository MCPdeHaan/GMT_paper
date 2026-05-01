source(file.path("..", "..", "code", "06_stage4_5_revenue_allocation_sbs.R"))

library(testthat)

test_that("UTPR raw weights follow the equal employee and asset rule", {
  expect_equal(
    compute_utpr_raw_weight(employee_share = 0.40, asset_share = 0.20),
    0.30,
    tolerance = 1e-12
  )
  expect_equal(
    compute_utpr_raw_weight(employee_share = 0.40, asset_share = NA_real_),
    0.40,
    tolerance = 1e-12
  )
  expect_equal(
    compute_utpr_raw_weight(employee_share = NA_real_, asset_share = 0.20),
    0.20,
    tolerance = 1e-12
  )
  expect_true(is.na(
    compute_utpr_raw_weight(employee_share = NA_real_, asset_share = NA_real_)
  ))
})

test_that("allocation regime follows the QDMTT, IIR, UTPR, SbS order", {
  expect_equal(
    allocation_regime(
      topup_after_behaviour = 100,
      qdmtt_flag = TRUE,
      parent_iir_utpr_flag = TRUE,
      sbs_exempt = TRUE
    ),
    "qdmtt"
  )
  expect_equal(
    allocation_regime(
      topup_after_behaviour = 100,
      qdmtt_flag = FALSE,
      parent_iir_utpr_flag = TRUE,
      sbs_exempt = FALSE
    ),
    "iir"
  )
  expect_equal(
    allocation_regime(
      topup_after_behaviour = 100,
      qdmtt_flag = FALSE,
      parent_iir_utpr_flag = FALSE,
      sbs_exempt = FALSE
    ),
    "utpr"
  )
  expect_equal(
    allocation_regime(
      topup_after_behaviour = 100,
      qdmtt_flag = FALSE,
      parent_iir_utpr_flag = FALSE,
      sbs_exempt = TRUE
    ),
    "sbs_extinguished"
  )
  expect_equal(
    allocation_regime(
      topup_after_behaviour = 0,
      qdmtt_flag = FALSE,
      parent_iir_utpr_flag = FALSE,
      sbs_exempt = TRUE
    ),
    "zero"
  )
})

test_that("positive weights normalise exactly when a UTPR pool exists", {
  weights <- normalise_positive_weights(c(0.2, 0.3, 0.5))

  expect_equal(sum(weights), 1, tolerance = 1e-12)
  expect_equal(weights, c(0.2, 0.3, 0.5), tolerance = 1e-12)
  expect_true(all(is.na(normalise_positive_weights(c(0, 0, NA)))))
})
