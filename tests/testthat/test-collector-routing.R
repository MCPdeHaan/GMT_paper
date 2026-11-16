routing_env <- function() {
  env <- new.env(parent = globalenv())
  for (script in c("07a_uncertainty.R", "09_econometric_and_reallocation_extensions.R",
    "11_policy_game_and_variance_extensions.R")) {
    source_pipeline(script, env)
  }
  env
}

routing_weights <- function() {
  list(
    parent_year_weights = tibble::tibble(
      parent = c("CAN", "CAN", "NZL"), year = 2023L,
      collector = c("DEU", "GBR", "GBR"), collector_name = collector,
      collector_is_eu27 = c(TRUE, FALSE, FALSE),
      utpr_weight = c(.25, .75, 1), utpr_weight_source = "parent_year",
      collector_utpr_explicit_flag = TRUE, collector_utpr_ambiguous_flag = FALSE),
    fallback_weights = tibble::tibble(
      year = 2023L, collector = c("FRA", "GBR"), collector_name = collector,
      collector_is_eu27 = c(TRUE, FALSE), utpr_weight = c(.5, .5),
      utpr_weight_source = "global_year_fallback",
      collector_utpr_explicit_flag = TRUE, collector_utpr_ambiguous_flag = FALSE)
  )
}

routing_sources <- function() {
  cells <- tibble::tribble(
    ~parent, ~affiliate, ~topup_after_behaviour, ~qdmtt_flag, ~parent_iir_utpr_flag, ~sbs_exempt,
    "USA", "NLD",  60, TRUE,  FALSE, TRUE,
    "FRA", "DEU",  20, FALSE, TRUE,  FALSE,
    "FRA", "FRA",  10, FALSE, TRUE,  FALSE,
    "CAN", "DEU",  80, FALSE, FALSE, FALSE,
    "CAN", "IRL",  20, FALSE, FALSE, FALSE,
    "NZL", "FRA",  40, FALSE, FALSE, FALSE,
    "AUS", "FRA",  30, FALSE, FALSE, FALSE,
    "USA", "IRL",  50, FALSE, TRUE,  TRUE,
    "KOR", "ITA",   0, FALSE, FALSE, FALSE,
    "MEX", "BEL",  NA, NA,    NA,    NA,
    "ZAF", "FRA",   4, NA,    NA,    NA
  )
  dplyr::mutate(cells, year = 2023L, scenario_id = "x10011",
    affiliate_jurisdiction_name = affiliate, parent_jurisdiction_name = parent,
    factor4_sbs = "sbs", rate_scenario = "initial", factor1_etr = "distributional",
    factor2_substance = "aggregate_sbie", factor3_rates = "initial", factor5_behaviour = "behavioural",
    x1_etr = 1L, x2_substance = 0L, x3_rates = 0L, x4_sbs = 1L, x5_behaviour = 1L,
    analysis_profit_positive = 100, stage1_lowtax_profit_distributional = 25)
}

# Off-support example with no weights for 2022.
unsupported_routing_source <- function() {
  dplyr::mutate(routing_sources()[7, ], year = 2022L)
}

make_profit_routing_input <- function(env, rows, weights) {
  directory <- tempfile("gmt-routing-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE))
  saveRDS(env$build_source_panel(rows), file.path(directory, "stage4_5_allocation_source_panel.rds"))
  saveRDS(weights$parent_year_weights, file.path(directory, "stage4_5_utpr_parent_year_weights.rds"))
  saveRDS(weights$fallback_weights, file.path(directory, "stage4_5_utpr_fallback_weights.rds"))
  if (!is.null(weights$policy)) saveRDS(weights$policy, file.path(directory, "stage4_5_utpr_policy.rds"))
  env$build_preferred_source_panel(directory)
}

profit_routing_fixture <- function(rows) {
  dplyr::mutate(rows, profit_panelai = topup_after_behaviour, profit_adj_panelai = NA_real_,
    is_domestic = parent == affiliate, rpr_panelai = 0, tot_rev_panelai = 1,
    assets_panelai = 0, employees_panelai = 0, holding_share_panelai = 0,
    affiliate_is_conduit_haven = FALSE, profit_panelai_uncorrected = profit_panelai,
    profit_panelai_corrected_low = profit_panelai, analysis_profit_base = profit_panelai,
    profit_panelai_corrected_high = profit_panelai, stage2_sbie = 0,
    stage1_distributional_low_share = 1, stage1_distributional_liability_rate = .1,
    sectoral_scale_selected = 1, behavioural_liability_filter = 1)
}

test_that("source classification separates a potential route from a realised amount", {
  env <- routing_env()
  rows <- routing_sources()
  expect_true(is.na(rows$topup_after_behaviour[10]))
  source <- env$build_source_panel(rows)
  expect_identical(source$stage4_allocation_regime,
    c("qdmtt", "iir", "iir", "utpr", "utpr", "utpr", "utpr", "sbs_extinguished", "zero", "zero", "utpr"))
  expect_identical(source$topup_after_behaviour[9:10], c(0, 0))
  expect_equal(with(source, stage4_qdmtt_liability + stage4_iir_liability +
    stage4_utpr_pool + stage4_sbs_extinguished_liability), source$topup_after_behaviour)
  expect_equal(rowSums(source[c("stage4_qdmtt_liability", "stage4_iir_liability",
    "stage4_utpr_pool", "stage4_sbs_extinguished_liability")] > 0), as.numeric(source$topup_after_behaviour > 0))
  expect_identical(env$allocation_regime(rep(50, 4), c(FALSE, FALSE, FALSE, TRUE),
    c(FALSE, TRUE, TRUE, TRUE), c(FALSE, FALSE, TRUE, TRUE)),
    c("utpr", "iir", "sbs_extinguished", "qdmtt"))
})

test_that("supported routes conserve source liability before and after geographic aggregation", {
  env <- routing_env()
  weights <- routing_weights()
  source <- env$build_source_panel(routing_sources())
  # Independent per-cell oracle. Extinction and inactive source rows collect zero.
  expected <- tibble::tribble(
    ~parent, ~affiliate, ~country, ~channel, ~revenue,
    "USA", "NLD", "NLD", "QDMTT", 60,
    "FRA", "DEU", "FRA", "IIR",   20,
    "FRA", "FRA", "FRA", "IIR",   10,
    "CAN", "DEU", "DEU", "UTPR",  20,
    "CAN", "DEU", "GBR", "UTPR",  60,
    "CAN", "IRL", "DEU", "UTPR",   5,
    "CAN", "IRL", "GBR", "UTPR",  15,
    "NZL", "FRA", "GBR", "UTPR",  40,
    "AUS", "FRA", "FRA", "UTPR",  15,
    "AUS", "FRA", "GBR", "UTPR",  15,
    "ZAF", "FRA", "FRA", "UTPR",   2,
    "ZAF", "FRA", "GBR", "UTPR",   2
  ) |>
    dplyr::mutate(scenario_id = "x10011", year = 2023L)
  keys <- c("scenario_id", "parent", "affiliate", "country", "year", "channel")
  detail <- lapply(seq_len(nrow(source)), function(i) {
    cell <- source[i, ]
    env$allocate_stage4_revenue(cell, weights)$revenue_by_channel_global |>
      dplyr::mutate(parent = cell$parent, affiliate = cell$affiliate) |>
      dplyr::select(dplyr::all_of(keys), revenue)
  }) |>
    dplyr::bind_rows()
  sort_routes <- function(x) dplyr::arrange(x, dplyr::across(dplyr::all_of(keys)))
  expect_equal(sort_routes(detail), sort_routes(dplyr::select(expected, dplyr::all_of(keys), revenue)))

  full <- env$allocate_stage4_revenue(source, weights)
  diagnostic <- env$build_conservation_diagnostics(source, full$revenue_by_channel_global)
  expect_equal(diagnostic$pre_allocation_topup, 314)
  expect_equal(diagnostic$sbs_extinguished_topup, 50)
  expect_equal(diagnostic$allocated_topup, 264)
  expect_equal(diagnostic$residual_gap, 0)
  expect_equal(sum(full$revenue_by_channel_eu27$revenue), 132)
  expect_equal(sum(full$revenue_by_channel_global$revenue[!full$revenue_by_channel_global$country_is_eu27]), 132)
  expect_equal(sum(full$utpr_pool$utpr_pool), 174)
  expect_equal(sum(full$revenue_by_channel_global$revenue[full$revenue_by_channel_global$channel == "UTPR"]), 174)
  expect_equal(sum(full$revenue_country_year_eu27$revenue), 132)
  expect_equal(env$nash_channels(source, weights)$max_gap, 0)
  expect_error(env$build_conservation_diagnostics(source,
    dplyr::filter(full$revenue_by_channel_global, country != "GBR")), "global allocation does not conserve")

  own <- env$build_source_routing(source, weights) |> dplyr::arrange(country)
  expect_equal(own$source_domestic_utpr[own$country %in% c("DEU", "FRA", "IRL")], c(20, 17, 0))
  expect_equal(own$source_exported_utpr[own$country %in% c("DEU", "FRA", "IRL")], c(60, 57, 20))
  expect_equal(sum(own$source_domestic_iir), 10)
  expect_equal(sum(own$source_exported_iir), 20)
  expect_equal(sum(own$source_sbs_extinguished), 50)
  expect_equal(sum(own$source_topup_liability), sum(own$source_retained_qdmtt +
    own$source_domestic_iir + own$source_exported_iir + own$source_domestic_utpr +
    own$source_exported_utpr + own$source_sbs_extinguished))

  preferred <- make_profit_routing_input(env, profit_routing_fixture(routing_sources()), weights)
  # NZL's observed non-EU-only share outranks the positive fallback share.
  expect_equal(preferred$eu27_utpr_share[preferred$parent == "NZL"], 0)
  expect_equal(preferred$eu27_utpr_share[preferred$parent == "AUS"], .5)
  result <- env$compute_preferred_revenue_from_profit(preferred, 10 * preferred$analysis_profit_base, "toy")
  expect_equal(result$global_allocated_revenue, 264)
  expect_equal(result$eu27_final_revenue, 132)
  expect_equal(result$eu27_qdmtt_revenue, 60)
  expect_equal(result$eu27_iir_revenue, 30)
  expect_equal(result$eu27_utpr_revenue, 42)
  expect_equal(result$sbs_extinguished_revenue, 50)
  universal <- dplyr::mutate(routing_sources(), sbs_exempt = FALSE,
    scenario_id = "x10001", factor4_sbs = "universal", x4_sbs = 0L)
  preferred <- make_profit_routing_input(env, profit_routing_fixture(universal), weights)
  result <- env$compute_preferred_revenue_from_profit(preferred, 10 * preferred$analysis_profit_base, "toy")
  expect_equal(result$global_allocated_revenue, 314)
  expect_equal(result$eu27_final_revenue, 132)
  expect_equal(result$sbs_extinguished_revenue, 0)
})

test_that("sparse projection matches detailed allocation for multiple vectors and scenarios", {
  env <- routing_env()
  weights <- routing_weights()
  rows <- routing_sources()
  rows <- dplyr::bind_rows(rows, dplyr::mutate(rows[4, ], year = 2022L, topup_after_behaviour = 16))
  weights$fallback_weights <- dplyr::bind_rows(weights$fallback_weights,
    dplyr::mutate(weights$fallback_weights, year = 2022L, utpr_weight = c(.75, .25)))
  collectors <- tidyr::expand_grid(country = env$EU27_ISO3, year = env$MAIN_YEARS)
  sb <- env$build_source_panel(rows)
  un <- env$build_source_panel(dplyr::mutate(rows, sbs_exempt = FALSE,
    scenario_id = "x10001", factor4_sbs = "universal", x4_sbs = 0L))
  # Both route operators ignore the input liability and are evaluated on two
  # vectors, one with large, non-exact binary amounts.
  amounts <- list(sb$topup_after_behaviour, seq_len(nrow(sb)) * 1e10 / 3)
  compare <- function(source, route, assigned) {
    expanded <- env$allocate_stage4_revenue(source, weights)
    eu <- collectors |>
      dplyr::left_join(dplyr::select(expanded$revenue_country_year_eu27, country, year, revenue),
        by = c("country", "year"), relationship = "one-to-one")
    sparse <- as.numeric(route$operator %*% assigned)
    detailed <- dplyr::coalesce(eu$revenue, 0)
    limit <- 1e-10 + 32 * .Machine$double.eps * sum(assigned)
    expect_lte(max(abs(sparse - detailed)), limit)
    expect_lte(max(abs(sparse - detailed) / pmax(abs(detailed), 1)), 32 * .Machine$double.eps)
    assigned_foreign <- sum(assigned * route$foreign_collection_weight)
    detailed_foreign <- sum(expanded$revenue_by_channel_global$revenue[!expanded$revenue_by_channel_global$country_is_eu27])
    expect_lte(abs(assigned_foreign - detailed_foreign), limit)
    expect_lte(abs(sum(sparse) + assigned_foreign +
      sum(assigned[route$extinguished]) - sum(assigned)), limit)
  }
  for (template in list(sb, un)) {
    route <- env$step15_route(template, weights)
    expect_equal(as.numeric(Matrix::colSums(route$operator)),
      c(1, 1, 1, .25, .25, 0, .5, 0, .5, .5, .5, .75))
    for (amount in amounts) {
      source <- env$build_source_panel(dplyr::mutate(template, topup_after_behaviour = amount))
      compare(source, route, amount)
      order <- rev(seq_len(nrow(source)))
      shuffled <- source[order, ]
      expect_equal(as.numeric(route$operator %*% amount),
        as.numeric(env$step15_route(shuffled, weights)$operator %*% amount[order]), tolerance = 1e-12)
      compare(shuffled, env$step15_route(shuffled, weights), amount[order])
    }
  }

  # Across scenarios the same cell can extinguish under SbS and pay foreign IIR
  # under universal coverage. Stage 06 retains each scenario's own totals.
  combined <- env$allocate_stage4_revenue(dplyr::bind_rows(sb, un), weights)
  total <- combined$revenue_by_channel_global |>
    dplyr::summarise(revenue = sum(revenue), .by = scenario_id) |>
    dplyr::arrange(scenario_id)
  expect_identical(total$scenario_id, c("x10001", "x10011"))
  expect_equal(total$revenue, c(330, 280))
})

test_that("unsupported positive UTPR remains visible and cannot be reported as receipts", {
  env <- routing_env()
  weights <- routing_weights()
  rows <- unsupported_routing_source()
  source <- env$build_source_panel(rows)
  expect_equal(source$stage4_utpr_pool, 30)
  expanded <- env$expand_utpr_routes(dplyr::select(source, parent, year, stage4_utpr_pool), weights)
  expect_equal(nrow(expanded), 1L)
  expect_true(is.na(expanded$collector) && is.na(expanded$utpr_weight))
  expect_equal(0 + 0 + expanded$stage4_utpr_pool, source$topup_after_behaviour)
  expect_error(env$allocate_stage4_revenue(source, weights), "no supported collector route")
  expect_error(env$nash_channels(source, weights, check = FALSE), "no supported collector route")
  expect_error(env$step15_route(source, weights), "no supported collector route")
  expect_error(env$build_source_routing(source, weights), "no supported collector route")

  mixed <- env$build_source_panel(dplyr::bind_rows(routing_sources()[4, ], rows))
  mixed_routes <- env$expand_utpr_routes(dplyr::select(mixed, parent, year, stage4_utpr_pool), weights)
  assigned <- sum(mixed_routes$stage4_utpr_pool * mixed_routes$utpr_weight, na.rm = TRUE)
  unsupported <- sum(mixed_routes$stage4_utpr_pool[is.na(mixed_routes$collector)])
  expect_equal(c(assigned, unsupported), c(80, 30))
  expect_equal(assigned + unsupported, sum(mixed$topup_after_behaviour))
  expect_error(env$allocate_stage4_revenue(mixed, weights), "no supported collector route")

  preferred <- make_profit_routing_input(env, profit_routing_fixture(rows), weights)
  expect_true(is.na(preferred$eu27_utpr_share))
  expect_error(env$compute_preferred_revenue_from_profit(preferred, 300, "toy"), "no supported collector route")
  expect_equal(env$compute_preferred_revenue_from_profit(preferred, 0, "toy")$global_allocated_revenue, 0)

  zero <- env$build_source_panel(dplyr::mutate(rows, topup_after_behaviour = 0))
  expect_equal(nrow(env$allocate_stage4_revenue(zero, weights)$revenue_by_channel_global), 0L)
  expect_equal(env$build_source_routing(zero, weights)$source_exported_utpr, 0)
  expect_error(env$step15_route(zero, weights), "potential UTPR source")
  tiny <- env$build_source_panel(dplyr::mutate(rows, topup_after_behaviour = 1e-4))
  expect_error(env$allocate_stage4_revenue(tiny, weights), "no supported collector route")
  qdmtt <- env$build_source_panel(dplyr::mutate(rows, qdmtt_flag = TRUE))
  expect_equal(env$nash_channels(qdmtt, weights)$channels$revenue, 30)
})

test_that("parent-only residuals reconcile at source and in all collector projections", {
  env <- routing_env()
  weights <- routing_weights()
  weights$fallback_weights <- weights$fallback_weights[0, ]
  weights$policy <- list(specification = "VERIFIED_PARENT_ONLY", eligible = c("DEU", "GBR"))
  rows <- routing_sources()
  source <- env$build_source_panel(rows)
  detail <- env$allocate_stage4_revenue(source, weights)
  expect_error(env$allocate_stage4_revenue(source, weights, unsupported = "strict"),
    "no supported collector route")
  expect_identical(detail$unsupported_utpr$parent, c("AUS", "ZAF"))
  expect_equal(detail$unsupported_utpr$unsupported_utpr, c(30, 4))
  totals <- env$build_conservation_diagnostics(source, detail$revenue_by_channel_global, detail$unsupported_utpr)
  expect_equal(unlist(totals[c("pre_allocation_topup", "allocated_topup", "sbs_extinguished_topup",
    "unsupported_utpr", "residual_gap")], use.names = FALSE), c(314, 230, 50, 34, 0))
  expect_equal(sum(detail$revenue_by_channel_eu27$revenue), 115)
  expect_equal(sum(detail$revenue_by_channel_global$revenue[!detail$revenue_by_channel_global$country_is_eu27]), 115)

  preferred <- make_profit_routing_input(env, profit_routing_fixture(rows), weights)
  expect_equal(preferred$eu27_utpr_share[preferred$parent == "NZL"], 0)
  expect_true(all(is.na(preferred$eu27_utpr_share[preferred$parent %in% c("AUS", "ZAF")])))
  collapsed <- env$compute_preferred_revenue_from_profit(preferred, 10 * preferred$analysis_profit_base, "toy")
  expect_equal(collapsed$global_allocated_revenue, 230)
  expect_equal(collapsed$eu27_final_revenue, 115)
  expect_equal(collapsed$eu27_utpr_revenue, 25)
  expect_equal(collapsed$unsupported_utpr, 34)

  sparse <- env$step15_route(source, weights)
  # The operator represents a potential route on every cell, including cells
  # with zero liability today that can carry positive liability in a draw.
  expect_identical(sparse$unsupported_weight, as.numeric(rows$parent %in% c("AUS", "ZAF", "KOR", "MEX")))
  expect_equal(as.numeric(Matrix::colSums(sparse$operator)) + sparse$foreign_collection_weight +
    sparse$extinguished + sparse$unsupported_weight, rep(1, nrow(source)))
  amounts <- source$topup_after_behaviour
  for (scale in c(1, 1e7 / 3)) {
    order <- rev(seq_len(nrow(source)))
    shuffled <- env$step15_route(source[order, ], weights)
    expect_equal(as.numeric(shuffled$operator %*% (amounts[order] * scale)),
      as.numeric(sparse$operator %*% (amounts * scale)), tolerance = 32 * .Machine$double.eps)
    expect_equal(sum(sparse$operator %*% (amounts * scale)), 115 * scale,
      tolerance = 32 * .Machine$double.eps)
    expect_equal(sum(sparse$unsupported_weight * amounts * scale), 34 * scale,
      tolerance = 32 * .Machine$double.eps)
  }
  ledger <- env$build_source_routing(source, weights)
  expect_equal(sum(ledger$source_unsupported_utpr), 34)
  expect_equal(sum(ledger$source_exported_utpr), 120)
  expect_equal(sum(ledger$source_domestic_utpr), 20)
  expect_equal(with(ledger, source_retained_qdmtt + source_domestic_iir + source_exported_iir +
    source_domestic_utpr + source_exported_utpr + source_sbs_extinguished + source_unsupported_utpr),
    ledger$source_topup_liability)
  expect_equal(sum(env$nash_channels(source, weights)$unsupported_utpr$unsupported_utpr), 34)

  simulation <- env$build_simulation_conservation_diagnostics(source, detail$revenue_by_channel_global,
    unsupported_utpr = detail$unsupported_utpr)
  expect_equal(simulation$unsupported_utpr, 34)
  expect_equal(simulation$residual_gap, 0)
  expect_error(env$build_simulation_conservation_diagnostics(source, detail$revenue_by_channel_global),
    "simulation allocation residual")

  malformed <- weights
  malformed$policy$eligible <- "DEU"
  expect_error(env$allocate_stage4_revenue(source, malformed), "ineligible")
})

test_that("production unsupported sources match the complete original source key", {
  env <- routing_env()
  directory <- dirname(processed_path("stage4_5_allocation_source_panel.rds"))
  weights <- env$read_stage4_utpr_weights(directory)
  if (!is.null(weights$policy) && weights$policy$specification == "VERIFIED_PARENT_ONLY") {
    source <- readRDS(processed_path("stage4_5_allocation_source_panel.rds"))
    residual <- readRDS(processed_path("stage4_5_utpr_unsupported_sources.rds"))
    key <- c("scenario_id", "parent", "affiliate", "year")
    expect_false(anyDuplicated(residual[key]) > 0)
    expect_true(all(residual$unsupported_utpr > 0))
    expect_true(all(residual$year %in% 2017:2023))
    expect_true(all(source$year %in% 2017:2023))
    expected <- dplyr::filter(source, stage4_utpr_pool > 0) |>
      dplyr::anti_join(dplyr::distinct(weights$parent_year_weights, parent, year), by = c("parent", "year")) |>
      dplyr::select(dplyr::all_of(key), unsupported_utpr = stage4_utpr_pool)
    expect_identical(dplyr::select(residual, dplyr::all_of(key), unsupported_utpr), expected)
  } else {
    if (is.null(weights$policy)) {
      expect_false(file.exists(processed_path("stage4_5_utpr_unsupported_sources.rds")))
    } else {
      expect_true(file.exists(processed_path("stage4_5_utpr_unsupported_sources.rds")))
    }
  }
})

test_that("activity combines eligible collectors within each weighting tier", {
  env <- routing_env()
  activity <- tibble::tribble(
    ~parent, ~affiliate, ~employees_sbie, ~assets_sbie, ~eligible,
    "CAN", "DEU", 20, 80, TRUE,
    "CAN", "GBR", 60, 20, TRUE,
    "NZL", "GBR", 40, NA, TRUE,
    "KOR", "FRA", NA, 80, TRUE,
    "CAN", "JPN", NA, NA, TRUE,
    "CAN", "USA", 100, 100, FALSE
  ) |>
    dplyr::mutate(year = 2023L, affiliate_jurisdiction_name = affiliate,
      affiliate_policy_iir_utpr_by_2026 = eligible, affiliate_policy_utpr_by_2026 = eligible,
      affiliate_policy_iir_utpr_explicit_by_2026 = eligible, affiliate_oecd_iir_by_2026 = eligible,
      affiliate_policy_iir_utpr_ambiguous_by_2026 = FALSE)
  repeated <- dplyr::bind_rows(activity, activity[1, ])
  collectors <- env$build_collector_activity(repeated)
  expect_equal(nrow(collectors), 6)
  expect_equal(collectors$asset_base[collectors$parent == "NZL"], 0)
  expect_equal(collectors$employee_base[collectors$parent == "KOR"], 0)
  weights <- env$build_parent_year_utpr_weights(collectors)
  parent <- dplyr::arrange(weights$parent_year_weights, parent, collector)
  expect_identical(parent$collector, c("DEU", "GBR", "FRA", "GBR"))
  expect_equal(parent$utpr_weight, c(.525, .475, 1, 1))
  fallback <- dplyr::arrange(weights$fallback_weights, collector)
  expect_identical(fallback$collector, c("DEU", "FRA", "GBR"))
  expect_equal(fallback$utpr_weight, c(11/36, 2/9, 17/36))
  conflicting <- dplyr::bind_rows(activity, dplyr::mutate(activity[1, ], employees_sbie = 21))
  expect_error(env$build_parent_year_utpr_weights(env$build_collector_activity(conflicting)),
    "duplicate collector keys")
})

test_that("malformed route keys, weights and geography are rejected", {
  env <- routing_env()
  source <- env$build_source_panel(routing_sources())
  weights <- routing_weights()
  duplicate <- weights
  row <- duplicate$parent_year_weights[1, ]
  duplicate$parent_year_weights$utpr_weight[1] <- .125
  row$utpr_weight <- .125
  duplicate$parent_year_weights <- dplyr::bind_rows(duplicate$parent_year_weights, row)
  expect_error(env$allocate_stage4_revenue(source, duplicate), "duplicate collector keys")
  expect_error(env$step15_route(source, duplicate), "duplicate collector keys")
  expect_error(env$build_source_routing(source, duplicate), "duplicate collector keys")
  expect_error(make_profit_routing_input(env, profit_routing_fixture(routing_sources()), duplicate),
    "duplicate collector keys")

  bad <- weights
  bad$fallback_weights$collector[1] <- bad$fallback_weights$collector[2]
  expect_error(env$validate_utpr_weights(bad, env$EU27_ISO3), "Fallback UTPR weights have duplicate")
  bad <- weights
  bad$fallback_weights$utpr_weight[1] <- .25
  expect_error(env$validate_utpr_weights(bad, env$EU27_ISO3), "do not sum to one")
  for (invalid in c(-.01, NA_real_, Inf, NaN)) {
    bad <- weights
    bad$parent_year_weights$utpr_weight[1] <- invalid
    expect_error(env$validate_utpr_weights(bad, env$EU27_ISO3), "finite and non-negative")
  }
  bad <- weights
  bad$parent_year_weights$collector_is_eu27[1] <- FALSE
  expect_error(env$validate_utpr_weights(bad, env$EU27_ISO3), "inconsistent EU27 geography")
  bad <- weights
  bad$fallback_weights$collector[1] <- NA_character_
  expect_error(env$validate_utpr_weights(bad, env$EU27_ISO3), "complete routing keys")
})
