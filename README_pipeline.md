# GMT Pipeline Map

This repository estimates Global Minimum Tax revenue using public OECD CbCR data and supplementary public macro, tax and policy sources. The empirical strategy is staged so that each output can be audited before it enters the next stage. The canonical execution order is in `run_all.R`.

<table>
<thead>
<tr>
<th>Script</th>
<th>Role</th>
<th>Main inputs</th>
<th>Main outputs</th>
<th>Thesis support</th>
</tr>
</thead>
<tbody>
<tr>
<td><code>code/00_config.R</code></td>
<td>Defines shared paths, years, EU27 country lists, GMT rate and scenario variables.</td>
<td>None.</td>
<td>In-memory constants.</td>
<td>All empirical sections.</td>
</tr>
<tr>
<td><code>code/00_helpers.R</code></td>
<td>Provides small reusable checks and safe arithmetic. Join helpers report missing keys, duplicate right-hand keys and row expansion.</td>
<td><code>code/00_config.R</code>.</td>
<td>In-memory helper functions.</td>
<td>Reproducibility and audit trail.</td>
</tr>
<tr>
<td><code>code/01_data_cleaning.R</code></td>
<td>Tidies raw OECD CbCR, Eurostat FATS, EUKLEMS, World Bank, BEA, OECD tax-rate, Pillar Two, BEPS and CIT revenue files. It does not merge empirical panels.</td>
<td><code>data/raw/**</code>.</td>
<td>Clean <code>.rds</code> files in <code>data/processed</code>, plus <code>data/processed/diagnostics/summary.csv</code>.</td>
<td>Data section.</td>
</tr>
<tr>
<td><code>code/02a_profit_reconciliation_model.R</code></td>
<td>Estimates the parent-year profit reconciliation model from observed adjusted-profit cells, manual external anchors and public ETR-parity diagnostics before Stage 1.</td>
<td><code>cbcr_table1.rds</code>, <code>cit_statutory.rds</code>, <code>data/manual/profit_correction_anchors.csv</code>.</td>
<td><code>profit_correction_parent_year.rds</code>, <code>profit_correction_evidence.rds</code>, and <code>diagnostics/step02a_*.csv</code>.</td>
<td>Profit, tax and ETR cleaning.</td>
</tr>
<tr>
<td><code>code/02_base_correction_and_merging.R</code></td>
<td>Builds the parent-affiliate-year CbCR spine, adds country metadata and tax-policy inputs, constructs payroll proxies, applies the Step 2a profit reconciliation, and writes sectoral bridge inputs.</td>
<td>Clean files in <code>data/processed</code>.</td>
<td><code>base_panel.rds</code>, base-panel bridge files and <code>diagnostics/step2_*.csv</code>.</td>
<td>Data construction and measurement sections.</td>
</tr>
<tr>
<td><code>code/03_stage1_etr.R</code></td>
<td>Estimates low-tax profit exposure before substance exclusions. It combines the average ETR fallback, direct Table IV bracket evidence, percentile/Beta estimates, BSPI shape transport for 2017 to 2018, cross-validation diagnostics and bilateral mapping.</td>
<td><code>base_panel.rds</code>, <code>base_panel_t4_bracket_shares.rds</code>.</td>
<td><code>stage1_affiliate_year.rds</code>, <code>stage1_bilateral_panel.rds</code>, <code>diagnostics/step3_stage1_*.csv</code>.</td>
<td>ETR measurement and low-tax profit section.</td>
</tr>
<tr>
<td><code>code/04_stage2_sbie.R</code></td>
<td>Applies aggregate SBIE and sectoral SBIE with SBTI overlay, including transition rates and diagnostics for payroll, asset and sectoral bridge quality.</td>
<td>Stage 1 outputs and base-panel sectoral bridge files.</td>
<td><code>stage2_bilateral_panel.rds</code>, <code>stage2_affiliate_year.rds</code>, <code>stage2_sectoral_matrix.rds</code>, <code>diagnostics/step4_stage2_*.csv</code>.</td>
<td>Substance exclusion and SBTI section.</td>
</tr>
<tr>
<td><code>code/05_stage3_behavioral.R</code></td>
<td>Estimates the behavioural semielasticity module and applies it as a scenario coefficient. The retained fixed-effect estimator is explicitly manual, with optional <code>fixest</code> equivalence diagnostics when <code>fixest</code> is installed.</td>
<td><code>base_panel.rds</code>, Stage 1 and Stage 2 outputs, OECD forward ETRs, Pillar Two Central Record.</td>
<td><code>stage3_*</code> <code>.rds</code> files and <code>diagnostics/step5_stage3_*.csv</code>.</td>
<td>Behavioural response and robustness section.</td>
</tr>
<tr>
<td><code>code/06_stage4_5_revenue_allocation_sbs.R</code></td>
<td>Implements the legal allocation waterfall: QDMTT first, then IIR, then UTPR, with SbS safe-harbour extinguishment where applicable. Conservation is checked at source and allocation levels.</td>
<td>Stage 3 revenue panel and policy flags.</td>
<td><code>stage4_5_revenue_by_channel.rds</code>, <code>stage4_5_revenue_country_year.rds</code>, UTPR weights, conservation diagnostics.</td>
<td>Legal allocation and Side-by-Side section.</td>
</tr>
<tr>
<td><code>code/07_stage4_6_revenue_pipeline_decomposition.R</code></td>
<td>Runs the 2^5 factorial decomposition, country-year checks, preferred scenario summaries, fiscal salience measures and country typology.</td>
<td>Stage 4.5 outputs, CIT revenue, World Bank macro data, Stage 1 measurement inputs.</td>
<td><code>stage4_6_*</code> <code>.rds</code> files, <code>diagnostics/step7_stage4_6_*.csv</code>, <code>writing/generated/stage4_6_results_tables.tex</code>.</td>
<td>Main results, decomposition and country heterogeneity sections.</td>
</tr>
<tr>
<td><code>code/07a_profit_correction_revenue_uncertainty.R</code></td>
<td>Propagates the parent-year profit-correction draws through the preferred behavioural Stage 4.6 revenue panel while holding low-tax shares, behavioural filters and allocation weights fixed.</td>
<td><code>profit_correction_parent_year.rds</code> and Stage 4.5 allocation outputs.</td>
<td><code>profit_correction_final_revenue_uncertainty.rds</code> and <code>diagnostics/step07a_*.csv</code>.</td>
<td>Profit reconciliation appendix and uncertainty diagnostics.</td>
</tr>
<tr>
<td><code>code/09_stage1_measurement_error_simulation.R</code></td>
<td>Optional Monte Carlo layer for Stage 1 measurement error. It preserves the seed and saved draw outputs while processing draw results iteratively.</td>
<td>Stage 1 to Stage 4.6 outputs and cross-validation diagnostics.</td>
<td><code>stage1_measurement_error_*</code> <code>.rds</code> files and <code>diagnostics/step9_stage1_measurement_error_*.csv</code>.</td>
<td>Measurement-error robustness section.</td>
</tr>
<tr>
<td><code>code/10_jurisdiction_influence_robustness.R</code></td>
<td>Optional leave-one-parent and leave-one-affiliate robustness diagnostics. The target diagnostic records whether a jurisdiction is included because of high leverage, named targeting or both.</td>
<td>Stage 1, Stage 3 and Stage 4.6 outputs.</td>
<td><code>jurisdiction_influence_*</code> <code>.rds</code> files and <code>diagnostics/step10_jurisdiction_influence_*.csv</code>.</td>
<td>Jurisdiction influence robustness section.</td>
</tr>
<tr>
<td><code>code/11_sesh_notch_bunching_diagnostic.R</code></td>
<td>Optional Simplified ETR Safe Harbour notch diagnostic. Public CbCR data are pre-reform, so the module estimates exposure around the 15 per cent threshold, not realised post-reform bunching.</td>
<td>Stage 1 affiliate-year and behavioural outputs.</td>
<td><code>sesh_notch_*.rds</code> and <code>diagnostics/step11_sesh_notch_*.csv</code>.</td>
<td>SESH diagnostic appendix.</td>
</tr>
<tr>
<td><code>code/08_generate_results_tables.R</code></td>
<td>Generates public LaTeX tables from processed outputs and diagnostics through <code>write_results_tables()</code>.</td>
<td><code>data/processed/**</code> and <code>data/processed/diagnostics/**</code>.</td>
<td><code>writing/generated/*.tex</code> and <code>writing/generated/results_tables/*.tex</code>.</td>
<td>Main tables and appendices.</td>
</tr>
</tbody>
</table>

Before refactoring or auditing output equivalence, run `Rscript dev/create_baseline_outputs.R` once. The regression tests compare `data/processed`, `data/processed/diagnostics` and `writing/generated` against `data/baseline_processed`, `data/baseline_diagnostics` and `writing/baseline_generated`.
