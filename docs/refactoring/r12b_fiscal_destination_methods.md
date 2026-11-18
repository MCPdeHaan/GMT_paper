# R12b. Fiscal destination methods

Starting revision `06c699186055607d1bd18e22ae2fd224884bc2de` on `publication-rework`. The scientific reference is R11c with its five leading settings. All profit and tax values below are USD unless otherwise stated. ETR and statutory rate columns contain fractions. Years are historical CbCR observation years.

## Original call graph and contracts

| Operation and owner at the starting revision | Inputs and keys | Result, convention and consumers |
|---|---|---|
| Behavioural source response, `add_behavioural_response()` | Scenario, parent, affiliate, year and the applied schedule | Relocated profit and channel amounts from the source, plus liability before and after response. Stage 05 passes these amounts separately to the destination matrix and the Stage 06 waterfall. |
| Stage 05 `build_rule_b_footprint()` and `build_rule_b_global_footprint()` | Bilateral observed activity, historical statutory gate and bilateral ETR. Global footprint also takes pooled host-year ETR | Parent-year-destination candidates and global-year-destination candidates. Positive observed activity and gate at least 15% qualify a footprint. Missing or negative activity is replaced by zero for this purpose. Global candidates sum qualifying parent activity and use the host ETR. |
| Stage 05 `allocate_rule_b_sources()` and `normalise_formulary_destinations()` | Original source key through a temporary source ID, plus parent and global candidate sets | Source-destination weights and profit received. Exclude the origin and require destination ETR strictly above the finite source ETR below 15%. Absence of a primary route triggers global-year candidates with the same restrictions. Unsupported positive sources fail. Stage 05, Stage 09 Rules B/C and the older notch diagnostic call this boundary. |
| Stage 05 `build_rule_a_global_reallocation()` | Scenario-year-channel pools of positive relocated profit. Destination activity comes from positive-profit rows | Global compatibility matrix. A historical high-tax, non-conduit set takes priority, with the broader positive-profit set if it is empty. Historical price, missing-price floor and nonnegative net-difference convention remain part of this projection. |
| Stage 05 `build_rule_b_reallocation()` and `build_reallocation_matrix()` | Positive bilateral sources, original channel amounts and candidate sets | Channel allocations priced on each route, then aggregated by scenario, year, destination and channel. The compatibility matrix joins B and global A on those keys, keeping their separately named fields. Stage 09 reads the B projection for the all-scenario fiscal ledger and decomposition. |
| Stage 09 `build_parent_specific_reallocation()` | Source losses at bounded source ETR and source amounts pooled by scenario-parent-year | Parent-specific Rule A matrix. The historical statutory gate and conduit exclusion apply regardless of observed destination profit or host ETR. Eligible zero-activity sets can receive equal weights. Global-year fallback uses the same candidate restrictions. The pool preserves its profit-weighted source rate. |
| Stage 09 `build_hub_destination_routes()` and `build_destination_routes()` | Positive bilateral source, parent and affiliate rates from Stage 1, Rule B candidates | Rule C computes B first, then sends half to an eligible headquarters, including same-country headquarters. An absent or ineligible headquarters retains the full formulary route. Rule A has parent-pool grain in this comparison. |
| `destination_price_lookup()` and `attach_destination_prices()` in rates module | Destination and year, optionally lookup from parent rates as well as affiliates | Leading price is the standard combined rate with same-year standard central fallback. A positive route with neither fails required pricing support. The crossed rate-role sensitivity can explicitly report unpriced amounts instead. |
| Stage 09 `build_destination_comparison()`, `build_total_fiscal_country_year()` | Destination receipts and separate original-source loss ledgers, matched to legal receipts by scenario-country-year | Rule A/B/C preferred-scenario and all-32 fiscal results respectively. The comparison uses parent-specific A, while the all-32 Rule B ledger consumes Stage 05's saved matrix. Ordinary net CIT subtracts source-country losses once. Direct top-up changes are then included in the separately named fiscal results. Stage 12 and Stage 13 read the affected ledgers. |
| Stage 06 legal allocation and Stage 11 policy game | Source liability, legal flags and verified parent-year collector weights | QDMTT, IIR and UTPR receipts or residual. Stage 11 computes its game and uncertainty from the source liability and collector routes. Its own credit-cost calculation uses a separate fiscal object. |

Stages 07a, 08 and 10 obtain Stage 05 functionality by local sourcing and directly calculate source or collector projections. Their calculations do not need destination assignment, but their shared import and the Stage 11 dependency through Stage 10 are covered by the replay. The Stage 12 scorecard and Stage 13 exhibits consume Stage 05 and Stage 09 outputs. Appendix E and the fiscal ledger combine reported amounts with distinct economic meanings. The Stage 05 compatibility A and Stage 09 parent-pool A have different eligible sets and are kept independently.

## Extracted interfaces

`code/behaviour/destination_rules.R` owns `normalise_formulary_destinations()`, the Rule B parent and global footprints, `allocate_rule_b_sources()`, `build_rule_a_global_weights()`, `expand_rule_a_parent_pools()` and `build_hub_destination_routes()`. It accepts prepared data and returns weights, assignments and route indicators. It has no legal-top-up allocator dependency.

`code/behaviour/fiscal_incidence.R` owns `build_rule_b_reallocation()`, `build_rule_a_global_reallocation()`, the parent-pool wrapper `build_parent_specific_reallocation()`, the comparison route adapter `build_destination_routes()` and two explicit incidence projections. `summarise_ordinary_cit_incidence()` serves the all-scenario EU27 fiscal comparison and preserves its effective-rate and weight fallback fields. `summarise_destination_incidence()` supplies the preferred-rule comparison, calculating receipts from routes and losses from original sources. Destination-year pricing remains in the rates module. The legal revenue calculation enters only through the existing Stage 09 adapter, which joins the separately computed tax quantities and retains the existing accounting identity.

Stage 05 sources both modules into its existing local calculation environment, retaining the old entry points for downstream callers. It still constructs the compatibility matrix, writes the original schema and coordinates estimation and the factorial design. Stage 09 still selects the comparison arms and windows, calls Stage 06 to calculate avoided top-up by behavioural regime and writes the annual and cumulative fiscal tables. Stage 12 and Stage 13 read the same paths. A parsed-expression check accounts for all 87 original named definitions across the affected stages. Four wrapper bodies now delegate their original blocks. The two new modules only load code on source. Source-safety tests cover package attachment, options, RNG and empirical I/O.

## Rule B eligibility and weights

The detailed key is `(scenario_id, parent, affiliate, year)`. The temporary `source_id` indexes this key within the call. Sources enter with positive relocated profit and a finite source ETR strictly below 15%. The source identifier and ETR stay on the route until eligibility, pricing and channel splitting have been applied. The footprint is unique at `(parent, year, destination)` after the original distinct projection. Conflicting retained activity records fail that check. The source-to-candidate join by parent and year is intentionally many-to-many. Each source's accepted routes retain the destination, weight, provenance and assigned USD. The Stage 05 export aggregates after multiplying each original channel amount by the source weight.

The gate accepts exact equality at 15%. A missing gate removes the candidate. A missing destination ETR or one equal to or below the source ETR cannot receive that source's relocated profit. The comparison makes no separate requirement that the destination ETR itself reach 15%. The origin is excluded. Rule B can admit a conduit if the rate and activity requirements pass. It does not consult the national UTPR register. The same-parent activity inputs use the observed bilateral destination ETR. Global fallback uses the pooled host-year ETR and the sum of already gate-eligible and activity-supported footprints in that year. An absent positive-weight same-parent route triggers fallback. The fallback also excludes the origin and retains the strict ETR comparison. A positive source lacking both routes raises the existing source conservation error. Missing source ETR fails before candidate evaluation.

The raw weight is one quarter of the employee share plus one quarter of the payroll share plus one half of the unrelated-party revenue share. In Rule B's footprint, individual missing or negative activity values become zero, and an all-nonpositive destination drops out. The remaining shares use eligible-destination totals for the particular source. A zero or missing component total contributes zero via the existing safe division and zero fill. The sum of the raw weights then normalises the final weights. One remaining component supplies its own shares. With the two destinations in the brief, the raw combination yields .625 and .375, allocating US$62.50 and US$37.50 of US$100. With only payroll available, payroll shares .25 and .75 assign US$25 and US$75. Equal weights on zero activity belong to the generic normaliser and the parent-pool A path, since Rule B's footprint requires positive activity. Non-finite arithmetic retains the existing conservation safeguards.

## The two Rule A variants and Rule C

Global compatibility Rule A uses a scenario-year-channel source pool and a profit-weighted original source ETR. The historical implementation substitutes zero for missing source ETRs in that projection. Its candidate activity comes from positive-profit rows, first retaining historical high-tax non-conduits. An empty preferred set admits all positive-profit candidates for that scenario-year, including a previously excluded conduit or source. The global version retains its signed employee and payroll aggregation, nonnegative unrelated revenue, equal-weight fallback, historical price, 15% fallback for a missing candidate price and the existing nonnegative price-minus-source-rate bound. It has a different support and price basis from the manuscript's parent-pool Rule A.

Parent-specific Rule A first computes each source loss with the bounded source ETR, then sums the losses and profits within scenario-parent-year. Pool loss divided by pool profit defines the effective source rate. It excludes conduits and requires the historical gate while allowing loss-making destinations and eligible zero-activity sets. Absence of a parent-year set leads to eligible global-year activity. The source pool cannot reappear under a different year. Missing global destinations or weights fail the existing assertion, and closure is checked at the original parent-pool grain. When required, the ordinary CIT price comes from the separate destination-year lookup. The original effective-rate projection uses the greater of 15% and the observed host ETR, falling back to the selected statutory price when the observed ETR is absent.

Rule C first resolves a supported Rule B assignment. With a headquarters gate of at least 15%, the source contributes half to the headquarters and retains half on the resolved formulary route. A below-gate or missing headquarters keeps the full formulary route. The headquarters operation can return profit to the source jurisdiction when the parent and source affiliate coincide. The flag `same_country_headquarters` records those allocations. Where a headquarters and a formulary destination coincide, the route identities still distinguish the components. Residuals are checked by source for B and C separately. The scope and lookup still permit headquarters pricing from the parent rate field in Stage 09.

## Ordinary CIT and the legal collection boundary

The historical targeted-first central covariate still selects destinations. The leading combined-first statutory price and standard-central fallback price assigned profit in the same year. There is no carry-forward or use of collector-status information. The leading path requires a finite price for every positive receipt. The crossed rate-role diagnostic can show positive unpriced profit and missing aggregate gross CIT. The historical-price sensitivity joins the historical price to fixed assignment independently of the eligibility gate. In particular a gate-rate observation does not become a price fallback. Effective destination-rate projections retain the original floor and missingness rules independently.

At destination, gross ordinary CIT is assigned profit times its price. At source, low source ETR times original relocated profit determines ordinary CIT forgone. The diagnostic Stage 05 matrix also carries an attributed source loss split fractionally by assigned routes. This supports the original destination-attributed measures, while the country-incidence comparison deducts the separately aggregated original source loss. A country can appear in both ledgers, with gross receipts and losses combined once by country-year and scenario. The fixtures allocate US$100 at 25% on US$62.50 and at 20% on US$37.50, yielding US$23.125 gross, US$5 source loss and US$18.125 net. A second source loses CIT in a country that also receives profit, confirming jurisdiction-level netting.

The all-scenario fiscal adapter adds a separately measured change in the legal top-up receipts to net ordinary CIT for its total fiscal comparison. The Stage 06 waterfall retains QDMTT, IIR, assigned UTPR, extinction and unsupported residual accounting. The independent allocation fixture has an Irish source relocating profit to Germany and the residual IIR collected in Canada. Stage 11's 432 unilateral cases, 108 historical strategy rows and 7,360 spillover rows use their own source and collector calculations. An unsupported relocated-profit source error cannot become an unassigned-UTPR entry.

## Empirical comparison and fiscal results

The starting code was archived before extraction and evaluated in a separate environment. Both code versions received the same frozen inputs for each paired method audit. A first diagnostic aggregation replaced the route-level receipt column before calculating the EU27 subtotal. The corrected diagnostic keeps a separate total and checks that every supported source has a known EU27 subtotal. Both comparisons use the corrected diagnostic. In both R11c and historical R10b, the paired audit records exact R identity in all 17 objects, including candidate rejections, accepted routes, source rate, exposure and channel fields, both A projections, B and C routes, rate-role ledgers, the ordinary-CIT country-year projections and the separate collector ledger. Exact equality covers row and column ordering, types, attributes, missingness and amounts. No monetary tolerance is used for before/after identity. [Leading keyed parity](r12b/leading_keyed_parity.csv) · [Historical keyed parity](r12b/historical_keyed_parity.csv).

| Calculation | Largest observed absolute residual, USD | Original keys at the maximum |
|---|---:|---|
| Rule B individual source, all scenarios | 0.000068665 | x10101 / USA / USA / 2021 |
| Rule A parent pool | 0.000061035 | x10001 / USA / 2018 |
| Rule A global compatibility, channel pool | 0.000122070 | x10001 / 2018 / transfer_pricing_ip |
| Rule A global compatibility, scenario-year | 0.000244141 | x10011 / 2021 |
| Rule C individual source, preferred scenarios | 0.000022888 | x10001 / USA / USA / 2021 |

These are old and new rounding residuals below the original US$0.001 allocation bound. The parent and source normalisers also retain their original weight-sum checks. Two sources with the same global total but different recipient sets would fail the object comparison. [Residuals](r12b/residuals.csv) · [Global A channel check](r12b/global_a_channel_closure.csv).

For Rule B the frozen R11c audit has 137,826 positive source-scenario rows. It assigns 136,882 on same-parent activity and 944 on global fallback. Every positive source is supported in one of those tiers. Of these, 3,080 have an exact zero EU27 destination amount because they are assigned entirely outside the EU27. The preferred SbS scenario has 11,278 same-parent sources and 74 global fallback sources, the latter carrying US$66.677bn of relocated profit worldwide. Historical R10b has 135,652 same-parent and 920 fallback assignments, with all its positive sources supported. [Leading source totals by route](r12b/source_route_totals.csv) · [Historical source totals by route](r12b/historical_source_route_totals.csv).

The leading source ledger retains the parent, originating jurisdiction, year, profit, original source rate, source CIT loss and exposed pre-response top-up. Its EU27 destination amount distinguishes a supported non-EU allocation from missing support. Candidate counts distinguish missing activity, observed zero and signed values in the original candidate cells. The fallback counts are conditional on having passed the parent-level activity and statutory footprint filters. The fail-fast fixture covers a positive source for which neither route is available. [Source support](r12b/source_support.rds) · [Detailed regional and fallback summaries](r12b/support_summary.csv) · [Candidate rejection counts](r12b/candidate_counts.csv).

In cumulative FY2017–2023 for the preferred SbS scenario, the exact Stage 09 EU27 Rule B receipt comparison gives the following amounts in USD.

| Quantity | USD |
|---|---:|
| Gross ordinary destination CIT | 96,390,148,338.2524 |
| Ordinary source CIT loss | 17,121,619,203.52201 |
| Net ordinary CIT | 79,268,529,134.73038 |
| Direct top-up receipts forgone | 61,694,750,086.55538 |
| Net fiscal gain against the mechanical comparison | 17,573,779,048.174973 |

Using the same gate and assigning the historical statutory price gives US$64.724443bn gross and US$47.602824bn net ordinary CIT for Rule B. The crossed ledger separates the standard-gate effects from the effect of repricing fixed assignments. Parent-pool Rule A and Rule C reproduce US$98.797109bn and US$106.558535bn gross respectively under the leading prices. All three have the same source loss in this comparison. [Exact preferred fiscal results](r12b/preferred_fiscal.csv) · [Historical and standard price/geography projections](r12b/preferred_rate_roles.csv).

## Scientific interpretation and R12c hand-off

The recorded rates are proxies for modelled ordinary CIT at destinations. Public CbCR can establish observed activity in bilateral groups of cells and the source-side covariates, but cannot identify actual destinations for marginal relocated profit, the legal marginal ordinary tax on each flow or realised fiscal incidence. The alternatives are conditional responses to different assignment and pricing assumptions. In particular the global compatibility Rule A rows, the Stage 09 parent-specific Rule A estimates and the source-weighted and destination-attributed incidence measures require their own labels. The historic gate, standard price and separate source rate are therefore part of the model contract.

R12c should start from R12a's Stage 08 covariance matrices and the Stage 09 repair flags. Characterise cluster-appropriate inference and the effect of covariance repair, then compare the statutory and EATR instruments on matched support with weak-IV-robust confidence sets. Explain the remaining exclusion, common-shock and denominator endogeneity problems. Any defensible change to the estimated or applied slope should be compared under these fixed destination contracts before interpreting fiscal sensitivity. The manuscript's two bounded editorial notes remain deferred. [R12a inference evidence](r12a_behaviour_estimation_response.md#iv-interpretation-and-covariance-evidence).

## Reproduction

Run from the repository root with the lockfile R library, a UTF-8 locale and the documented system tools. Set each output variable to a separate fresh absolute directory outside the checkout. Create the empty starting-code directory before extracting its archive. The paired audit writes 17 RDS objects per arm into the audit directories. Compare each RDS by name with strict `identical()` before retaining the compact evidence ledgers.

```sh
export LC_ALL=en_US.UTF-8 TZ=Europe/Amsterdam
export GMT_TABLE_IV_SPECIFICATION=OBSERVED_TWO_SIDED
export GMT_STATUTORY_RATE_SPECIFICATION=STANDARD_ROLE_SPECIFIC
export GMT_UTPR_SPECIFICATION=VERIFIED_PARENT_ONLY
export GMT_BEHAVIOURAL_SPECIFICATION=NO_NOTCH_STANDARD_RESPONSE
export GMT_FACTOR2_SPECIFICATION=SECTORAL_SBIE_ONLY
export GMT_MEASUREMENT_WORKERS=8
unset GMT_MEASUREMENT_CACHE_ROOT
shasum -a 256 -c tests/step17_raw_inputs.sha256
shasum -a 256 -c tests/r05b_legal_inputs.sha256

git archive 06c6991 code | tar -x -C "$original"
Rscript --vanilla code/diagnostics/fiscal_destination_parity.R "$original" "$PWD" "$before"
Rscript --vanilla code/diagnostics/fiscal_destination_parity.R "$PWD" "$PWD" "$after"
Rscript --vanilla -e 'a <- commandArgs(TRUE); x <- list.files(a[1], "[.]rds$");
  stopifnot(length(x) == 17L, identical(x, list.files(a[2], "[.]rds$")));
  for (f in x) stopifnot(identical(readRDS(file.path(a[1], f)), readRDS(file.path(a[2], f))))' "$before" "$after"
Rscript --vanilla tests/testthat.R
Rscript --vanilla run_all.R --output-root="$leading"
Rscript --vanilla tests/verify_golden_step15.R "$leading" r11c
GMT_TEST_OUTPUT_ROOT="$leading" Rscript --vanilla tests/testthat.R
```

For R10b use `LEGACY_HYBRID_SBIE_SBTI` and the other four settings above, including the continuous response. Repeat the standalone audit using the historical archive as its input root. For the targeted replay, seed a separate tree with the archived processed inputs and invoke Stages 05, 06, 07, 08, 09, 10, 11, 12 and 13 in normal order with `GMT_OUTPUT_ROOT` set to that tree. This regenerates every affected destination and fiscal calculation. The archived Stage 07a files supply the historical inputs to subsequent stages of this targeted replay. It has no destination method call in its calculation path. Stage 11 runs its joint simulation again. Verify the entire historical inventory with `Rscript --vanilla tests/verify_golden_step15.R "$historical" r10b` and run the full suite against the replay. Separately compare both historical-notch evaluators with the same source panel and same two-point schedule. The leading acceptance run regenerates all three uncertainty exercises in a fresh tree.

Use the documented [temporary TeX build](../../REPLICATION.md#exhibit-only-reproduction-and-latex-builds) with each replay's exhibits, canonical R11c sources for leading and the archived R10b sources for historical. Verify the TeX inventory by bytes and the figure PDFs after normalising creation and modification timestamps. For the papers and notes compare all rendered pixels, extracted text, dimensions and decoded page content against the matching frozen documents.

## Acceptance record

Verification used R 4.6.0 with all 68 lockfile package versions, the pinned sources and the documented locale. All 54 raw inputs and the independent UTPR legal register matched their pinned SHA-256 digests. The processed manifest digests are `4aae84a52bb1a3c1ec53555ca172460f88242a220af698aa623087313b9482b9` for R11c and `8e6b003d37b1be305874d9445ce84ef9956c2e616e80b35bbfaefeb8460e57e4` for R10b. Both original output inventories passed the verifier before and after extraction.

The targeted checkout suite passed 805 expectations, including 68 new destination and incidence expectations. The complete checkout suite passed 1,951. Both completed with zero failures, warnings and skips. The targeted run covered source response and the historical notch, Factor 2, the legal waterfall, Stage 09, Stage 11, the uncertainty paths, publication and source safety. A separate run on the R10b hybrid panel found exact Stage 05 matrix and preferred A/B/C route identity under the historical notch, with 15,248 bunching rows.

The historical replay passed all 373 processed hashes and the exact processed path inventory. It reproduced 81 TeX exhibits byte-for-byte, eight figure PDFs after normalising timestamps, and the archived 77-page paper and five-page note on decoded page content, dimensions, extracted text and rendered pixels. All 1,951 tests passed against the replay, with zero failures, warnings and skips. This replay recomputed the 500 joint draws and the 47,712 accounting-factorial rows, as well as all 432 repeal and opt-out cases, 108 strategy rows and 7,360 spillover rows.

The leading replay used eight measurement workers and an empty output tree with `GMT_MEASUREMENT_CACHE_ROOT` unset. Stage 07a recomputed all 500 draws in each standalone exercise. The profit-correction simulation has 1,000 policy-draw rows, and the ETR simulation has 16,000 rows across the 32 core scenarios. All 18 standalone uncertainty files in the manifest also passed a separate SHA-256 check as soon as that stage finished. Stage 11 independently ran all 500 joint draws. The two resulting variance and accounting CSVs match SHA-256, including 47,712 factorial rows across the L3 and strict L4 64-scenario and initial-rate 32-scenario designs.

The leading replay's 432 repeal and opt-out rows, 108 strategy rows and 7,360 spillover rows independently match the corresponding frozen tables. In both replays Stage 08 emitted the existing warning that the cluster covariance matrix required repair. Its outputs and the existing inference boundary were retained.

The 15-stage leading replay passed all 374 processed SHA-256 hashes and the exact path inventory. The focused check reaggregated all 32 scenarios from the replayed collector ledger. Cumulative 2017–2023 assigned receipts are shown in US$bn.

| Scope | Preferred SbS | Minimum across 32 | Maximum across 32 |
|---|---:|---:|---:|
| EU27 | 367.670094645 | 196.277042301 | 673.405475525 |
| Global | 1,031.779186724 | 655.048677962 | 1,643.580285054 |

The Factor 2 Shapley share is 0.1434072373%. The source panel, destination matrix, destination closure and collector ledgers also passed strict R identity at the stored keys. The 448 unsupported UTPR source-scenario rows match the reference. The largest collector conservation gap is US$0.000518798828125, within the original US$0.001 bound.

The leading replay reproduced all 81 TeX exhibits by bytes and all eight figure PDFs after timestamp normalisation. The rebuilt 78-page paper and five-page note matched the original page dimensions, decoded page content, extracted text and rendered pixels. All 1,951 expectations passed against the replay, with zero failures, warnings and skips. Both scientific manifests and the tracked publication files retain their original bytes.
