# Incremental refactoring roadmap

R01 establishes the [architecture](../architecture/current_architecture.md), [baseline](baseline_verification.md) and [scientific issue register](scientific_issue_register.md). The iterations below are review boundaries. A parity change uses the existing specification and reference outputs. A scientific revision has a named comparison arm, an evidence-based specification decision and a separate change set. The order prioritises executable checks, one publication boundary and the routing dependency used by several scientific revisions. Independent owners can review later slices in parallel once their input contracts are stable.

## Verification rules

For each parity slice, run the relevant method and source-safety tests, check the affected path set and bytes on the pinned host, and compare the meaningful keyed intermediates (including NA versus zero). For file format or row order changes agreed in advance, retain the old export for a byte check and compare the new projection by declared keys, types, missingness and a pre-specified numerical tolerance. Normalise only documented volatile PDF fields. When a cache could hide a changed computation, run the changed calculation or force a cache miss. Use fresh output directories.

For each science slice, state the observed data, proxy and alternative, the estimand, the affected baseline and the expected mechanism of change. Report before/after by scenario, country and window, including effects on publication headlines, with a dedicated specification/test/manuscript commit. Keep existing references identifiable even when results legitimately change. Change frozen hashes only in an independently versioned freeze after those comparisons. A provenance or exposition correction may close without a changed empirical specification when the proxy is explicit and judged fit for the stated estimand.

## Sequence

### R02. Make baseline verification green

- **Depends on:** R01. **Files:** `test-manuscript-exhibits.R`, README and the manuscript build section of REPLICATION.
- **Change and benefit:** Point the memo punctuation check and build commands to the tracked renamed source, add file-existence context to the lint, and provide an exact replay-and-build command using the current paths. This establishes an executable acceptance gate. Keep this change confined to validation and instructions.
- **Risk, tests and completion:** The rename must preserve coverage of both paper and memo. Run the full original suite against checkout and replay inputs with the corrected test, verify all 360 outputs, and compile paper and memo in temp. Both suites pass, and the guide's documented commands execute on the pinned host without any tracked artefact changes.

### R03. Extract one exhibit family

- **Depends on:** R02. **Files:** Stage 13, `code/publication/budget_waterfall.R` and the targeted, manuscript and source-safety suites.
- **Delivered:** The [budget and waterfall module](../architecture/current_architecture.md#r03-budget-and-accounting-waterfall-exhibits) separates input checks, reusable data selections and presentation. Stage 13 passes the existing reader, formatter, writer and output path, and saves the figure and numbered alias. The historical scenario-range label is tracked separately as [S09](scientific_issue_register.md#s09-table-6s-scenario-range-is-conditional-on-l3).
- **Verified:** 746 expectations passed on both the checkout and isolated replay, with no warnings or skips. The replay matched 360 frozen outputs and 80 TeX files, including the independent Stage 07 overview. All eight figure PDFs matched after date normalisation, and the paper built with the existing table and figure references.

### R04. Characterise dense, sparse and collapsed routing

- **Depends on:** R02. **Files:** `code/allocation/collector_routes.R`, 06, 07a, 09, 11 and the collector routing fixtures.
- **Delivered:** The [routing contract](../architecture/current_architecture.md#r04-collector-routing-contract) defines validation and parent-first route selection. Detailed and sparse expansion share an implementation. The two collapsed projections preserve their own estimands and use the shared validator. Positive unsupported pools fail before being reported as allocated or exported, and zero EU share preserves parent-year routing. [S04](scientific_issue_register.md#s04-legacy-and-sparse-revenue-calculators) records earlier discrepancies and the implications for R05.
- **Verified:** Hand-worked fixtures reconcile the detailed, domestic, EU and non-EU projections and distinguish unsupported residuals. The 15-stage replay recomputed all 500 Stage 07a measurement-error draws from an empty cache. All 360 frozen output hashes and 80 TeX files matched. The eight figures matched after date normalisation, and both publication PDFs built with their existing content.

### R04b. Correct national budget benchmarking scope

- **Depends on:** R03 and R04. **Delivered:** Stage 08 verifies the L1/L3 partition and publishes channel-matched core, conditional L3 and documented-policy comparisons. Table 6 and Appendix D show their different scenario supports. Section 5.3 uses national budget benchmarking on historical bases. The waterfall and Figure 3 retain their numerical inputs.
- **Verified:** Independent factorial, interval, channel, window and tie fixtures. The [country comparison and reproducibility record](r04b_budget_benchmarking.md) documents the revised interpretation and additive reference. [S09](scientific_issue_register.md#s09-table-6s-scenario-range-is-conditional-on-l3) records the historical error and remaining comparability limits.

### R05a. Establish UTPR evidence and shadow the collector map

- **Depends on:** R04 and R04b. **Delivered:** The [dated national-rule register and method](r05a_utpr_legal_basis.md) and [shadow results and decision memorandum](r05a_utpr_shadow_results.md). The 1 January 2026 map separates national applicability, Article 50 and OECD qualification. The shadow holds each R1 and R3 source panel fixed while checking collector incidence, fallback and two opt-out cases. The R04b production reference is intact.

### R05b. Adopt verified collectors and parent-year routing

- **Depends on:** R05a. **Delivered:** The leading specification uses national UTPR applicability for a fiscal year starting 1 January 2026 and parent-year activity. The dated map and explicit unsupported residual propagate across Stages 06–13. R1, R2 and R3 retain their source and parent predicates. The eligible set and the support assumption have separate sensitivity arms.
- **Verification and remaining questions:** The [R05b scientific revision](r05b_utpr_production.md) records the full replay, comparison, game and new versioned freeze. The law-specific questions that require group data or separate policy changes remain in S03, S05 and S08.

### R06a. Characterise the behavioural notch

- **Depends on:** R05b. The [legal audit](r06a_safe_harbour_legal_audit.md), [decision memorandum](r06a_behavioural_notch.md) and independent fixtures separate the historical band from legal eligibility and trace its effects through the full core and accounting designs under verified routing. Selected Stage 07a draws and the unilateral deviations are also evaluated. The R05b specification remains the production reference.

### R06b. Decide and propagate the behavioural specification

- **Depends on:** R06a. The [scientific revision](r06b_continuous_behavioural_response.md) adopts the continuous response with the existing legal flags and coefficient. It records source and collector accounting, the full simulations, benchmark and unilateral results, and both exact manifests. The stylised band remains available under `BASELINE_NOTCH`.

### R07. Extract the bilateral panel assembly

- **Depends on:** R06b. Stage 02 now uses the [bilateral assembly module](../../code/panel/bilateral_assembly.R) for the Table I spine, Table II–VI projections and checked attachments of prepared supplementary and reconciliation lookups. Stage 01, Stage 02a, wage selection, profit calculations, sidecars and output adapters retain their responsibilities. [Grains and join contracts](../architecture/current_architecture.md#r07-bilateral-panel-assembly).
- **Characterisation:** [Panel contract tests](../../tests/testthat/test-bilateral-assembly.R) cover key order, duplicate rejection, missing versus zero inputs, uncapped Table IV projection, wage precedence and adjusted-profit outcomes. The pre-calculation join boundary matches the original 20,111 × 329 object exactly. The 20,111 × 403 panel and all 29 Stage 02 sidecars and diagnostics match the reference bytes.
- **Replay:** The [R06b parity gates](baseline_verification.md#b-behaviour-preserving-code-refactoring) verify all 54 original inputs, the legal register and the exact 364-file processed inventory. The fresh 15-stage replay took 2,009 seconds and reran 500 measurement-error draws without a cache hit, 500 profit-correction draws and 500 joint draws. All 81 generated TeX files match by bytes, the eight figures match after PDF timestamp normalisation, and the rebuilt 76-page paper and five-page note match page text, content streams, images and fonts.
- **Test results:** 334 targeted expectations and 1,184 full-suite expectations on each of the checkout and replay, with zero failures, warnings or skips.
- **Publication follow-up complete:** A separate editorial change after R10b corrected the [Side-by-Side citation](../../writing/paper_v2.tex#L120) that printed a literal token on page 4 and rebuilt the paper.

### R08. Extract the constrained-Beta kernel

- **Depends on:** R07. [The numerical module](../../code/measurement/beta_fit.R) owns the mean-anchored fit, its two optimiser paths and its Beta primitives. Stage 08 passes its quantile strategy explicitly. [Caller inventory and support contracts](../architecture/current_architecture.md#r08-constrained-beta-numerical-kernel).
- **Characterisation:** Recorded R07 fixtures lock down the shapes, boundary flags, losses and quantiles for both mean-anchored paths and the alternatives. Independent checks exercise log-odds recovery, both optimiser paths, non-monotone rank feasibility, tail identities and sparse zero-hurdle support. Stage 03 reproduced all 17 files and retained the ordered 361/70/81 validation samples. All 29 Stage 08 outputs match. The 1,743-row Stage 08a diagnostic matches the tracked CSV by bytes, including its pre-existing frozen-fit tolerance check.
- **Replay and tests:** R 4.6.0 with all 68 lockfile versions matched. The fresh 15-stage run recomputed 500 measurement-error draws without a cache hit, 500 profit-correction draws and 500 joint draws. It verified the 54 pinned inputs, the legal register and all 364 R06b processed hashes and paths. All 81 TeX files matched exactly and eight figures matched after timestamp normalisation. The rebuilt 76-page paper and five-page note matched page contents, fonts, images and all rendered pages. The 925 targeted expectations and 1,369 full-suite expectations on each of the checkout and replay passed with zero failures, warnings or skips.
- **Deferred:** Stage 03 retains the rank methods, pooled and bilateral selectors, Table IV and BSPI support, validation, ladder orchestration and I/O. Separate those in later parity slices. The incompatibility of some point-mean anchors and observed ranks is recorded under [S10](scientific_issue_register.md#s10-boundary-mean-anchors-can-conflict-with-observed-rank-bounds).

### R09a. Diagnose statutory rates by use

- **Complete.** The [statutory audit and decision memorandum](r09a_statutory_rate_audit.md) distinguish mean clipping, percentile caps, the reconciliation prior, statutory robustness, ordinary CIT and a conditional joint shadow. All 17 audit outputs match between isolated runs. The existing 1,743-row Stage 08a audit and all 364 R06b hashes reproduce.
- **Decision.** Standard combined and standard central cover identical country-years in the pinned vintage. The combined-first candidate entered R09b for the statistical caps and as a candidate for the prior, with a labelled same-year central fallback and role-specific unsupported behaviour. Matched validation is mixed. The statutory IV is weaker and reverses its sign. Conditional L4 and ordinary-CIT amounts are more sensitive than the preferred core collector receipts. [Current project status](project_status.md).

### R09b. Implement the selected statutory rate definitions

- **Complete.** R09b established the 367-file statutory-role scientific freeze, retained as a historical reference. The isolated historical R06b replay remains reproducible under its own specification and manifest.
- **Dependency and scope.** R09a and R08. Stage 01/02/02a/03 for rate provenance and conditioning, Stages 05 and 09 for the instrument and fiscal roles, Stage 10 for accounting numerator variants, and the complete downstream analysis and publication.
- **Adopted roles.** Combined-first statistical conditioning with the five-point allowance; combined-only statutory IV; combined-first destination price. The prior holdout and gate/price split support retaining the historical prior and destination gate. The applied behavioural coefficient and legal allocation rules carry forward. [Paired sensitivity and verification](r09b_statutory_rate_revision.md).
- **Acceptance.** Reproduce R06b separately and verify the new replay, including 32 core designs, the 64-case accounting design, 432 policy deviations, all three seeded uncertainty studies and publication outputs. Preserve Table IV support for R10 and the distinction between statistical rate proxy and policy gates.

### R10a. Audit Table IV observability and BSPI

- **Complete.** The [standalone diagnostic and decision memorandum](r10a_table_iv_observability.md) recover raw status, compare pooled and bilateral support, separate direct and anchor sensitivities, check matched and accounting support, and propagate the principal arms through the R09b fiscal kernels. The production decision was deferred to R10b, with R09b as the comparator.

### R10b. Adopt and propagate a Table IV completeness rule

- **Complete.** [R10b](r10b_table_iv_support_revision.md) adopts the verified two-sided published-support rule for direct observations and BSPI anchors, separates the missing-measure-only comparison, and versions the new leading freeze. R09b and R06b remain historical references.
- **Depends on:** R10a and R09b. **Files:** 01/02/03 and 07a/08/10/11 where status, branch membership and ambiguity propagate, support tests, manuscript §§4.1–4.2/5 and Appendix B.
- **Change and benefit:** Carry the raw evidence into the pooled and bilateral eligibility decisions, apply the selected rule to contemporaneous direct estimates and eligible anchor years, and keep shape versus tax-numerator support explicit. Retain the R09b rate roles and the source hierarchies.
- **Risk, tests and completion:** Document and test the approved treatment of one-sided reports. Check exposure and calibration at fixed as well as natural support. Run isolated paired reproductions and re-evaluate the ladder, all scenario and accounting arms, game, benchmarks and seeded uncertainty. Report stage-specific deltas with harmonised manuscript exhibits and a separately versioned freeze.

### R11. Separate substance methods and incentive capacity

- **R11a parity refactor.** Extract the aggregate shield, component-specific sector allocation and SBTI dollar primitives, leaving the H5 regressions and writers in Stage 04. Preserve the transitions, missing and capped inputs, both factorial designs and the repeal game. [Fixture, keyed-comparison and replay record](r11a_substance_methods.md).
- **R11b diagnostic.** Study S06 separately by holding source support fixed and tracing sector aggregation, qualifying amounts and covered-tax add-back through the split-factor and repeal comparisons. Check where the available data bound the decision and where group-jurisdiction eligibility, depreciation and elections remain unidentified.
- **R11c decision stage.** If a separate specification decision warrants a change, quantify source and collector effects, then update tests, the paper and the scientific freeze as part of that revision.

### R12. Separate estimation, behavioural response and destinations

- **Depends on:** R04, R06, R08 and R11's relevant contracts. **Files:** 05, 09/10/11 econometric/reallocation callers and Stage 3 tests.
- **Change and benefit:** Move sample construction and FE/IV fits, inference and schedule construction, and stage-level evaluation into distinct modules. Return aligned modelling keys and parameters. Move Rule A/B/C destinations to fiscal methods. This makes alternative estimators and relocation choices explicit inputs.
- **Risk, tests and completion:** Clustering, covariance repairs, key alignment, bare serialized fit calls, elasticity signs, selected coefficient/substance bridge. Check coefficient/SE/matched sample, J/Wald, division-bias and response fixtures; preserve fits and stage/liability/recovery outputs by hash or reviewed projection with unchanged estimands.
- **Deferred from R10b/R11a.** Diagnose the Stage 08 EU27 L3 business-activity regression's covariance regularisation before interpreting its clustered inference. This model is separate from the Stage 04 H5 regressions. [Verification record](r10b_table_iv_support_revision.md#acceptance-record).

### R13. Define design, liability and contrast contracts

- **Depends on:** R04, R08, R11–R12. **Files:** 00, 05, 07, 08, 09 and 11 design and decomposition functions.
- **Change and benefit:** Centralise scenario identifiers/factor levels and one source amount kernel where equivalent. Pass the contrast basis and aggregation estimand explicitly; keep stage-proxy, pooled country-year, cumulative and ladder designs distinct. Move Stage 7 fiscal ratios and legacy TeX to their owners with compatibility adapters.
- **Risk, tests and completion:** Factor coding, zero cells, interactions and Jensen/aggregation differences. Test single-factor and interaction fixtures, heterogeneous country aggregation, 32/64-case support and multi-level contrasts. Preserve all publication-linked factorial and legacy outputs and check source-to-collector conservation.

### R14. Make the accounting bridge auditable by adjustment

- **Depends on:** R04, R08 and R13. **Files:** 02/10/11 bridge routines and tests, paper §§3.2/4.5/5, Appendices A/B/D if interpretation changes.
- **Change and benefit:** Resolve S07 with explicit denominator, shape, current and prior loss, numerator, screen and collection steps. Reuse existing waterfall before testing changes. Keep the additional foreign haircut traceable back to observed adjusted profit and the same keys the strict ladder uses.
- **Risk, tests and completion:** Double charge, sign and year chronology, overlap of losses and adjustments, discontinuous safe-harbour screens. Check stock and base identities with hand-worked fixtures and point parity of the accrued path where intended. Preserve existing step-wise and accounting-factorial outputs in the parity change. Document any new assumption, its measured impact and the relevant manuscript and freeze change separately.

### R15. Untangle measurement diagnostics and fiscal comparisons

- **Depends on:** R04, R08 and R12–R14. **Files:** 08/09/10/12, diagnostic and validation tests.
- **Change and benefit:** Move CbCR blending, size, interquartile and activity diagnostics by question and put benchmarks in one provenance-bearing input. Make the forecast metadata and comparison scopes explicit for ladder, ledger and bridge. Move 12 to narrow dependencies and preserve its historic archive interface.
- **Risk, tests and completion:** Match annualised versus cumulative amounts, exchange rates, receipt channels, period and source caveats. Require byte parity of diagnostic/scorecard artefacts, an unchanged set of benchmark matches, and exposed absence of a required input. Source graph ceases loading entire extensions for a benchmark or formatter.

### R16. Make uncertainty replay and attribution verifiable

- **Depends on:** R04, R08 and R12–R14. **Files:** 07a/11 simulation modules, test fixtures, REPLICATION, Appendix D and §5.2 if the model changes.
- **Change and benefit:** Make the three draw designs explicit, use validated routing, and key reuse on generator and input provenance. Provide a deliberate cache-miss route and report elapsed time and peak memory. Address S04/S08 sign and support checks and quantify MC error separately from the conditional parameter variance.
- **Risk, tests and completion:** RNG order, draw pairing, draw-dependent support, sparse performance, interval definitions and attribution estimand. Test keyed draws, known total-variance and interaction identities, point parity, cache invalidation, and production reproducibility with a full legacy cache miss and joint run. Characterise stability across draw counts/seeds. Changes to uncertainty assumptions or headline shares require a separate tested manuscript/specification revision.

### R17. Finish adapters and publication boundaries

- **Depends on:** R03 and R11–R16 for migrated domains. **Files:** 00/07/13, stage adapters, runner, exhibit and source-safety tests.
- **Change and benefit:** Finish appendix/final-figure extraction by exhibit family, move the stage 07 TeX export to the publication owner, and declare mandatory and legacy artefacts. Remove obsolete source edges only after ordinary CLI and scoped runs pass. Document stage contracts and optional acquisition.
- **Risk, tests and completion:** Conditional exhibits, aliases, source safety, relative paths and active readers. Require full exact TeX and normalised PDF checks, compiled paper, clean analytical replay and explicit missing-artifact errors. Keep each retained compatibility path keyed and covered. Measure remaining workflow latency and revisit a package or a `targets` pilot only if demonstrated needs remain.

### R18. Verify the independent replication deposit

- **Depends on:** R02–R17 or explicit documentation of any deferred science item. **Files:** release README/REPLICATION, input/deposit manifests, provenance and version record.
- **Change and benefit:** Deliver the pinned four companion extracts subject to redistribution review, and precisely identify allowed and required archived inputs. Reproduce from the intended deposit tree and exact dependency instructions in a clean environment. Release documentation can use the current exhibit and artefact index.
- **Risk, tests and completion:** Revision or omission of a provider file, stale release guidance, package/system version mismatch and legal restrictions on redistribution. Verify all raw and chosen frozen hashes, execute full tests and exhibit build, record timings and portability, document attribution and permissible retrieval where necessary, and report remaining scope/identification limits. An independent replicator can follow the deposit instructions without relying on an untracked file from this workstation.

## Recommended next task

For R11b, start from the R11a fixed-support audit. Quantify how sector aggregation, incentive qualification, alternative capacity legs and covered-tax add-back affect separately reported source and collector amounts. Keep the current R10b configuration and publication intact during the diagnostic.
