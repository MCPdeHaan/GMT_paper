# Run from the repository root after Steps 8–11. Read production RDS files
# and write four diagnostic CSVs. All amounts are in USD unless labelled.
source("code/diagnostics_step8_conduit_globe_wedge.R", local = TRUE)
source("code/diagnostics_step9_bilateral_aggregation_ladder.R", local = TRUE)

BRIDGE_KEYS <- c("parent", "affiliate", "year")
BRIDGE_BUDGETS <- c("NLD", "LUX", "IRL", "DEU", "FRA", "BEL", "AUT", "SVK")
BRIDGE_SCENARIO <- "x10011"
BRIDGE_EUR_USD <- 1.0813
delayedAssign("BRIDGE_SAFE_YEARS", tibble(policy_year = 2024:2026, transition_etr = c(.15, .16, .17),
  sigma_payroll = c(.098, .096, .094), sigma_assets = c(.078, .076, .074)))
delayedAssign("BRIDGE_WINDOWS", c(list("2017–2023" = MAIN_YEARS, "2019–2023" = DIRECT_YEARS,
  "2021–2023" = PERCENTILE_YEARS), set_names(as.list(MAIN_YEARS), paste0("FY", MAIN_YEARS))))

bridge_read <- function(stem) readRDS(file.path(PROCESSED_DIR, paste0(stem, ".rds")))

bridge_scopes <- function(x, location) {
  x <- rename(x, scope = all_of(location))
  bind_rows(filter(x, scope %in% EU27_ISO3),
    mutate(filter(x, scope %in% EU27_ISO3), scope = "EU27"),
    mutate(x, scope = "Global"))
}

bridge_windows <- function(x, windows = BRIDGE_WINDOWS) {
  imap_dfr(windows, function(years, label) {
    filter(x, year %in% years) |> mutate(window = label, n_years = length(years))
  })
}

bridge_loss_stock <- function(net, positive_profit) {
  n <- length(net)
  opening <- additions <- used <- closing <- numeric(n)
  for (i in seq_len(n)) {
    opening[i] <- if (i == 1L) 0 else closing[i - 1L]
    additions[i] <- if (is.finite(net[i])) max(0, -net[i]) else 0
    used[i] <- min(opening[i], positive_profit[i])
    closing[i] <- opening[i] + additions[i] - used[i]
  }
  tibble(cf_opening = opening, cf_added = additions, cf_used = used, cf_closing = closing)
}

bridge_table1_loss <- function(base, table1) {
  raw <- table1 |>
    select(all_of(BRIDGE_KEYS), profit, profit_panelai, profit_panelaii,
      tot_rev, tot_rev_panelai, subgroups_count, subgroups_count_panelai,
      tax_accrued, tax_accrued_panelai, tax_accrued_panelaii,
      tax_paid, tax_paid_panelai, tax_paid_panelaii)
  assert_unique_keys(raw, BRIDGE_KEYS, "Table I loss and tax observations")
  base |>
    transmute(across(all_of(BRIDGE_KEYS)), corrected_profit = pmax(coalesce_zero(analysis_profit_base), 0)) |>
    left_join(raw, by = BRIDGE_KEYS, relationship = "one-to-one") |>
    mutate(
      # Panel A is the net reported total. A-I and A-II are the positive
      # and negative subgroup populations. Prefer the reported total.
      reconstructed_net = if_else(profit_panelai >= 0 & profit_panelaii <= 0,
        profit_panelai + profit_panelaii, NA_real_),
      net_profit = coalesce(profit, reconstructed_net),
      net_source = case_when(
        is.finite(profit) ~ "reported_panel_a",
        is.finite(reconstructed_net) ~ "panel_ai_plus_aii",
        TRUE ~ "unobserved"
      ),
      loss_ratio = if_else(profit_panelai > 0 & is.finite(net_profit),
        clamp_unit_interval(1 - pmax(0, net_profit) / profit_panelai), NA_real_),
      raw_positive_loss_offset = profit_panelai * loss_ratio,
      corrected_current = corrected_profit * (1 - coalesce_zero(loss_ratio))
    ) |>
    arrange(parent, affiliate, year) |>
    group_by(parent, affiliate) |>
    mutate(bridge_loss_stock(net_profit, corrected_current)) |>
    ungroup() |>
    mutate(corrected_with_cf = corrected_current - cf_used,
      dta_used_at_floor = GMT_RATE * cf_used)
}

bridge_table4_loss <- function(table4) {
  table4 |>
    filter(year %in% DIRECT_YEARS) |>
    summarise(
      positive_partition = sum_or_na(pmax(0, profit[etr_bracket %in% T4_POSITIVE_BRACKETS])),
      negative_bracket = sum_or_na(profit[etr_bracket == "negative_profit" & profit < 0]),
      .by = all_of(BRIDGE_KEYS)
    ) |>
    mutate(net_table4_profit = positive_partition + negative_bracket,
      loss_ratio_table4 = if_else(positive_partition > 0 & is.finite(negative_bracket),
        pmin(1, abs(negative_bracket) / positive_partition), NA_real_),
      positive_loss_offset_table4 = positive_partition * loss_ratio_table4)
}

bridge_preferred_input <- function() {
  bridge_read("stage3_factorial_pair_year") |>
    filter(scenario_id == BRIDGE_SCENARIO) |>
    select(all_of(SCENARIO_VARS), all_of(BRIDGE_KEYS), parent_jurisdiction_name, affiliate_jurisdiction_name,
      affiliate_is_conduit_haven, employees_sbie, assets_sbie, act_ip_panelai, act_holding_panelai,
      act_igf_panelai, analysis_profit_positive, stage2_sbie, stage2_phi,
      average_low_share, stage1_lowtax_profit_average, stage2_excess_lowtax_profit_average,
      qdmtt_flag, sbs_exempt, parent_iir_utpr_flag, topup_after_behaviour)
}

bridge_measure <- function(spine, profit, share, gap) {
  tibble(parent = spine$parent, affiliate = spine$affiliate, year = spine$year,
    corrected_profit = profit, share, gap,
    low_profit = profit * coalesce_zero(share),
    stage1_topup = profit * coalesce_zero(share) * coalesce_zero(gap))
}

bridge_behaviour <- function(spine, measure, beta, scope = "host") {
  panel <- select(spine, -analysis_profit_positive) |>
    left_join(measure, by = BRIDGE_KEYS, relationship = "one-to-one") |>
    mutate(
      analysis_profit_positive = corrected_profit,
      stage1_distributional_low_share = share,
      stage1_lowtax_profit_distributional = low_profit,
      stage2_phi = compute_phi_ratio(stage2_sbie, corrected_profit),
      stage2_excess_lowtax_profit_distributional = low_profit * (1 - coalesce_zero(stage2_phi)),
      stage2_topup = stage1_topup * (1 - coalesce_zero(stage2_phi)),
      topup_after_stage2 = stage2_topup,
      behavioural_gap = gap
    )
  if (scope == "host") {
    panel <- panel |>
      mutate(behavioural_gap = safe_divide(sum(stage1_topup), sum(low_profit)),
        .by = c(affiliate, year))
  }
  tau <- if_else(panel$behavioural_gap > 0, GMT_RATE - panel$behavioural_gap, NA_real_)
  tau[!is.finite(tau)] <- NA_real_
  replace_behaviour_schedule(panel, tau,
    coalesce_zero(compute_reallocation_share(tau, rep_len("linear", nrow(panel)), beta)))
}

bridge_allocate <- function(panel, weights) {
  source <- build_source_panel(panel)
  channels <- allocate_stage4_revenue(source, weights)$revenue_by_channel_global
  checks <- build_conservation_diagnostics(source, channels)
  revenue <- channels |>
    summarise(collector = sum(revenue), qdmtt = sum(revenue[channel == "QDMTT"]),
      iir = sum(revenue[channel == "IIR"]), utpr = sum(revenue[channel == "UTPR"]),
      .by = c(country, year))
  spine <- tidyr::expand_grid(country = union(EU27_ISO3, revenue$country), year = MAIN_YEARS)
  list(source = source,
    revenue = left_join(spine, revenue, by = c("country", "year"), relationship = "one-to-one") |>
      mutate(across(c(collector, qdmtt, iir, utpr), coalesce_zero)),
    max_conservation_gap_usd = max(abs(checks$residual_gap)))
}

bridge_summarise <- function(result, windows = BRIDGE_WINDOWS) {
  source <- result$source |>
    bridge_scopes("affiliate") |>
    bridge_windows(windows) |>
    summarise(
      corrected_profit = sum(corrected_profit), low_profit = sum(low_profit),
      stage1_topup = sum(stage1_topup), stage2_topup = sum(stage2_topup),
      source_topup = sum(topup_after_behaviour),
      source_sbs_extinguished = sum(stage4_sbs_extinguished_liability),
      .by = c(scope, window, n_years)
    )
  collectors <- result$revenue |>
    bridge_scopes("country") |>
    bridge_windows(windows) |>
    summarise(across(c(collector, qdmtt, iir, utpr), sum), .by = c(scope, window, n_years))
  full_join(source, collectors, by = c("scope", "window", "n_years"), relationship = "one-to-one") |>
    mutate(
      low_share = safe_divide(low_profit, corrected_profit),
      topup_gap = safe_divide(stage1_topup, low_profit),
      liability_rate = safe_divide(stage1_topup, corrected_profit),
      across(c(collector, qdmtt, iir, utpr), ~ .x / (n_years * BRIDGE_EUR_USD * 1e9),
        .names = "{.col}_annualised_eur_bn"),
      max_conservation_gap_usd = result$max_conservation_gap_usd
    )
}

bridge_loss_records <- function(loss, t4_loss, runs) {
  detail <- loss |>
    left_join(t4_loss, by = BRIDGE_KEYS, relationship = "one-to-one")
  paired <- detail |>
    filter(year %in% MAIN_YEARS) |>
    mutate(pair = paste(parent, affiliate, sep = "/")) |>
    bridge_scopes("affiliate") |>
    bridge_windows() |>
    summarise(
      positive_cells = sum(corrected_profit > 0),
      measured_cells = sum(corrected_profit > 0 & is.finite(loss_ratio)),
      measured_corrected_profit = sum(corrected_profit[is.finite(loss_ratio)]),
      gross_reported_positive_profit = sum(profit_panelai[is.finite(loss_ratio)], na.rm = TRUE),
      raw_positive_loss_offset = sum(raw_positive_loss_offset, na.rm = TRUE),
      net_negative_cells = sum(net_profit < 0, na.rm = TRUE),
      panel_a_ai_aii_overlap = sum(is.finite(profit) & is.finite(reconstructed_net)),
      panel_a_identity_difference = sum(profit - reconstructed_net, na.rm = TRUE),
      panel_a_nonadditive_cells = sum(abs(profit - reconstructed_net) > 1, na.rm = TRUE),
      current_loss_reduction = sum(corrected_profit - corrected_current),
      cf_pairs_using = n_distinct(pair[cf_used > 0]),
      cf_used_cells = sum(cf_used > 0),
      cf_added = sum(cf_added), cf_used = sum(cf_used),
      dta_used_at_floor = sum(dta_used_at_floor),
      .by = c(scope, window, n_years)
    )
  iv <- t4_loss |>
    bridge_scopes("affiliate") |>
    bridge_windows() |>
    summarise(
      matched_partitions = sum(is.finite(loss_ratio_table4)),
      positive_partition = sum(positive_partition[is.finite(loss_ratio_table4)]),
      negative_bracket = sum(negative_bracket[is.finite(loss_ratio_table4)]),
      net_table4_profit = sum(net_table4_profit[is.finite(loss_ratio_table4)]),
      positive_loss_offset_table4 = sum(positive_loss_offset_table4, na.rm = TRUE),
      .by = c(scope, window, n_years)
    ) |>
    mutate(loss_ratio_table4 = safe_divide(positive_loss_offset_table4, positive_partition))
  summary <- imap_dfr(runs, ~ mutate(bridge_summarise(.x), adjustment = .y)) |>
    mutate(
      across(c(corrected_profit, low_profit, stage1_topup, qdmtt, collector),
        ~ .x - .x[adjustment == "baseline"], .names = "{.col}_change_vs_baseline"),
      .by = c(scope, window)
    )
  bind_rows(
    mutate(summary, record_type = "allocation_summary"),
    mutate(paired, record_type = "table1_loss_summary"),
    mutate(iv, record_type = "table4_loss_summary"),
    mutate(detail, record_type = "bilateral_cell"),
    mutate(anti_join(t4_loss, loss, by = BRIDGE_KEYS), record_type = "table4_only_cell")
  )
}

bridge_tax <- function(accrued, cash, numerator) {
  switch(numerator, T1_accrued = accrued, T2_cash = coalesce(cash, accrued),
    T3_envelope = pmax(accrued, cash, na.rm = TRUE))
}

bridge_tax_rates <- function(stage1, host, table4, bilateral_brackets, numerator) {
  if (numerator == "T1_accrued") {
    return(list(stage1 = stage1, host = host,
      partitions = step8_table4_partitions(table4)))
  }
  switched_t4 <- mutate(table4, tax_accrued = bridge_tax(tax_accrued, tax_paid, numerator))
  exact <- mutate(bilateral_brackets, tax_accrued = bridge_tax(tax_accrued, tax_paid, numerator))
  donor <- stage1 |>
    mutate(
      tax_variant = bridge_tax(tax_accrued_panelai, tax_paid_panelai, numerator),
      variant_raw_etr = safe_divide(tax_variant, analysis_profit_positive),
      cap = pmin(1, coalesce(affiliate_cit_top_all_unit, affiliate_cit_standard_unit,
        1 - ZETA_LOSS_OFFSET) + ZETA_LOSS_OFFSET),
      etr_panelai_stage1 = if_else(variant_raw_etr < -ZETA_LOSS_OFFSET,
        NA_real_, pmin(cap, pmax(0, variant_raw_etr)))
    )
  host_tax <- donor |>
    filter(profit_panelai > 0, analysis_profit_positive > 0) |>
    summarise(tax_variant = sum(tax_variant, na.rm = TRUE), .by = c(affiliate, year))
  partitions <- step8_table4_partitions(switched_t4)
  pool <- partitions |>
    summarise(variant_direct_low_tax = sum(t4_low_tax, na.rm = TRUE),
      .by = c(affiliate, year))
  anchors <- host |>
    left_join(pool, by = c("affiliate", "year"), relationship = "one-to-one") |>
    filter(year %in% BSPI_ANCHOR_YEARS, direct_has_partition %in% TRUE) |>
    summarise(anchor_tax = sum(variant_direct_low_tax, na.rm = TRUE),
      anchor_low_profit = sum(direct_low_profit, na.rm = TRUE), .by = affiliate) |>
    mutate(anchor_gap = if_else(anchor_low_profit > 0, GMT_RATE -
      pmin(pmax(safe_divide(anchor_tax, anchor_low_profit), 0), GMT_RATE), 0))
  host <- host |>
    left_join(host_tax, by = c("affiliate", "year"), relationship = "one-to-one") |>
    left_join(pool, by = c("affiliate", "year"), relationship = "one-to-one") |>
    left_join(select(anchors, affiliate, anchor_gap), by = "affiliate", relationship = "many-to-one") |>
    mutate(
      avg_etr_stage1 = pmin(affiliate_etr_cap_stage1,
        pmax(0, safe_divide(tax_variant, avg_profit_denominator))),
      average_low_share = as.numeric(avg_etr_stage1 < GMT_RATE),
      average_topup_rate = pmax(0, GMT_RATE - avg_etr_stage1),
      direct_low_tax = coalesce(variant_direct_low_tax, direct_low_tax),
      direct_topup_rate = if_else(direct_low_profit > 0,
        GMT_RATE - pmin(pmax(safe_divide(direct_low_tax, direct_low_profit), 0), GMT_RATE), 0)
    )
  percentile <- host |>
    filter(is.finite(q5_raw), is.finite(avg_etr_stage1)) |>
    rowwise() |>
    mutate(
      q = list(c(q5_raw, q25_raw, q50_raw, q75_raw, q95_raw)),
      cap_fit = list(fit_constrained_beta_percentiles(q, avg_etr_stage1,
        upper_cap = affiliate_etr_cap_stage1)),
      boundary = if (isTRUE(cap_fit$boundary_flag)) cap_fit$mean else NA_real_,
      variant_share = beta_mass_below(cap_fit$alpha, cap_fit$beta, boundary_mean = boundary),
      variant_gap = beta_avg_topup_rate(cap_fit$alpha, cap_fit$beta, boundary_mean = boundary),
      variant_precision = stage1_fit_cell(q, avg_etr_stage1,
        affiliate_etr_cap_stage1, STAGE1_BETA_MODELS[3])$precision
    ) |>
    ungroup() |>
    select(affiliate, year, variant_share, variant_gap, variant_precision)
  host <- host |>
    left_join(percentile, by = c("affiliate", "year"), relationship = "one-to-one") |>
    mutate(
      stage1_distributional_low_share = case_when(
        stage1_distributional_source == "percentile_fit" ~ variant_share,
        stage1_distributional_source == "avg_only" ~ average_low_share,
        TRUE ~ stage1_distributional_low_share
      ),
      stage1_distributional_topup_rate = case_when(
        stage1_distributional_source == "direct_t4" ~ direct_topup_rate,
        stage1_distributional_source == "shape_transport" ~ anchor_gap,
        stage1_distributional_source == "percentile_fit" ~ variant_gap,
        stage1_distributional_source == "avg_only" ~ average_topup_rate
      ),
      percentile_beta_precision_rank_bounded = variant_precision
    )
  fields <- c("average_low_share", "average_topup_rate", "stage1_distributional_low_share",
    "stage1_distributional_topup_rate")
  updated <- donor |>
    select(-all_of(fields), -starts_with("ladder_l")) |>
    left_join(select(host, affiliate, year, all_of(fields)),
      by = c("affiliate", "year"), relationship = "many-to-one") |>
    add_stage1_ladder_columns(host, exact)
  list(stage1 = updated, host = host, partitions = partitions)
}

bridge_tax_records <- function(table1, table4, results) {
  audit <- bind_rows(
    transmute(table1, across(all_of(BRIDGE_KEYS)), panel = "Table I A",
      profit, accrued = tax_accrued, cash = tax_paid),
    transmute(table1, across(all_of(BRIDGE_KEYS)), panel = "Table I A-I",
      profit = profit_panelai, accrued = tax_accrued_panelai, cash = tax_paid_panelai),
    transmute(table1, across(all_of(BRIDGE_KEYS)), panel = "Table I A-II",
      profit = profit_panelaii, accrued = tax_accrued_panelaii, cash = tax_paid_panelaii),
    transmute(table4, across(all_of(BRIDGE_KEYS)), panel = paste("Table IV", etr_bracket),
      profit, accrued = tax_accrued, cash = tax_paid)
  ) |>
    filter(year %in% MAIN_YEARS) |>
    mutate(paired = is.finite(accrued) & is.finite(cash),
      valid_positive_profit = paired & is.finite(profit) & profit > 0) |>
    bridge_scopes("affiliate") |>
    bridge_windows() |>
    summarise(
      cells = n(), paired_tax_cells = sum(paired),
      cash_missing_cells = sum(!is.finite(cash)),
      accrued_fallback_cells = sum(is.finite(accrued) & !is.finite(cash)),
      paired_positive_profit_cells = sum(valid_positive_profit),
      paired_positive_profit = sum(profit[valid_positive_profit]),
      accrued_paired = sum(accrued[paired]), cash_paired = sum(cash[paired]),
      accrued_positive_profit = sum(accrued[valid_positive_profit]),
      cash_positive_profit = sum(cash[valid_positive_profit]),
      envelope_positive_profit = sum(pmax(accrued, cash)[valid_positive_profit]),
      cash_exceeds_accrued_cells = sum(valid_positive_profit & cash > accrued, na.rm = TRUE),
      zero_accrual_positive_cash_cells = sum(valid_positive_profit & accrued == 0 & cash > 0, na.rm = TRUE),
      cash_etr_at_least_15_cells = sum(valid_positive_profit & cash >= GMT_RATE * profit, na.rm = TRUE),
      .by = c(scope, window, n_years, panel)
    ) |>
    mutate(record_type = "tax_numerator_audit",
      accrued_etr_paired_positive_profit = safe_divide(accrued_positive_profit, paired_positive_profit),
      cash_etr_paired_positive_profit = safe_divide(cash_positive_profit, paired_positive_profit))
  results <- results |>
    mutate(
      across(c(low_profit, stage1_topup, qdmtt, collector),
        ~ .x - .x[numerator == "T1_accrued"], .names = "{.col}_change_vs_baseline"),
      .by = c(scope, window, ladder)
    )
  bind_rows(mutate(results, record_type = "allocation_summary"), audit)
}

bridge_forecasts <- function() {
  read_csv(file.path(DIAGNOSTICS_DIR, "step9_ladder_budget_backtest.csv"), show_col_types = FALSE) |>
    filter(level == LADDER_LEVELS[3], window == "FY2023", country %in% BRIDGE_BUDGETS,
      is.finite(official_low_eur_bn), evidence != "academic estimate",
      !grepl("more than direct top-up", comparison_scope)) |>
    select(country, benchmark, forecast_period, revenue_scope, model_scope, official_low_eur_bn,
      official_high_eur_bn, stated_sbs_switch, comparison_scope, source_url) |>
    rename(scope = country) |>
    mutate(source_url = if_else(scope == "LUX",
      "https://igf.gouvernement.lu/dam-assets/fr/dossiers/budget-de-l-etat/loi-votee/budget-de-letat-2026.pdf",
      source_url))
}

bridge_safe_sbie <- function(employees, assets, wage, policy) {
  payroll <- if_else(employees == 0, 0, employees * wage)
  if_else(employees >= 0 & assets >= 0 & is.finite(payroll),
    compute_sbie_value(payroll, assets, policy$sigma_payroll, policy$sigma_assets), NA_real_)
}

bridge_safe_tests <- function(data, policy, basis, numerator, t4_low) {
  keys <- BRIDGE_KEYS
  if (basis == "table4_low_bracket") {
    x <- data |>
      select(all_of(keys), affiliate_wage_annual) |>
      inner_join(t4_low, by = keys, relationship = "one-to-one") |>
      transmute(across(all_of(keys)), test_profit = profit, test_revenue = tot_rev,
        test_subgroups = subgroups_count, test_tax = bridge_tax(tax_accrued, tax_paid, numerator),
        test_sbie = bridge_safe_sbie(employees, assets, affiliate_wage_annual, policy))
  } else {
    x <- data |>
      transmute(across(all_of(keys)),
        test_profit = if (basis == "panel_a_net") net_profit else profit_panelai,
        test_revenue = if (basis == "panel_a_net") tot_rev else tot_rev_panelai,
        test_subgroups = if (basis == "panel_a_net") subgroups_count else subgroups_count_panelai,
        test_tax = if (basis == "panel_a_net") bridge_tax(tax_accrued, tax_paid, numerator)
          else bridge_tax(tax_accrued_panelai, tax_paid_panelai, numerator),
        test_sbie = if (basis == "panel_a_net") {
          bridge_safe_sbie(employees_a_screen, assets, affiliate_wage_annual, policy)
        } else {
          bridge_safe_sbie(employees_ai_screen, assets_panelai, affiliate_wage_annual, policy)
        })
  }
  x |>
    mutate(
      simplified_etr = if_else(test_profit > 0, safe_divide(test_tax, test_profit), NA_real_),
      de_minimis = if_else(test_revenue >= 0 & test_subgroups > 0,
        test_revenue / test_subgroups < 10e6 * BRIDGE_EUR_USD &
          test_profit / test_subgroups < 1e6 * BRIDGE_EUR_USD, NA),
      profit_only_1m_usd = if_else(test_subgroups > 0, test_profit / test_subgroups < 1e6, NA),
      routine = test_profit <= 0 | test_sbie >= test_profit,
      simplified = simplified_etr >= policy$transition_etr,
      any_pass = coalesce(de_minimis, FALSE) | coalesce(routine, FALSE) | coalesce(simplified, FALSE),
      missing_test_inputs = is.na(de_minimis) | is.na(routine) |
        (is.na(simplified) & (is.na(test_profit) | test_profit > 0)),
      policy_year = policy$policy_year, transition_etr = policy$transition_etr,
      basis, test_numerator = numerator
    )
}

bridge_safe_summary <- function(tests, result, windows) {
  keys <- BRIDGE_KEYS
  result$source |>
    select(all_of(keys), topup_after_behaviour, stage4_qdmtt_liability,
      stage4_sbs_extinguished_liability) |>
    left_join(tests, by = keys, relationship = "one-to-one") |>
    bridge_scopes("affiliate") |>
    bridge_windows(windows) |>
    summarise(
      exposed_positive_cells = sum(topup_after_behaviour > 0),
      positive_cells_passing = sum(topup_after_behaviour > 0 & any_pass, na.rm = TRUE),
      pre_allocation_topup = sum(topup_after_behaviour),
      reported_single_subgroup_topup = sum(topup_after_behaviour[test_subgroups %in% 1]),
      any_pass_single_subgroup_topup = sum(topup_after_behaviour[any_pass %in% TRUE & test_subgroups %in% 1]),
      source_missing_any_test = sum(topup_after_behaviour[missing_test_inputs %in% TRUE | is.na(any_pass)]),
      de_minimis_source_topup = sum(topup_after_behaviour[de_minimis %in% TRUE]),
      profit_only_1m_usd_source_topup = sum(topup_after_behaviour[profit_only_1m_usd %in% TRUE]),
      routine_source_topup = sum(topup_after_behaviour[routine %in% TRUE]),
      simplified_etr_source_topup = sum(topup_after_behaviour[simplified %in% TRUE]),
      any_pass_source_topup = sum(topup_after_behaviour[any_pass %in% TRUE]),
      any_pass_qdmtt = sum(stage4_qdmtt_liability[any_pass %in% TRUE]),
      any_pass_already_sbs_extinguished = sum(stage4_sbs_extinguished_liability[any_pass %in% TRUE]),
      .by = c(scope, window, n_years)
    ) |>
    mutate(
      record_type = "safe_harbour_test_summary",
      share_source_passing = safe_divide(any_pass_source_topup, pre_allocation_topup),
      policy_year = first(tests$policy_year), transition_etr = first(tests$transition_etr),
      basis = first(tests$basis), test_numerator = first(tests$test_numerator)
    )
}

bridge_apply_safe <- function(result, tests, weights, keep_qdmtt = FALSE, include_etr = TRUE) {
  panel <- result$source |>
    select(-any_of(c("de_minimis", "routine", "simplified"))) |>
    left_join(select(tests, all_of(BRIDGE_KEYS), de_minimis, routine, simplified),
      by = BRIDGE_KEYS, relationship = "one-to-one") |>
    mutate(
      proxy_pass = coalesce(de_minimis, FALSE) | coalesce(routine, FALSE) |
        (include_etr & coalesce(simplified, FALSE)),
      apply_safe = proxy_pass & !(keep_qdmtt & qdmtt_flag),
      topup_after_behaviour = if_else(apply_safe, 0, topup_after_behaviour)
    )
  bridge_allocate(panel, weights)
}

bridge_waterfall <- function(combined, baseline, safe_inputs, t4_low, weights, forecasts) {
  windows <- BRIDGE_WINDOWS[c("FY2023", "2021–2023", "2019–2023", "2017–2023")]
  baseline_stats <- bridge_summarise(baseline, windows)
  screening <- list()
  safe_runs <- list()
  for (i in seq_len(nrow(BRIDGE_SAFE_YEARS))) {
    policy <- BRIDGE_SAFE_YEARS[i, ]
    for (basis in c("panel_a_net", "panel_ai_positive", "table4_low_bracket")) {
      for (numerator in c("T1_accrued", "T3_envelope")) {
        tests <- bridge_safe_tests(safe_inputs, policy, basis, numerator, t4_low)
        screened <- bridge_apply_safe(baseline, tests, weights)
        after <- bridge_summarise(screened, windows) |>
          select(scope, window, post_screen_qdmtt = qdmtt, post_screen_collector = collector) |>
          left_join(select(baseline_stats, scope, window, qdmtt, collector),
            by = c("scope", "window"), relationship = "one-to-one") |>
          mutate(
            collector_removed_by_screen = collector - post_screen_collector,
            qdmtt_removed_by_screen = qdmtt - post_screen_qdmtt
          )
        label <- paste(policy$policy_year, basis, numerator)
        screening[[label]] <- bridge_safe_summary(tests, baseline, windows) |>
          left_join(after, by = c("scope", "window"), relationship = "one-to-one")
        if (basis == "panel_a_net" && numerator == "T3_envelope") {
          before <- combined[["04_envelope_tax"]]
          safe_runs[[paste0("05_safe_harbour_", policy$policy_year)]] <-
            bridge_apply_safe(before, tests, weights)
          if (policy$policy_year == 2026) {
            safe_runs[["05_safe_harbour_2026_preserve_qdmtt"]] <-
              bridge_apply_safe(before, tests, weights, keep_qdmtt = TRUE)
            safe_runs[["05_safe_harbour_2026_without_etr_test"]] <-
              bridge_apply_safe(before, tests, weights, include_etr = FALSE)
            screening[["2026 cumulative test incidence"]] <-
              bridge_safe_summary(tests, before, windows) |>
              mutate(record_type = "cumulative_safe_harbour_test_summary")
          }
        }
      }
    }
  }
  steps <- imap_dfr(c(combined, safe_runs), ~ mutate(bridge_summarise(.x, windows), step = .y)) |>
    group_by(scope, window) |>
    mutate(
      dividend_method = if_else(step == "00_baseline", NA_character_, "Step 8 reporter pool, gamma = 1"),
      loss_method = case_when(
        step %in% c("00_baseline", "01_step8_dividends") ~ "none",
        step == "02_current_losses" ~ "current Panel A netting",
        TRUE ~ "Panel A netting plus pair carryforward as a base deduction"
      ),
      policy_year = as.integer(if_else(startsWith(step, "05_"), substr(step, 17, 20), NA_character_)),
      transition_etr = BRIDGE_SAFE_YEARS$transition_etr[match(policy_year, BRIDGE_SAFE_YEARS$policy_year)],
      test_numerator = if_else(startsWith(step, "05_"), "T3_envelope", NA_character_),
      basis = if_else(startsWith(step, "05_"), "panel_a_net", NA_character_),
      prior_step = if_else(startsWith(step, "05_"), "04_envelope_tax", lag(step)),
      prior_collector = collector[match(prior_step, step)],
      prior_qdmtt = qdmtt[match(prior_step, step)],
      collector_change_from_prior = collector - prior_collector,
      qdmtt_change_from_prior = qdmtt - prior_qdmtt,
      collector_change_from_baseline = collector - first(collector),
      qdmtt_change_from_baseline = qdmtt - first(qdmtt)
    ) |>
    ungroup()
  backtest <- steps |>
    inner_join(forecasts, by = "scope", relationship = "many-to-many") |>
    mutate(
      comparable_annualised_eur_bn = case_when(
        model_scope == "qdmt" ~ qdmtt_annualised_eur_bn,
        model_scope == "iir" ~ iir_annualised_eur_bn,
        TRUE ~ collector_annualised_eur_bn
      ),
      gap_vs_official_eur_bn = comparable_annualised_eur_bn -
        (official_low_eur_bn + official_high_eur_bn) / 2,
      model_to_official = safe_divide(comparable_annualised_eur_bn,
        (official_low_eur_bn + official_high_eur_bn) / 2),
      record_type = "budget_comparison"
    )
  bind_rows(mutate(steps, record_type = "waterfall"), backtest, bind_rows(screening))
}

bridge_trend <- function(result, forecasts) {
  selected <- result$source |>
    filter(affiliate %in% c("NLD", "LUX", "IRL", "CYP", "HUN", "DEU", "FRA", "BEL")) |>
    mutate(pair_requested = (parent == "USA" & affiliate %in% c("NLD", "LUX", "IRL")) |
      (parent == affiliate & affiliate %in% c("NLD", "LUX")))
  observed <- bind_rows(mutate(selected, parent = "ALL"), filter(selected, pair_requested)) |>
    summarise(
      corrected_profit = sum(corrected_profit), low_profit = sum(low_profit),
      stage1_topup = sum(stage1_topup), qdmtt = sum(stage4_qdmtt_liability),
      .by = c(parent, affiliate, year)
    ) |>
    left_join(select(result$revenue, affiliate = country, year, collector),
      by = c("affiliate", "year"), relationship = "many-to-one") |>
    mutate(collector = if_else(parent == "ALL", collector, NA_real_))
  measures <- c("corrected_profit", "low_profit", "stage1_topup", "qdmtt", "collector")
  annual <- observed |>
    group_by(parent, affiliate) |>
    complete(year = MAIN_YEARS) |>
    ungroup() |>
    mutate(observed_cell = is.finite(corrected_profit), record_type = "annual_observation",
      period = as.character(year))
  means <- bind_rows(mutate(filter(annual, year <= 2020L), period = "2017–2020"),
    mutate(annual, period = "2017–2023")) |>
    summarise(across(all_of(measures), ~ if (all(is.finite(.x))) mean(.x) else NA_real_),
      years_observed = sum(observed_cell), .by = c(parent, affiliate, period)) |>
    mutate(record_type = "historical_mean")
  fit <- function(y, year) {
    valid <- is.finite(y)
    if (sum(valid) >= 3L && all(y[valid] > 0)) {
      model <- lm(log(y) ~ year, data = data.frame(y = y[valid], year = year[valid]))
      pred <- predict(model, newdata = data.frame(year = 2026), interval = "prediction")
      return(tibble(value = exp(pred[1, "fit"]), annual_growth = expm1(coef(model)[[2]]),
        prediction_low = exp(pred[1, "lwr"]), prediction_high = exp(pred[1, "upr"]),
        n_observations = sum(valid), method = "log_linear"))
    }
    if (sum(valid) >= 3L && all(y[valid] == 0)) {
      return(tibble(value = 0, annual_growth = NA_real_, prediction_low = NA_real_,
        prediction_high = NA_real_, n_observations = sum(valid), method = "observed_all_zero"))
    }
    tibble(value = NA_real_, annual_growth = NA_real_, prediction_low = NA_real_,
      prediction_high = NA_real_, n_observations = sum(valid), method = "insufficient_positive_values")
  }
  projections <- map_dfr(c(2021L, 2020L), function(start) {
    annual |>
      filter(year >= start) |>
      pivot_longer(all_of(measures), names_to = "outcome", values_to = "observed_value") |>
      reframe(fit(observed_value, year), .by = c(parent, affiliate, outcome)) |>
      mutate(record_type = "trend_fit", year = 2026L, period = paste0("2026 fit from ", start),
        trend_start = start, trend_end = 2023L)
  })
  predicted <- projections |>
    select(parent, affiliate, year, period, trend_start, outcome, value) |>
    pivot_wider(names_from = outcome, values_from = value) |>
    mutate(record_type = "trend_projection")
  metrics <- bind_rows(annual, means, predicted) |>
    mutate(low_share = safe_divide(low_profit, corrected_profit), topup_gap = safe_divide(stage1_topup, low_profit),
      ratio_outside_model_support = coalesce(low_share > 1 + 1e-10 | topup_gap > GMT_RATE + 1e-10, FALSE),
      qdmtt_eur_bn = qdmtt / BRIDGE_EUR_USD / 1e9, collector_eur_bn = collector / BRIDGE_EUR_USD / 1e9)
  anchors <- filter(metrics, period == "2017–2023") |>
    transmute(parent, affiliate, anchor_low_profit = low_profit,
      anchor_qdmtt_eur_bn = qdmtt_eur_bn,
      anchor_qdmtt_per_low_profit = safe_divide(qdmtt_eur_bn, low_profit))
  qdmtt_bridge <- metrics |>
    filter(period %in% c("2018", "2021", "2022", "2023", "2026 fit from 2021", "2026 fit from 2020")) |>
    inner_join(anchors, by = c("parent", "affiliate"), relationship = "many-to-one") |>
    mutate(
      qdmtt_per_low_profit = safe_divide(qdmtt_eur_bn, low_profit),
      # Symmetric two-factor decomposition of QDMTT = low profit times
      # QDMTT per unit of low profit. The second term combines the gap,
      # SBIE, behaviour and the share of liability routed to QDMTT.
      low_profit_component_eur_bn = (low_profit - anchor_low_profit) *
        (qdmtt_per_low_profit + anchor_qdmtt_per_low_profit) / 2,
      qdmtt_intensity_component_eur_bn = (qdmtt_per_low_profit - anchor_qdmtt_per_low_profit) *
        (low_profit + anchor_low_profit) / 2,
      qdmtt_change_eur_bn = qdmtt_eur_bn - anchor_qdmtt_eur_bn,
      record_type = "qdmtt_trend_decomposition"
    )
  stopifnot(all(abs(qdmtt_bridge$low_profit_component_eur_bn +
    qdmtt_bridge$qdmtt_intensity_component_eur_bn - qdmtt_bridge$qdmtt_change_eur_bn) < 1e-8,
    na.rm = TRUE))
  budgets <- metrics |>
    filter(parent == "ALL", period %in% c("2017–2023", "2023", "2026 fit from 2021", "2026 fit from 2020")) |>
    inner_join(forecasts, by = c("affiliate" = "scope"), relationship = "many-to-many") |>
    filter(model_scope %in% c("direct", "qdmt")) |>
    mutate(comparable_eur_bn = if_else(model_scope == "qdmt", qdmtt_eur_bn, collector_eur_bn),
      budget_midpoint_eur_bn = (official_low_eur_bn + official_high_eur_bn) / 2,
      long_average_eur_bn = comparable_eur_bn[period == "2017–2023"],
      gap_vs_budget_eur_bn = comparable_eur_bn - budget_midpoint_eur_bn,
      decline_vs_long_average_eur_bn = long_average_eur_bn - comparable_eur_bn,
      fraction_of_original_positive_gap_closed = if_else(long_average_eur_bn > budget_midpoint_eur_bn,
        decline_vs_long_average_eur_bn / (long_average_eur_bn - budget_midpoint_eur_bn), NA_real_),
      .by = c(affiliate, benchmark)) |>
    mutate(record_type = "budget_gap")
  bind_rows(metrics, projections, qdmtt_bridge, budgets)
}

run_hanlon_globe_bridge <- function() {
  base <- bridge_read("base_panel")
  table1 <- bridge_read("cbcr_table1")
  table4 <- bridge_read("cbcr_table4")
  stage1 <- bridge_read("stage1_bilateral_panel")
  host <- bridge_read("stage1_affiliate_year")
  bilateral_t4 <- bridge_read("base_panel_t4_bilateral_bracket_shares")
  spine <- bridge_preferred_input()
  weights <- list(parent_year_weights = bridge_read("stage4_5_utpr_parent_year_weights"),
    fallback_weights = bridge_read("stage4_5_utpr_fallback_weights"))
  beta <- bridge_read("stage3_model_coefficients") |>
    filter(model_spec == "linear", term == "tau", inference == "parent_affiliate_clustered") |>
    pull(estimate)
  stopifnot(length(beta) == 1L, is.finite(beta), nrow(spine) == nrow(stage1))

  message("1/4 Panel A loss netting and loss stock")
  loss <- bridge_table1_loss(base, table1)
  stopifnot(all(loss$cf_used <= loss$cf_opening), all(loss$cf_used <= loss$corrected_current),
    all(loss$cf_closing >= 0), all(loss$corrected_with_cf >= 0))
  main_loss <- loss |>
    filter(year %in% MAIN_YEARS) |>
    select(all_of(BRIDGE_KEYS), net_profit, corrected_current, corrected_with_cf, cf_used)
  cells <- left_join(stage1, main_loss, by = BRIDGE_KEYS, relationship = "one-to-one")
  run <- function(profit, share, gap, scope = "host") {
    measure <- bridge_measure(cells, profit, share, gap)
    bridge_allocate(bridge_behaviour(spine, measure, beta, scope), weights)
  }
  loss_runs <- list(
    baseline = run(cells$analysis_profit_positive, cells$ladder_l3_low_share, cells$ladder_l3_topup_rate),
    current_losses = run(cells$corrected_current, cells$ladder_l3_low_share, cells$ladder_l3_topup_rate),
    current_and_prior_losses = run(cells$corrected_with_cf, cells$ladder_l3_low_share, cells$ladder_l3_topup_rate)
  )
  baseline <- loss_runs$baseline
  saved <- bridge_read("stage4_5_revenue_country_year") |>
    filter(scenario_id == BRIDGE_SCENARIO) |>
    select(country, year, saved = revenue)
  check <- inner_join(saved, baseline$revenue, by = c("country", "year"), relationship = "one-to-one")
  stopifnot(nrow(check) == length(EU27_ISO3) * length(MAIN_YEARS),
    max(abs(check$collector - check$saved)) < 1e-3)
  # Alternative to deducting CF from income. The Article 4.5-style proxy
  # credits a DTA at 15% and spreads it across the net positive cell.
  dta_gap <- pmax(0, cells$ladder_l3_topup_rate -
    coalesce_zero(safe_divide(GMT_RATE * cells$cf_used, cells$corrected_current)))
  loss_runs[["current_losses_with_dta_credit"]] <-
    run(cells$corrected_current, cells$ladder_l3_low_share, dta_gap)
  clean_t4 <- filter(table4, !affiliate %in% STEP8_AGGREGATES)
  raw_t4 <- filter(clean_t4, !parent %in% STEP8_AGGREGATES)
  loss_output <- bridge_loss_records(loss, bridge_table4_loss(raw_t4), loss_runs)
  # The source objects carry many columns and are only needed until summarised.
  rm(loss_runs)

  message("2/4 Cash, accrued and envelope tax numerators")
  numerator_names <- c("T1_accrued", "T2_cash", "T3_envelope")
  variants <- set_names(map(numerator_names, ~ bridge_tax_rates(stage1, host, clean_t4, bilateral_t4, .x)), numerator_names)
  branches <- c(L1_average = "l1", L3_pooled = "l3", L4_anchored = "l4_anchored", L4_strict = "l4_strict")
  tax_results <- imap_dfr(variants, function(variant, numerator) {
    stopifnot(identical(select(variant$stage1, all_of(BRIDGE_KEYS)), select(stage1, all_of(BRIDGE_KEYS))))
    imap_dfr(branches, function(level, ladder) {
      if (numerator == "T1_accrued" && ladder == "L3_pooled") {
        summary <- bridge_summarise(baseline)
      } else {
        summary <- run(cells$analysis_profit_positive,
          variant$stage1[[paste0("ladder_", level, "_low_share")]],
          variant$stage1[[paste0("ladder_", level, "_topup_rate")]],
          if (startsWith(ladder, "L4")) "bilateral" else "host") |>
          bridge_summarise()
      }
      mutate(summary, ladder, numerator,
        behaviour_scope = if_else(startsWith(ladder, "L4"), "bilateral", "host"))
    })
  })
  tax_output <- bridge_tax_records(filter(table1, !affiliate %in% STEP8_AGGREGATES,
    !parent %in% STEP8_AGGREGATES), raw_t4, tax_results)

  message("3/4 Dividend, loss, timing and transitional safe-harbour waterfall")
  # Reuse Step 8's reporter-pool purge at gamma=1. Existing domestic
  # correction is already in the Table I base. Apply the extra foreign
  # reduction before computing loss-stock use and keep positive bracket
  # taxes fixed when repricing the resulting low bracket.
  purge <- map(variants[c("T1_accrued", "T3_envelope")], ~
    step8_reconcile_rates(.x$stage1, base, .x$host, .x$partitions, 1, "reporter_pool")$cells)
  dividend <- purge$T1_accrued
  envelope <- purge$T3_envelope
  # The production bilateral base and OECD net-profit inventory also
  # include 2016 and cells with no positive profit in subsequent years.
  combined_loss <- loss |>
    left_join(select(dividend, all_of(BRIDGE_KEYS), revised_profit, foreign_removal),
      by = BRIDGE_KEYS, relationship = "one-to-one") |>
    mutate(corrected_after_dividends = coalesce(revised_profit, corrected_profit),
      dividend_current = corrected_after_dividends * (1 - coalesce_zero(loss_ratio))) |>
    group_by(parent, affiliate) |>
    mutate(bridge_loss_stock(net_profit, dividend_current)) |>
    ungroup() |>
    mutate(dividend_cf = dividend_current - cf_used) |>
    filter(year %in% MAIN_YEARS)
  combined_inputs <- select(cells, all_of(BRIDGE_KEYS)) |>
    left_join(select(combined_loss, all_of(BRIDGE_KEYS), corrected_after_dividends,
      dividend_current, dividend_cf), by = BRIDGE_KEYS, relationship = "one-to-one") |>
    left_join(select(dividend, all_of(BRIDGE_KEYS), accr_share = revised_share, accr_gap = revised_gap),
      by = BRIDGE_KEYS, relationship = "one-to-one") |>
    left_join(select(envelope, all_of(BRIDGE_KEYS), env_share = revised_share, env_gap = revised_gap),
      by = BRIDGE_KEYS, relationship = "one-to-one")
  stopifnot(all(abs(dividend$revised_profit - envelope$revised_profit) < 1e-3))
  combined <- list(
    "00_baseline" = baseline,
    "01_step8_dividends" = run(combined_inputs$corrected_after_dividends,
      combined_inputs$accr_share, combined_inputs$accr_gap),
    "02_current_losses" = run(combined_inputs$dividend_current,
      combined_inputs$accr_share, combined_inputs$accr_gap),
    "03_prior_loss_carryforward" = run(combined_inputs$dividend_cf,
      combined_inputs$accr_share, combined_inputs$accr_gap),
    "04_envelope_tax" = run(combined_inputs$dividend_cf,
      combined_inputs$env_share, combined_inputs$env_gap)
  )
  safe_inputs <- loss |>
    filter(year %in% MAIN_YEARS) |>
    left_join(select(base, all_of(BRIDGE_KEYS), employees, employees_panelai, assets, assets_panelai,
      employees_sbie_plausibility_cap, affiliate_wage_annual),
      by = BRIDGE_KEYS, relationship = "one-to-one") |>
    mutate(
      employees_a_screen = pmin(employees, coalesce(employees_sbie_plausibility_cap, Inf)),
      employees_ai_screen = pmin(employees_panelai, coalesce(employees_sbie_plausibility_cap, Inf))
    )
  low_bracket <- bilateral_t4 |>
    filter(etr_bracket == "rate_0_15", profit > 0) |>
    select(all_of(BRIDGE_KEYS), profit, tot_rev, subgroups_count, tax_accrued, tax_paid, employees, assets)
  forecasts <- bridge_forecasts()
  waterfall <- bridge_waterfall(combined, baseline, safe_inputs, low_bracket, weights, forecasts)
  stopifnot(all(waterfall$max_conservation_gap_usd[!is.na(waterfall$max_conservation_gap_usd)] < 1e-3),
    all(waterfall$collector_change_from_prior[startsWith(waterfall$step, "05_") &
      !is.na(waterfall$collector_change_from_prior)] <= 1e-3))

  message("4/4 Conduit time series and conditional 2026 extrapolation")
  time_series <- bridge_trend(baseline, forecasts)
  write_csv(loss_output, file.path(DIAGNOSTICS_DIR, "step12_loss_netting_and_carryforward_bridge.csv"))
  write_csv(tax_output, file.path(DIAGNOSTICS_DIR, "step12_tax_paid_vs_accrued_bridge.csv"))
  write_csv(waterfall, file.path(DIAGNOSTICS_DIR, "step12_cbcr_to_budget_waterfall_bridge.csv"))
  write_csv(time_series, file.path(DIAGNOSTICS_DIR, "step12_conduit_unwinding_time_series_2017_2026.csv"))
  message("Step 12 wrote four diagnostic CSVs. Production baseline replay difference: USD ",
    format(max(abs(check$collector - check$saved)), scientific = TRUE))
  invisible(list(loss = loss_output, tax = tax_output, waterfall = waterfall, trend = time_series))
}

if (is_direct_script_run("code/diagnostics_step12_hanlon_globe_bridge.R")) {
  run_hanlon_globe_bridge()
}
