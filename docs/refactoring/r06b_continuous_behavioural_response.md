# R06b. Continuous behavioural response

## Scientific specification

R06b adopts `NO_NOTCH_STANDARD_RESPONSE` on the verified parent-year-only UTPR map. In a behavioural scenario, an observation with positive low-tax excess and post-substance liability keeps the modelled fraction `exp(beta × gap)` where the tax gap is positive and collection is active. The fitted linear slope is −1.4651183. The response in an exposed cell tends to zero as the low-tax ETR approaches 15%. It is bounded by the existing unit-interval cap. A host QDMTT retains collection exposure for an SbS-exempt parent. In the absence of QDMTT, SbS-exempt liability produces no relocation. Mechanical scenarios keep their entire input amount. The policy flags and weights affect collection through the existing waterfall. The response predicate is evaluated before checking collector support. A cell can remain exposed while its UTPR pool has no observed route.

The historical `BASELINE_NOTCH` mode sets the post-behaviour amount to zero throughout the half-open interval [13%, 15%) in behavioural scenarios and moves no profit within that interval. Under the verified 2026 policy map, total gross exposure to that assumption is US$39.455m in preferred L3, US$16.156bn in the corresponding L1 case and US$8.340bn with strict bilateral L4, cumulatively over 2017–2023. The historical specification and one- and three-point sensitivities are retained. The [R06a analysis](r06a_behavioural_notch.md#fiscal-results) also restores liability with the response held at zero within the former band. That adds US$16.744m to preferred EU27 SbS receipts. The difference relative to the adopted US$16.372m increase isolates the extra relocation response.

The permanent Simplified ETR Safe Harbour requires group-jurisdiction eligibility, simplified taxes and income, and an election. A fiscal year starting 1 January 2026 falls in the conditional early-application period. Stage 10's separate 2026 Transitional CbCR Safe Harbour screen uses public-data tests and can preserve QDMTT under a separate assumption. It reduces only remaining amounts. The SBTI capacity and SbS eligibility scenario stay distinct. The aggregate CbCR density cannot identify legal elections or a structural behavioural notch. The regression still has endogeneity and measurement concerns. Its fixed-effect estimate serves as a scenario parameter. [R06a legal and observability audit](r06a_safe_harbour_legal_audit.md) · [OECD January 2026 package](https://www.oecd.org/content/dam/oecd/en/topics/policy-sub-issues/global-minimum-tax/side-by-side-package.pdf).

One environment selector controls both the width chosen from the Stage 05 schedule and the default applied by the consumers that recompute it. Stage 05 retains [0, 0.01, 0.02, 0.03] as the available widths in leading runs. The historical path retains its original rows and order. Stage 07a's profit-only draw starts from the point's frozen filter. Measurement draws rebuild the schedule from their altered low-tax shares and gaps. The Stage 11 evaluator inherits the same domain rule without expanding collector routes per draw. Stage 05 writes the active leading choice and width. Stage 13 uses that file to render the response table and describes the stylised notch separately. Missing or non-finite numerical response inputs supply zero movement. Negative finite responses are bounded at zero.

## Source and collector results

Cumulative window amounts are nominal USD. Each cell reports revised US$bn and the increment over R05b in US$m in parentheses.

| CbCR window | EU27 Universal | EU27 SbS | Global Universal | Global SbS |
| --- | ---: | ---: | ---: | ---: |
| FY2023 | 68.760 (+0.852) | 42.535 (+0.852) | 192.524 (+1.453) | 147.388 (+1.453) |
| 2019–2023 | 385.802 (+23.248) | 254.358 (+15.183) | 986.347 (+36.527) | 755.503 (+21.108) |
| 2017–2023 | 549.498 (+24.437) | 370.072 (+16.372) | 1,356.662 (+38.620) | 1,041.653 (+23.201) |

On the full-window preferred source panel, worldwide QDMTT rises by US$0.361m and IIR by US$9.732m under either regime. Supported UTPR rises by US$28.526m under Universal and US$13.107m under SbS. SbS extinguishes a further US$15.765m. Unsupported UTPR remains US$1.816bn under either regime. The EU27 QDMTT part is identical. The small worldwide QDMTT increase goes to other jurisdictions. Poland has the largest EU27 gain, US$10.146m Universal and US$9.763m SbS. The source ledger retains all 606,528 keys, including zero and mechanical observations. Restored amounts at positive QDMTT sources stay in the domestic channel.

When the tax measure uses host averages instead of the pooled distribution, the change is larger. The corresponding EU27 amounts rise by US$7.395bn Universal and US$7.173bn SbS. Worldwide assigned receipts rise by US$15.881bn and US$15.477bn, including US$13.962bn in QDMTT globally under each regime. Additional unsupported UTPR is US$1.487m in each arm. Spain and Sweden gain about US$1.861bn and US$1.025bn in the average-ETR SbS arm. The non-behavioural inputs and routing retain their existing support. Mechanical source, relocation and collection are compared independently of behavioural cells.

The before-and-after source ledger separates post-substance liability, historical relief, ordinary-response relief and the amount entering the waterfall. QDMTT, IIR and potential UTPR are reported with assigned UTPR, unsupported liability and SbS extinction. Profit moved and source ordinary tax lost are separate quantities. In the 2026 transitional-screen stress, cumulative preferred EU27 receipts change from US$119.653bn to US$120.204bn with the screen reaching QDMTT, and from US$160.410bn to US$161.061bn if it preserves domestic top-up. The difference in relief reflects the amount available to screen on each basis.

## Factorial results

The minimum core scenario remains `x01011`, the maximum `x10100`. The full 32-scenario EU27 range for FY2023 is US$12.830–83.280bn, for 2019–2023 US$101.313–470.635bn, and for 2017–2023 US$159.822–670.666bn. The revised lower cumulative endpoint is US$4.474bn higher. Across the full 64 two-level designs, the model produces US$62.521–670.666bn with L3 and US$62.521–591.623bn with strict L4. The accounting adjustment moves preferred SbS receipts from US$370.072bn to US$231.134bn in L3 and from US$328.941bn to US$213.623bn in L4. Relative to R05b, the latter accounting-adjusted point increases by US$2.595bn.

Each pair in the table is **main-effect / Shapley share** of pooled country-year scenario variance for 2017–2023, in per cent. The interaction row reports the sum of interactions before Shapley attribution.

| Factor | Core 32 | Accounting 64 L3 | Accounting 64 L4 |
| --- | ---: | ---: | ---: |
| ETR measurement | 68.72 / 71.92 | 42.08 / 45.48 | 39.74 / 42.56 |
| Substance | 2.80 / 3.53 | 1.55 / 2.08 | 1.79 / 2.40 |
| Transition rates | 0.13 / 0.17 | 0.09 / 0.12 | 0.08 / 0.11 |
| SbS | 17.95 / 20.19 | 11.00 / 12.58 | 9.21 / 10.72 |
| Behaviour | 3.84 / 4.20 | 2.11 / 2.46 | 2.20 / 2.58 |
| Accounting | — | 34.33 / 37.27 | 38.91 / 41.63 |
| Interactions | 6.57 | 8.85 | 8.06 |

Behaviour's core Shapley share was about 4.27% with the notch. Accounting L3 moves from 2.50% to 2.46% and L4 from 2.68% to 2.58%. Measurement and accounting remain the two largest contributors. Their combined pooled Shapley shares across the longer windows and both ladders span 82.76–89.67%. Summing to cumulative collector receipts before decomposing gives measurement/accounting shares of 51.70/32.92% in L3 and 45.20/38.39% in L4. On that estimand behaviour's shares are 1.97% and 2.36%, and interactions account for 6.75% and 6.22%. L4's separate initial-rates-only design retains a slight accounting lead. Full term and country decompositions are in the [accounting export](../../data/processed/diagnostics/step15_globe_accounting_factorial_anova.csv).

## Simulated uncertainty

Each exercise evaluates its established 500 draws. The independent profit-only exercise holds the ETR, the production behavioural filter and routing fixed. Its preferred EU27 95% intervals under SbS move from US$361.109–374.997bn to US$361.124–375.015bn; under Universal they move from US$527.934–567.075bn to US$527.956–567.098bn. These are profit-correction intervals conditional on that narrow set of fixed inputs.

The ETR-only exercise recalculates the low-tax share, tax gap and behavioural schedule, holding the other estimated inputs fixed. Its preferred EU27 90% intervals move from US$301.212–401.447bn to US$305.243–406.129bn under SbS and from US$430.847–588.885bn to US$436.151–591.679bn under Universal. The preferred SbS increase across paired draws has a median of US$2.970bn, a mean of US$3.371bn and a range of US$0.114–16.311bn. Universal has a median of US$3.457bn and a range of US$0.166–18.577bn. Relative to the point data, ETR perturbation can put many more observations into the former band. Both replays reproduce all 64 scenario-by-draw cells for draws 1 and 464 in their corresponding R06a diagnostic arms exactly. Stage 07a retains its established 2022 sectoral matrix in the measurement exercise. The main point uses the contemporaneous sectoral panel where available. Consequently, the unchanged average-ETR input can still yield a different level of band exposure in a sectoral draw scenario than in its main-design point.

The joint exercise pairs all 32 scenarios within each draw. Estimated parameters explain 1.654% of total EU27 cumulative variance over 2017–2023 and 0.409% over 2019–2023. Disagreement across scenarios explains the other 98.346% and 99.591%. The change in the ratio reflects primarily the change in scenario spread.

| Joint draw window | R05b preferred 90% interval width, US$bn | R06b preferred 90% interval, US$bn | R06b width, US$bn | Scenario spread / interval width, R05b → R06b |
| --- | ---: | ---: | ---: | ---: |
| 2017–2023 | 71.21 | 338.208–409.246 | 71.038 | 7.24 → 7.19 |
| 2019–2023 | 23.32 | 241.490–264.808 | 23.318 | 15.96 → 15.84 |

For 2017–2023, the joint input-block Shapley shares are 76.57% for ETR errors, 11.51% for the slope and 11.92% for the profit correction. For 2019–2023 these are 0.01%, 33.97% and 66.02%. Scenario variance dominates in every collecting Member State. Austria has the highest conditional parameter share, 45.09% and 19.55% in the two windows. Poland has the largest country spread-to-interval-width ratio in the longer window, 6.56. Slovakia's ratio is 41.28 for 2019–2023. The joint comparison CSV retains the paired country summaries.

## Ordinary CIT, budgets and adoption

Under Rule B, preferred SbS source profit relocated worldwide increases by US$34.349m. EU27 destinations receive US$1.990m more ordinary CIT. EU27 sources lose a further US$2.547m of CIT, yielding a US$0.557m decrease in EU27 net recovery. Outside the EU27, gross recovery rises by US$5.524m and origin loss by US$2.116m, for a US$3.408m net gain. The global net gain is US$2.852m. The revised preferred SbS fiscal comparison of behaviour against its mechanical counterpart is US$62.091bn less EU27 top-up, US$65.269bn of gross destination CIT and US$17.117bn of source CIT loss. Combined net fiscal receipts fall by US$13.939bn. Rules A, B and C retain their original definitions. The separate fiscal ledger reconciles the incidence under all three rules.

The eight main FY2023 benchmark coverage outcomes across the **unrestricted core** stay the same. Across all the stored comparisons, the Austrian FY2023 policy-matched core switches from covering the EUR0.100bn benchmark to exceeding it. Its minimum rises from EUR0.095bn to EUR0.150bn, while the unrestricted range still covers it. The Dutch post-package direct EUR0.176bn benchmark stays below the FY2023 core and matched minima of EUR0.254bn. The sequential preferred waterfall reaches EUR0.453bn. Germany's EUR1.000bn cash costing stays inside the unrestricted core and below the matched pre-SbS minimum of EUR1.699bn. The German EUR0.200bn full-year figure stays below both. Belgium's EUR0.634bn combined QDMTT and IIR costing stays inside the matched core range, and its EUR0.300bn IIR costing stays above even the matched core maximum of EUR0.113bn. The forecast amounts and dates are the same. The paired budget CSV records close-scenario IDs, ties, model bounds and interval status for each policy/scope combination.

The production game covers 432 cases at the original windows. The R3 adoption benchmark and the verified set of available UTPR recipients enter the recalculated game. Full opt-out rebuilds the denominator without the deviating collector. Gain and tie classifications at zero weight on retained profit agree with R05b. All 432 cases have a fiscal loss at zero weight. Under Universal, QDMTT repeal leaves modelled firm liability intact. Under SbS, summing the 27 distinct L3 repeal experiments over 2017–2023 gives US$100.150bn of firm liability saved, US$159.288bn retained profit and US$6.220bn ordinary CIT retained at source. The combined US$102.069bn foreign soak-up is distinct from US$76.026bn domestic IIR and US$0.611bn domestic UTPR recapture. Ireland's firm savings equal 85.9% of net forgone collector receipts over 2017–2023. Across strict L4 SbS full opt-outs, Denmark's domestic fiscal cost rises by US$594.195m and the Netherlands' by US$426.829m. These are unilateral deviations from a fixed adoption benchmark. The production sequence evaluates those deviations, the SBTI strategy comparison and bilateral spillovers.


## Reproduction

Starting revision `6359fff547fbc8f6b0693001fce93c6a1d352a61` on `publication-rework`. The pinned R05b paper, note and processed files are recoverable at `0e619fc2e112c8e758ea6e6969aca97ea01b8606`. Use R 4.6.0 and the 68 package versions in `renv.lock`, with the system tools in the [replication guide](../../REPLICATION.md#package-and-execution).

```sh
export LC_ALL=en_US.UTF-8 TZ=Europe/Amsterdam
shasum -a 256 -c tests/step17_raw_inputs.sha256
shasum -a 256 -c tests/r05b_legal_inputs.sha256
historical="$(mktemp -d)"
revised="$(mktemp -d)"
comparison="$(mktemp -d)"
GMT_UTPR_SPECIFICATION=VERIFIED_PARENT_ONLY GMT_BEHAVIOURAL_SPECIFICATION=BASELINE_NOTCH \
  GMT_MEASUREMENT_WORKERS=4 Rscript --vanilla run_all.R --output-root="$historical"
GMT_UTPR_SPECIFICATION=VERIFIED_PARENT_ONLY GMT_BEHAVIOURAL_SPECIFICATION=NO_NOTCH_STANDARD_RESPONSE \
  GMT_MEASUREMENT_WORKERS=4 Rscript --vanilla run_all.R --output-root="$revised"
Rscript --vanilla tests/verify_golden_step15.R "$historical" r05b
Rscript --vanilla tests/verify_golden_step15.R "$revised" r06b
GMT_BEHAVIOURAL_SPECIFICATION=BASELINE_NOTCH GMT_TEST_OUTPUT_ROOT="$historical" \
  Rscript --vanilla tests/testthat.R
GMT_BEHAVIOURAL_SPECIFICATION=NO_NOTCH_STANDARD_RESPONSE GMT_TEST_OUTPUT_ROOT="$revised" \
  Rscript --vanilla tests/testthat.R
Rscript --vanilla code/diagnostics/behavioural_specification_comparison.R \
  "$revised/data/processed" "$historical/data/processed" "$comparison"
```

The leading cache gate explicitly rejects every legacy ETR draw cache. The historical verified-collector path also recomputes all 500 ETR draws. The archived `LEGACY_FALLBACK` cache remains available only under `BASELINE_NOTCH`, when its archived inputs and outputs pass the original exact-hash checks. The two replay roots keep their file inventories separate. Complete fit coefficients, raw/manual inputs, the legal register, the ETR and substance inputs and the verified weights retain their bytes. The historical release uses an empty fallback file and explicit unsupported source keys. Its marker is absent by design. The revised release adds one CSV recording its active specification and bandwidth.

The independent source comparison runs at the original parent × affiliate × year × scenario keys and matches the unrounded R06a point calculations. Before the full replay, maximum absolute gaps were US$0.000244 for source summaries, US$0.000031 for EU27 channels, US$0.000123 at the core range endpoints and US$0.000062 for both 64-point accounting ladders. The sparse point collector check agreed with Stage 06 to US$0.000054. The comparison reconciles assigned receipts, extinction and unsupported UTPR using the detailed Stage 06 outputs. Its RDS stores each fixed-key source observation once alongside the monetary columns for both modes.

The [comparison files](../../data/diagnostics/r06b_comparison/) contain the complete source ledger, window totals, collector changes, reconciled Rule B ordinary CIT, forecast comparisons, 432 game pairs and the uncertainty summaries. The [processed changes inventory](../../data/diagnostics/r06b_comparison/processed_changes.csv) reports the schemas, affected layer and previous and revised SHA-256 digests for each changed or added output. The [R05b manifest](../../tests/golden_r05b.csv) and the [R06b manifest](../../tests/golden_r06b.csv) index the exact inventories. To verify the publication, use the documented isolated `latexmk` procedure from the [replication guide](../../REPLICATION.md#exhibit-only-reproduction-and-latex-builds), once with each corresponding set of sources and exhibits.

### Acceptance results

Both isolated runs completed all fifteen stages. The historical run took 4,907 seconds and the revised run took 4,826 seconds in summed runner stage timings, while the two processes overlapped. Each recomputed the 500 profit-correction draws, 500 measurement-error draws and 500 joint draws. Both produced 432 unilateral, 108 incentive-strategy and 7,360 spillover rows, and 47,712 rows of accounting factorial output. The independent downstream run reproduced the joint variance, accounting, game, benchmark, waterfall, Rule B and influence CSVs byte for byte. The matched source-to-collector change reconciles within US$0.000005 by scenario and year.

All 54 original inputs and the separately pinned legal register pass SHA-256 verification. The historical run matches all 363 R05b hashes and its exact path set. The revised run and checkout each match all 364 R06b hashes. Of the earlier files, 202 are byte-identical and 161 change. One specification CSV is added. The manifests have SHA-256 digests `cae6d61784a5da7a6286552b318b9f1a302b6802d9df15d064563ecd2121ce7e` (R05b) and `a5f2c6127e127980c731fcddaff21e184e4aa4a5e1f124479ac46f97d4b63320` (R06b).

The revised targeted check passes 1,093 expectations. The final publication-only rerun passes 275. The full suite passes 1,118 on the revised replay and checkout, and 1,113 on the historical replay. All have zero failures, warnings and skips. The historical exhibit tree matches all 81 archived TeX files byte for byte and all eight figures after normalising date fields. The revised tree changes 29 of the TeX files and four figures. Independent generation reproduces all 81 revised TeX files and eight revised figures under the same comparison. The two independently compiled revised documents match in page text, content streams, images and fonts. The paper is 76 pages and the research note five. The historical build also matches its archived documents by those checks.

A clean-machine replication still requires the four pinned companion extracts. Aggregate activity identifies neither GloBE elections nor firm-level collection entitlements. Actual group response and the causal effect of tax rates on reported profit also remain outside the identified results.
