 * ------------------------------------------------------------------------------
*     
*     	DATA PREPARATION 0/11
*     	Global Poverty Estimates of Climate Warming    
*                     
*-------------------------------------------------------------------------------

/* -----------------------------------------------------------------------------
	do-file comprises of data preparation and analysis steps:								  
	1. Import Datasets          
	* Saves The2022data.dta

 ---------------------------------------------------------------------------- */

 
 
* Define filepaths
global datain = "$swdLocal\2_data\data_in"
global dataout = "$swdLocal\2_data\data_out"
global temp = "$swdLocal\3_output\temp"



clear
tempfile dataall data1
save `dataall', replace emptyok
run "$adof\findpov.ado" 
global datain = "$swdLocal\2_data\data_in"

global distfile GlobalDist1000bins_2022_apr24.dta

use "${datain}\\${distfile}", clear
levelsof code, local(clist)
collapse (sum) pop (first) region_pip , by(code year)
local gr var
foreach num of numlist 215 365 685 322 547 1027 {			
	gen pov_gr_`num' = .		
	gen double pl`num' = (`num'/100)		
}	
save `data1', replace

qui foreach c of local clist {
	use "${datain}\\${distfile}", clear
	cap ren country_code code
	*noi dis "For `c'"
	keep if code=="`c'"
	bys code year (quantile): egen x = sum(pop)
	bys code year (quantile): gen x1 = sum(pop)
	gen y = x1/x	
	sort quantile
	putmata welf=welf rate=y, replace
	
	use `data1', clear
	keep if code=="`c'"
	local all = _N
	foreach num of numlist 215 365 685 322 547 1027 {	
		forv i=1(1)`all' {			
			findpov, value(`=pl`num'[`i']')
			local v = r(povrate)
			replace pov_gr_`num' = `v' in `i'
		}
	}
	append using `dataall'
	save `dataall', replace
}


use `dataall', clear
drop pl*
reshape long pov_gr_, i(code year region_pip pop) j(pline)

gen double npoor = pop*pov_gr
rename pov_gr povrate
rename region_pip pcn_region_code

preserve
groupfunction [aw=pop], rawsum(npoor pop) mean(povrate) by(pline pcn_region)
tempfile uno
save `uno'
restore

groupfunction [aw=pop], rawsum(npoor pop) mean(povrate) by(pline)
gen pcn_region_code= "WLD"
append using `uno'
gen year=2022
save "$dataout\the2022data.dta", replace

list year pline npoor pop povrate pcn_region_code if year==2022 & pline==215
