# 07a_profit_correction_revenue_uncertainty.R
# Post-allocation propagation of parent-year profit-correction uncertainty.
#
# Step 2a estimates rho_pt before the revenue pipeline. This script carries the
# same parent-year uncertainty draws through the realised preferred Stage 4.6
# revenue panel without expanding the full 2^5 scenario design. The propagation
# keeps distributional low-tax shares, behavioural filters and legal allocation
# weights fixed, and recomputes the preferred scenario's profit denominator and
# SBIE filter under each draw.
library(dplyr)
library(tidyr)
library(readr)
library(tibble)

source(if (file.exists("code/00_helpers.R")) {
  "code/00_helpers.R"
} else {
  file.path("..", "..", "code/00_helpers.R")
})

IN <- "data/processed"
OUT <- IN
DIAG <- file.path(OUT, "diagnostics")

PROFIT_RECONCILIATION_UPPER_BOUND <- 0.85
EPS_RHO <- 1e-5
FOREIGN_HOLDING_CHAIN_AFFILIATES <- c(
  "NLD", "LUX", "IRL", "CHE", "SGP", "HKG", "BMU", "CYM"
)
FOREIGN_HOLDING_CHAIN_RATE <- 0.10

clamp_interval <- function(x, lower, upper) {
  pmin(pmax(x, lower), upper)
}

inverse_bounded_logit <- function(x,
                                  upper_bound = PROFIT_RECONCILIATION_UPPER_BOUND) {
  upper_bound * plogis(x)
}

compute_draw_phi <- function(sbie, profit) {
  clamp_interval(safe_divide(sbie, profit), 0, 1)
}

build_utpr_eu_shares <- function(in_dir = IN) {
  parent_year_weights <- readRDS(
    file.path(in_dir, "stage4_5_utpr_parent_year_weights.rds")
  )
  fallback_weights <- readRDS(
    file.path(in_dir, "stage4_5_utpr_fallback_weights.rds")
  )

  parent_year <- parent_year_weights |>
    group_by(parent, year) |>
    summarise(
      eu27_utpr_share_parent_year =
        sum(if_else(collector_is_eu27, utpr_weight, 0), na.rm = TRUE),
      .groups = "drop"
    )

  fallback <- fallback_weights |>
    group_by(year) |>
    summarise(
      eu27_utpr_share_fallback =
        sum(if_else(collector_is_eu27, utpr_weight, 0), na.rm = TRUE),
      .groups = "drop"
    )

  list(parent_year = parent_year, fallback = fallback)
}

build_preferred_source_panel <- function(in_dir = IN) {
  utpr_shares <- build_utpr_eu_shares(in_dir)

  readRDS(file.path(in_dir, "stage4_5_allocation_source_panel.rds")) |>
    filter(
      factor1_etr == "distributional",
      factor2_substance == "aggregate_sbie",
      rate_scenario == "initial",
      factor5_behaviour == "behavioural",
      factor4_sbs %in% c("universal", "sbs"),
      year %in% MAIN_YEARS
    ) |>
    select(
      parent, affiliate, year, factor4_sbs,
      profit_panelai, profit_adj_panelai, is_domestic,
      rpr_panelai, tot_rev_panelai, assets_panelai, employees_panelai,
      holding_share_panelai, affiliate_is_conduit_haven,
      profit_panelai_uncorrected, profit_panelai_corrected_low,
      analysis_profit_base, profit_panelai_corrected_high,
      stage2_sbie, stage1_distributional_low_share,
      stage1_distributional_liability_rate, sectoral_scale_selected,
      behavioural_liability_filter, qdmtt_flag, parent_iir_utpr_flag,
      sbs_exempt
    ) |>
    left_join(utpr_shares$parent_year, by = c("parent", "year")) |>
    left_join(utpr_shares$fallback, by = "year") |>
    mutate(
      eu27_utpr_share = coalesce(
        eu27_utpr_share_parent_year,
        eu27_utpr_share_fallback,
        0
      ),
      parent_is_eu27 = parent %in% EU27_ISO3,
      affiliate_is_eu27 = affiliate %in% EU27_ISO3,
      sectoral_scale_selected = coalesce(sectoral_scale_selected, 1),
      behavioural_liability_filter = coalesce(behavioural_liability_filter, 1),
      stage1_distributional_low_share =
        coalesce(stage1_distributional_low_share, 0),
      stage1_distributional_liability_rate =
        coalesce(stage1_distributional_liability_rate, 0),
      stage2_sbie = coalesce(stage2_sbie, 0),
      qdmtt_flag = coalesce(qdmtt_flag, FALSE),
      parent_iir_utpr_flag = coalesce(parent_iir_utpr_flag, FALSE),
      sbs_exempt = coalesce(sbs_exempt, FALSE)
    )
}

add_foreign_holding_chain_flags <- function(source_panel) {
  source_panel |>
    mutate(
      related_party_revenue_share = clamp_interval(
        safe_divide(rpr_panelai, tot_rev_panelai),
        0,
        1
      ),
      profit_to_assets_reconciliation =
        safe_divide(analysis_profit_base, assets_panelai),
      profit_per_employee_reconciliation =
        safe_divide(analysis_profit_base, employees_panelai),
      foreign_holding_chain_correction_flag =
        !is_domestic &
        affiliate %in% FOREIGN_HOLDING_CHAIN_AFFILIATES &
        coalesce(analysis_profit_base, 0) > 0 &
        coalesce(holding_share_panelai, 0) >= 0.30 &
        coalesce(related_party_revenue_share, 0) >= 0.50 &
        (
          coalesce(profit_per_employee_reconciliation, 0) >= 1e6 |
          coalesce(profit_to_assets_reconciliation, 0) >= 1
        ),
      profit_foreign_holding_chain_sensitivity = if_else(
        foreign_holding_chain_correction_flag,
        analysis_profit_base * (1 - FOREIGN_HOLDING_CHAIN_RATE),
        analysis_profit_base
      )
    )
}

compute_preferred_revenue_from_profit <- function(source_panel, profit_value,
                                                  specification,
                                                  draw_id = NA_integer_) {
  source_panel |>
    mutate(
      profit_draw = pmax(coalesce(profit_value, 0), 0),
      phi_draw = compute_draw_phi(stage2_sbie, profit_draw),
      stage2_filter_draw = if_else(profit_draw > 0, 1 - phi_draw, 1),
      stage1_topup_draw =
        pmax(stage1_distributional_liability_rate * profit_draw, 0),
      topup_after_stage2_draw = pmax(
        stage1_topup_draw * stage2_filter_draw * sectoral_scale_selected,
        0
      ),
      topup_after_behaviour_draw =
        pmax(topup_after_stage2_draw * behavioural_liability_filter, 0),
      qdmtt_liability_draw =
        if_else(qdmtt_flag, topup_after_behaviour_draw, 0),
      iir_liability_draw = if_else(
        !qdmtt_flag & parent_iir_utpr_flag & !sbs_exempt,
        topup_after_behaviour_draw,
        0
      ),
      utpr_pool_draw = if_else(
        !qdmtt_flag & !parent_iir_utpr_flag & !sbs_exempt,
        topup_after_behaviour_draw,
        0
      ),
      sbs_extinguished_draw = if_else(
        !qdmtt_flag & sbs_exempt,
        topup_after_behaviour_draw,
        0
      ),
      eu27_revenue_draw =
        if_else(affiliate_is_eu27, qdmtt_liability_draw, 0) +
        if_else(parent_is_eu27, iir_liability_draw, 0) +
        utpr_pool_draw * eu27_utpr_share
    ) |>
    group_by(factor4_sbs) |>
    summarise(
      draw_id = draw_id,
      specification = specification,
      positive_profit = sum(profit_draw, na.rm = TRUE),
      global_allocated_revenue =
        sum(qdmtt_liability_draw + iir_liability_draw + utpr_pool_draw,
            na.rm = TRUE),
      eu27_final_revenue = sum(eu27_revenue_draw, na.rm = TRUE),
      eu27_qdmtt_revenue =
        sum(if_else(affiliate_is_eu27, qdmtt_liability_draw, 0),
            na.rm = TRUE),
      eu27_iir_revenue =
        sum(if_else(parent_is_eu27, iir_liability_draw, 0), na.rm = TRUE),
      eu27_utpr_revenue = sum(utpr_pool_draw * eu27_utpr_share, na.rm = TRUE),
      sbs_extinguished_revenue = sum(sbs_extinguished_draw, na.rm = TRUE),
      .groups = "drop"
    )
}

build_point_revenue_sensitivity <- function(source_panel) {
  bind_rows(
    compute_preferred_revenue_from_profit(
      source_panel,
      source_panel$profit_panelai_uncorrected,
      "uncorrected"
    ),
    compute_preferred_revenue_from_profit(
      source_panel,
      source_panel$profit_panelai_corrected_low,
      "low_correction"
    ),
    compute_preferred_revenue_from_profit(
      source_panel,
      source_panel$analysis_profit_base,
      "preferred_correction"
    ),
    compute_preferred_revenue_from_profit(
      source_panel,
      source_panel$profit_foreign_holding_chain_sensitivity,
      "foreign_holding_chain_correction"
    ),
    compute_preferred_revenue_from_profit(
      source_panel,
      source_panel$profit_panelai_corrected_high,
      "high_correction"
    )
  )
}

build_foreign_holding_chain_summary <- function(source_panel) {
  source_panel |>
    filter(factor4_sbs == "sbs") |>
    mutate(
      flagged_profit_reduction =
        analysis_profit_base - profit_foreign_holding_chain_sensitivity
    ) |>
    summarise(
      sensitivity = "foreign_holding_chain_correction",
      affiliate_scope = paste(FOREIGN_HOLDING_CHAIN_AFFILIATES, collapse = ";"),
      correction_rate = FOREIGN_HOLDING_CHAIN_RATE,
      flagged_cells = sum(foreign_holding_chain_correction_flag, na.rm = TRUE),
      flagged_parents =
        n_distinct(parent[foreign_holding_chain_correction_flag]),
      flagged_affiliates =
        n_distinct(affiliate[foreign_holding_chain_correction_flag]),
      flagged_profit =
        sum(analysis_profit_base[foreign_holding_chain_correction_flag],
            na.rm = TRUE),
      profit_reduction = sum(flagged_profit_reduction, na.rm = TRUE),
      mean_holding_share = weighted_mean_available(
        holding_share_panelai[foreign_holding_chain_correction_flag],
        analysis_profit_base[foreign_holding_chain_correction_flag]
      ),
      mean_related_party_revenue_share = weighted_mean_available(
        related_party_revenue_share[foreign_holding_chain_correction_flag],
        analysis_profit_base[foreign_holding_chain_correction_flag]
      )
    )
}

build_draw_revenue_sensitivity <- function(source_panel, predictions,
                                           n_draws = 500,
                                           seed = 20260613) {
  draw_parent_year <- predictions |>
    filter(year %in% MAIN_YEARS) |>
    select(parent, year, posterior_y, posterior_sd)

  set.seed(seed)
  bind_rows(lapply(seq_len(n_draws), function(draw_id) {
    draws <- draw_parent_year |>
      mutate(
        draw_id = draw_id,
        rho_draw = inverse_bounded_logit(
          stats::rnorm(n(), posterior_y, posterior_sd)
        )
      ) |>
      select(parent, year, rho_draw)

    draw_panel <- source_panel |>
      left_join(draws, by = c("parent", "year")) |>
      mutate(
        profit_draw = case_when(
          !is.na(profit_adj_panelai) ~ profit_adj_panelai,
          is_domestic ~ profit_panelai * (1 - rho_draw),
          TRUE ~ profit_panelai
        )
      )

    compute_preferred_revenue_from_profit(
      draw_panel,
      draw_panel$profit_draw,
      "rho_draw",
      draw_id = draw_id
    )
  }))
}

summarise_draw_revenue <- function(draws) {
  draws |>
    group_by(factor4_sbs, specification) |>
    summarise(
      draws = n_distinct(draw_id),
      positive_profit_mean = mean(positive_profit, na.rm = TRUE),
      positive_profit_p025 = quantile(positive_profit, 0.025, na.rm = TRUE),
      positive_profit_p975 = quantile(positive_profit, 0.975, na.rm = TRUE),
      global_revenue_mean = mean(global_allocated_revenue, na.rm = TRUE),
      global_revenue_p025 =
        quantile(global_allocated_revenue, 0.025, na.rm = TRUE),
      global_revenue_p975 =
        quantile(global_allocated_revenue, 0.975, na.rm = TRUE),
      eu27_revenue_mean = mean(eu27_final_revenue, na.rm = TRUE),
      eu27_revenue_p025 = quantile(eu27_final_revenue, 0.025, na.rm = TRUE),
      eu27_revenue_p975 = quantile(eu27_final_revenue, 0.975, na.rm = TRUE),
      eu27_qdmtt_mean = mean(eu27_qdmtt_revenue, na.rm = TRUE),
      eu27_iir_mean = mean(eu27_iir_revenue, na.rm = TRUE),
      eu27_utpr_mean = mean(eu27_utpr_revenue, na.rm = TRUE),
      sbs_extinguished_mean = mean(sbs_extinguished_revenue, na.rm = TRUE),
      .groups = "drop"
    )
}

run_profit_correction_revenue_uncertainty <- function(in_dir = IN,
                                                      out_dir = OUT,
                                                      n_draws = 500,
                                                      seed = 20260613) {
  diag_dir <- file.path(out_dir, "diagnostics")
  dir.create(diag_dir, showWarnings = FALSE, recursive = TRUE)

  source_panel <- build_preferred_source_panel(in_dir) |>
    add_foreign_holding_chain_flags()
  predictions <- readRDS(file.path(in_dir, "profit_correction_parent_year.rds"))

  point_sensitivity <- build_point_revenue_sensitivity(source_panel)
  holding_chain_summary <- build_foreign_holding_chain_summary(source_panel)
  draw_sensitivity <- build_draw_revenue_sensitivity(
    source_panel,
    predictions,
    n_draws = n_draws,
    seed = seed
  )
  draw_interval <- summarise_draw_revenue(draw_sensitivity)

  write_csv(
    point_sensitivity,
    file.path(diag_dir, "step07a_profit_correction_final_revenue_points.csv")
  )
  write_csv(
    holding_chain_summary,
    file.path(diag_dir, "step07a_profit_correction_foreign_holding_chain.csv")
  )
  write_csv(
    draw_sensitivity,
    file.path(diag_dir, "step07a_profit_correction_final_revenue_draws.csv")
  )
  write_csv(
    draw_interval,
    file.path(diag_dir, "step07a_profit_correction_final_revenue_interval.csv")
  )

  saveRDS(
    list(points = point_sensitivity,
         foreign_holding_chain = holding_chain_summary,
         draws = draw_sensitivity,
         interval = draw_interval),
    file.path(out_dir, "profit_correction_final_revenue_uncertainty.rds")
  )

  invisible(list(points = point_sensitivity,
                 foreign_holding_chain = holding_chain_summary,
                 draws = draw_sensitivity,
                 interval = draw_interval))
}

if (is_direct_script_run("code/07a_profit_correction_revenue_uncertainty.R")) {
  run_profit_correction_revenue_uncertainty()
  message("Step 7a profit-correction revenue uncertainty outputs written.")
}
