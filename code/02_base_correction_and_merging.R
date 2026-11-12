# 02_base_correction_and_merging.R
# Step 2 of the methodology pipeline.
#
# Builds the bilateral Parent x Affiliate x Year base panel from the cleaned
# inputs in data/processed/. the CbCR tables onto a country-like bilateral spine;
# adds the low-dimensional supplementary controls needed later;
# constructs a wage-based payroll proxy from employee counts;
# constructs deterministic corrected profit bases before Stage 1 / Stage 3.
library(dplyr)
library(tidyr)
library(purrr)
library(readr)
library(stringr)
library(tibble)

source("code/00_helpers.R")

run_base_panel <- function(in_dir = PROCESSED_DIR, out_dir = PROCESSED_DIR) {
  input_dir <- in_dir
  output_dir <- out_dir
  diagnostics_dir <- file.path(output_dir, "diagnostics")
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  dir.create(diagnostics_dir, showWarnings = FALSE, recursive = TRUE)

  ESTIMATION_YEARS <- MAIN_YEARS
  EMPLOYEES_PER_ENTITY_CAP <- 100000
  EUKLEMS_STOCK_COVERAGE_THRESHOLD <- 0.75

  AGGREGATE_AFFILIATES <- c(
    "A", "A_O", "E", "E_O", "F", "F_O",
    "S", "S_O", "W", "W_O", "WXD", "STLS"
  )
  PANELAI_PERCENTILES <- c(
    "etr_p5_panelai", "etr_p25_panelai", "etr_p50_panelai",
    "etr_p75_panelai", "etr_p95_panelai"
  )
  T_PERCENTILES <- c("etr_p5", "etr_p25", "etr_p50", "etr_p75", "etr_p95")

  # Literature-based conduit / haven set retained as an exposure diagnostic.
  # The preferred profit correction no longer applies a mechanical foreign
  # conduit haircut, because the public CbCR data do not identify ownership-chain
  # equity income in foreign affiliate cells.
  CONDUIT_HAVENS <- c(
    "BMU", "CYM", "IRL", "LUX", "NLD",
    "CHE", "SGP", "HKG", "PRI", "GBR"
  )

  build_year_nearest_lookup <- function(target_keys, candidates, value_col, source_col) {
    target_keys |>
      rename(jurisdiction = affiliate) |>
      left_join(candidates, by = "jurisdiction", relationship = "many-to-many") |>
      filter(!is.na(.data[[value_col]])) |>
      mutate(
        year_gap = abs(year - source_year),
        future_gap = source_year > year
      ) |>
      arrange(jurisdiction, year, source_rank, year_gap, future_gap, source_year) |>
      group_by(jurisdiction, year) |>
      slice(1) |>
      ungroup() |>
      transmute(
        affiliate               = jurisdiction,
        year,
        affiliate_wage_annual   = .data[[value_col]],
        affiliate_wage_source   = .data[[source_col]],
        affiliate_wage_year     = source_year,
        affiliate_wage_year_gap = year_gap
      )
  }

  # 1. Load cleaned inputs
  t1 <- readRDS(file.path(input_dir, "cbcr_table1.rds"))
  t2 <- readRDS(file.path(input_dir, "cbcr_table2.rds"))
  t3 <- readRDS(file.path(input_dir, "cbcr_table3.rds"))
  t4 <- readRDS(file.path(input_dir, "cbcr_table4.rds"))
  t5 <- readRDS(file.path(input_dir, "cbcr_table5.rds"))
  t6 <- readRDS(file.path(input_dir, "cbcr_table6.rds"))

  cit_statutory <- readRDS(file.path(input_dir, "cit_statutory.rds")) |>
    mutate(jurisdiction = normalize_code(jurisdiction))
  wb_classifications <- readRDS(file.path(input_dir, "wb_classifications.rds")) |>
    mutate(jurisdiction = normalize_code(jurisdiction))
  wb_gdp <- readRDS(file.path(input_dir, "wb_gdp.rds")) |>
    mutate(jurisdiction = normalize_code(jurisdiction))
  wb_population <- readRDS(file.path(input_dir, "wb_population.rds")) |>
    mutate(jurisdiction = normalize_code(jurisdiction))
  wages_oecd <- readRDS(file.path(input_dir, "wages_oecd.rds")) |>
    mutate(jurisdiction = normalize_code(jurisdiction))
  wages_ilo_monthly <- readRDS(file.path(input_dir, "wages_ilo_monthly.rds")) |>
    mutate(jurisdiction = normalize_code(jurisdiction))
  fats_post2021 <- readRDS(file.path(input_dir, "fats_post2021.rds"))
  euklems_sector_capital <- readRDS(file.path(input_dir, "euklems_sector_capital.rds")) |>
    mutate(jurisdiction = normalize_code(jurisdiction))
  global_intan_annual <- readRDS(file.path(input_dir, "global_intan_invest_annual.rds")) |>
    mutate(jurisdiction = normalize_code(jurisdiction))
  bea_us_mne_country_industry <- readRDS(file.path(input_dir, "bea_us_mne_country_industry.rds")) |>
    mutate(jurisdiction = normalize_code(jurisdiction))
  beps_rules <- readRDS(file.path(input_dir, "beps_rules.rds")) |>
    mutate(jurisdiction = normalize_code(jurisdiction))
  cbcr_requirements <- readRDS(file.path(input_dir, "cbcr_requirements.rds")) |>
    mutate(jurisdiction = normalize_code(jurisdiction))
  oecd_central_record <- readRDS(file.path(input_dir, "oecd_pillar2_central_record.rds")) |>
    mutate(jurisdiction = normalize_code(jurisdiction))


  # 2. Core bilateral spine and CbCR merges
  panel <- t1 |>
    filter(
      year %in% CORE_YEARS,
      !affiliate %in% AGGREGATE_AFFILIATES
    ) |>
    arrange(parent, affiliate, year) |>
    mutate(
      pair_id = paste(parent, affiliate, sep = "__"),
      is_domestic = parent == affiliate,
      is_2016_transition = year == 2016,
      is_main_estimation_year = year %in% ESTIMATION_YEARS,
      affiliate_is_eu27 = affiliate %in% EU27_ISO3,
      affiliate_is_conduit_haven = affiliate %in% CONDUIT_HAVENS,
      holding_share_panelai = safe_divide(act_holding_panelai, entities_count_panelai),
      holding_share_panelaii = safe_divide(act_holding_panelaii, entities_count_panelaii),
      profit_adj_observed_panelai = !is.na(profit_adj_panelai),
      profit_adj_ratio_observed = safe_divide(profit_adj_panelai, profit_panelai),
      profit_adj_above_profit_flag = !is.na(profit_adj_ratio_observed) &
        profit_adj_ratio_observed > 1 + 1e-9
    )

  assert_unique_keys(panel, c("parent", "affiliate", "year"), "base spine")

  t2_wide <- t2 |>
    rename_with(~ paste0("t2_", .x), -c(parent, affiliate, year))

  t3_low <- t3 |>
    filter(etr_bracket == "rate_0_15") |>
    select(-etr_bracket) |>
    rename_with(~ paste0("t3_low_", .x), -c(parent, affiliate, year))

  t4_low <- t4 |>
    filter(etr_bracket == "rate_0_15") |>
    select(-etr_bracket) |>
    rename_with(~ paste0("t4_low_", .x), -c(parent, affiliate, year))

  # Full Table IV bracket profile kept as a side panel for the Bracket-Share
  # Panel Imputation (Section sec:distributional / sec:crossval). Parents are
  # pooled within affiliate-year to produce a single within-jurisdiction
  # bracket-share vector per cell. Shares are computed only across the
  # positive-profit brackets (the non-overlapping partition {rate_0_15,
  # rate_15, rate_20_30, rate_30} for 2019-2022 bilateral data, and the
  # finer 2016-2018 WXD partition {rate_0_10, rate_10, rate_10_20, rate_20,
  # rate_20_30, rate_30} for the legacy vintages). The negative-profit
  # brackets are retained as companion volumes for diagnostics but do not
  # enter the share denominator, which keeps bracket_profit_share bounded in
  # [0, 1] even when an affiliate-year reports substantial loss mass.
  T4_POSITIVE_BRACKETS <- c(
    T4_DIRECT_POSITIVE_BRACKETS,
    "rate_0_10", "rate_10", "rate_10_20", "rate_20",
    "rate_10_accrued"
  )

  t4_brackets_long <- t4 |>
    filter(
      !affiliate %in% AGGREGATE_AFFILIATES,
      year %in% CORE_YEARS
    ) |>
    group_by(affiliate, year, etr_bracket) |>
    summarise(
      profit = sum_or_na(profit),
      tax_accrued = sum_or_na(tax_accrued),
      assets = sum_or_na(assets),
      employees = sum_or_na(employees),
      entities_count = sum_or_na(entities_count),
      subgroups_count = sum_or_na(subgroups_count),
      cbcr_count = sum_or_na(cbcr_count),
      .groups = "drop"
    )

  t4_bilateral_brackets <- t4 |>
    filter(
      year %in% CORE_YEARS,
      !parent %in% AGGREGATE_AFFILIATES,
      !affiliate %in% AGGREGATE_AFFILIATES
    ) |>
    group_by(parent, affiliate, year) |>
    mutate(
      is_positive_bracket = etr_bracket %in% T4_POSITIVE_BRACKETS,
      positive_profit_total = sum(pmax(profit[is_positive_bracket], 0),
        na.rm = TRUE
      ),
      bracket_profit_share = if_else(
        is_positive_bracket & positive_profit_total > 0,
        pmax(profit, 0) / positive_profit_total,
        NA_real_
      )
    ) |>
    ungroup() |>
    arrange(parent, affiliate, year, etr_bracket)

  assert_unique_keys(
    t4_bilateral_brackets,
    c("parent", "affiliate", "year", "etr_bracket"),
    "Bilateral Table IV bracket shares"
  )

  t4_parent_profit <- t4_bilateral_brackets |>
    filter(year >= 2019L, etr_bracket %in% T4_DIRECT_POSITIVE_BRACKETS) |>
    mutate(eu27 = affiliate %in% EU27_ISO3)

  t4_parent_composition <- bind_rows(
    mutate(t4_parent_profit, scope = "global"),
    mutate(filter(t4_parent_profit, eu27), scope = "eu27")
  ) |>
    group_by(year, scope, parent) |>
    summarise(positive_profit = sum(pmax(profit, 0), na.rm = TRUE), .groups = "drop") |>
    group_by(year, scope) |>
    mutate(
      scope_positive_profit = sum(positive_profit),
      share = safe_divide(positive_profit, scope_positive_profit)
    ) |>
    ungroup() |>
    arrange(year, scope, desc(share), parent)

  t4_positive_totals <- t4_brackets_long |>
    filter(etr_bracket %in% T4_POSITIVE_BRACKETS) |>
    group_by(affiliate, year) |>
    summarise(
      positive_profit_total = sum(pmax(profit, 0), na.rm = TRUE),
      .groups = "drop"
    )

  t4_brackets_by_affiliate_year <- t4_brackets_long |>
    left_join(t4_positive_totals, by = c("affiliate", "year")) |>
    mutate(
      is_positive_bracket = etr_bracket %in% T4_POSITIVE_BRACKETS,
      bracket_profit_share = if_else(
        is_positive_bracket & !is.na(positive_profit_total) &
          positive_profit_total > 0,
        pmax(profit, 0) / positive_profit_total,
        NA_real_
      )
    ) |>
    arrange(affiliate, year, etr_bracket)

  assert_unique_keys(
    t4_brackets_by_affiliate_year,
    c("affiliate", "year", "etr_bracket"),
    "Table IV bracket shares"
  )

  t5_wide <- t5 |>
    rename_with(~ paste0("t5_", .x), -c(parent, year))

  t6_wide <- t6 |>
    select(
      parent, affiliate, year, size_class, profit, assets, employees,
      accumulated_earnings, tax_accrued, entities_count,
      cbcr_count, subgroups_count
    ) |>
    pivot_wider(
      names_from = size_class,
      values_from = c(
        profit, assets, employees, accumulated_earnings, tax_accrued,
        entities_count, cbcr_count, subgroups_count
      ),
      names_glue = "t6_{.value}_{size_class}"
    )

  panel <- panel |>
    dplyr::left_join(t2_wide,
      by = c(
        "parent" = "parent",
        "affiliate" = "affiliate",
        "year" = "year"
      )
    ) |>
    dplyr::left_join(t3_low,
      by = c(
        "parent" = "parent",
        "affiliate" = "affiliate",
        "year" = "year"
      )
    ) |>
    dplyr::left_join(t4_low,
      by = c(
        "parent" = "parent",
        "affiliate" = "affiliate",
        "year" = "year"
      )
    ) |>
    dplyr::left_join(t5_wide,
      by = c("parent" = "parent", "year" = "year")
    ) |>
    dplyr::left_join(t6_wide,
      by = c(
        "parent" = "parent",
        "affiliate" = "affiliate",
        "year" = "year"
      )
    )


  # 3. Supplementary datasets added on their natural keys


  # Jurisdiction metadata
  jurisdiction_lookup <- wb_classifications |>
    transmute(
      jurisdiction,
      iso2,
      jurisdiction_name = name,
      region,
      income_level,
      income_id
    ) |>
    bind_rows(
      tibble(
        jurisdiction = "XKV", iso2 = "XK",
        jurisdiction_name = "Kosovo",
        region = "Europe & Central Asia",
        income_level = "Upper middle income",
        income_id = "UMC"
      ),
      tibble(
        jurisdiction = "TWN", iso2 = "TW",
        jurisdiction_name = "Taiwan",
        region = NA_character_,
        income_level = NA_character_,
        income_id = NA_character_
      )
    ) |>
    distinct(jurisdiction, .keep_all = TRUE)

  parent_lookup <- jurisdiction_lookup |>
    rename_with(~ paste0("parent_", .x), -jurisdiction) |>
    rename(parent = jurisdiction)

  affiliate_lookup <- jurisdiction_lookup |>
    rename_with(~ paste0("affiliate_", .x), -jurisdiction) |>
    rename(affiliate = jurisdiction)

  # Statutory rates and World Bank controls
  cit_affiliate <- cit_statutory |>
    rename(
      affiliate = jurisdiction,
      affiliate_cit_standard = cit_standard,
      affiliate_cit_top_all = cit_top_all
    )

  cit_parent <- cit_statutory |>
    rename(
      parent = jurisdiction,
      parent_cit_standard = cit_standard,
      parent_cit_top_all = cit_top_all
    )

  wb_gdp_affiliate <- wb_gdp |>
    select(jurisdiction, year, gdp_pc_usd) |>
    rename(affiliate = jurisdiction, affiliate_gdp_pc_usd = gdp_pc_usd)

  wb_population_affiliate <- wb_population |>
    select(jurisdiction, year, population) |>
    rename(affiliate = jurisdiction, affiliate_population = population)

  # Wage benchmark: OECD annual PPP first, then ILO monthly PPP annualised, then
  # ILO monthly USD annualised. Within each source, use the nearest available year.
  oecd_wage_candidates <- wages_oecd |>
    filter(currency == "USD_PPP") |>
    transmute(
      jurisdiction,
      source_rank = 1L,
      wage_source = "oecd_annual_ppp",
      source_year = year,
      wage_annual = value
    )

  ilo_sector_priority <- c(
    "ECO_ISIC4_TOTAL", "ECO_ISIC3_TOTAL",
    "ECO_AGGREGATE_TOTAL", "ECO_SECTOR_TOTAL"
  )

  ilo_monthly_selected <- wages_ilo_monthly |>
    filter(
      sex == "SEX_T",
      currency %in% c("CUR_TYPE_PPP", "CUR_TYPE_USD"),
      sector %in% ilo_sector_priority
    ) |>
    mutate(
      sector_rank = match(sector, ilo_sector_priority),
      source_rank = if_else(currency == "CUR_TYPE_PPP", 2L, 3L),
      wage_source = if_else(currency == "CUR_TYPE_PPP",
        "ilo_monthly_ppp_x12",
        "ilo_monthly_usd_x12"
      )
    ) |>
    arrange(jurisdiction, year, source_rank, sector_rank) |>
    group_by(jurisdiction, year, currency) |>
    slice(1) |>
    ungroup() |>
    transmute(
      jurisdiction,
      source_rank,
      wage_source,
      source_year = year,
      wage_annual = value * 12
    )

  wage_candidates <- bind_rows(oecd_wage_candidates, ilo_monthly_selected)
  assert_unique_keys(
    wage_candidates,
    c("jurisdiction", "source_rank", "source_year", "wage_source"),
    "wage candidates"
  )

  wage_lookup <- build_year_nearest_lookup(
    target_keys = panel |> distinct(affiliate, year),
    candidates  = wage_candidates,
    value_col   = "wage_annual",
    source_col  = "wage_source"
  )

  # BEPS rules reduced to clean presence flags.
  beps_flags <- beps_rules |>
    group_by(jurisdiction, year, rule) |>
    summarise(
      rule_present = case_when(
        any(!is.na(value) & str_to_lower(value) != "no") ~ TRUE,
        any(!is.na(value)) ~ FALSE,
        TRUE ~ NA
      ),
      .groups = "drop"
    ) |>
    pivot_wider(
      names_from = rule,
      values_from = rule_present,
      names_prefix = "beps_"
    )

  beps_affiliate <- beps_flags |>
    rename_with(~ paste0("affiliate_", .x), -c(jurisdiction, year)) |>
    rename(affiliate = jurisdiction)

  beps_parent <- beps_flags |>
    rename_with(~ paste0("parent_", .x), -c(jurisdiction, year)) |>
    rename(parent = jurisdiction)

  # CbCR filing requirements kept only in the dimensions that affect coverage.
  cbcr_req_summary <- cbcr_requirements |>
    mutate(
      upe_start = if_else(
        measure == "UPE" & value != "TBC",
        as.character(as.Date(value, format = "%d-%b-%y")),
        NA_character_
      )
    ) |>
    group_by(jurisdiction) |>
    summarise(
      cbcr_law = any(measure == "CBCR_LAW" & str_to_lower(value) == "yes"),
      cbcr_upe_start = min_date_or_na(upe_start),
      cbcr_threshold = pick_first_non_missing(value[measure == "THRESHOLD"]),
      .groups = "drop"
    )

  cbcr_req_parent <- cbcr_req_summary |>
    rename_with(~ paste0("parent_", .x), -jurisdiction) |>
    rename(parent = jurisdiction)

  # OECD Central Record reduced to earliest qualified effective dates.
  oecd_summary <- oecd_central_record |>
    filter(rule_type %in% c("qualified_iir", "qualified_qdmtt", "qualified_sbs")) |>
    group_by(jurisdiction, rule_type) |>
    summarise(start_date = min_date_or_na(effective_date), .groups = "drop") |>
    pivot_wider(
      names_from = rule_type,
      values_from = start_date,
      names_prefix = "oecd_"
    ) |>
    mutate(
      oecd_qdmtt_by_2026 =
        !is.na(oecd_qualified_qdmtt) &
          oecd_qualified_qdmtt <= as.Date("2026-01-01"),
      oecd_iir_by_2026 =
        !is.na(oecd_qualified_iir) &
          oecd_qualified_iir <= as.Date("2026-01-01"),
      oecd_sbs_by_2026 =
        !is.na(oecd_qualified_sbs) &
          oecd_qualified_sbs <= as.Date("2026-01-01")
    )

  oecd_affiliate <- oecd_summary |>
    rename_with(~ paste0("affiliate_", .x), -jurisdiction) |>
    rename(affiliate = jurisdiction)

  oecd_parent <- oecd_summary |>
    rename_with(~ paste0("parent_", .x), -jurisdiction) |>
    rename(parent = jurisdiction)

  panel <- panel |>
    dplyr::left_join(parent_lookup,
      by = c("parent" = "parent")
    ) |>
    dplyr::left_join(affiliate_lookup,
      by = c("affiliate" = "affiliate")
    ) |>
    dplyr::left_join(cit_affiliate,
      by = c(
        "affiliate" = "affiliate",
        "year" = "year"
      )
    ) |>
    dplyr::left_join(cit_parent,
      by = c(
        "parent" = "parent",
        "year" = "year"
      )
    ) |>
    dplyr::left_join(wb_gdp_affiliate,
      by = c(
        "affiliate" = "affiliate",
        "year" = "year"
      )
    ) |>
    dplyr::left_join(wb_population_affiliate,
      by = c(
        "affiliate" = "affiliate",
        "year" = "year"
      )
    ) |>
    dplyr::left_join(wage_lookup,
      by = c(
        "affiliate" = "affiliate",
        "year" = "year"
      )
    ) |>
    dplyr::left_join(beps_affiliate,
      by = c(
        "affiliate" = "affiliate",
        "year" = "year"
      )
    ) |>
    dplyr::left_join(beps_parent,
      by = c(
        "parent" = "parent",
        "year" = "year"
      )
    ) |>
    dplyr::left_join(cbcr_req_parent,
      by = c("parent" = "parent")
    ) |>
    dplyr::left_join(oecd_affiliate,
      by = c("affiliate" = "affiliate")
    ) |>
    dplyr::left_join(oecd_parent,
      by = c("parent" = "parent")
    )


  # Profit reconciliation model. This is produced by
  # code/02a_profit_reconciliation_model.R and consumed here so that the
  # denominator correction is explicit upstream of Stage 1.
  profit_reconciliation_path <- file.path(input_dir, "profit_correction_parent_year.rds")
  if (!file.exists(profit_reconciliation_path)) {
    stop(
      "Missing profit reconciliation model output: ",
      profit_reconciliation_path,
      ". Run code/02a_profit_reconciliation_model.R before Step 2.",
      call. = FALSE
    )
  }

  profit_reconciliation <- readRDS(profit_reconciliation_path) |>
    transmute(
      parent,
      year,
      rho_hat_pt,
      rho_lo_pt,
      rho_hi_pt,
      profit_reconciliation_main_source = main_source,
      profit_reconciliation_support_class = support_class,
      profit_reconciliation_posterior_sd = posterior_sd,
      profit_reconciliation_external_anchor_flag = external_anchor_flag,
      profit_reconciliation_public_signal_flag = public_signal_flag,
      profit_reconciliation_extrapolated_flag = extrapolated_flag
    )

  assert_unique_keys(
    profit_reconciliation, c("parent", "year"),
    "profit reconciliation parent-year model"
  )

  panel <- panel |>
    dplyr::left_join(
      profit_reconciliation,
      by = c("parent" = "parent", "year" = "year")
    )


  # 4. Deterministic imputations and corrected profit bases

  # OECD CbCR "EARNINGS" is accumulated earnings, not payroll. The SBIE payroll
  # input is therefore proxied from employee counts and the affiliate-year wage
  # benchmark rather than taken from the CbCR monetary measures.
  panel <- panel |>
    mutate(
      assets_sbie = coalesce(assets_panelaii, assets_panelai, assets),
      assets_sbie_source = case_when(
        !is.na(assets_panelaii) ~ "panelaii",
        !is.na(assets_panelai) ~ "panelai",
        !is.na(assets) ~ "aggregate",
        TRUE ~ "missing"
      ),
      entities_sbie = coalesce(entities_count_panelaii, entities_count_panelai, entities_count),
      entities_sbie_source = case_when(
        !is.na(entities_count_panelaii) ~ "panelaii",
        !is.na(entities_count_panelai) ~ "panelai",
        !is.na(entities_count) ~ "aggregate",
        TRUE ~ "missing"
      ),
      employees_sbie_raw = coalesce(employees_panelaii, employees_panelai, employees),
      employees_sbie_source = case_when(
        !is.na(employees_panelaii) ~ "panelaii",
        !is.na(employees_panelai) ~ "panelai",
        !is.na(employees) ~ "aggregate",
        TRUE ~ "missing"
      ),
      employees_sbie_entity_cap = if_else(
        !is.na(entities_sbie) & entities_sbie > 0,
        entities_sbie * EMPLOYEES_PER_ENTITY_CAP,
        NA_real_
      ),
      employees_sbie_population_cap = affiliate_population,
      employees_sbie_plausibility_cap = row_min_or_na(
        employees_sbie_entity_cap,
        employees_sbie_population_cap
      ),
      employees_sbie_correction_flag = !is.na(employees_sbie_raw) &
        !is.na(employees_sbie_plausibility_cap) &
        employees_sbie_raw > employees_sbie_plausibility_cap,
      employees_sbie = if_else(
        employees_sbie_correction_flag,
        employees_sbie_plausibility_cap,
        employees_sbie_raw
      ),
      employees_sbie_ratio_to_cap = safe_divide(
        employees_sbie_raw,
        employees_sbie_plausibility_cap
      ),
      employees_sbie_correction_share = safe_divide(
        employees_sbie_raw - employees_sbie,
        employees_sbie_raw
      ),
      payroll_sbie = if_else(
        !is.na(employees_sbie) & employees_sbie >= 0 & !is.na(affiliate_wage_annual),
        employees_sbie * affiliate_wage_annual,
        NA_real_
      ),
      payroll_sbie_raw_uncapped = if_else(
        !is.na(employees_sbie_raw) & employees_sbie_raw >= 0 & !is.na(affiliate_wage_annual),
        employees_sbie_raw * affiliate_wage_annual,
        NA_real_
      ),
      payroll_sbie_source = case_when(
        !is.na(payroll_sbie) & employees_sbie_correction_flag ~
          paste0("proxy_", employees_sbie_source, "_", affiliate_wage_source, "_screened_emp"),
        !is.na(payroll_sbie) ~ paste0("proxy_", employees_sbie_source, "_", affiliate_wage_source),
        !is.na(employees_sbie) & is.na(affiliate_wage_annual) ~ paste0("missing_wage_", employees_sbie_source),
        is.na(employees_sbie) & !is.na(affiliate_wage_annual) ~ "missing_employee_base",
        TRUE ~ "missing_employee_and_wage"
      ),
      affiliate_wage_stale_flag = !is.na(affiliate_wage_year_gap) &
        affiliate_wage_year_gap > 5,
      affiliate_wage_very_stale_flag = !is.na(affiliate_wage_year_gap) &
        affiliate_wage_year_gap > 10,
      affiliate_cit_top_all_unit = affiliate_cit_top_all / 100,
      affiliate_cit_standard_unit = affiliate_cit_standard / 100,
      parent_cit_top_all_unit = parent_cit_top_all / 100,
      parent_cit_standard_unit = parent_cit_standard / 100,
      profit_panelai_uncorrected = profit_panelai,
      domestic_correction_rate_static_benchmark = case_when(
        parent == "USA" ~ 0.54,
        parent == "NLD" ~ 0.16,
        TRUE ~ 0.324
      ),
      domestic_correction_rate_static_aggressive = case_when(
        parent == "USA" ~ 0.54,
        parent == "NLD" ~ 0.16,
        TRUE ~ 0.555
      ),
      domestic_correction_rate_baseline = rho_hat_pt,
      domestic_correction_rate_low = rho_lo_pt,
      domestic_correction_rate_high = rho_hi_pt,
      domestic_correction_rate_aggressive = rho_hi_pt,
      profit_panelai_corrected_preferred = case_when(
        !is.na(profit_adj_panelai) ~ profit_adj_panelai,
        is_domestic ~ profit_panelai * (1 - rho_hat_pt),
        TRUE ~ profit_panelai
      ),
      profit_panelai_corrected_low = case_when(
        !is.na(profit_adj_panelai) ~ profit_adj_panelai,
        is_domestic ~ profit_panelai * (1 - rho_lo_pt),
        TRUE ~ profit_panelai
      ),
      profit_panelai_corrected_high = case_when(
        !is.na(profit_adj_panelai) ~ profit_adj_panelai,
        is_domestic ~ profit_panelai * (1 - rho_hi_pt),
        TRUE ~ profit_panelai
      ),
      profit_panelai_corrected_static_benchmark = case_when(
        !is.na(profit_adj_panelai) ~ profit_adj_panelai,
        is_domestic ~ profit_panelai * (1 - domestic_correction_rate_static_benchmark),
        TRUE ~ profit_panelai
      ),
      profit_panelai_corrected_static_aggressive = case_when(
        !is.na(profit_adj_panelai) ~ profit_adj_panelai,
        is_domestic ~ profit_panelai * (1 - domestic_correction_rate_static_aggressive),
        TRUE ~ profit_panelai
      ),
      # Compatibility aliases used by later diagnostics. The baseline branch is
      # now the hybrid parent-year reconciliation, and the aggressive branch is
      # the upper end of the model interval.
      profit_panelai_corrected_baseline = profit_panelai_corrected_preferred,
      profit_panelai_corrected_aggressive = profit_panelai_corrected_high,
      profit_correction_source = case_when(
        !is.na(profit_adj_panelai) ~ "observed_adjusted",
        is_domestic & profit_reconciliation_support_class == "anchored_model" ~
          "anchored_model",
        is_domestic & profit_reconciliation_support_class == "parity_shrinkage" ~
          "parity_shrinkage",
        is_domestic & profit_reconciliation_support_class == "fallback_prior" ~
          "fallback_prior",
        is_domestic ~ "anchored_model",
        TRUE ~ "uncorrected_foreign"
      ),
      profit_correction_source_baseline = profit_correction_source,
      profit_correction_source_aggressive = case_when(
        !is.na(profit_adj_panelai) ~ "observed_adjusted",
        is_domestic ~ "model_high_interval",
        TRUE ~ "uncorrected_foreign"
      ),
      profit_correction_rate_preferred = safe_divide(
        profit_panelai_uncorrected - profit_panelai_corrected_preferred,
        profit_panelai_uncorrected
      ),
      profit_correction_rate_low = safe_divide(
        profit_panelai_uncorrected - profit_panelai_corrected_low,
        profit_panelai_uncorrected
      ),
      profit_correction_rate_high = safe_divide(
        profit_panelai_uncorrected - profit_panelai_corrected_high,
        profit_panelai_uncorrected
      ),
      profit_correction_rate_static_benchmark = safe_divide(
        profit_panelai_uncorrected - profit_panelai_corrected_static_benchmark,
        profit_panelai_uncorrected
      ),
      profit_correction_rate_baseline = profit_correction_rate_preferred,
      profit_correction_rate_aggressive = profit_correction_rate_high,
      analysis_profit_base = profit_panelai_corrected_preferred,
      etr_panelai_raw_uncorrected = if_else(
        !is.na(profit_panelai) & profit_panelai > 0,
        tax_accrued_panelai / profit_panelai,
        NA_real_
      ),
      etr_panelai_raw = if_else(
        !is.na(analysis_profit_base) & analysis_profit_base > 0,
        tax_accrued_panelai / analysis_profit_base,
        NA_real_
      ),
      # Stage 1 bounded ETR: clip to [0, affiliate_cit_rate + ZETA] for use as
      # the mean anchor in the constrained-Beta percentile fit.
      # Negative ETRs with magnitude below ZETA are treated as rounding noise
      # and collapsed to 0; ETRs below -ZETA are flagged as loss-carryforward
      # cells and propagate NA to Stage 1 so that the hybrid selector falls
      # through to the best available branch.
      etr_panelai_stage1 = case_when(
        is.na(etr_panelai_raw) ~ NA_real_,
        etr_panelai_raw < -ZETA_LOSS_OFFSET ~ NA_real_,
        etr_panelai_raw < 0 ~ 0,
        !is.na(affiliate_cit_top_all_unit) &
          etr_panelai_raw > affiliate_cit_top_all_unit + ZETA_LOSS_OFFSET ~
          affiliate_cit_top_all_unit + ZETA_LOSS_OFFSET,
        !is.na(affiliate_cit_standard_unit) &
          etr_panelai_raw > affiliate_cit_standard_unit + ZETA_LOSS_OFFSET ~
          affiliate_cit_standard_unit + ZETA_LOSS_OFFSET,
        etr_panelai_raw > 1 ~ 1,
        TRUE ~ etr_panelai_raw
      ),
      etr_panelai_stage1_adjustment = case_when(
        is.na(etr_panelai_raw) ~ "missing",
        etr_panelai_raw < -ZETA_LOSS_OFFSET ~ "dropped_loss_carryforward",
        etr_panelai_raw < 0 ~ "negative_noise_to_zero",
        !is.na(affiliate_cit_top_all_unit) &
          etr_panelai_raw > affiliate_cit_top_all_unit + ZETA_LOSS_OFFSET ~
          "above_cit_capped_top_all",
        !is.na(affiliate_cit_standard_unit) &
          etr_panelai_raw > affiliate_cit_standard_unit + ZETA_LOSS_OFFSET ~
          "above_cit_capped_standard",
        etr_panelai_raw > 1 ~ "above_one_capped",
        TRUE ~ "unchanged"
      ),
      # Regression-input ETR (Section sec:estimation_robustness). Harder
      # bounds to keep the log-regression well-behaved: drop anything outside
      # [-ZETA, 1 + ZETA] before the 1st and 99th percentile winsorisation is
      # applied inside the estimation script.
      etr_panelai_reg_eligible = !is.na(etr_panelai_raw) &
        etr_panelai_raw >= -ZETA_LOSS_OFFSET &
        etr_panelai_raw <= 1 + ZETA_LOSS_OFFSET,
      etr_panelai_reg = if_else(etr_panelai_reg_eligible, etr_panelai_raw, NA_real_),
      affiliate_cit_rate = coalesce(affiliate_cit_top_all, affiliate_cit_standard),
      affiliate_cit_rate_unit = coalesce(
        affiliate_cit_top_all_unit,
        affiliate_cit_standard_unit
      ),
      parent_cit_rate = coalesce(parent_cit_top_all, parent_cit_standard),
      parent_cit_rate_unit = coalesce(
        parent_cit_top_all_unit,
        parent_cit_standard_unit
      ),
      zero_profit_panelai_flag = !is.na(profit_panelai) & profit_panelai == 0,
      below_gmt_on_average_flag = !is.na(etr_panelai_raw) & etr_panelai_raw < GMT_RATE,
      etr_negative_flag = !is.na(etr_panelai_raw) & etr_panelai_raw < 0,
      etr_above_one_flag = !is.na(etr_panelai_raw) & etr_panelai_raw > 1,
      has_panelai_percentiles = !if_any(all_of(PANELAI_PERCENTILES), is.na),
      has_t_fallback_percentiles = !if_any(all_of(T_PERCENTILES), is.na),
      has_any_percentile_set = has_panelai_percentiles | has_t_fallback_percentiles,
      has_t4_low_bracket = !is.na(t4_low_profit),
      t4_low_profit_share_panelai = safe_divide(t4_low_profit, profit_panelai),
      # Table III groups entities by the parent-MNE ETR, not by the subsidiary
      # ETR used in Table I. The below-15 numerator is therefore not a subset of
      # bilateral Panel A-I profit, so this object is a loose ratio diagnostic,
      # not a bounded share.
      t3_low_profit_ratio_to_panelai = safe_divide(t3_low_profit, profit_panelai),
      t3_low_ratio_above_one_flag = !is.na(t3_low_profit_ratio_to_panelai) &
        t3_low_profit_ratio_to_panelai > 1,
      has_behavioral_estimation_inputs = is_main_estimation_year &
        !is.na(analysis_profit_base) & analysis_profit_base > 0 &
        !is.na(payroll_sbie) & payroll_sbie > 0 &
        !is.na(assets_sbie) & assets_sbie >= 0 &
        !is.na(etr_panelai_reg) &
        etr_panelai_reg_eligible,
      has_stage1_percentile_inputs = has_behavioral_estimation_inputs &
        has_any_percentile_set,
      has_stage1_hybrid_inputs = has_behavioral_estimation_inputs &
        (has_any_percentile_set | has_t4_low_bracket),
      has_stage1_crossval_inputs = has_behavioral_estimation_inputs &
        has_any_percentile_set & has_t4_low_bracket,
      has_estimation_inputs = has_behavioral_estimation_inputs,
      bspi_tier_raw = case_when(
        has_t4_low_bracket ~ "direct_t4",
        has_any_percentile_set ~ "percentile_fit",
        year %in% BSPI_IMPUTE_YEARS ~ "shape_transport_candidate",
        TRUE ~ "avg_only"
      )
    )

  assert_unique_keys(panel, c("parent", "affiliate", "year"), "final base panel")

  bspi_anchor_affiliates <- t4_brackets_by_affiliate_year |>
    filter(year %in% BSPI_ANCHOR_YEARS, !is.na(profit), profit > 0) |>
    distinct(affiliate) |>
    pull(affiliate)

  panel <- panel |>
    mutate(
      bspi_has_anchor = affiliate %in% bspi_anchor_affiliates,
      bspi_tier = case_when(
        bspi_tier_raw == "shape_transport_candidate" & bspi_has_anchor
        ~ "shape_transport",
        bspi_tier_raw == "shape_transport_candidate" & !bspi_has_anchor
        ~ "avg_only",
        TRUE
        ~ bspi_tier_raw
      )
    ) |>
    select(-bspi_tier_raw)


  # 5. Sectoral FATS, EUKLEMS and BEA sidecars for later SBIE work
  fats_geo_map <- tribble(
    ~geo, ~affiliate,
    "AT", "AUT", "BE", "BEL", "BG", "BGR", "CY", "CYP", "CZ", "CZE",
    "DE", "DEU", "DK", "DNK", "EE", "EST", "EL", "GRC", "ES", "ESP",
    "FI", "FIN", "FR", "FRA", "HR", "HRV", "HU", "HUN", "IE", "IRL",
    "IT", "ITA", "LT", "LTU", "LU", "LUX", "LV", "LVA", "MT", "MLT",
    "NL", "NLD", "PL", "POL", "PT", "PRT", "RO", "ROU", "SE", "SWE",
    "SI", "SVN", "SK", "SVK"
  )

  fats_leaf_sectors <- c(
    "B", "C10-C12", "C13-C15", "C16-C18", "C19", "C20", "C21",
    "C22-C23", "C24-C25", "C26", "C27", "C28", "C29-C30",
    "C31-C32", "C33", "D", "E", "F", "G", "H49", "H50", "H51",
    "H52-H53", "I", "J58", "J59-J60", "J61", "J62-J63", "K",
    "L", "M69-M71", "M72", "M73-M75", "N77", "N78-N82", "P",
    "Q86", "Q87-Q88", "R", "S95-S96"
  )

  fats_to_euklems_map <- tribble(
    ~nace_r2, ~euklems_nace_r2, ~euklems_mapping_tier,
    "B", "B", "direct",
    "C10-C12", "C10-C12", "direct",
    "C13-C15", "C13-C15", "direct",
    "C16-C18", "C16-C18", "direct",
    "C19", "C19", "direct",
    "C20", "C20", "direct",
    "C21", "C21", "direct",
    "C22-C23", "C22-C23", "direct",
    "C24-C25", "C24-C25", "direct",
    "C26", "C26", "direct",
    "C27", "C27", "direct",
    "C28", "C28", "direct",
    "C29-C30", "C29-C30", "direct",
    "C31-C32", "C31-C33", "allocated_from_broader_stock",
    "C33", "C31-C33", "allocated_from_broader_stock",
    "D", "D", "direct",
    "E", "E", "direct",
    "F", "F", "direct",
    "G", "G", "direct",
    "H49", "H49", "direct",
    "H50", "H50", "direct",
    "H51", "H51", "direct",
    "H52-H53", "H52-H53", "custom_aggregate",
    "I", "I", "direct",
    "J58", "J58-J60", "allocated_from_broader_stock",
    "J59-J60", "J58-J60", "allocated_from_broader_stock",
    "J61", "J61", "direct",
    "J62-J63", "J62-J63", "direct",
    "K", "K", "direct",
    "L", "L", "direct",
    "M69-M71", "M", "allocated_from_broader_stock",
    "M72", "M", "allocated_from_broader_stock",
    "M73-M75", "M", "allocated_from_broader_stock",
    "N77", "N", "allocated_from_broader_stock",
    "N78-N82", "N", "allocated_from_broader_stock",
    "P", "P", "direct",
    "Q86", "Q86", "direct",
    "Q87-Q88", "Q87-Q88", "direct",
    "R", "R", "direct",
    "S95-S96", "S", "allocated_from_broader_stock"
  )

  sectoral_source_hierarchy <- tribble(
    ~bridge_component, ~source_rank, ~source_dataset, ~source_variable,
    ~source_role, ~implementation_rule,
    "liability_base", 1L, "OECD CbCR",
    "PROFIT, PROFIT_ADJ, TAX_ACCRUED, ASSETS, EMPLOYEES",
    "Only source used for the GMT liability base",
    "CbCR remains the parent-affiliate-year base; sectoral data only allocate country-level levels across sectors",
    "sectoral_payroll_share", 1L, "Eurostat inward FATS",
    "ind_expn_sal_ben_meur",
    "Preferred EU host-country sectoral payroll allocator",
    "Foreign-control WRL_REST leaf-sector personnel costs, normalised within affiliate-year",
    "sectoral_payroll_share", 2L, "Eurostat inward FATS",
    "ind_emp_nr",
    "Fallback payroll allocator where personnel costs are suppressed",
    "Employees scaled by observed personnel cost per employee in the same affiliate-year",
    "sectoral_payroll_share", 3L, "Eurostat inward FATS",
    "ind_nettur_meur",
    "Last payroll allocator where both personnel costs and employees are suppressed",
    "Turnover scaled by observed personnel-cost-to-turnover ratio in the same affiliate-year",
    "sectoral_asset_share", 1L, "EUKLEMS and INTANProd",
    "K_Tang",
    "Preferred sectoral tangible-asset allocator",
    paste0(
      "Used when EUKLEMS tangible-stock cells cover at least ",
      EUKLEMS_STOCK_COVERAGE_THRESHOLD * 100,
      " per cent of FATS turnover in the affiliate-year"
    ),
    "sectoral_asset_share", 2L, "Eurostat inward FATS",
    "ind_grsinv_tnca_meur",
    "Fallback tangible-asset allocator",
    "Gross investment in tangible non-current assets, with activity-scaled imputation for suppressed cells",
    "sectoral_profit_share", 1L, "Eurostat inward FATS",
    "ind_gos_meur",
    "Preferred sectoral profit allocator",
    "Positive gross operating surplus, normalised within affiliate-year",
    "sectoral_profit_share", 2L, "Eurostat inward FATS",
    "ind_av_meur",
    "Fallback profit allocator",
    "Positive value added scaled by the observed gross-operating-surplus-to-value-added ratio",
    "sectoral_profit_share", 3L, "Eurostat inward FATS",
    "ind_nettur_meur",
    "Last profit allocator",
    "Turnover scaled by the observed gross-operating-surplus-to-turnover ratio, or turnover shares when no surplus information is usable",
    "bea_validation", 99L, "BEA USDIA MOFA",
    "employment, compensation, ppe_expenditures, total_assets",
    "External U.S.-parent benchmark only",
    "Used to validate broad-sector shares; never replaces CbCR levels or the EU sectoral bridge"
  )

  sectoral_nace_crosswalk_rules <- fats_to_euklems_map |>
    mutate(
      fats_sector_level = "post_2021_fats_leaf_sector",
      euklems_crosswalk_rule = case_when(
        euklems_mapping_tier == "direct" ~
          "FATS and EUKLEMS sectors are aligned one-to-one",
        euklems_mapping_tier == "custom_aggregate" ~
          "EUKLEMS source sectors are summed to match the FATS sector",
        euklems_mapping_tier == "allocated_from_broader_stock" ~
          "Broader EUKLEMS stock is allocated across FATS child sectors using the FATS activity base",
        TRUE ~ "unclassified"
      )
    )

  bea_top_level_industries <- c(
    "Mining",
    "Manufacturing",
    "Wholesale trade",
    "Retail trade",
    "Information",
    "Finance and insurance",
    "Professional, scientific, and technical services",
    "Other industries"
  )

  bea_top_level_nace_map <- tribble(
    ~bea_sector_group, ~nace_r2,
    "Mining", "B",
    "Manufacturing", "C",
    "Trade", "G",
    "Information", "J",
    "Finance and insurance", "K",
    "Professional, scientific, and technical services", "M",
    "Other industries", NA_character_
  )

  standardise_nace <- function(x) str_replace_all(x, "_", "-")

  euklems_bridge_capital_direct <- euklems_sector_capital |>
    select(
      affiliate = jurisdiction,
      source_year = year,
      euklems_nace_r2 = nace_r2,
      euklems_k_tang,
      euklems_k_tang_nres,
      euklems_k_intang,
      euklems_k_gfcf,
      euklems_va_cp,
      euklems_intangible_share
    ) |>
    mutate(euklems_source_nace = euklems_nace_r2)

  euklems_bridge_capital_custom <- euklems_sector_capital |>
    filter(nace_r2 %in% c("H52", "H53")) |>
    group_by(jurisdiction, year) |>
    summarise(
      euklems_nace_r2 = "H52-H53",
      euklems_source_nace = paste(sort(unique(nace_r2)), collapse = "+"),
      euklems_k_tang = sum_or_na(euklems_k_tang),
      euklems_k_tang_nres = sum_or_na(euklems_k_tang_nres),
      euklems_k_intang = sum_or_na(euklems_k_intang),
      euklems_k_gfcf = sum_or_na(euklems_k_gfcf),
      euklems_va_cp = sum_or_na(euklems_va_cp),
      .groups = "drop"
    ) |>
    transmute(
      affiliate = jurisdiction,
      source_year = year,
      euklems_nace_r2,
      euklems_k_tang,
      euklems_k_tang_nres,
      euklems_k_intang,
      euklems_k_gfcf,
      euklems_va_cp,
      euklems_intangible_share = safe_divide(
        euklems_k_intang,
        euklems_k_tang + euklems_k_intang
      ),
      euklems_source_nace
    )

  euklems_bridge_capital <- bind_rows(
    euklems_bridge_capital_direct,
    euklems_bridge_capital_custom
  ) |>
    distinct(affiliate, source_year, euklems_nace_r2, .keep_all = TRUE)

  fats_foreign_sector_levels <- fats_post2021 |>
    filter(
      year >= 2021L, year %in% CORE_YEARS,
      geo %in% fats_geo_map$geo,
      c_ctrl == "WRL_REST"
    ) |>
    left_join(fats_geo_map, by = "geo") |>
    mutate(nace_r2 = standardise_nace(nace_r2)) |>
    filter(nace_r2 %in% fats_leaf_sectors) |>
    group_by(affiliate, year, nace_r2) |>
    summarise(
      fats_personnel_costs = sum_or_na(ind_expn_sal_ben_meur),
      fats_employees = sum_or_na(ind_emp_nr),
      fats_investment = sum_or_na(ind_grsinv_tnca_meur),
      fats_turnover = sum_or_na(ind_nettur_meur),
      fats_value_added = sum_or_na(ind_av_meur),
      fats_gos = sum_or_na(ind_gos_meur),
      .groups = "drop"
    ) |>
    left_join(fats_to_euklems_map, by = "nace_r2")

  if (any(is.na(fats_foreign_sector_levels$euklems_nace_r2))) {
    stop("FATS to EUKLEMS NACE map is incomplete")
  }

  euklems_nearest_year <- fats_foreign_sector_levels |>
    distinct(affiliate, year, euklems_nace_r2) |>
    left_join(euklems_bridge_capital,
      by = c("affiliate", "euklems_nace_r2"),
      relationship = "many-to-many"
    ) |>
    filter(!is.na(euklems_k_tang)) |>
    mutate(
      year_gap = abs(year - source_year),
      future_year = source_year > year
    ) |>
    arrange(affiliate, year, euklems_nace_r2, future_year, year_gap, desc(source_year)) |>
    group_by(affiliate, year, euklems_nace_r2) |>
    slice(1) |>
    ungroup()

  fats_sector_shares <- fats_post2021 |>
    filter(
      year >= 2021L, year %in% CORE_YEARS,
      geo %in% fats_geo_map$geo,
      c_ctrl == "WRL_REST"
    ) |>
    left_join(fats_geo_map, by = "geo") |>
    mutate(nace_r2 = standardise_nace(nace_r2)) |>
    filter(nace_r2 %in% fats_leaf_sectors) |>
    group_by(affiliate, year, nace_r2) |>
    summarise(
      fats_personnel_costs = sum_or_na(ind_expn_sal_ben_meur),
      fats_employees = sum_or_na(ind_emp_nr),
      fats_investment = sum_or_na(ind_grsinv_tnca_meur),
      fats_turnover = sum_or_na(ind_nettur_meur),
      fats_value_added = sum_or_na(ind_av_meur),
      fats_gos = sum_or_na(ind_gos_meur),
      .groups = "drop"
    ) |>
    left_join(fats_to_euklems_map, by = "nace_r2") |>
    left_join(euklems_nearest_year,
      by = c("affiliate", "year", "euklems_nace_r2")
    ) |>
    group_by(affiliate, year, euklems_nace_r2) |>
    mutate(
      euklems_allocation_base = coalesce(
        fats_investment, fats_turnover,
        fats_personnel_costs, fats_employees
      ),
      euklems_allocation_denom = sum(coalesce(euklems_allocation_base, 0),
        na.rm = TRUE
      ),
      euklems_family_weight = case_when(
        is.na(euklems_k_tang) ~ NA_real_,
        euklems_allocation_denom > 0 ~
          coalesce(euklems_allocation_base, 0) / euklems_allocation_denom,
        TRUE ~ 1 / n()
      ),
      euklems_k_tang_allocated = euklems_k_tang * euklems_family_weight,
      euklems_k_tang_nres_allocated = euklems_k_tang_nres * euklems_family_weight,
      euklems_k_intang_allocated = euklems_k_intang * euklems_family_weight
    ) |>
    ungroup() |>
    group_by(affiliate, year) |>
    mutate(
      fats_personnel_costs_positive = if_else(
        !is.na(fats_personnel_costs),
        pmax(fats_personnel_costs, 0),
        NA_real_
      ),
      fats_employees_positive = if_else(
        !is.na(fats_employees),
        pmax(fats_employees, 0),
        NA_real_
      ),
      fats_investment_positive = if_else(
        !is.na(fats_investment),
        pmax(fats_investment, 0),
        NA_real_
      ),
      fats_turnover_positive = if_else(
        !is.na(fats_turnover),
        pmax(fats_turnover, 0),
        NA_real_
      ),
      fats_value_added_positive = if_else(
        !is.na(fats_value_added),
        pmax(fats_value_added, 0),
        NA_real_
      ),
      fats_gos_positive = if_else(
        !is.na(fats_gos),
        pmax(fats_gos, 0),
        NA_real_
      ),
      fats_turnover_allocation_base = case_when(
        !is.na(fats_turnover_positive) ~ fats_turnover_positive,
        !is.na(fats_value_added_positive) ~ fats_value_added_positive,
        !is.na(fats_personnel_costs_positive) ~ fats_personnel_costs_positive,
        TRUE ~ NA_real_
      ),
      turnover_share_proxy_source = case_when(
        !is.na(fats_turnover_positive) ~ "fats_turnover",
        !is.na(fats_value_added_positive) ~ "fats_value_added_turnover_fallback",
        !is.na(fats_personnel_costs_positive) ~
          "fats_personnel_costs_turnover_fallback",
        TRUE ~ "missing_turnover_allocator"
      ),
      fats_turnover_share = normalise_share(fats_turnover_allocation_base),
      fats_employee_share = normalise_share(fats_employees_positive),
      payroll_employee_rows = !is.na(fats_personnel_costs_positive) &
        !is.na(fats_employees_positive) & fats_employees_positive > 0,
      payroll_turnover_rows = !is.na(fats_personnel_costs_positive) &
        !is.na(fats_turnover_allocation_base) &
        fats_turnover_allocation_base > 0,
      fats_payroll_per_employee = safe_divide(
        sum(fats_personnel_costs_positive[payroll_employee_rows], na.rm = TRUE),
        sum(fats_employees_positive[payroll_employee_rows], na.rm = TRUE)
      ),
      fats_payroll_to_turnover = safe_divide(
        sum(fats_personnel_costs_positive[payroll_turnover_rows], na.rm = TRUE),
        sum(fats_turnover_allocation_base[payroll_turnover_rows], na.rm = TRUE)
      ),
      fats_payroll_allocation_base = case_when(
        !is.na(fats_personnel_costs_positive) ~ fats_personnel_costs_positive,
        !is.na(fats_employees_positive) &
          !is.na(fats_payroll_per_employee) ~
          fats_employees_positive * fats_payroll_per_employee,
        !is.na(fats_turnover_allocation_base) &
          !is.na(fats_payroll_to_turnover) ~
          fats_turnover_allocation_base * fats_payroll_to_turnover,
        TRUE ~ NA_real_
      ),
      payroll_share_proxy_source = case_when(
        !is.na(fats_personnel_costs_positive) ~ "fats_personnel_costs",
        !is.na(fats_employees_positive) &
          !is.na(fats_payroll_per_employee) ~
          "fats_employees_scaled_to_personnel_costs",
        !is.na(fats_turnover_allocation_base) &
          !is.na(fats_payroll_to_turnover) ~
          "fats_turnover_scaled_to_personnel_costs",
        TRUE ~ "missing_payroll_allocator"
      ),
      fats_payroll_share = normalise_share(fats_payroll_allocation_base),
      investment_turnover_rows = !is.na(fats_investment_positive) &
        !is.na(fats_turnover_allocation_base) &
        fats_turnover_allocation_base > 0,
      investment_payroll_rows = !is.na(fats_investment_positive) &
        !is.na(fats_payroll_allocation_base) &
        fats_payroll_allocation_base > 0,
      fats_investment_to_turnover = safe_divide(
        sum(fats_investment_positive[investment_turnover_rows], na.rm = TRUE),
        sum(fats_turnover_allocation_base[investment_turnover_rows], na.rm = TRUE)
      ),
      fats_investment_to_payroll = safe_divide(
        sum(fats_investment_positive[investment_payroll_rows], na.rm = TRUE),
        sum(fats_payroll_allocation_base[investment_payroll_rows], na.rm = TRUE)
      ),
      fats_investment_allocation_base = case_when(
        !is.na(fats_investment_positive) ~ fats_investment_positive,
        !is.na(fats_turnover_allocation_base) &
          !is.na(fats_investment_to_turnover) ~
          fats_turnover_allocation_base * fats_investment_to_turnover,
        !is.na(fats_payroll_allocation_base) &
          !is.na(fats_investment_to_payroll) ~
          fats_payroll_allocation_base * fats_investment_to_payroll,
        TRUE ~ NA_real_
      ),
      investment_share_proxy_source = case_when(
        !is.na(fats_investment_positive) ~ "fats_gross_investment_flow",
        !is.na(fats_turnover_allocation_base) &
          !is.na(fats_investment_to_turnover) ~
          "fats_turnover_scaled_to_investment_flow",
        !is.na(fats_payroll_allocation_base) &
          !is.na(fats_investment_to_payroll) ~
          "fats_payroll_scaled_to_investment_flow",
        TRUE ~ "missing_investment_allocator"
      ),
      fats_investment_share = normalise_share(fats_investment_allocation_base),
      fats_gos_denom = sum(fats_gos_positive, na.rm = TRUE),
      fats_value_added_denom = sum(fats_value_added_positive, na.rm = TRUE),
      gos_value_added_rows = !is.na(fats_gos_positive) &
        !is.na(fats_value_added_positive) & fats_value_added_positive > 0,
      gos_turnover_rows = !is.na(fats_gos_positive) &
        !is.na(fats_turnover_allocation_base) &
        fats_turnover_allocation_base > 0,
      fats_gos_to_value_added = safe_divide(
        sum(fats_gos_positive[gos_value_added_rows], na.rm = TRUE),
        sum(fats_value_added_positive[gos_value_added_rows], na.rm = TRUE)
      ),
      fats_gos_to_turnover = safe_divide(
        sum(fats_gos_positive[gos_turnover_rows], na.rm = TRUE),
        sum(fats_turnover_allocation_base[gos_turnover_rows], na.rm = TRUE)
      ),
      sectoral_profit_allocation_base = case_when(
        fats_gos_denom > 0 & !is.na(fats_gos_positive) ~
          fats_gos_positive,
        fats_gos_denom > 0 & is.na(fats_gos_positive) &
          !is.na(fats_value_added_positive) &
          !is.na(fats_gos_to_value_added) ~
          fats_value_added_positive * fats_gos_to_value_added,
        fats_gos_denom > 0 & is.na(fats_gos_positive) &
          !is.na(fats_turnover_allocation_base) &
          !is.na(fats_gos_to_turnover) ~
          fats_turnover_allocation_base * fats_gos_to_turnover,
        fats_value_added_denom > 0 & !is.na(fats_value_added_positive) ~
          fats_value_added_positive,
        !is.na(fats_turnover_allocation_base) ~
          fats_turnover_allocation_base,
        TRUE ~ NA_real_
      ),
      profit_share_proxy_source = case_when(
        fats_gos_denom > 0 & !is.na(fats_gos_positive) ~
          "fats_gross_operating_surplus",
        fats_gos_denom > 0 & is.na(fats_gos_positive) &
          !is.na(fats_value_added_positive) &
          !is.na(fats_gos_to_value_added) ~
          "fats_value_added_scaled_to_gos",
        fats_gos_denom > 0 & is.na(fats_gos_positive) &
          !is.na(fats_turnover_allocation_base) &
          !is.na(fats_gos_to_turnover) ~
          "fats_turnover_scaled_to_gos",
        fats_value_added_denom > 0 & !is.na(fats_value_added_positive) ~
          "fats_value_added",
        !is.na(fats_turnover_allocation_base) ~
          "fats_turnover",
        TRUE ~ "missing_profit_allocator"
      ),
      fats_gos_share = normalise_share(fats_gos_positive),
      fats_value_added_share = normalise_share(fats_value_added_positive),
      sectoral_profit_share = normalise_share(sectoral_profit_allocation_base),
      euklems_stock_coverage_turnover_share = sum(
        if_else(!is.na(euklems_k_tang_allocated), fats_turnover_share, 0),
        na.rm = TRUE
      ),
      euklems_stock_to_investment_ratio = safe_divide(
        euklems_k_tang_allocated,
        fats_investment_allocation_base
      ),
      euklems_median_stock_to_investment = median(
        euklems_stock_to_investment_ratio[
          is.finite(euklems_stock_to_investment_ratio) &
            euklems_stock_to_investment_ratio > 0
        ],
        na.rm = TRUE
      ),
      euklems_median_stock_to_investment = if_else(
        is.nan(euklems_median_stock_to_investment),
        NA_real_,
        euklems_median_stock_to_investment
      ),
      euklems_k_tang_gapfilled = case_when(
        !is.na(euklems_k_tang_allocated) ~ euklems_k_tang_allocated,
        euklems_stock_coverage_turnover_share >=
          EUKLEMS_STOCK_COVERAGE_THRESHOLD &
          !is.na(euklems_median_stock_to_investment) &
          !is.na(fats_investment_allocation_base) &
          fats_investment_allocation_base > 0 ~
          euklems_median_stock_to_investment *
            fats_investment_allocation_base,
        TRUE ~ NA_real_
      ),
      euklems_stock_available = sum(euklems_k_tang_gapfilled, na.rm = TRUE) > 0,
      use_euklems_asset_share = euklems_stock_available &
        euklems_stock_coverage_turnover_share >=
          EUKLEMS_STOCK_COVERAGE_THRESHOLD,
      euklems_tangible_asset_share = if_else(
        use_euklems_asset_share,
        safe_divide(
          euklems_k_tang_gapfilled,
          sum(euklems_k_tang_gapfilled, na.rm = TRUE)
        ),
        NA_real_
      ),
      sectoral_asset_share = if_else(
        use_euklems_asset_share,
        euklems_tangible_asset_share,
        fats_investment_share
      ),
      asset_cell_proxy_source = case_when(
        use_euklems_asset_share & !is.na(euklems_k_tang_allocated) ~
          "euklems_k_tang_stock",
        use_euklems_asset_share & is.na(euklems_k_tang_allocated) &
          !is.na(euklems_k_tang_gapfilled) ~
          "euklems_k_tang_gapfilled_from_fats_investment",
        !use_euklems_asset_share ~ investment_share_proxy_source,
        TRUE ~ "missing_asset_allocator"
      ),
      asset_share_proxy_source = case_when(
        use_euklems_asset_share & any(is.na(euklems_k_tang_allocated)) ~
          "euklems_k_tang_stock_with_fats_investment_gapfill",
        use_euklems_asset_share ~ "euklems_k_tang_stock",
        any(investment_share_proxy_source != "fats_gross_investment_flow",
          na.rm = TRUE
        ) ~
          "fats_gross_investment_flow_with_activity_gapfill",
        TRUE ~ "fats_gross_investment_flow_fallback"
      )
    ) |>
    ungroup() |>
    select(
      affiliate, year, nace_r2, euklems_nace_r2, euklems_mapping_tier,
      euklems_source_nace,
      euklems_source_year = source_year, year_gap,
      fats_personnel_costs, fats_employees, fats_investment, fats_turnover,
      fats_value_added, fats_gos,
      fats_payroll_allocation_base, payroll_share_proxy_source,
      fats_investment_allocation_base, investment_share_proxy_source,
      fats_turnover_allocation_base, turnover_share_proxy_source,
      sectoral_profit_allocation_base,
      fats_payroll_share, fats_employee_share, fats_investment_share,
      fats_turnover_share, fats_gos_share, fats_value_added_share,
      sectoral_profit_share, profit_share_proxy_source,
      euklems_k_tang, euklems_k_tang_nres, euklems_k_intang,
      euklems_k_tang_allocated, euklems_k_tang_nres_allocated,
      euklems_k_intang_allocated, euklems_k_tang_gapfilled,
      euklems_median_stock_to_investment, euklems_intangible_share,
      euklems_stock_coverage_turnover_share, use_euklems_asset_share,
      euklems_tangible_asset_share, sectoral_asset_share,
      asset_cell_proxy_source, asset_share_proxy_source
    )

  assert_unique_keys(
    fats_sector_shares, c("affiliate", "year", "nace_r2"),
    "FATS sector shares"
  )

  bea_us_parent_totals <- bea_us_mne_country_industry |>
    filter(
      jurisdiction %in% EU27_ISO3,
      !is.na(value),
      bea_industry == "All industries"
    ) |>
    transmute(
      measure,
      year,
      affiliate = jurisdiction,
      bea_all_industries_value = value
    )

  assert_unique_keys(
    bea_us_parent_totals,
    c("measure", "year", "affiliate"),
    "BEA all-industries totals"
  )

  bea_us_parent_sector_benchmark <- bea_us_mne_country_industry |>
    filter(
      jurisdiction %in% EU27_ISO3,
      !is.na(value),
      bea_industry %in% bea_top_level_industries
    ) |>
    mutate(
      affiliate = jurisdiction,
      bea_sector_group = case_when(
        bea_industry %in% c("Wholesale trade", "Retail trade") ~ "Trade",
        TRUE ~ bea_industry
      )
    ) |>
    group_by(measure, year, country_or_region, affiliate, bea_sector_group) |>
    summarise(
      value = sum(value, na.rm = TRUE),
      bea_industries = paste(sort(unique(bea_industry)), collapse = "; "),
      suppressed_rows = sum(!is.na(suppression_code)),
      .groups = "drop"
    ) |>
    left_join(bea_top_level_nace_map, by = "bea_sector_group") |>
    left_join(bea_us_parent_totals, by = c("measure", "year", "affiliate")) |>
    group_by(measure, year, affiliate) |>
    mutate(
      bea_share_denominator = if_else(
        !is.na(bea_all_industries_value),
        bea_all_industries_value,
        sum(value, na.rm = TRUE)
      ),
      bea_top_level_value_sum = sum(value, na.rm = TRUE),
      bea_top_level_coverage_ratio = safe_divide(
        bea_top_level_value_sum,
        bea_share_denominator
      ),
      bea_sector_share = safe_divide(value, bea_share_denominator),
      bea_sector_share_mapped = !is.na(nace_r2),
      bea_sector_level = "top_level_non_overlapping"
    ) |>
    ungroup() |>
    arrange(measure, year, affiliate, bea_sector_group)

  assert_unique_keys(
    bea_us_parent_sector_benchmark,
    c("measure", "year", "affiliate", "bea_sector_group"),
    "BEA US-parent sector benchmark"
  )

  global_intan_eu27_macro <- global_intan_annual |>
    filter(jurisdiction %in% EU27_ISO3) |>
    rename(affiliate = jurisdiction) |>
    select(
      affiliate, year,
      global_intan_i_gfcf,
      global_intan_i_intan,
      global_intan_intangible_investment_share,
      global_intan_non_natacc_share
    )


  # 6. Diagnostics and outputs

  panel_summary <- tibble(
    metric = c(
      "rows",
      "parent_jurisdictions",
      "affiliate_jurisdictions",
      "years",
      "domestic_rows",
      "eu27_affiliate_rows",
      "rows_with_wage_benchmark",
      "rows_with_employee_base",
      "rows_with_employee_plausibility_correction",
      "rows_with_payroll_proxy",
      "rows_with_wage_gap_over_5_years",
      "rows_with_wage_gap_over_10_years",
      "rows_with_affiliate_cit_rate",
      "rows_with_affiliate_cit_top_all",
      "rows_with_baseline_profit_correction",
      "rows_with_observed_profit_adj",
      "rows_with_t4_low_bracket",
      "rows_ready_for_behavioral_estimation",
      "rows_ready_for_stage1_percentiles",
      "rows_ready_for_stage1_hybrid",
      "rows_ready_for_stage1_crossval",
      "rows_bspi_direct_t4",
      "rows_bspi_percentile_fit",
      "rows_bspi_shape_transport",
      "rows_bspi_avg_only",
      "rows_t3_ratio_above_one",
      "rows_etr_negative_noise_recoded",
      "rows_etr_loss_carryforward_dropped",
      "rows_etr_above_cit_capped"
    ),
    value = c(
      nrow(panel),
      n_distinct(panel$parent),
      n_distinct(panel$affiliate),
      paste(range(panel$year), collapse = "-"),
      sum(panel$is_domestic, na.rm = TRUE),
      sum(panel$affiliate_is_eu27, na.rm = TRUE),
      sum(!is.na(panel$affiliate_wage_annual)),
      sum(!is.na(panel$employees_sbie)),
      sum(panel$employees_sbie_correction_flag, na.rm = TRUE),
      sum(!is.na(panel$payroll_sbie)),
      sum(panel$affiliate_wage_stale_flag, na.rm = TRUE),
      sum(panel$affiliate_wage_very_stale_flag, na.rm = TRUE),
      sum(!is.na(panel$affiliate_cit_rate)),
      sum(!is.na(panel$affiliate_cit_top_all)),
      sum(panel$profit_correction_source_baseline != "uncorrected_foreign", na.rm = TRUE),
      sum(panel$profit_adj_observed_panelai, na.rm = TRUE),
      sum(panel$has_t4_low_bracket, na.rm = TRUE),
      sum(panel$has_behavioral_estimation_inputs, na.rm = TRUE),
      sum(panel$has_stage1_percentile_inputs, na.rm = TRUE),
      sum(panel$has_stage1_hybrid_inputs, na.rm = TRUE),
      sum(panel$has_stage1_crossval_inputs, na.rm = TRUE),
      sum(panel$bspi_tier == "direct_t4", na.rm = TRUE),
      sum(panel$bspi_tier == "percentile_fit", na.rm = TRUE),
      sum(panel$bspi_tier == "shape_transport", na.rm = TRUE),
      sum(panel$bspi_tier == "avg_only", na.rm = TRUE),
      sum(panel$t3_low_ratio_above_one_flag, na.rm = TRUE),
      sum(panel$etr_panelai_stage1_adjustment == "negative_noise_to_zero",
        na.rm = TRUE
      ),
      sum(panel$etr_panelai_stage1_adjustment == "dropped_loss_carryforward",
        na.rm = TRUE
      ),
      sum(panel$etr_panelai_stage1_adjustment %in%
        c(
          "above_cit_capped_top_all", "above_cit_capped_standard",
          "above_one_capped"
        ), na.rm = TRUE)
    )
  )

  payroll_diag <- panel |>
    group_by(year) |>
    summarise(
      rows = n(),
      rows_with_employee_base = sum(!is.na(employees_sbie)),
      rows_with_employee_correction = sum(employees_sbie_correction_flag, na.rm = TRUE),
      rows_with_wage_benchmark = sum(!is.na(affiliate_wage_annual)),
      rows_with_payroll_proxy = sum(!is.na(payroll_sbie)),
      rows_with_positive_payroll_proxy = sum(payroll_sbie > 0, na.rm = TRUE),
      source_panelaii = sum(employees_sbie_source == "panelaii", na.rm = TRUE),
      source_panelai = sum(employees_sbie_source == "panelai", na.rm = TRUE),
      source_aggregate = sum(employees_sbie_source == "aggregate", na.rm = TRUE),
      wage_from_oecd = sum(str_detect(affiliate_wage_source, "^oecd_"), na.rm = TRUE),
      wage_from_ilo = sum(str_detect(affiliate_wage_source, "^ilo_"), na.rm = TRUE),
      proxy_payroll_sum = sum(payroll_sbie, na.rm = TRUE),
      .groups = "drop"
    )

  payroll_plausibility_diag <- panel |>
    group_by(year) |>
    summarise(
      rows = n(),
      rows_with_raw_payroll_proxy = sum(!is.na(payroll_sbie_raw_uncapped)),
      rows_with_corrected_payroll_proxy = sum(!is.na(payroll_sbie)),
      rows_with_payroll_screen = sum(employees_sbie_correction_flag, na.rm = TRUE),
      raw_payroll_proxy_sum = sum(payroll_sbie_raw_uncapped, na.rm = TRUE),
      corrected_payroll_proxy_sum = sum(payroll_sbie, na.rm = TRUE),
      removed_payroll_proxy_sum = sum(payroll_sbie_raw_uncapped - payroll_sbie, na.rm = TRUE),
      .groups = "drop"
    )

  accumulated_earnings_diag <- panel |>
    group_by(year) |>
    summarise(
      rows = n(),
      panelai_nonmissing = sum(!is.na(accumulated_earnings_panelai)),
      panelai_negative = sum(accumulated_earnings_panelai < 0, na.rm = TRUE),
      panelaii_nonmissing = sum(!is.na(accumulated_earnings_panelaii)),
      panelaii_negative = sum(accumulated_earnings_panelaii < 0, na.rm = TRUE),
      aggregate_nonmissing = sum(!is.na(accumulated_earnings)),
      aggregate_negative = sum(accumulated_earnings < 0, na.rm = TRUE),
      .groups = "drop"
    )

  employee_plausibility_diag <- panel |>
    group_by(year) |>
    summarise(
      rows = n(),
      rows_with_employee_base = sum(!is.na(employees_sbie_raw)),
      rows_with_entity_cap = sum(!is.na(employees_sbie_entity_cap)),
      rows_with_population_cap = sum(!is.na(employees_sbie_population_cap)),
      rows_capped = sum(employees_sbie_correction_flag, na.rm = TRUE),
      raw_employees_sum = sum(employees_sbie_raw, na.rm = TRUE),
      corrected_employees_sum = sum(employees_sbie, na.rm = TRUE),
      removed_employees_sum = sum(employees_sbie_raw - employees_sbie, na.rm = TRUE),
      .groups = "drop"
    )

  wage_match_quality_diag <- panel |>
    mutate(
      wage_gap_band = case_when(
        is.na(affiliate_wage_year_gap) ~ "missing_wage",
        affiliate_wage_year_gap <= 1 ~ "gap_0_1",
        affiliate_wage_year_gap <= 3 ~ "gap_2_3",
        affiliate_wage_year_gap <= 5 ~ "gap_4_5",
        affiliate_wage_year_gap <= 10 ~ "gap_6_10",
        TRUE ~ "gap_11_plus"
      )
    ) |>
    group_by(year, wage_gap_band) |>
    summarise(
      rows = n(),
      behavioral_rows = sum(has_behavioral_estimation_inputs, na.rm = TRUE),
      stage1_hybrid_rows = sum(has_stage1_hybrid_inputs, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(year, wage_gap_band)

  profit_correction_diag <- panel |>
    group_by(year, profit_correction_source_baseline) |>
    summarise(
      rows = n(),
      uncorrected_profit = sum(profit_panelai_uncorrected, na.rm = TRUE),
      corrected_profit = sum(profit_panelai_corrected_baseline, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(year, profit_correction_source_baseline)

  missingness_diag <- panel |>
    group_by(year) |>
    summarise(
      missing_affiliate_cit_rate = mean(is.na(affiliate_cit_rate)),
      missing_affiliate_cit_top_all = mean(is.na(affiliate_cit_top_all)),
      missing_affiliate_gdp = mean(is.na(affiliate_gdp_pc_usd)),
      missing_affiliate_pop = mean(is.na(affiliate_population)),
      missing_wage = mean(is.na(affiliate_wage_annual)),
      missing_payroll_sbie = mean(is.na(payroll_sbie)),
      missing_assets_sbie = mean(is.na(assets_sbie)),
      missing_any_percentiles = mean(!has_any_percentile_set),
      .groups = "drop"
    )

  stage_readiness_diag <- panel |>
    group_by(year) |>
    summarise(
      rows = n(),
      behavioral_estimation = sum(has_behavioral_estimation_inputs, na.rm = TRUE),
      stage1_percentiles = sum(has_stage1_percentile_inputs, na.rm = TRUE),
      stage1_hybrid = sum(has_stage1_hybrid_inputs, na.rm = TRUE),
      stage1_crossval = sum(has_stage1_crossval_inputs, na.rm = TRUE),
      etr_negative = sum(etr_negative_flag, na.rm = TRUE),
      etr_above_one = sum(etr_above_one_flag, na.rm = TRUE),
      .groups = "drop"
    )

  affiliate_year_stage1_diag <- panel |>
    group_by(year, affiliate) |>
    summarise(
      any_panelai_percentiles = any(has_panelai_percentiles, na.rm = TRUE),
      any_percentiles = any(has_any_percentile_set, na.rm = TRUE),
      any_t4 = any(has_t4_low_bracket, na.rm = TRUE),
      .groups = "drop"
    ) |>
    group_by(year) |>
    summarise(
      affiliate_years = n(),
      affiliate_years_panelai = sum(any_panelai_percentiles, na.rm = TRUE),
      affiliate_years_any_percentiles = sum(any_percentiles, na.rm = TRUE),
      affiliate_years_t4 = sum(any_t4, na.rm = TRUE),
      affiliate_years_overlap = sum(any_percentiles & any_t4, na.rm = TRUE),
      eu27_affiliate_years = sum(affiliate %in% EU27_ISO3),
      eu27_affiliate_years_panelai = sum(
        affiliate %in% EU27_ISO3 & any_panelai_percentiles,
        na.rm = TRUE
      ),
      eu27_affiliate_years_overlap = sum(
        affiliate %in% EU27_ISO3 & any_percentiles & any_t4,
        na.rm = TRUE
      ),
      .groups = "drop"
    )

  fats_diag <- fats_sector_shares |>
    group_by(affiliate, year) |>
    summarise(
      n_nace = n(),
      payroll_share_sum = sum(fats_payroll_share, na.rm = TRUE),
      employee_share_sum = sum(fats_employee_share, na.rm = TRUE),
      investment_share_sum = sum(fats_investment_share, na.rm = TRUE),
      turnover_share_sum = sum(fats_turnover_share, na.rm = TRUE),
      profit_share_sum = sum(sectoral_profit_share, na.rm = TRUE),
      asset_share_sum = sum(sectoral_asset_share, na.rm = TRUE),
      euklems_asset_share_sum = sum(euklems_tangible_asset_share, na.rm = TRUE),
      euklems_stock_coverage_turnover_share =
        first(euklems_stock_coverage_turnover_share),
      uses_euklems_asset_share = first(use_euklems_asset_share),
      n_missing_payroll = sum(is.na(fats_personnel_costs)),
      n_missing_payroll_share = sum(is.na(fats_payroll_share)),
      n_payroll_share_fallback = sum(
        payroll_share_proxy_source != "fats_personnel_costs",
        na.rm = TRUE
      ),
      n_missing_investment = sum(is.na(fats_investment)),
      n_missing_investment_share = sum(is.na(fats_investment_share)),
      n_investment_share_fallback = sum(
        investment_share_proxy_source != "fats_gross_investment_flow",
        na.rm = TRUE
      ),
      n_missing_euklems_stock = sum(is.na(euklems_k_tang_allocated)),
      n_missing_asset_share = sum(is.na(sectoral_asset_share)),
      n_profit_share_fallback = sum(
        !profit_share_proxy_source %in% c("fats_gross_operating_surplus"),
        na.rm = TRUE
      ),
      .groups = "drop"
    )

  sectoral_measurement_bridge <- bind_rows(
    fats_sector_shares |>
      transmute(
        affiliate,
        year,
        nace_r2,
        bridge_component = "sectoral_payroll_share",
        source_rule = payroll_share_proxy_source,
        source_rank = case_when(
          source_rule == "fats_personnel_costs" ~ 1L,
          source_rule == "fats_employees_scaled_to_personnel_costs" ~ 2L,
          source_rule == "fats_turnover_scaled_to_personnel_costs" ~ 3L,
          TRUE ~ 99L
        ),
        source_dataset = "Eurostat inward FATS",
        sector_share = fats_payroll_share,
        allocation_base = fats_payroll_allocation_base,
        crosswalk_rule =
          "Post-2021 WRL_REST FATS leaf NACE sector, normalised within affiliate-year"
      ),
    fats_sector_shares |>
      transmute(
        affiliate,
        year,
        nace_r2,
        bridge_component = "sectoral_asset_share",
        source_rule = asset_cell_proxy_source,
        source_rank = case_when(
          source_rule == "euklems_k_tang_stock" ~ 1L,
          source_rule == "euklems_k_tang_gapfilled_from_fats_investment" ~ 1L,
          source_rule == "fats_gross_investment_flow" ~ 2L,
          str_detect(source_rule, "scaled_to_investment_flow") ~ 3L,
          TRUE ~ 99L
        ),
        source_dataset = case_when(
          str_detect(source_rule, "^euklems") ~ "EUKLEMS and INTANProd",
          TRUE ~ "Eurostat inward FATS"
        ),
        sector_share = sectoral_asset_share,
        allocation_base = if_else(
          use_euklems_asset_share,
          euklems_k_tang_gapfilled,
          fats_investment_allocation_base
        ),
        crosswalk_rule = case_when(
          use_euklems_asset_share ~
            "FATS leaf sector mapped to EUKLEMS NACE stock, with within-family allocation when EUKLEMS is broader",
          TRUE ~
            "FATS investment-flow fallback, normalised within affiliate-year"
        )
      ),
    fats_sector_shares |>
      transmute(
        affiliate,
        year,
        nace_r2,
        bridge_component = "sectoral_profit_share",
        source_rule = profit_share_proxy_source,
        source_rank = case_when(
          source_rule == "fats_gross_operating_surplus" ~ 1L,
          str_detect(source_rule, "value_added") ~ 2L,
          str_detect(source_rule, "turnover") ~ 3L,
          TRUE ~ 99L
        ),
        source_dataset = "Eurostat inward FATS",
        sector_share = sectoral_profit_share,
        allocation_base = sectoral_profit_allocation_base,
        crosswalk_rule =
          "Post-2021 WRL_REST FATS leaf NACE sector, normalised within affiliate-year"
      )
  ) |>
    arrange(year, affiliate, nace_r2, bridge_component)

  sectoral_measurement_bridge_summary <- sectoral_measurement_bridge |>
    group_by(year, bridge_component, source_rule, source_rank, source_dataset) |>
    summarise(
      n_cells = n(),
      eu27_affiliates = n_distinct(affiliate),
      missing_share_cells = sum(is.na(sector_share)),
      total_country_share_mass = sum(sector_share, na.rm = TRUE),
      mean_sector_share = mean(sector_share, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(year, bridge_component, source_rank, source_rule)

  sectoral_bridge_country_year_diag <- fats_sector_shares |>
    group_by(affiliate, year) |>
    summarise(
      n_nace = n(),
      payroll_share_sum = sum(fats_payroll_share, na.rm = TRUE),
      asset_share_sum = sum(sectoral_asset_share, na.rm = TRUE),
      profit_share_sum = sum(sectoral_profit_share, na.rm = TRUE),
      n_payroll_fallback_cells = sum(
        payroll_share_proxy_source != "fats_personnel_costs",
        na.rm = TRUE
      ),
      n_asset_fallback_cells = sum(
        !asset_cell_proxy_source %in% c("euklems_k_tang_stock"),
        na.rm = TRUE
      ),
      n_profit_fallback_cells = sum(
        profit_share_proxy_source != "fats_gross_operating_surplus",
        na.rm = TRUE
      ),
      euklems_stock_coverage_turnover_share =
        first(euklems_stock_coverage_turnover_share),
      asset_country_year_source = first(asset_share_proxy_source),
      .groups = "drop"
    ) |>
    arrange(year, affiliate)

  bea_benchmark_diag <- bea_us_parent_sector_benchmark |>
    group_by(measure, year, affiliate) |>
    summarise(
      rows = n(),
      bea_share_denominator = first(bea_share_denominator),
      top_level_coverage_ratio = first(bea_top_level_coverage_ratio),
      mapped_rows = sum(bea_sector_share_mapped, na.rm = TRUE),
      mapped_value = sum(if_else(bea_sector_share_mapped, value, 0), na.rm = TRUE),
      suppressed_rows = sum(suppressed_rows, na.rm = TRUE),
      .groups = "drop"
    ) |>
    group_by(measure, year) |>
    summarise(
      rows = sum(rows),
      eu27_affiliates = n_distinct(affiliate),
      mapped_rows = sum(mapped_rows),
      mapped_value_share = safe_divide(
        sum(mapped_value, na.rm = TRUE),
        sum(bea_share_denominator, na.rm = TRUE)
      ),
      mean_top_level_coverage_ratio = weighted.mean(
        top_level_coverage_ratio,
        bea_share_denominator,
        na.rm = TRUE
      ),
      suppressed_rows = sum(suppressed_rows, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(measure, year)

  global_intan_diag <- global_intan_eu27_macro |>
    group_by(year) |>
    summarise(
      eu27_countries = n_distinct(affiliate),
      mean_intangible_investment_share = mean(
        global_intan_intangible_investment_share,
        na.rm = TRUE
      ),
      .groups = "drop"
    ) |>
    arrange(year)

  # Stage 1 tail-bounding diagnostic (Section sec:distributional).
  etr_bounding_diag <- panel |>
    group_by(year, etr_panelai_stage1_adjustment) |>
    summarise(n = n(), .groups = "drop") |>
    tidyr::pivot_wider(
      names_from = etr_panelai_stage1_adjustment,
      values_from = n, values_fill = 0
    ) |>
    arrange(year)

  # BSPI tier coverage (Section sec:crossval). Verifies that the
  # shape-transport branch activates for exactly 2017-2018 EU affiliate-years
  # with a 2019-2020 Table IV anchor present.
  bspi_tier_diag <- panel |>
    group_by(year, bspi_tier) |>
    summarise(
      rows = n(),
      eu27_rows = sum(affiliate_is_eu27, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(year, bspi_tier)

  # Shape-stability validation for the BSPI
  shape_stability_diag <- t4_brackets_by_affiliate_year |>
    mutate(window = case_when(
      year %in% BSPI_ANCHOR_YEARS ~ "anchor",
      year %in% BSPI_VALIDATION_YEARS ~ "validation",
      TRUE ~ NA_character_
    )) |>
    filter(!is.na(window), !is.na(bracket_profit_share))

  shape_stability_support <- shape_stability_diag |>
    distinct(affiliate, window, year) |>
    count(affiliate, window, name = "n_years_observed") |>
    tidyr::pivot_wider(
      names_from = window,
      values_from = n_years_observed,
      values_fill = 0
    ) |>
    rename(
      anchor_years_observed = anchor,
      validation_years_observed = validation
    )

  shape_stability_diag <- shape_stability_diag |>
    group_by(affiliate, window, etr_bracket) |>
    summarise(
      profit_share = mean(bracket_profit_share, na.rm = TRUE),
      .groups = "drop"
    ) |>
    tidyr::pivot_wider(
      names_from = window, values_from = profit_share,
      values_fill = 0
    ) |>
    group_by(affiliate) |>
    summarise(
      tv_anchor_vs_validation = 0.5 * sum(abs(anchor - validation), na.rm = TRUE),
      n_brackets_observed = sum(anchor > 0 | validation > 0, na.rm = TRUE),
      .groups = "drop"
    ) |>
    left_join(shape_stability_support, by = "affiliate") |>
    filter(anchor_years_observed > 0, validation_years_observed > 0) |>
    arrange(desc(tv_anchor_vs_validation))

  write_csv(panel_summary, file.path(diagnostics_dir, "step2_panel_summary.csv"))
  write_csv(payroll_diag, file.path(diagnostics_dir, "step2_payroll_imputation_by_year.csv"))
  write_csv(payroll_plausibility_diag, file.path(diagnostics_dir, "step2_payroll_plausibility_by_year.csv"))
  write_csv(
    accumulated_earnings_diag,
    file.path(diagnostics_dir, "step2_accumulated_earnings_by_year.csv")
  )
  write_csv(employee_plausibility_diag, file.path(diagnostics_dir, "step2_employee_plausibility_by_year.csv"))
  write_csv(wage_match_quality_diag, file.path(diagnostics_dir, "step2_wage_match_quality_by_year.csv"))
  write_csv(profit_correction_diag, file.path(diagnostics_dir, "step2_profit_correction_by_year.csv"))
  write_csv(missingness_diag, file.path(diagnostics_dir, "step2_missingness_by_year.csv"))
  write_csv(stage_readiness_diag, file.path(diagnostics_dir, "step2_stage_readiness_by_year.csv"))
  write_csv(
    affiliate_year_stage1_diag,
    file.path(diagnostics_dir, "step2_stage1_affiliate_year_coverage.csv")
  )
  write_csv(fats_diag, file.path(diagnostics_dir, "step2_fats_sector_coverage.csv"))
  write_csv(
    sectoral_source_hierarchy,
    file.path(diagnostics_dir, "step2_sectoral_source_hierarchy.csv")
  )
  write_csv(
    sectoral_nace_crosswalk_rules,
    file.path(diagnostics_dir, "step2_sectoral_nace_crosswalk_rules.csv")
  )
  write_csv(
    sectoral_measurement_bridge,
    file.path(diagnostics_dir, "step2_sectoral_measurement_bridge.csv")
  )
  write_csv(
    sectoral_measurement_bridge_summary,
    file.path(diagnostics_dir, "step2_sectoral_measurement_bridge_summary.csv")
  )
  write_csv(
    sectoral_bridge_country_year_diag,
    file.path(diagnostics_dir, "step2_sectoral_bridge_country_year.csv")
  )
  write_csv(bea_benchmark_diag, file.path(diagnostics_dir, "step2_bea_us_parent_sector_benchmark.csv"))
  write_csv(global_intan_diag, file.path(diagnostics_dir, "step2_global_intan_eu27_macro.csv"))
  write_csv(etr_bounding_diag, file.path(diagnostics_dir, "step2_etr_tail_bounding_by_year.csv"))
  write_csv(bspi_tier_diag, file.path(diagnostics_dir, "step2_bspi_tier_by_year.csv"))
  write_csv(shape_stability_diag, file.path(diagnostics_dir, "step2_bspi_shape_stability.csv"))

  saveRDS(panel, file.path(output_dir, "base_panel.rds"))
  saveRDS(fats_sector_shares, file.path(output_dir, "base_panel_fats_sector_shares.rds"))
  saveRDS(
    sectoral_measurement_bridge,
    file.path(output_dir, "base_panel_sectoral_measurement_bridge.rds")
  )
  saveRDS(
    sectoral_nace_crosswalk_rules,
    file.path(output_dir, "base_panel_sectoral_nace_crosswalk_rules.rds")
  )
  saveRDS(
    bea_us_parent_sector_benchmark,
    file.path(output_dir, "base_panel_bea_us_parent_sector_benchmark.rds")
  )
  saveRDS(
    global_intan_eu27_macro,
    file.path(output_dir, "base_panel_global_intan_eu27_macro.rds")
  )
  saveRDS(
    t4_brackets_by_affiliate_year,
    file.path(output_dir, "base_panel_t4_bracket_shares.rds")
  )
  saveRDS(
    t4_bilateral_brackets,
    file.path(output_dir, "base_panel_t4_bilateral_bracket_shares.rds")
  )
  write_csv(
    t4_parent_composition,
    file.path(diagnostics_dir, "step2_t4_parent_composition.csv")
  )

  message("\nStep 2 outputs written:")
  message(" - data/processed/base_panel.rds")
  message(" - data/processed/base_panel_fats_sector_shares.rds")
  message(" - data/processed/base_panel_sectoral_measurement_bridge.rds")
  message(" - data/processed/base_panel_sectoral_nace_crosswalk_rules.rds")
  message(" - data/processed/base_panel_bea_us_parent_sector_benchmark.rds")
  message(" - data/processed/base_panel_global_intan_eu27_macro.rds")
  message(" - data/processed/base_panel_t4_bracket_shares.rds")
  message(" - data/processed/base_panel_t4_bilateral_bracket_shares.rds")
  message(" - diagnostics/step2_*.csv")
}

if (is_direct_script_run("code/02_base_correction_and_merging.R")) {
  run_base_panel()
}
