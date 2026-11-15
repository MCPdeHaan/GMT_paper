# Incremental refactoring roadmap

R01 establishes the [architecture](../architecture/current_architecture.md), [baseline](baseline_verification.md) and [scientific issue register](scientific_issue_register.md). The 17 iterations below are review boundaries. A parity change uses the existing specification and reference outputs. A scientific revision has a named comparison arm, an evidence-based specification decision and a separate change set. The order prioritises executable checks, one publication boundary and the routing dependency used by several scientific revisions. Independent owners can review later slices in parallel once their input contracts are stable.

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

### R05. Audit and revise legal collector eligibility

- **Depends on:** R04. **Files:** 05/06 flags and allocation, affected 07a/09/10/11 studies, tests and paper §§2.1/6.1/6.3 and Appendix E.
- **Change and benefit:** Resolve S03 with a dated national/qualification evidence table and provenance for unknowns. Measure the effects of the IIR→UTPR inference, member deferrals and fallback pooling. Determine whether a documented proxy, source-based eligibility, or bounded scenarios best support the claim. Keep R1, R2 and R3 restrictions explicit.
- **Risk, tests and completion:** Source/collector country switches, effective dates, repeal and unsupported mass can change receipts markedly while global conservation holds. Test verified rule dates and classes, qualification versus enactment, authority of ambiguous cases, route eligibility, channel and country totals, repeal spillovers and decomposition. Publish scope/delta tables and revised legal exposition; if the adopted specification changes results, create a separate freeze after review.

### R06. Separate behavioural bunching and legal safe harbours

- **Depends on:** R04; use R05's agreed routing specification if available. **Files:** 05, 09 notch, 10 screens, 11 fast/policy evaluator, Stage 3 tests and paper §§2/4.4/5, Appendices C–E.
- **Change and benefit:** Resolve S05 by distinguishing pre-reform support, stylised responses and OECD eligibility. Reuse the notch and transitional diagnostics. Propagate an explicitly bounded response through all engines and identify who would otherwise collect.
- **Risk, tests and completion:** Threshold inclusivity and QDMTT/SbS interactions can differ across engines. Compare no-band and defended sensitivity with frozen benchmark across cases; test 13%/15% boundaries, sparse parity, and safe-harbour treatment and exposure by rule. Revise interpretation, figures and tables where affected, and version a new freeze if chosen.

### R07. Extract the bilateral panel assembly

- **Depends on:** R02. **Files:** 01/02/02a and panel contract tests.
- **Change and benefit:** Extract a spine-and-merge slice before wage and sector sidecars. Introduce canonical keys, join cardinalities, separate panel and sidecar data contracts, and a check at the reconciliation merge. Keep the existing writer and preserve the legacy panel schema.
- **Risk, tests and completion:** Codes, duplicated or lost cells, source panels and profit adjustments. Check the ordered 20,111-row output with all 403 columns, keys and sidecar bytes, Table IV missingness, wage source/same-year tags and parent-year evidence balances. Extract remaining sector-sidecar glue only against those fixtures.

### R08. Decompose the ETR measurement stage

- **Depends on:** R07. **Files:** 03 and 08/08a fit callers, Stage 1 and cap tests.
- **Change and benefit:** Separate pooled direct, BSPI, constrained/rank Beta, bilateral selection and validation while retaining existing priorities. Pass quantile strategy explicitly to free the alternate-fit closure from its environment workaround. Establish measurements with explicit support and rate metadata.
- **Risk, tests and completion:** Numerical tails, fallback order, overlaps, transported support and common-validation intersections. Require exact frozen outputs, established CV samples, numeric boundary cases and unchanged pooled and strict L4 support. The cap diagnostic reproduces to its existing tolerance.

### R09. Revise statutory-rate inputs under named estimands

- **Depends on:** R07–R08. **Files:** 01/02/02a/03/05/08a/09/10/11, tests and paper §§3–6 as affected and Appendices A–C.
- **Change and benefit:** Resolve S01. Reuse the conditional 08a result and compare separately the impact on upstream clipping, reconciliation, sample/estimation, source liability and collectors. Declare standard combined, standard central and targeted series with explicit missing policy. Assign a rate definition to each use.
- **Risk, tests and completion:** Revised denominators change measured support, behavioural regressors, legal allocations and ordinary CIT. Check rate unit/series/coverage, exact frozen comparator, matching CV, low-tax/profit shares and regression/scenario/receipt deltas. Report headline and variance results with changed cells, both channels and countries. Revise manuscript and version the selected empirical freeze if changed.

### R10. Resolve pooled Table IV suppression and eligibility

- **Depends on:** R08, use R09 rate definitions for the selected model or explicitly run against the old specification. **Files:** 02/03 and 08/10/11 where branch membership travels, support tests, §§4.1–4.2/5 and Appendix B.
- **Change and benefit:** Fix the missing-versus-observed-zero path. Reuse the existing pooled completeness exercise for the broader numeric low/upper and BSPI screen. Make flags and candidate treatment of partial observability explicit.
- **Risk, tests and completion:** Stage 1 fallback and BSPI shape changes can affect the full design. Test absent, suppressed, observed-zero and partially observed bracket cases at both grains; recompute CV and all downstream impacts of the selected source rule. Report stage-specific deltas and update tables/text and freeze if needed.

### R11. Separate substance methods and incentive capacity

- **Depends on:** R07–R08. **Files:** 04 and paired 08/09/11 substance callers, Stage 2 tests and paper §4.3, §§5/6 and Appendices B/E.
- **Change and benefit:** Extract activity allocations, aggregate and sectoral SBIE, capacity and H5 diagnostics as separate operations. First secure parity. Then review S06 separately, tracing aggregation, eligibility and covered-tax add-back versus the current capacity overlay with the existing stress/repeal results.
- **Risk, tests and completion:** Transition years, missing payroll/assets, caps at zero profit, sector aggregation, attribution of bundled factor. Test conservation of sector components, SBIE endpoints, reversion to aggregate and distinct capability/use definitions. Finish parity with exact outputs; if legal/economic choices change the specification, quantify source/collector shifts and update the paper, tests and freeze in the science change.

### R12. Separate estimation, behavioural response and destinations

- **Depends on:** R04, R06, R08 and R11's relevant contracts. **Files:** 05, 09/10/11 econometric/reallocation callers and Stage 3 tests.
- **Change and benefit:** Move sample construction and FE/IV fits, inference and schedule construction, and stage-level evaluation into distinct modules. Return aligned modelling keys and parameters. Move Rule A/B/C destinations to fiscal methods. This makes alternative estimators and relocation choices explicit inputs.
- **Risk, tests and completion:** Clustering, covariance repairs, key alignment, bare serialized fit calls, elasticity signs, selected coefficient/substance bridge. Check coefficient/SE/matched sample, J/Wald, division-bias and response fixtures; preserve fits and stage/liability/recovery outputs by hash or reviewed projection with unchanged estimands.

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

Execute R05. Build a dated evidence table for UTPR eligibility with separate provenance for enactment, effective date, qualification and proxy. Compare it with the frozen map before deciding how to account for unsupported pools in each law and opt-out arm.
