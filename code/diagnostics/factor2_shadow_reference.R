# R11b's no-imputed-adjustment construction, independently of the new selector.
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "00_helpers.R"), local = TRUE)

run_factor2_shadow_reference <- function(input_root, output_dir) {
  source(file.path(GMT_PROJECT_ROOT, "code", "09_econometric_and_reallocation_extensions.R"), local = TRUE)
  PROCESSED_DIR <- file.path(normalizePath(input_root, mustWork = TRUE), "data", "processed")
  DIAGNOSTICS_DIR <- file.path(PROCESSED_DIR, "diagnostics")
  target <- file.path(normalizePath(dirname(output_dir), mustWork = TRUE), basename(output_dir))
  protected <- c(file.path(normalizePath(input_root), c("data", "writing")),
    file.path(normalizePath(GMT_PROJECT_ROOT), c("data", "writing", ".git")))
  if (file.exists(target) || any(target == protected | startsWith(target, paste0(protected, "/")))) {
    stop("Use a fresh diagnostic directory outside data and publication trees", call. = FALSE)
  }
  if (file.exists(file.path(DIAGNOSTICS_DIR, FACTOR2_SPECIFICATION_FILE))) {
    stop("The independent shadow starts from the historical hybrid reference", call. = FALSE)
  }
  panel <- read_stage5_input("stage3_factorial_pair_year")
  # This is the R11b construction: the legacy rate implementation with a zero
  # capacity control, not selection of the new production sectoral-only column.
  scales <- build_split_substance_scales()
  changed <- filter(panel, x2_substance == 1) |>
    left_join(scales, by = c("rate_scenario", "affiliate", "year"), relationship = "many-to-one") |>
    mutate(sectoral_scale_selected = coalesce(if_else(x1_etr == 0,
      sector_only_average, sector_only_distributional), 1),
      topup_after_stage2 = pmax(stage2_topup_selected*sectoral_scale_selected, 0)) |>
    add_behavioural_response() |> select(all_of(names(panel)))
  counterfactual <- bind_rows(filter(panel, x2_substance == 0), changed)
  source <- build_source_panel(counterfactual)
  allocation <- allocate_stage4_revenue(source, read_stage4_utpr_weights())
  check <- build_conservation_diagnostics(source, allocation$revenue_by_channel_global,
    allocation$unsupported_utpr)
  receipts <- allocation$revenue_by_channel_global |>
    select(scenario_id, country, year, revenue)
  result <- imap_dfr(list(FY2023 = 2023L, `2017–2023` = MAIN_YEARS), function(years, window) {
    x <- filter(receipts, year %in% years)
    bind_rows(mutate(x, scope = "Global"), mutate(filter(x, country %in% EU27_ISO3), scope = "EU27")) |>
      summarise(assigned_total = sum(revenue), .by = c(scope, scenario_id)) |>
      mutate(window, reference = "R11b_no_imputed_adjustment", .before = 1)
  }) |> arrange(scope, window, scenario_id)
  stopifnot(nrow(result) == 128L)
  dir.create(output_dir)
  write_csv(result, file.path(output_dir, "core_shadow_receipts.csv"))
  write_csv(tibble(metric = "max_source_year_conservation_gap_usd", value = max(abs(check$residual_gap))),
    file.path(output_dir, "shadow_conservation.csv"))
  invisible(result)
}

if (is_direct_script_run("code/diagnostics/factor2_shadow_reference.R")) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 2L) stop("Supply the historical input root and fresh diagnostic directory")
  run_factor2_shadow_reference(args[1], args[2])
}
