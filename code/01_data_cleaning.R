# 01_data_cleaning.R
# Step 1 of the methodology pipeline.
#
# Reshapes the raw datasets collected by code/collect_all_data.py into tidy,
# analysis-ready intermediate tables in data/processed/. No new variables are
# calculated, no datasets are merged.
library(dplyr); library(tidyr); library(readr); library(purrr); library(stringr); library(tibble)

RAW <- "data/raw"
OUT <- "data/processed"
DIAG <- file.path(OUT, "diagnostics")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
dir.create(DIAG, showWarnings = FALSE, recursive = TRUE)

EU27_ISO3 <- c("AUT","BEL","BGR","CYP","CZE","DEU","DNK","ESP","EST","FIN","FRA",
               "GRC","HRV","HUN","IRL","ITA","LTU","LUX","LVA","MLT","NLD","POL",
               "PRT","ROU","SVK","SVN","SWE")
# Eurostat publishes inward FATS using its own 2-letter codes (UK, EL = Greece).
# EU27_ISO2 keeps the 27 Member States in Eurostat code system for the FATS coverage check.
EU27_ISO2 <- c("AT","BE","BG","CY","CZ","DE","DK","EE","EL","ES","FI","FR",
               "HR","HU","IE","IT","LT","LU","LV","MT","NL","PL","PT","RO",
               "SE","SI","SK")

clean_name <- function(x) x |> tolower() |> str_replace_all("[-[:space:]]", "_")

# OECD CbCR "EARNINGS" refers to accumulated earnings / retained earnings,
# not payroll costs. Rename it explicitly here to avoid a misleading carry-over
# into the merged panel and the later SBIE construction.
measure_name <- function(x) {
  case_when(
    x == "EARNINGS" ~ "accumulated_earnings",
    TRUE            ~ clean_name(x)
  )
}

read_oecd <- function(path) {
  read_csv(path, show_col_types = FALSE,
           col_types = cols(.default = col_guess(),
                            TIME_PERIOD = col_integer(),
                            OBS_VALUE   = col_double()))
}

panel_suffix <- function(p) {
  case_when(p == "PANELAI"  ~ "_panelai",
            p == "PANELAII" ~ "_panelaii",
            TRUE            ~ "")
}

assert_unique_keys <- function(df, keys, label) {
  n_dup <- df |> count(across(all_of(keys))) |> filter(n > 1) |> nrow()
  if (n_dup > 0) stop(sprintf("%s: %d duplicate key combinations", label, n_dup))
}

# Append a one-row tibble to the diagnostics list
diagnostics <- list()
add_diag <- function(dataset, metric, value) {
  diagnostics[[length(diagnostics) + 1L]] <<-
    tibble(dataset = dataset, metric = metric, value = as.character(value))
}

# 1. CbCR Table I — aggregate totals + within-jurisdiction ETR percentiles
t1_raw <- read_oecd(file.path(RAW, "oecd_cbcr/cbcr_table1_aggregate_totals.csv")) |>
  rename(parent = REF_AREA, affiliate = COUNTERPART_AREA, year = TIME_PERIOD,
         measure = MEASURE, panel = PROFIT_GROUPING,
         stat_op = STATISTICAL_OPERATION, value = OBS_VALUE)

# Financial measures: Profit / Tax_accrued split across Panel A-I (profit-makers)
# and Panel A-II (all entities); activity & entity counts arrive panel-agnostic.
t1_fin <- t1_raw |>
  filter(measure != "ETR") |>
  mutate(varname = paste0(measure_name(measure), panel_suffix(panel))) |>
  select(parent, affiliate, year, varname, value) |>
  pivot_wider(names_from = varname, values_from = value)

# ETR percentiles (the only distributional moments published by the OECD).
t1_etr <- t1_raw |>
  filter(measure == "ETR") |>
  mutate(varname = paste0("etr_", tolower(stat_op), panel_suffix(panel))) |>
  select(parent, affiliate, year, varname, value) |>
  pivot_wider(names_from = varname, values_from = value)

cbcr_t1 <- full_join(t1_fin, t1_etr, by = c("parent", "affiliate", "year")) |>
  arrange(parent, affiliate, year)

assert_unique_keys(cbcr_t1, c("parent", "affiliate", "year"), "T1")
saveRDS(cbcr_t1, file.path(OUT, "cbcr_table1.rds"))

add_diag("cbcr_t1", "rows", nrow(cbcr_t1))
add_diag("cbcr_t1", "parent_jurisdictions", n_distinct(cbcr_t1$parent))
add_diag("cbcr_t1", "affiliate_jurisdictions", n_distinct(cbcr_t1$affiliate))
add_diag("cbcr_t1", "year_range", paste(range(cbcr_t1$year), collapse = "-"))
add_diag("cbcr_t1", "zero_profit_panelai",
         sum(cbcr_t1$profit_panelai == 0, na.rm = TRUE))
add_diag("cbcr_t1", "negative_profit_panelai",
         sum(cbcr_t1$profit_panelai < 0, na.rm = TRUE))
add_diag("cbcr_t1", "missing_etr_p50_panelai_share",
         round(mean(is.na(cbcr_t1$etr_p50_panelai)), 3))
add_diag("cbcr_t1", "etr_p50_panelai_first_year_with_data",
         suppressWarnings(min(cbcr_t1$year[!is.na(cbcr_t1$etr_p50_panelai)])))
add_diag("cbcr_t1", "profit_adj_missing_pre2021",
         sum(is.na(cbcr_t1$profit_adj_panelai) & cbcr_t1$year < 2021))
add_diag("cbcr_t1", "profit_adj_present_2021_2022",
         sum(!is.na(cbcr_t1$profit_adj_panelai) & cbcr_t1$year >= 2021))
add_diag("cbcr_t1", "zero_profit_panelai_tax_positive",
         sum(cbcr_t1$profit_panelai == 0 & cbcr_t1$tax_accrued_panelai > 0,
             na.rm = TRUE))
add_diag("cbcr_t1", "eu27_present_as_affiliate",
         length(intersect(EU27_ISO3, unique(cbcr_t1$affiliate))))

# Year-by-year expansion of reporting parents (26 in 2016 → 58 in 2022).
write_csv(
  cbcr_t1 |> distinct(parent, year) |> count(year, name = "n_parents"),
  file.path(DIAG, "cbcr_t1_parent_coverage_by_year.csv")
)

# =============================================================================
# 2. CbCR Table II — interquartile means
# =============================================================================
message("[2/12] CbCR Table II")
t2_raw <- read_oecd(file.path(RAW, "oecd_cbcr/cbcr_table2_interquartile_means.csv")) |>
  rename(parent = REF_AREA, affiliate = COUNTERPART_AREA, year = TIME_PERIOD,
         measure = MEASURE, panel = PROFIT_GROUPING, value = OBS_VALUE)

cbcr_t2 <- t2_raw |>
  mutate(varname = paste0(measure_name(measure), panel_suffix(panel))) |>
  select(parent, affiliate, year, varname, value) |>
  pivot_wider(names_from = varname, values_from = value) |>
  arrange(parent, affiliate, year)

assert_unique_keys(cbcr_t2, c("parent", "affiliate", "year"), "T2")
saveRDS(cbcr_t2, file.path(OUT, "cbcr_table2.rds"))
add_diag("cbcr_t2", "rows", nrow(cbcr_t2))

# =============================================================================
# 3. CbCR Table III — ETR brackets at MNE-group level
# =============================================================================
message("[3/12] CbCR Table III")
t3_raw <- read_oecd(file.path(RAW, "oecd_cbcr/cbcr_table3_etr_aggregates.csv")) |>
  rename(parent = REF_AREA, affiliate = COUNTERPART_AREA, year = TIME_PERIOD,
         measure = MEASURE, panel = PROFIT_GROUPING,
         etr_bracket = EFFECTIVE_TAX_RATE, value = OBS_VALUE)

cbcr_t3 <- t3_raw |>
  mutate(varname     = paste0(measure_name(measure), panel_suffix(panel)),
         etr_bracket = clean_name(etr_bracket)) |>
  select(parent, affiliate, year, etr_bracket, varname, value) |>
  pivot_wider(names_from = varname, values_from = value) |>
  arrange(parent, affiliate, year, etr_bracket)

assert_unique_keys(cbcr_t3,
                   c("parent", "affiliate", "year", "etr_bracket"), "T3")
saveRDS(cbcr_t3, file.path(OUT, "cbcr_table3.rds"))
add_diag("cbcr_t3", "rows", nrow(cbcr_t3))

# =============================================================================
# 4. CbCR Table IV — ETR brackets at subsidiary level (the GMT-critical table)
# =============================================================================
message("[4/12] CbCR Table IV")
t4_raw <- read_oecd(file.path(RAW, "oecd_cbcr/cbcr_table4_etr_aggregates_alt.csv")) |>
  rename(parent = REF_AREA, affiliate = COUNTERPART_AREA, year = TIME_PERIOD,
         measure = MEASURE, panel = PROFIT_GROUPING,
         etr_bracket = EFFECTIVE_TAX_RATE, value = OBS_VALUE)

cbcr_t4 <- t4_raw |>
  mutate(varname     = paste0(measure_name(measure), panel_suffix(panel)),
         etr_bracket = clean_name(etr_bracket)) |>
  select(parent, affiliate, year, etr_bracket, varname, value) |>
  pivot_wider(names_from = varname, values_from = value) |>
  arrange(parent, affiliate, year, etr_bracket)

assert_unique_keys(cbcr_t4,
                   c("parent", "affiliate", "year", "etr_bracket"), "T4")
saveRDS(cbcr_t4, file.path(OUT, "cbcr_table4.rds"))

add_diag("cbcr_t4", "rows", nrow(cbcr_t4))
add_diag("cbcr_t4", "eu27_present_as_affiliate",
         length(intersect(EU27_ISO3, unique(cbcr_t4$affiliate))))
add_diag("cbcr_t4", "first_year_with_data",
         suppressWarnings(min(cbcr_t4$year)))
add_diag("cbcr_t4", "n_parents_reporting_brackets",
         n_distinct(cbcr_t4$parent))

# Switzerland anomaly, per-parent. Table IV CHE exists 2019-2022 only and is
# dominated by USA reporting 80-91% of its CHE profit in the rate_0_15 bracket.
# Flag, do not drop. Table IV reports a single profit panel (PROFIT_GROUPING
# = _Z), so the variable is plain `profit`.
che_flag <- cbcr_t4 |>
  filter(affiliate == "CHE", etr_bracket == "rate_0_15") |>
  left_join(
    cbcr_t1 |> select(parent, affiliate, year,
                      t1_profit_panelai = profit_panelai,
                      t1_profit_panelaii = profit_panelaii),
    by = c("parent", "affiliate", "year")
  ) |>
  arrange(year, parent) |>
  transmute(year, parent,
            t4_profit_below15 = profit,
            t1_profit_panelai, t1_profit_panelaii,
            share_of_panelai = round(profit / t1_profit_panelai, 3))
write_csv(che_flag, file.path(DIAG, "cbcr_t4_switzerland_flag.csv"))

# ETR percentile coverage by year. Percentiles are published only from 2021
# vintage onward for Panel A-I / A-II; the panel-agnostic `_T` series has
# slightly broader coverage and is the natural fallback for Stage 1's
# distributional fit. Recorded here so downstream does not have to rediscover it.
etr_pct_coverage <- cbcr_t1 |>
  group_by(year) |>
  summarise(n_cells = n(),
            pct_p50_panelai = round(1 - mean(is.na(etr_p50_panelai)), 3),
            pct_p50_panelaii = round(1 - mean(is.na(etr_p50_panelaii)), 3),
            pct_p50_t = round(1 - mean(is.na(etr_p50)), 3),
            pct_p50_either = round(mean(!is.na(etr_p50_panelai) |
                                        !is.na(etr_p50)), 3),
            .groups = "drop")
write_csv(etr_pct_coverage, file.path(DIAG, "cbcr_t1_etr_percentile_coverage.csv"))

# Table IV coverage by year. Only 2019-2022 carry observations, and only a
# handful of parents (USA, ESP, SGP, ...) report brackets. The hybrid Stage 1
# measurement therefore has much narrower coverage than Table IV's headline.
t4_coverage <- cbcr_t4 |>
  group_by(year) |>
  summarise(n_obs = n(),
            n_parents = n_distinct(parent),
            n_affiliates = n_distinct(affiliate),
            n_eu27_affiliates = n_distinct(affiliate[affiliate %in% EU27_ISO3]),
            .groups = "drop")
write_csv(t4_coverage, file.path(DIAG, "cbcr_t4_coverage_by_year.csv"))

# =============================================================================
# 5. CbCR Table V — MNE size distribution percentiles
# =============================================================================
message("[5/12] CbCR Table V")
t5_raw <- read_oecd(file.path(RAW, "oecd_cbcr/cbcr_table5_mne_size_distribution.csv")) |>
  rename(parent = REF_AREA, year = TIME_PERIOD, measure = MEASURE,
         stat_op = STATISTICAL_OPERATION, value = OBS_VALUE)

cbcr_t5 <- t5_raw |>
  mutate(varname = paste0(measure_name(measure), "_", tolower(stat_op))) |>
  select(parent, year, varname, value) |>
  pivot_wider(names_from = varname, values_from = value) |>
  arrange(parent, year)

assert_unique_keys(cbcr_t5, c("parent", "year"), "T5")
saveRDS(cbcr_t5, file.path(OUT, "cbcr_table5.rds"))
add_diag("cbcr_t5", "rows", nrow(cbcr_t5))

# =============================================================================
# 6. CbCR Table VI — financial aggregates by MNE size class (2022 only)
# =============================================================================
message("[6/12] CbCR Table VI")
t6_raw <- read_oecd(file.path(RAW, "oecd_cbcr/cbcr_table6_mne_size_aggregates.csv")) |>
  rename(parent = REF_AREA, affiliate = COUNTERPART_AREA, year = TIME_PERIOD,
         measure = MEASURE, panel = PROFIT_GROUPING, size_class = MNE_SIZE,
         value = OBS_VALUE)

cbcr_t6 <- t6_raw |>
  mutate(varname    = paste0(measure_name(measure), panel_suffix(panel)),
         size_class = clean_name(size_class)) |>
  select(parent, affiliate, year, size_class, varname, value) |>
  pivot_wider(names_from = varname, values_from = value) |>
  arrange(parent, affiliate, year, size_class)

assert_unique_keys(cbcr_t6,
                   c("parent", "affiliate", "year", "size_class"), "T6")
saveRDS(cbcr_t6, file.path(OUT, "cbcr_table6.rds"))
add_diag("cbcr_t6", "rows", nrow(cbcr_t6))

# =============================================================================
# 7. OECD statutory CIT rates (central + combined)
# =============================================================================
message("[7/12] OECD statutory CIT rates")
cit_stat_raw <- read_oecd(file.path(RAW, "oecd_tax_rates/oecd_statutory_cit_rates.csv"))
# Filter to MEASURE = "CIT" (the headline statutory CIT rate); the file also
# carries adjacent measure codes (CIT_C central-only, CIT_LSN local sub-national,
# exemption codes, etc.) which are kept long in cit_dividend / etr_forward style
# storage if needed later.
# TARGETING: ST = standard rate, TA = top-all (combined central + sub-central).
cit_statutory <- cit_stat_raw |>
  filter(MEASURE == "CIT") |>
  transmute(jurisdiction = REF_AREA, year = TIME_PERIOD,
            rate_kind = if_else(TARGETING == "ST", "standard", "top_all"),
            value     = OBS_VALUE) |>
  pivot_wider(names_from = rate_kind, values_from = value,
              names_prefix = "cit_") |>
  arrange(jurisdiction, year)

assert_unique_keys(cit_statutory, c("jurisdiction", "year"), "CIT-statutory")
saveRDS(cit_statutory, file.path(OUT, "cit_statutory.rds"))
add_diag("cit_statutory", "rows", nrow(cit_statutory))
add_diag("cit_statutory", "jurisdictions", n_distinct(cit_statutory$jurisdiction))

# OECD combined dividend tax rates (kept long because of many measure codes).
div_raw <- read_oecd(file.path(RAW, "oecd_tax_rates/oecd_combined_dividend_rates.csv"))
cit_dividend <- div_raw |>
  transmute(jurisdiction = REF_AREA, year = TIME_PERIOD,
            measure = MEASURE, value = OBS_VALUE) |>
  arrange(jurisdiction, year, measure)
saveRDS(cit_dividend, file.path(OUT, "cit_dividend.rds"))
add_diag("cit_dividend", "rows", nrow(cit_dividend))

# =============================================================================
# 8. OECD forward-looking ETRs (kept long; many scenario / asset dimensions)
# =============================================================================
message("[8/12] OECD forward-looking ETRs")
read_etr <- function(path, scenario) {
  read_oecd(path) |>
    transmute(scenario_file = scenario,
              jurisdiction = REF_AREA, year = TIME_PERIOD,
              measure = MEASURE, asset_type = ETR_TAX_BASIS,
              etr_scenario = ETR_SCENARIO, tax_type = ETR_TAX_TYPE,
              regime = REGIME, regime_name = REGIME_NAME,
              value = OBS_VALUE)
}
etr_forward <- bind_rows(
  read_etr(file.path(RAW, "oecd_etr/oecd_etr_baseline.csv"),               "baseline"),
  read_etr(file.path(RAW, "oecd_etr/oecd_etr_income_incentives.csv"),      "income_incentives"),
  read_etr(file.path(RAW, "oecd_etr/oecd_etr_expenditure_incentives.csv"), "expenditure_incentives")
)
saveRDS(etr_forward, file.path(OUT, "etr_forward.rds"))
add_diag("etr_forward", "rows", nrow(etr_forward))

# =============================================================================
# 9. OECD wages — average annual wages (PPP USD) + hourly earnings (kept long)
# =============================================================================
message("[9/12] OECD wages")
wages_oecd <- read_oecd(file.path(RAW, "oecd_wages/oecd_avg_annual_wages.csv")) |>
  filter(MEASURE == "WG", AGGREGATION_OPERATION == "MEAN") |>
  transmute(jurisdiction = REF_AREA, year = TIME_PERIOD,
            currency = UNIT_MEASURE, price_base = PRICE_BASE,
            base_year = BASE_PER, value = OBS_VALUE) |>
  arrange(jurisdiction, year, currency)
saveRDS(wages_oecd, file.path(OUT, "wages_oecd.rds"))
add_diag("wages_oecd", "rows", nrow(wages_oecd))
add_diag("wages_oecd", "jurisdictions", n_distinct(wages_oecd$jurisdiction))

wages_oecd_hourly <- read_csv(
  file.path(RAW, "oecd_wages/oecd_hourly_earnings.csv"),
  show_col_types = FALSE,
  col_types = cols(
    .default = col_guess(),
    TIME_PERIOD = col_character(),
    OBS_VALUE   = col_double()
  )
) |>
  transmute(
    jurisdiction = REF_AREA,
    time_period  = TIME_PERIOD,
    year         = suppressWarnings(as.integer(str_sub(TIME_PERIOD, 1, 4))),
    measure      = MEASURE,
    unit_measure = UNIT_MEASURE,
    adjustment   = ADJUSTMENT,
    activity     = ACTIVITY,
    sector       = SECTOR,
    frequency    = FREQ,
    base_year    = BASE_PER,
    value        = OBS_VALUE
  ) |>
  arrange(jurisdiction, time_period)
saveRDS(wages_oecd_hourly, file.path(OUT, "wages_oecd_hourly.rds"))
add_diag("wages_oecd_hourly", "rows", nrow(wages_oecd_hourly))

# ILO wages — extends coverage to non-OECD economies for payroll imputation.
ilo_monthly <- read_oecd(file.path(RAW, "ilo_wages/ilo_monthly_earnings.csv")) |>
  transmute(jurisdiction = REF_AREA, year = TIME_PERIOD, sex = SEX,
            sector = ECO, currency = CUR, value = OBS_VALUE)
saveRDS(ilo_monthly, file.path(OUT, "wages_ilo_monthly.rds"))
add_diag("wages_ilo_monthly", "rows", nrow(ilo_monthly))

ilo_hourly <- read_oecd(file.path(RAW, "ilo_wages/ilo_hourly_earnings.csv")) |>
  transmute(jurisdiction = REF_AREA, year = TIME_PERIOD, sex = SEX,
            sector = ECO, currency = CUR, value = OBS_VALUE)
saveRDS(ilo_hourly, file.path(OUT, "wages_ilo_hourly.rds"))
add_diag("wages_ilo_hourly", "rows", nrow(ilo_hourly))

# =============================================================================
# 10. World Bank — income classifications, GDP per capita, population
# =============================================================================
message("[10/12] World Bank")
wb_raw <- read_csv(file.path(RAW, "world_bank/wb_income_classifications.csv"),
                   show_col_types = FALSE)

wb_countries <- wb_raw |>
  filter(region != "Aggregates") |>
  rename(jurisdiction = iso3) |>
  arrange(jurisdiction)

wb_aggregates <- wb_raw |>
  filter(region == "Aggregates") |>
  rename(aggregate_code = iso3)

saveRDS(wb_countries,   file.path(OUT, "wb_classifications.rds"))
saveRDS(wb_aggregates,  file.path(OUT, "wb_aggregates.rds"))
add_diag("wb_classifications", "countries", nrow(wb_countries))
add_diag("wb_classifications", "aggregates", nrow(wb_aggregates))

# NB: the World Bank API ships the GDP and population files with the column
# header "iso3" but populates it with ISO2 codes. Country / aggregate split is
# therefore done by joining on iso2 from wb_classifications.
country_iso2 <- wb_countries$iso2

wb_gdp <- read_csv(file.path(RAW, "world_bank/wb_gdp_per_capita.csv"),
                   show_col_types = FALSE) |>
  rename(iso2 = iso3) |>
  filter(iso2 %in% country_iso2) |>
  left_join(wb_countries |> select(iso2, jurisdiction), by = "iso2") |>
  transmute(jurisdiction, iso2, year = as.integer(year), gdp_pc_usd) |>
  arrange(jurisdiction, year)
saveRDS(wb_gdp, file.path(OUT, "wb_gdp.rds"))
add_diag("wb_gdp", "rows", nrow(wb_gdp))

wb_pop <- read_csv(file.path(RAW, "world_bank/wb_population.csv"),
                   show_col_types = FALSE) |>
  rename(iso2 = iso3) |>
  filter(iso2 %in% country_iso2) |>
  left_join(wb_countries |> select(iso2, jurisdiction), by = "iso2") |>
  transmute(jurisdiction, iso2, year = as.integer(year), population) |>
  arrange(jurisdiction, year)
saveRDS(wb_pop, file.path(OUT, "wb_population.rds"))
add_diag("wb_population", "rows", nrow(wb_pop))

# =============================================================================
# 11. Eurostat inward FATS — pre/post-2021 split (structural break in 2021)
# =============================================================================
message("[11/12] Eurostat FATS")
fats_raw <- read_csv(
  file.path(RAW, "eurostat_fats/fats_inward_eu_full.csv.gz"),
  show_col_types = FALSE,
  col_types = cols(.default = col_character(),
                   time_period = col_integer(),
                   obs_value   = col_double())
)

# Pre-2021: legacy aggregate, used for descriptive trend work only.
fats_pre2021 <- fats_raw |>
  filter(source_dataset == "fats_g1b_08") |>
  transmute(geo, c_ctrl, nace_r2, year = time_period,
            indicator = tolower(indicator_code), value = obs_value) |>
  pivot_wider(names_from = indicator, values_from = value,
              names_prefix = "ind_") |>
  arrange(geo, c_ctrl, nace_r2, year)
saveRDS(fats_pre2021, file.path(OUT, "fats_pre2021.rds"))
add_diag("fats_pre2021", "rows", nrow(fats_pre2021))

# Post-2021: NACE-detailed activities — basis for the sectoral SBIE work.
fats_post2021 <- fats_raw |>
  filter(source_dataset == "fats_activ") |>
  transmute(geo, c_ctrl, nace_r2, year = time_period,
            indicator = tolower(indicator_code), value = obs_value) |>
  pivot_wider(names_from = indicator, values_from = value,
              names_prefix = "ind_") |>
  arrange(geo, c_ctrl, nace_r2, year)
saveRDS(fats_post2021, file.path(OUT, "fats_post2021.rds"))
add_diag("fats_post2021", "rows", nrow(fats_post2021))
add_diag("fats_post2021", "eu27_reporters",
         length(intersect(EU27_ISO2, unique(fats_post2021$geo))))

# Coverage of post-2021 FATS by EU Member State × year × NACE depth.
fats_coverage <- fats_post2021 |>
  filter(geo %in% EU27_ISO2) |>
  group_by(geo, year) |>
  summarise(n_nace = n_distinct(nace_r2),
            n_partner_countries = n_distinct(c_ctrl),
            n_obs = n(), .groups = "drop") |>
  arrange(geo, year)
write_csv(fats_coverage, file.path(DIAG, "fats_post2021_eu27_coverage.csv"))

# =============================================================================
# 12. Pillar Two trackers + BEPS rules + CIT revenue
# =============================================================================
message("[12/12] PwC tracker, BEPS rules, CIT revenue")
pwc <- read_csv(file.path(RAW, "pillar2_qdmtt/pwc_pillar2_tracker.csv"),
                show_col_types = FALSE)
# The PwC export carries a leading BOM and many trailing empty columns.
pwc_clean <- pwc |>
  select(territory = 1, requirement = `Requirement`,
         requirement_group = `Requirement Group`,
         p2_start = `P2 Start`, p2_end = `P2 End`,
         fy_start_mths_plus = `FY Start Mths+`,
         days_plus = `Days+`, mths_plus = `Mths+`,
         year = Year, month = Month, day = Day,
         caveat = Caveat, description = Description, status = Status) |>
  filter(!is.na(territory))
saveRDS(pwc_clean, file.path(OUT, "pwc_pillar2_tracker.rds"))
add_diag("pwc_pillar2_tracker", "rows", nrow(pwc_clean))
add_diag("pwc_pillar2_tracker", "territories", n_distinct(pwc_clean$territory))

# OECD BEPS rules — five panel rule types stacked, kept long with a `rule` key.
# Values are categorical ("Yes"/"No"/regime label), so OBS_VALUE stays character.
read_beps <- function(path) {
  read_csv(path, show_col_types = FALSE,
           col_types = cols(.default = col_character(),
                            TIME_PERIOD = col_integer()))
}
beps_files <- c(
  cfc                  = "oecd_cfc_rules.csv",
  interest_limitation  = "oecd_interest_limitation.csv",
  ip_regimes           = "oecd_ip_regimes.csv",
  hybrid_mismatch      = "oecd_hybrid_mismatch.csv",
  mandatory_disclosure = "oecd_mandatory_disclosure.csv"
)
beps_rules <- imap_dfr(beps_files, ~ read_beps(file.path(RAW, "pillar2_beps", .x)) |>
  transmute(rule = .y, jurisdiction = REF_AREA, year = TIME_PERIOD,
            measure = MEASURE, regime = REGIME, value = OBS_VALUE))
saveRDS(beps_rules, file.path(OUT, "beps_rules.rds"))
add_diag("beps_rules", "rows", nrow(beps_rules))
add_diag("beps_rules", "rule_types", n_distinct(beps_rules$rule))

# CbCR Action 13 implementation requirements (different schema: no time series).
cbcr_req <- read_csv(file.path(RAW, "pillar2_beps/oecd_cbcr_requirements.csv"),
                     show_col_types = FALSE,
                     col_types = cols(.default = col_character())) |>
  transmute(jurisdiction = REF_AREA, measure = MEASURE, value = OBS_VALUE)
saveRDS(cbcr_req, file.path(OUT, "cbcr_requirements.rds"))
add_diag("cbcr_requirements", "rows", nrow(cbcr_req))

# OECD comparative tax revenue statistics (CIT revenue / GDP among others).
cit_revenue <- read_oecd(file.path(RAW, "oecd_cts_additional/oecd_cit_revenue_gdp.csv")) |>
  transmute(jurisdiction = REF_AREA, year = TIME_PERIOD, measure = MEASURE,
            sector = SECTOR, revenue_classification = STANDARD_REVENUE,
            unit = UNIT_MEASURE, value = OBS_VALUE)
saveRDS(cit_revenue, file.path(OUT, "cit_revenue.rds"))
add_diag("cit_revenue", "rows", nrow(cit_revenue))

# =============================================================================
# Diagnostics summary
# =============================================================================
diagnostics_df <- bind_rows(diagnostics)
write_csv(diagnostics_df, file.path(DIAG, "summary.csv"))

message("\nDiagnostics summary:")
print(diagnostics_df, n = Inf)

message(sprintf("\nDone. %d intermediate files written to %s/",
                length(list.files(OUT, pattern = "\\.rds$")), OUT))
