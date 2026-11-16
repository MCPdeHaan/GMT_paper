# Manuscript tables and figures.

source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "00_helpers.R"), local = TRUE)
source(file.path(GMT_PROJECT_ROOT, "code", "publication", "budget_waterfall.R"), local = TRUE)

# LaTeX tables

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

  header_line <- paste0(paste(header, collapse = " & "), " \\\\")
  if (is.null(tabcolsep)) {
    tabcolsep <- if (identical(size, "\\footnotesize") || identical(size, "\\scriptsize")) {
      "3pt"
    } else {
      "4pt"
    }
  }

  lines <- c(
    "% Generated by code/13_generate_exhibits.R",
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
  writeLines(c("% Generated by code/13_generate_exhibits.R", lines), file)
}

write_appendix_latex_table <- function(file, caption, label, col_spec, header,
                                       rows, notes = NULL,
                                       short_caption = NULL, ..., size = "\\footnotesize") {
  write_latex_table(
    file = file,
    caption = caption,
    label = label,
    col_spec = col_spec,
    header = header,
    rows = rows,
    notes = notes,
    short_caption = short_caption,
    size = size,
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

# Verified against the pinned raw extract in tests/step17_raw_inputs.sha256
# (721a7b9d...31788e4). These are source records, before reshaping or filtering.
# Retain this metadata in code so an exhibit-only checkout needs no raw data.
raw_table1_counts <- function(raw_dir = file.path(GMT_PROJECT_ROOT, RAW_DIR)) {
  frozen <- list(records = 1367305L, parents = 63L, affiliates = 244L)
  paths <- file.path(raw_dir, c("oecd_cbcr", "cbcr"), "cbcr_table1_aggregate_totals.csv")
  paths <- paths[file.exists(paths)]
  if (!length(paths)) {
    message("Raw Table I extract absent; using verified frozen source metadata.")
    return(frozen)
  }
  counts <- lapply(paths, function(path) {
    raw_t1 <- read_csv(
      path,
      col_select = c(REF_AREA, COUNTERPART_AREA, TIME_PERIOD),
      show_col_types = FALSE
    )
    observed <- list(
      records = nrow(raw_t1),
      parents = n_distinct(raw_t1$REF_AREA),
      affiliates = n_distinct(raw_t1$COUNTERPART_AREA)
    )
    if (!identical(observed, frozen)) {
      stop("Raw Table I counts differ from the frozen snapshot: ", path,
        ". Expected 1367305 records, 63 parents and 244 affiliates.", call. = FALSE)
    }
    observed
  })
  counts[[1L]]
}

write_data_descriptive_tables <- function() {
  base_panel <- read_processed("base_panel.rds")
  panel <- read_processed("stage1_bilateral_panel.rds") |>
    filter(year %in% MAIN_YEARS)
  estimation <- read_processed("stage3_estimation_sample.rds")

  positive_panel <- panel |>
    filter(analysis_profit_positive > 0)

  raw_t1 <- raw_table1_counts()

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
      "2017--2023 analytical panel",
      "EU27 affiliate slice",
      "Positive-profit tax sample",
      "Behavioural estimation sample"
    ),
    `Rows/cells` = c(
      fmt_int(raw_t1$records),
      fmt_int(base_counts$cells),
      fmt_int(panel_counts$cells),
      fmt_int(eu27_counts$cells),
      fmt_int(positive_counts$cells),
      fmt_int(estimation_counts$cells)
    ),
    Parents = c(
      fmt_int(raw_t1$parents),
      fmt_int(base_counts$parents),
      fmt_int(panel_counts$parents),
      fmt_int(eu27_counts$parents),
      fmt_int(positive_counts$parents),
      fmt_int(estimation_counts$parents)
    ),
    Affiliates = c(
      fmt_int(raw_t1$affiliates),
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
      notes = "Share is relative to the 2017--2023 analytical panel.",
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
    label = "tab:data_panel_coverage",
    caption = "Analytical panel coverage by fiscal year",
    short_caption = "Analytical panel coverage by fiscal year",
    col_spec = "lrrrrrrrr",
    header = c(
      "Year", "Pair-years", "Parents", "Affiliates",
      "Positive pairs", "EU27 pairs", "Profit (US\\$ bn)",
      "Low-taxed profit (US\\$ bn)", "Median ETR"
    ),
    rows = bind_rows(coverage_by_year, coverage_total),
    notes = "2017--2023 Stage 1 panel; profit in USD bn; median ETR among positive-profit cells.",
    size = "\\footnotesize"  )

  write_paper_main_table1(sample_rows, bind_rows(coverage_by_year, coverage_total))

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
      "% Generated by code/13_generate_exhibits.R",
      "\\input{generated/results_tables/data_sample_construction.tex}",
      "\\input{generated/results_tables/data_panel_coverage.tex}",
      "\\input{generated/results_tables/data_summary_statistics.tex}"
    ),
    file.path(GENERATED_DIR, "data_descriptive_tables.tex")
  )
}

stage3_sample_label <- function(x) {
  recode(x, balanced_pairs = "Balanced pairs", baseline = "Baseline",
    exclude_2020_2021 = "Exclude 2020–2021", exclude_stale_wages = "Exclude stale wages")
}

profit_source_label <- function(x) {
  x <- str_replace_all(x, c("public_etr_parity" = "public ETR parity", "_" = " "))
  paste0(toupper(substr(x, 1, 1)), substring(x, 2))
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
      label = "Total",
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

  sensitivity <- read_diag("step02a_profit_correction_revenue_sensitivity.csv")
  sensitivity_profit <- setNames(sensitivity$positive_profit, sensitivity$specification)

  lines <- assemble_inline_table(
    col_spec = ">{\\raggedright\\arraybackslash}p{4.2cm}rrrrrr",
    caption_lines = c(
      "\\caption[Profit-base correction]{Correction from public CbCR profit to the reconciliation profit branch, 2017 to 2023}",
      "\\label{tab:profit_correction_effects}"
    ),
    header_lines = "Category & Cells & Reported & Corrected & Reduction & Rate (\\%) & Share (\\%) \\\\",
    body_lines = row_lines,
    notes = paste0(
      "Positive-profit cells, USD bn; share is share of total profit reduction. ",
      "The table conditions on cells with positive reported profit (US\\$", fmt_bn(total$uncorrected_profit, 1),
      " bn reported, US\\$", fmt_bn(total$corrected_profit, 1), " bn corrected), whereas Tables ",
      "\\ref{tab:tab_v2_main_table1_sample_and_coverage} and \\ref{tab:profit_correction_revenue_sensitivity} ",
      "sum all analytical cells with positive corrected profit (US\\$",
      fmt_bn(sensitivity_profit[["profit_uncorrected"]], 1), " bn reported, US\\$",
      fmt_bn(sensitivity_profit[["profit_preferred"]], 1), " bn corrected)."
    ),
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
    label = "tab:stage1_source_updated",
    caption = "Stage 1 source coverage, 2017 to 2023",
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
      tibble(row = paste0("\\multicolumn{", length(years) + 1L, "}{l}{\\textit{", scope_label, "}}")),
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
    col_spec = paste0("l", strrep("r", length(years))),
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
    label = "tab:stage1_bspi_updated",
    caption = "EU27 BSPI validation, 2019 to 2020 anchor versus 2021 to 2023 validation",
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
    label = "tab:app_stage1_crossval",
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
    label = "tab:stage2_aggregate_updated",
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
    label = "tab:stage2_sectoral_sbti",
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
    label = "tab:stage2_h5_regression",
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
    label = "tab:stage3_model_comparison",
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
    label = "tab:stage3_iv_diagnostics",
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
    label = "tab:stage3_econometric_scorecard",
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
    label = "tab:stage3_reliability_scorecard",
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
    label = "tab:stage3_semielasticity",
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
    label = "tab:stage4_6_anova_updated",
    caption = "Pooled factorial decomposition of EU GMT revenue",
    short_caption = "Pooled factorial decomposition of EU GMT revenue",
    col_spec = "lrr",
    header = c("Effect", "Order", "Share (\\%)"),
    rows = x,
    notes = paste(
      "Pooled orthogonal structural variance decomposition across the 32 legally allocated revenue scenarios, EU27 country-years, 2017 to 2023.",
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

  notes <- "Pooled 32-scenario decomposition, EU27 2017--2023; variance shares are partial $\\eta^{2}$."

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
    "% Generated by code/13_generate_exhibits.R",
    assemble_inline_table(
      col_spec = "lrrr",
      caption_lines = c(
        "\\caption[Preferred-core revenue by collection channel]{Preferred-core revenue by collection channel, cumulative 2017--2023.}",
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
    label = "tab:stage1_measurement_error_interval",
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
  "Cumulative 2017--2023; spread is min--max revenue across 32 scenarios (US\\$ bn);",
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
  notes <- COUNTRY_REVENUE_DIAGNOSTIC_NOTES
  if (file.exists(file.path(PROCESSED_DIR, "stage4_5_utpr_policy.rds"))) {
    countries <- read_diag("step7_stage4_6_fiscal_salience_country.csv") |>
      filter(preferred_revenue > 0) |>
      pull(country)
    notes <- paste(
      "Cumulative 2017–2023. Spread is the difference between the maximum and minimum across 32 scenarios (US\\$ bn).",
      "Salience ratios use OECD T\\_1200 CIT and the Eurostat equivalent for Cyprus.",
      "The table covers states with positive receipts in the preferred behavioural SbS scenario."
    )
  }
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
      notes = notes,
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
  reports_unsupported <- file.exists(file.path(PROCESSED_DIR, "stage4_5_utpr_policy.rds"))
  write_country_revenue_diagnostic_table(
    file = file.path(
      GENERATED_TABLES_DIR,
      "appendix_country_revenue_diagnostic.tex"
    ),
    countries = COUNTRY_REVENUE_DIAGNOSTIC_COUNTRIES,
    short_caption = if (reports_unsupported) "Country revenue uncertainty and fiscal salience, EU27 collectors" else
      "Country revenue uncertainty and fiscal salience, full EU sample",
    caption = if (reports_unsupported) "Country revenue uncertainty and fiscal salience, EU27 collectors (appendix replication)" else
      "Country revenue uncertainty and fiscal salience, full EU sample (appendix replication of the main-text diagnostic)",
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
    label = "tab:stage46_measurement_sample_decomposition",
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
    label = "tab:app_stage46_measurement_sample_decomposition",
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
  reports_unsupported <- file.exists(file.path(PROCESSED_DIR, "stage4_5_utpr_policy.rds"))
  imputation_note <- if (reports_unsupported) {
    "For PCA scaling, median imputation fills undefined channel shares for the four countries with zero assigned receipts."
  } else {
    "Cyprus' missing OECD T\\_1200 corporate-tax denominator and undefined channel shares for the four zero-revenue countries are median-imputed only for PCA scaling."
  }
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
    label = "tab:country_typology_pca",
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
      imputation_note,
      ""
    ),
    size = "\\footnotesize"
  )

  profiles <- read_diag("step7_stage4_6_country_typology_cluster_profiles.csv")
  zero_receipts_note <- "For T4, zero Rev.\\ and missing channel shares reflect non-adoption of qualified QDMTT and IIR rules: Cyprus had no qualified domestic top-up tax in the Central Record, and Estonia, Latvia, Lithuania and Malta deferred the rules under Article 50."
  if (reports_unsupported) {
    zero_receipts_note <- paste("T4 has zero assigned receipts and undefined channel shares.",
      "Estonia, Latvia, Lithuania and Malta deferred IIR and UTPR under Article 50.")
  }
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
    label = "tab:country_typology_clusters",
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
      "the smallest cluster contains one country, and the four-cluster solution separates conduit hubs (T1), QDMTT-protected smaller states (T2), residual IIR/UTPR exposure states (T3) and states with zero baseline collector receipts (T4).",
      "Rev.\\ is preferred behavioural SbS revenue in US dollars, billions.",
      zero_receipts_note,
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
      "Revenue, spread and main-effect columns are cumulative over 2017 to 2023 and expressed in US dollars, billions.",
      "Main effects are signed into policy-exposure magnitudes: distributional minus average ETR measurement, universal minus SbS revenue loss, aggregate minus sectoral substance exposure and mechanical minus behavioural revenue.",
      ""
    ),
    fit_width = TRUE
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
      "The distributional branch raises the EU27 Stage 1 liability rate relative to the jurisdiction-average rule in every year from 2017 to 2023.",
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
      "Supported. Member States separate into high-salience conduit hubs, QDMTT-protected smaller exposures, residual IIR/UTPR exposure states and states whose zero baseline receipts reflect non-adoption of qualified QDMTT or IIR rules and Article 50 deferral."
    ))
  )

  write_latex_table(
    file.path(GENERATED_TABLES_DIR, "hypothesis_summary.tex"),
    label = "tab:hypothesis_result_summary",
    caption = "Hypothesis summary",
    short_caption = "Hypothesis summary",
    col_spec = "L{1.7cm}L{7.1cm}L{4.8cm}",
    header = c("Hypothesis", "Main result", "Interpretation"),
    rows = rows,
    notes = paste(
      "The table summarises the evidence reported in the Stage 1 to Stage 4.6 diagnostics and the country fiscal-exposure calculations.",
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
      scope_label = str_to_sentence(str_replace_all(scope, "_", " ")) |>
        str_replace_all(c("\\bupe\\b" = "UPE", "\\birs\\b" = "IRS", "\\bcbcr\\b" = "CbCR",
          "\\bcompustat\\b" = "Compustat", "\\betr\\b" = "ETR"))
    ) |>
    transmute(
      Evidence = latex_escape(evidence_label),
      Source = paste0("\\citet{", source_citation_key, "}"),
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
    ),
    fit_width = TRUE
  )

  parent_year_top20 <- read_diag("step02a_profit_correction_parent_year_top20.csv") |>
    transmute(
      Parent = latex_escape(parent),
      Years = fmt_int(years),
      `Domestic profit (US$ bn)` = fmt_bn(domestic_profit, 1),
      `$\\hat{\\rho}$ (\\%)` = fmt_pct(rho_hat, 1),
      `Low (\\%)` = fmt_pct(rho_lo, 1),
      `High (\\%)` = fmt_pct(rho_hi, 1),
      `Main source` = latex_escape(profit_source_label(main_sources)),
      Support = latex_escape(profit_source_label(support_class))
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
      "Rows are the twenty parent jurisdictions with the largest positive domestic profit over 2017 to 2023.",
      "Rates are domestic-profit-weighted averages of parent-year predictions.",
      ""
    ),
    fit_width = TRUE
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
    ),
    fit_width = TRUE
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
      `Asset sensitivity` = recode(asset_sensitivity,
        minus_25 = "$-25\\%$", baseline = "Baseline", plus_25 = "$+25\\%$"),
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
      "Weighted $\\phi$ (\\%)", "Average floor (\\%)", "Distributional floor (\\%)"
    ),
    asset_sensitivity,
    ""
  )

  sample_summary <- read_diag("step5_stage3_estimation_sample_summary.csv") |>
    transmute(
      Sample = latex_escape(stage3_sample_label(sample)),
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
      Test = latex_escape(recode(test, vuong_gaussian_observation_ll = "Vuong log-likelihood",
        clarke_sign = "Clarke sign test", davidson_mackinnon_j = "Davidson–MacKinnon J-test")),
      `Model A` = latex_escape(str_to_sentence(model_a)),
      `Model B` = latex_escape(str_to_sentence(model_b)),
      Statistic = fmt_num(statistic, 3),
      `$p$-value` = fmt_p(p_value),
      Interpretation = latex_escape(paste0(toupper(substr(interpretation, 1, 1)), substring(interpretation, 2)))
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
      `Tax terms` = recode(terms, "tau" = "$\\tau$", "tau + tau_sq" = "$\\tau, \\tau^2$",
        "tau + log_tau" = "$\\tau, \\ln(\\tau+t_0)$"),
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
      Sample = latex_escape(stage3_sample_label(sample)),
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
      Component = latex_escape(recode(component, low_etr_nonlinearity = "Low-ETR nonlinearity",
        sesh_notch_bunching = "SESH notch bunching",
        .default = str_to_sentence(str_replace_all(component, "_", " ")))),
      `Baseline treatment` = latex_escape(str_replace_all(baseline_treatment,
        "Garcia-Bernardo and Jansky", "Garcia-Bernardo and Janský")),
      `Identification status` = latex_escape(str_replace_all(identification_status,
        "2017-2022 public CbCR panel", "2017–2023 public CbCR panel")),
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
    "",
    fit_width = TRUE
  )

  stage45_labels <- c(
    factorial_scenarios = "Factorial scenarios",
    eu27_country_year_revenue_rows = "EU27 country-year revenue rows",
    global_allocation_conservation_max_abs_gap = "Global allocation conservation, maximum absolute gap",
    utpr_parent_year_weight_rows = "UTPR parent-year weight rows",
    utpr_fallback_weight_rows = "UTPR fallback weight rows",
    h4_mean_delta_sbs_minus_universal = "H4 mean delta (SbS minus Universal)",
    h4_median_delta_sbs_minus_universal = "H4 median delta (SbS minus Universal)",
    h4_wilcoxon_less_p_value = "H4 Wilcoxon p-value",
    max_iir_ambiguous_parent_flag_share = "Max IIR ambiguous parent share",
    max_utpr_ambiguous_collector_share = "Max UTPR ambiguous collector share",
    eu_revenue_min_scenario = "EU27 revenue minimum scenario (US$ bn)",
    eu_revenue_max_scenario = "EU27 revenue maximum scenario (US$ bn)"
  )
  stage45_summary <- read_diag("step6_stage4_5_summary.csv") |>
    mutate(
      value = as.numeric(value),
      value_fmt = case_when(
        str_detect(metric, "rows|factorial") ~ fmt_int(value),
        str_detect(metric, "p_value") ~ fmt_p(value),
        str_detect(metric, "revenue|delta|scenario") ~ fmt_bn(value, 3),
        TRUE ~ fmt_num(value, 3)
      )
    ) |>
    transmute(
      Metric = latex_escape(coalesce(unname(stage45_labels[metric]), metric)),
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
    mutate(
      scale = if_else(term == "preferred_scenario_revenue", 1, 1e9),
      term = recode(term, "(Intercept)" = "Intercept", source_qdmttTRUE = "Source QDMTT enacted",
        source_us_parented_topup_share = "US-parented share of source top-up",
        preferred_scenario_revenue = "Preferred collector revenue")
    ) |>
    transmute(
      Term = latex_escape(term),
      Estimate = fmt_num(estimate / scale, 4),
      SE = fmt_num(std_error / scale, 4),
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
    paste(
      "The dependent variable is the SbS minus Universal revenue change.",
      "The dependent variable and the first three terms are in US\\$ bn; the revenue slope is in USD per USD.",
      ""
    )
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
        "Main effects are cumulative over 2017 to 2023 and expressed in US dollars, billions.",
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
      "% Generated by code/13_generate_exhibits.R",
      appendix_lines
    ),
    file.path(GENERATED_DIR, "results_appendix_tables.tex")
  )
}

write_manifest <- function() {
  lines <- c(
    "% Generated by code/13_generate_exhibits.R",
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

# PDF figures

FIGURES_DIR <- file.path(GENERATED_DIR, "figures")

thesis_cols <- c(
  navy = "#1F3A5F",
  red = "#C44536",
  orange = "#D97706",
  grey = "#6B7280",
  light = "#F3F4F6",
  mid = "#D1D5DB"
)

theme_thesis <- function(base_size = 8.5) {
  ggplot2::theme_minimal(base_size = base_size, base_family = "serif") +
    ggplot2::theme(
      text = ggplot2::element_text(colour = thesis_cols[["navy"]]),
      plot.title = ggplot2::element_blank(),
      plot.subtitle = ggplot2::element_blank(),
      plot.caption = ggplot2::element_blank(),
      axis.title = ggplot2::element_text(face = "bold"),
      axis.text = ggplot2::element_text(colour = thesis_cols[["navy"]]),
      panel.grid.major = ggplot2::element_line(colour = thesis_cols[["mid"]], linewidth = 0.25),
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = "bottom",
      legend.box = "vertical",
      legend.title = ggplot2::element_text(face = "bold"),
      legend.text = ggplot2::element_text(size = base_size - 0.5),
      legend.key.width = grid::unit(1.0, "lines"),
      strip.text = ggplot2::element_text(face = "bold", colour = thesis_cols[["navy"]])
    )
}

save_thesis_plot <- function(plot, filename, width, height) {
  dir.create(FIGURES_DIR, recursive = TRUE, showWarnings = FALSE)
  ggplot2::ggsave(
    filename = file.path(FIGURES_DIR, filename),
    plot = plot,
    width = width,
    height = height,
    units = "in",
    device = grDevices::pdf,
    bg = "white"
  )
}

format_usd_short <- function(x) {
  case_when(
    is.na(x) ~ NA_character_,
    abs(x) >= 1e12 ~ paste0("US$", round(x / 1e12, 1), "tn"),
    abs(x) >= 1e9 ~ paste0("US$", round(x / 1e9, 0), "bn"),
    abs(x) >= 1e6 ~ paste0("US$", round(x / 1e6, 0), "m"),
    abs(x) >= 1e3 ~ paste0("US$", round(x / 1e3, 0), "k"),
    TRUE ~ paste0("US$", round(x, 0))
  )
}

format_signed_bn <- function(x, digits = 1) {
  case_when(
    is.na(x) ~ NA_character_,
    x >= 0 ~ paste0("+US$", round(x / 1e9, digits), "bn"),
    TRUE ~ paste0("-US$", round(abs(x) / 1e9, digits), "bn")
  )
}

label_selected_countries <- c("NLD", "IRL", "LUX", "DEU", "FRA", "HUN", "BEL", "ESP", "AUT")

make_profit_employee_etr_bubble <- function() {
  base_panel <- readRDS(file.path(PROCESSED_DIR, "base_panel.rds"))
  stage1_affiliate_year <- readRDS(file.path(PROCESSED_DIR, "stage1_affiliate_year.rds"))

  employees_country_year <- base_panel %>%
    filter(
      is_main_estimation_year,
      affiliate_is_eu27,
      is.finite(analysis_profit_base),
      analysis_profit_base > 0,
      is.finite(employees_sbie),
      employees_sbie > 0
    ) %>%
    group_by(affiliate, year) %>%
    summarise(
      employees = sum(employees_sbie, na.rm = TRUE),
      .groups = "drop"
    )

  country_plot <- stage1_affiliate_year %>%
    filter(affiliate_is_eu27, year %in% MAIN_YEARS) %>%
    left_join(employees_country_year, by = c("affiliate", "year")) %>%
    group_by(affiliate, affiliate_name) %>%
    summarise(
      corrected_profit = sum(total_analysis_profit_positive, na.rm = TRUE),
      employees = sum(employees, na.rm = TRUE),
      average_etr = weighted.mean(avg_etr_stage1, total_analysis_profit_positive, na.rm = TRUE),
      distributional_low_share = weighted.mean(
        stage1_distributional_low_share,
        total_analysis_profit_positive,
        na.rm = TRUE
      ),
      .groups = "drop"
    ) %>%
    mutate(
      profit_per_employee = corrected_profit / employees,
      threshold_group = factor(
        case_when(
          average_etr < GMT_RATE ~ "Below 15% avg. ETR",
          distributional_low_share >= 0.25 ~ "Above 15% avg. ETR, tail at least 25%",
          TRUE ~ "Above 15% avg. ETR, smaller tail"
        ),
        levels = c(
          "Above 15% avg. ETR, smaller tail",
          "Above 15% avg. ETR, tail at least 25%",
          "Below 15% avg. ETR"
        )
      ),
      label_country = affiliate %in% label_selected_countries
    ) %>%
    filter(
      is.finite(profit_per_employee),
      profit_per_employee > 0,
      is.finite(average_etr),
      corrected_profit > 0
    )

  label_positions <- tibble::tribble(
    ~affiliate, ~label_x, ~label_y,
    "DEU", 1.75e5, 0.214,
    "FRA", 7.25e4, 0.223,
    "ESP", 7.50e4, 0.167,
    "BEL", 2.85e5, 0.174,
    "AUT", 2.65e5, 0.125,
    "HUN", 7.50e4, 0.105,
    "NLD", 5.60e5, 0.065,
    "IRL", 1.55e6, 0.122,
    "LUX", 3.25e6, 0.060
  )

  label_data <- country_plot %>%
    filter(label_country) %>%
    inner_join(label_positions, by = "affiliate")

  ggplot2::ggplot(
    country_plot,
    ggplot2::aes(
      x = profit_per_employee,
      y = average_etr,
      size = corrected_profit,
      colour = threshold_group
    )
  ) +
    ggplot2::geom_hline(
      yintercept = GMT_RATE,
      colour = thesis_cols[["red"]],
      linetype = "dashed",
      linewidth = 0.45
    ) +
    ggplot2::geom_point(alpha = 0.76) +
    ggplot2::geom_segment(
      data = label_data,
      ggplot2::aes(xend = label_x, yend = label_y),
      linewidth = 0.25,
      colour = thesis_cols[["grey"]],
      alpha = 0.55,
      show.legend = FALSE
    ) +
    ggplot2::geom_text(
      data = label_data,
      ggplot2::aes(x = label_x, y = label_y, label = affiliate),
      inherit.aes = FALSE,
      size = 2.15,
      colour = thesis_cols[["navy"]],
      fontface = "bold",
      show.legend = FALSE
    ) +
    ggplot2::scale_x_log10(
      labels = format_usd_short,
      breaks = c(1e4, 1e5, 1e6, 1e7, 1e8),
      expand = ggplot2::expansion(mult = c(0.04, 0.10))
    ) +
    ggplot2::scale_y_continuous(
      labels = scales::label_percent(accuracy = 1),
      limits = c(0, 0.25),
      breaks = seq(0, 0.25, by = 0.05),
      expand = ggplot2::expansion(mult = c(0.02, 0.02))
    ) +
    ggplot2::scale_size_area(
      max_size = 10,
      breaks = c(1e11, 5e11, 1e12),
      labels = format_usd_short,
      name = "Corrected profit",
      guide = ggplot2::guide_legend(
        order = 2,
        nrow = 1,
        override.aes = list(size = c(2.8, 4.5, 6.2), alpha = 0.76),
        keywidth = grid::unit(0.55, "lines")
      )
    ) +
    ggplot2::scale_colour_manual(
      values = c(
        "Below 15% avg. ETR" = thesis_cols[["red"]],
        "Above 15% avg. ETR, tail at least 25%" = thesis_cols[["orange"]],
        "Above 15% avg. ETR, smaller tail" = thesis_cols[["navy"]]
      ),
      name = NULL,
      guide = ggplot2::guide_legend(
        override.aes = list(size = 3.2, alpha = 0.76),
        nrow = 2,
        ncol = 2,
        byrow = TRUE,
        order = 1,
        keywidth = grid::unit(0.55, "lines")
      )
    ) +
    ggplot2::labs(
      x = "Corrected profit per employee (USD, log scale)",
      y = "Profit-weighted bounded ETR"
    ) +
    theme_thesis() +
    ggplot2::theme(
      legend.box = "vertical",
      legend.box.spacing = grid::unit(0.25, "lines"),
      legend.spacing.y = grid::unit(0.2, "lines"),
      legend.spacing.x = grid::unit(0.35, "lines"),
      legend.key.height = grid::unit(0.5, "lines"),
      legend.margin = ggplot2::margin(t = 2, r = 0, b = 2, l = 0),
      axis.title.x = ggplot2::element_text(margin = ggplot2::margin(t = 4, b = 2)),
      plot.margin = ggplot2::margin(2, 4, 6, 2),
      legend.text = ggplot2::element_text(size = 7)
    )
}

make_semielasticity_plot <- function() {
  coef <- readRDS(file.path(PROCESSED_DIR, "stage3_model_coefficients.rds")) %>%
    filter(inference == "parent_affiliate_clustered")

  pick_coef <- function(model, term) {
    coef %>%
      filter(model_spec == model, term == !!term) %>%
      slice(1) %>%
      pull(estimate)
  }

  t0_log <- coef %>%
    filter(model_spec == "logarithmic") %>%
    slice(1) %>%
    pull(t0)

  b_linear <- pick_coef("linear", "tau")
  b_quad_1 <- pick_coef("quadratic", "tau")
  b_quad_2 <- pick_coef("quadratic", "tau_sq")
  b_log_1 <- pick_coef("logarithmic", "tau")
  b_log_2 <- pick_coef("logarithmic", "log_tau")

  tau_grid <- seq(0.005, 0.30, by = 0.001)

  curves <- bind_rows(
    tibble(
      model = "Linear, selected",
      tau = tau_grid,
      semi_elasticity = -b_linear,
      profit_remaining = if_else(
        tau < GMT_RATE,
        exp(b_linear * (GMT_RATE - tau)),
        1
      )
    ),
    tibble(
      model = "Quadratic",
      tau = tau_grid,
      semi_elasticity = -(b_quad_1 + 2 * b_quad_2 * tau),
      profit_remaining = if_else(
        tau < GMT_RATE,
        exp(b_quad_1 * (GMT_RATE - tau) + b_quad_2 * (GMT_RATE^2 - tau^2)),
        1
      )
    ),
    tibble(
      model = "Logarithmic",
      tau = tau_grid,
      semi_elasticity = -(b_log_1 + b_log_2 / (t0_log + tau)),
      profit_remaining = if_else(
        tau < GMT_RATE,
        exp(
          b_log_1 * (GMT_RATE - tau) +
            b_log_2 * (log(t0_log + GMT_RATE) - log(t0_log + tau))
        ),
        1
      )
    )
  ) %>%
    mutate(
      model = factor(model, levels = c("Linear, selected", "Quadratic", "Logarithmic"))
    )

  ggplot2::ggplot(curves, ggplot2::aes(x = tau, y = semi_elasticity, colour = model)) +
    ggplot2::geom_vline(
      xintercept = GMT_RATE,
      colour = thesis_cols[["grey"]],
      linetype = "dashed",
      linewidth = 0.4
    ) +
    ggplot2::geom_line(linewidth = 0.9) +
    ggplot2::annotate(
      "text",
      x = GMT_RATE + 0.006,
      y = max(curves$semi_elasticity, na.rm = TRUE) - 0.08,
      label = "15% floor",
      hjust = 0,
      size = 2.6,
      colour = thesis_cols[["grey"]]
    ) +
    ggplot2::scale_x_continuous(
      labels = scales::label_percent(accuracy = 1),
      breaks = seq(0, 0.30, by = 0.05),
      limits = c(0, 0.30),
      expand = ggplot2::expansion(mult = c(0.01, 0.02))
    ) +
    ggplot2::scale_y_continuous(
      breaks = seq(1.2, 2.1, by = 0.2),
      expand = ggplot2::expansion(mult = c(0.03, 0.08))
    ) +
    ggplot2::scale_colour_manual(
      values = c(
        "Linear, selected" = thesis_cols[["navy"]],
        "Quadratic" = thesis_cols[["orange"]],
        "Logarithmic" = thesis_cols[["red"]]
      ),
      name = "Functional form"
    ) +
    ggplot2::labs(
      x = "Pre-reform ETR",
      y = "Semi-elasticity of reported profit"
    ) +
    theme_thesis(base_size = 8) +
    ggplot2::theme(
      legend.box = "horizontal",
      legend.margin = ggplot2::margin(t = -2, b = -2),
      plot.margin = ggplot2::margin(2, 4, 2, 2)
    )
}

make_decomposition_plot <- function() {
  main_effects <- readRDS(file.path(PROCESSED_DIR, "stage4_6_main_effects_pooled.rds")) %>%
    select(effect, high_minus_low)

  shapley <- readRDS(file.path(PROCESSED_DIR, "stage4_6_shapley_factor_attribution.rds")) %>%
    left_join(main_effects, by = "effect") %>%
    mutate(
      factor_label = recode(
        effect,
        "x1_etr" = "ETR measurement",
        "x4_sbs" = "SbS regime",
        "x2_substance" = "Substance specification",
        "x5_behaviour" = "Behavioural response",
        "x3_rates" = "SBIE rate endpoint",
        .default = factor_label
      ),
      factor_label = factor(factor_label, levels = factor_label[order(shapley_eta_squared)]),
      fill_group = case_when(
        effect == "x1_etr" ~ "Measurement",
        effect == "x4_sbs" ~ "Legal allocation",
        effect == "x5_behaviour" ~ "Behavioural",
        TRUE ~ "Substance and policy"
      ),
      bar_label = paste0(
        scales::label_percent(accuracy = 0.1)(shapley_eta_squared),
        "  ",
        format_signed_bn(high_minus_low)
      )
    )

  ggplot2::ggplot(shapley, ggplot2::aes(x = shapley_eta_squared, y = factor_label, fill = fill_group)) +
    ggplot2::geom_col(width = 0.66, colour = "white", linewidth = 0.2) +
    ggplot2::geom_text(
      ggplot2::aes(label = bar_label),
      hjust = -0.04,
      size = 2.45,
      colour = thesis_cols[["navy"]]
    ) +
    ggplot2::scale_x_continuous(
      labels = scales::label_percent(accuracy = 1),
      limits = c(0, max(shapley$shapley_eta_squared) * 1.18),
      expand = ggplot2::expansion(mult = c(0, 0.02))
    ) +
    ggplot2::scale_fill_manual(
      values = c(
        "Measurement" = thesis_cols[["navy"]],
        "Legal allocation" = thesis_cols[["red"]],
        "Behavioural" = thesis_cols[["orange"]],
        "Substance and policy" = thesis_cols[["grey"]]
      ),
      name = NULL
    ) +
    ggplot2::labs(
      x = "Share of pooled EU scenario variance",
      y = NULL
    ) +
    theme_thesis(base_size = 8.2) +
    ggplot2::theme(
      legend.position = "none",
      plot.margin = ggplot2::margin(2, 8, 2, 2)
    )
}

make_country_salience_plot <- function() {
  fiscal <- readRDS(file.path(PROCESSED_DIR, "stage4_6_fiscal_salience_country.rds"))
  anova_country <- readRDS(file.path(PROCESSED_DIR, "stage4_6_anova_by_country.rds"))

  dominant <- anova_country %>%
    filter(interaction_order == 1) %>%
    group_by(country) %>%
    slice_max(eta_squared, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    transmute(country, dominant_channel = effect_label)

  plot_data <- fiscal %>%
    left_join(dominant, by = "country") %>%
    mutate(
      revenue_to_cit_1200 = if_else(
        !is.finite(revenue_to_cit_1200) & preferred_revenue == 0,
        0,
        revenue_to_cit_1200
      ),
      scenario_spread_to_cit_1200 = if_else(
        !is.finite(scenario_spread_to_cit_1200) & scenario_spread == 0,
        0,
        scenario_spread_to_cit_1200
      ),
      dominant_channel = recode(
        dominant_channel,
        "ETR measurement" = "ETR measurement",
        "SbS regime" = "SbS regime",
        "Substance specification" = "Substance",
        "Behavioural response" = "Behavioural response",
        .default = dominant_channel
      ),
      label_country = country %in% c("NLD", "IRL", "LUX", "DEU", "FRA", "HUN", "BEL", "DNK", "AUT")
    )

  label_offsets <- tibble::tribble(
    ~country, ~dx, ~dy,
    "NLD", -0.025, 0.022,
    "IRL", 0.010, 0.020,
    "HUN", -0.030, 0.010,
    "DEU", 0.024, 0.012,
    "FRA", 0.000, 0.018,
    "BEL", 0.026, -0.014,
    "DNK", 0.010, -0.020,
    "AUT", -0.016, -0.014
  )

  label_data <- plot_data %>%
    filter(label_country, country != "LUX") %>%
    inner_join(label_offsets, by = "country") %>%
    mutate(
      label_x = revenue_to_cit_1200 + dx,
      label_y = scenario_spread_to_cit_1200 + dy
    )

  ggplot2::ggplot(
    filter(plot_data, country != "LUX"),
    ggplot2::aes(
      x = revenue_to_cit_1200,
      y = scenario_spread_to_cit_1200,
      colour = dominant_channel,
      size = preferred_revenue
    )
  ) +
    ggplot2::geom_abline(
      slope = 1,
      intercept = 0,
      colour = thesis_cols[["mid"]],
      linetype = "dotted",
      linewidth = 0.45
    ) +
    ggplot2::geom_point(alpha = 0.78) +
    ggplot2::geom_segment(
      data = label_data,
      ggplot2::aes(
        x = revenue_to_cit_1200,
        y = scenario_spread_to_cit_1200,
        xend = label_x,
        yend = label_y
      ),
      inherit.aes = FALSE,
      linewidth = 0.25,
      colour = thesis_cols[["grey"]],
      alpha = 0.55,
      show.legend = FALSE
    ) +
    ggplot2::geom_label(
      data = label_data,
      ggplot2::aes(x = label_x, y = label_y, label = country),
      inherit.aes = FALSE,
      size = 2.35,
      linewidth = 0.18,
      label.padding = grid::unit(0.04, "lines"),
      label.r = grid::unit(0.02, "lines"),
      fill = "white",
      colour = thesis_cols[["navy"]],
      show.legend = FALSE
    ) +
    ggplot2::annotate(
      "segment",
      x = 0.405,
      xend = 0.448,
      y = 0.405,
      yend = 0.448,
      colour = thesis_cols[["red"]],
      linewidth = 0.35,
      arrow = grid::arrow(length = grid::unit(0.10, "cm"), type = "closed")
    ) +
    ggplot2::annotate(
      "label",
      x = 0.326,
      y = 0.445,
      label = with(filter(plot_data, country == "LUX"), sprintf(
        "LUX outside scale:\n%.0f%% revenue, %.0f%% spread",
        100 * revenue_to_cit_1200, 100 * scenario_spread_to_cit_1200
      )),
      hjust = 0,
      size = 2.35,
      linewidth = 0.18,
      label.padding = grid::unit(0.10, "lines"),
      label.r = grid::unit(0.04, "lines"),
      fill = "white",
      colour = thesis_cols[["red"]]
    ) +
    ggplot2::scale_x_continuous(
      labels = scales::label_percent(accuracy = 1),
      breaks = c(0, 0.05, 0.10, 0.25, 0.40),
      limits = c(0, 0.46),
      expand = ggplot2::expansion(mult = c(0.01, 0.03))
    ) +
    ggplot2::scale_y_continuous(
      labels = scales::label_percent(accuracy = 1),
      breaks = c(0, 0.05, 0.10, 0.25, 0.40),
      limits = c(0, 0.46),
      expand = ggplot2::expansion(mult = c(0.01, 0.04))
    ) +
    ggplot2::scale_size_area(
      max_size = 8,
      breaks = c(5e9, 25e9, 75e9),
      labels = format_usd_short,
      name = "Preferred revenue",
      guide = ggplot2::guide_legend(
        order = 2,
        nrow = 1,
        override.aes = list(size = c(2.4, 4.2, 6.0), alpha = 0.78),
        keywidth = grid::unit(0.55, "lines")
      )
    ) +
    ggplot2::scale_colour_manual(
      values = c(
        "ETR measurement" = thesis_cols[["navy"]],
        "SbS regime" = thesis_cols[["red"]],
        "Substance" = thesis_cols[["orange"]],
        "Behavioural response" = thesis_cols[["grey"]]
      ),
      name = "Dominant channel",
      guide = ggplot2::guide_legend(
        order = 1,
        nrow = 2,
        ncol = 2,
        byrow = TRUE,
        override.aes = list(size = 3.2, alpha = 0.78),
        keywidth = grid::unit(0.55, "lines")
      )
    ) +
    ggplot2::labs(
      x = "Preferred revenue as share of CIT",
      y = "Scenario spread as share of CIT"
    ) +
    theme_thesis(base_size = 8.2) +
    ggplot2::theme(
      legend.box = "vertical",
      legend.box.spacing = grid::unit(0.25, "lines"),
      legend.spacing.y = grid::unit(0.2, "lines"),
      legend.spacing.x = grid::unit(0.35, "lines"),
      legend.key.height = grid::unit(0.5, "lines"),
      legend.margin = ggplot2::margin(t = 2, r = 0, b = 2, l = 0),
      axis.title.x = ggplot2::element_text(margin = ggplot2::margin(t = 4, b = 2)),
      plot.margin = ggplot2::margin(2, 4, 6, 2)
    )
}

make_preferred_channel_plot <- function() {
  channel <- readRDS(file.path(PROCESSED_DIR, "stage4_6_preferred_channel_summary.rds")) %>%
    mutate(
      regime = recode(
        factor4_sbs,
        "universal" = "Universal",
        "sbs" = "Side-by-Side"
      ),
      regime = factor(regime, levels = c("Universal", "Side-by-Side")),
      channel = factor(channel, levels = c("QDMTT", "IIR", "UTPR")),
      channel_label = if_else(revenue_bn >= 20, paste0(channel, "\n", round(revenue_bn, 1)), "")
    )

  totals <- channel %>%
    group_by(regime) %>%
    summarise(total_bn = sum(revenue_bn), .groups = "drop")

  utpr_loss <- channel %>%
    filter(channel == "UTPR") %>%
    summarise(loss_bn = revenue_bn[regime == "Universal"] - revenue_bn[regime == "Side-by-Side"]) %>%
    pull(loss_bn)

  ggplot2::ggplot(channel, ggplot2::aes(x = revenue_bn, y = regime, fill = channel)) +
    ggplot2::geom_col(width = 0.55, colour = "white", linewidth = 0.25) +
    ggplot2::geom_text(
      ggplot2::aes(label = channel_label),
      position = ggplot2::position_stack(vjust = 0.5),
      colour = "white",
      size = 2.35,
      lineheight = 0.92,
      show.legend = FALSE
    ) +
    ggplot2::geom_text(
      data = totals,
      ggplot2::aes(x = total_bn + 12, y = regime, label = paste0("Total US$", round(total_bn, 1), "bn")),
      inherit.aes = FALSE,
      hjust = 0,
      size = 2.45,
      colour = thesis_cols[["navy"]]
    ) +
    ggplot2::annotate(
      "text",
      x = 420,
      y = 1.5,
      label = paste0("UTPR loss under SbS: US$", round(utpr_loss, 1), "bn"),
      size = 2.45,
      colour = thesis_cols[["red"]]
    ) +
    ggplot2::scale_x_continuous(
      labels = function(x) paste0("US$", x, "bn"),
      breaks = seq(0, 500, by = 100),
      expand = ggplot2::expansion(mult = c(0, 0.18))
    ) +
    ggplot2::scale_fill_manual(
      values = c(
        "QDMTT" = thesis_cols[["navy"]],
        "IIR" = thesis_cols[["orange"]],
        "UTPR" = thesis_cols[["red"]]
      ),
      name = "Collection channel"
    ) +
    ggplot2::labs(
      x = "Cumulative preferred-core revenue, 2017 to 2023",
      y = NULL
    ) +
    theme_thesis(base_size = 8.2) +
    ggplot2::theme(
      legend.box = "horizontal",
      plot.margin = ggplot2::margin(4, 12, 4, 4)
    )
}

run_generate_results_figures <- function() {
  old_options <- options(lifecycle_verbosity = "quiet")
  on.exit(options(old_options), add = TRUE)
  figures <- list(
    fig_profit_employee_etr_bubble = make_profit_employee_etr_bubble(),
    fig_stage3_semielasticity_estimated = make_semielasticity_plot(),
    fig_stage46_shapley_variance = make_decomposition_plot(),
    fig_country_salience_uncertainty = make_country_salience_plot(),
    fig_preferred_channel_composition = make_preferred_channel_plot()
  )

  figure_files <- c(
    fig_profit_employee_etr_bubble = "fig_profit_employee_etr_bubble.pdf",
    fig_stage3_semielasticity_estimated = "fig_stage3_semielasticity_estimated.pdf",
    fig_stage46_shapley_variance = "fig_stage46_shapley_variance.pdf",
    fig_country_salience_uncertainty = "fig_country_salience_uncertainty.pdf",
    fig_preferred_channel_composition = "fig_preferred_channel_composition.pdf"
  )

  save_thesis_plot(figures$fig_profit_employee_etr_bubble,
    figure_files[["fig_profit_employee_etr_bubble"]], 6.7, 5.35
  )
  save_thesis_plot(figures$fig_stage3_semielasticity_estimated,
    figure_files[["fig_stage3_semielasticity_estimated"]], 5.8, 2.85
  )
  save_thesis_plot(figures$fig_stage46_shapley_variance,
    figure_files[["fig_stage46_shapley_variance"]], 6.7, 3.45
  )
  save_thesis_plot(figures$fig_country_salience_uncertainty,
    figure_files[["fig_country_salience_uncertainty"]], 6.0, 4.25
  )
  save_thesis_plot(figures$fig_preferred_channel_composition,
    figure_files[["fig_preferred_channel_composition"]], 6.7, 2.8
  )

  message(
    paste(
      "Generated figures:",
      file.path(FIGURES_DIR, unname(figure_files)),
      collapse = "\n"
    )
  )

  invisible(figures)
}

# Paper v2 exhibits, projected from the frozen diagnostic tables.

PAPER_TABLES_DIR <- file.path(GENERATED_DIR, "paper_v2_tables")
PAPER_FIGURES_DIR <- file.path(GENERATED_DIR, "paper_v2_figures")
paper_read <- function(stem) {
  read_csv(file.path(DIAGNOSTICS_DIR, paste0(stem, ".csv")),
    show_col_types = FALSE, guess_max = Inf)
}

paper_number <- function(x, digits = 2) {
  ifelse(is.infinite(x), paste0(ifelse(x < 0, "-", ""), "infinity"),
    ifelse(is.na(x), "--", fmt_num(x, digits)))
}

paper_p <- function(x) {
  ifelse(is.na(x), "--", ifelse(x < .001, "<0.001", paper_number(x, 3)))
}

paper_pct <- function(x, digits = 2) paper_number(100 * x, digits)
paper_bn <- function(x, digits = 2) paper_number(x / 1e9, digits)

PAPER_RAW_PREFIX <- "<raw>"
paper_raw <- function(x) paste0(PAPER_RAW_PREFIX, x)

paper_bic <- function(x) {
  exponent <- floor(log10(abs(x)))
  scientific <- paste0("$", formatC(x / 10^exponent, format = "f", digits = 2), "\\times 10^{", exponent, "}$")
  ifelse(abs(x) >= 1e7, paper_raw(scientific), paper_number(x, 1))
}

paper_rates <- function(x) recode(x, initial = "Initial", long_run = "Long-run")

paper_panel <- function(columns, rows) {
  stopifnot(ncol(rows) == length(columns), nrow(rows) > 0L)
  setNames(rows, columns)
}

paper_table_rows <- function(data) {
  bs <- intToUtf8(92L)
  cells <- as.matrix(data)
  cells[is.na(cells)] <- "--"
  apply(cells, 1, function(row) {
    raw <- startsWith(row, PAPER_RAW_PREFIX)
    formatted <- latex_escape(row)
    formatted[raw] <- substring(row[raw], nchar(PAPER_RAW_PREFIX) + 1L)
    formatted[formatted == "infinity"] <- paste0("$", bs, "infty$")
    formatted[formatted == "-infinity"] <- paste0("$-", bs, "infty$")
    formatted[formatted == "<0.001"] <- "$<0.001$"
    paste0(paste(formatted, collapse = " & "), " ", bs, bs)
  })
}

# Input-ready, page-breaking fragments with repeated headers, for long appendix tables.
write_paper_table <- function(filename, title, panels, notes, align = list()) {
  bs <- intToUtf8(92L)
  end_row <- paste0(" ", bs, bs)
  lines <- c("% Generated by code/13_generate_exhibits.R",
    "% Requires booktabs and longtable.",
    paste0("{", bs, "small", bs, "setlength{", bs, "LTpre}{4pt}",
      bs, "setlength{", bs, "LTpost}{4pt}"),
    purrr::imap(panels, function(data, panel) {
      span <- function(x) paste0(bs, "multicolumn{", ncol(data), "}{l}{", x, "}", end_row)
      first <- panel == names(panels)[1]
      label <- if (first) {
        paste0(bs, "caption{", latex_escape(title), "}", bs, "label{tab:", filename, "}", end_row)
      } else {
        span(paste0(bs, "textit{", latex_escape(title), " (continued)}"))
      }
      heading <- span(paste0(bs, "textbf{", latex_escape(panel), "}"))
      header <- paste0(paste(latex_escape(names(data)), collapse = " & "), end_row)
      spec <- if (is.null(align[[panel]])) paste0("l", strrep("r", ncol(data) - 1)) else align[[panel]]
      # Every longtable steps the table counter, so continuation panels undo the step.
      c(if (!first) paste0(bs, "addtocounter{table}{-1}"),
        paste0(bs, "begin{longtable}{@{}", spec, "@{}}"),
        label, heading, paste0(bs, "toprule"), header, paste0(bs, c("midrule", "endfirsthead")),
        heading, paste0(bs, "toprule"), header, paste0(bs, c("midrule", "endhead",
          "midrule", "endfoot", "bottomrule", "endlastfoot")), paper_table_rows(data),
        paste0(bs, "end{longtable}"))
    }) |> unlist(use.names = FALSE),
    paste0(bs, "par", bs, "noindent{", bs, "footnotesize", bs, "textit{Notes.} ",
      latex_escape(notes), "}", bs, "par"), "}")
  writeLines(lines, file.path(PAPER_TABLES_DIR, paste0(filename, ".tex")), useBytes = TRUE)
}

write_paper_etr_table <- function() {
  levels <- c(L1_Host_Average = "L1 Host average", L2_Bilateral_Cell_Average = "L2 Bilateral average",
    L3_Host_Pooled_Distributional = "L3 Host pooled", L4_bilat_anchored = "L4 Anchored",
    L4_strict_no_transport = "L4 Strict")
  ladder <- paper_read("step9_ladder_stage1_stage2_summary") |>
    filter(record_type == "summary", window %in% c("2017–2023", "FY2023"), level %in% names(levels)) |>
    transmute(scope, window, level = unname(levels[level]), share = paper_pct(low_share),
      gap = paper_pct(topup_gap), rate = paper_pct(liability_rate), tax = paper_number(stage2_topup_usd_bn_initial))
  cv <- paper_read("step3_stage1_crossval_summary") |>
    filter(statistic %in% c("n", "median_gap", "mae", "calibration_r_squared"),
      outcome %in% c("low_share", "liability_rate")) |>
    select(sample, estimator, outcome, statistic, value) |>
    pivot_wider(names_from = statistic, values_from = value) |>
    mutate(sample = recode(sample, unmatched_affiliate_year = "S1 Pooled",
      parent_restricted_affiliate_year = "S2 Restricted", exact_bilateral = "S3 Bilateral")) |>
    arrange(sample, outcome, estimator) |>
    transmute(sample, outcome = if_else(outcome == "low_share", "Low share", "Liability"),
      fit = if_else(estimator == "uncapped", "Uncapped", "Capped"), n = fmt_int(n),
      bias = paper_pct(median_gap), error = paper_pct(mae), r2 = paper_number(calibration_r_squared, 3))
  write_paper_float_table("tab_v2_etr_ladder_and_crossval", "ETR aggregation and Table IV validation", list(
    "A. Measurement ladder" = paper_panel(c("Scope", "Window", "Level", "Low share (%)",
      "Gap (pp)", "Liability (%)", "Post-SBIE"), ladder),
    "B. Table I percentile validation" = paper_panel(c("Sample", "Outcome", "Fit", "N",
      "Bias (pp)", "MAE (pp)", "R-squared"), cv)),
    "Post-SBIE liability is in US$ bn at initial carve-out rates. Validation uses FY2021–2023. Bias is the median fitted minus direct estimate. The cap is the host statutory rate plus the loss-offset allowance, bounded at 100%.",
    align = list("A. Measurement ladder" = "lllrrrr", "B. Table I percentile validation" = "lllrrrr"))
}

write_paper_substance_table <- function() {
  shield <- paper_read("step4_stage2_sbti_vs_sectoral_sbie_decomposition") |>
    filter(affiliate == "EU27", etr_measurement == "distributional") |>
    arrange(year, rate_scenario) |>
    transmute(year, rate_scenario = paper_rates(rate_scenario), aggregate = paper_pct(aggregate_sbie_per_profit),
      sector = paper_pct(sectoral_sbie_per_profit), sbti = paper_pct(sectoral_sbie_sbti_per_profit),
      coverage = paper_pct(comparable_profit_share, 1))
  bracket <- paper_read("audit_step4_stage2_bracket_substance") |>
    filter(section == "paired_tests", scope %in% c("Global", "EU27"),
      t4_sample == "exclude_BRA_parent_FY2021") |>
    transmute(scope, cell = if_else(level == "bilateral", "Bilateral", "Host-year"),
      rate_scenario = paper_rates(rate_scenario), pairs = fmt_int(n_pairs), low = paper_pct(mean_phi_low, 1),
      high = paper_pct(mean_phi_high, 1), wilcoxon = paper_p(wilcoxon_p_two_sided),
      fe = paper_pct(fe_estimate), p = paper_p(fe_clustered_p))
  h5 <- paper_read("step4_stage2_sectoral_h5_panel_regression") |>
    filter(sample == "pooled_2021_2023") |>
    transmute(rate_scenario = paper_rates(rate_scenario), weights = if_else(model_variant == "profit_weighted", "Profit", "Equal"),
      coef = paper_number(estimate, 4), se = paper_number(std_error, 4),
      p = paper_p(p_value), n = fmt_int(n_obs), clusters = fmt_int(n_clusters))
  panels <- list(
    "A. EU27 top-up per unit of profit" = paper_panel(c("Year", "Rates", "Aggregate (%)",
      "Sectoral (%)", "With SBTI (%)", "Comparable profit (%)"), shield),
    "B. Paired Table IV substance shields" = paper_panel(c("Scope", "Cell", "Rates", "Pairs",
      "Low (%)", "High (%)", "Wilcoxon p", "FE (pp)", "FE p"), bracket),
    "C. Capital intensity, pooled FY2021–2023" = paper_panel(c("Rates", "Weights", "Coef.", "SE", "p", "N", "Clusters"), h5))
  write_paper_table("tab_v2_stage2_sbti_and_bracket_substance", "Substance carve-out and safe harbour", panels,
    "Panel A compares sectoral SBIE at zero SBTI with the SBTI overlay on common support. Panel B excludes Brazil-parent FY2021 and uses affiliate-clustered fixed-effect inference. Panel C uses affiliate-by-year effects and affiliate-clustered standard errors.")
  write_paper_float_table("tab_v2_main_table3_substance_and_sbti", "Substance carve-out and safe harbour", panels[1:2],
    "Panel A compares sectoral SBIE at zero SBTI with the SBTI overlay on common support. Panel B excludes Brazil-parent FY2021 and uses affiliate-clustered fixed-effect inference. The capital-intensity regression is in Online Appendix B.",
    align = list("A. EU27 top-up per unit of profit" = "llrrrr", "B. Paired Table IV substance shields" = "lllrrrrrr"))
  write_paper_table("tab_v2_app_table3_h5_regression", "Capital intensity and the SBTI-induced floor reduction",
    list("Capital intensity, pooled FY2021–2023" = panels[[3]]),
    "Affiliate-by-year effects and affiliate-clustered standard errors. The dependent variable is the SBTI-induced reduction in the effective floor.")
}

write_paper_econometrics_table <- function() {
  tax <- c(current_etr = "Current", lagged_etr = "Lagged", jackknife_etr = "Jackknife")
  methods <- c(fe_ols = "FE-OLS", fe_wls = "FE-WLS", fe_ppml_positive = "FE-PPML")
  x <- paper_read("step6_division_bias_and_curvature_audit")
  elasticity <- x |>
    filter(sample == "available", activity == "current", regressor %in% names(tax),
      statistic_type == "semi_elasticity", bic_winner, tau_eval %in% c(.05, .10, .15)) |>
    mutate(etr = unname(tax[regressor]), method = unname(methods[estimator]),
      form = tools::toTitleCase(model_spec), value = paper_number(estimate, 2),
      at = factor(tau_eval, levels = c(.05, .10, .15))) |>
    select(etr, method, form, n, bic, at, value) |>
    pivot_wider(names_from = at, values_from = value, names_expand = TRUE) |>
    mutate(n = fmt_int(n), bic = paper_bic(bic))
  matched <- x |>
    filter(sample %in% c("matched_lagged_etr", "matched_jackknife_etr"),
      regressor %in% names(tax), statistic_type == "semi_elasticity", bic_winner, tau_eval == .05) |>
    transmute(support = recode(sample, matched_lagged_etr = "Lagged", matched_jackknife_etr = "Jackknife"),
      etr = unname(tax[regressor]), method = unname(methods[estimator]),
      form = tools::toTitleCase(model_spec), n = fmt_int(n), at5 = paper_number(estimate),
      se = paper_number(std_error), p = paper_p(joint_tax_wald_p))
  iv <- paper_read("step5_stage3_tax_endogeneity_diagnostics") |>
    filter(inference == "parent_affiliate_clustered", grepl("_2sls_", diagnostic)) |>
    transmute(instrument_label, f = paper_number(weak_instrument_f), coef = paper_number(estimate, 3),
      se = paper_number(std_error, 3), p = paper_p(p_value), n = fmt_int(n))
  write_paper_float_table("tab_v2_stage3_division_bias_and_ppml", "Division bias and profit semi-elasticities", list(
    "A. BIC winners by estimator and available sample" = paper_panel(c("ETR", "Estimator", "Form",
      "N", "BIC", "At 5%", "At 10%", "At 15%"), elasticity),
    "B. Current versus alternative ETR on matched support" = paper_panel(c("Support", "ETR",
      "Estimator", "Form", "N", "At 5%", "SE", "Joint p"), matched),
    "C. Tax-code instrument diagnostics" = paper_panel(c("Instrument", "First-stage F",
      "2SLS coefficient", "SE", "p", "N"), iv)),
    "Semi-elasticities are the negative of the profit slope. BIC is compared within an estimator and sample. FE-WLS uses fixed pair-mean profit weights and PPML here uses positive profit in USD. Standard errors cluster on parent and affiliate. IV coefficients retain their signed scale. The alternative ETRs remove the current own-profit denominator.",
    align = list("A. BIC winners by estimator and available sample" = "lllrrrrr",
      "B. Current versus alternative ETR on matched support" = "llllrrrr"))
}

write_paper_variance_table <- function() {
  factors <- c(x1_etr = "ETR", x2_substance = "Substance/SBTI", x2a_sectoral = "Sectoral SBIE",
    x2b_sbti = "SBTI", x3_rates = "Rates", x4_sbs = "SbS", x5_behaviour = "Behaviour",
    x6_accounting = "Accounting")
  stress <- paper_read("step7_decomposition_architecture_stress_test") |>
    filter(variant %in% c("A_baseline", "D_split_substance")) |>
    transmute(window = paste(start_year, end_year, sep = "–"),
      design = if_else(variant == "A_baseline", "Core 32", "Split SBTI 64"),
      factor = unname(factors[effect]), main = paper_pct(main_eta_squared),
      shapley = paper_pct(shapley_eta_squared))
  accounting <- paper_read("step15_globe_accounting_factorial_anova") |>
    filter(scope == "EU27", estimand == "pooled_country_year", record == "main_effect") |>
    transmute(window, design = if_else(design == "full_64", "Accounting 64", "Accounting 32"),
      etr = if_else(distributional_level == "L3", "L3", "L4 strict"), factor = unname(factors[effect]),
      main = paper_pct(main_eta_squared), shapley = paper_pct(shapley_eta_squared),
      dollars = paper_number(dollar_main_effect_usd_bn))
  mc <- paper_read("step15_law_of_total_variance_decomposition") |>
    filter(record == "total_variance") |>
    arrange(window, scope != "EU27", scope) |>
    transmute(scope, window, scenario = paper_pct(scenario_variance_share),
      parameter = paper_pct(parameter_variance_share), width = paper_number(preferred_width90_usd_bn),
      ratio = paper_number(proposal_ratio))
  write_paper_variance_profiles(stress, accounting, mc)
  write_paper_table("tab_v2_factorial_globe_and_total_variance", "Scenario and parameter uncertainty", list(
    "A1. Core and split-SBTI factorials" = paper_panel(c("Window", "Design", "Factor", "Main (%)",
      "Shapley (%)"), stress),
    "A2. Accounting factorials" = paper_panel(c("Window", "Design", "ETR", "Factor", "Main (%)",
      "Shapley (%)", "Effect (US$ bn)"), accounting),
    "B1. Law of total variance, 2017–2023" = paper_panel(c("Scope", "Window", "Scenario (%)", "Parameter (%)",
      "90% width (US$ bn)", "Proposal ratio"), filter(mc, window == "2017–2023")),
    "B2. Law of total variance, 2019–2023" = paper_panel(c("Scope", "Window", "Scenario (%)", "Parameter (%)",
      "90% width (US$ bn)", "Proposal ratio"), filter(mc, window == "2019–2023"))),
    "Panel A uses pooled EU27 country-year variation. Split SBTI and accounting are separate 64-scenario designs. The 32-scenario accounting design fixes initial carve-outs. Panel B uses 500 joint draws and 32 scenarios. The proposal ratio divides point scenario spread by the preferred scenario's 90% parameter interval width. The Monte Carlo has two windows.")
}

write_paper_ledger_table <- function() {
  groups <- paper_read("step7_eu27_institutional_regime_matrix") |> select(country, institutional_group)
  cit <- paper_read("step7_reallocation_destination_rules_comparison") |>
    filter(rule == "B", window == "2017–2023", scenario_id == "x10011", country %in% EU27_ISO3) |>
    select(country, gross_cit)
  ledger <- paper_read("step7_eu27_source_vs_collector_ledger_2017_2023") |>
    filter(scenario_id == "x10011") |>
    left_join(groups, by = "country", relationship = "one-to-one") |>
    left_join(cit, by = "country", relationship = "one-to-one") |>
    arrange(institutional_group, country)
  stopifnot(nrow(ledger) == 27L, !anyNA(ledger$gross_cit))
  allocation <- ledger |>
    transmute(country, institutional_group, generated = paper_bn(source_topup_liability),
      retained = paper_bn(source_retained_qdmtt + source_domestic_iir + source_domestic_utpr),
      iir = paper_bn(source_exported_iir), utpr = paper_bn(source_exported_utpr),
      relief = paper_bn(source_sbs_extinguished))
  reports_unsupported <- "source_unsupported_utpr" %in% names(ledger)
  allocation_columns <- c("ISO", "Group", "Generated", "Retained", "IIR abroad", "UTPR abroad", "SbS relief")
  ledger_note <- "CYP, EST, LTU, LVA and MLT have zero baseline collector receipts."
  if (reports_unsupported) {
    allocation$unsupported <- paper_bn(ledger$source_unsupported_utpr)
    allocation_columns <- c(allocation_columns, "Unassigned")
    ledger_note <- paste("Unassigned is residual UTPR liability outside observed parent-year routing support.",
      "The UTPR collector map uses verified national applicability. R1, R2 and R3 vary source QDMTT and parent IIR.")
  }
  collector <- ledger |>
    transmute(country, qdmtt = paper_bn(collector_QDMTT), iir = paper_bn(collector_IIR),
      utpr = paper_bn(collector_UTPR), collected = paper_bn(collector_revenue),
      net = paper_bn(net_fiscal_position), cit = paper_bn(gross_cit),
      salience = paper_number(collector_revenue_pct_of_cit), spread = paper_bn(scenario_spread))
  regimes <- paper_read("step7_cyprus_and_article50_sensitivity") |>
    filter(start_year == 2017, end_year == 2023, scenario_id == "x10011",
      country %in% c("EU27", "CYP", "EST", "LTU", "LVA", "MLT")) |>
    mutate(regime = substr(regime, 1, 2), revenue = paper_bn(collector_revenue, 3)) |>
    select(country, regime, revenue) |>
    pivot_wider(names_from = regime, values_from = revenue, names_sort = TRUE)
  panels <- list(
    "A. Liability generated and routed from source" = paper_panel(allocation_columns, allocation),
    "B. Collector receipts, ordinary CIT and scenario spread" = paper_panel(c("ISO", "QDMTT", "IIR",
      "UTPR", "Collected", "Net", "Rule B CIT", "CIT (%)", "Spread"), collector),
    "C. Qualification and adoption sensitivities" = paper_panel(c("ISO", "R1", "R2", "R3"), regimes))
  write_paper_float_table("tab_v2_main_table7_source_collector_ledger", "Source liability and collector receipts", panels[1:2],
    paste("Cumulative 2017–2023, US$ bn, preferred behavioural SbS scenario. Net is collected minus source liability. Rule B CIT is gross induced ordinary CIT. Groups are high-salience sources (1), QDMTT-protected collectors (2), residual IIR/UTPR collectors (3), and Article 50 fiscal exporters (4).", ledger_note,
      "Qualification sensitivities are in Online Appendix E."),
    align = list("A. Liability generated and routed from source" = if (reports_unsupported) "llrrrrrr" else "llrrrrr"),
    size = "scriptsize")
  write_paper_table("tab_v2_app_table7_regime_sensitivities", "Qualification and adoption sensitivities",
    list("Collector revenue under alternative legal regimes" = panels[[3]]),
    "Cumulative 2017–2023, US$ bn, preferred behavioural SbS scenario. R1 is the observed qualification baseline. R2 activates Cyprus under Law 151(I)/2024. R3 assumes full EU27 QDMTT and IIR adoption.")
  write_paper_table("tab_v2_source_collector_ledger_and_regimes", "Source liability and collector receipts", panels,
    paste("Cumulative 2017–2023, US$ bn, preferred behavioural SbS scenario. Net is collected minus source liability. Rule B CIT is gross induced ordinary CIT. Groups are high-salience sources (1), QDMTT-protected collectors (2), residual IIR/UTPR collectors (3), and Article 50 fiscal exporters (4).", ledger_note,
      "R2 activates Cyprus under Law 151(I)/2024. R3 assumes full EU27 QDMTT and IIR adoption."))
}

write_paper_nash_table <- function() {
  matrix <- paper_read("step13_unilateral_qdmtt_deviation_matrix") |>
    filter(level == "L3_pooled", window == "FY2023")
  reports_unsupported <- "host_unsupported_utpr" %in% names(matrix)
  residual_note <- "Unassigned denotes the deviating host's residual UTPR liability without modelled routing support. Source relief measures the decline in modelled source liability."
  format_deviations <- function(data) {
    formatted <- data |>
      arrange(country, regime) |>
      transmute(country, regime, qdmtt = paper_bn(-delta_qdmtt, 3), foreign = paper_bn(foreign_soakup, 3),
        tax_cut = paper_bn(mne_topup_saved, 3), efficiency = paper_pct(tax_cut_efficiency, 1),
        retained = paper_bn(retained_profit, 3), weight = paper_number(critical_welfare_weight, 3))
    if (reports_unsupported) {
      formatted$unassigned <- paper_bn(arrange(data, country, regime)$host_unsupported_utpr, 3)
    }
    formatted
  }
  deviations <- format_deviations(filter(matrix, deviation == "qdmtt_repeal"))
  strategy <- paper_read("step13_qdmtt_vs_sbti_strategy_comparison") |>
    filter(level == "L3_pooled", window == "FY2023") |>
    transmute(country, capacity = paper_bn(maximum_capacity_proxy, 3),
      repeal = paper_bn(repeal_topup_relief, 3), sbti = paper_bn(overlay_topup_relief, 3),
      leakage = paper_bn(overlay_foreign_leakage, 3), efficiency = paper_pct(overlay_efficiency, 1))
  relief_label <- if (reports_unsupported) "Source relief" else "MNE tax cut"
  deviation_columns <- c("ISO", "Regime", "QDMTT lost", "Foreign soak-up", relief_label,
    "Efficiency (%)", "Retained", "Critical weight")
  strategy_panel <- paper_panel(c("ISO", "Capacity", "Repeal relief", "SBTI relief", "Leakage",
    "SBTI efficiency (%)"), strategy)
  compact_columns <- c("ISO", "QDMTT lost", "Soak-up", relief_label, "Efficiency (%)", "Retained", "Weight")
  if (reports_unsupported) {
    deviation_columns <- c(deviation_columns, "Unassigned")
    compact_columns <- c(compact_columns, "Unassigned")
  }
  sbs_repeal <- filter(deviations, regime == "SbS")
  stopifnot(nrow(sbs_repeal) == 27L)
  write_paper_float_table("tab_v2_main_table8_qdmtt_repeal_game", "Unilateral QDMTT repeal and capped SBTI", list(
    "A. Repeal under Side-by-Side" = paper_panel(compact_columns, select(sbs_repeal, -regime)),
    "B. Side-by-Side repeal versus maximum SBTI overlay" = strategy_panel),
    paste(c("FY2023, L3, full EU27 adoption benchmark, US$ bn unless shown otherwise. Repeal holds the deviator's IIR and UTPR status fixed. Soak-up is the forgone QDMTT collected by foreign IIR and UTPR. Weight is the critical welfare weight, net domestic tax foregone per unit of retained profit. Under the Universal regime repeal yields no MNE tax cut in any state; those rows are in Online Appendix E. The SBTI overlay represents a capacity proxy. Its relief efficiency is distinct from the fiscal cost of new qualifying incentives.",
      if (reports_unsupported) residual_note), collapse = " "),
    size = "scriptsize")
  universal <- filter(deviations, regime == "Universal")
  opt_out <- format_deviations(filter(matrix, deviation == "full_opt_out"))
  stopifnot(nrow(universal) == 27L, nrow(opt_out) == 54L)
  write_paper_table("tab_v2_app_table8_universal_and_optout", "QDMTT repeal under Universal and full opt-out", list(
    "A. QDMTT repeal under the Universal regime" = paper_panel(compact_columns, select(universal, -regime)),
    "B. Full opt-out under Universal and Side-by-Side" = paper_panel(c("ISO", "Regime", compact_columns[-1]), opt_out)),
    paste(c("FY2023, L3, full EU27 adoption benchmark, US$ bn unless shown otherwise. Panel A holds the deviator's IIR and UTPR status fixed. Full opt-out also switches off the deviator's own IIR and UTPR. Soak-up is the forgone revenue collected by foreign IIR and UTPR. Weight is the critical welfare weight, net domestic tax foregone per unit of retained profit; it is infinite when the deviation yields no MNE tax cut. The 2017–2023 window and the L4 strict ladder are in the diagnostics CSV.",
      if (reports_unsupported) residual_note), collapse = " "))
  write_paper_table("tab_v2_qdmtt_nash_deviation_game", "Unilateral QDMTT repeal and capped SBTI", list(
    "A. Repeal under Universal and Side-by-Side" = paper_panel(deviation_columns, deviations),
    "B. Side-by-Side repeal versus maximum SBTI overlay" = strategy_panel),
    paste(c("FY2023, L3, full EU27 adoption benchmark, US$ bn unless shown otherwise. Repeal holds the deviator's IIR and UTPR status fixed. The critical welfare weight uses net domestic tax foregone and retained profit. The SBTI overlay represents a capacity proxy. Its relief efficiency is distinct from the fiscal cost of new qualifying incentives.",
      if (reports_unsupported) residual_note), collapse = " "))
}

paper_scope_label <- function(x) {
  recode(x, EU27_hosts = "EU27 hosts", EU27_parents = "EU27 parents", USA_parents = "US parents",
    USA_EU27 = "US–EU27")
}

write_paper_cbcr_table <- function() {
  blending <- paper_read("step14_table3_vs_table4_blending_wedge") |>
    filter(record == "matched_summary", resolution == "bilateral", sample == "matched_observed_partitions",
      window == "2019–2023", scope %in% c("Global", "EU27", "USA_EU27", PAPER_BUDGET_COUNTRIES)) |>
    filter(!is.na(group_share_common)) |>
    transmute(scope = paper_scope_label(scope), n = fmt_int(matched_pair_years), group = paper_pct(group_share_common),
      juris = paper_pct(juris_share_common), gap = paper_pct(juris_share_common - group_share_common),
      low = paper_bn(hidden_lb_share_times_weight_usd), high = paper_bn(hidden_ub_share_times_weight_usd))
  size <- paper_read("step14_table6_mne_size_incidence") |>
    filter(record == "size_summary", sample == "complete_fine", window == "2022–2023",
      scope %in% c("Global", "EU27_hosts", "USA_parents", "EU27_parents"), !is.na(positive_cell_profit_usd_share)) |>
    transmute(scope = paper_scope_label(scope), size = recode(size_class, size_less_2_5 = "Below 2.5", size_2_5_5 = "2.5–5",
      size_5_10 = "5–10", size_greater_10 = "Above 10"),
      profit = paper_pct(positive_cell_profit_usd_share, 1), etr = paper_pct(positive_cell_etr, 1),
      shield = paper_pct(phi_initial, 1), topup = paper_pct(post_sbie_initial_rate))
  iqm <- paper_read("step14_table2_interquartile_skewness") |>
    filter(record == "matched_summary", sample == "same_counts_multiple_of_4_min_8",
      window == "2018–2023", scope %in% c("Global", "EU27")) |>
    transmute(scope, n = fmt_int(tail_proxy_n), etr = paper_pct(profit_weighted_etr_gap),
      tails = paper_pct(outer_both_tails_weighted_proxy, 1),
      low = paper_pct(upper_tail_weighted_lb_conditional, 1), high = paper_pct(upper_tail_weighted_ub_conditional, 1))
  activity <- paper_read("step14_business_activity_drivers") |>
    filter(record == "activity_regression", term == "act_holding_panelai", fixed_effects == "affiliate^year",
      !is.na(outcome_pp_per_10pp_activity)) |>
    transmute(scope = paper_scope_label(scope),
      outcome = if_else(toupper(outcome) == "PHI", paper_raw("Shield ratio ($\\phi$)"), toupper(outcome)), estimate = paper_number(outcome_pp_per_10pp_activity, 3),
      se = paper_number(se_pp_per_10pp_activity, 3), p = paper_p(p_value_holm_within_model))
  write_paper_float_table("tab_v2_cbcr_tables_2_3_6_extensions", "CbCR blending, size, skewness and holding activity", list(
    "A. Group versus jurisdictional blending" = paper_panel(c("Scope", "Pair-years", "Group (%)",
      "Jurisdiction (%)", "Gap (pp)", "Hidden lower", "Hidden upper"), blending),
    "B. Size-class incidence" = paper_panel(c("Scope", "Size", "Profit share (%)",
      "ETR (%)", "Shield (%)", "Top-up (%)"), size),
    "C. Table II interquartile core" = paper_panel(c("Scope", "Cells", "ETR gap (pp)",
      "Outer tails (%)", "Top quartile low (%)", "Top quartile high (%)"), iqm),
    "D. Holding-activity slopes" = paper_panel(c("Scope", "Outcome", "Effect (pp)", "SE", "Holm p"), activity)),
    paste("Panel A uses common bilateral weights and reports Fréchet bounds on hidden profit in US$ bn. The joint allocation across margins is unobserved. Panel B uses complete fine partitions, with consolidated turnover bins in EUR bn and initial carve-outs. Panel C uses conditional bounds on the top quartile. Panel D reports changes per 10 percentage points of holding activity with host-year fixed effects.",
      "US-parent rows are absent from public Tables III and VI, so the US–EU27 blending row and the US-parent size rows are omitted. Host-year fixed effects absorb the host-pooled L3 rate in Panel D, so its L3 rows are omitted."),
    align = list("B. Size-class incidence" = "llrrrr", "D. Holding-activity slopes" = "llrrr"),
    placement = "H")
}

make_paper_nash_figure <- function() {
  data <- paper_read("step13_qdmtt_vs_sbti_strategy_comparison") |>
    filter(level == "L3_pooled", window == "FY2023") |>
    arrange(repeal_tax_cut_efficiency, country) |>
    mutate(country = factor(country, levels = country)) |>
    select(country, repeal_tax_cut_efficiency, overlay_efficiency)
  stopifnot(nrow(data) == 27L)
  long <- data |>
    pivot_longer(-country, names_to = "strategy", values_to = "efficiency") |>
    mutate(strategy = recode(strategy, repeal_tax_cut_efficiency = "QDMTT repeal under SbS",
      overlay_efficiency = "Capped SBTI overlay"))
  ggplot2::ggplot(long, ggplot2::aes(efficiency, country)) +
    ggplot2::geom_segment(data = data, ggplot2::aes(x = repeal_tax_cut_efficiency, xend = overlay_efficiency,
      y = country, yend = country), inherit.aes = FALSE, colour = "#C9D2D9", linewidth = .5) +
    ggplot2::geom_point(ggplot2::aes(colour = strategy, shape = strategy), size = 2.2) +
    ggplot2::scale_colour_manual(values = c("QDMTT repeal under SbS" = "#174C70", "Capped SBTI overlay" = "#A54633"),
      name = NULL) +
    ggplot2::scale_shape_manual(values = c("QDMTT repeal under SbS" = 16, "Capped SBTI overlay" = 17), name = NULL) +
    ggplot2::scale_x_continuous(labels = scales::label_percent(), breaks = seq(0, 1, .25),
      expand = ggplot2::expansion(add = .025)) +
    ggplot2::labs(x = "Relief efficiency", y = NULL) +
    ggplot2::theme_minimal(base_size = 10, base_family = "serif") +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(), panel.grid.major.y = ggplot2::element_blank(),
      legend.position = "top", plot.margin = ggplot2::margin(10, 16, 12, 10))
}

# Single-page float for main-text tables: one table counter step and one caption.
write_paper_float_table <- function(filename, title, panels, notes, align = list(),
                                    placement = "htbp", size = "footnotesize", output_dir = PAPER_TABLES_DIR) {
  bs <- intToUtf8(92L)
  end_row <- paste0(" ", bs, bs)
  body <- purrr::imap(panels, function(data, panel) {
    spec <- if (is.null(align[[panel]])) paste0("l", strrep("r", ncol(data) - 1)) else align[[panel]]
    c(paste0(bs, "begin{tabular}{@{}", spec, "@{}}"),
      paste0(bs, "multicolumn{", ncol(data), "}{@{}l}{", bs, "textbf{", latex_escape(panel), "}}", end_row),
      paste0(bs, "toprule"), paste0(paste(latex_escape(names(data)), collapse = " & "), end_row),
      paste0(bs, "midrule"), paper_table_rows(data), paste0(bs, "bottomrule"), paste0(bs, "end{tabular}"),
      paste0(bs, "par", bs, "vspace{0.6em}"))
  }) |> unlist(use.names = FALSE)
  lines <- c("% Generated by code/13_generate_exhibits.R", "% Requires booktabs and array.",
    paste0(bs, "begin{table}[", placement, "]"), paste0(bs, "centering"), paste0(bs, size),
    paste0(bs, "caption{", latex_escape(title), "}", bs, "label{tab:", filename, "}"), body,
    paste0(bs, "begin{minipage}{", bs, "textwidth}", bs, "footnotesize", bs, "raggedright", bs,
      "textit{Notes.} ", latex_escape(notes), bs, "end{minipage}"),
    paste0(bs, "end{table}"))
  writeLines(lines, file.path(output_dir, paste0(filename, ".tex")), useBytes = TRUE)
}

write_paper_main_table1 <- function(sample_rows, coverage_rows) {
  dir.create(PAPER_TABLES_DIR, recursive = TRUE, showWarnings = FALSE)
  dash <- intToUtf8(8211L)
  sample <- sample_rows |>
    mutate(across(c(Sample, `Main use`), ~ gsub("--", dash, .x, fixed = TRUE)))
  write_paper_float_table("tab_v2_main_table1_sample_and_coverage", "Sample construction and panel coverage", list(
    "A. Sample construction" = paper_panel(c("Sample", "Obs.", "Parents", "Affiliates",
      "Share (%)", "Main use"), sample),
    "B. Coverage by fiscal year, 2017–2023" = paper_panel(c("Year", "Pair-years", "Parents",
      "Affiliates", "Positive", "EU27", "Profit", "Low-taxed", "ETR (%)"), coverage_rows)),
    "Share is relative to the 2017–2023 analytical panel. Positive and EU27 count pair-years with positive corrected profit and with an EU27 affiliate. Profit and low-taxed profit are corrected positive profit in US$ bn. ETR is the median effective tax rate over positive-profit pair-years.",
    align = list("A. Sample construction" =
      ">{\\raggedright\\arraybackslash}p{4.2cm}rrrr>{\\raggedright\\arraybackslash}p{3.9cm}"),
    placement = "t")
}

write_paper_variance_profiles <- function(stress, accounting, mc) {
  main_windows <- c("2017–2023", "2019–2023")
  main_accounting <- accounting$design == "Accounting 64" & accounting$window %in% main_windows
  write_paper_float_table("tab_v2_main_table5_variance_and_uncertainty", "Scenario and parameter uncertainty", list(
    "A1. Core 32-scenario factorial" = paper_panel(c("Window", "Design", "Factor", "Main (%)",
      "Shapley (%)"), filter(stress, design == "Core 32")),
    "A2. Accounting 64-scenario factorial" = paper_panel(c("Window", "Design", "ETR", "Factor",
      "Main (%)", "Shapley (%)", "Effect (US$ bn)"), accounting[main_accounting, ]),
    "B. Law of total variance, EU27" = paper_panel(c("Scope", "Window", "Scenario (%)", "Parameter (%)",
      "90% width (US$ bn)", "Proposal ratio"), filter(mc, scope == "EU27"))),
    "Panel A uses pooled EU27 country-year variation. The accounting design adds the CbCR-to-GloBE bridge as a sixth factor. Panel B uses 500 joint draws and 32 scenarios. The proposal ratio divides point scenario spread by the preferred scenario's 90% parameter interval width. Split-SBTI, 32-scenario accounting, 2021–2023 accounting and member-state rows are in Online Appendix D.",
    align = list("A1. Core 32-scenario factorial" = "lllrr", "A2. Accounting 64-scenario factorial" = "llllrrr",
      "B. Law of total variance, EU27" = "llrrrr"))
  write_paper_table("tab_v2_app_table5_country_uncertainty", "Further factorial designs and member-state uncertainty", list(
    "A. Split-SBTI 64-scenario factorial" = paper_panel(c("Window", "Design", "Factor", "Main (%)",
      "Shapley (%)"), filter(stress, design == "Split SBTI 64")),
    "B. Remaining accounting designs and windows" = paper_panel(c("Window", "Design", "ETR", "Factor",
      "Main (%)", "Shapley (%)", "Effect (US$ bn)"), accounting[!main_accounting, ]),
    "C. Law of total variance by member state, 2017–2023" = paper_panel(c("Scope", "Window",
      "Scenario (%)", "Parameter (%)", "90% width (US$ bn)", "Proposal ratio"),
      filter(mc, window == "2017–2023", scope != "EU27")),
    "D. Law of total variance by member state, 2019–2023" = paper_panel(c("Scope", "Window",
      "Scenario (%)", "Parameter (%)", "90% width (US$ bn)", "Proposal ratio"),
      filter(mc, window == "2019–2023", scope != "EU27"))),
    "Panels A and B use pooled EU27 country-year variation. The 32-scenario accounting design fixes initial carve-outs. Panels C and D use 500 joint draws and 32 scenarios; the five zero-collector states have no revenue variance.")
}

forcats_rev <- function(x) factor(x, levels = rev(levels(x)))

make_paper_shapley_figure <- function() {
  factors <- c(x1_etr = "ETR measurement", x6_accounting = "Accounting bridge", x4_sbs = "Side-by-Side",
    x5_behaviour = "Behaviour", x2_substance = "Substance and SBTI", x3_rates = "Carve-out rates")
  windows <- c("2017–2023", "2019–2023")
  designs <- c("Core design, 32 scenarios", "Accounting bridge, L3", "Accounting bridge, L4 strict")
  core <- paper_read("step7_decomposition_architecture_stress_test") |>
    filter(variant == "A_baseline") |>
    transmute(window = paste(start_year, end_year, sep = "–"), design = designs[1], effect,
      shapley = shapley_eta_squared)
  accounting <- paper_read("step15_globe_accounting_factorial_anova") |>
    filter(scope == "EU27", estimand == "pooled_country_year", record == "main_effect", design == "full_64") |>
    transmute(window, design = if_else(distributional_level == "L3", designs[2], designs[3]), effect,
      shapley = shapley_eta_squared)
  data <- bind_rows(core, accounting) |>
    filter(window %in% windows, effect %in% names(factors)) |>
    mutate(factor = factor(unname(factors[effect]), levels = rev(unname(factors))),
      design = factor(design, levels = designs), window = factor(window, levels = windows),
      label = if_else(shapley >= .10, paste0(format(round(100 * shapley, 1), nsmall = 1), "%"), NA_character_))
  stopifnot(nrow(data) == 2L * 5L + 2L * 2L * 6L, !anyNA(data$shapley))
  dodge <- ggplot2::position_dodge(width = .78)
  ggplot2::ggplot(data, ggplot2::aes(shapley, factor, fill = window, group = forcats_rev(window))) +
    ggplot2::geom_col(position = dodge, width = .72, colour = "white", linewidth = .4) +
    ggplot2::geom_text(ggplot2::aes(label = label), position = dodge, hjust = -.15, size = 2.7,
      colour = "#3B3B3B", na.rm = TRUE) +
    ggplot2::facet_wrap(~design, nrow = 1) +
    ggplot2::scale_fill_manual(values = c("2017–2023" = "#2A6DB0", "2019–2023" = "#B5543A"), name = NULL) +
    ggplot2::scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1),
      breaks = seq(0, .8, .2), expand = ggplot2::expansion(mult = c(0, .02))) +
    ggplot2::labs(x = "Share of pooled country-year variance", y = NULL) +
    ggplot2::theme_minimal(base_size = 10, base_family = "serif") +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(), panel.grid.major.y = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold"), legend.position = "top",
      panel.spacing.x = grid::unit(1.2, "lines"), plot.margin = ggplot2::margin(10, 16, 12, 10))
}

# Numbered entry points preserve existing labels and the historical filenames.
# Appendix 4 expands the behavioural table; Appendix 6 lists the scenarios
# underlying the revenue ranges. Copy the generated bytes, never hand-edit them.
paper_fragment_aliases <- function() c(
  tab_v2_main_table2_etr_ladder_and_crossval = "paper_v2_tables/tab_v2_etr_ladder_and_crossval.tex",
  tab_v2_main_table4_division_bias_and_ppml = "paper_v2_tables/tab_v2_stage3_division_bias_and_ppml.tex",
  tab_v2_main_table6_budget_backtest_and_waterfall = "paper_v2_tables/tab_v2_budget_backtest_and_hanlon_waterfall.tex",
  tab_v2_app_table4_behavioural_robustness = "results_tables/appendix_stage3_robustness.tex",
  tab_v2_app_table6_revenue_scenarios = "results_tables/appendix_stage46_top_scenarios.tex"
)

write_paper_fragment_aliases <- function() {
  aliases <- paper_fragment_aliases()
  for (name in names(aliases)) {
    copied <- file.copy(file.path(GENERATED_DIR, aliases[[name]]),
      file.path(PAPER_TABLES_DIR, paste0(name, ".tex")), overwrite = TRUE)
    if (!copied) stop("Could not generate numbered paper fragment: ", name)
  }
}

write_paper_v2_exhibits <- function() {
  dir.create(PAPER_TABLES_DIR, recursive = TRUE, showWarnings = FALSE)
  dir.create(PAPER_FIGURES_DIR, recursive = TRUE, showWarnings = FALSE)
  write_paper_etr_table()
  write_paper_substance_table()
  write_paper_econometrics_table()
  write_paper_variance_table()
  write_paper_ledger_table()
  budget_inputs <- read_budget_waterfall_inputs(paper_read)
  budget <- paper_budget_rows(budget_inputs$budget)
  waterfall <- paper_waterfall_rows(budget_inputs$waterfall)
  write_paper_budget_tables(budget_inputs$budget, waterfall, output_dir = PAPER_TABLES_DIR,
    format_number = paper_number, write_table = write_paper_float_table)
  write_paper_nash_table()
  write_paper_cbcr_table()
  write_paper_fragment_aliases()
  ggplot2::ggsave(file.path(PAPER_FIGURES_DIR, "fig_v2_cbcr_to_budget_waterfall.pdf"),
    make_paper_waterfall_figure(budget, waterfall, budget_inputs$trend),
    width = 10, height = 6.5, device = grDevices::pdf)
  ggplot2::ggsave(file.path(PAPER_FIGURES_DIR, "fig_v2_qdmtt_deviation_efficiency_vs_sbti.pdf"),
    make_paper_nash_figure(), width = 7.4, height = 7.8, device = grDevices::pdf)
  ggplot2::ggsave(file.path(PAPER_FIGURES_DIR, "fig_v2_shapley_variance_core_and_accounting.pdf"),
    make_paper_shapley_figure(), width = 10, height = 4.6, device = grDevices::pdf, encoding = "WinAnsi.enc")
}

run_generate_exhibits <- function() {
  write_results_tables()
  run_generate_results_figures()
  write_paper_v2_exhibits()
}

if (is_direct_script_run("code/13_generate_exhibits.R")) {
  run_generate_exhibits()
}
