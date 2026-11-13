# Run from the repository root after Stage 4.6. Inputs are read-only.
source("code/03_stage1_etr.R", local = TRUE)
source("code/diagnostics_step5_revenue_architecture.R", local = TRUE)

LADDER_HOSTS <- c("NLD", "LUX", "IRL", "DEU", "FRA", "BEL")
LADDER_BUDGET_COUNTRIES <- c(LADDER_HOSTS, "AUT", "SVK")
LADDER_WINDOWS <- list(
  "2017–2023" = MAIN_YEARS, "2019–2023" = DIRECT_YEARS,
  "2021–2023" = PERCENTILE_YEARS, "FY2023" = max(MAIN_YEARS)
)
LADDER_EUR_USD <- 1.0813

ladder_read <- function(stem) readRDS(file.path(PROCESSED_DIR, paste0(stem, ".rds")))

ladder_write <- function(data, stem) {
  write_csv(data, file.path(DIAGNOSTICS_DIR, paste0("step9_", stem, ".csv")))
}

ladder_windows <- function(data, windows = LADDER_WINDOWS) {
  imap_dfr(windows, function(years, window) {
    data |> filter(year %in% years) |> mutate(window = window, years_in_window = length(years))
  })
}

ladder_apply_sbie <- function(measurement, stage2) {
  stage2 |>
    left_join(
      select(measurement, all_of(LADDER_KEYS), share, gap, low_profit, stage1_tax),
      by = LADDER_KEYS, relationship = "many-to-one"
    ) |>
    mutate(
      sbie_filter = 1 - coalesce(stage2_phi, 0),
      excess_low_profit = low_profit * sbie_filter,
      stage2_tax = stage1_tax * sbie_filter
    )
}

ladder_rebuild_scenarios <- function(measurement, post_sbie, factorial, host_stage1, sectors, beta) {
  host_rates <- measurement |>
    summarise(
      host_share = safe_divide(sum(low_profit), sum(analysis_profit_positive)),
      host_gap = coalesce(safe_divide(sum(stage1_tax), sum(low_profit)), 0),
      .by = c(affiliate, year)
    )
  updated_host <- host_stage1 |>
    left_join(host_rates, by = c("affiliate", "year"), relationship = "one-to-one") |>
    mutate(stage1_distributional_low_share = host_share, stage1_distributional_topup_rate = host_gap)
  updated_sectors <- sectors |>
    select(-stage1_distributional_topup_rate) |>
    left_join(select(updated_host, affiliate, year, stage1_distributional_topup_rate),
      by = c("affiliate", "year"), relationship = "many-to-one")
  bridge <- build_sectoral_factor2_bridge(
    mutate(post_sbie, stage2_topup_tax_distributional = stage2_tax), updated_host, updated_sectors
  )
  scenarios <- factorial |>
    filter(x1_etr == 1) |>
    left_join(
      select(post_sbie, all_of(LADDER_KEYS), rate_scenario, share, gap, low_profit,
        excess_low_profit, stage2_tax),
      by = c(LADDER_KEYS, "rate_scenario"), relationship = "many-to-one"
    ) |>
    left_join(
      select(bridge, affiliate, year, rate_scenario, ladder_scale = sectoral_scale_distributional),
      by = c("affiliate", "year", "rate_scenario"), relationship = "many-to-one"
    ) |>
    mutate(
      stage1_distributional_low_share = share,
      stage1_lowtax_profit_distributional = low_profit,
      stage2_excess_lowtax_profit_distributional = excess_low_profit,
      stage2_topup_selected = stage2_tax,
      sectoral_scale_selected = if_else(x2_substance == 0, 1, coalesce(ladder_scale, 1)),
      topup_after_stage2 = stage2_topup_selected * sectoral_scale_selected,
      # The behavioural threshold and slope are evaluated at each cell's
      # own implied low-tax ETR in the bilateral levels.
      tau_low = if_else(share > 0 & gap > 0, GMT_RATE - gap, NA_real_)
    )
  raw_beta <- coalesce(compute_reallocation_share(
    scenarios$tau_low, rep_len("linear", nrow(scenarios)), beta
  ), 0)
  replace_behaviour_schedule(scenarios, scenarios$tau_low, raw_beta) |>
    select(all_of(names(factorial)))
}

ladder_allocate <- function(panel, weights) {
  source <- build_source_panel(panel)
  allocation <- allocate_stage4_revenue(source, weights)
  conservation <- build_conservation_diagnostics(source, allocation$revenue_by_channel_global)
  stopifnot(nrow(allocation$revenue_country_year_eu27) == length(EU27_ISO3) * length(MAIN_YEARS) * 16)
  list(
    revenue = allocation$revenue_country_year_eu27,
    channels = allocation$revenue_by_channel_eu27,
    conservation = conservation,
    preferred_source = source |>
      filter(x2_substance == 0, x3_rates == 0, x5_behaviour == 1) |>
      select(all_of(LADDER_KEYS), x4_sbs, topup_after_behaviour,
        stage4_qdmtt_liability, stage4_iir_liability, stage4_utpr_pool,
        stage4_sbs_extinguished_liability)
  )
}

ladder_stage_summary <- function(measurements, post_sbie) {
  scopes <- bind_rows(
    mutate(measurements, scope = "Global"),
    mutate(filter(measurements, affiliate_is_eu27), scope = "EU27")
  ) |>
    filter(analysis_profit_positive > 0) |>
    ladder_windows()
  totals <- scopes |>
    summarise(
      positive_cells = n(), measured_cells = sum(measured),
      positive_profit_usd = sum(analysis_profit_positive),
      measured_profit_usd = sum(analysis_profit_positive[measured]),
      lowtax_profit_usd = sum(low_profit), stage1_topup_usd = sum(stage1_tax),
      .by = c(level, scope, window, years_in_window)
    ) |>
    mutate(
      record_type = "summary",
      measured_profit_share = measured_profit_usd / positive_profit_usd,
      low_share = lowtax_profit_usd / positive_profit_usd,
      topup_gap = safe_divide(stage1_topup_usd, lowtax_profit_usd),
      liability_rate = stage1_topup_usd / positive_profit_usd
    )
  sbie_totals <- bind_rows(mutate(post_sbie, scope = "Global"),
    mutate(filter(post_sbie, affiliate_is_eu27), scope = "EU27")) |>
    ladder_windows() |>
    summarise(stage2_topup_usd_bn = sum(stage2_tax) / 1e9,
      .by = c(level, scope, window, rate_scenario)
    ) |>
    pivot_wider(names_from = rate_scenario, values_from = stage2_topup_usd_bn,
      names_prefix = "stage2_topup_usd_bn_")
  tiers <- scopes |>
    summarise(
      positive_cells = n(), positive_profit_usd = sum(analysis_profit_positive),
      lowtax_profit_usd = sum(low_profit), stage1_topup_usd = sum(stage1_tax),
      percentile_fit_rank_violations = sum(percentile_fit_rank_violation),
      rank_violation_profit_usd = sum(analysis_profit_positive[percentile_fit_rank_violation]),
      .by = c(level, scope, window, years_in_window, source_tier)
    ) |>
    group_by(level, scope, window) |>
    mutate(tier_profit_share = positive_profit_usd / sum(positive_profit_usd)) |>
    ungroup() |>
    mutate(record_type = "coverage_by_tier")
  bind_rows(left_join(totals, sbie_totals, by = c("level", "scope", "window"),
    relationship = "one-to-one"), tiers) |>
    relocate(record_type, level, scope, window, source_tier)
}

ladder_parent_breakdown <- function(measurements, preferred_source, cells) {
  detail <- preferred_source |>
    filter(x4_sbs == 1, affiliate %in% LADDER_HOSTS, year %in% PERCENTILE_YEARS) |>
    select(level, all_of(LADDER_KEYS), stage4_qdmtt_liability) |>
    inner_join(measurements, by = c("level", LADDER_KEYS), relationship = "one-to-one") |>
    filter(analysis_profit_positive > 0) |>
    mutate(parent_group = case_when(
      parent == affiliate ~ "domestic",
      parent == "USA" ~ "us_parents",
      TRUE ~ "other_foreign"
    ))
  aggregates <- detail |>
    ladder_windows(LADDER_WINDOWS[c("2021–2023", "FY2023")]) |>
    summarise(
      across(c(analysis_profit_positive, low_profit, stage1_tax, stage4_qdmtt_liability), sum),
      positive_cells = n(),
      .by = c(level, affiliate, window, years_in_window, parent_group)
    ) |>
    group_by(level, affiliate, window) |>
    mutate(qdmtt_parent_group_share = safe_divide(stage4_qdmtt_liability, sum(stage4_qdmtt_liability))) |>
    ungroup() |>
    mutate(record_type = "parent_group")
  selected <- detail |>
    filter(
      (parent == affiliate & affiliate %in% c("NLD", "LUX", "DEU", "FRA")) |
        (affiliate == "NLD" & parent %in% c("GBR", "DEU", "USA"))
    ) |>
    left_join(
      select(cells, all_of(LADDER_KEYS), all_of(LADDER_QUANTILES), etr_panelai_raw,
        etr_panelai_stage1, has_panelai_percentiles, percentile_source, fitted_precision,
        transport_candidate_precision = selected_precision, pair_precision, host_year_precision,
        host_median_precision, fit_rmse, percentile_rank_lower, percentile_rank_upper),
      by = LADDER_KEYS, relationship = "many-to-one"
    ) |>
    mutate(record_type = "cell_year", window = paste0("FY", year), years_in_window = 1L)
  bind_rows(aggregates, selected) |>
    mutate(
      qdmtt_eur_bn = stage4_qdmtt_liability / LADDER_EUR_USD / 1e9,
      qdmtt_annualised_eur_bn = qdmtt_eur_bn / years_in_window
    ) |>
    relocate(record_type, level, affiliate, parent, parent_group, year, window) |>
    arrange(record_type, level, affiliate, window, parent_group, parent)
}

ladder_sbs_summary <- function(preferred_source, preferred_revenue) {
  sources <- bind_rows(
    mutate(preferred_source, scope = "Global"),
    mutate(filter(preferred_source, affiliate %in% EU27_ISO3), scope = "EU27"),
    mutate(filter(preferred_source, affiliate %in% EU27_ISO3), scope = affiliate)
  ) |>
    ladder_windows() |>
    summarise(
      source_topup_usd = sum(topup_after_behaviour),
      us_parent_source_usd = sum(topup_after_behaviour[parent == "USA"]),
      sbs_extinguished_source_usd = sum(stage4_sbs_extinguished_liability),
      source_qdmtt_usd = sum(stage4_qdmtt_liability),
      source_iir_usd = sum(stage4_iir_liability),
      source_utpr_usd = sum(stage4_utpr_pool),
      .by = c(level, scope, window, years_in_window, x4_sbs)
    ) |>
    mutate(
      us_parent_source_share = safe_divide(us_parent_source_usd, source_topup_usd),
      sbs_extinguished_source_share = safe_divide(sbs_extinguished_source_usd, source_topup_usd)
    )
  collectors <- bind_rows(
    mutate(preferred_revenue, scope = country),
    mutate(preferred_revenue, scope = "EU27")
  ) |>
    ladder_windows() |>
    summarise(direct_collector_usd = sum(revenue), .by = c(level, scope, window, x4_sbs))
  sources |>
    left_join(collectors, by = c("level", "scope", "window", "x4_sbs"), relationship = "one-to-one") |>
    mutate(regime = if_else(x4_sbs == 1, "sbs", "universal")) |>
    select(-x4_sbs) |>
    pivot_wider(
      names_from = regime, names_glue = "{.value}_{regime}",
      values_from = c(source_topup_usd, us_parent_source_usd, sbs_extinguished_source_usd,
        source_qdmtt_usd, source_iir_usd, source_utpr_usd, us_parent_source_share,
        sbs_extinguished_source_share, direct_collector_usd)
    ) |>
    mutate(
      collector_reduction_usd = direct_collector_usd_universal - direct_collector_usd_sbs,
      collector_reduction_share = safe_divide(collector_reduction_usd, direct_collector_usd_universal)
    ) |>
    arrange(level, scope, window)
}

ladder_official_forecasts <- function() {
  forecasts <- read_csv(file.path(DIAGNOSTICS_DIR, "step7_official_budget_forecasts_backtest.csv"),
    show_col_types = FALSE
  ) |>
    filter(window == "FY2023", country %in% LADDER_BUDGET_COUNTRIES,
      startsWith(evidence, "official") | evidence %in% c("implied by official figures", "academic estimate")
    ) |>
    select(country, benchmark, evidence, forecast_period, revenue_scope, model_scope,
      comparison_scope, official_low_eur_bn, official_high_eur_bn, stated_sbs_switch, source_url)
  luxembourg <- tibble(
    country = "LUX", benchmark = "Luxembourg 2026 budget Pillar Two minimum tax",
    evidence = "official forecast", forecast_period = "2026 cash",
    revenue_scope = "Pillar Two minimum tax, channels not disaggregated", model_scope = "direct",
    comparison_scope = "Direct collector revenue compared to the Pillar Two budget line",
    official_low_eur_bn = 0.080, official_high_eur_bn = 0.080,
    source_url = paste0("https://budget.public.lu/dam-assets/lb/budget2026/",
      "links-dokumenter/lu-ppb-2026.pdf")
  )
  slovakia <- tibble(
    country = "SVK", benchmark = "Slovakia 2026 state budget Pillar Two line",
    evidence = "official forecast", forecast_period = "2026 state budget",
    revenue_scope = "Global minimum tax budget line", model_scope = "direct",
    comparison_scope = "Direct collector revenue compared to the Pillar Two budget line",
    official_low_eur_bn = 0.0485, official_high_eur_bn = 0.0485,
    source_url = "https://www.mfsr.sk/files/archiv/44/Text.pdf"
  )
  bind_rows(forecasts, luxembourg, slovakia)
}

ladder_budget_backtest <- function(revenue, channels) {
  scenario_keys <- c("level", "country", "year", "scenario_id")
  channel_totals <- channels |>
    filter(country %in% LADDER_BUDGET_COUNTRIES) |>
    summarise(qdmt = sum(revenue[channel == "QDMTT"]),
      iir = sum(revenue[channel == "IIR"]), .by = all_of(scenario_keys)
    )
  matched <- revenue |>
    filter(country %in% LADDER_BUDGET_COUNTRIES) |>
    select(all_of(scenario_keys), all_of(FACTOR_COLS), direct = revenue) |>
    left_join(channel_totals, by = scenario_keys, relationship = "one-to-one") |>
    mutate(across(c(qdmt, iir), ~ coalesce(.x, 0))) |>
    ladder_windows(LADDER_WINDOWS[c("2019–2023", "FY2023")]) |>
    summarise(across(c(direct, qdmt, iir), ~ sum(.x) / first(years_in_window) / LADDER_EUR_USD / 1e9),
      .by = c(level, country, window, scenario_id, all_of(FACTOR_COLS))
    ) |>
    pivot_longer(c(direct, qdmt, iir), names_to = "model_scope", values_to = "annual_eur_bn") |>
    inner_join(ladder_official_forecasts(), by = c("country", "model_scope"),
      relationship = "many-to-many"
    ) |>
    mutate(
      gap_to_benchmark_eur_bn = pmax(official_low_eur_bn - annual_eur_bn,
        annual_eur_bn - official_high_eur_bn, 0),
      preferred = x2_substance == 0 & x3_rates == 0 & x5_behaviour == 1
    )
  matched |>
    arrange(gap_to_benchmark_eur_bn, scenario_id) |>
    summarise(
      official_low_eur_bn = first(official_low_eur_bn),
      official_high_eur_bn = first(official_high_eur_bn),
      stated_sbs_switch = first(stated_sbs_switch),
      source_url = first(source_url),
      scenario_min_eur_bn = min(annual_eur_bn), scenario_max_eur_bn = max(annual_eur_bn),
      preferred_universal_eur_bn = annual_eur_bn[preferred & x4_sbs == 0],
      preferred_sbs_eur_bn = annual_eur_bn[preferred & x4_sbs == 1],
      closest_scenario = if_else(is.finite(first(gap_to_benchmark_eur_bn)), first(scenario_id), NA_character_),
      closest_scenario_eur_bn = if_else(is.na(closest_scenario), NA_real_, first(annual_eur_bn)),
      closest_gap_eur_bn = first(gap_to_benchmark_eur_bn),
      .by = c(level, country, window, benchmark, evidence, forecast_period, revenue_scope, model_scope,
        comparison_scope)
    ) |>
    mutate(
      official_interval_overlaps_model_range = official_high_eur_bn >= scenario_min_eur_bn &
        official_low_eur_bn <= scenario_max_eur_bn,
      preferred_policy_comparable_eur_bn = case_when(
        stated_sbs_switch == 0 ~ preferred_universal_eur_bn,
        stated_sbs_switch == 1 ~ preferred_sbs_eur_bn
      )
    ) |>
    arrange(country, benchmark, window, level)
}

ladder_binary_stage46 <- function(low, high) {
  objects <- map(c("revenue", "channels", "conservation"), function(component) {
    bind_rows(
      mutate(low[[component]], x1_etr = 0L, factor1_etr = "average"),
      mutate(high[[component]], x1_etr = 1L, factor1_etr = "distributional")
    ) |>
      mutate(scenario_id = paste0("x", x1_etr, x2_substance, x3_rates, x4_sbs, x5_behaviour))
  })
  validation <- validate_revenue_inputs(objects[[1]], objects[[2]], objects[[3]])
  tibble(
    max_global_conservation_gap_usd =
      as.numeric(validation$value[validation$metric == "max_global_conservation_gap"]),
    max_country_channel_gap_usd =
      as.numeric(validation$value[validation$metric == "max_country_channel_gap"])
  )
}

ladder_anova <- function(revenue, level_order, design_name, validation) {
  factor_names <- FACTOR_COLS
  binary_factors <- factor_names[-1]
  n_levels <- length(level_order)
  dimensions <- c(n_levels, rep(2L, length(binary_factors)))
  design_rows <- revenue |>
    filter(level %in% level_order) |>
    distinct(level, across(all_of(binary_factors))) |>
    mutate(level_index = match(level, level_order)) |>
    arrange(level_index, across(all_of(binary_factors))) |>
    mutate(design_id = paste0("design_", row_number()))
  stopifnot(nrow(design_rows) == prod(dimensions))

  # Adjacent pairwise differences overlap, so they cannot all be orthogonal.
  # Gram–Schmidt in the requested order gives these Helmert contrasts.
  first_basis <- cbind(1, contr.helmert(n_levels))
  first_basis <- sweep(first_basis, 2, sqrt(colSums(first_basis^2)), "/")
  binary_basis <- cbind(1, c(-1, 1)) / sqrt(2)
  bases <- c(list(first_basis[design_rows$level_index, , drop = FALSE]),
    map(binary_factors, ~ binary_basis[design_rows[[.x]] + 1L, , drop = FALSE]))
  term_indices <- as.matrix(do.call(expand.grid, lapply(dimensions, seq_len)))
  contrast_matrix <- apply(term_indices, 1, function(indices) {
    Reduce(`*`, map(seq_along(bases), ~ bases[[.x]][, indices[.x]]))
  })
  stopifnot(max(abs(crossprod(contrast_matrix) - diag(nrow(design_rows)))) < 1e-12)
  term_order <- rowSums(term_indices > 1)

  wide <- revenue |>
    filter(level %in% level_order) |>
    inner_join(design_rows, by = c("level", binary_factors), relationship = "many-to-one") |>
    select(country, year, design_id, revenue) |>
    pivot_wider(names_from = design_id, values_from = revenue)
  y <- t(as.matrix(wide[design_rows$design_id]))
  stopifnot(ncol(y) == length(EU27_ISO3) * length(MAIN_YEARS), all(is.finite(y)))
  weights <- c("−1, +1, 0, 0", "−1, −1, +2, 0", "−1, −1, −1, +3")
  contrast_labels <- c("1a_cross_parent", "1b_within_cell", "1c_parent_selection")
  imap_dfr(LADDER_WINDOWS[1:3], function(years, window) {
    window_y <- y[, wide$year %in% years, drop = FALSE]
    ss <- rowSums(crossprod(contrast_matrix, window_y)^2)
    total_ss <- sum(sweep(window_y, 2, colMeans(window_y))^2)
    stopifnot(abs(sum(ss[term_order > 0]) / total_ss - 1) < 1e-12)
    eta <- ss / total_ss
    factor_rows <- map_dfr(seq_along(factor_names), function(i) {
      included <- term_indices[, i] > 1
      tibble(
        record_type = "factor", effect = factor_names[i],
        main_eta_squared = sum(eta[included & term_order == 1]),
        shapley_eta_squared = sum(eta[included] / term_order[included])
      )
    })
    stopifnot(abs(sum(factor_rows$shapley_eta_squared) - 1) < 1e-12)
    results <- factor_rows
    if (n_levels == 4) {
      # For Shapley, the ETR contrasts share the interaction credit of the
      # same original factor. They do not count as three independent switches.
      level_totals <- vapply(seq_len(n_levels), function(i) {
        mean(rowSums(window_y[design_rows$level_index == i, , drop = FALSE]))
      }, numeric(1))
      contrasts <- map_dfr(seq_len(3), function(i) {
        included <- term_indices[, 1] == i + 1L
        tibble(
          record_type = "etr_contrast", effect = contrast_labels[i],
          orthogonal_weights = weights[i],
          main_eta_squared = sum(eta[included & term_order == 1]),
          shapley_eta_squared = sum(eta[included] / term_order[included]),
          adjacent_from = level_order[i], adjacent_to = level_order[i + 1L],
          literal_adjacent_change_usd_bn = (level_totals[i + 1L] - level_totals[i]) / 1e9
        )
      })
      stopifnot(
        abs(sum(contrasts$main_eta_squared) - factor_rows$main_eta_squared[1]) < 1e-12,
        abs(sum(contrasts$shapley_eta_squared) - factor_rows$shapley_eta_squared[1]) < 1e-12
      )
      results <- bind_rows(results, contrasts)
    }
    cumulative <- rowSums(window_y) / 1e9
    results |>
      mutate(
        design = design_name, window = window, n_scenarios = nrow(design_rows),
        country_years = ncol(window_y), level_order = paste(level_order, collapse = " | "),
        interaction_eta_squared = sum(eta[term_order > 1]),
        min_eu27_revenue_usd_bn = min(cumulative), max_eu27_revenue_usd_bn = max(cumulative),
        min_level = design_rows$level[which.min(cumulative)],
        max_level = design_rows$level[which.max(cumulative)],
        min_other_switches = paste(unlist(design_rows[which.min(cumulative), binary_factors]), collapse = ""),
        max_other_switches = paste(unlist(design_rows[which.max(cumulative), binary_factors]), collapse = ""),
        max_global_conservation_gap_usd = validation$max_global_conservation_gap_usd,
        max_country_channel_gap_usd = validation$max_country_channel_gap_usd,
        .before = 1
      )
  })
}

run_step9_diagnostics <- function() {
  stage1 <- ladder_read("stage1_bilateral_panel")
  host_stage1 <- ladder_read("stage1_affiliate_year")
  ladder <- ladder_build_measurements(stage1, host_stage1,
    ladder_read("base_panel_t4_bilateral_bracket_shares"), rank_consistent = TRUE)
  levels <- c(LADDER_LEVELS, LADDER_BSPI)
  measurements <- ladder$measurements
  stopifnot(nrow(measurements) == nrow(stage1) * length(levels))
  for (i in 4:5) {
    prefix <- if (i == 4) "ladder_l4_anchored_" else "ladder_l4_strict_"
    check <- filter(measurements, level == levels[i]) |>
      inner_join(select(stage1, all_of(LADDER_KEYS), starts_with(prefix)),
        by = LADDER_KEYS, relationship = "one-to-one")
    stopifnot(nrow(check) == nrow(stage1),
      isTRUE(all.equal(check$share, check[[paste0(prefix, "low_share")]])),
      isTRUE(all.equal(check$gap, check[[paste0(prefix, "topup_rate")]])))
  }
  stage2 <- ladder_read("stage2_bilateral_panel") |>
    select(all_of(LADDER_KEYS), rate_scenario, affiliate_is_eu27, analysis_profit_positive,
      stage2_phi, stage2_topup_tax_average, stage2_topup_tax_distributional)
  post_sbie <- set_names(map(levels, function(level_name) {
    ladder_apply_sbie(filter(measurements, level == level_name), stage2)
  }), levels)
  for (i in c(1, 3)) {
    baseline_column <- c("stage2_topup_tax_average", NA, "stage2_topup_tax_distributional")[i]
    stopifnot(max(abs(post_sbie[[i]]$stage2_tax - coalesce(post_sbie[[i]][[baseline_column]], 0))) < 1e-3)
  }
  stage_summary <- ladder_stage_summary(measurements,
    imap_dfr(post_sbie, ~ mutate(.x, level = .y)))

  message("Allocating direct top-up across the ladder")
  factorial <- stage5_source_inputs()
  sectors <- ladder_read("stage2_sectoral_panel")
  weights <- list(
    parent_year_weights = ladder_read("stage4_5_utpr_parent_year_weights"),
    fallback_weights = ladder_read("stage4_5_utpr_fallback_weights")
  )
  beta <- ladder_read("stage3_model_coefficients") |>
    filter(model_spec == "linear", term == "tau", inference == "parent_affiliate_clustered") |>
    pull(estimate)
  stopifnot(length(beta) == 1, is.finite(beta))
  allocations <- set_names(map(levels, function(level_name) {
    message("  ", level_name)
    panel <- switch(level_name,
      L1_Host_Average = filter(factorial, x1_etr == 0),
      L3_Host_Pooled_Distributional = filter(factorial, x1_etr == 1),
      ladder_rebuild_scenarios(filter(measurements, level == level_name),
        post_sbie[[level_name]], factorial, host_stage1, sectors, beta)
    )
    ladder_allocate(panel, weights)
  }), levels)

  archived <- ladder_read("stage4_5_revenue_country_year") |>
    select(scenario_id, country, year, archived_revenue = revenue)
  baseline_check <- bind_rows(allocations[[1]]$revenue, allocations[[3]]$revenue) |>
    inner_join(archived, by = c("scenario_id", "country", "year"), relationship = "one-to-one")
  stopifnot(nrow(baseline_check) == nrow(archived),
    max(abs(baseline_check$revenue - baseline_check$archived_revenue)) < 1e-3)

  collector_revenues <- imap_dfr(allocations, ~ mutate(.x$revenue, level = .y))
  channels <- imap_dfr(allocations, ~ mutate(.x$channels, level = .y))
  preferred_source <- imap_dfr(allocations, ~ mutate(.x$preferred_source, level = .y))
  preferred_revenue <- collector_revenues |>
    filter(x2_substance == 0, x3_rates == 0, x5_behaviour == 1)
  parent_breakdown <- ladder_parent_breakdown(measurements, preferred_source, ladder$cells)
  sbs <- ladder_sbs_summary(preferred_source, preferred_revenue)
  backtest <- ladder_budget_backtest(collector_revenues, channels)

  message("Checking Stage 4.6 inputs and decomposing the factorial designs")
  binary_designs <- list(
    "L1_vs_L3" = c(1, 3), "L1_vs_L4_anchored" = c(1, 4),
    "L1_vs_L4_strict" = c(1, 5), "L2_vs_L4_anchored" = c(2, 4)
  )
  validation <- map(binary_designs, ~ ladder_binary_stage46(allocations[[.x[1]]], allocations[[.x[2]]]))
  anova <- imap_dfr(binary_designs, function(indices, name) {
    ladder_anova(collector_revenues, levels[indices], name, validation[[name]])
  })
  for (indices in list(c(1, 2, 4, 3), c(1, 2, 5, 3))) {
    selected <- allocations[indices]
    checks <- map_dfr(seq_along(indices)[-1], ~ ladder_binary_stage46(selected[[1]], selected[[.x]]))
    joint_checks <- summarise(checks, across(everything(), max))
    name <- if (4 %in% indices) "four_levels_anchored" else "four_levels_strict"
    anova <- bind_rows(anova, ladder_anova(collector_revenues, levels[indices], name, joint_checks))
  }

  ladder_write(stage_summary, "ladder_stage1_stage2_summary")
  ladder_write(parent_breakdown, "nld_lux_irl_parent_breakdown")
  ladder_write(sbs, "ladder_sbs_exposure")
  ladder_write(backtest, "ladder_budget_backtest")
  ladder_write(anova, "ladder_anova_decomposition")
}

if (is_direct_script_run("code/diagnostics_step9_bilateral_aggregation_ladder.R")) {
  run_step9_diagnostics()
}
