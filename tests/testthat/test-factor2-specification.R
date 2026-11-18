factor2_stage <- source_pipeline("11_policy_game_and_variance_extensions.R", new.env())

factor2_fixture <- function() {
  list(
    bilateral = tibble::tibble(rate_scenario = "initial", affiliate = "IRL",
      year = c(2021L, 2022L, 2023L), affiliate_is_eu27 = TRUE,
      analysis_profit_positive = 100, stage2_topup_tax_average = 5,
      stage2_topup_tax_distributional = 2.5),
    hosts = tibble::tibble(affiliate = "IRL", year = 2021:2023,
      average_low_share = 1, stage1_distributional_low_share = .5),
    sectors = tibble::tibble(rate_scenario = "initial", affiliate = "IRL",
      year = 2022L, sectoral_profit_proxy = c(75, 25),
      sectoral_phi = c(.2, .6), sectoral_kappa = c(.03, .05),
      average_topup_rate = .1, stage1_distributional_topup_rate = .1))
}

test_that("Factor 2 has exactly two named modes and an explicit leading default", {
  withr::local_envvar(GMT_FACTOR2_SPECIFICATION = NA_character_)
  expect_identical(factor2_stage$factor2_specification(), "SECTORAL_SBIE_ONLY")
  expect_identical(factor2_stage$factor2_sectoral_label(), "sectoral_sbie_only")
  withr::local_envvar(GMT_FACTOR2_SPECIFICATION = "LEGACY_HYBRID_SBIE_SBTI")
  expect_identical(factor2_stage$factor2_specification(), "LEGACY_HYBRID_SBIE_SBTI")
  expect_identical(factor2_stage$factor2_sectoral_label(), "sectoral_sbie_sbti")
  for (bad in list("", "SECTORAL", "zero", NA_character_, c("SECTORAL_SBIE_ONLY", "SECTORAL_SBIE_ONLY"))) {
    expect_error(factor2_stage$factor2_specification(bad), "Unknown GMT_FACTOR2_SPECIFICATION")
  }
})

test_that("sectoral-only rates retain low-tax shares and exclude positive capacity", {
  f <- factor2_fixture()
  before <- serialize(f, NULL)
  bridge <- factor2_stage$build_sectoral_factor2_bridge
  old <- bridge(f$bilateral, f$hosts, f$sectors, specification = "LEGACY_HYBRID_SBIE_SBTI")
  new <- bridge(f$bilateral, f$hosts, f$sectors, specification = "SECTORAL_SBIE_ONLY")
  # .75*.08 + .25*.04 = .07; legacy .75*.05 + .25*0 = .0375.
  expect_equal(old$sectoral_scale_average, rep(.75, 3))
  expect_equal(old$sectoral_scale_distributional, rep(.75, 3))
  expect_equal(new$sectoral_scale_average, rep(1.4, 3))
  expect_equal(new$sectoral_scale_distributional, rep(1.4, 3))
  expect_identical(new$sectoral_scale_source_distributional,
    c("reference_2022", "contemporaneous", "reference_2022"))
  expect_identical(new$aggregate_profit, old$aggregate_profit)
  expect_identical(new$aggregate_tax_per_profit_average, old$aggregate_tax_per_profit_average)
  expect_identical(new$weighted_sectoral_phi, old$weighted_sectoral_phi)
  expect_identical(new$weighted_sectoral_kappa, old$weighted_sectoral_kappa)
  expect_identical(serialize(f, NULL), before)
  for (capacity in c(0, NA_real_)) {
    f$sectors$sectoral_kappa <- capacity
    x <- bridge(f$bilateral, f$hosts, f$sectors, specification = "SECTORAL_SBIE_ONLY")
    expect_identical(x$sectoral_scale_average, new$sectoral_scale_average)
    previous <- bridge(f$bilateral, f$hosts, f$sectors, specification = "LEGACY_HYBRID_SBIE_SBTI")
    expect_equal(previous$sectoral_scale_average, rep(if (is.na(capacity)) 1 else 1.4, 3))
  }
  f$sectors$sectoral_phi <- NA_real_
  unavailable <- bridge(f$bilateral, f$hosts, f$sectors, specification = "SECTORAL_SBIE_ONLY")
  expect_identical(unavailable$sectoral_scale_distributional, rep(1, 3))
  expect_identical(unavailable$sectoral_scale_source_distributional, rep("neutral", 3))
})

test_that("the paired ledger keeps keys and missing values explicit", {
  env <- source_pipeline("diagnostics/factor2_revision.R", new.env())
  old <- tibble::tibble(id = c("IRL", "DEU", "FRA"), amount = c(0, NA_real_, 5))
  new <- tibble::tibble(id = c("FRA", "IRL", "DEU"), amount = c(8, 0, NA_real_))
  x <- env$factor2_compare_values(old, new, "id", "amount")
  expect_identical(x$id, c("DEU", "FRA", "IRL"))
  expect_identical(x$amount_change, c(NA_real_, 3, 0))
  expect_error(env$factor2_compare_values(dplyr::bind_rows(old, old[1, ]), new, "id", "amount"), "duplicate")
  expect_error(env$factor2_compare_values(old, new[-1, ], "id", "amount"), "different keyed support")
})

test_that("contemporaneous and reference selection are common to both modes", {
  f <- factor2_fixture()
  f$sectors <- dplyr::bind_rows(f$sectors, dplyr::mutate(f$sectors, year = 2023L, sectoral_phi = .5))
  for (mode in c("SECTORAL_SBIE_ONLY", "LEGACY_HYBRID_SBIE_SBTI")) {
    x <- factor2_stage$build_sectoral_factor2_bridge(f$bilateral, f$hosts, f$sectors, specification = mode)
    fixed <- factor2_stage$build_sectoral_factor2_bridge(f$bilateral, f$hosts, f$sectors,
      use_contemporaneous = FALSE, specification = mode)
    expect_identical(x$sectoral_scale_source_average, c("reference_2022", "contemporaneous", "contemporaneous"))
    expect_identical(fixed$sectoral_scale_average, rep(x$sectoral_scale_average[2], 3))
  }
})

test_that("sparse sectoral rates agree with independently weighted detailed rates", {
  # One host, two sectors: 75/25 profit allocation, shields 15/15 dollars.
  input <- list(host = data.frame(affiliate = "IRL"), sector = list(list(
    host = c(1L, 1L), ids = 1L, profit_share = c(.75, .25), profit_share_sum = 1,
    sbie = c(15, 15), incentive = c(2.25, 1.25), reference = 1L)))
  for (mode in c("SECTORAL_SBIE_ONLY", "LEGACY_HYBRID_SBIE_SBTI")) {
    expected <- if (mode == "SECTORAL_SBIE_ONLY") 1.4 else .75
    for (share in c(.5, 1)) {
      x <- factor2_stage$step15_sector_scale(input, 1L, 5 * share, 100, share, .1, specification = mode)
      expect_equal(x, expected, tolerance = 1e-14)
    }
  }
  input$sector[[1]]$incentive <- c(NA_real_, NA_real_)
  expect_equal(factor2_stage$step15_sector_scale(input, 1L, 2.5, 100, .5, .1,
    specification = "SECTORAL_SBIE_ONLY"), 1.4)
})

test_that("the revised six-factor SBTI axis is exactly redundant", {
  env <- source_pipeline("09_econometric_and_reallocation_extensions.R", new.env())
  panel <- tidyr::expand_grid(x1_etr = 0:1, x2_substance = 0:1, x3_rates = 0:1,
    x4_sbs = 0:1, x5_behaviour = 0:1) |>
    dplyr::mutate(scenario_id = paste0("x", x1_etr, x2_substance, x3_rates, x4_sbs, x5_behaviour),
      topup_after_behaviour = 100 + 10*x2_substance)
  x <- env$build_split_substance_variant(panel, NULL, specification = "SECTORAL_SBIE_ONLY")
  expect_identical(nrow(x), 64L)
  expect_identical(anyDuplicated(x$scenario_id), 0L)
  off <- dplyr::filter(x, x2b_sbti == 0) |> dplyr::select(-scenario_id, -x2b_sbti)
  on <- dplyr::filter(x, x2b_sbti == 1) |> dplyr::select(-scenario_id, -x2b_sbti)
  expect_identical(off, on)
  expect_identical(factor2_stage$build_transition_rates()$transition_year, 2024:2033)
  expect_identical(sort(panel$scenario_id), sort(factor2_stage$step15_design()$scenario_id))
})
