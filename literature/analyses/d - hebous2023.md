# Hebous & Keen (2023) — "Pareto-Improving Minimum Corporate Taxation"
**Journal of Public Economics, 225, 104952**

## Page 1 (Introduction)

The paper is published in the Journal of Public Economics (2023), vol. 225. Hebous is at the IMF Fiscal Affairs Department and CESifo; Keen is at Tokyo College (University of Tokyo), CERDI, Oxford Centre for Business Taxation, and IFS London.

JEL codes: H21, H25, F23. Keywords: tax competition, minimum taxation, corporate tax reform, international taxation.

Abstract in brief: the paper explores strategic responses to a minimum corporate tax rate. The core claim is that analysis and calibration "plausibly suggest sizable scope for minima that are Pareto-improving, benefiting low tax countries as well as high, relative to the uncoordinated equilibrium."

Introduction notes:

- For decades, proposals for a common minimum effective corporate tax rate had "virtually no practical traction." The October 2021 G-20/OECD Inclusive Framework agreement (136 members) established a minimum effective rate of 15%, with implementation beginning 2024. This is "Pillar Two" of a wider package (see OECD 2021a). Agreement does not oblige a member to impose the minimum but does oblige it to accept imposition by others even on earnings in that country.

- The appropriate level of the minimum rate "has been, and remains, extremely contentious." Civil society argues 15% is far too low; many low-tax countries (notably Ireland, statutory rate 12.5%) expressed "forceful reservations."

- The trade-off for low-tax countries: (i) loss from reduced inward profit shifting and investment; (ii) potential revenue gain if they raise their rate to the minimum. OECD (2020) para. 256 estimates a 12.5% minimum might reduce profits booked in investment hubs by around 10% (excluding U.S.-parented multinationals). Clausing (2020) suggests GILTI provisions (roughly a 10.5-13.125% minimum on U.S. affiliates' earnings abroad) might reduce the corporate tax base of low-tax jurisdictions by 12-16%, potentially almost double if applied globally rather than per country.

- Popular perception: low-tax countries, forced to set a higher rate, "must, as a result, be losers." But the paper argues there is more to it.

- The key point: assessing welfare implications for a low-tax country requires moving beyond the static trade-off and beyond the implicit presumption in policy debate that a minimum tax will not change the tax-setting behaviour of high-tax countries. "The purpose of the minimum, after all, is precisely to alter the rules of the tax competition game."

- Two central questions posed: (1) How high a minimum rate would a low-tax country most prefer? (2) How high can the minimum be set while still leaving the low-tax country better off than in the uncoordinated equilibrium?

- The paper characterises two critical minimum rates in a two-country Nash game (focusing on profit shifting, not real investment):
    - mu* = the Pareto efficient minimum rate (most preferred by the low-tax country; with the high-tax country always gaining from higher minimum, this is also the Pareto efficient rate)
    - mu** = the maximal Pareto dominant rate (highest minimum at which the low-tax country is still welfare-superior to the uncoordinated equilibrium)

- Both critical rates can be expressed as simple multiples of the Nash equilibrium rate of the low-tax country. This is exploited to numerically assess the scope for mutual gain.

- Framework: a "fairly straightforward generalization" of Kanbur & Keen (1993), which modelled tax competition between revenue-maximising governments. Key extension: governments are allowed to have positive and potentially different valuations of private income (i.e., not purely revenue-maximising). This is a "substantive extension."



## Page 2 (Section 2: Tax competition with profit shifting / Section 2.1: Context)

Section 2 lays out the model and the uncoordinated Nash equilibrium.

Section 2.1 Context:

- The model abstracts from many details of the 2021 Inclusive Framework agreement and its Model Rules (OECD 2021b) and EU implementing Directive (Council of the European Union, 2022). Aspects set aside include: less-than-complete scope (only largest multinationals included), and the exclusion of a modest substance-based return (see UNCTAD 2022 for details).

- Key consistency with the actual agreement: any "top-up" tax needed to bring liability to the minimum is levied by the source country. This is the "Qualified Domestic Minimum Top-up Tax" (OECD 2021b). While not mandatory, the implementing rules give the source country primacy, and it is in the source country's interest to collect rather than having the residence country collect.

- Three features highlighted:

    1. Two asymmetric countries. Lower-tax country denoted by lowercase (t, w), higher-tax by uppercase (T, W).

    2. Tax competition is for "paper profits" rather than real activity. Real activity is fixed, so there is no possibility that profit shifting opportunities reduce the cost of capital and thereby encourage real investment (see Suárez Serrato 2018 and Klemm & Liu 2021 for evidence). The paper notes emerging interest in investment effects of minimum corporate taxation (Hanappi & Cabral 2022 find modest effects; Keen et al. 2023 find significant increases in inward tangible investment for high-tax countries). Since the policy debate has centred on competition for paper profits, the paper focuses there.

    3. Countries play Nash. The alternative (first-mover/Stackelberg) leads to a "striking" result: the low-tax country, whether it follows or leads, loses from a minimum just above its Nash rate. The paper focuses on Nash as at least as plausible and important.

- Immediate welfare implications of a minimally binding minimum (forcing a small increase dt > 0 in t from t^N):

    - High-tax country: dW = W_t * dt, and W_t > 0, so welfare is certainly positive.
    - Low-tax country: dw = dw_T * (dT/dt), which is positive if and only if tax rates are strategic complements for the high-tax country (i.e., the high-tax country raises T in response to a higher t).

- Strategic complementarity: "perhaps the more instinctive and commonplace assumption, but not theoretically assured." Vrijburg & de Mooij (2016) show that a tax increase abroad (leading to an inflow of investment and hence higher domestic revenue) may lead the domestic government to reduce its rate if the degree of substitutability between domestic public good and private consumption is sufficiently low. Empirically, however, "the weight of evidence suggests that statutory corporate tax rates are strategic complements" (reviews: Brueckner 2003; Leibrecht & Hocgatterer 2012; OECD 2020). Magnitude estimates:
    - Devereux et al. (2008): 1 pp. increase in average foreign statutory rate induces 0.34-0.67 pp. increase in home rate (advanced countries).
    - IMF (2022): point estimates of 0.25 and 0.42 pp. for OECD and non-OECD respectively (with time trend), up to 0.6 pp. (ignoring trend).
    - Crivelli et al. (2016): 0.25-0.3 pp. response.

- But the result that an infinitesimally binding minimum is Pareto-improving is "hardly enough for policymaking and assessment," leading to the two key questions: what is the Pareto efficient minimum, and how high can the minimum be while leaving the low-tax country better off than in the Nash equilibrium?



## Page 3 (Section 2.2: The uncoordinated Nash equilibrium)

Section 2.2 sets up the formal model. It is a generalisation of Kanbur & Keen (1993) allowing governments to care about private income in addition to tax revenue. Countries differ in size and in their taste for public spending.

The representative citizen-multinational of each country earns a fixed amount of pre-tax profit: pi (low-tax country) and Pi (high-tax country), both strictly positive. These can be declared in either country. Profit shifting: the proportion of profit shifted to the low-tax country is s, with quadratic shifting costs C(s) = (delta/2)s^2 (non-deductible), parameterised by delta > 0. Profit shifting equilibrium: s = (T - t) * Pi / delta (profits shifted only out of the high-tax country). Shifting costs are thus (T - t)^2 * Pi / (2 * delta).

Welfare in each country = private after-tax income + tax revenue, where tax revenue is weighted by the marginal valuation of public spending:
- lambda in the low-tax country
- Lambda in the high-tax country
- Both strictly greater than unity.

Welfare of the low-tax country (eq. 1):

w(t, T) = (1 - t) * pi + lambda * t * (pi + ((T - t) / delta) * Pi)

- First term: after-tax income of the resident shareholder.
- Second term: social value of tax revenue, from both the resident multinational and the shifted profits s * Pi.

Differentiating with respect to t (eq. 2):

w_t(t, T) * delta / Pi = (lambda - 1) * delta * theta + lambda * T - lambda^2 * t

where theta = pi / Pi is the ratio of pre-tax profits of the two countries' residents (indicator of relative size). Second derivative: w_tt * delta / Pi = -lambda^2 < 0, confirming second-order condition satisfied.

Important implication: "a discrete forced increase in the tax rate set by the low tax country above its level in any Nash equilibrium thus reduces its welfare" -- consistent with the popular view -- but "all else will generally not be equal" because the high-tax country will respond.

Best response of low-tax country (eq. 3):

t(T) = (1/2) * [((lambda - 1)/lambda) * delta * theta + T]

Cross-partial: w_T(t, T) = (lambda * t * Pi) / delta > 0, so the low-tax country always benefits from a tax increase in the high-tax country (via increased inward profit shifting).

Welfare of the high-tax country (eq. 4):

W(T, t) = Pi - T*(1 - (T-t)/delta)*Pi - t*((T-t)/delta)*Pi - (1/2)*((T-t)^2/delta)*Pi + Lambda*T*(1 - (T-t)/delta)*Pi

- First four terms: after-tax income (only un-shifted profits are taxed at T, the rest at t, and there are shifting costs).
- Final term: tax revenue from un-shifted profits at rate T.

This can be rewritten (eq. 5) as:

W(T, t) = (1 - T)*Pi + (1/2)*((T-t)^2/delta)*Pi + Lambda*T*(1 - (T-t)/delta)*Pi

The second term P(T, t) = (1/2) * (T-t)^2 / delta * Pi (eq. 6) reflects the private gain from profit shifting (tax saving net of shifting costs).

The paper then allows for "signs of political and social discontent" with private gains from profit shifting, noting that countries denied pandemic-related support specifically to companies present in low-tax jurisdictions. This is analogous to the welfare analysis of tax evasion (Cowell 1990). Evidence cited: HMRC (2015) survey found 61% of respondents felt tax avoidance is never acceptable; Scarpa & Signori (2020) conclude tax avoidance is "widely perceived at least as a morally doubtful practice."

To allow for discounting of the private gain from profit shifting, the paper generalises by replacing the 1/2 in the second term by a parameter alpha in [0, 1/2] (eq. 7):

W(T, t) = (1 - T)*Pi + alpha*((T-t)^2/delta)*Pi + Lambda*T*(1 - (T-t)/delta)*Pi

- alpha = 1/2: full social valuation of the net private gain from profit shifting.
- alpha = 0: zero social valuation.



## Page 4 (Section 2.2 continued and Proposition 1)

Differentiating W with respect to T (eq. 8):

W_T(T, t) * delta / Pi = (Lambda - 1) * delta + t*(Lambda - 2*alpha) + 2*T*(alpha - Lambda) = 0

Best response of the high-tax country (eq. 9):

T(t) = (1/2) * [((Lambda - 1)/(Lambda - alpha)) * delta + ((Lambda - 2*alpha)/(Lambda - alpha)) * t]

This best response shifts upward with an increase in either Lambda or alpha. The former is as expected. The latter: a higher valuation of the private gain from shifting implies greater willingness to accept the increase in profit shifting induced by raising T.

Slope of high-tax country's best response (eq. 10):

T'(t) = (1 - 2*(alpha/Lambda)) / (2*(1 - (alpha/Lambda))) > 0

This shows strategic complementarity. The slope depends only on (and is decreasing in) the ratio alpha/Lambda (marginal social value of the private gain from profit shifting relative to that of tax revenue). A higher Lambda (revenue valuation) steepens the best response; a higher alpha (private gain valuation) flattens it. The flattening effect of alpha is explained by eq. 11: P_tT(T, t) = -Pi/delta < 0, meaning a higher t in the low-tax country reduces the extent to which raising T increases the private gain from shifting, which weakens the incentive to raise T. With higher alpha, this consideration carries more weight, amplifying the flattening.

Cross-partial for the high-tax country: the spillover W_t has the sign of (Lambda - 2*alpha)*T + 2*alpha*t, which is always positive, confirming that the high-tax country always gains from an increase in the low-tax rate.

Proposition 1: If (Lambda - 1)/Lambda > ((lambda - 1)/lambda) * theta (condition 12), there exists a unique Nash equilibrium with t^N < T^N, where:

t^N = delta * ((Lambda - alpha)/(3*Lambda - 2*alpha)) * [((lambda-1)/lambda)*2*theta + ((Lambda-1)/(Lambda-alpha))] (eq. 13)

T^N = (delta/2) * [4*(Lambda-1)/(3*Lambda-2*alpha) + ((Lambda-2*alpha)/(3*Lambda-2*alpha))*((lambda-1)/lambda)*2*theta] (eq. 14)

From this, (T^N - t^N)/delta = (Lambda/(3*Lambda - 2*alpha)) * ((Lambda-1)/Lambda - ((lambda-1)/lambda)*theta) (eq. 15)

The condition in (12) implies the country with the lower tax rate is characterised by a relatively small share of global profits (size effect familiar in tax competition) and/or a relatively low marginal valuation of public spending. Both Nash rates increase in Lambda, lambda, and alpha, and decrease in theta. The result that both rates increase in alpha: a higher social value of outward profit shifting by the high-tax country leads it to raise T, which induces a higher rate in the low-tax country.

When both governments maximise revenue (lambda, Lambda -> infinity) and theta < 1, eq. (13) reduces to t^N = delta*(1 + 2*theta)/3, as in Proposition 1 of Kanbur & Keen (1993).



## Page 5 (Section 3: Implications of a minimum rate / Section 3.1)

Section 3 introduces a minimum rate mu >= t^N, binding on the low-tax country, which then induces the high-tax country to set T(mu).

Section 3.1: The Pareto efficient and maximally dominant rates.

High-tax country: always benefits from an increase in mu (since W_t > 0), so prefers the highest possible minimum.

Low-tax country: welfare in the presence of the minimum (eq. 16):

w(mu) * delta / Pi = [1 + (lambda - 1)*mu]*delta*theta + lambda*mu*(T(mu) - mu)

Derivative with respect to mu (eq. 17):

w'(mu) * delta / Pi = (lambda - 1)*delta*theta + lambda*(T(mu) - mu) + lambda*mu*(T' - 1)

The three components:
- First two terms: positive -- gain from higher taxation of the domestic tax base, and gain from increased tax receipts from initially shifted profits.
- Third term: negative -- since T' < 1 (from eq. 9), the extent of profit shifting (proportional to T - t) falls, which is a welfare loss for the low-tax country.

The dynamic: at levels just above t^N, the positive effects dominate. As mu increases, the revenue loss from declining profit shifting "looms increasingly large." Eventually, a further slight increase in mu causes a contraction in the "profit-shifting-inclusive tax base" that exactly offsets the additional revenue gain. Welfare w(mu) reaches a peak at mu*: the "Pareto efficient minimum tax rate."

Beyond mu*, the marginal reduction in the low-tax country's shifting-inclusive tax base strictly dominates the mechanical revenue gain. At mu**, welfare falls back to w^N (the Nash equilibrium level): this is "the maximal Pareto dominant minimum rate, being the highest level at which the minimum can be set without making the low tax country worse off than in the Nash equilibrium."

Three zones of interest/conflict (illustrated in Figures 1 and 2):
- t^N to mu*: both countries gain, unanimity.
- mu* to mu**: high-tax country gains, low-tax country gains less but still prefers to Nash, some conflict at the margin.
- Beyond mu**: low-tax country would prefer no minimum at all.

Figure 2 discussion: the minimum introduces a vertical segment into the low-tax country's best response, shifting the Nash equilibrium from A to B. The low-tax country's most preferred minimum mu* is at D (iso-welfare contour tangent to T(t)); mu** is at C (iso-welfare contour through A intersects T(t)).

Important complication: since T'(t) < 1, at some level (eq. 18):

mu-bar = ((Lambda - 1)/Lambda) * delta

the minimum also binds the high-tax country (this is point E in Fig. 2 where T(t) cuts the 45-degree line). At mu > mu-bar, both countries set the minimum rate and welfare in each rises indefinitely with further increases in mu. This is "a relatively uninteresting possibility" because (i) at some point the assumption that marginal valuations of public spending do not decline with revenue would become untenable; (ii) more fundamentally, setting such a minimum "is equivalent to complete harmonization, and at a rate that is strictly above the higher of the Nash equilibrium rates." Not on any political agenda. The paper therefore restricts attention to mu <= mu-bar.

Proposition 2:

(a) Pareto efficient minimum tax rate = max(mu*, mu-bar), where:

mu* = delta * [((lambda - 1)*(Lambda - alpha)*2*theta + lambda*(Lambda-1)) / (2*lambda*Lambda)] (eq. 19)

(b) Maximal Pareto dominant minimum rate = max(mu**, mu-bar), where:

mu** = delta * [((Lambda - alpha)^2 / (Lambda*(3*lambda - 2*alpha)))] * [((lambda - 1)/lambda)*4*theta + (2*(Lambda-1)/(Lambda-alpha))] > mu* (eq. 20)

Proof: w(mu) is strictly concave in mu (T'' = 0, T' < 1), so unique maximum found by setting w'(mu*) = 0. For mu**, substitute T(mu) into (16) to get (eq. 21):

w(mu) = delta*theta + delta*[(lambda*(Lambda-1))/(2*(Lambda-alpha)) + (lambda-1)*theta]*mu - (lambda*Lambda/(2*(Lambda-alpha)))*mu^2

This is quadratic in mu. By symmetry of the quadratic: mu** = t^N + 2*(mu* - t^N) = 2*mu* - t^N. This is proven formally in Appendix A.



## Page 6 (Figures 1 and 2, and Section 3.1 continued: three cases)

Figure 1 description (see figure in paper):
- Horizontal axis: mu (minimum rate), starting from t^N.
- Vertical axis: welfare of each country, relative to Nash equilibrium levels w^N and W^N.
- W(mu) is strictly increasing and convex throughout (high-tax country always gains).
- w(mu) initially increases, reaches peak at mu* (Pareto efficient rate), then declines, crossing w^N at mu** (maximal Pareto dominant rate).
- Points mu-bar^U, mu-bar^PC, mu-bar^PL represent hypothetical levels at which the minimum binds the high-tax country.

Figure 2 description (see figure in paper):
- In (t, T) space. Nash equilibrium at A (intersection of unconstrained best responses t(T) and T(t)).
- Minimum mu introduces a vertical segment into the low-tax country's best response, shifting equilibrium to B.
- mu* is at D (iso-welfare contour tangent to T(t)).
- mu** is at C (iso-welfare contour through A intersects T(t)).
- E: T(t) cuts the 45-degree line (point at which minimum also binds the high-tax country), corresponding to mu-bar.

Three cases (comparing mu*, mu**, and mu-bar):

Case U (Unanimity): mu-bar <= mu*, i.e., a higher minimum always benefits both countries. Condition (eq. 22):

((Lambda-1)/Lambda) / ((lambda-1)/lambda) < (1 - alpha/Lambda) * 2*theta

Case PC (Potential Conflict): mu* <= mu-bar < mu**, meaning the low-tax country always gains relative to Nash, but there is potential conflict in that beyond some point (but before the high-tax country becomes constrained) the low-tax country loses from marginal increases. Applies when neither (22) nor (23) holds.

Case PL (Potential Loss): mu** < mu-bar, so there exist minima that do not bind the high-tax country but imply a welfare loss for the low-tax country relative to Nash. Condition (eq. 23):

((Lambda-1)/Lambda) / ((lambda-1)/lambda) > (1 - alpha/Lambda)^2 * 4*theta

The scope for conflict (moving U to PC to PL) increases with dissimilarities in size or valuation of revenue. Example with alpha = 0 and countries differing only in size: unanimity if theta > 0.5, potential loss for low-tax country if theta < 0.25. Countries differing only in revenue valuation: similar partition in terms of (lambda-1)/lambda relative to (Lambda-1)/Lambda.



## Page 7 (Section 3.2: Calibration and Proposition 3)

Section 3.2 Calibration.

Proposition 3 (the central result): Comparing eqs. (19) and (20) with (13):

mu* = (3/2 - alpha/Lambda) * t^N (eq. 24)

mu** = 2*(1 - alpha/Lambda) * t^N (eq. 25)

This is described as "a strikingly sharp answer." Both critical rates are simple multiples of the low-tax Nash rate t^N. The proportionate gaps depend only on, and are strictly decreasing in, alpha/Lambda (the ratio of the marginal social valuation of the private gain from profit shifting to that of tax revenue). This ratio determines the slope of T'(t) (see eq. 10). A reduction in alpha/Lambda steepens the best response, pushing D and C (mu* and mu**) further to the right.

Bounds:
- As alpha/Lambda approaches its limiting value of 0.5 (both private gain and tax revenue valued like private income by the high-tax country), the best response becomes perfectly flat and "the possibility of any Pareto gain from imposing a minimum tax disappears."
- At the opposite extreme (Lambda -> infinity or alpha = 0, with T'(t) reaching its maximum of 1/2): mu* = 1.5 * t^N; mu** = 2 * t^N.

Example with t^N = 12.5% (Ireland's statutory rate):
- mu* can be no more than 18.75%.
- mu** can be no more than 25%.

Both are "very much higher, by the standards of the policy debate, than that low Nash rate."

Figure 3 (see figure in paper):
- Shows mu* and mu** (left scale) and the slope T'(t) (right scale) across the full range of alpha/Lambda, conditional on t^N = 12.5%.
- Also shows which of the three cases (U, PC, PL) applies.

Intermediate values example: Lambda = 1.5, alpha = 0.5, so alpha/Lambda = 1/3. Then mu* = 14.6% and mu** = 16.7%. The paper calls this striking: "a country initially setting a rate of 12.5% might ultimately benefit from being obliged to raise its rate to nearly 17%."

Alternative calibration using T'(t) directly (since this is what shapes the welfare impact on the low-tax country, regardless of what drives it, and for which empirical evidence exists): with T'(t) = 0.4 (around the mid-point of estimates in the literature), the low-tax country's preferred minimum rate is 16.7%, and it benefits from any minimum up to 20.8%.

Table 1 (see table in paper, p. 9 in the article, continued across pages 7-8):
- Reports, conditional on t^N = 12.5%, the implied values of T^N (high Nash rate), T'(t) (slope of best response), mu* (Pareto efficient minimum), mu** (maximal Pareto dominant minimum), mu-bar (level at which the minimum binds the high-tax country), and which case (U, PC, PL) applies.
- Parameterised across three panels: Panel A (alpha = 0.5), Panel B (alpha = 0.3), Panel C (alpha = 0.1), and two combinations of (lambda, Lambda): (1.2, 1.7) and (1.5, 1.5).
- Size parameter theta varies: 1, 0.75, 0.5, 0.25, 0.1.

Key findings from Table 1:
- Whenever the high-tax rate is 20% or more (a plausible counterpart when calibrating the low rate at 12.5%), Case PL arises, meaning the low-tax country may lose relative to Nash from some ambitious minima that still leave the high-tax country unconstrained.
- Case PL is more likely the greater the dissimilarity in country size (consistent with condition 23).
- Across all parameterisations, it is "only at levels in the order of 17%-24% that the adoption of a minimum rate leaves the low tax country worse off than in the initial Nash equilibrium."

One notable analytical point: in some cases in Table 1, mu** < T^N, confirming that the Kanbur & Keen (1993) result (for revenue-maximising governments) that the maximally dominant rate exceeds the higher Nash rate "does not survive the generalization to attach some social weight to private income."



## Page 8 (Section 4: Further issues)

Section 4.1: Sustainability of the agreement.

If the low-tax country can defect from the minimum (setting a rate below mu, while the high-tax country continues to set T(mu)), the gain from defecting is:

D(mu) = w^D(mu) - w(mu)

where w^D(mu) is the low-tax country's maximised welfare from defecting (setting its best response to T(mu)). In a repeated game context with Nash reversion (reverting to the Nash equilibrium in perpetuity after defection), the minimum rate affects the incentive to defect only through its impact on the one-period gain. Appendix B shows that D(mu) is strictly increasing in mu (the gain from defecting strictly increases with the minimum rate). Therefore at a sufficiently high minimum, the low-tax country will want to defect (depending also on the discount rate). However, this potential instability is moderated because the high-tax country retains the ability (and indeed has an obligation under the current framework) to top-up liability to the minimum. In that case, the low-tax country has an incentive to raise its rate to the minimum itself. "In this wider sense, the minimum tax agreement has elements of self-enforcement."

Section 4.2: Collective welfare.

Joint welfare w + W is strictly increasing in mu to at least some level above mu*. A sufficient (but not necessary) condition for joint welfare to be everywhere increasing in mu is Lambda > lambda: the loss to the low-tax country from reduced profit shifting at higher mu is then always less than the corresponding gain to the high-tax country. In other cases, an interior maximum is possible, but this is not analysed in detail.

Section 4.3: Three-country extension (see Appendix C for full derivation).

Structure: one low-tax country, one high-tax, and one intermediate-tax country. The two higher-tax countries are structurally the same as the high-tax country in the base model but may differ in alpha_i, Lambda_i, and/or Pi_i. Shifting costs depend only on the total amount shifted, so both high- and intermediate-tax countries shift profits only to the lowest-taxed jurisdiction.

Key result: from the perspective of the low-tax country, the situation is "as if it faced a single larger country that is simply an average of the two bigger countries, weighted by their relative size." This yields a natural generalisation of Proposition 3: mu* and mu** are again multiples of t^N, with factors of proportionality depending only on (and increasing in) the weighted average slope of the best responses of the two large countries (defined as B = b_1*Theta_1 + b_2*Theta_2).

From Appendix C (eqs. C.11 and C.12):

mu* = t^N * (2 - B) / (2*(1 - B))

mu** = t^N * (1 / (1 - B))

A mean-preserving spread in the slopes of the best responses of the higher-tax countries increases rate dispersion among them but leaves mu* and mu** (as proportions of t^N) unchanged. The centrality of "the slope of the best responses of unconstrained countries in shaping the range over which, through the induced strategic response, a minimum tax rate is Pareto-improving" continues to apply.



## Page 9 (Table 1, continued; Section 5: Conclusions)

Table 1 appears here (see description under page 7 above).

Section 5: Conclusions.

Key messages:

- The purpose of a minimum corporate tax rate is to change the rules of international tax competition, particularly regarding profit shifting. Strategic responses by unconstrained countries are central to assessing effects and welfare.

- Strategic complementarity in statutory corporate tax rates (strongly supported empirically) and the fact that each country benefits from a tax increase by the other together point to the most plausible outcome being a welfare gain for the low-tax country from an infinitesimally binding minimum. The presumption that the high-tax country gains is strong. Thus "an infinitesimally binding minimum rate is Pareto-improving."

- The critical issue is not merely the sign but also the magnitude of the slope of the high-tax country's best response. In the model this turns on the social valuation of the private gain from profit shifting relative to tax revenue. Importantly, from the low-tax country's perspective, "it is immaterial what drives that slope: all that matters is the magnitude that results."

- Simulations suggest that "for what we believe to be reasonable parameter values, both Pareto efficient and maximal dominant rates may lie materially above the initial low tax rate." Starting from t^N = 12.5%, both high and low tax countries may well gain from a minimum as high as 17%-20%.

- The paper acknowledges that these numbers must be treated with "much caution." But the orders of magnitude are strongly salient in a policy debate where disagreement has been "heated even between candidate rates of 12.5 and 15%."

- Extension to more than two countries: essentially the same analysis applies in terms of the weighted average of best responses of high-tax countries.

- Remaining open questions include how the minimum affects tax-setting for smaller multinationals not directly in scope. Nonetheless: "the scope for a congruence of interest in setting an ambitious minimum rate may be larger than is commonly recognized."



## Pages 10-11 (Appendices and References)

Appendix A: Proof that mu** = 2*mu* - t^N.

Write w(mu) = A*mu^2 + B*mu + C. Necessary condition defining mu*: 2*A*mu* + B = 0. Define x = mu* - t^N > 0. Then w(mu**) = w(t^N) implies the second root is mu** = mu* + x = 2*mu* - t^N.

Appendix B: Proof that the gain from defecting is strictly increasing in mu.

D(mu) = w^D(mu) - w(mu). w^D(mu) is strictly convex in mu (from differentiating eq. B.3 twice and using T''(mu) = 0). w(mu) is strictly concave. Therefore D(mu) is strictly convex. Since D(mu) > 0 for all mu > t^N and D(t^N) = 0, it follows that D'(mu) > 0 for mu arbitrarily close to t^N, and hence D'(mu) > 0 for all mu > t^N.

Appendix C: Extension to three countries (summarised under Section 4 above).

Key equations for the three-country extension:

- Welfare of the low-tax country (eq. C.1-C.2) now includes inward profit shifting from both higher-tax countries.
- Best response of the low-tax country (eq. C.4) replaces T by tau (weighted average of T_1 and T_2).
- Best responses of the higher-tax countries (eq. C.5): T_i(t) = A_i + B_i*t.
- Weighted average best response: tau(t) = A + B*t, where B is the weighted average slope.
- Nash rate of the low-tax country (eq. C.8): t^N = (((lambda-1)/lambda)*delta*theta + A) / (2 - B).
- mu* (eq. C.11): mu* = t^N * (2-B) / (2*(1-B)).
- mu** (eq. C.12): mu** = t^N * (1/(1-B)).
