* ------------------------------------------------------------------------------
*     
*     	DATA ANALYSIS 3/3
*     	Global Poverty Estimates of Climate Warming    
*                     
*-------------------------------------------------------------------------------

/* -----------------------------------------------------------------------------
	do-file comprises of data preparation and analysis steps:								  
	1. Other output: Percent point change/difference in poverty - Climate Change vs No climate change
	* Add diffs to PovClim_v01.xlsx
                      			  
 ---------------------------------------------------------------------------- */

 
set more off
clear all

* Define filepaths
global datain = "$swdLocal\2_data\data_in"
global dataout = "$swdLocal\2_data\data_out"
global temp = "$swdLocal\3_output\temp"
global output = "$swdLocal\3_output\Tabs_Figs"


*===============================================================================
// Import country level results	
*===============================================================================
use "$dataout\Ctrylvl_neutral_CC.dta", clear
	rename povrate neutral_cc
	merge 1:1 pline method year code using "$dataout\Ctrylvl_neutral_noCC.dta"
		drop if _m==2
		drop _m
		
	rename povrate neutral_nocc
		
	gen diff = 100*(neutral_cc/neutral_nocc -1)
	gen pp_diff = 100*(neutral_cc - neutral_nocc)
	
	keep code year pline  incgroup_hist pop diff pp_diff pcn_region_code
	gen method = "Neutral"
	keep if inlist(pline,215,365,685)
	levelsof pline, local(plines)
	levelsof year, local(years)
	
	
tempfile neutral
save `neutral'
	
/*	use "$dataout\Ctrylvl_Demo_CC.dta", clear
	rename povrate demo_cc
	
	merge 1:1 pline method year code using "$dataout\Ctrylvl_Demo_noCC.dta"
		drop if _m==2
		drop _m
	
	rename povrate demo_nocc
	
	gen diff = 100*(demo_cc/demo_nocc - 1)
	gen pp_diff = 100*(demo_cc - demo_nocc)
	
	keep code year pline  incgroup_hist pop diff pp_diff
	gen method = "Demographic"
	keep if inlist(pline,215,365,685)
	levelsof pline, local(plines)
	levelsof year, local(years)
		
	append using `neutral'
*/
	
	lab var diff "Percent change in poverty - Climate Change vs No climate change"
	lab var pp_diff "Percent point difference in poverty - Climate Change vs No climate change"
	
	egen thegroups = group(method pline year)
	sum thegroups
	local top = r(max)
	
	foreach var in pp_diff diff{
		gen Q5_`var' = ""
		gen Qo_`var' = .
		forval groups = 1/`top'{
			xtile _x = `var' if thegroups==`groups', nq(5)
			forval z=1/5{
				sum `var' if _x==`z'
				local min = round(`r(min)',0.01)
				local min = trim("`: dis %10.2f `min''")
				local max = round(`r(max)',0.01)
				local max = trim("`: dis %10.2f `max''")
				if (`z'==1) replace Q5_`var' = "`min' - `max'" if _x==`z' & thegroups==`groups'
				else replace Q5_`var' = "`old_max' - `max'" if _x==`z' & thegroups==`groups'
				replace Qo_`var' = `z' if _x==`z' & thegroups==`groups'
				local old_max = "`max'"
			}
			drop _x
		}
	}
	
	
	
export excel using "$output\PovClim_v01.xlsx", sheet(country_level_diff) sheetreplace first(varlab)
	
	
