# Assemble the Stage 02 panel from cleaned CbCR inputs and prepared lookups.
# Stage 02 supplies the shared safe_divide() and assert_unique_keys() helpers.

BILATERAL_PANEL_KEY <- c("parent", "affiliate", "year")
STAGE02_AGGREGATE_AFFILIATES <- c(
  "A", "A_O", "E", "E_O", "F", "F_O",
  "S", "S_O", "W", "W_O", "WXD", "STLS"
)

build_bilateral_spine <- function(table1, core_years, estimation_years,
                                  aggregate_affiliates, eu27, conduit_havens) {
  panel <- table1 |>
    dplyr::filter(year %in% core_years, !affiliate %in% aggregate_affiliates) |>
    dplyr::arrange(parent, affiliate, year) |>
    dplyr::mutate(
      pair_id = paste(parent, affiliate, sep = "__"),
      is_domestic = parent == affiliate,
      is_2016_transition = year == 2016,
      is_main_estimation_year = year %in% estimation_years,
      affiliate_is_eu27 = affiliate %in% eu27,
      affiliate_is_conduit_haven = affiliate %in% conduit_havens,
      holding_share_panelai = safe_divide(act_holding_panelai, entities_count_panelai),
      holding_share_panelaii = safe_divide(act_holding_panelaii, entities_count_panelaii),
      profit_adj_observed_panelai = !is.na(profit_adj_panelai),
      profit_adj_ratio_observed = safe_divide(profit_adj_panelai, profit_panelai),
      profit_adj_above_profit_flag = !is.na(profit_adj_ratio_observed) &
        profit_adj_ratio_observed > 1 + 1e-9
    )

  assert_unique_keys(panel, BILATERAL_PANEL_KEY, "Table I spine (parent, affiliate, year)")
  panel
}

prepare_cbcr_bilateral_lookups <- function(table2, table3, table4, table5, table6) {
  # Table III brackets classify group ETRs. Table IV brackets classify local
  # affiliate ETRs. The Table IV projection precedes the employee caps applied
  # to the separate bracket sidecars. Both projections retain missing taxes.
  table2_wide <- table2 |>
    dplyr::rename_with(~ paste0("t2_", .x), -c(parent, affiliate, year))
  table3_low <- table3 |>
    dplyr::filter(etr_bracket == "rate_0_15") |>
    dplyr::select(-etr_bracket) |>
    dplyr::rename_with(~ paste0("t3_low_", .x), -c(parent, affiliate, year))
  table4_low <- table4 |>
    dplyr::filter(etr_bracket == "rate_0_15") |>
    dplyr::select(-etr_bracket) |>
    dplyr::rename_with(~ paste0("t4_low_", .x), -c(parent, affiliate, year))
  table5_wide <- table5 |>
    dplyr::rename_with(~ paste0("t5_", .x), -c(parent, year))

  assert_unique_keys(
    table6, c(BILATERAL_PANEL_KEY, "size_class"),
    "Table VI before widening (parent, affiliate, year, size_class)"
  )
  table6_wide <- table6 |>
    dplyr::select(
      parent, affiliate, year, size_class, profit, assets, employees,
      accumulated_earnings, tax_accrued, entities_count,
      cbcr_count, subgroups_count
    ) |>
    tidyr::pivot_wider(
      names_from = size_class,
      values_from = c(
        profit, assets, employees, accumulated_earnings, tax_accrued,
        entities_count, cbcr_count, subgroups_count
      ),
      names_glue = "t6_{.value}_{size_class}"
    )

  list(
    table2 = table2_wide, table3_low = table3_low, table4_low = table4_low,
    table5 = table5_wide, table6 = table6_wide
  )
}

# Keep every bilateral row in its incoming order. Unmatched keys produce NAs
# while values such as an observed zero pass through unchanged. Coverage can be
# recovered from the supplied lookup keys when a matched value is itself NA.
attach_bilateral_lookup <- function(panel, lookup, keys, label, relationship = "many-to-one") {
  assert_unique_keys(
    panel, BILATERAL_PANEL_KEY, paste0("Bilateral panel before ", label, " (parent, affiliate, year)")
  )
  assert_unique_keys(lookup, keys, paste0(label, " (", paste(keys, collapse = ", "), ")"))

  joined <- dplyr::left_join(panel, lookup, by = keys, relationship = relationship)
  if (nrow(joined) != nrow(panel) ||
      !all(vctrs::vec_equal(joined[BILATERAL_PANEL_KEY], panel[BILATERAL_PANEL_KEY], na_equal = TRUE))) {
    stop(label, ": join changed bilateral key coverage or order", call. = FALSE)
  }
  joined
}

attach_cbcr_bilateral_lookups <- function(panel, lookups) {
  panel |>
    attach_bilateral_lookup(lookups$table2, BILATERAL_PANEL_KEY, "Table II", "one-to-one") |>
    attach_bilateral_lookup(lookups$table3_low, BILATERAL_PANEL_KEY, "Table III low bracket", "one-to-one") |>
    attach_bilateral_lookup(lookups$table4_low, BILATERAL_PANEL_KEY, "Table IV low bracket", "one-to-one") |>
    attach_bilateral_lookup(lookups$table5, c("parent", "year"), "Table V") |>
    attach_bilateral_lookup(lookups$table6, BILATERAL_PANEL_KEY, "Table VI wide", "one-to-one")
}

# The prepared Stage 02a model has one row per parent and year. Leave support
# flags and unobserved correction rates intact for Stage 02's profit equations.
attach_profit_reconciliation <- function(panel, profit_reconciliation) {
  attach_bilateral_lookup(
    panel, profit_reconciliation, c("parent", "year"), "Profit reconciliation parent-year model"
  )
}
