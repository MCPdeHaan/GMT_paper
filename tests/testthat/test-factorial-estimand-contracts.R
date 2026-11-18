factorial_audit <- source_pipeline("diagnostics/factorial_contract_audit.R", new.env())

audit_fixture <- function(formula) {
  e <- factorial_audit
  z <- e$step15_design()
  z$revenue <- eval(substitute(formula), z, parent.frame())
  z
}

testthat::test_that("the frozen factors have their declared identity and both Factor 2 meanings", {
  e <- factorial_audit
  expect_identical(e$FACTOR_COLS, c("x1_etr", "x2_substance", "x3_rates", "x4_sbs", "x5_behaviour"))
  ids <- paste0("x", vapply(0:31, function(n) paste(as.integer(intToBits(n))[5:1], collapse = ""), ""))
  paths <- c(processed_path("stage3_factorial_pair_year.rds"),
    repo_path("data", "baseline_r10b", "data", "processed", "stage3_factorial_pair_year.rds"))
  labels <- c("sectoral_sbie_only", "sectoral_sbie_sbti")
  for (i in seq_along(paths)) {
    panel <- readRDS(paths[i])
    expect_identical(sort(unique(panel$scenario_id)), ids)
    expect_setequal(panel$factor2_substance, c("aggregate_sbie", labels[i]))
    design <- unique(panel[e$SCENARIO_VARS])
    expect_identical(sort(design$scenario_id[design$factor1_etr == "distributional" &
      design$factor2_substance == "aggregate_sbie" & design$rate_scenario == "initial" &
      design$factor5_behaviour == "behavioural"]), c("x10001", "x10011"))
    expect_no_error(e$assert_balanced_binary_design(panel, e$FACTOR_COLS, c("parent", "affiliate", "year")))
  }
})

testthat::test_that("the audit rejects invalid factors, key duplication and absent observations", {
  e <- factorial_audit
  d <- audit_fixture(x1_etr)
  expect_no_error(e$assert_balanced_binary_design(d, e$FACTOR_COLS, outcome = "revenue"))
  expect_error(e$assert_balanced_binary_design(d[-1, ], e$FACTOR_COLS), "Incomplete")
  expect_error(e$assert_balanced_binary_design(d[c(1, 1, 3:32), ], e$FACTOR_COLS), "duplicate")
  z <- d
  z$x1_etr[1] <- 2L
  expect_error(e$assert_balanced_binary_design(z, e$FACTOR_COLS), "numeric 0/1")
  z <- d
  z$scenario_id[1] <- "x10000"
  expect_error(e$assert_balanced_binary_design(z, e$FACTOR_COLS), "factor order")
  z <- d
  z$revenue[1] <- NA
  expect_error(e$assert_balanced_binary_design(z, e$FACTOR_COLS, outcome = "revenue"), "Non-finite")
  expect_no_error(e$assert_balanced_binary_design(d, e$FACTOR_COLS, outcome = "revenue"))
  expect_error(e$compute_factorial_effects_one(d[-1, ]), "complete 32-scenario")
})

testthat::test_that("hand-computed orthogonal components reproduce production", {
  e <- factorial_audit
  d <- audit_fixture(2*x1_etr + 3*x2_substance + 4*x1_etr*x2_substance)
  expect_equal(mean(d$revenue), 3.5)
  ans <- e$compute_factorial_effects_one(d)
  terms <- c("x1_etr", "x2_substance", "x1_etr:x2_substance")
  expect_equal(ans$ss[match(terms, ans$effect)]/32, c(4, 6.25, 1))
  expect_equal(unique(ans$total_ss)/32, 11.25)
  expect_equal(sum(ans$eta_squared), 1)
  allocation <- e$build_shapley_factor_attribution(ans)
  expect_equal(allocation$shapley_eta_squared[match(e$FACTOR_COLS, allocation$effect)], c(.4, .6, 0, 0, 0))
  reference <- e$audit_orthogonal_effects(d, matrix(d$revenue), e$FACTOR_COLS)
  expect_equal(unname(reference$shapley), c(.4, .6, 0, 0, 0))
  main <- e$compute_factorial_effects_one(audit_fixture(12 - 8*x4_sbs))
  expect_equal(unname(main$effect_coefficient[main$effect == "x4_sbs"]), -4)
  expect_equal(main$eta_squared[main$effect == "x4_sbs"], 1)
  d <- audit_fixture(10 + 3*(2*x1_etr-1)*(2*x2_substance-1)*(2*x3_rates-1))
  p <- e$compute_factorial_effects_one(d)
  expect_equal(p$ss[p$interaction_order == 3 & p$ss > 0]/32, 9)
  expect_equal(e$build_shapley_factor_attribution(p)$shapley_eta_squared, c(rep(1/3, 3), 0, 0))
  for (amount in c(0, 92)) {
    constant <- e$compute_factorial_effects_one(audit_fixture(amount + 0*x1_etr))
    expect_true(all(constant$ss == 0 & constant$total_ss == 0))
    expect_true(all(is.na(constant$eta_squared)))
    expect_true(all(e$build_shapley_factor_attribution(constant)$shapley_eta_squared == 0))
  }
})

testthat::test_that("cross-country and intertemporal covariance changes the estimand", {
  e <- factorial_audit
  d <- audit_fixture(10*x1_etr)
  reversal <- audit_fixture(10 - 10*x1_etr)
  panel <- dplyr::bind_rows(
    dplyr::mutate(d, country = "A", country_name = "A", year = 2022L),
    dplyr::mutate(reversal, country = "B", country_name = "B", year = 2022L),
    dplyr::mutate(reversal, country = "A", country_name = "A", year = 2023L),
    dplyr::mutate(d, country = "B", country_name = "B", year = 2023L))
  pooled <- e$compute_factorial_anova(panel)$pooled
  expect_equal(unique(pooled$total_ss)/32, 100)
  cum <- dplyr::summarise(panel, revenue = sum(revenue), .by = c(country, scenario_id))
  expect_true(all(cum$revenue == 10))
  eu <- dplyr::summarise(panel, revenue = sum(revenue), .by = c(year, scenario_id))
  expect_true(all(eu$revenue == 10))
  expect_equal(mean((d$revenue - 5)*(reversal$revenue - 5)), -25)
  expect_true(all(dplyr::summarise(eu, revenue = mean(revenue), .by = scenario_id)$revenue == 10))
  # A weaker opposite effect leaves a nonzero cumulative contrast, changing
  # the relative share of a second orthogonal factor.
  y <- cbind(d$revenue, -d$revenue + 4*d$x2_substance)
  before <- e$audit_orthogonal_effects(d, y, e$FACTOR_COLS)
  after <- e$audit_orthogonal_effects(d, matrix(rowSums(y)), e$FACTOR_COLS)
  expect_equal(unname(before$shapley), c(50/54, 4/54, 0, 0, 0))
  expect_equal(unname(after$shapley), c(0, 1, 0, 0, 0))
})

testthat::test_that("the two sixth factors differ and zero is not missing liability", {
  e <- factorial_audit
  d <- audit_fixture(x1_etr)
  split <- e$build_split_substance_variant(d, NULL, "SECTORAL_SBIE_ONLY")
  expect_equal(nrow(split), 64)
  expect_identical(split$scenario_id, paste0("x", split$x1_etr, split$x2a_sectoral,
    split$x2b_sbti, split$x3_rates, split$x4_sbs, split$x5_behaviour))
  expect_true(all(dplyr::summarise(split, span = diff(range(revenue)),
    .by = dplyr::all_of(e$FACTOR_COLS))$span == 0))
  accounting <- e$step15_design(TRUE)
  expect_equal(nrow(accounting), 64)
  expect_equal(sum(accounting$x3_rates == 0), 32)
  expect_identical(names(accounting)[6], "x6_accounting")
  expect_equal(sum(d$x1_etr == 1), 16)
  source <- e$build_source_panel(tibble::tibble(topup_after_behaviour = c(10, 20, 30, 40, NA, 0),
    qdmtt_flag = c(TRUE, rep(FALSE, 5)), parent_iir_utpr_flag = c(FALSE, TRUE, rep(FALSE, 4)),
    sbs_exempt = c(TRUE, FALSE, FALSE, TRUE, FALSE, FALSE)))
  expect_identical(source$stage4_allocation_regime, c("qdmtt", "iir", "utpr", "sbs_extinguished", "zero", "zero"))
  expect_equal(colSums(source[c("stage4_qdmtt_liability", "stage4_iir_liability", "stage4_utpr_pool",
    "stage4_sbs_extinguished_liability")]), c(stage4_qdmtt_liability = 10, stage4_iir_liability = 20,
    stage4_utpr_pool = 30, stage4_sbs_extinguished_liability = 40))
  expect_equal(source$stage4_conservation_gap, rep(0, 6))
  expect_error(e$run_factorial_contract_audit(repo_root, repo_path("data", "baseline_r10b"),
    repo_path("data", "processed", "r13a-test-forbidden")), "fresh diagnostic")
})

testthat::test_that("collector receipts exclude extinction and unsupported pools", {
  e <- factorial_audit
  revenue <- readRDS(processed_path("stage4_5_revenue_by_channel_global.rds"))
  totals <- dplyr::summarise(revenue, eu = sum(revenue[country_is_eu27]),
    world = sum(revenue), .by = scenario_id)
  expect_equal(totals$eu[totals$scenario_id == "x10011"]/1e9, 367.670094645, tolerance = 1e-11)
  expect_equal(range(totals$eu)/1e9, c(196.277042301, 673.405475525), tolerance = 1e-11)
  expect_equal(range(totals$world)/1e9, c(655.048677962, 1643.580285054), tolerance = 1e-11)
  expect_equal(totals$world[totals$scenario_id == "x10011"]/1e9, 1031.779186724, tolerance = 1e-11)
  attribution <- readRDS(processed_path("stage4_6_shapley_factor_attribution.rds"))
  expect_equal(attribution$shapley_eta_squared[attribution$effect == "x2_substance"]*100,
    .1434072373, tolerance = 1e-9)
  unsupported <- readRDS(processed_path("stage4_5_utpr_unsupported_sources.rds"))
  expect_true(all(unsupported$unsupported_utpr > 0))
  expect_false(any(revenue$channel %in% c("unsupported_utpr", "UTPR_source_proxy", "sbs_extinguished")))
  c <- readRDS(processed_path("stage4_5_allocation_conservation.rds"))
  expect_true(any(c$unsupported_utpr > 0))
  expect_true(any(c$sbs_extinguished_topup > 0))
  expect_lt(max(abs(c$pre_allocation_topup - c$allocated_topup - c$unsupported_utpr -
    c$sbs_extinguished_topup - c$zero_liability)), 1e-3)
  expect_lt(max(abs(c$residual_gap)), 1e-3)
})

testthat::test_that("the ladder and the combined-fiscal ledger retain their declared outcomes", {
  p <- readRDS(processed_path("stage1_bilateral_panel.rds"))
  expect_true(any(p$ladder_l4_strict_source == "exact_table_iv"))
  fallback <- p$ladder_l4_strict_source %in% "bilateral_average"
  expect_true(any(fallback))
  expect_equal(p$ladder_l4_strict_low_share[fallback], as.numeric(p$etr_panelai_stage1[fallback] < .15))
  expect_false(any(p$ladder_l4_strict_source[p$year %in% 2017:2018] %in% "exact_table_iv"))
  fiscal <- read.csv(processed_path("diagnostics", "step6_topup_vs_cit_recovery_rule_b_eu27.csv"))
  fiscal <- subset(fiscal, start_year == 2017 & end_year == 2023 & country == "EU27" & scenario_id == "x10011")
  expect_equal(fiscal$ordinary_cit_gross_destination_revenue/1e9, 96.390148338, tolerance = 1e-9)
  expect_equal(fiscal$ordinary_cit_net_by_incidence,
    fiscal$ordinary_cit_gross_destination_revenue - fiscal$ordinary_cit_source_loss)
  expect_equal(fiscal$total_fiscal_gain_vs_mechanical_net_by_incidence/1e9, 17.573779048, tolerance = 1e-9)
  expect_equal(fiscal$total_fiscal_revenue,
    fiscal$direct_topup + fiscal$ordinary_cit_gross_destination_revenue)
})

testthat::test_that("accounting contrasts preserve population variance and undefined zero shares", {
  e <- factorial_audit
  design <- e$step15_design(TRUE)
  factors <- c(e$FACTOR_COLS, "x6_accounting")
  # Respect the existing interface's USD bn unit.
  y <- with(design, 2*x1_etr + 3*x6_accounting + 4*x1_etr*x6_accounting)
  out <- e$step15_factorial_effects(matrix(y), design, factors, "EU27", "toy", "cumulative_collector")
  expect_equal(unique(out$factorial_variance_usd_bn_sq), 11.25)
  p <- subset(out, record == "main_effect")
  expect_equal(p$shapley_eta_squared[match(factors, p$effect)], c(.4, 0, 0, 0, 0, .6))
  expect_equal(unname(p$dollar_main_effect_usd_bn[match(factors, p$effect)]), c(4, 0, 0, 0, 0, 5))
  flat <- e$step15_factorial_effects(matrix(rep(8, 64)), design, factors, "EU27", "toy", "cumulative_collector")
  expect_equal(unique(flat$factorial_variance_usd_bn_sq), 0)
  expect_true(all(is.na(flat$shapley_eta_squared)))
})

testthat::test_that("scenario-keyed comparison retains missingness and prohibits dropped support", {
  e <- factorial_audit
  d <- tibble::tibble(scenario_id = c("x0", "x1"), amount = c(NA_real_, 0))
  result <- e$audit_compare(d, d[2:1, ], "scenario_id", "amount", "toy", 0)
  expect_true(result$exact_vector)
  expect_equal(result$missing_rows, 1)
  expect_error(e$audit_compare(d, d[1, ], "scenario_id", "amount", "toy", 0), "different keys")
  expect_error(e$audit_compare(d, dplyr::mutate(d, amount = 0), "scenario_id", "amount", "toy", 0),
    "different missingness")
})
