# Tørsløv, Wier & Zucman (2023) "The Missing Profits of Nations"
Review of Economic Studies, 90(3), 1499–1534

> Paper is close to in line with the 2020 version. Prefer to cite Torslov 2023 (this one) than the 2020 version, since that was a working paper! Although my notes for the 2020 version are better. 


## Abstract / Key findings up front

- Using new macroeconomic data ("foreign affiliates statistics"), foreign affiliates of multinational firms are "an order of magnitude more profitable than local firms" in low-tax countries.
- Estimate: 36% of multinational profits are shifted to tax havens globally (year of study: 2015).
- US multinationals shift twice as much profit as other multinationals relative to the size of their foreign earnings.
- If shifted profits were reallocated to source countries: domestic profits would increase by ~20% in high-tax EU countries, ~10% in the US, and ~5% in developing countries; profits in tax havens would fall by 55%.
- New international database of GDP, trade balances, and factor shares corrected for profit shifting is provided.
- Key macro implication: the corporate capital share has increased not only in North America but also in high-tax European countries once corrected for profit shifting. Capital's rise is "obscured by the tax avoidance strategies of multinational companies."

## p. 1499 - Introduction

Context: Global average statutory corporate tax rate fell by about half between 1985 and 2018 (from 49% to 24%). One driver is international tax competition.

Gap in literature: Despite prominence of profit shifting in academic and public debate, "we do not currently have comprehensive estimates of the amount of profit shifted from one country to another."

New data used: Foreign affiliates statistics (FATS), released since early 2010s by statistical institutes of most developed countries including major tax havens. These record wages and profits of foreign firms (defined as firms more than 50% owned by foreign shareholders, typically subsidiaries of foreign multinationals).

Basic method in brief: Combine FATS with national accounts data (covering all firms) to estimate profitability of foreign vs. local firms within each tax haven. "This exercise reveals that foreign firms are much more profitable than local firms in tax havens." Then use new bilateral balance of payments data to re-allocate shifted profits to source countries or parent countries.

What the global/bilateral approach adds:
- Can estimate comprehensive profit losses for individual countries (not just from domestic multinationals but all multinationals operating there)
- Compare profit losses across developed vs. developing economies and contrast with gains of tax havens
- Compare profit-shifting intensity of multinationals headquartered in different countries (US vs. EU etc.)
- Generate bilateral estimates (e.g. amount shifted from France to Luxembourg, or Germany to the Netherlands)
- Can address whether profits shifted to EU havens end up staying there or are further shifted to non-EU havens (EU treaties restrict some anti-avoidance rules for intra-EU payments)

Main findings summary:
- 36% of multinational profits shifted to tax havens globally in 2015 (preferred estimate)
- US firms shifted more than half of their multinational profits; other multinationals shifted about a quarter
- High-tax EU countries are "the prime losers," with domestic profit reduction of ~20%, vs. 10% in US and 5% in developing countries
- On an immediate counterpart basis, most EU profit shifting goes to EU havens (Luxembourg, Netherlands), but about half ultimately ends up in non-EU offshore centres (e.g. Bermuda)
- "A key pattern that emerges from our analysis is large profit shifting out of EU high-tax countries, often by US multinationals, first to European tax havens such as Luxembourg or the Netherlands, then eventually to non-EU offshore centres such as Bermuda."
- Tax havens derive sizable benefits: by taxing large amounts of attracted profits at low rates, they generate more tax revenue as a fraction of national income than higher-rate countries

Macro implications:
- Flip side: output, net exports, and profits recorded in non-haven countries are understated
- Adding back shifted profits increases corporate capital share significantly, especially in EU
- Corrected data suggest the rise of the capital share is more widespread than official statistics indicate: "after correcting for profit shifting, the capital share of corporate value added rose by about 4 points in high-tax EU countries over the 1985-2015 period"
- Supports theories about global technological and economic trends (declining relative prices of capital, capital-biased technical change, superstar firms, capital accumulation) rather than country-specific shocks

Structure of the paper: Section 2 relates to literature; Section 3 methodology; Section 4 data; Section 5 estimates of profits shifted; Section 6 geography of global profits; Section 7 corrected factor shares; Section 8 conclusion. Supplementary Appendix and Replication Guide available.



## p. 1500-1501 - Related Literature

### 2.1 Microeconometric estimates of profit shifting

Standard micro approach: run regressions of form log(profit_ic) = alpha + beta*(tax_parent - tax_country) + controls. A positive estimated beta is interpreted as evidence of profit shifting. OECD (2015) uses this methodology for its official BEPS estimate (Johansson et al., 2017).

Advantage of the macro approach in this paper over Orbis-based micro approach:
- Orbis relies on public business registries which often don't exist (e.g. Bermuda) or contain no income information (e.g. US and Switzerland)
- "In 2012, only 17% of the global profits of multinationals could be traced in Orbis. That is, 83% were booked in subsidiaries unknown to Orbis, or for which no profits data were available."
- Example: Orbis correctly reports Apple's consolidated global profits at 55.3 billion euros in 2016, but adding up all Orbis subsidiary-level data yields only 2.0 billion euros -- "None of the profits made by Apple in the US or in tax havens are visible."
- See Figure 1 in the paper for density plot of fraction of global profits traceable in Orbis.

Bilicka (2019) as reference point: using tax data (more comprehensive than accounting data), found foreign multinationals shifted about 50% of profits out of the UK during 2000-14. TWZ's findings (36% globally, 43% upper bound) are consistent with this order of magnitude.

### 2.2 Macroeconomic estimates of profit shifting

Most macro literature uses US statistics and focuses on US multinationals (Clausing, 2009, 2016; Wright & Zucman, 2018; Guvenen et al., 2021). TWZ take a global perspective.

Consistency check with Guvenen et al. (2021): that study estimates $158.3bn shifted by US multinationals out of the US in 2015 plus $3.5bn by 127 tech-intensive non-US multinationals. TWZ estimate $143bn shifted out of the US by US plus non-US multinationals -- broadly consistent (difference of 0.1% of US GDP).

Other global macro studies:
- Crivelli, de Mooij & Keen (2015): infer revenue losses from correlation between corporate tax revenue and statutory tax rates of other countries in panel model
- Bolwijn, Casella & Rigo (2018): rely on FDI statistics of non-haven countries
- Neither uses FATS or differential profitability of foreign vs. local firms in tax havens

TWZ advantage: produces estimates trackable annually; bilateral BoP data allow bilateral profit-shifting estimates (key input to calibrate quantitative models of multinational production)

TWZ global estimate ($616bn shifted in preferred scenario, 2015) is comparable to Bolwijn et al. ($700bn in 2012). Detailed comparison in Supplementary Appendix C.



## p. 1501-1505 - Conceptual Framework and Methodology (Section 3)

### 3.1 Profitability ratios

Definition of profitability: profits-to-wage ratio (pi). Corporate output Y = rK + wL. Pre-tax corporate profits defined as (1-p)*rK, where p is net interest paid as share of operating surplus rK. Net interest subtracted because interest payments are typically tax-deductible, while interest received (e.g. by banks) is taxable. Capital depreciation also subtracted since deductible from taxable profits. So Y, alpha, r, and pi are all net of capital depreciation.

Formula: pi = (1-p) * alpha / (1-alpha), where alpha = rK/Y (capital share of corporate output)

Note: "wage" throughout always refers to employee compensation in national accounts (SNA code D.1), including non-wage compensation such as retirement benefits, health benefits, payroll taxes.

For foreign firms (pi_f) and local firms (pi_l): defined analogously. Foreign firms = firms where foreign investors own more than 50% of shares with voting rights. Local firms = all firms incorporated in country i that are not classified as foreign, including domestic multinationals (e.g. Siemens in Germany) and purely domestic companies. By definition: pi = s*pi_f + (1-s)*pi_l where s = share of wages paid by foreign firms.

Three forms of profit shifting (per Heckemeyer & Overesch, 2017):
- Transfer price manipulation: subsidiaries in high-tax countries export goods/services to related low-tax firms at low prices and import at high prices. Increases recorded pi_f in tax havens.
- Intra-group interest payments (see Huizinga, Laeven & Nicodeme, 2008): affiliates in high-tax countries borrow from affiliates in low-tax countries at potentially high interest rates. Increases pi_f in tax havens.
- Strategic relocation of intangibles (trademarks, patents, logos, algorithms, financial portfolios) from high-tax to low-tax countries; then royalties/interest/payments charged to high-tax subsidiaries.

### 3.1.3 Definition of tax havens

41 countries and territories classified as tax havens: 5 OECD (Belgium, Ireland, Luxembourg, Netherlands, Switzerland) and 36 non-OECD. List based on Hines & Rice (1994), with additions of Netherlands, Belgium, and Puerto Rico.

Netherlands: not in Hines & Rice (1994) because US multinationals reported high tax rates there in 1982, but effective tax rate had fallen to 12% by 2015.

Belgium: borderline case -- conduit country with large cross-border flows conducive of profit shifting; effective tax rate of 19% (same as world average in 2015). Accounts for 2% of global baseline estimate; excluding it would not significantly change results.

Puerto Rico: US territory not subject to US federal corporate income tax. Not part of US for GDP statistics. Profit shifting to Puerto Rico reduces officially measured US GDP and capital share, just as shifting to Bermuda does. Relevant to include separately for purposes of correcting GDP and capital share measurement.

Figure 2 in paper: plots pi_f - pi_l against effective corporate income tax rate for all countries. Tax havens (red) have both low effective tax rates (below 15% in most cases) and pi_f >> pi_l. Non-havens (black) have pi_f <= pi_l. A few borderline non-haven cases (blue) have pi_f slightly above pi_l but including them would not materially affect results.

### 3.2 Inferring profit shifting: baseline assumptions

Baseline procedure: set pi_f equal to observed pi_l in each tax haven to compute what aggregate profits foreign firms would make if they were as profitable as local firms. The excess (observed pi_f minus pi_l) is attributed to profit shifting.

Three assumptions needed for this to be valid:
- Assumption 1: Elasticity of substitution between capital and labour (sigma) = 1 (Cobb-Douglas). Under sigma = 1, capital intensity differences between local and foreign firms do not affect the capital share -- "any increase in the capital stock is perfectly offset by a corresponding fall in the marginal product of capital." If sigma > 1: firms with high capital intensity have high pi; if sigma < 1: firms with high capital intensity have low pi.
- Assumption 2: Same degree of competition for foreign and local firms within countries. Does not require perfect competition; allows for rents from financial secrecy or lax regulation, but requires that such rents affect both local and foreign firms equally. Does not assume same degree of competition across countries.
- Assumption 3: No inward profit shifting in local sector of tax havens. Local haven firms include domestic multinationals headquartered in tax havens that might shift profits inward. Baseline assumes negligible effect on pi_l. Ideally, local firms without foreign affiliates would be the reference group, but existing FATS do not decompose local firms this way.

### 3.3 Validation test of baseline methodology

Applied to US multinationals using BEA outward FATS (available annually since 1982, benchmark surveys every 5 years; country x industry data available since 1994).

Regression model estimated (equation 4 in paper):
pi_cti = alpha_t + beta1_t * ln(K_cti) + beta2_t * ln(RD_cti) + gamma_t * X_ct + delta_t * Haven + epsilon_cti

where X_ct = GDP (PPP) and population; Haven dummy for being in list of tax havens; all regressions weighted by compensation of employees.

Key results (Figure 3 in paper):
- Raw series: in 2015, profits-to-wage ratio of haven affiliates = 346%, vs. 46% for non-haven affiliates. In the 1960s and 1970s, both were the same. Since then, haven affiliates' profitability has surged while non-haven has flatlined.
- After controls (capital stocks, R&D, industry fixed effects, country characteristics): excess profitability of haven affiliates remains. Cannot be explained by capital intensity, R&D, productivity, or industry composition.
- "Profit shifting is not limited to just a few sectors of the economy, such as information and communication technology: it appears to be an across-the-board phenomenon."
- R&D control: only 8% of R&D workers of US multinational affiliates were in tax havens in 2014; 92% in non-haven countries. "The high profitability of haven affiliates cannot be explained by local R&D, which by and large is conducted in high-tax countries."
- In 2015 (or 2014 benchmark year): haven profitability statistically different from non-haven in all specifications. Note: before 2014, standard errors are larger. Caveat: due to country aggregation in BEA tabulations, Haven dummy equals 1 for only seven countries/regions; statistical testing thus on only seven observations.

### 3.4 How shifted profits are allocated

3.4.1 Allocation to source countries -- three steps:
1. Define "high-risk service exports" (x) as exports of: rights to use intellectual property (patents and trademarks), headquarter services (administration, management, advertising), ICT services, and financial and insurance services (Hebous & Johannesen, 2021). Goods exports disregarded as less important per literature (see Supplementary Appendix C).
2. Compute excess high-risk exports (x-bar_ij) from haven i to country j = difference between recorded and predicted value, where predicted exports are projected based on haven's gross national income.
3. Compute excess intra-group interest (g-bar_ij) received by haven i from country j. Excess cross-border transactions t_ij = x-bar_ij + g-bar_ij. Shifted profits in haven i allocated to source countries j proportionally to t_ij.

Note: summing t_ij across destination countries j for a given haven gives an independent estimate of profits shifted into that haven (compared to baseline excess profitability estimate). These two independent estimates "line up well at the haven level" (Section 5.1).

This approach is consistent with how policymakers perceive profit shifting (many countries have anti-avoidance policies targeting specific cross-border transactions). Does not apply an apportionment formula; keeps subsidiary-by-subsidiary accounting and arm's length pricing, and considers how geography of profits would change if incentives to shift disappeared (e.g. if all countries had same effective tax rate). Not a counterfactual for perfect tax harmonisation since that would generate endogenous responses.

3.4.2 Allocation to parent countries: tracks where ultimate parents of haven subsidiaries are incorporated, using bilateral direct investment statistics on an ultimate ownership basis (Damgaard & Elkjaer, 2017). This allows assessing whether US multinationals make more extensive use of tax havens than EU multinationals. Also allows estimating revenue potential of minimum tax collected by each parent country on profits booked by its multinationals in tax havens -- directly relevant to the GMT agreement reached by 130+ countries in June 2021 (OECD, 2021).



## p. 1505-1510 - Data Sources and Global Summary Statistics (Section 4)

### 4.1 National accounts data

Source: OECD's detailed national accounts by sector (Table 14A). Covers all OECD countries (including key tax havens: Ireland, Luxembourg, Netherlands, Belgium, Switzerland) and some developing non-OECD countries (Brazil, China, Colombia, Costa Rica, India, Russia, South Africa). Non-OECD tax havens (Singapore, Hong Kong, Puerto Rico) extended by manually collecting official national accounts from their statistical institutes and central banks.

Data provides: corporate operating surplus rK, net interest payments p, wages wL for both financial and non-financial corporations, in benchmark year 2015.

Some adjustments:
- Countries providing only gross-of-depreciation operating surplus: depreciation imputed based on average rates in OECD and non-OECD countries separately (~15% of corporate gross value-added with little variation across countries).
- Australia, Canada, Iceland, Japan, Egypt, Indonesia do not isolate corporate sector: share of wages paid by corporations imputed based on average shares.

### 4.2 Foreign affiliates statistics (FATS)

Sources: Eurostat, OECD, and national statistical agencies. Based on exhaustive or quasi-exhaustive census-type surveys of multinational enterprises.

Inward FATS of country X: record value-added Y, operating surplus rK, compensation of employees wL of foreign firms operating in X, tabulated by country of foreign parent.

Outward FATS of country X: same statistics for affiliates of X's multinationals operating abroad, tabulated by country of affiliate.

Key difference from direct investment income statistics: FATS are tabulated by country of affiliate's primary activity, not by country of immediate counterpart. Example: if French parent owns German affiliate through Luxembourg holding, FATS record profits as made in Germany; BoP records income from Luxembourg. This makes FATS better suited for tracking where economic activity occurs.

pi_l computed as residual: since pi = s*pi_f + (1-s)*pi_l, once pi (from national accounts) and pi_f (from inward FATS) are known, pi_l can be computed. Variables in FATS are defined and constructed just like in national accounts (Eurostat, 2012). Validated by checking that resulting labour share in local sector is consistent with available estimates (Karabarbounis & Neiman, 2014; Cette et al., 2019; Gutiérrez & Piton, 2020).

4.2.1 Double-counting issue (Blouin & Robinson, 2019): "Net income" as reported in BEA Income Statement tables (D1-D13) double-counts income of US affiliates going through chains of holding companies. However, TWZ use BEA Value Added Tables (F1-F9), which report "profit-type return" (pre-tax profit that does not count equity income received as profit). The internationally compiled FATS used in this article are analogous: pre-tax profit excludes equity income received and does not double-count profits.

4.2.2 Imputations for missing countries: for countries not publishing FATS (smaller non-OECD havens: Bermuda, Cayman Islands, Hong Kong), profits and wages of foreign firms are imputed in two steps:
- Pre-tax profits: estimated using inward direct investment income from BoP statistics (available for almost all countries/territories via IMF). Direct investment income = net-of-depreciation, net-of-corporate income tax profits of firms more than 10% owned by foreign investors, prorated by ownership. FATS pre-tax profit = net-of-depreciation, gross-of-corporate income tax profit of firms more than 50% owned by foreign investors, no pro-rating. Wright & Zucman (2018) show both line up closely in the US case. When inward DI income reported by tax havens is lower than mirror outward income from OECD/EU countries, haven data corrected to match partner data. Example: Cayman Islands excludes offshore sector from BoP; replaced by mirror outward data from OECD and EU.
- Wages: estimated by applying wage/profit ratio from outward FATS of counterpart countries (primarily US outward FATS, which provide data on small havens like Barbados, Bermuda, Panama individually).

4.2.3 Bilateral discrepancies: inward FATS of European tax havens (especially Ireland, Netherlands, Luxembourg) record less profit by US affiliates than mirror US outward FATS. Similar gap in bilateral BoP data.

Two possible explanations: (a) European havens underestimate profits due to special purpose entities, non-response, or other data issues (Angulo & Hierro, 2017; Damgaard & Elkjaer, 2017); (b) US may overestimate profits in European havens (CSO, 2016). Authors investigate by comparing US outward investments in non-havens to non-haven inward investments from the US: these match, suggesting US data are generally reliable. Therefore, in central scenario, inward data of tax havens are upgraded to match counterpart outward data reported by US.

This also resolves a global statistical issue: taking haven data at face value creates a ~$200bn imbalance in global direct investment income recorded in world BoP (IMF, 2015), primarily from missing profits of US affiliates in inward statistics (see Replication Guide Section B).

4.2.4 Summary statistics (Table 1 in paper):
- 2015 global GDP: $75 trillion; net global output (after depreciation): $63 trillion
- ~54% of global net value-added produced by corporations
- Corporate capital share of net value-added: ~1/3; labour share: ~2/3
- Total net-of-depreciation corporate profits: $11.5 trillion
- Of this, ~15% ($1.7 trillion) made in foreign firms -- this is what TWZ call "multinational profits" (includes all profits by e.g. Apple in France, Germany, Ireland, Jersey, etc., but NOT Apple's US profits)
- Estimate: 36% (~$600bn) of the $1.7 trillion in multinational profits shifted to tax havens

### 4.3 Bilateral balances of payments

Source: IMF and Eurostat bilateral BoP. Since adoption of 6th edition IMF (2009) Balance of Payments Manual, most countries publish bilateral BoP including bilateral service trade flows by type of service, and bilateral FDI income (including bilateral intra-group interest payments and receipts).

When two estimates of same haven-to-non-haven flow available: TWZ use statistics reported by tax havens, as these "tend to be more comprehensive than those recorded by counterpart countries."

Service exports from 6 EU tax havens to 22 non-haven EU countries exceed recorded imports by more than 30%. Likely explanation: digital services multinationals incorporate IP in tax haven subsidiaries and sell directly to foreign customers without involving non-haven subsidiaries. "There is evidence that the typical business structure of digital services multinationals involves shifting intellectual property to tax haven subsidiaries and then directly selling services to final customers without involving any non-haven subsidiary." Associated service flows better captured in tax havens' trade statistics than in customer countries' statistics. Looking forward, systematic use of VAT returns could help fix this imports/exports service mismatch.



## p. 1510-1515 - Estimates of Profits Shifted to Tax Havens (Section 5)

### 5.1 Baseline estimates

5.1.1 Profitability in local vs. foreign firms (Figure 4 in paper):

Key finding: "foreign firms in tax havens are an order of magnitude more profitable than local firms in tax havens."

Specific examples in 2015:
- Ireland: pi_f = 800% (for $1 of wage paid to Irish employees, foreign multinationals book $8 in pre-tax profits). Note in paper states this corresponds to a capital share of corporate value-added of 80-90% for foreign firms, vs. ~25% in local Irish firms.
- Puerto Rico: pi_f = 1,625%
- Overall: foreign firms in havens have profits-to-wage ratio 8 times larger than local firms in havens (foreign = 277%, local = 34% unweighted)

In high-tax countries, the opposite: foreign firms slightly less profitable than local firms. Example: UK, pi_f = 26% vs. pi_l = 48%. Note: lower profitability of foreign firms in UK by factor ~2 is consistent with Bilicka (2019) finding that foreign multinational subsidiaries under-report taxable profits by about 50% relative to domestic standalone. Inferring outward profit shifting from this gap in high-tax countries is difficult because both local and foreign firms can shift profits out.

Second result: local firms in tax havens are generally as profitable as local firms in non-haven countries. They do not appear abnormally profitable, which would be the case if pi_l was inflated by inward profit shifting. This supports Assumption 3.

5.1.2 Profits shifted into each haven (Table 2 in paper, Column 1, baseline):

Top destinations in 2015 ($ billions):
- Ireland: $106bn (number one destination)
- Netherlands: $57bn
- Switzerland: $58bn
- Caribbean tax havens (aggregate): $97bn
- Singapore: $70bn
- Luxembourg: $47bn
- Puerto Rico: $42bn
- Hong Kong: $39bn
- Bermuda (within Caribbean aggregate): $24bn
- Total: $616bn

Alternative "excess cross-border transactions" methodology (Column 2): based on excess service exports and intra-group interest in BoP data. Independent data, but results consistent: global total $646bn (slightly higher than baseline because this method also captures shifting by multinationals headquartered in havens). At haven level, estimates line up well.

Additional results:
- High pi_f in tax havens is driven by high recorded capital shares, not by net interest. Main exception: Luxembourg, where intra-group interest receipts are the key driver. Overall, 15% of estimated shifted profits comes from interest; 85% from transfer pricing and strategic location of intangibles. Consistent with literature (Heckemeyer & Overesch, 2017) that debt-shifting is "second-order relative to transfer pricing and the strategic location of intangibles."
- For US affiliates: haven affiliates receive only 1.1 times more interest (relative to operating surplus) than non-haven affiliates in 2015.
- If profit shifting ended, profits booked in tax havens would fall by 55%; by as much as 90% in Malta and Bermuda.

### 5.2 Bounding the amounts of shifted profits

Four margins of uncertainty: (1) true profitability differences unrelated to profit shifting; (2) elasticity of substitution sigma; (3) inward shifting in local sector; (4) bilateral discrepancies in investment statistics.

5.2.1 True profitability differences between foreign and local haven firms:

Building on Paul & Isaka (2019) on firm-level determinants of factor shares globally:
- Foreign ownership associated with 2pp increase in capital share -> implied increase in pi of 4pp (starting from global average capital share of 34%)
- Moving from bottom to top of firm size distribution: additional 24pp increase in pi
- 50% rise in TFP: additional 17pp increase in pi
- Total combined additive effect: 4+24+17 = 45pp

Column 3 of Table 2: effect of increasing benchmark profitability of foreign haven firms (absent profit shifting) by 45pp. This is roughly equivalent to doubling pi_l in tax havens. Negligible effect in havens like Puerto Rico where pi_f is enormous; more significant in Belgium and Netherlands where pi_f is only marginally above pi_l.

5.2.2 Elasticity of substitution sigma different from 1:

Two values tested:
- sigma = 0.7 (US manufacturing aggregate elasticity, Oberfield & Raval, 2021): baseline estimate increases by 7%
- sigma = 1.3 (average macro elasticity, Karabarbounis & Neiman, 2014): baseline estimate reduced by 5%

Figure 5 in paper (top panel): tangible capital stocks in foreign vs. local firms in main havens. Foreign firms have relatively high capital stock in Ireland and Puerto Rico, relatively low in Luxembourg, Switzerland, Hong Kong. Differences are small relative to large profitability differences.

Bottom panel: even if local firms were as capital intensive as foreign firms, with sigma = 1.3, pi_l in Ireland would be 100% instead of observed 68% -- "still almost an order of magnitude less than the observed pi_f of 800%." Capital intensity differences cannot explain more than 10% of excess profitability, even under conservative assumptions.

5.2.3 Inward shifting in local sectors of tax havens:

Identify all listed multinationals headquartered in tax havens using Compustat Global. About 8% of ~30,000 listed firms globally headquartered in havens in 2015; these made $212bn in pre-tax income. If they shifted 36% of global profits inward: baseline understates global profit shifting by $76bn (12%). Effect significant for Hong Kong (~half of haven multinationals), and to lesser extent Singapore and Netherlands.

Alternative approaches have more modest impacts:
- If local firms in havens assumed as profitable as OECD average (pi_l = 41%): global estimate rises 3% only
- Difference between excess transactions and excess profitability methods suggests ~5% of global profit shifting missed from haven-headquartered multinationals

5.2.4 Effect of bilateral discrepancies:

Taking haven data at face value (instead of upgrading to match US outward data): reduces preferred estimate of global profit shifting by 18%, with larger effects in Caribbean and Bermuda. Authors consider this correction necessary because in some cases it is clear haven data are incomplete (e.g. Cayman Islands excludes large offshore sector from BoP).

5.2.5 Lower and upper bounds (Columns 8 and 9 of Table 2):

Lower bound: 45pp higher benchmark profitability + sigma = 1.3 + no corrections to haven data.
Upper bound: sigma = 0.7 + allow for inward shifting in local sector of tax havens.

Result: preferred estimate = 36% of multinational profits shifted (globally $616bn), lower bound = 22%, upper bound = 43%.



## p. 1515-1521 - The International Redistribution of Corporate Profits (Section 6)

### 6.1 Allocating the shifted profits

6.1.1 Profit losses in source countries (Table 3 in paper):

Absolute amounts:
- US: $143bn shifted out (23% of global total)
- EU: $216bn shifted out (36% of global total)
- Other OECD: $76bn (12%)
- Non-OECD: remaining 29%
- More than 70% of profit losses originate from high-income countries

As fraction of GDP (Column 5 of Table 3):
- EU is most affected: 1.5% of GDP lost
- US: 0.8%
- Other high-income countries: 0.7%
- Developing countries: 0.7%
- Selected country examples: UK 2.1%, Germany 1.6%, Sweden 1.7%, France 1.3%, US 0.8%, Japan 0.2%, China 0.5%

As percentage of reported domestic corporate profits (Column 6):
- Absent profit shifting, corporate profits would be 17% higher in France, 14% higher in UK, 8% higher in US, ~5% higher in main developing countries, only 1% higher in Japan
- Caveat: corporate sector delimitation varies across countries (some include self-employed; problem particularly severe in Germany and Italy per Pionnier & Guidetti, 2015). Corporate profits overstated in Germany and Italy, so ratio of shifted profits to reported profits is downward biased there.

6.1.2 Tax revenue losses in source countries (Column 7 of Table 3):

Method: statutory corporate tax rate applied to amount of profits shifted outward. Checked with forward-looking effective marginal tax rates from Spengel et al. (2019) for EU countries -- delivers similar results. Examples: German effective rate 28.2% vs. statutory 30%; France 38.3% vs. 33.3%; UK 21.5% vs. 20%.

Results:
- EU: corporate tax revenues reduced by 18% due to profit shifting
- US: 14% reduction
- Other OECD: 5% reduction
- Developing countries: 5% reduction
- Within EU: higher-tax countries (France, Germany) have higher losses relative to revenue collected than lower-tax countries (Eastern Europe), consistent with higher rates providing more incentive to shift

Two caveats:
- Countries attempt to tax shifted profits through Controlled Foreign Corporation (CFC) rules. So $1 of shifted profit does not necessarily translate into statutory rate cents of lost revenue.
- With better enforcement, there might be more real responses (mobility of tangible capital). Revenue loss computations keep everything else constant, as standard in tax evasion literature.

Tax havens (Supplementary Appendix B): Malta, Puerto Rico, Ireland, and Luxembourg derive more than half of their corporate income tax revenues from taxes on shifted profits.

6.1.3 Heterogeneity in shifting by parent country:

- About half of globally shifted profits accrue to US parents (50%)
- Slightly more than 25% to EU parents

Key contrast: US shifted $143bn from source countries (23% of global), but half of global profit shifting is by US multinationals. "For the US, profit shifting appears to be a tax-avoidance strategy more than a tax revenue loss. For other economies, it appears to be a revenue loss more than a tax-saving strategy."

US multinationals book 54% of their foreign profits in tax havens. Other multinationals: 27%. "US multinationals appear to shift twice as much profit (relative to the size of their earnings) as EU multinationals, while the European Union appear to lose twice as much profit (relative to GDP) as the US."

Explanation for higher US shifting intensity: specific provisions in US tax code before 2018 and "check-the-box" regulations adopted mid-1990s that facilitated shifting from foreign high-tax countries to tax havens (Wright & Zucman, 2018; Guvenen et al., 2021).

Additional finding from BoP data: about 60% of shifted profits retained in tax havens in 2015 (40% repatriated). For profits shifted by US companies: 72% retained (before 2018 US did not tax repatriated income, unlike most other countries).

### 6.2 The destination of shifted profits

Immediate counterpart basis: 77% of profits shifted out of the EU go to EU tax havens (primarily Ireland, Luxembourg, Netherlands). Profits shifted out of US primarily go to non-EU havens.

But do profits shifted to EU havens stay there? Using bilateral service exports and interest payments data of tax havens, TWZ study ultimate destination by constructing reallocation matrix Omega.

Example (Figure 7 in paper / Sankey diagram): Luxembourg receives $88bn on immediate basis but pays back roughly half to non-EU havens (e.g. Bermuda), only keeping $47bn.

Ultimate destination: while on immediate counterpart basis 77% of profits shifted from EU high-tax countries go to EU havens, on ultimate destination basis 46% end up in non-EU havens.

Policy relevance: EU treaties prohibit member states from taxing payments to other EU countries. A country like Germany can impose taxes on payments to Bermuda but not to Luxembourg. "By shifting profits first to Luxembourg and then to Bermuda, a multinational company can avoid the German anti-avoidance rules." Tax planning strategies like the "double Irish with a Dutch sandwich" and the "green Jersey" involve conduit EU tax havens facilitating shifting to non-EU havens (see Zucman, 2014, for analysis in the case of Google Alphabet). Companies must have minimal real activity in conduit EU havens to circumvent anti-avoidance rules.



## p. 1521-1527 - Implications for Factor Shares (Section 7)

### 7.1 A macroeconomic database corrected for profit shifting (Table 4 in paper)

Adjustment method: add profits shifted through transfer prices and strategic location of intangibles (85% of total) to recorded operating surplus rK of source country. Correct full sequence of economic accounts accordingly (increase value-added Y, GDP, exports, trade balance by same amount). Profits shifted through intra-group interest (15% of total) adjusted in breakdown of operating surplus into corporate profits and net interest payments.

Results for non-haven OECD countries (Table 4, Column 1 and 2):
- Capital share under-estimated by ~2-2.5pp in main EU countries (France +2.1pp, Germany +1.8pp, UK +2.5pp, Sweden +2.2pp)
- Under-estimated by 1.1pp in the US
- Corrections for Germany and Italy are conservative because official data already overstate corporate profits (for reasons noted in Section 3.4). Corrected adjustment for France, Germany, Italy combined = 4.4pp.

Mirror adjustment in tax havens:
- Ireland: capital share over-estimated by 20pp
- Luxembourg: over-estimated by ~12pp
- Puerto Rico: over-estimated by ~38pp

Trade balance corrections: profit shifting affects recorded trade balances (services exports by tax havens inflated; service imports by non-haven countries understated).
- Japan, UK, France, and Greece have trade surpluses in 2015 when corrected, despite recording trade deficits in official data
- True US trade deficit: 2.1% of GDP instead of 2.8% in official statistics

### 7.2 Dynamics of the capital share (Figure 8 in paper)

Top panel of Figure 8: aggregate profit-to-wage ratio in Ireland -- dramatic increase starting mid-1980s, from 30% (same level as US and high-tax European countries) up to early 1980s, to 250% in 2015. Especially sharp rise in 2015 due to transfers of multinational intangible assets (what the OECD (2016) called "Irish GDP up by 26.3% in 2015?").

Bottom panel of Figure 8 (Germany, France, Italy average):
- Blue line (Gutiérrez & Piton, 2020): capital share has not increased since 1985 without correction
- Red line (TWZ corrected): adjusted for profit shifting

Method for time series: for each country, fraction of profit shifted in 2015 taken from Column 7 of Table 3 (corporate income tax revenue loss ratio). Evolution over time assumes fraction of EU profits shifted to havens follows evolution of fraction shifted by US multinationals (BEA outward FATS available since early 1980s). Simplified but illustrative.

Result: corporate capital share "is likely to have increased substantially in high-tax European countries too." Preferred scenario: rose by 3.0pp in arithmetic average of Germany, France, and Italy over 1985-2015; upper bound scenario: 3.5pp. For reference, official BEA statistics show (gross-of-depreciation) corporate capital share in US rose 5.8pp between 1985 and 2015.

Interpretation: "After our corrections, the rise of the capital share in Europe becomes closer to the one seen in the US, albeit still not as large." Supports theories highlighting global trends (Karabarbounis & Neiman, 2014 on declining relative price of capital; Acemoglu & Restrepo, 2018 on capital-biased technical change; Autor et al., 2020 on superstar firms; Piketty & Zucman, 2014 on capital accumulation) rather than country-specific shocks.



## p. 1527-1529 - Conclusion (Section 8)

Method summary: foreign affiliates statistics show foreign firms in tax havens much more profitable than local firms. By exploiting differential profitability and bilateral BoP data, estimate how much each haven gains and each OECD country and main emerging economy loses. Preferred estimate: 36% of multinational profits shifted to tax havens in 2015. EU non-haven countries "appear to be the largest losers."

Policy implications:
- Findings can be used to study corporate tax reforms: formulary apportionment (Gordon & Wilson, 1986), destination-based corporate taxes (Auerbach, 2010), minimum country-by-country corporate taxes (OECD, 2021)
- Bilateral profit-shifting estimates are necessary input to calibrate structural models of multinational production
- Can evaluate policy efforts: estimates are for 2015 and planned to be updated annually, making it possible to assess effects of OECD BEPS initiative (started 2016), US Tax Cuts and Jobs Act (December 2017), and global minimum tax agreement (OECD, 2021)
- Updated estimates for 2016, 2017, and 2018 available in Tørsløv, Wier & Zucman (2021) at missingprofits.world

Statistical gaps uncovered:
- National statistical authorities need to be authorised to exchange micro-data to solve asymmetries in bilateral FATS and direct investment statistics
- FATS need to be compiled by more countries and expanded (interest payments, corporate taxes paid, capital stocks -- as US already does)
- Some Caribbean tax havens do not publish comprehensive enough national accounts
- US and some tax havens could improve public corporate registries so all firms are included and profit information is publicly available at subsidiary level

Future research agenda proposed by authors:
- Introduce inequality dimension: quantify how much various income and wealth groups in each country gain or lose from profit shifting. About half of globally shifted profits accrue to shareholders of US multinationals; "because equity ownership is concentrated (see e.g. Saez & Zucman, 2016), profit shifting reduces the effective tax rate of the wealthy, which may contribute to increasing inequality."
- Full macro-distributional analysis of globalisation raises "major conceptual and empirical challenges."

