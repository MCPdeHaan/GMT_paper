read_extension <- function(filename) {
  readr::read_csv(processed_path("diagnostics", paste0(filename, ".csv")),
    show_col_types = FALSE, guess_max = Inf)
}

test_that("measurement extensions preserve estimator and factorial coverage", {
  validation <- read_extension("audit_step4_stage1_estimator_comparison")
  expect_equal(nrow(validation), 30L)
  expect_equal(nrow(unique(validation[c("sample", "estimator", "outcome")])), 30L)
  expect_setequal(validation$outcome, c("low_share", "liability_rate"))

  ladder <- read_extension("step9_ladder_anova_decomposition")
  expect_setequal(ladder$n_scenarios, c(32, 64))
  expect_setequal(ladder$record_type, c("etr_contrast", "factor"))
  blending <- read_extension("step14_table3_vs_table4_blending_wedge")
  expect_true(all(c("group_share_common", "juris_share_common") %in% names(blending)))
  expect_true(any(blending$matched_pair_years > 0, na.rm = TRUE))
})

test_that("econometric extensions contain the division-bias and budget comparisons", {
  division <- read_extension("step6_division_bias_and_curvature_audit")
  expect_setequal(division$estimator, c("fe_ols", "fe_wls", "fe_ppml_positive"))
  expect_true(all(c("lagged_etr", "jackknife_etr") %in% division$regressor))
  expect_true(any(division$bic_winner, na.rm = TRUE))

  budgets <- read_extension("step7_official_budget_forecasts_backtest")
  expect_equal(nrow(budgets), 63L)
  expect_setequal(budgets$country, c("AUT", "BEL", "DEU", "FRA", "IRL", "NLD", "SVK"))
  expect_true(all(budgets$collector_min_eur_bn <= budgets$collector_max_eur_bn))
})

test_that("the accounting bridge retains its baseline and conserves allocated liability", {
  bridge <- read_extension("step12_cbcr_to_budget_waterfall_bridge")
  waterfall <- bridge[bridge$record_type == "waterfall", ]
  expect_true(all(c("00_baseline", "02_current_losses", "03_prior_loss_carryforward",
    "04_envelope_tax", "05_safe_harbour_2026") %in% waterfall$step))
  expect_true(all(is.finite(waterfall$max_conservation_gap_usd)))
  expect_lt(max(waterfall$max_conservation_gap_usd), 1e-3)
})

test_that("policy deviations and the joint variance decomposition cover the frozen designs", {
  nash <- read_extension("step13_unilateral_qdmtt_deviation_matrix")
  expect_setequal(nash$country, EU27_ISO3)
  expect_setequal(nash$regime, c("Universal", "SbS"))
  keys <- c("country", "level", "deviation", "regime", "window")
  expect_equal(nrow(unique(nash[keys])), 27L * 2L^4L)

  variance <- read_extension("step15_law_of_total_variance_decomposition")
  totals <- variance[variance$record == "total_variance", ]
  expect_setequal(totals$n_joint_draws, 500)
  expect_setequal(totals$scope, c(EU27_ISO3, "EU27"))
  expect_equal(totals$total_variance_usd_bn_sq,
    totals$scenario_variance_usd_bn_sq + totals$parameter_variance_usd_bn_sq,
    tolerance = 1e-12)
  factorial <- read_extension("step15_globe_accounting_factorial_anova")
  expect_setequal(factorial$scenarios, c(32, 64))
})

test_that("the master scorecard includes all empirical stages and extension results", {
  scorecard <- read_extension("master_paper_v2_scorecard")
  expect_equal(nrow(scorecard), 65478L)
  expect_setequal(scorecard$stage, c("Data", "Stage 1", "Stage 2", "Stage 3",
    "Stage 4.5", "Stage 4.6", "Step 12", "Step 13", "Step 14", "Step 15"))
  expect_true(any(is.finite(scorecard$paper_value)))
})

test_that("the Paper v2 publication tables and figures are complete", {
  expect_setequal(list.files(generated_path("paper_v2_tables")), c(
    "tab_v2_etr_ladder_and_crossval.tex",
    "tab_v2_stage2_sbti_and_bracket_substance.tex",
    "tab_v2_stage3_division_bias_and_ppml.tex",
    "tab_v2_factorial_globe_and_total_variance.tex",
    "tab_v2_source_collector_ledger_and_regimes.tex",
    "tab_v2_budget_backtest_and_hanlon_waterfall.tex",
    "tab_v2_qdmtt_nash_deviation_game.tex",
    "tab_v2_cbcr_tables_2_3_6_extensions.tex",
    "tab_v2_main_table1_sample_and_coverage.tex",
    "tab_v2_main_table3_substance_and_sbti.tex",
    "tab_v2_main_table5_variance_and_uncertainty.tex",
    "tab_v2_main_table7_source_collector_ledger.tex",
    "tab_v2_main_table8_qdmtt_repeal_game.tex",
    "tab_v2_app_table3_h5_regression.tex",
    "tab_v2_app_table5_country_uncertainty.tex",
    "tab_v2_app_table7_regime_sensitivities.tex",
    "tab_v2_app_table8_universal_and_optout.tex"
  ))
  figures <- file.path(generated_path("paper_v2_figures"), c(
    "fig_v2_cbcr_to_budget_waterfall.pdf",
    "fig_v2_qdmtt_deviation_efficiency_vs_sbti.pdf",
    "fig_v2_shapley_variance_core_and_accounting.pdf"
  ))
  expect_true(all(file.exists(figures)))
  expect_true(all(vapply(figures, function(path) {
    identical(rawToChar(readBin(path, "raw", n = 5L)), "%PDF-")
  }, logical(1))))
})

test_that("main-text and appendix fragments partition the full Paper v2 tables", {
  read_table <- function(name) readLines(file.path(generated_path("paper_v2_tables"), paste0(name, ".tex")))
  body_rows <- function(lines) {
    rows <- grep("\\\\\\\\$", lines, value = TRUE)
    rows[!grepl("^(\\\\caption|\\\\multicolumn)|& .*\\(%\\)|^(ISO|Window|Scope|Year|Rates|Sample) &", rows)]
  }
  for (pair in list(
    c("tab_v2_stage2_sbti_and_bracket_substance", "tab_v2_main_table3_substance_and_sbti", "tab_v2_app_table3_h5_regression"),
    c("tab_v2_source_collector_ledger_and_regimes", "tab_v2_main_table7_source_collector_ledger", "tab_v2_app_table7_regime_sensitivities"),
    c("tab_v2_factorial_globe_and_total_variance", "tab_v2_main_table5_variance_and_uncertainty", "tab_v2_app_table5_country_uncertainty")
  )) {
    full <- body_rows(read_table(pair[1]))
    split <- c(body_rows(read_table(pair[2])), body_rows(read_table(pair[3])))
    expect_setequal(split, full)
    expect_equal(length(split), length(full))
  }
  main8 <- read_table("tab_v2_main_table8_qdmtt_repeal_game")
  expect_false(any(grepl("& Universal &", main8, fixed = TRUE)))
  expect_length(grep("& Universal &", readLines(file.path(generated_path("paper_v2_tables"),
    "tab_v2_app_table8_universal_and_optout.tex")), fixed = TRUE), 27L)
  expect_length(grep("^IRL & ", main8), 2L)
})
