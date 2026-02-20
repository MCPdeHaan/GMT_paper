# Blouin & Robinson (2023) — "Accounting for the Profits of Multinational Enterprises: Double Counting and Misattribution of Foreign Affiliate Income"

## Abstract & Core Claim (p. 1)

The paper addresses a fundamental measurement problem in the empirical profit-shifting literature. The central argument: estimates of MNE profit shifting are severely overstated because researchers fail to account for the accounting conventions underlying the data they use. Two specific errors are identified:

1. **Double counting** — counting the same dollar of MNE income more than once, in two or more jurisdictions.
2. **Misattribution** — attributing income to the wrong jurisdiction.

Both errors arise specifically when MNE parent companies own foreign affiliates *indirectly* (i.e., through tiered ownership structures). The focus is on data from the U.S. Bureau of Economic Analysis (BEA), though the authors show the problem pervades all commonly used datasets. The paper is explicitly relevant for calibrating the reforms currently being implemented (OECD/G20 BEPS, Pillar One/Pillar Two), since the revenue estimates underlying those reforms may be systematically too large.

 

## 1. Introduction (pp. 2–5)

### Policy context
The international tax reform agenda (OECD/G20 BEPS, U.S. GILTI, Pillar One/Two) is motivated by empirical estimates of large-scale profit shifting. These estimates rely on academic and policy work suggesting MNEs engage in extensive tax avoidance. The authors do not dispute that some profit shifting occurs, but challenge the *magnitude* of the estimates.

### Two measurement errors
- **Double counting** arises from the equity method of accounting that the BEA requires. When a Dutch holding company holds a German subsidiary, the German affiliate's income appears *both* in Germany (standalone) *and* in the Netherlands (as "equity income" on the Dutch affiliate's books). Researchers who do not remove equity income count the same dollar twice.
- **Misattribution** arises because the doubled income is attributed to the holding company's jurisdiction (e.g., Netherlands), not where it was actually earned (Germany). The BEA's Direct Investment (DI) data solves double counting but introduces misattribution instead, because it reports income from the perspective of *directly* held affiliates only, lumping in income from indirectly owned sub-affiliates.

### Growing severity
Both errors are "increasing in frequency" because MNE ownership structures have become more complex over time (footnote 1 cites UNCTAD on increasingly complex MNE ownership). The introduction of "check-the-box" regulations in the U.S. accelerated tiered ownership structures after ~1999/2000 (Blouin & Krull 2019).

### Semi-elasticities
The paper also challenges the large and/or non-linear semi-elasticities of income to tax rates found in prior literature (Hines & Rice 1994; Dowd et al. 2017; Garcia-Bernardo & Janský 2021). The authors argue these are artefacts of mismeasurement, not evidence of actual profit shifting. When using correctly measured income (Net Income Excluding Equity Income), the non-linearities largely disappear and no discontinuity between haven and non-haven semi-elasticities remains once country fixed effects are included.

### Illustrative replication: Clausing (2016)
A key quantitative demonstration: Clausing (2016) estimated the U.S. annual revenue loss at between $77bn and $111bn. When the authors replicate that study correcting for double counting and misattribution (holding all other methodology constant), the estimate falls to **$11 billion per year**. The correction alone reduces the estimate by approximately a factor of ten.

### Data focus
The paper focuses on BEA data because the BEA is explicit and consistent in its methodology (unchanged since at least 1982). The same accounting problems are shown to affect IRS Form 5471, IRS Form 8975 (CbyCR), and Bureau van Dijk (Orbis). Non-U.S. data sources follow a wide variety of accounting methods, making cross-country comparisons particularly hazardous.

 

## 2. Measuring BEPS: The Role of Accounting Methods (pp. 6–10)

### 2.1 Constructs required to study profit shifting (p. 6)
To estimate profit shifting, researchers need: (1) jurisdiction-specific income, (2) taxes incurred per jurisdiction. Financial accounting data is preferred over tax return data because tax data is distorted by jurisdiction-specific rules (e.g., U.S. bonus depreciation). Accounting data is a "standardised measure of economic activity."

### 2.2 MNE ownership structures and income measurement (pp. 6–7)
The hypothetical MNE used throughout the paper (also adopted by the BEA itself in their FAQ — see https://www.bea.gov/help/faq/1402) has the following structure:
- U.S. parent (t = 21%) owns 100% of a Netherlands affiliate (t = 25%) directly.
- The Netherlands affiliate owns 100% of a Germany affiliate (t = 30%) — so Germany is *indirectly* owned by the U.S. parent.
- Stand-alone financials: Germany earns pretax $400, pays $120 tax, nets $280. Netherlands earns pretax $60, pays $15 tax, nets $45. U.S. parent earns $0 on a stand-alone basis.

The key insight: on a purely stand-alone basis, the U.S. parent shows zero income — but it has obviously benefited from its subsidiaries. Accounting rules determine how this change in wealth is recorded.

### 2.3 The three accounting methods (pp. 7–10)
Three methods exist under U.S. GAAP and IFRS for equity investments in affiliates:

**Consolidation method:** Combines all assets, liabilities, revenues, and expenses of the group into a single statement. Under this method, the Dutch affiliate (as parent of Germany) reports combined pretax $460 (= $400 + $60), combined tax $135 (= $120 + $15), and net income $325. All of Germany's activity is on the Dutch books — but not all activity took place in the Netherlands. Governed by U.S. GAAP ASC 810; requires majority (>50%) ownership.

**Equity method:** The parent reports its proportional share of the affiliate's *net income* as a single line item ("equity income") on its own income statement. So the Dutch affiliate reports: equity income $280 (= German net income), plus its own pretax income $60, giving pretax income of $340, with tax expense of only $15 (because equity income is already after-tax). Net income = $325. Important: "equity income is merely an accounting construct. It does not represent actual income earned or cash flows generated in the foreign affiliate parent's jurisdiction." Governed by U.S. GAAP ASC 321; generally applies when ownership is 20–50%, or majority with "significant influence." Like consolidated income, equity income is recorded *on an accrual basis*, regardless of dividends.

**Cost method:** Income is recognised only when a *cash distribution* (dividend) occurs. In the example, Germany pays a $10 dividend to Netherlands. Since the Netherlands uses a participation exemption, no Dutch tax applies. The Dutch affiliate reports $10 dividend income with no extra tax expense. Under the cost method, only the distributed income ($10) is recognised, not the full $280 earned in Germany. Governed by U.S. GAAP ASC 325.

 

## 3. How Accounting Methods Introduce Measurement Issues (pp. 10–24)

### 3.1 BEA data production and use of the equity method (pp. 10–13)
BEA data are described by the OECD as "best practices in available data for BEPS analysis" (OECD 2015, p. 35). The BEA's explicit methodology has not changed since 1982.

The BEA collects two relevant data series:
- **AMNE data** (Activities of Multinational Enterprises) — provides "Net Income" for each company in the ownership structure.
- **DI data** (Direct Investment) — provides "Direct Investment Income" only for the U.S. parent with respect to its *directly held* affiliates.

**Critical BEA rule:** The BEA departs from standard GAAP and *requires* all parent-affiliate relationships to be reported using the **equity method** — including when foreign affiliates are themselves parents of other foreign affiliates. This is described as producing "data that are conceptually or analytically more useful or appropriate for MNE analysis" (BEA Concepts and Methods Guide, p. 230). The survey instructions state that the equity method must be used for "equity investments of 20 percent or more in unconsolidated foreign affiliates, including all unconsolidated majority-owned affiliates."

**Implication for research:** The equity income reported by a parent must be *excluded* for jurisdiction-specific measurement. If not excluded, the German affiliate's $280 of net income appears *twice* in the AMNE data — once in Germany, once in the Netherlands as Dutch "equity income." The correct adjusted measure the authors recommend is "**Net Income Excluding Equity Income**."

**DI data problem:** The DI data reports $325 as the U.S. parent's income from the Netherlands. It provides no detail that $280 of this was earned in Germany. Germany "essentially does not exist in the DI data." So DI data solves double counting but creates income misattribution.

### 3.2 Detailed measurement issues (pp. 13–24)

#### 3.2.1 Double counting (pp. 13–15)
Net Income (including equity income) and Net Income Excluding Equity Income began diverging in the late 1990s (Figure 2, Panel A), largely because the "check-the-box" regulations introduced around that time prompted U.S. MNEs to adopt tiered ownership structures. The equity income causing double counting is concentrated in tax haven affiliates that serve as foreign parents (Figure 2, Panel B; citing Lewellen & Robinson 2014).

Historical context: The double counting issue was first noted academically by Altshuler & Grubert (2006, p. 472), but was *misinterpreted* there as cash distributions. The equity method does not require a distribution — income is recognised on an accrual basis. This misinterpretation persisted in Yorgason (2009), Clausing (2009, 2011, 2016, 2020a, 2020b), GAO (2008), Beer et al. (2018). Riedel (2018) in her literature review also perpetuated this misunderstanding. Importantly, it was not until 2020 — after this paper was circulated — that the BEA explicitly addressed double counting from equity income on its website (https://www.bea.gov/help/faq/1402) and in its Concepts and Methods Guide (pp. 225–26).

Footnote on hybrid dividends: If the distributing affiliate deducts the dividend (hybrid dividend), aggregate income would actually be *understated* under the equity method, not overstated. But there is no evidence that hybrid dividends are frequently used within U.S. MNEs between foreign affiliates.

#### 3.2.2 Income misattribution (pp. 15–18)
Double counting and misattribution are related: once equity income is excluded from the Dutch affiliate, both problems are resolved simultaneously. With unadjusted Net Income, the Netherlands shows $325 (of which $280 is German income), and Germany shows $280 — a double count and a geographic misattribution.

DI data does not solve misattribution. Referring to Figure 3, Panel A (a revision of Figure 2 from Zucman 2014): when equity income is properly excluded, the share of income in six tax havens falls from approximately **55% to 38%** of all foreign profits. Furthermore, the identity of the leading U.S. tax haven changes: with equity income included, the Netherlands appears to be the top U.S. tax haven; with equity income excluded, **Ireland** is the leading tax haven.

Figure 3, Panel C shows three ownership structures: in Structure 1 (both affiliates directly owned by U.S. parent), DI data attributes income correctly. In Structure 2 (70% indirect ownership of Germany via Netherlands), 70% of DI income is misattributed to the Netherlands. In Structure 3 (100% indirect), all income is misattributed to the Netherlands. "For Structure 1, 2, and 3, respectively, 0%, 70%, and 100% of Direct Investment Income is attributed to the wrong jurisdiction." This structure-induced misattribution is particularly problematic because ownership structures change over time, including for tax reasons (Lewellen & Robinson 2014).

#### 3.2.3 Estimating effective tax rates (pp. 18–21)
Effective tax rates (ETR = tax expense / pretax income) are corrupted by income mismeasurement. Key point: tax expense itself is *not* affected by the equity method, because tax is not recorded on equity income. So if equity income inflates the denominator but not the numerator, ETRs are systematically too low for countries reporting equity income.

Example: In the Netherlands, the correct ETR is 15/60 = 25%. But using Net Income (with equity income), the apparent ETR is 15/340 = 4.4%.

You cannot simply take tax expense from AMNE data and match it to DI data income. If an affiliate is indirectly owned, it doesn't appear in DI data at all, so its taxes are not captured for that jurisdiction. "Estimates of the sensitivity of that MNE's income to taxes will vary greatly, though the firm's earnings are identical" — depending purely on ownership structure.

Figure 4 quantifies the ETR bias for 1983–1999 vs. 2000–2017:
- **Haven countries (Panel A):** The ETR decline using Net Income is -66%, using DI income -53%, using Net Income Excluding Equity Income only -33%. Net Income Excluding Equity Income is consistently closer to statutory rates than the other two measures.
- **Non-haven countries (Panel B):** Net Income shows downward bias; DI data shows little bias (consistent with the observation that non-haven affiliates hold fewer sub-affiliates, so equity income is less prevalent there).

#### 3.2.4 Semi-elasticity of tax base to tax rates (pp. 21–24)
The standard specification from Hines & Rice (1994):

$$\log(\pi_{it}) = \alpha + \beta_1 \tau_{it} + \beta_2 \log(K_{it}) + \beta_3 \log(L_{it}) + \beta_4 \chi_{it} + \mu_t + \epsilon_{it}$$

where $\pi_{it}$ is pretax income in country $i$ in year $t$; $K_{it}$ is tangible fixed assets; $L_{it}$ is employee wages; $\tau_{it}$ is the effective tax rate; $\chi_{it}$ includes GDP per capita and population; $\mu_t$ is a year fixed effect. The authors estimate over 32 years of data. The coefficient $\beta_1$ is the semi-elasticity — e.g., Beer et al. (2018) suggest a consensus of -0.98 (a 1% increase in tax rate leads to ~1% less pretax income reported).

The non-linearity found by Hines & Rice (1994) and later confirmed by Dowd et al. (2017) and Garcia-Bernardo & Janský (2021) involves including a squared tax term $\tau_i^2$. The positive coefficient implies income in lower-tax jurisdictions is more sensitive to rate changes. The authors find this non-linearity "is markedly less pronounced" when using Net Income Excluding Equity Income, and **disappears entirely once country fixed effects are included.**

Table 2, Panel A: Using Net Income or DI income, the sensitivity of income to taxes in havens is 4–5 times greater than in non-havens. Using Net Income Excluding Equity Income, this ratio falls to approximately 1.5 times. With country fixed effects and correct income measure, "there is no discontinuity between havens and non-havens."

Table 2, Panel C: Splitting the sample pre/post-2000, the non-linearity is pronounced for the post-2000 period when using DI income, but not when using Net Income Excluding Equity Income. This confirms the non-linearity is driven by the rise in equity income post-check-the-box, not by underlying profit shifting behaviour.

 

## 4. Significance of Measurement Issues: Illustrative Examples (pp. 24–30)

### 4.1.1 Clausing (2016) (pp. 24–26)
Clausing (2016) is the most prominent pre-TCJA revenue loss estimate, published in the *National Tax Journal*. The paper's methodology has three inputs: (i) foreign affiliate income, (ii) foreign ETRs, (iii) semi-elasticity. Each is affected by equity income.

Clausing herself recognised double counting as a concern but concluded "there is no simple correction for the double-counting" (Clausing 2020b). She used Net Income as an "upper bound" and DI income as a "lower bound." Both are shown to be flawed.

**Key results from the replication (Table A2):**

| Income measure | U.S. revenue loss estimate (2012) |
| | |
| Net Income (Clausing's upper bound) | $105bn (≈ $111bn in original, difference due to revised vs. preliminary BEA data) |
| Net Income Excluding Equity Income | **$11bn** |
| Direct Investment Income | $16bn |

The overstatement using Net Income is primarily driven by: (1) overstated income in the denominator, causing understated ETRs, (2) inflated semi-elasticities, and (3) the income mismeasurement feeding into the revenue calculation directly. "The overstatement of income being the largest source of bias."

Note: Clausing's original DI-based estimate of $77bn was also wrong due to a "gross-up error" in her calculation (described in detail in Appendix A). The corrected DI-based estimate is $16bn. As of 2020, Clausing removed this gross-up factor from her later work in response to this critique.

### 4.1.2 Guvenen, Mataloni, Rassier, and Ruhl (2019) (pp. 26–28)
This paper, an NBER Working Paper, argues that measured U.S. productivity is downwardly biased because profit shifting means profits generated in the U.S. are reported abroad. The authors use apportionment (based on payroll and assets) to reallocate DI income back to source countries, finding up to **8% of industry value-added** shifted out of the U.S., implying an annual productivity growth rate correction of **0.53% for 2000–2008.**

The critique by Blouin & Robinson: the apportionment exercise itself is "reasonable," but the interpretation is not. In Structure 3 (fully indirect ownership), the Netherlands holds $325 of DI income, of which $280 is German. Guvenen et al. will interpret the "excess" Dutch income as shifted from the U.S., when in fact it represents German earnings reported via equity method. The authors estimate that "approximately 75% of the income that Guvenen et al. (2019) considers U.S. tax base lost to tax havens represents equity income that should have been reattributed from a different source country." As a concrete example: approximately $9.8bn of Net Income Excluding Equity Income was earned in the Netherlands, yet the paper removes $77.9bn from the Netherlands (see Figure 6 in Guvened et al. 2019). The increasing reported reallocation over time is "related to an increase in equity income stemming from the increasing prevalence of indirect ownership, rather than from increasing profit shifting."

### 4.1.3 Tørsløv, Wier, and Zucman (2022) (pp. 28–30)
Published in the *Review of Economic Studies*. TWZ estimate that roughly **$616 billion of 2015 global profits** was shifted out of non-tax haven countries, with substantial revenue losses. The methodology benchmarks "normal" profits in tax havens using the profits-to-wage ratio of domestic vs. foreign-owned firms.

**What TWZ do right:** The primary measure of value-added income (from European Commission FATS, similar to BEA's Profit Type Return) does *not* suffer from double counting, as acknowledged by Blouin & Robinson. The "Reported Profits" measure of $11.209 trillion is not contaminated.

**The critique:** TWZ supplement their $310bn of profit shifting from value-added analysis with an additional **$306bn** of "missing profits" derived from bilateral comparisons of Direct Investment Income between inbound and outbound countries. This $306bn *does* rely on DI income, which includes equity income. Since TWZ attribute all bilateral DI discrepancies to tax havens, and since the largest discrepancies are in countries where U.S. MNEs report large equity income (Netherlands, Ireland, Luxembourg, Bermuda, Caribbean, Singapore), the bilateral discrepancies largely reflect accounting conventions, not missing profits.

**Result when $306bn imputed income is excluded:** Total shifted profits falls from $616bn to **$310bn**, and revenue losses to non-haven countries fall by roughly **50%**. "The missing income imputed by Tørsløv et al. (2022) is only 3% of the total value added by the corporate sector, its inclusion doubles the level of shifted profits."

Importantly, more than 70% of TWZ's bilateral discrepancy is attributable to comparisons involving U.S. outbound DI income — precisely because the U.S. uses the equity method while most counterpart countries do not report income beyond the first tier of affiliates. A statistician at CEPII, France confirmed in 2020 that "most countries in Europe do not have surveys as the U.S. or Germany that would allow them to trace reinvested earnings all along the chain of ownership."

TWZ's response was that the U.S. follows international statistical standards. Blouin & Robinson's counter: the issue is not whether the U.S. complies, but whether *other countries* report symmetrically. TWZ's own data shows that "almost all of this gap owes to the large gap between what these havens report paying to the U.S. and what the U.S. declares receiving from these havens." This is structurally expected if the U.S. uses equity method and counterparties do not.

 

## 5. Measurement Issues in Other Data Sources (pp. 30–37)

### 5.1 BEA data versus IRS data (pp. 30–37)

#### IRS Form 5471 (pp. 31–33)
IRS Form 5471 (Information Return of U.S. Persons With Respect to Certain Foreign Corporations) must be filed for each foreign affiliate more than 50% owned by U.S. shareholders. The SOI publishes aggregate assets, revenues, and Earnings & Profits (E&P) biennially. E&P approximates net income generated per affiliate, net of dividends paid — similar to the *cost method*.

Since 2010, SOI provides data on related party dividends to allow partial correction for double counting. Table 3, Panel A (2016 data): Aggregate foreign E&P without related party dividends is ~$285bn *higher* than BEA's Net Income Excluding Equity Income. The percentage of income in tax havens is 66% under gross E&P vs. 41% under BEA's Net Income Excluding Equity Income.

An additional problem unique to Form 5471: **disregarded entities** created via check-the-box regulations. If an entity is "disregarded," its income is aggregated with another legal entity in a different country. As a result, income is counted at the correct aggregate level but attributed to the wrong jurisdiction. "Dowd et al. (2017) explain that there is no way for researchers using the IRS Form 5471 to ascertain with certainty the income from disregarded entities and the countries to which it belongs." In contrast, BEA requires firms to report income based on where it is generated, even for disregarded entities.

Schedule C of Form 5471 (income statement) appears to suffer from the same AMNE-style mismeasurement (consolidation, equity, or cost method — no guidance provided). SOI does not publish net income from Schedule C in aggregate, making reconciliation impossible.

#### IRS Form 8975 — Country-by-Country Report (pp. 33–35)
Introduced in 2016 for taxpayers with >$850m in revenues (BEPS Action Item 13). Requires revenue, profits, income taxes, capital, accumulated earnings, employees, and tangible assets by jurisdiction. Unlike Form 5471, CbyCR attempts to address double counting from indirectly owned affiliates, and also requires reporting of disregarded entities by their actual location.

Table 3, Panel A: CbyCR data (2016) closely resembles Net Income Excluding Equity Income. However, this resemblance in 2016 was likely coincidental as filing was *voluntary* that year. In 2017–2019, CbyCR income outpaces both BEA data and audited financial statements — suggesting CbyCR continues to double count income, possibly due to intercompany dividends and the post-TCJA effects of the 2017 Tax Cuts and Jobs Act on dividend activity.

Remaining CbyCR problems: (1) stateless income category — income of conduit entities (partnerships) is reported as stateless but then re-reported by the partners in their jurisdiction, creating double counting; (2) countries give inconsistent guidance on whether affiliate dividends should be included. Horst & Curatolo (2020) estimate **14–23% of U.S. CbyCR income is double counted.** The UK government refused to publish detailed CbyCR data pending OECD resolution of these inconsistencies (Johnston 2020).

CbyCR allows use of audited financials, statutory reporting, managerial reporting, or regulatory reporting — inconsistent across firms and years.

#### Annual data comparisons (pp. 35–37, Table 3 Panel B)
Aggregate Compustat data (U.S. public companies' consolidated pretax foreign income and foreign tax expense) closely tracks BEA's Net Income Excluding Equity Income across 2008–2019, confirming the validity of that measure. E&P from Form 5471 consistently exceeds both, confirming double counting in that series.

 

## 6. Conclusions (pp. 37–38)

The main policy implication: "large estimates of those losses stem from the misunderstanding of an accounting convention." Tax reform enacted on the basis of these estimates is therefore "unlikely to raise the hundreds of billions of dollars in revenue that previous researchers have forecasted."

Summary of recommended corrections per data source:
- **BEA AMNE data:** Must exclude equity income to arrive at Net Income Excluding Equity Income. This is the only measure appropriate for jurisdiction-specific BEPS analysis.
- **BEA DI data:** Solves double counting but introduces income misattribution. Not suitable for jurisdiction-specific analysis.
- **IRS Form 5471:** Appears to suffer from both double counting and income misattribution; disregarded entities add a further location-attribution problem.
- **IRS Form 8975 (CbyCR):** Partial improvement but continues to double count; not yet reliable for BEPS analysis.
- **Bureau van Dijk (Orbis) / Bundesbank MiDi:** Authors call for future research to examine double counting and misattribution in these datasets.

Broader implications for international comparisons: methods for reporting indirectly owned affiliate income are **not comparable across countries.** Any study that attributes bilateral FDI asymmetries to tax-motivated profit shifting (as TWZ do) must control for differences in national accounting conventions.

 

## Appendix A — Replication of Clausing (2016) (pp. A1–A21 of the appendix, shown as pp. 55–76 in the PDF)

### Methodology
Clausing's approach has three inputs: (i) income, (ii) ETR, (iii) semi-elasticity. The semi-elasticity is used to compute "shifted income" (excess income in haven jurisdictions attributable to profit shifting). Total shifted income × U.S. ETR (30%) × 34% (share attributable to U.S.) × (1 + 60% for foreign MNE activity in U.S.) = U.S. revenue loss estimate.

### Semi-elasticities (Table A1)
Using 1983–2012 data, 8 specifications:
- Net Income: average semi-elasticity = **-3.07** (Clausing reports -2.92; difference due to revised vs. preliminary BEA data)
- Net Income Excluding Equity Income: average = **-2.36** (about 77% of the Net Income estimate)
- Direct Investment Income: average = **-2.09**

### Revenue loss for 2012 (Table A2)
The Netherlands example illustrates the computation: shifted income = $169bn × (30% - 2.7%) × (-3.07) = -$142bn. Using Net Income, total shifted income across all countries = $646bn, yielding a U.S. revenue loss of **$105bn**. Using Net Income Excluding Equity Income, total shifted income = $68bn, U.S. revenue loss = **$11bn**. Using DI income, total shifted = $100bn, U.S. revenue loss = **$16bn**.

Note on Clausing's original DI estimate of $77bn: This was due to an erroneous "gross-up assumption" unique to Clausing's methodology. The authors confirmed this with Clausing; she removed the gross-up in her 2020 papers as a result of this critique.

### Revenue loss updated to 2017 (Tables A3, A4)
Semi-elasticities rise when sample extended to 2017 (consistent with more aggressive profit shifting in the later years or, alternatively, with even more equity income). The 2017 U.S. revenue loss estimates:
- Net Income: **$183bn** — "With corporate tax revenues at around $300 billion, this would imply that 61 percent of U.S. corporate tax revenue is lost to profit shifting. This figure is implausible and is clearly a consequence of not excluding equity income."
- Net Income Excluding Equity Income: **$36bn** (~12% of corporate tax revenue)
- Direct Investment Income: **$38bn**

 

## Appendix B — Critique of Tørsløv, Wier, and Zucman (2022) (pp. B1–B36 of appendix)

### What TWZ do
TWZ estimate global shifted profits using: (a) profits-to-wage ratio comparison of domestic vs. foreign-owned firms (value-added measure, $310bn shifted), and (b) bilateral comparisons of DI income to impute $306bn of "missing profits" attributed to tax havens. Total = $616bn.

### The $306bn problem
The $306bn comes from DI income data and therefore includes equity income. The bilateral comparisons work as follows: if the U.S. reports $325 of outbound DI income to the Netherlands, but the Netherlands only reports $30 of inbound income from the U.S., TWZ attribute the $295 discrepancy to unreported profits hidden in the Netherlands. But $280 of the U.S.'s reported $325 is German income reported via equity method — it is not Dutch income at all. "The bilateral comparisons are more likely to overstate the income of the haven when there are greater levels of equity income attributable to a country's Direct Investment Income."

Of the $306bn: $108bn from EU haven bilateral discrepancies (primarily Netherlands, Ireland, Luxembourg) and $198bn from non-EU haven bilateral discrepancies. "Almost all of this gap owes to the large gap between what these havens report paying to the U.S. and what the U.S. declares receiving" — consistent with the equity method explanation. No such imbalance exists for MNEs domiciled in countries that do not use the equity method (e.g., an Ireland-headquartered MNE, illustrated in Figure B.2).

At least 70.3% of the imputed $306bn stems from comparisons of U.S. outbound DI income to counterparty inbound data (TWZ Table B.10).

### Table B.1
Replication of TWZ's Table 3, removing the imputed $306bn:
- Total shifted profits: $616bn → **$310bn**
- Revenue losses to non-haven countries: fall by ~50%
- U.S. revenue loss as share of tax base: 14% → **7%**
  (Falls further to **3.8%** if corrected ETRs are also used)

### Section 5.2: BEA Profit Type Return (PTR)
Since 1994, the BEA reports PTR = Net Income (before income taxes), *excluding* capital gains/losses, *excluding* equity income, excluding other non-operating income, plus an inventory valuation adjustment. PTR is conceptually similar to Net Income Excluding Equity Income and tracks closely with it in aggregate. However, PTR is not suitable for BEPS analysis because it excludes capital gains/losses, creating biased ETRs in certain jurisdictions (e.g., Netherlands, Bermuda — shown in Figure B.4). Clausing (2019) herself states PTR is "not suitable for estimating the overall size of profit shifting," yet Wright & Zucman (2018) and Saez & Zucman (2019) use it. These later Zucman papers also exclude the oil industry and include Puerto Rico as a haven, which partially masks the improvement relative to the DI income measure used in Zucman (2014, 2015).

 
