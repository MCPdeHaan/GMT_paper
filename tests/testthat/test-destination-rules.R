destination_methods <- source_pipeline("behaviour/destination_rules.R", new.env())
fiscal_methods <- source_pipeline("behaviour/fiscal_incidence.R", new.env())

destination_fixture <- function() {
  tibble::tibble(
    parent = "USA", affiliate = c("IRL", "DEU", "FRA", "NLD", "BEL", "PRT", "SWE", "CZE", "DNK"),
    year = 2023L,
    affiliate_cit_destination_gate_rate = c(.2, .15, .150001, .25, .25, NA, .22, .14, .2),
    etr_panelai_stage1 = c(.2, .12, .10, .05, .04, .14, NA, .14, .14),
    employees_sbie = c(1, 3, 1, 1, 1, 1, 1, 1, NA),
    payroll_sbie = c(1, 1, 3, 1, 1, 1, 1, 1, -1),
    upr_panelai = c(1, 3, 1, 1, 1, 1, 1, 1, 0)
  ) |>
    dplyr::mutate(affiliate_cit_rate_unit = affiliate_cit_destination_gate_rate,
      affiliate_cit_destination_price_rate = .25,
      affiliate_is_conduit_haven = affiliate == "NLD",
      affiliate_jurisdiction_name = affiliate, selected_low_share = .5,
      analysis_profit_positive = 200, scenario_id = "x10011", rate_scenario = "initial",
      factor1_etr = "distributional", factor2_substance = "aggregate_sbie",
      factor3_rates = "initial", factor4_sbs = "sbs", factor5_behaviour = "behavioural",
      x1_etr = 1L, x2_substance = 0L, x3_rates = 0L, x4_sbs = 1L, x5_behaviour = 1L,
      reallocated_profit = ifelse(affiliate == "IRL", 100, 0), static_tau_low = .05,
      reallocated_profit_transfer_pricing_ip = .72 * reallocated_profit,
      reallocated_profit_debt = .28 * reallocated_profit,
      reallocated_profit_substance_planning = 0)
}

host_fixture <- function(panel) {
  dplyr::distinct(panel, affiliate, year, avg_etr_stage1 = etr_panelai_stage1)
}

test_that("Rule B tests the historical gate, source ETR and origin before computing source weights", {
  e <- destination_methods
  panel <- destination_fixture()
  foot <- e$build_rule_b_footprint(panel)
  expect_false(any(c("PRT", "CZE", "DNK") %in% foot$destination))
  expect_true(all(c("DEU", "FRA") %in% foot$destination))
  expect_equal(foot$statutory_rate[foot$destination == "DEU"], .15)
  global <- e$build_rule_b_global_footprint(foot, host_fixture(panel))
  source <- tibble::tibble(source_id = 1:3, parent = c("USA", "USA", "CAN"),
    affiliate = "IRL", year = 2023L, source_etr = c(.05, .11, .11),
    reallocated_profit = c(100, 20, 30))
  routes <- e$allocate_rule_b_sources(source, foot, global)
  expect_identical(routes$destination, c("DEU", "FRA", "DEU", "DEU"))
  expect_equal(routes$weight, c(.625, .375, 1, 1))
  expect_equal(routes$received, c(62.5, 37.5, 20, 30))
  expect_identical(routes$route, c(rep("parent_activity", 3), "global_activity"))
  expect_error(e$allocate_rule_b_sources(dplyr::mutate(source, source_etr = NA_real_), foot, global))
  expect_error(e$allocate_rule_b_sources(dplyr::mutate(source, year = 2022L), foot, global),
    "unsupported source")
  expect_error(e$allocate_rule_b_sources(dplyr::mutate(source, source_etr = .14), foot, global),
    "unsupported source")
  expect_error(e$build_rule_b_footprint(dplyr::bind_rows(panel,
    dplyr::mutate(panel[2, ], employees_sbie = 2))), "duplicate")
})

test_that("Rule B preserves observed non-EU support and does not join across years", {
  e <- destination_methods
  panel <- destination_fixture() |> dplyr::filter(affiliate == "DEU") |>
    dplyr::mutate(affiliate = "GBR", year = 2022L)
  panel <- dplyr::bind_rows(panel, dplyr::mutate(panel, affiliate = "FRA", year = 2023L))
  foot <- e$build_rule_b_footprint(panel)
  sources <- tibble::tibble(source_id = 1:2, parent = "USA", affiliate = "IRL",
    year = 2022:2023, source_etr = .05, reallocated_profit = c(30, 40))
  routes <- e$allocate_rule_b_sources(sources, foot, e$build_rule_b_global_footprint(foot, host_fixture(panel)))
  expect_identical(routes$destination, c("GBR", "FRA"))
  expect_equal(routes$received, c(30, 40))
  expect_equal(sum(routes$received[routes$year == 2022L & routes$destination %in% e$EU27_ISO3]), 0)
})

test_that("Rule B renormalises the original weighted combination on available activity", {
  e <- destination_methods
  p <- destination_fixture()
  p$employees_sbie <- ifelse(p$affiliate == "DEU", NA_real_, p$employees_sbie)
  p$payroll_sbie <- ifelse(p$affiliate == "FRA", NA_real_, p$payroll_sbie)
  p$upr_panelai <- ifelse(p$affiliate %in% c("DEU", "FRA"), NA_real_, p$upr_panelai)
  f <- e$build_rule_b_footprint(p)
  expect_equal(f$employees[f$destination == "DEU"], 0)
  expect_equal(f$payroll[f$destination == "FRA"], 0)
  expect_equal(f$upr[f$destination %in% c("DEU", "FRA")], c(0, 0))
  src <- tibble::tibble(source_id = 1L, parent = "USA", affiliate = "IRL", year = 2023L,
    source_etr = .05, reallocated_profit = 100)
  route <- function(f) e$allocate_rule_b_sources(src, f, e$build_rule_b_global_footprint(f, host_fixture(p)))
  expect_equal(route(f)$received, c(50, 50))
  # If only payroll is supported, payroll shares govern all the allocation.
  f <- dplyr::mutate(f, employees = 0, payroll = replace(payroll, destination == "FRA", 3))
  expect_equal(route(f)$received, c(25, 75))
  zero <- dplyr::mutate(p, reallocated_profit = 0)
  expect_equal(nrow(fiscal_methods$build_rule_b_reallocation(zero, host_fixture(zero))), 0L)
  priced <- destination_fixture() |> dplyr::mutate(affiliate_cit_destination_price_rate =
    ifelse(affiliate == "FRA", .20, .25))
  receipts <- fiscal_methods$build_rule_b_reallocation(priced, host_fixture(priced))
  expect_equal(sum(receipts$ordinary_cit_gross_destination_revenue), 23.125)
  expect_equal(sum(receipts$ordinary_cit_source_loss), 5)
  expect_equal(sum(receipts$ordinary_cit_net_recovery), 18.125)
})

test_that("the global Rule A compatibility pool keeps its own fallback and channels", {
  e <- fiscal_methods
  p <- destination_fixture() |> dplyr::filter(affiliate %in% c("IRL", "DEU", "NLD")) |>
    dplyr::mutate(affiliate_cit_rate_unit = c(.1, .15, .25))
  result <- e$build_rule_a_global_reallocation(p)
  expect_true(all(result$matrix$destination == "DEU"))
  expect_equal(result$matrix$reallocated_profit_received[
    match(c("transfer_pricing_ip", "debt"), result$matrix$behavioural_channel)], c(72, 28))
  expect_equal(result$conservation$allocation_gap, 0)
  p$affiliate_cit_rate_unit <- c(.1, .1, NA_real_)
  p$employees_sbie <- p$payroll_sbie <- p$upr_panelai <- 0
  wider <- e$build_rule_a_global_reallocation(p)$matrix
  expect_setequal(wider$destination, c("IRL", "DEU", "NLD"))
  expect_true(all(wider$destination_weight_source == "all_positive_activity_fallback"))
  expect_equal(wider$reallocation_weight, rep(1/3, 6))
  expect_equal(wider$destination_cit_rate[wider$destination == "NLD"], rep(.15, 2))
})

test_that("parent-specific Rule A weights source rates by pooled profit and permits equal weights", {
  e <- fiscal_methods
  p <- destination_fixture() |> dplyr::filter(affiliate %in% c("IRL", "DEU", "FRA", "NLD")) |>
    dplyr::mutate(affiliate_cit_destination_gate_rate = dplyr::if_else(affiliate == "IRL",
      .1, affiliate_cit_destination_gate_rate), employees_sbie = 0, payroll_sbie = 0, upr_panelai = 0)
  p <- dplyr::bind_rows(p, dplyr::mutate(p[1, ], affiliate = "SGP", reallocated_profit = 300,
    static_tau_low = .10), dplyr::mutate(p[1, ], parent = "CAN", reallocated_profit = 20))
  a <- e$build_parent_specific_reallocation(p, host_fixture(p))
  expect_equal(a$matrix$weighted_source_etr[a$matrix$parent == "USA"], rep(.0875, 2))
  expect_equal(a$matrix$reallocated_profit_received, c(200, 200, 10, 10))
  expect_true(all(a$matrix$equal_weight_fallback))
  expect_identical(a$matrix$destination_weight_source,
    rep(c("parent_year", "global_year_no_eligible_parent_destination"), each = 2))
  expect_false(any(a$matrix$destination == "NLD"))
  expect_equal(a$conservation$allocation_gap, c(0, 0))
})

test_that("Rule C checks formulary support before assigning its conditional headquarters half", {
  e <- destination_methods
  panel <- destination_fixture() |> dplyr::filter(affiliate %in% c("IRL", "DEU", "FRA"))
  panel <- dplyr::bind_rows(panel,
    dplyr::mutate(panel[1, ], parent = "IRL"),
    dplyr::mutate(panel[1, ], parent = "CAN"))
  s1 <- dplyr::mutate(panel, parent_cit_destination_gate_rate = dplyr::case_when(
    parent == "USA" ~ .15, parent == "IRL" ~ .16, TRUE ~ NA_real_))
  routes <- e$build_hub_destination_routes(panel, s1, host_fixture(panel))
  hq <- dplyr::filter(routes, rule == "C", route == "headquarters")
  expect_identical(hq$destination, c("USA", "IRL"))
  expect_identical(hq$same_country_headquarters, c(FALSE, TRUE))
  expect_equal(hq$received, c(50, 50))
  c_formulary <- routes |> dplyr::filter(rule == "C", route != "headquarters") |>
    dplyr::summarise(amount = sum(received), .by = source_id)
  expect_equal(c_formulary$amount, c(50, 50, 100))
  closure <- routes |> dplyr::summarise(amount = sum(received), .by = c(rule, source_id))
  expect_equal(closure$amount, rep(100, 6))
  s1$etr_panelai_stage1 <- .05
  expect_error(e$build_hub_destination_routes(panel, s1, host_fixture(s1)),
    "unsupported source")
})
