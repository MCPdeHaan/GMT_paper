# Measurement validation, bilateral ETR aggregation and CbCR Tables II–VI.

source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "03_stage1_etr.R"), local = TRUE)
source(file.path(GMT_PROJECT_ROOT, "code", "05_stage3_behavioral.R"), local = TRUE)
source(file.path(GMT_PROJECT_ROOT, "code", "06_stage4_5_revenue_allocation_sbs.R"), local = TRUE)
source(file.path(GMT_PROJECT_ROOT, "code", "07_stage4_6_revenue_pipeline_decomposition.R"), local = TRUE)

# Percentile estimators, negative accrued taxes and bracket-specific substance

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

read_measurement_audit_input <- function(name) readRDS(file.path(PROCESSED_DIR, paste0(name, ".rds")))
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

run_etr_and_bracket_audit <- function() {
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
  stage1 <- read_measurement_audit_input("stage1_bilateral_panel")
  affiliate_year <- read_measurement_audit_input("stage1_affiliate_year")
  write_audit(audit_bilateral_percentiles(stage1, affiliate_year, best_model),
    "stage1_bilateral_percentiles"
  )

  aggregate_codes <- c("A", "A_O", "E", "E_O", "F", "F_O", "S", "S_O", "W", "W_O", "WXD", "STLS")
  t4 <- read_measurement_audit_input("cbcr_table4") |>
    filter(year %in% AUDIT_YEARS, !affiliate %in% aggregate_codes)
  raw_t4 <- filter(t4, !parent %in% aggregate_codes)
  # Stage 5 caps employment in the production bracket files. Reconstruct
  # the published pooled employment count for this historical audit.
  published_employment <- t4 |>
    group_by(affiliate, year, etr_bracket) |>
    summarise(employees = sum_or_na(employees), .groups = "drop")
  pooled_t4 <- read_measurement_audit_input("base_panel_t4_bracket_shares") |>
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
  stage2 <- read_measurement_audit_input("stage2_bilateral_panel")
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

# Bilateral ETR ladder and national budget backtest

LADDER_HOSTS <- c("NLD", "LUX", "IRL", "DEU", "FRA", "BEL")
LADDER_BUDGET_COUNTRIES <- c(LADDER_HOSTS, "AUT", "SVK")
LADDER_WINDOWS <- list(
  "2017–2023" = MAIN_YEARS, "2019–2023" = DIRECT_YEARS,
  "2021–2023" = PERCENTILE_YEARS, "FY2023" = max(MAIN_YEARS)
)
LADDER_EUR_USD <- 1.0813

ladder_read <- function(stem) readRDS(file.path(PROCESSED_DIR, paste0(stem, ".rds")))

ladder_write <- function(data, stem) {
  write_csv(data, file.path(DIAGNOSTICS_DIR, paste0("step9_", stem, ".csv")))
}

ladder_windows <- function(data, windows = LADDER_WINDOWS) {
  imap_dfr(windows, function(years, window) {
    data |> filter(year %in% years) |> mutate(window = window, years_in_window = length(years))
  })
}

ladder_apply_sbie <- function(measurement, stage2) {
  stage2 |>
    left_join(
      select(measurement, all_of(LADDER_KEYS), share, gap, low_profit, stage1_tax),
      by = LADDER_KEYS, relationship = "many-to-one"
    ) |>
    mutate(
      sbie_filter = 1 - coalesce(stage2_phi, 0),
      excess_low_profit = low_profit * sbie_filter,
      stage2_tax = stage1_tax * sbie_filter
    )
}

ladder_rebuild_scenarios <- function(measurement, post_sbie, factorial, host_stage1, sectors, beta) {
  host_rates <- measurement |>
    summarise(
      host_share = safe_divide(sum(low_profit), sum(analysis_profit_positive)),
      host_gap = coalesce(safe_divide(sum(stage1_tax), sum(low_profit)), 0),
      .by = c(affiliate, year)
    )
  updated_host <- host_stage1 |>
    left_join(host_rates, by = c("affiliate", "year"), relationship = "one-to-one") |>
    mutate(stage1_distributional_low_share = host_share, stage1_distributional_topup_rate = host_gap)
  updated_sectors <- sectors |>
    select(-stage1_distributional_topup_rate) |>
    left_join(select(updated_host, affiliate, year, stage1_distributional_topup_rate),
      by = c("affiliate", "year"), relationship = "many-to-one")
  bridge <- build_sectoral_factor2_bridge(
    mutate(post_sbie, stage2_topup_tax_distributional = stage2_tax), updated_host, updated_sectors
  )
  scenarios <- factorial |>
    filter(x1_etr == 1) |>
    left_join(
      select(post_sbie, all_of(LADDER_KEYS), rate_scenario, share, gap, low_profit,
        excess_low_profit, stage2_tax),
      by = c(LADDER_KEYS, "rate_scenario"), relationship = "many-to-one"
    ) |>
    left_join(
      select(bridge, affiliate, year, rate_scenario, ladder_scale = sectoral_scale_distributional),
      by = c("affiliate", "year", "rate_scenario"), relationship = "many-to-one"
    ) |>
    mutate(
      stage1_distributional_low_share = share,
      stage1_lowtax_profit_distributional = low_profit,
      stage2_excess_lowtax_profit_distributional = excess_low_profit,
      stage2_topup_selected = stage2_tax,
      sectoral_scale_selected = if_else(x2_substance == 0, 1, coalesce(ladder_scale, 1)),
      topup_after_stage2 = stage2_topup_selected * sectoral_scale_selected,
      # The behavioural threshold and slope are evaluated at each cell's
      # own implied low-tax ETR in the bilateral levels.
      tau_low = if_else(share > 0 & gap > 0, GMT_RATE - gap, NA_real_)
    )
  raw_beta <- coalesce(compute_reallocation_share(
    scenarios$tau_low, rep_len("linear", nrow(scenarios)), beta
  ), 0)
  replace_behaviour_schedule(scenarios, scenarios$tau_low, raw_beta) |>
    select(all_of(names(factorial)))
}

ladder_allocate <- function(panel, weights) {
  source <- build_source_panel(panel)
  allocation <- allocate_stage4_revenue(source, weights)
  conservation <- build_conservation_diagnostics(source, allocation$revenue_by_channel_global)
  stopifnot(nrow(allocation$revenue_country_year_eu27) == length(EU27_ISO3) * length(MAIN_YEARS) * 16)
  list(
    revenue = allocation$revenue_country_year_eu27,
    channels = allocation$revenue_by_channel_eu27,
    conservation = conservation,
    preferred_source = source |>
      filter(x2_substance == 0, x3_rates == 0, x5_behaviour == 1) |>
      select(all_of(LADDER_KEYS), x4_sbs, topup_after_behaviour,
        stage4_qdmtt_liability, stage4_iir_liability, stage4_utpr_pool,
        stage4_sbs_extinguished_liability)
  )
}

ladder_stage_summary <- function(measurements, post_sbie) {
  scopes <- bind_rows(
    mutate(measurements, scope = "Global"),
    mutate(filter(measurements, affiliate_is_eu27), scope = "EU27")
  ) |>
    filter(analysis_profit_positive > 0) |>
    ladder_windows()
  totals <- scopes |>
    summarise(
      positive_cells = n(), measured_cells = sum(measured),
      positive_profit_usd = sum(analysis_profit_positive),
      measured_profit_usd = sum(analysis_profit_positive[measured]),
      lowtax_profit_usd = sum(low_profit), stage1_topup_usd = sum(stage1_tax),
      .by = c(level, scope, window, years_in_window)
    ) |>
    mutate(
      record_type = "summary",
      measured_profit_share = measured_profit_usd / positive_profit_usd,
      low_share = lowtax_profit_usd / positive_profit_usd,
      topup_gap = safe_divide(stage1_topup_usd, lowtax_profit_usd),
      liability_rate = stage1_topup_usd / positive_profit_usd
    )
  sbie_totals <- bind_rows(mutate(post_sbie, scope = "Global"),
    mutate(filter(post_sbie, affiliate_is_eu27), scope = "EU27")) |>
    ladder_windows() |>
    summarise(stage2_topup_usd_bn = sum(stage2_tax) / 1e9,
      .by = c(level, scope, window, rate_scenario)
    ) |>
    pivot_wider(names_from = rate_scenario, values_from = stage2_topup_usd_bn,
      names_prefix = "stage2_topup_usd_bn_")
  tiers <- scopes |>
    summarise(
      positive_cells = n(), positive_profit_usd = sum(analysis_profit_positive),
      lowtax_profit_usd = sum(low_profit), stage1_topup_usd = sum(stage1_tax),
      percentile_fit_rank_violations = sum(percentile_fit_rank_violation),
      rank_violation_profit_usd = sum(analysis_profit_positive[percentile_fit_rank_violation]),
      .by = c(level, scope, window, years_in_window, source_tier)
    ) |>
    group_by(level, scope, window) |>
    mutate(tier_profit_share = positive_profit_usd / sum(positive_profit_usd)) |>
    ungroup() |>
    mutate(record_type = "coverage_by_tier")
  bind_rows(left_join(totals, sbie_totals, by = c("level", "scope", "window"),
    relationship = "one-to-one"), tiers) |>
    relocate(record_type, level, scope, window, source_tier)
}

ladder_parent_breakdown <- function(measurements, preferred_source, cells) {
  detail <- preferred_source |>
    filter(x4_sbs == 1, affiliate %in% LADDER_HOSTS, year %in% PERCENTILE_YEARS) |>
    select(level, all_of(LADDER_KEYS), stage4_qdmtt_liability) |>
    inner_join(measurements, by = c("level", LADDER_KEYS), relationship = "one-to-one") |>
    filter(analysis_profit_positive > 0) |>
    mutate(parent_group = case_when(
      parent == affiliate ~ "domestic",
      parent == "USA" ~ "us_parents",
      TRUE ~ "other_foreign"
    ))
  aggregates <- detail |>
    ladder_windows(LADDER_WINDOWS[c("2021–2023", "FY2023")]) |>
    summarise(
      across(c(analysis_profit_positive, low_profit, stage1_tax, stage4_qdmtt_liability), sum),
      positive_cells = n(),
      .by = c(level, affiliate, window, years_in_window, parent_group)
    ) |>
    group_by(level, affiliate, window) |>
    mutate(qdmtt_parent_group_share = safe_divide(stage4_qdmtt_liability, sum(stage4_qdmtt_liability))) |>
    ungroup() |>
    mutate(record_type = "parent_group")
  selected <- detail |>
    filter(
      (parent == affiliate & affiliate %in% c("NLD", "LUX", "DEU", "FRA")) |
        (affiliate == "NLD" & parent %in% c("GBR", "DEU", "USA"))
    ) |>
    left_join(
      select(cells, all_of(LADDER_KEYS), all_of(LADDER_QUANTILES), etr_panelai_raw,
        etr_panelai_stage1, has_panelai_percentiles, percentile_source, fitted_precision,
        transport_candidate_precision = selected_precision, pair_precision, host_year_precision,
        host_median_precision, fit_rmse, percentile_rank_lower, percentile_rank_upper),
      by = LADDER_KEYS, relationship = "many-to-one"
    ) |>
    mutate(record_type = "cell_year", window = paste0("FY", year), years_in_window = 1L)
  bind_rows(aggregates, selected) |>
    mutate(
      qdmtt_eur_bn = stage4_qdmtt_liability / LADDER_EUR_USD / 1e9,
      qdmtt_annualised_eur_bn = qdmtt_eur_bn / years_in_window
    ) |>
    relocate(record_type, level, affiliate, parent, parent_group, year, window) |>
    arrange(record_type, level, affiliate, window, parent_group, parent)
}

ladder_sbs_summary <- function(preferred_source, preferred_revenue) {
  sources <- bind_rows(
    mutate(preferred_source, scope = "Global"),
    mutate(filter(preferred_source, affiliate %in% EU27_ISO3), scope = "EU27"),
    mutate(filter(preferred_source, affiliate %in% EU27_ISO3), scope = affiliate)
  ) |>
    ladder_windows() |>
    summarise(
      source_topup_usd = sum(topup_after_behaviour),
      us_parent_source_usd = sum(topup_after_behaviour[parent == "USA"]),
      sbs_extinguished_source_usd = sum(stage4_sbs_extinguished_liability),
      source_qdmtt_usd = sum(stage4_qdmtt_liability),
      source_iir_usd = sum(stage4_iir_liability),
      source_utpr_usd = sum(stage4_utpr_pool),
      .by = c(level, scope, window, years_in_window, x4_sbs)
    ) |>
    mutate(
      us_parent_source_share = safe_divide(us_parent_source_usd, source_topup_usd),
      sbs_extinguished_source_share = safe_divide(sbs_extinguished_source_usd, source_topup_usd)
    )
  collectors <- bind_rows(
    mutate(preferred_revenue, scope = country),
    mutate(preferred_revenue, scope = "EU27")
  ) |>
    ladder_windows() |>
    summarise(direct_collector_usd = sum(revenue), .by = c(level, scope, window, x4_sbs))
  sources |>
    left_join(collectors, by = c("level", "scope", "window", "x4_sbs"), relationship = "one-to-one") |>
    mutate(regime = if_else(x4_sbs == 1, "sbs", "universal")) |>
    select(-x4_sbs) |>
    pivot_wider(
      names_from = regime, names_glue = "{.value}_{regime}",
      values_from = c(source_topup_usd, us_parent_source_usd, sbs_extinguished_source_usd,
        source_qdmtt_usd, source_iir_usd, source_utpr_usd, us_parent_source_share,
        sbs_extinguished_source_share, direct_collector_usd)
    ) |>
    mutate(
      collector_reduction_usd = direct_collector_usd_universal - direct_collector_usd_sbs,
      collector_reduction_share = safe_divide(collector_reduction_usd, direct_collector_usd_universal)
    ) |>
    arrange(level, scope, window)
}

ladder_official_forecasts <- function() {
  forecasts <- read_csv(file.path(DIAGNOSTICS_DIR, "step7_official_budget_forecasts_backtest.csv"),
    show_col_types = FALSE
  ) |>
    filter(window == "FY2023", country %in% LADDER_BUDGET_COUNTRIES,
      startsWith(evidence, "official") | evidence %in% c("implied by official figures", "academic estimate")
    ) |>
    select(country, benchmark, evidence, forecast_period, revenue_scope, model_scope,
      comparison_scope, official_low_eur_bn, official_high_eur_bn, stated_sbs_switch, source_url)
  luxembourg <- tibble(
    country = "LUX", benchmark = "Luxembourg 2026 budget Pillar Two minimum tax",
    evidence = "official forecast", forecast_period = "2026 cash",
    revenue_scope = "Pillar Two minimum tax, channels not disaggregated", model_scope = "direct",
    comparison_scope = "Direct collector revenue compared to the Pillar Two budget line",
    official_low_eur_bn = 0.080, official_high_eur_bn = 0.080,
    source_url = paste0("https://budget.public.lu/dam-assets/lb/budget2026/",
      "links-dokumenter/lu-ppb-2026.pdf")
  )
  slovakia <- tibble(
    country = "SVK", benchmark = "Slovakia 2026 state budget Pillar Two line",
    evidence = "official forecast", forecast_period = "2026 state budget",
    revenue_scope = "Global minimum tax budget line", model_scope = "direct",
    comparison_scope = "Direct collector revenue compared to the Pillar Two budget line",
    official_low_eur_bn = 0.0485, official_high_eur_bn = 0.0485,
    source_url = "https://www.mfsr.sk/files/archiv/44/Text.pdf"
  )
  bind_rows(forecasts, luxembourg, slovakia)
}

ladder_budget_backtest <- function(revenue, channels) {
  scenario_keys <- c("level", "country", "year", "scenario_id")
  channel_totals <- channels |>
    filter(country %in% LADDER_BUDGET_COUNTRIES) |>
    summarise(qdmt = sum(revenue[channel == "QDMTT"]),
      iir = sum(revenue[channel == "IIR"]), .by = all_of(scenario_keys)
    )
  matched <- revenue |>
    filter(country %in% LADDER_BUDGET_COUNTRIES) |>
    select(all_of(scenario_keys), all_of(FACTOR_COLS), direct = revenue) |>
    left_join(channel_totals, by = scenario_keys, relationship = "one-to-one") |>
    mutate(across(c(qdmt, iir), ~ coalesce(.x, 0))) |>
    ladder_windows(LADDER_WINDOWS[c("2019–2023", "FY2023")]) |>
    summarise(across(c(direct, qdmt, iir), ~ sum(.x) / first(years_in_window) / LADDER_EUR_USD / 1e9),
      .by = c(level, country, window, scenario_id, all_of(FACTOR_COLS))
    ) |>
    pivot_longer(c(direct, qdmt, iir), names_to = "model_scope", values_to = "annual_eur_bn") |>
    inner_join(ladder_official_forecasts(), by = c("country", "model_scope"),
      relationship = "many-to-many"
    ) |>
    mutate(
      gap_to_benchmark_eur_bn = pmax(official_low_eur_bn - annual_eur_bn,
        annual_eur_bn - official_high_eur_bn, 0),
      preferred = x2_substance == 0 & x3_rates == 0 & x5_behaviour == 1
    )
  matched |>
    arrange(gap_to_benchmark_eur_bn, scenario_id) |>
    summarise(
      official_low_eur_bn = first(official_low_eur_bn),
      official_high_eur_bn = first(official_high_eur_bn),
      stated_sbs_switch = first(stated_sbs_switch),
      source_url = first(source_url),
      scenario_min_eur_bn = min(annual_eur_bn), scenario_max_eur_bn = max(annual_eur_bn),
      preferred_universal_eur_bn = annual_eur_bn[preferred & x4_sbs == 0],
      preferred_sbs_eur_bn = annual_eur_bn[preferred & x4_sbs == 1],
      closest_scenario = if_else(is.finite(first(gap_to_benchmark_eur_bn)), first(scenario_id), NA_character_),
      closest_scenario_eur_bn = if_else(is.na(closest_scenario), NA_real_, first(annual_eur_bn)),
      closest_gap_eur_bn = first(gap_to_benchmark_eur_bn),
      .by = c(level, country, window, benchmark, evidence, forecast_period, revenue_scope, model_scope,
        comparison_scope)
    ) |>
    mutate(
      official_interval_overlaps_model_range = official_high_eur_bn >= scenario_min_eur_bn &
        official_low_eur_bn <= scenario_max_eur_bn,
      preferred_policy_comparable_eur_bn = case_when(
        stated_sbs_switch == 0 ~ preferred_universal_eur_bn,
        stated_sbs_switch == 1 ~ preferred_sbs_eur_bn
      )
    ) |>
    arrange(country, benchmark, window, level)
}

ladder_binary_stage46 <- function(low, high) {
  objects <- map(c("revenue", "channels", "conservation"), function(component) {
    bind_rows(
      mutate(low[[component]], x1_etr = 0L, factor1_etr = "average"),
      mutate(high[[component]], x1_etr = 1L, factor1_etr = "distributional")
    ) |>
      mutate(scenario_id = paste0("x", x1_etr, x2_substance, x3_rates, x4_sbs, x5_behaviour))
  })
  validation <- validate_revenue_inputs(objects[[1]], objects[[2]], objects[[3]])
  tibble(
    max_global_conservation_gap_usd =
      as.numeric(validation$value[validation$metric == "max_global_conservation_gap"]),
    max_country_channel_gap_usd =
      as.numeric(validation$value[validation$metric == "max_country_channel_gap"])
  )
}

ladder_anova <- function(revenue, level_order, design_name, validation) {
  factor_names <- FACTOR_COLS
  binary_factors <- factor_names[-1]
  n_levels <- length(level_order)
  dimensions <- c(n_levels, rep(2L, length(binary_factors)))
  design_rows <- revenue |>
    filter(level %in% level_order) |>
    distinct(level, across(all_of(binary_factors))) |>
    mutate(level_index = match(level, level_order)) |>
    arrange(level_index, across(all_of(binary_factors))) |>
    mutate(design_id = paste0("design_", row_number()))
  stopifnot(nrow(design_rows) == prod(dimensions))

  # Adjacent pairwise differences overlap, so they cannot all be orthogonal.
  # Gram–Schmidt in the requested order gives these Helmert contrasts.
  first_basis <- cbind(1, contr.helmert(n_levels))
  first_basis <- sweep(first_basis, 2, sqrt(colSums(first_basis^2)), "/")
  binary_basis <- cbind(1, c(-1, 1)) / sqrt(2)
  bases <- c(list(first_basis[design_rows$level_index, , drop = FALSE]),
    map(binary_factors, ~ binary_basis[design_rows[[.x]] + 1L, , drop = FALSE]))
  term_indices <- as.matrix(do.call(expand.grid, lapply(dimensions, seq_len)))
  contrast_matrix <- apply(term_indices, 1, function(indices) {
    Reduce(`*`, map(seq_along(bases), ~ bases[[.x]][, indices[.x]]))
  })
  stopifnot(max(abs(crossprod(contrast_matrix) - diag(nrow(design_rows)))) < 1e-12)
  term_order <- rowSums(term_indices > 1)

  wide <- revenue |>
    filter(level %in% level_order) |>
    inner_join(design_rows, by = c("level", binary_factors), relationship = "many-to-one") |>
    select(country, year, design_id, revenue) |>
    pivot_wider(names_from = design_id, values_from = revenue)
  y <- t(as.matrix(wide[design_rows$design_id]))
  stopifnot(ncol(y) == length(EU27_ISO3) * length(MAIN_YEARS), all(is.finite(y)))
  weights <- c("−1, +1, 0, 0", "−1, −1, +2, 0", "−1, −1, −1, +3")
  contrast_labels <- c("1a_cross_parent", "1b_within_cell", "1c_parent_selection")
  imap_dfr(LADDER_WINDOWS[1:3], function(years, window) {
    window_y <- y[, wide$year %in% years, drop = FALSE]
    ss <- rowSums(crossprod(contrast_matrix, window_y)^2)
    total_ss <- sum(sweep(window_y, 2, colMeans(window_y))^2)
    stopifnot(abs(sum(ss[term_order > 0]) / total_ss - 1) < 1e-12)
    eta <- ss / total_ss
    factor_rows <- map_dfr(seq_along(factor_names), function(i) {
      included <- term_indices[, i] > 1
      tibble(
        record_type = "factor", effect = factor_names[i],
        main_eta_squared = sum(eta[included & term_order == 1]),
        shapley_eta_squared = sum(eta[included] / term_order[included])
      )
    })
    stopifnot(abs(sum(factor_rows$shapley_eta_squared) - 1) < 1e-12)
    results <- factor_rows
    if (n_levels == 4) {
      # For Shapley, the ETR contrasts share the interaction credit of the
      # same original factor. They do not count as three independent switches.
      level_totals <- vapply(seq_len(n_levels), function(i) {
        mean(rowSums(window_y[design_rows$level_index == i, , drop = FALSE]))
      }, numeric(1))
      contrasts <- map_dfr(seq_len(3), function(i) {
        included <- term_indices[, 1] == i + 1L
        tibble(
          record_type = "etr_contrast", effect = contrast_labels[i],
          orthogonal_weights = weights[i],
          main_eta_squared = sum(eta[included & term_order == 1]),
          shapley_eta_squared = sum(eta[included] / term_order[included]),
          adjacent_from = level_order[i], adjacent_to = level_order[i + 1L],
          literal_adjacent_change_usd_bn = (level_totals[i + 1L] - level_totals[i]) / 1e9
        )
      })
      stopifnot(
        abs(sum(contrasts$main_eta_squared) - factor_rows$main_eta_squared[1]) < 1e-12,
        abs(sum(contrasts$shapley_eta_squared) - factor_rows$shapley_eta_squared[1]) < 1e-12
      )
      results <- bind_rows(results, contrasts)
    }
    cumulative <- rowSums(window_y) / 1e9
    results |>
      mutate(
        design = design_name, window = window, n_scenarios = nrow(design_rows),
        country_years = ncol(window_y), level_order = paste(level_order, collapse = " | "),
        interaction_eta_squared = sum(eta[term_order > 1]),
        min_eu27_revenue_usd_bn = min(cumulative), max_eu27_revenue_usd_bn = max(cumulative),
        min_level = design_rows$level[which.min(cumulative)],
        max_level = design_rows$level[which.max(cumulative)],
        min_other_switches = paste(unlist(design_rows[which.min(cumulative), binary_factors]), collapse = ""),
        max_other_switches = paste(unlist(design_rows[which.max(cumulative), binary_factors]), collapse = ""),
        max_global_conservation_gap_usd = validation$max_global_conservation_gap_usd,
        max_country_channel_gap_usd = validation$max_country_channel_gap_usd,
        .before = 1
      )
  })
}

run_ladder_diagnostics <- function() {
  stage1 <- ladder_read("stage1_bilateral_panel")
  host_stage1 <- ladder_read("stage1_affiliate_year")
  ladder <- ladder_build_measurements(stage1, host_stage1,
    ladder_read("base_panel_t4_bilateral_bracket_shares"), rank_consistent = TRUE)
  levels <- c(LADDER_LEVELS, LADDER_BSPI)
  measurements <- ladder$measurements
  stopifnot(nrow(measurements) == nrow(stage1) * length(levels))
  for (i in 4:5) {
    prefix <- if (i == 4) "ladder_l4_anchored_" else "ladder_l4_strict_"
    check <- filter(measurements, level == levels[i]) |>
      inner_join(select(stage1, all_of(LADDER_KEYS), starts_with(prefix)),
        by = LADDER_KEYS, relationship = "one-to-one")
    stopifnot(nrow(check) == nrow(stage1),
      isTRUE(all.equal(check$share, check[[paste0(prefix, "low_share")]])),
      isTRUE(all.equal(check$gap, check[[paste0(prefix, "topup_rate")]])))
  }
  stage2 <- ladder_read("stage2_bilateral_panel") |>
    select(all_of(LADDER_KEYS), rate_scenario, affiliate_is_eu27, analysis_profit_positive,
      stage2_phi, stage2_topup_tax_average, stage2_topup_tax_distributional)
  post_sbie <- set_names(map(levels, function(level_name) {
    ladder_apply_sbie(filter(measurements, level == level_name), stage2)
  }), levels)
  for (i in c(1, 3)) {
    baseline_column <- c("stage2_topup_tax_average", NA, "stage2_topup_tax_distributional")[i]
    stopifnot(max(abs(post_sbie[[i]]$stage2_tax - coalesce(post_sbie[[i]][[baseline_column]], 0))) < 1e-3)
  }
  stage_summary <- ladder_stage_summary(measurements,
    imap_dfr(post_sbie, ~ mutate(.x, level = .y)))

  message("Allocating direct top-up across the ladder")
  factorial <- stage5_source_inputs()
  sectors <- ladder_read("stage2_sectoral_panel")
  weights <- list(
    parent_year_weights = ladder_read("stage4_5_utpr_parent_year_weights"),
    fallback_weights = ladder_read("stage4_5_utpr_fallback_weights")
  )
  beta <- ladder_read("stage3_model_coefficients") |>
    filter(model_spec == "linear", term == "tau", inference == "parent_affiliate_clustered") |>
    pull(estimate)
  stopifnot(length(beta) == 1, is.finite(beta))
  allocations <- set_names(map(levels, function(level_name) {
    message("  ", level_name)
    panel <- switch(level_name,
      L1_Host_Average = filter(factorial, x1_etr == 0),
      L3_Host_Pooled_Distributional = filter(factorial, x1_etr == 1),
      ladder_rebuild_scenarios(filter(measurements, level == level_name),
        post_sbie[[level_name]], factorial, host_stage1, sectors, beta)
    )
    ladder_allocate(panel, weights)
  }), levels)

  archived <- ladder_read("stage4_5_revenue_country_year") |>
    select(scenario_id, country, year, archived_revenue = revenue)
  baseline_check <- bind_rows(allocations[[1]]$revenue, allocations[[3]]$revenue) |>
    inner_join(archived, by = c("scenario_id", "country", "year"), relationship = "one-to-one")
  stopifnot(nrow(baseline_check) == nrow(archived),
    max(abs(baseline_check$revenue - baseline_check$archived_revenue)) < 1e-3)

  collector_revenues <- imap_dfr(allocations, ~ mutate(.x$revenue, level = .y))
  channels <- imap_dfr(allocations, ~ mutate(.x$channels, level = .y))
  preferred_source <- imap_dfr(allocations, ~ mutate(.x$preferred_source, level = .y))
  preferred_revenue <- collector_revenues |>
    filter(x2_substance == 0, x3_rates == 0, x5_behaviour == 1)
  parent_breakdown <- ladder_parent_breakdown(measurements, preferred_source, ladder$cells)
  sbs <- ladder_sbs_summary(preferred_source, preferred_revenue)
  backtest <- ladder_budget_backtest(collector_revenues, channels)

  message("Checking Stage 4.6 inputs and decomposing the factorial designs")
  binary_designs <- list(
    "L1_vs_L3" = c(1, 3), "L1_vs_L4_anchored" = c(1, 4),
    "L1_vs_L4_strict" = c(1, 5), "L2_vs_L4_anchored" = c(2, 4)
  )
  validation <- map(binary_designs, ~ ladder_binary_stage46(allocations[[.x[1]]], allocations[[.x[2]]]))
  anova <- imap_dfr(binary_designs, function(indices, name) {
    ladder_anova(collector_revenues, levels[indices], name, validation[[name]])
  })
  for (indices in list(c(1, 2, 4, 3), c(1, 2, 5, 3))) {
    selected <- allocations[indices]
    checks <- map_dfr(seq_along(indices)[-1], ~ ladder_binary_stage46(selected[[1]], selected[[.x]]))
    joint_checks <- summarise(checks, across(everything(), max))
    name <- if (4 %in% indices) "four_levels_anchored" else "four_levels_strict"
    anova <- bind_rows(anova, ladder_anova(collector_revenues, levels[indices], name, joint_checks))
  }

  ladder_write(stage_summary, "ladder_stage1_stage2_summary")
  ladder_write(parent_breakdown, "nld_lux_irl_parent_breakdown")
  ladder_write(sbs, "ladder_sbs_exposure")
  ladder_write(backtest, "ladder_budget_backtest")
  ladder_write(anova, "ladder_anova_decomposition")
}

# Rank-bounded Beta validation

STEP10_RAW_QUANTILES <- paste0("q", c(5, 25, 50, 75, 95), "_raw")
STEP10_MODELS <- STAGE1_BETA_MODELS
STEP10_ABLATION <- "M1_StatCap_Only"
STEP10_OMEGAS <- STAGE1_BETA_BLEND_WEIGHTS

step10_write <- function(data, stem) {
  write_csv(data, file.path(DIAGNOSTICS_DIR, paste0("step10_", stem, ".csv")))
}

step10_fit_rows <- function(data, qcols, key, models, blends = FALSE) {
  q <- as.matrix(data[qcols])
  map_dfr(seq_len(nrow(data)), function(i) {
    bind_cols(data[rep(i, length(models) + if (blends) length(STEP10_OMEGAS) else 0L), key],
      stage1_fit_cell(q[i, ], data$target_mean[i], data$affiliate_etr_cap_stage1[i], models, blends))
  })
}

step10_cross_validation <- function(host_cap) {
  paths <- c(S1_unmatched = "affiliate_year", S2_parent_restricted = "affiliate_year_parent_restricted",
    S3_exact_bilateral = "bilateral_matched")
  samples <- imap_dfr(paths, function(suffix, sample) {
    data <- read_csv(file.path(DIAGNOSTICS_DIR, paste0("step3_stage1_crossval_", suffix, ".csv")),
      show_col_types = FALSE)
    if (!"parent" %in% names(data)) data$parent <- NA_character_
    if (!"mean_etr" %in% names(data)) data$mean_etr <- data$avg_etr_stage1
    data |>
      transmute(sample, parent, affiliate, year, target_mean = mean_etr,
        across(all_of(STEP10_RAW_QUANTILES)), direct_low_share, direct_liability_rate,
        archive_low_share = percentile_low_share_uncapped,
        archive_liability_rate = percentile_liability_rate_uncapped)
  }) |>
    left_join(host_cap, by = c("affiliate", "year"), relationship = "many-to-one") |>
    mutate(sample_row = row_number())
  stopifnot(identical(as.integer(table(samples$sample)), c(361L, 70L, 81L)))
  fitted <- step10_fit_rows(samples, STEP10_RAW_QUANTILES, "sample_row",
    c(STEP10_MODELS, STEP10_ABLATION), blends = TRUE) |>
    inner_join(select(samples, -target_mean, -affiliate_etr_cap_stage1), by = "sample_row",
      relationship = "many-to-one")
  baseline <- filter(fitted, model == STEP10_MODELS[1])
  stopifnot(max(abs(baseline$share - baseline$archive_low_share)) < 1e-9,
    max(abs(baseline$liability_rate - baseline$archive_liability_rate)) < 1e-9,
    !any(fitted$rank_violation[fitted$model == STEP10_MODELS[3]]))
  audit <- fitted |>
    rename(low_share = share) |>
    pivot_longer(c(low_share, liability_rate), names_to = "outcome", values_to = "predicted") |>
    mutate(observed = if_else(outcome == "low_share", direct_low_share, direct_liability_rate),
      error = predicted - observed) |>
    group_by(sample, model, omega, outcome) |>
    group_modify(function(data, key) {
      calibration <- summary(lm(observed ~ predicted + factor(year), data = data))
      tibble(n = nrow(data), rank_violations = sum(data$rank_violation),
        rank_violation_pct = 100 * mean(data$rank_violation),
        rank_projection_n = sum(data$rank_projection),
        table4_share_outside_rank_pct = 100 * mean(stage1_rank_violation(
          data$direct_low_share, data$rank_lower, data$rank_upper)),
        p95_above_cap_n = sum(data$raw_p95_above_cap),
        p95_excluded_n = sum(data$p95_excluded),
        mean_above_cap_n = sum(data$target_mean > data$cap + 1e-8),
        cap_changes_rank_n = sum(data$rank_lower != data$capped_rank_lower |
          data$rank_upper != data$capped_rank_upper),
        u_shaped_n = sum(pmax(data$alpha, data$beta) < 1 - 1e-10, na.rm = TRUE),
        median_bias = median(data$error), mae = mean(abs(data$error)),
        rmse = sqrt(mean(data$error^2)), p90_absolute_error = unname(quantile(abs(data$error), 0.9)),
        spearman_rho = cor(data$predicted, data$observed, method = "spearman"),
        calibration_slope = unname(coef(calibration)["predicted", "Estimate"]),
        calibration_r_squared = calibration$r.squared
      )
    }) |>
    ungroup() |>
    mutate(record_type = "sample_metrics")
  bind_rows(audit, mutate(fitted, record_type = "cell_fit")) |>
    relocate(record_type, sample, model, omega)
}

step10_bilateral_inputs <- function(cells, host_cap) {
  inputs <- cells |>
    filter(!is.na(percentile_source), analysis_profit_positive > 0) |>
    left_join(host_cap, by = c("affiliate", "year"), relationship = "many-to-one") |>
    mutate(target_mean = etr_panelai_stage1)
  q <- as.matrix(inputs[LADDER_QUANTILES])
  fallback <- inputs$percentile_source == "panel_t_non_eu"
  q[fallback, ] <- as.matrix(inputs[fallback, paste0("etr_p", c(5, 25, 50, 75, 95))])
  colnames(q) <- STEP10_RAW_QUANTILES
  bind_cols(select(inputs, all_of(LADDER_KEYS), percentile_source,
    affiliate_etr_cap_stage1, target_mean), as_tibble(q))
}

step10_update_measurements <- function(ladder, host_fits, bilateral_fits, estimator) {
  pool <- host_fits |>
    transmute(affiliate, year, pool_share = share, pool_gap = gap,
      host_year_precision = precision, pool_rank_violation = rank_violation)
  fits <- bilateral_fits |>
    transmute(parent, affiliate, year, direct_fit_share = share, direct_fit_gap = gap,
      fitted_precision = precision, direct_fit_rank_violation = rank_violation)
  pair_precision <- fits |>
    filter(is.finite(fitted_precision)) |>
    summarise(pair_precision = median(fitted_precision), .by = c(parent, affiliate))
  host_median <- pool |>
    filter(is.finite(host_year_precision)) |>
    summarise(host_median_precision = median(host_year_precision), .by = affiliate)
  cells <- ladder$cells |>
    select(all_of(LADDER_KEYS), t4_available, direct_low_share, direct_topup_rate,
      etr_panelai_stage1, percentile_source, l2_share, l2_gap, mean_available) |>
    left_join(fits, by = LADDER_KEYS, relationship = "one-to-one") |>
    left_join(pair_precision, by = c("parent", "affiliate"), relationship = "many-to-one") |>
    left_join(pool, by = c("affiliate", "year"), relationship = "many-to-one") |>
    left_join(host_median, by = "affiliate", relationship = "many-to-one") |>
    mutate(transport_precision = coalesce(pair_precision, host_year_precision, host_median_precision))
  if (estimator == STEP10_MODELS[2]) {
    cells <- cells |>
      mutate(transport_precision = pmax(transport_precision,
        1 / pmax(etr_panelai_stage1, 1 - etr_panelai_stage1)))
  }
  cells <- bind_cols(cells, ladder_beta_metrics(cells$etr_panelai_stage1, cells$transport_precision))
  baseline <- filter(ladder$measurements, level %in% LADDER_LEVELS)
  baseline |>
    left_join(cells, by = LADDER_KEYS, relationship = "many-to-one") |>
    mutate(
      l3_refit = level == LADDER_LEVELS[3] & source_tier == "percentile_fit",
      l4_anchored = level == LADDER_LEVELS[4],
      l4_strict = level == LADDER_LEVELS[5],
      share = case_when(
        l3_refit ~ coalesce(pool_share, share),
        l4_anchored ~ coalesce(direct_low_share, direct_fit_share, beta_share, l2_share),
        l4_strict ~ coalesce(direct_low_share, direct_fit_share, l2_share),
        TRUE ~ share
      ),
      gap = case_when(
        l3_refit ~ coalesce(pool_gap, gap),
        l4_anchored ~ coalesce(direct_topup_rate, direct_fit_gap, beta_gap, l2_gap),
        l4_strict ~ coalesce(direct_topup_rate, direct_fit_gap, l2_gap),
        TRUE ~ gap
      ),
      source_tier = case_when(
        !(l4_anchored | l4_strict) ~ source_tier,
        t4_available ~ "exact_table_iv",
        !is.na(direct_fit_share) ~ paste0("exact_table_i_", percentile_source),
        l4_anchored & !is.na(beta_share) & etr_panelai_stage1 %in% c(0, 1) ~ "bilateral_boundary_mean",
        l4_anchored & !is.na(beta_share) & !is.na(pair_precision) ~ "pair_precision",
        l4_anchored & !is.na(beta_share) & !is.na(host_year_precision) ~ "host_year_precision",
        l4_anchored & !is.na(beta_share) & !is.na(host_median_precision) ~ "host_median_precision",
        mean_available ~ "bilateral_average",
        TRUE ~ "unmeasured"
      ),
      percentile_fit_rank_violation = case_when(
        l3_refit ~ coalesce(pool_rank_violation, FALSE),
        startsWith(source_tier, "exact_table_i_") ~ coalesce(direct_fit_rank_violation, FALSE),
        TRUE ~ FALSE
      ),
      measured = is.finite(share) & is.finite(gap),
      low_profit = if_else(measured, analysis_profit_positive * share, 0),
      stage1_tax = if_else(measured, low_profit * gap, 0)
    ) |>
    select(all_of(names(baseline)), transport_precision)
}

step10_variant <- function(estimator, measurements, stage2, factorial, host_stage1, sectors,
                           weights, beta, controls = NULL) {
  levels <- LADDER_LEVELS
  post_sbie <- set_names(map(levels, function(level_name) {
    ladder_apply_sbie(filter(measurements, level == level_name), stage2)
  }), levels)
  allocations <- set_names(map(levels, function(level_name) {
    if (!is.null(controls) && level_name %in% levels[1:2]) return(controls[[level_name]])
    if (level_name == levels[1]) {
      panel <- filter(factorial, x1_etr == 0)
    } else {
      panel <- ladder_rebuild_scenarios(filter(measurements, level == level_name),
        post_sbie[[level_name]], factorial, host_stage1, sectors, beta)
    }
    ladder_allocate(panel, weights)
  }), levels)
  list(
    allocations = allocations, measurements = measurements,
    stage = ladder_stage_summary(measurements, imap_dfr(post_sbie, ~ mutate(.x, level = .y))),
    revenues = imap_dfr(allocations, ~ mutate(.x$revenue, level = .y)),
    channels = imap_dfr(allocations, ~ mutate(.x$channels, level = .y)),
    sources = imap_dfr(allocations, ~ mutate(.x$preferred_source, level = .y))
  )
}

step10_focal_cells <- function(variants, ladder, host_cap, fits) {
  pairs <- tribble(
    ~parent, ~affiliate,
    "DEU", "DEU", "FRA", "FRA", "NLD", "NLD", "GBR", "NLD",
    "DEU", "NLD", "LUX", "LUX", "IRL", "IRL", "ITA", "ITA"
  )
  raw <- crossing(pairs, year = PERCENTILE_YEARS) |>
    left_join(
      ladder$cells |>
        transmute(parent, affiliate, year, analysis_profit_positive, etr_panelai_raw,
          etr_panelai_stage1, has_panelai_percentiles,
          baseline_transport_precision = selected_precision, across(all_of(LADDER_QUANTILES))),
      by = LADDER_KEYS, relationship = "one-to-one"
    ) |>
    left_join(host_cap, by = c("affiliate", "year"), relationship = "many-to-one")
  q <- as.matrix(raw[LADDER_QUANTILES])
  caps <- map(seq_len(nrow(raw)), ~ stage1_condition_percentile_knots(q[.x, ], raw$affiliate_etr_cap_stage1[.x]))
  capped <- as_tibble(do.call(rbind, caps), .name_repair = "minimal")
  names(capped) <- paste0("capped_", LADDER_QUANTILES)
  ranks <- t(apply(q, 1, function(x) {
    if (all(is.na(x))) return(c(lower = NA_real_, upper = NA_real_, interpolated = NA_real_))
    stage1_rank(stage1_condition_percentile_knots(x, 1))
  }))
  raw <- bind_cols(raw, capped, tibble(observed_rank_lower = ranks[, "lower"],
    observed_rank_upper = ranks[, "upper"]))
  imap_dfr(variants, function(variant, estimator) {
    measurements <- variant$measurements |>
      filter(level %in% LADDER_LEVELS[3:5]) |>
      select(any_of(c(LADDER_KEYS, "level", "share", "gap", "source_tier", "transport_precision")))
    qdmtt <- variant$sources |>
      filter(x4_sbs == 1, level %in% LADDER_LEVELS[3:5]) |>
      transmute(across(all_of(LADDER_KEYS)), level,
        qdmtt_eur_bn = stage4_qdmtt_liability / 1e9 / LADDER_EUR_USD)
    direct <- fits |>
      filter(model == estimator) |>
      transmute(parent, affiliate, year, fit_precision = precision, fit_alpha = alpha,
        fit_beta = beta, fit_share = share, fit_gap = gap, fit_rank_projection = rank_projection,
        fit_rank_violation = rank_violation, p95_excluded)
    crossing(raw, level = LADDER_LEVELS[3:5]) |>
      left_join(measurements, by = c(LADDER_KEYS, "level"), relationship = "one-to-one") |>
      left_join(qdmtt, by = c(LADDER_KEYS, "level"), relationship = "one-to-one") |>
      left_join(direct, by = LADDER_KEYS, relationship = "many-to-one") |>
      mutate(estimator = estimator,
        rank_violation_of_level = stage1_rank_violation(share, observed_rank_lower, observed_rank_upper),
        .before = 1)
  }) |>
    arrange(affiliate, parent, year, level, estimator)
}

step10_revenue_summary <- function(variant) {
  preferred <- filter(variant$revenues, x2_substance == 0, x3_rates == 0, x5_behaviour == 1)
  global <- imap_dfr(variant$allocations, function(allocation, level_name) {
    allocation$conservation |>
      filter(x2_substance == 0, x3_rates == 0, x5_behaviour == 1) |>
      transmute(level = level_name, country = "Global", year, x4_sbs, revenue = allocated_topup)
  }) |>
    ladder_windows() |>
    summarise(global_collector_usd = sum(revenue), .by = c(level, window, x4_sbs)) |>
    mutate(regime = if_else(x4_sbs == 1, "sbs", "universal")) |>
    select(-x4_sbs) |>
    pivot_wider(names_from = regime, names_prefix = "global_collector_usd_", values_from = global_collector_usd)
  waterfall <- ladder_sbs_summary(variant$sources, preferred) |>
    filter(scope %in% c("EU27", "Global")) |>
    left_join(global, by = c("level", "window"), relationship = "many-to-one") |>
    mutate(
      direct_collector_usd_universal = if_else(scope == "Global", global_collector_usd_universal,
        direct_collector_usd_universal),
      direct_collector_usd_sbs = if_else(scope == "Global", global_collector_usd_sbs,
        direct_collector_usd_sbs),
      collector_reduction_usd = direct_collector_usd_universal - direct_collector_usd_sbs,
      collector_reduction_share = safe_divide(collector_reduction_usd, direct_collector_usd_universal)
    ) |>
    select(-starts_with("global_collector"))
  variant$stage |>
    left_join(waterfall, by = c("level", "scope", "window", "years_in_window"),
      relationship = "many-to-one") |>
    mutate(across(any_of(setdiff(names(waterfall), names(variant$stage))),
      ~ if_else(record_type == "summary", .x, NA_real_)))
}

step10_budget_summary <- function(variant) {
  qdmtt <- variant$channels |>
    filter(channel == "QDMTT", country %in% LADDER_BUDGET_COUNTRIES) |>
    summarise(qdmtt_usd = sum(revenue), .by = c(level, country, year, scenario_id))
  simulation <- variant$revenues |>
    filter(x2_substance == 0, x3_rates == 0, x5_behaviour == 1,
      country %in% LADDER_BUDGET_COUNTRIES) |>
    left_join(qdmtt, by = c("level", "country", "year", "scenario_id"), relationship = "one-to-one") |>
    ladder_windows() |>
    summarise(
      qdmtt_eur_bn = sum(qdmtt_usd, na.rm = TRUE) / LADDER_EUR_USD / 1e9,
      collector_eur_bn = sum(revenue) / LADDER_EUR_USD / 1e9,
      .by = c(level, country, window, years_in_window, x4_sbs)
    ) |>
    mutate(
      record_type = "simulation",
      regime = if_else(x4_sbs == 1, "sbs", "universal"),
      annual_qdmtt_eur_bn = qdmtt_eur_bn / years_in_window,
      annual_collector_eur_bn = collector_eur_bn / years_in_window
    )
  bind_rows(simulation,
    mutate(ladder_budget_backtest(variant$revenues, variant$channels), record_type = "budget_backtest")) |>
    relocate(record_type, level, country, window)
}

step10_anova <- function(variant) {
  allocations <- variant$allocations
  designs <- list(
    L1_vs_L3 = c(1, 3), L1_vs_L4_anchored = c(1, 4),
    L1_vs_L4_strict = c(1, 5), L2_vs_L4_anchored = c(2, 4),
    four_levels_anchored = c(1, 2, 4, 3), four_levels_strict = c(1, 2, 5, 3)
  )
  imap_dfr(designs, function(indices, design) {
    checks <- map_dfr(indices[-1], ~ ladder_binary_stage46(allocations[[indices[1]]], allocations[[.x]]))
    ladder_anova(variant$revenues, LADDER_LEVELS[indices], design,
      summarise(checks, across(everything(), max)))
  })
}

run_rank_beta_diagnostics <- function() {
  host <- ladder_read("stage1_affiliate_year")
  host_cap <- select(host, affiliate, year, affiliate_etr_cap_stage1)
  message("Replaying the three archived Table I versus Table IV validation samples")
  audit <- step10_cross_validation(host_cap)

  stage1 <- ladder_read("stage1_bilateral_panel")
  # Replay the uncapped estimator on the current data and policy spine.
  # The archived production scenarios now use capped host percentiles.
  uncapped_host <- host |>
    mutate(
      percentile_beta_precision = percentile_beta_precision_uncapped,
      stage1_distributional_low_share = if_else(stage1_distributional_source == "percentile_fit",
        percentile_low_share_uncapped, stage1_distributional_low_share),
      stage1_distributional_topup_rate = if_else(stage1_distributional_source == "percentile_fit",
        percentile_topup_rate_uncapped, stage1_distributional_topup_rate)
    )
  uncapped_stage1 <- stage1 |>
    select(-stage1_distributional_low_share, -stage1_distributional_topup_rate) |>
    left_join(select(uncapped_host, affiliate, year, stage1_distributional_low_share,
      stage1_distributional_topup_rate), by = c("affiliate", "year"), relationship = "many-to-one")
  ladder <- ladder_build_measurements(uncapped_stage1, uncapped_host,
    ladder_read("base_panel_t4_bilateral_bracket_shares"))
  bilateral_inputs <- step10_bilateral_inputs(ladder$cells, host_cap)
  host_inputs <- host |>
    filter(year %in% PERCENTILE_YEARS, is.finite(avg_etr_stage1),
      if_all(all_of(STEP10_RAW_QUANTILES), is.finite)) |>
    mutate(target_mean = avg_etr_stage1)
  message("Fitting capped and rank-bounded Beta models to pooled and bilateral percentiles")
  host_fits <- step10_fit_rows(host_inputs, STEP10_RAW_QUANTILES, c("affiliate", "year"), STEP10_MODELS[2:3])
  bilateral_fits <- step10_fit_rows(bilateral_inputs, STEP10_RAW_QUANTILES, LADDER_KEYS, STEP10_MODELS)
  stopifnot(!any(host_fits$rank_violation[host_fits$model == STEP10_MODELS[3]]),
    !any(bilateral_fits$rank_violation[bilateral_fits$model == STEP10_MODELS[3]]))

  stage2 <- ladder_read("stage2_bilateral_panel") |>
    select(all_of(LADDER_KEYS), rate_scenario, affiliate_is_eu27, analysis_profit_positive,
      stage2_phi, stage2_topup_tax_average)
  sectors <- ladder_read("stage2_sectoral_panel")
  factorial <- stage5_source_inputs()
  weights <- list(
    parent_year_weights = ladder_read("stage4_5_utpr_parent_year_weights"),
    fallback_weights = ladder_read("stage4_5_utpr_fallback_weights")
  )
  beta <- ladder_read("stage3_model_coefficients") |>
    filter(model_spec == "linear", term == "tau", inference == "parent_affiliate_clustered") |>
    pull(estimate)
  stopifnot(length(beta) == 1L, is.finite(beta))
  variants <- set_names(vector("list", length(STEP10_MODELS)), STEP10_MODELS)
  for (estimator in STEP10_MODELS) {
    message("Re-running SBIE, behaviour and allocation for ", estimator)
    baseline <- estimator == STEP10_MODELS[1]
    measurements <- if (baseline) {
      filter(ladder$measurements, level %in% LADDER_LEVELS)
    } else {
      step10_update_measurements(ladder, filter(host_fits, model == estimator),
        filter(bilateral_fits, model == estimator), estimator)
    }
    controls <- if (baseline) NULL else variants[[1]]$allocations
    variants[[estimator]] <- step10_variant(estimator, measurements, stage2, factorial,
      host, sectors, weights, beta, controls)
  }
  archived <- ladder_read("stage4_5_revenue_country_year") |>
    filter(x1_etr == 0) |>
    select(scenario_id, country, year, archived = revenue)
  replay <- variants[[1]]$revenues |>
    filter(level == LADDER_LEVELS[1]) |>
    inner_join(archived, by = c("scenario_id", "country", "year"), relationship = "one-to-one")
  stopifnot(nrow(replay) == nrow(archived), max(abs(replay$revenue - replay$archived)) < 1e-3)

  focal <- step10_focal_cells(variants, ladder, host_cap, bilateral_fits)
  revenue <- imap_dfr(variants, ~ mutate(step10_revenue_summary(.x), estimator = .y, .before = 1))
  budget <- imap_dfr(variants, ~ mutate(step10_budget_summary(.x), estimator = .y, .before = 1))
  anova <- imap_dfr(variants, ~ mutate(step10_anova(.x), estimator = .y, .before = 1))
  step10_write(audit, "estimator_rank_consistency_audit")
  step10_write(focal, "focal_cells_comparison")
  step10_write(revenue, "ladder_revenue_and_sbs_summary")
  step10_write(budget, "nld_deu_fra_irl_lux_ladder")
  step10_write(anova, "ladder_anova_decomposition")
}

# CbCR blending, size incidence, interquartile skewness and activity

run_cbcr_table_extensions <- function() {
  key <- c("parent", "affiliate", "year")
  aggregate_codes <- c("A", "A_O", "E", "E_O", "F", "F_O", "S", "S_O",
                       "W", "W_O", "WXD", "STLS")
  hubs <- c("IRL", "NLD", "LUX", "DEU", "FRA", "BEL", "CYP", "HUN")
  activity <- c("act_holding", "act_ip", "act_igf", "act_rd", "act_man",
                "act_sales", "act_ser", "act_admin", "act_dor", "act_other",
                "act_fin", "act_ins", "act_pur")
  floor_rate <- GMT_RATE
  sum_obs <- function(x) if (any(is.finite(x))) sum(x[is.finite(x)]) else NA_real_
  median_obs <- function(x) if (any(is.finite(x))) median(x[is.finite(x)]) else NA_real_
  ratio <- function(x, y) x * ifelse(is.finite(y) & y > 0, 1 / y, NA_real_)
  clip <- function(x, lo = 0, hi = 1) pmax(lo, pmin(x, hi))
  pct_gap <- function(tax, profit) floor_rate - clip(ratio(tax, profit), 0, floor_rate)
  row_topup <- function(tax, profit) ifelse(profit == 0, 0, profit * pct_gap(tax, profit))
  country_rows <- function(x) filter(x, !parent %in% aggregate_codes,
                                     !affiliate %in% aggregate_codes)
  load_panel <- function(name) readRDS(file.path(PROCESSED_DIR, paste0(name, ".rds")))
  assert_keys <- function(x, keys) {
    stopifnot(!anyNA(x[keys]), !anyDuplicated(x[keys]))
  }
  scope_panel <- function(x, rules) {
    imap_dfr(rules, function(f, label) mutate(x[f(x), , drop = FALSE], scope = rep(label, sum(f(x)))))
  }
  host_rules <- c(list(Global = function(x) rep(TRUE, nrow(x)),
                       EU27 = function(x) x$affiliate %in% EU27_ISO3),
                  setNames(lapply(hubs, function(j) function(x) x$affiliate == j), hubs))
  blend_rules <- c(host_rules, list(USA_all_hosts = function(x) x$parent == "USA",
                                   USA_foreign = function(x) x$parent == "USA" &
                                   x$affiliate != "USA",
                                   USA_EU27 = function(x) x$parent == "USA" &
                                     x$affiliate %in% EU27_ISO3))
  time_panel <- function(x, pooled) bind_rows(
    mutate(x, window = as.character(year)),
    mutate(x, window = rep(pooled, nrow(x)))
  )
  signed_rank <- function(delta) {
    delta <- delta[is.finite(delta)]
    if (!length(delta) || all(delta == 0)) return(NA_real_)
    wilcox.test(delta, exact = FALSE)$p.value
  }

  t1 <- load_panel("cbcr_table1")
  t2 <- load_panel("cbcr_table2")
  t3 <- load_panel("cbcr_table3")
  t4 <- load_panel("cbcr_table4")
  base <- load_panel("base_panel")
  s1 <- load_panel("stage1_bilateral_panel")
  s2 <- load_panel("stage2_bilateral_panel")
  for (x in list(t1, t2, base, s1)) assert_keys(x, key)
  for (x in list(t3, t4)) assert_keys(x, c(key, "etr_bracket"))
  assert_keys(s2, c(key, "rate_scenario"))

  # 1. Tables III and IV: separate margins; no public group × jurisdiction cross-tab.
  # Use explicitly observed 0–15 and 15+ bins (15+ is a single bin in 2019–23).
  # Exclude negative-tax and negative-profit categories, and flag III's net loss bins.
  # Absent/suppressed brackets are never interpreted as zero.
  bracket_partition <- function(x) {
    x |>
      filter(year %in% MAIN_YEARS, etr_bracket %in% c("rate_0_15", "rate_15")) |>
      select(all_of(key), etr_bracket, profit, tax_accrued, subgroups_count) |>
      pivot_wider(names_from = etr_bracket,
                  values_from = c(profit, tax_accrued, subgroups_count)) |>
      transmute(across(all_of(key)),
        low = profit_rate_0_15, high = profit_rate_15, low_tax = tax_accrued_rate_0_15,
        subgroup_count = subgroups_count_rate_0_15 + subgroups_count_rate_15
      ) |>
      filter(is.finite(low), is.finite(high), low >= 0, high >= 0, low + high > 0) |>
      mutate(profit = low + high, share = low / profit,
             local_topup = row_topup(low_tax, low))
  }
  # An approximation to the worldwide group-bracket gap using the same reporter's
  # domestic + explicitly published all-foreign totals. Include separately reported
  # stateless records, as the OECD requests these outside domestic and foreign.
  group_gap <- t3 |>
    filter(year %in% MAIN_YEARS, etr_bracket == "rate_0_15",
           affiliate == parent | affiliate %in% c("WXD", "STLS")) |>
    summarise(
      domestic = any(parent == affiliate), foreign = any(affiliate == "WXD"),
      worldwide_low_profit = sum(profit), worldwide_low_tax = sum(tax_accrued),
      .by = c(parent, year)
    ) |>
    filter(domestic, foreign, is.finite(worldwide_low_profit), worldwide_low_profit > 0,
           is.finite(worldwide_low_tax)) |>
    mutate(worldwide_etr_raw = worldwide_low_tax / worldwide_low_profit,
           # Outside-range reported aggregate rates do not validate the bracket.
           worldwide_gap = if_else(between(worldwide_etr_raw, 0, floor_rate + 1e-8),
                                   pmax(0, floor_rate - worldwide_etr_raw), NA_real_)) |>
    select(-domestic, -foreign)

  g <- bracket_partition(t3) |> country_rows() |>
    left_join(group_gap, by = c("parent", "year"), relationship = "many-to-one") |>
    mutate(worldwide_topup = if_else(low == 0, 0, low * worldwide_gap))
  j <- bracket_partition(t4) |> country_rows()
  w <- s1 |> select(all_of(key), corrected_profit = analysis_profit_positive)
  g <- left_join(g, w, by = key, relationship = "one-to-one")
  j <- left_join(j, w, by = key, relationship = "one-to-one")
  matched <- inner_join(g, select(j, -corrected_profit), by = key,
                        suffix = c("_group", "_juris"), relationship = "one-to-one") |>
    filter(year >= 2019) |>
    mutate(
      denom_gap = abs(profit_group - profit_juris) / pmax(profit_group, profit_juris),
      counts_agree = is.finite(subgroup_count_group) & is.finite(subgroup_count_juris) &
        abs(subgroup_count_group - subgroup_count_juris) < 1e-6,
      close_denom = denom_gap <= 0.05,
      same_margin_totals = denom_gap <= 1e-6 & counts_agree
    )
  # Bounds are valid only under common positive-profit support. Matching a key
  # (or even its totals) does not establish common underlying subgroups.
  bounds <- function(x) {
    mutate(x, gap_share = share_juris - share_group,
           hidden_lb_share = pmax(0, gap_share),
           hidden_ub_share = pmin(share_juris, 1 - share_group),
           reverse_lb_share = pmax(0, -gap_share),
           reverse_ub_share = pmin(share_group, 1 - share_juris))
  }
  stopifnot(all(with(bounds(matched), hidden_lb_share <= hidden_ub_share + 1e-12 &
                                    reverse_lb_share <= reverse_ub_share + 1e-12)))
  blend_summary <- function(x, resolution, sample) {
    scoped <- scope_panel(time_panel(x, "2019–2023"), blend_rules)
    if (resolution == "affiliate_year") {
      scoped <- scoped |> summarise(
        n_bilateral = n(), n_parent_support = n_distinct(parent),
        reporters = paste(sort(unique(parent)), collapse = ";"),
        n_close_denom = sum(close_denom), n_same_margin_totals = sum(same_margin_totals),
        across(c(low_group, low_juris, profit_group, profit_juris, corrected_profit),
               sum_obs),
        across(c(local_topup_group, local_topup_juris, worldwide_topup),
               ~ if (all(is.finite(.x))) sum(.x) else NA_real_),
        .by = c(scope, window, affiliate, year)
      ) |> mutate(share_group = low_group / profit_group, share_juris = low_juris / profit_juris)
    } else {
      scoped <- scoped |> mutate(n_bilateral = 1L, n_parent_support = 1L, reporters = parent,
                                 n_close_denom = as.integer(close_denom),
                                 n_same_margin_totals = as.integer(same_margin_totals))
    }
    d <- scoped |> bounds() |> mutate(weight = if_else(corrected_profit > 0, corrected_profit, NA_real_))
    sm <- d |> summarise(
      observations = n(), matched_pair_years = sum(n_bilateral),
      host_years = n_distinct(affiliate, year),
      reporters = paste(sort(unique(unlist(strsplit(reporters, ";", fixed = TRUE)))), collapse = ";"),
      near_denominator_pair_years = sum(n_close_denom),
      equal_denominator_and_count_pair_years = sum(n_same_margin_totals),
      positive_weight_units = sum(is.finite(weight)),
      group_profit_usd = sum_obs(profit_group), juris_profit_usd = sum_obs(profit_juris),
      group_low_usd = sum_obs(low_group), juris_low_usd = sum_obs(low_juris),
      group_share_raw = ratio(group_low_usd, group_profit_usd),
      juris_share_raw = ratio(juris_low_usd, juris_profit_usd),
      common_weight_usd = sum_obs(weight),
      group_share_common = ratio(sum_obs(weight * share_group), common_weight_usd),
      juris_share_common = ratio(sum_obs(weight * share_juris), common_weight_usd),
      common_low_difference_usd = sum_obs(weight * gap_share),
      across(c(hidden_lb_share, hidden_ub_share, reverse_lb_share, reverse_ub_share),
             ~ sum_obs(weight * .x), .names = "{.col}_times_weight_usd"),
      liability_comparison_units = sum(is.finite(worldwide_topup) & is.finite(local_topup_juris)),
      liability_comparison_weight_usd = sum_obs(weight[is.finite(worldwide_topup) &
                                                      is.finite(local_topup_juris)]),
      group_worldwide_gap_topup_usd = sum_obs(worldwide_topup[is.finite(local_topup_juris)]),
      juris_topup_usd_on_group_gap_support = sum_obs(local_topup_juris[is.finite(worldwide_topup)]),
      group_worldwide_gap_topup_common_usd = sum_obs(
        (weight * worldwide_topup / profit_group)[is.finite(local_topup_juris)]),
      juris_topup_common_usd_on_group_gap_support = sum_obs(
        (weight * local_topup_juris / profit_juris)[is.finite(worldwide_topup)]),
      group_local_gap_proxy_usd = sum_obs(local_topup_group[is.finite(local_topup_juris)]),
      juris_topup_usd_on_group_local_gap_support = sum_obs(local_topup_juris[is.finite(local_topup_group)]),
      .by = c(scope, window)
    )
    # Explicitly include unsupported scopes (especially USA) as zero counts, NA amounts.
    sm <- expand_grid(scope = names(blend_rules), window = c(as.character(2019:2023), "2019–2023")) |>
      left_join(sm, by = c("scope", "window")) |>
      mutate(across(c(observations, matched_pair_years, host_years, near_denominator_pair_years,
                      equal_denominator_and_count_pair_years, positive_weight_units,
                      liability_comparison_units), ~ coalesce(.x, 0L)),
             record = "matched_summary", resolution = resolution, sample = sample)
    stopifnot(all(with(sm, abs(common_low_difference_usd -
      common_weight_usd * (juris_share_common - group_share_common)) <
      pmax(1e-3, common_weight_usd * 1e-12)), na.rm = TRUE))
    sm
  }

  standalone <- function(x, table_name, sample = "observed_partitions") {
    years <- if (table_name == "III") MAIN_YEARS else 2019:2023
    d <- bind_rows(time_panel(filter(x, year %in% 2019:2023), "2019–2023"),
                   mutate(filter(x, year < 2019, year %in% years), window = as.character(year)))
    sm <- scope_panel(d, blend_rules) |>
      summarise(observations = n(), host_years = n_distinct(affiliate, year),
        reporters = paste(sort(unique(parent)), collapse = ";"),
        denominator_usd = sum_obs(profit), low_usd = sum_obs(low), low_tax_usd = sum_obs(low_tax),
        low_share = ratio(low_usd, denominator_usd),
        local_gap_proxy_usd = sum_obs(local_topup), local_gap_cells = sum(is.finite(local_topup)),
        .by = c(scope, window))
    if (table_name == "III") {
      sm <- left_join(sm, scope_panel(d, blend_rules) |> summarise(
        worldwide_gap_proxy_usd = sum_obs(worldwide_topup),
        worldwide_gap_cells = sum(is.finite(worldwide_topup)), .by = c(scope, window)
      ), by = c("scope", "window"), relationship = "one-to-one")
    }
    expand_grid(scope = names(blend_rules), window = c(as.character(years), "2019–2023")) |>
      left_join(sm, by = c("scope", "window")) |>
      mutate(record = "standalone_summary", table = table_name, sample = sample,
             across(c(observations, host_years, local_gap_cells), ~ coalesce(.x, 0L)))
  }
  # Historical schemes straddle 15%. Bound the low share by assigning all or
  # none of the ambiguous bin to it, only when that reporter's full partition is
  # published and each bin has non-negative net profit.
  legacy_schemes <- list(
    legacy_four = c("rate_0_10", "rate_10_20", "rate_20_30", "rate_30"),
    legacy_three = c("rate_0_10", "rate_10_20", "rate_20"),
    legacy_two_includes_negative_accrual = c("rate_10_accrued", "rate_10")
  )
  legacy_input <- t3 |> country_rows() |> filter(year %in% 2017:2018)
  legacy <- imap_dfr(legacy_schemes, function(bins, scheme) {
    regimes <- t3 |> filter(year %in% 2017:2018) |> summarise(
      supports_scheme = all(bins %in% etr_bracket) &&
        !any(setdiff(unique(unlist(legacy_schemes)), bins) %in% etr_bracket),
      .by = c(parent, year)
    ) |> filter(supports_scheme)
    legacy_input |> semi_join(regimes, by = c("parent", "year")) |>
      filter(etr_bracket %in% bins) |>
      summarise(observed_bins = n(), all_valid = all(is.finite(profit) & profit >= 0),
        known_low = sum(profit[etr_bracket == bins[1L]]),
        ambiguous = sum(profit[etr_bracket == bins[2L]]),
        denominator = sum(profit), .by = all_of(key)) |>
      filter(observed_bins == length(bins), all_valid, denominator > 0) |>
      mutate(scheme = rep(scheme, n()))
  })
  legacy_summary <- scope_panel(legacy, blend_rules) |> summarise(
    observations = n(), reporters = paste(sort(unique(parent)), collapse = ";"),
    denominator_usd = sum(denominator), low_usd_lower = sum(known_low),
    low_usd_upper = sum(known_low + ambiguous), low_share_lower = low_usd_lower / denominator_usd,
    low_share_upper = low_usd_upper / denominator_usd, .by = c(scope, year, scheme)
  ) |> mutate(record = "table3_legacy_15pct_bounds", table = "III", window = as.character(year))

  # The published 2020 Chile Table III bilateral values have a major scale
  # discontinuity versus Table I. Preserve the original and report exclusion
  # sensitivity without imposing an unverifiable exchange rate or rescaling.
  chile_audit <- g |> filter(parent == "CHL", year == 2020) |>
    left_join(t1 |> select(all_of(key), table1_net_profit = profit,
                          table1_positive_profit = profit_panelai),
              by = key, relationship = "one-to-one") |>
    mutate(record = "table3_chile_2020_scale_check", table = "III", window = as.character(year))
  blend <- bind_rows(
    map_dfr(c("bilateral", "affiliate_year"), function(res) bind_rows(
      blend_summary(matched, res, "matched_observed_partitions"),
      blend_summary(filter(matched, close_denom), res, "denominators_within_5pct"),
      blend_summary(filter(matched, same_margin_totals), res, "equal_denominator_and_count")
    )),
    standalone(g, "III"), standalone(j, "IV"),
    standalone(filter(g, !(parent == "CHL" & year == 2020)), "III", "excluding_Chile_2020"),
    legacy_summary, chile_audit,
    scope_panel(country_rows(filter(t3, year %in% MAIN_YEARS)), blend_rules) |>
      summarise(observations = n(), profit_observed = sum(is.finite(profit)),
                bracket_net_profit_usd = sum_obs(profit),
                bracket_positive_part_usd = sum_obs(pmax(profit, 0)),
                .by = c(scope, year, etr_bracket)) |>
      mutate(record = "table3_bracket_inventory", table = "III", window = as.character(year)),
    bounds(matched) |> mutate(record = "matched_cell", resolution = "bilateral",
                             window = as.character(year)),
    group_gap |> mutate(record = "worldwide_gap_input", table = "III",
                        window = as.character(year))
  )

  # Wage benchmark by host-year; do not impute missing wages or reported tax/inputs.
  wage <- base |> filter(is.finite(affiliate_wage_annual), affiliate_wage_annual > 0) |>
    distinct(affiliate, year, affiliate_wage_annual, affiliate_population)
  assert_keys(wage, c("affiliate", "year"))

  # 2. Tables VI and V: USD worldwide unrelated-party-revenue bands, not the
  # statutory EUR 750m consolidated revenue test. Net class-cell profit is signed.
  t6 <- load_panel("cbcr_table6")
  t5 <- load_panel("cbcr_table5")
  assert_keys(t6, c(key, "size_class"))
  assert_keys(t5, c("parent", "year"))
  fine <- c("size_less_2_5", "size_2_5_5", "size_5_10", "size_greater_10")
  coarse <- c("size_less_5", "size_greater_5")
  size_amounts <- c("cbcr_count", "subgroups_count", "entities_count", "employees",
                    "assets", "profit", "tax_accrued")
  stopifnot(all(t6$size_class %in% c(fine, coarse)))
  size_rules <- list(Global = function(x) rep(TRUE, nrow(x)),
                     EU27_hosts = function(x) x$affiliate %in% EU27_ISO3,
                     EU27_parents = function(x) x$parent %in% EU27_ISO3,
                     EU27_parents_EU27_hosts = function(x) x$parent %in% EU27_ISO3 &
                       x$affiliate %in% EU27_ISO3,
                     USA_parents = function(x) x$parent == "USA",
                     USA_parents_EU27_hosts = function(x) x$parent == "USA" &
                       x$affiliate %in% EU27_ISO3)
  size_raw <- country_rows(t6)
  size_cells <- size_raw |>
    summarise(
      n_fine = sum(size_class %in% fine), n_coarse = sum(size_class %in% coarse),
      n_low_fine = sum(size_class %in% fine[1:2]),
      n_high_fine = sum(size_class %in% fine[3:4]),
      low_coarse = any(size_class == coarse[1]),
      high_coarse = any(size_class == coarse[2]),
      .by = all_of(key)
    ) |>
    mutate(low_complete = low_coarse | n_low_fine == 2,
           high_complete = high_coarse | n_high_fine == 2)
  # The two halves can use different resolutions within a cell. Never add a
  # coarse band to its constituent fine bands.
  stopifnot(!any(with(size_cells, (low_coarse & n_low_fine > 0) |
                                    (high_coarse & n_high_fine > 0))))
  size_raw <- left_join(size_raw, size_cells, by = key, relationship = "many-to-one")
  size_full <- filter(size_raw, n_fine == 4 | n_coarse == 2)
  size_5 <- size_raw |> filter(low_complete, high_complete) |>
    mutate(size_class = if_else(size_class %in% c(fine[1:2], coarse[1]), coarse[1], coarse[2])) |>
    summarise(across(all_of(size_amounts), sum), .by = c(all_of(key), size_class))

  prepare_size <- function(x) {
    x |>
      left_join(wage, by = c("affiliate", "year"), relationship = "many-to-one") |>
      mutate(
        employee_outlier = !is.na(employees) & (employees < 0 |
          (!is.na(entities_count) & employees > entities_count * 100000) |
          (!is.na(affiliate_population) & employees > affiliate_population)),
        employees_screened = if_else(employee_outlier, NA_real_, employees),
        positive_cell_profit = pmax(profit, 0),
        payroll_proxy = employees_screened * affiliate_wage_annual,
        sbie_initial = 0.10 * payroll_proxy + 0.08 * if_else(assets >= 0, assets, NA_real_),
        sbie_long_run = 0.05 * (payroll_proxy + if_else(assets >= 0, assets, NA_real_)),
        cell_phi_initial = clip(ratio(sbie_initial, profit)),
        cell_phi_long_run = clip(ratio(sbie_long_run, profit)),
        topup = if_else(profit > 0, row_topup(tax_accrued, profit), NA_real_)
      )
  }
  size_summary <- function(x, sample) {
    x <- prepare_size(x)
    sm <- scope_panel(time_panel(x, "2022–2023"), size_rules) |>
      summarise(
        observations = n(), parent_years = n_distinct(parent, year),
        parents = n_distinct(parent), affiliates = n_distinct(affiliate),
        across(all_of(size_amounts), sum_obs, .names = "{.col}_total"),
        across(all_of(size_amounts), ~ sum(is.finite(.x)), .names = "{.col}_n"),
        domestic_cbcr_count = sum_obs(cbcr_count[parent == affiliate]),
        positive_cell_profit_usd = sum_obs(positive_cell_profit),
        tax_matched_net_profit_usd = sum_obs(profit[is.finite(tax_accrued)]),
        tax_matched_net_etr = ratio(sum_obs(tax_accrued[is.finite(profit)]), tax_matched_net_profit_usd),
        tax_matched_positive_profit_usd = sum_obs(profit[profit > 0 & is.finite(tax_accrued)]),
        positive_cell_etr = ratio(sum_obs(tax_accrued[profit > 0 & is.finite(profit)]),
                                  tax_matched_positive_profit_usd),
        profit_per_employee_usd = ratio(sum_obs(profit[is.finite(profit) & is.finite(employees_screened)]),
                                       sum_obs(employees_screened[is.finite(profit)])),
        positive_profit_per_employee_usd = ratio(
          sum_obs(profit[profit > 0 & is.finite(employees_screened)]),
          sum_obs(employees_screened[is.finite(profit) & profit > 0])),
        employees_screened_outliers = sum(employee_outlier),
        phi_support_profit_usd = sum_obs(profit[is.finite(cell_phi_initial)]),
        phi_initial = ratio(sum_obs(cell_phi_initial * profit), phi_support_profit_usd),
        phi_long_run = ratio(sum_obs(cell_phi_long_run * profit), phi_support_profit_usd),
        pre_sbie_topup_usd = sum_obs(topup),
        pre_sbie_topup_rate = ratio(pre_sbie_topup_usd, tax_matched_positive_profit_usd),
        post_sbie_support_profit_usd = sum_obs(profit[is.finite(topup) & is.finite(cell_phi_initial)]),
        pre_sbie_topup_usd_on_post_support = sum_obs(topup[is.finite(cell_phi_initial)]),
        post_sbie_initial_topup_usd = sum_obs(topup * (1 - cell_phi_initial)),
        post_sbie_long_run_topup_usd = sum_obs(topup * (1 - cell_phi_long_run)),
        post_sbie_initial_rate = ratio(post_sbie_initial_topup_usd, post_sbie_support_profit_usd),
        post_sbie_long_run_rate = ratio(post_sbie_long_run_topup_usd, post_sbie_support_profit_usd),
        .by = c(scope, window, size_class)
      ) |>
      mutate(
        across(c(cbcr_count_total, subgroups_count_total, entities_count_total,
                 employees_total, assets_total, positive_cell_profit_usd, domestic_cbcr_count,
                 pre_sbie_topup_usd, post_sbie_initial_topup_usd),
               ~ ratio(.x, sum_obs(.x)), .names = "{.col}_share"),
        .by = c(scope, window)
      )
    classes <- if (sample %in% c("complete_coarse", "harmonised_5bn")) coarse else fine
    share_check <- sm |> summarise(across(ends_with("_share"), sum_obs), .by = c(scope, window))
    share_values <- unlist(select(share_check, ends_with("_share")), use.names = FALSE)
    stopifnot(all(abs(share_values - 1) < 1e-10, na.rm = TRUE))
    stopifnot(all(with(sm, post_sbie_support_profit_usd <= phi_support_profit_usd &
      post_sbie_initial_topup_usd <= post_sbie_long_run_topup_usd + 1e-6 &
      post_sbie_long_run_topup_usd <= pre_sbie_topup_usd_on_post_support + 1e-6),
      na.rm = TRUE))
    expand_grid(scope = names(size_rules), window = c("2022", "2023", "2022–2023"),
                size_class = classes) |>
      left_join(sm, by = c("scope", "window", "size_class")) |>
      mutate(record = "size_summary", sample = sample, observations = coalesce(observations, 0L))
  }
  # Matched size-extreme test: aggregate within reporting parents before inference.
  # Use identical cells and a common support for ETR and both post-SBIE rates.
  size_extreme <- prepare_size(filter(size_full, n_fine == 4, size_class %in% fine[c(1, 4)])) |>
    filter(profit > 0, is.finite(topup), is.finite(cell_phi_initial)) |>
    group_by(across(all_of(key))) |> filter(n() == 2) |> ungroup()
  size_test_parent <- scope_panel(time_panel(size_extreme, "2022–2023"), size_rules) |>
    summarise(
      paired_cells = n(), positive_profit_usd = sum(profit),
      etr = sum(tax_accrued) / positive_profit_usd,
      phi = sum(profit * cell_phi_initial) / positive_profit_usd,
      post_sbie_rate = sum(topup * (1 - cell_phi_initial)) / positive_profit_usd,
      .by = c(scope, window, parent, size_class)
    ) |>
    pivot_longer(c(etr, phi, post_sbie_rate), names_to = "metric", values_to = "rate") |>
    pivot_wider(names_from = size_class, values_from = c(rate, positive_profit_usd, paired_cells)) |>
    mutate(large_minus_small = rate_size_greater_10 - rate_size_less_2_5)
  size_test <- size_test_parent |>
    summarise(
      parents = n(), paired_cells = sum(paired_cells_size_greater_10),
      median_large_minus_small = median_obs(large_minus_small),
      paired_parent_p = signed_rank(large_minus_small),
      .by = c(scope, window, metric)
    )
  size_out <- bind_rows(
    size_summary(filter(size_raw, size_class %in% fine), "observed_fine"),
    size_summary(filter(size_full, n_fine == 4), "complete_fine"),
    size_summary(filter(size_full, n_coarse == 2), "complete_coarse"),
    size_summary(size_5, "harmonised_5bn"),
    t6 |> summarise(observations = n(), parents = n_distinct(parent),
                     affiliates = n_distinct(affiliate), .by = c(year, size_class)) |>
      mutate(record = "size_raw_inventory", window = as.character(year)),
    t5 |> filter(year %in% MAIN_YEARS) |>
      mutate(record = "table5_worldwide_group_size_percentiles", window = as.character(year),
             p50_class = case_when(
               !is.finite(upr_p50) ~ NA_character_, upr_p50 < 2.5e9 ~ fine[1],
               upr_p50 < 5e9 ~ fine[2], upr_p50 <= 10e9 ~ fine[3], TRUE ~ fine[4]
             )),
    mutate(size_test_parent, record = "size_extreme_paired_parent"),
    mutate(size_test, record = "size_extreme_paired_test")
  )

  # 3. Table II's reported IQMs are separate univariate statistics. No ETR or
  # SBIE of an identified common middle group, nor a point estimate for the top
  # quartile, can be recovered from the ratios of these means.
  iq_vars <- c("profit", "tax_accrued", "assets", "employees", "subgroups_count")
  iq_names <- paste0(iq_vars, "_panelai")
  iq_select <- function(x, prefix) {
    x |> country_rows() |> filter(year %in% MAIN_YEARS) |>
      select(all_of(key), all_of(iq_names)) |>
      rename_with(~ paste0(prefix, "_", sub("_panelai$", "", .x)), all_of(iq_names))
  }
  iq_cells <- inner_join(iq_select(t1, "t1"), iq_select(t2, "t2"), by = key,
                         relationship = "one-to-one") |>
    left_join(wage, by = c("affiliate", "year"), relationship = "many-to-one") |>
    filter(t1_profit > 0, t2_profit > 0, t1_subgroups_count > 0) |>
    mutate(
      table2_statistic = if_else(year == 2017L, "ordinary_mean_vintage", "reported_IQM_vintage"),
      counts_match = !is.na(t2_subgroups_count) &
        abs(t2_subgroups_count - t1_subgroups_count) < 1e-6,
      all_etr = t1_tax_accrued / t1_profit,
      iqm_ratio_etr = t2_tax_accrued / t2_profit,
      all_phi = clip((0.10 * t1_employees * affiliate_wage_annual + 0.08 * t1_assets) / t1_profit),
      iqm_ratio_phi = clip((0.10 * t2_employees * affiliate_wage_annual + 0.08 * t2_assets) / t2_profit),
      profit_iqm_to_ordinary_mean = t2_profit * t1_subgroups_count / t1_profit,
      matches_mean_0_1pct = abs(profit_iqm_to_ordinary_mean - 1) <= 0.001,
      # Extrapolating the IQM to ALL subgroups does not estimate the outer tails.
      mean_scaled_shortfall = 1 - profit_iqm_to_ordinary_mean,
      core_half_proxy = if_else(year >= 2018 & counts_match & t1_subgroups_count >= 8,
                                0.5 * profit_iqm_to_ordinary_mean, NA_real_),
      # If exactly half of the observations are retained by trimming, the upper
      # quartile's share is at least half the core share and at least outer-core/2.
      # The bottom quartile is non-negative and cannot exceed half the core.
      half_core_order_feasible = is.finite(core_half_proxy) &
        core_half_proxy >= 0 & core_half_proxy <= 2 / 3,
      outer_both_tails_proxy = if_else(half_core_order_feasible, 1 - core_half_proxy, NA_real_),
      top_quartile_lb_conditional = pmax(0.5 * core_half_proxy, 0.5 * outer_both_tails_proxy,
                                        outer_both_tails_proxy - 0.5 * core_half_proxy),
      top_quartile_ub_conditional = outer_both_tails_proxy
    )
  # Exact half-count premise is most defensible where the subgroup count is a
  # multiple of four. This remains a sensitivity because published IQMs can
  # include ties at quartile thresholds or depart from the requested convention.
  stopifnot(all(iq_cells$top_quartile_lb_conditional <= iq_cells$top_quartile_ub_conditional + 1e-12,
                na.rm = TRUE))
  iq_summary <- function(x, sample) {
    d <- scope_panel(bind_rows(mutate(x, window = as.character(year)),
      mutate(filter(x, year >= 2018), window = "2018–2023")), host_rules)
    d |> summarise(
      observations = n(), parents = n_distinct(parent),
      counts_match_n = sum(counts_match), matches_mean_n = sum(matches_mean_0_1pct),
      reported_profit_usd = sum(t1_profit),
      etr_n = sum(is.finite(all_etr) & is.finite(iqm_ratio_etr)),
      all_etr_median = median_obs(all_etr[is.finite(iqm_ratio_etr)]),
      iqm_ratio_etr_median = median_obs(iqm_ratio_etr[is.finite(all_etr)]),
      median_etr_gap = median_obs(iqm_ratio_etr - all_etr),
      profit_weighted_etr_gap = ratio(sum_obs(t1_profit * (iqm_ratio_etr - all_etr)),
        sum_obs(t1_profit[is.finite(iqm_ratio_etr - all_etr)])),
      paired_etr_lower_share = mean(iqm_ratio_etr < all_etr, na.rm = TRUE),
      phi_n = sum(is.finite(all_phi) & is.finite(iqm_ratio_phi)),
      all_phi_median = median_obs(all_phi[is.finite(iqm_ratio_phi)]),
      iqm_ratio_phi_median = median_obs(iqm_ratio_phi[is.finite(all_phi)]),
      median_phi_gap = median_obs(iqm_ratio_phi - all_phi),
      profit_weighted_phi_gap = ratio(sum_obs(t1_profit * (iqm_ratio_phi - all_phi)),
        sum_obs(t1_profit[is.finite(iqm_ratio_phi - all_phi)])),
      paired_phi_lower_share = mean(iqm_ratio_phi < all_phi, na.rm = TRUE),
      mean_scaled_shortfall_median = median_obs(mean_scaled_shortfall),
      mean_scaled_shortfall_negative_n = sum(mean_scaled_shortfall < 0),
      tail_proxy_n = sum(half_core_order_feasible),
      tail_proxy_profit_usd = sum_obs(t1_profit[half_core_order_feasible]),
      outer_both_tails_weighted_proxy = ratio(sum_obs(t1_profit * outer_both_tails_proxy),
                                             tail_proxy_profit_usd),
      upper_tail_weighted_lb_conditional = ratio(sum_obs(t1_profit * top_quartile_lb_conditional),
                                                 tail_proxy_profit_usd),
      upper_tail_weighted_ub_conditional = outer_both_tails_weighted_proxy,
      .by = c(scope, window, table2_statistic)
    ) |> mutate(record = "matched_summary", sample = sample)
  }
  iq_out <- bind_rows(
    iq_summary(iq_cells, "all_matched_positive_profit"),
    iq_summary(filter(iq_cells, counts_match, t1_subgroups_count >= 8), "same_counts_min_8"),
    iq_summary(filter(iq_cells, year >= 2018, counts_match, t1_subgroups_count >= 8,
                      abs(t1_subgroups_count / 4 - round(t1_subgroups_count / 4)) < 1e-6),
               "same_counts_multiple_of_4_min_8"),
    mutate(iq_cells, record = "matched_cell", window = as.character(year))
  )

  # 4. Entity activity incidence, not mutually exclusive shares. Restrict to
  # explicit <15/15+ reporter schemes. Pair low/high bins separately by activity
  # so the weighted shares have the same reporting support.
  act_long <- t3 |> country_rows() |>
    filter(year %in% MAIN_YEARS, etr_bracket %in% c("rate_0_15", "rate_15"),
           entities_count > 0) |>
    select(all_of(key), etr_bracket, entities_count, all_of(activity)) |>
    pivot_longer(all_of(activity), names_to = "activity", values_to = "entities_active") |>
    filter(is.finite(entities_active), between(entities_active, 0, entities_count))
  act_match <- act_long |> pivot_wider(names_from = etr_bracket,
                                      values_from = c(entities_count, entities_active)) |>
    filter(is.finite(entities_active_rate_0_15), is.finite(entities_active_rate_15)) |>
    mutate(share_low = entities_active_rate_0_15 / entities_count_rate_0_15,
           share_high = entities_active_rate_15 / entities_count_rate_15,
           gap = share_low - share_high)
  activity_comp <- scope_panel(time_panel(act_match, "2017–2023"), host_rules[1:2]) |>
    summarise(observations = n(), parents = n_distinct(parent),
      entities_low = sum(entities_count_rate_0_15),
      entities_high = sum(entities_count_rate_15),
      share_low = sum(entities_active_rate_0_15) / entities_low,
      share_high = sum(entities_active_rate_15) / entities_high,
      composition_gap = share_low - share_high, median_paired_gap = median(gap),
      .by = c(scope, window, activity)
    ) |> mutate(record = "table3_activity_paired")

  core_act <- activity[1:5]
  core_cols <- paste0(core_act, "_panelai")
  regression <- base |>
    select(all_of(key), entities_count_panelai, all_of(core_cols)) |>
    filter(entities_count_panelai > 0,
           if_all(all_of(core_cols), ~ is.finite(.x) & between(.x, 0, entities_count_panelai))) |>
    mutate(across(all_of(core_cols), ~ .x / entities_count_panelai)) |>
    inner_join(s1 |> select(all_of(key), analysis_profit_positive,
      l3 = stage1_distributional_liability_rate, l4 = ladder_l4_strict_liability_rate),
      by = key, relationship = "one-to-one") |>
    inner_join(s2 |> filter(rate_scenario == "initial") |>
      select(all_of(key), phi = stage2_phi),
      by = key, relationship = "one-to-one") |>
    filter(year %in% MAIN_YEARS, analysis_profit_positive > 0)
  fit_activity <- function(x, scope, outcome, fe) {
    x <- filter(x, is.finite(.data[[outcome]]))
    # Test identifying outcome variation on the estimation sample explicitly.
    within <- x |> summarise(spread = max(.data[[outcome]]) - min(.data[[outcome]]),
                              .by = c(affiliate, year))
    nf <- if (fe == "affiliate^year") sum(within$spread > 1e-12) else NA_integer_
    counts <- function(d) tibble(observations = nrow(d), parents = n_distinct(d$parent),
        affiliates = n_distinct(d$affiliate), host_years = n_distinct(d$affiliate, d$year))
    info <- counts(x)
    if (fe == "affiliate^year" && nf == 0L) {
      return(bind_cols(info, tibble(status = "absorbed_by_affiliate_year_FE",
        host_years_with_outcome_variation = nf, term = core_cols,
        estimate = NA_real_, std_error = NA_real_, p_value = NA_real_)))
    }
    model <- fixest::feols(as.formula(paste(outcome, "~", paste(core_cols, collapse = " + "), "|", fe)),
                   data = x, vcov = ~ parent + affiliate, notes = FALSE)
    used <- x[fixest::obs(model), , drop = FALSE]
    cc <- fixest::coeftable(model)
    used_within <- used |> summarise(
      spread = max(.data[[outcome]]) - min(.data[[outcome]]), .by = c(affiliate, year)
    )
    left_join(tibble(term = core_cols), tibble(term = rownames(cc), estimate = cc[, 1],
       std_error = cc[, 2], p_value = cc[, 4]), by = "term") |>
      mutate(
        !!!counts(used), status = if_else(is.finite(estimate), "estimated", "collinear"),
        host_years_with_outcome_variation = if (fe == "affiliate^year")
          sum(used_within$spread > 1e-12) else NA_integer_,
        within_r2 = as.numeric(fixest::fitstat(model, "wr2")[[1]]),
        # x and y are shares: a 10 pp change in x corresponds to 10 * beta pp of y.
        outcome_pp_per_10pp_activity = 10 * estimate,
        se_pp_per_10pp_activity = 10 * std_error,
        p_value_holm_within_model = p.adjust(p_value, method = "holm")
      )
  }
  activity_fits <- pmap_dfr(expand_grid(scope = names(host_rules)[1:2],
      outcome = c("l3", "l4", "phi"),
      fixed_effects = c("affiliate + year", "affiliate^year", "parent + affiliate^year")),
    function(scope, outcome, fixed_effects) {
      d <- regression[host_rules[[scope]](regression), ]
      fe <- if (outcome == "l3" && fixed_effects == "parent + affiliate^year")
        "affiliate^year" else fixed_effects
      fit_activity(d, scope, outcome, fe) |>
        mutate(record = "activity_regression", scope = scope, outcome = outcome,
               fixed_effects = fixed_effects, window = "2017–2023")
    })
  act_out <- bind_rows(activity_comp, activity_fits)

  outputs <- list(
    step14_table3_vs_table4_blending_wedge = blend,
    step14_table6_mne_size_incidence = size_out,
    step14_table2_interquartile_skewness = iq_out,
    step14_business_activity_drivers = act_out
  )
  stopifnot(all(vapply(outputs, nrow, integer(1)) > 0L))
  dir.create(DIAGNOSTICS_DIR, recursive = TRUE, showWarnings = FALSE)
  iwalk(outputs, function(x, name) {
    x <- mutate(x, across(where(is.double), ~ replace(.x, !is.finite(.x), NA_real_)))
    write_csv(x, file.path(DIAGNOSTICS_DIR, paste0(name, ".csv")))
    message(name, ": ", nrow(x), " rows")
  })
}

# Profit reconciliation validation

run_profit_correction_validation <- function(in_dir = PROCESSED_DIR,
                                             out_dir = PROCESSED_DIR) {
  diag_dir <- file.path(out_dir, "diagnostics")
  dir.create(diag_dir, showWarnings = FALSE, recursive = TRUE)

  panel <- readRDS(file.path(in_dir, "base_panel.rds")) |>
    filter(year %in% MAIN_YEARS)

  observed <- panel |>
    filter(profit_panelai > 0, !is.na(profit_adj_panelai)) |>
    mutate(
      observed_adjusted_ratio = clamp_unit_interval(
        safe_divide(profit_adj_panelai, profit_panelai)
      ),
      observed_correction_rate = 1 - observed_adjusted_ratio
    )

  observed_by_parent <- observed |>
    group_by(parent, parent_jurisdiction_name, is_domestic) |>
    summarise(
      cells = n(),
      years = n_distinct(year),
      unadjusted_profit = sum(profit_panelai, na.rm = TRUE),
      adjusted_profit = sum(profit_adj_panelai, na.rm = TRUE),
      aggregate_correction_rate = clamp_unit_interval(
        1 - safe_divide(adjusted_profit, unadjusted_profit)
      ),
      median_cell_correction_rate =
        median(observed_correction_rate, na.rm = TRUE),
      profit_weighted_cell_correction_rate =
        weighted_mean_clean(observed_correction_rate, profit_panelai),
      .groups = "drop"
    ) |>
    arrange(parent, desc(is_domestic))

  positive_tax_panel <- panel |>
    filter(
      profit_panelai > 0,
      !is.na(tax_accrued_panelai),
      tax_accrued_panelai >= 0
    )

  domestic <- positive_tax_panel |>
    filter(is_domestic) |>
    transmute(
      jurisdiction = affiliate,
      year,
      parent,
      parent_jurisdiction_name,
      domestic_profit = profit_panelai,
      domestic_tax = tax_accrued_panelai,
      domestic_etr = safe_divide(domestic_tax, domestic_profit)
    )

  foreign <- positive_tax_panel |>
    filter(!is_domestic) |>
    group_by(affiliate, year) |>
    summarise(
      foreign_profit = sum(profit_panelai, na.rm = TRUE),
      foreign_tax = sum(tax_accrued_panelai, na.rm = TRUE),
      foreign_parents = n_distinct(parent),
      foreign_cells = n(),
      foreign_etr = safe_divide(foreign_tax, foreign_profit),
      .groups = "drop"
    ) |>
    rename(jurisdiction = affiliate)

  etr_parity <- domestic |>
    left_join(foreign, by = c("jurisdiction", "year")) |>
    filter(
      is.finite(domestic_etr),
      is.finite(foreign_etr),
      foreign_profit > 0,
      foreign_etr > 0,
      foreign_parents >= 3
    ) |>
    mutate(
      implied_correction_rate_raw = 1 - domestic_etr / foreign_etr,
      implied_correction_rate = pmin(
        pmax(implied_correction_rate_raw, 0),
        0.555
      ),
      implied_reduction = implied_correction_rate * domestic_profit
    )

  etr_parity_summary <- etr_parity |>
    summarise(
      country_years = n(),
      parents = n_distinct(parent),
      domestic_profit = sum(domestic_profit, na.rm = TRUE),
      implied_reduction = sum(implied_reduction, na.rm = TRUE),
      profit_weighted_correction_rate =
        weighted_rate_clean(implied_reduction, domestic_profit),
      median_correction_rate = median(implied_correction_rate, na.rm = TRUE),
      p25_correction_rate =
        as.numeric(quantile(implied_correction_rate, 0.25, na.rm = TRUE)),
      p75_correction_rate =
        as.numeric(quantile(implied_correction_rate, 0.75, na.rm = TRUE))
    )

  etr_parity_by_parent <- etr_parity |>
    group_by(parent, parent_jurisdiction_name) |>
    summarise(
      country_years = n(),
      years = n_distinct(year),
      domestic_profit = sum(domestic_profit, na.rm = TRUE),
      implied_reduction = sum(implied_reduction, na.rm = TRUE),
      public_proxy_rate = weighted_rate_clean(implied_reduction, domestic_profit),
      median_country_year_rate =
        median(implied_correction_rate, na.rm = TRUE),
      aggregate_domestic_etr =
        safe_divide(
          sum(domestic_tax, na.rm = TRUE),
          sum(domestic_profit, na.rm = TRUE)
        ),
      aggregate_foreign_etr =
        safe_divide(
          sum(foreign_tax, na.rm = TRUE),
          sum(foreign_profit, na.rm = TRUE)
        ),
      minimum_foreign_parent_support = min(foreign_parents, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(desc(domestic_profit))

  benchmark_exposed <- panel |>
    filter(
      is_domestic,
      profit_panelai > 0,
      is.na(profit_adj_panelai)
    ) |>
    group_by(parent, parent_jurisdiction_name) |>
    summarise(
      benchmark_cells = n(),
      benchmark_profit = sum(profit_panelai, na.rm = TRUE),
      benchmark_rate =
        weighted_mean_clean(domestic_correction_rate_baseline, profit_panelai),
      benchmark_reduction =
        sum(profit_panelai * domestic_correction_rate_baseline, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(
      benchmark_source = case_when(
        parent == "USA" ~ "Garcia-Bernardo et al. (2022), US domestic CbCR reconciliation",
        parent == "NLD" ~ "Garcia-Bernardo and Jansky (2024), Netherlands correction",
        TRUE ~ "Hugger et al. (2026), median UPE correction"
      )
    )

  benchmark_comparison <- benchmark_exposed |>
    left_join(etr_parity_by_parent,
      by = c("parent", "parent_jurisdiction_name")
    ) |>
    mutate(
      public_proxy_gap = public_proxy_rate - benchmark_rate,
      public_proxy_available = !is.na(public_proxy_rate)
    ) |>
    arrange(desc(benchmark_reduction))

  direct_summary <- observed_by_parent |>
    mutate(
      evidence_source = "OECD observed adjusted profit",
      scope = if_else(is_domestic, "Domestic parent cell", "Foreign affiliate cell"),
      implied_rate = aggregate_correction_rate,
      benchmark_rate = NA_real_,
      interpretation = "Direct public CbCR adjustment where observed"
    ) |>
    transmute(
      evidence_source,
      scope,
      parent,
      parent_jurisdiction_name,
      cells,
      profit = unadjusted_profit,
      implied_rate,
      benchmark_rate,
      interpretation
    )

  parity_summary <- bind_rows(
    etr_parity_summary |>
      transmute(
        evidence_source = "Public CbCR ETR-parity proxy",
        scope = "All supported domestic country-years",
        parent = "ALL",
        parent_jurisdiction_name = "Supported domestic cells",
        cells = country_years,
        profit = domestic_profit,
        implied_rate = profit_weighted_correction_rate,
        benchmark_rate = 0.324,
        interpretation = "Diagnostic only; foreign affiliates are an imperfect control group"
      ),
    benchmark_comparison |>
      slice_head(n = 10) |>
      transmute(
        evidence_source = "Public CbCR ETR-parity proxy",
        scope = "Largest benchmark-exposed parents",
        parent,
        parent_jurisdiction_name,
        cells = benchmark_cells,
        profit = benchmark_profit,
        implied_rate = public_proxy_rate,
        benchmark_rate,
        interpretation = if_else(
          public_proxy_available,
          "Compared with benchmark calibration",
          "No public proxy available after support filter"
        )
      )
  )

  validation_summary <- bind_rows(direct_summary, parity_summary)

  stopifnot(nrow(observed_by_parent) > 0)
  stopifnot(nrow(etr_parity_by_parent) > 0)
  stopifnot(all(validation_summary$implied_rate >= 0 |
    is.na(validation_summary$implied_rate)))
  stopifnot(all(validation_summary$implied_rate <= 1 |
    is.na(validation_summary$implied_rate)))

  write_csv(
    observed_by_parent,
    file.path(diag_dir, "step12_profit_correction_observed_adjusted.csv")
  )
  write_csv(
    etr_parity,
    file.path(diag_dir, "step12_profit_correction_etr_parity_cell.csv")
  )
  write_csv(
    etr_parity_summary,
    file.path(diag_dir, "step12_profit_correction_etr_parity_summary.csv")
  )
  write_csv(
    etr_parity_by_parent,
    file.path(diag_dir, "step12_profit_correction_etr_parity_by_parent.csv")
  )
  write_csv(
    benchmark_comparison,
    file.path(diag_dir, "step12_profit_correction_benchmark_comparison.csv")
  )
  write_csv(
    validation_summary,
    file.path(diag_dir, "step12_profit_correction_validation_summary.csv")
  )

  saveRDS(
    observed_by_parent,
    file.path(out_dir, "profit_correction_observed_adjusted.rds")
  )
  saveRDS(
    etr_parity_by_parent,
    file.path(out_dir, "profit_correction_etr_parity_by_parent.rds")
  )
  saveRDS(
    benchmark_comparison,
    file.path(out_dir, "profit_correction_benchmark_comparison.rds")
  )
  saveRDS(
    validation_summary,
    file.path(out_dir, "profit_correction_validation_summary.rds")
  )

  invisible(list(
    observed_by_parent = observed_by_parent,
    etr_parity_by_parent = etr_parity_by_parent,
    benchmark_comparison = benchmark_comparison,
    validation_summary = validation_summary
  ))
}

run_measurement_and_cbcr_extensions <- function() {
  run_etr_and_bracket_audit()
  run_ladder_diagnostics()
  run_rank_beta_diagnostics()
  run_cbcr_table_extensions()
  run_profit_correction_validation()
}

if (is_direct_script_run("code/08_measurement_and_cbcr_extensions.R")) {
  run_measurement_and_cbcr_extensions()
}
