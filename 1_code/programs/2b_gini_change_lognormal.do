* ------------------------------------------------------------------------------
*     
*     	DATA PREPARATION 8/11
*     	Global Poverty Estimates of Climate Warming    
*                     
*-------------------------------------------------------------------------------

/* -----------------------------------------------------------------------------
	   do-file comprises of data preparation and analysis steps:								  
	   1. Poverty projection assuming changes in Gini (annualized)
	   * Creates Ginis_and_sigmas.dta
	   * Creates Tables_gini_${case}.xlsx
---------------------------------------------------------------------------- */

set more off

* Define filepaths
global datain = "$swdLocal\2_data\data_in"
global dataout = "$swdLocal\2_data\data_out"
global temp = "$swdLocal\3_output\temp"


clear all

use "$datain\GlobalDist1000bins_2022_apr24.dta", clear 
levelsof code, local(thecodes) clean


gen lnW = ln(welf)
local pline = ln(2.15)

groupfunction [aw=pop], gini(welf) mean(lnW) by(code) merge

sum wgini
local ll = r(min)
local ul = 1.2*r(max)

clear all
local a = 1

forval z=0(0.00001)2{
	set obs `a'
	if (`a'==1){
		gen gini = .
		gen sigma = .
	}
	replace gini  = 2*normal(`z'/sqrt(2))-1 in `a'
	replace sigma = `z' in `a'
	local ++a
}
save "${dataout}\Ginis_and_sigmas.dta", replace


* Define globals

global yearcut 2050 
global distyear 2022 
global distfile GlobalDist1000bins_2022_apr24.dta 
global passthrough 1



/* -----------------------------------------------------------------------------
	   **** WITH CLIMATE CHANGE
---------------------------------------------------------------------------- */

 

global case CC

clear
tempfile data1 data2 dataall data3 data4 datareg
save `dataall', replace emptyok

//load sigma and gini
use "${dataout}\Ginis_and_sigmas", clear
sort gini
putmata ginis=gini sigmas=sigma, replace

//Growth data
use "${dataout}\GDPcap_${case}", clear

keep if year>=${distyear}
replace gr = gr/100
clonevar gr_old1 = gr

merge m:1 code using "${datain}\PIP_lineup2022_welftype" 
drop if _m==2

gen passthrough = $passthrough if _m==1
replace passthrough = 1 if _m==3 & welfare_type==2
replace passthrough = 0.7 if _m==3 & welfare_type==1

drop _m
global growthlist gr
foreach var of global growthlist {
	replace `var' = 1 + ((passthrough*`var'))
}

//cumulative growth
foreach var of global growthlist {
	bys code (year): gen double `var'1 = sum(ln(`var'))
	replace `var'1 = exp(`var'1)
	ren `var' old`var'
	ren `var'1 `var'
}

drop if year > ${yearcut}
tempfile data1

save `data1', replace

//load binned data
use "$datain\\${distfile}", clear

foreach num of numlist 215 365 685 322 547 1027 {	
	gen p0_`num' = welf < `=`num'/100'	
}

clonevar gini = welf
gen double lnwelf = ln(welf)

qui groupfunction [aw=pop], by(code) gini(gini) mean(lnwelf welf p0_*) 

gen sigma_0 = invnormal((gini+1)/2)*sqrt(2)
foreach num of numlist 215 365 685 322 547 1027 {	
	gen double p1_`num' = normal((ln(`=`num'/100')  - lnwelf)/sigma_0)
	gen double adj_`num' = p0_`num'/p1_`num'
}

drop p0_* p1_*
save `data2', replace

use `data1', clear
merge m:1 code using `data2'
keep if _m==3
drop _m


gen double lnnewmean = lnwelf + ln(gr)
sum year


local start  = r(min) //-1
local ending = r(max)

forval z = 0/20{
	local annualized = (1+`z'/100)^(1/(`ending'-`start'))-1	
	gen double gini_`z' = gini*(1+`annualized') if year == `=`start'+1'
	bysort iso3 (year): replace gini_`z' = gini_`z'[_n-1]*(1+`annualized') if year!= `=`start'+1'
}


//Bring sigma in within country loop
cap drop pov_gini*
cap drop lasigma
local all = _N

forval j = 0/20{
	gen double lasigma = invnormal((gini_`j'+1)/2)*sqrt(2)
	qui: sum lasigma if year==2050
	di "Avg. sigma for `j'= `r(mean)'"
	foreach line of numlist 215 365 685 322 547 1027{
		if (`j'!=0) gen double pov_gini`j'_`line' = (normal((ln(`=`line'/100')  - lnnewmean)/lasigma))*adj_`line' 
		else{			
			gen double pov_gini`j'_`line' = (normal((ln(`=`line'/100')  - lnnewmean)/lasigma))*adj_`line'
		}
	}

	drop lasigma
}

	
keep code year pov_gini*
reshape long pov_gini, i(code year) j(pline) string
split pline, parse("_")
drop pline
ren pline1 ginicase
ren pline2 pline
destring ginicase pline, replace

gen esttype = 1
la def esttype 1 "nowcast" 2 "survey"
la val esttype esttype



//bring in actual 2022 data 
merge m:1 code year pline using "${datain}\PIP_survey_pline", keepus(headcount)
replace pov_gini = headcount if _m==3
replace esttype = 2 if _m==3
drop if _m==2
drop _m headcount

//merge in regional code
merge m:1 code using "${datain}\code_inc_regpcn_latest.dta", keepus(incgroup_hist ssa_subregion_code pcn_region_code)
save `data3', replace

//save country list with no data for regional value
keep if _m==2
keep pcn_region_code code ginicase
drop ginicase
expand 21, gen(num)
bysort code : gen ginicase = _n-1
drop num
save `data4', replace


//merge in pop data
use `data3', clear
drop if _m==2
drop _m

merge m:1 code year using "$dataout\UN_pop", keepus(pop)
drop if _m==2
drop _m
gen double npoor = pov_gini*pop
save `data2', replace

//regional average
collapse (sum) npoor pop, by(ginicase pcn_region_code year pline)
gen double regpov = npoor/pop
drop npoor pop
joinby ginicase pcn_region_code using `data4'
ren regpov pov_gini
save `datareg', replace


use `data3', clear
drop if _m==2
drop _m
append using `datareg'
merge m:1 code year using "$dataout\UN_pop", keepus(pop)
drop if _m==2
drop _m
gen double npoor = pov_gini*pop
gen method = "Gini"
sort ginicase code year

cap drop temp*
gen temp=pov_gini if year==2022 & ginicase==0
bys code year pline: egen temp2 = max(temp)
replace pov_gini=temp2 if year==2022
cap drop temp*

saveold "$dataout\\Ctrylvl_Gini_${case}", replace

//Prep agg data file
use "$dataout\\Ctrylvl_Gini_${case}", clear

collapse (sum) npoor pop, by(ginicase year pcn_region_code pline)
gen double povrate = (npoor/pop)*100
tempfile datax1
save `datax1', replace

collapse (sum) npoor pop, by(ginicase year pline)
gen double povrate = (npoor/pop)*100
gen pcn_region_code = "WLD"
append using `datax1'
saveold "$dataout\\Agg_Gini_${case}", replace


export excel using "$dataout\check_global_proj_lognormal_CC.xlsx", replace firstrow(variable)




/* -----------------------------------------------------------------------------
	   **** WITHOUT CLIMATE CHANGE
---------------------------------------------------------------------------- */

global case noCC


clear
tempfile data1 data2 dataall data3 data4 datareg
save `dataall', replace emptyok

//load sigma and gini
use "${dataout}\Ginis_and_sigmas", clear
sort gini
putmata ginis=gini sigmas=sigma, replace

//Growth data
use "${dataout}\GDPcap_${case}", clear

keep if year>=${distyear}
replace gr = gr/100
clonevar gr_old1 = gr

merge m:1 code using "${datain}\PIP_lineup2022_welftype" 
drop if _m==2

gen passthrough = $passthrough if _m==1
replace passthrough = 1 if _m==3 & welfare_type==2
replace passthrough = 0.7 if _m==3 & welfare_type==1

drop _m
global growthlist gr
foreach var of global growthlist {
	replace `var' = 1 + ((passthrough*`var'))
}

//cumulative growth
foreach var of global growthlist {
	bys code (year): gen double `var'1 = sum(ln(`var'))
	replace `var'1 = exp(`var'1)
	ren `var' old`var'
	ren `var'1 `var'
}

drop if year > ${yearcut}
tempfile data1

save `data1', replace

//load binned data
use "$datain\\${distfile}", clear

foreach num of numlist 215 365 685 322 547 1027 {	
	gen p0_`num' = welf < `=`num'/100'	
}

clonevar gini = welf
gen double lnwelf = ln(welf)

qui groupfunction [aw=pop], by(code) gini(gini) mean(lnwelf welf p0_*) 

gen sigma_0 = invnormal((gini+1)/2)*sqrt(2)
foreach num of numlist 215 365 685 322 547 1027 {	
	gen double p1_`num' = normal((ln(`=`num'/100')  - lnwelf)/sigma_0)
	gen double adj_`num' = p0_`num'/p1_`num'
}

drop p0_* p1_*
save `data2', replace

use `data1', clear
merge m:1 code using `data2'
keep if _m==3
drop _m


gen double lnnewmean = lnwelf + ln(gr)
sum year
local start  = r(min) 
local ending = r(max)

forval z = 0/20{
	local annualized = (1+`z'/100)^(1/(`ending'-`start'))-1	
	gen double gini_`z' = gini*(1+`annualized') if year == `=`start'+1'
	bysort iso3 (year): replace gini_`z' = gini_`z'[_n-1]*(1+`annualized') if year!= `=`start'+1'
}


//Bring sigma in within country loop
local all = _N
forval j = 0/20 {
	gen double lasigma = invnormal((gini_`j'+1)/2)*sqrt(2)
	qui: sum lasigma if year==2050
	di "Avg. sigma for `j'= `r(mean)'"
	foreach line of numlist 215 365 685 322 547 1027{
		if (`j'!=0) gen double pov_gini`j'_`line' = (normal((ln(`=`line'/100')  - lnnewmean)/lasigma))*adj_`line'
		else{			
			gen double pov_gini`j'_`line' = (normal((ln(`=`line'/100')  - lnnewmean)/lasigma))*adj_`line'
		}
	}

	drop lasigma
}


keep code year pov_gini*
reshape long pov_gini, i(code year) j(pline) string
split pline, parse("_")
drop pline
ren pline1 ginicase
ren pline2 pline
destring ginicase pline, replace

gen esttype = 1
la def esttype 1 "nowcast" 2 "survey"
la val esttype esttype

//bring in actual 2022 data 
merge m:1 code year pline using "${datain}\PIP_survey_pline", keepus(headcount)
replace pov_gini = headcount if _m==3
replace esttype = 2 if _m==3
drop if _m==2
drop _m headcount

//merge in regional code
merge m:1 code using "${datain}\code_inc_regpcn_latest.dta", keepus(incgroup_hist ssa_subregion_code pcn_region_code)
save `data3', replace

//save country list with no data for regional value
keep if _m==2
keep pcn_region_code code ginicase
drop ginicase
expand 21, gen(num)
bysort code : gen ginicase = _n-1
drop num
save `data4', replace


//merge in pop data
use `data3', clear
drop if _m==2
drop _m

merge m:1 code year using "$dataout\UN_pop", keepus(pop)
drop if _m==2
drop _m
gen double npoor = pov_gini*pop
save `data2', replace

//regional average
collapse (sum) npoor pop, by(ginicase pcn_region_code year pline)
gen double regpov = npoor/pop
drop npoor pop
joinby ginicase pcn_region_code using `data4'
ren regpov pov_gini
save `datareg', replace


use `data3', clear
drop if _m==2
drop _m
append using `datareg'
merge m:1 code year using "$dataout\UN_pop", keepus(pop)
drop if _m==2
drop _m
gen double npoor = pov_gini*pop
gen method = "Gini"
sort ginicase code year

cap drop temp*
gen temp=pov_gini if year==2022 & ginicase==0
bys code year pline: egen temp2 = max(temp)
replace pov_gini=temp2 if year==2022
cap drop temp*


saveold "$dataout\\Ctrylvl_Gini_${case}", replace


//Prep agg data file
use "$dataout\\Ctrylvl_Gini_${case}", clear

collapse (sum) npoor pop, by(ginicase year pcn_region_code pline)
gen double povrate = (npoor/pop)*100
tempfile datax1
save `datax1', replace

collapse (sum) npoor pop, by(ginicase year pline)
gen double povrate = (npoor/pop)*100
gen pcn_region_code = "WLD"
append using `datax1'
saveold "$dataout\\Agg_Gini_${case}", replace



export excel using "$dataout\check_global_proj_lognormal_noCC.xlsx", replace firstrow(variable)
	

