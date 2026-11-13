# 05_stage3_behavioral.R
# Step 5 of the methodology pipeline.
#
# Implements Stage 3 of the GMT revenue pipeline. The script estimates
# Hines-Rice profit-shifting semi-elasticities, maps them into behavioural
# filters and builds the 2^5 liability scenario matrix. The Stage 3 revenue,
# ANOVA and H4 exports are pre-waterfall source-proxy diagnostics. Stage 4.5
# allocates UTPR by collector substance and Stage 4.6 decomposes that revenue.

source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "04_stage2_sbie.R"), local = TRUE)
# Real-activity formulary routes and conservation checks.
normalise_formulary_destinations <- function(destinations, keys) {
  destinations |>
    group_by(across(all_of(keys))) |>
    mutate(
      raw_weight = 0.25 * coalesce_zero(safe_divide(employees, sum(employees))) +
        0.25 * coalesce_zero(safe_divide(payroll, sum(payroll))) +
        0.50 * coalesce_zero(safe_divide(upr, sum(upr))),
      weight = if (sum(raw_weight) > 0) raw_weight / sum(raw_weight) else rep(1 / n(), n()),
      equal_weight_fallback = sum(raw_weight) == 0
    ) |>
    ungroup() |>
    filter(weight > 0)
}

build_rule_b_footprint <- function(panel) {
  footprint <- panel |>
    distinct(parent, affiliate, year, affiliate_cit_rate_unit,
      etr_panelai_stage1, employees_sbie, payroll_sbie, upr_panelai) |>
    filter(affiliate_cit_rate_unit >= GMT_RATE) |>
    transmute(
      parent, year, destination = affiliate, statutory_rate = affiliate_cit_rate_unit,
      destination_etr = etr_panelai_stage1,
      employees = pmax(coalesce_zero(employees_sbie), 0),
      payroll = pmax(coalesce_zero(payroll_sbie), 0),
      upr = pmax(coalesce_zero(upr_panelai), 0)
    ) |>
    filter(employees > 0 | payroll > 0 | upr > 0)
  assert_unique_keys(footprint, c("parent", "year", "destination"), "Rule B activity footprint")
  footprint
}

build_rule_b_global_footprint <- function(footprint, host) {
  footprint |>
    group_by(destination, year, statutory_rate) |>
    summarise(across(c(employees, payroll, upr), sum), .groups = "drop") |>
    left_join(transmute(host, destination = affiliate, year, destination_etr = avg_etr_stage1),
      by = c("destination", "year"), relationship = "many-to-one")
}

allocate_rule_b_sources <- function(sources, footprint, global) {
  # Eligibility and formula denominators depend on the source ETR.
  # Exclude the origin itself and use global activity only if its parent
  # has no eligible bilateral destination.
  stopifnot(all(is.finite(sources$source_etr)), all(sources$source_etr < GMT_RATE))
  own <- sources |>
    inner_join(footprint, by = c("parent", "year"), relationship = "many-to-many") |>
    filter(destination != affiliate, destination_etr > source_etr) |>
    normalise_formulary_destinations("source_id") |>
    mutate(route = "parent_activity")
  fallback <- sources |>
    anti_join(own, by = "source_id") |>
    inner_join(global, by = "year", relationship = "many-to-many") |>
    filter(destination != affiliate, destination_etr > source_etr) |>
    normalise_formulary_destinations("source_id") |>
    mutate(route = "global_activity")
  routes <- bind_rows(own, fallback) |>
    mutate(received = reallocated_profit * weight)
  check <- routes |>
    summarise(gap = sum(received) - first(reallocated_profit),
      weight_gap = sum(weight) - 1, .by = source_id)
  if (nrow(check) != nrow(sources) || any(abs(check$gap) >= 1e-3) ||
    any(abs(check$weight_gap) > 1e-12)) {
    stop("Rule B has an unsupported source or fails source-level conservation")
  }
  routes
}

build_rule_b_reallocation <- function(panel, host) {
  footprint <- build_rule_b_footprint(panel)
  global <- build_rule_b_global_footprint(footprint, host)
  origins <- panel |>
    filter(reallocated_profit > 0, factor5_behaviour == "behavioural") |>
    transmute(
      across(all_of(SCENARIO_VARS)), parent, affiliate, year,
      source_etr = static_tau_low, reallocated_profit,
      transfer_pricing_ip = reallocated_profit_transfer_pricing_ip,
      debt = reallocated_profit_debt, substance_planning = reallocated_profit_substance_planning
    )
  channel_columns <- c("transfer_pricing_ip", "debt", "substance_planning")
  routed <- origins |>
    group_split(scenario_id, year, .keep = TRUE) |>
    map_dfr(function(sources) {
      vintage <- first(sources$year)
      routes <- allocate_rule_b_sources(mutate(sources, source_id = row_number()),
        filter(footprint, year == vintage), filter(global, year == vintage))
      routes |>
        select(all_of(SCENARIO_VARS), year, parent, destination, route, weight,
          statutory_rate, destination_etr, source_etr, all_of(channel_columns)) |>
        pivot_longer(all_of(channel_columns), names_to = "behavioural_channel",
          values_to = "source_profit") |>
        filter(source_profit > 0) |>
        mutate(
          received = source_profit * weight,
          ordinary_cit_gross_destination_revenue = received * statutory_rate,
          ordinary_cit_gross_destination_revenue_effective = received * pmax(GMT_RATE, destination_etr),
          ordinary_cit_source_loss = received * source_etr,
          ordinary_cit_net_recovery = ordinary_cit_gross_destination_revenue - ordinary_cit_source_loss,
          global_fallback_profit_received = if_else(route == "global_activity", received, 0)
        ) |>
        summarise(
          reallocated_profit_received = sum(received),
          across(c(starts_with("ordinary_cit_"), global_fallback_profit_received), sum),
          source_parents_rule_b = n_distinct(parent),
          .by = c(all_of(SCENARIO_VARS), year, destination, behavioural_channel)
        )
    })
  if (!nrow(origins)) {
    routed <- origins |>
      transmute(across(all_of(SCENARIO_VARS)), year, destination = character(),
        behavioural_channel = character(), reallocated_profit_received = numeric(),
        ordinary_cit_gross_destination_revenue = numeric(),
        ordinary_cit_gross_destination_revenue_effective = numeric(),
        ordinary_cit_source_loss = numeric(), ordinary_cit_net_recovery = numeric(),
        global_fallback_profit_received = numeric(), source_parents_rule_b = integer())
  }
  routed
}


SESH_BANDWIDTH_BASELINE <- 0.02
SESH_BANDWIDTH_SENSITIVITY <- c(0.01, 0.02, 0.03)
LOW_ETR_TAIL_CUTOFF <- 0.05
TAIL_REWEIGHT_TARGET_SHARE <- 0.50
LOG_T0_GRID <- seq(0.001, 0.200, length.out = 60)
MIN_PAIR_YEARS_FOR_FE <- 2L
SIMULATED_ETR_MEASURE <- "EATR"
SIMULATED_ETR_TAX_BASIS <- "BASELINE"
SIMULATED_ETR_SCENARIO <- "FIXED"
SIMULATED_ETR_TAX_TYPE <- "COMPOSITE"
BEHAVIOURAL_MAX_REALLOCATION_SHARE <- 1
# Fixed sensitivity benchmark motivated by Heckemeyer and Overesch (2017).
DIAGNOSTIC_CHANNEL_PRIOR_TP_IP <- 0.72
DIAGNOSTIC_CHANNEL_PRIOR_DEBT <- 0.28
DIAGNOSTIC_CHANNEL_PRIOR_SUBSTANCE <- 0

classify_etr_tail_band <- function(tau,
                                   cutoff = LOW_ETR_TAIL_CUTOFF,
                                   threshold = GMT_RATE) {
  case_when(
    is.na(tau) | !is.finite(tau) ~ "missing",
    tau < cutoff ~ "below_5pct",
    tau < threshold ~ "five_to_15pct",
    TRUE ~ "at_or_above_15pct"
  )
}

tail_balance_weights <- function(tail_indicator,
                                 target_tail_share =
                                   TAIL_REWEIGHT_TARGET_SHARE) {
  if (target_tail_share <= 0 || target_tail_share >= 1) {
    stop("Target tail share must lie strictly between zero and one")
  }

  tail_indicator <- as.logical(tail_indicator)
  valid <- !is.na(tail_indicator)
  weights <- rep(NA_real_, length(tail_indicator))

  if (!any(valid)) {
    return(weights)
  }

  observed_tail_share <- mean(tail_indicator[valid])
  if (observed_tail_share <= 0 || observed_tail_share >= 1) {
    return(weights)
  }

  weights[valid & tail_indicator] <- target_tail_share / observed_tail_share
  weights[valid & !tail_indicator] <-
    (1 - target_tail_share) / (1 - observed_tail_share)
  weights
}

summarise_stage3_etr_tail_support <- function(estimation_sample,
                                              cutoff = LOW_ETR_TAIL_CUTOFF,
                                              threshold = GMT_RATE) {
  base <- estimation_sample |>
    filter(is.finite(tau)) |>
    mutate(
      tail_band = classify_etr_tail_band(tau, cutoff, threshold),
      tail_band = factor(
        tail_band,
        levels = c("below_5pct", "five_to_15pct", "at_or_above_15pct")
      )
    )

  summarise_scope <- function(data, scope_label) {
    data |>
      mutate(scope = scope_label) |>
      group_by(scope, year, tail_band) |>
      summarise(
        rows = n(),
        pairs = n_distinct(pair_id),
        affiliates = n_distinct(affiliate),
        parents = n_distinct(parent),
        total_profit = sum(analysis_profit_base, na.rm = TRUE),
        mean_tau = mean(tau, na.rm = TRUE),
        median_tau = stats::median(tau, na.rm = TRUE),
        .groups = "drop_last"
      ) |>
      mutate(
        row_share = rows / sum(rows),
        profit_share = total_profit / sum(total_profit, na.rm = TRUE)
      ) |>
      ungroup()
  }

  pooled <- base |>
    mutate(year = NA_integer_) |>
    summarise_scope("pooled")

  by_year <- summarise_scope(base, "year")

  bind_rows(pooled, by_year) |>
    arrange(scope, year, tail_band)
}

summarise_stage3_tail_reweighting_feasibility <- function(
  estimation_sample,
  cutoff = LOW_ETR_TAIL_CUTOFF,
  target_tail_share = TAIL_REWEIGHT_TARGET_SHARE
) {
  base <- estimation_sample |>
    filter(is.finite(tau)) |>
    mutate(tail_flag = tau < cutoff)

  weights <- tail_balance_weights(base$tail_flag, target_tail_share)

  pair_support <- base |>
    group_by(pair_id) |>
    summarise(
      has_tail = any(tail_flag, na.rm = TRUE),
      has_non_tail = any(!tail_flag, na.rm = TRUE),
      .groups = "drop"
    )

  affiliate_support <- base |>
    group_by(affiliate) |>
    summarise(
      has_tail = any(tail_flag, na.rm = TRUE),
      has_non_tail = any(!tail_flag, na.rm = TRUE),
      .groups = "drop"
    )

  tail_rows <- sum(base$tail_flag, na.rm = TRUE)
  total_rows <- nrow(base)
  tail_profit <- sum(base$analysis_profit_base[base$tail_flag], na.rm = TRUE)
  total_profit <- sum(base$analysis_profit_base, na.rm = TRUE)

  finite_weights <- weights[is.finite(weights)]
  effective_n <- if (length(finite_weights) > 0) {
    sum(finite_weights)^2 / sum(finite_weights^2)
  } else {
    NA_real_
  }
  max_weight <- if (length(finite_weights) > 0) max(finite_weights) else NA_real_

  tibble(
    metric = c(
      "sample_rows",
      "low_tail_rows",
      "low_tail_row_share",
      "low_tail_profit_share",
      "low_tail_pairs",
      "low_tail_affiliates",
      "low_tail_parents",
      "low_tail_years",
      "tail_switching_pairs",
      "tail_switching_pair_share",
      "tail_switching_affiliates",
      "tail_balance_target_share",
      "tail_balance_tail_weight",
      "tail_balance_non_tail_weight",
      "tail_balance_max_weight",
      "tail_balance_effective_n",
      "tail_balance_design_effect"
    ),
    value = c(
      total_rows,
      tail_rows,
      tail_rows / total_rows,
      tail_profit / total_profit,
      n_distinct(base$pair_id[base$tail_flag]),
      n_distinct(base$affiliate[base$tail_flag]),
      n_distinct(base$parent[base$tail_flag]),
      n_distinct(base$year[base$tail_flag]),
      sum(pair_support$has_tail & pair_support$has_non_tail),
      mean(pair_support$has_tail & pair_support$has_non_tail),
      sum(affiliate_support$has_tail & affiliate_support$has_non_tail),
      target_tail_share,
      first_non_missing(weights[base$tail_flag]),
      first_non_missing(weights[!base$tail_flag]),
      max_weight,
      effective_n,
      total_rows / effective_n
    )
  )
}

coefficient_table_from_vcov <- function(coefficients, vcov, model_spec, t0,
                                        n, n_affiliates, n_parents,
                                        df_resid_full, within_r_squared,
                                        inference, df_inference,
                                        dependent_variable = "log_profit") {
  diag_vcov <- diag(vcov)
  std_error <- sqrt(if_else(diag_vcov >= 0, diag_vcov, NA_real_))
  statistic <- coefficients / std_error

  tibble(
    model_spec = model_spec,
    t0 = t0,
    inference = inference,
    term = names(coefficients),
    estimate = as.numeric(coefficients),
    std_error = as.numeric(std_error),
    statistic = as.numeric(statistic),
    p_value = 2 * stats::pt(
      abs(statistic),
      df = df_inference,
      lower.tail = FALSE
    ),
    negative_variance_flag = diag_vcov < 0,
    n = n,
    n_affiliates = n_affiliates,
    n_parents = n_parents,
    df_inference = df_inference,
    df_resid_full = df_resid_full,
    within_r_squared = within_r_squared,
    dependent_variable = dependent_variable
  )
}

# The manual estimator is retained because its degrees-of-freedom correction is
# part of the existing Stage 3 diagnostics. The implementation is deliberately
# named so that readers do not mistake it for a standard package call.
fit_two_way_fe_manual <- function(data, x_cols, model_spec, t0 = NA_real_,
                                  compute_vcov = TRUE,
                                  y_col = "log_profit") {
  model_data <- data |>
    select(pair_id, parent, year, affiliate, all_of(y_col), all_of(x_cols)) |>
    filter(if_all(c(all_of(y_col), all_of(x_cols)), is.finite))

  mat <- model_data |>
    select(all_of(y_col), all_of(x_cols)) |>
    as.matrix()

  mat_resid <- demean_two_way(mat, model_data$pair_id, model_data$year)
  y <- mat_resid[, y_col]
  x <- mat_resid[, x_cols, drop = FALSE]

  qr_x <- qr(x)
  independent_cols <- qr_x$pivot[seq_len(qr_x$rank)]
  x <- x[, sort(independent_cols), drop = FALSE]
  x_cols_kept <- colnames(x)
  x_cols_dropped <- setdiff(x_cols, x_cols_kept)
  crossprod_x <- crossprod(x)
  crossprod_rank <- qr(crossprod_x)$rank
  crossprod_condition_number <- kappa(crossprod_x, exact = FALSE)

  fit <- lm.fit(x = x, y = y)
  coefficients <- fit$coefficients
  residuals <- as.numeric(fit$residuals)
  fitted_within <- as.numeric(x %*% coefficients)
  rss <- sum(residuals^2)
  tss_within <- sum((y - mean(y))^2)
  within_r_squared <- if (tss_within > 0) 1 - rss / tss_within else NA_real_
  n <- nrow(x)
  fe_rank <- n_distinct(model_data$pair_id) + n_distinct(model_data$year) - 1
  k_total <- length(coefficients) + fe_rank
  df_resid_full <- n - k_total
  sigma2_mle <- rss / n
  loglik <- -0.5 * n * (log(2 * pi) + 1 + log(sigma2_mle))
  n_affiliates <- n_distinct(model_data$affiliate)
  n_parents <- n_distinct(model_data$parent)

  if (compute_vcov) {
    vcov <- cluster_vcov(
      x = x,
      residuals = residuals,
      cluster = model_data$affiliate,
      df_resid_full = df_resid_full
    )
    vcov_two_way <- cluster_vcov_twoway(
      x = x,
      residuals = residuals,
      cluster_a = model_data$parent,
      cluster_b = model_data$affiliate,
      df_resid_full = df_resid_full
    )
    std_error <- sqrt(diag(vcov))
    statistic <- coefficients / std_error
    p_value <- 2 * stats::pt(
      abs(statistic),
      df = max(n_affiliates - 1, 1),
      lower.tail = FALSE
    )
    coefficient_table_two_way <- coefficient_table_from_vcov(
      coefficients = coefficients,
      vcov = vcov_two_way,
      model_spec = model_spec,
      t0 = t0,
      n = n,
      n_affiliates = n_affiliates,
      n_parents = n_parents,
      df_resid_full = df_resid_full,
      within_r_squared = within_r_squared,
      dependent_variable = y_col,
      inference = "parent_affiliate_clustered",
      df_inference = max(min(n_parents, n_affiliates) - 1, 1)
    )
  } else {
    vcov <- NULL
    vcov_two_way <- NULL
    std_error <- rep(NA_real_, length(coefficients))
    statistic <- rep(NA_real_, length(coefficients))
    p_value <- rep(NA_real_, length(coefficients))
    coefficient_table_two_way <- tibble()
  }

  list(
    model_spec = model_spec,
    t0 = t0,
    dependent_variable = y_col,
    x_cols = x_cols_kept,
    x_cols_dropped = x_cols_dropped,
    n = n,
    n_pairs = n_distinct(model_data$pair_id),
    n_affiliates = n_affiliates,
    n_parents = n_parents,
    n_years = n_distinct(model_data$year),
    fe_rank = fe_rank,
    x_rank = qr_x$rank,
    crossprod_rank = crossprod_rank,
    crossprod_condition_number = crossprod_condition_number,
    k_total = k_total,
    df_resid_full = df_resid_full,
    rss = rss,
    tss_within = tss_within,
    within_r_squared = within_r_squared,
    sigma2_mle = sigma2_mle,
    loglik = loglik,
    aic = -2 * loglik + 2 * k_total,
    bic = -2 * loglik + log(n) * k_total,
    coefficients = coefficients,
    vcov = vcov,
    vcov_two_way = vcov_two_way,
    coefficient_table = tibble(
      model_spec = model_spec,
      t0 = t0,
      term = names(coefficients),
      estimate = as.numeric(coefficients),
      std_error = as.numeric(std_error),
      statistic = as.numeric(statistic),
      p_value = as.numeric(p_value),
      inference = "affiliate_clustered",
      n = n,
      n_affiliates = n_affiliates,
      n_parents = n_parents,
      df_resid_full = df_resid_full,
      within_r_squared = within_r_squared,
      dependent_variable = y_col
    ),
    coefficient_table_two_way = coefficient_table_two_way,
    residuals = residuals,
    fitted_within = fitted_within,
    model_data = model_data
  )
}

fit_fe_ols <- fit_two_way_fe_manual

build_fixest_equivalence_diagnostic <- function(manual_fit,
                                                tolerance = 1e-8) {
  if (!requireNamespace("fixest", quietly = TRUE)) {
    return(tibble(
      model_spec = manual_fit$model_spec,
      term = NA_character_,
      status = "fixest_not_installed",
      manual_estimate = NA_real_,
      fixest_estimate = NA_real_,
      abs_difference = NA_real_,
      within_tolerance = NA
    ))
  }

  rhs <- paste(manual_fit$x_cols, collapse = " + ")
  formula <- stats::as.formula(paste0(
    manual_fit$dependent_variable, " ~ ", rhs, " | pair_id + year"
  ))

  fixest_fit <- tryCatch(
    fixest::feols(
      formula,
      data = manual_fit$model_data,
      cluster = stats::as.formula("~ parent + affiliate"),
      warn = FALSE,
      notes = FALSE
    ),
    error = function(e) e
  )

  if (inherits(fixest_fit, "error")) {
    return(tibble(
      model_spec = manual_fit$model_spec,
      term = NA_character_,
      status = paste0("fixest_error: ", conditionMessage(fixest_fit)),
      manual_estimate = NA_real_,
      fixest_estimate = NA_real_,
      abs_difference = NA_real_,
      within_tolerance = NA
    ))
  }

  manual_coef <- manual_fit$coefficients
  fixest_coef <- stats::coef(fixest_fit)
  common_terms <- intersect(names(manual_coef), names(fixest_coef))

  tibble(
    model_spec = manual_fit$model_spec,
    term = common_terms,
    status = "compared",
    manual_estimate = as.numeric(manual_coef[common_terms]),
    fixest_estimate = as.numeric(fixest_coef[common_terms]),
    abs_difference = abs(manual_estimate - fixest_estimate),
    within_tolerance = abs_difference <= tolerance
  )
}

fit_fe_2sls <- function(data, y_col, endogenous_col, instrument_col,
                        exog_cols, model_spec, t0 = NA_real_) {
  model_data <- data |>
    select(
      pair_id, parent, year, affiliate, all_of(y_col),
      all_of(endogenous_col), all_of(instrument_col),
      all_of(exog_cols)
    ) |>
    filter(if_all(c(
      all_of(y_col), all_of(endogenous_col),
      all_of(instrument_col), all_of(exog_cols)
    ), is.finite))

  mat <- model_data |>
    select(
      all_of(y_col), all_of(endogenous_col),
      all_of(instrument_col), all_of(exog_cols)
    ) |>
    as.matrix()

  mat_resid <- demean_two_way(mat, model_data$pair_id, model_data$year)
  y <- mat_resid[, y_col]
  endogenous <- mat_resid[, endogenous_col]
  z <- mat_resid[, c(instrument_col, exog_cols), drop = FALSE]

  qr_z <- qr(z)
  z <- z[, sort(qr_z$pivot[seq_len(qr_z$rank)]), drop = FALSE]
  if (!instrument_col %in% colnames(z)) {
    stop("The excluded instrument is collinear after demeaning")
  }
  exog_cols_kept <- setdiff(colnames(z), instrument_col)

  first_stage <- lm.fit(x = z, y = endogenous)
  endogenous_hat <- as.numeric(z %*% first_stage$coefficients)

  x_hat <- cbind(endogenous_hat, mat_resid[, exog_cols_kept, drop = FALSE])
  colnames(x_hat)[1] <- endogenous_col
  x_structural <- cbind(endogenous, mat_resid[, exog_cols_kept, drop = FALSE])
  colnames(x_structural)[1] <- endogenous_col

  qr_x <- qr(x_hat)
  x_hat <- x_hat[, sort(qr_x$pivot[seq_len(qr_x$rank)]), drop = FALSE]
  x_structural <- x_structural[, colnames(x_hat), drop = FALSE]
  if (!endogenous_col %in% colnames(x_hat)) {
    stop("The fitted endogenous regressor is collinear after demeaning")
  }

  fit <- lm.fit(x = x_hat, y = y)
  coefficients <- fit$coefficients
  residuals <- as.numeric(y - x_structural %*% coefficients)
  fitted_within <- as.numeric(x_structural %*% coefficients)
  rss <- sum(residuals^2)
  tss_within <- sum((y - mean(y))^2)
  within_r_squared <- if (tss_within > 0) 1 - rss / tss_within else NA_real_
  n <- nrow(x_hat)
  fe_rank <- n_distinct(model_data$pair_id) + n_distinct(model_data$year) - 1
  k_total <- length(coefficients) + fe_rank
  df_resid_full <- n - k_total
  n_affiliates <- n_distinct(model_data$affiliate)
  n_parents <- n_distinct(model_data$parent)

  vcov <- cluster_vcov(
    x = x_hat,
    residuals = residuals,
    cluster = model_data$affiliate,
    df_resid_full = df_resid_full
  )
  vcov_two_way <- cluster_vcov_twoway(
    x = x_hat,
    residuals = residuals,
    cluster_a = model_data$parent,
    cluster_b = model_data$affiliate,
    df_resid_full = df_resid_full
  )

  list(
    model_spec = model_spec,
    t0 = t0,
    dependent_variable = y_col,
    endogenous_col = endogenous_col,
    instrument_col = instrument_col,
    x_cols = colnames(x_hat),
    z_cols = colnames(z),
    n = n,
    n_pairs = n_distinct(model_data$pair_id),
    n_affiliates = n_affiliates,
    n_parents = n_parents,
    n_years = n_distinct(model_data$year),
    fe_rank = fe_rank,
    k_total = k_total,
    df_resid_full = df_resid_full,
    rss = rss,
    tss_within = tss_within,
    within_r_squared = within_r_squared,
    coefficients = coefficients,
    vcov = vcov,
    vcov_two_way = vcov_two_way,
    coefficient_table = coefficient_table_from_vcov(
      coefficients = coefficients,
      vcov = vcov,
      model_spec = model_spec,
      t0 = t0,
      n = n,
      n_affiliates = n_affiliates,
      n_parents = n_parents,
      df_resid_full = df_resid_full,
      within_r_squared = within_r_squared,
      dependent_variable = y_col,
      inference = "affiliate_clustered",
      df_inference = max(n_affiliates - 1, 1)
    ),
    coefficient_table_two_way = coefficient_table_from_vcov(
      coefficients = coefficients,
      vcov = vcov_two_way,
      model_spec = model_spec,
      t0 = t0,
      n = n,
      n_affiliates = n_affiliates,
      n_parents = n_parents,
      df_resid_full = df_resid_full,
      within_r_squared = within_r_squared,
      dependent_variable = y_col,
      inference = "parent_affiliate_clustered",
      df_inference = max(min(n_parents, n_affiliates) - 1, 1)
    ),
    residuals = residuals,
    fitted_within = fitted_within,
    model_data = model_data
  )
}

add_affiliate_cit_lag <- function(base_panel) {
  lagged_rates <- base_panel |>
    group_by(affiliate, year) |>
    summarise(
      affiliate_cit_rate_unit_lag1 =
        first_non_missing(affiliate_cit_rate_unit),
      .groups = "drop"
    ) |>
    mutate(year = year + 1L)

  base_panel |>
    left_join(lagged_rates, by = c("affiliate", "year"))
}

build_simulated_tax_code_etr <- function(etr_forward) {
  etr_forward |>
    filter(
      measure == SIMULATED_ETR_MEASURE,
      asset_type == SIMULATED_ETR_TAX_BASIS,
      etr_scenario == SIMULATED_ETR_SCENARIO,
      tax_type == SIMULATED_ETR_TAX_TYPE,
      regime == "_Z"
    ) |>
    transmute(
      affiliate = jurisdiction,
      year,
      affiliate_simulated_eatr_unit = normalise_tax_rate_unit(value)
    ) |>
    group_by(affiliate, year) |>
    summarise(
      affiliate_simulated_eatr_unit =
        first_non_missing(affiliate_simulated_eatr_unit),
      .groups = "drop"
    )
}

add_affiliate_tax_instruments <- function(base_panel, etr_forward = NULL) {
  panel <- add_affiliate_cit_lag(base_panel)

  if (is.null(etr_forward)) {
    return(panel |> mutate(affiliate_simulated_eatr_unit = NA_real_))
  }

  panel |>
    left_join(
      build_simulated_tax_code_etr(etr_forward),
      by = c("affiliate", "year")
    )
}

prepare_estimation_sample <- function(base_panel,
                                      exclude_stale_wages = FALSE,
                                      balanced_pairs_only = FALSE,
                                      exclude_covid_years = FALSE,
                                      etr_forward = NULL) {
  sample <- add_affiliate_tax_instruments(base_panel, etr_forward) |>
    filter(
      year %in% MAIN_YEARS,
      has_behavioral_estimation_inputs,
      analysis_profit_base > 0,
      assets_sbie > 0,
      payroll_sbie > 0,
      affiliate_gdp_pc_usd > 0,
      affiliate_population > 0,
      !is.na(etr_panelai_reg)
    )

  if (exclude_stale_wages) {
    sample <- sample |>
      filter(!coalesce(affiliate_wage_stale_flag, FALSE))
  }

  if (exclude_covid_years) {
    sample <- sample |>
      filter(!year %in% c(2020, 2021))
  }

  sample <- sample |>
    group_by(pair_id) |>
    mutate(pair_years_in_estimation_sample = n_distinct(year)) |>
    ungroup() |>
    filter(pair_years_in_estimation_sample >= MIN_PAIR_YEARS_FOR_FE)

  if (balanced_pairs_only) {
    sample <- sample |>
      filter(pair_years_in_estimation_sample == length(MAIN_YEARS))
  }

  sample |>
    mutate(
      tau_raw = etr_panelai_reg,
      tau = winsorise(tau_raw),
      tau_sq = tau^2,
      log_profit = log(analysis_profit_base),
      log_assets = log(assets_sbie),
      log_payroll = log(payroll_sbie),
      log_gdp_pc = log(affiliate_gdp_pc_usd),
      log_population = log(affiliate_population)
    )
}

estimate_stage3_models <- function(estimation_sample) {
  x_linear <- c("log_assets", "log_payroll", "tau", "log_gdp_pc", "log_population")
  x_quadratic <- c(
    "log_assets", "log_payroll", "tau", "tau_sq",
    "log_gdp_pc", "log_population"
  )

  linear_fit <- fit_fe_ols(estimation_sample, x_linear, "linear")
  quadratic_fit <- fit_fe_ols(estimation_sample, x_quadratic, "quadratic")

  valid_t0_grid <- LOG_T0_GRID[LOG_T0_GRID + min(estimation_sample$tau) > 1e-8]
  if (length(valid_t0_grid) == 0) {
    stop("No valid logarithmic offset remains after ETR winsorisation")
  }

  log_grid <- map(valid_t0_grid, function(t0) {
    grid_sample <- estimation_sample |>
      mutate(log_tau = log(t0 + tau))

    fit_fe_ols(
      grid_sample,
      c(
        "log_assets", "log_payroll", "tau", "log_tau",
        "log_gdp_pc", "log_population"
      ),
      "logarithmic",
      t0 = t0,
      compute_vcov = FALSE
    )
  })

  log_grid_summary <- map_dfr(log_grid, function(fit) {
    tibble(t0 = fit$t0, aic = fit$aic, bic = fit$bic, rss = fit$rss)
  })

  best_t0 <- log_grid_summary |>
    arrange(bic) |>
    slice(1) |>
    pull(t0)

  log_fit <- estimation_sample |>
    mutate(log_tau = log(best_t0 + tau)) |>
    fit_fe_ols(
      x_cols = c(
        "log_assets", "log_payroll", "tau", "log_tau",
        "log_gdp_pc", "log_population"
      ),
      model_spec = "logarithmic",
      t0 = best_t0
    )

  list(
    linear = linear_fit,
    quadratic = quadratic_fit,
    logarithmic = log_fit,
    log_grid = log_grid_summary
  )
}

stage3_gaussian_bic <- function(fit, weights) {
  n <- stats::nobs(fit)
  weighted_variance <- sum(weights * stats::residuals(fit)^2) / n
  minus_twice_log_likelihood <-
    n * (log(2 * pi) + 1 + log(weighted_variance)) - sum(log(weights))
  minus_twice_log_likelihood + (fit$nparams + 1) * log(n)
}

build_stage3_alternative_estimators_diagnostic <- function(estimation_sample, base_panel,
                                                           log_t0 = NULL) {
  if (is.null(log_t0)) {
    log_t0 <- estimate_stage3_models(estimation_sample)$logarithmic$t0
  }

  positive <- base_panel |>
    filter(year %in% MAIN_YEARS, is.finite(analysis_profit_base), analysis_profit_base > 0)

  pair_weights <- positive |>
    group_by(pair_id) |>
    summarise(pair_mean_positive_profit = mean(analysis_profit_base), .groups = "drop")

  weighted_sample <- estimation_sample |>
    left_join(pair_weights, by = "pair_id", relationship = "many-to-one") |>
    mutate(pair_profit_weight = pair_mean_positive_profit / mean(pair_mean_positive_profit))
  stopifnot(all(is.finite(weighted_sample$pair_profit_weight)),
    all(weighted_sample$pair_profit_weight > 0)
  )

  # A cell's accrued-tax ETR is undefined at zero corrected profit. For
  # those rows only, use the affiliate-year ETR from observed positive cells.
  affiliate_year_etr <- positive |>
    group_by(affiliate, year) |>
    summarise(
      zero_profit_etr_proxy = weighted_mean_available(etr_panelai_reg, analysis_profit_base),
      .groups = "drop"
    )
  bounds <- stats::quantile(estimation_sample$tau_raw, ETR_WINSOR_PROBS, names = FALSE)
  expanded_sample <- base_panel |>
    filter(
      year %in% MAIN_YEARS, is.finite(analysis_profit_base), analysis_profit_base >= 0,
      is.finite(assets_sbie), assets_sbie > 0, is.finite(payroll_sbie), payroll_sbie > 0,
      is.finite(affiliate_gdp_pc_usd), affiliate_gdp_pc_usd > 0,
      is.finite(affiliate_population), affiliate_population > 0
    ) |>
    left_join(affiliate_year_etr, by = c("affiliate", "year"), relationship = "many-to-one") |>
    mutate(
      tau_proxy_used = analysis_profit_base == 0 & !is.finite(etr_panelai_reg),
      tau_raw = if_else(tau_proxy_used, zero_profit_etr_proxy, etr_panelai_reg)
    ) |>
    filter(is.finite(tau_raw)) |>
    mutate(
      tau = clamp_interval(tau_raw, bounds[1], bounds[2]),
      tau_sq = tau^2,
      log_assets = log(assets_sbie),
      log_payroll = log(payroll_sbie),
      log_gdp_pc = log(affiliate_gdp_pc_usd),
      log_population = log(affiliate_population)
    )

  samples <- list(
    fe_ols = list(data = estimation_sample, sample = "positive_profit", family = "gaussian"),
    fe_wls = list(data = weighted_sample, sample = "positive_profit", family = "gaussian"),
    fe_ppml_positive = list(
      data = estimation_sample, sample = "positive_profit", family = "poisson"
    ),
    fe_ppml_nonnegative = list(
      data = expanded_sample, sample = "nonnegative_profit", family = "poisson"
    )
  )
  tax_terms <- list(
    linear = "tau", quadratic = c("tau", "tau_sq"), logarithmic = c("tau", "log_tau")
  )
  controls <- c("log_assets", "log_payroll", "log_gdp_pc", "log_population")
  # Match the legacy two-way covariance correction, including the FE rank
  # and each cluster component's own degrees-of-freedom factor.
  cluster_correction <- fixest::ssc(K.fixef = "full", G.df = "conventional")

  map_dfr(names(samples), function(estimator) {
    design <- samples[[estimator]]
    data <- design$data |>
      mutate(log_tau = log(log_t0 + tau))
    map_dfr(names(tax_terms), function(specification) {
      poisson <- design$family == "poisson"
      dependent_variable <- if (poisson) "analysis_profit_base" else "log_profit"
      rhs <- paste(c(controls, tax_terms[[specification]]), collapse = " + ")
      formula <- stats::as.formula(paste(dependent_variable, "~", rhs, "| pair_id + year"))
      fit <- if (poisson) {
        fixest::fepois(formula, data = data, cluster = ~ parent + affiliate,
          ssc = cluster_correction, notes = FALSE
        )
      } else {
        fixest::feols(formula, data = data, cluster = ~ parent + affiliate,
          weights = if (estimator == "fe_wls") ~ pair_profit_weight else NULL,
          ssc = cluster_correction,
          notes = FALSE
        )
      }

      used <- data[fixest::obs(fit), , drop = FALSE]
      # The fixest Gaussian log-likelihood uses unweighted residuals.
      # For WLS, evaluate the Gaussian likelihood with analytic weights.
      bic <- if (poisson) {
        stats::BIC(fit)
      } else {
        weights <- if (estimator == "fe_wls") used$pair_profit_weight else rep(1, nrow(used))
        stage3_gaussian_bic(fit, weights)
      }
      coefs <- stats::coef(fit)
      vcov <- stats::vcov(fit)
      terms <- intersect(c("log_assets", "log_payroll", tax_terms[[specification]]), names(coefs))
      n_parents <- n_distinct(used$parent)
      n_affiliates <- n_distinct(used$affiliate)
      fit_metadata <- list(
        coefficients = coefs, model_spec = specification,
        t0 = if (specification == "logarithmic") log_t0 else NA_real_,
        n = stats::nobs(fit), n_pairs = n_distinct(used$pair_id),
        n_affiliates = n_affiliates, n_parents = n_parents
      )
      coefficient_rows <- tibble(
        statistic_type = "coefficient",
        term = terms,
        tau_eval = NA_real_,
        estimate = unname(coefs[terms]),
        std_error = unname(sqrt(diag(vcov))[terms])
      )
      semi_elasticities <- semielasticity_schedule_one(
        fit_metadata, c(0.05, 0.10, 0.15),
        inference = "parent_affiliate_two_way_clustered",
        vcov = vcov, df_inference = min(n_parents, n_affiliates) - 1L
      ) |>
        transmute(
          statistic_type = "semi_elasticity", term = "negative_log_profit_derivative",
          tau_eval = tau, estimate = semi_elasticity, std_error
        )

      bind_rows(coefficient_rows, semi_elasticities) |>
        mutate(
          estimator = estimator,
          sample = design$sample,
          model_spec = specification,
          dependent_variable = dependent_variable,
          inference = "parent_affiliate_two_way_clustered",
          n = fit_metadata$n,
          n_supplied = nrow(data),
          n_pairs = fit_metadata$n_pairs,
          n_parents = n_parents,
          n_affiliates = n_affiliates,
          n_zero_profit_supplied = sum(data$analysis_profit_base == 0),
          n_zero_profit = sum(used$analysis_profit_base == 0),
          n_tax_proxy = if ("tau_proxy_used" %in% names(used)) sum(used$tau_proxy_used) else 0L,
          bic = bic,
          bic_basis = if (poisson) "poisson_pseudo_likelihood_usd" else "gaussian_log_profit",
          t0 = fit_metadata$t0,
          converged = !isFALSE(fit$convStatus),
          .before = 1
        )
    })
  })
}

model_comparison_table <- function(model_fits) {
  fit_row <- function(fit) {
    tibble(
      model_spec = fit$model_spec,
      n = fit$n,
      n_pairs = fit$n_pairs,
      n_affiliates = fit$n_affiliates,
      rss = fit$rss,
      within_r_squared = fit$within_r_squared,
      aic = fit$aic,
      bic = fit$bic,
      t0 = fit$t0
    )
  }

  bind_rows(
    fit_row(model_fits$linear),
    fit_row(model_fits$quadratic),
    fit_row(model_fits$logarithmic)
  ) |>
    arrange(bic) |>
    mutate(bic_rank = row_number(), delta_bic = bic - min(bic))
}

wald_test_terms <- function(fit, terms, test_label,
                            inference = "affiliate_clustered",
                            vcov = fit$vcov,
                            df_den = max(fit$n_affiliates - 1, 1)) {
  kept_terms <- intersect(terms, names(fit$coefficients))
  q <- length(kept_terms)

  if (q == 0 || is.null(vcov)) {
    return(tibble(
      model_spec = fit$model_spec,
      t0 = fit$t0,
      inference = inference,
      test = test_label,
      terms = paste(terms, collapse = " + "),
      df_num = q,
      df_den = df_den,
      f_statistic = NA_real_,
      chi_square = NA_real_,
      p_value = NA_real_,
      n = fit$n,
      n_pairs = fit$n_pairs,
      n_affiliates = fit$n_affiliates,
      within_r_squared = fit$within_r_squared
    ))
  }

  b <- matrix(as.numeric(fit$coefficients[kept_terms]), ncol = 1)
  v <- vcov[kept_terms, kept_terms, drop = FALSE]
  v_inv_b <- if (qr(v)$rank == ncol(v)) {
    solve(v, b)
  } else {
    matrix(NA_real_, nrow = ncol(v), ncol = 1)
  }
  chi_square <- if (all(is.finite(v_inv_b))) {
    as.numeric(t(b) %*% v_inv_b)
  } else {
    NA_real_
  }
  f_statistic <- if (is.finite(chi_square) && q > 0) chi_square / q else NA_real_
  p_value <- if (is.finite(f_statistic)) {
    stats::pf(f_statistic, q, df_den, lower.tail = FALSE)
  } else {
    NA_real_
  }

  tibble(
    model_spec = fit$model_spec,
    t0 = fit$t0,
    inference = inference,
    test = test_label,
    terms = paste(kept_terms, collapse = " + "),
    df_num = q,
    df_den = df_den,
    f_statistic = f_statistic,
    chi_square = chi_square,
    p_value = p_value,
    n = fit$n,
    n_pairs = fit$n_pairs,
    n_affiliates = fit$n_affiliates,
    within_r_squared = fit$within_r_squared
  )
}

stage3_model_wald_tests <- function(model_fits) {
  bind_rows(
    wald_test_terms(
      model_fits$linear, "tau",
      "cluster_wald_tax_terms"
    ),
    wald_test_terms(
      model_fits$linear,
      "tau",
      "cluster_wald_tax_terms",
      inference = "parent_affiliate_clustered",
      vcov = model_fits$linear$vcov_two_way,
      df_den = max(min(
        model_fits$linear$n_parents,
        model_fits$linear$n_affiliates
      ) - 1, 1)
    ),
    wald_test_terms(
      model_fits$quadratic, c("tau", "tau_sq"),
      "cluster_wald_tax_terms"
    ),
    wald_test_terms(
      model_fits$quadratic,
      c("tau", "tau_sq"),
      "cluster_wald_tax_terms",
      inference = "parent_affiliate_clustered",
      vcov = model_fits$quadratic$vcov_two_way,
      df_den = max(min(
        model_fits$quadratic$n_parents,
        model_fits$quadratic$n_affiliates
      ) - 1, 1)
    ),
    wald_test_terms(
      model_fits$logarithmic, c("tau", "log_tau"),
      "cluster_wald_tax_terms"
    ),
    wald_test_terms(
      model_fits$logarithmic,
      c("tau", "log_tau"),
      "cluster_wald_tax_terms",
      inference = "parent_affiliate_clustered",
      vcov = model_fits$logarithmic$vcov_two_way,
      df_den = max(min(
        model_fits$logarithmic$n_parents,
        model_fits$logarithmic$n_affiliates
      ) - 1, 1)
    )
  )
}

build_single_tax_iv_diagnostics <- function(estimation_sample,
                                            instrument_col,
                                            instrument,
                                            instrument_label,
                                            instrument_note) {
  iv_sample <- estimation_sample |>
    filter(is.finite(.data[[instrument_col]]))
  exog_cols <- c("log_assets", "log_payroll", "log_gdp_pc", "log_population")
  first_stage_cols <- c(instrument_col, exog_cols)

  first_stage <- fit_fe_ols(
    iv_sample,
    x_cols = first_stage_cols,
    model_spec = paste0("first_stage_", instrument),
    y_col = "tau"
  )
  reduced_form <- fit_fe_ols(
    iv_sample,
    x_cols = first_stage_cols,
    model_spec = paste0("reduced_form_", instrument),
    y_col = "log_profit"
  )
  iv_fit <- fit_fe_2sls(
    iv_sample,
    y_col = "log_profit",
    endogenous_col = "tau",
    instrument_col = instrument_col,
    exog_cols = exog_cols,
    model_spec = paste0("linear_2sls_", instrument)
  )

  first_stage_rows <- bind_rows(
    first_stage$coefficient_table,
    first_stage$coefficient_table_two_way
  ) |>
    filter(term == instrument_col) |>
    mutate(
      instrument = instrument,
      instrument_label = instrument_label,
      diagnostic = paste0(instrument, "_first_stage_for_cbcr_etr"),
      f_statistic = statistic^2,
      n_pairs = first_stage$n_pairs,
      note = paste(
        "Excluded-instrument relevance for the FE-2SLS robustness model.",
        instrument_note
      )
    )

  weak_f <- first_stage_rows |>
    select(inference, weak_instrument_f = f_statistic)

  reduced_form_rows <- bind_rows(
    reduced_form$coefficient_table,
    reduced_form$coefficient_table_two_way
  ) |>
    filter(term == instrument_col) |>
    mutate(
      instrument = instrument,
      instrument_label = instrument_label,
      diagnostic = paste0(instrument, "_reduced_form_for_profit"),
      f_statistic = statistic^2,
      n_pairs = reduced_form$n_pairs,
      note = paste(
        "Reduced form sign check for the excluded instrument.",
        instrument_note
      )
    )

  iv_rows <- bind_rows(
    iv_fit$coefficient_table,
    iv_fit$coefficient_table_two_way
  ) |>
    filter(term == "tau") |>
    mutate(
      instrument = instrument,
      instrument_label = instrument_label,
      diagnostic = paste0(instrument, "_2sls_for_profit"),
      f_statistic = statistic^2,
      n_pairs = iv_fit$n_pairs,
      note = paste(
        "Linear FE-2SLS estimate instrumenting CbCR ETR.",
        instrument_note
      )
    )

  bind_rows(first_stage_rows, reduced_form_rows, iv_rows) |>
    left_join(weak_f, by = "inference") |>
    select(
      instrument, instrument_label, diagnostic, model_spec,
      dependent_variable, inference, term, estimate, std_error, statistic,
      f_statistic, weak_instrument_f, p_value, n, n_pairs, n_affiliates,
      n_parents, within_r_squared, note
    )
}

build_tax_endogeneity_diagnostics <- function(estimation_sample) {
  bind_rows(
    build_single_tax_iv_diagnostics(
      estimation_sample,
      instrument_col = "affiliate_simulated_eatr_unit",
      instrument = "simulated_tax_code_eatr",
      instrument_label = "OECD simulated fixed-project EATR",
      instrument_note = paste(
        "Instrument is the current-year OECD forward-looking EATR for a",
        "fixed composite investment project in the affiliate jurisdiction."
      )
    ),
    build_single_tax_iv_diagnostics(
      estimation_sample,
      instrument_col = "affiliate_cit_rate_unit_lag1",
      instrument = "lagged_statutory_cit",
      instrument_label = "Lagged statutory CIT",
      instrument_note = paste(
        "Instrument is the one-year lagged statutory CIT rate of the",
        "affiliate jurisdiction."
      )
    )
  )
}

summarise_tax_instrument_coverage <- function(estimation_sample) {
  instrument_specs <- tribble(
    ~instrument, ~instrument_label, ~instrument_col,
    "simulated_tax_code_eatr", "OECD simulated fixed-project EATR",
    "affiliate_simulated_eatr_unit",
    "lagged_statutory_cit", "Lagged statutory CIT",
    "affiliate_cit_rate_unit_lag1"
  )

  bind_rows(lapply(seq_len(nrow(instrument_specs)), function(i) {
    col <- instrument_specs$instrument_col[i]
    z <- estimation_sample[[col]]
    keep <- is.finite(z)

    tibble(
      instrument = instrument_specs$instrument[i],
      instrument_label = instrument_specs$instrument_label[i],
      estimation_rows = sum(keep),
      estimation_affiliates = n_distinct(estimation_sample$affiliate[keep]),
      estimation_parents = n_distinct(estimation_sample$parent[keep]),
      min_value = min(z[keep], na.rm = TRUE),
      median_value = stats::median(z[keep], na.rm = TRUE),
      max_value = max(z[keep], na.rm = TRUE),
      mean_value = mean(z[keep], na.rm = TRUE),
      sd_value = stats::sd(z[keep], na.rm = TRUE)
    )
  }))
}

semielasticity_schedule_one <- function(fit, tau_grid,
                                        inference = "affiliate_clustered",
                                        vcov = fit$vcov,
                                        df_inference =
                                          max(fit$n_affiliates - 1, 1)) {
  bind_rows(lapply(tau_grid, function(tau_eval) {
    if (fit$model_spec == "linear") {
      terms <- "tau"
      gradient <- c(tau = -1)
      derivative <- fit$coefficients["tau"]
    } else if (fit$model_spec == "quadratic") {
      terms <- c("tau", "tau_sq")
      gradient <- c(tau = -1, tau_sq = -2 * tau_eval)
      derivative <- fit$coefficients["tau"] +
        2 * fit$coefficients["tau_sq"] * tau_eval
    } else if (fit$model_spec == "logarithmic") {
      terms <- c("tau", "log_tau")
      gradient <- c(tau = -1, log_tau = -1 / (fit$t0 + tau_eval))
      derivative <- fit$coefficients["tau"] +
        fit$coefficients["log_tau"] / (fit$t0 + tau_eval)
    } else {
      terms <- character()
      gradient <- numeric()
      derivative <- NA_real_
    }

    estimate <- -as.numeric(derivative)
    v <- vcov[terms, terms, drop = FALSE]
    variance <- as.numeric(t(gradient) %*% v %*% gradient)
    std_error <- sqrt(if_else(variance >= 0, variance, NA_real_))
    statistic <- estimate / std_error
    p_value <- 2 * stats::pt(abs(statistic),
      df = df_inference,
      lower.tail = FALSE
    )

    beta3 <- fit$coefficients["tau"]
    beta4 <- case_when(
      fit$model_spec == "quadratic" ~ fit$coefficients["tau_sq"],
      fit$model_spec == "logarithmic" ~ fit$coefficients["log_tau"],
      TRUE ~ NA_real_
    )
    ratio <- counterfactual_profit_ratio(
      tau = tau_eval,
      model_spec = fit$model_spec,
      beta3 = beta3,
      beta4 = beta4,
      t0 = fit$t0
    )

    tibble(
      model_spec = fit$model_spec,
      t0 = fit$t0,
      inference = inference,
      tau = tau_eval,
      semi_elasticity = estimate,
      std_error = std_error,
      statistic = statistic,
      p_value = p_value,
      negative_variance_flag = variance < 0,
      counterfactual_profit_ratio_to_15 = ratio,
      reallocation_share_to_15 = 1 - ratio,
      n = fit$n,
      n_pairs = fit$n_pairs,
      n_affiliates = fit$n_affiliates,
      n_parents = fit$n_parents,
      df_inference = df_inference
    )
  }))
}

stage3_semielasticity_schedule <- function(model_fits,
                                           tau_grid = c(0.05, 0.10, 0.15, 0.30)) {
  bind_rows(lapply(
    model_fits[c("linear", "quadratic", "logarithmic")],
    function(fit) {
      bind_rows(
        semielasticity_schedule_one(
          fit,
          tau_grid,
          inference = "affiliate_clustered",
          vcov = fit$vcov,
          df_inference = max(fit$n_affiliates - 1, 1)
        ),
        semielasticity_schedule_one(
          fit,
          tau_grid,
          inference = "parent_affiliate_clustered",
          vcov = fit$vcov_two_way,
          df_inference = max(min(fit$n_parents, fit$n_affiliates) - 1, 1)
        )
      )
    }
  ))
}

build_model_diagnostics <- function(model_fits, sample_name) {
  wald <- stage3_model_wald_tests(model_fits)

  model_comparison_table(model_fits) |>
    left_join(
      wald |>
        filter(inference == "affiliate_clustered") |>
        select(model_spec,
          tax_terms_joint_f = f_statistic,
          tax_terms_joint_p_value = p_value
        ),
      by = "model_spec"
    ) |>
    left_join(
      wald |>
        filter(inference == "parent_affiliate_clustered") |>
        select(model_spec,
          tax_terms_joint_f_two_way = f_statistic,
          tax_terms_joint_p_value_two_way = p_value
        ),
      by = "model_spec"
    ) |>
    mutate(sample = sample_name, .before = model_spec)
}

estimate_robustness_model_diagnostics <- function(samples) {
  bind_rows(lapply(names(samples), function(sample_name) {
    fits <- estimate_stage3_models(samples[[sample_name]])
    build_model_diagnostics(fits, sample_name)
  }))
}

vuong_test <- function(fit_a, fit_b, label_a, label_b) {
  sigma2_a <- fit_a$rss / fit_a$n
  sigma2_b <- fit_b$rss / fit_b$n
  ll_a <- -0.5 * (log(2 * pi * sigma2_a) + fit_a$residuals^2 / sigma2_a)
  ll_b <- -0.5 * (log(2 * pi * sigma2_b) + fit_b$residuals^2 / sigma2_b)
  diff <- ll_a - ll_b
  statistic <- sqrt(length(diff)) * mean(diff) / stats::sd(diff)

  tibble(
    test = "vuong_gaussian_observation_ll",
    model_a = label_a,
    model_b = label_b,
    statistic = statistic,
    p_value = 2 * stats::pnorm(abs(statistic), lower.tail = FALSE),
    mean_loglik_diff = mean(diff),
    interpretation = case_when(
      statistic > 0 ~ paste(label_a, "favoured"),
      statistic < 0 ~ paste(label_b, "favoured"),
      TRUE ~ "tie"
    )
  )
}

clarke_test <- function(fit_a, fit_b, label_a, label_b) {
  sigma2_a <- fit_a$rss / fit_a$n
  sigma2_b <- fit_b$rss / fit_b$n
  ll_a <- -0.5 * (log(2 * pi * sigma2_a) + fit_a$residuals^2 / sigma2_a)
  ll_b <- -0.5 * (log(2 * pi * sigma2_b) + fit_b$residuals^2 / sigma2_b)
  diff <- ll_a - ll_b
  non_ties <- is.finite(diff) & diff != 0
  wins_a <- sum(diff[non_ties] > 0)
  n <- sum(non_ties)
  if (n > 0) {
    bt <- stats::binom.test(wins_a, n, p = 0.5)
    p_value <- bt$p.value
  } else {
    p_value <- NA_real_
  }

  tibble(
    test = "clarke_sign",
    model_a = label_a,
    model_b = label_b,
    statistic = wins_a,
    p_value = p_value,
    mean_loglik_diff = mean(diff),
    interpretation = if_else(wins_a > n / 2,
      paste(label_a, "favoured"),
      paste(label_b, "favoured")
    )
  )
}

j_test <- function(data, current_x_cols, alternative_fit,
                   current_label, alternative_label) {
  keys <- c("pair_id", "year")
  assert_unique_keys(data, keys, "J-test current data")
  alternative <- alternative_fit$model_data |>
    select(all_of(keys)) |>
    mutate(alternative_fitted_within = alternative_fit$fitted_within)
  assert_unique_keys(alternative, keys, "J-test alternative fitted values")
  stopifnot(!anyNA(data[keys]), !anyNA(alternative[keys]))
  # Keep the current ordering for the within estimator. A row missing from
  # the alternative fit receives NA and drops out of the common fit sample.
  j_data <- data |>
    left_join(alternative, by = keys, relationship = "one-to-one")

  fit <- fit_fe_ols(
    j_data,
    c(current_x_cols, "alternative_fitted_within"),
    paste0("j_", current_label, "_against_", alternative_label)
  )

  fit$coefficient_table |>
    filter(term == "alternative_fitted_within") |>
    transmute(
      test = "davidson_mackinnon_j",
      model_a = current_label,
      model_b = alternative_label,
      statistic,
      p_value,
      mean_loglik_diff = NA_real_,
      interpretation = paste("alternative fitted value in", current_label)
    )
}

run_specification_tests <- function(estimation_sample, model_fits) {
  bind_rows(
    vuong_test(
      model_fits$logarithmic, model_fits$quadratic,
      "logarithmic", "quadratic"
    ),
    clarke_test(
      model_fits$logarithmic, model_fits$quadratic,
      "logarithmic", "quadratic"
    ),
    j_test(
      estimation_sample |> mutate(log_tau = log(model_fits$logarithmic$t0 + tau)),
      c(
        "log_assets", "log_payroll", "tau", "tau_sq",
        "log_gdp_pc", "log_population"
      ),
      model_fits$logarithmic,
      "quadratic",
      "logarithmic"
    ),
    j_test(
      estimation_sample |> mutate(log_tau = log(model_fits$logarithmic$t0 + tau)),
      c(
        "log_assets", "log_payroll", "tau", "log_tau",
        "log_gdp_pc", "log_population"
      ),
      model_fits$quadratic,
      "logarithmic",
      "quadratic"
    )
  )
}

counterfactual_profit_ratio <- function(tau, model_spec, beta3,
                                        beta4 = NA_real_, t0 = NA_real_,
                                        threshold = GMT_RATE) {
  tau <- pmin(pmax(tau, 0), threshold)

  exponent <- case_when(
    model_spec == "linear" ~
      beta3 * (threshold - tau),
    model_spec == "quadratic" ~
      beta3 * (threshold - tau) + beta4 * (threshold^2 - tau^2),
    model_spec == "logarithmic" ~
      beta3 * (threshold - tau) +
      beta4 * (log(t0 + threshold) - log(t0 + tau)),
    TRUE ~ NA_real_
  )

  clamp_unit_interval(exp(exponent))
}

compute_reallocation_share <- function(tau, model_spec, beta3,
                                       beta4 = NA_real_, t0 = NA_real_,
                                       threshold = GMT_RATE) {
  1 - counterfactual_profit_ratio(tau, model_spec, beta3, beta4, t0, threshold)
}

apply_behavioural_regime <- function(tau_low, beta_raw,
                                     threshold = GMT_RATE,
                                     eta = SESH_BANDWIDTH_BASELINE) {
  in_band <- !is.na(tau_low) & tau_low >= threshold - eta & tau_low < threshold
  below_band <- !is.na(tau_low) & tau_low < threshold - eta
  beta_applied <- if_else(below_band, clamp_unit_interval(beta_raw), 0)

  tibble(
    beta_applied = beta_applied,
    behavioural_liability_filter = case_when(
      in_band ~ 0,
      below_band ~ 1 - beta_applied,
      TRUE ~ 1
    ),
    behavioural_regime = case_when(
      in_band ~ "sesh_bunching_topup_zero",
      below_band ~ "semi_elasticity_reallocation",
      TRUE ~ "no_low_tax_response"
    )
  )
}

extract_tax_coefficients <- function(model_fits) {
  bind_rows(
    model_fits$linear$coefficient_table |>
      filter(term == "tau") |>
      transmute(model_spec, t0, beta3 = estimate, beta4 = NA_real_),
    model_fits$quadratic$coefficient_table |>
      summarise(
        model_spec = "quadratic",
        t0 = NA_real_,
        beta3 = estimate[term == "tau"],
        beta4 = estimate[term == "tau_sq"],
        .groups = "drop"
      ),
    model_fits$logarithmic$coefficient_table |>
      summarise(
        model_spec = "logarithmic",
        t0 = first(t0),
        beta3 = estimate[term == "tau"],
        beta4 = estimate[term == "log_tau"],
        .groups = "drop"
      )
  )
}

build_behavioural_affiliate_year <- function(stage1_affiliate_year,
                                             model_fits) {
  tax_coefficients <- extract_tax_coefficients(model_fits)

  behavioural_base <- stage1_affiliate_year |>
    filter(year %in% MAIN_YEARS, stage1_positive_profit_flag) |>
    select(
      affiliate, affiliate_name, affiliate_is_eu27, year,
      total_analysis_profit_positive,
      average_low_share, average_topup_rate,
      stage1_distributional_low_share, stage1_distributional_topup_rate,
      stage1_distributional_low_share_strict,
      stage1_distributional_topup_rate_strict
    ) |>
    pivot_longer(
      cols = c(
        average_low_share, stage1_distributional_low_share,
        stage1_distributional_low_share_strict
      ),
      names_to = "low_share_measure",
      values_to = "stage1_low_share"
    ) |>
    mutate(
      etr_measurement = case_when(
        low_share_measure == "average_low_share" ~ "average",
        low_share_measure == "stage1_distributional_low_share" ~ "distributional",
        TRUE ~ "distributional_strict"
      ),
      stage1_topup_rate = case_when(
        etr_measurement == "average" ~ average_topup_rate,
        etr_measurement == "distributional" ~ stage1_distributional_topup_rate,
        TRUE ~ stage1_distributional_topup_rate_strict
      )
    ) |>
    select(
      -low_share_measure, -average_topup_rate,
      -stage1_distributional_topup_rate,
      -stage1_distributional_topup_rate_strict
    ) |>
    tidyr::crossing(tax_coefficients, tibble(eta = SESH_BANDWIDTH_SENSITIVITY)) |>
    mutate(
      tau_low = if_else(
        stage1_low_share > 0 & stage1_topup_rate > 0,
        GMT_RATE - stage1_topup_rate,
        NA_real_
      ),
      beta_raw = if_else(
        !is.na(tau_low),
        compute_reallocation_share(
          tau = tau_low,
          model_spec = model_spec,
          beta3 = beta3,
          beta4 = beta4,
          t0 = t0
        ),
        0
      ),
      beta_sign_restricted_flag = beta_raw < 0 | beta_raw > 1,
      beta_raw = clamp_unit_interval(beta_raw)
    )

  bind_cols(
    behavioural_base,
    apply_behavioural_regime(
      tau_low = behavioural_base$tau_low,
      beta_raw = behavioural_base$beta_raw,
      eta = behavioural_base$eta
    )
  )
}

build_policy_flags <- function(oecd_central_record) {
  oecd_central_record |>
    filter(rule_type %in% c("qualified_iir", "qualified_qdmtt", "qualified_sbs")) |>
    group_by(jurisdiction, jurisdiction_name) |>
    summarise(
      qdmtt_start = min_date_or_na(effective_date[rule_type == "qualified_qdmtt"]),
      iir_start = min_date_or_na(effective_date[rule_type == "qualified_iir"]),
      sbs_start = min_date_or_na(effective_date[rule_type == "qualified_sbs"]),
      qdmtt_rule_rows = sum(rule_type == "qualified_qdmtt", na.rm = TRUE),
      iir_rule_rows = sum(rule_type == "qualified_iir", na.rm = TRUE),
      sbs_rule_rows = sum(rule_type == "qualified_sbs", na.rm = TRUE),
      qdmtt_table_current_as =
        min_date_or_na(table_current_as[rule_type == "qualified_qdmtt"]),
      iir_table_current_as =
        min_date_or_na(table_current_as[rule_type == "qualified_iir"]),
      sbs_table_current_as =
        min_date_or_na(table_current_as[rule_type == "qualified_sbs"]),
      .groups = "drop"
    ) |>
    mutate(
      qdmtt_by_2026 =
        !is.na(qdmtt_start) & qdmtt_start <= as.Date("2026-01-01"),
      iir_by_2026 =
        !is.na(iir_start) & iir_start <= as.Date("2026-01-01"),
      sbs_by_2026 =
        !is.na(sbs_start) & sbs_start <= as.Date("2026-01-01"),
      iir_utpr_start = iir_start,
      utpr_start = iir_start,
      iir_utpr_by_2026 = iir_by_2026,
      utpr_by_2026 = iir_by_2026,
      iir_utpr_explicit_start = iir_start,
      iir_utpr_explicit_by_2026 = iir_by_2026,
      broad_topup_start = as.Date(NA),
      broad_topup_by_2026 = FALSE,
      iir_utpr_ambiguous_by_2026 = FALSE,
      iir_utpr_rule_rows = iir_rule_rows,
      iir_explicit_rule_rows = iir_rule_rows,
      utpr_explicit_rule_rows = NA_integer_,
      broad_topup_rule_rows = 0L
    )
}

build_eu27_legal_regime_classification <- function(oecd_central_record) {
  snapshot_date <- as.Date("2026-05-01")
  snapshot <- oecd_central_record |>
    filter(table_current_as == snapshot_date, rule_type %in% c("qualified_iir", "qualified_qdmtt"))
  if (nrow(snapshot) == 0) stop("Missing 1 May 2026 OECD IIR and QDMTT snapshot")

  qualified <- build_policy_flags(snapshot) |>
    select(jurisdiction, qdmtt_by_2026, iir_by_2026, qdmtt_rule_rows, iir_rule_rows,
      qdmtt_start, iir_start
    )
  article50 <- c("EST", "LTU", "LVA", "MLT", "SVK")

  tibble(jurisdiction = EU27_ISO3) |>
    left_join(qualified, by = "jurisdiction", relationship = "one-to-one") |>
    mutate(
      central_record_snapshot = snapshot_date,
      qdmtt_by_2026 = coalesce(qdmtt_by_2026, FALSE),
      iir_by_2026 = coalesce(iir_by_2026, FALSE),
      qdmtt_listed = coalesce(qdmtt_rule_rows, 0L) > 0,
      iir_listed = coalesce(iir_rule_rows, 0L) > 0,
      article50_iir_utpr_deferral = jurisdiction %in% article50,
      domestic_topup_tax_enacted = case_when(
        jurisdiction == "CYP" | qdmtt_listed ~ TRUE,
        article50_iir_utpr_deferral & jurisdiction != "SVK" ~ FALSE,
        TRUE ~ NA
      ),
      domestic_topup_tax_start = if_else(
        jurisdiction == "CYP", as.Date("2024-12-31"), qdmtt_start
      ),
      domestic_iir_start = if_else(jurisdiction == "CYP", as.Date("2023-12-31"), iir_start),
      domestic_enactment_summary = case_when(
        jurisdiction == "CYP" ~ paste(
          "Law 151(I)/2024 enacted IIR and domestic top-up tax.",
          "Neither rule is listed in the pinned OECD snapshot."
        ),
        jurisdiction == "SVK" ~ "Domestic top-up tax enacted and listed. Article 50 defers IIR and UTPR.",
        article50_iir_utpr_deferral ~ "Article 50 deferral of IIR and UTPR. No domestic top-up tax in the snapshot period.",
        qdmtt_listed & iir_listed ~ "Domestic top-up tax and IIR enacted and listed.",
        TRUE ~ "Domestic enactment not verified"
      ),
      article50_source = "https://eur-lex.europa.eu/eli/C/2023/1536/oj/eng",
      qualification_source = paste0(
        "https://www.oecd.org/en/topics/sub-issues/global-minimum-tax/",
        "central-record-of-legislation-with-transitional-qualified-status.html"
      ),
      domestic_source = case_when(
        jurisdiction == "CYP" ~ paste0(
          "https://www.gov.cy/mof-tax/documents/",
          "elachisto-pragmatiko-pagkosmio-epipedo-forologias-pillar-ii/"
        ),
        article50_iir_utpr_deferral ~ paste0(
          "https://www.oecd.org/en/publications/tax-policy-reforms-2026_43d18a55-en/",
          "full-report/tax-policy-reforms_82075677.html"
        ),
        TRUE ~ qualification_source
      )
    ) |>
    select(-qdmtt_rule_rows, -iir_rule_rows)
}

build_policy_tracker_diagnostics <- function(oecd_central_record) {
  oecd_central_record |>
    count(
      rule_type,
      table_current_as,
      qdmtt_safe_harbour,
      name = "rows"
    ) |>
    arrange(rule_type, table_current_as)
}

build_sectoral_factor2_bridge <- function(stage2_bilateral,
                                          stage1_affiliate_year,
                                          stage2_sectoral_matrix,
                                          use_contemporaneous = TRUE) {
  keys <- c("rate_scenario", "affiliate", "year")
  aggregate_rates <- stage2_bilateral |>
    filter(affiliate_is_eu27, analysis_profit_positive > 0) |>
    group_by(rate_scenario, affiliate, year) |>
    summarise(
      aggregate_profit = sum(analysis_profit_positive),
      aggregate_tax_per_profit_average =
        sum(stage2_topup_tax_average, na.rm = TRUE) / aggregate_profit,
      aggregate_tax_per_profit_distributional =
        sum(stage2_topup_tax_distributional, na.rm = TRUE) / aggregate_profit,
      .groups = "drop"
    )

  sectoral_rates <- summarise_sectoral_sbie_rates(stage2_sectoral_matrix, stage1_affiliate_year) |>
    rename(
      sectoral_tax_per_profit_average = sectoral_sbie_sbti_per_profit_average,
      sectoral_tax_per_profit_distributional = sectoral_sbie_sbti_per_profit_distributional
    )
  scales <- aggregate_rates |>
    left_join(sectoral_rates, by = keys, relationship = "one-to-one") |>
    mutate(
      sectoral_scale_same_year_average = safe_divide(
        sectoral_tax_per_profit_average, aggregate_tax_per_profit_average
      ),
      sectoral_scale_same_year_distributional = safe_divide(
        sectoral_tax_per_profit_distributional, aggregate_tax_per_profit_distributional
      )
    )
  reference <- scales |>
    filter(year == SECTORAL_REFERENCE_YEAR) |>
    transmute(
      rate_scenario, affiliate,
      sectoral_scale_reference_average = sectoral_scale_same_year_average,
      sectoral_scale_reference_distributional = sectoral_scale_same_year_distributional
    )

  bridge <- scales |>
    left_join(reference, by = c("rate_scenario", "affiliate"), relationship = "many-to-one") |>
    mutate(
      sectoral_scale_static_average = coalesce(sectoral_scale_reference_average, 1),
      sectoral_scale_static_distributional = coalesce(sectoral_scale_reference_distributional, 1),
      sectoral_scale_average = if (use_contemporaneous) {
        coalesce(sectoral_scale_same_year_average, sectoral_scale_static_average)
      } else {
        sectoral_scale_static_average
      },
      sectoral_scale_distributional = if (use_contemporaneous) {
        coalesce(sectoral_scale_same_year_distributional, sectoral_scale_static_distributional)
      } else {
        sectoral_scale_static_distributional
      },
      sectoral_scale_source_average = case_when(
        use_contemporaneous & is.finite(sectoral_scale_same_year_average) ~ "contemporaneous",
        is.finite(sectoral_scale_reference_average) ~ "reference_2022",
        TRUE ~ "neutral"
      ),
      sectoral_scale_source_distributional = case_when(
        use_contemporaneous & is.finite(sectoral_scale_same_year_distributional) ~ "contemporaneous",
        is.finite(sectoral_scale_reference_distributional) ~ "reference_2022",
        TRUE ~ "neutral"
      )
    )
  assert_unique_keys(bridge, keys, "Stage 3 sectoral bridge")
  bridge
}

summarise_sectoral_bridge_comparison <- function(bridge) {
  bridge |>
    filter(year %in% SECTORAL_PANEL_YEARS) |>
    select(
      rate_scenario, affiliate, year, aggregate_profit,
      starts_with("aggregate_tax_per_profit_"), sectoral_scale_average,
      sectoral_scale_distributional, starts_with("sectoral_scale_static_"),
      starts_with("sectoral_scale_source_")
    ) |>
    pivot_longer(
      ends_with("_average") | ends_with("_distributional"),
      names_to = c(".value", "etr_measurement"),
      names_pattern = "(.+)_(average|distributional)"
    ) |>
    group_by(year, rate_scenario, etr_measurement) |>
    summarise(
      affiliates = n(),
      contemporaneous_affiliates = sum(sectoral_scale_source == "contemporaneous"),
      aggregate_topup = sum(aggregate_profit * aggregate_tax_per_profit),
      static_2022_topup = sum(aggregate_profit * aggregate_tax_per_profit * sectoral_scale_static),
      contemporaneous_topup = sum(aggregate_profit * aggregate_tax_per_profit * sectoral_scale),
      difference = contemporaneous_topup - static_2022_topup,
      .groups = "drop"
    )
}

add_behavioural_response <- function(scenario_panel) {
  scenario_panel |>
    mutate(
      selected_low_share = if_else(
        factor1_etr == "average",
        average_low_share,
        stage1_distributional_low_share
      ),
      stage2_excess_lowtax_profit_selected = if_else(
        factor1_etr == "average",
        stage2_excess_lowtax_profit_average,
        stage2_excess_lowtax_profit_distributional
      ),
      stage2_lowtax_profit_selected = if_else(
        factor1_etr == "average",
        stage1_lowtax_profit_average,
        stage1_lowtax_profit_distributional
      ),
      post_sbie_topup_rate = safe_divide(
        topup_after_stage2,
        stage2_excess_lowtax_profit_selected
      ),
      post_gmt_tax_gap_relative = clamp_unit_interval(
        safe_divide(post_sbie_topup_rate, GMT_RATE)
      ),
      ip_holding_count = coalesce_zero(act_ip_panelai) +
        coalesce_zero(act_holding_panelai) + coalesce_zero(act_igf_panelai),
      profit_per_employee = safe_divide(
        analysis_profit_positive,
        pmax(coalesce_zero(employees_sbie), 1)
      ),
      profit_to_assets = safe_divide(
        analysis_profit_positive,
        pmax(coalesce_zero(assets_sbie), 1)
      ),
      low_substance_score = clamp_unit_interval(1 - coalesce(stage2_phi, 0)),
      substance_anchor_score = clamp_unit_interval(coalesce(stage2_phi, 0)),
      conduit_haven_score = as.numeric(coalesce(affiliate_is_conduit_haven, FALSE))
    ) |>
    group_by(year, scenario_id) |>
    mutate(
      ip_holding_score = rank01(log1p(ip_holding_count)),
      profit_per_employee_score = rank01(log1p(pmax(profit_per_employee, 0))),
      profit_to_assets_score = rank01(log1p(pmax(profit_to_assets, 0)))
    ) |>
    ungroup() |>
    mutate(
      policy_collection_exposure = case_when(
        qdmtt_flag ~ 1,
        sbs_exempt & !qdmtt_flag ~ 0,
        TRUE ~ 1
      ),
      diagnostic_planning_intensity = 1,
      strategic_response_eligible =
        factor5_behaviour == "behavioural" &
          static_behavioural_regime == "semi_elasticity_reallocation" &
          topup_after_stage2 > 0 &
          coalesce(stage2_excess_lowtax_profit_selected, 0) > 0,
      strategic_beta_applied = if_else(
        strategic_response_eligible,
        pmin(
          static_beta_applied * policy_collection_exposure,
          BEHAVIOURAL_MAX_REALLOCATION_SHARE
        ),
        0
      ),
      behavioural_liability_filter = case_when(
        factor5_behaviour == "mechanical" ~ 1,
        static_behavioural_regime == "sesh_bunching_topup_zero" ~ 0,
        strategic_response_eligible ~ 1 - strategic_beta_applied,
        TRUE ~ 1
      ),
      beta_applied = if_else(
        factor5_behaviour == "behavioural",
        strategic_beta_applied,
        0
      ),
      behavioural_regime = case_when(
        factor5_behaviour == "mechanical" ~ "mechanical",
        static_behavioural_regime == "sesh_bunching_topup_zero" ~
          "sesh_bunching_topup_zero",
        strategic_response_eligible ~ "semi_elasticity_reallocation",
        factor5_behaviour == "behavioural" ~ "no_low_tax_response",
        TRUE ~ "mechanical"
      ),
      topup_after_behaviour = pmax(
        topup_after_stage2 * behavioural_liability_filter,
        0
      ),
      behavioural_avoided_topup = pmax(
        topup_after_stage2 - topup_after_behaviour,
        0
      ),
      reallocated_profit = if_else(
        strategic_response_eligible,
        pmax(stage2_excess_lowtax_profit_selected, 0) *
          strategic_beta_applied,
        0
      ),
      tp_ip_channel_raw = DIAGNOSTIC_CHANNEL_PRIOR_TP_IP,
      debt_channel_raw = DIAGNOSTIC_CHANNEL_PRIOR_DEBT,
      substance_channel_raw = DIAGNOSTIC_CHANNEL_PRIOR_SUBSTANCE,
      behavioural_channel_total =
        tp_ip_channel_raw + debt_channel_raw + substance_channel_raw,
      channel_transfer_pricing_ip_share =
        tp_ip_channel_raw / behavioural_channel_total,
      channel_debt_share = debt_channel_raw / behavioural_channel_total,
      channel_substance_planning_share =
        substance_channel_raw / behavioural_channel_total,
      reallocated_profit_transfer_pricing_ip =
        reallocated_profit * channel_transfer_pricing_ip_share,
      reallocated_profit_debt = reallocated_profit * channel_debt_share,
      reallocated_profit_substance_planning =
        reallocated_profit * channel_substance_planning_share
    )
}

build_factorial_revenue <- function(stage2_bilateral,
                                    behavioural_affiliate_year,
                                    sectoral_bridge,
                                    policy_flags,
                                    preferred_model) {
  scenario_design <- tidyr::expand_grid(
    rate_scenario = c("initial", "long_run"),
    factor1_etr = c("average", "distributional"),
    factor2_substance = c("aggregate_sbie", "sectoral_sbie_sbti"),
    factor4_sbs = c("universal", "sbs"),
    factor5_behaviour = c("mechanical", "behavioural")
  ) |>
    mutate(
      factor3_rates = rate_scenario,
      x1_etr = as.integer(factor1_etr == "distributional"),
      x2_substance = as.integer(factor2_substance == "sectoral_sbie_sbti"),
      x3_rates = as.integer(rate_scenario == "long_run"),
      x4_sbs = as.integer(factor4_sbs == "sbs"),
      x5_behaviour = as.integer(factor5_behaviour == "behavioural"),
      scenario_id = paste0(
        "x", x1_etr, x2_substance, x3_rates, x4_sbs,
        x5_behaviour
      )
    )

  behaviour_preferred <- behavioural_affiliate_year |>
    filter(
      model_spec == preferred_model,
      eta == SESH_BANDWIDTH_BASELINE,
      etr_measurement %in% c("average", "distributional")
    ) |>
    select(
      affiliate, year, etr_measurement,
      static_tau_low = tau_low,
      static_beta_raw = beta_raw,
      static_beta_applied = beta_applied,
      static_behavioural_liability_filter = behavioural_liability_filter,
      static_behavioural_regime = behavioural_regime
    )

  policy_affiliate <- policy_flags |>
    select(
      affiliate = jurisdiction,
      affiliate_policy_qdmtt_by_2026 = qdmtt_by_2026,
      affiliate_policy_iir_utpr_by_2026 = iir_utpr_by_2026,
      affiliate_policy_iir_by_2026 = iir_by_2026,
      affiliate_policy_utpr_by_2026 = utpr_by_2026,
      affiliate_policy_iir_utpr_explicit_by_2026 =
        iir_utpr_explicit_by_2026,
      affiliate_policy_iir_utpr_ambiguous_by_2026 =
        iir_utpr_ambiguous_by_2026
    )

  policy_parent <- policy_flags |>
    select(
      parent = jurisdiction,
      parent_policy_iir_utpr_by_2026 = iir_utpr_by_2026,
      parent_policy_iir_by_2026 = iir_by_2026,
      parent_policy_utpr_by_2026 = utpr_by_2026,
      parent_policy_sbs_by_2026 = sbs_by_2026,
      parent_policy_iir_utpr_explicit_by_2026 =
        iir_utpr_explicit_by_2026,
      parent_policy_iir_utpr_ambiguous_by_2026 =
        iir_utpr_ambiguous_by_2026
    )

  scenario_panel <- stage2_bilateral |>
    inner_join(scenario_design,
      by = "rate_scenario",
      relationship = "many-to-many"
    ) |>
    left_join(
      sectoral_bridge |>
        select(
          rate_scenario, affiliate, year,
          sectoral_scale_average, sectoral_scale_distributional
        ),
      by = c("rate_scenario", "affiliate", "year"),
      relationship = "many-to-one"
    ) |>
    left_join(policy_affiliate, by = "affiliate") |>
    left_join(policy_parent, by = "parent") |>
    left_join(
      behaviour_preferred,
      by = c("affiliate", "year", "factor1_etr" = "etr_measurement")
    ) |>
    mutate(
      stage2_topup_selected = if_else(
        factor1_etr == "average",
        stage2_topup_tax_average,
        stage2_topup_tax_distributional
      ),
      sectoral_scale_selected = case_when(
        factor2_substance == "aggregate_sbie" ~ 1,
        factor1_etr == "average" ~ coalesce(sectoral_scale_average, 1),
        TRUE ~ coalesce(sectoral_scale_distributional, 1)
      ),
      topup_after_stage2 = pmax(stage2_topup_selected * sectoral_scale_selected, 0),
      static_tau_low = coalesce(static_tau_low, NA_real_),
      static_beta_raw = coalesce(static_beta_raw, 0),
      static_beta_applied = coalesce(static_beta_applied, 0),
      static_behavioural_liability_filter =
        coalesce(static_behavioural_liability_filter, 1),
      static_behavioural_regime =
        coalesce(static_behavioural_regime, "no_low_tax_response"),
      qdmtt_flag = coalesce(affiliate_policy_qdmtt_by_2026, FALSE),
      parent_iir_utpr_flag = coalesce(parent_policy_iir_utpr_by_2026, FALSE),
      parent_iir_utpr_explicit_flag = coalesce(
        parent_policy_iir_utpr_explicit_by_2026,
        FALSE
      ),
      parent_iir_utpr_ambiguous_flag =
        parent_iir_utpr_flag & !parent_iir_utpr_explicit_flag,
      sbs_parent_qualified = coalesce(parent_policy_sbs_by_2026, FALSE),
      sbs_exempt = factor4_sbs == "sbs" & sbs_parent_qualified
    ) |>
    add_behavioural_response() |>
    mutate(
      qdmtt_topup = if_else(qdmtt_flag, topup_after_behaviour, 0),
      iir_topup = if_else(!qdmtt_flag & parent_iir_utpr_flag & !sbs_exempt,
        topup_after_behaviour, 0
      ),
      utpr_source_proxy_topup = if_else(
        !qdmtt_flag & !parent_iir_utpr_flag & !sbs_exempt,
        topup_after_behaviour,
        0
      ),
      sbs_extinguished_topup = if_else(
        !qdmtt_flag & sbs_exempt,
        topup_after_behaviour,
        0
      )
    )

  if (any(scenario_panel$topup_after_behaviour < -1e-8, na.rm = TRUE)) {
    stop("Stage 3 produced negative post-behaviour top-up tax")
  }

  qdmtt_revenue <- scenario_panel |>
    filter(affiliate %in% EU27_ISO3) |>
    transmute(
      across(all_of(SCENARIO_VARS)),
      year,
      country = affiliate,
      channel = "QDMTT",
      revenue = qdmtt_topup
    )

  iir_revenue <- scenario_panel |>
    filter(parent %in% EU27_ISO3) |>
    transmute(
      across(all_of(SCENARIO_VARS)),
      year,
      country = parent,
      channel = "IIR",
      revenue = iir_topup
    )

  # This is UTPR assigned to the source, not to actual proxy collectors.
  # stage3_revenue_country_year.rds and step5_stage3_anova_pooled.csv retain
  # this historical diagnostic. The Stage 4.5 waterfall is the collector result.
  utpr_revenue <- scenario_panel |>
    filter(affiliate %in% EU27_ISO3) |>
    transmute(
      across(all_of(SCENARIO_VARS)),
      year,
      country = affiliate,
      channel = "UTPR_source_proxy",
      revenue = utpr_source_proxy_topup
    )

  channel_revenue <- bind_rows(qdmtt_revenue, iir_revenue, utpr_revenue) |>
    group_by(across(all_of(SCENARIO_VARS)), country, year, channel) |>
    summarise(revenue = sum(revenue, na.rm = TRUE), .groups = "drop")

  country_lookup <- stage2_bilateral |>
    filter(affiliate %in% EU27_ISO3) |>
    distinct(
      country = affiliate,
      country_name = affiliate_jurisdiction_name
    )

  scenario_country_year <- channel_revenue |>
    group_by(across(all_of(SCENARIO_VARS)), country, year) |>
    summarise(revenue = sum(revenue, na.rm = TRUE), .groups = "drop") |>
    complete(
      nesting(!!!syms(SCENARIO_VARS)),
      country = EU27_ISO3,
      year = MAIN_YEARS,
      fill = list(revenue = 0)
    ) |>
    left_join(country_lookup, by = "country") |>
    relocate(country_name, .after = country)

  scenario_summary <- scenario_country_year |>
    group_by(across(all_of(SCENARIO_VARS))) |>
    summarise(
      eu_revenue = sum(revenue, na.rm = TRUE),
      country_years = n(),
      .groups = "drop"
    ) |>
    arrange(scenario_id)

  list(
    scenario_panel = scenario_panel,
    channel_revenue = channel_revenue,
    country_year_revenue = scenario_country_year,
    scenario_summary = scenario_summary
  )
}

compute_stage3_factorial_effects_one <- function(df) {
  components <- factorial_binary_components(df)
  coefs <- components$coefs
  total_ss <- components$total_ss

  tibble(
    effect = names(coefs),
    ss = components$ss,
    total_ss = total_ss
  ) |>
    mutate(
      interaction_order = str_count(effect, ":") + 1L,
      eta_squared = if_else(total_ss > 0, ss / total_ss, NA_real_)
    )
}

compute_stage3_factorial_anova <- function(country_year_revenue) {
  by_country_year <- country_year_revenue |>
    group_by(country, country_name, year) |>
    group_modify(~ compute_stage3_factorial_effects_one(.x)) |>
    ungroup()

  pooled <- by_country_year |>
    group_by(effect, interaction_order) |>
    summarise(
      ss = sum(ss, na.rm = TRUE),
      total_ss = sum(total_ss, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(eta_squared = safe_divide(ss, sum(ss, na.rm = TRUE))) |>
    arrange(desc(eta_squared))

  by_country <- by_country_year |>
    group_by(country, country_name, effect, interaction_order) |>
    summarise(
      ss = sum(ss, na.rm = TRUE),
      .groups = "drop"
    ) |>
    group_by(country, country_name) |>
    mutate(eta_squared = safe_divide(ss, sum(ss, na.rm = TRUE))) |>
    ungroup() |>
    arrange(country, desc(eta_squared))

  list(
    by_country_year = by_country_year,
    pooled = pooled,
    by_country = by_country
  )
}

run_stage3_h4_tests <- function(country_year_revenue, scenario_panel) {
  h4_pairs <- build_h4_pairs(country_year_revenue)

  wt_two_sided <- stats::wilcox.test(
    h4_pairs$delta_sbs_minus_universal,
    mu = 0,
    exact = FALSE
  )
  wt_less <- stats::wilcox.test(
    h4_pairs$delta_sbs_minus_universal,
    mu = 0,
    exact = FALSE,
    alternative = "less"
  )

  country_policy <- scenario_panel |>
    filter(affiliate %in% EU27_ISO3) |>
    distinct(
      country = affiliate,
      country_qdmtt = qdmtt_flag
    ) |>
    group_by(country) |>
    summarise(country_qdmtt = any(country_qdmtt, na.rm = TRUE), .groups = "drop")

  us_share <- scenario_panel |>
    filter(
      affiliate %in% EU27_ISO3,
      factor1_etr == "distributional",
      factor2_substance == "aggregate_sbie",
      rate_scenario == "initial",
      factor4_sbs == "universal",
      factor5_behaviour == "mechanical"
    ) |>
    group_by(country = affiliate) |>
    summarise(
      total_topup = sum(topup_after_behaviour, na.rm = TRUE),
      us_parented_topup = sum(if_else(parent == "USA", topup_after_behaviour, 0),
        na.rm = TRUE
      ),
      us_parented_topup_share = safe_divide(us_parented_topup, total_topup),
      .groups = "drop"
    )

  h4_country <- h4_pairs |>
    group_by(country, country_name) |>
    summarise(
      mean_delta_sbs_minus_universal =
        mean(delta_sbs_minus_universal, na.rm = TRUE),
      .groups = "drop"
    ) |>
    left_join(country_policy, by = "country") |>
    left_join(us_share, by = "country") |>
    mutate(
      country_qdmtt = coalesce(country_qdmtt, FALSE),
      us_parented_topup_share = coalesce(us_parented_topup_share, 0)
    )

  h4_fit <- stats::lm(
    mean_delta_sbs_minus_universal ~ country_qdmtt + us_parented_topup_share,
    data = h4_country
  )

  h4_regression <- as.data.frame(summary(h4_fit)$coefficients) |>
    rownames_to_column("term") |>
    as_tibble() |>
    rename(
      estimate = Estimate,
      std_error = `Std. Error`,
      statistic = `t value`,
      p_value = `Pr(>|t|)`
    ) |>
    mutate(
      n_obs = stats::nobs(h4_fit),
      r_squared = summary(h4_fit)$r.squared
    )

  list(
    paired_differences = h4_pairs,
    country_regression_sample = h4_country,
    test_summary = tibble(
      test = "wilcoxon_sbs_minus_universal",
      n = length(h4_pairs$delta_sbs_minus_universal),
      mean_delta = mean(h4_pairs$delta_sbs_minus_universal, na.rm = TRUE),
      median_delta = stats::median(h4_pairs$delta_sbs_minus_universal,
        na.rm = TRUE
      ),
      statistic = unname(wt_two_sided$statistic),
      p_value_two_sided = wt_two_sided$p.value,
      p_value_less = wt_less$p.value
    ),
    regression = h4_regression
  )
}

build_rule_a_global_reallocation <- function(scenario_panel) {
  source_long <- scenario_panel |>
    filter(factor5_behaviour == "behavioural", reallocated_profit > 0) |>
    transmute(
      across(all_of(SCENARIO_VARS)),
      year,
      source_parent = parent,
      source_affiliate = affiliate,
      source_affiliate_name = affiliate_jurisdiction_name,
      source_tau_low = coalesce(static_tau_low, 0),
      transfer_pricing_ip = reallocated_profit_transfer_pricing_ip,
      debt = reallocated_profit_debt,
      substance_planning = reallocated_profit_substance_planning
    ) |>
    pivot_longer(
      cols = c(transfer_pricing_ip, debt, substance_planning),
      names_to = "behavioural_channel",
      values_to = "source_reallocated_profit"
    ) |>
    filter(source_reallocated_profit > 0)

  source_totals <- source_long |>
    group_by(across(all_of(SCENARIO_VARS)), year, behavioural_channel) |>
    summarise(
      total_reallocated_profit = sum(source_reallocated_profit, na.rm = TRUE),
      weighted_source_tau = weighted_mean_available(
        source_tau_low,
        source_reallocated_profit
      ),
      source_affiliates = n_distinct(source_affiliate),
      source_parents = n_distinct(source_parent),
      .groups = "drop"
    )

  destination_weights <- scenario_panel |>
    filter(analysis_profit_positive > 0) |>
    group_by(across(all_of(SCENARIO_VARS)),
      year,
      destination = affiliate
    ) |>
    summarise(
      destination_name = first(affiliate_jurisdiction_name),
      destination_is_eu27 = first(affiliate %in% EU27_ISO3),
      destination_is_conduit_haven =
        any(coalesce(affiliate_is_conduit_haven, FALSE), na.rm = TRUE),
      destination_cit_rate = first_non_missing(affiliate_cit_rate_unit),
      selected_low_share = weighted_mean_available(
        selected_low_share,
        analysis_profit_positive
      ),
      employees = sum(coalesce_zero(employees_sbie), na.rm = TRUE),
      payroll = sum(coalesce_zero(payroll_sbie), na.rm = TRUE),
      upr = sum(pmax(coalesce_zero(upr_panelai), 0), na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(
      high_tax_destination =
        coalesce(destination_cit_rate >= GMT_RATE, FALSE) &
          !destination_is_conduit_haven
    ) |>
    group_by(across(all_of(SCENARIO_VARS)), year) |>
    mutate(has_high_tax_destination = any(high_tax_destination, na.rm = TRUE)) |>
    filter(high_tax_destination | !has_high_tax_destination) |>
    mutate(
      employee_share = safe_divide(employees, sum(employees, na.rm = TRUE)),
      payroll_share = safe_divide(payroll, sum(payroll, na.rm = TRUE)),
      upr_share = safe_divide(upr, sum(upr, na.rm = TRUE)),
      reallocation_weight_raw = 0.25 * coalesce_zero(employee_share) +
        0.25 * coalesce_zero(payroll_share) +
        0.50 * coalesce_zero(upr_share),
      reallocation_weight = {
        total_weight <- sum(reallocation_weight_raw, na.rm = TRUE)
        if (total_weight > 0) {
          reallocation_weight_raw / total_weight
        } else {
          rep(1 / n(), n())
        }
      },
      destination_weight_source = if_else(
        has_high_tax_destination,
        "high_tax_activity_weight",
        "all_positive_activity_fallback"
      )
    ) |>
    ungroup()

  matrix <- destination_weights |>
    left_join(source_totals,
      by = c(SCENARIO_VARS, "year"),
      relationship = "many-to-many"
    ) |>
    mutate(
      total_reallocated_profit = coalesce_zero(total_reallocated_profit),
      weighted_source_tau = coalesce(weighted_source_tau, 0),
      behavioural_channel = coalesce(behavioural_channel, "none"),
      reallocated_profit_received =
        reallocation_weight * total_reallocated_profit,
      destination_cit_rate = coalesce(destination_cit_rate, GMT_RATE),
      ordinary_cit_gross_destination_revenue =
        reallocated_profit_received * destination_cit_rate,
      ordinary_cit_net_recovery =
        reallocated_profit_received *
          pmax(destination_cit_rate - weighted_source_tau, 0)
    )

  scenario_year_keys <- scenario_panel |>
    distinct(across(all_of(SCENARIO_VARS)), year)

  source_check <- source_totals |>
    group_by(across(all_of(SCENARIO_VARS)), year) |>
    summarise(
      total_reallocated_profit = sum(total_reallocated_profit, na.rm = TRUE),
      .groups = "drop"
    )

  allocated_check <- matrix |>
    group_by(across(all_of(SCENARIO_VARS)), year) |>
    summarise(
      allocated_profit = sum(reallocated_profit_received, na.rm = TRUE),
      eu27_destination_profit = sum(
        if_else(destination_is_eu27, reallocated_profit_received, 0),
        na.rm = TRUE
      ),
      ordinary_cit_gross_destination_revenue = sum(
        ordinary_cit_gross_destination_revenue,
        na.rm = TRUE
      ),
      ordinary_cit_net_recovery = sum(ordinary_cit_net_recovery, na.rm = TRUE),
      weight_sum = sum(
        reallocation_weight[behavioural_channel == first(behavioural_channel)],
        na.rm = TRUE
      ),
      destinations = n_distinct(destination),
      .groups = "drop"
    )

  conservation <- scenario_year_keys |>
    left_join(source_check, by = c(SCENARIO_VARS, "year")) |>
    left_join(allocated_check, by = c(SCENARIO_VARS, "year")) |>
    mutate(
      total_reallocated_profit = coalesce_zero(total_reallocated_profit),
      allocated_profit = coalesce_zero(allocated_profit),
      eu27_destination_profit = coalesce_zero(eu27_destination_profit),
      ordinary_cit_gross_destination_revenue =
        coalesce_zero(ordinary_cit_gross_destination_revenue),
      ordinary_cit_net_recovery = coalesce_zero(ordinary_cit_net_recovery),
      allocation_gap = allocated_profit - total_reallocated_profit
    )

  if (max(abs(conservation$allocation_gap), na.rm = TRUE) > 1e-3) {
    stop("Strategic behavioural reallocation does not conserve profit")
  }

  channel_summary <- source_totals |>
    group_by(across(all_of(SCENARIO_VARS)), behavioural_channel) |>
    summarise(
      reallocated_profit = sum(total_reallocated_profit, na.rm = TRUE),
      source_affiliates = sum(source_affiliates, na.rm = TRUE),
      source_parents = sum(source_parents, na.rm = TRUE),
      .groups = "drop"
    )

  destination_summary <- matrix |>
    filter(behavioural_channel != "none") |>
    group_by(
      across(all_of(SCENARIO_VARS)),
      destination,
      destination_name,
      destination_is_eu27,
      behavioural_channel
    ) |>
    summarise(
      reallocated_profit_received =
        sum(reallocated_profit_received, na.rm = TRUE),
      ordinary_cit_gross_destination_revenue =
        sum(ordinary_cit_gross_destination_revenue, na.rm = TRUE),
      ordinary_cit_net_recovery = sum(ordinary_cit_net_recovery, na.rm = TRUE),
      .groups = "drop"
    )

  list(
    matrix = matrix,
    conservation = conservation,
    channel_summary = channel_summary,
    destination_summary = destination_summary
  )
}

build_reallocation_matrix <- function(scenario_panel, affiliate_year) {
  legacy <- build_rule_a_global_reallocation(scenario_panel)
  rule_b <- build_rule_b_reallocation(scenario_panel, affiliate_year)
  keys <- c(SCENARIO_VARS, "year", "destination", "behavioural_channel")
  amounts <- c("reallocated_profit_received", "ordinary_cit_gross_destination_revenue",
    "ordinary_cit_net_recovery")
  legacy_values <- c(amounts, "reallocation_weight", "destination_weight_source")
  destinations <- scenario_panel |>
    summarise(destination_name_rule_b = first(affiliate_jurisdiction_name),
      destination_cit_rate_rule_b = first_non_missing(affiliate_cit_rate_unit),
      destination_is_conduit_haven_rule_b = any(coalesce(affiliate_is_conduit_haven, FALSE)),
      .by = c(affiliate, year)) |>
    rename(destination = affiliate)
  channel_keys <- setdiff(keys, "destination")
  channel_totals <- distinct(legacy$matrix, across(all_of(channel_keys)),
    channel_reallocated_profit = total_reallocated_profit)
  matrix <- legacy$matrix |>
    rename_with(~ paste0(.x, "_rule_a"), all_of(legacy_values)) |>
    full_join(rule_b, by = keys, relationship = "one-to-one") |>
    left_join(destinations, by = c("destination", "year"), relationship = "many-to-one") |>
    left_join(channel_totals, by = channel_keys, relationship = "many-to-one") |>
    mutate(
      destination_name = coalesce(destination_name, destination_name_rule_b),
      destination_cit_rate = coalesce(destination_cit_rate_rule_b, destination_cit_rate),
      destination_is_conduit_haven = coalesce(destination_is_conduit_haven,
        destination_is_conduit_haven_rule_b),
      destination_is_eu27 = destination %in% EU27_ISO3,
      total_reallocated_profit = coalesce(total_reallocated_profit, channel_reallocated_profit),
      across(c(all_of(amounts), ends_with("_revenue_effective"), ordinary_cit_source_loss,
        global_fallback_profit_received, all_of(paste0(amounts, "_rule_a"))), coalesce_zero),
      weighted_source_tau_rule_a = weighted_source_tau,
      weighted_source_tau = safe_divide(ordinary_cit_source_loss, reallocated_profit_received),
      destination_weight_source = case_when(
        reallocated_profit_received == 0 ~ "none",
        global_fallback_profit_received == 0 ~ "parent_activity",
        global_fallback_profit_received >= reallocated_profit_received ~ "global_activity",
        TRUE ~ "mixed_activity"
      )
    ) |>
    select(-destination_name_rule_b, -destination_cit_rate_rule_b,
      -destination_is_conduit_haven_rule_b, -channel_reallocated_profit) |>
    group_by(across(all_of(SCENARIO_VARS)), year, behavioural_channel) |>
    mutate(reallocation_weight = coalesce_zero(safe_divide(
      reallocated_profit_received, sum(reallocated_profit_received)
    ))) |>
    ungroup()
  allocated <- matrix |>
    summarise(
      allocated_profit = sum(reallocated_profit_received),
      eu27_destination_profit = sum(reallocated_profit_received[destination_is_eu27]),
      across(c(ordinary_cit_gross_destination_revenue, ordinary_cit_net_recovery,
        ordinary_cit_source_loss, global_fallback_profit_received), sum),
      weight_sum = sum(reallocation_weight[behavioural_channel == first(behavioural_channel)]),
      destinations = n_distinct(destination[reallocated_profit_received > 0]),
      .by = c(all_of(SCENARIO_VARS), year)
    )
  conservation <- legacy$conservation |>
    rename_with(~ paste0(.x, "_rule_a"), -all_of(c(SCENARIO_VARS, "year", "total_reallocated_profit"))) |>
    left_join(allocated, by = c(SCENARIO_VARS, "year"), relationship = "one-to-one") |>
    mutate(across(all_of(setdiff(names(allocated), c(SCENARIO_VARS, "year"))), coalesce_zero),
      allocation_gap = allocated_profit - total_reallocated_profit)
  stopifnot(all(abs(conservation$allocation_gap) < 1e-3),
    all(abs(conservation$allocation_gap_rule_a) < 1e-3))

  destination_summary <- matrix |>
    filter(behavioural_channel != "none") |>
    summarise(
      across(c(all_of(amounts), all_of(paste0(amounts, "_rule_a")),
        ordinary_cit_gross_destination_revenue_effective, ordinary_cit_source_loss,
        global_fallback_profit_received), sum),
      .by = c(all_of(SCENARIO_VARS), destination, destination_name,
        destination_is_eu27, behavioural_channel)
    )
  list(matrix = matrix, conservation = conservation, channel_summary = legacy$channel_summary,
    destination_summary = destination_summary)
}

build_behavioural_identification_design <- function() {
  tribble(
    ~component, ~baseline_treatment, ~identification_status,
    ~data_needed_for_structural_extension,
    "reallocation_share",
    paste(
      "Estimated from the CbCR fixed-effect semi-elasticity and applied only",
      "where a legal collection channel remains active."
    ),
    paste(
      "Identified as a reduced-form profit response, not as a structural",
      "destination-choice parameter."
    ),
    paste(
      "Private firm-level CbCR or unconsolidated affiliate accounts observed",
      "around tax shocks, with group identifiers and affiliate balance sheets."
    ),
    "low_etr_nonlinearity",
    paste(
      "Quadratic and logarithmic semi-elasticity specifications are estimated,",
      "but the preferred estimator is still chosen by BIC. A lower-tail",
      "support diagnostic reports below-5 per cent observations and an",
      "illustrative tail-balanced reweighting design."
    ),
    paste(
      "The current public CbCR panel identifies tax responsiveness more",
      "credibly than it identifies the curvature of the response at the",
      "extreme lower ETR tail. Tail upweighting is not treated as IPW because",
      "the public data do not observe a sampling or treatment-selection",
      "probability for below-5 per cent ETR cells."
    ),
    paste(
      "MNE-jurisdiction microdata or a quasi-experimental tax shock with dense",
      "support below 5 per cent, plus a defensible model for the probability",
      "that an observation enters the lower tail."
    ),
    "reallocation_cap",
    paste(
      "No discretionary cap is imposed; the response is bounded only to the",
      "unit interval."
    ),
    paste(
      "A cap below one is not identified from public aggregate CbCR data."
    ),
    paste(
      "Observed post-reform relocation shares from private CbCR or tax-return",
      "microdata."
    ),
    "sesh_notch_bunching",
    paste(
      "Implemented as an upper-bound liability filter inside the simplified",
      "ETR band below 15 per cent."
    ),
    paste(
      "Not structurally identified from the 2017-2022 public CbCR panel,",
      "which is pre-reform and does not observe a post-SESH density spike."
    ),
    paste(
      "Post-SESH MNE-jurisdiction microdata with simplified ETRs, safe-harbour",
      "elections and enough support around the 15 per cent threshold to",
      "estimate missing and excess mass."
    ),
    "channel_split",
    paste(
      "Diagnostic only. The short-run split uses the Heckemeyer-Overesch",
      "meta-regression distinction between transfer-pricing or licensing",
      "and financial-planning channels."
    ),
    paste(
      "The channel split does not affect top-up tax revenue in the legal",
      "allocation matrix."
    ),
    paste(
      "Royalty, licence, service-fee, interest, intra-group debt and IP",
      "ownership data by MNE group and affiliate."
    ),
    "substance_relocation",
    paste(
      "Set to zero in the short-run behavioural response because payroll and",
      "tangible assets are held fixed in the SBIE calculation."
    ),
    paste(
      "Real activity relocation is a longer-run margin and cannot be separated",
      "from book-profit shifting in aggregate CbCR."
    ),
    paste(
      "Firm-level employment, payroll, tangible-asset and investment responses",
      "around anti-avoidance or GMT implementation shocks."
    ),
    "destination_matrix",
    paste(
      "Uses the Garcia-Bernardo and Jansky activity-weighted formula as a",
      "profit-conservation diagnostic."
    ),
    paste(
      "Public CbCR does not observe origin-destination flows of shifted profit,",
      "so PPML or conditional logit would describe profit stocks rather than",
      "identify counterfactual relocation flows."
    ),
    paste(
      "Origin-destination royalty, interest, service-fee or profit-flow data,",
      "plus destination choice sets, statutory and effective tax rates,",
      "withholding taxes, treaty links and anti-avoidance rules."
    )
  )
}

run_stage3_pipeline <- function() {
  dir.create(DIAGNOSTICS_DIR, showWarnings = FALSE, recursive = TRUE)
  base_panel <- readRDS(file.path(PROCESSED_DIR, "base_panel.rds"))
  stage1_affiliate_year <- readRDS(file.path(PROCESSED_DIR, "stage1_affiliate_year.rds"))
  stage2_bilateral <- readRDS(file.path(PROCESSED_DIR, "stage2_bilateral_panel.rds"))
  stage2_sectoral_panel <- readRDS(file.path(PROCESSED_DIR, "stage2_sectoral_panel.rds"))
  etr_forward <- readRDS(file.path(PROCESSED_DIR, "etr_forward.rds"))
  oecd_central_record <- readRDS(file.path(PROCESSED_DIR, "oecd_pillar2_central_record.rds"))

  assert_unique_keys(base_panel, c("parent", "affiliate", "year"), "base panel")
  assert_unique_keys(
    stage1_affiliate_year, c("affiliate", "year"),
    "stage1 affiliate-year"
  )
  assert_unique_keys(
    stage2_bilateral,
    c("rate_scenario", "parent", "affiliate", "year"),
    "stage2 bilateral"
  )

  estimation_sample <- prepare_estimation_sample(
    base_panel,
    etr_forward = etr_forward
  )
  no_stale_sample <- prepare_estimation_sample(
    base_panel,
    exclude_stale_wages = TRUE,
    etr_forward = etr_forward
  )
  balanced_sample <- prepare_estimation_sample(
    base_panel,
    balanced_pairs_only = TRUE,
    etr_forward = etr_forward
  )
  no_covid_sample <- prepare_estimation_sample(
    base_panel,
    exclude_covid_years = TRUE,
    etr_forward = etr_forward
  )

  model_fits <- estimate_stage3_models(estimation_sample)
  fixest_equivalence <- bind_rows(lapply(
    model_fits[c("linear", "quadratic", "logarithmic")],
    build_fixest_equivalence_diagnostic
  ))
  alternative_estimators <- build_stage3_alternative_estimators_diagnostic(
    estimation_sample, base_panel, log_t0 = model_fits$logarithmic$t0
  )
  model_wald_tests <- stage3_model_wald_tests(model_fits)
  tax_endogeneity_diagnostics <- build_tax_endogeneity_diagnostics(estimation_sample)
  tax_instrument_coverage <- summarise_tax_instrument_coverage(estimation_sample)
  model_comparison <- build_model_diagnostics(model_fits, "baseline") |>
    select(-sample)
  preferred_model <- model_comparison$model_spec[1]

  coefficients <- bind_rows(
    model_fits$linear$coefficient_table,
    model_fits$linear$coefficient_table_two_way,
    model_fits$quadratic$coefficient_table,
    model_fits$quadratic$coefficient_table_two_way,
    model_fits$logarithmic$coefficient_table,
    model_fits$logarithmic$coefficient_table_two_way
  )
  semielasticity_schedule <- stage3_semielasticity_schedule(model_fits)

  specification_tests <- run_specification_tests(estimation_sample, model_fits)

  robustness_model_comparison <- bind_rows(
    build_model_diagnostics(model_fits, "baseline"),
    estimate_robustness_model_diagnostics(
      list(
        exclude_stale_wages = no_stale_sample,
        balanced_pairs = balanced_sample,
        exclude_2020_2021 = no_covid_sample
      )
    )
  ) |>
    arrange(sample, bic_rank)

  robustness_summary <- bind_rows(
    tibble(sample = "baseline", estimation_sample),
    tibble(sample = "exclude_stale_wages", no_stale_sample),
    tibble(sample = "balanced_pairs", balanced_sample),
    tibble(sample = "exclude_2020_2021", no_covid_sample)
  ) |>
    group_by(sample) |>
    summarise(
      rows = n(),
      pairs = n_distinct(pair_id),
      affiliates = n_distinct(affiliate),
      parents = n_distinct(parent),
      median_pair_years = stats::median(pair_years_in_estimation_sample),
      tau_min = min(tau, na.rm = TRUE),
      tau_p50 = stats::median(tau, na.rm = TRUE),
      tau_max = max(tau, na.rm = TRUE),
      stale_wage_rows = sum(coalesce(affiliate_wage_stale_flag, FALSE)),
      .groups = "drop"
    )

  etr_tail_support <- summarise_stage3_etr_tail_support(estimation_sample)
  tail_reweighting_feasibility <-
    summarise_stage3_tail_reweighting_feasibility(estimation_sample)
  tail_metric <- function(metric_name) {
    tail_reweighting_feasibility$value[
      tail_reweighting_feasibility$metric == metric_name
    ][1]
  }

  behavioural_affiliate_year <- build_behavioural_affiliate_year(
    stage1_affiliate_year,
    model_fits
  )

  policy_flags <- build_policy_flags(oecd_central_record)
  policy_tracker_diagnostics <- build_policy_tracker_diagnostics(oecd_central_record)
  eu27_legal_regimes <- build_eu27_legal_regime_classification(oecd_central_record)
  sectoral_bridge <- build_sectoral_factor2_bridge(
    stage2_bilateral,
    stage1_affiliate_year,
    stage2_sectoral_panel
  )
  sectoral_bridge_comparison <- summarise_sectoral_bridge_comparison(sectoral_bridge)

  revenue_objects <- build_factorial_revenue(
    stage2_bilateral,
    behavioural_affiliate_year,
    sectoral_bridge,
    policy_flags,
    preferred_model
  )

  anova_objects <- compute_stage3_factorial_anova(
    revenue_objects$country_year_revenue
  )
  h4_objects <- run_stage3_h4_tests(
    revenue_objects$country_year_revenue,
    revenue_objects$scenario_panel
  )
  reallocation_objects <- build_reallocation_matrix(
    revenue_objects$scenario_panel, stage1_affiliate_year
  )
  behavioural_identification_design <- build_behavioural_identification_design()

  behavioural_by_year <- behavioural_affiliate_year |>
    filter(eta == SESH_BANDWIDTH_BASELINE) |>
    group_by(model_spec, etr_measurement, year) |>
    summarise(
      affiliate_years = n(),
      eu27_affiliate_years = sum(affiliate_is_eu27, na.rm = TRUE),
      mean_beta_applied = mean(beta_applied, na.rm = TRUE),
      profit_weighted_beta_applied = weighted_mean_available(
        beta_applied,
        total_analysis_profit_positive
      ),
      bunching_affiliate_years = sum(
        behavioural_regime == "sesh_bunching_topup_zero",
        na.rm = TRUE
      ),
      reallocation_affiliate_years = sum(
        behavioural_regime == "semi_elasticity_reallocation",
        na.rm = TRUE
      ),
      sign_restricted_affiliate_years = sum(beta_sign_restricted_flag,
        na.rm = TRUE
      ),
      .groups = "drop"
    )

  scenario_country_year <- revenue_objects$country_year_revenue
  scenario_spread <- scenario_country_year |>
    group_by(country, country_name, year) |>
    summarise(
      min_revenue = min(revenue, na.rm = TRUE),
      max_revenue = max(revenue, na.rm = TRUE),
      scenario_spread = max_revenue - min_revenue,
      mean_revenue = mean(revenue, na.rm = TRUE),
      .groups = "drop"
    )

  strategy_scenario_summary <- revenue_objects$scenario_panel |>
    group_by(across(all_of(SCENARIO_VARS))) |>
    summarise(
      pre_behaviour_topup = sum(topup_after_stage2, na.rm = TRUE),
      post_behaviour_topup = sum(topup_after_behaviour, na.rm = TRUE),
      behavioural_avoided_topup = sum(behavioural_avoided_topup, na.rm = TRUE),
      reallocated_profit = sum(reallocated_profit, na.rm = TRUE),
      mean_static_beta = mean(static_beta_applied, na.rm = TRUE),
      topup_weighted_beta_applied = weighted_mean_available(
        beta_applied,
        topup_after_stage2
      ),
      diagnostic_multiplier_weighted = weighted_mean_available(
        diagnostic_planning_intensity,
        topup_after_stage2
      ),
      policy_collection_exposure_weighted = weighted_mean_available(
        policy_collection_exposure,
        topup_after_stage2
      ),
      semi_elasticity_reallocation_rows =
        sum(behavioural_regime == "semi_elasticity_reallocation",
          na.rm = TRUE
        ),
      sesh_rows =
        sum(behavioural_regime == "sesh_bunching_topup_zero", na.rm = TRUE),
      .groups = "drop"
    )

  strategy_by_year <- revenue_objects$scenario_panel |>
    filter(factor5_behaviour == "behavioural") |>
    group_by(factor1_etr, factor2_substance, rate_scenario, factor4_sbs, year) |>
    summarise(
      pre_behaviour_topup = sum(topup_after_stage2, na.rm = TRUE),
      post_behaviour_topup = sum(topup_after_behaviour, na.rm = TRUE),
      behavioural_avoided_topup = sum(behavioural_avoided_topup, na.rm = TRUE),
      reallocated_profit = sum(reallocated_profit, na.rm = TRUE),
      topup_weighted_beta_applied = weighted_mean_available(
        beta_applied,
        topup_after_stage2
      ),
      diagnostic_multiplier_weighted = weighted_mean_available(
        diagnostic_planning_intensity,
        topup_after_stage2
      ),
      semi_elasticity_reallocation_rows =
        sum(behavioural_regime == "semi_elasticity_reallocation",
          na.rm = TRUE
        ),
      .groups = "drop"
    )

  preferred_strategy <- strategy_scenario_summary |>
    filter(
      factor1_etr == "distributional",
      factor2_substance == "aggregate_sbie",
      rate_scenario == "initial",
      factor4_sbs == "universal",
      factor5_behaviour == "behavioural"
    )

  preferred_reallocation <- reallocation_objects$conservation |>
    filter(
      factor1_etr == "distributional",
      factor2_substance == "aggregate_sbie",
      rate_scenario == "initial",
      factor4_sbs == "universal",
      factor5_behaviour == "behavioural"
    )

  stage3_summary <- tibble(
    metric = c(
      "estimation_rows_baseline",
      "estimation_pairs_baseline",
      "estimation_affiliates_baseline",
      "preferred_model_bic",
      "preferred_model_within_r_squared",
      "preferred_model_tax_terms_wald_pvalue",
      "simulated_tax_code_eatr_first_stage_f_two_way",
      "lagged_statutory_cit_first_stage_f_two_way",
      "logarithmic_t0",
      "low_etr_tail_row_share",
      "low_etr_tail_switching_pairs",
      "low_etr_tail_balance_effective_n",
      "low_etr_tail_balance_design_effect",
      "factorial_scenarios",
      "country_year_revenue_rows",
      "pooled_interaction_eta_squared",
      "h4_mean_delta_sbs_minus_universal",
      "reallocation_max_abs_conservation_gap",
      "preferred_behavioural_avoided_topup",
      "preferred_behavioural_reallocated_profit",
      "preferred_behavioural_ordinary_cit_net_recovery"
    ),
    value = c(
      nrow(estimation_sample),
      n_distinct(estimation_sample$pair_id),
      n_distinct(estimation_sample$affiliate),
      preferred_model,
      model_comparison$within_r_squared[
        model_comparison$model_spec == preferred_model
      ][1],
      model_wald_tests$p_value[
        model_wald_tests$model_spec == preferred_model &
          model_wald_tests$inference == "affiliate_clustered"
      ][1],
      tax_endogeneity_diagnostics$f_statistic[
        tax_endogeneity_diagnostics$diagnostic ==
          "simulated_tax_code_eatr_first_stage_for_cbcr_etr" &
          tax_endogeneity_diagnostics$inference ==
            "parent_affiliate_clustered"
      ][1],
      tax_endogeneity_diagnostics$f_statistic[
        tax_endogeneity_diagnostics$diagnostic ==
          "lagged_statutory_cit_first_stage_for_cbcr_etr" &
          tax_endogeneity_diagnostics$inference ==
            "parent_affiliate_clustered"
      ][1],
      model_fits$logarithmic$t0,
      tail_metric("low_tail_row_share"),
      tail_metric("tail_switching_pairs"),
      tail_metric("tail_balance_effective_n"),
      tail_metric("tail_balance_design_effect"),
      n_distinct(revenue_objects$scenario_summary$scenario_id),
      nrow(scenario_country_year),
      sum(anova_objects$pooled$eta_squared[
        anova_objects$pooled$interaction_order >= 2
      ], na.rm = TRUE),
      h4_objects$test_summary$mean_delta,
      max(abs(reallocation_objects$conservation$allocation_gap), na.rm = TRUE),
      sum(preferred_strategy$behavioural_avoided_topup, na.rm = TRUE),
      sum(preferred_strategy$reallocated_profit, na.rm = TRUE),
      sum(preferred_reallocation$ordinary_cit_net_recovery, na.rm = TRUE)
    )
  )

  write_csv(
    stage3_summary,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_summary.csv")
  )
  write_csv(
    robustness_summary,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_estimation_sample_summary.csv")
  )
  write_csv(
    model_comparison,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_model_comparison.csv")
  )
  write_csv(
    model_fits$log_grid,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_log_t0_grid.csv")
  )
  write_csv(
    fixest_equivalence,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_fixest_equivalence.csv")
  )
  write_csv(
    coefficients,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_coefficients.csv")
  )
  write_csv(
    model_wald_tests,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_model_wald_tests.csv")
  )
  write_csv(
    tax_endogeneity_diagnostics,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_tax_endogeneity_diagnostics.csv")
  )
  write_csv(
    tax_instrument_coverage,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_tax_instrument_coverage.csv")
  )
  write_csv(
    semielasticity_schedule,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_semielasticity_schedule.csv")
  )
  write_csv(
    robustness_model_comparison,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_model_robustness.csv")
  )
  write_csv(
    specification_tests,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_specification_tests.csv")
  )
  write_csv(
    etr_tail_support,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_etr_tail_support.csv")
  )
  write_csv(
    tail_reweighting_feasibility,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_tail_reweighting_feasibility.csv")
  )
  write_csv(
    behavioural_by_year,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_behaviour_by_year.csv")
  )
  write_csv(
    policy_flags,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_policy_flags.csv")
  )
  write_csv(
    policy_tracker_diagnostics,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_policy_tracker_diagnostics.csv")
  )
  write_csv(
    eu27_legal_regimes,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_eu27_legal_regime_classification.csv")
  )
  write_csv(
    sectoral_bridge,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_sectoral_factor2_bridge.csv")
  )
  write_csv(
    alternative_estimators,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_alternative_estimators.csv")
  )
  write_csv(
    sectoral_bridge_comparison,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_sectoral_factor2_bridge_comparison.csv")
  )
  write_csv(
    revenue_objects$scenario_summary,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_factorial_scenario_summary.csv")
  )
  write_csv(
    strategy_scenario_summary,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_strategy_scenario_summary.csv")
  )
  write_csv(
    strategy_by_year,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_strategy_by_year.csv")
  )
  write_csv(
    scenario_spread,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_scenario_spread_country_year.csv")
  )
  write_csv(
    anova_objects$pooled,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_anova_pooled.csv")
  )
  write_csv(
    anova_objects$by_country,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_anova_by_country.csv")
  )
  write_csv(
    h4_objects$test_summary,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_h4_wilcoxon.csv")
  )
  write_csv(
    h4_objects$country_regression_sample,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_h4_country_regression_sample.csv")
  )
  write_csv(
    h4_objects$regression,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_h4_regression.csv")
  )
  write_csv(
    reallocation_objects$conservation,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_reallocation_conservation.csv")
  )
  write_csv(
    reallocation_objects$channel_summary,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_reallocation_channel_summary.csv")
  )
  write_csv(
    reallocation_objects$destination_summary,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_reallocation_destination_summary.csv")
  )
  write_csv(
    behavioural_identification_design,
    file.path(DIAGNOSTICS_DIR, "step5_stage3_behavioural_identification_design.csv")
  )

  saveRDS(estimation_sample, file.path(PROCESSED_DIR, "stage3_estimation_sample.rds"))
  saveRDS(model_comparison, file.path(PROCESSED_DIR, "stage3_model_comparison.rds"))
  saveRDS(coefficients, file.path(PROCESSED_DIR, "stage3_model_coefficients.rds"))
  saveRDS(model_wald_tests, file.path(PROCESSED_DIR, "stage3_model_wald_tests.rds"))
  saveRDS(
    tax_endogeneity_diagnostics,
    file.path(PROCESSED_DIR, "stage3_tax_endogeneity_diagnostics.rds")
  )
  saveRDS(
    tax_instrument_coverage,
    file.path(PROCESSED_DIR, "stage3_tax_instrument_coverage.rds")
  )
  saveRDS(
    semielasticity_schedule,
    file.path(PROCESSED_DIR, "stage3_semielasticity_schedule.rds")
  )
  saveRDS(
    robustness_model_comparison,
    file.path(PROCESSED_DIR, "stage3_model_robustness.rds")
  )
  saveRDS(
    etr_tail_support,
    file.path(PROCESSED_DIR, "stage3_etr_tail_support.rds")
  )
  saveRDS(
    tail_reweighting_feasibility,
    file.path(PROCESSED_DIR, "stage3_tail_reweighting_feasibility.rds")
  )
  saveRDS(
    behavioural_affiliate_year,
    file.path(PROCESSED_DIR, "stage3_behavioral_affiliate_year.rds")
  )
  saveRDS(
    revenue_objects$scenario_panel,
    file.path(PROCESSED_DIR, "stage3_factorial_pair_year.rds")
  )
  saveRDS(
    revenue_objects$channel_revenue,
    file.path(PROCESSED_DIR, "stage3_revenue_by_channel.rds")
  )
  saveRDS(
    scenario_country_year,
    file.path(PROCESSED_DIR, "stage3_revenue_country_year.rds")
  )
  saveRDS(
    anova_objects$pooled,
    file.path(PROCESSED_DIR, "stage3_anova_pooled.rds")
  )
  saveRDS(
    anova_objects$by_country,
    file.path(PROCESSED_DIR, "stage3_anova_by_country.rds")
  )
  saveRDS(
    reallocation_objects$matrix,
    file.path(PROCESSED_DIR, "stage3_reallocation_matrix.rds")
  )
  saveRDS(
    reallocation_objects$conservation,
    file.path(PROCESSED_DIR, "stage3_reallocation_conservation.rds")
  )
  saveRDS(
    reallocation_objects$channel_summary,
    file.path(PROCESSED_DIR, "stage3_reallocation_channel_summary.rds")
  )
  saveRDS(
    reallocation_objects$destination_summary,
    file.path(PROCESSED_DIR, "stage3_reallocation_destination_summary.rds")
  )
  saveRDS(
    behavioural_identification_design,
    file.path(PROCESSED_DIR, "stage3_behavioural_identification_design.rds")
  )
  saveRDS(
    strategy_scenario_summary,
    file.path(PROCESSED_DIR, "stage3_strategy_scenario_summary.rds")
  )

  message("\nStep 5 outputs written:")
  message(" - data/processed/stage3_estimation_sample.rds")
  message(" - data/processed/stage3_etr_tail_support.rds")
  message(" - data/processed/stage3_behavioral_affiliate_year.rds")
  message(" - data/processed/stage3_factorial_pair_year.rds")
  message(" - data/processed/stage3_revenue_by_channel.rds")
  message(" - data/processed/stage3_revenue_country_year.rds")
  message(" - data/processed/stage3_strategy_scenario_summary.rds")
  message(" - data/processed/stage3_reallocation_*")
  message(" - data/processed/stage3_anova_*.rds")
  message(" - diagnostics/step5_stage3_*.csv")
}

if (is_direct_script_run("code/05_stage3_behavioral.R")) {
  run_stage3_pipeline()
}
