# Run the pinned-input pipeline in fresh R sessions, from the repository root.
# Usage: Rscript --vanilla run_all.R [--output-root=PATH] [--skip-measurement-error]
main <- function(args = commandArgs(trailingOnly = TRUE)) {
  output_arg <- grep("^--output-root=.+", args, value = TRUE)
  skip_measurement_error <- "--skip-measurement-error" %in% args
  if (length(output_arg) > 1L || anyDuplicated(args) ||
      length(setdiff(args, c(output_arg, "--skip-measurement-error")))) {
    stop("Usage: Rscript --vanilla run_all.R [--output-root=PATH] [--skip-measurement-error]")
  }
  if (!file.exists("code/00_config.R")) {
    stop("Run this command from the repository root")
  }
  if (length(output_arg)) {
    output_root <- path.expand(sub("^--output-root=", "", output_arg))
    dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
    Sys.setenv(GMT_OUTPUT_ROOT = normalizePath(output_root, mustWork = TRUE))
  }
  Sys.setenv(GMT_PROJECT_ROOT = normalizePath(".", mustWork = TRUE))

  rscript <- file.path(R.home("bin"), "Rscript")
  run_script <- function(filename, ...) {
    script <- file.path("code", filename)
    args <- c(...)
    message("Running ", script, if (length(args)) paste0(" ", paste(args, collapse = " ")))
    status <- system2(rscript, c("--vanilla", shQuote(script), shQuote(args)))
    if (status != 0L) stop(script, " exited with status ", status)
  }

  for (script in c(
    "01_data_cleaning.R",
    "02a_profit_reconciliation_model.R",
    "02_base_correction_and_merging.R",
    "03_stage1_etr.R",
    "04_stage2_sbie.R",
    "05_stage3_behavioral.R",
    "06_stage4_5_revenue_allocation_sbs.R",
    "07_stage4_6_revenue_pipeline_decomposition.R"
  )) run_script(script)

  policy_module <- "11_policy_game_and_variance_extensions.R"
  # The fiscal ledger feeds the budget backtest. The budget comparisons
  # feed the measurement and accounting extensions used by the policy games.
  run_script(policy_module, "--phase=fiscal_flows")
  run_script("09_econometric_and_reallocation_extensions.R")
  run_script("08_measurement_and_cbcr_extensions.R")
  run_script("10_accounting_bridge_and_conduit_wedge.R")
  run_script(policy_module, "--phase=policy_and_variance")
  if (!skip_measurement_error) {
    run_script(policy_module, "--phase=measurement_error")
  }
  run_script("12_master_scorecard.R")
  run_script("13_generate_exhibits.R")
}

if (sys.nframe() == 0L) main()
