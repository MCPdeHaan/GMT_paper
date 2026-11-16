# R09a shadows use the pinned input and existing model methods.
# Rscript --vanilla code/diagnostics/statutory_rate_audit.R /absolute/new/output [--joint]
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "09_econometric_and_reallocation_extensions.R"), local = TRUE)
source(file.path(GMT_PROJECT_ROOT, "code", "08a_standard_cit_cap_diagnostic.R"), local = TRUE)
source(file.path(GMT_PROJECT_ROOT, "code", "02a_profit_reconciliation_model.R"), local = TRUE)
source(file.path(GMT_PROJECT_ROOT, "code", "02_base_correction_and_merging.R"), local = TRUE)

AUDIT_RATE_SPECS <- c("LEGACY", "STANDARD_COMBINED", "STANDARD_CENTRAL", "EXPLICIT_FALLBACK")
AUDIT_RATE_KEYS <- c("affiliate", "year")
AUDIT_RATE_WINDOWS <- list(FY2023 = 2023L, `2017–2023` = MAIN_YEARS)

audit_rate_series <- function(raw) {
  dictionary <- tribble(
    ~MEASURE, ~SECTOR, ~TARGETING, ~series,
    "CIT", "S1311", "TA", "targeted_central",
    "CIT", "S1311", "ST", "standard_central",
    "CIT_C", "S13", "ST", "standard_combined",
    "CIT_SCG", "S13M", "ST", "standard_subcentral",
    "CIT_LSN", "S1311", "ST", "standard_central_less_subcentral_deduction",
    "CIT_EX_ST", "S1311", "ST", "standard_central_excluding_surtax"
  )
  selected <- inner_join(raw, dictionary, by = c("MEASURE", "SECTOR", "TARGETING"),
    relationship = "many-to-one")
  stopifnot(is.numeric(selected$OBS_VALUE), all(selected$FREQ == "A"),
    all(selected$UNIT_MEASURE == "PT_INC_TAX"), all(selected$UNIT_MULT == 0),
    all(selected$DIV_TREATMENT == "_Z"), all(selected$RATE_STRUCTURE == "_Z"),
    all(selected$TAX_BASE == "_Z"), all(is.finite(selected$TIME_PERIOD)),
    all(grepl("^[A-Z0-9]{3}$", selected$REF_AREA)))
  selected <- selected |>
    transmute(oecd_code = REF_AREA, affiliate = normalize_code(REF_AREA),
      year = as.integer(TIME_PERIOD), series, status = OBS_STATUS,
      recorded_percent = OBS_VALUE,
      valid = is.finite(OBS_VALUE) & between(OBS_VALUE, 0, 100),
      rate = if_else(valid, OBS_VALUE / 100, NA_real_))
  assert_unique_keys(selected, c(AUDIT_RATE_KEYS, "series"), "OECD statutory-rate observations")
  selected
}

audit_rate_lookup <- function(series, keys) {
  full_join(distinct(keys, across(all_of(AUDIT_RATE_KEYS))),
    pivot_wider(series, id_cols = all_of(AUDIT_RATE_KEYS), names_from = series,
      values_from = c(rate, status, valid, oecd_code, recorded_percent)),
    by = AUDIT_RATE_KEYS, relationship = "one-to-one") |>
    arrange(affiliate, year)
}

audit_select_rate <- function(data, specification) {
  specification <- match.arg(specification, AUDIT_RATE_SPECS)
  order <- switch(specification,
    LEGACY = c("targeted_central", "standard_central"),
    STANDARD_COMBINED = "standard_combined",
    STANDARD_CENTRAL = "standard_central",
    EXPLICIT_FALLBACK = c("standard_combined", "standard_central"))
  rate <- rep(NA_real_, nrow(data))
  source <- rep("missing", nrow(data))
  for (series in order) {
    value <- data[[paste0("rate_", series)]]
    replace <- is.na(rate) & is.finite(value)
    rate[replace] <- value[replace]
    source[replace] <- series
  }
  transmute(data, affiliate, year, rate, rate_source = source)
}

audit_cap <- function(rate) pmin(1, coalesce(rate + ZETA_LOSS_OFFSET, 1))

audit_bilateral_mean <- function(raw, rate) {
  case_when(
    is.na(raw) | raw < -ZETA_LOSS_OFFSET ~ NA_real_,
    raw < 0 ~ 0,
    TRUE ~ pmin(raw, audit_cap(rate))
  )
}

audit_rate_lag <- function(rates) {
  transmute(rates, affiliate, year = year + 1L, lagged_rate = rate)
}

audit_exposure <- function(rates, stage1, base, archived) {
  preferred <- archived |>
    filter(scenario_id %in% c("x10001", "x10011")) |>
    summarise(topup = sum(topup_after_behaviour), .by = c(affiliate, year, scenario_id)) |>
    pivot_wider(names_from = scenario_id, values_from = topup, names_prefix = "post_behaviour_")
  exposure <- stage1 |>
    summarise(positive_profit = sum(analysis_profit_positive),
      low_taxed_profit = sum(stage1_lowtax_profit_distributional, na.rm = TRUE),
      pre_sbie_topup = sum(stage1_topup_tax_distributional, na.rm = TRUE), .by = all_of(AUDIT_RATE_KEYS))
  legacy <- audit_select_rate(rates, "LEGACY")
  combined <- audit_select_rate(rates, "STANDARD_COMBINED")
  central <- audit_select_rate(rates, "STANDARD_CENTRAL")
  explicit <- audit_select_rate(rates, "EXPLICIT_FALLBACK")
  host_keys <- distinct(base, affiliate, year) |> mutate(in_base_as_affiliate = TRUE)
  parent_keys <- transmute(base, affiliate = parent, year) |>
    distinct() |> mutate(in_base_as_parent = TRUE)
  rates |>
    left_join(host_keys, by = AUDIT_RATE_KEYS, relationship = "one-to-one") |>
    left_join(parent_keys, by = AUDIT_RATE_KEYS, relationship = "one-to-one") |>
    left_join(exposure, by = AUDIT_RATE_KEYS, relationship = "one-to-one") |>
    left_join(preferred, by = AUDIT_RATE_KEYS, relationship = "one-to-one") |>
    mutate(in_base_as_affiliate = in_base_as_affiliate %in% TRUE,
      in_base_as_parent = in_base_as_parent %in% TRUE,
      in_production_host_panel = !is.na(positive_profit),
      legacy_rate = legacy$rate, legacy_source = legacy$rate_source,
      explicit_rate = explicit$rate, explicit_source = explicit$rate_source,
      combined_minus_legacy = combined$rate - legacy$rate,
      central_minus_legacy = central$rate - legacy$rate,
      combined_minus_central = combined$rate - central$rate,
      destination_gate_differs = !vctrs::vec_equal(combined$rate >= GMT_RATE,
        legacy$rate >= GMT_RATE, na_equal = TRUE))
}

audit_fit_host <- function(host) {
  rows <- which(is.finite(host$avg_etr_stage1) & rowSums(is.finite(as.matrix(host[Q_RAW]))) == 5L)
  refit <- map_dfr(rows, function(i) {
    q <- unlist(host[i, Q_RAW], use.names = FALSE)
    mean <- host$avg_etr_stage1[i]
    cap <- host$affiliate_etr_cap_stage1[i]
    fit <- fit_constrained_beta_percentiles(q, mean, upper_cap = cap)
    point <- if (fit$boundary_flag) fit$mean else NA_real_
    rank <- stage1_fit_cell(q, mean, cap, STAGE1_BETA_MODELS[3])
    tibble(affiliate = host$affiliate[i], year = host$year[i], cap, mean,
      alpha = fit$alpha, beta = fit$beta, precision = fit$precision,
      rank_precision = rank$precision, rank_share = rank$share, rank_gap = rank$gap,
      rank_projection = rank$rank_projection,
      share = beta_mass_below(fit$alpha, fit$beta, boundary_mean = point),
      gap = beta_avg_topup_rate(fit$alpha, fit$beta, boundary_mean = point)) |>
      bind_cols(tibble::as_tibble_row(setNames(condition_stage1_percentiles(q, cap),
        paste0("conditioned_", Q_RAW))))
  })
  refit
}

audit_measurement <- function(stage1, host, brackets, selected, mean_clip = FALSE, percentile_cap = FALSE) {
  rate <- selected$rate[vctrs::vec_match(host[AUDIT_RATE_KEYS], selected[AUDIT_RATE_KEYS])]
  if (mean_clip) {
    cell_rate <- selected$rate[vctrs::vec_match(stage1[AUDIT_RATE_KEYS], selected[AUDIT_RATE_KEYS])]
    stage1$etr_panelai_stage1 <- audit_bilateral_mean(stage1$etr_panelai_raw, cell_rate)
    host$avg_etr_stage1 <- pmin(pmax(host$avg_etr_raw, 0), audit_cap(rate))
    host$average_low_share <- if_else(is.finite(host$avg_etr_stage1),
      as.numeric(host$avg_etr_stage1 < GMT_RATE), NA_real_)
    host$average_topup_rate <- pmax(0, GMT_RATE - host$avg_etr_stage1)
    stage1 <- stage1 |>
      select(-average_low_share, -average_topup_rate) |>
      left_join(select(host, all_of(AUDIT_RATE_KEYS), average_low_share, average_topup_rate),
        by = AUDIT_RATE_KEYS, relationship = "many-to-one")
  }
  if (percentile_cap) {
    host$affiliate_etr_cap_stage1 <- audit_cap(rate)
    stage1$affiliate_cit_rate_unit <- selected$rate[vctrs::vec_match(stage1[AUDIT_RATE_KEYS], selected[AUDIT_RATE_KEYS])]
  }
  fits <- audit_fit_host(host)
  fitted_at <- vctrs::vec_match(host[AUDIT_RATE_KEYS], fits[AUDIT_RATE_KEYS])
  estimated <- !is.na(fitted_at)
  host$percentile_beta_precision[estimated] <- fits$precision[fitted_at[estimated]]
  host$percentile_beta_precision_rank_bounded[estimated] <- fits$rank_precision[fitted_at[estimated]]
  fitted <- host$stage1_distributional_source %in% "percentile_fit"
  average <- host$stage1_distributional_source %in% "avg_only"
  stopifnot(all(estimated[fitted]))
  host$stage1_distributional_low_share[fitted] <- fits$share[fitted_at[fitted]]
  host$stage1_distributional_topup_rate[fitted] <- fits$gap[fitted_at[fitted]]
  host$stage1_distributional_low_share[average] <- host$average_low_share[average]
  host$stage1_distributional_topup_rate[average] <- host$average_topup_rate[average]
  high_tv <- host$stage1_distributional_source_strict %in% "avg_only_high_tv"
  host$stage1_distributional_low_share_strict <- if_else(high_tv, host$average_low_share,
    host$stage1_distributional_low_share)
  host$stage1_distributional_topup_rate_strict <- if_else(high_tv, host$average_topup_rate,
    host$stage1_distributional_topup_rate)
  stage1 <- stage1 |>
    select(-stage1_distributional_low_share, -stage1_distributional_topup_rate) |>
    left_join(select(host, all_of(AUDIT_RATE_KEYS),
      stage1_distributional_low_share, stage1_distributional_topup_rate),
      by = AUDIT_RATE_KEYS, relationship = "many-to-one")
  list(host = host, fits = fits, stage1 = stage1,
    ladder = ladder_build_measurements(stage1, host, brackets, rank_consistent = TRUE))
}

audit_validation <- function(processed, rates) {
  paths <- c(S1 = "affiliate_year", S2 = "affiliate_year_parent_restricted", S3 = "bilateral_matched")
  sample <- imap_dfr(paths, function(suffix, name) {
    data <- read_csv(file.path(processed, "diagnostics",
      paste0("step3_stage1_crossval_", suffix, ".csv")), show_col_types = FALSE)
    if (!"mean_etr" %in% names(data)) data$mean_etr <- data$avg_etr_stage1
    if (!"parent" %in% names(data)) data$parent <- NA_character_
    transmute(data, sample = name, parent, affiliate, year, mean_etr,
      cap_legacy = affiliate_etr_cap_stage1, across(all_of(Q_RAW)), direct_low_share,
      direct_liability_rate, archived_share = percentile_low_share,
      archived_liability = percentile_liability_rate)
  })
  stopifnot(identical(as.integer(table(sample$sample)), c(361L, 70L, 81L)))
  rows <- map_dfr(AUDIT_RATE_SPECS, function(spec) {
    selected <- audit_select_rate(rates, spec)
    joined <- left_join(sample, selected, by = AUDIT_RATE_KEYS, relationship = "many-to-one") |>
      mutate(affiliate_etr_cap_stage1 = if (spec == "LEGACY") cap_legacy else audit_cap(rate))
    fit <- fit_matched_beta_metrics(joined)
    if (spec == "LEGACY") {
      stopifnot(max(abs(fit$percentile_low_share - fit$archived_share)) < 1e-7,
        max(abs(fit$percentile_liability_rate - fit$archived_liability)) < 1e-7)
    }
    q <- as.matrix(fit[Q_RAW])
    rank <- map_dfr(seq_len(nrow(fit)), function(i) {
      stage1_fit_cell(q[i, ], fit$mean_etr[i], fit$affiliate_etr_cap_stage1[i],
        STAGE1_BETA_MODELS[3])
    })
    fit |>
      transmute(specification = spec, sample, parent, affiliate, year, rate_source, mean_etr,
        cap = affiliate_etr_cap_stage1, direct_low_share, direct_liability_rate,
        low_share = percentile_low_share, liability_rate = percentile_liability_rate,
        low_share_error = low_share - direct_low_share,
        liability_error = liability_rate - direct_liability_rate,
        rank_low_share = rank$share, rank_liability_rate = rank$liability_rate,
        rank_conflict = stage1_rank_violation(low_share, rank$rank_lower, rank$rank_upper),
        boundary_projection = rank$rank_projection & is.na(rank$precision))
  })
  legacy_errors <- rows |>
    filter(specification == "LEGACY") |>
    select(sample, all_of(LADDER_KEYS), legacy_share_error = low_share_error,
      legacy_liability_error = liability_error)
  rows <- rows |>
    left_join(legacy_errors, by = c("sample", LADDER_KEYS), relationship = "many-to-one") |>
    mutate(paired_share_error_change = low_share_error - legacy_share_error,
      paired_liability_error_change = liability_error - legacy_liability_error,
      observation_group = case_when(
        !is.na(parent) & parent == affiliate ~ "exact_domestic",
        !is.na(parent) ~ "exact_foreign",
        TRUE ~ "host_pooled"),
      low_statutory_rate = if_else(is.finite(cap), cap < GMT_RATE + ZETA_LOSS_OFFSET, NA))
  summary <- rows |>
    pivot_longer(c(low_share, liability_rate), names_to = "outcome", values_to = "predicted") |>
    mutate(observed = if_else(outcome == "low_share", direct_low_share, direct_liability_rate),
      error = predicted - observed) |>
    group_by(specification, sample, outcome) |>
    group_modify(~ {
      x <- .x
      usable <- filter(x, is.finite(error))
      tibble(n = nrow(x), failed = nrow(x) - nrow(usable),
        hosts = n_distinct(x$affiliate), years = paste(sort(unique(x$year)), collapse = "+"),
        rank_conflicts = sum(x$rank_conflict, na.rm = TRUE),
        boundary_projections = sum(x$boundary_projection, na.rm = TRUE),
        mean_error = mean(usable$error), median_bias = median(usable$error),
        mae = mean(abs(usable$error)), rmse = sqrt(mean(usable$error^2)),
        calibration_r2 = summary(stats::lm(observed ~ predicted + factor(year), data = usable))$r.squared)
    }) |>
    ungroup()
  list(rows = rows, summary = summary)
}

audit_measurement_comparison <- function(candidate, baseline, fixed_denominator = TRUE) {
  measure <- function(x) {
    x$ladder$measurements |>
      filter(level %in% LADDER_LEVELS) |>
      select(all_of(LADDER_KEYS), level, affiliate_is_eu27, analysis_profit_positive, measured,
        source_tier, share, gap, stage1_tax)
  }
  b <- measure(baseline) |>
    rename_with(~ paste0("baseline_", .x), c(measured, source_tier, share, gap, stage1_tax))
  x <- left_join(measure(candidate), b |> select(-affiliate_is_eu27, -analysis_profit_positive),
    by = c(LADDER_KEYS, "level"), relationship = "one-to-one")
  host <- candidate$host |>
    select(all_of(AUDIT_RATE_KEYS), avg_etr_stage1)
  mean_cells <- candidate$stage1 |>
    select(all_of(LADDER_KEYS), etr_panelai_stage1) |>
    left_join(host, by = AUDIT_RATE_KEYS, relationship = "many-to-one") |>
    left_join(select(baseline$stage1, all_of(LADDER_KEYS),
      baseline_bilateral_mean = etr_panelai_stage1), by = LADDER_KEYS, relationship = "one-to-one") |>
    left_join(select(baseline$host, all_of(AUDIT_RATE_KEYS), baseline_host_mean = avg_etr_stage1),
      by = AUDIT_RATE_KEYS, relationship = "many-to-one")
  # Direct bracket rates are inputs to these comparisons and retain their
  # original values when their source tier is used. Source profit may change.
  direct <- x$source_tier %in% c("direct_t4", "exact_table_iv") &
    x$source_tier == x$baseline_source_tier
  if (fixed_denominator) {
    stopifnot(identical(x$share[direct %in% TRUE], x$baseline_share[direct %in% TRUE]),
      identical(x$gap[direct %in% TRUE], x$baseline_gap[direct %in% TRUE]))
  }
  x <- x |>
    left_join(mean_cells, by = LADDER_KEYS, relationship = "many-to-one") |>
    mutate(anchor = if_else(level %in% LADDER_LEVELS[c(1, 3)], avg_etr_stage1, etr_panelai_stage1),
      baseline_anchor = if_else(level %in% LADDER_LEVELS[c(1, 3)], baseline_host_mean, baseline_bilateral_mean),
      changed_mean = !vctrs::vec_equal(anchor, baseline_anchor, na_equal = TRUE),
      changed_share = !vctrs::vec_equal(share, baseline_share, na_equal = TRUE),
      changed_gap = !vctrs::vec_equal(gap, baseline_gap, na_equal = TRUE),
      changed_liability_rate = !vctrs::vec_equal(share * gap, baseline_share * baseline_gap, na_equal = TRUE),
      changed_support = !vctrs::vec_equal(measured, baseline_measured, na_equal = TRUE),
      changed_tier = !vctrs::vec_equal(source_tier, baseline_source_tier, na_equal = TRUE),
      boundary_conflict = startsWith(source_tier, "exact_table_i_") &
        (anchor <= BETA_BOUNDARY_EPS | anchor >= 1 - BETA_BOUNDARY_EPS) &
        share != as.numeric(anchor < GMT_RATE))
  list(cells = x, summary = bind_rows(mutate(x, scope = "Global"),
    mutate(filter(x, affiliate_is_eu27), scope = "EU27")) |>
    ladder_windows(AUDIT_RATE_WINDOWS) |>
    summarise(cells = n(), supported = sum(measured),
      across(starts_with("changed_"), sum),
      positive_profit = sum(analysis_profit_positive),
      pre_sbie = sum(stage1_tax), baseline_pre_sbie = sum(baseline_stage1_tax),
      boundary_conflicts = sum(boundary_conflict, na.rm = TRUE),
      boundary_conflict_profit = sum(analysis_profit_positive[boundary_conflict %in% TRUE]),
      boundary_point_share_delta = sum(analysis_profit_positive[boundary_conflict %in% TRUE] *
        gap[boundary_conflict %in% TRUE] * ((anchor[boundary_conflict %in% TRUE] < GMT_RATE) -
        share[boundary_conflict %in% TRUE])),
      .by = c(scope, window, level, source_tier)))
}

audit_recon_rate_input <- function(rates, legacy, specification) {
  if (specification == "LEGACY") return(legacy)
  audit_select_rate(rates, specification) |>
    transmute(jurisdiction = affiliate, year, cit_standard = 100 * rate, cit_top_all = NA_real_)
}

audit_reconciliation_case <- function(input, rates, specification) {
  temp <- withr::local_tempdir(pattern = "gmt-r09a-recon-")
  p <- file.path(temp, "data", "processed")
  dir.create(p, recursive = TRUE)
  stage02_inputs <- c(paste0("cbcr_table", 1:6), "wb_classifications", "wb_gdp", "wb_population",
    "wages_oecd", "wages_ilo_monthly", "fats_post2021", "euklems_sector_capital",
    "global_intan_invest_annual", "bea_us_mne_country_industry", "beps_rules", "cbcr_requirements",
    "oecd_pillar2_central_record")
  copied <- file.copy(file.path(input, paste0(stage02_inputs, ".rds")), p)
  stopifnot(all(copied))
  legacy <- readRDS(file.path(input, "cit_statutory.rds"))
  cit_path <- file.path(p, "cit_statutory.rds")
  saveRDS(audit_recon_rate_input(rates, legacy, specification), cit_path)
  recon <- run_profit_reconciliation_model(p, p, manual_dir = file.path(GMT_PROJECT_ROOT, "data", "manual"))
  # The reconciliation rate feeds only the prior. All subsequent rate uses in
  # this arm receive the archived statutory inputs.
  saveRDS(legacy, cit_path)
  run_base_panel(p, p)
  for (stage in c("03_stage1_etr.R", "04_stage2_sbie.R")) {
    withr::with_envvar(c(GMT_OUTPUT_ROOT = temp), {
      env <- new.env(parent = globalenv())
      sys.source(file.path(GMT_PROJECT_ROOT, "code", stage), envir = env)
      if (stage == "03_stage1_etr.R") env$run_stage1_pipeline() else env$run_stage2_pipeline()
    })
  }
  read <- function(name) readRDS(file.path(p, paste0(name, ".rds")))
  list(base = read("base_panel"), stage1 = read("stage1_bilateral_panel"),
    host = read("stage1_affiliate_year"), stage2 = read("stage2_bilateral_panel"),
    sectors = read("stage2_sectoral_panel"),
    predictions = recon$predictions, evidence = recon$evidence,
    parity = read("profit_correction_etr_parity_parent_year"))
}

audit_reconciliation_comparison <- function(case, reference, forward) {
  keys <- c("parent", "year")
  before <- reference$predictions |>
    select(all_of(keys), rho_hat_pt, rho_lo_pt, rho_hi_pt, posterior_sd, support_class) |>
    rename_with(~ paste0("baseline_", .x), -all_of(keys))
  cells <- case$base |>
    select(all_of(LADDER_KEYS), analysis_profit_base, etr_panelai_raw, etr_panelai_reg) |>
    left_join(transmute(reference$base, across(all_of(LADDER_KEYS)),
      profit_legacy = analysis_profit_base, etr_legacy = etr_panelai_raw, reg_legacy = etr_panelai_reg),
      by = LADDER_KEYS, relationship = "one-to-one") |>
    mutate(domestic = parent == affiliate,
      delta_profit = analysis_profit_base - profit_legacy,
      denom_changed = !vctrs::vec_equal(analysis_profit_base, profit_legacy, na_equal = TRUE),
      etr_changed = !vctrs::vec_equal(etr_panelai_raw, etr_legacy, na_equal = TRUE),
      reg_changed = !vctrs::vec_equal(etr_panelai_reg, reg_legacy, na_equal = TRUE))
  stopifnot(!any(cells$denom_changed[!cells$domestic]))
  samples <- list(legacy = reference$sample, candidate = prepare_estimation_sample(case$base, etr_forward = forward))
  membership <- full_join(
    transmute(samples$legacy, across(all_of(LADDER_KEYS)), legacy = TRUE),
    transmute(samples$candidate, across(all_of(LADDER_KEYS)), candidate = TRUE),
    by = LADDER_KEYS, relationship = "one-to-one") |>
    mutate(legacy = coalesce(legacy, FALSE), candidate = coalesce(candidate, FALSE))
  common <- filter(membership, legacy, candidate)
  compare_fit <- imap_dfr(samples, function(sample, name) {
    bind_rows(natural = sample, matched = semi_join(sample, common, by = LADDER_KEYS), .id = "support") |>
      group_by(support) |>
      group_modify(~ fit_fe_ols(.x, c("log_assets", "log_payroll", "tau", "log_gdp_pc", "log_population"),
        "linear")$coefficient_table_two_way |> filter(term == "tau")) |>
      ungroup() |>
      mutate(sample = name)
  })
  predictors <- case$predictions |>
    select(all_of(keys), rho_hat_pt, rho_lo_pt, rho_hi_pt, posterior_sd, support_class, main_source) |>
    left_join(before, by = keys, relationship = "one-to-one") |>
    left_join(transmute(case$parity, parent, year, parity_statutory = statutory_rate, parity_signal = rho_signal),
      by = keys, relationship = "one-to-one")
  before_parity <- transmute(reference$parity, parent, year,
    parity_statutory_legacy = statutory_rate, parity_signal_legacy = rho_signal)
  predictors <- left_join(predictors, before_parity, by = keys, relationship = "one-to-one") |>
    left_join(cells |>
      summarise(domestic_denom_changed = sum(denom_changed & domestic),
        domestic_etr_changed = sum(etr_changed & domestic), domestic_reg_etr_changed = sum(reg_changed & domestic),
        domestic_profit_delta = sum(delta_profit[domestic], na.rm = TRUE), .by = all_of(keys)),
      by = keys, relationship = "one-to-one")
  list(posterior = predictors, sample_changes = filter(membership, legacy != candidate),
    fits = compare_fit, membership = summarise(membership,
      shared = sum(legacy & candidate), legacy = sum(legacy), candidate = sum(candidate)))
}

audit_instruments <- function(rates, estimation, base) {
  inputs <- build_division_bias_inputs(estimation, base)
  has_observation <- base |>
    distinct(affiliate, year) |>
    mutate(year = year + 1L, lagged_observation = TRUE)
  samples <- set_names(map(AUDIT_RATE_SPECS, function(spec) {
    rate <- audit_select_rate(rates, spec)
    x <- estimation |>
      left_join(audit_rate_lag(rate), by = AUDIT_RATE_KEYS, relationship = "many-to-one") |>
      left_join(select(rate, all_of(AUDIT_RATE_KEYS), rate), by = AUDIT_RATE_KEYS, relationship = "many-to-one") |>
      left_join(has_observation, by = AUDIT_RATE_KEYS, relationship = "many-to-one") |>
      mutate(lagged_rate = if_else(lagged_observation %in% TRUE, lagged_rate, NA_real_)) |>
      select(-lagged_observation)
    if (spec == "LEGACY") {
      stopifnot(identical(x$rate, x$affiliate_cit_rate_unit),
        identical(x$lagged_rate, x$affiliate_cit_rate_unit_lag1))
    }
    x
  }), AUDIT_RATE_SPECS)
  current <- Reduce(`&`, map(samples, ~ is.finite(.x$rate)))
  lagged <- Reduce(`&`, map(samples, ~ is.finite(.x$lagged_rate)))
  imap_dfr(samples, function(sample, spec) {
    compare <- function(support) {
      shared <- support == "matched"
      iv <- build_single_tax_iv_diagnostics(
        sample[if (shared) lagged else rep(TRUE, nrow(sample)), ], "lagged_rate",
        "lagged_statutory_cit", spec, "Exact preceding-year rate on observed host support.") |>
        select(diagnostic, term, inference, estimate, std_error, weak_instrument_f, n, n_pairs, n_affiliates, n_parents)
      data <- mutate(inputs, statutory_cit = sample$rate)
      data <- filter(data, is.finite(statutory_cit) & if (shared) current else TRUE)
      reg <- fit_fe_ols(mutate(data, tau = statutory_cit),
        c("log_assets", "log_payroll", "tau", "log_gdp_pc", "log_population"), "linear")$coefficient_table_two_way |>
        filter(term == "tau") |>
        transmute(diagnostic = "same_year_statutory_fe_ols", term, inference, estimate, std_error,
          n, n_pairs = n_distinct(data$pair_id), n_affiliates, n_parents)
      bind_rows(iv, reg) |> mutate(specification = spec, support)
    }
    map_dfr(c("natural", "matched"), compare)
  })
}

audit_core_fiscal <- function(measurement, stage2, sectors, frozen, replace_rates = TRUE) {
  host <- measurement$host
  if (replace_rates) {
    rates <- host |>
      select(all_of(AUDIT_RATE_KEYS), average_low_share_new = average_low_share,
        average_topup_rate_new = average_topup_rate,
        distributional_low_share_new = stage1_distributional_low_share,
        distributional_topup_rate_new = stage1_distributional_topup_rate)
    stage2 <- stage2 |>
      left_join(rates, by = AUDIT_RATE_KEYS, relationship = "many-to-one") |>
      mutate(
        average_low_share = average_low_share_new,
        stage1_distributional_low_share = distributional_low_share_new,
        stage1_lowtax_profit_average = average_low_share_new * analysis_profit_positive,
        stage1_lowtax_profit_distributional = distributional_low_share_new * analysis_profit_positive,
        stage1_topup_tax_average = stage1_lowtax_profit_average * average_topup_rate_new,
        stage1_topup_tax_distributional = stage1_lowtax_profit_distributional * distributional_topup_rate_new,
        stage2_excess_lowtax_profit_average = stage1_lowtax_profit_average * stage2_filter,
        stage2_excess_lowtax_profit_distributional = stage1_lowtax_profit_distributional * stage2_filter,
        stage2_topup_tax_average = coalesce_zero(stage1_topup_tax_average) * stage2_filter,
        stage2_topup_tax_distributional = coalesce_zero(stage1_topup_tax_distributional) * stage2_filter
      )
    sectors <- sectors |>
      select(-average_topup_rate, -stage1_distributional_topup_rate) |>
      left_join(select(host, all_of(AUDIT_RATE_KEYS), average_topup_rate, stage1_distributional_topup_rate),
        by = AUDIT_RATE_KEYS, relationship = "many-to-one")
  }
  # All keys and observed activity remain attached to the frozen legal routes.
  bridge <- build_sectoral_factor2_bridge(stage2, host, sectors)
  behaviour <- build_behavioural_affiliate_year(host, frozen$model_fits)
  compact <- stage2 |>
    select(parent, affiliate, year, affiliate_jurisdiction_name, parent_jurisdiction_name,
      affiliate_is_conduit_haven, affiliate_is_eu27, employees_sbie, payroll_sbie, assets_sbie, upr_panelai,
      affiliate_cit_rate_unit, rate_scenario, analysis_profit_positive, act_ip_panelai, act_holding_panelai,
      act_igf_panelai, stage2_phi, average_low_share, stage1_distributional_low_share,
      stage1_lowtax_profit_average, stage1_lowtax_profit_distributional,
      stage1_topup_tax_average, stage1_topup_tax_distributional,
      stage2_excess_lowtax_profit_average, stage2_excess_lowtax_profit_distributional,
      stage2_topup_tax_average, stage2_topup_tax_distributional)
  factorial <- build_factorial_revenue(compact, behaviour, bridge, frozen$policy, frozen$preferred)$scenario_panel
  source <- build_source_panel(factorial)
  allocation <- allocate_stage4_revenue(source, frozen$weights)
  conservation <- build_conservation_diagnostics(source, allocation$revenue_by_channel_global,
    allocation$unsupported_utpr)
  list(source = source, collectors = allocation$revenue_by_channel_global,
    allocated_eu = allocation$revenue_country_year_eu27, conservation = conservation,
    unassigned = allocation$unsupported_utpr)
}

audit_fiscal_tables <- function(fiscal) {
  sources <- fiscal$source |>
    mutate(pre_sbie = if_else(x1_etr == 0, stage1_topup_tax_average, stage1_topup_tax_distributional),
      source_cit_loss = reallocated_profit * clamp_interval(coalesce_zero(static_tau_low), 0, GMT_RATE)) |>
    summarise(pre_sbie = sum(pre_sbie, na.rm = TRUE),
      post_sbie_and_factor2 = sum(topup_after_stage2, na.rm = TRUE),
      post_behaviour = sum(topup_after_behaviour), qdmtt_source = sum(stage4_qdmtt_liability),
      iir_source = sum(stage4_iir_liability), utpr_pool_source = sum(stage4_utpr_pool),
      extinguished = sum(stage4_sbs_extinguished_liability),
      relocated_profit = sum(reallocated_profit), source_cit_loss = sum(source_cit_loss),
      .by = c(scenario_id, year, affiliate, affiliate_is_eu27))
  collectors <- fiscal$collectors |>
    summarise(assigned = sum(revenue), .by = c(scenario_id, year, channel, country, country_is_eu27))
  global <- fiscal$conservation |>
    ladder_windows(AUDIT_RATE_WINDOWS) |>
    summarise(unsupported_utpr = sum(unsupported_utpr), residual_gap = max(abs(residual_gap)),
      global_assigned = sum(allocated_topup), .by = c(scenario_id, window))
  summaries <- bind_rows(mutate(sources, scope = "Global"),
    mutate(filter(sources, affiliate_is_eu27), scope = "EU27"),
    mutate(filter(sources, !affiliate_is_eu27), scope = "non-EU27")) |>
    select(-affiliate, -affiliate_is_eu27) |>
    ladder_windows(AUDIT_RATE_WINDOWS) |>
    summarise(across(c(pre_sbie:source_cit_loss), sum), .by = c(scenario_id, window, scope))
  assigned <- bind_rows(mutate(collectors, scope = "Global"),
    mutate(filter(collectors, country_is_eu27), scope = "EU27"),
    mutate(filter(collectors, !country_is_eu27), scope = "non-EU27")) |>
    ladder_windows(AUDIT_RATE_WINDOWS) |>
    summarise(assigned = sum(assigned), .by = c(scenario_id, window, scope, channel)) |>
    pivot_wider(names_from = channel, values_from = assigned, values_fill = 0, names_prefix = "assigned_") |>
    mutate(assigned_total = assigned_QDMTT + assigned_IIR + assigned_UTPR)
  summaries <- left_join(summaries, assigned, by = c("scenario_id", "window", "scope"),
    relationship = "one-to-one") |>
    left_join(global, by = c("scenario_id", "window"), relationship = "many-to-one") |>
    mutate(unsupported_utpr = if_else(scope == "Global", unsupported_utpr, NA_real_),
      residual_gap = if_else(scope == "Global", residual_gap, NA_real_),
      global_assigned = if_else(scope == "Global", global_assigned, NA_real_))
  preferred <- c("x10001", "x10011")
  list(scenarios = summaries,
    sources = sources |>
      filter(scenario_id %in% preferred) |>
      ladder_windows(AUDIT_RATE_WINDOWS) |>
      summarise(across(c(pre_sbie:source_cit_loss), sum), .by = c(scenario_id, window, affiliate)),
    collectors = collectors |>
      filter(scenario_id %in% preferred) |>
      ladder_windows(AUDIT_RATE_WINDOWS) |>
      summarise(assigned = sum(assigned), .by = c(scenario_id, window, country, channel)))
}

audit_price_ordinary <- function(amount, rate) {
  if_else(amount == 0, 0, amount * rate)
}

audit_ordinary_recovery <- function(factorial, stage1, host, rates, specifications = AUDIT_RATE_SPECS) {
  panel <- filter(factorial, scenario_id %in% c("x10001", "x10011"))
  a <- build_parent_specific_reallocation(panel, host)
  routes <- bind_rows(
    transmute(a$matrix, rule = "A", scenario_id, year, destination, statutory_rate,
      received = reallocated_profit_received),
    build_hub_destination_routes(panel, stage1, host) |>
      select(rule, scenario_id, year, destination, statutory_rate, received)
  )
  origin <- a$source_rows |>
    summarise(profit_sent = sum(reallocated_profit), source_effective_loss = sum(source_tax_loss),
      .by = c(affiliate, year, scenario_id))
  common <- audit_select_rate(rates, "STANDARD_COMBINED") |>
    filter(is.finite(rate)) |>
    select(all_of(AUDIT_RATE_KEYS))
  map_dfr(specifications, function(spec) {
    rate <- audit_select_rate(rates, spec)
    x <- routes |>
      left_join(rename(rate, destination = affiliate), by = c("destination", "year"),
        relationship = "many-to-one")
    if (spec == "LEGACY") stopifnot(identical(x$rate, x$statutory_rate))
    dest <- x |>
      mutate(gross = audit_price_ordinary(received, rate), gross_legacy = received * statutory_rate,
        covered = is.finite(gross)) |>
      ladder_windows(AUDIT_RATE_WINDOWS) |>
      summarise(priced = sum(received[covered]), received = sum(received),
        gross_covered = sum(gross[covered]), gross_legacy_all = sum(gross_legacy),
        gross_legacy_matched = sum(gross_legacy[covered]), .by = c(rule, scenario_id, window, destination)) |>
      rename(country = destination) |>
      mutate(gross_all = if_else(priced < received, NA_real_, gross_covered))
    sent <- origin |>
      left_join(rate, by = AUDIT_RATE_KEYS, relationship = "many-to-one") |>
      mutate(source_statutory_loss = audit_price_ordinary(profit_sent, rate),
        source_profit_priced = if_else(is.finite(rate), profit_sent, 0),
        common_support = paste(affiliate, year) %in% paste(common$affiliate, common$year)) |>
      ladder_windows(AUDIT_RATE_WINDOWS) |>
      summarise(profit_sent = sum(profit_sent), source_effective_loss = sum(source_effective_loss),
        matched_source_effective_loss = sum(source_effective_loss[common_support]),
        source_profit_priced = sum(source_profit_priced),
        source_statutory_loss_covered = sum(source_statutory_loss, na.rm = TRUE),
        .by = c(scenario_id, window, affiliate)) |>
      rename(country = affiliate) |>
      mutate(source_statutory_loss_all = if_else(source_profit_priced < profit_sent, NA_real_, source_statutory_loss_covered))
    full_join(dest, crossing(sent, rule = c("A", "B", "C")), by = c("rule", "scenario_id", "window", "country"),
      relationship = "one-to-one") |>
      mutate(specification = spec,
        net_ordinary_cit = if_else(is.na(received), 0, gross_all) - coalesce_zero(source_effective_loss),
        gross_delta_matched = gross_covered - gross_legacy_matched)
  })
}

audit_frozen_inputs <- function(processed) {
  read <- function(name) readRDS(file.path(processed, paste0(name, ".rds")))
  # These are the fitted objects used to build the archived behavioural
  # schedule, reconstructed from its numerical coefficient table.
  coefficients <- read("stage3_model_coefficients") |>
    filter(inference == "affiliate_clustered")
  models <- c("linear", "quadratic", "logarithmic")
  model_fits <- set_names(map(models, ~ list(coefficient_table = filter(coefficients, model_spec == .x))), models)
  list(preferred = read("stage3_model_comparison")$model_spec[1],
    model_fits = model_fits, policy = build_policy_flags(read("oecd_pillar2_central_record")),
    weights = read_stage4_utpr_weights(processed), base = read("base_panel"),
    host = read("stage1_affiliate_year"), stage1 = read("stage1_bilateral_panel"),
    stage2 = read("stage2_bilateral_panel"), sectors = read("stage2_sectoral_panel"),
    brackets = read("base_panel_t4_bilateral_bracket_shares"),
    sample = read("stage3_estimation_sample"), predictions = read("profit_correction_parent_year"),
    evidence = read("profit_correction_evidence"), parity = read("profit_correction_etr_parity_parent_year"),
    forward = read("etr_forward"), archived = read("stage4_5_allocation_source_panel"),
    archived_receipts = read("stage4_5_revenue_country_year"), archived_conservation = read("stage4_5_allocation_conservation"))
}

audit_usd_parity <- function(legacy, frozen) {
  key <- c("scenario_id", LADDER_KEYS)
  fields <- c("topup_after_behaviour", "stage4_qdmtt_liability", "stage4_iir_liability", "stage4_utpr_pool",
    "stage4_sbs_extinguished_liability")
  assert_core_budget_parity(legacy$source, frozen$archived, key, fields)
  assert_core_budget_parity(legacy$allocated_eu, frozen$archived_receipts, c("scenario_id", "country", "year"), "revenue")
  invisible(TRUE)
}

audit_coverage_summary <- function(exposure) {
  exposure <- filter(exposure, in_production_host_panel)
  bind_rows(mutate(exposure, scope = "Global"),
    mutate(filter(exposure, affiliate %in% EU27_ISO3), scope = "EU27")) |>
    ladder_windows(AUDIT_RATE_WINDOWS) |>
    summarise(host_years = n(), combined_missing = sum(is.na(rate_standard_combined)),
      central_missing = sum(is.na(rate_standard_central)),
      targeted_missing = sum(is.na(rate_targeted_central)),
      combined_zero = sum(rate_standard_combined == 0, na.rm = TRUE),
      profit_missing_combined = sum(positive_profit[is.na(rate_standard_combined)]),
      lowtax_missing_combined = sum(low_taxed_profit[is.na(rate_standard_combined)]),
      topup_missing_combined = sum(pre_sbie_topup[is.na(rate_standard_combined)]),
      changed_headline_caps = sum(abs(audit_cap(rate_standard_combined) - audit_cap(legacy_rate)) > 1e-12),
      disparate_rates_profit = sum(positive_profit[abs(combined_minus_legacy) > 0.05], na.rm = TRUE),
      positive_profit = sum(positive_profit), low_taxed_profit = sum(low_taxed_profit),
      pre_sbie_topup = sum(pre_sbie_topup),
      .by = c(scope, window))
}

run_statutory_rate_audit <- function(output, run_joint = FALSE,
  processed = file.path(GMT_PROJECT_ROOT, "data", "processed"),
  raw = file.path(GMT_PROJECT_ROOT, "data", "raw", "oecd_tax_rates", "oecd_statutory_cit_rates.csv")) {
  output <- file.path(normalizePath(dirname(output), mustWork = TRUE), basename(output))
  protected <- unique(normalizePath(c(processed, file.path(GMT_PROJECT_ROOT, "data", "processed"),
    file.path(GMT_PROJECT_ROOT, "data", "raw"), file.path(GMT_PROJECT_ROOT, "writing")), mustWork = TRUE))
  if (file.exists(output) || any(output == protected | startsWith(output, paste0(protected, "/")))) {
    stop("Use a new diagnostic output directory outside frozen data and publication files.", call. = FALSE)
  }
  stopifnot(utpr_specification() == "VERIFIED_PARENT_ONLY",
    behavioural_specification() == "NO_NOTCH_STANDARD_RESPONSE")
  dir.create(output)
  save <- function(data, stem) write_csv(data, file.path(output, paste0(stem, ".csv")))
  frozen <- audit_frozen_inputs(processed)
  oecd <- read_csv(raw, show_col_types = FALSE)
  keys <- bind_rows(select(frozen$base, all_of(AUDIT_RATE_KEYS)),
    transmute(frozen$base, affiliate = parent, year))
  series <- audit_rate_series(oecd)
  rates <- audit_rate_lookup(series, keys)
  exposure <- audit_exposure(rates, frozen$stage1, frozen$base, frozen$archived)
  save(exposure, "country_year_rates")
  save(audit_coverage_summary(exposure), "rate_coverage")
  validation <- audit_validation(processed, rates)
  save(validation$rows, "validation_cells")
  save(validation$summary, "validation_summary")

  selected <- audit_select_rate(rates, "LEGACY")
  legacy <- audit_measurement(frozen$stage1, frozen$host, frozen$brackets, selected)
  legacy_fits <- legacy$fits |>
    inner_join(select(frozen$host, affiliate, year, percentile_beta_alpha, percentile_beta_beta,
      percentile_beta_precision_rank_bounded), by = AUDIT_RATE_KEYS, relationship = "one-to-one")
  stopifnot(identical(legacy_fits$alpha, legacy_fits$percentile_beta_alpha),
    identical(legacy_fits$beta, legacy_fits$percentile_beta_beta),
    identical(legacy_fits$rank_precision, legacy_fits$percentile_beta_precision_rank_bounded))
  cal <- audit_core_fiscal(legacy, frozen$stage2, frozen$sectors, frozen, replace_rates = FALSE)
  audit_usd_parity(cal, frozen)
  save(audit_ordinary_recovery(cal$source, frozen$stage1, frozen$host, rates), "ordinary_cit")
  rm(cal)
  save(audit_instruments(rates, frozen$sample, frozen$base), "statutory_instruments")

  s02 <- read_csv(file.path(processed, "diagnostics", "step3_stage1_pooled_t4_completeness_sensitivity.csv"),
    show_col_types = FALSE) |>
    filter(!is.na(affiliate), missing_low_tax %in% TRUE) |>
    distinct(affiliate, year, s02_missing_low_tax = missing_low_tax)
  posteriors <- list()
  recon_regressions <- list()
  sample_changes <- list()
  sample_support <- list()
  record <- function(intervention, spec, m, stage2, sectors, replace_rates = TRUE) {
    fiscal <- audit_core_fiscal(m, stage2, sectors, frozen, replace_rates)
    label <- function(x) mutate(x, intervention = .env$intervention, specification = spec, .before = 1)
    ordinary_specs <- if (intervention == "JOINT_CANDIDATE") c("LEGACY", spec) else "LEGACY"
    ordinary <- audit_ordinary_recovery(fiscal$source, frozen$stage1, frozen$host, rates, ordinary_specs) |>
      rename(pricing_specification = specification) |>
      mutate(country_is_eu27 = country %in% EU27_ISO3)
    ordinary <- bind_rows(mutate(ordinary, scope = "Global"),
      mutate(filter(ordinary, country_is_eu27), scope = "EU27"),
      mutate(filter(ordinary, !country_is_eu27), scope = "non-EU27")) |>
      summarise(destination_cit = if (all(is.finite(gross_all) | is.na(received))) sum(gross_all, na.rm = TRUE) else NA_real_,
        received = sum(received, na.rm = TRUE), priced = sum(priced, na.rm = TRUE),
        source_effective_loss = sum(source_effective_loss, na.rm = TRUE),
        net_ordinary = destination_cit - source_effective_loss,
        .by = c(pricing_specification, scope, window, scenario_id, rule))
    budget <- ladder_core_budget_ranges(
      mutate(fiscal$allocated_eu, level = LADDER_LEVELS[c(1, 3)][x1_etr + 1L]),
      mutate(filter(fiscal$collectors, country_is_eu27), level = LADDER_LEVELS[c(1, 3)][x1_etr + 1L]))
    comparison <- audit_measurement_comparison(m, legacy,
      fixed_denominator = intervention %in% c("CAP_ONLY", "MEAN_CLIP_ONLY", "REFERENCE"))
    list(fiscal = lapply(audit_fiscal_tables(fiscal), label),
      ordinary = label(ordinary), budget = label(budget),
      measurement = label(comparison$summary),
      fits = label(m$fits |>
        left_join(select(m$host, all_of(AUDIT_RATE_KEYS), all_of(Q_RAW), stage1_distributional_source),
          by = AUDIT_RATE_KEYS, relationship = "one-to-one") |>
        left_join(s02, by = AUDIT_RATE_KEYS, relationship = "one-to-one") |>
        mutate(s02_missing_low_tax = coalesce(s02_missing_low_tax, FALSE))))
  }
  runs <- list(LEGACY = record("REFERENCE", "LEGACY", legacy, frozen$stage2, frozen$sectors, FALSE))
  for (spec in AUDIT_RATE_SPECS[-1L]) {
    selected <- audit_select_rate(rates, spec)
    for (intervention in c("CAP_ONLY", "MEAN_CLIP_ONLY")) {
      m <- audit_measurement(frozen$stage1, frozen$host, frozen$brackets, selected,
        mean_clip = intervention == "MEAN_CLIP_ONLY", percentile_cap = intervention == "CAP_ONLY")
      runs[[paste(intervention, spec)]] <- record(intervention, spec, m, frozen$stage2, frozen$sectors)
    }
    message("Reconciliation: ", spec)
    case <- audit_reconciliation_case(processed, rates, spec)
    stopifnot(identical(case$evidence, frozen$evidence))
    r <- audit_reconciliation_comparison(case, frozen, frozen$forward)
    posteriors[[spec]] <- mutate(r$posterior, specification = spec, .before = 1)
    recon_regressions[[spec]] <- mutate(r$fits, specification = spec, .before = 1)
    sample_changes[[spec]] <- mutate(r$sample_changes, specification = spec, .before = 1)
    sample_support[[spec]] <- mutate(r$membership, specification = spec, .before = 1)
    m <- audit_measurement(case$stage1, case$host, frozen$brackets, selected)
    runs[[paste("RECONCILIATION_ONLY", spec)]] <- record("RECONCILIATION_ONLY", spec, m,
      case$stage2, case$sectors, FALSE)
    if (run_joint && spec == "EXPLICIT_FALLBACK") {
      m <- audit_measurement(case$stage1, case$host, frozen$brackets, selected, TRUE, TRUE)
      runs[["JOINT_CANDIDATE"]] <- record("JOINT_CANDIDATE", spec, m, case$stage2, case$sectors)
    }
  }
  for (name in c("scenarios", "sources", "collectors")) {
    save(map_dfr(runs, ~ .x$fiscal[[name]]), paste0("fiscal_", name))
  }
  save(map_dfr(runs, "ordinary"), "fiscal_ordinary")
  save(map_dfr(runs, "budget"), "budget_ranges")
  save(map_dfr(runs, "measurement"), "measurement")
  save(map_dfr(runs, "fits"), "host_fits")
  save(bind_rows(posteriors), "reconciliation")
  save(bind_rows(recon_regressions), "reconciliation_regression")
  save(bind_rows(sample_changes), "reconciliation_sample_changes")
  save(bind_rows(sample_support), "reconciliation_sample_support")
  message("R09a diagnostic outputs written.")
  invisible(output)
}

if (is_direct_script_run("code/diagnostics/statutory_rate_audit.R")) {
  args <- commandArgs(trailingOnly = TRUE)
  if (!length(args) || length(args) > 2L || (length(args) == 2L && args[2L] != "--joint")) {
    stop("Usage: Rscript --vanilla code/diagnostics/statutory_rate_audit.R /absolute/new/output [--joint]")
  }
  run_statutory_rate_audit(args[1L], run_joint = "--joint" %in% args)
}
