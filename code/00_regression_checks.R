# Baseline snapshot and comparison helpers for the GMT pipeline.

source("code/00_helpers.R")

pipeline_output_files <- function(path, pattern = NULL, recursive = FALSE) {
  files <- list.files(
    path,
    pattern = pattern,
    full.names = TRUE,
    recursive = recursive,
    all.files = FALSE,
    no.. = TRUE
  )
  files[!dir.exists(files)]
}

copy_files_with_structure <- function(files, from_dir, to_dir, overwrite) {
  for (file in files) {
    rel_path <- substring(file, nchar(from_dir) + 2L)
    target_path <- file.path(to_dir, rel_path)
    dir.create(dirname(target_path), recursive = TRUE, showWarnings = FALSE)
    ok <- file.copy(file, target_path, overwrite = overwrite, copy.date = TRUE)
    if (!ok) {
      stop("Failed to copy output file: ", file, call. = FALSE)
    }
  }
}

empty_difference_table <- function() {
  tibble::tibble(
    area = character(),
    file = character(),
    column = character(),
    current = character(),
    baseline = character(),
    first_row = integer(),
    mismatches = integer(),
    max_abs_diff = double()
  )
}

snapshot_pipeline_outputs <- function(
  processed_dir = PROCESSED_DIR,
  generated_dir = GENERATED_DIR,
  baseline_processed_dir = BASELINE_PROCESSED_DIR,
  baseline_diagnostics_dir = BASELINE_DIAGNOSTICS_DIR,
  baseline_generated_dir = BASELINE_GENERATED_DIR,
  overwrite = FALSE
) {
  processed_dir <- normalizePath(processed_dir, mustWork = TRUE)
  generated_dir <- normalizePath(generated_dir, mustWork = TRUE)
  diagnostics_dir <- normalizePath(
    file.path(processed_dir, "diagnostics"),
    mustWork = TRUE
  )

  targets <- c(
    baseline_processed_dir,
    baseline_diagnostics_dir,
    baseline_generated_dir
  )
  existing_targets <- targets[dir.exists(targets)]
  if (length(existing_targets) > 0L && !overwrite) {
    stop(
      "Baseline target(s) already exist: ",
      paste(existing_targets, collapse = ", "),
      ". Re-run with overwrite = TRUE only if replacing the comparator is intentional.",
      call. = FALSE
    )
  }

  if (overwrite) {
    unlink(existing_targets, recursive = TRUE, force = TRUE)
  }

  dir.create(baseline_processed_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(baseline_diagnostics_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(baseline_generated_dir, recursive = TRUE, showWarnings = FALSE)

  copy_files_with_structure(
    pipeline_output_files(processed_dir, pattern = "\\.rds$"),
    processed_dir,
    baseline_processed_dir,
    overwrite
  )
  copy_files_with_structure(
    pipeline_output_files(diagnostics_dir, pattern = "\\.csv$"),
    diagnostics_dir,
    baseline_diagnostics_dir,
    overwrite
  )
  copy_files_with_structure(
    pipeline_output_files(generated_dir, recursive = TRUE),
    generated_dir,
    baseline_generated_dir,
    overwrite
  )

  invisible(list(
    processed = baseline_processed_dir,
    diagnostics = baseline_diagnostics_dir,
    generated = baseline_generated_dir
  ))
}

first_mismatch_index <- function(current, baseline, tolerance) {
  if (length(current) != length(baseline)) {
    return(min(length(current), length(baseline)) + 1L)
  }

  both_missing <- is.na(current) & is.na(baseline)
  if (is.numeric(current) && is.numeric(baseline)) {
    same <- both_missing |
      (is.finite(current) & is.finite(baseline) &
        abs(current - baseline) <= tolerance) |
      (current == baseline)
  } else {
    same <- both_missing | (!is.na(current) & !is.na(baseline) &
      current == baseline)
  }

  hit <- which(!same)
  if (length(hit) == 0L) NA_integer_ else hit[1]
}

column_difference <- function(current, baseline, file, column, tolerance) {
  first_bad <- first_mismatch_index(current, baseline, tolerance)
  if (is.na(first_bad)) {
    return(NULL)
  }

  both_missing <- is.na(current) & is.na(baseline)
  missing_mismatch <- xor(is.na(current), is.na(baseline))

  if (is.numeric(current) && is.numeric(baseline)) {
    abs_diff <- abs(current - baseline)
    mismatch <- missing_mismatch |
      (!both_missing & is.finite(abs_diff) & abs_diff > tolerance) |
      (!both_missing & xor(is.finite(current), is.finite(baseline)))
    finite_abs_diff <- abs_diff[is.finite(abs_diff)]
    max_abs_diff <- if (length(finite_abs_diff) > 0L) {
      max(finite_abs_diff)
    } else {
      NA_real_
    }
  } else {
    mismatch <- missing_mismatch |
      (!both_missing & as.character(current) != as.character(baseline))
    max_abs_diff <- NA_real_
  }

  tibble::tibble(
    area = "content",
    file = file,
    column = column,
    current = as.character(current[first_bad]),
    baseline = as.character(baseline[first_bad]),
    first_row = first_bad,
    mismatches = sum(mismatch, na.rm = TRUE),
    max_abs_diff = max_abs_diff
  )
}

compare_data_frame_outputs <- function(current, baseline, file,
                                       tolerance = 1e-10) {
  differences <- list()

  if (!identical(names(current), names(baseline))) {
    differences[[length(differences) + 1L]] <- tibble::tibble(
      area = "schema",
      file = file,
      column = NA_character_,
      current = paste(setdiff(names(current), names(baseline)), collapse = ", "),
      baseline = paste(setdiff(names(baseline), names(current)), collapse = ", "),
      first_row = NA_integer_,
      mismatches = abs(length(names(current)) - length(names(baseline))),
      max_abs_diff = NA_real_
    )
  }

  if (nrow(current) != nrow(baseline)) {
    differences[[length(differences) + 1L]] <- tibble::tibble(
      area = "rows",
      file = file,
      column = NA_character_,
      current = as.character(nrow(current)),
      baseline = as.character(nrow(baseline)),
      first_row = NA_integer_,
      mismatches = abs(nrow(current) - nrow(baseline)),
      max_abs_diff = NA_real_
    )
  }

  common_columns <- intersect(names(current), names(baseline))
  common_rows <- seq_len(min(nrow(current), nrow(baseline)))
  for (column in common_columns) {
    diff <- column_difference(
      current[[column]][common_rows],
      baseline[[column]][common_rows],
      file,
      column,
      tolerance
    )
    if (!is.null(diff)) {
      differences[[length(differences) + 1L]] <- diff
    }
  }

  if (length(differences) == 0L) {
    empty_difference_table()
  } else {
    dplyr::bind_rows(differences)
  }
}

compare_rds_output <- function(current_file, baseline_file, label,
                               tolerance) {
  if (!file.exists(current_file)) {
    return(tibble::tibble(
      area = "missing_current",
      file = label,
      column = NA_character_,
      current = NA_character_,
      baseline = basename(baseline_file),
      first_row = NA_integer_,
      mismatches = 1L,
      max_abs_diff = NA_real_
    ))
  }

  current <- readRDS(current_file)
  baseline <- readRDS(baseline_file)

  if (is.data.frame(current) && is.data.frame(baseline)) {
    return(compare_data_frame_outputs(current, baseline, label, tolerance))
  }

  if (identical(current, baseline)) {
    return(empty_difference_table())
  }

  tibble::tibble(
    area = "object",
    file = label,
    column = NA_character_,
    current = digest::digest(current),
    baseline = digest::digest(baseline),
    first_row = NA_integer_,
    mismatches = 1L,
    max_abs_diff = NA_real_
  )
}

compare_csv_output <- function(current_file, baseline_file, label,
                               tolerance) {
  if (!file.exists(current_file)) {
    return(tibble::tibble(
      area = "missing_current",
      file = label,
      column = NA_character_,
      current = NA_character_,
      baseline = basename(baseline_file),
      first_row = NA_integer_,
      mismatches = 1L,
      max_abs_diff = NA_real_
    ))
  }

  current <- readr::read_csv(current_file, show_col_types = FALSE)
  baseline <- readr::read_csv(baseline_file, show_col_types = FALSE)
  compare_data_frame_outputs(current, baseline, label, tolerance)
}

compare_text_output <- function(current_file, baseline_file, label,
                                tolerance = 0) {
  if (!file.exists(current_file)) {
    return(tibble::tibble(
      area = "missing_current",
      file = label,
      column = NA_character_,
      current = NA_character_,
      baseline = basename(baseline_file),
      first_row = NA_integer_,
      mismatches = 1L,
      max_abs_diff = NA_real_
    ))
  }

  current <- readLines(current_file, warn = FALSE)
  baseline <- readLines(baseline_file, warn = FALSE)
  if (identical(current, baseline)) {
    return(empty_difference_table())
  }

  first_bad <- first_mismatch_index(current, baseline, tolerance = 0)
  tibble::tibble(
    area = "text",
    file = label,
    column = NA_character_,
    current = current[first_bad],
    baseline = baseline[first_bad],
    first_row = first_bad,
    mismatches = NA_integer_,
    max_abs_diff = NA_real_
  )
}

compare_file_group <- function(current_dir, baseline_dir, pattern, reader,
                               recursive = FALSE, tolerance = 1e-10) {
  baseline_files <- pipeline_output_files(
    baseline_dir,
    pattern = pattern,
    recursive = recursive
  )
  current_files <- pipeline_output_files(
    current_dir,
    pattern = pattern,
    recursive = recursive
  )

  baseline_rel <- substring(baseline_files, nchar(baseline_dir) + 2L)
  current_rel <- substring(current_files, nchar(current_dir) + 2L)
  common_rel <- sort(intersect(baseline_rel, current_rel))

  differences <- lapply(common_rel, function(file) {
    reader(
      file.path(current_dir, file),
      file.path(baseline_dir, file),
      file,
      tolerance
    )
  })

  missing_current <- setdiff(baseline_rel, current_rel)
  extra_current <- setdiff(current_rel, baseline_rel)

  if (length(missing_current) > 0L) {
    differences[[length(differences) + 1L]] <- tibble::tibble(
      area = "missing_current",
      file = missing_current,
      column = NA_character_,
      current = NA_character_,
      baseline = "present",
      first_row = NA_integer_,
      mismatches = 1L,
      max_abs_diff = NA_real_
    )
  }

  if (length(extra_current) > 0L) {
    differences[[length(differences) + 1L]] <- tibble::tibble(
      area = "extra_current",
      file = extra_current,
      column = NA_character_,
      current = "present",
      baseline = NA_character_,
      first_row = NA_integer_,
      mismatches = 1L,
      max_abs_diff = NA_real_
    )
  }

  if (length(differences) == 0L) {
    empty_difference_table()
  } else {
    dplyr::bind_rows(differences)
  }
}

compare_pipeline_outputs <- function(
  processed_dir = PROCESSED_DIR,
  generated_dir = GENERATED_DIR,
  baseline_processed_dir = BASELINE_PROCESSED_DIR,
  baseline_diagnostics_dir = BASELINE_DIAGNOSTICS_DIR,
  baseline_generated_dir = BASELINE_GENERATED_DIR,
  tolerance = 1e-8
) {
  diagnostics_dir <- file.path(processed_dir, "diagnostics")

  dplyr::bind_rows(
    compare_file_group(
      processed_dir,
      baseline_processed_dir,
      pattern = "\\.rds$",
      reader = compare_rds_output,
      tolerance = tolerance
    ) |>
      dplyr::mutate(group = "processed", .before = area),
    compare_file_group(
      diagnostics_dir,
      baseline_diagnostics_dir,
      pattern = "\\.csv$",
      reader = compare_csv_output,
      tolerance = tolerance
    ) |>
      dplyr::mutate(group = "diagnostics", .before = area),
    compare_file_group(
      generated_dir,
      baseline_generated_dir,
      pattern = "\\.tex$",
      reader = compare_text_output,
      recursive = TRUE,
      tolerance = tolerance
    ) |>
      dplyr::mutate(group = "generated", .before = area)
  ) |>
    dplyr::arrange(group, file, area, column)
}

format_pipeline_differences <- function(differences, n = 25L) {
  if (nrow(differences) == 0L) {
    return("No output differences detected.")
  }

  shown <- utils::head(differences, n)
  paste(
    paste0(
      "Detected ", nrow(differences), " output difference(s). Showing ",
      nrow(shown), "."
    ),
    paste(capture.output(print(shown, n = nrow(shown))), collapse = "\n"),
    sep = "\n"
  )
}

run_regression_check_cli <- function(args = commandArgs(trailingOnly = TRUE)) {
  command <- args[1]
  overwrite <- "--overwrite" %in% args

  if (identical(command, "snapshot")) {
    snapshot_pipeline_outputs(overwrite = overwrite)
    return(invisible(TRUE))
  }

  if (identical(command, "compare")) {
    differences <- compare_pipeline_outputs()
    if (nrow(differences) > 0L) {
      message(format_pipeline_differences(differences))
      stop("Pipeline outputs differ from the baseline.", call. = FALSE)
    }
    message("Pipeline outputs match the baseline.")
    return(invisible(TRUE))
  }

  stop(
    "Usage: Rscript code/00_regression_checks.R snapshot [--overwrite] ",
    "or Rscript code/00_regression_checks.R compare",
    call. = FALSE
  )
}

if (is_direct_script_run("code/00_regression_checks.R")) {
  run_regression_check_cli()
}
