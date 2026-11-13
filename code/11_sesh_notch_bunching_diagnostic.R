# 11_sesh_notch_bunching_diagnostic.R
# Diagnostic for the Simplified ETR Safe Harbour notch.
#
# Public CbCR currently observes the pre-reform ETR distribution. This script
# therefore estimates exposure around the 15 per cent threshold and a placebo
# bunching diagnostic. It does not identify realised post-SESH bunching.

source("code/00_helpers.R", local = TRUE)

source("code/05_stage3_behavioral.R", local = TRUE)


NOTCH_BIN_WIDTH <- 0.005
NOTCH_POLYNOMIAL_ORDER <- 4L
NOTCH_ESTIMATION_LOWER <- 0
NOTCH_ESTIMATION_UPPER <- 0.30
NOTCH_EXCLUDED_BANDWIDTH <- 0.02

build_etr_density_bins <- function(etr, weight = NULL,
                                   bin_width = NOTCH_BIN_WIDTH,
                                   lower = NOTCH_ESTIMATION_LOWER,
                                   upper = NOTCH_ESTIMATION_UPPER) {
  if (is.null(weight)) weight <- rep(1, length(etr))

  raw <- tibble(etr = etr, weight = weight) |>
    filter(
      is.finite(etr),
      is.finite(weight),
      weight > 0,
      etr >= lower,
      etr <= upper
    ) |>
    mutate(
      bin_id = pmin(
        floor((etr - lower) / bin_width),
        as.integer(round((upper - lower) / bin_width)) - 1L
      ),
      bin_lower = lower + bin_id * bin_width
    )

  bin_template <- tibble(
    bin_lower = seq(lower, upper - bin_width, by = bin_width),
    bin_upper = bin_lower + bin_width,
    bin_midpoint = bin_lower + bin_width / 2
  )

  binned <- raw |>
    group_by(bin_lower) |>
    summarise(
      observed_count = n(),
      observed_weight = sum(weight, na.rm = TRUE),
      .groups = "drop"
    )

  total_weight <- sum(raw$weight, na.rm = TRUE)

  bin_template |>
    left_join(binned, by = "bin_lower") |>
    mutate(
      observed_count = coalesce(observed_count, 0L),
      observed_weight = coalesce(observed_weight, 0),
      observed_share = if (total_weight > 0) {
        observed_weight / total_weight
      } else {
        NA_real_
      }
    )
}

fit_notch_counterfactual_density <- function(binned_density,
                                             threshold = GMT_RATE,
                                             excluded_bandwidth =
                                               NOTCH_EXCLUDED_BANDWIDTH,
                                             polynomial_order =
                                               NOTCH_POLYNOMIAL_ORDER) {
  estimation_bins <- binned_density |>
    filter(
      is.finite(observed_share),
      !(bin_midpoint >= threshold - excluded_bandwidth &
        bin_midpoint < threshold + excluded_bandwidth)
    )

  effective_order <- min(
    as.integer(polynomial_order),
    max(nrow(estimation_bins) - 2L, 1L)
  )

  fit <- stats::lm(
    observed_share ~ stats::poly(bin_midpoint, effective_order, raw = TRUE),
    data = estimation_bins
  )

  predicted <- pmax(
    stats::predict(fit, newdata = binned_density),
    0
  )
  observed_total <- sum(binned_density$observed_share, na.rm = TRUE)
  predicted_total <- sum(predicted, na.rm = TRUE)

  binned_density |>
    mutate(
      counterfactual_share = if (predicted_total > 0) {
        predicted * observed_total / predicted_total
      } else {
        NA_real_
      },
      estimation_bin = !(bin_midpoint >= threshold - excluded_bandwidth &
        bin_midpoint < threshold + excluded_bandwidth),
      polynomial_order = effective_order,
      excluded_bandwidth = excluded_bandwidth
    )
}

summarise_notch_counterfactual <- function(fitted_density,
                                           threshold = GMT_RATE,
                                           bunching_bandwidth =
                                             SESH_BANDWIDTH_BASELINE) {
  dominated_region <- fitted_density |>
    filter(
      bin_lower >= threshold - bunching_bandwidth,
      bin_upper <= threshold
    )

  threshold_bin <- fitted_density |>
    filter(bin_lower <= threshold, bin_upper > threshold)

  observed_dominated <- sum(dominated_region$observed_share, na.rm = TRUE)
  counterfactual_dominated <-
    sum(dominated_region$counterfactual_share, na.rm = TRUE)
  observed_threshold <- sum(threshold_bin$observed_share, na.rm = TRUE)
  counterfactual_threshold <-
    sum(threshold_bin$counterfactual_share, na.rm = TRUE)

  missing_mass <- counterfactual_dominated - observed_dominated
  excess_mass <- observed_threshold - counterfactual_threshold
  responsive_share <- clamp_unit_interval(
    safe_divide(pmax(missing_mass, 0), counterfactual_dominated)
  )

  tibble(
    threshold = threshold,
    bunching_bandwidth = bunching_bandwidth,
    observed_dominated_mass = observed_dominated,
    counterfactual_dominated_mass = counterfactual_dominated,
    placebo_missing_mass = missing_mass,
    observed_threshold_mass = observed_threshold,
    counterfactual_threshold_mass = counterfactual_threshold,
    placebo_excess_mass = excess_mass,
    implied_responsive_share_if_post_reform = responsive_share,
    implied_friction_share_if_post_reform = 1 - responsive_share,
    interpretation = paste(
      "Pre-reform placebo and exposure diagnostic only;",
      "not a structural estimate of post-SESH bunching."
    )
  )
}

notch_bunching_probability <- function(etr,
                                       threshold = GMT_RATE,
                                       bunching_bandwidth =
                                         SESH_BANDWIDTH_BASELINE,
                                       responsive_share = 1,
                                       curvature = 1) {
  gap <- threshold - etr
  in_band <- is.finite(gap) & gap > 0 & gap <= bunching_bandwidth
  probability <- rep(0, length(etr))
  probability[in_band] <- responsive_share *
    (1 - gap[in_band] / bunching_bandwidth)^curvature
  clamp_unit_interval(probability)
}

prepare_notch_sample <- function(stage1_affiliate_year, sample_name) {
  stage1_affiliate_year |>
    filter(
      stage1_positive_profit_flag,
      is.finite(avg_etr_stage1),
      is.finite(total_analysis_profit_positive),
      total_analysis_profit_positive > 0
    ) |>
    mutate(sample = sample_name) |>
    select(
      sample, affiliate, affiliate_name, affiliate_is_eu27, year,
      avg_etr_stage1, total_analysis_profit_positive
    )
}

estimate_notch_sample <- function(notch_sample,
                                  bin_width = NOTCH_BIN_WIDTH,
                                  polynomial_order = NOTCH_POLYNOMIAL_ORDER,
                                  threshold = GMT_RATE,
                                  excluded_bandwidth =
                                    NOTCH_EXCLUDED_BANDWIDTH,
                                  bunching_bandwidth =
                                    SESH_BANDWIDTH_BASELINE) {
  density <- build_etr_density_bins(
    notch_sample$avg_etr_stage1,
    notch_sample$total_analysis_profit_positive,
    bin_width = bin_width
  ) |>
    fit_notch_counterfactual_density(
      threshold = threshold,
      excluded_bandwidth = excluded_bandwidth,
      polynomial_order = polynomial_order
    )

  summary <- summarise_notch_counterfactual(
    density,
    threshold = threshold,
    bunching_bandwidth = bunching_bandwidth
  ) |>
    mutate(
      affiliate_years = nrow(notch_sample),
      weighted_profit = sum(notch_sample$total_analysis_profit_positive,
        na.rm = TRUE
      ),
      bin_width = bin_width,
      polynomial_order = first(density$polynomial_order),
      excluded_bandwidth = excluded_bandwidth,
      .before = 1
    )

  assignments <- notch_sample |>
    mutate(
      distance_to_threshold = threshold - avg_etr_stage1,
      in_sesh_band = distance_to_threshold > 0 &
        distance_to_threshold <= bunching_bandwidth,
      upper_bound_bunching_probability = notch_bunching_probability(
        avg_etr_stage1,
        threshold = threshold,
        bunching_bandwidth = bunching_bandwidth,
        responsive_share = 1
      ),
      placebo_calibrated_bunching_probability =
        notch_bunching_probability(
          avg_etr_stage1,
          threshold = threshold,
          bunching_bandwidth = bunching_bandwidth,
          responsive_share =
            summary$implied_responsive_share_if_post_reform[1]
        )
    )

  list(density = density, summary = summary, assignments = assignments)
}

run_sesh_notch_bunching_diagnostic <- function() {
  dir.create(DIAGNOSTICS_DIR, showWarnings = FALSE, recursive = TRUE)
  stage1_affiliate_year <- readRDS(file.path(PROCESSED_DIR, "stage1_affiliate_year.rds"))

  samples <- bind_rows(
    prepare_notch_sample(stage1_affiliate_year, "global"),
    prepare_notch_sample(
      stage1_affiliate_year |> filter(affiliate_is_eu27),
      "eu27"
    )
  )

  sample_splits <- samples |>
    group_split(sample)
  names(sample_splits) <- map_chr(sample_splits, ~ first(.x$sample))

  results <- map(sample_splits, estimate_notch_sample)

  density <- imap_dfr(results, ~ mutate(.x$density, sample = .y, .before = 1))
  summary <- imap_dfr(results, ~ mutate(.x$summary, sample = .y, .before = 1))
  assignments <- imap_dfr(results, ~ .x$assignments)

  write_csv(
    density,
    file.path(DIAGNOSTICS_DIR, "step11_sesh_notch_density_bins.csv")
  )
  write_csv(
    summary,
    file.path(DIAGNOSTICS_DIR, "step11_sesh_notch_summary.csv")
  )
  write_csv(
    assignments,
    file.path(DIAGNOSTICS_DIR, "step11_sesh_notch_assignment.csv")
  )

  saveRDS(density, file.path(PROCESSED_DIR, "sesh_notch_density_bins.rds"))
  saveRDS(summary, file.path(PROCESSED_DIR, "sesh_notch_summary.rds"))
  saveRDS(assignments, file.path(PROCESSED_DIR, "sesh_notch_assignment.rds"))

  message("\nStep 11 outputs written:")
  message(" - data/processed/sesh_notch_*.rds")
  message(" - diagnostics/step11_sesh_notch_*.csv")

  invisible(list(
    density = density,
    summary = summary,
    assignments = assignments
  ))
}

if (is_direct_script_run("code/11_sesh_notch_bunching_diagnostic.R")) {
  run_sesh_notch_bunching_diagnostic()
}
