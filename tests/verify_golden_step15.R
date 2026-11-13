# Usage from any directory:
# Rscript /path/to/GMT_paper/tests/verify_golden_step15.R [output-root]
# Verify the immutable Step 15 manifest and the separately frozen Step 17 CSV.
# A future schema migration needs a separate keyed comparison.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 1L) stop("Usage: Rscript tests/verify_golden_step15.R [output-root]")
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
repo_root <- file.path(dirname(normalizePath(script, mustWork = TRUE)), "..")
root <- if (length(args)) args[[1L]] else repo_root
root <- normalizePath(root, mustWork = TRUE)
manifest <- readRDS(file.path(repo_root, "tests", "golden_step15_manifest.rds"))$files
step17 <- utils::read.csv(file.path(repo_root, "tests", "golden_step17_additions.csv"))
expected <- c(manifest$path, step17$path)
expected_hashes <- c(manifest$sha256, step17$sha256)
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
failed <- is.na(hashes) | hashes != expected_hashes[index]
report("Missing", missing)
report("Unexpected", extra)
report("SHA-256 mismatch", expected[index][failed])
if (length(missing) + length(extra) + sum(failed)) quit(status = 1L)
cat(sprintf("All %d processed files match their frozen SHA-256 hashes (%d Step 15, %d Step 17).\n",
  length(expected), nrow(manifest), nrow(step17)))
