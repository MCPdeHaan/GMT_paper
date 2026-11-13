# Profit reconciliation uncertainty and the Stage 1 measurement-error simulation.

source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "05_stage3_behavioral.R"), local = TRUE)
source(file.path(GMT_PROJECT_ROOT, "code", "06_stage4_5_revenue_allocation_sbs.R"), local = TRUE)
source(file.path(GMT_PROJECT_ROOT, "code", "07_stage4_6_revenue_pipeline_decomposition.R"), local = TRUE)

# Legacy profit reconciliation uncertainty

FOREIGN_HOLDING_CHAIN_AFFILIATES <- c(
  "NLD", "LUX", "IRL", "CHE", "SGP", "HKG", "BMU", "CYM"
)
FOREIGN_HOLDING_CHAIN_RATE <- 0.10

compute_draw_phi <- function(sbie, profit) {
  clamp_interval(safe_divide(sbie, profit), 0, 1)
}

build_utpr_eu_shares <- function(in_dir = PROCESSED_DIR) {
  parent_year_weights <- readRDS(
    file.path(in_dir, "stage4_5_utpr_parent_year_weights.rds")
  )
  fallback_weights <- readRDS(
    file.path(in_dir, "stage4_5_utpr_fallback_weights.rds")
  )

  parent_year <- parent_year_weights |>
    group_by(parent, year) |>
    summarise(
      eu27_utpr_share_parent_year =
        sum(if_else(collector_is_eu27, utpr_weight, 0), na.rm = TRUE),
      .groups = "drop"
    )

  fallback <- fallback_weights |>
    group_by(year) |>
    summarise(
      eu27_utpr_share_fallback =
        sum(if_else(collector_is_eu27, utpr_weight, 0), na.rm = TRUE),
      .groups = "drop"
    )

  list(parent_year = parent_year, fallback = fallback)
}

build_preferred_source_panel <- function(in_dir = PROCESSED_DIR) {
  utpr_shares <- build_utpr_eu_shares(in_dir)

  readRDS(file.path(in_dir, "stage4_5_allocation_source_panel.rds")) |>
    filter(
      factor1_etr == "distributional",
      factor2_substance == "aggregate_sbie",
      rate_scenario == "initial",
      factor5_behaviour == "behavioural",
      factor4_sbs %in% c("universal", "sbs"),
      year %in% MAIN_YEARS
    ) |>
    select(
      parent, affiliate, year, factor4_sbs,
      profit_panelai, profit_adj_panelai, is_domestic,
      rpr_panelai, tot_rev_panelai, assets_panelai, employees_panelai,
      holding_share_panelai, affiliate_is_conduit_haven,
      profit_panelai_uncorrected, profit_panelai_corrected_low,
      analysis_profit_base, profit_panelai_corrected_high,
      stage2_sbie, stage1_distributional_low_share,
      stage1_distributional_liability_rate, sectoral_scale_selected,
      behavioural_liability_filter, qdmtt_flag, parent_iir_utpr_flag,
      sbs_exempt
    ) |>
    left_join(utpr_shares$parent_year, by = c("parent", "year")) |>
    left_join(utpr_shares$fallback, by = "year") |>
    mutate(
      eu27_utpr_share = coalesce(
        eu27_utpr_share_parent_year,
        eu27_utpr_share_fallback,
        0
      ),
      parent_is_eu27 = parent %in% EU27_ISO3,
      affiliate_is_eu27 = affiliate %in% EU27_ISO3,
      sectoral_scale_selected = coalesce(sectoral_scale_selected, 1),
      behavioural_liability_filter = coalesce(behavioural_liability_filter, 1),
      stage1_distributional_low_share =
        coalesce(stage1_distributional_low_share, 0),
      stage1_distributional_liability_rate =
        coalesce(stage1_distributional_liability_rate, 0),
      stage2_sbie = coalesce(stage2_sbie, 0),
      qdmtt_flag = coalesce(qdmtt_flag, FALSE),
      parent_iir_utpr_flag = coalesce(parent_iir_utpr_flag, FALSE),
      sbs_exempt = coalesce(sbs_exempt, FALSE)
    )
}

add_foreign_holding_chain_flags <- function(source_panel) {
  source_panel |>
    mutate(
      related_party_revenue_share = clamp_interval(
        safe_divide(rpr_panelai, tot_rev_panelai),
        0,
        1
      ),
      profit_to_assets_reconciliation =
        safe_divide(analysis_profit_base, assets_panelai),
      profit_per_employee_reconciliation =
        safe_divide(analysis_profit_base, employees_panelai),
      foreign_holding_chain_correction_flag =
        !is_domestic &
          affiliate %in% FOREIGN_HOLDING_CHAIN_AFFILIATES &
          coalesce(analysis_profit_base, 0) > 0 &
          coalesce(holding_share_panelai, 0) >= 0.30 &
          coalesce(related_party_revenue_share, 0) >= 0.50 &
          (
            coalesce(profit_per_employee_reconciliation, 0) >= 1e6 |
              coalesce(profit_to_assets_reconciliation, 0) >= 1
          ),
      profit_foreign_holding_chain_sensitivity = if_else(
        foreign_holding_chain_correction_flag,
        analysis_profit_base * (1 - FOREIGN_HOLDING_CHAIN_RATE),
        analysis_profit_base
      )
    )
}

compute_preferred_revenue_from_profit <- function(source_panel, profit_value,
                                                  specification,
                                                  draw_id = NA_integer_) {
  source_panel |>
    mutate(
      profit_draw = pmax(coalesce(profit_value, 0), 0),
      phi_draw = compute_draw_phi(stage2_sbie, profit_draw),
      stage2_filter_draw = if_else(profit_draw > 0, 1 - phi_draw, 1),
      stage1_topup_draw =
        pmax(stage1_distributional_liability_rate * profit_draw, 0),
      topup_after_stage2_draw = pmax(
        stage1_topup_draw * stage2_filter_draw * sectoral_scale_selected,
        0
      ),
      topup_after_behaviour_draw =
        pmax(topup_after_stage2_draw * behavioural_liability_filter, 0),
      qdmtt_liability_draw =
        if_else(qdmtt_flag, topup_after_behaviour_draw, 0),
      iir_liability_draw = if_else(
        !qdmtt_flag & parent_iir_utpr_flag & !sbs_exempt,
        topup_after_behaviour_draw,
        0
      ),
      utpr_pool_draw = if_else(
        !qdmtt_flag & !parent_iir_utpr_flag & !sbs_exempt,
        topup_after_behaviour_draw,
        0
      ),
      sbs_extinguished_draw = if_else(
        !qdmtt_flag & sbs_exempt,
        topup_after_behaviour_draw,
        0
      ),
      eu27_revenue_draw =
        if_else(affiliate_is_eu27, qdmtt_liability_draw, 0) +
          if_else(parent_is_eu27, iir_liability_draw, 0) +
          utpr_pool_draw * eu27_utpr_share
    ) |>
    group_by(factor4_sbs) |>
    summarise(
      draw_id = draw_id,
      specification = specification,
      positive_profit = sum(profit_draw, na.rm = TRUE),
      global_allocated_revenue =
        sum(qdmtt_liability_draw + iir_liability_draw + utpr_pool_draw,
          na.rm = TRUE
        ),
      eu27_final_revenue = sum(eu27_revenue_draw, na.rm = TRUE),
      eu27_qdmtt_revenue =
        sum(if_else(affiliate_is_eu27, qdmtt_liability_draw, 0),
          na.rm = TRUE
        ),
      eu27_iir_revenue =
        sum(if_else(parent_is_eu27, iir_liability_draw, 0), na.rm = TRUE),
      eu27_utpr_revenue = sum(utpr_pool_draw * eu27_utpr_share, na.rm = TRUE),
      sbs_extinguished_revenue = sum(sbs_extinguished_draw, na.rm = TRUE),
      .groups = "drop"
    )
}

build_point_revenue_sensitivity <- function(source_panel) {
  bind_rows(
    compute_preferred_revenue_from_profit(
      source_panel,
      source_panel$profit_panelai_uncorrected,
      "uncorrected"
    ),
    compute_preferred_revenue_from_profit(
      source_panel,
      source_panel$profit_panelai_corrected_low,
      "low_correction"
    ),
    compute_preferred_revenue_from_profit(
      source_panel,
      source_panel$analysis_profit_base,
      "preferred_correction"
    ),
    compute_preferred_revenue_from_profit(
      source_panel,
      source_panel$profit_foreign_holding_chain_sensitivity,
      "foreign_holding_chain_correction"
    ),
    compute_preferred_revenue_from_profit(
      source_panel,
      source_panel$profit_panelai_corrected_high,
      "high_correction"
    )
  )
}

build_foreign_holding_chain_summary <- function(source_panel) {
  source_panel |>
    filter(factor4_sbs == "sbs") |>
    mutate(
      flagged_profit_reduction =
        analysis_profit_base - profit_foreign_holding_chain_sensitivity
    ) |>
    summarise(
      sensitivity = "foreign_holding_chain_correction",
      affiliate_scope = paste(FOREIGN_HOLDING_CHAIN_AFFILIATES, collapse = ";"),
      correction_rate = FOREIGN_HOLDING_CHAIN_RATE,
      flagged_cells = sum(foreign_holding_chain_correction_flag, na.rm = TRUE),
      flagged_parents =
        n_distinct(parent[foreign_holding_chain_correction_flag]),
      flagged_affiliates =
        n_distinct(affiliate[foreign_holding_chain_correction_flag]),
      flagged_profit =
        sum(analysis_profit_base[foreign_holding_chain_correction_flag],
          na.rm = TRUE
        ),
      profit_reduction = sum(flagged_profit_reduction, na.rm = TRUE),
      mean_holding_share = weighted_mean_available(
        holding_share_panelai[foreign_holding_chain_correction_flag],
        analysis_profit_base[foreign_holding_chain_correction_flag]
      ),
      mean_related_party_revenue_share = weighted_mean_available(
        related_party_revenue_share[foreign_holding_chain_correction_flag],
        analysis_profit_base[foreign_holding_chain_correction_flag]
      )
    )
}

build_draw_revenue_sensitivity <- function(source_panel, predictions,
                                           n_draws = 500,
                                           seed = 20260613) {
  draw_parent_year <- predictions |>
    filter(year %in% MAIN_YEARS) |>
    select(parent, year, posterior_y, posterior_sd)

  set.seed(seed)
  bind_rows(lapply(seq_len(n_draws), function(draw_id) {
    draws <- draw_parent_year |>
      mutate(
        draw_id = draw_id,
        rho_draw = inverse_bounded_logit(
          stats::rnorm(n(), posterior_y, posterior_sd)
        )
      ) |>
      select(parent, year, rho_draw)

    draw_panel <- source_panel |>
      left_join(draws, by = c("parent", "year")) |>
      mutate(
        profit_draw = case_when(
          !is.na(profit_adj_panelai) ~ profit_adj_panelai,
          is_domestic ~ profit_panelai * (1 - rho_draw),
          TRUE ~ profit_panelai
        )
      )

    compute_preferred_revenue_from_profit(
      draw_panel,
      draw_panel$profit_draw,
      "rho_draw",
      draw_id = draw_id
    )
  }))
}

summarise_draw_revenue <- function(draws) {
  draws |>
    group_by(factor4_sbs, specification) |>
    summarise(
      draws = n_distinct(draw_id),
      positive_profit_mean = mean(positive_profit, na.rm = TRUE),
      positive_profit_p025 = quantile(positive_profit, 0.025, na.rm = TRUE),
      positive_profit_p975 = quantile(positive_profit, 0.975, na.rm = TRUE),
      global_revenue_mean = mean(global_allocated_revenue, na.rm = TRUE),
      global_revenue_p025 =
        quantile(global_allocated_revenue, 0.025, na.rm = TRUE),
      global_revenue_p975 =
        quantile(global_allocated_revenue, 0.975, na.rm = TRUE),
      eu27_revenue_mean = mean(eu27_final_revenue, na.rm = TRUE),
      eu27_revenue_p025 = quantile(eu27_final_revenue, 0.025, na.rm = TRUE),
      eu27_revenue_p975 = quantile(eu27_final_revenue, 0.975, na.rm = TRUE),
      eu27_qdmtt_mean = mean(eu27_qdmtt_revenue, na.rm = TRUE),
      eu27_iir_mean = mean(eu27_iir_revenue, na.rm = TRUE),
      eu27_utpr_mean = mean(eu27_utpr_revenue, na.rm = TRUE),
      sbs_extinguished_mean = mean(sbs_extinguished_revenue, na.rm = TRUE),
      .groups = "drop"
    )
}

run_profit_correction_revenue_uncertainty <- function(in_dir = PROCESSED_DIR,
                                                      out_dir = PROCESSED_DIR,
                                                      n_draws = 500,
                                                      seed = 20260613) {
  diag_dir <- file.path(out_dir, "diagnostics")
  dir.create(diag_dir, showWarnings = FALSE, recursive = TRUE)

  source_panel <- build_preferred_source_panel(in_dir) |>
    add_foreign_holding_chain_flags()
  predictions <- readRDS(file.path(in_dir, "profit_correction_parent_year.rds"))

  point_sensitivity <- build_point_revenue_sensitivity(source_panel)
  holding_chain_summary <- build_foreign_holding_chain_summary(source_panel)
  draw_sensitivity <- build_draw_revenue_sensitivity(
    source_panel,
    predictions,
    n_draws = n_draws,
    seed = seed
  )
  draw_interval <- summarise_draw_revenue(draw_sensitivity)

  write_csv(
    point_sensitivity,
    file.path(diag_dir, "step07a_profit_correction_final_revenue_points.csv")
  )
  write_csv(
    holding_chain_summary,
    file.path(diag_dir, "step07a_profit_correction_foreign_holding_chain.csv")
  )
  write_csv(
    draw_sensitivity,
    file.path(diag_dir, "step07a_profit_correction_final_revenue_draws.csv")
  )
  write_csv(
    draw_interval,
    file.path(diag_dir, "step07a_profit_correction_final_revenue_interval.csv")
  )

  saveRDS(
    list(
      points = point_sensitivity,
      foreign_holding_chain = holding_chain_summary,
      draws = draw_sensitivity,
      interval = draw_interval
    ),
    file.path(out_dir, "profit_correction_final_revenue_uncertainty.rds")
  )

  invisible(list(
    points = point_sensitivity,
    foreign_holding_chain = holding_chain_summary,
    draws = draw_sensitivity,
    interval = draw_interval
  ))
}

# Legacy Stage 1 measurement-error simulation

MEASUREMENT_ERROR_DRAWS <- 500L
MEASUREMENT_ERROR_SEED <- 20260503L
SIM_CONSERVATION_TOLERANCE <- 1

measurement_low_mean_etr <- function(low_share, topup_rate,
                                     threshold = GMT_RATE) {
  if_else(
    !is.na(low_share) & low_share > 0 & !is.na(topup_rate),
    threshold - pmin(pmax(topup_rate, 0), threshold),
    NA_real_
  )
}

calibrate_stage1_measurement_error <- function(crossval_affiliate_year,
                                               threshold = GMT_RATE) {
  calibration_sample <- crossval_affiliate_year |>
    filter(
      is.finite(percentile_low_share),
      is.finite(direct_low_share),
      is.finite(percentile_topup_rate),
      is.finite(direct_topup_rate)
    ) |>
    mutate(
      table_i_low_mean_etr = measurement_low_mean_etr(
        percentile_low_share,
        percentile_topup_rate,
        threshold
      ),
      table_iv_low_mean_etr = measurement_low_mean_etr(
        direct_low_share,
        direct_topup_rate,
        threshold
      ),
      low_share_error_raw = direct_low_share - percentile_low_share,
      low_mean_etr_error_raw =
        table_iv_low_mean_etr - table_i_low_mean_etr
    )

  low_share_errors <- calibration_sample$low_share_error_raw
  low_share_errors <- low_share_errors - mean(low_share_errors, na.rm = TRUE)

  low_mean_errors <- calibration_sample |>
    filter(is.finite(low_mean_etr_error_raw)) |>
    pull(low_mean_etr_error_raw)
  low_mean_errors <- low_mean_errors - mean(low_mean_errors, na.rm = TRUE)

  if (length(low_share_errors) == 0 || length(low_mean_errors) == 0) {
    stop("Measurement-error calibration has no usable validation residuals")
  }

  summary <- tibble(
    metric = c(
      "calibration_affiliate_years",
      "low_mean_etr_calibration_affiliate_years",
      "low_share_raw_bias_table_iv_minus_table_i",
      "low_share_raw_sd",
      "low_share_raw_p05",
      "low_share_raw_p50",
      "low_share_raw_p95",
      "low_mean_etr_raw_bias_table_iv_minus_table_i",
      "low_mean_etr_raw_sd",
      "low_mean_etr_raw_p05",
      "low_mean_etr_raw_p50",
      "low_mean_etr_raw_p95"
    ),
    value = c(
      nrow(calibration_sample),
      sum(is.finite(calibration_sample$low_mean_etr_error_raw)),
      mean(calibration_sample$low_share_error_raw, na.rm = TRUE),
      stats::sd(calibration_sample$low_share_error_raw, na.rm = TRUE),
      stats::quantile(calibration_sample$low_share_error_raw, 0.05,
        na.rm = TRUE, names = FALSE
      ),
      stats::quantile(calibration_sample$low_share_error_raw, 0.50,
        na.rm = TRUE, names = FALSE
      ),
      stats::quantile(calibration_sample$low_share_error_raw, 0.95,
        na.rm = TRUE, names = FALSE
      ),
      mean(calibration_sample$low_mean_etr_error_raw, na.rm = TRUE),
      stats::sd(calibration_sample$low_mean_etr_error_raw, na.rm = TRUE),
      stats::quantile(calibration_sample$low_mean_etr_error_raw, 0.05,
        na.rm = TRUE, names = FALSE
      ),
      stats::quantile(calibration_sample$low_mean_etr_error_raw, 0.50,
        na.rm = TRUE, names = FALSE
      ),
      stats::quantile(calibration_sample$low_mean_etr_error_raw, 0.95,
        na.rm = TRUE, names = FALSE
      )
    )
  )

  list(
    calibration_sample = calibration_sample,
    low_share_errors = low_share_errors,
    low_mean_etr_errors = low_mean_errors,
    summary = summary
  )
}

draw_stage1_measurement_error <- function(stage1_affiliate_year,
                                          calibration,
                                          n_draws = MEASUREMENT_ERROR_DRAWS,
                                          seed = MEASUREMENT_ERROR_SEED,
                                          threshold = GMT_RATE) {
  if (!is.null(seed)) set.seed(seed)

  base <- stage1_affiliate_year |>
    select(
      affiliate, year, stage1_positive_profit_flag,
      baseline_low_share = stage1_distributional_low_share,
      baseline_topup_rate = stage1_distributional_topup_rate
    ) |>
    mutate(
      baseline_low_mean_etr = measurement_low_mean_etr(
        baseline_low_share,
        baseline_topup_rate,
        threshold
      ),
      baseline_low_mean_etr = if_else(
        !is.na(baseline_low_share) & baseline_low_share == 0,
        threshold,
        baseline_low_mean_etr
      )
    )

  draws <- tidyr::crossing(draw_id = seq_len(n_draws), base)
  n <- nrow(draws)

  draws |>
    mutate(
      low_share_error = sample(calibration$low_share_errors, n, replace = TRUE),
      low_mean_etr_error = sample(calibration$low_mean_etr_errors, n,
        replace = TRUE
      ),
      draw_low_share = case_when(
        !stage1_positive_profit_flag | is.na(baseline_low_share) ~ NA_real_,
        TRUE ~ pmin(pmax(baseline_low_share + low_share_error, 0), 1)
      ),
      draw_low_mean_etr = case_when(
        is.na(draw_low_share) | draw_low_share <= 0 ~ NA_real_,
        TRUE ~ pmin(
          pmax(coalesce(baseline_low_mean_etr, threshold) +
            low_mean_etr_error, 0),
          threshold
        )
      ),
      draw_topup_rate = if_else(
        !is.na(draw_low_share) & draw_low_share > 0,
        threshold - draw_low_mean_etr,
        0
      ),
      draw_liability_rate = draw_low_share * draw_topup_rate
    ) |>
    select(
      draw_id, affiliate, year,
      low_share_error, low_mean_etr_error,
      draw_low_share, draw_low_mean_etr,
      draw_topup_rate, draw_liability_rate
    )
}

stage1_draw_for_id <- function(stage1_draws, draw_id) {
  stage1_draws |>
    filter(.data$draw_id == .env$draw_id)
}

apply_stage1_measurement_draw <- function(stage1_affiliate_year,
                                          stage1_draw) {
  stage1_draw_rates <- stage1_draw |>
    select(
      affiliate, year,
      draw_low_share, draw_topup_rate, draw_liability_rate
    )

  stage1_affiliate_year |>
    left_join(stage1_draw_rates, by = c("affiliate", "year")) |>
    mutate(
      stage1_distributional_low_share = draw_low_share,
      stage1_distributional_topup_rate = draw_topup_rate,
      stage1_distributional_liability_rate = draw_liability_rate
    ) |>
    select(-draw_low_share, -draw_topup_rate, -draw_liability_rate)
}

recompute_stage2_distributional <- function(stage2_bilateral,
                                            stage1_draw_affiliate_year,
                                            threshold = GMT_RATE) {
  draw_rates <- stage1_draw_affiliate_year |>
    select(
      affiliate, year,
      draw_low_share = stage1_distributional_low_share,
      draw_topup_rate = stage1_distributional_topup_rate,
      draw_liability_rate = stage1_distributional_liability_rate
    )

  stage2_bilateral |>
    left_join(draw_rates, by = c("affiliate", "year")) |>
    mutate(
      stage1_distributional_low_share = draw_low_share,
      stage1_distributional_topup_rate = draw_topup_rate,
      stage1_distributional_liability_rate = draw_liability_rate,
      stage1_lowtax_profit_distributional =
        stage1_distributional_low_share * analysis_profit_positive,
      stage1_topup_tax_distributional =
        stage1_lowtax_profit_distributional *
          stage1_distributional_topup_rate,
      stage2_sbie_shield_distributional =
        stage1_lowtax_profit_distributional * coalesce(stage2_phi, 0),
      stage2_excess_lowtax_profit_distributional =
        stage1_lowtax_profit_distributional * stage2_filter,
      stage2_topup_tax_distributional =
        coalesce(stage1_topup_tax_distributional, 0) * stage2_filter,
      stage2_effective_floor_distributional =
        compute_effective_floor(
          stage1_distributional_topup_rate, stage2_phi,
          threshold
        )
    ) |>
    select(-draw_low_share, -draw_topup_rate, -draw_liability_rate)
}

update_stage2_sectoral_distributional <- function(stage2_sectoral_matrix,
                                                  stage1_draw_affiliate_year) {
  draw_rates_2022 <- stage1_draw_affiliate_year |>
    filter(year == SECTORAL_REFERENCE_YEAR) |>
    select(
      affiliate,
      draw_distributional_topup_rate = stage1_distributional_topup_rate
    )

  stage2_sectoral_matrix |>
    left_join(draw_rates_2022, by = "affiliate") |>
    mutate(
      stage1_distributional_topup_rate =
        coalesce(
          draw_distributional_topup_rate,
          stage1_distributional_topup_rate
        ),
      sectoral_floor_distributional = compute_effective_floor(
        stage1_distributional_topup_rate,
        sectoral_phi
      ),
      sectoral_floor_distributional_sbti = apply_sbti_capacity_overlay(
        sectoral_floor_distributional,
        sectoral_kappa
      ),
      sectoral_delta_floor_distributional =
        sectoral_floor_distributional_sbti - sectoral_floor_distributional
    ) |>
    select(-draw_distributional_topup_rate)
}

update_behavioural_affiliate_year <- function(behavioural_affiliate_year,
                                              stage1_draw_affiliate_year,
                                              threshold = GMT_RATE) {
  draw_rates <- stage1_draw_affiliate_year |>
    select(
      affiliate, year,
      draw_low_share = stage1_distributional_low_share,
      draw_topup_rate = stage1_distributional_topup_rate
    )

  out <- behavioural_affiliate_year |>
    left_join(draw_rates, by = c("affiliate", "year")) |>
    mutate(
      update_row = etr_measurement == "distributional" &
        !is.na(draw_low_share),
      stage1_low_share = if_else(update_row, draw_low_share,
        stage1_low_share
      ),
      stage1_topup_rate = if_else(update_row, draw_topup_rate,
        stage1_topup_rate
      ),
      tau_low = if_else(
        update_row,
        if_else(stage1_low_share > 0 & stage1_topup_rate > 0,
          threshold - stage1_topup_rate,
          NA_real_
        ),
        tau_low
      ),
      beta_raw_unclamped = if_else(
        update_row & !is.na(tau_low),
        compute_reallocation_share(
          tau = tau_low,
          model_spec = model_spec,
          beta3 = beta3,
          beta4 = beta4,
          t0 = t0,
          threshold = threshold
        ),
        beta_raw
      ),
      beta_sign_restricted_flag = if_else(
        update_row,
        beta_raw_unclamped < 0 | beta_raw_unclamped > 1,
        beta_sign_restricted_flag
      ),
      beta_raw = if_else(
        update_row,
        pmin(pmax(coalesce(beta_raw_unclamped, 0), 0), 1),
        beta_raw
      )
    )

  regimes <- apply_behavioural_regime(
    tau_low = out$tau_low,
    beta_raw = out$beta_raw,
    eta = out$eta,
    threshold = threshold
  )

  out |>
    mutate(
      beta_applied = regimes$beta_applied,
      behavioural_liability_filter = regimes$behavioural_liability_filter,
      behavioural_regime = regimes$behavioural_regime
    ) |>
    select(
      -draw_low_share, -draw_topup_rate, -update_row,
      -beta_raw_unclamped
    )
}

summarise_draw_interval <- function(draws, value_col, group_vars) {
  draws |>
    group_by(across(all_of(group_vars))) |>
    summarise(
      draws = n(),
      mean = mean(.data[[value_col]], na.rm = TRUE),
      sd = stats::sd(.data[[value_col]], na.rm = TRUE),
      p025 = stats::quantile(.data[[value_col]], 0.025,
        na.rm = TRUE,
        names = FALSE
      ),
      p05 = stats::quantile(.data[[value_col]], 0.05,
        na.rm = TRUE,
        names = FALSE
      ),
      p50 = stats::quantile(.data[[value_col]], 0.50,
        na.rm = TRUE,
        names = FALSE
      ),
      p95 = stats::quantile(.data[[value_col]], 0.95,
        na.rm = TRUE,
        names = FALSE
      ),
      p975 = stats::quantile(.data[[value_col]], 0.975,
        na.rm = TRUE,
        names = FALSE
      ),
      min = min(.data[[value_col]], na.rm = TRUE),
      max = max(.data[[value_col]], na.rm = TRUE),
      .groups = "drop"
    )
}

build_simulation_conservation_diagnostics <- function(source_panel,
                                                      revenue_global,
                                                      tolerance =
                                                        SIM_CONSERVATION_TOLERANCE) {
  source_totals <- source_panel |>
    group_by(across(all_of(SCENARIO_VARS)), year) |>
    summarise(
      pre_allocation_topup = sum(topup_after_behaviour, na.rm = TRUE),
      sbs_extinguished_topup = sum(stage4_sbs_extinguished_liability,
        na.rm = TRUE
      ),
      zero_liability = sum(stage4_zero_liability, na.rm = TRUE),
      .groups = "drop"
    )

  allocated_totals <- revenue_global |>
    group_by(across(all_of(SCENARIO_VARS)), year) |>
    summarise(
      allocated_topup = sum(revenue, na.rm = TRUE),
      .groups = "drop"
    )

  conservation <- source_totals |>
    left_join(allocated_totals, by = c(SCENARIO_VARS, "year")) |>
    mutate(
      allocated_topup = coalesce_zero(allocated_topup),
      residual_gap = allocated_topup + sbs_extinguished_topup +
        zero_liability - pre_allocation_topup
    )

  max_gap <- max(abs(conservation$residual_gap), na.rm = TRUE)
  if (max_gap > tolerance) {
    stop("Stage 4.5 simulation allocation residual exceeds material tolerance")
  }

  conservation
}

run_one_measurement_error_draw <- function(draw_id,
                                           stage1_draw,
                                           stage1_affiliate_year,
                                           stage2_bilateral,
                                           stage2_sectoral_matrix,
                                           behavioural_affiliate_year,
                                           policy_flags,
                                           preferred_model) {
  stage1_draw_affiliate_year <- apply_stage1_measurement_draw(
    stage1_affiliate_year,
    stage1_draw
  )
  stage2_draw <- recompute_stage2_distributional(
    stage2_bilateral,
    stage1_draw_affiliate_year
  )
  stage2_sectoral_draw <- update_stage2_sectoral_distributional(
    stage2_sectoral_matrix,
    stage1_draw_affiliate_year
  )
  behavioural_draw <- update_behavioural_affiliate_year(
    behavioural_affiliate_year,
    stage1_draw_affiliate_year
  )
  sectoral_bridge_draw <- build_sectoral_factor2_bridge(
    stage2_draw,
    stage1_draw_affiliate_year,
    stage2_sectoral_draw
  )

  revenue_objects <- build_factorial_revenue(
    stage2_draw,
    behavioural_draw,
    sectoral_bridge_draw,
    policy_flags,
    preferred_model
  )

  source_panel <- build_source_panel(revenue_objects$scenario_panel)
  collector_activity <- build_collector_activity(revenue_objects$scenario_panel)
  utpr_weights <- build_parent_year_utpr_weights(collector_activity)
  allocation_objects <- allocate_stage4_revenue(source_panel, utpr_weights)
  conservation <- build_simulation_conservation_diagnostics(
    source_panel,
    allocation_objects$revenue_by_channel_global
  )

  revenue_country_year <- allocation_objects$revenue_country_year_eu27

  scenario_summary <- build_scenario_summary(revenue_country_year) |>
    mutate(draw_id = draw_id, .before = 1)

  preferred_summary <- revenue_country_year |>
    filter(
      factor1_etr == "distributional",
      factor2_substance == "aggregate_sbie",
      rate_scenario == "initial"
    ) |>
    group_by(factor4_sbs, factor5_behaviour) |>
    summarise(eu_revenue = sum(revenue, na.rm = TRUE), .groups = "drop") |>
    mutate(draw_id = draw_id, .before = 1)

  preferred_country_year <- revenue_country_year |>
    filter(
      factor1_etr == "distributional",
      factor2_substance == "aggregate_sbie",
      rate_scenario == "initial"
    ) |>
    mutate(draw_id = draw_id, .before = 1)

  diagnostics <- tibble(
    draw_id = draw_id,
    max_allocation_conservation_gap =
      max(abs(conservation$residual_gap), na.rm = TRUE),
    eu_revenue_min_scenario = min(scenario_summary$eu_revenue, na.rm = TRUE),
    eu_revenue_max_scenario = max(scenario_summary$eu_revenue, na.rm = TRUE)
  )

  list(
    scenario_summary = scenario_summary,
    preferred_summary = preferred_summary,
    preferred_country_year = preferred_country_year,
    diagnostics = diagnostics
  )
}

run_stage1_measurement_error_simulation <- function(
  n_draws = MEASUREMENT_ERROR_DRAWS,
  seed = MEASUREMENT_ERROR_SEED
) {
  dir.create(DIAGNOSTICS_DIR, showWarnings = FALSE, recursive = TRUE)
  stage1_affiliate_year <- readRDS(file.path(PROCESSED_DIR, "stage1_affiliate_year.rds"))
  stage2_bilateral <- readRDS(file.path(PROCESSED_DIR, "stage2_bilateral_panel.rds"))
  stage2_sectoral_matrix <- readRDS(file.path(PROCESSED_DIR, "stage2_sectoral_matrix.rds"))
  behavioural_affiliate_year <- readRDS(
    file.path(PROCESSED_DIR, "stage3_behavioral_affiliate_year.rds")
  )
  model_comparison <- readRDS(file.path(PROCESSED_DIR, "stage3_model_comparison.rds"))
  oecd_central_record <- readRDS(file.path(PROCESSED_DIR, "oecd_pillar2_central_record.rds"))
  crossval_affiliate_year <- read_csv(
    file.path(DIAGNOSTICS_DIR, "step3_stage1_crossval_affiliate_year.csv"),
    show_col_types = FALSE
  )

  preferred_model <- model_comparison |>
    arrange(bic_rank) |>
    slice(1) |>
    pull(model_spec)

  policy_flags <- build_policy_flags(oecd_central_record)
  calibration <- calibrate_stage1_measurement_error(crossval_affiliate_year)
  stage1_draws <- draw_stage1_measurement_error(
    stage1_affiliate_year,
    calibration,
    n_draws = n_draws,
    seed = seed
  )

  results <- vector("list", n_draws)

  for (draw_id in seq_len(n_draws)) {
    if (draw_id == 1L || draw_id %% 25L == 0L || draw_id == n_draws) {
      message(sprintf("Measurement-error draw %d of %d", draw_id, n_draws))
    }

    stage1_draw <- stage1_draw_for_id(stage1_draws, draw_id)

    results[[draw_id]] <- run_one_measurement_error_draw(
      draw_id = draw_id,
      stage1_draw = stage1_draw,
      stage1_affiliate_year = stage1_affiliate_year,
      stage2_bilateral = stage2_bilateral,
      stage2_sectoral_matrix = stage2_sectoral_matrix,
      behavioural_affiliate_year = behavioural_affiliate_year,
      policy_flags = policy_flags,
      preferred_model = preferred_model
    )
  }

  scenario_draws <- map_dfr(results, "scenario_summary")
  preferred_draws <- map_dfr(results, "preferred_summary")
  preferred_country_year_draws <- map_dfr(results, "preferred_country_year")
  draw_diagnostics <- map_dfr(results, "diagnostics")

  baseline_scenario_summary <- readRDS(
    file.path(PROCESSED_DIR, "stage4_6_scenario_summary.rds")
  ) |>
    select(all_of(SCENARIO_VARS), baseline_eu_revenue = eu_revenue)

  baseline_preferred_country_year <- readRDS(
    file.path(PROCESSED_DIR, "stage4_5_revenue_country_year.rds")
  ) |>
    filter(
      factor1_etr == "distributional",
      factor2_substance == "aggregate_sbie",
      rate_scenario == "initial"
    ) |>
    select(all_of(SCENARIO_VARS), country, country_name, year,
      baseline_revenue = revenue
    )

  baseline_preferred_summary <- baseline_preferred_country_year |>
    group_by(factor4_sbs, factor5_behaviour) |>
    summarise(
      baseline_eu_revenue = sum(baseline_revenue, na.rm = TRUE),
      .groups = "drop"
    )

  scenario_interval <- summarise_draw_interval(
    scenario_draws,
    "eu_revenue",
    SCENARIO_VARS
  ) |>
    left_join(baseline_scenario_summary, by = SCENARIO_VARS) |>
    mutate(
      mean_bn = mean / 1e9,
      p05_bn = p05 / 1e9,
      p50_bn = p50 / 1e9,
      p95_bn = p95 / 1e9,
      baseline_eu_revenue_bn = baseline_eu_revenue / 1e9,
      p90_width_bn = (p95 - p05) / 1e9,
      p95_minus_p05_to_baseline = safe_divide(
        p95 - p05,
        baseline_eu_revenue
      )
    )

  preferred_interval <- summarise_draw_interval(
    preferred_draws,
    "eu_revenue",
    c("factor4_sbs", "factor5_behaviour")
  ) |>
    left_join(baseline_preferred_summary,
      by = c("factor4_sbs", "factor5_behaviour")
    ) |>
    mutate(
      mean_bn = mean / 1e9,
      p05_bn = p05 / 1e9,
      p50_bn = p50 / 1e9,
      p95_bn = p95 / 1e9,
      baseline_eu_revenue_bn = baseline_eu_revenue / 1e9,
      p90_width_bn = (p95 - p05) / 1e9
    )

  preferred_country_year_interval <- summarise_draw_interval(
    preferred_country_year_draws,
    "revenue",
    c(SCENARIO_VARS, "country", "country_name", "year")
  ) |>
    left_join(
      baseline_preferred_country_year,
      by = c(SCENARIO_VARS, "country", "country_name", "year")
    ) |>
    mutate(
      mean_bn = mean / 1e9,
      p05_bn = p05 / 1e9,
      p50_bn = p50 / 1e9,
      p95_bn = p95 / 1e9,
      baseline_revenue_bn = baseline_revenue / 1e9,
      p90_width_bn = (p95 - p05) / 1e9
    )

  summary <- tibble(
    metric = c(
      "draws",
      "seed",
      "preferred_model",
      "max_allocation_conservation_gap",
      "scenario_interval_rows",
      "preferred_interval_rows",
      "preferred_country_year_interval_rows"
    ),
    value = as.character(c(
      n_draws,
      seed,
      preferred_model,
      max(abs(draw_diagnostics$max_allocation_conservation_gap), na.rm = TRUE),
      nrow(scenario_interval),
      nrow(preferred_interval),
      nrow(preferred_country_year_interval)
    ))
  )

  write_csv(
    calibration$summary,
    file.path(DIAGNOSTICS_DIR, "step9_stage1_measurement_error_calibration.csv")
  )
  write_csv(
    summary,
    file.path(DIAGNOSTICS_DIR, "step9_stage1_measurement_error_summary.csv")
  )
  write_csv(
    draw_diagnostics,
    file.path(DIAGNOSTICS_DIR, "step9_stage1_measurement_error_draw_diagnostics.csv")
  )
  write_csv(
    scenario_draws,
    file.path(DIAGNOSTICS_DIR, "step9_stage1_measurement_error_scenario_draws.csv")
  )
  write_csv(
    scenario_interval,
    file.path(DIAGNOSTICS_DIR, "step9_stage1_measurement_error_scenario_interval.csv")
  )
  write_csv(
    preferred_interval,
    file.path(DIAGNOSTICS_DIR, "step9_stage1_measurement_error_preferred_interval.csv")
  )
  write_csv(
    preferred_country_year_interval,
    file.path(
      DIAGNOSTICS_DIR,
      "step9_stage1_measurement_error_preferred_country_year_interval.csv"
    )
  )

  saveRDS(
    calibration,
    file.path(PROCESSED_DIR, "stage1_measurement_error_calibration.rds")
  )
  saveRDS(
    stage1_draws,
    file.path(PROCESSED_DIR, "stage1_measurement_error_stage1_draws.rds")
  )
  saveRDS(
    scenario_draws,
    file.path(PROCESSED_DIR, "stage1_measurement_error_scenario_draws.rds")
  )
  saveRDS(
    scenario_interval,
    file.path(PROCESSED_DIR, "stage1_measurement_error_scenario_interval.rds")
  )
  saveRDS(
    preferred_interval,
    file.path(PROCESSED_DIR, "stage1_measurement_error_preferred_interval.rds")
  )
  saveRDS(
    preferred_country_year_interval,
    file.path(
      PROCESSED_DIR,
      "stage1_measurement_error_preferred_country_year_interval.rds"
    )
  )

  message("\nStep 9 outputs written:")
  message(" - data/processed/stage1_measurement_error_*.rds")
  message(" - diagnostics/step9_stage1_measurement_error_*.csv")

  invisible(list(
    calibration = calibration,
    stage1_draws = stage1_draws,
    scenario_interval = scenario_interval,
    preferred_interval = preferred_interval,
    preferred_country_year_interval = preferred_country_year_interval,
    summary = summary
  ))
}

# A cache is portable only when all outputs and the regenerated inputs match
# their frozen hashes. A cache miss runs the full simulation.
reuse_measurement_error_cache <- function(cache_root) {
  manifest <- readRDS(file.path(GMT_PROJECT_ROOT, "tests", "golden_step15_manifest.rds"))$files
  outputs <- grepl("/(step9_stage1_measurement_error|stage1_measurement_error_)", manifest$path)
  inputs <- file.path("data", "processed", c(
    "stage1_affiliate_year.rds", "stage2_bilateral_panel.rds", "stage2_sectoral_matrix.rds",
    "stage3_behavioral_affiliate_year.rds", "stage3_model_comparison.rds",
    "oecd_pillar2_central_record.rds", "stage4_6_scenario_summary.rds",
    "stage4_5_revenue_country_year.rds", "diagnostics/step3_stage1_crossval_affiliate_year.csv"
  ))
  input_hashes <- manifest$sha256[match(inputs, manifest$path)]
  source <- file.path(cache_root, manifest$path[outputs])
  target <- file.path(PROCESSED_DIR, sub("^data/processed/", "", manifest$path[outputs]))
  current_inputs <- file.path(PROCESSED_DIR, sub("^data/processed/", "", inputs))
  if (!all(file.exists(c(source, current_inputs))) ||
      !identical(unname(tools::sha256sum(current_inputs)), input_hashes) ||
      !identical(unname(tools::sha256sum(source)), manifest$sha256[outputs])) {
    return(FALSE)
  }
  copy <- normalizePath(source, mustWork = TRUE) != normalizePath(target, mustWork = FALSE)
  if (any(copy) && !all(file.copy(source[copy], target[copy], overwrite = TRUE))) {
    stop("Could not install the verified measurement-error cache")
  }
  stopifnot(identical(unname(tools::sha256sum(target)), manifest$sha256[outputs]))
  message("Reused ", sum(outputs), " hash-verified Stage 1 simulation outputs.")
  TRUE
}

run_uncertainty <- function(cache_root = GMT_PROJECT_ROOT) {
  run_profit_correction_revenue_uncertainty()
  if (!reuse_measurement_error_cache(cache_root)) run_stage1_measurement_error_simulation()
}

if (is_direct_script_run("code/07a_uncertainty.R")) {
  run_uncertainty(Sys.getenv("GMT_MEASUREMENT_CACHE_ROOT", unset = GMT_PROJECT_ROOT))
}
