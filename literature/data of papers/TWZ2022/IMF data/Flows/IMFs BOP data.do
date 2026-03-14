/*we begin by doing the bulk download of all BOP items in all years and all countries from the IMF
First peace of code hence requires a new bulk download
Reader can begin from our cleaned master data file "IMF BOP 
import delimited "BOP_09-19-2017 18-24-05-99_timeSeries.csv", delimiter(",") clear 
rename ïcountryname n_country

*Stata can't read a variable name that is a number, so we recode it:
forvalues x=6/78{
local temp=1939+`x'
	rename v`x' year`temp'
}

forvalues x=1945/2016{
	destring year`x', replace ignore(",") force
}


*dropping info we don't need
drop if attribute!="Value"

gen account=substr(indicatorname,1,9)

drop if account !="Current A"



keep if (indicatorname=="Current Account, Primary Income, Net, US Dollars"|indicatorname=="Current Account, Primary Income, Debit, US Dollars"|indicatorname=="Current Account, Primary Income, Credit, US Dollars"|indicatorname=="Current Account, Goods and Services, Credit, US Dollars"| indicatorname=="Current Account, Goods and Services, Debit, US Dollars"| indicatorname=="Current Account, Goods and Services, Goods, Credit, US Dollars"| indicatorname=="Current Account, Goods and Services, Goods, Debit, US Dollars"| indicatorname=="Current Account, Goods and Services, Goods, Net, US Dollars"| indicatorname=="Current Account, Goods and Services, Net, US Dollars"| indicatorname=="Current Account, Goods and Services, Services, Credit, US Dollars"| indicatorname=="Current Account, Goods and Services, Services, Debit, US Dollars"| indicatorname=="Current Account, Goods and Services, Services, Net, US Dollars"| indicatorname=="Current Account, Primary Income, Investment Income, Direct Investment, Income on Equity and Investment Fund Shares, Credit, US Dollars"| indicatorname=="Current Account, Primary Income, Investment Income, Direct Investment, Income on Equity and Investment Fund Shares, Debit, US Dollars"| indicatorname=="Current Account, Primary Income, Investment Income, Direct Investment, Income on Equity and Investment Fund Shares, Net, US Dollars"| indicatorname=="Current Account, Primary Income, Investment Income, Direct Investment, Income on Equity and Investment Fund Shares, Dividends and Withdrawals from Income of Quasi-Corporations, Credit, US Dollars"| indicatorname=="Current Account, Primary Income, Investment Income, Direct Investment, Income on Equity and Investment Fund Shares, Dividends and Withdrawals from Income of Quasi-Corporations, Debit, US Dollars"| indicatorname=="Current Account, Primary Income, Investment Income, Direct Investment, Income on Equity and Investment Fund Shares, Dividends and Withdrawals from Income of Quasi-Corporations, Net, US Dollars"| indicatorname=="Current Account, Primary Income, Investment Income, Direct Investment, Income on Equity and Investment Fund Shares, Reinvested Earnings, Credit, US Dollars"| indicatorname=="Current Account, Primary Income, Investment Income, Direct Investment, Income on Equity and Investment Fund Shares, Reinvested Earnings, Debit, US Dollars"| indicatorname=="Current Account, Primary Income, Investment Income, Direct Investment, Income on Equity and Investment Fund Shares, Reinvested Earnings, Net, US Dollars" | indicatorname=="Current Account, Primary Income, Investment Income, Direct Investment, Interest, Net, US Dollars" | indicatorname=="Current Account, Primary Income, Investment Income, Direct Investment, Interest, Credit, US Dollars"| indicatorname=="Current Account, Primary Income, Investment Income, Direct Investment, Interest, Debit, US Dollars"| indicatorname=="Current Account, Primary Income, Investment Income, Other Investment, Interest, Credit, US Dollars"| indicatorname=="Current Account, Primary Income, Investment Income, Other Investment, Interest, Debit, US Dollars"| indicatorname=="Current Account, Primary Income, Investment Income, Other Investment, Interest, Net, US Dollars"| indicatorname=="Current Account, Primary Income, Investment Income, Portfolio Investment, Interest, Credit, US Dollars"| indicatorname=="Current Account, Primary Income, Investment Income, Portfolio Investment, Interest, Debit, US Dollars"| indicatorname=="Current Account, Primary Income, Investment Income, Portfolio Investment, Interest, Net, US Dollars"| indicatorname=="Current Account, Primary Income, Investment Income, Portfolio Investment, Investment Income on Equity and Investment Fund Shares, Credit, US Dollars"| indicatorname=="Current Account, Primary Income, Investment Income, Portfolio Investment, Investment Income on Equity and Investment Fund Shares, Debit, US Dollars"| indicatorname=="Current Account, Primary Income, Investment Income, Portfolio Investment, Investment Income on Equity and Investment Fund Shares, Net, US Dollars" ///
|indicatorname=="Current Account, Secondary Income, Financial Corporations, Nonfinancial Corporations, Households, and NPISHs, Credit, US Dollars"|indicatorname=="Current Account, Secondary Income, Financial Corporations, Nonfinancial Corporations, Households, and NPISHs, Debit, US Dollars"|indicatorname=="Current Account, Secondary Income, Financial Corporations, Nonfinancial Corporations, Households, and NPISHs, Net, US Dollars" ///
|indicatorname=="Current Account, Secondary Income, Credit, US Dollars"|indicatorname=="Current Account, Secondary Income, Debit, US Dollars"|indicatorname=="Current Account, Secondary Income, Net, US Dollars" ///
|indicatorname=="Current Account, Total, Credit, US Dollars"|indicatorname=="Current Account, Total, Debit, US Dollars"|indicatorname=="Current Account, Total, Net, US Dollars" ///
|indicatorname=="Current Account, Primary Income, Other Primary Income, Credit, US Dollars"|indicatorname=="Current Account, Primary Income, Other Primary Income, Debit, US Dollars" |indicatorname=="Current Account, Primary Income, Other Primary Income, Net, US Dollars" ///
|indicatorname=="Current Account, Goods and Services, Credit, US Dollars" |indicatorname=="Current Account, Goods and Services, Debit, US Dollars" |indicatorname=="Current Account, Primary Income, Compensation of Employees, Credit, US Dollars"|indicatorname=="Current Account, Primary Income, Compensation of Employees, Net, US Dollars"  |indicatorname=="Current Account, Primary Income, Compensation of Employees, Debit, US Dollars"|indicatorname=="Current Account, Primary Income, Compensation of Employees, Net, US Dollars"  |indicatorname=="Current Account, Primary Income, Investment Income, Credit, US Dollars" |indicatorname=="Current Account, Primary Income, Investment Income, Net, US Dollars" |indicatorname=="Current Account, Primary Income, Investment Income, Debit, US Dollars" |indicatorname=="Current Account, Primary Income, Investment Income, Direct Investment, Credit, US Dollars"|indicatorname=="Current Account, Primary Income, Investment Income, Direct Investment, Debit, US Dollars"|indicatorname=="Current Account, Primary Income, Investment Income, Direct Investment, Net, US Dollars")


gen id=_n

reshape long year, i(id) j(y)

drop attribute
rename year USD



replace indicatorname="DI_interest_Net" if indicatorname=="Current Account, Primary Income, Investment Income, Direct Investment, Interest, Net, US Dollars" 

foreach x in "Net" "Credit" "Debit"{
	replace indicatorname="primaryinc_`x'" if indicatorname=="Current Account, Primary Income, `x', US Dollars"
	replace indicatorname="totaltrade_`x'" if indicatorname=="Current Account, Goods and Services, `x', US Dollars"
	replace indicatorname="goods_`x'" if indicatorname=="Current Account, Goods and Services, Goods, `x', US Dollars"
	replace indicatorname="services_`x'" if indicatorname=="Current Account, Goods and Services, Services, `x', US Dollars"
	replace indicatorname="DI_grossprof_`x'" if indicatorname=="Current Account, Primary Income, Investment Income, Direct Investment, Income on Equity and Investment Fund Shares, `x', US Dollars"
	replace indicatorname="DI_divd_`x'" if indicatorname=="Current Account, Primary Income, Investment Income, Direct Investment, Income on Equity and Investment Fund Shares, Dividends and Withdrawals from Income of Quasi-Corporations, `x', US Dollars"
	replace indicatorname="DI_reinvested_`x'" if indicatorname=="Current Account, Primary Income, Investment Income, Direct Investment, Income on Equity and Investment Fund Shares, Reinvested Earnings, `x', US Dollars"
	replace indicatorname="DI_interest_`x'" if indicatorname=="Current Account, Primary Income, Investment Income, Direct Investment, Interest, `x', US Dollars"
	replace indicatorname="PI_divd_`x'" if indicatorname=="Current Account, Primary Income, Investment Income, Portfolio Investment, Investment Income on Equity and Investment Fund Shares, `x', US Dollars"
	replace indicatorname="PI_interest_`x'" if indicatorname=="Current Account, Primary Income, Investment Income, Portfolio Investment, Interest, `x', US Dollars"
	replace indicatorname="Other_`x'" if indicatorname=="Current Account, Primary Income, Investment Income, Other Investment, Interest, `x', US Dollars"
	replace indicatorname="SI_corpandhh_`x'" if indicatorname=="Current Account, Secondary Income, Financial Corporations, Nonfinancial Corporations, Households, and NPISHs, `x', US Dollars"
	replace indicatorname="SI_total_`x'" if indicatorname=="Current Account, Secondary Income, `x', US Dollars"
	replace indicatorname="CA_total_`x'" if indicatorname=="Current Account, Total, `x', US Dollars"
	replace indicatorname="Primaryincome_Other_`x'" if indicatorname=="Current Account, Primary Income, Other Primary Income, `x', US Dollars"
	replace indicatorname="CompensationEmployees_`x'" if indicatorname=="Current Account, Primary Income, Compensation of Employees, `x', US Dollars"
	replace indicatorname="TotalInvest_`x'" if indicatorname=="Current Account, Primary Income, Investment Income, `x', US Dollars"
	replace indicatorname="TotalDI_`x'" if indicatorname=="Current Account, Primary Income, Investment Income, Direct Investment, `x', US Dollars"
	}



	
	
drop indicatorcode id
egen idw=group(y countrycode)

reshape wide USD, i(idw) j(indicatorname) string

rename y year

foreach name in primaryinc_Net primaryinc_Credit primaryinc_Debit TotalDI_Debit TotalDI_Net TotalDI_Credit TotalInvest_Credit TotalInvest_Net TotalInvest_Debit CompensationEmployees_Debit CompensationEmployees_Net CompensationEmployees_Credit Primaryincome_Other_Credit Primaryincome_Other_Debit Primaryincome_Other_Net CA_total_Credit CA_total_Debit CA_total_Net DI_divd_Credit DI_divd_Debit DI_divd_Net DI_grossprof_Credit DI_grossprof_Debit DI_grossprof_Net DI_interest_Credit DI_interest_Debit DI_interest_Net DI_reinvested_Credit DI_reinvested_Debit DI_reinvested_Net Other_Credit Other_Debit Other_Net PI_divd_Credit PI_divd_Debit PI_divd_Net PI_interest_Credit PI_interest_Debit PI_interest_Net SI_corpandhh_Credit SI_corpandhh_Debit SI_corpandhh_Net SI_total_Credit SI_total_Debit SI_total_Net goods_Credit goods_Debit goods_Net services_Credit services_Debit services_Net totaltrade_Credit totaltrade_Debit totaltrade_Net {
	rename USD`name' `name'
}


gen EU=(n_cou=="Belgium"	|n_cou=="Bulgaria"	|n_cou=="Czech Republic"	|n_cou=="Denmark"	|n_cou=="Germany"	|n_cou=="Estonia"	|n_cou=="Ireland"	|n_cou=="Greece"	|n_cou=="Spain"	|n_cou=="France"	|n_cou=="Croatia"	|n_cou=="Italy"	|n_cou=="Cyprus"	|n_cou=="Latvia"	|n_cou=="Lithuania"	|n_cou=="Luxembourg"	|n_cou=="Hungary"	|n_cou=="Malta"	|n_cou=="Netherlands"	|n_cou=="Austria"	|n_cou=="Poland"	|n_cou=="Portugal"	|n_cou=="Romania"	|n_cou=="Slovenia"	|n_cou=="Slovakia"	|n_cou=="Finland"	|n_cou=="Sweden"	|n_cou=="United Kingdom")


*this constitutes our basic data:
save IMF_BOP_1, replace
*/
use IMF_BOP_1, clear

*we now zoom into 2015
keep if year==2015

*create an aux. file only with portfolio income
keep n_cou PI_divd_Credit
keep if PI_divd_Credit!=.


save IMF_BOP_for_CPIS, replace


use IMF_BOP_1, clear

*Have we generae the relevant excel tabouts


gen	 EU_haven=(n_country=="Luxembourg"|n_country=="Ireland"|n_country=="Belgium"|n_country=="Netherlands"|n_country=="Cyprus"|n_country=="Malta")
gen Non_EU_haven=(n_country=="Antigua and Barbuda"|n_country=="Aruba"|n_country=="Switzerland"||n_country=="Montserrat"|n_country=="Virgin Islands, British"|n_country=="Turks and Caicos Islands"|n_country=="Cayman Islands"|n_country=="Bahamas, The"|n_country=="Barbados"|n_country=="Belize"|n_country=="Bermuda"|n_country=="Curacao"|n_country=="Dominica"|n_country=="Grenada"|n_country=="St. Kitts and Nevis"|n_country=="St. Lucia"|n_country=="Lebanon"|n_country=="Liberia"|n_country=="Mauritius"|n_country=="Panama"|n_country=="Seychelles"|n_country=="Singapore"|n_country=="St. Vincent and the Grenadines"|n_country=="Vanuatu"|n_country=="Samoa"|n_country=="Anguilla"|n_country=="Marshall Islands, Republic of"|n_country=="China, P.R.: Hong Kong"|n_country=="Bahrain, Kingdom of"|n_country=="Nauru"|n_country=="Liechtenstein"|n_country=="Andorra"|n_country=="Gibraltar"|n_country=="Niue"|n_country=="Isle of Man"|n_country=="Sint Maarten"|n_country=="Cook Islands"|n_country=="Guernsey"|n_country=="Jersey"|n_country=="US Virgin Islands")

foreach name in "Credit"{
	quietly tabout year using havens_`name'.xls if (Non_EU_haven+EU_haven==1), append sum c(sum DI_grossprof_`name' count DI_grossprof_`name'  )   
}


foreach name in "Credit"{
	quietly tabout n_cou using noneuhavens_`name'.xls if year==2015 & Non_EU_haven, append sum c(sum DI_grossprof_`name' sum PI_divd_`name'  sum SI_total_`name'  sum Primaryincome_Other_`name' )   
}



foreach name in "Net" "Debit" "Credit"{
	quietly tabout n_cou using IMF2_`name'.xls if year==2015, append sum c(sum totaltrade_`name' sum goods_`name' sum services_`name' sum DI_grossprof_`name' sum DI_divd_`name' sum DI_reinvested_`name' sum DI_interest_`name' sum PI_divd_`name' sum PI_interest_`name' sum Other_`name' sum SI_corpandhh_`name' sum SI_total_`name' sum CA_total_`name' sum Primaryincome_Other_`name' sum desc_in_divd)   
	quietly tabout n_cou using IMF2_EU_`name'.xls if year==2015 & EU==1, append sum c(sum totaltrade_`name' sum goods_`name' sum services_`name' sum DI_grossprof_`name' sum DI_divd_`name' sum DI_reinvested_`name' sum DI_interest_`name' sum PI_divd_`name' sum PI_interest_`name' sum Other_`name' sum SI_corpandhh_`name' sum SI_total_`name' sum CA_total_`name' sum Primaryincome_Other_`name' sum desc_in_divd)
}

