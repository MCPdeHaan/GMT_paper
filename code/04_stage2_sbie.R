# 04_stage2_sbie.R
# Entry point for Stage 2 SBIE calculations.

source("code/04_stage2_sbie_functions.R")

if (is_direct_script_run("code/04_stage2_sbie.R")) {
  run_stage2_pipeline()
}
