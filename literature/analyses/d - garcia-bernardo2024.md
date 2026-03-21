
# Profit Shifting of Multinational Corporations Worldwide
Javier Garcia-Bernardo, Petr Janský

**p.1**

Use Country-By-Country Reporting data (CBCR): distributional consequences of profit shifting. MNEs shifted $850 billion in 2017, mostly to countries with ETR below 10%. Lower income countries lose larger share of total tax revenue due to profit shifting. Log function better due to nonlinear relationships between profits and tax rates, compared to linear/quadratic functions.

Corporate tax avoidance problematic cause affects efficiency and equity of financial markets and societies.

RQ: What is scale of profit shifting? Which tax haven largest? Which MNEs most aggressive in profit shifting? Which countries lose most relative to total tax revenues?

Profit shifting as form of tax avoidance cannot be directly observed and unclear how economists should estimate it.

**p.2**

CBCR most reliable data. But still groups small countries into categories (e.g. Other Africa) and double counting of profits due to unclear intercompany dividends and stateless entities => methodological solution for this.

New methodology for non-linear relationship profit location and tax rates with log function since 85% of profits in countries with tax rates below 10%.

4 findings:
- MNEs shift over $850 billion profits to tax havens in 2017, $200-300 billion revenue loss for other countries, semi-elasticity estimates that are consistent with higher shares of profits in tax havens.
- Shifting to countries with extremely low ETR (Cayman Islands, Luxembourg, Singapore, Canada, The Netherlands, Switzerland, Hong Kong, Bermuda, Puerto Rico, Ireland). Quadratic and linear model incapable of capturing extent of profit shifting.
- High income countries capture most of tax revenue gains due to being destination of profit shifting.
- MNEs with HQ in US, Brazil and Singapore most aggressive in profit shifting. Differences across countries in terms of outbound profit shifting.
- Which countries lose more tax revenue due to profit shifting: lower income countries lose more tax revenue due to profit shifting relative to total tax revenue.

Log function: high estimates of tax semi-elasticity at low levels of ETRs and high share of profits in number of tax havens with low ETR.

**p.3** Methodology

Semi-elasticity model: $\pi_i = p_i + S_i - c_i$, where $\pi_i$ = profit booked in jurisdiction, $p_i$ = real unobserved profit, $S_i$ = profits shifted into jurisdiction, $c_i$ = cost of profit shifting incurred by MNE.

Base methodology profit shifting: Hines and Rice 1994: cost of profit shifting increases quadratically with fraction of profit shifting, booked profits maximised subject to profit shifting, theoretical profits identified with Cobb-Douglas production function for FOC Taylor expansion and:

$$\log(\pi_i) = \beta_0 + \beta_1 \log(\tau_i) + \beta_2 \log(L_i) + \beta_3(\tau_i) + \beta_x X + \varepsilon$$

FOC Taylor expansion around 2 values of Lagrangian multiplier where profit shifting becomes 0:

$$\log(\pi_i) = \beta_0 + \beta_1 \log(\tau_i) + \beta_2 \log(L_i) + \beta_3(\tau_i) + \beta_4(\tau_i)^2 + \beta_x X + \varepsilon$$

$\tau_i$: tax rate of subsidiary, or difference of tax rate between parent and subsidiary or sometimes between subsidiaries.

Logarithmic model: quadratic relationship not suitable for profit shifting strategies based on financial assets (CIP or intra-group lending), since cost of profit shifting fixed and as fraction of profits first high and then decrease. MNEs responsible for bulk of profit shifting, since too costly for smaller enterprises. Non-linearity showed by: profits per employee constant around 30-50k $ until threshold of ETR below 10%.

Tax semi-elasticities:

Modified equation: $\log(\pi_i) = \beta_0 + \beta_1 \log(\tau_i) + \beta_2 \log(L_i) + \beta_3(\tau_i) + \beta_4 \log(t + \tau_i) + \beta_x Z + \varepsilon$

[Annotated: profit per employee | profit shifting countries | ETR]

Statutory rates perform worse than ETR, since no explanation for taxes paid and location of profits.

**p.4**

In equation: $t$ = offset parameter to "avoid extremely high differences in tax semi-elasticity for countries with similar, extremely low tax rates."

Iterating over range 0-0.2, keep value that minimises Bayesian Information Criterion. Result: 0.0011 for US and 0.0023 for OECD.

$K$: tangible assets, but these are also affected by profit shifting => conservative products of estimates of tax semi-elasticity. $L$: wages, no data, use on average salary and productive employees.

Pairs of HQ and operation country: $\hat{p}_i$ = underlying profits without profit shifting. By comparing profits with hypothetical 25%:

$$\hat{p}_i = \pi_i \cdot \frac{e^{(\beta_2(0.25) + \beta_4 \log(t+0.25))}}{e^{(\beta_2(\tau_i) + \beta_4 \log(t+\tau_i))}}$$

Reallocating shifted profits:

Cost of profit shifting regime: $\hat{S}_i = \pi_i - \hat{p}_i$

Redistribute shifted profits to where real economic activity takes place: $\Delta P_i = -\hat{S}_i + \left(\sum_j \hat{S}_j\right) \cdot R_i$

$\Delta P_i$ is change in profits due to profit shifting.

**p.5**

Redistribution formula: $R_i = \frac{1}{4} \frac{L_i}{\sum_i L_i} + \frac{1}{4} \frac{\omega_i}{\sum_i \omega_i} + \frac{1}{2} \frac{Rev_i}{\sum_i Rev_i}$

$Rev_i$ = unrelated parties revenue.

After redistribution, sum of change in profits due to profit shifting $\sum_i \Delta P_i$ sums to 0.

Tax revenue loss: $TRL_i$ = product of change in profit base and ETR.

$$TRL_i = \Delta P_i \cdot ETR_i$$

Misalignment model: arithmetic used on data to show how well location of reported profit are aligned with location of economic activity (costs of labour, capital, revenue). Difference between reported profit $(\pi)$ and estimated theoretical profit $(\hat{p})$, same weighting as for redistribution formula.

$$\hat{p}_i = R_i \cdot \sum_j \pi_j$$

Profit shifting calculated as difference between booked profits and estimated profits. Misalignment model: sum of profit shifting = 0 => $\sum \hat{S}_i = 0$ and $\Delta P_i = \hat{S}_i$.

Profit misalignment of all foreign observations with tax rate $\theta \leq 25\%$ = 0, since no shifting to high tax countries.

# Additional notes

## Page 2 (Article p. 2)

Four main findings:

(i) Scale: MNCs shifted over $850 billion in profits to tax havens in 2017, implying $200-300 billion in revenue losses. Comparable to Tørsløv et al. (2023b) estimate of $616bn in 2015 and Wier & Zucman (2022) estimate of $969bn in 2019 (see Fig. A.25 and Table A.13 for detailed comparisons).

(ii) Destinations: Cayman Islands, Luxembourg, Singapore, Canada, Netherlands, Switzerland, Hong Kong, Bermuda, Puerto Rico and Ireland are the largest destinations. Differences between models exist: UK is a source under the misalignment model but a recipient under other models because of its low ETR. Logarithmic and misalignment models agree that the vast majority of profits in small tax havens (e.g. Cayman Islands, Luxembourg) are shifted there. High-income countries capture most tax revenue gains.

(iii) Most aggressive headquarter countries: among those reporting on over 20 jurisdictions, MNCs headquartered in the US, Brazil and Singapore are the most aggressive. No evidence of profit shifting by South Africa and Malaysia. Prior research focused heavily on US MNCs but they are not necessarily representative of all MNCs.

(iv) Distributional consequences: lower-income countries lose more tax revenue relative to their total tax revenue, directly contravening the 2030 Agenda for Sustainable Development goal to "Strengthen domestic resource mobilisation, including through international support to lower-income countries, to improve domestic capacity for tax and other revenue collection." In absolute terms, the US suffers the most; Germany and France estimated to lose up to half of their profit base.

Overall contribution: the paper provides a possible resolution to the inconsistency between "micro" estimates (low semi-elasticities in Beer, De Mooij & Liu 2020; Heckemeyer & Overesch 2017) and "macro" estimates (high shares of profits in tax havens in Dharmapala 2019; Zucman 2015). The inconsistency arises partly because prior studies modelled the relationship using mostly linear and, far less frequently, quadratic functions. The logarithmic function yields high semi-elasticities at low ETR levels, reconciling micro and macro estimates.

Paper structure: Section 2 introduces the logarithmic model and compares it to existing specifications and the misalignment model; Section 3 describes CbCR data; Section 4 presents results and robustness checks; Section 5 concludes.

---

## Page 3 (Article p. 3)

Section 2: Methodology for estimating profit shifting

2.1 Semi-elasticity model

The standard approach (following Hines & Rice 1994): profits booked in jurisdiction i by MNCs expressed as:
pi = pi + Si - ci
where pi is real unobserved profits, Si is profits shifted into the jurisdiction, and ci is the cost of profit shifting.

Most frequently used model (linear, Equation 2):
log(pi) = b0 + b1*log(Ki) + b2*log(Li) + b3*(ti) + bx*x + e

Quadratic model (Equation 3):
log(pi) = b0 + b1*log(Ki) + b2*log(Li) + b3*(ti) + b4*(ti)^2 + bx*x + e

Where pi = profits booked in country i, Ki and Li are capital and labour (tangible assets and wages), ti is either the subsidiary's tax rate, difference between subsidiary and parent, or between subsidiary and other subsidiaries. x are controls (GDP per capita, population).

Important: Hines & Rice (1994) noted results of the quadratic specification suggest "the effect is strongest at low tax rates." Dowd et al. (2017) apply the quadratic model to a panel of US tax returns 2002-2012 and find that the incentive to shift profits from 20% to 0% is more than double compared to shifting from 20% to 10%. Both equations are still considered "traditional methods" though follow-up studies use the linear equation much more.

2.2 Addressing extreme non-linearity: A logarithmic model

Key argument: the non-linearity of tax semi-elasticity is too extreme for linear or quadratic models. Why? The quadratic relationship between the fraction of profit shifted and the cost of profit shifting is suitable for transfer pricing of physical goods (where arm-length prices are available), but not for profit shifting via financial assets like intellectual property or intra-group lending.

For IP or intra-group lending strategies:
- Costs are largely fixed, do not vary significantly with profits
- Cost as fraction of profits shifted is high for low fractions, then decreases
- Once a structure is in place (e.g. IP in a tax haven), costs do not increase much with each additional dollar shifted
- These costs are minor for large MNCs and are typically much lower than the tax avoided
- Smaller companies may not find it viable to set up such structures at all (Davies et al. 2018; Johannesen, Tørsløv & Wier 2020; Wier & Erasmus 2022 on large MNCs' dominance)
- Costs are comparable regardless of which tax haven is used, so firms have an incentive to shift to havens with the lowest effective taxation available (not just lower ETRs)

Three empirical observations supporting the logarithmic approach:
- (a) Profit per employee is relatively constant around $30,000-$50,000 per employee in countries with ETR over 10%, then exponentially increases as ETR falls below 10% (Fig. 1).
- (b) Dowd et al. (2017) discontinuity model yields semi-elasticities for ETRs below 10% that are twice as large as those from their quadratic model, meaning the quadratic still does not fully capture the extreme non-linearity.
- (c) Data-driven symbolic regression (Appendix A.5) finds models that best fit the data all include a logarithmic term.

The logarithmic model (Equation 4):
log(pi) = b0 + b1*log(Ki) + b2*log(Li) + b3*(ti) + b4*log(t + ti) + bx*x + e

Where t is an offset parameter included to avoid extremely high differences in the semi-elasticity for countries with similar but very low tax rates.

Note on ETR vs statutory rates: ETRs are preferred over statutory rates because they better capture actual tax rates faced by MNCs and are more likely used by MNCs for decision-making. Statutory rates are used in comparability robustness checks (Tables A.16 and A.17) and generally perform worse (lower R-squared for US data, higher BIC except for the linear model). Luxembourg had a statutory rate of 29.22% in 2017, but the authors estimate its ETR at 1% (Table 2), in line with Garcia-Bernardo, Janský & Tørsløv (2020).

---

## Page 4 (Article p. 4)

Fig. 1: Profit per employee as a function of the ETR using the OECD data. The horizontal axis is logarithmic, making the extreme non-linearity visible. The relationship is colour-coded by whether the ETR is below or above 10%. Horizontal axis cut at 40% (only 9 countries above 40%: Angola, Guyana, Malawi, Niger, Nigeria, Pakistan, Reunion, Rwanda, Tonga).

Offset parameter t: optimal value is 0.0011 for US data and 0.0023 for OECD data, obtained by iterating over range 0-0.2 and minimising BIC. Results are "highly robust to the choice of the offset" (Section 4.4). Headquarter-country fixed effects are included to account for differences in profitability and reporting methods. Interaction terms between country fixed effects and log(t + ti) capture differences in profit shifting aggressiveness across reporting countries.

Capital K is operationalised using tangible assets. Limitation: tangible assets are affected by profit shifting. US MNCs in Luxembourg report the second highest value of tangible assets in Europe: $223 billion, equal to values reported in the rest of the EU excluding tax havens. This means using tangible assets yields conservative semi-elasticity estimates. Labour L: data does not include wages directly, so modelled using employees multiplied by average salary from ILO. Missing salary values estimated using a linear model with log-GDP and log-Population (R2 = 0.91).

After estimating tax semi-elasticities, the underlying profits without profit shifting (pi-hat) are calculated by removing the effect of tax rates, comparing profits in country i with a hypothetical scenario where ETR = 25% (Equation 5):
pi-hat = pi * exp(b3*(0.25) + b4*log(t+0.25)) / exp(b3*(ti) + b4*log(t+ti))

The ETR threshold of 25% "corresponds roughly to a zero marginal effect of the ETR on profits in the quadratic and logarithmic models." Since MNCs do not appear to shift profits to countries with ETRs above 15%, pi-hat is almost always larger than pi. Robustness: a threshold of 20% reduces the logarithmic model estimate by 8%, the quadratic by 11%, the linear by 19%.

Additional note from authors: in Orbis, 3,804 out of 5,391 (70%) corporate groups, accounting for 89.7% of profits, have a subsidiary in one of the following tax havens: Bermuda, Ireland, Luxembourg, Netherlands, Switzerland, Cayman Islands, British Virgin Islands, Hong Kong, Singapore.

2.3 Reallocating shifted profits

Profit shifting calculated as (Equation 6):
S-hat-i = pi - pi-hat

Since pi-hat > pi in almost all cases, S-hat-i is not the profit shifted in or out of the country, and the sum of S-hat-i > 0. So a redistribution formula is needed (Equation 7):
DeltaP-i = -S-hat-i + (sum of S-hat-i) * R-i

Where DeltaP-i is the change in profits due to profit shifting: profits shifted out (-S-hat-i, sign reversed since S-hat-i measures profits shifted in) plus the country's share of total shifted profits redistributed back.

---

## Page 5 (Article p. 5)

Redistribution formula (Equation 8):
R-i = 1/4 * (L-i / sum L-i) + 1/4 * (W-i / sum W-i) + 1/2 * (Rev-i / sum Rev-i)

- 25% weight: employees (L-i)
- 25% weight: wages (W-i)
- 50% weight: unrelated party revenues (Rev-i) -- used instead of tangible assets because revenues are less affected by tax-planning strategies

This is the same formula used by the OECD (2020) in the BEPS impact assessment for both Pillar One (excess profit allocation) and Pillar Two (undertaxed payments rule), and by Beer, Mooij, Hebous, Keen & Liu (2020). Note: an alternative redistribution using bilateral balance of payments data (as in Tørsløv et al. 2023b) is not feasible due to poor coverage for many countries worldwide (Cobham, Garcia-Bernardo, Janský & Palanský 2021).

After redistribution, sum of DeltaP-i = 0.

Tax revenue loss (Equation 9):
TRL-i = DeltaP-i * ETR-i
(statutory rate used as robustness check)

2.4 Misalignment model

In addition to semi-elasticity specifications, the paper also uses a "misalignment model" which observes directly how well the location of reported profits aligns with the location of economic activity (approximated by labour, wages, tangible assets and revenues).

Theoretical profit in the misalignment model (Equation 10):
pi-hat-i = R-i * sum(pi)

Same redistribution formula as Equation 8 (25% employees, 25% wages, 50% unrelated party revenues).

Profit shifting again = booked profits minus estimated profits (Equation 6). In the pure misalignment model, sum of profit shifting = 0. But the authors add a constraint (similar to OECD 2020): they set the profit misalignment of all foreign observations with an ETR above 25% to zero, since an MNC would not shift profits to a country with ETR over 25%. This corrects for outliers such as high profits of MNCs in resource-rich countries. Redistribution is then applied as in Section 2.3 to ensure sum of DeltaP-i = 0.

Comparison between logarithmic and misalignment models:
- Logarithmic model: explicitly models the non-linear relationship between profits and tax rates; provides estimates of tax semi-elasticities; is agnostic to the current distribution of profits and redistributes only as a function of economic activity location.
- Misalignment model: provides a better estimate of the origin and destination countries because it takes into account the current distribution of profits.

Illustrative example: $9m US, $0m India, $1m Cayman Islands in profits; wages and sales $9m US, $1m India, $0m Cayman. Both models find shifted profit approximately $1m (in Cayman). Logarithmic model redistributes 90% back to US, 10% to India. Misalignment model redistributes 0% to US (since US profits already match economic activity), 100% to India. The misalignment model "is more accurate and realistic" in redistribution because it accounts for the degree of profit shifting already out of a country.

---

## Page 6 (Article p. 6)

Section 3: Data

Main dataset: OECD CbCR data, became available July 2020. Stems from BEPS Action 13. Regulation impacts MNCs with consolidated annual group revenue of €750 million and above, headquartered in any country that has adopted the CbCR regulation. Data is collected by the headquarter country, aggregated by country of operations, and published by the OECD at the country level for each reporting country.

Year of data used: 2017 OECD CbCR data, 38 headquarter countries (see Table A.4).

Prior concurrent research papers using CbCR data: US data (Clausing 2020b; Cobham, Faccio & FitzGerald 2019; De Mooij, Liu & Prihardini 2019; Garcia-Bernardo et al. 2021; Garcia-Bernardo, Janský & Zucman 2022; Nessa et al. 2022), Italy (Bratta, Santomartino & Acciari 2021), Germany (Fuest, Hugger & Neumeier 2022) and Germany/other countries (Fuest, Greil, Hugger & Neumeier 2022). The authors state this is the first paper using the OECD CbCR data. The US IRS publishes CbCR data approximately one year before the OECD.

Three key advantages of CbCR data:

(i) Country coverage: the most obvious advantage is the "much more substantial country coverage." Especially relevant for lower-income countries. US CbCR includes 25 African countries vs 3 from Bureau of Economic Analysis. CbCR includes data in up to 145 (US) and 198 (Japan) jurisdictions. 214 countries in total. UNODC and UNCTAD (2020) propose using this CbCR data for the SDG indicator of illicit financial flows.

(ii) Consistency of definition: profits and taxes in CbCR are defined consistently with the concepts of corporate profits and taxes. This is not the case for Bureau of Economic Analysis data where "profits are imputed from a combination of net profits, intra-group dividends, interest paid and other variables" (Blouin & Robinson 2020; Clausing 2020a, 2020b; Garcia-Bernardo et al. 2021). Consequently, CbCR data excludes double-counting in revenue.

Note on remaining issues with double-counting in profits: the authors correct for this in five ways (detailed in Appendix A.1):
- (1) Excluding stateless entities (footnote 3 explains: these include entities with a status resulting from a mismatch between two jurisdictions, e.g. Apple Sales International in Ireland, and flow-through entities whose profits are taxed at the owner level)
- (2) Using country-specific corrections (Netherlands investigated double-counting, ranging from 16% in the Netherlands to 51% in Sweden and UK)
- (3) Removing double-counting of US profits (54% of US domestic profits as estimated by Garcia-Bernardo, Janský & Zucman 2022 using Horst & Curatolo 2020 methodology) and 10% of tax haven profits
- (4) Removing 10% of profits in tax havens for non-US MNCs
- (5) Removing certain domestic profits in other countries depending on relative difference between ETR on domestic and foreign profits

(iii) Two separate datasets: CbCR is provided for "All Sub-Groups" and for "Sub-Groups with Positive Profit." The positive-profits dataset has lower coverage but allows more accurate ETR estimates.

3.1 Use of data in the logarithmic and misalignment models

ETR calculated as accrued taxes over profits, using the "sub-groups with positive profits" data. Why: using positive profits only avoids offsetting firms with losses against firms with profits, giving more precise ETRs. Including loss-making companies would overstate ETRs. ETRs used in two parts: (a) to calculate profit shifting in semi-elasticity models; (b) to calculate tax revenue losses.

For semi-elasticity models: outliers (country dyads with tax rates above 50%) are removed.

For tax revenue losses: average ETR weighted by profits: ETR = (sum ETR-i * pi) / sum pi. Countries only available in "all sub-groups" but not in the positive-profits data have statutory CIT used instead (Anguilla, Antigua and Barbuda, Cuba, Djibouti, French Guiana, Guadeloupe, Haiti, Kiribati, Kosovo, Kyrgyz Republic, Sao Tome and Principe, St. Lucia, St. Vincent & Grenadines, Syria, Turkmenistan, Turks and Caicos Islands).

For reallocation of shifted profits (Equation 8): "all sub-groups" dataset for the 38 reporting countries. This is because MNCs prefer to report losses in high-tax countries while locating profits in low-tax countries, so excluding loss-making affiliates would exclude an important profit shifting component. See Fig. A.9 for visualisation and De Simone, Klassen & Seidman (2017) for empirical confirmation using UK tax returns data.

Misalignment model: also uses "all sub-groups" for the same reasons. ETRs for tax revenue losses still use "sub-groups with positive profit." Since the misalignment method is not affected by outliers, all observations are kept.

---

## Page 7 (Article p. 7)

Section 4: Results

4.1 Estimation of profit shifting (US data): the logarithmic model versus other models

Testing methodology on US CbCR data first to compare with prior literature, especially Dowd et al. (2017). Table 1 shows regression results.

Key finding from Table 1: the logarithmic model fits the US data better than any other model (higher R-squared of 0.8850 vs 0.8481 for quadratic and 0.8170 for linear; lower BIC of 230.48 vs 255.83 for quadratic and 268.26 for linear). The Log+Quad combination (R-squared 0.8856, BIC 234.53) does not improve over the pure logarithmic model, confirming that adding the quadratic term to the logarithmic model does not help.

Fig. 2: graphical interpretation of the semi-elasticity coefficients, showing marginal effects and relative increase in profits due to profit shifting compared to a country with ETR of 25%. Shows logarithmic model marginal effects decrease (become more negative) faster than other models as ETR approaches 0%.

Logarithmic model: accounts for extreme ratios of profit shifted in small countries with low ETRs, while avoiding overestimation for countries with ETRs above 15%.

Specific comparison example (Table 2):
- Australia (ETR 15.3%): logarithmic estimates 16% profit shifted in; quadratic 40%; linear 26%
- Bermuda (ETR 1.7%): logarithmic estimates 91%; quadratic 86%; misalignment 98.5%; linear 52%

Fig. 2 also shows a U-shaped relationship between ETRs and profits. Semi-elasticity is negative until ETR reaches approximately 25%, then becomes positive. This is due to high profits in resource-rich countries (Angola, UAE, Qatar, Norway, Nigeria). To correct for this, the authors assume zero tax semi-elasticity if ETR > 25%. Same approach used in the OECD (2020) BEPS impact assessment.

After redistribution using Equation 8:
- Logarithmic model: $364 billion profit shifted
- Misalignment model: $323 billion profit shifted (Fig. 3)

Destination of shifted profits is similar between models. The large majority is concentrated in a small group of tax havens (top 10 in Table 2). Over 75% of profits booked in those 10 countries are artificially shifted there. Cayman Islands, Luxembourg, Netherlands, Switzerland, Singapore, Bermuda and Puerto Rico are the largest destinations.

Notable difference: profit shifted to Luxembourg is more than two times larger in the logarithmic than in the misalignment model, because of different data sources used (the "all sub-groups" data shows $22bn in Luxembourg vs $54bn in the "sub-groups with positive profits" data).

Origin of shifted profits differs considerably across models: 72% of employees, wages and sales of US MNCs are in the US with ETR of 43%, so approximately 72% of global shifted profits are redistributed back to the US in the semi-elasticity models. In the misalignment model, a similar level is shifted out of the US since only 48% of profits are already reported there. The UK is another notable discrepancy: the UK appears to lose in the misalignment model (because reported profits in the UK (1.5% of total) are lower than its share of the economy (3.3%)) but not in the semi-elasticity models (because the UK has a low ETR of 12%, so profits are expected to be shifted in). The low UK profits reflect MNCs reporting zero or negative profits (Bilicka 2019).

Conclusion for this section: the logarithmic specification is considered more accurate for estimating the global scale, but the misalignment method may provide more accurate estimates of redistribution. The misalignment model typically redistributes more profits back to lower-income countries.

---

## Page 8 (Article p. 8)

4.2 Estimation of profit shifting (OECD data)

Same methodology as for US data but adds fixed effects for reporting countries (to correct for differences in profitability due to headquarters location) and an interaction term between the reporting country and either log(t+ETR), ETR^2, or ETR.

Table 3: estimates of tax semi-elasticity using OECD data (graphical interpretation in Fig. A.16). US is the reference group.

Key finding: logarithmic model again fits data better (R-squared 0.7314 vs 0.7142 for quadratic and 0.7115 for linear; BIC 5267.72 vs 5356.36 for quadratic and 5362.54 for linear). The logarithmic model estimates that over 40% of profit shifting takes place towards countries with ETR below 1% (Table 4). Quadratic and linear cannot capture this fully. Misalignment model yields similar results to the logarithmic model, "reinforcing the accuracy of the logarithmic model."

Headquarter country heterogeneity: the location of MNC headquarters is theoretically and empirically important for profit shifting (Bilicka 2019; Dischinger, Knoll & Riedel 2014). Many prior studies focus on US MNCs (Clausing 2020b; Dowd et al. 2017; Guvenen et al. 2022). Note: the ETR paid on foreign profits by US MNCs in sectors other than oil has fallen by half since the late 1990s, and nearly half of this decline is estimated to result from profit shifting to tax havens (Wright & Zucman 2018).

Aggressiveness results from the interaction term between country fixed effect and log(ETR): MNCs from Singapore, Brazil and the US are the most aggressive (most negative interaction magnitude). This contrasts with Bilicka (2019) who finds US MNCs in the UK to have a similar profit ratio gap as French and German MNCs. Japan is interesting: historically perceived as having a distinct attitude towards tax planning (Izawa 2019), but the results show Japanese MNCs engage in profit shifting similarly to other MNCs. South Africa and Malaysia: the relationship completely disappears (Fig. A.17), indicating no profit shifting.

Global profit shifting estimates (OECD data):
- Logarithmic model: $862 billion shifted
- Misalignment model: median of $867 billion, with 95% CI of $838-$1,022 billion (Table A.12 and Fig. 4)

Note (footnote 1): the sum of the median misalignment for each country differs from the median of total misalignment; the authors use the median misalignment per country which adds up to +$841bn positive and -$854bn negative.

These estimates are comparable to Tørsløv et al. (2023b) ($616bn in 2015) and Wier & Zucman (2022) ($969bn in 2019), though with a much larger country sample (see Fig. A.25 for comparison).

Revenue losses: approximately $200-300 billion, comparable to recent leading estimates of $100-300 billion (Table A.13). Methodological note: these are conservative because the authors aggregate at the country level and net gains and losses.

Key country-level findings from Fig. 4 and Tables 5 and 6:
- Cayman Islands: 94%-96% of booked profits shifted in
- Netherlands: 34%-47% of booked profits shifted in
- US: suffers the most from profit shifting in absolute terms
- France: affected to a substantially greater degree relative to estimated profits (47% misalignment; 27% logarithmic model)

Note (footnote 2): Canada appears as a top destination, mostly driven by Canadian MNCs shifting profits towards headquarters, likely explained by its relatively low ETR of 12.9% and characteristics of its tax system (Capurso 2016; van't Riet & Lejour 2014).

---

## Page 9 (Article p. 9)

Table 3 (OECD regression results): country-specific interaction terms (country:tax) represent the interaction effect between the country and log(0.0023 + ETR), ETR^2, and ETR for the three specifications. The intercept and country fixed effects are generally negative and significant at 0.1%, which indicates the higher profitability of US MNCs (US is the reference group). Only countries reporting on over 20 partner jurisdictions are shown.

Table 4: share of profit shifted into countries grouped by ETR:
- Below 5%: misalignment 40.0%, logarithmic 40.6%, quadratic 33.5%, linear 31.6%
- 5%-10%: misalignment 30.0%, logarithmic 43.1%, quadratic 40.6%, linear 39.8%
- 10%-15%: misalignment 15.4%, logarithmic 11.8%, quadratic 16.4%, linear 17.2%
- 15%-25%: misalignment 9.7%, logarithmic 2.7%, quadratic 4.1%, linear 6.1%
- Above 25%: misalignment 4.9%, logarithmic 1.7%, quadratic 5.4%, linear 5.3%

Note on Table 4: "the quadratic and linear models are not able to account for the large share of profits shifted into countries with ETRs below 1%." Since profit shifting is estimated bilaterally (reporting:partner), a country can (rarely) have an average ETR above 25% but an ETR below 25% for some bilateral relationships.

Relevance for GMT/Pillar Two: this table directly shows that the vast majority of profit shifting (over 70-83% across preferred models) goes to countries with ETR below 10%, which is highly relevant for assessing the likely effect of a 15% minimum ETR under Pillar Two.

---

## Page 10 (Article p. 10)

Fig. 4: Profits shifted in and out of countries using the OECD data, estimated with misalignment, logarithmic, quadratic, linear and DLM models.

Table 5: Top destinations of profit shifting (both misalignment and logarithmic models). The United Kingdom appears as a large destination in the logarithmic model (190,160m shifted in, 43.1% of profits with positive profits) but much less so in the misalignment model (6,041m shifted in, 2.3% of profits). Other major destinations: Cayman Islands (96% misalignment, 100% logarithmic), Luxembourg (85% misalignment, 72% logarithmic), Singapore, Canada, Netherlands, Switzerland, Hong Kong, Bermuda, Puerto Rico, Ireland.

Table 6: Top sources of profit shifting (both models). Sorted by absolute amount: US (287,971m misalignment / 259,263m logarithmic), Japan (71,961m / 104,218m), Germany (82,717m / 51,268m), France (82,377m / 45,784m), China, India, Mexico. Sorted by percentage of total profits shifted: Kenya (66.4% misalignment / 41.2% logarithmic), Greece (56.8% / 44.3%), Colombia (61.0% / 38.3%), Nigeria (35.9% / 62.6%), Iran, Saudi Arabia.

4.3 Profit shifting and tax revenue loss by income groups

Countries from all income groups lose similarly relative to their GDP, but profit shifting takes place predominantly towards high-income countries (Fig. A.18). This is expected since most tax havens are high-income countries.

Why the misalignment model may be more accurate for this section (two reasons stated):
- (1) The misalignment model uses all available data by imputing missing data for smaller countries often grouped into categories (e.g. "Other Africa"). The logarithmic model underestimates losses of lower-income countries because it cannot fully use these grouped observations. Estimating missing employees and revenue "only increases total profit shifted by 30%, but it is key to estimating profit shifting in lower-income countries accurately."
- (2) The misalignment model observes that profits are less aligned with economic activity in lower-income countries.

Tax revenue loss as percentage of total tax revenue (Fig. 5): lower-income countries (Africa and Latin America) lose more tax revenue relative to their total tax revenue.

Key numbers from the misalignment model:
- Low-income countries: lose equivalent of 7.19% (95% CI: 2.12-17.42) of total tax revenue, while receiving influxes of only 0.02% (0.01-0.07%)
- High-income countries: lose equivalent of 1.43% (0.40-1.87%), while gaining 0.37% (0.18-1.07%)
- Lower-middle-income countries: losses (1.29-4.11) significantly higher than higher-income countries
- Upper-middle-income countries: moderate losses (0.15-2.01)

"High-income countries lose an equivalent of 1.43%..." -- note that the low tax revenue gains for high-income countries contrast with the high volume of profits shifted in absolute terms to those countries.

Country-level analysis (Fig. A.19): lower-income countries lose significantly more tax revenue. Similar results for comparisons with corporate income tax revenue (Fig. A.20) and GDP (Fig. A.21). Within lower-income countries, African countries tend to lose the highest share (Fig. A.22). "Overall, our analysis shows that only a small number of countries gain any tax revenue."

Contribution to literature: few existing studies identify income group differences in profit shifting vulnerability. Fuest, Hebous & Riedel (2011) and Johannesen et al. (2020) indicate lower-income countries are more vulnerable. But Janský & Palanský (2019) compare five sets of estimates (Clausing 2016, Cobham & Janský 2018, Tørsløv et al. 2023b, Cobham & Janský 2019, their own) and four of the five do not suggest lower-income countries are disproportionately affected. All these studies cover 25-102 countries vs this paper's 214.

---

## Page 11 (Article p. 11)

Fig. 5: Tax revenue loss as percentage of total tax revenue for income groups (top) and regions (bottom), misalignment (left) and logarithmic (right) models. Confidence intervals show 95% intervals from bootstrapping.

Regional findings:
- Africa: -3.5% (misalignment); -1.9% (logarithmic)
- Caribbean/American islands: -6.4% losses but +13.0% gains (misalignment); -11.7% gains (logarithmic) -- these islands include the tax haven destinations
- Latin America: significant losses
- Northern America: -2.1% (misalignment); -1.9% (logarithmic)
- Europe: relatively moderate losses

4.4 Robustness checks and sensitivity analyses (10 total, briefly summarised)

Methodology-related:
- (i) Scale is similar across all models: $817bn (linear), $880bn (quadratic), $862bn (logarithmic), $867bn (misalignment)
- (ii) 25% ETR threshold robustness: reducing to 20% reduces logarithmic estimate by 6%; increasing to 30% increases it by 8%
- (iii) High correlation with Tørsløv et al. (2023b) and Wier & Zucman (2022) with increased country sample (Fig. A.25)
- (iv) Lower-income countries lose comparatively the most across all benchmarks (CIT revenue, GDP)
- (v) Sensitivity to offset t is minimal (Fig. A.26)
- (vi) Comparison with alternative non-linear specifications (1/(t+ETR), 1/(t+ETR)^2, 1/(t+ETR)^3, coth(t+ETR)): the logarithmic specification "allows for higher non-linearities, and exhibits a higher R2 and lowest BIC" (Table A.14, Figs. A.27 and A.28)
- (vii) Alternative redistribution formula (regression of share of profits on shares of employees, capital, sales and wages, Table A.15): profit shifting reduced by 9%, similar distribution of origins and destinations (Fig. A.30)

Data-related:
- (viii) Missing data estimated using 1,000 bootstrapped samples (Appendix A.1) to test consistency. Confidence intervals in Fig. A.12.
- (ix) Location of employees and revenue from the missing data model compared with original CBCR data and GDP (Fig. A.13): estimates address limitations of raw data and GDP as alternatives
- (x) Comparison of missing data imputation with penalised linear regression (Appendix A.1.2): the authors' method has higher predictive power

---

## Page 12 (Article p. 12)

Fig. 5: Continued.

4.3 Continued: lower-income countries context

The paper also engages with prior literature that finds contradictory results. Notes from the text:
- Hearson (2018): strong theoretical case for higher vulnerability of lower-income countries
- Fuest, Hebous & Riedel (2011); Johannesen et al. (2020): indicate lower-income countries are more vulnerable
- Janský & Palanský (2019): compare five sets of country-level estimates -- Clausing (2016), Cobham & Janský (2018), Tørsløv et al. (2023b), Cobham & Janský (2019), and their own -- and four of the five do not suggest lower-income countries are disproportionately affected. These five studies cover 25, 102, 34, 37, 79 countries respectively, "all small in comparison with our results for up to 214 countries."

---

## Page 13 (Article p. 13)

Section 5: Conclusion

Main estimate: "MNCs shifted around $900 billion in profits to tax havens in 2017." (Note: the abstract says $850bn; the conclusion rounds to approximately $900bn from the combined model estimates.)

Linear and quadratic models underestimate profit shifting to countries with extremely low tax rates while overestimating it for countries with moderate rates. The logarithmic and misalignment models capture the behaviour accurately.

Using the two preferred models: 40%-41% of profit shifted goes to countries with ETR below 1%, and 70%-83% to countries with ETR below 10%. This is consistent with MNCs exploiting "the combination of globalisation and the sovereignty of individual countries, in particular tax havens."

Two key policy/research insights:

(1) The extremely non-linear relationship between profit location and tax rates has implications for assessing the Global Minimum Tax. The authors explicitly state: "While this assessment assumes that profit shifting incentives decrease in linear fashion as the minimum ETR increases, we show in this paper that this linearity assumption is unlikely to hold. Our findings indicate the importance of the specific value of the minimum ETR, which is 15% in the case of Pillar Two." This is a directly relevant finding for the GMT thesis.

(2) Lower-income countries lose more tax revenue relative to total tax revenue. This could encourage governments to use confidential tax return data for more detailed analyses (as South Africa recently did, learning that profit shifting is highly concentrated among a few large MNCs, Wier & Erasmus 2022). "Our results indicate that the current international tax system may be hindering the achievement of one of the goals of the 2030 Agenda for Sustainable Development: to strengthen domestic resource mobilisation" (FACTI 2021; UN 2015). Lower-income countries should be represented on an equal footing at reform discussions and reforms should create a level playing field in corporate taxation.

Two future research directions:
- More accurate estimates as new CbCR data become available (2020 data, to be published no later than 2024, will contain no double-counting because guidelines for intra-company dividends have been updated)
- More accurate tax semi-elasticity estimates using firm-level data (e.g. voluntary CBCR disclosures by Vodafone and Shell; EU regulation approved 2021 requiring companies to publish parts of CbCR data, to be available from around 2025)

---

## Pages 14-23 (Article pp. 14-23, Appendix A.1-A.2)

Appendix A.1: Additional data corrections

A.1.1 Data limitations and corrections: imputing missing data

Three main data issues and corrections:

(1) Double-counting in profit due to intercompany dividends: MNCs are instructed not to double-count intercompany dividends in revenue but not explicitly in profit. Some countries (Netherlands, Sweden) published associated notes showing domestic operations of MNCs may be considerably affected. The five correction steps are: excluding stateless entities (footnote 3: including Apple Sales International in Ireland, plus flow-through entities); country-specific corrections (Netherlands 16%, Sweden 51%, UK 51%); removing 54% of US domestic profits (Garcia-Bernardo, Janský & Zucman 2022 using Horst & Curatolo 2020 methodology) and 10% of US tax haven profits; removing 10% of tax haven profits for non-US MNCs; removing 35% of domestic profits in most other countries (except Slovenia, Latvia, Luxembourg where domestic ETR > foreign ETR; Belgium, Singapore, Isle of Man, Bermuda where 50% removed because domestic ETR is much lower than foreign ETR).

(2) Incomplete and non-systematic disaggregation by jurisdiction: CbCR implemented by approximately 100 countries but only 38 agreed to share data publicly in aggregated and anonymised form. Countries vary in how much they aggregate (Fig. A.2). US and Japan (145 and 198 jurisdictions respectively) lead. Only three countries report on Gambia; only seven on the Isle of Man.

Solution: Histogram-based Gradient Boosting Regression Tree (scikit-learn implementation, Pedregosa et al. 2011). Trained on location of profits, employees, sales and tangible assets using variables from CEPII gravity dataset, UN Comtrade, World Bank FDI, and other sources (Table A.2). Mean out-of-sample R-square: 0.74 (employees), 0.56 (sales), 0.57 (profits), 0.44 (tangible assets). The estimated values are adjusted so their sum corresponds to the aggregated sum in CbCR for reporting countries. A ratio is capped at 10 (i.e. if the model expects the OECD data to be less than 10% complete, it is treated as 10% complete). "Estimation of missing economic activity increases total shifted profits by approximately 30 per cent, but it is key with respect to accounting for missing data in countries underrepresented in the sample -- typically lower-income countries."

(3) Lack of reporting by some countries (e.g. Russia): addresses by estimating domestic activities for non-reporting countries using a linear model based on expected number of companies, GDP, population, average ETRs and consolidated banking claims (BIS Table B4), with R-squared of 0.97, 0.93, 0.88 for employees, revenue and tangible assets respectively (Figs. A.14 and A.15).

Important: in the logarithmic model, only fixes (2) and (3) are used for redistribution, not for calculating profit shifted. For non-reporting countries' share of profit shifted, the authors divide total profit shifted by the share of GDP of countries in the sample (83%), similar to the available economic activity estimated from CbCR using all fixes (94%).

A.1.2 Modelling missing employees and revenues

Variables used (full list in Table A.2): from CEPII GravData, WBD, UN, IMF, COMTRADE, LinkedIn, TJN, BIS, ILO, WHO, UNU-WIDER GRD. The gradient boosting model outperforms LASSO regression (Fig. A.5). Permutation feature importance (Fig. A.6): for profit estimation, outward FDI and Portfolio Investment are most important; for employees and sales, outward FDI and exports are most important. The authors note: "we are not trying to rationalise the variables chosen by the algorithm, just to create an accurate model to impute missing values."

Bootstrapping: models trained 1,000 times using bootstrapped samples. Results are robust.

A.2 Additional theory discussion

The Hines & Rice (1994) model is examined more carefully. It assumes the cost of profit shifting increases quadratically with the profit shifted: Cost-i = (a/2) * (S-i^2 / p-i). This implies low levels of profit shifting are practically cost-free, while costs quadratically increase with intensity. The profits booked in a country (Equation 12) are then maximised, yielding the relationship between profit shifted and tax rates (Equation 13).

The Taylor expansion of Equation 14 is taken around the point where no profit shifting takes place (pi = p-i). The expansions yield linear (Equation 18) and quadratic (Equation 19) forms. "These two equations are convenient but are only valid around the point where no profit shifting is present. Extending these approximations far from that point is not adequate."

Both linear and quadratic models: profit shifting is undervalued for countries with ETR below 10% and overvalued for others (Fig. A.7). Residuals are positive for countries with ETR below 10% for both models. Residuals are only corrected once the logarithmic term is reintroduced.

The authors also estimate alpha (normalisation constant) from the literature. Semi-elasticity is equivalent to -1/(a*lambda) at around 1 (Beer, De Mooij & Liu 2020) or around 4 (this paper). Table A.3 shows: for a tax haven with no CIT and 95% of profits shifted in, the cost of profit shifting is at least 33% higher than the amount of profits shifted under the most conservative alpha (0.14). This "points to a mismatch between the quadratic cost function proposed by (Hines & Rice, 1994) and profit shifting in the 21st century."

---

## Pages 14-23 (Article pp. 14-23, Figs. A.1-A.7 and Tables A.1-A.3)

Fig. A.1: Domestic and foreign ETRs before and after correction for double-counting. After correction, higher correlation between ETRs paid by domestic and foreign companies.

Table A.1: Summary of advantages and disadvantages of CbCR data.
- Advantages: includes over 150 jurisdictions for at least 5 headquarter countries; no double-counting in revenue; uses data on large MNCs with positive profit to estimate ETRs precisely
- Disadvantages: might include some double-counting in profit due to intercompany dividends or stateless entities (which the authors drop); data for 2017 for some countries in aggregated and anonymised form (which the authors address)

Fig. A.2: Country availability in the 2017 OECD data. Shows heterogeneity in countries' reporting decisions. US enables publication of information for all major tax havens; Austria, Norway, Poland report on none and therefore are not shown.

Fig. A.3: Available information on CbCR. Countries coloured by GDP per capita. Countries with below 20% availability are annotated. Countries with below 10% availability placed to the left of the 10% horizontal line. Shows data coverage is especially problematic for lower-income countries.

Table A.3: Values of alpha depending on the tax rate, the semi-elasticity, and the fraction of profit shifted.

Fig. A.7: Residuals and cumulative residuals for linear, quadratic and logarithmic models. The logarithmic model correctly resolves the systematic residuals at low ETRs.

---

## Page 21 (Article p. 21)

Table A.4: Number of jurisdictions available per country using the OECD data.

All Sub-Groups (top reporters): Japan (198), India (163), Germany (159), USA (145), South Africa (138), China (124), Switzerland (119), Spain (119), Denmark (114), Italy (109), Mexico (96), Bermuda (98), Luxembourg (90), France (89), Australia (80), Indonesia (41), Brazil (41), Malaysia (35), Singapore (28), Belgium (20).

Many countries report only domestic activities (1 jurisdiction reported = domestic only): Greece, Poland, Netherlands, Ireland, South Korea, Finland.

---

## Pages 21-22 (Article pp. 21-22)

Table A.5: Summary statistics for the 36 countries of the sample used in the logarithmic model, 2017 OECD data, "Sub-Groups with positive profits." The table shows aggregated profits, tax accrued, tax paid, employees, revenue, assets and ETRs for domestic vs foreign activities. Note: Latvia and Poland only report on all groups; Austria and Chile omit reporting on domestic activities; UK omits total foreign activities.

Notable ETR observations from Table A.5:
- Bermuda domestic ETR: 1.3% (accrued), 1.6% (cash)
- Luxembourg domestic ETR: 0.4% (accrued), 0.9% (cash)
- Singapore domestic ETR: 5.0% (accrued), 4.6% (cash)
- United States domestic ETR: 42.8% (accrued), 34.8% (cash)
- Ireland domestic ETR: 3.7% (accrued), 2.7% (cash)

---

## Pages 22-25 (Article pp. 22-25)

Table A.6: Expected vs observed number of large MNCs in CbCR.
- Good match for most countries (ratio close to 1.0)
- Luxembourg has a ratio of only 0.20 (26 expected, 129 observed), suggesting Luxembourg attracts many MNCs not headquartered there
- China has ratio of 2.04 (538 expected, 264 observed), suggesting significant underreporting

Fig. A.9: Loss-making affiliates as a profit shifting strategy. Three types of countries highlighted:
- "Profit centres": very high profits not offset by losses (red: Cayman Islands, Bermuda, Jersey, etc.)
- "Coordination centres/conduits": very high profits offset by losses (green: Luxembourg, Netherlands)
- "Origin countries": profits offset by losses (blue: US, UK, France)

Figs. A.10 and A.11: Comparisons between misalignment and logarithmic models for US and OECD data. Generally good correlation between models with some outliers (UK, Brazil, Malaysia, China). Profit shifting out of African countries is higher in the misalignment model.

Fig. A.12: Distribution of the scale of profit shifted by misalignment model at country level (bootstrapped). Non-reporting countries (Germany, UK, Cayman Islands) have higher uncertainty. Median estimates: USA $288.1bn, Germany $82.7bn, France $82.3bn, Japan $72.0bn.

Fig. A.13: Comparison between redistribution formula using imputed data vs raw data vs GDP shares. Estimated shares for African countries are higher than the raw CbCR data but lower than their GDP share, which is expected given the lower presence of large MNCs in developing countries.

---

## Pages 25-27 (Article pp. 25-27)

Figs. A.14-A.17: Various visualisations.

Fig. A.16: Graphical representation of Table 3 (OECD logarithmic model coefficients). Shows the marginal effect of ETR on profits and relative increase in profits due to profit shifting, compared to ETR of 25%.

Fig. A.17: Country-level graphical representation of the logarithmic model. Shows that South Africa and Malaysia have a flat relationship (no profit shifting), while Singapore, Brazil and the US have the most negative (most aggressive) relationships.

---

## Page 27 (Article p. 27)

Figs. A.18 and A.19:

Fig. A.18: Profits shifted as percentage of GDP for different income groups. Low-income: -2.0% (misalignment); High-income: -1.5% losses but +1.6%/+1.8% gains.

Fig. A.19: Tax revenue loss as percentage of total tax revenue for individual countries. Statistical differences between medians assessed using Mann-Whitney test. Low-income countries consistently have more negative (larger losses) values.

---

## Pages 28-39 (Article pp. 28-39)

Figs. A.20-A.22: Alternative benchmarks (CIT revenue, GDP) all show lower-income countries losing comparatively the most.

Tables A.7-A.10: Full country-level results for profit shifting for all four model-direction combinations (misalignment/logarithmic x destination/origin). These are extremely detailed tables but some noteworthy entries:

From Table A.7 (misalignment, destinations):
- Bermuda: PS/GDP 808.85%, almost entirely shifted profits
- Cayman Islands: 95.59% of profits shifted in
- Luxembourg: 85.01%
- British Virgin Islands: 88.95%

From Table A.8 (misalignment, origins):
- Venezuela: very high PS/GDP (6.90%) but negative profits (all groups), complicating interpretation
- Chad, Congo: extremely high percentages but small absolute amounts
- Kenya: 66.4% of potential base shifted out, TRL 4.50% of total tax revenue
- Germany: 32.0% of potential base shifted out, TRL 1.76%
- France: 47.1% of potential base shifted out, TRL 2.70%

From Table A.9 (logarithmic, destinations):
- United Kingdom appears as the largest destination in absolute terms ($190,160m) at 43.1% of profits with positive profits -- a notable finding under the logarithmic model
- Cayman Islands: 100% of profits shifted (logarithmic treats the entire amount as shifted)
- Luxembourg: 71.6% of booked profits, TRG 8.34% of tax revenue

From Table A.10 (logarithmic, origins):
- US: $259,254m shifted out, 23.79% of potential base, TRL 2.09% of total tax revenue
- China: $139,394m shifted out, 19.68% of potential base
- Japan: $104,214m shifted out, 23.19% of potential base
- Germany: $51,268m shifted out, TRL 1.09%

---

## Pages 36-39 (Article pp. 36-39)

Table A.11: Profits and effective tax rates for all countries. Includes ETRs accrued (ETRa) and cash-based (ETRc), weighted mean, median, foreign-only weighted mean. Key observations:

- Luxembourg ETRa (wmean): 2.1%; ETRc: 1.8%
- Cayman Islands ETRa: 0.3%; ETRc: 0.2%
- Bermuda ETRa: 1.1%; ETRc: 1.7%
- Singapore ETRa: 5.4%; ETRc: 5.3%
- Ireland ETRa: 10.4%; ETRc: 10.2%
- US ETRa: 35.4%; ETRc: 29.6%
- Germany ETRa: 18.6%; ETRc: 18.2%

---

## Page 39 (Article p. 39)

Table A.12: Estimates of profits shifted and tax revenue loss worldwide.
- Misalignment: $854bn shifted, TRL (total ETR) $214bn, TRL (foreign ETR) $173bn, TRL (CIT) $238bn
- Logarithmic: $862bn shifted, TRL (total ETR) $226bn, TRL (foreign ETR) $177bn, TRL (CIT) $234bn

Table A.13: Comparison with other studies. Key comparators:
- This paper: $862-867bn profit shifted, $177-257bn revenue loss, CBCR data, 214 countries, 2017
- Tax Justice Network (2021): $1,163-1,334bn, $312bn, CBCR, 200 countries, 2017
- Wier & Zucman (2022): $969bn, $247bn, FDI, 57 countries, 2019
- Tørsløv et al. (2023b): $946bn, $243bn, FDI, 57 countries, 2018
- Clausing (2016): $1,076bn, $279bn, FDI, 25 countries, 2012
- Janský & Palanský (2019): $420bn, $125bn, FDI, 79 countries, 2016
- UNCTAD's Bolwijn et al. (2018): $700bn, $200bn, FDI, 72 countries, 2012
- Bratta et al. (2021): $786bn, $217bn, CBCR, 2017
- Fuest, Greil et al. (2022): $271bn, $104bn, CBCR, 2019
- IMF's Crivelli et al. (2016): revenue loss only $123bn, 173 countries, 2013
- Cobham & Janský (2018): revenue loss only $90bn, 102 countries, 2013

---

## Page 40 (Article p. 40)

Table A.14: Regressions using alternative non-linear specifications (US data).
- All alternative specifications (1/(t+ETR), 1/(t+ETR)^2, 1/(t+ETR)^3, coth(t+ETR)) yield similar R-squared (~0.885-0.886) and BIC (230.05-230.15) to the logarithmic model (R-squared 0.885, BIC 230.48).
- All are better than quadratic (BIC 255.83) or linear (BIC 268.26).
- The logarithmic specification has the highest R-squared and among the lowest BIC values.

---

## Pages 41-43 (Article pp. 41-43)

Fig. A.25: Comparison with Tørsløv et al. (2023b). Good correlation between this paper's estimates and Tørsløv et al. The authors' country sample is larger, and countries not included in Tørsløv et al. appear on the left of the plots.

Fig. A.26: Effect of parameter t on the logarithmic model. The coefficient of log(t+ETR) changes with t but the total profit shifting estimate is "small" in sensitivity. The chosen value (dot) is at t = 0.0023 for OECD data.

Figs. A.27-A.28: Alternative non-linear functions. The logarithmic model (and coth) provide the sharpest non-linearity at low ETRs.

Fig. A.29: Fit of the robust model for the alternative redistribution formula. Large presence of tax havens among the outliers (USA:CYM, BMU:GBR, USA:GIB, JPN:GGY, DNK:GGY).

Table A.15: Robust linear model results regressing share of profits on shares of economic activity:
- Share of employees: 0.0733 (significant)
- Share of capital: 0.2683 (significant)
- Share of sales: 0.4372 (significant)
- Share of wages: 0.0607 (significant)
- This redistribution formula (when normalised to sum to one) gives 7.3% weight to employees, 26.8% to capital, 43.7% to sales, 6.1% to wages, compared to the paper's preferred formula of 25%/0%/50%/25%. Using this alternative reduces profit shifting by 9% with similar distribution patterns.

---

## Pages 43-45 (Article pp. 43-45)

A.5 Data-driven calculation of the effect of tax on profit shifting

Symbolic regression using Eureqa (Schmidt & Lipson 2009), run for 20 hours on 8 CPU cores. Variables used: unrelated party revenue, employment, tangible assets, ETR, log(ETR), wages, population, gross fixed capital formation, consumption, GDP, tax complexity, statistical capacity, resource revenues.

Key finding from Fig. A.23: unrelated party revenues and ETRs were almost always included in the found models. Statutory CIT never appears in any model. This supports the use of ETRs over statutory rates.

Fig. A.24: All symbolic regression models show extreme non-linearity at low ETRs, independently of complexity. At ETR = 1%, profits increase 6 to 14 times compared to the minimum. All models allow for a U-curve with minimum effect at ETR approximately 20%.

Tables A.16 and A.17: Regressions using statutory CIT rates (US and OECD data respectively). Key finding: models using CIT "generally perform worse than those with ETRs: for the US data, they have lower R-squared in every case and the BIC values are higher with the exception of the linear model." For the OECD data, logarithmic model with ETR (BIC 5267.72) is significantly better than with CIT (BIC 5331.26). For countries where CIT was not available, ETR was imputed (Anguilla, Antigua and Barbuda, Cuba, Djibouti, French Guiana, Guadeloupe, Haiti, Kiribati, Kosovo, Kyrgyz Republic, Sao Tome and Principe, St. Lucia, St. Vincent & Grenadines, Syria, Turkmenistan, Turks and Caicos Islands).

---

## Pages 46-47 (Article pp. 46-47)

References

Key references cited in this paper that are relevant for the GMT thesis (in addition to those already mentioned):

- Beer, De Mooij & Liu (2020): Journal of Economic Surveys review of international corporate tax avoidance channels
- Bilicka (2019): AER, comparing UK tax returns of foreign MNCs to domestic firms
- Blouin & Robinson (2020): SSRN, on double-counting in BEA data
- Clausing (2020b): NTJ, profit shifting before and after TCJA
- Dowd, Landefeld & Moore (2017): Journal of Public Economics, profit shifting of US multinationals with quadratic specification
- Garcia-Bernardo, Janský & Tørsløv (2021): International Tax and Public Finance, MNCs and tax havens using CbCR
- Garcia-Bernardo, Janský & Zucman (2022): NBER working paper on TCJA and profit shifting
- Heckemeyer & Overesch (2017): Canadian Journal of Economics, multinationals' profit response to tax differentials
- Hines & Rice (1994): QJE, fiscal paradise original methodology paper
- Johannesen, Tørsløv & Wier (2020): World Bank Economic Review, developing countries more exposed to MNC tax avoidance
- Tørsløv, Wier & Zucman (2023b): Review of Economic Studies, "The missing profits of nations"
- Wier & Zucman (2022): NBER working paper, global profit shifting 1975-2019
- Wright & Zucman (2018): NBER working paper, the exorbitant tax privilege
- Zucman (2015): "The hidden wealth of nations: The scourge of tax havens," University of Chicago Press
- OECD (2020): "Tax challenges arising from digitalisation -- Economic impact assessment"
