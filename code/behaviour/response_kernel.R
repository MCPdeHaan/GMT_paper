# Behavioural schedules and source-cell arithmetic. Rates are fractions,
# beta3 and beta4 are signed profit coefficients, and monetary amounts are USD.
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "00_helpers.R"), local = TRUE)

SESH_BANDWIDTH_BASELINE <- 0.02
SESH_BANDWIDTH_SENSITIVITY <- c(0.01, 0.02, 0.03)

behavioural_bandwidth <- function(specification = behavioural_specification()) {
  if (behavioural_specification(specification) == "BASELINE_NOTCH") SESH_BANDWIDTH_BASELINE else 0
}

BEHAVIOURAL_MAX_REALLOCATION_SHARE <- 1
# Fixed sensitivity benchmark motivated by Heckemeyer and Overesch (2017).
DIAGNOSTIC_CHANNEL_PRIOR_TP_IP <- 0.72
DIAGNOSTIC_CHANNEL_PRIOR_DEBT <- 0.28
DIAGNOSTIC_CHANNEL_PRIOR_SUBSTANCE <- 0

counterfactual_profit_ratio <- function(tau, model_spec, beta3,
                                        beta4 = NA_real_, t0 = NA_real_,
                                        threshold = GMT_RATE) {
  tau <- pmin(pmax(tau, 0), threshold)

  exponent <- case_when(
    model_spec == "linear" ~
      beta3 * (threshold - tau),
    model_spec == "quadratic" ~
      beta3 * (threshold - tau) + beta4 * (threshold^2 - tau^2),
    model_spec == "logarithmic" ~
      beta3 * (threshold - tau) +
      beta4 * (log(t0 + threshold) - log(t0 + tau)),
    TRUE ~ NA_real_
  )

  clamp_unit_interval(exp(exponent))
}

compute_reallocation_share <- function(tau, model_spec, beta3,
                                       beta4 = NA_real_, t0 = NA_real_,
                                       threshold = GMT_RATE) {
  1 - counterfactual_profit_ratio(tau, model_spec, beta3, beta4, t0, threshold)
}

apply_behavioural_regime <- function(tau_low, beta_raw,
                                     threshold = GMT_RATE,
                                     eta = behavioural_bandwidth()) {
  in_band <- is.finite(tau_low) & tau_low >= threshold - eta & tau_low < threshold
  below_band <- is.finite(tau_low) & tau_low < threshold - eta
  beta_applied <- if_else(below_band & is.finite(beta_raw), clamp_unit_interval(beta_raw), 0)

  tibble(
    beta_applied = beta_applied,
    behavioural_liability_filter = case_when(
      in_band ~ 0,
      below_band ~ 1 - beta_applied,
      TRUE ~ 1
    ),
    behavioural_regime = case_when(
      in_band ~ "sesh_bunching_topup_zero",
      below_band ~ "semi_elasticity_reallocation",
      TRUE ~ "no_low_tax_response"
    )
  )
}

# Apply an available static schedule to a factorial source panel. Source
# exposure is determined here; recipient support is determined in allocation.
add_behavioural_response <- function(scenario_panel) {
  scenario_panel |>
    mutate(
      selected_low_share = if_else(
        factor1_etr == "average",
        average_low_share,
        stage1_distributional_low_share
      ),
      stage2_excess_lowtax_profit_selected = if_else(
        factor1_etr == "average",
        stage2_excess_lowtax_profit_average,
        stage2_excess_lowtax_profit_distributional
      ),
      stage2_lowtax_profit_selected = if_else(
        factor1_etr == "average",
        stage1_lowtax_profit_average,
        stage1_lowtax_profit_distributional
      ),
      post_sbie_topup_rate = safe_divide(
        topup_after_stage2,
        stage2_excess_lowtax_profit_selected
      ),
      post_gmt_tax_gap_relative = clamp_unit_interval(
        safe_divide(post_sbie_topup_rate, GMT_RATE)
      ),
      ip_holding_count = coalesce_zero(act_ip_panelai) +
        coalesce_zero(act_holding_panelai) + coalesce_zero(act_igf_panelai),
      profit_per_employee = safe_divide(
        analysis_profit_positive,
        pmax(coalesce_zero(employees_sbie), 1)
      ),
      profit_to_assets = safe_divide(
        analysis_profit_positive,
        pmax(coalesce_zero(assets_sbie), 1)
      ),
      low_substance_score = clamp_unit_interval(1 - coalesce(stage2_phi, 0)),
      substance_anchor_score = clamp_unit_interval(coalesce(stage2_phi, 0)),
      conduit_haven_score = as.numeric(coalesce(affiliate_is_conduit_haven, FALSE))
    ) |>
    group_by(year, scenario_id) |>
    mutate(
      ip_holding_score = rank01(log1p(ip_holding_count)),
      profit_per_employee_score = rank01(log1p(pmax(profit_per_employee, 0))),
      profit_to_assets_score = rank01(log1p(pmax(profit_to_assets, 0)))
    ) |>
    ungroup() |>
    mutate(
      policy_collection_exposure = case_when(
        qdmtt_flag ~ 1,
        sbs_exempt & !qdmtt_flag ~ 0,
        TRUE ~ 1
      ),
      diagnostic_planning_intensity = 1,
      strategic_response_eligible =
        factor5_behaviour == "behavioural" &
          static_behavioural_regime == "semi_elasticity_reallocation" &
          topup_after_stage2 > 0 &
          coalesce(stage2_excess_lowtax_profit_selected, 0) > 0,
      strategic_beta_applied = if_else(
        strategic_response_eligible,
        pmin(
          static_beta_applied * policy_collection_exposure,
          BEHAVIOURAL_MAX_REALLOCATION_SHARE
        ),
        0
      ),
      behavioural_liability_filter = case_when(
        factor5_behaviour == "mechanical" ~ 1,
        static_behavioural_regime == "sesh_bunching_topup_zero" ~ 0,
        strategic_response_eligible ~ 1 - strategic_beta_applied,
        TRUE ~ 1
      ),
      beta_applied = if_else(
        factor5_behaviour == "behavioural",
        strategic_beta_applied,
        0
      ),
      behavioural_regime = case_when(
        factor5_behaviour == "mechanical" ~ "mechanical",
        static_behavioural_regime == "sesh_bunching_topup_zero" ~
          "sesh_bunching_topup_zero",
        strategic_response_eligible ~ "semi_elasticity_reallocation",
        factor5_behaviour == "behavioural" ~ "no_low_tax_response",
        TRUE ~ "mechanical"
      ),
      topup_after_behaviour = pmax(
        topup_after_stage2 * behavioural_liability_filter,
        0
      ),
      behavioural_avoided_topup = pmax(
        topup_after_stage2 - topup_after_behaviour,
        0
      ),
      reallocated_profit = if_else(
        strategic_response_eligible,
        pmax(stage2_excess_lowtax_profit_selected, 0) *
          strategic_beta_applied,
        0
      ),
      tp_ip_channel_raw = DIAGNOSTIC_CHANNEL_PRIOR_TP_IP,
      debt_channel_raw = DIAGNOSTIC_CHANNEL_PRIOR_DEBT,
      substance_channel_raw = DIAGNOSTIC_CHANNEL_PRIOR_SUBSTANCE,
      behavioural_channel_total =
        tp_ip_channel_raw + debt_channel_raw + substance_channel_raw,
      channel_transfer_pricing_ip_share =
        tp_ip_channel_raw / behavioural_channel_total,
      channel_debt_share = debt_channel_raw / behavioural_channel_total,
      channel_substance_planning_share =
        substance_channel_raw / behavioural_channel_total,
      reallocated_profit_transfer_pricing_ip =
        reallocated_profit * channel_transfer_pricing_ip_share,
      reallocated_profit_debt = reallocated_profit * channel_debt_share,
      reallocated_profit_substance_planning =
        reallocated_profit * channel_substance_planning_share
    )
}

replace_behaviour_schedule <- function(panel, tau_low, beta_raw) {
  regime <- apply_behavioural_regime(tau_low, beta_raw)
  panel |>
    mutate(
      static_tau_low = tau_low,
      static_beta_applied = regime$beta_applied,
      static_behavioural_regime = regime$behavioural_regime
    ) |>
    add_behavioural_response()
}
