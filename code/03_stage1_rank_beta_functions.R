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

stage1_minimise <- function(objective, low, high, points = numeric()) {
  # Include boundaries and optimise around all detected local minima.
  candidates <- c(points, map2(low, high, function(a, b) {
    if (b - a < 1e-9) return(a)
    grid <- seq(a, b, length.out = 9L)
    scores <- map_dbl(grid, objective)
    interior <- which(scores[2:8] < scores[1:7] & scores[2:8] < scores[3:9]) + 1L
    c(a, b, optimize(objective, c(a, b), tol = 1e-8)$minimum,
      map_dbl(interior, ~ optimize(objective, grid[c(.x - 1L, .x + 1L)], tol = 1e-8)$minimum))
  }) |> unlist())
  candidates <- unique(candidates)
  candidates[which.min(map_dbl(candidates, objective))]
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

