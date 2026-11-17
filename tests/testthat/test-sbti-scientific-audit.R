sbti_audit <- source_pipeline("diagnostics/sbti_scientific_audit.R", new.env())

test_that("legal-style caps keep formula and activity assumptions explicit", {
  cap <- sbti_audit$sbti_cap
  expect_equal(cap(100, 1000, "hybrid")$cap, 10)
  expect_equal(cap(100, 1000, "payroll_only")$cap, 5.5)
  expect_equal(cap(100, 1000, "default", depreciation_ratio = 0)$cap, 5.5)
  expect_equal(cap(100, 1000, "default", depreciation_ratio = .20)$cap, 11)
  expect_equal(cap(100, 1000, "default", payroll_share = .75, depreciation_ratio = .08,
    eligible_share = .75)$cap, 4.125)
  expect_equal(cap(100, 1000, "carrying", eligible_share = .5)$cap, 5)
  expect_equal(cap(100, 1000, "carrying", eligible_share = .75)$cap, 7.5)
  expect_equal(cap(NA, 1000, "carrying")$cap, 10)
  expect_true(is.na(cap(100, 1000, "default")$cap))
  expect_true(is.na(cap(NA, 1000, "payroll_only")$cap))
  expect_equal(cap(0, 1000, "default", depreciation_ratio = .08)$cap, 4.4)
  expect_true(is.na(cap(100, NA, "hybrid")$cap))
  expect_equal(cap(100, NA, "payroll_only")$cap, 5.5)
  expect_identical(cap(100, 1000, "default", depreciation_ratio = .2)$dominant_leg, "depreciation")
  grid <- filter(sbti_audit$sbti_cap_cases(), formula == "default", payroll_share == 1)
  expect_identical(grid$depreciation_ratio, c(0, .04, .08, .12, .20))
  expect_equal(cap(100, 1000, "default", depreciation_ratio = grid$depreciation_ratio)$cap,
    c(5.5, 5.5, 5.5, 6.6, 11))
  expect_error(cap(100, 1000, "carrying", eligible_share = 1.2))
  expect_error(cap(-100, 1000, "default"))
})

test_that("aggregation comparisons retain exactly the same activity support", {
  x <- tibble::tibble(parent = c("USA", "USA", "CAN", "CAN"), affiliate = "IRL", year = 2023L,
    nace_r2 = c("A", "B", "A", "B"), payroll = c(80, 0, 20, 0),
    assets = c(0, 900, 0, 100), profit = c(60, 40, 0, NA), post_sbie_topup = c(5, 2, 0, NA))
  before <- serialize(x, NULL)
  group <- sbti_audit$sbti_activity_groups
  sectors <- group(x, "sector")
  parents <- group(x, "parent_country")
  host <- group(x, "host")
  cap <- sbti_audit$sbti_cap
  expect_equal(sum(cap(sectors$payroll, sectors$assets, "hybrid")$cap), 15.5)
  expect_equal(sum(cap(parents$payroll, parents$assets, "hybrid")$cap), 10.1)
  expect_equal(cap(host$payroll, host$assets, "hybrid")$cap, 10)
  expect_equal(sum(parents$payroll), sum(sectors$payroll))
  expect_equal(sum(parents$assets), sum(sectors$assets))
  expect_equal(sum(parents$profit, na.rm = TRUE), sum(sectors$profit))
  expect_equal(sum(parents$post_sbie_topup, na.rm = TRUE), sum(sectors$post_sbie_topup))
  expect_identical(serialize(x, NULL), before)
  expect_error(group(select(x, -parent), "parent_country"), "lacks.*keys")
  expect_error(group(bind_rows(x, x[1, ]), "sector"), "duplicate")
  y <- mutate(x, payroll = NA_real_)
  expect_true(all(is.na(group(y, "host")$payroll)))
  expect_equal(sum(cap(c(80, 0), c(0, 900), "hybrid")$cap), 13.4)
})

test_that("a carrying-value election is fixed over policy years and restricts revocation", {
  path <- sbti_audit$sbti_cap_election_path
  expect_identical(path(2026:2030, rep(TRUE, 5)), rep("carrying", 5))
  expect_identical(path(2026:2031, c(rep(TRUE, 5), FALSE)), c(rep("carrying", 5), "default"))
  expect_identical(path(2026:2030, rep(FALSE, 5)), rep("default", 5))
  expect_error(path(2026:2030, c(TRUE, FALSE, TRUE, FALSE, TRUE)), "five years")
  expect_error(path(2026:2032, c(rep(TRUE, 5), FALSE, TRUE)), "Re-election")
  expect_error(path(2021:2023, c(TRUE, TRUE, TRUE)))
  expect_error(path(c(2026, 2028), c(TRUE, FALSE)))
  expect_identical(sbti_audit$sbti_depreciation_after_revocation(c(10, 20, NA), c(TRUE, FALSE, NA)),
    c(0, 20, NA_real_))
})

test_that("covered-tax additions reduce top-up in proportion to excess income", {
  tax <- sbti_audit$sbti_tax_account
  x <- tax(100, 0, 20, 10, 10, "existing")
  expect_equal(x$excess, 80)
  expect_equal(x$topup_baseline, 12)
  expect_equal(x$covered_tax_addition, 10)
  expect_equal(x$topup_after, 4)
  expect_equal(x$topup_relief_vs_baseline, 8)
  expect_equal(tax(100, 0, 20, 5, 10)$covered_tax_addition, 5)
  expect_equal(tax(100, 0, 20, 20, 10)$covered_tax_addition, 10)
  expect_equal(tax(100, 0, 20, 0, 10)$covered_tax_addition, 0)
  expect_equal(tax(100, 0, 20, 0, NA)$covered_tax_addition, 0)
  expect_equal(tax(100, 0, 20, 10, 10, election = FALSE)$topup_after, 12)
  expect_equal(tax(100, 0, 100, 10, 10)$topup_after, 0)
  expect_equal(tax(100, 20, 0, 10, 10)$topup_relief_vs_baseline, 0)
  expect_equal(tax(100, 0, 0, 50, 50)$topup_relief_vs_baseline, 15)
  expect_equal(tax(0, 0, 0, 0, 10)$topup_after, 0)
  expect_true(is.na(tax(NA, 0, 0, 10, 10)$topup_after))
  expect_true(is.na(tax(100, NA, 0, 10, 10)$topup_after))
  expect_error(tax(100, 0, 0, -1, 10))
  overlay <- tax(100, 0, 20, 0, 10, "direct_overlay")
  expect_equal(overlay$topup_after, 2)
  expect_equal(overlay$covered_tax_addition, 0)
  expect_equal(overlay$qti_used, 0)
})

test_that("new and already-reflected incentives have independent fiscal accounts", {
  tax <- sbti_audit$sbti_tax_account
  new <- tax(100, 10, 20, 5, 10, "new")
  expect_equal(new$ordinary_cit_expenditure, 5)
  expect_equal(new$covered_taxes_before_election, 5)
  expect_equal(new$covered_taxes_after_election, 10)
  expect_equal(new$topup_relief_from_election, 4)
  expect_equal(new$topup_relief_vs_baseline, 0)
  expect_equal(new$topup_after, 4)
  partial <- tax(100, 10, 20, 5, 3, "new")
  expect_equal(partial$ordinary_cit_expenditure, 5)
  expect_equal(partial$covered_tax_addition, 3)
  expect_equal(partial$topup_after, 5.6)
  expect_equal(partial$topup_relief_vs_baseline, -1.6)
  limited <- tax(100, 1, 20, 5, 10, "new")
  expect_equal(limited$qti_used, 1)
  expect_equal(limited$ordinary_cit_expenditure, 1)
  existing <- tax(100, 5, 20, 5, 10, "existing")
  expect_equal(existing$ordinary_cit_expenditure, 0)
  expect_equal(existing$covered_taxes_before_election, 5)
  expect_equal(existing$covered_taxes_after_election, 10)
  expect_equal(existing$topup_relief_vs_baseline, 4)
})

test_that("the OECD incentive examples use tax values and preserve income reclassification", {
  value <- sbti_audit$sbti_qti_tax_value
  expect_equal(value(60 + 20, "used_credit"), 80)
  expect_equal(value(1500, "claimed_deduction", .15), 225)
  expect_equal(value(500, "exempt_income", .20), 100)
  expect_equal(value(2000, "preferential_income", .20, .15), 100)
  # OECD chapter 4 para 22 example. The annual QRTC election removes
  # 600 from income and tax, then adds 600 back within the common cap.
  initial_income <- 11000
  initial_taxes <- 1000
  ordinary_credit <- 500
  remaining_cap <- 1100 - ordinary_credit
  revised_income <- initial_income - remaining_cap
  revised_taxes <- initial_taxes + ordinary_credit - remaining_cap + remaining_cap
  expect_equal(revised_income, 10400)
  expect_equal(revised_taxes, 1500)
  expect_equal(revised_taxes / revised_income, 1500/10400)
  # Chapter 4 para 27 illustration has negative deferred tax and a later
  # carry-forward. The positive-income ordinary-credit shadow excludes it.
  expect_equal(-75 + value(1500, "claimed_deduction", .15), 150)
  expect_equal(150/1000, .15)
  expect_error(sbti_audit$sbti_tax_account(1000, -75, 0, 225, 225))
})

test_that("audit routing uses the detailed allocator and preserves residuals", {
  # The routing fixture includes QDMTT, parent IIR, non-EU and EU UTPR,
  # unsupported sources and SbS extinction. Its collection is independent.
  env <- source_pipeline("11_policy_game_and_variance_extensions.R", new.env())
  cells <- tibble::tibble(parent = c("USA", "FRA", "CAN", "USA", "CAN"),
    affiliate = c("IRL", "DEU", "DEU", "FRA", "ESP"), year = c(2023L, 2023L, 2023L, 2023L, 2022L),
    topup_after_behaviour = c(10, 20, 100, 40, 50), qdmtt_flag = c(TRUE, FALSE, FALSE, FALSE, FALSE),
    parent_iir_utpr_flag = c(FALSE, TRUE, FALSE, FALSE, FALSE), sbs_exempt = c(TRUE, FALSE, FALSE, TRUE, FALSE)) |>
    mutate(scenario_id = "x10011", rate_scenario = "initial", factor1_etr = "distributional",
      factor2_substance = "aggregate_sbie", factor3_rates = "initial", factor4_sbs = "sbs",
      factor5_behaviour = "behavioural", x1_etr = 1L, x2_substance = 0L, x3_rates = 0L,
      x4_sbs = 1L, x5_behaviour = 1L, affiliate_jurisdiction_name = affiliate,
      parent_jurisdiction_name = parent)
  source <- env$build_source_panel(cells)
  parent_weights <- tibble::tibble(parent = "CAN", year = 2023L, collector = c("DEU", "GBR"),
    collector_name = collector, collector_is_eu27 = c(TRUE, FALSE), utpr_weight = c(.3, .7),
    utpr_weight_source = "parent_year", collector_utpr_explicit_flag = TRUE,
    collector_utpr_ambiguous_flag = FALSE)
  weights <- list(parent_year_weights = parent_weights,
    fallback_weights = select(parent_weights[0, ], -parent),
    policy = list(specification = "VERIFIED_PARENT_ONLY", eligible = c("DEU", "GBR")))
  before <- env$nash_channels(source, weights)
  original <- serialize(source, NULL)
  source$topup_after_behaviour <- source$topup_after_behaviour * .5
  after_source <- env$build_source_panel(source)
  after <- env$nash_channels(after_source, weights)
  delta <- sbti_audit$sbti_collector_pairs(before$channels, after$channels)
  expect_equal(sum(delta$receipts_foregone), sum(before$channels$revenue) / 2)
  expect_equal(after$max_gap, 0)
  expect_equal(after_source$stage4_sbs_extinguished_liability, source$stage4_sbs_extinguished_liability / 2)
  expect_true(any(delta$channel == "QDMTT"))
  expect_true(any(delta$channel == "IIR"))
  expect_true(any(delta$channel == "UTPR"))
  expect_identical(serialize(env$build_source_panel(cells), NULL), original)
})

test_that("audit boundaries preserve caller state and reject production output", {
  withr::local_dir(withr::local_tempdir())
  withr::local_envvar(GMT_PROJECT_ROOT = repo_root)
  withr::local_seed(29)
  before <- list(rng = .Random.seed, packages = search(), namespaces = sort(loadedNamespaces()),
    options = options(), files = list.files(all.files = TRUE, no.. = TRUE))
  sys.source(repo_path("code", "diagnostics", "sbti_scientific_audit.R"), envir = new.env())
  expect_identical(.Random.seed, before$rng)
  expect_identical(search(), before$packages)
  expect_identical(sort(loadedNamespaces()), before$namespaces)
  expect_identical(options(), before$options)
  expect_identical(list.files(all.files = TRUE, no.. = TRUE), before$files)
  for (path in c("data/processed/new-audit", "writing/generated/new-audit", ".git/new-audit")) {
    expect_error(sbti_audit$sbti_audit_output_path(repo_root, repo_path(path), repo_root), "protected")
  }
  expect_error(sbti_audit$sbti_audit_output_path(repo_root, repo_path("docs"), repo_root), "fresh")
})

test_that("empirical crossed cap summaries preserve component caps and the frozen reference", {
  x <- sbti_audit$sbti_matched_capacity(readRDS(processed_path("stage2_sectoral_panel.rds")),
    readRDS(processed_path("stage2_bilateral_panel.rds")), readRDS(processed_path("stage1_affiliate_year.rds")))
  expect_true(all(x$direct_overlay_ceiling_on_known_topup <= x$cap + .01))
  expect_true(all(x$known_profit_cap <= x$cap + .01))
  legacy <- filter(x, zero_profit == "retain", case == "hybrid", grain == "sector")
  expect_equal(sum(legacy$cap)/1e9, 104.493893877846, tolerance = 1e-10)
  expect_equal(sum(legacy$n_groups), 2894)
  expect_equal(nrow(x), 5346)
})
