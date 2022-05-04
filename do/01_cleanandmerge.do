
********************************************************************************
						* CLEAN AND MERGE * 
********************************************************************************

clear
clear matrix
capture log close
set more off

set mem 1000m

* LOG FILE
log using "$data\01_cleanandmerge.log", replace

/* 
***************
GENERAL NOTES
**************

- This do-file cleans and merges the dataset and creates the regression data set

- INPUT: 	* "$data\randhrsimp1992_2016v2.dta"
			* "$data\randhrs1992_2016v2.dta"
			* "$data\lw_data.dta"
			* "U:\Data\HRS\TRK2014TR_R.dct"			
						
- OUTPUT: 	* "$data\match.dta"
			
- PROCEDURE: 1. merge all datasets except exit wave
			 2. match controls with cases using exact_match 
						condition for matching based on age, entry year, race, and ethnicity
						condition for matching based on education and race 
					create temp files for cases and controls separately
					m:m merge to find all possible matches
					keep each case's first 5 matches
					merge in case diagnosis wave to create counterfactual date for controls
					merge in covariates for cases and controls from diagnosis wave
			3. create format file for time variable
					all respondents have 5 periods, starting at time=1
					if respondent is present <5 waves, all values missing
			4. finish formatting the data
					convert from wide to long
					adjust for inflation
			5. apply Basu and Manning conditions
*/

******************************************************************************** 

**********
* PART 1 *
**********
	
*pull in core and exit costs
	use hhidpn hhid pn r*mhosp r*mnhm r*mops r*mdr r*mdent r*mhhc ///
	r*mspec r*mdrug r*mothx r*oopmd inw* rem* ///
	using "$RAND\randhrsimp1992_2016v2.dta" 
		tostring hhidpn, replace
		tempfile RAND
		sa `RAND'
		clear

	
use "$HRS\lw_data.dta", clear
*once qualified, always qualified
	forval x = 4/13 {
		loc y = `x'-1
		replace lw`x' = 2 if lw`y'==2
		
	}
	drop lw3 lw4 
	forval x = 5/13 {
		recode lw`x' (1=0) (2=1), g(dementiawave`x')
	}
/*
g first_change_forecasting=.
	forval x = 6/13 {
		loc y = `x'-1
		replace first_change_forecasting = `x' if dementiawave`y'==0&(dementiawave`x'==1|dementiawave`x'==2)&first_change_forecasting==.
		
	}
	*/
		keep hhidpn dementia*
		
		merge 1:1 hhidpn using `RAND', keep(matched) nogen
		sa "$data\OOP_costs.dta", replace

	
*pull RAND variables, including interview date	
	use hhidpn hhid pn raracem ragender raeduc raddate radtimtdth rabyear rahispan ravetrn rabplace ///
		radtimtdth r*iwend r*exit r*shlt r*iwstat h*hhid r*hiltc r*agey_e r*mstat ///
		r*hiltc h*atota h*itot r*adla r*govmr r*govmd r*govva r*mrprem ///
		r*stroke r*psyche r*arthre r*hearte r*lunge r*cancre r*diabe r*hibpe ///
		using "U:\Data\RAND HRS\randhrs1992_2016v2.dta"
		tostring hhidpn, replace
		*stat for draft (36,176)
		g present = 1 if r5iwstat==1|r6iwstat==1|r7iwstat==1|r8iwstat==1|r9iwstat==1|r10iwstat==1|r11iwstat==1|r12iwstat==1|r13iwstat==1
		su present
		drop present
	merge 1:1 hhidpn using "$data\OOP_costs.dta", keep(matched) nogen
	sa "$data\OOP_costs.dta", replace
	

*use tracker to identify exit waves
	use HHID PN *IWTYPE FIRSTIW *PROXY using "U:\Data\HRS\trk2018tr_r.dta", clear
	loc x G H J K L M  N  O  P  Q
	loc y 5 6 7 8 9 10 11 12 13 14
			loc n : word count `x'
			forval i=1/`n' {
				loc a : word `i' of `x'
				loc b : word `i' of `y'
				
				rename `a'IWTYPE iwtype`b'
				recode `a'PROXY (1/2 11/12 21/22=1) (5 9 19 29=0) (else=.), g(proxy`b')
		}
		
		destring HHID, g(hhid)
		tostring hhid, replace
		g hhidpn = hhid+PN
		keep hhidpn iwtype* proxy* FIRSTIW
	merge 1:1 hhidpn using "$data\OOP_costs.dta", keep(matched) nogen
	sa "$data\OOP_costs.dta", replace

*once they receive a qualifying score, always counted as having dementia
	g diagnosis_wave=.
		replace diagnosis_wave=5 if dementiawave5==1&diagnosis_wave==.
		forval x = 6/13 {
			loc y = `x' - 1
				replace diagnosis_wave=`x' if dementiawave`x'==1&(dementiawave`y'==0|dementiawave`y'==.)&diagnosis_wave==.		
		}

*first wave present - can't be diagnosis wave, must have prior wave
	drop inw1 inw2 inw3 inw4
	g first_wave = .
		replace first_wave = 5 if iwtype5==1|iwtype5==11
		forval x = 6/13 {
		replace first_wave = `x' if (iwtype`x'==1|iwtype`x'==11)&first_wave==.
		}
	keep if first_wave<diagnosis_wave
	
*find exit wave
	g exitwave=.
	forval x = 5/14 {
		replace exitwave=`x' if iwtype`x'==11 & exitwave==.
	}	

*make sure that exitwave isnt firstwave
	drop if first_wave==exitwave
	*stat for draft (33,701)
	di _N
	
	
*generate matching conditions
	egen birth = cut(rabyear), at(1890, 1895, 1900, 1905, 1910, 1915, 1920, 1925, 1930, 1935, 1940, 1945, 1950, 1955, 1960, 1965, 1970, 1975, 1980, 1985, 1990, 1995, 2000)
	drop if FIRSTIW==.|birth==.|ragender==.|raracem==3|raracem==.|rahispan==.|raracem==.m|rahispan==.m|ragender==.|raracem==3|raracem==.|raracem==.m|raeduc==.
	recode raeduc (1/2=1) (3=2) (4/5=3), g(educ)
	g networth_baseline = .
	forval x = 1/13 {
	replace networth_baseline = h`x'atota if diagnosis_wave==`x'
	}
		xtile networth = networth_baseline, n(4)
	*stat for draft (30,486)
	di _N

*assign group	
*	egen exact_match = group(FIRSTIW birth ragender raracem rahispan raeduc)
			recode raracem (1=1) (2=0), g(white)
				replace white=0 if rahispan==1
*			recode raeduc (1=1) (2/3=2) (4/5=3), g(educ_match)	
			recode raeduc (1=1) (2/3=2) (4=3) (5=4), g(educ_match)	
*	egen exact_match = group(FIRSTIW birth ragender white educ_match networth)	
	egen exact_match = group(FIRSTIW birth ragender white educ_match)	
				drop white educ_match networth*

*make sure that everyone has a valid prior wave 
	g dementiadx=(dementiawave5==1 | dementiawave6==1 | dementiawave7==1 | dementiawave8==1 | dementiawave9==1 | dementiawave10==1 | dementiawave11==1 | dementiawave12==1 | dementiawave13==1) 

*fill exit wave with exit values
	forval x = 6/13 {		
	foreach var in mstat govmr govva hiltc {
			replace r`x'`var' = re`var' if exitwave==`x' & r`x'`var'==.
			}
	}	
	*stat for draft (3,780)
	ta dementiadx 
	
*fill exit wave with previous values - yes if ever reported yes
foreach var in hibpe diabe cancre lunge hearte stroke psyche arthre {
forval x = 1/12 {
    loc y = `x'+1
    replace r`y'`var'=1 if r`x'`var'==1
}
}
	sa "$data\OOP_costs.dta", replace

******************************************************************************** 

**********
* PART 2 *
**********

*keep cases with diagnosis wave
	keep if dementiadx==1

*sort, then apply random number for later sorting
	so hhidpn
	set seed 1234
	bys hhidpn: g randnum_case = runiform()
	
*keep only cases that were present in diagnosis wave
	forval x = 6/13 {
	drop if diagnosis_wave==`x'&h`x'itot==.&proxy`x'!=1
	drop if diagnosis_wave==`x'&r`x'agey_e==.&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'hibpe==.d|r`x'hibpe==.m|r`x'hibpe==.r)&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'diabe==.d|r`x'diabe==.m|r`x'diabe==.r)&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'cancre==.d|r`x'cancre==.m|r`x'cancre==.r)&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'lunge==.d|r`x'lunge==.m|r`x'lunge==.r)&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'hearte==.d|r`x'hearte==.m|r`x'hearte==.r)&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'stroke==.d|r`x'stroke==.m|r`x'stroke==.r)&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'psyche==.d|r`x'psyche==.m|r`x'psyche==.r)&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'arthre==.d|r`x'arthre==.m|r`x'arthre==.r)&proxy`x'!=1
	}
	
*make sure cases are in sample for more than 1 wave 
	keep if (inw5==1&inw6==1)|(inw6==1&inw7==1)|(inw7==1&inw8==1)|(inw8==1&inw9==1)|(inw9==1&inw10==1)|(inw10==1&inw11==1)|(inw11==1&inw12==1)|(inw12==1&inw13==1)|(iwtype5==1&iwtype6==11)|(iwtype6==1&iwtype7==11)|(iwtype7==1&iwtype8==11)|(iwtype8==1&iwtype9==11)|(iwtype9==1&iwtype10==11)|(iwtype10==1&iwtype11==11)|(iwtype11==1&iwtype12==11)|(iwtype12==1&iwtype13==11)

	keep hhidpn exact_match diagnosis_wave randnum_case
		rename hhidpn hhidpn_case
	tempfile cases
	sa `cases'
	clear

use "$data\OOP_costs.dta"
*keep controls with their wave-specific data
drop dementiadx
recode diagnosis_wave (.=0), g(control_diagnosis)
	so hhidpn
	set seed 9876
	bys hhidpn: g randnum_control = runiform()
		rename hhidpn hhidpn_control
		drop diagnosis_wave

*merge cases with controls to assign diagnosis wave to controls
	*m:m merge to match all cases to all controls in same group
	joinby exact_match using `cases'

*keep only controls that were present in diagnosis wave

	forval x = 6/13 {
	drop if diagnosis_wave==`x'&h`x'itot==.&proxy`x'!=1
	drop if diagnosis_wave==`x'&r`x'agey_e==.&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'hibpe==.d|r`x'hibpe==.m|r`x'hibpe==.r)&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'diabe==.d|r`x'diabe==.m|r`x'diabe==.r)&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'cancre==.d|r`x'cancre==.m|r`x'cancre==.r)&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'lunge==.d|r`x'lunge==.m|r`x'lunge==.r)&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'hearte==.d|r`x'hearte==.m|r`x'hearte==.r)&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'stroke==.d|r`x'stroke==.m|r`x'stroke==.r)&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'psyche==.d|r`x'psyche==.m|r`x'psyche==.r)&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'arthre==.d|r`x'arthre==.m|r`x'arthre==.r)&proxy`x'!=1
	}

*using keep instead of drop
	g check1=0
	forval x = 6/13 {
		replace check1=1 if diagnosis_wave==`x' & iwtype`x'==1
	}
	g check2=0
	forval x = 6/13 {
		replace check2=1 if diagnosis_wave==`x' & iwtype`x'==11
	}	
	keep if check1==1 | check2==1 
	drop check*

	
*keep only cases that are at least 2 waves away from diagnosis
g dif = diagnosis_wave - control_diagnosis
	drop if dif<2
	
*make sure controls are in sample for more than 1 wave 
	keep if (inw5==1&inw6==1)|(inw6==1&inw7==1)|(inw7==1&inw8==1)|(inw8==1&inw9==1)|(inw9==1&inw10==1)|(inw10==1&inw11==1)|(inw11==1&inw12==1)|(inw12==1&inw13==1)|(iwtype5==1&iwtype6==11)|(iwtype6==1&iwtype7==11)|(iwtype7==1&iwtype8==11)|(iwtype8==1&iwtype9==11)|(iwtype9==1&iwtype10==11)|(iwtype10==1&iwtype11==11)|(iwtype11==1&iwtype12==11)|(iwtype12==1&iwtype13==11)
	
	
*keep first 5 matches
	so randnum_case randnum_control
	bys randnum_case: g num = _n
	keep if num<6
	drop randnum* 
	
	g casecontrol=0
sa "$data\case_control.dta", replace

keep hhidpn_case
rename hhidpn_case hhidpn
duplicates drop
tempfile used_cases
sa `used_cases', replace

clear	
	
*append cases with diagnosis wave
use "$data\OOP_costs.dta"

*keep cases with their wave-specific data
	keep if dementiadx==1
	merge m:1 hhidpn using `used_cases', keep(matched) nogen
	*keep only cases that were present in diagnosis wave
	forval x = 6/13 {
	drop if diagnosis_wave==`x'&h`x'itot==.&proxy`x'!=1
	drop if diagnosis_wave==`x'&r`x'agey_e==.&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'hibpe==.d|r`x'hibpe==.m|r`x'hibpe==.r)&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'diabe==.d|r`x'diabe==.m|r`x'diabe==.r)&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'cancre==.d|r`x'cancre==.m|r`x'cancre==.r)&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'lunge==.d|r`x'lunge==.m|r`x'lunge==.r)&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'hearte==.d|r`x'hearte==.m|r`x'hearte==.r)&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'stroke==.d|r`x'stroke==.m|r`x'stroke==.r)&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'psyche==.d|r`x'psyche==.m|r`x'psyche==.r)&proxy`x'!=1
	drop if diagnosis_wave==`x'&(r`x'arthre==.d|r`x'arthre==.m|r`x'arthre==.r)&proxy`x'!=1
	}
	
*make sure cases are in sample for more than 1 wave 
	keep if (inw5==1&inw6==1)|(inw6==1&inw7==1)|(inw7==1&inw8==1)|(inw8==1&inw9==1)|(inw9==1&inw10==1)|(inw10==1&inw11==1)|(inw11==1&inw12==1)|(inw12==1&inw13==1)|(iwtype5==1&iwtype6==11)|(iwtype6==1&iwtype7==11)|(iwtype7==1&iwtype8==11)|(iwtype8==1&iwtype9==11)|(iwtype9==1&iwtype10==11)|(iwtype10==1&iwtype11==11)|(iwtype11==1&iwtype12==11)|(iwtype12==1&iwtype13==11)

	append using "$data\case_control.dta"	
	replace casecontrol=1 if casecontrol==.
		replace hhidpn = hhidpn_control if casecontrol==0
			drop hhidpn_control
	sa "$data\case_control.dta", replace 

*apply characteristics from diagnosis wave
recode raracem (1=1) (2=0), g(white)
recode rahispan (1=1) (0=0) (else=.), g(hispan)
recode ragender (1=1) (2=0), g(male)

foreach var in age itot hibpe diabe cancre lunge hearte rstroke psyche arthre {
	g `var'=.
}

	forval x = 6/13 {
		replace age = r`x'agey_e if diagnosis_wave==`x'
		replace itot = h`x'itot if diagnosis_wave==`x'
		replace hibpe = r`x'hibpe if diagnosis_wave==`x'
		replace diabe = r`x'diabe if diagnosis_wave==`x'
		replace cancre = r`x'cancre if diagnosis_wave==`x'
		replace lunge = r`x'lunge if diagnosis_wave==`x'
		replace hearte = r`x'hearte if diagnosis_wave==`x'
		replace rstroke = r`x'stroke if diagnosis_wave==`x'
		replace psyche = r`x'psyche if diagnosis_wave==`x'
		replace arthre = r`x'arthre if diagnosis_wave==`x'
	}
	
keep num hhidpn casecontrol diagnosis_wave age itot hibpe diabe cancre lunge ///
hearte rstroke psyche arthre white hispan male raddate radtimtdth

g check=0
foreach var in age itot hibpe diabe cancre lunge hearte rstroke psyche arthre {
	replace check=1 if `var'==.|`var'==.d|`var'==.m
}


*keeping track of first match for summary statistics
replace num = 1 if num==.&casecontrol==1

sa "$data\case_control.dta", replace


*merge with cost data
merge m:1 hhidpn using "$data\OOP_costs.dta", keep(matched) nogen

*create id variable for data cleaning
g id = _n

*make sure we inflate only the base year value
rename itot itot_orig
g itot = itot_orig
	loc x 1.41 1.36 1.31 1.27 1.23 1.19 1.16 1.12 1.10 1.08 1.06 1.04 1.03 1.03 1.01
	loc y 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2014 2015 2016 
	loc z 6	   6	7	 7	  8    8    9	 9 	  10   10 	11	 11	  12   12	13 
			loc n : word count `x'
			forval i=1/`n' {
				loc a : word `i' of `x'
				loc b : word `i' of `y'
				loc c : word `i' of `z'
				
				replace itot = itot*`a' if itot==h`c'itot & yofd(r`c'iwend)==`b'			
		}

sa "$data\case_control.dta", replace

********************************************************************************

**********
* PART 3 *
**********

*create the format for time = 1/5 for merging
	forval x = 1/5 {
	use "$data\case_control.dta"
	keep hhidpn id casecontrol num
	g time = `x'
	tempfile temp`x'
	sa `temp`x''
	clear
	}
	use `temp1'
	forval y = 2/5 {
	append using `temp`y''
	}
	so hhidpn time
	ta casecontrol if num==1&time==1
	
sa "$data\format.dta", replace
clear

********************************************************************************

**********
* PART 4 *
**********

*convert from wide to long
	use "$data\case_control.dta", clear
	
	keep hhidpn id casecontrol num diagnosis_wave age itot hibpe raeduc /// 
	diabe cancre lunge hearte rstroke psyche arthre white hispan /// 
	male raddate radtimtdth inw* r*mstat r*adla r*agey_e r*mhosp r*mops r*mdr r*mhhc /// 
	r*mdent r*mdrug r*mspec r*mnhm r*oopmd r*govmr r*govmd *wend ///
	r*govva r*hiltc r*mrprem exitwave
	
forval x = 6/13 {
	foreach y in mstat adla agey_e mhosp mops mdr mhhc mdent mdrug ///
	 mspec mnhm oopmd govmr govmd govva hiltc mrprem iwend {
		rename r`x'`y' `y'`x'
	}
	foreach var in num diagnosis_wave age itot hibpe diabe cancre ///
	 lunge hearte rstroke psyche arthre white hispan male exitwave ///
	 raddate radtimtdth raeduc {
		g `var'`x'  = `var'
	}
}

drop num diagnosis_wave age itot hibpe diabe cancre lunge ///
	hearte rstroke psyche arthre white hispan male exitwave ///
	raddate radtimtdth raeduc
	
	
reshape long num diagnosis_wave age itot hibpe diabe cancre lunge raeduc ///
	hearte rstroke psyche arthre white hispan male exitwave inw iwend ///
	raddate radtimtdth mstat adla agey_e mhosp mops mdr mhhc mdent mdrug ///
	mspec mnhm oopmd govmr govmd govva hiltc mrprem, i(hhidpn id casecontrol) j(wave)

	rename agey_e agey_e_current
	
	rename mdr exp_doc
	rename mdent exp_dent
	rename mdrug exp_drug
	rename mhhc exp_home
	rename mspec exp_specf
	rename mnhm exp_nh
	rename mhosp exp_hosp
	rename mops exp_surg	

	rename govmr govmr_current
	rename govmd govmd_current
	rename govva govva_current
	rename hiltc hiltc_current
	rename mrprem mrprem_current


order wave hhidpn casecontrol num

*HMO
	recode mrprem (.m . = .) (.d .r=1) (.n=0) (else=1), g(m_hmo)
	
sa "$data\case_control.dta", replace
**********************************************************

/*finding washout

g start = 0 if diagnosis_wave==wave

bys id: replace start=-1 if start[_n+1]==0
bys id: replace start=-2 if start[_n+1]==-1
bys id: replace start=-3 if start[_n+1]==-2
bys id: replace start=-4 if start[_n+1]==-3
bys id: replace start=-5 if start[_n+1]==-4
bys id: replace start=-6 if start[_n+1]==-5
bys id: replace start=-7 if start[_n+1]==-6

bys casecontrol: su totalcosts1value2014 if start==-1
bys casecontrol: su totalcosts1value2014 if start==-2
bys casecontrol: su totalcosts1value2014 if start==-3
bys casecontrol: su totalcosts1value2014 if start==-4
bys casecontrol: su totalcosts1value2014 if start==-5
bys casecontrol: su totalcosts1value2014 if start==-6
*/

*start at dementia diagnosis wave
so id wave	
g time=1 if wave==diagnosis_wave
forval x = 1/12 {
loc y = `x'+1
bys id: replace time = `y' if time[_n-1]==`x' & time==.
}
bys id: replace time = 0 if time[_n+1]==1 & time==.
drop if time==.
	
*backfill num to get baseline summary statistics
so id wave 
bys id: replace num = num[_n+1] if num==.&time==0	
	
merge 1:1 id time using "$data\format.dta"
			*_merge==1 is time=0 or 6/7
			*drop if _merge==1&time!=0
drop if time>5
drop _merge

	so id time
	order hhidpn id wave time
	drop r1* r2* r3* r4* r5* r6* r7* r8* r9* 
	
	g year = yofd(iwend)
		
	*convert to 2017 dollars and match name with exit cost variables				
			rename remnhm remnh 
			rename remdr remdoc
			rename remops remsurg
			rename remhhc remhome 
			rename remspec remspecf
			
		loc costs hosp nh doc drug surg dent home specf
		foreach var in `costs' {
			replace exp_`var'= rem`var' if wave==exitwave
		}
		
			egen exp_other = rowtotal(exp_surg exp_dent exp_home exp_specf)
				replace exp_other=. if (exp_surg==.&exp_dent==.&exp_home==.&exp_specf==.)
			egen exp_total = rowtotal(exp_hosp exp_nh exp_doc exp_drug exp_other)
				replace exp_total=. if (exp_hosp==.&exp_nh==.&exp_doc==.&exp_drug==.&exp_other==.)
					
	loc x 1.41 1.36 1.31 1.27 1.23 1.19 1.16 1.12 1.10 1.08 1.06 1.04 1.03 1.03 1.01
	loc y 2002 2003 2004 2005 2006 2007 2008 2009 2010 2011 2012 2013 2014 2015 2016 
			loc n : word count `x'
			forval i=1/`n' {
				loc a : word `i' of `x'
				loc b : word `i' of `y'
				replace exp_total=exp_total*`a' if year==`b'
				replace exp_hosp=exp_hosp*`a' 	if year==`b'
				replace exp_nh=exp_nh*`a' 		if year==`b'
				replace exp_doc=exp_doc*`a' 	if year==`b'
				replace exp_drug=exp_drug*`a' 	if year==`b'
				replace exp_other=exp_other*`a' if year==`b'
		}
	
********************************************************************************

**********
* PART 5 *
**********

*duration 
g month = mofd(iwend)
	so id time
	bys id: g month_lag = month[_n-1]
	g duration = month-month_lag
		*the following only keeps those with data prior to exitwave
		bys id: replace duration = radtimtdth if wave==exitwave
		*duration needs to be somewhat standardized for Basu method
		recode duration (.=0) (1/150=24), g(duration2)	
		replace duration2=duration if wave==exitwave & duration<=24		
		
*death
	recode wave (.=.) (else=0), g(death)
		replace death=1 if wave==exitwave & wave!=.
		so id time
		forval x = 1/10 {
		bys id: replace death=. if death[_n-`x']==1
		}
		
	g deathtime = time*death
		
*no costs after death - already done, confirm no changes made
	foreach var in exp_total exp_hosp exp_nh exp_doc exp_drug exp_other {
		replace `var'=0 if (time>deathtime)&deathtime!=0
	}
		
*censored
	recode inw (0=1) (1=0), g(censored)
		*account for people who never died or left the study
		replace censored=0 if inw==.&wave==. 
		so id time
		bys id: replace censored=1 if censored[_n-1]==1
		replace censored=0 if death==1
	
*casetime/centime	
	g casetime = casecontrol*time
	g centime=censored
		so id time
		bys id: replace centime=. if centime!=1|centime[_n-1]==1|centime[_n-2]==1|centime[_n-3]==1|centime[_n-4]==1|centime[_n-5]==1	
	replace centime=0 if centime==.
	
*obs, fullobs, obs2	
	g fullobs = inw
		replace fullobs=0 if wave==.
		replace fullobs=0 if death==1	
		replace fullobs=0 if censored==1
	g obs = fullobs
		replace obs=1 if exitwave==wave&obs[_n-1]==1&exitwave!=.&raddate!=.
	g obs2 = obs
		replace obs2 = 1 if (exitwave>=wave)&exitwave!=.&raddate!=.
		replace obs2=0 if censored==1
			
*yfrom ind* dtime*
	so id time
	ta time, g(yfromind)

*'old' variables
	g durold=duration	
	g casecontrolold=casecontrol		
	g deathtimeold = deathtime
	
*do "$subfolder\Labels.do" > not working
	label var exp_total "Total (2017 dollars)"
	label var exp_hosp "Hospital (2017 dollars)"
	label var exp_nh "Nursing home (2017 dollars)"
	label var exp_doc "Doctor (2017 dollars)"
	label var exp_drug "Prescription drug (2017 dollars)"
	label var exp_other "Other (2017 dollars)"
	label var male "Male"
	label var agey_e "Age"
	label var white "Race (proportion White)"
	label var hispan "Ethnicity (proportion Hispanic)"
	label var itot "Income (2017 dollars)"
	label var hibpe "Ever had high blood pressure"
	label var diabe "Ever had diabetes"
	label var cancre "Ever had cancer"
	label var lunge "Ever had lung disease"
	label var hearte "Ever had heart problems"
	label var rstroke "Ever had stroke"
	label var psyche "Ever had psych problems"
	label var arthre "Ever had arthritis"

sa "$data\sumstats.dta", replace
drop if time==0


*fill in costs with 0 after death
foreach var in hosp surg doc home dent drug specf nh other total {
    replace exp_`var'=0 if deathtime>time
}

sa "$data\match.dta", replace

capture log close
