# Dollar inputs are bilateral payroll, tangible assets and corrected positive
# profit. Rates and shield fractions are unitless. The shared helper contracts
# preserve missing denominators and zero activity contributions.

compute_sbie_value <- function(payroll, assets, sigma_w, sigma_a) {
  sigma_w * coalesce_zero(payroll) + sigma_a * coalesce_zero(assets)
}

compute_phi_ratio <- function(sbie, profit) {
  raw_phi <- safe_divide(sbie, profit)
  clamp_unit_interval(raw_phi)
}

compute_effective_floor <- function(topup_gap, phi, threshold = GMT_RATE) {
  dplyr::if_else(
    is.na(topup_gap) | is.na(phi),
    NA_real_,
    pmax(0, threshold - pmax(topup_gap, 0) * clamp_unit_interval(phi))
  )
}

# Keep Stage 1 measures and raw activity alongside the two endpoint rows.
# A missing top-up enters the numerical liability calculation as zero. A
# missing low-tax profit or floor input remains missing in those outputs.
build_aggregate_bilateral_sbie <- function(stage1_bilateral, endpoints) {
  # Aggregate bilateral Stage 2 filter. Missing payroll enters as a conservative
  # zero contribution so that the panel remains complete for downstream work;
  # the affected rows are flagged and quantified in the diagnostics.
  stage2_bilateral <- stage1_bilateral |>
    tidyr::crossing(endpoints) |>
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
      stage2_sbie_shield_distributional_bilat =
        stage1_lowtax_profit_distributional_bilat * coalesce(stage2_phi, 0),
      stage2_sbie_shield_distributional_strict =
        stage1_lowtax_profit_distributional_strict * coalesce(stage2_phi, 0),
      stage2_excess_lowtax_profit_average =
        stage1_lowtax_profit_average * stage2_filter,
      stage2_excess_lowtax_profit_distributional =
        stage1_lowtax_profit_distributional * stage2_filter,
      stage2_excess_lowtax_profit_distributional_bilat =
        stage1_lowtax_profit_distributional_bilat * stage2_filter,
      stage2_excess_lowtax_profit_distributional_strict =
        stage1_lowtax_profit_distributional_strict * stage2_filter,
      stage2_topup_tax_average =
        coalesce(stage1_topup_tax_average, 0) * stage2_filter,
      stage2_topup_tax_distributional =
        coalesce(stage1_topup_tax_distributional, 0) * stage2_filter,
      stage2_topup_tax_distributional_bilat =
        coalesce(stage1_topup_tax_distributional_bilat, 0) * stage2_filter,
      stage2_topup_tax_distributional_strict =
        coalesce(stage1_topup_tax_distributional_strict, 0) * stage2_filter,
      stage2_effective_floor_average =
        compute_effective_floor(average_topup_rate, stage2_phi),
      stage2_effective_floor_distributional =
        compute_effective_floor(stage1_distributional_topup_rate, stage2_phi),
      stage2_effective_floor_distributional_bilat =
        compute_effective_floor(stage1_distributional_topup_rate_bilat, stage2_phi),
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

  stage2_bilateral
}
