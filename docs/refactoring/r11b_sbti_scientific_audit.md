# R11b SBTI scientific audit

The starting revision is `f7db342ca726d9ee1539543f0db240c89ad751be` on `publication-rework`. R10b remains the leading scientific reference with `OBSERVED_TWO_SIDED`, `STANDARD_ROLE_SPECIFIC`, `VERIFIED_PARENT_ONLY` and `NO_NOTCH_STANDARD_RESPONSE`. R11b adds an isolated diagnostic and a decision memorandum. Its policy counterfactual concerns a fiscal year starting 1 January 2026 on the FY2017–2023 economic bases. Evidence is evaluated against the project's 15 November 2026 research cutoff, with retrieval on 17 November. The full OECD chapter was read directly and its operative cap and election provisions were visually checked.

## Recommendation for R11c

A scientific revision is warranted. Retain aggregate SBIE, sector allocation and the sectoral SBIE contrast. Move the hybrid capacity overlay into an explicitly conditional supplementary analysis. A leading estimate of actual SBTI adjustment cannot be identified from these inputs. The model can instead report revenue before any imputed QTI adjustment, accompanied by the assumptions that would generate the sensitivity results below. This modelling baseline leaves actual QTI use unresolved.

Replace the manuscript's description of the hybrid maximum as the OECD cap. Preserve the historical proxy as its own reproducible case. In the policy game, present repeal, existing-incentive elections and new incentive expenditure against their respective baselines. The current overlay efficiency is an incidence identity conditional on the direct liability reduction. It cannot establish the expected fiscal efficiency of an incentive programme.

No alternative depreciation rate, election or utilisation percentage is selected as an estimated parameter. R11c should first confirm this decision, then propagate it into the full design, accounting, uncertainty, policy game and publication, with separately versioned results. S06 remains open for that decision.

## Legal mechanism and what can be observed

The January 2026 OECD package is common-approach guidance. Chapter 4's boxed rules, paragraphs 1–8, define an election for a tested group-jurisdiction. Paragraph 4 permits an addition to Adjusted Covered Taxes limited by both the QTIs used and the selected substance cap. Paragraph 6 gives the two cap methods

```text
default       0.055 × max(eligible payroll, eligible depreciation and depletion)
five-year     0.01 × eligible depreciable tangible-asset carrying value
```

The historical proxy takes `max(.055 × proxy payroll, .01 × proxy assets)` in each sector. It combines elements of the two alternatives and changes the aggregation grain. Paragraph 7 restricts the depreciation of assets used under a revoked carrying-value election. The Model Rules' five-year-election definition also constrains revocation and re-election. These conditions preclude annual best-method selection as an ordinary fixed-method case. Paragraph 8 permits the SBTI election for fiscal years commencing from 1 January 2026. [OECD Side-by-Side Package, chapter 4 pp. 70–78](https://www.oecd.org/content/dam/oecd/en/topics/policy-sub-issues/global-minimum-tax/side-by-side-package.pdf#page=70) · [Model Rules, Article 10.1](https://www.oecd.org/content/dam/oecd/en/publications/reports/2021/12/tax-challenges-arising-from-digitalisation-of-the-economy-global-anti-base-erosion-model-rules-pillar-two_eed81a23/782bac33-en.pdf#page=57)

The accompanying [legal classification matrix](r11b/legal_definition_matrix.csv) covers expenditure credits, permanent additional deductions, expenditure-linked exemptions and rates, tangible-production volumes, sales-based benefits, general rate reductions, refundable and transferable credits, grants, non-covered taxes, excluded income and timing-only allowances. Qualification also requires general availability and a benefit based on activity actually undertaken. The value and timing of use differ between credit utilisation and claimed deductions. The expenditure-based benefit ceiling considers the tax incentives on the same expenditure together. Discretionary bargains and benefits restricted to in-scope groups require exclusion under the stated tests. [OECD chapter 4, commentary paragraphs 3–18, 24–29](https://www.oecd.org/content/dam/oecd/en/topics/policy-sub-issues/global-minimum-tax/side-by-side-package.pdf#page=71)

The examples in paragraphs 21–27 require separate treatment of QRTCs/MTTCs, carryforwards and deferred tax. Electing QRTC or MTTC income into QTI treatment changes both income and the tax numerator. The positive-income ordinary-credit shadow below holds income fixed and excludes that reclassification. It also excludes the super-deduction example's negative adjusted taxes, deferred-tax asset and excess negative-tax carryforward. Fixtures check the source examples' arithmetic without claiming a full deferred-tax engine. The underlying income, adjusted covered taxes, ETR and excess-profit calculation follow the boundaries in Articles 3.2.4, 4.1–4.4 and 5.1–5.3. [OECD chapter 4, pp. 75–77](https://www.oecd.org/content/dam/oecd/en/topics/policy-sub-issues/global-minimum-tax/side-by-side-package.pdf#page=75) · [Model Rules, chapters 4–5](https://www.oecd.org/content/dam/oecd/en/publications/reports/2021/12/tax-challenges-arising-from-digitalisation-of-the-economy-global-anti-base-erosion-model-rules-pillar-two_eed81a23/782bac33-en.pdf#page=23) · [Consolidated Commentary 2026, chapters 3–5 and SBTI section](https://www.oecd.org/content/dam/oecd/en/publications/reports/2026/05/tax-challenges-arising-from-the-digitalisation-of-the-economy-consolidated-commentary-to-the-global-anti-base-erosion-model-rules-2026_24289ddf/4377e89f-en.pdf)

### Domestic implementation

Commission Notice C/2026/253 recognises the agreed safe harbours in the Directive's Article 32 context. The Irish Revenue guidance acknowledges that recognition. Ireland's Finance (No. 2) Bill 2026 proposes a specific section 111AKB. The bill's exact publication day was not independently established in this audit, so its register leaves that date blank. The Dutch explanatory memorandum for bill 37 025 proposes commencement in 2027 with retrospective SBTI application from January 2026. Proposals, general recognition and administrative guidance establish different legal facts. Their existence supplies no group-level election or entitlement. [Commission notice](https://eur-lex.europa.eu/eli/C/2026/253/oj/eng/pdf) · [Irish Revenue](https://www.revenue.ie/en/companies-and-charities/pillar-two/dates/index.aspx) · [Irish proposed section 111AKB](https://assets.gov.ie/static/documents/89edf30b/Finance_No._2_Bill_2026.pdf) · [Dutch bill 37 025 explanatory memorandum, pp. 7–8](https://zoek.officielebekendmakingen.nl/kst-1269212.pdf#page=7)

Every fiscal shadow assumes that the particular mechanism is domestically available to the group in the relevant counterfactual, including its QDMTT application. No national SBTI eligibility map is inferred from an IIR/QDMTT listing or from the Commission notice. A compliance claim would require the enacted implementing text, commencement and retroactivity provisions, domestic QDMTT computation, administrative treatment, incentive qualification and the group election and use. R11b is a conditional economic sensitivity.

### Observable inputs

The pinned CbCR provides jurisdictional aggregates over many groups. Its screened headcount, annual wage imputation and tangible-asset amounts are proxies for the legal inputs. FATS and EUKLEMS supply sector weights with their own populations. No individual group identifier or utilisation/election history is available. The [input inventory](r11b/input_availability.csv) distinguishes each observed series, proxy and absent fact.

The pinned EUKLEMS capital and analytical CSVs contain investment and capital stocks with prices and volumes. Their national accounts contain compensation, labour and output measures. The variable-description workbook and the existing processed fields supply no directly usable eligible depreciation or depletion flow. FATS gross investment and global intangible investment have different meanings and coverage. The depreciation-to-stock grid of 0%, 4%, 8%, 12% and 20% is therefore a set of assumptions supplied for this diagnostic. Eligible carrying-value shares of 50%, 75% and 100% are also assumptions. The last value does not identify land or other ineligible assets. Eligible payroll, capitalised employee costs and correct opening/closing carrying values remain unobserved.

## Reproduced baseline and matched support

The unchanged R11a audit reproduces 81 EU27 host-years, 3,240 sector rows at each endpoint and 2,894 finite-activity sectors in 2021–2023. On that support, sector-first hybrid capacity is US$104.494bn and host-first capacity US$79.943bn. The US$24.551bn difference is 30.7% of the latter. Source shares retain their 396 missing profit, 343 missing payroll and 219 missing asset entries. Their available components reconcile with the totals. Reproducing the game gives all 108 strategy rows and the previously reported US$107.987bn L3 and US$111.077bn strict-L4 positive-QDMTT source populations. Rounding-unit comparisons apply when the baseline is read from decimal CSV.

| Cap on common 2021–2023 finite EU27 sector activity, US$bn | Sector first | Country-year first | Parent-country proxy grouping |
|---|---:|---:|---:|
| Historical hybrid | 104.494 | 79.943 | 83.267 |
| Payroll-only | 75.466 | 75.466 | 75.466 |
| Default with 4% depreciation | 80.526 | 75.468 | 76.078 |
| Default with 8% depreciation | 86.840 | 76.274 | 77.506 |
| Default with 12% depreciation | 93.608 | 77.524 | 79.454 |
| Default with 20% depreciation | 107.788 | 80.880 | 84.568 |
| Elective carrying value, 50% eligible | 20.548 | 20.548 | 20.548 |
| Elective carrying value, 75% eligible | 30.823 | 30.823 | 30.823 |
| Elective carrying value, 100% eligible | 41.097 | 41.097 | 41.097 |

The parent-country comparison allocates the same finite-support totals to the observed parent-country keys using separately normalised non-negative component weights. This makes the crossed support identical and avoids attributing a coverage change to grouping. It is a reconstruction of that supported activity. A separate `observed_parent_capacity.csv` uses the native complete non-negative bilateral inputs and their host aggregates, with its own scope and support counts. Neither grouping supplies an individual MNE observation or a legal bound. The main crossed output checks equality of payroll, assets, known profit and known post-SBIE exposure across all three groupings.

The support audit also finds signed asset values on 28 positive-profit bilateral rows, eight in EU27 hosts. They carry US$60.511bn of global profit and US$8.736bn of pre-SBIE L3 liability. Their reported asset total is −US$12.297bn. Stage 04 retains that signed input, while the existing game explicitly floors its activity inputs at zero. Native legal-style non-negative capacity comparisons exclude such rows and declare their support. The common-support reconstruction uses non-negative weights without changing its fixed sector totals. This technical and measurement boundary requires examination before interpreting a cap on those records.

At an 8% assumed stock ratio the finite-support implied depreciation is US$328.775bn. Depreciation dominates in 404 sector cells but only eight host-years. At 20%, it dominates in 750 sectors and 20 host-years. The default's sector-minus-host difference is US$10.566bn at 8%, compared with US$24.551bn for the hybrid. Their interaction is −US$13.984bn. The linear carrying-value formula has no such maximum-aggregation effect on identical eligible activity. These comparisons concern capacity before QTI use and top-up caps.

## Missing activity and zero-profit sectors

Global positive-profit payroll missingness affects 1,511 cells, US$1,583.434bn of profit and US$185.086bn of pre-SBIE L3 liability. Four positive-profit cells lack assets. Only three EU27 positive-profit cells lack payroll. A separate provenance ledger distinguishes missing wages, missing headcount, zeros in the wage/headcount proxy and stale wage sources. A zero payroll proxy does not establish a genuine legal zero.

Exact-year ILO nominal-USD hourly earnings support an alternative for eight missing-payroll cells with headcount, under an assumed 2,000-hour year. No EU27 missing-payroll cell receives this replacement. It adds US$0.495bn of payroll on the supported subset, while 1,503 global cases remain unresolved. Available-data-only results expose missing outcomes and supported subtotals. Additional donor scenarios use the 25th and 75th percentiles of the existing positive payroll/profit ratio. They fill remaining gaps under declared ratios, without claiming bounds or estimates. In the missing global cells, initial post-SBIE source liability moves from US$177.673bn under zero contribution to US$176.635bn and US$163.001bn respectively. The EU27 equivalents move from US$1.291m to US$1.283m and US$1.177m.

The wage sensitivity separately records SBTI capacity and overlay exposure with SBIE fixed, then with SBIE recomputed. The sectoral sensitivity changes host payroll before applying its original shares. Available-data cases retain an unknown total whenever a required payroll component is unresolved. None of these alternatives enters the cap-formula or fiscal-policy cases automatically.

The 132 zero-profit sectors with positive activity carry US$1.017bn of measured capacity in R11a. The matched capacity matrix both retains and excludes their activity, and keeps profit-unknown sectors separately visible. Removing activity merely because its allocated sector profit is zero imposes a different group-aggregation assumption. Retaining it in capacity also supplies no automatic recipient for relief. The direct model uses undefined ratios at those sector denominators, so capacity and its application require separate reporting. Real estate, trade and computer/information services concentrate 43.2% of the sector-first hybrid capacity.

The hypothetical direct-overlay ceiling on known post-SBIE exposure is also exported by cap formula and aggregation. For the retained-activity sector grouping it is US$41.142bn under the hybrid, US$38.299bn under the assumed default-8% cap and US$10.249bn under the 75%-eligible carrying cap. These ceilings use compatible sector keys and omit unknown amounts explicitly. They remain hypothetical direct-capacity applications and have different coverage from the R3 positive-QDMTT game.

## Covered taxes, QTI use and fiscal accounts

For positive income `I`, covered taxes `T`, fixed SBIE `S`, and allowed addition `A`, the stylised calculation uses

```text
excess        max(I − S, 0)
top-up        max(.15 − T/I, 0) × excess
addition      min(QTI used, selected cap), conditional on election
relief        original top-up − recalculated top-up using T + addition
```

For income 100, taxes zero, SBIE 20 and addition 10, top-up falls from 12 to 4. The relief is eight. Above the zero-top-up boundary the relation is nonlinear. The source shadow applies this illustration to inferred low-profit and tax bases, retains fixed adoption behaviour and uses the original detailed allocator. It excludes negative adjusted taxes, deferred taxes, group blending and QRTC/MTTC income reclassification. It is an ordinary-credit illustration conditional on the supplied proxy fields.

For existing incentives, reported taxes already include the prior tax reduction, so this counterfactual adds the permitted amount once. Its incremental ordinary-CIT expenditure is zero. For new ordinary credits, utilisation is capped at the imputed available covered taxes, with the credit deducted before the SBTI add-back. When the add-back fully offsets that deduction, top-up remains at its no-new-incentive baseline and ordinary CIT expenditure remains positive. Without the election, increased top-up partly recaptures the new credit. The historical direct overlay instead subtracts dollar capacity from dollar top-up subject to its cap and behavioural factor.

### R3 Side-by-Side on matched 2021–2023 sources

| Assumption, US$bn | L3 cap | L3 QTI used | L3 covered-tax addition | L3 assigned-receipt decrease | Strict-L4 decrease |
|---|---:|---:|---:|---:|---:|
| No assumed use | 31.386 | 0 | 0 | 0 | 0 |
| Historical direct overlay | 31.386 | 0 | 0 | 16.469 | 16.447 |
| Existing QTI, 25% of sector hybrid | 31.386 | 7.847 | 7.847 | 4.458 | 4.631 |
| Existing QTI, 50% of sector hybrid | 31.386 | 15.693 | 15.693 | 8.158 | 8.445 |
| Existing QTI, 100% of sector hybrid | 31.386 | 31.386 | 31.386 | 14.324 | 14.590 |
| Existing QTI, 100% of parent-country hybrid | 24.444 | 24.444 | 24.444 | 14.977 | 15.693 |
| Existing QTI, 50% of default with 8% depreciation | 21.532 | 10.766 | 10.766 | 6.913 | 7.206 |
| Existing QTI, 50% of elective 75%-eligible stock | 11.263 | 5.632 | 5.632 | 3.502 | 3.801 |
| Existing QTI, fixed US$1m per positive source cell | 21.532 | 1.492 | 0.955 | 0.639 | 0.535 |
| New credit, 100% of sector hybrid capacity | 31.386 | 19.144 | 19.144 | 0 | 0 |

The final row spends US$19.144bn of ordinary CIT under L3 and US$20.093bn under strict L4. The existing-use rows have no incremental expenditure in their stated baseline. In R3 the affected sources remain domestic QDMTT sources, so the decrease accrues to EU27 QDMTT with zero foreign IIR/UTPR recapture. This follows the assumed scope and liability channel.

In R1, existing use at 50% of the default-8% parent-country cap reduces L3 source liability after the fixed response by US$6.915bn. QDMTT, IIR and assigned UTPR decrease by US$6.837bn, US$0.030bn and US$0.032bn. Global assigned receipts decrease by US$6.899bn and EU27 receipts by US$6.889bn. Extinction decreases by US$0.016bn, with unsupported pools unchanged at US$0.685bn over the stated window. The corresponding elective-stock source and global assigned decreases are US$3.504bn and US$3.493bn, with EU27 receipts down US$3.488bn. New credits under the default case spend US$10.490bn without decreasing baseline top-up. These sensitivities concern the preferred distributional initial-rate SbS branches and their 2021–2023 supported EU27 sources.

## Factor 2, variance and the repeal comparison

The diagnostic retains the 32-case core and separate 64-case design. It first reproduces their legacy amounts. The no-use arm changes the overlay contrast while preserving sectoral SBIE. Alternative default-8% and carrying-75% cases assume 50% use on the existing sector support and recompute the gap through covered taxes before applying the shield. They retain the original contemporaneous/2022/neutral bridge and reapply the existing response and routing. They are conditional mechanism sensitivities and have a different cap application from the parent-country policy-game cases above.

| FY2017–2023 Shapley share, % | Legacy | No use | Default-8%, half use | Elective-75%, half use |
|---|---:|---:|---:|---:|
| Bundled core Factor 2 | 3.569 | 0.143 | 0.534 | 0.124 |
| Sector-only part in split design | 0.192 | 0.143 | 0.164 | 0.179 |
| SBTI part in split design | 4.892 | 0 | 1.047 | 0.158 |

The source and collector interaction contrasts are exported separately by year. Their weights and total sums of squares differ across the core and split designs. A capacity change therefore does not translate proportionately into its variance contribution. A zero-use SBTI axis is redundant in the 64-case diagnostic, as its exact off-diagonal equality test confirms.

The no-use core comparison has a US$196.277–673.405bn EU27 range, against the frozen US$159.750–667.064bn. The aggregate-SBIE preferred branch is unaffected by this Factor 2 sensitivity and retains US$367.670bn of cumulative SbS EU27 receipts. In the sector-plus-incentive branch the corresponding collector amount moves from US$326.104bn under the hybrid to US$378.647bn without imputed use, US$355.503bn under the default-8% half-use case and US$373.133bn under the elective-75% half-use case. These are conditional design values. They do not replace the official core outputs.

For FY2023 L3, the historical overlay exceeds repeal's modelled top-up relief in 18 countries. Existing-incentive use at 25%, 50% and 100% of the sector hybrid gives counts of four, 13 and 18. The default-8% half-use case gives 11 and the elective-75% half-use case three. Their total reliefs are US$2.380bn and US$1.186bn, compared with the legacy US$5.632bn. No use gives zero. Irish repeal gives US$4.573bn of modelled relief, compared with US$0.436bn under the direct overlay, US$0.393bn under full hybrid covered-tax use and US$0.148bn under the default-8% half-use case.

Within the existing-incentive QDMTT-only arms, foregone domestic receipts equal the incremental top-up saving by construction. New incentives require their ordinary CIT expenditure in the fiscal denominator. The existing repeal arm retains its foreign recapture, source-CIT and reported-profit response, and welfare threshold. The fixed-response incentive shadow has zero incremental retained profit and an undefined retained-profit welfare threshold. That asymmetry limits the policy ranking. It does not establish that qualifying incentives have no real investment or profit-location effects. A programme-specific welfare comparison requires those effects and programme financing on a consistent base.

## R11c scope

| Operation | Recommended controlled decision |
|---|---|
| Aggregate and sectoral SBIE | Retain the extracted calculations, endpoint coefficients, support metadata and share construction. Review signed-input quality separately before any empirical correction. |
| Leading SBTI adjustment | Use a revenue reference before an imputed QTI adjustment if the R11c review approves this choice. Actual adjustment remains unidentified. |
| Hybrid maximum and H5 | Retain as a clearly described mechanical-capacity sensitivity with its original arithmetic. Revise any legal interpretation of that proxy. |
| Independent-factor design | Preserve the historical six-factor comparison. Present alternative use and cap contrasts conditionally. A zero-use SBTI switch supplies duplicate cells and no independent variance. |
| Incentive policy game | Use a covered-tax recalculation for the stated ordinary-credit examples and report incentive expenditure separately. Retain direct overlay as a hypothetical case. A defensible predicted policy benefit needs programme and behavioural evidence. |
| Numerator and deferred-tax mechanisms | Keep QRTC/MTTC elections and loss/deferred-tax examples outside this simplified engine until their own income and tax accounting is implemented and characterised. |

1. Agree whether leading Factor 2 should retain only the sectoral SBIE contrast, with SBTI shown as explicitly conditional supplementary scenarios. Define any no-imputed-adjustment reference without claiming actual QTI use is zero.
2. Preserve the current proxy and all historical references. Add a named future production specification only after the scientific choice is approved. No depreciation or take-up point estimate follows from R11b.
3. If adopted, rerun the core, independent split, both accounting designs, all three uncertainty exercises, fiscal allocation and all repeal/incentive comparisons. Rebuild every manuscript exhibit and revise Sections 2.1, 4.3, 5.1, 6.3 and Appendix B/E, including the cap formula and conditional policy conclusions. Report headline changes and version the new freeze separately.
4. Retain the group-level, domestic-implementation, missing-activity, asset-eligibility and QTI-use limitations. S07, S08 and S10 and the Stage 08 covariance issue retain their own controlled workstreams.

## Reproduction and verification

From the root, use the locked R 4.6.0 environment and the four unchanged leading settings. The optional script accepts the input root and a fresh audit directory. It rejects production data, publication and Git destinations. It writes the matched support, parameter, source, collector and decision evidence independently of the fifteen-stage pipeline.

```sh
Rscript --vanilla code/diagnostics/sbti_scientific_audit.R "$PWD" "$audit_one"
Rscript --vanilla code/diagnostics/sbti_scientific_audit.R "$PWD" "$audit_two"
diff -r "$audit_one" "$audit_two"
shasum -a 256 -c tests/step17_raw_inputs.sha256
shasum -a 256 -c tests/r05b_legal_inputs.sha256
Rscript --vanilla tests/verify_golden_step15.R "$PWD" r10b
Rscript --vanilla tests/testthat.R
```

Deterministic evidence is stored under [the R11b audit directory](r11b). `source_ledger.csv` and `collector_ledger.csv` preserve the fiscal keys and stages. `capacity_by_host_year.csv` holds the crossed formula and grouping design, including zero-profit treatments. `factor_variance.csv` and `factor_contrasts.csv` retain the two attribution designs. Missingness studies have their own supported subtotals and counts. The frozen-input hashes, source register and exact parameter labels accompany the outputs.

### Completed acceptance record

Two fresh executions reproduce all 27 CSV files byte-for-byte, including the nested R11a audit, 44,863 fiscal source rows, 11,032 collector rows, 1,404 country-window incentive comparisons and the original 108 strategy rows. A [diagnostic-only checksum list](r11b/diagnostic_outputs.sha256) verifies those files independently of the scientific freeze. It is a record of this isolated audit.

The complete tracked suite passes **1,761 expectations**, with zero failures, warnings or skips. The focused suite covering the new audit, Stage 04, substance fixtures, Stage 05, decomposition, collector routing and source safety passes **454 expectations**. The current source matrix fixtures include the 100-income example, fixed election constraints, credit tax values and the QRTC and loss illustrations. Empirical cap-summary assertions additionally check that a stated direct-relief ceiling cannot exceed its associated dollar cap. Reproduction of historical game amounts from a decimal CSV permits four binary64 rounding units, separately from exact production hashes. Neither an empirical golden expectation nor an existing scientific tolerance was revised.

All **54 original input hashes**, the separate UTPR legal-register hash and the exact **373-file R10b path set and hashes** pass. The R10b manifest digest stays `8e6b003d37b1be305874d9445ce84ef9956c2e616e80b35bbfaefeb8460e57e4`. Retained R09b and R06b references also verify their 367 and 364 files. Git comparison against the starting revision confirms identical production modules, shared substance kernels, raw and processed data, historical and leading manifests, manuscript and publication artefacts. All source-only audit imports pass the existing isolation gate.

A full fifteen-stage replay is unnecessary for this isolated diagnostic because the production entry points and computational semantics match the starting revision. R11a's completed full replay remains its production verification reference. The audit explicitly recalculates the matched capacity, source and collector shadows and core and split point comparisons. No Monte Carlo run or official exhibit regeneration is used to validate a provisional alternative. The existing Stage 08 covariance-regularisation issue remains deferred to R12. The replication deposit still requires the four pinned companion extracts identified in the replication guide.
