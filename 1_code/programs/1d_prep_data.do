* ------------------------------------------------------------------------------
*     
*     	DATA PREPARATION 5/11
*     	Global Poverty Estimates of Climate Warming    
*                     
*-------------------------------------------------------------------------------

/* -----------------------------------------------------------------------------
	do-file comprises of data preparation and analysis steps:								  
	1. Convert future growth data from Burke et al.    
	* Creates GDPcap_CC.dta
	* Creates GDPcap_noCC.dta
 ---------------------------------------------------------------------------- */


*run "C:\Users\wb480081\OneDrive - WBG\Documents\Poverty_EAP\FY25\Global\Poverty_Climate\replication_package\0_master.do"

* Define filepaths
global datain = "$swdLocal\2_data\data_in"
global dataout = "$swdLocal\2_data\data_out"

//Prepare growth data


/* -----------------------------------------------------------------------------
**** WITH CLIMATE CHANGE
 ---------------------------------------------------------------------------- */
 
 
import delimited using "${datain}\GDPcap_ClimateChange_RCP85_SSP5.csv", clear varnames(1)
ds3 v*
local clist = r(varlist)
foreach v of local clist {
	local x : variable label `v'
	ren `v' y`x'
}
drop meantemp
reshape long y, i(iso3 iso2 name) j(year)
gen type = "WithCC"
ren y gdppc
clonevar code = iso3
merge 1:1 code year using "${dataout}\UN_pop.dta", keepus(pop) //UN pop projections start in 2024
drop if _m==2
drop _m
clonevar countrycode = code
bys code (year): gen gr = (gdppc[_n]/gdppc[_n-1]-1)*100
la var gr "Growth (%)"
compress
saveold "${dataout}\GDPcap_CC", replace




/* -----------------------------------------------------------------------------
**** WITHOUT CLIMATE CHANGE
 ---------------------------------------------------------------------------- */
 
 
import delimited using "${datain}\GDPcap_NOClimateChange_RCP85_SSP5.csv", clear varnames(1)
ds3 v*
local clist = r(varlist)
foreach v of local clist {
	local x : variable label `v'
	ren `v' y`x'
}
drop meantemp
reshape long y, i(iso3 iso2 name) j(year)
gen type = "NoCC"
ren y gdppc
clonevar code = iso3
merge 1:1 code year using "${dataout}\UN_pop.dta", keepus(pop) //UN pop projections start in 2024
drop if _m==2
drop _m
clonevar countrycode = code
bys code (year): gen gr = (gdppc[_n]/gdppc[_n-1]-1)*100
la var gr "Growth (%)"
compress
saveold "${dataout}\GDPcap_noCC", replace



use "${dataout}\GDPcap_CC", replace
append using "${dataout}\GDPcap_noCC", gen(CC)

merge m:1 code using "${datain}\code_inc_regpcn_latest.dta", keepus(incgroup_hist ssa_subregion_code pcn_region_code)

drop if _m==2

drop _m

keep if year > 2022  & year < 2051

table pcn_region_code type, stat(mean gr) nformat(%5.2f)