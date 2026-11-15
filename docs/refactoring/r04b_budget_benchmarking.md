# R04b. National budget benchmarking

The historical reference is `845936e972112b927fcfd44c5e27e0df6522b3ba`. Its Table 6 Panel A selected L3 from [the frozen ladder diagnostic](../../data/processed/diagnostics/step9_ladder_budget_backtest.csv) and described the result as a 32-scenario range. Stage 08 built L3 by fixing `x1_etr = 1`. R04b retains that diagnostic and adds [a versioned scenario-range diagnostic](../../data/processed/diagnostics/step9_budget_benchmark_scenario_ranges_r04b.csv).

## Design and comparison

- The 32-case core is the five binary factors crossed. Stage 08 checks that the 16 host-average L1 cases and 16 host-pooled distributional L3 cases have disjoint identifiers and cover that design. It compares unsummed source liabilities and each of QDMTT, IIR, the UTPR pool and SbS extinction by scenario, parent, affiliate and year against Stage 06. It checks EU27 collector totals and individual collection channels against Stage 06 by scenario, country, year and, for channels, instrument. Collector sums allow US$0.001 for summation order. Source comparisons are exact.
- L2 bilateral averages and the L4 bilateral distribution variants reuse scenario identifiers as labels under other measurement specifications. They are outside the core. Panel B holds L3, aggregate SBIE, initial rates, behaviour and SbS fixed while successively adjusting the accounting base. The accounting bridge also enters a separate 64-case variance analysis elsewhere in the paper.
- The four reported scopes are `l3` (16, distributional), `core` (32, both ETR methods), `l3_policy` (8, distributional at the documented policy setting) and `core_policy` (16, both ETR methods at that setting). Policy-unknown cases produce explicit `policy_unknown` records with zero eligible scenarios and missing statistics. This zero is a count.
- The diagnostic has one row per country, benchmark, model window and scope. It matches channels before annualising nominal USD amounts across all five years for 2019–2023 or the single FY2023. It then divides by 1.0813 USD per EUR, the 2023 annual reference rate used for both windows, and by one billion. Government amounts were already in EUR. [ECB annual series](https://data.ecb.europa.eu/data/datasets/EXR/EXR.A.USD.EUR.SP00.A) · [Bundesbank historical values](https://www.bundesbank.de/resource/blob/810480/48a34aba4c174775d4fd07c5ae8f70cd/mL/0-wechselkursstatistik-data.pdf)
- Overlap means the closed benchmark interval intersects the closed interval between the smallest and largest model values. The closest scenario minimises the distance to the entire official interval, including zero distance anywhere inside. Differences in distance up to €0.001 are counted as ties and the lexicographically first scenario ID is reported. The CSV also retains preferred amounts and IDs for universal (`x10001`) and SbS (`x10011`) where included. These use distributional ETRs, aggregate SBIE, initial rates and behaviour. They are chosen by the paper's specification independently of forecast distance.
- Table 6 Panel A presents both unrestricted ranges so that the effect of fixing ETR measurement is visible. Appendix D gives the policy-restricted ranges and closest scenarios. The historical bases represent exposure under later rules, while the official values include structural estimates and forecasts for specific collection years. The comparison does not identify forecast error on realised receipts, the effect of a single modelling factor on the gap, or a statistical confidence interval.

## Selected benchmark provenance

The eight selected amounts retain their original vintages and values. The corrected diagnostic excludes the other forecast lines for full fiscal impacts including ordinary behavioural CIT. That quantity differs from top-up receipts. It retains comparable component forecasts such as the Dutch €55m QDMTT, the Belgian €350m QDMTT and €300m IIR, and the German €200m full-year effect as distinct from the €1bn cash estimate. The Slovak implementing bill remains an unquantified QDMTT row. The separate Slovak academic QDMTT and direct top-up estimates retain their academic evidence labels.

| Country | Selected benchmark and matched definition | SbS assumption |
| --- | --- | --- |
| NLD | €176m structural, inferred as €55m QDMTT plus €121m IIR/UTPR after the package. The costing uses 2020–2023 CbCR and also models a separate incentives safe harbour. The policy restriction matches the SbS switch only. [Parliamentary response](https://www.eerstekamer.nl/behandeling/20261020/nota_naar_aanleiding_van_het) | SbS |
| DEU | €1bn for cash year 2026 and €200m full-year in the minimum-tax line of the September 2023 draft. The bill-wide fiscal effects also include accompanying tax changes and are separate. [Bundestag 20/8668, fiscal impact tables](https://dserver.bundestag.de/btd/20/086/2008668.pdf) | Universal |
| FRA | €500m on the 2026 budget's global minimum tax line 1304, separate from ordinary corporation tax. The budget line gives no channel split. [Finance ministry, PLF revenues annex, p. 22](https://www.budget.gouv.fr/documentation/file-download/30583) · [Senate budget report](https://www.senat.fr/rap/l25-139-1/l25-139-1_mono.html) | Unknown |
| IRL | €3.2bn in 2026 for Pillar Two, with payments starting in June. This is the Department of Finance forecast reported by the Irish Fiscal Advisory Council. The Council's estimate of the permanent share is a different quantity. [IFAC, November 2025, supporting item 5](https://www.fiscalcouncil.ie/wp-content/uploads/2025/11/Supporting-items-Fiscal-Assessment-Report-November-2025.pdf) | Unknown |
| LUX | €80m in the 2026 draft budget, line 37.002. The line does not disaggregate the channels. [2026 draft budget, volume 2](https://budget.public.lu/dam-assets/lb/budget2026/links-dokumenter/bu-2026-volume-2-pour-web-v1.pdf) | Unknown |
| BEL | €634m cash for 2024, made up of €350m QDMTT plus €300m IIR less €16m in personnel and IT costs. The corrected model projection uses gross QDMTT plus IIR. The remaining gross-to-net difference is explicit. [Chamber document 55 3272/004, pp. 48–49](https://www.dekamer.be/FLWB/PDF/55/3272/55K3272004.pdf) | Universal |
| AUT | €100m potential additional annual minimum-tax revenue from 2026, before implementation costs, in the original impact assessment. [MinBestG impact assessment, pp. 1 and 8](https://www.parlament.gv.at/dokument/XXVII/I/2322/imfname_1596482.pdf) | Universal |
| SVK | €48.5m for 2026, budget code 112004, the corporate domestic top-up tax under Act 507/2023. The corrected projection uses QDMTT only. The budget annex provides the explicit amount and line. [Finance ministry budget annex 2](https://www.mfsr.sk/files/archiv/72/Priloha-2.pdf) · [Slovak Financial Administration, payment timing](https://www.financnasprava.sk/sk/podnikatelia/dane/dorovnavacia-dan) · [Commission notice on IIR and UTPR deferral](https://eur-lex.europa.eu/legal-content/EN/TXT/PDF/?uri=OJ%3AC_202301536) | Unknown |

## Before and after by country

Each cell shows the range in EUR bn per year, the closest scenario (its revenue), and whether the benchmark overlaps the range. The historical column reproduces the original L3 comparison, including total direct receipts for Belgium and Slovakia. Their corrected L3 columns show the channel-scope effect before introducing L1. Values are displayed to four decimals to distinguish small positive flows from zero.

**Yes** means overlap. **Below** and **Above** describe the benchmark relative to the range.

### FY2023

| Country | Benchmark | Historical L3 | Corrected L3 (16) | Core (32) | Policy L3 (8) | Policy core (16) |
| --- | ---: | --- | --- | --- | --- | --- |
| NLD | 0.1760 | 6.3013–10.7283<br>`x11011` (6.3013)<br>Below | 6.3013–10.7283<br>`x11011` (6.3013)<br>Below | 0.1079–10.7283<br>`x00110` (0.1438)<br>Yes | 6.3013–7.9886<br>`x11011` (6.3013)<br>Below | 0.1079–7.9886<br>`x00110` (0.1438)<br>Yes |
| DEU | 1.0000 | 5.0430–11.5532<br>`x11011` (5.0430)<br>Below | 5.0430–11.5532<br>`x11011` (5.0430)<br>Below | 0.5906–11.5532<br>`x01001` (1.1725)<br>Yes | 8.0857–11.5532<br>`x11001` (8.0857)<br>Below | 1.1725–11.5532<br>`x01001` (1.1725)<br>Below |
| FRA | 0.5000 | 1.4581–4.7783<br>`x11011` (1.4581)<br>Below | 1.4581–4.7783<br>`x11011` (1.4581)<br>Below | 0.1353–4.7783<br>`x01001` (0.5271)<br>Yes | Unknown | Unknown |
| IRL | 3.2000 | 4.6528–8.7865<br>`x11011` (4.6528)<br>Below | 4.6528–8.7865<br>`x11011` (4.6528)<br>Below | 4.1980–8.7865<br>`x01011` (4.1980)<br>Below | Unknown | Unknown |
| LUX | 0.0800 | 4.2054–5.9438<br>`x11011` (4.2054)<br>Below | 4.2054–5.9438<br>`x11011` (4.2054)<br>Below | 3.5278–5.9438<br>`x01011` (3.5278)<br>Below | Unknown | Unknown |
| BEL | 0.6340 | 0.7651–2.1326<br>`x11011` (0.7651)<br>Below | 0.6871–1.1059<br>`x11001` (0.6871)<br>Below | 0.0003–1.1059<br>`x11001` (0.6871)<br>Yes | 0.6871–1.1059<br>`x11001` (0.6871)<br>Below | 0.0003–1.1059<br>`x11001` (0.6871)<br>Yes |
| AUT | 0.1000 | 0.3809–0.9150<br>`x11011` (0.3809)<br>Below | 0.3809–0.9150<br>`x11011` (0.3809)<br>Below | 0.0095–0.9150<br>`x01000` (0.1271)<br>Yes | 0.6414–0.9150<br>`x11001` (0.6414)<br>Below | 0.0593–0.9150<br>`x01000` (0.1271)<br>Yes |
| SVK | 0.0485 | 0.0253–0.0406<br>`x10100` (0.0406)<br>Above | 0.0253–0.0406<br>`x10100` (0.0406)<br>Above | 0.0000–0.0406<br>`x10100` (0.0406)<br>Above | Unknown | Unknown |

### 2019–2023

| Country | Benchmark | Historical L3 | Corrected L3 (16) | Core (32) | Policy L3 (8) | Policy core (16) |
| --- | ---: | --- | --- | --- | --- | --- |
| NLD | 0.1760 | 10.1114–15.5896<br>`x11011` (10.1114)<br>Below | 10.1114–15.5896<br>`x11011` (10.1114)<br>Below | 4.1644–15.5896<br>`x01011` (4.1644)<br>Below | 10.1114–12.8688<br>`x11011` (10.1114)<br>Below | 4.1644–12.8688<br>`x01011` (4.1644)<br>Below |
| DEU | 1.0000 | 5.3450–12.5962<br>`x11011` (5.3450)<br>Below | 5.3450–12.5962<br>`x11011` (5.3450)<br>Below | 0.5586–12.5962<br>`x00110` (0.7311)<br>Yes | 8.8852–12.5962<br>`x11001` (8.8852)<br>Below | 1.4109–12.5962<br>`x01001` (1.4109)<br>Below |
| FRA | 0.5000 | 2.5645–7.1621<br>`x11011` (2.5645)<br>Below | 2.5645–7.1621<br>`x11011` (2.5645)<br>Below | 0.1646–7.1621<br>`x00110` (0.2096)<br>Yes | Unknown | Unknown |
| IRL | 3.2000 | 4.2384–8.1454<br>`x11011` (4.2384)<br>Below | 4.2384–8.1454<br>`x11011` (4.2384)<br>Below | 3.9131–8.1454<br>`x01011` (3.9131)<br>Below | Unknown | Unknown |
| LUX | 0.0800 | 6.2003–9.3778<br>`x11011` (6.2003)<br>Below | 6.2003–9.3778<br>`x11011` (6.2003)<br>Below | 5.2859–9.3778<br>`x01011` (5.2859)<br>Below | Unknown | Unknown |
| BEL | 0.6340 | 1.0655–2.7901<br>`x11011` (1.0655)<br>Below | 0.9026–1.7215<br>`x11001` (0.9026)<br>Below | 0.0001–1.7215<br>`x11001` (0.9026)<br>Yes | 0.9026–1.7215<br>`x11001` (0.9026)<br>Below | 0.0001–1.7215<br>`x11001` (0.9026)<br>Yes |
| AUT | 0.1000 | 0.5607–1.0512<br>`x11011` (0.5607)<br>Below | 0.5607–1.0512<br>`x11011` (0.5607)<br>Below | 0.4092–1.0512<br>`x01011` (0.4092)<br>Below | 0.7494–1.0512<br>`x11001` (0.7494)<br>Below | 0.4510–1.0512<br>`x01001` (0.4510)<br>Below |
| SVK | 0.0485 | 0.0409–0.0626<br>`x11100` (0.0487)<br>Yes | 0.0409–0.0626<br>`x11100` (0.0487)<br>Yes | 0.0243–0.1718<br>`x11100` (0.0487)<br>Yes | Unknown | Unknown |

## What changes in the interpretation

On the FY2023 base the conditional minimum exceeds seven budgets. In the full core, five are bracketed (NLD, DEU, FRA, BEL, AUT), Ireland and Luxembourg remain below the minimum, and Slovakia's QDMTT benchmark is above the maximum. Each of the five new overlaps requires adding L1. For NLD, BEL and AUT the overlap survives the reported policy restriction. For DEU it disappears under the pre-SbS regime in both windows. France's policy assumption remains unresolved. The Dutch FY2023 closest discrete scenario is €0.1438bn, below the €0.176bn benchmark even under the matching switch.

Using the annual average over 2019–2023, the full core brackets Germany, France, Belgium and Slovakia. The Netherlands and Austria remain below the minimum on the earlier base, as do Ireland and Luxembourg. Of the four countries with known policy, only the Belgian benchmark overlaps the annualised policy-matched range. This distinguishes the effect of the ETR branch from that of the policy switch. It also shows how much the Dutch comparison depends on the historical base.

The accounting bridge continues to explain sizeable movements within the preferred distributional specification. In Table 6 Panel B its sequence brings FY2023 total receipts closer to the German, French and Irish cash forecasts, subject to the timing and policy differences above. The Dutch and Luxembourg estimates fall sharply, and Luxembourg retains a sizeable gap. Some unadjusted average-ETR scenarios bracket budgets that the preferred distributional baseline exceeds. Budget overlap cannot determine which ETR measure or accounting specification best represents the GloBE base. The paper's variance decomposition, preferred scenario, sequential adjustment amounts and Figure 3 data are unchanged.

## Reproducibility and changed artefacts

The lockfile-compatible R 4.6.0 library at `/private/tmp/gmt-r02-verify.UJ7adqE8/r-library` was used with `LC_ALL=en_US.UTF-8` and `TZ=Europe/Amsterdam`. The historical comparator was the uncached R04 replay at `/private/tmp/gmt-r04.kFHB48Ob/replay`. The complete R04b replay ran all 15 stages, with the 13 Stage 07a measurement-error outputs reused only after their input and output hashes passed. Stage 07a's generator and inputs are outside the correction. Stage 11 recomputed all 500 joint draws. Stages 08 and 13 also ran in an independent copy of the historical intermediates and reproduced the new diagnostic and TeX exactly. Stage 13 ran again on the full replay after the final display-precision decision.

Commands used from the repository root (the build commands ran from an isolated copy of `writing/` with generated exhibits from the full replay):

```sh
export R_LIBS=/private/tmp/gmt-r02-verify.UJ7adqE8/r-library
export LC_ALL=en_US.UTF-8 TZ=Europe/Amsterdam
r04=/private/tmp/gmt-r04.kFHB48Ob/replay
r04b=/private/tmp/gmt-r04b.3WplO6Du
shasum -a 256 -c tests/step17_raw_inputs.sha256
GMT_MEASUREMENT_CACHE_ROOT="$r04" Rscript --vanilla run_all.R --output-root="$r04b/replay"
export GMT_PROJECT_ROOT="$PWD"
mkdir -p "$r04b/check-final"
cp -R "$r04/data" "$r04b/check-final/"
GMT_OUTPUT_ROOT="$r04b/check-final" Rscript --vanilla code/08_measurement_and_cbcr_extensions.R
GMT_OUTPUT_ROOT="$r04b/check-final" Rscript --vanilla code/13_generate_exhibits.R
GMT_OUTPUT_ROOT="$r04b/replay" Rscript --vanilla code/13_generate_exhibits.R
Rscript --vanilla tests/verify_golden_step15.R "$r04" r04
Rscript --vanilla tests/verify_golden_step15.R "$r04b/check-final"
Rscript --vanilla tests/verify_golden_step15.R "$r04b/replay"
Rscript --vanilla tests/verify_golden_step15.R
Rscript --vanilla -e 'testthat::test_dir("tests/testthat", filter="budget-benchmark-ranges|budget-waterfall")'
Rscript --vanilla tests/testthat.R
GMT_TEST_OUTPUT_ROOT="$r04b/replay" Rscript --vanilla tests/testthat.R
```

```sh
python3 make_paper_bib.py
latexmk -pdf -interaction=nonstopmode -halt-on-error paper_v2.tex
```

All 54 raw hashes and all 360 historical processed hashes matched. The separately versioned R04b reference pins the 144-row scenario-range CSV and checks 361 processed files in total. The old manifest digests and legacy ladder and bridge outputs are identical. The targeted suites passed 97 expectations. Both complete suites passed 922 expectations with zero failures, warnings or skips. The replay produced 81 generated TeX fragments. Of the 80 historical fragments, 78 matched byte for byte and only the canonical Table 6 and its numbered alias changed. Panel B compares byte for byte in both files. All eight figure PDFs match after stripping creation and modification timestamps, including Figure 3. The 76-page manuscript built with resolved references and citations, with the pre-existing underfull bibliography box. Table 6, Figure 3 and Table D.12 were visually checked in the fresh PDF. The generated bibliography matched exactly. The paper PDF hash below identifies the compiled copy and can vary with build metadata.

| R04 SHA-256 | R04b SHA-256 | Artefact |
| --- | --- | --- |
| `Added` | `55db8d355bfec70766c461ddb9d1c1f515fa7d44be2ff948b8ebc2d9b0299481` | `data/processed/diagnostics/step9_budget_benchmark_scenario_ranges_r04b.csv` |
| `f42d957ee8f105bcc5d82a8e287a32a3b092f6027f68078a035e658049345edb` | `be21d422e65cadd48dbf91e9c32c312b032e21c0b78900bf963ea36cde6192c2` | `writing/generated/paper_v2_tables/tab_v2_budget_backtest_and_hanlon_waterfall.tex` |
| `f42d957ee8f105bcc5d82a8e287a32a3b092f6027f68078a035e658049345edb` | `be21d422e65cadd48dbf91e9c32c312b032e21c0b78900bf963ea36cde6192c2` | `writing/generated/paper_v2_tables/tab_v2_main_table6_budget_backtest_and_waterfall.tex` |
| `Added` | `c30e9b6af8d05977665435591e626fbbf03dd1bc32ef3eeca5a2971a1204b325` | `writing/generated/paper_v2_tables/tab_v2_app_budget_policy_matched.tex` |
| `c1e8445c6d2fd49121819414639a73f9be83e43a5dd2ee0cf59143638917546c` | `d7cef2553c5f1733612523ed66f7726e04783a158ace25dd277f40c68d21d763` | `writing/paper_v2.tex` |
| `57ad96a6c621a68e687c73b8dcdf3282ed6c27965d3b528fda644e73f61b6cbb` | `d006f34a880d7a5b3764ccfcfc67a0a8c7eec78abf2dbf9d557ccbcdf2baebaa` | `writing/paper_v2.pdf` |
