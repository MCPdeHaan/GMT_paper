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
    caps <- pmin(1, coalesce(fit_inputs$affiliate_cit_rate_unit + ZETA_LOSS_OFFSET, 1))
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

