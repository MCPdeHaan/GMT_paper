# 03_stage1_etr.R
# Implements Stage 1 of the GMT revenue pipeline on top of the merged bilateral
# base panel from code/02_base_correction_and_merging.R. The script builds an
# affiliate-year ETR measurement object, then maps the resulting low-tax share
# and average top-up rate back to the bilateral corrected profit base.

source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "00_helpers.R"), local = TRUE)
source(file.path(GMT_PROJECT_ROOT, "code", "measurement", "beta_fit.R"), local = TRUE)


DIRECT_YEARS <- 2019:2023
PERCENTILE_YEARS <- 2021:2023
BSPI_TV_FLAG <- 0.39

T4_POSITIVE_BRACKETS <- T4_DIRECT_POSITIVE_BRACKETS

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

pool_panelai_percentiles <- function(panel) {
  panel |>
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
}

# Require observations on both sides of the threshold. A published zero
# carries information; a suppressed or absent profit or tax value does not.
summarise_observed_t4 <- function(brackets, keys) {
  brackets |>
    filter(year %in% DIRECT_YEARS, etr_bracket %in% T4_POSITIVE_BRACKETS) |>
    group_by(across(all_of(keys))) |>
    summarise(
      t4_positive_profit = sum(pmax(profit, 0), na.rm = TRUE),
      t4_low_profit = sum(pmax(profit[etr_bracket == "rate_0_15"], 0), na.rm = TRUE),
      t4_low_tax = sum_or_na(tax_accrued[etr_bracket == "rate_0_15"]),
      t4_has_low = any(etr_bracket == "rate_0_15" & is.finite(profit) & profit >= 0),
      t4_has_upper = any(etr_bracket != "rate_0_15" & is.finite(profit) & profit >= 0),
      .groups = "drop"
    ) |>
    mutate(
      t4_available = t4_has_low & t4_has_upper &
        is.finite(t4_positive_profit) & t4_positive_profit > 0 &
        (t4_low_profit == 0 | is.finite(t4_low_tax)),
      direct_metrics = pmap(
        list(t4_low_profit, t4_low_tax, t4_positive_profit),
        direct_rule_metrics
      ),
      direct_low_share = if_else(
        t4_available, map_dbl(direct_metrics, "low_share"), NA_real_
      ),
      direct_topup_rate = if_else(
        t4_available, map_dbl(direct_metrics, "topup_rate"), NA_real_
      ),
      direct_liability_rate = direct_low_share * direct_topup_rate
    ) |>
    select(-direct_metrics)
}

# This sensitivity uses the frozen L3 priority order. The second specification
# also screens the Table IV partitions from which BSPI transports 2019–2020
# bracket shapes to 2017–2018. Missing Stage 1 liability contributes zero,
# matching the treatment when source liabilities enter the waterfall.
audit_pooled_t4_completeness <- function(host, brackets) {
  keys <- c("affiliate", "year")
  observed <- summarise_observed_t4(brackets, keys) |>
    select(all_of(keys), t4_has_low, t4_has_upper, t4_available, t4_low_profit, t4_low_tax)
  complete_anchors <- host |>
    filter(year %in% BSPI_ANCHOR_YEARS) |>
    inner_join(filter(observed, t4_available), by = keys, relationship = "one-to-one") |>
    summarise(
      complete_anchor_years = n(),
      complete_anchor_profit = sum(direct_positive_profit_total),
      complete_anchor_low_profit = sum(direct_low_profit),
      complete_anchor_tax = sum(direct_low_tax),
      .by = affiliate
    ) |>
    mutate(
      complete_bspi_share = safe_divide(complete_anchor_low_profit, complete_anchor_profit),
      complete_bspi_gap = if_else(complete_anchor_low_profit > 0,
        GMT_RATE - clamp_interval(
          safe_divide(complete_anchor_tax, complete_anchor_low_profit), 0, GMT_RATE
        ), 0)
    )
  base <- host |>
    select(
      all_of(keys), affiliate_is_eu27, total_analysis_profit_positive,
      direct_available, percentile_available, bspi_available, average_available,
      direct_low_share, direct_topup_rate, percentile_low_share, percentile_topup_rate,
      bspi_low_share, bspi_topup_rate, average_low_share, average_topup_rate,
      baseline_source = stage1_distributional_source,
      baseline_share = stage1_distributional_low_share,
      baseline_gap = stage1_distributional_topup_rate
    ) |>
    left_join(observed, by = keys, relationship = "one-to-one") |>
    left_join(complete_anchors, by = "affiliate", relationship = "many-to-one") |>
    mutate(
      across(c(t4_has_low, t4_has_upper, t4_available), ~ coalesce(.x, FALSE)),
      complete_anchor_years = coalesce(complete_anchor_years, 0L),
      incomplete_direct = baseline_source == "direct_t4" & !t4_available,
      missing_numeric_low = incomplete_direct & !t4_has_low,
      missing_numeric_upper = incomplete_direct & !t4_has_upper,
      missing_low_tax = incomplete_direct & coalesce(t4_low_profit > 0, FALSE) &
        !is.finite(t4_low_tax)
    )
  details <- map_dfr(c("direct_only", "direct_and_bspi_anchors"), function(spec) {
    use_complete_anchors <- spec == "direct_and_bspi_anchors"
    base |>
      mutate(
        specification = spec,
        sensitivity_source = choose_distributional_source(
          year, direct_available & t4_available, percentile_available,
          if (use_complete_anchors) complete_anchor_years > 0L else bspi_available,
          average_available
        ),
        sensitivity_share = case_when(
          sensitivity_source == "direct_t4" ~ direct_low_share,
          sensitivity_source == "percentile_fit" ~ percentile_low_share,
          sensitivity_source == "shape_transport" ~
            if (use_complete_anchors) complete_bspi_share else bspi_low_share,
          sensitivity_source == "avg_only" ~ average_low_share,
          TRUE ~ NA_real_
        ),
        sensitivity_gap = case_when(
          sensitivity_source == "direct_t4" ~ direct_topup_rate,
          sensitivity_source == "percentile_fit" ~ percentile_topup_rate,
          sensitivity_source == "shape_transport" ~
            if (use_complete_anchors) complete_bspi_gap else bspi_topup_rate,
          sensitivity_source == "avg_only" ~ average_topup_rate,
          TRUE ~ NA_real_
        ),
        source_changed = sensitivity_source != baseline_source,
        baseline_low_profit_usd = total_analysis_profit_positive * coalesce_zero(baseline_share),
        sensitivity_low_profit_usd = total_analysis_profit_positive * coalesce_zero(sensitivity_share),
        baseline_liability_usd = baseline_low_profit_usd * coalesce_zero(baseline_gap),
        sensitivity_liability_usd = sensitivity_low_profit_usd * coalesce_zero(sensitivity_gap),
        delta_low_profit_usd = sensitivity_low_profit_usd - baseline_low_profit_usd,
        delta_liability_usd = sensitivity_liability_usd - baseline_liability_usd
      )
  })
  summary <- bind_rows(
    mutate(details, scope = "Global"),
    mutate(filter(details, affiliate_is_eu27), scope = "EU27")
  ) |>
    mutate(window = as.character(year)) |>
    bind_rows(
      filter(details, year %in% MAIN_YEARS) |>
        mutate(scope = "Global", window = "2017–2023"),
      filter(details, year %in% MAIN_YEARS, affiliate_is_eu27) |>
        mutate(scope = "EU27", window = "2017–2023"),
      filter(details, year %in% DIRECT_YEARS) |>
        mutate(scope = "Global", window = "2019–2023"),
      filter(details, year %in% DIRECT_YEARS, affiliate_is_eu27) |>
        mutate(scope = "EU27", window = "2019–2023")
    ) |>
    summarise(
      host_years = n(),
      baseline_direct_host_years = sum(baseline_source == "direct_t4"),
      incomplete_direct_host_years = sum(incomplete_direct),
      missing_numeric_low_host_years = sum(missing_numeric_low),
      missing_numeric_upper_host_years = sum(missing_numeric_upper),
      missing_low_tax_host_years = sum(missing_low_tax),
      changed_branch_host_years = sum(source_changed),
      changed_liability_host_years = sum(delta_liability_usd != 0),
      across(c(total_analysis_profit_positive, ends_with("_profit_usd"),
               ends_with("_liability_usd")), sum),
      .by = c(specification, scope, window)
    ) |>
    mutate(
      baseline_liability_rate = safe_divide(baseline_liability_usd, total_analysis_profit_positive),
      sensitivity_liability_rate = safe_divide(sensitivity_liability_usd, total_analysis_profit_positive),
      delta_liability_rate = sensitivity_liability_rate - baseline_liability_rate
    ) |>
    arrange(specification, scope, window)
  bind_rows(
    mutate(summary, record = "summary", .before = 1L),
    details |>
      filter(incomplete_direct | source_changed | delta_liability_usd != 0) |>
      transmute(
        record = "affiliate_year", specification, scope = if_else(affiliate_is_eu27, "EU27", "non_EU27"),
        window = as.character(year), affiliate, year, baseline_source, sensitivity_source,
        t4_has_low, t4_has_upper, t4_available, t4_low_profit, t4_low_tax, missing_low_tax,
        complete_anchor_years, total_analysis_profit_positive, baseline_share, sensitivity_share,
        baseline_gap, sensitivity_gap, baseline_low_profit_usd, sensitivity_low_profit_usd,
        delta_low_profit_usd, baseline_liability_usd, sensitivity_liability_usd, delta_liability_usd
      ) |>
      arrange(specification, year, affiliate)
  )
}

fit_matched_beta_metrics <- function(data) {
  data |>
    rowwise() |>
    mutate(
      fit = list(fit_constrained_beta_percentiles(
        c(q5_raw, q25_raw, q50_raw, q75_raw, q95_raw), mean_etr,
        upper_cap = affiliate_etr_cap_stage1
      )),
      uncapped = list(fit_constrained_beta_percentiles(
        c(q5_raw, q25_raw, q50_raw, q75_raw, q95_raw), mean_etr
      )),
      boundary_mean = if_else(fit$boundary_flag, fit$mean, NA_real_),
      uncapped_boundary = if_else(uncapped$boundary_flag, uncapped$mean, NA_real_),
      percentile_low_share_uncapped = beta_mass_below(uncapped$alpha, uncapped$beta,
        boundary_mean = uncapped_boundary),
      percentile_topup_rate_uncapped = beta_avg_topup_rate(uncapped$alpha, uncapped$beta,
        boundary_mean = uncapped_boundary),
      percentile_liability_rate_uncapped =
        percentile_low_share_uncapped * percentile_topup_rate_uncapped,
      percentile_low_share = beta_mass_below(fit$alpha, fit$beta,
        boundary_mean = boundary_mean
      ),
      percentile_topup_rate = beta_avg_topup_rate(fit$alpha, fit$beta,
        boundary_mean = boundary_mean
      ),
      percentile_liability_rate = percentile_low_share * percentile_topup_rate,
      low_share_diff = percentile_low_share - direct_low_share,
      liability_rate_diff = percentile_liability_rate - direct_liability_rate
    ) |>
    ungroup() |>
    select(-fit, -boundary_mean, -uncapped, -uncapped_boundary)
}

build_matched_stage1_crossval <- function(panel, bilateral_brackets, direct_bilateral) {
  keys <- c("parent", "affiliate", "year")
  matched <- panel |>
    filter(
      year %in% PERCENTILE_YEARS, has_panelai_percentiles,
      analysis_profit_base > 0, is.finite(etr_panelai_reg)
    ) |>
    select(
      all_of(keys), affiliate_is_eu27, has_panelai_percentiles,
      analysis_profit_base, etr_panelai_reg, tax_accrued_panelai, affiliate_cit_rate_unit,
      any_of("affiliate_cit_statistical_ceiling"),
      subgroups_count_panelai, entities_count_panelai, subgroups_count, entities_count,
      etr_p5_panelai, etr_p25_panelai, etr_p50_panelai, etr_p75_panelai, etr_p95_panelai
    ) |>
    inner_join(filter(direct_bilateral, t4_available), by = keys)

  exact <- matched |>
    transmute(
      parent, affiliate, year, affiliate_is_eu27, analysis_profit_base,
      mean_etr = etr_panelai_reg,
      affiliate_etr_cap_stage1 = panel_statistical_ceiling(matched),
      mean_etr = if ("affiliate_cit_statistical_ceiling" %in% names(matched)) {
        regularise_bilateral_etr(etr_panelai_reg, affiliate_etr_cap_stage1)
      } else mean_etr,
      q5_raw = etr_p5_panelai, q25_raw = etr_p25_panelai, q50_raw = etr_p50_panelai,
      q75_raw = etr_p75_panelai, q95_raw = etr_p95_panelai,
      t4_positive_profit, t4_low_profit, t4_low_tax,
      direct_low_share, direct_topup_rate, direct_liability_rate
    ) |>
    fit_matched_beta_metrics()

  # Both tables use the same set of parents for each affiliate-year.
  affiliate_year_keys <- c("affiliate", "year")
  restricted_t4 <- bilateral_brackets |>
    semi_join(matched, by = keys) |>
    summarise_observed_t4(affiliate_year_keys)

  restricted_means <- matched |>
    group_by(affiliate, year) |>
    summarise(
      affiliate_is_eu27 = first(affiliate_is_eu27),
      parents = paste(sort(unique(parent)), collapse = "+"),
      analysis_profit_base = sum(analysis_profit_base),
      tax_accrued = sum(tax_accrued_panelai),
      affiliate_etr_cap_stage1 = first_non_missing(panel_statistical_ceiling(dplyr::pick(everything()))),
      .groups = "drop"
    ) |>
    mutate(
      mean_etr = pmin(pmax(tax_accrued / analysis_profit_base, 0), affiliate_etr_cap_stage1)
    )

  restricted <- pool_panelai_percentiles(matched) |>
    inner_join(restricted_means, by = affiliate_year_keys) |>
    inner_join(restricted_t4, by = affiliate_year_keys) |>
    fit_matched_beta_metrics()

  list(exact = exact, restricted = restricted)
}

summarise_stage1_crossval <- function(data, sample, uncapped = FALSE) {
  suffix <- if (uncapped) "_uncapped" else ""
  outcomes <- c("low_share", "topup_rate", "liability_rate")
  map_dfr(outcomes, function(outcome) {
    observations <- tibble(
      year = data$year,
      benchmark = data[[paste0("direct_", outcome)]],
      prediction = data[[paste0("percentile_", outcome, suffix)]]
    ) |>
      filter(is.finite(benchmark), is.finite(prediction))
    gap <- observations$prediction - observations$benchmark
    calibration <- if (nrow(observations) >= 3 &&
      n_distinct(observations$prediction) > 1 &&
      n_distinct(observations$benchmark) > 1) {
      formula <- if (n_distinct(observations$year) > 1) {
        benchmark ~ prediction + factor(year)
      } else {
        benchmark ~ prediction
      }
      fit <- stats::lm(formula, data = observations)
      c(slope = unname(stats::coef(fit)["prediction"]), r_squared = summary(fit)$r.squared)
    } else {
      c(slope = NA_real_, r_squared = NA_real_)
    }
    values <- c(
      n = nrow(observations),
      median_gap = median(gap),
      mae = mean(abs(gap)),
      rmse = sqrt(mean(gap^2)),
      p90_absolute_error = unname(quantile(abs(gap), .9)),
      spearman = safe_cor(observations$prediction, observations$benchmark, method = "spearman"),
      calibration_slope = calibration[["slope"]],
      calibration_r_squared = calibration[["r_squared"]]
    )
    tibble(
      sample = sample, estimator = if (uncapped) "uncapped" else "statutory_cap",
      outcome = outcome, statistic = names(values),
      prediction_field = paste0("percentile_", outcome, suffix),
      metric = paste0(paste(sample, outcome, statistic, sep = "_"), suffix),
      value = if_else(is.nan(values), NA_real_, unname(values))
    )
  })
}

# Rank-bounded and statutory-capped sensitivity estimators used by Stage 1.
STAGE1_BETA_MODELS <- c("M1_Baseline", "M1a_StatCap_LowerTail", "M1b_RankBounded_Beta")
STAGE1_BETA_BLEND_WEIGHTS <- seq(0, 1, by = 0.25)
STAGE1_RANK_TOL <- 1e-8

stage1_condition_percentile_knots <- function(q, cap) {
  out <- q
  observed <- is.finite(q)
  out[observed] <- cummax(pmin(pmax(q[observed], 0), cap))
  out
}

stage1_rank <- function(q) {
  q <- unname(q)
  lower <- which(q < GMT_RATE)
  upper <- which(q > GMT_RATE)
  p_low <- max(c(0, PERCENTILE_PROBS[lower]))
  p_high <- min(c(1, PERCENTILE_PROBS[upper]))
  q_low <- if (length(lower)) q[max(lower)] else 0
  q_high <- if (length(upper)) q[min(upper)] else 1
  c(lower = p_low, upper = p_high,
    interpolated = p_low + (p_high - p_low) * (GMT_RATE - q_low) / (q_high - q_low))
}

stage1_rank_violation <- function(share, lower, upper) {
  share < lower - STAGE1_RANK_TOL | share > upper + STAGE1_RANK_TOL
}

stage1_tail_gap <- function(mean, precision, share, raw_share) {
  if (share <= 0) return(0)
  if (!is.finite(precision)) return(pmax(0, GMT_RATE - mean))
  alpha <- mean * precision
  beta <- (1 - mean) * precision
  quantile <- if (precision > 1e5) stats::qbeta else beta_quantiles
  truncated_moment <- if (share == raw_share) {
    mean * pbeta(GMT_RATE, alpha + 1, beta)
  } else if (share == 1) {
    mean
  } else if (share <= pbeta(0.5, alpha, beta)) {
    mean * pbeta(quantile(share, alpha, beta), alpha + 1, beta)
  } else {
    reflected <- quantile(1 - share, beta, alpha)
    if (reflected == 0) {
      # Small-tail limit after the reflected quantile underflows.
      pmax(0, mean + share - 1)
    } else {
      mean * pbeta(reflected, beta, alpha + 1, lower.tail = FALSE)
    }
  }
  pmax(0, GMT_RATE - pmin(1, truncated_moment / share))
}

# Search the log-precision ray, including nonmonotone CDF sections. Turning
# points bracket separate crossings of either rank bound.
stage1_rank_feasibility <- function(cdf, bounds, rank) {
  grid <- seq(bounds[1], bounds[2], length.out = 81L)
  cdf_grid <- cdf(grid)
  left <- cdf_grid[-c(length(grid) - 1L, length(grid))]
  mid <- cdf_grid[-c(1L, length(grid))]
  right <- cdf_grid[-c(1L, 2L)]
  peaks <- which(mid > left & mid > right) + 1L
  troughs <- which(mid < left & mid < right) + 1L
  extrema <- c(
    map_dbl(peaks, ~ optimize(cdf, grid[c(.x - 1L, .x + 1L)], maximum = TRUE)$maximum),
    map_dbl(troughs, ~ optimize(cdf, grid[c(.x - 1L, .x + 1L)])$minimum)
  )
  knots <- sort(unique(c(bounds, extrema, grid)))
  values <- cdf(knots)
  roots <- map(rank[c("lower", "upper")], function(target) {
    error <- values - target
    across_target <- which(head(error, -1) * tail(error, -1) < 0)
    map_dbl(across_target, ~ uniroot(function(x) cdf(x) - target,
      knots[c(.x, .x + 1L)], tol = 1e-11)$root)
  })
  intervals <- sort(unique(c(bounds, extrema, unlist(roots))))
  low <- head(intervals, -1)
  high <- tail(intervals, -1)
  eligible <- !stage1_rank_violation(cdf((low + high) / 2), rank["lower"], rank["upper"])
  points <- intervals[!stage1_rank_violation(cdf(intervals), rank["lower"], rank["upper"])]
  distances <- pmax(rank["lower"] - values, values - rank["upper"], 0)
  list(low = low[eligible], high = high[eligible], points = points,
    closest = knots[which.min(distances)])
}

stage1_fit_cell <- function(raw, mean, cap, models, blends = FALSE) {
  stopifnot(length(raw) == length(PERCENTILE_PROBS), all(is.finite(raw)),
    is.finite(mean), is.finite(cap), cap >= 0, cap <= 1)
  unit_q <- stage1_condition_percentile_knots(raw, 1)
  capped_q <- stage1_condition_percentile_knots(raw, cap)
  # Preserve rank information from the published knots, even when a low
  # statutory cap moves a knot from above to below the threshold.
  rank <- stage1_rank(unit_q)
  capped_rank <- stage1_rank(capped_q)
  mean <- clamp_unit_interval(mean)
  boundary <- mean <= BETA_BOUNDARY_EPS || mean >= 1 - BETA_BOUNDARY_EPS
  if (boundary) mean <- round(mean)
  cdf <- function(log_precision) {
    precision <- exp(log_precision)
    pbeta(GMT_RATE, mean * precision, (1 - mean) * precision)
  }

  fit <- map_dfr(models, function(model) {
    baseline <- model == STAGE1_BETA_MODELS[1]
    lower_tail <- model == STAGE1_BETA_MODELS[2]
    rank_bounded <- model == STAGE1_BETA_MODELS[3]
    q <- if (baseline) unit_q else capped_q
    bounds <- BETA_PRECISION_LOG_BOUNDS
    if (lower_tail) bounds[1] <- log(1 / max(mean, 1 - mean))
    weights <- rep(1, length(raw))
    if (lower_tail && raw[5] > cap) weights[5] <- 0
    objective <- function(log_precision) {
      precision <- exp(log_precision)
      fitted <- beta_quantiles(PERCENTILE_PROBS, mean * precision, (1 - mean) * precision)
      sum(weights * (fitted - q)^2)
    }
    if (boundary) {
      precision <- NA_real_
      raw_share <- as.numeric(mean < GMT_RATE)
    } else if (baseline) {
      precision <- fit_constrained_beta_percentiles(unit_q, mean)$precision
      raw_share <- cdf(log(precision))
    } else if (rank_bounded) {
      feasible <- stage1_rank_feasibility(cdf, bounds, rank)
      precision <- if (length(feasible$points) + length(feasible$low)) {
        exp(stage1_minimise(objective, feasible$low, feasible$high, feasible$points))
      } else {
        exp(feasible$closest)
      }
      raw_share <- cdf(log(precision))
    } else {
      precision <- exp(stage1_minimise(objective, bounds[1], bounds[2]))
      raw_share <- cdf(log(precision))
    }
    share <- if (rank_bounded) clamp_interval(raw_share, rank["lower"], rank["upper"]) else raw_share
    gap <- stage1_tail_gap(mean, precision, share, raw_share)
    quantile_rmse <- if (boundary) sqrt(mean((mean - q)^2)) else {
      sqrt(objective(log(precision)) / sum(weights))
    }
    tibble(
      model, omega = NA_real_, target_mean = mean, cap,
      rank_lower = unname(rank["lower"]), rank_upper = unname(rank["upper"]),
      capped_rank_lower = unname(capped_rank["lower"]), capped_rank_upper = unname(capped_rank["upper"]),
      raw_p95_above_cap = raw[5] > cap, p95_excluded = weights[5] == 0,
      precision, alpha = mean * precision, beta = (1 - mean) * precision,
      beta_share_at_threshold = raw_share, share, gap, quantile_rmse,
      rank_projection = rank_bounded & stage1_rank_violation(raw_share, rank["lower"], rank["upper"]),
      rank_violation = stage1_rank_violation(share, rank["lower"], rank["upper"])
    )
  })
  if (blends) {
    base <- filter(fit, model == STAGE1_BETA_MODELS[2])
    mixture <- crossing(base |> select(-omega), omega = STAGE1_BETA_BLEND_WEIGHTS) |>
      mutate(
        model = "M1c_ProfitSkew_Adjusted_Beta",
        share = omega * beta_share_at_threshold + (1 - omega) * unname(rank["interpolated"]),
        gap = map2_dbl(share, beta_share_at_threshold,
          ~ stage1_tail_gap(mean, base$precision, .x, .y)),
        rank_violation = stage1_rank_violation(share, rank_lower, rank_upper)
      )
    fit <- bind_rows(fit, mixture)
  }
  mutate(fit, liability_rate = share * gap)
}
# Bilateral ETR measurements used by production and the ladder diagnostics.
LADDER_QUANTILES <- paste0("etr_p", c(5, 25, 50, 75, 95), "_panelai")
LADDER_BSPI <- "L4_strict_pair_BSPI_sensitivity"
LADDER_LEVELS <- c("L1_Host_Average", "L2_Bilateral_Cell_Average",
  "L3_Host_Pooled_Distributional", "L4_bilat_anchored", "L4_strict_no_transport")
LADDER_KEYS <- c("parent", "affiliate", "year")
ladder_beta_metrics <- function(mean, precision) {
  interior <- is.finite(precision) & precision > 0 &
    is.finite(mean) & mean > BETA_BOUNDARY_EPS & mean < 1 - BETA_BOUNDARY_EPS
  boundary <- is.finite(mean) & (mean <= BETA_BOUNDARY_EPS | mean >= 1 - BETA_BOUNDARY_EPS)
  alpha <- mean[interior] * precision[interior]
  beta <- (1 - mean[interior]) * precision[interior]
  share <- gap <- rep(NA_real_, length(mean))
  share[interior] <- pbeta(GMT_RATE, alpha, beta)
  first_moment <- mean[interior] * pbeta(GMT_RATE, alpha + 1, beta)
  gap[interior] <- coalesce(pmax(GMT_RATE - safe_divide(first_moment, share[interior]), 0), 0)
  share[boundary] <- as.numeric(mean[boundary] < GMT_RATE)
  gap[boundary] <- pmax(0, GMT_RATE - if_else(mean[boundary] <= BETA_BOUNDARY_EPS, 0, 1))
  tibble(beta_share = share, beta_gap = gap)
}

ladder_bilateral_fits <- function(stage1, rank_consistent = FALSE) {
  fit_inputs <- stage1 |>
    filter(
      analysis_profit_positive > 0, year %in% PERCENTILE_YEARS,
      is.finite(etr_panelai_stage1),
      has_panelai_percentiles | (!affiliate_is_eu27 & has_t_fallback_percentiles)
    ) |>
    mutate(
      percentile_source = if_else(has_panelai_percentiles, "panel_ai", "panel_t_non_eu")
    )
  fallback <- paste0("etr_p", c(5, 25, 50, 75, 95))
  probabilities <- as.matrix(fit_inputs[LADDER_QUANTILES])
  use_t <- fit_inputs$percentile_source == "panel_t_non_eu"
  probabilities[use_t, ] <- as.matrix(fit_inputs[use_t, fallback])
  if (rank_consistent) {
    caps <- panel_statistical_ceiling(fit_inputs)
    fits <- map_dfr(seq_len(nrow(fit_inputs)), function(i) {
      stage1_fit_cell(probabilities[i, ], fit_inputs$etr_panelai_stage1[i], caps[i],
        STAGE1_BETA_MODELS[3])
    })
    return(bind_cols(
      select(fit_inputs, all_of(LADDER_KEYS), percentile_source),
      transmute(fits, fitted_precision = precision, fit_rmse = quantile_rmse,
        percentile_rank_lower = rank_lower, percentile_rank_upper = rank_upper,
        fitted_share = share, fitted_gap = gap, fitted_share_outside_percentile_rank = rank_violation)
    ))
  }
  # A quantile below the threshold supplies a lower bound on its CDF rank.
  # A quantile at or above the threshold supplies an upper bound.
  rank_bounds <- t(apply(probabilities, 1, function(q) {
    conditioned <- condition_stage1_percentiles(q)
    c(max(c(0, PERCENTILE_PROBS[conditioned < GMT_RATE])),
      min(c(1, PERCENTILE_PROBS[conditioned >= GMT_RATE])))
  }))
  fits <- map(seq_len(nrow(fit_inputs)), function(i) {
    fit_constrained_beta_percentiles(probabilities[i, ], fit_inputs$etr_panelai_stage1[i])
  })
  precision <- map_dbl(fits, "precision")
  mean <- map_dbl(fits, "mean")
  bind_cols(
    select(fit_inputs, all_of(LADDER_KEYS), percentile_source),
    tibble(fitted_precision = precision,
      fit_rmse = sqrt(map_dbl(fits, "sse") / ncol(probabilities)),
      percentile_rank_lower = rank_bounds[, 1], percentile_rank_upper = rank_bounds[, 2]),
    ladder_beta_metrics(mean, precision) |>
      rename(fitted_share = beta_share, fitted_gap = beta_gap)
  ) |>
    mutate(fitted_share_outside_percentile_rank = fitted_share < percentile_rank_lower - 1e-8 |
      fitted_share > percentile_rank_upper + 1e-8)
}

ladder_build_measurements <- function(stage1, host_stage1, brackets, rank_consistent = FALSE) {
  exact <- summarise_observed_t4(brackets, LADDER_KEYS) |>
    filter(t4_available)
  message("Fitting bilateral Table I distributions")
  fits <- ladder_bilateral_fits(stage1, rank_consistent)
  pair_precision <- fits |>
    filter(is.finite(fitted_precision)) |>
    summarise(pair_precision = median(fitted_precision), .by = c(parent, affiliate))
  precision_field <- if (rank_consistent) "percentile_beta_precision_rank_bounded" else "percentile_beta_precision"
  host_precision <- host_stage1 |>
    transmute(affiliate, year, host_year_precision = .data[[precision_field]]) |>
    filter(year %in% PERCENTILE_YEARS, is.finite(host_year_precision))
  host_median <- host_precision |>
    summarise(host_median_precision = median(host_year_precision), .by = affiliate)

  # Report the 2017–2018 exception separately. The strict specification
  # uses L2 throughout these years because no contemporaneous partition exists.
  pair_bspi <- exact |>
    filter(year %in% BSPI_ANCHOR_YEARS) |>
    summarise(
      positive_profit = sum(t4_positive_profit),
      low_profit = sum(t4_low_profit),
      low_tax = sum(t4_low_tax, na.rm = TRUE),
      bspi_anchor_years = n(), .by = c(parent, affiliate)
    ) |>
    transmute(
      parent, affiliate, bspi_anchor_years,
      bspi_share = low_profit / positive_profit,
      bspi_gap = if_else(low_profit > 0,
        pmax(0, GMT_RATE - pmax(0, safe_divide(low_tax, low_profit))), 0)
    )

  cells <- stage1 |>
    left_join(select(exact, all_of(LADDER_KEYS), t4_available, direct_low_share, direct_topup_rate),
      by = LADDER_KEYS, relationship = "one-to-one") |>
    left_join(fits, by = LADDER_KEYS, relationship = "one-to-one") |>
    left_join(pair_precision, by = c("parent", "affiliate"), relationship = "many-to-one") |>
    left_join(host_precision, by = c("affiliate", "year"), relationship = "many-to-one") |>
    left_join(host_median, by = "affiliate", relationship = "many-to-one") |>
    left_join(pair_bspi, by = c("parent", "affiliate"), relationship = "many-to-one") |>
    mutate(
      t4_available = coalesce(t4_available, FALSE),
      mean_available = is.finite(etr_panelai_stage1),
      selected_precision = coalesce(pair_precision, host_year_precision, host_median_precision),
      l2_share = if_else(mean_available, as.numeric(etr_panelai_stage1 < GMT_RATE), NA_real_),
      l2_gap = if_else(mean_available, pmax(GMT_RATE - etr_panelai_stage1, 0), NA_real_),
      exact_source = case_when(
        t4_available ~ "exact_table_iv",
        !is.na(fitted_share) ~ paste0("exact_table_i_", percentile_source)
      )
    )
  transported <- ladder_beta_metrics(cells$etr_panelai_stage1, cells$selected_precision)
  cells <- bind_cols(cells, transported) |>
    mutate(
      strict_share = coalesce(direct_low_share, fitted_share, l2_share),
      strict_gap = coalesce(direct_topup_rate, fitted_gap, l2_gap),
      strict_source = coalesce(exact_source, if_else(mean_available, "bilateral_average", "unmeasured")),
      anchored_share = coalesce(direct_low_share, fitted_share, beta_share, l2_share),
      anchored_gap = coalesce(direct_topup_rate, fitted_gap, beta_gap, l2_gap),
      anchored_source = coalesce(exact_source, case_when(
        !is.na(beta_share) & etr_panelai_stage1 %in% c(0, 1) ~ "bilateral_boundary_mean",
        !is.na(beta_share) & !is.na(pair_precision) ~ "pair_precision",
        !is.na(beta_share) & !is.na(host_year_precision) ~ "host_year_precision",
        !is.na(beta_share) & !is.na(host_median_precision) ~ "host_median_precision",
        mean_available ~ "bilateral_average",
        TRUE ~ "unmeasured"
      )),
      use_pair_bspi = year %in% BSPI_IMPUTE_YEARS & !is.na(bspi_share)
    )
  measurements <- bind_rows(
    transmute(cells, across(all_of(LADDER_KEYS)), level = LADDER_LEVELS[1],
      share = average_low_share, gap = average_topup_rate, source_tier = "host_average"),
    transmute(cells, across(all_of(LADDER_KEYS)), level = LADDER_LEVELS[2],
      share = l2_share, gap = l2_gap, source_tier = if_else(mean_available, "bilateral_average", "unmeasured")),
    transmute(cells, across(all_of(LADDER_KEYS)), level = LADDER_LEVELS[3],
      share = stage1_distributional_low_share, gap = stage1_distributional_topup_rate,
      source_tier = stage1_distributional_source),
    transmute(cells, across(all_of(LADDER_KEYS)), level = LADDER_LEVELS[4],
      share = anchored_share, gap = anchored_gap, source_tier = anchored_source),
    transmute(cells, across(all_of(LADDER_KEYS)), level = LADDER_LEVELS[5],
      share = strict_share, gap = strict_gap, source_tier = strict_source),
    transmute(cells, across(all_of(LADDER_KEYS)), level = LADDER_BSPI,
      share = if_else(use_pair_bspi, bspi_share, strict_share),
      gap = if_else(use_pair_bspi, bspi_gap, strict_gap),
      source_tier = if_else(use_pair_bspi, "pair_bspi_2019_2020", strict_source))
  ) |>
    left_join(select(stage1, all_of(LADDER_KEYS), affiliate_is_eu27, analysis_profit_positive),
      by = LADDER_KEYS, relationship = "many-to-one") |>
    left_join(select(fits, all_of(LADDER_KEYS), fitted_share_outside_percentile_rank),
      by = LADDER_KEYS, relationship = "many-to-one") |>
    mutate(
      measured = is.finite(share) & is.finite(gap),
      low_profit = if_else(measured, analysis_profit_positive * share, 0),
      stage1_tax = if_else(measured, low_profit * gap, 0),
      percentile_fit_rank_violation = startsWith(source_tier, "exact_table_i_") &
        coalesce(fitted_share_outside_percentile_rank, FALSE)
    )
  assert_unique_keys(measurements, c(LADDER_KEYS, "level"), "Ladder measurements")
  stopifnot(all(between(measurements$share[measurements$measured], 0, 1)),
    all(between(measurements$gap[measurements$measured], 0, GMT_RATE)))
  list(cells = cells, measurements = measurements, direct = exact)
}

add_stage1_ladder_columns <- function(stage1, host_stage1, brackets) {
  levels <- set_names(c("l1", "l2", "l3", "l4_anchored", "l4_strict"), LADDER_LEVELS)
  measurements <- ladder_build_measurements(stage1, host_stage1, brackets,
    rank_consistent = TRUE)$measurements |>
    filter(level %in% LADDER_LEVELS) |>
    transmute(across(all_of(LADDER_KEYS)), level = unname(levels[level]),
      low_share = share, topup_rate = gap, liability_rate = share * gap,
      lowtax_profit = low_profit, topup_tax = stage1_tax, source = source_tier) |>
    pivot_wider(names_from = level, values_from = c(low_share, topup_rate, liability_rate,
      lowtax_profit, topup_tax, source), names_glue = "ladder_{level}_{.value}")
  left_join(stage1, measurements, by = LADDER_KEYS, relationship = "one-to-one")
}

run_stage1_pipeline <- function() {
  dir.create(DIAGNOSTICS_DIR, showWarnings = FALSE, recursive = TRUE)
  panel <- readRDS(file.path(PROCESSED_DIR, "base_panel.rds")) |>
    filter(year %in% MAIN_YEARS)
  t4_brackets <- readRDS(file.path(PROCESSED_DIR, "base_panel_t4_bracket_shares.rds"))
  t4_bilateral_brackets <- readRDS(
    file.path(PROCESSED_DIR, "base_panel_t4_bilateral_bracket_shares.rds")
  )
  bilateral_keys <- c("parent", "affiliate", "year")
  direct_bilateral <- summarise_observed_t4(t4_bilateral_brackets, bilateral_keys)

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

  if ("affiliate_cit_statistical_ceiling" %in% names(panel)) {
    ceilings <- panel |>
      distinct(affiliate, year, affiliate_cit_statistical_ceiling)
    affiliate_year_base <- affiliate_year_base |>
      left_join(ceilings, by = c("affiliate", "year"), relationship = "many-to-one") |>
      mutate(
        affiliate_etr_cap_stage1 = coalesce(affiliate_cit_statistical_ceiling, 1),
        avg_etr_stage1 = pmin(pmax(avg_etr_raw, 0), affiliate_etr_cap_stage1)
      ) |>
      select(-affiliate_cit_statistical_ceiling)
  }

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

  percentile_panelai <- pool_panelai_percentiles(percentile_rows)

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
      affiliate, year, affiliate_is_eu27, avg_etr_stage1, affiliate_etr_cap_stage1,
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
        condition_stage1_percentiles(unlist(percentile_raw), affiliate_etr_cap_stage1)
      ),
      percentile_conditioning_flag = any(abs(
        unlist(percentile_conditioned) - unlist(percentile_raw)
      ) > 1e-12),
      percentile_conditioning_max_abs_change = max(abs(
        unlist(percentile_conditioned) - unlist(percentile_raw)
      )),
      percentile_beta_fit = list(fit_constrained_beta_percentiles(
        unlist(percentile_raw), avg_etr_stage1, upper_cap = affiliate_etr_cap_stage1
      )),
      percentile_uncapped_fit = list(fit_constrained_beta_percentiles(
        unlist(percentile_raw), avg_etr_stage1
      )),
      percentile_uncapped_boundary = if_else(percentile_uncapped_fit$boundary_flag,
        percentile_uncapped_fit$mean, NA_real_),
      percentile_beta_precision_uncapped = percentile_uncapped_fit$precision,
      percentile_low_share_uncapped = beta_mass_below(percentile_uncapped_fit$alpha,
        percentile_uncapped_fit$beta, boundary_mean = percentile_uncapped_boundary),
      percentile_topup_rate_uncapped = beta_avg_topup_rate(percentile_uncapped_fit$alpha,
        percentile_uncapped_fit$beta, boundary_mean = percentile_uncapped_boundary),
      percentile_liability_rate_uncapped = percentile_low_share_uncapped * percentile_topup_rate_uncapped,
      percentile_beta_precision_rank_bounded = if (is.finite(avg_etr_stage1) &&
        all(is.finite(unlist(percentile_raw)))) {
        stage1_fit_cell(unlist(percentile_raw), avg_etr_stage1,
          affiliate_etr_cap_stage1, STAGE1_BETA_MODELS[3])$precision
      } else NA_real_,
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
      percentile_beta_precision_uncapped, percentile_low_share_uncapped,
      percentile_topup_rate_uncapped, percentile_liability_rate_uncapped,
      percentile_beta_precision_rank_bounded,
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
      direct_available = is.finite(direct_low_share) & is.finite(direct_topup_rate),
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

  matched_crossval <- build_matched_stage1_crossval(
    panel, t4_bilateral_brackets, direct_bilateral
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
    left_join(
      direct_bilateral |>
        transmute(
          parent, affiliate, year, t4_available,
          direct_low_share_bilat = direct_low_share,
          direct_topup_rate_bilat = direct_topup_rate
        ),
      by = bilateral_keys
    ) |>
    mutate(
      stage1_distributional_source_bilat = case_when(
        coalesce(t4_available, FALSE) ~ "direct_t4_bilateral",
        stage1_distributional_source == "direct_t4" ~ "direct_t4_pooled",
        TRUE ~ stage1_distributional_source
      ),
      stage1_distributional_low_share_bilat =
        coalesce(direct_low_share_bilat, stage1_distributional_low_share),
      stage1_distributional_topup_rate_bilat =
        coalesce(direct_topup_rate_bilat, stage1_distributional_topup_rate),
      stage1_distributional_liability_rate_bilat =
        stage1_distributional_low_share_bilat * stage1_distributional_topup_rate_bilat,
      analysis_profit_positive = pmax(coalesce(analysis_profit_base, 0), 0),
      stage1_lowtax_profit_average = average_low_share * analysis_profit_positive,
      stage1_topup_tax_average = stage1_lowtax_profit_average * average_topup_rate,
      stage1_lowtax_profit_distributional =
        stage1_distributional_low_share * analysis_profit_positive,
      stage1_topup_tax_distributional =
        stage1_lowtax_profit_distributional * stage1_distributional_topup_rate,
      stage1_lowtax_profit_distributional_bilat =
        stage1_distributional_low_share_bilat * analysis_profit_positive,
      stage1_topup_tax_distributional_bilat =
        stage1_lowtax_profit_distributional_bilat * stage1_distributional_topup_rate_bilat,
      stage1_lowtax_profit_distributional_strict =
        stage1_distributional_low_share_strict * analysis_profit_positive,
      stage1_topup_tax_distributional_strict =
        stage1_lowtax_profit_distributional_strict *
          stage1_distributional_topup_rate_strict
    ) |>
    select(-t4_available, -direct_low_share_bilat, -direct_topup_rate_bilat) |>
    add_stage1_ladder_columns(affiliate_year_stage1, t4_bilateral_brackets)

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

  positive_direct_years <- bilateral_stage1 |>
    filter(year %in% DIRECT_YEARS, analysis_profit_positive > 0)
  bilateral_comparison_by_year <- bind_rows(
    mutate(positive_direct_years, scope = "global"),
    mutate(filter(positive_direct_years, affiliate_is_eu27), scope = "eu27")
  ) |>
    group_by(scope, year) |>
    summarise(
      positive_profit_cells = n(),
      direct_bilateral_cells = sum(stage1_distributional_source_bilat == "direct_t4_bilateral"),
      positive_profit = sum(analysis_profit_positive),
      pooled_topup = sum(stage1_topup_tax_distributional, na.rm = TRUE),
      bilateral_first_topup = sum(stage1_topup_tax_distributional_bilat, na.rm = TRUE),
      pooled_liability_rate = pooled_topup / positive_profit,
      bilateral_first_liability_rate = bilateral_first_topup / positive_profit,
      .groups = "drop"
    )

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

  stage1_crossval_summary <- bind_rows(
    stage1_crossval_summary,
    summarise_stage1_crossval(crossval_affiliate_year, "unmatched_affiliate_year"),
    summarise_stage1_crossval(matched_crossval$restricted, "parent_restricted_affiliate_year"),
    summarise_stage1_crossval(matched_crossval$exact, "exact_bilateral"),
    summarise_stage1_crossval(crossval_affiliate_year, "unmatched_affiliate_year", uncapped = TRUE),
    summarise_stage1_crossval(matched_crossval$restricted, "parent_restricted_affiliate_year", uncapped = TRUE),
    summarise_stage1_crossval(matched_crossval$exact, "exact_bilateral", uncapped = TRUE)
  )

  write_csv(
    matched_crossval$exact,
    file.path(DIAGNOSTICS_DIR, "step3_stage1_crossval_bilateral_matched.csv")
  )
  write_csv(
    matched_crossval$restricted,
    file.path(DIAGNOSTICS_DIR, "step3_stage1_crossval_affiliate_year_parent_restricted.csv")
  )

  write_csv(stage1_summary, file.path(DIAGNOSTICS_DIR, "step3_stage1_summary.csv"))
  write_csv(stage1_branch_by_year, file.path(DIAGNOSTICS_DIR, "step3_stage1_branch_by_year.csv"))
  write_csv(
    stage1_pair_year_branch_by_year,
    file.path(DIAGNOSTICS_DIR, "step3_stage1_pair_year_branch_by_year.csv")
  )
  write_csv(
    stage1_bspi_tv_summary,
    file.path(DIAGNOSTICS_DIR, "step3_stage1_bspi_tv_summary.csv")
  )
  write_csv(stage1_scenario_by_year, file.path(DIAGNOSTICS_DIR, "step3_stage1_scenario_by_year.csv"))
  write_csv(
    bilateral_comparison_by_year,
    file.path(DIAGNOSTICS_DIR, "step3_stage1_bilateral_comparison_by_year.csv")
  )
  write_csv(
    stage1_conditioning_by_year,
    file.path(DIAGNOSTICS_DIR, "step3_stage1_conditioning_by_year.csv")
  )
  write_csv(
    stage1_crossval_summary,
    file.path(DIAGNOSTICS_DIR, "step3_stage1_crossval_summary.csv")
  )
  write_csv(
    crossval_regression,
    file.path(DIAGNOSTICS_DIR, "step3_stage1_crossval_regression.csv")
  )
  write_csv(
    crossval_calibration,
    file.path(DIAGNOSTICS_DIR, "step3_stage1_crossval_calibration.csv")
  )
  write_csv(
    crossval_affiliate_year,
    file.path(DIAGNOSTICS_DIR, "step3_stage1_crossval_affiliate_year.csv")
  )
  write_csv(
    bspi_validation,
    file.path(DIAGNOSTICS_DIR, "step3_stage1_bspi_validation.csv")
  )

  write_csv(
    audit_pooled_t4_completeness(affiliate_year_stage1, t4_brackets),
    file.path(DIAGNOSTICS_DIR, "step3_stage1_pooled_t4_completeness_sensitivity.csv")
  )
  saveRDS(affiliate_year_stage1, file.path(PROCESSED_DIR, "stage1_affiliate_year.rds"))
  saveRDS(bilateral_stage1, file.path(PROCESSED_DIR, "stage1_bilateral_panel.rds"))

  message("\nStep 3 outputs written:")
  message(" - data/processed/stage1_affiliate_year.rds")
  message(" - data/processed/stage1_bilateral_panel.rds")
  message(" - diagnostics/step3_stage1_*.csv")
}

if (is_direct_script_run("code/03_stage1_etr.R")) {
  run_stage1_pipeline()
}
