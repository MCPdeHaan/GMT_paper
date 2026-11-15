budget_waterfall_fixture <- function() {
  countries <- c("NLD", "DEU", "FRA", "IRL", "LUX", "BEL", "AUT", "SVK")
  windows <- c("FY2023", "2019–2023")
  benchmarks <- c(
    "Dutch October 2026 direct after package", "Mindeststeuergesetz cash estimate",
    "Projet de loi de finances 2026", "Department of Finance estimate, reported by IFAC",
    "Luxembourg 2026 budget Pillar Two minimum tax", "Belgian 2024 budget",
    "Austrian MinBestG impact assessment", "Slovakia 2026 state budget Pillar Two line"
  )
  steps <- c("00_baseline", "01_step8_dividends", "02_current_losses",
    "03_prior_loss_carryforward", "04_envelope_tax", "05_safe_harbour_2026")
  backtest <- tibble::tibble(
    country = rep(countries, 2), window = rep(windows, each = 8), benchmark = rep(benchmarks, 2),
    level = "L3_Host_Pooled_Distributional", forecast_period = "2026 cash",
    official_low_eur_bn = rep(c(.176, 1, .5, 3.2, .08, .634, .1, .0485), 2),
    scenario_min_eur_bn = rep(c(1.2346, 2), each = 8), scenario_max_eur_bn = 9,
    closest_scenario = "x11011", closest_scenario_eur_bn = 2.5
  )
  backtest <- dplyr::bind_rows(backtest[16:1, ],
    dplyr::mutate(backtest[1, ], level = "L2_Bilateral_Cell_Average", official_low_eur_bn = 99),
    dplyr::mutate(backtest[1, ], window = "2021–2023", official_low_eur_bn = 99),
    dplyr::mutate(backtest[1, ], benchmark = "Unselected benchmark", official_low_eur_bn = 99))
  waterfall <- tibble::tibble(
    scope = rep(countries, each = 12), window = rep(rep(windows, each = 6), 8),
    step = rep(rev(steps), 16), record_type = "waterfall",
    collector_annualised_eur_bn = rep(c(1:6, 11:16), 8)
  )
  waterfall <- dplyr::bind_rows(waterfall,
    dplyr::mutate(waterfall[1, ], record_type = "budget_comparison"),
    dplyr::mutate(waterfall[1, ], window = "2021–2023"),
    dplyr::mutate(waterfall[1, ], scope = "EU27"),
    dplyr::mutate(waterfall[1, ], step = "05_safe_harbour_2026_preserve_qdmtt"))
  trend <- tibble::tibble(
    parent = "ALL", affiliate = rep(c("NLD", "LUX", "IRL"), each = 6),
    year = rep(2018:2023, 3), record_type = "annual_observation",
    collector_eur_bn = c(31:36, 41:46, 51:56)
  )
  trend <- dplyr::bind_rows(trend,
    dplyr::mutate(trend[1, ], parent = "USA"),
    dplyr::mutate(trend[1, ], year = 2017L),
    dplyr::mutate(trend[1, ], record_type = "trend_projection", year = 2026L),
    dplyr::mutate(trend[1, ], affiliate = "DEU"))
  list(backtest = backtest, waterfall = waterfall, trend = trend)
}

budget_waterfall_reader <- function(fixture) {
  function(stem) {
    switch(stem,
      step9_ladder_budget_backtest = fixture$backtest,
      step12_cbcr_to_budget_waterfall_bridge = fixture$waterfall,
      step12_conduit_unwinding_time_series_2017_2026 = fixture$trend,
      stop("Unexpected input ", stem))
  }
}

budget_waterfall_env <- function() {
  env <- new.env(parent = baseenv())
  source_pipeline("publication/budget_waterfall.R", env)
  env
}

test_that("the input reader loads each diagnostic once and checks its required fields", {
  env <- budget_waterfall_env()
  fixture <- budget_waterfall_fixture()
  reader <- budget_waterfall_reader(fixture)
  loaded <- character()
  data <- env$read_budget_waterfall_inputs(function(stem) {
    loaded <<- c(loaded, stem)
    reader(stem)
  })
  expect_identical(data, fixture)
  expect_identical(loaded, c("step9_ladder_budget_backtest", "step12_cbcr_to_budget_waterfall_bridge",
    "step12_conduit_unwinding_time_series_2017_2026"))
  bad <- fixture
  bad$waterfall$collector_annualised_eur_bn <- NULL
  expect_error(env$read_budget_waterfall_inputs(budget_waterfall_reader(bad)),
    "step12_cbcr_to_budget_waterfall_bridge.csv is missing columns: collector_annualised_eur_bn", fixed = TRUE)
  bad <- fixture
  bad$backtest$official_low_eur_bn <- "text"
  expect_error(env$read_budget_waterfall_inputs(budget_waterfall_reader(bad)),
    "step9_ladder_budget_backtest.csv requires numeric columns: official_low_eur_bn", fixed = TRUE)
  bad$backtest$official_low_eur_bn <- NA
  expect_identical(env$read_budget_waterfall_inputs(budget_waterfall_reader(bad)), bad)
})

test_that("budget selection uses the eight ordered benchmarks in each modelling window", {
  env <- budget_waterfall_env()
  rows <- env$paper_budget_rows(budget_waterfall_fixture()$backtest)
  annual <- dplyr::filter(rows, window == "FY2023")
  average <- dplyr::filter(rows, window == "2019–2023")

  expect_identical(rows$window, rep(c("FY2023", "2019–2023"), each = 8))
  expect_identical(annual$country, c("NLD", "DEU", "FRA", "IRL", "LUX", "BEL", "AUT", "SVK"))
  expect_identical(annual$country, average$country)
  expect_identical(unique(annual$window), "FY2023")
  expect_identical(unique(average$window), "2019–2023")
  expect_identical(annual$official_low_eur_bn, c(.176, 1, .5, 3.2, .08, .634, .1, .0485))
  expect_identical(average$official_low_eur_bn, annual$official_low_eur_bn)
  expect_identical(annual$scenario_min_eur_bn, rep(1.2346, 8))
  expect_identical(average$scenario_min_eur_bn, rep(2, 8))
})

test_that("waterfall selection preserves the ordered labels and both windows", {
  env <- budget_waterfall_env()
  data <- env$paper_waterfall_rows(budget_waterfall_fixture()$waterfall)
  expect_equal(nrow(data), 8 * 2 * 6)
  expect_equal(unname(as.vector(table(data$scope, data$window, data$stage))), rep(1L, 96))
  expect_identical(unique(data$window), c("FY2023", "2019–2023"))
  expect_identical(levels(data$stage),
    c("Baseline", "Dividends", "Current losses", "Prior losses", "Tax envelope", "2026 screen"))
  expect_identical(as.integer(data$stage[1:6]), 6:1)
})

test_that("missing or duplicate benchmark keys and duplicate waterfall keys are rejected", {
  env <- budget_waterfall_env()
  fixture <- budget_waterfall_fixture()
  expect_error(env$paper_budget_rows(fixture$backtest[-16, ]), "one selected budget benchmark")
  duplicate <- dplyr::bind_rows(fixture$backtest, fixture$backtest[16, ])
  expect_error(env$paper_budget_rows(duplicate), "one selected budget benchmark")
  duplicate <- dplyr::bind_rows(fixture$waterfall, fixture$waterfall[1, ])
  expect_error(env$paper_waterfall_rows(duplicate), "Duplicate accounting waterfall rows")
})

test_that("the table preserves panels, rounding and missing values", {
  env <- budget_waterfall_env()
  stage <- new.env(parent = globalenv())
  source_pipeline("13_generate_exhibits.R", stage)
  fixture <- budget_waterfall_fixture()
  fixture$waterfall <- fixture$waterfall[-2, ]
  fixture$backtest$official_low_eur_bn[16] <- NA_real_
  record_table <- function(filename, title, panels, notes, align, output_dir) {
    list(filename = filename, panels = panels, notes = notes, output_dir = output_dir)
  }
  output <- tempfile("gmt-budget-table-")
  table <- env$write_paper_budget_table(env$paper_budget_rows(fixture$backtest),
    env$paper_waterfall_rows(fixture$waterfall), output_dir = output,
    format_number = stage$paper_number, write_table = record_table)
  expect_identical(table$filename, "tab_v2_budget_backtest_and_hanlon_waterfall")
  expect_identical(table$output_dir, output)
  expect_identical(names(table$panels), c("A. Official benchmark and 32-scenario collector range",
    "B. Preferred SbS collector revenue after each adjustment"))
  expect_identical(names(table$panels[[1]]),
    c("ISO", "Window", "Vintage", "Benchmark", "Min.", "Max.", "Closest", "Model"))
  expect_identical(unname(as.character(table$panels[[1]][1, ])),
    c("NLD", "FY2023", "2026 cash", "--", "1.235", "9.000", "x11011", "2.500"))
  expect_identical(table$panels[[1]]$Benchmark[[2]], "1.000")
  expect_identical(names(table$panels[[2]]), c("ISO", "Window",
    "Baseline", "Dividends", "Current losses", "Prior losses", "Tax envelope", "2026 screen"))
  expect_identical(unname(as.character(table$panels[[2]][1, ])),
    c("NLD", "FY2023", " 6.000", " 5.000", " 4.000", " 3.000", "--", " 1.000"))
  expect_identical(table$panels[[2]]$Baseline[2], "16.000")
  expect_match(table$notes, "EUR bn per year, converted at 1.0813 USD per EUR", fixed = TRUE)
})

test_that("the figure maps each panel to its own diagnostic and repeats FY2023 benchmarks", {
  env <- budget_waterfall_env()
  fixture <- budget_waterfall_fixture()
  plot <- env$make_paper_waterfall_figure(env$paper_budget_rows(fixture$backtest),
    env$paper_waterfall_rows(fixture$waterfall), fixture$trend)
  expect_identical(levels(plot$data$scope), c("NLD", "LUX", "IRL"))
  expect_equal(nrow(plot$data), 36L)
  bridge <- dplyr::filter(plot$data, scope == "NLD", panel == "A  Accounting bridge")
  history <- dplyr::filter(plot$data, scope == "NLD", panel == "B  Historical unwind")
  expect_identical(as.character(bridge$axis), c("2026 screen", "Tax envelope",
    "Prior losses", "Current losses", "Dividends", "Baseline"))
  expect_identical(bridge$revenue, 1:6)
  expect_identical(as.character(history$axis), as.character(2018:2023))
  expect_identical(history$revenue, 31:36)
  budgets <- dplyr::arrange(plot$layers[[1]]$data, panel, scope)
  expect_identical(budgets$benchmark, rep(c(.176, .08, 3.2), 2))
  expect_identical(rlang::as_label(plot$mapping$x), "axis")
  expect_identical(rlang::as_label(plot$mapping$y), "revenue")
  expect_identical(rlang::as_label(plot$layers[[1]]$mapping$yintercept), "benchmark")
  expect_identical(plot$labels$y, "Collector revenue (EUR bn)")
  expect_identical(plot$theme$axis.text.x$angle, 36)
  expect_identical(plot$theme$legend.position, "top")
  expect_equal(nrow(ggplot2::ggplot_build(plot)$layout$layout), 6L)
})
