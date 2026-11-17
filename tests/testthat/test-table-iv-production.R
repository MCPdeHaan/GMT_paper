t4_production <- source_pipeline("10_accounting_bridge_and_conduit_wedge.R", new.env())
t4_uncertainty <- source_pipeline("07a_uncertainty.R", new.env())

test_that("Table IV policy is independent of the other scientific switches", {
  withr::local_envvar(GMT_TABLE_IV_SPECIFICATION = NA,
    GMT_STATUTORY_RATE_SPECIFICATION = "LEGACY_TARGETED", GMT_BEHAVIOURAL_SPECIFICATION = "BASELINE_NOTCH")
  expect_identical(table_iv_specification(), "OBSERVED_TWO_SIDED")
  expect_identical(table_iv_specification("LEGACY_PUBLISHED"), "LEGACY_PUBLISHED")
  expect_error(table_iv_specification("unknown"), "arg")
  expect_false(t4_uncertainty$reuse_measurement_error_cache("unused"))
  expect_identical(statutory_rate_specification(), "LEGACY_TARGETED")
  expect_identical(behavioural_specification(), "BASELINE_NOTCH")
})

test_that("OECD measure provenance preserves status, units and keyed numeric values", {
  raw <- tibble::tibble(
    REF_AREA = "USA", COUNTERPART_AREA = "KAZ", TIME_PERIOD = 2023L,
    EFFECTIVE_TAX_RATE = c("RATE_0-15", "RATE_0-15", "RATE_15", "RATE_15"),
    MEASURE = c("PROFIT", "TAX_ACCRUED", "PROFIT", "TAX_PAID"),
    OBS_STATUS = c("A", "Q", "A", "A"), OBS_VALUE = c(100, NA_real_, 0, NA_real_),
    UNIT_MEASURE = "USD"
  )
  saved <- serialize(raw, NULL)
  provenance <- t4_production$t4_measure_provenance(raw, "test-vintage")
  expect_identical(provenance$original_bracket, raw$EFFECTIVE_TAX_RATE)
  expect_identical(provenance$observation_status, raw$OBS_STATUS)
  expect_identical(provenance$suppressed, c(FALSE, TRUE, FALSE, FALSE))
  expect_identical(provenance$observed_zero, c(FALSE, FALSE, TRUE, FALSE))
  expect_identical(provenance$missing_unclassified, c(FALSE, FALSE, FALSE, TRUE))
  expect_true(all(provenance$source_vintage == "test-vintage"))
  expect_error(t4_production$t4_measure_provenance(rbind(raw, raw[1, ]), "test"), "duplicate key")
  altered <- raw
  altered$UNIT_MEASURE[1] <- "EUR"
  expect_error(t4_production$t4_measure_provenance(altered, "test"), "USD")
  cleaned <- tibble::tibble(parent = "USA", affiliate = "KAZ", year = 2023L,
    etr_bracket = c("rate_0_15", "rate_15"), profit = c(100, 0),
    tax_accrued = NA_real_, tax_paid = NA_real_)
  expect_true(t4_production$t4_validate_measure_link(cleaned, provenance))
  components <- t4_production$t4_component_ledger(cleaned, provenance)
  expect_identical(components$status_tax_accrued, c("explicit_suppression", "absent_measure"))
  expect_identical(serialize(raw, NULL), saved)
})

test_that("one-sided reports and missing measures are separate support failures", {
  clean <- tibble::tribble(
    ~parent, ~affiliate, ~year, ~etr_bracket, ~profit, ~tax_accrued, ~tax_paid,
    "USA", "KAZ", 2023L, "rate_0_15", 100, NA_real_, 5,
    "GRC", "KAZ", 2023L, "rate_0_15", 100, 0, -1,
    "GRC", "KAZ", 2023L, "rate_15", 100, 20, 20,
    "USA", "IRL", 2020L, "rate_0_15", 20, 0, 1,
    "USA", "FRA", 2020L, "rate_0_15", 0, NA_real_, NA_real_,
    "USA", "FRA", 2020L, "rate_15", 50, 12, 12,
    "USA", "NLD", 2020L, "rate_0_15", 50, 1, 1,
    "USA", "NLD", 2020L, "rate_15", 50, 12, 12,
    "USA", "NLD", 2020L, "rate_10_20", 50, 8, 8,
    "USA", "ITA", 2020L, "rate_0_15", 50, 1, 1,
    "USA", "ITA", 2020L, "rate_30", 50, 20, 20
  )
  pool <- function(x, accrued = TRUE) {
    t4_production$t4_partition_support(t4_production$t4_component_ledger(x),
      t4_production$T4_HOST_KEYS, accrued = accrued)
  }
  accrued <- pool(clean)
  kaz <- dplyr::filter(accrued, affiliate == "KAZ")
  expect_true(kaz$share_available)
  expect_false(kaz$gap_available)
  expect_false(kaz$published_measures_complete)
  expect_equal(kaz$observed_low_tax, 0)
  expect_equal(kaz$unidentified_tax_profit, 100)
  expect_identical(kaz$rejection_reason, "missing_tax_on_positive_low_profit")
  expect_true(dplyr::filter(accrued, affiliate == "IRL")$published_measures_complete)
  expect_identical(dplyr::filter(accrued, affiliate == "IRL")$rejection_reason, "absent_upper_bracket")
  expect_true(dplyr::filter(accrued, affiliate == "FRA")$complete_direct)
  expect_false(dplyr::filter(accrued, affiliate == "FRA")$low_etr_available)
  expect_identical(dplyr::filter(accrued, affiliate == "NLD")$rejection_reason, "incompatible_or_absent_schedule")
  expect_identical(dplyr::filter(accrued, affiliate == "ITA")$rejection_reason, "incompatible_or_absent_schedule")
  tax <- t4_production$bridge_tax
  cash <- dplyr::mutate(clean, tax_accrued = tax(tax_accrued, tax_paid, "T2_cash"))
  envelope <- dplyr::mutate(clean, tax_accrued = tax(tax_accrued, tax_paid, "T3_envelope"))
  expect_false(dplyr::filter(pool(cash, FALSE), affiliate == "KAZ")$complete_direct)
  expect_true(dplyr::filter(pool(envelope, FALSE), affiliate == "KAZ")$complete_direct)
  expect_equal(dplyr::filter(pool(envelope, FALSE), affiliate == "KAZ")$observed_low_tax, 5)
})

test_that("transitional criteria retain evidence even if bracket tax is missing", {
  data <- tibble::tibble(parent = "USA", affiliate = "KAZ", year = 2023L, affiliate_wage_annual = 100)
  low <- dplyr::select(data, -affiliate_wage_annual) |>
    dplyr::mutate(profit = 10000, tot_rev = 100000, subgroups_count = 1,
      tax_accrued = NA_real_, tax_paid = 1900, employees = 0, assets = 0)
  policy <- dplyr::filter(t4_production$BRIDGE_SAFE_YEARS, policy_year == 2026L)
  accrued <- t4_production$bridge_safe_tests(data, policy, "table4_low_bracket", "T1_accrued", low)
  envelope <- t4_production$bridge_safe_tests(data, policy, "table4_low_bracket", "T3_envelope", low)
  expect_true(accrued$de_minimis)
  expect_false(accrued$routine)
  expect_identical(accrued$simplified, NA)
  expect_true(accrued$any_pass)
  expect_true(accrued$missing_test_inputs)
  expect_true(envelope$simplified)
})

test_that("the processed Table IV contract is versioned with the reference", {
  changed <- uses_revised_table_iv()
  expect_identical(file.exists(processed_path(t4_production$T4_PROVENANCE_FILE)), changed)
  expect_identical(file.exists(processed_path(t4_production$T4_HOST_SUPPORT_FILE)), changed)
  expect_identical(file.exists(processed_path(t4_production$T4_BILATERAL_SUPPORT_FILE)), changed)
  if (changed) {
    metadata <- utils::read.csv(processed_path("diagnostics", T4_SPECIFICATION_FILE))
    expect_identical(metadata$specification, "OBSERVED_TWO_SIDED")
    expect_identical(metadata$production_direct, 356L)
    expect_identical(metadata$production_anchor_hosts, 88L)
    host <- readRDS(processed_path("stage1_affiliate_year.rds"))
    expect_equal(sum(host$direct_available & host$affiliate_is_eu27), 114)
    pair <- readRDS(processed_path("stage1_bilateral_panel.rds"))
    expect_equal(sum(pair$ladder_l4_strict_source == "exact_table_iv"), 582)
    expect_equal(sum(pair$stage1_distributional_source == "shape_transport"), 3119)
    expect_true(all(is.na(host$stage1_distributional_liability_rate[host$stage1_distributional_source == "missing"])))
    status <- readRDS(processed_path(t4_production$T4_PROVENANCE_FILE))
    expect_equal(sum(status$suppressed), 212)
    expect_false(anyDuplicated(status[c(t4_production$T4_COMPONENT_KEYS, "measure")]) > 0)
  }
})
