# Data preparation logbook

This document tracks the data and methodology decisions made in the analysis pipeline. Each entry describes what was done in economic and policy terms; programming detail belongs in the scripts and their diagnostic output, not here.

## 2026-04-20 - Stage 1 execution and measurement alignment

This entry records the corrected rerun of Stage 1 through `code/03_stage1_etr.R` after the audit of the first implementation. The script now produces the same two core outputs as before, `data/processed/stage1_affiliate_year.rds` and `data/processed/stage1_bilateral_panel.rds`, but the coverage diagnostics and validation objects now align properly with the written methodology. The pure Stage 1 tests were rerun and passed after the corrections.

The first correction concerns how Table I percentiles are pooled across parents. The earlier implementation mixed Panel A-I and panel-agnostic `_T` percentiles inside the same affiliate-year whenever both happened to be present. That is not the intended measurement rule. The revised Stage 1 keeps a single statistical source for each affiliate-year. EU affiliate-years in 2021 and 2022 now use Panel A-I only; non-EU affiliate-years use Panel A-I where available and fall back to `_T` only when Panel A-I is absent. Realised percentile coverage remains 410 affiliate-years, but it is now split cleanly into 54 EU Panel A-I cells, 316 non-EU Panel A-I cells, and 40 non-EU `_T` fallback cells. This matters mainly for interpretation: the EU branch is now fully consistent with the profit-maker denominator used in the jurisdiction-average ETR.

The second correction concerns the conditioning and location-shift stage of the percentile fit. Under the cleaned single-source rule, 176 affiliate-years require conditioning before the five-percentile distribution can be fitted, rather than the 217 cases reported in the earlier draft note. The boundary of the admissible shift is hit in 21 affiliate-years. In 19 of those cases the target mean remains attainable after conditioning; in two cases, São Tomé and Príncipe in 2021 and Suriname in 2021, the target mean is exactly 1 while the fitted mixture cannot exceed 0.975 because the upper tail is represented as a point mass at the 95th percentile. The methodology should therefore describe the shift as a bounded mean-reconciliation step, not as an exact equality in every realised cell.

The third correction concerns the Bracket-Share Panel Imputation. The first implementation treated affiliates with no 2021-2022 validation window as if their validation profile were a zero vector, which mechanically generated a total-variation distance of 0.5 and wrongly classified some anchor-only affiliates as unstable. The revised script computes BSPI instability only for affiliates observed in both the 2019-2020 anchor window and the 2021-2022 validation window. The corrected counts are 124 distinct anchor affiliates, 117 affiliates with genuine validation support, and 13 affiliates above the pre-registered instability threshold of 0.39. In the EU27, only Lithuania, Croatia, and Greece exceed the threshold. The strict robustness branch now reassigns 26 shape-transport affiliate-years across 13 affiliates to the jurisdiction-average rule, of which 6 affiliate-years across 3 affiliates lie inside the EU sample. The earlier figures of 744 anchors, 120 high-instability affiliates, and 40 strict-fallback affiliate-years were row counts or support artefacts and should not be reused.

The direct Table IV branch remains conceptually unchanged, but its interpretation is now sharper. Stage 1 continues to treat the full positive-profit Table IV partition as direct evidence, so an affiliate-year with `RATE_15` but no `RATE_0-15` row is read correctly as a zero-low-tax-share case rather than as missing information. Direct coverage therefore remains 479 affiliate-years in 2019-2022, of which 78 are zero-low-share cases. This is economically important because excluding those cells would tilt the overlap sample toward affiliates that are already visibly low-taxed.

The cross-validation object is now complete enough to support the methods chapter. On the 239 positive-profit affiliate-years observed in both the percentile and direct Table IV data, the percentile fit overstates the low-taxed share by 0.134 on average and the Stage 1 liability rate by 0.0168. The paired Wilcoxon p-values are `1.11e-07` for the low-tax share and `1.51e-09` for the liability rate. The positive-partition total-variation distance remains large, with mean 0.502 and median 0.543. For the EU overlap sample alone, which contains 54 affiliate-years, the mean low-tax-share difference is 0.192, the mean liability-rate difference is 0.0261, and the mean total-variation distance is 0.430. The practical reading is unchanged: the percentile fit is not a neutral recovery of Table IV and should be presented as a fallback approximation, not as an observational equivalent.

The missing third cross-validation test has now also been implemented. The relative Stage 1 liability difference between the percentile and direct branches is regressed on the percentile interquartile range with year fixed effects on the overlap cells where the direct liability is positive. The estimation sample contains 199 affiliate-years. The coefficient on the ETR interquartile range is 2.17 with a p-value of 0.729 and an `R²` of 0.009. At present there is therefore no empirical basis for an IQR-based correction factor for the non-EU extension. The dispersion measure remains descriptively useful, but the data do not support the stronger claim that wider within-jurisdiction ETR dispersion systematically predicts relative Stage 1 revenue bias once year effects are absorbed.

The main substantive Stage 1 result for the EU27 survives these corrections. In every year from 2017 to 2022, the distributional Stage 1 liability rate remains above the jurisdiction-average liability rate. For the EU27 affiliate-year sample, the jurisdiction-average branch yields a profit-weighted Stage 1 liability rate of 4.52 per cent in 2017 and 1.79 per cent in 2022; the distributional branch yields 5.58 per cent in 2017 and 3.64 per cent in 2022. The measurement corrections therefore change how confidently this result can be defended, not the direction of the result itself.

One final clarification remains important for the methodology chapter. Public Table IV does not observe double-counting corrections within each ETR bracket. The implemented direct branch therefore continues to use raw Table IV bracket shares and bracket-level mean ETRs, then applies those Stage 1 objects to the corrected bilateral profit base `π*`. Any sentence in the thesis implying that corrected profit is directly observed within each Table IV bracket would still be too strong. The methodology text should also be updated to reflect the corrected distinct-affiliate counts and the revised statement that only three EU affiliates, not five, breach the BSPI instability threshold in the realised sample.

## 2026-04-20 - Reproducibility and readiness re-audit of Steps 1 and 2

This entry supersedes the numeric claims in the 2026-04-19 audit after rerunning `01_data_cleaning.R`, `02_base_correction_and_merging.R`, and `02b_base_panel_appendix_tables.R` on 20 April 2026.

The rerun confirms that the pipeline executes end to end, but it also revealed four issues that had to be corrected before Stage 1 or the behavioural module should be treated as ready. First, Step 1 had been reading the OECD hourly earnings file as if `TIME_PERIOD` were an integer year. In that file the time index is monthly, in `YYYY-MM` form. The cleaned object now preserves the monthly period and a derived year, so the hourly wage series is no longer silently corrupted in the intermediate data.

Second, Step 2 had been publishing a mislabeled diagnostic. The file `diagnostics/step2_payroll_plausibility_by_year.csv` did not describe payroll plausibility; it reported accumulated earnings. The pipeline now writes a genuine payroll-plausibility series based on raw and screened wage-based payroll proxies, and the accumulated-earnings audit is written separately to `diagnostics/step2_accumulated_earnings_by_year.csv`.

Third, the BSPI shape-stability validation was too permissive. The comment stated that validation should be calculated only for affiliates observed in both the 2019-2020 anchor window and the 2021-2022 validation window, but the code had also been including one-sided cases. The diagnostic now restricts the sample to overlapping affiliates and records the number of observed years in each window. This matters because total-variation distances of 0.5 or 1 in one-sided cases look like instability when they are actually missing-support artefacts.

Fourth, the audit showed that Table III should not be interpreted as a bilateral low-tax share. Table III assigns entities to ETR brackets using the parent-MNE ETR rather than the subsidiary ETR, so its `RATE_0-15` profit can exceed bilateral Panel A-I profit. This occurs in 87 pair-year cells and reaches a ratio of about 400 in the Chile domestic 2020 observation. The merged panel therefore now labels this object as a ratio diagnostic rather than as a share. Table IV remains the direct low-tax benchmark.

The updated rerun produces 16,915 pair-year cells, 9,572 behavioural-ready cells, 1,871 percentile-ready cells, 2,438 Stage 1 hybrid-ready cells, and 49 bilateral cross-validation cells. At affiliate-year level, 2021 and 2022 contain 370 affiliate-years with a complete Panel A-I percentile set, 410 with either Panel A-I or `_T` percentiles, and 199 with both a percentile source and a Table IV observation. The narrow employee screen still affects only 9 cells, all in 2022.

One remaining limitation is now explicit rather than implicit. The wage proxy sometimes relies on a temporally distant nearest observation. There are 612 pair-year cells with a wage-year gap above 5 years, including 316 rows in the behavioural estimation sample and 110 rows in the Stage 1 hybrid sample. These rows are not dropped in Step 2 because the alternative would be to discard country coverage rather than to correct a data error. They are now flagged in the merged panel and in `diagnostics/step2_wage_match_quality_by_year.csv`, and Stage 3 should report a sensitivity exercise that excludes them.

The practical implication is clear. The data-preparation pipeline is now reproducible and internally coherent enough to begin methodology execution, but only with three explicit conditions carried forward. Stage 1 should rely on Table IV as the direct benchmark and not on Table III ratios. Behavioural estimation should report a robustness check excluding stale wage matches. The written methodology and appendix text must also be aligned with the current data outputs before interpretation, because several narrative passages in `writing/thesisv2.tex` still report older sample sizes and older variable definitions.

## 2026-04-19 - Pre-methodology audit of Steps 1 and 2

This entry supersedes all earlier references in this logbook to observed CbCR payroll or to CbCR `EARNINGS` as a labour-cost measure. The audit was triggered by a full review of `01_data_cleaning.R`, `02_base_correction_and_merging.R`, the merged outputs, and the appendix tables before moving on to the methodology itself.

### Central correction: CbCR `EARNINGS` are accumulated earnings, not payroll

The decisive factual error in the earlier Step 2 construction was conceptual rather than computational. The OECD describes the CbCR template as containing stated capital, accumulated earnings, number of employees, and tangible assets. It does not provide a payroll variable. The previous pipeline had treated the CbCR measure code `EARNINGS` as if it were labour compensation, which then fed directly into the SBIE, the behavioural regressions, and the appendix tables. That interpretation was wrong.

Step 1 now renames the CbCR `EARNINGS` measure to `accumulated_earnings` in the cleaned tables, so the data no longer invite the same mistake. Step 2 no longer treats any CbCR monetary field as observed payroll. Instead, the SBIE payroll input is now an explicit wage-based proxy, constructed as employee counts times the affiliate-jurisdiction annual wage benchmark. The appendix tables have been regenerated so they describe this variable correctly. The same point must now also be reflected in the thesis text before the methodology chapter is executed or interpreted.

This repair removes the original measurement error, but it also changes the interpretation of Stage 2. The payroll leg of the SBIE is now a second-best proxy rather than an observed tax-administration measure. That is methodologically defensible given the public data constraint, but it is not innocuous. Any claim that the thesis observes bilateral payroll directly from CbCR would now be false and should not appear in the written chapter.

### Second correction: a narrow employee-count screen was required

Once payroll was rebuilt from employee counts, a second data problem became visible. A very small number of pair-year cells carry employee counts that are impossible on any plausible reading of the bilateral data. The most obvious cases sit in the 2022 Romanian disclosure wave, including Romania-Israel with more than 41 million employees and Romania-United States with more than 52 million employees. These are not just large numbers. They imply millions of employees per reported constituent entity, and in one case they exceed the host-country population.

The response is deliberately narrow. Employee counts are now screened only when they exceed a conservative plausibility cap defined as the lower of host-country population and 100,000 employees per reported constituent entity. This affects 9 of the 16,915 pair-year cells, all in 2022. The rest of the panel is left untouched. This is preferable to broad winsorisation because the problem is highly concentrated and clearly tied to an identifiable disclosure anomaly rather than to a diffuse heavy tail.

The consequence is economically important. Before the screen, the wage-based payroll proxy inherited the impossible Romanian employee counts and generated trillion-dollar payroll bases for several small foreign legs. After the screen, the largest payroll proxies are large domestic economies such as the United States rather than implausible foreign outliers. The employee screen therefore protects both the SBIE base and the later labour control in the behavioural regressions without rewriting the bulk of the sample.

### Readiness must be separated by stage

The earlier `has_estimation_inputs` flag overstated readiness because it captured only the broad Hines-Rice regression requirements and ignored the narrower data requirements of Stage 1. The merged panel now separates these objects explicitly. The behavioural estimation sample contains 9,935 pair-year cells. The narrower Stage 1 hybrid-ready sample contains 2,512 pair-year cells. The direct pair-year overlap used for simultaneous percentile and Table IV information contains only 49 cells, but that is not the relevant aggregation level for Stage 1 itself.

Stage 1 works at the affiliate-year level after pooling across parents, and the new diagnostic file `diagnostics/step2_stage1_affiliate_year_coverage.csv` makes that visible. For 2021 and 2022 together, the global sample contains 370 affiliate-years with a complete Panel A-I percentile set, 410 affiliate-years with either Panel A-I or `_T` percentiles, and 199 affiliate-years with both a usable percentile source and a bilateral Table IV observation. For the EU-27, all 54 affiliate-years in 2021 and 2022 have a complete Panel A-I percentile set and all 54 also sit in the percentile-Table IV overlap. That is the economically relevant Stage 1 coverage statement; the 49 pair-year overlap in the bilateral base panel should not be confused with it.

### Supplementary controls and what is now genuinely ready

The statutory-tax-rate coverage diagnosis has also been tightened. The earlier appendix used only the OECD `top_all` combined statutory rate, which made coverage look much worse than it really is. The merged panel now carries a headline statutory CIT measure that uses the combined rate where available and otherwise falls back to the standard statutory rate. Coverage rises from 2,766 to 13,818 pair-year cells under this economically sensible cascade.

The new diagnostics show that the base panel is now technically ready for the behavioural estimation step, conditional on the thesis accepting the wage-based payroll proxy and the narrow employee screen. The panel is also ready for the hybrid Stage 1 design on its actual support: Table IV direct information from 2019 onward, and percentile-based information from 2021 onward. What is not solved by more cleaning is the structural limitation of the source itself. The distributional branch of Stage 1 remains a 2021-2022 exercise because the OECD do not publish percentiles before 2021. The raw ETR tail also remains economically awkward rather than mechanically wrong: 703 pair-year cells have negative raw Panel A-I ETRs and 117 exceed 100 per cent. Those observations should not be "cleaned away" in Step 2, but the later Stage 3 bounding and winsorisation rules must be implemented exactly as planned before any behavioural estimation or revenue simulation is treated as final.

### Files refreshed by this audit

`01_data_cleaning.R` now carries the corrected `accumulated_earnings` naming. `02_base_correction_and_merging.R` now constructs wage-based payroll, applies the narrow employee screen, records stage-specific readiness flags, and writes three new diagnostics: `step2_employee_plausibility_by_year.csv`, `step2_stage_readiness_by_year.csv`, and `step2_stage1_affiliate_year_coverage.csv`. The appendix fragment `writing/generated/base_panel_appendix_tables.tex` has been regenerated so that the descriptive tables no longer describe non-existent observed payroll data. These are the versions that should be treated as authoritative for the methodology chapter going forward.

## 2026-04-18 — Step 1: data cleaning (`code/01_data_cleaning.R`)

### CbCR Tables I–VI

The CbCR is delivered in long, SDMX format. Each table is restructured into one row per economic unit:

- **Table I** — one row per (parent, affiliate, year). Each financial measure becomes its own column. Where the OECD reports both Panel A-I (profit-makers, the ETR denominator) and Panel A-II (all entities, including loss-makers), the two are kept side by side (`profit_panelai`, `profit_panelaii`, etc.). The within-jurisdiction ETR percentiles (P5, P25, P50, P75, P95) become five columns; they too are kept separately for Panel A-I, Panel A-II, and the panel-agnostic `_T` view, so downstream can pick the percentile series consistent with whichever ETR denominator the methodology selects.
- **Table II** — same shape as Table I but with interquartile means.
- **Table III** — one row per (parent, affiliate, year, ETR bracket) at the MNE-group level.
- **Table IV** — one row per (parent, affiliate, year, ETR bracket) at the subsidiary level. This is the table that observes the GMT-relevant `RATE_0-15` profit mass directly. Table IV reports a single profit panel.
- **Table V** — one row per (parent, year), with revenue percentiles as columns to characterise the MNE size distribution.
- **Table VI** — one row per (parent, affiliate, year, MNE size class), 2022 only.

### Descriptive flags raised by the CbCR cleaning

- **Reporting expansion confirmed.** Parent jurisdictions in Table I  rise from 26 in 2016 to 54 in 2022 (full coverage matrix in `diagnostics/cbcr_t1_parent_coverage_by_year.csv`). The seven-year panel is therefore strongly unbalanced; later identification work needs bilateral fixed effects rather than a simple pooled cross section.
- **EU-27 coverage is complete.** All 27 EU Member States appear as  affiliate jurisdictions in both Table I and Table IV, confirming that the EU-focused sectoral analysis has full source coverage on both the distributional fit and the direct subsidiary-level bracket.
- **Adjusted profit is far sparser than the OECD documentation suggests.** `PROFIT_ADJ` (the OECD's intra-group dividend-corrected profit) is essentially absent before 2021. Even in 2021 only 32 of ~3,200 (parent, affiliate, year) cells have a non-NA Panel A-I value; in 2022 only one. The methodology's holding-company-based correction model in §4.5 is therefore not optional polish: the empirical data simply do not provide a clean adjusted profit series, and the prediction model carries the bulk of the workload.
- **ETR percentiles on Panel A-I are missing for 83% of cells.** The Panel A-I percentile series — the methodology's preferred input to the Stage 1 distributional fit — is therefore much sparser than Table I's headline financial coverage. Decisions about whether to fall back on the `_T` percentile series in cells where Panel A-I is unavailable will need to be made before Stage 1.
- **Zero and negative profits.** Panel A-I has 82 cells with reported  zero profit and zero cells with reported negative profit (negative  values are mechanically excluded by the panel definition, which is  the point of A-I). The 82 zero-profit cells will divide-by-zero in any naive ETR calculation; Stage 1 needs an explicit handling rule consistent with how the GloBE rules treat losses.
- **Switzerland anomaly in Table IV.** The CHE row in the  `RATE_0-15` bracket reports profit roughly two orders of magnitude  above the corresponding Table I aggregate in 2020 and 2022 (see `diagnostics/cbcr_t4_switzerland_flag.csv`). This is the previously documented Switzerland reporting issue. The cleaning step flags but does not drop CHE; downstream scripts decide whether to exclude CHE in those years from the EU sample.

### Eurostat inward FATS

The combined download is split at the 2021 structural break:

- **`fats_pre2021.rds`** — legacy `fats_g1b_08` series (2008–2020) with a single broad activity aggregate. Retained for descriptive trend work only.
- **`fats_post2021.rds`** — `fats_activ` series (2021 onwards) with NACE-detailed activities and 19 standardised sectoral indicators. This is the basis for the sectoral SBIE decomposition in §6.

All 27 EU Member States are present as reporting economies in the post-2021 series. Per-country, per-year NACE coverage is in `diagnostics/fats_post2021_eu27_coverage.csv` and will be the benchmark for any "drop-vs-impute" decision on missing sector cells in the Stage 2 work.

### Supplementary datasets

Each is cleaned to a tidy, downstream-friendly shape:

- **OECD statutory CIT rates** — filtered to the headline `CIT`  measure code, kept wide on the `TARGETING` dimension so that the  standard rate and the top-all (central + sub-central) rate sit in   separate columns. 144 jurisdictions, 2000–2025.
- **OECD combined dividend rates** — kept long because the file carries multiple dividend-related measure codes that downstream  analysis may want to recombine.
- **OECD forward-looking ETRs** — the three scenarios (baseline, income incentives, expenditure incentives) are stacked long with a scenario key.
- **OECD average annual wages** — filtered to the `WG` measure with `MEAN` aggregation, all currencies kept (PPP USD, USD, local currency) so the imputation step can choose the right comparator.
- **OECD hourly earnings, ILO monthly and hourly earnings** — kept long; downstream picks the country / sector / currency slice required for payroll imputation.
- **World Bank** — income classifications, GDP per capita, and population. Aggregate rows (region groupings) are split out into `wb_aggregates.rds`. The GDP and population files are shipped by the WB API with the column header `iso3` but populated with ISO2 codes; the cleaning step joins them back to the country list on ISO2 and attaches the proper ISO3 jurisdiction code.
- **PwC Pillar Two tracker** — leading byte-order mark and trailing   empty columns stripped; one row per (territory, requirement). 53  territories.
- **OECD BEPS rules** — five rule files (CFC, interest limitation, IP  regimes, hybrid mismatch, mandatory disclosure) stacked long with a  `rule` key. The CbCR Action 13 implementation file ships with a   different schema (no time series) and is saved separately as  `cbcr_requirements.rds`.
- **OECD comparative tax revenue statistics** — kept long; the CIT revenue-as-share-of-GDP series sits inside this file alongside  many other revenue items.

### Code conventions

- `parent`, `affiliate`, `year` are the standard CbCR keys   throughout. ISO-3 codes for OECD/CbCR sources; ISO-2 for Eurostat  FATS (with explicit `EU27_ISO2` and `EU27_ISO3` lists in the script). The bridge between the two is the World Bank classifications table, which carries both codes.
-  Every cleaned file has its key uniqueness asserted before saving; the script fails loudly if a key combination duplicates.
- A consolidated `diagnostics/summary.csv` records row counts, jurisdiction counts, and missingness flags for every dataset; this  is the quick-look reference between cleaning runs.

## 2026-04-18 — Diagnostic verification and methodological response

Verifying the flags raised during cleaning produced three findings that sharpen the original entries, plus one factual correction to the Switzerland description. All decisions below are carried forward to Step 2 (merging) and Step 3 (Stage 1 / Stage 3 estimation); no further changes to `01_data_cleaning.R` are required for the issues themselves, but two new diagnostic files and three additional summary metrics have been added so the constraints surface without having to rediscover them.

### Finding 1 — ETR percentiles only exist from the 2021 vintage onward

The original entry noted that Panel A-I ETR percentiles are missing for ~83% of Table I cells. Looking at the distribution over years makes the constraint much sharper: the OECD only began publishing percentile moments with the 2021 vintage. The per-year coverage is now written to `diagnostics/cbcr_t1_etr_percentile_coverage.csv`:

| Vintage | Panel A-I `P50` present | `_T` (panel-agnostic) `P50` | Either source |
|---------|------------------------:|----------------------------:|--------------:|
| 2016--2020 | 0.0% | 0.0% | 0.0% |
| 2021 | 48.2% | 58.8% | 59.9% |
| 2022 | 50.6% | 62.8% | 63.2% |

The consequence is that the distributional Stage 1 fit of `\eqref{eq:mixture}`--`\eqref{eq:piecewise}` (`methodology §5.1.2`) can be evaluated on at most two fiscal years of data. The seven-year panel the rest of the pipeline runs on remains intact; it is the within-jurisdiction ETR distribution that is not observed before 2021.

**Resolution, carried into Step 3:**

1. Factor 1 of the factorial design (jurisdiction-average vs.\ distributional ETR measurement) becomes effectively a 2-year vs.\ 7-year comparison. For 2016--2020, the distributional level of Factor 1 must fall back on either (i) the Table IV direct observation where available (Finding 2) or (ii) the jurisdiction-average branch of `\eqref{eq:hybrid}`. This is already the third branch of `\eqref{eq:hybrid}` but was not flagged as load-bearing for 2016--2020; the methodology text of `§5.1.3` should note that for five of seven vintages the third branch is the only branch.
2. Within the 2021--2022 cells where percentiles exist, cascade Panel A-I → `_T` as the percentile source. `_T` adds roughly 10 percentage points of coverage over Panel A-I alone; denominator-side adjustments are handled separately in the mean-matching shift of `\eqref{eq:shift}` so the panel mismatch between `_T` (all subgroups) and Panel A-I (profit-makers) does not bias the distributional location.
3. The balanced-panel robustness check in `§5.3.5` should also be produced in a "2021--2022 only" variant, since any Factor 1 contrast on the full panel is driven mechanically by the availability structure rather than by substance.

### Finding 2 — Table IV is bilateral only from 2019 onward

Table IV carries 4,521 rows but before 2019 only the `W` world aggregate is reported; bilateral (parent × affiliate) observations first appear in 2019. The per-year structure is now in `diagnostics/cbcr_t4_coverage_by_year.csv`:

| Vintage | Rows | Parents | Affiliate codes |
|---------|-----:|--------:|----------------:|
| 2016--2018 | 124--186 | 25--37 | 1 (`W`) |
| 2019--2022 | 979--1,053 | 41--45 | 142--144 |

The hybrid Stage 1 measurement `\eqref{eq:hybrid}` therefore cannot take its Table IV branch before 2019. Within 2019--2022, bilateral coverage is narrower than the headline "49 parent jurisdictions" number implies in any single year (41--45 parents, not 49 simultaneously). All 27 EU Member States continue to appear as affiliates in each of 2019--2022.

**Resolution:**

1. Clarify in `§4.3` and the Table I/IV comparison in `§4.2` that Table IV's bilateral information covers 2019--2022, not 2016--2022. The methodology as written already works correctly — the bracket observation simply is not available for three of seven vintages — but the temporal statement needs correcting.
2. The cross-validation sample of `§5.1.3` (overlap between Table I percentiles and Table IV brackets) reduces to 2021--2022 by construction, since that is the only window where both objects exist. The Wilcoxon test, total-variation distance and regression `\eqref{eq:crossval_regression}` should be run on this two-year window and results should not be generalised to 2016--2020 without a stated assumption about temporal stability of the approximation error.

### Finding 3 — Adjusted profit regression is underpowered; adopt a benchmark ratio from Hugger (2026) and keep the regression only as a diagnostic

`PROFIT_ADJ` is observed for 33 Panel A-I cells in 2021--2022 (32 in 2021, 1 in 2022). All 33 of those cells also carry the holding-company share needed by equation `\eqref{eq:correction_model}`, so the regression is identified — but with N = 33 and a single covariate, the standard error on $\hat\beta$ will be wide enough that the predicted $\hat\gamma_{j,t}$ for 2016--2020 is essentially noise around a constant. Using this regression as the primary correction input, as `§4.5` currently does, is not supportable.

**Resolution:**

1. Replace the primary correction with the published ratio from \citet{hugger2026}: a median downward adjustment of 32.4% applied to the parent leg of UPE profit, capped at a 55.5% reduction. This is the correction set the OECD used in its own low-taxed profit estimates and has the virtue of being built on tax-authority information rather than an aggregate regression. Apply the Hugger cap to every parent--affiliate cell for 2016--2020; the 2021--2022 cells keep their observed `PROFIT_ADJ` where available and the Hugger ratio otherwise. This becomes the "baseline" level of Factor 4 (profit-base correction), replacing the predicted-ratio specification.
2. Keep the holding-share regression `\eqref{eq:correction_model}` as a descriptive test of the \citet{blouin2023} hypothesis that double counting scales with conduit intensity; report $\hat\beta$ and its standard error but do not use its fitted values to backcast. If $\hat\beta$ is significant and negative, that is supporting evidence for the Hugger-style correction; it is not a substitute for it.
3. Supplement the Hugger ratio with country-specific corrections from \citet{garcia-bernardo2022a} for the jurisdictions they explicitly document (Netherlands 16%, Sweden 51%, UK 51%, US domestic 54%, plus 10% of tax-haven profits for non-US MNEs). These enter as an overlay on top of the Hugger baseline for the named jurisdictions only.
4. The three factorial levels of Factor 4 become: (i) no correction ($\pi^{*} = \pi$) — upper bound; (ii) Hugger baseline with Garcia-Bernardo country overlay — central estimate; (iii) aggressive — apply the 55.5% cap uniformly. The spread across (i)--(iii) continues to play its role in the ANOVA decomposition of `§5.5`.

The cleaning script already exposes `act_holding_panelai` and `entities_count_panelai`, so no changes to Step 1 are needed for this; the overlay happens in Step 2.

### Finding 4 — Zero-profit cells in Panel A-I: 82 total, 8 of them with positive tax accrued

Of the 82 cells with `profit_panelai = 0`, 74 also have zero tax (the ETR numerator is 0/0 and the cell is uninformative) and 8 have positive tax (the ratio is $+\infty$). \citet{boukal2026} and \citet{hugger2026} both bound CbCR ETRs at zero and cap the upper tail at the statutory rate plus loss adjustment; neither defines ETR on a zero-profit denominator.

**Resolution:**

1. Drop the 82 zero-profit cells from ETR numerator/denominator calculations in Step 3. They do not enter `\eqref{eq:etr}`, `\eqref{eq:jurisdiction_percentile}`, or `\eqref{eq:panel_linear}` (since $\log \pi$ is undefined at zero anyway).
2. Retain them in the substance base aggregation used for SBIE (payroll, assets, employee counts). The zero profit is a legitimate observation of real activity with no accounting profit in the reporting year; excluding the substance would bias the SBIE denominator.
3. Winsorise the per-cell ETR at $[0, \bar\tau^{\text{stat}}_j + \text{loss adjustment}]$ following the Hugger bounds, applied after the location shift of `\eqref{eq:shift}`. This handles the 8 positive-tax-on-zero-profit cells implicitly by excluding them (division by zero) without needing a separate rule.

### Finding 5 — Switzerland in Table IV: the "8,600×" description was wrong

Verifying the CHE anomaly: the USA--CHE bilateral in the `RATE_0_15` bracket reports 80--91% of total USA--CHE Panel A-I profit, not 8,600× of it. The per-year shares are:

| Year | USA--CHE Panel A-I (Table I) | USA--CHE `RATE_0_15` (Table IV) | Share |
|------|------------------------------:|--------------------------------:|------:|
| 2019 | $72.0bn | $57.8bn | 80% |
| 2020 | $135.1bn | $122.9bn | 91% |
| 2021 | $58.5bn | $52.5bn | 90% |
| 2022 | $63.5bn | $56.2bn | 88% |

This is not a reporting error; it is the genuine observation that almost all profit US MNEs book in Switzerland sits below the 15% ETR threshold, consistent with US MNEs' well-documented use of Swiss IP and finance structures. The earlier "~8,600× Table I value" claim in the original logbook entry and the corresponding comment in `01_data_cleaning.R` are incorrect and have been corrected. The Switzerland flag file (`diagnostics/cbcr_t4_switzerland_flag.csv`) now reports the per-parent share of Panel A-I profit in the `RATE_0_15` bracket, which is the quantity the anomaly actually describes.

**Resolution:**

1. Do not exclude CHE in 2019, 2020, 2021, 2022 as a data-quality matter. The observation is not anomalous.
2. Keep CHE in as an influential observation in the hybrid Stage 1 measurement. Report the Stage 1 results twice: all-EU + CHE vs.\ all-EU only. If the latter materially differs, report both; the concentration of US MNE Swiss profits in `RATE_0_15` is exactly the kind of heterogeneity the distributional fit must handle, and dropping it would preempt a substantive finding.
3. The "Switzerland anomaly" note in `CLAUDE.md` (which described the USA--CHE share as an 8,600× anomaly) is inaccurate and should be revised together with the methodology text.

### Summary of code / methodology status

| Issue | Code change | Methodology change | Location |
|-------|-------------|--------------------|---------|
| ETR percentiles pre-2021 missing | New diagnostic file (`cbcr_t1_etr_percentile_coverage.csv`) | Restrict distributional Stage 1 to 2021--2022; A-I → `_T` fallback | Step 3 |
| Table IV pre-2019 | New diagnostic file (`cbcr_t4_coverage_by_year.csv`) | `§5.1.3` temporal window correction | `§4.3`, `§5.1.3` |
| `PROFIT_ADJ` sparsity | (No Step-1 change; inputs already exposed) | Replace §4.5 regression with Hugger ratio + GB country overlay as baseline | `§4.5`, Step 2 |
| Zero-profit cells | Summary metric added | Drop from ETR; retain for substance; winsorise | Step 3 |
| CHE Table IV | Comment corrected; flag file rewritten per-parent | Retain CHE; report with/without as sensitivity | `§5.1.3` |

No further cleaning-stage changes are required. The next script (Step 2, merging) picks up these decisions and applies them on the bilateral panel.

## 2026-04-18 - Step 2: base correction and merging (`code/02_base_correction_and_merging.R`)

### Merge architecture

Step 2 builds the bilateral base panel on the economically meaningful CbCR unit, one row per parent jurisdiction, affiliate jurisdiction, and fiscal year. Table I remains the spine because it is the only table that covers the full 2016-2022 horizon with the profit, tax, payroll, assets, and percentile information needed later in the pipeline. The merge removes only the non-country aggregate affiliate codes, namely the regional totals, `W`, `W_O`, `WXD`, and `STLS`. Domestic cells are retained. They are essential for the double-counting correction because the Hugger-style adjustment is defined on the domestic UPE leg.

The resulting country-like panel contains 16,915 bilateral rows, 58 parent jurisdictions, 228 affiliate jurisdictions, and all seven fiscal years from 2016 to 2022. Fiscal year 2016 is retained but explicitly flagged as a transition vintage, consistent with the thesis text and the OECD treatment of the first CbCR release. The main estimation window remains 2017-2022.

The other CbCR tables are added only where they can be reduced to the same pair-year key without inventing structure. Table II is merged in full as interquartile-mean controls. Table III and Table IV are not flattened across all ETR brackets, which would create bracket-level duplication of the bilateral key. Instead the script keeps the policy-relevant `RATE_0-15` slice from each table, because that is the direct low-tax benchmark needed for Stage 1 cross-validation. Table V is merged on the parent-year key because MNE size is a parent characteristic. Table VI is widened over its size classes before the join, so the 2022 size composition is kept without breaking one-row-per-pair-year uniqueness.

The same principle governs the non-CbCR sources. Supplementary datasets that live naturally on a jurisdiction-year key, such as statutory CIT rates, GDP per capita, population, BEPS implementation indicators, CbCR filing rules, and Pillar Two implementation dates, are merged directly onto the bilateral panel with explicit parent and affiliate prefixes. Datasets that remain fundamentally multi-dimensional are not forced into the base panel. Eurostat FATS is saved separately as `base_panel_fats_sector_shares.rds` at the affiliate-year-sector level. The forward-looking OECD ETR files, the dividend tax series, the hourly wage series, and the broad comparative tax-revenue file remain in their cleaned long form from Step 1. Flattening them now would require an arbitrary measure choice that belongs in a later analytical step, not in the construction of the base data.

### Missing-value handling

The only economically defensible imputation carried out in Step 2 is the payroll imputation already stated in the methodology. The script constructs an affiliate-year wage benchmark with a strict hierarchy. OECD annual average wages in PPP-adjusted USD come first. If that is unavailable, the script uses ILO monthly earnings in PPP terms and annualises them by multiplying by twelve. Only if PPP data are absent does it fall back to ILO monthly earnings in USD. Within each source, the nearest available year for the same jurisdiction is used, with ties broken in favour of the earlier observation. This keeps the imputation close to the observed wage path of the jurisdiction rather than importing a global average.

The imputation burden is small. Only 25 Panel A-I rows and 27 Panel A-II rows require wage-based payroll imputation. Wage coverage exists for 14,685 of the 16,915 bilateral cells. Missing payroll after this step is therefore concentrated in the difficult cells where neither CbCR payroll nor the employee count-wage combination is available. The script does not impute tangible assets, profits, taxes, or percentile moments. Those objects either have no credible deterministic bridge or belong to later modelling steps. Instead the panel records transparent coverage flags, so later scripts can distinguish a true economic zero from a missing observation.

For the SBIE base the script prefers the broader Panel A-II activity measures and falls back to Panel A-I only where the all-entity series is missing. This is an important policy choice. The ETR denominator belongs on profit-making entities, but the SBIE is a substance measure and should not be narrowed to profit-makers if a broader activity measure is available. The merged panel therefore carries a dedicated `payroll_sbie` and `assets_sbie` base, together with source flags showing whether the value comes from observed Panel A-II, imputed Panel A-II, observed Panel A-I, imputed Panel A-I, or the panel-agnostic aggregate.

### Profit-base correction

Step 2 applies the deterministic profit correction in the form now used by the thesis, and this required one conceptual clarification. Earlier notes referred to profit correction as a separate "Factor 4". The current thesis text no longer treats it as one of the five orthogonal pipeline factors. It is now an upstream data-conditioning choice. The code follows that structure. It stores three profit bases side by side: the uncorrected upper bound, the preferred baseline correction, and the aggressive lower-bound sensitivity. The baseline corrected profit is also exposed as `analysis_profit_base`, because it is the object later used in the estimation and revenue pipeline.

The baseline correction follows equations (4.5) and (4.6) in the current thesis draft. If `PROFIT_ADJ` is observed, the script uses it directly. If not, domestic UPE cells are reduced by 54 per cent for the United States, 16 per cent for the Netherlands, and 32.4 per cent for all other parents. Foreign non-US cells in separately identified conduit or haven jurisdictions receive a 10 per cent downward overlay. The conduit-and-haven set used in the code is the set explicitly named in the literature discussion of the thesis: Bermuda, the Cayman Islands, Ireland, Luxembourg, the Netherlands, Switzerland, Singapore, Hong Kong, Puerto Rico, and the United Kingdom. The aggressive correction keeps observed `PROFIT_ADJ` and the same conduit overlay, but replaces the generic 32.4 per cent domestic rate with the Hugger cap of 55.5 per cent.

The merged data confirm that the correction must remain deterministic rather than regression-driven. The `PROFIT_ADJ` donor sample is still far too narrow for a globally transportable fitted model, but the exact pattern in the draft text needed correction. The panel contains 36 country-like Panel A-I observations with reported `PROFIT_ADJ`, not 33. Twenty-seven belong to the Dutch 2021 disclosure wave, one is the Dutch domestic 2022 cell, and eight are earlier UK and Dutch domestic observations in 2017-2020. None of the observed ratios exceeds one, and the minimum observed `PROFIT_ADJ / PROFIT` ratio is 0.516. The sample remains too concentrated to support a global regression correction, but the empirical description in the thesis draft should now be updated to reflect these 36 observations rather than the earlier 33-cell Netherlands-only statement.

In the baseline merged panel, 308 domestic rows receive the Hugger-style domestic correction, 1,436 foreign conduit or haven rows receive the 10 per cent overlay, and 36 rows use observed `PROFIT_ADJ`. The remaining 15,135 foreign operating rows are left unchanged. This is materially more targeted than a parent-wide multiplicative haircut, and it matches the accounting mechanism discussed by Blouin more closely.

### Descriptive flags raised during the join

The join produces several descriptive flags that matter for later interpretation. First, direct subsidiary-level low-tax information from Table IV is available for 760 bilateral rows once the panel is restricted to country-like affiliates. Among these observed cells, the mean `RATE_0-15` profit share is 47.1 per cent of Panel A-I profit, and the 95th percentile reaches 100 per cent. This confirms that the hybrid Stage 1 design will be working with substantial heterogeneity, not with marginal bracket noise.

Second, the missingness pattern of the supplementary controls is asymmetric. World Bank GDP per capita and population are missing for only about 2 to 4 per cent of rows, mainly because of small territories and special jurisdictions not covered by the World Bank country list. By contrast, the OECD statutory CIT series covers only a minority of the bilateral panel because many small offshore jurisdictions and dependencies are not in the OECD tax database. This is not an error in the join. It is a property of the underlying source coverage and needs to be respected in later regressions.

Third, the FATS sidecar is cleaner than expected once it is aggregated over controlling countries. For all 27 EU Member States and both 2021 and 2022, the post-2021 FATS file yields 48 NACE rows per affiliate-year and the payroll, employment, investment, and turnover shares each sum to one up to rounding error. The main structural limitation of FATS remains conceptual rather than mechanical: the shares describe all foreign-controlled firms, not only the large in-scope CbCR population.

Finally, the merged panel now carries explicit readiness flags for later stages. A row is marked as ready for the main Hines-Rice estimation sample only if it lies in 2017-2022 and has positive corrected profit, non-missing ETR, and non-missing SBIE inputs. After all joins and imputations, 5,393 rows satisfy these conditions. This is the effective Step 2 bridge from raw CbCR coverage to the estimation sample.

### Outputs

Step 2 writes the main bilateral object to `data/processed/base_panel.rds` and the EU sectoral sidecar to `data/processed/base_panel_fats_sector_shares.rds`. The diagnostics folder now also contains six step-specific files: a panel summary, a year-by-year payroll imputation summary, a year-by-year payroll-plausibility summary, a year-by-year profit-correction summary, a missingness summary for the merged controls, and a FATS sector-coverage file. These files are intended to make the later analytical steps transparent and to prevent rediscovering the same data limitations at each stage.

### Working-appendix descriptive tables

The working appendix now pulls the Step 2 descriptive statistics from a dedicated regeneration script, `code/02b_base_panel_appendix_tables.R`, rather than hard-coding the numbers in `writing/thesisv2.tex`. This is methodologically preferable because the appendix tables are direct descriptive outputs of the merged base panel; if the Step 2 merge logic or the processed inputs change, the appendix should refresh mechanically rather than relying on manual editing.

The script reads `data/processed/base_panel.rds` and writes a LaTeX fragment to `writing/generated/base_panel_appendix_tables.tex`. The thesis file includes that fragment with `\input{generated/base_panel_appendix_tables.tex}` inside the working appendix block. Regeneration therefore requires only two steps: rerun `code/02_base_correction_and_merging.R` if the merged panel has changed, then rerun `code/02b_base_panel_appendix_tables.R` to refresh the appendix tables.

The script currently produces three appendix tables. First, a year-by-year coverage table for the full 2016-2022 bilateral panel, including the number of cells, parent jurisdictions, affiliate jurisdictions, percentile availability, direct Table IV low-tax observations, and the size of the estimation-ready sample. Second, an unweighted summary-statistics table for the main 2017-2022 estimation sample, reporting the mean, standard deviation, quartiles, and observation count for the corrected profit base, tax accrued, SBIE inputs, raw ETR, and core jurisdiction controls. Third, a construction-flags table that records how many cells are domestic, EU-based, directly corrected with observed `PROFIT_ADJ`, adjusted by the domestic Hugger rule, adjusted by the conduit overlay, supported by observed or imputed payroll, supported by direct Table IV bracket information, or retained in the estimation sample.

This setup also makes the empirical definitions transparent. The appendix summary table is computed on the exact `has_estimation_inputs` sample used downstream, not on the full merged panel. The flag table is instead anchored to the full 16,915-cell panel, so each share is interpretable as a construction share of the universe built in Step 2. That distinction matters. Mixing the two denominators would look tidy in presentation terms, but it would be econometrically sloppy because it would conflate sample-selection diagnostics with descriptive moments of the estimation sample.

### Payroll plausibility correction after appendix review

The first round of appendix statistics revealed a genuine Step 2 measurement problem rather than a cosmetic outlier issue. The initial merged panel produced an average SBIE payroll base of USD 10.2 billion per pair-year in the estimation sample, but the median was only USD 55 million and the maximum exceeded USD 25 trillion. The clearest example was the 2017 China--Greece cell, which carried roughly USD 25.1 trillion of payroll for 1,482 employees. That is not an economically meaningful heavy tail. It is a contaminated payroll observation, and leaving it in would mechanically overstate the SBIE, shrink the excess-profit base, and bias GMT revenue downward.

The correction is now built directly into `code/02_base_correction_and_merging.R`. The script keeps the raw payroll values, but it also constructs a jurisdiction-specific benchmark equal to employee counts times the local annual wage used elsewhere in Step 2. For Panel A-I, Panel A-II, and the aggregate fallback alike, observed payroll is capped when it exceeds twenty times that benchmark. The threshold is deliberately conservative. A factor of twenty is high enough to avoid forcing productive multinationals onto the local average wage, but low enough to catch clearly impossible CbCR values. The code stores both the raw and corrected payroll inputs, a correction flag, the raw-to-benchmark ratio, the effective cap, and the share of payroll removed by the correction.

Empirically the correction matters. Across the full 16,915-cell merged panel, 1,103 cells are capped by the plausibility rule. Within the 5,393-cell main estimation sample, 775 cells are capped, or 14.4% of the sample. The impact is concentrated in the right tail, exactly where the earlier appendix diagnosis suggested it should be. The mean SBIE payroll base in the estimation sample falls from USD 10.194 billion to USD 4.467 billion, while the median moves only from roughly USD 55 million to USD 47 million and the sample size does not change. In aggregate, the correction removes 56.2% of raw payroll mass from the estimation sample. That sounds large, but it is economically more plausible than leaving a small set of impossible payroll values to dominate the substance denominator.

The year pattern confirms that the problem was persistent rather than confined to one disclosure wave. The new diagnostic file `diagnostics/step2_payroll_plausibility_by_year.csv` shows capped shares between 5.2% and 7.0% of all pair-year cells in every vintage from 2016 to 2022. The raw payroll reduction is especially large in 2017 because of the extreme China--Greece observation, but every year exhibits a non-trivial correction. The companion file `diagnostics/step2_payroll_imputation_by_year.csv` now also records the number of capped Panel A-I, Panel A-II, and aggregate payroll cells, so the plausibility correction can be read alongside the original wage-imputation summary rather than being hidden as an undocumented overwrite.

This change fits the thesis methodology cleanly and should be described that way in the text. In the Stage 2 section of `thesisv2.tex`, the payroll component $\hat{W}_{p,j,t}$ is now defined as observed or imputed payroll subject to a conservative plausibility cap based on local wages and employment. This is not a departure from the economic logic of the chapter. It is a protection against a specific data-quality failure that would otherwise push the substance carve-out in the wrong direction. Because the same payroll variable is later used as a control in the Hines--Rice estimation, the correction also reduces measurement error in the regression stage rather than affecting only the SBIE calculation.

The working appendix now reflects this revised interpretation. `code/02b_base_panel_appendix_tables.R` regenerates the appendix tables from the corrected base panel, labels the payroll statistic explicitly as the corrected SBIE payroll base, and records the new payroll-capping flag in the construction table. The appendix notes also clarify that the reported ETR summary remains the raw Panel A-I ratio before the later Stage 3 bounding step. This is important for interpretation. The payroll problem required a Step 2 correction because it polluted the underlying quantity directly; the raw ETR tail remains a modelling issue for later stages because it reflects small denominators and tax refunds rather than an obvious merge error.

### Source trace of the extreme payroll values

After implementing the plausibility cap, the next question was whether the extreme payroll values originated in the thesis pipeline or in the source data itself. This was traced all the way back through `code/02_base_correction_and_merging.R`, `code/01_data_cleaning.R`, the raw OECD CSV file in `data/raw/oecd_cbcr/`, and the original download logic in `code/collect_all_data.py`.

The collection step is not the source of the anomaly. In `code/collect_all_data.py`, the CbCR collector only constructs the OECD SDMX endpoint and streams the returned bytes directly to disk. The relevant logic is operationally simple: `download_oecd()` builds the SDMX URL and `download_file()` writes the response to `data/raw/oecd_cbcr/cbcr_table1_aggregate_totals.csv` without any parsing, rescaling, or column-wise manipulation. The collector therefore cannot inflate `EARNINGS`, change units, multiply values, or duplicate observations. If a payroll value is extreme in the raw CSV, that extremity comes from the OECD response itself.

The cleaning step is not the source either. In `code/01_data_cleaning.R`, Table I is read from `data/raw/oecd_cbcr/cbcr_table1_aggregate_totals.csv`, columns are renamed, and the long file is pivoted wide into `cbcr_table1.rds`. There is no arithmetic on `EARNINGS`, no currency conversion, no aggregation over multiple rows, and no adjustment by panel. A direct check on the raw `EARNINGS` keys showed zero duplicate combinations of reporting jurisdiction, affiliate jurisdiction, year, panel, and statistical operation before the pivot. This means the wide transformation does not combine multiple `EARNINGS` rows into one inflated value.

The flagship anomaly, the China--Greece pair in 2017, is present in the original OECD download exactly as it later appears in the processed panel. In `data/raw/oecd_cbcr/cbcr_table1_aggregate_totals.csv`, the rows for `REF_AREA = CHN`, `COUNTERPART_AREA = GRC`, `TIME_PERIOD = 2017`, `MEASURE = EARNINGS` report `OBS_VALUE = 2.507134e+13` both for `PROFIT_GROUPING = PANELAI` and for `PROFIT_GROUPING = _T`. The file records these values in `UNIT_MEASURE = USD`, `DECIMALS = 0`, and `OBS_STATUS = A`. The same value then appears in `data/processed/cbcr_table1.rds`, and from there enters the merged base panel. The thesis pipeline therefore preserved the value; it did not create it.

The same conclusion holds for other large cells that triggered the plausibility correction. Belgium--United Kingdom in 2020, Saudi Arabia domestic in 2021, United States--Bermuda in 2017, and Indonesia--Mauritius in 2022 all appear directly in the raw OECD CSV as `EARNINGS` observations in USD with `DECIMALS = 0` and `OBS_STATUS = A`. Some of these observations are very large but still potentially plausible for major domestic economies; others are not. The key point is narrower and more important: the pipeline is not manufacturing them.

To verify this systematically rather than anecdotally, the capped observations in the final base panel were matched back to the original OECD rows. All 1,103 capped cells in `base_panel.rds` matched an underlying raw `EARNINGS` observation in the downloaded OECD file. None of the capped cells lacked a corresponding raw row. The source-panel composition is also informative. Of the capped cells, 514 originate from Panel A-II `EARNINGS`, 388 from Panel A-I, and 201 from the aggregate `_T` fallback. Every matched raw row carried `UNIT_MEASURE = USD`, and every matched raw row carried `OBS_STATUS = A`. This rules out the simplest internal-pipeline explanations such as a misaligned join, a duplication of Panel A-I and Panel A-II rows, or a mismatch between currencies.

The broader pattern in raw Table I confirms that this is not one isolated cell. Among the raw Panel A-I observations with both payroll and employment reported, 95 imply more than USD 100 million of payroll per employee and 20 imply more than USD 1 billion per employee. These magnitudes are impossible as labour costs. More generally, the distribution of raw `EARNINGS / EMPLOYEES` is far too dispersed to be interpreted literally in every cell. The worst values are concentrated in well-known conduit and haven locations and in some very small affiliate jurisdictions, but they are not limited to them.

What, then, is the likely root cause. The evidence supports a source-data problem, but not a single neatly identifiable mechanism. With only the public OECD aggregates, we cannot distinguish with certainty between several possibilities: reporting errors by national tax authorities, miscoding of one financial item as `EARNINGS`, contamination of payroll by non-labour flows during national aggregation, or more complex panel-definition inconsistencies between Panel A-I, Panel A-II, and `_T`. What we can say with confidence is that the anomaly is upstream of the thesis code. It is present in the original OECD Table I file as downloaded by the collector, survives the cleaning step unchanged, and only becomes consequential in Step 2 when payroll is used as a direct substance input for the SBIE and as a regression control.

This distinction matters for the thesis. The payroll plausibility cap is not a patch for a programming bug. It is a deliberate data-conditioning correction for an upstream measurement problem in the published CbCR aggregates. That is methodologically defensible. If the public source contains payroll values that are internally incompatible with employment counts and local wage levels, the analyst should not treat those values as economically meaningful substance. At the same time, the source trace implies that the thesis should not overstate certainty about the mechanism behind the anomaly. The correct claim is that some published OECD CbCR payroll aggregates are not empirically credible as labour-cost measures at the pair-year level, and therefore require screening before they can enter SBIE calculations.

For the written thesis, this source trace supports two presentational choices. First, the Stage 2 methodology should explicitly state that the payroll plausibility cap addresses upstream source anomalies in published CbCR payroll aggregates rather than missing-data imputation error. Second, the working appendix should keep the raw-ETR summary and the corrected payroll summary conceptually separate. The former remains a later modelling issue; the latter is now shown to be a verified source-data issue already visible in the original OECD Table I release.

## 2026-04-20 — Stage 1 audit, thesis corrections, and results section

This entry documents a full audit of the Stage 1 pipeline against the thesis methodology, a set of targeted corrections to the thesis text, and a new Stage 1 results section. No change to the economic logic of the pipeline. The motivation is alignment: several numerical claims in the methodology section of `writing/thesisv2.tex` were written against an earlier vintage of the diagnostics and were no longer consistent with the outputs actually produced by `code/03_stage1_etr.R` on the current `base_panel.rds`.

### Audit findings from the current outputs

The authoritative Stage 1 diagnostic CSVs in `data/processed/diagnostics/` were re-read against the thesis prose. Three sets of numbers disagreed.

First, the bilateral-panel branch counts. The thesis claimed 760 direct Table IV cells, 2,976 percentile-fit cells, 3,899 BSPI shape-transport cells, and 9,280 jurisdiction-average fallback cells. The current pipeline produces 9,395, 874, 3,899, and 1,459 respectively on the 15,758 pair-year panel, plus 131 residual cells without any source. The shape-transport count still matches; the other three were stale. The BSPI shape-transport count is stable because the 2017-2018 EU27 bilateral universe has been fixed by the step 2 merge for some time. The other counts moved because the step 2 revision introduced tighter Stage 1 input availability rules and because the percentile cascade from Panel A-I to `_T` was finalised after those numbers were first written.

Second, the EU27 BSPI shape-stability statistics. The thesis claimed a median total-variation distance of 0.10 with a maximum of 0.52 in Malta, and listed five EU affiliates above the 0.39 flag threshold (Lithuania, Croatia, Malta, Latvia, Greece). The current outputs give a median of 0.09, a maximum of 0.67 in Lithuania, and only three affiliates above the threshold: Lithuania (0.67), Croatia (0.56), and Greece (0.42). Malta turns out to have TV = 0.02, comfortably in the stable group. The country-specific TV values for the big conduits are close but not identical to the earlier numbers, for example Luxembourg now 0.11 rather than 0.10 and the Netherlands 0.12 rather than 0.09. The economically important conclusion is unchanged: the conduit jurisdictions pass the shape-stability test, and the three flagged affiliates are small-profit cases where an anchor-to-validation shift is plausibly real.

Third, the BSPI coverage claim. The thesis said BSPI delivers heterogeneity for 1,016 of the 1,165 pre-2019 EU27 pair-year cells, with 149 remaining cells falling back to the jurisdiction-average rule. The current bilateral panel contains exactly 1,016 pre-2019 EU27 pair-years and all of them are populated through BSPI; there is no pre-2019 EU27 fallback subset. The 1,165 number was never a universe count in the current data. The corrected wording says BSPI covers all 1,016 pre-2019 EU27 pair-year cells.

Outside those three, the thesis text was accurate. The percentile-fit coverage on the 2021-2022 overlap is 410 affiliate-year cells (54 EU27 plus 316 non-EU Panel A-I and 40 non-EU `_T` fallback), the cross-validation regression coefficient $\hat{\delta}$ on the IQR is 2.17 with a p-value of 0.73, and the profit-weighted Stage 1 liability rate is higher under the distributional rule than under the jurisdiction-average rule in every panel year.

### Code changes

Two additions to `code/03_stage1_etr.R` make the thesis-level numbers reproducible from a single CSV rather than requiring ad-hoc joins of the affiliate-year and bilateral diagnostic files.

The first addition writes a pair-year branch count by year. The existing `step3_stage1_branch_by_year.csv` reports affiliate-year counts, which is the unit the rest of the diagnostics uses. The thesis reports pair-year counts, because the factorial decomposition operates on the bilateral panel. The new file `step3_stage1_pair_year_branch_by_year.csv` reports both so that the text can cite the same source. The branch counts themselves are a direct `count(year, stage1_distributional_source)` over `stage1_bilateral_panel.rds` — no new computation.

The second addition writes an EU27-vs-non-EU summary of the BSPI TV distribution. The existing `step3_stage1_bspi_validation.csv` is at the affiliate level, which is the right unit for flagging individual affiliates but inconvenient for the methodology prose that reports EU27 aggregates. The new file `step3_stage1_bspi_tv_summary.csv` reports the median, 75th, 90th, and maximum TV distance separately for EU27 and non-EU affiliates, together with affiliate counts and the count of flagged high-TV affiliates. Again, no new computation — this is a grouped summary of the existing per-affiliate object.

Both additions are appended to the results block of `run_stage1_pipeline()` and are written alongside the existing CSVs. No dependent downstream file has been changed; the `stage1_affiliate_year.rds` and `stage1_bilateral_panel.rds` outputs are byte-identical to the previous run.

### Thesis corrections

Three paragraphs in `writing/thesisv2.tex` Section 5.1.3 (the hybrid, BSPI, and cross-validation block) were revised to report the verified numbers. The BSPI EU27 coverage paragraph now says BSPI covers all 1,016 pre-2019 EU27 pair-year cells rather than 1,016 of 1,165. The percentile coverage paragraph now says 54 EU27 plus 356 non-EU affiliate-year cells have a complete percentile set, reflecting the actual 316+40 split between Panel A-I and the `_T` cascade. The BSPI TV paragraph now reports median 0.09, 75th 0.20, 90th 0.36, maximum 0.67 (Lithuania), and names Lithuania, Croatia, and Greece as the three flagged affiliates. The conduit TV listing now includes Malta (0.02) and corrects Luxembourg (0.11) and the Netherlands (0.12). The strict-variant reassignment count is now cited explicitly: 13 of the 117 validated affiliates exceed the threshold globally, reassigning 26 shape-transport affiliate-years.

### New Stage 1 results section

`Section 6` (Results) now has a Stage 1 subsection, `\subsection{Stage 1: identifying low-taxed profit}`. It opens with the headline numbers — gross top-up liability rate 4.23% globally and 5.07% inside the EU27 under the distributional rule versus 2.88% and 3.98% under the jurisdiction-average rule, with a distributional uplift in every sample year — then presents four tables. Table 1 is the hybrid source coverage matrix, with one row per branch and one column per year on the 11,872 positive-profit pair-year panel. Table 2 is the EU27-and-global Stage 1 rate decomposition by year, showing low-taxed share and liability rate separately for the jurisdiction-average rule and the distributional rule. Table 3 is the EU27 BSPI shape-stability ranking with the three flagged affiliates and selected conduit jurisdictions. Table 4 is the cross-validation summary against Table IV on the 239-cell 2021-2022 overlap, with the Wilcoxon p-values, the MAE and RMSE of the low-taxed share and the liability rate, and the IQR-correction regression coefficient and fit.

The writing follows the rules from `handbook.md`. No bullet lists; each paragraph opens with a plain-language sentence stating what the paragraph does; numbers are placed before interpretation; the tables are captioned in a self-standing way so they can be read without the surrounding text. The section does not re-derive the methodology; it refers to the equations and cells established in Section 5.

### Numbers table

The reproducible key numbers behind the revised text and the new results section are as follows. All come from `data/processed/diagnostics/step3_stage1_*.csv` after the current pipeline run.

Pair-year branch counts, full 2017-2022 panel: direct Table IV 9,395, percentile fit 874, BSPI shape-transport 3,899, jurisdiction-average fallback 1,459, missing 131. Total 15,758.

Affiliate-year branch counts, positive-profit cells only: direct Table IV 477, percentile fit 136, BSPI shape-transport 248, jurisdiction-average fallback 299. Total 1,160. The total positive-profit positive-profit universe is 1,160 of 1,276 affiliate-years.

EU27 BSPI shape-stability, 27 affiliates with a validated anchor: median TV 0.093, 75th 0.196, 90th 0.358, max 0.665. Three high-TV affiliates: LTU 0.665, HRV 0.555, GRC 0.415. Conduit jurisdictions: CYP 0.011, CZE 0.018, DEU 0.023, MLT 0.023, IRL 0.064, FRA 0.073, LUX 0.106, NLD 0.116.

Global BSPI shape-stability: 117 affiliates with a validated anchor, 13 flagged.

Cross-validation overlap: 239 affiliate-years with both sources populated, of which 40 have a zero low-taxed share in Table IV. Low-taxed share median gap 0.071, MAE 0.312, Wilcoxon p-value $1.1 \times 10^{-7}$. Liability rate median gap 0.018, MAE 0.038, Wilcoxon p-value $1.5 \times 10^{-9}$. IQR regression $\hat{\delta} = 2.17$, p-value 0.729, $R^2 = 0.009$.

Profit-weighted Stage 1 liability rate, full panel (pre-SBIE, pre-behavioural): EU27 jurisdiction-average rule 3.98%, EU27 distributional rule 5.07%; global jurisdiction-average rule 2.88%, global distributional rule 4.23%. Total positive profit: EU27 \$6.2 trillion across six years, global \$34.5 trillion. The distributional approach therefore lifts the Stage 1 liability rate by 27% inside the EU27 and 47% globally relative to the jurisdiction-average approach.

### Build status

The revised `writing/thesisv2.tex` compiles cleanly in TinyTeX 2025 to a 91-page PDF. No new undefined references were introduced; the pre-existing undefined references (`sec:litreview`, `sec:feasibility`, `sec:timeline`, `sec:se_results`, `sec:descriptive`, `sec:benchmarks_unmodelled`, `eq:beta_estimated`, `tab:units`, `tab:statops`) are all in sections that have not yet been drafted and are unaffected by this audit.

