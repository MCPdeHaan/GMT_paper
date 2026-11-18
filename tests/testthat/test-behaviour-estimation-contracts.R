sample_methods <- source_pipeline("behaviour/estimation_sample.R", new.env())
model_methods <- source_pipeline("behaviour/estimation_models.R", new.env())

test_that("estimation eligibility retains keys, missing-tax distinction and pair weights", {
  base <- tidyr::expand_grid(parent = c("FRA", "DEU", "USA"), year = 2017:2020) |>
    dplyr::mutate(affiliate = "IRL", pair_id = paste(parent, affiliate),
      has_behavioral_estimation_inputs = TRUE,
      analysis_profit_base = c(10, 20, 90, 0, 30, 60, 90, NA, 25, -1, 5, 10),
      assets_sbie = c(rep(20, 10), 0, 20),
      payroll_sbie = c(rep(10, 11), 0),
      affiliate_gdp_pc_usd = 100, affiliate_population = 1000,
      etr_panelai_reg = c(.1, .2, NA, NA, .3, .3, .3, .3, .4, .4, .4, .4),
      affiliate_cit_rate_unit = .2, tax_accrued_panelai = NA_real_)
  # An observed ETR governs this boundary. Accrued tax itself is not screened here.
  sample <- sample_methods$prepare_estimation_sample(base)
  expected <- c(1:2, 5:7)
  expect_identical(sample[c("parent", "affiliate", "year", "pair_id")],
    base[expected, c("parent", "affiliate", "year", "pair_id")])
  expect_equal(sample$pair_years_in_estimation_sample, c(2, 2, 3, 3, 3))
  expect_equal(sample$tau_raw, c(.1, .2, .3, .3, .3))
  expect_equal(sample$log_profit, log(c(10, 20, 30, 60, 90)))
  expect_equal(sample$log_payroll, rep(log(10), 5))
  expect_true(all(is.na(sample$affiliate_simulated_eatr_unit)))
  expect_false(anyDuplicated(sample[c("parent", "affiliate", "year")]) > 0)
  samples <- sample_methods$prepare_alternative_estimator_samples(sample, base)
  expect_identical(samples$fe_ols$data, sample)
  expect_identical(samples$fe_ppml_positive$data, sample)
  # Pair means are based on all positive observations, including missing ETR.
  expect_equal(samples$fe_wls$data$pair_mean_positive_profit, c(40, 40, 60, 60, 60))
  expect_equal(samples$fe_wls$data$pair_profit_weight, c(40, 40, 60, 60, 60) / 52)
  base$etr_panelai_reg[12] <- .4
  base$payroll_sbie[12] <- 10
  samples <- sample_methods$prepare_alternative_estimator_samples(sample, base)
  zero <- dplyr::filter(samples$fe_ppml_nonnegative$data, analysis_profit_base == 0)
  expect_identical(zero$tau_proxy_used, TRUE)
  expect_equal(zero$zero_profit_etr_proxy, .4)
  expect_equal(zero$tau, .3)
})

test_that("lagging and parent exclusion use the declared keyed donor populations", {
  base <- tidyr::expand_grid(parent = c("IRL", "DEU", "FRA", "USA"),
    affiliate = c("IRL", "GBR", "CHE"), year = 2018:2019) |>
    dplyr::mutate(pair_id = paste(parent, affiliate),
      analysis_profit_base = 10, tax_accrued_panelai = rep(c(1, 2, 3, 4), each = 6),
      etr_panelai_stage1 = ifelse(year == 2018, .2, .4),
      assets_sbie = 1, payroll_sbie = 2,
      affiliate_cit_rate_unit = .25) |>
    dplyr::filter(!(affiliate == "GBR" & parent %in% c("IRL", "USA")),
      !(affiliate == "CHE" & parent != "DEU"))
  estimation <- base |>
    dplyr::mutate(tau = .1, log_profit = log(10), log_assets = 0, log_payroll = log(2),
      log_gdp_pc = 4, log_population = 7, affiliate_simulated_eatr_unit = NA_real_)
  out <- sample_methods$build_division_bias_inputs(estimation, base)
  i <- out$affiliate == "IRL" & out$parent == "DEU" & out$year == 2019L
  expect_equal(out$leaveout_profit[i], 30)
  expect_equal(out$leaveout_tax[i], 8)
  expect_equal(out$leaveout_foreign_tax[i], 7)
  expect_equal(out$other_foreign_parents[i], 2)
  expect_equal(out$lagged_bounded[i], .2)
  expect_true(all(is.na(out$lagged_bounded[out$year == 2018L])))
  expect_true(all(is.na(out$jackknife_etr[out$affiliate %in% c("GBR", "CHE")])))
  altered <- dplyr::mutate(base, tax_accrued_panelai = ifelse(
    affiliate == "IRL" & parent == "DEU" & year == 2019L, 9, tax_accrued_panelai))
  expect_equal(sample_methods$build_division_bias_inputs(estimation, altered)$jackknife_etr[i],
    out$jackknife_etr[i])
})

estimation_fixture <- function() {
  out <- tidyr::expand_grid(parent = LETTERS[1:4], affiliate = letters[1:5], year = 2017:2023)
  i <- seq_len(nrow(out))
  dplyr::mutate(out, pair_id = paste(parent, affiliate),
    tau = .05 + (i^2 %% 89) / 500, tau_sq = tau^2,
    log_assets = sin(i * .31), log_payroll = cos(i * .26),
    log_gdp_pc = sin(i * .63), log_population = cos(i * .17),
    log_profit = 4 + as.integer(factor(pair_id)) / 10 + (year - 2017) / 5 -
      2 * tau + .3 * log_assets + sin(i * .41) / 20,
    analysis_profit_base = exp(log_profit))
}

test_that("manual FE fits, offset search and model ranks agree with explicit dummy regressions", {
  data <- estimation_fixture()
  fits <- model_methods$estimate_stage3_models(data)
  rhs <- c(linear = "tau", quadratic = "tau + tau_sq", logarithmic = "tau + log_tau")
  for (name in names(rhs)) {
    fit <- fits[[name]]
    data$log_tau <- log(if (is.na(fit$t0)) .1 + data$tau else fit$t0 + data$tau)
    independent <- stats::lm(stats::as.formula(paste(
      "log_profit ~ log_assets + log_payroll + log_gdp_pc + log_population +",
      rhs[[name]], "+ factor(pair_id) + factor(year)")), data)
    expect_equal(fit$coefficients, stats::coef(independent)[names(fit$coefficients)],
      tolerance = 1e-9)
    expect_equal(fit$n, 140L)
    expect_equal(fit$n_pairs, 20L)
    expect_identical(fit$n_parents, 4L)
    expect_identical(fit$n_affiliates, 5L)
    expect_equal(fit$coefficient_table_two_way$std_error,
      unname(sqrt(ifelse(diag(fit$vcov_two_way) >= 0, diag(fit$vcov_two_way), NA_real_))))
  }
  expect_identical(fits$logarithmic$t0, fits$log_grid$t0[which.min(fits$log_grid$bic)])
  expect_equal(model_methods$model_comparison_table(fits)$bic, unname(sort(vapply(
    fits[names(rhs)], function(fit) fit$bic, numeric(1)))))
  schedule <- model_methods$stage3_semielasticity_schedule(fits, .05)
  expect_equal(schedule$semi_elasticity[schedule$model_spec == "linear"],
    rep(-unname(fits$linear$coefficients["tau"]), 2))
})

test_that("two-way inference uses each cluster component's correction", {
  x <- matrix(c(-1, -1, 1, 1), ncol = 1)
  errors <- c(1, 2, 3, -4)
  parent <- c("DEU", "DEU", "FRA", "FRA")
  affiliate <- c("IRL", "NLD", "IRL", "NLD")
  # Score sums are (-3, -1) by parent and (2, -6) by affiliate.
  # The four intersections each have one observation, with squared scores summing to 30.
  # The two-cluster correction is 3, the four-cluster correction 2 and the bread squared 1/16.
  expect_equal(as.numeric(model_methods$cluster_vcov(x, errors, affiliate, 2)), 120 / 16)
  expect_equal(as.numeric(model_methods$cluster_vcov(x, errors, parent, 2)), 30 / 16)
  expect_equal(as.numeric(model_methods$cluster_vcov_twoway(x, errors, parent, affiliate, 2)), 90 / 16)
})

test_that("excluded instrument checks preserve the clustered squared t statistic", {
  data <- estimation_fixture()
  i <- seq_len(nrow(data))
  data$z <- cos(i * .43)
  controls <- c("log_assets", "log_payroll", "log_gdp_pc", "log_population")
  # Make the first-stage residual orthogonal to the excluded instrument and FEs.
  noise <- resid(lm(sin(i) ~ z + log_assets + log_payroll + log_gdp_pc +
    log_population + factor(pair_id) + factor(year), data))
  data$tau <- .1 + .0001 * data$z + noise / 100
  result <- model_methods$build_single_tax_iv_diagnostics(data, "z", "fixture", "fixture", "")
  first <- dplyr::filter(result, diagnostic == "fixture_first_stage_for_cbcr_etr")
  expect_equal(first$estimate, rep(.0001, 2), tolerance = 1e-10)
  expect_equal(first$weak_instrument_f, first$statistic^2)
  expect_lt(first$weak_instrument_f[first$inference == "affiliate_clustered"], 1)
  # This fixture has negative two-way estimated variance for the instrument.
  expect_true(is.na(first$std_error[first$inference == "parent_affiliate_clustered"]))
  expect_setequal(first$inference, c("affiliate_clustered", "parent_affiliate_clustered"))
  data$z <- 0
  expect_error(model_methods$fit_fe_2sls(data, "log_profit", "tau", "z", controls, "fixture"),
    "excluded instrument is collinear")
})

test_that("WLS and PPML use the declared outcome, fixed effects and weight contracts", {
  data <- estimation_fixture() |>
    dplyr::mutate(current_etr = tau, pair_profit_weight = as.integer(factor(pair_id)) / 10,
      analysis_profit_base = round(analysis_profit_base), log_profit = log(analysis_profit_base))
  result <- model_methods$fit_division_bias_design(data, "current_etr", "fixture", "current", .15)
  linear <- dplyr::filter(result, model_spec == "linear", term == "tau")
  x <- ~ log_assets + log_payroll + log_gdp_pc + log_population + tau + factor(pair_id) + factor(year)
  ols <- stats::lm(update(x, log_profit ~ .), data)
  wls <- stats::lm(update(x, log_profit ~ .), data, weights = pair_profit_weight)
  ppml <- stats::glm(update(x, analysis_profit_base ~ .), data, family = stats::poisson())
  estimates <- c(coef(ols)[["tau"]], coef(wls)[["tau"]], coef(ppml)[["tau"]])
  expect_identical(linear$estimator, c("fe_ols", "fe_wls", "fe_ppml_positive"))
  expect_equal(unname(linear$estimate), estimates, tolerance = 1e-7)
  expect_equal(linear$n, rep(140L, 3))
  expect_true(all(linear$joint_tax_wald_df2 == 3L))
  expect_true(all(linear$n_parents == 4L & linear$n_affiliates == 5L))
  expect_equal(nrow(dplyr::distinct(dplyr::filter(result, bic_winner), estimator, model_spec)), 3L)
})
