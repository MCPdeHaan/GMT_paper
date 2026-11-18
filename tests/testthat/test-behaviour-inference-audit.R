inference_audit <- source_pipeline("diagnostics/behaviour_inference_audit.R", new.env())

test_that("AR inversion keeps both tails and explicitly handles undefined variance", {
  intervals <- inference_audit$ar_intervals
  strong <- intervals(0, 3, diag(2), 2)
  expect_equal(strong$lower, -2/sqrt(5))
  expect_equal(strong$upper, 2/sqrt(5))
  weak <- intervals(0, .25, diag(2), 2)
  expect_equal(c(weak$lower,weak$upper), c(-Inf,Inf))
  irrelevant <- intervals(0, 0, diag(2), 2)
  expect_identical(weak, irrelevant)
  split <- intervals(3, 0, diag(2), 2)
  expect_equal(split$lower, c(-Inf,sqrt(5)/2))
  expect_equal(split$upper, c(-sqrt(5)/2,Inf))
  expect_equal(intervals(1,2,diag(c(1,-1)),2)$status, "undefined covariance")
  expect_equal(intervals(1,2,diag(c(1,0)),2)$status, "undefined covariance")
})

test_that("AR null regressions agree with explicit dummy OLS and clustered sandwich", {
  withr::local_seed(41207)
  d <- expand.grid(parent=letters[1:9],affiliate=LETTERS[1:8],year=2017:2022)
  d$pair_id <- interaction(d$parent,d$affiliate)
  n <- nrow(d)
  d$control <- rnorm(n)
  d$z <- rnorm(n)
  shock <- rnorm(n)*(1+abs(d$z)) + rnorm(54)[interaction(d$parent,d$year)] +
    rnorm(48)[interaction(d$affiliate,d$year)]
  for (strength in c(.02,2)) for (slope in c(-2,0,2)) {
    d$tau <- strength*d$z + shock + d$control + rnorm(n)
    d$log_profit <- slope*d$tau + shock + rnorm(n)
    fit <- inference_audit$audit_iv(d,"z","control")
    expect_equal(fit$iv$n,n)
    expect_equal(fit$iv$df,7)
    for (i in c(1L,2L,3L)) {
      null <- fit$nulls$beta[i]
      manual <- lm(I(log_profit-null*tau)~z+control+pair_id+factor(year),d)
      v <- sandwich::vcovCL(manual, cluster=d[c("parent","affiliate")], type="HC1")
      expect_equal(fit$nulls$variance[i], unname(v["z","z"]), tolerance=1e-8)
      if (v["z","z"]>0)
        expect_equal(fit$nulls$p[i],unname(2*pt(-abs(coef(manual)["z"])/sqrt(v["z","z"]),7)),tolerance=1e-8)
    }
    # Under IID errors the exact single-exclusion AR F equals the squared t.
    iid <- lm(I(log_profit-slope*tau)~z+control+pair_id+factor(year),d)
    mv <- lm(cbind(log_profit,tau)~z+control+pair_id+factor(year),d)
    omega <- crossprod(resid(mv))/df.residual(mv) * summary(iid)$cov.unscaled["z","z"]
    cutoff <- qt(.975,df.residual(mv))
    ci <- inference_audit$ar_intervals(coef(mv)["z",1],coef(mv)["z",2],omega,cutoff)
    accepted <- any(ci$lower<=slope & ci$upper>=slope)
    f <- anova(update(iid,.~.-z),iid)$F[2]
    expect_identical(accepted,unname(f<=cutoff^2))
    expect_equal(f,unname(coef(summary(iid))["z",3]^2))
  }
  irrelevant <- d
  irrelevant$tau <- resid(lm(tau~z+control+pair_id+factor(year),d))
  null_stage <- inference_audit$audit_iv(irrelevant,"z","control")
  expect_true(is.na(null_stage$iv$second))
  expect_lt(abs(null_stage$iv$fs),1e-10)
  expect_true(any(is.infinite(null_stage$intervals$lower) | is.infinite(null_stage$intervals$upper)))
  expect_error(inference_audit$audit_iv(transform(d,z=control),"z","control"),"within variation")
  expect_error(inference_audit$audit_iv(transform(d,z=NA_real_),"z","control"),"finite")
})

test_that("frozen exposure and inference comparators retain their different units", {
  x <- readRDS(processed_path("stage3_model_coefficients.rds"))
  k <- subset(x,model_spec=="linear" & term=="tau" & inference=="parent_affiliate_clustered")
  expect_equal(k$estimate,-1.4651183078485985,tolerance=1e-12)
  expect_equal(k$std_error,.24295005765434916,tolerance=1e-12)
  iv <- readRDS(processed_path("stage3_tax_endogeneity_diagnostics.rds"))
  fs <- subset(iv, inference=="parent_affiliate_clustered" & grepl("first_stage",model_spec))
  expect_equal(sort(fs$f_statistic),c(2.088326,10.812194),tolerance=1e-6)
})

test_that("R12c compares the same final rows and reconciles both fiscal prices", {
  evidence <- function(file) repo_path("docs","refactoring","r12c",file)
  members <- readRDS(evidence("membership.rds"))
  ledger <- read.csv(evidence("iv.csv"))
  expect_identical(members$common,members$statutory & members$eatr)
  expect_false(anyDuplicated(members[c("parent","affiliate","year")]) > 0)
  expect_equal(ledger$n[grepl("common",ledger$design)],rep(sum(members$common),2))
  expect_equal(ledger$second,ledger$rf/ledger$fs,tolerance=1e-9)
  expect_equal(ledger$squared_t,(ledger$fs/ledger$fs_se)^2,tolerance=1e-10)
  f <- read.csv(evidence("fiscal.csv"))
  expect_equal(f$assigned_topup,f$qdmtt+f$iir+f$utpr)
  expect_equal(f$net_fiscal,f$standard-f$source_loss-f$topup_foregone)
  expect_equal(f$net_fiscal_historical,f$historical-f$source_loss-f$topup_foregone)
  expect_equal(f$net_fiscal[f$case=="positive_statutory"],c(0,0))
  expect_equal(f$source_profit[f$scope=="Global"],f$profit_received[f$scope=="Global"])
  expect_equal(subset(f,scope=="EU27" & case=="preferred")$net_fiscal/1e9,17.573779048,tolerance=1e-9)
  expect_error(inference_audit$run_inference_audit(repo_root,processed_path("forbidden-r12c")))
})
