# How to construct nationally representative firm level data from the Orbis global database: new facts and aggregate implications 
Ozcan 2015
NBER working paper

### **Page 1**

* **Abstract:** The authors aim to construct "nationally representative firm-level longitudinal data for European countries using financial statements from the Orbis database".

* The data construction is validated by comparing the sample's coverage and firm size distribution against official statistics.

* The paper highlights two main applications to demonstrate the importance of firm representativeness in understanding macroeconomics:

  1. Small-and-medium-sized firms (SMEs) are shown to account for a massive share of aggregate economic activity.
  2. Industry concentration trends change drastically depending on the firm samples used, proving that representation is crucial for calculating the economic activity of top firms.

### **Page 2**

* **Introduction:** Firm-level data that combines real activity (like employment and production) with financial data (like debt and assets) is increasingly vital for macro-finance research.

* Typically, datasets only cover one aspect: either real activity (via national censuses) or financial activity (via public company reporting).

* The Orbis global database (by Bureau van Dijk, BvD) is unique because it is the "largest cross-country firm-level database" that merges both real and financial data. It includes both public and private firm balance sheets, income statements, location, and domestic/foreign ownership structures.  
   

* However, data downloaded directly from Orbis is usually "not nationally representative" due to how the data is delivered and the shortcuts researchers use when downloading.

* This paper provides a methodological guide on how to download and organize Orbis data so that it becomes nationally representative.

* **Application 1 Overview:** The data shows that SMEs make up a large portion of real economic activity. While official statistics only show this for a select few private sectors, this paper's dataset confirms the trend for "all sectors of a given economy".  
   

* **Application 2 Overview:** The paper investigates industry concentration in Europe and documents a "declining trend". The authors warn that using a non-representative sample can falsely indicate increasing industry concentration over time.  
   

### **Page 3**

* **Validation Exercise:** To prove their sample is representative, the authors show that their Orbis firm data covers a large portion of the aggregate economy and matches the official firm size distribution provided by Eurostat's Structural Business Statistics (SBS).

* The validation focuses specifically on the manufacturing sector because it is the only sector where SBS consistently provides public aggregate data across European countries over time.

* Coverage of manufacturing output in the constructed dataset is robust: "close to 60% of manufacturing output at the beginning of our sample and more than 70% at the end of our sample".

* **SME Details:** SMEs are defined according to the Eurostat definition as firms with 20-250 employees. The data confirms that SMEs account for more than half of aggregate employment and gross output.

* **Concentration Trends:** Recent literature notes that industry concentration (measured by the market share of the top 4 or top 8 firms in a 2-digit industry) has increased in the United States, but declined in Europe.


### **Page 4**

* Some recent literature (Bajgar et al., 2019\) has challenged the declining European trend, arguing that concentration in Europe has actually increased if you look at business groups using consolidated company statements.

* The authors of this paper find a declining trend and explain the discrepancy: Firm representation matters because it dictates which firms are classified in the top 4 or top 8\.

* In a non-representative sample, industry concentration only appears to increase for the subset of firms that exclusively file consolidated statements. When a representative sample is used, concentration declines regardless of the financial account type used.  
   

* **The Foreign Firm Factor:** The increase in consolidated statement filings is driven by "increased presence of foreign-owned firms and changing regulation" related to European integration. Multinational companies (MNCs) are required to file consolidated statements.  
   

* Therefore, the increasing concentration trend observed among firms reporting consolidated statements is "purely driven by foreign-owned firms".

* *Footnote 6 Note:* Foreign firms account for about 30% of aggregate output on average, but this varies wildly (e.g., \>50% in Luxembourg vs. \~20% in Germany and Italy).

### **Page 5**

* When evaluating the market share of the top 8 firms, opposing trends appear based on account type: concentration decreases for firms reporting unconsolidated statements, but increases for those reporting consolidated statements.

* When all statements are combined (carefully avoiding double counting), the clear message is that "industry concentration has declined in Europe since 2001".

* Focusing only on a selected set of statements (like consolidated accounts) leads to a biased selection of listed firms, business groups, and foreign firms, yielding misleading trends.

* **Regulatory Impact:** A sharp increase in concentration was observed around 2007, which perfectly aligns with a "change in the European accounting legislation".

  * *Footnote 7 Note:* The European Commission introduced new accounting rules to align consolidated and unconsolidated reporting with International Financial Reporting Standards (IFRS).

* Many large firms that account for massive shares of industry activity only "report unconsolidated accounts". These firms are left out of studies that focus only on business groups. "For policies such as anti-trust regulation, it is essential to know about these firms".  
  \+2

### **Page 6**

* **Data Description:** The Orbis database collects data from over 160 providers to harmonize financial and ownership info. It is not a census; it relies on national business registers and country-specific filing requirements.  
   

* Firm-level data from national statistical offices does not automatically have better coverage than Orbis because BvD utilizes the exact same sources.

* Researchers often fail to get full coverage from Orbis if they rely on a single database vintage or a direct web platform download.

  * *Footnote 10 Note:* Issues with web downloads include a roughly two-year reporting lag, BvD erasing non-reporting companies, and download caps that result in missing data.

### **Page 7**

* **Best Practices for Downloading:** To maintain consistent coverage of both small and large firms over time, researchers must "use the historical vintages, download data vintage-by-vintage, and match the firm data over time using unique firm identifiers".

* Using a single vintage causes survivorship bias, drastically over-representing large firms and under-representing smaller ones that may have stopped reporting.

* If the authors' methodology is followed, researchers do not need to re-weigh the data with official aggregate statistics to achieve representativeness.

### **Page 8 & 9**

* **Validation Results:** Table 1 displays the coverage of the manufacturing sector based on gross output. With the exception of Finland, most European countries show coverage ratios close to or above 60% from 2001 onwards.  
   

* Table 2 indicates that EU-wide coverage for the manufacturing sector rose from 57% in 2001 to 71% in 2007\.

* The data accurately mimics the official Eurostat SBS firm-size distribution for both gross output and employment (shown in Table 3 for the year 2006).  
   

### **Page 10 & 11**

* **SME Application:** Because the dataset is validated, the authors use it to provide new facts about the size distribution of firms across *all* sectors (Table 4).  
   

* Official Eurostat SBS statistics are incomplete, missing data for sectors that represent \~20% of total economic output.

* The Orbis data shows that SMEs account for the majority of gross output and employment across the entire aggregate economy, proving this is not just a manufacturing sector phenomenon.

### **Page 12 & 13**

* **Industry Concentration Application:** The standard measure of concentration used is the market share of the top 8 firms (MS8) relative to the population of all firms in a specific 2-digit industry, country, and year.

* BvD classifies accounts by consolidation codes:

  * U1: Only unconsolidated accounts available.

  * C1: Only consolidated accounts available.

  * U2-C2: Both available.

* Using only unconsolidated accounts might under-represent concentration (due to group sales spread across units), but using only consolidated accounts is highly misleading because many large companies do not report them, biasing who is designated as a "top 8" firm.  
   

* In reality, an "overwhelming majority of companies in Orbis report unconsolidated accounts".

* The regulatory changes around 2007 (shifting to IFRS) forced many companies to switch to consolidated reporting.  
   

### **Page 14 & 15**

* Figure 1 visualizes the divergence: Using all firms and all accounts shows declining concentration in Europe. Using only consolidated accounts shows concentration declining until 2007, then artificially increasing.  
   

* Figure 2 proves this declining trend is robust regardless of the denominator used for total output (Orbis total, Orbis top-100, or OECD STAN gross output).  
   

* The artificial increase seen in the consolidated sample is driven by the omission of large unconsolidated firms and the 2007 regulatory switch. The firms making this reporting switch were largely foreign-owned firms.  
   

### **Page 16, 17, & 18**

* Figure 3 shows that relying on Compustat Global (which only includes publicly-held companies) produces the same biased, increasing concentration trend post-2007.

* To investigate the consolidated accounts bias, the authors aggregated foreign firm activity and validated it against OECD databases (AMNE and AFA), finding strong alignment.  
   

* Figure 4 separates the market share of the top 8 firms into foreign vs. domestic. The results definitively show that "the increase in industry concentration is driven by foreign firms, regardless of the account type used".  
   

* Because the 2007 regulations pushed foreign MNCs to file consolidated accounts, any sample using only consolidated accounts gives higher weight to these foreign firms, registering a false increasing concentration trend.

### **Page 19 & 20**

* **Conclusion:** Firm-level representation is critical.

* SMEs dominate aggregate economic activity across all sectors and countries, a fact not visible in standard official statistics.

* Using a nationally representative firm-level sample proves that industry concentration in Europe is declining.

* Studies showing rising concentration in Europe are relying on non-representative samples (focusing on large firms, foreign firms, or consolidated accounts) which artificially give more weight to large foreign firms whose market shares grew due to European integration.

### **Appendix Highlights (Relevant for Methodology)**

* **Page 23 (A.1 Dealing with Duplicates):** When resolving duplicate records (firms reporting under different consolidation codes in the same year), the authors prioritize consolidated accounts if the financial values differ. If the values are identical, they implement filters to maintain a consistent time series.  
   

* **Page 25 (A.2 Dealing with Switchers):** Firms that switched their reporting account type over time (combining consolidated and unconsolidated sales) were dropped. This switch occurred mostly around 2007 due to IAS legislation. Dropping them ensures a consistent time series and minimizes artificial sales increases.  
