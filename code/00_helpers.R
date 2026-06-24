# Small utility functions used across the GMT pipeline.

source("code/00_config.R")

# Check whether this script was run directly from the command line
# (so that scripts can be both sourced and run standalone).
is_direct_script_run <- function(script_path) {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) == 0) return(FALSE)
  invoked_path <- sub("^--file=", "", file_arg[1])
  normalizePath(invoked_path, winslash = "/", mustWork = FALSE) ==
    normalizePath(script_path, winslash = "/", mustWork = FALSE)
}

# Check that a data frame has no duplicate rows on the given key columns.
assert_unique_keys <- function(df, keys, label) {
  key_df <- df[, keys, drop = FALSE]
  n_dup <- sum(duplicated(key_df))
  if (n_dup > 0) {
    stop(sprintf("%s: %d duplicate key combinations", label, n_dup),
      call. = FALSE
    )
  }
  invisible(TRUE)
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

clamp_interval <- function(x, lower, upper) {
  pmin(pmax(x, lower), upper)
}

normalize_code <- function(x) {
  dplyr::case_when(
    x == "XKX" ~ "XKV",
    TRUE ~ x
  )
}

weighted_mean_available <- function(x, w) {
  keep <- !is.na(x) & !is.na(w) & w > 0
  if (!any(keep)) return(NA_real_)
  stats::weighted.mean(x[keep], w[keep])
}

weighted_mean_clean <- function(x, w) {
  keep <- is.finite(x) & is.finite(w) & w > 0
  if (!any(keep)) return(NA_real_)
  stats::weighted.mean(x[keep], w[keep])
}

weighted_rate_clean <- function(amount, weight) {
  keep <- is.finite(amount) & is.finite(weight) & weight > 0
  if (!any(keep)) return(NA_real_)
  sum(amount[keep], na.rm = TRUE) / sum(weight[keep], na.rm = TRUE)
}

bounded_logit <- function(
  rho,
  upper_bound = PROFIT_RECONCILIATION_UPPER_BOUND,
  eps = PROFIT_RECONCILIATION_EPS_RHO
) {
  stats::qlogis(clamp_interval(rho / upper_bound, eps, 1 - eps))
}

inverse_bounded_logit <- function(
  x,
  upper_bound = PROFIT_RECONCILIATION_UPPER_BOUND
) {
  upper_bound * stats::plogis(x)
}

rho_to_logit_se <- function(
  rho,
  rho_se,
  upper_bound = PROFIT_RECONCILIATION_UPPER_BOUND,
  eps = PROFIT_RECONCILIATION_EPS_RHO
) {
  rho_safe <- clamp_interval(rho, eps, upper_bound - eps)
  derivative <- (1 / rho_safe) + (1 / (upper_bound - rho_safe))
  clamp_interval(rho_se * derivative, 0.08, 3.50)
}

sum_or_na <- function(x) {
  if (all(is.na(x))) return(NA_real_)
  sum(x, na.rm = TRUE)
}

max_or_na <- function(x) {
  finite_x <- x[!is.na(x)]
  if (length(finite_x) == 0) return(NA_real_)
  max(finite_x)
}

pick_first_non_missing <- function(x) {
  idx <- which(!is.na(x) & x != "")
  if (length(idx) == 0) return(NA_character_)
  x[idx[1]]
}

normalise_share <- function(x) {
  total <- sum(x, na.rm = TRUE)
  if (is.na(total) || total <= 0) return(rep(NA_real_, length(x)))
  x / total
}

row_min_or_na <- function(...) {
  out <- pmin(..., na.rm = TRUE)
  out[is.infinite(out)] <- NA_real_
  out
}

safe_log1p_scale <- function(x, scale) {
  dplyr::if_else(!is.na(x) & x > 0, log1p(x / scale), 0)
}

normalise_tax_rate_unit <- function(x) {
  dplyr::if_else(!is.na(x) & abs(x) > 1, x / 100, x)
}

latex_escape <- function(x) {
  x <- as.character(x)
  placeholder <- "\001BACKSLASH\001"
  x <- gsub("\\", placeholder, x, fixed = TRUE)
  x <- gsub("&", "\\&", x, fixed = TRUE)
  x <- gsub("%", "\\%", x, fixed = TRUE)
  x <- gsub("$", "\\$", x, fixed = TRUE)
  x <- gsub("#", "\\#", x, fixed = TRUE)
  x <- gsub("_", "\\_", x, fixed = TRUE)
  x <- gsub("{", "\\{", x, fixed = TRUE)
  x <- gsub("}", "\\}", x, fixed = TRUE)
  x <- gsub("~", "\\textasciitilde{}", x, fixed = TRUE)
  x <- gsub("^", "\\textasciicircum{}", x, fixed = TRUE)
  x <- gsub(placeholder, "\\textbackslash{}", x, fixed = TRUE)
  x
}

safe_cor <- function(x, y, method = "pearson", min_pairs = 3L) {
  keep <- is.finite(x) & is.finite(y)
  if (sum(keep) < min_pairs) return(NA_real_)
  if (length(unique(x[keep])) < 2 || length(unique(y[keep])) < 2) {
    return(NA_real_)
  }
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
