* ------------------------------------------------------------------------------
*     
*     	DATA PREPARATION 10/11
*     	Global Poverty Estimates of Climate Warming    
*                     
*-------------------------------------------------------------------------------

/* -----------------------------------------------------------------------------
	do-file comprises of data preparation and analysis steps:								  
	1.Append the country result data; Aggregate, missing countries, WLD numbers  
	* Creates Ctrylvl_Demo_${case}.dta
	* Creates Agg_Demo_${case}.dta
 ---------------------------------------------------------------------------- */

* Define filepaths
global datain = "$swdLocal\2_data\data_in"
global dataout = "$swdLocal\2_data\data_out"
global temp = "$swdLocal\3_output\temp"
global output = "$swdLocal\3_output"


//Climate scenarios with CC and noCC

/* -----------------------------------------------------------------------------
**** WITH CLIMATE CHANGE
 ---------------------------------------------------------------------------- */
 


global case CC
global passthrough 1
global n1 `=int(${passthrough}*100)'


*If needed, install the directories, and sub-directories used in the process 
foreach i in "$dataout/lineup_${case}" "$dataout/lineup_${case}_res" {
	confirmdir "`i'" 
	if _rc!=0 {
		mkdir "`i'" 
	}
	else {
		display "No action needed"		
	}
}



global output	"$datain/lineup_${case}"
global output1	"$datain/lineup_${case}_res"
global growth 	"$dataout/GDPcap_${case}.dta"
global CPI	    "$datain/Final_CPI_PPP_to_be_used.dta"
global popdemo 	"$datain/popdata.dta"



clear
tempfile data1 data2 data3 data4 datareg
save `data1', replace emptyok


local flist : dir "$output1" files "*.dta", nofail respect
 foreach file of local flist {
	use "${output1}\\`file'", clear
	reshape long pr_, i(code baseyear lineupyear) j(pline)
	append using `data1'
	save `data1', replace
}



use `data1', clear
gen case = "${case}"
ren lineupyear year
ren pr_ povrate
gen esttype = 1
la def esttype 1 "nowcast" 2 "survey" 3 "neutral"
la val esttype esttype

//drop oldcase
drop if code=="IND"

unique code year pline
cap drop dupe
duplicates tag code year pline, gen(dupe)
list code year pline povrate if dupe==1
bys code year pline: gen ndu= _n
drop if ndu==2
cap drop dupe
duplicates tag code year pline, gen(dupe)
list code year pline povrate if dupe==1
cap drop dupe
cap drop ndu

merge 1:1 code year pline using "${datain}\PIP_survey_pline", keepus(headcount)
replace povrate = headcount if _m==3
replace esttype = 2 if _m==3
drop if _m==2
drop _m headcount
tempfile datax1
save `datax1', replace


merge m:1 code using "${datain}\PIP_lineup2022_welftype.dta"
keep if _m==2
keep code
isid code
joinby code using "${dataout}\Ctrylvl_neutral_${case}.dta"
keep code year pline povrate 
gen esttype = 3
gen case = "${case}"
append using `datax1'

//merge in regional code
merge m:1 code using "$datain\code_inc_regpcn_latest.dta", keepus(incgroup_hist ssa_subregion_code pcn_region_code)
save `data3', replace

//save country list with no data for regional value
keep if _m==2
keep pcn_region_code code
save `data4', replace

//merge in pop data
use `data3', clear
drop if _m==2
drop _m
merge m:1 code year using "$dataout\UN_pop", keepus(pop)
drop if _m==2
drop _m
gen double npoor = povrate*pop
save `data2', replace

//regional average
collapse (sum) npoor pop, by(pcn_region_code year pline)
gen double regpov = npoor/pop
drop npoor pop

joinby pcn_region_code using `data4'
ren regpov povrate
save `datareg', replace

use `data3', clear
drop if _m==2
drop _m
append using `datareg'
merge m:1 code year using "$dataout\UN_pop", keepus(pop)
drop if _m==2
drop _m
gen double npoor = povrate*pop
gen method = "Demo"

saveold "$dataout\Ctrylvl_Demo_${case}", replace

//Prep agg data file
use "$dataout\Ctrylvl_Demo_${case}", clear

collapse (sum) npoor pop, by(year pcn_region_code pline)
gen double povrate = (npoor/pop)*100
tempfile datax1
save `datax1', replace

collapse (sum) npoor pop, by(year pline)
gen double povrate = (npoor/pop)*100
gen pcn_region_code = "WLD"
append using `datax1'
saveold "$dataout\\Agg_Demo_${case}", replace

//WLD average
table (year) ( pcn_region_code) if pline==215, statistic(sum npoor pop) nformat(%4.2f) 
collect style header year  pcn_region_code, title(hide)
collect preview





/* -----------------------------------------------------------------------------
**** WITHOUT CLIMATE CHANGE
 ---------------------------------------------------------------------------- */
 
 

global case noCC
*global passthrough 0.8512506 
global passthrough 1
global n1 `=int(${passthrough}*100)'



global output	"$datain/lineup_${case}"
global output1	"$datain/lineup_${case}_res"
global growth 	"$dataout/GDPcap_${case}.dta"
global CPI	    "$datain/Final_CPI_PPP_to_be_used.dta"
global popdemo 	"$datain/popdata.dta"


*If needed, install the directories, and sub-directories used in the process 
foreach i in "$datain/lineup_${case}" "$datain/lineup_${case}_res" {
	confirmdir "`i'" 
	if _rc!=0 {
		mkdir "`i'" 
	}
	else {
		display "No action needed"		
	}
}


clear
tempfile data1 data2 data3 data4 datareg
save `data1', replace emptyok


local flist : dir "$output1" files "*.dta", nofail respect
 foreach file of local flist {
	use "${output1}\\`file'", clear
	reshape long pr_, i(code baseyear lineupyear) j(pline)
	append using `data1'
	save `data1', replace
}



use `data1', clear
gen case = "${case}"
ren lineupyear year
ren pr_ povrate
gen esttype = 1
la def esttype 1 "nowcast" 2 "survey" 3 "neutral"
la val esttype esttype

//drop oldcase
drop if code=="IND"

unique code year pline

merge 1:1 code year pline using "${datain}\PIP_survey_pline", keepus(headcount)
replace povrate = headcount if _m==3
replace esttype = 2 if _m==3
drop if _m==2
drop _m headcount
tempfile datax1
save `datax1', replace


merge m:1 code using "${datain}\PIP_lineup2022_welftype.dta"
keep if _m==2
keep code
isid code
joinby code using "${dataout}\Ctrylvl_neutral_${case}.dta"
keep code year pline povrate 
gen esttype = 3
gen case = "${case}"
append using `datax1'

//merge in regional code
merge m:1 code using "$datain\code_inc_regpcn_latest.dta", keepus(incgroup_hist ssa_subregion_code pcn_region_code)
save `data3', replace

//save country list with no data for regional value
keep if _m==2
keep pcn_region_code code
save `data4', replace

//merge in pop data
use `data3', clear
drop if _m==2
drop _m
merge m:1 code year using "$dataout\UN_pop", keepus(pop)
drop if _m==2
drop _m
gen double npoor = povrate*pop
save `data2', replace

//regional average
collapse (sum) npoor pop, by(pcn_region_code year pline)
gen double regpov = npoor/pop
drop npoor pop

joinby pcn_region_code using `data4'
ren regpov povrate
save `datareg', replace

use `data3', clear
drop if _m==2
drop _m
append using `datareg'
merge m:1 code year using "$dataout\UN_pop", keepus(pop)
drop if _m==2
drop _m
gen double npoor = povrate*pop
gen method = "Demo"

saveold "$dataout\Ctrylvl_Demo_${case}", replace

//Prep agg data file
use "$dataout\Ctrylvl_Demo_${case}", clear

collapse (sum) npoor pop, by(year pcn_region_code pline)
gen double povrate = (npoor/pop)*100
tempfile datax1
save `datax1', replace

collapse (sum) npoor pop, by(year pline)
gen double povrate = (npoor/pop)*100
gen pcn_region_code = "WLD"
append using `datax1'
saveold "$dataout\\Agg_Demo_${case}", replace

//WLD average
table (year) ( pcn_region_code) if pline==215, statistic(sum npoor pop) nformat(%4.2f) 
collect style header year  pcn_region_code, title(hide)
collect preview



