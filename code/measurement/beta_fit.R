# Numerical primitives for the Stage 03 mean-constrained Beta fit.
# Tail metrics inherit GMT_RATE from 00_config.R when called without a threshold.

PERCENTILE_PROBS <- c(0.05, 0.25, 0.50, 0.75, 0.95)
BETA_PRECISION_LOG_BOUNDS <- log(c(1e-4, 1e6))
BETA_BOUNDARY_EPS <- 1e-8

condition_stage1_percentiles <- function(q, upper_cap = 1) {
  q |>
    pmax(0) |>
    pmin(upper_cap) |>
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

beta_lower_tail <- function(log_x, alpha, beta) {
  tiny <- log_x < log(1e-16)
  result <- numeric(length(log_x))
  # For x this small, the leading incomplete-beta term avoids underflow
  # inside pbeta and has relative error of order (alpha + beta) * x.
  result[tiny] <- exp(alpha * log_x[tiny] - log(alpha) - lbeta(alpha, beta))
  result[!tiny] <- stats::pbeta(exp(log_x[!tiny]), alpha, beta)
  result
}

beta_quantiles <- function(probs, alpha, beta) {
  precision <- alpha + beta
  mean <- alpha / precision

  if (precision > 1e5) {
    return(rep(mean, length(probs)))
  }
  quantiles <- withCallingHandlers(
    stats::qbeta(probs, alpha, beta),
    warning = function(w) {
      if (grepl("qbeta", conditionMessage(w), fixed = TRUE)) {
        invokeRestart("muffleWarning")
      }
    }
  )
  # Invert the CDF on the log-odds scale when qbeta loses precision.
  # Reflection lets the CDF remain informative even when x rounds to 1.
  interior <- probs > 0 & probs < 1
  cdf <- rep(NA_real_, length(probs))
  lower <- which(is.finite(quantiles) & quantiles <= 0.5)
  upper <- which(is.finite(quantiles) & quantiles > 0.5)
  cdf[lower] <- beta_lower_tail(log(quantiles[lower]), alpha, beta)
  # qbeta can round slightly outside its support for extreme shapes. Keep the
  # reflected CDF defined so the log-odds fallback can retry the inversion.
  cdf[upper] <- 1 - beta_lower_tail(log1p(-pmin(quantiles[upper], 1)), beta, alpha)
  residual <- abs(cdf - probs)
  retry <- which(interior & (!is.finite(residual) | residual > 1e-8))
  for (i in retry) {
    cdf_gap <- function(log_odds) {
      log_tail <- -abs(log_odds) - log1p(exp(-abs(log_odds)))
      if (log_odds <= 0) {
        beta_lower_tail(log_tail, alpha, beta) - probs[i]
      } else {
        1 - beta_lower_tail(log_tail, beta, alpha) - probs[i]
      }
    }
    lower_gap <- cdf_gap(-746)
    upper_gap <- cdf_gap(746)
    quantiles[i] <- if (lower_gap >= 0) {
      0
    } else if (upper_gap <= 0) {
      1
    } else {
      log_odds <- stats::uniroot(cdf_gap, c(-746, 746),
        f.lower = lower_gap, f.upper = upper_gap, tol = 1e-10
      )$root
      if (log_odds <= 0) exp(log_odds) / (1 + exp(log_odds)) else stats::plogis(log_odds)
    }
  }
  quantiles
}

stage1_minimise <- function(objective, low, high, points = numeric()) {
  # Include boundaries and optimise around all detected local minima.
  candidates <- c(points, purrr::map2(low, high, function(a, b) {
    if (b - a < 1e-9) return(a)
    grid <- seq(a, b, length.out = 9L)
    scores <- purrr::map_dbl(grid, objective)
    interior <- which(scores[2:8] < scores[1:7] & scores[2:8] < scores[3:9]) + 1L
    c(a, b, stats::optimize(objective, c(a, b), tol = 1e-8)$minimum,
      purrr::map_dbl(interior, ~ stats::optimize(objective, grid[c(.x - 1L, .x + 1L)], tol = 1e-8)$minimum))
  }) |> unlist())
  candidates <- unique(candidates)
  candidates[which.min(purrr::map_dbl(candidates, objective))]
}

# Fit log precision at a fixed mean. The cap clips the observed knots and
# selects the existing multi-search optimiser. It does not truncate the Beta.
# Use the same quantile strategy for the loss and the returned diagnostics.
fit_constrained_beta_percentiles <- function(q, target_mean,
                                             probs = PERCENTILE_PROBS,
                                             upper_cap = NULL,
                                             quantile_function = beta_quantiles) {
  if (is.na(target_mean) || any(is.na(q))) {
    return(empty_beta_fit())
  }

  q <- condition_stage1_percentiles(q, if (is.null(upper_cap)) 1 else upper_cap)
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
    q_fit <- quantile_function(probs, alpha, beta)

    if (any(!is.finite(q_fit))) {
      return(.Machine$double.xmax)
    }
    sum((q_fit - q)^2)
  }

  log_precision <- if (is.null(upper_cap)) {
    stats::optimize(objective, interval = BETA_PRECISION_LOG_BOUNDS)$minimum
  } else {
    stage1_minimise(objective, BETA_PRECISION_LOG_BOUNDS[1], BETA_PRECISION_LOG_BOUNDS[2])
  }
  precision <- exp(log_precision)
  alpha <- target_mean * precision
  beta <- (1 - target_mean) * precision
  q_fit <- quantile_function(probs, alpha, beta)

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
