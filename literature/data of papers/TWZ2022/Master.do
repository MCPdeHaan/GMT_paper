*This file describes and run the programs used in TWZ2018 
global path "C:\Users\Luwie\Dropbox\International tax enforcement\TWZ2020Programs" /*insert the folder location here*/
cd "$path"

*In each directory we report copies of the output tables created by each do-file and a description of the content of these (mostly excel files) 

*********************************************************
**************BOP STATISTICS FROM IMF********************
*This data is used to calculate the FDI income of countries + the trend over time
cd "$path\IMF data\Flows"
*(files need to be run in specified order)

do "IMFs BOP data" /* the dofile that handles the bulk download from the IMF of all current account items for all countries over all available years. Also creates excel output for 2015 alone. Require reader to do bulk-download herself if fully updated version is desired*/
do "BOP timeseries" /* the dofile that outputs in excel the global timeseries of BOP items */

*********************************************************
**************INVESTMENT STOCK STATISTICS FROM IMF*******
*This data is used to calculate the FDI and Portfolio stocks of countries
cd "$path\IMF data\Stocks"
*FYI: In IMF data "countryname" is the country of the reporter, "counterpartcountryname" is the name of the partner and "derived" or "mirror" refers to the reports of the partner
do "FDI numbers" /* the dofile that handles the CDIS bulk download from the IMF. Also creates excel output for 2015 alone and suggests an alternative imputation of haven income. Require reader to do bulk-download herself if fully updated version is desired*/
do "CPIS" //* the dofile that handles the CDIS bulk download from the IMF (not used in paper). Also creates excel output for 2015 alone. Require reader to do bulk-download herself if fully updated version is desired*/


*********************************************************
**************SERVICE DATA FROM EUROSTAT*****************
cd "$path\Eurostat\Services"
*This data is used to calculate the high risk imports of each country => the main allocation key in our benchmark scenario
*Our version of the bulk download of eurostat main tables are attached  - if you want to replicate our findings precisely you shouldn't replace our master data in the following but just run the from the first do "non EU - debit" 
/*if you wish to update data:
ssc install eurostatuse /*to download eurostat data -
7zip must be installed, else error message: Install 7-zip here: C:\Program Files\7-Zip\7zG.exe to proceed from 7-zip.org */
eurostatuse bop_its6_det, clear /* bulk download of service transactions*/
save bop_its6_det, replace
*/

* In the following we create excel tables of available data + impute data whenever this is not available => imputations following strictly logical bookkeeping rules
* Variables are described by labels if this does not suffice, please read the eurostat documentation.
* Note in all the following that geo=reporting country (oppossed to partner)
* "Imports" is used to describe the value of each transaction in the following whether or not the reporting country is exporting/importing 
* "Dodgy" is the name we use for "high risk service payments" in the following see Appendix.pdf for an explanation of "high risk service payments" 


***begin here if you don't want to update data***
do "non EU - debit" /* the dofile that handles (including imputations) service debit data from non-EU (EU countries importing from non-EU countries)*/
do "non EU - credit" /* the dofile that handles (including imputations) service debit data from non-EU (EU countries importing from non-EU countries)*/
do "Internal EU - credit" /* the dofile that handles (including imputations) service debit data from non-EU (EU countries importing from non-EU countries)*/
do "EU - service discrepancies" /* the dofile that calculates credit/debit discrepancies in EU to EU transactions*/


*********************************************************
**************FDI INCOME DATA FROM EUROSTAT**************
cd "$path\Eurostat\FDI income"
*This data is used to calculate the high risk imports of each country => the main allocation key in our benchmark scenario + to calculate the dividend income of EU tax havens
*Our version of the bulk download of eurostat main tables are attached  - if you want to replicate our findings precisely you shouldn't replace our master data in the following but just run from the dofile "Div & Int EU (DO & DI) CRE"
/*if you wish to update data:
ssc install eurostatuse /*to download eurostat data -
Install 7-zip here: C:\Program Files\7-Zip\7zG.exe to proceed from 7-zip.org */
eurostatuse bop_fdi6_inc, clear /* bulk download of service transactions*/
save bop_fdi6_inc, replace
do "Generating basic" /*the dofile that strips away non-necessary variables and conducts the first strictly logical imputations*/
*/

* In the following we create excel tables of available data + impute data whenever this is not available => imputations following strictly logical bookkeeping rules
* A small stata file "fdikeys.dta" is also used in the following (and included in the TWZ2018Programs.zip) - The file contains the total FDI income credited to rest of the world for EU countries.
* Variables are described by labels if this does not suffice, please read the eurostat documentation.
* Note in all the following that geo=reporting country (oppossed to partner)

***begin here if you don't want to update data***
do "Ireland mirror data" /* NEED TO BE RUN FIRST - do-file that create mirror data reports for Ireland as they only report net-values to eurostat*/
do "Div & Int EU (DO & DI) CRE" /* the dofile that handles FDI income credit data where both parties are EU countries*/
do "Div & Int EU (DO & DI) DEB"/* the dofile that handles FDI income debit data where both parties are EU countries*/
do "Div & Int Non EU (DO & DI) CRE" /* the dofile that handles FDI income credit data where an EU country is the creditor and a non-EU country is the debitor*/
do "Div & Int Non EU (DO & DI) DEB" /* the dofile that handles FDI income credit data where an EU country is the debitor and a non-EU country is the creditor*/

*********************************************************
***********National accounts data from UNdata************

*The aim of this section is to report - and impute - the corporate value added, tangible fixed assets and compensation of employees in Non-OECD tax havens where other data is not available
*In the following a bulk download from UNdata of the specified variables in the below dofile is necessary before running the do file if a fully updated version is desired- 
*Note that we had to break up the download in financial, non-financial, gov't and total economy in order not overstep the max. amount of lines pr. download  
*We also downloaded exchange rates and World Bank economy wide data beforehand, these are included

cd "$path\UN data"
do "UN national accounts" /* the dofile that handles (and imputes) UNdata on corporate value added / compensation of employees in non-OECD tax havens with no other data*/
do "UN imputed capital stock" /* the dofile that imputes the tangible fixed assets based on UN national accounts data on gross fixed investments in non-OECD tax havens with no other data*/

*********************************************************
***********OECD data on tangible fixed assets************

*The aim of this section is to download, report and impute when necessary the corporate stock of tangible fixed assets in OECD countries
cd "$path\OECD data"
do "OECD table 9b" /* the dofile that handles (and imputes) OECD table 9b on tangible fixed assets of the corporate sector / compensation of employees in non-OECD tax havens with no other data*/


*********************************************************
***********US FATS timeseries 1983-2017 ************

*The aim of this section is to conduct a regression analysis of the determinants of pi in havens versus non-havens for US-owned firms.
cd "$path\US FATS"

do "Data cleaning" /* the dofile that handles imports the US FATS data and constructs variable for for regression analysis*/

do "Regressions_Rev" /* the dofile that runs regressions and creates table output in excel format*/


