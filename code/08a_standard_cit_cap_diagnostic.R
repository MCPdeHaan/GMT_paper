# Opt-in cap sensitivity. Never called by run_all.R and never writes processed data.
# Run from the checkout: Rscript --vanilla code/08a_standard_cit_cap_diagnostic.R
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code",
  "08_measurement_and_cbcr_extensions.R"), local = TRUE)

read_standard_cit_rates <- function(path) {
  raw <- read_csv(path, show_col_types = FALSE)
  # OECD DSD_TAX_CIT@DF_CIT: CIT/S1311 = central, CIT_C/S13 = combined.
  # ST = standard; TA = targeted small-business rate. Rates are percentages.
  select_rate <- function(measure, sector, targeting, name) {
    data <- raw |>
      filter(FREQ == "A", MEASURE == measure, SECTOR == sector,
        TARGETING == targeting, UNIT_MEASURE == "PT_INC_TAX", UNIT_MULT == 0) |>
      transmute(affiliate = REF_AREA, year = as.integer(TIME_PERIOD), rate = OBS_VALUE / 100)
    assert_unique_keys(data, HOST_KEY, paste("CIT", name))
    stopifnot(all(is.finite(data$rate) & data$rate >= 0 & data$rate <= 1))
    names(data)[3L] <- name
    data
  }
  central <- select_rate("CIT", "S1311", "ST", "standard_central_rate")
  combined <- select_rate("CIT_C", "S13", "ST", "standard_headline_rate")
  targeted <- select_rate("CIT", "S1311", "TA", "targeted_central_rate")
  full_join(central, combined, by = HOST_KEY, relationship = "one-to-one") |>
    full_join(targeted, by = HOST_KEY, relationship = "one-to-one")
}

run_standard_cit_cap_diagnostic <- function(
  processed_dir = file.path(GMT_PROJECT_ROOT, "data", "processed"),
  raw_path = file.path(GMT_PROJECT_ROOT, "data", "raw", "oecd_tax_rates", "oecd_statutory_cit_rates.csv"),
  output = file.path(GMT_PROJECT_ROOT, "docs", "audit_standard_vs_targeted_cit_cap.csv")
) {
  # Refuse processed-data output paths, even if a caller supplies one explicitly.
  parent <- normalizePath(dirname(output), mustWork = TRUE)
  protected <- unique(c(normalizePath(processed_dir, mustWork = TRUE),
    normalizePath(file.path(GMT_PROJECT_ROOT, "data", "processed"), mustWork = TRUE)))
  if (any(parent == protected | startsWith(parent, paste0(protected, .Platform$file.sep)))) {
    stop("Diagnostic output must be outside data/processed.")
  }
  if (!is.null(statutory_rate_metadata(processed_dir))) {
    stop("The historical cap diagnostic requires LEGACY_TARGETED processed data.")
  }

  # This is a conditional percentile-cap sensitivity. Keep corrected profits,
  # mean ETR anchors, Table IV, BSPI, sample membership and SBIE shields frozen.
  # It does not redo upstream mean winsorisation, profit reconciliation,
  # behavioural estimation or collector allocation.
  read <- function(name) readRDS(file.path(processed_dir, paste0(name, ".rds")))
  host <- read("stage1_affiliate_year")
  stage1 <- read("stage1_bilateral_panel")
  stage2 <- read("stage2_bilateral_panel") |>
    select(all_of(LADDER_KEYS), rate_scenario, affiliate_is_eu27,
      analysis_profit_positive, stage2_phi)
  brackets <- read("base_panel_t4_bilateral_bracket_shares")
  rates <- read_standard_cit_rates(raw_path)
  caps <- host |>
    select(affiliate, year, frozen_cap = affiliate_etr_cap_stage1) |>
    left_join(rates, by = HOST_KEY, relationship = "one-to-one") |>
    mutate(
      standard_headline_cap = pmin(1, coalesce(standard_headline_rate + ZETA_LOSS_OFFSET, 1)),
      standard_central_cap = pmin(1, coalesce(standard_central_rate + ZETA_LOSS_OFFSET, 1)),
      headline_coverage = if_else(is.finite(standard_headline_rate), "observed_combined", "missing_no_cap"),
      frozen_rate_kind = case_when(
        is.finite(targeted_central_rate) ~ "targeted_central",
        is.finite(standard_central_rate) ~ "standard_central",
        TRUE ~ "missing_no_cap")
    )
  # Audit the raw/processed mapping, including the misleading legacy column.
  legacy <- read("cit_statutory") |>
    transmute(affiliate = jurisdiction, year, central = cit_standard / 100, targeted = cit_top_all / 100) |>
    left_join(rates, by = HOST_KEY, relationship = "one-to-one")
  stopifnot(isTRUE(all.equal(legacy$central, legacy$standard_central_rate)),
    isTRUE(all.equal(legacy$targeted, legacy$targeted_central_rate)),
    max(abs(caps$frozen_cap - pmin(1, coalesce(caps$targeted_central_rate,
      caps$standard_central_rate, 0.95) + ZETA_LOSS_OFFSET))) < 1e-12)

  # Paired summaries share the exact frozen observations and year effects.
  sample_paths <- c(S1 = "affiliate_year", S2 = "affiliate_year_parent_restricted", S3 = "bilateral_matched")
  cv <- imap_dfr(sample_paths, function(suffix, sample) {
    data <- read_csv(file.path(processed_dir, "diagnostics",
      paste0("step3_stage1_crossval_", suffix, ".csv")), show_col_types = FALSE)
    if (!"mean_etr" %in% names(data)) data$mean_etr <- data$avg_etr_stage1
    if (!"parent" %in% names(data)) data$parent <- NA_character_
    transmute(data, sample, parent, affiliate, year, mean_etr,
      across(all_of(Q_RAW)), direct_low_share, direct_topup_rate, direct_liability_rate,
      frozen_low_share = percentile_low_share, frozen_topup_rate = percentile_topup_rate,
      frozen_liability_rate = percentile_liability_rate)
  }) |>
    left_join(caps, by = HOST_KEY, relationship = "many-to-one")
  stopifnot(identical(as.integer(table(cv$sample)), c(361L, 70L, 81L)))
  fit_cv <- function(cap_column) {
    fitted <- cv |>
      mutate(affiliate_etr_cap_stage1 = .data[[cap_column]]) |>
      fit_matched_beta_metrics()
    if (cap_column == "frozen_cap") {
      # CSV round trips perturb the nonlinear fit at about 1e-8; require 1e-7.
      stopifnot(max(abs(fitted$percentile_low_share - fitted$frozen_low_share)) < 1e-7,
        max(abs(fitted$percentile_liability_rate - fitted$frozen_liability_rate)) < 1e-7)
      fitted$percentile_low_share <- fitted$frozen_low_share
      fitted$percentile_topup_rate <- fitted$frozen_topup_rate
      fitted$percentile_liability_rate <- fitted$frozen_liability_rate
    }
    imap_dfr(split(fitted, fitted$sample), ~ summarise_stage1_crossval(.x, .y)) |>
      filter(outcome %in% c("low_share", "liability_rate"),
        statistic %in% c("n", "median_gap", "mae", "calibration_r_squared")) |>
      transmute(sample, metric = paste(outcome, statistic, sep = "_"), value,
        unit = if_else(statistic == "n", "cells", "fraction"))
  }
  frozen_cv <- fit_cv("frozen_cap")
  levels <- LADDER_LEVELS[3:5]
  baseline <- ladder_build_measurements(stage1, host, brackets, rank_consistent = TRUE)$measurements |>
    filter(level %in% levels)
  # Replay checks prevent comparing an alternative estimator to a stale baseline.
  for (i in seq_along(levels)) {
    prefix <- c("ladder_l3_", "ladder_l4_anchored_", "ladder_l4_strict_")[i]
    check <- filter(baseline, level == levels[i]) |>
      left_join(select(stage1, all_of(LADDER_KEYS), starts_with(prefix)),
        by = LADDER_KEYS, relationship = "one-to-one")
    stopifnot(isTRUE(all.equal(check$share, check[[paste0(prefix, "low_share")]])),
      isTRUE(all.equal(check$gap, check[[paste0(prefix, "topup_rate")]])))
  }
  summarise_revenue <- function(measurements) {
    post <- map_dfr(levels, function(level) {
      ladder_apply_sbie(filter(measurements, .data$level == .env$level), stage2) |>
        mutate(level = .env$level)
    })
    ladder_stage_summary(measurements, post) |>
      filter(record_type == "summary", window %in% c("2017–2023", "FY2023")) |>
      transmute(level, scope, window, stage1_usd_bn = stage1_topup_usd / 1e9,
        post_sbie_initial_usd_bn = stage2_topup_usd_bn_initial,
        post_sbie_long_run_usd_bn = stage2_topup_usd_bn_long_run) |>
      pivot_longer(ends_with("usd_bn"), names_to = "metric", values_to = "value") |>
      mutate(unit = "USD billions, window total")
  }
  focal <- function(measurements) {
    measurements |>
      filter(parent == affiliate, affiliate %in% c("FRA", "DEU", "NLD", "BEL", "LUX"), year == 2023) |>
      transmute(parent, affiliate, year, level, source_tier,
        low_share = share, topup_gap = gap, liability_rate = share * gap,
        stage1_usd_bn = stage1_tax / 1e9) |>
      pivot_longer(c(low_share, topup_gap, liability_rate, stage1_usd_bn), names_to = "metric", values_to = "value") |>
      mutate(unit = if_else(metric == "stage1_usd_bn", "USD billions", "fraction"))
  }
  compare <- function(before, after, keys, type, specification) {
    left_join(rename(before, frozen = value), rename(after, standard = value),
      by = c(keys, "metric", "unit"), relationship = "one-to-one") |>
      mutate(record_type = type, specification, delta = standard - frozen,
        relative_change_pct = if_else(frozen != 0, 100 * delta / frozen, NA_real_))
  }
  frozen_revenue <- summarise_revenue(baseline)
  frozen_focal <- focal(baseline)
  results <- list()
  # Central-only comparison distinguishes targeting from government coverage.
  for (specification in c("standard_headline", "standard_central")) {
    cap_column <- paste0(specification, "_cap")
    alternative_host <- left_join(host, select(caps, all_of(HOST_KEY), all_of(cap_column)),
      by = HOST_KEY, relationship = "one-to-one")
    alternative_host$affiliate_etr_cap_stage1 <- alternative_host[[cap_column]]
    eligible <- which(is.finite(host$avg_etr_stage1) & rowSums(is.finite(as.matrix(host[Q_RAW]))) == 5L)
    for (i in eligible) {
      q <- unlist(host[i, Q_RAW], use.names = FALSE)
      fit <- fit_constrained_beta_percentiles(q, host$avg_etr_stage1[i],
        upper_cap = alternative_host$affiliate_etr_cap_stage1[i])
      point <- if (fit$boundary_flag) fit$mean else NA_real_
      alternative_host$percentile_beta_precision[i] <- fit$precision
      alternative_host$percentile_beta_precision_rank_bounded[i] <- stage1_fit_cell(q,
        host$avg_etr_stage1[i], alternative_host$affiliate_etr_cap_stage1[i], STAGE1_BETA_MODELS[3])$precision
      if (host$stage1_distributional_source[i] == "percentile_fit") {
        alternative_host$stage1_distributional_low_share[i] <- beta_mass_below(fit$alpha, fit$beta, boundary_mean = point)
        alternative_host$stage1_distributional_topup_rate[i] <- beta_avg_topup_rate(fit$alpha, fit$beta, boundary_mean = point)
      }
    }
    alternative_stage1 <- stage1 |>
      select(-stage1_distributional_low_share, -stage1_distributional_topup_rate, -affiliate_cit_rate_unit) |>
      left_join(transmute(alternative_host, affiliate, year,
        stage1_distributional_low_share, stage1_distributional_topup_rate,
        affiliate_cit_rate_unit = .data[[cap_column]] - ZETA_LOSS_OFFSET),
        by = HOST_KEY, relationship = "many-to-one")
    alternative <- ladder_build_measurements(alternative_stage1, alternative_host, brackets,
      rank_consistent = TRUE)$measurements |>
      filter(level %in% levels)
    stopifnot(identical(baseline$measured, alternative$measured),
      identical(baseline$source_tier, alternative$source_tier))
    results[[specification]] <- bind_rows(
      compare(frozen_cv, fit_cv(cap_column), "sample", "cross_validation", specification),
      compare(frozen_revenue, summarise_revenue(alternative), c("level", "scope", "window"), "revenue", specification),
      compare(frozen_focal, focal(alternative), c("parent", "affiliate", "year", "level", "source_tier"), "focal_cell", specification)
    )
  }
  rate_report <- caps |>
    mutate(record_type = "cap_metadata", mean_anchor = host$avg_etr_stage1,
      raw_mean = host$avg_etr_raw,
      mean_was_clipped = is.finite(raw_mean) & raw_mean > frozen_cap)
  report <- bind_rows(bind_rows(results), rate_report) |>
    mutate(estimand = "percentile caps only; frozen mean ETRs, profits, direct Table IV, BSPI and SBIE")
  stopifnot(!anyNA(report$standard[report$record_type %in% c("cross_validation", "revenue", "focal_cell")]))
  write_csv(report, output)
  message("Wrote ", nrow(report), " diagnostic rows to ", output)
  invisible(report)
}

if (is_direct_script_run("code/08a_standard_cit_cap_diagnostic.R")) {
  run_standard_cit_cap_diagnostic()
}
