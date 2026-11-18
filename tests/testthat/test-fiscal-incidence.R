incidence_methods <- source_pipeline("behaviour/fiscal_incidence.R", new.env())

test_that("gross destination CIT and original source losses net once by country", {
  e <- incidence_methods
  source <- tibble::tibble(affiliate = c("IRL", "FRA"), year = 2023L, scenario_id = "x10011",
    reallocated_profit = c(100, 40), source_tax_loss = c(5, 4))
  destinations <- tibble::tibble(rule = "B", destination = c("DEU", "FRA", "DEU"),
    year = 2023L, scenario_id = "x10011", received = c(62.5, 37.5, 40),
    statutory_rate = c(.25, .2, .25), route = "parent_activity", same_country_headquarters = FALSE)
  first <- e$summarise_destination_incidence(destinations[1:2, ], source[1, ])
  expect_equal(sum(first$receipts$gross_cit), 23.125)
  expect_equal(sum(first$origin$source_cit_lost), 5)
  expect_equal(sum(first$receipts$gross_cit) - sum(first$origin$source_cit_lost), 18.125)
  both <- e$summarise_destination_incidence(destinations, source)
  net <- dplyr::full_join(both$receipts, both$origin, by = c("country", "scenario_id", "year")) |>
    dplyr::arrange(country) |>
    dplyr::mutate(net_cit = dplyr::coalesce(gross_cit, 0) - dplyr::coalesce(source_cit_lost, 0))
  expect_identical(net$country, c("DEU", "FRA", "IRL"))
  expect_equal(net$net_cit, c(25.625, 3.5, -5))
  expect_equal(sum(net$net_cit), 24.125)
  expect_equal(sum(both$origin$profit_sent), 140)
  expect_equal(sum(both$receipts$profit_received), 140)
})

test_that("destination prices have separate roles and same-year support", {
  e <- incidence_methods
  selected <- e$standard_statutory_rate(c(.25, NA, NA), c(.2, .19, NA))
  expect_equal(selected$rate, c(.25, .19, NA))
  panel <- tibble::tibble(affiliate = c("DEU", "FRA", "USA"), year = 2023L,
    affiliate_cit_rate_unit = c(.15, .21, .17),
    affiliate_cit_destination_gate_rate = affiliate_cit_rate_unit,
    affiliate_cit_destination_price_rate = selected$rate)
  prices <- e$destination_price_lookup(panel)
  routes <- tibble::tibble(destination = c("DEU", "FRA"), year = 2023L, received = c(62.5, 37.5))
  expect_equal(e$attach_destination_prices(routes, prices, "received")$price_rate, c(.25, .19))
  expect_equal(e$attach_destination_prices(routes, e$destination_price_lookup(panel, "historical"),
    "received")$price_rate, c(.15, .21))
  expect_error(e$attach_destination_prices(dplyr::mutate(routes, year = 2022L), prices, "received"),
    "missing for positive destination profit")
  unsupported <- dplyr::mutate(routes[1, ], destination = "USA")
  expect_error(e$attach_destination_prices(unsupported, prices, "received"),
    "missing for positive destination profit")
  expect_true(is.na(e$attach_destination_prices(unsupported, prices, "received",
    require_support = FALSE)$price_rate))
})

test_that("ordinary profit destination and legal IIR collector remain different jurisdictions", {
  e <- incidence_methods
  collector <- source_pipeline("06_stage4_5_revenue_allocation_sbs.R", new.env())
  relocated <- tibble::tibble(rule = "B", scenario_id = "x10011", destination = "DEU",
    year = 2023L, received = 100, statutory_rate = .25, route = "parent_activity",
    same_country_headquarters = FALSE)
  origin <- tibble::tibble(scenario_id = "x10011", affiliate = "IRL", year = 2023L,
    reallocated_profit = 100, source_tax_loss = 5)
  ordinary <- e$summarise_destination_incidence(relocated, origin)
  source <- dplyr::mutate(origin, parent = "CAN", qdmtt_flag = FALSE,
    parent_iir_utpr_flag = TRUE, sbs_exempt = FALSE, topup_after_behaviour = 9,
    affiliate_jurisdiction_name = "Ireland", parent_jurisdiction_name = "Canada",
    rate_scenario = "initial", factor1_etr = "distributional", factor2_substance = "aggregate_sbie",
    factor3_rates = "initial", factor4_sbs = "sbs", factor5_behaviour = "behavioural",
    x1_etr = 1L, x2_substance = 0L, x3_rates = 0L, x4_sbs = 1L, x5_behaviour = 1L)
  liability <- collector$build_source_panel(source)
  empty <- tibble::tibble(parent = character(), year = integer(), collector = character(),
    collector_name = character(), collector_is_eu27 = logical(), utpr_weight = numeric(),
    utpr_weight_source = character(), collector_utpr_explicit_flag = logical(),
    collector_utpr_ambiguous_flag = logical())
  legal <- collector$allocate_stage4_revenue(liability, list(parent_year_weights = empty,
    fallback_weights = dplyr::select(empty, -parent),
    policy = list(specification = "VERIFIED_PARENT_ONLY", eligible = "FRA")))
  expect_identical(legal$revenue_by_channel_global$country, "CAN")
  expect_equal(legal$revenue_by_channel_global$revenue, 9)
  expect_equal(liability$stage4_iir_liability, 9)
  expect_equal(liability$stage4_qdmtt_liability, 0)
  expect_identical(liability$parent, "CAN")
  expect_identical(ordinary$receipts$country, "DEU")
  expect_equal(ordinary$receipts$gross_cit, 25)
  expect_equal(ordinary$origin$source_cit_lost, 5)
})

test_that("the all-scenario incidence helper keeps the original EU27 geography", {
  e <- incidence_methods
  routes <- tibble::tibble(destination = c("DEU", "GBR"), year = 2023L, scenario_id = "x10011",
    reallocated_profit_received = c(50, 50), ordinary_cit_gross_destination_revenue = c(12.5, 12.5),
    ordinary_cit_gross_destination_revenue_effective = c(7.5, 7.5),
    ordinary_cit_net_recovery = c(10, 10), global_fallback_profit_received = c(0, 50),
    equal_weight_fallback = FALSE, effective_rate_fallback = FALSE)
  sources <- tibble::tibble(affiliate = c("GBR", "IRL"), year = 2023L, scenario_id = "x10011",
    reallocated_profit = c(50, 50), source_tax_loss = c(2.5, 2.5))
  incidence <- e$summarise_ordinary_cit_incidence(routes, sources)
  expect_identical(incidence$destination$country, "DEU")
  expect_identical(incidence$origin$country, "IRL")
  expect_equal(incidence$destination$ordinary_cit_gross_destination_revenue, 12.5)
  expect_equal(incidence$origin$ordinary_cit_source_loss, 2.5)
})
