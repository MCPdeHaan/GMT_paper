assembly <- source_pipeline("panel/bilateral_assembly.R", new.env())

test_that("Table I builds the ordered bilateral spine with exact filters and flags", {
  aggregate_codes <- c("A", "A_O", "E", "E_O", "F", "F_O", "S", "S_O", "W", "W_O", "WXD", "STLS")
  expect_identical(assembly$STAGE02_AGGREGATE_AFFILIATES, aggregate_codes)

  table1 <- tibble::tibble(
    parent = c("USA", "DEU", "DEU", "USA", "DEU", "USA", rep("DEU", length(aggregate_codes)), "W"),
    affiliate = c("IRL", "DEU", "IRL", "USA", "DEU", "DEU", aggregate_codes, "CHE"),
    year = c(2023L, 2017L, 2023L, 2024L, 2016L, 2015L, rep(2023L, length(aggregate_codes)), 2023L),
    act_holding_panelai = 2L, entities_count_panelai = 4L,
    act_holding_panelaii = 0L, entities_count_panelaii = 3L,
    profit_panelai = 100, profit_adj_panelai = NA_real_
  )
  table1$profit_adj_panelai[1:4] <- c(125, 0, 100, 0)
  table1$entities_count_panelai[2L] <- 0L
  table1$act_holding_panelai[3L] <- NA_integer_
  unchanged <- serialize(table1, NULL)

  build_spine <- function(table) {
    assembly$build_bilateral_spine(
      table, CORE_YEARS, MAIN_YEARS, assembly$STAGE02_AGGREGATE_AFFILIATES,
      eu27 = c("DEU", "IRL"), conduit_havens = "IRL"
    )
  }
  panel <- build_spine(table1)
  keys <- c("parent", "affiliate", "year")
  expect_identical(panel[keys], table1[c(5L, 2L, 3L, 1L, nrow(table1)), keys])
  expect_identical(anyDuplicated(panel[keys]), 0L)
  expect_identical(panel$pair_id, c("DEU__DEU", "DEU__DEU", "DEU__IRL", "USA__IRL", "W__CHE"))
  expect_identical(panel$is_domestic, c(TRUE, TRUE, FALSE, FALSE, FALSE))
  expect_identical(panel$is_2016_transition, c(TRUE, FALSE, FALSE, FALSE, FALSE))
  expect_identical(panel$is_main_estimation_year, c(FALSE, TRUE, TRUE, TRUE, TRUE))
  expect_identical(panel$affiliate_is_eu27, c(TRUE, TRUE, TRUE, TRUE, FALSE))
  expect_identical(panel$affiliate_is_conduit_haven, c(FALSE, FALSE, TRUE, TRUE, FALSE))
  expect_identical(panel$holding_share_panelai, c(0.5, NA_real_, NA_real_, 0.5, 0.5))
  expect_identical(panel$holding_share_panelaii, rep(0, 5))
  expect_identical(panel$profit_adj_observed_panelai, c(FALSE, TRUE, TRUE, TRUE, FALSE))
  expect_identical(panel$profit_adj_ratio_observed, c(NA_real_, 0, 1, 1.25, NA_real_))
  expect_identical(panel$profit_adj_above_profit_flag, c(FALSE, FALSE, FALSE, TRUE, FALSE))
  expect_identical(names(panel), c(
    names(table1), "pair_id", "is_domestic", "is_2016_transition",
    "is_main_estimation_year", "affiliate_is_eu27", "affiliate_is_conduit_haven",
    "holding_share_panelai", "holding_share_panelaii", "profit_adj_observed_panelai",
    "profit_adj_ratio_observed", "profit_adj_above_profit_flag"
  ))
  expect_identical(serialize(table1, NULL), unchanged)
  expect_error(build_spine(rbind(table1, table1[1, ])), "Table I spine.*duplicate key")
})

test_that("CbCR projections preserve dimensions, observation status and wide-column order", {
  panel <- tibble::tibble(
    parent = c("USA", "DEU", "USA", "USA"),
    affiliate = c("IRL", "IRL", "USA", "NLD"),
    year = 2023L
  )
  table2 <- dplyr::mutate(panel[c(3, 1), ], profit = c(0, NA_real_), cbcr_count = c(10L, 5L))
  table3 <- dplyr::mutate(panel[c(1, 1), ], etr_bracket = c("rate_15_20", "rate_0_15"), profit = c(80, 90))
  table4 <- dplyr::mutate(
    panel[c(1, 1, 3), ], etr_bracket = c("rate_0_15", "rate_15_20", "rate_0_15"),
    profit = c(40, 45, 60), tax_accrued = c(NA_real_, 9, 0), employees = c(250000, 30, 0)
  )
  table5 <- tibble::tibble(parent = "USA", year = 2023L, entities_count = 50L)
  measures <- c("profit", "assets", "employees", "accumulated_earnings", "tax_accrued",
                "entities_count", "cbcr_count", "subgroups_count")
  size_classes <- c("large", "small", "medium")
  table6 <- dplyr::mutate(
    panel[c(1, 1, 3), ], size_class = size_classes,
    profit = c(40, 0, 7), assets = c(60, NA_real_, 20), employees = c(12L, 4L, 7L),
    accumulated_earnings = 2, tax_accrued = 1, entities_count = 1L, cbcr_count = 1L,
    subgroups_count = 1L
  )
  before <- serialize(list(panel, table2, table3, table4, table5, table6), NULL)
  lookups <- assembly$prepare_cbcr_bilateral_lookups(table2, table3, table4, table5, table6)
  joined <- assembly$attach_cbcr_bilateral_lookups(panel, lookups)

  wide_names <- unlist(lapply(measures, function(measure) paste("t6", measure, size_classes, sep = "_")))
  expect_identical(names(joined), c(
    names(panel), "t2_profit", "t2_cbcr_count", "t3_low_profit", "t4_low_profit",
    "t4_low_tax_accrued", "t4_low_employees", "t5_entities_count", wide_names
  ))
  expect_identical(joined[names(panel)], panel)
  expect_identical(joined$t2_profit, c(NA_real_, NA_real_, 0, NA_real_))
  expect_identical(joined$t2_cbcr_count, c(5L, NA_integer_, 10L, NA_integer_))
  expect_identical(joined$t3_low_profit, c(90, NA_real_, NA_real_, NA_real_))
  expect_identical(joined$t4_low_profit, c(40, NA_real_, 60, NA_real_))
  expect_identical(joined$t4_low_tax_accrued, c(NA_real_, NA_real_, 0, NA_real_))
  expect_identical(joined$t4_low_employees, c(250000, NA_real_, 0, NA_real_))
  expect_identical(dplyr::anti_join(panel, lookups$table4_low, by = names(panel)), panel[c(2, 4), ])
  expect_identical(joined$t5_entities_count, c(50L, NA_integer_, 50L, 50L))
  expect_identical(joined$t6_profit_large, c(40, NA_real_, NA_real_, NA_real_))
  expect_identical(joined$t6_profit_small, c(0, NA_real_, NA_real_, NA_real_))
  expect_identical(joined$t6_profit_medium, c(NA_real_, NA_real_, 7, NA_real_))
  expect_identical(joined$t6_employees_small, c(4L, NA_integer_, NA_integer_, NA_integer_))
  expect_identical(serialize(list(panel, table2, table3, table4, table5, table6), NULL), before)

  expect_error(
    assembly$prepare_cbcr_bilateral_lookups(table2, table3, table4, table5, rbind(table6, table6[1, ])),
    "Table VI before widening.*size_class.*duplicate key"
  )
  for (name in names(lookups)) {
    duplicates <- lookups
    duplicates[[name]] <- rbind(duplicates[[name]], duplicates[[name]][1, ])
    expect_error(assembly$attach_cbcr_bilateral_lookups(panel, duplicates), "Table [IV]+.*duplicate key")
  }
})

test_that("prepared metadata, wages and reconciliation retain their natural keys", {
  panel <- tibble::tibble(
    parent = c("USA", "DEU", "USA"), affiliate = c("IRL", "IRL", "USA"), year = 2023L
  )
  parent <- tibble::tibble(parent = "USA", parent_name = "United States")
  affiliate <- tibble::tibble(affiliate = "IRL", affiliate_name = "Ireland")
  wage <- tibble::tibble(
    affiliate = "IRL", year = 2023L, affiliate_wage_annual = 60000,
    affiliate_wage_source = "oecd_annual_ppp", affiliate_wage_year = 2022L, affiliate_wage_year_gap = 1L
  )
  reconciliation <- tibble::tibble(
    parent = "USA", year = 2023L, rho_hat_pt = 0, rho_lo_pt = 0, rho_hi_pt = 0.1,
    profit_reconciliation_support_class = "anchored_model",
    profit_reconciliation_main_source = "fixture",
    profit_reconciliation_posterior_sd = 0.04,
    profit_reconciliation_external_anchor_flag = TRUE,
    profit_reconciliation_public_signal_flag = FALSE,
    profit_reconciliation_extrapolated_flag = FALSE
  )
  joined <- panel |>
    assembly$attach_bilateral_lookup(parent, "parent", "Parent labels") |>
    assembly$attach_bilateral_lookup(affiliate, "affiliate", "Affiliate labels") |>
    assembly$attach_bilateral_lookup(wage, c("affiliate", "year"), "Wages") |>
    assembly$attach_profit_reconciliation(reconciliation)

  expect_identical(joined[names(panel)], panel)
  expect_identical(joined$parent_name, c("United States", NA_character_, "United States"))
  expect_identical(joined$affiliate_name, c("Ireland", "Ireland", NA_character_))
  expect_identical(joined[names(wage)[-(1:2)]], wage[c(1L, 1L, NA_integer_), -(1:2)])
  expect_identical(joined[names(reconciliation)[-(1:2)]], reconciliation[c(1L, NA_integer_, 1L), -(1:2)])
  expect_error(assembly$attach_bilateral_lookup(panel, rbind(wage, wage), c("affiliate", "year"), "Wages"),
               "Wages \\(affiliate, year\\): 1 duplicate")
  expect_error(assembly$attach_bilateral_lookup(rbind(panel, panel), parent, "parent", "Parent labels"),
               "Bilateral panel before Parent labels.*duplicate key")
  expect_error(assembly$attach_profit_reconciliation(panel, rbind(reconciliation, reconciliation)),
               "Profit reconciliation parent-year model.*duplicate key")
})

test_that("Stage 02 applies the original profit and wage calculations after attachment", {
  stage02 <- source_pipeline("02_base_correction_and_merging.R", new.env())
  input <- withr::local_tempdir()
  output <- withr::local_tempdir()
  frozen_inputs <- c(
    paste0("cbcr_table", 2:6), "cit_statutory", "wb_classifications", "wb_gdp",
    "wb_population", "fats_post2021", "euklems_sector_capital", "global_intan_invest_annual",
    "bea_us_mne_country_industry", "beps_rules", "cbcr_requirements", "oecd_pillar2_central_record"
  )
  for (file in paste0(frozen_inputs, ".rds")) {
    stopifnot(file.copy(processed_path(file), input))
  }

  cells <- tibble::tibble(
    parent = c("DEU", "FRA", "NLD", "DEU", "DEU", "DEU"),
    affiliate = c("DEU", "FRA", "NLD", "FRA", "IRL", "NLD"), year = 2022L
  )
  table1 <- readRDS(processed_path("cbcr_table1.rds"))
  key <- c("parent", "affiliate", "year")
  rows <- vctrs::vec_match(cells, table1[key])
  stopifnot(!anyNA(rows))
  table1$profit_panelai[rows] <- 100
  table1$profit_adj_panelai[rows] <- c(NA_real_, NA_real_, NA_real_, NA_real_, 0, 60)
  table1$tax_accrued_panelai[rows] <- 15
  saveRDS(table1, file.path(input, "cbcr_table1.rds"))

  reconciliation <- readRDS(processed_path("profit_correction_parent_year.rds"))
  reconciliation <- dplyr::filter(reconciliation, !(parent == "NLD" & year == 2022L))
  reconciliation$rho_hat_pt[reconciliation$parent == "DEU" & reconciliation$year == 2022L] <- 0.25
  reconciliation$rho_hat_pt[reconciliation$parent == "FRA" & reconciliation$year == 2022L] <- 0
  saveRDS(reconciliation, file.path(input, "profit_correction_parent_year.rds"))

  # Source ranking precedes year distance, and a tied distance prefers the
  # earlier year. The absent NLD lookup never receives a numeric zero wage.
  saveRDS(tibble::tibble(jurisdiction = "DEU", year = c(2019L, 2025L), currency = "USD_PPP", value = c(100, 200)),
          file.path(input, "wages_oecd.rds"))
  saveRDS(tibble::tibble(
    jurisdiction = c("DEU", "FRA", "FRA", "IRL"), year = c(2022L, 2021L, 2022L, 2023L),
    currency = c("CUR_TYPE_PPP", "CUR_TYPE_PPP", "CUR_TYPE_USD", "CUR_TYPE_USD"),
    sex = "SEX_T", sector = "ECO_ISIC4_TOTAL", value = c(20, 21, 25, 24)
  ), file.path(input, "wages_ilo_monthly.rds"))

  withr::local_dir(withr::local_tempdir())
  invisible(capture.output(stage02$run_base_panel(in_dir = input, out_dir = output)))
  result <- readRDS(file.path(output, "base_panel.rds"))
  selected <- result[vctrs::vec_match(cells, result[key]), ]
  expect_identical(selected[key], cells)
  expect_identical(selected$profit_adj_observed_panelai, c(FALSE, FALSE, FALSE, FALSE, TRUE, TRUE))
  expect_identical(selected$rho_hat_pt, c(0.25, 0, NA_real_, 0.25, 0.25, 0.25))
  expect_identical(selected$analysis_profit_base, c(75, 100, NA_real_, 100, 0, 60))
  expect_identical(selected$etr_panelai_raw, c(0.2, 0.15, NA_real_, 0.15, NA_real_, 0.25))
  expect_identical(selected$profit_correction_source[c(3:6)],
                   c("anchored_model", "uncorrected_foreign", "observed_adjusted", "observed_adjusted"))
  expect_identical(selected$affiliate_wage_annual, c(100, 252, NA_real_, 252, 288, NA_real_))
  expect_identical(selected$affiliate_wage_source, c(
    "oecd_annual_ppp", "ilo_monthly_ppp_x12", NA_character_, "ilo_monthly_ppp_x12",
    "ilo_monthly_usd_x12", NA_character_
  ))
  expect_identical(selected$affiliate_wage_year, c(2019L, 2021L, NA_integer_, 2021L, 2023L, NA_integer_))
  expect_identical(selected$affiliate_wage_year_gap, c(3L, 1L, NA_integer_, 1L, 1L, NA_integer_))
})

test_that("the assembly module can be sourced independently from an empty directory", {
  withr::local_dir(withr::local_tempdir())
  namespaces <- sort(loadedNamespaces())
  imports <- search()
  config <- options()
  independent <- new.env(parent = baseenv())
  sys.source(repo_path("code", "panel", "bilateral_assembly.R"), envir = independent)
  expect_true(is.function(independent$build_bilateral_spine))
  expect_identical(sort(loadedNamespaces()), namespaces)
  expect_identical(search(), imports)
  expect_identical(options(), config)
  expect_identical(list.files(all.files = TRUE, no.. = TRUE), character())
})

test_that("the active output has stable ordered bilateral keys and a versioned schema", {
  panel <- readRDS(processed_path("base_panel.rds"))
  reference <- readRDS(repo_path("data", "processed", "base_panel.rds"))
  key <- c("parent", "affiliate", "year")
  expect_identical(nrow(panel), 20111L)
  standard <- "affiliate_cit_statistical_ceiling" %in% names(panel)
  standard_reference <- "affiliate_cit_statistical_ceiling" %in% names(reference)
  if (!standard) expect_identical(ncol(panel), 403L)
  expect_identical(sum(panel$is_main_estimation_year), 18954L)
  expect_identical(anyDuplicated(panel[key]), 0L)
  expect_identical(panel[key], dplyr::arrange(panel[key], parent, affiliate, year))
  if (standard == standard_reference) expect_identical(panel, reference)
  # A replay using the other scientific reference is checked against that
  # reference's complete manifest in test-golden-portability.R.
})
