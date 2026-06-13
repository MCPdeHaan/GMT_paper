# Shared paths, constants and scenario definitions for the GMT pipeline.

RAW_DIR <- "data/raw"
PROCESSED_DIR <- "data/processed"
DIAGNOSTICS_DIR <- file.path(PROCESSED_DIR, "diagnostics")
GENERATED_DIR <- "writing/generated"
GENERATED_TABLES_DIR <- file.path(GENERATED_DIR, "results_tables")

MAIN_YEARS <- 2017:2022
CORE_YEARS <- 2016:2022
GMT_RATE <- 0.15

EU27_ISO3 <- c(
  "AUT", "BEL", "BGR", "CYP", "CZE", "DEU", "DNK", "ESP", "EST", "FIN",
  "FRA", "GRC", "HRV", "HUN", "IRL", "ITA", "LTU", "LUX", "LVA", "MLT",
  "NLD", "POL", "PRT", "ROU", "SVK", "SVN", "SWE"
)

EU27_ISO2_EUROSTAT <- c(
  "AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "EL", "ES", "FI",
  "FR", "HR", "HU", "IE", "IT", "LT", "LU", "LV", "MT", "NL", "PL",
  "PT", "RO", "SE", "SI", "SK"
)

SELECTED_COUNTRIES <- c("NLD", "IRL", "LUX", "DEU", "FRA")
COUNTRY_CASE_COUNTRIES <- c("DEU", "NLD", "FRA", "LUX", "IRL", "HUN")
SELECTED_FISCAL_COUNTRIES <- COUNTRY_CASE_COUNTRIES

SCENARIO_VARS <- c(
  "scenario_id", "rate_scenario", "factor1_etr", "factor2_substance",
  "factor3_rates", "factor4_sbs", "factor5_behaviour", "x1_etr",
  "x2_substance", "x3_rates", "x4_sbs", "x5_behaviour"
)

FACTOR_COLS <- c(
  "x1_etr", "x2_substance", "x3_rates", "x4_sbs", "x5_behaviour"
)

BSPI_ANCHOR_YEARS <- 2019:2020
BSPI_VALIDATION_YEARS <- 2021:2022
BSPI_IMPUTE_YEARS <- 2017:2018
ZETA_LOSS_OFFSET <- 0.05
