//mata structure
cap prog drop findsigma
program define findsigma, rclass
	version 11.2	
	syntax, value(string) 
	mata: va = strtoreal(st_local("value"))
	mata: abs = abs(ginis:-va)	
	mata: minindex(abs,1,i=.,w=.)
	mata: sigma = sigmas[min(i)]
	mata: st_numscalar("sigmavalue", sigma)	
	return local sigmavalue = sigmavalue
end
