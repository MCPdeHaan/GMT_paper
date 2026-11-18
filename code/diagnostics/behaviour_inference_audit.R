# R12c diagnostic. Inputs and outputs are separate from the replication stages.
source(file.path(Sys.getenv("GMT_PROJECT_ROOT", "."), "code", "09_econometric_and_reallocation_extensions.R"), local = TRUE)
source(file.path(GMT_PROJECT_ROOT, "code", "diagnostics", "behaviour_inference.R"), local = TRUE)

audit_controls <- c("log_assets", "log_payroll", "log_gdp_pc", "log_population")

# Exact inversion of (RF - b FS)^2 <= critical^2 Var(RF - b FS).
# The two reduced-form fits have exactly the same regressors and observations.
ar_intervals <- function(rf, fs, covariance, critical) {
  interval <- function(lo, hi, status = "accepted") data.frame(lower = lo, upper = hi, status)
  if (any(!is.finite(covariance)) || min(eigen(covariance, symmetric = TRUE)$values) <= 0)
    return(interval(NA_real_, NA_real_, "undefined covariance"))
  a <- fs^2 - critical^2 * covariance[2, 2]
  b <- -2 * (rf * fs - critical^2 * covariance[1, 2])
  c <- rf^2 - critical^2 * covariance[1, 1]
  if (a == 0) {
    if (b > 0) return(interval(-Inf, -c/b))
    if (b < 0) return(interval(-c/b, Inf))
    if (c <= 0) return(interval(-Inf, Inf))
    return(interval(NA_real_, NA_real_, "empty"))
  }
  disc <- b^2 - 4*a*c
  if (disc < 0) {
    if (a < 0) return(interval(-Inf, Inf))
    return(interval(NA_real_, NA_real_, "empty"))
  }
  if (disc == 0 && a < 0) return(interval(-Inf, Inf))
  roots <- sort((-b + c(-1, 1)*sqrt(disc))/(2*a))
  if (a > 0) return(interval(roots[1], roots[2]))
  interval(c(-Inf, roots[2]), c(roots[1], Inf))
}

audit_iv <- function(data, instrument, controls = audit_controls, preferred = -1.4651183078485985) {
  vars <- c("log_profit", "tau", instrument, controls)
  stopifnot(all(is.finite(as.matrix(data[vars]))))
  m <- demean_two_way(as.matrix(data[vars]), data$pair_id, data$year)
  z <- qr.resid(qr(m[, controls, drop = FALSE]), m[, instrument])
  if (sum(z^2) <= .Machine$double.eps * max(1, sum(m[, instrument]^2)))
    stop("Excluded instrument has no independent within variation")
  x <- m[, c(instrument, controls), drop = FALSE]
  fit <- lm.fit(x, m[, c("log_profit", "tau")])
  slopes <- fit$coefficients[1, ]
  n <- nrow(data)
  parents <- length(unique(data$parent))
  affiliates <- length(unique(data$affiliate))
  pairs <- length(unique(data$pair_id))
  df <- min(parents, affiliates) - 1L
  df_res <- n - fit$rank - pairs - length(unique(data$year)) + 1L
  scores <- fit$residuals * as.numeric(z / sum(z^2))
  meat <- function(group) {
    s <- rowsum(scores, group)
    g <- nrow(s)
    stopifnot(g > 1, df_res > 0)
    crossprod(s) * g/(g-1) * (n-1)/df_res
  }
  v <- meat(data$parent) + meat(data$affiliate) - meat(data$pair_id)
  rf <- unname(slopes[1])
  fs <- unname(slopes[2])
  critical <- qt(.975, df)
  # An exactly irrelevant excluded regressor still permits reduced-form null
  # tests. Its conventional 2SLS point is numerically unidentified.
  second <- se <- NA_real_
  within_tau <- qr.resid(qr(m[, controls, drop = FALSE]), m[, "tau"])
  if (abs(fs)*sqrt(sum(z^2)) > .Machine$double.eps^0.75*sqrt(sum(within_tau^2))) {
    iv <- fit_fe_2sls(data, "log_profit", "tau", instrument, controls, "audit")
    second <- iv$coefficients[["tau"]]
    v_second <- iv$vcov_two_way["tau","tau"]
    if (v_second >= 0) se <- sqrt(v_second)
  }
  nulls <- c(0, preferred, second, 1, -10)
  nulls <- nulls[is.finite(nulls)]
  variances <- v[1,1] - 2*nulls*v[1,2] + nulls^2*v[2,2]
  fs_se <- sqrt(v[2,2])
  rf_se <- sqrt(v[1,1])
  list(iv = data.frame(n, parents, affiliates, pairs, df, df_res, fs, fs_se,
    squared_t = (fs/fs_se)^2, partial_r2 = cor(z, qr.resid(qr(m[,controls,drop=FALSE]),m[,"tau"]))^2,
    rf, rf_se, rf_p = 2*pt(-abs(rf/rf_se), df), second, se,
    wald_lower = second-critical*se, wald_upper = second+critical*se,
    cov_rf_fs = v[1,2]),
    nulls = data.frame(beta = nulls, variance = variances,
      p = 2*pt(-abs(rf-nulls*fs)/sqrt(ifelse(variances > 0, variances, NA_real_)), df)),
    intervals = ar_intervals(rf, fs, v, critical))
}

audit_fit_covariance <- function(fit, used, id, tax) {
  covariances <- list(hetero = "hetero", parent = ~parent, affiliate = ~affiliate,
    two_way = ~parent + affiliate, repaired = ~parent + affiliate)
  bind_rows(lapply(names(covariances), function(method) {
    v <- vcov(fit, vcov = covariances[[method]], attr = TRUE, vcov_fix = method == "repaired")
    eigenvalues <- eigen(v, symmetric = TRUE)$values
    se <- sqrt(ifelse(diag(v) > 0, diag(v), NA_real_))
    df <- attr(v, "df.t")
    b <- coef(fit)
    sub <- v[tax,tax,drop=FALSE]
    joint <- if (min(eigen(sub, symmetric = TRUE)$values)>0)
      as.numeric(crossprod(b[tax], solve(sub,b[tax])))/length(tax) else NA_real_
    data.frame(id, method, term = names(b), estimate = unname(b), se = unname(se),
      p = 2*pt(-abs(b/se), df), joint_tax_p = pf(joint,length(tax),df,lower.tail=FALSE),
      eigen_min = min(eigenvalues), negative_eigenvalues = sum(eigenvalues < 0),
      eigenvalues = paste(format(eigenvalues,digits=17),collapse=" "),
      n = nrow(used), parents = n_distinct(used$parent), affiliates = n_distinct(used$affiliate),
      pairs = n_distinct(used$parent, used$affiliate), residual_df = df.residual(fit),
      parameters = fit$nparams, df, row.names=NULL)
  }))
}

audit_division_covariance <- function(inputs, ledger, offset) {
  designs <- distinct(ledger, regressor, sample, activity, estimator, model_spec, covariance_repaired)
  cache <- new.env(parent=emptyenv())
  members <- list()
  displays <- list()
  for (i in seq_len(nrow(designs))) {
    d <- designs[i,]
    proxy <- if (startsWith(d$sample,"matched_") && d$sample != "matched_lagged_activity")
      sub("^matched_", "", d$sample) else d$regressor
    sub <- inputs[is.finite(inputs[[proxy]]) & is.finite(inputs[[d$regressor]]),]
    if (d$sample == "matched_lagged_activity") sub <- filter(sub, is.finite(log_assets_lagged), is.finite(log_payroll_lagged))
    if (d$activity == "lagged") sub <- mutate(sub, log_assets=log_assets_lagged, log_payroll=log_payroll_lagged)
    sub$tau <- sub[[d$regressor]]
    sub$tau_sq <- sub$tau^2
    sub$log_tau <- log(offset + sub$tau)
    terms <- switch(d$model_spec, linear="tau", quadratic=c("tau","tau_sq"), logarithmic=c("tau","log_tau"))
    poisson <- d$estimator == "fe_ppml_positive"
    y <- if (poisson) "analysis_profit_base" else "log_profit"
    fm <- as.formula(paste(y,"~",paste(c(audit_controls,terms),collapse="+"),"|pair_id+year"))
    key <- digest::digest(list(d$estimator, d$model_spec, sub[c("pair_id","year",y,terms,audit_controls)],
      if(d$estimator=="fe_wls") sub$pair_profit_weight))
    displays[[i]] <- mutate(d, id=key, formula=paste(deparse(fm),collapse=" "))
    if (exists(key,cache,inherits=FALSE)) next
    ssc <- fixest::ssc(K.fixef="full", G.df="conventional")
    fit <- if (poisson) fixest::fepois(fm, sub, vcov=~parent+affiliate, ssc=ssc, nthreads=1, notes=FALSE) else
      if (d$estimator=="fe_wls") fixest::feols(fm,sub,weights=~pair_profit_weight,vcov=~parent+affiliate,
        ssc=ssc,nthreads=1,notes=FALSE) else fixest::feols(fm,sub,vcov=~parent+affiliate,
        ssc=ssc, nthreads=1, notes=FALSE)
    used <- sub[fixest::obs(fit),]
    support <- used[c("parent","affiliate","year")]
    sample_id <- digest::digest(as.data.frame(support))
    members[[sample_id]] <- support
    results <- audit_fit_covariance(fit,used,key,terms)
    original <- filter(ledger, regressor==d$regressor,sample==d$sample,activity==d$activity,
      estimator==d$estimator,model_spec==d$model_spec,statistic_type=="coefficient")
    stopifnot(max(abs(original$estimate-coef(fit)[original$term])) < 1e-7,
      max(abs(original$std_error-results$se[results$method=="repaired"][match(original$term,names(coef(fit)))])) < 1e-8)
    cache[[key]] <- mutate(results, sample_id=sample_id, removed=nrow(sub)-nrow(used))
  }
  list(displays=bind_rows(displays), covariance=bind_rows(as.list(cache,sorted=TRUE)),
    fit_membership=bind_rows(members,.id="sample_id"))
}

audit_fiscal <- function(panel, host, weights, scenarios) {
  p <- filter(panel, scenario_id == "x10011")
  keys <- c("parent","affiliate","year")
  assert_unique_keys(p, keys, "preferred fiscal source")
  prices <- destination_price_lookup(p, "historical")
  cases <- lapply(seq_len(nrow(scenarios)), function(i) {
    d <- scenarios[i,]
    share <- compute_reallocation_share(p$static_tau_low,rep(d$form,nrow(p)),d$b3,d$b4,d$t0)
    x <- replace_behaviour_schedule(p,p$static_tau_low,coalesce_zero(share))
    stopifnot(identical(x[keys],p[keys]),identical(x$strategic_response_eligible,p$strategic_response_eligible))
    if (d$case=="preferred") stopifnot(max(abs(p$reallocated_profit-x$reallocated_profit)) < .001)
    s <- build_source_panel(x)
    alloc <- allocate_stage4_revenue(s, weights)
    unsupported <- semi_join(s,alloc$unsupported_utpr,by=c("scenario_id","parent","year"))
    revenue <- alloc$revenue_by_channel_global
    closure <- build_conservation_diagnostics(s,revenue,alloc$unsupported_utpr)
    routes <- build_rule_b_reallocation(x,host)
    # Channel aggregation sums trillions of dollars in a different order.
    # The production allocator has already tested each individual source.
    route_gap <- sum(routes$reallocated_profit_received)-sum(x$reallocated_profit)
    stopifnot(abs(route_gap) <= 128*.Machine$double.eps*max(1,sum(x$reallocated_profit)))
    r <- attach_destination_prices(routes,prices,"reallocated_profit_received",require_support=FALSE)
    bind_rows(lapply(c("EU27","Global"),function(scope) {
      local <- scope == "Global" | x$affiliate %in% EU27_ISO3
      dest <- filter(r,scope=="Global" | destination %in% EU27_ISO3)
      rev <- filter(revenue,scope=="Global" | country_is_eu27)
      loss <- sum(x$reallocated_profit[local]*coalesce_zero(x$static_tau_low[local]))
      data.frame(case=d$case,scope,source_profit=sum(x$reallocated_profit[local]),
        avoided_source_topup=sum(x$behavioural_avoided_topup[local]),
        unsupported_source=sum(filter(unsupported,scope=="Global" | affiliate %in% EU27_ISO3)$stage4_utpr_pool),
        assigned_topup=sum(rev$revenue),qdmtt=sum(rev$revenue[rev$channel=="QDMTT"]),
        iir=sum(rev$revenue[rev$channel=="IIR"]),utpr=sum(rev$revenue[rev$channel=="UTPR"]),
        profit_received=sum(dest$reallocated_profit_received), source_loss=loss,
        standard=sum(dest$ordinary_cit_gross_destination_revenue),
        historical=sum(ifelse(dest$reallocated_profit_received==0,0,dest$reallocated_profit_received*dest$price_rate)),
        global_channel_roundoff=route_gap,max_collector_gap=max(abs(closure$residual_gap)))
    }))
  })
  bind_rows(cases) |> group_by(scope) |>
    mutate(across(c(qdmtt,iir,utpr), ~ .x[case=="zero"]-.x,.names="{.col}_foregone"),
      topup_foregone=assigned_topup[case=="zero"]-assigned_topup,
      net_ordinary=standard-source_loss, net_fiscal=net_ordinary-topup_foregone,
      net_fiscal_historical=historical-source_loss-topup_foregone) |> ungroup()
}

audit_influence <- function(d) {
  slope <- function(s) {
    m <- demean_two_way(as.matrix(s[c("log_profit","tau",audit_controls)]),s$pair_id,s$year)
    unname(lm.fit(m[,-1,drop=FALSE],m[,1])$coefficients["tau"])
  }
  groups <- bind_rows(lapply(c("parent","affiliate","year"),function(k)
    bind_rows(lapply(unique(d[[k]]), function(g) data.frame(group=k,omitted=as.character(g),
      beta=slope(d[d[[k]]!=g,]))))))
  alternatives <- list(raw_etr=mutate(d,tau=tau_raw), unit_bound=mutate(d,tau=pmin(1,pmax(0,tau_raw))),
    omit_outer_percentiles=filter(d,tau_raw>min(tau),tau_raw<max(tau)),
    omit_top_profit_percentile=filter(d,analysis_profit_base<quantile(analysis_profit_base,.99)),
    omit_extreme_activity=filter(d,between(log_payroll,quantile(log_payroll,.01),quantile(log_payroll,.99)),
      between(log_assets,quantile(log_assets,.01),quantile(log_assets,.99))))
  bind_rows(groups,data.frame(group="sensitivity",omitted=names(alternatives),beta=vapply(alternatives,slope,numeric(1))))
}

# Conditional one-way restricted wild bootstrap-t. Reabsorb both fixed effects
# after multiplying null residuals by parent-level Rademacher signs.
audit_parent_bootstrap <- function(d, fit, draws=999L, seed=120312L) {
  x <- demean_two_way(as.matrix(d[c("tau",audit_controls)]),d$pair_id,d$year)
  y <- demean_two_way(as.matrix(d["log_profit"]),d$pair_id,d$year)[,1]
  null_residual <- qr.resid(qr(x[,-1]),y)
  bread_row <- drop(x %*% solve(crossprod(x))[,1])
  g <- factor(d$parent)
  G <- nlevels(g)
  correction <- G/(G-1)*(nrow(d)-1)/fit$df_resid_full
  statistic <- function(response) {
    full <- lm.fit(x,response)
    scores <- rowsum(full$residuals*bread_row,g)
    full$coefficients[1]/sqrt(correction*sum(scores^2))
  }
  observed <- statistic(y)
  # Each column is one cluster's restricted residual contribution. Both FE
  # projection and unrestricted residualisation are linear in these columns.
  contributions <- model.matrix(~g-1)*null_residual
  projected <- demean_two_way(contributions,d$pair_id,d$year)
  residuals <- qr.resid(qr(x),projected)
  scores <- rowsum(residuals*bread_row,g)
  coefficients <- drop(crossprod(bread_row,projected))
  signs <- withr::with_seed(seed,matrix(sample(c(-1,1),G*draws,replace=TRUE),G))
  t_draws <- drop(crossprod(coefficients,signs))/sqrt(correction*colSums((scores%*%signs)^2))
  data.frame(null=0,cluster="parent",clusters=G,draws,seed,observed,
    p=(1+sum(abs(t_draws)>=abs(observed)))/(draws+1))
}

manual_covariance_audit <- function(fit) {
  d <- fit$model_data
  x <- demean_two_way(as.matrix(d[fit$x_cols]),d$pair_id,d$year)
  scores <- x*fit$residuals
  bread <- solve(crossprod(x))
  vs <- list(hetero=bread %*% crossprod(scores) %*% bread * nrow(d)/fit$df_resid_full,
    parent=cluster_vcov(x,fit$residuals,d$parent,fit$df_resid_full),
    affiliate=fit$vcov,two_way=fit$vcov_two_way)
  bind_rows(lapply(names(vs),function(method) {
    v <- vs[[method]]
    df <- switch(method,hetero=fit$df_resid_full,parent=fit$n_parents-1,
      affiliate=fit$n_affiliates-1,two_way=min(fit$n_affiliates,fit$n_parents)-1)
    se <- sqrt(ifelse(diag(v)>=0,diag(v),NA_real_))
    data.frame(form=fit$model_spec,method,term=fit$x_cols,estimate=unname(fit$coefficients),
      se,p=2*pt(-abs(fit$coefficients/se),df),df,df_res=fit$df_resid_full,
      rank=fit$k_total,eigenvalues=paste(format(eigen(v,symmetric=TRUE)$values,digits=17),collapse=" "))
  }))
}

run_inference_audit <- function(input_root, output) {
  input_root <- normalizePath(input_root,mustWork=TRUE)
  processed <- file.path(input_root,"data","processed")
  dest <- file.path(normalizePath(dirname(output),mustWork=TRUE),basename(output))
  protected <- normalizePath(c(processed,file.path(GMT_PROJECT_ROOT,"data","processed")),mustWork=TRUE)
  stopifnot(!file.exists(dest),!basename(dest) %in% c(".",".."),
    !any(startsWith(dest,paste0(protected,"/"))))
  read <- function(name) readRDS(file.path(processed,paste0(name,".rds")))
  base <- read("base_panel")
  d <- prepare_estimation_sample(base,etr_forward=read("etr_forward"))
  fits <- estimate_stage3_models(d)
  iv <- build_tax_endogeneity_diagnostics(d)
  stopifnot(identical(d,read("stage3_estimation_sample")),identical(iv,read("stage3_tax_endogeneity_diagnostics")),
    identical(stage3_semielasticity_schedule(fits),read("stage3_semielasticity_schedule")))
  ledger <- withr::with_envvar(c(GMT_OUTPUT_ROOT=input_root), {
    engine <- new.env()
    source(file.path(GMT_PROJECT_ROOT,"code","09_econometric_and_reallocation_extensions.R"), local=engine)
    engine$audit_division_bias(d,base)
  })
  offset <- fits$logarithmic$t0
  inputs <- build_division_bias_inputs(d,base)
  # The matrix inventory records each repair beside its unrepaired spectrum.
  repair_warnings <- 0L
  stage9 <- withCallingHandlers(audit_division_covariance(inputs,ledger,offset), warning=function(w) {
    if (grepl("VCOV matrix is not positive definite",conditionMessage(w),fixed=TRUE)) {
      repair_warnings <<- repair_warnings+1L
      invokeRestart("muffleWarning")
    }
  })
  activity <- diagnose_stage8_activity_vcov(processed)
  key <- c("parent","affiliate","year")
  shares <- activity$effects$term
  driver <- activity$sample_keys |> left_join(select(base,all_of(c(key,shares,"entities_count_panelai"))),by=key) |>
    mutate(across(all_of(shares),~.x/entities_count_panelai)) |>
    left_join(select(read("stage1_bilateral_panel"),all_of(key),l3=stage1_distributional_liability_rate),by=key)
  driver_fit <- fixest::feols(as.formula(activity$sample$formula), driver,vcov=~parent+affiliate,nthreads=1)
  stage8 <- audit_fit_covariance(driver_fit, driver, "stage08",shares)
  instruments <- c(statutory="affiliate_cit_rate_unit_lag1",eatr="affiliate_simulated_eatr_unit")
  membership <- d[key]
  for (i in names(instruments)) membership[[i]] <- is.finite(d[[instruments[i]]])
  membership$common <- membership$statutory & membership$eatr
  stopifnot(behavioural_specification()=="NO_NOTCH_STANDARD_RESPONSE",
    !anyDuplicated(membership[key]))
  results <- list()
  distributions <- list()
  for (i in names(instruments)) for (support in c("available","common")) {
    rows <- if(support=="common") membership$common else membership[[i]]
    s <- d[rows,]
    label <- paste(i,support,sep="_")
    results[[label]] <- audit_iv(s,unname(instruments[i]),preferred=applied_preferred_beta(NULL,processed))
    distributions[[label]] <- bind_rows(lapply(c("log_profit","tau",audit_controls),function(k)
      data.frame(variable=k,mean=mean(s[[k]]),sd=sd(s[[k]]),min=min(s[[k]]),max=max(s[[k]]))))
  }
  combine <- function(k) bind_rows(lapply(results,`[[`,k),.id="design")
  choices <- filter(ledger,sample=="available",activity=="current",bic_winner,statistic_type=="coefficient",
    estimator=="fe_ppml_positive",regressor %in% c("lagged_etr","jackknife_etr","current_etr"))
  scenarios <- bind_rows(data.frame(case=c("zero","preferred","positive_statutory"),
    form="linear",b3=c(0,applied_preferred_beta(NULL,processed),results$statutory_available$iv$second),b4=NA_real_,t0=NA_real_),
    choices |> group_by(regressor,model_spec) |> summarise(b3=estimate[match("tau",term)],
      b4=estimate[match(if(first(model_spec)=="quadratic") "tau_sq" else "log_tau",term)],
      t0=first(log_t0),.groups="drop") |> rename(case=regressor,form=model_spec))
  fiscal <- audit_fiscal(read("stage3_factorial_pair_year"),read("stage1_affiliate_year"),
    read_stage4_utpr_weights(processed),scenarios)
  tail <- filter(d,tau<.05)
  concentration <- bind_rows(lapply(c("parent","affiliate"),function(k)
    transmute(tail,group=k,code=.data[[k]],analysis_profit_base) |>
      summarise(rows=n(),profit=sum(analysis_profit_base),.by=c(group,code))))
  within <- d |> group_by(parent,affiliate) |> summarise(n=n(),tail_rows=sum(tau<.05),
    sd_tau=sd(tau),range_tau=diff(range(tau)),.groups="drop")
  preferred <- fits$linear
  x <- demean_two_way(as.matrix(d[preferred$x_cols]),d$pair_id,d$year)
  leverage <- rowSums(qr.Q(qr(x))^2)
  contribution <- drop(x %*% solve(crossprod(x))[,match("tau",preferred$x_cols)])*preferred$residuals
  influence_cells <- mutate(d[key],leverage, slope_score=contribution) |> arrange(desc(abs(slope_score))) |> head(100)
  outputs <- c(stage9,list(parent_bootstrap=audit_parent_bootstrap(d,preferred),influence_cells=influence_cells,
    manual_covariance=bind_rows(lapply(fits[c("linear","quadratic","logarithmic")],manual_covariance_audit)), stage8=stage8,stage8_effects=activity$effects,stage8_eigen=activity$eigenvalues,
    stage8_negative_direction=data.frame(term=shares,loading=eigen(activity$covariance$raw,symmetric=TRUE)$vectors[,length(shares)]),
    original_iv=iv,iv=combine("iv"),ar_sets=combine("intervals"),ar_tests=combine("nulls"),
    membership=membership,distributions=bind_rows(distributions,.id="design"),
    matched_derivatives=filter(ledger,bic_winner,statistic_type=="semi_elasticity",tau_eval==.05),
    tail_concentration=concentration,within_pair=within,influence=audit_influence(d),
    response_curves=stage3_semielasticity_schedule(fits),scenarios=scenarios,fiscal=fiscal,
    environment=data.frame(R=as.character(getRversion()),fixest=as.character(utils::packageVersion("fixest")),
      stage9_repair_warnings=repair_warnings,bootstrap_seed=120312L,bootstrap_workers=1L)))
  stopifnot(dir.create(dest))
  for (k in names(outputs)) {
    if (k %in% c("fit_membership","covariance","membership")) {
      saveRDS(outputs[[k]],file.path(dest,paste0(k,".rds")),version=3)
    } else readr::write_csv(outputs[[k]],file.path(dest,paste0(k,".csv")))
  }
}

if (is_direct_script_run("code/diagnostics/behaviour_inference_audit.R")) {
  args <- commandArgs(trailingOnly=TRUE)
  stopifnot(length(args)==2L)
  run_inference_audit(args[1],args[2])
}
