# Table 6 and Figure 3 present frozen collector revenue and budget benchmarks.
# Revenue inputs are already in EUR billions. Table windows are annualised
# upstream and the historical figure uses annual modelled values.

PAPER_BUDGET_COUNTRIES <- c("NLD", "DEU", "FRA", "IRL", "LUX", "BEL", "AUT", "SVK")
PAPER_BUDGET_WINDOWS <- c("FY2023", "2019–2023")
PAPER_BUDGET_LABELS <- c(
  "Dutch October 2026 direct after package", "Mindeststeuergesetz cash estimate",
  "Projet de loi de finances 2026", "Department of Finance estimate, reported by IFAC",
  "Luxembourg 2026 budget Pillar Two minimum tax", "Belgian 2024 budget",
  "Austrian MinBestG impact assessment", "Slovakia 2026 state budget Pillar Two line"
)
PAPER_BRIDGE_STEPS <- c(
  "00_baseline" = "Baseline", "01_step8_dividends" = "Dividends",
  "02_current_losses" = "Current losses", "03_prior_loss_carryforward" = "Prior losses",
  "04_envelope_tax" = "Tax envelope", "05_safe_harbour_2026" = "2026 screen"
)

# The stage supplies its diagnostic CSV reader. Check the fields used here
# before selection, allowing missing amounts (including all-NA CSV columns).
read_budget_waterfall_inputs <- function(read_diagnostic) {
  read_fields <- function(stem, fields, numeric_fields) {
    data <- read_diagnostic(stem)
    missing <- setdiff(c(fields, numeric_fields), names(data))
    if (length(missing)) {
      stop(stem, ".csv is missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
    }
    valid <- vapply(data[numeric_fields], function(x) {
      is.numeric(x) || (is.logical(x) && all(is.na(x)))
    }, logical(1))
    if (!all(valid)) {
      stop(stem, ".csv requires numeric columns: ",
        paste(names(valid)[!valid], collapse = ", "), call. = FALSE)
    }
    data
  }

  list(
    budget = read_fields("step9_budget_benchmark_scenario_ranges_r04b",
      c("scenario_scope", "country", "window", "benchmark", "forecast_period", "closest_scenario"),
      c("official_low_eur_bn", "official_high_eur_bn", "scenario_min_eur_bn", "scenario_max_eur_bn",
        "closest_scenario_eur_bn", "scenario_count", "stated_sbs_switch")),
    waterfall = read_fields("step12_cbcr_to_budget_waterfall_bridge",
      c("record_type", "scope", "window", "step"), "collector_annualised_eur_bn"),
    trend = read_fields("step12_conduit_unwinding_time_series_2017_2026",
      c("record_type", "parent", "affiliate"), c("year", "collector_eur_bn"))
  )
}

paper_budget_rows <- function(data, scope = "l3") {
  rows <- data |>
    dplyr::filter(scenario_scope == scope,
      window %in% PAPER_BUDGET_WINDOWS, benchmark %in% PAPER_BUDGET_LABELS) |>
    dplyr::arrange(match(window, PAPER_BUDGET_WINDOWS), match(country, PAPER_BUDGET_COUNTRIES))
  if (!identical(rows$country, rep(PAPER_BUDGET_COUNTRIES, times = length(PAPER_BUDGET_WINDOWS))) ||
      !identical(rows$window, rep(PAPER_BUDGET_WINDOWS, each = length(PAPER_BUDGET_COUNTRIES)))) {
    stop("Expected one selected budget benchmark per country in FY2023 and 2019–2023", call. = FALSE)
  }
  rows
}

paper_waterfall_rows <- function(data) {
  rows <- data |>
    dplyr::filter(record_type == "waterfall", scope %in% PAPER_BUDGET_COUNTRIES,
      window %in% PAPER_BUDGET_WINDOWS, step %in% names(PAPER_BRIDGE_STEPS)) |>
    dplyr::mutate(stage = factor(unname(PAPER_BRIDGE_STEPS[step]), levels = unname(PAPER_BRIDGE_STEPS)))
  if (anyDuplicated(rows[c("scope", "window", "step")])) {
    stop("Duplicate accounting waterfall rows for scope, window and step", call. = FALSE)
  }
  rows
}

paper_budget_range <- function(low, high, format_number) {
  dplyr::case_when(
    is.na(low) | is.na(high) ~ "--",
    low == high ~ trimws(format_number(low, 4)),
    TRUE ~ paste0(trimws(format_number(low, 4)), "–", trimws(format_number(high, 4)))
  )
}

write_paper_budget_tables <- function(budget, waterfall, output_dir, format_number, write_table) {
  range <- function(low, high) paper_budget_range(low, high, format_number)
  l3 <- paper_budget_rows(budget, "l3")
  core <- paper_budget_rows(budget, "core")
  stopifnot(all(l3$scenario_count == 16L), all(core$scenario_count == 32L),
    identical(l3[c("country", "window", "benchmark")], core[c("country", "window", "benchmark")]))
  budget_panel <- l3 |>
    dplyr::transmute(
      ISO = country, Window = window, `Budget basis` = forecast_period,
      Benchmark = range(official_low_eur_bn, official_high_eur_bn),
      `L3 (16)` = range(scenario_min_eur_bn, scenario_max_eur_bn),
      `Core (32)` = range(core$scenario_min_eur_bn, core$scenario_max_eur_bn)
    )
  waterfall_panel <- waterfall |>
    dplyr::arrange(match(scope, PAPER_BUDGET_COUNTRIES)) |>
    dplyr::select(ISO = scope, Window = window, stage, collector_annualised_eur_bn) |>
    tidyr::pivot_wider(names_from = stage, values_from = collector_annualised_eur_bn, names_expand = TRUE) |>
    dplyr::mutate(dplyr::across(-c(ISO, Window), ~ format_number(.x, 3)))
  stopifnot(nrow(budget_panel) > 0L, nrow(waterfall_panel) > 0L)
  write_table("tab_v2_budget_backtest_and_hanlon_waterfall", "National budget benchmarks and accounting waterfall", list(
    "A. Official benchmarks and modelled revenue ranges" = budget_panel,
    "B. Preferred SbS collector revenue after each adjustment" = waterfall_panel),
    "EUR bn per year, converted at 1.0813 USD per EUR. Panel A spans both policy regimes. L3 fixes distributional ETR measurement, and the core adds the average ETR scenarios. Slovakia is QDMTT only. Belgium is QDMTT plus IIR, with the official amount net of costs. The Dutch after-package amount is inferred from published components. The two model windows apply later rules to historical activity. Panel B holds the scenario fixed. Its cumulative 2026 safe harbour screen uses the net CbCR profit and tax envelope.",
    align = list("A. Official benchmarks and modelled revenue ranges" = "lllrrr",
      "B. Preferred SbS collector revenue after each adjustment" = "llrrrrrr"),
    output_dir = output_dir)

  matched_l3 <- paper_budget_rows(budget, "l3_policy")
  matched_core <- paper_budget_rows(budget, "core_policy")
  stopifnot(identical(matched_l3[c("country", "window", "benchmark")],
    matched_core[c("country", "window", "benchmark")]))
  policy_panel <- matched_l3 |>
    dplyr::transmute(
      ISO = country, Window = window,
      Policy = dplyr::case_when(stated_sbs_switch == 0 ~ "Universal",
        stated_sbs_switch == 1 ~ "SbS", TRUE ~ "Unknown"),
      `L3 (8)` = range(scenario_min_eur_bn, scenario_max_eur_bn),
      `Closest L3` = dplyr::coalesce(closest_scenario, "--"),
      `Core (16)` = range(matched_core$scenario_min_eur_bn, matched_core$scenario_max_eur_bn),
      `Closest core` = dplyr::coalesce(matched_core$closest_scenario, "--")
    )
  write_table("tab_v2_app_budget_policy_matched", "National budget benchmarks under matched policy regimes",
    list("Scenario ranges at the documented policy setting" = policy_panel),
    "Ranges use the benchmark amounts, channel definitions and EUR bn per year units of Table 6. Universal refers to the pre-SbS policy. A policy restriction matches the modelled SbS switch only. Closest is the scenario with the smallest distance to the benchmark interval. Ties are broken by scenario identifier. Unknown means no policy setting is assigned.",
    align = list("Scenario ranges at the documented policy setting" = "lllrlrl"),
    output_dir = output_dir)
}

make_paper_waterfall_figure <- function(backtest, waterfall, history) {
  countries <- c("NLD", "LUX", "IRL")
  years <- 2018:2023
  steps <- unname(PAPER_BRIDGE_STEPS)
  bridge_panel <- "A  Accounting bridge"
  history_panel <- "B  Historical unwind"
  budget <- backtest |>
    dplyr::filter(window == "FY2023", country %in% countries) |>
    dplyr::transmute(scope = country, benchmark = official_low_eur_bn)
  bridge <- waterfall |>
    dplyr::filter(window == "FY2023", scope %in% countries) |>
    dplyr::transmute(scope, x = as.integer(stage), revenue = collector_annualised_eur_bn, panel = bridge_panel)
  trend <- history |>
    dplyr::filter(record_type == "annual_observation", parent == "ALL", affiliate %in% countries, year %in% years) |>
    dplyr::transmute(scope = affiliate, x = match(year, years), revenue = collector_eur_bn, panel = history_panel)
  axis_labels <- c(steps, as.character(years))
  labels <- tibble::tibble(
    x = c(seq_along(steps), seq_along(years)),
    panel = rep(c(bridge_panel, history_panel), c(length(steps), length(years))),
    label = axis_labels)
  data <- dplyr::bind_rows(bridge, trend) |>
    dplyr::left_join(labels, by = c("x", "panel"), relationship = "many-to-one") |>
    dplyr::mutate(axis = factor(label, levels = axis_labels),
      scope = factor(scope, levels = countries))
  budgets <- data |> dplyr::distinct(scope, panel) |>
    dplyr::left_join(budget, by = "scope", relationship = "many-to-one") |>
    dplyr::mutate(scope = factor(scope, levels = countries))
  ggplot2::ggplot(data, ggplot2::aes(axis, revenue, group = 1)) +
    ggplot2::geom_hline(data = budgets, ggplot2::aes(yintercept = benchmark, linetype = "Budget benchmark"),
      colour = "#A54633", linewidth = .55) +
    ggplot2::geom_line(colour = "#174C70", linewidth = .7) +
    ggplot2::geom_point(colour = "#174C70", size = 1.8) +
    ggplot2::facet_grid(scope ~ panel, scales = "free", space = "free_x") +
    ggplot2::scale_linetype_manual(values = c("Budget benchmark" = "dashed"), name = NULL) +
    ggplot2::expand_limits(y = 0) +
    ggplot2::labs(x = NULL, y = "Collector revenue (EUR bn)") +
    ggplot2::theme_minimal(base_size = 10, base_family = "serif") +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(), panel.grid.major.x = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_text(angle = 36, hjust = 1), strip.text = ggplot2::element_text(face = "bold"),
      legend.position = "top", plot.margin = ggplot2::margin(10, 16, 12, 10))
}
