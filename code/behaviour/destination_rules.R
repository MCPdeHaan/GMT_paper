# Relocated profit assignment by source or by the declared Rule A pool.
# Rates are eligibility fractions and assigned profit is in USD.
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "00_helpers.R"), local = TRUE)

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
    mutate(destination_gate_rate = panel_statutory_rate(panel, "destination_gate")) |>
    distinct(parent, affiliate, year, destination_gate_rate,
      etr_panelai_stage1, employees_sbie, payroll_sbie, upr_panelai) |>
    filter(destination_gate_rate >= GMT_RATE) |>
    transmute(
      parent, year, destination = affiliate, statutory_rate = destination_gate_rate,
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

# Stage 05's global compatibility candidates retain their original support.
build_rule_a_global_weights <- function(scenario_panel) {
  scenario_panel |>
    filter(analysis_profit_positive > 0) |>
    group_by(across(all_of(SCENARIO_VARS)),
      year,
      destination = affiliate
    ) |>
    summarise(
      destination_name = first(affiliate_jurisdiction_name),
      destination_is_eu27 = first(affiliate %in% EU27_ISO3),
      destination_is_conduit_haven =
        any(coalesce(affiliate_is_conduit_haven, FALSE), na.rm = TRUE),
      destination_cit_rate = first_non_missing(affiliate_cit_rate_unit),
      selected_low_share = weighted_mean_available(
        selected_low_share,
        analysis_profit_positive
      ),
      employees = sum(coalesce_zero(employees_sbie), na.rm = TRUE),
      payroll = sum(coalesce_zero(payroll_sbie), na.rm = TRUE),
      upr = sum(pmax(coalesce_zero(upr_panelai), 0), na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(
      high_tax_destination =
        coalesce(destination_cit_rate >= GMT_RATE, FALSE) &
          !destination_is_conduit_haven
    ) |>
    group_by(across(all_of(SCENARIO_VARS)), year) |>
    mutate(has_high_tax_destination = any(high_tax_destination, na.rm = TRUE)) |>
    filter(high_tax_destination | !has_high_tax_destination) |>
    mutate(
      employee_share = safe_divide(employees, sum(employees, na.rm = TRUE)),
      payroll_share = safe_divide(payroll, sum(payroll, na.rm = TRUE)),
      upr_share = safe_divide(upr, sum(upr, na.rm = TRUE)),
      reallocation_weight_raw = 0.25 * coalesce_zero(employee_share) +
        0.25 * coalesce_zero(payroll_share) +
        0.50 * coalesce_zero(upr_share),
      reallocation_weight = {
        total_weight <- sum(reallocation_weight_raw, na.rm = TRUE)
        if (total_weight > 0) {
          reallocation_weight_raw / total_weight
        } else {
          rep(1 / n(), n())
        }
      },
      destination_weight_source = if_else(
        has_high_tax_destination,
        "high_tax_activity_weight",
        "all_positive_activity_fallback"
      )
    ) |>
    ungroup()
}

# Stage 09's separate scenario-parent-year pool expansion.
expand_rule_a_parent_pools <- function(panel, sources) {
  # Destination eligibility depends on the observed footprint and tax code.
  # A loss-making destination may still employ workers and make sales.
  footprint <- panel |>
    mutate(destination_gate_rate = panel_statutory_rate(panel, "destination_gate")) |>
    distinct(parent, destination = affiliate, year, destination_gate_rate,
      affiliate_is_conduit_haven, employees_sbie, payroll_sbie, upr_panelai
    ) |>
    filter(destination_gate_rate >= GMT_RATE, !coalesce(affiliate_is_conduit_haven, FALSE)) |>
    transmute(
      parent, destination, year, statutory_rate = destination_gate_rate,
      employees = pmax(coalesce_zero(employees_sbie), 0),
      payroll = pmax(coalesce_zero(payroll_sbie), 0),
      upr = pmax(coalesce_zero(upr_panelai), 0)
    )
  assert_unique_keys(footprint, c("parent", "destination", "year"), "destination footprint")
  parent_weights <- normalise_formulary_destinations(footprint, c("parent", "year"))
  global_weights <- footprint |>
    group_by(destination, year, statutory_rate) |>
    summarise(across(c(employees, payroll, upr), sum), .groups = "drop") |>
    normalise_formulary_destinations("year")

  support <- distinct(parent_weights, parent, year)
  within_parent <- sources |>
    semi_join(support, by = c("parent", "year")) |>
    left_join(parent_weights, by = c("parent", "year"), relationship = "many-to-many") |>
    mutate(destination_weight_source = "parent_year")
  fallback <- sources |>
    anti_join(support, by = c("parent", "year")) |>
    left_join(global_weights, by = "year", relationship = "many-to-many") |>
    mutate(destination_weight_source = "global_year_no_eligible_parent_destination")

  bind_rows(within_parent, fallback)
}

build_hub_destination_routes <- function(panel, stage1, host) {
  keys <- c("parent", "affiliate", "year")
  bilateral <- stage1 |>
    transmute(across(all_of(keys)), etr_panelai_stage1,
      headquarters_gate_rate = panel_statutory_rate(stage1, "destination_gate", "parent"))
  sources <- panel |>
    filter(reallocated_profit > 0) |>
    transmute(across(all_of(keys)), scenario_id, source_etr = static_tau_low, reallocated_profit) |>
    left_join(bilateral |> select(-etr_panelai_stage1),
      by = keys, relationship = "many-to-one"
    ) |>
    mutate(source_id = row_number())
  stopifnot(all(is.finite(sources$source_etr)), all(sources$source_etr < GMT_RATE))
  footprint <- panel |>
    select(all_of(keys), affiliate_cit_rate_unit, any_of("affiliate_cit_destination_gate_rate"),
      employees_sbie, payroll_sbie, upr_panelai) |>
    left_join(bilateral |> select(-headquarters_gate_rate),
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
          if_else(coalesce(headquarters_gate_rate >= GMT_RATE, FALSE), 0.5, 1),
        same_country_headquarters = FALSE
      ),
    sources |>
      filter(headquarters_gate_rate >= GMT_RATE) |>
      transmute(source_id, scenario_id, year, destination = parent, route = "headquarters",
        statutory_rate = headquarters_gate_rate, received = 0.5 * reallocated_profit,
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
