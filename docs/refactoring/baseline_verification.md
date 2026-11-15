# Acceptance baseline verification

## R02. Passing acceptance baseline

R02 started from a clean `publication-rework` at `0052f24` on 15 November 2026. The punctuation test still opened `supervisor_pitch_memo.tex`, which had been renamed in `ca0f41d`. The failed `readLines()` emitted a missing-file warning and then errored. The test now checks the tracked research note and reports a missing source path directly. Both punctuation assertions are retained. The replication guide gives verified temporary-build commands for both documents. Only the build comment in the note source changed. The R01 incident record below retains the original filename.

### Commands

Run from the repository root with R 4.6.0 and the library from [the replication setup](../../REPLICATION.md#package-and-execution). In R02, all 68 installed package versions matched the lockfile. The runs used `LC_ALL=en_US.UTF-8`, `TZ=Europe/Amsterdam` and the existing lockfile-matched local R library.

```sh
shasum -a 256 -c tests/step17_raw_inputs.sha256
Rscript --vanilla tests/verify_golden_step15.R
Rscript --vanilla tests/testthat.R

# Set replay to the absolute path of a completed isolated run.
Rscript --vanilla tests/verify_golden_step15.R "$replay"
GMT_TEST_OUTPUT_ROOT="$replay" Rscript --vanilla tests/testthat.R
git diff --check HEAD
```

For the command above that tests the checkout, run with `GMT_TEST_OUTPUT_ROOT` unset. For compilation and exhibit-only regeneration use the exact [commands in REPLICATION.md](../../REPLICATION.md#exhibit-only-reproduction-and-latex-builds). The TeX commands regenerate the selected bibliography before running `latexmk` in a temporary directory. To build from replay exhibits, set `exhibits="$replay/writing/generated"` in that block.

### Results

| Check | R02 result |
|---|---|
| Pinned inputs and frozen outputs | All 54 raw/manual hashes matched. The checkout and R01 replay each matched all 360 frozen output hashes and the expected path set. |
| Full tracked suite, checkout | 696 passing expectations, zero failures, warnings or skips, 42.5 s. |
| Full tracked suite, R01 replay | 696 passing expectations, zero failures, warnings or skips, 42.5 s. |
| Targeted manuscript suite from gate A | 257 passing expectations, zero failures, warnings or skips. |
| Exhibit-only regeneration | All 79 module 13 TeX files and eight PDFs matched the corresponding tracked outputs. The TeX matched byte-for-byte. Only PDF date metadata differed. The full R01 replay also reproduced the module 07 TeX overview, for 80 exact TeX files. |
| Document builds with tracked and replay exhibits | Both builds produced a 75-page paper and a five-page research note. The bibliography matched byte-for-byte. Both PDFs matched their tracked counterparts after decoding streams and accounting for dates, trailer IDs and cross-reference offsets. The final paper logs retained the pre-existing underfull box. Citations and cross-references resolved. |
| Scope | The production code, lockfile, empirical manuscript, pinned inputs, frozen outputs, tables and figures match the starting revision. The build instruction in the research-note source is a TeX comment. |

R02 reused the existing R01 isolated run because the production pipeline and its inputs are identical. The R01 legacy Stage 1 uncertainty files remain cache-backed. An independent-machine restore, verification on older R runtimes, and a peak replay memory measurement remain open.

### Four companion inputs

The [replication guide](../../REPLICATION.md#data-availability-and-provenance) lists the exact paths for monthly ILO earnings, OECD CbCR Tables I and III, and OECD CIT revenue/GDP. All four were present as Git-ignored local files and matched the raw-input manifest. A Git-only clone needs those same bytes at the listed paths. A clean-machine restore needs access to the pinned companion files, the lockfile-matched R library, a SHA-256 implementation, LibreOffice for BEA conversion, and Python 3 and TeX for the paper. Supplying and testing the independent deposit is [R18](refactoring_roadmap.md#r18-verify-the-independent-replication-deposit).

## Regression gates

### A. Documentation only

- Run `git diff --check HEAD`. Verify changed internal links, file paths, names and project metadata against tracked sources. Execute changed commands in an isolated output or build directory. For a changed manuscript or exhibit build example, run the relevant [build block](../../REPLICATION.md#exhibit-only-reproduction-and-latex-builds). For changed lint configuration or a referenced publication path, run `Rscript --vanilla -e 'testthat::test_dir("tests/testthat", filter = "^manuscript-exhibits$")'`.
- A full empirical replay is unnecessary when executable production code, inputs and settings are the same. If checking analytical integrity, run the raw and frozen hash commands above. Any observed raw, CSV/RDS or generated TeX byte change lies outside a documentation-only change. Use the PDF comparison below if a document is built. Broken references, failing documented commands, unexpected warnings from the relevant tests, and changed frozen artefacts block the commit.

### B. Behaviour-preserving code refactoring

- Run the relevant suites with `Rscript --vanilla -e 'testthat::test_dir("tests/testthat", filter = "<affected suite>")'` using the test file stem without `test-`, then the complete suite with `Rscript --vanilla tests/testthat.R`. Test affected functions, call sites, data contracts and source safety. Exercise changed production code in a fresh output tree and run the golden verifier and complete suite against that tree. A full replay with `Rscript --vanilla run_all.R --output-root="$replay"` is mandatory for changes to analytical stages, their dependencies, cache handling or orchestration that can affect downstream outputs. For an exhibit-only change over unchanged analytical inputs, verify those inputs and regenerate the affected exhibits separately. Bypass any cache that can hide a changed calculation.
- Exact hashes are the gate for pinned raw/manual inputs and frozen CSV/RDS on the pinned environment, including the underlying path set. Generated TeX, including aliases and bibliography projection where relevant, must match byte-for-byte. For a deliberate format, ordering or runtime comparison, retain the exact frozen export and compare the new projection by key, schema, units, types, coverage and missingness before checking numbers. Use only a tolerance justified by observed round-off or a named existing contract. Examples are `1e-7` in fractions for the 08a nonlinear fit replay from rounded CSV inputs and US$0.001 absolute for the sparse country-year-scenario comparison. These thresholds apply to their named checks. PDF comparison follows the rule below.
- Treat a changed digest as evidence of a byte change. Locate the first divergent output and account for the entire difference. An unexplained hash or path mismatch, out-of-tolerance value, key or schema drift, hidden cache hit, unexplained publication difference, failing assertion or unexpected warning blocks a parity commit.

### C. Scientific specification changes

[R04b](r04b_budget_benchmarking.md) provides a worked example of an additive scientific reference. The default verifier includes its new scenario-range diagnostic, and the `r04` selector checks the exact historical output inventory.

[R05a](r05a_utpr_shadow_results.md#reproduction) applies the standalone-diagnostic gate. Two fresh shadow executions match each other, the LEGACY arm reconciles to frozen routing and game outputs, and the 361-file production reference remains byte-identical.

- Verify the original reference with the raw and golden hash commands above and run its tracked suite at the baseline revision. Run the old and new specifications in separate isolated output roots for any change to the production specification. A retained old replay can serve as the comparison if its revision, input hashes, code path and cache provenance are established. A standalone scientific diagnostic can exercise its affected path in isolation if it leaves the production specification intact. Run the full suite for each affected specification and build affected exhibits and the paper from the corresponding outputs.
- Compare both specifications using matched keys and report changes in population, support and scenario coverage separately from changed values. Quantify effects by affected scenario, jurisdiction, time window and headline result. Preserve exact bytes for pinned inputs within each vintage, the old freeze and outputs outside the intended change set. Once a new freeze is authorised, verify its own exact CSV/RDS path set and hashes and the TeX against that specification's reference. Numerical tolerances address reproducibility and calculation precision within each specification. Size and interpretation of scientific differences are assessed separately.
- Changed hashes identify outputs to reconcile against the specification change. Keep old manifests and record any proposed new freeze separately. Unexplained differences, missing baseline or missing checks of the changed mechanism, failures of common identities, unjustified changes to support or schema, mismatched manuscript claims and unexpected warnings block the commit.

**PDFs.** Compare figure PDFs after accounting for identified generation timestamps. Whole-document builds can also differ in trailer IDs and cross-reference offsets. Compare PDF content after normalising known volatile metadata where feasible. If byte differences remain across TeX stacks, verify page count, rendered pages and the relevant text, tables, captions and axes. Keep exact generated TeX checks even when PDFs need content comparison.

## R01. Original audit record

15 November 2026. Clean starting checkout `publication-rework` at `16dc40da94e9a04894ae299fa62bd2c37500ad05`, equal to its configured upstream at inspection. The audit replay used a newly created output tree under the system temporary directory, with raw inputs and archived fixtures read from the checkout. The paper and note built from temporary copies.

### Environment and execution

- R 4.6.0, arm64 macOS 27.2.1, default R BLAS/LAPACK, `LC_ALL=en_US.UTF-8` and Europe/Amsterdam time. LibreOfficeDev 26.8.0.0.alpha0 converted BEA workbooks. Python 3.14.6 regenerated the selected bibliography. TeX Live 2026 used pdfTeX 1.40.29, BibTeX and latexmk 4.88.
- The first vanilla replay stopped in 01 with missing `tibble` under the default R library. The initial default R environment lacked the project `renv` installation as well. An existing local library from a prior project run matched all 68 package versions in [`renv.lock`](../../renv.lock) when considered with R's library. It was set through `R_LIBS_USER` for the successful replay and the tests. No dependency installation was needed. This verifies the supplied dependencies on the local host. A fresh restoration on an independent machine remains open.
- Sum of runner stage wall times was **464.9 seconds** (7 min 45 s), including 189.3 s in 11, 67.6 s in 08, 43.2 s in 10, 36.1 s in 09, 30.9 s in 05, 25.2 s in 01 and 4.7 s in 13. The output tree used about 227 MiB. Peak resident memory was unavailable under the process-inspection restrictions. A previous full Stage 1 simulation took roughly 40 minutes according to [REPLICATION.md](../../REPLICATION.md#pipeline-architecture).
- 07a reused 13 frozen Stage 1 measurement-error files after checking their exact hashes and those of nine freshly computed analytical inputs. Its profit-correction draws ran. Stage 11 ran all 500 joint draws, expanded factorial and 27 jurisdiction leave-out cases. The 13 reused files have exact cached artefact parity. Computing the legacy 500-draw Stage 1 simulation from scratch was outside this replay. No cache was introduced by R01.

### Commands and results

The commands below run from the root unless a writing directory is indicated. Use an absolute fresh `audit_output` and a lockfile-matched `R_LIBS_USER` as described above. The TeX steps run on copies of the relevant master bibliography, note and paper sources, hand-authored figure and generated tree, with the repository's `.latexmkrc`.

| Check | Command or method | R01 result |
|---|---|---|
| Raw/manual SHA-256 | `shasum -a 256 -c tests/step17_raw_inputs.sha256` | 54/54 verified. Four ignored extracts were present. |
| Original frozen set | `Rscript --vanilla tests/verify_golden_step15.R` | Exact path set and 360/360 SHA-256 hashes. A separate probe ran `sha256_files(paths, backend = "system")` on all 360 original outputs and checked CSV/RDS manifest digest agreement. |
| Syntax and source safety | Parsed all 18 R modules in `code/` and ran the existing source-safety test as part of the suite. | All 18 parsed. Sources are safe under the existing isolated-environment probe. |
| Original suite | `Rscript --vanilla tests/testthat.R` | 695 passing expectations, one failure and one warning, no skips, 44.3 s. |
| Isolated production replay | `Rscript --vanilla run_all.R --output-root="$audit_output"` | All 15 stages completed. The Stage 11 sparse-to-production max country-year gap was US$0.00002289, below its US$0.001 threshold. Stage 10's baseline replay max difference was US$0.00000381. |
| Replay frozen set | `Rscript --vanilla tests/verify_golden_step15.R "$audit_output"` | Exact path set and 360/360 SHA-256 hashes. |
| Suite against replay | `GMT_TEST_OUTPUT_ROOT="$audit_output" Rscript --vanilla tests/testthat.R` | 695 passing expectations, same one failure and warning, no skips, 41.1 s. The manuscript test's exhibit-only rerun using its absent-raw fallback compared every included generated table byte-for-byte. |
| Memo filename confirmation | Repeat replay suite from a temporary copy of the tests with one memo filename corrected. Use checkout sources and replay data. | 696 passing expectations, zero failures, warnings or skips, 39.1 s. Establishes the cause without editing the tracked suite. |
| Full generated directory comparison | Compare replay and tracked path sets, bytes for `.tex`, and PDF bytes after replacing only creation/modification dates. | All 88 paths match, 80 TeX files byte-identical, eight PDFs differ only in timestamps. Includes the standalone stage 07 TeX and compatibility fragments. |
| Paper bibliography and builds | From temp writing directories, `python3 make_paper_bib.py` and `latexmk -pdf -interaction=nonstopmode -halt-on-error paper_v2.tex`. Test both checkout and replay exhibits. | Exact selected bibliography. Both builds are 75 pages. Checkout-exhibit build is byte-equal after normalising dates and trailer IDs. Replay-exhibit build matches the checked-in PDF in all 160 top-level PDF objects after decoding Flate streams and ignoring date fields (including embedded figure dictionaries), compressed lengths and cross-reference offsets/trailer ID. Final log has an underfull box, with no unresolved citations or references. |
| Renamed note build | From temp writing directory, `latexmk -pdf -interaction=nonstopmode -halt-on-error 'Research note and publication plan GMT revenue decomposition.tex'` | Five pages after BibTeX and reference passes. |
| Final integrity | Recheck docs, staged paths, original analytical hashes and Git status. | R01 deliverables are documentation and root guidance. No analysis, test, manuscript or frozen artefact edits. |

**Original failure and guide drift.** At the R01 revision the lint referenced `writing/supervisor_pitch_memo.tex`, and the guide used the old build target and a four-page description. The temporary filename correction established the cause of both the error and warning.

### Frozen references and scope

The verifier reads the [Step 15 RDS manifest](../../tests/golden_step15_manifest.rds) and [Step 17 addition](../../tests/golden_step17_additions.csv), and rejects any missing, extra or changed CSV/RDS under `data/processed/`. The combined set is **359 Step 15 + one Step 17**, with 127 RDS and 233 CSV files (232,790,638 bytes on this checkout). Outputs span cleaning, model fits, intermediate tables, main estimates, extensions, uncertainty and vintage scorecard. The [human-readable Step 15 manifest](../../tests/golden_step15_manifest.csv) preserves per-path digest and inferred object/column summaries. Those summaries do not define the byte verifier's pass criteria. Archived outputs, the optional 08a audit CSV, bibliography and manuscript files lie outside that verifier. The 08a sensitivity is separately replayed by its existing test, which checks its output against the committed diagnostic within `1e-6` and guards input files.

| Reference file | SHA-256 |
|---|---|
| `tests/step17_raw_inputs.sha256` | `4b4cf0a5b7805b3d5b1fa6953ba19d313dd5ed491bb074100dc27bda28b4e389` |
| `tests/golden_step15_manifest.csv` | `b411fca5acccf549131f5b903a19529317bee17b6c9bb5e4d46532741af0de5b` |
| `tests/golden_step15_manifest.rds` | `e673e3781d86c63bcaea4531ade03fca9900ae2c6b48e393b586d016dbf86690` |
| `tests/golden_step17_additions.csv` | `9448e2ef2878768c8918731f53cc0e310cc916167d47a452311c0db80105ceb9` |
| `data/processed/base_panel.rds` | `1feeaa1516c25132ab2f86a0dcb866834fed4a16a5e8546e8ecec80ee2a84667` |
| `data/processed/diagnostics/step3_stage1_pooled_t4_completeness_sensitivity.csv` | `b1df702449d89706b56488eec69220c4307bdab47caaff2d7ee3bd0a38d3bd65` |

The 78 test blocks cover source-safety, SHA-256 backends, manuscript dependencies, ETR/measurement, substance, behavioural estimation and response, routing, factorials, key/cardinality and archive regression, seed/uncertainty invariants, extension coverage, notch, influence and the optional cap comparison. They give partial direct coverage of the scientific primitives with strong output characterisation. In particular, intermediate joins in 02, loss-stock and correction overlap in 10, sparse/detailed behaviour away from production support and the joint Monte Carlo draw/attribution law need dedicated fixtures before moving those seams. R 4.3–4.5 portability of the verifier is code-supported and was not exercised here. The test path for system hashes ran on R 4.6.0. Production replay relies on the restored lockfile environment and does not establish portability to older runtimes.

The archived ILO fallback and the exhibit-only Table I metadata fallback do not establish a Git-only clean analytical replay. See the [companion input status](#four-companion-inputs).

### Manuscript correspondence

The checked-in paper builds directly from the reproduced tables and figures. That connects current publication inputs to the exact empirical artefacts. TeX contains narrative values and legal claims written by hand, so builds and hashes do not independently validate every sentence. The [scientific issue register](scientific_issue_register.md) identifies known discrepancies and the controlled work needed for them. Important comparison units are source versus collector, cumulative USD versus annualised EUR, and model comparator versus observed receipts or statutory obligation.
