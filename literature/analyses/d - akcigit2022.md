# Akcigit, Hanley & Stantcheva (2022) — "Optimal Taxation and R&D Policies"
**Econometrica, 90(2), 645-684**


## p. 645 - Abstract & Introduction (start)

Core research question: what is the optimal design of corporate taxation and R&D policies?

Framing: treated as a dynamic mechanism design problem with spillovers

Key setup features:
- firms have heterogeneous research productivity
- that research productivity is private information (asymmetric information)
- there are non-internalized technological spillovers across firms
- the asymmetric information prevents the government from correcting spillovers in the first-best way

Three key parameters identified for optimal policies:
- (i) relative complementarities between observable R&D investments, unobservable R&D inputs, and firm research productivity
- (ii) dispersion and persistence of firms' research productivities
- (iii) magnitude of technological spillovers across firms

Empirical finding: high research productivity firms get disproportionately higher returns to R&D investments than lower productivity firms

Main practical finding: "very simple innovation policies, such as linear corporate taxes combined with a nonlinear R&D subsidy — which provides lower marginal subsidies at higher R&D levels — can do almost as well as the unrestricted optimal policies"

Broader claim: formulas and methods are "more broadly applicable to the provision of firm incentives in dynamic settings with asymmetric information and spillovers, and to firm taxation more generally"

Government intervention context: governments intervene in R&D via tax credits and deductions, direct grants and funding for research, and subsidies for R&D costs. Scale of spending raises the question of how best to design these policies.

One major challenge: asymmetric information — quality of a firm's organisation, management, processes, or ideas are private information, very difficult for outside parties including government to observe.

Comparison with VC firms: VCs use intensive hands-on screening and staged financing but this approach is not easily scalable → not applicable to large-scale government policies.

The innovation literature has extensively addressed spillovers from innovation, but has "not focused as much on asymmetric information about firms and how to distinguish between firms that are good at innovation and those that are not."

## p. 646 - Introduction continued

Paper uses: methods from public economics, mechanism design theory advances, firm-level data matched to patent data.

Three main questions addressed both theoretically and quantitatively:
- Without restricting the set of policy tools a priori, what are the best policies for promoting innovation?
- What key parameters do optimal policies depend on?
- Are there simple policies that are almost as good as the unrestricted optimal ones?

Two market failures in the setting:
- Technology spillovers between firms (one firm's innovations affect other firms' productivities)
- Innovation is not appropriable; absent IPR policy any firm could use an idea embodied in an innovation. IPR policy (e.g. patent system) may itself create a distortion (monopoly rights)

Main impediment: asymmetric information. Firms are heterogeneous in research productivity and this is unobservable to the government.

Observable vs. unobservable R&D inputs: some inputs are observable ("R&D investment"), others are not ("R&D effort").

Research productivity: evolves stochastically over time. The firm has some, but not perfect, information about future productivity.

Without private information: government could perfectly correct via Pigouvian subsidy (technology externality) and a prize system (appropriability). Asymmetric information forces incentive constraints → limits how close the economy can get to full efficiency.

"We show that the need to screen firms may starkly modify the recommendations that arise with observable firm types."

Methodological contribution: building a tractable dynamic R&D model with spillovers. Mechanism design approach: do not ex ante restrict policies; direct revelation mechanism where government can choose allocations for each firm type, subject only to incentive compatibility constraints.

Builds on mechanism design methods and extends them with "a new approach to allow for spillovers between agents (firms) in the presence of asymmetric information."



## p. 647 - Introduction: Main findings and related literature (start)

Constrained efficient allocation: optimal incentives for R&D trade off Pigouvian correction for technology spillover and monopoly distortion correction against the need to screen good firms from bad ones.

Critical parameter: "the complementarity of R&D investment to R&D effort (i.e., the complementarity between observable and unobservable innovation inputs) relative to the complementarity of R&D investment to firm research productivity."

- If R&D investment is more complementary to unobservable firm research productivity → firms extract more rents if R&D is subsidised → puts a brake on corrective policies → optimal screening requires dampening first-best corrective policies
- If R&D investments are more complementary to unobservable R&D effort → they stimulate the firm to employ more of the unobservable input → optimal R&D subsidies are larger

Persistence of research productivity shocks and strength of spillovers are other key determinants.

Constrained efficient allocations can be implemented "with a parsimonious corporate income tax function."

Estimation: model estimated using firm-level data matched to U.S. Patent Office Patent data. Measure: inputs into R&D, production decisions, innovation output (patents and citations).

Empirical finding on complementarity: R&D investments are "highly complementary to a firm's research productivity" — higher productivity firms generate disproportionately more innovation from a given R&D investment. Since higher productivity firms have comparative advantage at innovation, it is better to incentivize R&D investments less for lower productivity firms. Otherwise it becomes excessively attractive for high productivity firms to mimic low productivity ones.

Wedges: higher net incentive for R&D for higher research productivity firms is provided with:
- lower profit wedge at higher profit levels
- lower R&D wedge at higher R&D levels
(because higher productivity firms generate more profits from the same research investments, and this allocation shape is more attractive to high types than low types)

Near-optimal simple policy: "a nonlinear, separable Heathcote-Storesletten-Violante (HSV) type subsidy combined with an HSV-type profit tax" — features decreasing marginal profit taxes (increasing marginal profit subsidies) at higher profit levels, and decreasing marginal R&D subsidies at higher R&D investment levels.

Note on footnote 2: wedges "measure the distortion in allocations relative to the laissez-faire economy's allocations and are thus akin to implicit taxes and subsidies."



## p. 648 - Introduction: Related literature and paper structure

Key quantitative finding: "the most important feature is the nonlinearity in the R&D subsidy: making the profit tax linear (and lower) only generates a small welfare loss." Intuition: a constant profit tax that is more generous than it should be for low profit firms, and about right for high profit firms, does reasonably well since the loss from being too generous to low profit firms is small (their low profit levels do not yield much revenue). "Thus, linear corporate income taxes — common in practice — can be very close to optimal for innovating firms if combined with the right nonlinear R&D subsidy."

Related literature overview:

Static contract theory on firm regulation under private information: Laffont and Tirole (1986), Baron and Myerson (1982). Very few papers consider regulation of research and innovation; Sappington (1982) does so in a simple static model.

Personal income taxes with externalities (rents): Rothschild and Scheuer (2016), Piketty, Saez, and Stantcheva (2014), Lockwood, Nathanson, and Glen Weyl (2017) — static models, individuals not firms, relatively blunt tools.

Dynamic public finance using mechanism design for income taxation: Albanesi and Sleet (2006), Farhi and Werning (2013), Golosov, Tsyvinski, and Werning (2006), Golosov, Tsyvinski, and Werquin (2014), Sachs, Tsyvinski, and Werquin (2020), Werquin (2016). Closest: Stantcheva (2015) and Stantcheva (2017) on human capital investment in dynamic tax problem.

Builds on mechanism design methodology of Pavan, Segal, and Toikka (2014), augmented with dynamic spillovers and realistic infinite-horizon dynamic life-cycle model of innovating firms.

To solve the model with spillovers: extends the two-step approach ("inner" and "outer" problem) from Rothschild and Scheuer (2013) to a dynamic, infinite-horizon firm setting.

Theoretical contributions: addition of spillovers between agents. Framework captures: market power, investments, production, heterogeneity in productivity, intellectual property, asymmetric information, and infinite horizon.

Computational contribution: "fully estimating this dynamic model with spillovers in the data, giving precise empirical content to the variables in our model thanks to the match between patent data and firm-level data."

Comparison with Grossman, Steger, and Trimborn (2013): they studied optimal time path of R&D subsidies in semi-endogenous growth model with Ramsey approach (linear policies); their model contains "neither heterogeneous firm productivities nor private information about these productivities."

Empirical literature used to discipline model: Goolsbee (1998), Bloom, Griffith, and Van Reenen (2002), Bloom and Griffith (2001), Bloom et al. (2002), Bloom and Van Reenen (2007), Bloom, Sadun, and Van Reenen (2012), Bloom et al. (2013) — support for firm heterogeneity in efficiency (hard for government to observe). Gap between private and social returns to R&D: Jones and Williams (1998, 2000). Spillover magnitude: Bloom, Schankerman, and Van Reenen (2013).



## p. 649 - Section 2: A Dynamic Model of R&D Investments

Model objectives:
- tractable enough for theoretical optimal mechanism design analysis under asymmetric information
- can also be used to study other types of firm investments with asymmetric information and spillovers
- can also study firm taxation with heterogeneous firms more generally, even for non-innovating firms (by turning off certain aspects like spillovers)

Paper structure:
- Section 2: dynamic model and its assumptions, empirical justification
- Section 3: sets up and solves the full dynamic model
- Section 4: forces shaping optimal policies
- Section 5: estimation using firm data matched to patent data, simulation of optimal policies
- Section 6: welfare loss from simpler, restricted policies
- Section 7: future research directions
- Supplemental Material: all proofs and computational procedure; also a simpler two-type, one-period version of the model and sensitivity and robustness checks

Section 2.1 - Setting:

Core: firms produce and sell differentiated intermediate goods; engage in R&D to improve product quality through innovation.

Quality evolution: qt = H(qt-1, λt) where λt is endogenous quality improvement ("step size")

Step size: λt = λt(rt-1, lt, θt) — depends on three components:

(i) Observable R&D inputs (rt-1): resources spent on R&D in period t-1; includes pay of scientists and researchers, lab equipment, material supplies, raw materials for research and innovation. Monetary cost is Mt(rt), with M't(rt) > 0 and M''t(rt) ≥ 0. Called "R&D investments."

- footnote 3: "Taking a broad view of these material inputs is consistent with the fact that many types of material inputs and expenses are eligible for R&D tax credits or subsidies (Tyson and Linden (2012))."

(ii) Unobservable R&D inputs (lt): cannot be directly monitored by the government; one such input is "unobservable research effort" required to transform material resources into innovation output. Called "R&D effort" — could also include other costly, unobservable actions at the organisational level. Cost φt(lt) for the firm, which is increasing and convex.

(iii) Firm type (θt): determines the efficiency with which it converts observable and unobservable inputs into innovation — "research productivity." θ may represent efficiency of management; or composite measure of quality of organisation, business model, or "ideas." Key: firms differ in their ability to produce innovation and "that this ability is hard to observe by a government or regulator."

Important clarification: "for policy design purposes, it is equivalent whether a characteristic (such as research productivity) is truly unobservable or whether it is simply impossible to condition policies on it" — in either case, incentive compatibility constraints are needed.

Type process: θt evolves over time according to a Markov process ft(θt|θt-1) on Θ = [θ, θ̄]. History of type realisations until time t: θt = {θ1,...,θt}. Probability of that history: P(θt) := ft(θt|θt-1)...f1(θ1).

Assumptions on the step size function:
- ∂λ/∂θ > 0 (higher research productivity → larger step size)
- ∂λ/∂r > 0 (higher R&D investment → larger step size)
- ∂λ/∂l > 0 (higher effort → larger step size)
- ∂²λ/∂θ∂l > 0 (marginal returns to effort are higher for higher types → enables screening)



## p. 650 - Section 2.1 continued: Product quality vs. research productivity; Input complementarity

Distinction: "Firms' product quality refers to the product quality qt of the intermediate good produced by the firm. Firm research productivity refers to the efficiency type of the firm, θt, which affects the innovation process that produces the product quality qt."

Returns to R&D: stochastic and heterogeneous across firm types, because step size depends on lagged R&D investments and stochastic realisation of θt about which firm has only partial advance information. This captures that R&D has uncertain returns.

Timing note (footnote 5): "If the timing was contemporaneous, the sums and expectations for the R&D wedge in Proposition 1 should simply be lagged one period." — qualitatively and quantitatively does not change results.

Conceptual timing: R&D investments (observable) = like physical capital investments, take a while to yield returns, determined before uncertainty is realised. R&D effort = inputs that can be more easily adjusted in response to current state (utilisation rate of equipment, managerial input, process improvements, labour effort of researchers, etc.).

Input Complementarity: characterised using the Hicksian coefficient of complementarity (Hicks (1970)), defined for any two variables (x, y) ∈ {θt, rt-1, lt} × {θt, rt-1, lt}:

ρxy = [∂²λ/∂x∂y · λ] / [∂λ/∂x · ∂λ/∂y]

Higher ρxy = more complementary in production of step size.

Examples:
- Multiplicatively separable: λt(rt-1, lt, θt) = h¹t(rt-1)h²t(lt)h³t(θt) → ρθl = ρθr = ρlr = 1
- Additively separable: λt = h¹t(rt-1) + h²t(lt) + h³t(θt) → ρθl = ρθr = ρlr = 0
- CES: λt = (αr · rt-1^(1-ρt) + αθ · θt^(1-ρt) + αl · lt^(1-ρt))^(1/(1-ρt)) → ρθl = ρθr = ρlr = ρt



## p. 651 - Section 2.1: Quality Spillovers, Final Goods Production, Patent Protection, Firm Life Cycle

Quality Spillovers: one firm's innovation has a beneficial effect on the production costs of other firms. Specific shape of knowledge spillovers taken from Akcigit and Kerr (2018) — captures "building on the shoulders of giants" idea (Aghion and Howitt (1992), Romer (1990)).

Important: "the exact shape of the spillovers is not key for our theoretical results and the spillovers could appear in different parts of the model."

Aggregate quality: q̄t = ∫Θt qt(θt)P(θt)dθt

Production cost of each firm is decreasing in aggregate quality; cost of producing k units is Ct(k, q̄t).

Final goods production: Yt = ∫Θt Y(qt(θt), kt(θt))P(θt)d(θt), where Y(qt(θt), kt(θt)) is the contribution of intermediate good of firm θt to the final good. Final good price normalised to 1.

Patent Protection and Monopoly Power: different IPR regimes captured through different demand functions p(qt(θt), kt(θt)). Benchmark: full patent protection → intermediate goods producer has monopoly power, faces downward sloping demand curve; p(q, k) = ∂Y(q,k)/∂k.

Firm Life Cycle: firms live for infinite number of periods. Small open economy assumption, gross interest rate R. In laissez-faire economy, firm chooses quality, quantity, R&D investments, and R&D effort to maximise [equation (1) in the paper: expected discounted profits over infinite horizon].



## p. 652 - Section 2.2: Social Welfare; Section 2.3: Two Market Failures and First-Best Allocation

footnote 4: "once produced, innovations are non-rival and non-appropriable absent IPR. The inputs into that innovation are, as usual, rival."

footnote 6: all formulas expressed at a general level as functions of net output and profits, depending on own quality and aggregate quality. "The channel could be through the cost (as here), directly through the demand function... or through the innovation production function."

Social Welfare (equation 3): weighted sum of consumer surplus plus firm surplus. The key benchmark case (following contract theory literature): χ = 1, so social objective = maximising total social surplus (consumer plus firm surplus) minus all informational rents = "virtual surplus."

Note: even absent redistributive concerns, maximising efficiency = maximising weighted sum of consumer and firm surpluses, "if we assume, as is standard in the contract theory literature, that the planner can only raise the money for transfers through some distortionary method (e.g., excise taxes or distortionary income taxes on households), so that the cost of one unit of transfer is weakly greater than 1."

Two market failures (in absence of government intervention):
- (1) Lack of appropriability of innovation → no investment in innovation absent IPR protection
- (2) Non-internalized technology spillovers affecting others' production technologies

First-Best Allocation: if planner can observe firm types and transfers are perfectly non-distortionary (χ = 0), social welfare = total expected discounted output net of production costs, R&D investment costs, and R&D effort costs (W^first-best formula).

In first best: firms choose R&D investment and effort so total marginal social benefit equals marginal costs (two equations involving discounted sums of effects on net output, own quality, and aggregate quality — accounting for both private and spillover benefits).



## p. 653 - Section 2.4: Asymmetric Information and Government Policies

Figure 1 (model summary): Household at top (max consumption), connected to Government (R&D & tax policies) and Final Goods Producer; Intermediate Goods Producers receive demand p(k(i), q(i)) from final goods market, subject to: Quality qt(i), quantity kt(i), demand p(kt(i), qt(i)), spillovers via aggregate quality q̄t = ∫qt(i)di, profits π(qt(i), q̄t) = max{p(k, qt(i))k - C(k, q̄t)}.

Production decision: profits gross of R&D costs = π(qt(θt), q̄t) := max_k{p(qt(θt), k)k - C(k, q̄t)}

Asymmetric Information Structure: history of research productivity realisations θt and unobservable R&D effort lt are private information for each firm. Government observes full histories of R&D investment rt, quality improvements (step size λt), and realised quality qt (concretely: patents granted and their citations). Quantity k(θt) is also unobservable/cannot be conditioned on by government → government cannot intervene directly in market between intermediate and final goods producers.

Note: case where government can observe quantity is considered in Section S.2 of replication file.

Government Policies Considered:
- Optimal unrestricted direct revelation mechanism (subject only to incentive compatibility constraints from asymmetric info on firm type, R&D effort, and quantity)
- Then: shape of and revenue losses from restricted, parametric instruments (simpler policies, Section 6)



## p. 654-655 - Section 2.4 continued: Importance of Asymmetric Information

Empirical evidence for asymmetric information in innovation (from literature):

- Hall and Lerner (2010): asymmetric information = the innovator has "better information about the likelihood of success" than anyone else including investors and government. Informational frictions from innovator-investor interaction "likely to carry over in an even more pronounced way to the interaction between inventors and the government." Also cautioned against mandating fuller disclosure — innovations can be easily imitated, revealing productivity to government risks revealing it to competitors.

- VC industry: VCs tend to operate in sectors with high asymmetric information (Gompers, 1995). Kaplan and Stromberg (2001): intensive screening by VCs. Illustration of severity: "even highly-skilled VCs cannot distinguish in advance the next Google from the other cases" (Kerr, Nanda, and Rhodes-Kropf, 2014). "Given that VCs face asymmetric information problems despite the huge time investment and detailed involvement in the firms that they fund, it is hard to imagine that the government would not be facing much larger informational problems when designing a decentralised tax system that does not micro-manage or directly intervene in firms."

- Stock prices: Zantout (1997), Alam and Walton (1995), Gharbi, Sahut, and Teulon (2014); Aboody and Lev (2000): insider gains are larger at R&D intensive firms because that is where asymmetric information is higher.

- R&D inputs not easily verifiable ("relabeling" problem): Hall and Van Reenen (2000). Mansfield (1986): substantial misreporting found in R&D tax credit survey across US, Canada, and Sweden. Chen et al. (2021): around 30% of reported R&D investment by Chinese firms could be due to relabeling.

Own data evidence: regressions of citations-weighted patents on a comprehensive set of controls (sector and year fixed effects, lagged sales, employment, R&D spending, age, balance sheet variables, etc.) — R-squared "barely moves above 0.3." Especially difficult to predict performance based on first few years of a company's life cycle. Difficult to predict which firms will become "superstars" (highly-cited and influential patents).

Important caveat (footnote 10): "These results are by no means a formal 'test' of asymmetric information. It may be that the prediction could be improved with different, better data or methods and it is always very difficult to disentangle heterogeneity (generating asymmetric information) from uncertainty (which is consistent with symmetric information)."



## p. 656-657 - Section 2.5: Discussion of Assumptions and Possible Generalizations

Additional Firm Heterogeneity: if government wants to condition on observable characteristics vector X, mechanism conditions on X (no additional incentive constraints needed, just increases state space). Heterogeneity in production productivities discussed in Section OA.3 of Supplemental Material.

Entry and Exit: in principle only intensive margin decisions in model. Exit captured through discount rate R (interest rate plus exogenous exit/death rate). Free entry could affect cohort size; entry barriers could be studied as policy tool.

The Role of IPR: focus is on R&D policy design, not IPR. Optimal R&D policies depend on the IPR policies. Benchmark: grant patent protection and monopoly rights (mirrors current world). Part of R&D policy role = partially correct monopoly distortion induced by patent system. Two cases studied: whether government can or cannot intervene in private market between intermediate and final goods producers (i.e., whether it can condition on quantity k). Benchmark: government cannot control quantity.

- Footnote 12: could instead consider patent for protection for x years, or patent protection for a fraction of monopoly profits.
- Footnote 13: if no IPR monopoly power (e.g. prize system), optimal IPR = paying innovating intermediate goods producer a prize to buy the innovation, then produce socially optimal quantity. Equivalent: full patent protection + nonlinear price subsidy to monopolist that aligns private and social valuation.

Shape of Spillovers: exact shape not important for theoretical results. Following Akcigit and Kerr (2018): spillovers affect costs of production — "building on the shoulders of giants." Examples: computers used in other companies, communication technologies, production technologies, health improvements. Framework general enough that spillovers could appear elsewhere (e.g. in innovation production function: qt = H(qt-1, λt, q̄t)). All formulas expressed in terms of general profit functions or net output functions depending on own quality and aggregate quality.

Different Types of Investments With Different Externalities: possible to consider different types of firm investments each generating different externalities (e.g. new drug discovery may have larger positive spillovers than improving machinery used by few firms).



## p. 658-661 - Section 3: A Dynamic Direct Revelation Mechanism with Spillovers

Setup: government observes step size λt, realised quality qt, and R&D investment rt. Private information: history θt and research effort lt.

Government designs direct revelation mechanism: every period, each firm reports a type θ't(θt) as function of true history θt. Reporting strategy σ = {θ't(θt)}∞t=1. Government assigns allocations x(θ't) = {λ(θ't), r(θ't)}t and transfers Tt(θ't). Starting R&D investment normalised: r(θ⁰) = r0.

Incentive compatibility: V(θt) ≥ V^σ(θt) for all σ, θt (truth-telling must be weakly dominant).

Assumption 1: (lt, rt) belongs to a convex and compact set.

Section 3.1 - First-Order Approach:

Replaces all incentive constraints with envelope conditions (as in Pavan, Segal, and Toikka (2014), Farhi and Werning (2013), and Stantcheva (2017)).

Focus on Markov process. Impulse response function I1,t(θt): captures persistence of stochastic type process. For AR(1) process where θt = p̃θt-1 + εt: I1,t(θt) = p̃^(t-1).

Assumption 2: full support — fs(θs|θs-1) > 0 for all θs, θs-1 ∈ Θ.

Assumption 3: ∂Fs(θs|θs-1)/∂θs-1 exists, is bounded, and ≤ 0 (higher type in s increases period s+1 type in first-order stochastic dominance sense). All discussed examples (AR(1), log AR(1), i.i.d., fully persistent process) satisfy this.

Envelope condition (equation 5): ∂V(θt)/∂θt = E[∑(s=t to ∞) I(t,s)(θs) · (1/R)^(s-t) · ∂vs(θs)/∂θs | θt]

Participation constraints (equation 6): V1(θ1) ≥ 0 for all θ1.

Integral form (equation 7): V(θt-1, θt) = ∫[θ to θt] ∂V(θt-1, m)/∂m dm + V(θt-1, θ̲). This gives the informational rent the principal must give to the agent at node θt to entice truthful reporting.

Section 3.2 - Planner's Problem:

Maximise social welfare (3) subject to incentive constraints (5) and participation constraints (6). Set χ = 1.

Footnote 16: χ = 1 is the typical contract theory case, aiming to maximise total social surplus and minimise rents. Any χ < 1 appears as a scaling factor in front of the screening term in all formulas.

Problem split into two steps:

Partial problem: for given sequence q̄ = {q̄1,...,q̄T}, planner solves for optimal allocations subject to resource and incentive constraints as functions of conjectured q̄. Consistency constraint in each period t: ∫Θt qt(θt)P(θt)dθt = q̄t. Multiplier on consistency constraint in period t: ηt/R^(t-1).

Virtual surplus expression: W(q̄) = E[∑(1/R)^(t-1) {Ỹ(qt(θt), q̄t) - Mt(r(θt)) - φt(lt(θt)) - [(1-F1(θ1))/f1(θ1)] · I1,t · φ't(lt(θt)) · [∂λt(.)/∂θt / ∂λt(.)/∂lt]}]

Full problem: max over q̄ of P(q̄).

Verifying Global Incentive Constraints: since first-order approach is only necessary (not sufficient), need numerical ex post verification that allocations are globally incentive compatible. "For the range of parameters we study in Section 5, the allocations found using the second-order approach do indeed satisfy the global incentive constraints." Uniqueness can also be shown for the functional forms and parameter values used in Section 5.



## p. 662-663 - Section 3.3: Characterising the Constrained Efficient Allocation Using Wedges

Definition 1 - Wedges:

"The wedges measure the distortions at the optimum relative to the laissez-faire economy with a patent system, that is, the hypothetical incentives expressed as implicit taxes or subsidies that would have to be provided to firms starting from the laissez-faire case in order to reach the allocation under consideration."

Corporate (profit) wedge τ(θt): measures distortion on firm's R&D effort margin at history θt. Equal to gap between expected stream of marginal benefits from effort and its marginal cost (conditional on θt). "A positive wedge means that the firm's effort is distorted downwards." This wedge will also be called the corporate tax or profit wedge, since it mimics a tax on firms' profits gross of R&D investments.

Formal: τ(θt) := E[∑(s=t to ∞) ((1-δ)/R)^(s-t) · ∂πs(qs(θs), q̄s)/∂qs(θs) · ∂λt(θt)/∂lt(θt)] - φ'(lt(θt))

R&D investment (R&D) wedge s(θt): defined as gap between marginal cost of R&D and expected stream of benefits. "Akin to an implicit subsidy: a positive R&D wedge will mean that, conditional on the effort, the firm is encouraged to invest more in R&D than under laissez-faire with patent protection."

Formal: s(θt) := M't(rt(θt)) - (1/R)E[∑(s=t+1 to ∞) ((1-δ)/R)^(s-t-1) · ∂πs(qs(θs), q̄s)/∂qs(θs) · ∂λt+1(θt+1)/∂rt(θt)]

Simplified notation:
- Πt(θt): marginal impact on future expected profit flows from increase in quality qt
- Qt(θt): marginal impact on future expected output net of production costs from increase in quality qt
- Q*t(θt): same but when quantity is set by planner to socially optimal level (footnote 18: because quantity maximises consumption net of production costs, derivative is just direct impact of quality, indirect effect through quantity change is zero)



## p. 663-667 - Section 4: Optimal Policies

Section 4.1 - Optimal Corporate and R&D Wedges:

εxy,t = elasticity of variable x to variable y at time t

Proposition 1 — Optimal corporate wedge and R&D wedge:

(i) Optimal profit wedge:
τ(θt) = [Pigouvian correction] + [Monopoly quality valuation correction] + [Screening and incentive term]

Where:
- Pigouvian correction: -E[∑(s=t to ∞) ((1-δ)/R)^(s-t) · ηs] · ∂λt/∂lt
- Monopoly quality valuation correction: -E[(Qt(θt) - Πt(θt))] · ∂λt/∂lt
- Screening term: [(1-F1(θ1))/f1(θ1)] · I1,t(θt) · [φ't · λθt/λt] · [1/εl,1-τ · 1/εl,λ + ρθl,t]

(ii) Optimal R&D subsidy:
s(θt) = [Pigouvian correction] + [Monopoly quality valuation correction] + [Screening term involving (ρlr - ρθr)]

(iii) Multipliers ηt capturing spillovers: ∫Θt [∂Ỹ(qt(θt), q̄t)/∂q̄t] · P(θt) dθt = ηt

The three main effects balancing the optimal wedges:

(1) Monopoly quality valuation correction: intermediate goods monopolist values quality increases via profits; planner values effect on household consumption. This term "decreases the profit wedge and increases the R&D wedge." The gap between social and private valuation means the more the monopolist undervalues the social benefit, the more incentive is needed. Polar cases: no IPR → profits zero → large subsidy needed; full prize system → monopoly distortion zero → smaller subsidy. In between: if profits are share αππ of net social value, remaining gap = E((1-αππ)Qt+1(θt+1)).

(2) Pigouvian correction for technology spillover: as long as spillover is positive, Pigouvian term "unambiguously increases firms' R&D effort and investment relative to laissez-faire." Correction for R&D effort increasing in ∂λt/∂lt; correction for R&D spending increasing in expected effect ∂λt+1/∂rt.

(3) Screening and incentives: "Screening considerations may push in the opposite direction from the monopoly and Pigouvian corrections." Without asymmetric information, screening term = zero, and optimal wedges = only Pigouvian + monopoly corrections.

With asymmetric information, three sub-effects:

(a) Stochastic process for firm type: initial type distribution times persistence (impulse response I1,t) increases magnitude of profit wedge and R&D investment wedge. More persistent types → more private information → higher potential informational rents → allocations have to be distorted more. If shocks i.i.d.: I1,t = 0 for t > 1, and wedges reduce to only Pigouvian + monopoly correction terms for t > 1. With AR(1) persistence p̃: I1,t = p̃^(t-1). With fully persistent types: I1,t = 1 for all t → screening term does not decay.

Higher inverse hazard ratio [(1-F1(θ1))/f1(θ1)] → larger mass of firms with productivity > θ1 relative to mass at θ1 → cost of inducing marginal distortion at θ1 is small relative to benefit of saving on informational rent over mass (1-F1(θ1)) of more productive firms.

(b) Efficiency cost of distorting R&D effort: higher efficiency cost decreases optimal effort wedge (analogous to inverse elasticity rule in Ramsey taxation, footnote 20). Allocative inefficiency increases in elasticity of step size with respect to effort (εl,1-τ · εl,λ). Informational rent inefficiency increases in complementarity of effort to firm research productivity ρθl — high complementarity between effort and firm type means it is easy for higher productivity firms to mimic lower productivity ones → increases potential informational rent → optimal to distort more to reduce rents.

(c) Complementarity between R&D, firm effort, and firm type: "observable R&D investments are distorted only in so far as they can indirectly affect the unobservable R&D effort choice, that is, can affect the incentive constraint of the high research productivity firm."

Sign of screening term depends on (ρlr - ρθr):
- If ρlr > ρθr: R&D expenses more complementary to effort than to firm type → R&D expenses relax firms' incentive constraints, reduce informational rents → higher R&D subsidies
- If ρlr = ρθr: screening term of optimal R&D subsidy is zero → offsetting effects, incentive constraints unaffected by changes in R&D investments
- If ρθr > ρlr: R&D investments disproportionately benefit high productivity firms → negative screening term → better not to incentivise R&D as much for lower productivity firms

Another interpretation of ρθr: "riskiness of R&D, or as its exposure to the intrinsic risk of the firm." Sign of (ρlr - ρθr) measures "the strength of R&D contribution to firm effort, filtered out of the exposure to firm risk."

Note: Hicksian coefficients of complementarity are not necessarily constant — can vary with effort level, R&D, ability, firm age → optimal R&D wedge may change sign over distribution of types or over life cycle.



## p. 666-667 - Section 4.1.1 and 4.1.2: Cross-Sectional and Age Profile of Optimal Policies

Section 4.1.1 - Cross-sectional profile:

Important caveat: "a higher R&D wedge does not mean a higher investment in R&D, and a lower effort wedge does not mean more R&D effort. It merely means a higher incentive relative to laissez-faire." Firms have heterogeneous benefits and costs from investments and effort under laissez-faire.

Screening term: larger in absolute value for lower productivity firms — higher productivity firms want to pretend to be lower types, so lower types' allocations are distorted to prevent such deviations.

For profit wedge: screening term is positive → higher type firms face lower profit wedge.

For R&D wedge: screening term's sign depends on ρrl - ρθr. When ρθr > ρrl, screening term is negative → better not to incentivise R&D investments as much for lower productivity firms → "lower productivity firms have no comparative advantage at innovation, they should not be incentivised as much to invest in R&D, so that high productivity firms can be incentivised more."

Pigouvian correction: higher research productivity firms have higher positive spillover if ρlr > 0 and ρθl > 0 → marginal investment or higher effort has higher marginal impact on step size and hence aggregate quality → optimal Pigouvian correction increasing in firm type → warrants higher profit subsidy for higher productivity firms.

Since high productivity firms invest more in R&D and have larger profits, the statements about wedges hold when expressed in terms of observable variables (profits and R&D investments).

Section 4.1.2 - Age profile:

Two reasons for age-dependence of optimal policies:
- (1) Policies set at age 1 under full commitment → time elapsed since initial period induces age patterns. Screening term declines in absolute value with age as long as impulse response < 1 (as with AR(1) process with p̃ < 1). Decay is faster with lower persistence.
- (2) Technological fundamentals (step size λt, cost of effort φt, type distribution, R&D cost Mt) can vary with age.

Over life cycle: wedges converge to Pigouvian and monopoly correction terms. Whether from above or below depends on sign of screening term (depends on relative Hicksian complementarities). If ρθr > ρlr: negative screening term → optimal wedges converge from below. If ρθr < ρlr: converge from above.



## p. 667-669 - Section 4.2: Implementation Through Taxes and Subsidies

Key result: optimal allocations can be implemented with "a relatively parsimonious tax function." In general, optimal policies depend on histories of R&D inputs and outputs in nonlinear and non-separable way. However, a simpler implementation exists that does not depend on histories longer than two periods — important contrast with dynamic income tax models (Farhi and Werning (2013), Stantcheva (2017)) where cutting history-dependence is generally impossible except for i.i.d. shocks.

Why shorter history sufficient: "the past stock of quality can serve as a sufficient statistic for past investments, in the sense that it fully determines the future benefit from more innovation investments (together with rt and rt-1)."

Implementation: requires AR(1)-type or geometric random walk impulse response functions (independent of history except through θ1 and θt).

Tax function conditioning on: current quality qt, lagged quality qt-1, current R&D rt, lagged R&D rt-1, and first-period quality q1: Tt(qt, rt, qt-1, rt-1, q1). Equivalently as function of profits: T̃t(πt, rt, πt-1, rt-1, π1).

Note: "the constrained efficient allocations solved for in Section 3 are independent of the underlying market structure as long as the information set and toolbox of the planner are as specified there." However, shape and level of tax function implementing the allocation does depend on market structure and IPR policy. Also: "the same optimal allocations can often be implemented with multiple different policies and, hence, the implementation is not unique."

Link between wedges and tax function (general formulas for s(θt) and τ(θt) in terms of partial derivatives of tax function with respect to quality and R&D investment).

In general: "the degree of nonlinearity of the profit tax and R&D subsidy depends crucially on the shape of the step size function." Profit taxes far from linear if marginal effect of R&D effort very nonlinear. Nonseparabilities quantitatively important if step size features strong complementarities between R&D effort and investment.

Section OA.2 of Supplemental Material: simple functional form example generating constant marginal profit taxes and constant R&D subsidies depending only on degree of market power (β) and strength of spillover (ζ).



## p. 669-673 - Section 5: Quantitative Investigation

Section 5.1 - Data and Summary Statistics:

Benchmark data: Census Bureau's Longitudinal Business Database and Census of Manufacturers, matched to U.S. Patent and Trademark Office (USPTO) patent data from the NBER database (Hall, Jaffe, and Trajtenberg (2001)) — over three million patents with forward citations. Data match done and used by Acemoglu et al. (2018) and Akcigit and Kerr (2018).

Alternative dataset also used: COMPUSTAT matched to NBER patent database (results in Section S.3 of replication file).

Map between model and data:
- R&D spending M(r) = reported R&D expenses in accounting data
- Step size λt = forward citations received on innovations patented in year t
- Quality qt = depreciation-adjusted stock of citations per patent: qt = (1-δ)qt-1 + λt
- Profits and sales directly measured

Section 5.2 - Estimation:

Model parametrised as in Table I. Some parameters calibrated exogenously; remaining parameters estimated internally to match moments in data (Table III). Non-targeted moments checked for fit (Table IV).

Status Quo Economy: baseline setting has same primitives as optimal policy setting but features current US policies. Linear R&D subsidy rate estimated at 19% (total government spending on firm R&D through all programs divided by total private business spending on R&D). Average effective corporate tax rate set at 23%. "Reassuringly, the estimation procedure for our key parameters is not very sensitive to the choice of these effective rates."

Functional Forms (Table I):
- Consumer valuation: Y(qt, kt) = (1/(1-β)) · qt^β · kt^(1-β)
- Cost function: Ct(k, q̄t) = k/q̄t^ζ
- Quality accumulation: qt = (1-δ)qt-1 + λt
- Step size: λt(rt-1, lt, θt) = (αrt-1^(1-ρθr) + (1-α)θt^(1-ρθr))^(1/(1-ρθr)) · lt (CES in type and R&D investment, multiplicatively separable in effort)
- In this specification: ρθl = ρlr = 1 (so key question for sign of screening term is whether ρθr ≥ 1 or ρθr < 1)
- Disutility of effort: φt(lt) = κl · lt^(1+γ)/(1+γ)
- Cost of R&D: Mt(rt) = κr · rt^(1+η)/(1+η)
- Stochastic type process: log θt = p̃ log θt-1 + (1-p̃)μθ + εt (geometric random walk with persistence p̃)
- Initial type distribution: uniform on Θ1 = [θ̲1, θ̄1]
- Initial quality level: q0 = 0

Externally calibrated parameters (Table II, upper panel):
- Interest rate: R = 1.05
- Intangibles depreciation: δ = 0.1
- Knowledge share: β = 0.15 (Guner, Ventura, and Xu (2008))
- R&D cost elasticity: η = 1.5 (Akcigit and Kerr (2018))
- Level of types: μθ = 0.00
- Initial R&D stock: r0 = 1.0
- Program horizon: T = 30

Internally calibrated parameters (Table II, lower panel):
- R&D share: α = 0.483 (s.e. 0.025)
- R&D-type substitution: ρθr = 1.88 (s.e. 0.126) → this is > 1, meaning sign of screening term on R&D is negative → better not to incentivise R&D as much for lower productivity firms
- Type variance: σε = 0.320 (s.e. 0.014)
- Type persistence: p̃ = 0.63 (s.e. 0.022)
- Scale of disutility: κl = 0.69 (s.e. 0.050)
- Scale of R&D cost: κr = 0.055 (s.e. 0.003)
- Effort cost elasticity: γ = 0.86 (s.e. 0.052)
- Support width for θ1: Θ1 = 1.91 (s.e. 0.097)
- Production externality: ζ = 0.018 (s.e. 0.001)

Loss function minimised: L(X) = ∑(k=1 to 9) [(moment_k^model(χ) - moment_k^data) / moment_k^data]² (also GMM-type weighting in replication file)

Moments targeted (Table III):
- M1: Patent quality-R&D elasticity — target 0.88, simulation 0.97 → identifies ρθr
- M2: R&D/Sales mean — target 0.041, simulation 0.035 → identifies α
- M3: Sales growth (DHS) mean — target 0.06, simulation 0.07 → identifies κr
- M4: Within-firm patent quality coeff of var — target 0.63, simulation 0.76 → identifies p̃ (persistence)
- M5-M6: Across-firm patent quality coeff of var (young/old) — target 1.06 and 0.99, simulation 1.05 and 0.81 → identifies σε and Θ1
- M7: Patent quality young/old ratio — target 1.04, simulation 1.08
- M8: Spillover coefficient — target 0.191, simulation 0.192 — identifies ζ through indirect inference replicating Bloom, Schankerman, and Van Reenen (2013) IV regression
- M9: Elasticity of R&D investment to cost — target -0.35, simulation -0.35 → from Bloom, Griffith, and Van Reenen (2002)

Non-targeted moments (Table IV) — good fit:
- Sales growth bottom 90% vs. top 10%: data 0.03, model 0.04
- R&D/Sales for bottom 90%: data 0.038, model 0.034
- R&D/Sales for top 10%: data 0.052, model 0.042
- Ratio sales for old firms vs. young firms: data 1.73, model 2.32



## p. 673-677 - Section 5.3: Results and Cross-Sectional Patterns

Key parameter findings: ρθr = 1.88 → R&D investments highly complementary to firm research productivity. Type persistence: p̃ = 0.63 (moderate).

Gross vs. Net Incentives: illustrated with linear taxes. If profit tax applies to profits gross of R&D spending (R&D not deductible): gross subsidy rate s̃ is such that firm's payoff is π(1-τ) - (1-s̃)M(r). If R&D deductible: net incentive s defined so payoff is π - τ(π - M(r)) - (1-s)M(r). Net incentive s = s̃ - τ (there are two ways to incentivise R&D: tax its returns less, or subsidise its costs more).

Section 5.3.1 - Cross-Sectional Patterns:

Wedges on profits: negative (subsidising profits / lower marginal profit tax). Wedges on R&D investment: positive (subsidising R&D). Both push firms to provide more effort and more R&D investment than under laissez-faire. This reflects: monopoly distortion effect (incentivise monopolists to produce more) and Pigouvian correction (correct for spillover), while still screening firms.

Important: these are marginal taxes/subsidies, not average or total taxes. "On balance, the government is still raising positive net revenues and consumers still get to consume a positive net output."

Cross-sectional variation: for given levels of monopoly distortion and Pigouvian correction, screening term is larger in absolute value for lower type firms.
- Profit wedge: screening term positive → higher productivity firms face lower profit wedge (less positive marginal profit tax or higher marginal profit subsidy)
- Net R&D wedge: screening term's sign depends on 1 - ρθr. Since ρθr = 1.88 > 1 → screening term negative → "the net R&D wedge is larger for higher type firms." R&D investments disproportionately benefit high productivity firms → better to incentivise R&D less for lower productivity firms, so high productivity firms can be incentivised more.

"In short, lower productivity firms that have no comparative advantage at innovation are not incentivised as much to invest in R&D, so that high productivity firms can be incentivised more. Naturally, they are still incentivised to some (possibly even to a large) extent because of the monopoly and Pigouvian corrections."

Mechanism for screening: "higher productivity firms will be able to generate more profits from the same research investments, so the way to attract them to a given allocation that features more R&D investments (without attracting low productivity firms) is by letting the profit wedge at that allocation be lower, rather than by making the R&D wedge higher." This encourages high productivity firms to put in more of the unobserved innovation input. "In some sense, this is 'performance-based' taxation, where good performance, rather than simply more (observable) inputs, is rewarded."

Gross wedge: smaller for higher type firms (partially compensating for lower profit wedge), but net incentive for R&D is larger for higher productivity firms.

For optimal inputs: higher research productivity firms should optimally provide more effort and invest more in R&D. Since ρlθ > 0 and ρrθ > 0 (estimated), effort and R&D for higher productivity firms have higher marginal benefits, and generate more spillovers.

Section 5.3.2 - Age Patterns:

Younger firms: simultaneously have profits taxed at higher rate (subsidised at lower rate) and R&D investment expenses subsidised less on net. With p̃ = 0.63 (less than fully persistent), screening terms are "largest in absolute values early in life, when the firm has the most private information, and decay with time, at a rate that is decreasing in the persistence." → optimal to distort allocations more among young firms to reduce overall informational rents. Over time, wedges converge to Pigouvian correction and monopoly valuation term. Because screening term on R&D wedge is negative: net R&D wedge converges from below; profit wedge converges from above.



## p. 678-679 - Section 5.4 and 5.5: Comparative Statics and Robustness

Section 5.4 - Role of Persistence, Complementarity, Spillover:

When ρθr = 0.8 < ρlr = 1: optimal R&D wedge is larger, especially for lower productivity firms. Since R&D not just benefiting high productivity firms, less need to reduce innovation incentives for low productivity firms. Also: closer ρθr is to 1, flatter the net wedge for different firm ages.

Higher persistence (p̃ = 0.9): wedges decay at lower rate (more private information sustained longer). More persistent process increases planner's ability to provide dynamic incentives → higher levels of effort and R&D investment for all firms.

No spillover (ζ = 0): wedges simply correct for monopoly distortion. Lack of spillover leads to lower R&D effort and smaller investment wedges.

Section 5.5 - Robustness Checks (in replication file):
- Two-step GMM with variance-covariance weighting
- Different stochastic type processes (AR(1), increasing persistence over life cycle, lower p=0.5, higher p=0.9)
- Varying β (higher β = more market power and higher consumer valuation of quality → more R&D and effort at optimum)
- Higher depreciation rates: δ = 0.15 and δ = 0.30 (larger wedges needed; lower optimal investments)
- Less convex R&D cost (η = 1): barely changes wedges (represent share of costs subsidised), but increases level of effort and incentives that can be achieved
- Re-estimation on COMPUSTAT publicly-traded firms matched to patent data
- Finite firm life cycle: horizon becomes important



## p. 680-681 - Section 6: Simpler Innovation Policies

Restricted, simpler policies are solved for and compared against full unrestricted mechanism. Welfare loss computed relative to full optimum.

Results (Table V): welfare achieved relative to full optimum:

A. Current US policy (T'(π) = 0.23, S'(M) = 0.19): only 18% of welfare gain relative to benchmark planner problem. If no spillovers: 31.1%. Very poor performance.

B. Optimal Linear (T'(π) = τ0, S'(M) = s0): 89% with spillovers, 88.5% without. Much better than current policy.

C. Linear with Interaction Term (T'(π,M) = τ0 + τ1M, S'(M) = s0): 93.5% with spillovers, 93.7% without. Adding interaction term between marginal tax rate and level of R&D spending improves welfare gains.

D. Heathcote-Storesletten-Violante (HSV) type policy (T'(π) = τ0 - τ1π^τ2, S'(M) = s0 - s1M^s2): "The optimal HSV policy reaps a full 97.4% of the full welfare gain of the optimal mechanism (and up to 98.2% in the case with no spillover)." The HSV function has one parameter controlling average level and one controlling progressivity. Extended here with constant component τ0. The implied marginal profit tax and marginal R&D subsidy exactly mimic the patterns of the profit and gross R&D wedges: lower marginal taxes (higher marginal profit subsidies) on higher profit firms, lower marginal R&D subsidies for higher levels of R&D investments. "Once this nonlinearity is allowed for, additional nonseparability between profits and R&D expenses brings no further gain (Panel G)."

E. HSV Tax on Profits and Linear Subsidy (T'(π) = τ0 - τ1π^τ2, S'(M) = s0): 94.7% with spillovers, 95.6% without.

F. HSV Subsidy on R&D and Linear Profit Tax (T'(π) = τ0, S'(M) = s0 - s1M^s2): 97.3% with spillovers, 97.4% without.

G. HSV With Interaction Term: 97.4% / 98.3%

Key conclusion: "the most important quantitative features are: first, the nonlinearity in the R&D subsidy that takes a HSV form and which provides lower marginal subsidies for higher levels of R&D investment; second, although the constant profit tax in this case provides excessively generous incentives to the low profitability firms (and just about the right level for high profitability firms), that loss is quantitatively very small since less profitable firms make low profits to start with."

Implication: "linear corporate income taxes — common in practice — can be very close to optimal for innovating firms if combined with the right nonlinear R&D subsidy."

Important scope limitation: "this is the right corporate tax system for innovating firms, and not all firms in the economy are innovating." Non-innovating firms would have different optimal tax. "If the government can set different corporate tax systems based on whether a firm is in an innovating sector, the tax system presented in this paper would apply to the innovative sectors." If government cannot distinguish: optimal tax = mix of optimal systems for non-innovating and innovating sectors, allowing for possible shifting between the two — noted as "a great avenue for future research."


## p. 682 - Section 7: Conclusion

Core contribution: introduce asymmetric information in a dynamic firm taxation model with spillovers.

Results and methods "are much more broadly applicable to the provision of firm incentives in dynamic settings with asymmetric information and with other types of investments with or without spillovers."

Formulas written "in the most generic form possible." Framework provides new way to think about innovation and firm taxation more generally.

Suggestions for future research:
- Endogenise competition structure in intermediate goods market (entry, exit, stealing products from competitors in response to tax incentives)
- Study optimal R&D policies when there is a noisy signal about product quality that firms may be able to manipulate
- More extended structural estimation focusing on identification of key parameters (complementarities, persistence, strength of spillovers) for different sectors and types of products → shed light on optimal sector-specific policies
