# Independent detailed-data-frame versus sparse evaluation on matched inputs.
# This diagnostic keeps the production estimators and random draw law intact.
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", unset = "."), "code", "00_helpers.R"), local = TRUE)

run_factor2_evaluator_parity <- function(input_root, output_dir) {
  withr::local_envvar(GMT_FACTOR2_SPECIFICATION = Sys.getenv("GMT_FACTOR2_SPECIFICATION", unset = NA_character_))
  withr::local_preserve_seed()
  source(file.path(GMT_PROJECT_ROOT, "code", "07a_uncertainty.R"), local = TRUE)
  source(file.path(GMT_PROJECT_ROOT, "code", "11_policy_game_and_variance_extensions.R"), local = TRUE)
  PROCESSED_DIR <- file.path(normalizePath(input_root, mustWork = TRUE), "data", "processed")
  DIAGNOSTICS_DIR <- file.path(PROCESSED_DIR, "diagnostics")
  destination <- file.path(normalizePath(dirname(output_dir), mustWork = TRUE), basename(output_dir))
  protected <- c(file.path(normalizePath(input_root), c("data", "writing")),
    file.path(normalizePath(GMT_PROJECT_ROOT), c("data", "writing", ".git")))
  if (file.exists(destination) || any(destination == protected | startsWith(destination, paste0(protected, "/")))) {
    stop("Use a fresh diagnostic directory outside data and publication trees", call. = FALSE)
  }
  dir.create(output_dir)
  original <- readRDS(file.path(PROCESSED_DIR,'stage3_factorial_pair_year.rds'))
  sectors <- readRDS(file.path(PROCESSED_DIR,'stage2_sectoral_panel.rds'))
  weights <- read_stage4_utpr_weights()
  results <- list()
  accounting_sources <- list()
  accounting_collectors <- list()
  for (spec in c('LEGACY_HYBRID_SBIE_SBTI','SECTORAL_SBIE_ONLY')) {
   Sys.setenv(GMT_FACTOR2_SPECIFICATION=spec)
   input <- step15_inputs()
   point <- step15_measure(input)
   globe <- step15_globe_base(input)
   # Recreate the production's first primary joint draw without changing its law.
   set.seed(STEP15_SEED)
   errors <- matrix(sample.int(nrow(input$residuals),length(input$residual_hosts)*STEP15_DRAWS,replace=TRUE),nrow=length(input$residual_hosts))
   betas <- rnorm(STEP15_DRAWS,input$beta,input$beta_se)
   rhos <- matrix(inverse_bounded_logit(rnorm(nrow(input$predictions)*STEP15_DRAWS,input$predictions$posterior_y,input$predictions$posterior_sd)),nrow=nrow(input$predictions))
   drawn <- step15_measure(input,rhos[,1],errors[,1])
   cases <- list(L3_point=point,
    L4_anchored=list(profit=point$profit,average=point$average,distributional=list(share=coalesce_zero(input$cells$ladder_l4_anchored_low_share),gap=coalesce_zero(input$cells$ladder_l4_anchored_topup_rate),bilateral=TRUE)),
    L4_strict=list(profit=point$profit,average=point$average,distributional=list(share=coalesce_zero(input$cells$ladder_l4_strict_low_share),gap=coalesce_zero(input$cells$ladder_l4_strict_topup_rate),bilateral=TRUE)),
    L3_accounting=list(profit=globe$profit,average=globe$average,distributional=globe$L3),
    L4_accounting=list(profit=globe$profit,average=globe$average,distributional=globe$L4_strict),
    L3_joint_draw_1=drawn)
   for (case in names(cases)) {
    m<-cases[[case]]
    beta<-if(case=='L3_joint_draw_1')betas[1] else input$beta
    host_profit<-input$host_sum(m$profit)
    panel<-original
    cell_id<-match(paste(panel$parent,panel$affiliate,panel$year),paste(input$cells$parent,input$cells$affiliate,input$cells$year))
    host_id<-input$cells$host_id[cell_id]
    panel$analysis_profit_positive<-m$profit[cell_id]
    endpoint<-match(panel$rate_scenario,STAGE2_ENDPOINTS$rate_scenario)
    panel$stage2_sbie<-input$sbie[cbind(cell_id,endpoint)]
    panel$stage2_phi<-compute_phi_ratio(panel$stage2_sbie,panel$analysis_profit_positive)
    excess<-panel$analysis_profit_positive-pmin(pmax(panel$stage2_sbie,0),panel$analysis_profit_positive)
    host<-input$host
    for(branch in c('average','distributional')) {
     z<-m[[branch]]
     share<-if(isTRUE(z$bilateral))z$share[cell_id] else z$share[host_id]
     gap<-if(isTRUE(z$bilateral))z$gap[cell_id] else z$gap[host_id]
     panel[[paste0('stage1_lowtax_profit_',branch)]]<-panel$analysis_profit_positive*share
     panel[[paste0('stage2_excess_lowtax_profit_',branch)]]<-excess*share
     panel[[paste0('stage2_topup_tax_',branch)]]<-excess*share*gap
     panel[[if(branch=='average')'average_low_share' else 'stage1_distributional_low_share']]<-share
     if(isTRUE(z$bilateral)) {
      low<-input$host_sum(m$profit*z$share)
      hs<-coalesce_zero(safe_divide(low,host_profit))
      hg<-coalesce_zero(safe_divide(input$host_sum(m$profit*z$share*z$gap),low))
     } else {hs<-z$share;hg<-z$gap}
     host[[if(branch=='average')'average_low_share' else 'stage1_distributional_low_share']]<-hs
     host[[if(branch=='average')'average_topup_rate' else 'stage1_distributional_topup_rate']]<-hg
    }
    s<-sectors
    hi<-match(paste(s$affiliate,s$year),paste(host$affiliate,host$year))
    s$sectoral_profit_proxy<-host_profit[hi]*s$sectoral_profit_share_used
    s$sectoral_phi<-compute_phi_ratio(s$sectoral_sbie,s$sectoral_profit_proxy)
    s$sectoral_kappa<-safe_divide(sbti_maximum_capacity(s$sectoral_payroll,s$sectoral_assets),s$sectoral_profit_proxy)
    s$average_topup_rate<-host$average_topup_rate[hi]
    s$stage1_distributional_topup_rate<-host$stage1_distributional_topup_rate[hi]
    bridge<-build_sectoral_factor2_bridge(distinct(panel,rate_scenario,parent,affiliate,year,.keep_all=TRUE),host,s)
    bi<-match(paste(panel$rate_scenario,panel$affiliate,panel$year),paste(bridge$rate_scenario,bridge$affiliate,bridge$year))
    selected<-ifelse(panel$x1_etr==0,bridge$sectoral_scale_average[bi],bridge$sectoral_scale_distributional[bi])
    panel$sectoral_scale_selected<-ifelse(panel$x2_substance==0,1,coalesce(selected,1))
    panel$stage2_topup_selected<-ifelse(panel$x1_etr==0,panel$stage2_topup_tax_average,panel$stage2_topup_tax_distributional)
    panel$topup_after_stage2<-pmax(panel$stage2_topup_selected*panel$sectoral_scale_selected,0)
    tau<-numeric(nrow(panel))
    for(branch in c('average','distributional')) {
     selected<-panel$x1_etr==as.integer(branch=='distributional')
     z<-m[[branch]]
     sh<-if(isTRUE(z$bilateral))z$share[cell_id[selected]] else z$share[host_id[selected]]
     gp<-if(isTRUE(z$bilateral))z$gap[cell_id[selected]] else z$gap[host_id[selected]]
     tau[selected]<-ifelse(sh>0&gp>0,GMT_RATE-gp,NA_real_)
    }
    panel<-replace_behaviour_schedule(panel,tau,coalesce_zero(compute_reallocation_share(tau,rep('linear',length(tau)),beta)))
    source<-build_source_panel(panel)
    a<-allocate_stage4_revenue(source,weights)
    if (case %in% c("L3_point", "L4_strict", "L3_accounting", "L4_accounting")) {
      # Retain accounting off/on at source-jurisdiction-year and collector-channel
      # grain. These are detailed-kernel ledgers, not reconstructed sparse totals.
      unsupported_keys <- a$unsupported_utpr |>
        select(scenario_id, parent, year) |> mutate(unsupported_route = TRUE)
      accounted <- source |>
        left_join(unsupported_keys, by = c("scenario_id", "parent", "year"),
          relationship = "many-to-one") |>
        mutate(unsupported_utpr = if_else(coalesce(unsupported_route, FALSE), stage4_utpr_pool, 0),
          assigned_utpr = stage4_utpr_pool - unsupported_utpr)
      amounts <- c("analysis_profit_positive", "topup_after_stage2", "topup_after_behaviour",
        "stage4_qdmtt_liability", "stage4_iir_liability", "stage4_utpr_pool", "assigned_utpr",
        "unsupported_utpr", "stage4_sbs_extinguished_liability")
      accounting_sources[[length(accounting_sources) + 1L]] <- accounted |>
        summarise(source_rows = n(), missing_liability_rows = sum(is.na(topup_after_behaviour)),
          across(all_of(amounts), ~ sum(.x, na.rm = TRUE)),
          .by = c(scenario_id, affiliate, year)) |>
        mutate(specification = spec, case = case, .before = 1)
      accounting_collectors[[length(accounting_collectors) + 1L]] <-
        a$revenue_by_channel_global |>
          summarise(revenue = sum(revenue), .by = c(scenario_id, country, year, channel)) |>
          mutate(specification = spec, case = case, .before = 1)
    }
    actual<-a$revenue_country_year_eu27 |> select(country,year,scenario_id,revenue) |> pivot_wider(names_from=scenario_id,values_from=revenue)
    actual<-left_join(input$collector_year,actual,by=c('country','year'),relationship='one-to-one')
    sparse<-step15_evaluate(input,m,beta,check=TRUE)
    gap<-max(abs(as.matrix(actual[colnames(sparse$revenue)])-sparse$revenue*1e9))
    stopifnot(gap<.001)
    results[[length(results)+1L]]<-tibble(specification=spec,case=case,scenarios=32L,collector_years=nrow(actual),max_absolute_gap_usd=gap,sparse_conservation_gap_usd=sparse$max_global_conservation_gap)
    cat(spec,case,gap,'\n')
   }
  }
  write_csv(bind_rows(results),file.path(output_dir,'evaluator_parity.csv'))
  source_year <- bind_rows(accounting_sources)
  source_keys <- c("case", "scenario_id", "affiliate", "year")
  assert_unique_keys(source_year, c("specification", source_keys), "accounting source ledger")
  historical <- source_year |> filter(specification == "LEGACY_HYBRID_SBIE_SBTI") |>
    select(-specification) |> arrange(across(all_of(source_keys)))
  revised <- source_year |> filter(specification == "SECTORAL_SBIE_ONLY") |>
    select(-specification) |> arrange(across(all_of(source_keys)))
  stopifnot(identical(historical[source_keys], revised[source_keys]),
    all(source_year$missing_liability_rows == 0),
    identical(filter(historical, substr(scenario_id, 3, 3) == "0"),
      filter(revised, substr(scenario_id, 3, 3) == "0")))
  write_csv(tibble(contract = c("matched_accounting_source_year_keys", "aggregate_source_amount_identity"),
    rows = c(nrow(historical), sum(substr(historical$scenario_id, 3, 3) == "0")), result = "exact"),
    file.path(output_dir, "accounting_contract_checks.csv"))
  saveRDS(list(source_year = source_year, collector_channel = bind_rows(accounting_collectors)),
    file.path(output_dir, "accounting_routing_ledgers.rds"))
    invisible(bind_rows(results))
}

if (is_direct_script_run("code/diagnostics/factor2_evaluator_parity.R")) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) != 2L) stop("Supply an input root and fresh diagnostic directory")
  run_factor2_evaluator_parity(args[1], args[2])
}
