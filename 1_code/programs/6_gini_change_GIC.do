* ------------------------------------------------------------------------------
*     
*     	DATA PREPARATION 8/11
*     	Global Poverty Estimates of Climate Warming    
*                     
*-------------------------------------------------------------------------------
/* -----------------------------------------------------------------------------
	   do-file comprises of data preparation and analysis steps:								  
	   1. Poverty projection with changes in gini using GIC  
	   * Creates Tables_Gini_GIC_${case}.xlsx
---------------------------------------------------------------------------- */

clear all
set more off
set maxvar 120000

global datain = "$swdLocal\2_data\data_in"
global dataout = "$swdLocal\2_data\data_out"
global temp = "$swdLocal\3_output\temp"
global output = "$swdLocal\3_output\Tables"

run "$swdLocal\1_code\ado\groupfunction.ado"
run "$swdLocal\1_code\ado\sp_groupfunction.ado"
run "$swdLocal\1_code\ado\findpov.ado"


* Define globals

global yearcut 2050 
global distyear 2022 
global distfile GlobalDist1000bins_2022_apr24.dta 
global passthrough 1
global start_year = 2022
global end_year   = 2050


/* -----------------------------------------------------------------------------
	   **** WITH CLIMATE CHANGE
---------------------------------------------------------------------------- */


global case CC

clear
tempfile data1 data2 dataall data3 data4 datareg
save `dataall', replace emptyok


//Growth data from Burke et al
use "${dataout}\GDPcap_${case}", clear

keep if year>= ${distyear} 
replace gr = gr/100
clonevar gr_old1 = gr
clonevar gr_burke = gr

merge m:1 code using "${datain}\PIP_lineup2022_welftype" 
drop if _m==2

gen passthrough = $passthrough if _m==1
replace passthrough = 1 if _m==3 & welfare_type==2
replace passthrough = 0.7 if _m==3 & welfare_type==1

drop _m


global growthlist gr
foreach var of global growthlist {
	replace `var' = 1 + ((passthrough*`var'))
	gen `var'_alt = `var' 
}

//cumulative growth
foreach var of global growthlist {
	bys code (year): gen double `var'1 = sum(ln(`var'))
	replace `var'1 = exp(`var'1)
	ren `var' old`var'
	ren `var'1 `var'
}


la var gr "cumulative growth"
la var gr_alt "annual growth, passthrued not cumulative"

drop if year > ${yearcut}
tempfile data1
levelsof code, local(clist)

local start_year = $start_year
local end_year   = $end_year

foreach ctry of local clist {
	forval z=`=$start_year+1'/$end_year {
		qui sum gr_alt if year==`z' & code=="`ctry'"
		local g_`z'_`ctry' =  r(mean)	
	}	
}


save `data1', replace

//Load binned data for 2022

local plines pline_215 pline_365 pline_685 pline_322 pline_547 pline_1027

local start_year = $start_year
local end_year   = $end_year

//Get annualized Gini Changes!
	local ending = `end_year'
	local start  = `start_year'
	
//Annualized gini change	
	forval z = 0/20 { 
		local ann_`z' = (1+`z'/100)^(1/(`ending'-`start'))-1	 //note that gini change is divided by 100
	}
	dis `ann_0'
	dis `ann_20'
		
use "$datain\\${distfile}", clear


foreach num of numlist 215 365 685 322 547 1027 {	
	gen pline_`num' = `num'/100
}

qui: levelsof code, local(thecountries)

ta code

//Remove countries with no growth data
foreach ctry of local thecountries {
	qui: if ("`g_2023_`ctry''"=="") drop if code=="`ctry'"
}

ta code 

qui: levelsof code, local(thecountries)

forval gini = 0/20 {
	forval y = 2022/2050 {
		if (`y'!=2022) {
			qui: gen cons`y'_`gini' = .
			foreach ctry of local thecountries {
				noi dis "For `ctry', year `y' and Ginicase `gini'"
				qui: replace cons`y'_`gini' = cons`=`y'-1'_`gini'*(`g_`y'_`ctry'') if code == "`ctry'" //using annual growth rates 
				qui: sum cons`y'_`gini' if code=="`ctry'" [aw=pop]
				qui: replace cons`y'_`gini' = (1+`ann_`gini'')*cons`y'_`gini' - `ann_`gini''*`r(mean)'	if code=="`ctry'"
			}
		}
		else qui: gen cons`y'_`gini' = welf
	}
}


// Note that the values for 2022 should be equal neutral distribution scenario


rename cons* cons_*
keep code cons_* pline_* pop

sp_groupfunction [aw=pop], by(code) poverty(cons_*) povertyline(pline_*) 

keep if measure=="fgt0"
split variable, parse(_)
gen double year = real(variable2)
drop variable2
gen ginicase = real(variable3)
drop variable*

foreach x of local plines {
	preserve
		keep if reference=="`x'"
		merge m:1 code using "${datain}\code_inc_regpcn_latest.dta", keepus(incgroup_hist ssa_subregion_code pcn_region_code)
		drop _m
		
		replace reference = "`x'"
		
		tempfile `x'
		save ``x''
		
	restore
}

tokenize `plines'
cap use ``1'', clear
local a = 1
while _rc==0 {
	local a = `a' + 1
	cap append using ```a'''
}

//Introduce population and get number of poor

merge m:1 code year using "$dataout\UN_pop", keepus(pop)
drop if _m==2
drop _m

groupfunction [aw=pop], mean(value) by(code ref year gini) merge

replace value = wmean_value if missing(value)

gen npoor = pop*value
drop wmean_value

gen method = "Gini GIC"
sort ginicase code year 
rename value pov_gini
rename reference pline
drop _population

ren pline pline_

gen pline=. 
replace pline = 215 if pline_=="pline_215"
replace pline = 322 if pline_=="pline_322"
replace pline = 365 if pline_=="pline_365"
replace pline = 547 if pline_=="pline_547"
replace pline = 685 if pline_=="pline_685"
replace pline = 1027 if pline_=="pline_1027"

drop pline_

save "$dataout\\Ctrylvl_Gini_GIC_${case}_full", replace

use "$dataout\\Ctrylvl_Gini_GIC_${case}_full", replace
unique code year ginicase pline

//save country list with no data for regional value assignment
preserve
keep if npoor==.
keep ginicase pcn_region_code code method
duplicates report code
duplicates drop
tempfile data4
save `data4', replace
restore

drop if npoor==.

unique code year ginicase pline

preserve
collapse (sum) npoor pop, by(ginicase pcn_region_code year pline)
gen double regpov = (npoor/pop)
drop npoor pop
joinby pcn_region_code using `data4'
merge m:1 code year using "$dataout\UN_pop", keepus(pop)
keep if _merge==3
drop _merge
unique code year ginicase pline
drop if ginicase==.
tempfile datarest
save `datarest', replace
restore

append using `datarest'

replace npoor = regpov*pop if npoor==.
replace regpov = (npoor/pop) if regpov==.
unique code year ginicase pline

ren regpov povrate

saveold "$dataout\\Ctrylvl_Gini_GIC_${case}", replace

use "$dataout\\Ctrylvl_Gini_GIC_${case}", replace

//Prep agg data file
collapse (sum) npoor pop, by(ginicase year pcn_region_code pline)
gen double povrate = (npoor/pop)*100
tempfile datax1
save `datax1', replace

collapse (sum) npoor pop, by(ginicase year pline)
gen double povrate = (npoor/pop)*100
gen pcn_region_code = "WLD"
append using `datax1'
saveold "$dataout\\Agg_Gini_GIC_${case}", replace

export excel using "$dataout\check_global_proj_GIC_CC.xlsx", replace firstrow(variable)
	

	
/* -----------------------------------------------------------------------------
**** WITHOUT CLIMATE CHANGE
---------------------------------------------------------------------------- */

global case noCC

clear
tempfile data1 data2 dataall data3 data4 datareg
save `dataall', replace emptyok


//Growth data from Burke et al
use "${dataout}\GDPcap_${case}", clear

keep if year>= ${distyear} 
replace gr = gr/100
clonevar gr_old1 = gr
clonevar gr_burke = gr

merge m:1 code using "${datain}\PIP_lineup2022_welftype" 
drop if _m==2

gen passthrough = $passthrough if _m==1
replace passthrough = 1 if _m==3 & welfare_type==2
replace passthrough = 0.7 if _m==3 & welfare_type==1

drop _m


global growthlist gr
foreach var of global growthlist {
	replace `var' = 1 + ((passthrough*`var'))
	gen `var'_alt = `var' 
}

//cumulative growth
foreach var of global growthlist {
	bys code (year): gen double `var'1 = sum(ln(`var'))
	replace `var'1 = exp(`var'1)
	ren `var' old`var'
	ren `var'1 `var'
}



la var gr "cumulative growth"
la var gr_alt "annual growth, passthrued not cumulative"

drop if year > ${yearcut}
tempfile data1
levelsof code, local(clist)

local start_year = $start_year
local end_year   = $end_year

foreach ctry of local clist {
	forval z=`=$start_year+1'/$end_year {
		qui sum gr_alt if year==`z' & code=="`ctry'"
		local g_`z'_`ctry' =  r(mean)	
	}	
}

save `data1', replace


//Load binned data for 2022

local plines pline_215 pline_365 pline_685 pline_322 pline_547 pline_1027

local start_year = $start_year
local end_year   = $end_year

//Get annualized Gini Changes!
	local ending = `end_year'
	local start  = `start_year'
	
//Annualized gini change	
	forval z = 0/20 { 
		local ann_`z' = (1+`z'/100)^(1/(`ending'-`start'))-1	 //note that gini change is divided by 100
	}
	dis `ann_0'
	dis `ann_20'
		
use "$datain\\${distfile}", clear

foreach num of numlist 215 365 685 322 547 1027 {	
	gen pline_`num' = `num'/100
}

qui: levelsof code, local(thecountries)

//Remove countries with no growth data
foreach ctry of local thecountries {
	qui: if ("`g_2023_`ctry''"=="") drop if code=="`ctry'"
}

qui: levelsof code, local(thecountries)


forval gini = 0/20 {
	forval y = 2022/2050 {
		if (`y'!=2022) {
			qui: gen cons`y'_`gini' = .
			foreach ctry of local thecountries {
				noi dis "For `ctry', year `y' and Ginicase `gini'"
				qui: replace cons`y'_`gini' = cons`=`y'-1'_`gini'*(`g_`y'_`ctry'') if code == "`ctry'" //using annual growth rates 
				qui: sum cons`y'_`gini' if code=="`ctry'" [aw=pop]
				qui: replace cons`y'_`gini' = (1+`ann_`gini'')*cons`y'_`gini' - `ann_`gini''*`r(mean)'	if code=="`ctry'"
			}
		}
		else qui: gen cons`y'_`gini' = welf
	}
}


// Note that the values for 2022 should be equal to neutral distribution scenario


rename cons* cons_*
keep code cons_* pline_* pop

sp_groupfunction [aw=pop], by(code) poverty(cons_*) povertyline(pline_*) 

keep if measure=="fgt0"
split variable, parse(_)
gen double year = real(variable2)
drop variable2
gen ginicase = real(variable3)
drop variable*

foreach x of local plines {
	preserve
		keep if reference=="`x'"
		merge m:1 code using "${datain}\code_inc_regpcn_latest.dta", keepus(incgroup_hist ssa_subregion_code pcn_region_code)
		drop _m
		
		replace reference = "`x'"
		
		tempfile `x'
		save ``x''
		
	restore
}

tokenize `plines'
cap use ``1'', clear
local a = 1
while _rc==0 {
	local a = `a' + 1
	cap append using ```a'''
}

//Introduce population and get number of poor

merge m:1 code year using "$dataout\UN_pop", keepus(pop)
drop if _m==2
drop _m

groupfunction [aw=pop], mean(value) by(code ref year gini) merge

replace value = wmean_value if missing(value)

gen npoor = pop*value
drop wmean_value

gen method = "Gini GIC"
sort ginicase code year 
rename value pov_gini
rename reference pline
drop _population

ren pline pline_

gen pline=. 
replace pline = 215 if pline_=="pline_215"
replace pline = 322 if pline_=="pline_322"
replace pline = 365 if pline_=="pline_365"
replace pline = 547 if pline_=="pline_547"
replace pline = 685 if pline_=="pline_685"
replace pline = 1027 if pline_=="pline_1027"

drop pline_


save "$dataout\\Ctrylvl_Gini_GIC_${case}_full", replace


use "$dataout\\Ctrylvl_Gini_GIC_${case}_full", replace
unique code year ginicase pline

//save country list with no data for regional value assignment
preserve
keep if npoor==.
keep ginicase pcn_region_code code method
duplicates report code
duplicates drop
tempfile data4
save `data4', replace
restore

drop if npoor==.

unique code year ginicase pline

preserve
collapse (sum) npoor pop, by(ginicase pcn_region_code year pline)
gen double regpov = (npoor/pop)
drop npoor pop
joinby pcn_region_code using `data4'
merge m:1 code year using "$dataout\UN_pop", keepus(pop)
keep if _merge==3
drop _merge
unique code year ginicase pline
drop if ginicase==.
tempfile datarest
save `datarest', replace
restore

append using `datarest'

replace npoor = regpov*pop if npoor==.
replace regpov = (npoor/pop) if regpov==.
unique code year ginicase pline

ren regpov povrate

saveold "$dataout\\Ctrylvl_Gini_GIC_${case}", replace


//Prep agg data file
collapse (sum) npoor pop, by(ginicase year pcn_region_code pline)
gen double povrate = (npoor/pop)*100
tempfile datax1
save `datax1', replace

collapse (sum) npoor pop, by(ginicase year pline)
gen double povrate = (npoor/pop)*100
gen pcn_region_code = "WLD"
append using `datax1'
saveold "$dataout\\Agg_Gini_GIC_${case}", replace


export excel using "$dataout\check_global_proj_GIC_noCC.xlsx", replace firstrow(variable)
	
