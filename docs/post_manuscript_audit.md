# Post-manuscript codebase audit

14–15 November 2026 · branch `publication-rework`

The frozen numerical baseline is preserved. The audit resolves exhibit-only raw-data dependence, adds portable byte verification and manuscript lint, and supplies a separate statutory-rate cap diagnostic. The standard headline cap has little effect on L3 revenue but increases L4 liability. Cross-validation does not show a uniform improvement.

## Code and provenance findings

- The reference set is **360 files: 359 in the Step 15 manifest and one Step 17 addition**. Neither manifest nor any processed file was edited.
- The actual raw Table I path is `data/raw/oecd_cbcr/cbcr_table1_aggregate_totals.csv`. Its pinned SHA-256 is `721a7b9d7d701f4f987890aee022f0e16e15e0aa48d4f2a163f6f0aac31788e4`. The local extract was counted: **1,367,305 source records, 63 parent codes and 244 affiliate codes**, before any reshaping or filtering. Module 13 now validates these counts whenever the extract is present and uses the same verified metadata when absent. It also recognises the requested `data/raw/cbcr/` location. A present but inconsistent extract fails rather than silently falling back.
- All numbered R modules 00–13, including the letter-suffixed modules, were parsed and inspected for debug calls, absolute paths, graphics-device handling and unused assignments. No interactive debug calls or manually opened graphics devices were found. Two unused variables were removed from module 13. Module 01 now cleans temporary workbook extraction/conversion directories on success or failure and quotes paths passed to LibreOffice. Execution from the repository root remains the documented convention; no machine-specific input path was introduced.
- The SHA-256 verifier now supports R >= 4.3 and issues a note outside the 4.6 runtime series. It uses the native tools function when available and a checked system backend otherwise. Exact bytes are hashed without reserialising analytical RDS objects. Both backends were exercised on the current R 4.6 host, including all 360 frozen paths and filenames with spaces and quotes. **An actual R 4.3 runtime was not available for testing.**
- The manuscript tests recursively check inputs/graphics, table labels and numeric formatting, prohibited dash punctuation, all eight numbered main-text and six numbered appendix fragments, and the CbCR extension table. Every included generated table is compared byte-for-byte with a temporary generation run using the missing-raw fallback. The test also verifies that generation leaves no graphics device open. Five numbered aliases preserve existing table contents, LaTeX labels and pagination; the legacy exhibit inventory test was updated accordingly.
- `REPLICATION.md` now maps the final Tables 1–8, Figures 1–5 and Appendices A–E and records the build commands. Both supervisor email drafts mention both PDFs. The untracked root `gemini.txt` was removed.

## What the statutory-rate diagnostic measures

The actual frozen object is `data/processed/cit_statutory.rds`, not `cit_rates.rds`. Its `cit_top_all` field is misleadingly named: it holds `TARGETING=TA` from the central-government series, while `cit_standard` holds `ST` from that same central series. The frozen selection prefers the targeted rate when available. The raw extract also contains **combined central and sub-central standard rates**, `MEASURE=CIT_C`, `SECTOR=S13`, `TARGETING=ST`. This distinction is consistent with the [OECD description of headline statutory rates](https://www.oecd.org/en/publications/corporate-tax-statistics-2025_6a915941-en/full-report/component-6.html) and its [explanatory annex on standard and targeted small-business rates](https://www.oecd.org/content/dam/oecd/en/topics/policy-sub-issues/corporate-taxation/explanatory-annex-corporate-tax-statistics.pdf). The cleaning comments are corrected, while the frozen schema and rate-selection logic are retained.

The primary comparator is `min(1, standard_combined_rate + 0.05)`. A second, standard-central comparison separates the targeting effect from the government-coverage effect. The CSV reports both, together with host-year rates and coverage. There are 1,503 host-years, 145 changed headline caps and 501 host-years without an observed standard combined rate; missing rates retain the explicit no-cap value of 1 and are flagged.

**This is a conditional percentile-cap sensitivity, not a fully corrected baseline.** Corrected profit, mean ETR anchors, Table IV partitions, BSPI shares, sample membership and SBIE shields remain frozen. L3 retains its constrained Beta estimator, while L4 retains its rank-bounded estimator and strict/anchored source rules. Host and bilateral precision changes propagate through the anchored ladder. Baseline ladders are replayed against their frozen columns. Cross-validation fits are checked within 1e-7, allowing approximately 1e-8 variation from CSV round trips, and reported baseline metrics use the archived predictions.

Frozen host means were upper-clipped in 167 host-years. For example, France's FY2023 host mean is held at 20.0% although the underlying ratio is 25.45%; Germany's is held at 20.825% rather than 27.57%. A complete correction would revisit these anchors and upstream reconciliation, then propagate the revised inputs through behavioural estimation and allocation in a separate, explicitly unfrozen specification. The present results do not justify mechanically replacing the paper's frozen revenue figures.

## Cross-validation

Entries are **frozen → standard headline**. Bias is median fitted minus direct; errors are percentage points. Calibration R-squared includes year effects, with direct outcomes regressed on fitted outcomes. These are diagnostics within the existing validation samples, not new out-of-sample predictive tests.

| Sample | N | Low-share median bias | Low-share MAE | Liability-rate MAE | Low-share R² | Liability R² |
|---|---:|---:|---:|---:|---:|---:|
| S1 | 361 | 0.00 → 0.24 | 25.16 → 25.11 | 3.16 → 3.10 | 0.255 → 0.248 | 0.269 → 0.267 |
| S2 | 70 | 3.03 → 3.78 | 19.66 → 19.49 | 1.74 → 1.85 | 0.453 → 0.441 | 0.549 → 0.531 |
| S3 | 81 | -3.99 → -1.11 | 18.64 → 18.07 | 1.84 → 1.80 | 0.484 → 0.476 | 0.520 → 0.537 |

Low-share MAE improves slightly in all three samples, but calibration R-squared falls, and liability-rate MAE worsens in S2. The standard headline series is the more appropriate comparator for large-group headline taxation; this diagnostic alone does not establish that the cap or distributional estimator is better calibrated.

## FY2023 domestic cells

Caps and low shares are percentages. Stage 1 liability is US$ billions. The table shows strict L4; the CSV also contains L3, anchored L4, liability rates, top-up gaps and source tiers.

| Domestic cell | Cap: frozen → headline | Strict L4 low share | Strict L4 Stage 1 liability | Source |
|---|---:|---:|---:|---|
| FRA → FRA | 20.000 → 30.825 | 25.00 → 32.84 | 0.540 → 0.993 | Bilateral Table I fit |
| DEU → DEU | 20.825 → 35.058 | 25.00 → 32.94 | 0.881 → 1.608 | Bilateral Table I fit |
| NLD → NLD | 24.000 → 30.800 | 0.00 → 0.00 | 0.000 → 0.000 | Bilateral average fallback |
| BEL → BEL | 25.000 → 30.000 | 25.00 → 25.00 | 0.173 → 0.173 | Bilateral Table I fit |
| LUX → LUX | 21.050 → 29.940 | 92.39 → 91.54 | 1.409 → 1.495 | Bilateral Table I fit |

The German change reflects central versus combined rates, not a targeted German rate. The Netherlands domestic cell remains on its bilateral-average fallback; changing percentile caps cannot alter that strict-L4 cell with its mean fixed.

## Revenue sensitivity

Entries are **frozen → standard headline**, in **US$ billions of source liability over the stated window**, before behaviour or allocation. The 2017–2023 rows are seven-year totals, not annual averages. Post-SBIE amounts use the unchanged aggregate bilateral shields.

| Window | Scope | Ladder | Stage 1 | Post-SBIE initial | Post-SBIE long-run |
|---|---|---|---:|---:|---:|
| 2017–2023 | EU27 | L3 | 360.491 → 360.491 | 328.154 → 328.154 | 340.994 → 340.994 |
| 2017–2023 | EU27 | L4 anchored | 366.565 → 381.227 | 336.648 → 348.610 | 348.342 → 361.403 |
| 2017–2023 | EU27 | L4 strict | 316.147 → 321.522 | 291.639 → 295.768 | 301.184 → 305.813 |
| 2017–2023 | Global | L3 | 1758.939 → 1758.941 | 1586.129 → 1586.131 | 1653.413 → 1653.415 |
| 2017–2023 | Global | L4 anchored | 1948.290 → 1978.312 | 1753.693 → 1779.361 | 1828.798 → 1856.214 |
| 2017–2023 | Global | L4 strict | 1563.523 → 1574.476 | 1415.822 → 1424.602 | 1472.839 → 1482.487 |
| FY2023 | EU27 | L3 | 42.530 → 42.530 | 37.800 → 37.800 | 39.679 → 39.679 |
| FY2023 | EU27 | L4 anchored | 40.840 → 42.982 | 36.805 → 38.377 | 38.398 → 40.199 |
| FY2023 | EU27 | L4 strict | 39.099 → 40.986 | 35.394 → 36.776 | 36.853 → 38.437 |
| FY2023 | Global | L3 | 250.004 → 250.004 | 224.633 → 224.633 | 234.553 → 234.553 |
| FY2023 | Global | L4 anchored | 285.834 → 289.994 | 256.672 → 259.938 | 268.007 → 271.630 |
| FY2023 | Global | L4 strict | 257.366 → 261.140 | 231.518 → 234.470 | 241.616 → 244.895 |

In FY2023, EU27 post-SBIE initial liability increases by US$1.573bn for anchored L4 and US$1.383bn for strict L4, while L3 is unchanged. Globally, the increases are US$3.266bn and US$2.952bn; the L3 change is only about US$0.119 million. This reflects which source tier each ladder actually uses, not general insensitivity to the statutory-rate selection.

The complete paired output is [audit_standard_vs_targeted_cit_cap.csv](audit_standard_vs_targeted_cit_cap.csv), generated by [the opt-in diagnostic](../code/08a_standard_cit_cap_diagnostic.R). It sits outside the golden directory, and the golden allowlist remains unchanged.

## Final verification

| Check | Result |
|---|---|
| Module 13 generation | Passed with the local raw extract; temporary no-raw regeneration also passed |
| Golden SHA-256 verifier | **360/360 exact matches**, both native and system hashing |
| Complete `testthat` directory | **696 passed, 0 failed, 0 warnings, 0 skips** |
| Main paper bibliography and three LaTeX passes | **75 pages; 0 errors, 0 warnings, 0 overfull boxes, 0 undefined references** |
| Supervisor memo, two LaTeX passes | **4 pages; 0 errors, 0 warnings, 0 overfull boxes** |
| Visual PDF review | All 79 pages rendered and contact sheets inspected; detailed checks of table pages found no clipping or overlap |
| Processed-data before/after comparison | All 360 files unchanged; no additions or removals |
| Repository hygiene | `gemini.txt` and temporary test output removed; no untracked scratch files |
| Whitespace | `git diff --check` passed |

The test host used R 4.6.0 with the existing package library selected through `R_LIBS_USER`. No packages were installed or lockfile versions changed. PDF generation timestamps changed, as expected; analytical data and numerical table content did not. No commit, push or external message was made.
