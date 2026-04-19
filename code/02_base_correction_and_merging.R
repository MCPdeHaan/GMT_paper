# 02_base_correction_and_merging.R
# Step 2 of the methodology pipeline.
#
# Builds the bilateral Parent x Affiliate x Year base panel from the cleaned
# inputs in data/processed/. This step does four things:
# 1. merges the CbCR tables onto a country-like bilateral spine;
# 2. adds the low-dimensional supplementary controls needed later;
# 3. constructs a wage-based payroll proxy from employee counts;
# 4. constructs deterministic corrected profit bases before Stage 1 / Stage 3.
#
# This script does not fit ETR distributions, integrate top-up rates, or model
# behavioural reallocations.
library(dplyr); library(tidyr); library(purrr); library(readr); library(stringr); library(tibble)

IN   <- "data/processed"
OUT  <- IN
DIAG <- file.path(OUT, "diagnostics")
dir.create(DIAG, showWarnings = FALSE, recursive = TRUE)

CORE_YEARS       <- 2016:2022
ESTIMATION_YEARS <- 2017:2022
GMT_RATE         <- 0.15
EMPLOYEES_PER_ENTITY_CAP <- 100000

AGGREGATE_AFFILIATES <- c("A", "A_O", "E", "E_O", "F", "F_O",
                          "S", "S_O", "W", "W_O", "WXD", "STLS")
EU27_ISO3 <- c("AUT","BEL","BGR","CYP","CZE","DEU","DNK","ESP","EST","FIN","FRA",
               "GRC","HRV","HUN","IRL","ITA","LTU","LUX","LVA","MLT","NLD","POL",
               "PRT","ROU","SVK","SVN","SWE")
PANELAI_PERCENTILES <- c("etr_p5_panelai", "etr_p25_panelai", "etr_p50_panelai",
                         "etr_p75_panelai", "etr_p95_panelai")
T_PERCENTILES <- c("etr_p5", "etr_p25", "etr_p50", "etr_p75", "etr_p95")

# Literature-based conduit / haven set used in the bilateral overlay.
# These are the jurisdictions explicitly identified in the thesis discussion of
# Garcia-Bernardo et al. and related conduit-country evidence.
CONDUIT_HAVENS <- c("BMU", "CYM", "IRL", "LUX", "NLD",
                    "CHE", "SGP", "HKG", "PRI", "GBR")

normalize_code <- function(x) {
  case_when(
    x == "XKX" ~ "XKV",
    TRUE       ~ x
  )
}

assert_unique_keys <- function(df, keys, label) {
  n_dup <- df |>
    count(across(all_of(keys))) |>
    filter(n > 1) |>
    nrow()

  if (n_dup > 0) stop(sprintf("%s: %d duplicate key combinations", label, n_dup))
}

left_join_checked <- function(x, y, by, label) {
  n_before <- nrow(x)
  assert_unique_keys(y, unname(by), label)
  out <- left_join(x, y, by = by)
  if (nrow(out) != n_before) stop(sprintf("%s changed row count", label))
  out
}

sum_or_na <- function(x) {
  if (all(is.na(x))) return(NA_real_)
  sum(x, na.rm = TRUE)
}

yes_no_to_flag <- function(x) {
  x_low <- str_to_lower(x)
  case_when(
    is.na(x_low)       ~ NA,
    x_low == "yes"     ~ TRUE,
    x_low == "no"      ~ FALSE,
    TRUE               ~ NA
  )
}

pick_first_non_missing <- function(x) {
  idx <- which(!is.na(x) & x != "")
  if (length(idx) == 0) return(NA_character_)
  x[idx[1]]
}

min_date_or_na <- function(x) {
  x <- as.Date(x)
  if (all(is.na(x))) return(as.Date(NA))
  min(x, na.rm = TRUE)
}

build_year_nearest_lookup <- function(target_keys, candidates, value_col, source_col) {
  target_keys |>
    rename(jurisdiction = affiliate) |>
    left_join(candidates, by = "jurisdiction", relationship = "many-to-many") |>
    filter(!is.na(.data[[value_col]])) |>
    mutate(year_gap = abs(year - source_year),
           future_gap = source_year > year) |>
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

safe_divide <- function(num, den) {
  if_else(is.na(num) | is.na(den) | den == 0, NA_real_, num / den)
}

row_min_or_na <- function(...) {
  out <- pmin(..., na.rm = TRUE)
  out[is.infinite(out)] <- NA_real_
  out
}

# =============================================================================
# 1. Load cleaned inputs
# =============================================================================
t1 <- readRDS(file.path(IN, "cbcr_table1.rds"))
t2 <- readRDS(file.path(IN, "cbcr_table2.rds"))
t3 <- readRDS(file.path(IN, "cbcr_table3.rds"))
t4 <- readRDS(file.path(IN, "cbcr_table4.rds"))
t5 <- readRDS(file.path(IN, "cbcr_table5.rds"))
t6 <- readRDS(file.path(IN, "cbcr_table6.rds"))

cit_statutory <- readRDS(file.path(IN, "cit_statutory.rds")) |>
  mutate(jurisdiction = normalize_code(jurisdiction))
wb_classifications <- readRDS(file.path(IN, "wb_classifications.rds")) |>
  mutate(jurisdiction = normalize_code(jurisdiction))
wb_gdp <- readRDS(file.path(IN, "wb_gdp.rds")) |>
  mutate(jurisdiction = normalize_code(jurisdiction))
wb_population <- readRDS(file.path(IN, "wb_population.rds")) |>
  mutate(jurisdiction = normalize_code(jurisdiction))
wages_oecd <- readRDS(file.path(IN, "wages_oecd.rds")) |>
  mutate(jurisdiction = normalize_code(jurisdiction))
wages_ilo_monthly <- readRDS(file.path(IN, "wages_ilo_monthly.rds")) |>
  mutate(jurisdiction = normalize_code(jurisdiction))
fats_post2021 <- readRDS(file.path(IN, "fats_post2021.rds"))
beps_rules <- readRDS(file.path(IN, "beps_rules.rds")) |>
  mutate(jurisdiction = normalize_code(jurisdiction))
cbcr_requirements <- readRDS(file.path(IN, "cbcr_requirements.rds")) |>
  mutate(jurisdiction = normalize_code(jurisdiction))
pwc_tracker <- readRDS(file.path(IN, "pwc_pillar2_tracker.rds"))

# =============================================================================
# 2. Core bilateral spine and CbCR merges
# =============================================================================
panel <- t1 |>
  filter(year %in% CORE_YEARS,
         !affiliate %in% AGGREGATE_AFFILIATES) |>
  arrange(parent, affiliate, year) |>
  mutate(
    pair_id                      = paste(parent, affiliate, sep = "__"),
    is_domestic                  = parent == affiliate,
    is_2016_transition           = year == 2016,
    is_main_estimation_year      = year %in% ESTIMATION_YEARS,
    affiliate_is_eu27            = affiliate %in% EU27_ISO3,
    affiliate_is_conduit_haven   = affiliate %in% CONDUIT_HAVENS,
    holding_share_panelai        = safe_divide(act_holding_panelai, entities_count_panelai),
    holding_share_panelaii       = safe_divide(act_holding_panelaii, entities_count_panelaii),
    profit_adj_observed_panelai  = !is.na(profit_adj_panelai),
    profit_adj_ratio_observed    = safe_divide(profit_adj_panelai, profit_panelai),
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

t5_wide <- t5 |>
  rename_with(~ paste0("t5_", .x), -c(parent, year))

t6_wide <- t6 |>
  select(parent, affiliate, year, size_class, profit, assets, employees,
         accumulated_earnings, tax_accrued, entities_count,
         cbcr_count, subgroups_count) |>
  pivot_wider(
    names_from  = size_class,
    values_from = c(profit, assets, employees, accumulated_earnings, tax_accrued,
                    entities_count, cbcr_count, subgroups_count),
    names_glue  = "t6_{.value}_{size_class}"
  )

panel <- panel |>
  left_join_checked(t2_wide, by = c("parent" = "parent",
                                    "affiliate" = "affiliate",
                                    "year" = "year"),
                    label = "join T2") |>
  left_join_checked(t3_low, by = c("parent" = "parent",
                                   "affiliate" = "affiliate",
                                   "year" = "year"),
                    label = "join T3 rate_0_15") |>
  left_join_checked(t4_low, by = c("parent" = "parent",
                                   "affiliate" = "affiliate",
                                   "year" = "year"),
                    label = "join T4 rate_0_15") |>
  left_join_checked(t5_wide, by = c("parent" = "parent", "year" = "year"),
                    label = "join T5") |>
  left_join_checked(t6_wide, by = c("parent" = "parent",
                                    "affiliate" = "affiliate",
                                    "year" = "year"),
                    label = "join T6")

# =============================================================================
# 3. Supplementary datasets added on their natural keys
# =============================================================================

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
    tibble(jurisdiction = "XKV", iso2 = "XK",
           jurisdiction_name = "Kosovo",
           region = "Europe & Central Asia",
           income_level = "Upper middle income",
           income_id = "UMC"),
    tibble(jurisdiction = "TWN", iso2 = "TW",
           jurisdiction_name = "Taiwan",
           region = NA_character_,
           income_level = NA_character_,
           income_id = NA_character_)
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
    affiliate_cit_top_all  = cit_top_all
  )

cit_parent <- cit_statutory |>
  rename(
    parent = jurisdiction,
    parent_cit_standard = cit_standard,
    parent_cit_top_all  = cit_top_all
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

ilo_sector_priority <- c("ECO_ISIC4_TOTAL", "ECO_ISIC3_TOTAL",
                         "ECO_AGGREGATE_TOTAL", "ECO_SECTOR_TOTAL")

ilo_monthly_selected <- wages_ilo_monthly |>
  filter(sex == "SEX_T",
         currency %in% c("CUR_TYPE_PPP", "CUR_TYPE_USD"),
         sector %in% ilo_sector_priority) |>
  mutate(
    sector_rank = match(sector, ilo_sector_priority),
    source_rank = if_else(currency == "CUR_TYPE_PPP", 2L, 3L),
    wage_source = if_else(currency == "CUR_TYPE_PPP",
                          "ilo_monthly_ppp_x12",
                          "ilo_monthly_usd_x12")
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
assert_unique_keys(wage_candidates,
                   c("jurisdiction", "source_rank", "source_year", "wage_source"),
                   "wage candidates")

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
      any(!is.na(value))                               ~ FALSE,
      TRUE                                            ~ NA
    ),
    .groups = "drop"
  ) |>
  pivot_wider(
    names_from  = rule,
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

# PwC Pillar Two tracker reduced to earliest effective dates.
pwc_map <- tribble(
  ~territory, ~jurisdiction,
  "Australia", "AUS",
  "Austria", "AUT",
  "Bahrain", "BHR",
  "Barbados", "BRB",
  "Belgium", "BEL",
  "Bulgaria", "BGR",
  "Canada", "CAN",
  "Croatia", "HRV",
  "Cyprus", "CYP",
  "Czech Republic", "CZE",
  "Denmark", "DNK",
  "Finland", "FIN",
  "France", "FRA",
  "Germany", "DEU",
  "Gibraltar", "GIB",
  "Greece", "GRC",
  "Guernsey", "GGY",
  "Hong Kong", "HKG",
  "Hungary", "HUN",
  "Indonesia", "IDN",
  "Ireland", "IRL",
  "Isle of Man", "IMN",
  "Italy", "ITA",
  "Japan", "JPN",
  "Jersey", "JEY",
  "Kenya", "KEN",
  "Kuwait", "KWT",
  "Liechtenstein", "LIE",
  "Lithuania", "LTU",
  "Luxembourg", "LUX",
  "Malaysia", "MYS",
  "Mauritius", "MUS",
  "Netherlands", "NLD",
  "New Zealand", "NZL",
  "North Macedonia", "MKD",
  "Norway", "NOR",
  "Poland", "POL",
  "Portugal", "PRT",
  "Romania", "ROU",
  "Singapore", "SGP",
  "Slovakia", "SVK",
  "Slovenia", "SVN",
  "South Africa", "ZAF",
  "South Korea", "KOR",
  "Spain", "ESP",
  "Sweden", "SWE",
  "Switzerland", "CHE",
  "Thailand", "THA",
  "Turkey", "TUR",
  "UAE", "ARE",
  "UK", "GBR",
  "Uruguay", "URY",
  "Vietnam", "VNM"
)

if (n_distinct(pwc_map$territory) != 53) stop("PwC territory map is incomplete")

pwc_joined <- pwc_tracker |>
  left_join(pwc_map, by = "territory")

if (any(is.na(pwc_joined$jurisdiction))) stop("PwC tracker has unmapped territories")

pwc_summary <- pwc_joined |>
  mutate(requirement_group = case_when(
    requirement_group == "Top-up tax" ~ "topup_tax",
    requirement_group == "GIR"        ~ "gir",
    requirement_group == "QDMTT"      ~ "qdmtt",
    TRUE                              ~ NA_character_
  )) |>
  filter(!is.na(jurisdiction), !is.na(requirement_group)) |>
  group_by(jurisdiction, requirement_group) |>
  summarise(start_date = min_date_or_na(p2_start), .groups = "drop") |>
  pivot_wider(
    names_from  = requirement_group,
    values_from = start_date,
    names_prefix = "pwc_"
  ) |>
  mutate(
    pwc_qdmtt_by_2026 = !is.na(pwc_qdmtt) & pwc_qdmtt <= as.Date("2026-01-01"),
    pwc_gir_by_2026   = !is.na(pwc_gir) & pwc_gir <= as.Date("2026-01-01"),
    pwc_topup_by_2026 = !is.na(pwc_topup_tax) & pwc_topup_tax <= as.Date("2026-01-01")
  )

pwc_affiliate <- pwc_summary |>
  rename_with(~ paste0("affiliate_", .x), -jurisdiction) |>
  rename(affiliate = jurisdiction)

pwc_parent <- pwc_summary |>
  rename_with(~ paste0("parent_", .x), -jurisdiction) |>
  rename(parent = jurisdiction)

panel <- panel |>
  left_join_checked(parent_lookup, by = c("parent" = "parent"),
                    label = "join parent lookup") |>
  left_join_checked(affiliate_lookup, by = c("affiliate" = "affiliate"),
                    label = "join affiliate lookup") |>
  left_join_checked(cit_affiliate, by = c("affiliate" = "affiliate",
                                          "year" = "year"),
                    label = "join affiliate CIT") |>
  left_join_checked(cit_parent, by = c("parent" = "parent",
                                       "year" = "year"),
                    label = "join parent CIT") |>
  left_join_checked(wb_gdp_affiliate, by = c("affiliate" = "affiliate",
                                             "year" = "year"),
                    label = "join affiliate GDP") |>
  left_join_checked(wb_population_affiliate, by = c("affiliate" = "affiliate",
                                                    "year" = "year"),
                    label = "join affiliate population") |>
  left_join_checked(wage_lookup, by = c("affiliate" = "affiliate",
                                        "year" = "year"),
                    label = "join affiliate wage") |>
  left_join_checked(beps_affiliate, by = c("affiliate" = "affiliate",
                                           "year" = "year"),
                    label = "join affiliate BEPS") |>
  left_join_checked(beps_parent, by = c("parent" = "parent",
                                        "year" = "year"),
                    label = "join parent BEPS") |>
  left_join_checked(cbcr_req_parent, by = c("parent" = "parent"),
                    label = "join parent CbCR requirements") |>
  left_join_checked(pwc_affiliate, by = c("affiliate" = "affiliate"),
                    label = "join affiliate PwC policy") |>
  left_join_checked(pwc_parent, by = c("parent" = "parent"),
                    label = "join parent PwC policy")

# =============================================================================
# 4. Deterministic imputations and corrected profit bases
# =============================================================================
# OECD CbCR "EARNINGS" is accumulated earnings, not payroll. The SBIE payroll
# input is therefore proxied from employee counts and the affiliate-year wage
# benchmark rather than taken from the CbCR monetary measures.
panel <- panel |>
  mutate(
    assets_sbie = coalesce(assets_panelaii, assets_panelai, assets),
    assets_sbie_source = case_when(
      !is.na(assets_panelaii) ~ "panelaii",
      !is.na(assets_panelai)  ~ "panelai",
      !is.na(assets)          ~ "aggregate",
      TRUE                    ~ "missing"
    ),
    entities_sbie = coalesce(entities_count_panelaii, entities_count_panelai, entities_count),
    entities_sbie_source = case_when(
      !is.na(entities_count_panelaii) ~ "panelaii",
      !is.na(entities_count_panelai)  ~ "panelai",
      !is.na(entities_count)          ~ "aggregate",
      TRUE                            ~ "missing"
    ),
    employees_sbie_raw = coalesce(employees_panelaii, employees_panelai, employees),
    employees_sbie_source = case_when(
      !is.na(employees_panelaii) ~ "panelaii",
      !is.na(employees_panelai)  ~ "panelai",
      !is.na(employees)          ~ "aggregate",
      TRUE                       ~ "missing"
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
    payroll_sbie_source = case_when(
      !is.na(payroll_sbie) & employees_sbie_correction_flag ~
        paste0("proxy_", employees_sbie_source, "_", affiliate_wage_source, "_screened_emp"),
      !is.na(payroll_sbie) ~ paste0("proxy_", employees_sbie_source, "_", affiliate_wage_source),
      !is.na(employees_sbie) & is.na(affiliate_wage_annual) ~ paste0("missing_wage_", employees_sbie_source),
      is.na(employees_sbie) & !is.na(affiliate_wage_annual) ~ "missing_employee_base",
      TRUE ~ "missing_employee_and_wage"
    ),
    etr_panelai_raw = if_else(
      !is.na(profit_panelai) & profit_panelai > 0,
      tax_accrued_panelai / profit_panelai,
      NA_real_
    ),
    domestic_correction_rate_baseline = case_when(
      parent == "USA" ~ 0.54,
      parent == "NLD" ~ 0.16,
      TRUE            ~ 0.324
    ),
    domestic_correction_rate_aggressive = case_when(
      parent == "USA" ~ 0.54,
      parent == "NLD" ~ 0.16,
      TRUE            ~ 0.555
    ),
    profit_panelai_uncorrected = profit_panelai,
    profit_panelai_corrected_baseline = case_when(
      !is.na(profit_adj_panelai) ~ profit_adj_panelai,
      is_domestic                ~ profit_panelai * (1 - domestic_correction_rate_baseline),
      parent != "USA" & affiliate_is_conduit_haven ~ profit_panelai * 0.90,
      TRUE                       ~ profit_panelai
    ),
    profit_panelai_corrected_aggressive = case_when(
      !is.na(profit_adj_panelai) ~ profit_adj_panelai,
      is_domestic                ~ profit_panelai * (1 - domestic_correction_rate_aggressive),
      parent != "USA" & affiliate_is_conduit_haven ~ profit_panelai * 0.90,
      TRUE                       ~ profit_panelai
    ),
    profit_correction_source_baseline = case_when(
      !is.na(profit_adj_panelai) ~ "observed_profit_adj",
      is_domestic                ~ "domestic_upe_hugger",
      parent != "USA" & affiliate_is_conduit_haven ~ "conduit_overlay_10pct",
      TRUE                       ~ "uncorrected_foreign"
    ),
    profit_correction_source_aggressive = case_when(
      !is.na(profit_adj_panelai) ~ "observed_profit_adj",
      is_domestic                ~ "domestic_upe_hugger_cap",
      parent != "USA" & affiliate_is_conduit_haven ~ "conduit_overlay_10pct",
      TRUE                       ~ "uncorrected_foreign"
    ),
    profit_correction_rate_baseline = safe_divide(
      profit_panelai_uncorrected - profit_panelai_corrected_baseline,
      profit_panelai_uncorrected
    ),
    profit_correction_rate_aggressive = safe_divide(
      profit_panelai_uncorrected - profit_panelai_corrected_aggressive,
      profit_panelai_uncorrected
    ),
    analysis_profit_base = profit_panelai_corrected_baseline,
    affiliate_cit_rate = coalesce(affiliate_cit_top_all, affiliate_cit_standard),
    parent_cit_rate = coalesce(parent_cit_top_all, parent_cit_standard),
    zero_profit_panelai_flag = !is.na(profit_panelai) & profit_panelai == 0,
    below_gmt_on_average_flag = !is.na(etr_panelai_raw) & etr_panelai_raw < GMT_RATE,
    etr_negative_flag = !is.na(etr_panelai_raw) & etr_panelai_raw < 0,
    etr_above_one_flag = !is.na(etr_panelai_raw) & etr_panelai_raw > 1,
    has_panelai_percentiles = !if_any(all_of(PANELAI_PERCENTILES), is.na),
    has_t_fallback_percentiles = !if_any(all_of(T_PERCENTILES), is.na),
    has_any_percentile_set = has_panelai_percentiles | has_t_fallback_percentiles,
    has_t4_low_bracket = !is.na(t4_low_profit),
    t4_low_profit_share_panelai = safe_divide(t4_low_profit, profit_panelai),
    t3_low_profit_share_panelai = safe_divide(t3_low_profit, profit_panelai),
    has_behavioral_estimation_inputs = is_main_estimation_year &
      !is.na(analysis_profit_base) & analysis_profit_base > 0 &
      !is.na(payroll_sbie) & payroll_sbie > 0 &
      !is.na(assets_sbie) & assets_sbie >= 0 &
      !is.na(etr_panelai_raw),
    has_stage1_percentile_inputs = has_behavioral_estimation_inputs &
      has_any_percentile_set,
    has_stage1_hybrid_inputs = has_behavioral_estimation_inputs &
      (has_any_percentile_set | has_t4_low_bracket),
    has_stage1_crossval_inputs = has_behavioral_estimation_inputs &
      has_any_percentile_set & has_t4_low_bracket,
    has_estimation_inputs = has_behavioral_estimation_inputs
  )

assert_unique_keys(panel, c("parent", "affiliate", "year"), "final base panel")

# =============================================================================
# 5. Sectoral FATS sidecar for later SBIE work
# =============================================================================
fats_geo_map <- tribble(
  ~geo, ~affiliate,
  "AT", "AUT", "BE", "BEL", "BG", "BGR", "CY", "CYP", "CZ", "CZE",
  "DE", "DEU", "DK", "DNK", "EE", "EST", "EL", "GRC", "ES", "ESP",
  "FI", "FIN", "FR", "FRA", "HR", "HRV", "HU", "HUN", "IE", "IRL",
  "IT", "ITA", "LT", "LTU", "LU", "LUX", "LV", "LVA", "MT", "MLT",
  "NL", "NLD", "PL", "POL", "PT", "PRT", "RO", "ROU", "SE", "SWE",
  "SI", "SVN", "SK", "SVK"
)

fats_sector_shares <- fats_post2021 |>
  filter(year %in% 2021:2022, geo %in% fats_geo_map$geo) |>
  left_join(fats_geo_map, by = "geo") |>
  group_by(affiliate, year, nace_r2) |>
  summarise(
    fats_personnel_costs = sum_or_na(ind_expn_sal_ben_meur),
    fats_employees       = sum_or_na(ind_emp_nr),
    fats_investment      = sum_or_na(ind_grsinv_tnca_meur),
    fats_turnover        = sum_or_na(ind_nettur_meur),
    .groups = "drop"
  ) |>
  group_by(affiliate, year) |>
  mutate(
    fats_payroll_share    = safe_divide(fats_personnel_costs, sum_or_na(fats_personnel_costs)),
    fats_employee_share   = safe_divide(fats_employees, sum_or_na(fats_employees)),
    fats_investment_share = safe_divide(fats_investment, sum_or_na(fats_investment)),
    fats_turnover_share   = safe_divide(fats_turnover, sum_or_na(fats_turnover))
  ) |>
  ungroup()

assert_unique_keys(fats_sector_shares, c("affiliate", "year", "nace_r2"),
                   "FATS sector shares")

# =============================================================================
# 6. Diagnostics and outputs
# =============================================================================
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
    "rows_with_affiliate_cit_rate",
    "rows_with_affiliate_cit_top_all",
    "rows_with_baseline_profit_correction",
    "rows_with_observed_profit_adj",
    "rows_with_t4_low_bracket",
    "rows_ready_for_behavioral_estimation",
    "rows_ready_for_stage1_percentiles",
    "rows_ready_for_stage1_hybrid",
    "rows_ready_for_stage1_crossval"
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
    sum(!is.na(panel$affiliate_cit_rate)),
    sum(!is.na(panel$affiliate_cit_top_all)),
    sum(panel$profit_correction_source_baseline != "uncorrected_foreign", na.rm = TRUE),
    sum(panel$profit_adj_observed_panelai, na.rm = TRUE),
    sum(panel$has_t4_low_bracket, na.rm = TRUE),
    sum(panel$has_behavioral_estimation_inputs, na.rm = TRUE),
    sum(panel$has_stage1_percentile_inputs, na.rm = TRUE),
    sum(panel$has_stage1_hybrid_inputs, na.rm = TRUE),
    sum(panel$has_stage1_crossval_inputs, na.rm = TRUE)
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

profit_correction_diag <- panel |>
  group_by(year, profit_correction_source_baseline) |>
  summarise(
    rows = n(),
    uncorrected_profit = sum(profit_panelai_uncorrected, na.rm = TRUE),
    corrected_profit   = sum(profit_panelai_corrected_baseline, na.rm = TRUE),
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
    missing_wage          = mean(is.na(affiliate_wage_annual)),
    missing_payroll_sbie  = mean(is.na(payroll_sbie)),
    missing_assets_sbie   = mean(is.na(assets_sbie)),
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
    n_missing_payroll = sum(is.na(fats_personnel_costs)),
    n_missing_investment = sum(is.na(fats_investment)),
    .groups = "drop"
  )

write_csv(panel_summary, file.path(DIAG, "step2_panel_summary.csv"))
write_csv(payroll_diag, file.path(DIAG, "step2_payroll_imputation_by_year.csv"))
write_csv(accumulated_earnings_diag, file.path(DIAG, "step2_payroll_plausibility_by_year.csv"))
write_csv(employee_plausibility_diag, file.path(DIAG, "step2_employee_plausibility_by_year.csv"))
write_csv(profit_correction_diag, file.path(DIAG, "step2_profit_correction_by_year.csv"))
write_csv(missingness_diag, file.path(DIAG, "step2_missingness_by_year.csv"))
write_csv(stage_readiness_diag, file.path(DIAG, "step2_stage_readiness_by_year.csv"))
write_csv(
  affiliate_year_stage1_diag,
  file.path(DIAG, "step2_stage1_affiliate_year_coverage.csv")
)
write_csv(fats_diag, file.path(DIAG, "step2_fats_sector_coverage.csv"))

saveRDS(panel, file.path(OUT, "base_panel.rds"))
saveRDS(fats_sector_shares, file.path(OUT, "base_panel_fats_sector_shares.rds"))

message("\nStep 2 outputs written:")
message(" - data/processed/base_panel.rds")
message(" - data/processed/base_panel_fats_sector_shares.rds")
message(" - diagnostics/step2_*.csv")
