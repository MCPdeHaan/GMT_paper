# 10_jurisdiction_influence_robustness.R
# Step 10 of the methodology pipeline.
#
# Influence diagnostics for the public CbCR panel. The script asks whether the
# Stage 3 semi-elasticity, Stage 1 liability rate and final EU revenue
# decomposition are driven by one large parent or affiliate jurisdiction.
library(dplyr)
library(tidyr)
library(readr)
library(purrr)
library(tibble)
library(stringr)

source("code/00_helpers.R", local = TRUE)

source("code/05_stage3_behavioral.R", local = TRUE)
stage3_estimate_models <- estimate_stage3_models
stage3_semielasticity_schedule_fn <- stage3_semielasticity_schedule
stage3_build_model_diagnostics <- build_model_diagnostics

source("code/06_stage4_5_revenue_allocation_sbs.R", local = TRUE)
stage45_build_source_panel <- build_source_panel
stage45_build_collector_activity <- build_collector_activity
stage45_build_parent_year_utpr_weights <- build_parent_year_utpr_weights
stage45_allocate_stage4_revenue <- allocate_stage4_revenue
stage45_build_conservation_diagnostics <- build_conservation_diagnostics

source("code/07_stage4_6_revenue_pipeline_decomposition.R", local = TRUE)
stage46_build_scenario_summary <- build_scenario_summary
stage46_compute_factorial_anova <- compute_factorial_anova
stage46_compute_main_effects <- compute_main_effects


DEFAULT_TOP_N <- 8L
NAMED_INFLUENCE_JURISDICTIONS <- c(
  "USA", "NLD", "IRL", "LUX", "DEU", "FRA", "CHE", "SGP"
)
AGGREGATE_CODES <- c(
  "W", "WXD", "STLS", "A", "A_O", "E", "E_O", "F", "F_O", "S", "S_O",
  "OECD", "EU27_2020", "EA19"
)
PREFERRED_CORE_FILTER <- rlang::expr(
  factor1_etr == "distributional" &
    factor2_substance == "aggregate_sbie" &
    rate_scenario == "initial"
)

is_jurisdiction_code <- function(x) {
  str_detect(x, "^[A-Z]{3}$") & !x %in% AGGREGATE_CODES
}

case_id <- function(leave_dimension, jurisdiction) {
  paste(leave_dimension, jurisdiction, sep = "_")
}

parse_arg_int <- function(prefix, default) {
  arg <- grep(paste0("^", prefix), commandArgs(trailingOnly = TRUE), value = TRUE)
  if (length(arg) == 0) {
    return(default)
  }
  as.integer(sub(prefix, "", arg[1]))
}

first_available <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) {
    return(NA_character_)
  }
  as.character(x[1])
}

build_jurisdiction_lookup <- function(stage1_bilateral, stage3_panel) {
  bind_rows(
    stage1_bilateral |>
      transmute(
        jurisdiction = parent,
        jurisdiction_name = parent_jurisdiction_name
      ),
    stage1_bilateral |>
      transmute(
        jurisdiction = affiliate,
        jurisdiction_name = affiliate_jurisdiction_name
      ),
    stage3_panel |>
      transmute(
        jurisdiction = parent,
        jurisdiction_name = parent_jurisdiction_name
      ),
    stage3_panel |>
      transmute(
        jurisdiction = affiliate,
        jurisdiction_name = affiliate_jurisdiction_name
      )
  ) |>
    filter(is_jurisdiction_code(jurisdiction)) |>
    group_by(jurisdiction) |>
    summarise(
      jurisdiction_name = first_available(jurisdiction_name),
      .groups = "drop"
    )
}

build_country_lookup <- function(stage3_panel) {
  stage3_panel |>
    transmute(
      country = affiliate,
      country_name = affiliate_jurisdiction_name
    ) |>
    filter(country %in% EU27_ISO3) |>
    group_by(country) |>
    summarise(country_name = first_available(country_name), .groups = "drop")
}

summarise_stage1_liability <- function(stage1_bilateral, case_id_value) {
  bind_rows(
    stage1_bilateral |>
      filter(year %in% MAIN_YEARS, stage1_positive_profit_flag) |>
      mutate(scope = "global"),
    stage1_bilateral |>
      filter(
        year %in% MAIN_YEARS, stage1_positive_profit_flag,
        affiliate_is_eu27
      ) |>
      mutate(scope = "eu27")
  ) |>
    group_by(scope) |>
    summarise(
      positive_profit = sum(analysis_profit_positive, na.rm = TRUE),
      average_topup_tax = sum(stage1_topup_tax_average, na.rm = TRUE),
      distributional_topup_tax =
        sum(stage1_topup_tax_distributional, na.rm = TRUE),
      average_liability_rate =
        safe_divide(average_topup_tax, positive_profit),
      distributional_liability_rate =
        safe_divide(distributional_topup_tax, positive_profit),
      pair_years = n(),
      parents = n_distinct(parent),
      affiliates = n_distinct(affiliate),
      .groups = "drop"
    ) |>
    mutate(case_id = case_id_value, .before = 1)
}

summarise_case_dropped_mass <- function(stage1_bilateral, estimation_sample,
                                        leave_dimension, jurisdiction) {
  dropped_stage1 <- stage1_bilateral |>
    filter(
      .data[[leave_dimension]] == jurisdiction,
      year %in% MAIN_YEARS,
      stage1_positive_profit_flag
    ) |>
    summarise(
      dropped_stage1_pair_years = n(),
      dropped_stage1_profit =
        sum(analysis_profit_positive, na.rm = TRUE),
      dropped_stage1_topup =
        sum(stage1_topup_tax_distributional, na.rm = TRUE),
      .groups = "drop"
    )

  total_stage1 <- stage1_bilateral |>
    filter(year %in% MAIN_YEARS, stage1_positive_profit_flag) |>
    summarise(
      total_stage1_profit = sum(analysis_profit_positive, na.rm = TRUE),
      total_stage1_topup =
        sum(stage1_topup_tax_distributional, na.rm = TRUE),
      .groups = "drop"
    )

  dropped_stage3_rows <- estimation_sample |>
    filter(.data[[leave_dimension]] == jurisdiction) |>
    summarise(
      dropped_estimation_rows = n(),
      dropped_estimation_pairs = n_distinct(pair_id),
      .groups = "drop"
    )

  bind_cols(dropped_stage1, total_stage1, dropped_stage3_rows) |>
    mutate(
      dropped_stage1_profit_share =
        safe_divide(dropped_stage1_profit, total_stage1_profit),
      dropped_stage1_topup_share =
        safe_divide(dropped_stage1_topup, total_stage1_topup)
    )
}

build_influence_targets <- function(stage1_bilateral, estimation_sample,
                                    jurisdiction_lookup,
                                    top_n = DEFAULT_TOP_N) {
  stage1_scope <- stage1_bilateral |>
    filter(year %in% MAIN_YEARS, stage1_positive_profit_flag)

  top_parent <- stage1_scope |>
    filter(is_jurisdiction_code(parent)) |>
    group_by(jurisdiction = parent) |>
    summarise(
      leverage_profit = sum(analysis_profit_positive, na.rm = TRUE),
      leverage_topup = sum(stage1_topup_tax_distributional, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(desc(leverage_profit)) |>
    slice_head(n = top_n) |>
    mutate(leave_dimension = "parent", target_reason = "high_leverage")

  top_affiliate <- stage1_scope |>
    filter(is_jurisdiction_code(affiliate)) |>
    group_by(jurisdiction = affiliate) |>
    summarise(
      leverage_profit = sum(analysis_profit_positive, na.rm = TRUE),
      leverage_topup = sum(stage1_topup_tax_distributional, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(desc(leverage_profit)) |>
    slice_head(n = top_n) |>
    mutate(leave_dimension = "affiliate", target_reason = "high_leverage")

  available_targets <- bind_rows(
    estimation_sample |>
      distinct(leave_dimension = "parent", jurisdiction = parent),
    estimation_sample |>
      distinct(leave_dimension = "affiliate", jurisdiction = affiliate)
  ) |>
    filter(is_jurisdiction_code(jurisdiction))

  named_targets <- tidyr::expand_grid(
    leave_dimension = c("parent", "affiliate"),
    jurisdiction = NAMED_INFLUENCE_JURISDICTIONS
  ) |>
    semi_join(available_targets, by = c("leave_dimension", "jurisdiction")) |>
    mutate(
      leverage_profit = NA_real_,
      leverage_topup = NA_real_,
      target_reason = "named"
    )

  bind_rows(top_parent, top_affiliate, named_targets) |>
    group_by(leave_dimension, jurisdiction) |>
    summarise(
      target_reason = paste(sort(unique(target_reason)), collapse = "+"),
      leverage_profit = max_or_na(leverage_profit),
      leverage_topup = max_or_na(leverage_topup),
      .groups = "drop"
    ) |>
    mutate(
      included_high_leverage = str_detect(target_reason, "high_leverage"),
      included_named_target = str_detect(target_reason, "named"),
      target_inclusion_reason = case_when(
        included_high_leverage & included_named_target ~ "both",
        included_high_leverage ~ "high_leverage",
        included_named_target ~ "named_target",
        TRUE ~ "unspecified"
      ),
      case_id = case_id(leave_dimension, jurisdiction)
    ) |>
    left_join(jurisdiction_lookup, by = "jurisdiction") |>
    arrange(
      leave_dimension, desc(str_detect(target_reason, "named")),
      desc(leverage_profit), jurisdiction
    )
}

filter_leave_one <- function(df, leave_dimension, jurisdiction) {
  df |>
    filter(.data[[leave_dimension]] != jurisdiction)
}

fit_leave_one_semielasticity <- function(estimation_sample, leave_dimension,
                                         jurisdiction, case_id_value) {
  sample_case <- filter_leave_one(estimation_sample, leave_dimension, jurisdiction)
  model_fits <- stage3_estimate_models(sample_case)

  list(
    model_comparison = stage3_build_model_diagnostics(model_fits, case_id_value),
    semielasticity = stage3_semielasticity_schedule_fn(
      model_fits,
      tau_grid = c(0.05, 0.10)
    ) |>
      mutate(case_id = case_id_value, .before = 1)
  )
}

repair_country_names <- function(revenue_country_year, country_lookup) {
  revenue_country_year |>
    select(-any_of("country_name")) |>
    left_join(country_lookup, by = "country") |>
    relocate(country_name, .after = country)
}

check_factorial_revenue <- function(revenue_country_year, label) {
  scenario_count <- n_distinct(revenue_country_year$scenario_id)
  if (scenario_count != 32) {
    stop(label, " does not contain 32 scenarios")
  }

  scenario_cells <- revenue_country_year |>
    count(country, year, name = "scenarios")

  if (any(scenario_cells$scenarios != 32)) {
    stop(label, " has incomplete country-year scenario cells")
  }

  if (any(revenue_country_year$revenue < -1e-8, na.rm = TRUE)) {
    stop(label, " contains negative revenue")
  }

  invisible(TRUE)
}

build_leave_one_revenue <- function(stage3_panel, leave_dimension, jurisdiction,
                                    country_lookup, case_id_value) {
  stage3_case <- filter_leave_one(stage3_panel, leave_dimension, jurisdiction)
  source_panel <- stage45_build_source_panel(stage3_case)
  collector_activity <- stage45_build_collector_activity(stage3_case)
  utpr_weights <- stage45_build_parent_year_utpr_weights(collector_activity)
  allocation <- stage45_allocate_stage4_revenue(source_panel, utpr_weights)
  conservation <- stage45_build_conservation_diagnostics(
    source_panel,
    allocation$revenue_by_channel_global
  )

  revenue_country_year <- repair_country_names(
    allocation$revenue_country_year_eu27,
    country_lookup
  )
  check_factorial_revenue(revenue_country_year, case_id_value)

  list(
    revenue_country_year = revenue_country_year,
    revenue_by_channel = allocation$revenue_by_channel_eu27,
    conservation = conservation
  )
}

summarise_revenue_decomposition <- function(revenue_country_year,
                                            case_id_value) {
  scenario_summary <- stage46_build_scenario_summary(revenue_country_year)
  anova_objects <- stage46_compute_factorial_anova(revenue_country_year)
  main_effects <- stage46_compute_main_effects(
    scenario_summary |> rename(revenue = eu_revenue),
    revenue_col = "revenue"
  )

  preferred <- scenario_summary |>
    filter(!!PREFERRED_CORE_FILTER) |>
    group_by(factor4_sbs, factor5_behaviour) |>
    summarise(eu_revenue = sum(eu_revenue, na.rm = TRUE), .groups = "drop") |>
    mutate(metric = paste("preferred", factor4_sbs, factor5_behaviour,
      "revenue",
      sep = "_"
    )) |>
    select(metric, value = eu_revenue)

  selected_main_effects <- main_effects |>
    filter(effect %in% c("x1_etr", "x4_sbs", "x5_behaviour")) |>
    transmute(
      metric = paste0(effect, "_main_effect"),
      value = high_minus_low
    )

  selected_anova <- anova_objects$pooled |>
    filter(effect %in% c("x1_etr", "x4_sbs", "x5_behaviour")) |>
    transmute(
      metric = paste0(effect, "_eta_squared"),
      value = eta_squared
    )

  largest_effect <- anova_objects$pooled |>
    arrange(desc(eta_squared)) |>
    slice(1) |>
    transmute(
      metric = "largest_anova_effect",
      value = NA_real_,
      value_label = effect
    )

  spread <- scenario_summary |>
    summarise(
      metric = "eu_revenue_scenario_spread",
      value = max(eu_revenue, na.rm = TRUE) - min(eu_revenue, na.rm = TRUE),
      value_label = NA_character_
    )

  list(
    scenario_summary = scenario_summary |> mutate(
      case_id = case_id_value,
      .before = 1
    ),
    anova_pooled = anova_objects$pooled |> mutate(
      case_id = case_id_value,
      .before = 1
    ),
    main_effects = main_effects |> mutate(
      case_id = case_id_value,
      .before = 1
    ),
    revenue_metrics = bind_rows(
      preferred,
      selected_main_effects,
      selected_anova,
      largest_effect,
      spread
    ) |>
      mutate(value_label = coalesce(value_label, NA_character_)) |>
      mutate(case_id = case_id_value, .before = 1)
  )
}

normalise_case_summary <- function(cases, jurisdiction_lookup, dropped_mass,
                                   semielasticity, model_comparison,
                                   stage1_rates, revenue_metrics) {
  baseline_model <- model_comparison |>
    filter(case_id == "baseline") |>
    arrange(bic_rank) |>
    slice(1) |>
    pull(model_spec)

  semielasticity_key <- semielasticity |>
    filter(
      inference == "parent_affiliate_clustered",
      model_spec == baseline_model,
      tau == 0.05
    ) |>
    select(case_id,
      leave_semielasticity_5 = semi_elasticity,
      leave_semielasticity_5_se = std_error,
      leave_semielasticity_5_p = p_value
    )

  preferred_model <- model_comparison |>
    arrange(case_id, bic_rank) |>
    group_by(case_id) |>
    slice(1) |>
    ungroup() |>
    select(case_id, preferred_model = model_spec)

  stage1_key <- stage1_rates |>
    filter(scope == "global") |>
    select(case_id,
      leave_stage1_distributional_liability_rate =
        distributional_liability_rate,
      leave_stage1_positive_profit = positive_profit
    )

  numeric_revenue_metrics <- c(
    "preferred_sbs_behavioural_revenue",
    "preferred_universal_behavioural_revenue",
    "x1_etr_main_effect",
    "x4_sbs_main_effect",
    "x5_behaviour_main_effect",
    "x1_etr_eta_squared",
    "x4_sbs_eta_squared",
    "x5_behaviour_eta_squared",
    "eu_revenue_scenario_spread"
  )

  revenue_key <- revenue_metrics |>
    filter(metric %in% numeric_revenue_metrics) |>
    select(case_id, metric, value) |>
    pivot_wider(
      names_from = metric, values_from = value,
      names_prefix = "leave_"
    ) |>
    left_join(
      revenue_metrics |>
        filter(metric == "largest_anova_effect") |>
        select(case_id, leave_largest_anova_effect = value_label),
      by = "case_id"
    )

  baseline <- tibble(case_id = "baseline") |>
    left_join(semielasticity_key, by = "case_id") |>
    left_join(preferred_model, by = "case_id") |>
    left_join(stage1_key, by = "case_id") |>
    left_join(revenue_key, by = "case_id") |>
    rename_with(
      ~ str_replace(.x, "^leave_", "baseline_"),
      -case_id
    ) |>
    rename(baseline_preferred_model = preferred_model)

  cases |>
    left_join(jurisdiction_lookup,
      by = "jurisdiction",
      suffix = c("", "_lookup")
    ) |>
    mutate(
      jurisdiction_name = coalesce(jurisdiction_name, jurisdiction_name_lookup)
    ) |>
    select(-any_of("jurisdiction_name_lookup")) |>
    left_join(dropped_mass, by = "case_id") |>
    left_join(semielasticity_key, by = "case_id") |>
    left_join(preferred_model, by = "case_id") |>
    left_join(stage1_key, by = "case_id") |>
    left_join(revenue_key, by = "case_id") |>
    tidyr::crossing(baseline |> select(-case_id)) |>
    mutate(
      semielasticity_5_abs_change =
        leave_semielasticity_5 - baseline_semielasticity_5,
      semielasticity_5_pct_change =
        safe_divide(
          semielasticity_5_abs_change,
          baseline_semielasticity_5
        ),
      stage1_liability_rate_abs_change =
        leave_stage1_distributional_liability_rate -
          baseline_stage1_distributional_liability_rate,
      stage1_liability_rate_pct_change =
        safe_divide(
          stage1_liability_rate_abs_change,
          baseline_stage1_distributional_liability_rate
        ),
      preferred_sbs_behavioural_revenue_abs_change =
        as.numeric(leave_preferred_sbs_behavioural_revenue) -
          as.numeric(baseline_preferred_sbs_behavioural_revenue),
      preferred_sbs_behavioural_revenue_pct_change =
        safe_divide(
          preferred_sbs_behavioural_revenue_abs_change,
          as.numeric(baseline_preferred_sbs_behavioural_revenue)
        ),
      largest_anova_effect_stable =
        leave_largest_anova_effect == baseline_largest_anova_effect,
      preferred_model_stable =
        preferred_model == baseline_preferred_model,
      semielasticity_sign_stable =
        sign(leave_semielasticity_5) == sign(baseline_semielasticity_5)
    ) |>
    arrange(
      leave_dimension,
      desc(abs(preferred_sbs_behavioural_revenue_pct_change)),
      jurisdiction
    )
}

add_baseline_model_case_id <- function(model_comparison) {
  model_comparison |>
    mutate(case_id = "baseline", .before = 1)
}

run_jurisdiction_influence_suite <- function(top_n = DEFAULT_TOP_N) {
  dir.create(DIAGNOSTICS_DIR, showWarnings = FALSE, recursive = TRUE)
  stage1_bilateral <- readRDS(file.path(PROCESSED_DIR, "stage1_bilateral_panel.rds"))
  stage3_panel <- readRDS(file.path(PROCESSED_DIR, "stage3_factorial_pair_year.rds"))
  estimation_sample <- readRDS(file.path(PROCESSED_DIR, "stage3_estimation_sample.rds"))
  country_lookup <- build_country_lookup(stage3_panel)
  jurisdiction_lookup <- build_jurisdiction_lookup(
    stage1_bilateral,
    stage3_panel
  )

  baseline_stage1 <- summarise_stage1_liability(stage1_bilateral, "baseline")
  baseline_semielasticity <- read_csv(
    file.path(DIAGNOSTICS_DIR, "step5_stage3_semielasticity_schedule.csv"),
    show_col_types = FALSE
  ) |>
    mutate(case_id = "baseline", .before = 1)
  baseline_model_comparison <- read_csv(
    file.path(DIAGNOSTICS_DIR, "step5_stage3_model_comparison.csv"),
    show_col_types = FALSE
  ) |>
    add_baseline_model_case_id()
  baseline_revenue <- readRDS(file.path(PROCESSED_DIR, "stage4_5_revenue_country_year.rds"))
  baseline_revenue_decomposition <- summarise_revenue_decomposition(
    baseline_revenue,
    "baseline"
  )

  targets <- build_influence_targets(
    stage1_bilateral,
    estimation_sample,
    jurisdiction_lookup,
    top_n = top_n
  )

  message("Running ", nrow(targets), " leave-one jurisdiction cases")

  case_outputs <- vector("list", nrow(targets))
  for (i in seq_len(nrow(targets))) {
    target <- targets[i, ]
    message(" - ", target$leave_dimension, " ", target$jurisdiction)

    semielasticity_output <- fit_leave_one_semielasticity(
      estimation_sample,
      target$leave_dimension,
      target$jurisdiction,
      target$case_id
    )

    stage1_case <- summarise_stage1_liability(
      filter_leave_one(
        stage1_bilateral,
        target$leave_dimension,
        target$jurisdiction
      ),
      target$case_id
    )

    revenue_output <- build_leave_one_revenue(
      stage3_panel,
      target$leave_dimension,
      target$jurisdiction,
      country_lookup,
      target$case_id
    )
    revenue_decomposition <- summarise_revenue_decomposition(
      revenue_output$revenue_country_year,
      target$case_id
    )

    case_outputs[[i]] <- list(
      dropped_mass = summarise_case_dropped_mass(
        stage1_bilateral,
        estimation_sample,
        target$leave_dimension,
        target$jurisdiction
      ) |>
        mutate(case_id = target$case_id, .before = 1),
      stage1 = stage1_case,
      semielasticity = semielasticity_output$semielasticity,
      model_comparison = semielasticity_output$model_comparison |>
        mutate(case_id = target$case_id, .before = 1),
      revenue_summary = revenue_decomposition$scenario_summary,
      anova_pooled = revenue_decomposition$anova_pooled,
      main_effects = revenue_decomposition$main_effects,
      revenue_metrics = revenue_decomposition$revenue_metrics,
      conservation = revenue_output$conservation |>
        mutate(case_id = target$case_id, .before = 1)
    )
  }

  dropped_mass <- bind_rows(map(case_outputs, "dropped_mass"))
  stage1_rates <- bind_rows(
    baseline_stage1,
    bind_rows(map(case_outputs, "stage1"))
  )
  semielasticity <- bind_rows(
    baseline_semielasticity,
    bind_rows(map(case_outputs, "semielasticity"))
  )
  model_comparison <- bind_rows(
    baseline_model_comparison,
    bind_rows(map(case_outputs, "model_comparison"))
  )
  revenue_summary <- bind_rows(
    baseline_revenue_decomposition$scenario_summary,
    bind_rows(map(case_outputs, "revenue_summary"))
  )
  anova_pooled <- bind_rows(
    baseline_revenue_decomposition$anova_pooled,
    bind_rows(map(case_outputs, "anova_pooled"))
  )
  main_effects <- bind_rows(
    baseline_revenue_decomposition$main_effects,
    bind_rows(map(case_outputs, "main_effects"))
  )
  revenue_metrics <- bind_rows(
    baseline_revenue_decomposition$revenue_metrics,
    bind_rows(map(case_outputs, "revenue_metrics"))
  )
  conservation <- bind_rows(map(case_outputs, "conservation"))

  case_summary <- normalise_case_summary(
    targets,
    jurisdiction_lookup,
    dropped_mass,
    semielasticity,
    model_comparison,
    stage1_rates,
    revenue_metrics
  )

  write_csv(
    targets,
    file.path(DIAGNOSTICS_DIR, "step10_jurisdiction_influence_cases.csv")
  )
  write_csv(
    case_summary,
    file.path(DIAGNOSTICS_DIR, "step10_jurisdiction_influence_case_summary.csv")
  )
  write_csv(
    stage1_rates,
    file.path(DIAGNOSTICS_DIR, "step10_jurisdiction_influence_stage1_rates.csv")
  )
  write_csv(
    semielasticity,
    file.path(DIAGNOSTICS_DIR, "step10_jurisdiction_influence_semielasticity.csv")
  )
  write_csv(
    model_comparison,
    file.path(DIAGNOSTICS_DIR, "step10_jurisdiction_influence_model_comparison.csv")
  )
  write_csv(
    revenue_summary,
    file.path(DIAGNOSTICS_DIR, "step10_jurisdiction_influence_revenue_summary.csv")
  )
  write_csv(
    anova_pooled,
    file.path(DIAGNOSTICS_DIR, "step10_jurisdiction_influence_anova_pooled.csv")
  )
  write_csv(
    main_effects,
    file.path(DIAGNOSTICS_DIR, "step10_jurisdiction_influence_main_effects.csv")
  )
  write_csv(
    revenue_metrics,
    file.path(DIAGNOSTICS_DIR, "step10_jurisdiction_influence_revenue_metrics.csv")
  )
  write_csv(
    conservation,
    file.path(DIAGNOSTICS_DIR, "step10_jurisdiction_influence_conservation.csv")
  )

  saveRDS(
    case_summary,
    file.path(PROCESSED_DIR, "jurisdiction_influence_case_summary.rds")
  )
  saveRDS(
    stage1_rates,
    file.path(PROCESSED_DIR, "jurisdiction_influence_stage1_rates.rds")
  )
  saveRDS(
    semielasticity,
    file.path(PROCESSED_DIR, "jurisdiction_influence_semielasticity.rds")
  )
  saveRDS(
    model_comparison,
    file.path(PROCESSED_DIR, "jurisdiction_influence_model_comparison.rds")
  )
  saveRDS(
    revenue_summary,
    file.path(PROCESSED_DIR, "jurisdiction_influence_revenue_summary.rds")
  )
  saveRDS(
    anova_pooled,
    file.path(PROCESSED_DIR, "jurisdiction_influence_anova_pooled.rds")
  )
  saveRDS(
    main_effects,
    file.path(PROCESSED_DIR, "jurisdiction_influence_main_effects.rds")
  )

  message("\nStep 10 outputs written:")
  message(" - diagnostics/step10_jurisdiction_influence_*.csv")
  message(" - data/processed/jurisdiction_influence_*.rds")

  invisible(list(
    targets = targets,
    case_summary = case_summary,
    stage1_rates = stage1_rates,
    semielasticity = semielasticity,
    model_comparison = model_comparison,
    revenue_summary = revenue_summary,
    anova_pooled = anova_pooled,
    main_effects = main_effects
  ))
}

if (is_direct_script_run("code/10_jurisdiction_influence_robustness.R")) {
  run_jurisdiction_influence_suite(
    top_n = parse_arg_int("--top-n=", DEFAULT_TOP_N)
  )
}
