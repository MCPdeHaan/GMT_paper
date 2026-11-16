# Usage from any directory:
# Rscript /path/to/GMT_paper/tests/verify_golden_step15.R [output-root] [r06b|r05b|r04b|r04]
# SHA-256 checks exact bytes, independently of the R serialisation version.
sha256_files <- function(paths, backend = c("auto", "system")) {
  backend <- match.arg(backend)
  if (!length(paths)) return(character())
  if (backend == "auto" && exists("sha256sum", envir = asNamespace("tools"), inherits = FALSE)) {
    return(unname(get("sha256sum", envir = asNamespace("tools"))(paths)))
  }
  commands <- Sys.which(c("sha256sum", "shasum", "openssl"))
  available <- which(nzchar(commands))
  if (!length(available)) stop("SHA-256 needs tools::sha256sum, sha256sum, shasum or openssl.")
  command <- commands[[available[1L]]]
  name <- names(commands)[available[1L]]
  prefix <- switch(name, sha256sum = character(), shasum = c("-a", "256"),
    openssl = c("dgst", "-sha256"))
  vapply(normalizePath(paths, mustWork = TRUE), function(path) {
    output <- system2(command, c(prefix, shQuote(path)), stdout = TRUE, stderr = TRUE)
    if (!is.null(attr(output, "status"))) stop("SHA-256 command failed: ", paste(output, collapse = "\n"))
    # Coreutils/shasum prefix the digest; openssl suffixes it.
    pattern <- if (name == "openssl") "[[:xdigit:]]{64}$" else "^[[:xdigit:]]{64}"
    hash <- regmatches(output, regexpr(pattern, output))
    if (length(hash) != 1L) stop("Cannot parse SHA-256 output for ", path)
    tolower(hash)
  }, character(1), USE.NAMES = FALSE)
}

read_golden_manifest <- function(repo_root, reference = c("r06b", "r05b", "r04b", "r04")) {
  reference <- match.arg(reference)
  if (reference %in% c("r06b", "r05b")) {
    return(utils::read.csv(file.path(repo_root, "tests", paste0("golden_", reference, ".csv"))))
  }
  manifest <- readRDS(file.path(repo_root, "tests", "golden_step15_manifest.rds"))$files
  step17 <- utils::read.csv(file.path(repo_root, "tests", "golden_step17_additions.csv"))
  r04b <- if (reference == "r04b") {
    utils::read.csv(file.path(repo_root, "tests", "golden_r04b_additions.csv"))
  }
  data.frame(path = c(manifest$path, step17$path, r04b$path),
    sha256 = c(manifest$sha256, step17$sha256, r04b$sha256))
}

verify_golden_step15 <- function(root, repo_root, reference = c("r06b", "r05b", "r04b", "r04")) {
  reference <- match.arg(reference)
  if (getRversion() < "4.3.0") stop("The verifier supports R >= 4.3.")
  if (getRversion() < "4.6.0" || getRversion() >= "4.7.0") {
    message("Note: running R ", getRversion(), "; the frozen outputs were produced with R 4.6.0. ",
      "Verifying exact file bytes; no reserialisation is required.")
  }
  root <- normalizePath(root, mustWork = TRUE)
  manifest <- read_golden_manifest(repo_root, reference)
  expected <- manifest$path
  expected_hashes <- manifest$sha256
  actual <- file.path("data", "processed",
    list.files(file.path(root, "data", "processed"), "\\.(rds|csv)$", recursive = TRUE))
  stopifnot(!anyDuplicated(expected), !anyDuplicated(actual))
  report <- function(label, paths) {
    if (length(paths)) cat(label, paste(paths, collapse = "\n"), "\n", sep = "\n", file = stderr())
  }
  missing <- setdiff(expected, actual)
  extra <- setdiff(actual, expected)
  index <- expected %in% actual
  hashes <- sha256_files(file.path(root, expected[index]))
  failed <- is.na(hashes) | hashes != expected_hashes[index]
  report("Missing", missing)
  report("Unexpected", extra)
  report("SHA-256 mismatch", expected[index][failed])
  if (length(missing) + length(extra) + sum(failed)) return(FALSE)
  cat(sprintf("All %d processed files match their frozen SHA-256 hashes (reference %s).\n",
    length(expected), reference))
  TRUE
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) > 2L) stop("Usage: Rscript tests/verify_golden_step15.R [output-root] [r06b|r05b|r04b|r04]")
  script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  repo_root <- file.path(dirname(normalizePath(script, mustWork = TRUE)), "..")
  root <- if (length(args)) args[[1L]] else repo_root
  reference <- if (length(args) == 2L) args[[2L]] else "r06b"
  if (!verify_golden_step15(root, repo_root, reference)) quit(status = 1L)
}
