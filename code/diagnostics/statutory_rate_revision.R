# Paired R09b sensitivities on a verified R06b processed directory.
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "diagnostics",
  "statutory_rate_audit.R"), local = TRUE)

compare_reconciliation_priors <- function(panel, legacy, standard, evidence) {
  arms <- list(
    legacy = list(legacy, "historical_encoding"),
    combined = list(mutate(standard, cit_reconciliation_prior_rate = cit_statistical_rate),
      "historical_encoding"),
    central = list(mutate(standard, cit_reconciliation_prior_rate = cit_standard_central),
      "historical_encoding"),
    omitted = list(legacy, "omit"),
    mean_imputed = list(mutate(standard, cit_reconciliation_prior_rate = cit_statistical_rate),
      "mean_imputed")
  )
  cases <- map(arms, function(arm) {
    targets <- build_parent_year_targets(panel, arm[[1]])
    prior <- fit_prior_reconciliation_model(evidence, targets, arm[[2]])$target_prior
    estimates <- combine_parent_year_evidence(prior, evidence) |>
      select(parent, year, rho_hat_pt, posterior_sd, rho_lo_pt, rho_hi_pt, support_class, main_source) |>
      left_join(select(prior, parent, year, prior_rho, prior_se_y, encoded_rate = parent_cit_rate_unit),
        by = c("parent", "year"), relationship = "one-to-one") |>
      left_join(select(targets, parent, year, observed_covariate = parent_cit_rate_unit),
        by = c("parent", "year"), relationship = "one-to-one")
    list(estimates = estimates, holdout = build_holdout_validation(evidence, targets, arm[[2]]))
  })
  holdout <- bind_rows(map(cases, "holdout"), .id = "arm")
  estimates <- bind_rows(map(cases, "estimates"), .id = "arm")
  stopifnot(all(estimates$prior_se_y > 0))
  evidence_keys <- c("parent", "year", "support_class", "main_source")
  support <- estimates |> select(all_of(evidence_keys), arm)
  stopifnot(nrow(distinct(support, across(all_of(evidence_keys)))) == sum(support$arm == "legacy"))
  list(prior_estimates = estimates, prior_holdout = holdout,
    prior_holdout_summary = summarise(holdout, n = n(), mae = mean(abs_error),
      rmse = sqrt(mean(error^2)), profit_mae = weighted_mean_clean(abs_error, profit_weight),
      .by = arm))
}

run_statutory_rate_revision_diagnostics <- function(processed, output) {
  stopifnot(!file.exists(output), !file.exists(file.path(processed, "cit_statutory_observations.rds")))
  dir.create(output)
  read <- function(name) readRDS(file.path(processed, paste0(name, ".rds")))
  save <- function(x, name) write_csv(x, file.path(output, paste0(name, ".csv")))
  raw_path <- file.path(GMT_PROJECT_ROOT, "data", "raw", "oecd_tax_rates", "oecd_statutory_cit_rates.csv")
  raw <- read_csv(raw_path, show_col_types = FALSE)
  series <- audit_rate_series(raw)
  rates <- audit_rate_lookup(series, select(read("base_panel"), all_of(AUDIT_RATE_KEYS)))
  validation <- audit_validation(processed, rates, compare_allowances = TRUE)
  save(validation$summary, "cap_validation_summary")
  save(validation$rows, "cap_validation_pairs")
  groups <- validation$rows |>
    mutate(rate_group = case_when(is.na(selected_rate) ~ "missing",
      selected_rate < GMT_RATE ~ "below_15pct", TRUE ~ "at_least_15pct")) |>
    summarise(n = n(), hosts = n_distinct(affiliate),
      share_mae = mean(abs(low_share_error), na.rm = TRUE),
      liability_rate_mae = mean(abs(liability_error), na.rm = TRUE),
      rank_conflicts = sum(rank_conflict, na.rm = TRUE),
      rank_conflict_profit = sum(analysis_profit_base[rank_conflict %in% TRUE]),
      .by = c(specification, sample, observation_group, rate_group, affiliate_is_eu27))
  save(groups, "cap_validation_subgroups")
  panel <- read("cbcr_table1") |>
    filter(year %in% CORE_YEARS, !affiliate %in% AGGREGATE_AFFILIATES_RECON) |>
    mutate(parent = normalize_code(parent), affiliate = normalize_code(affiliate))
  legacy <- read("cit_statutory") |> mutate(jurisdiction = normalize_code(jurisdiction))
  standard <- left_join(legacy,
    statutory_rate_panel(read_statutory_rate_observations(raw, tools::sha256sum(raw_path))),
    by = c("jurisdiction", "year"), relationship = "one-to-one")
  iwalk(compare_reconciliation_priors(panel, legacy, standard, read("profit_correction_evidence")), save)

  frozen <- audit_frozen_inputs(processed)
  selected <- audit_select_rate(rates, "EXPLICIT_FALLBACK")
  measurement <- audit_measurement(frozen$stage1, frozen$host, frozen$brackets, selected,
    mean_clip = TRUE, percentile_cap = TRUE)
  fiscal <- audit_core_fiscal(measurement, frozen$stage2, frozen$sectors, frozen)
  save(audit_fiscal_tables(fiscal)$scenarios, "cap_and_mean_scenarios")
  rm(fiscal, measurement)

  # Repeat the R09a joint candidate with the same direct evidence and archived
  # behavioural schedule. The combined-rate reconciliation prior is a sensitivity.
  reconcile <- audit_reconciliation_case(processed, rates, "EXPLICIT_FALLBACK")
  stopifnot(identical(reconcile$evidence, frozen$evidence))
  for (joint in c(FALSE, TRUE)) {
    measurement <- audit_measurement(reconcile$stage1, reconcile$host, frozen$brackets,
      selected, mean_clip = joint, percentile_cap = joint)
    fiscal <- audit_core_fiscal(measurement, reconcile$stage2, reconcile$sectors, frozen,
      replace_rates = joint)
    save(audit_fiscal_tables(fiscal)$scenarios,
      if (joint) "joint_r09a_scenarios" else "prior_only_scenarios")
  }
  invisible(output)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 2L) {
    stop("Usage: Rscript code/diagnostics/statutory_rate_revision.R R06b-processed new-output")
  }
  run_statutory_rate_revision_diagnostics(args[[1]], args[[2]])
}
