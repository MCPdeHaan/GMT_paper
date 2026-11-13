setwd(normalizePath(file.path("..", ".."), mustWork = TRUE))
source("code/03_stage1_etr.R")

library(testthat)

test_that("percentile conditioning clamps and orders quantiles", {
  q_raw <- c(-0.2, 0.10, 0.05, 1.20, 1.40)
  q_cond <- condition_stage1_percentiles(q_raw)

  expect_equal(q_cond, c(0, 0.10, 0.10, 1, 1))
  expect_true(all(diff(q_cond) >= 0))
  expect_equal(condition_stage1_percentiles(q_raw, upper_cap = 0.25),
    c(0, 0.10, 0.10, 0.25, 0.25))
})

test_that("statutory-cap and rank-bounded fits preserve the mean anchor", {
  q <- c(0.0053, 0.1087, 0.2435, 0.3748, 1.2253)
  target <- 0.20825
  legacy <- fit_constrained_beta_percentiles(q, target)
  capped <- fit_constrained_beta_percentiles(q, target, upper_cap = target)
  rank <- stage1_fit_cell(q, target, target, STAGE1_BETA_MODELS[3])
  expect_equal(capped$mean, target)
  expect_lt(beta_mass_below(capped$alpha, capped$beta), beta_mass_below(legacy$alpha, legacy$beta))
  expect_equal(rank$target_mean, target)
  expect_gte(rank$share, 0.25)
  expect_lte(rank$share, 0.50)
  expect_false(rank$rank_violation)
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

test_that("beta quantiles invert the CDF for very small shape parameters", {
  alpha <- 5e-6
  beta <- 9.5e-5
  x <- c(0.12, 0.50, 0.87)
  probs <- stats::pbeta(x, alpha, beta)

  expect_equal(beta_quantiles(probs, alpha, beta), x, tolerance = 1e-8)
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

test_that("bilateral Table IV requires numeric support above and below 15 per cent", {
  brackets <- tibble::tibble(
    parent = rep(c("USA", "JPN", "ESP", "GRC"), each = 2),
    affiliate = "IRL",
    year = 2023L,
    etr_bracket = rep(c("rate_0_15", "rate_15"), 4),
    profit = c(60, 40, 60, NA, 60, 40, 0, 40),
    tax_accrued = c(3, 8, 3, NA, NA, 8, NA, 8)
  )
  results <- summarise_observed_t4(brackets, c("parent", "affiliate", "year"))

  expect_setequal(results$parent[results$t4_available], c("USA", "GRC"))
  expect_equal(results$direct_low_share[results$parent == "USA"], 0.6)
  expect_equal(results$direct_topup_rate[results$parent == "USA"], 0.10)
  expect_equal(results$direct_low_share[results$parent == "GRC"], 0)
  expect_equal(results$direct_topup_rate[results$parent == "GRC"], 0)
})

test_that("parent-restricted cross-validation uses the intersection in both tables", {
  brackets <- tibble::tibble(
    parent = rep(c("USA", "JPN"), each = 2),
    affiliate = "IRL",
    year = 2023L,
    etr_bracket = rep(c("rate_0_15", "rate_15"), 2),
    profit = c(60, 40, 10, 90),
    tax_accrued = c(3, 8, 1, 27)
  )
  panel <- tibble::tibble(
    parent = c("USA", "ESP"),
    affiliate = "IRL",
    year = 2023L,
    affiliate_is_eu27 = TRUE,
    has_panelai_percentiles = TRUE,
    analysis_profit_base = 100,
    t4_low_profit = NA_real_,
    etr_panelai_reg = c(0.2, 0.5),
    tax_accrued_panelai = c(20, 50),
    affiliate_cit_rate_unit = 0.25,
    subgroups_count_panelai = c(1, 99),
    entities_count_panelai = NA_real_,
    subgroups_count = NA_real_,
    entities_count = NA_real_,
    etr_p5_panelai = c(0.02, 0.22),
    etr_p25_panelai = c(0.08, 0.28),
    etr_p50_panelai = c(0.16, 0.36),
    etr_p75_panelai = c(0.27, 0.47),
    etr_p95_panelai = c(0.46, 0.66)
  )
  direct <- summarise_observed_t4(brackets, c("parent", "affiliate", "year"))
  crossval <- build_matched_stage1_crossval(panel, brackets, direct)

  expect_identical(crossval$exact$parent, "USA")
  expect_identical(crossval$restricted$parents, "USA")
  expect_equal(crossval$restricted$direct_low_share, 0.6)
  expect_equal(crossval$restricted$percentile_low_share, crossval$exact$percentile_low_share)
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
