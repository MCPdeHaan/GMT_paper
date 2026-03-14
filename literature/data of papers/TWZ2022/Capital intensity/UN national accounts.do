
*******************************************************************
******Exchange rate problems may occur before 2015*****************
*******************************************************************
* To update numbers - go to the UNdata webpage: http://data.un.org/Data.aspx?d=SNA&f=group_code%3a206%3bfiscal_year%3a1995%2c1996%2c1997%2c1998%2c1999%2c2000%2c2001%2c2002%2c2003%2c2004%2c2005%2c2006%2c2007%2c2008%2c2009%2c2010%2c2011%2c2012%2c2013%2c2014%2c2015%2c2016%2c2017%3bsub_item_code%3a24%3bitem_code%3a16&c=1,2,3,5,6,8,9,10,11,12,13,14,15&s=_cr_engNameOrderBy:asc,fiscal_year:desc,_grSbIt_code:asc&v=1

. cd "/Users/ludvigwier/Dropbox/International tax enforcement/DataWork/Capital intensity"

import delimited "/Users/ludvigwier/Dropbox/International tax enforcement/DataWork/Capital intensity/UNdata_Export_20190927_041430014", clear 

ssc install Kountry
destring countryorareacode, replace force
kountry countryorareacode, from(iso3n) to(iso3c)
rename _ISO3C_ CountryCode
save UN_NA_capitalinvestment, replace


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


use UN_NA_capitalinvestment, clear

sort countryorarea


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

merge m:1 year CountryCode using "WB exchange rates", gen(m1) /*merging in world bank exchangerates*/
keep if m1==3
drop m1

save UN_NA_capitalinvestment, replace
use UN_NA_capitalinvestment, replace

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


*Using 5% depreciation
egen minyear=min(year),by(CountryName)
drop if year>2015
gen depreciation=0.95^(2015-year)
gen depreciatedstock=USD*depreciation
gen correction=depreciatedstock/0.05 if year==minyear
replace depreciatedstock=correction if minyear==year

egen capitalstock=total(depreciatedstock), by(CountryCode)

egen maxyear=max(year), by(CountryCode)
keep if maxyear==year

gen capitalstockbillion=capitalstock/1000000000

***do tabout
tabout CountryCode using UNimputedcapitalstock2015.xls, replace sum c(sum capitalstockbillion) f(50)
