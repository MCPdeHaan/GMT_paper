test_that("standard headline caps use combined ST rates and preserve the frozen data", {
  env <- new.env(parent = globalenv())
  source_pipeline("08a_standard_cit_cap_diagnostic.R", env)
  raw <- repo_path("data", "raw", "oecd_tax_rates", "oecd_statutory_cit_rates.csv")
  expect_error(env$run_standard_cit_cap_diagnostic(processed_dir = processed_path(),
    raw_path = raw, output = processed_path("diagnostics", "forbidden.csv")), "outside data/processed")
  rates <- env$read_standard_cit_rates(raw)
  focal <- rates[rates$affiliate %in% c("FRA", "DEU", "NLD", "BEL", "LUX") & rates$year == 2023, ]
  focal <- focal[match(c("FRA", "DEU", "NLD", "BEL", "LUX"), focal$affiliate), ]
  expect_equal(focal$standard_headline_rate, c(.25825, .30058462, .258, .25, .2494))
  expect_equal(focal$targeted_central_rate, c(.15, NA, .19, .20, .1605))
  files <- list.files(processed_path(), full.names = TRUE, recursive = TRUE)
  before <- tools::md5sum(files)
  output <- tempfile("gmt-cit-audit-", fileext = ".csv")
  withr::defer(unlink(output))
  report <- env$run_standard_cit_cap_diagnostic(processed_dir = processed_path(), raw_path = raw, output = output)
  expect_identical(tools::md5sum(files), before)
  expect_identical(list.files(processed_path(), full.names = TRUE, recursive = TRUE), files)
  cv <- report[report$record_type == "cross_validation" & report$metric == "low_share_n", ]
  expect_equal(cv$frozen, rep(c(361, 70, 81), 2))
  expect_equal(cv$standard, cv$frozen)
  revenue <- report[report$record_type == "revenue", ]
  expect_equal(nrow(revenue), 2 * 3 * 2 * 2 * 3)
  expect_true(all(is.finite(revenue$frozen) & is.finite(revenue$standard)))
  expect_setequal(revenue$window, c("2017–2023", "FY2023"))
  focal <- report[report$record_type == "focal_cell", ]
  expect_equal(nrow(focal), 2 * 5 * 3 * 4)
  expect_true(all(focal$parent == focal$affiliate & focal$year == 2023))
  recorded <- readr::read_csv(repo_path("docs", "audit_standard_vs_targeted_cit_cap.csv"), show_col_types = FALSE)
  replayed <- readr::read_csv(output, show_col_types = FALSE)
  expect_equal(replayed, recorded, tolerance = 1e-6)
})
