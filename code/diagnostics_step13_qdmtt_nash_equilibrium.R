# Run from the repository root after Stages 1–4.6. Write only Step 13 CSVs.
source("code/diagnostics_step9_bilateral_aggregation_ladder.R", local = TRUE)

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

run_step13_diagnostics <- function() {
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

if (is_direct_script_run("code/diagnostics_step13_qdmtt_nash_equilibrium.R")) run_step13_diagnostics()
