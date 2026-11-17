# R11b standalone audit. Monetary quantities are USD on pinned economic years.
# Each use scenario assumes an eligible incentive and election in the policy
# counterfactual. No simulated use is assigned by the production stages.
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "00_helpers.R"), local = TRUE)
source(file.path(GMT_PROJECT_ROOT, "code", "substance", "sbti_capacity.R"), local = TRUE)

sbti_cap <- function(payroll, assets, formula, payroll_share = 1, depreciation_ratio = NA_real_,
                     eligible_share = 1) {
  stopifnot(all(is.finite(payroll_share) & between(payroll_share, 0, 1)),
    all(is.finite(eligible_share) & between(eligible_share, 0, 1)),
    all(is.na(payroll) | payroll >= 0), all(is.na(assets) | assets >= 0),
    all(is.na(depreciation_ratio) | is.finite(depreciation_ratio) & depreciation_ratio >= 0))
  w <- sbti_payroll_capacity(payroll) * payroll_share
  depreciation <- depreciation_ratio * eligible_share * assets
  d <- sbti_payroll_capacity(depreciation)
  a <- sbti_carrying_value_capacity(assets) * eligible_share
  cap <- switch(match.arg(formula, c("hybrid", "payroll_only", "default", "carrying")),
    hybrid = pmax(w, a), payroll_only = w, default = pmax(w, d), carrying = a)
  tibble(cap, payroll_leg = w, assumed_depreciation = depreciation,
    depreciation_leg = d, carrying_leg = a,
    dominant_leg = case_when(
      is.na(cap) ~ "unknown", formula == "carrying" ~ "carrying_value",
      formula == "payroll_only" ~ "payroll", formula == "default" & d > w ~ "depreciation",
      formula == "hybrid" & a > w ~ "carrying_value",
      (formula == "default" & d == w) | (formula == "hybrid" & a == w) ~ "tie",
      TRUE ~ "payroll"))
}

# Check hypothetical policy-year paths. The audit uses fixed methods on
# repeated economic bases and assigns no historical elections to these bases.
sbti_cap_election_path <- function(year, carrying_elected) {
  stopifnot(length(year) > 0, length(year) == length(carrying_elected),
    is.logical(carrying_elected), !anyNA(carrying_elected), all(year >= 2026), all(diff(year) == 1))
  periods <- rle(carrying_elected)
  if (length(periods$lengths) > 1L && any(head(periods$lengths, -1L)[head(periods$values, -1L)] < 5L)) {
    stop("A carrying-value election cannot be abandoned within its first five years")
  }
  completed <- seq_len(length(periods$lengths) - 1L)
  if (any(completed > 1L & !periods$values[completed] & periods$lengths[completed] < 5L)) {
    stop("Re-election must respect the four years after the revocation year")
  }
  ifelse(carrying_elected, "carrying", "default")
}

sbti_depreciation_after_revocation <- function(depreciation, included_under_election) {
  if_else(included_under_election, 0, depreciation)
}

sbti_qti_tax_value <- function(amount, type, statutory_rate = NA_real_, preferential_rate = 0) {
  stopifnot(all(is.na(amount) | amount >= 0))
  switch(match.arg(type, c("used_credit", "claimed_deduction", "exempt_income", "preferential_income")),
    used_credit = amount, claimed_deduction = amount * statutory_rate,
    exempt_income = amount * statutory_rate,
    preferential_income = amount * (statutory_rate - preferential_rate))
}

# Positive-income ordinary-credit illustration under Arts 5.1–5.3. Income,
# tax and shield are proxies. Further current/deferred taxes, additional top-
# up tax, QRTC/MTTC reclassification and other adjustments are held outside.
sbti_tax_account <- function(income, covered_taxes, shield, qti_requested, cap,
                             mechanism = c("existing", "new", "direct_overlay"), election = TRUE) {
  mechanism <- match.arg(mechanism)
  stopifnot(all(is.na(income) | income >= 0), all(is.na(covered_taxes) | covered_taxes >= 0),
    all(is.na(shield) | shield >= 0), all(is.na(cap) | cap >= 0),
    all(is.na(qti_requested) | qti_requested >= 0), length(election) == 1L, !is.na(election))
  excess <- pmax(income - shield, 0)
  etr_initial <- safe_divide(covered_taxes, income)
  baseline <- if_else(excess == 0, 0, pmax(GMT_RATE - etr_initial, 0) * excess)
  used <- switch(mechanism, existing = qti_requested, new = pmin(qti_requested, covered_taxes),
    direct_overlay = rep(0, length(qti_requested)))
  cit_expenditure <- if (mechanism == "new") used else rep(0, length(used))
  before_election <- covered_taxes - cit_expenditure
  addback <- if (election && mechanism != "direct_overlay") {
    if_else(used == 0, 0, pmin(used, cap))
  } else rep(0, length(used))
  etr_after <- safe_divide(before_election + addback, income)
  before <- if_else(excess == 0, 0, pmax(GMT_RATE - safe_divide(before_election, income), 0) * excess)
  after <- if (mechanism == "direct_overlay") pmax(baseline - cap, 0) else
    if_else(excess == 0, 0, pmax(GMT_RATE - etr_after, 0) * excess)
  tibble(income, covered_taxes, shield, excess, qti_requested, cap, election, qti_used = used,
    ordinary_cit_expenditure = cit_expenditure, covered_taxes_before_election = before_election,
    covered_tax_addition = addback, covered_taxes_after_election = before_election + addback,
    etr_initial, etr_after, topup_percentage_initial = pmax(GMT_RATE - etr_initial, 0),
    topup_percentage_after = pmax(GMT_RATE - etr_after, 0), topup_baseline = baseline,
    topup_without_election = before, topup_after = after,
    topup_relief_from_election = before - after, topup_relief_vs_baseline = baseline - after)
}

sbti_cap_cases <- function() {
  bind_rows(tibble(case = c("hybrid", "payroll_only"), formula = case, payroll_share = 1,
      depreciation_ratio = NA_real_, eligible_share = 1),
    tibble(case = paste0("default_d", c(0, 4, 8, 12, 20)), formula = "default", payroll_share = 1,
      depreciation_ratio = c(0, .04, .08, .12, .20), eligible_share = 1),
    tibble(case = paste0("carrying_a", c(50, 75, 100)), formula = "carrying", payroll_share = 1,
      depreciation_ratio = NA_real_, eligible_share = c(.50, .75, 1)),
    tibble(case = "default_d8_w75_a75", formula = "default", payroll_share = .75,
      depreciation_ratio = .08, eligible_share = .75))
}

sbti_activity_groups <- function(activity, grain) {
  keys <- switch(match.arg(grain, c("sector", "host", "parent_country")),
    sector = c("affiliate", "year", "nace_r2"), host = c("affiliate", "year"),
    parent_country = c("parent", "affiliate", "year"))
  if (!all(keys %in% names(activity))) stop("Input lacks the observed keys for this grouping")
  assert_unique_keys(activity, intersect(c("parent", "affiliate", "year", "nace_r2"), names(activity)),
    "SBTI activity source")
  activity |>
    summarise(payroll = sum_or_na(payroll), assets = sum_or_na(assets),
      profit = sum_or_na(profit), post_sbie_topup = sum_or_na(post_sbie_topup), .by = all_of(keys))
}

sbti_matched_capacity <- function(sectors, bilateral, hosts) {
  cells <- sectors |>
    filter(rate_scenario == "initial", is.finite(sectoral_payroll), is.finite(sectoral_assets)) |>
    left_join(select(hosts, affiliate, year, stage1_distributional_low_share),
      by = c("affiliate", "year"), relationship = "many-to-one") |>
    transmute(affiliate, year, nace_r2, payroll = sectoral_payroll, assets = sectoral_assets,
      profit = sectoral_profit_proxy, post_sbie_topup = if_else(profit == 0, 0,
        profit * stage1_distributional_low_share * stage1_distributional_topup_rate * (1 - sectoral_phi)))
  include_zero <- list(retain = cells, exclude = filter(cells, is.na(profit) | profit != 0))
  cases <- sbti_cap_cases()
  imap_dfr(include_zero, function(activity, zero_profit) {
    host <- sbti_activity_groups(activity, "host")
    # Allocate the same covered totals to parent-country cells by separately
    # observed component weights. Their sum equals the common sector support.
    pairs <- bilateral |>
      filter(rate_scenario == "initial", analysis_profit_positive > 0) |>
      inner_join(rename_with(host, ~ paste0(.x, "_host"), -c(affiliate, year)),
        by = c("affiliate", "year"), relationship = "many-to-one") |>
      group_by(affiliate, year) |>
      mutate(payroll_weight = safe_divide(pmax(coalesce_zero(payroll_sbie), 0),
          sum(pmax(coalesce_zero(payroll_sbie), 0))),
        assets_weight = safe_divide(pmax(coalesce_zero(assets_sbie), 0),
          sum(pmax(coalesce_zero(assets_sbie), 0))),
        profit_weight = analysis_profit_positive / sum(analysis_profit_positive),
        topup_weight = safe_divide(coalesce_zero(stage2_topup_tax_distributional),
          sum(stage2_topup_tax_distributional, na.rm = TRUE))) |>
      ungroup() |>
      transmute(parent, affiliate, year, payroll = if_else(payroll_host == 0, 0, payroll_host * payroll_weight),
        assets = if_else(assets_host == 0, 0, assets_host * assets_weight),
        profit = profit_host * profit_weight,
        post_sbie_topup = if_else(post_sbie_topup_host == 0, 0, post_sbie_topup_host * topup_weight))
    groups <- list(sector = activity, host = host, parent_country = sbti_activity_groups(pairs, "parent_country"))
    for (data in groups) {
      stopifnot(all(is.finite(data$payroll)), all(is.finite(data$assets)),
        abs(sum(data$payroll) - sum(activity$payroll)) < .01,
        abs(sum(data$assets) - sum(activity$assets)) < .01,
        abs(sum(data$profit, na.rm = TRUE) - sum(activity$profit, na.rm = TRUE)) < .01,
        abs(sum(data$post_sbie_topup, na.rm = TRUE) - sum(activity$post_sbie_topup, na.rm = TRUE)) < .01)
    }
    imap_dfr(groups, function(data, grain) {
      pmap_dfr(cases, function(case, formula, payroll_share, depreciation_ratio, eligible_share) {
        bind_cols(data, sbti_cap(data$payroll, data$assets, formula, payroll_share,
          depreciation_ratio, eligible_share)) |>
          summarise(n_groups = n(), n_profit_unknown = sum(is.na(profit)), payroll = sum(payroll),
            assets = sum(assets), profit_known = sum(profit, na.rm = TRUE),
            post_sbie_topup_known = sum(post_sbie_topup, na.rm = TRUE),
            implied_depreciation = sum_or_na(assumed_depreciation), payroll_leg = sum(payroll_leg),
            depreciation_leg = sum_or_na(depreciation_leg), carrying_leg = sum(carrying_leg),
            payroll_dominant = sum(dominant_leg == "payroll"), depreciation_dominant = sum(dominant_leg == "depreciation"),
            carrying_dominant = sum(dominant_leg == "carrying_value"), ties = sum(dominant_leg == "tie"),
            known_profit_cap = sum(cap[!is.na(profit)]),
            cap_per_dollar_known_profit = safe_divide(known_profit_cap, profit_known),
            direct_overlay_ceiling_on_known_topup = sum(pmin(cap, post_sbie_topup), na.rm = TRUE),
            cap = sum(cap),
            .by = c(affiliate, year)) |>
          mutate(zero_profit, grain, case, formula, payroll_share, depreciation_ratio, eligible_share, .before = 1)
      })
    })
  })
}

sbti_observed_parent_capacity <- function(bilateral) {
  data <- bilateral |>
    filter(rate_scenario == "initial", analysis_profit_positive > 0,
      is.finite(payroll_sbie), payroll_sbie >= 0, is.finite(assets_sbie), assets_sbie >= 0) |>
    transmute(parent, affiliate, year, payroll = payroll_sbie, assets = assets_sbie,
      profit = analysis_profit_positive, post_sbie_topup = stage2_topup_tax_distributional)
  scopes <- list(global = data, EU27 = filter(data, affiliate %in% EU27_ISO3, year %in% 2021:2023))
  imap_dfr(scopes, function(data, scope) {
    map_dfr(c("parent_country", "host"), function(grain) {
      groups <- sbti_activity_groups(data, grain)
      pmap_dfr(sbti_cap_cases(), function(case, formula, payroll_share, depreciation_ratio, eligible_share) {
        amounts <- sbti_cap(groups$payroll, groups$assets, formula, payroll_share, depreciation_ratio, eligible_share)
        tibble(scope, first_year = min(data$year), last_year = max(data$year), grain, case,
          formula, payroll_share, depreciation_ratio, eligible_share, n_source_cells = nrow(data),
          n_groups = nrow(groups), profit = sum(data$profit), payroll = sum(data$payroll), assets = sum(data$assets),
          cap = sum(amounts$cap), capacity_per_profit = cap / sum(data$profit))
      })
    })
  })
}

sbti_reproduce_game <- function(analysis, r3, shares, weights, frozen) {
  rebuilt <- imap_dfr(r3, function(base, level) {
    payoff <- map_dfr(EU27_ISO3, function(country) {
      result <- analysis$nash_build_deviation(base$source, country, "qdmtt_repeal", weights)
      imap_dfr(analysis$NASH_STRATEGY_WINDOWS,
        ~ analysis$nash_summarise_deviation(base, result, country, .x, "SbS", .y))
    })
    analysis$nash_summarise_strategy(base, payoff, shares, weights) |>
      mutate(level, regime = "SbS", scenario_id = "x10011", benchmark = "R3_full_eu27_qdmtt_iir")
  })
  keys <- c("country", "level", "window")
  rebuilt <- arrange(select(rebuilt, all_of(names(frozen))), across(all_of(keys)))
  frozen <- arrange(frozen, across(all_of(keys)))
  stopifnot(nrow(rebuilt) == 108L, identical(select(rebuilt, all_of(keys)), select(frozen, all_of(keys))))
  for (name in names(rebuilt)) {
    if (is.numeric(rebuilt[[name]])) {
      # Reading a decimal CSV can change the final binary digit. Compare
      # the unchanged quantities within four binary64 rounding units.
      limit <- 4 * .Machine$double.eps * pmax(1, abs(frozen[[name]]))
      same <- (is.na(rebuilt[[name]]) & is.na(frozen[[name]])) |
        (!is.na(rebuilt[[name]]) & !is.na(frozen[[name]]) & rebuilt[[name]] == frozen[[name]])
      close <- abs(rebuilt[[name]] - frozen[[name]]) <= limit
      if (!all(same | (!is.na(close) & close))) stop("Historical game mismatch in ", name)
    } else stopifnot(identical(rebuilt[[name]], frozen[[name]]))
  }
  rebuilt
}

sbti_fiscal_cases <- function() {
  tribble(~arm, ~mechanism, ~case, ~grain, ~utilisation, ~fixed_use_usd, ~election,
    "no_qti", "existing", "hybrid", "sector", 0, NA_real_, TRUE,
    "legacy_overlay", "direct_overlay", "hybrid", "sector", 0, NA_real_, FALSE,
    "existing_hybrid25", "existing", "hybrid", "sector", .25, NA_real_, TRUE,
    "existing_hybrid50", "existing", "hybrid", "sector", .5, NA_real_, TRUE,
    "existing_hybrid100", "existing", "hybrid", "sector", 1, NA_real_, TRUE,
    "existing_hybrid100_pair", "existing", "hybrid", "parent_country", 1, NA_real_, TRUE,
    "existing_default_d8_50", "existing", "default_d8", "parent_country", .5, NA_real_, TRUE,
    "existing_carrying_a75_50", "existing", "carrying_a75", "parent_country", .5, NA_real_, TRUE,
    "existing_fixed_1m", "existing", "default_d8", "parent_country", NA_real_, 1e6, TRUE,
    "new_hybrid50", "new", "hybrid", "sector", .5, NA_real_, TRUE,
    "new_hybrid100", "new", "hybrid", "sector", 1, NA_real_, TRUE,
    "new_default_d8_50", "new", "default_d8", "parent_country", .5, NA_real_, TRUE,
    "new_default_d8_50_no_election", "new", "default_d8", "parent_country", .5, NA_real_, FALSE)
}

sbti_fiscal_cells <- function(source, shares, analysis, r3) {
  key <- analysis$NASH_KEYS
  rows <- source |>
    filter(scenario_id == "x10011", affiliate_is_eu27, year %in% 2021:2023,
      if (r3) stage4_qdmtt_liability > 0 else topup_after_behaviour > 0) |>
    transmute(across(all_of(key)), low_profit = stage1_lowtax_profit_distributional,
      excess_low_profit = stage2_excess_lowtax_profit_distributional,
      low_share = stage1_distributional_low_share, gap = stage1_distributional_topup_rate,
      payroll_missing = is.na(payroll_sbie), assets_missing = is.na(assets_sbie),
      payroll = pmax(coalesce_zero(payroll_sbie), 0), assets = pmax(coalesce_zero(assets_sbie), 0),
      behavioural_factor = safe_divide(topup_after_behaviour, topup_after_stage2),
      source_before = topup_after_behaviour)
  assert_unique_keys(rows, key, "SBTI fiscal source")
  stopifnot(all(is.finite(rows$behavioural_factor)), all(rows$behavioural_factor >= 0),
    all(rows$behavioural_factor <= 1 + 1e-12))
  rows |>
    inner_join(shares, by = c("affiliate", "year"), relationship = "many-to-many") |>
    mutate(income = low_profit * profit_share, excess = excess_low_profit * profit_share,
      covered_taxes = pmax(0, GMT_RATE - gap) * income)
}

sbti_model_fiscal_arm <- function(cells, candidate, parameters, key) {
  # Legacy multiplication order and its documented zero-contribution inputs.
  # The parent-country cap is redistributed by low-profit weights to keep
  # the tax/expense bases fixed and isolate the cap computation.
  args <- list(formula = parameters$formula, payroll_share = parameters$payroll_share,
    depreciation_ratio = parameters$depreciation_ratio, eligible_share = parameters$eligible_share)
  if (candidate$grain == "sector") {
    cap <- if (parameters$formula == "hybrid") {
      pmax(sbti_payroll_capacity(cells$payroll) * cells$payroll_share * cells$low_share,
        sbti_carrying_value_capacity(cells$assets) * cells$asset_share * cells$low_share)
    } else do.call(sbti_cap, c(list(cells$payroll * cells$payroll_share * cells$low_share,
      cells$assets * cells$asset_share * cells$low_share), args))$cap
  } else {
    cap <- do.call(sbti_cap, c(list(cells$payroll * cells$low_share,
      cells$assets * cells$low_share), args))$cap * cells$profit_share
  }
  requested <- if (is.na(candidate$fixed_use_usd)) candidate$utilisation * cap else
    candidate$fixed_use_usd * cells$profit_share
  tax <- sbti_tax_account(cells$income, cells$covered_taxes, pmax(0, cells$income - cells$excess),
    requested, cap, candidate$mechanism, election = candidate$election)
  bind_cols(cells, rename(select(tax, -income, -covered_taxes, -excess), shield_proxy = shield)) |>
    summarise(source_before = first(source_before), behaviour_factor = first(behavioural_factor),
      payroll_missing = first(payroll_missing), assets_missing = first(assets_missing),
      income_proxy = sum(income), covered_tax_proxy = sum(covered_taxes), excess_profit_proxy = sum(excess),
      covered_tax_before_election = sum(covered_taxes_before_election),
      covered_tax_after_election = sum(covered_taxes_after_election),
      cap = sum(cap), qti_requested = sum(qti_requested), qti_used = sum(qti_used),
      covered_tax_addition = sum(covered_tax_addition), ordinary_cit_expenditure = sum(ordinary_cit_expenditure),
      topup_before_behaviour = sum(topup_baseline), topup_without_election = sum(topup_without_election),
      topup_with_election = sum(topup_after), election_relief_before_behaviour = sum(topup_relief_from_election),
      relief_before_behaviour = sum(topup_relief_vs_baseline),
      relief_after_behaviour = sum(topup_relief_vs_baseline * behavioural_factor), .by = all_of(key)) |>
    mutate(source_after = pmax(0, source_before - relief_after_behaviour))
}

sbti_collector_pairs <- function(before, after) {
  key <- c("scenario_id", "country", "year", "channel")
  full_join(rename(before, receipts_before = revenue), rename(after, receipts_after = revenue),
    by = key, relationship = "one-to-one") |>
    mutate(across(c(receipts_before, receipts_after), coalesce_zero),
      receipts_foregone = receipts_before - receipts_after, collector_is_eu27 = country %in% EU27_ISO3)
}

sbti_fiscal_shadow <- function(analysis, panels, r3, shares, weights, legacy_strategy) {
  key <- analysis$NASH_KEYS
  cases <- sbti_fiscal_cases()
  parameters <- left_join(cases, sbti_cap_cases(), by = "case", relationship = "many-to-one")
  ledgers <- purrr::imap(panels, function(panel, level) {
    purrr::imap(list(R1 = analysis$build_source_panel(panel), R3 = r3[[level]]$source), function(base, regime) {
      base <- filter(base, scenario_id == "x10011", year %in% 2021:2023)
      before <- analysis$nash_channels(base, weights)
      cells <- sbti_fiscal_cells(base, shares, analysis, regime == "R3")
      use_arms <- if (regime == "R3") parameters else filter(parameters,
        arm %in% c("no_qti", "existing_default_d8_50", "existing_carrying_a75_50", "new_default_d8_50"))
      pmap <- lapply(seq_len(nrow(use_arms)), function(i) {
        candidate <- use_arms[i, ]
        measures <- sbti_model_fiscal_arm(cells, candidate, candidate, key)
        stopifnot(max(abs(measures$topup_before_behaviour * measures$behaviour_factor - measures$source_before)) < 1e-3)
        counterfactual <- base |>
          left_join(select(measures, all_of(key), source_after), by = key, relationship = "one-to-one") |>
          mutate(topup_after_behaviour = coalesce(source_after, topup_after_behaviour)) |>
          analysis$build_source_panel()
        after <- analysis$nash_channels(counterfactual, weights)
        collectors <- sbti_collector_pairs(before$channels, after$channels)
        outcome <- tibble(baseline_topup = sum(base$topup_after_behaviour), revised_topup = sum(counterfactual$topup_after_behaviour),
          affected_baseline_topup = sum(measures$source_before), cap = sum(measures$cap), qti_used = sum(measures$qti_used),
          covered_tax_addition = sum(measures$covered_tax_addition), relief_before_behaviour = sum(measures$relief_before_behaviour),
          relief_after_behaviour = sum(measures$relief_after_behaviour),
          qdmtt_foregone = sum(collectors$receipts_foregone[collectors$channel == "QDMTT"]),
          iir_foregone = sum(collectors$receipts_foregone[collectors$channel == "IIR"]),
          utpr_foregone = sum(collectors$receipts_foregone[collectors$channel == "UTPR"]),
          eu27_receipts_foregone = sum(collectors$receipts_foregone[collectors$collector_is_eu27]),
          global_receipts_foregone = sum(collectors$receipts_foregone),
          unsupported_before = sum(before$unsupported_utpr$unsupported_utpr),
          unsupported_after = sum(after$unsupported_utpr$unsupported_utpr),
          extinguished_before = sum(base$stage4_sbs_extinguished_liability),
          extinguished_after = sum(counterfactual$stage4_sbs_extinguished_liability),
          ordinary_cit_expenditure = sum(measures$ordinary_cit_expenditure),
          global_fiscal_cost = global_receipts_foregone + ordinary_cit_expenditure,
          eu27_fiscal_cost = eu27_receipts_foregone + ordinary_cit_expenditure,
          max_conservation_gap = max(before$max_gap, after$max_gap))
        stopifnot(abs(outcome$baseline_topup - outcome$revised_topup - outcome$global_receipts_foregone -
          (outcome$extinguished_before - outcome$extinguished_after) -
          (outcome$unsupported_before - outcome$unsupported_after)) < .01)
        annotate <- function(x) mutate(x, level, regime, arm = candidate$arm, .before = 1)
        list(source = annotate(measures), collectors = annotate(collectors), summary = annotate(outcome))
      })
      lapply(c("source", "collectors", "summary"), function(name) bind_rows(lapply(pmap, `[[`, name))) |>
        setNames(c("source", "collectors", "summary"))
    })
  })
  flatten <- function(name) bind_rows(lapply(ledgers, function(level) bind_rows(lapply(level, `[[`, name))))
  source <- flatten("source")
  collectors <- flatten("collectors")
  # R3 keeps every affected source in domestic QDMTT. Country and window
  # reporting keeps the fiscal treatment separate from the repeal arm.
  strategy <- imap_dfr(analysis$NASH_STRATEGY_WINDOWS, function(years, window) {
    subset <- filter(source, regime == "R3", year %in% years)
    collection <- collectors |>
      filter(regime == "R3", year %in% years) |>
      summarise(qdmtt_foregone = sum(receipts_foregone[channel == "QDMTT"]),
        iir_foregone = sum(receipts_foregone[channel == "IIR"]),
        utpr_foregone = sum(receipts_foregone[channel == "UTPR"]),
        remaining_qdmtt = sum(receipts_after[channel == "QDMTT"]), .by = c(level, arm, country))
    subset |>
      summarise(qti_used = sum(qti_used), capacity = sum(cap), coverage_addback = sum(covered_tax_addition),
        ordinary_cit_expenditure = sum(ordinary_cit_expenditure), topup_saved = sum(relief_after_behaviour),
        source_after = sum(source_after), .by = c(level, arm, affiliate)) |>
      rename(country = affiliate) |>
      left_join(collection, by = c("level", "arm", "country"), relationship = "one-to-one") |>
      left_join(select(filter(legacy_strategy, .data$window == .env$window), country, level, repeal_topup_relief,
        repeal_foreign_soakup, repeal_domestic_iir, repeal_domestic_utpr, repeal_net_domestic_tax_foregone,
        repeal_profit_retained, repeal_critical_weight, overlay_topup_relief, existing_qti_election_topup_relief,
        new_qti_ordinary_cit_cost, adoption_qdmtt), by = c("country", "level"), relationship = "many-to-one") |>
      mutate(window, net_domestic_cost = qdmtt_foregone + iir_foregone + utpr_foregone + ordinary_cit_expenditure,
        mne_saving = topup_saved + ordinary_cit_expenditure,
        mne_saving_per_cost = safe_divide(mne_saving, net_domestic_cost), incentive_retained_profit = 0,
        incentive_critical_weight = NA_real_, beats_repeal_topup = topup_saved - repeal_topup_relief > 1e-3)
  })
  stopifnot(max(abs(strategy$topup_saved[strategy$arm == "legacy_overlay"] -
      strategy$overlay_topup_relief[strategy$arm == "legacy_overlay"])) < .01,
    max(abs(strategy$topup_saved[strategy$arm == "existing_hybrid100"] -
      strategy$existing_qti_election_topup_relief[strategy$arm == "existing_hybrid100"])) < .01,
    max(abs(strategy$ordinary_cit_expenditure[strategy$arm == "new_hybrid100"] -
      strategy$new_qti_ordinary_cit_cost[strategy$arm == "new_hybrid100"])) < .01)
  list(fiscal_parameters = parameters, fiscal_summary = flatten("summary"), source_ledger = source,
    collector_ledger = collectors, repeal_comparison = strategy)
}

sbti_payroll_support <- function(bilateral, sectors, hosts, hourly, analysis) {
  base <- filter(bilateral, analysis_profit_positive > 0)
  # Exact host-year, positive economy-wide hourly earnings in nominal USD.
  # A 2,000-hour year is a transparent annualisation assumption.
  sectors_total <- c("ECO_ISIC4_TOTAL", "ECO_ISIC3_TOTAL", "ECO_AGGREGATE_TOTAL", "ECO_SECTOR_TOTAL")
  wages <- hourly |>
    filter(sex == "SEX_T", currency == "CUR_TYPE_USD", sector %in% sectors_total, is.finite(value), value > 0) |>
    mutate(priority = match(sector, sectors_total)) |>
    group_by(jurisdiction, year) |>
    slice_min(priority, with_ties = TRUE) |>
    summarise(hourly_usd = if (n_distinct(value) == 1L) first(value) else NA_real_, .groups = "drop") |>
    rename(affiliate = jurisdiction)
  ratio <- base$payroll_sbie[base$rate_scenario == "initial"] / base$analysis_profit_positive[base$rate_scenario == "initial"]
  ratios <- quantile(ratio[is.finite(ratio) & ratio > 0], c(.25, .75), names = FALSE)
  matched <- base |>
    left_join(wages, by = c("affiliate", "year"), relationship = "many-to-one") |>
    mutate(replacement = if_else(is.na(payroll_sbie) & is.finite(employees_sbie) & employees_sbie >= 0 &
      is.finite(hourly_usd), employees_sbie * hourly_usd * 2000, NA_real_),
      payroll_status = case_when(
        is.na(payroll_sbie) & !is.na(replacement) ~ "missing_proxy_hourly_available",
        is.na(payroll_sbie) ~ payroll_sbie_source,
        payroll_sbie == 0 ~ "zero_proxy",
        affiliate_wage_stale_flag ~ "stale_wage_proxy_gt5",
        TRUE ~ "positive_other_wage_proxy"))
  scopes <- function(x) bind_rows(mutate(x, scope = "global"),
    mutate(filter(x, affiliate_is_eu27), scope = "EU27"))
  provenance <- scopes(matched) |>
    summarise(cells = n(), anchored_employee_cells = sum(is.finite(employees_sbie)),
      eligible_payroll_observed = FALSE, profit = sum(analysis_profit_positive),
      payroll_available = sum_or_na(payroll_sbie), asset_available = sum_or_na(assets_sbie),
      stage1_topup = sum(stage1_topup_tax_distributional, na.rm = TRUE),
      .by = c(scope, rate_scenario, payroll_status, payroll_sbie_source))
  cases <- c("legacy_zero", "available_only", "hourly_supported_only", "donor_p25", "donor_p75")
  panels <- setNames(lapply(cases, function(case) {
    wages <- switch(case, legacy_zero = coalesce_zero(matched$payroll_sbie),
      available_only = matched$payroll_sbie,
      hourly_supported_only = coalesce(matched$payroll_sbie, matched$replacement),
      donor_p25 = coalesce(matched$payroll_sbie, matched$replacement, matched$analysis_profit_positive * ratios[1]),
      donor_p75 = coalesce(matched$payroll_sbie, matched$replacement, matched$analysis_profit_positive * ratios[2]))
    matched |>
      mutate(case = .env$case, payroll_case = wages,
        sbie = if_else(is.na(payroll_case), NA_real_, analysis$compute_sbie_value(payroll_case, assets_sbie, sigma_w, sigma_a)),
        excess = pmax(analysis_profit_positive - sbie, 0),
        topup = coalesce_zero(stage1_topup_tax_distributional) * (1 - analysis$compute_phi_ratio(sbie, analysis_profit_positive)),
        cap = sbti_maximum_capacity(payroll_case, assets_sbie),
        cap_with_historical_assets = sbti_maximum_capacity(payroll_case, coalesce_zero(assets_sbie)),
        low_profit_cap = cap_with_historical_assets * stage1_distributional_low_share,
        overlay_if_sbie_fixed = pmin(stage2_topup_tax_distributional, low_profit_cap),
        overlay_if_sbie_revised = pmin(topup, low_profit_cap))
  }), cases)
  bilateral_summary <- scopes(bind_rows(panels)) |>
    mutate(payroll_originally_missing = is.na(payroll_sbie)) |>
    summarise(cells = n(), missing_case_payroll = sum(is.na(payroll_case)), missing_asset = sum(is.na(assets_sbie)),
      hourly_replacement = sum(!is.na(replacement) & !is.na(payroll_case) & case %in% c("hourly_supported_only", "donor_p25", "donor_p75")),
      profit = sum(analysis_profit_positive), payroll_subtotal = sum_or_na(payroll_case),
      assets_subtotal = sum_or_na(assets_sbie), sbie_subtotal = sum_or_na(sbie),
      excess_subtotal = sum_or_na(excess), topup_subtotal = sum_or_na(topup),
      capacity_subtotal = sum_or_na(cap), hybrid_capacity_zero_asset_contribution = sum_or_na(cap_with_historical_assets),
      overlay_sbie_fixed = sum_or_na(overlay_if_sbie_fixed), overlay_sbie_revised = sum_or_na(overlay_if_sbie_revised),
      .by = c(scope, rate_scenario, case, payroll_originally_missing)) |>
    mutate(donor_wage_ratio = case_when(case == "donor_p25" ~ ratios[1], case == "donor_p75" ~ ratios[2]))
  host_payroll <- bind_rows(panels) |>
    filter(affiliate_is_eu27, year %in% 2021:2023) |>
    summarise(total_payroll_case = if (anyNA(payroll_case)) NA_real_ else sum(payroll_case),
      supported_payroll_subtotal = sum_or_na(payroll_case), missing_payroll_cells = sum(is.na(payroll_case)),
      .by = c(case, affiliate, year, rate_scenario))
  sector_summary <- host_payroll |>
    inner_join(select(sectors, affiliate, year, rate_scenario, nace_r2, sectoral_payroll,
      sectoral_payroll_share_used, sectoral_assets, sectoral_profit_proxy, sectoral_phi,
      sigma_w, sigma_a, stage1_distributional_topup_rate),
      by = c("affiliate", "year", "rate_scenario"), relationship = "many-to-many") |>
    left_join(select(hosts, affiliate, year, stage1_distributional_low_share),
      by = c("affiliate", "year"), relationship = "many-to-one") |>
    mutate(payroll_case = total_payroll_case * sectoral_payroll_share_used,
      sbie = if_else(is.na(total_payroll_case), NA_real_,
        analysis$compute_sbie_value(payroll_case, sectoral_assets, sigma_w, sigma_a)),
      excess = pmax(sectoral_profit_proxy - sbie, 0),
      low_profit = stage1_distributional_low_share * sectoral_profit_proxy,
      topup = stage1_distributional_topup_rate * stage1_distributional_low_share * excess,
      cap = sbti_maximum_capacity(payroll_case, sectoral_assets),
      overlay_revised = pmin(topup, cap * stage1_distributional_low_share),
      topup_fixed = low_profit * stage1_distributional_topup_rate * (1 - sectoral_phi),
      overlay_fixed = pmin(topup_fixed, cap * stage1_distributional_low_share)) |>
    summarise(cells = n(), missing_payroll_cells = first(missing_payroll_cells),
      payroll_subtotal = sum_or_na(payroll_case), assets_subtotal = sum_or_na(sectoral_assets),
      profit_subtotal = sum_or_na(sectoral_profit_proxy), sector_sbie_subtotal = sum_or_na(sbie),
      sector_excess_subtotal = sum_or_na(excess), sector_topup_subtotal = sum_or_na(topup),
      sector_capacity_subtotal = sum_or_na(cap), overlay_sbie_fixed = sum_or_na(overlay_fixed),
      overlay_sbie_revised = sum_or_na(overlay_revised),
      .by = c(case, rate_scenario, affiliate, year))
  list(payroll_provenance = provenance, missing_bilateral_activity = bilateral_summary,
    missing_sectoral_activity = sector_summary)
}

sbti_factor_scales <- function(analysis, sectors, hosts, aggregate, sector_only, case) {
  key <- c("rate_scenario", "affiliate", "year")
  if (case == "no_qti") return(sector_only |>
    select(all_of(key), starts_with("sector_only")) |>
    pivot_longer(starts_with("sector_only"), names_to = "etr", names_prefix = "sector_only_",
      values_to = "scale_sectoral") |>
    mutate(x1_etr = as.integer(etr == "distributional"), scale_overlay = 1) |>
    select(-etr))
  setup <- filter(sbti_cap_cases(), .data$case == .env$case)
  raw <- sectors |>
    mutate(cap = sbti_cap(sectoral_payroll, sectoral_assets, setup$formula,
      setup$payroll_share, setup$depreciation_ratio, setup$eligible_share)$cap,
      # The alternative and the historical overlay share the finite capacity
      # support. The no-use sectoral control has no capacity-data gate.
      increase_in_etr = if_else(is.finite(sectoral_kappa), safe_divide(.5 * cap, sectoral_profit_proxy), NA_real_))
  map_dfr(c(0L, 1L), function(etr) {
    branch <- c("average", "distributional")[etr + 1L]
    share_field <- c("average_low_share", "stage1_distributional_low_share")[etr + 1L]
    gap_field <- c("average_topup_rate", "stage1_distributional_topup_rate")[etr + 1L]
    rate_field <- paste0("aggregate_tax_per_profit_", branch)
    base <- aggregate |>
      transmute(across(all_of(key)), aggregate_rate = .data[[rate_field]]) |>
      left_join(transmute(hosts, affiliate, year, low_share = .data[[share_field]], gross_gap = .data[[gap_field]]),
        by = c("affiliate", "year"), relationship = "many-to-one") |>
      mutate(aggregate_filter = safe_divide(aggregate_rate, low_share * gross_gap))
    rates <- raw |>
      inner_join(base, by = key, relationship = "many-to-one") |>
      summarise(sectoral_rate = first(low_share) * weighted_mean_available(
          pmax(gross_gap - increase_in_etr, 0) * (1 - sectoral_phi), sectoral_profit_proxy),
        overlay_rate = first(low_share) * weighted_mean_available(
          pmax(gross_gap - increase_in_etr, 0) * aggregate_filter, sectoral_profit_proxy),
        .by = all_of(key)) |>
      left_join(select(base, all_of(key), aggregate_rate), by = key, relationship = "one-to-one") |>
      transmute(across(all_of(key)), same_sectoral = safe_divide(sectoral_rate, aggregate_rate),
        same_overlay = safe_divide(overlay_rate, aggregate_rate))
    reference <- filter(rates, year == analysis$SECTORAL_REFERENCE_YEAR) |>
      transmute(rate_scenario, affiliate, ref_sectoral = same_sectoral, ref_overlay = same_overlay)
    base |>
      select(all_of(key)) |>
      left_join(rates, by = key, relationship = "one-to-one") |>
      left_join(reference, by = c("rate_scenario", "affiliate"), relationship = "many-to-one") |>
      transmute(across(all_of(key)), x1_etr = etr,
        scale_sectoral = coalesce(same_sectoral, ref_sectoral, 1), scale_overlay = coalesce(same_overlay, ref_overlay, 1))
  })
}

sbti_factor_shadow <- function(analysis, bilateral, sectors, hosts, weights) {
  panel <- analysis$read_stage5_input("stage3_factorial_pair_year")
  sector_only <- analysis$build_split_substance_scales()
  aggregate <- analysis$build_sectoral_factor2_bridge(bilateral, hosts, sectors)
  split <- analysis$build_split_substance_variant(panel, sector_only)
  factors <- c("x1_etr", "x2a_sectoral", "x2b_sbti", "x3_rates", "x4_sbs", "x5_behaviour")
  design <- distinct(split, scenario_id, across(all_of(factors)))
  legacy_core <- analysis$read_stage5_input("stage4_5_revenue_country_year")
  key <- c("scenario_id", "country", "year")
  variants <- c("legacy", "no_qti", "default_d8", "carrying_a75")
  results <- lapply(variants, function(case) {
    message("Recomputing split and bundled point designs for ", case)
    if (case == "legacy") {
      x <- split
    } else {
      scales <- sbti_factor_scales(analysis, sectors, hosts, aggregate, sector_only, case)
      changed <- filter(split, x2b_sbti == 1L) |>
        left_join(scales, by = c("rate_scenario", "affiliate", "year", "x1_etr"), relationship = "many-to-one") |>
        mutate(sectoral_scale_selected = coalesce(if_else(x2a_sectoral == 1L, scale_sectoral, scale_overlay), 1),
          topup_after_stage2 = pmax(stage2_topup_selected * sectoral_scale_selected, 0)) |>
        analysis$add_behavioural_response() |>
        select(all_of(names(split)))
      x <- bind_rows(filter(split, x2b_sbti == 0L), changed)
    }
    result <- analysis$allocate_stress_variant(x, weights)
    decoded <- result$revenue |>
      select(all_of(key), revenue) |>
      left_join(design, by = "scenario_id", relationship = "many-to-one")
    diagonal <- filter(decoded, x2a_sectoral == x2b_sbti) |>
      mutate(scenario_id = paste0("x", x1_etr, x2a_sectoral, x3_rates, x4_sbs, x5_behaviour),
        x2_substance = x2a_sectoral)
    check <- select(diagonal, all_of(key), observed = revenue) |>
      inner_join(select(legacy_core, all_of(key), revenue), by = key, relationship = "one-to-one")
    stopifnot(nrow(check) == nrow(legacy_core))
    if (case == "legacy") stopifnot(max(abs(check$observed - check$revenue)) < 1e-4)
    if (case == "no_qti") {
      no_use <- decoded |>
        select(all_of(setdiff(factors, "x2b_sbti")), x2b_sbti, country, year, revenue) |>
        pivot_wider(names_from = x2b_sbti, values_from = revenue, names_prefix = "use")
      stopifnot(max(abs(no_use$use0 - no_use$use1)) < 1e-4)
    }
    core_design <- distinct(diagonal, scenario_id, across(all_of(FACTOR_COLS)))
    variance <- bind_rows(
      mutate(analysis$summarise_stress_variant(diagonal, core_design, FACTOR_COLS, case, result$gap), design = "core32"),
      mutate(analysis$summarise_stress_variant(decoded, design, factors, case, result$gap), design = "split64"))
    eligible_sources <- filter(x, affiliate_is_eu27) |>
      summarise(source_topup = sum(topup_after_behaviour), .by = c(year, scenario_id))
    means <- decoded |>
      summarise(collector_topup = sum(revenue), .by = c(year, scenario_id, all_of(factors))) |>
      left_join(eligible_sources, by = c("year", "scenario_id"), relationship = "one-to-one") |>
      filter(x1_etr == 1L, x3_rates == 0L, x5_behaviour == 1L, x4_sbs == 1L) |>
      mutate(substance = paste0(x2a_sectoral, x2b_sbti)) |>
      select(year, substance, source_topup, collector_topup) |>
      pivot_wider(names_from = substance, values_from = c(source_topup, collector_topup)) |>
      mutate(source_interaction = source_topup_11 - source_topup_10 - source_topup_01 + source_topup_00,
        collector_interaction = collector_topup_11 - collector_topup_10 - collector_topup_01 + collector_topup_00,
        case = .env$case, .before = 1)
    list(variance = variance, contrasts = means)
  })
  list(factor_variance = bind_rows(lapply(results, `[[`, "variance")),
    factor_contrasts = bind_rows(lapply(results, `[[`, "contrasts")))
}

sbti_audit_output_path <- function(input_root, output_dir, project_root = GMT_PROJECT_ROOT) {
  input <- normalizePath(input_root, mustWork = TRUE)
  project <- normalizePath(project_root, mustWork = TRUE)
  target <- file.path(normalizePath(dirname(output_dir), mustWork = TRUE), basename(output_dir))
  if (file.exists(target) || basename(target) %in% c(".", "..")) stop("Use a fresh audit directory")
  protected <- c(file.path(input, c("data", "writing")), file.path(project, c("data", "writing", ".git")))
  if (any(target == protected | startsWith(target, paste0(protected, "/")))) {
    stop("Audit output cannot be written within protected data or publication paths")
  }
  target
}

run_sbti_scientific_audit <- function(input_root, output_dir) {
  output_dir <- sbti_audit_output_path(input_root, output_dir)
  analysis <- new.env(parent = environment(run_sbti_scientific_audit))
  for (file in c("diagnostics/substance_support.R", "09_econometric_and_reallocation_extensions.R",
    "11_policy_game_and_variance_extensions.R")) sys.source(file.path(GMT_PROJECT_ROOT, "code", file), analysis)
  analysis$PROCESSED_DIR <- file.path(normalizePath(input_root), "data", "processed")
  analysis$DIAGNOSTICS_DIR <- file.path(analysis$PROCESSED_DIR, "diagnostics")
  stopifnot(dir.create(output_dir))
  baseline <- analysis$run_substance_support(input_root, file.path(output_dir, "r11a"))
  caps <- baseline$sector_capacity
  missing <- filter(baseline$bilateral_exposure, scope == "global", rate_scenario == "initial")
  stopifnot(nrow(caps) == 81L, sum(caps$matched_activity_sectors) == 2894,
    sum(caps$sectors) == 3240, abs(sum(caps$sector_first) / 1e9 - 104.493893877846) < 1e-10,
    abs(sum(caps$aggregate_first) / 1e9 - 79.943353800441) < 1e-10,
    missing$pair_years[missing$activity_support == "payroll_missing"] == 1511,
    missing$pair_years[missing$activity_support == "assets_missing"] == 4)
  panels <- analysis$nash_load_panels()
  shares <- analysis$nash_sector_shares()
  weights <- analysis$read_stage4_utpr_weights()
  r3 <- lapply(panels, function(panel) {
    source <- analysis$nash_r3_panel(panel)
    list(source = source, allocation = analysis$nash_channels(source, weights))
  })
  frozen <- read_csv(file.path(analysis$PROCESSED_DIR, "diagnostics", "step13_qdmtt_vs_sbti_strategy_comparison.csv"),
    show_col_types = FALSE)
  legacy <- sbti_reproduce_game(analysis, r3, shares, weights, frozen)
  message("Reproduced the R11a support and the 108 frozen strategy rows")
  bilateral <- analysis$nash_read("stage2_bilateral_panel")
  sectors <- analysis$nash_read("stage2_sectoral_panel")
  hosts <- analysis$nash_read("stage1_affiliate_year")
  signed <- filter(bilateral, rate_scenario == "initial", analysis_profit_positive > 0)
  signed <- bind_rows(mutate(signed, scope = "global"), mutate(filter(signed, affiliate_is_eu27), scope = "EU27")) |>
    filter(payroll_sbie < 0 | assets_sbie < 0) |>
    summarise(cells = n(), profit = sum(analysis_profit_positive), payroll = sum(payroll_sbie, na.rm = TRUE),
      assets = sum(assets_sbie, na.rm = TRUE), before_sbie = sum(stage1_topup_tax_distributional, na.rm = TRUE),
      after_sbie = sum(stage2_topup_tax_distributional, na.rm = TRUE), .by = scope)
  capacity <- sbti_matched_capacity(sectors, bilateral, hosts)
  check <- filter(capacity, zero_profit == "retain", case == "hybrid", grain == "sector")
  stopifnot(abs(sum(check$cap) - sum(caps$sector_first)) < .01,
    all(capacity$direct_overlay_ceiling_on_known_topup <= capacity$cap + .01),
    all(capacity$known_profit_cap <= capacity$cap + .01))
  wage <- sbti_payroll_support(bilateral, sectors, hosts, analysis$nash_read("wages_ilo_hourly"), analysis)
  fiscal <- sbti_fiscal_shadow(analysis, panels, r3, shares, weights, legacy)
  factors <- sbti_factor_shadow(analysis, bilateral, sectors, hosts, weights)
  examples <- bind_rows(
    mutate(sbti_tax_account(100, 0, 20, 10, 10, "existing"), case = "existing_positive_sbie"),
    mutate(sbti_tax_account(100, 10, 20, 5, 10, "new"), case = "new_within_cap"),
    mutate(sbti_tax_account(100, 10, 20, 5, 3, "new"), case = "new_above_cap"),
    mutate(sbti_tax_account(100, 0, 20, 0, 10, "direct_overlay"), case = "direct_overlay"))
  interaction <- capacity |>
    select(zero_profit, grain, case, affiliate, year, cap) |>
    pivot_wider(names_from = grain, values_from = cap) |>
    mutate(sector_minus_host = sector - host, parent_minus_host = parent_country - host) |>
    left_join(transmute(filter(capacity, case == "hybrid", grain == "sector"),
      zero_profit, affiliate, year, hybrid_sector = cap), by = c("zero_profit", "affiliate", "year"), relationship = "many-to-one") |>
    left_join(transmute(filter(capacity, case == "hybrid", grain == "host"),
      zero_profit, affiliate, year, hybrid_host = cap), by = c("zero_profit", "affiliate", "year"), relationship = "many-to-one") |>
    mutate(aggregation_formula_interaction = sector_minus_host - (hybrid_sector - hybrid_host))
  outputs <- c(list(legacy_strategy = legacy, signed_activity = signed, capacity_by_host_year = capacity,
    observed_parent_capacity = sbti_observed_parent_capacity(bilateral),
    aggregation_formula_interaction = interaction, mechanism_examples = examples),
    wage, fiscal, factors)
  provenance <- tibble(key = c("source_revision", "policy_fiscal_year_start", "economic_observation_years",
      "evidence_cutoff", "audit_date", "money_units", "behaviour_convention", "national_implementation",
      "table_iv", "statutory_rate", "utpr", "behaviour"),
    value = c("f7db342ca726d9ee1539543f0db240c89ad751be", "2026-01-01", "2017–2023",
      "2026-11-15", "2026-11-17", "USD", "fixed_adoption_response_within_fiscal_shadow",
      "conditional_unverified_for_each_jurisdiction", table_iv_specification(), statutory_rate_specification(),
      analysis$utpr_specification(), behavioural_specification()))
  outputs$audit_specification <- provenance
  inputs <- c("stage2_bilateral_panel.rds", "stage2_sectoral_panel.rds", "stage1_affiliate_year.rds",
    "stage3_factorial_pair_year.rds", "stage1_bilateral_panel.rds", "wages_ilo_hourly.rds",
    "stage4_5_utpr_parent_year_weights.rds", "stage4_5_utpr_fallback_weights.rds", "stage4_5_utpr_policy.rds",
    "diagnostics/step13_qdmtt_vs_sbti_strategy_comparison.csv")
  outputs$input_hashes <- tibble(path = inputs,
    sha256 = unname(tools::sha256sum(file.path(analysis$PROCESSED_DIR, inputs))))
  iwalk(outputs, ~ write_csv(.x, file.path(output_dir, paste0(.y, ".csv"))))
  for (file in c("legal_definition_matrix.csv", "legal_sources.csv", "input_availability.csv")) {
    stopifnot(file.copy(file.path(GMT_PROJECT_ROOT, "docs", "refactoring", "r11b", file), output_dir))
  }
  invisible(outputs)
}

if (is_direct_script_run("code/diagnostics/sbti_scientific_audit.R")) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 2L) stop("Supply the frozen input root and a fresh output directory")
  run_sbti_scientific_audit(args[1], args[2])
}
