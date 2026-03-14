ssc install kountry
ssc inst _gwtmean

sdmxuse data OECD, clear dataset(SNA_TABLE4) dimensions(CHE+EST+BEL+ESP+PRT+HUN+CZE+POL+EA19+CAN+FIN+SWE+SAU+GRC+BGR+NOR+CYP+IND+GBR+FRME+USA+MLT+LVA+ITA+NLD+FRA+SVN+JPN+IDN+SVK+LUX+EU28+ISR+ZAF+MEX+COL+ISL+TUR+KOR+DEW+CRI+DEU+NZL+ROU+AUT+AUS+DNK+NMEC+RUS+LTU+BRA+CHN+CHL+IRL+HRV.EXC.CD) panel(location)

drop transact measure

rename value EXC_CD

destring time, replace

save "OECD EXC_CD", replace


sdmxuse data OECD, clear dataset(SNA_TABLE9B) dimensions(CHE+EST+BEL+ESP+PRT+HUN+CZE+POL+EA19+CAN+FIN+SWE+SAU+GRC+BGR+NOR+CYP+IND+GBR+FRME+USA+MLT+LVA+ITA+NLD+FRA+SVN+JPN+IDN+SVK+LUX+EU28+ISR+ZAF+MEX+COL+ISL+TUR+KOR+DEW+CRI+DEU+NZL+ROU+AUT+AUS+DNK+NMEC+RUS+LTU+BRA+CHN+CHL+IRL.N11+N111.NS1+NS11+NS12.C) panel(location)


destring time, replace


save "OECD Table 9b", replace
use "OECD Table 9b", clear

merge 1:1 location time using countryyearlist, gen(merge2)

kountry location, from(iso3c) to(iso3n)
rename _ISO locnum
replace locnum=100019 if location=="EA19"
replace locnum=100028 if location=="EU28"
sort location time




foreach x in _ns11 _ns12 _ns1{

label var n111`x' "tangible fixed asset`x'"
label var n11`x' "fixed assets`x'"
gen tangibleshare`x'=n111`x'/ n11`x'
}


*S1 = Total economy , S11 = Financial corp, S12 = Non financial corp
merge 1:1  location time using "OECD EXC_CD", gen(merge1)
drop if merge1==2
drop merge1

foreach x in n111_ns1 n111_ns11 n111_ns12 n11_ns1 n11_ns11 n11_ns12 {
replace `x'=`x'/EXC_CD
}


merge 1:1  location time using "GDPprCapita", gen(mergeGDPprcap)
drop if mergeGDPprcap==2
drop mergeGDPprcap

egen rank=rank(GDPprCap), by(time)
egen maxrank=max(rank), by(time)
gen pcttile=rank/maxrank


egen inc_group=cut(pcttile), group(4)


gen corp_fixed_assets=n11_ns11+n11_ns12
gen corp_tangible_fixed_assets=n111_ns11+n111_ns12


***IMPUTATIONS BEGIN*** first attempt is to impute subelements 

*Imputing the following time based on last time + GDP growth 

merge 1:1 location time using GDPWEO1990to2017, gen(merge3)
drop if merge3==2


tsset locnum time
foreach var in n111_ns1 n111_ns11 n111_ns12 n11_ns1 n11_ns11 n11_ns12 {
replace `var'=L1.`var'*(GDP/L1.GDP) if `var'==.
}

replace corp_fixed_assets=n11_ns11+n11_ns12
replace corp_tangible_fixed_assets=n111_ns11+n111_ns12

foreach x in _ns11 _ns12 _ns1{
egen sumtangibleshare`x'= wtmean(tangibleshare`x'), by(time)
replace n111`x'=sumtangibleshare`x'*n11`x' if n111`x'==.
}

replace corp_fixed_assets=n11_ns11+n11_ns12
replace corp_tangible_fixed_assets=n111_ns11+n111_ns12

tabout country using TangibleAsset2015.xls if time==2015, replace sum c(sum n11_ns1 sum n11_ns11 sum n11_ns12 sum n111_ns1 sum n111_ns11  sum n111_ns12 sum corp_tangible_fixed_assets) h2(2015 with imputations)  format(5)

