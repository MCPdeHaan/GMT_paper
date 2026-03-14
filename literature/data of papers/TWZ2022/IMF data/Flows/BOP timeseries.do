use IMF_BOP_1, clear

drop if n_cou=="EU high risk countries"|n_cou=="EU22"|n_cou=="Eastern Caribbean Currency Union"|n_cou=="Euro Area"

tabout n_cou using fdi_credit_debitinc.xls if year==2015, sum c(sum TotalDI_Credit sum TotalDI_Debit) format(50c)

tabout n_cou using primaryinc_net.xls if year==2015, append sum c(sum primaryinc_Net) format(50c)

*BOP items (ordered) are TotalDI (FDI income), TotalInvest (Investment income), totaltrade (Trade of goods and services), CompensationEmployees (Compensation of employees), DI_grossprof (FDI equity income),  DI_divd (FDI dividends), CA_total (Current account), DI_interest (FDI interest),  PI_divd (Portfolio dividends), PI_interest (Portfolio interest), Primaryincome_Other (Other primary income), Other (Other income), SI_corpandhh (Corporate and household secondary income),  goods (Goods trade) and services (Service trade)

foreach name in "Credit" "Debit" "Net"{
foreach x in TotalDI TotalInvest totaltrade CompensationEmployees DI_grossprof DI_divd CA_total DI_interest PI_divd PI_interest Primaryincome_Other Other SI_corpandhh goods services{ 
	quietly tabout year using timeseries_`name'.xls, append sum c(sum `x'_`name' count `x'_`name') format(50c)  
}
}


