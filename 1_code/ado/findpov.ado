//mata structure,sort by quantile, two columns: welf and rate
cap prog drop findpov
program define findpov, rclass
	version 11.2	
	syntax, value(string) 
	mata: va = strtoreal(st_local("value"))
	mata: abs = abs(welf:-va)	
	mata: minindex(abs,1,i=.,w=.)
	mata: pov = rate[min(i)]
	mata: st_numscalar("povrate", pov)	
	return local povrate = povrate
end