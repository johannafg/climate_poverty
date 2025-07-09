* ------------------------------------------------------------------------------
*     
*     	DATA PREPARATION 4/11
*     	Global Poverty Estimates of Climate Warming    
*                     
*-------------------------------------------------------------------------------

/* -----------------------------------------------------------------------------
	do-file comprises of data preparation and analysis steps:								  
	1. Get yearly data pop from UN.       
	*  Creates UN_pop.dta
 ---------------------------------------------------------------------------- */


*run "C:\Users\wb480081\OneDrive - WBG\Documents\Poverty_EAP\FY25\Global\Poverty_Climate\replication_package\0_master.do"

* Define filepaths
global datain = "$swdLocal\2_data\data_in"
global dataout = "$swdLocal\2_data\data_out"


//Collapse UN pop to national

tempfile data1 data2

//load age gender pop
use "${datain}\popdata.dta", clear
clonevar countryname = country
drop countrycode
ren country countrycode
collapse (sum) yf* ym*, by(countrycode)
forv i=1950(1)2100 {
	egen y`i' = rowtotal(yf`i' ym`i'), missing
	drop yf`i' ym`i'
}
reshape long y, i(countrycode) j(year)
replace y = y/1000000
ren y pop
la var pop "UN pop in millions"
compress
clonevar code = countrycode
save `data1', replace // a few countries do not have projections; "fix" this below


//assuming 1% growth rate 

global gr 1

use "${datain}\code_inc_pop_regpcn.dta", clear 

expand 78 if year==2023 //projections start in 2024
bys code year: gen seq = _n

gen x = year + seq - 1 if year==2023
gen popgr = 1 if year==2023 & seq==1
bys code (year seq): replace popgr = popgr[_n-1]*(1+$gr/100) if x>=2024 & x~=.
replace year = x if year==2023
replace pop = pop *popgr if year>=2023 & year~=.
ren pop pop1
drop seq x popgr
save `data2', replace

use `data1', clear
merge 1:1 code year using `data2', keepus(pop1)

replace pop = pop1 if _m==2
replace countrycode = code if _m==2
drop pop1 _merge
saveold "${dataout}\UN_pop", replace