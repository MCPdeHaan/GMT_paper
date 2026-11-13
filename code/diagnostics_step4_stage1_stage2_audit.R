# Run from the repository root with Rscript. This audit only writes its four CSVs.
suppressPackageStartupMessages(source("code/03_stage1_etr.R", local = TRUE))

AUDIT_YEARS <- 2019:2023
AUDIT_CV_YEARS <- 2021:2023
AUDIT_HUBS <- c("LUX", "NLD", "IRL", "DEU", "FRA")
PAIR_KEY <- c("parent", "affiliate", "year")
HOST_KEY <- c("affiliate", "year")
Q_RAW <- paste0("q", c(5, 25, 50, 75, 95), "_raw")
Q_PANELAI <- paste0("etr_p", c(5, 25, 50, 75, 95), "_panelai")
MODEL_IDS <- c(
  "M1_Beta_1Param_MeanAnchored", "M2_Beta_2Param_Unconstrained",
  "M3_ZeroHurdle_Beta", "M4_Piecewise_Linear_CDF", "M5_Monotone_Hyman_Spline"
)

read_processed <- function(name) readRDS(file.path(PROCESSED_DIR, paste0(name, ".rds")))
read_diagnostic <- function(name) {
  read_csv(file.path(DIAGNOSTICS_DIR, paste0(name, ".csv")), show_col_types = FALSE)
}
write_audit <- function(data, suffix) {
  write_csv(data, file.path(DIAGNOSTICS_DIR, paste0("audit_step4_", suffix, ".csv")))
}

audit_beta_quantiles <- function(probs, alpha, beta) {
  quantiles <- clamp_unit_interval(suppressWarnings(qbeta(probs, alpha, beta)))
  lower <- which(quantiles <= 0.5)
  upper <- which(quantiles > 0.5)
  cdf <- rep(NA_real_, length(probs))
  cdf[lower] <- beta_lower_tail(log(quantiles[lower]), alpha, beta)
  cdf[upper] <- 1 - beta_lower_tail(log1p(-quantiles[upper]), beta, alpha)
  retry <- which(!is.finite(cdf) | abs(cdf - probs) > 1e-8)
  for (i in retry) {
    gap <- function(log_odds) {
      log_tail <- -abs(log_odds) - log1p(exp(-abs(log_odds)))
      if (log_odds <= 0) {
        beta_lower_tail(log_tail, alpha, beta) - probs[i]
      } else {
        1 - beta_lower_tail(log_tail, beta, alpha) - probs[i]
      }
    }
    lower_gap <- gap(-746)
    upper_gap <- gap(746)
    quantiles[i] <- if (lower_gap >= 0) {
      0
    } else if (upper_gap <= 0) {
      1
    } else {
      root <- uniroot(gap, c(-746, 746), f.lower = lower_gap, f.upper = upper_gap,
        tol = 1e-10
      )$root
      if (root <= 0) exp(root) / (1 + exp(root)) else plogis(root)
    }
  }
  quantiles
}

# Use the production fitting function with a local numerical guard. Some
# additional bilateral rows push qbeta marginally beyond 1 during fitting.
fit_audit_mean_beta <- fit_constrained_beta_percentiles
environment(fit_audit_mean_beta) <- list2env(
  list(beta_quantiles = function(probs, alpha, beta) {
    if (alpha + beta > 1e5) return(rep(alpha / (alpha + beta), length(probs)))
    audit_beta_quantiles(probs, alpha, beta)
  }),
  parent = environment(fit_constrained_beta_percentiles)
)

# Fit on log shapes to maintain positive shape parameters. Multiple starts
# cover near-degenerate, U-shaped and interior solutions.
fit_two_shape_beta <- function(q, probs, sparse_mean_anchor = NULL) {
  centre <- clamp_interval(mean(q), 0.001, 0.999)
  spread <- max(stats::sd(q), 0.01, na.rm = TRUE)
  moment_precision <- clamp_interval(centre * (1 - centre) / spread^2 - 1, 0.1, 1000)
  starting_means <- c(centre, centre, centre, 0.5)
  precisions <- c(moment_precision, 0.02, 200, 2)
  starts <- cbind(starting_means * precisions, (1 - starting_means) * precisions)

  objective <- function(log_shapes) {
    if (any(log_shapes < -14 | log_shapes > 12)) return(10)
    shapes <- exp(log_shapes)
    predicted <- audit_beta_quantiles(probs, shapes[1], shapes[2])
    loss <- sum((predicted - q)^2)
    if (!is.null(sparse_mean_anchor)) {
      loss <- loss + (shapes[1] / sum(shapes) - sparse_mean_anchor)^2
    }
    loss
  }

  fits <- lapply(seq_len(nrow(starts)), function(i) {
    optim(log(starts[i, ]), objective, method = "L-BFGS-B",
      lower = rep(-14, 2), upper = rep(12, 2),
      control = list(factr = 1e6, pgtol = 1e-8, maxit = 150)
    )
  })
  best <- fits[[which.min(vapply(fits, function(fit) fit$value, numeric(1)))]]
  # A derivative-free polish can improve a fit on a flat quantile region.
  polish <- optim(best$par, objective, method = "Nelder-Mead", control = list(maxit = 500))
  if (all(polish$par >= -14 & polish$par <= 12) && polish$value < best$value) best <- polish
  list(shape = exp(best$par), converged = best$convergence == 0)
}

beta_outcomes <- function(shape, zero_mass = 0, point = NA_real_) {
  alpha <- shape[1]
  beta <- shape[2]
  positive_share <- if (is.na(point)) beta_mass_below(alpha, beta, GMT_RATE) else as.numeric(point < GMT_RATE)
  positive_gap <- beta_avg_topup_rate(alpha, beta, GMT_RATE, point)
  list(
    low_share = zero_mass + (1 - zero_mass) * positive_share,
    liability_rate = zero_mass * GMT_RATE + (1 - zero_mass) * positive_share * positive_gap,
    fitted_mean = (1 - zero_mass) * if (is.na(point)) alpha / sum(shape) else point
  )
}

fit_percentile_model <- function(q, target_mean, model) {
  q <- condition_stage1_percentiles(q)
  target_mean <- clamp_unit_interval(target_mean)
  p <- PERCENTILE_PROBS
  converged <- TRUE
  sparse_tail <- FALSE
  zero_mass <- NA_real_
  upper_endpoint <- NA_real_
  mean_feasible <- NA

  if (model == MODEL_IDS[1]) {
    fit <- fit_audit_mean_beta(q, target_mean)
    metrics <- beta_outcomes(c(fit$alpha, fit$beta),
      point = if (fit$boundary_flag) fit$mean else NA_real_
    )
  } else if (model %in% MODEL_IDS[2:3]) {
    zero_mass <- if (model == MODEL_IDS[3]) max(c(0, p[q == 0])) else 0
    keep <- p > zero_mass
    conditional_probs <- (p[keep] - zero_mass) / (1 - zero_mass)
    sparse_tail <- model == MODEL_IDS[3] && sum(keep) <= 1L
    if (!any(keep)) {
      # The positive tail is unidentified. Give its point mass the mean
      # implied by the overall anchor, truncated to the positive support.
      tail_mean <- clamp_interval(target_mean / (1 - zero_mass), 1e-8, 1)
      metrics <- beta_outcomes(c(NA_real_, NA_real_), zero_mass, point = tail_mean)
    } else {
      sparse_anchor <- if (sparse_tail) clamp_unit_interval(target_mean / (1 - zero_mass))
      fit <- fit_two_shape_beta(q[keep], conditional_probs, sparse_anchor)
      metrics <- beta_outcomes(fit$shape, zero_mass)
      converged <- fit$converged
    }
  } else {
    p_knots <- c(0, p, 1)
    dp <- diff(p_knots)
    q95 <- tail(q, 1)
    if (model == MODEL_IDS[4]) {
      # The trapezoidal mean is affine in the last quantile.
      lower_mean <- sum(diff(c(0, p)) * (head(c(0, q), -1) + q) / 2)
      unconstrained_upper <- 2 * (target_mean - lower_mean) / tail(dp, 1) - q95
      mean_feasible <- unconstrained_upper >= q95 - 1e-12 && unconstrained_upper <= 1 + 1e-12
      upper_endpoint <- clamp_interval(unconstrained_upper, q95, 1)
      q_knots <- c(0, q, upper_endpoint)
      left <- head(q_knots, -1)
      width <- diff(q_knots)
      fraction <- as.numeric(left < GMT_RATE)
      moving <- width > 0
      fraction[moving] <- clamp_unit_interval((GMT_RATE - left[moving]) / width[moving])
      metrics <- list(
        low_share = sum(dp * fraction),
        liability_rate = sum(dp * fraction * (GMT_RATE - left - width * fraction / 2)),
        fitted_mean = sum(dp * (left + width / 2))
      )
    } else {
      upper_endpoint <- max(q95, target_mean)
      q_knots <- c(0, q, upper_endpoint)
      spline <- splinefun(p_knots, q_knots, method = "hyman")
      above <- which(q_knots >= GMT_RATE)
      cutoff <- if (!length(above)) {
        1
      } else {
        i <- above[1]
        if (q_knots[i] == GMT_RATE) p_knots[i] else {
          uniroot(function(prob) spline(prob) - GMT_RATE, p_knots[c(i - 1, i)],
            tol = 1e-12
          )$root
        }
      }
      # Simpson quadrature is exact on each cubic piece.
      integrate_spline <- function(end) {
        knots <- c(p_knots[p_knots < end], end)
        left <- head(knots, -1)
        right <- tail(knots, -1)
        sum((right - left) * (spline(left) + 4 * spline((left + right) / 2) + spline(right)) / 6)
      }
      metrics <- list(
        low_share = cutoff, liability_rate = GMT_RATE * cutoff - integrate_spline(cutoff),
        fitted_mean = integrate_spline(1)
      )
    }
  }
  metrics$liability_rate <- clamp_interval(metrics$liability_rate, 0, GMT_RATE * metrics$low_share)
  as_tibble(c(metrics, list(
    topup_rate = if (metrics$low_share > 0) metrics$liability_rate / metrics$low_share else 0,
    converged = converged, sparse_tail = sparse_tail, zero_mass = zero_mass,
    upper_endpoint = upper_endpoint, mean_feasible = mean_feasible
  )))
}

fit_quantile_rows <- function(data, columns, model) {
  quantiles <- as.matrix(data[columns])
  map_dfr(seq_len(nrow(data)), function(i) {
    fit_percentile_model(quantiles[i, ], data$target_mean[i], model)
  })
}

evaluate_fit <- function(data, metric) {
  predicted <- data[[metric]]
  benchmark <- data[[paste0("direct_", metric)]]
  errors <- predicted - benchmark
  stopifnot(all(is.finite(errors)))
  calibration <- summary(lm(benchmark ~ predicted + factor(year), data = data))
  tibble(
    outcome = metric, n = length(errors), median_error = median(errors),
    mae = mean(abs(errors)), rmse = sqrt(mean(errors^2)),
    p90_absolute_error = unname(quantile(abs(errors), 0.9)),
    spearman = safe_cor(predicted, benchmark, method = "spearman"),
    calibration_slope = unname(coef(calibration)["predicted", "Estimate"]),
    calibration_r_squared = calibration$r.squared,
    mean_abs_anchor_gap = mean(abs(data$fitted_mean - data$target_mean)),
    nonconverged = sum(!data$converged),
    sparse_tail = sum(data$sparse_tail),
    mean_infeasible = sum(!data$mean_feasible, na.rm = TRUE)
  )
}

compare_percentile_estimators <- function() {
  samples <- list(
    S1_affiliate_year = read_diagnostic("step3_stage1_crossval_affiliate_year") |>
      mutate(target_mean = avg_etr_stage1),
    S2_parent_restricted = read_diagnostic("step3_stage1_crossval_affiliate_year_parent_restricted") |>
      mutate(target_mean = mean_etr),
    S3_exact_bilateral = read_diagnostic("step3_stage1_crossval_bilateral_matched") |>
      mutate(target_mean = mean_etr)
  )
  stopifnot(identical(unname(vapply(samples, nrow, integer(1))), c(361L, 70L, 81L)))
  imap_dfr(samples, function(sample, name) {
    stopifnot(all(sample$year %in% AUDIT_CV_YEARS))
    message("Fitting the five percentile models on ", name)
    map_dfr(MODEL_IDS, function(model) {
      predictions <- fit_quantile_rows(sample, Q_RAW, model)
      if (model == MODEL_IDS[1]) {
        stopifnot(
          max(abs(predictions$low_share - sample$percentile_low_share_uncapped)) < 1e-8,
          max(abs(predictions$liability_rate - sample$percentile_liability_rate_uncapped)) < 1e-8
        )
      }
      evaluation <- bind_cols(
        select(sample, year, target_mean, direct_low_share, direct_liability_rate), predictions
      )
      map_dfr(c("low_share", "liability_rate"), ~ evaluate_fit(evaluation, .x)) |>
        mutate(sample = name, estimator = model, .before = 1)
    })
  })
}

# Add a whole-period roll-up with year = NA and explicit scope.
scope_years <- function(data, countries = character()) {
  scoped <- bind_rows(
    mutate(data, scope = "Global"),
    mutate(filter(data, affiliate %in% EU27_ISO3), scope = "EU27"),
    mutate(filter(data, affiliate %in% countries), scope = affiliate)
  )
  bind_rows(scoped, mutate(scoped, year = NA_integer_))
}

audit_bilateral_percentiles <- function(stage1, affiliate_year, best_model) {
  data <- stage1 |>
    filter(year %in% AUDIT_CV_YEARS, analysis_profit_positive > 0) |>
    select(all_of(PAIR_KEY), analysis_profit_positive, has_panelai_percentiles,
      etr_panelai_reg, all_of(Q_PANELAI), stage1_distributional_source,
      stage1_lowtax_profit_distributional, stage1_topup_tax_distributional
    ) |>
    left_join(
      affiliate_year |>
        select(all_of(HOST_KEY), all_of(Q_RAW), avg_etr_stage1),
      by = HOST_KEY, relationship = "many-to-one"
    )
  # On eligible rows both fits use the same estimator. Their anchors are
  # the corresponding bilateral and pooled ETRs. Missing bilateral anchors
  # borrow the pooled anchor, holding the bilateral quantiles fixed.
  eligible <- data |>
    filter(has_panelai_percentiles, is.finite(avg_etr_stage1)) |>
    mutate(anchor_fallback = !is.finite(etr_panelai_reg),
      target_mean = if_else(anchor_fallback, avg_etr_stage1, etr_panelai_reg)
    )
  stopifnot(all(is.finite(as.matrix(eligible[Q_RAW]))))
  bilateral <- fit_quantile_rows(eligible, Q_PANELAI, best_model) |>
    select(low_share, liability_rate, converged) |>
    rename_with(~ paste0("bilateral_", .x))
  pooled <- eligible |>
    distinct(affiliate, year, across(all_of(Q_RAW)), target_mean = avg_etr_stage1)
  pooled <- bind_cols(select(pooled, all_of(HOST_KEY)),
    fit_quantile_rows(pooled, Q_RAW, best_model) |>
      select(low_share, liability_rate, converged) |>
      rename_with(~ paste0("pooled_", .x))
  )
  predictions <- bind_cols(select(eligible, all_of(PAIR_KEY), anchor_fallback), bilateral) |>
    left_join(pooled, by = HOST_KEY, relationship = "many-to-one")

  data |>
    left_join(predictions, by = PAIR_KEY, relationship = "one-to-one") |>
    mutate(
      eligible = !is.na(bilateral_low_share),
      published_low = stage1_lowtax_profit_distributional,
      published_topup = stage1_topup_tax_distributional,
      pooled_low = if_else(eligible, pooled_low_share * analysis_profit_positive, published_low),
      pooled_topup = if_else(eligible, pooled_liability_rate * analysis_profit_positive, published_topup),
      bilateral_low = if_else(eligible, bilateral_low_share * analysis_profit_positive, published_low),
      bilateral_topup = if_else(eligible, bilateral_liability_rate * analysis_profit_positive, published_topup),
      replace_fallback = eligible & stage1_distributional_source == "percentile_fit",
      hierarchy_low = if_else(replace_fallback, bilateral_low, published_low),
      hierarchy_topup = if_else(replace_fallback, bilateral_topup, published_topup)
    ) |>
    scope_years() |>
    group_by(scope, year) |>
    summarise(
      positive_cells = n(), positive_profit = sum(analysis_profit_positive),
      panelai_cells = sum(has_panelai_percentiles),
      panelai_profit = sum(analysis_profit_positive[has_panelai_percentiles]),
      panelai_profit_share = panelai_profit / positive_profit,
      paired_estimator_cells = sum(eligible),
      paired_estimator_profit = sum(analysis_profit_positive[eligible]),
      bilateral_anchor_fallback_cells = sum(anchor_fallback, na.rm = TRUE),
      nonconverged_bilateral_cells = sum(!bilateral_converged, na.rm = TRUE),
      nonconverged_pooled_cells = sum(!pooled_converged, na.rm = TRUE),
      direct_t4_cells_overridden = sum(eligible & stage1_distributional_source == "direct_t4"),
      percentile_fallback_cells_replaced = sum(replace_fallback),
      across(matches("^(published|pooled|bilateral|hierarchy)_(low|topup)$"), sum),
      .groups = "drop"
    ) |>
    mutate(
      estimator = best_model,
      bilateral_minus_pooled_low = bilateral_low - pooled_low,
      bilateral_minus_pooled_topup = bilateral_topup - pooled_topup,
      bilateral_minus_published_low = bilateral_low - published_low,
      bilateral_minus_published_topup = bilateral_topup - published_topup,
      hierarchy_minus_published_low = hierarchy_low - published_low,
      hierarchy_minus_published_topup = hierarchy_topup - published_topup
    )
}

classify_negative_tax <- function(brackets) {
  brackets |>
    filter(etr_bracket == "negative_tax_accrued") |>
    mutate(
      positive_profit = is.finite(profit) & profit > 0,
      accrued_etr = safe_divide(tax_accrued, profit),
      tax_band = case_when(
        !positive_profit ~ "outside_positive_profit",
        accrued_etr < -ZETA_LOSS_OFFSET ~ "large_negative",
        accrued_etr < 0 ~ "small_negative",
        TRUE ~ "missing_or_nonnegative_tax"
      )
    )
}

summarise_negative_tax <- function(data) {
  data |>
    scope_years() |>
    group_by(scope, year) |>
    summarise(
      bracket_rows = n(), positive_profit_cells = sum(positive_profit),
      small_negative_cells = sum(tax_band == "small_negative"),
      large_negative_cells = sum(tax_band == "large_negative"),
      other_positive_cells = sum(tax_band == "missing_or_nonnegative_tax"),
      negative_bracket_profit = sum(profit[positive_profit]),
      small_negative_profit = sum(profit[tax_band == "small_negative"]),
      large_negative_profit = sum(profit[tax_band == "large_negative"]),
      negative_bracket_tax = sum_or_na(tax_accrued[positive_profit]),
      negative_bracket_assets = sum_or_na(assets[positive_profit]),
      negative_bracket_employees = sum_or_na(employees[positive_profit]),
      positive_cells_missing_tax = sum(positive_profit & !is.finite(tax_accrued)),
      positive_cells_missing_assets = sum(positive_profit & !is.finite(assets)),
      positive_cells_missing_employees = sum(positive_profit & !is.finite(employees)),
      .groups = "drop"
    )
}

audit_negative_tax_bracket <- function(raw_t4, pooled_t4, affiliate_year) {
  raw <- classify_negative_tax(raw_t4)
  pooled <- classify_negative_tax(pooled_t4)
  inventory <- bind_rows(
    mutate(summarise_negative_tax(raw), level = "bilateral"),
    mutate(summarise_negative_tax(pooled), level = "affiliate_year")
  ) |>
    mutate(section = "inventory", .before = 1)

  # Classify the raw rows before pooling to avoid netting different bands
  # across parents. The pooled inventory above records the netted result.
  negative_by_host <- raw |>
    group_by(affiliate, year) |>
    summarise(
      all_negative_profit = sum(profit[positive_profit]),
      small_negative_profit = sum(profit[tax_band == "small_negative"]),
      .groups = "drop"
    )

  reference <- affiliate_year |>
    filter(year %in% AUDIT_YEARS, direct_available, total_analysis_profit_positive > 0) |>
    select(
      all_of(HOST_KEY), total_analysis_profit_positive, direct_positive_profit_total,
      direct_low_profit, direct_low_share, direct_topup_rate, direct_liability_rate
    ) |>
    left_join(negative_by_host, by = HOST_KEY, relationship = "one-to-one") |>
    mutate(
      all_negative_profit = coalesce(all_negative_profit, 0),
      small_negative_profit = coalesce(small_negative_profit, 0),
      base_numerator = direct_low_profit * direct_topup_rate
    )

  scenarios <- tribble(
    ~scenario, ~add_all_to_denominator, ~add_small_to_numerator,
    "baseline", FALSE, FALSE,
    "all_negative_profit_in_denominator", TRUE, FALSE,
    "all_in_denominator_small_in_low_at_zero_etr", TRUE, TRUE,
    "only_small_in_denominator_and_low_at_zero_etr", FALSE, TRUE
  )
  sensitivity <- crossing(reference, scenarios) |>
    mutate(
      denominator = direct_positive_profit_total + case_when(
        add_all_to_denominator ~ all_negative_profit,
        add_small_to_numerator ~ small_negative_profit,
        TRUE ~ 0
      ),
      numerator = direct_low_profit + if_else(add_small_to_numerator, small_negative_profit, 0),
      low_tax_topup = base_numerator + if_else(add_small_to_numerator, GMT_RATE * small_negative_profit, 0),
      low_share = numerator / denominator,
      liability_rate = low_tax_topup / denominator
    )
  baseline <- filter(sensitivity, scenario == "baseline")
  stopifnot(
    max(abs(baseline$low_share - baseline$direct_low_share)) < 1e-12,
    max(abs(baseline$liability_rate - baseline$direct_liability_rate)) < 1e-12
  )
  effects <- sensitivity |>
    scope_years(AUDIT_HUBS) |>
    group_by(scope, year, scenario) |>
    summarise(
      direct_affiliate_years = n(),
      direct_affiliate_years_with_negative_profit = sum(all_negative_profit > 0),
      corrected_profit_weight = sum(total_analysis_profit_positive),
      low_share = weighted_mean_available(low_share, total_analysis_profit_positive),
      liability_rate = weighted_mean_available(liability_rate, total_analysis_profit_positive),
      low_share_change = low_share -
        weighted_mean_available(direct_low_share, total_analysis_profit_positive),
      liability_rate_change = liability_rate -
        weighted_mean_available(direct_liability_rate, total_analysis_profit_positive),
      t4_profit_weighted_low_share = sum(numerator) / sum(denominator),
      t4_profit_weighted_liability_rate = sum(low_tax_topup) / sum(denominator),
      implied_stage1_topup = sum(total_analysis_profit_positive * liability_rate),
      .groups = "drop"
    ) |>
    mutate(section = "direct_rate_sensitivity", level = "affiliate_year", .before = 1)
  bind_rows(inventory, effects)
}

bracket_shields <- function(t4, wage, keys, endpoints) {
  t4 |>
    filter(etr_bracket %in% T4_POSITIVE_BRACKETS) |>
    mutate(
      bracket = if_else(etr_bracket == "rate_0_15", "low", "high"),
      complete_inputs = is.finite(profit) & profit >= 0 &
        is.finite(assets) & assets >= 0 & is.finite(employees) & employees >= 0
    ) |>
    group_by(across(all_of(keys)), bracket) |>
    summarise(
      bracket_rows = n(),
      all_observed = all(complete_inputs),
      across(c(profit, assets, employees), sum_or_na),
      .groups = "drop"
    ) |>
    pivot_wider(
      names_from = bracket,
      values_from = c(bracket_rows, all_observed, profit, assets, employees)
    ) |>
    left_join(wage, by = HOST_KEY, relationship = "many-to-one") |>
    crossing(endpoints) |>
    mutate(
      usable_wage = is.finite(affiliate_wage_annual) & affiliate_wage_annual > 0,
      usable_low = coalesce(all_observed_low & profit_low > 0, FALSE) & usable_wage,
      usable_high = coalesce(all_observed_high & profit_high > 0, FALSE) & usable_wage,
      usable_all = usable_low & coalesce(all_observed_high, FALSE),
      sbie_low = sigma_w * employees_low * affiliate_wage_annual + sigma_a * assets_low,
      sbie_high = sigma_w * employees_high * affiliate_wage_annual + sigma_a * assets_high,
      phi_low = if_else(usable_low, clamp_unit_interval(safe_divide(sbie_low, profit_low)), NA_real_),
      phi_high = if_else(usable_high, clamp_unit_interval(safe_divide(sbie_high, profit_high)), NA_real_),
      phi_all = if_else(usable_all,
        clamp_unit_interval(safe_divide(sbie_low + sbie_high, profit_low + profit_high)),
        NA_real_
      ),
      paired_brackets = usable_low & usable_high
    )
}

test_bracket_shields <- function(partitions) {
  sample <- partitions |>
    filter(paired_brackets) |>
    mutate(partition = paste(coalesce(parent, ""), affiliate, year, sep = "/")) |>
    scope_years() |>
    filter(is.na(year)) |>
    group_by(level, scope, rate_scenario)
  sample |>
    group_modify(function(data, keys) {
      differences <- data$phi_low - data$phi_high
      wilcox_two <- wilcox.test(differences, exact = FALSE)
      wilcox_less <- wilcox.test(differences, alternative = "less", exact = FALSE)
      stacked <- bind_rows(
        transmute(data, affiliate, partition, phi = phi_low, low_bracket = 1),
        transmute(data, affiliate, partition, phi = phi_high, low_bracket = 0)
      )
      regression <- fixest::feols(phi ~ low_bracket | partition, data = stacked,
        vcov = ~affiliate, notes = FALSE
      )
      estimate <- unname(coef(regression)["low_bracket"])
      stopifnot(abs(estimate - mean(differences)) < 1e-10)
      table <- fixest::coeftable(regression)
      tibble(
        n_pairs = nrow(data), n_affiliate_clusters = n_distinct(data$affiliate),
        mean_phi_low = mean(data$phi_low), mean_phi_high = mean(data$phi_high),
        median_phi_difference = median(differences),
        share_low_below_high = mean(differences < 0),
        share_equal = mean(differences == 0),
        wilcoxon_statistic = unname(wilcox_two$statistic),
        wilcoxon_p_two_sided = wilcox_two$p.value,
        wilcoxon_p_less = wilcox_less$p.value,
        fe_estimate = estimate, fe_clustered_se = unname(table["low_bracket", "Std. Error"]),
        fe_clustered_p = unname(table["low_bracket", "Pr(>|t|)"])
      )
    }) |>
    ungroup() |>
    mutate(section = "paired_tests", .before = 1)
}

summarise_shield_revenue <- function(stage2, partitions, keys, level) {
  # Hold the Stage 1 liability fixed within each level. The affiliate-year
  # case starts from the pooled Stage 1 branch, and the bilateral case starts
  # from the bilateral-first branch. Unsupported rows retain the saved SBIE.
  suffix <- if (level == "bilateral") "_bilat" else ""
  amounts <- stage2 |>
    filter(year %in% AUDIT_YEARS, analysis_profit_positive > 0) |>
    transmute(
      across(all_of(PAIR_KEY)), rate_scenario, analysis_profit_positive, stage2_phi,
      pre_sbie_topup = coalesce(.data[[paste0("stage1_topup_tax_distributional", suffix)]], 0),
      table1_topup = .data[[paste0("stage2_topup_tax_distributional", suffix)]]
    ) |>
    left_join(
      partitions |>
        select(all_of(keys), rate_scenario, phi_all, phi_low, phi_high, paired_brackets),
      by = c(keys, "rate_scenario"), relationship = "many-to-one"
    )
  stopifnot(max(abs(amounts$table1_topup - amounts$pre_sbie_topup * (1 - amounts$stage2_phi))) < 1e-5)

  map_dfr(c("paired_brackets", "low_bracket_observed"), function(support) {
    amounts |>
      mutate(
        eligible = if (support == "paired_brackets") coalesce(paired_brackets, FALSE) else is.finite(phi_low),
        t4_low_topup = if_else(eligible, pre_sbie_topup * (1 - phi_low), table1_topup),
        t4_all_topup = if_else(eligible & is.finite(phi_all), pre_sbie_topup * (1 - phi_all), table1_topup),
        eligible_pre_sbie_topup = if_else(eligible, pre_sbie_topup, 0),
        paired_pre_sbie_topup = if_else(coalesce(paired_brackets, FALSE), pre_sbie_topup, 0)
      ) |>
      scope_years(EU27_ISO3) |>
      group_by(scope, year, rate_scenario) |>
      summarise(
        positive_profit_cells = n(), matched_cells = sum(eligible),
        matched_liability_cells = sum(eligible & pre_sbie_topup > 0),
        positive_profit = sum(analysis_profit_positive),
        matched_positive_profit = sum(analysis_profit_positive[eligible]),
        pre_sbie_topup = sum(pre_sbie_topup),
        matched_pre_sbie_topup = sum(eligible_pre_sbie_topup),
        table1_topup = sum(table1_topup), t4_low_topup = sum(t4_low_topup),
        t4_all_topup = sum(t4_all_topup),
        matched_table1_topup = sum(table1_topup[eligible]),
        matched_t4_low_topup = sum(t4_low_topup[eligible]),
        phi_table1_liability_weighted =
          weighted_mean_available(stage2_phi, eligible_pre_sbie_topup),
        phi_low_liability_weighted =
          weighted_mean_available(phi_low, eligible_pre_sbie_topup),
        phi_high_liability_weighted =
          weighted_mean_available(phi_high, paired_pre_sbie_topup),
        phi_all_liability_weighted =
          weighted_mean_available(phi_all, paired_pre_sbie_topup),
        .groups = "drop"
      ) |>
      mutate(
        section = "post_sbie_revenue", level = level, support = support,
        t4_low_minus_table1 = t4_low_topup - table1_topup,
        t4_all_minus_table1 = t4_all_topup - table1_topup,
        t4_low_minus_table1_pct = 100 * safe_divide(t4_low_minus_table1, table1_topup),
        .before = 1
      )
  })
}

audit_bracket_substance <- function(raw_t4, pooled_t4, stage2) {
  wage <- stage2 |>
    filter(year %in% AUDIT_YEARS) |>
    distinct(affiliate, year, affiliate_wage_annual)
  assert_unique_keys(wage, HOST_KEY, "audit wage lookup")
  endpoints <- distinct(stage2, rate_scenario, sigma_w, sigma_a)
  assert_unique_keys(endpoints, "rate_scenario", "audit SBIE rates")
  bilateral <- bracket_shields(raw_t4, wage, PAIR_KEY, endpoints)
  pooled <- bracket_shields(pooled_t4, wage, HOST_KEY, endpoints)

  partition_rows <- bind_rows(
    mutate(bilateral, level = "bilateral"),
    mutate(pooled, level = "affiliate_year")
  )
  table1_phi <- stage2 |>
    filter(year %in% AUDIT_YEARS, analysis_profit_positive > 0)
  matched_table1 <- bind_rows(
    table1_phi |>
      transmute(across(all_of(PAIR_KEY)), rate_scenario,
        phi_table1 = stage2_phi, level = "bilateral"
      ),
    table1_phi |>
      group_by(affiliate, year, rate_scenario) |>
      summarise(
        phi_table1 = weighted_mean_available(stage2_phi, analysis_profit_positive),
        .groups = "drop"
      ) |>
      mutate(level = "affiliate_year", parent = NA_character_)
  )
  partition_rows <- partition_rows |>
    left_join(matched_table1,
      by = c("level", PAIR_KEY, "rate_scenario"),
      relationship = "one-to-one"
    ) |>
    mutate(section = "partition_shields", .before = 1)

  bind_rows(
    partition_rows,
    test_bracket_shields(partition_rows),
    summarise_shield_revenue(stage2, pooled, HOST_KEY, "affiliate_year"),
    summarise_shield_revenue(stage2, bilateral, PAIR_KEY, "bilateral")
  )
}

run_audit <- function() {
  if (!requireNamespace("fixest", quietly = TRUE)) {
    stop("The bracket fixed-effect diagnostic requires fixest")
  }
  comparison <- compare_percentile_estimators()
  write_audit(comparison, "stage1_estimator_comparison")

  # Select the most accurate liability estimator on the exact-matched
  # sample. This is a benchmark choice within these data.
  best_model <- comparison |>
    filter(sample == "S3_exact_bilateral", outcome == "liability_rate") |>
    arrange(mae) |>
    slice_head(n = 1) |>
    pull(estimator)
  message("Applying ", best_model, " to bilateral and pooled Table I quantiles")
  stage1 <- read_processed("stage1_bilateral_panel")
  affiliate_year <- read_processed("stage1_affiliate_year")
  write_audit(audit_bilateral_percentiles(stage1, affiliate_year, best_model),
    "stage1_bilateral_percentiles"
  )

  aggregate_codes <- c("A", "A_O", "E", "E_O", "F", "F_O", "S", "S_O", "W", "W_O", "WXD", "STLS")
  t4 <- read_processed("cbcr_table4") |>
    filter(year %in% AUDIT_YEARS, !affiliate %in% aggregate_codes)
  raw_t4 <- filter(t4, !parent %in% aggregate_codes)
  # Stage 5 caps employment in the production bracket files. Reconstruct
  # the published pooled employment count for this historical audit.
  published_employment <- t4 |>
    group_by(affiliate, year, etr_bracket) |>
    summarise(employees = sum_or_na(employees), .groups = "drop")
  pooled_t4 <- read_processed("base_panel_t4_bracket_shares") |>
    filter(year %in% AUDIT_YEARS) |>
    select(-employees) |>
    left_join(published_employment, by = c(HOST_KEY, "etr_bracket"), relationship = "one-to-one")
  assert_unique_keys(raw_t4, c(PAIR_KEY, "etr_bracket"), "audit bilateral Table IV")
  assert_unique_keys(pooled_t4, c(HOST_KEY, "etr_bracket"), "audit pooled Table IV")

  message("Auditing the negative-accrued-tax bracket")
  write_audit(audit_negative_tax_bracket(raw_t4, pooled_t4, affiliate_year),
    "stage1_t4_negative_tax_bracket"
  )

  message("Auditing bracket-specific Stage 2 substance")
  stage2 <- read_processed("stage2_bilateral_panel")
  published_substance <- audit_bracket_substance(raw_t4, pooled_t4, stage2) |>
    mutate(t4_sample = "as_published", .after = section)

  # The source CSV labels the Brazilian FY2021 employee figures as persons,
  # including 1,158,261,000 in the domestic low-tax bracket. Exclude the
  # parent return in a sensitivity without assuming a correction factor.
  screened_t4 <- filter(t4, !(parent == "BRA" & year == 2021L))
  screened_pooled <- screened_t4 |>
    group_by(affiliate, year, etr_bracket) |>
    summarise(across(c(profit, assets, employees), sum_or_na), .groups = "drop")
  screened_substance <- audit_bracket_substance(
    filter(screened_t4, !parent %in% aggregate_codes), screened_pooled, stage2
  ) |>
    filter(section != "partition_shields", scope %in% c("Global", "EU27")) |>
    mutate(t4_sample = "exclude_BRA_parent_FY2021", .after = section)

  write_audit(bind_rows(published_substance, screened_substance),
    "stage2_bracket_substance"
  )
  message("Step 4 audit complete")
}

if (is_direct_script_run("code/diagnostics_step4_stage1_stage2_audit.R")) {
  run_audit()
}
