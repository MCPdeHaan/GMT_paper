---
title: "Global Minimum Tax: replication guide"
subtitle: "Journal paper v2 · OECD public CbCR, FY2017–2023"
geometry: margin=0.8in
fontsize: 10pt
---

# Package and execution

This package reproduces the bilateral CbCR panel, top-up tax simulations, collector-country allocation, robustness analyses and publication exhibits for the Pillar Two paper. The analytical window is FY2017–2023. FY2016 supplies initial conditions and supplementary data. The archived FY2017–2022 thesis results are the comparison vintage in the master scorecard.

Run from the repository root. The verified environment is R 4.6.0 on arm64 macOS, Apple M5 Pro, 48 GB RAM, a UTF-8 locale and LibreOfficeDev 26.8.0.0.alpha0. Set `LC_ALL` to an installed UTF-8 locale. LibreOffice's `soffice` must be on the path for BEA workbook conversion. The R lockfile records all package versions, including `fixest`, `ggplot2` and `testthat`. PDF figures use R's built-in PDF device. LaTeX with `booktabs` and `longtable` is required to compile the new table fragments. Reserve about 2 GB for the active inputs, outputs and an isolated replay, plus space for the R library and temporary workbook conversion.

```sh
Rscript --vanilla -e 'install.packages("renv", repos = "https://cloud.r-project.org")'
Rscript --vanilla -e 'renv::restore(prompt = FALSE)'
export R_LIBS_USER="$(Rscript --vanilla -e 'cat(renv::paths$library())')"
shasum -a 256 -c tests/step17_raw_inputs.sha256
shasum -a 256 -c tests/r05b_legal_inputs.sha256
Rscript --vanilla run_all.R
```

The command writes analysis data to `data/processed/`, diagnostics to `data/processed/diagnostics/`, and LaTeX and PDF exhibits to `writing/generated/`. Pass `--output-root=/absolute/path` for an isolated replay. All inputs resolve from this checkout. The default `GMT_UTPR_SPECIFICATION=VERIFIED_PARENT_ONLY` uses verified national applicability for fiscal years starting 1 January 2026 and observed parent-year activity. Stage 06 writes the dated collector map and source-key unsupported liability. Use a fresh output root for every specification. The four comparison specifications and the Guernsey sensitivity are defined in the [R05b scientific revision](docs/refactoring/r05b_utpr_production.md).

The default `GMT_BEHAVIOURAL_SPECIFICATION=NO_NOTCH_STANDARD_RESPONSE` applies the estimated response continuously below 15% where collection exposure and excess profit are positive. Stage 05 records the specification and zero bandwidth in `step5_stage3_behavioural_specification.csv`. To replay R05b in a fresh output root, set `GMT_UTPR_SPECIFICATION=VERIFIED_PARENT_ONLY GMT_BEHAVIOURAL_SPECIFICATION=BASELINE_NOTCH`. The historical mode preserves its two-point stylised notch and directory inventory. The R05b manuscript and research note sources are versioned at `0e619fc2e112c8e758ea6e6969aca97ea01b8606`.

The leading run computes every Stage 1 measurement-error draw. Only `BASELINE_NOTCH` with `LEGACY_FALLBACK` can reuse the 13 archived measurement-error files via `GMT_MEASUREMENT_CACHE_ROOT`, after checking the output hashes and nine simulation inputs. An empty existing directory for that variable exercises a fresh simulation in that mode. On Unix, `GMT_MEASUREMENT_WORKERS` optionally uses more than one process for evaluation of the already seeded measurement draws. The default is one. The seeds are 20260503 for measurement error, 20260613 for profit reconciliation uncertainty and 20261113 for joint uncertainty. The main analysis runs offline after dependency installation.

# Data availability and provenance

The working package contains the exact public aggregate extracts used for this analysis and the derived analysis files. The input manifest identifies the local bytes of each extract. The underlying MNE filings are confidential and were not accessed. The models use public aggregates and cannot reconstruct firm-level cross-classifications. `data/baseline_processed/` and `data/baseline_diagnostics/` contain the historical comparison fixtures. `writing/baseline_generated/` holds the corresponding archived exhibit fragments.

The listed public portals do not charge for downloading the extracts. A refresh depends on provider uptime, throughput and revision schedules. The live collector can take several minutes or longer and requires Python 3 and `requests`. Run `python3 code/collect_all_data.py --list` for source selectors or `--source NAME` to request a single source. `--refresh` replaces local extracts and can change the vintage. Use a separate checkout for that operation. The collector reports failed sources through its exit status and log. The acquisition script records the precise requests, dataflow versions and provider URLs.

A Git-only checkout needs four companion extracts from the pinned snapshot. They are currently supplied as local files in the verification workspace and excluded by Git ignore rules.

- `data/raw/ilo_wages/ilo_monthly_earnings.csv`
- `data/raw/oecd_cbcr/cbcr_table1_aggregate_totals.csv`
- `data/raw/oecd_cbcr/cbcr_table3_etr_aggregates.csv`
- `data/raw/oecd_cts_additional/oecd_cit_revenue_gdp.csv`

Place the exact extracts at these paths and run `shasum -a 256 -c tests/step17_raw_inputs.sha256` before replaying. The input manifest and live collector cannot recover historical provider bytes after a source revision. An independent clean-machine restore still requires supplying the pinned companion files or documenting verified access to them, restoring the lockfile and system tools, and testing the complete build. This is tracked in [R18](docs/refactoring/refactoring_roadmap.md#r18-verify-the-independent-replication-deposit).

| Source | Pinned inputs and acquisition |
|---|---|
| [OECD Corporate Tax Statistics](https://www.oecd.org/en/topics/sub-issues/corporate-tax-statistics.html) | `data/raw/oecd_cbcr/` holds aggregate Tables I–VI, flows `DSD_CBCR@DF_CBCRI` through `DF_CBCRVI`, version 1.1, with FY2023 where published. The `oecd_cbcr` selector fetches the SDMX CSVs. |
| [OECD SDMX](https://sdmx.oecd.org/public/rest/data) | `oecd_tax_rates/`, `oecd_etr/`, `oecd_cts_additional/` and `pillar2_beps/` hold statutory CIT and dividend rates, forward-looking ETRs, `T_1200` comparative revenue and BEPS rule series. Selectors are `oecd_cit_rates`, `oecd_etr`, `oecd_cts_additional` and `pillar2_tracker`. |
| [OECD earnings](https://www.oecd.org/en/data/indicators/average-annual-wages.html) and [ILOSTAT](https://ilostat.ilo.org/data/) | `oecd_wages/` and `ilo_wages/` hold annual, hourly and monthly extracts acquired through the respective SDMX APIs. Selectors are `oecd_wages` and `ilo_wages`. The archived monthly ILO file is the fallback if its raw CSV is absent. |
| [Eurostat inward FATS](https://ec.europa.eu/eurostat/web/structural-business-statistics/database) | `eurostat_fats/` holds `fats_g1b_08`, `fats_activ` and the harmonised gzip CSV produced by the `eurostat_fats` selector. |
| [Eurostat government finance](https://ec.europa.eu/eurostat/databrowser/view/gov_10a_taxag/default/table) and [ECB exchange rates](https://data.ecb.europa.eu/data/datasets/EXR/EXR.A.USD.EUR.SP00.A) | The two pinned CSVs under `data/raw/eurostat_gfs/` supply `gov_10a_taxag` and `EXR.A.USD.EUR.SP00.A` for FY2016–2023. Stage 01 uses annual USD per EUR for the Cyprus CIT denominator. These snapshots are supplied directly. |
| [EUKLEMS & INTANProd](https://euklems-intanprod-llee.luiss.it/) and [Global INTAN-Invest](https://global-intaninvest.luiss.it/) | `euklems_intanprod/` contains national, labour, capital and intangibles accounts. `global_intan_invest/` contains annual and quarterly data. The named selectors download the release files from the links recorded in the collector. |
| [World Bank World Development Indicators](https://databank.worldbank.org/source/world-development-indicators) | `world_bank/` contains bulk GDP per capita (`NY.GDP.PCAP.CD`) and population (`SP.POP.TOTL`) extracts, plus current and historical income classifications. The `world_bank` selector uses bulk CSV with workbook fallback for the WDI series. |
| [US Bureau of Economic Analysis](https://www.bea.gov/data/intl-trade-investment/activities-us-multinational-enterprises-mnes) | `bea_mne/` contains public majority-owned foreign affiliate workbooks, including preliminary FY2023 assets, employment and compensation. The `bea_mne` selector downloads the workbooks. The optional BEA API key is unnecessary for reproduction. |
| [OECD Global Minimum Tax Central Record](https://www.oecd.org/en/topics/sub-issues/global-minimum-tax.html) | `data/raw/pillar2_qdmtt/oecd_central_record_2026_05.csv` is the curated transcription of the 1 May 2026 qualification snapshot. Stage 01 consumes that CSV. The `pillar2_qdmtt` selector fetches a source PDF and a historical tracker CSV separately. |
| Author-curated profit reconciliation | `data/manual/profit_correction_anchors.csv` records jurisdiction, year range, correction rate, uncertainty and source key. Stage 02a combines those anchors with observed adjusted-profit rows and parity signals. The source keys resolve in `writing/bibliography.bib`. The collector does not generate the anchor CSV. |
| National budget evidence | `budget_benchmarks()` and `ladder_official_forecasts()` in module 08 record source URLs, forecast periods, amounts, policy scope and evidence type. Modules 08 and 09 use the same metadata. The model compares channel-matched estimates where the source permits. |

A public deposit should include the authorised input bytes or persistent references to those exact extracts, the runnable code and the derived data. This checkout has no assigned deposit DOI or documented redistribution clearance for every third-party input. Public access to a portal establishes acquisition access. Redistribution depends on the provider's terms. Thesis submissions, drafts, presentation files and third-party literature copies are outside the computational dependency chain and should be excluded from a journal deposit. Consult the [AEA Data and Code Availability Policy](https://www.aeaweb.org/journals/data/data-code-policy), the [Journal of Public Economics author guide](https://www.sciencedirect.com/journal/journal-of-public-economics/publish/guide-for-authors) and [Elsevier research data guidance](https://www.elsevier.com/en-gb/researcher/author/tools-and-resources/research-data/data-guidelines). The journal-specific guide returned HTTP 403 during the verification session.

# Pipeline architecture

`00_config.R` and `00_helpers.R` are sourced libraries. Each numbered execution module runs once. Module 08 uses the benchmark metadata directly, module 09 generates the fiscal ledger and budget comparison, and modules 10 and 11 consume the resulting diagnostics.

| Script | Inputs | Outputs | Time (s) |
|---|---|---|---:|
| 00 config, 00 helpers | Repository and output-root settings | Shared configuration, inference and validation functions | <1 |
| 01 data cleaning | Raw SDMX, FATS, BEA, wage and supplementary extracts | Clean CbCR Tables I–VI, wages, CIT, ETR, activity, GDP and legal status | 20.9 |
| 02a profit reconciliation model | Clean CbCR, statutory rates and manual anchors | Posterior corrections, evidence, holdouts and early revenue diagnostics | 6.1 |
| 02 base correction and merging | Clean inputs and posterior corrections | `base_panel.rds`, Table IV partitions and FATS, wage and BEA bridges | 4.8 |
| 03 stage1 etr | Base panel and Table IV partitions | Affiliate-year and bilateral measurement, ladders, cross-validation and completeness check | 12.4 |
| 04 stage2 sbie | Stage 1, wage and sector bridges | Aggregate and sectoral carve-outs, SBTI and H5 diagnostics | 3.1 |
| 05 stage3 behavioral | Stage 2, base and legal status | FE/IV estimates, alternative estimators, factorial source liabilities and reallocation | 29.7 |
| 06 stage4 5 revenue allocation sbs | Scenario liabilities and policy flags | QDMTT/IIR/UTPR/SbS waterfall, channel and country-year receipts | 14.9 |
| 07 stage4 6 revenue pipeline decomposition | Collector outputs and CIT denominators | ANOVA, Shapley, fiscal salience, typology and core LaTeX overview | 3.6 |
| 07a uncertainty | Reconciliation draws, Stage 1 validation and Stages 2–4.6 | Profit-correction uncertainty and 13 Stage 1 measurement-error files | 7.4 |
| 08 measurement and cbcr extensions | CbCR Tables I–VI, Stages 1–4.6 and forecast metadata | Ladder, bracket substance, rank-consistency and ancillary CbCR diagnostics | 64.5 |
| 09 econometric and reallocation extensions | Core panels, allocation and forecast metadata | Fiscal ledger, legal regimes, stress tests, division bias, CIT recovery and budget backtest | 35.6 |
| 10 accounting bridge and conduit wedge | Core and budget outputs | Conduit and dividend analysis, loss and tax timing bridge, safe harbour and trends | 42.0 |
| 11 policy game and variance extensions | Core, fiscal flows, ladder and accounting bridge | QDMTT games, joint Monte Carlo, expanded factorial and influence diagnostics | 186.7 |
| 12 master scorecard | Core, extension diagnostics and archived thesis fixtures | `master_paper_v2_scorecard.csv` | 12.1 |
| 13 generate exhibits | Inputs listed below | Core and appendix LaTeX, eight main-text tables and eight generated PDF figures | 4.2 |

The historical 15-stage replay took 7 minutes 28 seconds in total on the verification host with the hash-verified Stage 1 cache. A previous full 500-draw Stage 1 run took roughly 40 minutes. Live acquisition and dependency installation are outside these timings.

# Verification

```sh
Rscript --vanilla tests/verify_golden_step15.R
Rscript --vanilla tests/testthat.R
```

For an isolated output tree, pass its path to the verifier and set `GMT_TEST_OUTPUT_ROOT` to that path before running the tests. Use the same specification settings as the replay. The verifier rejects missing, extra and altered CSV or RDS files. It defaults to `r06b`. Select `r05b` for the 363-file historical notch replay under verified parent-only routing. Select `r04b` for the 361-file notch replay with legacy fallback, or `r04` for the preceding 360-file reference. The byte verifier supports R >= 4.3 and uses `tools::sha256sum()`, `sha256sum`, `shasum -a 256` or `openssl dgst -sha256`.

The manuscript tests follow every input and graphic, check non-empty files, reject raw code labels/scientific notation and prohibited dash punctuation, and regenerate every included table in a temporary directory for byte comparison. They also check all eight numbered main-text and six numbered appendix fragments plus the CbCR extension table. PDF metadata can include generation timestamps.


## Exhibit-only reproduction and LaTeX builds

Module 13 reads frozen processed inputs. If the local Table I extract exists under `data/raw/oecd_cbcr/` (or `data/raw/cbcr/`), it recomputes and checks the source counts: 1,367,305 records, 63 parents and 244 affiliates. If absent, it uses the frozen metadata in `raw_table1_counts()`, verified against the extract whose SHA-256 is `721a7b9d7d701f4f987890aee022f0e16e15e0aa48d4f2a163f6f0aac31788e4`. This exception permits exhibit-only reproduction from Git; a full cleaning replay still requires the pinned raw extracts.

To regenerate module 13 exhibits in a separate output tree, run from the repository root with the R library configured as above. The symlink supplies the frozen module inputs. The standalone Stage 4.6 overview is a module 07 output.

```sh
exhibit_root=$(mktemp -d)
mkdir -p "$exhibit_root/data"
ln -s "$(pwd)/data/processed" "$exhibit_root/data/processed"
GMT_OUTPUT_ROOT="$exhibit_root" Rscript --vanilla code/13_generate_exhibits.R
```

To compile the paper and research note, use Python 3 and a TeX installation with `latexmk`, pdfLaTeX and BibTeX. Run from the repository root. Set `exhibits` to the generated directory from an isolated run to build from those outputs.

```sh
exhibits=writing/generated
build_dir=$(mktemp -d)
note='Research note and publication plan GMT revenue decomposition.tex'
cp writing/.latexmkrc writing/make_paper_bib.py writing/bibliography.bib \
  writing/paper_v2.tex "writing/$note" "$build_dir/"
cp -R writing/figures "$exhibits" "$build_dir/"
(
  cd "$build_dir" &&
  python3 make_paper_bib.py &&
  latexmk -pdf -interaction=nonstopmode -halt-on-error paper_v2.tex "$note"
)
```

Both PDFs are written to `$build_dir`. The paper PDF includes Online Appendices A–E.

## Optional statutory-rate cap diagnostic

```sh
Rscript --vanilla code/08a_standard_cit_cap_diagnostic.R
```

This standalone module writes only `docs/audit_standard_vs_targeted_cit_cap.csv`; it is not part of `run_all.R`. The raw statutory file is `data/raw/oecd_tax_rates/oecd_statutory_cit_rates.csv`, and the frozen processed object is `cit_statutory.rds`, not `cit_rates.rds`. In OECD `DSD_TAX_CIT@DF_CIT`, `TARGETING=ST` is standard and `TA` is targeted small-business taxation; `CIT/S1311` is central-government and `CIT_C/S13` is combined. The legacy `cit_top_all` field contains targeted central rates and is preferred by the frozen baseline. The diagnostic compares that selection with standard combined rates and, separately, standard central rates. Missing standard rates imply a 100% cap and are flagged, without silently substituting a targeted rate.

The estimand is the **percentile-cap effect conditional on frozen mean ETRs**, corrected profits, Table IV, BSPI and SBIE shields. L3 uses the production constrained Beta fit; L4 retains the production rank-bounded estimator and strict/anchored source rules. Replayed baseline predictions and ladders must match the frozen outputs. Cross-validation retains S1 = 361, S2 = 70 and S3 = 81; calibration R-squared comes from an OLS regression of the direct outcome on the fitted outcome and year effects. Errors are fitted minus direct, in fractions. Revenue rows are total source liabilities in US$ billions over 2017–2023 or FY2023, with both initial and long-run SBIE rates. They are not annualised collector receipts.

The CSV contains paired cross-validation, five FY2023 domestic cells, all L3/L4 scope/window totals and host-year rate coverage. In particular, it records where the frozen mean was already upper-clipped. A full correction of upstream mean ETRs, reconciliation, behavioural estimates and allocation would be a separate unfrozen specification. See `docs/post_manuscript_audit.md` for findings and verification.

# Exhibit-to-code and data map

Paths below are relative to `writing/generated/`. Unless specified otherwise, the generator is `code/13_generate_exhibits.R`. Bare CSV names resolve under `data/processed/diagnostics/` and bare RDS names under `data/processed/`. The consolidated Stage 4.6 overview is generated by module 07 from the objects also written to the four listed diagnostics. The data, main-table and appendix manifests contain the exact LaTeX inclusions. Historical thesis exhibits are separately archived. Paper v2 table fragments can be included with LaTeX's `\input` using `booktabs` and `longtable`.

### Main text: Tables 1–8

All numbered fragments are in `paper_v2_tables/`. Numbered aliases retain the original table labels and bytes; they do not add or renumber tables in the PDF.

| Table | Fragment | Generator | Frozen input objects/diagnostics |
|---|---|---|---|
| 1. Sample and coverage | `tab_v2_main_table1_sample_and_coverage.tex` | `write_data_descriptive_tables()`, `write_paper_main_table1()` | Verified raw metadata; `base_panel.rds`, `stage1_bilateral_panel.rds`, `stage3_estimation_sample.rds` |
| 2. ETR ladder and validation | `tab_v2_main_table2_etr_ladder_and_crossval.tex` | `write_paper_etr_table()` | `step9_ladder_stage1_stage2_summary.csv`, `step3_stage1_crossval_summary.csv` |
| 3. Substance and SBTI | `tab_v2_main_table3_substance_and_sbti.tex` | `write_paper_substance_table()` | `step4_stage2_sbti_vs_sectoral_sbie_decomposition.csv`, `audit_step4_stage2_bracket_substance.csv` |
| 4. Division bias and semi-elasticities | `tab_v2_main_table4_division_bias_and_ppml.tex` | `write_paper_econometrics_table()` | `step6_division_bias_and_curvature_audit.csv`, `step5_stage3_tax_endogeneity_diagnostics.csv` |
| 5. Variance and uncertainty | `tab_v2_main_table5_variance_and_uncertainty.tex` | `write_paper_variance_table()`, `write_paper_variance_profiles()` | `step7_decomposition_architecture_stress_test.csv`, `step15_globe_accounting_factorial_anova.csv`, `step15_law_of_total_variance_decomposition.csv` |
| 6. Budget backtest and waterfall | `tab_v2_main_table6_budget_backtest_and_waterfall.tex` | `write_paper_budget_table()` | `step9_ladder_budget_backtest.csv`, `step12_cbcr_to_budget_waterfall_bridge.csv` |
| 7. Source and collector ledger | `tab_v2_main_table7_source_collector_ledger.tex` | `write_paper_ledger_table()` | `step7_eu27_source_vs_collector_ledger_2017_2023.csv`, `step7_eu27_institutional_regime_matrix.csv`, `step7_reallocation_destination_rules_comparison.csv` |
| 8. QDMTT repeal | `tab_v2_main_table8_qdmtt_repeal_game.tex` | `write_paper_nash_table()` | `step13_unilateral_qdmtt_deviation_matrix.csv`, `step13_qdmtt_vs_sbti_strategy_comparison.csv` |

### Main text: Figures 1–5

| Figure | File | Generator | Inputs |
|---|---|---|---|
| 1. Revenue filters | `writing/figures/fig_v2_filters.tex` (repository-relative) | Authored TikZ schematic | Conceptual stage definitions in the manuscript; no estimated values |
| 2. Variance attribution | `paper_v2_figures/fig_v2_shapley_variance_core_and_accounting.pdf` | `make_paper_shapley_figure()` | `step7_decomposition_architecture_stress_test.csv`, `step15_globe_accounting_factorial_anova.csv` |
| 3. Budget waterfall and time series | `paper_v2_figures/fig_v2_cbcr_to_budget_waterfall.pdf` | `make_paper_waterfall_figure()` | `step9_ladder_budget_backtest.csv`, `step12_cbcr_to_budget_waterfall_bridge.csv`, `step12_conduit_unwinding_time_series_2017_2026.csv` |
| 4. Country fiscal salience | `figures/fig_country_salience_uncertainty.pdf` | `make_country_salience_plot()` | `stage4_6_fiscal_salience_country.rds`, `stage4_6_anova_by_country.rds` |
| 5. Repeal efficiency and SBTI | `paper_v2_figures/fig_v2_qdmtt_deviation_efficiency_vs_sbti.pdf` | `make_paper_nash_figure()` | `step13_qdmtt_vs_sbti_strategy_comparison.csv` |

### Online Appendices A–E

The following map follows the final manuscript sections. The detailed core-table inventory below supplies the remaining file-level inputs. Appendix fragment numbers identify their corresponding main-text topic; displayed appendix table numbers follow LaTeX counters.

| Appendix | Contents and exhibit entry points | Producing modules and main data |
|---|---|---|
| A. Data, profit reconciliation and notation | Data summary; profit/employee/ETR figure; correction, evidence, holdout, sensitivity and parent-year tables | 01, 02a, 02 and 13; base and Stage 1 panels; `step02a_*` and profit-correction diagnostics |
| B. Low-taxed profit, substance and tax base | Stage 1 coverage/rates/validation/conditioning; measurement-error intervals; Stage 2 tables; `tab_v2_app_table3_h5_regression.tex`; `tab_v2_cbcr_tables_2_3_6_extensions.tex` | 03, 04, 07a, 08 and 13; `step3_*`, `step4_*`, `step14_table3_vs_table4_blending_wedge.csv`, `step14_table6_mne_size_incidence.csv`, `step14_table2_interquartile_skewness.csv`, `step14_business_activity_drivers.csv` |
| C. Behavioural estimation | Sample, regression, specification, IV and tail diagnostics; semi-elasticity figure; `tab_v2_app_table4_behavioural_robustness.tex` | 05, 09 and 13; `step5_*`, including `step5_stage3_model_robustness.csv`; division-bias derivation in the manuscript |
| D. Decomposition, uncertainty and country results | ANOVA, measurement windows, influence, channels and fiscal salience; `tab_v2_app_table5_country_uncertainty.tex`; `tab_v2_app_table6_revenue_scenarios.tex` | 07, 09, 11 and 13; `step7_*`, `step10_jurisdiction_influence_*`, `step15_*`; scenario appendix uses `step7_stage4_6_scenario_summary.csv` |
| E. Allocation law, repeal game and replication | Allocation/SbS tables; `tab_v2_app_table7_regime_sensitivities.tex`; `tab_v2_app_table8_universal_and_optout.tex`; country typology | 06, 07, 09, 11 and 13; `step6_stage4_5_*`, `step7_cyprus_and_article50_sensitivity.csv`, `step13_unilateral_qdmtt_deviation_matrix.csv`, `step7_stage4_6_country_typology_*` |

`write_paper_fragment_aliases()` supplies numbered aliases for main Tables 2, 4 and 6 and appendix fragments 4 and 6. Original filenames remain available to older drafts. The additional composite Paper v2 fragments are historical outputs, not extra main-text tables.

### Core figures

- `figures/fig_country_salience_uncertainty.pdf`
  - Generator `make_country_salience_plot()`
  - Inputs
    - `stage4_6_fiscal_salience_country.rds`
    - `stage4_6_anova_by_country.rds`
- `figures/fig_preferred_channel_composition.pdf`
  - Generator `make_preferred_channel_plot()`
  - Inputs
    - `stage4_6_preferred_channel_summary.rds`
- `figures/fig_profit_employee_etr_bubble.pdf`
  - Generator `make_profit_employee_etr_bubble()`
  - Inputs
    - `base_panel.rds`
    - `stage1_affiliate_year.rds`
- `figures/fig_stage3_semielasticity_estimated.pdf`
  - Generator `make_semielasticity_plot()`
  - Inputs
    - `stage3_model_coefficients.rds`
- `figures/fig_stage46_shapley_variance.pdf`
  - Generator `make_decomposition_plot()`
  - Inputs
    - `stage4_6_main_effects_pooled.rds`
    - `stage4_6_shapley_factor_attribution.rds`

### Core and appendix tables

- `data_descriptive_tables.tex`
  - Generator `write_data_descriptive_tables()`
  - Inputs
    - Included data sample construction, coverage and descriptive fragments
- `results_appendix_tables.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - Included appendix fragments listed in the manifest
- `results_main_tables_manifest.tex`
  - Generator `write_manifest()`
  - Inputs
    - Included main-table fragments listed in the manifest
- `results_tables/appendix_country_revenue_diagnostic.tex`
  - Generator `write_country_revenue_diagnostic_table()`
  - Inputs
    - `step7_stage4_6_scenario_spread_country.csv`
    - `step7_stage4_6_fiscal_salience_country.csv`
- `results_tables/appendix_country_typology_cluster_stability.tex`
  - Generator `write_country_typology_tables()`
  - Inputs
    - `step7_stage4_6_country_typology_cluster_stability.csv`
- `results_tables/appendix_country_typology_features.tex`
  - Generator `write_country_typology_tables()`
  - Inputs
    - `step7_stage4_6_country_typology_feature_matrix.csv`
    - `step7_stage4_6_country_typology_clusters.csv`
- `results_tables/appendix_jurisdiction_influence_decomposition.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step10_jurisdiction_influence_anova_pooled.csv`
    - `step10_jurisdiction_influence_main_effects.csv`
- `results_tables/appendix_jurisdiction_influence_summary.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step10_jurisdiction_influence_case_summary.csv`
- `results_tables/appendix_stage1_bspi_summary.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step3_stage1_bspi_tv_summary.csv`
- `results_tables/appendix_stage1_conditioning.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step3_stage1_conditioning_by_year.csv`
- `results_tables/appendix_stage2_asset_sensitivity.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step4_stage2_sectoral_asset_sensitivity.csv`
- `results_tables/appendix_stage2_payroll_fallback.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step4_stage2_payroll_fallback_by_year.csv`
- `results_tables/appendix_stage3_behaviour_by_year.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step5_stage3_behaviour_by_year.csv`
- `results_tables/appendix_stage3_behavioural_design.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step5_stage3_behavioural_identification_design.csv`
- `results_tables/appendix_stage3_etr_tail_support.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step5_stage3_etr_tail_support.csv`
    - `step5_stage3_tail_reweighting_feasibility.csv`
- `results_tables/appendix_stage3_robustness.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step5_stage3_model_robustness.csv`
- `results_tables/appendix_stage3_sample_summary.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step5_stage3_estimation_sample_summary.csv`
- `results_tables/appendix_stage3_specification_tests.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step5_stage3_specification_tests.csv`
- `results_tables/appendix_stage3_tax_coefficients.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step5_stage3_coefficients.csv`
- `results_tables/appendix_stage3_wald_tests.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step5_stage3_model_wald_tests.csv`
- `results_tables/appendix_stage45_h4_regression.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step6_stage4_5_h4_regression.csv`
- `results_tables/appendix_stage45_sbs_source_exposure.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step6_stage4_5_sbs_source_exposure.csv`
- `results_tables/appendix_stage45_summary.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step6_stage4_5_summary.csv`
- `results_tables/appendix_stage46_country_anova.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step7_stage4_6_anova_by_country.csv`
- `results_tables/appendix_stage46_measurement_sample_decomposition.tex`
  - Generator `write_stage46_measurement_sample_table()`
  - Inputs
    - `step7_stage4_6_measurement_sample_summary.csv`
- `results_tables/appendix_stage46_top_scenarios.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step7_stage4_6_scenario_summary.csv`
- `results_tables/country_revenue_diagnostic.tex`
  - Generator `write_country_revenue_diagnostic_table()`
  - Inputs
    - `step7_stage4_6_scenario_spread_country.csv`
    - `step7_stage4_6_fiscal_salience_country.csv`
- `results_tables/country_typology_clusters.tex`
  - Generator `write_country_typology_tables()`
  - Inputs
    - `step7_stage4_6_country_typology_cluster_profiles.csv`
    - `step7_stage4_6_country_typology_cluster_stability.csv`
- `results_tables/country_typology_pca.tex`
  - Generator `write_country_typology_tables()`
  - Inputs
    - `step7_stage4_6_country_typology_pca_summary.csv`
- `results_tables/data_panel_coverage.tex`
  - Generator `write_data_descriptive_tables()`
  - Inputs
    - `base_panel.rds`
    - `stage1_bilateral_panel.rds`
    - `stage3_estimation_sample.rds`
    - `data/raw/oecd_cbcr/cbcr_table1_aggregate_totals.csv`
- `results_tables/data_sample_construction.tex`
  - Generator `write_data_descriptive_tables()`
  - Inputs
    - `base_panel.rds`
    - `stage1_bilateral_panel.rds`
    - `stage3_estimation_sample.rds`
    - `data/raw/oecd_cbcr/cbcr_table1_aggregate_totals.csv`
- `results_tables/data_summary_statistics.tex`
  - Generator `write_data_descriptive_tables()`
  - Inputs
    - `base_panel.rds`
    - `stage1_bilateral_panel.rds`
    - `stage3_estimation_sample.rds`
    - `data/raw/oecd_cbcr/cbcr_table1_aggregate_totals.csv`
- `results_tables/hypothesis_summary.tex`
  - Generator `write_hypothesis_summary_table()`
  - Inputs
    - `stage4_6_hypothesis_summary.rds`
    - `step7_stage4_6_anova_pooled.csv`
    - `step7_stage4_6_summary.csv`
    - `step5_stage3_model_comparison.csv`
    - `step5_stage3_semielasticity_schedule.csv`
    - `step7_stage4_6_country_typology_pca_summary.csv`
    - `step7_stage4_6_country_typology_cluster_stability.csv`
- `results_tables/preferred_channel.tex`
  - Generator `write_stage46_channel_table()`
  - Inputs
    - `step7_stage4_6_preferred_channel_summary.csv`
- `results_tables/profit_correction_effects.tex`
  - Generator `write_profit_correction_table()`
  - Inputs
    - `step2_profit_correction_by_year.csv`
- `results_tables/profit_correction_evidence_table.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step02a_profit_correction_evidence_summary.csv`
- `results_tables/profit_correction_foreign_holding_chain_sensitivity.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step07a_profit_correction_foreign_holding_chain.csv`
    - `step07a_profit_correction_final_revenue_points.csv`
- `results_tables/profit_correction_parent_year_top20.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step02a_profit_correction_parent_year_top20.csv`
- `results_tables/profit_correction_revenue_sensitivity.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step02a_profit_correction_revenue_sensitivity.csv`
    - `step07a_profit_correction_final_revenue_points.csv`
    - `step02a_profit_correction_revenue_draw_interval.csv`
    - `step07a_profit_correction_final_revenue_interval.csv`
- `results_tables/profit_correction_validation_holdout.tex`
  - Generator `write_appendix_tables()`
  - Inputs
    - `step02a_profit_correction_validation_holdout.csv`
- `results_tables/stage1_bspi_validation.tex`
  - Generator `write_stage1_bspi_table()`
  - Inputs
    - `step3_stage1_bspi_validation.csv`
    - `base_panel.rds`
- `results_tables/stage1_crossval.tex`
  - Generator `write_stage1_crossval_table()`
  - Inputs
    - `step3_stage1_crossval_summary.csv`
- `results_tables/stage1_measurement_error_interval.tex`
  - Generator `write_stage1_measurement_error_table()`
  - Inputs
    - `step9_stage1_measurement_error_preferred_interval.csv`
- `results_tables/stage1_rates.tex`
  - Generator `write_stage1_rates_table()`
  - Inputs
    - `step3_stage1_scenario_by_year.csv`
- `results_tables/stage1_source_coverage.tex`
  - Generator `write_stage1_source_table()`
  - Inputs
    - `step3_stage1_pair_year_branch_by_year.csv`
    - `stage1_bilateral_panel.rds`
- `results_tables/stage2_aggregate.tex`
  - Generator `write_stage2_aggregate_table()`
  - Inputs
    - `step4_stage2_scenario_by_year.csv`
- `results_tables/stage2_h5_regression.tex`
  - Generator `write_stage2_h5_table()`
  - Inputs
    - `step4_stage2_sectoral_h5_regression_clustered.csv`
- `results_tables/stage2_sectoral_sbti.tex`
  - Generator `write_stage2_sectoral_table()`
  - Inputs
    - `step4_stage2_sectoral_country_summary.csv`
- `results_tables/stage3_econometric_scorecard.tex`
  - Generator `write_stage3_econometric_scorecard_table()`
  - Inputs
    - `step5_stage3_model_comparison.csv`
    - `step5_stage3_model_wald_tests.csv`
    - `step5_stage3_tax_endogeneity_diagnostics.csv`
    - `step5_stage3_specification_tests.csv`
    - `step5_stage3_etr_tail_support.csv`
    - `step5_stage3_model_robustness.csv`
    - `step10_jurisdiction_influence_case_summary.csv`
- `results_tables/stage3_iv_diagnostics.tex`
  - Generator `write_stage3_iv_table()`
  - Inputs
    - `step5_stage3_tax_endogeneity_diagnostics.csv`
- `results_tables/stage3_main_regression.tex`
  - Generator `write_stage3_main_regression_table()`
  - Inputs
    - `step5_stage3_coefficients.csv`
    - `step5_stage3_model_comparison.csv`
    - `step5_stage3_tax_endogeneity_diagnostics.csv`
- `results_tables/stage3_model_comparison.tex`
  - Generator `write_stage3_model_table()`
  - Inputs
    - `step5_stage3_model_comparison.csv`
- `results_tables/stage3_regression_table.tex`
  - Generator `write_stage3_regression_table()`
  - Inputs
    - `step5_stage3_coefficients.csv`
    - `step5_stage3_model_comparison.csv`
- `results_tables/stage3_semielasticity.tex`
  - Generator `write_stage3_semielasticity_table()`
  - Inputs
    - `step5_stage3_semielasticity_schedule.csv`
- `results_tables/stage46_measurement_sample_decomposition.tex`
  - Generator `write_stage46_measurement_sample_table()`
  - Inputs
    - `step7_stage4_6_measurement_sample_summary.csv`
- `results_tables/stage4_6_anova.tex`
  - Generator `write_stage46_anova_table()`
  - Inputs
    - `step7_stage4_6_anova_pooled.csv`
- `results_tables/stage4_6_factor_decomposition.tex`
  - Generator `write_stage46_factor_decomposition_table()`
  - Inputs
    - `step7_stage4_6_shapley_factor_attribution.csv`
    - `step7_stage4_6_main_effects_pooled.csv`
- `stage4_6_results_tables.tex`
  - Generator `write_generated_latex()`
  - Inputs
    - `step7_stage4_6_anova_pooled.csv`
    - `step7_stage4_6_preferred_channel_summary.csv`
    - `step7_stage4_6_scenario_spread_country.csv`
    - `step7_stage4_6_preferred_behavioural_channel_summary.csv`
