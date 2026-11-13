# Shared paths, constants and scenario definitions for the GMT pipeline.

GMT_PROJECT_ROOT <- Sys.getenv("GMT_PROJECT_ROOT", unset = ".")
RAW_DIR <- "data/raw"
GMT_OUTPUT_ROOT <- Sys.getenv("GMT_OUTPUT_ROOT")
PROCESSED_DIR <- if (nzchar(GMT_OUTPUT_ROOT)) {
  file.path(GMT_OUTPUT_ROOT, "data", "processed")
} else {
  "data/processed"
}
DIAGNOSTICS_DIR <- file.path(PROCESSED_DIR, "diagnostics")
GENERATED_DIR <- if (nzchar(GMT_OUTPUT_ROOT)) {
  file.path(GMT_OUTPUT_ROOT, "writing", "generated")
} else {
  "writing/generated"
}
GENERATED_TABLES_DIR <- file.path(GENERATED_DIR, "results_tables")
BASELINE_PROCESSED_DIR <- "data/baseline_processed"
BASELINE_DIAGNOSTICS_DIR <- "data/baseline_diagnostics"
BASELINE_GENERATED_DIR <- "writing/baseline_generated"

MAIN_YEARS <- 2017:2023
CORE_YEARS <- 2016:2023
GMT_RATE <- 0.15
ETR_WINSOR_PROBS <- c(0.01, 0.99)
T4_DIRECT_POSITIVE_BRACKETS <- c("rate_0_15", "rate_15", "rate_20_30", "rate_30")

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
COUNTRY_REVENUE_DIAGNOSTIC_EXCLUDED <- c("CYP", "EST", "LVA", "LTU", "MLT")
COUNTRY_REVENUE_DIAGNOSTIC_COUNTRIES <- base::setdiff(
  EU27_ISO3,
  COUNTRY_REVENUE_DIAGNOSTIC_EXCLUDED
)

SCENARIO_VARS <- c(
  "scenario_id", "rate_scenario", "factor1_etr", "factor2_substance",
  "factor3_rates", "factor4_sbs", "factor5_behaviour", "x1_etr",
  "x2_substance", "x3_rates", "x4_sbs", "x5_behaviour"
)

FACTOR_COLS <- c(
  "x1_etr", "x2_substance", "x3_rates", "x4_sbs", "x5_behaviour"
)

BSPI_ANCHOR_YEARS <- 2019:2020
BSPI_VALIDATION_YEARS <- 2021:2023
BSPI_IMPUTE_YEARS <- 2017:2018
ZETA_LOSS_OFFSET <- 0.05

PROFIT_RECONCILIATION_UPPER_BOUND <- 0.85
PROFIT_RECONCILIATION_EPS_RHO <- 1e-5
PUBLIC_ETR_PARITY_CAP <- 0.555
