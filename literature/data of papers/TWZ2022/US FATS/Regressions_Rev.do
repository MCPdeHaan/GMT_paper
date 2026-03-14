version 14.2
use "USFATSdata_clean", clear

drop if Region==" R"
* drop if Industry=="Petroleum"


*******************************
** Raw average profitability **
*******************************

* Compensation-weighted average profitability in havens
reg pi83 i.Year#c.haven [aweight=EmployeeCompUSDIA] if Industry=="AllIndustries", noconstant r


* Compensation-weighted average profitability in non-havens
gen nonhaven = 0
replace nonhaven = 1 if haven == 0
reg pi83 i.Year#c.nonhaven [aweight=EmployeeCompUSDIA] if Industry=="AllIndustries", noconstant cluster(Country)
outreg2 using regressionsRev.xls, ctitle(Nonhaven benchmark)
**************************************************
** Profitability premium of havens over non-havens
**************************************************

* No control
reghdfe pi83 i.Year#c.haven [aweight=EmployeeCompUSDIA] if Industry=="AllIndustries", a(Year) cluster(Country)
outreg2 using regressionsRev.xls, ctitle(Allindustries no countrols)
* Check: this is what needs to be added to raw average profitability of non-havens to obtain the raw average profitability of havens
* OK

*Capital and macro controls plus year FE
reghdfe pi83 i.Year#c.haven i.Year#c.logK i.Year#c.logGDP i.Year#c.logPop  [aweight=EmployeeCompUSDIA] if Industry=="AllIndustries", a(Year_Ind) cluster(Country)
outreg2 using regressionsRev.xls, ctitle(Allindustries with macro controls)
*outreg2 using regressions3.xls, ctitle(Allindustries)

*Additional country FE
*reghdfe pi83 i.Year#c.haven i.Year#c.logK i.Year#c.logGDP i.Year#c.logPop [aweight=EmployeeCompUSDIA] if Industry=="AllIndustries", a(Year Country) cluster(Country)
* Error: Country:  string variables may not be used as factor variables
egen Country_c=group(Country)
reghdfe pi83 i.Year#c.haven i.Year#c.logK i.Year#c.logGDP i.Year#c.logPop [aweight=EmployeeCompUSDIA] if Industry=="AllIndustries", a(Year Country_c) cluster(Country)
* outreg2 using regressions3.xls, ctitle(Year Country FE)

*Capital and macro controls plus year*Industry FE
reghdfe pi i.Year#c.haven i.Year#c.logK i.Year#c.logGDP i.Year#c.logPop  [aweight=EmployeeCompUSDIA] if Industry!="AllIndustries", a(Year_Ind) cluster(Country) 
outreg2 using regressionsRev.xls, ctitle(Year_IND FE)
*outreg2 using regressions3.xls, ctitle(Year_Ind FE)

*Capital and macro controls plus year*Industry FE plus country FE
*reghdfe pi i.Year#c.haven i.Year#c.logK i.Year#c.logGDP i.Year#c.logPop  [aweight=EmployeeCompUSDIA] if Industry!="AllIndustries", a(Year_Ind Country) cluster(Country)
* Error: Country:  string variables may not be used as factor variables
reghdfe pi i.Year#c.haven i.Year#c.logK i.Year#c.logGDP i.Year#c.logPop  [aweight=EmployeeCompUSDIA] if Industry!="AllIndustries", a(Country) 
outreg2 using regressionsRev.xls, ctitle(Year_Ind Country FE)

*Capital and macro controls plus year*Industry FE plus RnD controls
reghdfe pi i.Year#c.haven i.Year#c.logK i.Year#c.logRanD_total [aweight=EmployeeCompUSDIA] if Industry!="AllIndustries", a(Year_Ind) cluster(Country)
outreg2 using regressionsRev.xls, ctitle(Year_IND FE)
*outreg2 using regressions3.xls, ctitle(Year_IND FE)





