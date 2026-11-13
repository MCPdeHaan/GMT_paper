# Usage from any directory:
# Rscript /path/to/GMT_paper/tests/verify_golden_step15.R [repository-root]
# Exact mode intentionally rejects extra processed CSV/RDS files. A future
# schema migration needs a separate keyed comparison and a reviewed mapping.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 1L) stop("Usage: Rscript tests/verify_golden_step15.R [repository-root]")
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
root <- if (length(args)) args[[1L]] else file.path(dirname(script), "..")
root <- normalizePath(root, mustWork = TRUE)
manifest <- readRDS(file.path(root, "tests", "golden_step15_manifest.rds"))$files
expected <- manifest$path
actual <- file.path("data", "processed",
  list.files(file.path(root, "data", "processed"), "\\.(rds|csv)$", recursive = TRUE))
stopifnot(!anyDuplicated(expected), !anyDuplicated(actual))
report <- function(label, paths) {
  if (length(paths)) cat(label, paste(paths, collapse = "\n"), sep = "\n", file = stderr())
  if (length(paths)) cat("\n", file = stderr())
}
missing <- setdiff(expected, actual)
extra <- setdiff(actual, expected)
index <- expected %in% actual
paths <- file.path(root, expected[index])
if (!exists("sha256sum", envir = asNamespace("tools"), inherits = FALSE)) {
  stop("Use the Step 15 runtime (R 4.6+) for tools::sha256sum()")
}
hashes <- unname(tools::sha256sum(paths))
failed <- is.na(hashes) | hashes != manifest$sha256[index]
report("Missing", missing)
report("Unexpected", extra)
report("SHA-256 mismatch", expected[index][failed])
if (length(missing) + length(extra) + sum(failed)) quit(status = 1L)
cat(sprintf("All %d Step 15 files match their frozen SHA-256 hashes.\n", length(expected)))
