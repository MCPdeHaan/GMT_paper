# 07_stage4_6_revenue_pipeline_decomposition.R
# Step 7 of the methodology pipeline.
#
# Executes the Section 4.6 revenue pipeline after the legal Stage 4.5
# allocation. The script treats the Stage 4.5 country-year revenue matrix as
# the final object for the 2^5 counterfactual decomposition.
library(dplyr); library(tidyr); library(readr); library(tibble); library(stringr)

IN   <- "data/processed"
OUT  <- IN
DIAG <- file.path(OUT, "diagnostics")
GEN  <- "writing/generated"
dir.create(DIAG, showWarnings = FALSE, recursive = TRUE)
dir.create(GEN, showWarnings = FALSE, recursive = TRUE)

MAIN_YEARS <- 2017:2022
SELECTED_COUNTRIES <- c("NLD", "IRL", "LUX", "DEU", "FRA")

SCENARIO_VARS <- c(
  "scenario_id", "rate_scenario", "factor1_etr", "factor2_substance",
  "factor3_rates", "factor4_sbs", "factor5_behaviour", "x1_etr",
  "x2_substance", "x3_rates", "x4_sbs", "x5_behaviour"
)

FACTOR_COLS <- c("x1_etr", "x2_substance", "x3_rates", "x4_sbs",
                 "x5_behaviour")

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

assert_unique_keys <- function(df, keys, label) {
  n_dup <- df |>
    count(across(all_of(keys))) |>
    filter(n > 1) |>
    nrow()

  if (n_dup > 0) stop(sprintf("%s: %d duplicate key combinations", label, n_dup))
}

safe_divide <- function(num, den) {
  if_else(is.na(num) | is.na(den) | den == 0, NA_real_, num / den)
}

coalesce_zero <- function(x) {
  if_else(is.na(x), 0, x)
}

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
      scenario_id_check = paste0("x", x1_etr, x2_substance, x3_rates,
                                 x4_sbs, x5_behaviour),
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
                                 allocated_eta_squared, 0),
      interaction_eta_squared = if_else(interaction_order >= 2L,
                                        allocated_eta_squared, 0)
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
        select(effect, effect_label = mechanism_class, economic_object,
               uncertainty_class),
      by = "effect"
    ) |>
    mutate(factor_label = FACTOR_LABELS[effect]) |>
    relocate(factor_label, effect_label, economic_object,
             uncertainty_class, .after = effect) |>
    arrange(desc(shapley_eta_squared))
}

build_uncertainty_summary <- function(anova_df) {
  add_decomposition_taxonomy(anova_df) |>
    mutate(effect_eta_squared = eta_squared) |>
    group_by(uncertainty_class) |>
    summarise(
      eta_squared = sum(effect_eta_squared, na.rm = TRUE),
      main_eta_squared = sum(if_else(interaction_order == 1L,
                                     effect_eta_squared, 0), na.rm = TRUE),
      interaction_eta_squared = sum(if_else(interaction_order >= 2L,
                                            effect_eta_squared, 0),
                                    na.rm = TRUE),
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
      pivot_wider(names_from = level, values_from = mean_revenue,
                  names_prefix = "level_") |>
      mutate(
        high_minus_low = level_1 - level_0,
        pct_high_minus_low = safe_divide(high_minus_low, level_0)
      )
  })) |>
    left_join(FACTOR_LEVELS, by = "effect") |>
    relocate(low_level, high_level, .after = effect_label)
}

build_h4_pairs <- function(revenue_country_year) {
  other_factors <- c("rate_scenario", "factor1_etr", "factor2_substance",
                     "factor5_behaviour", "country", "country_name", "year")

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
                                 na.rm = TRUE),
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

latex_escape <- function(x) {
  x |>
    str_replace_all("&", "\\\\&") |>
    str_replace_all("_", "\\\\_")
}

format_bn <- function(x, digits = 1) {
  formatC(x / 1e9, format = "f", digits = digits, big.mark = ",")
}

format_pct <- function(x, digits = 1) {
  formatC(100 * x, format = "f", digits = digits)
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
    paste0(top_anova$effect, " & ", top_anova$order, " & ",
           top_anova$share, " \\\\"),
    "\\bottomrule",
    "\\end{tabular}",
    "\\end{table}",
    "",
    if (nrow(behavioural_channel_table) > 0) c(
      "\\begin{table}[H]",
      "\\centering",
      "\\caption{Behavioural preferred-core revenue by collection channel}",
      "\\label{tab:stage4_6_preferred_behavioural_channels_generated}",
      "\\small",
      "\\begin{tabular}{@{}llr@{}}",
      "\\toprule",
      "Regime & Channel & Revenue (USD bn) \\\\",
      "\\midrule",
      paste0(behavioural_channel_table$regime, " & ",
             behavioural_channel_table$channel, " & ",
             behavioural_channel_table$revenue, " \\\\"),
      "\\bottomrule",
      "\\end{tabular}",
      "\\end{table}",
      ""
    ),
    "\\begin{table}[H]",
    "\\centering",
    "\\caption{Mechanical preferred-core revenue by collection channel}",
    "\\label{tab:stage4_6_preferred_channels_generated}",
    "\\small",
    "\\begin{tabular}{@{}llr@{}}",
    "\\toprule",
    "Regime & Channel & Revenue (USD bn) \\\\",
    "\\midrule",
    paste0(channel_table$regime, " & ", channel_table$channel, " & ",
           channel_table$revenue, " \\\\"),
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
    paste0(selected_spread$country, " & ", selected_spread$minimum, " & ",
           selected_spread$maximum, " & ", selected_spread$spread, " \\\\"),
    "\\bottomrule",
    "\\end{tabular}",
    "\\end{table}"
  )

  writeLines(lines, file.path(GEN, "stage4_6_results_tables.tex"))
}

run_stage4_6_pipeline <- function() {
  revenue_country_year <- readRDS(file.path(IN, "stage4_5_revenue_country_year.rds"))
  revenue_by_channel <- readRDS(file.path(IN, "stage4_5_revenue_by_channel.rds"))
  conservation <- readRDS(file.path(IN, "stage4_5_allocation_conservation.rds"))

  validation_summary <- validate_revenue_inputs(
    revenue_country_year,
    revenue_by_channel,
    conservation
  )

  scenario_summary <- build_scenario_summary(revenue_country_year)
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
  hypothesis_summary <- build_hypothesis_summary(anova_objects$pooled,
                                                 h4_summary)

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

  write_csv(stage4_6_summary,
            file.path(DIAG, "step7_stage4_6_summary.csv"))
  write_csv(hypothesis_summary,
            file.path(DIAG, "step7_stage4_6_hypothesis_summary.csv"))
  write_csv(scenario_summary,
            file.path(DIAG, "step7_stage4_6_scenario_summary.csv"))
  write_csv(scenario_spread_country_year,
            file.path(DIAG, "step7_stage4_6_scenario_spread_country_year.csv"))
  write_csv(scenario_spread_country,
            file.path(DIAG, "step7_stage4_6_scenario_spread_country.csv"))
  write_csv(anova_objects$pooled,
            file.path(DIAG, "step7_stage4_6_anova_pooled.csv"))
  write_csv(anova_pooled_taxonomy,
            file.path(DIAG, "step7_stage4_6_structural_variance_pooled.csv"))
  write_csv(shapley_attribution,
            file.path(DIAG, "step7_stage4_6_shapley_factor_attribution.csv"))
  write_csv(uncertainty_summary,
            file.path(DIAG, "step7_stage4_6_uncertainty_summary.csv"))
  write_csv(anova_objects$by_country,
            file.path(DIAG, "step7_stage4_6_anova_by_country.csv"))
  write_csv(anova_objects$by_country_year,
            file.path(DIAG, "step7_stage4_6_anova_by_country_year.csv"))
  write_csv(main_effects_pooled,
            file.path(DIAG, "step7_stage4_6_main_effects_pooled.csv"))
  write_csv(main_effects_by_country,
            file.path(DIAG, "step7_stage4_6_main_effects_by_country.csv"))
  write_csv(h4_summary,
            file.path(DIAG, "step7_stage4_6_h4_wilcoxon.csv"))
  write_csv(h4_pairs,
            file.path(DIAG, "step7_stage4_6_h4_pairs.csv"))
  write_csv(preferred_outputs$channel_summary,
            file.path(DIAG, "step7_stage4_6_preferred_channel_summary.csv"))
  write_csv(preferred_outputs$year_channel,
            file.path(DIAG, "step7_stage4_6_preferred_channel_by_year.csv"))
  write_csv(preferred_outputs$country_year,
            file.path(DIAG, "step7_stage4_6_preferred_country_year.csv"))
  write_csv(preferred_behavioural_outputs$channel_summary,
            file.path(DIAG,
                      "step7_stage4_6_preferred_behavioural_channel_summary.csv"))
  write_csv(preferred_behavioural_outputs$year_channel,
            file.path(DIAG,
                      "step7_stage4_6_preferred_behavioural_channel_by_year.csv"))
  write_csv(preferred_behavioural_outputs$country_year,
            file.path(DIAG,
                      "step7_stage4_6_preferred_behavioural_country_year.csv"))

  saveRDS(scenario_summary, file.path(OUT, "stage4_6_scenario_summary.rds"))
  saveRDS(scenario_spread_country_year,
          file.path(OUT, "stage4_6_scenario_spread_country_year.rds"))
  saveRDS(scenario_spread_country,
          file.path(OUT, "stage4_6_scenario_spread_country.rds"))
  saveRDS(anova_objects$pooled, file.path(OUT, "stage4_6_anova_pooled.rds"))
  saveRDS(anova_pooled_taxonomy,
          file.path(OUT, "stage4_6_structural_variance_pooled.rds"))
  saveRDS(shapley_attribution,
          file.path(OUT, "stage4_6_shapley_factor_attribution.rds"))
  saveRDS(uncertainty_summary,
          file.path(OUT, "stage4_6_uncertainty_summary.rds"))
  saveRDS(anova_objects$by_country,
          file.path(OUT, "stage4_6_anova_by_country.rds"))
  saveRDS(anova_objects$by_country_year,
          file.path(OUT, "stage4_6_anova_by_country_year.rds"))
  saveRDS(main_effects_pooled,
          file.path(OUT, "stage4_6_main_effects_pooled.rds"))
  saveRDS(main_effects_by_country,
          file.path(OUT, "stage4_6_main_effects_by_country.rds"))
  saveRDS(h4_pairs, file.path(OUT, "stage4_6_h4_pairs.rds"))
  saveRDS(preferred_outputs$country_year,
          file.path(OUT, "stage4_6_preferred_country_year.rds"))
  saveRDS(preferred_outputs$channel_summary,
          file.path(OUT, "stage4_6_preferred_channel_summary.rds"))
  saveRDS(preferred_behavioural_outputs$country_year,
          file.path(OUT, "stage4_6_preferred_behavioural_country_year.rds"))
  saveRDS(preferred_behavioural_outputs$channel_summary,
          file.path(OUT,
                    "stage4_6_preferred_behavioural_channel_summary.rds"))
  saveRDS(hypothesis_summary,
          file.path(OUT, "stage4_6_hypothesis_summary.rds"))

  write_generated_latex(anova_objects$pooled,
                        preferred_outputs$channel_summary,
                        scenario_spread_country,
                        preferred_behavioural_outputs$channel_summary)

  results_table_script <- file.path("code", "08_generate_results_tables.R")
  if (file.exists(results_table_script)) {
    source(results_table_script)
    write_results_tables()
  }

  message("\nStep 7 outputs written:")
  message(" - data/processed/stage4_6_anova_*.rds")
  message(" - data/processed/stage4_6_shapley_factor_attribution.rds")
  message(" - data/processed/stage4_6_uncertainty_summary.rds")
  message(" - data/processed/stage4_6_scenario_spread_*.rds")
  message(" - data/processed/stage4_6_preferred_*.rds")
  message(" - diagnostics/step7_stage4_6_*.csv")
  message(" - writing/generated/stage4_6_results_tables.tex")
  message(" - writing/generated/results_tables/*.tex")
  message(" - writing/generated/results_appendix_tables.tex")
}

is_direct_script_run <- function(script_path) {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) == 0) return(FALSE)

  invoked_path <- sub("^--file=", "", file_arg[1])
  normalizePath(invoked_path, winslash = "/", mustWork = FALSE) ==
    normalizePath(script_path, winslash = "/", mustWork = FALSE)
}

if (is_direct_script_run("code/07_stage4_6_revenue_pipeline_decomposition.R")) {
  run_stage4_6_pipeline()
}
