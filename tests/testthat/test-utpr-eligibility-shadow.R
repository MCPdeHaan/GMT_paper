utpr_shadow_env <- function() {
  env <- new.env(parent = globalenv())
  source_pipeline("allocation/utpr_eligibility_shadow.R", env)
  env
}

test_that("UTPR evidence separates fiscal applicability, enactment and verification", {
  env <- utpr_shadow_env()
  legal <- env$read_utpr_evidence(repo_path("data", "legal", "utpr_eligibility_2026.csv"))
  fetch <- function(ids) legal[match(ids, legal$iso3), ]
  expect_true(all(env$EU27_ISO3 %in% legal$iso3))
  expect_equal(anyDuplicated(legal[c("iso3", "rule", "evaluation_date")]), 0L)
  expect_identical(unique(legal$rule), "UTPR")
  expect_identical(unique(legal$evaluation_date), as.Date("2026-01-01"))
  expect_identical(unique(legal$evidence_cutoff), as.Date("2026-11-15"))
  expect_true(all(legal$status %in% env$UTPR_LEGAL_STATUSES))
  expect_true(all(legal$source_retrieval_date <= legal$evidence_cutoff))
  expect_identical(fetch(c("CYP", "IDN", "JPN", "CAN", "HKG"))$status,
    c("verified_applicable", "verified_applicable", rep("verified_not_applicable", 3)))
  expect_identical(fetch(c("IDN", "JPN"))$first_applicable_fy_start,
    as.Date(c("2026-01-01", "2026-04-01")))
  expect_identical(fetch(c("CAN", "HKG"))$enactment_status, c("not_enacted", "enacted"))
  expect_true(is.na(fetch("HKG")$first_applicable_fy_start))
  expect_lt(fetch("GBR")$first_applicable_fy_start, fetch("GBR")$enactment_date)
  expect_identical(fetch("CYP")$oecd_utpr_qualification, "not_established")
  expect_true(any(legal$status == "not_established"))
  expect_error(env$validate_utpr_evidence(rbind(legal, legal[1L, ])), "Duplicated")
  bad <- legal
  bad$status[1L] <- "NO"
  expect_error(env$validate_utpr_evidence(bad), "UTPR_LEGAL_STATUSES")
  bad <- legal
  bad$commencement_date[bad$iso3 == "IDN"] <- as.Date("2022-01-01")
  expect_error(env$validate_utpr_evidence(bad), "commencement_date")
  bad <- legal
  bad$source_publication_date[1L] <- as.Date("2027-01-01")
  expect_error(env$validate_utpr_evidence(bad), "source_publication_date")
  bad <- legal
  bad$first_applicable_fy_start[bad$iso3 == "IDN"] <- as.Date("2026-01-02")
  expect_error(env$validate_utpr_evidence(bad), "first_applicable_fy_start")
})

test_that("Article 50 deferral and the source-side exception remain separate", {
  env <- utpr_shadow_env()
  legal <- env$read_utpr_evidence(repo_path("data", "legal", "utpr_eligibility_2026.csv"))
  elected <- dplyr::filter(legal, article50_status == "elected")
  expect_setequal(elected$iso3, c("EST", "LVA", "LTU", "MLT", "SVK"))
  expect_true(all(elected$status == "deferred"))
  expect_true(all(elected$article50_source_rule == "other_member_states"))
  expect_identical(elected$iso3[elected$domestic_topup_status == "separate_rule_applicable"], "SVK")
  bad <- legal
  bad$article50_source_rule[bad$iso3 == "EST"] <- "not_applicable"
  expect_error(env$validate_utpr_evidence(bad), "article50_source_rule")
})

utpr_shadow_fixture <- function() {
  # AAA originally routes 1/4 to NLD and 3/4 to CAN. For BBB the only
  # parent-year route is Australian, with a genuine zero EU share.
  activity <- tibble::tribble(
    ~parent, ~year, ~collector, ~employees, ~assets,
    "AAA", 2017L, "NLD", 1, 1,
    "AAA", 2017L, "CAN", 3, 3,
    "BBB", 2017L, "AUS", 2, 2,
    "CCC", 2017L, "GGY", 0, 2,
    "DDD", 2023L, "SVK", 1, 1
  ) |>
    dplyr::mutate(collector_name = collector, collector_is_eu27 = collector %in% c("NLD", "SVK"),
      employee_base = employees, asset_base = assets, collector_utpr_flag = collector != "SVK",
      collector_utpr_explicit_flag = collector_utpr_flag, collector_utpr_ambiguous_flag = FALSE)
  mapping <- tibble::tribble(
    ~iso3, ~status, ~collector_scope,
    "NLD", "verified_applicable", "candidate",
    "CAN", "verified_not_applicable", "candidate",
    "AUS", "verified_applicable", "candidate",
    "GGY", "not_established", "candidate",
    "SVK", "deferred", "candidate",
    "USA", "not_established", "parent_context"
  )
  source <- tibble::tribble(
    ~scenario_id, ~parent, ~year, ~stage4_utpr_pool, ~stage4_sbs_extinguished_liability,
    "x10001", "AAA", 2017L, 80, 0,
    "x10001", "BBB", 2017L, 40, 0,
    "x10001", "CCC", 2017L, 60, 0,
    "x10001", "DDD", 2023L, 10, 0,
    "x10011", "DDD", 2023L, 0, 10
  ) |> dplyr::mutate(topup_after_behaviour = stage4_utpr_pool + stage4_sbs_extinguished_liability)
  fixed <- tibble::tibble(scenario_id = character(), country = character(),
    country_is_eu27 = logical(), year = integer(), channel = character(), revenue = double())
  list(activity = activity, mapping = mapping, source = source, fixed = fixed)
}

test_that("a common policy date changes routes, with fallback and unsupported amounts explicit", {
  env <- utpr_shadow_env()
  f <- utpr_shadow_fixture()
  project <- function(arm, exclude = character()) {
    activity <- env$shadow_activity(f$activity, f$mapping, arm, exclude)
    env$shadow_project(f$source, env$build_parent_year_utpr_weights(activity), f$fixed)
  }
  legacy <- project("LEGACY")
  verified <- project("VERIFIED")
  provisional <- project("VERIFIED_PLUS_UNRESOLVED")
  pool <- function(x, parent_id) dplyr::filter(x$pools, parent == parent_id)
  expect_equal(pool(legacy, "AAA")$eu27_usd, 20)
  expect_equal(pool(verified, "AAA")$eu27_usd, 80)
  expect_identical(pool(verified, "BBB")$route, "parent_year")
  expect_equal(pool(verified, "BBB")$eu27_usd, 0)
  expect_equal(pool(verified, "BBB")$non_eu27_usd, 40)
  expect_identical(pool(verified, "CCC")$route, "global_year_fallback")
  expect_equal(pool(verified, "CCC")$eu27_usd, 20)
  expect_equal(pool(verified, "CCC")$non_eu27_usd, 40)
  expect_identical(pool(provisional, "CCC")$route, "parent_year")
  expect_equal(pool(provisional, "CCC")$eu27_usd, 0)
  expect_equal(pool(provisional, "CCC")$non_eu27_usd, 60)
  expect_identical(pool(verified, "DDD")$route, "unsupported")
  expect_equal(pool(verified, "DDD")$unsupported_usd, 10)
  expect_equal(pool(verified, "DDD")$assigned_usd, 0)
  expect_equal(sum(verified$totals$extinguished_usd), 10)
  expect_equal(sum(verified$totals$source_usd),
    with(verified$totals, sum(assigned_usd + extinguished_usd + unsupported_usd)))
  expect_equal(sum(verified$pools$assigned_usd), with(verified$pools, sum(eu27_usd + non_eu27_usd)))
  summary <- env$shadow_totals(verified)
  universal <- dplyr::filter(summary, scenario_id == "x10001", window == "2017–2023")
  expect_equal(universal$pool_usd, 190)
  expect_equal(universal$parent_year_pool_usd, 120)
  expect_equal(universal$fallback_pool_usd, 60)
  expect_equal(universal$unsupported_pool_usd, 10)
  expect_equal(universal$fallback_pct_of_pool, 100 * 60 / 190)
  # Opt-out removes the activity and rebuilds the denominator, including fallback.
  exit <- project("VERIFIED", exclude = "NLD")
  expect_identical(pool(exit, "AAA")$route, "global_year_fallback")
  expect_equal(pool(exit, "AAA")$non_eu27_usd, 80)
  expect_false(any(exit$channels$country == "NLD"))
  expect_identical(f$mapping$status[f$mapping$iso3 == "GGY"], "not_established")
})

test_that("frozen weights and the audited routing contract reproduce the preferred scenarios", {
  env <- utpr_shadow_env()
  source <- readRDS(processed_path("stage4_5_allocation_source_panel.rds")) |>
    dplyr::filter(scenario_id %in% env$NASH_IDS)
  activity <- env$build_collector_activity(source)
  weights <- env$build_parent_year_utpr_weights(activity)
  saved_weights <- env$read_stage4_utpr_weights(dirname(processed_path("stage4_5_utpr_parent_year_weights.rds")))
  specification <- if (is.null(saved_weights$policy)) "LEGACY_FALLBACK" else saved_weights$policy$specification
  expect_identical(env$build_production_utpr_weights(source, specification), saved_weights)
  policy <- env$build_policy_flags(readRDS(processed_path("oecd_pillar2_central_record.rds")))
  legal <- env$compare_utpr_eligibility(
    env$read_utpr_evidence(repo_path("data", "legal", "utpr_eligibility_2026.csv")), activity, policy, weights)
  expect_true(all(is.na(legal$independent_utpr_rule_rows)))
  expect_identical(legal$explicit_label_basis[legal$iso3 == "CAN"], "iir_proxy_only")
  expect_identical(legal$proxy_discrepancy[legal$iso3 == "CAN"], "false_positive")
  expect_identical(legal$proxy_discrepancy[legal$iso3 == "CYP"], "omitted_applicable")
  expect_true(legal$legacy_iir_by_2026[legal$iso3 == "CAN"])
  expect_false(legal$verified[legal$iso3 == "CAN"])
  projected <- env$shadow_project(source, weights)
  saved <- readRDS(processed_path("stage4_5_revenue_by_channel_global.rds")) |>
    dplyr::filter(scenario_id %in% env$NASH_IDS)
  active <- env$shadow_project(source, saved_weights)
  expect_lt(env$compare_shadow_channels(active$channels, saved,
    c("scenario_id", "country", "year", "channel")), 1e-3)
  expect_equal(sum(projected$pools$unsupported_usd), 0)
  if (specification == "VERIFIED_PARENT_ONLY") {
    expect_gt(sum(active$pools$unsupported_usd), 0)
    expect_identical(nrow(saved_weights$fallback_weights), 0L)
    expect_identical(saved_weights$policy$eligible, sort(legal$iso3[legal$verified & legal$collector_scope == "candidate"]))
  }
  verified <- env$shadow_project(source,
    env$build_parent_year_utpr_weights(env$shadow_activity(activity, legal, "VERIFIED")))
  expect_identical(verified$fixed, projected$fixed)
  keys <- c("scenario_id", "year")
  expect_identical(dplyr::arrange(verified$totals[c(keys, "source_usd", "extinguished_usd")], dplyr::across(dplyr::all_of(keys))),
    dplyr::arrange(projected$totals[c(keys, "source_usd", "extinguished_usd")], dplyr::across(dplyr::all_of(keys))))
})

test_that("the production recipient map keeps applicability separate from IIR and qualification", {
  env <- utpr_shadow_env()
  legal <- env$read_utpr_evidence(repo_path("data", "legal", "utpr_eligibility_2026.csv"))
  excluded <- c("CAN", "CHE", "GIB", "HKG", "IMN", "JEY", "JPN", "LIE", "MYS", "QAT", "SGP", "VNM", "ZAF")
  activity <- tibble::tibble(collector = c(excluded, "GGY"), collector_utpr_flag = TRUE)
  legacy <- env$utpr_collector_policy("LEGACY_FALLBACK", activity)
  strict <- env$utpr_collector_policy("VERIFIED_PARENT_ONLY", activity, legal)
  fallback <- env$utpr_collector_policy("VERIFIED_FALLBACK", activity, legal)
  unresolved <- env$utpr_collector_policy("VERIFIED_PLUS_UNRESOLVED_PARENT_ONLY", activity, legal)
  expect_identical(strict$evaluation_date, as.Date("2026-01-01"))
  expect_identical(strict$evidence_cutoff, as.Date("2026-11-15"))
  expect_identical(sort(intersect(excluded, legacy$eligible)), sort(excluded))
  expect_length(intersect(strict$eligible, c(excluded, "EST", "LVA", "LTU", "MLT", "SVK", "GGY")), 0L)
  expect_true("CYP" %in% strict$eligible)
  expect_identical(strict$eligible, fallback$eligible)
  expect_identical(setdiff(unresolved$eligible, strict$eligible), "GGY")
  expect_identical(unresolved$provisional, "GGY")
  expect_true(all(legal$oecd_utpr_qualification[match(strict$eligible, legal$iso3)] == "not_established"))
})

test_that("the eligibility and support comparison has a separately identified interaction", {
  env <- new.env(parent = globalenv())
  source_pipeline("allocation/utpr_policy_comparison.R", env)
  result <- env$utpr_decompose(tibble::tibble(metric = "receipts",
    specification = env$UTPR_SPECIFICATIONS, value = c(80, 95, 60, 90, 92)), "metric")
  expect_equal(unlist(result[c("eligibility_with_fallback", "fallback_removed_under_legacy",
    "interaction", "combined", "unresolved_sensitivity")], use.names = FALSE), c(15, -20, 15, 10, 2))
})
