# Run from the repository root after Stages 4.5 and 4.6.
source("code/05_stage3_behavioral_functions.R")
source("code/06_stage4_5_revenue_allocation_sbs_functions.R")
source("code/07_stage4_6_revenue_pipeline_decomposition_functions.R")

read_stage5_input <- function(stem) readRDS(file.path(PROCESSED_DIR, paste0(stem, ".rds")))

write_stage5_diagnostic <- function(data, stem) {
  write_csv(data, file.path(DIAGNOSTICS_DIR, paste0("step7_", stem, ".csv")))
}

stage5_source_inputs <- function() {
  read_stage5_input("stage3_factorial_pair_year") |>
    select(
      all_of(SCENARIO_VARS), parent, affiliate, year, pair_id,
      affiliate_jurisdiction_name, parent_jurisdiction_name, affiliate_is_conduit_haven,
      employees_sbie, assets_sbie, stage2_phi, act_ip_panelai, act_holding_panelai,
      act_igf_panelai, analysis_profit_positive, average_low_share,
      stage1_distributional_low_share, stage1_distributional_low_share_bilat,
      stage1_lowtax_profit_average, stage1_lowtax_profit_distributional,
      stage1_lowtax_profit_distributional_bilat, stage1_topup_tax_distributional_bilat,
      stage2_excess_lowtax_profit_average, stage2_excess_lowtax_profit_distributional,
      stage2_excess_lowtax_profit_distributional_bilat, stage2_topup_selected,
      stage2_topup_tax_distributional_bilat, sectoral_scale_selected,
      static_tau_low, static_beta_applied, static_behavioural_regime,
      topup_after_stage2, topup_after_behaviour, qdmtt_flag, sbs_exempt,
      parent_iir_utpr_flag, affiliate_oecd_iir_by_2026,
      affiliate_policy_iir_utpr_by_2026, affiliate_policy_utpr_by_2026,
      affiliate_policy_iir_utpr_explicit_by_2026, affiliate_policy_iir_utpr_ambiguous_by_2026
    )
}

# Independent Factor 2b under aggregate SBIE. Keep sector-specific kappa
# and sector profit weights, and apply them to the common aggregate post-SBIE
# gap. Under sectoral SBIE the production calculation applies both overlays.
build_split_substance_scales <- function() {
  stage2 <- read_stage5_input("stage2_bilateral_panel")
  stage1 <- read_stage5_input("stage1_affiliate_year")
  sectors <- read_stage5_input("stage2_sectoral_panel")
  keys <- c("rate_scenario", "affiliate", "year")
  sector_only <- build_sectoral_factor2_bridge(
    stage2, stage1, mutate(sectors, sectoral_kappa = 0)
  )
  sector_gap <- sector_only |>
    select(all_of(keys), starts_with("aggregate_tax_per_profit_")) |>
    left_join(
      select(stage1, affiliate, year, average_low_share, stage1_distributional_low_share),
      by = c("affiliate", "year"), relationship = "many-to-one"
    ) |>
    mutate(
      gap_average = safe_divide(aggregate_tax_per_profit_average, average_low_share),
      gap_distributional = safe_divide(
        aggregate_tax_per_profit_distributional, stage1_distributional_low_share
      )
    )
  overlay_only <- sectors |>
    filter(rate_scenario %in% STAGE2_ENDPOINTS$rate_scenario) |>
    inner_join(select(sector_gap, all_of(keys), starts_with("gap_")),
      by = keys, relationship = "many-to-one"
    ) |>
    group_by(across(all_of(keys))) |>
    summarise(
      overlay_same_average = safe_divide(
        weighted_mean_available(pmax(gap_average - sectoral_kappa, 0), sectoral_profit_proxy),
        first(gap_average)
      ),
      overlay_same_distributional = safe_divide(
        weighted_mean_available(pmax(gap_distributional - sectoral_kappa, 0), sectoral_profit_proxy),
        first(gap_distributional)
      ),
      .groups = "drop"
    )
  overlay_reference <- overlay_only |>
    filter(year == SECTORAL_REFERENCE_YEAR) |>
    transmute(rate_scenario, affiliate, overlay_ref_average = overlay_same_average,
      overlay_ref_distributional = overlay_same_distributional
    )
  sector_only |>
    select(all_of(keys), sector_only_average = sectoral_scale_average,
      sector_only_distributional = sectoral_scale_distributional
    ) |>
    left_join(overlay_only, by = keys, relationship = "one-to-one") |>
    left_join(overlay_reference, by = c("rate_scenario", "affiliate"), relationship = "many-to-one") |>
    transmute(
      across(all_of(keys)), sector_only_average, sector_only_distributional,
      overlay_only_average = coalesce(overlay_same_average, overlay_ref_average, 1),
      overlay_only_distributional = coalesce(overlay_same_distributional, overlay_ref_distributional, 1)
    )
}

get_ppml_schedule <- function() {
  coefficients <- read_csv(
    file.path(DIAGNOSTICS_DIR, "step5_stage3_alternative_estimators.csv"),
    show_col_types = FALSE
  ) |>
    filter(estimator == "fe_ppml_positive", sample == "positive_profit",
      model_spec == "logarithmic", statistic_type == "coefficient",
      term %in% c("tau", "log_tau"), converged
    )
  stopifnot(nrow(coefficients) == 2, n_distinct(coefficients$t0) == 1)
  observed <- read_stage5_input("stage3_estimation_sample")$tau
  list(
    beta3 = coefficients$estimate[coefficients$term == "tau"],
    beta4 = coefficients$estimate[coefficients$term == "log_tau"],
    t0 = first(coefficients$t0),
    tau_min = unname(quantile(observed, 0.05, na.rm = TRUE))
  )
}

ppml_reallocation_share <- function(tau_low, schedule, tau_floor = 0) {
  tau <- clamp_interval(tau_low, 0, GMT_RATE)
  tau_floor <- clamp_interval(tau_floor, 0, GMT_RATE)
  knot <- pmax(tau, tau_floor)
  log_ratio <- schedule$beta3 * (GMT_RATE - knot) +
    schedule$beta4 * log((schedule$t0 + GMT_RATE) / (schedule$t0 + knot)) +
    (schedule$beta3 + schedule$beta4 / (schedule$t0 + knot)) * (knot - tau)
  coalesce(clamp_unit_interval(-expm1(log_ratio)), 0)
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

build_bilateral_measurement_variant <- function(panel) {
  # Behavioural response is still calibrated at affiliate-year, using
  # the implied low-bracket gap from the bilateral-first profit and tax.
  bilateral_host <- panel |>
    filter(scenario_id == "x10001") |>
    group_by(affiliate, year) |>
    summarise(
      tau_bilateral = GMT_RATE - safe_divide(
        sum(stage1_topup_tax_distributional_bilat, na.rm = TRUE),
        sum(stage1_lowtax_profit_distributional_bilat, na.rm = TRUE)
      ),
      .groups = "drop"
    ) |>
    mutate(tau_bilateral = if_else(tau_bilateral < GMT_RATE, tau_bilateral, NA_real_))
  beta <- read_csv(
    file.path(DIAGNOSTICS_DIR, "step5_stage3_alternative_estimators.csv"),
    show_col_types = FALSE
  ) |>
    filter(estimator == "fe_ols", sample == "positive_profit", model_spec == "linear",
      statistic_type == "coefficient", term == "tau"
    ) |>
    pull(estimate)
  stopifnot(length(beta) == 1, is.finite(beta))
  distributional <- panel |>
    filter(x1_etr == 1) |>
    left_join(bilateral_host, by = c("affiliate", "year"), relationship = "many-to-one") |>
    mutate(
      stage1_distributional_low_share = stage1_distributional_low_share_bilat,
      stage1_lowtax_profit_distributional = stage1_lowtax_profit_distributional_bilat,
      stage2_excess_lowtax_profit_distributional = stage2_excess_lowtax_profit_distributional_bilat,
      stage2_topup_selected = stage2_topup_tax_distributional_bilat,
      topup_after_stage2 = pmax(stage2_topup_selected * sectoral_scale_selected, 0)
    )
  beta_raw <- coalesce(compute_reallocation_share(
    distributional$tau_bilateral, rep_len("linear", nrow(distributional)), beta
  ), 0)
  bind_rows(
    filter(panel, x1_etr == 0),
    replace_behaviour_schedule(distributional, distributional$tau_bilateral, beta_raw) |>
      select(all_of(names(panel)))
  )
}

build_split_substance_variant <- function(panel, scales) {
  # 00 and 11 inherit the exact baseline amounts. The two off-diagonal
  # cells have one mechanism active. x2_substance denotes sectoral SBIE.
  joint <- panel |>
    mutate(x2a_sectoral = x2_substance, x2b_sbti = x2_substance)
  separate <- panel |>
    filter(x2_substance == 0) |>
    crossing(x2a_sectoral = 0:1) |>
    left_join(scales, by = c("rate_scenario", "affiliate", "year"), relationship = "many-to-one") |>
    mutate(
      x2b_sbti = 1L - x2a_sectoral,
      sectoral_scale_selected = coalesce(case_when(
        x2a_sectoral == 1 & x1_etr == 0 ~ sector_only_average,
        x2a_sectoral == 1 ~ sector_only_distributional,
        x1_etr == 0 ~ overlay_only_average,
        TRUE ~ overlay_only_distributional
      ), 1),
      topup_after_stage2 = pmax(stage2_topup_selected * sectoral_scale_selected, 0),
      x2_substance = x2a_sectoral,
      factor2_substance = if_else(x2a_sectoral == 1, "sectoral_sbie_only", "aggregate_sbie_sbti"),
      scenario_id = paste0("x", x1_etr, x2a_sectoral, x2b_sbti, x3_rates, x4_sbs, x5_behaviour)
    ) |>
    add_behavioural_response() |>
    select(all_of(names(joint)))
  bind_rows(joint, separate) |>
    mutate(scenario_id = paste0("x", x1_etr, x2a_sectoral, x2b_sbti, x3_rates, x4_sbs, x5_behaviour))
}

allocate_stress_variant <- function(panel, weights) {
  source <- build_source_panel(panel)
  allocation <- allocate_stage4_revenue(source, weights)
  conservation <- build_conservation_diagnostics(source, allocation$revenue_by_channel_global)
  list(revenue = allocation$revenue_country_year_eu27, gap = max(abs(conservation$residual_gap)))
}

# Orthogonal contrasts within each country-year, followed by pooling sums
# of squares. Shapley divides each interaction SS equally among its factors.
summarise_stress_variant <- function(revenue, design, factors, variant, gap, tau_floor = NA_real_) {
  design <- arrange(design, scenario_id)
  n_scenarios <- 2^length(factors)
  stopifnot(nrow(design) == n_scenarios, nrow(distinct(design, across(all_of(factors)))) == n_scenarios)
  contrasts <- design |>
    mutate(across(all_of(factors), ~ 2 * .x - 1))
  x <- model.matrix(reformulate(paste(factors, collapse = "*")), data = contrasts)
  stopifnot(all(crossprod(x) == diag(n_scenarios) * n_scenarios))
  assert_unique_keys(revenue, c("country", "year", "scenario_id"), variant)
  revenues <- revenue |>
    select(country, year, scenario_id, revenue) |>
    pivot_wider(names_from = scenario_id, values_from = revenue)
  stopifnot(nrow(revenues) == length(EU27_ISO3) * length(MAIN_YEARS))
  y <- t(as.matrix(revenues[design$scenario_id]))
  stopifnot(all(is.finite(y)))
  effects <- strsplit(colnames(x)[-1], ":", fixed = TRUE)
  map_dfr(c(2017L, 2019L), function(start) {
    window_y <- y[, revenues$year >= start, drop = FALSE]
    coefficients <- crossprod(x, window_y) / n_scenarios
    ss <- n_scenarios * rowSums(coefficients[-1, , drop = FALSE]^2)
    total_ss <- sum(sweep(window_y, 2, colMeans(window_y))^2)
    stopifnot(abs(sum(ss) / total_ss - 1) < 1e-12)
    eta <- ss / total_ss
    order <- lengths(effects)
    shapley <- vapply(factors, function(factor) {
      sum(eta[vapply(effects, function(effect) factor %in% effect, logical(1))] /
        order[vapply(effects, function(effect) factor %in% effect, logical(1))])
    }, numeric(1))
    stopifnot(abs(sum(shapley) - 1) < 1e-12)
    total <- rowSums(window_y)
    tibble(
      variant, start_year = start, end_year = max(MAIN_YEARS), country_years = ncol(window_y),
      n_scenarios, effect = factors,
      main_eta_squared = eta[match(factors, colnames(x)[-1])],
      shapley_eta_squared = unname(shapley), interaction_eta_squared = sum(eta[order > 1]),
      min_scenario = design$scenario_id[which.min(total)], min_eu27_revenue = min(total),
      max_scenario = design$scenario_id[which.max(total)], max_eu27_revenue = max(total),
      eu27_revenue_spread = max(total) - min(total),
      max_global_conservation_gap = gap, ppml_tau_floor = tau_floor
    )
  })
}

build_architecture_stress <- function(panel, weights, baseline_revenue, baseline_gap) {
  base_design <- distinct(baseline_revenue, scenario_id, across(all_of(FACTOR_COLS)))
  a <- summarise_stress_variant(baseline_revenue, base_design, FACTOR_COLS, "A_baseline", baseline_gap)
  a_reference <- read_stage5_input("stage4_6_measurement_sample_main_effects")
  for (start in c(2017L, 2019L)) {
    expected <- filter(a_reference, start_year == start, end_year == max(MAIN_YEARS))
    observed <- filter(a, start_year == start)
    stopifnot(max(abs(observed$main_eta_squared - expected$eta_squared[
      match(observed$effect, expected$effect)
    ])) < 1e-12)
  }

  message("Stress-testing bilateral-first Table IV")
  b <- allocate_stress_variant(build_bilateral_measurement_variant(panel), weights)
  b_summary <- summarise_stress_variant(b$revenue, base_design, FACTOR_COLS, "B_bilateral_first", b$gap)

  message("Stress-testing FE-PPML logarithmic behaviour")
  ppml <- get_ppml_schedule()
  ppml_rows <- imap_dfr(c(C_ppml_uncapped = 0, C_ppml_p05_cap = ppml$tau_min), function(floor, variant) {
    counterfactual <- replace_behaviour_schedule(
      panel, panel$static_tau_low, ppml_reallocation_share(panel$static_tau_low, ppml, floor)
    )
    allocation <- allocate_stress_variant(counterfactual, weights)
    summarise_stress_variant(allocation$revenue, base_design, FACTOR_COLS,
      variant, allocation$gap, floor
    )
  }) |>
    mutate(ppml_beta_tau = ppml$beta3, ppml_beta_log = ppml$beta4, ppml_t0 = ppml$t0,
      ppml_epsilon_at_005 = -(ppml$beta3 + ppml$beta4 / (ppml$t0 + 0.05))
    )

  message("Splitting sectoral SBIE and SBTI into independent factors")
  split <- build_split_substance_variant(panel, build_split_substance_scales())
  factors <- c("x1_etr", "x2a_sectoral", "x2b_sbti", "x3_rates", "x4_sbs", "x5_behaviour")
  split_design <- distinct(split, scenario_id, across(all_of(factors)))
  d <- allocate_stress_variant(split, weights)
  diagonal <- d$revenue |>
    inner_join(select(split_design, scenario_id, x2a_sectoral, x2b_sbti), by = "scenario_id") |>
    filter(x2a_sectoral == x2b_sbti) |>
    transmute(
      scenario_id = paste0("x", x1_etr, x2_substance, x3_rates, x4_sbs, x5_behaviour),
      country, year, split_revenue = revenue
    ) |>
    left_join(select(baseline_revenue, scenario_id, country, year, revenue),
      by = c("scenario_id", "country", "year"), relationship = "one-to-one"
    )
  stopifnot(nrow(diagonal) == nrow(baseline_revenue),
    max(abs(diagonal$split_revenue - diagonal$revenue)) < 1e-4
  )
  d_summary <- summarise_stress_variant(d$revenue, split_design, factors, "D_split_substance", d$gap)
  bind_rows(a, b_summary, ppml_rows, d_summary)
}

PREFERRED_STAGE5_IDS <- c("x10001", "x10011")

build_vintage_window_comparison <- function(revenue) {
  archived <- readRDS(file.path(BASELINE_PROCESSED_DIR, "stage4_5_revenue_country_year.rds"))
  stopifnot(setequal(archived$year, 2017:2022))
  samples <- list(
    archived_thesis_2017_2022 = archived,
    updated_pipeline_2017_2022 = filter(revenue, year %in% 2017:2022),
    updated_pipeline_2017_2023 = revenue
  )
  imap_dfr(samples, function(data, sample) {
    scenarios <- build_scenario_summary(data)
    anova <- compute_factorial_anova(data)$pooled
    shapley <- build_shapley_factor_attribution(anova)
    tibble(
      sample, start_year = min(data$year), end_year = max(data$year),
      country_years = n_distinct(data$country, data$year),
      eu27_revenue_min = min(scenarios$eu_revenue), eu27_revenue_max = max(scenarios$eu_revenue),
      preferred_universal_revenue = scenarios$eu_revenue[scenarios$scenario_id == PREFERRED_STAGE5_IDS[1]],
      preferred_sbs_revenue = scenarios$eu_revenue[scenarios$scenario_id == PREFERRED_STAGE5_IDS[2]],
      etr_main_eta_squared = anova$eta_squared[anova$effect == "x1_etr"],
      etr_shapley_eta_squared = shapley$shapley_eta_squared[shapley$effect == "x1_etr"]
    )
  })
}

build_source_routing <- function(source, weights) {
  # UTPR can return to the source itself when it is an eligible collector.
  # Match the same parent-year or fallback weights as the allocator.
  parent_keys <- weights$parent_year_weights |>
    distinct(parent, year) |>
    mutate(has_parent_weights = TRUE)
  parent_own <- weights$parent_year_weights |>
    transmute(parent, year, affiliate = collector, own_parent_weight = utpr_weight)
  fallback_own <- weights$fallback_weights |>
    transmute(year, affiliate = collector, own_fallback_weight = utpr_weight)
  source |>
    filter(affiliate %in% EU27_ISO3) |>
    left_join(parent_keys, by = c("parent", "year"), relationship = "many-to-one") |>
    left_join(parent_own, by = c("parent", "year", "affiliate"), relationship = "many-to-one") |>
    left_join(fallback_own, by = c("year", "affiliate"), relationship = "many-to-one") |>
    mutate(
      own_utpr_weight = if_else(coalesce(has_parent_weights, FALSE),
        coalesce_zero(own_parent_weight), coalesce_zero(own_fallback_weight)
      ),
      domestic_utpr = stage4_utpr_pool * own_utpr_weight
    ) |>
    group_by(country = affiliate, year, scenario_id) |>
    summarise(
      positive_corrected_affiliate_profit = sum(analysis_profit_positive, na.rm = TRUE),
      distributional_low_taxed_profit = sum(stage1_lowtax_profit_distributional, na.rm = TRUE),
      source_topup_liability = sum(topup_after_behaviour),
      source_retained_qdmtt = sum(stage4_qdmtt_liability),
      source_domestic_iir = sum(stage4_iir_liability[affiliate == parent]),
      source_exported_iir = sum(stage4_iir_liability[affiliate != parent]),
      source_domestic_utpr = sum(domestic_utpr),
      source_exported_utpr = sum(stage4_utpr_pool - domestic_utpr),
      source_sbs_extinguished = sum(stage4_sbs_extinguished_liability),
      .groups = "drop"
    )
}

stage5_collector_channels <- function(country_year, by_channel) {
  keys <- c("country", "year", "scenario_id")
  channel_amounts <- country_year |>
    select(all_of(keys)) |>
    crossing(channel = c("QDMTT", "IIR", "UTPR")) |>
    left_join(select(by_channel, all_of(keys), channel, revenue),
      by = c(keys, "channel"), relationship = "one-to-one"
    ) |>
    mutate(revenue = coalesce_zero(revenue)) |>
    pivot_wider(names_from = channel, values_from = revenue, names_prefix = "collector_")
  country_year |>
    select(all_of(keys), country_name, collector_revenue = revenue) |>
    left_join(channel_amounts, by = keys, relationship = "one-to-one")
}

build_stage5_ledger <- function(source, weights, revenue, channels, cit, legal, years) {
  collectors <- stage5_collector_channels(
    filter(revenue, year %in% years, scenario_id %in% PREFERRED_STAGE5_IDS),
    filter(channels, year %in% years, scenario_id %in% PREFERRED_STAGE5_IDS)
  )
  routed <- build_source_routing(filter(source, year %in% years), weights)
  flows <- collectors |>
    left_join(routed, by = c("country", "year", "scenario_id"), relationship = "one-to-one") |>
    mutate(across(starts_with("source_"), coalesce_zero),
      across(c(positive_corrected_affiliate_profit, distributional_low_taxed_profit), coalesce_zero)
    ) |>
    left_join(select(cit, country, year, cit_revenue_T_1200),
      by = c("country", "year"), relationship = "many-to-one"
    )
  stopifnot(
    max(abs(with(flows, source_topup_liability - source_retained_qdmtt -
      source_domestic_iir - source_exported_iir - source_domestic_utpr -
      source_exported_utpr - source_sbs_extinguished))) < 1e-4,
    max(abs(with(flows, collector_revenue - collector_QDMTT - collector_IIR - collector_UTPR))) < 1e-4,
    max(abs(flows$source_retained_qdmtt - flows$collector_QDMTT)) < 1e-4
  )

  spreads <- revenue |>
    filter(year %in% years) |>
    build_country_scenario_totals() |>
    build_country_spread() |>
    select(country, min_revenue, max_revenue, scenario_spread, scenario_at_min, scenario_at_max)

  flows |>
    group_by(country, country_name, scenario_id) |>
    summarise(
      across(c(positive_corrected_affiliate_profit, distributional_low_taxed_profit,
        starts_with("source_"), starts_with("collector_")), sum),
      cit_years_observed = sum(is.finite(cit_revenue_T_1200)),
      cit_revenue_T_1200 = if (cit_years_observed == length(years)) sum(cit_revenue_T_1200) else NA_real_,
      .groups = "drop"
    ) |>
    mutate(
      start_year = min(years), end_year = max(years),
      net_fiscal_position = collector_revenue - source_topup_liability,
      collector_revenue_pct_of_cit = 100 * safe_divide(collector_revenue, cit_revenue_T_1200)
    ) |>
    left_join(spreads, by = "country", relationship = "many-to-one") |>
    left_join(legal, by = "country", relationship = "many-to-one") |>
    arrange(country, scenario_id)
}

summarise_legal_scenario <- function(allocation, source, legal, regime, active) {
  totals <- stage5_collector_channels(
    allocation$revenue_country_year_eu27, allocation$revenue_by_channel_eu27
  ) |>
    left_join(
      source |>
        filter(affiliate %in% EU27_ISO3) |>
        group_by(country = affiliate, year, scenario_id) |>
        summarise(source_topup_liability = sum(topup_after_behaviour), .groups = "drop"),
      by = c("country", "year", "scenario_id"), relationship = "one-to-one"
    ) |>
    mutate(source_topup_liability = coalesce_zero(source_topup_liability))
  map_dfr(c(min(MAIN_YEARS), max(MAIN_YEARS)), function(start) {
    data <- filter(totals, year >= start)
    amounts <- c("source_topup_liability", "collector_revenue", "collector_QDMTT", "collector_IIR", "collector_UTPR")
    bind_rows(
      data |>
        group_by(country, scenario_id) |>
        summarise(across(all_of(amounts), sum), .groups = "drop"),
      data |>
        group_by(scenario_id) |>
        summarise(across(all_of(amounts), sum), .groups = "drop") |>
        mutate(country = "EU27")
    ) |>
      left_join(legal, by = "country", relationship = "many-to-one") |>
      mutate(
        regime, start_year = start, end_year = max(MAIN_YEARS),
        qdmtt_active = qdmtt_by_2026 | country %in% active,
        iir_active = iir_by_2026 | country %in% active,
        net_fiscal_position = collector_revenue - source_topup_liability
      )
  })
}

build_legal_sensitivity <- function(panel, weights, legal, baseline_revenue) {
  regimes <- list(
    R1_central_record_2026_05_01 = character(),
    R2_cyprus_domestic_law = "CYP",
    R3_full_eu27_qdmtt_iir = EU27_ISO3
  )
  rows <- imap_dfr(regimes, function(active, regime) {
    # Only QDMTT and IIR status are intervened on. Hold the UTPR collector
    # set and weights fixed. The production IIR routing flag is combined,
    # so change it only on the parent side for newly active IIRs.
    counterfactual <- panel |>
      mutate(
        qdmtt_flag = qdmtt_flag | affiliate %in% active,
        parent_iir_utpr_flag = parent_iir_utpr_flag | parent %in% active
      ) |>
      add_behavioural_response() |>
      build_source_panel()
    allocation <- allocate_stage4_revenue(counterfactual, weights)
    conservation <- build_conservation_diagnostics(counterfactual, allocation$revenue_by_channel_global)
    if (!length(active)) {
      check <- allocation$revenue_country_year_eu27 |>
        inner_join(select(baseline_revenue, country, year, scenario_id, baseline = revenue),
          by = c("country", "year", "scenario_id"), relationship = "one-to-one"
        )
      stopifnot(nrow(check) == 2 * length(MAIN_YEARS) * length(EU27_ISO3),
        max(abs(check$revenue - check$baseline)) < 1e-4
      )
    }
    summarise_legal_scenario(allocation, counterfactual, legal, regime, active) |>
      mutate(max_global_conservation_gap = max(abs(conservation$residual_gap)))
  })
  baseline <- rows |>
    filter(regime == names(regimes)[1]) |>
    select(country, scenario_id, start_year, baseline_collector_revenue = collector_revenue)
  rows |>
    left_join(baseline, by = c("country", "scenario_id", "start_year"), relationship = "many-to-one") |>
    mutate(collector_revenue_change_vs_baseline = collector_revenue - baseline_collector_revenue) |>
    arrange(start_year, country, scenario_id, regime)
}

extract_compression_terms <- function(fit, data, pattern) {
  coefs <- fixest::coeftable(fit)
  ci <- confint(fit)
  terms <- grep(pattern, rownames(coefs), value = TRUE)
  used <- data[fixest::obs(fit), ]
  tibble(
    term = terms, estimate = coefs[terms, 1],
    estimate_unit = if_else(terms == "statutory_cit_10pp",
      "outcome_pp_per_10pp_statutory_cit", "outcome_pp_per_10pp_pre_agreement_exposure"
    ),
    clustered_se = coefs[terms, 2], p_value = coefs[terms, 4],
    ci95_lower = ci[terms, 1], ci95_upper = ci[terms, 2],
    observations = nobs(fit), pairs = n_distinct(used$pair_id),
    affiliates = n_distinct(used$affiliate), parents = n_distinct(used$parent)
  )
}

build_pre_implementation_compression <- function(stage1) {
  outcomes <- c("etr_panelai_stage1", "stage1_distributional_low_share",
    "stage1_distributional_liability_rate")
  positive <- stage1 |>
    filter(year %in% MAIN_YEARS, analysis_profit_positive > 0) |>
    select(pair_id, parent, affiliate, year, all_of(outcomes),
      affiliate_cit_rate_unit, stage1_distributional_source
    )
  exposure <- positive |>
    filter(year %in% 2017:2019, is.finite(stage1_distributional_low_share)) |>
    group_by(pair_id) |>
    summarise(
      pre_years = n_distinct(year),
      exposure_10pp = mean(stage1_distributional_low_share) / 0.10,
      .groups = "drop"
    ) |>
    filter(pre_years >= 2)
  study <- positive |>
    inner_join(exposure, by = "pair_id", relationship = "many-to-one") |>
    mutate(post_exposure = as.integer(year %in% 2022:2023) * exposure_10pp)
  stable_pairs <- study |>
    filter(year %in% 2020:2023, stage1_distributional_source == "direct_t4") |>
    count(pair_id) |>
    filter(n == 4L) |>
    select(pair_id)
  samples <- list(
    disjoint_2020_2023 = filter(study, year >= 2020L),
    full_2017_2023 = study,
    balanced_direct_t4_2020_2023 = study |>
      filter(year >= 2020L) |>
      semi_join(stable_pairs, by = "pair_id")
  )
  imap_dfr(samples, function(sample, sample_name) {
    map_dfr(outcomes, function(outcome) {
      data <- sample |>
        filter(is.finite(.data[[outcome]]), is.finite(affiliate_cit_rate_unit)) |>
        mutate(outcome_pp = 100 * .data[[outcome]], statutory_cit_10pp = affiliate_cit_rate_unit / 0.10) |>
        group_by(pair_id) |>
        filter(any(year == 2021L), any(year %in% 2022:2023), n() >= 2) |>
        ungroup()
      if (sample_name == "balanced_direct_t4_2020_2023") {
        data <- data |> group_by(pair_id) |> filter(n() == 4L) |> ungroup()
      }
      event <- fixest::feols(
        outcome_pp ~ i(year, exposure_10pp, ref = 2021) + statutory_cit_10pp | pair_id + year,
        data = data, vcov = ~affiliate, notes = FALSE
      )
      post <- fixest::feols(
        outcome_pp ~ post_exposure + statutory_cit_10pp | pair_id + year,
        data = data, vcov = ~affiliate, notes = FALSE
      )
      joint <- fixest::wald(event, keep = "^year::(2022|2023):", print = FALSE)
      stopifnot(is.list(joint), joint$df1 == 2L)
      bind_rows(
        extract_compression_terms(event, data, "^year::|^statutory_cit_10pp$") |>
          mutate(model = "event_study", post_joint_F = joint$stat, post_joint_p = joint$p),
        extract_compression_terms(post, data, "^post_exposure$|^statutory_cit_10pp$") |>
          mutate(model = "pooled_post")
      ) |>
        mutate(outcome, sample = sample_name, reference_year = 2021L,
          fixed_effects = "pair_and_year", cluster = "affiliate", .before = 1
        )
    })
  })
}

run_stage5_diagnostics <- function() {
  panel <- stage5_source_inputs()
  weights <- list(
    parent_year_weights = read_stage5_input("stage4_5_utpr_parent_year_weights"),
    fallback_weights = read_stage5_input("stage4_5_utpr_fallback_weights")
  )
  revenue <- read_stage5_input("stage4_5_revenue_country_year")
  conservation <- read_stage5_input("stage4_5_allocation_conservation")
  write_stage5_diagnostic(build_vintage_window_comparison(revenue), "stage4_6_vintage_window_comparison")
  stress <- build_architecture_stress(panel, weights, revenue, max(abs(conservation$residual_gap)))
  write_stage5_diagnostic(stress, "decomposition_architecture_stress_test")

  message("Building fiscal flow ledgers and legal counterfactuals")
  legal <- read_csv(
    file.path(DIAGNOSTICS_DIR, "step5_stage3_eu27_legal_regime_classification.csv"),
    show_col_types = FALSE
  ) |>
    transmute(country = jurisdiction, qdmtt_by_2026, iir_by_2026,
      table_current_as = central_record_snapshot,
      article50_deferral = article50_iir_utpr_deferral
    )
  preferred <- filter(panel, scenario_id %in% PREFERRED_STAGE5_IDS)
  source <- build_source_panel(preferred)
  channels <- read_stage5_input("stage4_5_revenue_by_channel")
  cit <- build_cit_revenue_denominators(read_stage5_input("cit_revenue"))
  for (years in list(MAIN_YEARS, max(MAIN_YEARS))) {
    ledger <- build_stage5_ledger(source, weights, revenue, channels, cit, legal, years)
    stopifnot(nrow(ledger) == length(EU27_ISO3) * length(PREFERRED_STAGE5_IDS))
    year_label <- paste(unique(range(years)), collapse = "_")
    write_stage5_diagnostic(ledger, paste0("eu27_source_vs_collector_ledger_", year_label))
  }
  legal_sensitivity <- build_legal_sensitivity(preferred, weights, legal, revenue)
  write_stage5_diagnostic(legal_sensitivity, "cyprus_and_article50_sensitivity")

  message("Estimating pre-implementation compression diagnostics")
  compression <- build_pre_implementation_compression(read_stage5_input("stage1_bilateral_panel"))
  write_stage5_diagnostic(compression, "pre_implementation_compression_test")
}

if (is_direct_script_run("code/diagnostics_step5_revenue_architecture.R")) {
  run_stage5_diagnostics()
}
