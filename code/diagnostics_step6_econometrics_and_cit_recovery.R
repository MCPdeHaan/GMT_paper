# Run from the repository root on the Stage 3 and Stage 4.5 outputs.
source("code/01_data_cleaning.R")
source("code/05_stage3_behavioral_functions.R")
source("code/06_stage4_5_revenue_allocation_sbs_functions.R")
source("code/07_stage4_6_revenue_pipeline_decomposition_functions.R")

read_step6_input <- function(stem) readRDS(file.path(PROCESSED_DIR, paste0(stem, ".rds")))

write_step6_diagnostic <- function(data, stem) {
  write_csv(data, file.path(DIAGNOSTICS_DIR, paste0("step6_", stem, ".csv")))
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
      affiliate_cit_rate_unit, affiliate_simulated_eatr_unit
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
      statutory_cit = affiliate_cit_rate_unit,
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

fit_division_bias_design <- function(data, regressor, support, activity, log_t0) {
  stopifnot(all(is.finite(data[[regressor]])), min(data[[regressor]]) + log_t0 > 0)
  data <- data |>
    mutate(
      tau = .data[[regressor]], tau_sq = tau^2, log_tau = log(log_t0 + tau),
      log_assets = if (activity == "lagged") log_assets_lagged else log_assets,
      log_payroll = if (activity == "lagged") log_payroll_lagged else log_payroll
    )
  tax_terms <- list(
    linear = "tau", quadratic = c("tau", "tau_sq"), logarithmic = c("tau", "log_tau")
  )
  controls <- c("log_assets", "log_payroll", "log_gdp_pc", "log_population")
  cluster_correction <- fixest::ssc(K.fixef = "full", G.df = "conventional")

  map_dfr(c("fe_ols", "fe_wls", "fe_ppml_positive"), function(estimator) {
    used_rows <- NULL
    estimates <- imap_dfr(tax_terms, function(terms, form) {
      poisson <- estimator == "fe_ppml_positive"
      outcome <- if (poisson) "analysis_profit_base" else "log_profit"
      formula <- as.formula(paste(outcome, "~", paste(c(controls, terms), collapse = " + "),
        "| pair_id + year"
      ))
      covariance_repaired <- FALSE
      record_covariance_repair <- function(warning) {
        if (grepl("VCOV matrix is not positive definite and was 'fixed'", conditionMessage(warning), fixed = TRUE)) {
          covariance_repaired <<- TRUE
          invokeRestart("muffleWarning")
        }
      }
      fit <- withCallingHandlers(if (poisson) {
        fixest::fepois(formula, data = data, cluster = ~ parent + affiliate,
          ssc = cluster_correction, notes = FALSE, nthreads = 2
        )
      } else {
        fixest::feols(formula, data = data, cluster = ~ parent + affiliate,
          weights = if (estimator == "fe_wls") ~ pair_profit_weight else NULL,
          ssc = cluster_correction, notes = FALSE, nthreads = 2
        )
      }, warning = record_covariance_repair)
      indices <- fixest::obs(fit)
      if (is.null(used_rows)) used_rows <<- indices
      stopifnot(identical(indices, used_rows), !isFALSE(fit$convStatus))
      used <- data[indices, , drop = FALSE]
      coefs <- coef(fit)
      covariance <- vcov(fit)
      coefficient_table <- fixest::coeftable(fit)
      report_terms <- intersect(c("log_assets", "log_payroll", terms), names(coefs))
      stopifnot(all(terms %in% report_terms))
      tax_pattern <- paste0("^(", paste(terms, collapse = "|"), ")$")
      wald <- withCallingHandlers(fixest::wald(fit, keep = tax_pattern, print = FALSE),
        warning = record_covariance_repair
      )
      affiliate_cluster_p <- if (covariance_repaired) {
        fixest::wald(fit, keep = tax_pattern, vcov = ~affiliate, print = FALSE)$p
      } else {
        NA_real_
      }
      n_parents <- n_distinct(used$parent)
      n_affiliates <- n_distinct(used$affiliate)
      n_pairs <- n_distinct(used$pair_id)
      bic <- if (poisson) {
        BIC(fit)
      } else {
        weights <- if (estimator == "fe_wls") used$pair_profit_weight else rep(1, nrow(used))
        stage3_gaussian_bic(fit, weights)
      }
      semi <- semielasticity_schedule_one(
        list(coefficients = coefs, model_spec = form, t0 = log_t0, n = nrow(used),
          n_parents = n_parents, n_affiliates = n_affiliates, n_pairs = n_pairs
        ),
        c(0.05, 0.10, 0.15), inference = "parent_affiliate_two_way_clustered",
        vcov = covariance, df_inference = min(n_parents, n_affiliates) - 1L
      ) |>
        transmute(statistic_type = "semi_elasticity", term = "negative_log_profit_derivative",
          tau_eval = tau, estimate = semi_elasticity, std_error, p_value
        )
      bind_rows(
        tibble(statistic_type = "coefficient", term = report_terms, tau_eval = NA_real_,
          estimate = coefficient_table[report_terms, 1], std_error = coefficient_table[report_terms, 2],
          p_value = coefficient_table[report_terms, 4]
        ),
        semi
      ) |>
        mutate(
          regressor, sample = support, activity, estimator, model_spec = form,
          dependent_variable = outcome, n = nrow(used), n_supplied = nrow(data),
          n_pairs, n_parents, n_affiliates, start_year = min(used$year), end_year = max(used$year),
          etr_min = min(used$tau), etr_max = max(used$tau),
          n_etr_below_005 = sum(used$tau < 0.05),
          n_etr_at_or_below_010 = sum(used$tau <= 0.10),
          joint_tax_wald_f = wald$stat, joint_tax_wald_p = wald$p,
          joint_tax_wald_df1 = wald$df1, joint_tax_wald_df2 = wald$df2,
          covariance_repaired, affiliate_cluster_p_if_repaired = affiliate_cluster_p,
          bic, bic_basis = if (poisson) "poisson_pseudo_likelihood_usd" else "gaussian_log_profit",
          log_t0 = if (form == "logarithmic") log_t0 else NA_real_,
          .before = 1
        )
    })
    estimates |>
      mutate(delta_bic = bic - min(bic), bic_winner = delta_bic == 0)
  })
}

audit_division_bias <- function(estimation, base) {
  inputs <- build_division_bias_inputs(estimation, base)
  regressors <- c("current_etr", "lagged_etr", "jackknife_etr", "jackknife_foreign_only_etr",
    "statutory_cit", "forward_eatr"
  )
  archived <- read_csv(file.path(DIAGNOSTICS_DIR, "step5_stage3_alternative_estimators.csv"),
    show_col_types = FALSE
  ) |>
    filter(sample == "positive_profit")
  log_t0 <- unique(na.omit(archived$t0))
  stopifnot(length(log_t0) == 1, all(inputs$pair_profit_weight > 0))
  available <- map_dfr(regressors, function(regressor) {
    fit_division_bias_design(filter(inputs, is.finite(.data[[regressor]])),
      regressor, "available", "current", log_t0
    )
  })
  reference <- available |>
    filter(regressor == "current_etr", statistic_type == "semi_elasticity") |>
    inner_join(
      archived |> filter(statistic_type == "semi_elasticity") |>
        select(estimator, model_spec, tau_eval, archived_estimate = estimate),
      by = c("estimator", "model_spec", "tau_eval"), relationship = "one-to-one"
    )
  stopifnot(nrow(reference) == 27, max(abs(reference$estimate - reference$archived_estimate)) < 1e-8)

  matched <- map_dfr(regressors[-1], function(proxy) {
    data <- filter(inputs, is.finite(.data[[proxy]]))
    benchmark <- c("current_etr",
      if (proxy == "lagged_etr" || startsWith(proxy, "jackknife")) "current_bounded"
    )
    support <- paste0("matched_", proxy)
    stopifnot(all(is.finite(data$current_etr)), all(is.finite(data$current_bounded)))
    bind_rows(
      map_dfr(benchmark, ~ fit_division_bias_design(data, .x, support, "current", log_t0)),
      available |> filter(regressor == proxy) |> mutate(sample = support)
    )
  })

  # Replace only the two activity controls. The current-control comparison
  # uses exactly the same cells with available t-1 activity.
  lagged_activity <- map_dfr(regressors, function(regressor) {
    data <- filter(inputs, is.finite(.data[[regressor]]),
      is.finite(log_assets_lagged), is.finite(log_payroll_lagged)
    )
    map_dfr(c("current", "lagged"), function(activity) {
      fit_division_bias_design(data, regressor, "matched_lagged_activity", activity, log_t0)
    })
  })

  bind_rows(available, matched, lagged_activity)
}

build_parent_specific_reallocation <- function(panel, affiliate_year) {
  keys <- c("scenario_id", "parent", "year")
  source_rows <- panel |>
    filter(reallocated_profit > 0) |>
    mutate(source_tax_loss = reallocated_profit * clamp_interval(static_tau_low, 0, GMT_RATE))
  stopifnot(all(source_rows$factor5_behaviour == "behavioural"),
    all(source_rows$static_tau_low < GMT_RATE), all(is.finite(source_rows$source_tax_loss))
  )
  sources <- source_rows |>
    group_by(across(all_of(keys))) |>
    summarise(
      reallocated_profit = sum(reallocated_profit),
      source_tax_loss = sum(source_tax_loss),
      .groups = "drop"
    ) |>
    mutate(weighted_source_etr = source_tax_loss / reallocated_profit)

  # Destination eligibility depends on the observed footprint and tax code.
  # A loss-making destination may still employ workers and make sales.
  footprint <- panel |>
    distinct(parent, destination = affiliate, year, affiliate_cit_rate_unit,
      affiliate_is_conduit_haven, employees_sbie, payroll_sbie, upr_panelai
    ) |>
    filter(affiliate_cit_rate_unit >= GMT_RATE, !coalesce(affiliate_is_conduit_haven, FALSE)) |>
    transmute(
      parent, destination, year, statutory_rate = affiliate_cit_rate_unit,
      employees = pmax(coalesce_zero(employees_sbie), 0),
      payroll = pmax(coalesce_zero(payroll_sbie), 0),
      upr = pmax(coalesce_zero(upr_panelai), 0)
    )
  assert_unique_keys(footprint, c("parent", "destination", "year"), "destination footprint")
  parent_weights <- normalise_formulary_destinations(footprint, c("parent", "year"))
  global_weights <- footprint |>
    group_by(destination, year, statutory_rate) |>
    summarise(across(c(employees, payroll, upr), sum), .groups = "drop") |>
    normalise_formulary_destinations("year")

  support <- distinct(parent_weights, parent, year)
  within_parent <- sources |>
    semi_join(support, by = c("parent", "year")) |>
    left_join(parent_weights, by = c("parent", "year"), relationship = "many-to-many") |>
    mutate(destination_weight_source = "parent_year")
  fallback <- sources |>
    anti_join(support, by = c("parent", "year")) |>
    left_join(global_weights, by = "year", relationship = "many-to-many") |>
    mutate(destination_weight_source = "global_year_no_eligible_parent_destination")

  matrix <- bind_rows(within_parent, fallback) |>
    left_join(
      transmute(affiliate_year, destination = affiliate, year, observed_etr = avg_etr_stage1),
      by = c("destination", "year"), relationship = "many-to-one"
    ) |>
    mutate(
      reallocated_profit_received = reallocated_profit * weight,
      # The observed ETR sensitivity uses the 15% floor and falls back to
      # the observed statutory rate when the affiliate-year ETR is missing.
      effective_rate_fallback = !is.finite(observed_etr),
      effective_rate = pmax(GMT_RATE, coalesce(observed_etr, statutory_rate)),
      ordinary_cit_gross_destination_revenue = reallocated_profit_received * statutory_rate,
      ordinary_cit_gross_destination_revenue_effective = reallocated_profit_received * effective_rate,
      ordinary_cit_net_recovery = reallocated_profit_received * pmax(statutory_rate - weighted_source_etr, 0)
    )
  stopifnot(!anyNA(matrix$weight), !anyNA(matrix$destination))
  conservation <- matrix |>
    group_by(across(all_of(keys))) |>
    summarise(
      allocation_gap = sum(reallocated_profit_received) - first(reallocated_profit),
      weight_gap = sum(weight) - 1,
      .groups = "drop"
    )
  stopifnot(nrow(conservation) == nrow(sources),
    max(abs(conservation$allocation_gap)) < 1e-3, max(abs(conservation$weight_gap)) < 1e-12
  )
  message("Maximum reallocated-profit residual by parent-year-scenario (USD): ",
    format(max(abs(conservation$allocation_gap)), digits = 8)
  )
  list(matrix = matrix, source_rows = source_rows, conservation = conservation)
}

allocate_avoided_topup <- function(panel, weights, regime) {
  source <- panel |>
    filter(factor5_behaviour == "behavioural") |>
    mutate(topup_after_behaviour = if_else(behavioural_regime == regime, behavioural_avoided_topup, 0)) |>
    build_source_panel()
  allocate_stage4_revenue(source, weights)$revenue_country_year_eu27 |>
    select(country, year, scenario_id, revenue)
}

build_total_fiscal_country_year <- function(panel, direct, affiliate_year, weights,
                                           rule_b_matrix = NULL) {
  reallocation <- if (is.null(rule_b_matrix)) {
    build_parent_specific_reallocation(panel, affiliate_year)
  } else {
    list(matrix = rule_b_matrix, source_rows = panel |>
      filter(reallocated_profit > 0) |>
      mutate(source_tax_loss = reallocated_profit * static_tau_low))
  }
  routing <- reallocation$matrix
  if (is.null(rule_b_matrix)) {
    routing <- routing |>
      mutate(global_fallback_profit_received = if_else(destination_weight_source == "parent_year",
        0, reallocated_profit_received))
  } else {
    routing <- routing |>
      mutate(equal_weight_fallback = FALSE, effective_rate_fallback = FALSE)
  }
  destination <- routing |>
    filter(destination %in% EU27_ISO3) |>
    group_by(country = destination, year, scenario_id) |>
    summarise(
      across(c(reallocated_profit_received, ordinary_cit_gross_destination_revenue,
        ordinary_cit_gross_destination_revenue_effective, ordinary_cit_net_recovery), sum),
      global_fallback_profit_received = sum(global_fallback_profit_received),
      equal_weight_profit_received = sum(reallocated_profit_received[equal_weight_fallback]),
      effective_rate_fallback_profit = sum(reallocated_profit_received[effective_rate_fallback]),
      .groups = "drop"
    )
  origin <- reallocation$source_rows |>
    filter(affiliate %in% EU27_ISO3) |>
    group_by(country = affiliate, year, scenario_id) |>
    summarise(reallocated_profit_sent = sum(reallocated_profit),
      ordinary_cit_source_loss = sum(source_tax_loss), .groups = "drop"
    )
  direct_reallocation <- allocate_avoided_topup(panel, weights, "semi_elasticity_reallocation") |>
    rename(direct_topup_lost_reallocation = revenue)
  direct_bunching <- allocate_avoided_topup(panel, weights, "sesh_bunching_topup_zero") |>
    rename(direct_topup_lost_bunching = revenue)
  keys <- c("country", "year", "scenario_id")
  country_year <- direct |>
    rename(direct_topup = revenue) |>
    mutate(mechanical_scenario = paste0(substr(scenario_id, 1, 5), "0")) |>
    left_join(
      direct |> transmute(country, year, mechanical_scenario = scenario_id, mechanical_direct_topup = revenue),
      by = c("country", "year", "mechanical_scenario"), relationship = "many-to-one"
    ) |>
    left_join(direct_reallocation, by = keys, relationship = "one-to-one") |>
    left_join(direct_bunching, by = keys, relationship = "one-to-one") |>
    left_join(destination, by = keys, relationship = "one-to-one") |>
    left_join(origin, by = keys, relationship = "one-to-one") |>
    mutate(
      across(c(starts_with("direct_topup_lost_"), starts_with("reallocated_profit_"),
        starts_with("ordinary_cit_"), ends_with("_profit_received"), effective_rate_fallback_profit),
      coalesce_zero),
      direct_topup_lost_total = mechanical_direct_topup - direct_topup,
      ordinary_cit_net_by_incidence = ordinary_cit_gross_destination_revenue - ordinary_cit_source_loss,
      total_fiscal_revenue = direct_topup + ordinary_cit_gross_destination_revenue,
      total_fiscal_revenue_effective = direct_topup + ordinary_cit_gross_destination_revenue_effective,
      total_fiscal_revenue_net_by_incidence = direct_topup + ordinary_cit_net_by_incidence,
      total_fiscal_gain_vs_mechanical = total_fiscal_revenue - mechanical_direct_topup,
      total_fiscal_gain_vs_mechanical_effective = total_fiscal_revenue_effective - mechanical_direct_topup,
      total_fiscal_gain_vs_mechanical_net_by_incidence = total_fiscal_revenue_net_by_incidence - mechanical_direct_topup
    )
  stopifnot(max(abs(with(country_year, direct_topup_lost_total -
    direct_topup_lost_reallocation - direct_topup_lost_bunching))) < 1e-4)
  list(country_year = country_year, reallocation = reallocation)
}

summarise_total_fiscal_ledger <- function(country_year, reallocation) {
  matrix <- reallocation$matrix
  legacy <- "parent" %in% names(matrix)
  global <- matrix |>
    group_by(scenario_id, year) |>
    summarise(
      global_reallocated_profit = sum(reallocated_profit_received),
      global_reallocated_profit_using_fallback = if (legacy) sum(reallocated_profit_received[
        destination_weight_source != "parent_year"
      ]) else sum(global_fallback_profit_received),
      parent_year_pools = if (legacy) n_distinct(parent) else NA_integer_,
      fallback_parent_year_pools = if (legacy) {
        n_distinct(parent[destination_weight_source != "parent_year"])
      } else NA_integer_,
      .groups = "drop"
    )
  amounts <- c(
    "direct_topup", "mechanical_direct_topup", "direct_topup_lost_total",
    "direct_topup_lost_reallocation", "direct_topup_lost_bunching",
    "reallocated_profit_received", "reallocated_profit_sent",
    "ordinary_cit_gross_destination_revenue", "ordinary_cit_gross_destination_revenue_effective",
    "ordinary_cit_source_loss", "ordinary_cit_net_recovery", "ordinary_cit_net_by_incidence",
    "total_fiscal_revenue", "total_fiscal_revenue_effective", "total_fiscal_revenue_net_by_incidence",
    "total_fiscal_gain_vs_mechanical", "total_fiscal_gain_vs_mechanical_effective",
    "total_fiscal_gain_vs_mechanical_net_by_incidence", "global_fallback_profit_received",
    "equal_weight_profit_received", "effective_rate_fallback_profit"
  )
  eu <- country_year |>
    group_by(across(all_of(SCENARIO_VARS)), year) |>
    summarise(across(all_of(amounts), sum), .groups = "drop") |>
    mutate(country = "EU27", country_name = "European Union (27)") |>
    left_join(global, by = c("scenario_id", "year"), relationship = "one-to-one") |>
    mutate(across(c(global_reallocated_profit, global_reallocated_profit_using_fallback), coalesce_zero))
  annual <- bind_rows(country_year, eu)
  global_amounts <- setdiff(names(global), c("scenario_id", "year"))
  cumulative <- annual |>
    group_by(across(all_of(SCENARIO_VARS)), country, country_name) |>
    summarise(across(all_of(c(amounts, global_amounts)), sum_or_na), .groups = "drop")
  bind_rows(
    annual |> mutate(start_year = year, end_year = year, .before = 1) |> select(-year),
    cumulative |> mutate(start_year = min(MAIN_YEARS), end_year = max(MAIN_YEARS), .before = 1)
  ) |>
    select(start_year, end_year, country, country_name, all_of(SCENARIO_VARS),
      all_of(c(amounts, global_amounts))
    ) |>
    mutate(mechanical_scenario = paste0(substr(scenario_id, 1, 5), "0")) |>
    arrange(start_year, end_year, country, scenario_id)
}

decompose_total_fiscal_revenue <- function(country_year) {
  outcomes <- c("direct_topup", "total_fiscal_revenue", "total_fiscal_revenue_effective",
    "total_fiscal_revenue_net_by_incidence")
  map_dfr(c(2017L, 2019L, 2021L, 2023L), function(start) {
    map_dfr(outcomes, function(outcome) {
      input <- country_year |>
        filter(year >= start) |>
        transmute(across(all_of(SCENARIO_VARS)), country, country_name, year, revenue = .data[[outcome]])
      anova <- compute_factorial_anova(input)$pooled
      shapley <- build_shapley_factor_attribution(anova) |>
        select(effect, shapley_eta_squared)
      stopifnot(abs(sum(anova$eta_squared) - 1) < 1e-12,
        abs(sum(shapley$shapley_eta_squared) - 1) < 1e-12
      )
      totals <- build_scenario_summary(input)
      anova |>
        left_join(shapley, by = "effect", relationship = "one-to-one") |>
        mutate(
          outcome, start_year = start, end_year = max(MAIN_YEARS),
          country_years = n_distinct(input$country, input$year),
          interaction_eta_squared = sum(eta_squared[interaction_order > 1]),
          eu27_revenue_min = min(totals$eu_revenue), eu27_revenue_max = max(totals$eu_revenue),
          min_scenario = totals$scenario_id[which.min(totals$eu_revenue)],
          max_scenario = totals$scenario_id[which.max(totals$eu_revenue)],
          .before = 1
        )
    })
  })
}

read_step6_factorial_input <- function() {
  read_step6_input("stage3_factorial_pair_year") |>
    select(all_of(SCENARIO_VARS), parent, affiliate, year, affiliate_jurisdiction_name,
      parent_jurisdiction_name, affiliate_cit_rate_unit, affiliate_is_conduit_haven,
      employees_sbie, payroll_sbie, upr_panelai, static_tau_low, reallocated_profit,
      behavioural_avoided_topup, behavioural_regime, qdmtt_flag, parent_iir_utpr_flag, sbs_exempt,
      stage2_phi, assets_sbie, act_ip_panelai, act_holding_panelai, act_igf_panelai,
      analysis_profit_positive, average_low_share, stage1_distributional_low_share,
      stage2_excess_lowtax_profit_average, stage2_excess_lowtax_profit_distributional,
      stage1_lowtax_profit_average, stage1_lowtax_profit_distributional,
      static_beta_applied, static_behavioural_regime, topup_after_stage2, topup_after_behaviour
    )
}

read_step6_utpr_weights <- function() {
  list(
    parent_year_weights = read_step6_input("stage4_5_utpr_parent_year_weights"),
    fallback_weights = read_step6_input("stage4_5_utpr_fallback_weights")
  )
}

run_fiscal_recovery_audit <- function(panel, direct, weights) {
  output <- build_total_fiscal_country_year(panel, direct, read_step6_input("stage1_affiliate_year"), weights)
  ledger <- summarise_total_fiscal_ledger(output$country_year, output$reallocation)
  stopifnot(nrow(ledger) == (length(MAIN_YEARS) + 1) * 28 * 32,
    all(ledger$ordinary_cit_gross_destination_revenue[ledger$x5_behaviour == 0] == 0),
    all(ledger$ordinary_cit_gross_destination_revenue >= 0)
  )
  write_step6_diagnostic(ledger, "topup_vs_cit_recovery_eu27")
  write_step6_diagnostic(decompose_total_fiscal_revenue(output$country_year), "anova_total_fiscal_revenue")
  rule_b_matrix <- read_step6_input("stage3_reallocation_matrix")
  if ("reallocated_profit_received_rule_a" %in% names(rule_b_matrix)) {
    rule_b <- build_total_fiscal_country_year(panel, direct, read_step6_input("stage1_affiliate_year"),
      weights, rule_b_matrix)
    rule_b_ledger <- summarise_total_fiscal_ledger(rule_b$country_year, rule_b$reallocation)
    stopifnot(nrow(rule_b_ledger) == nrow(ledger),
      all(rule_b_ledger$ordinary_cit_gross_destination_revenue[rule_b_ledger$x5_behaviour == 0] == 0))
    write_step6_diagnostic(rule_b_ledger, "topup_vs_cit_recovery_rule_b_eu27")
    write_step6_diagnostic(decompose_total_fiscal_revenue(rule_b$country_year),
      "anova_total_fiscal_revenue_rule_b")
  }
}

build_eurostat_oecd_comparison <- function(eurostat, cit_revenue) {
  oecd <- cit_revenue |>
    filter(jurisdiction %in% setdiff(EU27_ISO3, "CYP"), year %in% CORE_YEARS,
      measure == "TAX_REV", sector == "S13", revenue_classification == "T_1200", unit == "USD"
    ) |>
    transmute(jurisdiction, year, oecd_t1200_usd_billions = value)
  precision <- read_csv(
    file.path(RAW_DIR, "oecd_cts_additional", "oecd_cit_revenue_gdp.csv"),
    col_select = c(REF_AREA, TIME_PERIOD, MEASURE, SECTOR, STANDARD_REVENUE, UNIT_MEASURE,
      UNIT_MULT, DECIMALS
    ),
    show_col_types = FALSE
  ) |>
    filter(REF_AREA %in% setdiff(EU27_ISO3, "CYP"), TIME_PERIOD %in% CORE_YEARS,
      MEASURE == "TAX_REV", SECTOR == "S13", STANDARD_REVENUE == "T_1200", UNIT_MEASURE == "USD"
    ) |>
    transmute(jurisdiction = REF_AREA, year = as.integer(TIME_PERIOD),
      oecd_rounding_half_unit_usd_billions = 0.5 * 10^(UNIT_MULT - DECIMALS - 9)
    )
  assert_unique_keys(oecd, c("jurisdiction", "year"), "OECD comparator")
  assert_unique_keys(precision, c("jurisdiction", "year"), "OECD rounding metadata")

  crossing(jurisdiction = EU27_ISO3, year = CORE_YEARS, eurostat_tax_code = c("D51B", "D51B_C2")) |>
    left_join(eurostat, by = c("jurisdiction", "year", "eurostat_tax_code"), relationship = "one-to-one") |>
    left_join(oecd, by = c("jurisdiction", "year"), relationship = "many-to-one") |>
    left_join(precision, by = c("jurisdiction", "year"), relationship = "many-to-one") |>
    mutate(
      eurostat_usd_billions = usd_billions,
      difference_usd_billions = eurostat_usd_billions - oecd_t1200_usd_billions,
      difference_pct_oecd = 100 * safe_divide(difference_usd_billions, oecd_t1200_usd_billions),
      # Eurostat's published values in this extract are rounded to EUR 0.1m.
      rounding_tolerance_usd_billions = 0.05 * usd_per_eur / 1000 + oecd_rounding_half_unit_usd_billions,
      within_source_rounding = abs(difference_usd_billions) <= rounding_tolerance_usd_billions
    ) |>
    select(-usd_billions)
}

build_cyprus_denominator_audit <- function(eurostat, panel, direct, weights) {
  preferred_ids <- c("x10001", "x10011")
  cyprus <- eurostat |>
    filter(jurisdiction == "CYP") |>
    select(year, eurostat_tax_code, eur_millions, usd_billions, usd_per_eur, eurostat_last_update) |>
    pivot_wider(names_from = eurostat_tax_code, values_from = c(eur_millions, usd_billions))
  stopifnot(setequal(cyprus$year, CORE_YEARS), all(cyprus$eur_millions_D51B_C2 == cyprus$eur_millions_D51B),
    all(cyprus$eur_millions_D51C2 == 0)
  )
  preferred_source <- panel |> filter(scenario_id %in% preferred_ids)
  generated <- preferred_source |>
    filter(affiliate == "CYP") |>
    group_by(scenario_id, year) |>
    summarise(source_liability = sum(topup_after_behaviour), .groups = "drop")

  # Reproduce the Step 5 R2 policy change annually. The UTPR collector set
  # and its weights are held fixed, as in that sensitivity.
  cyprus_active_source <- preferred_source |>
    mutate(qdmtt_flag = qdmtt_flag | affiliate == "CYP",
      parent_iir_utpr_flag = parent_iir_utpr_flag | parent == "CYP"
    ) |>
    add_behavioural_response() |>
    build_source_panel()
  allocation <- allocate_stage4_revenue(cyprus_active_source, weights)
  build_conservation_diagnostics(cyprus_active_source, allocation$revenue_by_channel_global)
  active <- allocation$revenue_country_year_eu27 |>
    filter(country == "CYP") |>
    select(scenario_id, year, r2_cyprus_active_revenue = revenue)
  step5 <- read_csv(file.path(DIAGNOSTICS_DIR, "step7_cyprus_and_article50_sensitivity.csv"),
    show_col_types = FALSE
  ) |>
    filter(country == "CYP", regime == "R2_cyprus_domestic_law")
  check <- active |>
    group_by(scenario_id) |>
    summarise(full = sum(r2_cyprus_active_revenue),
      last = r2_cyprus_active_revenue[year == max(MAIN_YEARS)], .groups = "drop"
    ) |>
    pivot_longer(c(full, last), names_to = "window", values_to = "calculated") |>
    mutate(start_year = if_else(window == "full", min(MAIN_YEARS), max(MAIN_YEARS))) |>
    inner_join(select(step5, scenario_id, start_year, collector_revenue),
      by = c("scenario_id", "start_year"), relationship = "one-to-one"
    )
  stopifnot(nrow(check) == 4, max(abs(check$calculated - check$collector_revenue)) < 1e-4)
  preferred <- direct |>
    filter(country == "CYP", scenario_id %in% preferred_ids) |>
    select(scenario_id, year, preferred_revenue = revenue)
  cyprus |>
    left_join(preferred, by = "year", relationship = "one-to-many") |>
    left_join(generated, by = c("scenario_id", "year"), relationship = "one-to-one") |>
    left_join(active, by = c("scenario_id", "year"), relationship = "one-to-one") |>
    mutate(
      jurisdiction = "CYP", eurostat_dataset = "gov_10a_taxag", eurostat_sector = "S13",
      denominator_tax_code = "D51B_C2", exchange_rate_series = "ECB EXR.A.USD.EUR.SP00.A",
      cit_revenue_T_1200_usd_billions = usd_billions_D51B_C2,
      preferred_revenue_pct_of_cit = 100 * preferred_revenue / (cit_revenue_T_1200_usd_billions * 1e9),
      source_liability_pct_of_cit = 100 * source_liability / (cit_revenue_T_1200_usd_billions * 1e9),
      r2_cyprus_active_revenue_pct_of_cit = 100 * r2_cyprus_active_revenue / (cit_revenue_T_1200_usd_billions * 1e9)
    ) |>
    relocate(jurisdiction, year, scenario_id, cit_revenue_T_1200_usd_billions)
}

run_step6_econometrics_and_cit_recovery <- function() {
  message("Estimating matched division-bias and activity-control models")
  estimates <- audit_division_bias(read_step6_input("stage3_estimation_sample"), read_step6_input("base_panel"))
  write_step6_diagnostic(estimates, "division_bias_and_curvature_audit")

  message("Reconciling parent-specific CIT recovery with direct top-up")
  panel <- read_step6_factorial_input()
  direct <- read_step6_input("stage4_5_revenue_country_year")
  weights <- read_step6_utpr_weights()
  run_fiscal_recovery_audit(panel, direct, weights)

  message("Verifying Cyprus CIT receipts and the Eurostat–OECD crosswalk")
  eurostat <- read_eurostat_corporate_tax()
  cyprus <- build_cyprus_denominator_audit(eurostat, panel, direct, weights)
  stopifnot(nrow(cyprus) == 1 + 2 * length(MAIN_YEARS))
  write_step6_diagnostic(cyprus, "cyprus_cit_denominator")
  write_step6_diagnostic(
    build_eurostat_oecd_comparison(eurostat, read_step6_input("cit_revenue")),
    "eurostat_oecd_cit_comparison"
  )
}

if (is_direct_script_run("code/diagnostics_step6_econometrics_and_cit_recovery.R")) {
  run_step6_econometrics_and_cit_recovery()
}
