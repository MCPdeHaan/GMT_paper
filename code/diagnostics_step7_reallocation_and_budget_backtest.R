# Run from the repository root with Rscript after the Stage 3 and 4.5 pipelines.
source("code/diagnostics_step6_econometrics_and_cit_recovery.R", local = TRUE)

STEP7_PREFERRED <- c("x10001", "x10011")
STEP7_WINDOWS <- list(`2017–2023` = MAIN_YEARS, FY2023 = 2023L, `2019–2023` = 2019:2023)
USD_PER_EUR_2023 <- 1.0813

write_step7 <- function(data, name) {
  write_csv(data, file.path(DIAGNOSTICS_DIR, paste0("step7_", name, ".csv")))
}

build_hub_destination_routes <- function(panel, stage1, host) {
  keys <- c("parent", "affiliate", "year")
  bilateral <- stage1 |>
    select(all_of(keys), etr_panelai_stage1, parent_cit_rate_unit)
  sources <- panel |>
    filter(reallocated_profit > 0) |>
    transmute(across(all_of(keys)), scenario_id, source_etr = static_tau_low, reallocated_profit) |>
    left_join(bilateral |> select(-etr_panelai_stage1),
      by = keys, relationship = "many-to-one"
    ) |>
    mutate(source_id = row_number())
  stopifnot(all(is.finite(sources$source_etr)), all(sources$source_etr < GMT_RATE))
  footprint <- panel |>
    select(all_of(keys), affiliate_cit_rate_unit, employees_sbie, payroll_sbie, upr_panelai) |>
    left_join(bilateral |> select(-parent_cit_rate_unit),
      by = keys, relationship = "many-to-one") |>
    build_rule_b_footprint()
  global <- build_rule_b_global_footprint(footprint, host)
  formulary <- allocate_rule_b_sources(sources, footprint, global)

  b <- formulary |>
    transmute(source_id, scenario_id, year, destination, route, statutory_rate,
      received = reallocated_profit * weight, same_country_headquarters = FALSE
    )
  c <- bind_rows(
    formulary |>
      transmute(source_id, scenario_id, year, destination, route, statutory_rate,
        received = reallocated_profit * weight *
          if_else(coalesce(parent_cit_rate_unit >= GMT_RATE, FALSE), 0.5, 1),
        same_country_headquarters = FALSE
      ),
    sources |>
      filter(parent_cit_rate_unit >= GMT_RATE) |>
      transmute(source_id, scenario_id, year, destination = parent, route = "headquarters",
        statutory_rate = parent_cit_rate_unit, received = 0.5 * reallocated_profit,
        same_country_headquarters = affiliate == parent
      )
  )
  for (routes in list(b, c)) {
    check <- routes |>
      group_by(source_id) |>
      summarise(received = sum(received), .groups = "drop") |>
      left_join(select(sources, source_id, reallocated_profit), by = "source_id", relationship = "one-to-one")
    stopifnot(nrow(check) == nrow(sources), max(abs(check$received - check$reallocated_profit)) < 1e-3)
  }
  bind_rows(B = b, C = c, .id = "rule")
}

build_destination_comparison <- function(panel, direct, stage1, host) {
  panel <- filter(panel, scenario_id %in% STEP7_PREFERRED)
  a <- build_parent_specific_reallocation(panel, host)
  route_a <- a$matrix |>
    transmute(rule = "A", scenario_id, year, destination, statutory_rate,
      route = if_else(destination_weight_source == "parent_year", "parent_activity", "global_activity"),
      received = reallocated_profit_received, same_country_headquarters = FALSE
    )
  routes <- bind_rows(route_a, build_hub_destination_routes(panel, stage1, host))
  receipts <- routes |>
    group_by(rule, scenario_id, year, country = destination) |>
    summarise(
      gross_cit = sum(received * statutory_rate), profit_received = sum(received),
      global_fallback_profit = sum(received[route == "global_activity"]),
      headquarters_profit = sum(received[route == "headquarters"]),
      same_country_headquarters_profit = sum(received[same_country_headquarters]), .groups = "drop"
    )
  origin <- a$source_rows |>
    group_by(country = affiliate, scenario_id, year) |>
    summarise(source_cit_lost = sum(source_tax_loss), profit_sent = sum(reallocated_profit), .groups = "drop")
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
    left_join(origin, by = keys, relationship = "one-to-one") |>
    crossing(rule = c("A", "B", "C")) |>
    left_join(receipts, by = c("rule", keys), relationship = "one-to-one") |>
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

budget_benchmarks <- function() {
  dutch_2023 <- "https://www.tweedekamer.nl/downloads/document?id=2023D23289"
  dutch_2026 <- "https://zoek.officielebekendmakingen.nl/kst-36915-3.html"
  dutch_october_2026 <- "https://zoek.officielebekendmakingen.nl/dossier/kst-1275297.pdf#page=44"
  german <- "https://dserver.bundestag.de/btd/20/086/2008668.pdf"
  belgian <- "https://www.dekamer.be/FLWB/PDF/55/3272/55K3272004.pdf"
  slovak <- "https://link.springer.com/article/10.1007/s10797-026-09946-8"
  tribble(
    ~country, ~benchmark, ~evidence, ~forecast_period, ~revenue_scope, ~model_scope,
    ~official_low_eur_bn, ~official_high_eur_bn, ~stated_sbs_switch, ~source_url,
    "NLD", "Dutch 2023 structural estimate", "official forecast", "2034 onward", "Direct plus behavioural CIT", "direct", .466, .466, 0L, dutch_2023,
    "NLD", "Dutch 2023 direct component", "official forecast", "2034 onward", "QDMTT 55m plus IIR/UTPR 9m", "direct", .064, .064, 0L, dutch_2023,
    "NLD", "Dutch 2023 structural domestic top-up", "official forecast", "2034 onward", "QDMTT", "qdmt", .055, .055, 0L, dutch_2023,
    "NLD", "Dutch 2026 pre-SbS estimate", "official forecast", "annual", "Direct plus behavioural CIT", "direct", .700, .700, 0L, dutch_2026,
    "NLD", "Dutch 2026 post-SbS estimate", "implied by official figures", "annual", "Direct plus behavioural CIT and package changes", "direct", .578, .578, 1L, dutch_2026,
    "NLD", "2023 estimate less 2026 haircut", "cross-vintage arithmetic", "structural illustration", "Mixed vintages", "direct", .344, .344, 1L, dutch_2026,
    "NLD", "Dutch October 2026 structural domestic top-up", "official forecast", "structural, 2020–2023 CbCR base", "QDMTT, retained under both policies", "qdmt", .055, .055, NA_integer_, dutch_october_2026,
    "NLD", "Dutch October 2026 direct before package", "implied by official figures", "structural, 2020–2023 CbCR base", "QDMTT 55m plus IIR/UTPR 175m", "direct", .230, .230, 0L, dutch_october_2026,
    "NLD", "Dutch October 2026 direct after package", "implied by official figures", "structural, 2020–2023 CbCR base", "QDMTT 55m plus IIR/UTPR 121m after both safe harbours", "direct", .176, .176, 1L, dutch_october_2026,
    "DEU", "Mindeststeuergesetz cash estimate", "official draft costing", "2026 cash", "Minimum tax, separate from accompanying tax changes", "direct", 1, 1, 0L, german,
    "DEU", "Mindeststeuergesetz full-year effect", "official draft costing", "full-year effect", "Minimum tax, separate from accompanying tax changes", "direct", .2, .2, 0L, german,
    "FRA", "Projet de loi de finances 2026", "official forecast", "2026 cash", "Domestic and other top-up receipts", "direct", .5, .5, NA_integer_, "https://www.senat.fr/rap/l25-139-21/l25-139-211.pdf",
    "IRL", "Department of Finance estimate, reported by IFAC", "official forecast", "2026 cash", "Pillar II additional receipts", "direct", 3.2, 3.2, NA_integer_, "https://www.fiscalcouncil.ie/wp-content/uploads/2025/11/Supporting-items-Fiscal-Assessment-Report-November-2025.pdf",
    "BEL", "Belgian 2024 budget", "official forecast", "2024 cash", "QDMTT and IIR net of 16m implementation costs", "direct", .634, .634, 0L, belgian,
    "BEL", "Belgian 2024 domestic top-up", "official forecast", "2024 cash", "QDMTT gross", "qdmt", .350, .350, 0L, belgian,
    "BEL", "Belgian 2024 IIR", "official forecast", "2024 cash", "IIR gross", "iir", .300, .300, 0L, belgian,
    "AUT", "Austrian MinBestG impact assessment", "official potential estimate", "2026 onward", "Additional minimum-tax revenue", "direct", .100, .100, 0L, "https://www.parlament.gv.at/dokument/XXVII/I/2322/imfname_1596482.pdf",
    "SVK", "Slovak implementing bill", "official unquantified", "2026 onward", "Domestic top-up, no published amount in bill", "qdmt", NA_real_, NA_real_, NA_integer_, "https://www.vssr.sk/dovodova-sprava/dovodova-sprava-k-zakonu-c-507-2023-z-z.htm",
    "SVK", "Boukal et al. domestic top-up", "academic estimate", "annual, 2020 base", "QDMTT after behaviour", "qdmt", .044, .044, NA_integer_, slovak,
    "SVK", "Boukal et al. total direct top-up", "academic estimate", "annual, 2020 base", "Domestic and third-country top-up", "direct", .053, .053, NA_integer_, slovak,
    "SVK", "Boukal et al. overall effect", "academic estimate", "annual, 2020 base", "Top-up plus net ordinary corporate tax effect", "direct", .117, .144, NA_integer_, slovak
  ) |>
    mutate(comparison_scope = case_when(
      grepl("behavioural CIT|ordinary corporate|Mixed vintages", revenue_scope) ~
        "Numerical collector comparison only; benchmark includes more than direct top-up",
      benchmark == "Belgian 2024 budget" ~ "Gross model versus forecast net of implementation costs",
      TRUE ~ "Model channel as specified"
    ))
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

run_step7_reallocation_and_budget_backtest <- function() {
  direct <- read_step6_input("stage4_5_revenue_country_year")
  stage1 <- read_step6_input("stage1_bilateral_panel")
  host <- read_step6_input("stage1_affiliate_year")
  reallocation <- build_destination_comparison(read_step6_factorial_input(), direct, stage1, host)
  write_step7(reallocation, "reallocation_destination_rules_comparison")
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

if (is_direct_script_run("code/diagnostics_step7_reallocation_and_budget_backtest.R")) {
  run_step7_reallocation_and_budget_backtest()
}
