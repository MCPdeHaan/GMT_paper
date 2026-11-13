# Technical revision audit for the GMT journal article

5 September 2026. This is a prioritised research audit, based on source, selected implementation and existing outputs. It does not assert that every identified risk has already been quantified. No pipeline was rerun in preparing this review.

**P0 means resolve before presenting the main empirical claims as publication-ready. P1 means resolve before journal submission. P2 means improve if the material remains in the article.** The sequence is designed to remove weak dependencies, not to add more complexity.

## P0.1 — Establish what “revenue implications” means

**Evidence.** The thesis's redistribution subsection says profit reallocation is a conservation/plausibility exercise rather than a revenue channel. Its central equation subsequently allocates top-up liability. Yet the introduction and conclusion compare the behavioural result with forecasts that include ordinary corporate income tax.

Source: [behaviour and redistribution](/Users/mauritsdehaan/Documents/VSC/GMT_paper/writing/thesisv4.tex:939), [revenue equation](/Users/mauritsdehaan/Documents/VSC/GMT_paper/writing/thesisv4.tex:1030).

**Consequence.** A reduction in top-up tax when profits move can accompany an increase in ordinary CIT at the destination. Variance in a simulated top-up amount is also different from the share of total revenue gains caused by behaviour. The claim that behaviour is relatively unimportant in GMT fiscal outcomes therefore exceeds the present estimand.

**Action.** Use top-up revenue as the main object, explicitly named, or add a complete ordinary-CIT accounting. For any total-revenue extension, include destination gains, source losses and consistent treatment of the changed top-up liability. Specify the tax base and marginal tax rate on moved profit. Do not assume profits moving to a high-average-ETR jurisdiction necessarily face that average rate or automatically escape further top-up tax at subgroup level.

**Pass condition.** Every headline and comparison uses the same revenue object or includes an explicit bridge. A tax economist can trace a unit of moved profit and its tax consequences through the model without a missing or double-counted channel.

## P0.2 — Correct the monetary units of payroll

**Evidence.** The wage hierarchy selects OECD annual USD_PPP and ILO PPP monthly wages, alongside a nominal USD fallback. Payroll is then employees multiplied by the selected wage. Profit is reported in current USD.

Source: [wage construction](/Users/mauritsdehaan/Documents/VSC/GMT_paper/code/02_base_correction_and_merging.R:318), [payroll calculation](/Users/mauritsdehaan/Documents/VSC/GMT_paper/code/02_base_correction_and_merging.R:605).

**Consequence.** PPP international dollars and nominal US dollars measure different things. Combining them in payroll/profit or an SBIE amount can systematically distort cross-country comparisons, even if every numerical operation runs successfully.

**Action.** Use nominal wages in local currency with consistent exchange rates, or explicitly convert the PPP observations back to the relevant nominal amounts using matched PPP factors, price bases and exchange rates. Check employee population, employer contributions, annualisation and sector composition separately.

**Pass condition.** A unit dictionary and independently checked country examples reconcile payroll, assets and profit in the same monetary concept. Report the change in liability levels and decomposition ranking from this correction alone.

## P0.3 — Distinguish MNE subgroups from legal subsidiaries

**Evidence.** The thesis repeatedly calls Table IV subsidiary-level data. OECD defines it by the effective tax rate of an MNE subgroup and tax jurisdiction. A subgroup comprises a group's entities in a jurisdiction; observations are subsequently aggregated for publication.

Sources: [thesis Table IV description](/Users/mauritsdehaan/Documents/VSC/GMT_paper/writing/thesisv4.tex:1331), [OECD Table IV metadata](https://data-explorer.oecd.org/vis?df%5Bag%5D=OECD.CTP.TPS&df%5Bds%5D=dsDisseminateFinalDMZ&df%5Bid%5D=DSD_CBCR%40DF_CBCRIV).

**Consequence.** The reader needs the actual unit of measurement to evaluate jurisdictional blending, profit/loss aggregation and the link to GloBE. The data are valuable but do not reveal each subsidiary or exact GloBE liability.

**Action.** Rewrite the data architecture and verify the raw SDMX dimensions, profit panels, overlapping brackets, negative-tax categories and suppressed cells. Treat Table IV as closer to the relevant group-jurisdiction concept, while retaining the distinction between accounting CbCR and GloBE adjustments.

**Pass condition.** The text, diagrams, code variable dictionary and worked example all use the same observation unit. Bracket totals reconcile to comparable totals without double counting nested categories.

## P0.4 — Reconsider the percentile-based distribution estimator

**Evidence.** The source pools subgroup-count-weighted bilateral percentiles, fits a Beta distribution constrained by a profit-weighted mean ETR, and uses the CDF as a profit share. The implementation visibly averages percentiles. Its existing validation reports 239 overlapping affiliate-years, a 0.293 mean absolute error in low-taxed shares, 0.665 at the 90th percentile, Spearman correlation 0.474 and calibration R-squared 0.208.

Sources: [percentile pooling](/Users/mauritsdehaan/Documents/VSC/GMT_paper/writing/thesisv4.tex:1495), [implementation](/Users/mauritsdehaan/Documents/VSC/GMT_paper/code/03_stage1_etr.R:323), [validation table](/Users/mauritsdehaan/Documents/VSC/GMT_paper/writing/generated/results_tables/stage1_crossval.tex).

**Consequence.** Averaging quantiles does not generally recover a mixture distribution's quantiles. As a simple illustration, populations concentrated at rates 0 and 1 with weights 90% and 10% have a pooled median of 0; the weighted average of their medians is 0.1. A count-weighted distribution also does not determine profit weights without information about profit conditional on the rate. Constraining its mean does not eliminate that missing information.

**Action.** Make direct bracket profit and tax totals the preferred measurement on a comparable reporting population. Where predictions are needed, fit component distributions and combine CDFs only under clearly justified weights; recognise that this fixes the pooling operation but not necessarily profit weighting. Alternatively, use a prediction model calibrated to observed profit shares or derive bounds under explicit support assumptions. Use missing-data and imputation flags; a model prediction is not direct observation.

**Pass condition.** The estimator has a defensible target and probability/weighting interpretation. Holdout evaluation supports its actual use case. If accuracy remains weak, the branch is removed from the preferred estimate or reported as a bounded sensitivity. Do not select an arbitrary numerical error threshold after seeing results; agree what accuracy matters for the policy question first.

## P0.5 — Do not substitute pooled host distributions for ownership evidence silently

**Evidence.** The low-tax share and top-up gap are defined at affiliate-year level and applied to bilateral profits, while Side-by-Side depends on parent jurisdiction. The reported direct-source counts are counts of bilateral rows inheriting source assignments, not necessarily independent direct bilateral measurements.

Sources: [measurement and hybrid selector](/Users/mauritsdehaan/Documents/VSC/GMT_paper/writing/thesisv4.tex:733), [source coverage](/Users/mauritsdehaan/Documents/VSC/GMT_paper/writing/generated/results_tables/stage1_source_coverage.tex).

**Consequence.** US-parented and other subgroups may have different low-tax shares within the same host. Public-data coverage can also differ between the bracket source and the bilateral population receiving the imputation. Both affect the legal-allocation result.

**Action.** Retain parent–affiliate bracket information when available. Use a matched-reporting-population comparison; separately bound unsupported ownership assignments. Report observed and imputed shares of profit, liability and collector revenue. Examine whether US-versus-other ownership differences can be directly measured.

**Pass condition.** A reader can distinguish observed subgroup-bracket evidence from extrapolation. The Side-by-Side result survives plausible differences in ownership composition or is explicitly conditional on them.

## P0.6 — Unbundle legal simplification, incentives and behavioural response

**Evidence.** Factor 5 combines the elasticity with a SESH band [13%,15%) set to zero liability. Factor 2 combines sectoral substance allocation with an SBTI-capacity overlay. These choices change different economic/legal objects simultaneously.

Sources: [safe-harbour filter](/Users/mauritsdehaan/Documents/VSC/GMT_paper/writing/thesisv4.tex:924), [factor definitions](/Users/mauritsdehaan/Documents/VSC/GMT_paper/writing/thesisv4.tex:1051), [OECD package](https://www.oecd.org/content/dam/oecd/en/topics/policy-sub-issues/global-minimum-tax/side-by-side-package.pdf).

**Consequence.** Neither factor's share isolates what its short label suggests. Capacity is not take-up. A simplified-ETR safe harbour is not an automatic rule applying to an observed CbCR rate just below the threshold.

**Action.** Use distinct toggles or separate designs for behavioural response, safe-harbour eligibility/measurement and incentive use. Remove the assumed near-threshold exemption from the preferred branch absent supporting evidence. Date each legal regime and check actual domestic implementation. Document the limits of approximating group-level elections and ownership chains from parent-country aggregates.

**Pass condition.** Each factor changes one interpretable object, or is deliberately labelled a policy package. Legal examples are reviewed by a knowledgeable specialist. A static scenario and a behavioural response are not accidentally counted twice.

## P1.1 — Show what the variance decomposition does and does not establish

**Evidence.** The code computes factorial sums of squares within country-year and then sums them for the pooled measure. The factor endpoints mix alternative measurement methods, a known transition schedule and a legal counterfactual.

Source: [decomposition implementation](/Users/mauritsdehaan/Documents/VSC/GMT_paper/code/07_stage4_6_revenue_pipeline_decomposition_functions.R:240).

**Consequence.** This is a valid descriptive decomposition of a particular design. It is not automatically variance of EU total revenue or probabilistic forecast uncertainty. Wide chosen endpoints can create a large variance share. Main-effect dominance also does not follow merely because a factor appears earlier in a multiplicative equation; multiplication itself is commutative.

**Action.** Report pooled country-year and EU-total decompositions separately. Show main effects in money, alternative plausible ranges and legally feasible scenarios. Distinguish measurement uncertainty, parameter uncertainty and policy counterfactuals. Explain the assumptions under which equal allocation of interaction contributions has the intended Shapley interpretation. Avoid inferential p-values for algebraic consequences as if scenarios were independent observed experiments.

**Pass condition.** The headline states the design and aggregation. The qualitative policy claim survives relevant alternative designs, or the sensitivity becomes part of the finding. Describe inter-study disagreement only after a real common-basis reconciliation.

## P1.2 — Validate the size of country results

**Evidence.** Current processed diagnostics report Dutch preferred revenue of about USD 87.1bn and Luxembourg revenue of USD 51.7bn over six historical bases, with Luxembourg revenue/CIT about 2.25.

Source: [current fiscal diagnostics](/Users/mauritsdehaan/Documents/VSC/GMT_paper/data/processed/diagnostics/step7_stage4_6_fiscal_salience_country.csv).

**Action.** Trace the largest contributing cells. Compare annual results and matching fiscal denominators. Reconcile accounting bases, dividends, loss rules, deferred tax, taxes attributed across jurisdictions, domestic-only groups where relevant, sector exclusions and collection rules. Explain the residual versus official or published estimates. Do not tune a model to a ministry's figure without independent justification; official forecasts also contain assumptions.

**Pass condition.** Large results have a traceable, economically plausible explanation and explicit sensitivity. If they remain unvalidated, do not build a strong budget or country-ranking recommendation on them.

## P1.3 — Propagate measurement changes through the relevant downstream objects

**Evidence.** The profit-correction table reports preferred final SbS revenue of 303.7bn, compared with 356.8bn uncorrected and 264.1bn under high correction. Its 500-draw interval is conditional on fixed distributional low-tax shares, behavioural filters and allocation weights.

Source: [correction sensitivity](/Users/mauritsdehaan/Documents/VSC/GMT_paper/writing/generated/results_tables/profit_correction_revenue_sensitivity.tex).

**Consequence.** The narrow draw interval does not establish comprehensive measurement robustness. The broader correction scenarios move the level materially. A lack of sensitivity can arise because an affected link is held fixed.

**Action.** For each perturbation, state which quantities are re-estimated, which are fixed and why. Rerun the economically dependent stages when claiming full propagation. Preserve genuinely conditional exercises, but label them accordingly. Use targeted stress ranges for unresolved foreign holding-chain double counting instead of treating a 10% haircut on a small flagged subset as proof that the entire issue is negligible.

**Pass condition.** The uncertainty statement matches the actual computation. Both conditional intervals and structural changes are visible, without implying that scenario extrema form a confidence interval.

## P1.4 — Rebuild literature and policy comparisons

**Evidence.** The thesis credits public-data novelty against a characterisation of Hugger et al. as confidential microdata, although their published data statement identifies aggregated CbCR as the main source. The Dutch opening figure of EUR 466m is historical, while later government answers give a different contemporaneous baseline.

**Action.** Audit contribution statements and references against originals. Separate publication-online date from volume year where relevant. Compare the same annual revenue object, currency, coverage and policy assumptions. Include the July 2026 OECD materials. Update the Dutch discussion using official answers 270–271 and do not attribute all EUR 122m to a single allocation rule.

Sources: [Hugger et al.](https://link.springer.com/article/10.1007/s10797-024-09869-2), [Dutch government answers](https://zoek.officielebekendmakingen.nl/kst-36915-3.html).

**Pass condition.** A reader of the nearest papers agrees that you have represented them accurately and can identify a nontrivial incremental contribution.

## P2 — Simplify, reproduce and release

The elasticity tournament, sectoral exposure regression and PCA/k-means country types should support the main argument only if they earn their space. The current source already recognises weak causal identification in the elasticity and the partly mechanical character of sectoral results. Keep that restraint in the article's introduction and conclusion as well as the appendix.

Preserve useful existing influence checks. The latest generated influence table keeps measurement's share between 60.8% and 87.7%, while older logbook versions reported different results. Cite the current computation, not whichever historical version supports the preferred narrative. [Current influence table](/Users/mauritsdehaan/Documents/VSC/GMT_paper/writing/generated/results_tables/appendix_jurisdiction_influence_decomposition.tex).

Create a dated data dictionary, reproducible runner, dependency lock, calculation notes and selected hand-worked examples. Ask an independent reader to regenerate the principal tables from the instructions. Check the manuscript, tables, appendix and abstract against that one snapshot. Update AI-use, data availability, author contributions and conflict statements for the new article.

**Final submission gate:** a clearly novel question; defensible measurement; consistent units; separately labelled legal scenarios; validated revenue magnitudes; a properly delimited uncertainty claim; and one independent methods review. The result need not preserve the thesis's numerical ranking to pass.
