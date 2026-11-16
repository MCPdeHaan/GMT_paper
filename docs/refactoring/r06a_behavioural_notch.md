# R06a. Behavioural notch and decision for R06b

## Decision

Adopt `NO_NOTCH_STANDARD_RESPONSE` in R06b. The historical two-point band automatically extinguishes post-substance liability, including QDMTT, using an ETR that the model computes for a different unit and purpose than the permanent Simplified ETR Safe Harbour. For a fiscal year beginning 1 January 2026, even the availability of the permanent safe harbour depends on early implementation and specified conditions. Public CbCR cannot establish group eligibility or election. The legal audit gives the applicable dates, rules, conditions and missing observables. [R06a legal audit](r06a_safe_harbour_legal_audit.md).

The standard-response alternative extends the existing, estimated semi-elasticity to the former band under the same policy-exposure and positive-excess conditions. This is the most coherent continuation of the current response curve as the tax gap tends to zero. The coefficient remains a scenario parameter. Endogeneity, reporting responses and post-reform responsiveness remain unresolved. Use `NO_NOTCH_NO_BAND_RESPONSE` to isolate liability restoration with relocation held constant. The historical band and the 1–3 percentage-point cases can be retained as explicit stress tests of an abrupt liability reduction with no profit relocation. There is no basis here for interpreting a width, a 100% reduction, or a fraction of candidate exposure as estimated bunching or legal take-up.

R06b should change the common schedule across the core design, measurement draws, fixed-filter projections, legal stress tests, accounting comparators and the policy game. Regenerate the official uncertainty, factorial, national budget and publication outputs after adoption, including §2.1, the behavioural equation and interpretation in §4.4, §5 and Appendices C–E. Recheck budget-range membership and any affected case orderings using the existing R04b comparisons. Keep the verified UTPR set, source predicates, coefficients and accounting specifications fixed. Keep the historical R05b run independently verifiable and version the adopted specification separately. Use a separate diagnostic for any modelled legal election, using explicit applicability, group-level inputs and its own assumptions about domestic tax.

## Frozen contract and comparison

Stage 05 constructs a schedule at **affiliate × observation year × ETR measure** and attaches it to the bilateral scenario spine. Let `tau_low = 0.15 − gap`, defined when low-tax share and gap are positive. For L1, the rate is the corrected host-average ETR where it falls below 15%. For L3, the gap is conditional on the pooled low-tax tail inferred from Table IV. Neither case thresholds the individual bilateral ETR. Each parent inherits its host's rate. Under strict L4 in the accounting factorial and policy game, the schedule uses the observed bilateral Table IV low tail. The value can depend on profits and taxes in the underlying ETR estimator. Once those inputs are fixed, a change to the individual row's base, positive excess, QDMTT, IIR or SbS status does not itself move the row across the band. Accounting repricing and measurement draws can change the inputs. [Stage 05 schedule construction](../../code/05_stage3_behavioral.R#L1594) · [Stage 11 evaluator](../../code/11_policy_game_and_variance_extensions.R#L672).

The band includes exactly 13% and excludes 15%. In behavioural cells it sets the liability filter and applied response to zero, irrespective of legal flags. It can label rows with no positive liability. Mechanical cells retain their input liability. Outside the band the selected linear model's raw shifting share below the floor is `1 − exp(β × gap)`, where β is the signed coefficient. Application requires positive post-substance liability and positive low-tax excess, with the existing cap. Exposure is one where QDMTT applies or the source is outside the SbS exemption. Otherwise the response is zero. The IIR flag acts downstream in allocation. The response reduces post-substance liability and relocates a share of low-tax excess. The notch erases post-substance liability and relocates no profit. Collector routing subsequently applies QDMTT, SbS, IIR and UTPR in production priority. A positive unsupported pool remains separate. [Stage 05 filter](../../code/05_stage3_behavioral.R#L1548) · [Exposure and liability](../../code/05_stage3_behavioral.R#L1926) · [R05b collector rules](r05b_utpr_production.md).

| Diagnostic arm | Liability in the original 13–15% band | Relocation in the band |
| --- | --- | --- |
| BASELINE_NOTCH, 2 pp | Historical zero in behavioural scenarios | Zero |
| NO_NOTCH_STANDARD_RESPONSE, 0 pp | Ordinary response on otherwise exposed positive excess | Existing semi-elasticity on that excess |
| NO_NOTCH_NO_BAND_RESPONSE, 0 pp | Full post-substance liability | Zero in the former band |
| BANDWIDTH_1PP and BANDWIDTH_3PP | Historical mechanism in [14%, 15%) or [12%, 15%) | Zero inside the specified band and ordinary response below it |

The detailed ledger closes at scenario × parent × affiliate × observation year. Post-substance liability equals notch relief plus response relief plus any subsequently applied screen relief plus assigned revenue, SbS extinction and unsupported liability. Assigned revenue includes QDMTT, IIR and the supported part of the UTPR pool. The screen ledger reroutes after removing any remaining liability selected by a separate test. Ordinary CIT is a separate monetary outcome. The source loss values relocated profit at the model's source ETR and Rule B values each receiving destination at its statutory rate. The R05b parent-only restriction applies to UTPR. Rule B profit destinations retain their own global activity fallback.

## Exposure before collection

All amounts are USD. The table reports aggregate-substance initial-rate cases. Counts and gross exposure are the same across Universal and SbS for a given measurement ladder. L4 here is the strict bilateral analogue of the preferred case. The two-point L3 total reproduces the previous US$39.46m. Its FY2023, 2019–2023 and full-window gross post-substance amounts are US$1.489m, US$37.334m and US$39.455m. Of 283 full-window bilateral rows, 133 have positive reference profit and 111 have positive liability. There are 44 distinct candidate affiliate-years. Before substance the exposure is US$52.626m. Of US$39.455m post-substance, US$28.925m comes from EU27 sources and US$15.765m from US-parented EU27 sources. The latter enters the Universal UTPR pool and is extinguished under SbS. The gross Universal liability divides into US$0.369m QDMTT, US$9.900m IIR and US$29.186m residual UTPR. The QDMTT-tagged L3 amount is outside the EU27. The equivalent L1 case includes **US$14.204bn of QDMTT-tagged gross exposure**, of which US$6.808bn is at EU27 hosts.

| Measurement, 2017–2023 | 2 pp rows / affiliate-years | 2 pp pre-SBIE, US$bn | 1 pp post-SBIE, US$bn | 2 pp post-SBIE, US$bn | 3 pp post-SBIE, US$bn |
| --- | ---: | ---: | ---: | ---: | ---: |
| L1 host-average | 1,726 / 103 | 18.231 | 8.488 | 16.156 | 36.610 |
| L3 pooled distribution, preferred | 283 / 44 | 0.053 | 0.012 | 0.039 | 0.210 |
| L4 strict bilateral, preferred analogue | 890 / 451 | 9.964 | 3.167 | 8.340 | 28.618 |

The zero-width exposure table has zero candidate amounts. Counts are per scenario and window and should not be added over designs. The full exposure CSV includes geography, parentage, potential channels and counts for positive, zero and missing low-tax profit.

## Stage 09 placebo and Stage 10 transitional screen

Stage 09 uses positive-profit affiliate-years and a profit-weighted density of host-average ETRs, binned every half point over 0–30%. It fits a quartic to bin midpoints outside [13%, 17%), truncates negative fitted mass and normalises the fitted density. The missing mass below the floor and the signed excess near it are modelled discrepancies from that smooth fit. At the historical width the independently regenerated EU27 placebo has missing mass 1.493% and excess mass −0.273%, across 189 affiliate-years. The 1,352-host-year global sample has 0.278% missing mass and 2.409% excess. The reported conditional ratios (12.11% EU27 and 6.04% global) scale the missing mass by the fitted mass in the chosen band. They depend on the excluded window, polynomial, sample, weighting and bandwidth. The disagreement between deficits and excesses, the absence of post-policy treatment variation and the difference in ETR measures prevent the placebo from constraining either post-reform response or the supportable width. The 1-, 2- and 3-point calculations reuse this fit as a descriptive check. [Stage 09 density and probability code](../../code/09_econometric_and_reallocation_extensions.R#L1017).

Stage 10 applies the transition policy thresholds 15%, 16% and 17% for 2024–2026 to historical bilateral parent × host × year aggregates. Depending on the branch, inputs are Table I net profit, positive-profit Table I Panel A.I or the lowest Table IV bracket. Annual revenue and pre-tax profit are divided by the reported subgroup count for the EUR 10m and EUR 1m tests, converted at the bridge's fixed USD/EUR rate. The routine screen uses aggregate tangible assets and estimated payroll with the policy-year SBIE rates. Its simplified ETR uses accrued tax or the larger of accrued and paid tax with the non-negative proxy convention. A pass in any applicable test selects the entire remaining amount under the all-selected stress. It is an upper envelope conditional on that proxy-selected set. Actual qualifying groups may occur on either side of the proxy classification. The separate preserve-QDMTT projection assumes no domestic relief for selected sources and does not assert that result for every national law. `notch_screen()` reruns the 2026, net-profit, tax-envelope, reporter-pool preferred SbS case and deducts only liability remaining after the selected behavioural treatment. [Stage 10 screen inputs and rule](../../code/10_accounting_bridge_and_conduit_wedge.R#L988) · [Sequential application](../../code/10_accounting_bridge_and_conduit_wedge.R#L1061).

On that bridge, 876 bilateral rows pass the transitional proxy and sit in the former two-point band over 2017–2023. Of these, 470 have positive post-substance liability, totalling US$3.823bn. The baseline notch already removes all of it. Under the additional screen and baseline behaviour, EU27 receipts fall from US$188.076bn to US$119.653bn when the screen reaches QDMTT, or to US$160.410bn when domestic liability is preserved by assumption. With the ordinary response and no notch, the corresponding figures are US$189.196bn before the screen and US$120.204bn or US$161.061bn afterwards. The corresponding no-notch changes after screening are US$0.551bn and US$0.651bn. Adding independently calculated gross reductions would count overlapping liability twice. The bridge example is on a repriced accounting basis, so its band exposure differs from core L3.

## Fiscal results

Cumulative **changes from the frozen notch** with the standard response in the former band are shown below. All amounts are US$bn and small displayed zeros denote no change or a change below the displayed precision.

| 2017–2023 | Preferred L3 Universal | Preferred L3 SbS | L1 Universal | L1 SbS |
| --- | ---: | ---: | ---: | ---: |
| Source liability before routing | +0.03862 | +0.03897 | +15.88287 | +15.88914 |
| Global QDMTT | +0.00036 | +0.00036 | +13.96219 | +13.96219 |
| Global IIR | +0.00973 | +0.00973 | +1.23112 | +1.23112 |
| Global UTPR pool | +0.02853 | +0.01311 | +0.68955 | +0.28483 |
| Global assigned UTPR | +0.02853 | +0.01311 | +0.68807 | +0.28335 |
| SbS extinction | 0 | +0.01576 | 0 | +0.41099 |
| Unsupported UTPR | 0 | 0 | +0.00149 | +0.00149 |
| Global assigned receipts | +0.03862 | +0.02320 | +15.88138 | +15.47666 |
| EU27 assigned receipts | +0.02444 | +0.01637 | +7.39537 | +7.17332 |
| Global relocated profit | +0.05719 | +0.03435 | +23.46970 | +22.87216 |
| EU27 gross destination CIT | +0.00220 | +0.00199 | +1.08578 | +1.07951 |
| EU27 source CIT lost | +0.00563 | +0.00255 | +1.39020 | +1.39020 |
| EU27 net ordinary CIT | −0.00342 | −0.00056 | −0.30442 | −0.31069 |
| Global net ordinary CIT | +0.00462 | +0.00285 | +1.96557 | +1.92622 |

Preferred EU27 receipts therefore move from US$549.474bn to US$549.498bn under Universal and from US$370.055bn to US$370.072bn under SbS. The additional EU27 collection is IIR and supported UTPR. The additional QDMTT is collected outside the EU27. Unsupported UTPR stays at US$1.816bn in both preferred cases. FY2023 adds US$0.852m of EU27 and US$1.453m of global receipts under either law. Over 2019–2023 the EU27 additions are US$23.248m Universal and US$15.183m SbS. Poland has the largest EU27 country gain in the full-window L3 cases, US$10.146m Universal and US$9.763m SbS. In the L1 SbS analogue, Spain gains US$1.861bn and Sweden US$1.025bn. Channels are receipts by collector location. The source exposure above uses the location of the underlying liability.

With the former band released but still no relocation inside it, preferred EU27 gains are US$24.983m Universal and US$16.744m SbS. The ordinary response inside the former band offsets US$0.546m and US$0.372m of those gains, respectively. For L1, the analogous offsets are US$128.139m and US$124.643m. Over the full window the original ordinary response reduces preferred post-substance source liability by US$227.650bn Universal and US$174.892bn SbS, alongside US$39.455m from the notch. The L1 SbS case removes US$93.639bn through the ordinary response and US$16.156bn through the notch. Narrowing the band to 1 pp adds US$17.390m and US$12.034m in preferred EU27 receipts under Universal and SbS. Widening it to 3 pp reduces them by US$106.567m and US$48.670m. Ordinary CIT moves separately from these top-up receipts.

The full **32-scenario core range** for EU27 receipts moves from US$155.348–670.666bn to US$159.822–670.666bn over 2017–2023. Its lower endpoint increases by US$4.474bn, or 2.88%. For FY2023 it moves from US$12.637–83.280bn to US$12.830–83.280bn. The endpoints retain their scenario IDs in every arm. In the 3 pp case the cumulative lower endpoint falls to US$144.356bn. All 32 routes were recalculated for each arm.

The **64-scenario L3 accounting design** moves from US$61.199–670.666bn to US$62.521–670.666bn. The pooled country-year main-effect shares for ETR measurement, accounting base and behaviour move from 42.22%, 34.17% and 2.14% to 42.08%, 34.33% and 2.11%. Their ordering persists. The preferred accounting-adjusted SbS point moves from US$231.121bn to US$231.134bn. In the strict L4 design the upper endpoint is US$591.623bn in both arms. The L4 preferred SbS point rises from US$325.575bn to US$328.941bn on the original basis and from US$211.028bn to US$213.623bn after the accounting bridge. The materially larger L4 effect arises from bilateral band exposure. Comparing these L4 and L3 points is a measurement comparison. Exact detailed–sparse parity was tested for the common core source grain and inputs.

**Uncertainty.** Rebuilding the Stage 07a profit-only point reproduces the historical preferred amounts. Updating the filter at the alternative point and holding it fixed within each projection gives the same preferred changes to reported precision. The seeded Stage 07a measurement replay rebuilds the schedule after disturbing the low-tax share and gap. Draws 1 and 464 give illustrative cumulative preferred SbS increases of US$0.356bn and US$4.275bn, respectively. An individual draw can move considerably more mass into the band than the point model. These paired examples establish propagation and differing exposure. They do not establish revised intervals, joint variance shares or a draw-population order statistic. R06b needs the existing full Monte Carlo designs rerun under the adopted schedule.

**Unilateral incentives.** Recalculated the existing R3 QDMTT-only repeal and full opt-out exercises for all 27 countries, both regimes and both L3 and L4 measurement cases, using the other collectors' verified parent-year routing after full opt-out. The standard-response and frozen arms have identical fiscal gain and tie classifications at zero weight on MNE top-up savings across the 648 comparisons. None shows a fiscal gain at zero weight. Amounts can still move materially. Over 2017–2023 the L3 full-opt-out fiscal cost rises by US$25.19m for Lithuania under SbS and US$28.27m under Universal. In strict L4 the full-opt-out cost rises by US$594.19m for Denmark and US$426.83m for the Netherlands under SbS. Ireland's corresponding changes are US$0.29m under L3 and US$46.00m under L4. Among the reported comparisons the reasoning about fiscal incentives should be carried forward with recalculated fiscal and firm-savings amounts. This exercise concerns unilateral deviations and does not recompute the separate strategic equilibrium search.

## Reproduction and checks

Starting revision `0e619fc2e112c8e758ea6e6969aca97ea01b8606` on `publication-rework`. From the repository root, use R 4.6.0 and the 68 installed versions pinned by `renv.lock`. The run used `LC_ALL=en_US.UTF-8` and `TZ=Europe/Amsterdam`.

```sh
shasum -a 256 -c tests/step17_raw_inputs.sha256
shasum -a 256 -c tests/r05b_legal_inputs.sha256
Rscript --vanilla tests/verify_golden_step15.R . r05b
Rscript --vanilla -e 'testthat::test_dir("tests/testthat", filter = "behavioural-notch|stage3-behavioral|collector-routing|sesh-notch-bunching|stage1-measurement-error|pipeline-regression|source-safety", stop_on_failure = TRUE)'
Rscript --vanilla tests/testthat.R
audit_dir="$(mktemp -d)"
Rscript --vanilla code/diagnostics/behavioural_notch.R "$audit_dir/results"
diff -qr data/diagnostics/r06a_behavioural_notch "$audit_dir/results"
```

The targeted suite passes 495 expectations and the full suite passes 1,100, with zero failures, warnings or skips. All 54 original inputs, the legal register and all 363 R05b processed files match their manifests. The scientific baseline and publication build inputs are unchanged. Two fresh diagnostic runs each agree byte for byte with all 15 archived diagnostic CSVs. The second run took 226 seconds of wall time. The diagnostic executes directly and does not consult the Stage 07a output cache. A fifteen-stage replay and publication rebuild belong to R06b if adopted. The four companion extracts documented in the replication guide are still required for an independent clean-machine restoration.

The Stage 05 source liability and relocated profit match the frozen reference exactly, as do the Stage 06 EU27 country-year receipt cells and the selected Stage 10 screen receipts. Maximum absolute discrepancy across all matched Stage 05 and Stage 11 source cells and arms is US$0.00000763. The sparse R05b point collector discrepancy is US$0.0000534. Independently aggregating the CSVs gives a maximum difference of US$0.000610 across the 13,440 detailed and sparse L3 collector points on the common accounting-off basis. The largest baseline reconciliation gap is US$0.000542 across the reconciled outputs, below the existing US$0.001 point tolerance. The detailed and sparse scenario-year closure gaps are at most US$0.000458 and US$0.000549. The original Rule B router checks each source to US$0.001. Its diagnostic aggregate check also accounts for double-precision round-off when summing thousands of weighted destinations by scenario and year. The archived density and regenerated shares differ by at most 9.11 × 10⁻¹⁸.

### Result files

All CSVs are in the [R06a results directory](../../data/diagnostics/r06a_behavioural_notch/). Fields ending in `_usd` are nominal model USD for the indicated historical window. The accounting outputs use USD billions. Source country in `source.csv` is the affiliate. Collector in `channels.csv` is the recipient, with absent receipt keys representing zero. EU27 and Global rows in the fiscal tables are reporting aggregates over the underlying keys.

| Files | Grain and contents |
| --- | --- |
| `exposure.csv` | Width, level, scenario and window, with total and separate source geography, US parentage and would-be channels. Includes 0 pp. Pre-SBIE amounts use low-tax profit times the ETR gap before any SBTI overlay. |
| `source.csv`, `channels.csv`, `cit.csv` | Specification × scenario × window by source, collector/channel and CIT origin/destination jurisdiction respectively. The CIT file reports sent and received profit, source tax loss, destination receipts and net ordinary CIT. |
| `core_ranges.csv` | All 32 scenarios summarised by specification and window, with endpoint IDs. |
| `accounting.csv`, `accounting_effects.csv` | Complete 64-point EU collector designs for L3 and L4 and EU27 pooled/cumulative factorial effects, including the additional 2021–2023 comparison against the archive. |
| `game.csv` | Specification × measurement × regime × deviation × country × window, with fiscal and MNE effects, unsupported UTPR and source incidence. |
| `density_placebo.csv`, `density_reconciliation.csv`, `transitional_overlap.csv` | Reused Stage 09 density summaries and the Stage 10 sequential 2026 screen with both QDMTT assumptions. |
| `profit_point.csv`, `measurement_draws.csv` | Stage 07a fixed-filter preferred point and two rebuilt ETR measurement draws, paired across specifications. |
| `baseline.csv`, `checks.csv` | Frozen baseline parity and detailed/sparse reconciliation in USD. |

[Updated scientific issue S05](scientific_issue_register.md#s05-the-behavioural-notch-is-a-reduced-form-scenario).
