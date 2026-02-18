# Tax planning by multinational firms: firm-level evidence from a cross-country database

p.3 
Data from Orbis, analyse tax planning by MNE, profit shifting to lower tax rate countries measured by comparing profitability of MNE entities with different links to countries *with* different tax rates. use unconsolidated data. 

1.2 milllion observations of MNE accountes in 46 OECD countes 

Findings: MNE shift profits to lower tax rate countreis and large MNES exploit mismatches between tax systems and preferential tax treatment to reduce tax burde. 

Estimated net tax revenue loss ranges from 4-10% of global corporate tax revenue. 

Anti-avoidance rules decrease profit shifting, also bring higher compliance costs. 

p.7 
gap in literature: "issues of mismatches between tax systems and preferential tax treatment have received much less academic attention than profit-shifting.

limitations orbis: lower representation in US, does not include all MNE entitite, financial accounts rather than tax returns

step that this paper makes: take profit shifting into account between all members of group rather than subsidiary-parent 

emperical strategy baded on Huizinga and Laeven (2008) with regression analysis of profiatbility of MNE entity with similar charasteristics but diffent groups, exploit different links to countreis which means that different opportuniteis to shoft profits. "Profit shifting opportunities are proxied by the differential between the statutory tax rate in the country of an entity and the average rate among the countries where its MNE group is present" 

"On average, MNE entities with links to lower tax rate countries
are found to report lower profits than comparable entities without such links, supporting the profit shifting hypothesis"

"compare the effective tax rate (ETR) of an entity of a multinational group to the ETR of a non-multinational entity on its reported profit (i.e. profit reported in financial accounts, which may differ from taxable profit)."

"n the absence of mismatches, the profit reported in a given
country by a MNE entity would be taxed at the same rate as the profit of a non-MNE entity after controlling for other factors (e.g. industry, size, profitability)."

"ETR differential would also be increased if MNEs exploit country-specific preferential tax regimes for certain activities or incomes to a greater extent than comparable domestic firms, for example by locating all their
patents in countries with preferential tax treatment for patent revenues."

p.8
"MNEs operating in many countries engage more intensively in tax planning than other MNEs"

"international tax planning reduces the effective tax rate of large MNEs by an average 4-8½ percentage points relative to comparable non-multinational firms. This difference is lower (1½-3½ percentage points) for smaller MNEs"


p. 10 
Empirical strategy: identify profit shifting and then effect of mismatches between tax systems and preferential tax treatment jointly

profit shifting: based on Grubert and Mutti (1991) and Hines and Rice (1994) that the observed pre-tax profit of a multinational entity is a sum of the “true” profit and the profit shifted for tax reasons

$$\text{Observed profit}=\text{true profit}+\text{shifted profit}$$

Regression equation: 

$$Profitability_{f,g,c,i,t} = \alpha X_{f,g,c,i,t} + \beta (STAT_{c,t} - STAT\_group\_avg_{g,c,i,t}) + \delta_t + \delta_i + \epsilon_{f,g,c,i,t}$$


- $Profitability$: Defined as the ratio of pre-tax profit over total assets for entity f, in group g, country c, industry i, at year t.
- $X$: Determinants of "true" profitability, including firm size, group position (headquarters, other parent), patenting status, and macroeconomic variables (GDP growth, inflation, etc.).
- Tax Variable $(STAT_{c,t} - STAT\_group\_avg)$: The difference between the statutory tax rate in the entity's country and the unweighted average statutory rate of all countries where the MNE group operates.
- $\beta$: The coefficient of interest (tax sensitivity). A negative $\beta$ indicates profits are shifted to lower-tax countries.

Footnote 3: The authors clarify that the "country of an entity" is defined as the country where it reports financial accounts in ORBIS. This addresses ambiguity regarding hybrid entities that might be incorporated in one country but tax resident in another.

p.11 
prefer the pre-tax profit to total assets ratio as the measure of profitability due to data availability and comparability. "Ideally, the denominator [...] should reflect the 'true' activity of the firm and not be affected by profit shifting". Total assets and employment are considered good proxies for true activity, whereas turnover is rejected as it can be distorted by transfer pricing.


"Profit" refers to total pre-tax profit in unconsolidated account, acknowledge differences between financial profit and taxable profit (e.g., timing of depreciation, definition of income). However, authors argue that reported profit is a relevant proxy because profit shifting generally affects both financial and taxable profit in the same direction. 

p.12
Determinants of Profitability:
- Size: Economies of scale.
- Patents: Associated with higher profitability.
- Fixed Effects: The model controls for time ($\delta_t$) and industry ($\delta_i$). Country Fixed Effects: Ideally, country fixed effects control for time-invariant country characteristics (e.g., labour markets). However, they might also absorb some profit shifting variation (e.g., if most MNEs in a high-tax country are linked to low-tax ones). Therefore, results are presented for three specifications:

Footnote 4: The authors note that for the digital economy (e.g., online services), locating "true" activity is ambiguous. They assume assets/employees represent true activity but admit intangible assets (often underreported) and financial assets (inflated by debt shifting) are limitations.
Footnote 5: Intangible assets are only about 4% of total assets in the sample, largely because self-developed intangibles are often not reported in financial accounts.
Footnote 7: In countries with tax consolidation regimes (e.g., Germany, France), entities might report a fraction of the group's tax payment. This creates noise but is unlikely to bias results.

The tax variable uses the statutory tax rate, considered the most relevant for profit shifting decisions. It is calculated as the difference between the home country rate and the unweighted average of rates in all countries where the group is present.

Positive value: Entity has links to lower-tax countries (incentive to shift profit out).
Negative value: Entity has links to higher-tax countries (likely to receive shifted profit).

This variable avoids endogeneity issues found in studies using weighted averages (where weights depend on profits or sales).

Footnote 14: the difference to the lowest tax rate in the group is an alternative. However, this was rejected because it would treat a company with the lowest rate in the group as having a variable of zero, ignoring whether the gap to the rest of the group is large (high inflow probability) or small.

Page 13

Global Reach and Group Structure
The tax variable includes links to countries outside the OECD/G20 sample (including no-tax jurisdictions) if identified in the database.
Limitation: The group structure might be endogenous; highly productive groups may establish low-tax affiliates specifically to shift profits. This could lead to underestimation of shifted profits because these groups would still report high profits in high-tax countries due to their high "true" productivity.
Costs: Tax planning consumes resources (legal advice), potentially lowering overall pre-tax profitability.

MNE Identification
The study identifies MNE groups using a 50% ownership threshold, iterating through ownership chains to capture complex structures (see Appendix 2). This allows the inclusion of indirect ownership and "treaty abuse" routes. A 50% threshold is standard, as shifting requires control; a 90% threshold is tested for robustness.

Footnote 17: Using weights based on observed profits for the tax variable would bias estimates: "If profits are systematically shifted to lower-tax countries, weights based on observed profits would exaggerate the importance of these countries".

Page 14
Position in the Group
The profitability of headquarters and parent companies differs from subsidiaries (e.g., dividends included in profit, assets holding participations). The model includes dummy variables for:
Group headquarters (has subsidiaries, no parent).
Other parent companies (has subsidiaries and parent).
Non-parent entities.

Headquarters Location
There is a home bias; headquarters often remain in high-tax origin countries despite "inversion" trends. The data shows no clear pattern of HQs being predominantly in high or low-tax countries.


Debt Manipulation: Assessed by comparing the tax sensitivity of total profit (includes financial income/expenses) vs. operating profit (EBIT, excludes financial result).

Intangibles: Assessed by testing if patenting groups have higher profit shifting elasticity.
Footnote 19: Results are robust to excluding companies with subsidiaries (keeping only the lowest tier) to avoid dividend income bias.

Page 15
Direction of Shifting
The analysis splits the tax variable to test if shifting is driven by:
Links to no-corporate-tax countries (difference to zero).
Links to countries with positive but different rates.
Loss-making Firms
A refinement restricts the sample to profitable firms. While loss-making firms pay no tax, they might still shift losses to high-tax countries to offset future profits.
Impact of Anti-Avoidance Rules
The paper tests the effectiveness of rules such as:
Transfer pricing documentation.
Thin capitalisation rules (interest deductibility limits).
Controlled Foreign Company (CFC) rules.
General Anti-Avoidance Rules (GAARs).
Withholding taxes.
The authors use a classification index (0 to 8 scale) developed in Johansson et al. (2016).

Page 16
Figure 1 shows that countries have moved towards stronger anti-avoidance rules between 2005 and 2014.
Testing Effectiveness (Equation 3)
The model is adapted to test if strong rules reduce sensitivity.

p. 17 

$$Profitability = ... + \beta_1 (Tax\_Diff)_{negative} + \beta_2 (Tax\_Diff)_{positive} + \beta_3 AS_{c,2005} + \beta_4 (Tax\_Diff)_{positive} \times AS_{c,2005} + ...$$

The sample is split into firms facing higher-than-average rates (incentive to shift out, positive tax diff) and lower-than-average rates (receiving profit).
The interaction term $\beta_4$ tests if strong anti-avoidance rules ($AS$) reduce the shifting intensity for firms with an incentive to shift out.
$\beta_3$ captures the direct effect of rules on profitability (e.g., compliance costs).

3.2 Mismatches between tax systems and preferential tax treatment
This section investigates schemes that exploit:
Double non-taxation: Income taxable in no country (e.g., "stateless entities").
Double deduction: Expenses deductible in two countries.
Hybrid mismatches: Different treatment of instruments (debt vs equity) or entities across borders.
Preferential treatment: "Patent boxes" or negotiated tax rates.
These strategies reduce the Effective Tax Rate (ETR) relative to domestic firms, even without profit shifting.

Page 18
Methodology for Mismatches
The strategy compares the ETR of an MNE entity to that of a domestic (non-MNE) entity in the same country, controlling for characteristics.
Hypothesis: If MNEs exploit mismatches, their ETR on reported financial profit will be lower than that of domestic firms.
Example: A hybrid instrument treated as debt in the payer's country (deductible) and equity in the payee's country (exempt). The payee reports financial profit but pays no tax, lowering the ETR.
Caveat: Financial tax expense includes deferred taxes (accrual basis), differing from cash taxes paid.
Fixed Costs
Exploiting mismatches involves high fixed costs (legal advice, setting up vehicles). The model assumes larger MNEs are more likely to engage in these schemes.
Footnote 24: An alternative specification uses the ratio of tax expense to operating profit to capture hybrid instruments specifically.

Page 20
Estimation Equation (Equation 4)

$$ETR_{f,c,i,t} = \gamma_1 Large\_firm + \gamma_2 Small\_firm \times MNE + \gamma_3 Large\_firm \times MNE + \gamma_4 X + \delta_i + \delta_{c,t} + \epsilon$$

- $\gamma_2$ and $\gamma_3$: Measure the ETR differential between MNEs and non-MNEs for small and large firms respectively. Negative values indicate exploitation of mismatches.
- $\delta_{c,t}$: Country-year fixed effects ensure comparison happens between firms facing the same statutory rules.
Sample: Restricted to firms with positive pre-tax profit; micro-firms (<10 employees) excluded.

Refinements
The analysis tests if the ETR differential is larger for:
MNEs present in many countries (more opportunities for arbitrage).
Patenting MNEs (exploitation of IP regimes).

Page 21

Source: ORBIS database (Bureau Van Dijk)
Period: 2000-2010.
Coverage: Unconsolidated accounts from 46 countries (OECD, G20, plus others). Covers ~90% of world GDP.
Tax Havens: About 10% of MNEs in the sample have identified links to no-tax countries (Figure 2).
Cleaning: Data cleaned to remove implausible values and outliers (top/bottom 2.5% of profit ratios).
Sample Size: 1.2 million MNE entity observations for profit shifting.
Footnote 27: Winsorising outliers (replacing with threshold values) keeps more observations (1.4m) but makes the sample noisier and reduces the significance of results.

Page 23
Representativeness
Figure 3: Coverage of large firms is >50% in most European countries but <10% in non-European countries (e.g., US coverage is poor for unconsolidated data).
Bias Check: Results are robust to weighting observations to correct for under-sampling.
Group Coverage
The algorithm identifies 50-65% of group members (by assets/profit) when compared to consolidated accounts. This is higher than previous studies (e.g., Huizinga and Laeven, 2008).

Bias could happen if firms outside of ORBIS sample have different propensity to engage in tax planning than. in saemple firm of same country. 

Page 24
Data Sources
Tax Rates: OECD Tax Database, ZEW, KPMG.
Patents: PATSTAT database merged with ORBIS.
Group Definition: A patenting group has a stock of at least 10 patents.
5. Results
5.1 Profit Shifting
Table 1 (Baseline): A 1 percentage point higher tax rate differential is associated with a 0.069 decrease in the profit-to-assets ratio.
Interpretation: For an average entity (profit ratio 6.2%), a 1 pp tax increase reduces reported profit by about 1%.
Fixed Effects: Adding country fixed effects reduces the estimated sensitivity by about 30% (coefficient drops to -0.0453).
Control Variables:
Profitability increases with size and patents.
Headquarters and parent entities have lower profit-to-asset ratios (likely due to asset centralisation).

Page 26
Robustness Checks
Employment: Results hold using profit-to-employment ratio.
EU Sample: Results hold.
Ownership: Results hold with a 90% ownership threshold.
Time: No significant change between 2000-05 and 2005-10.

Page 27
Channels
Debt: The sensitivity of operating profit (EBIT) is not statistically different from total profit (Table A5.3), failing to isolate the debt channel via this method. However, separate analysis (Sorbe et al. 2016) suggests debt manipulation accounts for at least 20% of shifting.
Intangibles: Tax sensitivity is twice as high for patenting MNEs.
Geographic Scope: Sensitivity is significantly higher for groups present in 5+ countries.
Losses: Profit shifting elasticity is higher among profitable firms.
Effectiveness of Anti-Avoidance Rules
Table 2: Strong anti-avoidance rules reduce profit shifting.
Magnitude: Moving from "moderate" (score 3-4) to "relatively strong" (score 5-6) rules reduces profit shifting by about half.
Cost: Strong rules are associated with lower overall firm profitability, independent of tax levels, suggesting high compliance costs.

Page 29
5.2 Mismatches between tax systems
Baseline Results (Table 3)
Large MNEs: ETR is 3.3 percentage points lower than comparable large domestic firms.
Very Large MNEs (>1000 employees): ETR is 4.0 percentage points lower.
SMEs: No significant ETR difference between MNE and domestic entities.
Conclusion: Large MNEs exploit mismatches and preferential regimes; small MNEs do not (likely due to fixed costs).
Robustness
Results hold when controlling for profitability, restricting to manufacturing, or using operating profit. Using a 90% ownership threshold increases the differential to 4.3 pp.

Page 30-31
Refinements
Patenting: The ETR differential is significantly higher for patenting firms (MNEs locate patents in preferential regimes).
Geographic Scope: Higher differential for MNEs in 5+ countries.
Anti-Avoidance Rules: No significant effect of the anti-avoidance index on the mismatch ETR differential (likely because the index focuses on profit shifting rules like transfer pricing, not hybrid mismatches).

5.3 Trends
Figure 4 shows no clear trend in tax planning intensity over 2000-2010. Increases in globalisation/digitalisation may have been offset by stricter enforcement.

Page 32
6. Corporate tax revenue implications
The paper estimates global revenue losses by combining the estimated elasticities with:
Profit Shifting: Redistributes the tax base. Revenue loss occurs because shifted profit is taxed at a lower rate (or zero).
Mismatches: Results in profit not being taxed or deductions duplicated.

Assumptions (Box 2, Page 33)
Extrapolation: Firms outside the sample behave similarly to those inside.
Proportionality: Tax expense changes proportionally to profit shifted.
Formula: Loss $\approx$ (Share of MNEs in profit) $\times$ (Tax Sensitivity) $\times$ (Avg Tax Differential).
Profit Shifting $\beta$: -0.100 (based on profit-making firms).
MNE Share: 40-80% in most countries.

Page 36
Box 3: Book/Tax Differences
Revenue estimates assume tax revenues follow financial profits.
Timing differences: Create noise but no bias.
Permanent differences: Tax planning schemes (e.g., dual residence) reduce taxable profit relative to book profit. These are captured in the "Mismatches" analysis.
Tax Credits: Taking tax credits into account increases the estimated revenue loss estimates (as a % of net revenue).

Page 39
Sensitivity Analysis (Box 4)
Underestimation risks: Missing complex schemes ("unknowns"), lack of data on "stateless" entities, data cleaning removing extreme outliers.
Overestimation risks: Lack of country fixed effects in the revenue calculation parameter.
Adjustment: The final estimates use a range derived from a 95% confidence interval and a scenario where out-of-sample firms are 50% more aggressive.

Page 41
Global Revenue Loss Estimates
Parameters: Weighted average MNE share (59%), weighted average tax differential (3.6 pp).
Result: Net revenue loss for OECD/G20 is 4% to 10% of corporate tax revenues.
Monetary Value: USD 100-240 billion annually (in 2014 values).
Breakdown: ~Two-thirds from profit shifting, ~One-third from mismatches/preferential regimes.

Page 42
Impact on Effective Tax Rates (Table 4)
Tax planning reduces the ETR of MNEs relative to non-MNEs:
Profit Shifting: Equivalent to a 2.0 pp reduction in ETR for all MNEs.
Mismatches: 3.3 pp reduction (for large MNEs).
Total: For large MNE groups, tax planning reduces the ETR by 4 to 8.5 percentage points (5.3 pp point estimate).

Page 43
7. Conclusion
Evidence: Robust evidence exists for both profit shifting and mismatches.
Magnitude: Large MNEs reduce their ETR by 4-8.5 percentage points; revenue losses are 4-10% of global CIT.
Two Tiers:
Large MNEs: Use complex schemes (mismatches, treaty abuse, intangibles) for large reductions.
Small MNEs: Use marginal transfer pricing/debt shifting for smaller reductions.
Policy: Strong anti-avoidance rules reduce shifting (by up to half) but increase compliance costs. Implementation of the BEPS Action Plan is expected to reduce planning but increase burdens.
