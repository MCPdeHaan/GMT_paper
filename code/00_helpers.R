# Small utility functions used across the GMT pipeline.

source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "00_config.R"), local = TRUE)
source(file.path(GMT_PROJECT_ROOT, "code", "rates", "statutory_rates.R"), local = TRUE)

# Resolve imports on first use in the sourcing environment. This preserves the
# bare names used in stored model calls without attaching packages on source.
declare_gmt_imports <- function(package, symbols, target = parent.frame()) {
  for (name in base::setdiff(symbols, ls(target, all.names = TRUE))) {
    eval(substitute(
      delayedAssign(NAME, getExportedValue(PACKAGE, NAME), assign.env = target),
      list(NAME = name, PACKAGE = package)
    ))
  }
  invisible(NULL)
}

declare_gmt_imports("dplyr", c(
  "%>%", "across", "all_of", "anti_join", "any_of", "arrange", "between",
  "bind_cols", "bind_rows", "case_when", "coalesce", "count", "dense_rank",
  "desc", "distinct", "ends_with", "everything", "filter", "first",
  "full_join", "group_by", "group_modify", "group_split", "group_vars",
  "if_all", "if_any", "if_else", "inner_join", "intersect", "lag", "last",
  "left_join", "matches", "min_rank", "mutate", "n", "n_distinct",
  "percent_rank", "pick", "pull", "recode", "reframe", "relocate", "rename",
  "rename_with", "row_number", "rowwise", "select", "semi_join", "setdiff",
  "setequal", "slice", "slice_head", "slice_max", "slice_min", "starts_with",
  "summarise", "syms", "top_n", "transmute", "ungroup", "union", "where"
))
declare_gmt_imports("tidyr", c(
  "complete", "crossing", "expand_grid", "nesting", "pivot_longer",
  "pivot_wider", "replace_na", "separate", "spread", "unnest"
))
declare_gmt_imports("readr", c(
  "col_character", "col_date", "col_double", "col_guess", "col_integer",
  "col_logical", "cols", "parse_number", "read_csv", "spec", "write_csv"
))
declare_gmt_imports("purrr", c(
  "imap_dfr", "iwalk", "map", "map_chr", "map_dbl", "map_dfr", "map2",
  "map2_dbl", "pmap", "pmap_dfr", "set_names"
))
declare_gmt_imports("tibble", c("as_tibble", "rownames_to_column", "tibble", "tribble"))
declare_gmt_imports("stringr", c(
  "fixed", "str_count", "str_detect", "str_ends", "str_replace",
  "str_replace_all", "str_split", "str_sub", "str_to_lower", "str_to_sentence"
))

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

# Check whether this script was run directly from the command line, to fix many errors
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

winsorise <- function(x, probs = ETR_WINSOR_PROBS) {
  bounds <- stats::quantile(x, probs, na.rm = TRUE, names = FALSE)
  pmin(pmax(x, bounds[1]), bounds[2])
}

rank01 <- function(x) {
  x <- as.numeric(x)
  keep <- is.finite(x) & !is.na(x)
  out <- rep(0.5, length(x))

  if (sum(keep) > 1 && length(unique(x[keep])) > 1) {
    out[keep] <- dplyr::percent_rank(x[keep])
    out[!keep] <- stats::median(out[keep], na.rm = TRUE)
  }

  out
}

# Fast two way within transformation for an unbalanced pair x year panel.
group_mean_matrix <- function(mat, group) {
  group <- factor(group)
  sums <- rowsum(mat, group, reorder = TRUE)
  counts <- as.vector(tabulate(as.integer(group), nbins = nlevels(group)))
  means <- sweep(sums, 1, counts, "/")
  means[as.integer(group), , drop = FALSE]
}

demean_two_way <- function(mat, fe1, fe2, tol = 1e-10, max_iter = 100L) {
  out <- as.matrix(mat)

  for (i in seq_len(max_iter)) {
    old <- out
    out <- out - group_mean_matrix(out, fe1)
    out <- out - group_mean_matrix(out, fe2)

    if (max(abs(out - old), na.rm = TRUE) < tol) break
  }

  out
}

cluster_vcov <- function(x, residuals, cluster, df_resid_full) {
  x <- as.matrix(x)
  cluster <- factor(cluster)
  bread <- solve(crossprod(x))
  scores <- x * as.numeric(residuals)
  meat <- matrix(0, ncol(x), ncol(x))

  for (g in levels(cluster)) {
    sg <- colSums(scores[cluster == g, , drop = FALSE])
    meat <- meat + tcrossprod(sg)
  }

  g_count <- nlevels(cluster)
  n <- nrow(x)
  correction <- if (g_count > 1 && df_resid_full > 0) {
    g_count / (g_count - 1) * (n - 1) / df_resid_full
  } else {
    1
  }

  correction * bread %*% meat %*% bread
}

cluster_vcov_twoway <- function(x, residuals, cluster_a, cluster_b,
                                df_resid_full) {
  cluster_ab <- interaction(cluster_a, cluster_b, drop = TRUE)

  cluster_vcov(x, residuals, cluster_a, df_resid_full) +
    cluster_vcov(x, residuals, cluster_b, df_resid_full) -
    cluster_vcov(x, residuals, cluster_ab, df_resid_full)
}

format_bn <- function(x, digits = 1) {
  formatC(x / 1e9, format = "f", digits = digits, big.mark = ",")
}

format_pct <- function(x, digits = 1) {
  formatC(100 * x, format = "f", digits = digits)
}

signed_log1p <- function(x) {
  sign(x) * log1p(abs(x))
}

nan_to_na <- function(x) {
  dplyr::if_else(is.nan(x), NA_real_, x)
}

build_h4_pairs <- function(revenue_country_year) {
  other_factors <- c(
    "rate_scenario", "factor1_etr", "factor2_substance",
    "factor5_behaviour", "country", "country_name", "year"
  )

  revenue_country_year |>
    dplyr::select(dplyr::all_of(other_factors), factor4_sbs, revenue) |>
    tidyr::pivot_wider(names_from = factor4_sbs, values_from = revenue) |>
    dplyr::mutate(delta_sbs_minus_universal = sbs - universal)
}

# Orthogonal contrasts for the production five-factor design.
factorial_binary_components <- function(df) {
  design <- df |>
    dplyr::arrange(scenario_id) |>
    dplyr::mutate(dplyr::across(dplyr::all_of(FACTOR_COLS),
      ~ dplyr::if_else(as.integer(.x) == 1L, 1, -1)))
  y <- design$revenue
  x <- stats::model.matrix(
    ~ x1_etr * x2_substance * x3_rates * x4_sbs * x5_behaviour,
    data = design
  )
  coefs <- as.numeric(crossprod(x, y) / colSums(x^2))
  names(coefs) <- colnames(x)
  list(coefs = coefs[-1],
       ss = (coefs[-1]^2) * colSums(x[, -1, drop = FALSE]^2),
       total_ss = sum((y - mean(y))^2))
}
