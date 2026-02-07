# Barake, Chouc, Neef & Zucman (2022) — "Revenue Effects of the Global Minimum Tax Under Pillar Two"
**Intertax, 50(10), 689–710**

## Research Question
How much additional revenue could countries collect from a 15% GMT, and how does revenue distribution differ under IIR vs. QDMTT?

## Data Sources
1. **OECD aggregated CbCR statistics** (FY 2016–2017): 38 parent jurisdictions. Pre-tax profits, taxes paid, employees, tangible assets per parent–partner pair.
2. **Tørsløv, Wier & Zucman (2018, 2019)**: profits booked in havens by HQ country; extends coverage to 83 parent jurisdictions.
3. **Orbis (Bureau van Dijk)**: 182 large-scale purely domestic EU companies (turnover > EUR 750m).
4. **Auxiliary data**: ILO mean nominal earnings (payroll proxy), KPMG statutory CIT rates, ECB exchange rates, IMF WEO GDP growth.

## Methodology
- **Type**: Static microsimulation
- ETR computed as: income taxes paid / pre-tax profits (averaged 2016–2017)
- Top-up tax: Revenue_{pj} = (15% − ETR_{pj}) × [Profits_{pj} − 5% × (Payroll_{pj} + Tangible Assets_{pj})]
- Results scaled to 2021 using nominal GDP growth
- 20% wage premium applied to ILO earnings for MNE employees
- Two polar scenarios: full IIR vs. full QDMTT
- No behavioural adjustment in baseline

## Limitations
- Static (no behavioural adjustment by MNEs or governments)
- Tabulated CbCR masks within-pair heterogeneity (downward bias)
- Double-counting of intra-firm dividends partially addressed
- TWZ data not restricted to EUR 750m firms
- Does not model UTPR or Pillar One interaction

## Thesis Relevance
- **Benchmark simulation**: transparent, replicable methodology using public OECD CbCR data
- Can be updated with newer vintages (2018–2021 now available)
- Can incorporate behavioural adjustments using profit-shifting semi-elasticities
- IIR vs. QDMTT comparison directly motivates distributional analysis
- Key for testing whether revenue estimates hold up ex post

## Detailed notes

p. 689 Globalisation: countries compete for investments; incentive to reduce CIT. Globalisation: MNEs shift earnings to lowest tax jurisdiction; lower amount of effective taxes paid.

Oct 2021: 137 jurisdictions agreed on: 15% global minimum tax (Pillar Two, OECD).
* Income Inclusion Rule (IIR): revenue collected by HQ country.
* Qualified Domestic Minimum Top-up Tax (QDMTT): revenue collected by source country where affiliate of MNE has residence.

p. 690 Paper is first-stage effects without behavioural adjustment.
Global revenue potential GMT: €179 billion; if substance-based carve-outs apply, dependent on income deduction rates: €134-165 billion. EU revenue under IIR: €83 billion; €67 billion without carve-outs. US benefits most under IIR with estimated revenues of €58 billion.


List of tax havens [footnote 1]: This article considers the following jurisdictions as tax havens: Andorra, Anguilla, Antigua and Barbuda, Aruba, Bahamas, Bahrain, Barbados, Belgium, Belize, Bermuda, Bonaire, British Virgin Islands, Cayman Islands, Curacao, Cyprus, Gibraltar, Grenada, Guernsey, Hong Kong, Ireland, Isle of man, Jersey, Lebanon, Liechtenstein, Luxembourg, Macau, Malta, Marshall Islands, Mauritius, Monaco, the Netherlands, Panama, Puerto Rico, Seychelles, Singapore, Sint Maarten, St. Kitts and Nevis, St. Lucia, St Vincent and the Grenadines, Switzerland, Turks and Caicos. This corresponds to the list established by Thomas R. Tørsløv, Ludvig S. Wier & Gabriel Zucman, The Missing Profits of Nations, NBER Working Paper Series, No. 24701 (2018). 

New data:
* Country-by-Country Reports (CbCR) by OECD.
* Foreign Affiliate Statistics (FATS) by Eurostat.

p. 691 OECD/G20 Inclusive Framework on Base Erosion and Profit Shifting (BEPS) Pillar 2 = Global Minimum Tax; minimum top-up tax of 15% on undertaxed profits on a country-by-country basis.

Substance-based carve-outs: reduction in tax base when top-up tax will apply. Subtract 8% of carrying value of tangible assets and 10% of payroll or employee compensation from profits. 10-year transition period where excluded income will decline to 5% for both tangible assets and payroll.

Requirement: global annual turnover €750 million and above. GloBE rules exclude government, international organisations, non-profits, pension and investment funds that are UPE of MNE.

p. 691 OECD CbCR only systematic source on taxes effectively paid by MNEs. Tørsløv, Wier, Zucman (2018, 2019): profits multinationals record in tax havens, broken down by HQ country, how much they report, and effective tax rate. Do not use net income; focus on profit return (obtain profit by making adjustments).

p. 692 OECD and Tørsløv: 40% of MNE foreign profits recorded outside of HQ (36% for Tørsløv).

ORBIS data: used for domestic enterprises with revenue above €750 million. Should apply to pre-tax profits as reported in financial accounts with a number of adjustments "eliminating common gaps between accounting and taxable income".

Reduced by substance-based carve-outs. Tax liability globally determined for each MNE. Tax base calculated under long-run carve-out rates:

$$Tax\ Base_{p,j} = Profits_{p,j} - 5\%(Payroll_{p,j} + Tangible\ assets_{p,j})$$
$Profits_{p,j}$ are profits before tax.


p. 693 Implementation of IIR:

$$Revenue_p = \sum_{j} (15\% - ETR_{p,j}) \cdot Tax\ base_{p,j}$$

Implementation of QDMTT:

$$Revenue_j = \sum_{p} (15\% - ETR_{p,j}) \cdot Tax\ base_{p,j}$$

Assumptions: 10% ETR in all tax havens (conservative assumption), while Tørsløv (2018, 2019) finds ETR of 4.8%. Minimum tax revenue from non-haven imputed by assuming revenue gains from tax havens to non-tax havens in CbCR data applies to extended sample.

CbCR data: downward-biased revenue estimates due to heterogeneity in ETR within country pairs.

p. 694 Revenue gain estimates biased upward via 5 mechanisms: 
- Double counting intra-firm dividends in CbCR reduces ETR; correct if info available.
-  Revenue effects of Pillar One not included.
-  New companies that are exempted are not excluded.
- Tørsløv also includes companies below threshold.
- Partially owned entities under IIR ignored due to simplification of CbCR data.

p. 697 Additional tax revenues EU: collected from foreign profits, 20-40% from undertaxed profits of MNEs in HQ country. Revenues increase more than proportionally with increase in minimum tax rate.

Comparison of revenues under IIR and QDMTT: low-tax jurisdictions would gain most under QDMTT. Luxembourg and the Netherlands account for almost half of EU revenue of QDMTT. Revenue for US would fall from €54 billion to €3 billion since they are the HQ of many large MNEs that report earnings in foreign low-tax jurisdictions.

p. 700 QDMTT distributes revenue over more countries than IIR, since large MNEs are HQ'd in few countries.

Limited revenue effect for domestic companies: entire domestic companies already have high effective tax rates and substance-based carve-outs have significant impact on these firms.

Appendix: OECD computes ETR by ratio of covered taxes to an adjusted accounting income. This paper used income tax paid (on cash basis) in numerator instead of income taxes accrued. Profit before current year income taxes, both will not include deferred taxes.

OECD uses "tangible assets" in denominator. Carve-out composed of tangible assets other than cash and cash equivalents. Payroll component: number of employees $\times$ local mean earnings from ILO data. Substance-based income exclusion: (sum of tangible assets and payroll components) $\times$ carve-out rates. This is then subtracted from pre-tax profits.

If no data, ETR in tax havens assumed to be 10%. Tørsløv has no data about tangible assets and payroll for tax havens; therefore, average effect of substance-based carve-outs in foreign tax havens is imputed based on the effect of carve-outs.

Imputation of non-tax haven revenue gains: use ratio of non-tax haven to tax haven profits. The ratio assumes that ETR in tax havens is 10% while 20% in non-tax haven jurisdictions. Ratio: $\frac{\max(\min\ tax\ rate - 20\%, 0) \cdot profits\ in\ non-havens}{\max(\min\ tax\ rate - 10\%, 0) \cdot profits\ in\ tax\ havens}$

Aggregate country-by-country statistics double count intra-firm dividends and other participation results; not counted as revenue but counted as profits. Dividends subject to no or light taxation; double counting can lead to artificially low ETRs. Rule of thumb correction: broad, assumes all countries double count intra-firm dividends.

Art 5.3.4 December 2022 model rules definition of tangible assets component of substance-based income exclusion: Eligible tangible assets (all "located in that jurisdiction"):
* Property, plant and equipment.
* Natural resources.
* Lessee's right of use of tangible assets located in that jurisdiction.
* Licence or similar agreement from government for use of immovable property or exploitation of natural resources that entail significant investment in tangible assets.

Does not include carrying value of property that is held for sale, lease, or investment. Does not include carrying value of tangible assets used in generation of constituent entity International Shipping Income and Qualified Ancillary International Shipping Income. Treatment of partially owned entities under IIR: need data about subsidiary level. 8.7% are minority shareholders of after-tax profits of multinational groups. 5% when focusing on US parent.
