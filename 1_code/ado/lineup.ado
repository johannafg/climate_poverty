*! version 0.2  14mar2016
*! Minh Cong Nguyen
* History
* version 0.1  15feb2016 - first version
* version 0.2  14mar2016 - add popdata() and growthdata(), adjust EUSILC year, modify GPWG/GMD special cases for EAP countries

cap program drop lineup
program define lineup, rclass
	version 13, missing
	local verstata : di "version " string(_caller()) ", missing:"
	if c(more)=="on" set more off
	syntax, COUNtry(string) minlpyr(numlist max=1) maxlpyr(numlist max=1) method(numlist) ///
			popdata(string) growthdata(string) [type(string) pppyear(numlist max=1) ///
		    survname(string) maxyear(numlist max=1) minyear(numlist max=1) omit(numlist) ///
			PASSthrough(numlist max=1 <=1 >0) FILEServer age(string) male(string) NOMATCH]
	
	// external programs
	local extpro maxentropy
	foreach pg of local extpro {
		cap which `pg'
		if _rc~=0 qui ssc inst `pg', replace
		if _rc net install st0196.pkg
	}
	
	// Global error code
	global errcode 0

	// housekeeping check
	local country "`=upper("`country'")'"
	if 	`minlpyr' > `maxlpyr' {
		di in red "minlpyr should smaller than maxlpyr. Please check" _new
		global errcode 198
		error 198
	}
	if "`popdata'"=="" {
		di in red "Please provide the population data." _new
		global errcode 198
		error 198
	}
	if "`growthdata'"=="" {
		di in red "Please provide the growth data." _new
		global errcode 198
		error 198
	}
	global growth "`growthdata'"
	global popdemo "`popdata'"
	
	// setting up 
	if "`age'"=="" local age age
	if "`male'"=="" local male male
	if "`pppyear'"=="" local pppyear 2017
	if "`type'"=="" local type GMD
	if "`passthrough'"=="" local passthrough 1
	if "`minyear'"=="" local minyear 2000
	if "`maxyear'"=="" local maxyear : di year(date("$S_DATE", "DMY"))
	
	//temp outdata
	clear
	tempfile outdata
	qui save `outdata', replace emptyok
	
	/*method: 
	0 raw - which raw to call (before, after)
	1 raw + adj total pop for the same year, 
	2 adjust growth to the lineup year
	3 adjust pop and growth to the lineup year
	4 adjust growth to the lineup year, and total population
	
	Pop can be: 
		- total population
		- cell by gender and age groups
	*/
	qui {
		// upload population structure
		noi di as text "Population projections for `country'..."
		cap use "$popdemo" if country=="`country'", clear
		if _rc==0 {
			qui forval i=1950/2100 {
				gen __yt`i' = ym`i' + yf`i'
				egen _yt`i' = sum(__yt`i')
				gen shm`i' = ym`i'/_yt`i'
				gen shf`i'  = yf`i'/_yt`i'
				mkmat shm`i', matrix(m`i')
				mkmat shf`i', matrix(f`i')

				sum _yt`i'
				global popt`i' = r(sum)
			}
			tempfile popdata0
			sort country
			save `popdata0', replace
			noi di as result "          uploaded"
			collapse (sum) __yt*
			mkmat __yt*, matrix(popmatrix)
			noi mat list f2013
			noi mat list m2013 
			
		}
		else {
			noi dis in red "No population projection data for `country'..."
			global errcode 199
			error 199
		}
		
		// filter growth data
		noi di as text "Growth projections for `country'..."
		tempfile growthdata
		cap use "$growth" if countrycode=="`country'", clear	
		if _rc==0 { 
			//ren year all_needed
			cap ren year yr
			save `growthdata', replace
			noi di as result "          uploaded"
		}
		else {
			noi dis in red "No growth projection data for `country'..."
			global errcode 200
			error 200
		}
		
		// create input data
		clear
		tempfile dataall
		set obs 100
		local yr0 : di year(date("$S_DATE", "DMY"))
		if `maxlpyr'~=. {
			if `maxlpyr' > `yr0' local yr0 `maxlpyr'
		}
		gen str countrycode = "`country'"
		gen yr = .
		gen all_needed = .
		gen available = .
		local s = 1
		qui forv i = 1990(1)`yr0' {
			replace yr = `i' in `s'
			local s = `s' + 1		
		}
		// get needed years
		qui forv i=`minlpyr'(1)`maxlpyr' {
			replace all_needed = `i' if yr ==`i'		
		}		
		save `dataall', replace

		// check available data point, save it
		local yravail
		qui forv y=`minyear'(1)`maxyear' {
			//EUSILC
			if (strpos("`=upper("`survname'")'","EU-SILC") > 0) | (strpos("`=upper("`survname'")'","SILC-C") > 0) {
				local yused = `y' + 1
			}
			else {
				local yused = `y'
			}
			cap datalibweb, country(`country') type(`type') year(`yused') surveyid(`surveyid')  nometa mod(ALL)
**# Bookmark #1 /* `fileserver' filename(`survname')*/  
			if _rc==0 {
				tempfile data`y'
				gen  welfareused =  welfare // default welfare
				cap drop weight_h
				cap ren weight_p weight
				cap drop __0*
				cap tostring hhid, replace
				//cap drop hhid
				//gen hhid = _n
				/*
				***************************************
				* Adjustments for Particular Countries
				***************************************	
				if ("`=upper("`type'")'" == "GMD") {									
					if "`country'"=="FJI" | "`country'"=="KHM" | "`country'"=="LAO" | "`country'"=="MNG" | "`country'"=="THA" | "`country'"=="TLS" | "`country'"=="VNM" | "`country'"=="PNG" | "`country'"=="SLB" {
						//replace  welfareused = pcexp  //spatially deflated for EAP only - check later
						replace  welfareused = welfaredef
					}
					if "`country'"=="IDN" | "`ccc'"=="SLB"{
						replace  welfareused = welfaredef
					}
					if "`country'"=="PHL" {
						replace  welfareused = welfaredef // income for PHL
					}
				}
				if ("`=upper("`type'")'" == "GPWG") {	
					if "`country'"=="FJI" | "`country'"=="FSM" | "`country'"=="IDN" | "`country'"=="KHM" | "`country'"=="KIR" | "`country'"=="LAO" | "`country'"=="MNG" | "`country'"=="PNG" | "`country'"=="TLS" | "`country'"=="TON" | "`country'"=="TUV" | "`country'"=="VNM" | "`country'"=="WSM"  | "`country'"=="VUT" {
						replace  welfareused = pcexp  //spatially deflated for EAP only
					}
					if "`country'"=="THA" | "`country'"=="SLB" {
						replace  welfareused = welfare
					}
					if "`country'"=="PHL" {
						replace  welfareused = pcinc // income for PHL
					}
				}
				*/
				
				//adjust to PPP
				gen gallT_ppp = welfare/cpi`pppyear'/icp`pppyear'/365
				la var gallT_ppp "Welfare per capita per day with `pppyear' PPP"
				if ("`=upper("`type'")'" == "GMD") {
					//create variables on demographics
					cap des `age'
					if _rc==0 {
						gen _age = `age'
						cap des `male'
						if _rc==0 {
							gen _gender =.
							replace _gender = 1 if `male'==1
							replace _gender = 2 if `male'==0

							*1 MALES AND FEMALES COHORT 0-4
							gen mc00 =(_age>=0 & _age<=4 & _gender==1)
							gen fc00 =(_age>=0 & _age<=4 & _gender==2)

							*2 MALES AND FEMALES COHORT 5-9
							gen mc05 =(_age>=5 & _age<=9 & _gender==1)
							gen fc05 =(_age>=5 & _age<=9 & _gender==2)
							
							*3 MALES AND FEMALES COHORT 10-14, so on
							forval e = 10(5)75 {
								gen mc`e' =(_age>=`e' & _age<=`e'+4 & _gender==1)
								gen fc`e' =(_age>=`e' & _age<=`e'+4 & _gender==2)
							}
							replace mc75 =(_age>=75 & _age~=. & _gender==1)
							replace fc75 =(_age>=75 & _age~=. & _gender==2)
						}
						else {
							noi dis in red "Variable `male' is not available for `country'."
							global errcode 201
							error 201
						}
					}
					else {
						noi dis in red "Variable `age' is not available for `country'."
						global errcode 202
						error 202
					}
				}	
				save `data`y'', replace
				local yravail "`yravail' `y'"
			}
		}
		local yravail : list yravail - omit
		
		use `dataall', clear
		qui foreach yr of local yravail {
			replace available = `yr' if yr==`yr'
		}
		gen imputed = all_needed if available==.
		keep if all_needed~=. | available~=.
		
		//find the base_before years
		gen base_before = .
		local N = _N
		qui forv i=1(1)`N' {
			local stop = 0
			forv j=`i'(-1)1 {
				if `=available[`j']'~=. & `stop'==0 {
					replace base_before = `=available[`j']' in `i'
					local stop = 1
				}
			}
		}
		replace base_before =. if available==base_before

		//find the base_after years
		gen base_after = .
		local N = _N
		qui forv i=1(1)`N' {
			local stop = 0
			forv j=`i'(1)`N' {	
				if `=available[`j']'~=. & `stop'==0 {
					replace base_after = `=available[`j']' in `i'
					local stop = 1
				}
			}
		}
		replace base_after =. if available==base_after

		//generate types
		gen year_type= .
		replace year_type = 1 if available~=.
		replace year_type = 2 if base_after~=. & base_before~=.
		replace year_type = 3 if (base_after==. | base_before==.) & available==.
		egen maxy = rowmax(base_before base_after)
		
		//add growth data
		merge 1:1 countrycode yr using `growthdata'
		keep if _m==3
		drop _m
		cap drop growth	
		sort yr
		levelsof all_needed, local(yrlist)
		save `dataall', replace
		//save "c:\Users\wb327173\Downloads\ECA\Global\Global Poverty Profile\test.dta" , replace	
		noi di as text "Lining up for `country' from `minlpyr' to `maxlpyr'"
		noi list countrycode- maxy, table sep(99) noobs abbreviate(16)
		// Method selection
		if `method'==0 | `method'==1 { //method==0 raw, method==1 raw + adj total pop for the same year
			noi di as text "method 0 or 1 is selected; method==0 raw, method==1 raw + adj total pop for the same year" 
			use `dataall', clear
			keep if all_needed~=.	
			tempfile dataall2
			save `dataall2', replace
			
			local N=_N
			forv i=1(1)`N' {
				use `dataall2', clear
				local ny = all_needed[`i']
				local type = year_type[`i']
				//observed year
				if `type'==1 {
					local y = available[`i']
				}
				else {
					local y = maxy[`i']
				}
				noi di as result "          for `ny' using `y'"
				//load the data
				use `data`y'', clear
				gen lineupyear = `ny'
				gen baseyear = `y'
				if `method'==0 { //no weight adj method==0 raw
					noi di as text "method 0"
					gen _newweight = weight
				}
				if `method'==1 { //total population adjustted
					noi di as text "method 1"
					svmat popmatrix, names(col)				
					su year [aw=weight]
					local initial = r(sum_w)
					sum __yt`y'
					local final = r(sum)
					gen new_indW`y' = (weight) * (`final'/`initial')
					label var new_indW`y' "Weight with total population adjustment"
					gen _newweight = new_indW`y'
					cap drop __yt*
				}
				gen type = 1
				//save output
				append using `outdata', force
				save `outdata', replace
			}
		} //method 0 and 1
		
		if `method'==2 | `method'==3 | `method'==4 { 
			//2 adjust growth to the lineup year, no pop adj to lineup year but total survey year lineup			
			//4 adjust growth to the lineup year, total population adjusted to line up year
			//3 adjust pop by cell and growth to the lineup year, total population adjusted to line up year
			noi di as text "method 2, 3, or 4 is selected"
			local N=_N
			forv i=1(1)`N' {		
				use `dataall', clear
				//only doing for the requested year
				local ny = all_needed[`i']
				if `ny'~=. {
					local type = year_type[`i']
					//observed year
					if `type'==1 {					
						local y = available[`i']
						noi di as result "          for `ny' using `y'"
						
						//load the data
						use `data`y'', clear						
						svmat popmatrix, names(col)				
						su year [aw=weight]
						local initial = r(sum_w)
						sum __yt`y'
						local final = r(sum)
						gen new_indW`y' = (weight) * (`final'/`initial')
						label var new_indW`y' "Weight with total population adjustment"
						gen _newweight = new_indW`y'
						cap drop __yt*						
						gen lineupyear = `ny'
						gen baseyear = `y'
						//gen _newweight = weight
						gen type = 1
						//save output
						append using `outdata', force
						save `outdata', replace
					}
					
					//backcast or forecast year, either before or after is available
					if `type'==3 {
						noi di as text "type 3"
						local y = maxy[`i']
						noi di as result "          for `ny' using `y'"
						//calculate the growth
						keep if yr == `ny' | yr==`y'
						sort countrycode yr
						local growth =  (gdppc[2]/gdppc[1])-1
						//bys countrycode (all_needed): gen growth = (gdppc[_n]/gdppc[_n-1])-1
						if `ny'<`y' local factor = 1/(1+`growth'*`passthrough')
						if `ny'>`y' local factor = (1+`growth'*`passthrough')

						//load the data
						use `data`y'', clear
						
						// adjust the welfare to the year y
						replace gallT_ppp = gallT_ppp*`factor'
						
						// save the base data
						tempfile base
						save `base', replace
						
						if `method'==2 {
							noi di as text "method 2, adjust growth to the lineup year, no pop adj to lineup year but total survey year lineup"
							gen _newweight = weight
						}
						if `method'==4 {	
							noi di as text "method 4, adjust growth to the lineup year, total population adjusted to line up year"
							svmat popmatrix, names(col)				
							//sum __yt`y'
							//local initial = r(sum)
							su year [aw=weight]
							local initial = r(sum_w)
							sum __yt`ny'
							local final = r(sum)
							gen new_indW`ny' = (weight) * (`final'/`initial')
							label var new_indW`ny' "Weight with total population adjustment"
							gen _newweight = new_indW`ny'
							cap drop __yt*					
						}
						if `method'==3 {
							noi di as text "method 3, adjust pop by cell and growth to the lineup year, total population adjusted to line up year"
							su year [aw=weight]
							local initial = r(sum_w)
							// reweight if needed
							cap des _gender
							local rgender = _rc
							cap des age
							if _rc==0 & `rgender'==0 { // reweight by maximum entropy
								tempvar hhs
								gen hhs = 1
								cap drop __0*
								collapse (mean)  mc00 -  fc75 (sum) weight hhs, by(hhid)
								matrix constraint = [f`ny' \ m`ny']
								
								order hhid weight  f* m*				
								svmat constraint
								replace constraint = . if constraint[_n+1]==. & constraint!=.
								svmat popmatrix, names(col)
								//hh weight
								sum __yt`ny'
								local final=r(sum)
								if "`nomatch'"=="nomatch" {
									sum __yt`y'
									local initial = r(sum)
								}
								sum weight
								local w = r(sum)
								local popt`ny' = `w' * (`final'/`initial')
								noi list constraint if constraint~=.
								noi di as text "weight sum ="
								noi dis `popt`ny''
								des fc00 - mc70
								maxentropy constraint  fc00 - mc70, prior(weight) generate(new_indW`ny') total(`popt`ny'')
								replace new_indW`ny' = new_indW`ny'/hhs
								label var new_indW`ny' "Weight with demographics adjustment"
								cap drop __yt*
							} // _rc gender
							else { // reweight by a constant
								cap isid hhid
								if _rc~=0 {
									replace weight = weight*hsize
									duplicates drop hhid, force
								}
								svmat popmatrix, names(col)
								sum __yt`ny'
								local final = r(sum)
								//su year [aw=weight]
								//local initial = r(sum_w)
								if "`nomatch'"=="nomatch" {
									sum __yt`y'
									local initial = r(sum)
								}
								gen new_indW`ny' = (weight/hsize) * (`final'/`initial')
								label var new_indW`ny' "Weight with simple adjustment"
								cap drop __yt*
							} //else
							
							// add new weight to the data
							keep hhid new_indW`ny'
							tempfile nweights
							save `nweights'

							use `base', clear
							merge m:1 hhid using `nweights'
							tab _merge
							drop _merge
							gen _newweight = new_indW`ny'
						}
						// do the calculation
						gen lineupyear = `ny'
						gen baseyear = `y'
						gen type = 3
						
						//save output
						append using `outdata', force
						save `outdata', replace
					} //type 3
					
					//interpolation - do the calculations twice
					if `type'==2 {
						noi di as text "type 2"
						use `dataall', clear
						if base_before[`i']~=. {
							noi di as text "base before"
							local y = base_before[`i']
							noi di as result "          for `ny' using `y'"
							//calculate the growth
							keep if yr == `ny' | yr==`y'
							sort countrycode yr
							local growth =  (gdppc[2]/gdppc[1])-1
							if `ny'<`y' local factor = 1/(1+`growth'*`passthrough')
							if `ny'>`y' local factor = (1+`growth'*`passthrough')
							
							//load the data
							use `data`y'', clear
							// adjust the welfare to the year y
							replace gallT_ppp = gallT_ppp*`factor'
							
							// save the base data
							tempfile base
							save `base', replace
							
							if `method'==2 {
								noi di as text "method 2"
								gen _newweight = weight
							}
							if `method'==4 {	
								noi di as text "method 4"
								svmat popmatrix, names(col)				
								//sum __yt`y'
								//local initial = r(sum)
								su year [aw=weight]
								local initial = r(sum_w)
								sum __yt`ny'
								local final = r(sum)
								gen new_indW`ny' = (weight) * (`final'/`initial')
								label var new_indW`ny' "Weight with total population adjustment"
								gen _newweight = new_indW`ny'
								cap drop __yt*					
							}
							if `method'==3 { // reweight if needed
								noi di as text "method 3"
								su year [aw=weight]
								local initial = r(sum_w)
								cap des _gender
								local rgender = _rc
								cap des age
								if _rc==0 & `rgender'==0 { // reweight by maximum entropy
									tempvar hhs
									cap drop __0*
									gen hhs = 1
									collapse (mean)  mc00 -  fc75 (sum) weight hhs, by(hhid)
									matrix constraint = [f`ny' \ m`ny']	
									order hhid weight  f* m*
									svmat constraint
									replace constraint = . if constraint[_n+1]==. & constraint!=.
									
									svmat popmatrix, names(col)
									//hh weight
									sum __yt`ny'
									local final=r(sum)
									if "`nomatch'"=="nomatch" {
										sum __yt`y'
										local initial = r(sum)
									}
									sum weight
									local w = r(sum)
									local popt`ny' = `w' * (`final'/`initial')
									maxentropy constraint fc00 - mc70, prior(weight) generate(new_indW`ny') total(`popt`ny'')
									replace new_indW`ny' = new_indW`ny'/hhs
									label var new_indW`ny' "Weight with demographics adjustment"
									cap drop __yt*
								} //rc gender
								else { // reweight by a constant
									cap isid hhid
									if _rc~=0 {
										replace weight = weight*hsize
										duplicates drop hhid, force
									}
									svmat popmatrix, names(col)
									sum __yt`ny'
									local final = r(sum)
									//su year [aw=weight]
									//local initial = r(sum_w)
									if "`nomatch'"=="nomatch" {
										sum __yt`y'
										local initial = r(sum)
									}
									gen new_indW`ny' = (weight/hsize) * (`final'/`initial')
									label var new_indW`ny' "Weight with simple adjustment"
									cap drop __yt*
								} //else
								
								// add new weight to the data
								keep hhid new_indW`ny'
								tempfile nweights
								save `nweights'

								use `base', clear
								merge m:1 hhid using `nweights'
								tab _merge
								drop _merge
								gen _newweight = new_indW`ny'
							}
							// do the calculation
							gen lineupyear = `ny'
							gen baseyear = `y'
							gen type = 2
							
							//save output
							append using `outdata', force
							save `outdata', replace
						} //base_before
						
						use `dataall', clear
						if base_after[`i']~=. {
							noi di as text "base after"
							//calculate the growth
							local y = base_after[`i']
							noi di as result "          for `ny' using `y'"
							keep if yr == `ny' | yr==`y'
							sort countrycode yr
							local growth =  (gdppc[2]/gdppc[1])-1
							if `ny'<`y' local factor = 1/(1+`growth'*`passthrough')
							if `ny'>`y' local factor = (1+`growth'*`passthrough')
							
							//load the data
							use `data`y'', clear
							// adjust the welfare to the year y
							replace gallT_ppp = gallT_ppp*`factor'
							
							// save the base data
							tempfile base
							save `base', replace
							if `method'==2 {
								noi di as text "method 2"
								gen _newweight = weight
							}
							if `method'==4 {	
								noi di as text "method 4"
								svmat popmatrix, names(col)				
								//sum __yt`y'
								//local initial = r(sum)
								su year [aw=weight]
								local initial = r(sum_w)
								sum __yt`ny'
								local final = r(sum)
								gen new_indW`ny' = (weight) * (`final'/`initial')
								label var new_indW`ny' "Weight with total population adjustment"
								gen _newweight = new_indW`ny'
								cap drop __yt*					
							}
							if `method'==3 {
								noi di as text "method 3"
								su year [aw=weight]
								local initial = r(sum_w)
								// reweight if needed	
								cap des _gender
								local rgender = _rc
								cap des age
								if _rc==0 & `rgender'==0 { // reweight by maximum entropy
									tempvar hhs
									cap drop __0*
									gen hhs = 1
									collapse (mean) mc00 -  fc75 (sum) weight hhs, by(hhid)

									order hhid weight  f* m*
									matrix constraint = [f`ny' \ m`ny']
									svmat constraint
									replace constraint = . if constraint[_n+1]==. & constraint!=.
									svmat popmatrix, names(col)
									//hh weight
									sum __yt`ny'
									local final=r(sum)
									if "`nomatch'"=="nomatch" {
										sum __yt`y'
										local initial = r(sum)
									}
									sum weight
									local w = r(sum)
									local popt`ny' = `w' * (`final'/`initial')
									maxentropy constraint fc00 - mc70, prior(weight) generate(new_indW`ny') total(`popt`ny'')
									replace new_indW`ny' = new_indW`ny'/hhs
									label var new_indW`ny' "Weight with demographics adjustment"
									cap drop __yt*
								} //rc gender
								else { // reweight by a constant
									cap isid hhid
									if _rc~=0 {
										replace weight = weight*hsize
										duplicates drop hhid, force
									}
									svmat popmatrix, names(col)
									sum __yt`ny'
									local final = r(sum)
									//su year [aw=weight]
									//local initial = r(sum_w)
									if "`nomatch'"=="nomatch" {
										sum __yt`y'
										local initial = r(sum)
									}
									gen new_indW`ny' = (weight/hsize) * (`final'/`initial')
									label var new_indW`ny' "Weight with simple adjustment"
									cap drop __yt*
								}
							
								// add new weight to the data
								keep hhid new_indW`ny'
								tempfile nweights
								save `nweights'

								use `base', clear
								merge m:1 hhid using `nweights'
								tab _merge
								drop _merge
								gen _newweight = new_indW`ny'
							}
							// do the calculation
							gen lineupyear = `ny'
							gen baseyear = `y'
							gen type = 2
							
							//save output
							append using `outdata', force
							save `outdata', replace
						} //base_after
					} //type 2
				} //ny
			} //for i-N	
		} //method 2 and 3
		
		//after lineup cleaning
		use `outdata', clear
		cap drop _gender mc00 - fc75
		cap drop if lineupyear==.
	}
	la var lineupyear "Lining up year"
	la var baseyear "Base year"
	la var _newweight "New weights"
	noi dis as text _n "Lining up with base year tabulation."
	ta lineupyear baseyear,m
	noi dis as text _n "Lining up is done."
	
	//add return list
end
