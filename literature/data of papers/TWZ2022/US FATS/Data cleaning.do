use "USFATSdata", clear

gen Region=substr(Country,-2,2)
drop if Region==" R"

gen haven=(Country=="Bermuda"|Country=="Ireland"|Country=="Luxembourg"|Country=="Netherlands"|Country=="Singapore"|Country=="Switzerland"|Country=="Other Western Hemisphere")

foreach name in "Bermuda" "Ireland" "Luxembourg" "Netherlands" "Singapore" "Switzerland"  {
gen `name'=(Country=="`name'")
}

gen HK=(Country=="Hong Kong")
gen OWH=(Country=="Other Western Hemisphere")

destring NetIncome IncomefromEquityInvestments IncomefromCapitalGains ForeignIncomeTaxes, replace force

egen Year_Ind=group(Industry Year)

* Impute profit type return in 1995 (missing in raw BEA files)
sort Country Industry Year
replace ProfitTypeUSDIA = (ProfitTypeUSDIA[_n-1] + ProfitTypeUSDIA[_n+1])/2 if Year == 1995 & Year[_n-1] == 1994 &  Year[_n+1] == 1996


gen ProfitTypeUSDIA_1983= ProfitTypeUSDIA
replace ProfitTypeUSDIA_1983= NetIncome-IncomefromEquityInvestments-IncomefromCapitalGains+ForeignIncomeTaxes if Year<1994

gen pi=ProfitTypeUSDIA/EmployeeCompUSDIA

gen pi83=ProfitTypeUSDIA_1983/EmployeeCompUSDIA

gen logK=ln(Plant)

gen logEmp=ln(EmployeesU)

destring tot_by_aff, replace force
gen logRanD_total=ln(tot_by_aff)

destring number_RD_th, replace force
gen logRanD_emp=ln(number_RD_th)

gen logGDP=log(GDP_P)

gen ProfitPositive=ProfitTypeUSDIA
replace ProfitPositive=0 if ProfitTypeUSDIA<0

gen logPop=log(Pop)

save USFATSdata_clean, replace
