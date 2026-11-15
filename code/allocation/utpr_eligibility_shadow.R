# Standalone legal eligibility sensitivity. Production stages do not source this file.
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code",
  "11_policy_game_and_variance_extensions.R"), local = TRUE)

UTPR_EVALUATION_DATE <- as.Date("2026-01-01")
UTPR_EVIDENCE_CUTOFF <- as.Date("2026-11-15")
UTPR_LEGAL_STATUSES <- c("verified_applicable", "verified_not_applicable", "deferred",
  "not_established", "legally_ambiguous")
UTPR_SHADOW_ARMS <- c("LEGACY", "VERIFIED", "VERIFIED_PLUS_UNRESOLVED")
UTPR_SHADOW_WINDOWS <- list("FY2023" = 2023L, "2017–2023" = MAIN_YEARS)

read_utpr_evidence <- function(path) {
  date_cols <- c("enactment_date", "commencement_date", "first_applicable_fy_start",
    "source_publication_date", "source_retrieval_date", "evaluation_date", "evidence_cutoff")
  evidence <- readr::read_csv(path, show_col_types = FALSE,
    col_types = do.call(readr::cols, c(list(.default = readr::col_character()),
      setNames(rep(list(readr::col_date()), length(date_cols)), date_cols))))
  readr::stop_for_problems(evidence)
  validate_utpr_evidence(evidence)
  evidence
}

validate_utpr_evidence <- function(evidence) {
  keys <- c("iso3", "rule", "evaluation_date")
  stopifnot(!anyNA(evidence[keys]), !anyDuplicated(evidence[keys]),
    all(grepl("^[A-Z]{3}$", evidence$iso3)), all(evidence$rule == "UTPR"),
    all(evidence$evaluation_date == UTPR_EVALUATION_DATE),
    all(evidence$evidence_cutoff == UTPR_EVIDENCE_CUTOFF),
    all(evidence$status %in% UTPR_LEGAL_STATUSES),
    all(evidence$enactment_status %in% c("enacted", "not_enacted", "deferred", "not_established")),
    all(evidence$collector_scope %in% c("candidate", "parent_context")),
    all(evidence$evidence_category %in% c("national_law", "official_guidance",
      "eu_notice", "official_search", "bill")),
    all(evidence$verification_status %in% c("verified", "unresolved")),
    all(evidence$oecd_utpr_qualification %in% c("verified_qualified", "verified_not_qualified", "not_established")),
    all(evidence$article50_status %in% c("elected", "not_elected", "outside_eu")),
    all(evidence$article50_source_rule %in% c("other_member_states", "not_applicable")),
    all((evidence$article50_status == "elected") == (evidence$status == "deferred")),
    all((evidence$article50_status == "elected") == (evidence$article50_source_rule == "other_member_states")),
    all((evidence$iso3 %in% EU27_ISO3) == (evidence$article50_status != "outside_eu")),
    all(evidence$source_retrieval_date <= evidence$evidence_cutoff),
    all(evidence$source_publication_date <= evidence$source_retrieval_date, na.rm = TRUE),
    all(evidence$enactment_date <= evidence$evidence_cutoff, na.rm = TRUE),
    all(evidence$commencement_date >= evidence$enactment_date, na.rm = TRUE),
    all(grepl("^https://", evidence$source_url)),
    all((evidence$status %in% c("not_established", "legally_ambiguous")) ==
      (evidence$verification_status == "unresolved")))
  positive <- filter(evidence, status == "verified_applicable")
  stopifnot(all(positive$enactment_status == "enacted"),
    all(positive$first_applicable_fy_start <= positive$evaluation_date))
  later <- filter(evidence, status == "verified_not_applicable", !is.na(first_applicable_fy_start))
  stopifnot(all(later$first_applicable_fy_start > later$evaluation_date))
  invisible(evidence)
}

compare_utpr_eligibility <- function(evidence, activity, policy, frozen_weights) {
  validate_utpr_evidence(evidence)
  legacy <- activity |>
    summarise(legacy_eligible = any(collector_utpr_flag),
      legacy_explicit = any(collector_utpr_explicit_flag),
      legacy_ambiguous = any(collector_utpr_ambiguous_flag),
      positive_activity = any(employee_base > 0 | asset_base > 0), .by = collector) |>
    rename(iso3 = collector)
  supported <- unique(c(frozen_weights$parent_year_weights$collector, frozen_weights$fallback_weights$collector))
  stopifnot(all(c(EU27_ISO3, supported, legacy$iso3[legacy$legacy_eligible]) %in%
    evidence$iso3[evidence$collector_scope == "candidate"]))
  evidence |>
    left_join(legacy, by = "iso3", relationship = "one-to-one") |>
    left_join(select(policy, iso3 = jurisdiction, legacy_iir_start = iir_start,
      legacy_utpr_start = utpr_start, legacy_iir_by_2026 = iir_by_2026,
      independent_utpr_rule_rows = utpr_explicit_rule_rows, legacy_qdmtt_by_2026 = qdmtt_by_2026),
      by = "iso3", relationship = "one-to-one") |>
    mutate(across(c(legacy_eligible, legacy_explicit, legacy_ambiguous, positive_activity), ~ coalesce(.x, FALSE)),
      positive_frozen_weight = iso3 %in% supported,
      verified = status == "verified_applicable",
      unresolved = status %in% c("not_established", "legally_ambiguous"),
      provisional = collector_scope == "candidate" & unresolved,
      proxy_discrepancy = case_when(
        legacy_eligible & status %in% c("deferred", "verified_not_applicable") ~ "false_positive",
        legacy_eligible & unresolved ~ "unsupported_inclusion",
        !legacy_eligible & verified ~ "omitted_applicable",
        TRUE ~ "none_established"
      ),
      explicit_label_basis = if_else(legacy_explicit, "iir_proxy_only", NA_character_)) |>
    arrange(iso3)
}

shadow_activity <- function(activity, comparison, arm, exclude = character()) {
  stopifnot(arm %in% UTPR_SHADOW_ARMS)
  if (arm == "LEGACY") return(filter(activity, !collector %in% exclude))
  flags <- comparison |>
    transmute(collector = iso3, verified = status == "verified_applicable" & collector_scope == "candidate",
      provisional = arm == "VERIFIED_PLUS_UNRESOLVED" &
        status %in% c("not_established", "legally_ambiguous") & collector_scope == "candidate")
  activity |>
    filter(!collector %in% exclude) |>
    left_join(flags, by = "collector", relationship = "many-to-one") |>
    mutate(
      collector_utpr_explicit_flag = coalesce(verified, FALSE),
      collector_utpr_ambiguous_flag = coalesce(provisional, FALSE),
      collector_utpr_flag = collector_utpr_explicit_flag | collector_utpr_ambiguous_flag
    ) |>
    select(-verified, -provisional)
}

# Keep missing recipients in the pool ledger. Only the production allocator
# assigns QDMTT and IIR. Its fail-fast UTPR contract remains intact.
shadow_project <- function(source, weights, fixed = NULL) {
  validate_utpr_weights(weights, EU27_ISO3)
  if (is.null(fixed)) {
    no_utpr <- mutate(source, stage4_utpr_pool = 0)
    fixed <- allocate_stage4_revenue(no_utpr, weights)$revenue_by_channel_global |>
      select(scenario_id, country, country_is_eu27, year, channel, revenue)
  }
  pools <- source |>
    filter(stage4_utpr_pool > 0) |>
    summarise(pool_usd = sum(stage4_utpr_pool), .by = c(scenario_id, parent, year))
  routes <- expand_utpr_routes(pools, weights) |>
    mutate(assigned_usd = pool_usd * utpr_weight)
  ledger <- routes |>
    summarise(pool_usd = first(pool_usd),
      route = coalesce(first(utpr_weight_source), "unsupported"),
      support_collectors = sum(!is.na(collector)),
      eu27_usd = sum(assigned_usd[collector_is_eu27 %in% TRUE], na.rm = TRUE),
      non_eu27_usd = sum(assigned_usd[collector_is_eu27 %in% FALSE], na.rm = TRUE),
      assigned_usd = sum(assigned_usd, na.rm = TRUE),
      .by = c(scenario_id, parent, year)) |>
    mutate(unsupported_usd = if_else(route == "unsupported", pool_usd, 0))
  stopifnot(nrow(ledger) == nrow(pools),
    all(abs(ledger$pool_usd - ledger$assigned_usd - ledger$unsupported_usd) < 1e-3),
    all(abs(ledger$assigned_usd - ledger$eu27_usd - ledger$non_eu27_usd) < 1e-3))
  channels <- bind_rows(fixed, routes |>
    filter(!is.na(collector)) |>
    summarise(revenue = sum(assigned_usd),
      .by = c(scenario_id, collector, collector_is_eu27, year)) |>
    rename(country = collector, country_is_eu27 = collector_is_eu27) |>
    mutate(channel = "UTPR"))
  source_totals <- source |>
    summarise(source_usd = sum(topup_after_behaviour),
      extinguished_usd = sum(stage4_sbs_extinguished_liability), .by = c(scenario_id, year))
  assigned <- summarise(channels, assigned_usd = sum(revenue), .by = c(scenario_id, year))
  residual <- summarise(ledger, unsupported_usd = sum(unsupported_usd), .by = c(scenario_id, year))
  totals <- source_totals |>
    left_join(assigned, by = c("scenario_id", "year"), relationship = "one-to-one") |>
    left_join(residual, by = c("scenario_id", "year"), relationship = "one-to-one") |>
    mutate(across(c(assigned_usd, unsupported_usd), ~ coalesce(.x, 0)),
      conservation_gap_usd = source_usd - assigned_usd - extinguished_usd - unsupported_usd)
  stopifnot(all(abs(totals$conservation_gap_usd) < 1e-3))
  list(channels = channels, pools = ledger, totals = totals, fixed = fixed)
}

shadow_windows <- function(rows) {
  imap_dfr(UTPR_SHADOW_WINDOWS, ~ mutate(filter(rows, year %in% .x), window = .y))
}

compare_shadow_channels <- function(observed, expected, keys) {
  observed <- summarise(observed, observed = sum(revenue), .by = all_of(keys))
  expected <- summarise(expected, expected = sum(revenue), .by = all_of(keys))
  comparison <- full_join(observed, expected, by = keys, relationship = "one-to-one")
  stopifnot(!anyNA(comparison), all(abs(comparison$observed - comparison$expected) < 1e-3))
  max(abs(comparison$observed - comparison$expected))
}

shadow_totals <- function(result) {
  pools <- shadow_windows(result$pools) |>
    summarise(pools = n(),
      parent_year_pools = sum(route == "parent_year"),
      fallback_pools = sum(route == "global_year_fallback"),
      unsupported_pools = sum(route == "unsupported"),
      parent_year_pool_usd = sum(pool_usd[route == "parent_year"]),
      fallback_pool_usd = sum(pool_usd[route == "global_year_fallback"]),
      unsupported_pool_usd = sum(unsupported_usd), pool_usd = sum(pool_usd),
      .by = c(window, scenario_id))
  receipt_totals <- shadow_windows(result$channels) |>
    summarise(
      qdmtt_usd = sum(revenue[channel == "QDMTT"]),
      iir_usd = sum(revenue[channel == "IIR"]),
      utpr_usd = sum(revenue[channel == "UTPR"]),
      eu27_utpr_usd = sum(revenue[channel == "UTPR" & country_is_eu27]),
      non_eu27_utpr_usd = sum(revenue[channel == "UTPR" & !country_is_eu27]),
      eu27_assigned_usd = sum(revenue[country_is_eu27]),
      non_eu27_assigned_usd = sum(revenue[!country_is_eu27]), .by = c(window, scenario_id))
  shadow_windows(result$totals) |>
    summarise(across(c(source_usd, extinguished_usd, assigned_usd), sum),
      max_conservation_gap_usd = max(abs(conservation_gap_usd)), .by = c(window, scenario_id)) |>
    left_join(pools, by = c("window", "scenario_id"), relationship = "one-to-one") |>
    left_join(receipt_totals, by = c("window", "scenario_id"), relationship = "one-to-one") |>
    mutate(across(everything(), ~ if (is.numeric(.x)) coalesce(.x, 0) else .x),
      parent_year_pct_of_pool = 100 * safe_divide(parent_year_pool_usd, pool_usd),
      fallback_pct_of_pool = 100 * safe_divide(fallback_pool_usd, pool_usd),
      unsupported_pct_of_pool = 100 * safe_divide(unsupported_pool_usd, pool_usd))
}

shadow_country_changes <- function(channels) {
  totals <- shadow_windows(channels) |>
    summarise(revenue_usd = sum(revenue), .by = c(policy_arm, eligibility_arm, window,
      scenario_id, country, channel, country_is_eu27)) |>
    complete(nesting(policy_arm, window, scenario_id, country, channel, country_is_eu27),
      eligibility_arm = UTPR_SHADOW_ARMS, fill = list(revenue_usd = 0))
  keys <- c("policy_arm", "window", "scenario_id", "country", "channel", "country_is_eu27")
  totals |>
    left_join(filter(totals, eligibility_arm == "LEGACY") |>
      select(all_of(keys), legacy_usd = revenue_usd), by = keys, relationship = "many-to-one") |>
    mutate(change_usd = revenue_usd - legacy_usd,
      change_pct = 100 * safe_divide(change_usd, legacy_usd)) |>
    arrange(policy_arm, window, scenario_id, country, channel, eligibility_arm)
}

shadow_repeal <- function(base, activity, comparison, legacy_weights,
                          countries = c("IRL", "CYP")) {
  map_dfr(countries, function(country) {
    map_dfr(NASH_DEVIATIONS, function(deviation) {
      exit <- deviation == "full_opt_out"
      legacy_exit_weights <- if (exit) build_parent_year_utpr_weights(filter(activity, collector != country)) else legacy_weights
      # Compute the frozen game counterfactual once. All three collector maps
      # see identical post-deviation source cells, including behavioural rebound.
      after <- nash_build_deviation(base, country, deviation, legacy_exit_weights)$source
      host <- filter(after, affiliate == country)
      initial_host <- filter(base, affiliate == country)
      map_dfr(UTPR_SHADOW_ARMS, function(arm) {
        adoption <- shadow_activity(activity, comparison, arm)
        dev <- filter(adoption, !(exit & collector == country))
        adopt_weights <- if (arm == "LEGACY") legacy_weights else build_parent_year_utpr_weights(adoption)
        weights <- if (exit) build_parent_year_utpr_weights(dev) else adopt_weights
        baseline <- shadow_project(base, adopt_weights)
        revised <- shadow_project(after, weights)
        incidence <- shadow_project(host, weights)
        base_host <- shadow_windows(initial_host) |>
          summarise(foregone_qdmtt_usd = sum(stage4_qdmtt_liability),
            .by = c(scenario_id, window))
        spillover <- shadow_windows(incidence$channels) |>
          summarise(
            domestic_iir_usd = sum(revenue[channel == "IIR" & .data$country == .env$country]),
            domestic_utpr_usd = sum(revenue[channel == "UTPR" & .data$country == .env$country]),
            foreign_iir_usd = sum(revenue[channel == "IIR" & .data$country != .env$country]),
            foreign_utpr_usd = sum(revenue[channel == "UTPR" & .data$country != .env$country]),
            .by = c(scenario_id, window))
        domestic <- bind_rows(
          mutate(baseline$channels, phase = "adoption"),
          mutate(revised$channels, phase = "deviation")
        ) |>
          filter(.data$country == .env$country) |>
          shadow_windows() |>
          summarise(domestic_change_usd = sum(if_else(phase == "deviation", revenue, -revenue)),
            .by = c(scenario_id, window))
        host_summary <- shadow_totals(incidence) |>
          select(scenario_id, window, post_repeal_pool_usd = pool_usd, host_assigned_usd = assigned_usd,
            host_unsupported_usd = unsupported_pool_usd, host_extinguished_usd = extinguished_usd)
        global_summary <- shadow_totals(revised) |>
          select(scenario_id, window, global_unsupported_usd = unsupported_pool_usd)
        out <- base_host |>
          left_join(spillover, by = c("scenario_id", "window"), relationship = "one-to-one") |>
          left_join(domestic, by = c("scenario_id", "window"), relationship = "one-to-one") |>
          left_join(host_summary, by = c("scenario_id", "window"), relationship = "one-to-one") |>
          left_join(global_summary, by = c("scenario_id", "window"), relationship = "one-to-one") |>
          mutate(across(where(is.numeric), ~ coalesce(.x, 0)),
            adopted_utpr = any(adoption$collector == .env$country & adoption$collector_utpr_flag),
            deviation_utpr = adopted_utpr & !exit,
            foreign_soakup_pct = 100 * safe_divide(foreign_iir_usd + foreign_utpr_usd, foregone_qdmtt_usd),
            domestic_change_usd = if_else(abs(domestic_change_usd) < 1e-3, 0, domestic_change_usd))
        stopifnot(all(abs(out$host_assigned_usd - out$domestic_iir_usd - out$domestic_utpr_usd -
          out$foreign_iir_usd - out$foreign_utpr_usd) < 1e-3))
        mutate(out, country = .env$country, deviation = .env$deviation, eligibility_arm = arm, .before = 1)
      })
    })
  })
}

shadow_parent_exposure <- function(source) {
  source |> shadow_windows() |>
    summarise(
      iir_proxy_on = any(parent_iir_utpr_flag),
      residual_utpr_usd = sum(stage4_utpr_pool),
      source_iir_usd = sum(stage4_iir_liability),
      sbs_extinguished_usd = sum(stage4_sbs_extinguished_liability),
      .by = c(scenario_id, window, parent)
    ) |>
    mutate(total = sum(residual_utpr_usd), .by = c(scenario_id, window)) |>
    mutate(pool_share_pct = 100 * safe_divide(residual_utpr_usd, total)) |>
    select(-total) |>
    arrange(window, scenario_id, desc(residual_utpr_usd), parent)
}

verify_shadow_repeal <- function(repeal, archived) {
  keys <- c("country", "deviation", "scenario_id", "window")
  measures <- c(foregone_qdmtt_usd = "adoption_qdmtt", domestic_iir_usd = "domestic_iir_recapture",
    domestic_utpr_usd = "domestic_utpr_recapture", foreign_iir_usd = "foreign_iir_soakup",
    foreign_utpr_usd = "foreign_utpr_soakup", host_extinguished_usd = "sbs_extinguished_post_repeal",
    domestic_change_usd = "delta_domestic_collector")
  current <- filter(repeal, eligibility_arm == "LEGACY") |> select(all_of(c(keys, names(measures))))
  frozen <- filter(archived, level == "L3_pooled", country %in% current$country) |>
    select(all_of(keys), all_of(measures))
  joined <- full_join(current, frozen, by = keys, suffix = c("", "_frozen"), relationship = "one-to-one")
  gaps <- abs(as.matrix(joined[names(measures)]) - as.matrix(joined[paste0(names(measures), "_frozen")]))
  stopifnot(!anyNA(gaps), all(gaps < 1e-3))
  max(gaps)
}

run_utpr_eligibility_shadow <- function(output, processed = PROCESSED_DIR,
                                        legal_file = file.path(GMT_PROJECT_ROOT, "data", "legal", "utpr_eligibility_2026.csv")) {
  if (!dir.exists(output)) dir.create(output, recursive = TRUE)
  stopifnot(dir.exists(output), length(list.files(output, all.files = TRUE, no.. = TRUE)) == 0)
  read_frozen <- function(stem) readRDS(file.path(processed, paste0(stem, ".rds")))
  r1 <- read_frozen("stage4_5_allocation_source_panel") |> filter(scenario_id %in% NASH_IDS)
  r3 <- nash_r3_panel(r1)
  sources <- list(R1_central_record_2026_05_01 = r1, R3_full_eu27_qdmtt_iir = r3)
  activity <- build_collector_activity(r1)
  frozen_weights <- list(parent_year_weights = read_frozen("stage4_5_utpr_parent_year_weights"),
    fallback_weights = read_frozen("stage4_5_utpr_fallback_weights"))
  legacy_weights <- build_parent_year_utpr_weights(activity)
  stopifnot(identical(legacy_weights, frozen_weights))
  policy <- build_policy_flags(read_frozen("oecd_pillar2_central_record"))
  legal <- compare_utpr_eligibility(read_utpr_evidence(legal_file), activity, policy, frozen_weights)
  weights <- set_names(map(UTPR_SHADOW_ARMS, function(arm) {
    if (arm == "LEGACY") legacy_weights else
      build_parent_year_utpr_weights(shadow_activity(activity, legal, arm))
  }), UTPR_SHADOW_ARMS)

  checks <- list()
  legacy <- map(sources, ~ shadow_project(.x, weights$LEGACY))
  archived <- read_frozen("stage4_5_revenue_by_channel_global") |> filter(scenario_id %in% NASH_IDS)
  checks[["r1_global_country_year_channel"]] <- compare_shadow_channels(legacy[[1L]]$channels,
    archived, c("scenario_id", "country", "year", "channel"))
  archived_eu <- read_frozen("stage4_5_revenue_country_year") |>
    filter(scenario_id %in% NASH_IDS, revenue > 0)
  checks[["r1_eu_country_year_total"]] <- compare_shadow_channels(
    filter(legacy[[1L]]$channels, country_is_eu27), archived_eu, c("scenario_id", "country", "year"))
  archived_r3 <- readr::read_csv(file.path(processed, "diagnostics", "step7_cyprus_and_article50_sensitivity.csv"),
    show_col_types = FALSE) |>
    filter(regime == names(sources)[2L], country %in% EU27_ISO3, start_year == min(MAIN_YEARS),
      collector_revenue > 0) |>
    rename(revenue = collector_revenue)
  checks[["r3_eu_country_total"]] <- compare_shadow_channels(
    filter(legacy[[2L]]$channels, country_is_eu27), archived_r3, c("scenario_id", "country"))

  results <- purrr::imap(sources, function(source, policy_arm) {
    reference <- legacy[[policy_arm]]
    alternatives <- map(weights[-1L], ~ shadow_project(source, .x, fixed = reference$fixed))
    purrr::imap(c(list(LEGACY = reference), alternatives), function(result, arm) {
      map(result[c("channels", "pools", "totals")],
        ~ mutate(.x, policy_arm = .env$policy_arm, eligibility_arm = arm, .before = 1))
    })
  })
  combined <- unlist(results, recursive = FALSE)
  summary <- imap_dfr(results, function(arms, policy) {
    imap_dfr(arms, ~ mutate(shadow_totals(.x), policy_arm = policy, eligibility_arm = .y, .before = 1))
  })
  dims <- c("policy_arm", "window", "scenario_id")
  summary <- summary |>
    left_join(filter(summary, eligibility_arm == "LEGACY") |>
      select(all_of(dims), legacy_eu27_assigned_usd = eu27_assigned_usd,
        legacy_global_assigned_usd = assigned_usd), by = dims, relationship = "many-to-one") |>
    mutate(eu27_change_usd = eu27_assigned_usd - legacy_eu27_assigned_usd,
      global_change_usd = assigned_usd - legacy_global_assigned_usd,
      eu27_change_pct = 100 * safe_divide(eu27_change_usd, legacy_eu27_assigned_usd),
      global_change_pct = 100 * safe_divide(global_change_usd, legacy_global_assigned_usd))

  channels <- map_dfr(combined, "channels")
  legal <- legal |>
    left_join(filter(channels, policy_arm == names(sources)[1L], eligibility_arm == "LEGACY",
      scenario_id == NASH_IDS[1L], channel == "UTPR") |>
      summarise(legacy_universal_utpr_usd = sum(revenue), .by = country) |> rename(iso3 = country),
    by = "iso3", relationship = "one-to-one") |>
    mutate(legacy_universal_utpr_usd = coalesce(legacy_universal_utpr_usd, 0))
  repeal <- shadow_repeal(r3, activity, legal, legacy_weights)
  checks[["r3_ireland_cyprus_game_incidence"]] <- verify_shadow_repeal(repeal,
    readr::read_csv(file.path(processed, "diagnostics", "step13_unilateral_qdmtt_deviation_matrix.csv"),
      show_col_types = FALSE))
  files <- list(legal_mapping = legal, shadow_summary = summary,
    country_channels = shadow_country_changes(channels),
    pool_support = map_dfr(combined, "pools"),
    parent_exposure = shadow_parent_exposure(r1), repeal_shadow = repeal,
    legacy_checks = tibble(check = names(checks), max_absolute_gap_usd = unlist(checks, use.names = FALSE)))
  purrr::iwalk(files, ~ readr::write_csv(.x, file.path(output, paste0(.y, ".csv"))))
  invisible(files)
}

if (is_direct_script_run("code/allocation/utpr_eligibility_shadow.R")) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 1L) stop("Supply a new or empty shadow output directory", call. = FALSE)
  run_utpr_eligibility_shadow(args[[1L]])
}
