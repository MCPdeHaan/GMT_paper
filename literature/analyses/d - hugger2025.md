# Hugger, Gonzalez Cabral & O'Reilly (2025) — "Effective Tax Rates of MNEs and the Global Distribution of Low-Taxed Profit"
**International Tax and Public Finance (2025)**


## Abstract / Key Claim (p. 1)

- Debate on corporate profit taxation usually focuses on low-taxed profit in jurisdictions with low **statutory tax rates (STRs)** or low **average effective tax rates (ETRs)**
- However: affiliates in **high-tax jurisdictions** can also face low ETRs due to tax incentives or other provisions
- Prior work lacked a **global accounting of ETRs incorporating within-country heterogeneity**
- This paper uses new **Country-by-Country Reporting (CbCR)** data to estimate the **distribution** of ETRs and low-taxed profit **between and within** 222 jurisdictions
- Key finding: more than **half of total global low-taxed profit** (53.2%) is reported in jurisdictions that do **not** have an average ETR below 15%
- Estimated average annual low-taxed profit of large MNEs: **USD 2,143 billion**

## 1. Introduction (pp. 1–4)

### Motivation

- Standard empirical debate tends to split jurisdictions into "low tax" vs "high tax", ignores within-jurisdiction heterogeneity
- Four specific gaps in the existing literature:
  1. Firm elasticity estimates to tax often rely on jurisdiction-level tax rates; ignoring within-jurisdiction ETR heterogeneity can lead to **mismeasurement of firms' elasticities**
  2. Profit-shifting literature (e.g. Dowd et al. 2017; Clausing 2020; Fuest et al. 2022; Garcia-Bernardo & Janský 2024; Beer et al. 2020 for review) neglects the **"extent to which MNE affiliates generate low-taxed profit in high-tax jurisdictions"**
  3. Tax competition literature focuses on high vs. low tax jurisdictions — may miss that tax competition also leads to low-taxed profit **inside high-STR/high-average-ETR jurisdictions**
  4. Absence of global distribution data on low-taxed profit leads to **misleading policy reform estimates**

- Draws on **aggregated CbCR data** containing distributional moments of ETRs that MNEs face by jurisdiction
- Combines with average ETR estimates for **222 jurisdictions**
- Estimates full **within-jurisdiction ETR distributions** Advantage: better data than average effects that conceal heterogeneities. 
- Combines ETR distributions with **global profit data** to compute low-taxed profit globally

Data setbacks
- CbCR covers only MNEs with **revenues > EUR 750 million** (large MNEs only)
- Known **data quality issues**, especially for earlier years: double counting of intra-company dividends (Blouin & Robinson 2024) — paper develops correction methodology
- Some **imputations** required for comprehensive geographic coverage => downward corrections to profits
- CbCR still "best source available" for large MNEs across a broad set of jurisdictions

- ETR differs from STR and big variation across jurisdictions, average ETRs below 15% concentrated in investment hubs (definition: total inward FDI above 150% of GDP on average)

- Within-jurisdiction ETR dispersion often **larger than** cross-jurisdiction dispersion
- Estimated USD 2,143 billion of annual profit taxed below 15%; 53.2% in jurisdictions with average ETR **above** 15%

Contribution to literature
- Expands backward-looking ETR work (Mendoza et al. 1994; reviewed by Janský 2023)
- Firm-level ETR distribution work: Bachas et al. (2023) — 13 jurisdictions; Bilicka (2019)
- Tax expenditure literature: Abbas & Klemm (2013); Celani et al. (2022); González Cabral et al. (2023)
- Forward-looking ETR work (Devereux-Griffith 2003; reviews by Beer et al. 2020; Feld & Heckemeyer 2011)

## 2. Average Effective Tax Rates Across Jurisdictions (pp. 4–11)

### 2.1 Calculating Average ETRs (pp. 4–9)

- CbCR summarises global MNE activities (revenues > EUR 750 million) broken down by jurisdiction into **"subgroups"** (all entities of an MNE group in one tax jurisdiction)
- Individual CbCRs submitted to the UPE (ultimate parent entity) jurisdiction's tax authority
- Aggregated CbCR statistics collected and published annually by the OECD
- Dataset covers up to **52 UPE jurisdictions** and **211 affiliate jurisdictions** per year
- Information reported separately for subgroups with positive/negative profits, and combined

- Focus on **profit-weighted average ETRs** across all affiliates in a jurisdiction (regardless of UPE nationality) — accounts for potential non-representativeness of bilateral ETRs
- For jurisdictions with few MNEs in CbCR: supplement with additional sources
- **Correct for double counting of dividends in UPEs** (Blouin & Robinson 2024; OECD 2020a): double counting inflates UPE profits, leading to artificially low ETRs
  - Corrections based on information directly from tax authorities **or** by comparing ETRs of domestic vs. foreign MNE affiliates within same jurisdiction (foreign entities less likely affected by double counting)
  - Percentage reduction **capped at 55.5%** (maximum correction from tax authorities; roughly 80th percentile of estimated corrections)
  - Applied to **around two thirds** of UPE profit values; median correction = **32.4%**
  - Corrections larger in earlier years (2017–2018), consistent with gradual data quality improvement
  - Residual issues remain (e.g. affiliate-to-affiliate conduit payments not corrected); may result in **downward-biased ETRs** in some cases
- Outlier removal: ~3% of observations excluded; top and bottom 5 percentiles of bilateral ETR distribution dropped
- 2016 CbCR vintage entirely excluded due to data quality; flagged data points also excluded (OECD 2022 guidance)
- CbCR based on **accounting profits** (not taxable profit) — this allows cross-country comparability but diverges from taxable income (Desai 2005; Shackelford & Shevlin 2001 show accounting profits typically larger than taxable profits); footnote 3 notes ETRs here differ from GloBE ETRs used for GMT revenue estimation
- CbCR data for FY 2017-2020, reported on MNE subgroups with positive profits, 20,000 MNE/year observations and 100,000+ MNE subgroups
- Could be inflkaktekkd data before 2020, due to double counting

- Goal: approximate ETR across the **business cycle** (some years profit, some losses), not adjusting for losses would lead to downward bias in ETRs and not reflect tax treatment of losses
- Positive profits adjusted downward by the **typical share of losses** observed in that jurisdiction
- Example (footnote 7): profit 100, taxes 20 (year 1); loss 15, no taxes (year 2) → ETR on net profit = 20/(100−15) = 24%, not 20/100 = 20%
- Loss-adjusted ETRs also reflect generosity of actual loss offset rules
- Median adjustment: **11.8%** reduction of positive profits; varies strongly across jurisdictions
- Investment hubs: median adjustment **18.1%** vs. **11.6%** for non-hubs — may reflect risk-shifting to hubs (Becker et al. 2020)

- Bilateral ETR = income tax accrued / loss- and double-counting-adjusted profits (= net tax base)
- **Tax accrued** used (not tax paid) as it reflects the current tax expense on the year's profits (footnote 4)
- Taxes accrued negative in ~5% of observations → ETRs bounded at zero
- ETRs allowed to exceed STRs (incomplete loss offset can cause this), but capped based on average impact of loss adjustment at jurisdictional level (footnote 9)
- Final bilateral dataset: **8,386 bilateral ETRs** at UPE-affiliate-year level, based on **>265,000 MNE subgroup-year observations**, covering **211 affiliate jurisdictions** and **52 UPE jurisdictions** (2017–2020)


Estimating jurisdictional ETRs
- Profit-weighted average across bilateral ETRs for each affiliate jurisdiction
- Assumption: domestic tax system does not discriminate by UPE nationality -> ETRs should not vary systematically by UPE jurisdiction
- Final ETR = unweighted average across years 2017–2020 (to reduce time-series volatility)
- **Exception**: if STR changes by more than 1 percentage point, ETRs only averaged across years without the large change (~5% of jurisdictions per year affected) — footnote 11
- Year-to-year correlation of ETRs: 0.82 on average; annual medians stable (17.2%, 17.2%, 16.2%, 17.0%)

Supplementory data

- **BEA (US Bureau of Economic Analysis)**: ETRs for US MNEs in up to 55 affiliate jurisdictions; numerator = foreign income taxes (Table II.D1); denominator = profit-type return (Table II.F1) — footnote 12
- **TWZ (Tørsløv, Wier & Zucman 2023)**: ETRs based on macro data and assumptions, foreign-owned MNEs, 78 jurisdictions for 2017–2019
- Both BEA and TWZ aggregate profitable and loss-making subgroups → comparable to loss-adjusted CbCR ETRs
- **Regression-based imputation** for remaining gaps: regressors include STR, zero-tax incentive dummy, FDI/GDP ratio, STR × FDI/GDP interaction, log(GDP), log(population), region fixed effects, year fixed effects (see Appendix 2 for full results)

**Rank order for data source selection (per jurisdiction):**
1. CbCR if based on >20 MNE subgroups
2. Blend of CbCR and BEA/TWZ if <20 subgroups (weight proportional to number of subgroups)
3. BEA/TWZ if no CbCR
4. Blend of CbCR and regression imputation if CbCR insufficient and BEA/TWZ unavailable
5. Regression-only if none of the above available

**Coverage:**
- CbCR alone: **81.0%** of jurisdictions (up to 183), representing **99.6% of GDP** and **99.9% of total profit**
- 44 jurisdictions without sufficient CbCR account for only **0.4% of global GDP** and **0.1% of total profit**

### 2.2 Average ETRs across jurisdictions: results (pp. 10–11)

- 222 jurisdictions backward looking ETRs 2017-2020
- **Global median ETR: 16.4%**, but with range from 0% to 35+%
- **18 jurisdictions** have average ETR of zero; **17 jurisdictions** have ETR strictly between 0% and 5%
- **125 jurisdictions (56.3%)** have average ETR **above 15%**
- **31 jurisdictions** have average ETR exceeding **25%**

- **ETR vs. STR:** Positive correlation (coefficient: **0.69**), ETRs on average **6.9 percentage points below** STRs, ETRs **exceed STRs in ~10%** of jurisdictions (limited loss offset in jurisdictions with high loss shares)

## 3. The distribution of effective tax rates within jurisdictions (pp. 11–19)

- Average ETRs mask heterogeneity across firms 
- Sources of within-jurisdiction (thus across firms) heterogeneity: different firm circumstances; patent boxes, R&D credits (common in higher-income jurisdictions); tax exemptions, tax holidays (common in lower-income jurisdictions); targeted at specific sectors/regions/firm types (Celani et al. 2022)

### 3.1 Estimating ETR distributions (pp. 11–17)

#### 3.1.1 New Data Source

- Gathered data on **selected percentiles** (typically 5th, 25th, 50th, 75th, 95th) of ETR distributions at UPE-affiliate level from CbCR tax authorities
- Some authorities only provide subset due to confidentiality
- **Up to 30 UPE jurisdictions per year**, 2017–2020, covering **>180 affiliate jurisdictions**
- "Data have not been used for research before"
- Now available as part of **OECD Corporate Tax Statistics**
- Strict data cleaning:
  - Exclude if percentiles not in logical sequence (e.g. p5 > p25)
  - Exclude if lowest available percentile is in bottom or top 5% of all observations of that percentile
  - Exclude if highest available percentile is in bottom 5% or top 10% of all observations (asymmetric — unreasonably high ETRs relatively frequent; footnote 16)
- After cleaning: **3,173 observations** at UPE-affiliate-year level for p50, covering **183 unique affiliate jurisdictions**, based on **>75,000 MNE subgroup-year observations**

#### 3.1.2 Constructing Full Set of Distribution Points

- Jurisdictional distribution points = weighted averages of bilateral UPE-affiliate observations, weighted by number of subgroups; UPE jurisdiction data only included if unlikely affected by double counting (footnote 17)
- For **median (p50)**: regression imputation using average ETR as covariate (see Appendix 2); CbCR used alone if >20 subgroups, blended with regression if fewer; covers 222 jurisdictions
  - Imputations used for **42.3% of jurisdictions**, but CbCR directly covers **97.7% of GDP** and **98.5% of total positive profit**
- For **other percentiles (p5, p25, p75, p95)**: focus on typical percentage-point **distance** from median
  - Jurisdictional-level distance used if sufficient CbCR data (>20 subgroups)
  - If <20 subgroups: blend with income-group average distance
  - If no CbCR: income-group average only
  - Lower and lower-middle income combined for income-group averaging (small N); distances multiplied by **factor 1.5** for these groups to account for larger variance (footnote 19)
  - Imputations contribute in **42–45% of jurisdictions** but those only represent a very small share of GDP and profit

**Density assumptions between percentiles (Fig. 5):**
- Uniform distribution of ETRs over profit **between** the five percentiles
- All ETRs below p5 **assumed equal to p5**; all above p95 **assumed equal to p95**
- Second assumption has little binding impact since ETRs already capped at zero and STR (+loss adjustment)
- This implies results may be "somewhat compressed" → **conservative** estimate of low-taxed profit

#### 3.1.3 Shifting the distribution

- Distribution from step above: based on positive profits, defined across subgroups
- Average ETRs from Section 2: corrected for losses and profit-weighted
- To align: **shift entire ETR distribution** up or down until mean matches profit-weighted, loss-adjusted average ETR from Section 2
- Most shifts are **upward** (reflecting loss adjustment)
- Median difference before shifting: **4.3 percentage points** (distribution-implied average vs. Section 2 average)
- After shifting: difference is zero by construction
- Resulting distribution still bounded at zero; allowed to exceed STR to extent of loss adjustment

**Differential treatment by jurisdiction type:**
- Jurisdictions **with "zero-tax" incentives** (tax holidays, full CIT exemptions with broad availability — see Table 6, Appendix 4): shifting concentrated at **highest percentiles**, preserving **bimodal distribution** (substantial mass taxed at zero AND substantial mass near STR); this is because MNEs unlikely to allocate losses to zero-tax entities
- Jurisdictions **without "zero-tax" incentives**: low ETRs likely driven by **loss offset provisions** → shifting concentrated at **lower end** → **more compressed** distribution

### 3.2 ETR distribution within jurisdictions: results (pp. 17–19)

**Overall distribution points (medians across jurisdictions, Fig. 6):**
- p5: **0.8%** (heavily concentrated at low ETRs)
- p25: below **7.1%** for more than half of jurisdictions
- p50: **20.5%**
- p75: **22.9%**
- p95: **24.2%** (clearly above 15% in most cases; single digits for a small number of jurisdictions)

**Zero-tax incentive jurisdictions vs. others:**
- Jurisdictions with zero-tax incentives: median p5 = **0%** vs. **5.4%** without
- Medians for p50, p75, p95 comparable between the two groups — confirms strong **bimodal distribution** with zero-tax incentives

**Within-jurisdiction dispersion vs. cross-jurisdiction dispersion:**
- Distance between p5 and p95 **exceeds 10 percentage points** for ~80% of jurisdictions
- Distance **exceeds 20 percentage points** for more than half (median = **20.2 ppts**)
- Majority of jurisdictions with smaller distance are **zero-tax** jurisdictions
- Largest distances: low income (median **28.0 ppts**), lower middle income (**24.3 ppts**)
- Investment hubs: more compressed (median **5.8 ppts**), partly because of lower STRs
- Jurisdictions with generous incentives: median **23.1 ppts** vs. **17.4 ppts** without
- Distance **asymmetric**: distance between p5 and median accounts for **~three quarters** of total dispersion; p75 to p95 only one quarter → tax incentives (reducing ETRs at the low end) drive dispersion, not outliers at the top

## 4. The Global Taxation of MNE Profits (pp. 20–26)

### 4.1 Estimating the Global Distribution of MNE Profit (pp. 20–21)

- Builds on **OECD (2020b)** methodology, combining CbCR, Orbis firm-level data, and macroeconomic imputations (FDI statistics) 
- Limitations acknowledged: extrapolations are imperfect proxies; Orbis coverage varies; double-counting corrections remain estimates; lower-income jurisdictions more reliant on imputations

**Total estimated profits:**
- Global net profits of large MNEs (2017–2020): **USD 23,715 billion total**, or **USD 5,929 billion per year**

**Distribution by income group (Panel A, Fig. 9):**
- High income: **50.1%**
- Upper middle income: **27.7%**
- Investment hubs: **18.8%**
- Lower middle income + low income: small shares

**Concentration:**
- **5 affiliate jurisdictions** account for **48.1%** of total
- **20 affiliate jurisdictions** account for ~**80%** of total
- Bottom 111 jurisdictions (half of sample): only **0.6%** of total

**Distribution by average ETR group (Panel B, Fig. 9):**
- ETR 15–25%: **68.9%** of profit
- ETR > 25%: **9.7%**
- ETR < 5%: **6.8%**
- ETR 5–15%: **14.6%**
- Key implication: **most profit is in medium-ETR jurisdictions**, not in classic low-tax jurisdictions

### 4.2 Distribution of Global Profits by Effective Tax Rate (p. 22)

- Profit-weighted average global ETR: **19.1%** (2017–2020)
- About **half** of large MNE profit taxed at rates between **15–30%**

**From USD 5,929 billion annual net profit:**
- **12.7% (USD 753 billion)** taxed below 5%
- **23.4% (USD 1,390 billion)** taxed at ETR 5–15%
- Only **4.6% (USD 272 billion)** taxed above 35%

**By income group (Fig. 10):**
- High income and upper middle income: only ~5% of profits taxed above 35%
- Lower middle and low income: 23.2% and 27.3% taxed above 35%
- Investment hubs: **79.4%** taxed at less than 15%; virtually nothing above 25%

**By average ETR group (Fig. 11):**
- Jurisdictions with average ETR 15–25%: **26.1%** of profit taxed below 15%
- Jurisdictions with average ETR >25%: **13.0%** of profit taxed below 15%
- "Ignoring low-taxed profit in jurisdictions with high average ETRs can lead to a substantial underestimation of global low-taxed profit"

### 4.3 Global Low-Taxed Profit (pp. 23–26)

**Definitions:**
- Low-taxed: ETR < 15%
- Very low-taxed: ETR < 5%

**Headline figures (from USD 5,929 billion annual net profit):**
- Very low-taxed: **USD 753 billion (12.7%)**
- Low-taxed: **USD 2,143 billion (36.1%)**

**Distribution by income group (Panel A, Fig. 12):**
- Very low-taxed: **79.9%** in investment hubs; **13.5%** in high-income jurisdictions; upper middle income 4.1%; lower middle income 2.4%
- Low-taxed: quite different from above — **close to 60%** reported **outside** investment hubs; high-income jurisdictions account for **38.6%** vs. **41.4%** in hubs — nearly equal shares

**Distribution by average ETR group (Panel B, Fig. 12):**
- More than **half of very low-taxed profit** is in jurisdictions with average ETR **above 5%**
- ~10% of very low-taxed profit in jurisdictions with average ETR **above 15%**
- Jurisdictions with average ETR above 15% account for **more than half (53.2%)** of all profit taxed below 15%
- "An assessment of global low-taxed profit that focuses only on jurisdictions with low average tax rates could potentially not account for more than half of global low-taxed profit"

**Concentration of low-taxed profit:**
- Top 20 jurisdictions: **>80%** of total low-taxed profit
- Top 20 jurisdictions: **~90%** of very low-taxed profit (more concentrated)
- But the ranking of jurisdictions differs from total profit ranking: investment hubs more prominent in low and very low-taxed rankings

**Prevalence:**
- **~95%** of jurisdictions have some low-taxed profit
- On average, **49.8%** of MNE profit in a jurisdiction is taxed below 15%
- **~75%** of jurisdictions have some very low-taxed profit; average 27.9% of profit taxed below 5%

**Relationship between average ETR and low-taxed profit share (Fig. 14):**
- Correlation between average ETR and share of very low-taxed profit: **−0.86**
- Correlation between average ETR and share of low-taxed profit: **−0.93**
- Strong negative relationship, but key finding is the substantial **dispersion** around this trend — many high-average-ETR jurisdictions still have significant low-taxed profit
- Relying on STRs to identify low-taxed profit "can be even more misleading" — no strong relationship between STRs and low/very low-taxed profit shares (Fig. 17 in Appendix 1)

## 5. Conclusion (pp. 26–27)

- Within-jurisdiction ETR dispersion often **larger** than across-jurisdiction dispersion
- Low-taxed profit in high-tax jurisdictions is substantial and "often overlooked" — more low-taxed profit in high-tax than in low-tax jurisdictions
- **Policy implication for GMT:** domestic minimum taxes (Qualified Domestic Minimum Top-up Tax) could raise considerable revenue **not only in low-average-ETR jurisdictions but also in jurisdictions with rates above the minimum tax** — directly relevant for GMT design
- Data limitations: aggregated CbCR; only MNEs > EUR 750 million; corrections for double counting are estimates only; results remain estimates
- Authors call for further research on: global MNE taxation, drivers of low-taxed profit patterns, impact of corporate tax reform nationally and internationally

---

## Appendix 1 (p. 28): Summary Statistics

**Table 2 — Summary Statistics on Jurisdictional Average ETRs:**
- Panel C (averages 2017–2020): Mean ETR = **15.44%**, Median ETR = **16.37%**, Min = 0%, Max = **36.15%**, SD = 9.05%
- Mean STR = **22.36%**, Median STR = **25.00%**

**Table 3 — Summary Statistics on ETR Distribution Points (Panel C, averages):**
- P5: mean 3.88%, median **0.78%**
- P25: mean 8.88%, median **7.12%**
- P50: mean 18.22%, median **20.48%**
- P75: mean 21.71%, median **22.92%**
- P95: mean 22.81%, median **24.22%**

---

## Appendix 2: Regression Models (pp. 28–30)

### Average ETR Regression:

$$ETR_{it} = \alpha + \beta_1 STR_{it} + \beta_2 ZeroTaxIncentive_i + \beta_3 FDIratio_{it} + \beta_4 STR_{it} \times FDIratio_{it} + \beta_5 \log GDP_{it} + \beta_6 \log Population_{it} + \vartheta(i) + \theta_t + \varepsilon_{it}$$

- *ZeroTaxIncentive* = 1 if jurisdiction has broadly available tax holiday or full CIT exemption resulting in zero CIT (list in Table 6, Appendix 4)
- *FDIratio* winsorised at 95th percentile; interaction term captures that STR may be less relevant in high-FDI hubs
- Log(GDP) and log(population) capture that larger economies may sustain higher tax burdens (Haufler & Wooton 1999)
- Region and year fixed effects
- Weighted by number of MNE subgroups

**Results (Table 4, column 1):** R² = 0.721; STR coefficient = 0.571***; ZeroTaxIncentive = −0.025***; FDI ratio = 0.012***; STR × FDI ratio = −0.154***

### Median ETR Regression:

Same specification plus **average ETR** as additional covariate (coefficient = 0.527***); R² = 0.743

## Appendix 3: Profit Data Methodology (pp. 31–38)

- Follows **OECD (2020b)** (originally for 2016 data); updated with new CbCR vintages, Orbis data, macroeconomic extrapolations
- **222 × 222 bilateral profit matrices** constructed (UPE × affiliate jurisdiction); collapsed at affiliate level
- **Data sources (Fig. 19):** CbCR = 7.5% of cells but **85.3% of total profit**; extrapolations fill 54.8% of cells but small profit share; Orbis = 2.6% cells
- **Double counting correction** for UPE profits: capped at 55.5%; for zero-tax jurisdictions, median correction applied (double counting doesn't affect ETR numerator but can inflate profit totals); total reductions: USD 2,420 billion (jurisdictional data) + USD 2,110 billion (estimated corrections) over 4 years
- Loss adjustment: median = **11.8%** of positive profits; total loss adjustment = **16.5% of total positive profit**, or ~USD 1,180 billion per year
- Robustness of average ETR estimation (Fig. 21): correlation between baseline (loss-adjusted) and all-subgroups ETR = **0.97**; median ETR 16.4% (baseline) vs. 16.6% (all subgroups); no-loss-adjustment median is **2.2 ppts lower**

## Appendix 4: Jurisdiction Group Definitions (pp. 39–42)

- **Income groups**: World Bank classification 2019 (Table 5)
- **Investment hubs**: inward FDI/GDP > 150% on average 2017–2020 (OECD International Direct Investment Statistics + IMF CDIS + extrapolations from OECD 2020b)
  - Manual adjustments: Mozambique and Mongolia **removed** (high FDI driven by natural resources); Puerto Rico **added** (FDI ratio does not adequately reflect US investment)
  - Investment hubs list includes: Anguilla, Bahamas, Bailiwick of Guernsey, Barbados, Bermuda, British Virgin Islands, Cayman Islands, Curaçao, Cyprus, Gibraltar, Hong Kong (China), Hungary, Ireland, Isle of Man, Jersey, Liberia, Luxembourg, Malta, Marshall Islands, Mauritius, Netherlands, Puerto Rico, Singapore, Switzerland
- **Zero-tax incentive jurisdictions** (Table 6): classified using OECD Investment Tax Incentives Database (Celani et al. 2022), EY Worldwide Corporate Tax Guides, PwC Worldwide Tax Summaries, and other public sources — full list in Table 6 (extensive, includes e.g. Bahamas, Bermuda, Cayman Islands, Ireland, Jersey, Luxembourg, Netherlands, Singapore, Switzerland, UAE, among many others)
