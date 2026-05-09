# 08_generate_results_tables.R
# Step 8 of the methodology pipeline.
#
# Converts the processed outputs from Steps 1 to 7 into LaTeX tables that can be
# included directly in writing/thesisv2.tex. This keeps the Results section tied
# to the current data pipeline instead of hardcoding numerical tables in the
# manuscript.
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(tibble)

source(if (file.exists("code/00_helpers.R")) {
  "code/00_helpers.R"
} else {
  file.path("..", "..", "code/00_helpers.R")
})

IN <- "data/processed"
DIAG <- file.path(IN, "diagnostics")
GEN <- "writing/generated"
GEN_TABLES <- file.path(GEN, "results_tables")

read_diag <- function(file) {
  path <- file.path(DIAG, file)
  if (!file.exists(path)) stop("Missing diagnostics file: ", path)
  read_csv(path, show_col_types = FALSE)
}

read_processed <- function(file) {
  path <- file.path(IN, file)
  if (!file.exists(path)) stop("Missing processed file: ", path)
  readRDS(path)
}

latex_escape <- function(x) {
  x <- as.character(x)
  placeholder <- "\001BACKSLASH\001"
  x <- gsub("\\", placeholder, x, fixed = TRUE)
  x <- gsub("&", "\\&", x, fixed = TRUE)
  x <- gsub("%", "\\%", x, fixed = TRUE)
  x <- gsub("$", "\\$", x, fixed = TRUE)
  x <- gsub("#", "\\#", x, fixed = TRUE)
  x <- gsub("_", "\\_", x, fixed = TRUE)
  x <- gsub("{", "\\{", x, fixed = TRUE)
  x <- gsub("}", "\\}", x, fixed = TRUE)
  x <- gsub("~", "\\textasciitilde{}", x, fixed = TRUE)
  x <- gsub("^", "\\textasciicircum{}", x, fixed = TRUE)
  x <- gsub(placeholder, "\\textbackslash{}", x, fixed = TRUE)
  x
}

fmt_int <- function(x) {
  ifelse(is.na(x), "", format(round(x), big.mark = ",", scientific = FALSE))
}

fmt_year <- function(x) {
  ifelse(is.na(x), "", as.character(as.integer(round(x))))
}

fmt_num <- function(x, digits = 2) {
  ifelse(is.na(x), "", format(round(x, digits), nsmall = digits,
                              big.mark = ",", scientific = FALSE))
}

fmt_pct <- function(x, digits = 1) {
  ifelse(is.na(x), "", fmt_num(100 * x, digits))
}

fmt_bn <- function(x, digits = 1) {
  ifelse(is.na(x), "", fmt_num(x / 1e9, digits))
}

fmt_bool <- function(x) {
  ifelse(is.na(x), "", ifelse(x, "Yes", "No"))
}

fmt_p <- function(x) {
  out <- rep("", length(x))
  ok <- !is.na(x)
  tiny <- ok & x > 0 & x < 0.001
  regular <- ok & x >= 0.001
  zero <- ok & x == 0

  out[zero] <- "$< 10^{-300}$"
  out[regular] <- fmt_num(x[regular], 3)

  if (any(tiny)) {
    exponent <- floor(log10(x[tiny]))
    mantissa <- x[tiny] / (10 ^ exponent)
    out[tiny] <- sprintf("$%.1f \\times 10^{%d}$", mantissa, exponent)
  }

  out
}

significance_stars <- function(p) {
  case_when(
    is.na(p) ~ "",
    p < 0.01 ~ "***",
    p < 0.05 ~ "**",
    p < 0.10 ~ "*",
    TRUE ~ ""
  )
}

coef_cell <- function(estimate, std_error, p_value, digits = 3) {
  ifelse(
    is.na(estimate),
    "",
    paste0(fmt_num(estimate, digits), significance_stars(p_value),
           " (", fmt_num(std_error, digits), ")")
  )
}

source_note <- function(files) {
  ""
}

normalise_factor_label <- function(x) {
  recode(
    x,
    "average" = "Average",
    "distributional" = "Distributional",
    "aggregate_sbie" = "Aggregate SBIE",
    "sectoral_sbie_sbti" = "Sectoral SBIE with SBTI",
    "initial" = "Initial",
    "long_run" = "Long-run",
    "sbs" = "SbS",
    "universal" = "Universal",
    "behavioural" = "Behavioural",
    "mechanical" = "Mechanical",
    .default = str_to_sentence(str_replace_all(x, "_", " "))
  )
}

normalise_model_label <- function(x) {
  recode(
    x,
    "linear" = "Linear",
    "quadratic" = "Quadratic",
    "logarithmic" = "Logarithmic",
    .default = str_to_sentence(str_replace_all(x, "_", " "))
  )
}

normalise_term_label <- function(x) {
  recode(
    x,
    "tau" = "ETR",
    "tau_sq" = "ETR squared",
    "log_tau" = "Log shifted ETR",
    "statutory_tau" = "Statutory CIT rate",
    "log_assets" = "Log tangible assets",
    "log_payroll" = "Log payroll proxy",
    "log_gdp_pc" = "Log GDP per capita",
    "log_population" = "Log population",
    .default = str_to_sentence(str_replace_all(x, "_", " "))
  )
}

write_latex_table <- function(file, caption, label, col_spec, header, rows,
                              notes = NULL, short_caption = NULL,
                              size = "\\small", resize = FALSE) {
  dir.create(dirname(file), showWarnings = FALSE, recursive = TRUE)

  caption_line <- if (is.null(short_caption)) {
    sprintf("\\caption{%s}", caption)
  } else {
    sprintf("\\caption[%s]{%s}", short_caption, caption)
  }

  row_lines <- apply(as.matrix(rows), 1, function(r) {
    paste0(paste(r, collapse = " & "), " \\\\")
  })

  tabular_start <- sprintf("\\begin{tabular}{@{}%s@{}}", col_spec)
  tabular_end <- "\\end{tabular}"
  if (!identical(resize, FALSE)) {
    if (isTRUE(resize)) {
      tabular_start <- c("\\resizebox{\\textwidth}{!}{%", tabular_start)
      tabular_end <- c(tabular_end, "}")
    } else if (identical(resize, "max")) {
      tabular_start <- c("\\begin{adjustbox}{max width=\\textwidth,center}", tabular_start)
      tabular_end <- c(tabular_end, "\\end{adjustbox}")
    }
  }

  lines <- c(
    "% Generated by code/08_generate_results_tables.R",
    "\\begin{table}[H]",
    "\\centering",
    size,
    caption_line,
    sprintf("\\label{%s}", label),
    tabular_start,
    "\\toprule",
    paste0(paste(header, collapse = " & "), " \\\\"),
    "\\midrule",
    row_lines,
    "\\bottomrule",
    tabular_end
  )

  if (!is.null(notes) && nzchar(notes)) {
    lines <- c(
      lines,
      "",
      "\\vspace{0.5em}",
      "\\begin{minipage}{0.96\\textwidth}",
      sprintf("\\footnotesize\\raggedright \\textit{Notes:} %s", notes),
      "\\end{minipage}"
    )
  }

  lines <- c(lines, "\\end{table}", "")
  writeLines(lines, file)
}

write_custom_table <- function(file, lines) {
  dir.create(dirname(file), showWarnings = FALSE, recursive = TRUE)
  writeLines(c("% Generated by code/08_generate_results_tables.R", lines, ""), file)
}

write_appendix_latex_table <- function(file, caption, label, col_spec, header,
                                       rows, notes = NULL,
                                       short_caption = NULL) {
  write_latex_table(
    file = file,
    caption = caption,
    label = label,
    col_spec = col_spec,
    header = header,
    rows = rows,
    notes = notes,
    short_caption = short_caption,
    size = "\\scriptsize",
    resize = "max"
  )
}

metric_value <- function(df, metric) {
  value <- df$value[df$metric == metric]
  if (length(value) == 0) return(NA_character_)
  value[1]
}

finite_values <- function(x) {
  x[is.finite(x)]
}

safe_median <- function(x) {
  x <- finite_values(x)
  if (length(x) == 0) return(NA_real_)
  stats::median(x)
}

describe_vector <- function(label, x, digits = 2) {
  x <- finite_values(x)
  if (length(x) == 0) {
    return(tibble(
      Variable = latex_escape(label),
      `$N$` = "",
      Mean = "",
      SD = "",
      P25 = "",
      Median = "",
      P75 = ""
    ))
  }

  tibble(
    Variable = latex_escape(label),
    `$N$` = fmt_int(length(x)),
    Mean = fmt_num(mean(x), digits),
    SD = fmt_num(ifelse(length(x) > 1, stats::sd(x), NA_real_), digits),
    P25 = fmt_num(stats::quantile(x, 0.25, names = FALSE), digits),
    Median = fmt_num(stats::median(x), digits),
    P75 = fmt_num(stats::quantile(x, 0.75, names = FALSE), digits)
  )
}

write_data_descriptive_tables <- function() {
  panel <- read_processed("stage1_bilateral_panel.rds") |>
    filter(year %in% MAIN_YEARS)

  positive_panel <- panel |>
    filter(analysis_profit_positive > 0)

  coverage_by_year <- panel |>
    group_by(year) |>
    summarise(
      pair_years = n(),
      parents = n_distinct(parent),
      affiliates = n_distinct(affiliate),
      positive_pair_years = sum(analysis_profit_positive > 0, na.rm = TRUE),
      eu27_pair_years = sum(affiliate_is_eu27, na.rm = TRUE),
      corrected_profit = sum(analysis_profit_positive, na.rm = TRUE),
      lowtax_profit = sum(stage1_lowtax_profit_distributional, na.rm = TRUE),
      median_etr = safe_median(
        etr_panelai_stage1[analysis_profit_positive > 0]
      ),
      .groups = "drop"
    ) |>
    transmute(
      Year = fmt_year(year),
      `Pair-years` = fmt_int(pair_years),
      Parents = fmt_int(parents),
      Affiliates = fmt_int(affiliates),
      `Positive pairs` = fmt_int(positive_pair_years),
      `EU27 pairs` = fmt_int(eu27_pair_years),
      `Profit` = fmt_bn(corrected_profit, 1),
      `Low-taxed profit` = fmt_bn(lowtax_profit, 1),
      `Median ETR` = fmt_pct(median_etr, 1)
    )

  coverage_total <- panel |>
    summarise(
      pair_years = n(),
      parents = n_distinct(parent),
      affiliates = n_distinct(affiliate),
      positive_pair_years = sum(analysis_profit_positive > 0, na.rm = TRUE),
      eu27_pair_years = sum(affiliate_is_eu27, na.rm = TRUE),
      corrected_profit = sum(analysis_profit_positive, na.rm = TRUE),
      lowtax_profit = sum(stage1_lowtax_profit_distributional, na.rm = TRUE),
      median_etr = safe_median(
        etr_panelai_stage1[analysis_profit_positive > 0]
      )
    ) |>
    transmute(
      Year = "Pooled",
      `Pair-years` = fmt_int(pair_years),
      Parents = fmt_int(parents),
      Affiliates = fmt_int(affiliates),
      `Positive pairs` = fmt_int(positive_pair_years),
      `EU27 pairs` = fmt_int(eu27_pair_years),
      `Profit` = fmt_bn(corrected_profit, 1),
      `Low-taxed profit` = fmt_bn(lowtax_profit, 1),
      `Median ETR` = fmt_pct(median_etr, 1)
    )

  write_latex_table(
    file.path(GEN_TABLES, "data_panel_coverage.tex"),
    caption = "Analytical panel coverage by fiscal year",
    short_caption = "Analytical panel coverage by fiscal year",
    label = "tab:data_panel_coverage",
    col_spec = "lrrrrrrrr",
    header = c("Year", "Pair-years", "Parents", "Affiliates",
               "Positive pairs", "EU27 pairs", "Profit (US\\$ bn)",
               "Low-taxed profit (US\\$ bn)", "Median ETR"),
    rows = bind_rows(coverage_by_year, coverage_total),
    notes = paste(
      "The sample is the 2017 to 2022 analytical Stage 1 parent-affiliate-year panel.",
      "Profit and low-taxed profit are corrected positive Panel A-I profit under the preferred distributional measurement branch, expressed in US dollars, billions.",
      "Median ETR is the bounded Panel A-I ETR among positive-profit observations.",
      source_note("data/processed/stage1_bilateral_panel.rds")
    ),
    size = "\\scriptsize",
    resize = TRUE
  )

  summary_rows <- bind_rows(
    describe_vector("Corrected profit (US$ m)",
                    positive_panel$analysis_profit_positive / 1e6, 1),
    describe_vector("Tax accrued (US$ m)",
                    positive_panel$tax_accrued_panelai / 1e6, 1),
    describe_vector("Tangible assets (US$ m)",
                    positive_panel$assets_sbie / 1e6, 1),
    describe_vector("Employees (000s)",
                    positive_panel$employees_sbie / 1e3, 2),
    describe_vector("Payroll proxy (US$ m)",
                    positive_panel$payroll_sbie / 1e6, 1),
    describe_vector("Bounded ETR (%)",
                    100 * positive_panel$etr_panelai_stage1, 1),
    describe_vector("Average-rule low-taxed share (%)",
                    100 * positive_panel$average_low_share, 1),
    describe_vector("Distributional low-taxed share (%)",
                    100 * positive_panel$stage1_distributional_low_share, 1),
    describe_vector("Distributional top-up gap (%)",
                    100 * positive_panel$stage1_distributional_topup_rate, 1),
    describe_vector("Holding entity share (%)",
                    100 * positive_panel$holding_share_panelai, 1),
    describe_vector("Affiliate GDP per capita (US$ 000s)",
                    positive_panel$affiliate_gdp_pc_usd / 1000, 1),
    describe_vector("Affiliate population (millions)",
                    positive_panel$affiliate_population / 1e6, 1)
  )

  write_latex_table(
    file.path(GEN_TABLES, "data_summary_statistics.tex"),
    caption = "Summary statistics for positive-profit analytical pair-years",
    short_caption = "Summary statistics for analytical pair-years",
    label = "tab:data_summary_statistics",
    col_spec = "lrrrrrr",
    header = c("Variable", "$N$", "Mean", "SD", "P25", "Median", "P75"),
    rows = summary_rows,
    notes = paste(
      "The sample is restricted to positive-profit analytical pair-years because these observations define the relevant denominator for ETR measurement, low-taxed-profit measurement and the Hines-Rice estimation sample.",
      "Percent variables are reported in percentage points. Monetary variables are in current US dollars after the stated scaling.",
      "The summary deliberately reports quartiles rather than minima and maxima because CbCR cells are highly right-skewed and extreme cells are better treated in influence diagnostics.",
      source_note("data/processed/stage1_bilateral_panel.rds")
    ),
    size = "\\scriptsize",
    resize = TRUE
  )

  writeLines(
    c(
      "% Generated by code/08_generate_results_tables.R",
      "\\input{generated/results_tables/data_panel_coverage.tex}",
      "\\input{generated/results_tables/data_summary_statistics.tex}"
    ),
    file.path(GEN, "data_descriptive_tables.tex")
  )
}

write_profit_correction_table <- function() {
  correction <- read_diag("step2_profit_correction_by_year.csv") |>
    filter(year %in% MAIN_YEARS) |>
    mutate(
      reduction = uncorrected_profit - corrected_profit,
      reduction_rate = safe_divide(reduction, uncorrected_profit)
    )

  support <- read_diag("cbcr_t1_profit_adj_support_by_year.csv") |>
    filter(year %in% MAIN_YEARS)

  panel <- read_processed("base_panel.rds") |>
    filter(year %in% MAIN_YEARS,
           !is.na(profit_adj_ratio_observed),
           !is.na(holding_share_panelai),
           profit_panelai > 0) |>
    mutate(profit_adj_ratio_bounded = pmin(pmax(profit_adj_ratio_observed, 0), 1))

  branch <- correction |>
    group_by(profit_correction_source_baseline) |>
    summarise(
      cells = sum(rows),
      uncorrected_profit = sum(uncorrected_profit, na.rm = TRUE),
      corrected_profit = sum(corrected_profit, na.rm = TRUE),
      reduction = sum(reduction, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(
      reduction_rate = safe_divide(reduction, uncorrected_profit),
      reduction_share = safe_divide(reduction, sum(reduction, na.rm = TRUE)),
      label = recode(
        profit_correction_source_baseline,
        "observed_profit_adj" = "Observed PROFIT\\_ADJ",
        "domestic_upe_hugger" = "Domestic UPE correction",
        "uncorrected_foreign" = "Uncorrected foreign cells",
        .default = profit_correction_source_baseline
      ),
      order = match(
        profit_correction_source_baseline,
        c("observed_profit_adj", "domestic_upe_hugger", "uncorrected_foreign")
      )
    ) |>
    arrange(order)

  total <- branch |>
    summarise(
      label = "Total preferred correction",
      cells = sum(cells),
      uncorrected_profit = sum(uncorrected_profit),
      corrected_profit = sum(corrected_profit),
      reduction = sum(reduction),
      reduction_rate = safe_divide(reduction, uncorrected_profit),
      reduction_share = 1
    )

  effect_rows <- bind_rows(branch, total) |>
    transmute(
      label,
      cells = fmt_int(cells),
      uncorrected = fmt_bn(uncorrected_profit, 1),
      corrected = fmt_bn(corrected_profit, 1),
      reduction = fmt_bn(reduction, 1),
      reduction_rate = fmt_pct(reduction_rate, 1),
      reduction_share = fmt_pct(reduction_share, 1)
    )

  observed_total <- support |>
    summarise(
      cells_with_profit_adj = sum(cells_with_profit_adj, na.rm = TRUE),
      parents_with_profit_adj = max(parents_with_profit_adj, na.rm = TRUE),
      affiliates_with_profit_adj = sum(affiliates_with_profit_adj, na.rm = TRUE),
      median_ratio = median(median_profit_adj_ratio, na.rm = TRUE),
      min_ratio = min(min_profit_adj_ratio, na.rm = TRUE),
      max_ratio = max(max_profit_adj_ratio, na.rm = TRUE)
    )

  fit <- if (nrow(panel) >= 10) {
    summary(stats::lm(profit_adj_ratio_bounded ~ holding_share_panelai,
                      data = panel))
  } else {
    NULL
  }

  beta <- if (!is.null(fit)) fit$coefficients["holding_share_panelai", "Estimate"] else NA_real_
  se <- if (!is.null(fit)) fit$coefficients["holding_share_panelai", "Std. Error"] else NA_real_
  p_value <- if (!is.null(fit)) fit$coefficients["holding_share_panelai", "Pr(>|t|)"] else NA_real_
  r_squared <- if (!is.null(fit)) fit$r.squared else NA_real_

  diagnostic_rows <- tibble(
    label = c(
      "Observed adjusted-profit cells",
      "Parents with observed adjusted profit",
      "Affiliate observations with adjusted profit",
      "Median adjusted-to-unadjusted ratio",
      "Observed ratio range",
      "Holding-share slope",
      "Holding-share regression R-squared"
    ),
    cells = c(
      fmt_int(observed_total$cells_with_profit_adj),
      fmt_int(observed_total$parents_with_profit_adj),
      fmt_int(observed_total$affiliates_with_profit_adj),
      fmt_num(observed_total$median_ratio, 3),
      paste0(fmt_num(observed_total$min_ratio, 3), " to ",
             fmt_num(observed_total$max_ratio, 3)),
      coef_cell(beta, se, p_value, 3),
      fmt_num(r_squared, 3)
    ),
    uncorrected = "",
    corrected = "",
    reduction = "",
    reduction_rate = "",
    reduction_share = ""
  )

  lines <- c(
    "\\begin{table}[H]",
    "\\centering",
    "\\scriptsize",
    "\\caption[Profit-base correction effects]{Profit-base correction effects and diagnostic support, 2017 to 2022}",
    "\\label{tab:profit_correction_effects}",
    "\\resizebox{\\textwidth}{!}{%",
    "\\begin{tabular}{@{}lrrrrrr@{}}",
    "\\toprule",
    "Correction branch & Cells & Uncorrected profit & Corrected profit & Reduction & Reduction rate & Share of reduction \\\\",
    "\\midrule",
    "\\multicolumn{7}{l}{\\textit{Panel A: implemented economic effect, USD billions}} \\\\"
  )

  for (i in seq_len(nrow(effect_rows))) {
    lines <- c(lines, paste0(
      effect_rows$label[i], " & ",
      effect_rows$cells[i], " & ",
      effect_rows$uncorrected[i], " & ",
      effect_rows$corrected[i], " & ",
      effect_rows$reduction[i], " & ",
      effect_rows$reduction_rate[i], " & ",
      effect_rows$reduction_share[i], " \\\\"
    ))
  }

  lines <- c(
    lines,
    "\\addlinespace",
    "\\multicolumn{7}{l}{\\textit{Panel B: support for not estimating a full-panel adjusted-profit model}} \\\\"
  )

  for (i in seq_len(nrow(diagnostic_rows))) {
    lines <- c(lines, paste0(
      diagnostic_rows$label[i], " & ",
      diagnostic_rows$cells[i], " & ",
      diagnostic_rows$uncorrected[i], " & ",
      diagnostic_rows$corrected[i], " & ",
      diagnostic_rows$reduction[i], " & ",
      diagnostic_rows$reduction_rate[i], " & ",
      diagnostic_rows$reduction_share[i], " \\\\"
    ))
  }

  lines <- c(
    lines,
    "\\bottomrule",
    "\\end{tabular}",
    "}",
    "",
    "\\vspace{0.5em}",
    "\\begin{minipage}{0.96\\textwidth}",
    paste0(
      "\\footnotesize\\raggedright \\textit{Notes:} Profit amounts are Panel A-I positive-profit CbCR profit in USD billions. ",
      "Panel B reports the direct support for adjusted-profit modelling. The holding-share slope comes from an OLS regression of the bounded observed adjusted-to-unadjusted profit ratio on the holding-company entity share; standard error in parentheses. ",
      "The small and country-concentrated adjusted-profit sample is treated as diagnostic evidence rather than as a donor sample for full-panel imputation. ",
      source_note(c("data/processed/diagnostics/step2_profit_correction_by_year.csv",
                    "data/processed/diagnostics/cbcr_t1_profit_adj_support_by_year.csv",
                    "data/processed/base_panel.rds"))
    ),
    "\\end{minipage}",
    "\\end{table}"
  )

  write_custom_table(file.path(GEN_TABLES, "profit_correction_effects.tex"), lines)
}

write_stage1_source_table <- function() {
  branch <- read_diag("step3_stage1_pair_year_branch_by_year.csv")
  panel <- read_processed("stage1_bilateral_panel.rds")

  years <- sort(unique(panel$year))
  branch_wide <- branch |>
    mutate(label = recode(
      stage1_distributional_source,
      "direct_t4" = "Direct Table IV",
      "percentile_fit" = "Beta percentile fit",
      "shape_transport" = "BSPI shape transport",
      "avg_only" = "Jurisdiction-average fallback",
      "missing" = "Missing source",
      .default = stage1_distributional_source
    )) |>
    select(year, label, pair_years) |>
    pivot_wider(names_from = year, values_from = pair_years, values_fill = 0)

  order_labels <- c("Direct Table IV", "Beta percentile fit", "BSPI shape transport",
                    "Jurisdiction-average fallback", "Missing source")

  body <- branch_wide |>
    mutate(label = factor(label, levels = order_labels)) |>
    arrange(label) |>
    mutate(Total = rowSums(across(all_of(as.character(years))))) |>
    transmute(
      Source = as.character(label),
      across(all_of(as.character(years)), fmt_int),
      Total = fmt_int(Total)
    )

  totals <- panel |>
    filter(year %in% years) |>
    group_by(year) |>
    summarise(
      all_cells = n(),
      positive_cells = sum(analysis_profit_positive > 0, na.rm = TRUE),
      .groups = "drop"
    )

  total_rows <- bind_rows(
    totals |>
      transmute(label = "All analysis pair-years", year, value = all_cells),
    totals |>
      transmute(label = "Positive-profit pair-years", year, value = positive_cells)
  ) |>
    pivot_wider(names_from = year, values_from = value) |>
    mutate(Total = rowSums(across(all_of(as.character(years))))) |>
    transmute(
      Source = label,
      across(all_of(as.character(years)), fmt_int),
      Total = fmt_int(Total)
    )

  rows <- bind_rows(body, total_rows)
  rows[, 1] <- latex_escape(rows[[1]])

  write_latex_table(
    file.path(GEN_TABLES, "stage1_source_coverage.tex"),
    caption = "Stage 1 source coverage, 2017 to 2022",
    short_caption = "Stage 1 source coverage",
    label = "tab:stage1_source_updated",
    col_spec = paste0("l", paste(rep("r", length(years) + 1), collapse = "")),
    header = c("Source", years, "Total"),
    rows = rows,
    notes = paste(
      "Counts are parent-affiliate-year cells in the Stage 1 bilateral panel.",
      "Positive-profit cells are shown separately because only those cells can generate top-up tax.",
      source_note(c("data/processed/diagnostics/step3_stage1_pair_year_branch_by_year.csv",
                    "data/processed/stage1_bilateral_panel.rds"))
    )
  )
}

write_stage1_rates_table <- function() {
  scenario <- read_diag("step3_stage1_scenario_by_year.csv") |>
    filter(scope %in% c("eu27", "global")) |>
    arrange(scope, year)

  years <- sort(unique(scenario$year))
  make_scope_rows <- function(scope_id, scope_label) {
    dat <- scenario |> filter(scope == scope_id)
    bind_rows(
      tibble(row = "\\multicolumn{7}{l}{\\textit{" %+% scope_label %+% "}}"),
      tibble(
        row = c(
          "Average rule, low-taxed share",
          "Average rule, top-up gap",
          "Average rule, liability rate",
          "Distributional rule, low-taxed share",
          "Distributional rule, top-up gap",
          "Distributional rule, liability rate"
        ),
        metric = c(
          "average_low_share",
          "average_topup_rate",
          "average_liability_rate",
          "distributional_low_share",
          "distributional_topup_rate",
          "distributional_liability_rate"
        )
      ) |>
        rowwise() |>
        mutate(values = list(fmt_pct(dat[[metric]], 1))) |>
        ungroup()
    )
  }

  eu_rows <- make_scope_rows("eu27", "EU27")
  global_rows <- make_scope_rows("global", "Global")

  table_rows <- list()
  for (block in list(eu_rows, global_rows)) {
    for (i in seq_len(nrow(block))) {
      if (!is.null(block$values[[i]])) {
        table_rows[[length(table_rows) + 1L]] <- c(latex_escape(block$row[i]),
                                                   block$values[[i]])
      } else {
        table_rows[[length(table_rows) + 1L]] <- paste0(block$row[i], " \\\\")
      }
    }
  }

  lines <- c(
    "\\begin{table}[H]",
    "\\centering",
    "\\small",
    "\\caption[Stage 1 rates, EU27 and global]{Stage 1 rates before SBIE and behavioural responses. Low-taxed share is low-taxed profit divided by positive corrected profit. The top-up gap is the profit-weighted average distance to the 15 per cent threshold on the measured low-taxed profit mass. Liability rate is aggregate Stage 1 top-up divided by positive corrected profit. All entries are percentages.}",
    "\\label{tab:stage1_rates_updated}",
    "\\begin{tabular}{@{}lrrrrrr@{}}",
    "\\toprule",
    paste0(" & ", paste(years, collapse = " & "), " \\\\"),
    "\\midrule"
  )

  for (row in table_rows) {
    if (length(row) == 1) {
      lines <- c(lines, row)
    } else {
      lines <- c(lines, paste0(paste(row, collapse = " & "), " \\\\"))
    }
  }

  lines <- c(
    lines,
    "\\bottomrule",
    "\\end{tabular}",
    "",
    "\\vspace{0.5em}",
    "\\begin{minipage}{0.96\\textwidth}",
    paste0("\\footnotesize\\raggedright \\textit{Notes:} Ratios are aggregate ratios from the bilateral Stage 1 panel, not unweighted country averages. ",
           source_note("data/processed/diagnostics/step3_stage1_scenario_by_year.csv")),
    "\\end{minipage}",
    "\\end{table}"
  )

  write_custom_table(file.path(GEN_TABLES, "stage1_rates.tex"), lines)
}

`%+%` <- function(a, b) paste0(a, b)

write_stage1_bspi_table <- function() {
  bspi <- read_diag("step3_stage1_bspi_validation.csv")
  names <- read_processed("base_panel.rds") |>
    distinct(affiliate, affiliate_jurisdiction_name)

  selected <- bspi |>
    filter(affiliate %in% EU27_ISO3) |>
    left_join(names, by = "affiliate") |>
    arrange(desc(bspi_tv_anchor_validation)) |>
    slice_head(n = 6) |>
    bind_rows(
      bspi |>
        filter(affiliate %in% c("NLD", "LUX", "IRL")) |>
        left_join(names, by = "affiliate")
    ) |>
    distinct(affiliate, .keep_all = TRUE) |>
    arrange(desc(bspi_tv_anchor_validation)) |>
    transmute(
      Affiliate = latex_escape(coalesce(affiliate_jurisdiction_name, affiliate)),
      `Anchor low share` = fmt_num(anchor_low_share, 2),
      `Validation low share` = fmt_num(validation_low_share, 2),
      `TV distance` = fmt_num(bspi_tv_anchor_validation, 2),
      Flag = fmt_bool(bspi_high_tv_flag)
    )

  write_latex_table(
    file.path(GEN_TABLES, "stage1_bspi_validation.tex"),
    caption = "EU27 BSPI validation, 2019 to 2020 anchor versus 2021 to 2022 validation",
    short_caption = "EU27 BSPI validation",
    label = "tab:stage1_bspi_updated",
    col_spec = "lrrrr",
    header = c("Affiliate", "Anchor low share", "Validation low share",
               "TV distance", "Flag"),
    rows = selected,
    notes = source_note("data/processed/diagnostics/step3_stage1_bspi_validation.csv")
  )
}

write_stage1_crossval_table <- function() {
  x <- read_diag("step3_stage1_crossval_summary.csv")
  get <- function(metric) as.numeric(metric_value(x, metric))

  rows <- tibble(
    Statistic = latex_escape(c(
      "Overlap affiliate-years",
      "Zero-low-share cells in Table IV",
      "Low-taxed share, median gap",
      "Low-taxed share, mean absolute error",
      "Low-taxed share, p90 absolute error",
      "Low-taxed share, Spearman rho",
      "Calibration slope, direct on fitted",
      "Calibration R-squared",
      "Liability rate, median gap",
      "Liability rate, mean absolute error",
      "Liability rate, p90 absolute error",
      "Positive-partition TV, median",
      "Positive-partition TV, p90",
      "Low-share Wilcoxon p-value"
    )),
    Value = c(
      fmt_int(get("overlap_affiliate_years")),
      fmt_int(get("overlap_zero_low_share_cases")),
      fmt_num(get("low_share_median_diff"), 3),
      fmt_num(get("low_share_mae"), 3),
      fmt_num(get("low_share_p90_abs_error"), 3),
      fmt_num(get("low_share_spearman"), 3),
      fmt_num(get("low_share_calibration_slope"), 2),
      fmt_num(get("low_share_calibration_r_squared"), 3),
      fmt_num(get("liability_rate_median_diff"), 3),
      fmt_num(get("liability_rate_mae"), 3),
      fmt_num(get("liability_rate_p90_abs_error"), 3),
      fmt_num(get("positive_partition_tv_median"), 3),
      fmt_num(get("positive_partition_tv_p90"), 3),
      fmt_p(get("crossval_low_share_wilcox_pvalue"))
    )
  )

  write_latex_table(
    file.path(GEN_TABLES, "stage1_crossval.tex"),
    caption = "Beta percentile fit versus Table IV cross-validation",
    short_caption = "Beta percentile fit versus Table IV cross-validation",
    label = "tab:app_stage1_crossval",
    col_spec = "lr",
    header = c("Statistic", "Value"),
    rows = rows,
    notes = paste(
      "Differences are Table I constrained-Beta percentile fit minus Table IV direct observation.",
      "Calibration regresses the direct Table IV low-taxed share on the fitted Table I low-taxed share and year fixed effects.",
      source_note("data/processed/diagnostics/step3_stage1_crossval_summary.csv")
    )
  )
}

write_stage2_aggregate_table <- function() {
  x <- read_diag("step4_stage2_scenario_by_year.csv") |>
    filter(scope %in% c("eu27", "global"))

  agg <- x |>
    group_by(scope, rate_scenario) |>
    summarise(
      positive_profit_weight = sum(total_positive_profit, na.rm = TRUE),
      sbie_ratio = weighted.mean(profit_weighted_stage2_phi,
                                 total_positive_profit, na.rm = TRUE),
      stage1_avg = weighted.mean(stage1_average_liability_rate,
                                 total_positive_profit, na.rm = TRUE),
      stage2_avg = weighted.mean(stage2_average_liability_rate,
                                 total_positive_profit, na.rm = TRUE),
      stage1_dist = weighted.mean(stage1_distributional_liability_rate,
                                  total_positive_profit, na.rm = TRUE),
      stage2_dist = weighted.mean(stage2_distributional_liability_rate,
                                  total_positive_profit, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(
      scope = recode(scope, "eu27" = "EU27", "global" = "Global"),
      rate_scenario = recode(rate_scenario, "initial" = "Initial",
                             "long_run" = "Long-run")
    ) |>
    arrange(match(scope, c("EU27", "Global")),
            match(rate_scenario, c("Initial", "Long-run"))) |>
    transmute(
      Scope = latex_escape(scope),
      `SBIE rates` = latex_escape(rate_scenario),
      `SBIE ratio` = fmt_pct(sbie_ratio, 1),
      `Stage 1, avg` = fmt_pct(stage1_avg, 2),
      `Stage 2, avg` = fmt_pct(stage2_avg, 2),
      `Stage 1, dist` = fmt_pct(stage1_dist, 2),
      `Stage 2, dist` = fmt_pct(stage2_dist, 2)
    )

  write_latex_table(
    file.path(GEN_TABLES, "stage2_aggregate.tex"),
    caption = "Aggregate Stage 2 effect of the SBIE",
    short_caption = "Aggregate Stage 2 effect of the SBIE",
    label = "tab:stage2_aggregate_updated",
    col_spec = "llrrrrr",
    header = c("Scope", "SBIE rates", "SBIE ratio", "Stage 1, avg",
               "Stage 2, avg", "Stage 1, dist", "Stage 2, dist"),
    rows = agg,
    notes = paste(
      "Initial rates use a 10 per cent payroll carve-out and an 8 per cent tangible-asset carve-out.",
      "Long-run rates use 5 per cent for both components.",
      source_note("data/processed/diagnostics/step4_stage2_scenario_by_year.csv")
    )
  )
}

write_stage2_sectoral_table <- function() {
  x <- read_diag("step4_stage2_sectoral_country_summary.csv") |>
    filter(transition_year == 2024, rate_scenario == "initial")

  eu <- x |>
    summarise(
      affiliate_name = "EU27 weighted",
      profit_weight = sum(total_profit_proxy, na.rm = TRUE),
      weighted_phi = weighted.mean(weighted_phi, total_profit_proxy, na.rm = TRUE),
      weighted_kappa = weighted.mean(weighted_kappa, total_profit_proxy, na.rm = TRUE),
      weighted_floor_distributional =
        weighted.mean(weighted_floor_distributional, total_profit_proxy, na.rm = TRUE),
      weighted_floor_distributional_sbti =
        weighted.mean(weighted_floor_distributional_sbti,
                      total_profit_proxy, na.rm = TRUE)
    )

  countries <- x |>
    filter(affiliate %in% SELECTED_COUNTRIES) |>
    arrange(match(affiliate, SELECTED_COUNTRIES)) |>
    select(affiliate_name, total_profit_proxy, weighted_phi, weighted_kappa,
           weighted_floor_distributional, weighted_floor_distributional_sbti)

  rows <- bind_rows(eu, countries) |>
    mutate(change = weighted_floor_distributional_sbti -
             weighted_floor_distributional) |>
    transmute(
      Country = latex_escape(affiliate_name),
      `SBIE ratio` = fmt_pct(weighted_phi, 1),
      `SBTI capacity` = fmt_pct(weighted_kappa, 1),
      `Floor before SBTI` = fmt_pct(weighted_floor_distributional, 1),
      `Floor after SBTI` = fmt_pct(weighted_floor_distributional_sbti, 1),
      Change = fmt_pct(change, 1)
    )

  write_latex_table(
    file.path(GEN_TABLES, "stage2_sectoral_sbti.tex"),
    caption = "Sectoral SBTI effect in selected EU countries",
    short_caption = "Sectoral SBTI effect in selected EU countries",
    label = "tab:stage2_sectoral_sbti",
    col_spec = "lrrrrr",
    header = c("Country", "SBIE ratio", "SBTI capacity", "Floor before SBTI",
               "Floor after SBTI", "Change"),
    rows = rows,
    notes = paste(
      "The table uses the 2022 EU sectoral reference matrix and initial 2024 rates.",
      "All rates are percentages.",
      source_note("data/processed/diagnostics/step4_stage2_sectoral_country_summary.csv")
    )
  )
}

write_stage2_h5_table <- function() {
  x <- read_diag("step4_stage2_sectoral_h5_regression_clustered.csv") |>
    filter(term == "sectoral_capital_intensity") |>
    mutate(model_variant = recode(model_variant,
                                  "unweighted" = "Unweighted",
                                  "profit_weighted" = "Profit-weighted")) |>
    arrange(match(model_variant, c("Unweighted", "Profit-weighted"))) |>
    transmute(
      Specification = latex_escape(model_variant),
      Coefficient = fmt_num(estimate, 5),
      `Cluster SE` = fmt_num(std_error, 5),
      `$p$-value` = fmt_p(p_value),
      Observations = fmt_int(n_obs),
      `$R^2$` = fmt_num(r_squared, 3)
    )

  write_latex_table(
    file.path(GEN_TABLES, "stage2_h5_regression.tex"),
    caption = "H5 sectoral capital-intensity regression",
    short_caption = "H5 sectoral capital-intensity regression",
    label = "tab:stage2_h5_regression",
    col_spec = "lrrrrr",
    header = c("Specification", "Coefficient", "Cluster SE", "$p$-value",
               "Observations", "$R^2$"),
    rows = x,
    notes = paste(
      "Dependent variable: SBTI-induced change in the average effective floor in the 2022 EU sectoral reference matrix.",
      source_note("data/processed/diagnostics/step4_stage2_sectoral_h5_regression_clustered.csv")
    )
  )
}

write_stage3_model_table <- function() {
  x <- read_diag("step5_stage3_model_comparison.csv") |>
    arrange(bic_rank) |>
    transmute(
      Model = latex_escape(str_to_sentence(model_spec)),
      `$N$` = fmt_int(n),
      Pairs = fmt_int(n_pairs),
      `Within $R^2$` = fmt_num(within_r_squared, 4),
      `BIC rank` = fmt_int(bic_rank),
      `$\\Delta$BIC` = fmt_num(delta_bic, 2),
      `Tax Wald $p$, two-way` = fmt_p(tax_terms_joint_p_value_two_way)
    )

  write_latex_table(
    file.path(GEN_TABLES, "stage3_model_comparison.tex"),
    caption = "Stage 3 model comparison",
    short_caption = "Stage 3 model comparison",
    label = "tab:stage3_model_comparison",
    col_spec = "lrrrrrr",
    header = c("Model", "$N$", "Pairs", "Within $R^2$", "BIC rank",
               "$\\Delta$BIC", "Tax Wald $p$, two-way"),
    rows = x,
    notes = paste(
      "Two-way fixed-effect Hines-Rice models.",
      "The BIC ranking is the model-selection rule used in the current pipeline.",
      source_note("data/processed/diagnostics/step5_stage3_model_comparison.csv")
    )
  )
}

write_stage3_regression_table <- function() {
  coefficients <- read_diag("step5_stage3_coefficients.csv") |>
    filter(inference == "parent_affiliate_clustered") |>
    mutate(
      model_label = normalise_model_label(model_spec),
      term_label = normalise_term_label(term),
      cell = coef_cell(estimate, std_error, p_value, 3)
    )

  model_order <- c("Linear", "Quadratic", "Logarithmic")
  term_order <- c("ETR", "ETR squared", "Log shifted ETR",
                  "Log tangible assets", "Log payroll proxy",
                  "Log GDP per capita", "Log population")

  coefficient_rows <- tibble(Variable = term_order) |>
    left_join(
      coefficients |>
        select(Variable = term_label, model_label, cell) |>
        pivot_wider(names_from = model_label, values_from = cell),
      by = "Variable"
    ) |>
    mutate(across(all_of(model_order), ~ replace_na(.x, "")))

  model_stats <- read_diag("step5_stage3_model_comparison.csv") |>
    mutate(model_label = normalise_model_label(model_spec)) |>
    select(model_label, n, n_pairs, n_affiliates, within_r_squared, bic_rank,
           delta_bic, tax_terms_joint_p_value_two_way) |>
    pivot_longer(-model_label, names_to = "statistic", values_to = "value") |>
    mutate(
      Statistic = recode(
        statistic,
        "n" = "$N$",
        "n_pairs" = "Parent-affiliate pairs",
        "n_affiliates" = "Affiliate clusters",
        "within_r_squared" = "Within $R^2$",
        "bic_rank" = "BIC rank",
        "delta_bic" = "$\\Delta$BIC",
        "tax_terms_joint_p_value_two_way" = "Joint tax-term $p$"
      ),
      formatted = case_when(
        statistic %in% c("n", "n_pairs", "n_affiliates", "bic_rank") ~
          fmt_int(value),
        statistic == "tax_terms_joint_p_value_two_way" ~ fmt_p(value),
        statistic == "within_r_squared" ~ fmt_num(value, 4),
        TRUE ~ fmt_num(value, 2)
      )
    ) |>
    select(Statistic, model_label, formatted) |>
    pivot_wider(names_from = model_label, values_from = formatted)

  stat_order <- c("$N$", "Parent-affiliate pairs", "Affiliate clusters",
                  "Within $R^2$", "BIC rank", "$\\Delta$BIC",
                  "Joint tax-term $p$")
  statistic_rows <- tibble(Variable = stat_order) |>
    left_join(rename(model_stats, Variable = Statistic), by = "Variable") |>
    mutate(across(all_of(model_order), ~ replace_na(.x, "")))

  rows <- bind_rows(
    coefficient_rows,
    tibble(Variable = "\\midrule", Linear = "", Quadratic = "",
           Logarithmic = ""),
    statistic_rows
  )

  row_lines <- apply(as.matrix(rows), 1, function(r) {
    if (r[1] == "\\midrule") {
      "\\midrule"
    } else {
      paste0(paste(r, collapse = " & "), " \\\\")
    }
  })

  lines <- c(
    "\\begin{table}[H]",
    "\\centering",
    "\\small",
    "\\caption[Stage 3 fixed-effect regression estimates]{Stage 3 fixed-effect regression estimates. Dependent variable is log profit. Coefficients are reported with two-way parent-and-affiliate clustered standard errors in parentheses.}",
    "\\label{tab:stage3_regression_table}",
    "\\begin{tabular}{@{}lccc@{}}",
    "\\toprule",
    " & Linear & Quadratic & Logarithmic \\\\",
    "\\midrule",
    row_lines,
    "\\bottomrule",
    "\\end{tabular}",
    "",
    "\\vspace{0.5em}",
    "\\begin{minipage}{0.96\\textwidth}",
    paste0(
      "\\footnotesize\\raggedright \\textit{Notes:} All models include parent-affiliate pair fixed effects and year fixed effects. ",
      "$^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$. ",
      source_note(c("data/processed/diagnostics/step5_stage3_coefficients.csv",
                    "data/processed/diagnostics/step5_stage3_model_comparison.csv"))
    ),
    "\\end{minipage}",
    "\\end{table}"
  )

  write_custom_table(file.path(GEN_TABLES, "stage3_regression_table.tex"), lines)
}

write_stage3_iv_table <- function() {
  iv_raw <- read_diag("step5_stage3_tax_endogeneity_diagnostics.csv")
  if (!"instrument_label" %in% names(iv_raw)) {
    iv_raw <- iv_raw |>
      mutate(
        instrument_label = case_when(
          str_detect(diagnostic, "simulated") ~
            "OECD simulated fixed-project EATR",
          str_detect(diagnostic, "statutory") ~ "Lagged statutory CIT",
          TRUE ~ "Excluded instrument"
        )
      )
  }
  if (!"weak_instrument_f" %in% names(iv_raw)) {
    iv_raw <- iv_raw |>
      mutate(weak_instrument_f = f_statistic)
  }

  iv <- iv_raw |>
    filter(inference == "parent_affiliate_clustered") |>
    mutate(
      Instrument = instrument_label,
      Diagnostic = case_when(
        str_detect(diagnostic, "first_stage") ~ "First stage: CbCR ETR",
        str_detect(diagnostic, "reduced_form") ~ "Reduced form: log profit",
        str_detect(diagnostic, "2sls") ~ "FE-2SLS: log profit",
        TRUE ~ diagnostic
      ),
      `Dependent variable` = recode(
        dependent_variable,
        "tau" = "CbCR ETR",
        "log_profit" = "Log profit",
        .default = dependent_variable
      )
    ) |>
    arrange(
      match(Instrument,
            c("OECD simulated fixed-project EATR", "Lagged statutory CIT")),
      match(Diagnostic,
            c("First stage: CbCR ETR", "Reduced form: log profit",
              "FE-2SLS: log profit"))
    ) |>
    transmute(
      Instrument = latex_escape(Instrument),
      Diagnostic = latex_escape(Diagnostic),
      `Dependent variable` = latex_escape(`Dependent variable`),
      Coefficient = paste0(
        fmt_num(estimate, 3), significance_stars(p_value),
        " (", fmt_num(std_error, 3), ")"
      ),
      `Weak-IV $F$` = fmt_num(weak_instrument_f, 2),
      `$p$-value` = fmt_p(p_value),
      `$N$` = fmt_int(n),
      `Within $R^2$` = fmt_num(within_r_squared, 4)
    )

  write_latex_table(
    file.path(GEN_TABLES, "stage3_iv_diagnostics.tex"),
    caption = "Tax-code instrument diagnostics",
    short_caption = "Tax-code instrument diagnostics",
    label = "tab:stage3_iv_diagnostics",
    col_spec = "lllrrrrr",
    header = c("Instrument", "Diagnostic", "Dependent variable", "Coefficient",
               "Weak-IV $F$", "$p$-value", "$N$", "Within $R^2$"),
    rows = iv,
    notes = paste(
      "The table reports fixed-effect first stages, reduced forms and linear FE-2SLS robustness estimates.",
      "The simulated instrument is the current-year OECD forward-looking effective average tax rate for a fixed composite investment project in the affiliate jurisdiction.",
      "The statutory benchmark uses the one-year lagged statutory CIT rate of the affiliate jurisdiction.",
      "The weak-instrument statistic is the parent-and-affiliate clustered first-stage F-statistic for each excluded instrument.",
      "The 2SLS row is not used for the nonlinear counterfactual because one excluded instrument identifies only the linear ETR coefficient.",
      source_note("data/processed/diagnostics/step5_stage3_tax_endogeneity_diagnostics.csv")
    ),
    size = "\\scriptsize",
    resize = TRUE
  )
}

write_stage3_econometric_scorecard_table <- function() {
  model <- read_diag("step5_stage3_model_comparison.csv") |>
    arrange(bic_rank)
  wald <- read_diag("step5_stage3_model_wald_tests.csv") |>
    filter(inference == "parent_affiliate_clustered")
  iv <- read_diag("step5_stage3_tax_endogeneity_diagnostics.csv") |>
    filter(inference == "parent_affiliate_clustered")
  spec <- read_diag("step5_stage3_specification_tests.csv")
  tail <- read_diag("step5_stage3_etr_tail_support.csv") |>
    filter(scope == "pooled")
  robustness <- read_diag("step5_stage3_model_robustness.csv")

  preferred <- model |> slice(1)
  log_model <- model |> filter(model_spec == "logarithmic")
  quad_model <- model |> filter(model_spec == "quadratic")
  linear_wald <- wald |> filter(model_spec == "linear") |> slice(1)
  log_wald <- wald |> filter(model_spec == "logarithmic") |> slice(1)
  quad_wald <- wald |> filter(model_spec == "quadratic") |> slice(1)

  simulated_first <- iv |>
    filter(diagnostic == "simulated_tax_code_eatr_first_stage_for_cbcr_etr") |>
    slice(1)
  simulated_2sls <- iv |>
    filter(diagnostic == "simulated_tax_code_eatr_2sls_for_profit") |>
    slice(1)
  statutory_first <- iv |>
    filter(diagnostic == "lagged_statutory_cit_first_stage_for_cbcr_etr") |>
    slice(1)
  statutory_2sls <- iv |>
    filter(diagnostic == "lagged_statutory_cit_2sls_for_profit") |>
    slice(1)

  below_5 <- tail |> filter(tail_band == "below_5pct") |> slice(1)
  five_to_15 <- tail |> filter(tail_band == "five_to_15pct") |> slice(1)

  stable_samples <- robustness |>
    group_by(sample) |>
    slice_min(bic_rank, n = 1, with_ties = FALSE) |>
    ungroup()
  linear_stable <- stable_samples |>
    filter(model_spec == "linear") |>
    summarise(n = n(), .groups = "drop") |>
    pull(n)
  total_stable <- nrow(stable_samples)

  influence_path <- file.path(DIAG, "step10_jurisdiction_influence_case_summary.csv")
  if (file.exists(influence_path)) {
    influence <- read_csv(influence_path, show_col_types = FALSE)
    influence_result <- paste0(
      "Leave-one semi-elasticity range ",
      fmt_num(min(influence$leave_semielasticity_5, na.rm = TRUE), 2),
      "--",
      fmt_num(max(influence$leave_semielasticity_5, na.rm = TRUE), 2),
      "; preferred model stable in ",
      fmt_int(sum(influence$preferred_model_stable, na.rm = TRUE)),
      " of ",
      fmt_int(nrow(influence)),
      " cases; revenue change ",
      fmt_pct(min(influence$preferred_sbs_behavioural_revenue_pct_change,
                  na.rm = TRUE), 1),
      "\\% to ",
      fmt_pct(max(influence$preferred_sbs_behavioural_revenue_pct_change,
                  na.rm = TRUE), 1),
      "\\%."
    )
  } else {
    influence_result <- "Leave-one-jurisdiction diagnostics not yet generated."
  }

  rows <- tibble(
    Diagnostic = c(
      "Preferred fixed-effect model",
      "Joint tax-term tests",
      "Non-nested nonlinear tests",
      "Tax-code IV diagnostics",
      "Low-ETR support",
      "Sample robustness",
      "Jurisdiction influence"
    ),
    Result = c(
      paste0(
        latex_escape(str_to_sentence(preferred$model_spec[1])),
        "; $N=$", fmt_int(preferred$n[1]),
        "; pairs $=$ ", fmt_int(preferred$n_pairs[1]),
        "; within $R^2=$ ", fmt_num(preferred$within_r_squared[1], 4),
        "; $\\Delta$BIC log $=$ ", fmt_num(log_model$delta_bic[1], 2),
        ", quadratic $=$ ", fmt_num(quad_model$delta_bic[1], 2), "."
      ),
      paste0(
        "Linear $F=$ ", fmt_num(linear_wald$f_statistic[1], 2),
        ", $p=$ ", fmt_p(linear_wald$p_value[1]),
        "; quadratic $p=$ ", fmt_p(quad_wald$p_value[1]),
        "; logarithmic $p=$ ", fmt_p(log_wald$p_value[1]), "."
      ),
      paste0(
        "Vuong $p=$ ",
        fmt_p(spec$p_value[spec$test == "vuong_gaussian_observation_ll"][1]),
        "; Clarke $p=$ ",
        fmt_p(spec$p_value[spec$test == "clarke_sign"][1]),
        "; J-test $p=$ ",
        fmt_p(spec$p_value[spec$test == "davidson_mackinnon_j"][1]),
        " and ",
        fmt_p(spec$p_value[spec$test == "davidson_mackinnon_j"][2]), "."
      ),
      paste0(
        "First-stage $F=$ ", fmt_num(simulated_first$weak_instrument_f[1], 2),
        " for simulated EATR and ",
        fmt_num(statutory_first$weak_instrument_f[1], 2),
        " for lagged statutory CIT; 2SLS $p=$ ",
        fmt_p(simulated_2sls$p_value[1]), " and ",
        fmt_p(statutory_2sls$p_value[1]), "."
      ),
      paste0(
        "Below 5\\% ETR: ",
        fmt_pct(below_5$row_share[1], 1),
        "\\% of rows and ",
        fmt_pct(below_5$profit_share[1], 1),
        "\\% of profit; 5--15\\% ETR: ",
        fmt_pct(five_to_15$row_share[1], 1),
        "\\% of rows."
      ),
      paste0(
        "Linear is BIC-preferred in ",
        fmt_int(linear_stable),
        " of ",
        fmt_int(total_stable),
        " reported samples; the balanced-pair sample selects logarithmic."
      ),
      influence_result
    ),
    Reading = c(
      "The tax-profit relationship is visible after pair and year fixed effects, but the extra nonlinear parameters add little baseline fit.",
      "The tax terms are jointly relevant under two-way clustered inference.",
      "The logarithmic form is stronger than the quadratic form, but these tests do not overturn the linear BIC choice.",
      "External tax-code variation is relevant, yet the reduced-form profit response is too imprecise to replace the fixed-effect estimate.",
      "The GMT-relevant tail is present, while extreme lower-tail curvature remains weakly supported.",
      "The baseline coefficient survives standard sample cuts, with curvature becoming stronger only in the balanced subset.",
      "The behavioural coefficient is stable; final revenue remains exposed to high-leverage jurisdictions."
    )
  )

  write_latex_table(
    file.path(GEN_TABLES, "stage3_econometric_scorecard.tex"),
    caption = "Econometric diagnostics for the behavioural stage",
    short_caption = "Econometric diagnostics for the behavioural stage",
    label = "tab:stage3_econometric_scorecard",
    col_spec = "L{3.2cm}L{5.4cm}L{6.2cm}",
    header = c("Diagnostic", "Result", "Reading"),
    rows = rows,
    notes = paste(
      "The table compacts the formal diagnostics that support the Stage 3 behavioural counterfactual.",
      "It is generated from the same fixed-effect, IV, model-selection, tail-support and influence outputs used in the appendix.",
      source_note(c(
        "data/processed/diagnostics/step5_stage3_model_comparison.csv",
        "data/processed/diagnostics/step5_stage3_model_wald_tests.csv",
        "data/processed/diagnostics/step5_stage3_tax_endogeneity_diagnostics.csv",
        "data/processed/diagnostics/step5_stage3_specification_tests.csv",
        "data/processed/diagnostics/step5_stage3_etr_tail_support.csv",
        "data/processed/diagnostics/step5_stage3_model_robustness.csv",
        "data/processed/diagnostics/step10_jurisdiction_influence_case_summary.csv"
      ))
    ),
    size = "\\scriptsize",
    resize = TRUE
  )
}

write_stage3_semielasticity_table <- function() {
  x <- read_diag("step5_stage3_semielasticity_schedule.csv") |>
    filter(inference == "parent_affiliate_clustered", tau %in% c(0.05, 0.10)) |>
    arrange(match(model_spec, c("linear", "quadratic", "logarithmic")), tau) |>
    transmute(
      Model = latex_escape(str_to_sentence(model_spec)),
      ETR = paste0(fmt_pct(tau, 0), "\\%"),
      `Semi-elasticity` = fmt_num(semi_elasticity, 2),
      SE = fmt_num(std_error, 2),
      `$p$-value` = fmt_p(p_value),
      `Reallocation share` = paste0(fmt_pct(reallocation_share_to_15, 1), "\\%")
    )

  write_latex_table(
    file.path(GEN_TABLES, "stage3_semielasticity.tex"),
    caption = "Stage 3 semi-elasticity schedule",
    short_caption = "Stage 3 semi-elasticity schedule",
    label = "tab:stage3_semielasticity",
    col_spec = "lrrrrr",
    header = c("Model", "ETR", "Semi-elasticity", "SE", "$p$-value",
               "Reallocation share"),
    rows = x,
    notes = paste(
      "Standard errors are two-way clustered by parent and affiliate.",
      "Reallocation share is the implied reduction when the effective rate is raised to 15 per cent.",
      source_note("data/processed/diagnostics/step5_stage3_semielasticity_schedule.csv")
    )
  )
}

write_stage46_anova_table <- function() {
  x <- read_diag("step7_stage4_6_anova_pooled.csv") |>
    arrange(desc(eta_squared)) |>
    slice_head(n = 10) |>
    mutate(effect_label = vapply(
      strsplit(effect_label, " x ", fixed = TRUE),
      function(parts) paste(latex_escape(parts), collapse = " $\\times$ "),
      character(1)
    )) |>
    transmute(
      Effect = effect_label,
      Order = fmt_int(interaction_order),
      `Share (\\%)` = fmt_pct(eta_squared, 1)
    )

  write_latex_table(
    file.path(GEN_TABLES, "stage4_6_anova.tex"),
    caption = "Pooled factorial decomposition of EU GMT revenue",
    short_caption = "Pooled factorial decomposition of EU GMT revenue",
    label = "tab:stage4_6_anova_updated",
    col_spec = "lrr",
    header = c("Effect", "Order", "Share (\\%)"),
    rows = x,
    notes = paste(
      "Pooled orthogonal structural variance decomposition across the 32 legally allocated revenue scenarios, EU27 country-years, 2017 to 2022.",
      source_note("data/processed/diagnostics/step7_stage4_6_anova_pooled.csv")
    )
  )
}

write_stage46_shapley_table <- function() {
  x <- read_diag("step7_stage4_6_shapley_factor_attribution.csv") |>
    transmute(
      Factor = latex_escape(factor_label),
      Mechanism = latex_escape(effect_label),
      `Main share (\\%)` = fmt_pct(main_eta_squared, 1),
      `Interaction share (\\%)` = fmt_pct(interaction_eta_squared, 1),
      `Allocated share (\\%)` = fmt_pct(shapley_eta_squared, 1),
      `Uncertainty class` = latex_escape(uncertainty_class)
    )

  write_latex_table(
    file.path(GEN_TABLES, "stage4_6_shapley_factor_attribution.tex"),
    caption = "Shapley-style allocation of factorial revenue variance by economic mechanism",
    short_caption = "Shapley-style allocation of factorial revenue variance",
    label = "tab:stage4_6_shapley_attribution",
    col_spec = "L{2.2cm}L{3.2cm}rrrL{4.2cm}",
    header = c("Factor", "Mechanism", "Main share (\\%)",
               "Interaction share (\\%)", "Allocated share (\\%)",
               "Uncertainty class"),
    rows = x,
    notes = paste(
      "Interaction contrasts are allocated equally across the factors that enter them, giving a Shapley-style factor attribution that sums to the full scenario variance.",
      "The aleatoric label is reserved for bootstrap uncertainty in the estimated behavioural coefficients; the factorial behavioural contrast itself is a scenario contrast.",
      source_note("data/processed/diagnostics/step7_stage4_6_shapley_factor_attribution.csv")
    ),
    size = "\\scriptsize",
    resize = TRUE
  )
}

write_stage46_main_effects_table <- function() {
  x <- read_diag("step7_stage4_6_main_effects_pooled.csv") |>
    transmute(
      Factor = latex_escape(effect_label),
      `Low level` = fmt_bn(level_0, 1),
      `High level` = fmt_bn(level_1, 1),
      `High minus low` = fmt_bn(high_minus_low, 1)
    )

  write_latex_table(
    file.path(GEN_TABLES, "stage4_6_main_effects.tex"),
    caption = "Main effects on cumulative EU revenue",
    short_caption = "Main effects on cumulative EU revenue",
    label = "tab:stage4_6_main_effects",
    col_spec = "lrrr",
    header = c("Factor", "Low level", "High level", "High minus low"),
    rows = x,
    notes = paste(
      "Amounts are cumulative over 2017 to 2022 and expressed in US dollars, billions.",
      source_note("data/processed/diagnostics/step7_stage4_6_main_effects_pooled.csv")
    )
  )
}

write_stage46_channel_table <- function() {
  x <- read_diag("step7_stage4_6_preferred_channel_summary.csv") |>
    mutate(
      Regime = recode(factor4_sbs, "universal" = "Universal", "sbs" = "SbS"),
      Regime = factor(Regime, levels = c("Universal", "SbS")),
      channel = factor(channel, levels = c("IIR", "QDMTT", "UTPR"))
    ) |>
    arrange(Regime, channel) |>
    transmute(
      Regime = latex_escape(as.character(Regime)),
      Channel = latex_escape(as.character(channel)),
      `Revenue (US\\$ bn)` = fmt_num(revenue_bn, 1)
    )

  write_latex_table(
    file.path(GEN_TABLES, "preferred_channel.tex"),
    caption = "Preferred-core revenue by collection channel",
    short_caption = "Preferred-core revenue by collection channel",
    label = "tab:preferred_channel_updated",
    col_spec = "llr",
    header = c("Regime", "Channel", "Revenue (US\\$ bn)"),
    rows = x,
    notes = paste(
      "Preferred-core scenario: distributional ETR measurement, aggregate SBIE, initial carve-out rates and no behavioural response.",
      "Amounts are cumulative over 2017 to 2022.",
      source_note("data/processed/diagnostics/step7_stage4_6_preferred_channel_summary.csv")
    )
  )
}

write_stage1_measurement_error_table <- function() {
  input_file <- file.path(DIAG, "step9_stage1_measurement_error_preferred_interval.csv")
  if (!file.exists(input_file)) return(invisible(FALSE))

  x <- read_csv(input_file, show_col_types = FALSE) |>
    filter(draws >= 100) |>
    mutate(
      Regime = recode(factor4_sbs, "universal" = "Universal", "sbs" = "SbS"),
      Behaviour = recode(factor5_behaviour,
                         "mechanical" = "Mechanical",
                         "behavioural" = "Behavioural"),
      Regime = factor(Regime, levels = c("Universal", "SbS")),
      Behaviour = factor(Behaviour, levels = c("Mechanical", "Behavioural"))
    ) |>
    arrange(Behaviour, Regime) |>
    transmute(
      Behaviour = latex_escape(as.character(Behaviour)),
      Regime = latex_escape(as.character(Regime)),
      `Baseline (US\\$ bn)` = fmt_num(baseline_eu_revenue_bn, 1),
      `Median (US\\$ bn)` = fmt_num(p50_bn, 1),
      `5th pct.` = fmt_num(p05_bn, 1),
      `95th pct.` = fmt_num(p95_bn, 1),
      `90\\% width` = fmt_num(p90_width_bn, 1)
    )

  if (nrow(x) == 0) return(invisible(FALSE))

  write_latex_table(
    file.path(GEN_TABLES, "stage1_measurement_error_interval.tex"),
    caption = "Revenue interval from Stage 1 ETR measurement error",
    short_caption = "Stage 1 ETR measurement-error interval",
    label = "tab:stage1_measurement_error_interval",
    col_spec = "llrrrrr",
    header = c("Behaviour", "Regime", "Baseline (US\\$ bn)",
               "Median (US\\$ bn)", "5th pct.", "95th pct.", "90\\% width"),
    rows = x,
    notes = paste(
      "Intervals use centred empirical validation residuals from the Table I percentile-fit versus Table IV direct-bracket overlap.",
      "The reported rows hold the preferred ETR, aggregate SBIE and initial-rate scenario fixed, then vary behaviour and implementation regime.",
      source_note("data/processed/diagnostics/step9_stage1_measurement_error_preferred_interval.csv")
    )
  )

  invisible(TRUE)
}

write_stage46_country_spread_table <- function() {
  x <- read_diag("step7_stage4_6_scenario_spread_country.csv") |>
    filter(country %in% SELECTED_COUNTRIES) |>
    arrange(match(country, SELECTED_COUNTRIES)) |>
    transmute(
      Country = latex_escape(country_name),
      Minimum = fmt_bn(min_revenue, 1),
      Maximum = fmt_bn(max_revenue, 1),
      Spread = fmt_bn(scenario_spread, 1)
    )

  write_latex_table(
    file.path(GEN_TABLES, "country_spread.tex"),
    caption = "Scenario spread for selected EU Member States",
    short_caption = "Scenario spread for selected EU Member States",
    label = "tab:country_spread_updated",
    col_spec = "lrrr",
    header = c("Country", "Minimum", "Maximum", "Spread"),
    rows = x,
    notes = paste(
      "Amounts are cumulative collector-country revenue over 2017 to 2022, expressed in US dollars, billions.",
      "Country totals combine QDMTT source-country revenue, IIR parent-country revenue and UTPR revenue allocated by the substance key.",
      source_note("data/processed/diagnostics/step7_stage4_6_scenario_spread_country.csv")
    )
  )
}

write_hypothesis_summary_table <- function() {
  h <- read_processed("stage4_6_hypothesis_summary.rds")
  model <- read_diag("step5_stage3_model_comparison.csv") |> arrange(bic_rank)
  semi <- read_diag("step5_stage3_semielasticity_schedule.csv") |>
    filter(model_spec == "logarithmic", inference == "parent_affiliate_clustered",
           tau == 0.05)
  h5 <- read_diag("step4_stage2_sectoral_h5_regression_clustered.csv") |>
    filter(term == "sectoral_capital_intensity")

  h1_model <- str_to_sentence(model$model_spec[1])
  h1_p <- fmt_p(model$tax_terms_joint_p_value_two_way[1])
  h1_log <- fmt_num(semi$semi_elasticity[1], 2)
  h2_share <- fmt_pct(as.numeric(metric_value(h, "largest_main_effect_eta_squared")), 1)
  h3_share <- fmt_pct(as.numeric(metric_value(h, "interaction_eta_squared")), 1)
  h4_delta <- fmt_bn(abs(as.numeric(metric_value(h, "h4_mean_delta_sbs_minus_universal"))), 3)
  h4_p <- fmt_p(as.numeric(metric_value(h, "h4_wilcoxon_less_p_value")))
  h5_unweighted <- h5 |> filter(model_variant == "unweighted")
  h5_weighted <- h5 |> filter(model_variant == "profit_weighted")

  rows <- tibble(
    Hypothesis = latex_escape(c("H1", "H2", "H3", "H4", "H5")),
    `Main result` = c(
      paste0("Tax terms are jointly significant; baseline BIC selects ",
             latex_escape(h1_model), "; logarithmic 5\\% semi-elasticity is ",
             h1_log, "."),
      paste0("ETR measurement explains ", h2_share,
             "\\% of pooled scenario variance."),
      paste0("All interaction terms together explain ", h3_share,
             "\\% of scenario variance."),
      paste0("SbS reduces paired country-year revenue by US\\$",
             h4_delta, " bn on average; Wilcoxon $p$ = ", h4_p, "."),
      paste0("Capital intensity coefficient is negative; clustered $p$ = ",
             fmt_p(h5_unweighted$p_value[1]), " unweighted and ",
             fmt_p(h5_weighted$p_value[1]), " profit-weighted.")
    ),
    Interpretation = latex_escape(c(
      "Partly supported, but nonlinear dominance is too strong for the current baseline.",
      "Supported.",
      "Not supported under the 10 per cent threshold.",
      "Supported.",
      "Supported, subject to the FATS-sector proxy caveat."
    ))
  )

  write_latex_table(
    file.path(GEN_TABLES, "hypothesis_summary.tex"),
    caption = "Hypothesis summary",
    short_caption = "Hypothesis summary",
    label = "tab:hypothesis_result_summary",
    col_spec = "L{1.7cm}L{7.1cm}L{4.8cm}",
    header = c("Hypothesis", "Main result", "Interpretation"),
    rows = rows,
    notes = paste(
      "The table is generated from the Stage 2, Stage 3 and Stage 4.6 diagnostics.",
      source_note(c("data/processed/stage4_6_hypothesis_summary.rds",
                    "data/processed/diagnostics/step5_stage3_model_comparison.csv",
                    "data/processed/diagnostics/step4_stage2_sectoral_h5_regression_clustered.csv"))
    )
  )
}

write_simple_metric_table <- function(file, caption, label, data, metric_col,
                                      value_col, col_spec = "lr",
                                      notes = NULL) {
  rows <- data |>
    transmute(
      Metric = latex_escape(.data[[metric_col]]),
      Value = latex_escape(.data[[value_col]])
    )

  write_latex_table(file, caption, label, col_spec,
                    c("Metric", "Value"), rows, notes = notes)
}

write_appendix_tables <- function() {
  dir.create(GEN, showWarnings = FALSE, recursive = TRUE)

  bspi_summary <- read_diag("step3_stage1_bspi_tv_summary.csv") |>
    mutate(scope = recode(scope, "eu27" = "EU27", "non_eu" = "Non-EU")) |>
    transmute(
      Scope = latex_escape(scope),
      Affiliates = fmt_int(affiliates),
      `High-TV flagged` = fmt_int(high_tv_flagged),
      Median = fmt_num(tv_median, 3),
      P75 = fmt_num(tv_p75, 3),
      P90 = fmt_num(tv_p90, 3),
      Maximum = fmt_num(tv_max, 3)
    )

  write_appendix_latex_table(
    file.path(GEN_TABLES, "appendix_stage1_bspi_summary.tex"),
    "BSPI total-variation summary",
    "tab:app_stage1_bspi_tv",
    "lrrrrrr",
    c("Scope", "Affiliates", "High-TV flagged", "Median", "P75", "P90", "Maximum"),
    bspi_summary,
    source_note("data/processed/diagnostics/step3_stage1_bspi_tv_summary.csv")
  )

  conditioning <- read_diag("step3_stage1_conditioning_by_year.csv") |>
    transmute(
      Year = fmt_year(year),
      `Affiliate-years` = fmt_int(affiliate_years),
      `Non-monotone raw` = fmt_int(raw_non_monotone),
      `Out of support` = fmt_int(raw_out_of_support),
      Conditioned = fmt_int(conditioned),
      `Mean beta fit MAE` = fmt_num(mean_beta_fit_mae, 3),
      `Max beta fit error` = fmt_num(max_beta_fit_max_abs_error, 3)
    )

  write_appendix_latex_table(
    file.path(GEN_TABLES, "appendix_stage1_conditioning.tex"),
    "Stage 1 percentile and Beta-fit diagnostics",
    "tab:app_stage1_conditioning",
    "lrrrrrr",
    c("Year", "Affiliate-years", "Non-monotone raw", "Out of support",
      "Conditioned", "Mean beta fit MAE", "Max beta fit error"),
    conditioning,
    source_note("data/processed/diagnostics/step3_stage1_conditioning_by_year.csv")
  )

  payroll <- read_diag("step4_stage2_payroll_fallback_by_year.csv") |>
    filter(rate_scenario == "initial") |>
    transmute(
      Year = fmt_year(year),
      `Pair-years` = fmt_int(pair_years),
      `Fallback rows` = fmt_int(payroll_zero_fallback_rows),
      `Positive profit in fallback rows (US$ bn)` =
        fmt_bn(positive_profit_in_fallback_rows, 1),
      `Fallback share of Stage 1 top-up (\\%)` =
        fmt_pct(fallback_share_of_stage1_distributional_topup, 1)
    )

  write_appendix_latex_table(
    file.path(GEN_TABLES, "appendix_stage2_payroll_fallback.tex"),
    "Stage 2 payroll fallback diagnostics",
    "tab:app_stage2_payroll_fallback",
    "lrrrr",
    c("Year", "Pair-years", "Fallback rows",
      "Positive profit in fallback rows (US\\$ bn)",
      "Fallback share of Stage 1 top-up (\\%)"),
    payroll,
    source_note("data/processed/diagnostics/step4_stage2_payroll_fallback_by_year.csv")
  )

  asset_sensitivity <- read_diag("step4_stage2_sectoral_asset_sensitivity.csv") |>
    transmute(
      `Rate scenario` = latex_escape(normalise_factor_label(rate_scenario)),
      `Asset sensitivity` = latex_escape(str_replace_all(asset_sensitivity, "_", " ")),
      `Asset scale` = fmt_num(asset_component_scale, 2),
      `Weighted phi (\\%)` = fmt_pct(weighted_phi, 1),
      `Average floor (\\%)` = fmt_pct(weighted_floor_average, 1),
      `Distributional floor (\\%)` = fmt_pct(weighted_floor_distributional, 1)
    )

  write_appendix_latex_table(
    file.path(GEN_TABLES, "appendix_stage2_asset_sensitivity.tex"),
    "Stage 2 sectoral asset sensitivity",
    "tab:app_stage2_asset_sensitivity",
    "llrrrr",
    c("Rate scenario", "Asset sensitivity", "Asset scale",
      "Weighted phi (\\%)", "Average floor (\\%)", "Distributional floor (\\%)"),
    asset_sensitivity,
    source_note("data/processed/diagnostics/step4_stage2_sectoral_asset_sensitivity.csv")
  )

  sample_summary <- read_diag("step5_stage3_estimation_sample_summary.csv") |>
    mutate(sample = str_replace_all(sample, "_", " ")) |>
    transmute(
      Sample = latex_escape(str_to_sentence(sample)),
      Rows = fmt_int(rows),
      Pairs = fmt_int(pairs),
      Affiliates = fmt_int(affiliates),
      Parents = fmt_int(parents),
      `Median pair-years` = fmt_num(median_pair_years, 1),
      `Median ETR (\\%)` = fmt_pct(tau_p50, 1),
      `Stale-wage rows` = fmt_int(stale_wage_rows)
    )

  write_appendix_latex_table(
    file.path(GEN_TABLES, "appendix_stage3_sample_summary.tex"),
    "Stage 3 estimation-sample diagnostics",
    "tab:app_stage3_sample_summary",
    "lrrrrrrr",
    c("Sample", "Rows", "Pairs", "Affiliates", "Parents",
      "Median pair-years", "Median ETR (\\%)", "Stale-wage rows"),
    sample_summary,
    source_note("data/processed/diagnostics/step5_stage3_estimation_sample_summary.csv")
  )

  coefficients <- read_diag("step5_stage3_coefficients.csv") |>
    filter(inference == "parent_affiliate_clustered",
           term %in% c("tau", "tau_sq", "log_tau")) |>
    mutate(
      term = recode(term, "tau" = "ETR", "tau_sq" = "ETR squared",
                    "log_tau" = "Log shifted ETR")
    ) |>
    transmute(
      Model = latex_escape(str_to_sentence(model_spec)),
      Term = latex_escape(term),
      Estimate = fmt_num(estimate, 3),
      SE = fmt_num(std_error, 3),
      `$p$-value` = fmt_p(p_value),
      `Within $R^2$` = fmt_num(within_r_squared, 4)
    )

  write_appendix_latex_table(
    file.path(GEN_TABLES, "appendix_stage3_tax_coefficients.tex"),
    "Stage 3 tax coefficients",
    "tab:app_stage3_tax_coefficients",
    "llrrrr",
    c("Model", "Term", "Estimate", "SE", "$p$-value", "Within $R^2$"),
    coefficients,
    paste(
      "Inference is two-way clustered by parent and affiliate.",
      source_note("data/processed/diagnostics/step5_stage3_coefficients.csv")
    )
  )

  spec_tests <- read_diag("step5_stage3_specification_tests.csv") |>
    transmute(
      Test = latex_escape(str_replace_all(test, "_", " ")),
      `Model A` = latex_escape(str_to_sentence(model_a)),
      `Model B` = latex_escape(str_to_sentence(model_b)),
      Statistic = fmt_num(statistic, 3),
      `$p$-value` = fmt_p(p_value),
      Interpretation = latex_escape(interpretation)
    )

  write_appendix_latex_table(
    file.path(GEN_TABLES, "appendix_stage3_specification_tests.tex"),
    "Stage 3 non-nested specification tests",
    "tab:app_stage3_specification_tests",
    "lllrrL{4.2cm}",
    c("Test", "Model A", "Model B", "Statistic", "$p$-value", "Interpretation"),
    spec_tests,
    source_note("data/processed/diagnostics/step5_stage3_specification_tests.csv")
  )

  wald_tests <- read_diag("step5_stage3_model_wald_tests.csv") |>
    filter(inference == "parent_affiliate_clustered") |>
    transmute(
      Model = latex_escape(normalise_model_label(model_spec)),
      `Tax terms` = latex_escape(terms),
      `df num.` = fmt_int(df_num),
      `df den.` = fmt_int(df_den),
      `$F$-statistic` = fmt_num(f_statistic, 2),
      `$p$-value` = fmt_p(p_value),
      `Within $R^2$` = fmt_num(within_r_squared, 4)
    )

  write_appendix_latex_table(
    file.path(GEN_TABLES, "appendix_stage3_wald_tests.tex"),
    "Stage 3 joint tax-term Wald tests",
    "tab:app_stage3_wald_tests",
    "llrrrrr",
    c("Model", "Tax terms", "df num.", "df den.", "$F$-statistic",
      "$p$-value", "Within $R^2$"),
    wald_tests,
    paste(
      "Inference is two-way clustered by parent and affiliate.",
      source_note("data/processed/diagnostics/step5_stage3_model_wald_tests.csv")
    )
  )

  robustness <- read_diag("step5_stage3_model_robustness.csv") |>
    arrange(sample, bic_rank) |>
    transmute(
      Sample = latex_escape(str_to_sentence(str_replace_all(sample, "_", " "))),
      Model = latex_escape(normalise_model_label(model_spec)),
      `$N$` = fmt_int(n),
      `Within $R^2$` = fmt_num(within_r_squared, 4),
      `BIC rank` = fmt_int(bic_rank),
      `$\\Delta$BIC` = fmt_num(delta_bic, 2),
      `Tax Wald $p$` = fmt_p(tax_terms_joint_p_value_two_way)
    )

  write_appendix_latex_table(
    file.path(GEN_TABLES, "appendix_stage3_robustness.tex"),
    "Stage 3 model-selection robustness",
    "tab:app_stage3_robustness",
    "llrrrrr",
    c("Sample", "Model", "$N$", "Within $R^2$", "BIC rank",
      "$\\Delta$BIC", "Tax Wald $p$"),
    robustness,
    source_note("data/processed/diagnostics/step5_stage3_model_robustness.csv")
  )

  tail_support <- read_diag("step5_stage3_etr_tail_support.csv") |>
    filter(scope == "pooled") |>
    mutate(
      Band = recode(
        tail_band,
        "below_5pct" = "Below 5\\%",
        "five_to_15pct" = "5\\% to 15\\%",
        "at_or_above_15pct" = "15\\% and above"
      )
    ) |>
    transmute(
      Band,
      Rows = fmt_int(rows),
      `Row share (\\%)` = fmt_pct(row_share, 1),
      `Profit share (\\%)` = fmt_pct(profit_share, 1),
      Pairs = fmt_int(pairs),
      Affiliates = fmt_int(affiliates),
      Parents = fmt_int(parents),
      `Median ETR (\\%)` = fmt_pct(median_tau, 1)
    )

  tail_feasibility <- read_diag("step5_stage3_tail_reweighting_feasibility.csv")
  tail_value <- function(metric) {
    as.numeric(tail_feasibility$value[tail_feasibility$metric == metric][1])
  }

  write_appendix_latex_table(
    file.path(GEN_TABLES, "appendix_stage3_etr_tail_support.tex"),
    "Stage 3 lower-tail ETR support",
    "tab:app_stage3_etr_tail_support",
    "lrrrrrrr",
    c("ETR band", "Rows", "Row share (\\%)", "Profit share (\\%)",
      "Pairs", "Affiliates", "Parents", "Median ETR (\\%)"),
    tail_support,
    paste(
      "The table reports the support for the behavioural ETR regressor after winsorisation in the baseline fixed-effect estimation sample.",
      "An illustrative tail-balanced design that forces the below-5\\% band to 50\\% of weighted rows would use a tail multiplier of",
      fmt_num(tail_value("tail_balance_tail_weight"), 2),
      "and a non-tail multiplier of",
      fmt_num(tail_value("tail_balance_non_tail_weight"), 2),
      "with effective N equal to",
      fmt_int(tail_value("tail_balance_effective_n")),
      paste0("and a design effect of ",
             fmt_num(tail_value("tail_balance_design_effect"), 2), "."),
      "This is a support diagnostic, not an inverse-probability-weighted estimator.",
      source_note(c("data/processed/diagnostics/step5_stage3_etr_tail_support.csv",
                    "data/processed/diagnostics/step5_stage3_tail_reweighting_feasibility.csv"))
    )
  )

  behaviour <- read_diag("step5_stage3_behaviour_by_year.csv") |>
    filter(model_spec == "linear", etr_measurement == "distributional") |>
    transmute(
      Year = fmt_year(year),
      `Affiliate-years` = fmt_int(affiliate_years),
      `EU27 affiliate-years` = fmt_int(eu27_affiliate_years),
      `Mean beta (\\%)` = fmt_pct(mean_beta_applied, 1),
      `Profit-weighted beta (\\%)` = fmt_pct(profit_weighted_beta_applied, 1),
      `Bunching affiliate-years` = fmt_int(bunching_affiliate_years),
      `Reallocation affiliate-years` = fmt_int(reallocation_affiliate_years)
    )

  write_appendix_latex_table(
    file.path(GEN_TABLES, "appendix_stage3_behaviour_by_year.tex"),
    "Stage 3 applied behavioural response by year",
    "tab:app_stage3_behaviour_by_year",
    "lrrrrrr",
    c("Year", "Affiliate-years", "EU27 affiliate-years", "Mean beta (\\%)",
      "Profit-weighted beta (\\%)", "Bunching affiliate-years",
      "Reallocation affiliate-years"),
    behaviour,
    source_note("data/processed/diagnostics/step5_stage3_behaviour_by_year.csv")
  )

  behavioural_design <- read_diag("step5_stage3_behavioural_identification_design.csv") |>
    transmute(
      Component = latex_escape(str_to_sentence(str_replace_all(component, "_", " "))),
      `Baseline treatment` = latex_escape(baseline_treatment),
      `Identification status` = latex_escape(identification_status),
      `Data for structural extension` =
        latex_escape(data_needed_for_structural_extension)
    )

  write_appendix_latex_table(
    file.path(GEN_TABLES, "appendix_stage3_behavioural_design.tex"),
    "Stage 3 behavioural identification design",
    "tab:app_stage3_behavioural_design",
    "L{2.7cm}L{4.1cm}L{3.7cm}L{5.1cm}",
    c("Component", "Baseline treatment", "Identification status",
      "Data for structural extension"),
    behavioural_design,
    source_note("data/processed/diagnostics/step5_stage3_behavioural_identification_design.csv")
  )

  stage45_summary <- read_diag("step6_stage4_5_summary.csv") |>
    mutate(
      value_fmt = case_when(
        str_detect(metric, "revenue|delta|scenario") & !str_detect(metric, "rows|factorial") ~
          fmt_bn(as.numeric(value), 3),
        TRUE ~ fmt_num(as.numeric(value), 3)
      ),
      metric = str_replace_all(metric, "_", " ")
    ) |>
    transmute(Metric = latex_escape(str_to_sentence(metric)),
              Value = value_fmt)

  write_appendix_latex_table(
    file.path(GEN_TABLES, "appendix_stage45_summary.tex"),
    "Stage 4.5 allocation summary",
    "tab:app_stage45_summary",
    "lr",
    c("Metric", "Value"),
    stage45_summary,
    source_note("data/processed/diagnostics/step6_stage4_5_summary.csv")
  )

  source_exposure <- read_diag("step6_stage4_5_sbs_source_exposure.csv") |>
    filter(factor1_etr == "distributional",
           factor2_substance == "aggregate_sbie",
           factor3_rates == "initial",
           factor5_behaviour == "mechanical",
           factor4_sbs == "sbs",
           source_country %in% SELECTED_COUNTRIES) |>
    group_by(source_country_name, source_qdmtt) |>
    summarise(
      total_topup = sum(total_topup_after_behaviour, na.rm = TRUE),
      us_topup = sum(us_parented_topup, na.rm = TRUE),
      extinguished = sum(us_parented_extinguished_topup, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(match(source_country_name,
                  c("Netherlands", "Ireland", "Luxembourg", "Germany", "France"))) |>
    transmute(
      `Source country` = latex_escape(source_country_name),
      QDMTT = fmt_bool(source_qdmtt),
      `Total top-up (US$ bn)` = fmt_bn(total_topup, 1),
      `US-parented top-up (US$ bn)` = fmt_bn(us_topup, 1),
      `Extinguished (US$ bn)` = fmt_bn(extinguished, 1)
    )

  write_appendix_latex_table(
    file.path(GEN_TABLES, "appendix_stage45_sbs_source_exposure.tex"),
    "Selected source-country SbS exposure",
    "tab:app_stage45_sbs_source_exposure",
    "lrrrr",
    c("Source country", "QDMTT", "Total top-up (US\\$ bn)",
      "US-parented top-up (US\\$ bn)", "Extinguished (US\\$ bn)"),
    source_exposure,
    paste(
      "Preferred-core source exposure before final collector-country allocation.",
      source_note("data/processed/diagnostics/step6_stage4_5_sbs_source_exposure.csv")
    )
  )

  h4_reg <- read_diag("step6_stage4_5_h4_regression.csv") |>
    mutate(term = str_replace_all(term, "_", " ")) |>
    transmute(
      Term = latex_escape(term),
      Estimate = fmt_num(estimate, 4),
      SE = fmt_num(std_error, 4),
      Statistic = fmt_num(statistic, 2),
      `$p$-value` = fmt_p(p_value),
      `$R^2$` = fmt_num(r_squared, 3)
    )

  write_appendix_latex_table(
    file.path(GEN_TABLES, "appendix_stage45_h4_regression.tex"),
    "H4 country-level heterogeneity regression",
    "tab:app_stage45_h4_regression",
    "lrrrrr",
    c("Term", "Estimate", "SE", "Statistic", "$p$-value", "$R^2$"),
    h4_reg,
    source_note("data/processed/diagnostics/step6_stage4_5_h4_regression.csv")
  )

  scenario_summary <- read_diag("step7_stage4_6_scenario_summary.csv") |>
    arrange(desc(eu_revenue)) |>
    slice_head(n = 8) |>
    transmute(
      Scenario = latex_escape(scenario_id),
      ETR = latex_escape(normalise_factor_label(factor1_etr)),
      Substance = latex_escape(normalise_factor_label(factor2_substance)),
      Rates = latex_escape(normalise_factor_label(factor3_rates)),
      Regime = latex_escape(normalise_factor_label(factor4_sbs)),
      Behaviour = latex_escape(normalise_factor_label(factor5_behaviour)),
      `EU revenue (US$ bn)` = fmt_num(eu_revenue_bn, 1)
    )

  write_appendix_latex_table(
    file.path(GEN_TABLES, "appendix_stage46_top_scenarios.tex"),
    "Highest EU revenue scenarios",
    "tab:app_stage46_top_scenarios",
    "llllllr",
    c("Scenario", "ETR", "Substance", "Rates", "Regime", "Behaviour",
      "EU revenue (US\\$ bn)"),
    scenario_summary,
    source_note("data/processed/diagnostics/step7_stage4_6_scenario_summary.csv")
  )

  anova_country <- read_diag("step7_stage4_6_anova_by_country.csv") |>
    filter(country %in% SELECTED_COUNTRIES, interaction_order == 1) |>
    group_by(country_name) |>
    arrange(desc(eta_squared), .by_group = TRUE) |>
    slice_head(n = 3) |>
    ungroup() |>
    transmute(
      Country = latex_escape(country_name),
      Effect = latex_escape(effect_label),
      `Share (\\%)` = fmt_pct(eta_squared, 1)
    )

  write_appendix_latex_table(
    file.path(GEN_TABLES, "appendix_stage46_country_anova.tex"),
    "Largest country-level main effects",
    "tab:app_stage46_country_anova",
    "llr",
    c("Country", "Effect", "Share (\\%)"),
    anova_country,
    source_note("data/processed/diagnostics/step7_stage4_6_anova_by_country.csv")
  )

  influence_appendix_inputs <- character()
  influence_summary_path <- file.path(
    DIAG,
    "step10_jurisdiction_influence_case_summary.csv"
  )
  if (file.exists(influence_summary_path)) {
    influence <- read_diag("step10_jurisdiction_influence_case_summary.csv") |>
      arrange(desc(abs(preferred_sbs_behavioural_revenue_pct_change))) |>
      slice_head(n = 14) |>
      transmute(
        Drop = latex_escape(str_to_sentence(leave_dimension)),
        Jurisdiction = latex_escape(
          paste0(jurisdiction_name, " (", jurisdiction, ")")
        ),
        Reason = latex_escape(
          target_reason |>
            str_replace_all("_", " ") |>
            str_replace_all("\\+", ", ")
        ),
        `Profit share (\\%)` = fmt_pct(dropped_stage1_profit_share, 1),
        `Semi-elasticity` = fmt_num(leave_semielasticity_5, 2),
        `Stage 1 change (pp)` =
          fmt_num(100 * stage1_liability_rate_abs_change, 2),
        `Preferred revenue change (\\%)` =
          fmt_pct(preferred_sbs_behavioural_revenue_pct_change, 1),
        `Largest effect` = latex_escape(
          recode(
            leave_largest_anova_effect,
            "x1_etr" = "ETR measurement",
            "x2_substance" = "Substance specification",
            "x3_rates" = "SBIE rate endpoint",
            "x4_sbs" = "SbS regime",
            "x5_behaviour" = "Behavioural response",
            .default = leave_largest_anova_effect
          )
        )
      )

    write_appendix_latex_table(
      file.path(GEN_TABLES, "appendix_jurisdiction_influence_summary.tex"),
      "Leave-one-jurisdiction influence robustness",
      "tab:app_jurisdiction_influence_summary",
      "lllrrrrl",
      c("Drop", "Jurisdiction", "Reason", "Profit share (\\%)",
        "Semi-elasticity", "Stage 1 change (pp)",
        "Preferred revenue change (\\%)", "Largest effect"),
      influence,
      paste(
        "Rows are sorted by the absolute change in preferred-core behavioural SbS EU revenue.",
        "The preferred core uses distributional ETR measurement, aggregate SBIE and initial carve-out rates.",
        source_note("data/processed/diagnostics/step10_jurisdiction_influence_case_summary.csv")
      )
    )

    influence_anova <- read_diag("step10_jurisdiction_influence_anova_pooled.csv")
    influence_main <- read_diag("step10_jurisdiction_influence_main_effects.csv")
    core_effects <- c("x1_etr", "x4_sbs", "x5_behaviour")

    anova_range <- influence_anova |>
      filter(effect %in% core_effects) |>
      group_by(effect, effect_label) |>
      summarise(
        baseline_eta = eta_squared[case_id == "baseline"][1],
        min_eta = min(eta_squared[case_id != "baseline"], na.rm = TRUE),
        max_eta = max(eta_squared[case_id != "baseline"], na.rm = TRUE),
        .groups = "drop"
      )

    main_range <- influence_main |>
      filter(effect %in% core_effects) |>
      group_by(effect) |>
      summarise(
        baseline_main = high_minus_low[case_id == "baseline"][1],
        min_main = min(high_minus_low[case_id != "baseline"], na.rm = TRUE),
        max_main = max(high_minus_low[case_id != "baseline"], na.rm = TRUE),
        .groups = "drop"
      )

    influence_range <- anova_range |>
      left_join(main_range, by = "effect") |>
      arrange(match(effect, core_effects)) |>
      transmute(
        Effect = latex_escape(effect_label),
        `Baseline share (\\%)` = fmt_pct(baseline_eta, 1),
        `Min share (\\%)` = fmt_pct(min_eta, 1),
        `Max share (\\%)` = fmt_pct(max_eta, 1),
        `Baseline main effect` = fmt_bn(baseline_main, 1),
        `Min main effect` = fmt_bn(min_main, 1),
        `Max main effect` = fmt_bn(max_main, 1)
      )

    write_appendix_latex_table(
      file.path(GEN_TABLES, "appendix_jurisdiction_influence_decomposition.tex"),
      "Influence range for core decomposition effects",
      "tab:app_jurisdiction_influence_decomposition",
      "lrrrrrr",
      c("Effect", "Baseline share (\\%)", "Min share (\\%)",
        "Max share (\\%)", "Baseline main effect", "Min main effect",
        "Max main effect"),
      influence_range,
      paste(
        "Variance-decomposition shares and main effects are recomputed after each leave-one-parent and leave-one-affiliate omission.",
        "Main effects are cumulative over 2017 to 2022 and expressed in US dollars, billions.",
        source_note(c(
          "data/processed/diagnostics/step10_jurisdiction_influence_anova_pooled.csv",
          "data/processed/diagnostics/step10_jurisdiction_influence_main_effects.csv"
        ))
      )
    )

    influence_appendix_inputs <- c(
      "\\input{generated/results_tables/appendix_jurisdiction_influence_summary.tex}",
      "\\input{generated/results_tables/appendix_jurisdiction_influence_decomposition.tex}"
    )
  }

  appendix_lines <- c(
    "\\subsection{Stage 1 diagnostics}\\label{app:results_stage1}",
    "\\input{generated/results_tables/appendix_stage1_bspi_summary.tex}",
    "\\input{generated/results_tables/appendix_stage1_conditioning.tex}",
    "\\input{generated/results_tables/stage1_crossval.tex}",
    "",
    "\\subsection{Stage 2 diagnostics}\\label{app:results_stage2}",
    "\\input{generated/results_tables/appendix_stage2_payroll_fallback.tex}",
    "\\input{generated/results_tables/appendix_stage2_asset_sensitivity.tex}",
    "",
    "\\subsection{Stage 3 diagnostics}\\label{app:results_stage3}",
    "\\input{generated/results_tables/appendix_stage3_sample_summary.tex}",
    "\\input{generated/results_tables/appendix_stage3_tax_coefficients.tex}",
    "\\input{generated/results_tables/appendix_stage3_specification_tests.tex}",
    "\\input{generated/results_tables/appendix_stage3_wald_tests.tex}",
    "\\input{generated/results_tables/appendix_stage3_robustness.tex}",
    "\\input{generated/results_tables/appendix_stage3_etr_tail_support.tex}",
    "\\input{generated/results_tables/appendix_stage3_behaviour_by_year.tex}",
    "\\input{generated/results_tables/appendix_stage3_behavioural_design.tex}",
    "",
    "\\subsection{Stage 4.5 allocation diagnostics}\\label{app:results_stage45}",
    "\\input{generated/results_tables/appendix_stage45_summary.tex}",
    "\\input{generated/results_tables/appendix_stage45_sbs_source_exposure.tex}",
    "\\input{generated/results_tables/appendix_stage45_h4_regression.tex}",
    "",
    "\\subsection{Stage 4.6 decomposition diagnostics}\\label{app:results_stage46}",
    "\\input{generated/results_tables/appendix_stage46_top_scenarios.tex}",
    "\\input{generated/results_tables/appendix_stage46_country_anova.tex}",
    influence_appendix_inputs
  )

  writeLines(c("% Generated by code/08_generate_results_tables.R",
               appendix_lines),
             file.path(GEN, "results_appendix_tables.tex"))
}

write_manifest <- function() {
  lines <- c(
    "% Generated by code/08_generate_results_tables.R",
    "\\input{generated/results_tables/profit_correction_effects.tex}",
    "\\input{generated/results_tables/stage1_source_coverage.tex}",
    "\\input{generated/results_tables/stage1_rates.tex}",
    "\\input{generated/results_tables/stage1_bspi_validation.tex}",
    "\\input{generated/results_tables/stage2_aggregate.tex}",
    "\\input{generated/results_tables/stage2_sectoral_sbti.tex}",
    "\\input{generated/results_tables/stage2_h5_regression.tex}",
    "\\input{generated/results_tables/stage3_model_comparison.tex}",
    "\\input{generated/results_tables/stage3_regression_table.tex}",
    "\\input{generated/results_tables/stage3_iv_diagnostics.tex}",
    "\\input{generated/results_tables/stage3_econometric_scorecard.tex}",
    "\\input{generated/results_tables/stage3_semielasticity.tex}",
    "\\input{generated/results_tables/stage4_6_anova.tex}",
    "\\input{generated/results_tables/stage4_6_shapley_factor_attribution.tex}",
    "\\input{generated/results_tables/stage4_6_main_effects.tex}",
    "\\input{generated/results_tables/preferred_channel.tex}",
    if (file.exists(file.path(GEN_TABLES,
                              "stage1_measurement_error_interval.tex"))) {
      "\\input{generated/results_tables/stage1_measurement_error_interval.tex}"
    },
    "\\input{generated/results_tables/country_spread.tex}",
    "\\input{generated/results_tables/hypothesis_summary.tex}"
  )
  lines <- lines[!is.na(lines)]
  writeLines(lines, file.path(GEN, "results_main_tables_manifest.tex"))
}

write_results_tables <- function() {
  dir.create(GEN_TABLES, showWarnings = FALSE, recursive = TRUE)

  write_data_descriptive_tables()

  write_profit_correction_table()
  write_stage1_source_table()
  write_stage1_rates_table()
  write_stage1_bspi_table()
  write_stage1_crossval_table()

  write_stage2_aggregate_table()
  write_stage2_sectoral_table()
  write_stage2_h5_table()

  write_stage3_model_table()
  write_stage3_regression_table()
  write_stage3_iv_table()
  write_stage3_econometric_scorecard_table()
  write_stage3_semielasticity_table()

  write_stage46_anova_table()
  write_stage46_shapley_table()
  write_stage46_main_effects_table()
  write_stage46_channel_table()
  write_stage1_measurement_error_table()
  write_stage46_country_spread_table()
  write_hypothesis_summary_table()

  write_appendix_tables()
  write_manifest()

  message("\nStep 8 outputs written:")
  message(" - writing/generated/data_descriptive_tables.tex")
  message(" - writing/generated/results_tables/*.tex")
  message(" - writing/generated/results_appendix_tables.tex")
  message(" - writing/generated/results_main_tables_manifest.tex")
}

if (is_direct_script_run("code/08_generate_results_tables.R")) {
  write_results_tables()
}
