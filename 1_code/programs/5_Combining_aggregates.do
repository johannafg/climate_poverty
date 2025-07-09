* ------------------------------------------------------------------------------
*     
*     	DATA PREPARATION 11/11 
*     	Global Poverty Estimates of Climate Warming    
*                     
*-------------------------------------------------------------------------------

/* -----------------------------------------------------------------------------
	do-file comprises of data preparation and analysis steps:								  
	1.combine AGG data  
	* Creates Tables_WLD_${case}.xlsx
 ---------------------------------------------------------------------------- */

* Define filepaths
global datain = "$swdLocal\2_data\data_in"
global dataout = "$swdLocal\2_data\data_out"
global temp = "$swdLocal\3_output\temp"
global output = "$swdLocal\3_output"


use "${dataout}\Agg_neutral_CC.dta", clear
gen case = "Climate change"

append using "${dataout}\Agg_neutral_noCC.dta"
replace case = "No Climate Change" if case==""
gen method = "neutral"


keep if year>=2022 

collect: table (year) (method case ) if pcn_region_code=="WLD" & pline==215, statistic(mean npoor) nototal nformat(%4.2f)
collect style header year case method, title(hide)
collect preview
sleep 20000

collect export "$dataout\\Tables_WLD_${case}.xlsx", sheet(povrate`num', replace) modify