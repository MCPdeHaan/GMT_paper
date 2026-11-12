# Run from the repository root after Stage 4.6 and the Step 7 budget backtest.
# This audit reads the archived pipeline inputs and writes only Step 10 CSVs.
source("code/diagnostics_step9_bilateral_aggregation_ladder.R")

STEP10_RAW_QUANTILES <- paste0("q", c(5, 25, 50, 75, 95), "_raw")
STEP10_MODELS <- c("M1_Baseline", "M1a_StatCap_LowerTail", "M1b_RankBounded_Beta")
STEP10_ABLATION <- "M1_StatCap_Only"
STEP10_OMEGAS <- seq(0, 1, by = 0.25)
STEP10_RANK_TOL <- 1e-8

step10_write <- function(data, stem) {
  write_csv(data, file.path(DIAGNOSTICS_DIR, paste0("step10_", stem, ".csv")))
}

step10_condition <- function(q, cap) {
  out <- q
  observed <- is.finite(q)
  out[observed] <- cummax(pmin(pmax(q[observed], 0), cap))
  out
}

step10_rank <- function(q) {
  lower <- which(q < GMT_RATE)
  upper <- which(q > GMT_RATE)
  p_low <- max(c(0, PERCENTILE_PROBS[lower]))
  p_high <- min(c(1, PERCENTILE_PROBS[upper]))
  q_low <- if (length(lower)) q[max(lower)] else 0
  q_high <- if (length(upper)) q[min(upper)] else 1
  c(lower = p_low, upper = p_high,
    interpolated = p_low + (p_high - p_low) * (GMT_RATE - q_low) / (q_high - q_low))
}

step10_rank_violation <- function(share, lower, upper) {
  share < lower - STEP10_RANK_TOL | share > upper + STEP10_RANK_TOL
}

step10_tail_gap <- function(mean, precision, share, raw_share) {
  if (share <= 0) return(0)
  if (!is.finite(precision)) return(pmax(0, GMT_RATE - mean))
  alpha <- mean * precision
  beta <- (1 - mean) * precision
  cutoff <- if (share == raw_share) GMT_RATE else beta_quantiles(share, alpha, beta)
  truncated_moment <- mean * pbeta(cutoff, alpha + 1, beta)
  pmax(0, GMT_RATE - pmin(1, truncated_moment / share))
}

# Search the log-precision ray, including nonmonotone CDF sections. Turning
# points bracket separate crossings of either rank bound.
step10_rank_feasibility <- function(cdf, bounds, rank) {
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
  eligible <- !step10_rank_violation(cdf((low + high) / 2), rank["lower"], rank["upper"])
  points <- intervals[!step10_rank_violation(cdf(intervals), rank["lower"], rank["upper"])]
  distances <- pmax(rank["lower"] - values, values - rank["upper"], 0)
  list(low = low[eligible], high = high[eligible], points = points,
    closest = knots[which.min(distances)])
}

step10_minimise <- function(objective, low, high, points = numeric()) {
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

step10_fit_cell <- function(raw, mean, cap, models, blends = FALSE) {
  stopifnot(length(raw) == length(PERCENTILE_PROBS), all(is.finite(raw)),
    is.finite(mean), is.finite(cap), cap >= 0, cap <= 1)
  unit_q <- step10_condition(raw, 1)
  capped_q <- step10_condition(raw, cap)
  # Preserve rank information from the published knots, even when a low
  # statutory cap moves a knot from above to below the threshold.
  rank <- step10_rank(unit_q)
  capped_rank <- step10_rank(capped_q)
  mean <- clamp_unit_interval(mean)
  boundary <- mean <= BETA_BOUNDARY_EPS || mean >= 1 - BETA_BOUNDARY_EPS
  if (boundary) mean <- round(mean)
  cdf <- function(log_precision) {
    precision <- exp(log_precision)
    pbeta(GMT_RATE, mean * precision, (1 - mean) * precision)
  }

  fit <- map_dfr(models, function(model) {
    baseline <- model == STEP10_MODELS[1]
    lower_tail <- model == STEP10_MODELS[2]
    rank_bounded <- model == STEP10_MODELS[3]
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
      feasible <- step10_rank_feasibility(cdf, bounds, rank)
      precision <- if (length(feasible$points) + length(feasible$low)) {
        exp(step10_minimise(objective, feasible$low, feasible$high, feasible$points))
      } else {
        exp(feasible$closest)
      }
      raw_share <- cdf(log(precision))
    } else {
      precision <- exp(step10_minimise(objective, bounds[1], bounds[2]))
      raw_share <- cdf(log(precision))
    }
    share <- if (rank_bounded) clamp_interval(raw_share, rank["lower"], rank["upper"]) else raw_share
    gap <- step10_tail_gap(mean, precision, share, raw_share)
    tibble(
      model, omega = NA_real_, target_mean = mean, cap,
      rank_lower = unname(rank["lower"]), rank_upper = unname(rank["upper"]),
      capped_rank_lower = unname(capped_rank["lower"]), capped_rank_upper = unname(capped_rank["upper"]),
      raw_p95_above_cap = raw[5] > cap, p95_excluded = weights[5] == 0,
      precision, alpha = mean * precision, beta = (1 - mean) * precision,
      beta_share_at_threshold = raw_share, share, gap,
      rank_projection = rank_bounded & step10_rank_violation(raw_share, rank["lower"], rank["upper"]),
      rank_violation = step10_rank_violation(share, rank["lower"], rank["upper"])
    )
  })
  if (blends) {
    base <- filter(fit, model == STEP10_MODELS[2])
    mixture <- crossing(base |> select(-omega), omega = STEP10_OMEGAS) |>
      mutate(
        model = "M1c_ProfitSkew_Adjusted_Beta",
        share = omega * beta_share_at_threshold + (1 - omega) * unname(rank["interpolated"]),
        gap = map2_dbl(share, beta_share_at_threshold,
          ~ step10_tail_gap(mean, base$precision, .x, .y)),
        rank_violation = step10_rank_violation(share, rank_lower, rank_upper)
      )
    fit <- bind_rows(fit, mixture)
  }
  mutate(fit, liability_rate = share * gap)
}

step10_fit_rows <- function(data, qcols, key, models, blends = FALSE) {
  q <- as.matrix(data[qcols])
  map_dfr(seq_len(nrow(data)), function(i) {
    bind_cols(data[rep(i, length(models) + if (blends) length(STEP10_OMEGAS) else 0L), key],
      step10_fit_cell(q[i, ], data$target_mean[i], data$affiliate_etr_cap_stage1[i], models, blends))
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
        archive_low_share = percentile_low_share, archive_liability_rate = percentile_liability_rate)
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
        p95_above_cap_n = sum(data$raw_p95_above_cap),
        p95_excluded_n = sum(data$p95_excluded),
        mean_above_cap_n = sum(data$target_mean > data$cap + 1e-8),
        cap_changes_rank_n = sum(data$rank_lower != data$capped_rank_lower |
          data$rank_upper != data$capped_rank_upper),
        u_shaped_n = sum(data$alpha < 1 & data$beta < 1, na.rm = TRUE),
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
