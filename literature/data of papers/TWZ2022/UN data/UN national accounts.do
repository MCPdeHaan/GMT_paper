
*******************************************************************
******Exchange rate problems may occur before 2015*****************
*******************************************************************
* To update numbers - go to the UNdata webpage
 
import delimited "Financial corporations.csv", clear
drop valuefootnotes

save financial, replace

import delimited "Non financial corporations.csv", clear
drop valuefootnotes

save non_financial, replace

import delimited "General government.csv", clear
drop valuefootnotes

save government, replace

import delimited "Total economy.csv", clear
drop valuefootnotes

append using financial
append using non_financial
append using government
save UN_NA_all, replace


use UN_NA_all, replace


import excel "WB EXC.xls", sheet("Data") firstrow clear /* extra exchange rates brought in for countries with no WB coverage*/

gen i=_n

reshape long y, i(i) j(year)

rename y exchangerate


gen euro_aux=exchangerate if CountryName=="Euro area"
egen euro=total(euro_aux), by(year)

gen CHF=exchangerate if CountryName=="Switzerland"
egen CHF_all=total(CHF), by(year)
replace exchangerate=CHF_all if CountryName=="Liechtenstein" & exchangerate==.

gen eurogroup=0
replace eurogroup=1 if (CountryName=="Germany"|CountryName=="France"|CountryName=="Finland"|CountryName=="Austria"|CountryName=="Belgium"|CountryName=="Cyprus"|CountryName=="Estonia"|CountryName=="Greece"|CountryName=="Ireland"|CountryName=="Italy"|CountryName=="Latvia"|CountryName=="Lithuania"|CountryName=="Luxembourg"|CountryName=="Malta"|CountryName=="Netherlands"|CountryName=="Portugal"|CountryName=="Slovak Republic"|CountryName=="Slovenia"|CountryName=="Spain")

replace exchangerate=euro if eurogroup==1 & exchangerate==.

save "WB exchange rates", replace


use UN_NA_all, clear

sort countryorarea
drop in 1/143 /*dropping empty lines*/

replace countryorarea= "Bolivia" if countryorarea=="Bolivia (Plurinational State of)"
replace countryorarea= "Hong Kong SAR, China" if countryorarea=="China, Hong Kong Special Administrative Region"
replace countryorarea= "Macao SAR, China" if countryorarea=="China, Macao Special Administrative Region"
replace countryorarea= "Curacao" if countryorarea=="CuraÃ§ao"
replace countryorarea= "Cote d'Ivoire" if countryorarea=="CÃ´te d'Ivoire"
replace countryorarea= "Egypt, Arab Rep." if countryorarea=="Egypt"
replace countryorarea= "Germany" if countryorarea=="Germany, Federal Republic of"
replace countryorarea= "Iran, Islamic Rep." if countryorarea=="Iran (Islamic Republic of)"
replace countryorarea= "Kyrgyz Republic" if countryorarea=="Kyrgyzstan"
replace countryorarea= "Lao PDR" if countryorarea=="Lao People's Democratic Republic"
replace countryorarea= "Micronesia, Fed. Sts." if countryorarea=="Micronesia (Federated States of)"
replace countryorarea= "Korea, Rep." if countryorarea=="Republic o	f Korea"
replace countryorarea= "Moldova" if countryorarea=="Republic of Moldova"
replace countryorarea= "Slovak Republic" if countryorarea=="Slovakia"
replace countryorarea= "Sudan" if countryorarea=="Sudan (up to 2011)"
replace countryorarea= "Macedonia, FYR" if countryorarea=="The former Yugoslav Republic of Macedonia"
replace countryorarea= "Tanzania" if countryorarea=="Tanzania - Mainland"
replace countryorarea= "Venezuela, RB" if countryorarea=="Venezuela"
replace countryorarea= "Yemen, Rep." if countryorarea=="Yemen"





rename countryorarea CountryName

merge m:1 year CountryName using "WB exchange rates", gen(m1) /*merging in world bank exchangerates*/
keep if m1==3
drop m1

save UN_NA_all, replace


import excel "Extra exchange rates.xlsx", sheet("Sheet1") firstrow clear /*merging in oanda exchangerates when WB data is not available*/

merge 1:m year CountryName using "UN_NA_all", gen(m1)
drop if m1==1
drop m1

replace exchangerate=ExchangeRate if exchangerate==.
drop ExchangeRate

replace currency=trim(currency)

replace exchangerate=1 if (currency=="US dollar"|currency=="Cuban Peso")




*************'Several countries have many currencies. The correct observations must be used

*egen tag = tag(currency CountryName)
*egen distinct = total(tag), by(CountryName)
*tab CountryName if distinct>1

****All Euro-countries are on the list, since they change to euro. This has been accounted for.

****Armenia Russian Ruble -> Dram (We use Dram)
drop if CountryName=="Armenia" & currency=="Russian ruble"
**** Azerbaijan manat -> Azerbaijan new manat (We have new. 5000 old manat= 1 new manat. Both prices used today)
replace exchangerate=exchangerate*5000 if currency=="Azerbaijan manat"
****Bhutan spelling error
****Bulgaria uses lev, but some years 1000's of Levs.
replace exchangerate=exchangerate/1000 if currency=="lev (re-denom. 1:1000)"
****Burkino spelling error
****Hungary spelling error
****Kazakhstan used Rouble -> tenge
drop if CountryName=="Kazakhstan" & currency=="Russian ruble"
****Macao SAR, China spelling error
**** Mozambique spelling error
****Romania went from Leu -> New Leu in 2005. 10,000 old Leu= 1 new Leu
replace exchangerate=exchangerate*10000 if currency=="Romanian leu"
****Russian Federation have both Ruble and 1000's ruble. (Something is wrong here... Is the WB exchange rate in 1000's as well???)
replace exchangerate=exchangerate/1000 if currency=="Russian ruble (re-denom. 1:1000)"

****Sierra Leone  spelling error
****South Africa spelling error
****Tunesia Spelling error
****Ukraine went from karbovantsy -> hryvnia All data since 1996 is in hryvnia. I drop the other one
drop if currency=="karbovantsy"

*Belarus is denoted in thousands, but this is not true. It is in tens of thousands 
replace exchangerate=exchangerate*10000 if CountryName=="Belarus"

*Venezuelas accounts are in Bolivia Fuerte, Not Bolivia after 1996
******For now I drop them since most data is more recent
****We have problems with Venezuelas exchange rate

drop if currency=="Russian rouble" & CountryName=="Belarus"
drop if currency=="Belarussian rouble"

*Russian rouble in 1000's since 1995. currency name changed accordingly
***For now I drop observations pre 1995
drop if currency=="Russian ruble" & CountryName=="Russian Federation"

*Venezuela difficult to believe (tripled real economy since 2011???)
drop if CountryName=="Venezuela, RB"



gen USD=value/exchangerate

*drop tag
*drop distinct
*Mauritania (one year)



*Calculating Shares
drop IndicatorName IndicatorCode
rename sna93tablecode sector
rename sna93itemcode itemcode
drop if itemcode=="D.4"



replace itemcode = subinstr(itemcode, "*", "a",.) 
replace itemcode = subinstr(itemcode, ".", "_",.) 
replace itemcode = subinstr(itemcode, "-", "_",.)




drop value
drop item


drop currency fiscal euro - eurogroup
drop  exc euro
egen temp=group(CountryName year sector itemcode)

*There are multiple observations pr. country as different manuals can be used to construct data: We use the newest manual available
egen max=max(series), by(temp)
keep if series==max

drop series snasystem subgroup
drop temp max i

*Rename sector codes to human language 
replace sector="_total" if sector=="4.1"
replace sector="_nonfin" if sector=="4.3"
replace sector="_fin" if sector=="4.4"
replace sector="_govt" if sector=="4.5"

rename USD USD_
reshape wide USD_, i(CountryName year sector) j(itemcode) string

* variable description for codes below can be found on the UNdata webpage but here is the short version:
*D_2_D_3 = taxes less subsidies
*B_1ag= Value added
*B_1g= VA at basic prices
*D_1= Compensation of employees
*B_2g=Operating surplus
*K1=Consumption of fixed capital /depreciation


foreach var in B_1ag B_1an B_1g B_2g B_5g D_1 D_2_D_3 D_5 K_1 {
rename USD_`var' `var' 
} 



reshape wide B_1ag B_1an B_1g B_2g B_5g D_1 D_2_D_3 D_5 K_1  , i(CountryName year) j(sector) string



merge 1:1 year CountryCode using WBdata /*bringing in WB data on economy wide variables*/
drop _merge


replace B_1ag_total=gdp if B_1ag_total==.
replace K_1_total=depreciation if K_1_total==.
replace D_1_total=comp_emp if D_1_total==.


replace B_1ag_total=2500000000 if CountryName=="Aruba" & year==2015
replace B_1ag_total=900000000 if CountryName=="British Virgin Islands" & year==2015

**NB Channel Islands are Jersey and Guernsey
replace B_1ag_total=(4270000000+6170000000) if CountryName=="Channel Islands" & year==2015
replace B_1ag_total=2880000000 if CountryName=="Curacao" & year==2015

*Eritrea according to WB
replace B_1ag_total=2608000000 if CountryName=="Eritrea" & year==2015

*French poly. according to WB
replace B_1ag_total=3448000000 if CountryName=="French Polynesia" & year==2015
replace B_1ag_total=2510000000 if CountryName=="Gibraltar" & year==2015
*according to WB
replace B_1ag_total=12380000000 if CountryName=="Korea, Dem. People’s Rep." & year==2015
*according to WB
replace B_1ag_total=34700000000 if CountryName=="Libya" & year==2015
replace B_1ag_total=5740000000 if CountryName=="Monaco" & year==2015
*According to WB
replace B_1ag_total=2682000000 if CountryName=="New Caledonia" & year==2015
replace B_1ag_total=108000000000 if CountryName=="Puerto Rico" & year==2015
*According to Wikipedia 2008 - Frances national statistics
replace B_1ag_total=794700000 if CountryName=="Sint Maarten (Dutch part)" & year==2015
replace B_1ag_total=599000000 if CountryName=="St. Martin (French part)" & year==2015

*Syria pre war:
replace B_1ag_total=40410000000 if CountryName=="Syrian Arab Republic" & year==2015
*Turks and Caicos Islands 2007 estimate (PPP)
replace B_1ag_total=632000000 if CountryName=="Turks and Caicos Islands" & year==2015


***Splitting into 3 groups of countries: OECD, Haven and rest.

*Rest group
gen countrygroup=0


*OECD
replace countrygroup=1 if (CountryName=="Australia"|CountryName=="Austria"|CountryName=="Belgium"|CountryName=="Canada"|CountryName=="Chile"|CountryName=="Czech Republic"|CountryName=="Denmark"|CountryName=="Estonia"|CountryName=="Finland"|CountryName=="France"|CountryName=="Germany"|CountryName=="Greece"|CountryName=="Hungary"|CountryName=="Iceland"|CountryName=="Ireland"|CountryName=="Israel"|CountryName=="Italy"|CountryName=="Japan"|CountryName=="Korea, Rep."|CountryName=="Latvia"|CountryName=="Luxembourg"|CountryName=="Mexico"|CountryName=="Netherlands"|CountryName=="New Zealand"|CountryName=="Norway"|CountryName=="Poland"|CountryName=="Portugal"|CountryName=="Slovak Republic"|CountryName=="Slovenia"|CountryName=="Spain"|CountryName=="Sweden"|CountryName=="Switzerland"|CountryName=="Turkey"|CountryName=="United Kingdom"|CountryName=="United States")

*Havens
replace countrygroup=2 if (CountryName=="Anquilla"| CountryName=="Vanatu"|CountryName=="Turks and Caicos Islands"|CountryName=="St. Vincent and the Grenadines"|CountryName=="St. Martin (French part)"|CountryName=="St. Lucia"|CountryName=="St. Kitts and Nevis"|CountryName=="Sint Maarten (Dutch part)"|CountryName=="Singapore"|CountryName=="Seychelles"|CountryName=="Sao Tome and Principe"|CountryName=="San Marino"|CountryName=="Puerto Rico"|CountryName=="Panama"|CountryName=="Mauritius"|CountryName=="Samoa"|CountryName=="Marshall Islands"|CountryName=="Malta"|CountryName=="Monaco"|CountryName=="Maldives"|CountryName=="Macao SAR, China"|CountryName=="Liechtenstein"|CountryName=="Liberia"|CountryName=="Lebanon"|CountryName=="Isle of Man"|CountryName=="Hong Kong SAR, China"|CountryName=="Greneda"|CountryName=="Gibraltar"|CountryName=="Dominican Republic"|CountryName=="Cyprus"|CountryName=="Curacao"|CountryName=="Channel Islands"|CountryName=="Cayman Islands"|CountryName=="British Virgin Islands"|CountryName=="Bermuda"|CountryName=="Belize"|CountryName=="Barbados"|CountryName=="Bahrain"|CountryName=="Bahamas, The"|CountryName=="Aruba"|CountryName=="Antigua and Barbuda"|CountryName=="Andorra"|CountryName=="American Samoa")

*Aggregates
replace countrygroup=99 if (CountryName=="World"|CountryName=="Upper middle income"|CountryName=="Sub-Saharan Africa"|CountryName=="Sub-Saharan Africa (IDA & IBRD countries)"|CountryName=="Sub-Saharan Africa (excluding high income)"|CountryName=="South Asia (IDA & IBRD)"|CountryName=="South Asia"|CountryName=="Small states"|CountryName=="Pre-demographic dividend"|CountryName=="Post-demographic dividend"|CountryName=="Pacific island small states"|CountryName=="Other small states"|CountryName=="OECD members"|CountryName=="Not classified"|CountryName=="North America"|CountryName=="Middle income"|CountryName=="Middle East & North Africa"|CountryName=="Middle East & North Africa (IDA & IBRD countries)"|CountryName=="Middle East & North Africa (excluding high income)"|CountryName=="Lower middle income"|CountryName=="Low income"|CountryName=="Low & middle income"|CountryName=="Least developed countries: UN classification"|CountryName=="Latin America & Caribbean (excluding high income)"|CountryName=="Latin America & the Caribbean (IDA & IBRD countries)"|CountryName=="Late-demographic dividend"|CountryName=="Latin America & Caribbean"|CountryName=="IDA only"|CountryName=="IDA total"|CountryName=="IDA & IBRD total"|CountryName=="IDA blend"|CountryName=="IBRD only"|CountryName=="High income"|CountryName=="Heavily indebted poor countries (HIPC)"|CountryName=="Fragile and conflict affected situations"|CountryName=="European Union"|CountryName=="Europe & Central Asia (IDA & IBRD countries)"|CountryName=="Europe & Central Asia (excluding high income)"|CountryName=="Euro area"|CountryName=="Europe & Central Asia"|CountryName=="East Asia & Pacific (IDA & IBRD countries)"|CountryName=="East Asia & Pacific (excluding high income)"|CountryName=="Early-demographic dividend"|CountryName=="East Asia & Pacific"|CountryName=="Central Europe and the Baltics"|CountryName=="Caribbean small states"|CountryName=="Arab World")

merge 1:1 year CountryName using "Missing havens" /*bringing in economy wide data (from statistical webpages) on the last tax havens with no data*/

gen indirect_tax_share=D_2_D_3_total/B_1ag_total
egen indirect_tax_share_tot=mean(indirect_tax_share), by(year countrygroup)
replace indirect_tax_share=indirect_tax_share_tot if indirect_tax_share==.

gen va_basic_tot=(1-indirect_tax_share)*B_1ag_tot

***constructing relevant variables:
gen tot_labourshare=D_1_total/va_basic_tot
gen govt_pr_GDP=(B_1g_govt)/(va_basic_tot)

gen corp_vashare=(B_1g_fin+B_1g_nonfin)/va_basic_tot
gen non_fin_vashare=B_1g_nonfin/va_basic_tot

gen corp_labourshare=(D_1_fin+D_1_nonfin)/(B_1g_fin+B_1g_nonfin)
gen corp_depr_pr_va=(K_1_fin+K_1_nonfin)/(B_1g_fin+B_1g_nonfin)

gen corp_OS_pr_va=(B_2g_fin+B_2g_nonfin)/(B_1g_fin+B_1g_nonfin)

***We first create a weighted average of corporate labour shares and Value added over time (with no imputations)

gen temp_nonmiss= (B_1g_fin!=.)*(B_1g_nonfin!=.)*(B_1ag_total!=.)

*** calculating world corporate VA share of GDP

gen corp_va= B_1g_fin+B_1g_nonfin
replace corp_va=. if temp_nonmiss!=1
replace corp_va=. if countrygroup==99
egen corp_va_year= sum(corp_va), by(year)
gen gdp_world= B_1ag_total
replace gdp_world=. if temp_nonmiss!=1
replace gdp_world=. if countrygroup==99
egen world_gdp = sum(gdp_world), by(year)
gen corp_va_gdpshare = corp_va_year/world_gdp

drop temp_nonmiss world_gdp gdp_world corp_va corp_va_year

*** calculating labour share of corporate value added


gen temp_nonmiss= (D_1_fin!=.)*(D_1_nonfin!=.)*(B_1g_nonfin!=.)*(B_1g_fin!=.)

gen corp_va= B_1g_fin+B_1g_nonfin
replace corp_va=. if temp_nonmiss!=1
replace corp_va=. if countrygroup==99
egen corp_va_year= sum(corp_va), by(year)
replace corp_va_year=. if temp_nonmiss!=1


gen labour_aux=D_1_fin+D_1_nonfin
replace labour_aux=. if temp_nonmiss!=1
replace labour_aux=. if countrygroup==99
egen labour_comp_year = sum(labour_aux), by(year)

replace labour_comp_year=. if temp_nonmiss!=1

gen labour_share_corpva= labour_comp_year/corp_va_year

tabout  year if countrygroup<99  using UNnataccount_labour_corp_share.xls, sum c(mean labour_share_corpva count labour_share_corpva) append f(50)

tabout  year if countrygroup<99 using UNnataccount_corp_va_gdpshare.xls, sum c(mean corp_va_gdpshare count corp_va_gdpshare) append f(50)



**********************Imputations begin 


* time imputation
egen countrynum=group(CountryName)
tsset countrynum year

*bring shares up to 1 year back

foreach var in tot_labourshare corp_labourshare corp_OS_pr_va corp_depr_pr_va govt_pr_GDP corp_vashare non_fin_vashare indirect_tax_share{
replace `var'=L1.`var' if `var'==.
}

foreach var in tot_labourshare corp_labourshare corp_OS_pr_va corp_depr_pr_va govt_pr_GDP corp_vashare non_fin_vashare indirect_tax_share{
gen missing_`var'=1 if `var'==.
}



*tabout CountryName if countrygroup== 1 & year==2015 using UNnataccount_raw.xls, sum c(sum B_1ag_total sum D_2_D_3_total sum D_1_total sum B_1g_govt sum B_1g_fin sum B_1g_nonfin sum D_1_fin sum D_1_nonfin sum K_1_fin sum K_1_nonfin) f(50c)
*tabout CountryName if countrygroup== 2 & year==2015 using UNnataccount_raw.xls, sum c(sum B_1ag_total sum D_2_D_3_total sum D_1_total sum B_1g_govt sum B_1g_fin sum B_1g_nonfin sum D_1_fin sum D_1_nonfin sum K_1_fin sum K_1_nonfin) f(50c) append
*tabout CountryName if countrygroup== 0 & year==2015 using UNnataccount_raw.xls, sum c(sum B_1ag_total sum D_2_D_3_total sum D_1_total sum B_1g_govt sum B_1g_fin sum B_1g_nonfin sum D_1_fin sum D_1_nonfin sum K_1_fin sum K_1_nonfin) f(50c) append




* beyond time impuations we do the mean shares pr. country group and year
gen ratio_labor_share=tot_labourshare/corp_labourshare
egen corp_depr_pr_va_tot=mean(corp_depr_pr_va), by(year countrygroup)
egen corp_vashare_tot=mean(corp_vashare), by(year countrygroup)
egen ratio_labor_share_tot=mean(ratio_labor_share), by(year countrygroup)
egen govt_pr_GDP_tot=mean(govt_pr_GDP), by(year countrygroup)
egen non_fin_vashare_tot=mean(non_fin_vashare), by(year countrygroup)


replace corp_labour=tot_labourshare/ratio_labor_share_tot if corp_labourshare==.
replace corp_depr_pr_va=corp_depr_pr_va_tot if corp_depr_pr_va==.
replace corp_vashare=corp_vashare_tot if corp_vashare==.
replace non_fin_vashare=non_fin_vashare_tot if non_fin_vashare==.
replace govt_pr_GDP=govt_pr_GDP_tot if govt_pr_GDP==.





*Calculating relevant statistics in prioritized order:

gen indirect_taxes=indirect_tax_share*B_1ag_total
replace corp_va=corp_vashare*va_basic_tot if corp_va==.
gen non_fin_va=non_fin_vashare*va_basic_tot
gen fin_va=corp_va-non_fin_va
gen corp_compensation=corp_labourshare*(corp_va)
gen govt_va= govt_pr_GDP_tot*va_basic_tot
gen corp_depr=corp_depr_pr_va*corp_va

gen temp=corp_compensation/corp_va
egen temp2=mean(temp), by(year countrygroup)
replace corp_compensation=temp2*corp_va if corp_compensation==.

replace CountryName="Turks and Caicos" if CountryName=="Turks and Caicos Islands"
replace CountryName="Macau" if CountryName=="Macao SAR, China"
replace CountryName="Sint Maarten" if CountryName=="Sint Maarten (Dutch part)"
replace CountryName="Hong Kong" if CountryName=="Hong Kong SAR, China"


tabout CountryName if countrygroup== 1 & year==2015 using UNnataccount.xls, sum c(sum B_1ag_total sum indirect_taxes sum corp_va sum non_fin_va sum fin_va sum govt_va sum corp_compensation sum corp_depr) f(50c)
tabout CountryName if countrygroup== 2 & year==2015 using UNnataccount.xls, sum c(sum B_1ag_total sum indirect_taxes sum corp_va sum non_fin_va sum fin_va sum govt_va sum corp_compensation sum corp_depr) f(50c) append
tabout CountryName if countrygroup== 0 & year==2015 using UNnataccount.xls, sum c(sum B_1ag_total sum indirect_taxes sum corp_va sum non_fin_va sum fin_va sum govt_va sum corp_compensation sum corp_depr) f(50c) append





