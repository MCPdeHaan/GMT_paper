# Stage 04 supplies its filtered EU27 FATS shares, affiliate-year dollar
# totals and transition schedule. Shares have keys affiliate, year and NACE.
# Retain sector rows even when the totals lookup has no matching row.
sectoral_weights_summary <- function(sector_shares) {
  sectoral_weights_check <- sector_shares |>
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

  sectoral_weights_check
}

build_sectoral_transition_panel <- function(sector_shares, country_year_base, transition_rates) {
  assert_unique_keys(sector_shares, c("affiliate", "year", "nace_r2"), "sectoral shares")
  assert_unique_keys(country_year_base, c("affiliate", "year"), "sectoral base")
  sectoral_weights_check <- sectoral_weights_summary(sector_shares)

  # Sectoral SBIE with SBTI overlay. Unlike the aggregate bilateral SBIE above,
  # this allocates affiliate-year profit, payroll and assets across NACE sectors.
  sectoral_transition_panel <- sector_shares |>
    left_join(country_year_base, by = c("affiliate", "year"),
      relationship = "many-to-one"
    ) |>
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
        sbti_maximum_capacity(sectoral_payroll, sectoral_assets),
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
    sectoral_transition_panel,
    c("affiliate", "year", "transition_year", "nace_r2"),
    "stage2 sectoral panel"
  )

  list(panel = sectoral_transition_panel, weights = sectoral_weights_check)
}

# Use the Stage 3 liability formula for the decomposition. The separate
# effective-floor overlay in the H5 diagnostic is a capacity measure.
summarise_sectoral_sbie_rates <- function(sectoral_panel, stage1_affiliate_year,
                                        rate_scenarios = STAGE2_ENDPOINTS$rate_scenario) {
  sectoral_panel |>
    filter(rate_scenario %in% rate_scenarios) |>
    left_join(
      stage1_affiliate_year |>
        transmute(
          affiliate, year, average_low_share,
          distributional_low_share = stage1_distributional_low_share
        ),
      by = c("affiliate", "year"),
      relationship = "many-to-one"
    ) |>
    mutate(
      average_post_sbie_gap = average_topup_rate * (1 - sectoral_phi),
      distributional_post_sbie_gap =
        stage1_distributional_topup_rate * (1 - sectoral_phi)
    ) |>
    group_by(rate_scenario, affiliate, year) |>
    summarise(
      sectoral_sbie_per_profit_average = first(average_low_share) *
        weighted_mean_available(average_post_sbie_gap, sectoral_profit_proxy),
      sectoral_sbie_sbti_per_profit_average = first(average_low_share) *
        weighted_mean_available(pmax(average_post_sbie_gap - sectoral_kappa, 0),
          sectoral_profit_proxy
        ),
      sectoral_sbie_per_profit_distributional = first(distributional_low_share) *
        weighted_mean_available(distributional_post_sbie_gap, sectoral_profit_proxy),
      sectoral_sbie_sbti_per_profit_distributional = first(distributional_low_share) *
        weighted_mean_available(pmax(distributional_post_sbie_gap - sectoral_kappa, 0),
          sectoral_profit_proxy
        ),
      weighted_sectoral_phi = weighted_mean_available(sectoral_phi, sectoral_profit_proxy),
      weighted_sectoral_kappa = weighted_mean_available(sectoral_kappa, sectoral_profit_proxy),
      .groups = "drop"
    )
}
