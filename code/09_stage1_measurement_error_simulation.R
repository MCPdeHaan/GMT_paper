# 09_stage1_measurement_error_simulation.R
# Optional uncertainty layer for the GMT revenue pipeline.
#
# This script propagates Stage 1 ETR measurement error through the existing
# Stage 2 to Stage 4.6 revenue machinery. The calibration uses the 2021-2022
# overlap where Table I percentile-fit estimates can be compared with direct
# Table IV low-tax bracket observations.

source("code/00_helpers.R", local = TRUE)

source("code/04_stage2_sbie.R", local = TRUE)
source("code/05_stage3_behavioral.R", local = TRUE)
source("code/06_stage4_5_revenue_allocation_sbs.R", local = TRUE)
source("code/07_stage4_6_revenue_pipeline_decomposition.R", local = TRUE)


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

parse_int_arg <- function(flag, default) {
  args <- commandArgs(trailingOnly = TRUE)
  hit <- args[grepl(paste0("^", flag, "="), args)]
  if (length(hit) == 0) {
    return(default)
  }
  as.integer(sub(paste0("^", flag, "="), "", hit[1]))
}

if (is_direct_script_run("code/09_stage1_measurement_error_simulation.R")) {
  run_stage1_measurement_error_simulation(
    n_draws = parse_int_arg("--draws", MEASUREMENT_ERROR_DRAWS),
    seed = parse_int_arg("--seed", MEASUREMENT_ERROR_SEED)
  )
}
