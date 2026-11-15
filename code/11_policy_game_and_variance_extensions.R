# Fiscal flows, allocation counterfactuals, policy games and uncertainty.

source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "10_accounting_bridge_and_conduit_wedge.R"), local = TRUE)

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
  validate_utpr_weights(weights, EU27_ISO3)
  routed <- allocation_regime(rep(1, nrow(rows)), rows$qdmtt_flag,
                               rows$parent_iir_utpr_flag, rows$sbs_exempt)
  direct <- bind_rows(
    tibble(cell = which(routed == "qdmtt"), country = rows$affiliate[routed == "qdmtt"], share = 1),
    tibble(cell = which(routed == "iir"), country = rows$parent[routed == "iir"], share = 1)
  )
  utpr <- rows |> mutate(cell = row_number(), regime = routed) |>
    filter(regime == "utpr") |> select(cell, parent, year)
  routes <- expand_utpr_routes(utpr, weights)
  if (anyNA(routes$collector)) {
    stop("Sparse operator has a potential UTPR source with no supported collector route", call. = FALSE)
  }
  distributed <- routes |> transmute(cell, country = collector, share = utpr_weight)
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

run_policy_game_and_variance_extensions <- function() {
  run_qdmtt_game_diagnostics()
  run_total_variance_and_accounting_factorial()
  run_jurisdiction_influence_suite()
}

if (is_direct_script_run("code/11_policy_game_and_variance_extensions.R")) {
  run_policy_game_and_variance_extensions()
}
