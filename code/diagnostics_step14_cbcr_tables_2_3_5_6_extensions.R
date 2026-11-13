#!/usr/bin/env Rscript
# Run from the repository root. Reads the pinned release; writes only four CSVs.
source("code/00_helpers.R", local = TRUE)

run_diagnostics_step14 <- function() {
  key <- c("parent", "affiliate", "year")
  aggregate_codes <- c("A", "A_O", "E", "E_O", "F", "F_O", "S", "S_O",
                       "W", "W_O", "WXD", "STLS")
  hubs <- c("IRL", "NLD", "LUX", "DEU", "FRA", "BEL", "CYP", "HUN")
  activity <- c("act_holding", "act_ip", "act_igf", "act_rd", "act_man",
                "act_sales", "act_ser", "act_admin", "act_dor", "act_other",
                "act_fin", "act_ins", "act_pur")
  floor_rate <- GMT_RATE
  sum_obs <- function(x) if (any(is.finite(x))) sum(x[is.finite(x)]) else NA_real_
  median_obs <- function(x) if (any(is.finite(x))) median(x[is.finite(x)]) else NA_real_
  ratio <- function(x, y) x * ifelse(is.finite(y) & y > 0, 1 / y, NA_real_)
  clip <- function(x, lo = 0, hi = 1) pmax(lo, pmin(x, hi))
  pct_gap <- function(tax, profit) floor_rate - clip(ratio(tax, profit), 0, floor_rate)
  row_topup <- function(tax, profit) ifelse(profit == 0, 0, profit * pct_gap(tax, profit))
  country_rows <- function(x) filter(x, !parent %in% aggregate_codes,
                                     !affiliate %in% aggregate_codes)
  load_panel <- function(name) readRDS(file.path(PROCESSED_DIR, paste0(name, ".rds")))
  assert_keys <- function(x, keys) {
    stopifnot(!anyNA(x[keys]), !anyDuplicated(x[keys]))
  }
  scope_panel <- function(x, rules) {
    imap_dfr(rules, function(f, label) mutate(x[f(x), , drop = FALSE], scope = rep(label, sum(f(x)))))
  }
  host_rules <- c(list(Global = function(x) rep(TRUE, nrow(x)),
                       EU27 = function(x) x$affiliate %in% EU27_ISO3),
                  setNames(lapply(hubs, function(j) function(x) x$affiliate == j), hubs))
  blend_rules <- c(host_rules, list(USA_all_hosts = function(x) x$parent == "USA",
                                   USA_foreign = function(x) x$parent == "USA" &
                                   x$affiliate != "USA",
                                   USA_EU27 = function(x) x$parent == "USA" &
                                     x$affiliate %in% EU27_ISO3))
  time_panel <- function(x, pooled) bind_rows(
    mutate(x, window = as.character(year)),
    mutate(x, window = rep(pooled, nrow(x)))
  )
  signed_rank <- function(delta) {
    delta <- delta[is.finite(delta)]
    if (!length(delta) || all(delta == 0)) return(NA_real_)
    wilcox.test(delta, exact = FALSE)$p.value
  }

  t1 <- load_panel("cbcr_table1")
  t2 <- load_panel("cbcr_table2")
  t3 <- load_panel("cbcr_table3")
  t4 <- load_panel("cbcr_table4")
  base <- load_panel("base_panel")
  s1 <- load_panel("stage1_bilateral_panel")
  s2 <- load_panel("stage2_bilateral_panel")
  for (x in list(t1, t2, base, s1)) assert_keys(x, key)
  for (x in list(t3, t4)) assert_keys(x, c(key, "etr_bracket"))
  assert_keys(s2, c(key, "rate_scenario"))

  # 1. Tables III and IV: separate margins; no public group × jurisdiction cross-tab.
  # Use explicitly observed 0–15 and 15+ bins (15+ is a single bin in 2019–23).
  # Exclude negative-tax and negative-profit categories, and flag III's net loss bins.
  # Absent/suppressed brackets are never interpreted as zero.
  bracket_partition <- function(x) {
    x |>
      filter(year %in% MAIN_YEARS, etr_bracket %in% c("rate_0_15", "rate_15")) |>
      select(all_of(key), etr_bracket, profit, tax_accrued, subgroups_count) |>
      pivot_wider(names_from = etr_bracket,
                  values_from = c(profit, tax_accrued, subgroups_count)) |>
      transmute(across(all_of(key)),
        low = profit_rate_0_15, high = profit_rate_15, low_tax = tax_accrued_rate_0_15,
        subgroup_count = subgroups_count_rate_0_15 + subgroups_count_rate_15
      ) |>
      filter(is.finite(low), is.finite(high), low >= 0, high >= 0, low + high > 0) |>
      mutate(profit = low + high, share = low / profit,
             local_topup = row_topup(low_tax, low))
  }
  # An approximation to the worldwide group-bracket gap using the same reporter's
  # domestic + explicitly published all-foreign totals. Include separately reported
  # stateless records, as the OECD requests these outside domestic and foreign.
  group_gap <- t3 |>
    filter(year %in% MAIN_YEARS, etr_bracket == "rate_0_15",
           affiliate == parent | affiliate %in% c("WXD", "STLS")) |>
    summarise(
      domestic = any(parent == affiliate), foreign = any(affiliate == "WXD"),
      worldwide_low_profit = sum(profit), worldwide_low_tax = sum(tax_accrued),
      .by = c(parent, year)
    ) |>
    filter(domestic, foreign, is.finite(worldwide_low_profit), worldwide_low_profit > 0,
           is.finite(worldwide_low_tax)) |>
    mutate(worldwide_etr_raw = worldwide_low_tax / worldwide_low_profit,
           # Outside-range reported aggregate rates do not validate the bracket.
           worldwide_gap = if_else(between(worldwide_etr_raw, 0, floor_rate + 1e-8),
                                   pmax(0, floor_rate - worldwide_etr_raw), NA_real_)) |>
    select(-domestic, -foreign)

  g <- bracket_partition(t3) |> country_rows() |>
    left_join(group_gap, by = c("parent", "year"), relationship = "many-to-one") |>
    mutate(worldwide_topup = if_else(low == 0, 0, low * worldwide_gap))
  j <- bracket_partition(t4) |> country_rows()
  w <- s1 |> select(all_of(key), corrected_profit = analysis_profit_positive)
  g <- left_join(g, w, by = key, relationship = "one-to-one")
  j <- left_join(j, w, by = key, relationship = "one-to-one")
  matched <- inner_join(g, select(j, -corrected_profit), by = key,
                        suffix = c("_group", "_juris"), relationship = "one-to-one") |>
    filter(year >= 2019) |>
    mutate(
      denom_gap = abs(profit_group - profit_juris) / pmax(profit_group, profit_juris),
      counts_agree = is.finite(subgroup_count_group) & is.finite(subgroup_count_juris) &
        abs(subgroup_count_group - subgroup_count_juris) < 1e-6,
      close_denom = denom_gap <= 0.05,
      same_margin_totals = denom_gap <= 1e-6 & counts_agree
    )
  # Bounds are valid only under common positive-profit support. Matching a key
  # (or even its totals) does not establish common underlying subgroups.
  bounds <- function(x) {
    mutate(x, gap_share = share_juris - share_group,
           hidden_lb_share = pmax(0, gap_share),
           hidden_ub_share = pmin(share_juris, 1 - share_group),
           reverse_lb_share = pmax(0, -gap_share),
           reverse_ub_share = pmin(share_group, 1 - share_juris))
  }
  stopifnot(all(with(bounds(matched), hidden_lb_share <= hidden_ub_share + 1e-12 &
                                    reverse_lb_share <= reverse_ub_share + 1e-12)))
  blend_summary <- function(x, resolution, sample) {
    scoped <- scope_panel(time_panel(x, "2019–2023"), blend_rules)
    if (resolution == "affiliate_year") {
      scoped <- scoped |> summarise(
        n_bilateral = n(), n_parent_support = n_distinct(parent),
        reporters = paste(sort(unique(parent)), collapse = ";"),
        n_close_denom = sum(close_denom), n_same_margin_totals = sum(same_margin_totals),
        across(c(low_group, low_juris, profit_group, profit_juris, corrected_profit),
               sum_obs),
        across(c(local_topup_group, local_topup_juris, worldwide_topup),
               ~ if (all(is.finite(.x))) sum(.x) else NA_real_),
        .by = c(scope, window, affiliate, year)
      ) |> mutate(share_group = low_group / profit_group, share_juris = low_juris / profit_juris)
    } else {
      scoped <- scoped |> mutate(n_bilateral = 1L, n_parent_support = 1L, reporters = parent,
                                 n_close_denom = as.integer(close_denom),
                                 n_same_margin_totals = as.integer(same_margin_totals))
    }
    d <- scoped |> bounds() |> mutate(weight = if_else(corrected_profit > 0, corrected_profit, NA_real_))
    sm <- d |> summarise(
      observations = n(), matched_pair_years = sum(n_bilateral),
      host_years = n_distinct(affiliate, year),
      reporters = paste(sort(unique(unlist(strsplit(reporters, ";", fixed = TRUE)))), collapse = ";"),
      near_denominator_pair_years = sum(n_close_denom),
      equal_denominator_and_count_pair_years = sum(n_same_margin_totals),
      positive_weight_units = sum(is.finite(weight)),
      group_profit_usd = sum_obs(profit_group), juris_profit_usd = sum_obs(profit_juris),
      group_low_usd = sum_obs(low_group), juris_low_usd = sum_obs(low_juris),
      group_share_raw = ratio(group_low_usd, group_profit_usd),
      juris_share_raw = ratio(juris_low_usd, juris_profit_usd),
      common_weight_usd = sum_obs(weight),
      group_share_common = ratio(sum_obs(weight * share_group), common_weight_usd),
      juris_share_common = ratio(sum_obs(weight * share_juris), common_weight_usd),
      common_low_difference_usd = sum_obs(weight * gap_share),
      across(c(hidden_lb_share, hidden_ub_share, reverse_lb_share, reverse_ub_share),
             ~ sum_obs(weight * .x), .names = "{.col}_times_weight_usd"),
      liability_comparison_units = sum(is.finite(worldwide_topup) & is.finite(local_topup_juris)),
      liability_comparison_weight_usd = sum_obs(weight[is.finite(worldwide_topup) &
                                                      is.finite(local_topup_juris)]),
      group_worldwide_gap_topup_usd = sum_obs(worldwide_topup[is.finite(local_topup_juris)]),
      juris_topup_usd_on_group_gap_support = sum_obs(local_topup_juris[is.finite(worldwide_topup)]),
      group_worldwide_gap_topup_common_usd = sum_obs(
        (weight * worldwide_topup / profit_group)[is.finite(local_topup_juris)]),
      juris_topup_common_usd_on_group_gap_support = sum_obs(
        (weight * local_topup_juris / profit_juris)[is.finite(worldwide_topup)]),
      group_local_gap_proxy_usd = sum_obs(local_topup_group[is.finite(local_topup_juris)]),
      juris_topup_usd_on_group_local_gap_support = sum_obs(local_topup_juris[is.finite(local_topup_group)]),
      .by = c(scope, window)
    )
    # Explicitly include unsupported scopes (especially USA) as zero counts, NA amounts.
    sm <- expand_grid(scope = names(blend_rules), window = c(as.character(2019:2023), "2019–2023")) |>
      left_join(sm, by = c("scope", "window")) |>
      mutate(across(c(observations, matched_pair_years, host_years, near_denominator_pair_years,
                      equal_denominator_and_count_pair_years, positive_weight_units,
                      liability_comparison_units), ~ coalesce(.x, 0L)),
             record = "matched_summary", resolution = resolution, sample = sample)
    stopifnot(all(with(sm, abs(common_low_difference_usd -
      common_weight_usd * (juris_share_common - group_share_common)) <
      pmax(1e-3, common_weight_usd * 1e-12)), na.rm = TRUE))
    sm
  }

  standalone <- function(x, table_name, sample = "observed_partitions") {
    years <- if (table_name == "III") MAIN_YEARS else 2019:2023
    d <- bind_rows(time_panel(filter(x, year %in% 2019:2023), "2019–2023"),
                   mutate(filter(x, year < 2019, year %in% years), window = as.character(year)))
    sm <- scope_panel(d, blend_rules) |>
      summarise(observations = n(), host_years = n_distinct(affiliate, year),
        reporters = paste(sort(unique(parent)), collapse = ";"),
        denominator_usd = sum_obs(profit), low_usd = sum_obs(low), low_tax_usd = sum_obs(low_tax),
        low_share = ratio(low_usd, denominator_usd),
        local_gap_proxy_usd = sum_obs(local_topup), local_gap_cells = sum(is.finite(local_topup)),
        .by = c(scope, window))
    if (table_name == "III") {
      sm <- left_join(sm, scope_panel(d, blend_rules) |> summarise(
        worldwide_gap_proxy_usd = sum_obs(worldwide_topup),
        worldwide_gap_cells = sum(is.finite(worldwide_topup)), .by = c(scope, window)
      ), by = c("scope", "window"), relationship = "one-to-one")
    }
    expand_grid(scope = names(blend_rules), window = c(as.character(years), "2019–2023")) |>
      left_join(sm, by = c("scope", "window")) |>
      mutate(record = "standalone_summary", table = table_name, sample = sample,
             across(c(observations, host_years, local_gap_cells), ~ coalesce(.x, 0L)))
  }
  # Historical schemes straddle 15%. Bound the low share by assigning all or
  # none of the ambiguous bin to it, only when that reporter's full partition is
  # published and each bin has non-negative net profit.
  legacy_schemes <- list(
    legacy_four = c("rate_0_10", "rate_10_20", "rate_20_30", "rate_30"),
    legacy_three = c("rate_0_10", "rate_10_20", "rate_20"),
    legacy_two_includes_negative_accrual = c("rate_10_accrued", "rate_10")
  )
  legacy_input <- t3 |> country_rows() |> filter(year %in% 2017:2018)
  legacy <- imap_dfr(legacy_schemes, function(bins, scheme) {
    regimes <- t3 |> filter(year %in% 2017:2018) |> summarise(
      supports_scheme = all(bins %in% etr_bracket) &&
        !any(setdiff(unique(unlist(legacy_schemes)), bins) %in% etr_bracket),
      .by = c(parent, year)
    ) |> filter(supports_scheme)
    legacy_input |> semi_join(regimes, by = c("parent", "year")) |>
      filter(etr_bracket %in% bins) |>
      summarise(observed_bins = n(), all_valid = all(is.finite(profit) & profit >= 0),
        known_low = sum(profit[etr_bracket == bins[1L]]),
        ambiguous = sum(profit[etr_bracket == bins[2L]]),
        denominator = sum(profit), .by = all_of(key)) |>
      filter(observed_bins == length(bins), all_valid, denominator > 0) |>
      mutate(scheme = rep(scheme, n()))
  })
  legacy_summary <- scope_panel(legacy, blend_rules) |> summarise(
    observations = n(), reporters = paste(sort(unique(parent)), collapse = ";"),
    denominator_usd = sum(denominator), low_usd_lower = sum(known_low),
    low_usd_upper = sum(known_low + ambiguous), low_share_lower = low_usd_lower / denominator_usd,
    low_share_upper = low_usd_upper / denominator_usd, .by = c(scope, year, scheme)
  ) |> mutate(record = "table3_legacy_15pct_bounds", table = "III", window = as.character(year))

  # The published 2020 Chile Table III bilateral values have a major scale
  # discontinuity versus Table I. Preserve the original and report exclusion
  # sensitivity without imposing an unverifiable exchange rate or rescaling.
  chile_audit <- g |> filter(parent == "CHL", year == 2020) |>
    left_join(t1 |> select(all_of(key), table1_net_profit = profit,
                          table1_positive_profit = profit_panelai),
              by = key, relationship = "one-to-one") |>
    mutate(record = "table3_chile_2020_scale_check", table = "III", window = as.character(year))
  blend <- bind_rows(
    map_dfr(c("bilateral", "affiliate_year"), function(res) bind_rows(
      blend_summary(matched, res, "matched_observed_partitions"),
      blend_summary(filter(matched, close_denom), res, "denominators_within_5pct"),
      blend_summary(filter(matched, same_margin_totals), res, "equal_denominator_and_count")
    )),
    standalone(g, "III"), standalone(j, "IV"),
    standalone(filter(g, !(parent == "CHL" & year == 2020)), "III", "excluding_Chile_2020"),
    legacy_summary, chile_audit,
    scope_panel(country_rows(filter(t3, year %in% MAIN_YEARS)), blend_rules) |>
      summarise(observations = n(), profit_observed = sum(is.finite(profit)),
                bracket_net_profit_usd = sum_obs(profit),
                bracket_positive_part_usd = sum_obs(pmax(profit, 0)),
                .by = c(scope, year, etr_bracket)) |>
      mutate(record = "table3_bracket_inventory", table = "III", window = as.character(year)),
    bounds(matched) |> mutate(record = "matched_cell", resolution = "bilateral",
                             window = as.character(year)),
    group_gap |> mutate(record = "worldwide_gap_input", table = "III",
                        window = as.character(year))
  )

  # Wage benchmark by host-year; do not impute missing wages or reported tax/inputs.
  wage <- base |> filter(is.finite(affiliate_wage_annual), affiliate_wage_annual > 0) |>
    distinct(affiliate, year, affiliate_wage_annual, affiliate_population)
  assert_keys(wage, c("affiliate", "year"))

  # 2. Tables VI and V: USD worldwide unrelated-party-revenue bands, not the
  # statutory EUR 750m consolidated revenue test. Net class-cell profit is signed.
  t6 <- load_panel("cbcr_table6")
  t5 <- load_panel("cbcr_table5")
  assert_keys(t6, c(key, "size_class"))
  assert_keys(t5, c("parent", "year"))
  fine <- c("size_less_2_5", "size_2_5_5", "size_5_10", "size_greater_10")
  coarse <- c("size_less_5", "size_greater_5")
  size_amounts <- c("cbcr_count", "subgroups_count", "entities_count", "employees",
                    "assets", "profit", "tax_accrued")
  stopifnot(all(t6$size_class %in% c(fine, coarse)))
  size_rules <- list(Global = function(x) rep(TRUE, nrow(x)),
                     EU27_hosts = function(x) x$affiliate %in% EU27_ISO3,
                     EU27_parents = function(x) x$parent %in% EU27_ISO3,
                     EU27_parents_EU27_hosts = function(x) x$parent %in% EU27_ISO3 &
                       x$affiliate %in% EU27_ISO3,
                     USA_parents = function(x) x$parent == "USA",
                     USA_parents_EU27_hosts = function(x) x$parent == "USA" &
                       x$affiliate %in% EU27_ISO3)
  size_raw <- country_rows(t6)
  size_cells <- size_raw |>
    summarise(
      n_fine = sum(size_class %in% fine), n_coarse = sum(size_class %in% coarse),
      n_low_fine = sum(size_class %in% fine[1:2]),
      n_high_fine = sum(size_class %in% fine[3:4]),
      low_coarse = any(size_class == coarse[1]),
      high_coarse = any(size_class == coarse[2]),
      .by = all_of(key)
    ) |>
    mutate(low_complete = low_coarse | n_low_fine == 2,
           high_complete = high_coarse | n_high_fine == 2)
  # The two halves can use different resolutions within a cell. Never add a
  # coarse band to its constituent fine bands.
  stopifnot(!any(with(size_cells, (low_coarse & n_low_fine > 0) |
                                    (high_coarse & n_high_fine > 0))))
  size_raw <- left_join(size_raw, size_cells, by = key, relationship = "many-to-one")
  size_full <- filter(size_raw, n_fine == 4 | n_coarse == 2)
  size_5 <- size_raw |> filter(low_complete, high_complete) |>
    mutate(size_class = if_else(size_class %in% c(fine[1:2], coarse[1]), coarse[1], coarse[2])) |>
    summarise(across(all_of(size_amounts), sum), .by = c(all_of(key), size_class))

  prepare_size <- function(x) {
    x |>
      left_join(wage, by = c("affiliate", "year"), relationship = "many-to-one") |>
      mutate(
        employee_outlier = !is.na(employees) & (employees < 0 |
          (!is.na(entities_count) & employees > entities_count * 100000) |
          (!is.na(affiliate_population) & employees > affiliate_population)),
        employees_screened = if_else(employee_outlier, NA_real_, employees),
        positive_cell_profit = pmax(profit, 0),
        payroll_proxy = employees_screened * affiliate_wage_annual,
        sbie_initial = 0.10 * payroll_proxy + 0.08 * if_else(assets >= 0, assets, NA_real_),
        sbie_long_run = 0.05 * (payroll_proxy + if_else(assets >= 0, assets, NA_real_)),
        cell_phi_initial = clip(ratio(sbie_initial, profit)),
        cell_phi_long_run = clip(ratio(sbie_long_run, profit)),
        topup = if_else(profit > 0, row_topup(tax_accrued, profit), NA_real_)
      )
  }
  size_summary <- function(x, sample) {
    x <- prepare_size(x)
    sm <- scope_panel(time_panel(x, "2022–2023"), size_rules) |>
      summarise(
        observations = n(), parent_years = n_distinct(parent, year),
        parents = n_distinct(parent), affiliates = n_distinct(affiliate),
        across(all_of(size_amounts), sum_obs, .names = "{.col}_total"),
        across(all_of(size_amounts), ~ sum(is.finite(.x)), .names = "{.col}_n"),
        domestic_cbcr_count = sum_obs(cbcr_count[parent == affiliate]),
        positive_cell_profit_usd = sum_obs(positive_cell_profit),
        tax_matched_net_profit_usd = sum_obs(profit[is.finite(tax_accrued)]),
        tax_matched_net_etr = ratio(sum_obs(tax_accrued[is.finite(profit)]), tax_matched_net_profit_usd),
        tax_matched_positive_profit_usd = sum_obs(profit[profit > 0 & is.finite(tax_accrued)]),
        positive_cell_etr = ratio(sum_obs(tax_accrued[profit > 0 & is.finite(profit)]),
                                  tax_matched_positive_profit_usd),
        profit_per_employee_usd = ratio(sum_obs(profit[is.finite(profit) & is.finite(employees_screened)]),
                                       sum_obs(employees_screened[is.finite(profit)])),
        positive_profit_per_employee_usd = ratio(
          sum_obs(profit[profit > 0 & is.finite(employees_screened)]),
          sum_obs(employees_screened[is.finite(profit) & profit > 0])),
        employees_screened_outliers = sum(employee_outlier),
        phi_support_profit_usd = sum_obs(profit[is.finite(cell_phi_initial)]),
        phi_initial = ratio(sum_obs(cell_phi_initial * profit), phi_support_profit_usd),
        phi_long_run = ratio(sum_obs(cell_phi_long_run * profit), phi_support_profit_usd),
        pre_sbie_topup_usd = sum_obs(topup),
        pre_sbie_topup_rate = ratio(pre_sbie_topup_usd, tax_matched_positive_profit_usd),
        post_sbie_support_profit_usd = sum_obs(profit[is.finite(topup) & is.finite(cell_phi_initial)]),
        pre_sbie_topup_usd_on_post_support = sum_obs(topup[is.finite(cell_phi_initial)]),
        post_sbie_initial_topup_usd = sum_obs(topup * (1 - cell_phi_initial)),
        post_sbie_long_run_topup_usd = sum_obs(topup * (1 - cell_phi_long_run)),
        post_sbie_initial_rate = ratio(post_sbie_initial_topup_usd, post_sbie_support_profit_usd),
        post_sbie_long_run_rate = ratio(post_sbie_long_run_topup_usd, post_sbie_support_profit_usd),
        .by = c(scope, window, size_class)
      ) |>
      mutate(
        across(c(cbcr_count_total, subgroups_count_total, entities_count_total,
                 employees_total, assets_total, positive_cell_profit_usd, domestic_cbcr_count,
                 pre_sbie_topup_usd, post_sbie_initial_topup_usd),
               ~ ratio(.x, sum_obs(.x)), .names = "{.col}_share"),
        .by = c(scope, window)
      )
    classes <- if (sample %in% c("complete_coarse", "harmonised_5bn")) coarse else fine
    share_check <- sm |> summarise(across(ends_with("_share"), sum_obs), .by = c(scope, window))
    share_values <- unlist(select(share_check, ends_with("_share")), use.names = FALSE)
    stopifnot(all(abs(share_values - 1) < 1e-10, na.rm = TRUE))
    stopifnot(all(with(sm, post_sbie_support_profit_usd <= phi_support_profit_usd &
      post_sbie_initial_topup_usd <= post_sbie_long_run_topup_usd + 1e-6 &
      post_sbie_long_run_topup_usd <= pre_sbie_topup_usd_on_post_support + 1e-6),
      na.rm = TRUE))
    expand_grid(scope = names(size_rules), window = c("2022", "2023", "2022–2023"),
                size_class = classes) |>
      left_join(sm, by = c("scope", "window", "size_class")) |>
      mutate(record = "size_summary", sample = sample, observations = coalesce(observations, 0L))
  }
  # Matched size-extreme test: aggregate within reporting parents before inference.
  # Use identical cells and a common support for ETR and both post-SBIE rates.
  size_extreme <- prepare_size(filter(size_full, n_fine == 4, size_class %in% fine[c(1, 4)])) |>
    filter(profit > 0, is.finite(topup), is.finite(cell_phi_initial)) |>
    group_by(across(all_of(key))) |> filter(n() == 2) |> ungroup()
  size_test_parent <- scope_panel(time_panel(size_extreme, "2022–2023"), size_rules) |>
    summarise(
      paired_cells = n(), positive_profit_usd = sum(profit),
      etr = sum(tax_accrued) / positive_profit_usd,
      phi = sum(profit * cell_phi_initial) / positive_profit_usd,
      post_sbie_rate = sum(topup * (1 - cell_phi_initial)) / positive_profit_usd,
      .by = c(scope, window, parent, size_class)
    ) |>
    pivot_longer(c(etr, phi, post_sbie_rate), names_to = "metric", values_to = "rate") |>
    pivot_wider(names_from = size_class, values_from = c(rate, positive_profit_usd, paired_cells)) |>
    mutate(large_minus_small = rate_size_greater_10 - rate_size_less_2_5)
  size_test <- size_test_parent |>
    summarise(
      parents = n(), paired_cells = sum(paired_cells_size_greater_10),
      median_large_minus_small = median_obs(large_minus_small),
      paired_parent_p = signed_rank(large_minus_small),
      .by = c(scope, window, metric)
    )
  size_out <- bind_rows(
    size_summary(filter(size_raw, size_class %in% fine), "observed_fine"),
    size_summary(filter(size_full, n_fine == 4), "complete_fine"),
    size_summary(filter(size_full, n_coarse == 2), "complete_coarse"),
    size_summary(size_5, "harmonised_5bn"),
    t6 |> summarise(observations = n(), parents = n_distinct(parent),
                     affiliates = n_distinct(affiliate), .by = c(year, size_class)) |>
      mutate(record = "size_raw_inventory", window = as.character(year)),
    t5 |> filter(year %in% MAIN_YEARS) |>
      mutate(record = "table5_worldwide_group_size_percentiles", window = as.character(year),
             p50_class = case_when(
               !is.finite(upr_p50) ~ NA_character_, upr_p50 < 2.5e9 ~ fine[1],
               upr_p50 < 5e9 ~ fine[2], upr_p50 <= 10e9 ~ fine[3], TRUE ~ fine[4]
             )),
    mutate(size_test_parent, record = "size_extreme_paired_parent"),
    mutate(size_test, record = "size_extreme_paired_test")
  )

  # 3. Table II's reported IQMs are separate univariate statistics. No ETR or
  # SBIE of an identified common middle group, nor a point estimate for the top
  # quartile, can be recovered from the ratios of these means.
  iq_vars <- c("profit", "tax_accrued", "assets", "employees", "subgroups_count")
  iq_names <- paste0(iq_vars, "_panelai")
  iq_select <- function(x, prefix) {
    x |> country_rows() |> filter(year %in% MAIN_YEARS) |>
      select(all_of(key), all_of(iq_names)) |>
      rename_with(~ paste0(prefix, "_", sub("_panelai$", "", .x)), all_of(iq_names))
  }
  iq_cells <- inner_join(iq_select(t1, "t1"), iq_select(t2, "t2"), by = key,
                         relationship = "one-to-one") |>
    left_join(wage, by = c("affiliate", "year"), relationship = "many-to-one") |>
    filter(t1_profit > 0, t2_profit > 0, t1_subgroups_count > 0) |>
    mutate(
      table2_statistic = if_else(year == 2017L, "ordinary_mean_vintage", "reported_IQM_vintage"),
      counts_match = !is.na(t2_subgroups_count) &
        abs(t2_subgroups_count - t1_subgroups_count) < 1e-6,
      all_etr = t1_tax_accrued / t1_profit,
      iqm_ratio_etr = t2_tax_accrued / t2_profit,
      all_phi = clip((0.10 * t1_employees * affiliate_wage_annual + 0.08 * t1_assets) / t1_profit),
      iqm_ratio_phi = clip((0.10 * t2_employees * affiliate_wage_annual + 0.08 * t2_assets) / t2_profit),
      profit_iqm_to_ordinary_mean = t2_profit * t1_subgroups_count / t1_profit,
      matches_mean_0_1pct = abs(profit_iqm_to_ordinary_mean - 1) <= 0.001,
      # Extrapolating the IQM to ALL subgroups does not estimate the outer tails.
      mean_scaled_shortfall = 1 - profit_iqm_to_ordinary_mean,
      core_half_proxy = if_else(year >= 2018 & counts_match & t1_subgroups_count >= 8,
                                0.5 * profit_iqm_to_ordinary_mean, NA_real_),
      # If exactly half of the observations are retained by trimming, the upper
      # quartile's share is at least half the core share and at least outer-core/2.
      # The bottom quartile is non-negative and cannot exceed half the core.
      half_core_order_feasible = is.finite(core_half_proxy) &
        core_half_proxy >= 0 & core_half_proxy <= 2 / 3,
      outer_both_tails_proxy = if_else(half_core_order_feasible, 1 - core_half_proxy, NA_real_),
      top_quartile_lb_conditional = pmax(0.5 * core_half_proxy, 0.5 * outer_both_tails_proxy,
                                        outer_both_tails_proxy - 0.5 * core_half_proxy),
      top_quartile_ub_conditional = outer_both_tails_proxy
    )
  # Exact half-count premise is most defensible where the subgroup count is a
  # multiple of four. This remains a sensitivity because published IQMs can
  # include ties at quartile thresholds or depart from the requested convention.
  stopifnot(all(iq_cells$top_quartile_lb_conditional <= iq_cells$top_quartile_ub_conditional + 1e-12,
                na.rm = TRUE))
  iq_summary <- function(x, sample) {
    d <- scope_panel(bind_rows(mutate(x, window = as.character(year)),
      mutate(filter(x, year >= 2018), window = "2018–2023")), host_rules)
    d |> summarise(
      observations = n(), parents = n_distinct(parent),
      counts_match_n = sum(counts_match), matches_mean_n = sum(matches_mean_0_1pct),
      reported_profit_usd = sum(t1_profit),
      etr_n = sum(is.finite(all_etr) & is.finite(iqm_ratio_etr)),
      all_etr_median = median_obs(all_etr[is.finite(iqm_ratio_etr)]),
      iqm_ratio_etr_median = median_obs(iqm_ratio_etr[is.finite(all_etr)]),
      median_etr_gap = median_obs(iqm_ratio_etr - all_etr),
      profit_weighted_etr_gap = ratio(sum_obs(t1_profit * (iqm_ratio_etr - all_etr)),
        sum_obs(t1_profit[is.finite(iqm_ratio_etr - all_etr)])),
      paired_etr_lower_share = mean(iqm_ratio_etr < all_etr, na.rm = TRUE),
      phi_n = sum(is.finite(all_phi) & is.finite(iqm_ratio_phi)),
      all_phi_median = median_obs(all_phi[is.finite(iqm_ratio_phi)]),
      iqm_ratio_phi_median = median_obs(iqm_ratio_phi[is.finite(all_phi)]),
      median_phi_gap = median_obs(iqm_ratio_phi - all_phi),
      profit_weighted_phi_gap = ratio(sum_obs(t1_profit * (iqm_ratio_phi - all_phi)),
        sum_obs(t1_profit[is.finite(iqm_ratio_phi - all_phi)])),
      paired_phi_lower_share = mean(iqm_ratio_phi < all_phi, na.rm = TRUE),
      mean_scaled_shortfall_median = median_obs(mean_scaled_shortfall),
      mean_scaled_shortfall_negative_n = sum(mean_scaled_shortfall < 0),
      tail_proxy_n = sum(half_core_order_feasible),
      tail_proxy_profit_usd = sum_obs(t1_profit[half_core_order_feasible]),
      outer_both_tails_weighted_proxy = ratio(sum_obs(t1_profit * outer_both_tails_proxy),
                                             tail_proxy_profit_usd),
      upper_tail_weighted_lb_conditional = ratio(sum_obs(t1_profit * top_quartile_lb_conditional),
                                                 tail_proxy_profit_usd),
      upper_tail_weighted_ub_conditional = outer_both_tails_weighted_proxy,
      .by = c(scope, window, table2_statistic)
    ) |> mutate(record = "matched_summary", sample = sample)
  }
  iq_out <- bind_rows(
    iq_summary(iq_cells, "all_matched_positive_profit"),
    iq_summary(filter(iq_cells, counts_match, t1_subgroups_count >= 8), "same_counts_min_8"),
    iq_summary(filter(iq_cells, year >= 2018, counts_match, t1_subgroups_count >= 8,
                      abs(t1_subgroups_count / 4 - round(t1_subgroups_count / 4)) < 1e-6),
               "same_counts_multiple_of_4_min_8"),
    mutate(iq_cells, record = "matched_cell", window = as.character(year))
  )

  # 4. Entity activity incidence, not mutually exclusive shares. Restrict to
  # explicit <15/15+ reporter schemes. Pair low/high bins separately by activity
  # so the weighted shares have the same reporting support.
  act_long <- t3 |> country_rows() |>
    filter(year %in% MAIN_YEARS, etr_bracket %in% c("rate_0_15", "rate_15"),
           entities_count > 0) |>
    select(all_of(key), etr_bracket, entities_count, all_of(activity)) |>
    pivot_longer(all_of(activity), names_to = "activity", values_to = "entities_active") |>
    filter(is.finite(entities_active), between(entities_active, 0, entities_count))
  act_match <- act_long |> pivot_wider(names_from = etr_bracket,
                                      values_from = c(entities_count, entities_active)) |>
    filter(is.finite(entities_active_rate_0_15), is.finite(entities_active_rate_15)) |>
    mutate(share_low = entities_active_rate_0_15 / entities_count_rate_0_15,
           share_high = entities_active_rate_15 / entities_count_rate_15,
           gap = share_low - share_high)
  activity_comp <- scope_panel(time_panel(act_match, "2017–2023"), host_rules[1:2]) |>
    summarise(observations = n(), parents = n_distinct(parent),
      entities_low = sum(entities_count_rate_0_15),
      entities_high = sum(entities_count_rate_15),
      share_low = sum(entities_active_rate_0_15) / entities_low,
      share_high = sum(entities_active_rate_15) / entities_high,
      composition_gap = share_low - share_high, median_paired_gap = median(gap),
      .by = c(scope, window, activity)
    ) |> mutate(record = "table3_activity_paired")

  core_act <- activity[1:5]
  core_cols <- paste0(core_act, "_panelai")
  regression <- base |>
    select(all_of(key), entities_count_panelai, all_of(core_cols)) |>
    filter(entities_count_panelai > 0,
           if_all(all_of(core_cols), ~ is.finite(.x) & between(.x, 0, entities_count_panelai))) |>
    mutate(across(all_of(core_cols), ~ .x / entities_count_panelai)) |>
    inner_join(s1 |> select(all_of(key), analysis_profit_positive,
      l3 = stage1_distributional_liability_rate, l4 = ladder_l4_strict_liability_rate),
      by = key, relationship = "one-to-one") |>
    inner_join(s2 |> filter(rate_scenario == "initial") |>
      select(all_of(key), phi = stage2_phi),
      by = key, relationship = "one-to-one") |>
    filter(year %in% MAIN_YEARS, analysis_profit_positive > 0)
  fit_activity <- function(x, scope, outcome, fe) {
    x <- filter(x, is.finite(.data[[outcome]]))
    # Test identifying outcome variation on the estimation sample explicitly.
    within <- x |> summarise(spread = max(.data[[outcome]]) - min(.data[[outcome]]),
                              .by = c(affiliate, year))
    nf <- if (fe == "affiliate^year") sum(within$spread > 1e-12) else NA_integer_
    counts <- function(d) tibble(observations = nrow(d), parents = n_distinct(d$parent),
        affiliates = n_distinct(d$affiliate), host_years = n_distinct(d$affiliate, d$year))
    info <- counts(x)
    if (fe == "affiliate^year" && nf == 0L) {
      return(bind_cols(info, tibble(status = "absorbed_by_affiliate_year_FE",
        host_years_with_outcome_variation = nf, term = core_cols,
        estimate = NA_real_, std_error = NA_real_, p_value = NA_real_)))
    }
    model <- fixest::feols(as.formula(paste(outcome, "~", paste(core_cols, collapse = " + "), "|", fe)),
                   data = x, vcov = ~ parent + affiliate, notes = FALSE)
    used <- x[fixest::obs(model), , drop = FALSE]
    cc <- fixest::coeftable(model)
    used_within <- used |> summarise(
      spread = max(.data[[outcome]]) - min(.data[[outcome]]), .by = c(affiliate, year)
    )
    left_join(tibble(term = core_cols), tibble(term = rownames(cc), estimate = cc[, 1],
       std_error = cc[, 2], p_value = cc[, 4]), by = "term") |>
      mutate(
        !!!counts(used), status = if_else(is.finite(estimate), "estimated", "collinear"),
        host_years_with_outcome_variation = if (fe == "affiliate^year")
          sum(used_within$spread > 1e-12) else NA_integer_,
        within_r2 = as.numeric(fixest::fitstat(model, "wr2")[[1]]),
        # x and y are shares: a 10 pp change in x corresponds to 10 * beta pp of y.
        outcome_pp_per_10pp_activity = 10 * estimate,
        se_pp_per_10pp_activity = 10 * std_error,
        p_value_holm_within_model = p.adjust(p_value, method = "holm")
      )
  }
  activity_fits <- pmap_dfr(expand_grid(scope = names(host_rules)[1:2],
      outcome = c("l3", "l4", "phi"),
      fixed_effects = c("affiliate + year", "affiliate^year", "parent + affiliate^year")),
    function(scope, outcome, fixed_effects) {
      d <- regression[host_rules[[scope]](regression), ]
      fe <- if (outcome == "l3" && fixed_effects == "parent + affiliate^year")
        "affiliate^year" else fixed_effects
      fit_activity(d, scope, outcome, fe) |>
        mutate(record = "activity_regression", scope = scope, outcome = outcome,
               fixed_effects = fixed_effects, window = "2017–2023")
    })
  act_out <- bind_rows(activity_comp, activity_fits)

  outputs <- list(
    step14_table3_vs_table4_blending_wedge = blend,
    step14_table6_mne_size_incidence = size_out,
    step14_table2_interquartile_skewness = iq_out,
    step14_business_activity_drivers = act_out
  )
  stopifnot(all(vapply(outputs, nrow, integer(1)) > 0L))
  dir.create(DIAGNOSTICS_DIR, recursive = TRUE, showWarnings = FALSE)
  iwalk(outputs, function(x, name) {
    x <- mutate(x, across(where(is.double), ~ replace(.x, !is.finite(.x), NA_real_)))
    write_csv(x, file.path(DIAGNOSTICS_DIR, paste0(name, ".csv")))
    message(name, ": ", nrow(x), " rows")
  })
}

if (is_direct_script_run("code/diagnostics_step14_cbcr_tables_2_3_5_6_extensions.R")) {
  run_diagnostics_step14()
}
