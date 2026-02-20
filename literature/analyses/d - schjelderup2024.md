# Schjelderup & Stähler (2024) — "The Economics of the Global Minimum Tax"
**International Tax and Public Finance, 31, 935–952**

p.935
Pillar 2 => increase empoyment and investment in low tax countries due to SBIE (deduct payroll and tangible assets from tax base of top up tax)
Pillar Two limits tax motivated transfer pricing, but changes employment, investment and import incentives

p.936
focus "how the top-up tax owed by subsidiaries in low-tax countries is calculated"

two effects on MNE behaviour: 
- tax base for top up tax implies production subsidy in low tax countreis taht may replace imports by foreign direct investment
- minimum tax makes transfer pricing manipulation less attractive => "imposes a cost on importing subsidiary"

- The production subsidy favours **capital-intensive industries** more than labour-intensive ones.
- Shell companies in tax havens (no "real activity") stand to **lose** under Pillar Two.
- Countries with genuine real investments (e.g., Ireland, Hungary) will be **less affected** because their SBIEs will be substantial.


## p. 936–938 — Section 2: Related Literature

**Tax coordination literature:**
- Konrad & Schjelderup (1999): a subgroup of countries can benefit from harmonising capital income taxes if tax rates are strategic complements in the non-cooperative Nash equilibrium.
- Keen & Konrad (2013): survey of tax coordination literature; minimum rate above the lowest observed outcome could be beneficial.
- Vrijburg & de Mooij (2016): from a theoretical perspective, strategic complementarity of tax rates is not guaranteed — a country may *reduce* its own tax rate following a tax increase abroad. Empirically, however, Brueckner (2003), Leibrecht & Hocgatterer (2012), and OECD (2020) find that statutory CIT rates *are* strategic complements.

**Profit shifting literature:**
- Heckemeyer & Overesch (2017): semi-elasticity of reported profits w.r.t. tax differentials ≈ 0.8.
- Garcia-Bernardo et al. (2021): lower effective CIT rates associated with higher reported profits relative to real activity indicators.
- Garcia-Bernardo & Janský (2022): profit shifted to low-tax jurisdictions is highly sensitive to the low-tax jurisdiction's own rate.
- Conclusion: if GMT raises the tax rate in low-tax countries, less profit will be shifted there, potentially dampening tax competition.

**Design of Pillar Two top-up tax base:**
- Devereux et al. (2021): the design of the tax base for the top-up tax is crucial for how Pillar Two affects tax competition.
- Devereux et al. (2022): the way the top-up tax is calculated puts downward pressure on CIT in source countries; source countries have a strong incentive to collect the top-up tax themselves (QDMTT). Conclusion: "Pillar Two effectively creates a floor on source country tax competition."

**Welfare effects — key theoretical models:**
- Hebous & Keen (2021): fixed profits, endogenous profit location. Two-country model based on Kanbur & Keen (1993). Haven may benefit or be harmed by GMT. If tax rates are strategic complements, both haven and non-haven may gain.
- Johannesen (2022): many haven and non-haven countries; capital is fixed; paper profits are mobile. Low-tax countries respond to GMT by *raising* their own CIT rate, which curbs profit shifting but reduces MNC after-tax profits. Net welfare effect for non-havens is **ambiguous** — depends on whether revenue gain from less shifting exceeds the loss in MNC after-tax profits.
- Janeba & Schjelderup (2022): one haven, two non-havens; mobile capital. GMT (modelled as exogenous tax increase in haven) increases revenues in non-havens via less profit shifting, but this raises the *value* of attracting FDI, intensifying tax competition among non-havens. Revenue/welfare effects depend on whether governments compete via **tax rates** (revenue may increase) or **firm-specific/uniform subsidies** (revenue gains from less profit shifting are exactly offset by higher subsidies). Key difference from Johannesen (2022): includes real relocation effect between non-haven countries.
- Hindriks & Nishimura (2022): heterogeneous countries; finds that low-tax country **always gains** and that a critical threshold exists above which the high-tax country is worse off.
- Kurian (2022): some developing countries may lack expertise to implement Pillar Two.

**Contribution of this paper:**
- Sets itself apart by embedding the *design of Pillar Two* (specifically the SBIE) directly into a model of MNC behaviour, studying effects on investment, factor demand, and profit shifting in low-tax countries.

## p. 938–940 — Section 3: The Design of Pillar Two Rules

**Mechanics of the top-up tax:**

1. Calculate **GloBE income** (the income of the subsidiary in the low-tax country).
2. Calculate **covered taxes** on that income.
3. **ETR** = covered taxes / GloBE income.
4. If ETR < 15%, the **top-up tax rate** = 15% − ETR.
5. The top-up tax rate is applied to **excess profits** = GloBE income − SBIE.
6. **SBIE** = (carve-out rate × payroll costs) + (carve-out rate × carrying value of eligible tangible assets).
   - Initial rates: 10% on payroll, 8% on tangible assets.
   - These rates are scheduled to decline to **5% for both** over a ten-year period.
7. **Top-up tax owed** = excess profits × top-up tax rate.

**Collection mechanism:**
- Top-up tax can be collected by the **residence country** (via the Income Inclusion Rule, IIR) or by the **source country** if it implements a **Qualified Domestic Minimum Top-up Tax (QDMTT)**.
- QDMTT: if a domestic minimum tax meets the QDMTT conditions, any QDMTT paid is fully creditable against Pillar Two liability. This changes the order in which jurisdictions may charge top-up taxes.
- Low-tax countries have a clear incentive to implement a QDMTT: businesses pay the same tax regardless, but the revenue goes to the domestic government rather than to the headquarters country — without any need to change the headline CIT rate.

**Numerical example (p. 939):**

Given: GloBE income = USD 1,000; covered taxes = USD 50; payroll costs = USD 500; tangible assets = USD 7,500.

$$t^{ERT} = 50/1000 = 0.05$$
$$t^{TOP} = 15 - 5 = 10\%$$
$$SBIE = 0.1 \times 500 + 0.08 \times 7500 = 650$$
$$E = 1000 - 650 = 350$$
$$\text{Top-up tax} = 350 \times 0.1 = 35$$
$$\text{Total tax} = 50 + 35 = 85 \Rightarrow \text{True ETR} = 8.5\%$$

Using the long-term 5% carve-out rate instead: true ETR = 11.5% — **still below 15%**.

**Key insight from the example:**
- "Pillar Two will not bring the total amount of taxes paid on an MNC's excess profit in a low-tax jurisdiction up to the minimum rate of 15% as long as the Substance-based Income Exclusion is positive."
- The SBIE allows countries to **continue competing over tangible investments** (both capital and labour) up to a point.
- Countries with real MNC activity (Ireland, Hungary) are **less affected**; pure shell company havens are **hurt**.
- The authors note an important design oddity (footnote 7): applying a common carve-out rate to both a *flow* variable (payroll) and a *stock* variable (tangible assets) is conceptually non-standard. No rationale is given in OECD (2021, p. 3) beyond allowing tax incentives for "substantive activities."

## p. 940–943 — Section 4: The Model

**Production function (Cobb-Douglas):**

$$x = AF(L,K,M) = AL^\lambda K^\kappa M^\mu \tag{1}$$

where $\alpha \equiv \lambda + \kappa + \mu \leq 1$ and $A = (\lambda^\lambda \kappa^\kappa \mu^\mu)^{1/\alpha}/\alpha$ normalises output. Decreasing or constant returns to scale. The Cobb-Douglas form is chosen because it allows use of a minimal set of assumptions on cost shares and effective factor price changes.

**Three inputs:**
- **L**: labour, sourced locally, fully tax-deductible.
- **K**: capital; interest on debt is fully tax-deductible; depreciation deductibility depends on host country rules.
- **M**: material input, sourced from headquarters location; subject to transfer pricing.

**Cost function (given effective factor prices w, r, q):**

$$C(w,r,q,x) = (w^\lambda r^\kappa q^\mu x)^{1/\alpha} \tag{2}$$

**Marginal cost:**

$$C' = \frac{1}{\alpha} x^{\frac{1}{\alpha}-1}(w^\lambda r^\kappa q^\mu)^{1/\alpha} \tag{3}$$

**Factor demands:**

$$L = \frac{\lambda}{\alpha w}(w^\lambda r^\kappa q^\mu x)^{1/\alpha} \tag{4a}$$
$$K = \frac{\kappa}{\alpha r}(w^\lambda r^\kappa q^\mu x)^{1/\alpha} \tag{4b}$$
$$M = \frac{\mu}{\alpha q}(w^\lambda r^\kappa q^\mu x)^{1/\alpha} \tag{4c}$$

**Economic profit of the subsidiary:**

$$\pi^* = R(x) - \omega L - \phi i K - (1-\phi)\rho K - \delta K - qM$$

where $\omega$ = wage rate, $\rho$ = opportunity cost of debt-financed capital, $i$ = opportunity cost of equity, $\delta$ = economic depreciation rate, $\phi$ = equity share.

**Corporate tax base (GloBE income) without GMT:**

$$\pi^*_t = R(x) - \omega L - (1-\phi)\rho K - \tilde{\delta} K - qM$$

where $\tilde{\delta}$ = tax-deductible depreciation rate. Only debt cost is deductible.

**After-tax profit without GMT:**

$$\Pi^* = \pi^* - t^*\pi^*_t = (1-t^*)\left[R(x) - \omega L - \left[(1-\phi)\rho + \tilde{\delta} + \frac{\phi i + (\delta - \tilde{\delta})}{1-t^*}\right]K - qM\right] \tag{5}$$

**effective rental**

$$r^* \equiv (1-\phi)\rho + \tilde{\delta} + \frac{\delta - t^*\tilde{\delta}}{1-t^*} + \frac{\phi i}{1-t^*}$$

**Transfer pricing (concealment cost approach):**

Headquarters in high-tax country (rate $t$), subsidiary in low-tax country (rate $t^*$, with $t > t^*$). Transfer price per unit of M = $q$; true cost = $\gamma$. Under-invoicing M reduces the transfer price below $\gamma$, shifting profit to the low-tax subsidiary. The concealment cost is $\beta(\gamma - q)^2 M/2$ (tax-deductible at headquarters). (See footnotes 2–3 for references: Haufler & Schjelderup (2000); Nielsen et al. (2008, 2010, 2014).)

**Aggregate after-tax profit:**

$$\Pi = (1-t^*)\left[R(x) - \omega L - \left[(1-\phi)\rho + \tilde{\delta} + \frac{\phi i + (\delta-\tilde{\delta})}{1-t^*}\right]K - qM\right] + (1-t)M\left[q - \gamma - \frac{\beta(q-\gamma)^2}{2}\right] \tag{6}$$

**Optimal transfer price (maximising after-tax value of transfer pricing w.r.t. $q$):**

$$q^* = \gamma - \frac{t - t^*}{\beta(1-t)} < \gamma$$

If $t - t^* = 0$: no incentive to shift, $q^* = \gamma$. Example: $\gamma=1, \beta=2, t=30\%, t^*=5\%$: $q^* = 0.82$, i.e. a **18% understatement** of the transfer price relative to true cost (footnote 4: if concealment cost deductible in subsidiary country instead: $q^* = 0.87$). Empirical support cited from Wier (2020) for South African data: transfer price from low-tax countries is 31% higher than arm's-length comparators on average.

**Depreciation data (footnote 6, from RSIT International Tax Institutions Database, Wamser et al. (2023)):**

Economic depreciation rates: buildings 3.61% p.a., machinery 12.25% p.a. (Egger et al., 2009).
- Straight Line Method (n=3,364 observations): average tax-deductible rates: buildings 5.41%, machinery 17.76%.
- Declining Balance Method (n=729): buildings 7.78%, machinery 24.97%.

Conclusion: "on average — the applied depreciation rules act as an investment subsidy" already before Pillar Two.

**Debt/equity structure (footnote 10):**
- Møen et al. (2019): average debt ratio of German MNCs 1996–2006 = 62% (equity share 38%).
- Goldbach et al. (2021): this declined to ≈50% equity share between 1999–2017.
- Opportunity cost of equity assumed at 5% (conservative; 10-year government bond yields not exceeded 5% since 2010 in major economies, per OECD 2023b).

---

## p. 944–948 — Section 5: The Effects of Pillar Two

**SBIE definition:**

Excess profit: $E = \pi^*_t - \sigma(\omega L + K)$, where $\sigma$ is the carve-out fraction (converging to 5% in the long run). If $\pi^*_t - \sigma(\omega L + K) \leq 0$, the GMT has no effect — some capital-intensive manufacturing subsidiaries may fall in this category. Shell companies will definitely be affected. Analysis is confined to subsidiaries for which $\sigma(\omega L + K) < \pi^*_t$ continues to hold, though some bunching at $\sigma(\omega L + K) = \pi^*_t$ is expected.

**After-tax profit under GMT (replaces equation 5):**

$$\Pi^* = \pi^* - T\pi^*_t + (T-t^*)\sigma(\omega L + K)$$

$$= (1-T)\left[R(x) - \left[\omega - \frac{\sigma(T-t^*)\omega}{1-T}\right]L - qM\right] - (1-T)K\left[(1-\phi)\rho + \tilde{\delta} + \frac{\phi i + (\delta-\tilde{\delta})}{1-T} - \frac{\sigma(T-t^*)}{1-T}\right] \tag{7}$$

Note (footnote 8): if $L = K = 0$ (shell company with no genuine activity), the tax equals $T\pi^*_t$, so the effective tax rate is exactly the minimum tax $T$.

**Effect 1 — Effective wage rate (labour subsidy):**

Wage costs are deductible *twice* under Pillar Two (once from GloBE income, once via SBIE), equivalent to a wage subsidy:

$$w^{**} \equiv \omega\left(1 - \frac{\sigma(T-t^*)}{1-T}\right) < w^*$$

Maximum size: $\sigma(T-t^*)/(1-T) < \sigma T/(1-T) = 0.88\%$ for $\sigma=0.05, T=0.15$. So the **wage subsidy is moderate** (less than 0.88%).

**Effect 2 — Transfer pricing becomes less attractive:**

The new effective transfer price:

$$q^{**} = \gamma - \frac{t - T}{\beta(1-t)} > q^*$$

Since $T > t^*$, the minimum tax rate replaces the subsidiary's tax rate in the formula, raising the effective cost of the material input. Numerical example: transfer price increases by 8.7% from 0.82 to 0.89.

**Effect 3 — Effective rental rate (capital subsidy):**

New effective rental:

$$r^{**} \equiv (1-\phi)\rho + \frac{\delta - T\tilde{\delta}}{1-T} - \frac{\sigma(T-t^*)}{1-T} + \frac{\phi i}{1-T}$$

Difference between new and old effective rental:

$$r^{**} - r^* = -\frac{(T-t^*)\left[\underbrace{(1-t^*)\sigma}_{I} - \underbrace{(\delta-\tilde{\delta})}_{II}\right]}{(1-t^*)(1-T)} + \underbrace{\frac{\phi i(T-t^*)}{(1-t^*)(1-T)}}_{III} \tag{8}$$

- Term **I**: the SBIE investment subsidy effect — positive when $(1-t^*)\sigma > (\delta - \tilde{\delta})$. Since $t^* < 0.15$ triggers GMT and $\sigma \geq 0.05$: $(1-t^*)\sigma > 3.61\%$, which exceeds any plausible gap between economic and tax-deductible depreciation.
- Term **II**: counteracted by any excess of economic over tax-deductible depreciation (if $\tilde{\delta} > \delta$, the depreciation allowance already subsidises investment and the SBIE makes it stronger).
- Term **III**: equity cost increase (small: $\phi i T/(1-T) = 0.44\%$ under the baseline assumptions).

Numerical results for $t^* = 5\%$ (baseline, Straight Line Method):
- Machinery: $r^{**} - r^* = -0.96\%$
- Buildings: $r^{**} - r^* = -0.50\%$

For $t^* = 10\%$ (footnote 11): -0.49% (machinery) and -0.25% (buildings) — "still sizable in the context of rentals."

Conclusion: "the effective rental will decline in response to the introduction of Pillar Two" — the SBIE works like a **strong investment subsidy**.

**Proposition 1:**
"For a sufficiently large cost share of labor and/or capital, Pillar Two is equivalent to a production subsidy in low-tax countries."

*Proof sketch (from Appendix A.1):* Define $\Gamma = w^\lambda r^\kappa q^\mu$. Relative change in marginal cost for unchanged output: $\hat{C}' = \hat{\Gamma}/\alpha$ where $\hat{\Gamma} = \lambda\hat{w} + \kappa\hat{r} + \mu\hat{q}$. Since $\hat{w}, \hat{r} < 0$ and $\hat{q} > 0$: $\hat{\Gamma} < 0$ if $\lambda\hat{w} + \kappa\hat{r} < -\mu\hat{q} = -(\alpha-\lambda-\kappa)\hat{q}$, which holds when $\lambda$ and/or $\kappa$ are sufficiently large. $\hat{\Gamma} < 0$ reduces marginal cost, implying an increase in output.

**Figure 1 (p. 949):** Shows the critical percentage increase in the transfer price ($\hat{q}^*$) at which production remains unchanged, for four labour cost share values ($\lambda = 0.2, 0.4, 0.55, 0.7$) and varying capital cost shares ($\kappa$), with $\mu = 1-\lambda-\kappa$. The **coloured area below the $\hat{q}^*$-line** represents combinations of factor shares for which Pillar Two acts as a production subsidy. The required increase in the transfer price to produce $\hat{x} < 0$ must be "substantial unless $\kappa$ is small and thus the cost share of material input $\mu$ is relatively large." Baseline assumptions (footnote 12): $\phi=0.5, \rho=0.05, \tilde{\delta}=0.1776, \delta=0.1225, t^*=0.05, \sigma=0.05, T=0.15$.

**Proposition 2:**
"Assume that the effective rental decreases with the introduction of the global minimum tax, that is, $\hat{r} < 0$. Material imports decrease if output decreases. Labor demand increases (decreases) if the wage change is sufficiently small (large) such that $\hat{w} < (>) (\kappa\hat{r} + \mu\hat{q} + \hat{x})/(\kappa+\mu)$. Capital demand increases (decreases) if the rental change is sufficiently small (large) such that $\hat{r} < (>) (\lambda\hat{w} + \mu\hat{q} + \hat{x})/(\lambda+\mu)$."

*Proof (Appendix A.2):* Differentiating logs of factor demand equations (4a–4c):

$$\hat{L} = -(1/\alpha)[(\kappa+\mu)\hat{w} - \kappa\hat{r} - \mu\hat{q} - \hat{x}]$$
$$\hat{K} = -(1/\alpha)[(\lambda+\mu)\hat{r} - \lambda\hat{w} - \mu\hat{q} - \hat{x}]$$
$$\hat{M} = -(1/\alpha)[(\lambda+\kappa)\hat{q} - \lambda\hat{w} - \kappa\hat{r} - \hat{x}]$$

**Numerical illustration (footnote 14):** $\lambda=0.7, \kappa=0.2, \mu=0.1$; other assumptions as in footnote 12.

- $\lambda\hat{w} + \kappa\hat{r} + \mu\hat{q} = -0.0067 < 0$ → output *will increase*.
- If output held constant: labour demand increases by **0.43%**, capital demand by **4.04%**, material input demand decreases by **6.29%**.
- With output increase, all increases are larger: "the global minimum tax works like a large investment subsidy even if the cost share of capital is relatively small."
- Material input demand declines unless output increases by more than 6.29% → "Pillar Two is likely to replace imports by foreign direct investment."

**Additional distortion analysis:**
- Transfer pricing already makes material imports inefficiently large; Pillar Two *reduces* (but does not eliminate) this distortion. (Footnote 15: in the numerical example, the amount of transfer pricing $(\gamma-q)M$ declines by less than 42.7%.)
- Pillar Two **exacerbates** the capital demand distortion (adds to pre-existing investment subsidy from generous depreciation allowances).
- Pillar Two **introduces** a new labour market demand distortion where none existed before.

---

## p. 948–950 — Section 6: Concluding Remarks

**Main conclusion:** Pillar Two "fails to implement the claimed 15% minimum corporate tax for subsidiaries of multinational corporations in low-tax countries that are not shell companies." This is due to the SBIE allowing double deduction of payroll costs and user costs of tangible assets.

**Distributional/sectoral heterogeneity:** The SBIE as a production subsidy "favors capital-intensive industries over labor-intensive industries since the subsidy to capital is larger than the subsidy to wages."

**OECD rationale (quoted directly from OECD (2021), p. 3):** "[a] substance carve-out based on assets and payroll costs allows a jurisdiction to continue to offer tax incentives that reduce taxes on routine returns from investment in substantive activities, without triggering additional GloBE top-up tax. Given the carve-out covers investment in both tangible assets and payroll, it will have broad application to a wide range of different industries." The authors note that their paper shows "these effects can be indeed very strong and heterogeneous across industries."

**Welfare implications — not clear:**
- Pillar Two *reduces* transfer pricing distortions but *exacerbates* capital demand distortions and *introduces* a new labour market demand distortion in genuine-activity low-tax countries.
- Justifiable if net effect is larger MNC output, but the long-run implications of a 5% carve-out rate across industries are unclear.
- "It may be a rude awakening for policymakers when the public realizes that the global minimum tax does not imply the same effective tax rate of 15% for a large number of industries."

**Shell companies and IIR (Income Inclusion Rule):**
- Pillar Two is likely to **increase tax revenues from shell companies** in tax havens.
- Common practice: locate intangibles in low-tax countries, over-invoice subsidiaries in high-tax countries.
- Via the **IIR**, the headquarter country collects the top-up tax → effective rate = 15% (since no genuine activity and therefore SBIE = 0; see footnote 17: "This is the case when the carve-out is zero").
- Transfer pricing incentive also dampened in this case.

**Policy conclusion:** "how Pillar Two will play out across jurisdictions will crucially depend on the type of multinational activity in the respective country."
