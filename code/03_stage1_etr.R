# 03_stage1_etr.R
# Step 3 of the methodology pipeline.
#
# Implements Stage 1 of the GMT revenue pipeline on top of the merged bilateral
# base panel from code/02_base_correction_and_merging.R. The script builds an
# affiliate-year ETR measurement object, then maps the resulting low-tax share
# and average top-up rate back to the bilateral corrected profit base.
library(dplyr)
library(tidyr)
library(readr)
library(purrr)
library(tibble)

source("code/00_helpers.R")

IN <- "data/processed"
OUT <- IN
DIAG <- file.path(OUT, "diagnostics")
dir.create(DIAG, showWarnings = FALSE, recursive = TRUE)

DIRECT_YEARS <- 2019:2022
PERCENTILE_YEARS <- 2021:2022
BSPI_TV_FLAG <- 0.39

T4_POSITIVE_BRACKETS <- c("rate_0_15", "rate_15", "rate_20_30", "rate_30")
PERCENTILE_PROBS <- c(0.05, 0.25, 0.50, 0.75, 0.95)
BETA_PRECISION_LOG_BOUNDS <- log(c(1e-4, 1e6))
BETA_BOUNDARY_EPS <- 1e-8

condition_stage1_percentiles <- function(q) {
  q |>
    pmax(0) |>
    pmin(1) |>
    cummax()
}

empty_beta_fit <- function() {
  list(
    alpha = NA_real_,
    beta = NA_real_,
    precision = NA_real_,
    mean = NA_real_,
    sse = NA_real_,
    mae = NA_real_,
    max_abs_error = NA_real_,
    boundary_flag = NA,
    quantiles = rep(NA_real_, length(PERCENTILE_PROBS))
  )
}

beta_quantiles <- function(probs, alpha, beta) {
  precision <- alpha + beta
  mean <- alpha / precision

  if (precision > 1e5) {
    return(rep(mean, length(probs)))
  }
  suppressWarnings(stats::qbeta(probs, alpha, beta))
}

fit_constrained_beta_percentiles <- function(q, target_mean,
                                             probs = PERCENTILE_PROBS) {
  if (is.na(target_mean) || any(is.na(q))) {
    return(empty_beta_fit())
  }

  q <- condition_stage1_percentiles(q)
  target_mean <- pmin(pmax(target_mean, 0), 1)

  if (target_mean <= BETA_BOUNDARY_EPS) {
    q_fit <- rep(0, length(probs))
    return(list(
      alpha = NA_real_,
      beta = NA_real_,
      precision = NA_real_,
      mean = 0,
      sse = sum((q_fit - q)^2),
      mae = mean(abs(q_fit - q)),
      max_abs_error = max(abs(q_fit - q)),
      boundary_flag = TRUE,
      quantiles = q_fit
    ))
  }

  if (target_mean >= 1 - BETA_BOUNDARY_EPS) {
    q_fit <- rep(1, length(probs))
    return(list(
      alpha = NA_real_,
      beta = NA_real_,
      precision = NA_real_,
      mean = 1,
      sse = sum((q_fit - q)^2),
      mae = mean(abs(q_fit - q)),
      max_abs_error = max(abs(q_fit - q)),
      boundary_flag = TRUE,
      quantiles = q_fit
    ))
  }

  objective <- function(log_precision) {
    precision <- exp(log_precision)
    alpha <- target_mean * precision
    beta <- (1 - target_mean) * precision
    q_fit <- beta_quantiles(probs, alpha, beta)

    if (any(!is.finite(q_fit))) {
      return(.Machine$double.xmax)
    }
    sum((q_fit - q)^2)
  }

  opt <- stats::optimize(objective, interval = BETA_PRECISION_LOG_BOUNDS)
  precision <- exp(opt$minimum)
  alpha <- target_mean * precision
  beta <- (1 - target_mean) * precision
  q_fit <- beta_quantiles(probs, alpha, beta)

  list(
    alpha = alpha,
    beta = beta,
    precision = precision,
    mean = alpha / (alpha + beta),
    sse = sum((q_fit - q)^2),
    mae = mean(abs(q_fit - q)),
    max_abs_error = max(abs(q_fit - q)),
    boundary_flag = FALSE,
    quantiles = q_fit
  )
}

beta_mass_below <- function(alpha, beta, threshold = GMT_RATE,
                            boundary_mean = NA_real_) {
  if (!is.na(boundary_mean)) {
    return(as.numeric(threshold >= boundary_mean))
  }
  if (is.na(alpha) || is.na(beta)) {
    return(NA_real_)
  }
  stats::pbeta(threshold, alpha, beta)
}

beta_first_moment_below <- function(alpha, beta, threshold = GMT_RATE,
                                    boundary_mean = NA_real_) {
  if (!is.na(boundary_mean)) {
    return(if (threshold >= boundary_mean) boundary_mean else 0)
  }
  if (is.na(alpha) || is.na(beta)) {
    return(NA_real_)
  }

  mean <- alpha / (alpha + beta)
  mean * stats::pbeta(threshold, alpha + 1, beta)
}

beta_avg_topup_rate <- function(alpha, beta, threshold = GMT_RATE,
                                boundary_mean = NA_real_) {
  low_share <- beta_mass_below(alpha, beta, threshold, boundary_mean)
  if (is.na(low_share) || low_share <= 0) {
    return(0)
  }

  low_mean_etr <- beta_first_moment_below(
    alpha, beta, threshold, boundary_mean
  ) / low_share
  pmax(0, threshold - pmin(pmax(low_mean_etr, 0), threshold))
}

beta_mass_between <- function(alpha, beta, lower, upper,
                              boundary_mean = NA_real_) {
  beta_mass_below(alpha, beta, upper, boundary_mean) -
    beta_mass_below(alpha, beta, lower, boundary_mean)
}

beta_bracket_shares <- function(alpha, beta, boundary_mean = NA_real_) {
  rate_0_15 <- beta_mass_below(alpha, beta, 0.15, boundary_mean)
  rate_15 <- beta_mass_between(alpha, beta, 0.15, 0.20, boundary_mean)
  rate_20_30 <- beta_mass_between(alpha, beta, 0.20, 0.30, boundary_mean)
  rate_30 <- 1 - rate_0_15 - rate_15 - rate_20_30

  c(
    rate_0_15  = rate_0_15,
    rate_15    = rate_15,
    rate_20_30 = rate_20_30,
    rate_30    = rate_30
  )
}

average_rule_metrics <- function(avg_etr, threshold = GMT_RATE) {
  if (is.na(avg_etr)) {
    return(c(low_share = NA_real_, topup_rate = NA_real_))
  }

  low_share <- as.numeric(avg_etr < threshold)
  topup_rate <- if_else(low_share == 1, threshold - avg_etr, 0)
  c(low_share = low_share, topup_rate = topup_rate)
}

direct_rule_metrics <- function(low_profit, low_tax, positive_profit_total,
                                threshold = GMT_RATE) {
  if (is.na(positive_profit_total) || positive_profit_total <= 0) {
    return(c(low_share = NA_real_, low_mean_etr = NA_real_, topup_rate = NA_real_))
  }

  if (is.na(low_profit) || low_profit <= 0) {
    return(c(low_share = 0, low_mean_etr = 0, topup_rate = 0))
  }

  low_mean_etr <- safe_divide(low_tax, low_profit)
  low_mean_etr <- if_else(is.na(low_mean_etr), NA_real_,
    pmin(pmax(low_mean_etr, 0), threshold)
  )
  topup_rate <- if_else(is.na(low_mean_etr), NA_real_, threshold - low_mean_etr)

  c(
    low_share = safe_divide(low_profit, positive_profit_total),
    low_mean_etr = low_mean_etr,
    topup_rate = topup_rate
  )
}

choose_distributional_source <- function(year, direct_available,
                                         percentile_available, bspi_available,
                                         average_available) {
  case_when(
    year %in% DIRECT_YEARS & direct_available ~ "direct_t4",
    year %in% PERCENTILE_YEARS & percentile_available ~ "percentile_fit",
    year %in% BSPI_IMPUTE_YEARS & bspi_available ~ "shape_transport",
    average_available ~ "avg_only",
    TRUE ~ "missing"
  )
}

choose_percentile_affiliate_year_source <- function(affiliate_is_eu27,
                                                    panelai_available,
                                                    t_fallback_available) {
  case_when(
    affiliate_is_eu27 & panelai_available ~ "panelai",
    affiliate_is_eu27 ~ "missing",
    panelai_available ~ "panelai",
    t_fallback_available ~ "t_fallback",
    TRUE ~ "missing"
  )
}

run_stage1_pipeline <- function() {
  panel <- readRDS(file.path(IN, "base_panel.rds")) |>
    filter(year %in% MAIN_YEARS)
  t4_brackets <- readRDS(file.path(IN, "base_panel_t4_bracket_shares.rds"))

  affiliate_year_base <- panel |>
    group_by(affiliate, year) |>
    summarise(
      affiliate_name = first(affiliate_jurisdiction_name),
      affiliate_is_eu27 = first(affiliate_is_eu27),
      n_pair_years = n(),
      total_analysis_profit_positive = sum(
        pmax(coalesce(analysis_profit_base, 0), 0),
        na.rm = TRUE
      ),
      total_analysis_profit_signed = sum(
        coalesce(analysis_profit_base, 0),
        na.rm = TRUE
      ),
      avg_profit_denominator = sum(
        analysis_profit_base[!is.na(profit_panelai) &
          profit_panelai > 0 &
          !is.na(analysis_profit_base) &
          analysis_profit_base > 0],
        na.rm = TRUE
      ),
      avg_profit_denominator_uncorrected = sum(
        profit_panelai[!is.na(profit_panelai) & profit_panelai > 0],
        na.rm = TRUE
      ),
      avg_tax_numerator = sum(
        tax_accrued_panelai[!is.na(profit_panelai) &
          profit_panelai > 0 &
          !is.na(analysis_profit_base) &
          analysis_profit_base > 0],
        na.rm = TRUE
      ),
      affiliate_cit_rate = first_non_missing(affiliate_cit_rate),
      affiliate_cit_rate_unit = first_non_missing(affiliate_cit_rate_unit),
      .groups = "drop"
    ) |>
    mutate(
      avg_etr_raw = if_else(
        avg_profit_denominator > 0,
        avg_tax_numerator / avg_profit_denominator,
        NA_real_
      ),
      avg_profit_denominator_correction_rate = safe_divide(
        avg_profit_denominator_uncorrected - avg_profit_denominator,
        avg_profit_denominator_uncorrected
      ),
      affiliate_etr_cap_stage1 = case_when(
        !is.na(affiliate_cit_rate_unit) ~
          pmin(1, affiliate_cit_rate_unit + ZETA_LOSS_OFFSET),
        TRUE ~ 1
      ),
      avg_etr_stage1 = case_when(
        is.na(avg_etr_raw) ~ NA_real_,
        TRUE ~ pmin(pmax(avg_etr_raw, 0), affiliate_etr_cap_stage1)
      )
    )

  # Average ETR branch: treats the affiliate-year mean ETR as representative
  # of all positive profits. This is the conservative fallback when the public
  # CbCR distributional tables cannot support a lower-tail split.
  average_metrics <- affiliate_year_base |>
    rowwise() |>
    mutate(
      avg_metrics = list(average_rule_metrics(avg_etr_stage1))
    ) |>
    ungroup() |>
    mutate(
      average_low_share = map_dbl(avg_metrics, "low_share"),
      average_topup_rate = map_dbl(avg_metrics, "topup_rate"),
      average_liability_rate = average_low_share * average_topup_rate
    ) |>
    select(-avg_metrics)

  # Percentile/Beta branch: fits a bounded ETR distribution from public
  # percentile tables, then integrates the mass below the 15 per cent floor.
  percentile_rows <- panel |>
    filter(year %in% PERCENTILE_YEARS, has_any_percentile_set)

  percentile_panelai <- percentile_rows |>
    filter(has_panelai_percentiles) |>
    mutate(
      percentile_source_selected = "panelai",
      weight_primary = subgroups_count_panelai,
      weight_used = coalesce(
        weight_primary,
        entities_count_panelai,
        subgroups_count,
        entities_count,
        1
      ),
      percentile_weight_fallback_row = is.na(weight_primary),
      p5_raw = etr_p5_panelai,
      p25_raw = etr_p25_panelai,
      p50_raw = etr_p50_panelai,
      p75_raw = etr_p75_panelai,
      p95_raw = etr_p95_panelai
    ) |>
    group_by(affiliate, year) |>
    summarise(
      n_pair_years_percentile = n(),
      percentile_weight_fallback_used = any(percentile_weight_fallback_row),
      percentile_weight_sum = sum(weight_used[!is.na(weight_used)], na.rm = TRUE),
      q5_raw = weighted_mean_available(p5_raw, weight_used),
      q25_raw = weighted_mean_available(p25_raw, weight_used),
      q50_raw = weighted_mean_available(p50_raw, weight_used),
      q75_raw = weighted_mean_available(p75_raw, weight_used),
      q95_raw = weighted_mean_available(p95_raw, weight_used),
      .groups = "drop"
    ) |>
    mutate(percentile_source_selected = "panelai")

  percentile_t_fallback <- percentile_rows |>
    filter(has_t_fallback_percentiles) |>
    mutate(
      percentile_source_selected = "t_fallback",
      weight_primary = subgroups_count,
      weight_used = coalesce(weight_primary, entities_count, 1),
      percentile_weight_fallback_row = is.na(weight_primary),
      p5_raw = etr_p5,
      p25_raw = etr_p25,
      p50_raw = etr_p50,
      p75_raw = etr_p75,
      p95_raw = etr_p95
    ) |>
    group_by(affiliate, year) |>
    summarise(
      n_pair_years_percentile = n(),
      percentile_weight_fallback_used = any(percentile_weight_fallback_row),
      percentile_weight_sum = sum(weight_used[!is.na(weight_used)], na.rm = TRUE),
      q5_raw = weighted_mean_available(p5_raw, weight_used),
      q25_raw = weighted_mean_available(p25_raw, weight_used),
      q50_raw = weighted_mean_available(p50_raw, weight_used),
      q75_raw = weighted_mean_available(p75_raw, weight_used),
      q95_raw = weighted_mean_available(p95_raw, weight_used),
      .groups = "drop"
    ) |>
    mutate(percentile_source_selected = "t_fallback")

  percentile_candidates <- bind_rows(percentile_panelai, percentile_t_fallback)

  assert_unique_keys(
    percentile_candidates,
    c("affiliate", "year", "percentile_source_selected"),
    "stage1 percentile candidates"
  )

  percentile_source_availability <- percentile_candidates |>
    group_by(affiliate, year) |>
    summarise(
      panelai_candidate_available =
        any(percentile_source_selected == "panelai"),
      t_fallback_candidate_available =
        any(percentile_source_selected == "t_fallback"),
      percentile_source_combo =
        paste(sort(unique(percentile_source_selected)), collapse = "+"),
      .groups = "drop"
    )

  percentile_affiliate_year <- affiliate_year_base |>
    select(
      affiliate, year, affiliate_is_eu27, avg_etr_stage1,
      total_analysis_profit_positive
    ) |>
    left_join(percentile_source_availability, by = c("affiliate", "year")) |>
    mutate(
      panelai_candidate_available = coalesce(panelai_candidate_available, FALSE),
      t_fallback_candidate_available =
        coalesce(t_fallback_candidate_available, FALSE),
      percentile_source_selected = choose_percentile_affiliate_year_source(
        affiliate_is_eu27 = affiliate_is_eu27,
        panelai_available = panelai_candidate_available,
        t_fallback_available = t_fallback_candidate_available
      ),
      percentile_source_scope = case_when(
        affiliate_is_eu27 ~ "eu27_panelai_only",
        TRUE ~ "non_eu_panelai_then_t"
      )
    ) |>
    filter(percentile_source_selected != "missing") |>
    left_join(
      percentile_candidates,
      by = c("affiliate", "year", "percentile_source_selected")
    ) |>
    rowwise() |>
    mutate(
      percentile_raw = list(c(q5_raw, q25_raw, q50_raw, q75_raw, q95_raw)),
      percentile_raw_non_monotone = any(diff(unlist(percentile_raw)) < 0),
      percentile_raw_out_of_support = any(unlist(percentile_raw) < 0 |
        unlist(percentile_raw) > 1),
      percentile_conditioned = list(
        condition_stage1_percentiles(unlist(percentile_raw))
      ),
      percentile_conditioning_flag = any(abs(
        unlist(percentile_conditioned) - unlist(percentile_raw)
      ) > 1e-12),
      percentile_conditioning_max_abs_change = max(abs(
        unlist(percentile_conditioned) - unlist(percentile_raw)
      )),
      percentile_beta_fit = list(fit_constrained_beta_percentiles(
        unlist(percentile_conditioned),
        avg_etr_stage1
      )),
      percentile_beta_alpha = percentile_beta_fit$alpha,
      percentile_beta_beta = percentile_beta_fit$beta,
      percentile_beta_precision = percentile_beta_fit$precision,
      percentile_beta_mean = percentile_beta_fit$mean,
      percentile_beta_sse = percentile_beta_fit$sse,
      percentile_beta_mae = percentile_beta_fit$mae,
      percentile_beta_max_abs_error = percentile_beta_fit$max_abs_error,
      percentile_beta_boundary_flag = percentile_beta_fit$boundary_flag,
      percentile_beta_mean_gap = percentile_beta_mean - avg_etr_stage1,
      percentile_fitted = list(percentile_beta_fit$quantiles),
      percentile_beta_boundary_mean = if_else(
        percentile_beta_boundary_flag,
        percentile_beta_mean,
        NA_real_
      ),
      percentile_low_share = beta_mass_below(
        percentile_beta_alpha,
        percentile_beta_beta,
        GMT_RATE,
        percentile_beta_boundary_mean
      ),
      percentile_topup_rate = beta_avg_topup_rate(
        percentile_beta_alpha,
        percentile_beta_beta,
        GMT_RATE,
        percentile_beta_boundary_mean
      ),
      percentile_liability_rate = percentile_low_share * percentile_topup_rate,
      percentile_bracket_shares = list(
        beta_bracket_shares(
          percentile_beta_alpha,
          percentile_beta_beta,
          percentile_beta_boundary_mean
        )
      )
    ) |>
    ungroup() |>
    mutate(
      percentile_q5 = map_dbl(percentile_fitted, 1),
      percentile_q25 = map_dbl(percentile_fitted, 2),
      percentile_q50 = map_dbl(percentile_fitted, 3),
      percentile_q75 = map_dbl(percentile_fitted, 4),
      percentile_q95 = map_dbl(percentile_fitted, 5),
      percentile_iqr = percentile_q75 - percentile_q25,
      percentile_rate_0_15 = map_dbl(percentile_bracket_shares, "rate_0_15"),
      percentile_rate_15 = map_dbl(percentile_bracket_shares, "rate_15"),
      percentile_rate_20_30 = map_dbl(percentile_bracket_shares, "rate_20_30"),
      percentile_rate_30 = map_dbl(percentile_bracket_shares, "rate_30")
    ) |>
    select(
      affiliate, year,
      n_pair_years_percentile, percentile_source_scope,
      percentile_source_selected, percentile_source_combo,
      panelai_candidate_available, t_fallback_candidate_available,
      percentile_weight_fallback_used, percentile_weight_sum,
      q5_raw, q25_raw, q50_raw, q75_raw, q95_raw,
      percentile_raw_non_monotone, percentile_raw_out_of_support,
      percentile_conditioning_flag, percentile_conditioning_max_abs_change,
      percentile_beta_alpha, percentile_beta_beta, percentile_beta_precision,
      percentile_beta_mean, percentile_beta_mean_gap,
      percentile_beta_sse, percentile_beta_mae, percentile_beta_max_abs_error,
      percentile_beta_boundary_flag,
      percentile_q5, percentile_q25, percentile_q50, percentile_q75, percentile_q95,
      percentile_iqr, percentile_low_share, percentile_topup_rate,
      percentile_liability_rate, percentile_rate_0_15, percentile_rate_15,
      percentile_rate_20_30, percentile_rate_30
    )

  # Direct Table IV branch: uses observed low-tax bracket shares when Table IV
  # directly partitions positive profit by ETR band.
  direct_affiliate_year <- t4_brackets |>
    filter(year %in% DIRECT_YEARS, etr_bracket %in% T4_POSITIVE_BRACKETS) |>
    group_by(affiliate, year) |>
    summarise(
      direct_has_partition = TRUE,
      direct_positive_profit_total = sum(pmax(profit, 0), na.rm = TRUE),
      direct_low_profit = sum(if_else(etr_bracket == "rate_0_15", pmax(profit, 0), 0),
        na.rm = TRUE
      ),
      direct_low_tax = sum(if_else(etr_bracket == "rate_0_15", tax_accrued, 0),
        na.rm = TRUE
      ),
      direct_rate_0_15 = sum(
        if_else(etr_bracket == "rate_0_15",
          coalesce(bracket_profit_share, 0), 0
        ),
        na.rm = TRUE
      ),
      direct_rate_15 = sum(
        if_else(etr_bracket == "rate_15",
          coalesce(bracket_profit_share, 0), 0
        ),
        na.rm = TRUE
      ),
      direct_rate_20_30 = sum(
        if_else(etr_bracket == "rate_20_30",
          coalesce(bracket_profit_share, 0), 0
        ),
        na.rm = TRUE
      ),
      direct_rate_30 = sum(
        if_else(etr_bracket == "rate_30",
          coalesce(bracket_profit_share, 0), 0
        ),
        na.rm = TRUE
      ),
      .groups = "drop"
    ) |>
    rowwise() |>
    mutate(
      direct_metrics = list(
        direct_rule_metrics(
          low_profit = direct_low_profit,
          low_tax = direct_low_tax,
          positive_profit_total = direct_positive_profit_total,
          threshold = GMT_RATE
        )
      )
    ) |>
    ungroup() |>
    mutate(
      direct_low_share = map_dbl(direct_metrics, "low_share"),
      direct_low_mean_etr = map_dbl(direct_metrics, "low_mean_etr"),
      direct_topup_rate = map_dbl(direct_metrics, "topup_rate"),
      direct_liability_rate = direct_low_share * direct_topup_rate,
      direct_zero_low_share_flag = direct_has_partition & direct_low_share == 0
    ) |>
    select(-direct_metrics)

  # BSPI branch: transports stable Table IV bracket shapes from anchor years
  # into 2017 and 2018, when the direct distributional table is unavailable.
  bspi_anchor <- direct_affiliate_year |>
    filter(year %in% BSPI_ANCHOR_YEARS) |>
    group_by(affiliate) |>
    summarise(
      bspi_has_anchor = TRUE,
      bspi_anchor_years_observed = n(),
      bspi_anchor_positive_profit = sum(direct_positive_profit_total, na.rm = TRUE),
      bspi_anchor_low_profit = sum(direct_low_profit, na.rm = TRUE),
      bspi_anchor_low_tax = sum(direct_low_tax, na.rm = TRUE),
      bspi_low_share = safe_divide(
        bspi_anchor_low_profit,
        bspi_anchor_positive_profit
      ),
      bspi_low_mean_etr = if_else(
        bspi_anchor_low_profit > 0,
        bspi_anchor_low_tax / bspi_anchor_low_profit,
        0
      ),
      bspi_topup_rate = if_else(
        bspi_anchor_low_profit > 0,
        pmax(0, GMT_RATE - pmin(pmax(bspi_low_mean_etr, 0), GMT_RATE)),
        0
      ),
      .groups = "drop"
    )

  bspi_support <- direct_affiliate_year |>
    mutate(window = case_when(
      year %in% BSPI_ANCHOR_YEARS ~ "anchor",
      year %in% BSPI_VALIDATION_YEARS ~ "validation",
      TRUE ~ NA_character_
    )) |>
    filter(!is.na(window)) |>
    count(affiliate, window, name = "n_years_observed") |>
    pivot_wider(
      names_from = window,
      values_from = n_years_observed,
      values_fill = 0
    ) |>
    rename(
      anchor_years_observed = anchor,
      validation_years_observed = validation
    )

  bspi_profile <- t4_brackets |>
    filter(
      year %in% c(BSPI_ANCHOR_YEARS, BSPI_VALIDATION_YEARS),
      etr_bracket %in% T4_POSITIVE_BRACKETS
    ) |>
    mutate(
      window = case_when(
        year %in% BSPI_ANCHOR_YEARS ~ "anchor",
        year %in% BSPI_VALIDATION_YEARS ~ "validation",
        TRUE ~ NA_character_
      ),
      bracket_profit = pmax(profit, 0)
    ) |>
    group_by(affiliate, window, etr_bracket) |>
    summarise(bracket_profit = sum(bracket_profit, na.rm = TRUE), .groups = "drop") |>
    group_by(affiliate, window) |>
    mutate(
      window_total = sum(bracket_profit, na.rm = TRUE),
      bracket_share = safe_divide(bracket_profit, window_total)
    ) |>
    ungroup() |>
    group_by(affiliate, window) |>
    complete(
      etr_bracket = T4_POSITIVE_BRACKETS,
      fill = list(bracket_profit = 0, window_total = 0, bracket_share = 0)
    ) |>
    ungroup() |>
    select(affiliate, window, etr_bracket, bracket_share) |>
    pivot_wider(
      names_from = c(window, etr_bracket),
      values_from = bracket_share,
      values_fill = 0
    ) |>
    left_join(bspi_support, by = "affiliate") |>
    mutate(
      bspi_validation_supported =
        anchor_years_observed > 0 & validation_years_observed > 0,
      bspi_tv_anchor_validation = if_else(
        bspi_validation_supported,
        0.5 * (
          abs(anchor_rate_0_15 - validation_rate_0_15) +
            abs(anchor_rate_15 - validation_rate_15) +
            abs(anchor_rate_20_30 - validation_rate_20_30) +
            abs(anchor_rate_30 - validation_rate_30)
        ),
        NA_real_
      ),
      bspi_high_tv_flag = bspi_validation_supported &
        bspi_tv_anchor_validation > BSPI_TV_FLAG
    )

  bspi_validation <- direct_affiliate_year |>
    filter(year %in% BSPI_ANCHOR_YEARS) |>
    group_by(affiliate) |>
    summarise(
      anchor_low_share = weighted_mean_available(
        direct_low_share,
        direct_positive_profit_total
      ),
      anchor_low_mean_etr = weighted_mean_available(
        direct_low_mean_etr,
        direct_low_profit
      ),
      anchor_topup_rate = weighted_mean_available(
        direct_topup_rate,
        direct_low_profit
      ),
      .groups = "drop"
    ) |>
    left_join(
      direct_affiliate_year |>
        filter(year %in% BSPI_VALIDATION_YEARS) |>
        group_by(affiliate) |>
        summarise(
          validation_low_share = weighted_mean_available(
            direct_low_share,
            direct_positive_profit_total
          ),
          validation_low_mean_etr = weighted_mean_available(
            direct_low_mean_etr,
            direct_low_profit
          ),
          validation_topup_rate = weighted_mean_available(
            direct_topup_rate,
            direct_low_profit
          ),
          .groups = "drop"
        ),
      by = "affiliate"
    ) |>
    left_join(
      bspi_profile |>
        select(
          affiliate, anchor_years_observed, validation_years_observed,
          bspi_validation_supported, bspi_tv_anchor_validation, bspi_high_tv_flag
        ),
      by = "affiliate"
    ) |>
    mutate(
      bspi_low_share_gap = validation_low_share - anchor_low_share,
      bspi_topup_rate_gap = validation_topup_rate - anchor_topup_rate,
      bspi_low_mean_etr_gap = validation_low_mean_etr - anchor_low_mean_etr
    )

  # Branch selection: combine direct, fitted percentile, transported shape and
  # average ETR evidence into one affiliate-year low-tax profit estimate.
  affiliate_year_stage1 <- affiliate_year_base |>
    left_join(
      average_metrics |>
        select(
          affiliate, year,
          average_low_share, average_topup_rate, average_liability_rate
        ),
      by = c("affiliate", "year")
    ) |>
    left_join(percentile_affiliate_year, by = c("affiliate", "year")) |>
    left_join(direct_affiliate_year, by = c("affiliate", "year")) |>
    left_join(bspi_anchor, by = "affiliate") |>
    left_join(bspi_validation, by = "affiliate") |>
    mutate(
      direct_available = coalesce(direct_has_partition, FALSE),
      percentile_available = !is.na(percentile_low_share),
      bspi_available = year %in% BSPI_IMPUTE_YEARS & coalesce(bspi_has_anchor, FALSE),
      average_available = !is.na(average_low_share),
      stage1_distributional_source = choose_distributional_source(
        year = year,
        direct_available = direct_available,
        percentile_available = percentile_available,
        bspi_available = bspi_available,
        average_available = average_available
      ),
      stage1_distributional_low_share = case_when(
        stage1_distributional_source == "direct_t4" ~ direct_low_share,
        stage1_distributional_source == "percentile_fit" ~ percentile_low_share,
        stage1_distributional_source == "shape_transport" ~ bspi_low_share,
        stage1_distributional_source == "avg_only" ~ average_low_share,
        TRUE ~ NA_real_
      ),
      stage1_distributional_topup_rate = case_when(
        stage1_distributional_source == "direct_t4" ~ direct_topup_rate,
        stage1_distributional_source == "percentile_fit" ~ percentile_topup_rate,
        stage1_distributional_source == "shape_transport" ~ bspi_topup_rate,
        stage1_distributional_source == "avg_only" ~ average_topup_rate,
        TRUE ~ NA_real_
      ),
      stage1_distributional_liability_rate =
        stage1_distributional_low_share * stage1_distributional_topup_rate,
      stage1_distributional_source_strict = case_when(
        stage1_distributional_source == "shape_transport" &
          coalesce(bspi_validation_supported, FALSE) &
          coalesce(bspi_high_tv_flag, FALSE) ~ "avg_only_high_tv",
        TRUE ~ stage1_distributional_source
      ),
      stage1_distributional_low_share_strict = case_when(
        stage1_distributional_source_strict == "avg_only_high_tv" ~ average_low_share,
        TRUE ~ stage1_distributional_low_share
      ),
      stage1_distributional_topup_rate_strict = case_when(
        stage1_distributional_source_strict == "avg_only_high_tv" ~ average_topup_rate,
        TRUE ~ stage1_distributional_topup_rate
      ),
      stage1_distributional_liability_rate_strict =
        stage1_distributional_low_share_strict * stage1_distributional_topup_rate_strict,
      stage1_positive_profit_flag = total_analysis_profit_positive > 0
    )

  # Cross-validation diagnostics: compare fitted percentile rates against
  # direct Table IV rates in years where both public sources overlap.
  crossval_affiliate_year <- affiliate_year_stage1 |>
    filter(
      year %in% BSPI_VALIDATION_YEARS,
      stage1_positive_profit_flag,
      percentile_available,
      direct_available
    ) |>
    mutate(
      low_share_diff = percentile_low_share - direct_low_share,
      low_share_abs_error = abs(low_share_diff),
      topup_rate_diff = percentile_topup_rate - direct_topup_rate,
      liability_rate_diff = percentile_liability_rate - direct_liability_rate,
      liability_rate_abs_error = abs(liability_rate_diff),
      liability_rate_rel_diff = safe_divide(
        liability_rate_diff,
        direct_liability_rate
      ),
      tv_positive_partition = 0.5 * (
        abs(percentile_rate_0_15 - direct_rate_0_15) +
          abs(percentile_rate_15 - direct_rate_15) +
          abs(percentile_rate_20_30 - direct_rate_20_30) +
          abs(percentile_rate_30 - direct_rate_30)
      )
    )

  crossval_calibration_sample <- crossval_affiliate_year |>
    filter(
      is.finite(direct_low_share),
      is.finite(percentile_low_share)
    )

  crossval_calibration <- if (
    nrow(crossval_calibration_sample) >= 3 &&
      n_distinct(crossval_calibration_sample$percentile_low_share) > 1
  ) {
    crossval_calibration_fit <- stats::lm(
      direct_low_share ~ percentile_low_share + factor(year),
      data = crossval_calibration_sample
    )

    crossval_calibration_summary <- summary(crossval_calibration_fit)

    as.data.frame(crossval_calibration_summary$coefficients) |>
      rownames_to_column("term") |>
      as_tibble() |>
      rename(
        estimate = Estimate,
        std_error = `Std. Error`,
        statistic = `t value`,
        p_value = `Pr(>|t|)`
      ) |>
      mutate(
        n_obs = stats::nobs(crossval_calibration_fit),
        r_squared = crossval_calibration_summary$r.squared,
        adj_r_squared = crossval_calibration_summary$adj.r.squared
      )
  } else {
    tibble(
      term = NA_character_,
      estimate = NA_real_,
      std_error = NA_real_,
      statistic = NA_real_,
      p_value = NA_real_,
      n_obs = NA_real_,
      r_squared = NA_real_,
      adj_r_squared = NA_real_
    )
  }

  # Bilateral mapping: transport the selected affiliate-year low-tax rate back
  # to each parent-affiliate cell so later stages preserve the CbCR spine.
  bilateral_stage1 <- panel |>
    left_join(
      affiliate_year_stage1 |>
        select(
          affiliate, year,
          stage1_positive_profit_flag,
          average_low_share, average_topup_rate, average_liability_rate,
          stage1_distributional_source, stage1_distributional_low_share,
          stage1_distributional_topup_rate, stage1_distributional_liability_rate,
          stage1_distributional_source_strict,
          stage1_distributional_low_share_strict,
          stage1_distributional_topup_rate_strict,
          stage1_distributional_liability_rate_strict,
          direct_zero_low_share_flag, bspi_high_tv_flag
        ),
      by = c("affiliate", "year")
    ) |>
    mutate(
      analysis_profit_positive = pmax(coalesce(analysis_profit_base, 0), 0),
      stage1_lowtax_profit_average = average_low_share * analysis_profit_positive,
      stage1_topup_tax_average = stage1_lowtax_profit_average * average_topup_rate,
      stage1_lowtax_profit_distributional =
        stage1_distributional_low_share * analysis_profit_positive,
      stage1_topup_tax_distributional =
        stage1_lowtax_profit_distributional * stage1_distributional_topup_rate,
      stage1_lowtax_profit_distributional_strict =
        stage1_distributional_low_share_strict * analysis_profit_positive,
      stage1_topup_tax_distributional_strict =
        stage1_lowtax_profit_distributional_strict *
          stage1_distributional_topup_rate_strict
    )

  assert_unique_keys(affiliate_year_stage1, c("affiliate", "year"), "stage1 affiliate-year")
  assert_unique_keys(bilateral_stage1, c("parent", "affiliate", "year"), "stage1 bilateral")

  percentile_sum_error <- affiliate_year_stage1 |>
    filter(percentile_available) |>
    transmute(
      share_sum = percentile_rate_0_15 + percentile_rate_15 +
        percentile_rate_20_30 + percentile_rate_30
    )

  direct_sum_error <- affiliate_year_stage1 |>
    filter(direct_available) |>
    transmute(
      share_sum = direct_rate_0_15 + direct_rate_15 +
        direct_rate_20_30 + direct_rate_30
    )

  if (max(abs(percentile_sum_error$share_sum - 1), na.rm = TRUE) > 1e-8) {
    stop("Percentile-implied positive bracket shares do not sum to one")
  }

  if (max(abs(direct_sum_error$share_sum - 1), na.rm = TRUE) > 1e-8) {
    stop("Direct Table IV positive bracket shares do not sum to one")
  }

  if (any(affiliate_year_stage1$stage1_distributional_low_share < 0, na.rm = TRUE) ||
    any(affiliate_year_stage1$stage1_distributional_low_share > 1, na.rm = TRUE)) {
    stop("Hybrid Stage 1 low-tax shares leave [0, 1]")
  }

  if (any(affiliate_year_stage1$stage1_distributional_topup_rate < 0, na.rm = TRUE) ||
    any(affiliate_year_stage1$stage1_distributional_topup_rate > GMT_RATE, na.rm = TRUE)) {
    stop("Hybrid Stage 1 top-up rates leave [0, GMT_RATE]")
  }

  if (any(bilateral_stage1$stage1_topup_tax_distributional < 0, na.rm = TRUE)) {
    stop("Hybrid Stage 1 top-up tax turned negative")
  }

  stage1_summary <- tibble(
    metric = c(
      "affiliate_years_total",
      "affiliate_years_positive_profit",
      "pair_years_total",
      "pair_years_positive_profit",
      "direct_partition_affiliate_years",
      "direct_zero_low_share_affiliate_years",
      "percentile_affiliate_years",
      "percentile_conditioned_affiliate_years",
      "percentile_weight_fallback_affiliate_years",
      "percentile_beta_boundary_affiliate_years",
      "percentile_beta_mean_mismatch_affiliate_years",
      "percentile_beta_fit_mae_mean",
      "bspi_anchor_affiliates_distinct",
      "bspi_validation_affiliates_distinct",
      "bspi_high_tv_affiliates_distinct",
      "hybrid_direct_affiliate_years",
      "hybrid_percentile_affiliate_years",
      "hybrid_shape_transport_affiliate_years",
      "hybrid_avg_only_affiliate_years",
      "hybrid_shape_transport_strict_fallback_affiliate_years",
      "hybrid_shape_transport_strict_fallback_affiliates_distinct",
      "avg_etr_anchor_uncorrected_profit_denominator",
      "avg_etr_anchor_corrected_profit_denominator",
      "avg_etr_anchor_profit_correction_rate",
      "crossval_affiliate_years",
      "crossval_zero_low_share_cases",
      "crossval_wilcox_low_share_pvalue",
      "crossval_wilcox_liability_pvalue",
      "crossval_rel_diff_regression_rows"
    ),
    value = c(
      nrow(affiliate_year_stage1),
      sum(affiliate_year_stage1$stage1_positive_profit_flag, na.rm = TRUE),
      nrow(bilateral_stage1),
      sum(bilateral_stage1$analysis_profit_positive > 0, na.rm = TRUE),
      sum(affiliate_year_stage1$direct_available, na.rm = TRUE),
      sum(affiliate_year_stage1$direct_zero_low_share_flag, na.rm = TRUE),
      sum(affiliate_year_stage1$percentile_available, na.rm = TRUE),
      sum(affiliate_year_stage1$percentile_conditioning_flag, na.rm = TRUE),
      sum(affiliate_year_stage1$percentile_weight_fallback_used, na.rm = TRUE),
      sum(affiliate_year_stage1$percentile_beta_boundary_flag, na.rm = TRUE),
      sum(abs(affiliate_year_stage1$percentile_beta_mean_gap) > 1e-8, na.rm = TRUE),
      mean(affiliate_year_stage1$percentile_beta_mae, na.rm = TRUE),
      n_distinct(affiliate_year_stage1$affiliate[
        coalesce(affiliate_year_stage1$bspi_has_anchor, FALSE)
      ]),
      n_distinct(affiliate_year_stage1$affiliate[
        coalesce(affiliate_year_stage1$bspi_validation_supported, FALSE)
      ]),
      n_distinct(affiliate_year_stage1$affiliate[
        coalesce(affiliate_year_stage1$bspi_high_tv_flag, FALSE)
      ]),
      sum(affiliate_year_stage1$stage1_distributional_source == "direct_t4", na.rm = TRUE),
      sum(affiliate_year_stage1$stage1_distributional_source == "percentile_fit", na.rm = TRUE),
      sum(affiliate_year_stage1$stage1_distributional_source == "shape_transport", na.rm = TRUE),
      sum(affiliate_year_stage1$stage1_distributional_source == "avg_only", na.rm = TRUE),
      sum(affiliate_year_stage1$stage1_distributional_source_strict == "avg_only_high_tv",
        na.rm = TRUE
      ),
      n_distinct(affiliate_year_stage1$affiliate[
        affiliate_year_stage1$stage1_distributional_source_strict == "avg_only_high_tv"
      ]),
      sum(affiliate_year_stage1$avg_profit_denominator_uncorrected, na.rm = TRUE),
      sum(affiliate_year_stage1$avg_profit_denominator, na.rm = TRUE),
      safe_divide(
        sum(affiliate_year_stage1$avg_profit_denominator_uncorrected, na.rm = TRUE) -
          sum(affiliate_year_stage1$avg_profit_denominator, na.rm = TRUE),
        sum(affiliate_year_stage1$avg_profit_denominator_uncorrected, na.rm = TRUE)
      ),
      nrow(crossval_affiliate_year),
      sum(crossval_affiliate_year$direct_zero_low_share_flag, na.rm = TRUE),
      stats::wilcox.test(crossval_affiliate_year$low_share_diff,
        mu = 0,
        exact = FALSE
      )$p.value,
      stats::wilcox.test(crossval_affiliate_year$liability_rate_diff,
        mu = 0,
        exact = FALSE
      )$p.value,
      sum(!is.na(crossval_affiliate_year$liability_rate_rel_diff))
    )
  )

  stage1_branch_by_year <- affiliate_year_stage1 |>
    filter(stage1_positive_profit_flag) |>
    group_by(year, stage1_distributional_source) |>
    summarise(
      affiliate_years = n(),
      total_positive_profit = sum(total_analysis_profit_positive, na.rm = TRUE),
      profit_weighted_low_share = weighted_mean_available(
        stage1_distributional_low_share,
        total_analysis_profit_positive
      ),
      profit_weighted_topup_rate = weighted_mean_available(
        stage1_distributional_topup_rate,
        total_analysis_profit_positive
      ),
      profit_weighted_liability_rate = weighted_mean_available(
        stage1_distributional_liability_rate,
        total_analysis_profit_positive
      ),
      .groups = "drop"
    ) |>
    arrange(year, stage1_distributional_source)

  stage1_pair_year_branch_by_year <- bilateral_stage1 |>
    count(year, stage1_distributional_source, name = "pair_years") |>
    arrange(year, stage1_distributional_source)

  stage1_bspi_tv_summary <- bspi_profile |>
    mutate(affiliate_is_eu27 = affiliate %in% EU27_ISO3) |>
    filter(bspi_validation_supported) |>
    group_by(scope = if_else(affiliate_is_eu27, "eu27", "non_eu")) |>
    summarise(
      affiliates = n(),
      high_tv_flagged = sum(bspi_high_tv_flag, na.rm = TRUE),
      tv_median = median(bspi_tv_anchor_validation, na.rm = TRUE),
      tv_p75 = stats::quantile(bspi_tv_anchor_validation, 0.75, na.rm = TRUE),
      tv_p90 = stats::quantile(bspi_tv_anchor_validation, 0.90, na.rm = TRUE),
      tv_max = max(bspi_tv_anchor_validation, na.rm = TRUE),
      .groups = "drop"
    )

  stage1_scenario_by_year <- bind_rows(
    affiliate_year_stage1 |>
      filter(stage1_positive_profit_flag) |>
      mutate(scope = "global"),
    affiliate_year_stage1 |>
      filter(stage1_positive_profit_flag, affiliate_is_eu27) |>
      mutate(scope = "eu27")
  ) |>
    group_by(scope, year) |>
    summarise(
      affiliate_years = n(),
      total_positive_profit = sum(total_analysis_profit_positive, na.rm = TRUE),
      average_low_share = weighted_mean_available(
        average_low_share,
        total_analysis_profit_positive
      ),
      average_topup_rate = weighted_mean_available(
        average_topup_rate,
        total_analysis_profit_positive
      ),
      average_liability_rate = weighted_mean_available(
        average_liability_rate,
        total_analysis_profit_positive
      ),
      distributional_low_share = weighted_mean_available(
        stage1_distributional_low_share,
        total_analysis_profit_positive
      ),
      distributional_topup_rate = weighted_mean_available(
        stage1_distributional_topup_rate,
        total_analysis_profit_positive
      ),
      distributional_liability_rate = weighted_mean_available(
        stage1_distributional_liability_rate,
        total_analysis_profit_positive
      ),
      .groups = "drop"
    ) |>
    arrange(scope, year)

  stage1_conditioning_by_year <- affiliate_year_stage1 |>
    filter(percentile_available) |>
    group_by(year) |>
    summarise(
      affiliate_years = n(),
      raw_non_monotone = sum(percentile_raw_non_monotone, na.rm = TRUE),
      raw_out_of_support = sum(percentile_raw_out_of_support, na.rm = TRUE),
      conditioned = sum(percentile_conditioning_flag, na.rm = TRUE),
      weight_fallback_used = sum(percentile_weight_fallback_used, na.rm = TRUE),
      beta_boundary_cells = sum(percentile_beta_boundary_flag, na.rm = TRUE),
      mean_abs_conditioning_change = mean(
        percentile_conditioning_max_abs_change,
        na.rm = TRUE
      ),
      mean_beta_fit_mae = mean(percentile_beta_mae, na.rm = TRUE),
      max_beta_fit_mae = max(percentile_beta_mae, na.rm = TRUE),
      mean_beta_fit_max_abs_error = mean(percentile_beta_max_abs_error, na.rm = TRUE),
      max_beta_fit_max_abs_error = max(percentile_beta_max_abs_error, na.rm = TRUE),
      mean_abs_beta_mean_gap = mean(abs(percentile_beta_mean_gap), na.rm = TRUE),
      max_abs_beta_mean_gap = max(abs(percentile_beta_mean_gap), na.rm = TRUE),
      .groups = "drop"
    )

  crossval_regression_sample <- crossval_affiliate_year |>
    filter(
      !is.na(percentile_iqr),
      !is.na(liability_rate_rel_diff),
      is.finite(liability_rate_rel_diff)
    )

  crossval_regression <- if (nrow(crossval_regression_sample) > 0) {
    crossval_fit <- stats::lm(
      liability_rate_rel_diff ~ percentile_iqr + factor(year),
      data = crossval_regression_sample
    )

    crossval_fit_summary <- summary(crossval_fit)

    as.data.frame(crossval_fit_summary$coefficients) |>
      rownames_to_column("term") |>
      as_tibble() |>
      rename(
        estimate = Estimate,
        std_error = `Std. Error`,
        statistic = `t value`,
        p_value = `Pr(>|t|)`
      ) |>
      mutate(
        n_obs = stats::nobs(crossval_fit),
        r_squared = crossval_fit_summary$r.squared,
        adj_r_squared = crossval_fit_summary$adj.r.squared
      )
  } else {
    tibble(
      term = NA_character_,
      estimate = NA_real_,
      std_error = NA_real_,
      statistic = NA_real_,
      p_value = NA_real_,
      n_obs = NA_real_,
      r_squared = NA_real_,
      adj_r_squared = NA_real_
    )
  }

  stage1_crossval_summary <- tibble(
    metric = c(
      "overlap_affiliate_years",
      "overlap_zero_low_share_cases",
      "low_share_mean_diff",
      "low_share_median_diff",
      "low_share_mae",
      "low_share_rmse",
      "low_share_p90_abs_error",
      "low_share_spearman",
      "low_share_calibration_slope",
      "low_share_calibration_pvalue",
      "low_share_calibration_r_squared",
      "topup_rate_mean_diff",
      "topup_rate_median_diff",
      "liability_rate_mean_diff",
      "liability_rate_median_diff",
      "liability_rate_mae",
      "liability_rate_rmse",
      "liability_rate_p90_abs_error",
      "liability_rate_rel_diff_mean",
      "liability_rate_rel_diff_median",
      "positive_partition_tv_mean",
      "positive_partition_tv_median",
      "positive_partition_tv_p90",
      "crossval_low_share_wilcox_pvalue",
      "crossval_liability_wilcox_pvalue",
      "rel_diff_regression_rows",
      "rel_diff_regression_iqr_beta",
      "rel_diff_regression_iqr_pvalue",
      "rel_diff_regression_r_squared"
    ),
    value = c(
      nrow(crossval_affiliate_year),
      sum(crossval_affiliate_year$direct_zero_low_share_flag, na.rm = TRUE),
      mean(crossval_affiliate_year$low_share_diff, na.rm = TRUE),
      median(crossval_affiliate_year$low_share_diff, na.rm = TRUE),
      mean(abs(crossval_affiliate_year$low_share_diff), na.rm = TRUE),
      sqrt(mean(crossval_affiliate_year$low_share_diff^2, na.rm = TRUE)),
      stats::quantile(crossval_affiliate_year$low_share_abs_error, 0.9,
        na.rm = TRUE
      ),
      safe_cor(crossval_affiliate_year$percentile_low_share,
        crossval_affiliate_year$direct_low_share,
        method = "spearman"
      ),
      crossval_calibration$estimate[
        crossval_calibration$term == "percentile_low_share"
      ][1],
      crossval_calibration$p_value[
        crossval_calibration$term == "percentile_low_share"
      ][1],
      crossval_calibration$r_squared[1],
      mean(crossval_affiliate_year$topup_rate_diff, na.rm = TRUE),
      median(crossval_affiliate_year$topup_rate_diff, na.rm = TRUE),
      mean(crossval_affiliate_year$liability_rate_diff, na.rm = TRUE),
      median(crossval_affiliate_year$liability_rate_diff, na.rm = TRUE),
      mean(abs(crossval_affiliate_year$liability_rate_diff), na.rm = TRUE),
      sqrt(mean(crossval_affiliate_year$liability_rate_diff^2, na.rm = TRUE)),
      stats::quantile(crossval_affiliate_year$liability_rate_abs_error, 0.9,
        na.rm = TRUE
      ),
      mean(crossval_affiliate_year$liability_rate_rel_diff, na.rm = TRUE),
      median(crossval_affiliate_year$liability_rate_rel_diff, na.rm = TRUE),
      mean(crossval_affiliate_year$tv_positive_partition, na.rm = TRUE),
      median(crossval_affiliate_year$tv_positive_partition, na.rm = TRUE),
      stats::quantile(crossval_affiliate_year$tv_positive_partition, 0.9, na.rm = TRUE),
      stats::wilcox.test(crossval_affiliate_year$low_share_diff,
        mu = 0,
        exact = FALSE
      )$p.value,
      stats::wilcox.test(crossval_affiliate_year$liability_rate_diff,
        mu = 0,
        exact = FALSE
      )$p.value,
      nrow(crossval_regression_sample),
      crossval_regression$estimate[crossval_regression$term == "percentile_iqr"][1],
      crossval_regression$p_value[crossval_regression$term == "percentile_iqr"][1],
      crossval_regression$r_squared[1]
    )
  )

  write_csv(stage1_summary, file.path(DIAG, "step3_stage1_summary.csv"))
  write_csv(stage1_branch_by_year, file.path(DIAG, "step3_stage1_branch_by_year.csv"))
  write_csv(
    stage1_pair_year_branch_by_year,
    file.path(DIAG, "step3_stage1_pair_year_branch_by_year.csv")
  )
  write_csv(
    stage1_bspi_tv_summary,
    file.path(DIAG, "step3_stage1_bspi_tv_summary.csv")
  )
  write_csv(stage1_scenario_by_year, file.path(DIAG, "step3_stage1_scenario_by_year.csv"))
  write_csv(
    stage1_conditioning_by_year,
    file.path(DIAG, "step3_stage1_conditioning_by_year.csv")
  )
  write_csv(
    stage1_crossval_summary,
    file.path(DIAG, "step3_stage1_crossval_summary.csv")
  )
  write_csv(
    crossval_regression,
    file.path(DIAG, "step3_stage1_crossval_regression.csv")
  )
  write_csv(
    crossval_calibration,
    file.path(DIAG, "step3_stage1_crossval_calibration.csv")
  )
  write_csv(
    crossval_affiliate_year,
    file.path(DIAG, "step3_stage1_crossval_affiliate_year.csv")
  )
  write_csv(
    bspi_validation,
    file.path(DIAG, "step3_stage1_bspi_validation.csv")
  )

  saveRDS(affiliate_year_stage1, file.path(OUT, "stage1_affiliate_year.rds"))
  saveRDS(bilateral_stage1, file.path(OUT, "stage1_bilateral_panel.rds"))

  message("\nStep 3 outputs written:")
  message(" - data/processed/stage1_affiliate_year.rds")
  message(" - data/processed/stage1_bilateral_panel.rds")
  message(" - diagnostics/step3_stage1_*.csv")
}

if (is_direct_script_run("code/03_stage1_etr.R")) {
  run_stage1_pipeline()
}
