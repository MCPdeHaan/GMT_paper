# R11c. Sectoral SBIE before an imputed QTI adjustment

Starting revision: `aee0590d5a9f5c41cf9cdb67451aea8e598f9269`, clean `publication-rework`. The comparator is the R10b 373-file reference. R11c implements the authorised scientific decision following [R11a](r11a_substance_methods.md) and [R11b](r11b_sbti_scientific_audit.md). Economic observations remain FY2017–2023; the legal counterfactual remains a fiscal year beginning 1 January 2026, with the existing evidence cutoff. No estimator, accounting assumption, eligibility map or behavioural schedule is revised.

## Decision and identification

The leading revenue design compares aggregate and sectoral SBIE **before an imputed QTI adjustment**. It does not assert that actual incentives, elections or SBTI relief are zero. Public CbCR and the sectoral sources do not identify eligible group-jurisdiction activity, qualifying incentives used, covered-tax adjustments or elections. Applying a capacity proxy as though it were observed relief combines an unobserved treatment with the sectoral SBIE contrast.

The [OECD January 2026 package, chapter 4 paragraphs 4–8](https://www.oecd.org/content/dam/oecd/en/topics/policy-sub-issues/global-minimum-tax/side-by-side-package.pdf#page=70) permits an elected covered-tax addition limited by QTI used and the applicable substance cap. The default uses 5.5% of the greater of eligible payroll and eligible depreciation/depletion. The five-year alternative uses 1% of eligible depreciable carrying value, with revocation constraints. The historical `max(.055*payroll, .01*assets)` within sectors combines elements of those alternatives and applies them at a proxy grain. It remains an explicitly conditional sensitivity. R11b's existing-use and new-credit examples retain their distinct fiscal baselines and legal assumptions.

## Specification and implementation contract

`GMT_FACTOR2_SPECIFICATION` accepts exactly two complete names and rejects explicit NA, empty, partial or unknown values. When the environment variable is unset, the ordinary default is `SECTORAL_SBIE_ONLY`. Set `LEGACY_HYBRID_SBIE_SBTI` explicitly for R10b and earlier references. The other four leading switches retain their R10b values: `OBSERVED_TWO_SIDED`, `STANDARD_ROLE_SPECIFIC`, `VERIFIED_PARENT_ONLY` and `NO_NOTCH_STANDARD_RESPONSE`.

The 32 identifiers `x00000` through `x11111`, five binary columns and source key `(scenario_id, parent, affiliate, year)` retain their meanings and ordering except for the named interpretation of Factor 2. `x2=0` remains aggregate SBIE. `x2=1` is sectoral SBIE alone in the leading mode and the original bundled sectoral/hybrid treatment in historical mode. Leading outputs use `factor2_substance=sectoral_sbie_only`; historical outputs keep `sectoral_sbie_sbti`. Stage 05 writes a one-row specification marker only in the leading mode, preserving the historical inventory exactly. The complete unchanged R10b processed and publication snapshot is retained under [`data/baseline_r10b/`](../../data/baseline_r10b/ARCHIVE.md); its original manifest remains authoritative. A historical run rejects a destination containing that leading marker.

| Consumer | Ownership and selected operation |
|---|---|
| Stage 04 and `substance/` | Unchanged aggregate shields, endpoints, transition schedule, sector panel, phi, capacity, floor diagnostics and H5 regressions. Both sectoral rate summaries remain available. The compatibility field `total_factor2_effect` in the Stage 04 capacity decomposition continues to describe the historical bundle, not leading Factor 2. |
| Stage 05 bridge | Select `sectoral_sbie_per_profit_*` or historical `sectoral_sbie_sbti_per_profit_*` at the rate boundary. Retain low share, sector-profit weights, average/distributional distinction, aggregate denominator, contemporaneous → 2022 → unit hierarchy. |
| Stage 05 source and behaviour | Existing 32-case source kernel and response operate on the selected post-SBIE amount. Liability and relocated profit change only where the selected factor changes the numerical exposure. Legal flags and the response function remain fixed. |
| Stage 07 decomposition | Factor levels and economic-object metadata describe the selected contrast. Main effects, interactions and Shapley values are recalculated. |
| Stage 07a | Profit-only preferred calculations keep their original estimand. Standalone ETR draws rebuild the selected bridge using the original draw law. The old cache also requires historical Factor 2 and remains unavailable to either R10b-profile replay. |
| Stage 09 | Historical mode retains the original independent sectoral/overlay design. In leading mode the SBTI axis duplicates each core cell exactly. It is a degenerate diagnostic axis, not 64 independently varying substantive policies. |
| Stage 10 | Accounting changes feed the same selected sectoral bridge. The dividend, loss, numerator, envelope and transitional-screen mechanisms retain their contracts. |
| Stage 11 sparse evaluator | Records the selected mode in its input object, selects the same post-SBIE or historical post-overlay gap and preserves the routes and conservation checks. Leading support requires a usable sector SBIE, without an unrelated capacity-data gate. |
| Stage 11 game | The 432 repeal/opt-out cases and 108 historical strategy rows use aggregate SBIE and keep their original fiscal accounts. No leading Factor 2 switch is applied to these conditional capacity scenarios. |
| Stages 12 and 13 | Scorecard topic and exhibit labels distinguish leading SBIE from historical capacity. Publication wording follows the input tree's specification marker, so a historical tree cannot be relabelled by the shell's new default. |

The original core contains 606,528 ordered source rows. Unused host-year sectoral lookup columns can change on aggregate-arm rows, but the selected scale, all active source amounts, flags, schedules and routed revenues must be identical there. The comparison checks this distinction explicitly. Twenty endpoint-sector rows have finite phi and unavailable hybrid kappa. Sectoral-only calculations preserve their usable SBIE, consistently with R11b's no-QTI shadow. Host-year fallback support is checked separately from that sector-capacity boundary.

## Point results and the variance denominator

The production core reproduces R11b's no-imputed-adjustment characterisation. Cumulative EU27 receipts span US$196.277–673.405bn, compared with US$159.750–667.064bn historically. Preferred aggregate-SBIE receipts remain US$546.32bn under Universal and US$367.670bn under SbS. The sectoral preferred SbS branch changes from US$326.104bn to US$378.647bn.

Global assigned receipts span US$655.049–1,643.580bn, compared with US$618.446–1,637.241bn historically. Preferred global Universal and SbS receipts remain US$1,345.355bn and US$1,031.779bn. These are assigned top-up receipts, excluding unsupported pools and ordinary CIT. The revised EU27 maximum is the distributional, sectoral, long-run, Universal, mechanical scenario `x11100`; the former maximum used aggregate SBIE.

Over FY2017–2023 the Factor 2 Shapley share changes from 3.5688% to 0.1434%, with its average cumulative effect moving from −US$44.1bn to +US$5.828bn. The new core measurement main and Shapley shares are 72.1684% and 74.6666%; SbS shares are 18.0805% and 20.3224%; behaviour is 4.6787% by Shapley and the endpoint 0.1889%. Measurement's Shapley share rises to 81.2936% in 2019–2023 and 85.3624% in 2021–2023. These shares use the revised total sum of squares. They cannot be read as an additive subtraction of the former SBTI percentage from a fixed denominator.

Historical six-factor capacity attribution remains separately reproducible: its FY2017–2023 overlay and sectoral contributions were 4.8920% and 0.1917%. In the leading degenerate split, exact on/off cell equality makes the SBTI contribution structurally zero; floating-point contrast residuals near machine precision are arithmetic noise. This differs from the six-factor accounting design, whose sixth factor remains substantive.

## Accounting and country heterogeneity

Both accounting designs are recalculated for L3 and strict L4, with initial-rate restrictions kept separate from the full 64-case designs. The FY2017–2023 L3 range moves from US$63.096–667.064bn to US$66.939–673.405bn; strict L4 moves from US$63.096–594.015bn to US$66.939–601.049bn. The preferred aggregate-SBIE accounting-on receipts remain US$229.653bn under L3 SbS and US$215.321bn under strict L4 SbS. Accounting-off preferred receipts remain US$367.670bn and US$330.936bn. Thus the unchanged preferred branch coexists with changed factorial ranges, main effects and interactions.

The [detailed accounting routing ledgers](r11c/accounting_routing_ledgers.rds) retain both specifications at `(case, scenario_id, affiliate, year)` source grain and `(case, scenario_id, country, year, channel)` collector grain. `L3_point`/`L4_strict` are accounting off and `L3_accounting`/`L4_accounting` are accounting on. Every case contains all 32 binary scenarios; pairing off/on gives each 64-case accounting design. Liability, assigned UTPR, unsupported amounts and extinction remain separate. These data-frame calculations independently match the sparse representation; they are not source amounts inferred from collector totals. All 192,384 paired source-year keys match across modes, all 96,192 aggregate-arm source-year rows agree exactly, and no source liability is missing. [Accounting contract checks](r11c/accounting_contract_checks.csv).

Under L3 over FY2017–2023, measurement's main and Shapley shares are 44.613% and 47.396%, against 41.674% and 45.10% historically. Accounting's revised shares are 35.517% and 37.951%, with an average effect of −US$181.752bn, compared with −US$171.682bn. Under strict L4 the revised measurement/accounting Shapley shares are 43.933%/42.958%. Combined shares across the two longer windows and ladders are 85.347–91.506%; in 2021–2023 they are 92.869–93.198%. [Keyed accounting levels, effects and interactions](r11c/accounting_comparison.csv).

For the sectoral preferred SbS branch `x11011`, cumulative EU27 collection increases by US$52.543bn. Germany gains US$12.334bn, the Netherlands US$7.403bn, Spain US$6.007bn, Ireland US$5.667bn, Belgium US$5.587bn, France US$5.165bn and Luxembourg US$1.647bn. These are changes in the sectoral sensitivity; every country's preferred aggregate branch is unchanged. [All 27 country comparisons](r11c/preferred_sectoral_country_comparison.csv).

In the L3 accounting design, measurement/accounting Shapley shares are 77.38%/10.75% in Germany, 64.18%/13.44% in France, 30.88%/55.76% in Ireland, 46.56%/45.09% in the Netherlands and 5.80%/69.78% in Luxembourg. The original distinctions between pooled country-year and cumulative-collector variance, and between the full 64 cases and initial-rate 32 cases, remain essential.

A small Factor 2 share measures the allocation contrast between two SBIE treatments. It does not measure the effect of abolishing the SBIE. No additional dividend purge, loss rule, tax numerator or safe-harbour change is introduced through this revision.

## Uncertainty and paired draws

All three studies retain their original seeds, draw order, input law and scope. All 500 primary joint draws agree exactly on every aggregate-branch scenario across 28 country/EU27 scopes and two cumulative windows, totalling 448,000 matched projections. Preferred intervals therefore remain unchanged. The independently recalculated historical joint CSV also reproduces its original frozen bytes. [Paired joint identity](r11c/paired_joint_draw_identity.csv) · [Preferred joint intervals, Universal and SbS](r11c/joint_preferred_intervals.csv).

| Preferred cumulative EU27 interval, US$bn | Universal | SbS | Level and scope |
|---|---:|---:|---|
| Profit correction | 524.79–563.91 | 358.74–372.62 | 95%, 2017–2023 |
| Standalone ETR error | 462.97–593.68 | 314.42–397.00 | 90%, 2017–2023 |
| Joint uncertainty | 493.89–577.30 | 337.62–392.76 | 90%, 2017–2023 |
| Joint uncertainty | 352.86–398.68 | 237.67–259.85 | 90%, 2019–2023 |

The linked CSV retains the unrounded limits. These studies are distinct conditional experiments. In particular the standalone ETR simulation and joint residual perturbation have different support and calibration conventions. Their intervals are not nested variance components.

Across all 32 scenarios, the revised joint parameter share is 1.2346% over 2017–2023 and 0.4348% over 2019–2023, compared with the historical 1.18% and 0.44%. Preferred 90% widths remain US$55.134bn and US$22.176bn, while point scenario spreads fall to US$477.128bn and US$349.171bn. The ratios become 8.654 and 15.746. The revised ETR/coefficient/reconciliation parameter Shapley shares are 71.326%/13.547%/15.127% over the longer window and 3.524%/29.124%/67.352% over the shorter one. This change comes from the sectoral design, not an unexplained change in the preferred draws. Accounting and legal uncertainty still lie outside the three-block parameter simulation. [Paired variance and parameter-block comparison](r11c/uncertainty_variance_comparison.csv).

The annual diagnostic derives actual EU27 draw-level sums and verifies their cumulative projection against the original study. It does not sum country interval endpoints. For FY2023 the SbS profit-only 95% interval is approximately US$39.8–43.3bn, the standalone ETR 90% interval US$29.2–60.0bn and the joint 90% interval US$39.0–43.4bn. All seven annual windows, both regimes, levels and widths are retained in [the annual interval file](r11c/preferred_annual_intervals.csv). Summing the profit-only annual receipts agrees with the original cumulative draws within US$0.000794, attributable to binary64 grouping order.

## Fiscal sensitivities retained

The matched sector-first and host-first hybrid capacities remain US$104.494bn and US$79.943bn, a US$24.551bn difference on the same finite activity. The R11b 0–20% depreciation grid, 50/75/100% eligible carrying-value shares, missing payroll/assets, signed assets, positive-activity zero-profit sectors and use assumptions retain their original provenance. None supplies a preferred estimate of legal capacity or use.

R3 SbS, L3, supported positive-QDMTT sources in 2021–2023 give US$16.469bn of direct-overlay relief and US$14.324bn under full existing use of the sector hybrid through covered taxes. The hypothetical default-8%-depreciation half-use and elective-75%-stock half-use cases give US$6.913bn and US$3.502bn. New ordinary credits under the sector hybrid cost US$19.144bn and leave baseline top-up unchanged when their covered-tax add-back offsets the reduction. These fixed-response examples are supplementary. They neither identify investment effects nor rank programmes against repeal's different behavioural counterfactual.

The 432 repeal/opt-out cases, 108 historical strategy rows and 7,360 bilateral spillover rows were freshly recalculated in both full replays and remain byte-identical to R10b. Their SHA-256 values are respectively `5a53c0f8909786b475cf0cfbaf8e8eadf1c18acee64ef4bdd02ed096c81a795f`, `e1fb56ad79e81551c7db3c7cead9ddf4f0968533e21a4cfbba1a3029a3df13bd` and `c69cb789a3bbf354e2f3bacd5f74095e23efde2e965fcd18a5f06f89738cee03`. All 27 R11b conditional-audit CSVs independently reproduce their historical bytes. Fiscal-gain and tie classifications are unchanged. The figure and table now identify the direct overlay as historical and conditional; their relief comparison is not a welfare ranking.

## Budget comparisons and source reconciliation

The unrestricted FY2023 core range brackets three of the eight selected official benchmarks, Belgium, Germany and France, rather than the historical four. Austria's lower bound rises from EUR0.066bn to EUR0.428bn, above its EUR0.100bn forecast. Its policy-matched Universal minimum rises from EUR0.149bn to EUR0.512bn. The 2019–2023 core also brackets three benchmarks: Slovakia's minimum rises from EUR0.024bn to EUR0.053bn, above EUR0.0485bn. The accounting-on L3 range brackets none; its minimum exceeds seven benchmarks, while Slovakia's forecast exceeds its maximum. These comparisons retain each benchmark's policy, channel, currency and time-base distinctions. The preferred accounting waterfall remains unchanged, including Dutch FY2023 receipts of about EUR0.447bn. [All scenario-range changes](r11c/step9_budget_benchmark_scenario_ranges_r04b_comparison.csv).

Every original ordered source key is retained. The [bilateral sectoral comparison](r11c/sectoral_source_cell_comparison.rds) records all 303,264 `x2=1` cells, their coefficients, applied response schedule and liability components. The [source-year comparison](r11c/source_year_comparison.csv) and [collector-channel comparison](r11c/collector_channel_comparison.csv) retain all 32 scenarios. Coefficients and the response function are fixed; a source can move from an inactive response to the unchanged continuous response when the removal of imputed relief creates exposure. Such changes are listed in [the applied-schedule ledger](r11c/applied_schedule_changes.csv).

The maximum annual scenario conservation residual in either complete core is US$0.000518799. For preferred Universal, global source liability of US$1,346.507bn equals US$1,345.355bn assigned plus US$1.152bn unsupported. Preferred SbS liability of US$1,399.316bn equals US$1,031.779bn assigned, US$366.385bn extinguished and US$1.152bn unsupported. The different behavioural source totals reflect the unchanged response to legal exposure, not a conservation failure. The unsupported amounts are not labelled collected revenue. [Scenario-year identities](r11c/conservation_comparison.csv).

## Reproduction and acceptance evidence

Use the [locked environment and publication procedure](../../REPLICATION.md). Both arms use fresh isolated directories and recompute all three 500-draw exercises. No old Monte Carlo output or checkpoint is installed.

```sh
export GMT_TABLE_IV_SPECIFICATION=OBSERVED_TWO_SIDED
export GMT_STATUTORY_RATE_SPECIFICATION=STANDARD_ROLE_SPECIFIC
export GMT_UTPR_SPECIFICATION=VERIFIED_PARENT_ONLY
export GMT_BEHAVIOURAL_SPECIFICATION=NO_NOTCH_STANDARD_RESPONSE
export GMT_FACTOR2_SPECIFICATION=SECTORAL_SBIE_ONLY
shasum -a 256 -c tests/step17_raw_inputs.sha256
shasum -a 256 -c tests/r05b_legal_inputs.sha256
GMT_FACTOR2_SPECIFICATION=LEGACY_HYBRID_SBIE_SBTI Rscript --vanilla run_all.R --output-root="$historical"
GMT_FACTOR2_SPECIFICATION=SECTORAL_SBIE_ONLY Rscript --vanilla run_all.R --output-root="$revised"
Rscript --vanilla tests/verify_golden_step15.R "$historical" r10b
Rscript --vanilla tests/verify_golden_step15.R "$revised" r11c
Rscript --vanilla code/diagnostics/factor2_revision.R "$historical" "$revised" "$comparison"
Rscript --vanilla code/diagnostics/factor2_evaluator_parity.R "$revised" "$evaluator_checks"
Rscript --vanilla code/diagnostics/factor2_joint_parity.R "$revised" "$joint_checks"
Rscript --vanilla code/diagnostics/factor2_annual_uncertainty.R "$revised" "$annual_checks"
GMT_FACTOR2_SPECIFICATION=LEGACY_HYBRID_SBIE_SBTI Rscript --vanilla code/diagnostics/factor2_shadow_reference.R "$historical" "$shadow_checks"
GMT_FACTOR2_SPECIFICATION=LEGACY_HYBRID_SBIE_SBTI GMT_TEST_OUTPUT_ROOT="$historical" Rscript --vanilla tests/testthat.R
GMT_FACTOR2_SPECIFICATION=SECTORAL_SBIE_ONLY GMT_TEST_OUTPUT_ROOT="$revised" Rscript --vanilla tests/testthat.R
GMT_FACTOR2_SPECIFICATION=SECTORAL_SBIE_ONLY Rscript --vanilla tests/testthat.R
```

Define each output variable as a different fresh absolute directory. The diagnostic commands do not change either replay, production data or the freeze. The R11b audit remains a historical-input calculation; invoke it under the legacy mode against the historical root. The annual diagnostic recomputes the original draws and reports their annual EU27 projections. The joint diagnostic reruns the original sampler under each mode with a read-only observer that consumes no random numbers.

### Completed gate, 17–18 November 2026

R 4.6.0 on arm64 macOS 27.2.1 used all 68 lockfile-matched package versions, the default R BLAS/LAPACK, `LC_ALL=en_US.UTF-8` and `TZ=Europe/Amsterdam`. The two full runner calls used seven measurement workers. All 54 original input hashes and the independent UTPR legal-register hash pass. No raw input, legal register, lockfile, Stage 04 physical panel or primitive changed.

| Check | Result |
|---|---|
| Historical fifteen-stage replay | All stages completed; all 373 original R10b hashes and exact processed path set pass. The retained archive independently passes the same manifest. |
| Revised fifteen-stage replay | All stages completed; all 374 R11c hashes and exact path set pass, independently rechecked against the promoted checkout. |
| Complete tracked suite, revised replay | 1,804 passing expectations, zero failures, warnings or skips; 41.3 s. |
| Complete tracked suite, checkout | 1,804 passing expectations, zero failures, warnings or skips; 41.2 s. |
| Complete tracked suite, historical replay | 1,804 passing expectations, zero failures, warnings or skips; 41.2 s. |
| New fixtures and source safety | Explicit mode selection, invalid values, positive/zero/missing capacity, missing activity, reference fallback, physical invariance, independent sparse arithmetic, unchanged schedule/identifiers, degenerate axis and safe sourcing pass. Existing legal-style incentive, route, game, accounting and manuscript tests remain active. |
| Core and simulation identity | 606,528 ordered source keys; 303,264 aggregate-arm rows identical on every active field; 751,500 ETR draw-input rows identical; 8,000 aggregate scenario/draw receipts identical; 1,000 preferred profit-only draw rows identical. |
| Joint pairing | Every one of 500 draws agrees exactly on 896 aggregate-branch projections, 448,000 values in total. Independently rerun joint outputs reproduce each full replay's CSV exactly. |
| Detailed/sparse equivalence | Twelve complete 32-case comparisons across both modes, L3, anchored and strict L4, both accounting ladders and a sampled joint draw. Maximum collector-year discrepancy US$0.000038147, below the unchanged US$0.001 contract. |
| Accounting | Independent complete sparse factorial recomputation matches all 47,712 exported comparison rows. Detailed source and collector ledgers provide the separate off/on check. |
| Publication artefacts | Historical replay reproduces all 81 TeX files exactly and eight figures after date normalisation. Independent revised regeneration, including Stage 07's separate writer, reproduces the same complete path set, all 81 TeX bytes and eight normalised figures. |
| Publication builds | Historical source plus historical exhibits reproduces all 77 manuscript and five note pages. Revised full-replay and independently regenerated exhibits each build the 78-page manuscript and five-page note. Each paired build has identical extracted text, decoded page streams and rendered pixels on every page; selected bibliographies also match. All revised pages were visually reviewed, including the new legal formula, capacity, variance, game and fiscal tables. |

The revised manuscript and note resolve citations and cross-references, with no overfull boxes or missing-reference warnings. The paper retains one pre-existing underfull box. Removing the research note's forced page break keeps the enlarged scientific discussion and comparison table on five pages. Historical publication sources and PDF bytes remain archived without that edit.

The first revised full suite exposed a scientific-reference mismatch in `test-behavioural-notch.R`: it compared all 32 revised scenarios with R10b's hybrid shadow. Its assertions and existing annual/cumulative monetary tolerances are unchanged. The new [128-cell independent reference](r11c/core_shadow_receipts.csv) is recalculated from historical sources using R11b's legacy-rate zero-capacity control, the original response and detailed allocator, bypassing the new sectoral-rate selector. Both old historical comparisons remain active. The revised full suite then passes.

No uncertainty outputs were copied into a run. Both roots were empty before execution; all 500 profit-only, 500 standalone measurement and 500 joint draws ran. The old measurement cache is excluded by the Table IV, rate, behaviour, UTPR and Factor 2 profile guards. The permanent parity, annual and joint diagnostics were subsequently executed, not merely added as untested scripts. The full-run logs are retained locally under `/private/tmp/gmt-r11c.evJYPwne/`, together with isolated roots and build/render evidence. Committed keyed comparisons above provide durable scientific evidence.

The largest observed full joint global conservation residual is US$0.001098633 on very large source pools, within the existing `0.001 + 64 * .Machine$double.eps * liability` bound in Stage 11. This absolute-plus-round-off rule scales with the source amount; it is not an economic tolerance. The point-level detailed/sparse checks use the separate US$0.001 absolute bound. The unchanged cumulative game identity has a US$0.002685547 rounding residual over seven years, within its existing annual bound accumulated over the window. No numerical tolerance was enlarged. Summed stage wall times were 26,216.3 s and 26,217.2 s; Stage 07a includes overnight computer suspension, so these are not performance benchmarks. Peak memory was not measured.

Both replays emit the same pre-existing Stage 08 warning that the VCOV matrix is not positive definite and was repaired. No test emits a warning. The covariance investigation belongs to R12; no estimator was changed to suppress it. Independent clean-machine restoration and delivery of the four ignored companion extracts remain R18 work.

### Versioned scientific references

| Manifest | Files | SHA-256 of manifest |
|---|---:|---|
| `tests/golden_r11c.csv` | 374 | `4aae84a52bb1a3c1ec53555ca172460f88242a220af698aa623087313b9482b9` |
| `tests/golden_r10b.csv`, unchanged | 373 | `8e6b003d37b1be305874d9445ce84ef9956c2e616e80b35bbfaefeb8460e57e4` |
| `tests/golden_r09b.csv`, unchanged | 367 | `8b20e8daac06cdceb0ef983306b662831a0eee24dc324bdb6065199808eb4835` |
| `tests/golden_r06b.csv`, unchanged | 364 | `a5f2c6127e127980c731fcddaff21e184e4aa4a5e1f124479ac46f97d4b63320` |

The [complete processed difference inventory](r11c/processed_file_changes.csv) identifies 239 unchanged files, 134 changed files and one new specification marker. Changes are classified as the intended Factor 2 revision, its downstream effects or descriptive metadata. No unexplained path or hash change remains. Upstream panel/measurement/physical-sector inputs, fitted coefficients and legal weights retain their bytes. The [89-file generated-publication inventory](r11c/publication_file_changes.csv) preserves 52 files byte-for-byte and records 37 expected numerical or interpretative changes; compatibility paths are retained. Four figures with timestamp-only changes retain their original bytes after regeneration verified equivalent content. Historical generated files and documents reside beside the unchanged R10b data in its versioned archive.

The focused change set contains 16 production/diagnostic R files, six test/manifest paths, ten architecture/refactoring documents, `REPLICATION.md`, 24 keyed evidence files, 135 processed-reference paths and 43 publication paths. Another 471 paths preserve R10b: 470 files are exact copies of their starting Git blobs, plus the archive guide. These archival copies reuse existing Git content. No protected raw/manual/legal input, lockfile, Stage 04 primitive or old manifest is staged. New diagnostic CSVs use LF endings, with every parsed field checked unchanged. The pre-commit whitespace check excludes the immutable archive because it deliberately retains historical trailing whitespace and line endings; its bytes are instead verified against the original Git blobs and scientific manifest. Current code, documentation and outputs pass the scoped whitespace check.

## Scientific disposition and R12 hand-off

The identifiable S06 implementation issue is addressed by removing unobserved incentive application from the leading factor, retaining the historical mechanism and correcting its legal and fiscal interpretation. Actual group-level QTI qualification, domestic availability, elections and use remain unidentified. Missing and signed activity and legal cap proxies retain the limitations documented by R11b. S07, S08 and S10 stay open. The pre-existing Stage 08 covariance regularisation and the R12–R18 programme remain outside this revision.
