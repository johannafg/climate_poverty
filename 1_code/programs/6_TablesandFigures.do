* ------------------------------------------------------------------------------
*     
*     	DATA ANALYSIS 1/3 
*     	Global Poverty Estimates of Climate Warming    
*                     
*-------------------------------------------------------------------------------

/* -----------------------------------------------------------------------------
	do-file comprises of data preparation and analysis steps:								  
	1. Figures         
	Tables1.xlsx
	Regions_growth.png
 ---------------------------------------------------------------------------- */


* Define filepaths
global datain = "$swdLocal\2_data\data_in"
global dataout = "$swdLocal\2_data\data_out"
global temp = "$swdLocal\3_output\temp"
global output = "$swdLocal\3_output\Tabs_Figs"


//1- Compare the growth by scenarios.
use "${dataout}\GDPcap_noCC.dta", clear 
gen case = "noCC"
append using "${dataout}\GDPcap_CC.dta"
replace case = "CC" if case==""

append using "${datain}\growth_GDP_MPO_AM2024.dta" 
replace gr = gr_new if case==""
drop gr_new
replace code = iso3 if case==""
replace case = "MPO" if case==""
export excel _all using "${dataout}\GDPcap_CC_noCC", firstrow(variables) replace

merge m:1 code using "${datain}\code_inc_regpcn_latest.dta", keepus(incgroup_hist ssa_subregion_code pcn_region_code)
drop if _m==2
drop _m

groupfunction, mean(gr) by(case pcn_region_code year)

keep if year<=2050 
la var pcn_region_code "Region"
 
twoway (line gr year if case=="CC", sort lpattern(dash)) (line gr year if case=="noCC", sort lpattern(solid)), ytitle(Growth per capita) xtitle(Year) by(, legend(on)) scheme(white_tableau) by(pcn_region_code) legend(row(1) pos(6) order(1 "Climate change" 2 "No climate change"))
graph export "${output}\Regions_growth.png", replace

twoway (line gr year if case=="CC", sort lpattern(dash)) (line gr year if case=="noCC", sort lpattern(solid)) (line gr year if case=="MPO", sort lpattern(dash dot)), ytitle(Growth per capita) xtitle(Year) by(, legend(on)) scheme(white_tableau) by(pcn_region_code) legend(row(1) pos(6) order(1 "Climate change" 2 "No climate change" 3 "MPO")) 
graph export "${output}\Regions_growth2.png", replace


//2-Between and within inequality of GDPpc by scenarios (Gini type index)

use "${dataout}\GDPcap_noCC.dta", clear
gen case = "noCC"
append using "${dataout}\GDPcap_CC.dta"
replace case = "CC" if case==""
keep if year>=2022 
replace case = "Climate change" if case=="CC"
replace case = "No climate change" if case=="noCC"

groupfunction [aw=pop], gini(gdppc) by(case  year)
replace gdppc = gdppc*100
table (year) (case), statistic(mean gdppc) nototal nformat(%4.2f)
collect style header year case , title(hide)
collect preview
collect export "$output\Tables1.xlsx", sheet(Gini_of_gdp, replace) modify

use "${dataout}\GDPcap_noCC.dta", clear
gen case = "noCC"
append using "${dataout}\GDPcap_CC.dta"
replace case = "CC" if case==""
keep if year>=2022 

merge m:1 code using "${datain}\code_inc_regpcn_latest.dta", keepus(incgroup_hist ssa_subregion_code pcn_region_code)
drop if _m==2
drop _m

encode code, gen(code2)
encode incgroup_hist, gen(incgroup_hist2)
encode pcn_region_code, gen(pcn_region_code2)
encode case, gen(case2)


//by income groups
cap mat drop inc
levelsof case2, local(caselist)
foreach cc of local caselist {
	forv y=2022(1)2050 {
		ineqdecgini gdppc if case2==`cc' & year==`y' [aw=pop], by(incgroup_hist2)	
		local res = r(residual_pc)
		local bw = r(gini_b_pc)
		local wt = r(gini_w_pc)
		mat inc = (nullmat(inc) \ (`cc', `y', `bw',`wt',`res' ))
	}
}
mat list inc

return list


//by income groups
cap mat drop inc
levelsof case2, local(caselist)
foreach cc of local caselist {
	forv y=2022(1)2099 {
		ineqdecgini gdppc if case2==`cc' & year==`y' [aw=pop], by(incgroup_hist2)	
		local res = r(residual_pc)
		local bw = r(gini_b_pc)
		local wt = r(gini_w_pc)
		mat inc = (nullmat(inc) \ (`cc', `y', `bw',`wt',`res' ))
	}
}
mat list inc

return list



//by income groups
cap mat drop inc
levelsof case2, local(caselist)
foreach cc of local caselist {
	forv y=2022(1)2050 {
		ineqdecgini gdppc if case2==`cc' & year==`y' [aw=pop], by(pcn_region_code2)	
		local res = r(residual_pc)
		local bw = r(gini_b_pc)
		local wt = r(gini_w_pc)
		mat inc = (nullmat(inc) \ (`cc', `y', `bw',`wt',`res' ))
	}
}
mat list inc

return list



//by income groups
cap mat drop inc
levelsof case2, local(caselist)
foreach cc of local caselist {
	forv y=2022(1)2099 {
		ineqdecgini gdppc if case2==`cc' & year==`y' [aw=pop], by(pcn_region_code2)	
		local res = r(residual_pc)
		local bw = r(gini_b_pc)
		local wt = r(gini_w_pc)
		mat inc = (nullmat(inc) \ (`cc', `y', `bw',`wt',`res' ))
	}
}
mat list inc

return list

		  
		  