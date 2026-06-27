# 08_generate_results_tables.R
# Step 8 of the methodology pipeline.
#
# Converts the processed outputs from Steps 1 to 7 into LaTeX tables that can be
# included directly in the thesis manuscript. This keeps the Results section tied
# to the current data pipeline instead of hardcoding numerical tables in the
# manuscript.
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(tibble)

source("code/00_helpers.R")


read_diag <- function(file) {
  path <- file.path(DIAGNOSTICS_DIR, file)
  if (!file.exists(path)) stop("Missing diagnostics file: ", path)
  read_csv(path, show_col_types = FALSE)
}

read_processed <- function(file) {
  path <- file.path(PROCESSED_DIR, file)
  if (!file.exists(path)) stop("Missing processed file: ", path)
  readRDS(path)
}

fmt_int <- function(x) {
  ifelse(is.na(x), "", format(round(x), big.mark = ",", scientific = FALSE))
}

fmt_year <- function(x) {
  ifelse(is.na(x), "", as.character(as.integer(round(x))))
}

fmt_num <- function(x, digits = 2) {
  ifelse(is.na(x), "", format(round(x, digits),
    nsmall = digits,
    big.mark = ",", scientific = FALSE
  ))
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
    mantissa <- x[tiny] / (10^exponent)
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
    paste0(
      fmt_num(estimate, digits), significance_stars(p_value),
      " (", fmt_num(std_error, digits), ")"
    )
  )
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

normalise_typology_feature_label <- function(x) {
  recode(
    x,
    "preferred_revenue" = "Preferred revenue",
    "scenario_spread" = "Scenario spread",
    "revenue_to_cit_1200" = "Revenue/CIT",
    "revenue_to_gdp" = "Revenue/GDP",
    "revenue_per_capita" = "Revenue per resident",
    "etr_measurement_main_effect" = "ETR measurement effect",
    "sbs_regime_main_effect" = "SbS effect",
    "substance_specification_main_effect" = "Substance effect",
    "behavioural_response_main_effect" = "Behavioural effect",
    "qdmtt_share" = "QDMTT share",
    "residual_iir_utpr_exposure" = "Residual IIR/UTPR",
    "sbs_extinguished_share" = "SbS extinguished share",
    "high_risk_imputation_share" = "High-risk imputation",
    "direct_t4_lowtax_share" = "Direct Table IV share",
    .default = str_to_sentence(str_replace_all(x, "_", " "))
  )
}

format_typology_feature_list <- function(x) {
  vapply(str_split(x, ";\\s*"), function(features) {
    paste(normalise_typology_feature_label(features), collapse = "; ")
  }, character(1))
}

longtable_heads <- function(n_cols, header_lines, label = NULL) {
  header_lines <- as.character(header_lines)
  cont_label <- if (!is.null(label) && nzchar(label)) {
    sprintf(
      "\\multicolumn{%d}{c}{\\textit{Table~\\ref{%s}---continued}} \\\\",
      n_cols, label
    )
  } else {
    sprintf(
      "\\multicolumn{%d}{c}{\\textit{continued from previous page}} \\\\",
      n_cols
    )
  }

  c(
    "\\toprule",
    header_lines,
    "\\midrule",
    "\\endfirsthead",
    cont_label,
    "\\toprule",
    header_lines,
    "\\midrule",
    "\\endhead",
    "\\midrule",
    sprintf(
      "\\multicolumn{%d}{r}{\\textit{Continued on next page}}\\\\",
      n_cols
    ),
    "\\endfoot",
    "\\bottomrule"
  )
}

longtable_lastfoot <- function(n_cols, notes = NULL) {
  "\\endlastfoot"
}

assemble_inline_table <- function(
  col_spec,
  caption_lines,
  header_lines,
  body_lines,
  notes = NULL,
  size = "\\small",
  tabcolsep = "4pt",
  table_position = "H",
  fit_width = FALSE
) {
  caption_lines <- as.character(caption_lines)
  header_lines <- as.character(header_lines)
  body_lines <- as.character(body_lines)

  tabular_block <- c(
    sprintf("\\begin{tabular}{@{}%s@{}}", col_spec),
    "\\toprule",
    header_lines,
    "\\midrule",
    body_lines,
    "\\bottomrule",
    "\\end{tabular}"
  )

  if (isTRUE(fit_width)) {
    tabular_block <- c(
      "\\begin{adjustbox}{max width=\\textwidth,center}",
      tabular_block,
      "\\end{adjustbox}"
    )
  }

  block <- c(
    sprintf("\\begin{table}[%s]", table_position),
    "\\centering",
    size,
    sprintf("\\setlength{\\tabcolsep}{%s}", tabcolsep),
    caption_lines,
    tabular_block
  )

  if (!is.null(notes) && nzchar(trimws(notes))) {
    block <- c(
      block,
      "",
      "\\vspace{0.35em}",
      "\\noindent\\begin{minipage}{\\textwidth}",
      sprintf("\\footnotesize\\raggedright\\textit{Notes:} %s", trimws(notes)),
      "\\end{minipage}"
    )
  }

  c(block, "\\end{table}")
}

assemble_splittable_table <- function(
  col_spec,
  caption_lines,
  n_cols,
  header_lines,
  body_lines,
  label = NULL,
  notes = NULL,
  size = "\\small",
  tabcolsep = "4pt"
) {
  caption_lines <- as.character(caption_lines)
  header_lines <- as.character(header_lines)
  body_lines <- as.character(body_lines)

  table_inner <- c(
    splittable_begin(col_spec),
    c(caption_lines, "\\\\"),
    longtable_heads(n_cols, header_lines, label = label),
    longtable_lastfoot(n_cols),
    body_lines,
    splittable_end(col_spec)
  )

  block <- c(
    size,
    sprintf("\\setlength{\\tabcolsep}{%s}", tabcolsep),
    table_inner,
    "\\normalsize"
  )

  if (!is.null(notes) && nzchar(trimws(notes))) {
    block <- c(
      block,
      "",
      "\\vspace{0.35em}",
      "\\noindent\\begin{minipage}{\\textwidth}",
      sprintf("\\footnotesize\\raggedright\\textit{Notes:} %s", trimws(notes)),
      "\\end{minipage}"
    )
  }

  block
}

normalize_col_spec <- function(col_spec, x_width = "8.5cm") {
  x_col <- paste0(">{\\raggedright\\arraybackslash}p{", x_width, "}")
  col_spec <- gsub(">{\\raggedright\\arraybackslash}X", x_col, col_spec, fixed = TRUE)
  gsub("X", x_col, col_spec, fixed = TRUE)
}

splittable_begin <- function(col_spec, width = "\\textwidth") {
  sprintf("\\begin{longtable}{@{}%s@{}}", normalize_col_spec(col_spec))
}

splittable_end <- function(col_spec) {
  "\\end{longtable}"
}

write_latex_table <- function(file, caption, label, col_spec, header, rows,
                              notes = NULL, short_caption = NULL,
                              size = "\\small", tabcolsep = NULL,
                              fit_width = FALSE) {
  dir.create(dirname(file), showWarnings = FALSE, recursive = TRUE)

  caption_line <- if (is.null(short_caption)) {
    sprintf("\\caption{%s}", caption)
  } else {
    sprintf("\\caption[%s]{%s}", short_caption, caption)
  }

  row_lines <- apply(as.matrix(rows), 1, function(r) {
    paste0(paste(r, collapse = " & "), " \\\\")
  })

  n_cols <- length(header)
  header_line <- paste0(paste(header, collapse = " & "), " \\\\")
  if (is.null(tabcolsep)) {
    tabcolsep <- if (identical(size, "\\footnotesize") || identical(size, "\\scriptsize")) {
      "3pt"
    } else {
      "4pt"
    }
  }

  lines <- c(
    "% Generated by code/08_generate_results_tables.R",
    assemble_inline_table(
      col_spec = col_spec,
      caption_lines = c(caption_line, sprintf("\\label{%s}", label)),
      header_lines = header_line,
      body_lines = row_lines,
      notes = notes,
      size = size,
      tabcolsep = tabcolsep,
      fit_width = fit_width
    )
  )

  writeLines(lines, file)
}

write_custom_table <- function(file, lines) {
  dir.create(dirname(file), showWarnings = FALSE, recursive = TRUE)
  writeLines(c("% Generated by code/08_generate_results_tables.R", lines), file)
}

write_appendix_latex_table <- function(file, caption, label, col_spec, header,
                                       rows, notes = NULL,
                                       short_caption = NULL, ...) {
  write_latex_table(
    file = file,
    caption = caption,
    label = label,
    col_spec = col_spec,
    header = header,
    rows = rows,
    notes = notes,
    short_caption = short_caption,
    size = "\\footnotesize",
    ...
  )
}

metric_value <- function(df, metric) {
  value <- df$value[df$metric == metric]
  if (length(value) == 0) {
    return(NA_character_)
  }
  value[1]
}

finite_values <- function(x) {
  x[is.finite(x)]
}

safe_median <- function(x) {
  x <- finite_values(x)
  if (length(x) == 0) {
    return(NA_real_)
  }
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
      P10 = "",
      P25 = "",
      Median = "",
      P75 = "",
      P90 = ""
    ))
  }

  tibble(
    Variable = latex_escape(label),
    `$N$` = fmt_int(length(x)),
    Mean = fmt_num(mean(x), digits),
    SD = fmt_num(ifelse(length(x) > 1, stats::sd(x), NA_real_), digits),
    P10 = fmt_num(stats::quantile(x, 0.10, names = FALSE), digits),
    P25 = fmt_num(stats::quantile(x, 0.25, names = FALSE), digits),
    Median = fmt_num(stats::median(x), digits),
    P75 = fmt_num(stats::quantile(x, 0.75, names = FALSE), digits),
    P90 = fmt_num(stats::quantile(x, 0.90, names = FALSE), digits)
  )
}

write_data_descriptive_tables <- function() {
  base_panel <- read_processed("base_panel.rds")
  panel <- read_processed("stage1_bilateral_panel.rds") |>
    filter(year %in% MAIN_YEARS)
  estimation <- read_processed("stage3_estimation_sample.rds")

  positive_panel <- panel |>
    filter(analysis_profit_positive > 0)

  raw_t1_path <- file.path(
    "data", "raw", "oecd_cbcr",
    "cbcr_table1_aggregate_totals.csv"
  )
  raw_t1 <- read_csv(
    raw_t1_path,
    col_select = c(REF_AREA, COUNTERPART_AREA, TIME_PERIOD),
    show_col_types = FALSE
  )

  count_cells <- function(df) {
    tibble(
      cells = nrow(df),
      parents = n_distinct(df$parent),
      affiliates = n_distinct(df$affiliate)
    )
  }

  base_counts <- count_cells(base_panel)
  panel_counts <- count_cells(panel)
  positive_counts <- count_cells(positive_panel)
  eu27_counts <- count_cells(filter(panel, affiliate_is_eu27))
  estimation_counts <- count_cells(estimation)

  sample_rows <- tibble(
    Sample = c(
      "Raw OECD Table I records",
      "Country parent-affiliate-year cells",
      "2017--2022 analytical panel",
      "EU27 affiliate slice",
      "Positive-profit tax sample",
      "Behavioural estimation sample"
    ),
    `Rows/cells` = c(
      fmt_int(nrow(raw_t1)),
      fmt_int(base_counts$cells),
      fmt_int(panel_counts$cells),
      fmt_int(eu27_counts$cells),
      fmt_int(positive_counts$cells),
      fmt_int(estimation_counts$cells)
    ),
    Parents = c(
      fmt_int(n_distinct(raw_t1$REF_AREA)),
      fmt_int(base_counts$parents),
      fmt_int(panel_counts$parents),
      fmt_int(eu27_counts$parents),
      fmt_int(positive_counts$parents),
      fmt_int(estimation_counts$parents)
    ),
    Affiliates = c(
      fmt_int(n_distinct(raw_t1$COUNTERPART_AREA)),
      fmt_int(base_counts$affiliates),
      fmt_int(panel_counts$affiliates),
      fmt_int(eu27_counts$affiliates),
      fmt_int(positive_counts$affiliates),
      fmt_int(estimation_counts$affiliates)
    ),
    `Share of panel` = c(
      "",
      "",
      "100.0",
      fmt_pct(eu27_counts$cells / panel_counts$cells, 1),
      fmt_pct(positive_counts$cells / panel_counts$cells, 1),
      fmt_pct(estimation_counts$cells / panel_counts$cells, 1)
    ),
    `Main use` = c(
      "Raw source",
      "Reshaped bilateral panel",
      "Simulation frame",
      "EU source-country results",
      "ETRs and top-up gaps",
      "Hines--Rice semi-elasticity"
    )
  )

  sample_line <- function(r) {
    paste0(
      latex_escape(r[["Sample"]]), " & ",
      r[["Rows/cells"]], " & ",
      r[["Parents"]], " & ",
      r[["Affiliates"]], " & ",
      r[["Share of panel"]], " & ",
      latex_escape(r[["Main use"]]), " \\\\"
    )
  }

  sample_lines <- c(
    "\\multicolumn{6}{@{}l}{\\textit{Panel A: source construction}} \\\\",
    apply(as.matrix(sample_rows[1:3, ]), 1, sample_line),
    "\\addlinespace[0.2em]",
    "\\multicolumn{6}{@{}l}{\\textit{Panel B: analysis samples}} \\\\",
    apply(as.matrix(sample_rows[4:6, ]), 1, sample_line)
  )

  write_custom_table(
    file.path(GENERATED_TABLES_DIR, "data_sample_construction.tex"),
    assemble_inline_table(
      col_spec = "L{3.6cm}rrrr>{\\raggedright\\arraybackslash}p{5.8cm}",
      caption_lines = c(
        "\\caption[Sample construction]{Sample construction and empirical objects}",
        "\\label{tab:data_sample_construction}"
      ),
      header_lines = "Sample & Obs. & Parents & Affiliates & Share (\\%) & Main use \\\\",
      body_lines = sample_lines,
      notes = "Share is relative to the 2017--2022 analytical panel.",
      size = "\\footnotesize",
      tabcolsep = "3pt"
    )
  )

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
    file.path(GENERATED_TABLES_DIR, "data_panel_coverage.tex"),
    caption = "Analytical panel coverage by fiscal year",
    short_caption = "Analytical panel coverage by fiscal year",
    col_spec = "lrrrrrrrr",
    header = c(
      "Year", "Pair-years", "Parents", "Affiliates",
      "Positive pairs", "EU27 pairs", "Profit (US\\$ bn)",
      "Low-taxed profit (US\\$ bn)", "Median ETR"
    ),
    rows = bind_rows(coverage_by_year, coverage_total),
    notes = "2017--2022 Stage 1 panel; profit in USD bn; median ETR among positive-profit cells.",
    size = "\\footnotesize"  )

  summary_blocks <- list(
    "Panel A: Scale variables" = bind_rows(
      describe_vector(
        "Corrected profit (US$ m)",
        positive_panel$analysis_profit_positive / 1e6, 1
      ),
      describe_vector(
        "Tax accrued (US$ m)",
        positive_panel$tax_accrued_panelai / 1e6, 1
      )
    ),
    "Panel B: Tax and low-taxed-profit variables" = bind_rows(
      describe_vector(
        "Bounded ETR (%)",
        100 * positive_panel$etr_panelai_stage1, 1
      ),
      describe_vector(
        "Affiliate statutory CIT rate (%)",
        positive_panel$affiliate_cit_rate, 1
      ),
      describe_vector(
        "Average-rule low-taxed share (%)",
        100 * positive_panel$average_low_share, 1
      ),
      describe_vector(
        "Distributional low-taxed share (%)",
        100 * positive_panel$stage1_distributional_low_share, 1
      ),
      describe_vector(
        "Distributional top-up gap (%)",
        100 * positive_panel$stage1_distributional_topup_rate, 1
      )
    ),
    "Panel C: Substance variables" = bind_rows(
      describe_vector(
        "Tangible assets (US$ m)",
        positive_panel$assets_sbie / 1e6, 1
      ),
      describe_vector(
        "Employees (000s)",
        positive_panel$employees_sbie / 1e3, 2
      ),
      describe_vector(
        "Payroll proxy (US$ m)",
        positive_panel$payroll_sbie / 1e6, 1
      )
    ),
    "Panel D: Controls and activity composition" = bind_rows(
      describe_vector(
        "Holding entity share (%)",
        100 * positive_panel$holding_share_panelai, 1
      ),
      describe_vector(
        "Affiliate GDP per capita (US$ 000s)",
        positive_panel$affiliate_gdp_pc_usd / 1000, 1
      ),
      describe_vector(
        "Affiliate population (millions)",
        positive_panel$affiliate_population / 1e6, 1
      )
    ),
    "Panel E: Measurement support" = bind_rows(
      describe_vector(
        "Direct Table IV support (%)",
        100 * as.numeric(positive_panel$stage1_distributional_source == "direct_t4"), 1
      ),
      describe_vector(
        "Table I percentile-fit support (%)",
        100 * as.numeric(positive_panel$stage1_distributional_source == "percentile_fit"), 1
      ),
      describe_vector(
        "BSPI shape-transport support (%)",
        100 * as.numeric(positive_panel$stage1_distributional_source == "shape_transport"), 1
      ),
      describe_vector(
        "Jurisdiction-average fallback support (%)",
        100 * as.numeric(positive_panel$stage1_distributional_source == "avg_only"), 1
      )
    )
  )

  summary_row_lines <- unlist(Map(function(title, rows) {
    c(
      "\\addlinespace",
      sprintf("\\multicolumn{9}{l}{\\textit{%s}} \\\\", title),
      apply(as.matrix(rows), 1, function(r) {
        paste0(paste(r, collapse = " & "), " \\\\")
      })
    )
  }, names(summary_blocks), summary_blocks), use.names = FALSE)

  write_custom_table(
    file.path(GENERATED_TABLES_DIR, "data_summary_statistics.tex"),
    assemble_splittable_table(
      col_spec = "lrrrrrrrr",
      caption_lines = c(
        "\\caption[Summary statistics for analytical pair-years]{Summary statistics for positive-profit analytical pair-years}",
        "\\label{tab:data_summary_statistics}"
      ),
      n_cols = 9L,
      header_lines = "Variable & $N$ & Mean & SD & P10 & P25 & Median & P75 & P90 \\\\",
      body_lines = summary_row_lines,
      notes = "Positive-profit analytical pair-years; monetary variables in current USD.",
      size = "\\footnotesize",
      tabcolsep = "3pt"
    )
  )

  writeLines(
    c(
      "% Generated by code/08_generate_results_tables.R",
      "\\input{generated/results_tables/data_sample_construction.tex}",
      "\\input{generated/results_tables/data_panel_coverage.tex}",
      "\\input{generated/results_tables/data_summary_statistics.tex}"
    ),
    file.path(GENERATED_DIR, "data_descriptive_tables.tex")
  )
}

write_profit_correction_table <- function() {
  correction <- read_diag("step2_profit_correction_by_year.csv") |>
    filter(year %in% MAIN_YEARS) |>
    mutate(
      reduction = uncorrected_profit - corrected_profit,
      reduction_rate = safe_divide(reduction, uncorrected_profit)
    )

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
      uncorrected_share = safe_divide(
        uncorrected_profit,
        sum(uncorrected_profit, na.rm = TRUE)
      ),
      reduction_share = safe_divide(reduction, sum(reduction, na.rm = TRUE)),
      label = recode(
        profit_correction_source_baseline,
        "observed_adjusted" = "OECD adjusted",
        "anchored_model" = "External-anchor domestic",
        "parity_shrinkage" = "Domestic model, parity signal",
        "fallback_prior" = "Domestic model, fallback prior",
        "uncorrected_foreign" = "Foreign affiliates",
        .default = profit_correction_source_baseline
      ),
      order = match(
        profit_correction_source_baseline,
        c(
          "observed_adjusted", "anchored_model", "parity_shrinkage",
          "fallback_prior", "uncorrected_foreign"
        )
      )
    ) |>
    arrange(order)

  total <- branch |>
    summarise(
      cells = sum(cells),
      uncorrected_profit = sum(uncorrected_profit),
      corrected_profit = sum(corrected_profit),
      reduction = sum(reduction),
      reduction_rate = safe_divide(reduction, uncorrected_profit),
      uncorrected_share = 1,
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

  row_lines <- character(0)
  for (i in seq_len(nrow(effect_rows))) {
    if (i == nrow(effect_rows)) {
      row_lines <- c(row_lines, "\\midrule")
    }
    row_lines <- c(row_lines, paste0(
      effect_rows$label[i], " & ",
      effect_rows$cells[i], " & ",
      effect_rows$uncorrected[i], " & ",
      effect_rows$corrected[i], " & ",
      effect_rows$reduction[i], " & ",
      effect_rows$reduction_rate[i], " & ",
      effect_rows$reduction_share[i], " \\\\"
    ))
  }

  lines <- assemble_inline_table(
    col_spec = ">{\\raggedright\\arraybackslash}p{4.2cm}rrrrrr",
    caption_lines = c(
      "\\caption[Profit-base correction]{Correction from public CbCR profit to the reconciliation profit branch, 2017 to 2022}",
      "\\label{tab:profit_correction_effects}"
    ),
    header_lines = "Category & Cells & Reported & Corrected & Reduction & Rate (\\%) & Share (\\%) \\\\",
    body_lines = row_lines,
    notes = "Positive-profit cells, USD bn; share is share of total profit reduction.",
    size = "\\footnotesize",
    tabcolsep = "3pt"
  )

  write_custom_table(file.path(GENERATED_TABLES_DIR, "profit_correction_effects.tex"), lines)
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

  order_labels <- c(
    "Direct Table IV", "Beta percentile fit", "BSPI shape transport",
    "Jurisdiction-average fallback", "Missing source"
  )

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
    file.path(GENERATED_TABLES_DIR, "stage1_source_coverage.tex"),
    caption = "Stage 1 source coverage, 2017 to 2022",
    short_caption = "Stage 1 source coverage",
    col_spec = paste0("l", paste(rep("r", length(years) + 1), collapse = "")),
    header = c("Source", years, "Total"),
    rows = rows,
    notes = paste(
      "Counts are parent-affiliate-year cells in the Stage 1 bilateral panel.",
      "Positive-profit cells are shown separately because only those cells can generate top-up tax.",
      ""
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
      tibble(row = paste0("\\multicolumn{7}{l}{\\textit{", scope_label, "}}")),
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
        table_rows[[length(table_rows) + 1L]] <- c(
          latex_escape(block$row[i]),
          block$values[[i]]
        )
      } else {
        table_rows[[length(table_rows) + 1L]] <- paste0(block$row[i], " \\\\")
      }
    }
  }

  body_lines <- character(0)
  for (row in table_rows) {
    if (length(row) == 1) {
      body_lines <- c(body_lines, row)
    } else {
      body_lines <- c(body_lines, paste0(paste(row, collapse = " & "), " \\\\"))
    }
  }

  lines <- assemble_inline_table(
    col_spec = "lrrrrrr",
    caption_lines = c(
      "\\caption[Stage 1 rates, EU27 and global]{Stage 1 rates before SBIE and behavioural responses. Low-taxed share is low-taxed profit divided by positive corrected profit. The top-up gap is the profit-weighted average distance to the 15 per cent threshold on the measured low-taxed profit mass. Liability rate is aggregate Stage 1 top-up divided by positive corrected profit. All entries are percentages.}",
      "\\label{tab:stage1_rates_updated}"
    ),
    header_lines = paste0(" & ", paste(years, collapse = " & "), " \\\\"),
    body_lines = body_lines,
    size = "\\small"  )

  write_custom_table(file.path(GENERATED_TABLES_DIR, "stage1_rates.tex"), lines)
}

write_stage1_bspi_table <- function() {
  bspi <- read_diag("step3_stage1_bspi_validation.csv")
  jurisdiction_names <- read_processed("base_panel.rds") |>
    distinct(affiliate, affiliate_jurisdiction_name)

  selected <- bspi |>
    filter(affiliate %in% EU27_ISO3) |>
    left_join(jurisdiction_names, by = "affiliate") |>
    arrange(desc(bspi_tv_anchor_validation)) |>
    slice_head(n = 6) |>
    bind_rows(
      bspi |>
        filter(affiliate %in% c("NLD", "LUX", "IRL")) |>
        left_join(jurisdiction_names, by = "affiliate")
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
    file.path(GENERATED_TABLES_DIR, "stage1_bspi_validation.tex"),
    caption = "EU27 BSPI validation, 2019 to 2020 anchor versus 2021 to 2022 validation",
    short_caption = "EU27 BSPI validation",
    col_spec = "lrrrr",
    header = c(
      "Affiliate", "Anchor low share", "Validation low share",
      "TV distance", "Flag"
    ),
    rows = selected
  )
}

write_stage1_crossval_table <- function() {
  x <- read_diag("step3_stage1_crossval_summary.csv")
  crossval_metric <- function(metric) as.numeric(metric_value(x, metric))

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
      fmt_int(crossval_metric("overlap_affiliate_years")),
      fmt_int(crossval_metric("overlap_zero_low_share_cases")),
      fmt_num(crossval_metric("low_share_median_diff"), 3),
      fmt_num(crossval_metric("low_share_mae"), 3),
      fmt_num(crossval_metric("low_share_p90_abs_error"), 3),
      fmt_num(crossval_metric("low_share_spearman"), 3),
      fmt_num(crossval_metric("low_share_calibration_slope"), 2),
      fmt_num(crossval_metric("low_share_calibration_r_squared"), 3),
      fmt_num(crossval_metric("liability_rate_median_diff"), 3),
      fmt_num(crossval_metric("liability_rate_mae"), 3),
      fmt_num(crossval_metric("liability_rate_p90_abs_error"), 3),
      fmt_num(crossval_metric("positive_partition_tv_median"), 3),
      fmt_num(crossval_metric("positive_partition_tv_p90"), 3),
      fmt_p(crossval_metric("crossval_low_share_wilcox_pvalue"))
    )
  )

  write_latex_table(
    file.path(GENERATED_TABLES_DIR, "stage1_crossval.tex"),
    caption = "Beta percentile fit versus Table IV cross-validation",
    short_caption = "Beta percentile fit versus Table IV cross-validation",
    col_spec = "lr",
    header = c("Statistic", "Value"),
    rows = rows,
    notes = paste(
      "Differences are Table I constrained-Beta percentile fit minus Table IV direct observation.",
      "Calibration regresses the direct Table IV low-taxed share on the fitted Table I low-taxed share and year fixed effects.",
      ""
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
        total_positive_profit,
        na.rm = TRUE
      ),
      stage1_avg = weighted.mean(stage1_average_liability_rate,
        total_positive_profit,
        na.rm = TRUE
      ),
      stage2_avg = weighted.mean(stage2_average_liability_rate,
        total_positive_profit,
        na.rm = TRUE
      ),
      stage1_dist = weighted.mean(stage1_distributional_liability_rate,
        total_positive_profit,
        na.rm = TRUE
      ),
      stage2_dist = weighted.mean(stage2_distributional_liability_rate,
        total_positive_profit,
        na.rm = TRUE
      ),
      .groups = "drop"
    ) |>
    mutate(
      scope = recode(scope, "eu27" = "EU27", "global" = "Global"),
      rate_scenario = recode(rate_scenario,
        "initial" = "Initial",
        "long_run" = "Long-run"
      )
    ) |>
    arrange(
      match(scope, c("EU27", "Global")),
      match(rate_scenario, c("Initial", "Long-run"))
    ) |>
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
    file.path(GENERATED_TABLES_DIR, "stage2_aggregate.tex"),
    caption = "Aggregate Stage 2 effect of the SBIE",
    short_caption = "Aggregate Stage 2 effect of the SBIE",
    col_spec = "llrrrrr",
    header = c(
      "Scope", "SBIE rates", "SBIE ratio", "Stage 1, avg",
      "Stage 2, avg", "Stage 1, dist", "Stage 2, dist"
    ),
    rows = agg,
    notes = paste(
      "Initial rates use a 10 per cent payroll carve-out and an 8 per cent tangible-asset carve-out.",
      "Long-run rates use 5 per cent for both components.",
      ""
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
          total_profit_proxy,
          na.rm = TRUE
        )
    )

  countries <- x |>
    filter(affiliate %in% SELECTED_COUNTRIES) |>
    arrange(match(affiliate, SELECTED_COUNTRIES)) |>
    select(
      affiliate_name, total_profit_proxy, weighted_phi, weighted_kappa,
      weighted_floor_distributional, weighted_floor_distributional_sbti
    )

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
    file.path(GENERATED_TABLES_DIR, "stage2_sectoral_sbti.tex"),
    caption = "Sectoral SBTI effect in selected EU countries",
    short_caption = "Sectoral SBTI effect in selected EU countries",
    col_spec = "lrrrrr",
    header = c(
      "Country", "SBIE ratio", "SBTI capacity", "Floor before SBTI",
      "Floor after SBTI", "Change"
    ),
    rows = rows,
    notes = paste(
      "The table uses the 2022 EU sectoral reference matrix and initial 2024 rates.",
      "All rates are percentages.",
      ""
    )
  )
}

write_stage2_h5_table <- function() {
  x <- read_diag("step4_stage2_sectoral_h5_regression_clustered.csv")

  pick <- function(variant, trm, col) {
    out <- x[[col]][x$model_variant == variant & x$term == trm]
    if (length(out) == 0) NA_real_ else out[1]
  }

  coef_cell_star <- function(variant, trm, digits = 5) {
    est <- pick(variant, trm, "estimate")
    if (is.na(est)) return("---")
    paste0(fmt_num(est, digits), significance_stars(pick(variant, trm, "p_value")))
  }

  se_cell <- function(variant, trm, digits = 5) {
    if (is.na(pick(variant, trm, "estimate"))) return("")
    paste0("(", fmt_num(pick(variant, trm, "std_error"), digits), ")")
  }

  n_obs <- fmt_int(pick("unweighted", "sectoral_capital_intensity", "n_obs"))
  n_clusters <- fmt_int(pick("unweighted", "sectoral_capital_intensity", "n_clusters"))
  r2_uw <- fmt_num(pick("unweighted", "sectoral_capital_intensity", "r_squared"), 3)
  r2_pw <- fmt_num(pick("profit_weighted", "sectoral_capital_intensity", "r_squared"), 3)

  rows <- tibble::tribble(
    ~term, ~uw, ~pw,
    "Constant ($\\alpha$)",
    coef_cell_star("unweighted", "(Intercept)"),
    coef_cell_star("profit_weighted", "(Intercept)"),
    "",
    se_cell("unweighted", "(Intercept)"),
    se_cell("profit_weighted", "(Intercept)"),
    "Tangible-asset intensity ($\\beta$)",
    coef_cell_star("unweighted", "sectoral_capital_intensity"),
    coef_cell_star("profit_weighted", "sectoral_capital_intensity"),
    "",
    se_cell("unweighted", "sectoral_capital_intensity"),
    se_cell("profit_weighted", "sectoral_capital_intensity"),
    "Country fixed effects", "Yes", "Yes",
    "Observations", n_obs, n_obs,
    "Clusters (countries)", n_clusters, n_clusters,
    "$R^2$", r2_uw, r2_pw
  )

  write_latex_table(
    file.path(GENERATED_TABLES_DIR, "stage2_h5_regression.tex"),
    caption = "Sectoral capital-intensity regression",
    short_caption = "Sectoral capital-intensity regression",
    col_spec = "lcc",
    header = c(
      "", "(1) Unweighted", "(2) Profit-weighted"
    ),
    rows = rows,
    notes = paste(
      "Estimating equation:",
      "$\\Delta\\mathrm{floor}_{cs} = \\alpha + \\gamma_c + \\beta\\,\\mathrm{capint}_{cs} + \\varepsilon_{cs}$,",
      "where $c$ indexes EU27 countries and $s$ broad NACE sectors,",
      "$\\Delta\\mathrm{floor}_{cs}$ is the SBTI-induced change in the average effective floor",
      "in the 2022 EU sectoral reference matrix (the dependent variable),",
      "$\\mathrm{capint}_{cs}$ is sectoral tangible-asset intensity,",
      "$\\alpha$ is the constant and $\\gamma_c$ are country fixed effects.",
      "Standard errors clustered by country in parentheses.",
      "$^{*}\\,p<0.10$, $^{**}\\,p<0.05$, $^{***}\\,p<0.01$."
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
    file.path(GENERATED_TABLES_DIR, "stage3_model_comparison.tex"),
    caption = "Stage 3 model comparison",
    short_caption = "Stage 3 model comparison",
    col_spec = "lrrrrrr",
    header = c(
      "Model", "$N$", "Pairs", "Within $R^2$", "BIC rank",
      "$\\Delta$BIC", "Tax Wald $p$, two-way"
    ),
    rows = x,
    notes = paste(
      "Two-way fixed-effect Hines-Rice models.",
      "The BIC ranking is the model-selection rule used in the current pipeline.",
      ""
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
  term_order <- c(
    "ETR", "ETR squared", "Log shifted ETR",
    "Log tangible assets", "Log payroll proxy",
    "Log GDP per capita", "Log population"
  )

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
    select(
      model_label, n, n_pairs, n_affiliates, within_r_squared, bic_rank,
      delta_bic, tax_terms_joint_p_value_two_way
    ) |>
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

  stat_order <- c(
    "$N$", "Parent-affiliate pairs", "Affiliate clusters",
    "Within $R^2$", "BIC rank", "$\\Delta$BIC",
    "Joint tax-term $p$"
  )
  statistic_rows <- tibble(Variable = stat_order) |>
    left_join(rename(model_stats, Variable = Statistic), by = "Variable") |>
    mutate(across(all_of(model_order), ~ replace_na(.x, "")))

  rows <- bind_rows(
    coefficient_rows,
    tibble(
      Variable = "\\midrule", Linear = "", Quadratic = "",
      Logarithmic = ""
    ),
    statistic_rows
  )

  row_lines <- apply(as.matrix(rows), 1, function(r) {
    if (r[1] == "\\midrule") {
      "\\midrule"
    } else {
      paste0(paste(r, collapse = " & "), " \\\\")
    }
  })

  lines <- assemble_inline_table(
    col_spec = "lccc",
    caption_lines = c(
      "\\caption[Stage 3 fixed-effect regression estimates]{Stage 3 fixed-effect regression estimates. Dependent variable is log profit. Coefficients are reported with two-way parent-and-affiliate clustered standard errors in parentheses.}",
      "\\label{tab:stage3_regression_table}"
    ),
    header_lines = " & Linear & Quadratic & Logarithmic \\\\",
    body_lines = row_lines,
    notes = "Parent-affiliate pair and year fixed effects; $^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$.",
    size = "\\small"
  )

  write_custom_table(file.path(GENERATED_TABLES_DIR, "stage3_regression_table.tex"), lines)
}

write_stage3_main_regression_table <- function() {
  coef <- read_diag("step5_stage3_coefficients.csv") |>
    filter(inference == "parent_affiliate_clustered")
  models <- read_diag("step5_stage3_model_comparison.csv")
  iv <- read_diag("step5_stage3_tax_endogeneity_diagnostics.csv") |>
    filter(inference == "parent_affiliate_clustered")

  cell_est <- function(estimate, p_value) {
    if (length(estimate) == 0 || is.na(estimate)) {
      return("")
    }
    paste0(fmt_num(estimate, 3), significance_stars(p_value))
  }
  cell_se <- function(std_error) {
    if (length(std_error) == 0 || is.na(std_error)) {
      return("")
    }
    paste0("(", fmt_num(std_error, 3), ")")
  }
  coef_get <- function(spec, trm) {
    row <- coef |> filter(model_spec == spec, term == trm)
    list(est = cell_est(row$estimate[1], row$p_value[1]),
      se = cell_se(row$std_error[1]))
  }
  iv_get <- function(diag_name) {
    row <- iv |> filter(diagnostic == diag_name)
    list(est = cell_est(row$estimate[1], row$p_value[1]),
      se = cell_se(row$std_error[1]))
  }
  empty <- list(est = "", se = "")

  stacked_rows <- function(label, cells) {
    est <- vapply(cells, function(x) x$est, character(1))
    se <- vapply(cells, function(x) x$se, character(1))
    c(
      paste0(label, " & ", paste(est, collapse = " & "), " \\\\"),
      paste0(" & ", paste(se, collapse = " & "), " \\\\[2pt]")
    )
  }
  simple_row <- function(label, vals) {
    paste0(label, " & ", paste(vals, collapse = " & "), " \\\\")
  }

  etr_row <- stacked_rows("ETR $(\\tau)$", list(
    coef_get("linear", "tau"),
    coef_get("quadratic", "tau"),
    coef_get("logarithmic", "tau"),
    iv_get("simulated_tax_code_eatr_2sls_for_profit"),
    iv_get("lagged_statutory_cit_2sls_for_profit")
  ))
  etr_sq_row <- stacked_rows("ETR squared $(\\tau^{2})$", list(
    coef_get("linear", "tau_sq"),
    coef_get("quadratic", "tau_sq"),
    coef_get("logarithmic", "tau_sq"),
    empty, empty
  ))
  log_tau_row <- stacked_rows("Log shifted ETR $(\\ln(\\tau+t_{0}))$", list(
    coef_get("linear", "log_tau"),
    coef_get("quadratic", "log_tau"),
    coef_get("logarithmic", "log_tau"),
    empty, empty
  ))

  model_stat <- function(spec, col) {
    val <- models[[col]][models$model_spec == spec]
    if (length(val) == 0) NA else val[1]
  }
  iv_stat <- function(diag_name, col) {
    val <- iv[[col]][iv$diagnostic == diag_name]
    if (length(val) == 0) NA else val[1]
  }

  eatr_2sls <- "simulated_tax_code_eatr_2sls_for_profit"
  cit_2sls <- "lagged_statutory_cit_2sls_for_profit"

  n_row <- simple_row("Observations", c(
    fmt_int(model_stat("linear", "n")),
    fmt_int(model_stat("quadratic", "n")),
    fmt_int(model_stat("logarithmic", "n")),
    fmt_int(iv_stat(eatr_2sls, "n")),
    fmt_int(iv_stat(cit_2sls, "n"))
  ))
  pairs_row <- simple_row("Parent-affiliate pairs", c(
    fmt_int(model_stat("linear", "n_pairs")),
    fmt_int(model_stat("quadratic", "n_pairs")),
    fmt_int(model_stat("logarithmic", "n_pairs")),
    fmt_int(iv_stat(eatr_2sls, "n_pairs")),
    fmt_int(iv_stat(cit_2sls, "n_pairs"))
  ))
  r2_row <- simple_row("Within $R^2$", c(
    fmt_num(model_stat("linear", "within_r_squared"), 3),
    fmt_num(model_stat("quadratic", "within_r_squared"), 3),
    fmt_num(model_stat("logarithmic", "within_r_squared"), 3),
    fmt_num(iv_stat(eatr_2sls, "within_r_squared"), 3),
    fmt_num(iv_stat(cit_2sls, "within_r_squared"), 3)
  ))
  bic_row <- simple_row("$\\Delta$BIC (vs.\\ linear)", c(
    fmt_num(model_stat("linear", "delta_bic"), 2),
    fmt_num(model_stat("quadratic", "delta_bic"), 2),
    fmt_num(model_stat("logarithmic", "delta_bic"), 2),
    "--", "--"
  ))
  joint_row <- simple_row("Joint tax-term $p$", c(
    fmt_p(model_stat("linear", "tax_terms_joint_p_value_two_way")),
    fmt_p(model_stat("quadratic", "tax_terms_joint_p_value_two_way")),
    fmt_p(model_stat("logarithmic", "tax_terms_joint_p_value_two_way")),
    "--", "--"
  ))

  body_lines <- c(
    "\\multicolumn{6}{@{}l}{\\textit{Panel A: Effective tax rate terms}} \\\\[2pt]",
    etr_row,
    etr_sq_row,
    log_tau_row,
    "\\midrule",
    "\\multicolumn{6}{@{}l}{\\textit{Panel B: Fit and model selection}} \\\\[2pt]",
    n_row,
    pairs_row,
    r2_row,
    bic_row,
    joint_row
  )

  lines <- assemble_inline_table(
    col_spec = "lccccc",
    caption_lines = c(
      paste0(
        "\\caption[Behavioural response of reported profit to the affiliate ",
        "effective tax rate]{Behavioural response of reported profit to the ",
        "affiliate effective tax rate}"
      ),
      "\\label{tab:stage3_main_regression}"
    ),
    header_lines = c(
      paste0(
        " & \\multicolumn{3}{c}{Fixed-effect OLS} & ",
        "\\multicolumn{2}{c}{Fixed-effect 2SLS} \\\\"
      ),
      "\\cmidrule(lr){2-4}\\cmidrule(lr){5-6}",
      paste0(
        " & Linear$^{\\dagger}$ & Quadratic & Logarithmic & ",
        "Simulated EATR & Lagged CIT \\\\"
      )
    ),
    body_lines = body_lines,
    notes = "Clustered two-way by parent and affiliate; $^{\\dagger}$ preferred specification.",
    size = "\\footnotesize",
    tabcolsep = "3pt"  )

  write_custom_table(
    file.path(GENERATED_TABLES_DIR, "stage3_main_regression.tex"), lines
  )
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
      match(
        Instrument,
        c("OECD simulated fixed-project EATR", "Lagged statutory CIT")
      ),
      match(
        Diagnostic,
        c(
          "First stage: CbCR ETR", "Reduced form: log profit",
          "FE-2SLS: log profit"
        )
      )
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
    file.path(GENERATED_TABLES_DIR, "stage3_iv_diagnostics.tex"),
    caption = "Tax-code instrument diagnostics",
    short_caption = "Tax-code instrument diagnostics",
    col_spec = "lllrrrrr",
    header = c(
      "Instrument", "Diagnostic", "Dependent variable", "Coefficient",
      "Weak-IV $F$", "$p$-value", "$N$", "Within $R^2$"
    ),
    rows = iv,
    notes = "FE first stages, reduced forms and 2SLS; weak-IV $F$ is parent--affiliate clustered.",
    size = "\\scriptsize",
    tabcolsep = "2pt",
    fit_width = TRUE
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
  linear_wald <- wald |>
    filter(model_spec == "linear") |>
    slice(1)
  log_wald <- wald |>
    filter(model_spec == "logarithmic") |>
    slice(1)
  quad_wald <- wald |>
    filter(model_spec == "quadratic") |>
    slice(1)

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

  below_5 <- tail |>
    filter(tail_band == "below_5pct") |>
    slice(1)
  five_to_15 <- tail |>
    filter(tail_band == "five_to_15pct") |>
    slice(1)

  stable_samples <- robustness |>
    group_by(sample) |>
    slice_min(bic_rank, n = 1, with_ties = FALSE) |>
    ungroup()
  linear_stable <- stable_samples |>
    filter(model_spec == "linear") |>
    summarise(n = n(), .groups = "drop") |>
    pull(n)
  total_stable <- nrow(stable_samples)

  influence_path <- file.path(DIAGNOSTICS_DIR, "step10_jurisdiction_influence_case_summary.csv")
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
        na.rm = TRUE
      ), 1),
      "\\% to ",
      fmt_pct(max(influence$preferred_sbs_behavioural_revenue_pct_change,
        na.rm = TRUE
      ), 1),
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
    file.path(GENERATED_TABLES_DIR, "stage3_econometric_scorecard.tex"),
    caption = "Econometric diagnostics for the behavioural stage",
    short_caption = "Econometric diagnostics for the behavioural stage",
    col_spec = "L{3.2cm}L{5.4cm}L{6.2cm}",
    header = c("Diagnostic", "Result", "Reading"),
    rows = rows,
    notes = paste(
      "The table compacts the formal diagnostics that support the Stage 3 behavioural counterfactual.",
      "It is generated from the same fixed-effect, IV, model-selection, tail-support and influence outputs used in the appendix.",
      ""
    ),
    size = "\\footnotesize"  )
}

write_stage3_reliability_scorecard_table <- function() {
  model <- read_diag("step5_stage3_model_comparison.csv") |>
    arrange(bic_rank)
  coefficients <- read_diag("step5_stage3_coefficients.csv")
  wald <- read_diag("step5_stage3_model_wald_tests.csv")
  iv <- read_diag("step5_stage3_tax_endogeneity_diagnostics.csv") |>
    filter(inference == "parent_affiliate_clustered")
  tail <- read_diag("step5_stage3_etr_tail_support.csv") |>
    filter(scope == "pooled")

  preferred <- model |> slice(1)
  log_model <- model |> filter(model_spec == "logarithmic")
  quad_model <- model |> filter(model_spec == "quadratic")

  linear_two_way <- coefficients |>
    filter(
      model_spec == "linear", term == "tau",
      inference == "parent_affiliate_clustered"
    ) |>
    slice(1)
  linear_affiliate <- coefficients |>
    filter(
      model_spec == "linear", term == "tau",
      inference == "affiliate_clustered"
    ) |>
    slice(1)

  simulated_first <- iv |>
    filter(diagnostic == "simulated_tax_code_eatr_first_stage_for_cbcr_etr") |>
    slice(1)
  statutory_first <- iv |>
    filter(diagnostic == "lagged_statutory_cit_first_stage_for_cbcr_etr") |>
    slice(1)
  simulated_reduced <- iv |>
    filter(diagnostic == "simulated_tax_code_eatr_reduced_form_for_profit") |>
    slice(1)
  statutory_reduced <- iv |>
    filter(diagnostic == "lagged_statutory_cit_reduced_form_for_profit") |>
    slice(1)
  simulated_2sls <- iv |>
    filter(diagnostic == "simulated_tax_code_eatr_2sls_for_profit") |>
    slice(1)
  statutory_2sls <- iv |>
    filter(diagnostic == "lagged_statutory_cit_2sls_for_profit") |>
    slice(1)

  below_5 <- tail |>
    filter(tail_band == "below_5pct") |>
    slice(1)
  five_to_15 <- tail |>
    filter(tail_band == "five_to_15pct") |>
    slice(1)

  influence_path <- file.path(DIAGNOSTICS_DIR, "step10_jurisdiction_influence_case_summary.csv")
  if (file.exists(influence_path)) {
    influence <- read_csv(influence_path, show_col_types = FALSE)

    influence_summary <- influence |>
      group_by(leave_dimension) |>
      summarise(
        cases = n(),
        min_semi = min(leave_semielasticity_5, na.rm = TRUE),
        max_semi = max(leave_semielasticity_5, na.rm = TRUE),
        stable = sum(preferred_model_stable, na.rm = TRUE),
        min_revenue_change =
          min(preferred_sbs_behavioural_revenue_pct_change, na.rm = TRUE),
        max_revenue_change =
          max(preferred_sbs_behavioural_revenue_pct_change, na.rm = TRUE),
        .groups = "drop"
      )

    affiliate_influence <- influence_summary |>
      filter(leave_dimension == "affiliate") |>
      slice(1)
    parent_influence <- influence_summary |>
      filter(leave_dimension == "parent") |>
      slice(1)

    affiliate_result <- paste0(
      "Affiliate omissions: semi-elasticity ",
      fmt_num(affiliate_influence$min_semi[1], 2), "--",
      fmt_num(affiliate_influence$max_semi[1], 2),
      "; model stable in ", fmt_int(affiliate_influence$stable[1]),
      " of ", fmt_int(affiliate_influence$cases[1]),
      "; preferred revenue change ",
      fmt_pct(affiliate_influence$min_revenue_change[1], 1), "\\% to ",
      fmt_pct(affiliate_influence$max_revenue_change[1], 1), "\\%."
    )

    parent_result <- paste0(
      "Parent omissions: semi-elasticity ",
      fmt_num(parent_influence$min_semi[1], 2), "--",
      fmt_num(parent_influence$max_semi[1], 2),
      "; model stable in ", fmt_int(parent_influence$stable[1]),
      " of ", fmt_int(parent_influence$cases[1]),
      "; preferred revenue change ",
      fmt_pct(parent_influence$min_revenue_change[1], 1), "\\% to ",
      fmt_pct(parent_influence$max_revenue_change[1], 1), "\\%."
    )
  } else {
    affiliate_result <- "Leave-one-affiliate diagnostics not yet generated."
    parent_result <- "Leave-one-parent diagnostics not yet generated."
  }

  rows <- tibble(
    Diagnostic = c(
      "Preferred FE estimate",
      "Model selection",
      "Clustered inference",
      "FE-2SLS first stage",
      "Reduced forms and 2SLS",
      "Low-ETR tail support",
      "Leave-one affiliate",
      "Leave-one parent",
      "Final decision"
    ),
    Result = c(
      paste0(
        "$\\hat{\\beta}_{\\tau}=$ ",
        fmt_num(linear_two_way$estimate[1], 3),
        "; semi-elasticity $=$ ",
        fmt_num(-linear_two_way$estimate[1], 2),
        "; $N=$ ", fmt_int(preferred$n[1]),
        "; pairs $=$ ", fmt_int(preferred$n_pairs[1]),
        "; within $R^2=$ ", fmt_num(preferred$within_r_squared[1], 4),
        "."
      ),
      paste0(
        "BIC selects linear; $\\Delta$BIC log $=$ ",
        fmt_num(log_model$delta_bic[1], 2),
        " and quadratic $=$ ",
        fmt_num(quad_model$delta_bic[1], 2),
        "; tax-term Wald $p=$ ",
        fmt_p(preferred$tax_terms_joint_p_value_two_way[1]),
        "."
      ),
      paste0(
        "Two-way clustered SE for ETR $=$ ",
        fmt_num(linear_two_way$std_error[1], 3),
        " ($p=$ ", fmt_p(linear_two_way$p_value[1]),
        "); affiliate-clustered SE $=$ ",
        fmt_num(linear_affiliate$std_error[1], 3),
        " ($p=$ ", fmt_p(linear_affiliate$p_value[1]), ")."
      ),
      paste0(
        "Simulated EATR: coefficient ",
        fmt_num(simulated_first$estimate[1], 3),
        ", $F=$ ", fmt_num(simulated_first$weak_instrument_f[1], 2),
        "; lagged statutory CIT: coefficient ",
        fmt_num(statutory_first$estimate[1], 3),
        ", $F=$ ", fmt_num(statutory_first$weak_instrument_f[1], 2),
        "."
      ),
      paste0(
        "Reduced-form signs are negative but imprecise: simulated EATR ",
        fmt_num(simulated_reduced$estimate[1], 3),
        " ($p=$ ", fmt_p(simulated_reduced$p_value[1]),
        "), lagged CIT ",
        fmt_num(statutory_reduced$estimate[1], 3),
        " ($p=$ ", fmt_p(statutory_reduced$p_value[1]),
        "); FE-2SLS $p=$ ",
        fmt_p(simulated_2sls$p_value[1]), " and ",
        fmt_p(statutory_2sls$p_value[1]), "."
      ),
      paste0(
        "Below 5\\% ETR: ", fmt_pct(below_5$row_share[1], 1),
        "\\% of rows and ", fmt_pct(below_5$profit_share[1], 1),
        "\\% of profit; 5--15\\% ETR: ",
        fmt_pct(five_to_15$row_share[1], 1), "\\% of rows."
      ),
      affiliate_result,
      parent_result,
      "Use the behavioural input as a scenario coefficient; do not make it the causal centrepiece."
    ),
    Weight = c(
      "Moderate: the sign and magnitude are economically interpretable.",
      "Moderate: the public panel prefers a parsimonious linear response.",
      "Useful: two-way clustering is the main inference; affiliate clustering is a less conservative comparison.",
      "Limited: the instruments are relevant enough for diagnostics.",
      "Weak for causal replacement: reduced forms and 2SLS are too imprecise.",
      "Limited for curvature: the low-rate tail exists but does not strongly identify nonlinear extrapolation.",
      "Moderate for the coefficient; weaker for final revenue because conduit jurisdictions are influential.",
      "Moderate for the coefficient; model selection changes in one parent omission.",
      "The revenue decomposition should carry more interpretive weight than the behavioural module."
    )
  )

  write_latex_table(
    file.path(GENERATED_TABLES_DIR, "stage3_reliability_scorecard.tex"),
    caption = "Reliability scorecard for the behavioural module",
    short_caption = "Reliability scorecard for the behavioural module",
    col_spec = "L{3.0cm}L{6.3cm}L{5.4cm}",
    header = c("Diagnostic", "Result", "Weight for interpretation"),
    rows = rows,
    notes = paste(
      "The scorecard reports whether the behavioural module is usable for the revenue counterfactual.",
      "The preferred estimate is the linear two-way fixed-effect Hines-Rice coefficient with parent-and-affiliate clustered inference.",
      "The final row states the evidentiary decision used in the thesis.",
      ""
    ),
    size = "\\footnotesize"  )
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
    file.path(GENERATED_TABLES_DIR, "stage3_semielasticity.tex"),
    caption = "Stage 3 semi-elasticity schedule",
    short_caption = "Stage 3 semi-elasticity schedule",
    col_spec = "lrrrrr",
    header = c(
      "Model", "ETR", "Semi-elasticity", "SE", "$p$-value",
      "Reallocation share"
    ),
    rows = x,
    notes = paste(
      "Standard errors are two-way clustered by parent and affiliate.",
      "Reallocation share is the implied reduction when the effective rate is raised to 15 per cent.",
      ""
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
    file.path(GENERATED_TABLES_DIR, "stage4_6_anova.tex"),
    caption = "Pooled factorial decomposition of EU GMT revenue",
    short_caption = "Pooled factorial decomposition of EU GMT revenue",
    col_spec = "lrr",
    header = c("Effect", "Order", "Share (\\%)"),
    rows = x,
    notes = paste(
      "Pooled orthogonal structural variance decomposition across the 32 legally allocated revenue scenarios, EU27 country-years, 2017 to 2022.",
      ""
    )
  )
}

fmt_signed_pct <- function(x, digits = 1) {
  ifelse(
    is.na(x),
    "",
    sprintf("%+.*f", digits, 100 * x)
  )
}

write_stage46_factor_decomposition_table <- function() {
  shapley <- read_diag("step7_stage4_6_shapley_factor_attribution.csv") |>
    arrange(desc(shapley_eta_squared))

  effects <- read_diag("step7_stage4_6_main_effects_pooled.csv") |>
    mutate(effect = factor(effect, levels = shapley$effect)) |>
    arrange(effect)

  rows <- shapley |>
    mutate(
      level_0 = effects$level_0[match(effect, effects$effect)],
      level_1 = effects$level_1[match(effect, effects$effect)],
      high_minus_low = effects$high_minus_low[match(effect, effects$effect)],
      pct_high_minus_low = effects$pct_high_minus_low[match(effect, effects$effect)]
    )

  body_lines <- vapply(seq_len(nrow(rows)), function(i) {
    r <- rows[i, ]
    paste0(
      latex_escape(r$factor_label), " & ",
      fmt_pct(r$main_eta_squared, 1), " & ",
      sprintf("\\textbf{%s}", fmt_pct(r$shapley_eta_squared, 1)), " & ",
      fmt_bn(r$level_0, 1), " & ",
      fmt_bn(r$level_1, 1), " & ",
      fmt_bn(r$high_minus_low, 1), " & ",
      fmt_signed_pct(r$pct_high_minus_low, 1),
      " \\\\"
    )
  }, character(1))

  notes <- "Pooled 32-scenario decomposition, EU27 2017--2022; variance shares are partial $\\eta^{2}$."

  write_custom_table(
    file.path(GENERATED_TABLES_DIR, "stage4_6_factor_decomposition.tex"),
    assemble_inline_table(
      col_spec = "l rr rrr r",
      caption_lines = c(
        "\\caption[Factorial decomposition of EU GMT revenue]{Factorial decomposition of EU GMT revenue}",
        "\\label{tab:stage4_6_factor_decomposition}",
        "\\label{tab:stage4_6_shapley_attribution}",
        "\\label{tab:stage4_6_main_effects}"
      ),
      header_lines = c(
        " & \\multicolumn{2}{c}{Variance (\\%)} & \\multicolumn{4}{c}{Main effects (US\\$ bn)} \\\\",
        "\\cmidrule(lr){2-3} \\cmidrule(lr){4-7}",
        "Factor & Main & Allocated & Low & High & Effect & Chg (\\%) \\\\"
      ),
      body_lines = body_lines,
      notes = notes,
      size = "\\footnotesize",
      tabcolsep = "3pt"
    )
  )
}

write_stage46_channel_table <- function() {
  wide <- read_diag("step7_stage4_6_preferred_channel_summary.csv") |>
    mutate(channel = factor(channel, levels = c("IIR", "QDMTT", "UTPR"))) |>
    select(factor4_sbs, channel, revenue_bn) |>
    pivot_wider(names_from = factor4_sbs, values_from = revenue_bn) |>
    arrange(channel) |>
    mutate(share = universal / sum(universal))

  total <- wide |>
    summarise(
      channel = "Total",
      universal = sum(universal),
      sbs = sum(sbs),
      share = sum(share)
    )

  build_row <- function(r) {
    paste0(
      paste(
        c(
          latex_escape(as.character(r$channel)),
          fmt_num(r$universal, 1),
          fmt_num(r$sbs, 1),
          fmt_num(100 * r$share, 1)
        ),
        collapse = " & "
      ),
      " \\\\"
    )
  }

  body_lines <- vapply(seq_len(nrow(wide)), function(i) build_row(wide[i, ]), character(1))
  total_line <- build_row(total)

  notes <- NULL

  lines <- c(
    "% Generated by code/08_generate_results_tables.R",
    assemble_inline_table(
      col_spec = "lrrr",
      caption_lines = c(
        "\\caption[Preferred-core revenue by collection channel]{Preferred-core revenue by collection channel, cumulative 2017--2022.}",
        "\\label{tab:preferred_channel_updated}"
      ),
      header_lines = c(
        " & \\multicolumn{2}{c}{Revenue (US\\$ bn)} & Share (\\%) \\\\",
        "\\cmidrule(lr){2-3}",
        "Channel & Universal & SbS & EU total \\\\"
      ),
      body_lines = c(body_lines, "\\midrule", total_line),
      notes = notes,
      size = "\\small"
    )
  )

  writeLines(lines, file.path(GENERATED_TABLES_DIR, "preferred_channel.tex"))
}

write_stage1_measurement_error_table <- function() {
  input_file <- file.path(DIAGNOSTICS_DIR, "step9_stage1_measurement_error_preferred_interval.csv")
  if (!file.exists(input_file)) {
    return(invisible(FALSE))
  }

  x <- read_csv(input_file, show_col_types = FALSE) |>
    filter(draws >= 100) |>
    mutate(
      Regime = recode(factor4_sbs, "universal" = "Universal", "sbs" = "SbS"),
      Behaviour = recode(factor5_behaviour,
        "mechanical" = "Mechanical",
        "behavioural" = "Behavioural"
      ),
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

  if (nrow(x) == 0) {
    return(invisible(FALSE))
  }

  write_latex_table(
    file.path(GENERATED_TABLES_DIR, "stage1_measurement_error_interval.tex"),
    caption = "Revenue interval from Stage 1 ETR measurement error",
    short_caption = "Stage 1 ETR measurement-error interval",
    col_spec = "llrrrrr",
    header = c(
      "Behaviour", "Regime", "Baseline (US\\$ bn)",
      "Median (US\\$ bn)", "5th pct.", "95th pct.", "90\\% width"
    ),
    rows = x,
    notes = "Intervals from Table I versus Table IV validation residuals; preferred scenario held fixed.",
  )

  invisible(TRUE)
}

build_country_revenue_diagnostic_rows <- function(countries) {
  spread <- read_diag("step7_stage4_6_scenario_spread_country.csv") |>
    filter(country %in% countries)

  fiscal <- read_diag("step7_stage4_6_fiscal_salience_country.csv") |>
    filter(country %in% countries) |>
    select(
      country,
      preferred_revenue,
      revenue_to_cit_1200,
      sbs_loss_to_cit_1200,
      qdmtt_preserved_share,
      cit_revenue_T_1200
    ) |>
    mutate(
      scenario_spread_to_cit_1200 = safe_divide(
        spread$scenario_spread[match(country, spread$country)],
        cit_revenue_T_1200
      )
    )

  spread |>
    dplyr::left_join(fiscal, by = "country") |>
    arrange(country_name) |>
    transmute(
      country_name,
      min_revenue,
      max_revenue,
      scenario_spread,
      preferred_revenue,
      revenue_to_cit_1200,
      scenario_spread_to_cit_1200,
      sbs_loss_to_cit_1200,
      qdmtt_preserved_share
    )
}

format_country_revenue_diagnostic_body <- function(rows) {
  vapply(seq_len(nrow(rows)), function(i) {
    r <- rows[i, ]
    paste0(
      latex_escape(r$country_name), " & ",
      fmt_bn(r$min_revenue, 1), " & ",
      fmt_bn(r$max_revenue, 1), " & ",
      fmt_bn(r$scenario_spread, 1), " & ",
      fmt_bn(r$preferred_revenue, 1), " & ",
      format_available_pct(r$revenue_to_cit_1200, 1), " & ",
      format_available_pct(r$scenario_spread_to_cit_1200, 1), " & ",
      format_available_pct(r$sbs_loss_to_cit_1200, 1), " & ",
      format_available_pct(r$qdmtt_preserved_share, 1),
      " \\\\"
    )
  }, character(1))
}

COUNTRY_REVENUE_DIAGNOSTIC_NOTES <- paste(
  "Cumulative 2017--2022; spread is min--max revenue across 32 scenarios (US\\$ bn);",
  "salience ratios use OECD T\\_1200 CIT where available.",
  "Cyprus, Estonia, Latvia, Lithuania and Malta are omitted because preferred",
  "behavioural SbS revenue is zero in every scenario."
)

COUNTRY_REVENUE_DIAGNOSTIC_HEADER <- c(
  " & \\multicolumn{3}{c}{Spread} & \\multicolumn{5}{c}{Salience} \\\\",
  "\\cmidrule(lr){2-4} \\cmidrule(lr){5-9}",
  "Country & Min & Max & Spread & Revenue & Rev./CIT & Spread/CIT & SbS/CIT & QDMTT \\\\"
)

write_country_revenue_diagnostic_table <- function(
  file,
  countries,
  caption,
  short_caption,
  label,
  extra_labels = character(),
  size = "\\scriptsize",
  tabcolsep = "2pt",
  fit_width = TRUE
) {
  rows <- build_country_revenue_diagnostic_rows(countries)
  body_lines <- format_country_revenue_diagnostic_body(rows)

  write_custom_table(
    file,
    assemble_inline_table(
      col_spec = "l rrr r rrrr",
      caption_lines = c(
        sprintf("\\caption[%s]{%s}", short_caption, caption),
        sprintf("\\label{%s}", label),
        sprintf("\\label{%s}", extra_labels)
      ),
      header_lines = COUNTRY_REVENUE_DIAGNOSTIC_HEADER,
      body_lines = body_lines,
      notes = COUNTRY_REVENUE_DIAGNOSTIC_NOTES,
      size = size,
      tabcolsep = tabcolsep,
      fit_width = fit_width
    )
  )
}

write_stage46_country_diagnostic_table <- function() {
  write_country_revenue_diagnostic_table(
    file = file.path(GENERATED_TABLES_DIR, "country_revenue_diagnostic.tex"),
    countries = COUNTRY_REVENUE_DIAGNOSTIC_COUNTRIES,
    short_caption = "Country revenue uncertainty and fiscal salience",
    caption = "Country revenue uncertainty and fiscal salience, EU Member States",
    label = "tab:country_revenue_diagnostic",
    extra_labels = c(
      "tab:country_spread_updated",
      "tab:country_fiscal_salience"
    )
  )
}

write_stage46_country_diagnostic_appendix_table <- function() {
  write_country_revenue_diagnostic_table(
    file = file.path(
      GENERATED_TABLES_DIR,
      "appendix_country_revenue_diagnostic.tex"
    ),
    countries = COUNTRY_REVENUE_DIAGNOSTIC_COUNTRIES,
    short_caption = "Country revenue uncertainty and fiscal salience, full EU sample",
    caption = "Country revenue uncertainty and fiscal salience, full EU sample (appendix replication of the main-text diagnostic)",
    label = "tab:app_country_revenue_diagnostic"
  )
}

format_available_pct <- function(x, digits = 1) {
  ifelse(is.na(x), "", paste0(fmt_pct(x, digits), "\\%"))
}

fmt_pct_compact <- function(x, digits = 1) {
  trimws(fmt_pct(x, digits))
}

format_imputation_reliance <- function(x) {
  label <- case_when(
    is.na(x) ~ "",
    x >= 0.50 ~ "Heavy",
    x >= 0.25 ~ "Moderate",
    x > 0 ~ "Limited",
    TRUE ~ "None"
  )
  ifelse(is.na(x), "", paste0(label, " (", fmt_pct_compact(x, 1), "\\%)"))
}


write_stage46_measurement_sample_table <- function() {
  samples <- read_diag("step7_stage4_6_measurement_sample_summary.csv") |>
    transmute(
      Sample = latex_escape(sample_label),
      `ETR` = format_available_pct(etr_measurement_allocated_eta, 1),
      `SbS` = format_available_pct(sbs_regime_allocated_eta, 1),
      `Substance` =
        format_available_pct(substance_specification_allocated_eta, 1),
      `Behaviour` =
        format_available_pct(behavioural_response_allocated_eta, 1),
      `Interaction` = format_available_pct(interaction_eta, 1),
      `Preferred revenue` = fmt_bn(preferred_behavioural_sbs_revenue, 1),
      `Scenario range` = paste0(
        fmt_bn(eu_revenue_min, 1),
        "--",
        fmt_bn(eu_revenue_max, 1)
      )
    )

  write_latex_table(
    file.path(GENERATED_TABLES_DIR, "stage46_measurement_sample_decomposition.tex"),
    caption = "Decomposition stability across higher-measurement windows",
    short_caption = "Decomposition stability across higher-measurement windows",
    col_spec = "L{3.7cm}rrrrrrr",
    header = c(
      "Sample", "ETR", "SbS", "Substance", "Behaviour",
      "Interaction", "Preferred revenue", "Scenario range"
    ),
    rows = samples,
    notes = paste(
      "ETR, SbS, substance and behaviour columns report Shapley-style allocated shares of the pooled 32-scenario variance.",
      "Interaction reports the unallocated ANOVA interaction share before Shapley redistribution.",
      "Preferred revenue is cumulative behavioural preferred-core SbS EU revenue in US dollars, billions.",
      "Scenario range reports the minimum and maximum cumulative EU revenue across the 32 scenarios in US dollars, billions.",
      ""
    ),
    size = "\\footnotesize"
  )

  appendix_samples <- read_diag("step7_stage4_6_measurement_sample_summary.csv") |>
    transmute(
      Sample = latex_escape(sample_label),
      `ETR main` = format_available_pct(etr_measurement_eta, 1),
      `SbS main` = format_available_pct(sbs_regime_eta, 1),
      `Substance main` = format_available_pct(substance_specification_eta, 1),
      `Behaviour main` = format_available_pct(behavioural_response_eta, 1),
      `Interaction` = format_available_pct(interaction_eta, 1),
      `Direct Table IV` = format_available_pct(direct_t4_lowtax_share, 1),
      `High-risk branch` = format_available_pct(high_risk_imputation_share, 1),
      `Overlap cells` = fmt_int(overlap_affiliate_years)
    )

  write_latex_table(
    file.path(GENERATED_TABLES_DIR, "appendix_stage46_measurement_sample_decomposition.tex"),
    caption = "Decomposition-window robustness diagnostics",
    short_caption = "Decomposition-window robustness diagnostics",
    col_spec = "L{3.7cm}rrrrrrrr",
    header = c(
      "Sample", "ETR main", "SbS main", "Subst. main",
      "Behav. main", "Interaction", "Direct T. IV",
      "Hi-risk branch", "Overlap"
    ),
    rows = appendix_samples,
    notes = paste(
      "Main columns report raw main-effect shares of the pooled 32-scenario ANOVA.",
      "Interaction is the aggregate share of all non-main effects.",
      "Direct Table IV and high-risk branch columns report EU affiliate low-taxed profit shares in the Stage 1 distributional branch.",
      "Overlap cells are affiliate-year validation cells with both percentile and direct Table IV support.",
      ""
    ),
    size = "\\scriptsize",
    tabcolsep = "2pt",
    fit_width = TRUE
  )
}

write_country_typology_tables <- function() {
  pca <- read_diag("step7_stage4_6_country_typology_pca_summary.csv") |>
    filter(component %in% c("PC1", "PC2", "PC3")) |>
    transmute(
      Component = latex_escape(component),
      `Variance` = format_available_pct(variance_share, 1),
      `Cumulative` = format_available_pct(cumulative_share, 1),
      `Dominant dimension` = latex_escape(interpreted_dimension),
      `Largest loadings` =
        latex_escape(format_typology_feature_list(top_features))
    )

  write_latex_table(
    file.path(GENERATED_TABLES_DIR, "country_typology_pca.tex"),
    caption = "PCA of the country typology feature matrix",
    short_caption = "PCA of the country typology feature matrix",
    col_spec = "lrrL{3.0cm}L{6.0cm}",
    header = c(
      "Component", "Variance", "Cumulative",
      "Dominant dimension", "Largest loadings"
    ),
    rows = pca,
    notes = paste(
      "The PCA is run on standardised country-level features.",
      "Revenue amounts, scenario spread and per-resident revenue enter in logs; signed main-effect amounts enter as signed log magnitudes.",
      "Cyprus' missing OECD T\\_1200 corporate-tax denominator and undefined channel shares for the four zero-revenue countries are median-imputed only for PCA scaling.",
      ""
    ),
    size = "\\footnotesize"
  )

  profiles <- read_diag("step7_stage4_6_country_typology_cluster_profiles.csv")
  stability <- read_diag("step7_stage4_6_country_typology_cluster_stability.csv")
  selected_stability <- stability |>
    filter(selected) |>
    slice_head(n = 1)

  profile_rows <- profiles |>
    transmute(
      Type = latex_escape(typology_id),
      Countries = latex_escape(countries),
      `n` = fmt_int(n_countries),
      `Rev.` = fmt_bn(preferred_revenue, 1),
      `Rev./CIT` = format_available_pct(mean_revenue_to_cit_1200, 1),
      `QDMTT` = format_available_pct(mean_qdmtt_share, 1),
      `Res.` = format_available_pct(mean_residual_iir_utpr_exposure, 1),
      `SbS ext.` = format_available_pct(mean_sbs_extinguished_share, 1),
      `Imp.` = format_available_pct(mean_high_risk_imputation_share, 1)
    )

  write_latex_table(
    file.path(GENERATED_TABLES_DIR, "country_typology_clusters.tex"),
    caption = "Policy-facing country typology from PCA-informed clustering",
    short_caption = "Policy-facing country typology",
    col_spec = "L{0.85cm}L{3.35cm}rrrrrrr",
    header = c(
      "Type", "Countries", "$n$", "Rev.", "Rev./CIT",
      "QDMTT", "Res.", "SbS ext.", "Imp."
    ),
    rows = profile_rows,
    notes = paste(
      "Four clusters are selected because the jitter stability score is",
      paste0(fmt_pct(selected_stability$stability_score, 1), "\\%,"),
      "the smallest cluster contains one country, and the four-cluster solution separates conduit hubs (T1), QDMTT-protected smaller states (T2), residual IIR/UTPR exposure states (T3) and states with latent exposure masked by sparse CbCR data (T4).",
      "Rev.\\ is preferred behavioural SbS revenue in US dollars, billions.",
      "For T4, zero Rev.\\ and missing channel shares reflect sparse CbCR coverage rather than absent exposure.",
      "Rev./CIT uses OECD T\\_1200 where available; cluster means ignore missing denominators.",
      "Res.\\ is residual IIR/UTPR exposure; SbS ext.\\ is the share of CIT revenue extinguished under the SbS regime; Imp.\\ is the high-risk imputation share.",
      ""
    ),
    size = "\\scriptsize",
    tabcolsep = "2pt",
    fit_width = TRUE
  )

  feature_rows <- read_diag(
    "step7_stage4_6_country_typology_feature_matrix.csv"
  ) |>
    left_join(
      read_diag("step7_stage4_6_country_typology_clusters.csv") |>
        select(country, typology_id),
      by = "country"
    ) |>
    arrange(typology_id, country_name) |>
    transmute(
      Type = latex_escape(typology_id),
      Country = latex_escape(country_name),
      `Revenue` = fmt_bn(preferred_revenue, 1),
      `Spread` = fmt_bn(scenario_spread, 1),
      `Revenue/CIT` = format_available_pct(revenue_to_cit_1200, 1),
      `ETR effect` = fmt_bn(etr_measurement_main_effect, 1),
      `SbS effect` = fmt_bn(sbs_regime_main_effect, 1),
      `QDMTT` = format_available_pct(qdmtt_share, 1),
      `Residual` = format_available_pct(residual_iir_utpr_exposure, 1),
      `Imputation risk` = format_available_pct(high_risk_imputation_share, 1)
    )

  write_appendix_latex_table(
    file.path(GENERATED_TABLES_DIR, "appendix_country_typology_features.tex"),
    "Country typology feature matrix, full EU sample",
    "tab:app_country_typology_features",
    "llrrrrrrrr",
    c(
      "Type", "Country", "Revenue", "Spread", "Revenue/CIT",
      "ETR effect", "SbS effect", "QDMTT", "Residual",
      "Imputation risk"
    ),
    feature_rows,
    paste(
      "Revenue, spread and main-effect columns are cumulative over 2017 to 2022 and expressed in US dollars, billions.",
      "Main effects are signed into policy-exposure magnitudes: distributional minus average ETR measurement, universal minus SbS revenue loss, aggregate minus sectoral substance exposure and mechanical minus behavioural revenue.",
      ""
    )
  )

  stability_rows <- stability |>
    transmute(
      `k` = fmt_int(k),
      `Stability` = format_available_pct(stability_score, 1),
      `Minimum` = format_available_pct(stability_min, 1),
      `Smallest cluster` = fmt_int(min_cluster_size),
      `Cluster sizes` = latex_escape(cluster_sizes),
      `Selected` = fmt_bool(selected)
    )

  write_appendix_latex_table(
    file.path(GENERATED_TABLES_DIR, "appendix_country_typology_cluster_stability.tex"),
    "Cluster stability diagnostics for the country typology",
    "tab:app_country_typology_cluster_stability",
    "rrrrlr",
    c(
      "k", "Stability", "Minimum", "Smallest cluster",
      "Cluster sizes", "Selected"
    ),
    stability_rows,
    paste(
      "Stability is the mean country-pair co-assignment agreement after 200 small jitter perturbations of the standardised feature matrix.",
      "The selected four-cluster solution is chosen by stability and interpretability, not by a mechanical elbow rule.",
      ""
    )
  )
}

write_hypothesis_summary_table <- function() {
  h <- read_processed("stage4_6_hypothesis_summary.rds")
  anova <- read_diag("step7_stage4_6_anova_pooled.csv")
  stage46_summary <- read_diag("step7_stage4_6_summary.csv")
  model <- read_diag("step5_stage3_model_comparison.csv") |> arrange(bic_rank)
  semi <- read_diag("step5_stage3_semielasticity_schedule.csv") |>
    filter(
      model_spec == "logarithmic", inference == "parent_affiliate_clustered",
      tau == 0.05
    )
  pca <- read_diag("step7_stage4_6_country_typology_pca_summary.csv") |>
    filter(component == "PC1")
  stability <- read_diag("step7_stage4_6_country_typology_cluster_stability.csv") |>
    filter(selected) |>
    slice_head(n = 1)

  h4_model <- str_to_sentence(model$model_spec[1])
  h4_log <- fmt_num(semi$semi_elasticity[1], 2)
  h2_share <- fmt_pct(as.numeric(metric_value(h, "largest_main_effect_eta_squared")), 1)
  h3_share <- fmt_pct(
    anova$eta_squared[anova$effect == "x4_sbs" &
      anova$interaction_order == 1L][1],
    1
  )
  h3_sbs_loss <- (
    as.numeric(metric_value(stage46_summary, "preferred_universal_revenue")) -
      as.numeric(metric_value(stage46_summary, "preferred_sbs_revenue"))
  ) / 1e9
  h5_pca_share <- fmt_pct(pca$variance_share[1], 1)
  h5_stability <- fmt_pct(stability$stability_score[1], 1)

  rows <- tibble(
    Hypothesis = latex_escape(c("H1", "H2", "H3", "H4", "H5")),
    `Main result` = c(
      "The distributional branch raises the EU27 Stage 1 liability rate relative to the jurisdiction-average rule in every year from 2017 to 2022.",
      paste0(
        "ETR measurement explains ", h2_share,
        "\\% of pooled scenario variance."
      ),
      paste0(
        "The SbS regime explains ", h3_share,
        "\\% of pooled scenario variance and reduces preferred-core EU revenue by US\\$",
        fmt_num(h3_sbs_loss, 1), " bn through the UTPR channel."
      ),
      paste0(
        "Tax terms are jointly significant; baseline BIC selects ",
        latex_escape(h4_model), "; logarithmic 5\\% semi-elasticity is ",
        h4_log, "."
      ),
      paste0(
        "PC1 explains ", h5_pca_share,
        "\\% of typology variation and the selected four-cluster solution has ",
        h5_stability, "\\% jitter stability."
      )
    ),
    Interpretation = latex_escape(c(
      "Supported.",
      "Supported.",
      "Supported. SbS is the second-largest variance source and materially changes collection channels.",
      "Supported in its cautious form: the panel supports a negative tax-profit relationship, but not a sharply nonlinear lower-tail specification.",
      "Supported. Member States separate into high-salience conduit hubs, QDMTT-protected smaller exposures, residual IIR/UTPR exposure states and states whose exposure is masked by sparse CbCR data."
    ))
  )

  write_latex_table(
    file.path(GENERATED_TABLES_DIR, "hypothesis_summary.tex"),
    caption = "Hypothesis summary",
    short_caption = "Hypothesis summary",
    col_spec = "L{1.7cm}L{7.1cm}L{4.8cm}",
    header = c("Hypothesis", "Main result", "Interpretation"),
    rows = rows,
    notes = paste(
      "The table summarises the evidence reported in the Stage 1 to Stage 4.6 diagnostics and the country fiscal-exposure calculations in Section \\ref{sec:results_sbs}.",
      ""
    )
  )
}

write_appendix_tables <- function() {
  dir.create(GENERATED_DIR, showWarnings = FALSE, recursive = TRUE)

  evidence_summary <- read_diag("step02a_profit_correction_evidence_summary.csv") |>
    mutate(
      evidence_label = recode(
        signal_type,
        "observed_adjusted_profit" = "Observed adjusted profit",
        "observed_adjusted_profit_parent" = "Observed adjusted profit, parent average",
        "macro_reconciliation" = "Macro reconciliation anchor",
        "official_country_note" = "Official country-note anchor",
        "public_etr_parity" = "Public ETR-parity signal",
        "fallback_prior" = "Fallback prior",
        .default = str_to_sentence(str_replace_all(signal_type, "_", " "))
      ),
      scope_label = str_to_sentence(str_replace_all(scope, "_", " "))
    ) |>
    transmute(
      Evidence = latex_escape(evidence_label),
      Source = latex_escape(source_citation_key),
      Scope = latex_escape(scope_label),
      Rows = fmt_int(rows),
      Parents = fmt_int(parents),
      `Profit weight (US$ bn)` = fmt_bn(profit_weight_total, 1),
      `Weighted $\\rho$ (\\%)` = fmt_pct(weighted_rho, 1),
      `Median $\\rho$ (\\%)` = fmt_pct(median_rho, 1),
      `Mean SE` = fmt_num(mean_source_se, 3)
    )

  write_appendix_latex_table(
    file.path(GENERATED_TABLES_DIR, "profit_correction_evidence_table.tex"),
    "Evidence hierarchy for the profit-reconciliation model",
    "tab:profit_correction_evidence_table",
    "L{2.8cm}L{1.8cm}L{3.4cm}rrrrrr",
    c(
      "Evidence", "Source", "Scope", "Rows", "Parents",
      "Profit (US\\$ bn)", "$\\rho$ (\\%)", "Median (\\%)", "SE"
    ),
    evidence_summary,
    paste(
      "Each row summarises one type of signal entering the parent-year correction model.",
      "The fallback prior is the Hugger et al. median UPE correction; the public ETR-parity signal is capped at 55.5\\% and enters with low precision.",
      ""
    )
  )

  parent_year_top20 <- read_diag("step02a_profit_correction_parent_year_top20.csv") |>
    transmute(
      Parent = latex_escape(parent),
      Years = fmt_int(years),
      `Domestic profit (US$ bn)` = fmt_bn(domestic_profit, 1),
      `$\\hat{\\rho}$ (\\%)` = fmt_pct(rho_hat, 1),
      `Low (\\%)` = fmt_pct(rho_lo, 1),
      `High (\\%)` = fmt_pct(rho_hi, 1),
      `Main source` = latex_escape(main_sources),
      Support = latex_escape(support_class)
    )

  write_appendix_latex_table(
    file.path(GENERATED_TABLES_DIR, "profit_correction_parent_year_top20.tex"),
    "Largest parent-level profit corrections under the hybrid model",
    "tab:profit_correction_parent_year_top20",
    "lrrrrrL{3.0cm}L{2.7cm}",
    c(
      "Parent", "Years", "Profit (US\\$ bn)", "$\\hat{\\rho}$ (\\%)",
      "Low (\\%)", "High (\\%)", "Main source", "Support"
    ),
    parent_year_top20,
    paste(
      "Rows are the twenty parent jurisdictions with the largest positive domestic profit over 2017 to 2022.",
      "Rates are domestic-profit-weighted averages of parent-year predictions.",
      ""
    )
  )

  holdout_summary <- read_diag("step02a_profit_correction_validation_holdout.csv") |>
    group_by(signal_type) |>
    summarise(
      rows = n(),
      weighted_error = weighted_mean_available(error, pmax(profit_weight, 1)),
      weighted_abs_error =
        weighted_mean_available(abs_error, pmax(profit_weight, 1)),
      median_abs_error = median(abs_error, na.rm = TRUE),
      max_abs_error = max(abs_error, na.rm = TRUE),
      profit_weight_total = sum(profit_weight, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(
      signal_label = recode(
        signal_type,
        "observed_adjusted_profit" = "Observed adjusted profit",
        "macro_reconciliation" = "Macro reconciliation",
        "official_country_note" = "Official country note",
        .default = str_to_sentence(str_replace_all(signal_type, "_", " "))
      )
    ) |>
    transmute(
      Evidence = latex_escape(signal_label),
      Rows = fmt_int(rows),
      `Profit weight (US$ bn)` = fmt_bn(profit_weight_total, 1),
      `Mean error (pp)` = fmt_num(100 * weighted_error, 1),
      `Mean abs. error (pp)` = fmt_num(100 * weighted_abs_error, 1),
      `Median abs. error (pp)` = fmt_num(100 * median_abs_error, 1),
      `Max abs. error (pp)` = fmt_num(100 * max_abs_error, 1)
    )

  write_appendix_latex_table(
    file.path(GENERATED_TABLES_DIR, "profit_correction_validation_holdout.tex"),
    "Holdout validation for high-credibility profit-correction signals",
    "tab:profit_correction_validation_holdout",
    "lrrrrrr",
    c(
      "Evidence", "Rows", "Profit (US\\$ bn)", "Mean error",
      "Mean abs.", "Median abs.", "Max abs."
    ),
    holdout_summary,
    paste(
      "Each high-credibility signal is held out from the prior fit one source-parent-year at a time and compared with the model prediction.",
      "Errors are reported in percentage points of the correction share.",
      ""
    )
  )

  revenue_point <- read_diag("step02a_profit_correction_revenue_sensitivity.csv") |>
    mutate(
      specification = recode(
        specification,
        "profit_uncorrected" = "Uncorrected profit",
        "profit_low_correction" = "Low correction",
        "profit_preferred" = "Preferred correction",
        "profit_high_correction" = "High correction",
        .default = specification
      )
    ) |>
    transmute(
      Specification = latex_escape(specification),
      `Positive profit (US$ bn)` = fmt_bn(positive_profit, 1),
      `Global top-up proxy (US$ bn)` = fmt_bn(mechanical_pre_sbie_topup, 1),
      `EU27 top-up proxy (US$ bn)` = fmt_bn(eu27_mechanical_pre_sbie_topup, 1)
    )

  final_point_path <- file.path(
    DIAGNOSTICS_DIR,
    "step07a_profit_correction_final_revenue_points.csv"
  )
  final_point <- if (file.exists(final_point_path)) {
    read_csv(final_point_path, show_col_types = FALSE) |>
      filter(factor4_sbs == "sbs") |>
      mutate(
        specification = recode(
          specification,
          "uncorrected" = "Uncorrected profit",
          "low_correction" = "Low correction",
          "preferred_correction" = "Preferred correction",
          "high_correction" = "High correction",
          .default = specification
        )
      ) |>
      transmute(
        Specification = latex_escape(specification),
        `EU27 final SbS (US$ bn)` = fmt_bn(eu27_final_revenue, 1)
      )
  } else {
    tibble(
      Specification = revenue_point$Specification,
      `EU27 final SbS (US$ bn)` = NA_character_
    )
  }

  revenue_point <- revenue_point |>
    left_join(final_point, by = "Specification")

  revenue_draw <- read_diag("step02a_profit_correction_revenue_draw_interval.csv") |>
    transmute(
      Specification = "500 $\\rho_{pt}$ draws",
      `Positive profit (US$ bn)` = paste0(
        fmt_bn(positive_profit_mean, 1), " [",
        fmt_bn(positive_profit_p025, 1), ", ",
        fmt_bn(positive_profit_p975, 1), "]"
      ),
      `Global top-up proxy (US$ bn)` = paste0(
        fmt_bn(mechanical_topup_mean, 1), " [",
        fmt_bn(mechanical_topup_p025, 1), ", ",
        fmt_bn(mechanical_topup_p975, 1), "]"
      ),
      `EU27 top-up proxy (US$ bn)` = paste0(
        fmt_bn(eu27_mechanical_topup_mean, 1), " [",
        fmt_bn(eu27_mechanical_topup_p025, 1), ", ",
        fmt_bn(eu27_mechanical_topup_p975, 1), "]"
      )
    )

  final_draw_path <- file.path(
    DIAGNOSTICS_DIR,
    "step07a_profit_correction_final_revenue_interval.csv"
  )
  revenue_draw <- if (file.exists(final_draw_path)) {
    final_draw <- read_csv(final_draw_path, show_col_types = FALSE) |>
      filter(factor4_sbs == "sbs") |>
      slice_head(n = 1) |>
      transmute(
        Specification = "500 $\\rho_{pt}$ draws",
        `EU27 final SbS (US$ bn)` = paste0(
          fmt_bn(eu27_revenue_mean, 1), " [",
          fmt_bn(eu27_revenue_p025, 1), ", ",
          fmt_bn(eu27_revenue_p975, 1), "]"
        )
      )

    revenue_draw |>
      left_join(final_draw, by = "Specification")
  } else {
    revenue_draw |>
      mutate(`EU27 final SbS (US$ bn)` = NA_character_)
  }

  write_appendix_latex_table(
    file.path(GENERATED_TABLES_DIR, "profit_correction_revenue_sensitivity.tex"),
    "Profit-correction uncertainty and preferred-scenario revenue",
    "tab:profit_correction_revenue_sensitivity",
    "lrrrr",
    c(
      "Specification", "Positive profit", "Global top-up proxy",
      "EU27 top-up proxy", "EU27 final SbS"
    ),
    bind_rows(revenue_point, revenue_draw),
    paste(
      "The top-up proxy is pre-SBIE and pre-allocation: $\\max\\{0,0.15-\\tau\\}\\pi$ using the drawn corrected denominator.",
      "The final SbS column propagates the same parent-year draws through the preferred behavioural Stage 4.6 panel while holding distributional low-tax shares, behavioural filters and legal allocation weights fixed.",
      "It is therefore a conditional profit-correction interval, reported separately from the main factorial revenue decomposition.",
      ""
    )
  )

  holding_chain_path <- file.path(
    DIAGNOSTICS_DIR,
    "step07a_profit_correction_foreign_holding_chain.csv"
  )
  if (file.exists(holding_chain_path) && file.exists(final_point_path)) {
    holding_chain <- read_csv(holding_chain_path, show_col_types = FALSE)
    holding_points <- read_csv(final_point_path, show_col_types = FALSE) |>
      filter(
        factor4_sbs == "sbs",
        specification %in% c(
          "preferred_correction",
          "foreign_holding_chain_correction"
        )
      ) |>
      select(
        specification, positive_profit, global_allocated_revenue,
        eu27_final_revenue
      )

    preferred_point <- holding_points |>
      filter(specification == "preferred_correction") |>
      slice_head(n = 1)
    holding_point <- holding_points |>
      filter(specification == "foreign_holding_chain_correction") |>
      slice_head(n = 1)

    holding_rows <- tibble(
      Row = c(
        "Flagged foreign holding-chain cells",
        "Preferred domestic-only correction",
        "Foreign holding-chain sensitivity",
        "Movement relative to preferred"
      ),
      Cells = c(fmt_int(holding_chain$flagged_cells), "", "", ""),
      Parents = c(fmt_int(holding_chain$flagged_parents), "", "", ""),
      `Profit or reduction (US$ bn)` = c(
        fmt_bn(holding_chain$flagged_profit, 1),
        fmt_bn(preferred_point$positive_profit, 1),
        fmt_bn(holding_point$positive_profit, 1),
        fmt_bn(
          holding_point$positive_profit - preferred_point$positive_profit,
          1
        )
      ),
      `Global allocated revenue (US$ bn)` = c(
        "",
        fmt_bn(preferred_point$global_allocated_revenue, 1),
        fmt_bn(holding_point$global_allocated_revenue, 1),
        fmt_bn(holding_point$global_allocated_revenue -
          preferred_point$global_allocated_revenue, 1)
      ),
      `EU27 final SbS (US$ bn)` = c(
        "",
        fmt_bn(preferred_point$eu27_final_revenue, 1),
        fmt_bn(holding_point$eu27_final_revenue, 1),
        fmt_bn(holding_point$eu27_final_revenue -
          preferred_point$eu27_final_revenue, 1)
      )
    ) |>
      mutate(Row = latex_escape(Row))

    write_appendix_latex_table(
      file.path(
        GENERATED_TABLES_DIR,
        "profit_correction_foreign_holding_chain_sensitivity.tex"
      ),
      "Targeted foreign holding-chain profit-correction sensitivity",
      "tab:profit_correction_foreign_holding_chain",
      "lrrrrr",
      c(
        "Object", "Cells", "Parents", "Profit", "Global revenue",
        "EU27 final SbS"
      ),
      holding_rows,
      paste(
        "The sensitivity applies a 10\\% residual profit haircut only to foreign affiliate cells in the Netherlands, Luxembourg, Ireland, Switzerland, Singapore, Hong Kong, Bermuda or the Cayman Islands with positive preferred profit, high holding activity, high related-party revenue and low substance relative to profit.",
        "It is not part of the preferred correction because public aggregate CbCR cannot identify ownership-chain dividends in foreign affiliate cells.",
        ""
      )
    )
  }

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
    file.path(GENERATED_TABLES_DIR, "appendix_stage1_bspi_summary.tex"),
    "BSPI total-variation summary",
    "tab:app_stage1_bspi_tv",
    "lrrrrrr",
    c("Scope", "Affiliates", "High-TV flagged", "Median", "P75", "P90", "Maximum"),
    bspi_summary,
    ""
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
    file.path(GENERATED_TABLES_DIR, "appendix_stage1_conditioning.tex"),
    "Stage 1 percentile and Beta-fit diagnostics",
    "tab:app_stage1_conditioning",
    "lrrrrrr",
    c(
      "Year", "Affiliate-years", "Non-monotone raw", "Out of support",
      "Conditioned", "Mean beta fit MAE", "Max beta fit error"
    ),
    conditioning,
    ""
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
    file.path(GENERATED_TABLES_DIR, "appendix_stage2_payroll_fallback.tex"),
    "Stage 2 payroll fallback diagnostics",
    "tab:app_stage2_payroll_fallback",
    "lrrrr",
    c(
      "Year", "Pair-years", "Fallback rows",
      "Positive profit in fallback rows (US\\$ bn)",
      "Fallback share of Stage 1 top-up (\\%)"
    ),
    payroll,
    ""
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
    file.path(GENERATED_TABLES_DIR, "appendix_stage2_asset_sensitivity.tex"),
    "Stage 2 sectoral asset sensitivity",
    "tab:app_stage2_asset_sensitivity",
    "llrrrr",
    c(
      "Rate scenario", "Asset sensitivity", "Asset scale",
      "Weighted phi (\\%)", "Average floor (\\%)", "Distributional floor (\\%)"
    ),
    asset_sensitivity,
    ""
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
    file.path(GENERATED_TABLES_DIR, "appendix_stage3_sample_summary.tex"),
    "Stage 3 estimation-sample diagnostics",
    "tab:app_stage3_sample_summary",
    "lrrrrrrr",
    c(
      "Sample", "Rows", "Pairs", "Affiliates", "Parents",
      "Median pair-years", "Median ETR (\\%)", "Stale-wage rows"
    ),
    sample_summary,
    ""
  )

  coefficients <- read_diag("step5_stage3_coefficients.csv") |>
    filter(
      inference == "parent_affiliate_clustered",
      term %in% c("tau", "tau_sq", "log_tau")
    ) |>
    mutate(
      term = recode(term,
        "tau" = "ETR", "tau_sq" = "ETR squared",
        "log_tau" = "Log shifted ETR"
      )
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
    file.path(GENERATED_TABLES_DIR, "appendix_stage3_tax_coefficients.tex"),
    "Stage 3 tax coefficients",
    "tab:app_stage3_tax_coefficients",
    "llrrrr",
    c("Model", "Term", "Estimate", "SE", "$p$-value", "Within $R^2$"),
    coefficients,
    paste(
      "Inference is two-way clustered by parent and affiliate.",
      ""
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
    file.path(GENERATED_TABLES_DIR, "appendix_stage3_specification_tests.tex"),
    "Stage 3 non-nested specification tests",
    "tab:app_stage3_specification_tests",
    "lllrrL{4.2cm}",
    c("Test", "Model A", "Model B", "Statistic", "$p$-value", "Interpretation"),
    spec_tests,
    ""
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
    file.path(GENERATED_TABLES_DIR, "appendix_stage3_wald_tests.tex"),
    "Stage 3 joint tax-term Wald tests",
    "tab:app_stage3_wald_tests",
    "llrrrrr",
    c(
      "Model", "Tax terms", "df num.", "df den.", "$F$-statistic",
      "$p$-value", "Within $R^2$"
    ),
    wald_tests,
    paste(
      "Inference is two-way clustered by parent and affiliate.",
      ""
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
    file.path(GENERATED_TABLES_DIR, "appendix_stage3_robustness.tex"),
    "Stage 3 model-selection robustness",
    "tab:app_stage3_robustness",
    "llrrrrr",
    c(
      "Sample", "Model", "$N$", "Within $R^2$", "BIC rank",
      "$\\Delta$BIC", "Tax Wald $p$"
    ),
    robustness,
    ""
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
    file.path(GENERATED_TABLES_DIR, "appendix_stage3_etr_tail_support.tex"),
    "Stage 3 lower-tail ETR support",
    "tab:app_stage3_etr_tail_support",
    "lrrrrrrr",
    c(
      "ETR band", "Rows", "Row share (\\%)", "Profit share (\\%)",
      "Pairs", "Affiliates", "Parents", "Median ETR (\\%)"
    ),
    tail_support,
    paste(
      "The table reports the support for the behavioural ETR regressor after winsorisation in the baseline fixed-effect estimation sample.",
      "An illustrative tail-balanced design that forces the below-5\\% band to 50\\% of weighted rows would use a tail multiplier of",
      fmt_num(tail_value("tail_balance_tail_weight"), 2),
      "and a non-tail multiplier of",
      fmt_num(tail_value("tail_balance_non_tail_weight"), 2),
      "with effective N equal to",
      fmt_int(tail_value("tail_balance_effective_n")),
      paste0(
        "and a design effect of ",
        fmt_num(tail_value("tail_balance_design_effect"), 2), "."
      ),
      "This is a support diagnostic, not an inverse-probability-weighted estimator.",
      ""
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
    file.path(GENERATED_TABLES_DIR, "appendix_stage3_behaviour_by_year.tex"),
    "Stage 3 applied behavioural response by year",
    "tab:app_stage3_behaviour_by_year",
    "lrrrrrr",
    c(
      "Year", "Aff.-years", "EU27 aff.-years", "Mean $\\beta$ (\\%)",
      "Profit-wtd $\\beta$ (\\%)", "Bunching aff.-years",
      "Realloc. aff.-years"
    ),
    behaviour,
    "",
    tabcolsep = "2pt",
    fit_width = TRUE
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
    file.path(GENERATED_TABLES_DIR, "appendix_stage3_behavioural_design.tex"),
    "Stage 3 behavioural identification design",
    "tab:app_stage3_behavioural_design",
    "L{2.7cm}L{4.1cm}L{3.7cm}L{5.1cm}",
    c(
      "Component", "Baseline treatment", "Identification status",
      "Data for structural extension"
    ),
    behavioural_design,
    ""
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
    transmute(
      Metric = latex_escape(str_to_sentence(metric)),
      Value = value_fmt
    )

  write_appendix_latex_table(
    file.path(GENERATED_TABLES_DIR, "appendix_stage45_summary.tex"),
    "Stage 4.5 allocation summary",
    "tab:app_stage45_summary",
    "lr",
    c("Metric", "Value"),
    stage45_summary,
    ""
  )

  source_exposure <- read_diag("step6_stage4_5_sbs_source_exposure.csv") |>
    filter(
      factor1_etr == "distributional",
      factor2_substance == "aggregate_sbie",
      factor3_rates == "initial",
      factor5_behaviour == "mechanical",
      factor4_sbs == "sbs",
      source_country %in% SELECTED_COUNTRIES
    ) |>
    group_by(source_country_name, source_qdmtt) |>
    summarise(
      total_topup = sum(total_topup_after_behaviour, na.rm = TRUE),
      us_topup = sum(us_parented_topup, na.rm = TRUE),
      extinguished = sum(us_parented_extinguished_topup, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(match(
      source_country_name,
      c("Netherlands", "Ireland", "Luxembourg", "Germany", "France")
    )) |>
    transmute(
      `Source country` = latex_escape(source_country_name),
      QDMTT = fmt_bool(source_qdmtt),
      `Total top-up (US$ bn)` = fmt_bn(total_topup, 1),
      `US-parented top-up (US$ bn)` = fmt_bn(us_topup, 1),
      `Extinguished (US$ bn)` = fmt_bn(extinguished, 1)
    )

  write_appendix_latex_table(
    file.path(GENERATED_TABLES_DIR, "appendix_stage45_sbs_source_exposure.tex"),
    "Selected source-country SbS exposure",
    "tab:app_stage45_sbs_source_exposure",
    "lrrrr",
    c(
      "Source country", "QDMTT", "Total top-up (US\\$ bn)",
      "US-parented top-up (US\\$ bn)", "Extinguished (US\\$ bn)"
    ),
    source_exposure,
    paste(
      "Preferred-core source exposure before final collector-country allocation.",
      ""
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
    file.path(GENERATED_TABLES_DIR, "appendix_stage45_h4_regression.tex"),
    "Country-level Side-by-Side allocation regression",
    "tab:app_stage45_h4_regression",
    "lrrrrr",
    c("Term", "Estimate", "SE", "Statistic", "$p$-value", "$R^2$"),
    h4_reg,
    ""
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
    file.path(GENERATED_TABLES_DIR, "appendix_stage46_top_scenarios.tex"),
    "Highest EU revenue scenarios",
    "tab:app_stage46_top_scenarios",
    "llllllr",
    c(
      "Scenario", "ETR", "Substance", "Rates", "Regime", "Behaviour",
      "EU revenue (US\\$ bn)"
    ),
    scenario_summary,
    ""
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
    file.path(GENERATED_TABLES_DIR, "appendix_stage46_country_anova.tex"),
    "Largest country-level main effects",
    "tab:app_stage46_country_anova",
    "llr",
    c("Country", "Effect", "Share (\\%)"),
    anova_country,
    ""
  )

  influence_appendix_inputs <- character()
  influence_summary_path <- file.path(
    DIAGNOSTICS_DIR,
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
      file.path(GENERATED_TABLES_DIR, "appendix_jurisdiction_influence_summary.tex"),
      "Leave-one-jurisdiction influence robustness",
      "tab:app_jurisdiction_influence_summary",
      "lL{2.5cm}lrrrrl",
      c(
        "Drop", "Jurisdiction", "Reason", "Profit share (\\%)",
        "Semi-elast.", "Stage 1 chg (pp)",
        "Pref. rev. chg (\\%)", "Largest eff."
      ),
      influence,
      paste(
        "Rows are sorted by the absolute change in preferred-core behavioural SbS EU revenue.",
        "The preferred core uses distributional ETR measurement, aggregate SBIE and initial carve-out rates.",
        ""
      ),
      size = "\\scriptsize",
      tabcolsep = "2pt",
      fit_width = TRUE
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
      file.path(GENERATED_TABLES_DIR, "appendix_jurisdiction_influence_decomposition.tex"),
      "Influence range for core decomposition effects",
      "tab:app_jurisdiction_influence_decomposition",
      "lrrrrrr",
      c(
        "Effect", "Baseline (\\%)", "Min (\\%)",
        "Max (\\%)", "Baseline effect", "Min effect",
        "Max effect"
      ),
      influence_range,
      paste(
        "Variance-decomposition shares and main effects are recomputed after each leave-one-parent and leave-one-affiliate omission.",
        "Main effects are cumulative over 2017 to 2022 and expressed in US dollars, billions.",
        ""
      ),
      tabcolsep = "2pt",
      fit_width = TRUE
    )

    influence_appendix_inputs <- c(
      "\\input{generated/results_tables/appendix_jurisdiction_influence_summary.tex}",
      "\\input{generated/results_tables/appendix_jurisdiction_influence_decomposition.tex}"
    )
  }

  profit_reconciliation_inputs <- c(
    "\\input{generated/results_tables/profit_correction_evidence_table.tex}",
    "\\input{generated/results_tables/profit_correction_parent_year_top20.tex}",
    "\\input{generated/results_tables/profit_correction_validation_holdout.tex}",
    "\\input{generated/results_tables/profit_correction_revenue_sensitivity.tex}"
  )
  if (file.exists(file.path(
    GENERATED_TABLES_DIR,
    "profit_correction_foreign_holding_chain_sensitivity.tex"
  ))) {
    profit_reconciliation_inputs <- c(
      profit_reconciliation_inputs,
      "\\input{generated/results_tables/profit_correction_foreign_holding_chain_sensitivity.tex}"
    )
  }

  appendix_lines <- c(
    "\\subsection{Profit reconciliation diagnostics}\\label{app:profit_reconciliation_tables}",
    profit_reconciliation_inputs,
    "",
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
    "\\input{generated/results_tables/stage3_model_comparison.tex}",
    "\\input{generated/results_tables/stage3_regression_table.tex}",
    "\\input{generated/results_tables/stage3_iv_diagnostics.tex}",
    "\\input{generated/results_tables/stage3_econometric_scorecard.tex}",
    "\\input{generated/results_tables/stage3_semielasticity.tex}",
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
    "\\input{generated/results_tables/appendix_stage46_measurement_sample_decomposition.tex}",
    "\\input{generated/results_tables/appendix_stage46_top_scenarios.tex}",
    "\\input{generated/results_tables/appendix_stage46_country_anova.tex}",
    "\\input{generated/results_tables/appendix_country_revenue_diagnostic.tex}",
    "\\input{generated/results_tables/appendix_country_typology_features.tex}",
    "\\input{generated/results_tables/appendix_country_typology_cluster_stability.tex}",
    influence_appendix_inputs
  )

  writeLines(
    c(
      "% Generated by code/08_generate_results_tables.R",
      appendix_lines
    ),
    file.path(GENERATED_DIR, "results_appendix_tables.tex")
  )
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
    "\\input{generated/results_tables/stage3_main_regression.tex}",
    "\\input{generated/results_tables/stage3_model_comparison.tex}",
    "\\input{generated/results_tables/stage3_regression_table.tex}",
    "\\input{generated/results_tables/stage3_iv_diagnostics.tex}",
    "\\input{generated/results_tables/stage3_econometric_scorecard.tex}",
    "\\input{generated/results_tables/stage3_semielasticity.tex}",
    "\\input{generated/results_tables/stage4_6_anova.tex}",
    "\\input{generated/results_tables/stage4_6_factor_decomposition.tex}",
    "\\input{generated/results_tables/preferred_channel.tex}",
    if (file.exists(file.path(
      GENERATED_TABLES_DIR,
      "stage1_measurement_error_interval.tex"
    ))) {
      "\\input{generated/results_tables/stage1_measurement_error_interval.tex}"
    },
    "\\input{generated/results_tables/stage46_measurement_sample_decomposition.tex}",
    "\\input{generated/results_tables/country_revenue_diagnostic.tex}",
    "\\input{generated/results_tables/country_typology_pca.tex}",
    "\\input{generated/results_tables/country_typology_clusters.tex}",
    "\\input{generated/results_tables/hypothesis_summary.tex}"
  )
  lines <- lines[!is.na(lines)]
  writeLines(lines, file.path(GENERATED_DIR, "results_main_tables_manifest.tex"))
}

write_results_tables <- function() {
  dir.create(GENERATED_TABLES_DIR, showWarnings = FALSE, recursive = TRUE)

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
  write_stage3_main_regression_table()
  write_stage3_iv_table()
  write_stage3_econometric_scorecard_table()
  write_stage3_semielasticity_table()

  write_stage46_anova_table()
  write_stage46_factor_decomposition_table()
  write_stage46_channel_table()
  write_stage1_measurement_error_table()
  write_stage46_measurement_sample_table()
  write_stage46_country_diagnostic_table()
  write_stage46_country_diagnostic_appendix_table()
  write_country_typology_tables()
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
