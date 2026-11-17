# R10b. Table IV support revision

The starting revision is `0837080adad724ac0fe181b176080f1e5de15876` on `publication-rework`. The comparator is the R09b empirical specification, with the R06b reference preserved separately. The leading settings are `OBSERVED_TWO_SIDED`, `STANDARD_ROLE_SPECIFIC`, `VERIFIED_PARENT_ONLY` and `NO_NOTCH_STANDARD_RESPONSE`.

## Source, support and the decision

[The support module](../../code/measurement/table_iv_support.R) preserves every original OECD measure observation, its units, status and file digest. Stage 01 asserts one measure per reporter–host–year–bracket–measure key and verifies that raw profit, accrued tax and cash tax in USD survive the pivot exactly. The 121,938 records retain 212 explicit suppression blanks and 6,572 other published blanks. Stage 02 attaches status at bracket grain and writes separate pooled and bilateral support ledgers. The pooled calculation retains the same parent universe as the legacy pooled sidecar and excludes the same aggregate hosts. Bilateral support additionally uses the existing parent filters.

The modern schedule bins jurisdictional subgroups at 15% on current accrued income tax relative to profit. Negative tax with positive profit and non-positive profit have separate categories. Older intervals that cross 15% cannot identify either side of the split. The underlying disclosure decision and unreported amounts remain unobserved. A published zero, `Q` suppression, an unclassified blank, an absent measure and an absent bracket remain distinct. [OECD reporting guidelines and R10a source trace](r10a_table_iv_observability.md#what-the-source-identifies).

For a direct accrued-tax point, the leading rule requires an observed positive denominator and supported published profits on both sides of the compatible partition, with valid observed accrued tax on each published positive lower component. Zero observed lower profit contributes no gap liability where tax is zero or missing. Upper accrued tax is unnecessary for this target. Subtotals and statuses survive a failed test. A supported lower profit or share does not suffice for a point on the conditional tax gap. Any bound is conditional on admissible bracket membership and addresses the available published population. Retaining Tables I and IV as separate populations also rules out interpreting Table I projections as observed bounds on unidentified subgroup tax. The pipeline infers no structural-zero exceptions from omitted brackets.

The four verified FY2023 cases concern US-parent tax suppressed on positive lower profit in Kazakhstan, Sri Lanka, El Salvador and Venezuela. Kazakhstan also has a Greek-parent zero. The historical sum concealed the missing component by returning a finite zero. One-sided reporting raises a different issue. We require both sides for a point and retain a narrower diagnostic in which historically missing categories keep their legacy assumption but incomplete published numerical measures fail. This distinguishes the verified defect from a conservative support choice.

## Support and measurement

Across FY2019–2023, 356 of 603 direct L3 host-years pass, including 114 of 135 for EU27. The 247 rejected hosts include 98 with an absent lower bracket, 145 with an absent upper bracket alone, one with an absent upper bracket and mixed low tax, and three with missing lower tax on positive profit. All 582 exact bilateral Table IV cells pass. The strict and anchored accrued-tax L4 estimators, the rank and mean bounds and the bilateral BSPI sensitivity retain their original support. L1 and L2 do not use the new gate.

In 2017–2018 the host transport uses a common eligible pool of source-year profits and taxes, weighted by the published dollars. Of 124 historical profiles, 61 keep two source years and 27 keep only 2019. Thirty-six lose both. The 72 affected early host-years shift 780 bilateral assignments from BSPI to average. All 151 bilateral anchor profiles retain their source years. The leading L3 gives 8,501 direct, 3,611 percentile, 3,119 transported, 3,462 average and 261 unmeasured bilateral cells. The 12 newly unmeasured cells have zero positive corrected profit. The measurement ledger preserves the missing state before the allocator's explicit numerical boundary.

| Exclusive Stage 03 reason, global | Host-years | Change in pre-SBIE liability, US$bn |
|---|---:|---:|
| Absent lower bracket | 98 | +2.384 |
| Absent upper bracket alone | 145 | −15.742 |
| Absent upper bracket and partial lower tax | 1 | −0.621 |
| Missing tax on positive lower profit, upper side observed | 3 | −0.018 |
| Loss of BSPI profile | 72 | −0.033 |
| Retained but changed BSPI profile | 54 | −1.389 |

The direct FY2019–2023 change is −US$13.996bn globally and −US$0.457bn for EU27 sources. The FY2017–2018 change is −US$1.422bn and −US$0.833bn respectively. Malta accounts for US$0.771bn of the EU27 early decrease. Bermuda's and Macao's modelled changes go in opposite directions when their source-year profiles fail. Differences of floating-point summation order are omitted from the reason table. See `step3_table_iv_host_transitions.csv` for per-key rates, support, reasons and exact anchor years.

The new S1 gross validation population is 207 of the earlier 361 observations, representing 68 of 81 EU27 host-years. S2 parent-matched observations remain 70 and S3 bilateral matches remain 81. The capped S1 liability MAE on natural support falls from 3.14 to 2.32 percentage points. The excluded set has 4.24 points of MAE. Profit-weighted MAE changes from 1.922 to 1.917 points. There is no change on the fixed 207-cell common support. These are selection effects. Fit accuracy on absent or suppressed cells is unobserved. The selection reduces confidence in transporting fitted errors to poorly disclosed cases. [Validation data](r10b/matched_validation.csv).

## Shadow attribution and collector effects

The [frozen comparison data](r10b/fiscal_summary.csv) use R09b inputs and preserve all five arms. Missing measures only removes four direct hosts but leaves the earlier one-sided attendance assumptions and anchor profile. L3 direct-and-anchor is the leading production support. Stage 05 re-estimates the published regressions on the unchanged estimation design. The applied linear coefficient remains the R09b value.

| Shadow arm, change in cumulative assigned receipts, US$bn | EU27 Universal | EU27 SbS | Global Universal | Global SbS |
|---|---:|---:|---:|---:|
| Missing measures only | −0.297 | −0.234 | −0.470 | −0.361 |
| Direct only | −2.628 | −1.558 | −9.933 | −8.042 |
| BSPI only | −0.552 | −0.844 | −1.375 | −1.833 |
| Direct and BSPI | −3.180 | −2.402 | −11.309 | −9.875 |

The combined screen lowers global low-tax profit by US$105.29bn and pre-/post-SBIE liability by US$15.419bn and US$14.342bn. The EU27 source equivalents before and after SBIE are −US$1.290bn and −US$1.114bn. Under Universal global post-behaviour liability falls by US$11.973bn and reallocation by US$19.228bn. Under SbS the falls are US$11.922bn and US$17.156bn. The most important Universal source movements are Macao (−US$5.57bn), Mauritius (−US$3.01bn), the UAE (−US$1.67bn), Nigeria (−US$1.40bn) and Bermuda (+US$1.28bn). Germany receives US$1.18bn less Universal and US$1.01bn less SbS. Indonesia and Hong Kong have the largest absolute drops in Universal assigned receipts. Stage 06 uses the same eligibility map, weight construction and no-fallback rule.

| Cumulative assigned receipts or liabilities, US$bn | R09b | R10b |
|---|---:|---:|
| EU27 Universal receipts | 549.499 | 546.319 |
| EU27 SbS receipts | 370.072 | 367.670 |
| Global Universal receipts | 1,356.664 | 1,345.355 |
| Global SbS receipts | 1,041.654 | 1,031.779 |
| Global QDMTT receipts, either regime | 730.469 | 727.817 |
| Global IIR receipts, either regime | 172.528 | 167.252 |
| Global assigned UTPR, Universal | 453.666 | 450.286 |
| Global assigned UTPR, SbS | 138.656 | 136.711 |
| SbS-extinguished liability | 367.768 | 366.385 |
| Unsupported residual, either regime | 1.816 | 1.152 |

| Assigned receipts, R09b → R10b, US$bn | FY2023 | FY2019–2023 |
|---|---:|---:|
| EU27 Universal | 68.760 → 67.862 | 385.803 → 383.175 |
| EU27 SbS | 42.535 → 41.915 | 254.359 → 252.801 |
| Global Universal | 192.524 → 188.658 | 986.348 → 976.415 |
| Global SbS | 147.388 → 144.001 | 755.504 → 747.462 |

The 32 core cases retain their original keys and factors. The cumulative EU27 range changes from US$159.750–670.667bn to US$159.750–667.064bn. Measurement's pooled main/Shapley shares move from 68.76%/71.96% to 68.36%/71.58%. The SbS shares move from 17.92%/20.16% to 18.17%/20.43%. The maximum-to-minimum range remains a comparison of assumptions. Payroll, assets, wages, sectoral shares, the corrected-profit denominator and the SBTI proxy are held to the existing specifications.

## Accounting, safe-harbour and budget effects

The accrued reporter-pool dividend purge depends on direct support. Relative to the old support, the revised accrued branch removes US$60.707bn less foreign profit globally and US$11.587bn less for EU27 hosts. This is a change in where the method can be applied. It does not imply that the dividends disappear or that the true adjustment is zero. A source that switches to a fitted measure has no applicable direct-only purge and retains its fallback rates. The accrual/cash/envelope models continue to use their original tax formulas and loss-stock law. At host grain cash and envelope are conditional on the admissible accrued shape and can fall back on an unsupported alternative numerator. At bilateral grain the same bracket structure permits a separate assessment of the alternative numerator. A valid cash amount or envelope never repairs the accrued production point.

The conditional check on 583 two-sided bilateral shapes gives 582 eligible accrued, 571 eligible cash and 583 eligible envelope gap calculations. The cash difference includes negative cash under a bracket classified by accrual and does not count as missing accrual. The host support by numerator is written to `step12_table_iv_numerator_support.csv`. Stage 10's three public safe-harbour criteria retain separate support. The unknown test is counted distinctly and does not pass the individual criterion under the existing model convention. Routine profit and de minimis can still pass when accrued tax is unavailable. The legal assumptions and 2026 screen inputs are held fixed. The screen remains a proxy on public aggregates.

For the conditional FY2023 Table IV low-bracket transitional screen, all three unknown-input totals are US$18.612bn out of US$33.381bn of exposed EU27 source liability under either the accrued or envelope variant. Absent observations dominate this exposure. The accumulated liability passing at least one criterion is US$8.0m with accrual and US$21.9m with the envelope. The conditional schedule therefore leaves extensive exposure unassessed. The official budget bridge uses its stated Table I inputs and reports the wider alternatives separately.

The FY2023 EU27 preferred SbS budget waterfall now starts at €38.763bn, reaches €32.721bn after the dividend step, €23.179bn after current losses, €21.497bn after prior losses, €17.379bn under the tax envelope and €8.173bn under the 2026 screen. Omitting its simplified ETR test gives €15.504bn. Dutch receipts move from €7.088bn to €0.447bn (QDMTT €0.362bn) against the unchanged €0.176bn benchmark. Germany reaches €0.526bn, France €0.173bn and Ireland €3.586bn. The full and policy-matched scenario ranges and restricted L3 ranges retain their intended channel definitions, matched horizons and official vintages. The overlap flags remain unchanged relative to R09b. A match does not identify forecast accuracy.

## Repeal and full opt-out

All 216 QDMTT-only repeals and 216 full opt-outs retain their keys. No status changes between fiscal gain, loss and tie at zero welfare weight. Universal QDMTT repeal leaves source liability unchanged. Across the 27 separate cumulative L3 Universal repeals, foreign soak-up is US$194.901bn and own IIR/UTPR recapture US$83.073bn. Seven Universal full opt-outs leave US$10.294bn of deviating-host liability unassigned in total. In cumulative L3 SbS, the separate repeals lower source liability by US$99.867bn. Retained reported profit is US$158.818bn and the ordinary source CIT on it is US$6.226bn. Ireland's relief remains 85.9% of net forgone receipts in the cumulative window (critical weight 0.665), and 87.0% in FY2023 (0.655). FY2023 weights are below one for Cyprus, Ireland, Lithuania and Malta. The overlay continues to deliver more modelled relief than repeal in 18 of 27 FY2023 L3 cases. The SBTI methodology and its costs remain outside this revision.

## The two 64-scenario accounting designs

The accounting-off paths retain the core rules. The accounting-on paths rebuild positive profits after the applicable direct purge, current losses and carryforwards. Both ladders use the common Step 12 accounting denominator, so the strict L4 accounting-on results move even when its stand-alone accrued ETR ladder is unchanged. The existing official 64-case accounting switch uses the accrued path. Cash and envelope remain separate conditional Stage 10 projections.

| 2017–2023 EU27, US$bn unless labelled | L3 R09b | L3 R10b | Strict L4 R09b | Strict L4 R10b |
|---|---:|---:|---:|---:|
| Minimum | 62.496 | 63.096 | 62.496 | 63.096 |
| Maximum | 670.667 | 667.064 | 594.015 | 594.015 |
| Preferred Universal, accounting on | 303.834 | 301.719 | 266.308 | 266.878 |
| Preferred SbS, accounting on | 231.135 | 229.653 | 214.751 | 215.321 |
| Measurement Shapley share, % | 45.53 | 45.10 | 42.28 | 42.36 |
| Accounting Shapley share, % | 37.25 | 37.46 | 41.96 | 41.83 |
| Measurement × accounting interaction, % | 3.48 | 3.50 | 2.58 | 2.59 |

Over 2019–2023 the L3 range is now US$26.441–467.535bn and strict L4 US$26.441–451.238bn. For L3 the measurement and accounting mean effects move to +US$215.557bn and −US$171.682bn. Measurement and accounting jointly explain 82.55–89.68% across both ladders and the two longer windows. In Germany and France measurement's L3 Shapley shares are 72.60% and 59.43%, against 12.30% and 15.27% for accounting. In Ireland and Luxembourg the accounting shares are 50.57% and 69.39%, against 31.37% and 5.71% for measurement. The country-level differences support reporting the two choices separately.

## Uncertainty calibration

The reconciliation posterior and draw law are unchanged. Under the revised fiscal point, the profit-only 95% EU27 interval is US$524.79–563.91bn for Universal and US$358.74–372.62bn for SbS. The R09b intervals were US$527.96–567.10bn and US$361.12–375.02bn. The shift follows the changed distributional measurement held fixed across the profit-only draws.

The measurement-error calibration retains 207 share residuals and 207 conditional low-ETR residuals, compared with 361 and 302 in R09b. The raw share residual standard deviation falls from 35.9 to 25.6 percentage points and the low-ETR residual standard deviation from 4.27 to 3.88 points. The residual law remains the same. The standalone measurement simulation perturbs positive-profit host-years with an observed or estimated rate. The joint simulation applies paired residual coordinates to positive-profit hosts using percentile, transported or average tiers. On that common 1,352-host-year universe, the direct count moves from 599 to 356 and the jointly perturbed count from 753 to 996. The direct cohorts shift into fitted and average tiers and a separate set of transport hosts shifts into the average tier. Narrower calibration dispersion on the published overlap is therefore compatible with broader exposure to measurement uncertainty.

The standalone measurement-error study recomputes all 500 draws and the full fiscal design for each draw. It gives behavioural EU27 90% intervals of US$462.97–593.68bn under Universal and US$314.42–397.00bn under SbS. Under R09b the corresponding intervals were US$443.29–591.80bn and US$309.28–402.57bn. The SbS median is US$353.05bn and its width is US$82.58bn, against a median of US$353.76bn and width of US$93.29bn before screening. The mechanical Universal width falls from US$183.97bn to US$158.78bn. These results depend on the observed overlap and the original draw generator.

The joint study uses the same 500 draws, seed, residual pairing, behavioural fit and profit-correction blocks. Its preferred 90% EU27 interval changes from US$338.13–410.73bn to US$337.62–392.76bn over 2017–2023. It changes from US$241.49–264.80bn to US$237.67–259.85bn over 2019–2023. Parameter variance shares change from 1.65% to 1.18% and from 0.41% to 0.44%, respectively. Scenario-spread-to-interval ratios rise from 7.04 to 9.20 and from 15.85 to 16.52. Across the full window, the ETR residual, behavioural coefficient and reconciliation shares of parameter variance are 70.51%, 13.00% and 16.50%. The corresponding shorter-window shares are 3.61%, 27.09% and 69.30%. The increase from approximately 0.01% in the short-window ETR share is consistent with the expansion of fitted and average tiers. The preferred short-window interval still narrows. These are results under the existing simulation law and observed overlap.

## Reproduction procedure

Run from the repository root with the lockfile-matched R 4.6.0 installation, `LC_ALL=en_US.UTF-8` and `TZ=Europe/Amsterdam`. The new processed files are the Stage 01 measure provenance, the two Stage 02 support ledgers, the Stage 03 specification and host-transition diagnostics, and the Stage 10 numerator-support diagnostic. The historical schemas omit these files. The original Table IV extract and upstream Stage 02a model inputs are pinned as before.

```sh
export GMT_UTPR_SPECIFICATION=VERIFIED_PARENT_ONLY
export GMT_BEHAVIOURAL_SPECIFICATION=NO_NOTCH_STANDARD_RESPONSE
export GMT_STATUTORY_RATE_SPECIFICATION=STANDARD_ROLE_SPECIFIC
shasum -a 256 -c tests/step17_raw_inputs.sha256
shasum -a 256 -c tests/r05b_legal_inputs.sha256
GMT_TABLE_IV_SPECIFICATION=LEGACY_PUBLISHED Rscript --vanilla run_all.R --output-root="$historical"
GMT_TABLE_IV_SPECIFICATION=OBSERVED_TWO_SIDED Rscript --vanilla run_all.R --output-root="$revised"
Rscript --vanilla tests/verify_golden_step15.R "$historical" r09b
Rscript --vanilla tests/verify_golden_step15.R "$revised" r10b
GMT_TABLE_IV_SPECIFICATION=LEGACY_PUBLISHED GMT_TEST_OUTPUT_ROOT="$historical" Rscript --vanilla tests/testthat.R
GMT_TABLE_IV_SPECIFICATION=OBSERVED_TWO_SIDED GMT_TEST_OUTPUT_ROOT="$revised" Rscript --vanilla tests/testthat.R
GMT_TABLE_IV_SPECIFICATION=LEGACY_PUBLISHED Rscript --vanilla code/diagnostics/table_iv_observability.R "$comparison" "$historical"
```

The R06b mode also sets `GMT_STATUTORY_RATE_SPECIFICATION=LEGACY_TARGETED`. Use its separate 364-file manifest, with the same continuous behaviour and verified parent-only legal rule. Compile the paper and note using [the replication guide](../../REPLICATION.md#exhibit-only-reproduction-and-latex-builds) and the matching generated tree. Use the source from revision `473ff6f` when checking R09b's historical publication.

An isolated support check verified exact L1, L2 and anchored and strict L4 rate fields, unchanged substance inputs at both endpoints, identical fitted behavioural coefficients and the exact applied coefficient. The 207 common S1 point rates agree exactly and the S2 and S3 validation files retain their bytes. The 128 FY2023 and cumulative core scenario–scope–window receipts in the fiscal shadow match the revised production point within US$0.000123. L3 and strict L4 accounting-off and accounting-on use the same ordered design keys. These checks distinguish the changed measurement from the fixed estimators and policy inputs.

## Acceptance record

On 17 November 2026, both isolated profiles completed all fifteen stages from the pinned inputs using R 4.6.0 and the 68 lockfile-matched packages. All 54 original input hashes and the independent UTPR legal-register hash matched. Each replay computed 500 profit-correction and 500 joint draws, plus 500 standalone measurement draws for all 32 scenarios. Both standalone simulations used fresh per-draw checkpoints after the initiating terminal session ended. The restart used the same production draw function, seeds and ordered aggregation, with a signature covering the code, input hashes, lockfile, environment and specification settings. No frozen simulation output was substituted. All 500 individual R09b measurement draws also matched their prior R09b checkpoints byte-for-byte. Stage 11 freshly evaluated the 432-case repeal and full opt-out design, both 64-case accounting designs and 27 jurisdiction influence cases.

| Gate | Result |
|---|---|
| R10b isolated replay and checkout | Each matched all 373 processed SHA-256 hashes and the exact path set and passed 1,570 expectations. |
| R09b isolated replay | All 367 processed SHA-256 hashes and the path set matched the unchanged manifest. The full suite passed 1,564 expectations. |
| R06b retained replay | All 364 processed SHA-256 hashes and the path set matched the unchanged manifest. The suite passed 1,557 expectations. Fresh execution through Stages 01, 02a, 02 and 03 additionally matched all 99 upstream files byte-for-byte. |
| Table IV and bilateral assembly fixtures | 166 expectations passed against the new reference. The Stage 02 integration fixture now supplies the provenance file in the regime that requires it. |
| Generated exhibits | All 81 TeX files matched an independent R10b generation byte-for-byte and all eight figure PDFs matched with creation and modification fields normalised. The same comparisons passed for R09b against its historical reference. The adopted R10b checkout changes 51 generated TeX files and five figure PDFs. |
| Publication | Independent R10b builds match across 77 paper pages and five research-note pages by page text, decoded content streams, dimensions and font and image resources. All pages were rendered and inspected at overview scale. The bibliography matched byte-for-byte. A historical build from `473ff6f` likewise matches the R09b paper and note. |

All reported test gates finished with zero failures, warnings and skips. In the full revised run, the unchanged Stage 08 country-clustered covariance procedure emitted one `fixest` regularisation warning in the EU27 L3 business-activity regression with affiliate and year fixed effects and parent and affiliate clustered covariance. An isolated repeat reproduced the warning. The associated inference is conditional on regularisation. This diagnostic does not feed the production point or uncertainty draws. The paper build retained an underfull box in a table, with citations and cross-references resolved by TeX. The pre-existing literal Side-by-Side citation is handled separately from the scientific revision.

The [R10b manifest](../../tests/golden_r10b.csv) has SHA-256 `8e6b003d37b1be305874d9445ce84ef9956c2e616e80b35bbfaefeb8460e57e4`. The [per-file comparison](r10b/processed_file_changes.csv) lists all 162 unchanged, 205 revised and six new processed files. The base panel, Table IV cleaned pivot, fitted reconciliation and original published input bytes are among the unchanged files.

The manuscript now states the support rule for current and transported Table IV points, reports validation changes on natural and fixed support, and distinguishes assigned receipts, extinguished amounts and unsupported residuals. Its core and accounting comparisons, standalone and joint uncertainty figures, policy game and matched budget discussion use the revised outputs. Disclosure selection, the joint draw law, the accounting overlap question and the conditional SBTI proxy remain open. A clean-machine restore still requires the four pinned companion extracts documented in the replication guide.
