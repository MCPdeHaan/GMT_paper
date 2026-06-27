# 06_stage4_5_revenue_allocation_sbs.R
# Step 6 of the methodology pipeline.
#
# Implements the revenue allocation and Side-by-Side package on top of the
# Stage 3 pre-allocation liability matrix. The script keeps the legal
# QDMTT/IIR/UTPR waterfall separate from the behavioural model and replaces
# the earlier source-country UTPR proxy with a parent-year substance-weighted
# UTPR allocation.
library(dplyr)
library(tidyr)
library(readr)
library(tibble)

source("code/00_helpers.R")

dir.create(DIAGNOSTICS_DIR, showWarnings = FALSE, recursive = TRUE)

compute_utpr_raw_weight <- function(employee_share, asset_share) {
  case_when(
    !is.na(employee_share) & !is.na(asset_share) ~
      0.50 * employee_share + 0.50 * asset_share,
    !is.na(employee_share) ~ employee_share,
    !is.na(asset_share) ~ asset_share,
    TRUE ~ NA_real_
  )
}

normalise_positive_weights <- function(weight) {
  total <- sum(weight, na.rm = TRUE)
  if (is.na(total) || total <= 0) {
    return(rep(NA_real_, length(weight)))
  }
  weight / total
}

allocation_regime <- function(topup_after_behaviour, qdmtt_flag,
                              parent_iir_utpr_flag, sbs_exempt) {
  case_when(
    is.na(topup_after_behaviour) | topup_after_behaviour <= 0 ~ "zero",
    qdmtt_flag ~ "qdmtt",
    !qdmtt_flag & parent_iir_utpr_flag & !sbs_exempt ~ "iir",
    !qdmtt_flag & !parent_iir_utpr_flag & !sbs_exempt ~ "utpr",
    !qdmtt_flag & sbs_exempt ~ "sbs_extinguished",
    TRUE ~ "unclassified"
  )
}

build_source_panel <- function(stage3_panel) {
  source_panel <- stage3_panel |>
    mutate(
      qdmtt_flag = coalesce(qdmtt_flag, FALSE),
      parent_iir_utpr_flag = coalesce(parent_iir_utpr_flag, FALSE),
      sbs_exempt = coalesce(sbs_exempt, FALSE),
      topup_after_behaviour = pmax(coalesce_zero(topup_after_behaviour), 0),
      stage4_allocation_regime = allocation_regime(
        topup_after_behaviour,
        qdmtt_flag,
        parent_iir_utpr_flag,
        sbs_exempt
      ),
      stage4_qdmtt_liability = if_else(
        stage4_allocation_regime == "qdmtt",
        topup_after_behaviour,
        0
      ),
      stage4_iir_liability = if_else(
        stage4_allocation_regime == "iir",
        topup_after_behaviour,
        0
      ),
      stage4_utpr_pool = if_else(
        stage4_allocation_regime == "utpr",
        topup_after_behaviour,
        0
      ),
      stage4_sbs_extinguished_liability = if_else(
        stage4_allocation_regime == "sbs_extinguished",
        topup_after_behaviour,
        0
      ),
      stage4_zero_liability = if_else(
        stage4_allocation_regime == "zero",
        topup_after_behaviour,
        0
      ),
      stage4_conservation_gap =
        stage4_qdmtt_liability + stage4_iir_liability + stage4_utpr_pool +
          stage4_sbs_extinguished_liability + stage4_zero_liability -
          topup_after_behaviour
    )

  if (any(source_panel$stage4_allocation_regime == "unclassified", na.rm = TRUE)) {
    stop("Stage 4.5 allocation left positive liabilities unclassified")
  }

  if (max(abs(source_panel$stage4_conservation_gap), na.rm = TRUE) > 1e-6) {
    stop("Stage 4.5 source-level allocation does not conserve liability")
  }

  source_panel
}

build_collector_activity <- function(stage3_panel) {
  stage3_panel |>
    distinct(
      parent,
      collector = affiliate,
      year,
      collector_name = affiliate_jurisdiction_name,
      employees_sbie,
      assets_sbie,
      affiliate_policy_iir_utpr_by_2026,
      affiliate_policy_utpr_by_2026,
      affiliate_policy_iir_utpr_explicit_by_2026,
      affiliate_policy_iir_utpr_ambiguous_by_2026,
      affiliate_oecd_iir_by_2026
    ) |>
    mutate(
      collector_is_eu27 = collector %in% EU27_ISO3,
      collector_utpr_flag = coalesce(
        affiliate_policy_iir_utpr_by_2026,
        affiliate_oecd_iir_by_2026,
        FALSE
      ),
      collector_utpr_explicit_flag = coalesce(
        affiliate_policy_utpr_by_2026,
        affiliate_policy_iir_utpr_explicit_by_2026,
        FALSE
      ),
      collector_utpr_ambiguous_flag =
        collector_utpr_flag & !collector_utpr_explicit_flag,
      employee_base = pmax(coalesce_zero(employees_sbie), 0),
      asset_base = pmax(coalesce_zero(assets_sbie), 0)
    )
}

build_parent_year_utpr_weights <- function(collector_activity) {
  parent_year_weights <- collector_activity |>
    filter(collector_utpr_flag) |>
    group_by(parent, year) |>
    mutate(
      employee_total = sum(employee_base, na.rm = TRUE),
      asset_total = sum(asset_base, na.rm = TRUE),
      employee_share = if_else(employee_total > 0,
        employee_base / employee_total,
        NA_real_
      ),
      asset_share = if_else(asset_total > 0,
        asset_base / asset_total,
        NA_real_
      ),
      raw_weight = compute_utpr_raw_weight(employee_share, asset_share),
      utpr_weight = normalise_positive_weights(raw_weight),
      utpr_weight_source = "parent_year"
    ) |>
    ungroup() |>
    filter(!is.na(utpr_weight), utpr_weight > 0) |>
    select(
      parent, year, collector, collector_name, collector_is_eu27,
      collector_utpr_explicit_flag, collector_utpr_ambiguous_flag,
      employee_share, asset_share, raw_weight, utpr_weight,
      utpr_weight_source
    )

  fallback_weights <- collector_activity |>
    filter(collector_utpr_flag) |>
    group_by(year, collector, collector_name, collector_is_eu27) |>
    summarise(
      employee_base = sum(employee_base, na.rm = TRUE),
      asset_base = sum(asset_base, na.rm = TRUE),
      collector_utpr_explicit_flag =
        any(collector_utpr_explicit_flag, na.rm = TRUE),
      collector_utpr_ambiguous_flag =
        any(collector_utpr_ambiguous_flag, na.rm = TRUE),
      .groups = "drop"
    ) |>
    group_by(year) |>
    mutate(
      employee_total = sum(employee_base, na.rm = TRUE),
      asset_total = sum(asset_base, na.rm = TRUE),
      employee_share = if_else(employee_total > 0,
        employee_base / employee_total,
        NA_real_
      ),
      asset_share = if_else(asset_total > 0,
        asset_base / asset_total,
        NA_real_
      ),
      raw_weight = compute_utpr_raw_weight(employee_share, asset_share),
      utpr_weight = normalise_positive_weights(raw_weight),
      utpr_weight_source = "global_year_fallback"
    ) |>
    ungroup() |>
    filter(!is.na(utpr_weight), utpr_weight > 0) |>
    select(
      year, collector, collector_name, collector_is_eu27,
      collector_utpr_explicit_flag, collector_utpr_ambiguous_flag,
      employee_share, asset_share, raw_weight, utpr_weight,
      utpr_weight_source
    )

  parent_year_check <- parent_year_weights |>
    group_by(parent, year) |>
    summarise(weight_sum = sum(utpr_weight, na.rm = TRUE), .groups = "drop")

  fallback_check <- fallback_weights |>
    group_by(year) |>
    summarise(weight_sum = sum(utpr_weight, na.rm = TRUE), .groups = "drop")

  if (any(abs(parent_year_check$weight_sum - 1) > 1e-8, na.rm = TRUE)) {
    stop("Parent-year UTPR weights do not sum to one")
  }

  if (any(abs(fallback_check$weight_sum - 1) > 1e-8, na.rm = TRUE)) {
    stop("Fallback UTPR weights do not sum to one")
  }

  list(
    parent_year_weights = parent_year_weights,
    fallback_weights = fallback_weights
  )
}

allocate_stage4_revenue <- function(source_panel, utpr_weights) {
  qdmtt_allocation <- source_panel |>
    filter(stage4_qdmtt_liability > 0) |>
    group_by(across(all_of(SCENARIO_VARS)),
      country = affiliate, country_name = affiliate_jurisdiction_name,
      year
    ) |>
    summarise(
      revenue = sum(stage4_qdmtt_liability, na.rm = TRUE),
      source_rows = n(),
      .groups = "drop"
    ) |>
    mutate(channel = "QDMTT", allocation_weight_source = "source_qdmtt")

  iir_allocation <- source_panel |>
    filter(stage4_iir_liability > 0) |>
    group_by(across(all_of(SCENARIO_VARS)),
      country = parent, country_name = parent_jurisdiction_name,
      year
    ) |>
    summarise(
      revenue = sum(stage4_iir_liability, na.rm = TRUE),
      source_rows = n(),
      .groups = "drop"
    ) |>
    mutate(channel = "IIR", allocation_weight_source = "parent_iir")

  utpr_pool <- source_panel |>
    filter(stage4_utpr_pool > 0) |>
    group_by(across(all_of(SCENARIO_VARS)), parent, year) |>
    summarise(
      utpr_pool = sum(stage4_utpr_pool, na.rm = TRUE),
      source_rows = n(),
      source_affiliates = n_distinct(affiliate),
      .groups = "drop"
    )

  parent_year_keys <- utpr_weights$parent_year_weights |>
    distinct(parent, year)

  utpr_parent_year <- utpr_pool |>
    semi_join(parent_year_keys, by = c("parent", "year")) |>
    # Intended expansion: one parent-year UTPR pool is split across all
    # collecting jurisdictions with positive parent-year substance weights.
    left_join(
      utpr_weights$parent_year_weights,
      by = c("parent", "year"),
      relationship = "many-to-many"
    ) |>
    mutate(revenue = utpr_pool * utpr_weight)

  utpr_fallback <- utpr_pool |>
    anti_join(parent_year_keys, by = c("parent", "year")) |>
    # Intended expansion: when parent-year weights are unavailable, the pool is
    # split across year-level fallback collectors with positive substance weights.
    left_join(
      utpr_weights$fallback_weights,
      by = "year",
      relationship = "many-to-many"
    ) |>
    mutate(revenue = utpr_pool * utpr_weight)

  utpr_pool_check <- bind_rows(utpr_parent_year, utpr_fallback) |>
    group_by(across(all_of(SCENARIO_VARS)), parent, year) |>
    summarise(
      allocated_utpr_pool = sum(revenue, na.rm = TRUE),
      .groups = "drop"
    ) |>
    left_join(utpr_pool, by = c(SCENARIO_VARS, "parent", "year")) |>
    mutate(utpr_pool_gap = allocated_utpr_pool - utpr_pool)

  if (max(abs(utpr_pool_check$utpr_pool_gap), na.rm = TRUE) > 1e-3) {
    stop("Stage 4.5 UTPR expansion does not conserve the UTPR pool")
  }

  utpr_allocation <- bind_rows(utpr_parent_year, utpr_fallback) |>
    group_by(across(all_of(SCENARIO_VARS)),
      country = collector, country_name = collector_name, year,
      allocation_weight_source = utpr_weight_source,
      collector_utpr_explicit_flag,
      collector_utpr_ambiguous_flag
    ) |>
    summarise(
      revenue = sum(revenue, na.rm = TRUE),
      source_rows = sum(source_rows, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(channel = "UTPR")

  revenue_by_channel_global <- bind_rows(
    qdmtt_allocation,
    iir_allocation,
    utpr_allocation
  ) |>
    mutate(country_is_eu27 = country %in% EU27_ISO3) |>
    select(
      all_of(SCENARIO_VARS), country, country_name, country_is_eu27,
      year, channel, allocation_weight_source,
      collector_utpr_explicit_flag, collector_utpr_ambiguous_flag,
      revenue, source_rows
    )

  revenue_by_channel_eu27 <- revenue_by_channel_global |>
    filter(country_is_eu27) |>
    group_by(
      across(all_of(SCENARIO_VARS)), country, country_name,
      year, channel
    ) |>
    summarise(revenue = sum(revenue, na.rm = TRUE), .groups = "drop")

  country_lookup <- source_panel |>
    filter(affiliate %in% EU27_ISO3) |>
    distinct(
      country = affiliate,
      country_name = affiliate_jurisdiction_name
    )

  revenue_country_year_eu27 <- revenue_by_channel_eu27 |>
    group_by(across(all_of(SCENARIO_VARS)), country, year) |>
    summarise(revenue = sum(revenue, na.rm = TRUE), .groups = "drop") |>
    complete(
      nesting(!!!syms(SCENARIO_VARS)),
      country = EU27_ISO3,
      year = MAIN_YEARS,
      fill = list(revenue = 0)
    ) |>
    left_join(country_lookup, by = "country") |>
    relocate(country_name, .after = country)

  list(
    revenue_by_channel_global = revenue_by_channel_global,
    revenue_by_channel_eu27 = revenue_by_channel_eu27,
    revenue_country_year_eu27 = revenue_country_year_eu27,
    utpr_pool = utpr_pool
  )
}

build_conservation_diagnostics <- function(source_panel, revenue_global) {
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
      residual_gap = allocated_topup + sbs_extinguished_topup + zero_liability -
        pre_allocation_topup
    )

  if (max(abs(conservation$residual_gap), na.rm = TRUE) > 1e-3) {
    stop("Stage 4.5 global allocation does not conserve liability")
  }

  conservation
}

build_sbs_source_exposure <- function(source_panel) {
  source_panel |>
    filter(affiliate %in% EU27_ISO3) |>
    group_by(across(all_of(SCENARIO_VARS)),
      source_country = affiliate,
      source_country_name = affiliate_jurisdiction_name,
      year,
      source_qdmtt = qdmtt_flag
    ) |>
    summarise(
      total_topup_after_behaviour = sum(topup_after_behaviour, na.rm = TRUE),
      us_parented_topup = sum(
        if_else(parent == "USA", topup_after_behaviour, 0),
        na.rm = TRUE
      ),
      sbs_extinguished_topup = sum(stage4_sbs_extinguished_liability,
        na.rm = TRUE
      ),
      us_parented_extinguished_topup = sum(
        if_else(parent == "USA", stage4_sbs_extinguished_liability, 0),
        na.rm = TRUE
      ),
      us_parented_topup_share = safe_divide(
        us_parented_topup,
        total_topup_after_behaviour
      ),
      .groups = "drop"
    )
}

build_policy_ambiguity_diagnostics <- function(source_panel, revenue_global) {
  iir_ambiguity <- source_panel |>
    group_by(across(all_of(SCENARIO_VARS))) |>
    summarise(
      total_iir_liability = sum(stage4_iir_liability, na.rm = TRUE),
      iir_liability_from_ambiguous_parent_flag = sum(
        if_else(
          coalesce(parent_iir_utpr_ambiguous_flag, FALSE),
          stage4_iir_liability,
          0
        ),
        na.rm = TRUE
      ),
      iir_ambiguous_share = safe_divide(
        iir_liability_from_ambiguous_parent_flag,
        total_iir_liability
      ),
      .groups = "drop"
    )

  utpr_ambiguity <- revenue_global |>
    filter(channel == "UTPR") |>
    group_by(across(all_of(SCENARIO_VARS))) |>
    summarise(
      total_utpr_allocated = sum(revenue, na.rm = TRUE),
      utpr_allocated_to_ambiguous_collector = sum(
        if_else(
          coalesce(collector_utpr_ambiguous_flag, FALSE),
          revenue,
          0
        ),
        na.rm = TRUE
      ),
      utpr_ambiguous_collector_share = safe_divide(
        utpr_allocated_to_ambiguous_collector,
        total_utpr_allocated
      ),
      .groups = "drop"
    )

  iir_ambiguity |>
    left_join(utpr_ambiguity, by = SCENARIO_VARS) |>
    mutate(
      total_utpr_allocated = coalesce_zero(total_utpr_allocated),
      utpr_allocated_to_ambiguous_collector =
        coalesce_zero(utpr_allocated_to_ambiguous_collector),
      policy_diagnostic_note =
        "Shares identify revenue that relies on broad tracker top-up rows rather than explicit IIR or UTPR labels."
    )
}

run_stage4_5_h4_tests <- function(revenue_country_year_eu27, source_panel) {
  other_factors <- c(
    "rate_scenario", "factor1_etr", "factor2_substance",
    "factor5_behaviour", "country", "country_name", "year"
  )

  h4_pairs <- revenue_country_year_eu27 |>
    select(all_of(other_factors), factor4_sbs, revenue) |>
    pivot_wider(names_from = factor4_sbs, values_from = revenue) |>
    mutate(delta_sbs_minus_universal = sbs - universal)

  wt_two_sided <- stats::wilcox.test(
    h4_pairs$delta_sbs_minus_universal,
    mu = 0,
    exact = FALSE
  )
  wt_less <- stats::wilcox.test(
    h4_pairs$delta_sbs_minus_universal,
    mu = 0,
    exact = FALSE,
    alternative = "less"
  )

  collector_exposure <- source_panel |>
    filter(
      affiliate %in% EU27_ISO3,
      factor1_etr == "distributional",
      factor2_substance == "aggregate_sbie",
      rate_scenario == "initial",
      factor4_sbs == "universal",
      factor5_behaviour == "mechanical"
    ) |>
    group_by(country = affiliate) |>
    summarise(
      source_total_topup = sum(topup_after_behaviour, na.rm = TRUE),
      source_us_parented_topup = sum(
        if_else(parent == "USA", topup_after_behaviour, 0),
        na.rm = TRUE
      ),
      source_qdmtt = any(qdmtt_flag, na.rm = TRUE),
      source_us_parented_topup_share =
        safe_divide(source_us_parented_topup, source_total_topup),
      .groups = "drop"
    )

  pre_sbs_utpr_collection <- revenue_country_year_eu27 |>
    filter(
      factor1_etr == "distributional",
      factor2_substance == "aggregate_sbie",
      rate_scenario == "initial",
      factor4_sbs == "universal",
      factor5_behaviour == "mechanical"
    ) |>
    group_by(country) |>
    summarise(
      preferred_scenario_revenue = sum(revenue, na.rm = TRUE),
      .groups = "drop"
    )

  h4_country <- h4_pairs |>
    group_by(country, country_name) |>
    summarise(
      mean_delta_sbs_minus_universal =
        mean(delta_sbs_minus_universal, na.rm = TRUE),
      .groups = "drop"
    ) |>
    left_join(collector_exposure, by = "country") |>
    left_join(pre_sbs_utpr_collection, by = "country") |>
    mutate(
      source_qdmtt = coalesce(source_qdmtt, FALSE),
      source_us_parented_topup_share =
        coalesce(source_us_parented_topup_share, 0),
      preferred_scenario_revenue = coalesce(preferred_scenario_revenue, 0)
    )

  h4_fit <- stats::lm(
    mean_delta_sbs_minus_universal ~ source_qdmtt +
      source_us_parented_topup_share + preferred_scenario_revenue,
    data = h4_country
  )

  h4_regression <- as.data.frame(summary(h4_fit)$coefficients) |>
    rownames_to_column("term") |>
    as_tibble() |>
    rename(
      estimate = Estimate,
      std_error = `Std. Error`,
      statistic = `t value`,
      p_value = `Pr(>|t|)`
    ) |>
    mutate(
      n_obs = stats::nobs(h4_fit),
      r_squared = summary(h4_fit)$r.squared
    )

  list(
    paired_differences = h4_pairs,
    country_regression_sample = h4_country,
    test_summary = tibble(
      test = "wilcoxon_sbs_minus_universal_stage4_5",
      n = length(h4_pairs$delta_sbs_minus_universal),
      mean_delta = mean(h4_pairs$delta_sbs_minus_universal, na.rm = TRUE),
      median_delta = stats::median(h4_pairs$delta_sbs_minus_universal,
        na.rm = TRUE
      ),
      statistic = unname(wt_two_sided$statistic),
      p_value_two_sided = wt_two_sided$p.value,
      p_value_less = wt_less$p.value
    ),
    regression = h4_regression
  )
}

run_stage4_5_pipeline <- function() {
  stage3_panel <- readRDS(file.path(PROCESSED_DIR, "stage3_factorial_pair_year.rds"))

  assert_unique_keys(
    stage3_panel,
    c(SCENARIO_VARS, "parent", "affiliate", "year"),
    "stage3 factorial pair-year input"
  )

  source_panel <- build_source_panel(stage3_panel)
  collector_activity <- build_collector_activity(stage3_panel)
  utpr_weights <- build_parent_year_utpr_weights(collector_activity)
  allocation_objects <- allocate_stage4_revenue(source_panel, utpr_weights)

  conservation <- build_conservation_diagnostics(
    source_panel,
    allocation_objects$revenue_by_channel_global
  )

  h4_objects <- run_stage4_5_h4_tests(
    allocation_objects$revenue_country_year_eu27,
    source_panel
  )

  sbs_source_exposure <- build_sbs_source_exposure(source_panel)
  policy_ambiguity <- build_policy_ambiguity_diagnostics(
    source_panel,
    allocation_objects$revenue_by_channel_global
  )

  scenario_summary <- allocation_objects$revenue_country_year_eu27 |>
    group_by(across(all_of(SCENARIO_VARS))) |>
    summarise(
      eu_revenue = sum(revenue, na.rm = TRUE),
      country_years = n(),
      .groups = "drop"
    ) |>
    arrange(scenario_id)

  channel_summary <- allocation_objects$revenue_by_channel_eu27 |>
    group_by(channel, factor4_sbs) |>
    summarise(
      nonzero_country_year_scenarios = sum(revenue > 0, na.rm = TRUE),
      country_year_scenarios = n(),
      revenue = sum(revenue, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(channel, factor4_sbs)

  utpr_weight_summary <- bind_rows(
    utpr_weights$parent_year_weights |>
      group_by(weight_source = utpr_weight_source) |>
      summarise(
        parent_years = n_distinct(paste(parent, year)),
        rows = n(),
        min_weight_sum = min(tapply(utpr_weight, paste(parent, year), sum)),
        max_weight_sum = max(tapply(utpr_weight, paste(parent, year), sum)),
        eu27_weight_mean = mean(
          tapply(
            if_else(collector_is_eu27, utpr_weight, 0),
            paste(parent, year),
            sum
          ),
          na.rm = TRUE
        ),
        .groups = "drop"
      ),
    utpr_weights$fallback_weights |>
      group_by(weight_source = utpr_weight_source) |>
      summarise(
        parent_years = NA_integer_,
        rows = n(),
        min_weight_sum = min(tapply(utpr_weight, year, sum)),
        max_weight_sum = max(tapply(utpr_weight, year, sum)),
        eu27_weight_mean = mean(
          tapply(if_else(collector_is_eu27, utpr_weight, 0), year, sum),
          na.rm = TRUE
        ),
        .groups = "drop"
      )
  )

  stage4_5_summary <- tibble(
    metric = c(
      "factorial_scenarios",
      "eu27_country_year_revenue_rows",
      "global_allocation_conservation_max_abs_gap",
      "utpr_parent_year_weight_rows",
      "utpr_fallback_weight_rows",
      "h4_mean_delta_sbs_minus_universal",
      "h4_median_delta_sbs_minus_universal",
      "h4_wilcoxon_less_p_value",
      "max_iir_ambiguous_parent_flag_share",
      "max_utpr_ambiguous_collector_share",
      "eu_revenue_min_scenario",
      "eu_revenue_max_scenario"
    ),
    value = c(
      n_distinct(scenario_summary$scenario_id),
      nrow(allocation_objects$revenue_country_year_eu27),
      max(abs(conservation$residual_gap), na.rm = TRUE),
      nrow(utpr_weights$parent_year_weights),
      nrow(utpr_weights$fallback_weights),
      h4_objects$test_summary$mean_delta,
      h4_objects$test_summary$median_delta,
      h4_objects$test_summary$p_value_less,
      max(policy_ambiguity$iir_ambiguous_share, na.rm = TRUE),
      max(policy_ambiguity$utpr_ambiguous_collector_share, na.rm = TRUE),
      min(scenario_summary$eu_revenue, na.rm = TRUE),
      max(scenario_summary$eu_revenue, na.rm = TRUE)
    )
  )

  write_csv(
    stage4_5_summary,
    file.path(DIAGNOSTICS_DIR, "step6_stage4_5_summary.csv")
  )
  write_csv(
    scenario_summary,
    file.path(DIAGNOSTICS_DIR, "step6_stage4_5_scenario_summary.csv")
  )
  write_csv(
    channel_summary,
    file.path(DIAGNOSTICS_DIR, "step6_stage4_5_channel_summary.csv")
  )
  write_csv(
    conservation,
    file.path(DIAGNOSTICS_DIR, "step6_stage4_5_conservation_by_scenario.csv")
  )
  write_csv(
    utpr_weight_summary,
    file.path(DIAGNOSTICS_DIR, "step6_stage4_5_utpr_weight_summary.csv")
  )
  write_csv(
    h4_objects$test_summary,
    file.path(DIAGNOSTICS_DIR, "step6_stage4_5_h4_wilcoxon.csv")
  )
  write_csv(
    h4_objects$country_regression_sample,
    file.path(DIAGNOSTICS_DIR, "step6_stage4_5_h4_country_regression_sample.csv")
  )
  write_csv(
    h4_objects$regression,
    file.path(DIAGNOSTICS_DIR, "step6_stage4_5_h4_regression.csv")
  )
  write_csv(
    sbs_source_exposure,
    file.path(DIAGNOSTICS_DIR, "step6_stage4_5_sbs_source_exposure.csv")
  )
  write_csv(
    policy_ambiguity,
    file.path(DIAGNOSTICS_DIR, "step6_stage4_5_policy_ambiguity.csv")
  )

  saveRDS(source_panel, file.path(PROCESSED_DIR, "stage4_5_allocation_source_panel.rds"))
  saveRDS(
    utpr_weights$parent_year_weights,
    file.path(PROCESSED_DIR, "stage4_5_utpr_parent_year_weights.rds")
  )
  saveRDS(
    utpr_weights$fallback_weights,
    file.path(PROCESSED_DIR, "stage4_5_utpr_fallback_weights.rds")
  )
  saveRDS(
    allocation_objects$revenue_by_channel_global,
    file.path(PROCESSED_DIR, "stage4_5_revenue_by_channel_global.rds")
  )
  saveRDS(
    allocation_objects$revenue_by_channel_eu27,
    file.path(PROCESSED_DIR, "stage4_5_revenue_by_channel.rds")
  )
  saveRDS(
    allocation_objects$revenue_country_year_eu27,
    file.path(PROCESSED_DIR, "stage4_5_revenue_country_year.rds")
  )
  saveRDS(conservation, file.path(PROCESSED_DIR, "stage4_5_allocation_conservation.rds"))
  saveRDS(
    sbs_source_exposure,
    file.path(PROCESSED_DIR, "stage4_5_sbs_source_exposure.rds")
  )
  saveRDS(
    policy_ambiguity,
    file.path(PROCESSED_DIR, "stage4_5_policy_ambiguity.rds")
  )

  message("\nStep 6 outputs written:")
  message(" - data/processed/stage4_5_revenue_by_channel.rds")
  message(" - data/processed/stage4_5_revenue_country_year.rds")
  message(" - data/processed/stage4_5_utpr_parent_year_weights.rds")
  message(" - diagnostics/step6_stage4_5_*.csv")
}

