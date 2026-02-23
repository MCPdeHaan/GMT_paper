# Garcia-Bernardo, Janský & Zucman (2022) "Did the Tax Cuts and Jobs Act Reduce Profit Shifting by US Multinational Companies?"

## p. 1 Title page / abstract

Core question: Did the 2017 Tax Cuts and Jobs Act (TCJA) reduce profit shifting by US multinationals?

Method: Combines BEA survey data, IRS tax data (country-by-country reporting, CbCR), and Compustat firm financial statements.

Main findings (summary level):
- Share of profits booked abroad by US multinationals fell 3–5 percentage points post-reform, driven mainly by repatriation of intellectual property (IP) to the US.
- Share of foreign profits booked in tax havens remained stable at around 50% between 2015 and 2020.
- Changes are small overall, but some individual firms responded strongly.

## p. 2 Introduction (first part)

Context on profit shifting: "close to 40% of multinational profits profits booked by firms outside of their headquarter country are shifted to tax havens globally" (citing Garcia-Bernardo & Janský 2021; Tørsløv et al., forthcoming). US multinationals specifically book a "particularly large fraction" of foreign income in low-tax places (citing Clausing 2020b; Dowd et al. 2017; Guvened et al. 2022).

What the TCJA did (enacted end of 2017):
- Lowered US federal corporate income tax rate from 35% to 21%.
- Switched from a worldwide system (foreign profits taxable upon repatriation) to a territorial system (foreign profits generally exempt from US tax). Note: described in practice as "hybrid" because anti-avoidance provisions still exist.
- Introduced three provisions to curb haven shifting: (1) GILTI a US minimum tax on foreign income taxed at low rates abroad; (2) FDII a reduced rate on foreign income from intangibles booked in the US; (3) BEAT measures limiting deductibility of certain payments suspected to shift income out of the US.

Research questions: Has the foreign share of US firms' profits declined? Has the share in tax havens fallen? If so, where did profits go back to the US or to high-tax countries?

Policy relevance: Directly tied to the debate on whether additional reform (i.e., the OECD/G20 global minimum tax, OECD 2021) is still needed. If the TCJA already curbed shifting substantially, the case for GMT weakens. If tax haven profits remain high, the case strengthens.

Contribution: "the first comprehensive analysis of trends in profit shifting after the Tax Cuts and Jobs Act." Previous work had to rely on case studies (e.g., Sullivan 2020 on pharma; Coffey 2021 on Ireland) because key data were not yet available. Data coverage here extends to 2019 (BEA, IRS CbCR published April 2022) and 2020 (Compustat).

## p. 3 Introduction (continued main findings)

Finding 1 Foreign share of profits: Evidence that US corporations book a larger share of profits in the US post-reform, but change is small: share of profits booked abroad fell by about 3–5 percentage points, to about 27% for all US companies. Driven primarily by six large companies (Alphabet, Microsoft, Facebook, Cisco, Qualcomm, Nike) that repatriated IP to the US, each experiencing a drop in foreign earnings share of over 20 percentage points.

Finding 2 Haven share of foreign profits: The geographical allocation of foreign profits was "not significantly affected." Across all data sources, the haven share of foreign profits remained stable at around 50% between 2015 and 2020. Since the foreign share only slightly declined, the share of total (domestic + foreign) profits booked in tax havens remained around 13–15% throughout 2015–2020, described as "a historically high level."

Overall characterisation: "although a few firms responded to incentives introduced by the Act sometimes with dramatic effects at the micro level the global allocation of profits by US firms appears to have changed relatively little overall."

Ambiguity of TCJA effects (noted upfront): Lower US rate and GILTI reduce incentives to shift to havens. But the move to a territorial system increases incentives to shift to low-tax countries. Some aspects of GILTI also give firms incentives to move tangible capital (not just profits) to low-tax countries (Clausing 2020b).

Methodological contribution: Reconciling all available sources by harmonising the definition of profit, accounting for sample specifics, and removing double-counting from CbCR data. Builds on Horst & Curatolo (2020) for the double-counting correction.

## p. 5 Section 2: Data Sources

Three main sources for studying US multinational activities:

(1) BEA Survey Data

Bureau of Economic Analysis conducts mandatory quarterly, annual, and benchmark surveys of foreign operations of US MNEs. Two key profit measures:

- "Direct investment equity income": Net of foreign income taxes, pro-rated by ownership stake, allocated to countries with which the US parent has a direct link (not where operating income is earned). So if a US parent owns a German affiliate through a Dutch holding, profit is recorded in the Netherlands, not Germany.
- "Profit-type return": Not pro-rated by ownership stake (all majority-owned affiliate profits included, minority excluded), gross of foreign income taxes, assigned to countries where operating income is earned. The paper prefers this measure for country-level allocations.
- "Net income": Double-counts income earned through chains of affiliates not used in this paper.

Important nuance: BEA survey uses stockholder reporting standards, not tax-reporting standards. So neither measure necessarily reflects where income is taxed. Profit-type return can understate haven income (because hybrid structures and hybrid dividends shift taxable but not accounting income). Direct investment income likely overstates haven income (because profits flowing to holding company countries may actually have been taxed elsewhere). Direct investment income thus treated as an upper bound.

Footnote on Blouin & Robinson (2020): They use "adjusted pre-tax income" = net income minus equity investment income plus foreign taxes. This is very close to profit-type return. The paper's headline series are based on profit-type return, not adjusted pre-tax income.

Footnote on Alphabet/Google: Google Holdings (incorporated Ireland, taxable Bermuda, zero tax) made $13.7bn in operating income in 2019. Likely appears as Irish income in profit-type return, but should logically be Bermuda in CbCR. Illustrates the difference between sources.

Footnote on hybrid dividends: e.g., Luxembourg affiliate paying what is classified as interest in Luxembourg but dividend in Switzerland excluded from profit-type return in both countries, understating haven profits.

(2) Compustat (section 2.2, p. 6)

S&P Compustat North America: public financial statements (10-K filings). Covers listed corporations only excludes private firms. Vast majority report global vs. non-US profit split, but no country breakdown. Foreign profits (pifo) available for ~95% of firms by profit weight since 2010.

(3) Country-by-Country Tax Data (section 2.3, p. 7)

IRS tabulations of Form 8975 (CbCR). Covers all US-headquartered MNEs with annual revenue above $850 million. Reporting voluntary in 2016 (incomplete), compulsory from 2017. Paper does not use 2016 data.

Advantage: More likely to reflect how firms allocate profits for tax purposes. IRS instructs that a business entity is resident in a jurisdiction where it is "liable for tax therein" so Google Holdings taxable in Bermuda should appear under Bermuda, not Ireland. Also includes Puerto Rico (treated separately from the US, not included in BEA surveys). Also distinguishes between profit-making and loss-making affiliates, enabling meaningful effective tax rate (ETR) calculations.

Main drawback: Double-counting of profits. Pre-2020, OECD guidelines did not explicitly require firms to remove intra-group dividends from profits. When intra-group dividends are included, profits can be counted multiple times as they flow through chains of holding companies. Addressed in Section 3.2.

Note on IRS Form 5471 (footnote): Data on controlled foreign corporations, available only every two years. Most recent at time of writing: 2016. Not used in this paper.

## p. 8–10 Section 3: Methodology

Section 3.1 Aggregate domestic and foreign profits

Goal: construct harmonised, comparable, comprehensive, consistent series across sources.

Macroeconomic accounts (all corporations most comprehensive):
- Foreign profits = "pre-tax direct investment equity income": start with DI equity income (without current-cost adjustment), convert to pre-tax by dividing by (1 minus foreign ETR of majority-owned affiliates from BEA), then add the current-cost adjustment (converts book to economic depreciation). Example: 2016: $420bn DI equity income / 0.8 = $525bn, plus $21bn current-cost adjustment = $546bn.
- Domestic profits = NIPA corporate profits (Table 1.12 line 13) minus Federal Reserve profits minus net portfolio dividends received from the rest of the world minus DI equity income received with current-cost adjustment. Example 2016: $2,038bn minus $93bn minus $79bn = $1,866bn global; then minus $441bn DI equity income = $1,425bn domestic.
- Foreign share 2016 example: 546/(546+1425) = 28%.

BEA survey (multinationals only):
- Domestic = profit-type return of parents.
- Foreign = profit-type return of majority-owned affiliates.
- Both net of book (not economic) depreciation.
- Pre-1994: computed as net income + foreign taxes paid minus equity income minus capital gains.

Compustat (listed firms):
- Global profits = variable "pi"; foreign profits = variable "pifo."

CbCR (multinationals, large firms):
- Requires correction for double-counting (see below).

Table 1 (p. 11): Aggregate foreign pre-tax profits across sources in 2019: DI equity income $656bn, profit-type return $523bn, corrected CbCR $603bn, Compustat $560bn. Differences reflect sample coverage. Ratios are broadly stable over time (Appendix Figure A1).

Section 3.2 Haven share of foreign profits

BEA series: preferred measure = profit-type return (not DI income). Haven list following Zucman (2014): Bermuda, Ireland, Luxembourg, Netherlands, Singapore, Switzerland, UK Caribbean. Puerto Rico imputed from IRS Form 8975 and added to the haven list (does not affect trend results). Direct investment income used as an upper bound.

CbCR (corrected): slightly broader haven list adds Barbados, Gibraltar, Hong Kong, Isle of Man, Jersey, Malta, Mauritius.

Double-counting correction for CbCR (building on Horst & Curatolo 2020): Use Compustat to estimate theoretical profits that should appear in CbCR absent double-counting. Steps: extract Compustat data (pifo, txfo, pi, txc, at, intan, emp, revt) via WRDS; keep US-headquartered MNEs with revenue over $850m (sample ~1,440–1,470 firms). Estimate foreign/domestic split for ~120 firms with missing pifo using regression on assets, revenue, intangibles, employees, and foreign taxes. Estimate profits of ~150 private firms subject to CbCR but not in Compustat (assigned 20% of average non-missing profits). Results: CbCR over-estimated total profits by 48% in 2017, 72% in 2018, 47% in 2019. Over half of double-counting involves domestic profits. Domestic double-counting: 54%/74%/42% in 2017/2018/2019; foreign double-counting: 7%/39%/28%. Correction applied at country level: double-counting removed proportionally from profit-making entities in tax haven and conduit countries. UK and Ireland treated as exceptions (UK: not classified as haven but serves as conduit; Ireland: effective tax rate ~12% and CbCR profits already lower than other sources possibly because Double Irish profits appear under Bermuda or stateless entities elsewhere).



## p. 12–15 Section 4: Evolution of the Foreign Share of Profits

Section 4.1 Aggregate data

Figure 1a: Foreign profit share across all sources, 1982–2020.
- Foreign share in 2019–2020 ranges from 30–45% across sources, reflecting different firm samples. Multinationals > all corporations (latter includes firms with no foreign affiliates); listed firms > multinationals (listed firms are larger, more international); corrected CbCR lies between Compustat and BEA survey.
- All sources agree: foreign profit share fell 3–5 percentage points between 2017 and 2020.
- Decline is "an across-the-board phenomenon, albeit more pronounced in the Information sector" (Appendix Figure A2).
- Caveat: short-run fluctuations exist due to business cycle timing differences between US and rest of world. Cannot be certain the full decline is TCJA-attributable.

Section 4.2 Firm-level analysis (Compustat)

Identification: firms with sustained decline in foreign share of at least 20 percentage points post-TCJA, with positive profits 2017–2020 and revenue above $10bn at least one year. 23 firms identified. Manually checked 10-K filings.

Results:
- 6 firms: decline "unambiguously (or very likely)" related to profit shifting changes specifically IP repatriation to the US: Alphabet, Cisco, Facebook, Microsoft, Nike, Qualcomm. Alphabet's 10-K (2019): "we have simplified our corporate legal entity structure and now license intellectual property from the U.S. that was previously licensed from Bermuda."
- 6 additional firms: limited evidence of partial profit-shifting-related decline.
- 11 firms: no evidence of profit shifting changes.
- ~90% of large listed firms experienced no large (>20pp) sustained drop in foreign earnings share.

Counterfactual calculation:
- Lower bound (only the 6 unambiguous firms): US foreign profit share would be 2.8 percentage points higher in 2020 absent the reform.
- Upper bound (all 22 firms with 20pp+ drop): 4.2 percentage points higher.
- Conclusion: changes in profit shifting strategy "can account for a significant fraction of the 3–5 percentage point decline."

Two important caveats:
1. FDII (foreign-derived intangible income) incentivised IP repatriation royalties from US-booked IP taxed at 13.125% and GILTI imposed a minimum tax on foreign low-taxed income. Both push toward IP repatriation.
2. Ireland phased out the "Double Irish" structure in 2020, which was also a reason Alphabet would have restructured regardless of the TCJA. The observed decline in the foreign income share should therefore be treated as "an upper bound for the effect of the Tax Cuts and Jobs Act."



## p. 16–19 Section 5: Evolution of the Geography of Foreign Profits

Figure 2 (panels A, B, C): Share of foreign profits, employees, and tangible assets in tax havens over 2015–2020.

Classification of havens (following Reurink & Garcia-Bernardo 2020):
- "Profit centers" primarily used for profit booking with little production: Bermuda, Cayman Islands, Puerto Rico, Jersey, Isle of Man, Gibraltar, Barbados, Mauritius, British Virgin Islands, Bahamas, Malta.
- "Coordination centers" used for both profit booking and management/coordination: Singapore, Netherlands, Switzerland, Ireland, Luxembourg, Hong Kong.

Findings across DI income, profit-type return, and corrected CbCR:

(1) Haven share of foreign profits: approximately 50% across sources in recent years. DI income series shows ~55% (upper bound, conduit income recorded at holding company location). Profit-type return shows ~45% (lower bound, possibly understating zero-tax haven income due to hybrid structures). CbCR usually in between.

(2) Haven share is "flat at around 50%." No source suggests a significant change. Country-level patterns: within profit centers, Bermuda, Jersey, Isle of Man, Gibraltar gained share; Cayman Islands lost share. Within coordination centers, Ireland and Singapore attracted a larger share; Netherlands and Switzerland roughly stable or slightly declining. Gains and losses broadly offset each other.

(3) Employment and tangible assets in havens very low: only 4–9% of foreign employees and 18–23% of foreign tangible assets are in tax havens, primarily in coordination centers (Ireland, Singapore, Netherlands). These shares are stable 2015–2019 "no significant changes in patterns of tax competition for production factors."

Figure 3: Long-run trend in the share of total profits of all US corporations booked in tax havens, 1982–2020.

Calculation method: (share of profits abroad, NIPA) × (haven share of foreign profits, profit-type return, excl. Puerto Rico). Example: 2017: 32% of total profits booked abroad × 46% haven share = ~15% of all US corporate profits in havens "a historical peak." Fell back to 13% in 2020 driven by the slight decline in the foreign share. Was less than 5% in the 1980s and 1990s.

Overall conclusion: "The Tax Cuts and Jobs Act was not followed by a major decline in the fraction of US firms' profits booked in tax havens." Around 13–15% of total US corporate profits booked in tax havens throughout 2015–2020, "a historically high level." This suggests "additional policy efforts have the potential to further reduce profit shifting by US multinational companies" directly reinforcing the rationale for the Global Minimum Tax.

