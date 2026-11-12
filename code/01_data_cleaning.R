# 01_data_cleaning.R
# Step 1 of the methodology pipeline.
#
# Reshapes the raw datasets collected by code/collect_all_data.py into tidy,
# analysis-ready intermediate tables in data/processed/.
library(dplyr)
library(tidyr)
library(readr)
library(purrr)
library(stringr)
library(tibble)
library(xml2)

source("code/00_helpers.R")

run_data_cleaning <- function(raw_dir = RAW_DIR, out_dir = PROCESSED_DIR) {
  raw_data_dir <- raw_dir
  processed_dir <- out_dir
  diagnostics_dir <- file.path(processed_dir, "diagnostics")
  dir.create(processed_dir, showWarnings = FALSE, recursive = TRUE)
  dir.create(diagnostics_dir, showWarnings = FALSE, recursive = TRUE)

  # Eurostat publishes inward FATS using its own 2-letter codes (UK, EL = Greece).
  # EU27_ISO2 keeps the 27 Member States in Eurostat code system for the FATS coverage check.
  EU27_ISO2 <- EU27_ISO2_EUROSTAT

  EUROSTAT_GEO_MAP <- tribble(
    ~geo, ~jurisdiction,
    "AT", "AUT", "BE", "BEL", "BG", "BGR", "CY", "CYP", "CZ", "CZE",
    "DE", "DEU", "DK", "DNK", "EE", "EST", "EL", "GRC", "ES", "ESP",
    "FI", "FIN", "FR", "FRA", "HR", "HRV", "HU", "HUN", "IE", "IRL",
    "IT", "ITA", "LT", "LTU", "LU", "LUX", "LV", "LVA", "MT", "MLT",
    "NL", "NLD", "PL", "POL", "PT", "PRT", "RO", "ROU", "SE", "SWE",
    "SI", "SVN", "SK", "SVK", "US", "USA", "UK", "GBR", "JP", "JPN"
  )

  BEA_COUNTRY_MAP <- tribble(
    ~country_or_region, ~jurisdiction,
    "Austria", "AUT",
    "Belgium", "BEL",
    "Bulgaria", "BGR",
    "Croatia", "HRV",
    "Cyprus", "CYP",
    "Czech Republic", "CZE",
    "Denmark", "DNK",
    "Estonia", "EST",
    "Finland", "FIN",
    "France", "FRA",
    "Germany", "DEU",
    "Greece", "GRC",
    "Hungary", "HUN",
    "Ireland", "IRL",
    "Italy", "ITA",
    "Latvia", "LVA",
    "Lithuania", "LTU",
    "Luxembourg", "LUX",
    "Malta", "MLT",
    "Netherlands", "NLD",
    "Poland", "POL",
    "Portugal", "PRT",
    "Romania", "ROU",
    "Slovakia", "SVK",
    "Slovenia", "SVN",
    "Spain", "ESP",
    "Sweden", "SWE",
    "Canada", "CAN",
    "United Kingdom", "GBR",
    "Switzerland", "CHE",
    "Norway", "NOR",
    "Japan", "JPN",
    "Australia", "AUS",
    "China", "CHN",
    "Mexico", "MEX",
    "Brazil", "BRA"
  )

  clean_name <- function(x) {
    x |>
      tolower() |>
      str_replace_all("[-[:space:]]", "_")
  }

  # OECD CbCR "EARNINGS" refers to accumulated earnings / retained earnings,
  # not payroll costs. Rename it explicitly here to avoid a misleading carry-over
  # into the merged panel and the later SBIE construction.
  measure_name <- function(x) {
    case_when(
      x == "EARNINGS" ~ "accumulated_earnings",
      TRUE ~ clean_name(x)
    )
  }

  read_oecd <- function(path) {
    read_csv(path,
      show_col_types = FALSE,
      col_types = cols(
        .default = col_guess(),
        TIME_PERIOD = col_integer(),
        OBS_VALUE = col_double()
      )
    )
  }

  panel_suffix <- function(p) {
    case_when(
      p == "PANELAI" ~ "_panelai",
      p == "PANELAII" ~ "_panelaii",
      TRUE ~ ""
    )
  }

  # Append a one-row tibble to the diagnostics list
  diagnostics <- list()
  add_diag <- function(dataset, metric, value) {
    diagnostics[[length(diagnostics) + 1L]] <<-
      tibble(dataset = dataset, metric = metric, value = as.character(value))
  }

  min_or_na <- function(x) {
    if (all(is.na(x))) {
      return(NA_real_)
    }
    min(x, na.rm = TRUE)
  }

  excel_col_to_int <- function(ref) {
    letters <- str_replace_all(ref, "[0-9]", "")
    vapply(strsplit(letters, ""), function(x) {
      sum(match(x, LETTERS) * 26^rev(seq_along(x) - 1L))
    }, numeric(1))
  }

  read_xlsx_sheet_names <- function(xlsx_path) {
    tmp <- tempfile("xlsx_names_")
    dir.create(tmp)
    utils::unzip(xlsx_path, exdir = tmp)
    wb <- read_xml(file.path(tmp, "xl/workbook.xml"))
    ns <- xml_ns(wb)
    xml_attr(xml_find_all(wb, ".//d1:sheets/d1:sheet", ns), "name")
  }

  read_xlsx_sheet_cells <- function(xlsx_path, sheet_index) {
    tmp <- tempfile("xlsx_cells_")
    dir.create(tmp)
    utils::unzip(xlsx_path, exdir = tmp)

    shared_path <- file.path(tmp, "xl/sharedStrings.xml")
    shared_strings <- character()
    if (file.exists(shared_path)) {
      shared_xml <- read_xml(shared_path)
      shared_ns <- xml_ns(shared_xml)
      shared_strings <- xml_text(xml_find_all(shared_xml, ".//d1:si", shared_ns))
    }

    sheet_xml <- read_xml(file.path(tmp, sprintf("xl/worksheets/sheet%d.xml", sheet_index)))
    sheet_ns <- xml_ns(sheet_xml)
    cells <- xml_find_all(sheet_xml, ".//d1:c", sheet_ns)
    ref <- xml_attr(cells, "r")
    type <- xml_attr(cells, "t")
    raw_value <- xml_text(xml_find_first(cells, "d1:v", sheet_ns))
    inline_value <- xml_text(xml_find_first(cells, "d1:is", sheet_ns))

    value <- case_when(
      type == "s" ~ shared_strings[as.integer(raw_value) + 1L],
      type == "inlineStr" ~ inline_value,
      TRUE ~ raw_value
    )
    value[value == ""] <- NA_character_

    tibble(
      row = as.integer(str_replace_all(ref, "[A-Z]", "")),
      col = excel_col_to_int(ref),
      value = value
    )
  }

  convert_xls_to_xlsx <- function(path) {
    soffice <- Sys.which("soffice")
    if (soffice == "") stop("LibreOffice soffice is required to convert BEA .xls files")

    out_dir <- tempfile("bea_xlsx_")
    dir.create(out_dir)
    system2(
      soffice,
      c("--headless", "--convert-to", "xlsx", "--outdir", out_dir, path),
      stdout = TRUE,
      stderr = TRUE
    )

    out_path <- file.path(out_dir, str_replace(basename(path), "\\.xls$", ".xlsx"))
    if (!file.exists(out_path)) stop(sprintf("BEA conversion failed for %s", basename(path)))
    out_path
  }

  clean_bea_numeric <- function(x) {
    parse_number(
      x,
      na = c("", "D", "(D)", "NA", "(NA)", "n.a.", "--", "...")
    )
  }

  parse_bea_country_industry_sheet <- function(path, sheet_name, measure, unit,
                                               year = NA_integer_) {
    xlsx_path <- if (str_ends(path, "\\.xls$")) convert_xls_to_xlsx(path) else path
    sheet_names <- read_xlsx_sheet_names(xlsx_path)
    sheet_index <- match(sheet_name, sheet_names)
    if (is.na(sheet_index)) stop(sprintf("Missing BEA sheet %s in %s", sheet_name, basename(path)))

    cells <- read_xlsx_sheet_cells(xlsx_path, sheet_index)
    data_start <- cells |>
      filter(col == 1, value == "All countries") |>
      summarise(row = min(row), .groups = "drop") |>
      pull(row)
    if (length(data_start) == 0 || is.infinite(data_start)) {
      stop(sprintf("Cannot locate BEA data body in %s / %s", basename(path), sheet_name))
    }

    number_row <- max(cells$row[cells$row < data_start &
      str_detect(coalesce(cells$value, ""), "^\\([0-9]+\\)$")])
    industry_cols <- cells |>
      filter(row == number_row, str_detect(coalesce(value, ""), "^\\([0-9]+\\)$")) |>
      arrange(col) |>
      pull(col)

    industry_lookup <- map_dfr(industry_cols, function(j) {
      label <- cells |>
        filter(
          col == j, row < number_row, !is.na(value),
          !value %in% c("Of which:", "Total")
        ) |>
        arrange(desc(row)) |>
        slice(1) |>
        pull(value)
      tibble(col = j, bea_industry = label)
    })

    country_rows <- cells |>
      filter(col == 1, row >= data_start, !is.na(value)) |>
      transmute(row, country_or_region = value)

    values <- cells |>
      filter(row %in% country_rows$row, col %in% industry_cols) |>
      left_join(country_rows, by = "row") |>
      left_join(industry_lookup, by = "col") |>
      transmute(
        source_file = basename(path),
        source_sheet = sheet_name,
        year = year,
        measure = measure,
        unit = unit,
        country_or_region,
        bea_industry,
        raw_value = value,
        suppression_code = if_else(raw_value %in% c("(D)", "(*)", "A"),
          raw_value, NA_character_
        ),
        value = clean_bea_numeric(raw_value)
      ) |>
      filter(!is.na(raw_value)) |>
      left_join(BEA_COUNTRY_MAP, by = "country_or_region") |>
      mutate(is_country = !is.na(jurisdiction))

    values
  }

  message("[1/15] CbCR Table I")
  # 1. CbCR Table I: aggregate totals and within-jurisdiction ETR percentiles
  t1_raw <- read_oecd(file.path(raw_data_dir, "oecd_cbcr/cbcr_table1_aggregate_totals.csv")) |>
    rename(
      parent = REF_AREA, affiliate = COUNTERPART_AREA, year = TIME_PERIOD,
      measure = MEASURE, panel = PROFIT_GROUPING,
      stat_op = STATISTICAL_OPERATION, value = OBS_VALUE
    )

  # Financial measures: Profit / Tax_accrued split across Panel A-I (profit-makers)
  # and Panel A-II (all entities); activity & entity counts arrive panel-agnostic.
  t1_fin <- t1_raw |>
    filter(measure != "ETR") |>
    mutate(varname = paste0(measure_name(measure), panel_suffix(panel))) |>
    select(parent, affiliate, year, varname, value) |>
    pivot_wider(names_from = varname, values_from = value)

  # ETR percentiles (the only distributional moments published by the OECD).
  t1_etr <- t1_raw |>
    filter(measure == "ETR") |>
    mutate(varname = paste0("etr_", tolower(stat_op), panel_suffix(panel))) |>
    select(parent, affiliate, year, varname, value) |>
    pivot_wider(names_from = varname, values_from = value)

  cbcr_t1 <- full_join(t1_fin, t1_etr, by = c("parent", "affiliate", "year")) |>
    arrange(parent, affiliate, year)

  assert_unique_keys(cbcr_t1, c("parent", "affiliate", "year"), "T1")
  saveRDS(cbcr_t1, file.path(processed_dir, "cbcr_table1.rds"))

  add_diag("cbcr_t1", "rows", nrow(cbcr_t1))
  add_diag("cbcr_t1", "parent_jurisdictions", n_distinct(cbcr_t1$parent))
  add_diag("cbcr_t1", "affiliate_jurisdictions", n_distinct(cbcr_t1$affiliate))
  add_diag("cbcr_t1", "year_range", paste(range(cbcr_t1$year), collapse = "-"))
  add_diag(
    "cbcr_t1", "zero_profit_panelai",
    sum(cbcr_t1$profit_panelai == 0, na.rm = TRUE)
  )
  add_diag(
    "cbcr_t1", "negative_profit_panelai",
    sum(cbcr_t1$profit_panelai < 0, na.rm = TRUE)
  )
  add_diag(
    "cbcr_t1", "missing_etr_p50_panelai_share",
    round(mean(is.na(cbcr_t1$etr_p50_panelai)), 3)
  )
  add_diag(
    "cbcr_t1", "etr_p50_panelai_first_year_with_data",
    min_or_na(cbcr_t1$year[!is.na(cbcr_t1$etr_p50_panelai)])
  )
  add_diag(
    "cbcr_t1", "profit_adj_missing_pre2021",
    sum(is.na(cbcr_t1$profit_adj_panelai) & cbcr_t1$year < 2021)
  )
  add_diag(
    "cbcr_t1", "profit_adj_present_2021_2022",
    sum(!is.na(cbcr_t1$profit_adj_panelai) & cbcr_t1$year >= 2021)
  )
  add_diag(
    "cbcr_t1", "profit_adj_ratio_observed_country_like",
    sum(!is.na(cbcr_t1$profit_adj_panelai) &
      !is.na(cbcr_t1$profit_panelai) &
      cbcr_t1$profit_panelai > 0 &
      !cbcr_t1$affiliate %in% c(
        "A", "A_O", "E", "E_O", "F", "F_O",
        "S", "S_O", "W", "W_O", "WXD", "STLS"
      ))
  )
  add_diag(
    "cbcr_t1", "zero_profit_panelai_tax_positive",
    sum(cbcr_t1$profit_panelai == 0 & cbcr_t1$tax_accrued_panelai > 0,
      na.rm = TRUE
    )
  )
  add_diag(
    "cbcr_t1", "eu27_present_as_affiliate",
    length(intersect(EU27_ISO3, unique(cbcr_t1$affiliate)))
  )

  # Year-by-year expansion of reporting parents (26 in 2016 -> 58 in 2022).
  write_csv(
    cbcr_t1 |> distinct(parent, year) |> count(year, name = "n_parents"),
    file.path(diagnostics_dir, "cbcr_t1_parent_coverage_by_year.csv")
  )

  profit_adj_support <- cbcr_t1 |>
    filter(
      !affiliate %in% c(
        "A", "A_O", "E", "E_O", "F", "F_O",
        "S", "S_O", "W", "W_O", "WXD", "STLS"
      ),
      !is.na(profit_panelai),
      profit_panelai > 0
    ) |>
    mutate(
      profit_adj_ratio = profit_adj_panelai / profit_panelai,
      holding_share = act_holding_panelai / entities_count_panelai,
      profit_adj_ratio_bounded = pmin(pmax(profit_adj_ratio, 0), 1)
    ) |>
    group_by(year) |>
    summarise(
      country_like_positive_profit_cells = n(),
      cells_with_profit_adj = sum(!is.na(profit_adj_ratio)),
      parents_with_profit_adj = n_distinct(parent[!is.na(profit_adj_ratio)]),
      affiliates_with_profit_adj = n_distinct(affiliate[!is.na(profit_adj_ratio)]),
      median_profit_adj_ratio = median(profit_adj_ratio_bounded, na.rm = TRUE),
      min_profit_adj_ratio = min_or_na(profit_adj_ratio_bounded),
      max_profit_adj_ratio = max_or_na(profit_adj_ratio_bounded),
      median_holding_share_with_profit_adj =
        median(holding_share[!is.na(profit_adj_ratio)], na.rm = TRUE),
      .groups = "drop"
    )

  write_csv(
    profit_adj_support,
    file.path(diagnostics_dir, "cbcr_t1_profit_adj_support_by_year.csv")
  )


  # 2. CbCR Table II: interquartile means

  message("[2/15] CbCR Table II")
  t2_raw <- read_oecd(file.path(raw_data_dir, "oecd_cbcr/cbcr_table2_interquartile_means.csv")) |>
    rename(
      parent = REF_AREA, affiliate = COUNTERPART_AREA, year = TIME_PERIOD,
      measure = MEASURE, panel = PROFIT_GROUPING, value = OBS_VALUE
    )

  cbcr_t2 <- t2_raw |>
    mutate(varname = paste0(measure_name(measure), panel_suffix(panel))) |>
    select(parent, affiliate, year, varname, value) |>
    pivot_wider(names_from = varname, values_from = value) |>
    arrange(parent, affiliate, year)

  assert_unique_keys(cbcr_t2, c("parent", "affiliate", "year"), "T2")
  saveRDS(cbcr_t2, file.path(processed_dir, "cbcr_table2.rds"))
  add_diag("cbcr_t2", "rows", nrow(cbcr_t2))


  # 3. CbCR Table III: ETR brackets at MNE-group level

  message("[3/15] CbCR Table III")
  t3_raw <- read_oecd(file.path(raw_data_dir, "oecd_cbcr/cbcr_table3_etr_aggregates.csv")) |>
    rename(
      parent = REF_AREA, affiliate = COUNTERPART_AREA, year = TIME_PERIOD,
      measure = MEASURE, panel = PROFIT_GROUPING,
      etr_bracket = EFFECTIVE_TAX_RATE, value = OBS_VALUE
    )

  cbcr_t3 <- t3_raw |>
    mutate(
      varname = paste0(measure_name(measure), panel_suffix(panel)),
      etr_bracket = clean_name(etr_bracket)
    ) |>
    select(parent, affiliate, year, etr_bracket, varname, value) |>
    pivot_wider(names_from = varname, values_from = value) |>
    arrange(parent, affiliate, year, etr_bracket)

  assert_unique_keys(
    cbcr_t3,
    c("parent", "affiliate", "year", "etr_bracket"), "T3"
  )
  saveRDS(cbcr_t3, file.path(processed_dir, "cbcr_table3.rds"))
  add_diag("cbcr_t3", "rows", nrow(cbcr_t3))


  # 4. CbCR Table IV: ETR brackets at subsidiary level (the GMT-critical table)

  message("[4/15] CbCR Table IV")
  t4_raw <- read_oecd(file.path(raw_data_dir, "oecd_cbcr/cbcr_table4_etr_aggregates_alt.csv")) |>
    rename(
      parent = REF_AREA, affiliate = COUNTERPART_AREA, year = TIME_PERIOD,
      measure = MEASURE, panel = PROFIT_GROUPING,
      etr_bracket = EFFECTIVE_TAX_RATE, value = OBS_VALUE
    )

  cbcr_t4 <- t4_raw |>
    mutate(
      varname = paste0(measure_name(measure), panel_suffix(panel)),
      etr_bracket = clean_name(etr_bracket)
    ) |>
    select(parent, affiliate, year, etr_bracket, varname, value) |>
    pivot_wider(names_from = varname, values_from = value) |>
    arrange(parent, affiliate, year, etr_bracket)

  assert_unique_keys(
    cbcr_t4,
    c("parent", "affiliate", "year", "etr_bracket"), "T4"
  )
  saveRDS(cbcr_t4, file.path(processed_dir, "cbcr_table4.rds"))

  add_diag("cbcr_t4", "rows", nrow(cbcr_t4))
  add_diag(
    "cbcr_t4", "eu27_present_as_affiliate",
    length(intersect(EU27_ISO3, unique(cbcr_t4$affiliate)))
  )
  add_diag(
    "cbcr_t4", "first_year_with_data",
    min_or_na(cbcr_t4$year)
  )
  add_diag(
    "cbcr_t4", "n_parents_reporting_brackets",
    n_distinct(cbcr_t4$parent)
  )

  # Switzerland anomaly, per-parent. Table IV CHE exists 2019-2022 only and is
  # dominated by USA reporting 80-91% of its CHE profit in the rate_0_15 bracket.
  # Flag, do not drop. Table IV reports a single profit panel (PROFIT_GROUPING
  # = _Z), so the variable is plain `profit`.
  che_flag <- cbcr_t4 |>
    filter(affiliate == "CHE", etr_bracket == "rate_0_15") |>
    left_join(
      cbcr_t1 |> select(parent, affiliate, year,
        t1_profit_panelai = profit_panelai,
        t1_profit_panelaii = profit_panelaii
      ),
      by = c("parent", "affiliate", "year")
    ) |>
    arrange(year, parent) |>
    transmute(year, parent,
      t4_profit_below15 = profit,
      t1_profit_panelai, t1_profit_panelaii,
      share_of_panelai = round(profit / t1_profit_panelai, 3)
    )
  write_csv(che_flag, file.path(diagnostics_dir, "cbcr_t4_switzerland_flag.csv"))

  # ETR percentile coverage by year. Percentiles are published only from 2021
  # vintage onward for Panel A-I / A-II; the panel-agnostic `_T` series has
  # slightly broader coverage and is the natural fallback for Stage 1's
  # distributional fit. Recorded here so downstream does not have to rediscover it.
  etr_pct_coverage <- cbcr_t1 |>
    group_by(year) |>
    summarise(
      n_cells = n(),
      pct_p50_panelai = round(1 - mean(is.na(etr_p50_panelai)), 3),
      pct_p50_panelaii = round(1 - mean(is.na(etr_p50_panelaii)), 3),
      pct_p50_t = round(1 - mean(is.na(etr_p50)), 3),
      pct_p50_either = round(mean(!is.na(etr_p50_panelai) |
        !is.na(etr_p50)), 3),
      .groups = "drop"
    )
  write_csv(etr_pct_coverage, file.path(diagnostics_dir, "cbcr_t1_etr_percentile_coverage.csv"))

  # Table IV coverage by year. Only 2019-2022 carry observations, and only a
  # handful of parents (USA, ESP, SGP, ...) report brackets. The hybrid Stage 1
  # measurement therefore has much narrower coverage than Table IV's headline.
  t4_coverage <- cbcr_t4 |>
    group_by(year) |>
    summarise(
      n_obs = n(),
      n_parents = n_distinct(parent),
      n_affiliates = n_distinct(affiliate),
      n_eu27_affiliates = n_distinct(affiliate[affiliate %in% EU27_ISO3]),
      .groups = "drop"
    )
  write_csv(t4_coverage, file.path(diagnostics_dir, "cbcr_t4_coverage_by_year.csv"))


  # 5. CbCR Table V: MNE size distribution percentiles

  message("[5/15] CbCR Table V")
  t5_raw <- read_oecd(file.path(raw_data_dir, "oecd_cbcr/cbcr_table5_mne_size_distribution.csv")) |>
    rename(
      parent = REF_AREA, year = TIME_PERIOD, measure = MEASURE,
      stat_op = STATISTICAL_OPERATION, value = OBS_VALUE
    )

  cbcr_t5 <- t5_raw |>
    mutate(varname = paste0(measure_name(measure), "_", tolower(stat_op))) |>
    select(parent, year, varname, value) |>
    pivot_wider(names_from = varname, values_from = value) |>
    arrange(parent, year)

  assert_unique_keys(cbcr_t5, c("parent", "year"), "T5")
  saveRDS(cbcr_t5, file.path(processed_dir, "cbcr_table5.rds"))
  add_diag("cbcr_t5", "rows", nrow(cbcr_t5))


  # 6. CbCR Table VI: financial aggregates by MNE size class (2022 only)

  message("[6/15] CbCR Table VI")
  t6_raw <- read_oecd(file.path(raw_data_dir, "oecd_cbcr/cbcr_table6_mne_size_aggregates.csv")) |>
    rename(
      parent = REF_AREA, affiliate = COUNTERPART_AREA, year = TIME_PERIOD,
      measure = MEASURE, panel = PROFIT_GROUPING, size_class = MNE_SIZE,
      value = OBS_VALUE
    )

  cbcr_t6 <- t6_raw |>
    mutate(
      varname = paste0(measure_name(measure), panel_suffix(panel)),
      size_class = clean_name(size_class)
    ) |>
    select(parent, affiliate, year, size_class, varname, value) |>
    pivot_wider(names_from = varname, values_from = value) |>
    arrange(parent, affiliate, year, size_class)

  assert_unique_keys(
    cbcr_t6,
    c("parent", "affiliate", "year", "size_class"), "T6"
  )
  saveRDS(cbcr_t6, file.path(processed_dir, "cbcr_table6.rds"))
  add_diag("cbcr_t6", "rows", nrow(cbcr_t6))


  # 7. OECD statutory CIT rates (central + combined)

  message("[7/15] OECD statutory CIT rates")
  cit_stat_raw <- read_oecd(file.path(raw_data_dir, "oecd_tax_rates/oecd_statutory_cit_rates.csv"))
  # Filter to MEASURE = "CIT" (the headline statutory CIT rate); the file also
  # carries adjacent measure codes (CIT_C central-only, CIT_LSN local sub-national,
  # exemption codes, etc.) which are kept long in cit_dividend / etr_forward style
  # storage if needed later.
  # TARGETING: ST = standard rate, TA = top-all (combined central + sub-central).
  cit_statutory <- cit_stat_raw |>
    filter(MEASURE == "CIT") |>
    transmute(
      jurisdiction = REF_AREA, year = TIME_PERIOD,
      rate_kind = if_else(TARGETING == "ST", "standard", "top_all"),
      value = OBS_VALUE
    ) |>
    pivot_wider(
      names_from = rate_kind, values_from = value,
      names_prefix = "cit_"
    ) |>
    arrange(jurisdiction, year)

  assert_unique_keys(cit_statutory, c("jurisdiction", "year"), "CIT-statutory")
  saveRDS(cit_statutory, file.path(processed_dir, "cit_statutory.rds"))
  add_diag("cit_statutory", "rows", nrow(cit_statutory))
  add_diag("cit_statutory", "jurisdictions", n_distinct(cit_statutory$jurisdiction))

  # OECD combined dividend tax rates (kept long because of many measure codes).
  div_raw <- read_oecd(file.path(raw_data_dir, "oecd_tax_rates/oecd_combined_dividend_rates.csv"))
  cit_dividend <- div_raw |>
    transmute(
      jurisdiction = REF_AREA, year = TIME_PERIOD,
      measure = MEASURE, value = OBS_VALUE
    ) |>
    arrange(jurisdiction, year, measure)
  saveRDS(cit_dividend, file.path(processed_dir, "cit_dividend.rds"))
  add_diag("cit_dividend", "rows", nrow(cit_dividend))


  # 8. OECD forward-looking ETRs (kept long; many scenario / asset dimensions)

  message("[8/15] OECD forward-looking ETRs")
  read_etr <- function(path, scenario) {
    read_oecd(path) |>
      transmute(
        scenario_file = scenario,
        jurisdiction = REF_AREA, year = TIME_PERIOD,
        measure = MEASURE, asset_type = ETR_TAX_BASIS,
        etr_scenario = ETR_SCENARIO, tax_type = ETR_TAX_TYPE,
        regime = REGIME, regime_name = REGIME_NAME,
        value = OBS_VALUE
      )
  }
  etr_forward <- bind_rows(
    read_etr(file.path(raw_data_dir, "oecd_etr/oecd_etr_baseline.csv"), "baseline"),
    read_etr(file.path(raw_data_dir, "oecd_etr/oecd_etr_income_incentives.csv"), "income_incentives"),
    read_etr(file.path(raw_data_dir, "oecd_etr/oecd_etr_expenditure_incentives.csv"), "expenditure_incentives")
  )
  saveRDS(etr_forward, file.path(processed_dir, "etr_forward.rds"))
  add_diag("etr_forward", "rows", nrow(etr_forward))


  # 9. OECD wages: average annual wages (PPP USD) + hourly earnings (kept long)

  message("[9/15] OECD wages")
  wages_oecd <- read_oecd(file.path(raw_data_dir, "oecd_wages/oecd_avg_annual_wages.csv")) |>
    filter(MEASURE == "WG", AGGREGATION_OPERATION == "MEAN") |>
    transmute(
      jurisdiction = REF_AREA, year = TIME_PERIOD,
      currency = UNIT_MEASURE, price_base = PRICE_BASE,
      base_year = BASE_PER, value = OBS_VALUE
    ) |>
    arrange(jurisdiction, year, currency)
  saveRDS(wages_oecd, file.path(processed_dir, "wages_oecd.rds"))
  add_diag("wages_oecd", "rows", nrow(wages_oecd))
  add_diag("wages_oecd", "jurisdictions", n_distinct(wages_oecd$jurisdiction))

  wages_oecd_hourly <- read_csv(
    file.path(raw_data_dir, "oecd_wages/oecd_hourly_earnings.csv"),
    show_col_types = FALSE,
    col_types = cols(
      .default = col_guess(),
      TIME_PERIOD = col_character(),
      OBS_VALUE = col_double()
    )
  ) |>
    transmute(
      jurisdiction = REF_AREA,
      time_period  = TIME_PERIOD,
      year         = as.integer(str_sub(TIME_PERIOD, 1, 4)),
      measure      = MEASURE,
      unit_measure = UNIT_MEASURE,
      adjustment   = ADJUSTMENT,
      activity     = ACTIVITY,
      sector       = SECTOR,
      frequency    = FREQ,
      base_year    = BASE_PER,
      value        = OBS_VALUE
    ) |>
    arrange(jurisdiction, time_period)
  saveRDS(wages_oecd_hourly, file.path(processed_dir, "wages_oecd_hourly.rds"))
  add_diag("wages_oecd_hourly", "rows", nrow(wages_oecd_hourly))

  # ILO wages extend coverage to non-OECD economies for payroll imputation.
  ilo_monthly <- read_oecd(file.path(raw_data_dir, "ilo_wages/ilo_monthly_earnings.csv")) |>
    transmute(
      jurisdiction = REF_AREA, year = TIME_PERIOD, sex = SEX,
      sector = ECO, currency = CUR, value = OBS_VALUE
    )
  saveRDS(ilo_monthly, file.path(processed_dir, "wages_ilo_monthly.rds"))
  add_diag("wages_ilo_monthly", "rows", nrow(ilo_monthly))

  ilo_hourly <- read_oecd(file.path(raw_data_dir, "ilo_wages/ilo_hourly_earnings.csv")) |>
    transmute(
      jurisdiction = REF_AREA, year = TIME_PERIOD, sex = SEX,
      sector = ECO, currency = CUR, value = OBS_VALUE
    )
  saveRDS(ilo_hourly, file.path(processed_dir, "wages_ilo_hourly.rds"))
  add_diag("wages_ilo_hourly", "rows", nrow(ilo_hourly))


  # 10. World Bank: income classifications, GDP per capita, population

  message("[10/15] World Bank")
  wb_raw <- read_csv(file.path(raw_data_dir, "world_bank/wb_income_classifications.csv"),
    show_col_types = FALSE
  )

  wb_countries <- wb_raw |>
    filter(region != "Aggregates") |>
    rename(jurisdiction = iso3) |>
    arrange(jurisdiction)

  wb_aggregates <- wb_raw |>
    filter(region == "Aggregates") |>
    rename(aggregate_code = iso3)

  saveRDS(wb_countries, file.path(processed_dir, "wb_classifications.rds"))
  saveRDS(wb_aggregates, file.path(processed_dir, "wb_aggregates.rds"))
  add_diag("wb_classifications", "countries", nrow(wb_countries))
  add_diag("wb_classifications", "aggregates", nrow(wb_aggregates))

  # NB: the World Bank API ships the GDP and population files with the column
  # header "iso3" but populates it with ISO2 codes. Country / aggregate split is
  # therefore done by joining on iso2 from wb_classifications.
  country_iso2 <- wb_countries$iso2

  wb_gdp <- read_csv(file.path(raw_data_dir, "world_bank/wb_gdp_per_capita.csv"),
    show_col_types = FALSE
  ) |>
    rename(iso2 = iso3) |>
    filter(iso2 %in% country_iso2) |>
    left_join(wb_countries |> select(iso2, jurisdiction), by = "iso2") |>
    transmute(jurisdiction, iso2, year = as.integer(year), gdp_pc_usd) |>
    arrange(jurisdiction, year)
  saveRDS(wb_gdp, file.path(processed_dir, "wb_gdp.rds"))
  add_diag("wb_gdp", "rows", nrow(wb_gdp))

  wb_pop <- read_csv(file.path(raw_data_dir, "world_bank/wb_population.csv"),
    show_col_types = FALSE
  ) |>
    rename(iso2 = iso3) |>
    filter(iso2 %in% country_iso2) |>
    left_join(wb_countries |> select(iso2, jurisdiction), by = "iso2") |>
    transmute(jurisdiction, iso2, year = as.integer(year), population) |>
    arrange(jurisdiction, year)
  saveRDS(wb_pop, file.path(processed_dir, "wb_population.rds"))
  add_diag("wb_population", "rows", nrow(wb_pop))


  # 11. Eurostat inward FATS: pre/post-2021 split (structural break in 2021)

  message("[11/15] Eurostat FATS")
  fats_raw <- read_csv(
    file.path(raw_data_dir, "eurostat_fats/fats_inward_eu_full.csv.gz"),
    show_col_types = FALSE,
    col_types = cols(
      .default = col_character(),
      time_period = col_integer(),
      obs_value = col_double()
    )
  )

  # Pre-2021: legacy aggregate, used for descriptive trend work only.
  fats_pre2021 <- fats_raw |>
    filter(source_dataset == "fats_g1b_08") |>
    transmute(geo, c_ctrl, nace_r2,
      year = time_period,
      indicator = tolower(indicator_code), value = obs_value
    ) |>
    pivot_wider(
      names_from = indicator, values_from = value,
      names_prefix = "ind_"
    ) |>
    arrange(geo, c_ctrl, nace_r2, year)
  saveRDS(fats_pre2021, file.path(processed_dir, "fats_pre2021.rds"))
  add_diag("fats_pre2021", "rows", nrow(fats_pre2021))

  # Post-2021: NACE-detailed activities, basis for the sectoral SBIE work.
  fats_post2021 <- fats_raw |>
    filter(source_dataset == "fats_activ") |>
    transmute(geo, c_ctrl, nace_r2,
      year = time_period,
      indicator = tolower(indicator_code), value = obs_value
    ) |>
    pivot_wider(
      names_from = indicator, values_from = value,
      names_prefix = "ind_"
    ) |>
    arrange(geo, c_ctrl, nace_r2, year)
  saveRDS(fats_post2021, file.path(processed_dir, "fats_post2021.rds"))
  add_diag("fats_post2021", "rows", nrow(fats_post2021))
  add_diag(
    "fats_post2021", "eu27_reporters",
    length(intersect(EU27_ISO2, unique(fats_post2021$geo)))
  )

  # Coverage of post-2021 FATS by EU Member State × year × NACE depth.
  fats_coverage <- fats_post2021 |>
    filter(geo %in% EU27_ISO2) |>
    group_by(geo, year) |>
    summarise(
      n_nace = n_distinct(nace_r2),
      n_partner_countries = n_distinct(c_ctrl),
      n_obs = n(), .groups = "drop"
    ) |>
    arrange(geo, year)
  write_csv(fats_coverage, file.path(diagnostics_dir, "fats_post2021_eu27_coverage.csv"))


  # 12. EUKLEMS & INTANProd: sectoral capital stocks

  message("[12/15] EUKLEMS & INTANProd")
  euklems_capital_raw <- read_csv(
    file.path(raw_data_dir, "euklems_intanprod/capital_accounts.csv"),
    show_col_types = FALSE,
    col_select = c(
      nace_r2_code, geo_code, nace_r2_name, geo_name, year,
      K_GFCF, K_CT, K_OCon, K_OMach, K_Rstruc, K_TraEq
    )
  )

  euklems_intan_raw <- read_csv(
    file.path(raw_data_dir, "euklems_intanprod/intangibles_analytical.csv"),
    show_col_types = FALSE,
    col_select = c(
      nace_r2_code, geo_code, nace_r2_name, geo_name, year,
      K_Tang, K_TangNRes, K_Intang, K_NatAcc, K_NonNatAcc,
      VA_CP, VAadj
    )
  )

  euklems_sector_capital <- euklems_intan_raw |>
    left_join(
      euklems_capital_raw |>
        select(
          nace_r2_code, geo_code, year, K_GFCF, K_CT, K_OCon, K_OMach,
          K_Rstruc, K_TraEq
        ),
      by = c("nace_r2_code", "geo_code", "year")
    ) |>
    left_join(EUROSTAT_GEO_MAP, by = c("geo_code" = "geo")) |>
    transmute(
      jurisdiction,
      geo_code,
      geo_name,
      nace_r2 = str_replace_all(nace_r2_code, "_", "-"),
      nace_r2_name,
      year = as.integer(year),
      euklems_k_tang = K_Tang,
      euklems_k_tang_nres = K_TangNRes,
      euklems_k_intang = K_Intang,
      euklems_k_natacc = K_NatAcc,
      euklems_k_non_natacc = K_NonNatAcc,
      euklems_k_gfcf = K_GFCF,
      euklems_k_construction = K_OCon,
      euklems_k_machinery = K_OMach,
      euklems_k_residential = K_Rstruc,
      euklems_k_transport = K_TraEq,
      euklems_k_computing = K_CT,
      euklems_va_cp = VA_CP,
      euklems_va_adjusted = VAadj,
      euklems_tangible_intensity = safe_divide(euklems_k_tang, euklems_va_cp),
      euklems_intangible_share = safe_divide(
        euklems_k_intang,
        euklems_k_tang + euklems_k_intang
      )
    ) |>
    filter(!is.na(jurisdiction)) |>
    arrange(jurisdiction, year, nace_r2)

  assert_unique_keys(
    euklems_sector_capital,
    c("jurisdiction", "year", "nace_r2"),
    "EUKLEMS sector capital"
  )
  saveRDS(euklems_sector_capital, file.path(processed_dir, "euklems_sector_capital.rds"))
  add_diag("euklems_sector_capital", "rows", nrow(euklems_sector_capital))
  add_diag(
    "euklems_sector_capital", "jurisdictions",
    n_distinct(euklems_sector_capital$jurisdiction)
  )
  add_diag(
    "euklems_sector_capital", "year_range",
    paste(range(euklems_sector_capital$year), collapse = "-")
  )

  euklems_coverage <- euklems_sector_capital |>
    filter(jurisdiction %in% EU27_ISO3) |>
    group_by(jurisdiction, year) |>
    summarise(
      n_nace = n_distinct(nace_r2),
      tangible_stock_available = sum(!is.na(euklems_k_tang)),
      intangible_stock_available = sum(!is.na(euklems_k_intang)),
      .groups = "drop"
    ) |>
    arrange(jurisdiction, year)
  write_csv(euklems_coverage, file.path(diagnostics_dir, "euklems_sector_capital_coverage.csv"))


  # 13. Global INTAN-Invest: country-level robustness data

  message("[13/15] Global INTAN-Invest")
  global_intan_annual <- read_csv(
    file.path(raw_data_dir, "global_intan_invest/annual_extrapolated_estimates.csv"),
    show_col_types = FALSE
  ) |>
    left_join(EUROSTAT_GEO_MAP, by = c("geo_code" = "geo")) |>
    transmute(
      jurisdiction,
      geo_code,
      year = as.integer(year),
      global_intan_va_cp = VA_CP,
      global_intan_gdp = GDP,
      global_intan_i_gfcf = I_GFCF,
      global_intan_i_tang_nres = I_TangNRes,
      global_intan_i_intan = I_Intan,
      global_intan_i_natacc = I_NatAcc,
      global_intan_i_non_natacc = I_NonNatAcc,
      global_intan_employment = H_EMP,
      global_intan_intangible_investment_share = safe_divide(I_Intan, I_GFCF),
      global_intan_non_natacc_share = safe_divide(I_NonNatAcc, I_GFCF)
    ) |>
    arrange(jurisdiction, year)

  assert_unique_keys(
    global_intan_annual,
    c("geo_code", "year"),
    "Global INTAN annual"
  )
  saveRDS(global_intan_annual, file.path(processed_dir, "global_intan_invest_annual.rds"))
  add_diag("global_intan_invest_annual", "rows", nrow(global_intan_annual))
  add_diag(
    "global_intan_invest_annual", "year_range",
    paste(range(global_intan_annual$year), collapse = "-")
  )


  # 14. BEA US MNE benchmark: country by industry tables

  message("[14/15] BEA US MNE benchmark")
  bea_assets_xlsx <- convert_xls_to_xlsx(file.path(raw_data_dir, "bea_mne/bea_mofa_assets.xls"))
  bea_employment_xlsx <- convert_xls_to_xlsx(file.path(raw_data_dir, "bea_mne/bea_mofa_employment.xls"))
  bea_ppe_xlsx <- convert_xls_to_xlsx(
    file.path(raw_data_dir, "bea_mne/bea_usdia2023p_mofa_ppe_c4_c6.xls")
  )
  bea_compensation_xlsx <- convert_xls_to_xlsx(
    file.path(raw_data_dir, "bea_mne/bea_usdia2023p_mofa_employment_compensation_g1_g5.xls")
  )

  bea_us_mne_country_industry <- bind_rows(
    map_dfr(2009:2023, ~ parse_bea_country_industry_sheet(
      bea_assets_xlsx,
      as.character(.x),
      "total_assets",
      "millions_usd",
      .x
    )),
    map_dfr(2009:2023, ~ parse_bea_country_industry_sheet(
      bea_employment_xlsx,
      as.character(.x),
      "employment",
      "thousand_employees",
      .x
    )),
    parse_bea_country_industry_sheet(
      bea_ppe_xlsx,
      "Table II.C 4",
      "ppe_expenditures",
      "millions_usd",
      2023
    ),
    parse_bea_country_industry_sheet(
      bea_compensation_xlsx,
      "Table II.G 3",
      "compensation",
      "millions_usd",
      2023
    )
  ) |>
    arrange(measure, year, country_or_region, bea_industry)

  saveRDS(
    bea_us_mne_country_industry,
    file.path(processed_dir, "bea_us_mne_country_industry.rds")
  )
  add_diag("bea_us_mne_country_industry", "rows", nrow(bea_us_mne_country_industry))
  add_diag(
    "bea_us_mne_country_industry", "eu27_country_rows",
    sum(bea_us_mne_country_industry$jurisdiction %in% EU27_ISO3)
  )
  add_diag(
    "bea_us_mne_country_industry", "suppressed_cells",
    sum(!is.na(bea_us_mne_country_industry$suppression_code))
  )

  bea_us_mne_coverage <- bea_us_mne_country_industry |>
    group_by(measure, year) |>
    summarise(
      rows = n(),
      country_rows = sum(is_country),
      eu27_country_rows = sum(jurisdiction %in% EU27_ISO3, na.rm = TRUE),
      suppressed_share = mean(!is.na(suppression_code)),
      .groups = "drop"
    ) |>
    arrange(measure, year)
  write_csv(bea_us_mne_coverage, file.path(diagnostics_dir, "bea_us_mne_country_industry_coverage.csv"))


  # 15. Pillar Two Central Record + BEPS rules + CIT revenue

  message("[15/15] OECD Central Record, BEPS rules, CIT revenue")
  oecd_central_record <- read_csv(
    file.path(raw_data_dir, "pillar2_qdmtt/oecd_central_record_2026_05.csv"),
    show_col_types = FALSE,
    col_types = cols(
      jurisdiction = col_character(),
      jurisdiction_name = col_character(),
      rule_type = col_character(),
      effective_date = col_date(),
      qdmtt_safe_harbour = col_logical(),
      table_current_as = col_date(),
      source_note = col_character()
    )
  ) |>
    filter(!is.na(jurisdiction), !is.na(rule_type))

  if (nrow(oecd_central_record) != 95) {
    stop("OECD Central Record tracker should contain 95 rule rows")
  }
  if (n_distinct(
    oecd_central_record$jurisdiction,
    oecd_central_record$rule_type
  ) != nrow(oecd_central_record)) {
    stop("OECD Central Record tracker has duplicate jurisdiction-rule rows")
  }
  if (!setequal(
    unique(oecd_central_record$rule_type),
    c("qualified_iir", "qualified_qdmtt", "qualified_sbs")
  )) {
    stop("OECD Central Record tracker has unexpected rule types")
  }

  saveRDS(
    oecd_central_record,
    file.path(processed_dir, "oecd_pillar2_central_record.rds")
  )
  add_diag("oecd_pillar2_central_record", "rows", nrow(oecd_central_record))
  add_diag(
    "oecd_pillar2_central_record", "jurisdictions",
    n_distinct(oecd_central_record$jurisdiction)
  )
  add_diag(
    "oecd_pillar2_central_record", "qualified_iir_rows",
    sum(oecd_central_record$rule_type == "qualified_iir")
  )
  add_diag(
    "oecd_pillar2_central_record", "qualified_qdmtt_rows",
    sum(oecd_central_record$rule_type == "qualified_qdmtt")
  )
  add_diag(
    "oecd_pillar2_central_record", "qualified_sbs_rows",
    sum(oecd_central_record$rule_type == "qualified_sbs")
  )

  # OECD BEPS rules: five panel rule types stacked, kept long with a `rule` key.
  # Values are categorical ("Yes"/"No"/regime label), so OBS_VALUE stays character.
  read_beps <- function(path) {
    read_csv(path,
      show_col_types = FALSE,
      col_types = cols(
        .default = col_character(),
        TIME_PERIOD = col_integer()
      )
    )
  }
  beps_files <- c(
    cfc                  = "oecd_cfc_rules.csv",
    interest_limitation  = "oecd_interest_limitation.csv",
    ip_regimes           = "oecd_ip_regimes.csv",
    hybrid_mismatch      = "oecd_hybrid_mismatch.csv",
    mandatory_disclosure = "oecd_mandatory_disclosure.csv"
  )
  beps_rules <- imap_dfr(beps_files, ~ read_beps(file.path(raw_data_dir, "pillar2_beps", .x)) |>
    transmute(
      rule = .y, jurisdiction = REF_AREA, year = TIME_PERIOD,
      measure = MEASURE, regime = REGIME, value = OBS_VALUE
    ))
  saveRDS(beps_rules, file.path(processed_dir, "beps_rules.rds"))
  add_diag("beps_rules", "rows", nrow(beps_rules))
  add_diag("beps_rules", "rule_types", n_distinct(beps_rules$rule))

  # CbCR Action 13 implementation requirements (different schema: no time series).
  cbcr_req <- read_csv(file.path(raw_data_dir, "pillar2_beps/oecd_cbcr_requirements.csv"),
    show_col_types = FALSE,
    col_types = cols(.default = col_character())
  ) |>
    transmute(jurisdiction = REF_AREA, measure = MEASURE, value = OBS_VALUE)
  saveRDS(cbcr_req, file.path(processed_dir, "cbcr_requirements.rds"))
  add_diag("cbcr_requirements", "rows", nrow(cbcr_req))

  # Retain monetary values in billions of the reported currency, as expected
  # by the fiscal-salience code. Ratios retain their original units.
  revenue_raw <- read_oecd(file.path(raw_data_dir, "oecd_cts_additional/oecd_cit_revenue_gdp.csv"))
  monetary <- revenue_raw$UNIT_MEASURE %in% c("USD", "XDC") &
    !is.na(revenue_raw$OBS_VALUE)
  if (any(!is.finite(revenue_raw$UNIT_MULT[monetary]))) {
    stop("OECD monetary revenue has missing or invalid UNIT_MULT")
  }
  cit_revenue <- revenue_raw |>
    transmute(
      jurisdiction = REF_AREA, year = TIME_PERIOD, measure = MEASURE,
      sector = SECTOR, revenue_classification = STANDARD_REVENUE,
      unit = UNIT_MEASURE,
      value = if_else(unit %in% c("USD", "XDC"),
        OBS_VALUE * 10^(UNIT_MULT - 9), OBS_VALUE
      )
    )
  saveRDS(cit_revenue, file.path(processed_dir, "cit_revenue.rds"))
  add_diag("cit_revenue", "rows", nrow(cit_revenue))


  # Diagnostics summary

  diagnostics_df <- bind_rows(diagnostics)
  write_csv(diagnostics_df, file.path(diagnostics_dir, "summary.csv"))

  message("\nDiagnostics summary written to ", file.path(diagnostics_dir, "summary.csv"))
  message(sprintf(
    "%d intermediate files written to %s/",
    length(list.files(processed_dir, pattern = "\\.rds$")), processed_dir
  ))
}

if (is_direct_script_run("code/01_data_cleaning.R")) {
  run_data_cleaning()
}
