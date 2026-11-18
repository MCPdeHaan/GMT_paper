# Standalone comparison on frozen inputs. Store full keyed objects in isolated
# output roots, with compact summaries suitable for the verification record.
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "00_helpers.R"), local = TRUE)

capture_fiscal_destinations <- function(engine_root, input_root) {
  engine_root <- normalizePath(engine_root, mustWork = TRUE)
  input_root <- normalizePath(input_root, mustWork = TRUE)
  e <- new.env(parent = environment(capture_fiscal_destinations))
  withr::with_envvar(c(GMT_PROJECT_ROOT = engine_root, GMT_OUTPUT_ROOT = input_root),
    source(file.path(engine_root, "code", "09_econometric_and_reallocation_extensions.R"), local = e))
  read <- e$read_step6_input
  panel <- read("stage3_factorial_pair_year")
  stage1 <- read("stage1_bilateral_panel")
  host <- read("stage1_affiliate_year")
  direct <- read("stage4_5_revenue_country_year")
  keys <- c("scenario_id", "parent", "affiliate", "year")
  source_response <- panel |> select(all_of(keys), static_tau_low, behavioural_regime,
    starts_with("reallocated_profit"), topup_after_stage2, topup_after_behaviour)
  assert_unique_keys(source_response, keys, "diagnostic source response")
  sources <- panel |> filter(reallocated_profit > 0, factor5_behaviour == "behavioural") |>
    transmute(across(all_of(keys)), source_id = row_number(), source_etr = static_tau_low,
      reallocated_profit, exposed_topup_before_response = topup_after_stage2,
      source_cit_lost = reallocated_profit * static_tau_low,
      source_is_eu27 = affiliate %in% EU27_ISO3)
  raw <- panel |> transmute(parent, destination = affiliate, year,
    statutory_rate = e$panel_statutory_rate(panel, "destination_gate"),
    destination_etr = etr_panelai_stage1, employees = employees_sbie, payroll = payroll_sbie,
    upr = upr_panelai) |> distinct()
  footprint <- e$build_rule_b_footprint(panel)
  global <- e$build_rule_b_global_footprint(footprint, host)
  routes <- e$allocate_rule_b_sources(sources, footprint, global)
  priced_routes <- e$attach_destination_prices(routes, e$destination_price_lookup(panel), "received")

  reason <- function(x) x |> mutate(rejection = case_when(
    destination == affiliate ~ "origin",
    is.na(statutory_rate) ~ "missing_gate",
    statutory_rate < GMT_RATE ~ "below_gate",
    pmax(coalesce_zero(employees), 0) == 0 & pmax(coalesce_zero(payroll), 0) == 0 &
      pmax(coalesce_zero(upr), 0) == 0 ~ "no_positive_activity",
    is.na(destination_etr) ~ "missing_destination_etr",
    destination_etr <= source_etr ~ "destination_etr_not_higher",
    TRUE ~ "admissible"))
  candidate_keys <- c(keys, "source_etr", "destination", "statutory_rate", "destination_etr",
    "employees", "payroll", "upr", "rejection")
  primary <- sources |> inner_join(raw, by = c("parent", "year"), relationship = "many-to-many") |>
    reason() |> select(all_of(candidate_keys))
  fallback <- sources |> anti_join(filter(routes, route == "parent_activity"), by = "source_id") |>
    inner_join(global, by = "year", relationship = "many-to-many") |>
    reason() |> select(all_of(candidate_keys))
  allocated <- routes |> summarise(assigned_total = sum(received), weights = sum(weight),
    eu27_received = sum(received[destination %in% EU27_ISO3]), .by = c(source_id, route)) |>
    rename(received = assigned_total)
  support <- sources |>
    left_join(allocated, by = "source_id", relationship = "one-to-one") |>
    mutate(residual = received - reallocated_profit)
  stopifnot(!anyNA(support[c("route", "eu27_received")]), max(abs(support$residual)) < 1e-3)
  classified <- support |> mutate(scope = if_else(source_is_eu27, "EU27", "non-EU27"))
  support_summary <- bind_rows(classified, mutate(classified, scope = "Global")) |>
    summarise(sources = n(), relocated_profit = sum(reallocated_profit),
      exposed_topup_before_response = sum(exposed_topup_before_response),
      source_cit_lost = sum(source_cit_lost), profit_assigned_eu27 = sum(eu27_received),
      .by = c(scenario_id, year, scope, route))
  step9 <- e$read_step6_factorial_input()
  preferred <- filter(step9, scenario_id %in% e$STEP7_PREFERRED)
  pool <- e$build_parent_specific_reallocation(step9, host)
  compatibility <- e$build_rule_a_global_reallocation(panel)
  hub <- e$build_hub_destination_routes(preferred, stage1, host)
  hub_origins <- preferred |> filter(reallocated_profit > 0) |>
    transmute(across(all_of(keys)), reallocated_profit, source_id = row_number())
  hub_gaps <- hub |> summarise(received = sum(received), .by = c(rule, source_id)) |>
    left_join(hub_origins, by = "source_id", relationship = "many-to-one") |>
    mutate(residual = received - reallocated_profit)
  max_residual <- function(x, key, label, residual) {
    x |>
      mutate(residual_usd = .data[[residual]]) |>
      slice_max(abs(residual_usd), n = 1, with_ties = FALSE) |>
      transmute(rule = label, key = do.call(paste, c(as.list(dplyr::pick(all_of(key))), sep = "/")),
        residual_usd)
  }
  residuals <- bind_rows(max_residual(support, keys, "B full source", "residual"),
    max_residual(pool$conservation, c("scenario_id", "parent", "year"), "A parent pool", "allocation_gap"),
    max_residual(compatibility$conservation, c("scenario_id", "year"), "A global scenario-year", "allocation_gap"),
    max_residual(filter(hub_gaps, rule == "C"), keys, "C preferred source", "residual"))
  comparison <- e$build_destination_comparison(step9, direct, stage1, host)
  rate_roles <- e$compare_destination_rate_roles(step9, stage1, host)
  matrix <- e$build_reallocation_matrix(panel, host)
  stopifnot(identical(matrix$matrix, read("stage3_reallocation_matrix")))
  weights <- e$read_stage4_utpr_weights()
  fiscal_b <- e$build_total_fiscal_country_year(step9, direct, host, weights, matrix$matrix)
  fiscal_a <- e$build_total_fiscal_country_year(step9, direct, host, weights)
  collector <- read("stage4_5_revenue_by_channel_global")
  list(source_response = source_response, primary_candidates = primary,
    fallback_candidates = fallback, b_routes = priced_routes, support = support,
    support_summary = support_summary, residuals = residuals, a_global = compatibility,
    a_parent = pool, b_c_routes = hub, b_c_route_conservation = hub_gaps,
    destination_matrix = matrix, fiscal_a = fiscal_a, fiscal_b = fiscal_b,
    destination_comparison = comparison, rate_roles = rate_roles, collector = collector)
}

write_destination_support <- function(evidence, directory) {
  counts <- function(x, tier) {
    x |> summarise(candidates = n(),
      any_activity_missing = sum(is.na(employees) | is.na(payroll) | is.na(upr)),
      all_activity_zero = sum(employees == 0 & payroll == 0 & upr == 0, na.rm = TRUE),
      any_activity_negative = sum(employees < 0 | payroll < 0 | upr < 0, na.rm = TRUE),
      .by = rejection) |> mutate(tier, .before = 1)
  }
  write_csv(bind_rows(counts(evidence$primary_candidates, "same_parent"),
    counts(evidence$fallback_candidates, "global_year")), file.path(directory, "candidate_counts.csv"))
  totals <- evidence$support |>
    summarise(sources = n(), profit = sum(reallocated_profit), source_cit_lost = sum(source_cit_lost),
      eu27_destination_profit = sum(eu27_received),
      zero_eu27_destination_sources = sum(eu27_received == 0), .by = route)
  write_csv(totals, file.path(directory, "source_route_totals.csv"))
  compatibility <- evidence$a_global$matrix |>
    summarise(residual_usd = sum(reallocated_profit_received, na.rm = TRUE) - first(total_reallocated_profit),
      .by = c(scenario_id, year, behavioural_channel)) |>
    slice_max(abs(residual_usd), n = 1, with_ties = FALSE)
  stopifnot(max(abs(compatibility$residual_usd)) < 1e-3)
  write_csv(compatibility, file.path(directory, "global_a_channel_closure.csv"))
}

if (is_direct_script_run("code/diagnostics/fiscal_destination_parity.R")) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 3L || file.exists(args[3]) || !dir.exists(dirname(args[3]))) {
    stop("Supply a code root, frozen input root and fresh diagnostic output directory")
  }
  evidence <- capture_fiscal_destinations(args[1], args[2])
  stopifnot(dir.create(args[3]))
  for (name in names(evidence)) {
    saveRDS(evidence[[name]], file.path(args[3], paste0(name, ".rds")))
  }
  write_csv(evidence$support_summary, file.path(args[3], "support_summary.csv"))
  write_csv(evidence$residuals, file.path(args[3], "residuals.csv"))
  write_destination_support(evidence, args[3])
  write_csv(evidence$destination_comparison |>
    filter(country == "EU27", scenario_id == "x10011", window == "2017–2023") |>
    mutate(net_ordinary_cit = gross_cit - source_cit_lost), file.path(args[3], "preferred_fiscal.csv"))
  write_csv(evidence$rate_roles |>
    filter(country %in% c("EU27", "Global"), scenario_id == "x10011", window == "2017–2023"),
    file.path(args[3], "preferred_rate_roles.csv"))
}
