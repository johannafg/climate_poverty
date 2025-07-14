
* ------------------------------------------------------------------------------
*     
*     	DATA ANALYSIS b/3
*     	Global Poverty Estimates of Climate Warming    
*                     
*-------------------------------------------------------------------------------

/* -----------------------------------------------------------------------------
	do-file comprises of data preparation and analysis steps:								  
	1. Inputs for Tableau using GIC
                      			  
 ---------------------------------------------------------------------------- */


set more off
clear all

* Define filepaths
global datain = "$swdLocal\2_data\data_in"
global dataout = "$swdLocal\2_data\data_out"
global temp = "$swdLocal\3_output\temp"
global output = "$swdLocal\3_output\Tabs_Figs"


*===============================================================================
// Bring in data
*===============================================================================

use "$dataout\Agg_neutral_CC.dta", clear
	gen TYPE = "Neutral dist - Climate change"
	
	append using "$dataout\Agg_neutral_noCC.dta"
	replace TYPE = "Neutral dist - No climate change" if missing(TYPE)
	
	append using "$dataout\Agg_Gini_GIC_CC.dta"
	replace TYPE = "Gini_GIC" if missing(TYPE)
	
	append using "$dataout\the2022data.dta"
	replace TYPE = "The OG" if missing(TYPE)

export excel using "$output\PovClim.xlsx", sheet(region_wld_GIC) sheetreplace first(variable) //Agg 

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

export excel using "$output\PovClim_v01.xlsx", sheet(region_wld_GIC) sheetreplace first(varlab) //Agg with inlist(pline,215,365,685)


*===============================================================================
// Bring in country level data
*===============================================================================
use "$dataout\Ctrylvl_neutral_CC.dta", clear
	gen TYPE = "Neutral dist - Climate change"
	gen case = "CC"
	
	append using "$dataout\Ctrylvl_neutral_noCC.dta"
	replace TYPE = "Neutral dist - No climate change" if missing(TYPE)
	replace case = "noCC" if missing(case)
	
	append using "$dataout\Ctrylvl_Gini_GIC_CC.dta"
	replace TYPE = "Gini_GIC" if missing(TYPE)
	
export excel using "$output\PovClim.xlsx", sheet(country_level_GIC) sheetreplace first(variable) //Ctrylvl

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
	
export excel using "$output\PovClim_v01.xlsx", sheet(country_level_GIC) sheetreplace first(varlab) //Ctrylvl with inlist(pline,215,365,685)
