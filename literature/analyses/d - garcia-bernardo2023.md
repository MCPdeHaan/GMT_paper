# Garcia-Bernardo, Janský & Tørsløv (2023) Effective Tax Rates of Multinational Corporations: Country-level Estimates
PLOS ONE, 18(11), e0293552


## p. 1 — Abstract & Introduction

Abstract (key points):
- Paper proposes a new methodology to estimate backward-looking effective tax rates (ETRs) from Orbis unconsolidated data, 2011–2015 period
- Focus on countries with at least 50 available companies → 47 mostly European countries
- ETR defined as: ratio of corporate income tax to gross income, for all MNC affiliates in a country, weighted by gross income
- Four ETR estimations proposed: two point estimates + lower bound (ETR3) + upper bound (ETR4), differing by gross income calculation
- Main finding: ETRs substantially differ from statutory tax rates; Luxembourg (statutory 29%) pays as little as 1–8% of gross income in taxes; Norway (statutory 28%) pays as much as 46–67%
- Call for better data: MNCs' unconsolidated, public country-by-country reporting (CbCR) data

Introduction:
- MNC tax avoidance contributes to inequalities both between and within countries — profit shifting to tax havens reduces revenues elsewhere (ref [1] Clausing 2016; [2] Nerudova et al. 2023); tax burden can be transferred to other taxpayers (ref [3] Bilicka/Dubinina/Janský 2023)
- This motivated the OECD two-pillar proposal, agreed by 100+ countries in 2021 (ref [4] OECD 2019)
- Pillar 1 (ref [5]): redistributes some MNC profits according to economic activity — similar to EU proposals CCCTB (ref [6]), BEFIT (ref [8]), or global unitary taxation proposals (ref [9])
- Pillar 2: ensures MNCs pay a minimum ETR of 15% in each implementing country (ref [5])
- December 2022: EU agreed Pillar 2 mandatory for all member states from 2024
- Problem: "it is not clear how much MNCs pay in taxes now" — motivates the paper



## p. 2 — Introduction (continued)

Two conceptually different ETR approaches in existing literature:

1. Forward-looking ETRs: based on hypothetical company models using existing legislation (ref [10] Devereux/Griffith 1999; [11] Devereux/Griffith 2003)
   - Estimated for EU member states (ref [12]), G20 (ref [13]), OECD (ref [14])
   - Policy-useful and research-useful
   - Limitation: based on hypothetical modelling, not actual MNC behaviour → "unsuitable for determining the actual tax rate that MNCs pay in a country"

2. Backward-looking ETRs (= focus of this paper): use data from existing companies
   - Other relevant data sources besides Orbis: Form 5471 (ref [15]), Compustat (ref [16], [17], [18]) — reviewed comprehensively in Janský (2023) (ref [19])
   - Currently no "reliable and continuously-updated databases of ETRs estimated using company data are currently available"
   - Problems: data-related (poor accuracy, limited coverage) and methodology-related (no consensus on how to estimate ETRs)

Novelty of paper:
- First paper explicitly dedicated to estimating ETRs from Orbis for many countries using thorough methodology
- Not novel in identifying which countries (e.g. Luxembourg) have low ETRs — prior work exists (ref [20] Huesecken/Overesch 2019; [21] Tørsløv/Wier/Zucman 2022; [22] Keller/Schanz 2013; [23] Ates et al. 2021) — but novel in showing "how low these ETRs are"
- Compares backward-looking ETRs with one set of forward-looking ETRs from OECD (ref [24] Hanappi 2018)
- Results relevant for Pillar 2: indicate which countries might be affected by the 15% minimum tax



## p. 3 — Data (Section 2)

Data source: Orbis (Bureau van Dijk)
- Commercial product, one of the best available company-level datasets
- Coverage from mid-2000s, some data from 1980s
- Contains both consolidated and unconsolidated data
- Unconsolidated data used here because: allows estimating ETRs for individual affiliates and thus for individual countries
- Consolidated data cannot be disaggregated by country → not used in this paper
- Previously used for profit shifting research: Huizinga/Laeven (2008) (ref [37]); Barrios/d'Andria (2020) (ref [38])

Important Orbis caveat: "financial, rather than tax, reporting" — relevant literature on book-tax conformity for MNCs: Hanlon/Maydew (2009) (ref [39]), Graham/Raedy/Shackelford (2012) (ref [40])
- Bilicka (2019) (ref [41], AER) shows that using accounting data overestimates the ratio of taxable profits to total assets for foreign MNC affiliates in the UK — important methodological caveat for the whole paper



## p. 4 — Data (continued): Sample Construction

Orbis version accessed December 2017; best five-year period: 2011–2015 (2016 had poor coverage)
- Five-year period chosen to allow tax credits from losses to offset tax liabilities

Key Orbis variables used:
- Profit: "P/L before Tax"
- Tax: "Taxation"
- Operating profit: "Operating P/L [= EBIT] (= P/L before Tax – Financial profit)"
- Financial revenue: "Financial revenue"
- Financial expenses: "Financial expenses"

Sample construction (Table 1 — stepwise):

Starting sample: 15,684,360 companies / 60,400,740 observations (2011–2015)
- MNC affiliates (defined by global ultimate owner [GUO] having affiliates in more than one country): 1,682,851 companies / 5,915,908 observations (100%)
- Step 1 — drop financial companies (keep Orbis type "C" corporate): 794,914 / 2,617,019 remaining (47.2% / 44.2%)
- Step 2 — keep only private and public limited companies (drop mainly partnerships): 533,046 / 1,818,415 remaining (31.7% / 30.7%)
- Step 3 — drop company if negative profits in 2010 (to remove carry-forward loss effects): 489,199 / 1,654,808 remaining (29.1% / 30.0%)
- Step 4 — drop last observation if negative profits (robustness check shows broadly similar results without this, see Table A1): 272,321 / 905,255 remaining (16.2% / 15.3%)
- Step 5 — drop companies with negative profits or taxes for entire period; drop companies with ETR > 1; aggregate by affiliate: final sample 198,527 affiliates (11.8%)

Rationale for restrictions:
- Goal is to calculate "the ETR paid by MNCs in normal business circumstances" — mostly profitable — not the average ETR of all affiliates (including those affected by losses)
- Carry-forward losses can produce "positive taxation, i.e., taxes received rather than paid" → distorts ETR
- Dropping obs with negative taxes might inflate ETRs; dropping ETR > 1 might deflate ETRs — acknowledged limitation

Final sample: 47 countries with data for at least 50 companies (out of 93 with at least one company in Orbis)
- Includes all EU member states
- Does NOT include the US: only one US company in Orbis



## p. 5 — Data (continued): Orbis Limitations & Other Sources

Additional Orbis limitations (discussed in refs [42]–[50]):
- Coverage not universal, differs by country — "biased against tax havens and developing countries"
- Even for included companies, available information is limited
- Tørsløv/Wier/Zucman 2022 (ref [21]): only a "weighted average of 17% of global (consolidated) profits is included in the unconsolidated accounts"
- Cannot account for country-specific tax system characteristics (e.g. deferred taxes of low quality; Malta allows up to 6/7 of corporate tax paid to be claimed as refunds to shareholders)
- "Any results based on this database, including ours, are limited; as such, they should not be used as the only evidence base for policymakers' decisions"
- Detailed country-specific sources like Dafne (Germany) provide more detailed financial profit information

Other data used:
- Statutory corporate income tax rates: primarily from KPMG corporate income tax database (ref [51]), supplemented by Janský/Palanský (2019) (ref [52])
- Note: "headline statutory rates" = the most frequently applied or highest applicable statutory rate — imperfect comparison
- Forward-looking ETRs from OECD (ref [24] Hanappi 2018), available for 2017, in three scenarios: low, high, country-specific interest and inflation rates



## p. 6 — Methodology (Section 3): ETR Definitions

Core logic: for each MNC affiliate → ETR = corporate income tax / gross income. Then: gross income-weighted mean of ETRs across all affiliates in one country → country-level ETR.

Central data challenge: gross income is "not unambiguously available in the data"
- Ideal gross income: operating profit + corporate income taxes + interest income (and other income like royalties, but NOT equity income)
- Interest is generally taxable → should be in gross income denominator
- Equity income is generally NOT taxable → should be excluded
- Orbis provides only: financial revenue, financial expenses, and financial profit (= revenue minus expenses)
- Each of these three variables "lumps together both interest and equity income"
- Separate variable for interest paid exists but not used (no variable for interest received available)

Solution: four ETR versions

ETR1 (preferred point estimate):
- Denominator: operating profit + financial profit (= operating profit + financial revenue - financial expenses)
- Includes equity income (should ideally be excluded, not taxable) → upward bias on denominator
- "Preferred version since many affiliates have substantial interest expenses, but no substantial equity income" (ref [53] OECD/G20 Inclusive Framework Economic Analysis and Impact Assessment 2020)

ETR2 (alternative point estimate):
- Denominator: operating profit only
- Excludes all financial revenue and expenses → also excludes taxable interest income → downward bias on denominator
- Formula: ETR1_it = Σ CIT_it / Σ(Operating profit + Financial profit)_it
- Formula: ETR2_it = Σ CIT_it / Σ(Operating profit)_it

Note: because interest and equity income can be positive or negative, ETR1 can be higher or lower than ETR2 — ETR1 is lower than ETR2 for 29 of 47 countries (Table 2)

ETR3 (lower bound):
- Denominator: operating profit + financial revenue (largest possible denominator → lowest ETR)
- Financial revenue always positive → denominator highest of four versions → ETR ≤ true ETR
- Formula: ETR3_it = Σ CIT_it / Σ(Operating profit + financial revenue)_it

ETR4 (upper bound):
- Denominator: operating profit − financial expenses (smallest possible denominator → highest ETR)
- Financial expenses always positive → denominator lowest of four versions → ETR ≥ true ETR
- Formula: ETR4_it = Σ CIT_it / Σ(Operating profit − financial expenses)_it

Additional note: ETR2 and ETR4 are NOT vulnerable to potential double-counting of profits for holding companies (concentrated in Netherlands and Luxembourg) — because financial revenue is not in their denominator. References on double-counting: Blouin/Robinson (2020) (ref [54]); Clausing (2020) (ref [50]); Garcia-Bernardo/Janský/Zucman (2022) (ref [55]); Tørsløv/Wier/Zucman (2022) (ref [21])

Mean vs. median: mean is headline estimate (as is common in literature), but medians also reported
- For most countries median > mean, consistent with Wier/Erasmus (2022) (ref [56]) who show large companies engage disproportionately in profit shifting

Sample differences: different data samples used for each of the four ETR versions (because availability of individual variables differs)
- Estonia: 500+ companies for ETR1 and ETR2, zero for ETR3 and ETR4
- Singapore: 500+ companies for ETR1, zero for ETR2–ETR4



## pp. 7–9 — Table 2: Effective Tax Rates (Full Results Table)

Table 2 presents mean ETRs, median ETRs, and number of companies across all four versions, for all countries in the dataset (including countries with < 50 companies, marked *)

Selected key entries (from the main 47-country sample, ETR1–ETR4 mean values):

- Luxembourg (EU, statutory 29.1%): ETR1 2.2%, ETR2 7.3%, ETR3 1.3%, ETR4 8.2% → n = 620/424/700/334
- Belgium (EU, statutory 34%): ETR1 13.3%, ETR2 21.6%, ETR3 6.8%, ETR4 29.2% → n = 5,670
- Netherlands (EU, statutory 25%): ETR1 12.3%, ETR2 29.6%, ETR3 9.2%, ETR4 33.5% → n = 2,205
- France (EU, statutory 33.3%): ETR1 16.2%, ETR2 31.0%, ETR3 12.1%, ETR4 34.2% → n = 12,764
- Germany (EU, statutory 29.5%): ETR1 19.6%, ETR2 23.7%, ETR3 14.8%, ETR4 27.8% → n = 7,728
- Ireland (EU, statutory 12.5%): ETR1 16.1%, ETR2 15.4%, ETR3 14.3%, ETR4 19.1% → n = 926
- Norway (Other Europe, statutory 27.6%): ETR1 52.6%, ETR2 62.0%, ETR3 46.0%, ETR4 67.1% → n = 4,510
- Bulgaria (EU, statutory 10%): ETR1 9.6%, ETR2 8.4%, ETR3 5.6%, ETR4 10.9% → n = 790
- Hungary (EU, statutory 19%): ETR1 9.2%, ETR2 11.6%, ETR3 5.9%, ETR4 17.4% → n = 1,589
- Italy (EU, statutory 31.4%): ETR1 29.8%, ETR2 36.2%, ETR3 24.1%, ETR4 41.4% → n = 9,880
- UK (Other Europe, statutory 22.8%): ETR1 13.7%, ETR2 22.7%, ETR3 12.0%, ETR4 22.9% → n = 10,033
- Japan (statutory 37.2%): ETR1 29.7%, ETR2 36.2%, ETR3 28.6%, ETR4 39.2% → n = 7,542
- North Macedonia (Other Europe, statutory 10%): ETR1 5.3%, ETR2 8.3%, ETR3 4.2%, ETR4 8.1% → n = 137
- Bosnia & Herzegovina (Other Europe, statutory 10%): ETR1 7.0%, ETR2 7.1%, ETR3 6.4%, ETR4 7.7% → n = 274
- Serbia (Other Europe, statutory 13%): ETR1 7.7%, ETR2 7.3%, ETR3 5.7%, ETR4 10.3% → n = 680
- Estonia (EU, statutory 20.8%): ETR1 14.1%, ETR2 14.6% only (n = 551/544; ETR3/4 unavailable)
- Singapore (statutory 17%): ETR1 7.2% only (n = 552; ETR2–4 unavailable)

Table note: EU27 = country was EU member in February 2020; "Other Europe" = non-EU but geographically European (excludes Russia and Turkey). Countries with * have fewer than 50 companies per sample.



## pp. 9–10 — Methodology (continued): Data Samples, Statutory Rate Comparison, Discussion

On using different samples per ETR version vs. a single balanced panel:
- Single balanced panel alternative: produces four internally consistent ETR versions but based on fewer companies (extreme case: Estonia all four versions based on one company) → fails to exploit all available data
- Balanced panel implemented as robustness check (Table A2, S1 Appendix)

Comparing ETRs with statutory rates:
- "One headline statutory rate per country" → provides only "imperfect comparison," especially where multiple rates exist (e.g. German municipal trade tax; Norwegian sector-specific rates; South Korean progressive schedule)
- Germany case: research interest surged partly in response to preliminary version of this paper used in Janský (2019) (ref [57]) policy report; see also Bräutigam/Ludwig/Spengel (2019) (ref [58]) and Huber/Maiterth (2019) (ref [59]) in German literature

ETRs lower than statutory rates expected because of: tax holidays, tax exemptions, tax rulings, other deductions
- These are captured both by backward-looking ETRs (this paper) and forward-looking ETRs (ref [10]; OECD ref [24])
- Country-specific details in Table A5 (S1 Appendix) for all countries with ≥ 50 companies — lists characteristics of CIT systems that may explain ETR-statutory rate differences (subnational rates, industry-specific provisions, etc.)

Note on consolidated vs. unconsolidated data:
- If worldwide taxation of MNCs headquartered in a given country is the interest → ETRs using consolidated MNC data may be estimated as weighted average of company-level ETRs (as in Garcia-Bernardo/Janský/Tørsløv 2022, ref [33]) — but NOT for individual affiliate-level analysis
- Both consolidated and unconsolidated data useful; choice depends on research purpose; unconsolidated data less available in Orbis



## pp. 11–12 — Results (Section 4): Main Findings

ETR estimates: gross income-weighted means, 2011–2015, for 47 countries with at least 50 companies

Figure 1 (key visual): Shows four ETR versions + statutory rates, sorted by ETR3, for 47 countries with ≥ 50 companies
Figure 2: Maps mean ETR1 and median ETR1 across Europe

Across the 47 countries:
- 5 countries: all four ETR versions between 0–10% (very low)
- 20 countries: 10–20%
- 20 countries: 20–30%
- 5 countries: above 30%
- Extreme cases: as low as 1%, as high as 65%

Lowest ETRs (all four versions below 10%):
- Luxembourg, North Macedonia, Bosnia & Herzegovina, Serbia
- Luxembourg specifically: ETR3 = 1% (lower bound), ETR4 = 8% (upper bound), statutory rate = 29% — "Some evidence indicates that tax rulings have played a role in Luxembourg's low ETR" (ref [60] OECD Table II.2 2018)

Highest ETR:
- Norway: ETR3 = 45%, ETR4 = 66% — driven by petroleum sector (subject to marginal tax rate up to 78%, ref [62])
- Other high-ETR countries mostly non-European: Japan, Peru, Australia, Morocco

EU countries with lowest ETRs (besides Luxembourg):
- Cyprus: 7–11%; Bulgaria: 6–11%
- Hungary: lower bound 6%, upper bound 18%; Belgium: 8–31%; Netherlands: 10–34%

EU countries with highest ETRs:
- Italy: 25–42%; Greece: 24–31%

Major EU economies:
- France: 13–35%; Germany: 15–29%; UK: 13–24%



## pp. 13–14 — Results: ETRs vs. Statutory Rates & Robustness Checks

ETRs vs. statutory rates:
- ETRs lower than statutory rates: ETR1 in 40/47 countries, ETR2 in 37/47, ETR3 in 43/47, ETR4 in 23/47
- ETRs higher than statutory rates: ETR1 in 7/47, ETR2 in 10/47, ETR3 in 4/47, ETR4 in 24/47
- Only three countries have ETR3 (lower bound) higher than statutory rate: Norway, Ireland, Estonia

Country-specific explanations for ETR3 > statutory rate:
- Norway: ETR1–4 = 53%, 62%, 46%, 67% vs. statutory 28% → driven by petroleum sector (marginal rate up to 78%, ref [62])
- Ireland: ETR1–4 = 16%, 15%, 14%, 19% vs. statutory 12.5% → consistent with existing literature; Apple case not captured (ref [21]); Irish Comptroller and Auditor General (ref [63]) found ETRs of similar magnitude; Orbis-based ETRs are "positively, albeit of course not perfectly, correlated" with backward-looking ETRs from CbCR data for US-headquartered MNCs (ref [49])
- Estonia: ETR3 and ETR4 based on only one company → not representative

Countries where statutory rate provides good approximation of ETR:
- Ukraine, Bulgaria, Slovakia — ETRs comparable to statutory rates

Countries where statutory rate is uninformative:
- Luxembourg (extreme case); many others exhibit substantial divergence

Correlation between ETRs and statutory rates (47-country sample):
- ETR1–ETR4 vs. statutory: correlations = 0.58, 0.63, 0.51, 0.64
- 93-country sample: 0.53, 0.55, 0.52, 0.52
- EU-only subsample: 0.37, 0.64, 0.28, 0.61 for ETR1–ETR4 → lower correlations for ETR1 and ETR3 in EU countries
- But when Luxembourg excluded as robustness check: EU–worldwide correlation difference disappears → Luxembourg is main driver
- Forward-looking ETRs (OECD, ref [24]): positively correlated with backward-looking ETRs, but "mostly higher values" than backward-looking ETRs (Fig A2)

Robustness checks (five in total):
- Table A1: do not exclude companies with negative profits in previous year
- Table A2: balanced panel for all four ETR versions
- Table A3: both conditions (A1 + A2) simultaneously
- Table A4: keep only affiliates with 3 or more observations between 2011–2015
- Table A5: country-specific corporate income tax system characteristics (for countries with ≥ 50 companies)

Sectoral robustness (fifth check):
- Remove one NACE 1-digit sector at a time; ETR changes by >5 pp in 28 instances across four ETR types and four sectors:
   - B (Mining and Quarrying): 15 cases — dominant sector driving Norway result; excluding mining, Norway ETR drops to ~16%
   - C (Manufacturing): 6 cases
   - K (Financial and Insurance Activities): 5 cases — reduces ETR1 and ETR3 substantially in Netherlands and Cyprus
   - N (Administrative and Support Service Activities): 2 cases
- Mining sector also increases tax rate by >5 pp in Denmark and Netherlands
- "Results are in general very robust to excluding individual sectors"



## p. 15 — Conclusions (Section 5)

Three-step contribution:
1. ETRs from MNC income statement data are useful for cross-country comparison
2. New methodology to estimate ETRs as reliably and for as many countries as possible
3. Application to Orbis unconsolidated data: new estimates for 50 mostly European countries

Key findings:
- ETRs differ substantially across countries and from statutory rates
- Many countries: MNCs pay little tax
- ETRs generally lower than statutory rates, but "countries differ significantly with respect to how much"
- ETRs and statutory rates positively related, but less so for EU countries
- Evidence "suggests to some extent a race to the bottom in ETRs" — some EU countries already close to zero
- Some of those same EU countries block tax reform at EU level → paper recommends EU consider abandoning unanimity requirement in tax matters (Article 116 TFEU)
- December 2022 Pillar 2 directive for EU: described as "encouraging"

Data limitations:
- Orbis income statement data does not differentiate between equity income and other financial income → four ETR versions needed but still imperfect
- Call for "public, affiliate-level country-by-country reporting data" — in contrast to aggregate CbCR data the OECD has published since 2020

Policy recommendations:
- EU to use Article 116 TFEU if Pillar 2 implementation stalls
- EU should consider adopting Pillar 1 or other profit-shifting reforms



## p. 16 — Conclusions (continued): Implications for Future Research

Three main future research uses of the methodology and estimates:

1. Effect of corporate taxation on investment:
   - Most existing studies use statutory rates or forward-looking ETRs "often for the lack of a better alternative" (e.g. meta-analysis by De Mooij/Ederveen 2008, ref [67])
   - This paper improves availability of backward-looking ETRs, which can "substantially differ" — e.g. Luxembourg: backward-looking ETR 1–8% vs. statutory 28% vs. forward-looking ETR above 20% (OECD, ref [24])

2. Profit shifting literature:
   - Has historically relied on statutory rates because ETRs were unavailable (meta-analysis Beer/De Mooij/Liu 2020, ref [68])
   - This paper addresses availability gap; future research can build on this by providing ETR estimates over time

3. Evaluating global minimum tax reform:
   - Methodology "should be useful in evaluating the reform's effects ex ante as well as ex post"
   - ETRs also used as control variables in tax and public economics research
