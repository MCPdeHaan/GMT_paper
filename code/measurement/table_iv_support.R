# Table IV source and support contracts. Uses the shared GMT helpers and constants.

T4_HOST_KEYS <- c("affiliate", "year")
T4_COMPONENT_KEYS <- c("parent", "affiliate", "year", "etr_bracket")
T4_POINT_MEASURES <- c("profit", "tax_accrued", "tax_paid")
T4_PROVENANCE_FILE <- "cbcr_table4_measure_provenance.rds"
T4_HOST_SUPPORT_FILE <- "base_panel_t4_host_support.rds"
T4_BILATERAL_SUPPORT_FILE <- "base_panel_t4_bilateral_support.rds"

t4_reporting_schedule <- function(bracket) {
  case_when(
    bracket %in% c("rate_0_15", "rate_15") ~ "split_at_15",
    bracket %in% c("rate_20_30", "rate_30") ~ "upper_tail_only",
    bracket %in% c("negative_profit", "negative_tax_accrued") ~ "non_partition_category",
    TRUE ~ "other_schedule"
  )
}

t4_measure_provenance <- function(raw, source_vintage) {
  out <- raw |>
    transmute(parent = REF_AREA, affiliate = COUNTERPART_AREA, year = as.integer(TIME_PERIOD),
      etr_bracket = gsub("[-[:space:]]", "_", tolower(EFFECTIVE_TAX_RATE)),
      original_bracket = EFFECTIVE_TAX_RATE, measure = tolower(MEASURE), original_measure = MEASURE,
      value = OBS_VALUE, observation_status = OBS_STATUS, unit = UNIT_MEASURE,
      source_vintage = source_vintage,
      reporting_schedule = t4_reporting_schedule(etr_bracket),
      row_exists = TRUE, measure_exists = TRUE, finite = is.finite(value),
      observed_zero = finite & value == 0,
      suppressed = observation_status %in% "Q" & is.na(value) & !is.nan(value),
      status = case_when(
        suppressed ~ "explicit_suppression",
        finite ~ "observed",
        is.nan(value) | is.infinite(value) ~ "invalid",
        TRUE ~ "missing_unclassified"
      ), missing_unclassified = status == "missing_unclassified") |>
    arrange(parent, affiliate, year, etr_bracket, measure)
  assert_unique_keys(out, c(T4_COMPONENT_KEYS, "measure"), "Table IV OECD measure")
  stopifnot(all(out$unit[out$measure %in% T4_POINT_MEASURES] == "USD"))
  out
}

t4_pinned_status <- function(raw) {
  # The minimal R10a interface also accepts small extracts without unit metadata.
  if (!"UNIT_MEASURE" %in% names(raw)) raw$UNIT_MEASURE <- "USD"
  t4_measure_provenance(raw, NA_character_) |>
    filter(measure %in% T4_POINT_MEASURES) |>
    select(all_of(T4_COMPONENT_KEYS), measure, value, status)
}

t4_validate_measure_link <- function(clean, provenance) {
  for (name in T4_POINT_MEASURES) {
    raw <- filter(provenance, measure == name)
    match <- inner_join(raw, select(clean, all_of(T4_COMPONENT_KEYS), all_of(name)),
      by = T4_COMPONENT_KEYS, relationship = "one-to-one")
    stopifnot(nrow(match) == nrow(raw), identical(match$value, match[[name]]),
      all(is.na(anti_join(clean, raw, by = T4_COMPONENT_KEYS)[[name]])))
  }
  invisible(TRUE)
}

t4_component_ledger <- function(clean, status = NULL) {
  assert_unique_keys(clean, T4_COMPONENT_KEYS, "Table IV bracket")
  components <- select(clean, all_of(T4_COMPONENT_KEYS), profit, tax_accrued, tax_paid)
  if (!is.null(status)) {
    assert_unique_keys(status, c(T4_COMPONENT_KEYS, "measure"), "Table IV raw measure")
    evidence <- status |>
      filter(measure %in% T4_POINT_MEASURES) |>
      transmute(across(all_of(T4_COMPONENT_KEYS)),
        measure = factor(measure, levels = T4_POINT_MEASURES), status) |>
      pivot_wider(names_from = measure, values_from = status, names_prefix = "status_",
        names_expand = TRUE, values_fill = "absent_measure")
    components <- left_join(components, evidence, by = T4_COMPONENT_KEYS,
      relationship = "one-to-one")
  } else {
    components <- mutate(components, across(c(profit, tax_accrued, tax_paid),
      ~ case_when(is.nan(.x) | is.infinite(.x) ~ "invalid", is.na(.x) ~ "missing_unclassified",
        TRUE ~ "observed"), .names = "status_{.col}"))
  }
  components |>
    mutate(across(starts_with("status_"), ~ coalesce(.x, "absent_measure")),
      component_class = case_when(
        is.nan(profit) | is.nan(tax_accrued) | is.infinite(profit) |
          is.infinite(tax_accrued) ~ "non_finite",
        etr_bracket == "negative_tax_accrued" & tax_accrued < 0 ~ "negative_accrued_category",
        etr_bracket %in% T4_DIRECT_POSITIVE_BRACKETS &
          (profit < 0 | (etr_bracket == "rate_0_15" & tax_accrued < 0)) ~ "invalid_sign",
        is.na(profit) & is.na(tax_accrued) ~ "missing_profit_and_tax",
        is.na(profit) ~ "missing_profit_observed_tax",
        profit == 0 & is.na(tax_accrued) ~ "zero_profit_missing_tax",
        profit == 0 & tax_accrued == 0 ~ "zero_profit_zero_tax",
        profit > 0 & is.na(tax_accrued) ~ "positive_profit_missing_tax",
        profit > 0 & tax_accrued == 0 ~ "positive_profit_zero_tax",
        profit > 0 & tax_accrued > 0 ~ "positive_profit_positive_tax",
        TRUE ~ "other_observed"
      )) |>
    arrange(parent, affiliate, year, etr_bracket)
}

# A pool's screened point concerns the published, compatible population.
# Unknown attendance and alternative bracket schedules are reported separately.
t4_partition_support <- function(components, keys, numerator = "tax_accrued",
                                 accrued = numerator == "tax_accrued") {
  assert_unique_keys(components, T4_COMPONENT_KEYS, "Table IV bracket")
  direct_years <- filter(components, year %in% DIRECT_YEARS)
  # The ≥15 bin and historical upper-tail bins cannot both carry positive
  # profit in one reporter's partition. Tail bins alone leave 15–20 unknown.
  incompatible <- direct_years |>
    mutate(schedule = t4_reporting_schedule(etr_bracket)) |>
    summarise(
      incompatible_rows = sum(schedule == "other_schedule" & startsWith(etr_bracket, "rate_")) +
        sum(schedule == "upper_tail_only" &
          (!any(etr_bracket == "rate_15") | !coalesce(profit == 0, FALSE))),
      .by = c(parent, affiliate, year)
    ) |>
    filter(incompatible_rows > 0L) |>
    summarise(incompatible_rows = sum(incompatible_rows), .by = all_of(keys))
  support <- direct_years |>
    filter(etr_bracket %in% T4_DIRECT_POSITIVE_BRACKETS) |>
    mutate(low = etr_bracket == "rate_0_15", tax = .data[[numerator]],
      profit_valid = is.finite(profit) & profit >= 0, profit_positive = profit_valid & profit > 0,
      tax_valid = is.finite(tax) & tax >= 0,
      low_positive_with_tax = low & profit_positive & tax_valid,
      low_positive_missing_tax = low & profit_positive & is.na(tax) & !is.nan(tax),
      low_tax_problem = low & (!profit_valid | (profit_positive & !tax_valid) |
        (profit_valid & profit == 0 & !is.na(tax) & (!tax_valid | tax != 0)) | is.nan(tax))) |>
    summarise(
      parents = n_distinct(parent), rows = n(), lower_rows = sum(low), upper_rows = sum(!low),
      lower_observed = sum(low & profit_valid), upper_observed = sum(!low & profit_valid),
      lower_missing = sum(low & !profit_valid), upper_missing = sum(!low & !profit_valid),
      invalid_profit = sum(is.nan(profit) | is.infinite(profit) | coalesce(profit < 0, FALSE)),
      invalid_lower_tax = sum(low & (is.nan(tax) | is.infinite(tax) | coalesce(tax < 0, FALSE))),
      lower_tax_problems = sum(low_tax_problem),
      positive_low_tax_missing = sum(low_positive_missing_tax),
      observed_profit_components = sum(profit_valid),
      missing_profit_components = sum(is.na(profit) & !is.nan(profit)),
      suppressed_profit_components = sum(status_profit == "explicit_suppression"),
      unclassified_profit_components = sum(status_profit == "missing_unclassified"),
      absent_profit_measures = sum(status_profit == "absent_measure"),
      observed_zero_profit_components = sum(profit_valid & profit == 0, na.rm = TRUE),
      observed_low_tax_components = sum(low & tax_valid),
      missing_low_tax_components = sum(low & is.na(tax) & !is.nan(tax)),
      absent_low_tax_measures = sum(low & status_tax_accrued == "absent_measure"),
      zero_low_tax_observed = sum(low & profit_positive & tax_valid & tax == 0, na.rm = TRUE),
      positive_low_tax_observed = sum(low_positive_with_tax),
      low_tax_suppressed = sum(low & status_tax_accrued == "explicit_suppression"),
      low_tax_blank = sum(low & status_tax_accrued == "missing_unclassified"),
      observed_profit = sum_or_na(profit[profit_valid]),
      observed_low_profit = sum_or_na(profit[low & profit_valid]),
      observed_upper_profit = sum_or_na(profit[!low & profit_valid]),
      observed_low_tax = sum_or_na(tax[low & tax_valid]),
      unidentified_tax_profit = sum(profit[low_positive_missing_tax]),
      incompatible_low_rate = any(tax[low_positive_with_tax] >
        GMT_RATE * profit[low_positive_with_tax]),
      .by = all_of(keys))
  full_join(support, incompatible, by = keys, relationship = "one-to-one") |>
    mutate(incompatible_rows = coalesce(incompatible_rows, 0L),
      across(c(rows, lower_rows, upper_rows, lower_observed, upper_observed, lower_missing,
        upper_missing, lower_tax_problems, invalid_lower_tax, invalid_profit,
        positive_low_tax_missing, positive_low_tax_observed), ~ coalesce(.x, 0L)),
      incompatible_low_rate = coalesce(incompatible_low_rate, FALSE)) |>
    mutate(absent_lower = lower_rows == 0L, absent_upper = upper_rows == 0L,
      mixed_profit = lower_observed + upper_observed > 0 & lower_missing + upper_missing > 0,
      mixed_low_tax = positive_low_tax_observed > 0 & positive_low_tax_missing > 0,
      all_positive_low_tax_missing = positive_low_tax_observed == 0 & positive_low_tax_missing > 0,
      compatible_schedule = rows > 0 & incompatible_rows == 0L,
      denominator_available = compatible_schedule & lower_observed > 0 & upper_observed > 0 &
        lower_missing + upper_missing == 0 & coalesce(observed_profit > 0, FALSE),
      low_profit_available = lower_observed > 0 & lower_missing == 0,
      share_available = denominator_available & low_profit_available,
      low_tax_available = low_profit_available & lower_tax_problems == 0 &
        coalesce(observed_low_profit == 0 | is.finite(observed_low_tax), FALSE),
      gap_available = low_tax_available & (!accrued | !incompatible_low_rate),
      low_etr_available = gap_available & coalesce(observed_low_profit > 0, FALSE),
      complete_profit = denominator_available,
      complete_direct = share_available & gap_available,
      published_measures_complete = compatible_schedule & lower_missing + upper_missing == 0 &
        lower_tax_problems == 0 & !incompatible_low_rate,
      rejection_reason = case_when(
        complete_direct ~ "eligible",
        !compatible_schedule ~ "incompatible_or_absent_schedule",
        lower_missing > 0 & upper_missing > 0 ~ "invalid_or_missing_profit_both_sides",
        lower_missing > 0 ~ "invalid_or_missing_lower_profit",
        upper_missing > 0 ~ "invalid_or_missing_upper_profit",
        positive_low_tax_missing > 0 & absent_upper ~ "missing_low_tax_and_absent_upper",
        positive_low_tax_missing > 0 ~ "missing_tax_on_positive_low_profit",
        lower_tax_problems > 0 | (accrued & incompatible_low_rate) ~ "invalid_lower_tax",
        absent_lower ~ "absent_lower_bracket",
        absent_upper ~ "absent_upper_bracket",
        TRUE ~ "non_positive_denominator"
      ),
      support = case_when(complete_direct ~ "complete_published_partition",
        lower_observed + upper_observed > 0 ~ "partial_direct_information",
        TRUE ~ "unsupported_direct_information"))
}

t4_partial_bounds <- function(support) {
  support |>
    mutate(
      low_known = lower_observed > 0 & lower_missing == 0,
      upper_known = upper_observed > 0 & upper_missing == 0,
      share_lo = if_else(complete_profit, observed_low_profit / observed_profit, 0),
      share_hi = case_when(
        complete_profit ~ share_lo,
        low_known & observed_low_profit == 0 ~ 0,
        low_known ~ observed_low_profit / (observed_low_profit + coalesce(observed_upper_profit, 0)),
        TRUE ~ 1
      ),
      # Conditional on published low-bin membership and non-negative rates.
      # Zero-profit components contribute no tax and no gaps are defined for L=0.
      gap_bounded = low_known & observed_low_profit > 0 & invalid_lower_tax == 0 &
        lower_tax_problems == positive_low_tax_missing & !incompatible_low_rate,
      known_low_tax = if_else(gap_bounded, coalesce(observed_low_tax, 0), NA_real_),
      gap_lo = if_else(gap_bounded,
        pmax(0, GMT_RATE - (known_low_tax + GMT_RATE * unidentified_tax_profit) / observed_low_profit),
        NA_real_),
      gap_hi = if_else(gap_bounded, pmax(0, GMT_RATE - known_low_tax / observed_low_profit), NA_real_),
      bracket_topup_lo = observed_low_profit * gap_lo,
      bracket_topup_hi = observed_low_profit * gap_hi,
      liability_rate_lo = if_else(gap_bounded, share_lo * gap_lo, NA_real_),
      liability_rate_hi = if_else(gap_bounded, share_hi * gap_hi, NA_real_)
    )
}

t4_anchor_profiles <- function(partitions, keys) {
  partitions |>
    filter(year %in% BSPI_ANCHOR_YEARS, complete_direct) |>
    arrange(year) |>
    summarise(anchor_years = paste(year, collapse = "+"),
      anchor_profit = sum(observed_profit), anchor_low_profit = sum(observed_low_profit),
      anchor_low_tax = sum(observed_low_tax, na.rm = TRUE), .by = all_of(keys)) |>
    mutate(anchor_share = anchor_low_profit / anchor_profit,
      anchor_gap = if_else(anchor_low_profit > 0,
        GMT_RATE - clamp_interval(anchor_low_tax / anchor_low_profit, 0, GMT_RATE), 0))
}
