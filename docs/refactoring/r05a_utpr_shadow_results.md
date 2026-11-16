# R05a shadow results and R05b decision memorandum

R05a applies three UTPR collector maps to liabilities for a fiscal year beginning on **1 January 2026**, using the frozen 2017–2023 economic observations and evidence available by 15 November 2026. The [legal basis and source register](r05a_utpr_legal_basis.md) cover the authority, date conventions, qualification and group data limitations. The shadow is separate from the model revision adopted in R04b.

## Eligibility and exposure

- **LEGACY** reproduces the frozen 44-country collector set. All 44 were labelled explicit by a transformation of IIR evidence. Thirty of the 44 have independently verified national UTPR applicability. The pinned input has no independent UTPR rows.
- **VERIFIED** uses 31 countries with verified applicable national UTPR, including Cyprus. The 13 false positives are Canada, Gibraltar, Hong Kong, the Isle of Man, Japan, Jersey, Liechtenstein, Malaysia, Qatar, Singapore, South Africa, Switzerland and Viet Nam. They received US$135.272bn of the R1 universal seven-year pool in LEGACY, 29.70% of that pool. This is their frozen assigned revenue, before reweighting. Japan has enacted a UTPR with later fiscal-year application. Hong Kong's enabling legislation awaits commencement. Canada's proposed retrospective rule was before Parliament at the cutoff. Cyprus has an operative UTPR and positive footprint and received no UTPR in LEGACY. Under VERIFIED its R1 seven-year universal and SbS UTPR receipts are US$0.522bn and US$0.345bn. The five Article 50 electors remain outside all collector maps. [Canada Bill C-31](https://www.parl.ca/legisinfo/en/bill/45-1/c-31) · [Hong Kong IRD](https://www.ird.gov.hk/eng/tax/bus_beps.htm) · [Japan NTA](https://www.nta.go.jp/publication/pamph/hojin/kaisei_gaiyo2026/pdf/H.pdf) · [Cyprus Law 151(I)/2024](https://www.mof.gov.cy/mof/gpo/gazette.nsf/F8E95C499922C956C2258BF7004BA5F1/%24file/5019%2018%2012%202024%20PARARTHMA%201o%20MEROS%20I.pdf)
- **VERIFIED_PLUS_UNRESOLVED** provisionally adds Guernsey, the one unresolved candidate, making 32 countries. Its rule status remains unresolved in the data. Twelve rows for parent-context screening are outside the eligibility universe in every arm. These alternative outcomes reflect changes in denominators, support and fallback. They are sensitivities.

The [mapping comparison](../../data/legal/r05a_shadow/legal_mapping.csv) provides the exact status and date differences, including the original IIR start and the independent first UTPR fiscal year. Australia, for example, first applies UTPR by fiscal-year start in January 2025, a year after its proxy start. Indonesia first applies it on the evaluation date. The dated differences matter even where the January 2026 binary inclusion agrees. The [parent exposure output](../../data/legal/r05a_shadow/parent_exposure.csv) identifies all modelled parents, with the frozen IIR proxy, allocated IIR liability, residual liability and SbS extinguished amounts. Of the universal R1 US$455.453bn residual, the US accounts for US$314.994bn, mainland China US$54.149bn, Saudi Arabia US$28.459bn, the Cayman Islands US$25.525bn and Bermuda US$12.187bn. The five account for about 95.6%. US-parent residual no longer enters the UTPR under frozen SbS. The extinguished amount is measured on the SbS source base. Japan, Hong Kong, Indonesia, Switzerland and Germany lead the separate parent IIR liability ranking. In particular, the applicable Canadian, Hong Kong and Swiss IIR arrangements are compatible with an absent or inactive UTPR. The shadow freezes the parent flags and ownership proxy. [Canadian GMTA](https://laws-lois.justice.gc.ca/eng/acts/G-3.3/page-1.html) · [Hong Kong IRD](https://www.ird.gov.hk/eng/tax/bus_beps.htm) · [Swiss Federal Department of Finance](https://www.efd.admin.ch/en/implementation-oecd-minimum-tax-rate-switzerland)

## Collector receipts and coverage

The source and allocation calculations cover the preferred L3 universal (`x10001`) and SbS (`x10011`) specifications. The R1 source panel is the frozen Stage 06 output. R3 uses Stage 11's existing wrapper to apply QDMTT and IIR to all EU27, preserving that arm's behavioural calculation and other assumptions. For each R1 or R3 source panel, exactly the same liabilities, QDMTT and IIR classifications, SbS extinction and historical activity enter the three collector maps. R3 and R1 have distinct liabilities by design. The [full results](../../data/legal/r05a_shadow/shadow_summary.csv) include exact USD, all channels, geography, amounts and counts by support route, and changes from LEGACY in USD and percent.

Amounts below are US$bn unless marked as percentages. Seven-year values are cumulative.

| Source arm | Window | Policy | UTPR pool | Global assigned, all maps | EU27 LEGACY | EU27 VERIFIED | EU27 VERIFIED + unresolved | EU27 VERIFIED change |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| R1 | FY2023 | Universal | 64.420 | 193.213 | 55.989 | 69.153 | 69.144 | +13.164 (+23.51%) |
| R1 | FY2023 | SbS | 19.285 | 148.078 | 39.350 | 42.928 | 42.926 | +3.578 (+9.09%) |
| R1 | 2017–2023 | Universal | 455.453 | 1358.440 | 478.862 | 550.521 | 550.190 | +71.658 (+14.96%) |
| R1 | 2017–2023 | SbS | 140.458 | 1043.446 | 343.765 | 371.102 | 371.059 | +27.337 (+7.95%) |
| R3 | FY2023 | Universal | 61.068 | 193.213 | 58.206 | 70.670 | 70.662 | +12.464 (+21.41%) |
| R3 | FY2023 | SbS | 19.180 | 151.325 | 42.764 | 46.332 | 46.330 | +3.568 (+8.34%) |
| R3 | 2017–2023 | Universal | 449.217 | 1358.440 | 484.726 | 555.257 | 554.928 | +70.531 (+14.55%) |
| R3 | 2017–2023 | SbS | 139.948 | 1049.171 | 351.880 | 379.116 | 379.073 | +27.236 (+7.74%) |

Global assigned receipts are invariant within each matched case to floating-point summation. QDMTT and IIR amounts are fixed by construction. For example, in R1 the seven-year QDMTT and IIR totals are US$730.469bn and US$172.518bn in both policy settings. The remaining movement is UTPR. Under universal, EU27 UTPR rises from US$173.894bn to US$245.552bn and non-EU27 UTPR falls from US$281.559bn to US$209.900bn. Under SbS, EU27 UTPR rises from US$38.796bn to US$66.134bn, non-EU27 falls from US$101.662bn to US$74.325bn, and the separate US$367.752bn of extinguished liability is fixed. The seven-year largest gains in R1 universal accrue to the UK (+US$32.015bn), Germany (+US$14.295bn) and Ireland (+US$10.074bn). Canada (−US$43.887bn) and Hong Kong (−US$31.286bn) show the largest declines. The [country and channel file](../../data/legal/r05a_shadow/country_channels.csv) reports these amounts and their legacy-relative changes. A new channel with zero baseline has an undefined percentage change.

### Parent-year, fallback and unsupported liability

Assignment follows a positive validated parent-year route, then a supported year fallback if there is no parent-year route. The [pool support ledger](../../data/legal/r05a_shadow/pool_support.csv) carries each original positive scenario × parent × year pool through the route selection. A supported pool that allocates exclusively outside the EU has zero EU share. A missing recipient has an explicit unsupported amount and contributes no assigned receipts. In this exercise every pool was supported after fallback in all arms, including the targeted games. The alternative arms have the same fallback amounts and counts.

| Source arm | Window | Policy | LEGACY parent-year / fallback pools | VERIFIED parent-year / fallback pools | LEGACY fallback US$bn (% of pool) | VERIFIED fallback US$bn (% of pool) |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| R1 | FY2023 | Universal | 14 / 4 | 14 / 4 | 0.691 (1.072%) | 0.691 (1.072%) |
| R1 | FY2023 | SbS | 13 / 4 | 13 / 4 | 0.691 (3.581%) | 0.691 (3.581%) |
| R1 | 2017–2023 | Universal | 87 / 11 | 86 / 12 | 1.766 (0.388%) | 1.816 (0.399%) |
| R1 | 2017–2023 | SbS | 80 / 11 | 79 / 12 | 1.766 (1.257%) | 1.816 (1.293%) |
| R3 | FY2023 | Universal | 13 / 4 | 13 / 4 | 0.691 (1.131%) | 0.691 (1.131%) |
| R3 | FY2023 | SbS | 12 / 4 | 12 / 4 | 0.691 (3.601%) | 0.691 (3.601%) |
| R3 | 2017–2023 | Universal | 81 / 11 | 80 / 12 | 1.766 (0.393%) | 1.816 (0.404%) |
| R3 | 2017–2023 | SbS | 74 / 11 | 73 / 12 | 1.766 (1.262%) | 1.816 (1.298%) |

Without the fallback assumption, the VERIFIED parent-year assignments would cover 99.601% of R1 universal UTPR and 98.707% of R1 SbS over the seven years. The respective FY2023 proportions are 98.928% and 96.419%. The residual under that narrower support criterion is exactly the fallback amount above. It is an empirical support limit, with Mauritius and Chile among the largest parent-year fallback exposures. Neither absence of a CbCR footprint nor use of year-level fallback establishes what an MNE legally owes or who can collect it.

## Targeted repeal and full opt-out

The [deviation file](../../data/legal/r05a_shadow/repeal_shadow.csv) contains FY2023 and cumulative 2017–2023 results for Ireland and Cyprus. Cyprus is the omitted applicable collector. Both use the preferred L3 R3 adoption counterfactual and the archived Stage 11 deviation logic. Repeal alone drops the jurisdiction's QDMTT and retains its IIR and collector eligibility under the chosen map. Full opt-out also removes its IIR and UTPR, with both levels of weights rebuilt for remaining recipients. Behaviour can change **between adoption and deviation** under the frozen rule. Each map receives the same adoption and deviation source panels. No unsupported amount is introduced in either case.

| Country | Policy | Deviation | Foreign IIR, both maps | Foreign UTPR, LEGACY → VERIFIED | Change in domestic collector receipts, LEGACY → VERIFIED |
| --- | --- | --- | ---: | ---: | ---: |
| Ireland | Universal | QDMTT repeal | 3.353 | 22.420 → 22.022 | −25.773 → −25.376 |
| Ireland | SbS | QDMTT repeal | 3.353 | 0.427 → 0.419 | −26.835 → −26.826 |
| Ireland | Universal | Full opt-out | 3.353 | 25.397 → 25.397 | −47.407 → −57.326 |
| Ireland | SbS | Full opt-out | 3.353 | 2.343 → 2.343 | −32.798 → −37.915 |
| Cyprus | Universal | QDMTT repeal | 1.936 | 3.803 → 3.798 | −5.738 → −5.734 |
| Cyprus | SbS | QDMTT repeal | 1.936 | 0.370 → 0.369 | −5.738 → −5.737 |
| Cyprus | Universal | Full opt-out | 1.936 | 3.803 → 3.803 | −5.738 → −6.254 |
| Cyprus | SbS | Full opt-out | 1.936 | 0.370 → 0.370 | −5.738 → −6.082 |

These are cumulative US$bn. The foreign columns refer only to liability from the deviating host; the domestic change covers receipts from all sources. Ireland forfeits US$28.751bn of adoption QDMTT across both cases. Under repeal, it recaptures US$1.067bn of host UTPR in LEGACY universal and US$1.465bn under VERIFIED. The Irish SbS repeal ratio of group relief to net domestic top-up revenue forgone moves from 85.91% to 85.94%. Full opt-out eliminates the deviator's now larger adoption UTPR receipts, including flows from other sources, even when total foreign soak-up of the host pool stays fixed. The much larger opt-out cost therefore has a different mechanism from the change in repeal incidence. Cyprus gains the ability to recapture a small UTPR amount in the repeal arm and removes that ability in full opt-out. The Cyprus dollar scale in this exercise is conditional on hypothetical R3 adoption. These two cases do not establish the full equilibrium or the countries for which the sign or rank of opt-out payoffs changes.

## Decision for R05b

1. **Correct the jurisdiction rule independently of the source flags.** Use positively verified domestic applicability for the named 1 January 2026 fiscal-year policy and publish provenance by instrument and rule. Separate the collector UTPR flag from parent IIR, QDMTT, modelled SbS and qualification. Remove each demonstrated non-applicable recipient and include Cyprus. Keep Guernsey unknown unless its operative text is verified. Revisit Canada only if changing the evidence vintage or explicitly modelling its proposal. A different FY start could include Japan. Neither change belongs in the 1 January baseline.
2. **Default to evidenced recipient availability and parent-year support.** Retain the two observable activity components in the frozen weighting proxy for the first controlled specification, and disclose the single-component rule. Use VERIFIED with the parent-year footprint as the leading projection and report remaining residual liability explicitly. Preserve VERIFIED with global-year fallback as a paired sensitivity to show the effect of assigning the unsupported-on-observed-footprint amounts. The shadow dollar amounts put the size of this choice in context. Using fallback as the production point would be viable for continuity if labelled as imputed allocation, with separate reporting of its receipts. It is a discretionary imputation. The provisional Guernsey arm can remain a narrow sensitivity until resolved. Across R1's seven-year results it shifts US$0.331bn universal and US$0.043bn SbS from EU27 relative to VERIFIED, with no global change.
3. **Keep a group-level legal model as a distinct specification.** The statutory allocation formula, Article 50(2), Article 49, qualification and safe harbours do not imply that the requisite facts are observable. Test separately whether and how to model source-side changes, group thresholds, group-specific zero allocations, previously unpaid allocations and off-calendar start rules. Require evidence for any substitution. Holding those predicates fixed first identifies the collector-map effect.
4. **Rerun the full research contract before adoption.** Reclassify each R1/R2/R3 intervention only as approved. Rebuild legal activity and weights in the detailed Stage 06, collapsed Stages 07a/09 and sparse Stage 11 implementations, and propagate any unsupported residual through ledgers, accounting and variance outputs. Check the entire 32-case core and expanded accounting design, the 500-draw studies with affected caches invalidated, and the full 27-country game at both L3 and L4. Compare adoption, QDMTT-only and full-opt-out routes by parent, source, collector and channel, including foregone QDMTT, domestic and foreign recapture, unsupported residual and SbS relief separately. Match spillovers, welfare denominators and global versus domestic identities. Report headline deltas, revise the relevant manuscript text, captions, Appendix E weight counts and legal vintages, and version the proposed freeze only after that review.

R05a carries out the mapping comparison and shadow diagnostics only. It leaves the production eligibility flags, frozen outputs and manuscript at R04b.

## Reproduction

Run from the repository root with R 4.6.0 and the lockfile-matched library. The two isolated invocations have no cache and use the archived R04b freeze as inputs. To run the R05a acceptance suite as shipped, use commit `ef458db1bbf12e10d6ac01828591c5c7c632e420`.

```sh
export LC_ALL=en_US.UTF-8 TZ=Europe/Amsterdam
export R_LIBS=/private/tmp/gmt-r02-verify.UJ7adqE8/r-library
shasum -a 256 -c tests/step17_raw_inputs.sha256
reference=$(mktemp -d)
git archive 338d7203958c34d036f5e5baa21b8a4ffdd0a036 data/processed | tar -x -C "$reference"
Rscript --vanilla tests/verify_golden_step15.R "$reference" r04b
shadow=$(mktemp -d)
second_shadow=$(mktemp -d)
Rscript --vanilla code/allocation/utpr_eligibility_shadow.R "$shadow" "$reference/data/processed"
Rscript --vanilla code/allocation/utpr_eligibility_shadow.R "$second_shadow" "$reference/data/processed"
diff -rq "$shadow" "$second_shadow"
diff -rq "$shadow" data/legal/r05a_shadow
```

Both frozen weight tables rebuild exactly, including key order. The [LEGACY checks](../../data/legal/r05a_shadow/legacy_checks.csv) match country-year-channel globally and country-year totals within the EU27 for R1, EU27 country totals for R3, and the two targeted Stage 11 game comparisons against their frozen references. The largest numeric gap is US$0.0000153. The comparison uses an absolute US$0.001 threshold, consistent with the Stage 06 and Stage 11 routing checks. Positive pools and complete routed totals are reconciled separately. The shadow CSVs are versioned under `data/legal/r05a_shadow/`, outside the scientific freeze. A full fifteen-stage run is unnecessary under gate C for a read-only standalone diagnostic with unchanged production dependencies. The correct production guard is exact path and byte verification on R04b, alongside uncached execution and tests of the new path.

Both isolated runs and the committed seven-file shadow inventory matched byte for byte. All 24 summary rows reconcile by source, channel and geography. The largest matched global receipt difference across the eligibility maps was US$0.000366, below the US$0.001 round-off tolerance. All 54 pinned raw inputs and all 361 processed outputs matched the R04b reference. The targeted legal, routing and source-safety run passed 63 expectations. The full suite passed 984 expectations with zero failures, warnings or skips.
