# OECD rates are fractions here. Historical cleaning aliases are percentages.
STATUTORY_CAP_ALLOWANCE <- 0.05
STATUTORY_RATE_SPECIFICATION_FILE <- "step1_statutory_rate_specification.csv"
statutory_rate_specification <- function(name = Sys.getenv("GMT_STATUTORY_RATE_SPECIFICATION",
  unset = "STANDARD_ROLE_SPECIFIC")) {
  match.arg(name, c("STANDARD_ROLE_SPECIFIC", "LEGACY_TARGETED"))
}

standard_statutory_rate <- function(combined, central) {
  tibble::tibble(
    rate = dplyr::coalesce(combined, central),
    source = dplyr::case_when(
      !is.na(combined) ~ "standard_combined",
      !is.na(central) ~ "standard_central_fallback",
      TRUE ~ "missing"
    )
  )
}

statistical_etr_ceiling <- function(rate, allowance = STATUTORY_CAP_ALLOWANCE) {
  pmin(1, dplyr::coalesce(rate + allowance, 1))
}

regularise_bilateral_etr <- function(raw_etr, ceiling) {
  dplyr::case_when(
    is.na(raw_etr) | raw_etr < -ZETA_LOSS_OFFSET ~ NA_real_,
    raw_etr < 0 ~ 0,
    TRUE ~ pmin(raw_etr, ceiling)
  )
}

read_statutory_rate_observations <- function(raw, input_sha256) {
  codes <- tibble::tribble(
    ~MEASURE, ~SECTOR, ~TARGETING, ~series,
    "CIT", "S1311", "TA", "cit_targeted_central",
    "CIT", "S1311", "ST", "cit_standard_central",
    "CIT_C", "S13", "ST", "cit_standard_combined"
  )
  selected <- dplyr::inner_join(raw, codes,
    by = c("MEASURE", "SECTOR", "TARGETING"), relationship = "many-to-one")
  stopifnot(nrow(selected) > 0, all(selected$FREQ == "A"),
    all(selected$UNIT_MEASURE == "PT_INC_TAX"), all(selected$UNIT_MULT == 0),
    all(selected$DIV_TREATMENT == "_Z"), all(selected$RATE_STRUCTURE == "_Z"),
    all(selected$TAX_BASE == "_Z"), all(grepl("^[A-Z0-9]{3}$", selected$REF_AREA)),
    all(is.finite(selected$TIME_PERIOD)))
  rates <- dplyr::transmute(selected,
    jurisdiction = normalize_code(REF_AREA), year = as.integer(TIME_PERIOD), series,
    oecd_area = REF_AREA, measure = MEASURE, sector = SECTOR, targeting = TARGETING,
    observation_status = OBS_STATUS, recorded_percent = OBS_VALUE,
    valid = is.finite(OBS_VALUE) & dplyr::between(OBS_VALUE, 0, 100),
    rate = dplyr::if_else(valid, OBS_VALUE / 100, NA_real_),
    dataflow = DATAFLOW, input_sha256 = input_sha256
  )
  assert_unique_keys(rates, c("jurisdiction", "year", "series"), "Statutory-rate observations")
  dplyr::arrange(rates, jurisdiction, year, series)
}

statutory_rate_panel <- function(observations) {
  rates <- observations |>
    dplyr::select(jurisdiction, year, series, rate) |>
    tidyr::pivot_wider(names_from = series, values_from = rate)
  selected <- standard_statutory_rate(rates$cit_standard_combined, rates$cit_standard_central)
  dplyr::mutate(rates,
    cit_reconciliation_prior_rate = dplyr::coalesce(cit_targeted_central, cit_standard_central),
    cit_reconciliation_prior_rate_source = dplyr::case_when(
      !is.na(cit_targeted_central) ~ "targeted_central",
      !is.na(cit_standard_central) ~ "standard_central_fallback",
      TRUE ~ "missing"
    ),
    cit_destination_gate_rate = cit_reconciliation_prior_rate,
    cit_destination_gate_rate_source = cit_reconciliation_prior_rate_source,
    cit_statistical_rate = selected$rate,
    cit_statistical_rate_source = selected$source,
    cit_statistical_ceiling = statistical_etr_ceiling(selected$rate),
    cit_statistical_ceiling_source = dplyr::if_else(is.na(selected$rate),
      "unit_ceiling", selected$source),
    cit_robustness_rate = cit_standard_combined,
    cit_robustness_rate_source = dplyr::if_else(is.na(cit_standard_combined), "missing", "standard_combined"),
    cit_destination_price_rate = selected$rate,
    cit_destination_price_rate_source = selected$source
  )
}

# Historical objects lack the role fields. A role field with a missing rate
# retains that missingness. The numerical ceiling alone can fall back to one.
panel_statutory_rate <- function(data, role, jurisdiction = "affiliate") {
  role <- match.arg(role, c("historical", "reconciliation_prior", "statistical",
    "robustness", "destination_gate", "destination_price"))
  legacy <- paste0(jurisdiction, "_cit_rate_unit")
  field <- paste0(jurisdiction, "_cit_", role, "_rate")
  if (field %in% names(data)) data[[field]] else data[[legacy]]
}

panel_statistical_ceiling <- function(data) {
  if ("affiliate_cit_statistical_ceiling" %in% names(data)) {
    return(dplyr::coalesce(data$affiliate_cit_statistical_ceiling, 1))
  }
  statistical_etr_ceiling(data$affiliate_cit_rate_unit, ZETA_LOSS_OFFSET)
}

statutory_rate_metadata <- function(processed = PROCESSED_DIR) {
  path <- file.path(processed, "diagnostics", STATUTORY_RATE_SPECIFICATION_FILE)
  if (!file.exists(path)) return(NULL)
  metadata <- utils::read.csv(path, stringsAsFactors = FALSE)
  stopifnot(nrow(metadata) == 1L,
    identical(statutory_rate_specification(metadata$specification), metadata$specification))
  metadata
}

# The statutory-rate revision holds the applied structural coefficient fixed.
# The refitted ETR regression and its standard error remain available as estimates.
applied_preferred_beta <- function(estimate, processed = PROCESSED_DIR) {
  metadata <- statutory_rate_metadata(processed)
  if (is.null(metadata)) return(estimate)
  beta <- as.numeric(metadata$applied_beta_hex)
  stopifnot(length(beta) == 1L, is.finite(beta))
  beta
}

destination_price_lookup <- function(panel, rate = "destination_price", include_parents = FALSE) {
  affiliates <- dplyr::transmute(panel,
    destination = affiliate, year, price_rate = panel_statutory_rate(panel, rate))
  if (include_parents) {
    affiliates <- dplyr::bind_rows(affiliates, dplyr::transmute(panel,
      destination = parent, year, price_rate = panel_statutory_rate(panel, rate, "parent")))
  }
  result <- dplyr::distinct(affiliates)
  assert_unique_keys(result, c("destination", "year"), "Destination pricing rates")
  result
}

attach_destination_prices <- function(routes, prices, amount, require_support = TRUE) {
  priced <- dplyr::left_join(routes, prices, by = c("destination", "year"),
    relationship = "many-to-one")
  if (require_support && any(priced[[amount]] > 0 & !is.finite(priced$price_rate))) {
    stop("Selected statutory pricing is missing for positive destination profit")
  }
  priced
}
