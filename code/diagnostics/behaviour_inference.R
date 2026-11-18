# Targeted R12a inference audit using frozen inputs. The production fit and
# its covariance are untouched. This script writes only to a fresh audit root.
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "00_helpers.R"), local = TRUE)

diagnose_stage8_activity_vcov <- function(processed) {
  read_panel <- function(stem) readRDS(file.path(processed, paste0(stem, ".rds")))
  keys <- c("parent", "affiliate", "year")
  terms <- paste0(c("act_holding", "act_ip", "act_igf", "act_rd", "act_man"), "_panelai")
  # Mirror only the EU27 L3 affiliate + year branch of the Stage 08 diagnostic.
  sample <- read_panel("base_panel") |>
    select(all_of(keys), entities_count_panelai, all_of(terms)) |>
    filter(entities_count_panelai > 0,
      if_all(all_of(terms), ~ is.finite(.x) & between(.x, 0, entities_count_panelai))) |>
    mutate(across(all_of(terms), ~ .x / entities_count_panelai)) |>
    inner_join(read_panel("stage1_bilateral_panel") |>
      select(all_of(keys), analysis_profit_positive, l3 = stage1_distributional_liability_rate),
      by = keys, relationship = "one-to-one") |>
    inner_join(read_panel("stage2_bilateral_panel") |>
      filter(rate_scenario == "initial") |> select(all_of(keys), phi = stage2_phi),
      by = keys, relationship = "one-to-one") |>
    filter(year %in% MAIN_YEARS, analysis_profit_positive > 0,
      affiliate %in% EU27_ISO3, is.finite(l3))
  formula <- stats::as.formula(paste("l3 ~", paste(terms, collapse = " + "), "| affiliate + year"))
  warnings <- character()
  record <- function(w) warnings <<- c(warnings, conditionMessage(w))
  fit <- withCallingHandlers(
    fixest::feols(formula, data = sample, vcov = ~ parent + affiliate, notes = FALSE),
    warning = record
  )
  repaired <- stats::vcov(fit)
  raw <- stats::vcov(fit, vcov = ~ parent + affiliate, vcov_fix = FALSE)
  reported <- fixest::coeftable(fit)
  used <- sample[fixest::obs(fit), , drop = FALSE]
  raw_variance <- diag(raw)
  raw_se <- sqrt(if_else(raw_variance >= 0, raw_variance, NA_real_))
  df <- attr(repaired, "df.t")
  if (is.null(df)) df <- attr(stats::vcov(fit, vcov = ~ parent + affiliate, attr = TRUE), "df.t")
  raw_p <- 2 * stats::pt(abs(stats::coef(fit) / raw_se), df, lower.tail = FALSE)
  effects <- tibble(term = names(stats::coef(fit)), coefficient = unname(stats::coef(fit)),
    raw_variance = unname(raw_variance), raw_se = unname(raw_se),
    repaired_se = unname(reported[, 2]), raw_p = unname(raw_p),
    repaired_p = unname(reported[, 4]), raw_holm_p = stats::p.adjust(raw_p, "holm"),
    repaired_holm_p = stats::p.adjust(reported[, 4], "holm"))
  eigenvalues <- tibble(index = seq_len(ncol(raw)),
    raw_eigenvalue = eigen(raw, symmetric = TRUE, only.values = TRUE)$values,
    repaired_eigenvalue = eigen(repaired, symmetric = TRUE, only.values = TRUE)$values)
  archived <- read_csv(file.path(processed, "diagnostics", "step14_business_activity_drivers.csv"),
    show_col_types = FALSE) |>
    filter(scope == "EU27", outcome == "l3", fixed_effects == "affiliate + year") |>
    select(term, estimate, std_error, p_value)
  paired <- left_join(effects, archived, by = "term", relationship = "one-to-one")
  stopifnot(nrow(archived) == nrow(effects),
    any(grepl("VCOV matrix is not positive definite", warnings, fixed = TRUE)),
    min(eigenvalues$raw_eigenvalue) < 0, max(abs(paired$coefficient - paired$estimate)) < 1e-12,
    max(abs(paired$repaired_se - paired$std_error)) < 1e-12,
    max(abs(paired$repaired_p - paired$p_value)) < 1e-12)
  list(effects = effects, eigenvalues = eigenvalues,
    sample = tibble(formula = paste(deparse(formula), collapse = " "), observations = nrow(used),
      parents = n_distinct(used$parent), affiliates = n_distinct(used$affiliate),
      pair_years = n_distinct(used$parent, used$affiliate, used$year),
      first_year = min(used$year), last_year = max(used$year),
      df_inference = df, fixest = as.character(utils::packageVersion("fixest")),
      covariance = "parent + affiliate", warning = paste(warnings, collapse = " | ")),
    covariance = list(raw = raw, repaired = repaired), sample_keys = used[keys])
}

if (is_direct_script_run("code/diagnostics/behaviour_inference.R")) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 2L || file.exists(args[2]) || !dir.exists(dirname(args[2]))) {
    stop("Supply a processed input directory and a fresh audit output directory")
  }
  audit <- diagnose_stage8_activity_vcov(args[1])
  stopifnot(dir.create(args[2]))
  for (name in c("effects", "eigenvalues", "sample")) {
    write_csv(audit[[name]], file.path(args[2], paste0("activity_", name, ".csv")))
  }
  saveRDS(audit[c("covariance", "sample_keys")], file.path(args[2], "activity_covariance.rds"))
}
