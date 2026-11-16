# Compare verified-collector replays at the original source and collector keys.
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "diagnostics",
  "behavioural_notch.R"), local = TRUE)

read_behavioural_source_ledger <- function(processed) {
  keys <- NOTCH_KEYS
  unsupported <- readRDS(file.path(processed, "stage4_5_utpr_unsupported_sources.rds")) |>
    select(all_of(keys), unsupported_usd = unsupported_utpr)
  ledger <- readRDS(file.path(processed, "stage4_5_allocation_source_panel.rds")) |>
    transmute(across(all_of(keys)), across(all_of(FACTOR_COLS)),
      qdmtt_flag, parent_iir_utpr_flag, sbs_exempt, static_tau_low, behavioural_regime,
      post_substance_usd = topup_after_stage2,
      notch_relief_usd = if_else(behavioural_regime == "sesh_bunching_topup_zero", topup_after_stage2, 0),
      response_relief_usd = topup_after_stage2 - notch_relief_usd - topup_after_behaviour,
      source_usd = topup_after_behaviour, qdmtt_usd = stage4_qdmtt_liability,
      iir_usd = stage4_iir_liability, utpr_pool_usd = stage4_utpr_pool,
      sbs_extinguished_usd = stage4_sbs_extinguished_liability, relocated_profit_usd = reallocated_profit,
      source_cit_lost_usd = reallocated_profit * coalesce_zero(clamp_interval(static_tau_low, 0, GMT_RATE))) |>
    left_join(unsupported, by = keys, relationship = "one-to-one") |>
    mutate(unsupported_usd = coalesce_zero(unsupported_usd),
      assigned_utpr_usd = utpr_pool_usd - unsupported_usd,
      assigned_usd = qdmtt_usd + iir_usd + assigned_utpr_usd)
  assert_unique_keys(ledger, keys, "Behavioural source ledger")
  stopifnot(max(abs(ledger$post_substance_usd - ledger$notch_relief_usd -
    ledger$response_relief_usd - ledger$source_usd)) < 1e-3,
    max(abs(ledger$source_usd - ledger$assigned_usd - ledger$sbs_extinguished_usd -
      ledger$unsupported_usd)) < 1e-3, all(ledger$assigned_utpr_usd >= 0),
    all(ledger$utpr_pool_usd[ledger$qdmtt_flag] == 0))
  ledger
}

read_behavioural_collector_ledger <- function(processed) {
  readRDS(file.path(processed, "stage4_5_revenue_by_channel_global.rds")) |>
    group_by(scenario_id, country, year, channel) |>
    summarise(assigned_usd = sum(revenue), .groups = "drop")
}

behavioural_point_acceptance <- function(processed, expected_dir) {
  active <- "NO_NOTCH_STANDARD_RESPONSE"
  expected <- function(name) {
    read_csv(file.path(expected_dir, paste0(name, ".csv")), show_col_types = FALSE) |>
      filter(specification == active)
  }
  ledger <- read_behavioural_source_ledger(processed)
  design <- distinct(ledger, scenario_id, across(all_of(FACTOR_COLS)))
  stopifnot(nrow(design) == 32L, !anyDuplicated(design$scenario_id),
    sum(design$x1_etr == 0L) == 16L, sum(design$x1_etr == 1L) == 16L,
    !any(ledger$behavioural_regime == "sesh_bunching_topup_zero"))
  source <- notch_windows(ledger) |>
    summarise(across(ends_with("_usd"), sum), .by = c(window, scenario_id))
  geography <- read_behavioural_collector_ledger(processed) |>
    filter(country %in% EU27_ISO3)
  ranges <- notch_windows(geography) |>
    summarise(assigned_usd = sum(assigned_usd), .by = c(window, scenario_id)) |>
    summarise(scenarios = n(), minimum_usd = min(assigned_usd), maximum_usd = max(assigned_usd),
      minimum_scenario = scenario_id[which.min(assigned_usd)], maximum_scenario = scenario_id[which.max(assigned_usd)],
      .by = window)
  projection <- notch_windows(geography) |>
    summarise(assigned_usd = sum(assigned_usd), .by = c(window, scenario_id, channel))
  archive_source <- filter(expected("source"), affiliate == "Global")
  source_metrics <- intersect(names(archive_source), grep("_usd$", names(source), value = TRUE))
  source_gap <- notch_keyed_gap(source, archive_source, c("window", "scenario_id"), source_metrics)
  collector_gap <- notch_keyed_gap(projection, filter(expected("channels"), country == "EU27"),
    c("window", "scenario_id", "channel"), "assigned_usd")
  range_gap <- notch_keyed_gap(ranges, expected("core_ranges"),
    c("window", "scenarios", "minimum_scenario", "maximum_scenario"), c("minimum_usd", "maximum_usd"))
  tibble(check = c("global_source", "EU27_channel", "32_scenario_endpoints"),
    max_absolute_gap_usd = c(source_gap, collector_gap, range_gap))
}

compare_behavioural_replays <- function(revised, historical, output) {
  stopifnot(dir.exists(output), length(list.files(output, all.files = TRUE, no.. = TRUE)) == 0L)
  keys <- NOTCH_KEYS
  before <- read_behavioural_source_ledger(historical)
  after <- read_behavioural_source_ledger(revised)
  fixed <- c(keys, FACTOR_COLS, "qdmtt_flag", "parent_iir_utpr_flag", "sbs_exempt",
    "static_tau_low", "post_substance_usd")
  stopifnot(identical(before[fixed], after[fixed]),
    !any(after$behavioural_regime == "sesh_bunching_topup_zero"))
  monetary <- grep("_usd$", names(after), value = TRUE)
  before <- select(before, all_of(c(fixed, monetary, "behavioural_regime")))
  after <- select(after, all_of(c(keys, setdiff(monetary, fixed), "behavioural_regime")))
  ledger <- inner_join(before, after, by = keys, relationship = "one-to-one", suffix = c("_r05b", "_r06b"))
  stopifnot(nrow(ledger) == nrow(before), nrow(ledger) == nrow(after))
  for (field in setdiff(monetary, fixed)) {
    ledger[[paste0("delta_", field)]] <- ledger[[paste0(field, "_r06b")]] - ledger[[paste0(field, "_r05b")]]
  }
  delta <- grep("^delta_", names(ledger), value = TRUE)
  stopifnot(all(as.matrix(ledger[ledger$x5_behaviour == 0L, delta]) == 0),
    max(abs(with(ledger, delta_source_usd - delta_assigned_usd -
      delta_sbs_extinguished_usd - delta_unsupported_usd))) < 1e-3)
  # The full keyed ledger includes every source, even for mechanical and zero
  # liability scenarios. Retain the common fields once across the two vintages.
  saveRDS(ledger, file.path(output, "source_ledger.rds"))
  fiscal <- notch_windows(ledger) |>
    summarise(across(ends_with("_usd") | ends_with("_r05b") & where(is.numeric) |
      ends_with("_r06b") & where(is.numeric), sum), .by = c(window, scenario_id))
  write_csv(fiscal, file.path(output, "source_totals.csv"))

  channels <- full_join(read_behavioural_collector_ledger(historical),
    read_behavioural_collector_ledger(revised), by = c("scenario_id", "country", "year", "channel"),
    relationship = "one-to-one", suffix = c("_r05b", "_r06b")) |>
    mutate(across(starts_with("assigned_usd_"), coalesce_zero),
      delta_assigned_usd = assigned_usd_r06b - assigned_usd_r05b)
  totals <- channels |> summarise(delta_assigned = sum(delta_assigned_usd), .by = c(scenario_id, year))
  source <- ledger |> summarise(delta_assigned_usd = sum(delta_assigned_usd), .by = c(scenario_id, year))
  gap <- notch_keyed_gap(totals, rename(source, delta_assigned = delta_assigned_usd),
    c("scenario_id", "year"), "delta_assigned")
  collectors <- bind_rows(channels, mutate(channels, country = "Global"),
    mutate(filter(channels, country %in% EU27_ISO3), country = "EU27"),
    mutate(filter(channels, !country %in% EU27_ISO3), country = "Non-EU27")) |>
    notch_windows() |>
    summarise(across(ends_with("_usd") | starts_with("assigned_usd"), sum),
      .by = c(window, scenario_id, country, channel))
  write_csv(collectors, file.path(output, "collector_totals.csv"))
  write_behavioural_downstream_comparison(revised, historical, output)
  write_behavioural_artifact_inventory(revised, historical, output)
  message("Source to collector delta, maximum absolute scenario-year gap USD ", gap)
  invisible(list(fiscal = fiscal, collectors = collectors, gap = gap))
}

write_behavioural_downstream_comparison <- function(revised, historical, output) {
  read <- function(root, name) read_csv(file.path(root, "diagnostics", paste0(name, ".csv")),
    show_col_types = FALSE)
  paired <- function(name, keys, fields) {
    columns <- c(keys, fields)
    before <- select(read(historical, name), all_of(columns))
    after <- select(read(revised, name), all_of(columns))
    assert_unique_keys(before, keys, name)
    assert_unique_keys(after, keys, name)
    stopifnot(nrow(anti_join(before, after, by = keys)) == 0,
      nrow(anti_join(after, before, by = keys)) == 0)
    inner_join(before, after, by = keys, suffix = c("_r05b", "_r06b"), relationship = "one-to-one")
  }
  forecasts <- "step9_budget_benchmark_scenario_ranges_r04b"
  budget_keys <- c("window", "scenario_scope", "country", "benchmark")
  budget_inputs <- c(budget_keys, "model_scope", "comparison_scope", "forecast_period", "revenue_scope",
    "official_low_eur_bn", "official_high_eur_bn", "stated_sbs_switch", "source_url")
  stopifnot(identical(select(read(historical, forecasts), all_of(budget_inputs)),
    select(read(revised, forecasts), all_of(budget_inputs))))
  write_csv(paired(forecasts, budget_inputs, c("scenario_count", "scenario_min_eur_bn", "scenario_max_eur_bn",
    "closest_scenario", "closest_gap_eur_bn", "closest_tie_count", "preferred_universal_eur_bn",
    "preferred_sbs_eur_bn", "official_interval_overlaps_model_range")), file.path(output, "budget.csv"))

  game <- paired("step13_unilateral_qdmtt_deviation_matrix",
    c("country", "level", "deviation", "regime", "window"),
    c("adoption_qdmtt", "domestic_iir_recapture", "domestic_utpr_recapture", "foreign_iir_soakup",
      "foreign_utpr_soakup", "mne_topup_saved", "sbs_extinguished_post_repeal", "global_assigned_decline",
      "retained_profit", "retained_source_cit", "delta_total_domestic_tax", "tax_cut_efficiency",
      "critical_welfare_weight", "fiscal_gain_at_zero_weight", "fiscal_tie_at_zero_weight", "host_unsupported_utpr"))
  stopifnot(nrow(game) == 432)
  write_csv(game, file.path(output, "game.csv"))

  preferred <- function(root) {
    p <- readRDS(file.path(root, "stage3_factorial_pair_year.rds")) |> filter(scenario_id %in% NASH_IDS)
    stage1 <- readRDS(file.path(root, "stage1_bilateral_panel.rds"))
    host <- readRDS(file.path(root, "stage1_affiliate_year.rds"))
    cit <- notch_cit(p, stage1, host)
    frozen <- read(root, "step7_reallocation_destination_rules_comparison") |>
      filter(rule == "B") |>
      transmute(window, scenario_id, country, gross_cit_usd = gross_cit, source_cit_lost_usd = source_cit_lost)
    notch_keyed_gap(filter(cit, country %in% c(EU27_ISO3, "EU27")), frozen,
      c("window", "scenario_id", "country"), c("gross_cit_usd", "source_cit_lost_usd"))
    outside <- filter(cit, country != "Global", country != "EU27", !country %in% EU27_ISO3) |>
      summarise(across(where(is.numeric), sum), .by = c(window, scenario_id)) |>
      mutate(country = "Non-EU27")
    bind_rows(cit, outside)
  }
  cit <- full_join(preferred(historical), preferred(revised), by = c("window", "scenario_id", "country"),
    relationship = "one-to-one", suffix = c("_r05b", "_r06b")) |>
    mutate(across(matches("_(r05b|r06b)$"), coalesce_zero))
  write_csv(cit, file.path(output, "rule_b_cit.csv"))

  draws <- paired("step9_stage1_measurement_error_scenario_draws", c("draw_id", "scenario_id"),
    "eu_revenue")
  draw_design <- count(draws, draw_id)
  stopifnot(setequal(draw_design$draw_id, seq_len(MEASUREMENT_ERROR_DRAWS)), all(draw_design$n == 32),
    identical(draws$eu_revenue_r05b[endsWith(draws$scenario_id, "0")],
      draws$eu_revenue_r06b[endsWith(draws$scenario_id, "0")]))
  changes <- draws |>
    mutate(delta_usd = eu_revenue_r06b - eu_revenue_r05b) |>
    summarise(draws = n(), min_delta_usd = min(delta_usd), mean_delta_usd = mean(delta_usd),
      median_delta_usd = median(delta_usd), p95_delta_usd = quantile(delta_usd, .95),
      max_delta_usd = max(delta_usd), .by = scenario_id)
  write_csv(changes, file.path(output, "paired_measurement_error.csv"))

  profit <- paired("step07a_profit_correction_final_revenue_interval", c("factor4_sbs", "specification"),
    c("draws", "global_revenue_p025", "global_revenue_p975", "eu27_revenue_p025", "eu27_revenue_p975"))
  stopifnot(all(profit$draws_r05b == 500L), all(profit$draws_r06b == 500L))
  write_csv(profit, file.path(output, "profit_uncertainty.csv"))

  joint_name <- "step15_law_of_total_variance_decomposition"
  joint <- function(root) filter(read(root, joint_name), record == "total_variance")
  joint_keys <- c("scope", "window")
  joint <- full_join(joint(historical), joint(revised),
    by = joint_keys, suffix = c("_r05b", "_r06b"), relationship = "one-to-one")
  stopifnot(all(joint$n_joint_draws_r05b == STEP15_DRAWS), all(joint$n_joint_draws_r06b == STEP15_DRAWS),
    all(joint$n_scenarios_r05b == 32L), all(joint$n_scenarios_r06b == 32L))
  write_csv(select(joint, all_of(joint_keys),
    matches("^(parameter_variance_share|scenario_variance_share|proposal_ratio|preferred_p05_usd_bn|preferred_p95_usd_bn|preferred_width90_usd_bn)_")),
    file.path(output, "joint_uncertainty.csv"))
}

# CSV has a header and lexical values. For RDS, record R classes and matrix
# dimensions as well as the columns of tabular and named-list outputs.
behavioural_artifact_schema <- function(path) {
  if (!file.exists(path)) return(NA_character_)
  if (endsWith(path, ".csv")) {
    return(paste(names(read_csv(path, n_max = 0, show_col_types = FALSE)), collapse = " | "))
  }
  describe <- function(x) paste(c(class(x)[1L], dim(x)), collapse = " ")
  value <- readRDS(path)
  if (!is.null(names(value))) {
    return(paste(paste0(names(value), " (", vapply(value, describe, ""), ")"), collapse = " | "))
  }
  describe(value)
}

write_behavioural_artifact_inventory <- function(revised, historical, output) {
  paths <- list.files(revised, "\\.(csv|rds)$", recursive = TRUE)
  old_paths <- list.files(historical, "\\.(csv|rds)$", recursive = TRUE)
  marker <- file.path("diagnostics", BEHAVIOURAL_SPECIFICATION_FILE)
  stopifnot(identical(setdiff(paths, old_paths), marker), length(setdiff(old_paths, paths)) == 0)
  old <- rep(NA_character_, length(paths))
  common <- paths %in% old_paths
  old[common] <- unname(tools::sha256sum(file.path(historical, paths[common])))
  new <- unname(tools::sha256sum(file.path(revised, paths)))
  change <- is.na(old) | old != new
  selected <- paths[change]
  filename <- basename(selected)
  reason <- case_when(
    filename == BEHAVIOURAL_SPECIFICATION_FILE ~ "Active specification and selected bandwidth",
    grepl("^(stage3_|step5_)", filename) ~ "Selected schedule, source response or Stage 05 description",
    grepl("^(stage4_5_|step6_stage4_5_)", filename) ~ "Revised source liability passed through fixed collector routing",
    grepl("^(stage4_6_|step7_stage4_6_)", filename) ~ "Recomputed decomposition or country results",
    grepl("^(profit_correction_final|step07a_)", filename) ~ "Fixed continuous-response filter at the preferred point",
    grepl("^(stage1_measurement_error|step9_stage1_measurement_error)", filename) ~ "Continuous schedule rebuilt within each ETR draw",
    grepl("^(step12_|step8_anova)", filename) ~ "Repriced liability, accounting or sequential screening",
    grepl("^step13_", filename) ~ "Replayed unilateral fiscal deviation or incentive capacity comparison",
    grepl("^step15_", filename) ~ "Recomputed joint uncertainty or accounting factorial",
    TRUE ~ "Recomputed downstream extension using the continuous schedule"
  )
  write_csv(tibble(path = file.path("data", "processed", selected),
    status = if_else(is.na(old[change]), "added", "changed"), r05b_sha256 = old[change], r06b_sha256 = new[change],
    r05b_schema = vapply(file.path(historical, selected), behavioural_artifact_schema, ""),
    r06b_schema = vapply(file.path(revised, selected), behavioural_artifact_schema, ""), reason),
    file.path(output, "processed_changes.csv"))
}

if (is_direct_script_run("code/diagnostics/behavioural_specification_comparison.R")) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 3L) stop("Supply revised and historical processed directories and a fresh analysis directory")
  compare_behavioural_replays(args[[1L]], args[[2L]], args[[3L]])
}
