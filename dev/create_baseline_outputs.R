create_baseline_outputs <- function(processed_dir = "data/processed",
                                    generated_dir = "writing/generated",
                                    baseline_processed_dir = "data/baseline_processed",
                                    baseline_diagnostics_dir = "data/baseline_diagnostics",
                                    baseline_generated_dir = "writing/baseline_generated",
                                    overwrite = FALSE) {
  stopifnot(is.character(processed_dir), length(processed_dir) == 1L)
  stopifnot(is.character(generated_dir), length(generated_dir) == 1L)

  processed_dir <- normalizePath(processed_dir, mustWork = TRUE)
  generated_dir <- normalizePath(generated_dir, mustWork = TRUE)
  diagnostics_dir <- file.path(processed_dir, "diagnostics")

  if (!dir.exists(diagnostics_dir)) {
    stop("Diagnostics directory does not exist: ", diagnostics_dir, call. = FALSE)
  }

  targets <- c(baseline_processed_dir, baseline_diagnostics_dir,
               baseline_generated_dir)
  existing_targets <- targets[dir.exists(targets)]
  if (length(existing_targets) > 0L && !overwrite) {
    stop(
      "Baseline target(s) already exist: ",
      paste(existing_targets, collapse = ", "),
      ". Re-run with overwrite = TRUE only if you intend to replace the comparator.",
      call. = FALSE
    )
  }

  if (overwrite) {
    unlink(existing_targets, recursive = TRUE, force = TRUE)
  }

  dir.create(baseline_processed_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(baseline_diagnostics_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(baseline_generated_dir, recursive = TRUE, showWarnings = FALSE)

  processed_files <- list.files(processed_dir, full.names = TRUE,
                                all.files = TRUE, no.. = TRUE)
  processed_files <- processed_files[file.info(processed_files)$isdir == FALSE]
  if (length(processed_files) > 0L) {
    ok <- file.copy(processed_files, baseline_processed_dir,
                    overwrite = overwrite, copy.date = TRUE)
    if (!all(ok)) {
      stop("Failed to copy some processed files into ",
           baseline_processed_dir, call. = FALSE)
    }
  }

  diagnostic_files <- list.files(diagnostics_dir, full.names = TRUE,
                                 all.files = TRUE, no.. = TRUE)
  diagnostic_files <- diagnostic_files[file.info(diagnostic_files)$isdir == FALSE]
  if (length(diagnostic_files) > 0L) {
    ok <- file.copy(diagnostic_files, baseline_diagnostics_dir,
                    overwrite = overwrite, copy.date = TRUE)
    if (!all(ok)) {
      stop("Failed to copy some diagnostic files into ",
           baseline_diagnostics_dir, call. = FALSE)
    }
  }

  generated_files <- list.files(generated_dir, full.names = TRUE,
                                recursive = TRUE, all.files = TRUE,
                                no.. = TRUE)
  for (file in generated_files) {
    rel_path <- substring(file, nchar(generated_dir) + 2L)
    target_path <- file.path(baseline_generated_dir, rel_path)
    if (dir.exists(file)) {
      dir.create(target_path, recursive = TRUE, showWarnings = FALSE)
    } else {
      dir.create(dirname(target_path), recursive = TRUE, showWarnings = FALSE)
      ok <- file.copy(file, target_path, overwrite = overwrite,
                      copy.date = TRUE)
      if (!ok) {
        stop("Failed to copy generated file: ", file, call. = FALSE)
      }
    }
  }

  invisible(list(
    processed = baseline_processed_dir,
    diagnostics = baseline_diagnostics_dir,
    generated = baseline_generated_dir
  ))
}

if (identical(environment(), globalenv())) {
  args <- commandArgs(trailingOnly = TRUE)
  overwrite <- "--overwrite" %in% args
  create_baseline_outputs(overwrite = overwrite)
}
