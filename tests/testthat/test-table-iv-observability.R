table_iv <- source_pipeline("diagnostics/table_iv_observability.R", new.env())

t4_fixture <- function() {
  tibble::tribble(
    ~parent, ~affiliate, ~year, ~etr_bracket, ~profit, ~tax_accrued,
    "USA", "IRL", 2019L, "rate_0_15", 100, 5,
    "USA", "IRL", 2019L, "rate_15", 100, 20,
    "USA", "IRL", 2019L, "rate_20_30", 0, 0,
    "USA", "IRL", 2019L, "rate_30", 0, 0,
    "DEU", "IRL", 2019L, "rate_0_15", 50, NA_real_,
    "DEU", "IRL", 2019L, "rate_15", 50, 12,
    "USA", "IRL", 2020L, "rate_0_15", 20, 0,
    "USA", "IRL", 2020L, "rate_15", 80, 16,
    "USA", "IRL", 2020L, "negative_tax_accrued", 10, -5,
    "USA", "FRA", 2020L, "rate_0_15", 0, NA_real_,
    "USA", "FRA", 2020L, "rate_15", 100, 20,
    "USA", "BEL", 2019L, "rate_0_15", NA_real_, 2,
    "USA", "BEL", 2019L, "rate_15", 100, 20,
    "USA", "BEL", 2020L, "rate_15", 100, 20,
    "USA", "ESP", 2020L, "rate_0_15", 20, 0,
    "USA", "ITA", 2020L, "rate_0_15", 40, NA_real_,
    "USA", "ITA", 2020L, "rate_15", 60, 15,
    "USA", "ITA", 2020L, "rate_30", NA_real_, NA_real_,
    "USA", "AUT", 2020L, "rate_0_15", Inf, 0
  ) |>
    dplyr::mutate(tax_paid = NA_real_)
}

test_that("published blanks, suppression, zeros, negative tax and absence retain separate states", {
  raw <- tibble::tribble(
    ~REF_AREA, ~COUNTERPART_AREA, ~TIME_PERIOD, ~EFFECTIVE_TAX_RATE, ~MEASURE, ~OBS_STATUS, ~OBS_VALUE,
    "DEU", "IRL", 2019L, "RATE_0-15", "TAX_ACCRUED", "Q", NA_real_,
    "USA", "FRA", 2020L, "RATE_0-15", "TAX_ACCRUED", "A", NA_real_,
    "USA", "IRL", 2020L, "RATE_0-15", "TAX_ACCRUED", "A", 0,
    "USA", "IRL", 2020L, "RATE_0-15", "PROFIT", "A", 20,
    "USA", "IRL", 2020L, "RATE_0-15", "TAX_PAID", "A", NA_real_
  )
  status <- table_iv$t4_pinned_status(raw)
  fixture <- t4_fixture()
  saved <- serialize(fixture, NULL)
  ledger <- table_iv$t4_component_ledger(fixture, status)
  pick <- function(parent, affiliate, year, bracket = "rate_0_15") {
    dplyr::filter(ledger, .data$parent == .env$parent, .data$affiliate == .env$affiliate,
      .data$year == .env$year, etr_bracket == bracket)
  }
  expect_identical(pick("DEU", "IRL", 2019)$status_tax_accrued, "explicit_suppression")
  expect_identical(pick("USA", "FRA", 2020)$status_tax_accrued, "missing_unclassified")
  expect_identical(pick("USA", "FRA", 2020)$component_class, "zero_profit_missing_tax")
  expect_identical(pick("USA", "IRL", 2020)$component_class, "positive_profit_zero_tax")
  expect_identical(pick("USA", "IRL", 2020, "negative_tax_accrued")$component_class,
    "negative_accrued_category")
  expect_identical(pick("USA", "AUT", 2020)$component_class, "non_finite")
  expect_identical(pick("USA", "ESP", 2020)$status_tax_accrued, "absent_measure")
  expect_identical(pick("USA", "BEL", 2019)$component_class, "missing_profit_observed_tax")
  expect_identical(pick("USA", "BEL", 2020)$component_class, character())
  expect_identical(serialize(fixture, NULL), saved)
  expect_error(table_iv$t4_component_ledger(rbind(fixture, fixture[1, ])), "duplicate key")
  expect_error(table_iv$t4_component_ledger(fixture, rbind(status, status[1, ])), "duplicate key")
})

test_that("pooling does not convert partial coverage into complete direct information", {
  ledger <- table_iv$t4_component_ledger(t4_fixture())
  host <- table_iv$t4_partition_support(ledger, table_iv$T4_HOST_KEYS)
  pair <- table_iv$t4_partition_support(ledger, table_iv$LADDER_KEYS)
  irl <- dplyr::filter(host, affiliate == "IRL", year == 2019L)
  expect_true(irl$complete_profit)
  expect_false(irl$complete_direct)
  expect_true(irl$mixed_low_tax)
  expect_equal(irl$observed_low_tax, 5)
  expect_equal(irl$unidentified_tax_profit, 50)
  expect_equal(irl$observed_profit, 300)
  expect_true(dplyr::filter(pair, parent == "USA", affiliate == "IRL", year == 2019L)$complete_direct)
  expect_true(dplyr::filter(host, affiliate == "FRA")$complete_direct)
  expect_true(dplyr::filter(host, affiliate == "BEL", year == 2020)$absent_lower)
  expect_true(dplyr::filter(host, affiliate == "BEL", year == 2019)$mixed_profit)
  expect_true(dplyr::filter(host, affiliate == "ESP")$absent_upper)
  expect_true(dplyr::filter(host, affiliate == "ITA")$all_positive_low_tax_missing)
  expect_false(dplyr::filter(host, affiliate == "ITA")$complete_profit)
  expect_equal(nrow(table_iv$t4_partition_support(ledger[FALSE, ], table_iv$LADDER_KEYS)), 0L)
  expect_false(anyDuplicated(host[table_iv$T4_HOST_KEYS]) > 0L)
  expect_false(anyDuplicated(pair[table_iv$LADDER_KEYS]) > 0L)
})

test_that("bounds separate known tax, unknown tax, denominator support and observed zero", {
  ledger <- table_iv$t4_component_ledger(t4_fixture())
  bounds <- table_iv$t4_partial_bounds(table_iv$t4_partition_support(ledger, table_iv$T4_HOST_KEYS))
  irl <- dplyr::filter(bounds, affiliate == "IRL", year == 2019L)
  expect_equal(c(irl$share_lo, irl$share_hi), c(.5, .5))
  expect_equal(c(irl$gap_lo, irl$gap_hi), c(10, 17.5) / 150)
  expect_equal(c(irl$bracket_topup_lo, irl$bracket_topup_hi), c(10, 17.5))
  expect_equal(c(irl$liability_rate_lo, irl$liability_rate_hi), c(10, 17.5) / 300)
  ita <- dplyr::filter(bounds, affiliate == "ITA")
  expect_equal(c(ita$share_lo, ita$share_hi), c(0, .4))
  expect_equal(c(ita$gap_lo, ita$gap_hi), c(0, .15))
  esp <- dplyr::filter(bounds, affiliate == "ESP")
  expect_equal(c(esp$gap_lo, esp$gap_hi), c(.15, .15))
  expect_true(all(is.na(dplyr::filter(bounds, affiliate == "BEL")$gap_lo)))
  expect_true(is.na(dplyr::filter(bounds, affiliate == "FRA")$gap_hi))
})

test_that("screening anchors preserves the existing source precedence and host keys", {
  ledger <- table_iv$t4_component_ledger(t4_fixture())
  support <- table_iv$t4_partition_support(ledger, table_iv$T4_HOST_KEYS)
  anchors <- table_iv$t4_anchor_profiles(support, "affiliate")
  expect_identical(dplyr::filter(anchors, affiliate == "IRL")$anchor_years, "2020")
  expect_equal(dplyr::filter(anchors, affiliate == "IRL")$anchor_gap, .15)
  expect_equal(dplyr::filter(anchors, affiliate == "FRA")$anchor_gap, 0)
  expect_false("BEL" %in% anchors$affiliate)
  toy <- tibble::tibble(affiliate = c("IRL", "IRL", "IRL", "IRL", "BEL", "BEL", "ESP"),
    year = c(2017L, 2018L, 2019L, 2020L, 2017L, 2018L, 2021L),
    direct_available = c(FALSE, FALSE, TRUE, TRUE, FALSE, FALSE, TRUE),
    percentile_available = c(rep(FALSE, 6), TRUE), bspi_available = FALSE,
    average_available = c(rep(TRUE, 5), FALSE, TRUE), direct_low_share = .5, direct_topup_rate = .1,
    percentile_low_share = .3, percentile_topup_rate = .05,
    bspi_low_share = NA_real_, bspi_topup_rate = NA_real_,
    average_low_share = .1, average_topup_rate = .02)
  picked <- table_iv$t4_host_selection(toy, support, anchors, TRUE, TRUE)
  expect_identical(picked$stage1_distributional_source,
    c("shape_transport", "shape_transport", "avg_only", "direct_t4", "avg_only", "missing", "percentile_fit"))
  expect_equal(picked$stage1_distributional_low_share, c(.2, .2, .1, .5, .1, NA, .3))
  expect_identical(picked[table_iv$T4_HOST_KEYS], toy[table_iv$T4_HOST_KEYS])
})

test_that("R09b legacy support and statutory conditioning reproduce on frozen objects", {
  if (uses_revised_table_iv()) {
    manifests <- new.env(parent = globalenv())
    source(repo_path("tests", "verify_golden_step15.R"), local = manifests)
    legacy <- manifests$read_golden_manifest(repo_root, "r09b")
    suffix <- "diagnostics/step3_stage1_pooled_t4_completeness_sensitivity.csv"
    expect_identical(manifests$sha256_files(processed_path(suffix)),
      legacy$sha256[legacy$path == file.path("data", "processed", suffix)])
  } else {
    host <- readRDS(processed_path("stage1_affiliate_year.rds"))
    pooled <- readRDS(processed_path("base_panel_t4_bracket_shares.rds"))
    legacy <- table_iv$t4_legacy_host(host, pooled)$host
    expect_identical(legacy$stage1_distributional_source, host$stage1_distributional_source)
    expect_identical(legacy$stage1_distributional_liability_rate, host$stage1_distributional_liability_rate)
    expect_identical(legacy$affiliate_etr_cap_stage1, host$affiliate_etr_cap_stage1)
    temporary <- withr::local_tempfile()
    readr::write_csv(table_iv$audit_pooled_t4_completeness(host, pooled), temporary)
    expect_identical(readBin(temporary, "raw", n = file.size(temporary)),
      readBin(processed_path("diagnostics", "step3_stage1_pooled_t4_completeness_sensitivity.csv"),
        "raw", n = file.size(temporary)))
  }
})

test_that("the R10a diagnostic is source safe and refuses production output paths", {
  withr::local_seed(109)
  seed <- .Random.seed
  before <- search()
  expect_silent(source_pipeline("diagnostics/table_iv_observability.R", new.env()))
  expect_identical(search(), before)
  expect_identical(.Random.seed, seed)
  expect_error(table_iv$t4_output_directory(repo_path("data", "processed", "r10a-shadow"), repo_root),
    "outside production")
  expect_error(table_iv$t4_output_directory(tempdir(), repo_root), "new absolute")
})
