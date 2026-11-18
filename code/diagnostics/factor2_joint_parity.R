# Independent execution of the production joint sampler with a read-only trace.
# The callback stores primary-draw projections and does not consume randomness.
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "00_helpers.R"), local = TRUE)

run_factor2_joint_parity <- function(input_root, output_dir) {
  withr::local_envvar(GMT_FACTOR2_SPECIFICATION = Sys.getenv("GMT_FACTOR2_SPECIFICATION", unset = NA_character_))
  withr::local_preserve_seed()
  source(file.path(GMT_PROJECT_ROOT, "code", "11_policy_game_and_variance_extensions.R"), local = TRUE)
  PROCESSED_DIR <- file.path(normalizePath(input_root, mustWork = TRUE), "data", "processed")
  DIAGNOSTICS_DIR <- file.path(PROCESSED_DIR, "diagnostics")
  destination <- file.path(normalizePath(dirname(output_dir), mustWork = TRUE), basename(output_dir))
  protected <- c(file.path(normalizePath(input_root), c("data", "writing")),
    file.path(normalizePath(GMT_PROJECT_ROOT), c("data", "writing", ".git")))
  if (file.exists(destination) || any(destination == protected | startsWith(destination, paste0(protected, "/")))) {
    stop("Use a fresh diagnostic directory outside data and publication trees", call. = FALSE)
  }
  dir.create(output_dir)
  q <- output_dir
  results <- list()
  traces <- list()
  for (arm in c('historical','revised')) {
   Sys.setenv(GMT_FACTOR2_SPECIFICATION=if(arm=='historical') 'LEGACY_HYBRID_SBIE_SBTI' else 'SECTORAL_SBIE_ONLY')
   input <- step15_inputs()
   point <- step15_evaluate(input,step15_measure(input))$revenue
   original <- step15_evaluate
   index <- 0L
   trace <- vector('list',STEP15_DRAWS)
   step15_evaluate <- function(...) {
     value <- original(...)
     index <<- index+1L
     if(index %% 11L == 8L) {
       draw <- (index-1L) %/% 11L+1L
       trace[[draw]] <<- step15_cumulative(value$revenue,input,1:2)
     }
     value
   }
   result <- step15_monte_carlo(input,point)
   step15_evaluate <- original
   write_csv(result,file.path(q,paste0(arm,'-independent-joint.csv')))
   saveRDS(trace,file.path(q,paste0(arm,'-joint-trace.rds')))
   traces[[arm]] <- trace
   cat(arm,'calls',index,'draws',length(trace),'\n')
  }
  # Joint preferred draws and every aggregate scenario agree at every country
  # and window, even though factorial-wide variance and ranks can change.
  ids <- which(step15_design()$x2_substance==0)
  check <- map_dfr(seq_len(STEP15_DRAWS),function(i) {
   a<-traces$historical[[i]][ids,,drop=FALSE];b<-traces$revised[[i]][ids,,drop=FALSE]
   tibble(draw_id=i,aggregate_entries=length(a),max_absolute_difference_usd_bn=max(abs(a-b)))
  })
  stopifnot(all(check$max_absolute_difference_usd_bn==0))
  write_csv(check,file.path(q,'paired_joint_draw_identity.csv'))
  invisible(check)
}

if (is_direct_script_run("code/diagnostics/factor2_joint_parity.R")) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 2L) stop("Supply an input root and fresh diagnostic directory")
  run_factor2_joint_parity(args[1], args[2])
}
