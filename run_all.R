# Run the pinned-input pipeline in fresh R sessions, from the repository root.
# Usage: Rscript --vanilla run_all.R [--output-root=PATH]
main <- function(args = commandArgs(trailingOnly = TRUE)) {
  output_arg <- grep("^--output-root=.+", args, value = TRUE)
  if (length(output_arg) > 1L || anyDuplicated(args) ||
      length(setdiff(args, output_arg))) {
    stop("Usage: Rscript --vanilla run_all.R [--output-root=PATH]")
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
  run_script <- function(filename) {
    script <- file.path("code", filename)
    message("Running ", script)
    elapsed <- system.time(status <- system2(rscript, c("--vanilla", shQuote(script))))
    if (status != 0L) stop(script, " exited with status ", status)
    message(sprintf("Completed %s in %.1f seconds", script, elapsed[["elapsed"]]))
  }

  for (script in c(
    "01_data_cleaning.R",
    "02a_profit_reconciliation_model.R",
    "02_base_correction_and_merging.R",
    "03_stage1_etr.R",
    "04_stage2_sbie.R",
    "05_stage3_behavioral.R",
    "06_stage4_5_revenue_allocation_sbs.R",
    "07_stage4_6_revenue_pipeline_decomposition.R",
    "07a_uncertainty.R",
    "08_measurement_and_cbcr_extensions.R",
    "09_econometric_and_reallocation_extensions.R",
    "10_accounting_bridge_and_conduit_wedge.R",
    "11_policy_game_and_variance_extensions.R",
    "12_master_scorecard.R",
    "13_generate_exhibits.R"
  )) run_script(script)
}

if (sys.nframe() == 0L) main()
