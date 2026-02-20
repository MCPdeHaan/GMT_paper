# Riedel (2018) — "Quantifying International Tax Avoidance: A Review of the Academic Literature"

Riedel, N. (2018). Quantifying international tax avoidance: A review of the academic literature. *Review of Economics*, 69(2), 169–181. https://doi.org/10.1515/roe-2018-0004


## p. 169–170 — Section 1: Introduction

**Background and public debate:**
- Post-financial crisis, high-profile cases (Google, Apple, Starbucks, IKEA) triggered public outrage. Media labelled MNEs "modern Robber Barons" (John Simpson, The Telegraph, 2012) and criticised "lousy behaviour" (Larry Elliott, The Guardian, 2013).
- MNEs' defence: fully compliant with existing law; legislators should close loopholes.
- G20 mandated the OECD to develop an action plan → OECD BEPS Action Plan, endorsed by G20 in 2015.

**Known avoidance strategies (anecdotal evidence):**
- **Transfer mispricing**: mis-pricing of intra-firm trade flows.
- **IP location**: strategic placement of valuable intellectual property at low-tax affiliates.
- **Debt shifting**: low-tax entities lend to high-tax affiliates, stripping out tax-deductible interest payments.

**Illustrative example — "Double Irish Dutch Sandwich" (footnote 1):**
- US-based MNC avoids European high-tax rates by selling from an Irish subsidiary (12.5% CIT).
- Patents transferred to a zero-rate haven subsidiary (e.g., Bermuda); income stripped from Ireland via royalties/licences.
- Money routed through a Dutch conduit to avoid withholding taxes (no Dutch withholding tax).
- CFC rules circumvented via a second Irish affiliate managed from Bermuda, exploiting the mismatch between US residence rules (tax resident in Ireland) and Irish residence rules (tax resident in Bermuda).
- Note: Irish tax residence rule changes in 2015 ended this scheme.

**Policy relevance of quantification:**
- Anti-shifting provisions may also distort underlying business activity, increase double taxation risk, and raise compliance/enforcement costs.
- Therefore, welfare consequences of anti-shifting policy depend on the *actual extent* of profit shifting.
- Paper's purpose: assess whether profit shifting is systematic and quantitatively important beyond the singular media cases.

## p. 170–171 — Section 2: Descriptive Evidence

**Naive observation:** MNE presence in tax havens and low aggregate ETRs seem to prove profit shifting. But caution is required:
- Low ETRs may also reflect high tax-deductible investment expenses or loss-carryforwards (non-avoidance).
- Tax havens often offer more than just low rates: good governance, public infrastructure, developed financial and labour markets (e.g., Switzerland, Ireland). Corporate location decisions may be driven by these non-tax factors.

**Tax haven presence data (footnote 2):**
- Desai, Foley & Hines: in 1999, more than every second US-based MNE had some presence in tax haven countries (per standard tax-haven lists, see Dharmapala & Hines).
- Gumpert, Hines & Schnitzer: 25% for German-based MNEs (lower figure may relate to reporting thresholds excluding small foreign entities).
- BEA aggregate data: ~40% of (foreign) net income of US firms is located in tax havens (Dharmapala).

## p. 171–173 — Section 3: Indirect Evidence — Pre-Tax Profits and Corporate Tax Rates

**Main empirical approach in the literature:**
- Compare pre-tax profits of high-tax vs. low-tax affiliates: income shifting reduces the former and increases the latter.

**BEA-based evidence:**
- Sullivan and Clausing: strongly elevated pre-tax profitability rates at tax-haven affiliates of US MNEs.
- Caveat (footnote 3): BEA data includes equity investment income in foreign affiliates' pre-tax income, which may cause double-counting of income and artificial profits at low-tax holding companies. Example: manufacturing affiliate in high-tax country earns USD 1,000; after 40% tax, remits USD 600 in dividends to a tax-haven holding company. BEA data shows USD 600 after-tax profits in *both* affiliates — overstating haven-side profitability. (See Altshuler & Grubert and Dharmapala.)

**Improvement in methodology:**
- More recent papers use other firm databases (accounting information) and estimate regression models controlling for country and affiliate-specific profit determinants.
- Later papers exploit *changes* in affiliates' reported pre-tax profitability in response to CIT reforms (difference-in-differences logic), which controls for time-constant unobserved heterogeneity.

**Key result — consensus estimate:**
- All studies report an inverse relation between CIT rate (differential) and affiliates' reported pre-tax profits.
- **Heckemeyer & Overesch (2017) meta-analysis:** consensus semi-elasticity = **0.8**, meaning a 10 percentage point increase in the host country CIT reduces affiliates' reported pre-tax profits by **8%**. I.e., from every €1,000 earned at a high-tax location, MNEs would shift €80 more to lower-tax entities after such an increase.

**Three alternative mechanisms that could produce the same empirical pattern** (without actual profit shifting):

1. **Strategic sorting of projects**: MNEs route high-return projects to low-tax affiliates → negative correlation between taxes and profitability without paper profit shifting.
2. **Required pre-tax return**: high CIT rates require higher pre-tax return for investment → *positive* correlation (works against the profit shifting hypothesis, so estimates would understate true shifting).
3. **Effort provision**: higher taxes reduce owner-manager effort or alter incentive contracts → negative correlation between pre-tax profits and CIT rates.

Implication: interpreting the estimates as evidence of paper profit shifting assumes these alternative mechanisms are minor. Depending on which dominates, the true shifting extent could be understated (mechanism 2) or overstated (mechanisms 1 and 3).

Additional caveats (footnote 5): lack of book-tax conformity in accounting data; worldwide taxation systems; reporting exemptions excluding small firms.

**Revenue loss estimates from this approach:**
- Clausing (2009, 2011): revenue costs for US in 2004 = $60 billion; in 2008 = $90 billion; ≈ 30% of US CIT revenues. Note: Clausing's tax-sensitivity estimate = 3.3, much larger than the 0.8 consensus. Interpret with care.
- Dowd, Landefeld & Moore (2017, footnote 7): log-linear specifications may severely understate tax sensitivity of profits in low-tax jurisdictions while overstating it in high-tax jurisdictions — heterogeneity in elasticities matters.
- **OECD BEPS Action 11 (2015):** global CIT revenue lost from BEPS = **$100–240 billion**, or **4–10% of global CIT revenues**.

## p. 173–175 — Section 4: Alternative Approaches — Profitability Shocks and Corporate Twins

Two approaches that do **not** rely on tax rate variation for identification, and are therefore not subject to the alternative mechanism concerns above.

**Approach 1 — Profitability shocks (Dharmapala & Riedel, 2013):**
- Exploits positive profit shocks at high-tax affiliates to test for income shifting.
- Argument: if MNEs shift income, positive shocks at high-tax locations should partly translate into higher reported income at the group's *low-tax* affiliates (but *not* at other high-tax affiliates).
- Profit shocks modelled using changes in industry profitability in a given country (European firm data).
- Findings: MNEs shift around **2% of additional income** to lower-tax entities.
- This is likely a **lower bound** for three reasons:
  1. Profit shocks are constructed for parent firms; MNEs are more reluctant to shift income away from headquarters than from high-tax subsidiaries (Dischinger, Knoll & Riedel).
  2. The average tax rate differential between parents and lower-tax subsidiaries in the sample is relatively small → limited shifting incentives.
  3. Subsidiaries in the same industry as the parent are excluded (subject to same shock), which may exclude intra-firm trade shifting in related industries.
- Footnote 8: the tax-sensitivity approach in Section 3 would predict ~4% shifting in the same sample (average tax rate differential of 7.7% × semi-elasticity of 0.5 from Dischinger, Knoll & Riedel).

**Approach 2 — Corporate twins (Egger, Eggert & Winner, 2010; Finke, 2013):**
- Compares corporate tax payments of MNEs vs. domestic national enterprises (NEs) using matching techniques to identify "twins" (matched on: age, size, industry, productivity, host region).
- Egger et al. (2010, European high-tax countries): MNEs' CIT burden is more than **30% lower** than comparable NEs.
- Finke (2013, Germany): MNE-NE gap = **27% in 2007**, declining after the 2008 German CIT reform (attributed to lower headline rate and tighter thin-capitalisation rules).
- **Achilles' heel:** matching estimates are biased if unobserved tax-determinants differ systematically between MNEs and NEs:
  - MNE managers may be more aggressive in exploiting tax planning.
  - MNEs may engage in more extensive government lobbying (possibly involving fixed costs → only large firms lobby; footnote 9) and receive firm-specific tax benefits (laxer audits).
  - Governments may grant firm-specific tax reductions to MNEs to prevent relocation.
- All three arguments imply part of the observed gap could reflect non-shifting mechanisms.

## p. 175–176 — Section 5: Other Estimates — Tax Authorities and NGOs

**HMRC (UK, 2014):**
- Tax avoidance gap for large businesses = **£1.1 billion in 2012/13** = approximately **5% of theoretical tax liabilities**.
- Small and medium firms: £0.1 billion.
- Large firms account for lion's share of total CIT gap of £3.9 billion.
- Likely a **lower bound**: relies on internal case management knowledge; tax specialists unlikely to identify all avoidance schemes.
- Note: HMRC does not distinguish between international and domestic avoidance, nor between avoidance and evasion/filing errors/criminal activity.

**TUC (2008) and The Guardian (2009) — UK:**
- Methodology: compare tax paid (as declared in accounts) with estimated tax due.
- Shortcoming: does not account for deliberate structural elements of the tax system reducing liabilities (capital allowances, R&D tax credits, loss carry-forwards) or genuine commercial reasons for paying tax in other jurisdictions.
- TUC (2008): avoidance gap ≈ **£12 billion in 2006** (UK) — likely substantially **overstated** and possibly by a wide margin.

**Murphy (2012) — EU (footnote 11):**
- Estimates income tax gap (evasion + avoidance, firms + individuals) in the EU at >**€1 trillion**; lion's share from evasion. Avoidance losses quantified at **€150 billion per year**.
- Based on simple average of tax authority estimates and TUC methodology — may over- or underestimate.


## p. 176–178 — Section 6: Analysing Specific Relocation Channels

Most credible evidence; more direct tests with less room for confounding mechanisms.

**Channel 1 — Transfer mispricing of intra-firm trade:**

- Clausing (2003): US trade data; 1 percentage point drop in foreign CIT rate reduces intra-firm export prices by **1.8%**.
- Bernard, Jensen & Schott (2006): confirms Clausing using US export prices linked to firm-level data. Average intra-firm vs. extra-firm price wedge = **43%**, also dependent on foreign CIT rates. (Footnote 13: accounts for potential bias from MNEs and NEs trading systematically different goods within same product group.)
- Cristea & Nguyen (2016): Danish firms; after establishing a first foreign subsidiary in a low-tax country, MNEs reduce prices for exports from Denmark by **5.7%**. Associated tax revenue loss = **3.2% of Danish MNEs' tax returns**. Likely lower bound (limited to manufacturing; excludes IP transactions). Note (footnote 14): Cristea & Nguyen argue MNEs strategically deviate extra-firm trade prices towards the transfer price to comply with the arm's-length principle — this implies Bernard et al. *underestimate* the mispricing effect; Cristea & Nguyen's approach is immune to this concern.
- Davies et al. (2018): similar evidence for France; "lion's share of income shifting relates to a minority of only 400 multinational groups" and their export flows to tax haven economies.

**Channel 2 — Strategic location of intangible property:**

- Dischinger & Riedel (2011): location of valuable intangibles is systematically distorted towards low-tax locations.
- Karkinsky & Riedel (2012): data on corporate patent holdings of European MNEs. A **1% increase in CIT rate reduces patent holdings by approximately 3.5%**. (See also Griffith, Miller & O'Connell (2014) and Alstadsæter et al. (2017) for similar evidence.)
- Baumann et al. (2017): MNEs strategically relocate patents with **above-average value** to tax havens (not just average patents).

**Channel 3 — Debt shifting:**

- Mechanism: MNEs inject equity into low-tax subsidiaries, which then lend to high-tax affiliates, stripping out tax-deductible interest without raising the group's overall debt-to-equity ratio or bankruptcy risk.
- Key papers: Altshuler & Grubert; Desai, Foley & Hines; Büttner & Wamser (2013); Møen et al. (2012).
- Footnote 16: Büttner & Wamser and Møen et al. note that debt-shifting incentives relate both to the host country CIT rate *and* to the CIT rate of the lowest-tax affiliate in the group.
- Reported semi-elasticity ≈ **1**: a 10 percentage point increase in local statutory CIT rate is associated with a **10% increase in the affiliate's internal debt ratio**.
- However, because internal debt holdings tend to be small and transferred income = internal debt × interest rate, the **absolute debt-shifting volumes are relatively small**.
- **Heckemeyer & Overesch (2017) meta-analysis (footnote 17):** debt shifting accounts for approximately **30% of overall income shifting** activities; mispricing of intra-firm trade accounts for approximately **70%**. (Methodology: compare CIT sensitivity of operating income/EBIT — captures transfer pricing and IP location — vs. pre-tax profit — also captures financial income/debt shifting. Difference isolates the debt component.)

**Other avoidance channels (footnote 12):**
- Tax treaty shopping: Collins & Shackelford; Desai, Foley & Hines; Weichenrieder & Mintz provide empirical evidence consistent with treaty shopping.
- Hybrid mismatch arrangements: Johannesen (2014) discusses theoretically; no systematic empirical evidence available as of this paper.

## p. 178–179 — Section 7: Conclusions

**Qualitative finding:** All studies find evidence *consistent with* international tax avoidance by MNEs across different data sources and estimation strategies.

**Quantitative range:** Results vary substantially:
- Lower end: MNEs transfer **less than 5%** of high-tax income to low-tax entities.
- Upper end: **30% or more**.

**Comparison with media reports:** Academic evidence points to *smaller* shifting volumes in the population of medium-sized and large MNEs than high-profile media cases (e.g., groups with virtually no taxable income in high-tax countries). Note: most academic studies use accounting data from private providers, covering medium-sized and large firms only (footnote 18) — not necessarily representative for the full population.

**Most credible evidence:** Channel-specific studies, as their empirical tests are more direct with less room for confounding mechanisms. However, these studies are still scarce and some BEPS strategies (e.g., hybrid mismatch arrangements) have no empirical evidence at all.

**Conclusion on state of knowledge:** "It is thus too early to draw final conclusions on the quantitative importance of international tax avoidance activities."

**Future progress depends on data access:** Progress in quantifying BEPS and assessing the effectiveness of anti-shifting provisions critically depends on whether researchers can access high-quality data identifying MNEs' reported tax bases, tax liabilities/payments, and business activity across group locations. Many tax authorities have so far been restrictive in providing access to anonymised corporate tax return and audit data.
