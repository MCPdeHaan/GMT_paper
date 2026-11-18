# R11c paired scientific comparison. Read independently replayed trees; never
# write to either input tree or to the official processed/publication folders.
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "00_helpers.R"), local = TRUE)

factor2_compare_values <- function(old, new, keys, values) {
  assert_unique_keys(old, keys, "historical Factor 2 comparison")
  assert_unique_keys(new, keys, "revised Factor 2 comparison")
  old <- old |> arrange(across(all_of(keys)))
  new <- new |> arrange(across(all_of(keys)))
  if (!identical(as.data.frame(old[keys]), as.data.frame(new[keys]))) {
    stop("Factor 2 comparison has different keyed support", call. = FALSE)
  }
  # Unknown amounts stay unknown. There is no missing-to-zero conversion.
  bind_cols(old[keys], set_names(old[values], paste0(values, "_r10b")),
    set_names(new[values], paste0(values, "_r11c")),
    set_names(as_tibble(Map(`-`, new[values], old[values])), paste0(values, "_change")))
}

run_factor2_revision_comparison <- function(historical_root, revised_root, output_dir) {
  roots <- normalizePath(c(historical_root, revised_root), mustWork = TRUE)
  target <- file.path(normalizePath(dirname(output_dir), mustWork = TRUE), basename(output_dir))
  protected <- c(file.path(roots[1], c("data", "writing")),
    file.path(roots[2], c("data", "writing")), file.path(normalizePath(GMT_PROJECT_ROOT), c("data", "writing", ".git")))
  if (file.exists(target) || any(target == protected | startsWith(target, paste0(protected, "/")))) {
    stop("Use a fresh comparison directory outside data and publication trees", call. = FALSE)
  }
  read_rds <- function(arm, stem) readRDS(file.path(roots[arm], "data", "processed", paste0(stem, ".rds")))
  read_diag <- function(arm, stem) read_csv(file.path(roots[arm], "data", "processed", "diagnostics",
    paste0(stem, ".csv")), show_col_types = FALSE)
  old <- read_rds(1, "stage3_factorial_pair_year")
  new <- read_rds(2, "stage3_factorial_pair_year")
  keys <- c("scenario_id", "parent", "affiliate", "year")
  assert_unique_keys(old, keys, "historical core sources")
  assert_unique_keys(new, keys, "revised core sources")
  stopifnot(identical(old[keys], new[keys]), identical(names(old), names(new)))
  # Inactive bridge lookup columns change even in the aggregate arm. Its
  # actually selected scale, all source amounts, flags and behaviour do not.
  inactive <- c("sectoral_scale_average", "sectoral_scale_distributional")
  old_zero <- filter(old, x2_substance == 0) |> select(-all_of(inactive))
  new_zero <- filter(new, x2_substance == 0) |> select(-all_of(inactive))
  stopifnot(identical(old_zero, new_zero))
  changes <- tibble(column = names(old),
    identical_all_sources = vapply(names(old), function(n) identical(old[[n]], new[[n]]), logical(1)))
  prepare <- function(x, arm) x |> mutate(
    pre_sbie_liability = if_else(x1_etr == 0, stage1_topup_tax_average, stage1_topup_tax_distributional),
    aggregate_post_sbie = stage2_topup_selected,
    sectoral_post_sbie = stage2_topup_selected * if_else(x1_etr == 0,
      coalesce(sectoral_scale_average, 1), coalesce(sectoral_scale_distributional, 1))) |>
    left_join(read_rds(arm, "stage4_5_utpr_unsupported_sources") |>
      select(all_of(keys), unsupported_utpr), by = keys, relationship = "one-to-one") |>
    mutate(unsupported_utpr = coalesce_zero(unsupported_utpr),
      assigned_utpr = utpr_source_proxy_topup - unsupported_utpr)
  amounts <- c("pre_sbie_liability", "stage2_sbie", "aggregate_post_sbie", "sectoral_post_sbie",
    "topup_after_stage2", "topup_after_behaviour", "behavioural_avoided_topup", "reallocated_profit",
    "qdmtt_topup", "iir_topup", "utpr_source_proxy_topup", "assigned_utpr", "unsupported_utpr", "sbs_extinguished_topup")
  source_totals <- function(x, arm) prepare(x, arm) |>
    summarise(across(all_of(amounts), ~ sum(.x, na.rm = TRUE)),
      .by = c("scenario_id", "affiliate", "year"))
  source <- factor2_compare_values(source_totals(old, 1), source_totals(new, 2),
    c("scenario_id", "affiliate", "year"), amounts)
  response <- c("static_beta_raw", "static_beta_applied", "beta_applied", "behavioural_liability_filter")
  cells <- factor2_compare_values(prepare(filter(old, x2_substance == 1), 1),
    prepare(filter(new, x2_substance == 1), 2), keys, c(amounts, response))
  schedules <- select(old, all_of(keys), schedule_r10b = behavioural_regime) |>
    inner_join(select(new, all_of(keys), schedule_r11c = behavioural_regime),
      by = keys, relationship = "one-to-one") |>
    filter(schedule_r10b != schedule_r11c)
  collector_keys <- c("scenario_id", "country", "year", "channel")
  collector_totals <- function(arm) {
    x <- read_rds(arm, "stage4_5_revenue_by_channel_global")
    stopifnot(all(is.finite(x$revenue)))
    # The saved table additionally distinguishes routing weight provenance.
    # Collapse that dimension explicitly for the collector/channel estimand.
    x |> summarise(revenue = sum(revenue), .by = all_of(collector_keys))
  }
  collectors <- full_join(rename(collector_totals(1), revenue_r10b = revenue) |>
      mutate(record_r10b = TRUE),
    rename(collector_totals(2), revenue_r11c = revenue) |> mutate(record_r11c = TRUE),
    by = collector_keys, relationship = "one-to-one") |>
    mutate(record_r10b = coalesce(record_r10b, FALSE), record_r11c = coalesce(record_r11c, FALSE),
      # A missing positive-channel export row is a structural zero receipt.
      # Unsupported source amounts remain in their separate explicit ledger.
      revenue_change = coalesce(revenue_r11c, 0) - coalesce(revenue_r10b, 0)) |>
    arrange(across(all_of(collector_keys)))
  conservation <- factor2_compare_values(read_rds(1, "stage4_5_allocation_conservation"),
    read_rds(2, "stage4_5_allocation_conservation"), c("scenario_id", "year"),
    c("pre_allocation_topup", "allocated_topup", "sbs_extinguished_topup", "unsupported_utpr", "residual_gap"))
  # Both conditional game populations use the unchanged aggregate branch.
  game <- read_diag(1, "step13_unilateral_qdmtt_deviation_matrix")
  strategy <- read_diag(1, "step13_qdmtt_vs_sbti_strategy_comparison")
  game_files <- c("step13_unilateral_qdmtt_deviation_matrix.csv",
    "step13_qdmtt_vs_sbti_strategy_comparison.csv")
  # Compare bytes, avoiding readr's per-read parser diagnostic pointers.
  stopifnot(identical(unname(tools::sha256sum(file.path(roots[1], "data", "processed", "diagnostics", game_files))),
    unname(tools::sha256sum(file.path(roots[2], "data", "processed", "diagnostics", game_files)))))
  # Standalone simulation ranks may move when sectoral competitors change.
  # The preferred and all aggregate-branch monetary draws must remain paired.
  draw_old <- read_rds(1, "stage1_measurement_error_scenario_draws") |> filter(x2_substance == 0)
  draw_new <- read_rds(2, "stage1_measurement_error_scenario_draws") |> filter(x2_substance == 0)
  paired <- factor2_compare_values(draw_old, draw_new, c("draw_id", "scenario_id"), "eu_revenue")
  stopifnot(all(paired$eu_revenue_change == 0),
    identical(read_rds(1, "stage1_measurement_error_stage1_draws"), read_rds(2, "stage1_measurement_error_stage1_draws")),
    identical(read_rds(1, "profit_correction_final_revenue_uncertainty"), read_rds(2, "profit_correction_final_revenue_uncertainty")))
  outputs <- list(source_year_comparison = source, collector_channel_comparison = collectors,
    applied_schedule_changes = schedules,
    conservation_comparison = conservation, source_column_contract = changes,
    paired_aggregate_measurement_draws = paired,
    contract_checks = tibble(contract = c("ordered_original_source_keys", "aggregate_branch_active_fields",
      "432_repeal_and_optout_cases", "108_historical_strategy_rows", "500_paired_measurement_draw_inputs",
      "8000_aggregate_scenario_draw_receipts", "profit_only_preferred_draws"),
      result = "exact", rows = c(nrow(old), nrow(old_zero), nrow(game), nrow(strategy),
        nrow(read_rds(1, "stage1_measurement_error_stage1_draws")), nrow(paired),
        nrow(read_rds(1, "profit_correction_final_revenue_uncertainty")$draws))))
  dir.create(target)
  # Retain the full bilateral drill-down compactly. The aggregate branch is
  # covered by exact all-active-column identity above, not repeated here.
  saveRDS(cells, file.path(target, "sectoral_source_cell_comparison.rds"))
  iwalk(outputs, ~ write_csv(.x, file.path(target, paste0(.y, ".csv"))))
  invisible(outputs)
}

if (is_direct_script_run("code/diagnostics/factor2_revision.R")) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 3L) stop("Supply historical root, revised root and fresh comparison directory")
  run_factor2_revision_comparison(args[1], args[2], args[3])
}
