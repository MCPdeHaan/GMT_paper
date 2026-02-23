# Van 't Riet & Lejour (2025) — "Developing Countries, Treaty Shopping and the GMT"
Public Finance Review, 53(6), 671–732

p. 672
Developing countries do not have a higher chance of revenue losses. But some countries are very vulnerable for withholding tax revenue by treaty shopping. 

p.672 and 673

Double tax treaties (more then 3000): prevent double taxation, but also create opportunites for MNEs to treaty shop (routing income through intermediate jurisdictions (conduit countries) to access reduced withholding tax (WHT) rates that would not be available directly.)

Reason for international coordination for tax avoidance (G20/OECD BEPS): budget concerns of national governments, developing countries might be more vulnerable. Therefore, focus of this paper on low- and middle-income countries (LMICs) by consiedering tax system as international network. 

Findings

1. Average Losses: Contrary to some expectations, developing countries are, on average, *less* likely to suffer from tax revenue losses due to treaty shopping than developed countries. This is largely because their standard WHT rates are already lower, leaving less room for reduction.
2. Specific Vulnerability: The average masks significant heterogeneity. Specific countries, such as Bangladesh, Egypt, Indonesia, Kenya, Uganda, and Zambia, are vulnerable to substantial potential losses of WHT revenue.
3. Aggressive Treaties: The vulnerability of these specific countries usually stems from a small number of "potentially aggressive" tax treaties with conduit jurisdictions like the Netherlands, Switzerland, the UAE, and Singapore.
4. GMT Paradox: The Global Minimum Tax may lead to a transfer of tax revenue from developing countries to developed treaty partners if the former do not implement specific domestic top-up taxes (QDMTTs).

## Methodology: Network Analysis (Pages 677-687)

The authors model the international tax system as a transportation network where MNEs seek the "shortest path" (lowest tax cost) to repatriate profits, since treaty shopping is anlysed = thus see international tax system as transportation network. MNEs reduce taxes on "repatriated income" by choosing cheapest route over network. 

Subsidiary = $S$, parent = $P$, tax cost = $t_{S,P}$ that consists of WHT of S and/or CIT in P. Alternative: income is routed through Conduit Country (C1), then the tax rate is $t_{S, CI, P}$, this rate could be lower than directly due to double tax treaty with lower WHT rate between S and CI. And maybe even a second conduit country (C2) is advantageous for MNE when that would lead to even lower tax rate. Thus, to conclude, there are more than one route (for 100+ countries, there are SO MANY routes). routes can be direct and indirect. 

Central assumption is that MNEs structure their financing so that the tax minimising routes will be used. 

"treaty shopping reduces potential reduction of worldwide average of taxed on repartiated dividends of about 6 percentage points". Countries most used as conduits for dividend repatriation: UK, Luxembourg, Netherlands. 

118 countries included, most high and upper middle income countries. 18 LMICs. 

Data needed: tax parameters from 118 jurisdictions, obtaimed from IBFD supplemented with EY world corporate tax guide. Data from 2018 and - when not availiable - from earlier years. Statutory CIT rate needed, next to standards rates of non-resident WHTs on dividend, interest, royalties, systems for double tax relief. Use reduced WHT rates agreed in treaties (bilateral data), differentiate between reduced rates that apply for all and reduced rates for sectors, for dividends lowest rate taken (since assumed that MNEs would structure so that conditions would be met), if several rates for interest and royalties the second lowest was chosen, since often lowest rate for specific sector. 

Also taken into account: parent subsidiary directive and interest and royalty directive of EU. sicne these say that there is no "withholding taxation between MS".

### The Algorithm

The analysis uses a graph theory algorithm (Dijkstra/Floyd-Warshall) to determine the optimal route for repatriating income from a subsidiary (Source, S) to a parent (Home, P). The route can be direct or indirect via conduit countries (C1, C2). The "tax distance" is calculated based on:

1. Corporate Income Tax (CIT) in the source country.
2. non-resident Withholding Tax (WHT) on the outgoing flow.
3. Taxation in the conduit country (if any).
4. CIT in the residence country, adjusted for double tax relief methods (credit or exemption).

- Dividends: analyse cross-borer profit distribution after taxation in source country
- Interest and royalties: deductible from tax base for CIT in source country. 

Not modelled: "erosion of tax base in source countries that strategic allocation of IP and debt" while this often has a bigger advantage than treaty shopping. 

Three scenarios are compared to estimate revenue loss:

* NOT (No Treaties): Assumes standard statutory WHT rates apply; no bilateral reductions.
* DIR (Direct Routes): MNEs use the bilateral treaty between Source and Home but do not use conduit countries.
* OPT (Optimal Routes): MNEs use the full network to minimise taxes, potentially routing through third countries (treaty shopping).

### The Data and Weighting

The study covers 118 countries (97% of world GDP) using 2018 tax data. The 18 LMICs analysed are: Angola, Bangladesh, Egypt, Ethiopia, Ghana, India, Indonesia, Kenya, Mongolia, Morocco, Nepal, Nigeria, Pakistan, Philippines, Tanzania, Uganda, Vietnam, and Zambia.

To aggregate the results, the authors use:

* Dividends: Double GDP weights (reflecting the economic size of both source and residence countries).
* Interest & Royalties: Alternative weighting. Weights are only positive if the CIT in the source country is higher than in the destination country (), simulating profit-shifting behaviour where debt and IP are located in low-tax jurisdictions.

### Definition of "Potentially Aggressive Tax Treaty"

A central contribution of the paper is the formal definition of an aggressive treaty. A treaty is classified as potentially aggressive if:

1. It is the first step in a tax-minimising route.
2. The product of the *share of total potential tax loss* for the source country and the *share of that specific treaty's responsibility* for the loss exceeds 25%.

Does not take into account that "tax treaties may attract new investment into a country"

## Worldwide Average Results (Pages 687-689)

Before focusing on developing countries, the paper establishes global baselines.

* Dividends: Treaty shopping reduces the tax burden by 5.6 percentage points on average. The main gain comes from converting high standard WHT rates into lower treaty rates via conduits.
* Interest and Royalties: The gains are higher (7.4 and 7.7 percentage points respectively). This is partly because interest and royalty payments are deductible in the source country, meaning the tax avoidance strategy often eliminates source taxation entirely.

The Netherlands, United Kingdom, Switzerland, Singapore, and Luxembourg consistently rank as the top conduit jurisdictions used to route these flows.

Parent Subsidiary Directive (dividends) and Interest and Royalty directive in EU make the EU attractive as conduit country. 

## Results for Developing Countries (Pages 689-701)

The analysis reveals distinct patterns for the 18 LMICs compared to the global average.

### Dividends (Page 690-696)

* Average Loss: LMICs show a potential treaty shopping gain of 3.0 percentage points, which is significantly lower than the global average of 5.6 points.
* Reasoning: LMICs often have lower standard WHT rates to begin with (e.g., India had no dividend WHT in the 2018 data), meaning there is less tax to "save" by shopping.
* Extreme Cases:
* Bangladesh: Potential WHT revenue loss of 63%.
* Egypt: Potential loss of 100%. This is due to a preferential double tax relief system where Egypt grants exemptions to treaty partners, which MNEs can exploit.
* Kenya: Potential loss of 99.2%, primarily through a treaty with Zambia (identified as a conduit in this specific model).

### Interest (Page 696-698)

* Average Loss: The treaty shopping gain is 5.4 percentage points for LMICs.
* Revenue Impact: Unlike dividends, interest payments reduce the tax base in the source country. The WHT losses here are substantial for specific nations:
* India: Loses 66.7% of potential WHT revenue. MNEs exploit treaty rates of 10% (via conduits) versus the standard 20%.
* Indonesia: Potential loss of 57.9%.

### Royalties (Page 699-701)

* Average Loss: The gain for MNEs is 2.3 percentage points, much lower than the global average of 7.7.
* Variance: Most LMICs (e.g., Angola, Ethiopia, India) show zero potential loss because they have no reduced rates for royalties in their treaties. However, Egypt stands out again with an 85.3% potential loss.

## Identifying Potentially Aggressive Tax Treaties (Pages 701-706)

The authors apply their 25% threshold definition to identify specific bilateral treaties that act as the primary drain on tax revenue for the studied LMICs.

### Key Aggressive Treaties Identified:

* Dividends:
* Philippines – Germany: Germany is the first conduit for 100% of optimal routes due to a unique 5% rate (standard is 30%).
* Indonesia – Netherlands: The Netherlands treaty is responsible for 90% of the loss.
* Bangladesh – UAE: The UAE treaty offers a 5% rate (standard 20%), driving significant diversion.


* Interest:
* India – Switzerland: Switzerland accounts for 100% of the diversion.
* Indonesia – UAE: The UAE treaty is the first stop for 100% of tax-minimising routes.
* Nigeria – South Africa: Responsible for nearly all potential WHT revenue losses.


* Royalties:
* Pakistan – USA: The US treaty offers a 0% rate on royalties (standard 15%), making it the exclusive route for optimisation.
* Ghana – Singapore: Singapore acts as the sole conduit.

The analysis highlights that a small group of conduit countries—Netherlands, UAE, Switzerland, Singapore, and Mauritius—recur frequently as the partners in these aggressive treaties.

## Global Minimum Tax (GMT) and Treaty Shopping (Pages 706-711)

Analyse aggresive tax treatis in combination with GMT. Especially relevant for LMICs if tax incentived to attract investments and activities of MNEs. 

Developing countries often offer tax incentives (e.g., tax holidays in Special Economic Zones) to attract investment, which drives the ETR below 15%.

* If the developing country does not implement a QDMTT, it cannot collect the top-up tax.
* The right to tax then shifts to the jurisdiction of the UPE or IPE.
* Crucial Link: The "potentially aggressive" treaties identified in the paper often link developing countries to conduit countries (Netherlands, Switzerland, Singapore). These conduit countries are typically where IPEs are located.
* Most conduit countries *have* implemented Pillar Two rules (IIR), while many developing countries have not yet implemented the GMT or QDMTTs.

Consequently, the GMT might not benefit developing countries in the short run. Instead, it could result in a transfer of revenue from the developing country (which gave the incentive) to the developed conduit country (which collects the top-up tax via IIR). The incentive for investment is nullified for the MNE (they pay 15% regardless), but the developing country gets neither the investment benefit nor the tax revenue.

* Annex 3 (Robustness Checks):
* Brexit: Treating the UK as a non-EU member (removing Parent-Subsidiary Directive benefits) had minimal impact on global or LMIC averages. The UK remained a highly central conduit.
* Weights: Using additive GDP weights (instead of multiplicative) increased the estimated treaty shopping gains slightly but did not alter the identification of aggressive treaties or the general trends.

* Annex 4 (Treaty Elimination):
* Simulating the removal of the 8 most aggressive dividend treaties showed mixed results. For Indonesia, traffic shifted from the Netherlands to Hong Kong with similar revenue losses. For Uganda, traffic shifted to Belgium, but with a reduced loss (62% instead of 100%). This confirms that piecemeal renegotiation is difficult and requires a systemic view.
