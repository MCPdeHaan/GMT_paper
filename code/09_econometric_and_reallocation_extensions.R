# Division bias, induced ordinary CIT, destination rules and budget forecasts.

source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "01_data_cleaning.R"), local = TRUE)
source(file.path(GMT_PROJECT_ROOT, "code", "05_stage3_behavioral.R"), local = TRUE)
source(file.path(GMT_PROJECT_ROOT, "code", "06_stage4_5_revenue_allocation_sbs.R"), local = TRUE)
source(file.path(GMT_PROJECT_ROOT, "code", "07_stage4_6_revenue_pipeline_decomposition.R"), local = TRUE)
source(file.path(GMT_PROJECT_ROOT, "code", "08_measurement_and_cbcr_extensions.R"), local = TRUE)

# Tax-rate endogeneity and induced ordinary CIT recovery

read_step6_input <- function(stem) readRDS(file.path(PROCESSED_DIR, paste0(stem, ".rds")))

write_step6_diagnostic <- function(data, stem) {
  write_csv(data, file.path(DIAGNOSTICS_DIR, paste0("step6_", stem, ".csv")))
}

audit_division_bias <- function(estimation, base) {
  inputs <- build_division_bias_inputs(estimation, base)
  regressors <- c("current_etr", "lagged_etr", "jackknife_etr", "jackknife_foreign_only_etr",
    "statutory_cit", "forward_eatr"
  )
  archived <- read_csv(file.path(DIAGNOSTICS_DIR, "step5_stage3_alternative_estimators.csv"),
    show_col_types = FALSE
  ) |>
    filter(sample == "positive_profit")
  log_t0 <- unique(na.omit(archived$t0))
  stopifnot(length(log_t0) == 1, all(inputs$pair_profit_weight > 0))
  available <- map_dfr(regressors, function(regressor) {
    fit_division_bias_design(filter(inputs, is.finite(.data[[regressor]])),
      regressor, "available", "current", log_t0
    )
  })
  reference <- available |>
    filter(regressor == "current_etr", statistic_type == "semi_elasticity") |>
    inner_join(
      archived |> filter(statistic_type == "semi_elasticity") |>
        select(estimator, model_spec, tau_eval, archived_estimate = estimate),
      by = c("estimator", "model_spec", "tau_eval"), relationship = "one-to-one"
    )
  stopifnot(nrow(reference) == 27, max(abs(reference$estimate - reference$archived_estimate)) < 1e-8)

  matched <- map_dfr(regressors[-1], function(proxy) {
    data <- filter(inputs, is.finite(.data[[proxy]]))
    benchmark <- c("current_etr",
      if (proxy == "lagged_etr" || startsWith(proxy, "jackknife")) "current_bounded"
    )
    support <- paste0("matched_", proxy)
    stopifnot(all(is.finite(data$current_etr)), all(is.finite(data$current_bounded)))
    bind_rows(
      map_dfr(benchmark, ~ fit_division_bias_design(data, .x, support, "current", log_t0)),
      available |> filter(regressor == proxy) |> mutate(sample = support)
    )
  })

  # Replace only the two activity controls. The current-control comparison
  # uses exactly the same cells with available t-1 activity.
  lagged_activity <- map_dfr(regressors, function(regressor) {
    data <- filter(inputs, is.finite(.data[[regressor]]),
      is.finite(log_assets_lagged), is.finite(log_payroll_lagged)
    )
    map_dfr(c("current", "lagged"), function(activity) {
      fit_division_bias_design(data, regressor, "matched_lagged_activity", activity, log_t0)
    })
  })

  bind_rows(available, matched, lagged_activity)
}

allocate_avoided_topup <- function(panel, weights, regime) {
  source <- panel |>
    filter(factor5_behaviour == "behavioural") |>
    mutate(topup_after_behaviour = if_else(behavioural_regime == regime, behavioural_avoided_topup, 0)) |>
    build_source_panel()
  allocate_stage4_revenue(source, weights)$revenue_country_year_eu27 |>
    select(country, year, scenario_id, revenue)
}

build_total_fiscal_country_year <- function(panel, direct, affiliate_year, weights,
                                           rule_b_matrix = NULL) {
  reallocation <- if (is.null(rule_b_matrix)) {
    build_parent_specific_reallocation(panel, affiliate_year)
  } else {
    list(matrix = rule_b_matrix, source_rows = panel |>
      filter(reallocated_profit > 0) |>
      mutate(source_tax_loss = reallocated_profit * static_tau_low))
  }
  routing <- reallocation$matrix
  if (is.null(rule_b_matrix)) {
    routing <- routing |>
      mutate(global_fallback_profit_received = if_else(destination_weight_source == "parent_year",
        0, reallocated_profit_received))
  } else {
    routing <- routing |>
      mutate(equal_weight_fallback = FALSE, effective_rate_fallback = FALSE)
  }
  ordinary <- summarise_ordinary_cit_incidence(routing, reallocation$source_rows)
  direct_reallocation <- allocate_avoided_topup(panel, weights, "semi_elasticity_reallocation") |>
    rename(direct_topup_lost_reallocation = revenue)
  direct_bunching <- allocate_avoided_topup(panel, weights, "sesh_bunching_topup_zero") |>
    rename(direct_topup_lost_bunching = revenue)
  keys <- c("country", "year", "scenario_id")
  country_year <- direct |>
    rename(direct_topup = revenue) |>
    mutate(mechanical_scenario = paste0(substr(scenario_id, 1, 5), "0")) |>
    left_join(
      direct |> transmute(country, year, mechanical_scenario = scenario_id, mechanical_direct_topup = revenue),
      by = c("country", "year", "mechanical_scenario"), relationship = "many-to-one"
    ) |>
    left_join(direct_reallocation, by = keys, relationship = "one-to-one") |>
    left_join(direct_bunching, by = keys, relationship = "one-to-one") |>
    left_join(ordinary$destination, by = keys, relationship = "one-to-one") |>
    left_join(ordinary$origin, by = keys, relationship = "one-to-one") |>
    mutate(
      across(c(starts_with("direct_topup_lost_"), starts_with("reallocated_profit_"),
        starts_with("ordinary_cit_"), ends_with("_profit_received"), effective_rate_fallback_profit),
      coalesce_zero),
      direct_topup_lost_total = mechanical_direct_topup - direct_topup,
      ordinary_cit_net_by_incidence = ordinary_cit_gross_destination_revenue - ordinary_cit_source_loss,
      total_fiscal_revenue = direct_topup + ordinary_cit_gross_destination_revenue,
      total_fiscal_revenue_effective = direct_topup + ordinary_cit_gross_destination_revenue_effective,
      total_fiscal_revenue_net_by_incidence = direct_topup + ordinary_cit_net_by_incidence,
      total_fiscal_gain_vs_mechanical = total_fiscal_revenue - mechanical_direct_topup,
      total_fiscal_gain_vs_mechanical_effective = total_fiscal_revenue_effective - mechanical_direct_topup,
      total_fiscal_gain_vs_mechanical_net_by_incidence = total_fiscal_revenue_net_by_incidence - mechanical_direct_topup
    )
  stopifnot(max(abs(with(country_year, direct_topup_lost_total -
    direct_topup_lost_reallocation - direct_topup_lost_bunching))) < 1e-4)
  list(country_year = country_year, reallocation = reallocation)
}

summarise_total_fiscal_ledger <- function(country_year, reallocation) {
  matrix <- reallocation$matrix
  legacy <- "parent" %in% names(matrix)
  global <- matrix |>
    group_by(scenario_id, year) |>
    summarise(
      global_reallocated_profit = sum(reallocated_profit_received),
      global_reallocated_profit_using_fallback = if (legacy) sum(reallocated_profit_received[
        destination_weight_source != "parent_year"
      ]) else sum(global_fallback_profit_received),
      parent_year_pools = if (legacy) n_distinct(parent) else NA_integer_,
      fallback_parent_year_pools = if (legacy) {
        n_distinct(parent[destination_weight_source != "parent_year"])
      } else NA_integer_,
      .groups = "drop"
    )
  amounts <- c(
    "direct_topup", "mechanical_direct_topup", "direct_topup_lost_total",
    "direct_topup_lost_reallocation", "direct_topup_lost_bunching",
    "reallocated_profit_received", "reallocated_profit_sent",
    "ordinary_cit_gross_destination_revenue", "ordinary_cit_gross_destination_revenue_effective",
    "ordinary_cit_source_loss", "ordinary_cit_net_recovery", "ordinary_cit_net_by_incidence",
    "total_fiscal_revenue", "total_fiscal_revenue_effective", "total_fiscal_revenue_net_by_incidence",
    "total_fiscal_gain_vs_mechanical", "total_fiscal_gain_vs_mechanical_effective",
    "total_fiscal_gain_vs_mechanical_net_by_incidence", "global_fallback_profit_received",
    "equal_weight_profit_received", "effective_rate_fallback_profit"
  )
  eu <- country_year |>
    group_by(across(all_of(SCENARIO_VARS)), year) |>
    summarise(across(all_of(amounts), sum), .groups = "drop") |>
    mutate(country = "EU27", country_name = "European Union (27)") |>
    left_join(global, by = c("scenario_id", "year"), relationship = "one-to-one") |>
    mutate(across(c(global_reallocated_profit, global_reallocated_profit_using_fallback), coalesce_zero))
  annual <- bind_rows(country_year, eu)
  global_amounts <- setdiff(names(global), c("scenario_id", "year"))
  cumulative <- annual |>
    group_by(across(all_of(SCENARIO_VARS)), country, country_name) |>
    summarise(across(all_of(c(amounts, global_amounts)), sum_or_na), .groups = "drop")
  bind_rows(
    annual |> mutate(start_year = year, end_year = year, .before = 1) |> select(-year),
    cumulative |> mutate(start_year = min(MAIN_YEARS), end_year = max(MAIN_YEARS), .before = 1)
  ) |>
    select(start_year, end_year, country, country_name, all_of(SCENARIO_VARS),
      all_of(c(amounts, global_amounts))
    ) |>
    mutate(mechanical_scenario = paste0(substr(scenario_id, 1, 5), "0")) |>
    arrange(start_year, end_year, country, scenario_id)
}

decompose_total_fiscal_revenue <- function(country_year) {
  outcomes <- c("direct_topup", "total_fiscal_revenue", "total_fiscal_revenue_effective",
    "total_fiscal_revenue_net_by_incidence")
  map_dfr(c(2017L, 2019L, 2021L, 2023L), function(start) {
    map_dfr(outcomes, function(outcome) {
      input <- country_year |>
        filter(year >= start) |>
        transmute(across(all_of(SCENARIO_VARS)), country, country_name, year, revenue = .data[[outcome]])
      anova <- compute_factorial_anova(input)$pooled
      shapley <- build_shapley_factor_attribution(anova) |>
        select(effect, shapley_eta_squared)
      stopifnot(abs(sum(anova$eta_squared) - 1) < 1e-12,
        abs(sum(shapley$shapley_eta_squared) - 1) < 1e-12
      )
      totals <- build_scenario_summary(input)
      anova |>
        left_join(shapley, by = "effect", relationship = "one-to-one") |>
        mutate(
          outcome, start_year = start, end_year = max(MAIN_YEARS),
          country_years = n_distinct(input$country, input$year),
          interaction_eta_squared = sum(eta_squared[interaction_order > 1]),
          eu27_revenue_min = min(totals$eu_revenue), eu27_revenue_max = max(totals$eu_revenue),
          min_scenario = totals$scenario_id[which.min(totals$eu_revenue)],
          max_scenario = totals$scenario_id[which.max(totals$eu_revenue)],
          .before = 1
        )
    })
  })
}

read_step6_factorial_input <- function() {
  read_step6_input("stage3_factorial_pair_year") |>
    select(all_of(SCENARIO_VARS), parent, affiliate, year, affiliate_jurisdiction_name,
      parent_jurisdiction_name, affiliate_cit_rate_unit, affiliate_is_conduit_haven,
      any_of(c("affiliate_cit_destination_price_rate", "affiliate_cit_destination_gate_rate",
        "affiliate_cit_standard_combined")), employees_sbie, payroll_sbie, upr_panelai, static_tau_low, reallocated_profit,
      behavioural_avoided_topup, behavioural_regime, qdmtt_flag, parent_iir_utpr_flag, sbs_exempt,
      stage2_phi, assets_sbie, act_ip_panelai, act_holding_panelai, act_igf_panelai,
      analysis_profit_positive, average_low_share, stage1_distributional_low_share,
      stage2_excess_lowtax_profit_average, stage2_excess_lowtax_profit_distributional,
      stage1_lowtax_profit_average, stage1_lowtax_profit_distributional,
      static_beta_applied, static_behavioural_regime, topup_after_stage2, topup_after_behaviour
    )
}

read_step6_utpr_weights <- function() {
  read_stage4_utpr_weights()
}

run_fiscal_recovery_audit <- function(panel, direct, weights) {
  output <- build_total_fiscal_country_year(panel, direct, read_step6_input("stage1_affiliate_year"), weights)
  ledger <- summarise_total_fiscal_ledger(output$country_year, output$reallocation)
  stopifnot(nrow(ledger) == (length(MAIN_YEARS) + 1) * 28 * 32,
    all(ledger$ordinary_cit_gross_destination_revenue[ledger$x5_behaviour == 0] == 0),
    all(ledger$ordinary_cit_gross_destination_revenue >= 0)
  )
  write_step6_diagnostic(ledger, "topup_vs_cit_recovery_eu27")
  write_step6_diagnostic(decompose_total_fiscal_revenue(output$country_year), "anova_total_fiscal_revenue")
  rule_b_matrix <- read_step6_input("stage3_reallocation_matrix")
  if ("reallocated_profit_received_rule_a" %in% names(rule_b_matrix)) {
    rule_b <- build_total_fiscal_country_year(panel, direct, read_step6_input("stage1_affiliate_year"),
      weights, rule_b_matrix)
    rule_b_ledger <- summarise_total_fiscal_ledger(rule_b$country_year, rule_b$reallocation)
    stopifnot(nrow(rule_b_ledger) == nrow(ledger),
      all(rule_b_ledger$ordinary_cit_gross_destination_revenue[rule_b_ledger$x5_behaviour == 0] == 0))
    write_step6_diagnostic(rule_b_ledger, "topup_vs_cit_recovery_rule_b_eu27")
    write_step6_diagnostic(decompose_total_fiscal_revenue(rule_b$country_year),
      "anova_total_fiscal_revenue_rule_b")
  }
}

build_eurostat_oecd_comparison <- function(eurostat, cit_revenue) {
  oecd <- cit_revenue |>
    filter(jurisdiction %in% setdiff(EU27_ISO3, "CYP"), year %in% CORE_YEARS,
      measure == "TAX_REV", sector == "S13", revenue_classification == "T_1200", unit == "USD"
    ) |>
    transmute(jurisdiction, year, oecd_t1200_usd_billions = value)
  precision <- read_csv(
    file.path(RAW_DIR, "oecd_cts_additional", "oecd_cit_revenue_gdp.csv"),
    col_select = c(REF_AREA, TIME_PERIOD, MEASURE, SECTOR, STANDARD_REVENUE, UNIT_MEASURE,
      UNIT_MULT, DECIMALS
    ),
    show_col_types = FALSE
  ) |>
    filter(REF_AREA %in% setdiff(EU27_ISO3, "CYP"), TIME_PERIOD %in% CORE_YEARS,
      MEASURE == "TAX_REV", SECTOR == "S13", STANDARD_REVENUE == "T_1200", UNIT_MEASURE == "USD"
    ) |>
    transmute(jurisdiction = REF_AREA, year = as.integer(TIME_PERIOD),
      oecd_rounding_half_unit_usd_billions = 0.5 * 10^(UNIT_MULT - DECIMALS - 9)
    )
  assert_unique_keys(oecd, c("jurisdiction", "year"), "OECD comparator")
  assert_unique_keys(precision, c("jurisdiction", "year"), "OECD rounding metadata")

  crossing(jurisdiction = EU27_ISO3, year = CORE_YEARS, eurostat_tax_code = c("D51B", "D51B_C2")) |>
    left_join(eurostat, by = c("jurisdiction", "year", "eurostat_tax_code"), relationship = "one-to-one") |>
    left_join(oecd, by = c("jurisdiction", "year"), relationship = "many-to-one") |>
    left_join(precision, by = c("jurisdiction", "year"), relationship = "many-to-one") |>
    mutate(
      eurostat_usd_billions = usd_billions,
      difference_usd_billions = eurostat_usd_billions - oecd_t1200_usd_billions,
      difference_pct_oecd = 100 * safe_divide(difference_usd_billions, oecd_t1200_usd_billions),
      # Eurostat's published values in this extract are rounded to EUR 0.1m.
      rounding_tolerance_usd_billions = 0.05 * usd_per_eur / 1000 + oecd_rounding_half_unit_usd_billions,
      within_source_rounding = abs(difference_usd_billions) <= rounding_tolerance_usd_billions
    ) |>
    select(-usd_billions)
}

build_cyprus_denominator_audit <- function(eurostat, panel, direct, weights) {
  preferred_ids <- c("x10001", "x10011")
  cyprus <- eurostat |>
    filter(jurisdiction == "CYP") |>
    select(year, eurostat_tax_code, eur_millions, usd_billions, usd_per_eur, eurostat_last_update) |>
    pivot_wider(names_from = eurostat_tax_code, values_from = c(eur_millions, usd_billions))
  stopifnot(setequal(cyprus$year, CORE_YEARS), all(cyprus$eur_millions_D51B_C2 == cyprus$eur_millions_D51B),
    all(cyprus$eur_millions_D51C2 == 0)
  )
  preferred_source <- panel |> filter(scenario_id %in% preferred_ids)
  generated <- preferred_source |>
    filter(affiliate == "CYP") |>
    group_by(scenario_id, year) |>
    summarise(source_liability = sum(topup_after_behaviour), .groups = "drop")

  # Reproduce the Step 5 R2 policy change annually. The UTPR collector set
  # and its weights are held fixed, as in that sensitivity.
  cyprus_active_source <- preferred_source |>
    mutate(qdmtt_flag = qdmtt_flag | affiliate == "CYP",
      parent_iir_utpr_flag = parent_iir_utpr_flag | parent == "CYP"
    ) |>
    add_behavioural_response() |>
    build_source_panel()
  allocation <- allocate_stage4_revenue(cyprus_active_source, weights)
  build_conservation_diagnostics(cyprus_active_source, allocation$revenue_by_channel_global, allocation$unsupported_utpr)
  active <- allocation$revenue_country_year_eu27 |>
    filter(country == "CYP") |>
    select(scenario_id, year, r2_cyprus_active_revenue = revenue)
  step5 <- read_csv(file.path(DIAGNOSTICS_DIR, "step7_cyprus_and_article50_sensitivity.csv"),
    show_col_types = FALSE
  ) |>
    filter(country == "CYP", regime == "R2_cyprus_domestic_law")
  check <- active |>
    group_by(scenario_id) |>
    summarise(full = sum(r2_cyprus_active_revenue),
      last = r2_cyprus_active_revenue[year == max(MAIN_YEARS)], .groups = "drop"
    ) |>
    pivot_longer(c(full, last), names_to = "window", values_to = "calculated") |>
    mutate(start_year = if_else(window == "full", min(MAIN_YEARS), max(MAIN_YEARS))) |>
    inner_join(select(step5, scenario_id, start_year, collector_revenue),
      by = c("scenario_id", "start_year"), relationship = "one-to-one"
    )
  stopifnot(nrow(check) == 4, max(abs(check$calculated - check$collector_revenue)) < 1e-4)
  preferred <- direct |>
    filter(country == "CYP", scenario_id %in% preferred_ids) |>
    select(scenario_id, year, preferred_revenue = revenue)
  cyprus |>
    left_join(preferred, by = "year", relationship = "one-to-many") |>
    left_join(generated, by = c("scenario_id", "year"), relationship = "one-to-one") |>
    left_join(active, by = c("scenario_id", "year"), relationship = "one-to-one") |>
    mutate(
      jurisdiction = "CYP", eurostat_dataset = "gov_10a_taxag", eurostat_sector = "S13",
      denominator_tax_code = "D51B_C2", exchange_rate_series = "ECB EXR.A.USD.EUR.SP00.A",
      cit_revenue_T_1200_usd_billions = usd_billions_D51B_C2,
      preferred_revenue_pct_of_cit = 100 * preferred_revenue / (cit_revenue_T_1200_usd_billions * 1e9),
      source_liability_pct_of_cit = 100 * source_liability / (cit_revenue_T_1200_usd_billions * 1e9),
      r2_cyprus_active_revenue_pct_of_cit = 100 * r2_cyprus_active_revenue / (cit_revenue_T_1200_usd_billions * 1e9)
    ) |>
    relocate(jurisdiction, year, scenario_id, cit_revenue_T_1200_usd_billions)
}

run_division_bias_and_cit_recovery <- function() {
  message("Estimating matched division-bias and activity-control models")
  estimates <- audit_division_bias(read_step6_input("stage3_estimation_sample"), read_step6_input("base_panel"))
  write_step6_diagnostic(estimates, "division_bias_and_curvature_audit")

  message("Reconciling parent-specific CIT recovery with direct top-up")
  panel <- read_step6_factorial_input()
  direct <- read_step6_input("stage4_5_revenue_country_year")
  weights <- read_step6_utpr_weights()
  run_fiscal_recovery_audit(panel, direct, weights)

  message("Verifying Cyprus CIT receipts and the Eurostat–OECD crosswalk")
  eurostat <- read_eurostat_corporate_tax()
  cyprus <- build_cyprus_denominator_audit(eurostat, panel, direct, weights)
  stopifnot(nrow(cyprus) == 1 + 2 * length(MAIN_YEARS))
  write_step6_diagnostic(cyprus, "cyprus_cit_denominator")
  write_step6_diagnostic(
    build_eurostat_oecd_comparison(eurostat, read_step6_input("cit_revenue")),
    "eurostat_oecd_cit_comparison"
  )
}

# Formulary destinations, budget forecasts and institutional regimes

STEP7_PREFERRED <- c("x10001", "x10011")
STEP7_WINDOWS <- list(`2017–2023` = MAIN_YEARS, FY2023 = 2023L, `2019–2023` = 2019:2023)
USD_PER_EUR_2023 <- 1.0813

write_step7 <- function(data, name) {
  write_csv(data, file.path(DIAGNOSTICS_DIR, paste0("step7_", name, ".csv")))
}

build_destination_comparison <- function(panel, direct, stage1, host) {
  panel <- filter(panel, scenario_id %in% STEP7_PREFERRED)
  destination <- build_destination_routes(panel, stage1, host)
  routes <- destination$routes
  if ("affiliate_cit_destination_price_rate" %in% names(stage1)) {
    routes <- attach_destination_prices(routes,
      destination_price_lookup(stage1, include_parents = TRUE), "received") |>
      mutate(statutory_rate = price_rate)
  }
  ordinary <- summarise_destination_incidence(routes, destination$sources)
  keys <- c("country", "scenario_id", "year")
  annual <- direct |>
    filter(scenario_id %in% STEP7_PREFERRED) |>
    transmute(across(all_of(keys)), direct_topup = revenue,
      mechanical_id = sub("1$", "0", scenario_id)
    ) |>
    left_join(
      transmute(direct, country, year, mechanical_id = scenario_id, mechanical_topup = revenue),
      by = c("country", "year", "mechanical_id"), relationship = "many-to-one"
    ) |>
    left_join(ordinary$origin, by = keys, relationship = "one-to-one") |>
    crossing(rule = c("A", "B", "C")) |>
    left_join(ordinary$receipts, by = c("rule", keys), relationship = "one-to-one") |>
    mutate(across(c(gross_cit, source_cit_lost, profit_received, profit_sent,
      global_fallback_profit, headquarters_profit, same_country_headquarters_profit), coalesce_zero),
      direct_topup_change = direct_topup - mechanical_topup,
      net_fiscal_change = direct_topup_change + gross_cit - source_cit_lost
    )
  amounts <- c("direct_topup", "mechanical_topup", "direct_topup_change", "gross_cit",
    "source_cit_lost", "net_fiscal_change", "profit_received", "profit_sent",
    "global_fallback_profit", "headquarters_profit", "same_country_headquarters_profit")
  compare <- imap_dfr(STEP7_WINDOWS, function(years, window) {
    states <- annual |>
      filter(year %in% years) |>
      group_by(country, scenario_id, rule) |>
      summarise(across(all_of(amounts), sum), .groups = "drop")
    eu <- states |>
      group_by(scenario_id, rule) |>
      summarise(across(all_of(amounts), sum), .groups = "drop") |>
      mutate(country = "EU27")
    support <- routes |>
      filter(year %in% years) |>
      group_by(scenario_id, rule) |>
      summarise(
        global_profit_reallocated = sum(received),
        global_profit_using_fallback = sum(received[route == "global_activity"]),
        global_headquarters_profit = sum(received[route == "headquarters"]),
        global_same_country_headquarters_profit = sum(received[same_country_headquarters]), .groups = "drop"
      )
    bind_rows(states, left_join(eu, support, by = c("scenario_id", "rule"))) |>
      mutate(window, start_year = min(years), end_year = max(years), .before = 1)
  })
  step6 <- read_csv(file.path(DIAGNOSTICS_DIR, "step6_topup_vs_cit_recovery_eu27.csv"),
    show_col_types = FALSE
  )
  previous <- imap_dfr(STEP7_WINDOWS, function(years, window) {
    step6 |>
      filter(scenario_id %in% STEP7_PREFERRED, start_year == end_year, end_year %in% years) |>
      group_by(country, scenario_id) |>
      summarise(ordinary_cit_gross_destination_revenue = sum(ordinary_cit_gross_destination_revenue),
        .groups = "drop"
      ) |>
      mutate(window)
  })
  check <- compare |>
    filter(rule == "A") |>
    left_join(previous, by = c("country", "scenario_id", "window"), relationship = "one-to-one")
  stopifnot(nrow(compare) == length(STEP7_WINDOWS) * 28L * 2L * 3L,
    max(abs(check$gross_cit - check$ordinary_cit_gross_destination_revenue)) < 1e-3
  )
  compare
}

compare_destination_rate_roles <- function(panel, stage1, host) {
  panel <- filter(panel, scenario_id %in% STEP7_PREFERRED)
  prices <- list(legacy = destination_price_lookup(stage1, "historical", include_parents = TRUE),
    standard = destination_price_lookup(stage1, include_parents = TRUE))
  by_gate <- list(
    legacy = build_destination_routes(panel, stage1, host),
    standard = build_destination_routes(
      mutate(panel, affiliate_cit_destination_gate_rate = affiliate_cit_standard_combined),
      mutate(stage1, parent_cit_destination_gate_rate = parent_cit_standard_combined), host)
  )
  origin <- by_gate$legacy$sources |>
    transmute(country = affiliate, year, scenario_id, reallocated_profit, source_tax_loss)
  stopifnot(identical(origin, transmute(by_gate$standard$sources, country = affiliate, year,
    scenario_id, reallocated_profit, source_tax_loss)))
  keys <- c("country", "year", "scenario_id")
  origin <- summarise(origin, profit_sent = sum(reallocated_profit),
    source_cit_lost = sum(source_tax_loss), .by = all_of(keys)) |>
    crossing(rule = c("A", "B", "C"))
  imap_dfr(by_gate, function(routes, gate) {
    imap_dfr(prices, function(rate, pricing) {
      priced <- attach_destination_prices(routes$routes, rate, "received", require_support = FALSE) |>
        summarise(relocated_profit = sum(received),
          unpriced_profit = sum(received[!is.finite(price_rate)]),
          priced_gross_cit = sum(received[is.finite(price_rate)] * price_rate[is.finite(price_rate)]),
          fallback_profit = sum(received[route == "global_activity"]),
          headquarters_profit = sum(received[route == "headquarters"]),
          .by = c(rule, scenario_id, year, destination)) |>
        rename(country = destination) |>
        full_join(origin, by = c("rule", keys), relationship = "one-to-one") |>
        mutate(across(c(relocated_profit, unpriced_profit, priced_gross_cit, fallback_profit,
          headquarters_profit, profit_sent, source_cit_lost), coalesce_zero))
      conservation <- summarise(priced, sent = sum(profit_sent), received = sum(relocated_profit),
        .by = c(rule, scenario_id, year))
      stopifnot(all(abs(conservation$sent - conservation$received) <
        1e-12 * pmax(1, conservation$sent)))
      amounts <- c("relocated_profit", "unpriced_profit", "priced_gross_cit", "fallback_profit",
        "headquarters_profit", "profit_sent", "source_cit_lost")
      imap_dfr(STEP7_WINDOWS, function(years, window) {
        countries <- priced |>
          filter(year %in% years) |>
          summarise(across(all_of(amounts), sum), .by = c(rule, scenario_id, country)) |>
          mutate(region = if_else(country %in% EU27_ISO3, "EU27", "non-EU27"))
        regional <- summarise(countries, across(all_of(amounts), sum),
          .by = c(rule, scenario_id, region)) |> rename(country = region)
        global <- summarise(countries, across(all_of(amounts), sum),
          .by = c(rule, scenario_id)) |> mutate(country = "Global")
        bind_rows(select(countries, -region), regional, global) |>
          mutate(gate, pricing, window,
            gross_cit = if_else(unpriced_profit > 0, NA_real_, priced_gross_cit),
            net_ordinary_cit = gross_cit - source_cit_lost, .before = 1)
      })
    })
  })
}

summarise_budget_matches <- function(revenue, channels, destination_comparison) {
  windows <- list(FY2023 = 2023L, `2019–2023 annualised` = 2019:2023,
    `2017–2023 annualised` = MAIN_YEARS)
  model <- imap_dfr(windows, function(years, window) {
    scope_values <- channels |>
      filter(year %in% years, channel %in% c("QDMTT", "IIR")) |>
      group_by(country, scenario_id, channel) |>
      summarise(channel_eur_bn = sum(revenue) / (length(years) * USD_PER_EUR_2023 * 1e9),
        .groups = "drop"
      ) |>
      mutate(channel = recode(channel, QDMTT = "qdmt", IIR = "iir")) |>
      pivot_wider(names_from = channel, values_from = channel_eur_bn)
    revenue |>
      filter(year %in% years) |>
      group_by(country, scenario_id, across(all_of(FACTOR_COLS))) |>
      summarise(direct = sum(revenue) / (length(years) * USD_PER_EUR_2023 * 1e9),
        observations = n(), .groups = "drop"
      ) |>
      left_join(scope_values, by = c("country", "scenario_id"), relationship = "one-to-one") |>
      mutate(across(c(qdmt, iir), coalesce_zero), window)
  })
  stopifnot(all(model$observations == lengths(windows)[model$window]))
  benchmarks <- budget_benchmarks()
  matches <- pmap_dfr(benchmarks, function(country, benchmark, evidence, forecast_period, revenue_scope,
                              model_scope, official_low_eur_bn, official_high_eur_bn,
                              stated_sbs_switch, source_url, comparison_scope) {
    member <- model[model$country == country, ]
    map_dfr(names(windows), function(window) {
      x <- member[member$window == window, ]
      stopifnot(nrow(x) == 32L, n_distinct(x$scenario_id) == 32L)
      value <- x[[model_scope]]
      distance <- pmax(official_low_eur_bn - value, value - official_high_eur_bn, 0)
      eligible <- is.na(stated_sbs_switch) | x$x4_sbs == stated_sbs_switch
      indices <- which(distance == min(distance))
      best <- indices[1]
      policy_indices <- which(eligible & distance == min(distance[eligible]))
      pair <- match(STEP7_PREFERRED, x$scenario_id)
      tibble(
        country, benchmark, evidence, forecast_period, revenue_scope, model_scope, comparison_scope,
        window, official_low_eur_bn, official_high_eur_bn, usd_per_eur = USD_PER_EUR_2023,
        collector_min_eur_bn = min(x$direct), collector_max_eur_bn = max(x$direct),
        benchmark_inside_collector_range = official_high_eur_bn >= min(x$direct) & official_low_eur_bn <= max(x$direct),
        comparable_min_eur_bn = min(value), comparable_max_eur_bn = max(value),
        benchmark_inside_comparable_range = official_high_eur_bn >= min(value) & official_low_eur_bn <= max(value),
        closest_scenario = x$scenario_id[best],
        closest_tied_scenarios = if (length(indices)) paste(x$scenario_id[indices], collapse = "/") else NA_character_,
        closest_model_eur_bn = value[best], distance_to_benchmark_eur_bn = distance[best],
        stated_sbs_switch,
        closest_with_stated_sbs = x$scenario_id[policy_indices[1]],
        closest_with_stated_sbs_eur_bn = value[policy_indices[1]],
        preferred_universal_direct = x$direct[pair[1]], preferred_sbs_direct = x$direct[pair[2]],
        preferred_universal_qdmtt = x$qdmt[pair[1]], preferred_sbs_qdmtt = x$qdmt[pair[2]],
        preferred_direct_haircut_pct = 100 * (x$direct[pair[2]] / x$direct[pair[1]] - 1),
        source_url
      ) |>
        bind_cols(select(x[best, ], all_of(FACTOR_COLS)))
    })
  })
  fiscal <- destination_comparison |>
    mutate(
      window = if_else(window == "FY2023", window, paste(window, "annualised")),
      scale = (end_year - start_year + 1) * USD_PER_EUR_2023 * 1e9,
      gross_induced_cit = gross_cit / scale,
      net_fiscal_receipts = (direct_topup + gross_cit - source_cit_lost) / scale
    ) |>
    select(country, window, scenario_id, rule, gross_induced_cit, net_fiscal_receipts) |>
    pivot_wider(names_from = c(scenario_id, rule), values_from = c(gross_induced_cit, net_fiscal_receipts))
  matches |> left_join(fiscal, by = c("country", "window"), relationship = "many-to-one")
}

build_institutional_regime_matrix <- function(stage1, host, cit) {
  read_ledger <- function(suffix) {
    read_csv(file.path(DIAGNOSTICS_DIR, paste0("step7_eu27_source_vs_collector_ledger_", suffix, ".csv")),
      show_col_types = FALSE
    ) |>
      filter(scenario_id == "x10011") |>
      select(-cit_revenue_T_1200, -cit_years_observed, -collector_revenue_pct_of_cit)
  }
  by_country <- cit |>
    group_by(country) |>
    summarise(cit_revenue = sum(cit_revenue_T_1200),
      cit_revenue_2023 = cit_revenue_T_1200[year == 2023L], .groups = "drop")
  hidden <- stage1 |>
    filter(affiliate %in% EU27_ISO3, year %in% MAIN_YEARS) |>
    left_join(select(host, affiliate, year, avg_etr_stage1),
      by = c("affiliate", "year"), relationship = "many-to-one"
    ) |>
    group_by(country = affiliate) |>
    summarise(
      low_tax_profit = sum(stage1_lowtax_profit_distributional, na.rm = TRUE),
      low_tax_profit_in_high_mean_cells = sum(if_else(avg_etr_stage1 > GMT_RATE,
        stage1_lowtax_profit_distributional, 0, missing = 0
      ), na.rm = TRUE), .groups = "drop"
    ) |>
    mutate(hidden_tail_share = safe_divide(low_tax_profit_in_high_mean_cells, low_tax_profit))
  legal <- read_csv(file.path(DIAGNOSTICS_DIR, "step5_stage3_eu27_legal_regime_classification.csv"),
    show_col_types = FALSE
  ) |>
    transmute(country = jurisdiction, domestic_topup_tax_enacted, domestic_enactment_summary)
  r2 <- read_csv(file.path(DIAGNOSTICS_DIR, "step7_cyprus_and_article50_sensitivity.csv"),
    show_col_types = FALSE
  ) |>
    filter(regime == "R2_cyprus_domestic_law", start_year == 2017L, end_year == 2023L, scenario_id == "x10011") |>
    transmute(country, r2_collector_revenue = collector_revenue, r2_source_liability = source_topup_liability,
      r2_qdmtt = collector_QDMTT, r2_iir = collector_IIR, r2_utpr = collector_UTPR
    )
  result <- read_ledger("2017_2023") |>
    left_join(by_country, by = "country", relationship = "one-to-one") |>
    left_join(
      read_ledger("2023") |> transmute(country, source_liability_2023 = source_topup_liability),
      by = "country", relationship = "one-to-one"
    ) |>
    left_join(hidden, by = "country", relationship = "one-to-one") |>
    left_join(legal, by = "country", relationship = "one-to-one") |>
    left_join(r2, by = "country", relationship = "one-to-one") |>
    mutate(
      source_to_cit = source_topup_liability / cit_revenue,
      source_to_cit_2023 = source_liability_2023 / cit_revenue_2023,
      collector_to_cit = collector_revenue / cit_revenue,
      r2_collector_to_cit = r2_collector_revenue / cit_revenue,
      collector_qdmtt_share = safe_divide(collector_QDMTT, collector_revenue),
      source_qdmtt_retention_share = safe_divide(source_retained_qdmtt, source_topup_liability),
      foreign_export_share = safe_divide(source_exported_iir + source_exported_utpr, source_topup_liability),
      high_salience = source_to_cit > .25,
      institutional_group = case_when(
        high_salience ~ 1L,
        article50_deferral & !qdmtt_by_2026 & foreign_export_share > 0 ~ 4L,
        qdmtt_by_2026 & collector_qdmtt_share >= .75 ~ 2L,
        TRUE ~ 3L
      ),
      institutional_regime = case_when(
        institutional_group == 1L & qdmtt_by_2026 ~ "High-salience source, QDMTT active",
        institutional_group == 1L & article50_deferral ~ "High-salience source, Article 50 exporter",
        institutional_group == 1L ~ "High-salience source, domestic tax outside pinned baseline",
        institutional_group == 2L ~ "QDMTT-protected collector",
        institutional_group == 3L ~ "Residual IIR/UTPR collector",
        TRUE ~ "Article 50 fiscal exporter"
      ),
      proposed_group = case_when(
        country %in% c("LUX", "CYP", "NLD", "IRL", "HUN", "MLT") ~ 1L,
        country %in% c("AUT", "BEL", "DNK", "FIN", "GRC", "SVK") ~ 2L,
        country %in% c("EST", "LTU", "LVA") ~ 4L,
        TRUE ~ 3L
      ),
      matches_proposed_group = institutional_group == proposed_group
    ) |>
    relocate(country, country_name, institutional_group, institutional_regime, proposed_group,
      source_to_cit, source_to_cit_2023, collector_to_cit, collector_qdmtt_share, hidden_tail_share
    ) |>
    arrange(institutional_group, desc(source_to_cit))
  stopifnot(nrow(result) == 27L, all(is.finite(result$source_to_cit)), all(is.finite(result$collector_to_cit)))
  result
}

compare_typology_membership <- function(features, fiscal, regimes) {
  baseline <- prepare_typology_matrix(features)$scaled
  source <- cbind(baseline, source_topup_liability = scale(log1p(regimes$source_topup_liability[
    match(features$country, regimes$country)
  ])))
  r2 <- read_csv(file.path(DIAGNOSTICS_DIR, "step7_cyprus_and_article50_sensitivity.csv"),
    show_col_types = FALSE
  ) |>
    filter(regime == "R2_cyprus_domestic_law", start_year == 2017L, end_year == 2023L,
      country %in% EU27_ISO3
    ) |>
    select(country, scenario_id, collector_revenue, collector_QDMTT, collector_IIR, collector_UTPR) |>
    pivot_wider(names_from = scenario_id,
      values_from = c(collector_revenue, collector_QDMTT, collector_IIR, collector_UTPR)
    )
  # R2 updates the preferred fiscal and channel features. The factorial
  # main effects, spread and measurement-risk features retain the base design.
  r2_features <- features |>
    left_join(r2, by = "country", relationship = "one-to-one") |>
    left_join(select(fiscal, country, cit_revenue_T_1200, gdp_usd, average_population),
      by = "country", relationship = "one-to-one"
    ) |>
    mutate(
      preferred_revenue = collector_revenue_x10011,
      revenue_to_cit_1200 = preferred_revenue / cit_revenue_T_1200,
      revenue_to_gdp = preferred_revenue / gdp_usd,
      revenue_per_capita = preferred_revenue / average_population,
      qdmtt_share = safe_divide(collector_QDMTT_x10011, preferred_revenue),
      residual_iir_utpr_exposure = safe_divide(collector_IIR_x10011 + collector_UTPR_x10011, preferred_revenue),
      sbs_extinguished_share = safe_divide(collector_revenue_x10001 - preferred_revenue, collector_revenue_x10001)
    )
  source_view <- features |>
    left_join(select(regimes, country, source_topup_liability), by = "country", relationship = "one-to-one") |>
    left_join(select(fiscal, country, cit_revenue_T_1200, gdp_usd, average_population),
      by = "country", relationship = "one-to-one"
    ) |>
    mutate(preferred_revenue = source_topup_liability,
      revenue_to_cit_1200 = source_topup_liability / cit_revenue_T_1200,
      revenue_to_gdp = source_topup_liability / gdp_usd,
      revenue_per_capita = source_topup_liability / average_population
    )
  inputs <- list(baseline_collector = baseline, add_source_liability = source,
    substitute_source_fiscal_scale = prepare_typology_matrix(source_view)$scaled,
    cyprus_active_r2 = prepare_typology_matrix(r2_features)$scaled)
  fits <- map(inputs, function(x) {
    list(
      cluster = run_country_typology_clusters(features, x)$fit$cluster,
      pca = stats::prcomp(x, center = FALSE, scale. = FALSE)
    )
  })
  ref <- fits$baseline_collector$cluster
  permutations <- crossing(a = 1:4, b = 1:4, c = 1:4, d = 1:4) |>
    filter(a != b, a != c, a != d, b != c, b != d, c != d) |>
    as.matrix()
  imap_dfr(fits, function(fit, variant) {
    match_count <- apply(permutations, 1, function(labels) sum(ref == labels[fit$cluster]))
    aligned <- if (variant == "baseline_collector") ref else permutations[which.max(match_count), fit$cluster]
    variance <- fit$pca$sdev^2 / sum(fit$pca$sdev^2)
    tibble(
      country = features$country, variant, baseline_cluster = ref, aligned_cluster = aligned,
      membership_changed = aligned != ref, pairwise_agreement = pairwise_cluster_agreement(ref, fit$cluster),
      pc1_variance_share = variance[1], first3_variance_share = sum(variance[1:3]),
      PC1 = fit$pca$x[, 1], PC2 = fit$pca$x[, 2], PC3 = fit$pca$x[, 3]
    )
  })
}

run_reallocation_and_budget_backtest <- function() {
  direct <- read_step6_input("stage4_5_revenue_country_year")
  stage1 <- read_step6_input("stage1_bilateral_panel")
  host <- read_step6_input("stage1_affiliate_year")
  panel <- read_step6_factorial_input()
  reallocation <- build_destination_comparison(panel, direct, stage1, host)
  write_step7(reallocation, "reallocation_destination_rules_comparison")
  if ("affiliate_cit_standard_combined" %in% names(panel)) {
    write_step7(compare_destination_rate_roles(panel, stage1, host), "statutory_destination_gate_and_pricing")
  }
  write_step7(summarise_budget_matches(direct, read_step6_input("stage4_5_revenue_by_channel"), reallocation),
    "official_budget_forecasts_backtest")
  fiscal <- read_step6_input("stage4_6_fiscal_salience_country")
  features <- read_step6_input("stage4_6_country_typology_feature_matrix")
  stopifnot(nrow(fiscal) == 27L, all(fiscal$cit_1200_years == length(MAIN_YEARS)),
    nrow(features) == 27L, all(is.finite(features$revenue_to_cit_1200)),
    all(is.finite(fiscal$revenue_to_cit_1200))
  )
  regimes <- build_institutional_regime_matrix(stage1, host,
    build_cit_revenue_denominators(read_step6_input("cit_revenue"))
  )
  write_step7(regimes, "eu27_institutional_regime_matrix")
  write_step7(compare_typology_membership(features, fiscal, regimes), "eu27_typology_cluster_sensitivity")
}

# Pre-reform ETR density and stylised historical notch

NOTCH_BIN_WIDTH <- 0.005
NOTCH_POLYNOMIAL_ORDER <- 4L
NOTCH_ESTIMATION_LOWER <- 0
NOTCH_ESTIMATION_UPPER <- 0.30
NOTCH_EXCLUDED_BANDWIDTH <- 0.02

build_etr_density_bins <- function(etr, weight = NULL,
                                   bin_width = NOTCH_BIN_WIDTH,
                                   lower = NOTCH_ESTIMATION_LOWER,
                                   upper = NOTCH_ESTIMATION_UPPER) {
  if (is.null(weight)) weight <- rep(1, length(etr))

  raw <- tibble(etr = etr, weight = weight) |>
    filter(
      is.finite(etr),
      is.finite(weight),
      weight > 0,
      etr >= lower,
      etr <= upper
    ) |>
    mutate(
      bin_id = pmin(
        floor((etr - lower) / bin_width),
        as.integer(round((upper - lower) / bin_width)) - 1L
      ),
      bin_lower = lower + bin_id * bin_width
    )

  bin_template <- tibble(
    bin_lower = seq(lower, upper - bin_width, by = bin_width),
    bin_upper = bin_lower + bin_width,
    bin_midpoint = bin_lower + bin_width / 2
  )

  binned <- raw |>
    group_by(bin_lower) |>
    summarise(
      observed_count = n(),
      observed_weight = sum(weight, na.rm = TRUE),
      .groups = "drop"
    )

  total_weight <- sum(raw$weight, na.rm = TRUE)

  bin_template |>
    left_join(binned, by = "bin_lower") |>
    mutate(
      observed_count = coalesce(observed_count, 0L),
      observed_weight = coalesce(observed_weight, 0),
      observed_share = if (total_weight > 0) {
        observed_weight / total_weight
      } else {
        NA_real_
      }
    )
}

fit_notch_counterfactual_density <- function(binned_density,
                                             threshold = GMT_RATE,
                                             excluded_bandwidth =
                                               NOTCH_EXCLUDED_BANDWIDTH,
                                             polynomial_order =
                                               NOTCH_POLYNOMIAL_ORDER) {
  estimation_bins <- binned_density |>
    filter(
      is.finite(observed_share),
      !(bin_midpoint >= threshold - excluded_bandwidth &
        bin_midpoint < threshold + excluded_bandwidth)
    )

  effective_order <- min(
    as.integer(polynomial_order),
    max(nrow(estimation_bins) - 2L, 1L)
  )

  fit <- stats::lm(
    observed_share ~ stats::poly(bin_midpoint, effective_order, raw = TRUE),
    data = estimation_bins
  )

  predicted <- pmax(
    stats::predict(fit, newdata = binned_density),
    0
  )
  observed_total <- sum(binned_density$observed_share, na.rm = TRUE)
  predicted_total <- sum(predicted, na.rm = TRUE)

  binned_density |>
    mutate(
      counterfactual_share = if (predicted_total > 0) {
        predicted * observed_total / predicted_total
      } else {
        NA_real_
      },
      estimation_bin = !(bin_midpoint >= threshold - excluded_bandwidth &
        bin_midpoint < threshold + excluded_bandwidth),
      polynomial_order = effective_order,
      excluded_bandwidth = excluded_bandwidth
    )
}

summarise_notch_counterfactual <- function(fitted_density,
                                           threshold = GMT_RATE,
                                           bunching_bandwidth =
                                             SESH_BANDWIDTH_BASELINE) {
  dominated_region <- fitted_density |>
    filter(
      bin_lower >= threshold - bunching_bandwidth,
      bin_upper <= threshold
    )

  threshold_bin <- fitted_density |>
    filter(bin_lower <= threshold, bin_upper > threshold)

  observed_dominated <- sum(dominated_region$observed_share, na.rm = TRUE)
  counterfactual_dominated <-
    sum(dominated_region$counterfactual_share, na.rm = TRUE)
  observed_threshold <- sum(threshold_bin$observed_share, na.rm = TRUE)
  counterfactual_threshold <-
    sum(threshold_bin$counterfactual_share, na.rm = TRUE)

  missing_mass <- counterfactual_dominated - observed_dominated
  excess_mass <- observed_threshold - counterfactual_threshold
  responsive_share <- clamp_unit_interval(
    safe_divide(pmax(missing_mass, 0), counterfactual_dominated)
  )

  tibble(
    threshold = threshold,
    bunching_bandwidth = bunching_bandwidth,
    observed_dominated_mass = observed_dominated,
    counterfactual_dominated_mass = counterfactual_dominated,
    placebo_missing_mass = missing_mass,
    observed_threshold_mass = observed_threshold,
    counterfactual_threshold_mass = counterfactual_threshold,
    placebo_excess_mass = excess_mass,
    implied_responsive_share_if_post_reform = responsive_share,
    implied_friction_share_if_post_reform = 1 - responsive_share,
    interpretation = paste(
      "Pre-reform placebo and exposure diagnostic only;",
      "not a structural estimate of post-SESH bunching."
    )
  )
}

notch_bunching_probability <- function(etr,
                                       threshold = GMT_RATE,
                                       bunching_bandwidth =
                                         SESH_BANDWIDTH_BASELINE,
                                       responsive_share = 1,
                                       curvature = 1) {
  gap <- threshold - etr
  in_band <- is.finite(gap) & gap > 0 & gap <= bunching_bandwidth
  probability <- rep(0, length(etr))
  probability[in_band] <- responsive_share *
    (1 - gap[in_band] / bunching_bandwidth)^curvature
  clamp_unit_interval(probability)
}

prepare_notch_sample <- function(stage1_affiliate_year, sample_name) {
  stage1_affiliate_year |>
    filter(
      stage1_positive_profit_flag,
      is.finite(avg_etr_stage1),
      is.finite(total_analysis_profit_positive),
      total_analysis_profit_positive > 0
    ) |>
    mutate(sample = sample_name) |>
    select(
      sample, affiliate, affiliate_name, affiliate_is_eu27, year,
      avg_etr_stage1, total_analysis_profit_positive
    )
}

estimate_notch_sample <- function(notch_sample,
                                  bin_width = NOTCH_BIN_WIDTH,
                                  polynomial_order = NOTCH_POLYNOMIAL_ORDER,
                                  threshold = GMT_RATE,
                                  excluded_bandwidth =
                                    NOTCH_EXCLUDED_BANDWIDTH,
                                  bunching_bandwidth =
                                    SESH_BANDWIDTH_BASELINE) {
  density <- build_etr_density_bins(
    notch_sample$avg_etr_stage1,
    notch_sample$total_analysis_profit_positive,
    bin_width = bin_width
  ) |>
    fit_notch_counterfactual_density(
      threshold = threshold,
      excluded_bandwidth = excluded_bandwidth,
      polynomial_order = polynomial_order
    )

  summary <- summarise_notch_counterfactual(
    density,
    threshold = threshold,
    bunching_bandwidth = bunching_bandwidth
  ) |>
    mutate(
      affiliate_years = nrow(notch_sample),
      weighted_profit = sum(notch_sample$total_analysis_profit_positive,
        na.rm = TRUE
      ),
      bin_width = bin_width,
      polynomial_order = first(density$polynomial_order),
      excluded_bandwidth = excluded_bandwidth,
      .before = 1
    )

  assignments <- notch_sample |>
    mutate(
      distance_to_threshold = threshold - avg_etr_stage1,
      in_sesh_band = distance_to_threshold > 0 &
        distance_to_threshold <= bunching_bandwidth,
      upper_bound_bunching_probability = notch_bunching_probability(
        avg_etr_stage1,
        threshold = threshold,
        bunching_bandwidth = bunching_bandwidth,
        responsive_share = 1
      ),
      placebo_calibrated_bunching_probability =
        notch_bunching_probability(
          avg_etr_stage1,
          threshold = threshold,
          bunching_bandwidth = bunching_bandwidth,
          responsive_share =
            summary$implied_responsive_share_if_post_reform[1]
        )
    )

  list(density = density, summary = summary, assignments = assignments)
}

run_sesh_notch_bunching_diagnostic <- function() {
  dir.create(DIAGNOSTICS_DIR, showWarnings = FALSE, recursive = TRUE)
  stage1_affiliate_year <- readRDS(file.path(PROCESSED_DIR, "stage1_affiliate_year.rds"))

  samples <- bind_rows(
    prepare_notch_sample(stage1_affiliate_year, "global"),
    prepare_notch_sample(
      stage1_affiliate_year |> filter(affiliate_is_eu27),
      "eu27"
    )
  )

  sample_splits <- samples |>
    group_split(sample)
  names(sample_splits) <- map_chr(sample_splits, ~ first(.x$sample))

  results <- map(sample_splits, estimate_notch_sample)

  density <- imap_dfr(results, ~ mutate(.x$density, sample = .y, .before = 1))
  summary <- imap_dfr(results, ~ mutate(.x$summary, sample = .y, .before = 1))
  assignments <- imap_dfr(results, ~ .x$assignments)

  write_csv(
    density,
    file.path(DIAGNOSTICS_DIR, "step11_sesh_notch_density_bins.csv")
  )
  write_csv(
    summary,
    file.path(DIAGNOSTICS_DIR, "step11_sesh_notch_summary.csv")
  )
  write_csv(
    assignments,
    file.path(DIAGNOSTICS_DIR, "step11_sesh_notch_assignment.csv")
  )

  saveRDS(density, file.path(PROCESSED_DIR, "sesh_notch_density_bins.rds"))
  saveRDS(summary, file.path(PROCESSED_DIR, "sesh_notch_summary.rds"))
  saveRDS(assignments, file.path(PROCESSED_DIR, "sesh_notch_assignment.rds"))

  message("\nStep 11 outputs written:")
  message(" - data/processed/sesh_notch_*.rds")
  message(" - diagnostics/step11_sesh_notch_*.csv")

  invisible(list(
    density = density,
    summary = summary,
    assignments = assignments
  ))
}

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
    stage2, stage1, mutate(sectors, sectoral_kappa = 0),
    specification = "LEGACY_HYBRID_SBIE_SBTI"
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

build_split_substance_variant <- function(panel, scales,
                                          specification = factor2_specification()) {
  if (factor2_specification(specification) == "SECTORAL_SBIE_ONLY") {
    # QTI application is unestimated. The second axis is deliberately redundant,
    # not an additional set of substantively different policy scenarios.
    return(panel |>
      mutate(x2a_sectoral = x2_substance) |>
      crossing(x2b_sbti = 0:1) |>
      mutate(scenario_id = paste0("x", x1_etr, x2a_sectoral, x2b_sbti,
        x3_rates, x4_sbs, x5_behaviour)))
  }
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
  conservation <- build_conservation_diagnostics(source, allocation$revenue_by_channel_global, allocation$unsupported_utpr)
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
  validate_utpr_weights(weights, EU27_ISO3)
  # UTPR can return to the source itself when it is an eligible collector.
  # Match the same parent-year or fallback weights as the allocator.
  parent_keys <- weights$parent_year_weights |>
    distinct(parent, year) |>
    mutate(has_parent_weights = TRUE)
  parent_own <- weights$parent_year_weights |>
    transmute(parent, year, affiliate = collector, own_parent_weight = utpr_weight)
  fallback_own <- weights$fallback_weights |>
    transmute(year, affiliate = collector, own_fallback_weight = utpr_weight)
  routed <- source |>
    filter(affiliate %in% EU27_ISO3) |>
    left_join(parent_keys, by = c("parent", "year"), relationship = "many-to-one") |>
    left_join(parent_own, by = c("parent", "year", "affiliate"), relationship = "many-to-one") |>
    left_join(fallback_own, by = c("year", "affiliate"), relationship = "many-to-one")
  unsupported <- is.na(routed$has_parent_weights) & !(routed$year %in% weights$fallback_weights$year)
  contract <- utpr_unsupported_contract(weights)
  if (contract == "strict" && any(unsupported & routed$stage4_utpr_pool > 0)) {
    stop("Source ledger has a positive UTPR pool with no supported collector route", call. = FALSE)
  }
  routed <- routed |>
    mutate(
      own_utpr_weight = if_else(coalesce(has_parent_weights, FALSE),
        coalesce_zero(own_parent_weight), coalesce_zero(own_fallback_weight)
      ),
      domestic_utpr = stage4_utpr_pool * own_utpr_weight,
      unsupported_utpr = if_else(unsupported, stage4_utpr_pool, 0)
    )
  totals <- routed |>
    group_by(country = affiliate, year, scenario_id) |>
    summarise(
      positive_corrected_affiliate_profit = sum(analysis_profit_positive, na.rm = TRUE),
      distributional_low_taxed_profit = sum(stage1_lowtax_profit_distributional, na.rm = TRUE),
      source_topup_liability = sum(topup_after_behaviour),
      source_retained_qdmtt = sum(stage4_qdmtt_liability),
      source_domestic_iir = sum(stage4_iir_liability[affiliate == parent]),
      source_exported_iir = sum(stage4_iir_liability[affiliate != parent]),
      source_domestic_utpr = sum(domestic_utpr),
      source_exported_utpr = sum(stage4_utpr_pool - domestic_utpr - unsupported_utpr),
      source_sbs_extinguished = sum(stage4_sbs_extinguished_liability),
      .groups = "drop"
    )
  if (contract == "report") {
    residual <- routed |>
      summarise(source_unsupported_utpr = sum(unsupported_utpr), .by = c(affiliate, year, scenario_id)) |>
      rename(country = affiliate)
    totals <- left_join(totals, residual, by = c("country", "year", "scenario_id"), relationship = "one-to-one")
  }
  totals
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
  unsupported <- flows[["source_unsupported_utpr"]]
  if (is.null(unsupported)) unsupported <- 0
  stopifnot(
    max(abs(with(flows, source_topup_liability - source_retained_qdmtt -
      source_domestic_iir - source_exported_iir - source_domestic_utpr -
      source_exported_utpr - source_sbs_extinguished - unsupported))) < 1e-4,
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
    conservation <- build_conservation_diagnostics(counterfactual, allocation$revenue_by_channel_global, allocation$unsupported_utpr)
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
      affiliate_cit_rate_unit, stage1_distributional_source,
      any_of("affiliate_cit_robustness_rate")
    ) |>
    mutate(affiliate_cit_rate_unit = panel_statutory_rate(dplyr::pick(everything()), "robustness"))
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
  weights <- read_stage4_utpr_weights()
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

run_econometric_and_reallocation_extensions <- function() {
  run_fiscal_flows_and_stress_tests()
  run_division_bias_and_cit_recovery()
  run_reallocation_and_budget_backtest()
  run_sesh_notch_bunching_diagnostic()
}

if (is_direct_script_run("code/09_econometric_and_reallocation_extensions.R")) {
  run_econometric_and_reallocation_extensions()
}
