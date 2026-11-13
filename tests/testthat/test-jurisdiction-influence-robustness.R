source_pipeline("11_policy_game_and_variance_extensions.R")

library(testthat)

test_that("Stage 1 liability summaries are profit weighted by scope", {
  toy <- tibble::tibble(
    parent = c("USA", "DEU", "USA"),
    affiliate = c("NLD", "IRL", "CHE"),
    year = c(2022, 2022, 2022),
    stage1_positive_profit_flag = c(TRUE, TRUE, TRUE),
    affiliate_is_eu27 = c(TRUE, TRUE, FALSE),
    analysis_profit_positive = c(100, 300, 600),
    stage1_topup_tax_average = c(5, 6, 9),
    stage1_topup_tax_distributional = c(10, 30, 60)
  )

  out <- summarise_stage1_liability(toy, "baseline")

  expect_equal(
    out$distributional_liability_rate[out$scope == "global"],
    0.10
  )
  expect_equal(
    out$distributional_liability_rate[out$scope == "eu27"],
    0.10
  )
  expect_equal(out$pair_years[out$scope == "eu27"], 2)
})

test_that("Influence target selection keeps named and high-leverage cases", {
  stage1 <- tibble::tibble(
    parent = c("USA", "DEU", "GBR", "GBR"),
    affiliate = c("NLD", "IRL", "SGP", "CAN"),
    parent_jurisdiction_name = c(
      "United States", "Germany", "United Kingdom",
      "United Kingdom"
    ),
    affiliate_jurisdiction_name = c(
      "Netherlands", "Ireland", "Singapore",
      "Canada"
    ),
    year = 2022,
    stage1_positive_profit_flag = TRUE,
    analysis_profit_positive = c(100, 50, 500, 25),
    stage1_topup_tax_distributional = c(10, 5, 50, 2)
  )
  estimation_sample <- tibble::tibble(
    parent = c("USA", "DEU", "GBR"),
    affiliate = c("NLD", "IRL", "SGP")
  )
  lookup <- build_jurisdiction_lookup(stage1, stage1)

  targets <- build_influence_targets(stage1, estimation_sample, lookup, top_n = 1)

  expect_true(any(targets$leave_dimension == "parent" &
    targets$jurisdiction == "USA"))
  expect_true(any(targets$leave_dimension == "affiliate" &
    targets$jurisdiction == "SGP"))
  expect_true(any(str_detect(targets$target_reason, "high_leverage")))
})

test_that("Leave-one filtering removes only the requested dimension", {
  toy <- tibble::tibble(
    parent = c("USA", "USA", "DEU"),
    affiliate = c("NLD", "IRL", "NLD"),
    value = 1:3
  )

  parent_drop <- filter_leave_one(toy, "parent", "USA")
  affiliate_drop <- filter_leave_one(toy, "affiliate", "NLD")

  expect_equal(parent_drop$value, 3)
  expect_equal(affiliate_drop$value, 2)
})
