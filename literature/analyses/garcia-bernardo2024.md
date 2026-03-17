
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