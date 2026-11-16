# GMT project status

The leading scientific reference is **R06b**, established at `b0056d8289eee6277865f3405758f6a9b469cd9e` and defined by [the 364-file processed manifest](../../tests/golden_r06b.csv). Economic observations are FY2017–2023. `VERIFIED_PARENT_ONLY` applies the independently verified 2026 UTPR recipient map and parent-year activity weights, reporting unsupported UTPR separately. `NO_NOTCH_STANDARD_RESPONSE` applies the continuous response below the minimum rate and the retained modelled Side-by-Side exemption. [R06b scientific specification](r06b_continuous_behavioural_response.md) · [R05b collector specification](r05b_utpr_production.md).

The reference uses observed adjusted profit where available, a fitted domestic reconciliation elsewhere, the existing pooled and bilateral Table IV/Table I hierarchy and BSPI transport, the 15% floor, existing SBIE/SBTI rules and the accrual/cash/loss-stock/safe-harbour accounting bridge. Statutory roles still use the R06b legacy rate inputs. The latest complete production replay was R08 at `50b6848175b8d95fce607a0eb10bd30668ce14a4`. It matched 364 processed files, 81 TeX exhibits, eight figures and both publication PDFs. [R08 gate](refactoring_roadmap.md#r08-extract-the-constrained-beta-kernel) · [Acceptance rules](baseline_verification.md).

| Iteration | Type | Main result and hand-off | Scientific production change and freeze |
|---|---|---|---|
| R01 | Architecture audit | Mapped stages, provenance, reproducibility risks and issue register. | None |
| R02 | Verification | Restored the acceptance gate and documented reproducible builds. | None |
| R03 | Refactor | Extracted the budget and accounting-waterfall publication family. | None |
| R04 | Refactor | Characterised detailed, sparse and collapsed collection and shared validated routing. | None |
| R04b | Scientific correction | Matched national budget forecasts to their policy scope and expanded the unrestricted comparison to the full core. | Revised budget outputs and reference |
| R05a | Diagnostic | Verified eligibility evidence and shadowed alternative UTPR recipient maps. | None |
| R05b | Scientific correction | Adopted verified national recipients and parent-year-only support with explicit unassigned liability. Group-level exclusions remain open. | R05b freeze |
| R06a | Diagnostic | Documented the stylised behavioural notch and the separate safe-harbour mechanisms. | None |
| R06b | Scientific correction | Replaced the notch with the continuous specification and propagated it through allocation and uncertainty. | Current R06b freeze |
| R07 | Refactor | Validated the bilateral spine and the cardinality of prepared joins and reconciliation attachment. | None |
| R08 | Refactor | Extracted the constrained-Beta kernel and made the audit quantile strategy explicit. Broader measurement orchestration is open. | None |

**R09a** audits statutory rate definitions by use, with isolated comparisons for mean clipping, percentile caps, reconciliation, the statutory instrument and ordinary CIT recovery. The two isolated runs match all 17 diagnostic files. The R06b hashes and the Stage 08a diagnostic match, and the full suite passes 1,422 expectations. The combined-first conditional candidate is ready for R09b review. [Technical audit and decision memorandum](r09a_statutory_rate_audit.md) · [Rate dependency inventory](r09a/dependency_inventory.csv).

**Sequence.** R09b implements the selected rate policy. R10 resolves Table IV completeness and suppression. R11 covers substance and SBTI, R12 econometric estimation and behaviour, R13 scenario and liability contracts, R14 the accounting bridge, R15 fiscal diagnostics, R16 uncertainty and cache validity, R17 publication adapters and R18 the replication deposit. Separate diagnostic and implementation phases remain available for material scientific decisions. [Roadmap](refactoring_roadmap.md).

**Issues.** S01 rate definitions stay open pending the implementation decision. S02 suppressed Table IV tax and S10 inconsistent point anchors/ranks remain open. S03 recipient mapping and S04 residual accounting were addressed for the leading model, with group-level legal implementation and comparison contracts still bounded by observable support. S05's stylised notch was removed from the leading regime. S06 SBTI capacity, S07 accounting overlaps and S08 simulation dependence/cache provenance are open. S09's full-core budget range was corrected in R04b. [Issue register](scientific_issue_register.md).

**Replication deposit.** A Git-only restore still needs the exact ILO monthly earnings, CbCR Tables I and III, and OECD CIT-revenue/GDP companion extracts. The current workspace supplied and validated them. Independent replication also requires the R lockfile and documented system tools, redistribution or persistent access arrangements for the pinned bytes, and a clean-machine restore. [Companion paths and provenance](../../REPLICATION.md#data-availability-and-provenance).
