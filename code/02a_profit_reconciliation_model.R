# 02a_profit_reconciliation_model.R
#
# Builds an parent-year profit reconciliation model before Stage 1.
# The object is a denominator measurement correction: public CbCR adjusted
# profit is used where observed, external anchors enter as higher-precision
# evidence, and the public domestic-versus-foreign ETR comparison is retained
# as a noisy diagnostic signal.

source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "00_helpers.R"), local = TRUE)

MIN_PARITY_FOREIGN_PROFIT <- 1e9
MIN_PARITY_DOMESTIC_PROFIT <- 1e7

AGGREGATE_AFFILIATES_RECON <- c(
  "A", "A_O", "E", "E_O", "F", "F_O", "S", "S_O", "W", "W_O", "WXD",
  "STLS"
)

INVESTMENT_HUBS_RECON <- c(
  "AIA", "BHS", "GGY", "BRB", "BMU", "VGB", "CYM", "CUW", "CYP", "GIB",
  "HKG", "HUN", "IRL", "IMN", "JEY", "LBR", "LUX", "MLT", "MHL", "MUS",
  "NLD", "PRI", "SGP", "CHE"
)

CONDUIT_HAVENS_RECON <- c(
  "BMU", "CYM", "IRL", "LUX", "NLD", "CHE", "SGP", "HKG", "PRI", "GBR",
  "IMN", "MUS", "BHR", "ARE"
)

ZERO_TAX_OR_LOW_TAX_RECON <- c(
  "BHS", "BHR", "BMU", "CYM", "GGY", "IMN", "JEY", "VGB", "ARE", "MUS"
)

profit_reconciliation_source_precision <- function(signal_type) {
  case_when(
    signal_type == "observed_adjusted_profit" ~ 0.045,
    signal_type == "observed_adjusted_profit_parent" ~ 0.075,
    signal_type == "macro_reconciliation" ~ 0.060,
    signal_type == "official_country_note" ~ 0.100,
    signal_type == "public_etr_parity" ~ 0.220,
    signal_type == "fallback_prior" ~ 0.160,
    TRUE ~ 0.200
  )
}

build_parent_year_targets <- function(panel, cit_statutory) {
  domestic <- panel |>
    filter(parent == affiliate, profit_panelai > 0) |>
    group_by(parent, year) |>
    summarise(
      domestic_profit_mass = sum(profit_panelai, na.rm = TRUE),
      domestic_tax_mass = sum(tax_accrued_panelai, na.rm = TRUE),
      domestic_assets_mass = sum(assets_panelai, na.rm = TRUE),
      domestic_employee_mass = sum(employees_panelai, na.rm = TRUE),
      domestic_entities = sum(entities_count_panelai, na.rm = TRUE),
      holding_entities = sum(act_holding_panelai, na.rm = TRUE),
      domestic_holding_share = safe_divide(holding_entities, domestic_entities),
      domestic_asset_intensity =
        safe_divide(domestic_assets_mass, domestic_profit_mass),
      domestic_employee_intensity =
        safe_divide(domestic_employee_mass, domestic_profit_mass),
      .groups = "drop"
    )

  target <- panel |>
    distinct(parent, year) |>
    left_join(domestic, by = c("parent", "year")) |>
    left_join(
      cit_statutory |>
        select(
          parent = jurisdiction, year,
          parent_cit_standard = cit_standard,
          parent_cit_top_all = cit_top_all, any_of("cit_reconciliation_prior_rate")
        ),
      by = c("parent", "year")
    )

  large_parents <- target |>
    filter(year %in% MAIN_YEARS) |>
    group_by(parent) |>
    summarise(
      total_domestic_profit = sum(domestic_profit_mass, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(desc(total_domestic_profit)) |>
    slice_head(n = 12) |>
    pull(parent)

  target |>
    mutate(
      parent_is_investment_hub = parent %in% INVESTMENT_HUBS_RECON,
      parent_is_conduit_haven = parent %in% CONDUIT_HAVENS_RECON,
      parent_is_zero_tax_or_low_tax = parent %in% ZERO_TAX_OR_LOW_TAX_RECON,
      parent_is_large_upe = parent %in% large_parents,
      parent_group = case_when(
        parent_is_large_upe ~ "large_upe",
        parent_is_investment_hub ~ "investment_hub",
        parent_is_zero_tax_or_low_tax ~ "zero_tax_or_low_tax",
        TRUE ~ "residual"
      ),
      parent_cit_rate_unit = if ("cit_reconciliation_prior_rate" %in% names(target)) {
        cit_reconciliation_prior_rate
      } else coalesce(parent_cit_top_all, parent_cit_standard) / 100,
      domestic_holding_share = coalesce(domestic_holding_share, 0),
      log_domestic_profit = safe_log1p_scale(domestic_profit_mass, 1e9),
      log_domestic_assets = safe_log1p_scale(domestic_assets_mass, 1e9),
      log_domestic_employees = safe_log1p_scale(domestic_employee_mass, 1000),
      year_factor = factor(year, levels = sort(unique(panel$year))),
      parent_group = factor(
        parent_group,
        levels = c(
          "large_upe", "investment_hub", "zero_tax_or_low_tax",
          "residual"
        )
      )
    )
}

build_adjusted_profit_signal <- function(panel) {
  adjusted_cells <- panel |>
    filter(
      year %in% CORE_YEARS,
      profit_panelai > 0,
      !is.na(profit_adj_panelai)
    ) |>
    mutate(
      is_domestic = parent == affiliate,
      rho_cell_raw = 1 - safe_divide(profit_adj_panelai, profit_panelai),
      rho_cell = clamp_interval(rho_cell_raw, 0, PROFIT_RECONCILIATION_UPPER_BOUND),
      adjusted_above_reported_flag = rho_cell_raw < 0
    )

  parent_year <- adjusted_cells |>
    filter(is_domestic) |>
    group_by(parent, year) |>
    summarise(
      rho_signal_raw = 1 - safe_divide(
        sum(profit_adj_panelai, na.rm = TRUE),
        sum(profit_panelai, na.rm = TRUE)
      ),
      rho_signal = clamp_interval(
        rho_signal_raw, 0,
        PROFIT_RECONCILIATION_UPPER_BOUND
      ),
      profit_weight = sum(profit_panelai, na.rm = TRUE),
      cells = n(),
      adjusted_above_reported_cells =
        sum(adjusted_above_reported_flag, na.rm = TRUE),
      support_score = clamp_interval(
        log1p(profit_weight / 1e9) / log1p(100),
        0.35, 1
      ),
      signal_type = "observed_adjusted_profit",
      source = "OECD adjusted profit, domestic parent-year cell",
      source_citation_key = "oecd2025a",
      scope = "domestic_parent_year_adjusted_profit",
      notes = "Computed as one minus aggregate adjusted profit over reported profit for domestic cells with observed OECD adjusted profit.",
      .groups = "drop"
    )

  parent_overall <- adjusted_cells |>
    filter(is_domestic) |>
    group_by(parent) |>
    summarise(
      rho_signal_raw = 1 - safe_divide(
        sum(profit_adj_panelai, na.rm = TRUE),
        sum(profit_panelai, na.rm = TRUE)
      ),
      rho_signal = clamp_interval(
        rho_signal_raw, 0,
        PROFIT_RECONCILIATION_UPPER_BOUND
      ),
      profit_weight = sum(profit_panelai, na.rm = TRUE),
      cells = n(),
      years = n_distinct(year),
      adjusted_above_reported_cells =
        sum(adjusted_above_reported_flag, na.rm = TRUE),
      support_score = clamp_interval(
        log1p(profit_weight / 1e9) / log1p(100),
        0.25, 0.85
      ),
      .groups = "drop"
    )

  list(
    adjusted_cells = adjusted_cells,
    parent_year = parent_year,
    parent_overall = parent_overall
  )
}

build_etr_parity_signal <- function(panel, cit_statutory) {
  positive_tax_panel <- panel |>
    filter(
      year %in% CORE_YEARS,
      profit_panelai > 0,
      !is.na(tax_accrued_panelai),
      tax_accrued_panelai >= 0
    ) |>
    mutate(is_domestic = parent == affiliate)

  domestic <- positive_tax_panel |>
    filter(is_domestic) |>
    transmute(
      jurisdiction = affiliate,
      year,
      parent,
      domestic_profit = profit_panelai,
      domestic_tax = tax_accrued_panelai,
      domestic_assets = assets_panelai,
      domestic_employees = employees_panelai,
      domestic_etr = safe_divide(domestic_tax, domestic_profit),
      domestic_asset_intensity = safe_divide(domestic_assets, domestic_profit),
      domestic_employee_intensity =
        safe_divide(domestic_employees, domestic_profit)
    )

  foreign <- positive_tax_panel |>
    filter(!is_domestic) |>
    group_by(affiliate, year) |>
    summarise(
      foreign_profit = sum(profit_panelai, na.rm = TRUE),
      foreign_tax = sum(tax_accrued_panelai, na.rm = TRUE),
      foreign_assets = sum(assets_panelai, na.rm = TRUE),
      foreign_employees = sum(employees_panelai, na.rm = TRUE),
      foreign_parents = n_distinct(parent),
      foreign_cells = n(),
      foreign_etr = safe_divide(foreign_tax, foreign_profit),
      foreign_asset_intensity = safe_divide(foreign_assets, foreign_profit),
      foreign_employee_intensity =
        safe_divide(foreign_employees, foreign_profit),
      .groups = "drop"
    ) |>
    rename(jurisdiction = affiliate)

  domestic |>
    left_join(foreign, by = c("jurisdiction", "year")) |>
    left_join(
      cit_statutory |>
        transmute(
          jurisdiction,
          year,
          statutory_rate = if ("cit_reconciliation_prior_rate" %in% names(cit_statutory)) {
            cit_reconciliation_prior_rate
          } else coalesce(cit_top_all, cit_standard) / 100
        ),
      by = c("jurisdiction", "year")
    ) |>
    filter(
      is.finite(domestic_etr),
      is.finite(foreign_etr),
      domestic_profit >= MIN_PARITY_DOMESTIC_PROFIT,
      foreign_profit >= MIN_PARITY_FOREIGN_PROFIT,
      foreign_etr > 0,
      foreign_parents >= 3
    ) |>
    mutate(
      implied_correction_rate_raw = 1 - domestic_etr / foreign_etr,
      rho_signal = clamp_interval(
        implied_correction_rate_raw, 0,
        PUBLIC_ETR_PARITY_CAP
      ),
      implied_reduction = rho_signal * domestic_profit,
      asset_intensity_gap = abs(log(
        pmax(domestic_asset_intensity, 1e-12) /
          pmax(foreign_asset_intensity, 1e-12)
      )),
      employee_intensity_gap = abs(log(
        pmax(domestic_employee_intensity, 1e-12) /
          pmax(foreign_employee_intensity, 1e-12)
      )),
      parent_support_score = clamp_interval(foreign_parents / 12, 0, 1),
      foreign_mass_score =
        clamp_interval(log1p(foreign_profit / 1e9) / log1p(100), 0, 1),
      domestic_mass_score =
        clamp_interval(log1p(domestic_profit / 1e9) / log1p(100), 0, 1),
      intensity_similarity_score =
        exp(-0.15 * coalesce(asset_intensity_gap, 0) -
          0.15 * coalesce(employee_intensity_gap, 0)),
      support_score = clamp_interval(
        0.15 + 0.30 * parent_support_score +
          0.20 * foreign_mass_score +
          0.20 * domestic_mass_score +
          0.15 * intensity_similarity_score,
        0.10,
        1
      ),
      source_se = 0.45 / sqrt(support_score),
      signal_type = "public_etr_parity",
      source = "Public CbCR domestic-versus-foreign ETR parity diagnostic",
      source_citation_key = "hugger2026",
      scope = "domestic_parent_year_public_etr_parity",
      notes = "Noisy public signal, capped at the Hugger et al. ETR-comparison ceiling and filtered for foreign-parent support."
    ) |>
    transmute(
      parent,
      year,
      jurisdiction,
      rho_signal,
      signal_type,
      source,
      source_citation_key,
      profit_weight = domestic_profit,
      source_se,
      support_score,
      scope,
      notes,
      domestic_profit,
      domestic_tax,
      domestic_etr,
      foreign_profit,
      foreign_tax,
      foreign_etr,
      foreign_parents,
      foreign_cells,
      asset_intensity_gap,
      employee_intensity_gap,
      statutory_rate,
      affiliate_is_investment_hub = jurisdiction %in% INVESTMENT_HUBS_RECON,
      affiliate_is_conduit_haven = jurisdiction %in% CONDUIT_HAVENS_RECON,
      implied_correction_rate_raw
    )
}

expand_manual_anchor_signals <- function(anchors, targets) {
  anchors_model <- anchors |>
    filter(applies_to %in% c("domestic_upe_signal", "global_prior")) |>
    mutate(parent = normalize_code(parent))

  country_anchors <- anchors_model |>
    filter(parent != "ALL") |>
    select(
      parent, year_start, year_end, rho, rho_se, source_type,
      source_citation_key, scope, applies_to, notes
    )

  country_signals <- targets |>
    select(parent, year, domestic_profit_mass) |>
    inner_join(country_anchors, by = "parent", relationship = "many-to-many") |>
    filter(year >= year_start, year <= year_end) |>
    transmute(
      parent,
      year,
      rho_signal = clamp_interval(
        rho, 0,
        PROFIT_RECONCILIATION_UPPER_BOUND
      ),
      signal_type = source_type,
      source = paste0(source_type, ": ", source_citation_key),
      source_citation_key,
      profit_weight = coalesce(domestic_profit_mass, 0),
      source_se = rho_se,
      support_score = case_when(
        source_type == "macro_reconciliation" ~ 1,
        source_type == "official_country_note" ~ 0.80,
        TRUE ~ 0.60
      ),
      scope,
      notes
    )

  fallback_anchors <- anchors_model |>
    filter(parent == "ALL") |>
    select(
      year_start, year_end, rho, rho_se, source_type,
      source_citation_key, scope, applies_to, notes
    )

  fallback_signals <- targets |>
    select(parent, year, domestic_profit_mass) |>
    crossing(fallback_anchors) |>
    filter(year >= year_start, year <= year_end) |>
    transmute(
      parent,
      year,
      rho_signal = clamp_interval(
        rho, 0,
        PROFIT_RECONCILIATION_UPPER_BOUND
      ),
      signal_type = source_type,
      source = paste0(source_type, ": ", source_citation_key),
      source_citation_key,
      profit_weight = coalesce(domestic_profit_mass, 0),
      source_se = rho_se,
      support_score = 0.45,
      scope,
      notes
    )

  bind_rows(country_signals, fallback_signals)
}

fit_prior_reconciliation_model <- function(evidence, targets,
  covariate = c("historical_encoding", "mean_imputed", "omit")) {
  covariate <- match.arg(covariate)
  model_data <- evidence |>
    filter(signal_type != "public_etr_parity") |>
    left_join(
      targets |>
        select(
          parent, year, parent_group, year_factor, parent_is_investment_hub,
          parent_is_conduit_haven, parent_is_zero_tax_or_low_tax,
          parent_is_large_upe, log_domestic_profit, log_domestic_assets,
          log_domestic_employees, domestic_holding_share, parent_cit_rate_unit
        ),
      by = c("parent", "year")
    ) |>
    mutate(
      signal_upper_bound = PROFIT_RECONCILIATION_UPPER_BOUND,
      y_signal = bounded_logit(rho_signal, signal_upper_bound),
      source_se = coalesce(
        source_se,
        profit_reconciliation_source_precision(signal_type)
      ),
      logit_se = rho_to_logit_se(rho_signal, source_se, signal_upper_bound),
      logit_weight = 1 / (logit_se^2),
      parent_group = factor(
        parent_group,
        levels = levels(targets$parent_group)
      ),
      year_factor = factor(year, levels = levels(targets$year_factor)),
      log_domestic_profit = coalesce(log_domestic_profit, 0),
      log_domestic_assets = coalesce(log_domestic_assets, 0),
      log_domestic_employees = coalesce(log_domestic_employees, 0),
      domestic_holding_share = coalesce(domestic_holding_share, 0)
    ) |>
    filter(is.finite(y_signal), is.finite(logit_weight), logit_weight > 0)

  replacement <- if (covariate == "mean_imputed") {
    weighted_mean_clean(model_data$parent_cit_rate_unit, model_data$logit_weight)
  } else 0
  model_data$parent_cit_rate_unit <- coalesce(model_data$parent_cit_rate_unit, replacement)
  model_formula <- y_signal ~ parent_group + year_factor + log_domestic_profit +
    log_domestic_assets + log_domestic_employees + domestic_holding_share +
    parent_cit_rate_unit
  if (covariate == "omit") model_formula <- stats::update(model_formula, . ~ . - parent_cit_rate_unit)
  fit <- stats::lm(model_formula, data = model_data, weights = logit_weight)

  target_data <- targets |>
    mutate(
      parent_group = factor(parent_group, levels = levels(model_data$parent_group)),
      year_factor = factor(year, levels = levels(model_data$year_factor)),
      log_domestic_profit = coalesce(log_domestic_profit, 0),
      log_domestic_assets = coalesce(log_domestic_assets, 0),
      log_domestic_employees = coalesce(log_domestic_employees, 0),
      domestic_holding_share = coalesce(domestic_holding_share, 0)
    )

  target_data$parent_cit_rate_unit <- coalesce(target_data$parent_cit_rate_unit, replacement)
  prior_y <- as.numeric(stats::predict(fit, newdata = target_data))
  residual_sigma <- sqrt(weighted.mean(stats::residuals(fit)^2,
    model_data$logit_weight,
    na.rm = TRUE
  ))
  if (!is.finite(residual_sigma) || residual_sigma <= 0) {
    residual_sigma <- 0.75
  }

  list(
    fit = fit,
    model_data = model_data,
    target_prior = target_data |>
      mutate(
        prior_y = prior_y,
        prior_rho = inverse_bounded_logit(prior_y),
        prior_se_y = clamp_interval(residual_sigma, 0.80, 1.50)
      ),
    residual_sigma = residual_sigma
  )
}

combine_parent_year_evidence <- function(prior, evidence) {
  exact_evidence <- evidence |>
    filter(signal_type != "fallback_prior") |>
    mutate(
      y_signal = bounded_logit(rho_signal),
      source_se = coalesce(
        source_se,
        profit_reconciliation_source_precision(signal_type)
      ),
      logit_se = rho_to_logit_se(rho_signal, source_se),
      logit_weight = 1 / (logit_se^2),
      source_priority = case_when(
        signal_type == "observed_adjusted_profit" ~ 1L,
        signal_type == "macro_reconciliation" ~ 2L,
        signal_type == "official_country_note" ~ 3L,
        signal_type == "observed_adjusted_profit_parent" ~ 4L,
        signal_type == "public_etr_parity" ~ 5L,
        TRUE ~ 9L
      )
    ) |>
    filter(is.finite(y_signal), is.finite(logit_weight), logit_weight > 0)

  prior_rows <- prior |>
    transmute(
      parent,
      year,
      y_signal = prior_y,
      logit_weight = 1 / (prior_se_y^2),
      signal_type = "fallback_prior",
      source = "partial-pooling prior",
      source_priority = 8L
    )

  combined <- bind_rows(
    prior_rows,
    exact_evidence |>
      select(
        parent, year, y_signal, logit_weight, signal_type, source,
        source_priority
      )
  ) |>
    group_by(parent, year) |>
    summarise(
      posterior_y = weighted.mean(y_signal, logit_weight, na.rm = TRUE),
      posterior_sd = sqrt(1 / sum(logit_weight, na.rm = TRUE)),
      evidence_rows = n(),
      .groups = "drop"
    ) |>
    mutate(
      rho_hat_pt = inverse_bounded_logit(posterior_y),
      rho_lo_pt = inverse_bounded_logit(posterior_y - 1.96 * posterior_sd),
      rho_hi_pt = inverse_bounded_logit(posterior_y + 1.96 * posterior_sd)
    )

  exact_summary <- exact_evidence |>
    arrange(parent, year, source_priority, desc(logit_weight)) |>
    group_by(parent, year) |>
    summarise(
      main_source = first(signal_type),
      external_anchor_flag = any(signal_type %in%
        c(
          "macro_reconciliation",
          "official_country_note"
        )),
      observed_adjusted_signal_flag = any(signal_type %in%
        c(
          "observed_adjusted_profit",
          "observed_adjusted_profit_parent"
        )),
      direct_adjusted_signal_flag = any(signal_type == "observed_adjusted_profit"),
      historical_adjusted_signal_flag = any(signal_type == "observed_adjusted_profit_parent"),
      public_signal_flag = any(signal_type == "public_etr_parity"),
      exact_signal_count = n(),
      .groups = "drop"
    )

  combined |>
    left_join(exact_summary, by = c("parent", "year")) |>
    mutate(
      main_source = coalesce(main_source, "fallback_prior"),
      external_anchor_flag = coalesce(external_anchor_flag, FALSE),
      observed_adjusted_signal_flag =
        coalesce(observed_adjusted_signal_flag, FALSE),
      direct_adjusted_signal_flag = coalesce(direct_adjusted_signal_flag, FALSE),
      historical_adjusted_signal_flag = coalesce(historical_adjusted_signal_flag, FALSE),
      public_signal_flag = coalesce(public_signal_flag, FALSE),
      exact_signal_count = coalesce(exact_signal_count, 0L),
      support_class = case_when(
        observed_adjusted_signal_flag ~ "observed_adjusted",
        external_anchor_flag ~ "anchored_model",
        public_signal_flag ~ "parity_shrinkage",
        TRUE ~ "fallback_prior"
      ),
      extrapolated_flag = !observed_adjusted_signal_flag & !external_anchor_flag
    )
}

build_holdout_validation <- function(evidence, targets, covariate = "historical_encoding") {
  holdout_rows <- evidence |>
    filter(signal_type %in% c(
      "observed_adjusted_profit",
      "macro_reconciliation",
      "official_country_note"
    )) |>
    mutate(row_id = row_number())

  if (nrow(holdout_rows) == 0) {
    return(tibble())
  }

  bind_rows(lapply(seq_len(nrow(holdout_rows)), function(i) {
    heldout <- holdout_rows[i, ]
    train <- evidence |>
      anti_join(heldout |> select(parent, year, signal_type, source),
        by = c("parent", "year", "signal_type", "source")
      )

    fit_i <- fit_prior_reconciliation_model(train, targets, covariate)
    pred_i <- fit_i$target_prior |>
      filter(parent == heldout$parent, year == heldout$year) |>
      transmute(heldout_prediction = prior_rho) |>
      pull(heldout_prediction)

    tibble(
      parent = heldout$parent,
      year = heldout$year,
      signal_type = heldout$signal_type,
      source = heldout$source,
      rho_signal = heldout$rho_signal,
      heldout_prediction = pred_i[1],
      error = pred_i[1] - heldout$rho_signal,
      abs_error = abs(pred_i[1] - heldout$rho_signal),
      profit_weight = heldout$profit_weight
    )
  }))
}

build_etr_balance_diagnostic <- function(parity_cells, predictions,
                                         adjusted_cells = NULL) {
  if (nrow(parity_cells) == 0) {
    return(tibble())
  }

  observed_adj_domestic <- adjusted_cells |>
    filter(is_domestic) |>
    select(parent, year, adjusted_profit = profit_adj_panelai)

  parity_cells |>
    left_join(predictions |> select(parent, year, rho_hat_pt),
      by = c("parent", "year")
    ) |>
    left_join(observed_adj_domestic, by = c("parent", "year")) |>
    mutate(
      static_rate = case_when(
        parent == "USA" ~ 0.54,
        parent == "NLD" ~ 0.16,
        TRUE ~ 0.324
      ),
      parity_only_rate = rho_signal,
      hybrid_profit = case_when(
        !is.na(adjusted_profit) ~ adjusted_profit,
        TRUE ~ domestic_profit * (1 - rho_hat_pt)
      ),
      static_profit = domestic_profit * (1 - static_rate),
      parity_profit = domestic_profit * (1 - parity_only_rate),
      uncorrected_etr = domestic_etr,
      static_etr = safe_divide(domestic_tax, static_profit),
      parity_only_etr = safe_divide(domestic_tax, parity_profit),
      hybrid_etr = safe_divide(domestic_tax, hybrid_profit),
      gap_uncorrected = uncorrected_etr - foreign_etr,
      gap_static = static_etr - foreign_etr,
      gap_parity_only = parity_only_etr - foreign_etr,
      gap_hybrid = hybrid_etr - foreign_etr
    ) |>
    select(
      parent, year, jurisdiction, domestic_profit, foreign_profit,
      foreign_parents, uncorrected_etr, static_etr, parity_only_etr,
      hybrid_etr, foreign_etr, gap_uncorrected, gap_static,
      gap_parity_only, gap_hybrid, rho_hat_pt, parity_only_rate,
      static_rate
    )
}

build_revenue_sensitivity_proxy <- function(panel, predictions,
                                            n_draws = 500,
                                            seed = 20260613) {
  domestic_prediction <- predictions |>
    select(
      parent, year, rho_hat_pt, rho_lo_pt, rho_hi_pt, posterior_y,
      posterior_sd
    )

  base <- panel |>
    filter(year %in% MAIN_YEARS) |>
    left_join(domestic_prediction, by = c("parent", "year")) |>
    mutate(
      profit_uncorrected = profit_panelai,
      profit_preferred = case_when(
        !is.na(profit_adj_panelai) ~ profit_adj_panelai,
        parent == affiliate ~ profit_panelai * (1 - rho_hat_pt),
        TRUE ~ profit_panelai
      ),
      profit_low_correction = case_when(
        !is.na(profit_adj_panelai) ~ profit_adj_panelai,
        parent == affiliate ~ profit_panelai * (1 - rho_lo_pt),
        TRUE ~ profit_panelai
      ),
      profit_high_correction = case_when(
        !is.na(profit_adj_panelai) ~ profit_adj_panelai,
        parent == affiliate ~ profit_panelai * (1 - rho_hi_pt),
        TRUE ~ profit_panelai
      )
    )

  exposure <- function(profit_col) {
    profit <- base[[profit_col]]
    etr <- safe_divide(base$tax_accrued_panelai, profit)
    topup <- if_else(
      !is.na(profit) & profit > 0 & !is.na(etr),
      pmax(GMT_RATE - etr, 0) * profit,
      0
    )
    tibble(
      specification = profit_col,
      positive_profit = sum(pmax(coalesce(profit, 0), 0), na.rm = TRUE),
      mechanical_pre_sbie_topup = sum(topup, na.rm = TRUE),
      eu27_mechanical_pre_sbie_topup =
        sum(if_else(base$affiliate %in% EU27_ISO3, topup, 0), na.rm = TRUE)
    )
  }

  interval <- bind_rows(
    exposure("profit_uncorrected"),
    exposure("profit_low_correction"),
    exposure("profit_preferred"),
    exposure("profit_high_correction")
  )

  set.seed(seed)
  draw_parent_year <- predictions |>
    filter(year %in% MAIN_YEARS) |>
    select(parent, year, posterior_y, posterior_sd)

  draw_summary <- bind_rows(lapply(seq_len(n_draws), function(draw_id) {
    draws <- draw_parent_year |>
      mutate(
        draw_id = draw_id,
        rho_draw = inverse_bounded_logit(
          stats::rnorm(n(), posterior_y, posterior_sd)
        )
      ) |>
      select(parent, year, draw_id, rho_draw)

    draw_base <- panel |>
      filter(year %in% MAIN_YEARS) |>
      left_join(draws, by = c("parent", "year")) |>
      mutate(
        profit_draw = case_when(
          !is.na(profit_adj_panelai) ~ profit_adj_panelai,
          parent == affiliate ~ profit_panelai * (1 - rho_draw),
          TRUE ~ profit_panelai
        ),
        etr_draw = safe_divide(tax_accrued_panelai, profit_draw),
        topup_draw = if_else(
          !is.na(profit_draw) & profit_draw > 0 & !is.na(etr_draw),
          pmax(GMT_RATE - etr_draw, 0) * profit_draw,
          0
        )
      )

    draw_base |>
      summarise(
        draw_id = .env$draw_id,
        positive_profit = sum(pmax(coalesce(profit_draw, 0), 0),
          na.rm = TRUE
        ),
        mechanical_pre_sbie_topup = sum(topup_draw, na.rm = TRUE),
        eu27_mechanical_pre_sbie_topup =
          sum(if_else(affiliate %in% EU27_ISO3, topup_draw, 0),
            na.rm = TRUE
          )
      )
  }))

  draw_interval <- draw_summary |>
    summarise(
      specification = "rho_draws",
      draws = n(),
      positive_profit_mean = mean(positive_profit, na.rm = TRUE),
      positive_profit_p025 = quantile(positive_profit, 0.025, na.rm = TRUE),
      positive_profit_p975 = quantile(positive_profit, 0.975, na.rm = TRUE),
      mechanical_topup_mean = mean(mechanical_pre_sbie_topup, na.rm = TRUE),
      mechanical_topup_p025 =
        quantile(mechanical_pre_sbie_topup, 0.025, na.rm = TRUE),
      mechanical_topup_p975 =
        quantile(mechanical_pre_sbie_topup, 0.975, na.rm = TRUE),
      eu27_mechanical_topup_mean =
        mean(eu27_mechanical_pre_sbie_topup, na.rm = TRUE),
      eu27_mechanical_topup_p025 =
        quantile(eu27_mechanical_pre_sbie_topup, 0.025, na.rm = TRUE),
      eu27_mechanical_topup_p975 =
        quantile(eu27_mechanical_pre_sbie_topup, 0.975, na.rm = TRUE)
    )

  list(
    point_interval = interval, draw_interval = draw_interval,
    draws = draw_summary
  )
}

run_profit_reconciliation_model <- function(in_dir = PROCESSED_DIR,
                                            out_dir = PROCESSED_DIR,
                                            manual_dir = "data/manual",
                                            n_draws = 500,
                                            seed = 20260613) {
  diag_dir <- file.path(out_dir, "diagnostics")
  dir.create(diag_dir, showWarnings = FALSE, recursive = TRUE)

  panel <- readRDS(file.path(in_dir, "cbcr_table1.rds")) |>
    filter(year %in% CORE_YEARS, !affiliate %in% AGGREGATE_AFFILIATES_RECON) |>
    mutate(
      parent = normalize_code(parent),
      affiliate = normalize_code(affiliate)
    )

  cit_statutory <- readRDS(file.path(in_dir, "cit_statutory.rds")) |>
    mutate(jurisdiction = normalize_code(jurisdiction))

  anchors_path <- file.path(manual_dir, "profit_correction_anchors.csv")
  if (!file.exists(anchors_path)) {
    stop("Missing profit correction anchors: ", anchors_path, call. = FALSE)
  }

  anchors <- read_csv(anchors_path, show_col_types = FALSE) |>
    mutate(parent = normalize_code(parent))

  targets <- build_parent_year_targets(panel, cit_statutory)

  adjusted <- build_adjusted_profit_signal(panel)

  parent_year_direct <- adjusted$parent_year |>
    transmute(
      parent, year, rho_signal, signal_type, source, source_citation_key,
      profit_weight,
      source_se = profit_reconciliation_source_precision(signal_type),
      support_score, scope, notes
    )

  parent_overall_expanded <- targets |>
    select(parent, year) |>
    anti_join(parent_year_direct |> select(parent, year),
      by = c("parent", "year")
    ) |>
    inner_join(adjusted$parent_overall, by = "parent") |>
    transmute(
      parent,
      year,
      rho_signal,
      signal_type = "observed_adjusted_profit_parent",
      source = "OECD adjusted profit, parent-level domestic average",
      source_citation_key = "oecd2025a",
      profit_weight,
      source_se = profit_reconciliation_source_precision(signal_type),
      support_score,
      scope = "domestic_parent_average_adjusted_profit",
      notes = "Parent-level adjusted-profit signal expanded only to parent-years without a directly observed domestic adjusted-profit cell."
    )

  parity <- build_etr_parity_signal(panel, cit_statutory)

  manual_signals <- expand_manual_anchor_signals(anchors, targets)

  evidence <- bind_rows(
    parent_year_direct,
    parent_overall_expanded,
    manual_signals,
    parity |>
      select(
        parent, year, rho_signal, signal_type, source,
        source_citation_key, profit_weight, source_se, support_score,
        scope, notes
      )
  ) |>
    mutate(
      rho_signal = clamp_interval(
        rho_signal, 0,
        PROFIT_RECONCILIATION_UPPER_BOUND
      ),
      source_se = coalesce(
        source_se,
        profit_reconciliation_source_precision(signal_type)
      ),
      support_score = clamp_interval(coalesce(support_score, 0.50), 0.05, 1)
    ) |>
    filter(year %in% CORE_YEARS)

  stopifnot(nrow(evidence) > 0)
  stopifnot(all(evidence$rho_signal >= 0, na.rm = TRUE))
  stopifnot(all(evidence$rho_signal <= PROFIT_RECONCILIATION_UPPER_BOUND,
    na.rm = TRUE
  ))

  prior_fit <- fit_prior_reconciliation_model(evidence, targets)
  predictions <- combine_parent_year_evidence(prior_fit$target_prior, evidence) |>
    left_join(
      targets |>
        select(
          parent, year, parent_group, parent_is_large_upe,
          parent_is_investment_hub, parent_is_conduit_haven,
          parent_is_zero_tax_or_low_tax, domestic_profit_mass,
          domestic_tax_mass, domestic_holding_share
        ),
      by = c("parent", "year")
    ) |>
    mutate(
      rho_hat_pt = clamp_interval(
        rho_hat_pt, 0,
        PROFIT_RECONCILIATION_UPPER_BOUND
      ),
      rho_lo_pt = clamp_interval(rho_lo_pt, 0, rho_hat_pt),
      rho_hi_pt = clamp_interval(
        rho_hi_pt, rho_hat_pt,
        PROFIT_RECONCILIATION_UPPER_BOUND
      ),
      main_source = recode(
        main_source,
        "observed_adjusted_profit_parent" = "observed_adjusted_profit",
        .default = main_source
      )
    ) |>
    arrange(year, desc(domestic_profit_mass), parent)

  assert_unique_keys(predictions, c("parent", "year"), "profit reconciliation predictions")
  stopifnot(
    nrow(predictions) == nrow(targets),
    all(is.finite(predictions$rho_hat_pt)),
    all(predictions$rho_lo_pt <= predictions$rho_hat_pt &
      predictions$rho_hat_pt <= predictions$rho_hi_pt)
  )

  holdout <- build_holdout_validation(evidence, targets)
  etr_balance <- build_etr_balance_diagnostic(
    parity,
    predictions,
    adjusted_cells = adjusted$adjusted_cells
  )
  revenue_sensitivity <- build_revenue_sensitivity_proxy(
    panel,
    predictions,
    n_draws = n_draws,
    seed = seed
  )

  evidence_summary <- evidence |>
    group_by(signal_type, source_citation_key, scope) |>
    summarise(
      rows = n(),
      parents = n_distinct(parent),
      years = n_distinct(year),
      weighted_rho = weighted_mean_clean(rho_signal, profit_weight),
      median_rho = median(rho_signal, na.rm = TRUE),
      profit_weight_total = sum(profit_weight, na.rm = TRUE),
      mean_source_se = mean(source_se, na.rm = TRUE),
      mean_support_score = mean(support_score, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(signal_type, desc(profit_weight_total))

  prediction_top20 <- predictions |>
    filter(year %in% MAIN_YEARS) |>
    group_by(parent) |>
    summarise(
      years = n(),
      domestic_profit = sum(domestic_profit_mass, na.rm = TRUE),
      rho_hat = weighted_mean_clean(rho_hat_pt, domestic_profit_mass),
      rho_lo = weighted_mean_clean(rho_lo_pt, domestic_profit_mass),
      rho_hi = weighted_mean_clean(rho_hi_pt, domestic_profit_mass),
      main_sources = paste(sort(unique(main_source)), collapse = "; "),
      support_class = paste(sort(unique(support_class)), collapse = "; "),
      external_anchor_flag = any(external_anchor_flag, na.rm = TRUE),
      public_signal_flag = any(public_signal_flag, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(desc(domestic_profit)) |>
    slice_head(n = 20)

  etr_balance_summary <- etr_balance |>
    summarise(
      supported_parent_years = n(),
      domestic_profit_total = sum(domestic_profit, na.rm = TRUE),
      foreign_profit_total = sum(foreign_profit, na.rm = TRUE),
      mean_abs_gap_uncorrected =
        weighted_mean_clean(abs(gap_uncorrected), domestic_profit),
      mean_abs_gap_static =
        weighted_mean_clean(abs(gap_static), domestic_profit),
      mean_abs_gap_parity_only =
        weighted_mean_clean(abs(gap_parity_only), domestic_profit),
      mean_abs_gap_hybrid =
        weighted_mean_clean(abs(gap_hybrid), domestic_profit),
      mean_gap_uncorrected =
        weighted_mean_clean(gap_uncorrected, domestic_profit),
      mean_gap_hybrid =
        weighted_mean_clean(gap_hybrid, domestic_profit)
    )

  write_csv(
    anchors,
    file.path(diag_dir, "step02a_profit_correction_anchors.csv")
  )
  write_csv(
    evidence,
    file.path(diag_dir, "step02a_profit_correction_evidence.csv")
  )
  write_csv(
    evidence_summary,
    file.path(diag_dir, "step02a_profit_correction_evidence_summary.csv")
  )
  write_csv(
    predictions,
    file.path(diag_dir, "step02a_profit_correction_parent_year.csv")
  )
  write_csv(
    prediction_top20,
    file.path(diag_dir, "step02a_profit_correction_parent_year_top20.csv")
  )
  write_csv(
    holdout,
    file.path(diag_dir, "step02a_profit_correction_validation_holdout.csv")
  )
  write_csv(
    parity,
    file.path(diag_dir, "step02a_profit_correction_etr_parity_cell.csv")
  )
  write_csv(
    etr_balance,
    file.path(diag_dir, "profit_correction_domestic_foreign_etr_balance.csv")
  )
  write_csv(
    etr_balance_summary,
    file.path(diag_dir, "step02a_profit_correction_etr_balance_summary.csv")
  )
  write_csv(
    revenue_sensitivity$point_interval,
    file.path(diag_dir, "step02a_profit_correction_revenue_sensitivity.csv")
  )
  write_csv(
    revenue_sensitivity$draw_interval,
    file.path(
      diag_dir,
      "step02a_profit_correction_revenue_draw_interval.csv"
    )
  )
  write_csv(
    revenue_sensitivity$draws,
    file.path(diag_dir, "step02a_profit_correction_revenue_draws.csv")
  )

  saveRDS(
    predictions,
    file.path(out_dir, "profit_correction_parent_year.rds")
  )
  saveRDS(
    evidence,
    file.path(out_dir, "profit_correction_evidence.rds")
  )
  saveRDS(
    adjusted$parent_year,
    file.path(out_dir, "profit_correction_observed_adjusted_parent_year.rds")
  )
  saveRDS(
    parity,
    file.path(out_dir, "profit_correction_etr_parity_parent_year.rds")
  )
  saveRDS(
    revenue_sensitivity$draws,
    file.path(out_dir, "profit_correction_revenue_draws.rds")
  )

  invisible(list(
    predictions = predictions,
    evidence = evidence,
    evidence_summary = evidence_summary,
    holdout = holdout,
    etr_balance = etr_balance,
    revenue_sensitivity = revenue_sensitivity,
    prior_fit = prior_fit
  ))
}

if (is_direct_script_run("code/02a_profit_reconciliation_model.R")) {
  run_profit_reconciliation_model()
  message("Step 2a profit-reconciliation model outputs written.")
}
