# Shared constants and small utilities used across the GMT pipeline.

PROCESSED_DIR <- "data/processed"
DIAGNOSTICS_DIR <- file.path(PROCESSED_DIR, "diagnostics")

MAIN_YEARS <- 2017:2022
GMT_RATE <- 0.15

EU27_ISO3 <- c(
  "AUT", "BEL", "BGR", "CYP", "CZE", "DEU", "DNK", "ESP", "EST", "FIN",
  "FRA", "GRC", "HRV", "HUN", "IRL", "ITA", "LTU", "LUX", "LVA", "MLT",
  "NLD", "POL", "PRT", "ROU", "SVK", "SVN", "SWE"
)

SELECTED_COUNTRIES <- c("NLD", "IRL", "LUX", "DEU", "FRA")

SCENARIO_VARS <- c(
  "scenario_id", "rate_scenario", "factor1_etr", "factor2_substance",
  "factor3_rates", "factor4_sbs", "factor5_behaviour", "x1_etr",
  "x2_substance", "x3_rates", "x4_sbs", "x5_behaviour"
)

FACTOR_COLS <- c(
  "x1_etr", "x2_substance", "x3_rates", "x4_sbs", "x5_behaviour"
)

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
  key_df <- df[, keys, drop = FALSE]
  duplicated_keys <- duplicated(key_df) | duplicated(key_df, fromLast = TRUE)
  n_dup <- nrow(unique(key_df[duplicated_keys, , drop = FALSE]))

  if (n_dup > 0) {
    stop(sprintf("%s: %d duplicate key combinations", label, n_dup))
  }
}

left_join_checked <- function(x, y, by, label) {
  n_before <- nrow(x)
  assert_unique_keys(y, unname(by), label)
  out <- dplyr::left_join(x, y, by = by)
  if (nrow(out) != n_before) stop(sprintf("%s changed row count", label))
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
