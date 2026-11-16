# R05b. Verified UTPR collectors and observed activity

## Scientific decision and legal evidence

The leading specification applies national UTPR rules for a fiscal year beginning **1 January 2026**, using evidence published through **15 November 2026**. It assigns UTPR only where at least one eligible jurisdiction has observed activity for that CbCR parent and year. FY2017–2023 remains the economic base for the counterfactual. Source liabilities, the R1/R2/R3 QDMTT and parent IIR predicates, and the SbS switch retain their previous definitions.

The [dated national register](../../data/legal/utpr_eligibility_2026.csv) covers 50 collector candidates and 12 parent-context jurisdictions. It supplies 31 verified recipients, including 22 EU Member States:

- EU27 recipients: AUT, BEL, BGR, CYP, CZE, DEU, DNK, ESP, FIN, FRA, GRC, HRV, HUN, IRL, ITA, LUX, NLD, POL, PRT, ROU, SVN and SWE.
- Other recipients: AUS, GBR, IDN, KOR, MKD, NOR, NZL, THA and TUR.
- Thirteen inapplicable legacy recipients: CAN, CHE, GIB, HKG, IMN, JEY, JPN, LIE, MYS, QAT, SGP, VNM and ZAF. Japan's commencement reaches fiscal years from 1 April 2026. Hong Kong's UTPR requires separate commencement. Canada's proposed commencement was still in a bill at cutoff. The other charging instruments and guidance establish different or narrower rule coverage. [Japan NTA](https://www.nta.go.jp/publication/pamph/hojin/kaisei_gaiyo2026/pdf/H.pdf) · [Hong Kong IRD](https://www.ird.gov.hk/eng/tax/bus_beps.htm) · [Canada C-31](https://www.parl.ca/legisinfo/en/bill/45-1/c-31) · [Gibraltar Act, sections 12–14](https://www.gibraltarlaws.gov.gi/uploads/legislations/minimum-tax/2024-20/2024-20o.pdf) · [Isle of Man Order, article 7](https://tynwald.org.im/index.php/spfile?file=%2Flinks%2Ftls%2FSD%2F2024%2F2024-SD-0234.pdf) · [Malaysia enactment and implementation guidance](https://www.hasil.gov.my/media/llke0zf0/domestic-topup-tax-guidelines.pdf)
- Cyprus enters on evidence of its own enacted UTPR. Estonia, Latvia, Lithuania, Malta and Slovakia remain deferred as collectors. Article 50(2) concerns collection by other Member States on liabilities of groups headquartered in deferring states. Slovakia's domestic top-up is separate. [Cyprus Law 151(I)/2024, article 61](https://www.mof.gov.cy/mof/gpo/gazette.nsf/F8E95C499922C956C2258BF7004BA5F1/%24file/5019%2018%2012%202024%20PARARTHMA%201o%20MEROS%20I.pdf) · [Directive 2022/2523, articles 12–14, 49, 50 and 56](https://eur-lex.europa.eu/eli/dir/2022/2523/oj/eng) · [Commission notice C/2023/1536](https://eur-lex.europa.eu/eli/C/2023/1536/oj/eng)
- Guernsey is the one unresolved collector candidate. The States' vote concerns implementation of IIR and domestic top-up. The States' record confirms that instrument No. 97 of 2024 was made on 26 November 2024 and laid before the States. The operative text could not be verified directly. Its provisional inclusion is evaluated separately. The parent-context screen is a distinct and incomplete inquiry into potential parents. [Guernsey legislative vote](https://statesvoting-records.gov.gg/Propositions/Details/1572) · [Instrument laid before the States](https://parliament.gg/parliamentary-business/assets/resolutions/resolution-iii-2025-02-05)

The [R05a legal basis](r05a_utpr_legal_basis.md) and register give each jurisdiction's charging instrument, dates, evidence status and sources. Independent OECD UTPR qualification remains unestablished in this register. Neither the presence of an IIR listing nor the absence of a UTPR listing identifies it. National applicability establishes potential recipients under the model's rule map. Article 14 requires activity of the individual group in its qualified implementing jurisdictions, with exclusions and cash-collection adjustments. CbCR parent-year aggregates pool many groups. The source-side Article 49 exclusion, transitional UTPR safe harbour, January 2026 UPE Safe Harbour and group-specific Article 14 adjustments require separate legal and empirical work. The UPE Safe Harbour concerns UTPR on profit in the UPE jurisdiction. The broader SbS Safe Harbour used in the research switch concerns the foreign backstops of eligible groups. [OECD Central Record](https://www.oecd.org/en/topics/sub-issues/global-minimum-tax/central-record-of-legislation-with-transitional-qualified-status.html) · [OECD January 2026 package](https://www.oecd.org/content/dam/oecd/en/topics/policy-sub-issues/global-minimum-tax/side-by-side-package.pdf)

## Matched-source fiscal comparison

| Specification | Recipient map | Support |
|---|---|---|
| `LEGACY_FALLBACK` | Historical IIR proxy | Parent-year, then pooled-year |
| `VERIFIED_FALLBACK` | Verified national UTPR | Parent-year, then pooled-year |
| `LEGACY_PARENT_ONLY` | Historical IIR proxy | Parent-year |
| `VERIFIED_PARENT_ONLY` | Verified national UTPR | Parent-year |
| `VERIFIED_PLUS_UNRESOLVED_PARENT_ONLY` | Verified plus provisional Guernsey | Parent-year |

[The comparison outputs](../../data/legal/r05b_comparison/) cover all 32 R1 cases, both preferred R3 cases and each policy case over FY2023, 2017–2023 and 2019–2023. The latter totals can be divided by five for annual averages. The comparisons are deterministic sensitivities.

The table gives modelled EU27 receipts in US$bn. The last four columns decompose the change from historical to leading. Eligibility compares the two maps with fallback retained. Fallback compares removal under the historical map. The interaction compares the fallback-removal effect under the verified map with the same effect under the historical map. Thus the combined change equals the sum of the three effects, with rounding only in this table. The [unrounded decomposition](../../data/legal/r05b_comparison/effects.csv) carries the corresponding quantities for each fiscal outcome and the independent Guernsey sensitivity.

| Preferred R1 | Legacy + fallback | Verified + fallback | Legacy parent only | Verified parent only | Eligibility | Fallback | Interaction | Combined |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| FY2023 Universal | 55.989 | 69.153 | 55.690 | 68.759 | +13.164 | −0.299 | −0.095 | +12.770 |
| FY2023 SbS | 39.350 | 42.928 | 39.051 | 42.534 | +3.578 | −0.299 | −0.095 | +3.184 |
| 2017–2023 Universal | 478.862 | 550.521 | 478.108 | 549.474 | +71.658 | −0.755 | −0.292 | +70.611 |
| 2017–2023 SbS | 343.765 | 371.102 | 343.010 | 370.055 | +27.337 | −0.755 | −0.292 | +26.290 |
| 2019–2023 Universal | 327.554 | 386.558 | 326.987 | 385.779 | +59.003 | −0.568 | −0.211 | +58.225 |
| 2019–2023 SbS | 232.689 | 255.122 | 232.122 | 254.343 | +22.432 | −0.568 | −0.211 | +21.654 |

Cumulative EU27 receipts rise by 14.75% in universal and 7.65% in SbS. The SbS reduction grows from US$135.097bn (28.2%) to US$179.419bn (32.7%). The global assigned reduction due to dropping fallback is US$0.691bn in FY2023, US$1.349bn in 2019–2023 and US$1.816bn in 2017–2023, under both preferred R1 policy settings. Over all seven years that last difference comprises US$1.766bn from removing historical fallback and a US$0.050bn interaction. The eligibility-only effect on global assigned revenue is zero to numerical precision. With verified eligibility fixed, removing fallback reduces EU27 receipts by US$1.047bn cumulatively under either policy. Provisionally adding Guernsey under parent-only lowers cumulative EU27 receipts by US$0.331bn under universal and US$0.043bn under SbS. It does not materially change the global assigned total.

### Support and channel ledger

Verified parent-only routes the two cumulative R1 pools of US$455.453bn and US$140.458bn through 86 and 79 supported parent-years, respectively, and leaves 12 unsupported in each. The amounts supported are 99.60% and 98.71%. In FY2023 the supported shares are 98.93% and 96.42%, with four unsupported parent-year pools in each. Under verified fallback the otherwise unsupported pools use pooled-year weights in these cases. Across R3 the cumulative EU27 totals move from US$484.726bn to US$554.210bn under universal and from US$351.880bn to US$378.069bn under SbS. The R3 benchmark also has US$1.816bn unsupported under parent-only in both scenarios.

| R1 scope, US$bn | QDMTT globally | IIR globally | Assigned UTPR EU27 | Assigned UTPR elsewhere | Assigned globally | SbS extinguished | Unsupported |
|---|---:|---:|---:|---:|---:|---:|---:|
| FY2023 Universal | 96.585 | 32.208 | 34.305 | 29.425 | 192.522 | 0 | 0.691 |
| FY2023 SbS | 96.585 | 32.208 | 8.080 | 10.514 | 147.387 | 52.551 | 0.691 |
| 2017–2023 Universal | 730.469 | 172.518 | 244.505 | 209.131 | 1,356.624 | 0 | 1.816 |
| 2017–2023 SbS | 730.469 | 172.518 | 65.086 | 73.556 | 1,041.630 | 367.752 | 1.816 |

Stage 06 retains the original source keys and tests closure before and after collector aggregation. Positive liability equals assigned USD plus SbS extinction plus unsupported USD. Within a supported parent-year, collector weights sum to one. EU27 and other recipients partition assigned revenue. The leading model produces 4,937 weights at parent × year × collector covering 323 parent-years. All 31 eligible recipients receive positive weight. The 440 positive source × scenario rows without support span all 32 scenarios. The largest cumulative unsupported amount across the core is US$2.305bn. If only one of employees or assets has support, that component supplies the weight. A zero EU share with observed non-EU support remains zero. A parent-year with no support retains its full UTPR liability outside receipts. This records insufficient support under the proxy. It has no implication for whether the tax is legally collectible or paid.

At fixed source and channel, EU27 gains principally come from reweighting. Germany gains US$14.045bn, Ireland US$10.024bn, France US$9.082bn and the Netherlands US$8.928bn in the cumulative universal case. These four and Luxembourg retain their positions in the top five. In SbS, Ireland (+US$5.093bn), Germany (+US$5.043bn) and the Netherlands (+US$3.640bn) show the largest gains. Italy moves from eighth to seventh. Cyprus goes from zero to US$0.520bn and US$0.343bn under universal and SbS respectively, through UTPR alone. The [country-by-channel table](../../data/legal/r05b_comparison/country_channel_effects.csv) and [EU27 ranks](../../data/legal/r05b_comparison/eu27_country_ranks.csv) give the full distribution.

In 16 matched preferred R1 and R3 cases with fallback, the comparison reproduces the published R05a totals at a maximum gap of US$0.0001221. The legacy global country-year-channel projection matches the historical Stage 06 file within US$0.00000191, and the leading projection matches the revised Stage 06 file exactly at those keys. The full measurement, accounting and game exercises recalculate source amounts as those designs require. Their estimands differ from this fixed-source comparison. [Reconciliation CSV](../../data/legal/r05b_comparison/reconciliation.csv)

## Consequences for the paper

- **Scenario ranges.** The 32-scenario R1 FY2023 EU27 range moves from US$11.474–67.837bn to US$12.637–83.280bn. Cumulatively it moves from US$144.277–584.879bn to US$155.348–670.666bn. The 2019–2023 annual average range moves from US$17.892–79.979bn to US$19.685–94.127bn. [All five ranges](../../data/legal/r05b_comparison/eu27_core_ranges.csv)
- **Decomposition.** Core measurement Shapley share moves from 74.31% to 72.01% over 2017–2023, while SbS rises from 16.07% to 20.07%. Measurement and accounting still explain most 64-scenario variation. Their combined share moves from 84.68–91.75% to 82.77–89.67% across the two main windows and both ladders. Over 2021–2023 it is 91.49–91.82%. Strict L4 accounting no longer has the larger Shapley share in the full 64-scenario seven-year design. Accounting takes the lead under strict L4 with initial rates fixed. The preferred SbS accounting-bridge receipt estimate moves from US$214.06bn to US$231.12bn. [Accounting comparison](../../data/legal/r05b_comparison/accounting_comparison.csv)
- **Joint uncertainty.** The EU27 parameter share moves from 1.71% to 1.64% over 2017–2023 and from 0.36% to 0.40% over 2019–2023. The ratios of scenario spread to the preferred 90% interval width move from 6.93 to 7.24 and from 14.99 to 15.96. The scenario share now exceeds the parameter share in Austria as well as the other collecting Member States. [Joint variance comparison](../../data/legal/r05b_comparison/joint_variance_comparison.csv)
- **Budgets.** The 16 distributional cases, full 32 and documented-policy arms retain their R04b definitions. Four of the eight principal FY2023 benchmarks fall inside the core range, down from five. The Dutch post-package line no longer overlaps. The full core minimum rises from €0.108bn to €0.248bn against €0.176bn. The FY2023 pre-SbS German minimum rises from €1.173bn to €1.669bn against the €1bn cash forecast. Separate forecast channels and vintages retain their original comparison scopes. [Budget comparison](../../data/legal/r05b_comparison/budget_comparison.csv)
- **Ordinary CIT and collector exposure.** The preferred SbS top-up loss from behaviour rises from US$58.09bn to US$62.11bn, while Rule B's gross ordinary CIT recovery remains US$65.27bn. Net of the source CIT lost, the overall fiscal effect is −US$13.95bn. The revised ledger shows Cyprus with UTPR receipts and four EU Member States with zero assigned receipts.
- **Game.** The L3 and strict L4 matrix includes 432 rows across 27 countries, two deviations, two policy regimes and two windows. QDMTT repeal retains the recipient map, while full opt-out removes the deviator and recalculates the normalisation. In cumulative L3 universal repeal, foreign IIR and UTPR together receive US$195.77bn across the separate experiments, down from US$197.41bn. Domestic recapture increases correspondingly. Under universal full opt-out, AUT, ESP, FIN, GRC, IRL, NLD and SWE generate host residuals summing to US$10.29bn across the seven separate L3 deviations. Ireland generates US$1.91bn of host residual and a corresponding decline in assigned global receipts under universal full opt-out, with zero source-liability saving. Irish cumulative SbS repeal efficiency remains 85.9% after rounding, whereas its full opt-out efficiency falls from 70.3% to 60.9%. No state has a positive net fiscal payoff from repeal at zero weight on retained profit. The core incentive finding survives, with a different decomposition of where the liability goes. [All 432 before/after rows](../../data/legal/r05b_comparison/repeal_comparison.csv)

## Reproduction and acceptance

Run from the root with R 4.6.0 and the lockfile-matched R library, UTF-8 and Europe/Amsterdam time. The current gate uses independent legacy and revised output trees.

```sh
export LC_ALL=en_US.UTF-8 TZ=Europe/Amsterdam
shasum -a 256 -c tests/step17_raw_inputs.sha256
shasum -a 256 -c tests/r05b_legal_inputs.sha256
revised=$(mktemp -d)
legacy=$(mktemp -d)
reference=$(mktemp -d)
git archive 338d7203958c34d036f5e5baa21b8a4ffdd0a036 data/processed | tar -x -C "$reference"
GMT_UTPR_SPECIFICATION=LEGACY_FALLBACK GMT_MEASUREMENT_CACHE_ROOT="$reference" \
  Rscript --vanilla run_all.R --output-root="$legacy"
GMT_UTPR_SPECIFICATION=VERIFIED_PARENT_ONLY GMT_MEASUREMENT_WORKERS=4 \
  Rscript --vanilla run_all.R --output-root="$revised"
Rscript --vanilla tests/verify_golden_step15.R "$legacy" r04b
Rscript --vanilla tests/verify_golden_step15.R "$revised" r05b
GMT_TEST_OUTPUT_ROOT="$legacy" Rscript --vanilla tests/testthat.R
GMT_TEST_OUTPUT_ROOT="$revised" Rscript --vanilla tests/testthat.R
Rscript --vanilla code/allocation/utpr_policy_comparison.R \
  "$revised/data/processed" "$reference/data/processed" "$(mktemp -d)" --full
```

Stage 06 uses US$0.001 absolute tolerance for pool and point scenario-year reconciliations. The largest point scenario-year gap is US$0.000458. The Stage 07a simulation retains its established US$1 absolute draw-level aggregation tolerance, while checking pool closure at US$0.001. A trial run using the Stage 06 point tolerance on draw 464 exposed US$0.001038 of floating-point summation error. The successful run applies the original measurement-draw tolerance with the unsupported component explicitly included. The maximum draw-level gap is US$0.001038. An independent eight-draw run was byte-identical on one and two workers. The sparse check retains its pre-existing US$0.001 plus a floating-point allowance proportional to liability. The Stage 11 game reconciles source-country incidence at its existing per-deviation tolerance and checks worldwide differences separately.

The R04b historical replay reproduces all 361 processed hashes, 81 TeX files and eight figure PDFs after date normalisation. Its 13 cached measurement-error outputs were hash-verified against R04b. Its joint Monte Carlo and full game ran, and both PDFs compiled from the historical sources and matched after metadata normalisation. The original R05a seven-file shadow also reproduces byte for byte against the archived output tree.

The R05b replay used all 68 lockfile package versions and completed all fifteen stages in 1,802 seconds of reported elapsed stage time. It recomputed 500 measurement-error draws, 500 profit-correction draws, 500 joint draws and the complete game. Stage 11's sparse point projection agrees with Stage 06 within US$0.0000535. The largest joint scenario-year reconciliation gap is US$0.001221 under the existing size-adjusted tolerance. The [R05b manifest](../../tests/golden_r05b.csv) verifies all 363 files in both the replay and the checkout. Relative to R04b, 224 are byte-identical, 137 change with receipts or their diagnostics, and two are new. The new files record the active recipient policy and unsupported source keys. All 54 original inputs and the separately pinned legal register passed SHA-256 verification.

Of the 81 generated TeX files and eight figure PDFs, 36 TeX files and six figures change. Independent regeneration matches the new TeX byte for byte and the figures after date normalisation. Two `latexmk` builds of the 76-page manuscript and five-page research note agree after normalising identified volatile PDF fields. The selected bibliography is byte-identical. The abstract, routing figure, source ledger, repeal tables and research-note comparison were checked in the rendered PDFs.

The full suite passed 1,047 expectations in each of the R05b checkout and isolated replay, and 1,029 on the isolated R04b replay. All three runs had zero failures, warnings or skips. The routing, legal, budget and source-safety selection passed 285 expectations. The final acceptance tests select the manifest and exhibits for the specification under test and check the 108 new source-ledger scorecard rows separately from the existing metric inventory. The Cyprus publication check verifies its inclusion under the leading collector map.

The old manifests and archived commit identify the earlier baseline. The paired budget and game tables outside `data/processed/` document the scientific differences and can be regenerated using the comparison command. Use `git diff --name-status ef458db1bbf12e10d6ac01828591c5c7c632e420` against the R05b commit for the complete revision inventory.

An independent restore still needs the four pinned companion extracts described in the [replication guide](../../REPLICATION.md). The evidence date and the historical CbCR years are distinct. Actual group footprints, legal qualification where unpublished, ownership and cash receipts remain outside the identified estimand.
