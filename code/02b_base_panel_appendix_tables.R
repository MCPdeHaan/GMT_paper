# 02b_base_panel_appendix_tables.R
# Regenerates the working-appendix descriptive tables for the merged bilateral
# base panel created in Step 2.
library(dplyr); library(readr); library(purrr); library(stringr); library(tibble)

IN_FILE  <- "data/processed/base_panel.rds"
OUT_DIR  <- "writing/generated"
OUT_FILE <- file.path(OUT_DIR, "base_panel_appendix_tables.tex")

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

required_cols <- c(
  "year", "parent", "affiliate", "is_domestic", "affiliate_is_eu27",
  "profit_adj_observed_panelai", "profit_correction_source_baseline",
  "has_panelai_percentiles", "has_t_fallback_percentiles",
  "has_any_percentile_set", "has_t4_low_bracket",
  "has_behavioral_estimation_inputs", "has_stage1_hybrid_inputs",
  "has_stage1_crossval_inputs", "analysis_profit_base",
  "tax_accrued_panelai", "payroll_sbie", "assets_sbie", "employees_sbie",
  "employees_sbie_correction_flag",
  "etr_panelai_raw", "etr_negative_flag", "etr_above_one_flag",
  "affiliate_cit_rate", "affiliate_gdp_pc_usd", "affiliate_population",
  "holding_share_panelai", "payroll_sbie_source"
)

fmt_int <- function(x) format(round(x), big.mark = ",", scientific = FALSE, trim = TRUE)
fmt_num <- function(x, digits = 1) format(round(x, digits), nsmall = digits, trim = TRUE)

assert_required_cols <- function(df, cols) {
  missing_cols <- setdiff(cols, names(df))
  if (length(missing_cols) > 0) {
    stop(sprintf("Missing required columns: %s", paste(missing_cols, collapse = ", ")))
  }
}

table_rows <- function(df, cols, digits) {
  pmap_chr(df[cols], function(...) {
    vals <- list(...)
    formatted <- map2_chr(vals, digits, function(.x, .y) {
      if (!is.numeric(.x)) return(as.character(.x))
      if (.y == 0) fmt_int(.x) else fmt_num(.x, .y)
    })
    paste(formatted, collapse = " & ")
  })
}

summary_row <- function(name, vec) {
  tibble(
    variable = name,
    N = sum(!is.na(vec)),
    Mean = mean(vec, na.rm = TRUE),
    SD = sd(vec, na.rm = TRUE),
    P25 = quantile(vec, 0.25, na.rm = TRUE),
    Median = median(vec, na.rm = TRUE),
    P75 = quantile(vec, 0.75, na.rm = TRUE)
  )
}

x <- readRDS(IN_FILE)
assert_required_cols(x, required_cols)

coverage <- x |>
  group_by(year) |>
  summarise(
    Cells = n(),
    Parents = n_distinct(parent),
    Affiliates = n_distinct(affiliate),
    AnyPercentiles = 100 * mean(has_any_percentile_set, na.rm = TRUE),
    T4Below15 = 100 * mean(has_t4_low_bracket, na.rm = TRUE),
    Stage1Hybrid = sum(has_stage1_hybrid_inputs, na.rm = TRUE),
    Behavioral = sum(has_behavioral_estimation_inputs, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(year = as.character(year))

coverage_total <- x |>
  summarise(
    year = "Total",
    Cells = n(),
    Parents = n_distinct(parent),
    Affiliates = n_distinct(affiliate),
    AnyPercentiles = 100 * mean(has_any_percentile_set, na.rm = TRUE),
    T4Below15 = 100 * mean(has_t4_low_bracket, na.rm = TRUE),
    Stage1Hybrid = sum(has_stage1_hybrid_inputs, na.rm = TRUE),
    Behavioral = sum(has_behavioral_estimation_inputs, na.rm = TRUE)
  )

flags <- tibble(
  Flag = c(
    "Total pair-year cells",
    "Domestic cells",
    "EU-27 affiliate cells",
    "Observed \\code{PROFIT\\_ADJ} cells",
    "Domestic Hugger correction",
    "Conduit or haven overlay",
    "Employee counts capped by plausibility rule",
    "Wage-based payroll proxy available",
    "Missing wage-based payroll proxy",
    "Direct Table IV \\code{RATE\\_0-15} observation",
    "Complete Panel A-I percentile set",
    "\\code{\\_T} percentile fall-back only",
    "Raw Panel A-I ETR below 0",
    "Raw Panel A-I ETR above 100\\%",
    "Stage 1 hybrid-ready pair-year cells",
    "Stage 1 cross-validation pair-year cells",
    "Behavioural estimation sample"
  ),
  Cells = c(
    nrow(x),
    sum(x$is_domestic, na.rm = TRUE),
    sum(x$affiliate_is_eu27, na.rm = TRUE),
    sum(x$profit_adj_observed_panelai, na.rm = TRUE),
    sum(x$profit_correction_source_baseline == "domestic_upe_hugger", na.rm = TRUE),
    sum(x$profit_correction_source_baseline == "conduit_overlay_10pct", na.rm = TRUE),
    sum(x$employees_sbie_correction_flag, na.rm = TRUE),
    sum(!is.na(x$payroll_sbie)),
    sum(is.na(x$payroll_sbie)),
    sum(x$has_t4_low_bracket, na.rm = TRUE),
    sum(x$has_panelai_percentiles, na.rm = TRUE),
    sum(!x$has_panelai_percentiles & x$has_t_fallback_percentiles, na.rm = TRUE),
    sum(x$etr_negative_flag, na.rm = TRUE),
    sum(x$etr_above_one_flag, na.rm = TRUE),
    sum(x$has_stage1_hybrid_inputs, na.rm = TRUE),
    sum(x$has_stage1_crossval_inputs, na.rm = TRUE),
    sum(x$has_behavioral_estimation_inputs, na.rm = TRUE)
  )
) |>
  mutate(Share = 100 * Cells / nrow(x))

x_beh <- x |>
  filter(has_behavioral_estimation_inputs)

summary_stats <- bind_rows(
  summary_row("Corrected profit base (USD bn)", x_beh$analysis_profit_base / 1e9),
  summary_row("Income tax accrued (USD bn)", x_beh$tax_accrued_panelai / 1e9),
  summary_row("SBIE payroll proxy (USD bn)", x_beh$payroll_sbie / 1e9),
  summary_row("SBIE tangible assets (USD bn)", x_beh$assets_sbie / 1e9),
  summary_row("Employees (thousands)", x_beh$employees_sbie / 1e3),
  summary_row("Raw Panel A-I ETR (per cent)", 100 * x_beh$etr_panelai_raw),
  summary_row("Affiliate statutory CIT, headline (per cent)", x_beh$affiliate_cit_rate),
  summary_row("Affiliate GDP per capita (USD thousands)", x_beh$affiliate_gdp_pc_usd / 1e3),
  summary_row("Affiliate population (millions)", x_beh$affiliate_population / 1e6),
  summary_row("Holding share, Panel A-I (per cent)", 100 * x_beh$holding_share_panelai)
)

coverage_lines <- c(
  "\\begin{table}[H]",
  "\\centering",
  "\\caption{Coverage of the merged bilateral base panel by fiscal year}",
  "\\label{tab:base_panel_coverage_working}",
  "\\small",
  "\\begin{tabular}{@{}crrrrrrr@{}}",
  "\\toprule",
  "Year & Cells & Parents & Affiliates & Any percentile set (\\%) & Table IV below-15 observed (\\%) & Stage 1 hybrid-ready & Behavioural-ready \\\\",
  "\\midrule",
  paste0(
    table_rows(
      coverage,
      cols = c("year", "Cells", "Parents", "Affiliates",
               "AnyPercentiles", "T4Below15", "Stage1Hybrid", "Behavioral"),
      digits = c(0, 0, 0, 0, 1, 1, 0, 0)
    ),
    " \\\\"
  ),
  "\\midrule",
  paste0(
    table_rows(
      coverage_total,
      cols = c("year", "Cells", "Parents", "Affiliates",
               "AnyPercentiles", "T4Below15", "Stage1Hybrid", "Behavioral"),
      digits = c(0, 0, 0, 0, 1, 1, 0, 0)
    ),
    " \\\\"
  ),
  "\\bottomrule",
  "\\end{tabular}",
  "",
  "\\vspace{0.5em}",
  "\\begin{minipage}{0.93\\textwidth}",
  "\\footnotesize \\textit{Notes:} The merged panel keeps country-like affiliate jurisdictions only; regional aggregates, \\code{W}, \\code{W\\_O}, \\code{WXD}, and \\code{STLS} are excluded. ``Any percentile set'' equals one when either the full Panel A-I percentile set or the panel-agnostic \\code{\\_T} fall-back is available in Table I. ``Table IV below-15 observed'' equals one when the bilateral cell has a direct \\code{RATE\\_0-15} observation in Table IV. ``Stage 1 hybrid-ready'' requires positive corrected profit, non-missing SBIE inputs, a non-missing Panel A-I ETR, and at least one Stage 1 low-tax source, either a percentile set or Table IV. ``Behavioural-ready'' is the broader Hines--Rice sample with positive corrected profit, non-missing Panel A-I ETR, and non-missing SBIE inputs. Fiscal year 2016 is retained for coverage diagnostics only and does not enter either estimation sample. Source: author's calculations based on \\texttt{data/processed/base\\_panel.rds}.",
  "\\end{minipage}",
  "\\end{table}"
)

summary_lines <- c(
  "\\begin{table}[H]",
  "\\centering",
  "\\caption{Summary statistics for the behavioural estimation sample}",
  "\\label{tab:base_panel_summary_working}",
  "\\small",
  "\\begin{tabular}{@{}L{5.8cm}rrrrrr@{}}",
  "\\toprule",
  "Variable & N & Mean & SD & P25 & Median & P75 \\\\",
  "\\midrule",
  paste0(
    map_chr(seq_len(nrow(summary_stats)), function(i) {
      row <- summary_stats[i, ]
      paste(
        row$variable,
        fmt_int(row$N),
        fmt_num(row$Mean, 3),
        fmt_num(row$SD, 3),
        fmt_num(row$P25, 3),
        fmt_num(row$Median, 3),
        fmt_num(row$P75, 3),
        sep = " & "
      )
    }),
    " \\\\"
  ),
  "\\bottomrule",
  "\\end{tabular}",
  "",
  "\\vspace{0.5em}",
  "\\begin{minipage}{0.93\\textwidth}",
  "\\footnotesize \\textit{Notes:} The behavioural estimation sample consists of the 2017--2022 pair-year cells with positive baseline-corrected profit, a non-missing Panel A-I ETR, a non-missing wage-based payroll proxy, and non-missing SBIE tangible assets. The reported payroll variable is not an observed CbCR item. It is constructed as screened employee counts times the affiliate-jurisdiction annual wage benchmark. The statutory CIT variable uses the combined top-all rate where available and falls back to the standard statutory rate otherwise. All statistics are unweighted across pair-year cells. Monetary variables are expressed in USD billions, GDP per capita in USD thousands, population in millions, and employment in thousands of persons. Source: author's calculations based on \\texttt{data/processed/base\\_panel.rds}.",
  "\\end{minipage}",
  "\\end{table}"
)

flag_lines <- c(
  "\\begin{table}[H]",
  "\\centering",
  "\\caption{Construction and readiness flags in the merged bilateral panel}",
  "\\label{tab:base_panel_flags_working}",
  "\\small",
  "\\begin{tabular}{@{}L{7.6cm}rr@{}}",
  "\\toprule",
  "Flag & Cells & Share of panel (\\%) \\\\",
  "\\midrule",
  paste0(
    map_chr(seq_len(nrow(flags)), function(i) {
      row <- flags[i, ]
      paste(row$Flag, fmt_int(row$Cells), fmt_num(row$Share, 1), sep = " & ")
    }),
    " \\\\"
  ),
  "\\bottomrule",
  "\\end{tabular}",
  "",
  "\\vspace{0.5em}",
  "\\begin{minipage}{0.93\\textwidth}",
  "\\footnotesize \\textit{Notes:} Shares are calculated relative to the full merged panel. ``Domestic Hugger correction'' identifies cells where the baseline profit correction applies the domestic UPE adjustment rather than observed \\code{PROFIT\\_ADJ}. ``Conduit or haven overlay'' identifies non-US foreign cells that receive the 10 per cent conduit overlay in the baseline correction. The employee-cap row identifies cells where reported CbCR employee counts exceeded a conservative plausibility cap based on the number of constituent entities and the host-jurisdiction population. The payroll rows refer to the wage-based proxy used in Step 2, not to observed CbCR \\code{EARNINGS}. The Stage 1 rows count pair-year cells in the bilateral base panel; the affiliate-year coverage used in the actual Stage 1 aggregation is reported separately in the Step 2 diagnostics. Source: author's calculations based on \\texttt{data/processed/base\\_panel.rds}.",
  "\\end{minipage}",
  "\\end{table}"
)

lines <- c(
  "\\subsection{Merged bilateral base panel}\\label{sec:base_panel_appendix}",
  "",
  "This subsection documents the merged bilateral parent--affiliate--year panel produced in Step 2 of the data pipeline. Table \\ref{tab:base_panel_coverage_working} reports the coverage of the merged panel by fiscal year and distinguishes the broader behavioural estimation sample from the narrower Stage 1 hybrid sample. Table \\ref{tab:base_panel_summary_working} reports unweighted cell-level summary statistics for the behavioural estimation sample. Table \\ref{tab:base_panel_flags_working} records the main construction and readiness flags created during the merge. The distributions of the monetary variables are strongly right-skewed, so the median and interquartile range are more informative than the mean alone. Importantly, the CbCR \\code{EARNINGS} measure is accumulated earnings rather than payroll, so Step 2 now constructs the SBIE payroll input from employee counts and external wage data instead of treating \\code{EARNINGS} as labour cost.",
  "",
  coverage_lines,
  "",
  summary_lines,
  "",
  flag_lines
)

write_lines(lines, OUT_FILE)
message("Wrote ", OUT_FILE)
