# Run the pinned-input pipeline in fresh R sessions, from the repository root.
# Usage: Rscript --vanilla run_all.R [--output-root=/path/to/output]
main <- function(args = commandArgs(trailingOnly = TRUE)) {
  if (length(args) > 1L || (length(args) && !grepl("^--output-root=.+", args))) {
    stop("Usage: Rscript --vanilla run_all.R [--output-root=/path/to/output]")
  }
  if (!file.exists("code/00_config.R")) {
    stop("Run this command from the repository root")
  }
  if (length(args)) {
    output_root <- path.expand(sub("^--output-root=", "", args))
    dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
    Sys.setenv(GMT_OUTPUT_ROOT = normalizePath(output_root, mustWork = TRUE))
  }
  scripts <- c(
    "01_data_cleaning.R",
    "02a_profit_reconciliation_model.R",
    "02_base_correction_and_merging.R",
    "03_stage1_etr.R",
    "04_stage2_sbie.R",
    "05_stage3_behavioral.R",
    "06_stage4_5_revenue_allocation_sbs.R",
    "07_stage4_6_revenue_pipeline_decomposition.R",
    "07a_profit_correction_revenue_uncertainty.R",
    "09_stage1_measurement_error_simulation.R",
    "10_jurisdiction_influence_robustness.R",
    "11_sesh_notch_bunching_diagnostic.R",
    "12_profit_correction_validation.R",
    "diagnostics_step4_stage1_stage2_audit.R",
    "diagnostics_step5_revenue_architecture.R",
    "diagnostics_step6_econometrics_and_cit_recovery.R",
    "diagnostics_step7_reallocation_and_budget_backtest.R",
    "diagnostics_step8_conduit_globe_wedge.R",
    "diagnostics_step9_bilateral_aggregation_ladder.R",
    "diagnostics_step10_rank_consistent_beta.R",
    "diagnostics_step12_hanlon_globe_bridge.R",
    "diagnostics_step13_qdmtt_nash_equilibrium.R",
    "diagnostics_step14_cbcr_tables_2_3_5_6_extensions.R",
    "diagnostics_step15_total_variance_and_globe_factorial.R",
    "diagnostics_step11_master_scorecard.R",
    "08_generate_results_tables.R",
    "13_generate_results_figures.R"
  )
  rscript <- file.path(R.home("bin"), "Rscript")
  for (script in file.path("code", scripts)) {
    message("Running ", script)
    status <- system2(rscript, c("--vanilla", shQuote(script)))
    if (status != 0L) stop(script, " exited with status ", status)
  }
}

if (sys.nframe() == 0L) main()
