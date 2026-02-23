# Hanlon (2023) — "The Use of Accounting Information in Pillar 2 GloBE Tax"
Fiscal Studies, 44(1), 37–52

> Symposium paper, so limit citing 

## Abstract / Scope of Paper (p. 37)

High-level, non-technical review of how financial accounting information is used in Pillar 2 and what this means for the tax base. The paper:

1. Discusses the rules and mechanics of Pillar 2
2. Identifies problems with using financial accounting data as the starting point for GloBE income
3. Considers alternative solutions that may be simpler and pose fewer risks to accounting quality and capital markets

The paper intentionally limits itself to the accounting-income question and explicitly notes that other serious issues (treaty interactions, foreign tax credits, double taxation, ordering of rules, GILTI, CAMT) are outside scope – but acknowledges these are substantial (fn. 1).



## p. 38 – Introduction

Why financial accounting income and taxable income differ fundamentally:

Financial accounting (book) income is computed using the accrual method and is designed to inform external stakeholders (investors, creditors, customers, suppliers, employees) about firm performance. It allows managers to incorporate private information about firm performance. It involves significant estimation – for future warranty costs, collectability of credit sales, etc. Some items are recorded at fair market value (e.g. equity investments <20%, financial instruments elected at fair value). Key reference: Dechow (1994); Dechow, Kothari & Watts (1998); Hanlon, LaPlante & Shevlin (2005) on accrual accounting as a superior measure of economic performance compared to cash flows (fn. 3).

Taxable income by contrast is designed to raise government revenue and to incentivise/disincentivise behaviour (e.g. investment via accelerated depreciation). Note: taxable income is often a hybrid of cash basis and accrual accounting (fn. 2) – many expenses are estimated in advance under book accounting but recognised later under tax.

Hanlon's core argument: anyone with a background in financial accounting will consider using book income as a tax base a bad idea, because the two measures serve entirely different purposes, especially in countries with efficient capital markets. Explicitly linking them creates two chief concerns:
1. Complexity in compliance, administration and enforcement
2. Risk of harming the quality of financial accounting and capital markets

On timing of Pillar 2: OECD reached consensus with ~140 countries in October 2021; EU agreed to implement in 2024. Hanlon considers alternatives still worth discussing in the event the agreement collapses, proves unworkable, or requires revision.



## p. 39 – Section 2: Financial Accounting as the Starting Base for Pillar 2

### 2.1 Pillar 2 Mechanics (Brief Summary)

Basic logic: Start with financial accounting income → make adjustments (GloBE adjustments) to approximate a cross-jurisdictional notion of taxable income → aggregate across constituent entities per jurisdiction → divide adjusted covered taxes by GloBE income to obtain jurisdictional ETR → if ETR < 15%, top-up tax is triggered.

Scope: Applies to MNE groups with annual consolidated revenue ≥ €750 million (fn. 5 notes that consolidation rules differ between tax and financial accounting, and even between US GAAP and IFRS).

Six computational steps:
1. Determine GloBE income per constituent entity, aggregate by jurisdiction
2. Determine adjusted covered taxes per constituent entity, aggregate by jurisdiction
3. Compute jurisdictional ETR per jurisdiction (adjusted covered taxes / GloBE income)
4. Determine top-up tax percentage per jurisdiction
5. Compute excess profit per jurisdiction
6. Compute and impose top-up tax on applicable entities

Why start with financial accounting income? The OECD wants a comparable cross-country income measure. Book income is "likely more comparable across countries than taxable income." However, there remain significant differences both in standards (US GAAP vs. IFRS vs. local standards) and in how those standards are applied, because financial accounting involves more judgement and discretion than taxable income. This creates two required fixes.

Step 1 – GloBE income:

Financial accounting income is adjusted via "GloBE adjustments" (OECD calls these permanent item adjustments, but Hanlon notes they are not all permanent in nature – fn. 7 reports that Dr Ulrike Schramm, Global Head of Tax at Continental AG, listed at least 22 possible adjustments). These bring income closer to a cross-country notion of taxable income (e.g. treatment of equity gains/losses, certain revaluations). Critically: the GloBE adjustments do not include the majority of timing differences between book and taxable income. Example: accelerated depreciation for tax purposes vs. straight-line for book – this difference is not a GloBE adjustment. Therefore: GloBE income ≠ taxable income AND GloBE income ≠ financial accounting income. It is a separate, third measure of income (fn. 9 adds that companies do not ordinarily compute aggregated or consolidated financial accounting income by jurisdiction, so this is an entirely new task requiring additional data).



## p. 40 – Step 2: Adjusted Covered Taxes & the Deferred Tax Problem

Step 2 – Adjusted covered taxes:

Starting point: current tax expense on financial statements of constituent entities and permanent establishments. Then required additions and subtractions for specified items. Then an adjustment for deferred taxes.

Adjusted Covered Taxes exclude top-up taxes accrued under Pillar 2 (IIR, QDMTT, UTPR) to avoid circular calculation. They include CFC taxes (Subpart F, GILTI, possibly US CAMT), allocated back to the CFC jurisdiction; taxes under Pillar 1; taxes on profit distributions. They exclude consumption taxes, property taxes, excise taxes, payroll taxes, digital services taxes (fn. 10, taken from Hanlon & Nessa (2023)).

Deferred tax adjustment explained:

Timing differences = differences between book and taxable income that exist in one year but reverse in a future year. Because taxes are paid on taxable income (not GloBE income), extra computation is needed to ensure that the tax measure is comparable to GloBE income.

Example with full expensing (depreciation): Jurisdiction allows full expensing of assets. In year of purchase, financial accounting income > taxable income (because tax depreciation is large). Current tax expense is low relative to book income → artificially low jurisdictional ETR unless adjusted. OECD does not want this to trigger top-up tax, so a deferred tax adjustment is required.

The rate used to compute the deferred tax amount is: lower of 15% or the country's statutory tax rate.

Numerical example from text: Book-tax depreciation difference = $2,000; country statutory rate = 25%. Accelerated depreciation saves the company $500 in tax relative to what would be owed on book income. For adjusted covered taxes: current tax expense + $300 ($2,000 × 15%) → increases the numerator → increases jurisdictional ETR so that the depreciation difference does not push ETR below 15%.

Key implication: Because there are many book-tax differences requiring this treatment, companies must maintain a deferred tax system specifically for Pillar 2, which is "sufficiently different" from the existing financial accounting deferred tax system and "will increase complexity significantly."

Step 3: Compute jurisdictional ETR = adjusted covered taxes / GloBE income by jurisdiction.

Step 4: Compare jurisdictional ETR to 15%. If ETR < 15%, top-up tax percentage = 15% – ETR.



## p. 41 – Steps 5 and 6: Excess Profit, SBIE, Top-up Tax

Step 5 – Excess profit:

Excess profit = GloBE income – Substance-Based Income Exclusion (SBIE)

SBIE = sum of 10% of payroll costs + 8% of tangible assets (transition rates, declining to 5% each over a 10-year transition period – fn. 11 refers to Devereux, Vella & Wardell (2022) and Faulhaber (2023) for more detail).

Eligible tangible assets: property, plant and equipment; natural resources; lessees' rights of use of tangible assets; government licences to use immovable property or exploit natural resources. Carrying value = average of net carrying value at beginning and end of year from financial accounts used to prepare the consolidated statements.

Purpose of SBIE: exempt "real" activity and target what is more likely profit-shifting.

Step 6 – Top-up tax:

Top-up tax = excess profit × top-up tax percentage – QDMTT (if applicable). Fn. 12: QDMTT = a domestic minimum tax regime that increases domestic tax to 15% in a manner similar to GloBE rules; see Herzfeld (2022). Hanlon does not discuss QDMTT further because it mainly affects who receives the tax payment, not the computation concerns related to using book income.

Important structural note: The excess profit base (the denominator of the top-up tax base) is not adjusted for most timing differences. The jurisdictional ETR accounts for timing via the deferred tax adjustment in the numerator, but the base itself (GloBE income, which equals book income minus GloBE adjustments) reflects straight-line depreciation, not accelerated tax depreciation. This means: no benefit of full expensing is passed through into the top-up tax base.

Table 1 introduced (pp. 41–44, three panels): Numerical example with one asset costing $1,000, 10-year book life, full expensing for tax, statutory rate = 10%, minimum rate = 15%. Book and taxable income before depreciation = $3,000 each. Six columns presented:

- Columns 1–3: Starting with financial accounting income (current Pillar 2 approach)
- Columns 4–6: Alternative – starting with taxable income



## pp. 42–44 – Table 1: Detailed Numerical Example

### Panel A – Year 1

Depreciation: Book = $100; Tax = $1,000 → book-tax difference = $900; Pre-tax book income = $2,900; Taxable income = $2,000.

Column 1 (no deferred tax adj., no SBIE): GloBE income = $2,900; current tax expense = $200; ETR = 6.90%; top-up % = 8.10%; excess profit = $2,900; top-up tax = $235.00. This is the case where the numerator is not commensurate with the denominator – ETR is "arguably artificially low."

Column 2 (DT adjustment, no SBIE): Current tax expense $200 + deferred tax adjustment $90 ($900 × 10%) = $290; ETR = 10.00%; top-up % = 5.00%; excess profit = $2,900; top-up tax = $145.00. The top-up percentage now correctly equals the 5pp difference between 15% and the statutory 10% rate. However, the tax base still reflects straight-line depreciation only.

Column 3 (DT adjustment + SBIE): SBIE at end of year 1 (5% × $900 carrying value) = $45; excess profit = $2,900 – $45 = $2,855; top-up tax = $142.75.

Columns 4–6 (taxable income as starting base): No deferred tax adjustment needed. Column 4: book depreciation in base, result identical to column 2 ($145.00) but without the need for a deferred tax system. Column 5: tax depreciation in base → GloBE income = taxable income = $2,000; top-up % = 5%; top-up tax = $100.00. Column 6: tax depreciation + SBIE ($45) → excess profit = $1,955; top-up tax = $97.75.

### Panel B – Year 2

Timing difference starts to reverse. Book depreciation = $100; tax depreciation = $0; book-tax difference = –$100 (reversal). Current tax expense = $300. Under column 2, deferred tax adjustment = –$10 ($100 × 10%) → total covered taxes = $290; ETR = $290/$2,900 = 10%; top-up % = 5%; top-up tax = $145.00. Under column 5 (taxable income): GloBE income = $3,000; covered taxes = $300; ETR = 10%; top-up tax = $150.00.

### Panel C – Year 10

Same pattern as year 2 for columns 2 and 5. SBIE goes to zero under column 3 because book carrying value of the asset reaches zero by end of year 10.

Sum over 10 years: Columns 1, 2, 4, and 5 all yield total top-up tax = $1,450.00 (columns 3 and 6 not fully calculable in table). Key finding: columns 2 and 4 yield identical results, showing that starting with taxable income (column 4) achieves the same outcome as starting with book income plus a deferred tax system (column 2), but without requiring a deferred tax system for Pillar 2.



## p. 45 – Section 2.2: Potential Problems and Concerns

### 2.2.1 General Concerns

Three general concerns with any system linking financial accounting income to taxable income:

1. Accounting standard setters gain de facto tax legislation power. If FASB or IASB change standards in a way that lowers book income, GloBE income falls, and so does tax revenue. Some are "very concerned" that accounting standard setters would effectively gain tax-legislation-writing capabilities.

2. Government influence over accounting standard setters. Because of the revenue impact, governments (and the OECD) may try to influence standard setters. Accountants are more concerned about this direction of influence than the first. Tax law rules (e.g. accelerated depreciation) are designed to promote behaviour, not to inform investors. If governments start overly influencing accounting standards, the quality of information in financial statements decreases, leading to less efficient capital markets. References: Hanlon & Shevlin (2005); Hanlon, Maydew & Shevlin (2008); Atwood, Drake & Myers (2010). Fn. 17: example – financial accounting does not accelerate depreciation to stimulate investment; US municipal bond interest is included in book income but excluded from taxable income. Also notes ESG disclosures in financial statements could be argued to incentivise/disincentivise behaviour.

3. Incentive for earnings management. If book income is used as the minimum tax base, some companies may have incentive to lower reported financial accounting income to reduce top-up taxes. Hanlon notes there is generally strong pressure to increase book earnings (even at cash-tax cost – see Erickson, Hanlon & Maydew (2004) fn. 19). However, there is mixed evidence that companies managed earnings downward under the US corporate minimum tax enacted in 1986 (which also relied on book income). Companies may shift income across jurisdictions to reduce top-up taxes in specific countries while keeping consolidated worldwide earnings unaffected. Alternatively, companies may lower book earnings via specific items such as goodwill write-downs, restructuring charges, or greater equity-based compensation – these can then be added back as non-GAAP / pro-forma disclosures. If investors rely more on non-GAAP earnings, the tax cost of lower GAAP earnings is lower. Regardless, all such tactics reduce the information content of financial accounting earnings and potentially harm capital markets.



## p. 46 – Section 2.2.2: Specific Concerns with Pillar 2

(Much of this discussion based on Hanlon & Nessa (2023) – see that paper for more detail; fn. 20.)

Concern 1 – Compliance, administration and enforcement complexity. Pillar 2 is argued to be "needlessly difficult" because it starts with financial accounting income (not because all new tax rules are inherently complex). Because the OECD does not actually want to tax pure financial accounting income, adjustments are required. The deferred tax system adds a further layer of complexity on top of what already exists for financial accounting.

Concern 2 – Role of financial statement auditors. Materiality thresholds in Pillar 2 appear to be much smaller than what would be material for financial accounting at large MNEs. The OECD states (Article 3, paragraph 12 of the 2022 Commentary): "The financial accounting auditor's acceptance of a deviation [from a strict application of the UPE's accounting standard] without a qualification to the auditor's opinion is good evidence that the difference is immaterial." This potentially thrusts financial statement auditors into a tax enforcement role – a significant institutional concern.



## p. 47 – Section 3: Is There a Better Way Forward?

### 3.1 What Problem Are We Trying to Solve?

Two problems the OECD states Pillar 2 will address: (1) income shifting and (2) tax competition. Hanlon focuses on income shifting; she is "not clear" that tax competition is a problem per se.

Estimates of income shifting:

OECD definition of BEPS: tax planning strategies that "exploit gaps and mismatches in tax rules to artificially shift profits to locations with no/low tax rates and no/little economic activity," resulting in revenue losses of "at least 100–240 billion USD, equivalent to 4–10% of global corporate income tax revenue" (fn. 24 refers to OECD BEPS Inclusive Framework flyer).

Clausing (2020b): US MNEs shifted ~$100 billion in 2017 using BEA data. Blouin & Robinson (2022) re-examine this data and argue there is "double counting" of lower-tier subsidiary earnings, so actual estimates are much smaller. Clausing (2020b) contests this using multiple data sources. Clausing (2020a) finds that as of end of 2019, there was "no evidence of a reduction in profit shifting or a change in the location of US MNC profits" after TCJA.

Dyreng & Hanlon (2021) conduct back-of-the-envelope calculations using financial statement data and conclude many prior estimates are "implausibly high." Key example: Wright & Zucman (2018) estimate 60% of foreign income (~$250 billion) was recognised in tax havens. If correct, the remaining 40% would have been taxed at roughly 59% to account for actual foreign current tax expense recorded by companies – which Dyreng & Hanlon argue is implausible. Dyreng, Hills & Markle (2022) provide more rigorous evidence that estimates by Clausing, Zucman and others are likely too high, and that income shifting is "concentrated in a small number of firms."

Conclusion: No consensus on the magnitude or breadth of income shifting. This makes it difficult to assess whether the compliance costs, administration burden, and risks to financial accounting quality are justified.

Additional considerations: BEPS 1.0 action items were finalised in 2015; their effects have not been fully understood yet. TCJA (2018) already mitigated US-based incentives to shift income: statutory rate cut from 35% to 21%; FDII regime; 100% participation exemption on foreign earnings; GILTI regime which taxes a return on foreign tangible assets (QBAI = Qualified Business Asset Investment) as a proxy for non-shifted income. Hanlon notes there has not been sufficient time to evaluate TCJA's effects fully.



## p. 48 – Section 3.2: Alternative Solutions

### 3.2.1 Eliminate Financial Accounting Income from Pillar 2

If maintaining a country-by-country minimum tax is desired, Hanlon's primary recommendation is to start with taxable income per jurisdiction, with specific adjustments to disallow certain deductions and credits (fn. 29 notes the OECD need not be the authority making these determinations). Advantages:

- Tax base is transparent, not a "black-box" (fn. 30: Kim Clausing, former US Treasury Assistant Secretary for Tax Policy, called the US CAMT base "mysterious")
- Eliminates complexities arising from book-tax differences: consolidation rule differences, mark-to-market / fair value accounting differences, acquisition method accounting (including goodwill post-acquisition)
- For most companies, no separate deferred tax system for Pillar 2 would be required
- Forces policymakers to explicitly specify the tax base
- Eliminates the overriding concern about harming financial accounting quality and capital market efficiency

Fn. 31 notes this approach was considered in the early OECD Programme of Work (May 2019, Annex B, paragraph 19 of the November–December 2019 public consultation document), but was set aside because of concerns that each subsidiary would need to recalculate income under the parent jurisdiction's tax base rules, possibly causing highly taxed subsidiaries to appear low-taxed for technical reasons. Hanlon argues it is "not clear that these challenges are less than those that arise from using financial accounting income."

Returning to Table 1, columns 4–6: Starting with taxable income in the example yields the same total top-up tax over 10 years as starting with book income plus deferred tax adjustment (column 4 = column 2 = $1,450 over 10 years), but column 4 requires no deferred tax system. Column 5 (allowing full tax depreciation in the excess profit base) reduces the top-up tax in year 1 to $100 (vs $145 under column 2) because the income base is lower.

Key observation: "it is not clear to me, if one considers all the various complexities of the two alternatives, that the alternative of starting with taxable income is more complicated than starting with financial accounting income." Reasons: (i) financial accounting standards are not identical across jurisdictions; (ii) there is more discretion within the same standards across companies; (iii) many complexities of using book income, including the required deferred tax system, are still unknown in practice.

### 3.2.2 Replace Pillar 2 with a GILTI-Type Provision

Why not implement something equivalent to GILTI (Global Intangible Low-Taxed Income) or existing CFC regimes? GILTI rules: not perfect (e.g. expense allocation rules are "likely too harsh"), but accomplish the goal of taxing low-taxed foreign earnings without using financial accounting as the starting point – "which makes them much more attractive and straightforward." UK, Germany and others have CFC rules preventing complete income shifting to tax havens. If all countries agreed to adopt a provision taxing low-taxed home-jurisdiction earnings, tax havens could respond by raising their own statutory rates. Hanlon views this as "far simpler" than Pillar 2 and "probably just as effective, or at least effective enough." Notes the analogy to crime mitigation: cannot target zero income shifting without excessive cost.



## p. 50 – Section 3.2.3: A More Complete Overhaul

Destination-Based Cash-Flow Tax (DBCFT): Hanlon briefly raises the DBCFT as a more fundamental alternative. She notes it was "potentially not appropriately named" (fn. 33: not clear whether the originators meant pure cash flows or an accrual-based system as in current tax). Could potentially accomplish goals of both Pillar 1 and Pillar 2. The outstanding unresolved questions include currency valuation effects and pricing impacts. Not developed further due to scope limitations.



## p. 51 – Section 4: Conclusions

Hanlon's overall conclusion: "using financial accounting income as the base of a minimum tax is a mistake." It creates complexity for both taxpayers and tax authorities, and – more importantly – risks lowering the quality of financial accounting earnings and thereby harming capital market efficiency. Several viable alternatives exist that do not rely on financial accounting income and appear at least as attractive as the current Pillar 2 proposal. Hanlon acknowledges identification difficulties in testing the economic consequences of Pillar 2 empirically, but looks forward to research on those consequences.



## Key References for Further Reading

- Hanlon & Nessa (2023), National Tax Journal – detailed companion paper on the use of financial accounting information in BEPS 2.0 (including more detailed examples of deferred tax under Pillar 2)
- Dyreng & Hanlon (2021) – on tax avoidance and MNE behaviour, including back-of-the-envelope tests of income-shifting estimates
- Dyreng, Hills & Markle (2022) – income shifting concentrated in small number of firms; prior estimates likely too high
- Clausing (2020a, 2020b) – profit shifting estimates using BEA data
- Blouin & Robinson (2022) – "double counting" critique of Clausing's estimates
- Wright & Zucman (2018) – tax haven income estimates
- Faulhaber (2023) – Pillar 2's built-in escape hatch (National Tax Journal)
- Devereux, Vella & Wardell-Burrus (2022) – Pillar 2: rule order, incentives, and tax competition
- Herzfeld (2022) – on the QDMTT (Tax Notes Today International)
- Hanlon (2021), The Accounting Review – on the weakening of financial accounting from tax reforms (earlier version of the core argument)
- Hanlon & Shevlin (2005); Hanlon, Maydew & Shevlin (2008); Atwood, Drake & Myers (2010) – book-tax conformity and earnings informativeness