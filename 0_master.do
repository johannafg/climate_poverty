* ------------------------------------------------------------------------------
*     
*     	INITIALIZATION TO RUN THE PIPELINE 
*     	Global Poverty Estimates of Climate Warming    
*                     
*-------------------------------------------------------------------------------

clear all
set more off
set seed 10051990 

* Define username
global suser = c(username)

// INITIALIZE DIRECTORIES 
*For swdLocal, update address of your local directory. 


	else if (inlist("${suser}","wb480081", "WB480081")) {
		gl swdLocal = "C:\Users\\${suser}\OneDrive - WBG\Documents\Poverty_EAP\FY25\Global\Poverty_Climate\replication_files"
	}


else {
	di as error "Configure work environment before running the code."
	error 1
}

// INSTALL COMMANDS AND PACKAGES


local commands = "tabout confirmdir labelmiss ds3 ineqdecgini"
foreach c of local commands {
	qui capture which `c' 
	qui if _rc!=0 {
		noisily di "This command requires '`c''. The package will now be downloaded and installed."
		ssc install `c'
	}
}

 
* Define filepaths
global adof = "$swdLocal\1_code\ado"
global programs = "$swdLocal\1_code\programs"


* Run do files

di "Starting data prep... "

run "$programs/1_baseyear2022pov.do"

run "$programs/2_prep_data.do"
run "$programs/3_prep_data.do"

qui run "$programs/4_neutraldist_alt.do"
qui run "$programs/5_gini_change_lognormal.do"
qui run "$programs/6_gini_change_GIC_alt.do"

di "Starting aggregation to 2050... "

run "$programs/7_aggregateto2050.do"
run "$programs/8_Combining_aggregates.do"

di "Starting final output..."

qui run "$programs/9_TablesandFigures.do"
run "$programs/10-aggregate_for_tableau.do"
run "$programs/11-GIC_aggregate_for_tableau.do"

run "$programs/12-difference_nat_level.do" 

di "This is the end..."