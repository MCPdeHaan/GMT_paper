# Reproduce the GMT thesis pipeline in the intended execution order.

source("code/00_config.R")
source("code/00_helpers.R")

source_pipeline_script("code/01_data_cleaning.R")
source_pipeline_script("code/02_base_correction_and_merging.R")
source_pipeline_script("code/03_stage1_etr.R")
source_pipeline_script("code/04_stage2_sbie.R")
source_pipeline_script("code/05_stage3_behavioral.R")
source_pipeline_script("code/06_stage4_5_revenue_allocation_sbs.R")
source_pipeline_script("code/07_stage4_6_revenue_pipeline_decomposition.R")
source_pipeline_script("code/09_stage1_measurement_error_simulation.R")
source_pipeline_script("code/10_jurisdiction_influence_robustness.R")
source_pipeline_script("code/11_sesh_notch_bunching_diagnostic.R")
source_pipeline_script("code/08_generate_results_tables.R")

run_all <- function(run_optional_diagnostics = TRUE,
                    measurement_error_draws = MEASUREMENT_ERROR_DRAWS,
                    measurement_error_seed = MEASUREMENT_ERROR_SEED,
                    influence_top_n = DEFAULT_TOP_N) {
  run_data_cleaning(raw_dir = RAW_DIR, out_dir = PROCESSED_DIR)
  run_base_panel(in_dir = PROCESSED_DIR, out_dir = PROCESSED_DIR)
  run_stage1_pipeline()
  run_stage2_pipeline()
  run_stage3_pipeline()
  run_stage4_5_pipeline()
  run_stage4_6_pipeline()

  if (isTRUE(run_optional_diagnostics)) {
    run_stage1_measurement_error_simulation(
      n_draws = measurement_error_draws,
      seed = measurement_error_seed
    )
    run_jurisdiction_influence_suite(top_n = influence_top_n)
    run_sesh_notch_bunching_diagnostic()
  }

  write_results_tables()

  invisible(TRUE)
}

if (is_direct_script_run("run_all.R")) {
  run_all()
}
