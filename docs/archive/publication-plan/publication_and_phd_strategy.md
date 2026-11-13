# Publication and external PhD strategy for Maurits de Haan

Prepared 5 September 2026. Planning horizon: September 2026–June 2027, followed by journal review and a sustainable external doctorate.

This plan uses your stated availability of **8–12 hours per week**, some employer flexibility, and your combined priorities: strong research, a clear external PhD route by June, and future policy and business influence. I interpret June as **June 2027**. Publication probabilities, effort estimates and recommendations below are my judgements, not admissions statistics or promises from journals or universities.

The assessment is grounded in [the LaTeX thesis](/Users/mauritsdehaan/Documents/VSC/GMT_paper/writing/thesisv4.tex), the [79-page thesis PDF](/Users/mauritsdehaan/Documents/VSC/GMT_paper/writing/thesisv4.pdf), the bibliography, selected earlier methodological material and literature notes, the research logbook, generated tables and diagnostics, and targeted inspection of the R implementation. It is a publication-readiness review, not a complete replication or a certification of every calculation. The existing thesis and analysis have not been changed.

Companion documents: [technical revision audit](/Users/mauritsdehaan/Documents/VSC/GMT_paper/writing/publication_plan/technical_revision_audit.md) and [research brief and draft outreach](/Users/mauritsdehaan/Documents/VSC/GMT_paper/writing/publication_plan/research_brief_and_outreach.md).

## 1. The decision I recommend

**Pursue publication. Do substantial redevelopment before submitting. Build the paper and the PhD relationship together.**

Your strongest asset is a research question that matters: which assumptions explain differences in estimated Global Minimum Tax revenue, and which information would make those estimates more useful? The repository contains enough substantive work to justify a serious attempt. However, relevance alone does not establish originality or methodological validity. Adding FY2023 and shortening the thesis would leave several important objections unresolved.

The best route is one international research article, developed with one genuinely involved academic collaborator, with a second specialist added only if needed. Accompany it with a distinct Dutch policy article and a concise business briefing. Start the external PhD conversations now, using a progressively stronger paper as evidence of your ability. Do not make acceptance by a journal a prerequisite for approaching a promotor.

My preferred initial framing is:

> **How much can public data tell us about minimum-tax revenue? Measurement, legal allocation and the reconciliation of European estimates.**

The enduring contribution should be a validated way to compare estimates and establish which conclusions survive limited information. The precise 69% measurement share is a result to re-test, not a finding that the revision must preserve.

### How realistic is publication?

The following are deliberately broad planning estimates. They concern your project, not a journal's acceptance rate. They assume continued work, honest reporting of adverse results, suitable submissions and participation in revisions. The rows overlap and must not be added together.

| Outcome | My assessment | Conditions and horizon |
|---|---|---|
| Acceptance of the current thesis with mostly editorial changes in a good international research journal | Low; roughly below 10–15% | The contribution, measurement and interpretation issues are substantial. Immediate submission is poor use of the paper. |
| Eventual publication of a thoroughly revised paper in a suitable international specialist research journal | Plausible; roughly 40–65% over 24–36 months | A defensible result survives the audit; one experienced collaborator contributes; you are willing to revise and make two or three sequential submissions if necessary. |
| The same route after the key measurement and legal questions are resolved and two informed external readers positively assess the contribution | More favourable; roughly 55–75% | This is a future reassessment conditional on evidence you do not yet have. |
| A worthwhile Dutch policy publication from validated work | Relatively promising; roughly 60–80% over 12–24 months | A specific Dutch message, a suitable editorial pitch and willingness to rewrite. This is a different outcome from an international refereed research article. |
| A leading general-interest economics publication from the present project | Very unlikely; below roughly 5% | A substantially different contribution or research design would be needed. It should not determine this project's schedule. |
| A clearly agreed external PhD route by June 2027 | Feasible, but not usefully quantifiable from the available information | Supervisor capacity, your academic record, faculty approval, workload and personal fit remain unknown. Formal admission and publication are separate decisions. |

The point of these ranges is to distinguish an attractive but uncertain research investment from a near-ready manuscript. There is no defensible way to estimate a precise acceptance probability from one thesis review. Use the October and December decision points below to update this assessment.

An adverse finding can still support a useful paper. For example, showing that a supposedly informative public-data estimator fails validation, explaining why, and establishing better bounds may be more publishable than a fragile country ranking. Conversely, if the only surviving result is the already-established observation that country-average ETRs hide low-taxed profit, a top specialist research paper will be difficult. In that case, narrow the output to a replication or policy contribution and move the more ambitious research to the next project.

## 2. What you have, and what the article needs to become

The thesis already has a corrected bilateral CbCR panel for 2017–2022, competing low-tax measurement methods, a substance module, behavioural estimates, a collection waterfall and a factorial decomposition. It reports 15,758 analytical parent–affiliate–year cells and 8,971 behavioural estimation observations. The latest generated decomposition attributes 69.1% of pooled scenario variation to measurement and 15.0% to Side-by-Side allocation. It already includes validation, uncertainty exercises, alternative measurement windows and jurisdiction influence checks. The revision should build on these rather than add a long, undirected list of robustness exercises.

Its weakness as a journal article is the attempt to carry five contributions at once: distribution recovery, decomposition, new elasticity estimates, sectoral tax incentives and machine-learning country types. Each creates a separate burden of proof. One well-supported contribution will be stronger than five partially supported ones.

### The novelty test

Three bodies of work must be confronted directly:

| Closest work | What you must credit | What could remain yours |
|---|---|---|
| Hugger, González Cabral and O'Reilly, *Effective tax rates of MNEs and the global distribution of low-taxed profit* | Within-country low-tax heterogeneity and distributional measurement using aggregated CbCR are established. The thesis's simple contrast between your public data and their confidential microdata is inaccurate. | Transparent validation and sensitivity of public-data revenue estimates, ownership-specific allocation, and a defensible comparison of measurement methods. |
| Boukal, Janský and Palanský, *Decomposing the revenue implications of the global minimum tax* | A GMT revenue decomposition already exists, using Slovak administrative data and distinguishing top-up taxes from ordinary corporate-tax changes. | A different decomposition of variation between estimates across EU collectors, with explicit coverage and legal assumptions. |
| OECD July 2026 impact assessment and new post-implementation research | Current implementation, Side-by-Side and early observed responses have now been studied. | A replicable public-data reconciliation and an explanation of what cannot be established without stronger data. |

Sources: [Hugger et al.](https://link.springer.com/article/10.1007/s10797-024-09869-2), [Boukal et al.](https://link.springer.com/article/10.1007/s10797-026-09946-8), [OECD July assessment](https://www.oecd.org/en/events/2026/07/economic-impact-assessment-of-the-global-minimum-tax-2026.html), [Contreras, Hugger and Zawisza](https://www.oecd.org/en/publications/2026/07/mne-responses-to-the-global-minimum-tax_a2b1c6a4.html).

Write a comparison matrix before new estimation. For each study record data years and release, covered population, geographical coverage, accounting adjustments, revenue definition, behavioural channels, legal scenario, currency, treatment of missing countries and validation. Then state the incremental contribution in three sentences. If those sentences mainly say “more recent data” or “more scenarios,” the research angle needs further work.

### Choose between three viable versions

| Version | Content | Recommendation |
|---|---|---|
| A. Public-data measurement and reconciliation | Validated top-up estimates; transparent bounds; decomposition conditional on clearly specified rules; comparable national and international benchmarks. | Best first article. Add a bounded ordinary-CIT extension if feasible, without making it a new identification project. |
| B. Total fiscal effects of GMT | Top-up revenue plus source and destination changes in ordinary CIT, with coherent behavioural responses and policy adoption. | Stronger ambition, but substantially more work. Choose only if a collaborator can help build and defend the full accounting. |
| C. Side-by-Side and European fiscal exposure | A legal and economic explanation of which collection rights survive, with selected country simulations. | Attractive alternative with a tax-law collaborator. It needs a legal argument and current implementation review, not merely the economics paper with fewer equations. |

Adopt A for the initial work programme. At the December review, choose A or C according to the evidence and the collaborator you actually have. Do not develop three complete manuscripts in parallel.

## 3. The substantive revision programme

The companion [technical revision audit](/Users/mauritsdehaan/Documents/VSC/GMT_paper/writing/publication_plan/technical_revision_audit.md) records the evidence and acceptance criteria in more detail. These are the priorities in the order I would tackle them.

### 3.1 Define the revenue object and time convention

Distinguish gross top-up tax collected through QDMTT/IIR/UTPR from the total change in corporate-tax revenue. In schematic terms:

**Change in total corporate-tax revenue = new top-up revenue + change in ordinary CIT after the reform.**

The second term includes gains where profit returns and losses where it leaves. It can also involve domestic policy responses and interactions with other tax regimes. Your current redistribution exercise conserves profits but does not convert the relocated profits into the full ordinary-CIT revenue change. Consequently, the small behavioural share in your top-up scenario variance cannot establish that behavioural effects are small in the overall fiscal reform.

For Version A, explicitly limit the main estimand to top-up revenue and develop a separate, transparent range for the ordinary-CIT channel if the required inputs can be defended. Remove comparisons that imply the same object is being estimated when it is not. Do not automatically treat an extra euro of shifted book profit as an extra euro of taxable profit at the headline CIT rate.

Your 2017–2022 calculations are counterfactual applications of later policy regimes to earlier economic bases. They are not taxes actually collected in those years. Lead with FY2023 annual estimates and comparable annual results for 2021–2022. Keep the historical panel as a robustness and measurement resource. State the data year, legal regime date, currency and whether the figure is an accrual or cash-flow concept beside every headline number. If cumulative historical totals remain, call them sums of annual counterfactuals and explain their limited policy meaning.

### 3.2 Repair the measurement interpretation

Table IV groups observations by the ETR of an **MNE subgroup in a jurisdiction**. It does not directly disclose each legal subsidiary's ETR. That distinction is helpful because GloBE also uses jurisdictional blending within groups, but CbCR subgroups still do not reproduce adjusted GloBE liabilities. Correct this description throughout the article. The [OECD Table IV definition](https://data-explorer.oecd.org/vis?df%5Bag%5D=OECD.CTP.TPS&df%5Bds%5D=dsDisseminateFinalDMZ&df%5Bid%5D=DSD_CBCR%40DF_CBCRIV) makes the aggregation level explicit.

The percentile reconstruction needs more than a wording change. Weighted averages of subgroup percentiles are not, in general, percentiles of the pooled distribution. Also, a distribution over subgroup counts is not automatically a distribution over profit dollars. The current fallback combines these concepts, and its own validation is weak: across 239 overlapping affiliate-years, the low-tax-share mean absolute error is 0.293 and the calibration R-squared is 0.208.

Prefer directly observed bracket profit and tax information wherever suitable. Retain parent-specific brackets when they exist, especially for US-versus-other ownership comparisons. Report how much profit and simulated revenue depend on imputation, not just the number of rows carrying a “direct” label. A host-level bracket share copied to many bilateral cells is still a host-level input.

For missing cells, use clearly qualified predictions or bounds. Do not market a fitted CDF as recovered profit-weighted truth without additional evidence. A simpler, credible estimator is preferable to defending a sophisticated construction that cannot identify the object it claims to measure.

### 3.3 Fix currencies and validate substance inputs

The [wage selection](/Users/mauritsdehaan/Documents/VSC/GMT_paper/code/02_base_correction_and_merging.R:318) prioritises PPP-dollar wages, and payroll is formed by multiplying those wages by employees. The thesis reports profit in current US dollars. Those monetary concepts cannot be directly combined in an SBIE-to-profit ratio.

Rebuild payroll using consistent nominal currency conversions and date conventions. If PPP data must be used, reconstruct the appropriate local-currency amount with matching conversion factors before converting it to nominal USD. Separately assess whether average wages capture eligible remuneration, employer costs and the employees actually represented in CbCR. Quantify the impact on liability and the factor ranking. This is an early correction, not an optional appendix exercise.

Use Table IV substance data for the low-taxed part where available and conceptually suitable. Test the assumption implicit in applying a bilateral average substance ratio to a low-taxed share. For the sectoral extension, distinguish observed tax data from activity-share imputations. The cap on an incentive is not its actual use; the existence of payroll and assets does not establish a qualifying incentive claim.

### 3.4 Separate behaviour from safe harbours and policy scenarios

Your current behavioural switch includes both an elasticity response and a filter that extinguishes liability for a two-percentage-point band below 15%. This makes its variance share difficult to interpret. The Simplified ETR Safe Harbour uses a specified simplified tax calculation and eligibility requirements; a public CbCR ETR of 13–15% does not itself create automatic exemption. Its start dates must also be respected. See the [OECD Side-by-Side package](https://www.oecd.org/content/dam/oecd/en/topics/policy-sub-issues/global-minimum-tax/side-by-side-package.pdf).

Move this assumed band out of the baseline. If retained, identify it as a behavioural or measurement stress scenario and vary it independently. Separate SBTI eligibility and take-up from sectoral allocation. Separate known SBIE transition rates from uncertainty about measurement. You do not need to retain exactly five binary factors or exactly 32 scenarios: the design must fit the economic questions.

Ask a Pillar Two specialist to review the actual legal mapping, including qualification, implementation and election dates; QDMTT priority; residual IIR and UTPR; intermediate parents and ownership limitations; transitional and permanent safe harbours; and what the public data cannot observe. Treat OECD qualification and domestic implementation as distinct facts. Audit UTPR status independently rather than assuming every legal flag is supplied by the same central-record table.

### 3.5 Reframe the elasticity module

Keep the fixed-effect estimate as a descriptive calibration and sensitivity input. The ETR contains profit in its denominator, while profit is the dependent variable. Fixed effects, BIC selection and a statistically significant coefficient do not remove that mechanical endogeneity. The existing IV diagnostics already counsel caution; another long list of tests will not manufacture a causal design.

Use a small set of literature-disciplined behavioural schedules, with no response as a reference. Separate uncertainty about coefficient sampling from uncertainty about its causal interpretation. Make the implied tax incentive consistent with the chosen SBIE and safe-harbour treatment. A move in the average effective burden and a marginal incentive to shift profit are different objects; state which mechanism the formula represents.

If causal estimation becomes the article's central claim, stop and redesign the identification strategy with an econometric collaborator. That is a different project. For the first paper, a well-defended simulation can be valuable without pretending to be a causal evaluation.

### 3.6 Make the decomposition defensible

A balanced factorial design measures variation across the scenarios you select. It does not give the probability distribution of future tax receipts. Changing the parameter ranges, scenario weights or factor definitions may change the ranking.

Report a small set of explicit designs: a fixed-current-policy measurement comparison; a separate legal-policy comparison; and a broader stress design. Show absolute revenue differences as well as percentage variance shares. Recompute the ranking under plausible alternative behavioural ranges and incentive take-up assumptions. Treat equal weights as a transparent design choice, not evidence that all configurations are equally likely.

The current pooled decomposition sums country-year sums of squares. That object need not match the variance decomposition of the EU-wide total, because cross-country effects can offset or move together. Show both, label them clearly, and connect the object you report to the policy question you answer.

Do not describe the comparison as explaining disagreement among published studies until you have actually reconciled selected studies on a common footing. Otherwise, call it variation between estimates generated by your framework. Standard ANOVA or Shapley accounting is a tool; its use alone is not a methodological invention.

### 3.7 Validate levels before making policy recommendations

The latest processed fiscal table puts preferred Dutch counterfactual revenue at about USD 87.1 billion over six years and Luxembourg's at about USD 51.7 billion. Luxembourg's cumulative top-up estimate is about 225% of its six-year CIT denominator. These figures do not mechanically prove an error, but they demand a serious explanation. Calling them “stress statistics” is insufficient if the same estimates support policy conclusions.

Produce country reconciliation sheets for the Netherlands and Luxembourg first, then Germany and Ireland. Bridge coverage, profit correction, low-tax shares, covered-tax adjustments, substance, legal collection and behavioural assumptions. Report fiscal ratios using matching years and currencies. Identify large unresolved residuals rather than calibrating the model to force agreement with official forecasts.

The Dutch comparison also needs updating. The government's later answer gives approximately EUR 700 million annually before the Side-by-Side package and a EUR 122 million reduction. It attributes roughly EUR 90 million to the exemption and related behavioural channel and roughly EUR 30 million to incentive treatment. These are approximate components. They cannot be used as a pure test of your US-exemption switch. See [answers 270–271 in Kamerstuk 36915, nr. 3](https://zoek.officielebekendmakingen.nl/kst-36915-3.html).

### 3.8 Cut material that does not earn its place

Move the detailed model-selection tournament, the country clustering and most sectoral regressions out of the main article. A regression partly driven by variables already built into an exposure formula is not independent confirmation of its economics. A four-cluster solution from 27 countries can be an exploratory summary, but it should not be a principal contribution or a substitute for transparent country comparisons.

Keep existing high-measurement-window and influence exercises, but rerun them after substantive corrections. Do not import older logbook results into the current article: the numerical conclusions changed across versions. Preserve negative results and document departures from your original expectations.

## 4. FY2023: how to make the update valuable

Adding FY2023 is worthwhile, but it contributes freshness and validation rather than automatic novelty. The current OECD Table IV interface includes FY2023 and records a July 2026 update. Verify the actual variables, flags and country coverage when downloading. FY2023 is still before the principal 2024 implementation and may reflect anticipation, so it does not establish realised GMT effects.

1. Freeze the current thesis dataset and results; preserve its release dates and code version.
2. Download the complete current vintage into a separate raw-data snapshot. Do not append new rows while silently mixing revised old years with unrevised ones.
3. Build a release comparison: changed historical observations; newly reporting parents; new brackets; suppression changes; country notes; and accounting-definition changes.
4. Reproduce the old design on the old snapshot before changing the estimator. Then isolate data-vintage changes, FY2023 additions and methodological changes in separate runs.
5. Freeze the redesigned measurement method using the older information before looking at its FY2023 validation performance. If FY2023 has already influenced tuning, call that exercise validation rather than an untouched holdout.
6. Evaluate predictions against directly observed 2023 brackets using economically relevant errors: low-tax profit, liability and collection exposure. Show revenue-weighted errors and performance for large countries, not only unweighted means.
7. Report FY2023 as the main annual economic base where coverage supports it; show 2021–2023 separately and in a clearly defined average. Retain 2019–2023 as a broader measurement window and 2017–2023 only where the backcast adds value.
8. Run stable-coverage comparisons so a change caused by new reporters is not presented as an economic trend.
9. Update wages, prices, exchange rates, fiscal denominators and sectoral information consistently. Document any unavoidable year mismatch.
10. Freeze a legal snapshot for the main submission. Maintain later developments in a change log, and rerun the core estimates only if a change materially affects the contribution.

The OECD's July 2026 work already includes an early ex post design using consolidated company data. A later PhD chapter on observed effects therefore needs a distinct question and identification strategy; merely adding 2024 to an existing panel will not be enough. [OECD study](https://www.oecd.org/en/publications/2026/07/mne-responses-to-the-global-minimum-tax_a2b1c6a4.html).

## 5. Publish alone or with someone?

**My recommendation is coauthorship with one active academic, while retaining your intellectual ownership and lead contribution.** A third author is justified if they take responsibility for a material legal, empirical or methodological component. A large team is unnecessary for this paper and would increase coordination costs at your available hours.

The ideal coauthor helps decide what the paper claims, challenges the measurement, reads and rewrites substantial text, and participates through referee revisions. Prestige and introductions are useful but insufficient reasons for authorship.

| Arrangement | Benefit | Main risk | Use it when |
|---|---|---|---|
| Solo, with acknowledged advisers | Full control and a clear independence signal | You carry all methodological and publishing judgement; informal readers may disappear when revisions arrive | No suitable collaborator commits after a bounded search, and you can still obtain independent scrutiny |
| You plus Peter Gerbrands | Existing knowledge of the project and a practical first collaboration | Availability and specialist GMT expertise must be established | He wants to make a substantive contribution to the journal version |
| You plus a specialist in international tax/public finance | Stronger challenge to the central measurement and policy claims | Time to establish trust and agree a common question | A short trial demonstrates working compatibility |
| Three authors covering empirical, legal and publication work | Complementary skills and better future PhD network | Coordination and diluted accountability | Each has a specific intellectual task and time to deliver |

Discuss authorship at the start and revisit it when contributions change. Agree contribution statements, author order, corresponding author, code stewardship, expected turnaround, dissemination and how disagreements are resolved. Economics sometimes uses alphabetical order; other fields emphasise first authorship. Choose explicitly. The [ITPF author guidance](https://link.springer.com/journal/10797/submission-guidelines) recommends the student usually be principal author for work based mainly on their thesis. A CRediT-style contribution record helps make your role visible under either ordering convention.

Thesis supervision does not automatically settle authorship of the article. Neither does helping obtain access to a professor. Acknowledge bounded advice where authorship criteria are not met, with the person's consent. Equally, do not exclude someone who makes a substantial contribution to the revised research simply because you wrote the original thesis.

Give the collaborator search six to eight weeks of active effort. If no one commits, continue the minimum viable paper solo with scheduled expert reviews. Avoid remaining indefinitely in an ambiguous “maybe coauthor” arrangement.

## 6. Journal strategy

Your main paper is applied public economics with strong international-tax institutions. Its journal home should follow its final argument. The recommendations below are assessments of fit and ambition, not a ranking of your worth as a researcher.

| Outlet | Fit and realistic role | What the paper would need |
|---|---|---|
| **International Tax and Public Finance (ITPF)** | Best topical specialist target; demanding first choice if the measurement/reconciliation contribution is convincing | Direct positioning against Hugger and Boukal; robust measurement; clear economic implications beyond descriptive rankings |
| **Fiscal Studies** | Strong alternative first choice, and likely the best balance of policy relevance and research credibility for Version A | A focused policy question, transparent evidence and readable exposition. Its guidelines prefer no more than 7,500 words and an abstract of at most 200 words |
| **National Tax Journal** | Conditional option if the paper develops a substantial US-parented-group and international spillover argument | A reason for its readership to care beyond the EU application; do not add a superficial US paragraph merely to target it |
| **World Tax Journal** | Serious alternative for Version C or a developed legal-economic article | A substantive international-tax argument. It is fully peer reviewed, welcomes related disciplines and interdisciplinary work, and lists 10,000–22,000 words |
| **Intertax** | Appropriate for a legally developed discussion of Side-by-Side, allocation and fiscal consequences | A tax-law collaborator or equivalent command of doctrinal argument and primary rules. Its author guide describes double-blind review |
| **Bulletin for International Taxation** | Strong practitioner-facing international route for a distinct applied article | Practical relevance and international application; its guidance specifies editorial review and 5,000–12,000 words. Do not equate that route with the same kind of review as WTJ |
| **TPEdigitaal** | Credible Dutch scientific-policy alternative | A Dutch economic-policy question, concise explanation and rigorous evidence; maximum guideline 5,500 words and independent anonymous refereeing |
| **ESB** | Preferred Dutch dissemination outlet | One defensible Dutch policy message and a few clear figures. An ESB publication can have policy value without serving as the main international research article |
| **Weekblad Fiscaal Recht / NTFR** | Possible specialist Dutch commentary routes | Use if a legal interpretation becomes central and a knowledgeable collaborator can tailor it. Confirm current article category and editorial requirements before drafting |

Verified guidance: [ITPF scope](https://link.springer.com/journal/10797/aims-and-scope), [Fiscal Studies](https://onlinelibrary.wiley.com/page/journal/14755890/homepage/forauthors.html), [National Tax Journal](https://www.journals.uchicago.edu/journals/ntj/instruct), [World Tax Journal](https://www.ibfd.org/journals/world-tax-journal-wtj), [Intertax guide](https://assets.contenthub.wolterskluwer.com/api/public/content/e3eaa36090214f6989c740e330d2f5a6?v=dd2b0243), [Bulletin](https://www.ibfd.org/journals/bulletin-international-taxation-bit), [TPEdigitaal](https://www.tpedigitaal.nl/auteursinstructie), [ESB](https://esb.nu/publiceren-in-esb/).

### Submission sequence

At the December review, select the first journal based on a real introduction, main tables and independent feedback. If the new measurement and reconciliation result is strong and generalisable, try ITPF first. If the paper's principal strength is careful policy analysis, start with Fiscal Studies. The fact that ITPF has published the closest studies helps establish readership fit, but also raises the novelty hurdle.

After a desk rejection, assess whether the reason is fit, insufficient contribution or invalid analysis. Reformatting addresses only the first. Make a targeted revision before sending it elsewhere. A sensible sequence for Version A is **ITPF → Fiscal Studies → reassess the argument and choose NTJ, a tax journal or TPEdigitaal**. This is not an automatic prestige ladder: the third choice depends on what earlier feedback teaches you. For Version C, consider WTJ or Intertax first.

ITPF's Policy Watch is another possible format to discuss if the final output becomes a timely policy analysis. It is not a bypass around scholarly evaluation. Conference presentation also does not confer acceptance in an associated journal.

Do not begin with the Journal of Public Economics or a general top economics journal unless informed readers identify a substantially stronger contribution than is currently visible. “I have time” is a reason to do the research carefully, not to spend successive years making poorly matched submissions.

Allow roughly 9–15 months to reach a strong submission at your hours if the project stays focused; substantial reconstruction could take 12–18 months. From first submission to an eventual accepted paper, allow another 12–24 months or longer as a planning reserve. These are contingencies, not promised journal turnaround times. A first acceptance by June 2027 would be a bonus; it should not be a condition of the PhD decision.

### What the submission package should contain

For an economics-led article, aim initially at 6,500–7,500 main-text words, with journal-specific adjustments. Use roughly five or six principal exhibits: the measurement/revenue architecture; data coverage; validation; the central reconciliation; robustness of rankings; and a limited set of country implications. Provide a separate online appendix.

Prepare the manuscript, a clear cover letter, an anonymised version where required, supplement, data and code statement, funding and conflict disclosures, author contributions and accurate AI-use disclosure. Explain that the work develops your master's thesis and identify a public thesis or working-paper version where relevant. Check each journal's prior-dissemination policy before circulating an overlapping Dutch article. Thesis-derived publication is a normal route, but journal and copyright terms still determine the details.

Use a repository working paper, institutional series if eligible, or a preprint service when the paper has passed an internal quality review and its authors agree. RePEc is an indexing system, not a substitute for a host or acceptance. Code can receive a versioned archival record where redistribution is permitted. Check publication fees and open-access arrangements before submission; do not assume that an external affiliation covers an APC or buy gold open access merely for status.

On revise-and-resubmit, build a response table for every referee point; distinguish essential changes from misunderstandings; show where text and analysis changed; and explain justified disagreements respectfully. Request an extension before a deadline if necessary. After two full rejection cycles, review whether the scope, claim or outlet needs to change rather than restarting the same submission unchanged.

## 7. People and networks: whom to involve, and why

The first task is to create a small set of useful relationships. You do not need a large list of famous names. Public profiles establish expertise; they do not tell us whether someone has capacity, wants an external candidate or is a supportive supervisor.

| Person / network | Why relevant | First request |
|---|---|---|
| **Peter Gerbrands, Utrecht** | Your thesis supervisor; simulation and tax-policy research; already understands the project | A 45-minute publication review and a discussion of an active role, plus advice on a qualified promotor |
| **Adriaan Kalwij, Utrecht** | Your second reader; applied economics and existing familiarity with the thesis | A bounded critique of the measurement and econometric claims, with particular attention to the estimand and the elasticity |
| **Javier García-Bernardo, Utrecht** | Directly relevant work on corporate networks, tax avoidance and CbCR; potentially valuable across the methods and tax literatures | A two-page memo on subgroup aggregation, profit weighting and validation; request a focused methods conversation |
| **Arjan Lejour, Tilburg / CPB** | Particularly strong substantive bridge between international business taxation, academic publication and Dutch policy | Feedback on the reconciliation contribution and whether the project could fit an external doctorate in his institutional setting |
| **Maarten de Wilde, Erasmus School of Law** | International and European tax law, with current minimum-tax work and a policy/practice connection | A bounded legal audit or a discussion of a legal-economic PhD direction |
| **Dirk Schindler, Erasmus School of Economics** | International taxation and multinational-tax economics | An economic assessment of the contribution and, if warranted, advice on appropriate research embedding |
| **Dennis Weber / ACTL, Amsterdam** | European corporate-tax law and the Amsterdam Centre for Tax Law | Explore only if the article develops a substantial legal argument and you want that doctoral home |
| **Felix Hugger or a coauthor; Boukal/Janský/Palanský** | Authors of the closest studies | One precise methodological question or a replication discrepancy, after you have done the comparison |
| **Dutch Ministry of Finance / CPB policy researchers** | Understanding forecast construction and the demand for useful evidence | A technical comparison, ideally through an introduction; seek explanation of publicly discussable assumptions |
| **One in-house tax professional and one experienced Pillar Two adviser** | Reality check on data availability, elections and practical interpretation | A structured review of three examples; discuss research advice separately from any paid engagement |

Profiles supporting the shortlist: [Gerbrands](https://www.uu.nl/staff/PGerbrands), [Kalwij](https://www.uu.nl/staff/ASKalwij), [García-Bernardo](https://www.uu.nl/staff/JGarciaBernardo), [Lejour at Tilburg](https://research.tilburguniversity.edu/en/persons/arjan-lejour/), [Lejour at CPB](https://www.cpb.nl/users/arjan-lejour), [de Wilde](https://www.eur.nl/people/maarten-de-wilde), [Schindler](https://www.eur.nl/people/dirk-schindler), [Weber](https://www.uva.nl/profiel/w/e/d.m.weber/d.m.weber.html).

Start with Gerbrands, then approach Kalwij and one specialist for different, concrete tasks. After discussing fit and introductions, speak with one serious alternative PhD host. Be transparent that you are exploring arrangements; do not make exclusive commitments to several supervisors. One polite follow-up after ten working days is reasonable; after another unanswered attempt, move on.

Send a two-page brief, not the entire repository as a first attachment. It should state the question, the closest research, your potential contribution, the three largest unresolved issues, the work plan and the specific help requested. The full thesis and replication material can be linked as optional background. Ask existing tax experts who encouraged you to identify the strongest novelty claim and the scholar best placed to challenge it. Their praise becomes useful when it yields a precise critique or a relevant introduction.

Use **KVS/Nederlandse Economendag** for Dutch economic-policy contacts, **IIPF** for research feedback, and **IFA/Young IFA** for the international tax profession. The NED is scheduled for 23 October 2026; attending can be useful even if no paper submission is possible. IIPF 2027 is announced for Warsaw in the second half of August; its submission timetable needs checking when published. YIN is primarily aimed at early-career members, generally 40 and under, while welcoming broader participation. [NED](https://esb.nu/nederlandse-economendag-2026/), [IIPF](https://www.iipf.org/cng.htm), [YIN](https://www.ifa.nl/ifa-its-structure/yin).

Prioritise one working-paper presentation and one well-matched conference over frequent attendance without feedback. At any event, aim for two substantive conversations and one useful follow-up. A relationship grows through thoughtful engagement with someone's research and delivery on agreed work.

## 8. External PhD: institutional route and shortlist

Your desired working arrangement is a legitimate doctoral route. It still requires a contribution at doctoral level, formal admission and reliable supervision. Paying your own costs does not replace those requirements. Having one publication can help, but a coherent proposal, strong sample chapter and a promotor's commitment may support admission before a paper is accepted.

If your employer formally gives you paid research time, the university may classify the arrangement as an externally funded doctorate rather than a strictly self-funded buitenpromotie. Ask which category applies; either can preserve your objective of pursuing research alongside employment. Admission also depends on the faculty's assessment of your MSc record and research preparation. Do not assume that you must obtain another complete master's degree, or that no further training will be needed: seek a specific assessment and a targeted training plan.

### Recommended order of exploration

| Route | Why explore it | Verified position / question still open |
|---|---|---|
| **Utrecht, through U.S.E. and the relevant graduate-school structure** | Existing relationship and low cost of testing collaboration; the natural first conversation | UU recognises external doctorates with the same quality requirements. Confirm U.S.E.-specific admission, training, fees, supervision capacity and methodological prerequisites. Do not assume the standard research-master recruitment route is the only possible external route. |
| **Tilburg, around Lejour / Fiscal Institute Tilburg** | Strongest alternative substantive match for your combined research and Dutch policy ambitions | The university distinguishes external candidates from its paid professional programme. Establish which faculty registers an economics-led tax doctorate and which route is available in your case. |
| **Erasmus School of Law, potentially a legal-economic tax project** | Strong Pillar Two expertise and an explicit external route | New external projects from 1 September 2026 currently face EUR 1,350 annually over the stated six-year period; an extension currently costs EUR 1,000/year. A structured digital training programme applies. Confirm fit for your empirical contribution. |
| **Amsterdam Law School / ACTL** | Attractive if the research programme becomes substantially legal and internationally oriented | External admission, training and a stated six-year maximum need to fit your available time. The overview lists EUR 2,000/year, while the detailed page identifies that amount as a 2023 rate subject to annual revision: request the actual 2027 fee. |
| **Maastricht Graduate School of Law** | Reserve option if a specific tax scholar is an excellent personal and substantive match | The graduate-school funding page says no tuition fee. Confirm external admission and actual supervision arrangements; free tuition alone is not a reason to choose a host. |

Sources: [UU external route](https://www.uu.nl/organisatie/promoveren-aan-de-uu/promotietraject-starten/soorten-promotietrajecten), [U.S.E. PhD information](https://www.uu.nl/organisatie/utrecht-university-school-of-economics-use/onderzoek/promoveren-bij-use), [Tilburg routes](https://www.tilburguniversity.edu/education/phd-programs), [Erasmus Law external admission](https://www.eur.nl/en/esl/research/phd/starting-phd), [Erasmus training](https://www.eur.nl/en/esl/research/phd/phd-trajectory/education), [Amsterdam overview](https://www.uva.nl/en/about-the-uva/organisation/faculties/amsterdam-law-school/research/phd-research/admission-to-the-phd-programme/registration-and-admissions-procedure.html), [Amsterdam detailed procedure](https://www.uva.nl/en/about-the-uva/organisation/faculties/amsterdam-law-school/research/phd-research/admission-to-the-phd-programme/how-to-apply-for-contract-and-external-phd-candidates/application-procedure-for-contract-and-external-phd-candidates.html), [Maastricht fees](https://www.maastrichtuniversity.nl/research/mgsl/phd-programme/fee-funding).

Tilburg's general information currently says its PhD routes do not charge a fee except the professional business/economics programme, which lists EUR 7,500 annually. Erasmus's structured ERIM part-time programme is separate from Erasmus Law's external route: its listed fees are EUR 10,000/year in years 1–2, EUR 7,000 in years 3–4 and EUR 6,000 thereafter. That totals EUR 40,000 for five years or EUR 46,000 for six, before incidental costs. Those programmes may suit people wanting their structure and resources, but they are not the default recommendation for you. Check whether ordinary external economics admission is available rather than assuming it is interchangeable with a professional programme. [Tilburg professional fees](https://www.tilburguniversity.edu/research/economics-and-management/graduate-school/ppp/application-admission-and-tuition-fee), [Erasmus part-time programme](https://www.eur.nl/en/ese/research/phd/phd-programme/part-time).

### How Peter Gerbrands can help

Invite Peter to help develop the journal paper, assess your readiness, identify training needs and introduce you to an appropriate promotor. If the working relationship is good, continuity with him could be valuable. However, his public page lists him as a researcher. Neither his title nor your thesis relationship establishes formal promotierecht. Kalwij is an associate professor; that also does not establish individual ius promovendi.

Ask the graduate school who can formally serve as promotor and whether Peter or another specialist could be co-promotor. Under the [UU regulations retrieved, version March 2025](https://www.uu.nl/sites/default/files/UBD-Promotiereglement-UU-2025-vastgesteld-EN.pdf), eligible professors or authorised associate professors can be appointed promotor, and doctoral-level experts may be appointed co-supervisor. Verify the current rules before applying. Cross-university co-supervision is something to explore through formal approval, not to assume.

The ideal arrangement may be a supportive daily supervisor who knows your methods plus a senior promotor who understands international taxation and commits to the whole programme. Those functions need not be performed by the same person. Avoid a nominal senior signatory who never engages.

### What must be clear by June 2027

Your June deliverable should be a written arrangement or a clearly documented admissions decision with remaining administrative conditions. It should identify:

- The host institution and faculty, qualified promotor, co-supervisor and responsibilities.
- The research theme and a plausible article-based thesis structure.
- Whether and how the reworked master's research may count as a chapter, including work published before enrolment.
- Required coursework, research-method training, ethics and data-management processes.
- Actual expected weekly hours, maximum duration, extension arrangements and assessment milestones.
- Written fees and budget, employer contributions, data access and publication freedom.
- Frequency of supervision and a workable procedure if capacity or personal circumstances change.

“A professor likes the idea” is encouraging but insufficient. Conversely, a manuscript under review plus a sound approved doctoral plan is a successful June position even without an accepted article.

Amsterdam's current procedure gives application deadlines of **1 February and 1 May**, with preference for the February route to allow revisions before September. Treat those as dates to reconfirm for 2027. If you choose that route, have supervisor support and the application dossier ready in January. Erasmus ERIM currently lists applications for 2027/28 from 15 January to 15 March 2027, but this matters only if you actively choose that distinct programme. Utrecht and Tilburg dates and processes must be obtained from the relevant graduate office.

## 9. Finding a supportive supervisor and avoiding a poor match

No public webpage can establish that a person is “non-toxic.” Research reputation, friendliness at a conference and impressive student placements are different evidence from consistent, respectful supervision. Evaluate behaviour and arrangements.

Use an eight-to-twelve-week trial around a bounded part of the paper. Agree two meetings and one written review. Observe whether the person reads what you send, explains criticism, distinguishes essential revisions from personal preference, responds reasonably and changes their view when the evidence changes. A demanding reader can be a good supervisor. A relaxed but absent supervisor can be a serious problem.

Before committing, talk privately with at least two current or former candidates, preferably including an external or employed candidate. Where possible, include someone whose progress was slow or who left; successful graduates alone give a selected picture. Ask for concrete examples, not gossip or a personality verdict.

Useful questions include: What happens when a result is null? How long do draft comments normally take? How are authorship disagreements handled? What happens after three months of slow progress? Are external candidates included in seminars and opportunities? Have commitments about workload changed? Who helps if the supervisor becomes unavailable?

Propose the following working agreement, adapted together:

| Topic | Starting proposal |
|---|---|
| Meetings | Every four to six weeks, scheduled in advance, with a short written agenda |
| Draft feedback | Normally within two to three weeks for an agreed, bounded deliverable; longer full-draft reviews planned separately |
| Workload | A realistic weekly commitment and quarterly outputs; no expectation of immediate evening or weekend replies |
| Priorities | One principal paper in active development; additional tasks explicitly displace existing work |
| Review | A substantive annual progress discussion; early discussion of difficulties and reasonable milestones |
| Autonomy | You can argue for choices with evidence, select relevant dissemination opportunities and decline unrelated unpaid work |
| Authorship | Contribution-based agreement before substantial joint work and revision when roles change |
| Continuity | A second supervisor who understands the project and a documented replacement route |
| Problems | Access to the graduate-school coordinator, confidential adviser and applicable escalation procedures |

Score candidate arrangements on research fit, constructive challenge, capacity, external-candidate experience, autonomy, policy connections and practical feasibility. As your own decision weights, give research fit 25%, respectful and constructive supervision 25%, capacity 20%, external-candidate support 15%, policy connections 10% and practical costs 5%. Treat unavailable supervision, coercive authorship or contemptuous behaviour as reasons to decline even if the weighted score looks attractive.

Describe what you want positively: “I work well with agreed milestones, direct feedback and room to organise my research alongside employment.” There is no need to promise unlimited availability to appear motivated.

## 10. A coherent doctoral programme with policy and business relevance

A workable umbrella is **the fiscal and behavioural consequences of international minimum taxation under limited information**. It is broad enough to remain useful if GMT rules change, and focused enough to build cumulative expertise.

| Potential chapter | Distinct contribution | Feasibility condition |
|---|---|---|
| 1. Public-data measurement and reconciliation | Establish what can credibly be measured and how model choices affect fiscal conclusions | The revised current project passes the methods and novelty review |
| 2. Legal allocation and incentives | Explain the distributional consequences of QDMTT adoption, Side-by-Side and incentive treatment | A distinct question with stronger ownership/implementation evidence; cannot simply republish Chapter 1's scenario table |
| 3. Observed firm or revenue responses | Evaluate a defined implementation margin or forecast error using post-reform information | Data access and a credible comparison design; a pure before/after GMT comparison is insufficient |
| Optional additional chapter | Data-quality validation or another separate international-tax mechanism | Add only if required by the approved programme and supported by a real contribution |

An article-based doctorate often makes sense here, but **there is no universal Dutch rule that three or four accepted papers automatically produce a doctorate**. Agree the faculty's expectations, your individual contribution to coauthored chapters and any publication-status requirements. A thesis also needs a coherent overarching argument. Do not plan to recycle a thesis plus a Dutch summary as separate doctoral chapters.

Do a data-feasibility review for Chapter 3 during the first year. Public company disclosures, national aggregates and later public CbCR releases may support some questions. Orbis, CBS microdata or administrative tax data may support others, but availability, coverage and permissions must be established before they become dependencies. CBS requires an authorised institution and approved project access; university affiliation alone does not establish access to confidential CbCR or GloBE returns. [CBS access procedure](https://www.cbs.nl/en-gb/our-services/customised-services-microdata/microdata-conducting-your-own-research/applying-for-access-to-microdata).

At 8–12 hours/week across approximately 46 working weeks, you have about **368–552 hours annually** before considering how much training and administration consumes. This is a serious commitment but does not support the expectation of several substantial solo economics articles each year. Initially plan for one main paper over roughly 12–18 months, potentially longer during major reconstruction, plus a small number of policy outputs derived from solid research. A coauthor pipeline may increase later productivity, but every paper still creates revision work.

For example, Erasmus Law currently specifies 10 EC of first-year education for external and part-time candidates. Such requirements must be included in your total time budget. Ask whether previous methods training can satisfy any requirements and what remains compulsory; do not assume coursework is negligible or automatically waived. [Erasmus Law education](https://www.eur.nl/en/esl/research/phd/phd-trajectory/education).

For the full doctorate, treat six to eight years as a hypothesis to test with potential supervisors, not a promise. At the lower end of your hours, with demanding coursework or difficult data, it may take longer or be incompatible with a programme's six-year limit. If six years is mandatory, solve the hours and scope mismatch before enrolment. Consider negotiating an additional protected half-day per week, so actual research capacity rises rather than merely relabelling existing evenings.

## 11. Policy and business influence without diluting the research

Position yourself as someone who can connect tax rules, public data and credible fiscal analysis. A useful description is:

> “I study how international corporate-tax rules translate into public revenue, and which data and assumptions make those estimates reliable.”

That is more durable than becoming known for a single large revenue number. Use the same research base for different audiences, with genuinely different outputs:

| Output | Audience | Main purpose |
|---|---|---|
| International research article and replication package | Researchers and future doctoral assessors | Establish a defensible contribution and a record of rigorous work |
| Short Dutch policy article, preferably ESB | Ministry, CPB, parliament-facing analysts and economists | Explain one implication for Dutch revenue interpretation and transparency |
| Two-page business briefing | In-house tax teams, CFO advisers and professional associations | Explain which country-level uncertainties matter and why macro estimates do not determine a firm's liability |
| Research seminar or technical roundtable | Academic and policy specialists | Obtain criticism and understand the questions users actually need answered |

An initial Dutch article could be titled “Waarom ramingen van de minimumbelasting uiteenlopen.” A business briefing could focus on the distinction between the headline 15% rate, actual liability and the government that collects it. Do not present a country-level simulation as a firm-specific compliance calculator.

The Dutch article should cite and interpret the research, not duplicate its full results and wording. Agree timing with coauthors and check the research journal's overlapping-publication policy. Public working papers can support influence before final journal acceptance, provided their status and limitations are clear.

Ask your employer for a bounded package: protected time, a small training/conference budget and a clear publication agreement. Explain what the organisation receives—deeper expertise and occasional briefings—and agree what remains yours. Any confidentiality review should have a defined scope and turnaround, and research should remain publishable when results are inconvenient. Disclose relevant employment, funding and commercial roles under the journal's rules. Public aggregate data make the first paper less dependent on employer-controlled information.

Track influence through evidence of use: a substantive citation, a request for a technical explanation, an invitation to present, or an analytical change prompted by the work. Posting frequently is not the same as building a credible research profile.

## 12. Work plan through June 2027

The central plan allocates about **380 hours**, including a 40-hour reserve. It assumes roughly 38–40 productive weeks at around ten hours/week. If your realised availability is consistently eight hours, protect the PhD decisions and move final submission into summer/autumn rather than compressing validation.

| Period | Research and publication work | People and PhD work | Deliverable / decision | Planned hours |
|---|---|---|---|---:|
| September 2026 | Freeze the baseline; read closest and July 2026 work; define the estimand; prepare the issue list | Contact Peter; discuss employer support; request graduate-school information | Two-page concept and one-page novelty comparison | 25 |
| October | Audit units, subgroup construction, percentile weighting and legal factors | Meetings with Peter, Kalwij and one specialist; attend NED if useful | Choose A/B/C; identify a prospective active collaborator | 45 |
| November | Correct measurement and run a minimal validated pipeline; begin FY2023 release comparison | Start the trial collaboration; speak to one alternative PhD host | Credibility review: result, method, or bounded policy pivot | 50 |
| December | Complete first validation and country reconciliations; draft central figures and introduction | Review working fit; identify a feasible supervisory team | Choose first journal and final article scope | 45 |
| January 2027 | Develop the manuscript and appendix | Prepare PhD proposal, CV, writing sample and training/budget agreement; submit early if Amsterdam chosen | Complete PhD dossier and a paper draft | 45 |
| February–March | Finish FY2023 validation; run the redesigned sensitivity exercises; obtain a seminar critique | Follow admissions steps; speak with current/former candidates; negotiate concrete supervision | Submission-quality analytical results and a preferred host | 55 |
| April | Revise after the seminar; independent replication handoff | Resolve remaining admission conditions; activate second-choice host if needed | Full paper and written supervision outline | 35 |
| May–June | Finalise submission if ready; prepare a distinct Dutch policy pitch | Complete admission or document the precise agreed route and outstanding formalities | June decision packet, article submitted or scheduled, approved next research steps | 40 |
| Flexible reserve | Unexpected data revisions, larger corrections, feedback and personal interruptions | Administrative delay | Preserve quality without making every week a deadline | 40 |

### Decision points

**31 October:** Continue the international article if you can state a defensible new contribution and have a credible plan for the major measurement problems. If not, give the methods question another bounded six weeks. Do not spend the entire winter polishing unsupported numbers.

**15 December:** Require a result that survives the corrected units and measurement treatment, a clear legal scenario and an intelligible country reconciliation. If these remain unresolved, narrow the estimand or change the research question. Update the journal choice and probability assessment.

**31 March:** Require at least one realistic PhD host with identified supervisors, formal requirements and a feasible workload. If no such arrangement exists, escalate the search to the next substantive match. Do not wait until June to discover a maximum-duration or training mismatch.

**30 June:** Record an explicit decision: enrol under the agreed conditions; proceed subject to a defined administrative step; or continue publishing independently while pursuing a better supervisor match. Avoid accepting a poor relationship simply to satisfy the date.

### Weekly rhythm

Use two three-hour blocks for analysis or writing, one two-hour block for literature/methods and one two-hour block for meetings, administration and revision. Put the best concentration time on the central paper. Where useful, rotate the allocation; the point is protected blocks rather than constant low-level attention. Leave at least one evening or weekend day entirely free of research. Evaluate completed outputs monthly, not how guilty you feel about time spent away from the project.

## 13. Budget, research infrastructure and issues easy to miss

Obtain written programme fees before choosing a university. In addition, allow an indicative **EUR 1,000–2,500 annual planning envelope** for selected travel, courses, memberships and minor research expenses, adjusted to employer support. This is a personal budget assumption, not a price quotation. Large proprietary datasets, CBS projects or open-access charges need separate decisions and quotes. Do not make expensive data acquisition a condition of the first paper before establishing a viable public-data result.

The repository is useful but not yet a stranger-friendly publication package: the root README is effectively just a title, and several historical output trees coexist. Establish one documented article pipeline with pinned package versions, raw-vintage identifiers, file checksums, a configuration file, seeds, expected outputs and an explanation of restricted or non-redistributable material. Preserve the submitted thesis separately. A reproducible package should allow another researcher to regenerate the central exhibits without knowing the project's history.

Run the meaningful existing tests after changes, then add independent economic checks for the repaired units, subgroup aggregation, legal waterfall and revenue conservation. Compare new results with hand-calculated examples. Passing code tests shows implementation consistency; independent replication and economic validation are still required. Regenerate the article tables and prose from one final snapshot so reported numbers do not drift across versions.

Check redistribution rights for every data source. Public accessibility is not a universal licence to republish datasets, and the literature PDF folder should not be bundled into a public replication archive. Use actual authorised affiliations and distinguish previous thesis affiliation from current employment and future doctoral status. Seek an institutional library/data steward's advice if needed.

The thesis has an AI disclosure describing its original process. A later article that uses AI-assisted research planning, literature search or drafting needs a fresh, accurate disclosure under the chosen journal's rules. That does not retroactively alter how the thesis was written. Verify every reference and substantive claim yourself; you and your coauthors remain responsible for the article.

Agree in advance how earlier work and coauthored chapters count toward the doctorate. Retain evidence of your intellectual contribution. Plan for supervisor departure, retirement, employer change, data-access loss and periods with less research time. Obtain a second supervisory relationship and a process for revisiting milestones. A sustainable programme needs a realistic route through disruption, not an assumption that every year will be unusually productive.

## 14. What to do in the next fourteen days

1. Read this plan and select Version A as the provisional scope unless you have a strong reason to prefer the legal-economic route.
2. Write the one-sentence revenue estimand and stop using broader claims that the current model does not establish.
3. Preserve the thesis baseline; open a separate article workstream.
4. Read the closest three research contributions and record precisely what your paper adds.
5. Prepare a two-page brief using the companion outreach file, with the measurement problems included openly.
6. Contact Peter for a publication and PhD discussion. Request a separate bounded review from Kalwij and one specialist.
7. Ask your employer for a trial of protected research time and clarification of publication conditions.
8. Ask the relevant UU graduate-school/U.S.E. contact for external admission requirements, fees, training, duration and promotor eligibility.
9. Put the October and December decision dates in your own calendar and reserve the weekly research blocks.
10. Start the units and Table IV audit before expanding the dataset or rewriting the entire manuscript.

The best outcome is a paper whose claims survive criticism, a supervisor who actively supports your development, and a research identity that is useful to both academics and people making tax-policy or business decisions. That is a stronger foundation for repeated publication than maximising the number of outputs in the first year.
