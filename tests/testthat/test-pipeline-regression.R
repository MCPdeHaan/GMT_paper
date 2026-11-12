library(testthat)
library(dplyr)

setwd(normalizePath(file.path("..", ".."), mustWork = TRUE))
repo_root <- getwd()

repo_path <- function(...) file.path(repo_root, ...)

source_from_repo <- function(path) {
  source(path)
}

source_from_repo("code/00_helpers.R")

processed_path <- function(file) repo_path("data", "processed", file)

baseline_path <- function(env_var, ...) {
  value <- Sys.getenv(env_var)
  if (nzchar(value)) value else repo_path(...)
}

expect_unique_key <- function(df, keys, label) {
  expect_true(all(keys %in% names(df)),
    info = paste(label, "is missing expected key columns")
  )
  key_df <- df[, keys, drop = FALSE]
  expect_equal(nrow(unique(key_df)), nrow(df),
    info = paste(label, "has duplicate key rows")
  )
}

expect_scenario_id_matches_factors <- function(df, label) {
  expected <- paste0("x", do.call(paste0, df[FACTOR_COLS]))
  expect_identical(df$scenario_id, expected,
    info = paste(label, "scenario_id does not match factors")
  )
}

latex_labels <- function(path) {
  lines <- readLines(path, warn = FALSE)
  matches <- regmatches(lines, gregexpr("\\\\label\\{[^}]+\\}", lines))
  unlist(matches, use.names = FALSE)
}

test_that("main analytical outputs have unique keys", {
  expect_unique_key(
    readRDS(processed_path("base_panel.rds")),
    c("parent", "affiliate", "year"),
    "base panel"
  )
  expect_unique_key(
    readRDS(processed_path("stage1_affiliate_year.rds")),
    c("affiliate", "year"),
    "Stage 1 affiliate-year"
  )
  expect_unique_key(
    readRDS(processed_path("stage4_5_revenue_country_year.rds")),
    c(SCENARIO_VARS, "country", "year"),
    "Stage 4.5 country-year revenue"
  )
  expect_unique_key(
    readRDS(processed_path("stage4_5_revenue_by_channel.rds")),
    c(SCENARIO_VARS, "country", "year", "channel"),
    "Stage 4.5 channel revenue"
  )
  expect_unique_key(
    readRDS(processed_path("stage3_revenue_country_year.rds")),
    c(SCENARIO_VARS, "country", "year"),
    "Stage 3 country-year revenue"
  )
  expect_unique_key(
    readRDS(processed_path("stage3_revenue_by_channel.rds")),
    c(SCENARIO_VARS, "country", "year", "channel"),
    "Stage 3 channel revenue"
  )
})

test_that("allocation and country-year channel totals conserve revenue", {
  conservation <- readRDS(processed_path("stage4_5_allocation_conservation.rds"))
  expect_lte(max(abs(conservation$residual_gap), na.rm = TRUE), 1e-3)

  for (prefix in c("stage4_5", "stage3")) {
    country_year <- readRDS(processed_path(paste0(prefix, "_revenue_country_year.rds")))
    channel <- readRDS(processed_path(paste0(prefix, "_revenue_by_channel.rds"))) |>
      group_by(across(all_of(c(SCENARIO_VARS, "country", "year")))) |>
      summarise(channel_revenue = sum(revenue, na.rm = TRUE), .groups = "drop")

    check <- country_year |>
      select(all_of(c(SCENARIO_VARS, "country", "year")), revenue) |>
      left_join(channel, by = c(SCENARIO_VARS, "country", "year")) |>
      mutate(
        channel_revenue = coalesce(channel_revenue, 0),
        gap = revenue - channel_revenue
      )

    expect_true(max(abs(check$gap), na.rm = TRUE) <= 1e-3,
      info = paste(prefix, "country-year revenue")
    )
  }
})

test_that("final revenue matrices contain the complete 32-scenario EU27 design", {
  for (file in c(
    "stage4_5_revenue_country_year.rds",
    "stage3_revenue_country_year.rds"
  )) {
    revenue <- readRDS(processed_path(file))
    completeness <- revenue |>
      filter(country %in% EU27_ISO3, year %in% MAIN_YEARS) |>
      group_by(country, year) |>
      summarise(scenarios = n_distinct(scenario_id), .groups = "drop")

    expect_true(nrow(completeness) == length(EU27_ISO3) * length(MAIN_YEARS),
      info = file
    )
    expect_true(all(completeness$scenarios == 32L), info = file)

    design <- revenue |>
      distinct(scenario_id, across(all_of(FACTOR_COLS))) |>
      arrange(scenario_id)
    expect_scenario_id_matches_factors(design, file)
  }
})

test_that("archived thesis revenue and current scenario totals reconcile by vintage", {
  archive <- readRDS(file.path(
    baseline_path("GMT_BASELINE_PROCESSED_DIR", "data", "baseline_processed"),
    "stage4_5_revenue_country_year.rds"
  ))
  thesis <- archive |>
    group_by(scenario_id) |>
    summarise(eu_revenue = sum(revenue), .groups = "drop") |>
    arrange(scenario_id)
  expect_setequal(archive$year, 2017:2022)
  expect_equal(nrow(thesis), 32L)
  expect_equal(min(thesis$eu_revenue), 127672689733.25746, tolerance = 1e-10)
  expect_equal(max(thesis$eu_revenue), 517433709472.1247, tolerance = 1e-10)

  current <- readRDS(processed_path("stage4_5_revenue_country_year.rds")) |>
    group_by(scenario_id) |>
    summarise(eu_revenue = sum(revenue), .groups = "drop") |>
    arrange(scenario_id)
  reported <- readRDS(processed_path("stage4_6_scenario_summary.rds")) |>
    arrange(scenario_id) |>
    select(scenario_id, eu_revenue)
  expect_equal(reported, current, tolerance = 1e-10)
})

test_that("current fiscal and typology results use complete CIT denominators", {
  annual <- readRDS(processed_path("cit_revenue.rds")) |>
    filter(jurisdiction %in% EU27_ISO3, year %in% MAIN_YEARS, measure == "TAX_REV",
      sector == "S13", revenue_classification == "T_1200", unit == "USD"
    ) |>
    transmute(country = jurisdiction, year, cit_usd = value * 1e9)
  expect_unique_key(annual, c("country", "year"), "CIT denominator")
  expect_equal(nrow(annual), length(EU27_ISO3) * length(MAIN_YEARS))
  expect_true(all(is.finite(annual$cit_usd) & annual$cit_usd > 0))
  fiscal <- readRDS(processed_path("stage4_6_fiscal_salience_country.rds"))
  features <- readRDS(processed_path("stage4_6_country_typology_feature_matrix.rds"))
  check <- annual |>
    group_by(country) |>
    summarise(cit_usd = sum(cit_usd), .groups = "drop") |>
    left_join(fiscal, by = "country", relationship = "one-to-one") |>
    left_join(select(features, country, typology_ratio = revenue_to_cit_1200),
      by = "country", relationship = "one-to-one"
    )
  expect_true(all(is.finite(check$typology_ratio)))
  expect_equal(check$cit_revenue_T_1200, check$cit_usd, tolerance = 1e-10)
  expect_equal(check$revenue_to_cit_1200, check$preferred_revenue / check$cit_usd)
  expect_equal(check$typology_ratio, check$revenue_to_cit_1200)
})

test_that("generated LaTeX tables remain present and well formed", {
  generated_files <- list.files(repo_path("writing", "generated"),
    pattern = "\\.tex$", recursive = TRUE,
    full.names = TRUE
  )
  expect_gt(length(generated_files), 0)

  for (current_file in generated_files) {
    rel_file <- substring(
      current_file,
      nchar(repo_path("writing", "generated")) + 2L
    )
    labels <- latex_labels(current_file)
    expect_identical(labels, unique(labels), info = rel_file)
    table_text <- paste(readLines(current_file, warn = FALSE), collapse = "\n")
    expect_false(grepl("\\b(NA|NaN|Inf)\\b", table_text),
      info = rel_file
    )
  }
})

test_that("measurement-error draws are reproducible with a fixed seed", {
  source_from_repo("code/09_stage1_measurement_error_simulation.R")

  toy_stage1 <- tibble::tibble(
    affiliate = c("AAA", "BBB"),
    year = c(2021L, 2021L),
    stage1_positive_profit_flag = c(TRUE, TRUE),
    stage1_distributional_low_share = c(0.2, 0.4),
    stage1_distributional_topup_rate = c(0.05, 0.02)
  )
  toy_calibration <- list(
    low_share_errors = c(-0.01, 0.00, 0.02),
    low_mean_etr_errors = c(-0.005, 0.000, 0.004)
  )

  first <- draw_stage1_measurement_error(toy_stage1, toy_calibration,
    n_draws = 5L, seed = 123L
  )
  second <- draw_stage1_measurement_error(toy_stage1, toy_calibration,
    n_draws = 5L, seed = 123L
  )
  expect_identical(first, second)
})

test_that("country typology cluster stability is reproducible with a fixed seed", {
  source_from_repo("code/07_stage4_6_revenue_pipeline_decomposition.R")

  scaled_matrix <- matrix(seq(-2.5, 2.5, length.out = 40), nrow = 10)
  first <- build_cluster_stability(scaled_matrix,
    k_values = 2:3,
    draws = 5L, seed = 987L
  )
  second <- build_cluster_stability(scaled_matrix,
    k_values = 2:3,
    draws = 5L, seed = 987L
  )

  expect_identical(first, second)
})
