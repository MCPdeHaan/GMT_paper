# GMT project status

The leading reference is **R09b**, [versioned by the processed manifest](../../tests/golden_r09b.csv). The reference uses `STANDARD_ROLE_SPECIFIC`, `VERIFIED_PARENT_ONLY` UTPR and `NO_NOTCH_STANDARD_RESPONSE` behaviour. Economic observations are FY2017–2023. The statutory model distinguishes the combined-first statistical cap and destination price, the combined-only statutory instrument, and the historical reconciliation and gate covariates. [Rate specification, results and replay](r09b_statutory_rate_revision.md).

The model uses observed adjusted profit where available, estimated domestic reconciliation, the existing Table IV/Table I hierarchy and BSPI transport, the 15% floor, SBIE/SBTI rules and the accrual/cash/loss-stock/safe-harbour bridge. The independently verified UTPR map applies to fiscal years beginning on 1 January 2026 and uses observed parent-year collector activity. Liability without route support is reported separately. R06b remains the historical reproducibility reference. [R06b manifest](../../tests/golden_r06b.csv) · [R05b collector specification](r05b_utpr_production.md).

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
| R06b | Scientific correction | Replaced the notch with the continuous specification and propagated it through allocation and uncertainty. | Historical R06b freeze |
| R07 | Refactor | Validated the bilateral spine and the cardinality of prepared joins and reconciliation attachment. | None |
| R08 | Refactor | Extracted the constrained-Beta kernel and made the audit quantile strategy explicit. Broader measurement orchestration is open. | None |

| R09a | Diagnostic | Investigated statutory rate definitions and conditional changes by role. | None |
| R09b | Scientific correction | Separated measurement, IV, reconciliation, eligibility and marginal-price rate roles. Recalculated downstream analyses. | R09b freeze |
| R10a | Diagnostic | Recovered published Table IV status at component grain, reproduced the historical screen and compared contemporaneous direct and BSPI-anchor rules through collector receipts. | None |

The prior holdout supports retaining the historical reconciliation covariate. Preferred top-up receipts barely move, whereas the marginal-rate proxy materially raises modelled gross destination ordinary CIT. The revised statutory IV is weak and its imprecise point estimate is positive. [R09a audit](r09a_statutory_rate_audit.md) · [R09b evidence and decisions](r09b_statutory_rate_revision.md).

**Sequence.** The [R10a decision memorandum](r10a_table_iv_observability.md) informs R10b, which will decide and propagate the Table IV support rule. R11 covers substance and SBTI, R12 econometric estimation and behaviour, R13 scenario and liability contracts, R14 the accounting bridge, R15 fiscal diagnostics, R16 uncertainty and cache validity, R17 publication adapters and R18 the replication deposit. Separate diagnostic and implementation phases remain available for material scientific decisions. [Roadmap](refactoring_roadmap.md).

**Issues.** S01 is addressed for the statistical cap, the statutory IV and the destination price. The declared reconciliation and gate proxies retain their empirical limitations. S02 suppressed Table IV tax and S10 inconsistent point anchors/ranks remain open. S03 recipient mapping and S04 residual accounting were addressed for the leading model, with group-level legal implementation and comparison contracts still bounded by observable support. S05's stylised notch was removed from the leading regime. S06 SBTI capacity, S07 accounting overlaps and S08 simulation dependence/cache provenance are open. S09's full-core budget range was corrected in R04b. [Issue register](scientific_issue_register.md).

**Replication deposit.** A Git-only restore still needs the exact ILO monthly earnings, CbCR Tables I and III, and OECD CIT-revenue/GDP companion extracts. The current workspace supplied and validated them. Independent replication also requires the R lockfile and documented system tools, redistribution or persistent access arrangements for the pinned bytes, and a clean-machine restore. [Companion paths and provenance](../../REPLICATION.md#data-availability-and-provenance).
