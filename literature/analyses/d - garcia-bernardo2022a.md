# Garcia-Bernardo, Janský & Zucman (2022) Did the Tax Cuts and Jobs Act Reduce Profit Shifting by US Multinational Companies?
NBER Working Paper 30086


## Abstract

- The 2017 Tax Cuts and Jobs Act (TCJA) lowered the US corporate tax rate and introduced provisions against profit shifting.
- The share of profits booked abroad by US multinationals fell 3-5 percentage points after the reform, mainly driven by repatriations of intellectual property (IP) to the US.
- The share of foreign profits booked in tax havens remained stable at around 50% between 2015 and 2020.
- Changes in the global allocation of profits are small overall, but some individual firms responded strongly.



## p. 2 — Introduction

- Large literature documents profit shifting by MNEs. Recent estimates: "close to 40% of multinational profits — profits booked by firms outside of their headquarter country — are shifted to tax havens globally" (citing Garcia-Bernardo and Janský 2021; Tørsløv et al. forthcoming).
- US multinationals in particular book a large fraction of foreign income in low-tax places (Clausing 2020b; Dowd et al. 2017; Guvenen et al. 2022).

Three main reforms introduced by the TCJA (enacted end of 2017):
- US corporate tax rate reduced from 35% to 21%, narrowing the gap between US and foreign rates.
- Switch from a worldwide system (foreign profits taxed upon repatriation) to a territorial system (foreign profits generally exempt from US tax). Note: in practice both old and new systems are hybrid with anti-avoidance provisions.
- Three specific anti-profit-shifting provisions: (1) GILTI — a US minimum tax on foreign income subject to low tax rates; (2) FDII — a reduced rate on foreign income from intangibles booked in the US; (3) measures to limit deductibility of payments suspected to shift income out of the US (BEAT).

Research questions asked in this paper:
- Has the international allocation of US firms' profits changed post-TCJA?
- Has profit booked in tax havens declined? If so, is more profit booked in the US or in other high-tax countries?
- This matters for evaluating the need for further international reform, i.e. the global minimum tax (OECD, 2021).

Main contribution: "first comprehensive analysis of trends in profit shifting after the Tax Cuts and Jobs Act." Prior data delays had prevented this — the 2019 BEA survey was published November 2021, and the 2019 IRS country-by-country statistics only in April 2022.

Prior work limited to case studies: Sullivan (2020) found no evidence of profit being shifted back to the US for the largest 10 pharmaceutical MNEs; Coffey (2021) studied Ireland specifically. This paper covers US firms as a whole, up to 2019 or 2020.

Methodological contribution: reconciling and harmonising all available data sources (BEA surveys, Compustat, IRS CbCR), paying attention to double-counting in country-by-country data (building on Horst and Curatolo 2020).

Main findings:
- Share of profits booked abroad fell ~3-5 percentage points, to about 27% for all US companies. Driven by a handful of large firms (Alphabet, Microsoft, Facebook, Cisco, Qualcomm, Nike) repatriating IP to the US — these firms account for most of the macroeconomic decline.
- Share of foreign profits in tax havens: stable at ~50% across 2015-2020, consistent across all data sources.
- Share of total (domestic + foreign) US profits in tax havens: remained ~13-15% throughout 2015-2020, a historically high level.



## p. 5–7 — Section 2: Data on the Profits of US Multinational Companies

Three main data sources used:

### 2.1 BEA Survey Data (p. 5)

- Bureau of Economic Analysis conducts mandatory quarterly, annual, and benchmark surveys of foreign operations of US MNEs.
- Quarterly surveys: data on profits of foreign affiliates in which a US investor owns >10% stake, net of foreign income taxes and pro-rated by ownership stake — published as "direct investment equity income."
- Annual surveys: also report "profit-type return" — not pro-rated by ownership stake (majority-owned affiliates only, not minority), and gross of foreign income taxes.
- Benchmark surveys every 5 years; most recent annual survey used is 2019 (also a benchmark year).

Difference between direct investment income and profit-type return in how profits are allocated across countries:
- Direct investment income: income assigned to country with which US parent has direct link (following BoP guidelines). So if a German affiliate is owned via a Dutch holding, income is recorded in the Netherlands.
- Profit-type return: income assigned to where operating income is earned. Same case: recorded in Germany.
- Annual surveys also report "net income," which double-counts income through chains of affiliates — not used here.

Important caveats on measurement bias direction:
- Profit-type return can understate haven income (misses schemes like hybrid structures and hybrid dividends that shift taxable but not accounting income — fn. 3 gives Google/Bermuda case: Google Holdings incorporated in Ireland but taxable in Bermuda, paid zero Irish tax, profits likely assigned to Ireland in profit-type return but should be in Bermuda).
- Direct investment income likely overstates haven income, because income to holding companies in havens may have already been taxed in operating countries.

### 2.2 Corporate Financial Statements / Compustat (p. 6)

- S&P Compustat North America: public financial statements (10-K SEC filings) of listed companies.
- Compustat only covers listed firms, not private companies.
- Most listed firms report US vs. non-US profit split, but not a country-by-country breakdown.

### 2.3 Country-By-Country Tax Data (p. 7)

- IRS form 8975 tabulations: covers all US-headquartered MNEs with annual revenue over $850 million.
- 2016 reporting was voluntary (data incomplete); compulsory from 2017 — the paper does not use 2016 data.
- Advantage: reflects where income is allocated for tax purposes. IRS instructions state a business entity is "generally considered a resident in a tax jurisdiction if, under the laws of that tax jurisdiction, the business entity is liable for tax therein." So unlike profit-type return, Bermuda-taxable entities should logically be assigned to Bermuda here (paper confirms this in Section 5).
- Additional advantage: CbCR reports Puerto Rico separately (BEA excludes it as not a foreign jurisdiction) and provides separate data for profit-making vs. all affiliates (allowing meaningful ETR computation).
- Main drawback: profits can be double-counted because until 2020, OECD guidelines did not explicitly instruct companies to remove intra-group dividends from profits, which causes multi-counting when dividends flow through chains of holding companies. The paper addresses this (Section 3.2).



## p. 8–11 — Section 3: Methodology

### 3.1 Aggregate Domestic and Foreign Profits (p. 8–9)

Four aggregate series constructed, each targeting a different sample:

Macroeconomic accounts (all corporations):
- Total domestic profits: NIPA corporate profits (Table 1.12 line 13) minus Federal Reserve profits, minus net portfolio dividends from rest of world, minus direct investment equity income with current-cost adjustment.
- Total foreign profits: pre-tax direct investment equity income = direct investment equity income (without current-cost adjustment), divided by (1 minus foreign effective income tax rate of majority-owned affiliates), plus the current-cost adjustment. The current-cost adjustment converts book depreciation to economic depreciation, making this comparable to NIPA profits.
- Both series on pre-tax basis and with economic depreciation — the most comprehensive and consistent measure.

BEA survey (multinationals only):
- US profits = profit-type return of parents.
- Foreign profits = profit-type return of majority-owned affiliates.
- Both net of book (not economic) depreciation.

Compustat (listed firms):
- Global profits = variable "pi"; foreign profits = variable "pifo."
- Since 2010, foreign profits available for ~95% of listed firms (weighted by global profit).

Country-by-country data (multinationals with >$850M revenue):
- Requires double-counting correction — developed by building on Horst and Curatolo (2020).
- Method: estimate what total domestic and foreign profits should be (using Compustat for listed companies, with regression imputation for ~120 firms with missing "pifo," and 20% of average profits for ~150 private companies not in Compustat), then re-scale CbCR data to match these estimated totals.
- Results of correction: total profits in CbCR were over-estimated by 48% in 2017, 72% in 2018, 47% in 2019. Over half of this double-counting involves domestic profits.

### Consistency across sources (p. 10–11)

Table 1 shows aggregate foreign pre-tax profits for 2019: $656bn (direct investment equity income), $523bn (profit-type return), $603bn (corrected CbCR), $560bn (Compustat). Differences reflect sample differences (e.g. profit-type return excludes minority-owned affiliates; Compustat excludes private firms).

### 3.2 Share of Foreign Profits in Tax Havens (p. 10–11)

- Preferred measure for allocating foreign profit across jurisdictions in BEA data: profit-type return (not direct investment income).
- Tax haven list (following Zucman 2014): Bermuda, Ireland, Luxembourg, Netherlands, Singapore, Switzerland, UK Caribbean.
- Puerto Rico imputed from IRS form 8975 and added to the haven list for comparability with CbCR (does not affect trend results around TCJA).
- This list is noted to be conservative — it excludes havens not separately identifiable in BEA (e.g. Jersey, Malta, Mauritius).
- Direct investment income series used as upper bound; profit-type return as conservative lower bound.
- For CbCR (which has wider country coverage): extended list includes additionally Barbados, Gibraltar, Hong Kong, Isle of Man, Jersey, Malta, Mauritius.



## p. 12–15 — Section 4: Evolution of the Share of Profits Made Abroad

### 4.1 Foreign vs. Domestic Profits: Aggregate Data (p. 12)

Figure 1a: share of profits booked abroad, 1982-2020, across all four sources.

Key findings:
- Foreign profit share ranges from 30–45% across sources in 2019-2020. Listed companies (Compustat) highest, as they are larger and more international. All US corporations (NIPA) lowest, because it includes small domestic-only firms. Corrected CbCR in between BEA and Compustat.
- In all series, foreign profit share fell 3-5 percentage points between 2017 and 2020. Clear directional consistency across sources.
- Sector breakdown (Figure A2): decline is "across-the-board" but more pronounced in the Information sector.
- Important caveat: the decline could be caused by factors other than the TCJA (e.g. differential timing of business cycles).

### 4.2 Firm-Level Analysis (p. 13–15)

Methodology: identify all Compustat firms with (i) positive profits over 2017-2020, (ii) revenue >$10bn in at least one year, and (iii) a sustained decline (lasting through 2020) in foreign profit share of 20 percentage points or more post-TCJA. Then manually check annual 10-K reports.

Results (Figure 1b, Table A2):
- 23 such firms identified (10.5% of 219 eligible firms).
- 6 firms unambiguously (or very likely) profit-shifting related: Alphabet, Cisco, Facebook, Microsoft, Nike, Qualcomm. All related to IP repatriation.
  - Alphabet 10-K (2019): "we have simplified our corporate legal entity structure and now license intellectual property from the U.S. that was previously licensed from Bermuda."
  - Microsoft 10-K (2019): "we transferred certain intangible properties held by our foreign subsidiaries to the U.S. and Ireland" in response to TCJA.
  - Qualcomm 10-K (2019): "one of our Singapore subsidiaries distributed certain intellectual property to a U.S. subsidiary."
  - Nike 10-K (2020): restructuring of IP interests to benefit from FDII.
  - Facebook and Cisco: identified via symmetric movement of domestic and foreign profits.
- 6 additional firms: limited/possible evidence of profit-shifting change (incl. Pfizer, HP, Netflix, Metlife).
- 11 firms: no evidence of profit-shifting change (e.g. Walmart — foreign subsidiary sale; Coca-Cola, Thermo Fisher, Salesforce — rapid increase in domestic profits; Ball Corporation — abnormally high foreign profits in 2017 baseline).
- ~90% of eligible listed firms show no large change (>20pp) in foreign earnings share.

Counterfactual bounds (contribution of profit-shifting changes to the aggregate decline):
- Lower bound (6 confirmed firms only): the foreign profit share of US corporations would be 2.8 percentage points higher in 2020 absent the shifts. These 6 firms would have booked an estimated $61bn extra abroad.
- Upper bound (all 22 firms with >20pp drop): foreign income share would be 4.2 points larger in 2020.
- Implication: profit-shifting changes can account for a significant fraction of the overall 3-5pp aggregate decline, and the repatriation of IP by a few large tech companies drives most of the drop.

Two important remarks:
- Incentive consistency: FDII taxes royalties on IP booked in the US at 13.125%; GILTI creates a minimum tax on low-taxed foreign income. Both push towards repatriating IP to the US.
- Confounding factors: Ireland phased out the "Double Irish" in 2020. Alphabet would likely have restructured regardless of the TCJA (its structure involved an Irish-incorporated but Bermuda-taxable entity). This means "the observed decline in the foreign income share of US companies should probably be seen as an upper bound for the effect of the Tax Cuts and Jobs Act."



## p. 16–19 — Section 5: Evolution of the Geography of Foreign Profits

Figure 2 (panels A, B, C): share of foreign profits, employees, and tangible assets, 2015-2020.

Classification of havens (following Reurink and Garcia-Bernardo 2020):
- "Profit centers" (primarily for profit booking, little production): Bermuda, Cayman Islands, Puerto Rico, Jersey, Isle of Man, Gibraltar, Barbados, Mauritius, British Virgin Islands, Bahamas, Malta.
- "Coordination centers" (profit booking plus management/coordination): Singapore, Netherlands, Switzerland, Ireland, Luxembourg, Hong Kong.

Key findings across all sources (direct investment income, profit-type return, CbCR):

Haven share level: about 50% of foreign profits of US MNEs booked in tax havens in recent years. Higher in direct investment income (~55%) than in profit-type return (~45%), with corrected CbCR in between. Profit-type return = conservative; direct investment income = upper bound.

Haven share trend: stable at ~50% throughout 2015-2020. "No source suggests a significant change in the haven share of foreign profits."

Country-level patterns within havens:
- Profit centers: Bermuda, Jersey, Isle of Man, Gibraltar share increased; Cayman Islands share fell.
- Coordination centers: Ireland and Singapore attracted larger share consistently; Netherlands and Switzerland stable or slightly declining. "Overall gains and losses at the haven-level broadly offset each other."

Cross-source differences on individual havens:
- More profit assigned to Bermuda in CbCR than in profit-type return (consistent with the taxation-based CbCR definition picking up Bermuda-taxable entities).
- More profit in conduit countries (Luxembourg, Netherlands) in direct investment income (BoP-based allocation to direct-link countries).

Contrast with employment and tangible assets:
- Only 4-9% of foreign employees and 18-23% of foreign tangible assets located in tax havens (Figure 2B and 2C). Stable over 2015-2019.
- "The high concentration of foreign profits in tax havens contrasts with the dispersion of employment and tangible assets."
- No significant changes in patterns of tax competition for production factors.

Combined result (Figure 3 — long-run series back to 1982):
- Constructed as: (share of profits abroad) × (share of foreign profits in tax havens).
- In 2017: 32% of US corporate profits booked abroad × 46% (profit-type return) in havens = ~15% of total US corporate profits in tax havens — a historical peak.
- This fell to ~13% in 2020, driven by the decline in the foreign profit share.
- Note: haven share was less than 5% in the 1980s-1990s.
- Puerto Rico excluded from Figure 3 due to lack of long-run data; including it would raise the haven share throughout.

Concluding paragraph of main text: "In 2018–2020, US multinational corporations booked a similar share of their foreign profits in tax havens — around half — as in the years immediately preceding the reform." The paper concludes that additional policy measures have the potential to further reduce profit shifting, implicitly motivating the Global Minimum Tax.



## Appendix A — Domestic and Foreign Profits in the National Accounts

Computation of foreign pre-tax profits (p. 22-23):
1. Start with direct investment equity income received without current-cost adjustment (e.g. $420bn in 2016).
2. Convert to pre-tax by dividing by (1 minus foreign ETR of majority-owned affiliates). ETR in 2016 = $87bn / $434bn = 20.0%, so $420bn / 0.8 = $525bn.
3. Add BEA current-cost adjustment ($21bn in 2016) → total foreign pre-tax = $546bn.

Computation of domestic pre-tax profits:
1. Start with NIPA corporate profits as included in national income (e.g. $2,038bn in 2016) — includes foreign income net of foreign taxes.
2. Subtract Federal Reserve profits ($93bn), net portfolio dividends from rest of world ($218bn - $139bn = $79bn) → global income of US-headquartered corporations = $1,866bn.
3. Remove foreign profits (direct investment equity income with current-cost adjustment = $441bn) → domestic income = $1,425bn.

Foreign share in 2016: $546bn / ($546bn + $1,425bn) = 28%.



## Appendix B — Correction of Country-by-Country Data

### B.1 Double-Counting Correction (p. 23–25)

Root cause: OECD CbCR guidelines only changed in 2020 to explicitly require removal of intra-group dividends from profits. For 2017-2019, companies could include tax-exempt intra-group dividends as profit, leading to multi-counting through chains of holding companies.

Correction method (building on Horst and Curatolo 2020):
- Use Compustat data (via WRDS) to estimate theoretical profits for the CbCR-eligible population ($850M+ revenue).
- Variables: pifo (foreign profits), txfo (foreign taxes), pi (total profits), txc (total taxes), at (total assets), intan (intangible assets), emp (employees), revt (revenues).

Cleaning steps:
1. Keep industrial reporting format (indfmt=="INDL").
2. Keep US-headquartered MNEs (loc=="USA") → 7,789 / 7,821 / 7,651 companies for 2017/18/19.
3. Keep companies with revenue >$850M → 1,741 / 1,756 / 1,737.
4. Drop firms lacking foreign profit or foreign tax data → 1,444 / 1,468 / 1,443.

- For the ~120 firms with missing pifo: model log(foreign profits) on log(assets, revenue, intangibles, employees, foreign tax accrued) to impute values.
- For ~150 private companies in CbCR but not Compustat: assign 20% of average profits of non-missing observations (these are smaller, private firms).

Estimated total profits for CbCR-eligible population: $1,361bn (2017), $1,514bn (2018), $1,513bn (2019).
Reported in CbCR (excl. stateless entities): $1,818bn (2017), $2,406bn (2018), $2,064bn (2019).
Implied double-counting: 34% (2017), 59% (2018), 36% (2019).

Breakdown:
- Domestic double-counting: 54% / 74% / 42% ($415bn / $632bn / $385bn) in 2017/18/19.
- Foreign double-counting: 7% / 39% / 28% ($42bn / $260bn / $166bn) in 2017/18/19.
- Including stateless entities adds ~$200bn to foreign double-counting in both 2017 and 2018.

Country-level correction: double-counting removed proportionally from profits of profit-making entities, concentrated in tax havens and conduit countries.
- UK treated as partial conduit → double-counting removed.
- Ireland excluded from correction: ETR ~12% (close to statutory), and Irish profits in CbCR lower than in other sources (possibly because Double Irish structures assign profits to Bermuda/stateless entities rather than Ireland in CbCR).

### B.2 Reconciliation with Other Sources (p. 25)

After correction, all sources broadly agree on aggregate foreign profits:
- 2017: corrected CbCR = $596bn vs. $570-669bn in other datasets.
- 2018: $658bn vs. $580-694bn.
- 2019: $602bn vs. $547-671bn.



## Appendix C — Changes in Profit Shifting at the Firm Level (p. 26–27)

Sample: listed firms, >$10bn revenue, remained profitable 2017-2020, sustained 20pp drop in foreign profit share post-TCJA vs. previous 3-year average, concurrent with no sharp change in total profits.

Evidence criteria for profit-shifting change:
- (1) Annual report explicitly mentions change in profit-shifting behavior (intra-group transfer of intangibles — patents, trademarks, copyrights; or intra-group lending), or
- (2) Domestic and foreign profits move almost symmetrically (rise in domestic / symmetric fall in foreign).

Key confirmed cases (Table A2):
- Alphabet: 36pp drop in 2020, estimated $17.3bn extra domestic profits in 2020. Explicit IP repatriation from Bermuda cited in 10-K.
- Microsoft: 21.5pp drop in 2019, $16.3bn. IP transferred to US and Ireland in response to TCJA regulations.
- Facebook: 43.1pp drop in 2020, $14.3bn. Symmetric movement of domestic/foreign profits.
- Cisco: 28.5pp drop in 2019, $4.2bn. Symmetric movement.
- Qualcomm: 88.8pp drop in 2019, $4.7bn. Singapore subsidiary distributed IP to US subsidiary.
- Nike: 36.4pp drop in 2019, $4.5bn. Restructuring of IP to benefit from FDII.

Possibly related cases include Pfizer (change in intra-group lending), HP, Metlife, Netflix (explicit corporate structure simplification mentioned but quantitative evidence less conclusive), Abbott Laboratories, Newmont.

Unrelated cases: Walmart (foreign subsidiary sale loss), Coca-Cola / Thermo Fisher / General Motors Financial / Salesforce / Paypal (domestic profit increases), Ball Corporation / Mondelez (abnormal baseline profits), Quanta Services / Stonex (volatile low profits).
