# Real-activity formulary routes and conservation checks.
normalise_formulary_destinations <- function(destinations, keys) {
  destinations |>
    group_by(across(all_of(keys))) |>
    mutate(
      raw_weight = 0.25 * coalesce_zero(safe_divide(employees, sum(employees))) +
        0.25 * coalesce_zero(safe_divide(payroll, sum(payroll))) +
        0.50 * coalesce_zero(safe_divide(upr, sum(upr))),
      weight = if (sum(raw_weight) > 0) raw_weight / sum(raw_weight) else rep(1 / n(), n()),
      equal_weight_fallback = sum(raw_weight) == 0
    ) |>
    ungroup() |>
    filter(weight > 0)
}

build_rule_b_footprint <- function(panel) {
  footprint <- panel |>
    distinct(parent, affiliate, year, affiliate_cit_rate_unit,
      etr_panelai_stage1, employees_sbie, payroll_sbie, upr_panelai) |>
    filter(affiliate_cit_rate_unit >= GMT_RATE) |>
    transmute(
      parent, year, destination = affiliate, statutory_rate = affiliate_cit_rate_unit,
      destination_etr = etr_panelai_stage1,
      employees = pmax(coalesce_zero(employees_sbie), 0),
      payroll = pmax(coalesce_zero(payroll_sbie), 0),
      upr = pmax(coalesce_zero(upr_panelai), 0)
    ) |>
    filter(employees > 0 | payroll > 0 | upr > 0)
  assert_unique_keys(footprint, c("parent", "year", "destination"), "Rule B activity footprint")
  footprint
}

build_rule_b_global_footprint <- function(footprint, host) {
  footprint |>
    group_by(destination, year, statutory_rate) |>
    summarise(across(c(employees, payroll, upr), sum), .groups = "drop") |>
    left_join(transmute(host, destination = affiliate, year, destination_etr = avg_etr_stage1),
      by = c("destination", "year"), relationship = "many-to-one")
}

allocate_rule_b_sources <- function(sources, footprint, global) {
  # Eligibility and formula denominators depend on the source ETR.
  # Exclude the origin itself and use global activity only if its parent
  # has no eligible bilateral destination.
  stopifnot(all(is.finite(sources$source_etr)), all(sources$source_etr < GMT_RATE))
  own <- sources |>
    inner_join(footprint, by = c("parent", "year"), relationship = "many-to-many") |>
    filter(destination != affiliate, destination_etr > source_etr) |>
    normalise_formulary_destinations("source_id") |>
    mutate(route = "parent_activity")
  fallback <- sources |>
    anti_join(own, by = "source_id") |>
    inner_join(global, by = "year", relationship = "many-to-many") |>
    filter(destination != affiliate, destination_etr > source_etr) |>
    normalise_formulary_destinations("source_id") |>
    mutate(route = "global_activity")
  routes <- bind_rows(own, fallback) |>
    mutate(received = reallocated_profit * weight)
  check <- routes |>
    summarise(gap = sum(received) - first(reallocated_profit),
      weight_gap = sum(weight) - 1, .by = source_id)
  if (nrow(check) != nrow(sources) || any(abs(check$gap) >= 1e-3) ||
    any(abs(check$weight_gap) > 1e-12)) {
    stop("Rule B has an unsupported source or fails source-level conservation")
  }
  routes
}

build_rule_b_reallocation <- function(panel, host) {
  footprint <- build_rule_b_footprint(panel)
  global <- build_rule_b_global_footprint(footprint, host)
  origins <- panel |>
    filter(reallocated_profit > 0, factor5_behaviour == "behavioural") |>
    transmute(
      across(all_of(SCENARIO_VARS)), parent, affiliate, year,
      source_etr = static_tau_low, reallocated_profit,
      transfer_pricing_ip = reallocated_profit_transfer_pricing_ip,
      debt = reallocated_profit_debt, substance_planning = reallocated_profit_substance_planning
    )
  channel_columns <- c("transfer_pricing_ip", "debt", "substance_planning")
  routed <- origins |>
    group_split(scenario_id, year, .keep = TRUE) |>
    map_dfr(function(sources) {
      vintage <- first(sources$year)
      routes <- allocate_rule_b_sources(mutate(sources, source_id = row_number()),
        filter(footprint, year == vintage), filter(global, year == vintage))
      routes |>
        select(all_of(SCENARIO_VARS), year, parent, destination, route, weight,
          statutory_rate, destination_etr, source_etr, all_of(channel_columns)) |>
        pivot_longer(all_of(channel_columns), names_to = "behavioural_channel",
          values_to = "source_profit") |>
        filter(source_profit > 0) |>
        mutate(
          received = source_profit * weight,
          ordinary_cit_gross_destination_revenue = received * statutory_rate,
          ordinary_cit_gross_destination_revenue_effective = received * pmax(GMT_RATE, destination_etr),
          ordinary_cit_source_loss = received * source_etr,
          ordinary_cit_net_recovery = ordinary_cit_gross_destination_revenue - ordinary_cit_source_loss,
          global_fallback_profit_received = if_else(route == "global_activity", received, 0)
        ) |>
        summarise(
          reallocated_profit_received = sum(received),
          across(c(starts_with("ordinary_cit_"), global_fallback_profit_received), sum),
          source_parents_rule_b = n_distinct(parent),
          .by = c(all_of(SCENARIO_VARS), year, destination, behavioural_channel)
        )
    })
  if (!nrow(origins)) {
    routed <- origins |>
      transmute(across(all_of(SCENARIO_VARS)), year, destination = character(),
        behavioural_channel = character(), reallocated_profit_received = numeric(),
        ordinary_cit_gross_destination_revenue = numeric(),
        ordinary_cit_gross_destination_revenue_effective = numeric(),
        ordinary_cit_source_loss = numeric(), ordinary_cit_net_recovery = numeric(),
        global_fallback_profit_received = numeric(), source_parents_rule_b = integer())
  }
  routed
}
