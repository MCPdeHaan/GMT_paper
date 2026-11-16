# R09a diagnostic definitions

These rules were set before inspecting the alternative outcomes. All fractions are annual and jurisdiction-specific. The historical observation year is the rate year. The lagged instrument uses the immediately preceding year. No carry-forward, nearest-year or cross-country rate imputation is used.

| Specification | Primary series | Fallback |
|---|---|---|
| LEGACY | Targeted central followed by standard central, with Stage 02's ordered conditional bilateral clipping | Original role-specific rule |
| STANDARD_COMBINED | Standard combined | Rate remains missing |
| STANDARD_CENTRAL | Standard central | Rate remains missing |
| EXPLICIT_FALLBACK | Standard combined | Same-year standard central as a labelled proxy for missing combined coverage |

| Intervention | Input affected | Identification |
|---|---|---|
| CAP_ONLY | Ceiling on Table I knots, including the capped rank search | Keep measured means, positive profit and Table IV or BSPI anchors fixed. Use the original kernel and the exact Stage 08a audit as the benchmark. |
| MEAN_CLIP_ONLY | Upper clipping of the corrected bilateral ETR and pooled host mean | Keep percentile ceilings, corrected profit, the bilateral regression ETR and the treatment of negative ETRs fixed. |
| RECONCILIATION_ONLY | Parent-year statutory covariate in the reconciliation prior | Refit Stage 02a and apply its result through the unchanged Stage 02–04 code in a scratch tree. Hold the leading behavioural schedule's coefficient fixed for fiscal comparison and separately refit the regression as a diagnostic. Existing zero substitution inside the prior is a nuisance-covariate convention, with missing rates counted separately. |
| INSTRUMENT_ONLY | Same-year statutory diagnostic regressor and exact one-year lagged instrument | Compare each available sample with the intersection of all four definitions. The leading ETR regression and its applied coefficient are fixed. |
| CIT_RECOVERY_ONLY | Rate applied to each existing Rule A/B/C destination flow | Keep eligibility, routes, relocated profit, observed source ETR, top-up and legal allocation fixed. Separately price origin loss at the same statutory definition as a sensitivity. Show covered flow and matched comparisons, leaving unpriced amounts missing. |
| JOINT_CANDIDATE | Accepted measurement and reconciliation rates | Evaluate only after the separate arms. Keep the leading behavioural coefficient and verified collector map fixed. Report instrument and ordinary CIT effects separately. |

For measurement the candidate maximum is min(1, rate + 0.05). Without a supported rate it is 1 for the bounded statistical model. This is a support rule, with the source rate still missing. The combined rate is evaluated as a statistical regularisation proxy. The five-point allowance is inherited and requires a separately controlled calibration sensitivity. The same combined series is a proxy for all-government marginal ordinary CIT, where firm-level rates, relief and recoverable tax bases are unobserved. The low-tax source loss retains the estimated effective rate on the displaced base in the main recovery comparison. The same statutory rate at both ends is a policy-rate stress test.

Report FY2023 and cumulative 2017–2023. Where additional years enter validation or exact lags, show that support in the audit files. Fiscal values are USD. Source amounts and assigned receipts have separate geography. A fixed-law shadow can support conditional attribution, while a new leading specification needs fresh settlement, accounting, budget, game and uncertainty validation.
