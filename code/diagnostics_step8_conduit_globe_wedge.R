# Run from the repository root after Stages 1–4.6. This audit reads the
# replication objects and writes only the four Step 8 diagnostic CSVs.
source("code/03_stage1_etr.R", local = TRUE)
source("code/diagnostics_step5_revenue_architecture.R", local = TRUE)

STEP8_KEYS <- c("parent", "affiliate", "year")
STEP8_HOSTS <- c("NLD", "LUX", "IRL", "CYP", "DEU", "FRA", "BEL")
STEP8_AGGREGATES <- c("A", "A_O", "E", "E_O", "F", "F_O", "S", "S_O",
  "W", "W_O", "WXD", "STLS")
STEP8_EUR_USD <- 1.0813
STEP8_SCENARIOS <- c("x10011", "x10001")

step8_read <- function(stem) readRDS(file.path(PROCESSED_DIR, paste0(stem, ".rds")))

step8_write <- function(data, stem) {
  write_csv(data, file.path(DIAGNOSTICS_DIR, paste0("step8_", stem, ".csv")))
}

step8_profit_fields <- function(table) {
  table |>
    transmute(
      parent, affiliate, year, profit_panelai, profit_adj_panelai,
      tax_accrued_panelai, entities_count_panelai, act_holding_panelai,
      act_igf_panelai, act_ip_panelai,
      holding_share_panelai = safe_divide(act_holding_panelai, entities_count_panelai),
      igf_share_panelai = safe_divide(act_igf_panelai, entities_count_panelai),
      ip_share_panelai = safe_divide(act_ip_panelai, entities_count_panelai)
    )
}

step8_table4_partitions <- function(table4) {
  table4 |>
    filter(year %in% DIRECT_YEARS, !affiliate %in% STEP8_AGGREGATES,
      etr_bracket %in% T4_POSITIVE_BRACKETS
    ) |>
    group_by(parent, affiliate, year) |>
    summarise(
      t4_low_observed = any(etr_bracket == "rate_0_15" & !is.na(profit)),
      t4_upper_observed = any(etr_bracket != "rate_0_15" & !is.na(profit)),
      t4_profit = sum(pmax(profit, 0), na.rm = TRUE),
      t4_low_profit = sum(pmax(profit[etr_bracket == "rate_0_15"], 0), na.rm = TRUE),
      t4_low_tax = sum_or_na(tax_accrued[etr_bracket == "rate_0_15"]),
      .groups = "drop"
    ) |>
    mutate(
      t4_low_share = safe_divide(t4_low_profit, t4_profit),
      t4_low_etr = safe_divide(t4_low_tax, t4_low_profit)
    )
}

step8_observed_inventory <- function(table1, partitions) {
  step8_profit_fields(table1) |>
    filter(!is.na(profit_adj_panelai)) |>
    mutate(
      cell_type = case_when(
        parent %in% STEP8_AGGREGATES | affiliate %in% STEP8_AGGREGATES ~ "geographic_aggregate",
        parent == affiliate ~ "domestic",
        TRUE ~ "foreign"
      ),
      observed_profit_reduction = profit_panelai - profit_adj_panelai,
      observed_rho = safe_divide(observed_profit_reduction, profit_panelai),
      raw_etr = safe_divide(tax_accrued_panelai, profit_panelai),
      adjusted_etr = safe_divide(tax_accrued_panelai, profit_adj_panelai)
    ) |>
    left_join(partitions, by = STEP8_KEYS, relationship = "one-to-one") |>
    mutate(
      t4_positive_partition_observed = coalesce(t4_low_observed & t4_upper_observed & t4_profit > 0, FALSE),
      observed_reduction_to_t4_low_profit = safe_divide(observed_profit_reduction, t4_low_profit),
      all_low_dollar_purge_feasible = if_else(
        t4_positive_partition_observed,
        observed_profit_reduction >= 0 & observed_profit_reduction <= t4_low_profit &
          observed_profit_reduction < t4_profit,
        NA
      )
    ) |>
    arrange(cell_type, parent, affiliate, year)
}

step8_anatomy <- function(base, stage1, source, partitions, host_stage1, table4) {
  cells <- step8_profit_fields(base) |>
    inner_join(
      base |>
        select(all_of(STEP8_KEYS), analysis_profit_base, profit_correction_rate_preferred,
          profit_correction_source, rho_hat_pt),
      by = STEP8_KEYS, relationship = "one-to-one"
    ) |>
    inner_join(stage1, by = STEP8_KEYS, relationship = "one-to-one") |>
    filter(affiliate %in% c(STEP8_HOSTS, "GBR", "USA"), year %in% DIRECT_YEARS) |>
    left_join(
      source |>
        filter(scenario_id == "x10011") |>
        select(all_of(STEP8_KEYS), stage4_qdmtt_liability),
      by = STEP8_KEYS, relationship = "one-to-one"
    ) |>
    left_join(partitions, by = STEP8_KEYS, relationship = "one-to-one") |>
    left_join(
      host_stage1 |>
        select(affiliate, year, direct_positive_profit_total, direct_low_profit,
          direct_low_tax, direct_low_share, direct_topup_rate),
      by = c("affiliate", "year"), relationship = "many-to-one"
    ) |>
    mutate(
      parent_group = case_when(parent == affiliate ~ "domestic", parent == "USA" ~ "USA",
        TRUE ~ "other_foreign"),
      table1_profit_reduction = profit_panelai - analysis_profit_base,
      table1_observed_reduction_to_t4_low_profit =
        safe_divide(profit_panelai - profit_adj_panelai, t4_low_profit),
      t4_parent_profit_share_of_pool = safe_divide(t4_profit, direct_positive_profit_total),
      stage4_qdmtt_eur_bn = stage4_qdmtt_liability / STEP8_EUR_USD / 1e9
    )
  cumulative <- cells |>
    group_by(affiliate, parent, parent_group) |>
    summarise(
      across(c(analysis_profit_positive, stage1_lowtax_profit_distributional,
        stage4_qdmtt_liability, stage4_qdmtt_eur_bn), ~ sum(.x, na.rm = TRUE)),
      .groups = "drop"
    ) |>
    mutate(record_type = "parent_2019_2023", n_years = length(DIRECT_YEARS))
  parent_groups <- cells |>
    mutate(window = as.character(year)) |>
    bind_rows(mutate(cells, window = "2019–2023")) |>
    group_by(affiliate, parent_group, window) |>
    summarise(
      across(c(analysis_profit_positive, stage1_lowtax_profit_distributional,
        stage4_qdmtt_liability, stage4_qdmtt_eur_bn), ~ sum(.x, na.rm = TRUE)),
      .groups = "drop"
    ) |>
    mutate(record_type = "parent_group",
      n_years = if_else(window == "2019–2023", length(DIRECT_YEARS), 1L))

  # Include every published Table IV PROFIT_ADJ record, including aggregates
  # and out-of-window brackets, separately from the bilateral anatomy rows.
  t4_reported <- table4 |>
    filter(!is.na(profit_adj)) |>
    transmute(record_type = "table4_reported_adjusted_bracket", parent, affiliate, year,
      etr_bracket, t4_bracket_profit = profit, t4_bracket_profit_adj = profit_adj,
      t4_bracket_tax_accrued = tax_accrued, t4_bracket_reported_reduction = profit - profit_adj)
  t4_adjusted_partitions <- t4_reported |>
    filter(year %in% DIRECT_YEARS, etr_bracket %in% T4_POSITIVE_BRACKETS) |>
    group_by(parent, affiliate, year) |>
    filter(any(etr_bracket == "rate_0_15"), any(etr_bracket != "rate_0_15")) |>
    summarise(
      t4_profit = sum(t4_bracket_profit),
      t4_low_profit = sum(t4_bracket_profit[etr_bracket == "rate_0_15"]),
      t4_low_tax = sum(t4_bracket_tax_accrued[etr_bracket == "rate_0_15"]),
      t4_reported_adjusted_profit = sum(t4_bracket_profit_adj),
      t4_reported_adjusted_low_profit = sum(t4_bracket_profit_adj[etr_bracket == "rate_0_15"]),
      t4_reported_upper_reduction = sum(t4_bracket_reported_reduction[etr_bracket != "rate_0_15"]),
      .groups = "drop"
    ) |>
    mutate(
      record_type = "table4_reported_adjusted_partition",
      t4_low_share = safe_divide(t4_low_profit, t4_profit),
      t4_bracket_reported_reduction = t4_profit - t4_reported_adjusted_profit,
      t4_reported_adjusted_low_share = safe_divide(t4_reported_adjusted_low_profit, t4_reported_adjusted_profit),
      t4_all_low_implied_share = safe_divide(pmax(t4_low_profit - t4_bracket_reported_reduction, 0),
        t4_reported_adjusted_profit),
      t4_all_low_dollar_purge_feasible = t4_bracket_reported_reduction <= t4_low_profit &
        t4_bracket_reported_reduction >= 0 & t4_reported_adjusted_profit > 0
    )

  bind_rows(mutate(cells, record_type = "cell_year", n_years = 1L), cumulative,
    parent_groups, t4_reported, t4_adjusted_partitions) |>
    group_by(record_type, affiliate, year, window) |>
    mutate(
      qdmtt_share_of_affiliate = safe_divide(stage4_qdmtt_liability,
        sum(stage4_qdmtt_liability, na.rm = TRUE)),
      qdmtt_rank = min_rank(desc(stage4_qdmtt_liability)),
      positive_profit_rank = min_rank(desc(analysis_profit_positive)),
      lowtax_profit_rank = min_rank(desc(stage1_lowtax_profit_distributional)),
      qdmtt_annualised_eur_bn = stage4_qdmtt_eur_bn / n_years
    ) |>
    ungroup() |>
    relocate(record_type, parent, affiliate, year, window) |>
    arrange(record_type, affiliate, year, window, qdmtt_rank, parent)
}

# Keep tax fixed and remove positive profit from its original low bracket.
# Cap the removal within the reporting partition. A clipped request is a
# failure of the all-low assumption for that requested amount, not a
# licence to remove the excess from a different reporter or bracket.
step8_remove_low_profit <- function(total, low, tax, requested) {
  applied <- pmin(requested, low)
  remaining_low <- low - applied
  remaining_total <- total - applied
  share <- coalesce(safe_divide(remaining_low, remaining_total), 0)
  etr <- safe_divide(tax, remaining_low)
  gap <- if_else(remaining_low > 0, GMT_RATE - pmin(pmax(etr, 0), GMT_RATE), 0)
  rho_iv <- coalesce(safe_divide(applied, total), 0)
  original_share <- coalesce(safe_divide(low, total), 0)
  identity_share <- coalesce(safe_divide(pmax(original_share - rho_iv, 0), 1 - rho_iv), 0)
  stopifnot(all(abs(share - identity_share) < 1e-9))
  # Within-bracket ETR identity applies only while low profit remains.
  stable <- remaining_low > 0 & low > 0 & remaining_low / pmax(low, 1) > 1e-8 & is.finite(tax)
  identity_etr <- (tax[stable] / low[stable]) / (1 - applied[stable] / low[stable])
  stopifnot(isTRUE(all.equal(etr[stable], identity_etr, tolerance = 1e-8)))
  tibble(requested, applied, share, gap)
}

step8_reconcile_rates <- function(stage1, base, host_stage1, partitions, gamma, method) {
  correction <- base |>
    transmute(
      parent, affiliate, year,
      domestic_rho = if_else(parent == affiliate & profit_panelai > 0,
        clamp_unit_interval(profit_correction_rate_preferred), 0),
      foreign_rho = if_else(parent != affiliate &
          (affiliate_is_conduit_haven | affiliate %in% c("CYP", "MLT")) &
          is.na(profit_adj_panelai),
        gamma * clamp_unit_interval(holding_share_panelai), 0),
      table1_raw_positive = coalesce(pmax(profit_panelai, 0), 0)
    ) |>
    mutate(across(c(domestic_rho, foreign_rho), ~ coalesce(.x, 0)))

  direct_hosts <- host_stage1 |>
    filter(stage1_distributional_source == "direct_t4") |>
    select(affiliate, year, direct_positive_profit_total, direct_low_profit, direct_low_tax)
  cells <- stage1 |>
    left_join(correction, by = STEP8_KEYS, relationship = "one-to-one") |>
    mutate(direct = stage1_distributional_source == "direct_t4")
  support <- partitions |>
    semi_join(direct_hosts, by = c("affiliate", "year")) |>
    left_join(correction, by = STEP8_KEYS, relationship = "one-to-one") |>
    mutate(
      rho = coalesce(domestic_rho + foreign_rho, 0),
      t4_requested = rho * t4_profit,
      t4_removed = pmin(t4_requested, t4_low_profit)
    ) |>
    group_by(affiliate, year) |>
    summarise(
      t4_profit_rebuilt = sum(t4_profit),
      t4_low_rebuilt = sum(t4_low_profit),
      t4_tax_rebuilt = sum(t4_low_tax, na.rm = TRUE),
      requested = sum(t4_requested),
      applied = sum(t4_removed),
      .groups = "drop"
    ) |>
    inner_join(direct_hosts, by = c("affiliate", "year"), relationship = "one-to-one")
  for (fields in list(c("t4_profit_rebuilt", "direct_positive_profit_total"),
    c("t4_low_rebuilt", "direct_low_profit"), c("t4_tax_rebuilt", "direct_low_tax"))) {
    stopifnot(isTRUE(all.equal(support[[fields[1]]], support[[fields[2]]], tolerance = 1e-10)))
  }

  if (method == "reporter_pool") {
    pooled <- step8_remove_low_profit(support$direct_positive_profit_total,
      support$direct_low_profit, support$direct_low_tax, support$applied)
    cells <- cells |>
      left_join(
        transmute(bind_cols(support, select(pooled, share, gap)), affiliate, year,
          requested, applied, share, gap),
        by = c("affiliate", "year"), relationship = "many-to-one"
      ) |>
      mutate(
        revised_share = if_else(direct & applied > 0, share, stage1_distributional_low_share),
        revised_gap = if_else(direct & applied > 0, gap, stage1_distributional_topup_rate),
        foreign_removal = if_else(direct, analysis_profit_positive * foreign_rho, 0)
      )
  } else {
    # Apply the pooled shape to the target cell's own pre-correction profit.
    # This transports the shape when the target parent supplied no Table IV
    # observation. Its inferred low-bracket dollars are not OECD observations.
    synthetic_low <- coalesce(cells$stage1_distributional_low_share, 0) * cells$table1_raw_positive
    synthetic_tax <- synthetic_low * (GMT_RATE - coalesce(cells$stage1_distributional_topup_rate, 0))
    requested <- if_else(cells$direct, cells$table1_raw_positive *
      (cells$domestic_rho + cells$foreign_rho), 0)
    transport <- step8_remove_low_profit(cells$table1_raw_positive, synthetic_low,
      synthetic_tax, requested)
    cells <- bind_cols(cells, transport) |>
      mutate(
        revised_share = if_else(applied > 0, share, stage1_distributional_low_share),
        revised_gap = if_else(applied > 0, gap, stage1_distributional_topup_rate),
        foreign_removal = if_else(parent != affiliate, pmin(applied, analysis_profit_positive), 0)
      )
    support <- cells |>
      group_by(affiliate, year) |>
      summarise(across(c(requested, applied), sum), .groups = "drop")
  }

  list(
    cells = cells |>
      mutate(
        revised_profit = analysis_profit_positive - foreign_removal,
        revised_lowtax_profit = revised_profit * coalesce(revised_share, 0),
        revised_stage1_tax = revised_lowtax_profit * coalesce(revised_gap, 0)
      ) |>
      select(all_of(STEP8_KEYS), revised_profit, revised_share, revised_gap,
        revised_lowtax_profit, revised_stage1_tax, foreign_removal),
    support = select(support, affiliate, year, requested, applied)
  )
}

step8_allocate <- function(source, weights) {
  allocation <- allocate_stage4_revenue(source, weights)
  conservation <- build_conservation_diagnostics(source, allocation$revenue_by_channel_global)
  gap <- max(abs(conservation$residual_gap))
  stopifnot(gap < 1e-3, nrow(allocation$revenue_country_year_eu27) == 27 * 7 * 32)
  list(
    revenue = allocation$revenue_country_year_eu27,
    channels = allocation$revenue_by_channel_global,
    gap = gap
  )
}

step8_reallocate <- function(revised, factorial, stage2, host_stage1, sectors, weights, beta) {
  host_rates <- revised |>
    group_by(affiliate, year) |>
    summarise(
      host_share = safe_divide(sum(revised_lowtax_profit), sum(revised_profit)),
      host_gap = coalesce(safe_divide(sum(revised_stage1_tax), sum(revised_lowtax_profit)), 0),
      .groups = "drop"
    )
  updated_host <- host_stage1 |>
    left_join(host_rates, by = c("affiliate", "year"), relationship = "one-to-one") |>
    mutate(
      stage1_distributional_low_share = coalesce(host_share, stage1_distributional_low_share),
      stage1_distributional_topup_rate = if_else(!is.na(host_share), host_gap,
        stage1_distributional_topup_rate)
    )
  updated_stage2 <- stage2 |>
    left_join(revised, by = STEP8_KEYS, relationship = "many-to-one") |>
    mutate(
      analysis_profit_positive = revised_profit,
      stage2_phi = compute_phi_ratio(stage2_sbie, revised_profit),
      stage2_filter = 1 - coalesce(stage2_phi, 0),
      stage2_excess_lowtax_profit_distributional = revised_lowtax_profit * stage2_filter,
      stage2_topup_tax_distributional = revised_stage1_tax * stage2_filter
    )

  # Recompute the sectoral SBTI multiplier because the overlay is nonlinear
  # in the host gap. Observed sector proxy weights, phi and kappa stay fixed.
  updated_sectors <- sectors |>
    select(-stage1_distributional_topup_rate) |>
    left_join(select(updated_host, affiliate, year, stage1_distributional_topup_rate),
      by = c("affiliate", "year"), relationship = "many-to-one")
  bridge <- build_sectoral_factor2_bridge(updated_stage2, updated_host, updated_sectors)
  scenarios <- factorial |>
    filter(x1_etr == 1) |>
    select(-analysis_profit_positive, -stage2_phi, -stage1_distributional_low_share,
      -stage1_lowtax_profit_distributional, -stage2_excess_lowtax_profit_distributional) |>
    left_join(
      updated_stage2 |>
        transmute(
          parent, affiliate, year, rate_scenario, analysis_profit_positive, stage2_phi,
          stage1_distributional_low_share = revised_share,
          stage1_lowtax_profit_distributional = revised_lowtax_profit,
          stage2_excess_lowtax_profit_distributional, stage2_topup_tax_distributional
        ),
      by = c(STEP8_KEYS, "rate_scenario"), relationship = "many-to-one"
    ) |>
    left_join(
      select(bridge, affiliate, year, rate_scenario, sectoral_scale_distributional),
      by = c("affiliate", "year", "rate_scenario"), relationship = "many-to-one"
    ) |>
    left_join(host_rates, by = c("affiliate", "year"), relationship = "many-to-one") |>
    mutate(
      stage2_topup_selected = stage2_topup_tax_distributional,
      sectoral_scale_selected = if_else(x2_substance == 0, 1, coalesce(sectoral_scale_distributional, 1)),
      topup_after_stage2 = stage2_topup_selected * sectoral_scale_selected,
      host_tau = if_else(host_share > 0 & host_gap > 0, GMT_RATE - host_gap, NA_real_)
    )
  raw_beta <- coalesce(compute_reallocation_share(
    scenarios$host_tau, rep_len("linear", nrow(scenarios)), beta
  ), 0)
  updated <- replace_behaviour_schedule(scenarios, scenarios$host_tau, raw_beta)
  stage8_source <- bind_rows(filter(factorial, x1_etr == 0), select(updated, all_of(names(factorial))))
  step8_allocate(build_source_panel(stage8_source), weights)
}

step8_scopes <- function(data, location) {
  data <- rename(data, scope = all_of(location))
  bind_rows(
    filter(data, scope %in% STEP8_HOSTS),
    mutate(filter(data, scope %in% EU27_ISO3), scope = "EU27"),
    mutate(data, scope = "Global")
  )
}

step8_windows <- function(data) {
  bind_rows(
    mutate(data, window = paste0("FY", year), n_years = 1L),
    mutate(filter(data, year %in% DIRECT_YEARS), window = "2019–2023", n_years = length(DIRECT_YEARS)),
    mutate(filter(data, year %in% MAIN_YEARS), window = "2017–2023", n_years = length(MAIN_YEARS))
  )
}

step8_comparison <- function(revised, support, allocation, branch, method, gamma) {
  measures <- revised |>
    step8_scopes("affiliate") |>
    step8_windows() |>
    group_by(scope, window, n_years) |>
    summarise(
      corrected_positive_profit_usd = sum(revised_profit),
      lowtax_profit_usd = sum(revised_lowtax_profit),
      stage1_liability_usd = sum(revised_stage1_tax),
      foreign_table1_removal_usd = sum(foreign_removal),
      .groups = "drop"
    ) |>
    mutate(
      low_share = safe_divide(lowtax_profit_usd, corrected_positive_profit_usd),
      topup_gap = safe_divide(stage1_liability_usd, lowtax_profit_usd),
      liability_rate = safe_divide(stage1_liability_usd, corrected_positive_profit_usd)
    )
  support <- support |>
    step8_scopes("affiliate") |>
    step8_windows() |>
    group_by(scope, window) |>
    summarise(
      requested_purge_usd = sum(requested),
      applied_purge_usd = sum(applied),
      unplaced_purge_usd = sum(requested - applied),
      .groups = "drop"
    )
  revenues <- allocation$channels |>
    filter(scenario_id %in% STEP8_SCENARIOS) |>
    step8_scopes("country") |>
    step8_windows() |>
    group_by(scenario_id, scope, window, n_years) |>
    summarise(
      collector_usd = sum(revenue),
      qdmtt_usd = sum(revenue[channel == "QDMTT"]),
      iir_usd = sum(revenue[channel == "IIR"]),
      utpr_usd = sum(revenue[channel == "UTPR"]),
      .groups = "drop"
    )
  crossing(measures, scenario_id = STEP8_SCENARIOS) |>
    left_join(support, by = c("scope", "window"), relationship = "many-to-one") |>
    left_join(revenues, by = c("scenario_id", "scope", "window", "n_years"), relationship = "one-to-one") |>
    mutate(
      branch = branch, method = method, gamma = gamma,
      across(ends_with("_usd"), ~ coalesce(.x, 0)),
      across(c(collector_usd, qdmtt_usd, iir_usd, utpr_usd), ~ .x / STEP8_EUR_USD / 1e9 / n_years,
        .names = "{.col}_annualised_eur_bn"),
      max_global_conservation_gap_usd = allocation$gap,
      .before = 1
    ) |>
    rename_with(~ sub("_usd_annualised", "_annualised", .x), ends_with("_usd_annualised_eur_bn"))
}

step8_budget_comparisons <- function(metrics) {
  forecasts <- read_csv(
    file.path(DIAGNOSTICS_DIR, "step7_official_budget_forecasts_backtest.csv"),
    show_col_types = FALSE
  ) |>
    filter(window == "FY2023", country %in% STEP8_HOSTS, startsWith(evidence, "official") |
        evidence == "implied by official figures") |>
    transmute(scope = country, benchmark, evidence, forecast_period, revenue_scope, model_scope,
      official_low_eur_bn, official_high_eur_bn, source_url)
  # The published Luxembourg budget adds a comparison absent from Step 7.
  luxembourg <- tibble(
    scope = "LUX", benchmark = "Luxembourg draft budget 2026, Pillar Two minimum tax",
    evidence = "official forecast", forecast_period = "2026 cash",
    revenue_scope = "Pillar Two minimum tax, channels not disaggregated", model_scope = "direct",
    official_low_eur_bn = 0.080, official_high_eur_bn = 0.080,
    source_url = paste0("https://budget.public.lu/dam-assets/lb/budget2026/",
      "links-dokumenter/bu-2026-volume-1-pour-web-v1.pdf")
  )
  comparisons <- metrics |>
    filter(window %in% c("FY2023", "2019–2023")) |>
    inner_join(bind_rows(forecasts, luxembourg), by = "scope", relationship = "many-to-many") |>
    mutate(
      comparable_annualised_eur_bn = case_when(
        model_scope == "qdmt" ~ qdmtt_annualised_eur_bn,
        model_scope == "iir" ~ iir_annualised_eur_bn,
        TRUE ~ collector_annualised_eur_bn
      ),
      model_minus_official_eur_bn = comparable_annualised_eur_bn - official_low_eur_bn,
      model_to_official_ratio = safe_divide(comparable_annualised_eur_bn, official_low_eur_bn),
      comparable_scope = if_else(grepl("behavioural CIT", revenue_scope, fixed = TRUE) |
          grepl("2026 (pre|post)-SbS", benchmark),
        "numerical comparison to wider fiscal forecast", "direct collection channel comparison")
    )
  bind_rows(mutate(metrics, record_type = "simulation"),
    mutate(comparisons, record_type = "official_forecast")) |>
    relocate(record_type) |>
    arrange(record_type, branch, scope, window, scenario_id, benchmark)
}

run_step8_diagnostics <- function() {
  base <- step8_read("base_panel")
  table4 <- step8_read("cbcr_table4")
  stage1 <- step8_read("stage1_bilateral_panel") |>
    select(all_of(STEP8_KEYS), analysis_profit_positive, stage1_distributional_source,
      stage1_distributional_low_share, stage1_distributional_topup_rate,
      stage1_lowtax_profit_distributional, stage1_topup_tax_distributional)
  host_stage1 <- step8_read("stage1_affiliate_year")
  partitions <- step8_table4_partitions(table4)
  source <- step8_read("stage4_5_allocation_source_panel") |>
    select(all_of(SCENARIO_VARS), all_of(STEP8_KEYS), affiliate_jurisdiction_name,
      parent_jurisdiction_name, qdmtt_flag, parent_iir_utpr_flag, sbs_exempt,
      topup_after_behaviour, stage4_qdmtt_liability, affiliate_oecd_iir_by_2026,
      affiliate_policy_iir_utpr_by_2026, affiliate_policy_utpr_by_2026,
      affiliate_policy_iir_utpr_explicit_by_2026, affiliate_policy_iir_utpr_ambiguous_by_2026)
  message("Checking observed bracket support and ranking source cells")
  anatomy <- step8_anatomy(base, stage1, source, partitions, host_stage1, table4)
  table1 <- step8_read("cbcr_table1")
  inventory <- step8_observed_inventory(table1, partitions)
  assert_unique_keys(inventory, STEP8_KEYS, "Observed Table I adjusted profits")
  stopifnot(nrow(inventory) == sum(!is.na(table1$profit_adj_panelai)))

  factorial <- stage5_source_inputs()
  stage2 <- step8_read("stage2_bilateral_panel") |>
    select(all_of(STEP8_KEYS), rate_scenario, affiliate_is_eu27, stage2_sbie,
      stage2_topup_tax_average)
  sectors <- step8_read("stage2_sectoral_panel")
  weights <- list(
    parent_year_weights = step8_read("stage4_5_utpr_parent_year_weights"),
    fallback_weights = step8_read("stage4_5_utpr_fallback_weights")
  )
  beta <- step8_read("stage3_model_coefficients") |>
    filter(model_spec == "linear", term == "tau", inference == "parent_affiliate_clustered") |>
    pull(estimate)
  stopifnot(length(beta) == 1, is.finite(beta))
  baseline <- step8_allocate(build_source_panel(source), weights)
  archived <- step8_read("stage4_5_revenue_country_year") |>
    select(scenario_id, country, year, archived_revenue = revenue)
  baseline_check <- baseline$revenue |>
    inner_join(archived, by = c("scenario_id", "country", "year"), relationship = "one-to-one")
  stopifnot(nrow(baseline_check) == nrow(archived),
    max(abs(baseline_check$revenue - baseline_check$archived_revenue)) < 1e-3)

  baseline_rates <- stage1 |>
    transmute(
      parent, affiliate, year, revised_profit = analysis_profit_positive,
      revised_share = stage1_distributional_low_share,
      revised_gap = stage1_distributional_topup_rate,
      revised_lowtax_profit = coalesce(stage1_lowtax_profit_distributional, 0),
      revised_stage1_tax = coalesce(stage1_topup_tax_distributional, 0),
      foreign_removal = 0
    )
  # A zero-adjustment replay checks the same bridge, behaviour and allocation
  # path used in all sensitivities against the archived country-year totals.
  replay <- step8_reallocate(baseline_rates, factorial, stage2, host_stage1, sectors, weights, beta)
  replay_check <- replay$revenue |>
    inner_join(archived, by = c("scenario_id", "country", "year"), relationship = "one-to-one")
  stopifnot(nrow(replay_check) == nrow(archived),
    max(abs(replay_check$revenue - replay_check$archived_revenue)) < 1e-3)
  baseline_support <- distinct(stage1, affiliate, year) |>
    mutate(requested = 0, applied = 0)
  design <- distinct(baseline$revenue, scenario_id, across(all_of(FACTOR_COLS)))
  metrics <- list(step8_comparison(baseline_rates, baseline_support, baseline,
    "B1_baseline", "current_pipeline", 0))
  anova <- list(summarise_stress_variant(baseline$revenue, design, FACTOR_COLS,
    "B1_baseline", baseline$gap))

  specifications <- tribble(
    ~branch, ~method, ~gamma,
    "B2_domestic", "reporter_pool", 0,
    "B3_foreign_gamma_0_5", "reporter_pool", 0.5,
    "B3_foreign_gamma_1", "reporter_pool", 1,
    "B2_domestic_transported", "target_cell_transport", 0,
    "B3_foreign_gamma_1_transported", "target_cell_transport", 1
  )
  for (i in seq_len(nrow(specifications))) {
    specification <- specifications[i, ]
    message("Recomputing Stages 1–4.5 for ", specification$branch)
    revised <- step8_reconcile_rates(stage1, base, host_stage1, partitions,
      specification$gamma, specification$method)
    allocation <- step8_reallocate(revised$cells, factorial, stage2, host_stage1,
      sectors, weights, beta)
    metrics[[i + 1L]] <- step8_comparison(revised$cells, revised$support, allocation,
      specification$branch, specification$method, specification$gamma)
    anova[[i + 1L]] <- summarise_stress_variant(allocation$revenue, design, FACTOR_COLS,
      specification$branch, allocation$gap)

    if (specification$branch == "B3_foreign_gamma_1") {
      # The extra factor is a conditional adjustment to the distributional
      # branch. It has no effect at x1 = 0 by construction.
      expanded <- bind_rows(
        mutate(baseline$revenue, x6_globe_purge = 0L),
        mutate(allocation$revenue, x6_globe_purge = 1L)
      ) |>
        mutate(scenario_id = paste0(scenario_id, x6_globe_purge))
      factors <- c(FACTOR_COLS, "x6_globe_purge")
      expanded_design <- distinct(expanded, scenario_id, across(all_of(factors)))
      expanded_anova <- summarise_stress_variant(expanded, expanded_design, factors,
        "expanded_explicit_globe_purge_gamma_1", max(baseline$gap, allocation$gap))
    }
  }
  comparison <- bind_rows(metrics)
  differences <- comparison |>
    filter(branch == "B1_baseline") |>
    select(scenario_id, scope, window, low_share, topup_gap, liability_rate,
      qdmtt_annualised_eur_bn, collector_annualised_eur_bn) |>
    rename_with(~ paste0("baseline_", .x), -c(scenario_id, scope, window))
  comparison <- comparison |>
    left_join(differences, by = c("scenario_id", "scope", "window"), relationship = "many-to-one") |>
    mutate(
      low_share_change_pp = 100 * (low_share - baseline_low_share),
      topup_gap_change_pp = 100 * (topup_gap - baseline_topup_gap),
      liability_rate_change_pp = 100 * (liability_rate - baseline_liability_rate),
      qdmtt_change_annualised_eur_bn = qdmtt_annualised_eur_bn - baseline_qdmtt_annualised_eur_bn,
      collector_change_annualised_eur_bn =
        collector_annualised_eur_bn - baseline_collector_annualised_eur_bn
    )
  step8_write(anatomy, "nld_lux_irl_cell_anatomy")
  step8_write(step8_budget_comparisons(comparison), "bracket_dividend_purge_comparison")
  step8_write(inventory, "observed_profit_adj_all_cells")
  step8_write(bind_rows(bind_rows(anova), expanded_anova) |> select(-ppml_tau_floor),
    "anova_with_globe_dividend_purge")
}

if (is_direct_script_run("code/diagnostics_step8_conduit_globe_wedge.R")) {
  run_step8_diagnostics()
}
