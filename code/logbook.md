# Data preparation logbook

This document tracks the data and methodology decisions made in the analysis pipeline. Each entry describes what was done in economic and policy terms — programming detail belongs in the scripts and their diagnostic output, not here.

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
