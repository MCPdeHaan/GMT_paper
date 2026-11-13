# Run from the repository root after Stage 4.6 and the Step 7 budget backtest.
# This audit reads the archived pipeline inputs and writes only Step 10 CSVs.
source("code/diagnostics_step9_bilateral_aggregation_ladder.R")

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

run_step10_diagnostics <- function() {
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

if (sys.nframe() == 0L) {
  run_step10_diagnostics()
}
