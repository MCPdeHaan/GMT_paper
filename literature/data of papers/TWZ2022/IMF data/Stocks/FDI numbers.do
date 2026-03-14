*reader must first do the CDIS bulk download at the IMF webpage manually if updated number are desired
import delimited "CDIS_10-05-2017 10-54-55-79_timeSeries.csv", clear


destring v8, force replace
rename v8 value
drop if value==.
rename ïcountryname countryname
egen idw=group(countryname counterpartcountryname)
drop indicatorcode attribute v9


drop if (countryname=="British Indian Ocean Territory"|countryname=="Central and South Asia"|countryname=="East Asia"|countryname=="Economies of Persian Gulf"|countryname=="Europe"|countryname=="French Southern Territories"|countryname=="North Africa"|countryname=="North Atlantic and Caribbean"|countryname=="North and Central America"|countryname=="Oceania and Polar Regions"|countryname=="Other Near and Middle East Economies"|countryname=="South America" |countryname=="Sub-Saharan Africa"|countryname=="Western Sahara")

*we rename variables - derived = mirror data
replace indicatorname= "IN_EQ_DER" if indicatorname == "Inward Equity Positions (Net), Derived, US Dollars"
replace indicatorname= "IN_EQ" if indicatorname=="Inward Equity Positions (Net), US Dollars"
replace indicatorname= "IN_DI" if indicatorname=="Inward Direct Investment Positions, US Dollars"
replace indicatorname= "IN_DI_DER" if indicatorname=="Inward Direct Investment Positions, Derived, US Dollars"
replace indicatorname="OUT_DI_DER" if indicatorname=="Outward Direct Investment Positions, Derived, US Dollars"	
replace indicatorname="OUT_DI" if indicatorname=="Outward Direct Investment Positions, US Dollars"
replace indicatorname="OUT_EQ_DER" if indicatorname=="Outward Equity Positions (Net), Derived, US Dollars"
replace indicatorname="OUT_EQ" if indicatorname=="Outward Equity Positions (Net), US Dollars"

replace indicatorname="IN_DEBT_LIAB_GROSS" if indicatorname=="Inward Debt Instruments Liabilities Positions (Gross), US Dollars"
replace indicatorname="IN_DEBT_LIAB_GROSS_DER" if indicatorname=="Inward Debt Instruments Liabilities Positions (Gross), Derived, US Dollars"
replace indicatorname="OUT_DEBT_ASS_GROSS" if indicatorname=="Outward Debt Instruments Assets Positions (Gross), US Dollars"
replace indicatorname="OUT_DEBT_ASS_GROSS_DER" if indicatorname=="Outward Debt Instruments Assets Positions (Gross), Derived, US Dollars"




reshape wide value, i(idw) j(indicatorname) string

foreach name in OUT_DEBT_ASS_GROSS_DER OUT_DEBT_ASS_GROSS IN_DEBT_LIAB_GROSS_DER IN_DEBT_LIAB_GROSS IN_DI IN_DI_DER IN_EQ IN_EQ_DER OUT_DI OUT_DI_DER OUT_EQ OUT_EQ_DER {
	rename value`name' `name'
}

*We create country groups:

gen EU_c1=(countryname=="Belgium"	|countryname=="Bulgaria"	|countryname=="Czech Republic"	|countryname=="Denmark"	|countryname=="Germany"	|countryname=="Estonia"	|countryname=="Ireland"	|countryname=="Greece"	|countryname=="Spain"	|countryname=="France"	|countryname=="Croatia"	|countryname=="Italy"	|countryname=="Cyprus"	|countryname=="Latvia"	|countryname=="Lithuania"	|countryname=="Luxembourg"	|countryname=="Hungary"	|countryname=="Malta"	|countryname=="Netherlands"	|countryname=="Austria"	|countryname=="Poland"	|countryname=="Portugal"	|countryname=="Romania"	|countryname=="Slovenia"	|countryname=="Slovakia"	|countryname=="Finland"	|countryname=="Sweden"	|countryname=="United Kingdom")
gen EU_c2=(counterpartcountryname=="Belgium"	|counterpartcountryname=="Bulgaria"	|counterpartcountryname=="Czech Republic"	|counterpartcountryname=="Denmark"	|counterpartcountryname=="Germany"	|counterpartcountryname=="Estonia"	|counterpartcountryname=="Ireland"	|counterpartcountryname=="Greece"	|counterpartcountryname=="Spain"	|counterpartcountryname=="France"	|counterpartcountryname=="Croatia"	|counterpartcountryname=="Italy"	|counterpartcountryname=="Cyprus"	|counterpartcountryname=="Latvia"	|counterpartcountryname=="Lithuania"	|counterpartcountryname=="Luxembourg"	|counterpartcountryname=="Hungary"	|counterpartcountryname=="Malta"	|counterpartcountryname=="Netherlands"	|counterpartcountryname=="Austria"	|counterpartcountryname=="Poland"	|counterpartcountryname=="Portugal"	|counterpartcountryname=="Romania"	|counterpartcountryname=="Slovenia"	|counterpartcountryname=="Slovakia"	|counterpartcountryname=="Finland"	|counterpartcountryname=="Sweden"	|counterpartcountryname=="United Kingdom")
gen EU_haven_c1=0
replace EU_haven_c1=1 if (countryname=="Luxembourg"|countryname=="Ireland"|countryname=="Belgium"|countryname=="Netherlands"|countryname=="Cyprus"|countryname=="Malta")
gen EU_haven_c2=0 
replace EU_haven_c2=1 if (counterpartcountryname=="Luxembourg"|counterpartcountryname=="Ireland"|counterpartcountryname=="Belgium"|counterpartcountryname=="Netherlands"|counterpartcountryname=="Cyprus"|counterpartcountryname=="Malta")
gen haven_c1=0
replace haven_c1=1 if (countryname=="Antigua and Barbuda"|countryname=="Aruba"|countryname=="Switzerland"||countryname=="Montserrat"|countryname=="Virgin Islands, British"|countryname=="Turks and Caicos Islands"|countryname=="Cayman Islands"|countryname=="Bahamas, The"|countryname=="Barbados"|countryname=="Belize"|countryname=="Bermuda"|countryname=="Curacao"|countryname=="Dominica"|countryname=="Grenada"|countryname=="St. Kitts and Nevis"|countryname=="St. Lucia"|countryname=="Lebanon"|countryname=="Liberia"|countryname=="Mauritius"|countryname=="Panama"|countryname=="Seychelles"|countryname=="Singapore"|countryname=="St. Vincent and the Grenadines"|countryname=="Vanuatu"|countryname=="Samoa"|countryname=="Anguilla"|countryname=="Marshall Islands, Republic of"|countryname=="China, P.R.: Hong Kong"|countryname=="Bahrain, Kingdom of"|countryname=="Nauru"|countryname=="Liechtenstein"|countryname=="Andorra"|countryname=="Gibraltar"|countryname=="Niue"|countryname=="Isle of Man"|countryname=="Sint Maarten"|countryname=="Cook Islands"|countryname=="Guernsey"|countryname=="Jersey"|countryname=="US Virgin Islands")
gen haven_c2=0
replace haven_c2=1 if (counterpartcountryname=="Antigua and Barbuda"|counterpartcountryname=="Aruba"|counterpartcountryname=="Switzerland"||counterpartcountryname=="Montserrat"|counterpartcountryname=="Virgin Islands, British"|counterpartcountryname=="Turks and Caicos Islands"|counterpartcountryname=="Cayman Islands"|counterpartcountryname=="Bahamas, The"|counterpartcountryname=="Barbados"|counterpartcountryname=="Belize"|counterpartcountryname=="Bermuda"|counterpartcountryname=="Curacao"|counterpartcountryname=="Dominica"|counterpartcountryname=="Grenada"|counterpartcountryname=="St. Kitts and Nevis"|counterpartcountryname=="St. Lucia"|counterpartcountryname=="Lebanon"|counterpartcountryname=="Liberia"|counterpartcountryname=="Mauritius"|counterpartcountryname=="Panama"|counterpartcountryname=="Seychelles"|counterpartcountryname=="Singapore"|counterpartcountryname=="St. Vincent and the Grenadines"|counterpartcountryname=="Vanuatu"|counterpartcountryname=="Samoa"|counterpartcountryname=="Anguilla"|counterpartcountryname=="Marshall Islands, Republic of"|counterpartcountryname=="China, P.R.: Hong Kong"|counterpartcountryname=="Bahrain, Kingdom of"|counterpartcountryname=="Nauru"|counterpartcountryname=="Liechtenstein"|counterpartcountryname=="Andorra"|counterpartcountryname=="Gibraltar"|counterpartcountryname=="Niue"|counterpartcountryname=="Isle of Man"|counterpartcountryname=="Sint Maarten"|counterpartcountryname=="Cook Islands"|counterpartcountryname=="Guernsey"|counterpartcountryname=="Jersey"|counterpartcountryname=="US Virgin Islands")

*creating first excel files:

tabout countryname using discrepancies_in_stocks.xls if counterpartcountryname=="World", sum c(sum OUT_DI sum OUT_DI_DER sum OUT_EQ sum OUT_EQ_DER sum IN_DI sum IN_DI_DER sum IN_EQ sum IN_EQ_DER) f(50)
*tabout countryname using EUUSposition.xls if EU_c2==1, sum c(sum "OUT_DI_DER") 
*tabout countryname using EUUSposition.xls if counterpartcountryname=="United States", append sum c(sum "OUT_DI_DER")
*tabout countryname using EUUSposition.xls if counterpartcountryname=="World", append sum c(sum "OUT_DI_DER")


tabout counterpartcountryname using EUUSposition2.xls if EU_c1==1, sum c(sum "OUT_DI") 
tabout counterpartcountryname using EUUSposition2.xls if countryname=="United States", append sum c(sum "OUT_DI")
tabout counterpartcountryname using EUUSposition2.xls if countryname=="World", append sum c(sum "OUT_DI")

tabout counterpartcountryname using EUUSposition2.xls if countryname=="United States" & EU_c2==1, append sum c(sum "OUT_DI")

tabout counterpartcountryname using EUUSpositioninhavens.xls if EU_c1==1 & haven_c2, sum c(sum "OUT_DI") 
tabout counterpartcountryname using EUUSpositioninhavens.xls if countryname=="United States" & haven_c2, append sum c(sum "OUT_DI")
tabout counterpartcountryname using EUUSpositioninhavens.xls if countryname=="World" & haven_c2, append sum c(sum "OUT_DI")


***We now try to correct the data on investments and income in havens by using the counterpart data (not used in main results but as a alternative estimate in table A7).
*First - for tax havens where both mirror data and own reports exists, we calculate the weighted ratio between these two:
gen adj_DIRE_EQ=IN_EQ
gen temp_DIRE_EQ=IN_EQ if haven_c1==1 & IN_EQ_DER!=. & counterpartcountryname=="World"
egen total_DIRE=sum(temp_DIRE_EQ)
gen temp_DIRE_EQ_DER=IN_EQ_DER if haven_c1==1 & IN_EQ!=. & counterpartcountryname=="World"
egen total_DIRE_DER=sum(temp_DIRE_EQ_DER)
gen ratio_DIRE_EQ=total_DIRE/total_DIRE_DER

drop temp_DIRE_EQ total_DIRE temp_DIRE_EQ_DER total_DIRE_DER 

*Second for tax havens that don't report FDI investments, we use the mirror report multiplied by the ratio between own reports and haven reports
replace adj_DIRE_EQ=IN_EQ_DER*ratio_DIRE_EQ if adj_DIRE_EQ==.
*Third for tax havens where their own reports are less than the mirror reports - we add the excess partner reports and scale these up by the same factor as above
replace adj_DIRE_EQ=(IN_EQ_DER-adj_DIRE_EQ)*ratio_DIRE_EQ + adj_DIRE_EQ if adj_DIRE_EQ<=IN_EQ_DER

replace adj_DIRE_EQ=. if haven_c1!=1

****Imputing tax haven income 
*To impute inward FDI income we use the average yield on inward and outward investments from countries where we do have data (see TWZ2017Appendix.pdf table A7)
gen DIRE_EQ_income=adj_DIRE_EQ*0.0743 if haven_c1==1


****We now do the exact same procedure on outward FDI from tax havens
gen adj_DIA_EQ=OUT_EQ
gen temp_DIA_EQ=OUT_EQ if haven_c1==1 & OUT_EQ_DER!=. & counterpartcountryname=="World"
egen total_DIA=sum(temp_DIA_EQ)
gen temp_DIA_EQ_DER=OUT_EQ_DER if haven_c1==1 & IN_EQ!=. & counterpartcountryname=="World"
egen total_DIA_DER=sum(temp_DIA_EQ_DER)
gen ratio_DIA_EQ=total_DIA/total_DIA_DER

drop temp_DIA_EQ total_DIA temp_DIA_EQ_DER total_DIA_DER 


replace adj_DIA_EQ=OUT_EQ_DER*ratio_DIA_EQ if adj_DIA_EQ==.
replace adj_DIA_EQ=(OUT_EQ_DER-adj_DIA_EQ)*ratio_DIA_EQ + adj_DIA_EQ if adj_DIA_EQ<=OUT_EQ_DER

replace adj_DIA_EQ=. if haven_c1!=1

gen DIA_EQ_income=adj_DIA_EQ*0.0447 if haven_c1==1

****And similar we impute the interest payments to tax havens using mirror reports:

*Generating debt ratio
gen adj_DIA_DEBT=OUT_DEBT_ASS_GROSS
gen temp_DIA_DEBT=OUT_DEBT_ASS_GROSS if haven_c1==1 & OUT_DEBT_ASS_GROSS_DER!=. & counterpartcountryname=="World"
egen total_DIA_DEBT=sum(temp_DIA_DEBT)
gen temp_DIA_DEBT_DER=OUT_DEBT_ASS_GROSS_DER if haven_c1==1 & OUT_DEBT_ASS_GROSS!=. & counterpartcountryname=="World"
egen total_DIA_DEBT_DER=sum(temp_DIA_DEBT_DER)
gen ratio_DIA_DEBT=total_DIA_DEBT/total_DIA_DEBT_DER


******Tabout of Haven DIA and DIRE
tabout countryname using CDIS_haven_adj.xls if counterpartcountryname=="World" & haven_c1==1 ///
	, append sum c(sum "adj_DIRE_EQ" sum "DIRE_EQ_income" sum "adj_DIA_EQ" sum "DIA_EQ_income" sum "adj_DIA_DEBT")   








	
