eurostatuse bop_fdi6_inc, clear

drop if nace_r2!="FDI"
drop if entity=="SPE"

gen keep=0
foreach name in "Direct investment in the reporting economy"	"Direct investment in the reporting economy; Income on debt"	"Direct investment abroad; Dividends"	"Direct investment abroad; Reinvested earnings"	"Direct investment abroad"	"Direct investment abroad; Income on debt"	"Direct investment in the reporting economy; Dividends"	"Direct investment in the reporting economy; Reinvested earnings"	"Direct investment in the reporting economy"	"Direct investment in the reporting economy; Income on debt" {
replace keep=1 if fdi_item_l=="`name'"
}

drop if keep==0
drop keep

* First strictly logical replacement 3rd variable when net and credit exists and so on...
sort geo partner fdi_item_l
by geo partner fdi_item_l: gen count_aux=1 if bop_fdi6_inc2015!=.
by geo partner fdi_item_l: gen count_aux2=1
egen sum_aux= sum(count_aux), by(geo partner fdi_item_l)
egen sum_aux2= sum(count_aux2), by(geo partner fdi_item_l)

gen credit_aux=bop_fdi6_inc2015 if stk_flow=="CRE"
gen debit_aux=bop_fdi6_inc2015 if stk_flow=="DEB"
gen netIO_aux= bop_fdi6_inc2015 if stk_flow=="IO"
gen netII_aux= bop_fdi6_inc2015 if stk_flow=="II"

gen direction=substr(fdi_item,1,2)


egen sum_credit_aux= sum(credit_aux), by(geo partner fdi_item_l)
egen sum_debit_aux= sum(debit_aux), by(geo partner fdi_item_l)
egen sum_netIO_aux= sum(netIO_aux), by(geo partner fdi_item_l)
egen sum_netII_aux= sum(netII_aux), by(geo partner fdi_item_l)


*net=credit - debit when abroad <=> credit = debit+net
gen test=sum_debit_aux + sum_netIO_aux
replace bop_fdi6_inc2015=test if bop_fdi6_inc2015==. & sum_aux==2 & sum_aux2==3 & stk_flow =="CRE" & direction=="DO"
drop test

*net=debit- credit when DIR<=> credit= debit-net
gen test =sum_debit_aux - sum_netII_aux
replace bop_fdi6_inc2015 =test if bop_fdi6_inc2015==. & sum_aux==2 & sum_aux2==3 & stk_flow =="CRE" & direction=="DI"
drop test


***reinvested earnings can only be in the country where the investment is ==> DIA only Credit and IO exists and for DIR only Debit and IO exists

gen test= sum_netIO_aux
replace bop_fdi6_inc2015=test if bop_fdi6_inc2015==. & sum_aux==1 & sum_aux2==2 & stk_flow=="CRE" & fdi_item_label=="Direct investment abroad; Reinvested earnings"
drop test

gen test= sum_netII_aux
replace bop_fdi6_inc2015=test if bop_fdi6_inc2015==. & sum_aux==1 & sum_aux2==2 & stk_flow=="DEB" & fdi_item_label=="Direct investment in the reporting economy; Reinvested earnings"
drop test

*net=credit - debit when abroad <=> debit = credit - net
gen test=sum_credit_aux - sum_netIO_aux
replace bop_fdi6_inc2015=test if bop_fdi6_inc2015==. & sum_aux==2 & sum_aux2==3 & stk_flow =="DEB" & direction=="DO"
drop test

*net=debit - credit when in reporting  <=> debit = credit + net
gen test=sum_credit_aux + sum_netII_aux
replace bop_fdi6_inc2015=test if bop_fdi6_inc2015==. & sum_aux==2 & sum_aux2==3 & stk_flow =="DEB" & direction=="DI"
drop test

drop count_aux count_aux2 sum_aux sum_aux2 credit_aux debit_aux netIO_aux netII_aux sum_credit_aux sum_debit_aux sum_netIO_aux sum_netII_aux


save basic, replace
