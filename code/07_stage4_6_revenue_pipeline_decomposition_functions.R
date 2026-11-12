# 07_stage4_6_revenue_pipeline_decomposition.R
# Step 7 of the methodology pipeline.
#
# Executes the Section 4.6 revenue pipeline after the legal Stage 4.5
# allocation. The script treats the Stage 4.5 country-year revenue matrix as
# the final object for the 2^5 counterfactual decomposition.
library(dplyr)
library(tidyr)
library(readr)
library(tibble)
library(stringr)

source("code/00_helpers.R")

dir.create(DIAGNOSTICS_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(GENERATED_DIR, showWarnings = FALSE, recursive = TRUE)

FACTOR_LABELS <- c(
  x1_etr = "ETR measurement",
  x2_substance = "Substance specification",
  x3_rates = "SBIE rate endpoint",
  x4_sbs = "SbS regime",
  x5_behaviour = "Behavioural response"
)

FACTOR_LEVELS <- tribble(
  ~effect, ~low_level, ~high_level,
  "x1_etr", "average", "distributional",
  "x2_substance", "aggregate SBIE", "sectoral SBIE with SBTI",
  "x3_rates", "initial rates", "long-run rates",
  "x4_sbs", "universal", "SbS",
  "x5_behaviour", "mechanical", "behavioural"
)

FACTOR_TAXONOMY <- tribble(
  ~effect, ~mechanism_class, ~economic_object, ~uncertainty_class,
  "x1_etr", "Endowment: low-taxed profit base",
  "Low-taxed profit volume and average top-up rate",
  "Epistemic measurement uncertainty",
  "x2_substance", "Endowment: substance shield",
  "Payroll, tangible assets and sectoral SBTI capacity",
  "Epistemic model uncertainty",
  "x3_rates", "Policy parameter: SBIE transition",
  "Statutory carve-out endpoint",
  "Policy-design scenario uncertainty",
  "x4_sbs", "Legal allocation regime",
  "QDMTT, IIR and UTPR collection rights",
  "Epistemic legal-regime uncertainty",
  "x5_behaviour", "Coefficient: behavioural response",
  "Panel-estimated semi-elasticity and SESH liability filter",
  "Behavioural specification; aleatoric only under coefficient bootstrap"
)

TYPOLOGY_FEATURES <- c(
  "preferred_revenue",
  "scenario_spread",
  "revenue_to_cit_1200",
  "revenue_to_gdp",
  "revenue_per_capita",
  "etr_measurement_main_effect",
  "sbs_regime_main_effect",
  "substance_specification_main_effect",
  "behavioural_response_main_effect",
  "qdmtt_share",
  "residual_iir_utpr_exposure",
  "sbs_extinguished_share",
  "high_risk_imputation_share"
)

TYPOLOGY_LOG_FEATURES <- c(
  "preferred_revenue",
  "scenario_spread",
  "revenue_per_capita"
)

TYPOLOGY_SIGNED_LOG_FEATURES <- c(
  "etr_measurement_main_effect",
  "sbs_regime_main_effect",
  "substance_specification_main_effect",
  "behavioural_response_main_effect"
)

TYPOLOGY_FEATURE_GROUPS <- tribble(
  ~feature, ~policy_dimension,
  "preferred_revenue", "Fiscal scale",
  "scenario_spread", "Fiscal scale",
  "revenue_to_cit_1200", "Fiscal scale",
  "revenue_to_gdp", "Fiscal scale",
  "revenue_per_capita", "Fiscal scale",
  "etr_measurement_main_effect", "Measurement risk",
  "substance_specification_main_effect", "Measurement risk",
  "behavioural_response_main_effect", "Measurement risk",
  "high_risk_imputation_share", "Measurement risk",
  "sbs_regime_main_effect", "Legal allocation",
  "qdmtt_share", "Legal allocation",
  "residual_iir_utpr_exposure", "Legal allocation",
  "sbs_extinguished_share", "Legal allocation"
)

DECOMPOSITION_SAMPLES <- tribble(
  ~sample_id, ~sample_label, ~start_year, ~end_year,
  "baseline_2017_2023", "2017–2023 baseline full public panel", 2017L, 2023L,
  "high_measurement_2019_2023", "2019–2023 direct Table IV window", 2019L, 2023L,
  "strict_overlap_2021_2023", "2021–2023 Table I and Table IV overlap window", 2021L, 2023L,
  "baseline_2017_2022", "2017–2022 comparison window on the updated pipeline", 2017L, 2022L
)

label_effect <- function(effect) {
  parts <- strsplit(effect, ":", fixed = TRUE)
  vapply(
    parts,
    function(x) paste(FACTOR_LABELS[x], collapse = " x "),
    character(1)
  )
}

split_effect <- function(effect) {
  strsplit(effect, ":", fixed = TRUE)[[1]]
}

classify_effect_uncertainty <- function(effect) {
  parts <- split_effect(effect)
  classes <- FACTOR_TAXONOMY$uncertainty_class[
    match(parts, FACTOR_TAXONOMY$effect)
  ]
  mechanisms <- FACTOR_TAXONOMY$mechanism_class[
    match(parts, FACTOR_TAXONOMY$effect)
  ]

  tibble(
    uncertainty_class = if (length(unique(classes)) == 1) {
      unique(classes)
    } else {
      "Mixed interaction"
    },
    mechanism_class = paste(mechanisms, collapse = " x ")
  )
}

validate_revenue_inputs <- function(revenue_country_year,
                                    revenue_by_channel,
                                    conservation) {
  assert_unique_keys(
    revenue_country_year,
    c(SCENARIO_VARS, "country", "year"),
    "Stage 4.6 country-year revenue input"
  )

  assert_unique_keys(
    revenue_by_channel,
    c(SCENARIO_VARS, "country", "year", "channel"),
    "Stage 4.6 channel revenue input"
  )

  scenarios <- revenue_country_year |>
    distinct(across(all_of(SCENARIO_VARS))) |>
    mutate(
      scenario_id_check = paste0(
        "x", x1_etr, x2_substance, x3_rates,
        x4_sbs, x5_behaviour
      ),
      scenario_id_valid = scenario_id == scenario_id_check
    )

  if (nrow(scenarios) != 32) {
    stop("Stage 4.6 revenue matrix does not contain exactly 32 scenarios")
  }

  if (any(!scenarios$scenario_id_valid)) {
    stop("Stage 4.6 scenario identifiers do not match the factor columns")
  }

  scenario_counts <- revenue_country_year |>
    count(country, year, name = "scenarios_per_country_year")

  if (any(scenario_counts$scenarios_per_country_year != 32)) {
    stop("Each country-year must contain all 32 factorial scenarios")
  }

  if (n_distinct(revenue_country_year$country) != 27 ||
    !setequal(unique(revenue_country_year$year), MAIN_YEARS)) {
    stop("Stage 4.6 revenue matrix is not the expected EU27 by 2017-2022 panel")
  }

  if (any(is.na(revenue_country_year$country_name))) {
    stop("Stage 4.6 revenue matrix has missing country names")
  }

  if (any(revenue_country_year$revenue < -1e-8, na.rm = TRUE) ||
    any(revenue_by_channel$revenue < -1e-8, na.rm = TRUE)) {
    stop("Stage 4.6 revenue inputs contain negative revenue")
  }

  channel_totals <- revenue_by_channel |>
    group_by(across(all_of(SCENARIO_VARS)), country, year) |>
    summarise(channel_revenue = sum(revenue, na.rm = TRUE), .groups = "drop")

  country_channel_check <- revenue_country_year |>
    left_join(channel_totals, by = c(SCENARIO_VARS, "country", "year")) |>
    mutate(
      channel_revenue = coalesce_zero(channel_revenue),
      channel_gap = revenue - channel_revenue
    )

  max_channel_gap <- max(abs(country_channel_check$channel_gap), na.rm = TRUE)
  if (max_channel_gap > 1e-3) {
    stop("Stage 4.6 country-year revenue does not match channel revenue")
  }

  max_conservation_gap <- max(abs(conservation$residual_gap), na.rm = TRUE)
  if (max_conservation_gap > 1e-3) {
    stop("Stage 4.6 allocation conservation gap exceeds tolerance")
  }

  tibble(
    metric = c(
      "factorial_scenarios",
      "country_year_revenue_rows",
      "eu_countries",
      "years",
      "max_country_channel_gap",
      "max_global_conservation_gap",
      "negative_revenue_rows"
    ),
    value = as.character(c(
      nrow(scenarios),
      nrow(revenue_country_year),
      n_distinct(revenue_country_year$country),
      n_distinct(revenue_country_year$year),
      max_channel_gap,
      max_conservation_gap,
      sum(revenue_country_year$revenue < -1e-8, na.rm = TRUE)
    ))
  )
}

compute_factorial_effects_one <- function(df) {
  if (nrow(df) != 32 || n_distinct(df$scenario_id) != 32) {
    stop("Factorial decomposition requires one complete 32-scenario cell")
  }

  design <- df |>
    arrange(scenario_id) |>
    mutate(across(all_of(FACTOR_COLS), ~ if_else(as.integer(.x) == 1L, 1, -1)))

  y <- design$revenue
  x <- stats::model.matrix(
    ~ x1_etr * x2_substance * x3_rates * x4_sbs * x5_behaviour,
    data = design
  )
  coefs <- as.numeric(crossprod(x, y) / colSums(x^2))
  names(coefs) <- colnames(x)
  total_ss <- sum((y - mean(y))^2)
  ss <- (coefs[-1]^2) * colSums(x[, -1, drop = FALSE]^2)

  tibble(
    effect = names(coefs)[-1],
    effect_label = label_effect(names(coefs)[-1]),
    interaction_order = str_count(names(coefs)[-1], ":") + 1L,
    effect_coefficient = coefs[-1],
    ss = as.numeric(ss),
    total_ss = total_ss,
    eta_squared = safe_divide(as.numeric(ss), total_ss)
  )
}

compute_factorial_anova <- function(revenue_country_year) {
  by_country_year <- revenue_country_year |>
    group_by(country, country_name, year) |>
    group_modify(~ compute_factorial_effects_one(.x)) |>
    ungroup()

  pooled <- by_country_year |>
    group_by(effect, effect_label, interaction_order) |>
    summarise(
      ss = sum(ss, na.rm = TRUE),
      total_ss = sum(total_ss, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(eta_squared = safe_divide(ss, total_ss)) |>
    arrange(desc(eta_squared))

  by_country <- by_country_year |>
    group_by(country, country_name, effect, effect_label, interaction_order) |>
    summarise(
      ss = sum(ss, na.rm = TRUE),
      total_ss = sum(total_ss, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(eta_squared = safe_divide(ss, total_ss)) |>
    arrange(country, desc(eta_squared))

  list(
    by_country_year = by_country_year,
    pooled = pooled,
    by_country = by_country
  )
}

add_decomposition_taxonomy <- function(anova_df) {
  taxonomy <- bind_rows(lapply(anova_df$effect, classify_effect_uncertainty)) |>
    mutate(effect = anova_df$effect)

  anova_df |>
    left_join(taxonomy, by = "effect") |>
    relocate(mechanism_class, uncertainty_class, .after = effect_label)
}

build_shapley_factor_attribution <- function(anova_df) {
  anova_df |>
    select(effect, interaction_order, eta_squared) |>
    mutate(factor = strsplit(effect, ":", fixed = TRUE)) |>
    unnest(factor) |>
    mutate(
      allocated_eta_squared = eta_squared / interaction_order,
      main_eta_squared = if_else(interaction_order == 1L,
        allocated_eta_squared, 0
      ),
      interaction_eta_squared = if_else(interaction_order >= 2L,
        allocated_eta_squared, 0
      )
    ) |>
    group_by(effect = factor) |>
    summarise(
      main_eta_squared = sum(main_eta_squared, na.rm = TRUE),
      interaction_eta_squared = sum(interaction_eta_squared, na.rm = TRUE),
      shapley_eta_squared = sum(allocated_eta_squared, na.rm = TRUE),
      .groups = "drop"
    ) |>
    left_join(
      FACTOR_TAXONOMY |>
        select(effect,
          effect_label = mechanism_class, economic_object,
          uncertainty_class
        ),
      by = "effect"
    ) |>
    mutate(factor_label = FACTOR_LABELS[effect]) |>
    relocate(factor_label, effect_label, economic_object,
      uncertainty_class,
      .after = effect
    ) |>
    arrange(desc(shapley_eta_squared))
}

build_uncertainty_summary <- function(anova_df) {
  add_decomposition_taxonomy(anova_df) |>
    mutate(effect_eta_squared = eta_squared) |>
    group_by(uncertainty_class) |>
    summarise(
      eta_squared = sum(effect_eta_squared, na.rm = TRUE),
      main_eta_squared = sum(if_else(interaction_order == 1L,
        effect_eta_squared, 0
      ), na.rm = TRUE),
      interaction_eta_squared = sum(
        if_else(interaction_order >= 2L,
          effect_eta_squared, 0
        ),
        na.rm = TRUE
      ),
      effects = n(),
      .groups = "drop"
    ) |>
    arrange(desc(eta_squared))
}

build_scenario_summary <- function(revenue_country_year) {
  revenue_country_year |>
    group_by(across(all_of(SCENARIO_VARS))) |>
    summarise(
      eu_revenue = sum(revenue, na.rm = TRUE),
      mean_country_year_revenue = mean(revenue, na.rm = TRUE),
      median_country_year_revenue = stats::median(revenue, na.rm = TRUE),
      country_years = n(),
      .groups = "drop"
    ) |>
    mutate(
      eu_revenue_bn = eu_revenue / 1e9,
      scenario_rank_desc = dense_rank(desc(eu_revenue))
    ) |>
    arrange(scenario_rank_desc, scenario_id)
}

build_scenario_design_table <- function(revenue_country_year) {
  revenue_country_year |>
    distinct(across(all_of(SCENARIO_VARS))) |>
    mutate(
      scenario_id_from_factors = paste0("x", do.call(
        paste0,
        across(all_of(FACTOR_COLS))
      )),
      scenario_id_matches_factors = scenario_id == scenario_id_from_factors
    ) |>
    arrange(scenario_id)
}

build_scenario_spread <- function(revenue_country_year) {
  revenue_country_year |>
    group_by(country, country_name, year) |>
    summarise(
      min_revenue = min(revenue, na.rm = TRUE),
      max_revenue = max(revenue, na.rm = TRUE),
      mean_revenue = mean(revenue, na.rm = TRUE),
      median_revenue = stats::median(revenue, na.rm = TRUE),
      sd_revenue = stats::sd(revenue, na.rm = TRUE),
      scenario_spread = max_revenue - min_revenue,
      spread_to_mean = safe_divide(scenario_spread, mean_revenue),
      scenario_at_min = scenario_id[which.min(revenue)][1],
      scenario_at_max = scenario_id[which.max(revenue)][1],
      .groups = "drop"
    ) |>
    arrange(desc(scenario_spread))
}

build_country_scenario_totals <- function(revenue_country_year) {
  revenue_country_year |>
    group_by(across(all_of(SCENARIO_VARS)), country, country_name) |>
    summarise(country_revenue = sum(revenue, na.rm = TRUE), .groups = "drop")
}

build_country_spread <- function(country_scenario_totals) {
  country_scenario_totals |>
    group_by(country, country_name) |>
    summarise(
      min_revenue = min(country_revenue, na.rm = TRUE),
      max_revenue = max(country_revenue, na.rm = TRUE),
      mean_revenue = mean(country_revenue, na.rm = TRUE),
      median_revenue = stats::median(country_revenue, na.rm = TRUE),
      scenario_spread = max_revenue - min_revenue,
      spread_to_mean = safe_divide(scenario_spread, mean_revenue),
      scenario_at_min = scenario_id[which.min(country_revenue)][1],
      scenario_at_max = scenario_id[which.max(country_revenue)][1],
      .groups = "drop"
    ) |>
    arrange(desc(scenario_spread))
}

compute_main_effects <- function(scenario_totals,
                                 revenue_col = "revenue",
                                 group_vars = character()) {
  bind_rows(lapply(FACTOR_COLS, function(factor_col) {
    scenario_totals |>
      group_by(across(all_of(c(group_vars, factor_col)))) |>
      summarise(
        mean_revenue = mean(.data[[revenue_col]], na.rm = TRUE),
        .groups = "drop"
      ) |>
      transmute(
        across(all_of(group_vars)),
        effect = factor_col,
        effect_label = FACTOR_LABELS[factor_col],
        level = as.integer(.data[[factor_col]]),
        mean_revenue = mean_revenue
      ) |>
      pivot_wider(
        names_from = level, values_from = mean_revenue,
        names_prefix = "level_"
      ) |>
      mutate(
        high_minus_low = level_1 - level_0,
        pct_high_minus_low = safe_divide(high_minus_low, level_0)
      )
  })) |>
    left_join(FACTOR_LEVELS, by = "effect") |>
    relocate(low_level, high_level, .after = effect_label)
}

build_h4_pairs <- function(revenue_country_year) {
  other_factors <- c(
    "rate_scenario", "factor1_etr", "factor2_substance",
    "factor5_behaviour", "country", "country_name", "year"
  )

  revenue_country_year |>
    select(all_of(other_factors), factor4_sbs, revenue) |>
    pivot_wider(names_from = factor4_sbs, values_from = revenue) |>
    mutate(delta_sbs_minus_universal = sbs - universal)
}

build_h4_summary <- function(h4_pairs) {
  wt_two_sided <- stats::wilcox.test(
    h4_pairs$delta_sbs_minus_universal,
    mu = 0,
    exact = FALSE
  )
  wt_less <- stats::wilcox.test(
    h4_pairs$delta_sbs_minus_universal,
    mu = 0,
    exact = FALSE,
    alternative = "less"
  )

  tibble(
    test = "wilcoxon_sbs_minus_universal_stage4_6",
    n = length(h4_pairs$delta_sbs_minus_universal),
    mean_delta = mean(h4_pairs$delta_sbs_minus_universal, na.rm = TRUE),
    median_delta = stats::median(h4_pairs$delta_sbs_minus_universal,
      na.rm = TRUE
    ),
    statistic = unname(wt_two_sided$statistic),
    p_value_two_sided = wt_two_sided$p.value,
    p_value_less = wt_less$p.value
  )
}

filter_preferred_core <- function(df, behaviour = "mechanical") {
  df |>
    filter(
      factor1_etr == "distributional",
      factor2_substance == "aggregate_sbie",
      rate_scenario == "initial",
      factor5_behaviour == behaviour
    )
}

build_preferred_outputs <- function(revenue_country_year, revenue_by_channel,
                                    behaviour = "mechanical") {
  preferred_country_year <- revenue_country_year |>
    filter_preferred_core(behaviour = behaviour) |>
    arrange(factor4_sbs, country, year)

  preferred_channel_summary <- revenue_by_channel |>
    filter_preferred_core(behaviour = behaviour) |>
    group_by(factor4_sbs, channel) |>
    summarise(
      revenue = sum(revenue, na.rm = TRUE),
      revenue_bn = revenue / 1e9,
      .groups = "drop"
    ) |>
    arrange(factor4_sbs, channel)

  preferred_year_channel <- revenue_by_channel |>
    filter_preferred_core(behaviour = behaviour) |>
    group_by(factor4_sbs, year, channel) |>
    summarise(
      revenue = sum(revenue, na.rm = TRUE),
      revenue_bn = revenue / 1e9,
      .groups = "drop"
    ) |>
    arrange(factor4_sbs, year, channel)

  list(
    behaviour = behaviour,
    country_year = preferred_country_year,
    channel_summary = preferred_channel_summary,
    year_channel = preferred_year_channel
  )
}

build_cit_revenue_denominators <- function(cit_revenue) {
  cit_revenue |>
    filter(
      jurisdiction %in% EU27_ISO3,
      year %in% MAIN_YEARS,
      measure == "TAX_REV",
      sector == "S13",
      revenue_classification %in% c("T_1200", "T_1210"),
      unit == "USD"
    ) |>
    transmute(
      country = jurisdiction,
      year,
      revenue_classification,
      cit_revenue_usd = value * 1e9
    ) |>
    pivot_wider(
      names_from = revenue_classification,
      values_from = cit_revenue_usd,
      names_prefix = "cit_revenue_"
    )
}

build_macro_denominators <- function(wb_gdp, wb_population) {
  wb_gdp |>
    select(jurisdiction, year, gdp_pc_usd) |>
    inner_join(
      wb_population |> select(jurisdiction, year, population),
      by = c("jurisdiction", "year")
    ) |>
    filter(jurisdiction %in% EU27_ISO3, year %in% MAIN_YEARS) |>
    transmute(
      country = jurisdiction,
      year,
      gdp_usd = gdp_pc_usd * population,
      population
    )
}

build_preferred_channel_country_year <- function(revenue_by_channel,
                                                 behaviour = "behavioural") {
  revenue_by_channel |>
    filter_preferred_core(behaviour = behaviour) |>
    group_by(country, country_name, year, factor4_sbs, channel) |>
    summarise(revenue = sum(revenue, na.rm = TRUE), .groups = "drop") |>
    pivot_wider(names_from = channel, values_from = revenue, values_fill = 0)
}

build_fiscal_salience_country_year <- function(preferred_country_year,
                                               preferred_channel_country_year,
                                               scenario_spread_country_year,
                                               cit_revenue,
                                               wb_gdp,
                                               wb_population) {
  preferred_sbs <- preferred_country_year |>
    filter(factor4_sbs == "sbs") |>
    select(country, country_name, year, preferred_revenue = revenue)

  preferred_universal <- preferred_country_year |>
    filter(factor4_sbs == "universal") |>
    select(country, year, universal_revenue = revenue)

  qdmtt <- preferred_channel_country_year |>
    filter(factor4_sbs == "sbs") |>
    transmute(
      country,
      year,
      qdmtt_revenue = coalesce_zero(QDMTT)
    )

  preferred_sbs |>
    dplyr::left_join(
      preferred_universal,
      by = c("country", "year")
    ) |>
    dplyr::left_join(
      qdmtt,
      by = c("country", "year")
    ) |>
    dplyr::left_join(
      scenario_spread_country_year |> select(country, year, scenario_spread),
      by = c("country", "year")
    ) |>
    dplyr::left_join(
      build_cit_revenue_denominators(cit_revenue),
      by = c("country", "year")
    ) |>
    dplyr::left_join(
      build_macro_denominators(wb_gdp, wb_population),
      by = c("country", "year")
    ) |>
    mutate(
      sbs_revenue_loss = universal_revenue - preferred_revenue,
      revenue_to_cit_1200 =
        safe_divide(preferred_revenue, cit_revenue_T_1200),
      revenue_to_cit_1210 =
        safe_divide(preferred_revenue, cit_revenue_T_1210),
      revenue_to_gdp = safe_divide(preferred_revenue, gdp_usd),
      revenue_per_capita = safe_divide(preferred_revenue, population),
      scenario_spread_to_cit_1200 =
        safe_divide(scenario_spread, cit_revenue_T_1200),
      sbs_loss_to_cit_1200 =
        safe_divide(sbs_revenue_loss, cit_revenue_T_1200),
      qdmtt_preserved_share =
        safe_divide(qdmtt_revenue, preferred_revenue)
    ) |>
    arrange(country, year)
}

build_fiscal_salience_country <- function(fiscal_country_year) {
  fiscal_country_year |>
    group_by(country, country_name) |>
    summarise(
      preferred_revenue = sum(preferred_revenue, na.rm = TRUE),
      universal_revenue = sum(universal_revenue, na.rm = TRUE),
      sbs_revenue_loss = sum(sbs_revenue_loss, na.rm = TRUE),
      qdmtt_revenue = sum(qdmtt_revenue, na.rm = TRUE),
      scenario_spread = sum(scenario_spread, na.rm = TRUE),
      cit_1200_years = sum(!is.na(cit_revenue_T_1200)),
      cit_1210_years = sum(!is.na(cit_revenue_T_1210)),
      # Complete-case denominator: a missing fiscal or macro year makes the
      # cumulative ratio unavailable instead of silently shrinking the base.
      cit_revenue_T_1200 = sum(cit_revenue_T_1200, na.rm = FALSE),
      cit_revenue_T_1210 = sum(cit_revenue_T_1210, na.rm = FALSE),
      gdp_usd = sum(gdp_usd, na.rm = FALSE),
      average_population = mean(population, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(
      revenue_to_cit_1200 =
        safe_divide(preferred_revenue, cit_revenue_T_1200),
      revenue_to_cit_1210 =
        safe_divide(preferred_revenue, cit_revenue_T_1210),
      revenue_to_gdp = safe_divide(preferred_revenue, gdp_usd),
      revenue_per_capita =
        safe_divide(preferred_revenue, average_population),
      scenario_spread_to_cit_1200 =
        safe_divide(scenario_spread, cit_revenue_T_1200),
      sbs_loss_to_cit_1200 =
        safe_divide(sbs_revenue_loss, cit_revenue_T_1200),
      qdmtt_preserved_share =
        safe_divide(qdmtt_revenue, preferred_revenue)
    ) |>
    arrange(desc(revenue_to_cit_1200))
}

build_stage1_imputation_exposure <- function(stage1_bilateral) {
  stage1_bilateral |>
    filter(affiliate %in% EU27_ISO3, year %in% MAIN_YEARS) |>
    mutate(
      high_risk_imputation_branch =
        stage1_distributional_source %in%
          c("shape_transport", "percentile_fit", "avg_only") |
          coalesce(bspi_high_tv_flag, FALSE),
      lowtax_distributional_row =
        coalesce_zero(stage1_lowtax_profit_distributional)
    ) |>
    group_by(
      country = affiliate,
      country_name = affiliate_jurisdiction_name
    ) |>
    summarise(
      lowtax_distributional =
        sum(lowtax_distributional_row, na.rm = TRUE),
      high_risk_imputation_lowtax =
        sum(if_else(high_risk_imputation_branch,
          lowtax_distributional_row, 0
        ), na.rm = TRUE),
      direct_t4_lowtax =
        sum(if_else(stage1_distributional_source == "direct_t4",
          lowtax_distributional_row, 0
        ), na.rm = TRUE),
      high_risk_imputation_share =
        safe_divide(high_risk_imputation_lowtax, lowtax_distributional),
      direct_t4_lowtax_share =
        safe_divide(direct_t4_lowtax, lowtax_distributional),
      .groups = "drop"
    )
}

build_country_typology_feature_matrix <- function(fiscal_salience_country,
                                                  main_effects_by_country,
                                                  preferred_channel_country_year,
                                                  stage1_bilateral) {
  effect_features <- main_effects_by_country |>
    select(country, effect, high_minus_low) |>
    pivot_wider(names_from = effect, values_from = high_minus_low)

  channel_exposure <- preferred_channel_country_year |>
    filter(factor4_sbs == "sbs") |>
    group_by(country, country_name) |>
    summarise(
      qdmtt_revenue = sum(coalesce_zero(QDMTT), na.rm = TRUE),
      iir_revenue = sum(coalesce_zero(IIR), na.rm = TRUE),
      utpr_revenue = sum(coalesce_zero(UTPR), na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(
      preferred_channel_revenue =
        qdmtt_revenue + iir_revenue + utpr_revenue,
      residual_iir_utpr_exposure =
        safe_divide(
          iir_revenue + utpr_revenue,
          preferred_channel_revenue
        )
    )

  imputation_exposure <- build_stage1_imputation_exposure(stage1_bilateral)

  fiscal_salience_country |>
    dplyr::left_join(
      effect_features,
      by = "country",
    ) |>
    dplyr::left_join(
      channel_exposure |>
        select(country, residual_iir_utpr_exposure),
      by = "country",
    ) |>
    dplyr::left_join(
      imputation_exposure |>
        select(
          country, high_risk_imputation_share,
          direct_t4_lowtax_share
        ),
      by = "country",
    ) |>
    transmute(
      country,
      country_name,
      preferred_revenue,
      scenario_spread,
      revenue_to_cit_1200,
      revenue_to_gdp,
      revenue_per_capita,
      etr_measurement_main_effect = x1_etr,
      sbs_regime_main_effect = -x4_sbs,
      substance_specification_main_effect = -x2_substance,
      behavioural_response_main_effect = -x5_behaviour,
      qdmtt_share = qdmtt_preserved_share,
      residual_iir_utpr_exposure,
      sbs_extinguished_share =
        safe_divide(sbs_revenue_loss, universal_revenue),
      high_risk_imputation_share,
      direct_t4_lowtax_share
    ) |>
    mutate(
      across(c(
        qdmtt_share, residual_iir_utpr_exposure,
        sbs_extinguished_share, high_risk_imputation_share,
        direct_t4_lowtax_share
      ), nan_to_na)
    ) |>
    arrange(country)
}

prepare_typology_matrix <- function(feature_matrix) {
  transformed <- feature_matrix |>
    select(all_of(TYPOLOGY_FEATURES)) |>
    mutate(
      across(all_of(TYPOLOGY_LOG_FEATURES), log1p),
      across(all_of(TYPOLOGY_SIGNED_LOG_FEATURES), signed_log1p)
    )

  imputation_summary <- tibble(
    feature = TYPOLOGY_FEATURES,
    missing_values =
      vapply(
        transformed[TYPOLOGY_FEATURES],
        function(x) sum(is.na(x)), integer(1)
      ),
    imputation_value =
      vapply(
        transformed[TYPOLOGY_FEATURES],
        function(x) median(x, na.rm = TRUE), numeric(1)
      )
  )

  imputed <- transformed
  for (feature in TYPOLOGY_FEATURES) {
    fill_value <- imputation_summary$imputation_value[
      imputation_summary$feature == feature
    ]
    imputed[[feature]][is.na(imputed[[feature]])] <- fill_value
  }

  scaled <- scale(as.matrix(imputed[TYPOLOGY_FEATURES]))
  list(
    transformed = transformed,
    imputed = imputed,
    scaled = scaled,
    imputation_summary = imputation_summary
  )
}

top_loading_features <- function(loadings, component, n = 4L) {
  loadings |>
    transmute(feature, loading = .data[[component]]) |>
    arrange(desc(abs(loading))) |>
    slice_head(n = n) |>
    pull(feature) |>
    paste(collapse = "; ")
}

run_country_typology_pca <- function(feature_matrix) {
  prepared <- prepare_typology_matrix(feature_matrix)
  pca <- stats::prcomp(prepared$scaled, center = FALSE, scale. = FALSE)

  variance <- pca$sdev^2
  pca_summary <- tibble(
    component = paste0("PC", seq_along(variance)),
    variance_share = variance / sum(variance),
    cumulative_share = cumsum(variance / sum(variance))
  )

  loadings <- as.data.frame(pca$rotation) |>
    rownames_to_column("feature") |>
    as_tibble()

  scores <- as.data.frame(pca$x) |>
    mutate(
      country = feature_matrix$country,
      country_name = feature_matrix$country_name
    ) |>
    relocate(country, country_name)

  component_diagnostics <- bind_rows(lapply(
    paste0("PC", 1:3),
    function(component) {
      dimension_strength <- loadings |>
        select(feature, loading = all_of(component)) |>
        left_join(TYPOLOGY_FEATURE_GROUPS, by = "feature") |>
        group_by(policy_dimension) |>
        summarise(
          abs_loading = sum(abs(loading), na.rm = TRUE),
          .groups = "drop"
        ) |>
        arrange(desc(abs_loading))

      tibble(
        component = component,
        interpreted_dimension = dimension_strength$policy_dimension[1],
        fiscal_scale_loading = dimension_strength$abs_loading[
          match("Fiscal scale", dimension_strength$policy_dimension)
        ],
        legal_allocation_loading = dimension_strength$abs_loading[
          match("Legal allocation", dimension_strength$policy_dimension)
        ],
        measurement_risk_loading = dimension_strength$abs_loading[
          match("Measurement risk", dimension_strength$policy_dimension)
        ],
        top_features = top_loading_features(loadings, component)
      )
    }
  )) |>
    mutate(across(ends_with("_loading"), ~ if_else(is.na(.x), 0, .x)))

  pca_summary <- pca_summary |>
    left_join(component_diagnostics, by = "component")

  list(
    pca = pca,
    summary = pca_summary,
    loadings = loadings,
    scores = scores,
    imputation_summary = prepared$imputation_summary,
    scaled = prepared$scaled
  )
}

pairwise_cluster_agreement <- function(reference_cluster, comparison_cluster) {
  reference_same <- outer(reference_cluster, reference_cluster, `==`)
  comparison_same <- outer(comparison_cluster, comparison_cluster, `==`)
  mean(
    reference_same[upper.tri(reference_same)] ==
      comparison_same[upper.tri(comparison_same)]
  )
}

build_cluster_stability <- function(scaled_matrix,
                                    k_values = 2:4,
                                    draws = 200L,
                                    jitter_sd = 0.05,
                                    seed = 20260606L) {
  bind_rows(lapply(k_values, function(k) {
    set.seed(seed + k)
    baseline <- stats::kmeans(scaled_matrix, centers = k, nstart = 100)

    stability_draws <- replicate(draws, {
      jittered <- scaled_matrix +
        matrix(stats::rnorm(length(scaled_matrix), 0, jitter_sd),
          nrow = nrow(scaled_matrix)
        )
      candidate <- stats::kmeans(jittered, centers = k, nstart = 20)
      pairwise_cluster_agreement(baseline$cluster, candidate$cluster)
    })

    cluster_sizes <- tabulate(baseline$cluster, nbins = k)
    tibble(
      k = k,
      stability_score = mean(stability_draws),
      stability_min = min(stability_draws),
      min_cluster_size = min(cluster_sizes),
      max_cluster_size = max(cluster_sizes),
      total_withinss = sum(baseline$withinss),
      cluster_sizes = paste(cluster_sizes, collapse = "/"),
      selected = k == 4L,
      selection_reason = if_else(
        k == 4L,
        "Selected: stable, no single-country clusters, and separates conduit hubs, QDMTT-protected smaller states, residual-exposure states and states with latent exposure masked by sparse CbCR data.",
        ""
      )
    )
  }))
}

label_cluster_profile <- function(total_revenue, mean_revenue_to_cit,
                                  mean_qdmtt_share) {
  case_when(
    total_revenue <= 0 ~ "Exposure masked by sparse CbCR data",
    !is.na(mean_revenue_to_cit) & mean_revenue_to_cit >= 0.30 ~
      "High-salience conduit hubs",
    !is.na(mean_qdmtt_share) & mean_qdmtt_share >= 0.80 ~
      "QDMTT-protected smaller exposure",
    TRUE ~ "Residual IIR/UTPR and measurement exposure"
  )
}

run_country_typology_clusters <- function(feature_matrix,
                                          scaled_matrix,
                                          selected_k = 4L,
                                          seed = 20260606L) {
  set.seed(seed)
  cluster_fit <- stats::kmeans(scaled_matrix,
    centers = selected_k,
    nstart = 100
  )

  country_clusters <- feature_matrix |>
    mutate(cluster_id = cluster_fit$cluster)

  cluster_profiles <- country_clusters |>
    group_by(cluster_id) |>
    summarise(
      countries = paste(country, collapse = ", "),
      n_countries = n(),
      preferred_revenue = sum(preferred_revenue, na.rm = TRUE),
      scenario_spread = sum(scenario_spread, na.rm = TRUE),
      mean_revenue_to_cit_1200 = mean(revenue_to_cit_1200, na.rm = TRUE),
      mean_revenue_to_gdp = mean(revenue_to_gdp, na.rm = TRUE),
      mean_qdmtt_share = mean(qdmtt_share, na.rm = TRUE),
      mean_residual_iir_utpr_exposure =
        mean(residual_iir_utpr_exposure, na.rm = TRUE),
      mean_sbs_extinguished_share =
        mean(sbs_extinguished_share, na.rm = TRUE),
      mean_high_risk_imputation_share =
        mean(high_risk_imputation_share, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(
      across(where(is.numeric), nan_to_na),
      policy_type = label_cluster_profile(
        preferred_revenue,
        mean_revenue_to_cit_1200,
        mean_qdmtt_share
      ),
      policy_order = case_when(
        policy_type == "High-salience conduit hubs" ~ 1L,
        policy_type == "QDMTT-protected smaller exposure" ~ 2L,
        policy_type == "Residual IIR/UTPR and measurement exposure" ~ 3L,
        TRUE ~ 4L
      )
    ) |>
    arrange(policy_order, desc(preferred_revenue)) |>
    mutate(typology_id = paste0("T", row_number())) |>
    select(typology_id, cluster_id, policy_type, everything(), -policy_order)

  country_clusters <- country_clusters |>
    left_join(
      cluster_profiles |>
        select(cluster_id, typology_id, policy_type),
      by = "cluster_id"
    ) |>
    arrange(typology_id, country)

  list(
    fit = cluster_fit,
    clusters = country_clusters,
    profiles = cluster_profiles
  )
}

build_measurement_sample_coverage <- function(stage1_bilateral,
                                              stage1_affiliate_year,
                                              years) {
  eu_bilateral <- stage1_bilateral |>
    filter(affiliate %in% EU27_ISO3, year %in% years) |>
    mutate(
      lowtax_distributional =
        coalesce_zero(stage1_lowtax_profit_distributional),
      high_risk_imputation_branch =
        stage1_distributional_source %in%
          c("shape_transport", "percentile_fit", "avg_only") |
          coalesce(bspi_high_tv_flag, FALSE)
    )

  lowtax_total <- sum(eu_bilateral$lowtax_distributional, na.rm = TRUE)
  direct_t4_lowtax <- sum(if_else(
    eu_bilateral$stage1_distributional_source == "direct_t4",
    eu_bilateral$lowtax_distributional,
    0
  ), na.rm = TRUE)
  high_risk_lowtax <- sum(if_else(
    eu_bilateral$high_risk_imputation_branch,
    eu_bilateral$lowtax_distributional,
    0
  ), na.rm = TRUE)

  overlap_affiliate_years <- stage1_affiliate_year |>
    filter(
      affiliate %in% EU27_ISO3,
      year %in% years,
      stage1_positive_profit_flag,
      coalesce(direct_available, FALSE),
      coalesce(percentile_available, FALSE)
    ) |>
    nrow()

  tibble(
    direct_t4_lowtax_share =
      safe_divide(direct_t4_lowtax, lowtax_total),
    high_risk_imputation_share =
      safe_divide(high_risk_lowtax, lowtax_total),
    overlap_affiliate_years = overlap_affiliate_years
  )
}

build_measurement_sample_decomposition <- function(revenue_country_year,
                                                   stage1_bilateral,
                                                   stage1_affiliate_year) {
  sample_anova <- bind_rows(lapply(
    seq_len(nrow(DECOMPOSITION_SAMPLES)),
    function(i) {
      sample_def <- DECOMPOSITION_SAMPLES[i, ]
      sample_revenue <- revenue_country_year |>
        filter(
          year >= sample_def$start_year,
          year <= sample_def$end_year
        )

      compute_factorial_anova(sample_revenue)$pooled |>
        mutate(
          sample_id = sample_def$sample_id,
          sample_label = sample_def$sample_label,
          start_year = sample_def$start_year,
          end_year = sample_def$end_year
        ) |>
        relocate(sample_id, sample_label, start_year, end_year)
    }
  ))

  sample_main_effects <- sample_anova |>
    filter(interaction_order == 1L) |>
    group_by(sample_id) |>
    arrange(desc(eta_squared), .by_group = TRUE) |>
    mutate(main_effect_rank = row_number()) |>
    ungroup()

  sample_summary <- bind_rows(lapply(
    seq_len(nrow(DECOMPOSITION_SAMPLES)),
    function(i) {
      sample_def <- DECOMPOSITION_SAMPLES[i, ]
      sample_revenue <- revenue_country_year |>
        filter(
          year >= sample_def$start_year,
          year <= sample_def$end_year
        )
      scenario_summary <- build_scenario_summary(sample_revenue)
      coverage <- build_measurement_sample_coverage(
        stage1_bilateral,
        stage1_affiliate_year,
        sample_def$start_year:sample_def$end_year
      )
      main_effects <- sample_main_effects |>
        filter(sample_id == sample_def$sample_id) |>
        arrange(main_effect_rank)
      allocated_effects <- build_shapley_factor_attribution(
        sample_anova |> filter(sample_id == sample_def$sample_id)
      )
      interaction_eta <- sample_anova |>
        filter(sample_id == sample_def$sample_id, interaction_order >= 2L) |>
        summarise(value = sum(eta_squared, na.rm = TRUE), .groups = "drop") |>
        pull(value)
      preferred_revenue <- sample_revenue |>
        filter_preferred_core(behaviour = "behavioural") |>
        filter(factor4_sbs == "sbs") |>
        summarise(value = sum(revenue, na.rm = TRUE), .groups = "drop") |>
        pull(value)

      tibble(
        sample_id = sample_def$sample_id,
        sample_label = sample_def$sample_label,
        start_year = sample_def$start_year,
        end_year = sample_def$end_year,
        country_years = n_distinct(sample_revenue$country) *
          n_distinct(sample_revenue$year),
        eu_revenue_min = min(scenario_summary$eu_revenue, na.rm = TRUE),
        eu_revenue_max = max(scenario_summary$eu_revenue, na.rm = TRUE),
        eu_revenue_spread =
          max(scenario_summary$eu_revenue, na.rm = TRUE) -
            min(scenario_summary$eu_revenue, na.rm = TRUE),
        etr_measurement_eta = main_effects$eta_squared[
          match("x1_etr", main_effects$effect)
        ],
        sbs_regime_eta = main_effects$eta_squared[
          match("x4_sbs", main_effects$effect)
        ],
        substance_specification_eta = main_effects$eta_squared[
          match("x2_substance", main_effects$effect)
        ],
        behavioural_response_eta = main_effects$eta_squared[
          match("x5_behaviour", main_effects$effect)
        ],
        sbie_rate_endpoint_eta = main_effects$eta_squared[
          match("x3_rates", main_effects$effect)
        ],
        etr_measurement_allocated_eta =
          allocated_effects$shapley_eta_squared[
            match("x1_etr", allocated_effects$effect)
          ],
        sbs_regime_allocated_eta =
          allocated_effects$shapley_eta_squared[
            match("x4_sbs", allocated_effects$effect)
          ],
        substance_specification_allocated_eta =
          allocated_effects$shapley_eta_squared[
            match("x2_substance", allocated_effects$effect)
          ],
        behavioural_response_allocated_eta =
          allocated_effects$shapley_eta_squared[
            match("x5_behaviour", allocated_effects$effect)
          ],
        sbie_rate_endpoint_allocated_eta =
          allocated_effects$shapley_eta_squared[
            match("x3_rates", allocated_effects$effect)
          ],
        interaction_eta = interaction_eta,
        preferred_behavioural_sbs_revenue = preferred_revenue,
        main_effect_ranking =
          paste(main_effects$effect_label, collapse = " > ")
      ) |>
        bind_cols(coverage)
    }
  ))

  list(
    anova = sample_anova,
    main_effects = sample_main_effects,
    summary = sample_summary
  )
}

build_hypothesis_summary <- function(anova_pooled, h4_summary) {
  main_effects <- anova_pooled |>
    filter(interaction_order == 1) |>
    arrange(desc(eta_squared))

  interaction_share <- anova_pooled |>
    filter(interaction_order >= 2) |>
    summarise(value = sum(eta_squared, na.rm = TRUE)) |>
    pull(value)

  tibble(
    metric = c(
      "largest_main_effect",
      "largest_main_effect_eta_squared",
      "h2_supported",
      "interaction_eta_squared",
      "h3_supported_above_10_percent",
      "h4_mean_delta_sbs_minus_universal",
      "h4_wilcoxon_less_p_value"
    ),
    value = as.character(c(
      main_effects$effect_label[1],
      main_effects$eta_squared[1],
      main_effects$effect[1] == "x1_etr",
      interaction_share,
      interaction_share > 0.10,
      h4_summary$mean_delta,
      h4_summary$p_value_less
    ))
  )
}

format_bn <- function(x, digits = 1) {
  formatC(x / 1e9, format = "f", digits = digits, big.mark = ",")
}

format_pct <- function(x, digits = 1) {
  formatC(100 * x, format = "f", digits = digits)
}

signed_log1p <- function(x) {
  sign(x) * log1p(abs(x))
}

nan_to_na <- function(x) {
  if_else(is.nan(x), NA_real_, x)
}

write_generated_latex <- function(anova_pooled, preferred_channel_summary,
                                  country_spread,
                                  preferred_behavioural_channel_summary = NULL) {
  top_anova <- anova_pooled |>
    arrange(desc(eta_squared)) |>
    slice_head(n = 10) |>
    transmute(
      effect = latex_escape(effect_label),
      order = interaction_order,
      share = format_pct(eta_squared)
    )

  channel_table <- preferred_channel_summary |>
    mutate(
      regime_label = case_when(
        factor4_sbs == "universal" ~ "Universal",
        factor4_sbs == "sbs" ~ "SbS",
        TRUE ~ factor4_sbs
      )
    ) |>
    arrange(match(regime_label, c("Universal", "SbS")), channel) |>
    transmute(
      regime = latex_escape(regime_label),
      channel = latex_escape(channel),
      revenue = formatC(revenue_bn, format = "f", digits = 1, big.mark = ",")
    )

  behavioural_channel_table <- if (!is.null(preferred_behavioural_channel_summary)) {
    preferred_behavioural_channel_summary |>
      mutate(
        regime_label = case_when(
          factor4_sbs == "universal" ~ "Universal",
          factor4_sbs == "sbs" ~ "SbS",
          TRUE ~ factor4_sbs
        )
      ) |>
      arrange(match(regime_label, c("Universal", "SbS")), channel) |>
      transmute(
        regime = latex_escape(regime_label),
        channel = latex_escape(channel),
        revenue = formatC(revenue_bn, format = "f", digits = 1, big.mark = ",")
      )
  } else {
    tibble(regime = character(), channel = character(), revenue = character())
  }

  selected_spread <- country_spread |>
    filter(country %in% SELECTED_COUNTRIES) |>
    arrange(match(country, SELECTED_COUNTRIES)) |>
    transmute(
      country = latex_escape(country_name),
      minimum = format_bn(min_revenue),
      maximum = format_bn(max_revenue),
      spread = format_bn(scenario_spread)
    )

  lines <- c(
    "% Generated by code/07_stage4_6_revenue_pipeline_decomposition.R",
    "\\begin{table}[H]",
    "\\centering",
    "\\caption{Pooled factorial decomposition of legally allocated EU GMT revenue}",
    "\\label{tab:stage4_6_anova_pooled_generated}",
    "\\small",
    "\\begin{tabular}{@{}lrr@{}}",
    "\\toprule",
    "Effect & Order & Share (\\%) \\\\",
    "\\midrule",
    paste0(
      top_anova$effect, " & ", top_anova$order, " & ",
      top_anova$share, " \\\\"
    ),
    "\\bottomrule",
    "\\end{tabular}",
    "\\end{table}",
    "",
    if (nrow(behavioural_channel_table) > 0) {
      c(
        "\\begin{table}[H]",
        "\\centering",
        "\\caption{Behavioural preferred-core revenue by collection channel}",
        "\\label{tab:stage4_6_preferred_behavioural_channels_generated}",
        "\\small",
        "\\begin{tabular}{@{}llr@{}}",
        "\\toprule",
        "Regime & Channel & Revenue (USD bn) \\\\",
        "\\midrule",
        paste0(
          behavioural_channel_table$regime, " & ",
          behavioural_channel_table$channel, " & ",
          behavioural_channel_table$revenue, " \\\\"
        ),
        "\\bottomrule",
        "\\end{tabular}",
        "\\end{table}",
        ""
      )
    },
    "\\begin{table}[H]",
    "\\centering",
    "\\caption{Mechanical preferred-core revenue by collection channel}",
    "\\label{tab:stage4_6_preferred_channels_generated}",
    "\\small",
    "\\begin{tabular}{@{}llr@{}}",
    "\\toprule",
    "Regime & Channel & Revenue (USD bn) \\\\",
    "\\midrule",
    paste0(
      channel_table$regime, " & ", channel_table$channel, " & ",
      channel_table$revenue, " \\\\"
    ),
    "\\bottomrule",
    "\\end{tabular}",
    "\\end{table}",
    "",
    "\\begin{table}[H]",
    "\\centering",
    "\\caption{Scenario spread for selected EU Member States}",
    "\\label{tab:stage4_6_country_spread_generated}",
    "\\small",
    "\\begin{tabular}{@{}lrrr@{}}",
    "\\toprule",
    "Country & Minimum & Maximum & Spread (USD bn) \\\\",
    "\\midrule",
    paste0(
      selected_spread$country, " & ", selected_spread$minimum, " & ",
      selected_spread$maximum, " & ", selected_spread$spread, " \\\\"
    ),
    "\\bottomrule",
    "\\end{tabular}",
    "\\end{table}"
  )

  writeLines(lines, file.path(GENERATED_DIR, "stage4_6_results_tables.tex"))
}

run_stage4_6_pipeline <- function(write_latex = TRUE) {
  revenue_country_year <- readRDS(file.path(PROCESSED_DIR, "stage4_5_revenue_country_year.rds"))
  revenue_by_channel <- readRDS(file.path(PROCESSED_DIR, "stage4_5_revenue_by_channel.rds"))
  conservation <- readRDS(file.path(PROCESSED_DIR, "stage4_5_allocation_conservation.rds"))
  cit_revenue <- readRDS(file.path(PROCESSED_DIR, "cit_revenue.rds"))
  wb_gdp <- readRDS(file.path(PROCESSED_DIR, "wb_gdp.rds"))
  wb_population <- readRDS(file.path(PROCESSED_DIR, "wb_population.rds"))
  stage1_bilateral <- readRDS(file.path(PROCESSED_DIR, "stage1_bilateral_panel.rds"))
  stage1_affiliate_year <- readRDS(file.path(PROCESSED_DIR, "stage1_affiliate_year.rds"))

  validation_summary <- validate_revenue_inputs(
    revenue_country_year,
    revenue_by_channel,
    conservation
  )

  scenario_summary <- build_scenario_summary(revenue_country_year)
  scenario_design <- build_scenario_design_table(revenue_country_year)
  anova_objects <- compute_factorial_anova(revenue_country_year)
  anova_pooled_taxonomy <- add_decomposition_taxonomy(anova_objects$pooled)
  shapley_attribution <- build_shapley_factor_attribution(anova_objects$pooled)
  uncertainty_summary <- build_uncertainty_summary(anova_objects$pooled)
  country_scenario_totals <- build_country_scenario_totals(revenue_country_year)
  scenario_spread_country_year <- build_scenario_spread(revenue_country_year)
  scenario_spread_country <- build_country_spread(country_scenario_totals)

  main_effects_pooled <- compute_main_effects(
    scenario_summary |> rename(revenue = eu_revenue),
    revenue_col = "revenue"
  )
  main_effects_by_country <- compute_main_effects(
    country_scenario_totals |> rename(revenue = country_revenue),
    revenue_col = "revenue",
    group_vars = c("country", "country_name")
  )

  h4_pairs <- build_h4_pairs(revenue_country_year)
  h4_summary <- build_h4_summary(h4_pairs)
  preferred_outputs <- build_preferred_outputs(
    revenue_country_year,
    revenue_by_channel,
    behaviour = "mechanical"
  )
  preferred_behavioural_outputs <- build_preferred_outputs(
    revenue_country_year,
    revenue_by_channel,
    behaviour = "behavioural"
  )
  preferred_behavioural_channel_country_year <-
    build_preferred_channel_country_year(
      revenue_by_channel,
      behaviour = "behavioural"
    )
  fiscal_salience_country_year <- build_fiscal_salience_country_year(
    preferred_behavioural_outputs$country_year,
    preferred_behavioural_channel_country_year,
    scenario_spread_country_year,
    cit_revenue,
    wb_gdp,
    wb_population
  )
  fiscal_salience_country <- build_fiscal_salience_country(
    fiscal_salience_country_year
  )
  country_typology_feature_matrix <- build_country_typology_feature_matrix(
    fiscal_salience_country,
    main_effects_by_country,
    preferred_behavioural_channel_country_year,
    stage1_bilateral
  )
  country_typology_pca <- run_country_typology_pca(
    country_typology_feature_matrix
  )
  country_typology_stability <- build_cluster_stability(
    country_typology_pca$scaled
  )
  country_typology_clusters <- run_country_typology_clusters(
    country_typology_feature_matrix,
    country_typology_pca$scaled,
    selected_k = 4L
  )
  measurement_sample_decomposition <-
    build_measurement_sample_decomposition(
      revenue_country_year,
      stage1_bilateral,
      stage1_affiliate_year
    )
  hypothesis_summary <- build_hypothesis_summary(
    anova_objects$pooled,
    h4_summary
  )

  stage4_6_summary <- bind_rows(
    validation_summary,
    tibble(
      metric = c(
        "eu_revenue_min_scenario",
        "eu_revenue_max_scenario",
        "eu_revenue_scenario_spread",
        "pooled_interaction_eta_squared",
        "preferred_universal_revenue",
        "preferred_sbs_revenue",
        "preferred_behavioural_universal_revenue",
        "preferred_behavioural_sbs_revenue"
      ),
      value = as.character(c(
        min(scenario_summary$eu_revenue, na.rm = TRUE),
        max(scenario_summary$eu_revenue, na.rm = TRUE),
        max(scenario_summary$eu_revenue, na.rm = TRUE) -
          min(scenario_summary$eu_revenue, na.rm = TRUE),
        sum(anova_objects$pooled$eta_squared[
          anova_objects$pooled$interaction_order >= 2
        ], na.rm = TRUE),
        sum(preferred_outputs$country_year$revenue[
          preferred_outputs$country_year$factor4_sbs == "universal"
        ], na.rm = TRUE),
        sum(preferred_outputs$country_year$revenue[
          preferred_outputs$country_year$factor4_sbs == "sbs"
        ], na.rm = TRUE),
        sum(preferred_behavioural_outputs$country_year$revenue[
          preferred_behavioural_outputs$country_year$factor4_sbs == "universal"
        ], na.rm = TRUE),
        sum(preferred_behavioural_outputs$country_year$revenue[
          preferred_behavioural_outputs$country_year$factor4_sbs == "sbs"
        ], na.rm = TRUE)
      ))
    )
  )

  write_csv(
    stage4_6_summary,
    file.path(DIAGNOSTICS_DIR, "step7_stage4_6_summary.csv")
  )
  write_csv(
    hypothesis_summary,
    file.path(DIAGNOSTICS_DIR, "step7_stage4_6_hypothesis_summary.csv")
  )
  write_csv(
    scenario_summary,
    file.path(DIAGNOSTICS_DIR, "step7_stage4_6_scenario_summary.csv")
  )
  write_csv(
    scenario_design,
    file.path(DIAGNOSTICS_DIR, "step7_stage4_6_scenario_design.csv")
  )
  write_csv(
    scenario_spread_country_year,
    file.path(DIAGNOSTICS_DIR, "step7_stage4_6_scenario_spread_country_year.csv")
  )
  write_csv(
    scenario_spread_country,
    file.path(DIAGNOSTICS_DIR, "step7_stage4_6_scenario_spread_country.csv")
  )
  write_csv(
    anova_objects$pooled,
    file.path(DIAGNOSTICS_DIR, "step7_stage4_6_anova_pooled.csv")
  )
  write_csv(
    anova_pooled_taxonomy,
    file.path(DIAGNOSTICS_DIR, "step7_stage4_6_structural_variance_pooled.csv")
  )
  write_csv(
    shapley_attribution,
    file.path(DIAGNOSTICS_DIR, "step7_stage4_6_shapley_factor_attribution.csv")
  )
  write_csv(
    uncertainty_summary,
    file.path(DIAGNOSTICS_DIR, "step7_stage4_6_uncertainty_summary.csv")
  )
  write_csv(
    anova_objects$by_country,
    file.path(DIAGNOSTICS_DIR, "step7_stage4_6_anova_by_country.csv")
  )
  write_csv(
    anova_objects$by_country_year,
    file.path(DIAGNOSTICS_DIR, "step7_stage4_6_anova_by_country_year.csv")
  )
  write_csv(
    main_effects_pooled,
    file.path(DIAGNOSTICS_DIR, "step7_stage4_6_main_effects_pooled.csv")
  )
  write_csv(
    main_effects_by_country,
    file.path(DIAGNOSTICS_DIR, "step7_stage4_6_main_effects_by_country.csv")
  )
  write_csv(
    h4_summary,
    file.path(DIAGNOSTICS_DIR, "step7_stage4_6_h4_wilcoxon.csv")
  )
  write_csv(
    h4_pairs,
    file.path(DIAGNOSTICS_DIR, "step7_stage4_6_h4_pairs.csv")
  )
  write_csv(
    preferred_outputs$channel_summary,
    file.path(DIAGNOSTICS_DIR, "step7_stage4_6_preferred_channel_summary.csv")
  )
  write_csv(
    preferred_outputs$year_channel,
    file.path(DIAGNOSTICS_DIR, "step7_stage4_6_preferred_channel_by_year.csv")
  )
  write_csv(
    preferred_outputs$country_year,
    file.path(DIAGNOSTICS_DIR, "step7_stage4_6_preferred_country_year.csv")
  )
  write_csv(
    preferred_behavioural_outputs$channel_summary,
    file.path(
      DIAGNOSTICS_DIR,
      "step7_stage4_6_preferred_behavioural_channel_summary.csv"
    )
  )
  write_csv(
    preferred_behavioural_outputs$year_channel,
    file.path(
      DIAGNOSTICS_DIR,
      "step7_stage4_6_preferred_behavioural_channel_by_year.csv"
    )
  )
  write_csv(
    preferred_behavioural_outputs$country_year,
    file.path(
      DIAGNOSTICS_DIR,
      "step7_stage4_6_preferred_behavioural_country_year.csv"
    )
  )
  write_csv(
    fiscal_salience_country_year,
    file.path(
      DIAGNOSTICS_DIR,
      "step7_stage4_6_fiscal_salience_country_year.csv"
    )
  )
  write_csv(
    fiscal_salience_country,
    file.path(
      DIAGNOSTICS_DIR,
      "step7_stage4_6_fiscal_salience_country.csv"
    )
  )
  write_csv(
    country_typology_feature_matrix,
    file.path(
      DIAGNOSTICS_DIR,
      "step7_stage4_6_country_typology_feature_matrix.csv"
    )
  )
  write_csv(
    country_typology_pca$summary,
    file.path(
      DIAGNOSTICS_DIR,
      "step7_stage4_6_country_typology_pca_summary.csv"
    )
  )
  write_csv(
    country_typology_pca$loadings,
    file.path(
      DIAGNOSTICS_DIR,
      "step7_stage4_6_country_typology_pca_loadings.csv"
    )
  )
  write_csv(
    country_typology_pca$scores,
    file.path(
      DIAGNOSTICS_DIR,
      "step7_stage4_6_country_typology_pca_scores.csv"
    )
  )
  write_csv(
    country_typology_pca$imputation_summary,
    file.path(
      DIAGNOSTICS_DIR,
      "step7_stage4_6_country_typology_imputation.csv"
    )
  )
  write_csv(
    country_typology_stability,
    file.path(
      DIAGNOSTICS_DIR,
      "step7_stage4_6_country_typology_cluster_stability.csv"
    )
  )
  write_csv(
    country_typology_clusters$clusters,
    file.path(
      DIAGNOSTICS_DIR,
      "step7_stage4_6_country_typology_clusters.csv"
    )
  )
  write_csv(
    country_typology_clusters$profiles,
    file.path(
      DIAGNOSTICS_DIR,
      "step7_stage4_6_country_typology_cluster_profiles.csv"
    )
  )
  write_csv(
    measurement_sample_decomposition$anova,
    file.path(
      DIAGNOSTICS_DIR,
      "step7_stage4_6_measurement_sample_anova.csv"
    )
  )
  write_csv(
    measurement_sample_decomposition$main_effects,
    file.path(
      DIAGNOSTICS_DIR,
      "step7_stage4_6_measurement_sample_main_effects.csv"
    )
  )
  write_csv(
    measurement_sample_decomposition$summary,
    file.path(
      DIAGNOSTICS_DIR,
      "step7_stage4_6_measurement_sample_summary.csv"
    )
  )

  saveRDS(scenario_summary, file.path(PROCESSED_DIR, "stage4_6_scenario_summary.rds"))
  saveRDS(
    scenario_spread_country_year,
    file.path(PROCESSED_DIR, "stage4_6_scenario_spread_country_year.rds")
  )
  saveRDS(
    scenario_spread_country,
    file.path(PROCESSED_DIR, "stage4_6_scenario_spread_country.rds")
  )
  saveRDS(anova_objects$pooled, file.path(PROCESSED_DIR, "stage4_6_anova_pooled.rds"))
  saveRDS(
    anova_pooled_taxonomy,
    file.path(PROCESSED_DIR, "stage4_6_structural_variance_pooled.rds")
  )
  saveRDS(
    shapley_attribution,
    file.path(PROCESSED_DIR, "stage4_6_shapley_factor_attribution.rds")
  )
  saveRDS(
    uncertainty_summary,
    file.path(PROCESSED_DIR, "stage4_6_uncertainty_summary.rds")
  )
  saveRDS(
    anova_objects$by_country,
    file.path(PROCESSED_DIR, "stage4_6_anova_by_country.rds")
  )
  saveRDS(
    anova_objects$by_country_year,
    file.path(PROCESSED_DIR, "stage4_6_anova_by_country_year.rds")
  )
  saveRDS(
    main_effects_pooled,
    file.path(PROCESSED_DIR, "stage4_6_main_effects_pooled.rds")
  )
  saveRDS(
    main_effects_by_country,
    file.path(PROCESSED_DIR, "stage4_6_main_effects_by_country.rds")
  )
  saveRDS(h4_pairs, file.path(PROCESSED_DIR, "stage4_6_h4_pairs.rds"))
  saveRDS(
    preferred_outputs$country_year,
    file.path(PROCESSED_DIR, "stage4_6_preferred_country_year.rds")
  )
  saveRDS(
    preferred_outputs$channel_summary,
    file.path(PROCESSED_DIR, "stage4_6_preferred_channel_summary.rds")
  )
  saveRDS(
    preferred_behavioural_outputs$country_year,
    file.path(PROCESSED_DIR, "stage4_6_preferred_behavioural_country_year.rds")
  )
  saveRDS(
    preferred_behavioural_outputs$channel_summary,
    file.path(
      PROCESSED_DIR,
      "stage4_6_preferred_behavioural_channel_summary.rds"
    )
  )
  saveRDS(
    fiscal_salience_country_year,
    file.path(PROCESSED_DIR, "stage4_6_fiscal_salience_country_year.rds")
  )
  saveRDS(
    fiscal_salience_country,
    file.path(PROCESSED_DIR, "stage4_6_fiscal_salience_country.rds")
  )
  saveRDS(
    country_typology_feature_matrix,
    file.path(PROCESSED_DIR, "stage4_6_country_typology_feature_matrix.rds")
  )
  saveRDS(
    country_typology_pca$summary,
    file.path(PROCESSED_DIR, "stage4_6_country_typology_pca_summary.rds")
  )
  saveRDS(
    country_typology_pca$loadings,
    file.path(PROCESSED_DIR, "stage4_6_country_typology_pca_loadings.rds")
  )
  saveRDS(
    country_typology_pca$scores,
    file.path(PROCESSED_DIR, "stage4_6_country_typology_pca_scores.rds")
  )
  saveRDS(
    country_typology_pca$imputation_summary,
    file.path(PROCESSED_DIR, "stage4_6_country_typology_imputation.rds")
  )
  saveRDS(
    country_typology_stability,
    file.path(PROCESSED_DIR, "stage4_6_country_typology_cluster_stability.rds")
  )
  saveRDS(
    country_typology_clusters$clusters,
    file.path(PROCESSED_DIR, "stage4_6_country_typology_clusters.rds")
  )
  saveRDS(
    country_typology_clusters$profiles,
    file.path(PROCESSED_DIR, "stage4_6_country_typology_cluster_profiles.rds")
  )
  saveRDS(
    measurement_sample_decomposition$anova,
    file.path(PROCESSED_DIR, "stage4_6_measurement_sample_anova.rds")
  )
  saveRDS(
    measurement_sample_decomposition$main_effects,
    file.path(PROCESSED_DIR, "stage4_6_measurement_sample_main_effects.rds")
  )
  saveRDS(
    measurement_sample_decomposition$summary,
    file.path(PROCESSED_DIR, "stage4_6_measurement_sample_summary.rds")
  )
  saveRDS(
    hypothesis_summary,
    file.path(PROCESSED_DIR, "stage4_6_hypothesis_summary.rds")
  )

  if (write_latex) {
    write_generated_latex(
      anova_objects$pooled,
      preferred_outputs$channel_summary,
      scenario_spread_country,
      preferred_behavioural_outputs$channel_summary
    )
  }

  message("\nStep 7 outputs written:")
  message(" - data/processed/stage4_6_anova_*.rds")
  message(" - data/processed/stage4_6_shapley_factor_attribution.rds")
  message(" - data/processed/stage4_6_uncertainty_summary.rds")
  message(" - data/processed/stage4_6_scenario_spread_*.rds")
  message(" - data/processed/stage4_6_preferred_*.rds")
  message(" - data/processed/stage4_6_fiscal_salience_*.rds")
  message(" - data/processed/stage4_6_country_typology_*.rds")
  message(" - data/processed/stage4_6_measurement_sample_*.rds")
  message(" - diagnostics/step7_stage4_6_*.csv")
  if (write_latex) message(" - writing/generated/stage4_6_results_tables.tex")
}

