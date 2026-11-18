# Fixed-effect fits, model comparison and reported schedules. The formulas,
# weights and covariance calculations retain their estimator-specific contracts.
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "00_helpers.R"), local = TRUE)

source(file.path(GMT_PROJECT_ROOT, "code", "behaviour", "estimation_sample.R"), local = TRUE)
source(file.path(GMT_PROJECT_ROOT, "code", "behaviour", "response_kernel.R"), local = TRUE)

LOG_T0_GRID <- seq(0.001, 0.200, length.out = 60)

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

  samples <- prepare_alternative_estimator_samples(estimation_sample, base_panel)
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

fit_division_bias_design <- function(data, regressor, support, activity, log_t0) {
  stopifnot(all(is.finite(data[[regressor]])), min(data[[regressor]]) + log_t0 > 0)
  data <- data |>
    mutate(
      tau = .data[[regressor]], tau_sq = tau^2, log_tau = log(log_t0 + tau),
      log_assets = if (activity == "lagged") log_assets_lagged else log_assets,
      log_payroll = if (activity == "lagged") log_payroll_lagged else log_payroll
    )
  tax_terms <- list(
    linear = "tau", quadratic = c("tau", "tau_sq"), logarithmic = c("tau", "log_tau")
  )
  controls <- c("log_assets", "log_payroll", "log_gdp_pc", "log_population")
  cluster_correction <- fixest::ssc(K.fixef = "full", G.df = "conventional")

  map_dfr(c("fe_ols", "fe_wls", "fe_ppml_positive"), function(estimator) {
    used_rows <- NULL
    estimates <- imap_dfr(tax_terms, function(terms, form) {
      poisson <- estimator == "fe_ppml_positive"
      outcome <- if (poisson) "analysis_profit_base" else "log_profit"
      formula <- as.formula(paste(outcome, "~", paste(c(controls, terms), collapse = " + "),
        "| pair_id + year"
      ))
      covariance_repaired <- FALSE
      record_covariance_repair <- function(warning) {
        if (grepl("VCOV matrix is not positive definite and was 'fixed'", conditionMessage(warning), fixed = TRUE)) {
          covariance_repaired <<- TRUE
          invokeRestart("muffleWarning")
        }
      }
      fit <- withCallingHandlers(if (poisson) {
        fixest::fepois(formula, data = data, cluster = ~ parent + affiliate,
          ssc = cluster_correction, notes = FALSE, nthreads = 2
        )
      } else {
        fixest::feols(formula, data = data, cluster = ~ parent + affiliate,
          weights = if (estimator == "fe_wls") ~ pair_profit_weight else NULL,
          ssc = cluster_correction, notes = FALSE, nthreads = 2
        )
      }, warning = record_covariance_repair)
      indices <- fixest::obs(fit)
      if (is.null(used_rows)) used_rows <<- indices
      stopifnot(identical(indices, used_rows), !isFALSE(fit$convStatus))
      used <- data[indices, , drop = FALSE]
      coefs <- coef(fit)
      covariance <- vcov(fit)
      coefficient_table <- fixest::coeftable(fit)
      report_terms <- intersect(c("log_assets", "log_payroll", terms), names(coefs))
      stopifnot(all(terms %in% report_terms))
      tax_pattern <- paste0("^(", paste(terms, collapse = "|"), ")$")
      wald <- withCallingHandlers(fixest::wald(fit, keep = tax_pattern, print = FALSE),
        warning = record_covariance_repair
      )
      affiliate_cluster_p <- if (covariance_repaired) {
        fixest::wald(fit, keep = tax_pattern, vcov = ~affiliate, print = FALSE)$p
      } else {
        NA_real_
      }
      n_parents <- n_distinct(used$parent)
      n_affiliates <- n_distinct(used$affiliate)
      n_pairs <- n_distinct(used$pair_id)
      bic <- if (poisson) {
        BIC(fit)
      } else {
        weights <- if (estimator == "fe_wls") used$pair_profit_weight else rep(1, nrow(used))
        stage3_gaussian_bic(fit, weights)
      }
      semi <- semielasticity_schedule_one(
        list(coefficients = coefs, model_spec = form, t0 = log_t0, n = nrow(used),
          n_parents = n_parents, n_affiliates = n_affiliates, n_pairs = n_pairs
        ),
        c(0.05, 0.10, 0.15), inference = "parent_affiliate_two_way_clustered",
        vcov = covariance, df_inference = min(n_parents, n_affiliates) - 1L
      ) |>
        transmute(statistic_type = "semi_elasticity", term = "negative_log_profit_derivative",
          tau_eval = tau, estimate = semi_elasticity, std_error, p_value
        )
      bind_rows(
        tibble(statistic_type = "coefficient", term = report_terms, tau_eval = NA_real_,
          estimate = coefficient_table[report_terms, 1], std_error = coefficient_table[report_terms, 2],
          p_value = coefficient_table[report_terms, 4]
        ),
        semi
      ) |>
        mutate(
          regressor, sample = support, activity, estimator, model_spec = form,
          dependent_variable = outcome, n = nrow(used), n_supplied = nrow(data),
          n_pairs, n_parents, n_affiliates, start_year = min(used$year), end_year = max(used$year),
          etr_min = min(used$tau), etr_max = max(used$tau),
          n_etr_below_005 = sum(used$tau < 0.05),
          n_etr_at_or_below_010 = sum(used$tau <= 0.10),
          joint_tax_wald_f = wald$stat, joint_tax_wald_p = wald$p,
          joint_tax_wald_df1 = wald$df1, joint_tax_wald_df2 = wald$df2,
          covariance_repaired, affiliate_cluster_p_if_repaired = affiliate_cluster_p,
          bic, bic_basis = if (poisson) "poisson_pseudo_likelihood_usd" else "gaussian_log_profit",
          log_t0 = if (form == "logarithmic") log_t0 else NA_real_,
          .before = 1
        )
    })
    estimates |>
      mutate(delta_bic = bic - min(bic), bic_winner = delta_bic == 0)
  })
}
