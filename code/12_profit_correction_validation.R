# 12_profit_correction_validation.R
# Diagnostic audit of whether the external profit-correction rates can be
# reproduced from the public CbCR panel.
library(dplyr)
library(readr)
library(tibble)

source(if (file.exists("code/00_helpers.R")) {
  "code/00_helpers.R"
} else {
  file.path("..", "..", "code/00_helpers.R")
})

weighted_mean_clean <- function(x, w) {
  keep <- is.finite(x) & is.finite(w) & w > 0
  if (!any(keep)) return(NA_real_)
  weighted.mean(x[keep], w[keep])
}

weighted_rate <- function(amount, weight) {
  keep <- is.finite(amount) & is.finite(weight) & weight > 0
  if (!any(keep)) return(NA_real_)
  sum(amount[keep], na.rm = TRUE) / sum(weight[keep], na.rm = TRUE)
}

run_profit_correction_validation <- function(in_dir = PROCESSED_DIR,
                                             out_dir = PROCESSED_DIR) {
  diag_dir <- file.path(out_dir, "diagnostics")
  dir.create(diag_dir, showWarnings = FALSE, recursive = TRUE)

  panel <- readRDS(file.path(in_dir, "base_panel.rds")) |>
    filter(year %in% MAIN_YEARS)

  observed <- panel |>
    filter(profit_panelai > 0, !is.na(profit_adj_panelai)) |>
    mutate(
      observed_adjusted_ratio = clamp_unit_interval(
        safe_divide(profit_adj_panelai, profit_panelai)
      ),
      observed_correction_rate = 1 - observed_adjusted_ratio
    )

  observed_by_parent <- observed |>
    group_by(parent, parent_jurisdiction_name, is_domestic) |>
    summarise(
      cells = n(),
      years = n_distinct(year),
      unadjusted_profit = sum(profit_panelai, na.rm = TRUE),
      adjusted_profit = sum(profit_adj_panelai, na.rm = TRUE),
      aggregate_correction_rate = clamp_unit_interval(
        1 - safe_divide(adjusted_profit, unadjusted_profit)
      ),
      median_cell_correction_rate =
        median(observed_correction_rate, na.rm = TRUE),
      profit_weighted_cell_correction_rate =
        weighted_mean_clean(observed_correction_rate, profit_panelai),
      .groups = "drop"
    ) |>
    arrange(parent, desc(is_domestic))

  positive_tax_panel <- panel |>
    filter(
      profit_panelai > 0,
      !is.na(tax_accrued_panelai),
      tax_accrued_panelai >= 0
    )

  domestic <- positive_tax_panel |>
    filter(is_domestic) |>
    transmute(
      jurisdiction = affiliate,
      year,
      parent,
      parent_jurisdiction_name,
      domestic_profit = profit_panelai,
      domestic_tax = tax_accrued_panelai,
      domestic_etr = safe_divide(domestic_tax, domestic_profit)
    )

  foreign <- positive_tax_panel |>
    filter(!is_domestic) |>
    group_by(affiliate, year) |>
    summarise(
      foreign_profit = sum(profit_panelai, na.rm = TRUE),
      foreign_tax = sum(tax_accrued_panelai, na.rm = TRUE),
      foreign_parents = n_distinct(parent),
      foreign_cells = n(),
      foreign_etr = safe_divide(foreign_tax, foreign_profit),
      .groups = "drop"
    ) |>
    rename(jurisdiction = affiliate)

  etr_parity <- domestic |>
    left_join(foreign, by = c("jurisdiction", "year")) |>
    filter(
      is.finite(domestic_etr),
      is.finite(foreign_etr),
      foreign_profit > 0,
      foreign_etr > 0,
      foreign_parents >= 3
    ) |>
    mutate(
      implied_correction_rate_raw = 1 - domestic_etr / foreign_etr,
      implied_correction_rate = pmin(
        pmax(implied_correction_rate_raw, 0),
        0.555
      ),
      implied_reduction = implied_correction_rate * domestic_profit
    )

  etr_parity_summary <- etr_parity |>
    summarise(
      country_years = n(),
      parents = n_distinct(parent),
      domestic_profit = sum(domestic_profit, na.rm = TRUE),
      implied_reduction = sum(implied_reduction, na.rm = TRUE),
      profit_weighted_correction_rate =
        weighted_rate(implied_reduction, domestic_profit),
      median_correction_rate = median(implied_correction_rate, na.rm = TRUE),
      p25_correction_rate =
        as.numeric(quantile(implied_correction_rate, 0.25, na.rm = TRUE)),
      p75_correction_rate =
        as.numeric(quantile(implied_correction_rate, 0.75, na.rm = TRUE))
    )

  etr_parity_by_parent <- etr_parity |>
    group_by(parent, parent_jurisdiction_name) |>
    summarise(
      country_years = n(),
      years = n_distinct(year),
      domestic_profit = sum(domestic_profit, na.rm = TRUE),
      implied_reduction = sum(implied_reduction, na.rm = TRUE),
      public_proxy_rate = weighted_rate(implied_reduction, domestic_profit),
      median_country_year_rate =
        median(implied_correction_rate, na.rm = TRUE),
      aggregate_domestic_etr =
        safe_divide(sum(domestic_tax, na.rm = TRUE),
                    sum(domestic_profit, na.rm = TRUE)),
      aggregate_foreign_etr =
        safe_divide(sum(foreign_tax, na.rm = TRUE),
                    sum(foreign_profit, na.rm = TRUE)),
      minimum_foreign_parent_support = min(foreign_parents, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(desc(domestic_profit))

  benchmark_exposed <- panel |>
    filter(
      is_domestic,
      profit_panelai > 0,
      is.na(profit_adj_panelai)
    ) |>
    group_by(parent, parent_jurisdiction_name) |>
    summarise(
      benchmark_cells = n(),
      benchmark_profit = sum(profit_panelai, na.rm = TRUE),
      benchmark_rate =
        weighted_mean_clean(domestic_correction_rate_baseline, profit_panelai),
      benchmark_reduction =
        sum(profit_panelai * domestic_correction_rate_baseline, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(
      benchmark_source = case_when(
        parent == "USA" ~ "Garcia-Bernardo et al. (2022), US domestic CbCR reconciliation",
        parent == "NLD" ~ "Garcia-Bernardo and Jansky (2024), Netherlands correction",
        TRUE ~ "Hugger et al. (2026), median UPE correction"
      )
    )

  benchmark_comparison <- benchmark_exposed |>
    left_join(etr_parity_by_parent,
              by = c("parent", "parent_jurisdiction_name")) |>
    mutate(
      public_proxy_gap = public_proxy_rate - benchmark_rate,
      public_proxy_available = !is.na(public_proxy_rate)
    ) |>
    arrange(desc(benchmark_reduction))

  direct_summary <- observed_by_parent |>
    mutate(
      evidence_source = "OECD observed adjusted profit",
      scope = if_else(is_domestic, "Domestic parent cell", "Foreign affiliate cell"),
      implied_rate = aggregate_correction_rate,
      benchmark_rate = NA_real_,
      interpretation = "Direct public CbCR adjustment where observed"
    ) |>
    transmute(
      evidence_source,
      scope,
      parent,
      parent_jurisdiction_name,
      cells,
      profit = unadjusted_profit,
      implied_rate,
      benchmark_rate,
      interpretation
    )

  parity_summary <- bind_rows(
    etr_parity_summary |>
      transmute(
        evidence_source = "Public CbCR ETR-parity proxy",
        scope = "All supported domestic country-years",
        parent = "ALL",
        parent_jurisdiction_name = "Supported domestic cells",
        cells = country_years,
        profit = domestic_profit,
        implied_rate = profit_weighted_correction_rate,
        benchmark_rate = 0.324,
        interpretation = "Diagnostic only; foreign affiliates are an imperfect control group"
      ),
    benchmark_comparison |>
      slice_head(n = 10) |>
      transmute(
        evidence_source = "Public CbCR ETR-parity proxy",
        scope = "Largest benchmark-exposed parents",
        parent,
        parent_jurisdiction_name,
        cells = benchmark_cells,
        profit = benchmark_profit,
        implied_rate = public_proxy_rate,
        benchmark_rate,
        interpretation = if_else(
          public_proxy_available,
          "Compared with benchmark calibration",
          "No public proxy available after support filter"
        )
      )
  )

  validation_summary <- bind_rows(direct_summary, parity_summary)

  stopifnot(nrow(observed_by_parent) > 0)
  stopifnot(nrow(etr_parity_by_parent) > 0)
  stopifnot(all(validation_summary$implied_rate >= 0 |
                  is.na(validation_summary$implied_rate)))
  stopifnot(all(validation_summary$implied_rate <= 1 |
                  is.na(validation_summary$implied_rate)))

  write_csv(observed_by_parent,
            file.path(diag_dir, "step12_profit_correction_observed_adjusted.csv"))
  write_csv(etr_parity,
            file.path(diag_dir, "step12_profit_correction_etr_parity_cell.csv"))
  write_csv(etr_parity_summary,
            file.path(diag_dir, "step12_profit_correction_etr_parity_summary.csv"))
  write_csv(etr_parity_by_parent,
            file.path(diag_dir, "step12_profit_correction_etr_parity_by_parent.csv"))
  write_csv(benchmark_comparison,
            file.path(diag_dir, "step12_profit_correction_benchmark_comparison.csv"))
  write_csv(validation_summary,
            file.path(diag_dir, "step12_profit_correction_validation_summary.csv"))

  saveRDS(observed_by_parent,
          file.path(out_dir, "profit_correction_observed_adjusted.rds"))
  saveRDS(etr_parity_by_parent,
          file.path(out_dir, "profit_correction_etr_parity_by_parent.rds"))
  saveRDS(benchmark_comparison,
          file.path(out_dir, "profit_correction_benchmark_comparison.rds"))
  saveRDS(validation_summary,
          file.path(out_dir, "profit_correction_validation_summary.rds"))

  invisible(list(
    observed_by_parent = observed_by_parent,
    etr_parity_by_parent = etr_parity_by_parent,
    benchmark_comparison = benchmark_comparison,
    validation_summary = validation_summary
  ))
}

if (is_direct_script_run("code/12_profit_correction_validation.R")) {
  run_profit_correction_validation()
  message("Step 12 profit-correction validation outputs written.")
}
