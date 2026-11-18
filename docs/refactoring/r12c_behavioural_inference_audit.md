# R12c. Behavioural identification and fiscal incidence

**Decision. Retain −1.4651183078485985 as the signed conditional response parameter for R11c.** The negative within-pair association survives alternative dependence assumptions and deletion of individual jurisdictions or years. Neither instrument establishes its causal magnitude or even its sign. Give the lagged and other-parent sensitivities more prominence, and state the destination-price dependency wherever the paper reports a positive fiscal effect. The evidence supports a bounded interpretation and metadata edit followed by R13. It supplies insufficient grounds for an R12d replacement coefficient.

## What enters the estimates

The original sample consists of profitable parent–affiliate cells with positive assets, payroll, host GDP per capita and population, a usable accrued-tax ETR and at least two years per pair before the IV restriction. Stage 05 prepares and winsorises the ETR, then fits log profit on the ETR, log assets, log payroll, log host GDP per capita and log population, absorbing pair and observation-year effects. All three functional forms use the same 10,611 observations and 2,031 pairs. The manual fit retains observations that cease to supply within-pair variation after restriction. The historical FE rank convention counts pairs plus years minus one. The linear fit uses 2,042 parameters and 8,569 residual degrees of freedom.

| Object | Empirical use |
|---|---|
| Stage 05 manual fits, model comparison and Wald tests | Appendix behavioural regression, model-selection, tax coefficient and specification-test tables. BIC selects the linear form on the baseline sample. |
| Stage 05 fitted curves and lower-tail support | Semi-elasticity table and figure, appendix tail and robustness tables. The log model selects its offset by a grid search. |
| Stage 05 manual instrument diagnostics | Appendix IV table. Each first stage regresses the CbCR ETR on the excluded instrument and all included controls. The reduced form uses log profit. |
| Stage 09 WLS, OLS and PPML | Division-bias discussion and robustness diagnostics. WLS weights observations by pair mean profit. PPML models profit levels. The positive-sample comparison and the wider Stage 05 nonnegative-profit PPML have different support. |
| Stage 08 business-activity fit | Separate affiliate and year effects in the diagnostic. The displayed appendix panel uses affiliate-year effects. Stage 04 H5 has a different outcome/model. |
| Stage 05 applied coefficient, Stage 11 draws | The versioned rate metadata supplies the applied linear coefficient. Stage 05 applies the bounded integrated response. Stage 11 samples a normal signed slope centred on the applied value with the fitted two-way SE. Destination and collector accounting then follow R12b. |

The refitted original coefficient, schedule and instrument tables match their frozen R objects. The [R12a comparator](r12a_behaviour_estimation_response.md) records the full specifications and the [R12b contracts](r12b_fiscal_destination_methods.md) document source, destination and collector accounting.

## Dependence and covariance repair

For the preferred slope the heteroskedasticity-robust, parent-only, affiliate-only and two-way SEs are 0.13917, 0.23019, 0.19107 and 0.24295006. The primary two-way p-value is 0.000000242. The manual covariance adds the parent and affiliate score meats and subtracts their intersection. Each component uses its own G/(G−1) times (N−1)/(N−K), including FE rank in K. The two-way test uses 47 degrees of freedom from 48 parents and 153 affiliates. Precision is conditional on adequate cluster asymptotics and the regression's exogeneity assumptions. A restricted parent-cluster bootstrap-t for a zero slope gives p = 0.001 with 999 Rademacher draws, seed 120312. Its resolution is 0.001. This bootstrap addresses the parent-only null, without supplying a two-way bootstrap or a multiway CR2/CR3 result. It permits within-parent dependence and assumes independent parents. The multiway covariance addresses dependence shared across parents in the same affiliate. [Manual covariance ledger](r12c/manual_covariance.csv) · [Parent-only bootstrap](r12c/parent_bootstrap.csv) · [Cameron, Gelbach and Miller](https://cameron.econ.ucdavis.edu/research/JBESpaper2009version.pdf) · [Cameron and Miller](https://cameron.econ.ucdavis.edu/research/Cameron_Miller_Cluster_Robust_October152013.pdf).

Stage 08 reproduces 2,689 rows, 40 parents, 27 affiliates and 26 two-way test degrees of freedom. One of five eigenvalues is negative, −6.5585×10⁻⁷. Its normalised direction loads mainly on holding (+0.832), R&D (−0.475) and manufacturing (−0.235). Spectral repair lifts that eigenvalue to about 10⁻¹⁶. Holding's coefficient is +0.005204. Its SE increases 4.35%, from 0.002261 to 0.002359. The raw and repaired p-values are 0.02959 and 0.03641, or 0.11837 and 0.14563 after Holm correction. Holding's parent-only and affiliate-only p-values are 0.0642 and 0.0846. Thus dependence assumptions change the nominal 5% decision more than the numerical repair does. No Holm-adjusted holding result crosses 5%. Repair regularises inference for a fixed estimate. [Stage 08 term comparison](r12c/stage8_effects.csv) · [Directional clustering](r12c/stage8.csv).

Stage 09's 279 labelled designs correspond to 216 distinct fits after matching the actual design, estimator, weights and ordered observations. Of 49 flagged entries, 38 unique fits have indefinite raw two-way covariances across eight of ten distinct fitted observation sets. The Stage 09 fits use fixest 0.14.2, full FE parameter counting and conventional component-specific cluster corrections. The ledger also records supplied versus fitted membership and test degrees of freedom. Materiality here means reversal of a 5% tax-term or joint-tax decision, or an undefined tax test becoming defined. **Zero of the 38** meet that criterion. The largest tax-term change in p is 0.0000151. The largest joint-test change is 0.00251, for the logarithmic statutory-rate PPML design (0.21729 to 0.21980). None of the six available-sample BIC winners behind the quoted current, lagged and jackknife WLS/PPML derivatives are flagged. Near-zero eigenvalues after repair can retain floating-point signs. [Display-to-fit mapping](r12c/displays.csv) · [Covariances, spectra and tests](r12c/covariance.rds) · [Fitted sample keys](r12c/fit_membership.rds).

## Instrument comparison and weak-IV inference

Both instruments use identical controls and fixed effects. The 8,530-row intersection spans 1,578 pairs, 47 parents, 88 affiliates and FY2017–2023. Requiring EATR removes 1,073 rows from statutory support. Requiring lagged statutory CIT removes 290 from EATR support. The intersection has the same 8,530 rows before and after FE/rank checks. None of the three IV observation sets contains a singleton pair. Both second stages retain exactly the common keys. The membership and distribution ledgers permit country, year and regressor-composition checks. [Membership](r12c/membership.rds) · [Outcome and controls](r12c/distributions.csv).

| Instrument and support | N | First-stage slope (SE) | Squared t | Partial R² | Reduced form | 2SLS (SE) | 95% AR set |
|---|---:|---:|---:|---:|---:|---:|---|
| Lagged statutory, available | 9,603 | 0.1498 (0.1036) | 2.088 | 0.00116 | 0.0498 | 0.332 (3.351) | (−∞, −11.174] ∪ [−3.879, ∞) |
| Lagged statutory, common | 8,530 | 0.1522 (0.1086) | 1.963 | 0.00125 | −0.0974 | −0.640 (2.009) | (−∞, −8.252] ∪ [−2.658, ∞) |
| Simulated EATR, available | 8,820 | 0.2640 (0.0803) | 10.812 | 0.00320 | −0.5927 | −2.245 (1.556) | [−5.820, 2.146] |
| Simulated EATR, common | 8,530 | 0.2610 (0.0812) | 10.319 | 0.00324 | −0.5803 | −2.224 (1.576) | [−5.776, 2.441] |

Sample selection alone reverses the statutory reduced form and IV point sign. On identical observations EATR retains greater first-stage relevance, yet its AR set includes economically substantial slopes of both signs. All four sets include zero and the preferred conditional slope. The first-stage statistic is the historical clustered squared t. We do not assign a generic threshold of ten or report a separately calibrated effective-F bias test. Such a decision needs a stated bias criterion, a compatible long-run covariance and matching critical values. [Original stage estimates](r12c/original_iv.csv) · [Partial R², reduced-form inference and conventional intervals](r12c/iv.csv) · [Montiel Olea and Pflueger](https://joseluismontielolea.com/Montiel-OleaJBES.pdf).

For each proposed slope b, AR regresses log profit minus b times the ETR on the excluded instrument, controls and the same fixed effects. The resulting instrument coefficient is RF − b FS. The variance is the quadratic form of the jointly estimated RF/FS two-way score covariance. Inversion against the squared 97.5% t critical value, with the smaller cluster count minus one degrees of freedom, solves a quadratic inequality on the entire real line. This removes any grid endpoint or unresolved tail. It is an approximate cluster calibration. Instrument exogeneity is still required. The code flags a non-positive joint covariance as undefined and preserves disconnected and unbounded sets. Tests independently compare against explicit dummy regressions and sandwich cluster scores. [Candidate null tests](r12c/ar_tests.csv) · [Confidence sets](r12c/ar_sets.csv) · [Andrews, Stock and Sun](https://doi.org/10.1146/annurev-economics-080218-025643).

## Identification and external validity

| Mechanism | Observations and estimand | Limitation for interpretation |
|---|---|---|
| Current ETR | Bilateral accrued taxes, profits and activity yield a conditional FE association | A profit shock moves the denominator and the outcome simultaneously. Reverse causality, measurement error and changing composition survive FE absorption. |
| Lagged ETR | Previous-year measured taxes and profit predict current profit | Lagging removes the contemporaneous denominator link. Persistent shocks, anticipation and attenuation remain. |
| Jackknife | Other parents' host-year taxes and profits proxy tax exposure | Removing the focal parent breaks own-cell arithmetic. Common host shocks and changing donor composition can move both exposure and outcome. |
| Lagged standard-combined statutory CIT | National policy-rate variation predicts measured ETR | Anticipation, simultaneous base reforms and host shocks can affect location and accrued taxes directly. Legal rates and marginal effective rates can diverge. |
| Simulated fixed-project EATR | A common hypothetical project generates tax-system variation | Incentives can directly affect investment, capital, labour and location. Actual affiliates have different projects. Host-specific reforms can jointly determine EATR and reported profits. |
| Response | Fitted historical curve integrated from a low ETR to 15%, bounded to [0,1] | Aggregate pre-reform associations supply a conditional counterfactual. The public panel cannot recover post-GMT structural adjustments. |
| Destination | Rule B assigns marginal profit using observed activity, rates and fallback | Destination flows are unobserved. Routing support establishes feasibility within the model. |
| Fiscal incidence | Source amounts, collector rules and two marginal-price proxies yield tax changes | Destination assignment and the relevant marginal CIT price are assumptions. The resulting fiscal balance is a revenue simulation. |

The panel can test relevance, reduced forms, support, concentration and dependence sensitivity. Neither instrument supplies variation demonstrably excluded from the profit equation. Pair FE absorb time-invariant location differences and year FE absorb common calendar shocks. Host-year shocks remain. Conditioning on current activity may itself condition on responses to tax policy. First-stage strength, a small reduced form and an imprecise second stage cannot validate exclusion.

On available support the BIC-selected WLS/PPML semi-elasticities at 5% are 11.195/9.333 for current ETR, 0.602/0.335 for lagged ETR and 3.194/2.514 for the other-parent ETR. On the 8,584 fitted lagged observations the current pair is 11.873/9.941. On the 10,430 fitted jackknife observations it is 11.196/9.331. Foreign-only donor derivatives are 3.243/3.575. For lagged ETR, switching current to lagged activity on its own matched sample moves WLS from 0.626 to 0.529. Most of the attenuation in the principal comparisons survives holding observation membership fixed. A causal decomposition into division bias, measurement error, persistence and regressor/form changes is unavailable. These numbers are local derivatives of selected curves. [Matched designs and lagged controls](r12c/matched_derivatives.csv).

Below 5% there are 1,819 observations (17.14%), 9.27% of sample profit, 804 pairs and 672 switching pairs. US parents account for US$1.206tn of the US$3.632tn tail. UK affiliates account for US$0.469tn. Median within-pair ETR SD among pairs ever in the tail is 0.0678, compared with 0.0596 overall. Variation across the whole pair history does not identify a slope local to its below-5% observations. Weighting that tail to half the sample reduces effective N to 6,029 and lacks an identified selection probability. [Tail concentration](r12c/tail_concentration.csv) · [Within-pair support](r12c/within_pair.csv).

Removing one parent gives slopes from −1.607 (omit Romania) to −1.366 (omit China). Affiliate deletions span −1.512 to −1.409, and year deletions −1.545 to −1.379. The Cayman Islands–Kenya 2021 cell has the largest absolute within-regression slope-score contribution. Using the selected sample before winsorisation gives −1.381, bounding its ETR to [0,1] gives −1.389, dropping extreme profits gives −1.446 and dropping extreme activity gives −1.456. These are descriptive influence checks. At 5%, the linear, quadratic and logarithmic models imply derivatives in semi-elasticity units of 1.465, 1.769 and 2.097, and relocation shares of 13.63%, 15.69% and 16.83%. The forms converge at the 15% policy boundary in their implied relocation. Low-tail curvature remains sensitive to form and weighting. [Group deletions](r12c/influence.csv) · [Cell scores](r12c/influence_cells.csv) · [Integrated fitted curves](r12c/response_curves.csv).

## Conditional fiscal sign

FY2017–2023, preferred SbS, EU27, US$bn. Each alternative uses exactly the same source keys, exposure gate, recipient rules and same-year prices. The three PPML cases use their BIC-selected positive-profit specifications and integrate their full fitted functions. The historical-price column reprices the same routed profit. Foregone top-up is measured against zero relocation.

| Response | EU source profit relocated | Assigned top-up | Top-up forgone | Gross destination CIT | Source CIT loss | Net fiscal, standard price | Net fiscal, historical price |
|---|---:|---:|---:|---:|---:|---:|---:|
| Zero | 0 | 429.365 | 0 | 0 | 0 | 0 | 0 |
| Lagged ETR, quadratic | 175.071 | 404.995 | 24.370 | 39.947 | 7.581 | +7.996 | −5.096 |
| Preferred linear | 433.284 | 367.670 | 61.695 | 96.390 | 17.122 | +17.574 | −14.092 |
| Jackknife ETR, logarithmic | 454.365 | 362.170 | 67.195 | 96.261 | 15.009 | +14.057 | −17.705 |
| Current ETR, logarithmic | 1,552.557 | 207.802 | 221.563 | 345.199 | 60.711 | +62.926 | −50.503 |
| Positive statutory IV point | 0 | 429.365 | 0 | 0 | 0 | 0 | 0 |

Preferred foregone EU27 receipts comprise US$46.994bn QDMTT, US$5.205bn IIR and US$9.496bn assigned UTPR. Standard-price net ordinary CIT is US$79.269bn. Globally, the preferred case reallocates US$1,636.228bn of profit and assigns US$1,031.779bn of top-up to collectors. Global unsupported source liability falls from US$1.321bn in the zero case to US$1.152bn in the preferred case. All four nonzero cases have positive net revenue at the standard price and negative net revenue at the historical price. A change in curve changes which source cells contribute how much, even when the recipient rule is fixed. Repricing changes gross receipts on those same destinations without changing source losses or top-up. The positive statutory slope maps to zero under the original nonnegative relocation convention. Zero is a legitimate model case. The exercise does not identify a welfare gain. The ledger includes global totals, unsupported source liability, destination amounts and each channel. [Fiscal sensitivities](r12c/fiscal.csv) · [Fitted scenario parameters](r12c/scenarios.csv).

The Stage 11 normal slope draw approximates sampling variation conditional on the selected linear model, point estimate and two-way SE. It excludes weak identification, exclusion violations, model choice, post-GMT response changes and unobserved marginal destinations and prices. A finite normal approximation cannot represent the statutory instrument's disconnected unbounded AR set. Distinguish conditional parameter uncertainty from irreducible future outcome variation.

## Publication boundary and reproduction

The Stage 05 identification-design constructor describes an implemented upper-bound notch and a 2017–2022 panel. The historical diagnostic under `data/baseline_diagnostics/` contains both. The leading writer already replaces both notch fields before writing the CSV and RDS. Its continuous-mode output and the R10b continuous-mode archive describe the continuous response correctly. For a separately tracked metadata edit, use “The historical notch sensitivity extinguishes modelled liability in the specified band. The FY2017–2023 pre-reform data do not establish safe-harbour eligibility or post-reform bunching.” Replace “Identified as a reduced-form profit response” with “Conditional within-pair tax–profit association used to parameterise the response scenario.” In the paper qualify the fiscal sign by marginal price, narrow causal language about the division-bias magnitude, label Section 5.2's draws as estimation uncertainty and make Section 4.3's historical hypothetical SBTI capacity overlay explicit.

Use R 4.6.0 and the locked library, the five leading settings, `en_US.UTF-8` and the repository root. Each diagnostic run requires a new output directory. The original production routines and publication sources remain at the R12b revision.

```sh
Rscript --vanilla code/diagnostics/behaviour_inference_audit.R "$PWD" "$audit_a"
Rscript --vanilla code/diagnostics/behaviour_inference_audit.R "$PWD" "$audit_b"
diff -rq "$audit_a" "$audit_b"
Rscript --vanilla -e 'testthat::test_dir("tests/testthat",filter="behaviour-inference-audit")'
Rscript --vanilla tests/testthat.R
shasum -a 256 -c tests/step17_raw_inputs.sha256
shasum -a 256 -c tests/r05b_legal_inputs.sha256
Rscript --vanilla tests/verify_golden_step15.R "$PWD" r11c
Rscript --vanilla tests/verify_golden_step15.R "$PWD/data/baseline_r10b" r10b
```

### Acceptance record

The two independent executions of the final diagnostic produced 24 byte-identical files, including the sample membership, covariance objects, bootstrap, confidence sets and fiscal projections. The independent AR fixtures and fiscal checks passed 88 expectations. The full tracked suite passed 2,039 expectations with zero failures, warnings or skips. The diagnostic itself intentionally encounters covariance warnings when requesting the original fits and alternative matrices. The 114 recorded Stage 09 warning events arise from repeated covariance evaluations of the 38 affected fits.

All 54 pinned raw inputs and the independent legal register passed SHA-256. The legal register digest is `74f6da39591358c38b0d13521fba849eb8b41e358731a9c4706dd73ecf12e7aa`. Both processed path sets and all hashes passed. The R11c and R10b manifest digests are respectively `4aae84a52bb1a3c1ec53555ca172460f88242a220af698aa623087313b9482b9` and `8e6b003d37b1be305874d9445ce84ef9956c2e616e80b35bbfaefeb8460e57e4`. Git comparison against the starting revision found identical publication sources and exhibit inventory (81 TeX files and eight figure PDFs). Verification used fresh diagnostic calculations over the two previously verified scientific inventories, with R11c as the estimation and sensitivity input. A fifteen-stage replay and publication rebuild were unnecessary because the diagnostic has no production caller and the production dependencies and sources are identical.

Each positive Rule B source passes the existing source-level conservation check before channel aggregation. The extra diagnostic comparison of differently ordered global sums allows 128 machine epsilons times the total USD amount. The cent-scale aggregate roundoff on trillion-dollar scenarios is retained in the fiscal ledger. Stage 06 separately checks collector conservation, and unsupported pools recover their original source geography by joining on scenario, parent and year.
