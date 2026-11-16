# Compare collector maps on common source liabilities. Run the fully coupled
# R05b and historical pipelines separately for exhibit and model comparisons.
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code",
  "allocation", "utpr_eligibility_shadow.R"), local = TRUE)

utpr_decompose <- function(values, key) {
  wide <- tidyr::pivot_wider(values, id_cols = all_of(key), names_from = specification,
    values_from = value)
  stopifnot(!anyNA(wide[UTPR_SPECIFICATIONS]))
  out <- wide |>
    mutate(
      eligibility_with_fallback = VERIFIED_FALLBACK - LEGACY_FALLBACK,
      eligibility_parent_only = VERIFIED_PARENT_ONLY - LEGACY_PARENT_ONLY,
      fallback_removed_under_legacy = LEGACY_PARENT_ONLY - LEGACY_FALLBACK,
      fallback_removed_under_verified = VERIFIED_PARENT_ONLY - VERIFIED_FALLBACK,
      interaction = fallback_removed_under_verified - fallback_removed_under_legacy,
      combined = VERIFIED_PARENT_ONLY - LEGACY_FALLBACK,
      unresolved_sensitivity = VERIFIED_PLUS_UNRESOLVED_PARENT_ONLY - VERIFIED_PARENT_ONLY)
  stopifnot(all(abs(with(out, combined - eligibility_with_fallback - fallback_removed_under_legacy -
    interaction)) < 1e-3))
  out
}

# These diagnostics compare complete replays. The common-source factorial below
# holds liability fixed; the accounting, MC and game outputs run their own models.
compare_utpr_replays <- function(current, historical, output) {
  diagnostic <- function(root, name) {
    readr::read_csv(file.path(root, "diagnostics", paste0(name, ".csv")),
      show_col_types = FALSE, guess_max = Inf)
  }
  compare <- function(name, keys, metrics, descriptors = character(), new_residuals = character(),
                      select_rows = identity) {
    previous <- select_rows(diagnostic(historical, name)) |> select(all_of(c(keys, metrics, descriptors)))
    revised <- select_rows(diagnostic(current, name)) |>
      select(all_of(c(keys, metrics, descriptors, new_residuals)))
    stopifnot(nrow(anti_join(previous, revised, by = keys)) == 0L, nrow(anti_join(revised, previous, by = keys)) == 0L)
    paired <- left_join(revised, previous, by = keys, suffix = c("_r05b", "_r04b"), relationship = "one-to-one")
    for (metric in metrics) {
      new_value <- paired[[paste0(metric, "_r05b")]]
      old_value <- paired[[paste0(metric, "_r04b")]]
      paired[[paste0(metric, "_change")]] <- if_else(new_value == old_value, 0, new_value - old_value)
    }
    paired
  }
  budget <- compare("step9_budget_benchmark_scenario_ranges_r04b",
    c("window", "scenario_scope", "country", "benchmark", "forecast_period", "revenue_scope", "model_scope"),
    c("scenario_min_eur_bn", "scenario_max_eur_bn", "closest_gap_eur_bn",
      "preferred_universal_eur_bn", "preferred_sbs_eur_bn"),
    c("official_low_eur_bn", "official_high_eur_bn", "scenario_count",
      "official_interval_overlaps_model_range", "closest_scenario"))
  game <- compare("step13_unilateral_qdmtt_deviation_matrix",
    c("country", "level", "deviation", "regime", "window", "scenario_id"),
    c("adoption_qdmtt", "domestic_iir_recapture", "domestic_utpr_recapture", "foreign_iir_soakup",
      "foreign_utpr_soakup", "mne_topup_saved", "sbs_extinguished_post_repeal",
      "delta_domestic_collector_from_other_sources", "retained_source_cit", "net_domestic_tax_foregone",
      "tax_cut_efficiency", "critical_welfare_weight"),
    c("adoption_utpr_active", "deviation_utpr_active", "fiscal_gain_at_zero_weight"),
    c("host_unsupported_utpr", "adoption_global_unsupported_utpr", "deviation_global_unsupported_utpr",
      "global_assigned_decline"))
  variance <- compare("step15_law_of_total_variance_decomposition", c("scope", "window", "record"),
    c("scenario_variance_share", "parameter_variance_share", "preferred_width90_usd_bn", "proposal_ratio"),
    select_rows = function(rows) filter(rows, record == "total_variance"))
  accounting <- compare("step15_globe_accounting_factorial_anova",
    c("scope", "window", "design", "distributional_level", "estimand", "effect"),
    c("main_eta_squared", "shapley_eta_squared", "dollar_main_effect_usd_bn"),
    select_rows = function(rows) filter(rows, record == "main_effect"))
  purrr::iwalk(list(budget_comparison = budget, repeal_comparison = game,
    joint_variance_comparison = variance, accounting_comparison = accounting),
    ~ readr::write_csv(.x, file.path(output, paste0(.y, ".csv"))))
}

compare_utpr_specifications <- function(processed, output, historical) {
  if (!dir.exists(output)) dir.create(output, recursive = TRUE)
  stopifnot(length(list.files(output, all.files = TRUE, no.. = TRUE)) == 0L)
  windows <- c(UTPR_SHADOW_WINDOWS, list("2019–2023" = 2019:2023))
  core <- readRDS(file.path(processed, "stage4_5_allocation_source_panel.rds"))
  r3 <- nash_r3_panel(filter(core, scenario_id %in% NASH_IDS))
  sources <- list(R1_central_record_2026_05_01 = core, R3_full_eu27_qdmtt_iir = r3)
  activity <- build_collector_activity(core)
  legal <- read_utpr_evidence(file.path(GMT_PROJECT_ROOT, "data", "legal", "utpr_eligibility_2026.csv"))
  weights <- set_names(map(UTPR_SPECIFICATIONS, function(name) {
    build_parent_year_utpr_weights(activity, utpr_collector_policy(name, activity, legal))
  }), UTPR_SPECIFICATIONS)
  routed <- purrr::imap(sources, function(source, arm) {
    fixed <- shadow_project(source, weights[["LEGACY_FALLBACK"]])$fixed
    purrr::imap(weights, function(weight, specification) {
      result <- shadow_project(source, weight, fixed = fixed)
      list(
        summary = mutate(shadow_totals(result, windows), policy_arm = arm, specification, .before = 1),
        channels = mutate(result$channels, policy_arm = arm, specification, .before = 1)
      )
    })
  })
  r1 <- routed[[1L]]
  comparator_key <- c("scenario_id", "country", "year", "channel")
  archived <- readRDS(file.path(historical, "stage4_5_revenue_by_channel_global.rds"))
  current <- readRDS(file.path(processed, "stage4_5_revenue_by_channel_global.rds"))
  reconciliation <- tibble(
    check = c("R04b global legacy country-year-channel", "R05b production country-year-channel"),
    max_gap_usd = c(compare_shadow_channels(r1$LEGACY_FALLBACK$channels, archived, comparator_key),
      compare_shadow_channels(r1$VERIFIED_PARENT_ONLY$channels, current, comparator_key))
  )
  results <- unlist(routed, recursive = FALSE)
  summaries <- map_dfr(results, "summary")
  channels <- map_dfr(results, "channels")
  archived_shadow <- readr::read_csv(file.path(GMT_PROJECT_ROOT, "data", "legal", "r05a_shadow",
    "shadow_summary.csv"), show_col_types = FALSE)
  shadow_keys <- c("policy_arm", "scenario_id", "window", "eligibility_arm")
  measures <- c("pool_usd", "eu27_assigned_usd", "assigned_usd", "fallback_pool_usd")
  archived_values <- archived_shadow |>
    filter(eligibility_arm != "VERIFIED_PLUS_UNRESOLVED") |>
    select(all_of(shadow_keys), all_of(measures))
  reprojected <- summaries |>
    filter(scenario_id %in% NASH_IDS, window %in% names(UTPR_SHADOW_WINDOWS),
      specification %in% c("LEGACY_FALLBACK", "VERIFIED_FALLBACK")) |>
    mutate(eligibility_arm = sub("_FALLBACK$", "", specification)) |>
    select(all_of(shadow_keys), all_of(measures))
  matched <- full_join(reprojected, archived_values, by = shadow_keys,
    suffix = c("", "_archive"), relationship = "one-to-one")
  gap <- max(abs(as.matrix(matched[measures]) - as.matrix(matched[paste0(measures, "_archive")])))
  stopifnot(nrow(matched) == 16L, is.finite(gap), gap < 1e-3)
  reconciliation <- bind_rows(reconciliation, tibble(check = "R05a preferred R1 and R3 fallback cases", max_gap_usd = gap))

  summary_keys <- c("policy_arm", "window", "scenario_id", "outcome")
  summary_metrics <- c("source_usd", "assigned_usd", "extinguished_usd", "qdmtt_usd",
    "iir_usd", "pool_usd", "utpr_usd", "eu27_utpr_usd", "non_eu27_utpr_usd",
    "eu27_assigned_usd", "non_eu27_assigned_usd", "parent_year_pool_usd", "fallback_pool_usd",
    "unsupported_pool_usd", "parent_year_pct_of_pool", "fallback_pct_of_pool", "unsupported_pct_of_pool")
  effects <- summaries |>
    select(policy_arm, window, scenario_id, specification, all_of(summary_metrics)) |>
    tidyr::pivot_longer(all_of(summary_metrics), names_to = "outcome", values_to = "value") |>
    utpr_decompose(summary_keys)

  country_keys <- c("policy_arm", "window", "scenario_id", "country", "channel")
  country <- shadow_windows(channels, windows) |>
    filter(scenario_id %in% NASH_IDS) |>
    summarise(value = sum(revenue), .by = all_of(c(country_keys, "specification"))) |>
    tidyr::complete(tidyr::nesting(!!!syms(country_keys)),
      specification = UTPR_SPECIFICATIONS, fill = list(value = 0)) |>
    utpr_decompose(country_keys)
  rank_changes <- country |>
    filter(country %in% EU27_ISO3) |>
    summarise(across(all_of(UTPR_SPECIFICATIONS), sum), .by = c(policy_arm, window, scenario_id, country)) |>
    tidyr::complete(tidyr::nesting(policy_arm, window, scenario_id), country = EU27_ISO3,
      fill = as.list(set_names(rep(0, length(UTPR_SPECIFICATIONS)), UTPR_SPECIFICATIONS))) |>
    mutate(legacy_rank = min_rank(desc(LEGACY_FALLBACK)), verified_rank = min_rank(desc(VERIFIED_PARENT_ONLY)),
      rank_gain = legacy_rank - verified_rank, .by = c(policy_arm, window, scenario_id))
  ranges <- summaries |>
    filter(policy_arm == names(sources)[1L]) |>
    summarise(min_eu27_usd = min(eu27_assigned_usd), max_eu27_usd = max(eu27_assigned_usd),
      scenarios = n_distinct(scenario_id), .by = c(window, specification))
  files <- list(summary = summaries, effects = effects, country_channel_effects = country,
    eu27_country_ranks = rank_changes, eu27_core_ranges = ranges, reconciliation = reconciliation)
  purrr::iwalk(files, ~ readr::write_csv(.x, file.path(output, paste0(.y, ".csv"))))
  invisible(files)
}

if (is_direct_script_run("code/allocation/utpr_policy_comparison.R")) {
  args <- commandArgs(trailingOnly = TRUE)
  if (!length(args) %in% c(3L, 4L) || (length(args) == 4L && args[[4L]] != "--full")) {
    stop("Supply R05b processed, historical processed and fresh output directories, with optional --full",
      call. = FALSE)
  }
  compare_utpr_specifications(args[[1L]], args[[3L]], args[[2L]])
  if (length(args) == 4L) compare_utpr_replays(args[[1L]], args[[2L]], args[[3L]])
}
