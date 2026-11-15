testthat::test_that("R modules can be sourced into an isolated environment", {
  fixture <- tempfile("gmt-source-")
  dir.create(fixture)
  withr::defer(unlink(fixture, recursive = TRUE))
  dir.create(file.path(fixture, "code"))
  scripts <- list.files(repo_path("code"), "\\.[Rr]$", recursive = TRUE)
  for (script in scripts) {
    target <- file.path(fixture, "code", script)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    stopifnot(file.copy(repo_path("code", script), target))
  }

  probe <- file.path(fixture, "probe.R")
  writeLines(c(
    "local({",
    "  Sys.unsetenv('GMT_PROJECT_ROOT')",
    "  withr::local_dir(commandArgs(trailingOnly = TRUE)[1L])",
    "  files <- list.files(all.files = TRUE, recursive = TRUE, include.dirs = TRUE)",
    "  bindings <- ls(globalenv(), all.names = TRUE)",
    "  namespaces <- sort(loadedNamespaces())",
    "  packages <- search()",
    "  session_options <- options()",
    "  for (script in list.files('code', '[.][Rr]$', full.names = TRUE, recursive = TRUE)) {",
    "    source(script, local = new.env(parent = globalenv()))",
    "    stopifnot(identical(ls(globalenv(), all.names = TRUE), bindings),",
    "      identical(sort(loadedNamespaces()), namespaces),",
    "      identical(search(), packages), identical(options(), session_options),",
    "      identical(list.files(all.files = TRUE, recursive = TRUE, include.dirs = TRUE), files))",
    "  }",
    "})"
  ), probe)
  output <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
    c("--vanilla", shQuote(probe), shQuote(fixture)), stdout = TRUE, stderr = TRUE))
  testthat::expect_null(attr(output, "status"), info = paste(output, collapse = "\n"))
})
