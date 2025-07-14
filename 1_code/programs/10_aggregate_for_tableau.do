* ------------------------------------------------------------------------------
*     
*     	DATA ANALYSIS 2/3
*     	Global Poverty Estimates of Climate Warming    
*                     
*-------------------------------------------------------------------------------

/* -----------------------------------------------------------------------------
	do-file comprises of data preparation and analysis steps:								  
	1. Inputs for Tableau
                      			  
 ---------------------------------------------------------------------------- */

set more off
clear all


* Define filepaths
global datain = "$swdLocal\2_data\data_in"
global dataout = "$swdLocal\2_data\data_out"
global temp = "$swdLocal\3_output\temp"
global output = "$swdLocal\3_output\Tabs_Figs"


*===============================================================================
// Bring in aggregate data
*===============================================================================

use "$dataout\Agg_neutral_CC.dta", clear
append using "$dataout\Agg_Gini_CC.dta", gen(gini)

egen double base  = max(npoor*(gini==0)), by(pline year)

egen double base0 = max(npoor*(gini==1 & ginicase==0)), by(pline year)

gen double ratio = base/base0
drop if gini==0
drop base*
cap drop temp

replace npoor = npoor*ratio
replace povrate = povrate*ratio


tempfile uno
save `uno'


use "$dataout\Agg_neutral_CC.dta", clear
	gen TYPE = "Neutral dist - Climate change"
	
	append using "$dataout\Agg_neutral_noCC.dta"
	replace TYPE = "Neutral dist - No climate change" if missing(TYPE)

	cap append using "`uno'"
	replace TYPE = "Gini" if missing(TYPE)
	cap appen using "$dataout\the2022data.dta"
	replace TYPE = "The OG" if missing(TYPE)

export excel using "$output\PovClim.xlsx", sheet(region_wld_lognormal) sheetreplace first(variable)

	lab var year "Year"
	keep if inlist(pline,215,365,685)
	gen povline = "$"+string(pline/100)
	drop pline
	lab var povline "Poverty line"
	lab var npoor "Number of poor"
	lab var pop   "Population"
	lab var povrate "Poverty rate"
	lab var pcn_region "Region/Country"
	lab var TYPE  "Projection method"
	lab var ginicase "Percentage change in Gini"

export excel using "$output\PovClim_v01.xlsx", sheet(region_wld_lognormal) sheetreplace first(varlab)


*===============================================================================
// Bring in country level data
*===============================================================================
use "$dataout\Ctrylvl_neutral_CC.dta", clear
	gen TYPE = "Neutral dist - Climate change"
	gen case = "CC"
	append using "$dataout\Ctrylvl_neutral_noCC.dta"
	replace TYPE = "Neutral dist - No climate change" if missing(TYPE)
	replace case = "noCC" if missing(case)

	cap append using "$dataout\Ctrylvl_Gini_CC.dta"
	replace TYPE = "Gini" if missing(TYPE)
	
export excel using "$output\PovClim.xlsx", sheet(country_level_lognormal) sheetreplace first(variable)

	
	lab var year "Year"
	keep if inlist(pline,215,365,685)
	gen povline = "$"+string(pline/100)
	drop pline
	lab var povline "Poverty line"
	lab var npoor "Number of poor"
	lab var pop   "Population"
	lab var povrate "Poverty rate"
	lab var pcn_region "Region/Country"
	lab var TYPE  "Projection method"
	lab var ginicase "Percentage change in Gini"
	lab var code  "Country"
	lab var incgroup_hist "Income group"
	
	keep code year povline npoor pop povrate pcn_region TYPE ginicase incgroup_hist pcn_region_code
	
export excel using "$output\PovClim_v01.xlsx", sheet(country_level_lognormal) sheetreplace first(varlab)
