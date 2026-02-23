# How to construct nationally representative firm level data from the Orbis global database: new facts and aggregate implications 
Ozcan 2015
NBER working paper

## Abstract (p. 1)

- The paper constructs nationally representative firm-level longitudinal data for European countries using financial statements from the Orbis database (Bureau van Dijk, a Moody's Analytics company).
- The data are validated by comparing coverage and firm size distribution to official statistics.
- Two applications illustrate the importance of representativeness:
  1. SMEs account for a large share of aggregate economic activity.
  2. Firm representativeness matters for measuring industry concentration trends: concentration has declined in Europe when a representative sample is used, but appears to rise when non-representative subsets are used.

## p. 1 - Introduction

- Firm-level data combining real activity (employment, sales) and financial activity (debt, assets) are increasingly important in macro-finance research.
- Most databases cover only one or the other: national censuses cover real activity; financial databases cover publicly listed firms only.
- Orbis is described as "the largest cross-country firm-level database that combines both," including balance sheets, income statements, and detailed information on location, industry, domestic and foreign owners, and subsidiaries, covering both public and private firms.
- Key problem identified: "firm-level data downloaded from this database are not nationally representative, either due to the way the data is delivered to researchers and/or due to short-cuts the researchers adopt for quick downloads of an immense database that covers millions of firms over time."
- The paper provides a guide for downloading and organising the data to achieve national representativeness.
- Footnote 1: the online appendix was "originally circulated under the title 'How to Construct Nationally Representative Firm Level Data from the ORBIS Global Database,' NBER Working Paper No: 21558."

**Two applications (preview):**
- Application 1 (Section 4): SMEs (defined as firms with 20–250 employees, consistent with the Eurostat definition) account for more than half of aggregate employment and gross output in almost all countries.
- Application 2 (Section 5): Industry concentration - defined as market shares of the top 4 or top 8 firms in a given 2-digit industry - has declined in Europe when a representative sample is used, contrary to findings for the US (where concentration has increased, see Grullon et al. 2019; Crouzet & Eberly 2018). The paper reconciles conflicting results in the existing European literature.
- Footnote 3: US concentration increases documented alongside increasing profit margins and firm markups (De Loecker et al. 2020); Rossi-Hansberg et al. (2021) show the US trend becomes negative at local level; Amiti & Heise (2021) link import competition to declining US market shares of top firms.

**conflict in literature being addressed:**
- Gutierrez & Philippon (2017) find declining concentration in Europe.
- Bajgar et al. (2019) argue concentration has increased in Europe once business groups and consolidated statements are taken into account.
- This paper sides with Gutierrez & Philippon when a representative sample is used, and explains the Bajgar et al. result as an artefact of using consolidated accounts only (which over-weights foreign firms and is sensitive to regulatory changes in 2007).

**regulatory note (footnote 7):** "To promote convergence of accounting standards at the global level, the European Commission introduced new accounting rules on the requirements to report consolidated and unconsolidated accounts in line with international standards adopted by International Financial Reporting Standards (IFRS)." - This regulatory change causes a spurious break around 2007 in concentration measures based on consolidated accounts only.

**finding on double-counting:** In 52% of country-sector-year triplets, the top-8 firms report a mixture of consolidated and unconsolidated accounts, enough to change which firms are in the top-8 group. Footnote 8: The concern about double-counting (consolidated HQ + unconsolidated subsidiary) was examined using global ultimate owner (GUO), domestic ultimate owner (DUO), and immediate shareholder (ISH) information; the number of triplets where top-8 firms share an owner is negligible, confirming no meaningful double-counting.



## p. 2 - Introduction (continued): validation

- Validation is done for the manufacturing sector because Eurostat Structural Business Statistics (SBS) - which comes from national statistical offices - is only consistently publicly available for manufacturing across European countries over time.
- Validation compares: total output, firm size distribution, and presence of foreign companies against official Eurostat SBS and OECD data.
- For foreign companies' aggregate output, OECD data is used.
- Coverage in European countries: close to 60% of manufacturing output at the beginning of the sample; more than 70% at the end.
- Footnote 2: the paper provides "a fair account of the advantages and disadvantages of using Orbis as well as the differences in coverage across countries over time."



## p. 6-7 - Section 2: Data

- Orbis covers more than 100 countries and over 400 million firms as of January 2022.
- BvD collects from over 160 different government and commercial information providers and harmonises into a standard global format.
- Includes both private and publicly listed firms; not a census survey.
- Financial and balance sheet information comes from national business registers, governed by country-specific legal and administrative filing requirements.
- Coverage note: "There is a common misconception that firm-level financial data from national statistical offices always have better coverage than Orbis. For countries where the laws require every firm to file to the national business register, this is not the case because BvD uses the same sources as the statistical offices."
- For countries where only large firms must file financial statements, national statistical offices running separate surveys may have better small-firm coverage.

**Critical methodological issue - single vintage vs. historical vintages:**
- If a single vintage is used, firms will be missing longitudinally because Orbis drops non-reporting firms after a certain time.
- Some variables (e.g., "value-added" and "intermediate inputs") may be missing from certain downloads, including Wharton Research Data Services (WRDS).
- Single-vintage data "will often over-represent larger firms and under-represent smaller firms due to survivorship bias."
- Footnote 10 explains reasons for missing historical data: (1) reporting lag of ~2 years in BvD products; (2) firms erased after non-reporting periods; (3) download cap on web interfaces causes missing data; (4) BvD collection has improved over time.
- Solution: use historical vintages, download vintage-by-vintage, and match over time using unique firm identifiers.
- Based on this guidance, BvD developed a new product called "Historical Product" linking vintages through firm identifiers. The authors note it still requires specific methodology to process (guide and programs at the kalemli website above).

**On re-weighting:**
- Some researchers re-weigh data using official aggregate statistics.
- The authors argue: if their guidelines are followed, re-weighting is unnecessary.
- Warning: "to produce the correct propensity score weights, the non-representative data needs to be matched first to a fully representative data at the firm-level, such as census, otherwise re-weighing with ad-hoc country-sector weights will introduce more errors as argued by Haltiwanger et al. (2017)."
- Footnote 11 references two self-contained online appendices: Appendix A (financial information and data download strategies, including A.1–A.4 on organisation and download, A.5 on constructing financial panel, B.1 on foreign ownership panel).



## p. 8-10 - Section 3: Validation

**Step 1 - Output coverage ratios (manufacturing):**
- Output proxied by operating revenue.
- Coverage ratio = Orbis firm output / official Eurostat SBS output for manufacturing.
- Table 1 shows country-year coverage ratios for 20 European countries (AT, BE, CZ, DE, EE, ES, FI, FR, GB, GR, HU, IT, LV, NO, PL, PT, RO, SE, SI, SK), period 2001–2012.
- Most countries show close to or above 60% from 2001; Finland (FI) is an exception with lower coverage (average 42%).
- Table 2 shows EU-wide coverage rising from ~57% in 2001 to ~67-74% by 2011, then dropping slightly to ~62-68% in 2012. Three averaging methods used: simple unweighted mean, GDP-weighted mean, EU-wide sum ratio (no borders).

**Step 2 - Firm size distribution:**
- Table 3 compares firm size distribution (based on gross output and employment) in Orbis vs. Eurostat SBS for manufacturing, for 2006.
- Three size bins: 1–19 employees (small), 20–249 employees (SME), 250+ employees (large).
- Finding: Orbis distribution very close to official SBS distribution.
- Most of gross output and employment in manufacturing accounted for by SMEs, in both Orbis and SBS.
- Exceptions noted: Finland, UK, Slovakia have under-representation of large firms; Greece has over-representation of medium firms; slight under-representation of small firms in Italy and Slovenia.
- Footnote 12: Online appendix C.1 provides details on official aggregate data sets used for comparison.



## p. 9-11 - Section 4: Application - New Facts on SMEs

- Table 4 presents firm size distribution in the aggregate economy (all sectors) in 2006 using Orbis.
- No equivalent official statistics available for all sectors and countries - this is described as "a new fact shown by our data."
- Important caveat: Eurostat SBS does not cover all sectors consistently (Table A.1 in appendix shows missing sector coverage by country: for most countries, missing sectors represent ~14-26% of total output; missing sector-size cells represent ~53-74%).
- Finding confirmed for aggregate economy: SMEs account for the majority of output and employment across sectors, not just manufacturing.
- SMEs defined as 20–249 employees (Eurostat definition).
- The share of aggregate employment and gross output accounted for by SMEs (20–249 employees) exceeds 50% in almost all countries.



## p. 12-19 - Section 5: Application - Trends in Industry Concentration

**Methodology:**
- Standard concentration measure: market share of top 8 firms (MS8) in a given 2-digit industry (NACE level 2), country, and year relative to total output in that triplet.
- Also computed: top 4 (MS4) and Herfindahl index (similar results, see Figure A.4).
- Footnote 13: NACE Revision 2, Level 2 Classification used; firms assigned to primary industry by largest share of operating revenue.
- Sample period: 2001–2012.
- Two aggregate EU measures: (a) EU-wide (treating EU as single market), (b) EU-country-weighted (each country's concentration weighted by GDP).

**Orbis consolidation codes (key for data construction):**
- U1: only unconsolidated accounts available.
- C1: only consolidated accounts available.
- C2/U2: both consolidated and unconsolidated available (C2 are the consolidated ones; U2 are the unconsolidated ones).
- Additional types: LF (limited financial information), NF (no financial items), NRF/NRLF (no recent accounts/limited financials, where "no recent" = last 3 years).
- Footnote 14: by default, Orbis gives preference to consolidated accounts; this can be changed in search settings. Example of multi-account firm given: Koc Holding (Turkey), see Figure D.4.1 of online appendix D.4.
- Footnote 15: All firms under different consolidation codes share the same BvD ID number, differing only in the last letter code. To avoid double-counting: consolidated accounts kept when both types reported (i.e., unconsolidated HQ sales dropped). Concern about subsidiary sales included in both consolidated HQ and separate unconsolidated affiliate entries is addressed using ownership information.

**The regulatory problem (2007):**
- Footnote 16: The Council of the EU adopted an IAS Regulation requiring listed companies (incl. banks and insurers) to prepare consolidated accounts in accordance with IAS from 2005 onward. Member States could defer until 2007 for companies listed both in EU and elsewhere using US GAAP (or other GAAP) or those with only publicly traded debt. Further details: https://www.esma.europa.eu/convergence/ias-regulation. This regulatory change causes many firms to switch from unconsolidated to consolidated reporting around 2007–2009, creating a spurious break in concentration series based on consolidated accounts.

**Main results (Figure 1):**
- When all firms and all accounts are used: concentration is declining in Europe (2001–2012).
- When only consolidated accounts are used: concentration appears to decline 2000–2007, then increase post-2007 - consistent with Bajgar et al. (2019). This break is even more pronounced when switchers are not corrected for (Figure A.1 in appendix).
- When only unconsolidated accounts are used: declining trend throughout.

**Robustness of the declining trend (Figure 2):**
- Three different denominators for total output tested: Orbis total, Orbis top-100, OECD STAN gross output.
- Results expressed as percentage change since 2001 (=100) for comparability with Bajgar et al. (2019).
- Panel A (all accounts) and Panel B (unconsolidated accounts): clear declining trend throughout, regardless of denominator. Concentration declined by ~10% (full sample) and ~20% (unconsolidated) over 2001–2012.
- Panel C (consolidated accounts): decline until 2007, then increase to +2.5% by 2012.
- Note on STAN denominator: the authors prefer not to use it because the STAN A64 classification does not fully correspond to the two-digit NACE Rev. 2 industry classification.
- Footnote 17: Figure A.2 shows the declining trend for unconsolidated accounts is robust to denominators being top 50, top 100, or top 1000 firms.
- Footnote 18: For Figure 2, only overlapping sectors between STAN and NACE were selected.

**Orbis vs. Compustat Global (Figure 3):**
- Using consolidated accounts in Orbis or in Compustat Global (which covers only publicly-held companies) both result in increasing concentration trends in Europe, especially post-2007.
- Reference: Ali et al. (2008) argue that Compustat-based industry concentration measures are "poor proxies for actual industry concentration." Correlation between Compustat and US Census-based Herfindahl indexes is only 13%.

**Foreign vs. domestic firms (Figure 4):**
- Foreign-owned firm defined as: any firm whose equity is owned by foreigners in excess of 10%, following the IMF balance-of-payments definition (footnote 19).
- Denominator kept fixed (all firms); numerator split into top-8 foreign and top-8 domestic firms.
- EU-country-weighted averages used (to have a clear interpretation: e.g., BMW-Germany = domestic in Germany; BMW-Spain = foreign-owned in Spain; in EU-wide measure both are domestic).
- Validation of foreign firm data: aggregated foreign firm activity compared to OECD AMNE and AFA databases (Figure B.3.1 of online appendix). Footnote 20: AMNE covers 28 OECD host countries from 2008; AFA covers manufacturing from earlier years. Details in online appendix B.2.
- Finding (both all accounts and consolidated accounts): "the increase in industry concentration is driven by foreign firms, regardless of the account type used."
- Logic: any non-representative sample giving larger weight to foreign firms will register an increasing concentration trend. Using consolidated accounts disproportionately captures foreign firms (MNCs required to file consolidated accounts).
- The increasing trend in concentration among consolidated-account firms is "purely driven by foreign-owned firms."



## p. 20 - Section 6: Conclusion

- Nationally representative firm-level longitudinal data constructed for European countries from Orbis.
- Validated against official statistics for manufacturing.
- Two confirmed findings:
  1. SMEs account for a large share of aggregate economic activity across all sectors - previously unknown because official statistics only provide sector-level SME data for certain sectors.
  2. Industry concentration in Europe has declined in representative samples; rising concentration is an artefact of non-representative sampling (large firms, foreign firms, or specific accounting types), all of which give excessive weight to large foreign firms whose market shares rose due to European integration and cross-border regulatory easing.
- Footnote 24: note that even the US Small Business Administration (SBA) with detailed SME data only reports aggregate SME share for the total private sector in the US, not by sector.



## Appendix A - Data Construction Details (selected relevant points)

### A.1 - Dealing with Duplicates

- BvD assigns three generic variables: "BvD Account Number," "BvD ID Number," and "Consolidation Code."
- BvD Account Number = country code (2 letters) + numeric firm ID + last letter (consolidation code type).
- BvD ID Number = country code + numeric part (without last letter).
- Authors create: ID_NUMBER (copy of BvD ID Number) and CONSCODE2 (copy of last letter of BvD Account Number, filled as "C" or "U").
  - C = firm available via C1 and/or C2 accounts.
  - U = firm available via U1 and/or U2 accounts.
  - For LF firms (limited financials): account type extracted from last letter of BvD Account Number.
- Duplicate accounts arise in two cases:
  1. Same ID, different consolidation codes, different financial values in the same year.
  2. Same ID, different consolidation codes, same financial values.
- Resolution rules:
  - Case 1: priority to consolidated accounts.
  - Case 2 (i): firms continuously reporting unconsolidated → priority to unconsolidated.
  - Case 2 (ii): firms continuously reporting consolidated → priority to consolidated.
  - Case 2 (iii): firms switching with same sales values but inconsistently → reclassify as consolidated throughout.

### A.2 - Dealing with Switchers

- Switchers = firms that change account type over time (mixing consolidated and unconsolidated sales in the panel).
- Given the 2007 regulatory change (IAS), switchers are dropped to maintain consistent time series and avoid artificial sales increases from regulation.
- Note: the IAS regulation was supposed to take effect from 2005 but Member States could defer to 2007 for firms listed both in EU and abroad using US GAAP (or other GAAP) or those with only publicly traded debt.

### A.3 - Appendix Tables & Figures

- Table A.1 shows the fraction of output missing from Eurostat SBS: column (1) shows missing sectors (~10-36% depending on country); column (2) shows missing sector-size cells (~10-74% depending on country). Highlights the severe incompleteness of official Eurostat data as a benchmark for all-sector firm size distribution analysis.
- Figure A.1: concentration trends including switchers - the break at 2007 in consolidated accounts is even more pronounced.
- Figure A.2: robustness to different denominators (top 50, top 100, top 1000, all firms) - declining trend for unconsolidated accounts is fully robust.
- Figure A.3: foreign vs. domestic concentration using top-100 denominator - results fully robust.
- Figure A.4: alternative concentration measures (CR4 and Herfindahl) for EU KLEMS countries 1999–2012 - replicates Dottling et al. (2017), using unconsolidated accounts only, confirming declining trend. (Note: utilities, financial firms, real estate, and public sector excluded from non-financial corporate sector in this figure.)

### A.1.1 - Accessing BvD Products

Three access methods described:
1. BvD proprietary browser online (orbis.bvdinfo.com or amadeus.bvdinfo.com).
2. BvD historic CD/DVD-ROM or Blu-Ray disks (or the newer "Orbis Historical" solution linking historical data, still in development at time of writing).
3. WRDS (Wharton Research Data Services) - for Amadeus only.

Note: Orbis and Amadeus data available in "sections" - Orbis Financials (financial data) and Orbis Ownership (ownership information), plus Auditors and Advisors, Board Members, Patents, etc.

**WRDS note:** Amadeus through WRDS organised in three non-overlapping size tiers (Very Large & Large, Medium, Small), with country-varying thresholds based on sales, operating revenue, and employment. Important to account for this when querying via SAS under WRDS subscription.

### A.1.2 - Financial Module

- Orbis Financials includes: balance sheet items, profit and loss account items, financial ratios over time, and static descriptive variables.
- Descriptive variables: national ID number, address (country, region, city, street), legal form, year of incorporation, company status (active/liquidation/merger-acquisition), number of employees, quoted/unquoted indicator, industry and activity codes (4-digit level), and business description (local language and English).
- Footnote 1 of appendix: encoding issues with non-Latin alphabets and non-standard national letters - the user should choose "show textual information in the international alphabet rather than the original alphabet" before download.
- Issues with historical downloads from single disk or web interface: download speed and cap issues - BvD platforms "are not designed for the purposes of academic research involving large-scale downloads."

