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

test_that("paper and supervisor memo avoid prohibited dash punctuation", {
  for (name in c("paper_v2.tex", "supervisor_pitch_memo.tex")) {
    lines <- tex_without_comments(repo_path("writing", name))
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
  references <- manuscript_dependencies(repo_path("writing", "paper_v2.tex"))
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
      expect_identical(readBin(path, "raw", n = file.info(path)$size),
        readBin(regenerated, "raw", n = file.info(regenerated)$size), info = relative)
    }
  }
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
