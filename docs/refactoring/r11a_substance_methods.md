# R11a substance methods and support

R11a started from the clean `publication-rework` checkout at `859a867e377049b3fe2984939d0ae0ace708e49a`. It retains the R10b Table IV, statutory-rate, UTPR and behavioural specifications. All dollar amounts below are model quantities over the stated economic observation years. Policy-rate endpoints and transition years index separate counterfactuals.

## Call graph and contracts

Previously `04_stage2_sbie.R` owned all three numerical layers, and Stage 11 repeated the capacity coefficients in its game and sparse evaluator. Stage 04 now sources `aggregate_sbie.R`, `sbti_capacity.R` and `sectoral_sbie.R` into its existing evaluation environment. Stage 05 and its downstream callers retain the same Stage 04 entry points. Stage 11 obtains the two capacity legs through this path and preserves its multiplication order, game, route comparison and sparse evaluation. [Stage 04 adapter](../../code/04_stage2_sbie.R) · [Stage 11 applications](../../code/11_policy_game_and_variance_extensions.R)

| Operation and owner | Input and key | Calculation, support and downstream use |
|---|---|---|
| Aggregate bilateral shield, `aggregate_sbie.R` | Stage 1 pair panel × rate endpoint, keyed by rate scenario × parent × affiliate × year | Dollar SBIE is `sigma_w * payroll + sigma_a * assets`. The numerical contribution of missing activity is zero and the input is retained with a fallback flag. Divide by positive profit, clip the fraction to `[0, 1]`, then apply its complement to each ladder's low-tax profit and top-up. The liability calculation coalesces a missing incoming top-up to zero. Zero profit gives an undefined shield and a unit filter, while missing profit gives a missing filter. Used by Stage 05 and as a reference in 07a, 08, 10 and 11. |
| Affiliate-year aggregation, Stage 04 | Bilateral output keyed by rate scenario × affiliate × year after grouping | Sum dollar amounts with missing values omitted. Weighted rates use non-missing observations with positive, non-missing weights. Profit-weighted shield and top-up-weighted shield answer different questions. Stage 12 and Stage 13 read the summary. |
| Allocation and sectoral shield, `sectoral_sbie.R` | Stage 02 FATS sidecar keyed by affiliate × year × NACE. Stage 04 joins unique affiliate-year totals and crosses the transition schedule. | Profit uses `sectoral_profit_share` from the FATS profit-proxy hierarchy, payroll uses `fats_payroll_share` and assets use `sectoral_asset_share`. Available shares sum to one within the existing `1e-8` check. Missing sector shares and unmatched totals remain missing. Sector SBIE uses the same numerical zero contributions and its own sector denominator. Stage 04 selects the 2022 reference matrix and the 2021–2023 endpoints from the result. |
| Capacity and diagnostic floors, `sbti_capacity.R` | Sector dollar activity on the same keys | Capacity is `max(.055 * payroll, .01 * assets)` within each sector. Either missing leg makes the maximum missing. `sectoral_kappa` divides the capacity by sector profit and is missing at a zero or missing denominator. After the diagnostic floor `max(0, .15 - max(gap, 0) * phi)`, the overlay subtracts `min(max(kappa, 0), floor)`. A missing floor or capacity yields a missing overlay. H5 uses the resulting floor difference. |
| Sectoral liability rates and bundled Factor 2, Stages 04 and 05 | Sectoral endpoint panel plus host gap and low share. Aggregates to rate scenario × affiliate × year, then applies to source cells. | At sector grain, take `gap * (1 - phi)` and `max(0, gap * (1 - phi) - kappa)` separately. The host low share scales profit-weighted rates. The bundle divides the latter rate by aggregate liability per dollar of profit. Stage 05 uses a contemporaneous, 2022-reference, then unit fallback. The 32-case design inherits these amounts before allocation. |
| Independent sectoral SBIE and overlay, Stage 09 | Same host-year and source design keys, with separate `x2a_sectoral` and `x2b_sbti` | Sector-only sets capacity to zero in the sectoral bridge. Overlay-only applies sector capacity to the common aggregate-SBIE gap and retains sector profit weights. The `00` and `11` arms inherit the core values. The six-factor diagnostic attributes collector receipts after allocation. Stage 04's separate decomposition uses common-support source rates. |
| H5 and bracket shields, Stages 04 and 08 | H5 uses the 2022 initial reference and the 2022, 2023 and pooled 2021–2023 endpoint samples. Each requires positive sector profit and finite floor difference and capital intensity. Stage 08 uses observed Table IV bracket activity at host and bilateral grain. | H5 uses the original country or country-year fixed effects, profit weights where specified and affiliate-clustered diagnostics. Stage 08's bracket shield requires observed activity and a usable wage. Its liability comparison retains the Table I filter on unsupported rows. The Stage 08 EU27 L3 business-activity covariance warning belongs to R12. |
| Stage 11 repeal and incentive overlay | R3 `x10011` positive-QDMTT sources at parent × affiliate × year, in EU27 for 2021–2023. Source rows expand to host-year shares and return to their original keys. | Each capacity leg is computed on source dollars, multiplied by its sector share and then by the low-profit share. The game takes the maximum within sectors, caps the distinct relief amounts against their relevant bases and retains the original behavioural scaling. The detailed allocator checks collector receipts after applying the overlay. |
| Stage 07a and Stage 11 uncertainty | Stage 07a profit-only preferred draws, Stage 07a standalone ETR draws and Stage 11 sparse source arrays | Profit-only re-divides fixed dollar SBIE by drawn positive profit and keeps the estimated schedules and selected sector scale fixed. Standalone ETR draws update the gap and low share while retaining physical sector inputs. Stage 11's sparse kernel holds sector dollars and shares fixed, recomputes profits, `phi` and capacity per profit, then projects the resulting source liabilities to collectors. |
| Stage 10 and publication | Accounting-adjusted Stage 10 bilateral and host panels. Stages 12 and 13 read the saved diagnostics. | Stage 10 re-divides fixed SBIE by revised profit when applicable. Its conduit variant updates the low-tax gap without changing sector activity or its denominator. The accounting and transitional safe-harbour calculations keep their own numerator and support. The scorecard and exhibits present the saved quantities without feeding them back into production. |

The original 2024–2033 linear sequence, 10% payroll and 8% assets initially, and 5% for both in the long run remain in Stage 04 alongside the readers, affiliate-year aggregation, country-year base, panel selections, H5 covariance and models, decomposition, diagnostics and writers. The 2022 asset-component sensitivity applies its original ±25% variation without coalescing missing sector amounts. The BEA comparison continues as an external validation of the sector allocator. The row keys and column schemes of the 2022 reference matrix, the endpoint panel and all diagnostics stay intact. [Aggregate SBIE](../../code/substance/aggregate_sbie.R) · [Sectoral scaling](../../code/substance/sectoral_sbie.R) · [Capacity](../../code/substance/sbti_capacity.R)

## Missing activity and fixed-support comparisons

The table describes disjoint Stage 04 positive-profit cells, FY2017–2023 at the initial endpoint. Dollar amounts are in billions. Observed activity totals sum available inputs. Residual top-up uses the study's distributional L3 measurement before behaviour and routing.

| Scope and missing inputs | Pair-years | Profit | Payroll | Assets | SBIE | Top-up before SBIE | Top-up after SBIE |
|---|---:|---:|---:|---:|---:|---:|---:|
| Global, neither missing | 12,593 | 40,319.787 | 9,283.935 | 49,052.078 | 4,852.560 | 1,558.139 | 1,393.827 |
| Global, payroll missing | 1,511 | 1,583.434 | 0 | 1,718.258 | 137.461 | 185.086 | 177.673 |
| Global, assets missing | 4 | 5.762 | 1.426 | 0 | 0.143 | 0.297 | 0.289 |
| EU27, neither missing | 3,638 | 7,313.188 | 2,506.685 | 8,012.153 | 891.641 | 358.928 | 326.776 |
| EU27, payroll missing | 3 | 0.054 | 0 | 0.070 | 0.006 | 0.001 | 0.001 |
| EU27, assets missing | 3 | 3.516 | 1.343 | 0 | 0.134 | 0.271 | 0.263 |

There are no positive-profit cells with both legs missing. Global payroll-missing cells carry about 10.6% of pre-SBIE L3 liability. A zero in a missing-activity column denotes the available total and Stage 04's numerical contribution. Reported and constructed activity must still be distinguished using the existing provenance.

Across FY2021–2023, the EU27 sector panel has 81 country-years and 3,240 sectors at each endpoint. Allocated positive profit, payroll and assets sum to US$3,420.043bn, US$1,372.114bn and US$4,136.247bn. The maximum absolute country-year discrepancies against the respective totals are US$0.000061, US$0.000122 and US$0.000061. Source shares remain incomplete at sector grain. There are 396 missing profit shares in 69 host-years, 343 missing payroll shares in 55 and 219 missing asset shares in 36. Available shares sum to one. Non-GOS profit proxies allocate US$215.283bn, scaled payroll proxies US$15.681bn, and fallback investment-flow shares allocate US$670.915bn of the asset stock proxy. The Stage 05 distributional bridge uses contemporary rates in all 81 FY2021–2023 EU27 host-years and the 2022 reference in 108 older host-years per endpoint. Those older years carry US$3,896.714bn of profit and US$201.940bn of initial aggregate post-SBIE liability before applying the scale.

## Sector-first capacity and the game

Among 2,894 EU27 sector cells with both legs finite, the 2021–2023 sector-first maximum sums to **US$104.494bn**. The sum of country-year maxima over exactly the same activity is **US$79.943bn**. The **US$24.551bn (30.7%)** difference measures the effect of changing the order of the maximum and aggregation. It includes zero-profit sectors and holds sector coverage fixed. Real estate (`L`), trade (`G`) and computer programming and information services (`J62–J63`) account for 43.2% of the sector-first capacity. The EU27 sector panel is the available scope for this comparison.

There are 132 zero-profit sectors with positive payroll or assets, with US$14.290bn of payroll, US$44.541bn of assets and US$1.017bn of measured dollar capacity. Their ratio is undefined. Sectors with supported positive profit account for US$103.141bn of capacity. In 936 positive-profit sector cells with a positive low share, capacity per profit exceeds the residual gap after SBIE, including cells with a zero residual gap. After applying the low share, those cells carry US$20.230bn of capacity and US$1.810bn of post-SBIE liability. This comparison uses the same population and profit denominator for both quantities. It identifies saturation under the existing overlay.

The R3 Side-by-Side game holds aggregate SBIE and the adoption response fixed. It estimates pre-SBIE covered taxes on low profit. New-incentive use is capped at those taxes and represents hypothetical ordinary CIT expenditure, with an equal covered-tax add-back in this arm. For an existing incentive already reflected in tax, the capacity-to-low-profit ratio reduces the gap before multiplying by excess low profit and the behavioural factor. The overlay counterfactual instead caps relief against dollar top-up after SBIE, then scales by the same behavioural factor. Foregone QDMTT is the change in assigned QDMTT under the resulting counterfactual. These margins have distinct fiscal meanings.

| 2021–2023 R3 Side-by-Side, US$bn unless noted | L3 pooled | Strict L4 |
|---|---:|---:|
| Positive-QDMTT sources | 1,492 | 1,147 |
| QDMTT on those sources | 107.987 | 111.077 |
| Maximum capacity proxy | 31.386 | 33.258 |
| Sources with capacity above QDMTT | 440 | 375 |
| QDMTT on those sources | 8.845 | 7.433 |
| Capacity on those sources | 15.354 | 16.736 |
| New incentive or ordinary CIT expenditure proxy | 19.144 | 20.093 |
| Modelled overlay relief | 16.469 | 16.447 |
| Modelled relief for already-reflected incentives | 14.324 | 14.590 |

## R11b diagnostic scope

The frozen public data supply corrected positive profit, reported tangible assets, headcount and imputed payroll, and FATS/EUKLEMS allocation proxies. They do not identify group-jurisdiction eligible payroll and assets, eligible depreciation and depletion, qualifying incentive terms and utilisation, covered-tax effects, or five-year elections and eligible carrying values. The OECD's primary guidance describes a group-jurisdiction cap, a default using eligible payroll or depreciation and depletion, and an elective eligible carrying-value method. A sector-level maximum using the two currently modelled legs has a separately defined meaning. [OECD Side-by-Side Package, chapter 3, especially pp. 71–78](https://www.oecd.org/content/dam/oecd/en/topics/policy-sub-issues/global-minimum-tax/side-by-side-package.pdf#page=71)

Start R11b with a fixed-support decomposition of sector versus pooled maxima, the missing-activity and share cases above, and separate caps on post-SBIE liability, new incentive use and already-reflected covered-tax relief. Then assess alternative payroll and carrying-value cases and explicit depreciation scenarios, with clearly labelled assumptions for eligibility and elections. Compare source amounts and R3 receipts on identical keys before considering a specification change. S06 remains open. [Scientific issue register](scientific_issue_register.md#s06-sbti-capacity-overlay-and-use-are-different-quantities)

## Verification

Run the optional characterisation from the repository root with an explicit evidence directory outside the processed output tree.

```sh
Rscript --vanilla code/diagnostics/substance_support.R "$PWD" "$audit_dir"
```

All 21 Stage 04 files match the original checkout by bytes. Ordered keys, values, types and attributes match directly for the bilateral panel (37,908 rows), affiliate-year summary (3,006), endpoint sector panel (6,480) and 2022 reference matrix (10,800). Re-running the original and extracted functions on the same inputs gives identical Stage 11 source-capacity objects (1,492 L3 and 1,147 strict L4 rows), all 378 Stage 09 host-year scales, and 17,792 source rows from all 64 scenarios across Germany, Ireland and the Netherlands in 2019, 2022 and 2023. These checks include individual relief amounts and the six-factor off-diagonal cells. The synthetic fixtures also cover the original endpoint sequence, missing denominators, join keys, nonlinearity, source-to-QDMTT conservation and module isolation.

Use the [locked replication environment](../../REPLICATION.md#package-and-execution), the four leading R10b settings and a fresh absolute `replay` directory for the main gate.

```sh
shasum -a 256 -c tests/step17_raw_inputs.sha256
shasum -a 256 -c tests/r05b_legal_inputs.sha256
GMT_MEASUREMENT_WORKERS=10 Rscript --vanilla run_all.R --output-root="$replay"
Rscript --vanilla tests/verify_golden_step15.R "$replay" r10b
GMT_TEST_OUTPUT_ROOT="$replay" Rscript --vanilla tests/testthat.R
```

Historical compatibility was checked with `LEGACY_PUBLISHED` Table IV support on R09b inputs. Stage 04 recomputed its 21 files, and Stage 11 recomputed the repeal game, 500 joint draws, both accounting designs and 27 influence cases. The resulting tree matches all 367 historical hashes and its suite passes 1,650 expectations. This targeted historical replay retains the other stage outputs and publication inputs from the verified R09b run. The retained R06b tree also matches all 364 historical hashes.

### Completed acceptance gate

On 17 November 2026 all fifteen stages completed in a fresh directory under R 4.6.0 with all 68 lockfile package versions, `en_US.UTF-8` and `Europe/Amsterdam`. The stage wall times totalled 2,607.1 seconds. Stage 07a took 2,117.2 seconds with ten native workers. It recomputed 500 profit-correction draws and 500 measurement-error draws, with 16,000 unique draw–scenario records. Stage 11 recomputed 500 joint draws, both accounting designs and the influence diagnostics. The run used the original runner and fresh draws throughout, with no simulation cache or checkpoint reuse.

| Gate | Result |
|---|---|
| Pinned inputs and inventory | All 54 raw/manual hashes and the separate legal-register hash match. All 373 processed hashes and the ordered manifest's exact path set match in the checkout and replay. The R10b manifest SHA-256 is `8e6b003d37b1be305874d9445ce84ef9956c2e616e80b35bbfaefeb8460e57e4`. |
| Test suites | 1,096 targeted expectations, including 86 new substance expectations. Both full R10b suites pass 1,656 expectations each. All suites have zero failures, warnings or skips. |
| Exact component checks | All 606,528 ordered core source rows across 32 scenarios, all 78 saved stress and decomposition rows, all 432 game payoffs and all 108 incentive comparisons match. The original fiscal classifications, H5 samples and inference are preserved. The standalone exposure audit also gives identical output bytes from the checkout and replay. |
| Publication | 81 TeX files match byte-for-byte. Eight figure PDFs match with creation and modification timestamps normalised. The rebuilt 77-page paper and five-page note match the checked-in pages in dimensions, decoded content streams, text and rendered pixels. The bibliography matches by bytes. |

The replay retains R10b's `fixest` covariance regularisation warning in the Stage 08 EU27 L3 business-activity regression, deferred to R12, and the paper's existing underfull box. Both are distinct from the test-suite results. No scientific freeze, source data, empirical output or publication file changes in this iteration.
