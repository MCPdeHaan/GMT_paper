# Bilateral parent–affiliate–year estimation samples. Transformations preserve
# the original model-specific support, units and input ordering.
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "00_helpers.R"), local = TRUE)

MIN_PAIR_YEARS_FOR_FE <- 2L
SIMULATED_ETR_MEASURE <- "EATR"
SIMULATED_ETR_TAX_BASIS <- "BASELINE"
SIMULATED_ETR_SCENARIO <- "FIXED"
SIMULATED_ETR_TAX_TYPE <- "COMPOSITE"

add_affiliate_cit_lag <- function(base_panel) {
  lagged_rates <- base_panel |>
    group_by(affiliate, year) |>
    summarise(
      affiliate_cit_rate_unit_lag1 =
        first_non_missing(panel_statutory_rate(dplyr::pick(everything()), "robustness")),
      .groups = "drop"
    ) |>
    mutate(year = year + 1L)

  base_panel |>
    left_join(lagged_rates, by = c("affiliate", "year"))
}

build_simulated_tax_code_etr <- function(etr_forward) {
  etr_forward |>
    filter(
      measure == SIMULATED_ETR_MEASURE,
      asset_type == SIMULATED_ETR_TAX_BASIS,
      etr_scenario == SIMULATED_ETR_SCENARIO,
      tax_type == SIMULATED_ETR_TAX_TYPE,
      regime == "_Z"
    ) |>
    transmute(
      affiliate = jurisdiction,
      year,
      affiliate_simulated_eatr_unit = normalise_tax_rate_unit(value)
    ) |>
    group_by(affiliate, year) |>
    summarise(
      affiliate_simulated_eatr_unit =
        first_non_missing(affiliate_simulated_eatr_unit),
      .groups = "drop"
    )
}

add_affiliate_tax_instruments <- function(base_panel, etr_forward = NULL) {
  panel <- add_affiliate_cit_lag(base_panel)

  if (is.null(etr_forward)) {
    return(panel |> mutate(affiliate_simulated_eatr_unit = NA_real_))
  }

  panel |>
    left_join(
      build_simulated_tax_code_etr(etr_forward),
      by = c("affiliate", "year")
    )
}

prepare_estimation_sample <- function(base_panel,
                                      exclude_stale_wages = FALSE,
                                      balanced_pairs_only = FALSE,
                                      exclude_covid_years = FALSE,
                                      etr_forward = NULL) {
  sample <- add_affiliate_tax_instruments(base_panel, etr_forward) |>
    filter(
      year %in% MAIN_YEARS,
      has_behavioral_estimation_inputs,
      analysis_profit_base > 0,
      assets_sbie > 0,
      payroll_sbie > 0,
      affiliate_gdp_pc_usd > 0,
      affiliate_population > 0,
      !is.na(etr_panelai_reg)
    )

  if (exclude_stale_wages) {
    sample <- sample |>
      filter(!coalesce(affiliate_wage_stale_flag, FALSE))
  }

  if (exclude_covid_years) {
    sample <- sample |>
      filter(!year %in% c(2020, 2021))
  }

  sample <- sample |>
    group_by(pair_id) |>
    mutate(pair_years_in_estimation_sample = n_distinct(year)) |>
    ungroup() |>
    filter(pair_years_in_estimation_sample >= MIN_PAIR_YEARS_FOR_FE)

  if (balanced_pairs_only) {
    sample <- sample |>
      filter(pair_years_in_estimation_sample == length(MAIN_YEARS))
  }

  sample |>
    mutate(
      tau_raw = etr_panelai_reg,
      tau = winsorise(tau_raw),
      tau_sq = tau^2,
      log_profit = log(analysis_profit_base),
      log_assets = log(assets_sbie),
      log_payroll = log(payroll_sbie),
      log_gdp_pc = log(affiliate_gdp_pc_usd),
      log_population = log(affiliate_population)
    )
}

# Positive-profit WLS uses a fixed pair mean from the wider panel. The separate
# nonnegative PPML diagnostic proxies an undefined zero-profit ETR at host-year grain.
prepare_alternative_estimator_samples <- function(estimation_sample, base_panel) {
  positive <- base_panel |>
    filter(year %in% MAIN_YEARS, is.finite(analysis_profit_base), analysis_profit_base > 0)

  pair_weights <- positive |>
    group_by(pair_id) |>
    summarise(pair_mean_positive_profit = mean(analysis_profit_base), .groups = "drop")

  weighted_sample <- estimation_sample |>
    left_join(pair_weights, by = "pair_id", relationship = "many-to-one") |>
    mutate(pair_profit_weight = pair_mean_positive_profit / mean(pair_mean_positive_profit))
  stopifnot(all(is.finite(weighted_sample$pair_profit_weight)),
    all(weighted_sample$pair_profit_weight > 0)
  )

  # A cell's accrued-tax ETR is undefined at zero corrected profit. For
  # those rows only, use the affiliate-year ETR from observed positive cells.
  affiliate_year_etr <- positive |>
    group_by(affiliate, year) |>
    summarise(
      zero_profit_etr_proxy = weighted_mean_available(etr_panelai_reg, analysis_profit_base),
      .groups = "drop"
    )
  bounds <- stats::quantile(estimation_sample$tau_raw, ETR_WINSOR_PROBS, names = FALSE)
  expanded_sample <- base_panel |>
    filter(
      year %in% MAIN_YEARS, is.finite(analysis_profit_base), analysis_profit_base >= 0,
      is.finite(assets_sbie), assets_sbie > 0, is.finite(payroll_sbie), payroll_sbie > 0,
      is.finite(affiliate_gdp_pc_usd), affiliate_gdp_pc_usd > 0,
      is.finite(affiliate_population), affiliate_population > 0
    ) |>
    left_join(affiliate_year_etr, by = c("affiliate", "year"), relationship = "many-to-one") |>
    mutate(
      tau_proxy_used = analysis_profit_base == 0 & !is.finite(etr_panelai_reg),
      tau_raw = if_else(tau_proxy_used, zero_profit_etr_proxy, etr_panelai_reg)
    ) |>
    filter(is.finite(tau_raw)) |>
    mutate(
      tau = clamp_interval(tau_raw, bounds[1], bounds[2]),
      tau_sq = tau^2,
      log_assets = log(assets_sbie),
      log_payroll = log(payroll_sbie),
      log_gdp_pc = log(affiliate_gdp_pc_usd),
      log_population = log(affiliate_population)
    )

  list(
    fe_ols = list(data = estimation_sample, sample = "positive_profit", family = "gaussian"),
    fe_wls = list(data = weighted_sample, sample = "positive_profit", family = "gaussian"),
    fe_ppml_positive = list(
      data = estimation_sample, sample = "positive_profit", family = "poisson"
    ),
    fe_ppml_nonnegative = list(
      data = expanded_sample, sample = "nonnegative_profit", family = "poisson"
    )
  )
}

build_division_bias_inputs <- function(estimation, base) {
  pair_keys <- c("parent", "affiliate", "year")
  assert_unique_keys(base, pair_keys, "division-bias input")
  lagged <- base |>
    transmute(
      parent, affiliate, year = year + 1L, lagged_bounded = etr_panelai_stage1,
      log_assets_lagged = log(if_else(assets_sbie > 0, assets_sbie, NA_real_)),
      log_payroll_lagged = log(if_else(payroll_sbie > 0, payroll_sbie, NA_real_))
    )
  donors <- base |>
    filter(is.finite(analysis_profit_base), analysis_profit_base > 0,
      is.finite(tax_accrued_panelai)
    ) |>
    transmute(parent, affiliate, year, donor_profit = analysis_profit_base,
      donor_tax = tax_accrued_panelai
    )
  host_totals <- donors |>
    group_by(affiliate, year) |>
    summarise(
      total_profit = sum(donor_profit), total_tax = sum(donor_tax),
      foreign_profit = sum(donor_profit[parent != affiliate]),
      foreign_tax = sum(donor_tax[parent != affiliate]),
      foreign_parents = sum(parent != affiliate), .groups = "drop"
    )

  estimation |>
    select(all_of(pair_keys), pair_id, tau, etr_panelai_stage1, log_profit,
      analysis_profit_base, log_assets, log_payroll, log_gdp_pc, log_population,
      affiliate_cit_rate_unit, any_of("affiliate_cit_robustness_rate"), affiliate_simulated_eatr_unit
    ) |>
    left_join(lagged, by = pair_keys, relationship = "one-to-one") |>
    left_join(host_totals, by = c("affiliate", "year"), relationship = "many-to-one") |>
    left_join(donors, by = pair_keys, relationship = "one-to-one") |>
    mutate(
      own_foreign_donor = !is.na(donor_profit) & parent != affiliate,
      other_foreign_parents = foreign_parents - as.integer(own_foreign_donor),
      leaveout_profit = total_profit - coalesce_zero(donor_profit),
      leaveout_tax = total_tax - coalesce_zero(donor_tax),
      leaveout_foreign_profit = foreign_profit - if_else(own_foreign_donor, donor_profit, 0),
      leaveout_foreign_tax = foreign_tax - if_else(own_foreign_donor, donor_tax, 0),
      current_etr = tau,
      current_bounded = winsorise(etr_panelai_stage1),
      lagged_etr = winsorise(lagged_bounded),
      jackknife_etr = winsorise(clamp_unit_interval(if_else(
        other_foreign_parents >= 2 & leaveout_profit > 0,
        safe_divide(leaveout_tax, leaveout_profit), NA_real_
      ))),
      jackknife_foreign_only_etr = winsorise(clamp_unit_interval(if_else(
        other_foreign_parents >= 2 & leaveout_foreign_profit > 0,
        safe_divide(leaveout_foreign_tax, leaveout_foreign_profit), NA_real_
      ))),
      statutory_cit = panel_statutory_rate(dplyr::pick(everything()), "robustness"),
      forward_eatr = affiliate_simulated_eatr_unit
    ) |>
    left_join(
      base |>
        filter(year %in% MAIN_YEARS, is.finite(analysis_profit_base), analysis_profit_base > 0) |>
        group_by(pair_id) |>
        summarise(pair_mean_profit = mean(analysis_profit_base), .groups = "drop"),
      by = "pair_id", relationship = "many-to-one"
    ) |>
    mutate(pair_profit_weight = pair_mean_profit / mean(pair_mean_profit))
}
