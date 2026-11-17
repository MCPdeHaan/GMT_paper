beta_stage03 <- source_pipeline("03_stage1_etr.R", new.env())
beta_stage08 <- source_pipeline("08_measurement_and_cbcr_extensions.R", new.env())
# Recorded before extraction from R07, with its inputs, fit objects and warnings.
beta_reference <- readRDS(test_path("fixtures", "r07-beta-characterisation.rds"))

record_beta_call <- function(fun, args) {
  warnings <- character()
  result <- withCallingHandlers(
    tryCatch(do.call(fun, args), error = function(e) list(error = conditionMessage(e))),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  list(result = result, warnings = warnings)
}

test_that("mean-anchored production and audit fits exactly match the R07 fixtures", {
  original_inputs <- serialize(beta_reference$inputs, NULL)
  for (name in names(beta_reference$inputs)) {
    args <- beta_reference$inputs[[name]]
    expect_identical(record_beta_call(beta_stage03$fit_constrained_beta_percentiles, args),
                     beta_reference$production[[name]], info = name)
    expect_identical(record_beta_call(beta_stage08$fit_audit_mean_beta, args),
                     beta_reference$audit[[name]], info = name)
  }
  expect_identical(serialize(beta_reference$inputs, NULL), original_inputs)
})

test_that("conditioning and point-mean handling retain the original fit contract", {
  q <- c(-0.2, 0.10, 0.05, 1.20, 1.40)
  expect_identical(beta_stage03$condition_stage1_percentiles(q), c(0, 0.1, 0.1, 1, 1))
  expect_identical(beta_stage03$condition_stage1_percentiles(q, 0.12), c(0, 0.1, 0.1, 0.12, 0.12))

  fields <- c(alpha = "double", beta = "double", precision = "double", mean = "double",
    sse = "double", mae = "double", max_abs_error = "double",
    boundary_flag = "logical", quantiles = "double")
  lower <- beta_stage03$fit_constrained_beta_percentiles(q, 0)
  upper <- beta_stage03$fit_constrained_beta_percentiles(q, 1, upper_cap = 0.12)
  missing <- beta_stage03$fit_constrained_beta_percentiles(q, NA_real_)
  for (fit in list(lower, upper, missing)) expect_identical(vapply(fit, typeof, ""), fields)
  expect_identical(lower$quantiles, rep(0, 5))
  expect_identical(upper$quantiles, rep(1, 5))
  expect_identical(c(lower$mean, upper$mean), c(0, 1))
  expect_identical(c(lower$boundary_flag, upper$boundary_flag, missing$boundary_flag), c(TRUE, TRUE, NA))
  expect_true(all(is.na(unlist(missing))))
  expect_identical(beta_stage03$fit_constrained_beta_percentiles(c(0, NA, 1, 1, 1), 0), missing)
  expect_identical(beta_stage03$beta_mass_below(NA_real_, NA_real_, 0.15, 0), 1)
  expect_identical(beta_stage03$beta_mass_below(NA_real_, NA_real_, 0.15, 1), 0)
  expect_identical(beta_stage03$beta_avg_topup_rate(NA_real_, NA_real_), 0)
})

test_that("both guarded quantile routines retain their extreme-tail and precision rules", {
  for (name in names(beta_reference$quantile_inputs)) {
    args <- beta_reference$quantile_inputs[[name]]
    expect_identical(record_beta_call(beta_stage03$beta_quantiles, args),
                     beta_reference$quantile_production[[name]], info = name)
    expect_identical(record_beta_call(beta_stage08$audit_beta_quantiles, args),
                     beta_reference$quantile_audit[[name]], info = name)
  }
  p <- c(0, 0.05, 0.5, 0.95, 1)
  expect_identical(beta_stage03$beta_quantiles(p, 2, 8), stats::qbeta(p, 2, 8))
  expect_identical(beta_stage08$audit_beta_quantiles(p, 2, 8), stats::qbeta(p, 2, 8))
  expect_identical(beta_stage03$beta_quantiles(p, 1e5, 2e5), rep(1 / 3, length(p)))
  expect_gt(diff(range(beta_stage08$audit_beta_quantiles(p[2:4], 1e5, 2e5))), 0)

  # The base-R starting quantile has a material CDF residual in this subnormal
  # tail. On this support the leading incomplete-beta term is accurate.
  a <- 1e-4
  b <- 0.01
  p <- 0.92
  base <- suppressWarnings(stats::qbeta(p, a, b))
  recovered <- beta_stage08$audit_beta_quantiles(p, a, b)
  leading_cdf <- function(x) exp(a * log(x) - log(a) - lbeta(a, b))
  expect_gt(abs(leading_cdf(base) - p), 1e-8)
  expect_gt(recovered, 0)
  expect_lt(recovered, base)
  expect_lt(abs(leading_cdf(recovered) - p), 1e-8)
  expect_identical(beta_stage03$beta_quantiles(p, a, b), recovered)
})

test_that("the injected strategy drives the loss and fitted quantiles under both optimisers", {
  bounds <- log(c(1e-4, 1e6))
  q <- rep(0.6, 5)
  mean_anchor <- 0.25
  quantile_value <- function(log_precision) {
    0.2 + 0.1 * (log_precision - bounds[1]) / diff(bounds)
  }
  log_calls <- numeric()
  strategy <- function(probs, alpha, beta) {
    log_calls <<- c(log_calls, log(alpha + beta))
    rep(quantile_value(tail(log_calls, 1)), length(probs))
  }

  # This monotone objective has its minimum at the upper bound. Only the
  # capped search evaluates and can select the exact endpoint.
  expected <- stats::optimize(function(x) sum((quantile_value(x) - q)^2), bounds)$minimum
  uncapped <- beta_stage03$fit_constrained_beta_percentiles(q, mean_anchor, quantile_function = strategy)
  expect_equal(log(uncapped$precision), expected, tolerance = 1e-10)
  expect_true(all(log_calls > bounds[1] & log_calls < bounds[2]))
  expect_identical(uncapped$quantiles, rep(quantile_value(tail(log_calls, 1)), 5))
  expect_identical(uncapped$sse, sum((uncapped$quantiles - q)^2))

  log_calls <- numeric()
  capped <- beta_stage03$fit_constrained_beta_percentiles(q, mean_anchor, upper_cap = 1,
    quantile_function = strategy)
  expect_identical(capped$precision, exp(bounds[2]))
  expect_equal(range(log_calls), bounds, tolerance = 1e-12)
  expect_identical(capped$quantiles, rep(quantile_value(tail(log_calls, 1)), 5))
  expect_identical(capped$sse, sum((capped$quantiles - q)^2))
  expect_identical(capped$mean, mean_anchor)
})

test_that("default and explicit strategies are stable and source-compatible across call orders", {
  q <- beta_reference$inputs$above_cap$q
  mean_anchor <- beta_reference$inputs$above_cap$target_mean
  probs <- beta_stage03$PERCENTILE_PROBS
  cap <- 0.20825
  recorded <- beta_reference$production$above_cap$result
  audit_recorded <- beta_reference$audit$above_cap$result

  expect_identical(environment(beta_stage08$fit_audit_mean_beta), beta_stage08)
  expect_identical(environment(beta_stage08$fit_constrained_beta_percentiles), beta_stage08)
  expect_identical(beta_stage08$fit_audit_mean_beta(q, mean_anchor, probs, cap), audit_recorded)
  expect_identical(beta_stage08$fit_constrained_beta_percentiles(q, mean_anchor, probs, cap), recorded)
  expect_identical(beta_stage03$fit_constrained_beta_percentiles(q, mean_anchor, probs, cap,
    beta_stage03$beta_quantiles), recorded)
  expect_identical(beta_stage03$fit_constrained_beta_percentiles(
    upper_cap = cap, target_mean = mean_anchor, q = q, probs = probs), recorded)
  expect_identical(beta_stage08$fit_audit_mean_beta(q, mean_anchor, upper_cap = cap), audit_recorded)
  expect_identical(body(beta_stage08$beta_quantiles), body(beta_stage03$beta_quantiles))
})

test_that("valid Beta tails satisfy independently checked identities", {
  for (name in c("unimodal", "u_shaped", "concentrated", "dispersed")) {
    args <- beta_reference$inputs[[name]]
    fit <- do.call(beta_stage03$fit_constrained_beta_percentiles, args)
    expect_gt(fit$alpha, 0)
    expect_gt(fit$beta, 0)
    expect_equal(fit$alpha / (fit$alpha + fit$beta), args$target_mean, tolerance = 1e-10)
    share <- beta_stage03$beta_mass_below(fit$alpha, fit$beta)
    moment <- beta_stage03$beta_first_moment_below(fit$alpha, fit$beta)
    gap <- beta_stage03$beta_avg_topup_rate(fit$alpha, fit$beta)
    expect_identical(share, stats::pbeta(0.15, fit$alpha, fit$beta))
    expect_true(0 <= share && share <= 1 && 0 <= moment && moment <= share)
    conditional_etr <- moment / share
    expect_true(0 <= conditional_etr && conditional_etr <= 0.15)
    expect_gte(gap, 0)
    expect_equal(share * gap, 0.15 * share - moment, tolerance = 1e-10)
    expect_equal(sum(beta_stage03$beta_bracket_shares(fit$alpha, fit$beta)), 1, tolerance = 1e-10)
  }
  # For the uniform distribution, the integral of x over [0, .15] is .15²/2.
  expect_equal(beta_stage03$beta_first_moment_below(1, 1), 0.15^2 / 2, tolerance = 1e-10)
})

test_that("rank feasibility searches both intervals and preserves unconditioned ranks", {
  cdf <- function(log_precision) {
    precision <- exp(log_precision)
    mean <- beta_reference$rank_mean
    stats::pbeta(0.15, mean * precision, (1 - mean) * precision)
  }
  rank <- beta_reference$rank
  intervals <- beta_stage03$stage1_rank_feasibility(cdf, beta_stage03$BETA_PRECISION_LOG_BOUNDS, rank)
  expect_identical(intervals, beta_reference$rank_feasibility)
  expect_length(intervals$low, 2L)
  expect_true(intervals$high[1] < intervals$low[2])
  expect_true(all(cdf((intervals$low + intervals$high) / 2) >= rank["lower"]))
  expect_true(all(cdf((intervals$low + intervals$high) / 2) <= rank["upper"]))
  expect_lt(cdf(mean(c(intervals$high[1], intervals$low[2]))), rank["lower"])

  for (name in names(beta_reference$variants)) {
    result <- record_beta_call(beta_stage03$stage1_fit_cell, beta_reference$variants[[name]])
    expect_identical(result, beta_reference$variant_results[[name]], info = name)
    fit <- result$result
    rank_fit <- fit[fit$model == beta_stage03$STAGE1_BETA_MODELS[3], ]
    expect_true(all(rank_fit$share >= rank_fit$rank_lower & rank_fit$share <= rank_fit$rank_upper))
    expect_identical(fit$liability_rate, fit$share * fit$gap)
  }
  fits <- do.call(beta_stage03$stage1_fit_cell, beta_reference$variants$p95_above)
  expect_identical(fits$p95_excluded[1:3], c(FALSE, TRUE, FALSE))
  expect_identical(fits$omega[4:8], seq(0, 1, 0.25))
  expect_gte(fits$precision[2], 1 / max(fits$target_mean[2], 1 - fits$target_mean[2]))
  tied <- do.call(beta_stage03$stage1_fit_cell, beta_reference$variants$p95_tied)
  expect_false(tied$p95_excluded[2])
  low_cap <- do.call(beta_stage03$stage1_fit_cell, beta_reference$variants$low_cap)
  expect_lt(low_cap$rank_lower[3], low_cap$capped_rank_lower[3])
  boundary <- do.call(beta_stage03$stage1_fit_cell, beta_reference$variants$boundary)
  expect_true(boundary$rank_projection[3])
  expect_identical(boundary$share[3], boundary$rank_upper[3])
  expect_error(beta_stage03$stage1_fit_cell(c(0, 0, NA, 0.2, 0.3), 0.2, 1,
    beta_stage03$STAGE1_BETA_MODELS[3]), "all.*is.finite")
})

test_that("Stage 08 retains the five distinct estimator outputs and sparse hurdle support", {
  for (name in names(beta_reference$estimator_inputs)) {
    for (model in beta_stage08$MODEL_IDS) {
      args <- c(beta_reference$estimator_inputs[[name]], list(model = model))
      expect_identical(record_beta_call(beta_stage08$fit_percentile_model, args),
                       beta_reference$estimator_results[[name]][[model]], info = paste(name, model))
    }
  }

  hurdle <- beta_stage08$MODEL_IDS[3]
  one_positive <- beta_stage08$fit_percentile_model(c(0, 0, 0, 0, 0.18), 0.04, hurdle)
  expect_true(one_positive$sparse_tail)
  expect_identical(one_positive$zero_mass, 0.75)
  point_tail <- beta_stage08$fit_percentile_model(rep(0, 5), 0.03, hurdle)
  expect_true(point_tail$sparse_tail)
  expect_identical(point_tail$low_share, 0.95)
  expect_equal(point_tail$liability_rate, 0.95 * 0.15, tolerance = 1e-10)
  expect_equal(point_tail$fitted_mean, 0.03, tolerance = 1e-10)
})

test_that("the isolated kernel source leaves the working directory and session untouched", {
  withr::local_dir(withr::local_tempdir())
  namespaces <- sort(loadedNamespaces())
  attached <- search()
  opts <- options()
  seed <- get0(".Random.seed", envir = globalenv(), inherits = FALSE)
  kernel <- new.env(parent = baseenv())
  sys.source(repo_path("code", "measurement", "beta_fit.R"), kernel)
  expect_identical(sort(loadedNamespaces()), namespaces)
  expect_identical(search(), attached)
  expect_identical(options(), opts)
  expect_identical(get0(".Random.seed", envir = globalenv(), inherits = FALSE), seed)
  expect_identical(list.files(all.files = TRUE, no.. = TRUE), character())
  expect_identical(kernel$fit_constrained_beta_percentiles(c(0, 0.1, 0.2, 0.3, 0.4), 0.20),
                   beta_stage03$fit_constrained_beta_percentiles(c(0, 0.1, 0.2, 0.3, 0.4), 0.20))
  expect_identical(kernel$beta_quantiles(0.75, 0.005, 0.01),
                   beta_stage03$beta_quantiles(0.75, 0.005, 0.01))
})

test_that("Stage 03 panels and Stage 03 and 08 validation files retain their ordered contracts", {
  manifest_env <- new.env(parent = globalenv())
  source(repo_path("tests", "verify_golden_step15.R"), local = manifest_env)
  standard <- !is.null(statutory_rate_metadata(processed_path()))
  reference <- if (standard) "r09b" else "r06b"
  manifest <- manifest_env$read_golden_manifest(repo_root, reference)
  panels <- list(
    stage1_affiliate_year.rds = c(1503L, 111L),
    stage1_bilateral_panel.rds = c(18954L, if (standard) 490L else 460L)
  )
  for (file in names(panels)) {
    active <- readRDS(processed_path(file))
    key <- intersect(c("parent", "affiliate", "year"), names(active))
    expect_identical(dim(active), panels[[file]])
    expect_identical(anyDuplicated(active[key]), 0L)
    expected <- manifest$sha256[manifest$path == file.path("data", "processed", file)]
    expect_identical(manifest_env$sha256_files(processed_path(file)), expected)
  }
  diagnostics <- manifest[grepl("/(step3_stage1_|audit_step4_stage1_|step10_estimator_rank_consistency)",
    manifest$path), ]
  active <- processed_path(sub("^data/processed/", "", diagnostics$path))
  expect_true(all(file.exists(active)))
  expect_identical(manifest_env$sha256_files(active), diagnostics$sha256)

  samples <- c("affiliate_year", "affiliate_year_parent_restricted", "bilateral_matched")
  counts <- vapply(samples, function(sample) {
    length(readLines(processed_path("diagnostics", paste0("step3_stage1_crossval_", sample, ".csv")))) - 1L
  }, integer(1))
  expect_identical(unname(counts), c(361L, 70L, 81L))
})
