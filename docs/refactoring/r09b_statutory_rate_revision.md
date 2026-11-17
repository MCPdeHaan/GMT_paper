# R09b role-specific statutory CIT rates

The comparison starts at `6a7d3d6716964b1473f5422ed911544336719018` on `publication-rework`. The analysis uses FY2017–2023 economic observations, with FY2016 available for controls and initial conditions. National UTPR applicability remains the R05b map for fiscal years beginning on 1 January 2026. The R06b continuous behavioural response and its applied linear coefficient carry forward.

## A. Rate definitions and provenance

The pinned OECD series are annual observations from `DSD_TAX_CIT@DF_CIT(2.0)`. The original digest is `4c5c0cd633207a20a5cbc4035d0852e8d505225de2b5d9b2d342a5ff3cfa9cac`. The source vintage was acquired on 12 November 2026. `cit_statutory_observations.rds` records the original area, normalised code, year, OECD series identifiers, observation status, recorded percentage, validity, fractional rate, dataflow and digest. Stage 01 carries the historical `cit_top_all` and `cit_standard` percentage aliases alongside the new fractional fields. Stage 02 attaches them independently by host and parent year. [R09a source audit and OECD dictionary](r09a_statutory_rate_audit.md#source-and-vintage).

| Field | OECD measure / sector / targeting |
|---|---|
| `cit_targeted_central` | `CIT / S1311 / TA`, central-government small-business rate |
| `cit_standard_central` | `CIT / S1311 / ST`, standard central-government rate |
| `cit_standard_combined` | `CIT_C / S13 / ST`, standard combined general-government rate |

The reader accepts finite values from 0 to 100 per cent and divides by 100 once. It records invalid values separately. The combined series already incorporates subcentral taxation as defined by the OECD. Each selection uses an exact jurisdiction-year key. An absent observation and an observed zero retain distinct representations. The pinned standard series have identical host-year support. The central fallback therefore adds no observed coverage to the 501 host-years missing the combined rate.

## B. Scientific decisions

| Role | Leading policy |
|---|---|
| Observed bilateral ETR and baseline regression ETR | Corrected tax-to-profit ratio and the independent R06b regression support and winsorisation |
| Mean and percentile conditioning | Standard combined, same-year standard central fallback, then a numerical ceiling of one; otherwise min(1, rate + 0.05) |
| Profit reconciliation prior | Historical targeted-first central covariate and historical numerical zero encoding inside the fit |
| Statutory robustness and IV | Standard combined on available observations; exactly the preceding observation year for the IV |
| Destination gate for A, B and C | Historical targeted-first central threshold; standard-combined threshold is a crossed sensitivity |
| Destination pricing for A, B and C | Standard combined with the same-year standard central fallback |
| Origin ordinary CIT loss | Effective low-tax rate on the displaced base; statutory origin pricing remains the R09a stress test |
| Numerator replacement and accounting | Same named statistical ceiling as production, with existing accounting rules and direct-measurement support |

The five-point allowance regularises measurements given accounting timing, losses and other differences between the numerator and denominator. It imposes no firm-level legal restriction and conditions the Beta's estimated knots and mean on its existing unit support. The standard headline is economically closer to a general marginal proxy and a statistical regulariser than the small-business rate. It still misses deductions, tax credits, loss positions and other firm-level policies.

The prior is predictive shrinkage. Its covariate can partly reflect incentives to use structures that generate mismeasured accounting profits, while the correction also depends on conditions that the headline rate does not identify. The 37 holdouts and the omit-covariate sensitivity give no empirical reason to replace the covariate as part of this revision. Keeping the gate holds the selection of high-tax destinations fixed with respect to the statutory-rate role, while permitting the ETR measurement revision itself to alter relative ETR eligibility. This choice isolates repricing from a model redesign of the destination set. The crossed table quantifies the alternative.

## C. Measurement, prior and behaviour

The bilateral panel retains all 20,111 ordered keys and adds 30 parent and affiliate rate-role columns, for 433 columns. Stage 01 records 7,360 eligible source observations across the three OECD series. Raw and corrected profit, the Stage 02a posterior, the raw ETR and the regression ETR match R06b. The regularised bilateral mean changes in 1,183 cells, of which 1,118 are in the analytical window. Among 1,503 host-years the ceiling changes in 145, the bounded mean in 52, and the production distributional low-tax share and gap in four. The host-level direct/fitted/transport source selection is identical. The 10,611 estimation observations retain their keys, profit outcome and baseline ETR.

The cap comparison holds the archived mean anchors and Table IV comparators fixed to isolate the conditioning of the knots. The 361 S1 observations span unmatched host-years, the 70 S2 observations restrict hosts to common parents, and the 81 S3 observations match bilateral cells. Positive-profit weights, low-rate performance, domestic and foreign splits, paired residuals, calibration and fit failures are retained in the candidate files. The production validation also recalculates the mean anchors. [Paired comparison](r09b/cap_validation_pairs.csv) · [Sample statistics](r09b/cap_validation_summary.csv) · [Subgroups](r09b/cap_validation_subgroups.csv).

| Cap | S1 liability MAE (pp) | S2 liability MAE (pp) | S3 liability MAE (pp) |
|---|---:|---:|---:|
| Historical | 3.155 | 1.738 | 1.842 |
| Standard + 0 pp | 3.180 | 1.863 | 1.847 |
| Standard + 5 pp | 3.102 | 1.849 | 1.799 |
| Standard + 10 pp | 3.091 | 1.917 | 1.803 |
| Unit only | 4.031 | 3.912 | 3.557 |

The zero-point arm has one explicit fit failure, for the Cayman Islands in FY2023, with a zero cap and a positive held mean. This occurs in the existing Beta routine at the predicted quantile evaluation. Its S1 summary uses 360 finite predictions and identifies the failed key. The five-point cap yields 229, 39 and 53 rank conflicts under the comparison's rank criterion, against 233, 39 and 55 in the historical arm. These checks use a different population and definition from the S10 point-anchor and rank conflict in the bilateral ladder. In the production bilateral ladder, each L4 definition retains 331 boundary cells and 40 conflicts, including 18 in the EU27. The affected positive profit stays at US$29.857bn globally and US$5.998bn in the EU27. Using the point share with the same source and conditional gap would add US$1.355bn and US$0.282bn of pre-SBIE liability, respectively. S10 remains open. S02's pooled Table IV support is unchanged. [Matched S10 exposure](r09b/s10_exposure.csv).

| Prior arm | Correction-rate MAE (pp) | RMSE (pp) | Profit-weighted MAE (pp) |
|---|---:|---:|---:|
| Historical | 11.691 | 13.118 | 13.445 |
| Standard combined-first | 11.780 | 13.250 | 13.974 |
| Standard central | 11.770 | 13.244 | 13.955 |
| Omit rate | 11.696 | 13.145 | 13.301 |
| Combined-first with weighted-mean encoding | 11.780 | 13.250 | 13.974 |

Weighted-mean encoding coincides with the historical encoding in the matched comparison because the selected parent-year covariates are supported. The counterfactual prior changes 376 posterior means and 325 domestic profit denominators, by a net −US$48.543bn over FY2016–2023. The direct evidence and observed adjustment rules stay fixed. The published alternative has the same posterior SDs and support classes; it moves predictions through the prior. Retaining the historical prior preserves the adopted posterior, corrected domestic profit, raw ETR and the leading regression sample and coefficient. [Holdout rows](r09b/prior_holdout.csv) · [Matched posterior support and prior predictions](r09b/prior_estimates.csv) · [R09a denominator, support and regression contrasts](r09a_statutory_rate_audit.md).

For the exact-lag statutory IV on the same 9,603 cells, the two-way first-stage statistic falls from 7.31 to 2.09 and the 2SLS estimate moves from −1.182 to +0.332 (p = 0.921). The simulated EATR first-stage statistic remains 10.81. The statutory IV supplies little sign information. The preferred linear ETR estimate and simulated EATR are unchanged. In the matched division-bias comparison the lagged bounded ETR changes because the statistical ceiling changes. Weighted lagged estimators now select quadratic forms and imply 5% semi-elasticities of 0.33–0.60, against 2.51–3.19 for the leave-one-parent-out logarithmic fits. The weighted lagged WLS tax terms are jointly significant at 5%. The estimates retain their existing non-causal interpretation. Weak-IV-robust inference and exclusion restrictions belong in R12.

## D. Source liability and collector receipts

The R09a joint arm changed both the prior and measurement. R09b holds the prior fixed. The cap-only, mean-only, and independent cap-plus-mean arms show why the preferred top-up receipts move far less than in the R09a joint simulation. The cap and mean effects are conditional on the other settings. A sequential allocation of the interaction depends on which change is applied first.

| Cumulative change against R06b, US$bn | EU27 Universal | EU27 SbS | Global Universal | Global SbS |
|---|---:|---:|---:|---:|
| Percentile cap only | +0.000716 | +0.000716 | +0.001361 | +0.001361 |
| Mean clipping only | −0.000023 | −0.000023 | −0.000058 | −0.000058 |
| Reconciliation prior only | −0.545851 | +0.038068 | −0.938195 | +0.087486 |
| Percentile cap and mean clipping | +0.000673 | +0.000673 | +0.001251 | +0.001251 |
| All three upstream changes, R09a joint shadow | −0.545178 | +0.038740 | −0.936944 | +0.088736 |

Adding mean clipping after the percentile cap changes EU27 preferred receipts by −US$0.043mn and global receipts by −US$0.110mn. The cap-by-mean interaction relative to the sum of their isolated effects is approximately −US$0.021mn for the EU27 and −US$0.053mn globally. Moving the prior last adds −US$545.851mn under Universal and +US$38.068mn under SbS for the EU27, at displayed precision. Repricing and eligibility affect only the ordinary-CIT ledger in these comparisons. [Reproduced cap-plus-mean arms by scenario, scope and channel](r09b/cap_and_mean_scenarios.csv) · [R09a isolated and joint alternatives](r09a/results/fiscal_scenarios.csv).

The independent re-execution of the R09a combined-first prior-only and joint candidates reproduced all 192 assigned-receipt values of each arm exactly from the archived CSV. The adopted percentile and mean changes reproduce the corresponding upstream shadow at the preferred point. The cumulative EU27 core range moves from US$159.82–670.67bn to US$159.75–670.67bn. The minimum is still `x01011` and the maximum is `x10100`. The measurement main effect and Shapley share in the pooled design are 68.76% and 71.96%. Changes at the bottom of the core range reflect the average-ETR treatment.

| Cumulative assigned receipts, US$bn | R06b | R09b | Change, US$mn |
|---|---:|---:|---:|
| EU27 Universal | 549.498288 | 549.498961 | +0.673 |
| EU27 SbS | 370.071508 | 370.072180 | +0.673 |
| Global Universal | 1,356.662470 | 1,356.663720 | +1.251 |
| Global SbS | 1,041.652867 | 1,041.654118 | +1.251 |

At each preferred regime, EU27 IIR changes by +US$0.100mn, UTPR by +US$0.573mn and QDMTT by zero. Globally the corresponding changes are +US$0.352mn, +US$0.899mn and zero. Cumulative unsupported UTPR is still US$1.816bn under both regimes. SbS extinguishes US$367.768bn at the preferred point. The largest absolute cumulative country changes include Switzerland (+US$0.250mn), Ireland (+US$0.220mn), Germany (+US$0.119mn) and Sweden (+US$0.099mn). The source and collector geographies remain separate. All three assigned channels are available by country and window. [Matched collector ledger](r09b/collector_comparison.csv).

## E. Ordinary CIT

The crossed sensitivity starts from the same revised ETRs, profit, behavioural response and source legal rules for every arm. The underlying 15% threshold comparison changes 44 host-years in FY2017–2023. Each destination rule has its own footprint and fallback. The legacy and standard gate use their respective rate only for the threshold, including the headquarters condition in Rule C. Both prices are independently joined at the destination-year. The origin effective loss is identical across all four arms and each rule. The comparison reports unpriced profit explicitly, with missing gross amounts where applicable. All selected profit is priceable in these runs. [Crossed country and regional ledgers](../../data/processed/diagnostics/step7_statutory_destination_gate_and_pricing.csv).

| Cumulative preferred SbS EU27 gross destination CIT, US$bn | A | B | C |
|---|---:|---:|---:|
| Historical gate and price | 67.923 | 65.269 | 71.254 |
| Historical gate, standard price | 99.624 | 97.227 | 107.354 |
| Standard gate, historical price | 65.600 | 62.355 | 66.431 |
| Standard gate and price | 96.935 | 93.591 | 100.673 |

With the adopted gate and price, Rule B assigns US$346.481bn of relocated profit to EU27 destinations and US$1,653.384bn globally in the preferred SbS case. EU27 and global gross CIT are US$97.227bn and US$438.725bn. Effective origin losses of US$17.117bn and US$73.115bn leave net ordinary CIT of US$80.109bn and US$365.610bn. The EU27 gross increase from repricing is US$31.958bn on the same routes. The alternative gate alone reduces EU27 gross CIT by US$2.914bn with historical pricing. Under standard pricing it reduces it by US$3.635bn. The interaction follows from assigning profit to different destinations and is distinct from the measurement effects on top-up.

Subtracting the approximately US$62.09bn decline in EU27 top-up relative to the mechanical scenario yields a positive net modelled fiscal change of about US$18.02bn under preferred Rule B. The corresponding R06b figure was −US$13.94bn. This sign change depends on the statutory marginal proxy. Gross destination tax, net ordinary CIT, and net fiscal change including top-up answer different questions. This ledger models hypothetical collection on relocated profit. The destination's marginal rate and the relocation itself are unobserved. The R09a statutory-origin stress prices US$329.424bn of global losses on supported origin flows, compared with US$73.115bn of global effective losses on all flows. The statutory price is missing for US$13.980bn of origin profit in that stress test. [Origin-price sensitivity and coverage](r09a_statutory_rate_audit.md#ordinary-cit-on-fixed-routes). The standalone Stage 05 global Rule A series remains a historical compatibility diagnostic. The published A/B/C comparison uses the Stage 09 parent-specific, formulary and headquarters definitions.

## F. Accounting and uncertainty

The ordinary-CIT pricing change does not enter the accounting factorial or the three parameter simulations. The revised cap enters the cash and envelope numerator variants at the bilateral and host-year measurement boundaries. The dividend-removal case, current and prior-year loss proxies, accrued/cash definitions, direct Table IV selection and transitional safe-harbour screens retain their existing definitions. The factorial treats accounting as an additional switch. It does not assign a probability to the accounting choices.

| Cumulative EU27 full accounting design, 2017–2023, US$bn | R06b range | R09b range | R06b preferred accounting | R09b preferred accounting |
|---|---:|---:|---:|---:|
| L3 | 62.52–670.67 | 62.50–670.67 | 231.13 | 231.14 |
| Strict L4 | 62.52–591.62 | 62.50–594.02 | 213.62 | 214.75 |

For cumulative L3, the ETR measurement and accounting Shapley shares move from 45.48% and 37.27% to 45.53% and 37.25%. Strict L4 moves from 42.56% and 41.63% to 42.28% and 41.96%. Total interaction shares in the two cumulative designs move from 8.85% and 8.06% to 8.85% and 8.13%, respectively. The pre-accounting preferred L3 estimate remains US$370.07bn to two decimal places. The strict bilateral design has greater exposure to the changed fits. With existing unadjusted profit and the preferred policy, the revised EU27 L3 receipts are US$370.07bn on accrual, US$326.26bn on cash and US$313.45bn on the envelope. Strict L4 gives US$330.94bn, US$339.21bn and US$305.74bn. Cash tax does not move both levels in the same direction, because it replaces the numerators in different matched measurement branches. [Full factorial, both estimands and windows](../../data/processed/diagnostics/step15_globe_accounting_factorial_anova.csv) · [Numerator comparison](../../data/processed/diagnostics/step12_tax_paid_vs_accrued_bridge.csv).

All three studies use 500 draws. Profit-only varies the correction posterior with ETRs, behaviour and routes held at the point outputs. ETR-only recalibrates the Stage 1 residuals and recomputes the core liability and response. Joint draws combine all three existing blocks, preserving common draws across scenarios.

| EU27 preferred interval, US$bn | Universal | SbS |
|---|---:|---:|
| Profit-only 95% | 527.96–567.10 | 361.12–375.02 |
| ETR-only 90% | 443.29–591.80 | 309.28–402.57 |

Over 2017–2023 the joint preferred SbS 90% interval is US$338.13–410.73bn. Parameter variance accounts for 1.65% of total variance. The scenario spread is 7.04 times the interval width. ETR residuals, the coefficient and the prior contribute 76.67%, 11.46% and 11.86% of parameter variance, respectively.

Over 2019–2023 the joint preferred SbS 90% interval is US$241.49–264.80bn. Parameter variance accounts for 0.41% of total variance. The scenario spread is 15.85 times the interval width. ETR residuals, the coefficient and the prior contribute 0.01%, 33.96% and 66.03% of parameter variance, respectively.

[Profit-only intervals](../../data/processed/diagnostics/step07a_profit_correction_final_revenue_interval.csv) · [ETR-only intervals](../../data/processed/diagnostics/step9_stage1_measurement_error_preferred_interval.csv) · [Joint variance and Member State intervals](../../data/processed/diagnostics/step15_law_of_total_variance_decomposition.csv).

## G. Repeal game and budgets

The game replays 216 QDMTT-only repeals and 216 full opt-outs, covering 27 Member States, two measurement levels, two regimes and two reporting windows. Full opt-out rebuilds the parent-year weights after excluding the deviator. The ordinary CIT carried by a payoff is the deviator's retained effective origin tax. The game has no destination pricing term. Its changes are driven by measured liability and retained profit. The adopted standard price operates separately in the Stage 09 fiscal ledger.

The 432 fiscal gain and tie classifications are unchanged. Universal QDMTT-only repeal yields no source tax relief. Across the 27 separate pooled SbS repeal cases, firms' cumulative modelled liability falls by US$100.15bn. The retained profit is US$159.29bn and its effective source CIT is US$6.22bn. The Irish US-parented relief efficiency remains 85.9% cumulatively and 87.0% in FY2023. A decline in assigned global receipts can also reflect additional unassigned liability. In the cumulative strict L4 SbS full-opt-out case, the simulated German domestic fiscal loss increases by US$1.364bn and foreign recapture increases by US$0.913bn. Host unsupported UTPR is unchanged across the game. These comparisons preserve the definition of the within-deviator ordinary source-tax payoff. [Game and source residuals](../../data/processed/diagnostics/step13_unilateral_qdmtt_deviation_matrix.csv).

The principal FY2023 comparisons still put four budget benchmarks inside the unrestricted core range and one inside the L3 range. The same policy-matched definitions and official amounts carry forward. Closest-case identifiers, scenario counts and overlap indicators all remain unchanged in the matched and unmatched ranges for both windows. Germany's FY2023 full-core minimum is €0.744bn, or €1.666bn in the pre-SbS policy-matched core. The latter exceeds its €1.000bn cash benchmark. Austria's pre-SbS core minimum remains about €0.150bn. With the accounting and legal-screen adjustments the preferred L3 FY2023 German, French and Irish gaps stay within €0.5bn. These comparisons depend on official channel definitions and the financial and policy window. [Full-core, L3 and policy-matched table](../../data/processed/diagnostics/step9_budget_benchmark_scenario_ranges_r04b.csv) · [Accounting waterfall and screen variants](../../data/processed/diagnostics/step12_cbcr_to_budget_waterfall_bridge.csv).

## H. Manuscript consequences

The paper's central comparison of ETR measurement, accounting and parameter uncertainty survives. The preferred top-up estimates and the main repeal conclusions are stable, while the strict bilateral accounting distribution is more sensitive. The statutory IV no longer reinforces the sign of the preferred response. Prior and price roles now have separate explanations. The country fiscal ledger and the conclusion distinguish the increase in gross destination CIT from origin losses and from the net fiscal change including top-up. The Dutch ordinary-CIT comparison becomes less close to the official forecasts under the standard price. The revised figures include France's bounded average ETR rather than omitting it at the previous 25% display limit. The existing literal citation defect is a separate editorial follow-up.

## I. Reproduction commands

Run from the repository root with the lockfile-matched library, R 4.6.0, a UTF-8 locale and the system dependencies in [REPLICATION.md](../../REPLICATION.md). Supply fresh absolute output directories. The reference is the pinned data vintage.

```sh
export LC_ALL=en_US.UTF-8 TZ=Europe/Amsterdam
export GMT_UTPR_SPECIFICATION=VERIFIED_PARENT_ONLY
export GMT_BEHAVIOURAL_SPECIFICATION=NO_NOTCH_STANDARD_RESPONSE
shasum -a 256 -c tests/step17_raw_inputs.sha256
shasum -a 256 -c tests/r05b_legal_inputs.sha256
GMT_STATUTORY_RATE_SPECIFICATION=LEGACY_TARGETED Rscript --vanilla run_all.R --output-root="$legacy"
GMT_STATUTORY_RATE_SPECIFICATION=STANDARD_ROLE_SPECIFIC Rscript --vanilla run_all.R --output-root="$leading"
Rscript --vanilla tests/verify_golden_step15.R "$legacy" r06b
Rscript --vanilla tests/verify_golden_step15.R "$leading" r09b
GMT_STATUTORY_RATE_SPECIFICATION=LEGACY_TARGETED GMT_TEST_OUTPUT_ROOT="$legacy" Rscript --vanilla tests/testthat.R
GMT_STATUTORY_RATE_SPECIFICATION=STANDARD_ROLE_SPECIFIC GMT_TEST_OUTPUT_ROOT="$leading" Rscript --vanilla tests/testthat.R
Rscript --vanilla tests/testthat.R
Rscript --vanilla code/diagnostics/statutory_rate_revision.R "$legacy/data/processed" "$diagnostics"
```

The diagnostics command expects a verified historical processed directory and a new destination. It repeats the R09a conditional prior-only and joint arms, the cap-plus-mean arm, the matched allowance grid and the held-out prior comparisons. Stage 09 independently publishes the four fiscal pricing and threshold arms on the leading base. Neither scientific configuration can reuse the historical Stage 1 cache. The Monte Carlo seeds and laws retain the previously documented design.

## Acceptance evidence

Both configurations completed all fifteen stages in separate fresh output roots. The 500 profit-only draws, 500 measurement-error draws and 500 joint draws ran in each. The continuous configuration bypasses the historical measurement-error cache in both profiles. The original terminal sessions stopped during Stage 07a before retaining any measurement-error results. The replay reran that stage with a scratch checkpoint scheduler around the existing draw evaluator. It kept the calibration, seed, per-draw computation, order of draw IDs and final aggregation. The checkpoint signatures included the R runtime, environment, inputs and source hashes, with the lockfile and UTPR weight inputs checked separately. All 13 historical measurement-error files reproduced exactly. Wall times include machine and session pauses and do not estimate uninterrupted runtime.

| Verification | Result |
|---|---|
| Original inputs and R05b register | 54 pinned raw inputs and the separate legal hash matched |
| R06b replay | Exact 364-file path set and SHA-256 inventory |
| R09b replay and checkout | Exact 367-file path set and SHA-256 inventory |
| Processed change inventory | 140 historical files byte-identical, 224 changed, two rate-provenance files and one crossed fiscal diagnostic added |
| Official designs | 32 core cases, 64 accounting cases in both L3 and strict L4, 216 repeals and 216 full opt-outs |
| Publication regeneration | 81 exact TeX fragments and eight figures after creation and modification timestamp normalisation, within each specification |
| Leading publication builds | 77-page paper and five-page research note; two independent builds agree in page streams, text, images and font resources |
| Historical publication builds | 76-page paper and five-page research note reproduce the archived page streams, text, images and font resources |

The historical manifest's SHA-256 is `a5f2c6127e127980c731fcddaff21e184e4aa4a5e1f124479ac46f97d4b63320`. The leading manifest's SHA-256 is `8b20e8daac06cdceb0ef983306b662831a0eee24dc324bdb6065199808eb4835`. [Historical freeze](../../tests/golden_r06b.csv) · [Leading freeze](../../tests/golden_r09b.csv) · [Expected changed and new file hashes](r09b/processed_file_changes.csv).

The named-rate changes account for the processed differences in measurement, the downstream model panels, diagnostics, fiscal ledgers and report inputs. Stage 02 sidecars, observed profit inputs, the reconciliation posterior and legal weight files retained their bytes. The active R09b cap test checks a versioned Stage 03 schema and its exact Stage 03 and 08 files. The original conditional cap audit still reproduces every one of its 1,743 records under R06b. The historical behavioural point comparison retains its existing tolerance. The leading shadow and replay agree on 128 matched FY2023 and cumulative EU27/Global scenario totals within US$0.004. The new comparison uses the existing US$0.001 annual allowance for summation and scales it by the number of summed years. The manifest tests compare production outputs by bytes.

The leading paper was checked visually at the revised measurement figure, tax-code diagnostic, fiscal and uncertainty passages, with rendered note pages checked separately. The final LaTeX logs have resolved citations and references and retain the existing underfull-box diagnostic. The separate literal citation defect remains open. A Git-only independent restore still requires the four exact companion extracts described in the replication guide.

The complete tracked suite passed 1,470 expectations in the leading checkout, 1,469 against its isolated replay and 1,464 against the historical replay. All three had zero failures, warnings and skips. The checkout includes the ordered-object comparison against the same-specification panel. The historical run exercises the full archived cap audit and behavioural point comparison.
