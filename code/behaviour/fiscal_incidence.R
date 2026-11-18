# Ordinary CIT projections from destination profit and original source losses.
# Legal top-up waterfall calculations remain with their existing stage callers.
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "behaviour", "destination_rules.R"), local = TRUE)

build_rule_b_reallocation <- function(panel, host) {
  prices <- if ("affiliate_cit_destination_price_rate" %in% names(panel)) destination_price_lookup(panel)
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
      if (!is.null(prices)) {
        routes <- attach_destination_prices(routes, prices, "received") |>
          mutate(statutory_rate = price_rate)
      }
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

build_rule_a_global_reallocation <- function(scenario_panel) {
  source_long <- scenario_panel |>
    filter(factor5_behaviour == "behavioural", reallocated_profit > 0) |>
    transmute(
      across(all_of(SCENARIO_VARS)),
      year,
      source_parent = parent,
      source_affiliate = affiliate,
      source_affiliate_name = affiliate_jurisdiction_name,
      source_tau_low = coalesce(static_tau_low, 0),
      transfer_pricing_ip = reallocated_profit_transfer_pricing_ip,
      debt = reallocated_profit_debt,
      substance_planning = reallocated_profit_substance_planning
    ) |>
    pivot_longer(
      cols = c(transfer_pricing_ip, debt, substance_planning),
      names_to = "behavioural_channel",
      values_to = "source_reallocated_profit"
    ) |>
    filter(source_reallocated_profit > 0)

  source_totals <- source_long |>
    group_by(across(all_of(SCENARIO_VARS)), year, behavioural_channel) |>
    summarise(
      total_reallocated_profit = sum(source_reallocated_profit, na.rm = TRUE),
      weighted_source_tau = weighted_mean_available(
        source_tau_low,
        source_reallocated_profit
      ),
      source_affiliates = n_distinct(source_affiliate),
      source_parents = n_distinct(source_parent),
      .groups = "drop"
    )

  destination_weights <- build_rule_a_global_weights(scenario_panel)

  matrix <- destination_weights |>
    left_join(source_totals,
      by = c(SCENARIO_VARS, "year"),
      relationship = "many-to-many"
    ) |>
    mutate(
      total_reallocated_profit = coalesce_zero(total_reallocated_profit),
      weighted_source_tau = coalesce(weighted_source_tau, 0),
      behavioural_channel = coalesce(behavioural_channel, "none"),
      reallocated_profit_received =
        reallocation_weight * total_reallocated_profit,
      destination_cit_rate = coalesce(destination_cit_rate, GMT_RATE),
      ordinary_cit_gross_destination_revenue =
        reallocated_profit_received * destination_cit_rate,
      ordinary_cit_net_recovery =
        reallocated_profit_received *
          pmax(destination_cit_rate - weighted_source_tau, 0)
    )

  scenario_year_keys <- scenario_panel |>
    distinct(across(all_of(SCENARIO_VARS)), year)

  source_check <- source_totals |>
    group_by(across(all_of(SCENARIO_VARS)), year) |>
    summarise(
      total_reallocated_profit = sum(total_reallocated_profit, na.rm = TRUE),
      .groups = "drop"
    )

  allocated_check <- matrix |>
    group_by(across(all_of(SCENARIO_VARS)), year) |>
    summarise(
      allocated_profit = sum(reallocated_profit_received, na.rm = TRUE),
      eu27_destination_profit = sum(
        if_else(destination_is_eu27, reallocated_profit_received, 0),
        na.rm = TRUE
      ),
      ordinary_cit_gross_destination_revenue = sum(
        ordinary_cit_gross_destination_revenue,
        na.rm = TRUE
      ),
      ordinary_cit_net_recovery = sum(ordinary_cit_net_recovery, na.rm = TRUE),
      weight_sum = sum(
        reallocation_weight[behavioural_channel == first(behavioural_channel)],
        na.rm = TRUE
      ),
      destinations = n_distinct(destination),
      .groups = "drop"
    )

  conservation <- scenario_year_keys |>
    left_join(source_check, by = c(SCENARIO_VARS, "year")) |>
    left_join(allocated_check, by = c(SCENARIO_VARS, "year")) |>
    mutate(
      total_reallocated_profit = coalesce_zero(total_reallocated_profit),
      allocated_profit = coalesce_zero(allocated_profit),
      eu27_destination_profit = coalesce_zero(eu27_destination_profit),
      ordinary_cit_gross_destination_revenue =
        coalesce_zero(ordinary_cit_gross_destination_revenue),
      ordinary_cit_net_recovery = coalesce_zero(ordinary_cit_net_recovery),
      allocation_gap = allocated_profit - total_reallocated_profit
    )

  if (max(abs(conservation$allocation_gap), na.rm = TRUE) > 1e-3) {
    stop("Strategic behavioural reallocation does not conserve profit")
  }

  channel_summary <- source_totals |>
    group_by(across(all_of(SCENARIO_VARS)), behavioural_channel) |>
    summarise(
      reallocated_profit = sum(total_reallocated_profit, na.rm = TRUE),
      source_affiliates = sum(source_affiliates, na.rm = TRUE),
      source_parents = sum(source_parents, na.rm = TRUE),
      .groups = "drop"
    )

  destination_summary <- matrix |>
    filter(behavioural_channel != "none") |>
    group_by(
      across(all_of(SCENARIO_VARS)),
      destination,
      destination_name,
      destination_is_eu27,
      behavioural_channel
    ) |>
    summarise(
      reallocated_profit_received =
        sum(reallocated_profit_received, na.rm = TRUE),
      ordinary_cit_gross_destination_revenue =
        sum(ordinary_cit_gross_destination_revenue, na.rm = TRUE),
      ordinary_cit_net_recovery = sum(ordinary_cit_net_recovery, na.rm = TRUE),
      .groups = "drop"
    )

  list(
    matrix = matrix,
    conservation = conservation,
    channel_summary = channel_summary,
    destination_summary = destination_summary
  )
}

build_parent_specific_reallocation <- function(panel, affiliate_year,
  prices = if ("affiliate_cit_destination_price_rate" %in% names(panel)) destination_price_lookup(panel)) {
  keys <- c("scenario_id", "parent", "year")
  source_rows <- panel |>
    filter(reallocated_profit > 0) |>
    mutate(source_tax_loss = reallocated_profit * clamp_interval(static_tau_low, 0, GMT_RATE))
  stopifnot(all(source_rows$factor5_behaviour == "behavioural"),
    all(source_rows$static_tau_low < GMT_RATE), all(is.finite(source_rows$source_tax_loss))
  )
  sources <- source_rows |>
    group_by(across(all_of(keys))) |>
    summarise(
      reallocated_profit = sum(reallocated_profit),
      source_tax_loss = sum(source_tax_loss),
      .groups = "drop"
    ) |>
    mutate(weighted_source_etr = source_tax_loss / reallocated_profit)

  matrix <- expand_rule_a_parent_pools(panel, sources) |>
    left_join(
      transmute(affiliate_year, destination = affiliate, year, observed_etr = avg_etr_stage1),
      by = c("destination", "year"), relationship = "many-to-one"
    ) |>
    mutate(
      reallocated_profit_received = reallocated_profit * weight,
      # The observed ETR sensitivity uses the 15% floor and falls back to
      # the observed statutory rate when the affiliate-year ETR is missing.
      effective_rate_fallback = !is.finite(observed_etr),
      effective_rate = pmax(GMT_RATE, coalesce(observed_etr, statutory_rate)),
      ordinary_cit_gross_destination_revenue = reallocated_profit_received * statutory_rate,
      ordinary_cit_gross_destination_revenue_effective = reallocated_profit_received * effective_rate,
      ordinary_cit_net_recovery = reallocated_profit_received * pmax(statutory_rate - weighted_source_etr, 0)
    )
  stopifnot(!anyNA(matrix$weight), !anyNA(matrix$destination))
  if (!is.null(prices)) {
    matrix <- attach_destination_prices(matrix, prices, "reallocated_profit_received") |>
      mutate(
        effective_rate = pmax(GMT_RATE, coalesce(observed_etr, price_rate)),
        ordinary_cit_gross_destination_revenue = reallocated_profit_received * price_rate,
        ordinary_cit_gross_destination_revenue_effective = reallocated_profit_received * effective_rate,
        ordinary_cit_net_recovery = ordinary_cit_gross_destination_revenue -
          reallocated_profit_received * weighted_source_etr
      )
  }
  conservation <- matrix |>
    group_by(across(all_of(keys))) |>
    summarise(
      allocation_gap = sum(reallocated_profit_received) - first(reallocated_profit),
      weight_gap = sum(weight) - 1,
      .groups = "drop"
    )
  stopifnot(nrow(conservation) == nrow(sources),
    max(abs(conservation$allocation_gap)) < 1e-3, max(abs(conservation$weight_gap)) < 1e-12
  )
  message("Maximum reallocated-profit residual by parent-year-scenario (USD): ",
    format(max(abs(conservation$allocation_gap)), digits = 8)
  )
  list(matrix = matrix, source_rows = source_rows, conservation = conservation)
}

build_destination_routes <- function(panel, stage1, host) {
  a <- build_parent_specific_reallocation(panel, host, prices = NULL)
  route_a <- a$matrix |>
    transmute(rule = "A", scenario_id, year, destination, statutory_rate,
      route = if_else(destination_weight_source == "parent_year", "parent_activity", "global_activity"),
      received = reallocated_profit_received, same_country_headquarters = FALSE
    )
  list(routes = bind_rows(route_a, build_hub_destination_routes(panel, stage1, host)),
    sources = a$source_rows)
}

summarise_ordinary_cit_incidence <- function(routing, source_rows) {
  destination <- routing |>
    filter(destination %in% EU27_ISO3) |>
    group_by(country = destination, year, scenario_id) |>
    summarise(
      across(c(reallocated_profit_received, ordinary_cit_gross_destination_revenue,
        ordinary_cit_gross_destination_revenue_effective, ordinary_cit_net_recovery), sum),
      global_fallback_profit_received = sum(global_fallback_profit_received),
      equal_weight_profit_received = sum(reallocated_profit_received[equal_weight_fallback]),
      effective_rate_fallback_profit = sum(reallocated_profit_received[effective_rate_fallback]),
      .groups = "drop"
    )
  origin <- source_rows |>
    filter(affiliate %in% EU27_ISO3) |>
    group_by(country = affiliate, year, scenario_id) |>
    summarise(reallocated_profit_sent = sum(reallocated_profit),
      ordinary_cit_source_loss = sum(source_tax_loss), .groups = "drop"
    )
  list(destination = destination, origin = origin)
}

summarise_destination_incidence <- function(routes, source_rows) {
  receipts <- routes |>
    group_by(rule, scenario_id, year, country = destination) |>
    summarise(
      gross_cit = sum(received * statutory_rate), profit_received = sum(received),
      global_fallback_profit = sum(received[route == "global_activity"]),
      headquarters_profit = sum(received[route == "headquarters"]),
      same_country_headquarters_profit = sum(received[same_country_headquarters]), .groups = "drop"
    )
  origin <- source_rows |>
    group_by(country = affiliate, scenario_id, year) |>
    summarise(source_cit_lost = sum(source_tax_loss), profit_sent = sum(reallocated_profit), .groups = "drop")
  list(receipts = receipts, origin = origin)
}
