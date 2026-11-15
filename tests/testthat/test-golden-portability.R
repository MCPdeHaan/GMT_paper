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
  manifest <- readRDS(repo_path("tests", "golden_step15_manifest.rds"))$files
  addition <- read.csv(repo_path("tests", "golden_step17_additions.csv"))
  expect_identical(env$sha256_files(repo_path(c(manifest$path, addition$path)), "system"),
    c(manifest$sha256, addition$sha256))
})
