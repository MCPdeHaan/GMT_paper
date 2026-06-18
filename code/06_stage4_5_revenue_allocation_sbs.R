# 06_stage4_5_revenue_allocation_sbs.R
# Entry point for Stage 4.5 revenue allocation.

source("code/06_stage4_5_revenue_allocation_sbs_functions.R")

if (is_direct_script_run("code/06_stage4_5_revenue_allocation_sbs.R")) {
  run_stage4_5_pipeline()
}
