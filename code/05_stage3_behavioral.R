# 05_stage3_behavioral.R
# Entry point for Stage 3 behavioural response estimation.

source("code/05_stage3_behavioral_functions.R")

if (is_direct_script_run("code/05_stage3_behavioral.R")) {
  run_stage3_pipeline()
}
