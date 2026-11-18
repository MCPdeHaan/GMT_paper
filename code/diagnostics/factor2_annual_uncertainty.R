# Annual projections of the existing preferred aggregate-branch draw laws.
# No new estimator, source amount, policy scenario or simulation law is added.
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "00_helpers.R"), local = TRUE)

run_factor2_annual_uncertainty <- function(input_root, output_dir) {
  withr::local_preserve_seed()
  source(file.path(GMT_PROJECT_ROOT, "code", "07a_uncertainty.R"), local = TRUE)
  source(file.path(GMT_PROJECT_ROOT, "code", "11_policy_game_and_variance_extensions.R"), local = TRUE)
  PROCESSED_DIR <- file.path(normalizePath(input_root, mustWork = TRUE), "data", "processed")
  DIAGNOSTICS_DIR <- file.path(PROCESSED_DIR, "diagnostics")
  target <- file.path(normalizePath(dirname(output_dir), mustWork = TRUE), basename(output_dir))
  protected <- c(file.path(normalizePath(input_root), c("data", "writing")),
    file.path(normalizePath(GMT_PROJECT_ROOT), c("data", "writing", ".git")))
  if (file.exists(target) || any(target == protected | startsWith(target, paste0(protected, "/")))) {
    stop("Use a fresh diagnostic directory outside data and publication trees", call. = FALSE)
  }
  input <- step15_inputs()
  source <- build_preferred_source_panel()
  unsupported <- attr(source, "utpr_unsupported_contract", exact = TRUE)
  predictions <- readRDS(file.path(PROCESSED_DIR, "profit_correction_parent_year.rds")) |>
    filter(year %in% MAIN_YEARS) |> select(parent, year, posterior_y, posterior_sd)
  set.seed(20260613)
  profit <- map_dfr(seq_len(500), function(draw) {
    rho <- predictions |> mutate(rho_draw = inverse_bounded_logit(rnorm(n(), posterior_y, posterior_sd))) |>
      select(parent, year, rho_draw)
    panel <- source |> left_join(rho, by = c("parent", "year"), relationship = "many-to-one") |>
      mutate(profit_draw = case_when(!is.na(profit_adj_panelai) ~ profit_adj_panelai,
        is_domestic ~ profit_panelai * (1-rho_draw), TRUE ~ profit_panelai))
    map_dfr(MAIN_YEARS, function(y) {
      part <- filter(panel, year == y)
      compute_preferred_revenue_from_profit(part, part$profit_draw, "rho_draw", draw,
        unsupported = unsupported) |>
        transmute(study = "profit_only", draw_id = draw, year = y, factor4_sbs,
          eu_revenue = eu27_final_revenue)
    })
  })
  set.seed(STEP15_SEED)
  errors <- matrix(sample.int(nrow(input$residuals), length(input$residual_hosts)*STEP15_DRAWS,
    replace = TRUE), nrow = length(input$residual_hosts))
  betas <- rnorm(STEP15_DRAWS, input$beta, input$beta_se)
  rhos <- matrix(inverse_bounded_logit(rnorm(nrow(input$predictions)*STEP15_DRAWS,
    input$predictions$posterior_y, input$predictions$posterior_sd)), nrow = nrow(input$predictions))
  project <- function(y, study, draw) {
    bind_cols(input$collector_year, as_tibble(y[, c("x10001", "x10011"), drop = FALSE])) |>
      summarise(across(starts_with("x"), sum), .by = year) |>
      pivot_longer(starts_with("x"), names_to = "scenario_id", values_to = "eu_revenue") |>
      transmute(study, draw_id = draw, year,
        factor4_sbs = if_else(scenario_id == "x10001", "universal", "sbs"), eu_revenue)
  }
  joint <- map_dfr(seq_len(STEP15_DRAWS), function(draw) {
    m <- step15_measure(input, rhos[, draw], errors[, draw])
    y <- step15_evaluate(input, m, betas[draw], check = TRUE)$revenue
    project(y*1e9, "joint", draw)
  })
  host <- input$host
  measured <- readRDS(file.path(PROCESSED_DIR, "stage1_measurement_error_stage1_draws.rds"))
  comparison <- readRDS(file.path(PROCESSED_DIR, "stage3_model_comparison.rds"))
  preferred_model <- comparison$model_spec[which.min(comparison$bic_rank)]
  baseline <- step15_measure(input)
  measurement <- map_dfr(seq_len(500), function(draw) {
    h <- apply_stage1_measurement_draw(host, stage1_draw_for_id(measured, draw))
    m <- baseline
    m$distributional <- list(share = coalesce_zero(h$stage1_distributional_low_share),
      gap = coalesce_zero(h$stage1_distributional_topup_rate))
    # Only aggregate-branch receipts are retained. The sparse source schedule
    # uses the same applied linear coefficient as the standalone production fit.
    stopifnot(preferred_model == "linear")
    y <- step15_evaluate(input, m, beta = input$beta, check = TRUE)$revenue
    project(y*1e9, "measurement_only", draw)
  })
  draws <- bind_rows(profit, measurement, joint)
  cumulative <- draws |> summarise(eu_revenue = sum(eu_revenue),
    .by = c(study, draw_id, factor4_sbs))
  # Verify the annual projection against the original cumulative study,
  # rather than inferring an EU interval by summing country quantiles.
  preferred <- readRDS(file.path(PROCESSED_DIR, "stage1_measurement_error_scenario_draws.rds")) |>
    filter(scenario_id %in% c("x10001", "x10011")) |> select(draw_id, factor4_sbs, expected = eu_revenue)
  check <- filter(cumulative, study == "measurement_only") |>
    left_join(preferred, by = c("draw_id", "factor4_sbs"), relationship = "one-to-one")
  stopifnot(!anyNA(check$expected), max(abs(check$eu_revenue-check$expected)) < .001)
  annual <- draws |> summarise(draws = n_distinct(draw_id), mean = mean(eu_revenue),
    p025 = quantile(eu_revenue, .025), p05 = quantile(eu_revenue, .05),
    p50 = quantile(eu_revenue, .5), p95 = quantile(eu_revenue, .95),
    p975 = quantile(eu_revenue, .975), .by = c(study, year, factor4_sbs)) |>
    mutate(width90 = p95-p05, width95 = p975-p025)
  dir.create(output_dir)
  write_csv(annual, file.path(output_dir, "preferred_annual_intervals.csv"))
  write_csv(cumulative, file.path(output_dir, "preferred_cumulative_draws.csv"))
  invisible(list(annual = annual, cumulative = cumulative))
}

if (is_direct_script_run("code/diagnostics/factor2_annual_uncertainty.R")) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 2L) stop("Supply an input root and fresh diagnostic directory")
  run_factor2_annual_uncertainty(args[1], args[2])
}
