# Follow TeX inclusions from the writing directory, including nested fragments.
tex_without_comments <- function(path) {
  sub("(?<!\\\\)%.*$", "", readLines(path, warn = FALSE), perl = TRUE)
}

manuscript_dependencies <- function(path) {
  writing <- dirname(path)
  visited <- character()
  references <- character()
  visit <- function(file) {
    if (file %in% visited || !file.exists(file)) return()
    visited <<- c(visited, file)
    text <- paste(tex_without_comments(file), collapse = "\n")
    pattern <- "\\\\(?:input|includegraphics\\*?(?:\\[[^]]*\\])?)\\{[^}]+\\}"
    commands <- regmatches(text, gregexpr(pattern, text, perl = TRUE))[[1L]]
    for (command in commands) {
      target <- sub("^[^{]+\\{([^}]+)\\}$", "\\1", command)
      candidate <- file.path(writing, target)
      if (!nzchar(tools::file_ext(candidate))) {
        extensions <- if (startsWith(command, "\\input")) ".tex" else c(".pdf", ".png", ".jpg")
        candidates <- paste0(candidate, extensions)
        candidate <- if (any(file.exists(candidates))) candidates[which(file.exists(candidates))[1L]] else candidates[1L]
      }
      references <<- c(references, candidate)
      if (endsWith(candidate, ".tex")) visit(candidate)
    }
  }
  visit(path)
  unique(references)
}

test_that("every manuscript input and graphic exists and is non-empty", {
  paths <- manuscript_dependencies(repo_path("writing", "paper_v2.tex"))
  expect_gt(length(paths), 0L)
  expect_true(all(file.exists(paths)), info = paste(paths[!file.exists(paths)], collapse = "\n"))
  sizes <- file.info(paths)$size
  expect_true(all(!is.na(sizes) & sizes > 0), info = paste(paths[is.na(sizes) | sizes == 0], collapse = "\n"))
})

test_that("generated tables use publication labels and formatted numbers", {
  paths <- manuscript_dependencies(repo_path("writing", "paper_v2.tex"))
  paths <- paths[grepl("/generated/.*\\.tex$", paths)]
  for (path in paths) {
    lines <- tex_without_comments(path)
    # TeX labels and referenced filenames are identifiers, not table prose.
    lines <- gsub("\\\\(?:label|input)\\{[^}]+\\}", "", lines, perl = TRUE)
    raw_labels <- "(?<![[:alnum:]_])(long_run|EU27_hosts|USA_parents|tau_sq|log_tau)(?![[:alnum:]_])"
    scientific <- "(?<![[:alpha:]])[+-]?[0-9]+(?:\\.[0-9]+)?[eE]\\+[0-9]+"
    expect_false(any(grepl(raw_labels, lines, perl = TRUE)), info = path)
    expect_false(any(grepl(scientific, lines, perl = TRUE)), info = path)
  }
})

test_that("paper and research note avoid prohibited dash punctuation", {
  for (name in c("paper_v2.tex", "Research note and publication plan GMT revenue decomposition.tex")) {
    path <- repo_path("writing", name)
    if (!file.exists(path)) stop("Missing TeX source: ", path, call. = FALSE)
    lines <- tex_without_comments(path)
    invalid <- grepl("\u2014|\\\\textemdash|---|[[:blank:]]--[[:blank:]]", lines, perl = TRUE)
    expect_false(any(invalid), info = paste(name, paste(which(invalid), collapse = ", ")))
  }
})

test_that("all numbered paper fragments match a fresh generator run", {
  output <- tempfile("gmt-exhibit-lint-")
  dir.create(output)
  withr::defer(unlink(output, recursive = TRUE))
  env <- new.env(parent = globalenv())
  source_pipeline("13_generate_exhibits.R", env)
  env$PROCESSED_DIR <- processed_path()
  env$DIAGNOSTICS_DIR <- processed_path("diagnostics")
  env$GENERATED_DIR <- output
  env$GENERATED_TABLES_DIR <- file.path(output, "results_tables")
  env$FIGURES_DIR <- file.path(output, "figures")
  env$PAPER_TABLES_DIR <- file.path(output, "paper_v2_tables")
  env$PAPER_FIGURES_DIR <- file.path(output, "paper_v2_figures")
  # Reproduce the lightweight-checkout case without renaming a user's raw file.
  env$RAW_DIR <- file.path(output, "absent-raw")
  env$GMT_PROJECT_ROOT <- ""
  devices <- grDevices::dev.list()
  env$run_generate_exhibits()
  expect_identical(grDevices::dev.list(), devices)
  read_bytes <- function(path) readBin(path, "raw", n = file.size(path))
  references <- manuscript_dependencies(repo_path("writing", "paper_v2.tex"))
  budget_tex <- "paper_v2_tables/tab_v2_budget_backtest_and_hanlon_waterfall.tex"
  table6 <- "paper_v2_tables/tab_v2_main_table6_budget_backtest_and_waterfall.tex"
  policy_tex <- "paper_v2_tables/tab_v2_app_budget_policy_matched.tex"
  figure3 <- "paper_v2_figures/fig_v2_cbcr_to_budget_waterfall.pdf"
  expect_true(all(repo_path("writing", "generated", c(table6, policy_tex, figure3)) %in% references))
  expect_true(file.exists(file.path(output, figure3)))
  expect_identical(read_bytes(file.path(output, budget_tex)),
    read_bytes(generated_path(budget_tex)))
  expect_identical(read_bytes(file.path(output, budget_tex)), read_bytes(file.path(output, table6)))
  numbered <- references[grepl("/tab_v2_(main_table[1-8]_|app_table[3-8]_|cbcr_tables_2_3_6)", references)]
  expect_length(numbered, 15L)
  expect_setequal(sub("^tab_v2_main_table([1-8])_.*", "\\1", basename(numbered[grepl("main_table", numbered)])), as.character(1:8))
  expect_setequal(sub("^tab_v2_app_table([3-8])_.*", "\\1", basename(numbered[grepl("app_table", numbered)])), as.character(3:8))
  # Check all included generated tables, not just the numbered entry points.
  tables <- references[grepl("/generated/.*\\.tex$", references)]
  for (path in tables) {
    relative <- sub("^.*/writing/generated/", "", path)
    regenerated <- file.path(output, relative)
    expect_true(file.exists(regenerated), info = relative)
    if (file.exists(regenerated)) {
      expect_identical(read_bytes(generated_path(relative)), read_bytes(regenerated), info = relative)
    }
  }
})

test_that("Table 6 labels and renders distinct L3 and full-core diagnostics", {
  rows <- readr::read_csv(processed_path("diagnostics", "step9_budget_benchmark_scenario_ranges_r04b.csv"),
    show_col_types = FALSE)
  rows <- dplyr::filter(rows, window == "FY2023",
    benchmark == "Dutch October 2026 direct after package", scenario_scope %in% c("l3", "core")) |>
    dplyr::arrange(scenario_count)
  expect_equal(rows$scenario_count, c(16, 32))
  if (file.exists(processed_path("stage4_5_utpr_policy.rds")) &&
      readRDS(processed_path("stage4_5_utpr_policy.rds"))$specification == "VERIFIED_PARENT_ONLY") {
    expect_gt(rows$scenario_min_eur_bn[2], rows$official_high_eur_bn[2])
    expect_false(rows$official_interval_overlaps_model_range[2])
  } else {
    expect_lt(rows$scenario_min_eur_bn[2], rows$official_low_eur_bn[2])
  }
  expect_gt(rows$scenario_min_eur_bn[1], rows$official_high_eur_bn[1])
  tex <- readLines(generated_path("paper_v2_tables", "tab_v2_main_table6_budget_backtest_and_waterfall.tex"))
  expect_true(any(grepl("L3 (16) & Core (32)", tex, fixed = TRUE)))
  dutch <- tex[startsWith(tex, "NLD & FY2023")][1L]
  amounts <- sprintf("%.4f", c(rows$official_low_eur_bn[1], rows$scenario_min_eur_bn[1],
    rows$scenario_max_eur_bn[1], rows$scenario_min_eur_bn[2], rows$scenario_max_eur_bn[2]))
  expect_identical(regmatches(dutch, gregexpr("[0-9]+\\.[0-9]{4}", dutch))[[1L]],
    amounts)
})

test_that("the publication distinguishes unsupported UTPR from assigned receipts and source relief", {
  reports_unsupported <- file.exists(processed_path("stage4_5_utpr_policy.rds"))
  table_dir <- "paper_v2_tables"
  ledger <- readLines(generated_path(table_dir, "tab_v2_main_table7_source_collector_ledger.tex"))
  game <- readLines(generated_path(table_dir, "tab_v2_app_table8_universal_and_optout.tex"))
  country <- readLines(generated_path("results_tables", "country_revenue_diagnostic.tex"))
  expect_identical(any(grepl("Unassigned", ledger, fixed = TRUE)), reports_unsupported)
  expect_identical(any(grepl("Unassigned", game, fixed = TRUE)), reports_unsupported)
  expect_identical(any(grepl("Source relief", game, fixed = TRUE)), reports_unsupported)
  expect_identical(any(startsWith(country, "Cyprus &")), reports_unsupported)
})

test_that("raw source metadata falls back only when the extract is absent", {
  env <- new.env(parent = globalenv())
  source_pipeline("13_generate_exhibits.R", env)
  raw <- tempfile("gmt-raw-")
  dir.create(raw)
  withr::defer(unlink(raw, recursive = TRUE))
  expected <- list(records = 1367305L, parents = 63L, affiliates = 244L)
  expect_message(expect_identical(env$raw_table1_counts(raw), expected), "verified frozen")
  for (folder in c("oecd_cbcr", "cbcr")) {
    dir.create(file.path(raw, folder))
    file <- file.path(raw, folder, "cbcr_table1_aggregate_totals.csv")
    writeLines(c("REF_AREA,COUNTERPART_AREA,TIME_PERIOD", "FRA,FRA,2023"), file)
    expect_error(env$raw_table1_counts(raw), "counts differ")
    unlink(file)
  }
})
