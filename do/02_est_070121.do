
*****************************************************************************************************************************************************************************************
																		* ESTIMATION * 
*****************************************************************************************************************************************************************************************

/* 
***************
GENERAL NOTES
**************

This file runs the Basu & Manning Method for the Out of Pocket Costs Study

- Outcomes: total costs, hospital costs, prescription drug costs, nursing 
			home costs, doctor costs

- Definitions:
	duration2 - months observed over the interval (24 when fully observed, <24 if 
			   death occurs between waves, 0 if not observed in a given wave)
	ind - indicates any out of pocket expenditures in a given wave	
	casecontrol - indicates respondents who were ever diagnosed over the study period
	time - counts the intervals (1-5 for each respondent)
	casetime - casecontrol*time
	death - indicates the wave of death and all subsequent waves
	deathtime - death*time	
	censored - indicates the first wave in which a respondent is not present and
			   takes on the value of 1 for all subsequent waves  
	centime - takes on the value of the period in which the respondent was first 
				censored (for the entire study period)
	fullobs - identifies waves in which the respondent is fully observed (duration2=24)
	obs - identifies waves in which the respondent was at least partiall observed 
		 (as in the wave of death)
	obs2 - modifies 'obs' to include waves between being censored and having 
		   completed an exitwave		
*/

gl data "U:\Projects\OOP_Costs\update"


*** Direct Medicare Expenditures Analysis ***
clear
eststo clear



gl xlist "casecontrol male age white hispan itot hibpe diabe cancre lunge hearte rstroke psyche arthre"
gl vars "casetime duration2 yfromind2 yfromind3 yfromind4"


foreach val in full male female white_nonhis nonwhite {
foreach a in total nh hosp drug doc { 

		loc table1 "$output\OOP_Costs_exp_`a'_`val'.rtf"
	
set obs 1
g simul=.
sa "$data\bootdata_exp_`a'_`val'.dta", replace

forv iter = 1/$reps {
clear all 
cap est sto clear	
use "$data\match.dta"
		
		if "`val'"=="male" {
		keep if male==1
		}

		if "`val'"=="female" {
		keep if male==0
		}
		
		if "`val'"=="white_nonhis" {
		keep if white==1 & hispan==0
		}

		if "`val'"=="nonwhite" {
		keep if white==0 | hispan==1
		}

*generate indicators for any expenditure
foreach var in total hosp drug doc nh other {
	recode exp_`var' (.=.) (0=0) (else=1), g(ind_`var')
}

bsample, cluster(id) idcluster(freshid)
so freshid time

*topcoding the highest 1% - replace with 99th percentile value
	su exp_`a'
	_pctile exp_`a', nq(100)
	replace exp_`a' = r(r99) if exp_`a'>r(r99) & exp_`a'!=.

********************************************************************************
// MODELING COSTS IN INTERVALS BEFORE OBSERVED DEATH

		capture log using "$data\02_est_exp_`a'_`val'.log", replace

keep exp_* ind_* $xlist $vars fullobs obs obs2 time centime death deathtime hhidpn durold casecontrolold yfromind1 id
cap preserve


** First part of two part model - find probability of incurring any cost while alive => mat b
cap logit ind_`a' $xlist $vars if fullobs==1, cluster(hhidpn)

if _rc==0 & e(converged)==1 {
    
mat b=e(b)
restore

** PREDICT FOR ALL PATIENT TIME INTERVALS as If patient was alive during the entirety of the interval

	/* treat everyone as if they had never died */
	cap drop p2* 
	cap drop xb
	replace duration2=24 if time==deathtime | time==centime | duration2==0  
		predict p2,p
	
		/* treat everyone as a control */
		replace casecontrol=0 
		replace casetime=casecontrol*time 
		
			/* create a scalar of the sum of the coefficients*x values */
			mat score xb=b     
			/* generate the probability that any cost was incurred */
			g p2_0 = exp(xb)/(1+ exp(xb))
			drop xb

		/* treat everyone as a case */
		replace casecontrol=1
		replace casetime=casecontrol*time
		
			/* create a scalar of the sum of the coefficients*x values */
			mat score xb=b
			/* generate the probability that any cost was incurred */
			g p2_1 = exp(xb)/(1+ exp(xb))
			drop xb

/* return indicators to baseline values */		
replace duration2=durold						
replace casecontrol=casecontrolold
replace casetime=casecontrol*time

preserve

** SECOND PART OF TWO PART MODEL
	keep if fullobs==1 & exp_`a' >0 & exp_`a'!=. 
	compress
	glm exp_`a' $xlist $vars, cluster(hhidpn) link(log) family(gamma) iterate(50) difficult

	capture {
	mat bg=e(b)
	capture restore

	** PREDICT FOR ALL PATIENT TIME INTERVALS as If patient was alive during the entirety of the interval
	replace duration2=24 if time==deathtime | time==centime | duration2==0
	replace casecontrol=0 
	replace casetime=casecontrol*time
	mat score xb=bg
	g mu2_0 = exp(xb)
	drop xb

	replace casecontrol=1
	replace casetime=casecontrol*time
	mat score xb=bg
	g mu2_1 = exp(xb)
	drop xb

	replace duration2=durold
	replace casecontrol=casecontrolold
	replace casetime=casecontrol*time

	// full predictions for E(Y| No Death)
	forv i=0/1 {
	capture g mu2p_`i' = p2_`i'*mu2_`i'
	}
	}
	
********************************************************************************
// MODELING COSTS IN INTERVALS OF OBSERVED DEATH
capture drop mu1 mu1_pred
preserve

keep if death==1 & time==deathtime 
*compress

/*FIRST PART OF THE MODEL*/
cap logit ind_`a' $xlist $vars, cluster(hhidpn)

if _rc==0 & e(converged)==1 {

mat d=e(b)
restore 

// Make predictions after integrating out time of death within an interval
proportion duration2 if time==deathtime   
mat prop=e(b)

replace casecontrol=0
replace casetime=casecontrol*time
g pu1p_0=0
loc k=1

forv i=1(1)25 {		
replace duration2=`i'
mat score xdg = d
g tg = exp(xdg)/(1+ exp(xdg))
g prod = prop[1,`k']*tg
replace pu1p_0 = pu1p_0+prod
drop tg prod xdg
loc k = `k' + 1
}

replace casecontrol=1
replace casetime=casecontrol*time
g pu1p_1=0
loc k=1

forv i=1(1)25 {
replace duration2=`i'
mat score xdg = d
g tg = exp(xdg)/(1+ exp(xdg))
g prod = prop[1,`k']*tg
replace pu1p_1 = pu1p_1+prod
drop tg prod xdg
loc k = `k' + 1
}


/*restore the values after prediction*/
replace duration2 = durold
replace casecontrol = casecontrolold
replace casetime = casecontrol*time


preserve /*check*/

/*SECOND PART OF 2 PART MODEL*/
keep if exp_`a' >0 & exp_`a'!=. 
keep if death==1 & time==deathtime 
compress
glm exp_`a' $xlist $vars, link(log) family(gamma) robust iterate(50) difficult


capture {
mat bg = e(b)
capture restore
 
// Make predictions after integrating out time of death within an interval
proportion duration2 if time==deathtime   
mat prop=e(b)

replace casecontrol=0
replace casetime=casecontrol*time
g mu1_0=0
loc k=1

forv i=1(1)25 {		
replace duration2=`i'
mat score xbg = bg
g tg = exp(xbg)
g prod = prop[1,`k']*tg
replace mu1_0 = mu1_0+prod
drop tg prod xbg
loc k = `k' + 1
}

replace casecontrol=1
replace casetime=casecontrol*time
g mu1_1=0
loc k=1

forv i=1(1)25 {
replace duration2=`i'
mat score xbg = bg
g tg = exp(xbg)
g prod = prop[1,`k']*tg
replace mu1_1 = mu1_1+prod
drop tg prod xbg
loc k = `k' + 1
}

// full predictions for E(Y| No Death)
	forv i=0/1 {
	capture g mu1p_`i' = pu1p_`i'*mu1_`i'
	}

replace casecontrol=casecontrolold
replace casetime=casecontrol*time
replace duration2=durold

}

***************************************************************************************************************************
* SURVIVAL ESTIMATORS
	capture drop _*
	stset time if obs2==1
	streset if obs2==1, id(id) failure(death==1) 

	capture drop s0
	capture drop st 
	compress
	streg $xlist if obs2==1, cluster(hhidpn) dist(lognormal) time iterate(50)
	
	replace _st=1 if obs2==0
	replace _d=0 if obs2==0
	replace _t=time if obs2==0
	replace _t0=time-1 if obs2==0
	
	predict surv, surv 
	predict csurv, csurv oos
	g haz=1-surv
	
		/* treat everyone as a control */
		replace casecontrol=0
		/* predict the survivor function (each observation's predicted survivor probability) */
		predict surv0, surv 
		/* predict the cumulative survivor function */
		predict csurv0, csurv oos
		g haz0=1-surv0
		
		/* treat everyone as a case */
		replace casecontrol=1
		/* predict the survivor function (each observation's predicted survivor probability) */
		predict surv1, surv 
		/* predict the cumulative survivor function */
		predict csurv1, csurv oos
		g haz1=1-surv1
	
	replace casecontrol=casecontrolold
	
*	ta time, miss

// OVERALL PREDICTIONS
forv i =0/1 {
capture gen mu_`i' = csurv`i'*(haz`i'*mu1p_`i' + (1-haz`i')*mu2p_`i')
*capture g mu_`i' = csurv`i'*(mu2p_`i')
}

capture g ie10_survcons = csurv1*(haz1*mu1p_1 + (1-haz1)*mu2p_1) - csurv1*(haz0*mu1p_0 + (1-haz0)*mu2p_0)
capture g ie10_costcons = csurv1*(haz0*mu1p_0 + (1-haz0)*mu2p_0) - csurv0*(haz0*mu1p_0 + (1-haz0)*mu2p_0)

keep if casecontrol==1

collapse (mean) exp_`a' csurv* haz* mu*  ie*, by(time)

gen simul = `iter'
di simul

append using "$data/bootdata_exp_`a'_`val'.dta"
sa "$data/bootdata_exp_`a'_`val'.dta", replace
noi di `iter'
} /* end if 2nd logit converges */
		else {
			clear
		} /* end if 2nd logit doesn't converge */
		
	} /* end if 1st logit converges */
clear	
	else {
		clear
	} /* end if 1st logit doesn't converge */
*cap est sto clear	
} /* end iteration loop */
*cap est sto clear	

use "$data/bootdata_exp_`a'_`val'.dta"
su time
di "`a'"
di "a"

drop if time==.|time==5

g incrementalcost=ie10_survcons+ie10_costcons
g incrementalcostalive = mu2p_1-mu2p_0

bysort time simul: egen cummu0=total(mu_0)
bysort time simul: egen cummu1=total(mu_1)
bysort time simul: egen cumsurvcons=total(ie10_survcons)
bysort time simul: egen cumcostcons=total(ie10_costcons)
bysort time simul: egen cumincrementalcost=total(incrementalcost)
bysort time simul: egen cumincrementalcostalive=total(incrementalcostalive)

*totals
bysort simul: egen cummu0_total=total(mu_0)
bysort simul: egen cummu1_total=total(mu_1)
bysort simul: egen cumsurvcons_total=total(ie10_survcons)
bysort simul: egen cumcostcons_total=total(ie10_costcons)
bysort simul: egen cumincrementalcost_total=total(incrementalcost)
bysort simul: egen cumincrementalcostalive_total=total(incrementalcostalive)

loc list cummu1 cummu0 cumsurvcons cumcostcons cumincrementalcost cumincrementalcostalive
loc count 1 2 3 4 
	foreach u in `list' {
	    g `u'_lb=.
	    g `u'_ub=.
		foreach w in `count' {
			_pctile `u' if time==`w', p(2.5, 97.5)
			return list
			replace `u'_lb = r(r1) if time==`w'
			replace `u'_ub = r(r2) if time==`w'
		}
	}

	
loc list cummu1_total cummu0_total cumsurvcons_total cumcostcons_total cumincrementalcost_total cumincrementalcostalive_total
	foreach v in `list' {
	    g `v'_lb=.
	    g `v'_ub=.
			_pctile `v', p(2.5, 97.5)
			return list
			replace `v'_lb = r(r1)
			replace `v'_ub = r(r2)
		}

		
*collapse and concatenate to get final formatting ready
collapse (mean) cummu1 cummu0 cumsurvcons cumcostcons cumincrementalcost cumincrementalcostalive cummu1_total cummu0_total cumsurvcons_total cumcostcons_total cumincrementalcost_total cumincrementalcostalive_total *_lb *_ub, by(time)


rename cumincrementalcostalive_total cuminccostalive_total
rename cumincrementalcostalive_total_lb cuminccostalive_total_lb
rename cumincrementalcostalive_total_ub cuminccostalive_total_ub


loc list cummu1 cummu0 cumsurvcons cumcostcons cumincrementalcost cumincrementalcostalive cummu1_total cummu0_total cumsurvcons_total cumcostcons_total cumincrementalcost_total cuminccostalive_total
foreach var in `list' {	

	g `var'_st = string(`var', "%3.0f")	
	g `var'_lb_st = string(`var'_lb, "%3.0f")	
	g `var'_ub_st = string(`var'_ub, "%3.0f")	
		g `var'_final = "$" + `var'_st + "" + "(" + `var'_lb_st + ";" + "" + `var'_ub_st + ")"	
		
}	
keep time *final

tempfile orig
sa `orig'
	keep *total*
	keep if _n==1
	rename *_total* **
	rename cuminccostalive_final cumincrementalcostalive_final
append using `orig'

drop *_total* 
replace time=5 if time==.
order time 
so time


	label var cummu1_final "Participants with dementia diagnosis"
	label var cummu0_final "Predicted costs without dementia"
	label var cumsurvcons_final "Incremental costs if survival held constant"
	label var cumcostcons_final "Incremental costs due to changed survival"
	label var cumincrementalcost_final "Total incremental costs"
	label var cumincrementalcostalive_final "Conditional on being alive"


*export to excel 
export excel using "$data/exp_`a'_`val'_educ.xlsx", firstrow(variables) replace

clear all
log close

}
}
