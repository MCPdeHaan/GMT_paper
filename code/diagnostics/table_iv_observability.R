# R10a uses the existing R09b measurement, scenario and routing functions.
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code",
  "diagnostics", "statutory_rate_audit.R"), local = TRUE)
source(file.path(GMT_PROJECT_ROOT, "code", "10_accounting_bridge_and_conduit_wedge.R"), local = TRUE)

T4_HOST_KEYS <- c("affiliate", "year")
T4_COMPONENT_KEYS <- c(LADDER_KEYS, "etr_bracket")
T4_AUDIT_WINDOWS <- c(stats::setNames(as.list(MAIN_YEARS), MAIN_YEARS),
  list(FY2023 = 2023L, `2017–2018` = BSPI_IMPUTE_YEARS,
    `2019–2023` = DIRECT_YEARS, `2017–2023` = MAIN_YEARS))
T4_AUDIT_ARMS <- c("LEGACY", "COMPLETE_DIRECT_ONLY", "COMPLETE_DIRECT_AND_BSPI", "BSPI_ONLY")

t4_pinned_status <- function(raw) {
  select(raw, REF_AREA, COUNTERPART_AREA, TIME_PERIOD, EFFECTIVE_TAX_RATE,
    MEASURE, OBS_STATUS, OBS_VALUE) |>
    filter(MEASURE %in% c("PROFIT", "TAX_ACCRUED", "TAX_PAID")) |>
    transmute(parent = REF_AREA, affiliate = COUNTERPART_AREA, year = as.integer(TIME_PERIOD),
      etr_bracket = gsub("[-[:space:]]", "_", tolower(EFFECTIVE_TAX_RATE)),
      measure = tolower(MEASURE), value = OBS_VALUE,
      status = case_when(
        OBS_STATUS == "Q" & is.na(value) ~ "explicit_suppression",
        !is.na(value) & is.finite(value) ~ "observed",
        is.nan(value) | is.infinite(value) ~ "invalid",
        TRUE ~ "missing_unclassified"
      ))
}

t4_component_ledger <- function(clean, status = NULL) {
  assert_unique_keys(clean, T4_COMPONENT_KEYS, "Table IV bracket")
  components <- select(clean, all_of(T4_COMPONENT_KEYS), profit, tax_accrued, tax_paid)
  if (!is.null(status)) {
    assert_unique_keys(status, c(T4_COMPONENT_KEYS, "measure"), "Table IV raw measure")
    evidence <- status |>
      select(-value) |>
      pivot_wider(names_from = measure, values_from = status, names_prefix = "status_",
        values_fill = "absent_measure")
    components <- left_join(components, evidence, by = T4_COMPONENT_KEYS,
      relationship = "one-to-one")
  } else {
    components <- mutate(components, across(c(profit, tax_accrued, tax_paid),
      ~ case_when(is.nan(.x) | is.infinite(.x) ~ "invalid", is.na(.x) ~ "missing_unclassified",
        TRUE ~ "observed"), .names = "status_{.col}"))
  }
  components |>
    mutate(across(starts_with("status_"), ~ coalesce(.x, "absent_measure")),
      component_class = case_when(
        is.nan(profit) | is.nan(tax_accrued) | is.infinite(profit) |
          is.infinite(tax_accrued) ~ "non_finite",
        etr_bracket == "negative_tax_accrued" & tax_accrued < 0 ~ "negative_accrued_category",
        etr_bracket %in% T4_DIRECT_POSITIVE_BRACKETS &
          (profit < 0 | (etr_bracket == "rate_0_15" & tax_accrued < 0)) ~ "invalid_sign",
        is.na(profit) & is.na(tax_accrued) ~ "missing_profit_and_tax",
        is.na(profit) ~ "missing_profit_observed_tax",
        profit == 0 & is.na(tax_accrued) ~ "zero_profit_missing_tax",
        profit == 0 & tax_accrued == 0 ~ "zero_profit_zero_tax",
        profit > 0 & is.na(tax_accrued) ~ "positive_profit_missing_tax",
        profit > 0 & tax_accrued == 0 ~ "positive_profit_zero_tax",
        profit > 0 & tax_accrued > 0 ~ "positive_profit_positive_tax",
        TRUE ~ "other_observed"
      )) |>
    arrange(parent, affiliate, year, etr_bracket)
}

# A pool's screened point concerns the published, compatible population.
# Unknown attendance and alternative bracket schedules are reported separately.
t4_partition_support <- function(components, keys, numerator = "tax_accrued") {
  assert_unique_keys(components, T4_COMPONENT_KEYS, "Table IV bracket")
  components |>
    filter(year %in% DIRECT_YEARS, etr_bracket %in% T4_DIRECT_POSITIVE_BRACKETS) |>
    mutate(low = etr_bracket == "rate_0_15", tax = .data[[numerator]],
      profit_valid = is.finite(profit) & profit >= 0, profit_positive = profit_valid & profit > 0,
      tax_valid = is.finite(tax) & tax >= 0,
      low_positive_with_tax = low & profit_positive & tax_valid,
      low_positive_missing_tax = low & profit_positive & is.na(tax) & !is.nan(tax),
      low_tax_problem = low & (!profit_valid | (profit_positive & !tax_valid) |
        (profit_valid & profit == 0 & !is.na(tax) & (!tax_valid | tax != 0)) | is.nan(tax))) |>
    summarise(
      parents = n_distinct(parent), rows = n(), lower_rows = sum(low), upper_rows = sum(!low),
      lower_observed = sum(low & profit_valid), upper_observed = sum(!low & profit_valid),
      lower_missing = sum(low & !profit_valid), upper_missing = sum(!low & !profit_valid),
      invalid_profit = sum(is.nan(profit) | is.infinite(profit) | coalesce(profit < 0, FALSE)),
      invalid_lower_tax = sum(low & (is.nan(tax) | is.infinite(tax) | coalesce(tax < 0, FALSE))),
      lower_tax_problems = sum(low_tax_problem),
      positive_low_tax_missing = sum(low_positive_missing_tax),
      zero_low_tax_observed = sum(low & profit_positive & tax_valid & tax == 0, na.rm = TRUE),
      positive_low_tax_observed = sum(low_positive_with_tax),
      low_tax_suppressed = sum(low & status_tax_accrued == "explicit_suppression"),
      low_tax_blank = sum(low & status_tax_accrued == "missing_unclassified"),
      observed_profit = sum_or_na(profit[profit_valid]),
      observed_low_profit = sum_or_na(profit[low & profit_valid]),
      observed_upper_profit = sum_or_na(profit[!low & profit_valid]),
      observed_low_tax = sum_or_na(tax[low & tax_valid]),
      unidentified_tax_profit = sum(profit[low_positive_missing_tax]),
      incompatible_low_rate = any(tax[low_positive_with_tax] >
        GMT_RATE * profit[low_positive_with_tax]),
      .by = all_of(keys)) |>
    mutate(absent_lower = lower_rows == 0L, absent_upper = upper_rows == 0L,
      mixed_profit = lower_observed + upper_observed > 0 & lower_missing + upper_missing > 0,
      mixed_low_tax = positive_low_tax_observed > 0 & positive_low_tax_missing > 0,
      all_positive_low_tax_missing = positive_low_tax_observed == 0 & positive_low_tax_missing > 0,
      complete_profit = lower_observed > 0 & upper_observed > 0 &
        lower_missing + upper_missing == 0 & observed_profit > 0,
      complete_direct = complete_profit & lower_tax_problems == 0,
      support = case_when(complete_direct ~ "complete_published_partition",
        lower_observed + upper_observed > 0 ~ "partial_direct_information",
        TRUE ~ "unsupported_direct_information"))
}

t4_partial_bounds <- function(support) {
  support |>
    mutate(
      low_known = lower_observed > 0 & lower_missing == 0,
      upper_known = upper_observed > 0 & upper_missing == 0,
      share_lo = if_else(complete_profit, observed_low_profit / observed_profit, 0),
      share_hi = case_when(
        complete_profit ~ share_lo,
        low_known & observed_low_profit == 0 ~ 0,
        low_known ~ observed_low_profit / (observed_low_profit + coalesce(observed_upper_profit, 0)),
        TRUE ~ 1
      ),
      # Conditional on published low-bin membership and non-negative rates.
      # Zero-profit components contribute no tax and no gaps are defined for L=0.
      gap_bounded = low_known & observed_low_profit > 0 & invalid_lower_tax == 0 &
        lower_tax_problems == positive_low_tax_missing & !incompatible_low_rate,
      known_low_tax = if_else(gap_bounded, coalesce(observed_low_tax, 0), NA_real_),
      gap_lo = if_else(gap_bounded,
        pmax(0, GMT_RATE - (known_low_tax + GMT_RATE * unidentified_tax_profit) / observed_low_profit),
        NA_real_),
      gap_hi = if_else(gap_bounded, pmax(0, GMT_RATE - known_low_tax / observed_low_profit), NA_real_),
      bracket_topup_lo = observed_low_profit * gap_lo,
      bracket_topup_hi = observed_low_profit * gap_hi,
      liability_rate_lo = if_else(gap_bounded, share_lo * gap_lo, NA_real_),
      liability_rate_hi = if_else(gap_bounded, share_hi * gap_hi, NA_real_)
    )
}

t4_anchor_profiles <- function(partitions, keys) {
  partitions |>
    filter(year %in% BSPI_ANCHOR_YEARS, complete_direct) |>
    arrange(year) |>
    summarise(anchor_years = paste(year, collapse = "+"),
      anchor_profit = sum(observed_profit), anchor_low_profit = sum(observed_low_profit),
      anchor_low_tax = sum(observed_low_tax, na.rm = TRUE), .by = all_of(keys)) |>
    mutate(anchor_share = anchor_low_profit / anchor_profit,
      anchor_gap = if_else(anchor_low_profit > 0,
        GMT_RATE - clamp_interval(anchor_low_tax / anchor_low_profit, 0, GMT_RATE), 0))
}

t4_host_selection <- function(host, support, anchors, screen_direct, screen_bspi) {
  host |>
    left_join(select(support, all_of(T4_HOST_KEYS), complete_direct),
      by = T4_HOST_KEYS, relationship = "one-to-one") |>
    left_join(anchors, by = "affiliate", relationship = "many-to-one") |>
    mutate(
      direct_available = direct_available & (!screen_direct | coalesce(complete_direct, FALSE)),
      bspi_available = if (screen_bspi) year %in% BSPI_IMPUTE_YEARS & !is.na(anchor_years) else bspi_available,
      bspi_low_share = if (screen_bspi) anchor_share else bspi_low_share,
      bspi_topup_rate = if (screen_bspi) anchor_gap else bspi_topup_rate,
      stage1_distributional_source = choose_distributional_source(year, direct_available,
        percentile_available, bspi_available, average_available),
      stage1_distributional_low_share = case_when(
        stage1_distributional_source == "direct_t4" ~ direct_low_share,
        stage1_distributional_source == "percentile_fit" ~ percentile_low_share,
        stage1_distributional_source == "shape_transport" ~ bspi_low_share,
        stage1_distributional_source == "avg_only" ~ average_low_share
      ),
      stage1_distributional_topup_rate = case_when(
        stage1_distributional_source == "direct_t4" ~ direct_topup_rate,
        stage1_distributional_source == "percentile_fit" ~ percentile_topup_rate,
        stage1_distributional_source == "shape_transport" ~ bspi_topup_rate,
        stage1_distributional_source == "avg_only" ~ average_topup_rate
      ),
      stage1_distributional_liability_rate =
        stage1_distributional_low_share * stage1_distributional_topup_rate
    )
}

t4_legacy_host <- function(host, pooled) {
  direct <- pooled |>
    filter(year %in% DIRECT_YEARS, etr_bracket %in% T4_DIRECT_POSITIVE_BRACKETS) |>
    summarise(direct_positive_profit_total = sum(pmax(profit, 0), na.rm = TRUE),
      direct_low_profit = sum(if_else(etr_bracket == "rate_0_15", pmax(profit, 0), 0), na.rm = TRUE),
      direct_low_tax = sum(if_else(etr_bracket == "rate_0_15", tax_accrued, 0), na.rm = TRUE),
      .by = all_of(T4_HOST_KEYS)) |>
    mutate(metrics = pmap(list(direct_low_profit, direct_low_tax, direct_positive_profit_total),
      direct_rule_metrics),
      direct_low_share = map_dbl(metrics, "low_share"), direct_topup_rate = map_dbl(metrics, "topup_rate")) |>
    select(-metrics)
  anchors <- direct |>
    filter(year %in% BSPI_ANCHOR_YEARS) |>
    summarise(anchor_years = paste(sort(year), collapse = "+"),
      anchor_profit = sum(direct_positive_profit_total, na.rm = TRUE),
      anchor_low_profit = sum(direct_low_profit, na.rm = TRUE),
      anchor_low_tax = sum(direct_low_tax, na.rm = TRUE), .by = affiliate) |>
    mutate(bspi_low_share = safe_divide(anchor_low_profit, anchor_profit),
      bspi_topup_rate = if_else(anchor_low_profit > 0,
        GMT_RATE - clamp_interval(safe_divide(anchor_low_tax, anchor_low_profit), 0, GMT_RATE), 0))
  fields <- c(names(direct)[-c(1, 2)], "bspi_low_share", "bspi_topup_rate")
  rebuilt <- host |>
    select(-all_of(fields)) |>
    left_join(direct, by = T4_HOST_KEYS, relationship = "one-to-one") |>
    left_join(select(anchors, affiliate, anchor_years, bspi_low_share, bspi_topup_rate),
      by = "affiliate", relationship = "many-to-one") |>
    mutate(direct_available = is.finite(direct_low_share) & is.finite(direct_topup_rate),
      bspi_available = year %in% BSPI_IMPUTE_YEARS & !is.na(anchor_years))
  empty_anchors <- transmute(anchors, affiliate, anchor_years = NA_character_,
    anchor_share = NA_real_, anchor_gap = NA_real_)
  rebuilt <- t4_host_selection(select(rebuilt, -anchor_years), direct |> mutate(complete_direct = TRUE),
    empty_anchors, FALSE, FALSE)
  parity <- c(fields, "direct_available", "bspi_available", "stage1_distributional_source",
    "stage1_distributional_low_share", "stage1_distributional_topup_rate", "stage1_distributional_liability_rate")
  stopifnot(identical(select(rebuilt, all_of(parity)), select(host, all_of(parity))))
  list(host = rebuilt, anchors = anchors)
}

t4_bilateral_measurements <- function(frozen, support, hosts) {
  screened <- semi_join(frozen$brackets, filter(support, complete_direct), by = LADDER_KEYS)
  legacy <- ladder_build_measurements(frozen$stage1, frozen$host, frozen$brackets, rank_consistent = TRUE)
  revised <- ladder_build_measurements(frozen$stage1, frozen$host, screened, rank_consistent = TRUE)
  for (i in 4:5) {
    prefix <- c("ladder_l4_anchored_", "ladder_l4_strict_")[i - 3]
    check <- filter(legacy$measurements, level == LADDER_LEVELS[i]) |>
      left_join(select(frozen$stage1, all_of(LADDER_KEYS), starts_with(prefix)),
        by = LADDER_KEYS, relationship = "one-to-one")
    stopifnot(identical(check$share, check[[paste0(prefix, "low_share")]]),
      identical(check$gap, check[[paste0(prefix, "topup_rate")]]))
  }
  options <- list(legacy$measurements, revised$measurements, revised$measurements, legacy$measurements)
  options[[2]] <- bind_rows(filter(options[[2]], level != LADDER_BSPI | !year %in% BSPI_IMPUTE_YEARS),
    filter(legacy$measurements, level == LADDER_BSPI, year %in% BSPI_IMPUTE_YEARS))
  options[[4]] <- bind_rows(filter(options[[4]], level != LADDER_BSPI | !year %in% BSPI_IMPUTE_YEARS),
    filter(revised$measurements, level == LADDER_BSPI, year %in% BSPI_IMPUTE_YEARS))
  purrr::imap(set_names(options, T4_AUDIT_ARMS), function(measurements, arm) {
    measurements <- measurements |>
      left_join(transmute(hosts[[arm]], affiliate, year, host_share = stage1_distributional_low_share,
        host_gap = stage1_distributional_topup_rate, host_source = stage1_distributional_source),
        by = T4_HOST_KEYS, relationship = "many-to-one") |>
      mutate(pooled = level == LADDER_LEVELS[3],
        share = if_else(pooled, host_share, share), gap = if_else(pooled, host_gap, gap),
        source_tier = if_else(pooled, host_source, source_tier),
        measured = is.finite(share) & is.finite(gap),
        low_profit = if_else(measured, analysis_profit_positive * share, NA_real_),
        stage1_tax = low_profit * gap) |>
      select(-pooled, -host_share, -host_gap, -host_source) |>
      arrange(level, parent, affiliate, year)
    assert_unique_keys(measurements, c(LADDER_KEYS, "level"), "R10a ladder")
    stopifnot(nrow(measurements) == nrow(legacy$measurements))
    measurements
  })
}

t4_scope <- function(x, eu = "affiliate_is_eu27") {
  bind_rows(mutate(x, scope = "Global"), mutate(filter(x, .data[[eu]]), scope = "EU27"))
}

t4_measurement_summary <- function(measurements, stage2) {
  pre <- imap_dfr(measurements, ~ mutate(.x, arm = .y))
  taxes <- select(stage2, all_of(LADDER_KEYS), rate_scenario, stage2_phi)
  pre |>
    left_join(filter(taxes, rate_scenario == "initial") |> select(-rate_scenario),
      by = LADDER_KEYS, relationship = "many-to-one") |>
    mutate(post_sbie_tax = stage1_tax * (1 - coalesce(stage2_phi, 0))) |>
    t4_scope() |>
    ladder_windows(T4_AUDIT_WINDOWS) |>
    summarise(cells = n(), unmeasured = sum(!measured),
      base_usd = sum(analysis_profit_positive), unmeasured_base_usd = sum(analysis_profit_positive[!measured]),
      low_profit_usd = sum(low_profit, na.rm = TRUE), pre_sbie_usd = sum(stage1_tax, na.rm = TRUE),
      post_sbie_usd = sum(post_sbie_tax, na.rm = TRUE),
      .by = c(arm, level, scope, window, source_tier)) |>
    arrange(arm, level, scope, window, source_tier)
}

t4_validation_summary <- function(read_diag, pooled, bilateral) {
  pool <- function(data) left_join(data, select(pooled, all_of(T4_HOST_KEYS), complete_direct),
    by = T4_HOST_KEYS, relationship = "one-to-one")
  restrict <- function(data, keys) left_join(data, select(bilateral, all_of(keys), complete_direct),
    by = keys, relationship = "many-to-one")
  s1 <- pool(read_diag("affiliate_year")) |>
    filter(stage1_distributional_source == "direct_t4") |>
    mutate(analysis_profit_base = total_analysis_profit_positive,
      low_share_diff = percentile_low_share - direct_low_share,
      liability_rate_diff = percentile_liability_rate - direct_liability_rate)
  s3 <- restrict(read_diag("bilateral_matched"), LADDER_KEYS)
  s2 <- read_diag("affiliate_year_parent_restricted")
  s2_complete <- s2 |>
    select(all_of(T4_HOST_KEYS), parents) |>
    tidyr::separate_longer_delim(parents, "+") |>
    rename(parent = parents) |>
    restrict(LADDER_KEYS) |>
    summarise(complete_direct = all(complete_direct %in% TRUE), .by = all_of(T4_HOST_KEYS))
  s2 <- left_join(s2, s2_complete, by = T4_HOST_KEYS, relationship = "one-to-one")
  samples <- imap_dfr(list(S1_unmatched = s1, S2_parent_restricted = s2, S3_bilateral = s3),
    ~ mutate(.x, validation = .y)) |>
    filter(is.finite(low_share_diff), is.finite(liability_rate_diff))
  bind_rows(mutate(samples, sample = "legacy_natural"),
    mutate(filter(samples, complete_direct %in% TRUE), sample = "common_and_screened_natural"),
    mutate(filter(samples, !complete_direct %in% TRUE), sample = "excluded")) |>
    t4_scope() |>
    summarise(n = n(), base_usd = sum(analysis_profit_base),
      share_bias_pp = 100 * mean(low_share_diff),
      share_mae_pp = 100 * mean(abs(low_share_diff)),
      liability_bias_pp = 100 * mean(liability_rate_diff),
      liability_mae_pp = 100 * mean(abs(liability_rate_diff)),
      liability_weighted_mae_pp = 100 * weighted.mean(abs(liability_rate_diff), analysis_profit_base),
      .by = c(validation, sample, scope)) |>
    arrange(validation, scope, sample)
}

t4_accounting_support <- function(components, frozen) {
  keys <- LADDER_KEYS
  partition <- step8_table4_partitions(components) |>
    select(all_of(keys), t4_low_share, t4_low_observed, t4_upper_observed)
  map_dfr(c("T1_accrued", "T2_cash", "T3_envelope"), function(numerator) {
    mutated <- mutate(components, variant_tax = bridge_tax(tax_accrued, tax_paid, numerator))
    support <- t4_partition_support(mutated, keys, "variant_tax")
    frozen$stage1 |>
      select(all_of(keys), affiliate_is_eu27, analysis_profit_positive) |>
      inner_join(partition, by = keys, relationship = "one-to-one") |>
      inner_join(support, by = keys, relationship = "one-to-one") |>
      mutate(numerator = numerator, legacy_shape = is.finite(t4_low_share),
        candidate_shape = complete_profit, candidate_gap = complete_direct,
        legacy_two_sided = t4_low_observed & t4_upper_observed) |>
      t4_scope() |>
      summarise(cells = n(), base_usd = sum(analysis_profit_positive),
        t4_low_profit_usd = sum(observed_low_profit, na.rm = TRUE),
        .by = c(numerator, scope, legacy_shape, legacy_two_sided, candidate_shape, candidate_gap))
  })
}

t4_accounting_purge <- function(clean, frozen, hosts) {
  partitions <- step8_table4_partitions(clean)
  fields <- c("stage1_distributional_source", "stage1_distributional_low_share",
    "stage1_distributional_topup_rate")
  map_dfr(c("LEGACY", "COMPLETE_DIRECT_AND_BSPI"), function(arm) {
    host <- hosts[[arm]]
    stage1 <- frozen$stage1 |>
      select(-all_of(fields)) |>
      left_join(select(host, all_of(T4_HOST_KEYS), all_of(fields)), by = T4_HOST_KEYS,
        relationship = "many-to-one")
    result <- step8_reconcile_rates(stage1, frozen$base, host, partitions, 1, "reporter_pool")
    result$cells |>
      mutate(arm = arm, affiliate_is_eu27 = affiliate %in% EU27_ISO3) |>
      t4_scope() |>
      ladder_windows(T4_AUDIT_WINDOWS) |>
      summarise(revised_profit_usd = sum(revised_profit),
        revised_low_profit_usd = sum(revised_lowtax_profit),
        revised_pre_sbie_usd = sum(revised_stage1_tax), removed_foreign_profit_usd = sum(foreign_removal),
        .by = c(arm, scope, window))
  })
}

t4_fiscal_summary <- function(fiscal, preferred) {
  keys <- c("scenario_id", "year")
  sources <- fiscal$source |> filter(scenario_id %in% preferred) |>
    mutate(low_profit = stage1_lowtax_profit_distributional, pre_sbie = stage1_topup_tax_distributional) |>
    summarise(low_profit = sum_or_na(low_profit), pre_sbie = sum_or_na(pre_sbie),
      post_sbie_sector = sum(topup_after_stage2, na.rm = TRUE), post_behaviour = sum(topup_after_behaviour),
      relocated_profit = sum(reallocated_profit), utpr_pool = sum(stage4_utpr_pool),
      extinguished = sum(stage4_sbs_extinguished_liability),
      .by = c(all_of(keys), affiliate, affiliate_is_eu27))
  collectors <- fiscal$collectors |> filter(scenario_id %in% preferred) |>
    summarise(assigned = sum(revenue), .by = c(all_of(keys), country, country_is_eu27, channel))
  grouping <- c("scenario_id", "window", "scope")
  assigned <- collectors |> t4_scope("country_is_eu27") |> ladder_windows(T4_AUDIT_WINDOWS) |>
    summarise(amount = sum(assigned), .by = c(all_of(grouping), channel)) |>
    pivot_wider(names_from = channel, values_from = amount, values_fill = 0) |>
    mutate(assigned_total = QDMTT + IIR + UTPR)
  unassigned <- fiscal$conservation |> filter(scenario_id %in% preferred) |>
    ladder_windows(T4_AUDIT_WINDOWS) |>
    summarise(unsupported_utpr = sum(unsupported_utpr),
      max_conservation_gap = max(abs(residual_gap)), .by = c("scenario_id", "window"))
  summary <- sources |> t4_scope() |> ladder_windows(T4_AUDIT_WINDOWS) |>
    summarise(across(c(low_profit:extinguished), sum_or_na), .by = all_of(grouping)) |>
    left_join(assigned, by = grouping, relationship = "one-to-one") |>
    left_join(unassigned, by = c("scenario_id", "window"), relationship = "many-to-one") |>
    mutate(unsupported_utpr = if_else(scope == "Global", unsupported_utpr, NA_real_))
  list(summary = summary, sources = sources, collectors = collectors)
}

t4_fiscal_shadow <- function(hosts, measurements, frozen, processed, read) {
  beta <- applied_preferred_beta(NULL, processed)
  frozen$model_fits$linear$coefficient_table <- mutate(frozen$model_fits$linear$coefficient_table,
    estimate = if_else(term == "tau", beta, estimate))
  fiscal <- purrr::imap(hosts, function(host, arm) {
    message("L3 fiscal shadow: ", arm)
    result <- audit_core_fiscal(list(host = host), frozen$stage2, frozen$sectors, frozen)
    if (arm == "LEGACY") audit_usd_parity(result, frozen)
    t4_fiscal_summary(result, c("x10001", "x10011"))
  })
  factorial <- read("stage3_factorial_pair_year")
  stage2 <- select(frozen$stage2, all_of(LADDER_KEYS), rate_scenario, affiliate_is_eu27,
    analysis_profit_positive, stage2_phi, stage2_topup_tax_average)
  strict <- map(measurements[c("LEGACY", "COMPLETE_DIRECT_ONLY")], function(levels) {
    message("Strict L4 fiscal shadow")
    # The published strict L4 maps unmeasured cells to zero at the allocator,
    # while the measurement ledger retains their missing rates and liabilities.
    strict <- filter(levels, level == LADDER_LEVELS[5]) |>
      mutate(low_profit = coalesce_zero(low_profit), stage1_tax = coalesce_zero(stage1_tax))
    stage <- ladder_apply_sbie(strict, stage2)
    panel <- ladder_rebuild_scenarios(strict, stage, factorial, frozen$host, frozen$sectors, beta)
    source <- build_source_panel(panel) |>
      select(-any_of("stage1_topup_tax_distributional")) |>
      left_join(select(strict, all_of(LADDER_KEYS), stage1_topup_tax_distributional = stage1_tax),
        by = LADDER_KEYS, relationship = "many-to-one")
    allocation <- allocate_stage4_revenue(source, frozen$weights)
    conservation <- build_conservation_diagnostics(source, allocation$revenue_by_channel_global,
      allocation$unsupported_utpr)
    t4_fiscal_summary(list(source = source, collectors = allocation$revenue_by_channel_global,
      conservation = conservation), c("x10001", "x10011"))
  })
  bind <- function(name) bind_rows(
    imap_dfr(fiscal, ~ mutate(.x[[name]], arm = .y, level = "L3", .before = 1)),
    imap_dfr(strict, ~ mutate(.x[[name]], arm = .y, level = "L4_strict", .before = 1)))
  list(summary = bind("summary"), sources = bind("sources"), collectors = bind("collectors"))
}

t4_reporting_profiles <- function(components) {
  components |>
    summarise(brackets = paste(sort(unique(etr_bracket)), collapse = "+"),
      compatible_low = any(etr_bracket == "rate_0_15"),
      compatible_upper = any(etr_bracket %in% setdiff(T4_DIRECT_POSITIVE_BRACKETS, "rate_0_15")),
      alternate_schedule = any(startsWith(etr_bracket, "rate_") &
        !etr_bracket %in% T4_DIRECT_POSITIVE_BRACKETS),
      any_accrued_suppression = any(status_tax_accrued == "explicit_suppression"),
      .by = all_of(LADDER_KEYS)) |>
    arrange(parent, affiliate, year)
}

t4_output_directory <- function(output, project) {
  if (!startsWith(output, "/") || file.exists(output) ||
      !Sys.readlink(output) %in% c("", NA_character_)) {
    stop("Supply a new absolute diagnostic output directory.")
  }
  parent <- normalizePath(dirname(output), mustWork = TRUE)
  path <- file.path(parent, basename(output))
  protected <- file.path(normalizePath(project, mustWork = TRUE), c("data", "writing", "tests", "code"))
  if (any(startsWith(paste0(path, "/"), paste0(protected, "/")))) {
    stop("Output directory must be outside production and test paths.")
  }
  path
}

run_table_iv_observability <- function(output, project = GMT_PROJECT_ROOT, reference = project) {
  output <- t4_output_directory(output, project)
  if (normalizePath(reference) != normalizePath(project)) t4_output_directory(output, reference)
  verification <- new.env(parent = baseenv())
  sys.source(file.path(project, "tests", "verify_golden_step15.R"), envir = verification)
  stopifnot(statutory_rate_specification() == "STANDARD_ROLE_SPECIFIC",
    utpr_specification() == "VERIFIED_PARENT_ONLY",
    behavioural_specification() == "NO_NOTCH_STANDARD_RESPONSE",
    verification$verify_golden_step15(reference, project, "r09b"))
  processed <- file.path(reference, "data", "processed")
  read <- function(name) readRDS(file.path(processed, paste0(name, ".rds")))
  read_diag <- function(name) readr::read_csv(file.path(processed, "diagnostics",
    paste0("step3_stage1_crossval_", name, ".csv")), show_col_types = FALSE)
  raw_relative <- "data/raw/oecd_cbcr/cbcr_table4_etr_aggregates_alt.csv"
  raw_path <- file.path(project, raw_relative)
  input_manifest <- utils::read.table(file.path(project, "tests", "step17_raw_inputs.sha256"),
    col.names = c("hash", "path"), colClasses = "character")
  stopifnot(identical(verification$sha256_files(raw_path),
    input_manifest$hash[match(raw_relative, input_manifest$path)]))
  raw <- readr::read_csv(raw_path, show_col_types = FALSE,
    col_types = readr::cols(TIME_PERIOD = readr::col_integer(), OBS_VALUE = readr::col_double()))
  status <- t4_pinned_status(raw)
  clean <- read("cbcr_table4")
  components <- t4_component_ledger(clean, status)
  for (name in c("profit", "tax_accrued", "tax_paid")) {
    original <- filter(status, measure == name)
    agree <- original |>
      inner_join(select(components, all_of(T4_COMPONENT_KEYS), all_of(name)),
        by = T4_COMPONENT_KEYS, relationship = "one-to-one")
    stopifnot(nrow(agree) == nrow(original), identical(agree$value, agree[[name]]))
  }
  pooled <- read("base_panel_t4_bracket_shares")
  frozen <- audit_frozen_inputs(processed)
  historical <- audit_pooled_t4_completeness(frozen$host, pooled)
  historical_path <- file.path(processed, "diagnostics", "step3_stage1_pooled_t4_completeness_sensitivity.csv")

  in_scope <- filter(components, !affiliate %in% STAGE02_AGGREGATE_AFFILIATES)
  bilateral_components <- filter(in_scope, !parent %in% STAGE02_AGGREGATE_AFFILIATES)
  partitions_host <- t4_partition_support(in_scope, T4_HOST_KEYS)
  partitions_pair <- t4_partition_support(bilateral_components, LADDER_KEYS)
  attendance <- t4_partition_support(in_scope, LADDER_KEYS) |>
    summarise(all_contributing_parents_two_sided = all(lower_observed > 0 & upper_observed > 0),
      missing_lower_parents = sum(lower_observed == 0L), missing_upper_parents = sum(upper_observed == 0L),
      .by = all_of(T4_HOST_KEYS))
  anchor_profiles <- t4_anchor_profiles(partitions_host, "affiliate")
  legacy <- t4_legacy_host(frozen$host, pooled)
  hosts <- set_names(list(legacy$host,
    t4_host_selection(frozen$host, partitions_host, anchor_profiles, TRUE, FALSE),
    t4_host_selection(frozen$host, partitions_host, anchor_profiles, TRUE, TRUE),
    t4_host_selection(frozen$host, partitions_host, anchor_profiles, FALSE, TRUE)), T4_AUDIT_ARMS)
  measurements <- t4_bilateral_measurements(frozen, partitions_pair, hosts)
  l3 <- filter(measurements$LEGACY, level == LADDER_LEVELS[3]) |>
    left_join(select(frozen$stage1, all_of(LADDER_KEYS), stage1_topup_tax_distributional),
      by = LADDER_KEYS, relationship = "one-to-one")
  stopifnot(identical(l3$stage1_tax, l3$stage1_topup_tax_distributional))
  stage_summary <- t4_measurement_summary(measurements, frozen$stage2)
  pair_anchors <- t4_anchor_profiles(partitions_pair, c("parent", "affiliate"))
  pair_old <- summarise_observed_t4(frozen$brackets, LADDER_KEYS) |>
    transmute(parent, affiliate, year, complete_direct = t4_available,
      observed_profit = t4_positive_profit, observed_low_profit = t4_low_profit,
      observed_low_tax = t4_low_tax) |>
    t4_anchor_profiles(c("parent", "affiliate"))
  compare_anchors <- function(old, new, keys) full_join(
    rename_with(old, ~ paste0("legacy_", .x), -all_of(keys)),
    rename_with(new, ~ paste0("screened_", .x), -all_of(keys)),
    by = keys, relationship = "one-to-one")
  anchor_host <- compare_anchors(legacy$anchors, anchor_profiles, "affiliate")
  anchor_pair <- compare_anchors(pair_old, pair_anchors, c("parent", "affiliate"))

  host_ledger <- frozen$host |>
    select(all_of(T4_HOST_KEYS), affiliate_is_eu27, n_pair_years, total_analysis_profit_positive,
      avg_etr_stage1, direct_positive_profit_total, direct_low_profit, direct_low_tax,
      direct_low_share, direct_topup_rate, stage1_distributional_source,
      percentile_available, average_available) |>
    left_join(t4_partial_bounds(partitions_host), by = T4_HOST_KEYS, relationship = "one-to-one") |>
    left_join(attendance, by = T4_HOST_KEYS, relationship = "one-to-one") |>
    mutate(support = coalesce(support, "absent_compatible_partition")) |>
    arrange(affiliate, year)
  pair_ledger <- frozen$stage1 |>
    select(all_of(LADDER_KEYS), affiliate_is_eu27, analysis_profit_positive,
      ladder_l4_strict_source, ladder_l4_strict_low_share, ladder_l4_strict_topup_rate) |>
    left_join(t4_partial_bounds(partitions_pair), by = LADDER_KEYS, relationship = "one-to-one") |>
    mutate(support = coalesce(support, "absent_compatible_partition")) |>
    arrange(parent, affiliate, year)
  host_measurements <- imap_dfr(hosts, function(host, arm) {
    host |> transmute(arm, affiliate, year, affiliate_is_eu27, total_analysis_profit_positive,
      source = stage1_distributional_source, share = stage1_distributional_low_share,
      gap = stage1_distributional_topup_rate, low_profit = total_analysis_profit_positive * share,
      stage1_tax = low_profit * gap)
  })
  pair_changes <- imap_dfr(measurements[-1], function(levels, arm) {
    levels |>
      inner_join(transmute(measurements$LEGACY, across(all_of(c(LADDER_KEYS, "level"))),
        old_tier = source_tier, old_share = share, old_gap = gap, old_tax = stage1_tax),
        by = c(LADDER_KEYS, "level"), relationship = "one-to-one") |>
      filter(!vctrs::vec_equal(share, old_share, na_equal = TRUE) |
        !vctrs::vec_equal(gap, old_gap, na_equal = TRUE) | source_tier != old_tier) |>
      mutate(arm = arm, .before = 1)
  })
  fiscal <- t4_fiscal_shadow(hosts, measurements, frozen, processed, read)
  strict_reference <- readr::read_csv(file.path(processed, "diagnostics",
    "step10_ladder_revenue_and_sbs_summary.csv"), show_col_types = FALSE) |>
    filter(estimator == STEP10_MODELS[3], record_type == "summary", level == LADDER_LEVELS[5],
      window %in% c("FY2023", "2017–2023", "2019–2023")) |>
    select(scope, window, stage1_topup_usd, direct_collector_usd_universal, direct_collector_usd_sbs)
  strict_rebuilt <- fiscal$summary |>
    filter(arm == "LEGACY", level == "L4_strict", window %in% strict_reference$window) |>
    inner_join(strict_reference, by = c("scope", "window"), relationship = "many-to-one") |>
    mutate(archived = if_else(scenario_id == "x10001",
      direct_collector_usd_universal, direct_collector_usd_sbs),
      # Use the project's US$0.001 annual parity allowance for summed years.
      tolerance = 1e-3 * lengths(T4_AUDIT_WINDOWS[window]))
  stopifnot(nrow(strict_rebuilt) == 2L * nrow(strict_reference),
    all(abs(strict_rebuilt$assigned_total - strict_rebuilt$archived) < strict_rebuilt$tolerance),
    all(abs(strict_rebuilt$pre_sbie - strict_rebuilt$stage1_topup_usd) < strict_rebuilt$tolerance))
  interaction <- fiscal$summary |>
    filter(level == "L3") |>
    select(arm, scenario_id, scope, window, pre_sbie, post_sbie_sector, assigned_total) |>
    pivot_longer(c(pre_sbie, post_sbie_sector, assigned_total), names_to = "metric") |>
    pivot_wider(names_from = arm, values_from = value) |>
    mutate(direct_effect = COMPLETE_DIRECT_ONLY - LEGACY,
      bspi_effect_alone = BSPI_ONLY - LEGACY,
      bspi_effect_given_direct = COMPLETE_DIRECT_AND_BSPI - COMPLETE_DIRECT_ONLY,
      combined_effect = COMPLETE_DIRECT_AND_BSPI - LEGACY,
      interaction = bspi_effect_given_direct - bspi_effect_alone)
  output_tables <- list(
    raw_status_counts = count(raw, MEASURE, OBS_STATUS, observed = is.finite(OBS_VALUE)),
    component_ledger = components,
    component_counts = count(components, etr_bracket, component_class, status_profit, status_tax_accrued),
    reporting_profiles = t4_reporting_profiles(components),
    host_observability = host_ledger, pair_observability = pair_ledger,
    historical_completeness = historical,
    host_anchor_profiles = anchor_host, pair_anchor_profiles = anchor_pair,
    host_measurements = host_measurements, changed_pair_measurements = pair_changes,
    ladder_summary = stage_summary, matched_validation = t4_validation_summary(read_diag, partitions_host, partitions_pair),
    accounting_support = t4_accounting_support(in_scope, frozen),
    accounting_dividend_shadow = t4_accounting_purge(clean, frozen, hosts),
    fiscal_summary = fiscal$summary, fiscal_sources = fiscal$sources,
    fiscal_collectors = fiscal$collectors, interaction = interaction
  )
  inventory <- tibble(file = paste0(c(names(output_tables), "inventory"), ".csv"),
    rows = c(vapply(output_tables, nrow, integer(1)), length(output_tables) + 1L))
  output_tables$inventory <- inventory
  stopifnot(dir.create(output))
  iwalk(output_tables, ~ write_csv(.x, file.path(output, paste0(.y, ".csv"))))
  stopifnot(identical(verification$sha256_files(file.path(output, "historical_completeness.csv")),
    verification$sha256_files(historical_path)))
  message("R10a shadow outputs written to ", output)
  invisible(inventory)
}

if (is_direct_script_run(file.path(GMT_PROJECT_ROOT, "code", "diagnostics", "table_iv_observability.R"))) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 1L) stop("Usage: Rscript --vanilla code/diagnostics/table_iv_observability.R /absolute/new/output")
  run_table_iv_observability(args[1L])
}
