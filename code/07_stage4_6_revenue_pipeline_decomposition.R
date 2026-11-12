source("code/07_stage4_6_revenue_pipeline_decomposition_functions.R")

if (is_direct_script_run("code/07_stage4_6_revenue_pipeline_decomposition.R")) {
  run_stage4_6_pipeline(write_latex = !"--diagnostics-only" %in% commandArgs(trailingOnly = TRUE))
}
