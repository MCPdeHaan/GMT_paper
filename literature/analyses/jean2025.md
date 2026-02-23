# Jean & Nishimura (2025) — "The Enforcement Dilemma of the Global Minimum Tax"
**International Tax and Public Finance (2025)**


The Enforcement Dilemma of the Global Minimum Tax
Jean & Yukihiro, 2025 — Note: $\rho$ = rho in all cases of formula

Incorporating endogenous enforcement choices. Formal model of international tax competition among heterogeneous countries: how does GMT reshape dynamics of tax competition, profit allocation, enforcement incentives. Result: threshold for GMT: beyond threshold low-tax country may withdraw from international enforcement cooperation, leaving high-tax country worse off. Robust even of non-cooperative tax haven with no tax and no enforcement.

**Introduction**

International enforcement cooperation is more effective than unilateral reforms: low-tax countries have weak incentives to curb profit shifting. Model this paper: MNE shifts profits from high-tax country to low-tax country including concealment cost; each country chooses enforcement efforts and tax rate to maximise tax revenue net of enforcement costs. Both low/high tax countries want international tax enforcement to increase revenue due to suboptimally set tax rates, with different incentives for enforcement. Effective enforcement relies on international cooperation & coordination. Consistent with empirical literature in showing that semi-elasticity of profit shifting varies with statutory tax rate (different sensitivities!), due to complementary effect between enforcement and tax rates: higher tax rates strengthen enforcement incentives, reduce elasticity of profit shifting in high-tax countries.

GMT: low-tax countries can choose not to cooperate in enforcement agreements, leaving high-tax countries worse off. Goal paper: simple model that can be solved explicitly where enforcement choices have key strategic effect on taxes and profit allocation. Finding: GMT can backfire by undermining enforcement cooperation. Paper asks to test this with empirical data.

**Framework**

2 countries, MNE has branch in each country, profit $\pi_i$ in country $i$. Total profit normalised to 1, distribution follows:

$$\pi_1 = \frac{1+\varepsilon}{2}, \quad \varepsilon \in [0,1) \text{ showing market asymmetry}$$
$$\pi_2 = \frac{1-\varepsilon}{2}$$

Country 1 has larger domestic market; MNE shifts profits between branches to minimise total tax liability. Profit reported: $\tilde{\pi}_i$ subject to quadratic and non-fiscally deductible shifting cost:

$$C(\pi_i - \tilde{\pi}_i) = \delta(e_i, e_j)(\pi_i - \tilde{\pi}_i)^2$$

where $\delta(e_i, e_j)$ captures international enforcement tax capacity related to profit shifting. Enforcement increases cost of profit shifting. Lack of tax relevant information provided by host country makes taxable income unclear to home country.

International enforcement technology: joint technology when national enforcement choices are relevant and independent:

$$\delta(e_1, e_2) = \left(0.5e_1^{-\rho} + 0.5e_2^{-\rho}\right)^{-1/\rho}, \quad \rho \geq -1$$

$\rho = 1 \Rightarrow$ perfect substitutes
$\rho = 0 \Rightarrow$ Cobb-Douglas complements
$\rho = \infty \Rightarrow$ perfect complements

MAP: low-tax country can have veto power on TP and taxable income of MNEs, enforcement technologies closer to weakest-link formula. Enforcement technology equal for both countries; effectiveness can differ.

**Profit shifting incentives**

Tax: $t = (t_1, t_2)$; enforcement choices: $e = (e_1, e_2)$; declared profit: $(\tilde{\pi}_1, \tilde{\pi}_2)$ to maximise after-tax profit net of profit-shifting cost:

$$\max \ (1-t_1)\tilde{\pi}_1 + (1-t_2)\tilde{\pi}_2 - \delta(e)(\pi_i - \tilde{\pi}_i)^2$$

subject to $\tilde{\pi}_1 + \tilde{\pi}_2 = \pi_1 + \pi_2$. Leading to:

$$\pi_2 - \tilde{\pi}_2 = -(\pi_2 - \tilde{\pi}_2) = \frac{t_1 - t_2}{2\delta(e)}$$

Profit shifting proportional to tax differential and inversely proportional to enforcement levels. Exogenous enforcement: profit shifting with tax differential constant when enforcement is fixed. Low state enforcement: weaker enforcement incentives when low revenue & tax. Declared profit:

$$\tilde{\pi}_1 = \frac{1+\varepsilon}{2} - \frac{t_1 - t_2}{2\delta(e)}$$

$$\tilde{\pi}_2 = \frac{1-\varepsilon}{2} + \frac{t_1 - t_2}{2\delta(e)}$$

Tax choices with GMT: second stage of game, anticipate declared profit ($\tilde{\pi}_1$ and $\tilde{\pi}_2$) to maximise welfare. FOC:

$$\frac{\partial \omega_i}{\partial t_i} = \frac{1+\varepsilon_i}{2} - \frac{t_i - t_j}{2\delta(e)} + t_i \cdot \frac{-1}{2\delta(e)} = 0$$

Tax responses positively sloped; slope of tax response function positively sloped (fiscal decisions are strategic complements), stability of tax equilibrium. GMT set exogenously as weighted average of both countries' tax rate and weights $\lambda$ exogenous between 0 and 1: see which value of $\lambda$ each country prefers.

Constrained equilibrium tax: $t_2^m = \bar{t}$, $e_i^m = \delta(e)\left(\frac{1+\varepsilon}{2}\right) + \frac{\bar{t}}{2}$

Tax gap: $t_1^m - t_2^m = \frac{\delta(e)}{2}\left(\frac{4\varepsilon}{3} - \frac{2\varepsilon\lambda}{3}\right) > 0$

GMT shifts up tax rate in lowest-tax countries, tax gap shrinks, profit shifting reduced in low-tax country, since tax rate increased to greater extent than high-tax country. Tax gap in profit shifting equation: $\pi_i - \tilde{\pi}_i = -(\pi_2 - \tilde{\pi}_2) = \frac{\varepsilon}{3} - \frac{\varepsilon\lambda}{6}$, decreasing in $\lambda$. GMT decreases profit shifting, substitute to costly enforcement.

**Proposition 1:** GMT $\lambda \in [0,1]$, country asymmetry $\varepsilon \in [0,1]$, enforcement levels $e = (e_1, e_2)$: equilibrium revenue satisfies:

$$R_1^m(e) = a_1(\lambda, \varepsilon)\delta(e) \geq R_2^m(e) = a_2(\lambda, \varepsilon)\delta(e)$$

GMT curbs profit shifting and increases equilibrium taxes, positive effect on tax revenue in high-tax countries when enforcement exogenous & low-tax countries GMT higher tax rate and smaller tax base. So for low-tax country, the profit shifting loss could be offset by higher tax rate. Thus both for low & high-tax country a benefit. But assumes enforcement is exogenous.

**Now effect on enforcement & cooperation**

Cooperative enforcement: 2 types of enforcement externalities. Cost of profit shifting depends on both countries' — public good externality. Tax response to enforcement: increasing enforcement increases taxes as well as tax gap. Increase in taxes benefits both countries due to suboptimal taxes; each country wants to free-ride on enforcement needed, coordinated enforcement effective. Countries choose $e = (e_1, e_2)$ anticipating tax revenues:

$$\max_{e_i, e_j} \sum_i \left(R_i^m(e_i, e_j) - \frac{e_i^2}{2}\right) \equiv \max_{e_i, e_j} \sum_i \left(a_i(\lambda, \varepsilon)\delta(e_i, e_j) - \frac{e_i^2}{2}\right)$$

Cost-minimising equal cooperative enforcement level:

$$\hat{e}_1^m = \hat{e}_2^m = \frac{a_1(\lambda, \varepsilon) + a_2(\lambda, \varepsilon)}{2}$$

Cooperative enforcement independent of elasticity of substitution: $\sigma = \frac{1}{1+\rho}$. Enforcement cooperation: same enforcement levels independent of enforcement being complements or substitutes.

**Proposition 2:** Given enforcement technologies, under minimum tax $\lambda \in [0,1]$ and country asymmetry $\varepsilon \in [0,1]$, cooperative enforcement satisfies:

$$\hat{e}_1^m = \hat{e}_2^m = \frac{a_1(\lambda, \varepsilon) + a_2(\lambda, \varepsilon)}{2}$$

where coordinated enforcement is identical across countries and increasing with minimum tax $\lambda$. Enforcement cooperation induces welfare levels in country $i$:

$$\omega_i^c = \left(\frac{a_i(\lambda,\varepsilon) + a_j(\lambda,\varepsilon)}{4}\right)\left(\frac{3a_i(\lambda,\varepsilon) - a_j(\lambda,\varepsilon)}{2}\right)$$

**Non-cooperative enforcement:** each country chooses $e_i$ simultaneously and independently. Country maximises: $\omega_i(e_i, e_j) = a_i(\lambda, \varepsilon)\delta(e_i, e_j) - \frac{e_i^2}{2}$. Under enforcement technology, equilibrium will be:

$$e_i^m = 0.5\left(0.5a_1(\lambda,\varepsilon)^{-P/(2+P)} + 0.5a_2(\lambda,\varepsilon)^{-P(1+P)}\right)^{-P/(2+P)} \cdot a_i(\lambda,\varepsilon)^{1/(1+P)}$$

So dependent on $\rho$ and minimum tax $\lambda$. Non-cooperative enforcement changes with enforcement technology, since uncoordinated enforcement is less effective when complementarity between enforcement increases.

(1) Enforcements are substitutes: $\rho = -1$, international enforcement is arithmetic mean of enforcement levels. FOC: $e_1^m = a_1(\lambda, \varepsilon) \geq e_2^m = \frac{a_2(\lambda,\varepsilon)}{2}$. Each country's choice of enforcement is independent of other country, good for each country to marginal benefit = marginal cost. Increasing enforcement induces higher tax and tax gap. Enforcement increases tax capacity in each country without affecting equilibrium tax base driven by revenue-maximising governments. Non-cooperative below cooperative since enforcement externalities no longer internalised.

**Proposition 3:** Enforcements are perfect substitutes ($\rho = -1$). High-tax countries benefit from enforcement cooperation for all $\lambda \in (a,1)$ and $\varepsilon \in (0,1)$, as for low-tax country minimum tax threshold $\lambda^0(\varepsilon) \in (0,1)$ and country asymmetry threshold: $0 < \underline{\varepsilon}(-1) \leq \bar{\varepsilon}(-1) < 1$.

Low-tax country benefits from enforcement cooperation when $\varepsilon < \underline{\varepsilon}(-1)$. Minimum tax can erode effect of enforcement cooperation for low-tax country. GMT Pareto improving when treating national enforcement policy as exogenous. Higher enforcement in both high & low-tax countries. Coordinated enforcement less attractive for low-tax country when GMT too high. Low-tax country benefits less from coordinated enforcement if country asymmetry too high.

(2) Enforcements are complements: enforcement productivity by one country increases with enforcement of the other country. No independent decisions with $\rho = -1$. Equilibrium enforcement levels: $e_i^m = \frac{a_i(\lambda,\varepsilon)^{3/4} a_j(\lambda,\varepsilon)^{1/4}}{...}$. Welfare function: $\omega_i^{NC}(\rho=0) = \frac{3}{2}\left(\frac{a_i(\lambda,\varepsilon)^2}{4}\right)\left(a_i(\lambda,\varepsilon)a_j(\lambda,\varepsilon)\right)^{1/2}$

**Proposition 4:** Enforcements are complements ($\rho > -1$). High-tax countries benefit from enforcement cooperation for all $\lambda$ and $\varepsilon$. Low-tax countries: minimum tax threshold $\lambda^0(\varepsilon, \rho) \in (0,1)$. Minimum tax threshold decreasing with asymmetry rate $\varepsilon$ and increasing with enforcement complementarity rate $\rho$. Enforcement complementarity: higher participation threshold for low-tax country by amount of enforcement complementarity (due to higher benefit of enforcement cooperation). Minimum tax to make low-tax countries defect of enforcement agreement (lower limit if higher asymmetry).

**Breakdown of cooperation**

Due to dynamics of tax and enforcement policies: high-tax can lose, low-tax can gain, via breakdown of enforcement cooperation. Low-tax country can freely opt out from enforcement agreement when minimum tax is too high = enforcement dilemma of minimum tax. High asymmetry: mutual beneficial cooperation, even without minimum taxation.

**Proposition 5:** $\rho = -1, 0, \infty$, minimum tax threshold $\lambda^0(\varepsilon, \rho) \in (0,1)$ and country asymmetry threshold $0 \leq \underline{\varepsilon}(\rho) \leq \bar{\varepsilon}(\rho) < 1$ so that: enforcement cooperation robust to minimum taxation when $\varepsilon \leq \underline{\varepsilon}(\rho)$ and enforcement cooperation never robust for $\varepsilon > \bar{\varepsilon}(\rho)$; for both cases introducing minimum tax is Pareto improving. For any $\underline{\varepsilon}(\rho) \leq \varepsilon \leq \bar{\varepsilon}(\rho)$: enforcement dilemma with breakdown of enforcement cooperation when minimum tax is $\lambda \geq \lambda^0(\varepsilon, \rho)$.

**Model extension with tax haven:** zero profit tax and zero enforcement effort. Additional country added. Haven not subject to minimum tax due to staying hidden from authorities and "water's edge" regulation: tax haven not in GMT union. Minimum tax increases profit shifted in non-participating haven, decreases profit shifted in low-tax country. Profit reported in high-tax country increases with minimum tax. If minimum tax pushed too far: low-tax country will defect from enforcement cooperation and high-tax country will be worse off.

**Conclusion** ✓