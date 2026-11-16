# R06a point sensitivities over the R05b freeze. This module has no production callers.
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code",
  "09_econometric_and_reallocation_extensions.R"), local = TRUE)
source(file.path(GMT_PROJECT_ROOT, "code", "07a_uncertainty.R"), local = TRUE)
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code",
  "11_policy_game_and_variance_extensions.R"), local = TRUE)

NOTCH_ARMS <- c("BASELINE_NOTCH", "NO_NOTCH_STANDARD_RESPONSE", "NO_NOTCH_NO_BAND_RESPONSE",
  "BANDWIDTH_1PP", "BANDWIDTH_3PP")
NOTCH_WINDOWS <- list("FY2023" = 2023L, "2019–2023" = 2019:2023, "2017–2023" = 2017:2023)
NOTCH_KEYS <- c("parent", "affiliate", "year", "scenario_id")

notch_bandwidth <- function(specification) {
  spec <- match.arg(specification, NOTCH_ARMS)
  unname(c(BASELINE_NOTCH = .02, NO_NOTCH_STANDARD_RESPONSE = 0, NO_NOTCH_NO_BAND_RESPONSE = 0,
    BANDWIDTH_1PP = .01, BANDWIDTH_3PP = .03)[spec])
}

notch_schedule <- function(tau_low, beta_raw, specification, threshold = GMT_RATE) {
  spec <- match.arg(specification, NOTCH_ARMS)
  if (spec != "NO_NOTCH_NO_BAND_RESPONSE") {
    return(apply_behavioural_regime(tau_low, beta_raw, threshold, notch_bandwidth(spec)))
  }
  historical <- apply_behavioural_regime(tau_low, beta_raw, threshold, SESH_BANDWIDTH_BASELINE)
  former_band <- historical$behavioural_regime == "sesh_bunching_topup_zero"
  historical$behavioural_liability_filter[former_band] <- 1
  historical$behavioural_regime[former_band] <- "no_low_tax_response"
  historical
}

notch_response <- function(panel, specification) {
  schedule <- notch_schedule(panel$static_tau_low, panel$static_beta_raw, specification)
  panel$static_beta_applied <- schedule$beta_applied
  panel$static_behavioural_liability_filter <- schedule$behavioural_liability_filter
  panel$static_behavioural_regime <- schedule$behavioural_regime
  add_behavioural_response(panel)
}

# Source the original functions in a separate environment. Only the diagnostic
# invocation resolves the alternate schedule. The production bindings and input
# data stay untouched, including the selection of the two-point reference row.
notch_engine <- function(specification, processed = PROCESSED_DIR) {
  specification <- match.arg(specification, NOTCH_ARMS)
  e <- new.env(parent = environment(notch_engine))
  sys.source(file.path(GMT_PROJECT_ROOT, "code", "07a_uncertainty.R"), e)
  sys.source(file.path(GMT_PROJECT_ROOT, "code", "11_policy_game_and_variance_extensions.R"), e)
  e$PROCESSED_DIR <- processed
  e$DIAGNOSTICS_DIR <- file.path(processed, "diagnostics")
  if (specification != "BASELINE_NOTCH") {
    e$apply_behavioural_regime <- function(tau_low, beta_raw, threshold = GMT_RATE, eta = NULL) {
      notch_schedule(tau_low, beta_raw, specification, threshold)
    }
  }
  e
}

# Legal commencement gate only. The optional 2026 paths assume an affirmative
# domestic implementation decision. Group qualification and election are separate.
sesh_start_available <- function(fiscal_start, early_implementation, qdmtt_safe_harbour,
                                 number_of_taxing_jurisdictions, all_early_and_elected) {
  fiscal_start <- as.Date(fiscal_start)
  fiscal_start >= as.Date("2026-12-31") |
    (fiscal_start >= as.Date("2025-12-31") & early_implementation &
      (qdmtt_safe_harbour | number_of_taxing_jurisdictions == 1 | all_early_and_elected))
}

notch_windows <- function(panel, windows = NOTCH_WINDOWS) {
  imap_dfr(windows, ~ mutate(filter(panel, year %in% .x), window = .y, .before = 1))
}

# Source grain is parent × affiliate × observation year × scenario. Unsupported
# parent-year pools are mapped back to their original bilateral source amounts.
notch_allocate <- function(panel, weights) {
  source <- build_source_panel(panel)
  allocation <- allocate_stage4_revenue(source, weights, unsupported = "report")
  conservation <- build_conservation_diagnostics(source, allocation$revenue_by_channel_global,
    allocation$unsupported_utpr)
  unsupported <- distinct(allocation$unsupported_utpr, scenario_id, parent, year) |>
    mutate(unsupported = TRUE)
  source <- source |>
    left_join(unsupported, by = c("scenario_id", "parent", "year"), relationship = "many-to-one") |>
    mutate(
      unsupported_usd = if_else(unsupported %in% TRUE, stage4_utpr_pool, 0),
      notch_relief_usd = if_else(behavioural_regime == "sesh_bunching_topup_zero", topup_after_stage2, 0),
      response_relief_usd = topup_after_stage2 - notch_relief_usd - topup_after_behaviour,
      assigned_usd = stage4_qdmtt_liability + stage4_iir_liability + stage4_utpr_pool - unsupported_usd,
      source_cit_lost_usd = reallocated_profit * coalesce_zero(clamp_interval(static_tau_low, 0, GMT_RATE))
    )
  # Check stage accounting at the original keys, where dollar magnitudes are
  # smaller than the scenario-year totals handled by the production allocator.
  stopifnot(max(abs(with(source, topup_after_stage2 - notch_relief_usd - response_relief_usd -
      assigned_usd - unsupported_usd - stage4_sbs_extinguished_liability))) < 1e-3,
    all(source$response_relief_usd >= -1e-8))
  list(source = source, allocation = allocation, max_gap = max(abs(conservation$residual_gap)))
}

notch_exposure <- function(panel, width, level) {
  band <- apply_behavioural_regime(panel$static_tau_low, 0, eta = width)$behavioural_regime
  candidates <- panel[band == "sesh_bunching_topup_zero", ] |>
    transmute(scenario_id, factor1_etr, factor4_sbs, parent, affiliate, year,
      source_area = if_else(affiliate %in% EU27_ISO3, "EU27", "non_EU27"),
      parent_area = if_else(parent == "USA", "USA", "other"),
      channel = allocation_regime(rep(1, n()), qdmtt_flag, parent_iir_utpr_flag, sbs_exempt),
      positive_profit = analysis_profit_positive > 0,
      lowtax_profit = if_else(factor1_etr == "average", stage1_lowtax_profit_average,
        stage1_lowtax_profit_distributional),
      pre_sbie_usd = coalesce_zero(lowtax_profit) * (GMT_RATE - static_tau_low),
      post_sbie_usd = topup_after_stage2)
  summarise_candidates <- function(data, keys) {
    data |>
      summarise(rows = n(), affiliate_years = n_distinct(affiliate, year),
        positive_profit_rows = sum(positive_profit %in% TRUE),
        positive_lowtax_profit_rows = sum(lowtax_profit > 0, na.rm = TRUE),
        zero_lowtax_profit_rows = sum(lowtax_profit == 0, na.rm = TRUE),
        missing_lowtax_profit_rows = sum(is.na(lowtax_profit)),
        positive_liability_rows = sum(post_sbie_usd > 0), pre_sbie_usd = sum(pre_sbie_usd),
        post_sbie_usd = sum(post_sbie_usd), .by = all_of(keys))
  }
  windows <- notch_windows(candidates)
  keys <- c("window", "scenario_id", "factor1_etr", "factor4_sbs")
  scenarios <- crossing(distinct(panel, scenario_id, factor1_etr, factor4_sbs), window = names(NOTCH_WINDOWS))
  bind_rows(
    left_join(scenarios, summarise_candidates(windows, keys), by = keys, relationship = "one-to-one") |>
      mutate(across(where(is.numeric), coalesce_zero), source_area = "Global", parent_area = "All", channel = "All"),
    summarise_candidates(windows, c(keys, "source_area", "parent_area", "channel"))
  ) |>
    mutate(width_pp = width * 100, level, .before = 1)
}

notch_core_outputs <- function(result) {
  source <- result$source |>
    transmute(scenario_id, affiliate, year, post_substance_usd = topup_after_stage2,
      notch_relief_usd, response_relief_usd, source_usd = topup_after_behaviour,
      qdmtt_usd = stage4_qdmtt_liability, iir_usd = stage4_iir_liability,
      utpr_pool_usd = stage4_utpr_pool, assigned_usd, unsupported_usd,
      sbs_extinguished_usd = stage4_sbs_extinguished_liability,
      relocated_profit_usd = reallocated_profit, source_cit_lost_usd)
  source <- bind_rows(source, mutate(source, affiliate = "Global"),
    mutate(filter(source, affiliate %in% EU27_ISO3), affiliate = "EU27"))
  fiscal <- notch_windows(source) |>
    summarise(across(ends_with("_usd"), sum), .by = c(window, scenario_id, affiliate))
  channels <- result$allocation$revenue_by_channel_global |>
    summarise(assigned_usd = sum(revenue), .by = c(scenario_id, year, country, channel))
  channels <- bind_rows(channels, mutate(channels, country = "Global"),
    mutate(filter(channels, country %in% EU27_ISO3), country = "EU27"))
  collectors <- notch_windows(channels) |>
    summarise(assigned_usd = sum(assigned_usd), .by = c(window, scenario_id, country, channel))
  list(source = fiscal, channels = collectors, gap = result$max_gap)
}

# Rule B in the paper. Work directly with the existing destination engine so
# the Stage 09 baseline-only Rule A gate does not govern alternative cases.
notch_cit <- function(panel, stage1, host) {
  keys <- c("parent", "affiliate", "year")
  footprint <- panel |>
    distinct(across(all_of(keys)), affiliate_cit_rate_unit, employees_sbie, payroll_sbie, upr_panelai) |>
    left_join(select(stage1, all_of(keys), etr_panelai_stage1), by = keys,
      relationship = "one-to-one") |>
    build_rule_b_footprint()
  global <- build_rule_b_global_footprint(footprint, host)
  relocating <- panel |> filter(reallocated_profit > 0) |>
    transmute(across(all_of(keys)), scenario_id, source_etr = static_tau_low, reallocated_profit,
      source_id = row_number())
  routes <- allocate_rule_b_sources(relocating, footprint, global) |>
    transmute(scenario_id, year, country = destination, received = received,
      gross_cit_usd = received * statutory_rate)
  origins <- panel |>
    filter(reallocated_profit > 0) |>
    transmute(scenario_id, year, country = affiliate, sent = reallocated_profit,
      source_cit_lost_usd = sent * clamp_interval(static_tau_low, 0, GMT_RATE))
  sent <- summarise(origins, sent = sum(sent), .by = c(scenario_id, year))
  receipts <- summarise(routes, received = sum(received), .by = c(scenario_id, year))
  allocation <- full_join(sent, receipts, by = c("scenario_id", "year"), relationship = "one-to-one")
  # The original router checks every source in USD. Aggregating thousands
  # of weighted routes can add round-off at the scenario-year scale.
  rounding <- pmax(1e-3, 128 * .Machine$double.eps * allocation$sent)
  stopifnot(!anyNA(allocation), all(abs(allocation$sent - allocation$received) < rounding))
  summarise_with_geography <- function(data) {
    bind_rows(data, mutate(data, country = "Global"),
      mutate(filter(data, country %in% EU27_ISO3), country = "EU27")) |>
      notch_windows() |>
      summarise(across(where(is.numeric) & !all_of("year"), sum), .by = c(window, scenario_id, country))
  }
  key <- c("window", "scenario_id", "country")
  amounts <- full_join(summarise_with_geography(routes), summarise_with_geography(origins),
    by = key, relationship = "one-to-one")
  universe <- crossing(window = names(NOTCH_WINDOWS), scenario_id = unique(panel$scenario_id),
    country = sort(unique(c(EU27_ISO3, "EU27", "Global", amounts$country))))
  left_join(universe, amounts, by = key, relationship = "one-to-one") |>
    mutate(across(c(received, gross_cit_usd, sent, source_cit_lost_usd), coalesce_zero),
      net_cit_usd = gross_cit_usd - source_cit_lost_usd)
}

# Project onto the source cell identity for a USD-by-source comparison. The
# real sparse routes are evaluated separately and checked by the original evaluator.
notch_fast_source <- function(engine, input, measure) {
  input$collector_year <- input$cells
  identity <- Matrix::Diagonal(nrow(input$cells))
  input$routes <- lapply(input$routes, function(route) {
    route$operator <- identity
    route
  })
  engine$step15_evaluate(input, measure)$revenue * 1e9
}

notch_fast_compare <- function(input, panel, engine, measure) {
  actual <- notch_fast_source(engine, input, measure)
  dense <- panel |> select(all_of(NOTCH_KEYS), topup_after_behaviour) |>
    tidyr::pivot_wider(names_from = scenario_id, values_from = topup_after_behaviour)
  dense <- left_join(select(input$cells, all_of(STEP15_KEYS)), dense,
    by = STEP15_KEYS, relationship = "one-to-one")
  difference <- actual - as.matrix(dense[colnames(actual)])
  stopifnot(!anyNA(difference), max(abs(difference)) < 1e-3)
  max(abs(difference))
}

notch_accounting <- function(engine, input, measure, point, globe) {
  design <- step15_design(TRUE)
  windows <- c(NOTCH_WINDOWS, STEP15_WINDOWS[setdiff(names(STEP15_WINDOWS), names(NOTCH_WINDOWS))])
  strict <- list(share = coalesce_zero(input$cells$ladder_l4_strict_low_share),
    gap = coalesce_zero(input$cells$ladder_l4_strict_topup_rate), bilateral = TRUE)
  set_names(map(c("L3", "L4_strict"), function(level) {
    untreated <- if (level == "L3") point else {
      engine$step15_evaluate(input, list(profit = input$profit,
        average = measure$average, distributional = strict), check = TRUE)$revenue
    }
    treated <- engine$step15_evaluate(input, list(profit = globe$profit,
      average = globe$average, distributional = globe[[level]]), check = TRUE)$revenue
    y <- untreated[, rep(seq_len(ncol(untreated)), each = 2L)]
    y[, design$x6_accounting == 1L] <- treated
    colnames(y) <- design$scenario_id
    long <- bind_cols(input$collector_year, as_tibble(y)) |>
      pivot_longer(all_of(design$scenario_id), names_to = "scenario_id", values_to = "assigned_usd_bn")
    totals <- bind_rows(long, mutate(long, country = "EU27")) |>
      notch_windows(windows) |>
      summarise(assigned_usd_bn = sum(assigned_usd_bn), .by = c(window, country, scenario_id)) |>
      mutate(level, .before = 1)
    effects <- imap_dfr(windows, function(years, window) {
      pooled <- t(y[input$collector_year$year %in% years, , drop = FALSE])
      factors <- setdiff(names(design), "scenario_id")
      bind_rows(step15_factorial_effects(pooled, design, factors, "EU27", window, "pooled_country_year"),
        step15_factorial_effects(matrix(rowSums(pooled), ncol = 1), design, factors,
          "EU27", window, "cumulative_collector")) |>
        filter(record == "main_effect") |>
        select(-record, -interaction_term_eta_squared)
    }) |> mutate(level, .before = 1)
    list(totals = totals, effects = effects)
  }), c("L3", "L4_strict"))
}

notch_density <- function(host) {
  samples <- list(global = host, eu27 = filter(host, affiliate_is_eu27))
  imap_dfr(samples, function(data, sample) {
    observations <- prepare_notch_sample(data, sample)
    map_dfr(c(.01, .02, .03), ~ estimate_notch_sample(observations, bunching_bandwidth = .x)$summary) |>
      mutate(sample, .before = 1)
  })
}

# Preserve the fixed-filter estimand in the profit-only module. Replace only
# the schedule at the observed point, then hold it fixed within that projection.
notch_profit_point <- function(engine, revised) {
  keys <- c("parent", "affiliate", "year", "factor4_sbs")
  filters <- revised |> filter(scenario_id %in% NASH_IDS) |>
    select(all_of(keys), behavioural_liability_filter)
  preferred <- engine$build_preferred_source_panel(engine$PROCESSED_DIR) |>
    select(-behavioural_liability_filter) |>
    left_join(filters, by = keys, relationship = "one-to-one")
  stopifnot(!anyNA(preferred$behavioural_liability_filter))
  engine$compute_preferred_revenue_from_profit(preferred, preferred$analysis_profit_base,
    "preferred_correction", unsupported = "report") |>
    select(-draw_id, -specification)
}

notch_keyed_gap <- function(actual, expected, keys, values, tolerance = 1e-3) {
  joined <- full_join(select(actual, all_of(c(keys, values))),
    select(expected, all_of(c(keys, values))), by = keys,
    suffix = c("", "_saved"), relationship = "one-to-one")
  gap <- max(abs(as.matrix(joined[values]) - as.matrix(joined[paste0(values, "_saved")])))
  if (!is.finite(gap) || gap >= tolerance) {
    stop("Failed baseline parity for ", paste(values, collapse = ", "), " (maximum gap ", gap, ")",
      call. = FALSE)
  }
  gap
}

notch_game <- function(engine, weights, exits, beta) {
  panels <- engine$nash_load_panels()
  common <- panels$L3_pooled
  panels$L3_pooled <- engine$replace_behaviour_schedule(common, common$static_tau_low,
    coalesce_zero(compute_reallocation_share(common$static_tau_low, rep_len("linear", nrow(common)), beta)))
  imap_dfr(panels, function(panel, level) {
    source <- engine$nash_r3_panel(panel)
    adoption <- list(source = source, allocation = nash_channels(source, weights))
    map_dfr(EU27_ISO3, function(country) {
      map_dfr(NASH_DEVIATIONS, function(deviation) {
        chosen_weights <- if (deviation == "full_opt_out") exits[[country]] else weights
        change <- engine$nash_build_deviation(source, country, deviation, chosen_weights)
        imap_dfr(NOTCH_WINDOWS, function(years, window) {
          map_dfr(c("Universal", "SbS"), ~ nash_summarise_deviation(adoption, change, country, years, .x, window))
        }) |> mutate(level, deviation, .before = 1)
      })
    })
  })
}

notch_transitional_inputs <- function(engine, input, globe) {
  base <- engine$bridge_read("base_panel")
  t1 <- engine$bridge_read("cbcr_table1")
  t4 <- engine$bridge_read("cbcr_table4") |> filter(!affiliate %in% STEP8_AGGREGATES)
  t4_bilateral <- engine$bridge_read("base_panel_t4_bilateral_bracket_shares")
  low_bracket <- t4_bilateral |>
    filter(etr_bracket == "rate_0_15", profit > 0) |>
    select(all_of(BRIDGE_KEYS), profit, tot_rev, subgroups_count, tax_accrued, tax_paid, employees, assets)
  tests <- bridge_table1_loss(base, t1) |>
    filter(year %in% MAIN_YEARS) |>
    left_join(select(base, all_of(BRIDGE_KEYS), employees, employees_panelai, assets, assets_panelai,
      employees_sbie_plausibility_cap, affiliate_wage_annual), by = BRIDGE_KEYS, relationship = "one-to-one") |>
    mutate(employees_a_screen = pmin(employees, coalesce(employees_sbie_plausibility_cap, Inf)),
      employees_ai_screen = pmin(employees_panelai, coalesce(employees_sbie_plausibility_cap, Inf)))
  screen_2026 <- filter(BRIDGE_SAFE_YEARS, policy_year == 2026)
  variant <- bridge_tax_rates(engine$bridge_read("stage1_bilateral_panel"),
    engine$bridge_read("stage1_affiliate_year"), t4, t4_bilateral, "T3_envelope")
  repriced <- step8_reconcile_rates(variant$stage1, base, variant$host, variant$partitions,
    gamma = 1, method = "reporter_pool")$cells |>
    select(all_of(BRIDGE_KEYS), revised_share, revised_gap)
  cells <- select(input$cells, all_of(BRIDGE_KEYS)) |>
    left_join(repriced, by = BRIDGE_KEYS, relationship = "one-to-one")
  list(measure = bridge_measure(cells, globe$profit, cells$revised_share, cells$revised_gap),
    tests = bridge_safe_tests(tests, screen_2026, "panel_a_net", "T3_envelope", low_bracket),
    spine = engine$bridge_preferred_input())
}

notch_screen <- function(engine, prepared, weights, beta) {
  panel <- engine$bridge_behaviour(prepared$spine, prepared$measure, beta)
  before <- notch_allocate(panel, weights)
  bridge_input <- list(source = select(before$source, -unsupported))
  output <- map_dfr(c(FALSE, TRUE), function(preserve) {
    after <- bridge_apply_safe(bridge_input, prepared$tests, weights, keep_qdmtt = preserve)
    ledger <- before$source |>
      select(all_of(BRIDGE_KEYS), qdmtt_flag, topup_after_stage2, behavioural_regime, static_tau_low,
        notch_relief_usd, response_relief_usd, assigned_usd, unsupported_usd,
        stage4_sbs_extinguished_liability, topup_after_behaviour) |>
      left_join(select(prepared$tests, all_of(BRIDGE_KEYS), de_minimis, routine, simplified, any_pass),
        by = BRIDGE_KEYS, relationship = "one-to-one") |>
      left_join(transmute(after$source, across(all_of(BRIDGE_KEYS)), remaining = topup_after_behaviour,
        after_qdmtt = stage4_qdmtt_liability, after_iir = stage4_iir_liability,
        after_utpr = stage4_utpr_pool, after_sbs = stage4_sbs_extinguished_liability,
        after_unsupported = source_unsupported_utpr), by = BRIDGE_KEYS, relationship = "one-to-one") |>
      mutate(former_band = static_tau_low >= GMT_RATE - .02 & static_tau_low < GMT_RATE,
        overlapping_exposure = if_else(former_band %in% TRUE & any_pass %in% TRUE, topup_after_stage2, 0),
        overlapping_notch_removal = if_else(any_pass %in% TRUE, notch_relief_usd, 0),
        screen_relief_usd = topup_after_behaviour - remaining,
        after_assigned = after_qdmtt + after_iir + after_utpr - after_unsupported)
    stopifnot(max(abs(with(ledger, topup_after_stage2 - notch_relief_usd - response_relief_usd -
        screen_relief_usd - after_assigned - after_sbs - after_unsupported))) < 1e-3)
    exports <- notch_windows(ledger) |>
      summarise(
        candidate_overlap_rows = sum(former_band %in% TRUE & any_pass %in% TRUE),
        positive_overlap_rows = sum(overlapping_exposure > 0),
        gross_overlap_usd = sum(overlapping_exposure),
        notch_already_removed_in_overlap_usd = sum(overlapping_notch_removal),
        post_substance_usd = sum(topup_after_stage2),
        notch_relief_usd = sum(notch_relief_usd), response_relief_usd = sum(response_relief_usd),
        additional_screen_relief_usd = sum(screen_relief_usd),
        source_before_screen_usd = sum(topup_after_behaviour), source_after_screen_usd = sum(remaining),
        qdmtt_after_screen_usd = sum(after_qdmtt), iir_after_screen_usd = sum(after_iir),
        utpr_pool_after_screen_usd = sum(after_utpr), assigned_global_usd = sum(after_assigned),
        unsupported_usd = sum(after_unsupported), extinguished_usd = sum(after_sbs), .by = window)
    collector <- filter(after$revenue, country %in% EU27_ISO3) |>
      notch_windows() |> summarise(assigned_eu27_usd = sum(collector), .by = window)
    left_join(exports, collector, by = "window") |> mutate(preserve_qdmtt = preserve, .before = 1)
  })
  before_eu27 <- filter(before$allocation$revenue_by_channel_global, country_is_eu27) |>
    notch_windows() |> summarise(before_eu27_usd = sum(revenue), .by = window)
  left_join(output, before_eu27, by = "window", relationship = "many-to-one")
}

run_behavioural_notch_diagnostic <- function(output, processed = PROCESSED_DIR) {
  withr::local_envvar(GMT_BEHAVIOURAL_SPECIFICATION = "BASELINE_NOTCH")
  stopifnot(dir.exists(processed), !file.exists(output) ||
    (dir.exists(output) && length(list.files(output, all.files = TRUE, no.. = TRUE)) == 0L))
  output <- file.path(normalizePath(dirname(output), mustWork = TRUE), basename(output))
  if (dir.exists(output)) output <- normalizePath(output, mustWork = TRUE)
  protected <- unique(normalizePath(c(processed, PROCESSED_DIR), mustWork = TRUE))
  stopifnot(!any(startsWith(paste0(output, "/"), paste0(protected, "/"))))
  if (!dir.exists(output)) stopifnot(dir.create(output))
  read <- function(stem) readRDS(file.path(processed, paste0(stem, ".rds")))
  diagnostic <- function(stem) read_csv(file.path(processed, "diagnostics", paste0(stem, ".csv")),
    show_col_types = FALSE)
  weights <- read_stage4_utpr_weights(processed)
  stopifnot(identical(weights$policy$specification, "VERIFIED_PARENT_ONLY"), nrow(weights$fallback_weights) == 0)
  frozen <- read("stage3_factorial_pair_year")
  stage1 <- read("stage1_bilateral_panel")
  host <- read("stage1_affiliate_year")
  stage2 <- read("stage2_bilateral_panel")
  schedule <- read("stage3_behavioral_affiliate_year")
  model <- arrange(read("stage3_model_comparison"), bic_rank)$model_spec[1L]
  flags <- build_policy_flags(read("oecd_pillar2_central_record"))
  sectoral <- build_sectoral_factor2_bridge(stage2, host, read("stage2_sectoral_panel"))
  panel <- build_factorial_revenue(stage2, schedule, sectoral, flags, model)$scenario_panel
  stage5_gap <- notch_keyed_gap(panel, frozen, NOTCH_KEYS,
    c("topup_after_stage2", "topup_after_behaviour", "reallocated_profit"))
  stopifnot(stage5_gap == 0, identical(panel$behavioural_regime, frozen$behavioural_regime))
  message("Stage 05 baseline reproduced")
  core <- select(panel, all_of(unique(c(NOTCH_KEYS, SCENARIO_VARS, NASH_KEYS))),
    affiliate_jurisdiction_name, parent_jurisdiction_name, affiliate_is_conduit_haven, affiliate_is_eu27,
    affiliate_policy_iir_utpr_ambiguous_by_2026, parent_iir_utpr_ambiguous_flag,
    parent_iir_utpr_explicit_flag, affiliate_policy_iir_utpr_by_2026, affiliate_policy_utpr_by_2026,
    affiliate_policy_iir_utpr_explicit_by_2026, affiliate_oecd_iir_by_2026, qdmtt_flag, parent_iir_utpr_flag,
    sbs_exempt, employees_sbie, assets_sbie, payroll_sbie, act_ip_panelai, act_holding_panelai, act_igf_panelai,
    analysis_profit_positive, stage2_phi, average_low_share, stage1_lowtax_profit_average,
    stage2_excess_lowtax_profit_average, stage1_distributional_low_share, stage1_lowtax_profit_distributional,
    stage2_excess_lowtax_profit_distributional, topup_after_stage2, static_tau_low, static_beta_raw,
    affiliate_cit_rate_unit, upr_panelai)
  rm(panel, frozen, sectoral)
  e <- notch_engine("BASELINE_NOTCH", processed)
  input <- e$step15_inputs()
  point_measure <- step15_measure(input)
  globe <- e$step15_globe_base(input)
  prepared <- notch_transitional_inputs(e, input, globe)
  density <- notch_density(host)
  saved_density <- diagnostic("step11_sesh_notch_summary")
  density_gap <- notch_keyed_gap(filter(density, bunching_bandwidth == .02), saved_density, "sample",
    c("placebo_missing_mass", "placebo_excess_mass", "implied_responsive_share_if_post_reform"),
    tolerance = 1e-12)
  calibration <- calibrate_stage1_measurement_error(diagnostic("step3_stage1_crossval_affiliate_year"))
  scenario_draws <- draw_stage1_measurement_error(host, calibration,
    n_draws = MEASUREMENT_ERROR_DRAWS, seed = MEASUREMENT_ERROR_SEED)
  draw_ids <- c(1L, 464L)
  stage2_sectoral <- read("stage2_sectoral_matrix")
  saved_draws <- diagnostic("step9_stage1_measurement_error_scenario_draws") |>
    filter(draw_id %in% draw_ids)
  saved_profit <- diagnostic("step07a_profit_correction_final_revenue_points") |>
    filter(specification == "preferred_correction")
  activity <- build_collector_activity(core)
  exits <- set_names(map(EU27_ISO3, ~ build_parent_year_utpr_weights(filter(activity, collector != .x),
    weights$policy)), EU27_ISO3)
  strict <- e$nash_load_panels()$L4_strict
  exposure <- map_dfr(c(0, .01, .02, .03), function(width) bind_rows(
    notch_exposure(core, width, "core_L1_L3"),
    notch_exposure(strict, width, "preferred_L4_strict")))
  saved_dense <- read("stage4_5_revenue_country_year")
  saved_game <- diagnostic("step13_unilateral_qdmtt_deviation_matrix")
  saved_accounting <- diagnostic("step15_globe_accounting_factorial_anova") |>
    filter(record == "scenario_revenue", design == "full_64") |>
    transmute(level = distributional_level, country = scope, window, scenario_id,
      assigned_usd = cumulative_revenue_usd_bn * 1e9)
  saved_cit <- diagnostic("step7_reallocation_destination_rules_comparison") |>
    filter(rule == "B") |>
    select(window, scenario_id, country, gross_cit_usd = gross_cit, source_cit_lost_usd = source_cit_lost)
  saved_screen <- diagnostic("step12_cbcr_to_budget_waterfall_bridge") |>
    filter(record_type == "waterfall", scope == "EU27",
      step %in% c("05_safe_harbour_2026", "05_safe_harbour_2026_preserve_qdmtt")) |>
    transmute(window, preserve_qdmtt = grepl("preserve", step), assigned_eu27_usd = collector)
  results <- set_names(map(NOTCH_ARMS, function(specification) {
    message("Evaluating ", specification)
    engine <- notch_engine(specification, processed)
    revised <- notch_response(core, specification)
    detail <- notch_allocate(revised, weights)
    fast <- engine$step15_evaluate(input, point_measure, check = TRUE)
    raw_gap <- notch_fast_compare(input, revised, engine, point_measure)
    accounting <- notch_accounting(engine, input, point_measure, fast$revenue, globe)
    cit <- notch_cit(revised, stage1, host)
    draws <- map_dfr(draw_ids, function(id) {
      engine$run_one_measurement_error_draw(id, stage1_draw_for_id(scenario_draws, id),
        host, stage2, stage2_sectoral, schedule, flags, model, weights)$scenario_summary |>
        select(draw_id, scenario_id, eu_revenue)
    })
    profit <- notch_profit_point(engine, revised)
    message("  Recomputing repeal and opt-out")
    game <- notch_game(engine, weights, exits, input$beta)
    screen <- notch_screen(engine, prepared, weights, input$beta)
    results <- notch_core_outputs(detail)
    if (specification == "BASELINE_NOTCH") {
      dense_gap <- notch_keyed_gap(detail$allocation$revenue_country_year_eu27, saved_dense,
        c("scenario_id", "country", "year"), "revenue")
      fast_gap <- e$step15_check_production(input, fast$revenue)
      factor_gap <- notch_keyed_gap(filter(mutate(map_dfr(accounting, "totals"), assigned_usd = assigned_usd_bn * 1e9),
        window %in% names(STEP15_WINDOWS)), saved_accounting,
        c("level", "country", "window", "scenario_id"), "assigned_usd")
      game_gap <- notch_keyed_gap(filter(game, window %in% names(NASH_WINDOWS)), saved_game,
        c("level", "country", "deviation", "regime", "window"),
        c("adoption_qdmtt", "mne_topup_saved", "delta_domestic_collector", "host_unsupported_utpr"))
      cit_gap <- notch_keyed_gap(filter(cit, scenario_id %in% NASH_IDS,
        country %in% c(EU27_ISO3, "EU27")), saved_cit,
        c("window", "scenario_id", "country"), c("gross_cit_usd", "source_cit_lost_usd"))
      screen_gap <- notch_keyed_gap(screen, filter(saved_screen, window %in% names(NOTCH_WINDOWS)),
        c("window", "preserve_qdmtt"), "assigned_eu27_usd")
      draw_gap <- notch_keyed_gap(draws, saved_draws, c("draw_id", "scenario_id"), "eu_revenue")
      profit_gap <- notch_keyed_gap(profit, saved_profit, "factor4_sbs",
        c("global_allocated_revenue", "eu27_final_revenue", "unsupported_utpr"))
      results$baseline <- tibble::enframe(c(stage05_source = stage5_gap, stage06_receipts = dense_gap,
        stage11_point = fast_gap, stage11_accounting = factor_gap, stage11_game = game_gap,
        stage09_cit = cit_gap, stage10_screen = screen_gap, stage07a_draws = draw_gap,
        stage07a_profit_point = profit_gap), name = "reconciliation", value = "max_gap_usd")
    }
    results$checks <- tibble(detailed_conservation_usd = results$gap, source_dense_sparse_usd = raw_gap,
      sparse_conservation_usd = fast$max_global_conservation_gap)
    results$gap <- NULL
    c(results, list(cit = cit, accounting = map_dfr(accounting, "totals"),
      accounting_effects = map_dfr(accounting, "effects"), game = game,
      transitional_overlap = screen, measurement_draws = draws, profit_point = profit))
  }), NOTCH_ARMS)
  tables <- set_names(map(names(results[[1L]]), function(name) {
    map_dfr(results, name, .id = "specification")
  }), names(results[[1L]]))
  ranges <- tables$channels |> filter(country == "EU27") |>
    summarise(assigned_usd = sum(assigned_usd), .by = c(specification, window, scenario_id)) |>
    summarise(scenarios = n(), minimum_usd = min(assigned_usd), maximum_usd = max(assigned_usd),
      minimum_scenario = scenario_id[which.min(assigned_usd)], maximum_scenario = scenario_id[which.max(assigned_usd)],
      .by = c(specification, window))
  tables <- c(tables, list(exposure = exposure, core_ranges = ranges, density_placebo = density,
    density_reconciliation = tibble(max_absolute_share_gap = density_gap)))
  purrr::iwalk(tables, ~ write_csv(.x, file.path(output, paste0(.y, ".csv"))))
  invisible(tables)
}

if (is_direct_script_run("code/diagnostics/behavioural_notch.R")) {
  args <- commandArgs(trailingOnly = TRUE)
  if (!length(args) %in% c(1L, 2L)) {
    stop("Supply a fresh diagnostic output directory and optionally the frozen processed directory", call. = FALSE)
  }
  run_behavioural_notch_diagnostic(args[[1L]], if (length(args) == 2L) args[[2L]] else PROCESSED_DIR)
}
