# 04_stage2_sbie.R
# Step 4 of the methodology pipeline.
#
# Implements Stage 2 of the GMT revenue pipeline on top of the Stage 1 outputs.
# The script produces two linked objects:
# an aggregate bilateral SBIE filter for the 2017-2022 panel; and
# a 2022 EU27 sectoral effective-floor matrix using CbCR levels, FATS
#  foreign-control sector shares and EUKLEMS tangible-capital stock shares,
#  with an SBTI-capacity overlay and a mechanical 2024-2033 transition path.
library(dplyr)
library(tidyr)
library(readr)
library(tibble)

source("code/00_helpers.R")

dir.create(DIAGNOSTICS_DIR, showWarnings = FALSE, recursive = TRUE)

SECTORAL_REFERENCE_YEAR <- 2022
SECTORAL_TRANSITION_YEARS <- 2024:2033

STAGE2_ENDPOINTS <- tribble(
  ~rate_scenario, ~sigma_w, ~sigma_a,
  "initial",      0.10,     0.08,
  "long_run",     0.05,     0.05
)

ASSET_COMPONENT_SENSITIVITY <- tribble(
  ~asset_sensitivity, ~asset_component_scale,
  "minus_25",         0.75,
  "baseline",         1.00,
  "plus_25",          1.25
)

nace_broad_group <- function(x) {
  out <- substr(x, 1, 1)
  out[!out %in% LETTERS] <- NA_character_
  out
}

classify_bea_bridge_signal <- function(measure, share_correlation,
                                       mean_abs_share_gap) {
  case_when(
    is.na(share_correlation) | is.na(mean_abs_share_gap) ~
      "not_evaluable",
    measure == "total_assets" &
      (share_correlation < 0.50 | mean_abs_share_gap > 0.10) ~
      "reject_as_primary_asset_allocator",
    share_correlation >= 0.70 & mean_abs_share_gap <= 0.09 ~
      "supportive_external_benchmark",
    share_correlation >= 0.50 & mean_abs_share_gap <= 0.10 ~
      "caution_external_benchmark",
    TRUE ~ "benchmark_only"
  )
}

model_frame_row_indices <- function(model_frame) {
  row_ids <- rownames(model_frame)
  if (all(grepl("^[0-9]+$", row_ids))) {
    return(as.integer(row_ids))
  }
  seq_len(nrow(model_frame))
}

cluster_vcov_lm <- function(fit, cluster) {
  mf <- stats::model.frame(fit)
  used_rows <- model_frame_row_indices(mf)

  x <- stats::model.matrix(fit)
  residuals <- as.numeric(stats::residuals(fit))
  weights <- stats::weights(fit)
  if (is.null(weights)) weights <- rep(1, length(residuals))

  cluster <- if (length(cluster) == nrow(mf)) {
    factor(cluster)
  } else {
    factor(cluster[used_rows])
  }
  bread <- solve(crossprod(sqrt(weights) * x))
  scores <- x * as.numeric(residuals * weights)
  meat <- matrix(0, ncol(x), ncol(x))

  for (g in levels(cluster)) {
    sg <- colSums(scores[cluster == g, , drop = FALSE])
    meat <- meat + tcrossprod(sg)
  }

  g_count <- nlevels(cluster)
  n <- nrow(x)
  df_resid <- stats::df.residual(fit)
  correction <- if (g_count > 1 && df_resid > 0) {
    g_count / (g_count - 1) * (n - 1) / df_resid
  } else {
    1
  }

  correction * bread %*% meat %*% bread
}

tidy_lm_clustered <- function(fit, cluster, model_variant) {
  mf <- stats::model.frame(fit)
  used_rows <- model_frame_row_indices(mf)
  cluster_used <- if (length(cluster) == nrow(mf)) {
    factor(cluster)
  } else {
    factor(cluster[used_rows])
  }

  vcov <- cluster_vcov_lm(fit, cluster)
  estimates <- stats::coef(fit)
  std_error <- sqrt(diag(vcov))
  statistic <- estimates / std_error
  df <- max(nlevels(cluster_used) - 1, 1)
  fit_summary <- summary(fit)

  tibble(
    model_variant = model_variant,
    inference = "affiliate_clustered",
    term = names(estimates),
    estimate = as.numeric(estimates),
    std_error = as.numeric(std_error),
    statistic = as.numeric(statistic),
    p_value = 2 * stats::pt(abs(statistic), df = df, lower.tail = FALSE),
    n_obs = stats::nobs(fit),
    n_clusters = nlevels(cluster_used),
    df_cluster = df,
    r_squared = fit_summary$r.squared,
    adj_r_squared = fit_summary$adj.r.squared,
    dependent_variable = "sectoral_delta_floor_average",
    reference_year = SECTORAL_REFERENCE_YEAR,
    transition_year = min(SECTORAL_TRANSITION_YEARS)
  )
}

compute_sbie_value <- function(payroll, assets, sigma_w, sigma_a) {
  sigma_w * coalesce_zero(payroll) + sigma_a * coalesce_zero(assets)
}

compute_phi_ratio <- function(sbie, profit) {
  raw_phi <- safe_divide(sbie, profit)
  clamp_unit_interval(raw_phi)
}

compute_effective_floor <- function(topup_gap, phi, threshold = GMT_RATE) {
  if_else(
    is.na(topup_gap) | is.na(phi),
    NA_real_,
    pmax(0, threshold - pmax(topup_gap, 0) * clamp_unit_interval(phi))
  )
}

apply_sbti_capacity_overlay <- function(floor_rate, kappa) {
  if_else(
    is.na(floor_rate) | is.na(kappa),
    NA_real_,
    pmax(0, floor_rate - pmin(pmax(kappa, 0), floor_rate))
  )
}

build_transition_rates <- function(years = SECTORAL_TRANSITION_YEARS,
                                   sigma_w_start = 0.10,
                                   sigma_w_end = 0.05,
                                   sigma_a_start = 0.08,
                                   sigma_a_end = 0.05) {
  tibble(
    transition_year = years,
    sigma_w = seq(sigma_w_start, sigma_w_end, length.out = length(years)),
    sigma_a = seq(sigma_a_start, sigma_a_end, length.out = length(years))
  ) |>
    mutate(
      rate_scenario = case_when(
        transition_year == min(transition_year) ~ "initial",
        transition_year == max(transition_year) ~ "long_run",
        TRUE ~ "transition"
      )
    )
}

run_stage2_pipeline <- function() {
  stage1_bilateral <- readRDS(file.path(PROCESSED_DIR, "stage1_bilateral_panel.rds")) |>
    filter(year %in% MAIN_YEARS)
  stage1_affiliate_year <- readRDS(file.path(PROCESSED_DIR, "stage1_affiliate_year.rds")) |>
    filter(year %in% MAIN_YEARS)
  fats_sector_shares <- readRDS(file.path(PROCESSED_DIR, "base_panel_fats_sector_shares.rds"))
  bea_us_parent_sector_benchmark <- readRDS(
    file.path(PROCESSED_DIR, "base_panel_bea_us_parent_sector_benchmark.rds")
  )

  assert_unique_keys(
    stage1_bilateral,
    c("parent", "affiliate", "year"),
    "stage1 bilateral input"
  )
  assert_unique_keys(
    stage1_affiliate_year,
    c("affiliate", "year"),
    "stage1 affiliate-year input"
  )
  assert_unique_keys(
    fats_sector_shares,
    c("affiliate", "year", "nace_r2"),
    "FATS sector shares input"
  )
  assert_unique_keys(
    bea_us_parent_sector_benchmark,
    c("measure", "year", "affiliate", "bea_sector_group"),
    "BEA US-parent sector benchmark input"
  )

  # Aggregate bilateral Stage 2 filter. Missing payroll enters as a conservative
  # zero contribution so that the panel remains complete for downstream work;
  # the affected rows are flagged and quantified in the diagnostics.
  stage2_bilateral <- stage1_bilateral |>
    tidyr::crossing(STAGE2_ENDPOINTS) |>
    mutate(
      stage2_payroll_zero_fallback_flag =
        analysis_profit_positive > 0 & is.na(payroll_sbie),
      stage2_assets_zero_fallback_flag =
        analysis_profit_positive > 0 & is.na(assets_sbie),
      stage2_sbie = if_else(
        analysis_profit_positive > 0,
        compute_sbie_value(payroll_sbie, assets_sbie, sigma_w, sigma_a),
        NA_real_
      ),
      stage2_phi_raw = safe_divide(stage2_sbie, analysis_profit_positive),
      stage2_phi = compute_phi_ratio(stage2_sbie, analysis_profit_positive),
      stage2_filter = if_else(
        analysis_profit_positive > 0,
        1 - stage2_phi,
        1
      ),
      stage2_phi_capped_flag = !is.na(stage2_phi_raw) & stage2_phi_raw > 1,
      stage2_sbie_shield_average =
        stage1_lowtax_profit_average * coalesce(stage2_phi, 0),
      stage2_sbie_shield_distributional =
        stage1_lowtax_profit_distributional * coalesce(stage2_phi, 0),
      stage2_sbie_shield_distributional_strict =
        stage1_lowtax_profit_distributional_strict * coalesce(stage2_phi, 0),
      stage2_excess_lowtax_profit_average =
        stage1_lowtax_profit_average * stage2_filter,
      stage2_excess_lowtax_profit_distributional =
        stage1_lowtax_profit_distributional * stage2_filter,
      stage2_excess_lowtax_profit_distributional_strict =
        stage1_lowtax_profit_distributional_strict * stage2_filter,
      stage2_topup_tax_average =
        coalesce(stage1_topup_tax_average, 0) * stage2_filter,
      stage2_topup_tax_distributional =
        coalesce(stage1_topup_tax_distributional, 0) * stage2_filter,
      stage2_topup_tax_distributional_strict =
        coalesce(stage1_topup_tax_distributional_strict, 0) * stage2_filter,
      stage2_effective_floor_average =
        compute_effective_floor(average_topup_rate, stage2_phi),
      stage2_effective_floor_distributional =
        compute_effective_floor(stage1_distributional_topup_rate, stage2_phi),
      stage2_effective_floor_distributional_strict =
        compute_effective_floor(
          stage1_distributional_topup_rate_strict,
          stage2_phi
        )
    )

  assert_unique_keys(
    stage2_bilateral,
    c("rate_scenario", "parent", "affiliate", "year"),
    "stage2 bilateral"
  )

  if (any(stage2_bilateral$stage2_filter < 0, na.rm = TRUE) ||
    any(stage2_bilateral$stage2_filter > 1, na.rm = TRUE)) {
    stop("Stage 2 filter leaves the [0, 1] interval")
  }

  if (any(stage2_bilateral$stage2_topup_tax_distributional < 0, na.rm = TRUE)) {
    stop("Stage 2 produced a negative distributional top-up tax")
  }

  stage2_affiliate_year <- stage2_bilateral |>
    group_by(rate_scenario, sigma_w, sigma_a, affiliate, year) |>
    summarise(
      affiliate_name = first(affiliate_jurisdiction_name),
      affiliate_is_eu27 = first(affiliate_is_eu27),
      pair_years = n(),
      positive_pair_years = sum(analysis_profit_positive > 0, na.rm = TRUE),
      total_analysis_profit_positive = sum(analysis_profit_positive, na.rm = TRUE),
      total_stage1_topup_tax_average = sum(stage1_topup_tax_average, na.rm = TRUE),
      total_stage1_topup_tax_distributional = sum(
        stage1_topup_tax_distributional,
        na.rm = TRUE
      ),
      total_stage1_topup_tax_distributional_strict = sum(
        stage1_topup_tax_distributional_strict,
        na.rm = TRUE
      ),
      total_stage2_topup_tax_average = sum(stage2_topup_tax_average, na.rm = TRUE),
      total_stage2_topup_tax_distributional = sum(
        stage2_topup_tax_distributional,
        na.rm = TRUE
      ),
      total_stage2_topup_tax_distributional_strict = sum(
        stage2_topup_tax_distributional_strict,
        na.rm = TRUE
      ),
      profit_weighted_stage2_phi = weighted_mean_available(
        stage2_phi,
        analysis_profit_positive
      ),
      distributional_topup_weighted_stage2_phi = weighted_mean_available(
        stage2_phi,
        stage1_topup_tax_distributional
      ),
      profit_weighted_floor_average = weighted_mean_available(
        stage2_effective_floor_average,
        analysis_profit_positive
      ),
      profit_weighted_floor_distributional = weighted_mean_available(
        stage2_effective_floor_distributional,
        analysis_profit_positive
      ),
      profit_weighted_floor_distributional_strict = weighted_mean_available(
        stage2_effective_floor_distributional_strict,
        analysis_profit_positive
      ),
      rows_with_payroll_zero_fallback = sum(
        stage2_payroll_zero_fallback_flag,
        na.rm = TRUE
      ),
      rows_with_assets_zero_fallback = sum(
        stage2_assets_zero_fallback_flag,
        na.rm = TRUE
      ),
      rows_with_phi_cap = sum(stage2_phi_capped_flag, na.rm = TRUE),
      distributional_topup_in_payroll_fallback_rows = sum(
        if_else(stage2_payroll_zero_fallback_flag,
          stage1_topup_tax_distributional,
          0
        ),
        na.rm = TRUE
      ),
      .groups = "drop"
    )

  assert_unique_keys(
    stage2_affiliate_year,
    c("rate_scenario", "affiliate", "year"),
    "stage2 affiliate-year"
  )

  stage2_scenario_by_year <- bind_rows(
    stage2_bilateral |>
      filter(analysis_profit_positive > 0) |>
      mutate(scope = "global"),
    stage2_bilateral |>
      filter(analysis_profit_positive > 0, affiliate_is_eu27) |>
      mutate(scope = "eu27")
  ) |>
    group_by(scope, rate_scenario, year) |>
    summarise(
      pair_years = n(),
      total_positive_profit = sum(analysis_profit_positive, na.rm = TRUE),
      profit_weighted_stage2_phi = weighted_mean_available(
        stage2_phi,
        analysis_profit_positive
      ),
      stage1_average_liability_rate = safe_divide(
        sum(stage1_topup_tax_average, na.rm = TRUE),
        sum(analysis_profit_positive, na.rm = TRUE)
      ),
      stage2_average_liability_rate = safe_divide(
        sum(stage2_topup_tax_average, na.rm = TRUE),
        sum(analysis_profit_positive, na.rm = TRUE)
      ),
      stage1_distributional_liability_rate = safe_divide(
        sum(stage1_topup_tax_distributional, na.rm = TRUE),
        sum(analysis_profit_positive, na.rm = TRUE)
      ),
      stage2_distributional_liability_rate = safe_divide(
        sum(stage2_topup_tax_distributional, na.rm = TRUE),
        sum(analysis_profit_positive, na.rm = TRUE)
      ),
      stage2_distributional_liability_rate_strict = safe_divide(
        sum(stage2_topup_tax_distributional_strict, na.rm = TRUE),
        sum(analysis_profit_positive, na.rm = TRUE)
      ),
      profit_weighted_floor_average = weighted_mean_available(
        stage2_effective_floor_average,
        analysis_profit_positive
      ),
      profit_weighted_floor_distributional = weighted_mean_available(
        stage2_effective_floor_distributional,
        analysis_profit_positive
      ),
      payroll_zero_fallback_rows = sum(
        stage2_payroll_zero_fallback_flag,
        na.rm = TRUE
      ),
      distributional_topup_in_payroll_fallback_rows = sum(
        if_else(stage2_payroll_zero_fallback_flag,
          stage1_topup_tax_distributional,
          0
        ),
        na.rm = TRUE
      ),
      .groups = "drop"
    ) |>
    arrange(scope, rate_scenario, year)

  stage2_payroll_fallback_by_year <- stage2_bilateral |>
    filter(analysis_profit_positive > 0) |>
    group_by(rate_scenario, year) |>
    summarise(
      pair_years = n(),
      payroll_zero_fallback_rows = sum(
        stage2_payroll_zero_fallback_flag,
        na.rm = TRUE
      ),
      positive_profit_in_fallback_rows = sum(
        if_else(stage2_payroll_zero_fallback_flag,
          analysis_profit_positive,
          0
        ),
        na.rm = TRUE
      ),
      stage1_distributional_topup_in_fallback_rows = sum(
        if_else(stage2_payroll_zero_fallback_flag,
          stage1_topup_tax_distributional,
          0
        ),
        na.rm = TRUE
      ),
      fallback_share_of_stage1_distributional_topup = safe_divide(
        sum(if_else(stage2_payroll_zero_fallback_flag,
          stage1_topup_tax_distributional,
          0
        ), na.rm = TRUE),
        sum(stage1_topup_tax_distributional, na.rm = TRUE)
      ),
      .groups = "drop"
    ) |>
    arrange(rate_scenario, year)

  # Sectoral Stage 2 matrix. This is a 2022 EU27 reference-year object used
  # for the sectoral floor map and the H5 cross-section; it is not imposed on
  # the historical 2017-2022 bilateral panel because sectoral profits and QTI
  # claims are not observed in the public data.
  sectoral_weights_check <- fats_sector_shares |>
    filter(year == SECTORAL_REFERENCE_YEAR, affiliate %in% EU27_ISO3) |>
    group_by(affiliate, year) |>
    summarise(
      n_nace = n(),
      payroll_share_sum = sum(fats_payroll_share, na.rm = TRUE),
      employee_share_sum = sum(fats_employee_share, na.rm = TRUE),
      investment_share_sum = sum(fats_investment_share, na.rm = TRUE),
      asset_share_sum = sum(sectoral_asset_share, na.rm = TRUE),
      turnover_share_sum = sum(fats_turnover_share, na.rm = TRUE),
      profit_share_sum = sum(sectoral_profit_share, na.rm = TRUE),
      euklems_asset_share_sum = sum(euklems_tangible_asset_share, na.rm = TRUE),
      affiliates_using_euklems_stock = as.integer(first(use_euklems_asset_share)),
      euklems_stock_coverage_turnover_share =
        first(euklems_stock_coverage_turnover_share),
      .groups = "drop"
    )

  if (max(abs(sectoral_weights_check$payroll_share_sum - 1), na.rm = TRUE) > 1e-8 ||
    max(abs(sectoral_weights_check$asset_share_sum - 1), na.rm = TRUE) > 1e-8 ||
    max(abs(sectoral_weights_check$profit_share_sum - 1), na.rm = TRUE) > 1e-8) {
    stop("Sectoral Stage 2 weights do not sum to one")
  }

  sectoral_reference_base <- stage1_bilateral |>
    filter(
      year == SECTORAL_REFERENCE_YEAR,
      affiliate_is_eu27,
      analysis_profit_positive > 0
    ) |>
    group_by(affiliate, affiliate_jurisdiction_name) |>
    summarise(
      total_profit = sum(analysis_profit_positive, na.rm = TRUE),
      total_payroll = sum(coalesce_zero(payroll_sbie), na.rm = TRUE),
      total_assets = sum(coalesce_zero(assets_sbie), na.rm = TRUE),
      pair_years = n(),
      rows_with_payroll_zero_fallback = sum(is.na(payroll_sbie), na.rm = TRUE),
      .groups = "drop"
    ) |>
    left_join(
      stage1_affiliate_year |>
        filter(year == SECTORAL_REFERENCE_YEAR, affiliate_is_eu27) |>
        select(
          affiliate,
          affiliate_name,
          avg_etr_stage1,
          average_topup_rate,
          stage1_distributional_topup_rate,
          stage1_distributional_topup_rate_strict
        ),
      by = "affiliate"
    )

  assert_unique_keys(
    sectoral_reference_base,
    c("affiliate"),
    "sectoral reference base"
  )

  transition_rates <- build_transition_rates()

  # Sectoral SBIE with SBTI overlay. Unlike the aggregate bilateral SBIE above,
  # this allocates 2022 affiliate profit, payroll and tangible assets across
  # broad NACE sectors before applying the sectoral transition path.
  stage2_sectoral_matrix <- fats_sector_shares |>
    filter(year == SECTORAL_REFERENCE_YEAR, affiliate %in% EU27_ISO3) |>
    left_join(sectoral_reference_base, by = "affiliate") |>
    tidyr::crossing(transition_rates) |>
    mutate(
      sectoral_payroll_share_used = fats_payroll_share,
      sectoral_asset_share_used = sectoral_asset_share,
      sectoral_profit_share_used = sectoral_profit_share,
      sectoral_payroll = fats_payroll_share * total_payroll,
      sectoral_assets = sectoral_asset_share * total_assets,
      sectoral_profit_proxy = sectoral_profit_share * total_profit,
      sectoral_sbie = compute_sbie_value(
        sectoral_payroll,
        sectoral_assets,
        sigma_w,
        sigma_a
      ),
      sectoral_phi_raw = safe_divide(sectoral_sbie, sectoral_profit_proxy),
      sectoral_phi = compute_phi_ratio(sectoral_sbie, sectoral_profit_proxy),
      sectoral_kappa = safe_divide(
        pmax(0.055 * sectoral_payroll, 0.01 * sectoral_assets),
        sectoral_profit_proxy
      ),
      sectoral_capital_intensity = safe_divide(
        sectoral_assets,
        sectoral_profit_proxy
      ),
      sectoral_payroll_intensity = safe_divide(
        sectoral_payroll,
        sectoral_profit_proxy
      ),
      sectoral_floor_average = compute_effective_floor(
        average_topup_rate,
        sectoral_phi
      ),
      sectoral_floor_distributional = compute_effective_floor(
        stage1_distributional_topup_rate,
        sectoral_phi
      ),
      sectoral_floor_distributional_strict = compute_effective_floor(
        stage1_distributional_topup_rate_strict,
        sectoral_phi
      ),
      sectoral_floor_average_sbti = apply_sbti_capacity_overlay(
        sectoral_floor_average,
        sectoral_kappa
      ),
      sectoral_floor_distributional_sbti = apply_sbti_capacity_overlay(
        sectoral_floor_distributional,
        sectoral_kappa
      ),
      sectoral_floor_distributional_strict_sbti = apply_sbti_capacity_overlay(
        sectoral_floor_distributional_strict,
        sectoral_kappa
      ),
      sectoral_delta_floor_average =
        sectoral_floor_average_sbti - sectoral_floor_average,
      sectoral_delta_floor_distributional =
        sectoral_floor_distributional_sbti - sectoral_floor_distributional,
      sectoral_delta_floor_distributional_strict =
        sectoral_floor_distributional_strict_sbti -
          sectoral_floor_distributional_strict
    )

  assert_unique_keys(
    stage2_sectoral_matrix,
    c("affiliate", "transition_year", "nace_r2"),
    "stage2 sectoral matrix"
  )

  if (any(stage2_sectoral_matrix$sectoral_floor_distributional < 0, na.rm = TRUE) ||
    any(stage2_sectoral_matrix$sectoral_floor_distributional > GMT_RATE,
      na.rm = TRUE
    )) {
    stop("Sectoral Stage 2 floor leaves [0, GMT_RATE]")
  }

  sectoral_bridge_source_summary <- bind_rows(
    stage2_sectoral_matrix |>
      filter(transition_year == min(SECTORAL_TRANSITION_YEARS)) |>
      transmute(
        component = "payroll",
        source_rule = payroll_share_proxy_source,
        sector_share = sectoral_payroll_share_used,
        sectoral_level = sectoral_payroll
      ),
    stage2_sectoral_matrix |>
      filter(transition_year == min(SECTORAL_TRANSITION_YEARS)) |>
      transmute(
        component = "assets",
        source_rule = asset_cell_proxy_source,
        sector_share = sectoral_asset_share_used,
        sectoral_level = sectoral_assets
      ),
    stage2_sectoral_matrix |>
      filter(transition_year == min(SECTORAL_TRANSITION_YEARS)) |>
      transmute(
        component = "profit",
        source_rule = profit_share_proxy_source,
        sector_share = sectoral_profit_share_used,
        sectoral_level = sectoral_profit_proxy
      )
  ) |>
    group_by(component, source_rule) |>
    summarise(
      n_cells = n(),
      missing_share_cells = sum(is.na(sector_share)),
      total_sectoral_level = sum(sectoral_level, na.rm = TRUE),
      .groups = "drop"
    ) |>
    group_by(component) |>
    mutate(
      level_share = safe_divide(
        total_sectoral_level,
        sum(total_sectoral_level, na.rm = TRUE)
      )
    ) |>
    ungroup() |>
    arrange(component, desc(level_share), source_rule)

  sectoral_bridge_country_quality <- stage2_sectoral_matrix |>
    filter(transition_year == min(SECTORAL_TRANSITION_YEARS)) |>
    group_by(affiliate, affiliate_name) |>
    summarise(
      n_nace = n(),
      payroll_share_sum = sum(sectoral_payroll_share_used, na.rm = TRUE),
      asset_share_sum = sum(sectoral_asset_share_used, na.rm = TRUE),
      profit_share_sum = sum(sectoral_profit_share_used, na.rm = TRUE),
      missing_payroll_share_cells = sum(is.na(sectoral_payroll_share_used)),
      missing_asset_share_cells = sum(is.na(sectoral_asset_share_used)),
      missing_profit_share_cells = sum(is.na(sectoral_profit_share_used)),
      euklems_stock_coverage_turnover_share =
        first(euklems_stock_coverage_turnover_share),
      asset_country_year_source = first(asset_share_proxy_source),
      .groups = "drop"
    ) |>
    arrange(affiliate)

  stage2_sectoral_country_summary <- stage2_sectoral_matrix |>
    filter(transition_year %in% c(
      min(SECTORAL_TRANSITION_YEARS),
      max(SECTORAL_TRANSITION_YEARS)
    )) |>
    group_by(affiliate, affiliate_name, transition_year, rate_scenario) |>
    summarise(
      sectors = n(),
      total_profit_proxy = sum(sectoral_profit_proxy, na.rm = TRUE),
      weighted_phi = weighted_mean_available(
        sectoral_phi,
        sectoral_profit_proxy
      ),
      weighted_kappa = weighted_mean_available(
        sectoral_kappa,
        sectoral_profit_proxy
      ),
      weighted_floor_average = weighted_mean_available(
        sectoral_floor_average,
        sectoral_profit_proxy
      ),
      weighted_floor_average_sbti = weighted_mean_available(
        sectoral_floor_average_sbti,
        sectoral_profit_proxy
      ),
      weighted_floor_distributional = weighted_mean_available(
        sectoral_floor_distributional,
        sectoral_profit_proxy
      ),
      weighted_floor_distributional_sbti = weighted_mean_available(
        sectoral_floor_distributional_sbti,
        sectoral_profit_proxy
      ),
      min_floor_average = min(sectoral_floor_average, na.rm = TRUE),
      min_floor_average_sector = nace_r2[which.min(sectoral_floor_average)][1],
      min_floor_distributional = min(sectoral_floor_distributional, na.rm = TRUE),
      min_floor_distributional_sector =
        nace_r2[which.min(sectoral_floor_distributional)][1],
      .groups = "drop"
    ) |>
    arrange(transition_year, affiliate)

  stage2_irl_nld_comparison <- stage2_sectoral_matrix |>
    filter(
      affiliate %in% c("IRL", "NLD"),
      transition_year %in% c(
        min(SECTORAL_TRANSITION_YEARS),
        max(SECTORAL_TRANSITION_YEARS)
      )
    ) |>
    group_by(affiliate, affiliate_name, transition_year, rate_scenario) |>
    arrange(sectoral_floor_average, .by_group = TRUE) |>
    slice_head(n = 10) |>
    ungroup() |>
    select(
      affiliate,
      affiliate_name,
      transition_year,
      rate_scenario,
      nace_r2,
      sectoral_capital_intensity,
      sectoral_kappa,
      sectoral_floor_average,
      sectoral_floor_average_sbti,
      sectoral_floor_distributional,
      sectoral_floor_distributional_sbti
    )

  stage2_sectoral_asset_sensitivity <- fats_sector_shares |>
    filter(year == SECTORAL_REFERENCE_YEAR, affiliate %in% EU27_ISO3) |>
    left_join(sectoral_reference_base, by = "affiliate") |>
    tidyr::crossing(STAGE2_ENDPOINTS, ASSET_COMPONENT_SENSITIVITY) |>
    mutate(
      sectoral_payroll = fats_payroll_share * total_payroll,
      sectoral_assets = sectoral_asset_share * total_assets,
      sectoral_profit_proxy = sectoral_profit_share * total_profit,
      sectoral_phi_sensitivity = compute_phi_ratio(
        sigma_w * sectoral_payroll +
          sigma_a * asset_component_scale * sectoral_assets,
        sectoral_profit_proxy
      ),
      sectoral_floor_average_sensitivity = compute_effective_floor(
        average_topup_rate,
        sectoral_phi_sensitivity
      ),
      sectoral_floor_distributional_sensitivity = compute_effective_floor(
        stage1_distributional_topup_rate,
        sectoral_phi_sensitivity
      )
    ) |>
    group_by(rate_scenario, asset_sensitivity, asset_component_scale) |>
    summarise(
      weighted_phi = weighted_mean_available(
        sectoral_phi_sensitivity,
        sectoral_profit_proxy
      ),
      weighted_floor_average = weighted_mean_available(
        sectoral_floor_average_sensitivity,
        sectoral_profit_proxy
      ),
      weighted_floor_distributional = weighted_mean_available(
        sectoral_floor_distributional_sensitivity,
        sectoral_profit_proxy
      ),
      .groups = "drop"
    ) |>
    arrange(rate_scenario, asset_component_scale)

  # BEA is a U.S.-parented MNE benchmark, not a replacement for the CbCR
  # liability base. This diagnostic compares its broad sector shares with the
  # FATS/EUKLEMS host-country bridge used in the EU sectoral sensitivity.
  fats_broad_sector_reference <- fats_sector_shares |>
    filter(year == SECTORAL_REFERENCE_YEAR, affiliate %in% EU27_ISO3) |>
    mutate(nace_broad = nace_broad_group(nace_r2)) |>
    group_by(affiliate, nace_broad) |>
    summarise(
      fats_payroll_share = sum(fats_payroll_share, na.rm = TRUE),
      fats_employee_share = sum(fats_employee_share, na.rm = TRUE),
      fats_investment_share = sum(fats_investment_share, na.rm = TRUE),
      fats_asset_share = sum(sectoral_asset_share, na.rm = TRUE),
      fats_profit_share = sum(sectoral_profit_share, na.rm = TRUE),
      fats_turnover_share = sum(fats_turnover_share, na.rm = TRUE),
      .groups = "drop"
    )

  bea_fats_broad_sector_validation <- bea_us_parent_sector_benchmark |>
    filter(
      affiliate %in% EU27_ISO3,
      measure %in% c(
        "employment", "compensation",
        "ppe_expenditures", "total_assets"
      ),
      (measure %in% c("employment", "total_assets") &
        year == SECTORAL_REFERENCE_YEAR) |
        (measure %in% c("compensation", "ppe_expenditures") &
          year == SECTORAL_REFERENCE_YEAR + 1L),
      !is.na(nace_r2)
    ) |>
    transmute(
      affiliate,
      bea_year = year,
      measure,
      bea_sector_group,
      nace_broad = nace_r2,
      bea_value = value,
      bea_sector_share,
      bea_top_level_coverage_ratio,
      bea_share_denominator
    ) |>
    left_join(fats_broad_sector_reference,
      by = c("affiliate", "nace_broad")
    ) |>
    mutate(
      fats_reference_year = SECTORAL_REFERENCE_YEAR,
      fats_comparator_share = case_when(
        measure == "employment" ~ fats_employee_share,
        measure == "compensation" ~ fats_payroll_share,
        measure == "ppe_expenditures" ~ fats_investment_share,
        measure == "total_assets" ~ fats_asset_share,
        TRUE ~ NA_real_
      ),
      share_gap = bea_sector_share - fats_comparator_share,
      abs_share_gap = abs(share_gap),
      comparator_interpretation = case_when(
        measure == "employment" ~
          "BEA employment share versus FATS employee share",
        measure == "compensation" ~
          "BEA compensation share versus FATS personnel-cost share",
        measure == "ppe_expenditures" ~
          "BEA PPE expenditure share versus FATS investment-flow share",
        measure == "total_assets" ~
          "BEA total-asset share versus FATS/EUKLEMS sectoral asset share",
        TRUE ~ NA_character_
      )
    ) |>
    arrange(measure, bea_year, affiliate, nace_broad)

  bea_fats_broad_sector_validation_summary <-
    bea_fats_broad_sector_validation |>
    filter(!is.na(fats_comparator_share)) |>
    group_by(measure, bea_year) |>
    summarise(
      n_sector_country_cells = n(),
      eu27_affiliates = n_distinct(affiliate),
      mean_abs_share_gap = mean(abs_share_gap, na.rm = TRUE),
      bea_weighted_abs_share_gap = weighted_mean_available(
        abs_share_gap,
        bea_sector_share
      ),
      share_correlation = safe_cor(bea_sector_share, fats_comparator_share,
        min_pairs = 2L
      ),
      mean_bea_top_level_coverage_ratio = weighted_mean_available(
        bea_top_level_coverage_ratio,
        bea_share_denominator
      ),
      .groups = "drop"
    ) |>
    mutate(
      validation_decision = classify_bea_bridge_signal(
        measure,
        share_correlation,
        mean_abs_share_gap
      ),
      measurement_interpretation = case_when(
        validation_decision == "reject_as_primary_asset_allocator" ~
          "BEA total assets are not used as the sectoral asset allocator",
        validation_decision == "supportive_external_benchmark" ~
          "BEA supports the broad direction of the FATS/EUKLEMS bridge",
        validation_decision == "caution_external_benchmark" ~
          "BEA is directionally useful but remains a benchmark only",
        TRUE ~ "BEA remains a benchmark only"
      )
    ) |>
    arrange(measure, bea_year)

  h5_sample <- stage2_sectoral_matrix |>
    filter(
      transition_year == min(SECTORAL_TRANSITION_YEARS),
      is.finite(sectoral_delta_floor_average),
      is.finite(sectoral_capital_intensity),
      sectoral_profit_proxy > 0
    )

  h5_fit <- stats::lm(
    sectoral_delta_floor_average ~ sectoral_capital_intensity + factor(affiliate),
    data = h5_sample
  )
  h5_fit_weighted <- stats::lm(
    sectoral_delta_floor_average ~ sectoral_capital_intensity + factor(affiliate),
    data = h5_sample,
    weights = sectoral_profit_proxy
  )
  h5_fit_summary <- summary(h5_fit)

  stage2_sectoral_h5_regression <- as.data.frame(h5_fit_summary$coefficients) |>
    rownames_to_column("term") |>
    as_tibble() |>
    rename(
      estimate = Estimate,
      std_error = `Std. Error`,
      statistic = `t value`,
      p_value = `Pr(>|t|)`
    ) |>
    mutate(
      n_obs = stats::nobs(h5_fit),
      r_squared = h5_fit_summary$r.squared,
      adj_r_squared = h5_fit_summary$adj.r.squared,
      dependent_variable = "sectoral_delta_floor_average",
      reference_year = SECTORAL_REFERENCE_YEAR,
      transition_year = min(SECTORAL_TRANSITION_YEARS)
    )

  stage2_sectoral_h5_regression_clustered <- bind_rows(
    tidy_lm_clustered(h5_fit, h5_sample$affiliate, "unweighted"),
    tidy_lm_clustered(h5_fit_weighted, h5_sample$affiliate, "profit_weighted")
  )

  stage2_sectoral_h5_model_tests <- stage2_sectoral_h5_regression_clustered |>
    filter(term == "sectoral_capital_intensity") |>
    transmute(
      model_variant,
      inference,
      test = "cluster_wald_capital_intensity",
      df_num = 1,
      df_den = df_cluster,
      f_statistic = statistic^2,
      p_value,
      n_obs,
      n_clusters,
      r_squared,
      adj_r_squared,
      dependent_variable,
      reference_year,
      transition_year
    )

  stage2_bilateral_initial <- stage2_bilateral |>
    filter(rate_scenario == "initial")

  stage2_summary <- tibble(
    metric = c(
      "pair_years_total",
      "pair_years_positive_profit",
      "aggregate_payroll_zero_fallback_rows_positive_profit",
      "aggregate_assets_zero_fallback_rows_positive_profit",
      "aggregate_phi_cap_rows_positive_profit_initial",
      "aggregate_global_stage1_distributional_topup_in_payroll_fallback_rows",
      "aggregate_global_stage1_distributional_topup_in_payroll_fallback_share",
      "sectoral_reference_affiliates_2022",
      "sectoral_reference_rows_2022",
      "sectoral_transition_rows",
      "sectoral_bridge_euklems_asset_affiliates_2022",
      "sectoral_bridge_fats_asset_fallback_affiliates_2022",
      "bea_total_assets_share_correlation",
      "bea_total_assets_mean_abs_share_gap",
      "sectoral_h5_capital_intensity_beta",
      "sectoral_h5_capital_intensity_pvalue",
      "sectoral_h5_capital_intensity_pvalue_clustered",
      "sectoral_h5_capital_intensity_pvalue_weighted_clustered",
      "sectoral_h5_r_squared"
    ),
    value = c(
      nrow(stage2_bilateral_initial),
      sum(stage2_bilateral_initial$analysis_profit_positive > 0, na.rm = TRUE),
      sum(stage2_bilateral_initial$stage2_payroll_zero_fallback_flag, na.rm = TRUE),
      sum(stage2_bilateral_initial$stage2_assets_zero_fallback_flag, na.rm = TRUE),
      sum(stage2_bilateral_initial$stage2_phi_capped_flag, na.rm = TRUE),
      sum(stage2_bilateral_initial$stage1_topup_tax_distributional[
        stage2_bilateral_initial$stage2_payroll_zero_fallback_flag
      ], na.rm = TRUE),
      safe_divide(
        sum(stage2_bilateral_initial$stage1_topup_tax_distributional[
          stage2_bilateral_initial$stage2_payroll_zero_fallback_flag
        ], na.rm = TRUE),
        sum(stage2_bilateral_initial$stage1_topup_tax_distributional, na.rm = TRUE)
      ),
      n_distinct(stage2_sectoral_matrix$affiliate),
      sum(stage2_sectoral_matrix$transition_year == SECTORAL_TRANSITION_YEARS[1]),
      nrow(stage2_sectoral_matrix),
      sum(grepl(
        "^euklems",
        sectoral_bridge_country_quality$asset_country_year_source
      ), na.rm = TRUE),
      sum(grepl(
        "^fats",
        sectoral_bridge_country_quality$asset_country_year_source
      ), na.rm = TRUE),
      bea_fats_broad_sector_validation_summary$share_correlation[
        bea_fats_broad_sector_validation_summary$measure == "total_assets"
      ][1],
      bea_fats_broad_sector_validation_summary$mean_abs_share_gap[
        bea_fats_broad_sector_validation_summary$measure == "total_assets"
      ][1],
      stage2_sectoral_h5_regression$estimate[
        stage2_sectoral_h5_regression$term == "sectoral_capital_intensity"
      ][1],
      stage2_sectoral_h5_regression$p_value[
        stage2_sectoral_h5_regression$term == "sectoral_capital_intensity"
      ][1],
      stage2_sectoral_h5_regression_clustered$p_value[
        stage2_sectoral_h5_regression_clustered$model_variant == "unweighted" &
          stage2_sectoral_h5_regression_clustered$term ==
            "sectoral_capital_intensity"
      ][1],
      stage2_sectoral_h5_regression_clustered$p_value[
        stage2_sectoral_h5_regression_clustered$model_variant ==
          "profit_weighted" &
          stage2_sectoral_h5_regression_clustered$term ==
            "sectoral_capital_intensity"
      ][1],
      stage2_sectoral_h5_regression$r_squared[1]
    )
  )

  write_csv(stage2_summary, file.path(DIAGNOSTICS_DIR, "step4_stage2_summary.csv"))
  write_csv(
    stage2_scenario_by_year,
    file.path(DIAGNOSTICS_DIR, "step4_stage2_scenario_by_year.csv")
  )
  write_csv(
    stage2_payroll_fallback_by_year,
    file.path(DIAGNOSTICS_DIR, "step4_stage2_payroll_fallback_by_year.csv")
  )
  write_csv(
    sectoral_weights_check,
    file.path(DIAGNOSTICS_DIR, "step4_stage2_sectoral_weights_check.csv")
  )
  write_csv(
    sectoral_bridge_source_summary,
    file.path(DIAGNOSTICS_DIR, "step4_stage2_sectoral_bridge_source_summary.csv")
  )
  write_csv(
    sectoral_bridge_country_quality,
    file.path(DIAGNOSTICS_DIR, "step4_stage2_sectoral_bridge_country_quality.csv")
  )
  write_csv(
    stage2_sectoral_country_summary,
    file.path(DIAGNOSTICS_DIR, "step4_stage2_sectoral_country_summary.csv")
  )
  write_csv(
    stage2_sectoral_h5_regression,
    file.path(DIAGNOSTICS_DIR, "step4_stage2_sectoral_h5_regression.csv")
  )
  write_csv(
    stage2_sectoral_h5_regression_clustered,
    file.path(
      DIAGNOSTICS_DIR,
      "step4_stage2_sectoral_h5_regression_clustered.csv"
    )
  )
  write_csv(
    stage2_sectoral_h5_model_tests,
    file.path(DIAGNOSTICS_DIR, "step4_stage2_sectoral_h5_model_tests.csv")
  )
  write_csv(
    stage2_sectoral_asset_sensitivity,
    file.path(DIAGNOSTICS_DIR, "step4_stage2_sectoral_asset_sensitivity.csv")
  )
  write_csv(
    bea_fats_broad_sector_validation,
    file.path(DIAGNOSTICS_DIR, "step4_stage2_bea_fats_broad_sector_validation.csv")
  )
  write_csv(
    bea_fats_broad_sector_validation_summary,
    file.path(DIAGNOSTICS_DIR, "step4_stage2_bea_fats_broad_sector_validation_summary.csv")
  )
  write_csv(
    stage2_irl_nld_comparison,
    file.path(DIAGNOSTICS_DIR, "step4_stage2_irl_nld_comparison.csv")
  )

  saveRDS(stage2_bilateral, file.path(PROCESSED_DIR, "stage2_bilateral_panel.rds"))
  saveRDS(stage2_affiliate_year, file.path(PROCESSED_DIR, "stage2_affiliate_year.rds"))
  saveRDS(stage2_sectoral_matrix, file.path(PROCESSED_DIR, "stage2_sectoral_matrix.rds"))

  message("\nStep 4 outputs written:")
  message(" - data/processed/stage2_bilateral_panel.rds")
  message(" - data/processed/stage2_affiliate_year.rds")
  message(" - data/processed/stage2_sectoral_matrix.rds")
  message(" - diagnostics/step4_stage2_*.csv")
}
