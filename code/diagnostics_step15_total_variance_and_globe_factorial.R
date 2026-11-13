# Run from the repository root after Stages 1–4.6 and the Step 12 diagnostic.
# This script reads the production inputs and writes two diagnostic CSVs.
source("code/diagnostics_step12_hanlon_globe_bridge.R", local = TRUE)

STEP15_SEED <- 20261113L
STEP15_DRAWS <- 500L
STEP15_KEYS <- c("parent", "affiliate", "year")
STEP15_WINDOWS <- BRIDGE_WINDOWS[c("2017–2023", "2019–2023", "2021–2023")]
STEP15_SCOPES <- c(EU27_ISO3, "EU27")
STEP15_PREFERRED <- "x10011"

step15_host_rate <- function(tax, profit, cap) {
  rate <- pmin(cap, pmax(0, safe_divide(tax, profit)))
  list(share = coalesce_zero(as.numeric(rate < GMT_RATE)),
       gap = coalesce_zero(pmax(0, GMT_RATE - rate)))
}

# Build a linear routing operator once for each legal regime. Every dollar
# has one QDMTT/IIR collector, a normalized UTPR split, or SbS extinction.
step15_route <- function(rows, weights) {
  routed <- allocation_regime(rep(1, nrow(rows)), rows$qdmtt_flag,
                               rows$parent_iir_utpr_flag, rows$sbs_exempt)
  direct <- bind_rows(
    tibble(cell = which(routed == "qdmtt"), country = rows$affiliate[routed == "qdmtt"], share = 1),
    tibble(cell = which(routed == "iir"), country = rows$parent[routed == "iir"], share = 1)
  )
  utpr <- rows |> mutate(cell = row_number(), regime = routed) |>
    filter(regime == "utpr") |> select(cell, parent, year)
  w <- weights$parent_year_weights |> select(parent, year, collector, utpr_weight)
  f <- weights$fallback_weights |> select(year, collector, utpr_weight)
  covered <- distinct(w, parent, year)
  distributed <- bind_rows(
    semi_join(utpr, covered, by = c("parent", "year")) |>
      inner_join(w, by = c("parent", "year"), relationship = "many-to-many"),
    anti_join(utpr, covered, by = c("parent", "year")) |>
      inner_join(f, by = "year", relationship = "many-to-many")
  ) |> transmute(cell, country = collector, share = utpr_weight)
  all <- bind_rows(direct, distributed)
  totals <- numeric(nrow(rows))
  routing_totals <- rowsum(all$share, all$cell)
  totals[as.integer(rownames(routing_totals))] <- routing_totals[, 1L]
  stopifnot(all(is.finite(all$share)), all(all$share >= 0),
            max(abs(totals + (routed == "sbs_extinguished") - 1)) < 1e-12)
  collectors <- expand_grid(country = EU27_ISO3, year = MAIN_YEARS)
  eu <- all |> filter(country %in% EU27_ISO3) |> mutate(year = rows$year[cell]) |>
    left_join(mutate(collectors, collector_id = row_number()), by = c("country", "year"),
              relationship = "many-to-one")
  operator <- Matrix::sparseMatrix(i = eu$collector_id, j = eu$cell, x = eu$share,
                                  dims = c(nrow(collectors), nrow(rows)))
  list(operator = operator, foreign_collection_weight = totals - Matrix::colSums(operator),
       extinguished = routed == "sbs_extinguished", exposed = !(rows$sbs_exempt & !rows$qdmtt_flag))
}

step15_inputs <- function() {
  cells <- bridge_read("stage1_bilateral_panel") |> arrange(parent, affiliate, year)
  host <- bridge_read("stage1_affiliate_year") |> arrange(affiliate, year) |>
    mutate(host_id = row_number())
  cells <- left_join(cells, select(host, affiliate, year, host_id),
                     by = c("affiliate", "year"), relationship = "many-to-one")
  stopifnot(!anyNA(cells$host_id), all(tabulate(cells$host_id, nrow(host)) > 0))
  host_sum <- function(value) unname(rowsum(value, cells$host_id, reorder = TRUE)[, 1])
  average_support <- !is.na(cells$profit_panelai) & cells$profit_panelai > 0
  stopifnot(isTRUE(all.equal(host_sum(cells$analysis_profit_positive * average_support),
                             host$avg_profit_denominator, tolerance = 1e-12)))
  weights <- list(parent_year_weights = bridge_read("stage4_5_utpr_parent_year_weights"),
                  fallback_weights = bridge_read("stage4_5_utpr_fallback_weights"))
  source <- bridge_read("stage4_5_allocation_source_panel") |>
    filter(scenario_id %in% c("x00000", "x00010")) |>
    select(scenario_id, all_of(STEP15_KEYS), qdmtt_flag, parent_iir_utpr_flag, sbs_exempt)
  routes <- lapply(c("x00000", "x00010"), function(scenario) {
    flags <- filter(source, scenario_id == scenario) |> select(-scenario_id)
    rows <- left_join(select(cells, all_of(STEP15_KEYS)), flags,
                      by = STEP15_KEYS, relationship = "one-to-one")
    stopifnot(!anyNA(rows))
    step15_route(rows, weights)
  })
  predictions <- bridge_read("profit_correction_parent_year") |>
    filter(year %in% MAIN_YEARS) |> arrange(parent, year) |> mutate(rho_id = row_number())
  draw_cells <- cells |> mutate(cell = row_number()) |>
    filter(parent == affiliate, is.na(profit_adj_panelai), profit_panelai > 0,
           analysis_profit_positive > 0) |>
    left_join(select(predictions, parent, year, rho_id), by = c("parent", "year"),
              relationship = "many-to-one")
  stopifnot(!anyNA(draw_cells$rho_id),
    max(abs(draw_cells$analysis_profit_positive - draw_cells$profit_panelai *
          (1 - inverse_bounded_logit(predictions$posterior_y[draw_cells$rho_id])))) < 1e-3)
  coef <- bridge_read("stage3_model_coefficients") |>
    filter(model_spec == "linear", term == "tau", inference == "parent_affiliate_clustered")
  stopifnot(nrow(coef) == 1L, coef$std_error > 0)
  residuals <- read_csv(file.path(DIAGNOSTICS_DIR, "step3_stage1_crossval_affiliate_year.csv"),
                        show_col_types = FALSE) |>
    filter(is.finite(low_share_diff), is.finite(topup_rate_diff)) |>
    arrange(affiliate, year)
  # Resample the two residual coordinates jointly, centred for a variance
  # exercise as in Step 09. Validation CSV defines error as fit minus direct.
  residuals <- -as.matrix(residuals[c("low_share_diff", "topup_rate_diff")])
  residual_mean <- colMeans(residuals)
  residuals <- sweep(residuals, 2L, residual_mean)
  residual_hosts <- which(host$stage1_positive_profit_flag %in% TRUE &
    host$stage1_distributional_source %in% c("percentile_fit", "shape_transport", "avg_only"))
  sector <- bridge_read("stage2_sectoral_panel") |>
    inner_join(select(host, affiliate, year, host_id), by = c("affiliate", "year"),
               relationship = "many-to-one") |>
    filter(is.finite(sectoral_profit_share_used), sectoral_profit_share_used > 0,
           is.finite(sectoral_sbie), is.finite(sectoral_payroll), is.finite(sectoral_assets))
  sectors <- lapply(STAGE2_ENDPOINTS$rate_scenario, function(rate) {
    s <- filter(sector, rate_scenario == rate) |> arrange(host_id, nace_r2)
    ids <- unique(s$host_id)
    ref <- match(host$affiliate, host$affiliate[ids[host$year[ids] == SECTORAL_REFERENCE_YEAR]])
    reference_ids <- ids[host$year[ids] == SECTORAL_REFERENCE_YEAR]
    list(host = s$host_id, ids = ids, profit_share = s$sectoral_profit_share_used,
         profit_share_sum = as.numeric(rowsum(s$sectoral_profit_share_used, s$host_id)),
         sbie = s$sectoral_sbie, incentive = pmax(.055 * s$sectoral_payroll, .01 * s$sectoral_assets),
         reference = reference_ids[ref])
  })
  collector_year <- expand_grid(country = EU27_ISO3, year = MAIN_YEARS)
  windows <- lapply(STEP15_WINDOWS, function(years) {
    lapply(STEP15_SCOPES, function(c) which(collector_year$year %in% years &
                                            (collector_year$country == c | c == "EU27")))
  })
  list(cells = cells, host = host, host_sum = host_sum, routes = routes, predictions = predictions,
       draw_cells = draw_cells, beta = coef$estimate, beta_se = coef$std_error,
       residuals = residuals, residual_hosts = residual_hosts, average_support = average_support,
       sector = sectors, collector_year = collector_year, windows = windows,
       profit = cells$analysis_profit_positive, sbie = vapply(seq_len(nrow(STAGE2_ENDPOINTS)),
         function(i) compute_sbie_value(cells$payroll_sbie, cells$assets_sbie,
           STAGE2_ENDPOINTS$sigma_w[i], STAGE2_ENDPOINTS$sigma_a[i]), numeric(nrow(cells))))
}

step15_measure <- function(input, rho = NULL, error = NULL) {
  h <- input$host
  profit <- input$profit
  if (!is.null(rho)) {
    d <- input$draw_cells
    profit[d$cell] <- d$profit_panelai * (1 - rho[d$rho_id])
  }
  host_profit <- input$host_sum(profit * input$average_support)
  average <- step15_host_rate(h$avg_tax_numerator, host_profit, h$affiliate_etr_cap_stage1)
  share <- coalesce_zero(h$stage1_distributional_low_share)
  gap <- coalesce_zero(h$stage1_distributional_topup_rate)
  fallback <- which(h$stage1_distributional_source %in% "avg_only")
  share[fallback] <- average$share[fallback]
  gap[fallback] <- average$gap[fallback]
  if (!is.null(error)) {
    idx <- input$residual_hosts
    share[idx] <- clamp_unit_interval(share[idx] + input$residuals[error, 1L])
    gap[idx] <- clamp_interval(gap[idx] + input$residuals[error, 2L], 0, GMT_RATE)
  }
  list(profit = profit, average = average, distributional = list(share = share, gap = gap))
}

# Recompute the two sectoral scales against the drawn host profit and gap.
# The NACE allocation weights and sector payroll/assets are the production inputs.
step15_sector_scale <- function(input, endpoint, aggregate_tax, host_profit, share, gap) {
  s <- input$sector[[endpoint]]
  sector_profit <- host_profit[s$host] * s$profit_share
  available <- sector_profit > 0
  net_gap <- numeric(length(s$host))
  net_gap[available] <- pmax(0,
    gap[s$host[available]] * (1 - clamp_unit_interval(s$sbie[available] / sector_profit[available])) -
      s$incentive[available] / sector_profit[available])
  weighted_gap <- rowsum(net_gap * s$profit_share, s$host, reorder = FALSE)[, 1L] /
    s$profit_share_sum
  scale <- rep(NA_real_, nrow(input$host))
  scale[s$ids] <- safe_divide(share[s$ids] * weighted_gap * host_profit[s$ids], aggregate_tax[s$ids])
  scale[host_profit <= 0] <- NA_real_
  coalesce(scale, scale[s$reference], 1)
}

step15_design <- function(accounting = FALSE) {
  factors <- c(FACTOR_COLS, if (accounting) "x6_accounting")
  design <- expand_grid(!!!set_names(rep(list(0:1), length(factors)), factors))
  design$scenario_id <- paste0("x", apply(design[factors], 1L, paste0, collapse = ""))
  design
}

# Compute a complete 32-scenario waterfall for one parameter draw. The ETR,
# substance and transition switches change the source amount; legal allocation
# is linear conditional on each regime and its fixed UTPR weights.
step15_evaluate <- function(input, measure, beta = input$beta, check = FALSE) {
  id <- input$cells$host_id
  profit <- measure$profit
  host_profit <- input$host_sum(profit)
  amounts <- lapply(c("average", "distributional"), function(name) {
    m <- measure[[name]]
    bilateral <- isTRUE(m$bilateral)
    share <- if (bilateral) m$share else m$share[id]
    gap <- if (bilateral) m$gap else m$gap[id]
    if (bilateral) {
      low <- input$host_sum(profit * share)
      host_share <- coalesce_zero(safe_divide(low, host_profit))
      host_gap <- coalesce_zero(safe_divide(input$host_sum(profit * share * gap), low))
    } else {
      host_share <- m$share
      host_gap <- m$gap
    }
    tau <- ifelse(share > 0 & gap > 0, GMT_RATE - gap, NA_real_)
    behaviour <- apply_behavioural_regime(tau,
      coalesce_zero(1 - clamp_unit_interval(exp(beta * (GMT_RATE - tau)))))
    lapply(seq_len(ncol(input$sbie)), function(endpoint) {
      excess <- profit - pmin(pmax(input$sbie[, endpoint], 0), profit)
      topup <- excess * share * gap
      scale <- step15_sector_scale(input, endpoint, input$host_sum(topup),
                                   host_profit, host_share, host_gap)
      list(aggregate = topup, sectoral = topup * scale[id],
           bunch = behaviour$behavioural_regime == "sesh_bunching_topup_zero",
           beta_applied = pmin(behaviour$beta_applied, BEHAVIOURAL_MAX_REALLOCATION_SHARE))
    })
  })
  design <- step15_design()
  y <- matrix(0, nrow(input$collector_year), nrow(design), dimnames = list(NULL, design$scenario_id))
  max_gap <- 0
  for (law in 0:1) {
    cols <- which(design$x4_sbs == law)
    route <- input$routes[[law + 1L]]
    source <- vapply(cols, function(i) {
      d <- design[i, ]
      a <- amounts[[d$x1_etr + 1L]][[d$x3_rates + 1L]]
      amount <- if (d$x2_substance == 0L) a$aggregate else a$sectoral
      if (d$x5_behaviour == 0L) return(amount)
      amount * ifelse(a$bunch, 0, 1 - a$beta_applied * route$exposed)
    }, numeric(length(profit)))
    y[, cols] <- as.matrix(route$operator %*% source)
    if (check) {
      outside <- route$foreign_collection_weight + route$extinguished
      for (year in MAIN_YEARS) {
        cells <- input$cells$year == year
        collectors <- input$collector_year$year == year
        collected <- colSums(y[collectors, cols, drop = FALSE])
        accounted_outside_eu <- apply(source[cells, , drop = FALSE] * outside[cells], 2L, sum)
        liability <- apply(source[cells, , drop = FALSE], 2L, sum)
        gaps <- abs(collected + accounted_outside_eu - liability)
        # Allow roundoff from sparse summation at trillion-dollar scale.
        stopifnot(all(gaps <= 1e-3 + 64 * .Machine$double.eps * liability))
        max_gap <- max(max_gap, gaps)
      }
    }
  }
  list(revenue = y / 1e9, max_global_conservation_gap = max_gap)
}

step15_cumulative <- function(revenue, input, windows = seq_along(input$windows)) {
  vapply(unlist(input$windows[windows], recursive = FALSE), function(i) {
    colSums(revenue[i, , drop = FALSE])
  }, numeric(ncol(revenue)))
}

step15_check_production <- function(input, y) {
  production <- bridge_read("stage4_5_revenue_country_year") |>
    select(country, year, scenario_id, revenue) |>
    pivot_wider(names_from = scenario_id, values_from = revenue)
  production <- left_join(input$collector_year, production, by = c("country", "year"),
                          relationship = "one-to-one")
  difference_usd <- max(abs(y * 1e9 - as.matrix(production[colnames(y)])))
  stopifnot(difference_usd < 1e-3)
  difference_usd
}

step15_population_variance <- function(x) mean((x - mean(x))^2)

step15_monte_carlo <- function(input, point) {
  set.seed(STEP15_SEED)
  sample_inputs <- function() {
    list(
      error = matrix(sample.int(nrow(input$residuals), length(input$residual_hosts) *
        STEP15_DRAWS, replace = TRUE), nrow = length(input$residual_hosts)),
      beta = rnorm(STEP15_DRAWS, input$beta, input$beta_se),
      rho = matrix(inverse_bounded_logit(rnorm(nrow(input$predictions) * STEP15_DRAWS,
        input$predictions$posterior_y, input$predictions$posterior_sd)), nrow = nrow(input$predictions))
    )
  }
  independent <- list(sample_inputs(), sample_inputs())
  masks <- as.matrix(expand_grid(etr = 0:1, beta = 0:1, rho = 0:1))
  starts <- 1:2
  window_names <- names(STEP15_WINDOWS)[starts]
  point_totals <- step15_cumulative(point, input, starts)
  n_scenarios <- nrow(point_totals)
  n_outcomes <- ncol(point_totals)
  # Two independent input samples support pick-freeze estimates. Each hybrid
  # shares the inputs indicated by its mask with the 111 run.
  hybrid <- array(0, c(STEP15_DRAWS, n_scenarios, n_outcomes, nrow(masks)))
  fixed <- array(0, c(STEP15_DRAWS, n_scenarios, n_outcomes, 3L))
  largest_gap <- 0
  evaluate <- function(error, beta, rho) {
    result <- step15_evaluate(input, step15_measure(input, rho, error), beta, check = TRUE)
    largest_gap <<- max(largest_gap, result$max_global_conservation_gap)
    step15_cumulative(result$revenue, input, starts)
  }
  for (m in seq_len(STEP15_DRAWS)) {
    for (k in seq_len(nrow(masks))) {
      draws <- independent[2L - masks[k, ]]
      hybrid[m, , , k] <- evaluate(draws[[1]]$error[, m], draws[[2]]$beta[m],
                                     draws[[3]]$rho[, m])
    }
    a <- independent[[1L]]
    fixed[m, , , 1L] <- evaluate(a$error[, m], input$beta, NULL)
    fixed[m, , , 2L] <- evaluate(NULL, a$beta[m], NULL)
    fixed[m, , , 3L] <- evaluate(NULL, input$beta, a$rho[, m])
    if (m %% 100L == 0L) message("  Completed ", m, " of ", STEP15_DRAWS, " joint draws")
  }
  bit_names <- c("etr", "beta", "rho")
  subsets <- lapply(seq_len(nrow(masks)), function(k) which(masks[k, ] == 1))
  components <- vapply(subsets, function(s) paste(bit_names[s], collapse = "_"), character(1))
  # Each draw evaluates the full 2×2×2 cube of two independent levels per
  # input. For a subset S, difference along every axis in S, then multiply
  # the differences at complementary corners of the remaining axes. Those
  # corners integrate out the remaining inputs independently. The expected
  # product divided by 2^|S| is the pure functional ANOVA variance of S.
  contrasts <- lapply(subsets[-1], function(s) {
    other <- setdiff(seq_len(ncol(masks)), s)
    if (!length(other)) return(list(list(a = seq_len(nrow(masks)), b = seq_len(nrow(masks)),
      signs = (-1)^rowSums(masks[, s, drop = FALSE]), divisor = 2^length(s))))
    settings <- unique(masks[, other, drop = FALSE])
    lapply(seq_len(nrow(settings) / 2L), function(j) {
      selected <- settings[j, ]
      a <- which(rowSums(abs(sweep(masks[, other, drop = FALSE], 2L, selected))) == 0)
      b <- which(rowSums(abs(sweep(masks[, other, drop = FALSE], 2L, 1 - selected))) == 0)
      list(a = a, b = b, signs = (-1)^rowSums(masks[a, s, drop = FALSE]),
           divisor = 2^length(s))
    })
  })
  describe <- function(i) {
    y <- hybrid[, , i, 8L]
    scenario_means <- colMeans(y)
    scenario_vars <- apply(y, 2L, step15_population_variance)
    epistemic <- step15_population_variance(scenario_means)
    parameter <- mean(scenario_vars)
    total <- epistemic + parameter
    stopifnot(abs(total - step15_population_variance(y)) < 1e-9 * max(1, total))
    oaat <- colMeans(apply(fixed[, , i, ], c(2, 3), step15_population_variance))
    corner_y <- matrix(hybrid[, , i, ], ncol = nrow(masks))
    raw_components <- vapply(contrasts, function(pairs) mean(vapply(pairs, function(p) {
      a <- corner_y[, p$a, drop = FALSE] %*% p$signs
      b <- corner_y[, p$b, drop = FALSE] %*% p$signs
      mean(a * b) / p$divisor
    }, numeric(1))), numeric(1))
    # Use the cube to estimate the shares and the primary joint sample to
    # estimate the total variance. Retain the unscaled estimates for audit.
    sobol <- c(0, if (parameter == 0) rep(0, 7L) else {
      stopifnot(sum(raw_components) > 0)
      raw_components * parameter / sum(raw_components)
    })
    shapley <- vapply(seq_along(bit_names), function(f) sum(vapply(2:8, function(k) {
      if (f %in% subsets[[k]]) sobol[k] / length(subsets[[k]]) else 0
    }, numeric(1))), numeric(1))
    stopifnot(abs(sum(shapley) - parameter) < 1e-10 * max(1, parameter))
    country <- STEP15_SCOPES[(i - 1L) %% length(STEP15_SCOPES) + 1L]
    window <- window_names[(i - 1L) %/% length(STEP15_SCOPES) + 1L]
    years <- STEP15_WINDOWS[[window]]
    bounds <- apply(y, 2L, quantile, probs = c(.05, .95), names = FALSE)
    preferred <- match(STEP15_PREFERRED, rownames(point_totals))
    width <- diff(bounds[, preferred])
    spread <- diff(range(point_totals[, i]))
    measures <- tibble(
      scope = country, window = window, seed = STEP15_SEED, n_joint_draws = STEP15_DRAWS,
      n_scenarios = n_scenarios, validation_cells = nrow(input$residuals),
      perturbed_host_years = sum(input$host$year[input$residual_hosts] %in% years),
      posterior_bilateral_cells = sum(input$draw_cells$year %in% years),
      beta_estimate = input$beta, beta_clustered_se = input$beta_se,
      max_global_conservation_gap_usd = largest_gap
    )
    bind_rows(
      mutate(measures, record = "total_variance",
        total_variance_usd_bn_sq = total, scenario_variance_usd_bn_sq = epistemic,
        parameter_variance_usd_bn_sq = parameter,
        scenario_variance_share = safe_divide(epistemic, total),
        parameter_variance_share = safe_divide(parameter, total),
        point_scenario_spread_usd_bn = spread,
        mean_scenario_spread_usd_bn = diff(range(scenario_means)),
        preferred_scenario = STEP15_PREFERRED, preferred_point_usd_bn = point_totals[preferred, i],
        preferred_p05_usd_bn = bounds[1, preferred], preferred_p95_usd_bn = bounds[2, preferred],
        preferred_width90_usd_bn = width, proposal_ratio = safe_divide(spread, width)),
      bind_cols(measures, tibble(record = "one_at_a_time", component = bit_names,
        component_variance_usd_bn_sq = oaat,
        component_share_of_total_variance = safe_divide(oaat, total),
        component_share_of_parameter_variance = safe_divide(oaat, parameter))),
      bind_cols(measures, tibble(record = "orthogonal_parameter", component = components[-1],
        unscaled_component_variance_usd_bn_sq = raw_components,
        component_variance_usd_bn_sq = sobol[-1],
        component_share_of_total_variance = safe_divide(sobol[-1], total),
        component_share_of_parameter_variance = safe_divide(sobol[-1], parameter))),
      bind_cols(measures, tibble(record = "parameter_shapley", component = bit_names,
        component_variance_usd_bn_sq = shapley,
        component_share_of_total_variance = safe_divide(shapley, total),
        component_share_of_parameter_variance = safe_divide(shapley, parameter))),
      bind_cols(measures, tibble(record = "scenario_distribution", scenario_id = rownames(point_totals),
        point_revenue_usd_bn = point_totals[, i], mean_revenue_usd_bn = scenario_means,
        parameter_variance_usd_bn_sq = scenario_vars,
        parameter_p05_usd_bn = bounds[1, ], parameter_p95_usd_bn = bounds[2, ]))
    )
  }
  map_dfr(seq_len(n_outcomes), describe)
}

step15_globe_base <- function(input) {
  cells <- input$cells
  base <- bridge_read("base_panel")
  raw <- bridge_read("cbcr_table1")
  t4 <- bridge_read("cbcr_table4")
  # Match Step 12 through the last accrued-tax step. Panel A is net of
  # negative subgroup profit, which Panel A-II alone reports separately.
  pooled <- step8_reconcile_rates(cells, base, input$host, step8_table4_partitions(t4),
                                  gamma = 1, method = "reporter_pool")$cells
  loss <- bridge_table1_loss(base, raw) |>
    left_join(select(pooled, all_of(STEP15_KEYS), revised_profit), by = STEP15_KEYS,
              relationship = "one-to-one") |>
    mutate(current = coalesce(revised_profit, corrected_profit) * (1 - coalesce_zero(loss_ratio))) |>
    group_by(parent, affiliate) |>
    mutate(bridge_loss_stock(net_profit, current)) |>
    ungroup() |>
    mutate(accounting_profit = current - cf_used)
  accounting <- cells |>
    select(all_of(STEP15_KEYS), profit_correction_rate_preferred, affiliate_is_conduit_haven,
      profit_adj_panelai, holding_share_panelai, ladder_l4_strict_source,
      ladder_l4_strict_low_share, ladder_l4_strict_topup_rate) |>
    left_join(select(loss, all_of(STEP15_KEYS), accounting_profit), by = STEP15_KEYS,
              relationship = "one-to-one") |>
    left_join(select(pooled, all_of(STEP15_KEYS), revised_share, revised_gap), by = STEP15_KEYS,
              relationship = "one-to-one")
  # The strict ladder uses its own exact Table IV partitions for the purge.
  # Keep the common Step 12 accounting denominator across the ETR switches.
  bilateral_t4 <- summarise_observed_t4(bridge_read("base_panel_t4_bilateral_bracket_shares"),
                                        STEP15_KEYS) |>
    filter(t4_available) |>
    select(all_of(STEP15_KEYS), t4_positive_profit, t4_low_profit, t4_low_tax)
  accounting <- accounting |>
    left_join(bilateral_t4, by = STEP15_KEYS, relationship = "one-to-one") |>
    mutate(
      exact = ladder_l4_strict_source == "exact_table_iv",
      domestic_rate = if_else(parent == affiliate, coalesce_zero(
        clamp_unit_interval(profit_correction_rate_preferred)), 0),
      foreign_rate = if_else(parent != affiliate & is.na(profit_adj_panelai) &
        (affiliate_is_conduit_haven | affiliate %in% c("CYP", "MLT")),
        coalesce_zero(clamp_unit_interval(holding_share_panelai)), 0)
    )
  exact <- which(accounting$exact)
  stopifnot(all(is.finite(accounting$t4_positive_profit[exact])),
            all(is.finite(accounting$accounting_profit)), all(accounting$accounting_profit >= 0))
  partition <- step8_remove_low_profit(accounting$t4_positive_profit[exact],
    accounting$t4_low_profit[exact], coalesce_zero(accounting$t4_low_tax[exact]),
    (accounting$domestic_rate[exact] + accounting$foreign_rate[exact]) *
      accounting$t4_positive_profit[exact])
  strict_share <- coalesce_zero(accounting$ladder_l4_strict_low_share)
  strict_gap <- coalesce_zero(accounting$ladder_l4_strict_topup_rate)
  strict_share[exact] <- partition$share
  strict_gap[exact] <- partition$gap

  host_profit <- input$host_sum(accounting$accounting_profit)
  # L1 uses the same accrued tax numerator as production, with the new
  # accounting denominator. L3 follows the Step 12 host-weighted low gap.
  average <- step15_host_rate(input$host$avg_tax_numerator,
                             input$host_sum(accounting$accounting_profit * input$average_support),
                             input$host$affiliate_etr_cap_stage1)
  low <- input$host_sum(accounting$accounting_profit * coalesce_zero(accounting$revised_share))
  topup <- input$host_sum(accounting$accounting_profit * coalesce_zero(accounting$revised_share) *
                           coalesce_zero(accounting$revised_gap))
  list(
    profit = accounting$accounting_profit, average = average,
    L3 = list(share = coalesce_zero(safe_divide(low, host_profit)),
              gap = coalesce_zero(safe_divide(topup, low))),
    L4_strict = list(share = strict_share, gap = strict_gap, bilateral = TRUE)
  )
}

step15_factorial_effects <- function(y, design, factors, scope, window, estimand) {
  # Orthogonal ±1 contrasts. Squaring before pooling gives the thesis
  # country-year SS estimand. Summing revenue first gives variance of the
  # cumulative collector outcome used in Task 1.
  coded <- mutate(design, across(all_of(factors), ~ 2 * .x - 1))
  x <- model.matrix(reformulate(paste(factors, collapse = "*")), data = coded)
  n <- nrow(design)
  stopifnot(nrow(y) == n, all(crossprod(x) == n * diag(n)))
  coef <- crossprod(x, y) / n
  effects <- strsplit(rownames(coef)[-1], ":", fixed = TRUE)
  order <- lengths(effects)
  ss <- n * rowSums(coef[-1, , drop = FALSE]^2)
  total_ss <- sum(sweep(y, 2L, colMeans(y))^2)
  stopifnot(abs(sum(ss) - total_ss) < 1e-10 * max(1, total_ss))
  eta <- if (total_ss > 0) ss / total_ss else rep(NA_real_, length(ss))
  shapley <- vapply(factors, function(factor) {
    keep <- vapply(effects, function(e) factor %in% e, logical(1))
    sum(eta[keep] / order[keep])
  }, numeric(1))
  if (total_ss > 0) stopifnot(abs(sum(shapley) - 1) < 1e-12)
  revenue <- rowSums(y)
  preferred <- which(design$scenario_id == paste0(STEP15_PREFERRED, "0"))
  adjusted <- which(design$scenario_id == paste0(STEP15_PREFERRED, "1"))
  stats <- tibble(scope, window, estimand, scenarios = n,
    factorial_variance_usd_bn_sq = total_ss / n,
    min_revenue_usd_bn = min(revenue), max_revenue_usd_bn = max(revenue),
    interaction_eta_squared = sum(eta[order > 1L]),
    preferred_baseline_usd_bn = revenue[preferred], preferred_globe_usd_bn = revenue[adjusted],
    preferred_globe_change_usd_bn = revenue[adjusted] - revenue[preferred])
  bind_rows(
    bind_cols(stats, tibble(record = "main_effect", effect = factors,
      main_eta_squared = eta[match(factors, rownames(coef)[-1])],
      shapley_eta_squared = unname(shapley),
      dollar_main_effect_usd_bn = 2 * rowSums(coef[factors, , drop = FALSE]))),
    bind_cols(stats, tibble(record = "interaction", effect = rownames(coef)[-1][order > 1L],
      interaction_term_eta_squared = eta[order > 1L]))
  )
}

step15_factorial <- function(input, baseline, point) {
  globe <- step15_globe_base(input)
  ladders <- c("L3", "L4_strict")
  design <- step15_design(TRUE)
  by_ladder <- lapply(ladders, function(level) {
    untreated <- if (level == "L3") point else {
      m <- baseline
      m$distributional <- list(share = coalesce_zero(input$cells$ladder_l4_strict_low_share),
        gap = coalesce_zero(input$cells$ladder_l4_strict_topup_rate), bilateral = TRUE)
      step15_evaluate(input, m, check = TRUE)$revenue
    }
    m <- list(profit = globe$profit, average = globe$average, distributional = globe[[level]])
    treated <- step15_evaluate(input, m, check = TRUE)$revenue
    y <- untreated[, rep(seq_len(ncol(untreated)), each = 2L)]
    y[, design$x6_accounting == 1L] <- treated
    colnames(y) <- design$scenario_id
    y
  })
  reference <- read_csv(file.path(DIAGNOSTICS_DIR, "step12_cbcr_to_budget_waterfall_bridge.csv"),
                        show_col_types = FALSE) |>
    filter(record_type == "waterfall", step == "03_prior_loss_carryforward",
           scope %in% STEP15_SCOPES, window %in% names(STEP15_WINDOWS)) |>
    arrange(match(window, names(STEP15_WINDOWS)), match(scope, STEP15_SCOPES))
  expected <- step15_cumulative(by_ladder[[1L]], input)[paste0(STEP15_PREFERRED, "1"), ]
  stopifnot(nrow(reference) == length(expected),
            max(abs(reference$collector - expected * 1e9)) < 1e-3)
  map_dfr(seq_along(ladders), function(i) {
    imap_dfr(list(full_64 = seq_len(nrow(design)), initial_rates_32 = which(design$x3_rates == 0)),
      function(scenarios, name) {
        d <- design[scenarios, ]
        factors <- setdiff(setdiff(names(d), "scenario_id"),
                           if (name == "initial_rates_32") "x3_rates")
        y <- t(by_ladder[[i]][, scenarios, drop = FALSE])
        map_dfr(seq_along(STEP15_WINDOWS), function(w) {
          window <- names(STEP15_WINDOWS)[w]
          map_dfr(seq_along(STEP15_SCOPES), function(c) {
            scope <- STEP15_SCOPES[c]
            panel <- y[, input$windows[[w]][[c]], drop = FALSE]
            cumulative <- matrix(rowSums(panel), ncol = 1L)
            bind_rows(
              step15_factorial_effects(panel, d, factors, scope, window, "pooled_country_year"),
              step15_factorial_effects(cumulative, d, factors, scope, window, "cumulative_collector"),
              tibble(record = "scenario_revenue", scope, window, estimand = "cumulative_collector",
                scenarios = nrow(d), scenario_id = d$scenario_id,
                cumulative_revenue_usd_bn = cumulative[, 1L])
            )
          })
        }) |> mutate(distributional_level = ladders[i], design = name)
      })
  })
}

run_step15_diagnostics <- function() {
  input <- step15_inputs()
  point_measure <- step15_measure(input)
  point <- step15_evaluate(input, point_measure, check = TRUE)$revenue
  gap <- step15_check_production(input, point)
  message("1/2 Joint Monte Carlo. Maximum production reproduction gap in USD: ", format(gap))
  variance <- step15_monte_carlo(input, point)
  message("2/2 Expanded accounting factorial")
  factorial <- step15_factorial(input, point_measure, point)
  dir.create(DIAGNOSTICS_DIR, recursive = TRUE, showWarnings = FALSE)
  write_csv(variance, file.path(DIAGNOSTICS_DIR, "step15_law_of_total_variance_decomposition.csv"))
  write_csv(factorial, file.path(DIAGNOSTICS_DIR, "step15_globe_accounting_factorial_anova.csv"))
  message("Wrote ", nrow(variance), " variance rows and ", nrow(factorial), " factorial rows")
}

if (is_direct_script_run("code/diagnostics_step15_total_variance_and_globe_factorial.R")) {
  run_step15_diagnostics()
}
