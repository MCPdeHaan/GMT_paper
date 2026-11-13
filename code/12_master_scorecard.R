# Thesis and journal paper scorecard with a fixed archived baseline.

source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "11_policy_game_and_variance_extensions.R"), local = TRUE)

# Scorecard assembly

SCORE_THESIS_YEARS <- 2017:2022
SCORE_PAPER_YEARS <- MAIN_YEARS
SCORE_ARCHIVE <- "thesis_value"
SCORE_CURRENT <- "paper_value"
SCORE_OVERLAP <- "paper_2017_2022_value"

score_rds <- function(name, archive = FALSE) {
  readRDS(file.path(if (archive) BASELINE_PROCESSED_DIR else PROCESSED_DIR, paste0(name, ".rds")))
}

score_csv <- function(name, archive = FALSE) {
  read_csv(file.path(if (archive) BASELINE_DIAGNOSTICS_DIR else DIAGNOSTICS_DIR,
    paste0(name, ".csv")), show_col_types = FALSE)
}

# The specification and window identify comparable estimands. The source
# column retains the actual file used, including the thesis archive.
score_metrics <- function(data, stage, topic, vintage, source, units) {
  stopifnot(all(names(units) %in% names(data)))
  if (!"scope" %in% names(data)) data$scope <- "Global"
  if (!"window" %in% names(data)) data$window <- "Full vintage"
  if (!"specification" %in% names(data)) data$specification <- "production"
  if (!"note" %in% names(data)) data$note <- NA_character_
  data |>
    select(scope, window, specification, note, all_of(names(units))) |>
    pivot_longer(all_of(names(units)), names_to = "metric", values_to = "value") |>
    mutate(stage, topic, vintage, source, unit = unname(units[metric]), .before = 1)
}

score_scopes <- function(panel) {
  bind_rows(mutate(panel, scope = "Global"),
    mutate(filter(panel, affiliate_is_eu27), scope = "EU27"))
}

score_windows <- function(data, years, annual = TRUE) {
  data <- filter(data, year %in% years)
  cumulative <- mutate(data, window = "Full vintage")
  if (annual) bind_rows(cumulative, mutate(data, window = as.character(year))) else cumulative
}

score_data_and_stages12 <- function() {
  rows <- list()
  for (vintage in c(SCORE_ARCHIVE, SCORE_CURRENT, SCORE_OVERLAP)) {
    archive <- vintage == SCORE_ARCHIVE
    years <- if (vintage == SCORE_CURRENT) SCORE_PAPER_YEARS else SCORE_THESIS_YEARS
    prefix <- if (archive) "baseline_processed/" else "processed/"
    stage1 <- score_rds("stage1_bilateral_panel", archive)
    stage2 <- score_rds("stage2_bilateral_panel", archive)
    scopes <- score_windows(score_scopes(stage1), years, annual = vintage != SCORE_OVERLAP)
    data <- scopes |>
      summarise(
        pair_years = n(), positive_profit_pair_years = sum(analysis_profit_positive > 0),
        reporting_parents = n_distinct(parent), affiliates = n_distinct(affiliate),
        reported_signed_profit = sum(profit_panelai, na.rm = TRUE),
        corrected_signed_profit = sum(analysis_profit_base, na.rm = TRUE),
        reported_positive_profit = sum(pmax(profit_panelai, 0), na.rm = TRUE),
        corrected_positive_profit = sum(analysis_profit_positive, na.rm = TRUE),
        .by = c(scope, window)
      )
    rows[[paste0(vintage, "_data")]] <- score_metrics(data, "Data", "Sample architecture",
      vintage, paste0(prefix, "stage1_bilateral_panel.rds"),
      c(pair_years = "cells", positive_profit_pair_years = "cells", reporting_parents = "countries",
        affiliates = "countries", reported_signed_profit = "USD", corrected_signed_profit = "USD",
        reported_positive_profit = "USD", corrected_positive_profit = "USD"))
    branches <- list(
      L1 = c("stage1_lowtax_profit_average", "stage1_topup_tax_average"),
      L3 = c("stage1_lowtax_profit_distributional", "stage1_topup_tax_distributional")
    )
    if (!archive) {
      branches <- c(branches, list(
        L2 = c("ladder_l2_lowtax_profit", "ladder_l2_topup_tax"),
        L4_anchored = c("ladder_l4_anchored_lowtax_profit", "ladder_l4_anchored_topup_tax"),
        L4_strict = c("ladder_l4_strict_lowtax_profit", "ladder_l4_strict_topup_tax")
      ))
    }
    stage1_summary <- imap_dfr(branches, function(cols, specification) {
      scopes |>
        summarise(
          profit = sum(analysis_profit_positive, na.rm = TRUE),
          lowtax_profit = sum(.data[[cols[1]]], na.rm = TRUE),
          stage1_liability = sum(.data[[cols[2]]], na.rm = TRUE), .by = c(scope, window)
        ) |>
        mutate(specification, low_share = safe_divide(lowtax_profit, profit),
          topup_gap = safe_divide(stage1_liability, lowtax_profit),
          liability_rate = safe_divide(stage1_liability, profit))
    })
    rows[[paste0(vintage, "_stage1")]] <- score_metrics(stage1_summary, "Stage 1", "ETR ladder",
      vintage, paste0(prefix, "stage1_bilateral_panel.rds"),
      c(low_share = "share", topup_gap = "rate", liability_rate = "rate",
        lowtax_profit = "USD", stage1_liability = "USD"))
    stage2_summary <- score_windows(score_scopes(stage2), years, annual = vintage != SCORE_OVERLAP) |>
      summarise(
        post_sbie_topup = sum(stage2_topup_tax_distributional, na.rm = TRUE),
        pre_sbie_topup = sum(stage1_topup_tax_distributional, na.rm = TRUE),
        profit = sum(analysis_profit_positive, na.rm = TRUE),
        .by = c(scope, window, rate_scenario)
      ) |>
      mutate(specification = rate_scenario, liability_rate = safe_divide(post_sbie_topup, profit),
        sbie_liability_reduction = 1 - safe_divide(post_sbie_topup, pre_sbie_topup))
    rows[[paste0(vintage, "_stage2")]] <- score_metrics(stage2_summary, "Stage 2", "Aggregate SBIE",
      vintage, paste0(prefix, "stage2_bilateral_panel.rds"),
      c(post_sbie_topup = "USD", liability_rate = "rate", sbie_liability_reduction = "share"))
  }
  published <- score_rds("base_panel_t4_bilateral_bracket_shares") |>
    filter(year == 2023L, etr_bracket %in% T4_DIRECT_POSITIVE_BRACKETS)
  coverage <- score_csv("step2_t4_parent_composition") |>
    filter(year == 2023L) |>
    summarise(table4_parents = n_distinct(parent[positive_profit > 0]), .by = scope) |>
    mutate(scope = if_else(tolower(scope) == "eu27", "EU27", "Global"), window = "2023")
  rows$release <- score_metrics(coverage, "Data", "FY2023 vintage",
    SCORE_CURRENT, "processed/diagnostics/step2_t4_parent_composition.csv", c(table4_parents = "countries"))
  table1 <- score_rds("cbcr_table1")
  vintage <- tibble(window = "2023", table4_bilateral_bracket_rows = nrow(published),
    table1_adjusted_profit_rows = sum(table1$year == 2023L & !is.na(table1$profit_adj_panelai)))
  rows$release_totals <- score_metrics(vintage, "Data", "FY2023 vintage", SCORE_CURRENT,
    "processed/base_panel_t4_bilateral_bracket_shares.rds; processed/cbcr_table1.rds",
    c(table4_bilateral_bracket_rows = "rows", table1_adjusted_profit_rows = "rows"))
  bind_rows(rows)
}

score_crossval <- function() {
  name <- "step3_stage1_crossval_summary"
  current <- score_csv(name) |>
    filter(!is.na(sample)) |>
    transmute(stage = "Stage 1", topic = "Table I vs Table IV validation", scope = sample,
      window = "Full vintage", specification = paste(outcome, estimator, sep = " / "),
      metric = statistic, value, vintage = SCORE_CURRENT, source = paste0("processed/diagnostics/", name, ".csv"),
      unit = case_when(statistic == "n" ~ "cells", statistic %in% c("median_gap", "mae", "rmse", "p90_absolute_error") ~ "rate",
        TRUE ~ "statistic"), note = NA_character_)
  keys <- tribble(
    ~archive_key, ~outcome, ~metric,
    "overlap_affiliate_years", "low_share", "n",
    "overlap_affiliate_years", "liability_rate", "n",
    "low_share_median_diff", "low_share", "median_gap",
    "low_share_mae", "low_share", "mae",
    "low_share_rmse", "low_share", "rmse",
    "low_share_p90_abs_error", "low_share", "p90_absolute_error",
    "low_share_spearman", "low_share", "spearman",
    "low_share_calibration_slope", "low_share", "calibration_slope",
    "low_share_calibration_r_squared", "low_share", "calibration_r_squared",
    "liability_rate_median_diff", "liability_rate", "median_gap",
    "liability_rate_mae", "liability_rate", "mae",
    "liability_rate_rmse", "liability_rate", "rmse",
    "liability_rate_p90_abs_error", "liability_rate", "p90_absolute_error",
    "liability_rate_spearman", "liability_rate", "spearman"
  )
  thesis <- score_csv(name, TRUE) |>
    inner_join(keys, by = c("metric" = "archive_key"), relationship = "one-to-many") |>
    transmute(stage = "Stage 1", topic = "Table I vs Table IV validation", scope = "unmatched_affiliate_year",
      window = "Full vintage", specification = paste(outcome, "uncapped", sep = " / "),
      metric = metric.y, value, vintage = SCORE_ARCHIVE, source = paste0("baseline_diagnostics/", name, ".csv"),
      unit = case_when(metric == "n" ~ "cells", metric %in% c("median_gap", "mae", "rmse", "p90_absolute_error") ~ "rate",
        TRUE ~ "statistic"), note = NA_character_)
  rank_name <- "step10_estimator_rank_consistency_audit"
  rank <- score_csv(rank_name) |>
    filter(record_type == "sample_metrics", model %in% c("M1_Baseline", "M1_StatCap_Only", "M1b_RankBounded_Beta")) |>
    mutate(scope = sample, specification = paste(outcome, model, sep = " / "))
  bind_rows(thesis, current,
    score_metrics(rank, "Stage 1", "Percentile rank consistency", SCORE_CURRENT,
      paste0("processed/diagnostics/", rank_name, ".csv"),
      c(n = "cells", rank_violations = "cells", rank_projection_n = "cells",
        table4_share_outside_rank_pct = "percent", p95_above_cap_n = "cells", median_bias = "rate",
        mae = "rate", rmse = "rate", calibration_r_squared = "statistic")))
}

score_stage2_extensions <- function() {
  decomposition <- score_csv("step4_stage2_sbti_vs_sectoral_sbie_decomposition") |>
    mutate(scope = affiliate, window = as.character(year),
      specification = paste(etr_measurement, rate_scenario, sep = " / "))
  stopifnot(setequal(decomposition$year, 2021:2023))
  sectoral <- score_metrics(decomposition, "Stage 2", "Sectoral SBIE and SBTI", SCORE_CURRENT,
    "processed/diagnostics/step4_stage2_sbti_vs_sectoral_sbie_decomposition.csv",
    c(aggregate_sbie_per_profit = "rate", sectoral_sbie_per_profit = "rate",
      sectoral_sbie_sbti_per_profit = "rate", comparable_profit_share = "share",
      sectoral_sbie_effect = "rate", sbti_overlay_effect = "rate"))
  bracket <- score_csv("audit_step4_stage2_bracket_substance")
  sorting <- bracket |>
    filter(!is.na(n_pairs)) |>
    mutate(window = "2019–2023", specification = paste(t4_sample, level, rate_scenario, sep = " / "))
  bracket_sorting <- score_metrics(sorting, "Stage 2", "Within-host Table IV substance sorting",
    SCORE_CURRENT, "processed/diagnostics/audit_step4_stage2_bracket_substance.csv",
    c(n_pairs = "pairs", mean_phi_low = "rate", mean_phi_high = "rate",
      median_phi_difference = "rate", share_low_below_high = "share",
      wilcoxon_p_two_sided = "p-value", wilcoxon_p_less = "p-value",
      fe_estimate = "rate", fe_clustered_se = "rate", fe_clustered_p = "p-value"))
  h5_name <- "step4_stage2_sectoral_h5_panel_regression"
  h5 <- score_csv(h5_name) |>
    filter(term == "sectoral_capital_intensity") |>
    mutate(scope = "EU27", window = case_when(
      sample == "cross_section_2022" ~ "2022", sample == "cross_section_2023" ~ "2023",
      TRUE ~ "2021–2023"
    ), specification = paste(rate_scenario, model_variant, sep = " / "), note = fixed_effects)
  h5_units <- c(estimate = "coefficient", std_error = "coefficient", p_value = "p-value",
    n_obs = "cells", n_clusters = "countries", r_squared = "statistic")
  legacy_name <- "step4_stage2_sectoral_h5_regression_clustered"
  legacy <- score_csv(legacy_name, TRUE) |>
    filter(term == "sectoral_capital_intensity") |>
    mutate(scope = "EU27", window = "2022", specification = paste("initial", model_variant, sep = " / "),
      note = "Archived 2022 reference matrix uses transition year 2024")
  ladder_name <- "step9_ladder_stage1_stage2_summary"
  ladder <- score_csv(ladder_name) |>
    filter(record_type == "summary", scope %in% c("Global", "EU27")) |>
    mutate(specification = level)
  bind_rows(sectoral, bracket_sorting,
    score_metrics(ladder, "Stage 2", "Post-SBIE ETR ladder", SCORE_CURRENT,
      paste0("processed/diagnostics/", ladder_name, ".csv"),
      c(measured_cells = "cells", measured_profit_share = "share",
        stage2_topup_usd_bn_initial = "USD bn", stage2_topup_usd_bn_long_run = "USD bn")),
    score_metrics(h5, "Stage 2", "H5 capital intensity", SCORE_CURRENT,
      paste0("processed/diagnostics/", h5_name, ".csv"), h5_units),
    score_metrics(legacy, "Stage 2", "H5 capital intensity", SCORE_ARCHIVE,
      paste0("baseline_diagnostics/", legacy_name, ".csv"), h5_units))
}

score_stage3 <- function() {
  comparison <- map_dfr(c(FALSE, TRUE), function(archive) {
    vintage <- if (archive) SCORE_ARCHIVE else SCORE_CURRENT
    prefix <- if (archive) "baseline_processed/" else "processed/"
    models <- score_rds("stage3_model_comparison", archive) |>
      mutate(specification = model_spec, n = as.double(n)) |>
      arrange(bic) |>
      mutate(bic_rank = row_number())
    coefficients <- score_rds("stage3_model_coefficients", archive) |>
      filter(term %in% c("tau", "tau_sq", "log_tau"),
        inference == "parent_affiliate_clustered") |>
      mutate(specification = paste(model_spec, term, sep = " / "))
    iv <- score_rds("stage3_tax_endogeneity_diagnostics", archive) |>
      mutate(specification = paste(instrument, diagnostic, inference, term, sep = " / "))
    bind_rows(
      score_metrics(models, "Stage 3", "FE-OLS model choice", vintage,
        paste0(prefix, "stage3_model_comparison.rds"),
        c(n = "cells", n_pairs = "pairs", bic = "statistic", bic_rank = "rank",
          within_r_squared = "statistic")),
      score_metrics(coefficients, "Stage 3", "FE-OLS tax terms", vintage,
        paste0(prefix, "stage3_model_coefficients.rds"),
        c(estimate = "coefficient", std_error = "coefficient", p_value = "p-value")),
      score_metrics(iv, "Stage 3", "IV and endogeneity diagnostics", vintage,
        paste0(prefix, "stage3_tax_endogeneity_diagnostics.rds"),
        c(estimate = "coefficient", std_error = "coefficient", p_value = "p-value",
          weak_instrument_f = "statistic", f_statistic = "statistic", n = "cells"))
    )
  })
  alternative <- score_csv("step5_stage3_alternative_estimators") |>
    filter(statistic_type == "semi_elasticity" | term %in% c("tau", "tau_sq", "log_tau")) |>
    mutate(specification = paste(estimator, sample, model_spec,
      if_else(is.na(tau_eval), term, paste0("tau=", tau_eval)), sep = " / "))
  division <- score_csv("step6_division_bias_and_curvature_audit") |>
    filter(statistic_type == "semi_elasticity" | term %in% c("tau", "tau_sq", "log_tau")) |>
    mutate(specification = paste(regressor, sample, activity, estimator, model_spec,
      if_else(is.na(tau_eval), term, paste0("tau=", tau_eval)), sep = " / "),
      bic_winner = as.integer(bic_winner),
      note = if_else(covariance_repaired, "Two-way covariance repaired", NA_character_))
  compression <- score_csv("step7_pre_implementation_compression_test") |>
    mutate(scope = outcome, window = "2022–2023 diagnostic",
      specification = paste(sample, model, term, sep = " / "),
      note = estimate_unit)
  bind_rows(comparison,
    score_metrics(alternative, "Stage 3", "Alternative estimators", SCORE_CURRENT,
      "processed/diagnostics/step5_stage3_alternative_estimators.csv",
      c(estimate = "coefficient", std_error = "coefficient", n = "cells", bic = "statistic")),
    score_metrics(division, "Stage 3", "Division bias and curvature", SCORE_CURRENT,
      "processed/diagnostics/step6_division_bias_and_curvature_audit.csv",
      c(estimate = "coefficient", std_error = "coefficient", p_value = "p-value", n = "cells",
        bic = "statistic", delta_bic = "statistic", bic_winner = "indicator",
        joint_tax_wald_p = "p-value")),
    score_metrics(compression, "Stage 3", "Pre-implementation compression", SCORE_CURRENT,
      "processed/diagnostics/step7_pre_implementation_compression_test.csv",
      c(estimate = "pp per 10 pp exposure", clustered_se = "pp per 10 pp exposure",
        p_value = "p-value", post_joint_p = "p-value", observations = "cells")))
}

score_factorials <- function() {
  baseline <- score_rds("stage4_6_shapley_factor_attribution", TRUE) |>
    mutate(scope = "EU27", specification = paste("32 scenarios", effect, sep = " / "))
  splits <- score_csv("step7_decomposition_architecture_stress_test") |>
    mutate(scope = "EU27",
      window = if_else(start_year == min(MAIN_YEARS), "Full vintage",
        paste(start_year, end_year, sep = "–")),
      specification = paste(case_when(
        variant == "A_baseline" ~ "32 scenarios",
        variant == "D_split_substance" ~ "64 scenarios, split SBTI",
        TRUE ~ variant
      ), effect, sep = " / "))
  ladder <- score_csv("step9_ladder_anova_decomposition") |>
    mutate(scope = "EU27", specification = paste(design, effect, sep = " / "))
  fiscal <- score_csv("step6_anova_total_fiscal_revenue_rule_b") |>
    filter(interaction_order == 1) |>
    mutate(scope = "EU27", window = paste(start_year, end_year, sep = "–"),
      specification = paste(outcome, effect, sep = " / "),
      main_eta_squared = eta_squared)
  overlap_anova <- score_rds("stage4_5_revenue_country_year") |>
    filter(year %in% SCORE_THESIS_YEARS) |>
    compute_factorial_anova()
  overlap <- build_shapley_factor_attribution(overlap_anova$pooled) |>
    mutate(scope = "EU27", specification = paste("32 scenarios", effect, sep = " / "))
  units <- c(main_eta_squared = "share", shapley_eta_squared = "share")
  bind_rows(
    score_metrics(baseline, "Stage 4.6", "ANOVA and Shapley", SCORE_ARCHIVE,
      "baseline_processed/stage4_6_shapley_factor_attribution.rds", units),
    score_metrics(splits, "Stage 4.6", "ANOVA and Shapley", SCORE_CURRENT,
      "processed/diagnostics/step7_decomposition_architecture_stress_test.csv", units),
    score_metrics(overlap, "Stage 4.6", "ANOVA and Shapley", SCORE_OVERLAP,
      "processed/stage4_5_revenue_country_year.rds", units),
    score_metrics(ladder, "Stage 4.6", "Ladder ANOVA and Helmert contrasts", SCORE_CURRENT,
      "processed/diagnostics/step9_ladder_anova_decomposition.csv", units),
    score_metrics(fiscal, "Stage 4.6", "Rule B total fiscal revenue ANOVA", SCORE_CURRENT,
      "processed/diagnostics/step6_anova_total_fiscal_revenue_rule_b.csv", units)
  )
}

score_allocation_ledger <- function(archive, years) {
  source <- score_rds("stage4_5_allocation_source_panel", archive) |>
    filter(scenario_id %in% PREFERRED_STAGE5_IDS, year %in% years) |>
    select(scenario_id, year, parent, affiliate, analysis_profit_positive,
      stage1_lowtax_profit_distributional, topup_after_behaviour, stage4_qdmtt_liability,
      stage4_iir_liability, stage4_utpr_pool, stage4_sbs_extinguished_liability)
  weights <- list(
    parent_year_weights = score_rds("stage4_5_utpr_parent_year_weights", archive),
    fallback_weights = score_rds("stage4_5_utpr_fallback_weights", archive)
  )
  legal <- score_csv("step5_stage3_policy_flags", archive) |>
    transmute(country = jurisdiction, qdmtt_by_2026, iir_by_2026)
  build_stage5_ledger(source, weights, score_rds("stage4_5_revenue_country_year", archive),
    score_rds("stage4_5_revenue_by_channel", archive),
    build_cit_revenue_denominators(score_rds("cit_revenue", archive)), legal, years)
}

score_fiscal_flows <- function() {
  ledger_units <- c(positive_corrected_affiliate_profit = "USD",
    distributional_low_taxed_profit = "USD", source_topup_liability = "USD",
    source_retained_qdmtt = "USD", source_domestic_iir = "USD", source_exported_iir = "USD",
    source_domestic_utpr = "USD", source_exported_utpr = "USD", source_sbs_extinguished = "USD",
    collector_revenue = "USD", collector_QDMTT = "USD", collector_IIR = "USD",
    collector_UTPR = "USD", cit_revenue_T_1200 = "USD", net_fiscal_position = "USD",
    collector_revenue_pct_of_cit = "percent", cit_years_observed = "years", min_revenue = "USD", max_revenue = "USD",
    scenario_spread = "USD", qdmtt_by_2026 = "indicator", iir_by_2026 = "indicator")
  ledger <- map_dfr(c(SCORE_ARCHIVE, SCORE_CURRENT, SCORE_OVERLAP), function(vintage) {
    archive <- vintage == SCORE_ARCHIVE
    if (vintage == SCORE_CURRENT) {
      data <- bind_rows(
        mutate(score_csv("step7_eu27_source_vs_collector_ledger_2017_2023"), window = "Full vintage"),
        mutate(score_csv("step7_eu27_source_vs_collector_ledger_2023"), window = "2023")
      )
      source <- "processed/diagnostics/step7_eu27_source_vs_collector_ledger_{2017_2023,2023}.csv"
    } else {
      data <- mutate(score_allocation_ledger(archive, SCORE_THESIS_YEARS), window = "Full vintage")
      source <- paste0(if (archive) "baseline_processed/" else "processed/",
        "stage4_5_allocation_source_panel.rds; revenue and CIT archives for the same vintage")
    }
    data <- data |>
      mutate(scope = country, specification = scenario_id, across(c(qdmtt_by_2026, iir_by_2026), as.integer))
    score_metrics(data, "Stage 4.5", "Source and collector ledger", vintage, source, ledger_units)
  })
  scenario_totals <- map_dfr(c(SCORE_ARCHIVE, SCORE_CURRENT, SCORE_OVERLAP), function(vintage) {
    archive <- vintage == SCORE_ARCHIVE
    years <- if (vintage == SCORE_CURRENT) SCORE_PAPER_YEARS else SCORE_THESIS_YEARS
    revenue <- score_rds("stage4_5_revenue_country_year", archive) |>
      score_windows(years, annual = vintage == SCORE_CURRENT) |>
      summarise(direct_topup = sum(revenue), .by = c(window, scenario_id)) |>
      mutate(scope = "EU27", specification = scenario_id)
    bounds <- revenue |>
      summarise(min_scenario_revenue = min(direct_topup), max_scenario_revenue = max(direct_topup),
        .by = c(scope, window))
    source <- paste0(if (archive) "baseline_processed/" else "processed/",
      "stage4_5_revenue_country_year.rds")
    bind_rows(
      score_metrics(revenue, "Stage 4.5", "32-scenario collector revenue", vintage, source, c(direct_topup = "USD")),
      score_metrics(bounds, "Stage 4.5", "32-scenario bounds", vintage, source,
        c(min_scenario_revenue = "USD", max_scenario_revenue = "USD"))
    )
  })
  legal <- score_csv("step7_cyprus_and_article50_sensitivity") |>
    mutate(scope = country, window = if_else(start_year == end_year, as.character(end_year), "Full vintage"),
      specification = paste(scenario_id, regime, sep = " / "),
      qdmtt_active = as.integer(qdmtt_active), iir_active = as.integer(iir_active))
  recovery <- score_csv("step6_topup_vs_cit_recovery_rule_b_eu27") |>
    filter(country == "EU27" | scenario_id %in% PREFERRED_STAGE5_IDS) |>
    mutate(scope = country, specification = scenario_id,
      window = if_else(start_year == end_year, as.character(end_year), "Full vintage"))
  thesis_destinations <- score_rds("stage3_reallocation_matrix", TRUE) |>
    filter(destination %in% EU27_ISO3) |>
    rename(country = destination) |>
    summarise(ordinary_cit_gross_destination_revenue = sum(ordinary_cit_gross_destination_revenue),
      .by = c(scenario_id, year, country))
  thesis_fiscal <- score_rds("stage4_5_revenue_country_year", TRUE) |>
    left_join(thesis_destinations, by = c("scenario_id", "year", "country"), relationship = "one-to-one") |>
    mutate(ordinary_cit_gross_destination_revenue = coalesce_zero(ordinary_cit_gross_destination_revenue)) |>
    summarise(direct_topup = sum(revenue),
      ordinary_cit_gross_destination_revenue = sum(ordinary_cit_gross_destination_revenue),
      .by = c(country, scenario_id))
  thesis_fiscal <- bind_rows(
    filter(thesis_fiscal, scenario_id %in% PREFERRED_STAGE5_IDS),
    summarise(thesis_fiscal, across(c(direct_topup, ordinary_cit_gross_destination_revenue), sum),
      .by = scenario_id) |> mutate(country = "EU27")
  ) |>
    mutate(scope = country, specification = scenario_id,
      total_fiscal_revenue = direct_topup + ordinary_cit_gross_destination_revenue,
      note = "Thesis ordinary CIT uses global-pool conduit-excluding Rule A")
  budgets <- score_csv("step9_ladder_budget_backtest") |>
    mutate(scope = country, specification = paste(level, benchmark, sep = " / "),
      note = paste(forecast_period, comparison_scope, paste("Closest scenario", closest_scenario), source_url, sep = " | "),
      official_interval_overlaps_model_range = as.integer(official_interval_overlaps_model_range))
  dutch_cit <- score_csv("step7_reallocation_destination_rules_comparison") |>
    filter(country == "NLD", rule == "B", start_year == 2019L, end_year == 2023L) |>
    mutate(scope = country, window = "2019–2023 annualised", specification = scenario_id,
      rule_b_gross_eur_bn = gross_cit / (5 * 1.0813 * 1e9),
      official_october_2026_induced_cit_eur_bn = if_else(scenario_id == "x10001", .451, .397),
      official_2023_induced_cit_eur_bn = if_else(scenario_id == "x10001", .402, NA_real_),
      note = paste("October 2026 post-package forecast also includes the incentive safe harbour.",
        "https://zoek.officielebekendmakingen.nl/dossier/kst-1275297.pdf#page=44"))
  ladder_sbs_name <- "step9_ladder_sbs_exposure"
  ladder_sbs <- score_csv(ladder_sbs_name) |>
    mutate(specification = level)
  bind_rows(ledger, scenario_totals,
    score_metrics(ladder_sbs, "Stage 4.5", "Side-by-Side exposure by ETR ladder", SCORE_CURRENT,
      paste0("processed/diagnostics/", ladder_sbs_name, ".csv"),
      c(source_topup_usd_universal = "USD", us_parent_source_share_universal = "share",
        sbs_extinguished_source_usd_sbs = "USD", direct_collector_usd_universal = "USD",
        direct_collector_usd_sbs = "USD", collector_reduction_usd = "USD", collector_reduction_share = "share")),
    score_metrics(legal, "Stage 4.5", "Cyprus and Article 50 legal regimes", SCORE_CURRENT,
      "processed/diagnostics/step7_cyprus_and_article50_sensitivity.csv",
      c(source_topup_liability = "USD", collector_revenue = "USD", collector_QDMTT = "USD",
        collector_IIR = "USD", collector_UTPR = "USD", collector_revenue_change_vs_baseline = "USD",
        qdmtt_active = "indicator", iir_active = "indicator")),
    score_metrics(recovery, "Stage 4.6", "Rule B direct top-up and ordinary CIT", SCORE_CURRENT,
      "processed/diagnostics/step6_topup_vs_cit_recovery_rule_b_eu27.csv",
      c(direct_topup = "USD", mechanical_direct_topup = "USD", direct_topup_lost_total = "USD",
        direct_topup_lost_reallocation = "USD", direct_topup_lost_bunching = "USD",
        ordinary_cit_gross_destination_revenue = "USD", ordinary_cit_source_loss = "USD",
        ordinary_cit_net_by_incidence = "USD", total_fiscal_revenue = "USD",
        total_fiscal_revenue_net_by_incidence = "USD", total_fiscal_gain_vs_mechanical = "USD",
        total_fiscal_gain_vs_mechanical_net_by_incidence = "USD", global_fallback_profit_received = "USD")),
    score_metrics(thesis_fiscal, "Stage 4.6", "Rule B direct top-up and ordinary CIT", SCORE_ARCHIVE,
      "baseline_processed/stage3_reallocation_matrix.rds; baseline_processed/stage4_5_revenue_country_year.rds",
      c(direct_topup = "USD", ordinary_cit_gross_destination_revenue = "USD", total_fiscal_revenue = "USD")),
    score_metrics(budgets, "Stage 4.6", "National budget backtest", SCORE_CURRENT,
      "processed/diagnostics/step9_ladder_budget_backtest.csv",
      c(official_low_eur_bn = "EUR bn", official_high_eur_bn = "EUR bn", scenario_min_eur_bn = "EUR bn",
        scenario_max_eur_bn = "EUR bn", preferred_universal_eur_bn = "EUR bn",
        preferred_sbs_eur_bn = "EUR bn", closest_scenario_eur_bn = "EUR bn",
        closest_gap_eur_bn = "EUR bn", official_interval_overlaps_model_range = "indicator")),
    score_metrics(dutch_cit, "Stage 4.6", "Dutch behavioural CIT benchmark", SCORE_CURRENT,
      "processed/diagnostics/step7_reallocation_destination_rules_comparison.csv",
      c(rule_b_gross_eur_bn = "EUR bn", official_october_2026_induced_cit_eur_bn = "EUR bn",
        official_2023_induced_cit_eur_bn = "EUR bn"))
  )
}

score_steps12_to_15 <- function() {
  read_extension <- function(stem) read_csv(file.path(DIAGNOSTICS_DIR, paste0(stem, ".csv")),
    show_col_types = FALSE, guess_max = Inf)
  extension <- function(data, stage, topic, stem, units) {
    score_metrics(data, stage, topic, SCORE_CURRENT,
      file.path("processed/diagnostics", paste0(stem, ".csv")), units)
  }
  waterfall_stem <- "step12_cbcr_to_budget_waterfall_bridge"
  waterfall <- read_extension(waterfall_stem) |>
    filter(record_type == "waterfall", scope %in% c("EU27", EU27_ISO3)) |>
    mutate(specification = step, collector_usd_bn = collector / 1e9,
      qdmtt_usd_bn = qdmtt / 1e9, source_topup_usd_bn = source_topup / 1e9,
      change_vs_baseline_usd_bn = collector_change_from_baseline / 1e9,
      note = "Preferred SbS; distinct accounting, tax timing and safe-harbour steps")
  trends_stem <- "step12_conduit_unwinding_time_series_2017_2026"
  trends <- read_extension(trends_stem) |>
    filter(record_type %in% c("annual_observation", "historical_mean", "trend_projection")) |>
    mutate(scope = affiliate, window = period, specification = if_else(
      is.na(parent), record_type, paste(record_type, parent, sep = " / ")),
      corrected_profit_usd_bn = corrected_profit / 1e9, low_profit_usd_bn = low_profit / 1e9)
  deviation_stem <- "step13_unilateral_qdmtt_deviation_matrix"
  deviation <- read_extension(deviation_stem) |>
    mutate(scope = country, specification = paste(level, regime, deviation, sep = " / "),
      qdmtt_foregone_usd_bn = -delta_qdmtt / 1e9, foreign_soakup_usd_bn = foreign_soakup / 1e9,
      mne_topup_saved_usd_bn = mne_topup_saved / 1e9,
      retained_source_cit_usd_bn = retained_source_cit / 1e9,
      note = benchmark)
  strategy_stem <- "step13_qdmtt_vs_sbti_strategy_comparison"
  strategy <- read_extension(strategy_stem) |>
    mutate(scope = country, specification = paste(level, regime, sep = " / "),
      overlay_topup_relief_usd_bn = overlay_topup_relief / 1e9,
      overlay_foreign_leakage_usd_bn = overlay_foreign_leakage / 1e9,
      new_qti_mne_tax_relief_usd_bn = new_qti_mne_tax_relief / 1e9,
      note = benchmark)
  blending_stem <- "step14_table3_vs_table4_blending_wedge"
  blending <- read_extension(blending_stem) |>
    filter(record == "matched_summary", sample == "matched_observed_partitions",
      window %in% c("2019–2023", "2023")) |>
    mutate(specification = resolution,
      low_share_wedge = juris_share_common - group_share_common,
      group_topup_usd_bn = group_worldwide_gap_topup_common_usd / 1e9,
      juris_topup_usd_bn = juris_topup_common_usd_on_group_gap_support / 1e9,
      note = "Matched reporters and common Stage 1 profit weights")
  usa <- read_extension(blending_stem) |>
    filter(record == "standalone_summary", scope == "USA_EU27", table == "IV",
      window %in% c("2019–2023", "2023")) |>
    mutate(specification = "Table IV only", low_usd_bn = low_usd / 1e9,
      topup_usd_bn = local_gap_proxy_usd / 1e9, note = "No US-parent Table III coverage")
  size_stem <- "step14_table6_mne_size_incidence"
  size <- read_extension(size_stem) |>
    filter(record == "size_summary", sample == "complete_fine", window == "2022–2023",
      observations > 0L) |>
    mutate(specification = size_class, note = "Complete fine bins; worldwide UPR in USD")
  iqm_stem <- "step14_table2_interquartile_skewness"
  iqm <- read_extension(iqm_stem) |>
    filter(record == "matched_summary", sample == "same_counts_multiple_of_4_min_8",
      window == "2018–2023", scope %in% c("EU27", "Global")) |>
    mutate(specification = sample, note = "Upper-quartile bounds conditional on exact-half trim")
  activity_stem <- "step14_business_activity_drivers"
  activity <- read_extension(activity_stem) |>
    filter(record == "activity_regression", term == "act_holding_panelai",
      outcome %in% c("l4", "phi"), fixed_effects != "affiliate + year") |>
    mutate(specification = paste(outcome, fixed_effects, sep = " / "))
  variance_stem <- "step15_law_of_total_variance_decomposition"
  variance <- read_extension(variance_stem)
  variance_total <- variance |> filter(record == "total_variance") |>
    mutate(specification = "Equal-weight 32 scenarios / 500 joint draws",
      note = "Cumulative collector revenue; proposal ratio uses point-estimate spread")
  variance_components <- variance |> filter(record %in%
    c("parameter_shapley", "one_at_a_time", "orthogonal_parameter")) |>
    mutate(specification = paste(record, component, sep = " / "))
  factorial_stem <- "step15_globe_accounting_factorial_anova"
  factorial <- read_extension(factorial_stem) |> filter(record == "main_effect") |>
    mutate(specification = paste(distributional_level, design, estimand, effect, sep = " / "))
  bind_rows(
    extension(waterfall, "Step 12", "Accounting and safe-harbour waterfall", waterfall_stem,
      c(collector_usd_bn = "USD bn", qdmtt_usd_bn = "USD bn", source_topup_usd_bn = "USD bn",
        change_vs_baseline_usd_bn = "USD bn")),
    extension(trends, "Step 12", "Conduit profit and revenue trend", trends_stem,
      c(corrected_profit_usd_bn = "USD bn", low_profit_usd_bn = "USD bn", low_share = "share",
        qdmtt_eur_bn = "EUR bn", collector_eur_bn = "EUR bn")),
    extension(deviation, "Step 13", "Unilateral QDMTT deviation", deviation_stem,
      c(qdmtt_foregone_usd_bn = "USD bn", foreign_soakup_usd_bn = "USD bn",
        mne_topup_saved_usd_bn = "USD bn", retained_source_cit_usd_bn = "USD bn",
        tax_cut_efficiency = "ratio", critical_welfare_weight = "ratio")),
    extension(strategy, "Step 13", "QDMTT and SBTI strategy", strategy_stem,
      c(overlay_topup_relief_usd_bn = "USD bn", overlay_foreign_leakage_usd_bn = "USD bn",
        new_qti_mne_tax_relief_usd_bn = "USD bn", overlay_efficiency = "ratio")),
    extension(blending, "Step 14", "Worldwide versus jurisdictional blending", blending_stem,
      c(matched_pair_years = "cells", group_share_common = "share", juris_share_common = "share",
        low_share_wedge = "share", group_topup_usd_bn = "USD bn", juris_topup_usd_bn = "USD bn")),
    extension(usa, "Step 14", "US-parented EU27 Table IV", blending_stem,
      c(observations = "cells", low_share = "share", low_usd_bn = "USD bn", topup_usd_bn = "USD bn")),
    extension(size, "Step 14", "Worldwide revenue-band incidence", size_stem,
      c(positive_cell_profit_usd_share = "share", positive_cell_etr = "rate", phi_initial = "share",
        post_sbie_initial_rate = "rate", post_sbie_initial_topup_usd_share = "share")),
    extension(iqm, "Step 14", "Interquartile profit concentration", iqm_stem,
      c(tail_proxy_n = "cells", profit_weighted_etr_gap = "rate",
        outer_both_tails_weighted_proxy = "share", upper_tail_weighted_lb_conditional = "share",
        upper_tail_weighted_ub_conditional = "share")),
    extension(activity, "Step 14", "Holding activity and liability or substance", activity_stem,
      c(outcome_pp_per_10pp_activity = "pp per 10 pp", se_pp_per_10pp_activity = "pp per 10 pp",
        p_value_holm_within_model = "p-value")),
    extension(variance_total, "Step 15", "Joint scenario and parameter variance", variance_stem,
      c(total_variance_usd_bn_sq = "USD bn squared", scenario_variance_share = "share",
        parameter_variance_share = "share", point_scenario_spread_usd_bn = "USD bn",
        preferred_p05_usd_bn = "USD bn", preferred_p95_usd_bn = "USD bn", proposal_ratio = "ratio")),
    extension(variance_components, "Step 15", "Sources of parameter variance", variance_stem,
      c(component_variance_usd_bn_sq = "USD bn squared", component_share_of_parameter_variance = "share")),
    extension(factorial, "Step 15", "Accounting factorial effects", factorial_stem,
      c(main_eta_squared = "share", shapley_eta_squared = "share", dollar_main_effect_usd_bn = "USD bn",
        preferred_baseline_usd_bn = "USD bn", preferred_globe_usd_bn = "USD bn"))
  )
}

run_master_paper_scorecard <- function() {
  data <- bind_rows(score_data_and_stages12(), score_crossval(), score_stage2_extensions(),
    score_stage3(), score_factorials(), score_fiscal_flows(), score_steps12_to_15())
  keys <- c("stage", "topic", "scope", "window", "specification", "metric", "unit")
  assert_unique_keys(data, c(keys, "vintage"), "Scorecard measures")
  output <- data |>
    pivot_wider(id_cols = all_of(keys), names_from = vintage, values_from = c(value, source, note),
      names_glue = "{vintage}_{.value}") |>
    rename(thesis_value = thesis_value_value, paper_value = paper_value_value,
      paper_2017_2022_value = paper_2017_2022_value_value,
      thesis_source = thesis_value_source, paper_source = paper_value_source,
      paper_2017_2022_source = paper_2017_2022_value_source,
      thesis_note = thesis_value_note, paper_note = paper_value_note) |>
    mutate(
      thesis_vintage = "2017–2022",
      paper_vintage = "2017–2023",
      paper_minus_thesis = paper_value - thesis_value,
      paper_2017_2022_minus_thesis = paper_2017_2022_value - thesis_value,
      comparison = case_when(
        is.na(thesis_source) ~ "paper diagnostic",
        is.na(paper_source) ~ "thesis archive only",
        window == "Full vintage" ~ "different vintage windows",
        TRUE ~ "same labelled period"
      )
    ) |>
    select(-paper_2017_2022_value_note) |>
    arrange(stage, topic, scope, window, specification, metric)
  stopifnot(is.double(output$thesis_value), is.double(output$paper_value),
    n_distinct(output$scope[output$topic == "Source and collector ledger"]) == 27)
  write_csv(output, file.path(DIAGNOSTICS_DIR, "master_paper_v2_scorecard.csv"))
  message("Master scorecard written with ", nrow(output), " comparable or explicitly vintage-specific measures")
}

run_scorecard <- function() run_master_paper_scorecard()

if (is_direct_script_run("code/12_master_scorecard.R")) {
  run_scorecard()
}
