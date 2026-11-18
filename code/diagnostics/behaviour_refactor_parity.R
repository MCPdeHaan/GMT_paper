# Read-only comparison with the Stage 05/09 implementation in a starting
# checkout (or a git archive of its code directory). Writes a separate ledger.
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "00_helpers.R"), local = TRUE)

compare_behaviour_estimation <- function(reference_code_root, input_root) {
  load_engine <- function(root) {
    root <- normalizePath(root, mustWork = TRUE)
    engine <- new.env(parent = environment(compare_behaviour_estimation))
    withr::with_envvar(c(GMT_PROJECT_ROOT = root, GMT_OUTPUT_ROOT = input_root),
      source(file.path(root, "code", "09_econometric_and_reallocation_extensions.R"), local = engine))
    engine
  }
  project <- normalizePath(GMT_PROJECT_ROOT, mustWork = TRUE)
  input_root <- normalizePath(input_root, mustWork = TRUE)
  reference <- load_engine(reference_code_root)
  current <- load_engine(project)
  read_input <- function(stem) readRDS(file.path(input_root, "data", "processed", paste0(stem, ".rds")))
  base <- read_input("base_panel")
  forward_rates <- read_input("etr_forward")
  host <- read_input("stage1_affiliate_year")
  calculate <- function(e) {
    warnings <- character()
    results <- withCallingHandlers({
      sample <- e$prepare_estimation_sample(base, etr_forward = forward_rates)
      fits <- e$estimate_stage3_models(sample)
      division_inputs <- e$build_division_bias_inputs(sample, base)
      list(sample = sample, fits = fits, fit_comparison = e$model_comparison_table(fits),
        extracted_tax_coefficients = e$extract_tax_coefficients(fits),
        wald = e$stage3_model_wald_tests(fits),
        coefficients = bind_rows(map(fits[c("linear", "quadratic", "logarithmic")],
          ~ bind_rows(.x$coefficient_table, .x$coefficient_table_two_way))),
        schedule = e$stage3_semielasticity_schedule(fits),
        test_comparison = e$run_specification_tests(sample, fits),
        instruments = e$build_tax_endogeneity_diagnostics(sample),
        alternatives = e$build_stage3_alternative_estimators_diagnostic(sample, base, fits$logarithmic$t0),
        division_inputs = division_inputs, division_fits = e$audit_division_bias(sample, base),
        host_schedule = e$build_behavioural_affiliate_year(host, fits,
          applied_linear_beta = e$applied_preferred_beta(NULL)))
    }, warning = function(w) warnings <<- c(warnings, conditionMessage(w)))
    results$warnings <- warnings
    results
  }
  old <- calculate(reference)
  new <- calculate(current)
  parity <- tibble(object = names(old), identical = map(seq_along(old),
    ~ identical(old[[.x]], new[[.x]])) |> unlist(use.names = FALSE))
  stopifnot(all(parity$identical),
    identical(new$sample, read_input("stage3_estimation_sample")),
    identical(new$coefficients, read_input("stage3_model_coefficients")),
    identical(new$schedule, read_input("stage3_semielasticity_schedule")),
    identical(new$instruments, read_input("stage3_tax_endogeneity_diagnostics")))
  manual_fit_metadata <- map_dfr(new$fits[c("linear", "quadratic", "logarithmic")], function(fit) {
    tibble(model_spec = fit$model_spec, n = fit$n, loglik = fit$loglik, rss = fit$rss,
      x_rank = fit$x_rank, fe_rank = fit$fe_rank, k_total = fit$k_total,
      df_resid_full = fit$df_resid_full, bic = fit$bic, converged = NA)
  })
  division_inputs <- new$division_inputs
  samples <- map_dfr(c("current_etr", "lagged_etr", "jackknife_etr", "jackknife_foreign_only_etr",
    "statutory_cit", "forward_eatr"), function(regressor) {
    used <- filter(division_inputs, is.finite(.data[[regressor]]))
    tibble(regressor, observations = nrow(used), pairs = n_distinct(used$pair_id),
      parents = n_distinct(used$parent), affiliates = n_distinct(used$affiliate),
      first_year = min(used$year), last_year = max(used$year))
  })
  list(parity = parity, samples = samples, manual_fit_metadata = manual_fit_metadata,
    baseline_coefficients = new$coefficients, baseline_schedule = new$schedule,
    baseline_joint_tests = new$wald, iv = new$instruments, alternatives = new$alternatives,
    division_fits = new$division_fits, warnings = tibble(warning = new$warnings))
}

if (is_direct_script_run("code/diagnostics/behaviour_refactor_parity.R")) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 3L || file.exists(args[3]) || !dir.exists(dirname(args[3]))) {
    stop("Supply the starting code root, processed input root and a fresh audit output directory")
  }
  evidence <- compare_behaviour_estimation(args[1], args[2])
  stopifnot(dir.create(args[3]))
  iwalk(evidence, ~ write_csv(.x, file.path(args[3], paste0(.y, ".csv"))))
}
