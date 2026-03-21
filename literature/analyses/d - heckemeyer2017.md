# Heckemeyer & Overesch (2017) Multinationals' Profit Response to Tax Differentials: Effect Size and Shifting Channels
Canadian Journal of Economics, 50(4), 965–994


## p. 965 (title/abstract)

- Meta-analysis of empirical literature on profit-shifting behaviour of MNEs
- Synthesises evidence from 27 studies, 203 primary estimates
- Main result: tax semi-elasticity of subsidiary pre-tax profits of approximately 0.8 (after accounting for confounding factors via meta-regressions)
- Interpretation: reported profits decrease by about 0.8% if the international tax rate differential increases by one percentage point
- Second contribution: disentangles financial planning channel (inter-company debt) from transfer pricing and licensing channel
- Conclusion: transfer pricing and licensing are the dominant profit-shifting channels, not inter-company debt
- JEL: H25, H26, H32



## p. 966–967 (introduction)

- Policy context: public debate on legal tax avoidance by MNEs; Apple Inc. reported foreign ETR of only 4.7% for fiscal year 2011 (Sullivan 2012)
- OECD (2013) published BEPS Action Plan in response; US also considered unilateral measures (President's Framework for Business Tax Reform, 2012)
- Literature on channels for income shifting:
  - Financial structures: Desai et al. (2004), Huizinga et al. (2008)
  - Transfer pricing: Clausing (2003) — prices responsive to taxes in related-party transactions but not in third-party transactions
  - Patent allocation: Karkinsky and Riedel (2012), Griffith et al. (2014)
  - Tax expense disclosures: Jacob (1996), Dyreng and Lindsey (2009)
  - Profitability comparisons domestic vs. MNE subsidiaries: Grubert et al. (1993), Collins et al. (1997), Egger et al. (2010) — mixed results
  - Aggregated public account data: Bartelsman and Beetsma (2003)
  - Subsidiary-level data: Hines and Rice (1994), Huizinga and Laeven (2008)
- Key gap: no consensus on scale of profit-shifting activity, no consensus on relative importance of financial vs. non-financial channels
  - Grubert (2003): shifting volume of US firms almost equally attributed to financial and non-financial techniques
  - Dharmapala and Riedel (2013): approach more likely to capture debt shifting than transfer pricing
- Three contributions of this paper:
  1. Survey existing evidence on tax elasticity of reported parent or subsidiary profits; use meta-regression to systematically explain heterogeneity in estimates
  2. Propose a conservative "consensus" estimate for the tax-rate elasticity of reported profits
  3. Use meta-regression results to determine relative importance of financial structures vs. transfer pricing/licensing; also test for publication selection bias



## p. 967–968 (introduction cont.)

- Meta-database: 203 primary estimates from 27 empirical studies (EconLit search, SSRN, relevant journals)
- Starting point: early work by Hines and Rice (1994); all studies estimate empirical relationship between reported profitability and tax incentive to shift profits abroad
- This is "indirect evidence" for profit shifting — not direct observation of shifting techniques
- Predicted semi-elasticity of pre-tax profit: approximately 0.8 (absolute terms)
- Comparison of tax sensitivity of pre-tax profits (all shifting channels) with tax sensitivity of EBIT (non-financial channels only) → transfer pricing and licensing dominant, not inter-company debt
- Policy relevance: results provide information for BEPS debate based on broad empirical facts; helpful for designing counter-measures; meta-regression also guides future empirical research



## p. 968–969 (section 2.1 — meta-regression approach)

- Empirical approaches in the literature are diverse; unlike randomised trials, estimates vary beyond pure sampling error
- Meta-regression analysis: statistical approach to synthesise central tendency of a literature strand and identify determinants of variation in reported findings
- Primary literature estimates regressed on variables capturing differences in method, design, and data (Stanley 2001, Disdier and Head 2008)
- Precedents for meta-analysis in economics: Card et al. (2010, 2015), Lichter et al. (2015) in labour economics; Havranek and Irsova (2011) in international economics; de Mooij and Ederveen (2003, 2005, 2006, 2008) in international taxation; Feld et al. (2013) on capital structures
- Scope restriction: limited to MNEs' profit response to international tax differentials — the "most general manifestation of profit shifting behaviour"
- Tax effect measured consistently as semi-elasticities: percentage change of reported profit per one percentage point change in tax differential
- Formula: Semi-Elasticity = ∂ln(Reported Profit) / ∂Tax Differential ≈ (∂Reported Profit / Reported Profit) · (1 / ∂Tax Differential)
- Estimation: Weighted Least Squares (WLS), recommended procedure for meta-regressions (Stanley 2008)
- Weights: inverse standard errors of primary effect estimates — reliable estimates receive larger weight



## p. 969–970 (section 2.2 — the tax effects data set)

- All studies estimate the relationship between reported parent/subsidiary profitability and tax incentive to shift profits abroad
- Underlying model derived from Hines and Rice (1994) and Huizinga and Laeven (2008)
- Basic setup:
  - Reported pre-tax profit in country i: P^r_i = true pre-tax profit P_i + shifted profit S_i
  - S_i = P_i · γ · Δτ_{i,j} where γ is the semi-elasticity and Δτ_{i,j} is the bilateral tax rate differential between country i and other subsidiary locations j
  - So: P^r_i = P_i (1 + γΔτ_{i,j}) — equation (3)
- Taking logs and assuming a Cobb-Douglas production function, the standard estimation equation is:
  - ln P^r_i = β_1 + β_2 ln A_i + β_3 ln L_i + β_4 ln K_i + γΔτ_{i,j} + v_i — equation (5)
  - A = productivity, L = labour, K = capital
- Meta-analysis collects point estimates of γ from the primary literature
- Database search: EconLit, SSRN, relevant journals (Journal of Public Economics, AEJ: Economic Policy, Journal of International Economics, National Tax Journal, International Tax and Public Finance, Accounting Review, Journal of Accounting Research, Journal of Accounting and Economics, Contemporary Accounting Research, European Accounting Review) — footnote 6
- Last update: February 2015
- Over 50 studies matched initial search; exclusion criteria:
  - Only studies using profit measure as dependent variable included
  - Only studies that directly provide semi-elasticities or allow transformation at sample means
  - Excluded: Grubert and Mutti (1991), Jacob (1996), Grubert (1998), Bartelsman and Beetsma (2003), Clausing (2003) — footnote 7
  - Highly selective estimates (e.g. specific industry subsamples) excluded — footnote 9: this excludes results from Blouin et al. (2012), Lohse and Riedel (2013), Beer and Loeprick (2013), and Klassen and LaPlante (2012) because all specifications include interaction terms of tax incentive with firm characteristics
- Final dataset: 203 observations from 27 studies
- Convention: all semi-elasticities pre-multiplied by (–1) before entering meta-dataset



## p. 971 (figure 1 and discussion of time trend)

- Figure 1 plots all 203 estimates against average sample year, with a linear trend line
- Key observation: magnitude of estimated semi-elasticities tends to decrease over time
  - Studies using data from 1980 to mid-1990s: majority of semi-elasticities above 1 or even 2.5
  - Studies using data from late 1990s to 2008: semi-elasticities range around 1, often lower
- Two possible explanations for the downward trend (cannot yet determine which):
  1. More restrictive anti-avoidance legislation and enforcement made shifting more costly
  2. Studies increasingly use firm-level data allowing more accurate microeconometric estimation
- Meta-regression results in section 4 will address principal drivers



## p. 972–973 (section 2.2 cont. — Table 1 and data description)

- Table 1: means and medians of semi-elasticities for full sample and subsamples
  - Full meta-sample: arithmetic mean = 1.52, inverse-variance weighted mean = 0.51, median = 1.02, N = 203
  - Firm-data studies: mean = 1.09, inverse-variance weighted = 0.49, median = 0.90, N = 171
  - By dependent variable type (firm-data studies only):
    - Value added: mean 0.86, IV-weighted 0.84, N = 4
    - Total factor productivity: mean 1.29, IV-weighted 0.95, N = 18
    - Profit (after-tax): mean 1.23, IV-weighted 1.15, N = 18
    - Profit (before-tax): mean 1.17, IV-weighted 0.71, N = 81
    - EBIT: mean 0.85, IV-weighted 0.24, N = 50
- Comparison with de Mooij (2005) — the only previous survey of profit-shifting semi-elasticities: de Mooij found average semi-elasticity of 2 based on five studies; the lower mean here is consistent with the downward time trend
- Simple arithmetic mean does not use information on precision; inverse-variance weighted mean for full sample is 0.51
- Figure 2: kernel density of all 203 semi-elasticities; arithmetic mean (long dash) inflated by large but imprecisely estimated values at right tail
- Firm-level vs. aggregate data:
  - Aggregate data (e.g. Hines and Rice 1994 using BEA data) may simply reflect systematic differences in characteristics of firms investing in low-tax countries, rather than profit shifting (de Mooij 2005)
  - Aggregate approaches may fail to control adequately for scale of real economic activity; may pick up tax effects on investment and location choices rather than profit shifting
  - Micro-data studies yield mean of 1.09 vs. full sample mean of 1.52 — but medians and IV-weighted means are comparable between aggregate and micro samples, suggesting aggregate data yields outlying estimates
  - Caveat: micro-data studies might underestimate tax effect if time-invariant tax rate differences are absorbed by country or subsidiary fixed effects
- Different types of profit variables used: total profits, EBIT, value added, total factor productivity
  - Semi-elasticity of total profits reflects all shifting routes
  - Semi-elasticity of before-financing profits (EBIT) excludes shifting via inter-company financing
  - Descriptively, tax effect on total profits larger than on before-financing profits — preliminary evidence on channel importance



## p. 974–975 (section 3 — why identified tax effects might vary; section 3.1)

- Four expected main drivers of variation in identified tax effects:
  1. Exact type of profit variable (scope of shifting it reflects)
  2. Econometric specification
  3. Structural heterogeneity of firm data
  4. Proxy used for the tax incentive

- Section 3.1 — categories of profit variables:
  - After-financing profit: captures shifting via all routes (financial + non-financial)
  - EBIT: independent of financial structures, captures only non-financial techniques (transfer pricing, royalties)
  - Also value added and total factor productivity capture only non-financial shifting — footnote 10: TFP adjusts for cost of total capital but not for choice between debt and equity financing
  - Financial mechanisms: inter-company debt in high-tax subsidiaries allows deduction of interest expenses; interest income from such debt taxed at low rate in low-tax subsidiary
  - Interest income and interest paid (both inter-company and external bank lending) not reflected in EBIT
  - Key inference: tax effect on EBIT reflects only non-financial shifting → expect smaller tax effect on EBIT than on total profit
  - Meta-variable constructed: dummy "After Financing Profitability" — marks primary estimates based on after-financing profit
  - Additional nuance: if debt ratio is not controlled for in studies using after-financing profits, identified tax effect is expected to be more pronounced (debt ratio has negative impact on after-financing profits and is positively correlated with tax incentive)
  - Including debt share as control is equivalent to isolating non-financial shifting effects
  - Meta-variable: "No Control for Debt Ratio" — equals 1 if specification does not control for debt share
  - Distinction pre- vs. after-tax profits: any correlation between pre-tax profitability and tax rate reflects behavioural response; after-tax profits are directly and technically affected by tax payments → expect more pronounced tax response if dependent variable is after-tax
  - Meta-variable: "Profits Before Taxes" — equals 1 if dependent variable is measured before taxes



## p. 975–976 (section 3.2 — data sample characteristics)

- Micro-level vs. aggregate data: meta-variable "Micro-Level Data" — equals 1 if study uses subsidiary-level data
- Temporal dimension: data used in studies span very different time periods (Hines and Rice 1994: cross-section 1982; Huizinga and Laeven 2008: 1999; Beer and Loeprick 2013: 2003–2011)
- Downward trend in estimated tax effects already noted; empirical question whether this reflects tighter anti-avoidance rules or methodological trends
- Meta-variable: "Average Sample Year" — average disclosure year of data used in the estimation
- 27 studies use 6 different databases (different geographical coverage and firm types); database fixed effects included in meta-regressions



## p. 976–977 (section 3.3 — econometric specification)

- Profitability varies between firms; firms also differ in tax aggressiveness (Dyreng et al. 2010)
- Profit shifting may contradict interests of local managers (avoiding debt discipline, bonus effects)
- Subsidiary fixed effects:
  - Pro: avoids omitted variable bias for unobserved subsidiary-specific heterogeneity
  - Con: subsidiary fixed effects nest country fixed effects; much of cross-sectional tax rate variation absorbed → reduces identified semi-elasticities (Clausing 2006, p. 276)
  - Also: shifting opportunities are determined by details of tax code and enforcement; if anti-avoidance rules do not vary much over time, subsidiary or country fixed effects also control for heterogeneity in shifting opportunities
  - Meta-variable: "Subsidiary Fixed Effects Included"
  - Also: "Country Fixed Effects Included"
- Time fixed effects: unobserved time trends (business cycles, financial crises, institutional changes) may be correlated with tax incentive
  - Meta-variable: "Time Fixed Effects Included"



## p. 976–977 (section 3.4 — proxy for the tax incentive)

- Ideal tax variable: composite of host country tax rate differentials vis-à-vis all other relevant locations worldwide
- Profit shifting requires bilateral intra-firm transactions (intra-firm sales, royalties, debt financing) → each intra-firm bilateral tax rate differential creates shifting incentive, but relevance depends on bilateral transaction volumes and shifting opportunities
- Problem: information on all locations and their relevance for shifting often unavailable
- Many studies use host country tax rate only → potential omitted variable bias
  - Cross-sectional context: host tax rate alone → estimates biased toward larger effect sizes (Huizinga and Laeven 2008)
  - Panel data context: only local tax rate ignores time correlation between local and foreign tax rates → estimated effects biased toward smaller effect sizes
- More refined approaches: bilateral parent-subsidiary tax differential; sophisticated size-weighted or activity-weighted average differentials (Collins et al. 1998, Mills and Newberry 2004, Huizinga and Laeven 2008, Grubert 2012) — "best conceivable proxy for the genuine profit shifting incentive"
- Meta-variable: "Worldwide Tax Incentive Considered" — marks studies using activity-weighted or size-weighted composite tax differentials



## p. 977–979 (section 4 — meta-regression results; Table 2)

- Six specifications reported in Table 2; specifications (5) and (6) use standard errors clustered at study level (27 clusters — interpret carefully)
- Specification (1): only after-financing profitability dummy
- Specification (2): adds average sample year, micro-level data dummy, profits-before-taxes dummy
- Specification (3): adds econometric specification dummies (time FE, subsidiary FE, country FE)
- Specification (4): adds worldwide tax incentive dummy — most comprehensive; preferred specification
- All specifications estimated by WLS; specifications (1)–(4) use heteroskedasticity-robust standard errors

- Key coefficient results from specification (4) (preferred):
  - After-financing profitability: +0.243*** (se 0.0901) — semi-elasticity higher for after-financing profit vs. EBIT; not significant when clustered at study level
  - No control for debt share: +0.256* (se 0.150)
  - Profits before taxes: -0.977*** (se 0.211) — strong negative coefficient; after-tax profits overestimate tax effect
  - Average sample year: -0.0293* (se 0.0158) — significant downward trend over time
  - Micro-level data: -1.683*** (se 0.458) — striking; aggregate data substantially overestimates tax responsiveness
  - Worldwide tax incentive considered: +0.147 (se 0.153) — positive but insignificant
  - Time fixed effects included: +0.292** (se 0.122)
  - Subsidiary fixed effects included: -0.443** (se 0.224)
  - Country fixed effects included: +0.353* (se 0.212)
  - Constant: 60.65* (se 31.60)
  - R² = 0.599
  - Predicted tax effect (all significant dummies set to 1, sample means for insignificant/continuous): 0.786***



## p. 980–982 (section 4.1 and 4.2 — benchmark study and sources of variation)

- Benchmark study: hypothetical primary analysis lacking all study characteristics that prove statistically significant in meta-regressions (i.e. dummies for significant variables set to zero; sample means used for continuous variables and insignificant dummies)
- Predicted benchmark semi-elasticity from specification (4): approximately 2.745 — footnote 11 shows calculation: 60.648 (constant) + database effects weighted average + 0.147 · 0.684 (worldwide tax incentive) – 0.02929 · 1999.95 (average sample year) = 2.745
- This benchmark of 2.75 is "no preferred estimate" — rather serves as starting point for systematic discussion of sources of misspecification bias

- Sources of variation (specification 4 discussion):
  - After-financing profitability: positive and significant in most specifications; semi-elasticity 0.243 pp higher for after-financing profit vs. EBIT → some evidence for financial channel on top of non-financial; but not significant when clustering at study level → caveat
  - No control for debt ratio: similar magnitude difference to EBIT vs. profit comparison → consistent result
  - Profits before taxes: significant negative coefficient — confirms upward bias when after-tax profits used
  - Micro-level data: coefficient approximately -1.6 — very large; aggregate data associated with significant upward bias; likely attributable to "diffuse identification of shifting vs. real economic location effects in aggregated data"
  - Average sample year: semi-elasticities fall with increasing average sample year, even conditional on econometric specification; in line with Lohse and Riedel (2013); decreasing responsiveness of profits does not necessarily mean total volume of shifted profits has shrunk — given significant increase in scale of transnational business activity
  - Time fixed effects: inclusion associated with significantly higher reported tax responsiveness
  - Subsidiary fixed effects: leads to significantly smaller estimated semi-elasticities
  - Country fixed effects: leads to higher estimates
  - Fixed effects results not robust when clustering at study level
  - Worldwide tax incentive: positive sign (refined measure → higher semi-elasticity) but insignificant



## p. 982–983 (section 4.3 — predicted profit response; Table 3)

- Predicted semi-elasticity for a state-of-the-art hypothetical study avoiding all significant specification biases (specification 4):
  - 0.786 = 2.745 (benchmark) + 0.243·1 (after-financing) + 0.256·1 (no debt control) – 0.977·1 (before taxes) – 1.683·1 (micro-level data) + 0.292·1 (time FE) – 0.443·1 (subsidiary FE) + 0.353·1 (country FE) — equation (6)
- Table 3: point estimate 0.786***, 95% confidence interval [0.546, 1.026], standard error 0.122
- Interpretation: "a one percentage point smaller tax rate differential, for example, as a consequence of a one percentage point cut in host country taxes, is associated with a 0.786% increase in subsidiaries' pre-tax profits"
- Predicted semi-elasticities significant and robust across all six specifications (range approximately 0.677 to 0.885)
- The approximately 0.8 estimate "can be interpreted — with adequate caution — as some sort of a consensus or typical estimate based on the available evidence provided by 27 empirical studies and corrected for confounding factors"



## p. 983–984 (section 4.4 — influence of the database; Table 4)

- Six databases used across the 27 studies; database fixed effects included in all specifications
- Table 4: predicted tax effects by database (from specification 4):
  - Amadeus (N=86): 0.89
  - BEA aggregated data (N=19): 1.89
  - BEA micro-data (N=1): 0.21
  - Compustat (N=8): 0.43 — possibly because consolidated accounts analysed rather than subsidiary-level linked to host country taxes
  - IRS aggregated data (N=13): 2.77
  - IRS micro-data (N=25): 1.09
  - MiDi (N=6): -0.23 — note: MiDi includes only after-tax profit information
  - Orbis (N=45): 0.87
  - Full meta-sample micro-data (N=203): 0.79
- Most pronounced tax effect: IRS tax accounting data — footnote 14 notes that differences between IRS and other databases (e.g. Amadeus, Orbis) are statistically insignificant (p-values 0.116 and 0.219)
- Compustat finding may indicate measurement issues with consolidated accounts
- No clear tax response found with MiDi; only after-tax profits available in that database



## p. 984–987 (section 5 — which shifting route is more important?; Table 5)

- Goal: determine relative importance of financial structures (inter-company debt) vs. non-financial techniques (transfer pricing, licensing)
- Approach: compare predicted semi-elasticity of pre-tax profits (all channels) with predicted semi-elasticity of EBIT (non-financial only), then rescale EBIT semi-elasticity to make it comparable
- From specification (4): predicted semi-elasticity of pre-tax profit = 0.786; predicted semi-elasticity of EBIT = 0.543 (= 0.786 – 0.243, subtracting the after-financing profitability dummy coefficient) — footnote 15: standard error of EBIT prediction = 0.10, 95% CI [0.346, 0.741]
- Problem: the two semi-elasticities have different bases (EBIT vs. pre-tax profit); to compare them, must rescale EBIT semi-elasticity to pre-tax profit basis
- Equation (7): γ_NF = γ_EBIT · (EBIT_i / Pre-tax Profit) — multiplying the EBIT semi-elasticity by the ratio of EBIT to pre-tax profit aligns the base
- Data on ratio: 2013 S&P 500 consolidated financial accounts used (consolidated accounts clear of profit shifting because intra-firm transactions cancel out — footnote 16)
- 2013 mean ratio of EBIT / pre-tax profit for S&P 500 = 1.18 → EBIT exceeds pre-tax profit on average by 18%
- Rescaled non-financial semi-elasticity: 0.641 (= 0.543 · 1.18)
- Table 5 summarises:
  - All shifting: EBIT n/a, pre-tax profit 0.786, share 100%
  - Non-financial: EBIT 0.543, pre-tax profit 0.641, share 82%
  - Financial: pre-tax profit 0.145 (= 0.786 – 0.641), share 18%
- Interpretation: non-financial mechanisms (transfer pricing, royalties) account for approximately 82% of total profit response; financial mechanisms (inter-company debt) account for approximately 18%
- Robustness check: across all six specifications, share of non-financial shifting always at least two thirds or above — footnote 17: 86% in col. (1), 83% in col. (2), 77% in col. (3), 82% in col. (4), 76% in col. (5), 80% in col. (6)
- Alternative check using debt-ratio control instead of EBIT: predicted tax effect = 0.53 (= 0.786 – 0.256); non-financial share 67% (= 0.53/0.786), financial share 33% (= 0.256/0.786)
- Stated limitations of back-of-the-envelope calculation:
  - Point estimates have significant confidence intervals
  - Assumption on ratio of EBIT to pre-tax profit from S&P 500 is simplifying
  - Studies using subsidiary data may underestimate financial profit shifting if MNEs use additional special entities for complex financing structures (Mintz 2004, Ruf 2011, Wamser 2011)
  - Also noted: the difference in tax response of EBIT vs. pre-tax profit is not always statistically significant in the meta-regressions
- Overall conclusion: "volumes of shifted tax bases are predominantly driven by firms' non-financial inter-company transactions"



## p. 987–989 (section 6 — publication selection bias; Table 6, Figure 3)

- Concern: publication process may have influenced which findings are available — both authors and editors may prefer statistically significant results (De Long and Lang 1992, Franco et al. 2014)
- Standard test: relationship between estimated coefficient and its standard error (Card and Krueger 1995; Stanley 2005, 2008)
- If no publication bias: no systematic relationship between magnitude of semi-elasticity and precision
- If publication bias present: positive relationship between standard error and semi-elasticity (larger standard error → need larger coefficient to achieve significance)
- Figure 3 (funnel plot): plots semi-elasticity estimates against standard errors; grey region = 5% significance frontier; asymmetric pattern observed — many estimates cluster along right side of 5% significance frontier
- Note: funnel asymmetry may also reflect other types of bias or genuine heterogeneity in true effects
- Table 6: formal test within preferred meta-regression (specification 4)
  - Column (1): standard error coefficient = 1.601*** (se 0.272) — positive and significant; publication bias confirmed
  - Column (2): standard error interacted with average sample year: -0.0455 (se 0.0355) — insignificant; no evidence bias changed over time
  - Column (3): adds "Published" dummy and its interaction with standard error; published coefficient = -0.038 (ns), interaction = 0.863 (ns); publication status has no statistically significant effect on extent of publication bias



## p. 989–990 (section 7 — conclusion)

- Summary of main findings:
  - Data sampling and econometric specification significantly influence estimated profit response
  - Aggregate data significantly overestimates tax-responsiveness relative to firm-level data
  - Database used also matters; IRS tax accounting data associated with most pronounced effects
  - Controlling for unobserved firm heterogeneity (subsidiary fixed effects) associated with significantly smaller tax effects
  - Even conditional on study design, responsiveness of subsidiary profits to shifting incentives has decreased over time
  - Semi-elasticity of total profits significantly higher than semi-elasticity of EBIT — financial channel adds to overall response
- Consensus estimate: "tax semi-elasticity of pre-tax profit of about 0.8" — "a one percentage point smaller tax rate differential... is associated with an increase in a subsidiary's pre-tax profit by approximately 0.8%"
- Channel decomposition: "MNEs' response to a change in shifting incentives... runs mainly via the route of non-financial intra-firm transactions"; share of non-financial shifting always at least two thirds across several calculations
- Policy implication: findings can inform targeted design of anti-avoidance measures
- Acknowledged limitations:
  1. Limited set of study characteristics can be controlled for
  2. Only indirect evidence (profit response); studies on transfer prices, intellectual property allocation, and financial structures excluded
  3. Publication selection bias detected
  4. Subsidiary-level studies may underestimate profit shifting if special-purpose entities used
