# Read-only R13a characterisation. Source amounts and receipts are in USD,
# except for the existing sparse and accounting interfaces, which use USD bn.
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."),
  "code", "07a_uncertainty.R"), local = TRUE)
source(file.path(GMT_PROJECT_ROOT, "code", "09_econometric_and_reallocation_extensions.R"), local = TRUE)
source(file.path(GMT_PROJECT_ROOT, "code", "11_policy_game_and_variance_extensions.R"), local = TRUE)

# Audit validation is stricter than some of the existing production wrappers.
assert_balanced_binary_design <- function(data, factors, unit_keys = character(), outcome = NULL) {
  if (any(vapply(data[factors], function(x) !is.numeric(x) || anyNA(x) ||
      any(!x %in% c(0, 1)), logical(1)))) {
    stop("Binary factors require numeric 0/1 values", call. = FALSE)
  }
  id <- do.call(paste0, c(list("x"), as.list(data[factors])))
  if (anyNA(data$scenario_id) || any(data$scenario_id != id)) {
    stop("Scenario identifiers must match the declared factor order", call. = FALSE)
  }
  assert_unique_keys(data, c(unit_keys, "scenario_id"), "factorial audit")
  counts <- if (length(unit_keys)) count(data, across(all_of(unit_keys)))$n else nrow(data)
  if (!nrow(data) || any(counts != 2^length(factors))) {
    stop("Incomplete binary design", call. = FALSE)
  }
  if (!is.null(outcome) && any(!is.finite(data[[outcome]]))) {
    stop("Non-finite outcomes require an explicit support rule", call. = FALSE)
  }
  invisible(data)
}

# Independent reference, with a row for every nonempty factor subset.
# y has scenarios on rows and separate observation units on columns.
audit_orthogonal_effects <- function(design, y, factors) {
  assert_balanced_binary_design(design, factors)
  stopifnot(is.matrix(y), nrow(y) == nrow(design), all(is.finite(y)))
  n <- nrow(design)
  subsets <- unlist(lapply(seq_along(factors), function(k)
    combn(factors, k, simplify = FALSE)), recursive = FALSE)
  coefficients <- vapply(subsets, function(included) {
    sign <- (-1)^(length(included) - rowSums(design[included]))
    colMeans(y * sign)
  }, numeric(ncol(y)))
  coefficients <- matrix(coefficients, nrow = ncol(y))
  variance <- colSums(coefficients^2)
  total <- sum(sweep(y, 2, colMeans(y))^2) / n
  stopifnot(abs(sum(variance) - total) <= 1e-12 * max(1, total))
  eta <- if (total > 0) variance / total else rep(NA_real_, length(variance))
  list(terms = tibble(effect = vapply(subsets, paste, character(1), collapse = ":"),
    variance = variance, total_variance = total, eta_squared = eta),
    shapley = set_names(vapply(factors, function(factor) {
      terms <- vapply(subsets, function(s) factor %in% s, logical(1))
      sum(eta[terms] / lengths(subsets)[terms])
    }, numeric(1)), factors))
}

audit_compare <- function(left, right, keys, columns, label, tolerance) {
  assert_unique_keys(left, keys, paste(label, "original keys"))
  assert_unique_keys(right, keys, paste(label, "comparison keys"))
  order_by <- function(x) arrange(x, across(all_of(keys)))
  left <- order_by(left)
  right <- order_by(right)
  if (!isTRUE(all.equal(as.data.frame(left[keys]), as.data.frame(right[keys]), tolerance = 0))) {
    stop(label, " has different keys", call. = FALSE)
  }
  bind_rows(lapply(columns, function(column) {
    a <- unname(left[[column]])
    b <- unname(right[[column]])
    if (!identical(is.na(a), is.na(b))) stop(label, " has different missingness in ", column)
    gap <- max(c(0, abs(a - b)), na.rm = TRUE)
    if (gap > tolerance) stop(label, " gap in ", column, ": ", format(gap), call. = FALSE)
    tibble(comparison = label, amount = column, rows = length(a), missing_rows = sum(is.na(a)),
      exact_vector = identical(a, b), max_abs_gap = gap, tolerance)
  }))
}

audit_revenue_matrix <- function(data) {
  wide <- data |>
    select(country, year, scenario_id, revenue) |>
    tidyr::pivot_wider(names_from = scenario_id, values_from = revenue) |>
    arrange(country, year)
  as.matrix(wide[sort(unique(data$scenario_id))])
}

audit_aggregation <- function(design, revenue, global_totals) {
  paths <- list(
    pooled_country_year = t(audit_revenue_matrix(revenue)),
    pooled_country_cumulative = t(audit_revenue_matrix(
      summarise(revenue, revenue = sum(revenue), .by = c(country, scenario_id)) |> mutate(year = 0L))),
    eu27_annual = t(audit_revenue_matrix(
      summarise(revenue, revenue = sum(revenue), .by = c(year, scenario_id)) |> mutate(country = "EU27"))),
    eu27_cumulative = matrix(colSums(audit_revenue_matrix(revenue)), ncol = 1),
    global_annual = t(audit_revenue_matrix(mutate(global_totals, country = "Global"))),
    global_cumulative = matrix(colSums(audit_revenue_matrix(mutate(global_totals, country = "Global"))), ncol = 1)
  )
  imap_dfr(paths, function(y, basis) {
    effects <- audit_orthogonal_effects(design, y / 1e9, FACTOR_COLS)
    effects$terms |>
      filter(effect %in% FACTOR_COLS) |>
      mutate(basis, observation_units = ncol(y), shapley = effects$shapley[effect], .before = 1)
  })
}

audit_source_projection <- function(input, measurement) {
  # Observe the existing sparse source evaluator before legal collection by
  # substituting an identity projection in a local copy. Exposure stays intact.
  keys <- c("parent", "affiliate", "year")
  input$collector_year <- select(input$cells, all_of(keys))
  input$routes <- lapply(input$routes, function(route) {
    route$operator <- Matrix::Diagonal(nrow(input$cells))
    route
  })
  result <- step15_evaluate(input, measurement)$revenue
  bind_cols(input$collector_year, as_tibble(result * 1e9)) |>
    tidyr::pivot_longer(starts_with("x"), names_to = "scenario_id", values_to = "topup_after_behaviour")
}

audit_fiscal_designs <- function(panel, revenue, host, weights, read_diag, read_data) {
  combine <- function(rule, matrix = NULL) {
    fiscal <- build_total_fiscal_country_year(panel, revenue, host, weights, matrix)
    ledger <- summarise_total_fiscal_ledger(fiscal$country_year, fiscal$reallocation)
    foil <- if (rule == "A") "" else "_rule_b"
    anova <- decompose_total_fiscal_revenue(fiscal$country_year)
    archived <- read_diag(paste0("step6_anova_total_fiscal_revenue", foil))
    compare <- audit_compare(anova, archived, c("outcome", "start_year", "effect"),
      c("eta_squared", "shapley_eta_squared", "interaction_eta_squared"),
      paste("Stage 09", rule, "fiscal contrasts"), 1e-12)
    preferred <- ledger |>
      filter(country == "EU27", scenario_id == "x10011", start_year == 2017, end_year == 2023) |>
      select(direct_topup, ordinary_cit_gross_destination_revenue, ordinary_cit_source_loss,
        ordinary_cit_net_by_incidence, direct_topup_lost_total,
        total_fiscal_revenue_net_by_incidence, total_fiscal_gain_vs_mechanical_net_by_incidence) |>
      mutate(rule, .before = 1)
    assert_balanced_binary_design(fiscal$country_year, FACTOR_COLS, c("country", "year"))
    list(compare = compare, preferred = preferred)
  }
  a <- combine("A")
  b <- combine("B", read_data("stage3_reallocation_matrix"))
  list(compare = bind_rows(a$compare, b$compare), preferred = bind_rows(a$preferred, b$preferred))
}

audit_ladder_designs <- function(panel, weights, host, cells, input, read_data, read_diag) {
  ladder <- ladder_build_measurements(cells, host,
    read_data("base_panel_t4_bilateral_bracket_shares"), rank_consistent = TRUE)
  measurements <- ladder$measurements
  levels <- c(LADDER_LEVELS, LADDER_BSPI)
  stage2 <- read_data("stage2_bilateral_panel") |>
    select(all_of(LADDER_KEYS), rate_scenario, affiliate_is_eu27, analysis_profit_positive,
      stage2_phi, stage2_topup_tax_average, stage2_topup_tax_distributional)
  sectors <- read_data("stage2_sectoral_panel")
  support <- summarise(measurements, rows = n(), measured = sum(measured),
    missing_share = sum(is.na(share)), missing_gap = sum(is.na(gap)),
    zero_low_profit = sum(low_profit == 0), .by = c(level, year, source_tier))
  comparisons <- list()
  allocations <- set_names(lapply(seq_along(levels), function(i) {
    measurement <- filter(measurements, level == levels[i])
    post <- ladder_apply_sbie(measurement, stage2)
    chosen <- switch(as.character(i),
      "1" = filter(panel, x1_etr == 0), "3" = filter(panel, x1_etr == 1),
      ladder_rebuild_scenarios(measurement, post, panel, host, sectors, input$beta))
    if (i %in% c(4L, 5L)) {
      measure <- step15_measure(input)
      aligned <- left_join(select(input$cells, all_of(LADDER_KEYS)), measurement,
        by = LADDER_KEYS, relationship = "one-to-one")
      measure$distributional <- list(share = coalesce_zero(aligned$share),
        gap = coalesce_zero(aligned$gap), bilateral = TRUE)
      sparse <- audit_source_projection(input, measure) |>
        filter(substr(scenario_id, 2, 2) == "1")
      comparisons[[levels[i]]] <<- audit_compare(chosen, sparse,
        c("scenario_id", LADDER_KEYS), "topup_after_behaviour",
        paste("Stage 08 vs 11", levels[i]), 1e-3)
    }
    ladder_allocate(chosen, weights)
  }), levels)
  revenues <- imap_dfr(allocations, ~ mutate(.x$revenue, level = .y))
  for (level in levels) {
    stopifnot(all(count(filter(revenues, .data$level == .env$level), country, year)$n == 16L))
  }
  designs <- list(L1_vs_L3 = c(1, 3), L1_vs_L4_anchored = c(1, 4), L1_vs_L4_strict = c(1, 5),
    L2_vs_L4_anchored = c(2, 4), four_levels_anchored = c(1, 2, 4, 3),
    four_levels_strict = c(1, 2, 5, 3))
  contrasts <- imap_dfr(designs, function(indices, name) {
    validation <- map_dfr(indices[-1], ~ ladder_binary_stage46(allocations[[indices[1]]], allocations[[.x]])) |>
      summarise(across(everything(), max))
    ladder_anova(revenues, levels[indices], name, validation)
  })
  checks <- audit_compare(contrasts, read_diag("step9_ladder_anova_decomposition"),
    c("design", "window", "effect", "record_type"), c("main_eta_squared", "shapley_eta_squared",
      "min_eu27_revenue_usd_bn", "max_eu27_revenue_usd_bn"), "Stage 08 ladder", 1e-9)
  totals <- summarise(revenues, revenue = sum(revenue), .by = c(level, scenario_id)) |>
    summarise(scenarios = n(), min_usd = min(revenue), max_usd = max(revenue), .by = level)
  list(compare = bind_rows(checks, bind_rows(comparisons)), support = support,
    totals = totals, contrasts = contrasts)
}

audit_one_factorial_reference <- function(root, specification, full_diagnostics) {
  # The numbered code resolves its frozen readers in this call environment.
  withr::local_envvar(c(GMT_OUTPUT_ROOT = root, GMT_FACTOR2_SPECIFICATION = specification))
  source(file.path(GMT_PROJECT_ROOT, "code", "09_econometric_and_reallocation_extensions.R"), local = TRUE)
  source(file.path(GMT_PROJECT_ROOT, "code", "11_policy_game_and_variance_extensions.R"), local = TRUE)
  source(file.path(GMT_PROJECT_ROOT, "code", "07a_uncertainty.R"), local = TRUE)
  read_data <- function(name) readRDS(file.path(PROCESSED_DIR, paste0(name, ".rds")))
  read_diag <- function(name) readr::read_csv(file.path(DIAGNOSTICS_DIR,
    paste0(tools::file_path_sans_ext(name), ".csv")), show_col_types = FALSE)

  configured <- c(table_iv_specification(), statutory_rate_specification(), utpr_specification(),
    behavioural_specification(), factor2_specification())
  frozen <- c(read_diag(T4_SPECIFICATION_FILE)$specification,
    read_diag(STATUTORY_RATE_SPECIFICATION_FILE)$specification,
    read_data("stage4_5_utpr_policy")$specification,
    read_diag(BEHAVIOURAL_SPECIFICATION_FILE)$specification,
    if (full_diagnostics) read_diag(FACTOR2_SPECIFICATION_FILE)$specification else "LEGACY_HYBRID_SBIE_SBTI")
  stopifnot(identical(configured, frozen), identical(frozen,
    c("OBSERVED_TWO_SIDED", "STANDARD_ROLE_SPECIFIC", "VERIFIED_PARENT_ONLY",
      "NO_NOTCH_STANDARD_RESPONSE", specification)))
  configuration <- tibble(setting = c("table_iv", "statutory_rate", "utpr", "behaviour", "factor2"),
    value = configured)
  panel <- read_data("stage3_factorial_pair_year")
  source_keys <- c("scenario_id", "parent", "affiliate", "year")
  receipt_keys <- c("scenario_id", "country", "year")
  assert_balanced_binary_design(panel, FACTOR_COLS, source_keys[-1], "topup_after_behaviour")
  design <- arrange(distinct(panel, across(all_of(SCENARIO_VARS))), scenario_id)
  sparse_design <- step15_design()
  stopifnot(identical(design[names(sparse_design)], sparse_design),
    identical(design$factor2_substance,
      if_else(design$x2_substance == 1, factor2_sectoral_label(), "aggregate_sbie")))
  design <- mutate(design, specification, .before = 1)
  weights <- read_stage4_utpr_weights()
  source_panel <- build_source_panel(panel)
  source_amounts <- c("topup_after_behaviour", "stage4_qdmtt_liability", "stage4_iir_liability",
    "stage4_utpr_pool", "stage4_sbs_extinguished_liability")
  checks <- list(audit_compare(source_panel, read_data("stage4_5_allocation_source_panel"),
    source_keys, source_amounts, "Stage 06 source classification", 0))
  # Check the recorded Stage 05 selected amount and exposure multiplier on the
  # same rows. The sectoral multiplier scales top-up, not relocated profit.
  predicted <- panel |>
    transmute(across(all_of(source_keys)),
      topup_after_stage2 = pmax(if_else(x1_etr == 0, stage2_topup_tax_average,
        stage2_topup_tax_distributional) * sectoral_scale_selected, 0),
      topup_after_behaviour = pmax(topup_after_stage2 * behavioural_liability_filter, 0))
  checks[[length(checks) + 1L]] <- audit_compare(panel, predicted, source_keys,
    c("topup_after_stage2", "topup_after_behaviour"), "Stage 05 recorded amount identity", 0)
  allocation <- allocate_stage4_revenue(source_panel, weights)
  conservation <- build_conservation_diagnostics(source_panel,
    allocation$revenue_by_channel_global, allocation$unsupported_utpr)
  revenue <- allocation$revenue_country_year_eu27
  global <- allocation$revenue_by_channel_global
  assert_balanced_binary_design(revenue, FACTOR_COLS, c("country", "year"), "revenue")
  proxy <- read_data("stage3_revenue_country_year")
  assert_balanced_binary_design(proxy, FACTOR_COLS, c("country", "year"), "revenue")
  validation <- validate_revenue_inputs(revenue, allocation$revenue_by_channel_eu27, conservation)
  checks[[length(checks) + 1L]] <- audit_compare(revenue, read_data("stage4_5_revenue_country_year"),
    receipt_keys, "revenue", "Stage 06 EU collector receipts", 0)
  checks[[length(checks) + 1L]] <- audit_compare(global,
    read_data("stage4_5_revenue_by_channel_global"),
    c(receipt_keys, "channel", "allocation_weight_source"), "revenue", "Stage 06 global channels", 0)

  stage05 <- compute_stage3_factorial_anova(proxy)$pooled
  stage07 <- compute_factorial_anova(revenue)$pooled
  checks[[length(checks) + 1L]] <- bind_rows(
    audit_compare(stage05, read_data("stage3_anova_pooled"), "effect", "eta_squared", "Stage 05 proxy contrasts", 0),
    audit_compare(stage07, read_data("stage4_6_anova_pooled"), "effect", "eta_squared", "Stage 07 collector contrasts", 0),
    audit_compare(compute_stage3_factorial_anova(revenue)$pooled, stage07, "effect", c("ss", "eta_squared"),
      "Stage 05 and 07 contrasts on identical collector support", 1e-12))
  annual_global <- summarise(global, revenue = sum(revenue), .by = c(scenario_id, year))
  sums <- function(data) summarise(data, revenue = sum(revenue), .by = scenario_id)
  totals <- bind_rows(EU27 = sums(revenue), Global = sums(global), EU27_source_proxy = sums(proxy), .id = "scope")
  aggregation <- audit_aggregation(sparse_design, revenue, annual_global)
  shapley <- build_shapley_factor_attribution(stage07)
  stopifnot(max(abs(shapley$shapley_eta_squared -
    filter(aggregation, basis == "pooled_country_year")$shapley[match(shapley$effect, FACTOR_COLS)])) < 1e-12)

  pref <- build_preferred_source_panel(PROCESSED_DIR)
  profit_point <- compute_preferred_revenue_from_profit(pref, pref$analysis_profit_base, "point")
  detailed_preferred <- global |>
    filter(scenario_id %in% c("x10001", "x10011")) |>
    summarise(eu27_final_revenue = sum(revenue[country_is_eu27]),
      global_allocated_revenue = sum(revenue), .by = factor4_sbs)
  profit_check <- audit_compare(profit_point, detailed_preferred, "factor4_sbs",
    c("eu27_final_revenue", "global_allocated_revenue"),
    "Stage 07a preferred collapsed profit-only projection vs detailed point", .01)
  checks[[length(checks) + 1L]] <- profit_check

  input <- step15_inputs()
  measurement <- step15_measure(input)
  sparse <- step15_evaluate(input, measurement, check = TRUE)
  point_gap <- step15_check_production(input, sparse$revenue)
  checks[[length(checks) + 1L]] <- audit_compare(panel, audit_source_projection(input, measurement),
    source_keys, "topup_after_behaviour", "Stage 05 vs 11 source amount before collection", 1e-3)
  accounting <- step15_factorial(input, measurement, sparse$revenue)
  archive_accounting <- read_diag("step15_globe_accounting_factorial_anova")
  # Each record family has a different key, so use a common explicit term key.
  accounting_key <- function(x) mutate(x, term = coalesce(effect, scenario_id))
  checks[[length(checks) + 1L]] <- audit_compare(accounting_key(accounting), accounting_key(archive_accounting),
    c("scope", "window", "estimand", "record", "distributional_level", "design", "term"),
    c("factorial_variance_usd_bn_sq", "main_eta_squared", "shapley_eta_squared",
      "interaction_term_eta_squared", "cumulative_revenue_usd_bn"),
    "Stage 11 accounting supports and amounts", 1e-9)

  split_factors <- c("x1_etr", "x2a_sectoral", "x2b_sbti", FACTOR_COLS[3:5])
  split <- build_split_substance_variant(panel, if (full_diagnostics) NULL else build_split_substance_scales())
  assert_balanced_binary_design(split, split_factors, source_keys[-1], "topup_after_behaviour")
  split_design <- distinct(split, scenario_id, across(all_of(split_factors)))
  split_revenue <- allocate_stress_variant(split, weights)
  split_summary <- summarise_stress_variant(split_revenue$revenue, split_design, split_factors,
    "D_split_substance", split_revenue$gap)
  checks[[length(checks) + 1L]] <- audit_compare(split_summary,
    filter(read_diag("step7_decomposition_architecture_stress_test"), variant == "D_split_substance"),
    c("start_year", "effect"), c("main_eta_squared", "shapley_eta_squared"), "Stage 09 split substance", 1e-12)
  paired <- split_revenue$revenue |>
    mutate(core = paste0(substr(scenario_id, 1, 3), substr(scenario_id, 5, 7)),
      overlay = substr(scenario_id, 4, 4)) |>
    summarise(rows = n(), range_usd = diff(range(revenue)), .by = c(core, country, year))
  stopifnot(all(paired$rows == 2L))
  if (full_diagnostics) stopifnot(all(paired$range_usd == 0))
  split_pairing <- summarise(paired, compared_keys = n(),
    equal_keys = sum(range_usd == 0), max_overlay_difference_usd = max(range_usd))
  rm(split)
  result <- list(configuration = configuration, scenarios = design, totals = totals, aggregation = aggregation,
    comparisons = bind_rows(checks), validation = validation,
    sparse = tibble(point_gap_usd = point_gap, max_conservation_gap_usd = sparse$max_global_conservation_gap,
      max_unsupported_utpr_usd = sparse$max_unsupported_utpr_usd),
    routing = conservation,
    accounting = filter(accounting, record == "main_effect", scope == "EU27"),
    split = split_summary, split_pairing = split_pairing)
  monte_carlo <- read_diag("step15_law_of_total_variance_decomposition")
  total_variance <- filter(monte_carlo, record == "total_variance")
  stopifnot(all(total_variance$n_joint_draws == 500), all(total_variance$n_scenarios == 32),
    max(abs(with(total_variance, total_variance_usd_bn_sq -
      scenario_variance_usd_bn_sq - parameter_variance_usd_bn_sq))) < 1e-9)
  result$joint_variance <- monte_carlo |>
    filter(scope == "EU27", record %in% c("total_variance", "parameter_shapley")) |>
    select(window, n_joint_draws, n_scenarios, record, total_variance_usd_bn_sq,
      scenario_variance_share, parameter_variance_share, point_scenario_spread_usd_bn,
      preferred_p05_usd_bn, preferred_p95_usd_bn, preferred_width90_usd_bn, proposal_ratio,
      component, component_share_of_parameter_variance)
  result$source_support <- panel |>
    summarise(rows = n(), missing_profit_base = sum(is.na(analysis_profit_base)),
      zero_positive_profit = sum(analysis_profit_positive == 0), missing_low_etr = sum(is.na(static_tau_low)),
      positive_liability = sum(topup_after_behaviour > 0), .by = scenario_id)
  if (full_diagnostics) {
    ladder <- audit_ladder_designs(panel, weights, input$host, input$cells, input, read_data, read_diag)
    fiscal <- audit_fiscal_designs(read_step6_factorial_input(), revenue, input$host,
      weights, read_diag, read_data)
    result$comparisons <- bind_rows(result$comparisons, ladder$compare, fiscal$compare)
    result <- c(result, list(ladder_support = ladder$support, ladder_totals = ladder$totals,
      ladder_contrasts = ladder$contrasts, fiscal = fiscal$preferred))
  }
  result
}

run_factorial_contract_audit <- function(input_root, historical_root, output_dir) {
  input_root <- normalizePath(input_root, mustWork = TRUE)
  historical_root <- normalizePath(historical_root, mustWork = TRUE)
  output <- file.path(normalizePath(dirname(output_dir), mustWork = TRUE), basename(output_dir))
  protected <- unlist(lapply(unique(c(input_root, historical_root, GMT_PROJECT_ROOT)),
    file.path, c("data", "writing", ".git")))
  if (file.exists(output) || basename(output) %in% c(".", "..") ||
      any(startsWith(output, paste0(protected, "/")))) {
    stop("Use a fresh diagnostic directory outside scientific and publication inputs", call. = FALSE)
  }
  leading <- audit_one_factorial_reference(input_root, "SECTORAL_SBIE_ONLY", TRUE)
  historical <- audit_one_factorial_reference(historical_root, "LEGACY_HYBRID_SBIE_SBTI", FALSE)
  stopifnot(dir.create(output))
  for (name in names(leading)) {
    result <- leading[[name]]
    if (name %in% names(historical))
      result <- bind_rows(R11c = result, R10b = historical[[name]], .id = "reference")
    readr::write_csv(result, file.path(output, paste0(name, ".csv")))
  }
  invisible(output)
}

if (is_direct_script_run("code/diagnostics/factorial_contract_audit.R")) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 3L) stop("Supply the leading root, historical root and fresh output directory")
  run_factorial_contract_audit(args[1], args[2], args[3])
}
