repo_root <- rprojroot::find_root(rprojroot::has_file("tests/golden_step15_manifest.rds"))

repo_path <- function(...) file.path(repo_root, ...)

source_pipeline <- function(filename, envir = parent.frame()) {
  withr::local_envvar(GMT_PROJECT_ROOT = repo_root)
  source(repo_path("code", filename), local = envir)
  invisible(envir)
}

processed_path <- function(...) {
  root <- Sys.getenv("GMT_TEST_OUTPUT_ROOT", unset = repo_root)
  file.path(root, "data", "processed", ...)
}

generated_path <- function(...) {
  root <- Sys.getenv("GMT_TEST_OUTPUT_ROOT", unset = repo_root)
  file.path(root, "writing", "generated", ...)
}

uses_revised_table_iv <- function() file.exists(processed_path("diagnostics", T4_SPECIFICATION_FILE))

source_pipeline("00_helpers.R")
