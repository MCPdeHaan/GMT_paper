cd "/Users/ludvigwier/Dropbox/International tax enforcement/DataWork/Capital intensity"

import excel "/Users/ludvigwier/Dropbox/International tax enforcement/DataWork/Capital intensity/Part II B1-2-B12.xls", sheet("Table II.B 1-2") cellrange(A6:N96) firstrow clear

rename A country

drop if country==""

keep country Propertyplantandequipment Total

rename Total Totalassets

drop if country=="Other"

save Btables_2015, replace

import excel "/Users/ludvigwier/Dropbox/International tax enforcement/DataWork/Capital intensity/Part II F1-F9.xls", sheet("Table II.F 1") cellrange(A5:G94) firstrow clear

rename A country

drop if country==""

keep country Comp Profit

drop if country=="Other"

merge  1:1 country using Btables_2015

destring Comp-Propertyplantandequipment, force replace

save B_F_tables2015, replace

import excel "/Users/ludvigwier/Dropbox/International tax enforcement/DataWork/Capital intensity/Part II G1-G5.xls", sheet("Table II.G 1") cellrange(A5:G94) firstrow clear
rename A country
drop if country==""
drop if country=="Other"
rename All numberofemployees

destring numberofemployees, force replace

merge  1:1 country using B_F_tables2015, gen(merge2)

gen pi=Profittype/Comp

gen ProfprEmp=Profittype/numberofemployees

gen TprC=Propertyplantandequipment/Comp

gen profit_pr_T=Profit/Propertyplantandequipment

tabout country using pi.xls, replace sum c(sum pi sum TprC sum profit_pr_T sum Propertyplantandequipment sum Compensation sum Profit sum ProfprEmp sum numberofemployees) f(50)

do one with more commas havens seperated and country codes

