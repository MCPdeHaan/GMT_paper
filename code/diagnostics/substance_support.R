# R11a support audit. Run from the repository root with a frozen input root
# and a separate output directory. No analytical stage calls this script.
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "00_helpers.R"), local = TRUE)

run_substance_support <- function(input_root, output_dir,
                                  specification = factor2_specification()) {
  source(file.path(GMT_PROJECT_ROOT, "code", "09_econometric_and_reallocation_extensions.R"), local = TRUE)
  source(file.path(GMT_PROJECT_ROOT, "code", "11_policy_game_and_variance_extensions.R"), local = TRUE)
  PROCESSED_DIR <- file.path(input_root, "data", "processed")
  read_panel <- function(name) readRDS(file.path(PROCESSED_DIR, paste0(name, ".rds")))

  bilateral <- read_panel("stage2_bilateral_panel") |>
    filter(analysis_profit_positive > 0)
  bilateral_exposure <- bind_rows(mutate(bilateral, scope = "global"),
    mutate(filter(bilateral, affiliate_is_eu27), scope = "EU27")) |>
    mutate(activity_support = case_when(
      stage2_payroll_zero_fallback_flag & stage2_assets_zero_fallback_flag ~ "both_missing",
      stage2_payroll_zero_fallback_flag ~ "payroll_missing",
      stage2_assets_zero_fallback_flag ~ "assets_missing",
      TRUE ~ "neither_missing"
    )) |>
    summarise(pair_years = n(), profit = sum(analysis_profit_positive),
      payroll = sum(payroll_sbie, na.rm = TRUE), assets = sum(assets_sbie, na.rm = TRUE),
      sbie = sum(stage2_sbie, na.rm = TRUE),
      before_sbie = sum(stage1_topup_tax_distributional, na.rm = TRUE),
      after_sbie = sum(stage2_topup_tax_distributional, na.rm = TRUE),
      .by = c(scope, rate_scenario, activity_support))

  panel <- read_panel("stage2_sectoral_panel")
  hosts <- read_panel("stage1_affiliate_year")
  amounts <- panel |>
    filter(rate_scenario == "initial") |>
    left_join(select(hosts, affiliate, year, stage1_distributional_low_share),
      by = c("affiliate", "year"), relationship = "many-to-one") |>
    mutate(capacity = sbti_maximum_capacity(sectoral_payroll, sectoral_assets),
      supported_profit = sectoral_profit_proxy > 0 & is.finite(sectoral_kappa),
      zero_profit_activity = sectoral_profit_proxy == 0 &
        (coalesce_zero(sectoral_payroll) > 0 | coalesce_zero(sectoral_assets) > 0),
      gap_after_sbie = stage1_distributional_topup_rate * (1 - sectoral_phi),
      post_sbie_topup = stage1_distributional_low_share * gap_after_sbie * sectoral_profit_proxy,
      capacity_on_low_profit = stage1_distributional_low_share * capacity,
      capacity_above_gap = supported_profit & stage1_distributional_low_share > 0 &
        capacity > gap_after_sbie * sectoral_profit_proxy)

  # Compare the two orders on identical finite-activity sectors for each
  # affiliate-year. The pooled comparator is a diagnostic of nonlinearity.
  sector_capacity <- amounts |>
    summarise(sectors = n(), missing_profit_share = sum(is.na(sectoral_profit_share_used)),
      missing_payroll_share = sum(is.na(sectoral_payroll_share_used)),
      missing_asset_share = sum(is.na(sectoral_asset_share_used)),
      profit = sum(sectoral_profit_proxy, na.rm = TRUE),
      payroll = sum(sectoral_payroll, na.rm = TRUE),
      assets = sum(sectoral_assets, na.rm = TRUE),
      profit_reconciliation_gap = profit - first(total_profit),
      payroll_reconciliation_gap = payroll - first(total_payroll),
      asset_reconciliation_gap = assets - first(total_assets),
      sbie = sum(sectoral_sbie, na.rm = TRUE),
      matched_activity_sectors = sum(is.finite(capacity)),
      sector_first = sum(capacity[is.finite(capacity)]),
      aggregate_first = sbti_maximum_capacity(sum(sectoral_payroll[is.finite(capacity)]),
        sum(sectoral_assets[is.finite(capacity)])),
      maximum_difference = sector_first - aggregate_first,
      capacity_on_positive_profit = sum(capacity[supported_profit %in% TRUE], na.rm = TRUE),
      zero_profit_activity_sectors = sum(zero_profit_activity, na.rm = TRUE),
      zero_profit_payroll = sum(sectoral_payroll[zero_profit_activity], na.rm = TRUE),
      zero_profit_assets = sum(sectoral_assets[zero_profit_activity], na.rm = TRUE),
      zero_profit_capacity = sum(capacity[zero_profit_activity], na.rm = TRUE),
      post_sbie_topup = sum(post_sbie_topup, na.rm = TRUE),
      capacity_above_gap_sectors = sum(capacity_above_gap, na.rm = TRUE),
      topup_in_capacity_above_gap = sum(post_sbie_topup[capacity_above_gap], na.rm = TRUE),
      capacity_on_low_profit_above_gap = sum(capacity_on_low_profit[capacity_above_gap], na.rm = TRUE),
      .by = c(affiliate, year))

  sector_concentration <- amounts |>
    summarise(profit = sum(sectoral_profit_proxy, na.rm = TRUE),
      payroll = sum(sectoral_payroll, na.rm = TRUE), assets = sum(sectoral_assets, na.rm = TRUE),
      capacity = sum(capacity, na.rm = TRUE), .by = nace_r2) |>
    mutate(capacity_share = capacity / sum(capacity)) |>
    arrange(desc(capacity))

  sector_share_provenance <- bind_rows(
    transmute(amounts, component = "profit", source = profit_share_proxy_source,
      amount = sectoral_profit_proxy),
    transmute(amounts, component = "payroll", source = payroll_share_proxy_source,
      amount = sectoral_payroll),
    transmute(amounts, component = "assets", source = asset_cell_proxy_source,
      amount = sectoral_assets)
  ) |>
    summarise(sectors = n(), amount = sum(amount, na.rm = TRUE), .by = c(component, source))

  bridge <- build_sectoral_factor2_bridge(bilateral, hosts, panel, specification = specification)
  keys <- c("rate_scenario", "affiliate", "year")
  factor2_support <- bilateral |>
    filter(affiliate_is_eu27) |>
    summarise(profit = sum(analysis_profit_positive), payroll = sum(payroll_sbie, na.rm = TRUE),
      assets = sum(assets_sbie, na.rm = TRUE), topup = sum(stage2_topup_tax_distributional, na.rm = TRUE),
      .by = all_of(keys)) |>
    left_join(select(bridge, all_of(keys), sectoral_scale_source_distributional,
      sectoral_scale_distributional), by = keys, relationship = "one-to-one")

  shares <- nash_sector_shares()
  game_exposure <- imap_dfr(nash_load_panels(), function(panel, level) {
    nash_sbti_capacity(list(source = nash_r3_panel(panel)), shares) |>
      mutate(level = level, capacity_above_qdmtt = capacity > qdmtt) |>
      summarise(source_cells = n(), qdmtt = sum(qdmtt), capacity = sum(capacity),
        covered_tax_proxy = sum(covered_tax_proxy), new_incentive_proxy = sum(used_new_qti),
        overlay = sum(sbti_overlay_relief), existing_incentives = sum(existing_qti_relief),
        .by = c(level, affiliate, year, capacity_above_qdmtt))
  })
  output <- list(bilateral_exposure = bilateral_exposure, sector_capacity = sector_capacity,
    sector_concentration = sector_concentration, sector_share_provenance = sector_share_provenance,
    factor2_support = factor2_support, game_exposure = game_exposure)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  iwalk(output, ~ write_csv(.x, file.path(output_dir, paste0(.y, ".csv"))))
  invisible(output)
}

if (is_direct_script_run("code/diagnostics/substance_support.R")) {
  args <- commandArgs(trailingOnly = TRUE)
  stopifnot(length(args) == 2L)
  run_substance_support(args[1], args[2])
}
