# Paper v2 blueprint: from thesis to journal manuscript

**Historical development blueprint.** Numerical examples and implementation notes below predate R11c. The active paper now uses sectoral SBIE before imputed QTI adjustment; the historical hybrid is a conditional sensitivity. Use [the R11c revision](../docs/refactoring/r11c_sbti_specification_revision.md), the current manuscript and its named reference for current numerical claims.

**Target file:** `writing/paper_v2.tex` · **Primary target:** *International Tax and Public Finance* (ITAX) · **Secondary options:** *Fiscal Studies*, *Journal of Public Economics* (JPubE) · **Preceded by:** a U.S.E. Working Paper · **Length:** about 9,050 words of main text, 8 tables, 5 figures, Online Appendix A–E · **Empirical vintage:** tag `v2.0-empirical-freeze`, FY2017–2023 OECD public country-by-country reporting (CbCR).

Every number quoted below is copied from `writing/generated/paper_v2_tables/`, `writing/generated/results_tables/` or `data/processed/diagnostics/master_paper_v2_scorecard.csv`. Where the brief for Step 20 stated a number that the frozen outputs do not support, this blueprint uses the frozen value and flags the change in Section 9.

---

## 1. Title options

1. **The Tax Base Decides: Why Global Minimum Tax Revenue Estimates Disagree** (recommended). Short, states the finding, and works for both a policy reader and a referee.
2. **Measurement before Behaviour: Decomposing Uncertainty in Europe's Global Minimum Tax Revenue.** Puts the ranking of the two candidate explanations in the title.
3. **Who Collects the Minimum Tax? Measurement, Accounting and Allocation in Public Country-by-Country Data.** Leads with the distributional question; the strongest option if the ITAX referees respond most to the collector ledger and the repeal game, which connect to the journal's tax-competition literature.

## 2. Front matter

**Target abstract (148 words).** European governments have budgeted revenue from the Global Minimum Tax, yet published estimates for the same country differ by multiples. We trace that disagreement to its sources. Using public OECD country-by-country data for 2017–2023, we compute European revenue under every combination of six modelling decisions and attribute the variance across estimates to each decision. Two decisions dominate: how profit taxed below 15% is measured and how accounting profit is translated into the minimum-tax base. Together they explain 84.7–91.8% of the variance. Statistical uncertainty in estimated parameters accounts for 1.71% or less, and profit-shifting responses shrink once a division bias in effective tax rates is removed. After the accounting adjustments, the model tracks national budget forecasts for real-economy collectors. Under the 2026 Side-by-Side package, repealing a domestic top-up tax becomes a tax cut for US-parented groups: 85.9% of Ireland's forgone revenue reaches firms.

**Journal positioning.** ITAX is the primary target because the empirical conversation the paper joins takes place there: Hugger, Gonzalez Cabral and O'Reilly (2026) on within-country low-taxed profit, Boukal, Janský and Palanský (2026) on single-country minimum tax decomposition, Schjelderup and Stähler (2024) on the economics of the minimum tax, Godar et al. (2024) and Tuinsma et al. (2025) on what country-by-country reports reveal, and Hindriks and Nishimura (2026) on enforcement. *Fiscal Studies* is the natural alternative because Devereux, Paraknewitz and Simmler (2023) on the substance carve-out and Hanlon (2023) on accounting information in the tax base appeared there, and the accounting bridge in Section 4.5 answers Hanlon's concerns directly. JPubE remains a secondary option if the co-authors judge the variance decomposition and the division-bias result general enough for a broad public economics readership. The manuscript follows ITAX conventions: an abstract of at most 150 words, author–year referencing, and an Online Appendix for derivations and robustness. The introduction cites the ITAX and *Fiscal Studies* papers above in its first literature paragraph so that editors can place the contribution at once.

**JEL:** H25, H87, F23, C54. **Keywords:** global minimum tax; Pillar Two; country-by-country reporting; revenue estimation; profit shifting; tax competition.

**Footnote to title:** acknowledgements; data availability statement pointing to the replication package and `REPLICATION.md`.

## 3. Writing rules applied to every section

These rules come from `docs/archive/thesis-handbook.md` (March 2026 supervisor feedback and the note on writing for the general reader) and from the Step 20 brief. Each subsection draft is checked against them before it enters `paper_v2.tex`.

| Rule | Operational check |
|---|---|
| British English | analyse, behavioural, modelled, centrepiece, programme, standardised, favour |
| No em-dashes or double hyphens as punctuation | `grep -n -- "--\|—" paper_v2.tex` returns only number ranges written with `–` |
| Opening sentence of each section and subsection | Plain language; no formula, no abbreviation, no citation; states what the part does and why the reader should care |
| Explain *why* before *how* | The economic reason for each step precedes any acronym or equation (general reader and policy-officer clarity rule: "and why then?") |
| Declarative voice | No "aims to", "can be seen as", "it is worth noting", "may suggest", and no "not X, but Y" contrast template |
| Abbreviations | Full term at first use in running text; repeated in full after a long gap; also listed in Appendix A notation table |
| Equation chains | One-line map before each chain: what it produces, its inputs, where it is used downstream |
| Dissent and limitations | Main text states the position; a footnote gives the contrary evidence and why the paper keeps its choice |
| Originality flags | Every new notation, design or diagnostic is labelled as the paper's own; adapted formulas state what changed |
| Navigation | Each major section ends with one sentence on what was established and what comes next |
| No bullets | Main text and appendices are prose only; tables carry lists |
| Verified openings | All section and subsection openings in Sections 5 and 6 of this blueprint were checked against these rules on 14 November 2026; the openings of Introduction P4 and Section 3.1 were revised (one contained an abbreviation, one a contrast template) |

## 4. Word budget and exhibit plan

| Section | Words | Main-text tables | Main-text figures |
|---|---:|---|---|
| 1 Introduction | 1,400 | | |
| 2 How the minimum tax raises revenue | 950 | | Figure 1 |
| 3 Data | 850 | Table 1 | |
| 4 Measuring the revenue filters | 2,000 | Tables 2, 3, 4 | |
| 5 Where the disagreement comes from | 1,650 | Tables 5, 6 | Figures 2, 3 |
| 6 Who collects and who gives up revenue | 1,450 | Tables 7, 8 | Figures 4, 5 |
| 7 Conclusion | 750 | | |
| **Total** | **9,050** | **8** | **5** |

**Main-text tables.** All main-text fragments sit in `writing/generated/paper_v2_tables/`. Table 1 `tab_v2_main_table1_sample_and_coverage.tex`. Table 2 `tab_v2_etr_ladder_and_crossval.tex`. Table 3 `tab_v2_main_table3_substance_and_sbti.tex`. Table 4 `tab_v2_stage3_division_bias_and_ppml.tex`. Table 5 `tab_v2_main_table5_variance_and_uncertainty.tex`. Table 6 `tab_v2_budget_backtest_and_hanlon_waterfall.tex`. Table 7 `tab_v2_main_table7_source_collector_ledger.tex`. Table 8 `tab_v2_main_table8_qdmtt_repeal_game.tex`. The full multi-panel versions keep their original filenames for the scorecard and tests.

**Main-text figures.** Figure 1 revenue as successive filters (TikZ, adapted from the thesis figure `fig:gmt_mechanics_intro`, extended with the accounting bridge and the collector stage; new file `writing/figures/fig_v2_filters.tex`). Figure 2 `paper_v2_figures/fig_v2_shapley_variance_core_and_accounting.pdf`. Figure 3 `paper_v2_figures/fig_v2_cbcr_to_budget_waterfall.pdf`. Figure 4 `figures/fig_country_salience_uncertainty.pdf`. Figure 5 `paper_v2_figures/fig_v2_qdmtt_deviation_efficiency_vs_sbti.pdf`.

**Notation used throughout.** Parent jurisdiction $p$, affiliate (host) jurisdiction $j$, year $t$, collecting state $c$. Corrected profit $\pi^*_{pjt}$; profit-correction rate $\rho_{pt}$; effective tax rate (ETR) $\tau$; within-cell ETR distribution $F_{pjt}(\tau)$; low-taxed share $s_{pjt}=F_{pjt}(0.15)$; average top-up gap on low-taxed profit $\bar g_{pjt}$; substance carve-out to profit ratio $\phi_{pjt}$; scenario vector $x=(x_1,\dots,x_6)$ for ETR, substance, carve-out rates, Side-by-Side, behaviour and accounting. Appendix A.1 holds the single notation table (Table A1).

---

## 5. Section-by-section outline

### Section 1. Introduction (1,400 words, no subsections)

The introduction is planned paragraph by paragraph. It states the answer in paragraph 3, as the March 2026 feedback requires.

**P1. Motivation.**
(a) *Opening:* "European governments have already written revenue from the new global minimum tax on multinational profits into their budgets, yet nobody can tell them which part of that forecast is solid."
(b) *Content:* The Global Minimum Tax (GMT) sets a 15% floor on the effective tax rate of groups with consolidated revenue above €750 million. Dutch example: the Ministry of Finance attributed most of its forecast to reduced profit shifting and cut it by €122 million when the January 2026 Side-by-Side (SbS) package changed one allocation rule. Published estimates for the same country differ by multiples.
(c) *Exhibit:* none.

**P2. The question in plain words.**
(a) *Opening:* "Every revenue estimate rests on a short list of modelling decisions, and the size of the estimate depends on how each one is made."
(b) *Content:* The six decisions in words: which profit counts as low-taxed; how much is exempt for real activity; which exemption rates apply; which government collects; how firms move profit; how accounting profit maps into the tax base. The method in Gerbrands' formulation: switching each decision on or off and computing revenue for every combination shows how much each decision moves the answer.

**P3. The answer first.**
(a) *Opening:* "Two of the six decisions account for almost all of the disagreement between estimates."
(b) *Content:* ETR aggregation 42.5–50.2% and the accounting bridge 39.7–44.7% of Shapley-attributed variance; jointly 84.7–91.8% (2017–2023 and 2019–2023 windows, L3 and L4 strict). Parameter uncertainty 1.71% (2017–2023) and 0.36% (2019–2023). EU27 cumulative 2017–2023 range US$144.3–584.9 billion across the 32 core scenarios.

**P4. Three supporting results.**
(a) *Opening:* "Three further results show that the ranking survives the most obvious objections to the method."
(b) *Content:* The Beta-fit rank violation and its fix (validation MAE 3.85 to 1.74 pp); division bias in log semi-elasticities (9.33–11.20 at a 5% ETR, falling to 2.51–3.94); the budget backtest (real-economy FY2023 gaps below €0.5 billion after the accounting bridge).

**P5. Distribution and incentives.**
(a) *Opening:* "The decisions that matter for the total also decide which treasuries receive the money."
(b) *Content:* Five zero-collector states generate US$11.94 billion of liability exported or extinguished; repeal of a domestic top-up tax is never a tax cut under the universal regime and becomes one under Side-by-Side (Ireland 85.9%).

**P6. Literature and contribution.**
(a) *Opening:* "Earlier studies each fix most of these decisions and vary one, so their estimates cannot be compared."
(b) *Content:* One sentence of contribution and one of limitation per paper, positioned against each other, starting with the ITAX and *Fiscal Studies* papers listed under journal positioning: Baraké et al. (2022) jurisdiction averages and the averaging bias that Hugger et al. (2026) document with confidential data; Godar et al. (2024) and Tuinsma et al. (2025) on the content and limits of country-by-country reports; Schjelderup and Stähler (2024) on the economics of the minimum tax; Hindriks and Nishimura (2026) on enforcement; Devereux et al. (2023) on the substance carve-out floor; Heckemeyer and Overesch (2017), Dowd et al. (2017) and Garcia-Bernardo and Janský (2024) on the semi-elasticity; Hanlon (2023) on accounting information in the base; Devereux et al. (2022) on the adoption game; Boukal et al. (2026) single-country decomposition. Contributions stated with strong verbs: the paper *delivers* a public-data distributional measure validated against direct data, *decomposes* scenario variance with a factorial and Shapley design, *separates* scenario from parameter uncertainty, *corrects* the division bias, *reconciles* the model with national budgets, and *tests* the adoption game under the 2026 rules. The six-factor design with the accounting bridge, the four-level ETR ladder, the proposal ratio $\Lambda$ and the source–collector ledger are flagged as original.
(c) *Footnote:* Torslov et al. (2023) and Garcia-Bernardo and Janský (2024) scale estimates of shifted profit.

**P7. Roadmap.**
(a) *Opening:* "The paper follows multinational profit from the public reports to the treasury that collects the tax."
(d) *Closing navigation:* "Section 2 sets out how the minimum tax turns low-taxed profit into revenue and which modelling decisions that process requires."

---

### Section 2. How the minimum tax raises revenue (950 words)

#### 2.1 The collection rules

(a) *Opening:* "The minimum tax adds a top-up charge wherever a multinational pays less than fifteen per cent, and a fixed order of rules decides which government collects it."
(b) *Argument:* Explain in words why the order matters before naming the rules: the host country has first claim; the parent country collects what the host leaves; other countries where the group operates collect the remainder. Then name the qualified domestic minimum top-up tax (QDMTT), income inclusion rule (IIR) and undertaxed profits rule (UTPR). The January 2026 Side-by-Side safe harbour removes US-parented groups from the IIR and UTPR, so their top-up survives only where a host levies a QDMTT. The substance-based income exclusion (SBIE) shields a return on payroll and tangible assets. No equations; one footnote on the OECD Central Record snapshot of 1 May 2026.
(c) *Exhibit:* Figure 1, panel on the collector order.
(d) *Closing:* "These rules turn a single pool of reported profit into revenue through a sequence of filters, which the next subsection writes down."

#### 2.2 Revenue as a sequence of filters

(a) *Opening:* "Revenue for any European state can be written as reported profit passed through a short sequence of reductions and then divided among governments."
(b) *Argument:* One-line map: the identity produces collector revenue $R_c(x)$ from corrected profit and the scenario vector; it is evaluated 32 or 64 times in Section 5. Liability by cell and allocation to collectors:
$$L_{pjt}(x)=\bar g_{pjt}(x_1)\,\max\{0,\; s_{pjt}(x_1)\,B_{pjt}(x_6)\,\lambda_{pjt}(x_5)-\mathrm{SBIE}_{pjt}(x_2,x_3)\},\qquad R_c(x)=\sum_{p,j,t} a_{c\mid pjt}(x_4)\,L_{pjt}(x).$$
$B_{pjt}$ is the minimum-tax base after the accounting bridge applied to $\pi^*_{pjt}$; $\lambda$ is the behavioural retention factor; $a$ the collector share, with Side-by-Side extinction as a residual. State that the six-factor version with $x_6$ is the paper's extension of the thesis five-factor design.
(c) *Exhibit:* **Figure 1** (successive filters, TikZ).
(d) *Closing:* "Each filter in this identity requires a modelling decision that published studies make differently, and the next subsection shows where."

#### 2.3 Why published estimates disagree

(a) *Opening:* "Published estimates differ because each study makes the same six decisions in a different way and reports only its preferred combination."
(b) *Argument:* Map Baraké et al. (2022), Hugger et al. (2026), Boukal et al. (2026), Dutch and German ministry estimates onto the six factors in prose. State the gap: no study varies all decisions jointly on one dataset, and none separates scenario disagreement from parameter noise. Footnote: Baraké et al. use jurisdiction averages because firm-level Table IV brackets were unavailable before 2021.
(c) *Exhibit:* none (Appendix A crosswalk table of studies to factors, optional).
(d) *Closing navigation:* "Section 3 describes the public data that make a joint treatment of all six decisions possible."

---

### Section 3. Data (850 words)

#### 3.1 Public country-by-country reports as a bilateral panel

(a) *Opening:* "Large multinationals report their profit, tax and activity country by country to tax authorities, and these reports are published in aggregated form for most of the world's economies."
(b) *Argument:* Six OECD CbCR tables, reshaped from 1,367,305 raw Table I records into 20,111 parent–affiliate–year cells and an analytical panel of 18,954 pair-years (63 parent and 232 affiliate jurisdictions), 14,108 with positive profit and US$41.91 trillion of corrected profit. The FY2023 vintage from the July 2026 release adds 3,186 pair-years. EU27 slice 4,330 pair-years; behavioural sample 10,611. Why bilateral: the parent country determines which collection rules and safe harbours apply.
(c) *Exhibit:* **Table 1** (sample construction Panel A; coverage by year Panel B).
(d) *Closing:* "Aggregated reports count some profit twice, and the next subsection removes it."

#### 3.2 Correcting double-counted profit

(a) *Opening:* "Profit that passes through holding companies can appear in the reports of both the subsidiary and its parent, which inflates the base on which tax is computed."
(b) *Argument:* The reconciliation model estimates a parent-year correction rate $\rho_{pt}$ from documented anchors, adjusted-profit rows and parity signals; corrected profit $\pi^*_{pjt}$. Explain the prior, the evidence and the holdout in words; the full model moves to Appendix A.3. Footnote on dependence between prior and evidence (audit finding A06).
(c) *Exhibit:* none in main text (`profit_correction_*` tables in Appendix A).
(d) *Closing:* "Corrected profit then needs to be matched with data on real activity and with official forecasts."

#### 3.3 Activity, sector and budget data

(a) *Opening:* "Three further sources measure the real activity that the rules exempt and the revenue that governments expect."
(b) *Argument:* Eurostat inward foreign affiliate statistics (FATS) and EUKLEMS & INTANProd for sectoral payroll and tangible assets; US Bureau of Economic Analysis (BEA) affiliate data; national budget documents for eight member states with their scope and vintage (`budget_benchmarks()` in module 08). URLs and access dates in Appendix A footnotes.
(c) *Exhibit:* none (Appendix A source table).
(d) *Closing navigation:* "Section 4 turns these inputs into the measured filters of the revenue identity."

---

### Section 4. Measuring the revenue filters (2,000 words)

#### 4.1 How much profit is taxed below fifteen per cent

(a) *Opening:* "The first and largest decision is how to find the profit that is taxed below the fifteen per cent floor."
(b) *Argument:* Why distributions matter: an average rate above 15% can hide subsidiaries far below it. The four-level ladder in words, then labels: host average (L1), bilateral average (L2), pooled host distribution (L3), bilateral distribution anchored to Table I (L4, with an anchored and a strict variant). Results: global 2017–2023 low-taxed share rises from 30.14% (L1) to 50.25% (L4 anchored); post-carve-out liability doubles from US$872.92 billion to US$1,753.69 billion. EU27: US$200.42 billion to US$336.65 billion. Notation: $s_{pjt}=F_{pjt}(0.15)$. The ladder is original to the paper.
(c) *Exhibit:* **Table 2, Panel A**.
(d) *Closing:* "A distributional measure is only as good as the curve fitted to the published percentiles, which the next subsection tests."

#### 4.2 Testing the fitted distribution against direct data

(a) *Opening:* "Where subsidiary-level brackets and published percentiles overlap, the fitted distribution can be checked against what is directly observed."
(b) *Argument:* Map first: the fit produces $s_{pjt}$ and $\bar g_{pjt}$ for cells without direct brackets; inputs are the five Table I percentiles; output feeds factor $x_1$. Fit:
$$(\hat\alpha,\hat\beta)=\arg\min_{\alpha,\beta}\sum_{k\in\{5,25,50,75,95\}}\Big[F^{-1}(q_k;\alpha,\beta)-\min\{P_{k,pjt},\bar\tau_j\}\Big]^2,\qquad \bar\tau_j=\min\{\text{statutory}_j+\text{loss allowance},1\}.$$
The diagnosis in words: a 95th percentile above 100% (DEU to DEU 122.5% in FY2023; FRA to FRA 102.0%) forces both shape parameters below one, a U-shaped density that places 64.4% and 67.1% of profit below 15% against direct bounds of 25–50%. Capping halves the matched liability MAE (S2 3.85 to 1.74 pp; S3 3.50 to 1.84 pp) and raises $R^2$ from 0.339 and 0.404 to 0.549 and 0.520. Validation window FY2021–2023. Rank-consistency and BSPI shape-transport details in Appendix B.
(c) *Exhibit:* **Table 2, Panel B**. Focal-cell evidence (`step10_focal_cells_comparison.csv`) in Appendix B.
(d) *Closing:* "Once low-taxed profit is measured, the rules exempt part of it for real activity."

#### 4.3 The exemption for real activity

(a) *Opening:* "The rules exempt a fixed return on wages and tangible assets, so firms with real operations in low-tax countries pay less top-up tax than their profit alone suggests."
(b) *Argument:* Ratio $\phi_{pjt}$, the carve-out relative to profit (cite the thesis note on the origin of the ratio and what it adapts from Hugger et al. 2026). Aggregate versus sectoral carve-out and the substance-based tax incentive (SBTI) overlay. EU27 top-up per unit of profit in 2023: 3.23% aggregate, 3.36% sectoral, 2.76% with SBTI (initial rates). Within-host Table IV substance sorting: low-tax brackets carry less substance (EU27 host-year 36.0% against 47.8%; fixed-effect gap −11.78 pp, $p=0.004$). Footnote: global bilateral gap not significant (−1.10 pp, $p=0.636$).
(c) *Exhibit:* **Table 3** (Panels A and B; Panel C to Appendix B).
(d) *Closing:* "The remaining profit is the base on which firms can respond, and the next subsection measures how strongly they do."

#### 4.4 How firms respond, once a mechanical bias is removed

(a) *Opening:* "Firms that face a higher tax on profit booked in low-tax countries report less profit there, and the size of that response decides how much of the base survives."
(b) *Argument:* Map: the regression produces the semi-elasticity that sets $\lambda_{pjt}$ in factor $x_5$. Hines–Rice panel with pair and year effects:
$$\ln\pi_{pjt}=\mu_{pj}+\gamma_t+\beta_1\tau_{pjt}+X_{pjt}'\delta+\varepsilon_{pjt}\quad\text{or}\quad \ldots+\beta_3\ln\tau_{pjt}+\ldots,\qquad \epsilon(\tau)=-\beta_3/\tau .$$
Division bias in words first: the ETR is tax divided by profit, so error in profit appears on both sides and mechanically steepens the slope at low rates. Current-ETR logarithmic estimates at a 5% ETR: 11.20 (FE-WLS) and 9.33 (FE-PPML). Lagged ETR: 3.94 and 3.22; leave-one-parent-out jackknife ETR: 3.19 and 2.51; joint tests lose significance ($p$ 0.085–0.393). Linear FE-OLS 1.47 on 10,611 cells. The two tax-code instruments have first-stage F statistics of 10.81 and 7.31, and neither 2SLS coefficient is significant. Footnote: Dowd et al. (2017) report steep low-rate responses with US tax-return data that do not share this denominator problem. The jackknife ETR as a division-bias fix is the paper's own.
(c) *Exhibit:* **Table 4** (Panels A–C).
(d) *Closing:* "The last measurement step translates the accounting profit in the reports into the base the rules actually tax."

#### 4.5 From accounting profit to the minimum-tax base

(a) *Opening:* "The profit in the public reports is an accounting figure, while the minimum tax applies to a defined base that excludes most dividends and offsets losses."
(b) *Argument:* Why: dividends between group members are mostly exempt; current losses net within a jurisdictional subgroup; prior losses carry forward; covered taxes define the tax envelope (Hanlon, 2023). Waterfall written as successive adjustments to $\pi^*$:
$$B_{pjt}=\pi^*_{pjt}-D_{pjt}-\ell^{\,\text{cur}}_{pjt}-\ell^{\,\text{prior}}_{pjt},$$
with bracket-level dividend purging, Panel A-II current subgroup loss netting and prior-loss carryforward (factor $x_6$). The 2026 screen is a proxy reported separately. Derivations of the loss stock and tax-timing bridge move to Appendix B.5.
(c) *Exhibit:* none here; results appear in Table 6 Panel B and Table 5 Panel A2.
(d) *Closing navigation:* "With every filter measured, Section 5 asks which of them drives the spread across revenue estimates."

---

### Section 5. Where the disagreement comes from (1,650 words)

#### 5.1 Switching the decisions on and off

(a) *Opening:* "To learn which decision matters most, the model computes revenue under every combination of choices and measures how much each choice moves the result."
(b) *Argument:* Plain-language framing first, then the design: a full factorial over $x\in\{0,1\}^5$ (32 scenarios) and $\{0,1\}^6$ (64 scenarios with accounting). Map: inputs are the 32 or 64 values of $R_{\text{EU27}}(x)$ by country-year; outputs are main-effect shares $\eta^2_k$ and Shapley shares that split interactions; used in 5.2 and 7. Core 32, 2017–2023: ETR 71.46% main (74.31% Shapley), SbS 14.44%, behaviour 4.52%, substance 3.59%, rates 0.14%. Accounting 64: ETR 41.80–50.20% main and 45.02–54.27% Shapley (L3); accounting 35.17–41.34% main. Joint Shapley ETR plus accounting: 84.68% (L3, 2017–2023), 91.75% (L3, 2019–2023), 86.31% and 91.41% (L4 strict). Oaxaca–Blinder analogy in one sentence. The six-factor design is original.
(c) *Exhibit:* **Figure 2** (Shapley shares for the core and accounting designs) and **Table 5, Panels A1–A2**.
(d) *Closing:* "A large spread across scenarios matters only if it exceeds the noise in the estimated parameters, which the next subsection checks."

#### 5.2 Scenario disagreement versus statistical noise

(a) *Opening:* "Some of the spread across estimates could come from the statistical uncertainty in estimated inputs, and the analysis measures that share directly."
(b) *Argument:* Map: 500 joint draws of $(\hat\beta_3,\rho_{pt},\text{Beta residuals})$, each run through 32 scenarios; output is the variance split and $\Lambda$. Law of total variance:
$$\operatorname{Var}(R)=\underbrace{\operatorname{Var}_x\!\big(\mathbb E_\theta[R\mid x]\big)}_{\text{scenario}}+\underbrace{\mathbb E_x\!\big[\operatorname{Var}_\theta(R\mid x)\big]}_{\text{parameter}},\qquad \Lambda=\frac{\max_x\hat R(x)-\min_x\hat R(x)}{W_{90}(x^\star)} .$$
EU27: parameter share 1.71% (2017–2023) and 0.36% (2019–2023); $\Lambda=6.93$ and 14.99; 90% widths US$63.61 billion and US$20.71 billion. Country exceptions in the long window: Austria 52.89%, Sweden 31.46%. Draw diagnostics and seeds to Appendix D. $\Lambda$ is the paper's own statistic.
(c) *Exhibit:* **Table 5, Panel B** (EU27 rows; member-state rows in Appendix D).
(d) *Closing:* "Scenario disagreement dominates, so the remaining test is whether any scenario reproduces what governments expect to collect."

#### 5.3 Back-testing against national budgets

(a) *Opening:* "National budgets give an outside check on the model, because finance ministries forecast what they expect to collect from the same rules."
(b) *Argument:* Eight benchmarks, two windows, channel-matched where the source permits. Raw CbCR collector revenue overshoots everywhere; the accounting waterfall closes most of the gap. Netherlands FY2023: €6.684 billion baseline, €5.117 after dividends, €2.766 after current losses, €2.564 after prior losses, €2.380 after the tax envelope, €0.419 after the 2026 screen, against €0.176 billion. Conduit unwind: Dutch and Luxembourg low-taxed profit fell 64.7% from 2018 to 2023, which explains why the 2019–2023 base leaves a Dutch gap of €3.18 billion. Real-economy collectors after the screen in FY2023: all gaps below €0.5 billion (Germany €0.514 against €1.000; Ireland €3.538 against €3.200; Austria €0.008 against €0.100). Footnote: budget vintages, cash timing and scope differ; the 2026 screen is a proxy.
(c) *Exhibit:* **Table 6** (Panels A and B) and **Figure 3**.
(d) *Closing navigation:* "Section 6 turns from the size of revenue to the question of which treasuries collect it and what incentives that creates."

---

### Section 6. Who collects and who gives up revenue (1,450 words)

#### 6.1 Liability generated and revenue collected

(a) *Opening:* "The state where low-taxed profit is booked does not always collect the tax that profit generates."
(b) *Argument:* Ledger in words: for each state, the liability its profit generates at source and the revenue its treasury collects, cumulative 2017–2023, preferred behavioural SbS scenario. Five zero-collector states (Cyprus, Malta, Estonia, Lithuania, Latvia) generate US$11.94 billion: US$4.44 billion to foreign IIR collectors, US$0.51 billion to foreign UTPR collectors, US$6.99 billion extinguished by SbS. Four institutional groups replace the thesis clustering: high-salience sources, QDMTT-protected collectors, residual IIR/UTPR collectors, Article 50 fiscal exporters. Luxembourg's top-up receipts equal 207.45% of its ordinary corporate income tax (CIT) revenue; Germany collects US$23.06 billion more than it generates. Footnote on why $k$-means with median-filled features was retired (audit A18), pointing to Appendix E.
(c) *Exhibit:* **Table 7, Panel A** and **Figure 4**.
(d) *Closing:* "Firms' responses move profit between these states, and the next subsection counts the ordinary tax that the move brings."

#### 6.2 What behaviour costs and what it brings home

(a) *Opening:* "When firms move profit out of low-tax countries, the lost top-up tax is partly replaced by ordinary corporate tax wherever the profit lands."
(b) *Argument:* Rule B (destination) in words, then:
$$\Delta \mathrm{CIT}_d=\sum_{p,j,t}\tau^{\text{stat}}_d\,\Delta\pi_{pjt\to d},$$
gross and net of source losses. EU27, preferred SbS scenario, 2017–2023: direct top-up falls by US$58.09 billion (from US$401.86 to US$343.77 billion); gross ordinary CIT rises by US$65.27 billion (US$48.15 billion net by incidence); total fiscal gain against the mechanical scenario US$7.18 billion. Netherlands, 2019–2023 annual average: €431 million (SbS) to €678 million (universal) against the Ministry's €397–451 million (October 2026). Rule A and Rule C comparisons in Appendix E.
(c) *Exhibit:* **Table 7, Panel B** (Rule B CIT column).
(d) *Closing:* "Allocation rules also change each government's incentive to keep its domestic top-up tax, which the next subsection tests."

#### 6.3 Does any state gain from repealing its domestic top-up tax?

(a) *Opening:* "A state that drops its own top-up tax either hands the revenue to another government or hands it back to firms, and the rules decide which."
(b) *Argument:* Devereux et al. (2022) predict universal adoption because repeal only transfers revenue abroad. Test: 216 unilateral repeal cases (27 states, universal and SbS regimes, L3 and L4 strict, 2017–2023 and FY2023), plus a further 216 full opt-out cases in Appendix E. Efficiency $e_c$ is the share of forgone QDMTT that reaches firms; the critical welfare weight $w^\ast_c$ is net domestic tax forgone per unit of retained profit:
$$e_c=\frac{\Delta T^{\text{MNE}}_c}{Q_c},\qquad w^\ast_c=\frac{N_c}{\Pi^{\text{ret}}_c},\qquad \text{repeal pays if }\omega_c>w^\ast_c .$$
Universal: $e_c=0$ in all 108 cases, so adoption is dominant. SbS: Ireland 85.9% (L3, 2017–2023; 87.0% in FY2023, $w^\ast=0.655$); in FY2023 Cyprus 87.3% and Malta 63.3%. A capped SBTI overlay delivers relief with zero foreign leakage in all 27 states and exceeds repeal relief in 18 of 27 (FY2023, L3). Footnote: SBTI efficiency excludes the fiscal cost of new incentives.
(c) *Exhibit:* **Table 8** (SbS rows of Panel A and Panel B) and **Figure 5**.
(d) *Closing navigation:* "Section 7 draws these results together into an answer for finance ministries and for the literature."

---

### Section 7. Conclusion (750 words)

#### 7.1 Answer and implications

(a) *Opening:* "Disagreement about how much the minimum tax will raise is mostly disagreement about the tax base, and only marginally about how firms behave."
(b) *Argument:* Answer in the first paragraph (84.7–91.8%; parameter share at most 1.71%). Implications for ministries: agree on measurement and the accounting bridge before modelling behaviour; report behavioural revenue net of ordinary CIT recovery; the SbS package turns domestic top-up taxes into a policy lever with a measurable leakage cost. Position against Baraké et al. (2022), Hugger et al. (2026) and Devereux et al. (2022) only; no new material.
(d) *Closing:* "These conclusions rest on public aggregates, which sets clear limits."

#### 7.2 Limitations and next steps

(a) *Opening:* "Public aggregates cannot recover firm-level detail, so several results are bounds and should be read as such."
(b) *Argument:* No firm-level cross-classification; the accounting bridge is approximated from aggregates; benchmark vintages differ; legal UTPR status is proxied from IIR status (audit A12); three FY2023 cells with missing accrued tax (audit A09). Next steps: confidential CbCR access, firm-level GloBE returns from 2026, and the post-2026 adoption record as a natural experiment for the repeal game.
(d) *Closing:* none (end of paper).

---

## 6. Online Appendix A–E

Each appendix section opens with a plain-language sentence, follows the same rules as the main text, and contains every exhibit that the main text cites. Equations moved out of the main text are marked **[derivation]**.

### Appendix A. Data, profit reconciliation and notation

(a) *Opening:* "This appendix documents how the public reports become the analytical panel and how double-counted profit is removed."
A.1 Notation table (new, Table A1). A.2 Sources, URLs and access dates; study-to-factor crosswalk. A.3 Profit reconciliation model **[derivation]**: prior, evidence, posterior and grouped holdout.
*Exhibits:* `results_tables/data_summary_statistics.tex`, `results_tables/profit_correction_effects.tex`, `results_tables/profit_correction_evidence_table.tex`, `results_tables/profit_correction_validation_holdout.tex`, `results_tables/profit_correction_revenue_sensitivity.tex`, `results_tables/profit_correction_parent_year_top20.tex`, `results_tables/profit_correction_foreign_holding_chain_sensitivity.tex`, `figures/fig_profit_employee_etr_bubble.pdf`.

### Appendix B. Measuring low-taxed profit, substance and the tax base

(a) *Opening:* "This appendix gives the full detail of the measurement steps summarised in Section 4."
B.1 Source tiers and coverage. B.2 Beta fit, statutory cap and rank-consistency **[derivation]**, focal cells (DEU, FRA, ITA, LUX, NLD). B.3 Shape transport to earlier vintages and Stage 1 measurement error. B.4 Substance carve-out, SBTI and capital intensity. B.5 Accounting bridge: dividend purge, loss stock, tax timing **[derivation]**. B.6 CbCR Tables II, III and VI extensions.
*Exhibits:* `results_tables/stage1_source_coverage.tex`, `results_tables/stage1_rates.tex`, `results_tables/stage1_crossval.tex`, `results_tables/stage1_bspi_validation.tex`, `results_tables/appendix_stage1_bspi_summary.tex`, `results_tables/appendix_stage1_conditioning.tex`, `results_tables/stage1_measurement_error_interval.tex`, `results_tables/stage2_aggregate.tex`, `results_tables/stage2_sectoral_sbti.tex`, `results_tables/stage2_h5_regression.tex`, `results_tables/appendix_stage2_asset_sensitivity.tex`, `results_tables/appendix_stage2_payroll_fallback.tex`, `paper_v2_tables/tab_v2_app_table3_h5_regression.tex`, `paper_v2_tables/tab_v2_cbcr_tables_2_3_6_extensions.tex`.

### Appendix C. Behavioural estimation

(a) *Opening:* "This appendix reports every behavioural specification behind the response used in the simulations."
C.1 Sample and identification design. C.2 Functional forms, BIC and non-nested tests. C.3 Division bias **[derivation]**: sign of the mechanical covariance and the jackknife ETR. C.4 Instruments and endogeneity. C.5 Tail support, robustness and year-by-year estimates. C.6 From semi-elasticity to the retention factor $\lambda$ **[derivation]**.
*Exhibits:* `results_tables/appendix_stage3_sample_summary.tex`, `results_tables/appendix_stage3_behavioural_design.tex`, `results_tables/stage3_main_regression.tex`, `results_tables/stage3_regression_table.tex`, `results_tables/stage3_model_comparison.tex`, `results_tables/appendix_stage3_tax_coefficients.tex`, `results_tables/appendix_stage3_specification_tests.tex`, `results_tables/appendix_stage3_wald_tests.tex`, `results_tables/stage3_semielasticity.tex`, `results_tables/stage3_iv_diagnostics.tex`, `results_tables/stage3_econometric_scorecard.tex`, `results_tables/appendix_stage3_etr_tail_support.tex`, `results_tables/appendix_stage3_robustness.tex`, `results_tables/appendix_stage3_behaviour_by_year.tex`, `figures/fig_stage3_semielasticity_estimated.pdf`.

### Appendix D. Factorial decomposition, uncertainty and country results

(a) *Opening:* "This appendix shows that the variance ranking holds across windows, designs, countries and influential jurisdictions."
D.1 ANOVA identity and Shapley attribution **[derivation]**. D.2 Split-SBTI and 32-scenario accounting designs (remaining rows of Table 5 Panel A). D.3 Measurement-sample decomposition. D.4 Country ANOVA, scenario spread and fiscal salience. D.5 Joint Monte Carlo: draws, seeds, country rows of Table 5 Panel B. D.6 Jurisdiction influence. D.7 Preferred channel composition. D.8 Thesis hypotheses crosswalk.
*Exhibits:* `results_tables/stage4_6_anova.tex`, `results_tables/stage4_6_factor_decomposition.tex`, `results_tables/stage46_measurement_sample_decomposition.tex`, `results_tables/appendix_stage46_measurement_sample_decomposition.tex`, `results_tables/appendix_stage46_country_anova.tex`, `results_tables/appendix_stage46_top_scenarios.tex`, `results_tables/country_revenue_diagnostic.tex`, `results_tables/appendix_country_revenue_diagnostic.tex`, `results_tables/appendix_jurisdiction_influence_summary.tex`, `results_tables/appendix_jurisdiction_influence_decomposition.tex`, `results_tables/preferred_channel.tex`, `figures/fig_preferred_channel_composition.pdf`, `results_tables/hypothesis_summary.tex`, `paper_v2_tables/tab_v2_app_table5_country_uncertainty.tex`.

### Appendix E. Allocation law, the repeal game and replication

(a) *Opening:* "This appendix sets out the legal allocation rules as modelled, the full set of repeal cases and the replication package."
E.1 Allocation waterfall and SbS exposure. E.2 Qualification and adoption sensitivities (R1–R3, Cyprus Law 151(I)/2024). E.3 Reallocation destination rules A, B and C. E.4 Full repeal and opt-out matrix, including all universal-regime rows. E.5 Why the institutional ledger replaces clustering (legacy PCA and $k$-means exhibits). E.6 Replication: pipeline, runtimes, seeds, hashes.
*Exhibits:* `results_tables/appendix_stage45_summary.tex`, `results_tables/appendix_stage45_sbs_source_exposure.tex`, `results_tables/appendix_stage45_h4_regression.tex`, `paper_v2_tables/tab_v2_app_table7_regime_sensitivities.tex`, `paper_v2_tables/tab_v2_app_table8_universal_and_optout.tex`, `results_tables/country_typology_pca.tex`, `results_tables/country_typology_clusters.tex`, `results_tables/appendix_country_typology_features.tex`, `results_tables/appendix_country_typology_cluster_stability.tex`.

**Not included in the manuscript.** `data_descriptive_tables.tex`, `results_main_tables_manifest.tex` and `results_appendix_tables.tex` are build wrappers; `stage4_6_results_tables.tex` is the legacy monolithic thesis export (audit A19). All 54 fragments in `results_tables/` and all 8 in `paper_v2_tables/` are mapped above.

---

## 7. Exhibit map at a glance

| Exhibit | Source fragment | Section |
|---|---|---|
| Figure 1 | `writing/figures/fig_v2_filters.tex` (new TikZ) | 2.2 |
| Table 1 | `paper_v2_tables/tab_v2_main_table1_sample_and_coverage.tex` | 3.1 |
| Table 2 | `paper_v2_tables/tab_v2_etr_ladder_and_crossval.tex` | 4.1–4.2 |
| Table 3 | `paper_v2_tables/tab_v2_main_table3_substance_and_sbti.tex` | 4.3 |
| Table 4 | `paper_v2_tables/tab_v2_stage3_division_bias_and_ppml.tex` | 4.4 |
| Table 5 | `paper_v2_tables/tab_v2_main_table5_variance_and_uncertainty.tex` | 5.1–5.2 |
| Figure 2 | `paper_v2_figures/fig_v2_shapley_variance_core_and_accounting.pdf` | 5.1 |
| Table 6 | `paper_v2_tables/tab_v2_budget_backtest_and_hanlon_waterfall.tex` | 5.3 |
| Figure 3 | `paper_v2_figures/fig_v2_cbcr_to_budget_waterfall.pdf` | 5.3 |
| Table 7 | `paper_v2_tables/tab_v2_main_table7_source_collector_ledger.tex` | 6.1–6.2 |
| Figure 4 | `figures/fig_country_salience_uncertainty.pdf` | 6.1 |
| Table 8 | `paper_v2_tables/tab_v2_main_table8_qdmtt_repeal_game.tex` | 6.3 |
| Figure 5 | `paper_v2_figures/fig_v2_qdmtt_deviation_efficiency_vs_sbti.pdf` | 6.3 |

## 8. Exhibit preparation (completed in Step 21)

1. **Main and appendix profiles.** `code/13_generate_exhibits.R` now writes compact fragments next to the full tables: `tab_v2_main_table3_substance_and_sbti` and `tab_v2_app_table3_h5_regression`; `tab_v2_main_table5_variance_and_uncertainty` (core 32 and Accounting 64 for 2017–2023 and 2019–2023, EU27 law of total variance) and `tab_v2_app_table5_country_uncertainty` (split SBTI, Accounting 32, Accounting 64 for 2021–2023, member-state rows); `tab_v2_main_table7_source_collector_ledger` and `tab_v2_app_table7_regime_sensitivities`; `tab_v2_main_table8_qdmtt_repeal_game` and `tab_v2_app_table8_universal_and_optout`. A test checks that each main and appendix pair reproduces exactly the rows of the full table.
2. **Figure 2.** `make_paper_shapley_figure()` writes `paper_v2_figures/fig_v2_shapley_variance_core_and_accounting.pdf` from `step7_decomposition_architecture_stress_test.csv` and `step15_globe_accounting_factorial_anova.csv`.
3. **Figure 1.** `writing/figures/fig_v2_filters.tex` holds the TikZ filter diagram with the accounting bridge and the collector waterfall.
4. **Table 1.** `write_paper_main_table1()` writes `tab_v2_main_table1_sample_and_coverage` from the same objects as the two descriptive tables. It needs the local-only raw Table I extract (`data/raw/oecd_cbcr/cbcr_table1_aggregate_totals.csv`), so a full module 13 run must happen on a machine that holds it.
5. **Verification.** All 360 frozen processed files keep their hashes, the test suite passes (412 expectations), and every new fragment compiles in a stand-alone harness without errors, warnings or overfull boxes.

## 9. Corrections to the Step 20 brief

The frozen outputs differ from three statements in the Step 20 brief, two in the Step 24 brief, several Section 6 figures in the Step 25 brief and several appendix figures in the Step 26 brief, and one bibliography entry needs correcting. The research note and this blueprint use the frozen values and the correct citation.

1. **SBTI overlay.** The brief states 100% no-leakage efficiency "in 20 of 27 EU states". In `step13_qdmtt_vs_sbti_strategy_comparison.csv` the overlay efficiency is 100% with zero leakage in **all 27** states, for every ladder and window. The overlay delivers more relief than SbS repeal in **18 of 27** states (L3, FY2023 and 2021–2023; 18 for L4 strict FY2023 and 19 for L4 strict 2021–2023). No cut of the data yields 20.
2. **Ireland's repeal efficiency.** 85.9% is the L3 value for 2017–2023. Table 8 (FY2023) shows 87.0%. The text cites both with their windows.
3. **Joint variance share.** The brief's rounded "42%–50%", "40%–44%" and "85% to 92%" correspond to exact Shapley shares of 42.5–50.2% (ETR), 39.7–44.7% (accounting) and 84.7–91.8% (joint) across the 2017–2023 and 2019–2023 windows and the L3 and L4 strict designs. In 2021–2023 the joint share reaches 93.3% (L3) and 93.6% (L4 strict).

4. **Side-by-Side main effect in the core design (Step 24 brief).** The brief gives an average SbS effect of −US$87.55 billion; that figure is the thesis 2017–2022 vintage (`baseline_generated/results_tables/stage4_6_main_effects.tex`, −87.5). The frozen 2017–2023 core 32 design gives −US$98.61 billion (`step15_globe_accounting_factorial_anova.csv`, scenarios with $x_6=0$; also `step7_stage4_6_main_effects_pooled.csv`). Section 5.1 uses −US$98.61 billion.
5. **Statutory rate behind the Beta-fit ceiling (Step 24 brief).** The brief describes $\tau^{\mathrm{stat}}_{jt}$ as the central-government statutory rate. The pipeline takes `coalesce(cit_top_all, cit_standard)`, and `cit_top_all` holds the OECD `TARGETING = TA` series, which is the targeted (reduced) rate. For France in 2023 this is 15.0% (the standard central-government rate is 25.825%); Belgium, Spain, Hungary, Lithuania, Latvia, Luxembourg, the Netherlands, Poland and Slovakia are also affected in 2023. Section 4.2 describes the series as used. Correcting it requires a new empirical freeze.
6. **Section 6 figures (Step 25 brief).** Checked against Tables 7 and 8 and the Step 6, 7 and 13 diagnostics; the text uses the frozen values. (a) EU27 collector receipts by rule are IIR US$36.82 billion and UTPR US$38.80 billion (brief 36.88 and 38.73); universal UTPR is US$173.89 billion (brief 173.83). (b) France collects US$22.28 billion (brief 23.72). (c) Cumulative collector receipts as a share of CIT are 35.48% for the Netherlands, 28.47% for Ireland and 31.99% for Hungary (brief 39.21%, 29.07% and 25.19%; no frozen file holds the brief's values). Ireland is in group 2, because its source liability is 24.93% of CIT, below the 25% high-salience threshold. (d) FY2023 L3 repeal efficiency is 36.3% for Germany, 29.3% for France, 37.3% for the Netherlands and 24.3% for Luxembourg (brief 19.6%, 13.7%, 36.0% and 24.1%); the Netherlands over 2017–2023 is 45.9% (brief 46.0%). (e) Ireland's FY2023 SBTI relief is US$0.44 billion (brief 0.50). Repeal beats the overlay in nine states: clearly in Ireland, Cyprus, Malta, Luxembourg, the Netherlands and Hungary, and by less than US$3 million in Croatia, Denmark and Lithuania. (f) Rounding: EU27 source CIT lost is US$17.11 billion, and Germany's top-up loss and induced CIT are US$7.53 and 16.56 billion; the net gains of Italy and Belgium are US$5.66 and 4.00 billion, and Ireland's net loss is US$7.14 billion. (g) The US$7.18 billion gain is gross of source CIT losses; net by incidence, the EU27 fiscal change is −US$9.94 billion, and the text reports both. (h) The Luxembourg annotation in Figure 4 was hard-coded from an earlier vintage (225% and 182%); it is now computed from the data (207% and 163%).
7. **Hindriks and Nishimura (2026).** The bibliography entry `jean2026` stores the authors' first names as surnames ("Jean, Hindriks and Yukihiro, Nishimura"). The article is by Jean Hindriks and Yukihiro Nishimura and is cited as Hindriks and Nishimura (2026). Fixed in Step 21: the key `jean2026` is kept so the thesis still compiles, and `hindriks2026` is added as an alias.

8. **Appendix figures (Step 26 brief).** Checked against the fragments and diagnostics; the appendices use the frozen values. (a) Pooled Table IV completeness: −US$0.44 billion is the direct-only check over 2017–2023 (0.12% of US$360.49 billion); adding the shape-transport anchors gives −US$1.27 billion (0.35%). The largest single-year EU27 change is −0.55% (2023), which is the "less than 0.6%" in Section 7.2; the three host-years without low-bracket tax are non-EU and move global 2023 liability by −2.15%. (b) The 23.9-point lower median shield ratio of groups above €10 billion is the global paired-parent comparison (618 pairs, p = 6.1×10⁻⁴); the EU27-host difference is 5.3 points and insignificant (p = 0.14). (c) Table VI size bins are consolidated turnover in euros, so the threshold is €10 billion, not US$10 billion. (d) The four-cluster k-means solution is 100% stable under jitter; the weakness is its dependence on k (85.5% stability at k = 3, minimum 66.7%), a singleton cluster (Luxembourg) and median-filled channel shares for the five zero collectors. The Section 6.1 footnote and Appendix E.2 say this. (e) Dutch costing (Kamerstukken II 37025, nr. 6): Rule B under SbS (€431 million) lies within 9% of the post-package €397 million, while universal allocation (€678 million) is 50% above the pre-package €451 million. (f) The foreign holding-chain adjustment is a sensitivity only (10% on 46 flagged cells in eight conduit hosts); the sentence removed from Section 4.5 implied it was applied, and Appendix A.3 describes it as a sensitivity. (g) The package has thirteen numbered modules plus companions 02a and 07a, run in fifteen stages. (h) The Step 26 trim of Section 4.2 had described the statutory rate as "central-government"; the text again states that it is the targeted rate where reported (see item 5). (i) `tab_v2_app_table5_country_uncertainty` is input in Appendix D.1, where its split-SBTI and accounting panels are discussed; Appendix D.2 refers to its country panels.

The "216 unilateral QDMTT deviations" count is confirmed as the QDMTT-repeal subset of the 432-row deviation matrix (27 states × 2 regimes × 2 ladders × 2 windows); the matrix holds a further 216 full opt-out cases. The "65% conduit unwind" is the 64.7% fall in combined Dutch and Luxembourg low-taxed profit between 2018 and 2023.

## 10. Questions to settle with the co-author

1. Journal choice: ITAX first (closest fit with the papers the manuscript engages), *Fiscal Studies* as the alternative, or JPubE if the co-authors see a broader audience for the variance decomposition.
2. Title choice among the three options in Section 1.
3. Whether the repeal game stays in the main text or becomes a companion policy note.
4. Timing: full draft early in 2027, U.S.E. Working Paper in spring 2027, submission before summer 2027.
5. Whether to invite dr. Javier Garcia-Bernardo (Department of Methodology and Statistics, Utrecht University) to join the paper, and whether this could connect to supervision of an external PhD at Utrecht University. The pipeline builds directly on four of his country-by-country reporting papers: the US macro profit-reconciliation anchors for 2017–2019 in `data/manual/profit_correction_anchors.csv` come from Garcia-Bernardo, Janský and Zucman (2022); the logarithmic profit-shifting specification and the activity-weighted (formulary) destination rule behind Rule B follow Garcia-Bernardo and Janský (2024); and the CbCR effective tax rate methodology follows Garcia-Bernardo, Janský and Tørsløv (2021, 2023). His involvement alongside dr. Peter Gerbrands would join U.S.E.'s tax policy expertise with UU Methodology and Statistics and connect the paper to the core CbCR research network.
