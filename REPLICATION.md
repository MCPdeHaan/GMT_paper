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
Rscript --vanilla run_all.R
```

The command writes analysis data to `data/processed/`, diagnostics to `data/processed/diagnostics/`, and LaTeX and PDF exhibits to `writing/generated/`. For a separate run, pass `--output-root=/absolute/path`. All inputs resolve from this checkout. An isolated replay may reuse the 13 Stage 1 measurement-error outputs from the checkout or from a completed replay supplied through `GMT_MEASUREMENT_CACHE_ROOT`. Module 07a checks the SHA-256 hashes of all 13 files and the nine current simulation inputs before reusing them. If any check fails, it runs the full 500-draw simulation. The seeds are 20260503 for measurement error, 20260613 for profit reconciliation uncertainty and 20261113 for joint uncertainty. The main analysis runs offline after dependency installation.

# Data availability and provenance

The working package contains the exact public aggregate extracts used for this analysis and the derived analysis files. The input manifest identifies the local bytes of each extract. The underlying MNE filings are confidential and were not accessed. The models use public aggregates and cannot reconstruct firm-level cross-classifications. `data/baseline_processed/` and `data/baseline_diagnostics/` contain the historical comparison fixtures. `writing/baseline_generated/` holds the corresponding archived exhibit fragments.

The listed public portals do not charge for downloading the extracts. A refresh depends on provider uptime, throughput and revision schedules. The live collector can take several minutes or longer and requires Python 3 and `requests`. Run `python3 code/collect_all_data.py --list` for source selectors or `--source NAME` to request a single source. `--refresh` replaces local extracts and can change the vintage. Use a separate checkout for that operation. The collector reports failed sources through its exit status and log. The acquisition script records the precise requests, dataflow versions and provider URLs.

A Git-only checkout needs four local extracts from the pinned snapshot. These are `ilo_monthly_earnings.csv`, `cbcr_table1_aggregate_totals.csv`, `cbcr_table3_etr_aggregates.csv` and `oecd_cit_revenue_gdp.csv`, under the paths in the input manifest. They are present in the verification workspace and excluded by Git ignore rules. An independent replicator needs those exact bytes alongside the checkout. Check the hashes before proceeding. The input manifest and live collector by themselves do not recover historical provider bytes if a portal has revised its series.

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
| 13 generate exhibits | Inputs listed below | Core and appendix LaTeX, eight Paper v2 tables and seven figures in total | 4.2 |

The 15 stages took 7 minutes 28 seconds in total on the verification host with the hash-verified Stage 1 cache. A previous full 500-draw Stage 1 run took roughly 40 minutes. Live acquisition and dependency installation are outside these timings.

# Verification

```sh
Rscript --vanilla tests/verify_golden_step15.R
Rscript -e "testthat::test_dir('tests/testthat')"
```

For an isolated output tree, pass its path to the verifier and set `GMT_TEST_OUTPUT_ROOT` to that path before running the tests. The verifier rejects missing, extra and altered CSV or RDS files. The active reference set has 359 Step 15 files and the separately pinned Step 17 sensitivity CSV. The obsolete PwC RDS was retired from the reference set. The remaining hashes are the original frozen values. Table fragments are tested for well-formed labels and invalid numeric tokens. PDF metadata can include generation timestamps.

# Exhibit-to-code and data map

Paths below are relative to `writing/generated/`. Unless specified otherwise, the generator is `code/13_generate_exhibits.R`. Bare CSV names resolve under `data/processed/diagnostics/` and bare RDS names under `data/processed/`. The consolidated Stage 4.6 overview is generated by module 07 from the objects also written to the four listed diagnostics. The data, main-table and appendix manifests contain the exact LaTeX inclusions. Historical thesis exhibits are separately archived. Paper v2 table fragments can be included with LaTeX's `\input` using `booktabs` and `longtable`.

### Paper v2 tables and figures

- `paper_v2_figures/fig_v2_cbcr_to_budget_waterfall.pdf`
  - Generator `make_paper_waterfall_figure()`
  - Inputs
    - `step9_ladder_budget_backtest.csv`
    - `step12_cbcr_to_budget_waterfall_bridge.csv`
    - `step12_conduit_unwinding_time_series_2017_2026.csv`
- `paper_v2_figures/fig_v2_qdmtt_deviation_efficiency_vs_sbti.pdf`
  - Generator `make_paper_nash_figure()`
  - Inputs
    - `step13_qdmtt_vs_sbti_strategy_comparison.csv`
- `paper_v2_tables/tab_v2_budget_backtest_and_hanlon_waterfall.tex`
  - Generator `write_paper_budget_table()`
  - Inputs
    - `step9_ladder_budget_backtest.csv`
    - `step12_cbcr_to_budget_waterfall_bridge.csv`
- `paper_v2_tables/tab_v2_cbcr_tables_2_3_6_extensions.tex`
  - Generator `write_paper_cbcr_table()`
  - Inputs
    - `step14_table3_vs_table4_blending_wedge.csv`
    - `step14_table6_mne_size_incidence.csv`
    - `step14_table2_interquartile_skewness.csv`
    - `step14_business_activity_drivers.csv`
- `paper_v2_tables/tab_v2_etr_ladder_and_crossval.tex`
  - Generator `write_paper_etr_table()`
  - Inputs
    - `step9_ladder_stage1_stage2_summary.csv`
    - `step3_stage1_crossval_summary.csv`
- `paper_v2_tables/tab_v2_factorial_globe_and_total_variance.tex`
  - Generator `write_paper_variance_table()`
  - Inputs
    - `step7_decomposition_architecture_stress_test.csv`
    - `step15_globe_accounting_factorial_anova.csv`
    - `step15_law_of_total_variance_decomposition.csv`
- `paper_v2_tables/tab_v2_qdmtt_nash_deviation_game.tex`
  - Generator `write_paper_nash_table()`
  - Inputs
    - `step13_unilateral_qdmtt_deviation_matrix.csv`
    - `step13_qdmtt_vs_sbti_strategy_comparison.csv`
- `paper_v2_tables/tab_v2_source_collector_ledger_and_regimes.tex`
  - Generator `write_paper_ledger_table()`
  - Inputs
    - `step7_eu27_institutional_regime_matrix.csv`
    - `step7_reallocation_destination_rules_comparison.csv`
    - `step7_eu27_source_vs_collector_ledger_2017_2023.csv`
    - `step7_cyprus_and_article50_sensitivity.csv`
- `paper_v2_tables/tab_v2_stage2_sbti_and_bracket_substance.tex`
  - Generator `write_paper_substance_table()`
  - Inputs
    - `step4_stage2_sbti_vs_sectoral_sbie_decomposition.csv`
    - `audit_step4_stage2_bracket_substance.csv`
    - `step4_stage2_sectoral_h5_panel_regression.csv`
- `paper_v2_tables/tab_v2_stage3_division_bias_and_ppml.tex`
  - Generator `write_paper_econometrics_table()`
  - Inputs
    - `step6_division_bias_and_curvature_audit.csv`
    - `step5_stage3_tax_endogeneity_diagnostics.csv`

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
