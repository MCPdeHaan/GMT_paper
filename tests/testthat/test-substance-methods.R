substance_stage <- source_pipeline("04_stage2_sbie.R", new.env())

test_that("aggregate SBIE uses the two endpoint rates on the same activity", {
  payroll <- c(200, 0, 200, 0, NA, 200, NA)
  assets <- c(500, 500, 0, 0, 500, NA, NA)
  endpoints <- substance_stage$STAGE2_ENDPOINTS
  expect_identical(endpoints$rate_scenario, c("initial", "long_run"))
  expect_identical(endpoints$sigma_w, c(0.10, 0.05))
  expect_identical(endpoints$sigma_a, c(0.08, 0.05))
  expect_equal(substance_stage$compute_sbie_value(payroll, assets, 0.10, 0.08),
    c(60, 40, 20, 0, 40, 20, 0))
  expect_equal(substance_stage$compute_sbie_value(payroll, assets, 0.05, 0.05),
    c(35, 25, 10, 0, 25, 10, 0))

  rates <- substance_stage$build_transition_rates()
  expect_identical(rates$transition_year, 2024:2033)
  expect_identical(rates$rate_scenario, c("initial", rep("transition", 8), "long_run"))
  expect_equal(rates$sigma_w[c(1, 4, 10)], c(.10, .10 - .05 / 3, .05), tolerance = 1e-15)
  expect_equal(rates$sigma_a[c(1, 4, 10)], c(.08, .07, .05), tolerance = 1e-15)
  expect_equal(substance_stage$compute_sbie_value(200, 500, rates$sigma_w[4], rates$sigma_a[4]),
    155 / 3, tolerance = 1e-14)
})

test_that("bilateral shields retain the flags, denominator and liability boundary", {
  stage1 <- tibble::tibble(parent = c("CAN", "DEU", "DNK", "GBR", "JPN", "USA"),
    affiliate = "IRL", year = 2023L, payroll_sbie = c(200, 200, NA, 0, NA, NA),
    assets_sbie = c(500, 500, 500, 0, 500, NA),
    analysis_profit_positive = c(100, 60, 20, 0, NA, 100),
    stage1_lowtax_profit_distributional = c(50, 30, 10, 0, NA, 0),
    stage1_distributional_topup_rate = c(.1, .1, .1, .1, NA, NA))
  stage1 <- dplyr::mutate(stage1,
    stage1_topup_tax_distributional = stage1_lowtax_profit_distributional * stage1_distributional_topup_rate,
    stage1_lowtax_profit_average = stage1_lowtax_profit_distributional,
    stage1_lowtax_profit_distributional_bilat = stage1_lowtax_profit_distributional,
    stage1_lowtax_profit_distributional_strict = c(20, 20, 20, 0, NA, 20),
    average_topup_rate = 0, stage1_distributional_topup_rate_bilat = stage1_distributional_topup_rate,
    stage1_distributional_topup_rate_strict = 0.05,
    stage1_topup_tax_average = 0,
    stage1_topup_tax_distributional_bilat = stage1_topup_tax_distributional,
    stage1_topup_tax_distributional_strict = stage1_lowtax_profit_distributional_strict * .05)
  before <- serialize(stage1, NULL)
  stage2 <- substance_stage$build_aggregate_bilateral_sbie(stage1, substance_stage$STAGE2_ENDPOINTS)
  initial <- dplyr::filter(stage2, rate_scenario == "initial")
  long <- dplyr::filter(stage2, rate_scenario == "long_run")
  expect_identical(serialize(stage1, NULL), before)
  expect_identical(initial$parent, stage1$parent)
  expect_identical(initial$payroll_sbie, stage1$payroll_sbie)
  expect_identical(initial$stage2_payroll_zero_fallback_flag, c(FALSE, FALSE, TRUE, FALSE, NA, TRUE))
  expect_identical(initial$stage2_assets_zero_fallback_flag, c(FALSE, FALSE, FALSE, FALSE, FALSE, TRUE))
  expect_equal(initial$stage2_sbie, c(60, 60, 40, NA, NA, 0))
  expect_equal(long$stage2_sbie, c(35, 35, 25, NA, NA, 0))
  expect_equal(initial$stage2_phi_raw, c(0.6, 1, 2, NA, NA, 0))
  expect_equal(initial$stage2_phi, c(0.6, 1, 1, NA, NA, 0))
  expect_identical(initial$stage2_phi_capped_flag, c(FALSE, FALSE, TRUE, FALSE, FALSE, FALSE))
  expect_equal(initial$stage2_filter, c(0.4, 0, 0, 1, NA, 1))
  expect_equal(initial$stage2_excess_lowtax_profit_distributional, c(20, 0, 0, 0, NA, 0))
  expect_equal(initial$stage2_topup_tax_distributional, c(2, 0, 0, 0, NA, 0))
  expect_equal(initial$stage2_topup_tax_distributional_strict, c(.4, 0, 0, 0, NA, 1))
  expect_equal(initial$stage2_effective_floor_distributional, c(.09, .05, .05, NA, NA, NA))
  expect_equal(initial$stage2_effective_floor_average, c(.15, .15, .15, NA, NA, .15))
  expect_equal(substance_stage$compute_phi_ratio(60, -100), 0)
})

test_that("sectoral scaling uses three distinct weights and retains incomplete rows", {
  shares <- tibble::tibble(affiliate = "IRL", year = 2022L, nace_r2 = LETTERS[1:5],
    fats_payroll_share = c(.8, 0, .2, 0, NA), sectoral_asset_share = c(0, .9, 0, .1, NA),
    sectoral_profit_share = c(.6, .4, 0, 0, NA), fats_employee_share = fats_payroll_share,
    fats_investment_share = sectoral_asset_share, fats_turnover_share = sectoral_profit_share,
    euklems_tangible_asset_share = sectoral_asset_share, use_euklems_asset_share = TRUE,
    euklems_stock_coverage_turnover_share = 1)
  base <- tibble::tibble(affiliate = "IRL", year = 2022L,
    total_payroll = 100, total_assets = 1000, total_profit = 100,
    average_topup_rate = .10, stage1_distributional_topup_rate = .10,
    stage1_distributional_topup_rate_strict = .05)
  rates <- substance_stage$build_transition_rates()[c(1, 4, 10), ]
  build <- substance_stage$build_sectoral_transition_panel
  before <- serialize(list(shares, base), NULL)
  result <- build(dplyr::bind_rows(shares, dplyr::mutate(shares, affiliate = "FRA")), base, rates)
  expect_identical(serialize(list(shares, base), NULL), before)
  expect_equal(result$weights$profit_share_sum, c(1, 1))
  expect_equal(result$weights$payroll_share_sum, c(1, 1))
  expect_equal(result$weights$asset_share_sum, c(1, 1))
  expect_equal(anyDuplicated(result$panel[c("affiliate", "year", "transition_year", "nace_r2")]), 0)
  initial <- dplyr::filter(result$panel, affiliate == "IRL", rate_scenario == "initial")
  expect_identical(initial$year, rep(2022L, 5))
  expect_identical(initial$transition_year, rep(2024L, 5))
  expect_equal(initial$sectoral_payroll, c(80, 0, 20, 0, NA))
  expect_equal(initial$sectoral_assets, c(0, 900, 0, 100, NA))
  expect_equal(initial$sectoral_profit_proxy, c(60, 40, 0, 0, NA))
  expect_equal(sum(initial$sectoral_payroll, na.rm = TRUE), 100)
  expect_equal(sum(initial$sectoral_assets, na.rm = TRUE), 1000)
  expect_equal(sum(initial$sectoral_profit_proxy, na.rm = TRUE), 100)
  expect_equal(initial$sectoral_sbie, c(8, 72, 2, 8, 0))
  expect_equal(initial$sectoral_phi_raw, c(8/60, 72/40, NA, NA, NA))
  expect_equal(initial$sectoral_phi, c(8/60, 1, NA, NA, NA))
  expect_equal(initial$sectoral_kappa, c(4.4/60, 9/40, NA, NA, NA))
  expect_equal(initial$sectoral_floor_average, c(.15 - .10 * 8/60, .05, NA, NA, NA))
  expect_equal(initial$sectoral_floor_average_sbti, c(.15 - (.10 * 8 + 4.4)/60, 0, NA, NA, NA))
  expect_equal(initial$sectoral_floor_distributional_strict_sbti, c(.15 - (.05 * 8 + 4.4)/60, 0, NA, NA, NA))
  unmatched <- dplyr::filter(result$panel, affiliate == "FRA")
  expect_equal(nrow(unmatched), 15)
  expect_true(all(is.na(unmatched$sectoral_profit_proxy)))
  expect_true(all(is.na(unmatched$sectoral_kappa)))
  expect_error(build(dplyr::bind_rows(shares, shares[1, ]), base, rates), "sectoral shares.*duplicate")
  expect_error(build(shares, dplyr::bind_rows(base, base), rates), "sectoral base.*duplicate")
  shares$fats_payroll_share[1] <- .7
  expect_error(build(shares, base, rates), "weights do not sum to one")
})

test_that("the maximum is computed on sector dollars before summing", {
  capacity <- substance_stage$sbti_maximum_capacity
  sectors <- capacity(c(80, 0, 20), c(0, 900, 100))
  expect_equal(sectors, c(4.4, 9, 1.1))
  expect_equal(sum(sectors), 14.5)
  expect_equal(capacity(100, 1000), 10)
  expect_identical(capacity(c(0, NA, 0), c(0, 20, NA)), c(0, NA_real_, NA_real_))
  expect_equal(substance_stage$apply_sbti_capacity_overlay(c(.12, .02, .12, NA), c(.03, .03, NA, .02)),
    c(.09, 0, NA, NA))
})

test_that("the six-factor off-diagonals preserve the standalone estimands", {
  env <- source_pipeline("09_econometric_and_reallocation_extensions.R", new.env())
  env$PROCESSED_DIR <- withr::local_tempdir()
  aggregate <- tibble::tibble(rate_scenario = "initial", affiliate = "IRL", year = c(2022L, 2023L),
    affiliate_is_eu27 = TRUE, analysis_profit_positive = 100,
    stage2_topup_tax_average = 5, stage2_topup_tax_distributional = 2.5)
  hosts <- tibble::tibble(affiliate = "IRL", year = c(2022L, 2023L),
    average_low_share = 1, stage1_distributional_low_share = .5)
  sectors <- tibble::tibble(rate_scenario = "initial", affiliate = "IRL", year = 2022L,
    sectoral_profit_proxy = c(75, 25), sectoral_phi = c(.2, .6), sectoral_kappa = c(.03, .05),
    average_topup_rate = .10, stage1_distributional_topup_rate = .10)
  saveRDS(aggregate, file.path(env$PROCESSED_DIR, "stage2_bilateral_panel.rds"))
  saveRDS(hosts, file.path(env$PROCESSED_DIR, "stage1_affiliate_year.rds"))
  saveRDS(sectors, file.path(env$PROCESSED_DIR, "stage2_sectoral_panel.rds"))
  combined <- env$build_sectoral_factor2_bridge(aggregate, hosts, sectors,
    specification = "LEGACY_HYBRID_SBIE_SBTI")
  separate <- env$build_split_substance_scales()
  expect_equal(combined$sectoral_scale_distributional, rep(.75, 2))
  expect_identical(combined$sectoral_scale_source_distributional, c("contemporaneous", "reference_2022"))
  expect_equal(separate$sector_only_distributional, rep(1.4, 2))
  expect_equal(separate$overlay_only_distributional, rep(.3, 2))
  expect_equal(separate$sector_only_average, separate$sector_only_distributional)
  expect_equal(separate$overlay_only_average, separate$overlay_only_distributional)
})

test_that("the game applies capacity, relief and foregone receipts on distinct dollar bases", {
  env <- source_pipeline("11_policy_game_and_variance_extensions.R", new.env())
  source <- tibble::tibble(parent = "USA", affiliate = "IRL", year = 2023L,
    scenario_id = "x10011", affiliate_is_eu27 = TRUE, stage4_qdmtt_liability = 1,
    stage1_lowtax_profit_distributional = 50, stage2_excess_lowtax_profit_distributional = 20,
    stage1_distributional_low_share = .5, stage1_distributional_topup_rate = .10,
    payroll_sbie = 40, assets_sbie = 100, topup_after_stage2 = 2)
  shares <- tibble::tibble(affiliate = "IRL", year = 2023L, nace_r2 = c("A", "B"),
    profit_share = .5, payroll_share = c(1, 0), asset_share = c(0, 1))
  x <- env$nash_sbti_capacity(list(source = source), shares)
  expect_identical(x[c("parent", "affiliate", "year")], source[c("parent", "affiliate", "year")])
  expect_equal(x$payroll_cap, 1.1)
  expect_equal(x$carrying_value_cap, .5)
  expect_equal(x$capacity, 1.6)
  expect_equal(x$covered_tax_proxy, 2.5)
  expect_equal(x$used_new_qti, 1.6)
  expect_equal(x$new_qti_net_covered_tax, 2.5)
  expect_equal(x$existing_qti_relief, .32)
  expect_equal(x$sbti_overlay_relief, .75)
  expect_equal(x$sector_qdmtt, 1)

  large <- env$nash_sbti_capacity(list(source = dplyr::mutate(source, payroll_sbie = 400)), shares)
  expect_equal(large$capacity, 11.5)
  expect_equal(large$used_new_qti, 1.75)
  expect_equal(large$existing_qti_relief, .6)
  expect_equal(large$sbti_overlay_relief, .75)

  after <- dplyr::mutate(source, topup_after_behaviour = x$qdmtt - x$sbti_overlay_relief,
    qdmtt_flag = TRUE, parent_iir_utpr_flag = FALSE, sbs_exempt = TRUE,
    affiliate_jurisdiction_name = "Ireland", parent_jurisdiction_name = "United States",
    rate_scenario = "initial", factor1_etr = "distributional", factor2_substance = "aggregate_sbie",
    factor3_rates = "initial", factor4_sbs = "sbs", factor5_behaviour = "behavioural",
    x1_etr = 1L, x2_substance = 0L, x3_rates = 0L, x4_sbs = 1L, x5_behaviour = 1L)
  # The ordinary frozen collector weights need not route this QDMTT-only fixture.
  weights <- list(parent_year_weights = readRDS(processed_path("stage4_5_utpr_parent_year_weights.rds")),
    fallback_weights = readRDS(processed_path("stage4_5_utpr_fallback_weights.rds")))
  allocation <- env$nash_channels(env$build_source_panel(after), weights)
  expect_equal(allocation$max_gap, 0)
  expect_identical(allocation$channels$channel, "QDMTT")
  expect_equal(allocation$channels$revenue, .25)
})

test_that("new substance modules are source-safe independently", {
  withr::local_dir(withr::local_tempdir())
  withr::local_seed(7)
  rng <- .Random.seed
  packages <- search()
  namespaces <- sort(loadedNamespaces())
  opts <- options()
  files <- list.files(all.files = TRUE, no.. = TRUE)
  for (file in c("aggregate_sbie.R", "sectoral_sbie.R", "sbti_capacity.R")) {
    sys.source(repo_path("code", "substance", file), envir = new.env(parent = baseenv()))
  }
  expect_identical(.Random.seed, rng)
  expect_identical(search(), packages)
  expect_identical(sort(loadedNamespaces()), namespaces)
  expect_identical(options(), opts)
  expect_identical(list.files(all.files = TRUE, no.. = TRUE), files)
})
