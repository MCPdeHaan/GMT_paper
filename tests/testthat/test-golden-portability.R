test_that("native and system SHA-256 backends hash exact bytes and spaced paths", {
  env <- new.env(parent = globalenv())
  source(repo_path("tests", "verify_golden_step15.R"), local = env)
  path <- tempfile("gmt hash 'quoted' ")
  withr::defer(unlink(path))
  writeBin(charToRaw("abc"), path)
  expected <- "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  expect_identical(env$sha256_files(path), expected)
  expect_identical(env$sha256_files(path, "system"), expected)
  expect_identical(env$sha256_files(character()), character())
  root <- dirname(dirname(processed_path()))
  reference <- if (uses_revised_table_iv()) {
    "r10b"
  } else if (file.exists(processed_path("diagnostics", STATUTORY_RATE_SPECIFICATION_FILE))) {
    "r09b"
  } else if (file.exists(processed_path("diagnostics", BEHAVIOURAL_SPECIFICATION_FILE))) {
    "r06b"
  } else if (file.exists(processed_path("stage4_5_utpr_policy.rds"))) {
    "r05b"
  } else {
    "r04b"
  }
  manifest <- env$read_golden_manifest(repo_root, reference)
  expect_identical(env$sha256_files(file.path(root, manifest$path), "system"), manifest$sha256)
})
