

Only leave the following in data_in


"$swdLocal\2_data\data_in\Lineup country tables.xls"


"${datain}\Final_CPI_PPP_to_be_used.dta", replace


"${datain}\code_inc_regpcn_latest.dta", replace

"${datain}\growth_GDP_MPO_AM2024.dta", replace 

use "${datain}\code_inc_pop_regpcn.dta", clear 

use "${dataout}\popdata.dta", clear

saveold "${dataout}\PIP_lineup_pline", replace

"${dataout}\PIP_survey_pline", replace


saveold "${dataout}\PIP_lineup2022_welftype", replace //168 ctrys

"${datain}\GDPcap_ClimateChange_RCP85_SSP5.csv"

"${datain}\GDPcap_NOClimateChange_RCP85_SSP5.csv"


"$dataout\growth_gdp_pce_pop.dta", replace

This way:

we drop 0, 1a, 1e, 1b