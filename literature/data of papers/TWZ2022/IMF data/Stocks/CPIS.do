*Reader has to do CPIS bulk download herself if update is desired
*In this file we summarize the Portfolio assets of each country and estimate the liabilities using mirror data
*These results are not used in the paper


import delimited "CPIS_10-09-2017 16-07-54-96_timeSeries.csv", clear

drop v13 indicatorcode attribute

destring v12, force replace
rename v12 value


rename ïcountryname countryname
egen idw=group(countryname counterpartcountryname)



replace indicatorname= "ASS_PI" if indicatorname == "Assets, Equity, BPM6, US Dollars"
replace indicatorname= "LIAB_PI" if indicatorname=="Liabilities, Equity, BPM6, US Dollars"



reshape wide value, i(idw) j(indicatorname) string

foreach name in LIAB_PI  ASS_PI{
	rename value`name' `name'
}

*generating country groups

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


*Generating mirror data
egen LIAB_PI_DER=sum(ASS_PI), by(counterpartcountryname)


save CPIS_pre_merge, replace

keep if counterpartcountryname=="World"



save CPIS_world_ASS, replace

use CPIS_pre_merge, clear


sort counterpartcountryname
by counterpartcountryname: gen n=_n
by counterpartcountryname: gen N=_N
keep if n==N
drop countryname
drop if (counterpartcountryname=="British Indian Ocean Territory"|counterpartcountryname=="World"|counterpartcountryname=="Central and South Asia"|counterpartcountryname=="East Asia"|counterpartcountryname=="Economies of Persian Gulf"|counterpartcountryname=="Europe"|counterpartcountryname=="French Southern Territories"|counterpartcountryname=="North Africa"|counterpartcountryname=="North Atlantic and Caribbean"|counterpartcountryname=="North and Central America"|counterpartcountryname=="Oceania and Polar Regions"|counterpartcountryname=="Other Near and Middle East Economies"|counterpartcountryname=="South America" |counterpartcountryname=="Sub-Saharan Africa"|counterpartcountryname=="Western Sahara")
rename counterpartcountryname countryname
keep LIAB_PI_DER countryname  ASS_PI


*Tabout to compare a countries own reports with the mirror reports
tabout countryname using PI_World.xls, append sum c(sum LIAB_PI_DER sum ASS_PI)

merge 1:m countryname using CPIS_world_ASS, gen(m1)

gen temp_0=LIAB_PI_DER if LIAB_PI!=.
gen temp_0a=LIAB_PI if LIAB_PI_DER!=.
egen temp_1=total(temp_0)
egen temp_2=total(temp_0a)
gen ratio_reported_derived= temp_2/temp_1

***Generating world return

use CPIS_world_ASS, replace
gen n_country=countryname
merge 1:1 n_country using "IMF_BOP_for_CPIS", gen(m2)

keep if m2==3

egen Assets_PI_tot=total(ASS_PI)
egen Income_PI_tot=total(PI_divd_Credit)

gen return_PI_tot=Income_PI_tot/Assets_PI_tot


