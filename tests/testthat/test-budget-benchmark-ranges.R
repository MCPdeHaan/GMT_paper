budget_range_fixture <- function(env) {
  # An independent binary design with all years retained. Amounts below are
  # in annual EUR billions before conversion to the allocator's USD units.
  cells <- tidyr::expand_grid(
    country = c("NLD", "BEL"), year = 2019:2023, x1_etr = 0:1,
    x2_substance = 0:1, x3_rates = 0:1, x4_sbs = 0:1, x5_behaviour = 0:1
  ) |>
    dplyr::mutate(
      scenario_id = paste0("x", x1_etr, x2_substance, x3_rates, x4_sbs, x5_behaviour),
      level = env$LADDER_LEVELS[1L + 2L * x1_etr],
      QDMTT = (year - 2019) + 4 * x1_etr + 2 * x4_sbs + ifelse(country == "BEL", 10, 0),
      IIR = 3 + x2_substance, UTPR = 10 + x3_rates + x5_behaviour
    )
  revenue <- dplyr::mutate(cells, revenue = (QDMTT + IIR + UTPR) * 1.0813e9) |>
    dplyr::select(-QDMTT, -IIR, -UTPR)
  channels <- tidyr::pivot_longer(cells, c(QDMTT, IIR, UTPR),
    names_to = "channel", values_to = "revenue") |>
    dplyr::mutate(revenue = revenue * 1.0813e9)
  forecasts <- tibble::tribble(
    ~country, ~benchmark, ~model_scope, ~official_low_eur_bn, ~official_high_eur_bn, ~stated_sbs_switch,
    "NLD", "interval", "direct", 17.5, 18.5, 0L,
    "NLD", "between scenarios", "qdmt", 5, 5, 1L,
    "NLD", "IIR only", "iir", 2, 2, NA_integer_,
    "NLD", "no amount", "direct", NA_real_, NA_real_, 0L,
    "BEL", "two channels", "qdmt_iir", 20, 21, 0L
  )
  list(revenue = revenue, channels = channels, forecasts = forecasts)
}

budget_range_env <- function() {
  env <- new.env(parent = globalenv())
  source_pipeline("08_measurement_and_cbcr_extensions.R", env)
  env
}

test_that("the core partitions disjointly into L1 and L3 and excludes the other ladder variants", {
  env <- budget_range_env()
  fixture <- budget_range_fixture(env)
  design <- unique(fixture$revenue[c("scenario_id", "level")])
  l1 <- design$scenario_id[design$level == env$LADDER_LEVELS[1L]]
  l3 <- design$scenario_id[design$level == env$LADDER_LEVELS[3L]]
  expect_length(l1, 16L)
  expect_length(l3, 16L)
  expect_length(intersect(l1, l3), 0L)
  expect_length(union(l1, l3), 32L)

  run <- function(revenue) env$ladder_core_budget_ranges(revenue, fixture$channels, fixture$forecasts)
  rows <- run(fixture$revenue)
  extra <- dplyr::mutate(fixture$revenue, level = env$LADDER_LEVELS[2L], revenue = 1e18)
  expect_identical(run(dplyr::bind_rows(extra, fixture$revenue)), rows)
  expect_identical(run(fixture$revenue[nrow(fixture$revenue):1L, ]), rows)
  expect_error(run(dplyr::filter(fixture$revenue, scenario_id != "x00000")), "nrow\\(design\\)")
  expect_error(run(dplyr::bind_rows(fixture$revenue, fixture$revenue[1, ])), "support")
  expect_error(run(dplyr::mutate(fixture$revenue,
    level = ifelse(scenario_id == "x00000", env$LADDER_LEVELS[3L], level))), "design")

  counts <- dplyr::filter(rows, benchmark == "interval", window == "FY2023")
  expect_identical(counts$scenario_scope, c("l3", "core", "l3_policy", "core_policy"))
  expect_identical(counts$scenario_count, c(16L, 32L, 8L, 16L))
  expect_equal(counts$scenario_min_eur_bn, c(21, 17, 21, 17), tolerance = 1e-12)
  expect_equal(counts$scenario_max_eur_bn, c(26, 26, 24, 24), tolerance = 1e-12)
  expect_identical(counts$preferred_universal_scenario, rep("x10001", 4L))
  expect_identical(counts$preferred_sbs_scenario, c("x10011", "x10011", NA_character_, NA_character_))
})

test_that("closest scenarios use the interval, channel, fiscal window and documented policy", {
  env <- budget_range_env()
  f <- budget_range_fixture(env)
  rows <- env$ladder_core_budget_ranges(f$revenue, f$channels, f$forecasts)
  row <- function(label, period = "FY2023", scope = "core") {
    dplyr::filter(rows, benchmark == label, window == period, scenario_scope == scope)
  }
  r <- row("interval")
  expect_true(r$official_interval_overlaps_model_range)
  expect_identical(r$closest_scenario, "x00001")
  expect_equal(r$closest_scenario_eur_bn, 18, tolerance = 1e-12)
  expect_equal(r$closest_gap_eur_bn, 0)
  expect_equal(r$closest_tie_count, 3)
  average <- row("interval", "2019–2023")
  expect_equal(average$scenario_min_eur_bn, 15, tolerance = 1e-12)
  expect_equal(average$scenario_max_eur_bn, 24, tolerance = 1e-12)

  qdmt <- row("between scenarios")
  expect_true(qdmt$official_interval_overlaps_model_range)
  expect_identical(qdmt$closest_scenario, "x00000")
  expect_equal(qdmt$closest_tie_count, 16L)
  expect_equal(qdmt$closest_gap_eur_bn, 1, tolerance = 1e-12)
  qdmt_sbs <- row("between scenarios", scope = "core_policy")
  expect_equal(qdmt_sbs$scenario_min_eur_bn, 6, tolerance = 1e-12)
  expect_false(qdmt_sbs$official_interval_overlaps_model_range)
  expect_identical(qdmt_sbs$closest_scenario, "x00010")
  expect_identical(qdmt_sbs$preferred_sbs_scenario, "x10011")

  iir <- row("IIR only")
  expect_equal(c(iir$scenario_min_eur_bn, iir$scenario_max_eur_bn), c(3, 4), tolerance = 1e-12)
  expect_false(iir$official_interval_overlaps_model_range)
  unknown <- row("IIR only", scope = "core_policy")
  expect_identical(unknown$comparison_status, "policy_unknown")
  expect_equal(unknown$scenario_count, 0L)
  expect_true(is.na(unknown$closest_scenario) && is.na(unknown$scenario_min_eur_bn))
  expect_true(is.na(unknown$official_interval_overlaps_model_range))
  unquantified <- row("no amount")
  expect_identical(unquantified$comparison_status, "unquantified")
  expect_equal(unquantified$scenario_count, 32L)
  expect_true(is.na(unquantified$closest_gap_eur_bn))
  two <- row("two channels")
  expect_identical(two$country, "BEL")
  expect_equal(c(two$scenario_min_eur_bn, two$scenario_max_eur_bn), c(17, 24), tolerance = 1e-12)
  expect_true(two$official_interval_overlaps_model_range)
})

test_that("the corrected budget records preserve channel and policy provenance", {
  env <- budget_range_env()
  forecasts <- env$ladder_budget_forecasts_r04b()
  expect_identical(forecasts$model_scope[forecasts$benchmark == "Slovakia 2026 state budget Pillar Two line"], "qdmt")
  expect_identical(forecasts$model_scope[forecasts$benchmark == "Belgian 2024 budget"], "qdmt_iir")
  expect_identical(forecasts$model_scope[forecasts$benchmark == "Belgian 2024 IIR"], "iir")
  expect_false(any(grepl("behavioural CIT|ordinary corporate|Mixed vintages", forecasts$revenue_scope)))
  expect_identical(forecasts$stated_sbs_switch[forecasts$benchmark == "Projet de loi de finances 2026"], NA_integer_)
})

test_that("parity checks reject a missing source and unequal liability on the same keys", {
  env <- budget_range_env()
  rows <- tibble::tibble(parent = c("USA", "NLD"), source_usd = c(1, 2))
  expect_silent(env$assert_core_budget_parity(rows, rows[2:1, ], "parent", "source_usd"))
  expect_error(env$assert_core_budget_parity(rows[-1, ], rows, "parent", "source_usd"), "identical")
  expect_error(env$assert_core_budget_parity(dplyr::mutate(rows, source_usd = 0), rows,
    "parent", "source_usd"), "tolerance")
})
