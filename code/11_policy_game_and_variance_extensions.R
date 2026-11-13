# Fiscal flows, allocation counterfactuals, policy games and uncertainty.

source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "10_accounting_bridge_and_conduit_wedge.R"), local = TRUE)

# Factorial stress, fiscal flows, legal regimes and pre-implementation compression

write_stage5_diagnostic <- function(data, stem) {
  write_csv(data, file.path(DIAGNOSTICS_DIR, paste0("step7_", stem, ".csv")))
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
build_architecture_stress <- function(panel, weights, baseline_revenue, baseline_gap) {
  base_design <- distinct(baseline_revenue, scenario_id, across(all_of(FACTOR_COLS)))
  a <- summarise_stress_variant(baseline_revenue, base_design, FACTOR_COLS, "A_baseline", baseline_gap)
  a_reference <- read_stage5_input("stage4_6_measurement_sample_main_effects")
  for (start in c(2017L, 2019L, 2021L)) {
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

run_fiscal_flows_and_stress_tests <- function() {
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

# Unilateral QDMTT deviations, SBTI and bilateral spillovers

NASH_KEYS <- c("parent", "affiliate", "year")
NASH_IDS <- c("x10001", "x10011")
NASH_LEVELS <- c("L3_pooled", "L4_strict")
NASH_DEVIATIONS <- c("qdmtt_repeal", "full_opt_out")
NASH_WINDOWS <- list("2017–2023" = MAIN_YEARS, FY2023 = 2023L)
NASH_STRATEGY_WINDOWS <- list("2021–2023" = 2021:2023, FY2023 = 2023L)
NASH_HUBS <- c("IRL", "NLD", "LUX", "CYP", "MLT", "HUN", "BEL", "EST", "LTU", "LVA")
NASH_TOL <- 1e-3

nash_read <- function(stem) readRDS(file.path(PROCESSED_DIR, paste0(stem, ".rds")))

nash_load_panels <- function() {
  common <- nash_read("stage3_factorial_pair_year") |>
    filter(scenario_id %in% NASH_IDS) |>
    select(all_of(SCENARIO_VARS), all_of(NASH_KEYS), affiliate_jurisdiction_name,
      parent_jurisdiction_name, affiliate_is_conduit_haven, affiliate_is_eu27,
      affiliate_policy_iir_utpr_by_2026, affiliate_policy_utpr_by_2026,
      affiliate_policy_iir_utpr_explicit_by_2026, affiliate_policy_iir_utpr_ambiguous_by_2026,
      affiliate_oecd_iir_by_2026, qdmtt_flag, parent_iir_utpr_flag, sbs_exempt,
      employees_sbie, assets_sbie, payroll_sbie, act_ip_panelai, act_holding_panelai,
      act_igf_panelai, analysis_profit_positive, stage2_phi, average_low_share,
      stage1_lowtax_profit_average, stage2_excess_lowtax_profit_average,
      stage1_distributional_low_share, stage1_distributional_topup_rate,
      stage1_lowtax_profit_distributional, stage2_excess_lowtax_profit_distributional,
      topup_after_stage2, static_tau_low, static_beta_applied, static_behavioural_regime,
      topup_after_behaviour, reallocated_profit)
  beta <- nash_read("stage3_model_coefficients") |>
    filter(model_spec == "linear", term == "tau", inference == "parent_affiliate_clustered") |>
    pull(estimate)
  stopifnot(length(beta) == 1L, is.finite(beta))
  assert_unique_keys(common, c("scenario_id", NASH_KEYS), "Step 13 production panel")
  strict <- nash_read("stage1_bilateral_panel") |>
    select(all_of(NASH_KEYS), ladder_l4_strict_low_share, ladder_l4_strict_topup_rate,
      ladder_l4_strict_lowtax_profit, ladder_l4_strict_topup_tax)
  stopifnot(nrow(common) == 2 * nrow(strict), setequal(common$parent[common$sbs_exempt], "USA"))
  strict_panel <- common |>
      left_join(strict, by = NASH_KEYS, relationship = "many-to-one") |>
      mutate(
        stage1_distributional_low_share = ladder_l4_strict_low_share,
        stage1_distributional_topup_rate = ladder_l4_strict_topup_rate,
        stage1_lowtax_profit_distributional = ladder_l4_strict_lowtax_profit,
        stage2_excess_lowtax_profit_distributional =
          ladder_l4_strict_lowtax_profit * (1 - coalesce_zero(stage2_phi)),
        topup_after_stage2 = ladder_l4_strict_topup_tax * (1 - coalesce_zero(stage2_phi)),
        tau = if_else(ladder_l4_strict_low_share > 0 & ladder_l4_strict_topup_rate > 0,
          GMT_RATE - ladder_l4_strict_topup_rate, NA_real_)
      )
  strict_panel <- replace_behaviour_schedule(strict_panel, strict_panel$tau,
    coalesce_zero(compute_reallocation_share(strict_panel$tau, rep_len("linear", nrow(strict_panel)), beta)))
  list(L3_pooled = common, L4_strict = strict_panel)
}

nash_channels <- function(source, weights, check = TRUE) {
  allocation <- allocate_stage4_revenue(source, weights)
  channels <- allocation$revenue_by_channel_global |>
    summarise(revenue = sum(revenue), .by = c(scenario_id, country, year, channel))
  if (check) {
    conservation <- build_conservation_diagnostics(source, allocation$revenue_by_channel_global)
    return(list(channels = channels, max_gap = max(abs(conservation$residual_gap))))
  }
  channels
}

nash_revenue <- function(channels, country, channel = NULL) {
  selected <- channels$country == country
  if (!is.null(channel)) selected <- selected & channels$channel == channel
  sum(channels$revenue[selected])
}

nash_r3_panel <- function(panel) {
  # Match the repository's R3: universal EU27 QDMTT and IIR, frozen UTPR set.
  panel |>
    mutate(qdmtt_flag = qdmtt_flag | affiliate_is_eu27,
      parent_iir_utpr_flag = parent_iir_utpr_flag | parent %in% EU27_ISO3) |>
    add_behavioural_response() |>
    build_source_panel()
}

nash_verify_benchmarks <- function(panels, weights, r3) {
  saved <- nash_read("stage4_5_revenue_country_year") |>
    filter(scenario_id %in% NASH_IDS) |>
    select(scenario_id, country, year, saved = revenue)
  r1 <- nash_channels(build_source_panel(panels$L3_pooled), weights)$channels |>
    filter(country %in% EU27_ISO3) |>
    summarise(replayed = sum(revenue), .by = c(scenario_id, country, year))
  replay <- left_join(saved, r1, by = c("scenario_id", "country", "year"), relationship = "one-to-one")
  r1_gap <- max(abs(replay$saved - coalesce_zero(replay$replayed)))
  stopifnot(r1_gap < NASH_TOL)
  r3_saved <- read_csv(file.path(DIAGNOSTICS_DIR, "step7_cyprus_and_article50_sensitivity.csv"),
    show_col_types = FALSE) |>
    filter(regime == "R3_full_eu27_qdmtt_iir", country %in% EU27_ISO3,
      start_year == min(MAIN_YEARS)) |>
    select(scenario_id, country, saved = collector_revenue)
  actual <- r3$L3_pooled$allocation$channels |>
    filter(country %in% EU27_ISO3) |>
    summarise(replayed = sum(revenue), .by = c(scenario_id, country))
  stopifnot(nrow(r3_saved) == 54L)
  r3_gap <- max(abs(r3_saved$saved - coalesce_zero(left_join(r3_saved, actual,
    by = c("scenario_id", "country"), relationship = "one-to-one")$replayed)))
  stopifnot(r3_gap < NASH_TOL)
  strict_saved <- read_csv(file.path(DIAGNOSTICS_DIR, "step9_ladder_sbs_exposure.csv"),
    show_col_types = FALSE) |>
    filter(level == LADDER_LEVELS[5], scope == "EU27", window == "2017–2023")
  strict_channels <- nash_channels(build_source_panel(panels$L4_strict), weights)$channels |>
    filter(country %in% EU27_ISO3)
  stopifnot(nrow(strict_saved) == 1L)
  strict_gap <- max(abs(c(
    sum(strict_channels$revenue[strict_channels$scenario_id == "x10001"]) -
      strict_saved$direct_collector_usd_universal,
    sum(strict_channels$revenue[strict_channels$scenario_id == "x10011"]) -
      strict_saved$direct_collector_usd_sbs
  )))
  stopifnot(strict_gap < NASH_TOL)
  message(sprintf("R1 L3, R3 L3 and R1 L4 replay gaps: USD %.9g / %.9g / %.9g",
    r1_gap, r3_gap, strict_gap))
}

nash_build_deviation <- function(base, country, deviation, weights) {
  exit <- deviation == "full_opt_out"
  source <- base |>
    mutate(
      qdmtt_flag = qdmtt_flag & affiliate != country,
      parent_iir_utpr_flag = parent_iir_utpr_flag & !(exit & parent == country)
    ) |>
    add_behavioural_response() |>
    build_source_panel()
  host <- filter(source, affiliate == country)
  list(source = source, allocation = nash_channels(source, weights),
    host_channels = nash_channels(host, weights, check = FALSE))
}

nash_summarise_deviation <- function(base, result, country, years, regime, window) {
  id <- NASH_IDS[match(regime, c("Universal", "SbS"))]
  before <- filter(base$source, scenario_id == id, year %in% years, affiliate == country)
  after <- filter(result$source, scenario_id == id, year %in% years, affiliate == country)
  stopifnot(nrow(before) > 0L, identical(select(before, all_of(NASH_KEYS)), select(after, all_of(NASH_KEYS))))
  initial <- filter(base$allocation$channels, scenario_id == id, year %in% years)
  revised <- filter(result$allocation$channels, scenario_id == id, year %in% years)
  host <- filter(result$host_channels, scenario_id == id, year %in% years)
  qdmtt <- sum(before$stage4_qdmtt_liability)
  us <- before$parent == "USA"
  foreign_parent <- before$parent != country
  self_iir <- nash_revenue(host, country, "IIR")
  self_utpr <- nash_revenue(host, country, "UTPR")
  foreign_iir <- sum(host$revenue[host$country != country & host$channel == "IIR"])
  foreign_utpr <- sum(host$revenue[host$country != country & host$channel == "UTPR"])
  tax_saved <- qdmtt - sum(host$revenue)
  us_tax_saved <- sum(before$stage4_qdmtt_liability[us]) - sum(
    after$stage4_iir_liability[us] + after$stage4_utpr_pool[us])
  # Compute relief on the adoption base. The extinguished post-repeal
  # liability includes the change in the base when behaviour is recomputed.
  extinguished <- sum(after$stage4_sbs_extinguished_liability)
  liability_rebound <- sum(after$topup_after_behaviour - before$topup_after_behaviour)
  retained <- before$reallocated_profit - after$reallocated_profit
  source_cit <- sum(retained * coalesce_zero(before$static_tau_low))
  delta_collector <- nash_revenue(revised, country) - nash_revenue(initial, country)
  delta_total_tax <- delta_collector + source_cit
  fiscal_cost <- -delta_total_tax
  retain_total <- sum(retained)
  if (abs(tax_saved) < NASH_TOL) tax_saved <- 0
  if (abs(us_tax_saved) < NASH_TOL) us_tax_saved <- 0
  source_gap <- qdmtt - (self_iir + self_utpr + foreign_iir + foreign_utpr + tax_saved)
  stopifnot(abs(source_gap) < NASH_TOL, abs(extinguished - liability_rebound - tax_saved) < NASH_TOL,
    all(retained >= -NASH_TOL), abs(sum(retained[!us])) < NASH_TOL,
    abs(sum(after$stage4_iir_liability[after$parent == country]) - self_iir) < NASH_TOL)
  if (regime == "Universal") stopifnot(tax_saved == 0, extinguished == 0, retain_total == 0)
  if (regime == "SbS") stopifnot(abs(tax_saved - us_tax_saved) < NASH_TOL)
  tibble(
    country, regime, scenario_id = id, window, start_year = min(years), end_year = max(years),
    adoption_qdmtt = qdmtt, delta_qdmtt = -qdmtt,
    adoption_qdmtt_us = sum(before$stage4_qdmtt_liability[us]),
    adoption_qdmtt_foreign_parent = sum(before$stage4_qdmtt_liability[foreign_parent]),
    us_share_foreign_parent_qdmtt = safe_divide(adoption_qdmtt_us, adoption_qdmtt_foreign_parent),
    domestic_iir_recapture = self_iir, domestic_utpr_recapture = self_utpr,
    foreign_iir_soakup = foreign_iir, foreign_utpr_soakup = foreign_utpr,
    foreign_soakup = foreign_iir + foreign_utpr,
    foreign_soakup_share_of_foregone_qdmtt = safe_divide(foreign_soakup, qdmtt),
    mne_topup_saved = tax_saved, us_mne_topup_saved = us_tax_saved,
    sbs_extinguished_post_repeal = extinguished,
    counterfactual_liability_rebound = liability_rebound,
    retained_profit = retain_total, retained_us_profit = sum(retained[us]), retained_source_cit = source_cit,
    domestic_adoption_collector = nash_revenue(initial, country),
    domestic_deviation_collector = nash_revenue(revised, country),
    delta_domestic_collector = delta_collector,
    delta_domestic_iir_all_sources = nash_revenue(revised, country, "IIR") - nash_revenue(initial, country, "IIR"),
    delta_domestic_utpr_all_sources = nash_revenue(revised, country, "UTPR") - nash_revenue(initial, country, "UTPR"),
    delta_domestic_collector_from_other_sources = delta_collector + qdmtt - self_iir - self_utpr,
    delta_total_domestic_tax = delta_total_tax,
    net_domestic_tax_foregone = fiscal_cost,
    tax_cut_efficiency = safe_divide(tax_saved, abs(delta_collector)),
    topup_cut_per_net_tax_cost = safe_divide(tax_saved, abs(fiscal_cost)),
    critical_welfare_weight = if (retain_total > 0) max(0, fiscal_cost / retain_total) else
      if (fiscal_cost < -NASH_TOL) 0 else Inf,
    fiscal_gain_at_zero_weight = delta_total_tax > NASH_TOL,
    fiscal_tie_at_zero_weight = abs(delta_total_tax) <= NASH_TOL,
    source_incidence_residual = source_gap,
    global_topup_saved_all_sources = sum(initial$revenue) - sum(revised$revenue),
    max_global_conservation_gap = result$allocation$max_gap
  )
}

nash_network <- function(base, result, country, years, window, collectors) {
  # Net spillovers can also include reallocation of pre-existing UTPR pools
  # and loss of the deviator's outward IIR under a full opt-out.
  full <- bind_rows(mutate(base$allocation$channels, arm = "adoption"),
    mutate(result$allocation$channels, arm = "deviation")) |>
    filter(year %in% years) |>
    summarise(revenue = sum(revenue), .by = c(scenario_id, country, channel, arm)) |>
    pivot_wider(names_from = arm, values_from = revenue, values_fill = 0)
  host <- result$host_channels |>
    filter(year %in% years) |>
    summarise(source_windfall = sum(revenue), .by = c(scenario_id, country, channel))
  cross <- expand_grid(scenario_id = NASH_IDS, country = collectors, channel = c("IIR", "UTPR")) |>
    left_join(full, by = c("scenario_id", "country", "channel"), relationship = "one-to-one") |>
    left_join(host, by = c("scenario_id", "country", "channel"), relationship = "one-to-one") |>
    mutate(across(c(adoption, deviation, source_windfall), coalesce_zero),
      net_collector_change = deviation - adoption,
      net_change_from_other_sources = net_collector_change - source_windfall)
  cross |>
    select(scenario_id, collector = country, channel, source_windfall, net_collector_change,
      net_change_from_other_sources) |>
    pivot_wider(names_from = scenario_id,
      values_from = c(source_windfall, net_collector_change, net_change_from_other_sources)) |>
    rename_with(~ sub("_x10001$", "_universal", .x)) |>
    rename_with(~ sub("_x10011$", "_sbs", .x)) |>
    mutate(
      source_country = country, collector_is_eu27 = collector %in% EU27_ISO3,
      collector_is_foreign = collector != country, window,
      source_windfall_removed_by_sbs = source_windfall_universal - source_windfall_sbs,
      net_collector_change_removed_by_sbs = net_collector_change_universal - net_collector_change_sbs,
      share_of_universal_windfall_removed = safe_divide(source_windfall_removed_by_sbs, source_windfall_universal)
    ) |>
    relocate(source_country, collector, channel, window)
}

nash_sbti_capacity <- function(base, sector_shares) {
  # Keep aggregate SBIE and the adoption behavioural response fixed.
  # Synthetic sector rows only distribute the low-tax base and capacity.
  sources <- base$source |>
    filter(scenario_id == "x10011", affiliate_is_eu27, year %in% 2021:2023,
      stage4_qdmtt_liability > 0) |>
    transmute(
      across(all_of(NASH_KEYS)), qdmtt = stage4_qdmtt_liability,
      low_profit = stage1_lowtax_profit_distributional,
      excess_low_profit = stage2_excess_lowtax_profit_distributional,
      low_share = stage1_distributional_low_share, gap = stage1_distributional_topup_rate,
      payroll = pmax(coalesce_zero(payroll_sbie), 0),
      assets = pmax(coalesce_zero(assets_sbie), 0),
      behavioural_factor = safe_divide(stage4_qdmtt_liability, topup_after_stage2)
    )
  stopifnot(all(is.finite(sources$low_share)), all(is.finite(sources$behavioural_factor)),
    all(sources$behavioural_factor >= 0 & sources$behavioural_factor <= 1))
  sector <- sources |>
    inner_join(sector_shares, by = c("affiliate", "year"), relationship = "many-to-many") |>
    mutate(
      sector_low_profit = low_profit * profit_share,
      sector_excess_low_profit = excess_low_profit * profit_share,
      # Assume the low-tax part uses its share of each sector's substance.
      payroll_cap = 0.055 * payroll * payroll_share * low_share,
      carrying_value_cap = 0.01 * assets * asset_share * low_share,
      # Mirrors the repository's max proxy. Legal methods apply at MNE
      # jurisdiction level, not sector level, and the default includes
      # depreciation, which the bilateral CbCR input does not measure.
      capacity = pmax(payroll_cap, carrying_value_cap),
      sector_qdmtt = qdmtt * profit_share,
      covered_tax_proxy = pmax(0, GMT_RATE - gap) * sector_low_profit,
      used_new_qti = pmin(capacity, covered_tax_proxy),
      new_qti_net_covered_tax = covered_tax_proxy - used_new_qti + used_new_qti,
      sbti_overlay_relief = behavioural_factor *
        pmin(gap * sector_excess_low_profit, capacity),
      # If an incentive is already reflected in observed tax, recognise
      # a capped add-back in the ETR numerator before applying SBIE.
      existing_qti_relief = behavioural_factor * sector_excess_low_profit *
        pmin(gap, coalesce_zero(safe_divide(capacity, sector_low_profit)))
    )
  amounts <- c("sector_qdmtt", "payroll_cap", "carrying_value_cap", "capacity",
    "used_new_qti", "sbti_overlay_relief", "existing_qti_relief", "covered_tax_proxy",
    "new_qti_net_covered_tax")
  cells <- sector |>
    summarise(across(all_of(amounts), sum), .by = all_of(NASH_KEYS)) |>
    left_join(select(sources, all_of(NASH_KEYS), qdmtt), by = NASH_KEYS, relationship = "one-to-one")
  stopifnot(nrow(cells) == nrow(sources), max(abs(cells$sector_qdmtt - cells$qdmtt)) < NASH_TOL,
    all(cells$sbti_overlay_relief <= cells$qdmtt + NASH_TOL),
    all(cells$existing_qti_relief <= cells$sbti_overlay_relief + NASH_TOL),
    all(cells$used_new_qti <= cells$capacity + NASH_TOL),
    all(abs(cells$new_qti_net_covered_tax - cells$covered_tax_proxy) < NASH_TOL))
  cells
}

nash_sector_shares <- function() {
  shares <- nash_read("stage2_sectoral_panel") |>
    filter(rate_scenario == "initial", year %in% 2021:2023) |>
    transmute(affiliate, year, nace_r2,
      payroll_share = coalesce_zero(sectoral_payroll_share_used),
      asset_share = coalesce_zero(sectoral_asset_share_used),
      profit_share = coalesce_zero(sectoral_profit_share_used))
  assert_unique_keys(shares, c("affiliate", "year", "nace_r2"), "Step 13 sector shares")
  totals <- shares |>
    summarise(across(ends_with("_share"), sum), .by = c(affiliate, year))
  stopifnot(nrow(totals) == length(EU27_ISO3) * 3L,
    all(abs(as.matrix(select(totals, ends_with("_share"))) - 1) < 1e-8),
    all(as.matrix(select(shares, ends_with("_share"))) >= 0))
  shares
}

nash_summarise_strategy <- function(base, repeal, sector_shares, weights) {
  cells <- nash_sbti_capacity(base, sector_shares)
  # Applying the overlay separately to every source is additive because
  # all affected rows remain QDMTT rows and the collection weights stay fixed.
  overlay <- base$source |>
    filter(scenario_id == "x10011") |>
    left_join(select(cells, all_of(NASH_KEYS), sbti_overlay_relief), by = NASH_KEYS,
      relationship = "one-to-one") |>
    mutate(topup_after_behaviour = pmax(0, topup_after_behaviour - coalesce_zero(sbti_overlay_relief))) |>
    build_source_panel()
  overlay_allocation <- nash_channels(overlay, weights)
  side_channels <- filter(base$allocation$channels, scenario_id == "x10011", channel != "QDMTT")
  after_side <- filter(overlay_allocation$channels, channel != "QDMTT")
  stopifnot(isTRUE(all.equal(arrange(side_channels, year, country, channel),
    arrange(after_side, year, country, channel), tolerance = 0)))
  baseline_qdmtt <- filter(base$allocation$channels, scenario_id == "x10011", channel == "QDMTT")
  overlay_qdmtt <- filter(overlay_allocation$channels, channel == "QDMTT")

  imap_dfr(NASH_STRATEGY_WINDOWS, function(years, window) {
    relief <- cells |>
      filter(year %in% years) |>
      summarise(
        adoption_qdmtt = sum(qdmtt), sector_payroll_cap = sum(payroll_cap),
        sector_carrying_value_cap = sum(carrying_value_cap), maximum_capacity_proxy = sum(capacity),
        overlay_topup_relief = sum(sbti_overlay_relief),
        overlay_topup_relief_us = sum(sbti_overlay_relief[parent == "USA"]),
        overlay_topup_relief_non_us = sum(sbti_overlay_relief[parent != "USA"]),
        existing_qti_election_topup_relief = sum(existing_qti_relief),
        existing_qti_election_topup_relief_us = sum(existing_qti_relief[parent == "USA"]),
        existing_qti_election_topup_relief_non_us = sum(existing_qti_relief[parent != "USA"]),
        new_qti_ordinary_cit_cost = sum(used_new_qti),
        new_qti_mne_tax_relief_us = sum(used_new_qti[parent == "USA"]),
        new_qti_mne_tax_relief_non_us = sum(used_new_qti[parent != "USA"]),
        .by = affiliate
      ) |>
      rename(country = affiliate)
    direct <- bind_rows(mutate(baseline_qdmtt, arm = "adoption"),
      mutate(overlay_qdmtt, arm = "overlay")) |>
      filter(year %in% years, country %in% EU27_ISO3) |>
      summarise(revenue = sum(revenue), .by = c(country, arm)) |>
      pivot_wider(names_from = arm, values_from = revenue, values_fill = 0)
    a <- filter(repeal, start_year == min(years), end_year == max(years)) |>
      select(country, repeal_foreign_soakup = foreign_soakup, repeal_topup_relief = mne_topup_saved,
        repeal_domestic_iir = domestic_iir_recapture, repeal_domestic_utpr = domestic_utpr_recapture,
        repeal_delta_domestic_collector = delta_domestic_collector, repeal_tax_cut_efficiency = tax_cut_efficiency,
        repeal_profit_retained = retained_profit, repeal_source_cit_retained = retained_source_cit,
        repeal_net_domestic_tax_foregone = net_domestic_tax_foregone, repeal_critical_weight = critical_welfare_weight)
    out <- tibble(country = EU27_ISO3) |>
      left_join(relief, by = "country", relationship = "one-to-one") |>
      mutate(across(-country, coalesce_zero)) |>
      left_join(direct, by = "country", relationship = "one-to-one") |>
      mutate(across(c(adoption, overlay), coalesce_zero),
        sbti_capacity_assumption = "sector max of 5.5% payroll or 1% carrying value, allocated to low-tax profit",
        new_qti_assumption = "ordinary credit in positive-QDMTT cells, usable up to imputed low-tax covered taxes",
        overlay_qdmtt_foregone = adoption - overlay,
        overlay_foreign_leakage = 0, overlay_efficiency = safe_divide(overlay_topup_relief, overlay_qdmtt_foregone),
        existing_qti_election_qdmtt_foregone = existing_qti_election_topup_relief,
        existing_qti_election_foreign_leakage = 0,
        existing_qti_election_efficiency = safe_divide(existing_qti_election_topup_relief, existing_qti_election_qdmtt_foregone),
        # A new, fully used ordinary credit up to the cap reduces ordinary
        # CIT and is added back in equal amount. The original QDMTT survives.
        new_qti_topup_relief_vs_no_incentive = 0,
        new_qti_mne_tax_relief = new_qti_ordinary_cit_cost,
        new_qti_foreign_leakage = 0,
        new_qti_efficiency = safe_divide(new_qti_mne_tax_relief, new_qti_ordinary_cit_cost),
        window, start_year = min(years), end_year = max(years),
        max_global_conservation_gap = overlay_allocation$max_gap) |>
      left_join(a, by = "country", relationship = "one-to-one")
    stopifnot(all(abs(out$overlay_topup_relief - out$overlay_qdmtt_foregone) < NASH_TOL),
      all(abs(out$adoption - out$adoption_qdmtt) < NASH_TOL), nrow(out) == 27L,
      all(abs(out$overlay_topup_relief_us + out$overlay_topup_relief_non_us - out$overlay_topup_relief) < NASH_TOL),
      all(abs(out$new_qti_mne_tax_relief_us + out$new_qti_mne_tax_relief_non_us - out$new_qti_mne_tax_relief) < NASH_TOL))
    out |>
      mutate(repeal_net_topup_foregone = -repeal_delta_domestic_collector) |>
      select(-adoption, sbti_overlay_remaining_qdmtt = overlay) |>
      relocate(country, window, start_year, end_year)
  })
}

run_qdmtt_game_diagnostics <- function() {
  panels <- nash_load_panels()
  weights <- list(parent_year_weights = nash_read("stage4_5_utpr_parent_year_weights"),
    fallback_weights = nash_read("stage4_5_utpr_fallback_weights"))
  activity <- build_collector_activity(panels$L3_pooled)
  collectors <- sort(unique(c(EU27_ISO3, activity$collector[activity$collector_utpr_flag],
    panels$L3_pooled$parent[panels$L3_pooled$parent_iir_utpr_flag], "USA", "GBR", "CHE", "JPN", "HKG")))
  r3 <- map(panels, function(panel) {
    source <- nash_r3_panel(panel)
    list(source = source, allocation = nash_channels(source, weights))
  })
  nash_verify_benchmarks(panels, weights, r3)
  message("1/3 Running the 27 unilateral deviations for both ETR ladders")
  pairs <- vector("list", length(EU27_ISO3) * length(NASH_LEVELS) * length(NASH_DEVIATIONS))
  spillovers <- vector("list", length(pairs))
  index <- 0L
  for (country in EU27_ISO3) {
    exit_weights <- build_parent_year_utpr_weights(filter(activity, collector != country))
    for (level in NASH_LEVELS) {
      base <- r3[[level]]
      for (deviation in NASH_DEVIATIONS) {
        index <- index + 1L
        result <- nash_build_deviation(base$source, country, deviation,
          if (deviation == "full_opt_out") exit_weights else weights)
        years_to_report <- if (deviation == "qdmtt_repeal") {
          c(NASH_WINDOWS, NASH_STRATEGY_WINDOWS["2021–2023"])
        } else NASH_WINDOWS
        pairs[[index]] <- imap_dfr(years_to_report, function(years, window) {
          map_dfr(c("Universal", "SbS"),
            ~ nash_summarise_deviation(base, result, country, years, .x, window))
        }) |>
          mutate(level, deviation, benchmark = "R3_full_eu27_qdmtt_iir",
            adoption_iir_active = TRUE, deviation_iir_active = deviation == "qdmtt_repeal",
            adoption_utpr_active = country %in% activity$collector[activity$collector_utpr_flag],
            deviation_utpr_active = adoption_utpr_active & deviation == "qdmtt_repeal")
        if (country %in% NASH_HUBS) {
          spillovers[[index]] <- imap_dfr(NASH_WINDOWS,
            ~ nash_network(base, result, country, .x, .y, collectors)) |>
            mutate(level, deviation, benchmark = "R3_full_eu27_qdmtt_iir")
        }
      }
    }
  }
  deviations <- bind_rows(pairs)
  matrix <- filter(deviations, window %in% names(NASH_WINDOWS)) |>
    relocate(country, level, deviation, regime, window) |>
    arrange(country, level, deviation, regime, window)
  assert_unique_keys(matrix, c("country", "level", "deviation", "regime", "window"), "Step 13 payoff")
  matrix <- mutate(matrix, global_savings_reconciliation_gap = global_topup_saved_all_sources - mne_topup_saved)
  message(sprintf("Largest cumulative global savings reconciliation gap: USD %.9g",
    max(abs(matrix$global_savings_reconciliation_gap))))
  stopifnot(nrow(matrix) == 27 * 2 * 2 * 2 * 2,
    all(abs(matrix$global_savings_reconciliation_gap) < 2 * NASH_TOL * (matrix$end_year - matrix$start_year + 1)),
    all(abs(matrix$delta_domestic_collector_from_other_sources[matrix$deviation == "qdmtt_repeal"]) < NASH_TOL))

  message("2/3 Comparing repeal with capped substance incentives")
  sectors <- nash_sector_shares()
  strategy <- imap_dfr(r3, function(base, level) {
    nash_summarise_strategy(base,
      filter(deviations, .data$level == .env$level, deviation == "qdmtt_repeal", regime == "SbS"),
      sectors, weights) |>
      mutate(level, regime = "SbS", scenario_id = "x10011", benchmark = "R3_full_eu27_qdmtt_iir")
  }) |>
    relocate(country, level, window, regime, scenario_id)
  assert_unique_keys(strategy, c("country", "level", "window"), "Step 13 SBTI")
  stopifnot(nrow(strategy) == 27 * 2 * 2)

  message("3/3 Reconciling source-to-collector spillovers")
  network <- bind_rows(spillovers) |>
    arrange(source_country, level, deviation, window, collector, channel)
  assert_unique_keys(network, c("source_country", "collector", "channel", "level", "deviation", "window"),
    "Step 13 bilateral spillovers")
  reconciliation <- network |>
    filter(collector_is_foreign) |>
    summarise(universal = sum(source_windfall_universal), sbs = sum(source_windfall_sbs),
      .by = c(source_country, level, deviation, window)) |>
    rename(country = source_country) |>
    pivot_longer(c(universal, sbs), names_to = "regime", values_to = "foreign_network") |>
    mutate(regime = recode(regime, universal = "Universal", sbs = "SbS")) |>
    inner_join(select(matrix, country, level, deviation, window, regime, foreign_soakup),
      by = c("country", "level", "deviation", "window", "regime"), relationship = "one-to-one")
  stopifnot(nrow(reconciliation) == length(NASH_HUBS) * 2 * 2 * 2 * 2,
    max(abs(reconciliation$foreign_soakup - reconciliation$foreign_network)) < NASH_TOL)
  write_csv(matrix, file.path(DIAGNOSTICS_DIR, "step13_unilateral_qdmtt_deviation_matrix.csv"))
  write_csv(strategy, file.path(DIAGNOSTICS_DIR, "step13_qdmtt_vs_sbti_strategy_comparison.csv"))
  write_csv(network, file.path(DIAGNOSTICS_DIR, "step13_bilateral_deviation_spillovers.csv"))
  message(sprintf("Step 13 wrote %d payoff, %d strategy and %d network rows.", nrow(matrix), nrow(strategy), nrow(network)))
}

# Joint variance and GloBE accounting factorial

STEP15_SEED <- 20261113L
STEP15_DRAWS <- 500L
STEP15_KEYS <- c("parent", "affiliate", "year")
delayedAssign("STEP15_WINDOWS", BRIDGE_WINDOWS[c("2017–2023", "2019–2023", "2021–2023")])
STEP15_SCOPES <- c(EU27_ISO3, "EU27")
STEP15_PREFERRED <- "x10011"

step15_host_rate <- function(tax, profit, cap) {
  rate <- pmin(cap, pmax(0, safe_divide(tax, profit)))
  list(share = coalesce_zero(as.numeric(rate < GMT_RATE)),
       gap = coalesce_zero(pmax(0, GMT_RATE - rate)))
}

# Build a linear routing operator once for each legal regime. Every dollar
# has one QDMTT/IIR collector, a normalized UTPR split, or SbS extinction.
step15_route <- function(rows, weights) {
  routed <- allocation_regime(rep(1, nrow(rows)), rows$qdmtt_flag,
                               rows$parent_iir_utpr_flag, rows$sbs_exempt)
  direct <- bind_rows(
    tibble(cell = which(routed == "qdmtt"), country = rows$affiliate[routed == "qdmtt"], share = 1),
    tibble(cell = which(routed == "iir"), country = rows$parent[routed == "iir"], share = 1)
  )
  utpr <- rows |> mutate(cell = row_number(), regime = routed) |>
    filter(regime == "utpr") |> select(cell, parent, year)
  w <- weights$parent_year_weights |> select(parent, year, collector, utpr_weight)
  f <- weights$fallback_weights |> select(year, collector, utpr_weight)
  covered <- distinct(w, parent, year)
  distributed <- bind_rows(
    semi_join(utpr, covered, by = c("parent", "year")) |>
      inner_join(w, by = c("parent", "year"), relationship = "many-to-many"),
    anti_join(utpr, covered, by = c("parent", "year")) |>
      inner_join(f, by = "year", relationship = "many-to-many")
  ) |> transmute(cell, country = collector, share = utpr_weight)
  all <- bind_rows(direct, distributed)
  totals <- numeric(nrow(rows))
  routing_totals <- rowsum(all$share, all$cell)
  totals[as.integer(rownames(routing_totals))] <- routing_totals[, 1L]
  stopifnot(all(is.finite(all$share)), all(all$share >= 0),
            max(abs(totals + (routed == "sbs_extinguished") - 1)) < 1e-12)
  collectors <- expand_grid(country = EU27_ISO3, year = MAIN_YEARS)
  eu <- all |> filter(country %in% EU27_ISO3) |> mutate(year = rows$year[cell]) |>
    left_join(mutate(collectors, collector_id = row_number()), by = c("country", "year"),
              relationship = "many-to-one")
  operator <- Matrix::sparseMatrix(i = eu$collector_id, j = eu$cell, x = eu$share,
                                  dims = c(nrow(collectors), nrow(rows)))
  list(operator = operator, foreign_collection_weight = totals - Matrix::colSums(operator),
       extinguished = routed == "sbs_extinguished", exposed = !(rows$sbs_exempt & !rows$qdmtt_flag))
}

step15_inputs <- function() {
  cells <- bridge_read("stage1_bilateral_panel") |> arrange(parent, affiliate, year)
  host <- bridge_read("stage1_affiliate_year") |> arrange(affiliate, year) |>
    mutate(host_id = row_number())
  cells <- left_join(cells, select(host, affiliate, year, host_id),
                     by = c("affiliate", "year"), relationship = "many-to-one")
  stopifnot(!anyNA(cells$host_id), all(tabulate(cells$host_id, nrow(host)) > 0))
  host_sum <- function(value) unname(rowsum(value, cells$host_id, reorder = TRUE)[, 1])
  average_support <- !is.na(cells$profit_panelai) & cells$profit_panelai > 0
  stopifnot(isTRUE(all.equal(host_sum(cells$analysis_profit_positive * average_support),
                             host$avg_profit_denominator, tolerance = 1e-12)))
  weights <- list(parent_year_weights = bridge_read("stage4_5_utpr_parent_year_weights"),
                  fallback_weights = bridge_read("stage4_5_utpr_fallback_weights"))
  source <- bridge_read("stage4_5_allocation_source_panel") |>
    filter(scenario_id %in% c("x00000", "x00010")) |>
    select(scenario_id, all_of(STEP15_KEYS), qdmtt_flag, parent_iir_utpr_flag, sbs_exempt)
  routes <- lapply(c("x00000", "x00010"), function(scenario) {
    flags <- filter(source, scenario_id == scenario) |> select(-scenario_id)
    rows <- left_join(select(cells, all_of(STEP15_KEYS)), flags,
                      by = STEP15_KEYS, relationship = "one-to-one")
    stopifnot(!anyNA(rows))
    step15_route(rows, weights)
  })
  predictions <- bridge_read("profit_correction_parent_year") |>
    filter(year %in% MAIN_YEARS) |> arrange(parent, year) |> mutate(rho_id = row_number())
  draw_cells <- cells |> mutate(cell = row_number()) |>
    filter(parent == affiliate, is.na(profit_adj_panelai), profit_panelai > 0,
           analysis_profit_positive > 0) |>
    left_join(select(predictions, parent, year, rho_id), by = c("parent", "year"),
              relationship = "many-to-one")
  stopifnot(!anyNA(draw_cells$rho_id),
    max(abs(draw_cells$analysis_profit_positive - draw_cells$profit_panelai *
          (1 - inverse_bounded_logit(predictions$posterior_y[draw_cells$rho_id])))) < 1e-3)
  coef <- bridge_read("stage3_model_coefficients") |>
    filter(model_spec == "linear", term == "tau", inference == "parent_affiliate_clustered")
  stopifnot(nrow(coef) == 1L, coef$std_error > 0)
  residuals <- read_csv(file.path(DIAGNOSTICS_DIR, "step3_stage1_crossval_affiliate_year.csv"),
                        show_col_types = FALSE) |>
    filter(is.finite(low_share_diff), is.finite(topup_rate_diff)) |>
    arrange(affiliate, year)
  # Resample the two residual coordinates jointly, centred for a variance
  # exercise as in Step 09. Validation CSV defines error as fit minus direct.
  residuals <- -as.matrix(residuals[c("low_share_diff", "topup_rate_diff")])
  residual_mean <- colMeans(residuals)
  residuals <- sweep(residuals, 2L, residual_mean)
  residual_hosts <- which(host$stage1_positive_profit_flag %in% TRUE &
    host$stage1_distributional_source %in% c("percentile_fit", "shape_transport", "avg_only"))
  sector <- bridge_read("stage2_sectoral_panel") |>
    inner_join(select(host, affiliate, year, host_id), by = c("affiliate", "year"),
               relationship = "many-to-one") |>
    filter(is.finite(sectoral_profit_share_used), sectoral_profit_share_used > 0,
           is.finite(sectoral_sbie), is.finite(sectoral_payroll), is.finite(sectoral_assets))
  sectors <- lapply(STAGE2_ENDPOINTS$rate_scenario, function(rate) {
    s <- filter(sector, rate_scenario == rate) |> arrange(host_id, nace_r2)
    ids <- unique(s$host_id)
    ref <- match(host$affiliate, host$affiliate[ids[host$year[ids] == SECTORAL_REFERENCE_YEAR]])
    reference_ids <- ids[host$year[ids] == SECTORAL_REFERENCE_YEAR]
    list(host = s$host_id, ids = ids, profit_share = s$sectoral_profit_share_used,
         profit_share_sum = as.numeric(rowsum(s$sectoral_profit_share_used, s$host_id)),
         sbie = s$sectoral_sbie, incentive = pmax(.055 * s$sectoral_payroll, .01 * s$sectoral_assets),
         reference = reference_ids[ref])
  })
  collector_year <- expand_grid(country = EU27_ISO3, year = MAIN_YEARS)
  windows <- lapply(STEP15_WINDOWS, function(years) {
    lapply(STEP15_SCOPES, function(c) which(collector_year$year %in% years &
                                            (collector_year$country == c | c == "EU27")))
  })
  list(cells = cells, host = host, host_sum = host_sum, routes = routes, predictions = predictions,
       draw_cells = draw_cells, beta = coef$estimate, beta_se = coef$std_error,
       residuals = residuals, residual_hosts = residual_hosts, average_support = average_support,
       sector = sectors, collector_year = collector_year, windows = windows,
       profit = cells$analysis_profit_positive, sbie = vapply(seq_len(nrow(STAGE2_ENDPOINTS)),
         function(i) compute_sbie_value(cells$payroll_sbie, cells$assets_sbie,
           STAGE2_ENDPOINTS$sigma_w[i], STAGE2_ENDPOINTS$sigma_a[i]), numeric(nrow(cells))))
}

step15_measure <- function(input, rho = NULL, error = NULL) {
  h <- input$host
  profit <- input$profit
  if (!is.null(rho)) {
    d <- input$draw_cells
    profit[d$cell] <- d$profit_panelai * (1 - rho[d$rho_id])
  }
  host_profit <- input$host_sum(profit * input$average_support)
  average <- step15_host_rate(h$avg_tax_numerator, host_profit, h$affiliate_etr_cap_stage1)
  share <- coalesce_zero(h$stage1_distributional_low_share)
  gap <- coalesce_zero(h$stage1_distributional_topup_rate)
  fallback <- which(h$stage1_distributional_source %in% "avg_only")
  share[fallback] <- average$share[fallback]
  gap[fallback] <- average$gap[fallback]
  if (!is.null(error)) {
    idx <- input$residual_hosts
    share[idx] <- clamp_unit_interval(share[idx] + input$residuals[error, 1L])
    gap[idx] <- clamp_interval(gap[idx] + input$residuals[error, 2L], 0, GMT_RATE)
  }
  list(profit = profit, average = average, distributional = list(share = share, gap = gap))
}

# Recompute the two sectoral scales against the drawn host profit and gap.
# The NACE allocation weights and sector payroll/assets are the production inputs.
step15_sector_scale <- function(input, endpoint, aggregate_tax, host_profit, share, gap) {
  s <- input$sector[[endpoint]]
  sector_profit <- host_profit[s$host] * s$profit_share
  available <- sector_profit > 0
  net_gap <- numeric(length(s$host))
  net_gap[available] <- pmax(0,
    gap[s$host[available]] * (1 - clamp_unit_interval(s$sbie[available] / sector_profit[available])) -
      s$incentive[available] / sector_profit[available])
  weighted_gap <- rowsum(net_gap * s$profit_share, s$host, reorder = FALSE)[, 1L] /
    s$profit_share_sum
  scale <- rep(NA_real_, nrow(input$host))
  scale[s$ids] <- safe_divide(share[s$ids] * weighted_gap * host_profit[s$ids], aggregate_tax[s$ids])
  scale[host_profit <= 0] <- NA_real_
  coalesce(scale, scale[s$reference], 1)
}

step15_design <- function(accounting = FALSE) {
  factors <- c(FACTOR_COLS, if (accounting) "x6_accounting")
  design <- expand_grid(!!!set_names(rep(list(0:1), length(factors)), factors))
  design$scenario_id <- paste0("x", apply(design[factors], 1L, paste0, collapse = ""))
  design
}

# Compute a complete 32-scenario waterfall for one parameter draw. The ETR,
# substance and transition switches change the source amount; legal allocation
# is linear conditional on each regime and its fixed UTPR weights.
step15_evaluate <- function(input, measure, beta = input$beta, check = FALSE) {
  id <- input$cells$host_id
  profit <- measure$profit
  host_profit <- input$host_sum(profit)
  amounts <- lapply(c("average", "distributional"), function(name) {
    m <- measure[[name]]
    bilateral <- isTRUE(m$bilateral)
    share <- if (bilateral) m$share else m$share[id]
    gap <- if (bilateral) m$gap else m$gap[id]
    if (bilateral) {
      low <- input$host_sum(profit * share)
      host_share <- coalesce_zero(safe_divide(low, host_profit))
      host_gap <- coalesce_zero(safe_divide(input$host_sum(profit * share * gap), low))
    } else {
      host_share <- m$share
      host_gap <- m$gap
    }
    tau <- ifelse(share > 0 & gap > 0, GMT_RATE - gap, NA_real_)
    behaviour <- apply_behavioural_regime(tau,
      coalesce_zero(1 - clamp_unit_interval(exp(beta * (GMT_RATE - tau)))))
    lapply(seq_len(ncol(input$sbie)), function(endpoint) {
      excess <- profit - pmin(pmax(input$sbie[, endpoint], 0), profit)
      topup <- excess * share * gap
      scale <- step15_sector_scale(input, endpoint, input$host_sum(topup),
                                   host_profit, host_share, host_gap)
      list(aggregate = topup, sectoral = topup * scale[id],
           bunch = behaviour$behavioural_regime == "sesh_bunching_topup_zero",
           beta_applied = pmin(behaviour$beta_applied, BEHAVIOURAL_MAX_REALLOCATION_SHARE))
    })
  })
  design <- step15_design()
  y <- matrix(0, nrow(input$collector_year), nrow(design), dimnames = list(NULL, design$scenario_id))
  max_gap <- 0
  for (law in 0:1) {
    cols <- which(design$x4_sbs == law)
    route <- input$routes[[law + 1L]]
    source <- vapply(cols, function(i) {
      d <- design[i, ]
      a <- amounts[[d$x1_etr + 1L]][[d$x3_rates + 1L]]
      amount <- if (d$x2_substance == 0L) a$aggregate else a$sectoral
      if (d$x5_behaviour == 0L) return(amount)
      amount * ifelse(a$bunch, 0, 1 - a$beta_applied * route$exposed)
    }, numeric(length(profit)))
    y[, cols] <- as.matrix(route$operator %*% source)
    if (check) {
      outside <- route$foreign_collection_weight + route$extinguished
      for (year in MAIN_YEARS) {
        cells <- input$cells$year == year
        collectors <- input$collector_year$year == year
        collected <- colSums(y[collectors, cols, drop = FALSE])
        accounted_outside_eu <- apply(source[cells, , drop = FALSE] * outside[cells], 2L, sum)
        liability <- apply(source[cells, , drop = FALSE], 2L, sum)
        gaps <- abs(collected + accounted_outside_eu - liability)
        # Allow roundoff from sparse summation at trillion-dollar scale.
        stopifnot(all(gaps <= 1e-3 + 64 * .Machine$double.eps * liability))
        max_gap <- max(max_gap, gaps)
      }
    }
  }
  list(revenue = y / 1e9, max_global_conservation_gap = max_gap)
}

step15_cumulative <- function(revenue, input, windows = seq_along(input$windows)) {
  vapply(unlist(input$windows[windows], recursive = FALSE), function(i) {
    colSums(revenue[i, , drop = FALSE])
  }, numeric(ncol(revenue)))
}

step15_check_production <- function(input, y) {
  production <- bridge_read("stage4_5_revenue_country_year") |>
    select(country, year, scenario_id, revenue) |>
    pivot_wider(names_from = scenario_id, values_from = revenue)
  production <- left_join(input$collector_year, production, by = c("country", "year"),
                          relationship = "one-to-one")
  difference_usd <- max(abs(y * 1e9 - as.matrix(production[colnames(y)])))
  stopifnot(difference_usd < 1e-3)
  difference_usd
}

step15_population_variance <- function(x) mean((x - mean(x))^2)

step15_monte_carlo <- function(input, point) {
  set.seed(STEP15_SEED)
  sample_inputs <- function() {
    list(
      error = matrix(sample.int(nrow(input$residuals), length(input$residual_hosts) *
        STEP15_DRAWS, replace = TRUE), nrow = length(input$residual_hosts)),
      beta = rnorm(STEP15_DRAWS, input$beta, input$beta_se),
      rho = matrix(inverse_bounded_logit(rnorm(nrow(input$predictions) * STEP15_DRAWS,
        input$predictions$posterior_y, input$predictions$posterior_sd)), nrow = nrow(input$predictions))
    )
  }
  independent <- list(sample_inputs(), sample_inputs())
  masks <- as.matrix(expand_grid(etr = 0:1, beta = 0:1, rho = 0:1))
  starts <- 1:2
  window_names <- names(STEP15_WINDOWS)[starts]
  point_totals <- step15_cumulative(point, input, starts)
  n_scenarios <- nrow(point_totals)
  n_outcomes <- ncol(point_totals)
  # Two independent input samples support pick-freeze estimates. Each hybrid
  # shares the inputs indicated by its mask with the 111 run.
  hybrid <- array(0, c(STEP15_DRAWS, n_scenarios, n_outcomes, nrow(masks)))
  fixed <- array(0, c(STEP15_DRAWS, n_scenarios, n_outcomes, 3L))
  largest_gap <- 0
  evaluate <- function(error, beta, rho) {
    result <- step15_evaluate(input, step15_measure(input, rho, error), beta, check = TRUE)
    largest_gap <<- max(largest_gap, result$max_global_conservation_gap)
    step15_cumulative(result$revenue, input, starts)
  }
  for (m in seq_len(STEP15_DRAWS)) {
    for (k in seq_len(nrow(masks))) {
      draws <- independent[2L - masks[k, ]]
      hybrid[m, , , k] <- evaluate(draws[[1]]$error[, m], draws[[2]]$beta[m],
                                     draws[[3]]$rho[, m])
    }
    a <- independent[[1L]]
    fixed[m, , , 1L] <- evaluate(a$error[, m], input$beta, NULL)
    fixed[m, , , 2L] <- evaluate(NULL, a$beta[m], NULL)
    fixed[m, , , 3L] <- evaluate(NULL, input$beta, a$rho[, m])
    if (m %% 100L == 0L) message("  Completed ", m, " of ", STEP15_DRAWS, " joint draws")
  }
  bit_names <- c("etr", "beta", "rho")
  subsets <- lapply(seq_len(nrow(masks)), function(k) which(masks[k, ] == 1))
  components <- vapply(subsets, function(s) paste(bit_names[s], collapse = "_"), character(1))
  # Each draw evaluates the full 2×2×2 cube of two independent levels per
  # input. For a subset S, difference along every axis in S, then multiply
  # the differences at complementary corners of the remaining axes. Those
  # corners integrate out the remaining inputs independently. The expected
  # product divided by 2^|S| is the pure functional ANOVA variance of S.
  contrasts <- lapply(subsets[-1], function(s) {
    other <- setdiff(seq_len(ncol(masks)), s)
    if (!length(other)) return(list(list(a = seq_len(nrow(masks)), b = seq_len(nrow(masks)),
      signs = (-1)^rowSums(masks[, s, drop = FALSE]), divisor = 2^length(s))))
    settings <- unique(masks[, other, drop = FALSE])
    lapply(seq_len(nrow(settings) / 2L), function(j) {
      selected <- settings[j, ]
      a <- which(rowSums(abs(sweep(masks[, other, drop = FALSE], 2L, selected))) == 0)
      b <- which(rowSums(abs(sweep(masks[, other, drop = FALSE], 2L, 1 - selected))) == 0)
      list(a = a, b = b, signs = (-1)^rowSums(masks[a, s, drop = FALSE]),
           divisor = 2^length(s))
    })
  })
  describe <- function(i) {
    y <- hybrid[, , i, 8L]
    scenario_means <- colMeans(y)
    scenario_vars <- apply(y, 2L, step15_population_variance)
    epistemic <- step15_population_variance(scenario_means)
    parameter <- mean(scenario_vars)
    total <- epistemic + parameter
    stopifnot(abs(total - step15_population_variance(y)) < 1e-9 * max(1, total))
    oaat <- colMeans(apply(fixed[, , i, ], c(2, 3), step15_population_variance))
    corner_y <- matrix(hybrid[, , i, ], ncol = nrow(masks))
    raw_components <- vapply(contrasts, function(pairs) mean(vapply(pairs, function(p) {
      a <- corner_y[, p$a, drop = FALSE] %*% p$signs
      b <- corner_y[, p$b, drop = FALSE] %*% p$signs
      mean(a * b) / p$divisor
    }, numeric(1))), numeric(1))
    # Use the cube to estimate the shares and the primary joint sample to
    # estimate the total variance. Retain the unscaled estimates for audit.
    sobol <- c(0, if (parameter == 0) rep(0, 7L) else {
      stopifnot(sum(raw_components) > 0)
      raw_components * parameter / sum(raw_components)
    })
    shapley <- vapply(seq_along(bit_names), function(f) sum(vapply(2:8, function(k) {
      if (f %in% subsets[[k]]) sobol[k] / length(subsets[[k]]) else 0
    }, numeric(1))), numeric(1))
    stopifnot(abs(sum(shapley) - parameter) < 1e-10 * max(1, parameter))
    country <- STEP15_SCOPES[(i - 1L) %% length(STEP15_SCOPES) + 1L]
    window <- window_names[(i - 1L) %/% length(STEP15_SCOPES) + 1L]
    years <- STEP15_WINDOWS[[window]]
    bounds <- apply(y, 2L, quantile, probs = c(.05, .95), names = FALSE)
    preferred <- match(STEP15_PREFERRED, rownames(point_totals))
    width <- diff(bounds[, preferred])
    spread <- diff(range(point_totals[, i]))
    measures <- tibble(
      scope = country, window = window, seed = STEP15_SEED, n_joint_draws = STEP15_DRAWS,
      n_scenarios = n_scenarios, validation_cells = nrow(input$residuals),
      perturbed_host_years = sum(input$host$year[input$residual_hosts] %in% years),
      posterior_bilateral_cells = sum(input$draw_cells$year %in% years),
      beta_estimate = input$beta, beta_clustered_se = input$beta_se,
      max_global_conservation_gap_usd = largest_gap
    )
    bind_rows(
      mutate(measures, record = "total_variance",
        total_variance_usd_bn_sq = total, scenario_variance_usd_bn_sq = epistemic,
        parameter_variance_usd_bn_sq = parameter,
        scenario_variance_share = safe_divide(epistemic, total),
        parameter_variance_share = safe_divide(parameter, total),
        point_scenario_spread_usd_bn = spread,
        mean_scenario_spread_usd_bn = diff(range(scenario_means)),
        preferred_scenario = STEP15_PREFERRED, preferred_point_usd_bn = point_totals[preferred, i],
        preferred_p05_usd_bn = bounds[1, preferred], preferred_p95_usd_bn = bounds[2, preferred],
        preferred_width90_usd_bn = width, proposal_ratio = safe_divide(spread, width)),
      bind_cols(measures, tibble(record = "one_at_a_time", component = bit_names,
        component_variance_usd_bn_sq = oaat,
        component_share_of_total_variance = safe_divide(oaat, total),
        component_share_of_parameter_variance = safe_divide(oaat, parameter))),
      bind_cols(measures, tibble(record = "orthogonal_parameter", component = components[-1],
        unscaled_component_variance_usd_bn_sq = raw_components,
        component_variance_usd_bn_sq = sobol[-1],
        component_share_of_total_variance = safe_divide(sobol[-1], total),
        component_share_of_parameter_variance = safe_divide(sobol[-1], parameter))),
      bind_cols(measures, tibble(record = "parameter_shapley", component = bit_names,
        component_variance_usd_bn_sq = shapley,
        component_share_of_total_variance = safe_divide(shapley, total),
        component_share_of_parameter_variance = safe_divide(shapley, parameter))),
      bind_cols(measures, tibble(record = "scenario_distribution", scenario_id = rownames(point_totals),
        point_revenue_usd_bn = point_totals[, i], mean_revenue_usd_bn = scenario_means,
        parameter_variance_usd_bn_sq = scenario_vars,
        parameter_p05_usd_bn = bounds[1, ], parameter_p95_usd_bn = bounds[2, ]))
    )
  }
  map_dfr(seq_len(n_outcomes), describe)
}

step15_globe_base <- function(input) {
  cells <- input$cells
  base <- bridge_read("base_panel")
  raw <- bridge_read("cbcr_table1")
  t4 <- bridge_read("cbcr_table4")
  # Match Step 12 through the last accrued-tax step. Panel A is net of
  # negative subgroup profit, which Panel A-II alone reports separately.
  pooled <- step8_reconcile_rates(cells, base, input$host, step8_table4_partitions(t4),
                                  gamma = 1, method = "reporter_pool")$cells
  loss <- bridge_table1_loss(base, raw) |>
    left_join(select(pooled, all_of(STEP15_KEYS), revised_profit), by = STEP15_KEYS,
              relationship = "one-to-one") |>
    mutate(current = coalesce(revised_profit, corrected_profit) * (1 - coalesce_zero(loss_ratio))) |>
    group_by(parent, affiliate) |>
    mutate(bridge_loss_stock(net_profit, current)) |>
    ungroup() |>
    mutate(accounting_profit = current - cf_used)
  accounting <- cells |>
    select(all_of(STEP15_KEYS), profit_correction_rate_preferred, affiliate_is_conduit_haven,
      profit_adj_panelai, holding_share_panelai, ladder_l4_strict_source,
      ladder_l4_strict_low_share, ladder_l4_strict_topup_rate) |>
    left_join(select(loss, all_of(STEP15_KEYS), accounting_profit), by = STEP15_KEYS,
              relationship = "one-to-one") |>
    left_join(select(pooled, all_of(STEP15_KEYS), revised_share, revised_gap), by = STEP15_KEYS,
              relationship = "one-to-one")
  # The strict ladder uses its own exact Table IV partitions for the purge.
  # Keep the common Step 12 accounting denominator across the ETR switches.
  bilateral_t4 <- summarise_observed_t4(bridge_read("base_panel_t4_bilateral_bracket_shares"),
                                        STEP15_KEYS) |>
    filter(t4_available) |>
    select(all_of(STEP15_KEYS), t4_positive_profit, t4_low_profit, t4_low_tax)
  accounting <- accounting |>
    left_join(bilateral_t4, by = STEP15_KEYS, relationship = "one-to-one") |>
    mutate(
      exact = ladder_l4_strict_source == "exact_table_iv",
      domestic_rate = if_else(parent == affiliate, coalesce_zero(
        clamp_unit_interval(profit_correction_rate_preferred)), 0),
      foreign_rate = if_else(parent != affiliate & is.na(profit_adj_panelai) &
        (affiliate_is_conduit_haven | affiliate %in% c("CYP", "MLT")),
        coalesce_zero(clamp_unit_interval(holding_share_panelai)), 0)
    )
  exact <- which(accounting$exact)
  stopifnot(all(is.finite(accounting$t4_positive_profit[exact])),
            all(is.finite(accounting$accounting_profit)), all(accounting$accounting_profit >= 0))
  partition <- step8_remove_low_profit(accounting$t4_positive_profit[exact],
    accounting$t4_low_profit[exact], coalesce_zero(accounting$t4_low_tax[exact]),
    (accounting$domestic_rate[exact] + accounting$foreign_rate[exact]) *
      accounting$t4_positive_profit[exact])
  strict_share <- coalesce_zero(accounting$ladder_l4_strict_low_share)
  strict_gap <- coalesce_zero(accounting$ladder_l4_strict_topup_rate)
  strict_share[exact] <- partition$share
  strict_gap[exact] <- partition$gap

  host_profit <- input$host_sum(accounting$accounting_profit)
  # L1 uses the same accrued tax numerator as production, with the new
  # accounting denominator. L3 follows the Step 12 host-weighted low gap.
  average <- step15_host_rate(input$host$avg_tax_numerator,
                             input$host_sum(accounting$accounting_profit * input$average_support),
                             input$host$affiliate_etr_cap_stage1)
  low <- input$host_sum(accounting$accounting_profit * coalesce_zero(accounting$revised_share))
  topup <- input$host_sum(accounting$accounting_profit * coalesce_zero(accounting$revised_share) *
                           coalesce_zero(accounting$revised_gap))
  list(
    profit = accounting$accounting_profit, average = average,
    L3 = list(share = coalesce_zero(safe_divide(low, host_profit)),
              gap = coalesce_zero(safe_divide(topup, low))),
    L4_strict = list(share = strict_share, gap = strict_gap, bilateral = TRUE)
  )
}

step15_factorial_effects <- function(y, design, factors, scope, window, estimand) {
  # Orthogonal ±1 contrasts. Squaring before pooling gives the thesis
  # country-year SS estimand. Summing revenue first gives variance of the
  # cumulative collector outcome used in Task 1.
  coded <- mutate(design, across(all_of(factors), ~ 2 * .x - 1))
  x <- model.matrix(reformulate(paste(factors, collapse = "*")), data = coded)
  n <- nrow(design)
  stopifnot(nrow(y) == n, all(crossprod(x) == n * diag(n)))
  coef <- crossprod(x, y) / n
  effects <- strsplit(rownames(coef)[-1], ":", fixed = TRUE)
  order <- lengths(effects)
  ss <- n * rowSums(coef[-1, , drop = FALSE]^2)
  total_ss <- sum(sweep(y, 2L, colMeans(y))^2)
  stopifnot(abs(sum(ss) - total_ss) < 1e-10 * max(1, total_ss))
  eta <- if (total_ss > 0) ss / total_ss else rep(NA_real_, length(ss))
  shapley <- vapply(factors, function(factor) {
    keep <- vapply(effects, function(e) factor %in% e, logical(1))
    sum(eta[keep] / order[keep])
  }, numeric(1))
  if (total_ss > 0) stopifnot(abs(sum(shapley) - 1) < 1e-12)
  revenue <- rowSums(y)
  preferred <- which(design$scenario_id == paste0(STEP15_PREFERRED, "0"))
  adjusted <- which(design$scenario_id == paste0(STEP15_PREFERRED, "1"))
  stats <- tibble(scope, window, estimand, scenarios = n,
    factorial_variance_usd_bn_sq = total_ss / n,
    min_revenue_usd_bn = min(revenue), max_revenue_usd_bn = max(revenue),
    interaction_eta_squared = sum(eta[order > 1L]),
    preferred_baseline_usd_bn = revenue[preferred], preferred_globe_usd_bn = revenue[adjusted],
    preferred_globe_change_usd_bn = revenue[adjusted] - revenue[preferred])
  bind_rows(
    bind_cols(stats, tibble(record = "main_effect", effect = factors,
      main_eta_squared = eta[match(factors, rownames(coef)[-1])],
      shapley_eta_squared = unname(shapley),
      dollar_main_effect_usd_bn = 2 * rowSums(coef[factors, , drop = FALSE]))),
    bind_cols(stats, tibble(record = "interaction", effect = rownames(coef)[-1][order > 1L],
      interaction_term_eta_squared = eta[order > 1L]))
  )
}

step15_factorial <- function(input, baseline, point) {
  globe <- step15_globe_base(input)
  ladders <- c("L3", "L4_strict")
  design <- step15_design(TRUE)
  by_ladder <- lapply(ladders, function(level) {
    untreated <- if (level == "L3") point else {
      m <- baseline
      m$distributional <- list(share = coalesce_zero(input$cells$ladder_l4_strict_low_share),
        gap = coalesce_zero(input$cells$ladder_l4_strict_topup_rate), bilateral = TRUE)
      step15_evaluate(input, m, check = TRUE)$revenue
    }
    m <- list(profit = globe$profit, average = globe$average, distributional = globe[[level]])
    treated <- step15_evaluate(input, m, check = TRUE)$revenue
    y <- untreated[, rep(seq_len(ncol(untreated)), each = 2L)]
    y[, design$x6_accounting == 1L] <- treated
    colnames(y) <- design$scenario_id
    y
  })
  reference <- read_csv(file.path(DIAGNOSTICS_DIR, "step12_cbcr_to_budget_waterfall_bridge.csv"),
                        show_col_types = FALSE) |>
    filter(record_type == "waterfall", step == "03_prior_loss_carryforward",
           scope %in% STEP15_SCOPES, window %in% names(STEP15_WINDOWS)) |>
    arrange(match(window, names(STEP15_WINDOWS)), match(scope, STEP15_SCOPES))
  expected <- step15_cumulative(by_ladder[[1L]], input)[paste0(STEP15_PREFERRED, "1"), ]
  stopifnot(nrow(reference) == length(expected),
            max(abs(reference$collector - expected * 1e9)) < 1e-3)
  map_dfr(seq_along(ladders), function(i) {
    imap_dfr(list(full_64 = seq_len(nrow(design)), initial_rates_32 = which(design$x3_rates == 0)),
      function(scenarios, name) {
        d <- design[scenarios, ]
        factors <- setdiff(setdiff(names(d), "scenario_id"),
                           if (name == "initial_rates_32") "x3_rates")
        y <- t(by_ladder[[i]][, scenarios, drop = FALSE])
        map_dfr(seq_along(STEP15_WINDOWS), function(w) {
          window <- names(STEP15_WINDOWS)[w]
          map_dfr(seq_along(STEP15_SCOPES), function(c) {
            scope <- STEP15_SCOPES[c]
            panel <- y[, input$windows[[w]][[c]], drop = FALSE]
            cumulative <- matrix(rowSums(panel), ncol = 1L)
            bind_rows(
              step15_factorial_effects(panel, d, factors, scope, window, "pooled_country_year"),
              step15_factorial_effects(cumulative, d, factors, scope, window, "cumulative_collector"),
              tibble(record = "scenario_revenue", scope, window, estimand = "cumulative_collector",
                scenarios = nrow(d), scenario_id = d$scenario_id,
                cumulative_revenue_usd_bn = cumulative[, 1L])
            )
          })
        }) |> mutate(distributional_level = ladders[i], design = name)
      })
  })
}

run_total_variance_and_accounting_factorial <- function() {
  input <- step15_inputs()
  point_measure <- step15_measure(input)
  point <- step15_evaluate(input, point_measure, check = TRUE)$revenue
  gap <- step15_check_production(input, point)
  message("1/2 Joint Monte Carlo. Maximum production reproduction gap in USD: ", format(gap))
  variance <- step15_monte_carlo(input, point)
  message("2/2 Expanded accounting factorial")
  factorial <- step15_factorial(input, point_measure, point)
  dir.create(DIAGNOSTICS_DIR, recursive = TRUE, showWarnings = FALSE)
  write_csv(variance, file.path(DIAGNOSTICS_DIR, "step15_law_of_total_variance_decomposition.csv"))
  write_csv(factorial, file.path(DIAGNOSTICS_DIR, "step15_globe_accounting_factorial_anova.csv"))
  message("Wrote ", nrow(variance), " variance rows and ", nrow(factorial), " factorial rows")
}

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

# Leave-one-jurisdiction influence

stage3_estimate_models <- estimate_stage3_models
stage3_semielasticity_schedule_fn <- stage3_semielasticity_schedule
stage3_build_model_diagnostics <- build_model_diagnostics

stage45_build_source_panel <- build_source_panel
stage45_build_collector_activity <- build_collector_activity
stage45_build_parent_year_utpr_weights <- build_parent_year_utpr_weights
stage45_allocate_stage4_revenue <- allocate_stage4_revenue
stage45_build_conservation_diagnostics <- build_conservation_diagnostics

stage46_build_scenario_summary <- build_scenario_summary
stage46_compute_factorial_anova <- compute_factorial_anova
stage46_compute_main_effects <- compute_main_effects


DEFAULT_TOP_N <- 8L
NAMED_INFLUENCE_JURISDICTIONS <- c(
  "USA", "NLD", "IRL", "LUX", "DEU", "FRA", "CHE", "SGP"
)
AGGREGATE_CODES <- c(
  "W", "WXD", "STLS", "A", "A_O", "E", "E_O", "F", "F_O", "S", "S_O",
  "OECD", "EU27_2020", "EA19"
)
delayedAssign("PREFERRED_CORE_FILTER", rlang::expr(
  factor1_etr == "distributional" &
    factor2_substance == "aggregate_sbie" &
    rate_scenario == "initial"
))

is_jurisdiction_code <- function(x) {
  str_detect(x, "^[A-Z]{3}$") & !x %in% AGGREGATE_CODES
}

case_id <- function(leave_dimension, jurisdiction) {
  paste(leave_dimension, jurisdiction, sep = "_")
}

first_available <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) {
    return(NA_character_)
  }
  as.character(x[1])
}

build_jurisdiction_lookup <- function(stage1_bilateral, stage3_panel) {
  bind_rows(
    stage1_bilateral |>
      transmute(
        jurisdiction = parent,
        jurisdiction_name = parent_jurisdiction_name
      ),
    stage1_bilateral |>
      transmute(
        jurisdiction = affiliate,
        jurisdiction_name = affiliate_jurisdiction_name
      ),
    stage3_panel |>
      transmute(
        jurisdiction = parent,
        jurisdiction_name = parent_jurisdiction_name
      ),
    stage3_panel |>
      transmute(
        jurisdiction = affiliate,
        jurisdiction_name = affiliate_jurisdiction_name
      )
  ) |>
    filter(is_jurisdiction_code(jurisdiction)) |>
    group_by(jurisdiction) |>
    summarise(
      jurisdiction_name = first_available(jurisdiction_name),
      .groups = "drop"
    )
}

build_country_lookup <- function(stage3_panel) {
  stage3_panel |>
    transmute(
      country = affiliate,
      country_name = affiliate_jurisdiction_name
    ) |>
    filter(country %in% EU27_ISO3) |>
    group_by(country) |>
    summarise(country_name = first_available(country_name), .groups = "drop")
}

summarise_stage1_liability <- function(stage1_bilateral, case_id_value) {
  bind_rows(
    stage1_bilateral |>
      filter(year %in% MAIN_YEARS, stage1_positive_profit_flag) |>
      mutate(scope = "global"),
    stage1_bilateral |>
      filter(
        year %in% MAIN_YEARS, stage1_positive_profit_flag,
        affiliate_is_eu27
      ) |>
      mutate(scope = "eu27")
  ) |>
    group_by(scope) |>
    summarise(
      positive_profit = sum(analysis_profit_positive, na.rm = TRUE),
      average_topup_tax = sum(stage1_topup_tax_average, na.rm = TRUE),
      distributional_topup_tax =
        sum(stage1_topup_tax_distributional, na.rm = TRUE),
      average_liability_rate =
        safe_divide(average_topup_tax, positive_profit),
      distributional_liability_rate =
        safe_divide(distributional_topup_tax, positive_profit),
      pair_years = n(),
      parents = n_distinct(parent),
      affiliates = n_distinct(affiliate),
      .groups = "drop"
    ) |>
    mutate(case_id = case_id_value, .before = 1)
}

summarise_case_dropped_mass <- function(stage1_bilateral, estimation_sample,
                                        leave_dimension, jurisdiction) {
  dropped_stage1 <- stage1_bilateral |>
    filter(
      .data[[leave_dimension]] == jurisdiction,
      year %in% MAIN_YEARS,
      stage1_positive_profit_flag
    ) |>
    summarise(
      dropped_stage1_pair_years = n(),
      dropped_stage1_profit =
        sum(analysis_profit_positive, na.rm = TRUE),
      dropped_stage1_topup =
        sum(stage1_topup_tax_distributional, na.rm = TRUE),
      .groups = "drop"
    )

  total_stage1 <- stage1_bilateral |>
    filter(year %in% MAIN_YEARS, stage1_positive_profit_flag) |>
    summarise(
      total_stage1_profit = sum(analysis_profit_positive, na.rm = TRUE),
      total_stage1_topup =
        sum(stage1_topup_tax_distributional, na.rm = TRUE),
      .groups = "drop"
    )

  dropped_stage3_rows <- estimation_sample |>
    filter(.data[[leave_dimension]] == jurisdiction) |>
    summarise(
      dropped_estimation_rows = n(),
      dropped_estimation_pairs = n_distinct(pair_id),
      .groups = "drop"
    )

  bind_cols(dropped_stage1, total_stage1, dropped_stage3_rows) |>
    mutate(
      dropped_stage1_profit_share =
        safe_divide(dropped_stage1_profit, total_stage1_profit),
      dropped_stage1_topup_share =
        safe_divide(dropped_stage1_topup, total_stage1_topup)
    )
}

build_influence_targets <- function(stage1_bilateral, estimation_sample,
                                    jurisdiction_lookup,
                                    top_n = DEFAULT_TOP_N) {
  stage1_scope <- stage1_bilateral |>
    filter(year %in% MAIN_YEARS, stage1_positive_profit_flag)

  top_parent <- stage1_scope |>
    filter(is_jurisdiction_code(parent)) |>
    group_by(jurisdiction = parent) |>
    summarise(
      leverage_profit = sum(analysis_profit_positive, na.rm = TRUE),
      leverage_topup = sum(stage1_topup_tax_distributional, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(desc(leverage_profit)) |>
    slice_head(n = top_n) |>
    mutate(leave_dimension = "parent", target_reason = "high_leverage")

  top_affiliate <- stage1_scope |>
    filter(is_jurisdiction_code(affiliate)) |>
    group_by(jurisdiction = affiliate) |>
    summarise(
      leverage_profit = sum(analysis_profit_positive, na.rm = TRUE),
      leverage_topup = sum(stage1_topup_tax_distributional, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(desc(leverage_profit)) |>
    slice_head(n = top_n) |>
    mutate(leave_dimension = "affiliate", target_reason = "high_leverage")

  available_targets <- bind_rows(
    estimation_sample |>
      distinct(leave_dimension = "parent", jurisdiction = parent),
    estimation_sample |>
      distinct(leave_dimension = "affiliate", jurisdiction = affiliate)
  ) |>
    filter(is_jurisdiction_code(jurisdiction))

  named_targets <- tidyr::expand_grid(
    leave_dimension = c("parent", "affiliate"),
    jurisdiction = NAMED_INFLUENCE_JURISDICTIONS
  ) |>
    semi_join(available_targets, by = c("leave_dimension", "jurisdiction")) |>
    mutate(
      leverage_profit = NA_real_,
      leverage_topup = NA_real_,
      target_reason = "named"
    )

  bind_rows(top_parent, top_affiliate, named_targets) |>
    group_by(leave_dimension, jurisdiction) |>
    summarise(
      target_reason = paste(sort(unique(target_reason)), collapse = "+"),
      leverage_profit = max_or_na(leverage_profit),
      leverage_topup = max_or_na(leverage_topup),
      .groups = "drop"
    ) |>
    mutate(
      included_high_leverage = str_detect(target_reason, "high_leverage"),
      included_named_target = str_detect(target_reason, "named"),
      target_inclusion_reason = case_when(
        included_high_leverage & included_named_target ~ "both",
        included_high_leverage ~ "high_leverage",
        included_named_target ~ "named_target",
        TRUE ~ "unspecified"
      ),
      case_id = case_id(leave_dimension, jurisdiction)
    ) |>
    left_join(jurisdiction_lookup, by = "jurisdiction") |>
    arrange(
      leave_dimension, desc(str_detect(target_reason, "named")),
      desc(leverage_profit), jurisdiction
    )
}

filter_leave_one <- function(df, leave_dimension, jurisdiction) {
  df |>
    filter(.data[[leave_dimension]] != jurisdiction)
}

fit_leave_one_semielasticity <- function(estimation_sample, leave_dimension,
                                         jurisdiction, case_id_value) {
  sample_case <- filter_leave_one(estimation_sample, leave_dimension, jurisdiction)
  model_fits <- stage3_estimate_models(sample_case)

  list(
    model_comparison = stage3_build_model_diagnostics(model_fits, case_id_value),
    semielasticity = stage3_semielasticity_schedule_fn(
      model_fits,
      tau_grid = c(0.05, 0.10)
    ) |>
      mutate(case_id = case_id_value, .before = 1)
  )
}

repair_country_names <- function(revenue_country_year, country_lookup) {
  revenue_country_year |>
    select(-any_of("country_name")) |>
    left_join(country_lookup, by = "country") |>
    relocate(country_name, .after = country)
}

check_factorial_revenue <- function(revenue_country_year, label) {
  scenario_count <- n_distinct(revenue_country_year$scenario_id)
  if (scenario_count != 32) {
    stop(label, " does not contain 32 scenarios")
  }

  scenario_cells <- revenue_country_year |>
    count(country, year, name = "scenarios")

  if (any(scenario_cells$scenarios != 32)) {
    stop(label, " has incomplete country-year scenario cells")
  }

  if (any(revenue_country_year$revenue < -1e-8, na.rm = TRUE)) {
    stop(label, " contains negative revenue")
  }

  invisible(TRUE)
}

build_leave_one_revenue <- function(stage3_panel, leave_dimension, jurisdiction,
                                    country_lookup, case_id_value) {
  stage3_case <- filter_leave_one(stage3_panel, leave_dimension, jurisdiction)
  source_panel <- stage45_build_source_panel(stage3_case)
  collector_activity <- stage45_build_collector_activity(stage3_case)
  utpr_weights <- stage45_build_parent_year_utpr_weights(collector_activity)
  allocation <- stage45_allocate_stage4_revenue(source_panel, utpr_weights)
  conservation <- stage45_build_conservation_diagnostics(
    source_panel,
    allocation$revenue_by_channel_global
  )

  revenue_country_year <- repair_country_names(
    allocation$revenue_country_year_eu27,
    country_lookup
  )
  check_factorial_revenue(revenue_country_year, case_id_value)

  list(
    revenue_country_year = revenue_country_year,
    revenue_by_channel = allocation$revenue_by_channel_eu27,
    conservation = conservation
  )
}

summarise_revenue_decomposition <- function(revenue_country_year,
                                            case_id_value) {
  scenario_summary <- stage46_build_scenario_summary(revenue_country_year)
  anova_objects <- stage46_compute_factorial_anova(revenue_country_year)
  main_effects <- stage46_compute_main_effects(
    scenario_summary |> rename(revenue = eu_revenue),
    revenue_col = "revenue"
  )

  preferred <- scenario_summary |>
    filter(!!PREFERRED_CORE_FILTER) |>
    group_by(factor4_sbs, factor5_behaviour) |>
    summarise(eu_revenue = sum(eu_revenue, na.rm = TRUE), .groups = "drop") |>
    mutate(metric = paste("preferred", factor4_sbs, factor5_behaviour,
      "revenue",
      sep = "_"
    )) |>
    select(metric, value = eu_revenue)

  selected_main_effects <- main_effects |>
    filter(effect %in% c("x1_etr", "x4_sbs", "x5_behaviour")) |>
    transmute(
      metric = paste0(effect, "_main_effect"),
      value = high_minus_low
    )

  selected_anova <- anova_objects$pooled |>
    filter(effect %in% c("x1_etr", "x4_sbs", "x5_behaviour")) |>
    transmute(
      metric = paste0(effect, "_eta_squared"),
      value = eta_squared
    )

  largest_effect <- anova_objects$pooled |>
    arrange(desc(eta_squared)) |>
    slice(1) |>
    transmute(
      metric = "largest_anova_effect",
      value = NA_real_,
      value_label = effect
    )

  spread <- scenario_summary |>
    summarise(
      metric = "eu_revenue_scenario_spread",
      value = max(eu_revenue, na.rm = TRUE) - min(eu_revenue, na.rm = TRUE),
      value_label = NA_character_
    )

  list(
    scenario_summary = scenario_summary |> mutate(
      case_id = case_id_value,
      .before = 1
    ),
    anova_pooled = anova_objects$pooled |> mutate(
      case_id = case_id_value,
      .before = 1
    ),
    main_effects = main_effects |> mutate(
      case_id = case_id_value,
      .before = 1
    ),
    revenue_metrics = bind_rows(
      preferred,
      selected_main_effects,
      selected_anova,
      largest_effect,
      spread
    ) |>
      mutate(value_label = coalesce(value_label, NA_character_)) |>
      mutate(case_id = case_id_value, .before = 1)
  )
}

normalise_case_summary <- function(cases, jurisdiction_lookup, dropped_mass,
                                   semielasticity, model_comparison,
                                   stage1_rates, revenue_metrics) {
  baseline_model <- model_comparison |>
    filter(case_id == "baseline") |>
    arrange(bic_rank) |>
    slice(1) |>
    pull(model_spec)

  semielasticity_key <- semielasticity |>
    filter(
      inference == "parent_affiliate_clustered",
      model_spec == baseline_model,
      tau == 0.05
    ) |>
    select(case_id,
      leave_semielasticity_5 = semi_elasticity,
      leave_semielasticity_5_se = std_error,
      leave_semielasticity_5_p = p_value
    )

  preferred_model <- model_comparison |>
    arrange(case_id, bic_rank) |>
    group_by(case_id) |>
    slice(1) |>
    ungroup() |>
    select(case_id, preferred_model = model_spec)

  stage1_key <- stage1_rates |>
    filter(scope == "global") |>
    select(case_id,
      leave_stage1_distributional_liability_rate =
        distributional_liability_rate,
      leave_stage1_positive_profit = positive_profit
    )

  numeric_revenue_metrics <- c(
    "preferred_sbs_behavioural_revenue",
    "preferred_universal_behavioural_revenue",
    "x1_etr_main_effect",
    "x4_sbs_main_effect",
    "x5_behaviour_main_effect",
    "x1_etr_eta_squared",
    "x4_sbs_eta_squared",
    "x5_behaviour_eta_squared",
    "eu_revenue_scenario_spread"
  )

  revenue_key <- revenue_metrics |>
    filter(metric %in% numeric_revenue_metrics) |>
    select(case_id, metric, value) |>
    pivot_wider(
      names_from = metric, values_from = value,
      names_prefix = "leave_"
    ) |>
    left_join(
      revenue_metrics |>
        filter(metric == "largest_anova_effect") |>
        select(case_id, leave_largest_anova_effect = value_label),
      by = "case_id"
    )

  baseline <- tibble(case_id = "baseline") |>
    left_join(semielasticity_key, by = "case_id") |>
    left_join(preferred_model, by = "case_id") |>
    left_join(stage1_key, by = "case_id") |>
    left_join(revenue_key, by = "case_id") |>
    rename_with(
      ~ str_replace(.x, "^leave_", "baseline_"),
      -case_id
    ) |>
    rename(baseline_preferred_model = preferred_model)

  cases |>
    left_join(jurisdiction_lookup,
      by = "jurisdiction",
      suffix = c("", "_lookup")
    ) |>
    mutate(
      jurisdiction_name = coalesce(jurisdiction_name, jurisdiction_name_lookup)
    ) |>
    select(-any_of("jurisdiction_name_lookup")) |>
    left_join(dropped_mass, by = "case_id") |>
    left_join(semielasticity_key, by = "case_id") |>
    left_join(preferred_model, by = "case_id") |>
    left_join(stage1_key, by = "case_id") |>
    left_join(revenue_key, by = "case_id") |>
    tidyr::crossing(baseline |> select(-case_id)) |>
    mutate(
      semielasticity_5_abs_change =
        leave_semielasticity_5 - baseline_semielasticity_5,
      semielasticity_5_pct_change =
        safe_divide(
          semielasticity_5_abs_change,
          baseline_semielasticity_5
        ),
      stage1_liability_rate_abs_change =
        leave_stage1_distributional_liability_rate -
          baseline_stage1_distributional_liability_rate,
      stage1_liability_rate_pct_change =
        safe_divide(
          stage1_liability_rate_abs_change,
          baseline_stage1_distributional_liability_rate
        ),
      preferred_sbs_behavioural_revenue_abs_change =
        as.numeric(leave_preferred_sbs_behavioural_revenue) -
          as.numeric(baseline_preferred_sbs_behavioural_revenue),
      preferred_sbs_behavioural_revenue_pct_change =
        safe_divide(
          preferred_sbs_behavioural_revenue_abs_change,
          as.numeric(baseline_preferred_sbs_behavioural_revenue)
        ),
      largest_anova_effect_stable =
        leave_largest_anova_effect == baseline_largest_anova_effect,
      preferred_model_stable =
        preferred_model == baseline_preferred_model,
      semielasticity_sign_stable =
        sign(leave_semielasticity_5) == sign(baseline_semielasticity_5)
    ) |>
    arrange(
      leave_dimension,
      desc(abs(preferred_sbs_behavioural_revenue_pct_change)),
      jurisdiction
    )
}

add_baseline_model_case_id <- function(model_comparison) {
  model_comparison |>
    mutate(case_id = "baseline", .before = 1)
}

run_jurisdiction_influence_suite <- function(top_n = DEFAULT_TOP_N) {
  dir.create(DIAGNOSTICS_DIR, showWarnings = FALSE, recursive = TRUE)
  stage1_bilateral <- readRDS(file.path(PROCESSED_DIR, "stage1_bilateral_panel.rds"))
  stage3_panel <- readRDS(file.path(PROCESSED_DIR, "stage3_factorial_pair_year.rds"))
  estimation_sample <- readRDS(file.path(PROCESSED_DIR, "stage3_estimation_sample.rds"))
  country_lookup <- build_country_lookup(stage3_panel)
  jurisdiction_lookup <- build_jurisdiction_lookup(
    stage1_bilateral,
    stage3_panel
  )

  baseline_stage1 <- summarise_stage1_liability(stage1_bilateral, "baseline")
  baseline_semielasticity <- read_csv(
    file.path(DIAGNOSTICS_DIR, "step5_stage3_semielasticity_schedule.csv"),
    show_col_types = FALSE
  ) |>
    mutate(case_id = "baseline", .before = 1)
  baseline_model_comparison <- read_csv(
    file.path(DIAGNOSTICS_DIR, "step5_stage3_model_comparison.csv"),
    show_col_types = FALSE
  ) |>
    add_baseline_model_case_id()
  baseline_revenue <- readRDS(file.path(PROCESSED_DIR, "stage4_5_revenue_country_year.rds"))
  baseline_revenue_decomposition <- summarise_revenue_decomposition(
    baseline_revenue,
    "baseline"
  )

  targets <- build_influence_targets(
    stage1_bilateral,
    estimation_sample,
    jurisdiction_lookup,
    top_n = top_n
  )

  message("Running ", nrow(targets), " leave-one jurisdiction cases")

  case_outputs <- vector("list", nrow(targets))
  for (i in seq_len(nrow(targets))) {
    target <- targets[i, ]
    message(" - ", target$leave_dimension, " ", target$jurisdiction)

    semielasticity_output <- fit_leave_one_semielasticity(
      estimation_sample,
      target$leave_dimension,
      target$jurisdiction,
      target$case_id
    )

    stage1_case <- summarise_stage1_liability(
      filter_leave_one(
        stage1_bilateral,
        target$leave_dimension,
        target$jurisdiction
      ),
      target$case_id
    )

    revenue_output <- build_leave_one_revenue(
      stage3_panel,
      target$leave_dimension,
      target$jurisdiction,
      country_lookup,
      target$case_id
    )
    revenue_decomposition <- summarise_revenue_decomposition(
      revenue_output$revenue_country_year,
      target$case_id
    )

    case_outputs[[i]] <- list(
      dropped_mass = summarise_case_dropped_mass(
        stage1_bilateral,
        estimation_sample,
        target$leave_dimension,
        target$jurisdiction
      ) |>
        mutate(case_id = target$case_id, .before = 1),
      stage1 = stage1_case,
      semielasticity = semielasticity_output$semielasticity,
      model_comparison = semielasticity_output$model_comparison |>
        mutate(case_id = target$case_id, .before = 1),
      revenue_summary = revenue_decomposition$scenario_summary,
      anova_pooled = revenue_decomposition$anova_pooled,
      main_effects = revenue_decomposition$main_effects,
      revenue_metrics = revenue_decomposition$revenue_metrics,
      conservation = revenue_output$conservation |>
        mutate(case_id = target$case_id, .before = 1)
    )
  }

  dropped_mass <- bind_rows(map(case_outputs, "dropped_mass"))
  stage1_rates <- bind_rows(
    baseline_stage1,
    bind_rows(map(case_outputs, "stage1"))
  )
  semielasticity <- bind_rows(
    baseline_semielasticity,
    bind_rows(map(case_outputs, "semielasticity"))
  )
  model_comparison <- bind_rows(
    baseline_model_comparison,
    bind_rows(map(case_outputs, "model_comparison"))
  )
  revenue_summary <- bind_rows(
    baseline_revenue_decomposition$scenario_summary,
    bind_rows(map(case_outputs, "revenue_summary"))
  )
  anova_pooled <- bind_rows(
    baseline_revenue_decomposition$anova_pooled,
    bind_rows(map(case_outputs, "anova_pooled"))
  )
  main_effects <- bind_rows(
    baseline_revenue_decomposition$main_effects,
    bind_rows(map(case_outputs, "main_effects"))
  )
  revenue_metrics <- bind_rows(
    baseline_revenue_decomposition$revenue_metrics,
    bind_rows(map(case_outputs, "revenue_metrics"))
  )
  conservation <- bind_rows(map(case_outputs, "conservation"))

  case_summary <- normalise_case_summary(
    targets,
    jurisdiction_lookup,
    dropped_mass,
    semielasticity,
    model_comparison,
    stage1_rates,
    revenue_metrics
  )

  write_csv(
    targets,
    file.path(DIAGNOSTICS_DIR, "step10_jurisdiction_influence_cases.csv")
  )
  write_csv(
    case_summary,
    file.path(DIAGNOSTICS_DIR, "step10_jurisdiction_influence_case_summary.csv")
  )
  write_csv(
    stage1_rates,
    file.path(DIAGNOSTICS_DIR, "step10_jurisdiction_influence_stage1_rates.csv")
  )
  write_csv(
    semielasticity,
    file.path(DIAGNOSTICS_DIR, "step10_jurisdiction_influence_semielasticity.csv")
  )
  write_csv(
    model_comparison,
    file.path(DIAGNOSTICS_DIR, "step10_jurisdiction_influence_model_comparison.csv")
  )
  write_csv(
    revenue_summary,
    file.path(DIAGNOSTICS_DIR, "step10_jurisdiction_influence_revenue_summary.csv")
  )
  write_csv(
    anova_pooled,
    file.path(DIAGNOSTICS_DIR, "step10_jurisdiction_influence_anova_pooled.csv")
  )
  write_csv(
    main_effects,
    file.path(DIAGNOSTICS_DIR, "step10_jurisdiction_influence_main_effects.csv")
  )
  write_csv(
    revenue_metrics,
    file.path(DIAGNOSTICS_DIR, "step10_jurisdiction_influence_revenue_metrics.csv")
  )
  write_csv(
    conservation,
    file.path(DIAGNOSTICS_DIR, "step10_jurisdiction_influence_conservation.csv")
  )

  saveRDS(
    case_summary,
    file.path(PROCESSED_DIR, "jurisdiction_influence_case_summary.rds")
  )
  saveRDS(
    stage1_rates,
    file.path(PROCESSED_DIR, "jurisdiction_influence_stage1_rates.rds")
  )
  saveRDS(
    semielasticity,
    file.path(PROCESSED_DIR, "jurisdiction_influence_semielasticity.rds")
  )
  saveRDS(
    model_comparison,
    file.path(PROCESSED_DIR, "jurisdiction_influence_model_comparison.rds")
  )
  saveRDS(
    revenue_summary,
    file.path(PROCESSED_DIR, "jurisdiction_influence_revenue_summary.rds")
  )
  saveRDS(
    anova_pooled,
    file.path(PROCESSED_DIR, "jurisdiction_influence_anova_pooled.rds")
  )
  saveRDS(
    main_effects,
    file.path(PROCESSED_DIR, "jurisdiction_influence_main_effects.rds")
  )

  message("\nStep 10 outputs written:")
  message(" - diagnostics/step10_jurisdiction_influence_*.csv")
  message(" - data/processed/jurisdiction_influence_*.rds")

  invisible(list(
    targets = targets,
    case_summary = case_summary,
    stage1_rates = stage1_rates,
    semielasticity = semielasticity,
    model_comparison = model_comparison,
    revenue_summary = revenue_summary,
    anova_pooled = anova_pooled,
    main_effects = main_effects
  ))
}

run_policy_game_and_variance_extensions <- function(
  phase = c("all", "fiscal_flows", "policy_and_variance", "measurement_error"),
  n_draws = MEASUREMENT_ERROR_DRAWS,
  seed = MEASUREMENT_ERROR_SEED
) {
  phase <- match.arg(phase)
  if (phase %in% c("all", "fiscal_flows")) {
    run_fiscal_flows_and_stress_tests()
  }
  if (phase %in% c("all", "policy_and_variance")) {
    run_qdmtt_game_diagnostics()
    run_total_variance_and_accounting_factorial()
    run_profit_correction_revenue_uncertainty()
    run_jurisdiction_influence_suite()
  }
  if (phase %in% c("all", "measurement_error")) {
    run_stage1_measurement_error_simulation(n_draws = n_draws, seed = seed)
  }
}

if (is_direct_script_run("code/11_policy_game_and_variance_extensions.R")) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) && !all(grepl("^--(phase|draws|seed)=.+$", args))) {
    stop("Usage: specify --phase=all|fiscal_flows|policy_and_variance|measurement_error, --draws=N or --seed=N")
  }
  values <- strsplit(sub("^--", "", args), "=", fixed = TRUE)
  flags <- setNames(lapply(values, `[[`, 2L), vapply(values, `[[`, "", 1L))
  stopifnot(!anyDuplicated(names(flags)))
  run_policy_game_and_variance_extensions(
    phase = if (is.null(flags$phase)) "all" else flags$phase,
    n_draws = if (is.null(flags$draws)) MEASUREMENT_ERROR_DRAWS else as.integer(flags$draws),
    seed = if (is.null(flags$seed)) MEASUREMENT_ERROR_SEED else as.integer(flags$seed)
  )
}
