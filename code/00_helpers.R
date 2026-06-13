# Shared small utilities used across the GMT pipeline.

source(if (file.exists("code/00_config.R")) {
  "code/00_config.R"
} else {
  file.path("..", "..", "code/00_config.R")
})

source_pipeline_script <- function(path) {
  if (file.exists(path)) {
    source(path)
  } else {
    source(file.path("..", "..", path))
  }
}

is_direct_script_run <- function(script_path) {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) == 0) return(FALSE)

  invoked_path <- sub("^--file=", "", file_arg[1])
  normalizePath(invoked_path, winslash = "/", mustWork = FALSE) ==
    normalizePath(script_path, winslash = "/", mustWork = FALSE)
}

assert_unique_keys <- function(df, keys, label) {
  missing_keys <- setdiff(keys, names(df))
  if (length(missing_keys) > 0L) {
    stop(sprintf(
      "%s: missing key column(s): %s",
      label,
      paste(missing_keys, collapse = ", ")
    ), call. = FALSE)
  }

  key_df <- df[, keys, drop = FALSE]
  duplicated_keys <- duplicated(key_df) | duplicated(key_df, fromLast = TRUE)
  n_dup <- nrow(unique(key_df[duplicated_keys, , drop = FALSE]))

  if (n_dup > 0) {
    stop(sprintf("%s: %d duplicate key combinations", label, n_dup),
         call. = FALSE)
  }

  invisible(TRUE)
}

left_join_checked <- function(x, y, by, label) {
  if (!is.character(by)) {
    stop(label, ": `by` must be a character vector understood by dplyr joins",
         call. = FALSE)
  }

  if (is.null(names(by))) {
    left_keys <- by
  } else {
    left_keys <- names(by)
    unnamed_keys <- left_keys == ""
    left_keys[unnamed_keys] <- by[unnamed_keys]
  }
  right_keys <- unname(by)

  missing_left <- setdiff(left_keys, names(x))
  missing_right <- setdiff(right_keys, names(y))
  if (length(missing_left) > 0L || length(missing_right) > 0L) {
    stop(
      label,
      ": missing join key column(s). Left missing: ",
      paste(missing_left, collapse = ", "),
      "; right missing: ",
      paste(missing_right, collapse = ", "),
      call. = FALSE
    )
  }

  n_before <- nrow(x)
  assert_unique_keys(y, right_keys, paste0(label, " right-hand side"))
  out <- dplyr::left_join(x, y, by = by)
  if (nrow(out) != n_before) {
    stop(sprintf(
      "%s expanded row count from %d to %d despite unique right-hand keys",
      label, n_before, nrow(out)
    ), call. = FALSE)
  }
  out
}

safe_divide <- function(num, den) {
  dplyr::if_else(is.na(num) | is.na(den) | den == 0, NA_real_, num / den)
}

coalesce_zero <- function(x) {
  dplyr::if_else(is.na(x), 0, x)
}

clamp_unit_interval <- function(x) {
  pmin(pmax(x, 0), 1)
}

weighted_mean_available <- function(x, w) {
  keep <- !is.na(x) & !is.na(w) & w > 0
  if (!any(keep)) return(NA_real_)
  stats::weighted.mean(x[keep], w[keep])
}

safe_cor <- function(x, y, method = "pearson", min_pairs = 3L) {
  keep <- is.finite(x) & is.finite(y)
  if (sum(keep) < min_pairs) return(NA_real_)
  if (length(unique(x[keep])) < 2 || length(unique(y[keep])) < 2) return(NA_real_)
  stats::cor(x[keep], y[keep], method = method)
}

solve_crossprod_checked <- function(x, label) {
  x <- as.matrix(x)
  xtx <- crossprod(x)
  xtx_rank <- qr(xtx)$rank
  if (xtx_rank < ncol(xtx)) {
    stop(sprintf(
      "%s: cross-product matrix is rank deficient (%d < %d)",
      label, xtx_rank, ncol(xtx)
    ), call. = FALSE)
  }
  solve(xtx)
}

first_non_missing <- function(x) {
  idx <- which(!is.na(x))
  if (length(idx) == 0) return(x[NA_integer_][1])
  x[idx[1]]
}

min_date_or_na <- function(x) {
  x <- as.Date(x)
  if (all(is.na(x))) return(as.Date(NA))
  min(x, na.rm = TRUE)
}
