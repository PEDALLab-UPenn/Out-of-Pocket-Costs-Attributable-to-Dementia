
* Original file corrupted 4/14/21 - below is the output from the log file *
  
 gl data "U:\Projects\OOP_Costs\update"
         loc table2 "$output\SST_baseline.rtf"

  use "$data\sumstats.dta", clear
    
	*make sure that all period 0 variables are included
	so id time
	foreach var in casecontrol male age white hispan itot hibpe diabe cancre lunge hearte rstroke psyche arthre {
	    bys id: replace `var' = `var'[n+1] if `var'==.
	}
	
	/*setting the sample
	drop if casecontrol==.|male==.|age==.|white==.|hispan==.|itot==.|hibpe==.|diabe==.|cancre==.|lunge==.|hearte==.|rstroke==.|psyche==.|arthre==.
	*/
	
*find no LTCI group

	recode govmr_current (0=0) (1=1) (else=.)
	recode govmd_current (0=0) (1=1) (else=.)
	recode govva_current (0=0) (1=1) (else=.)
	recode hiltc_current (0=0) (1=1) (else=.)

	g no_ltci=1
		replace no_ltci=. if govmd_current==.&govva_current==.&hiltc_current==.
		replace no_ltci=0 if govmd_current==1|govva_current==1|hiltc_current==1

*create race & education categories	
	recode raeduc (1=1) (2/5=0), g(lhs)	
	recode raeduc (1=0) (2/3=1) (4/5=0), g(hs_ged)	
	recode raeduc (1/3=0) (4/5=1), g(some_col)	

	g nonhispanic_white=white
		replace nonhispanic_white=0 if hispan==1

*apply variable labels	
	label var male "Male (%)"
	label var age "Age"
	label var nonhispanic_white "Non-Hispanic White (%)"
	label var white "White (%))"
	label var hispan "Hispanic (%)"
	label var lhs "Less than high school (%)"
	label var hs_ged "High school/GED (%)"
	label var some_col "At least some college (%)"
	label var itot "Income (2017 dollars)"
	label var hibpe "High blood pressure"
	label var diabe "Diabetes"
	label var cancre "Cancer"
	label var lunge "Lung disease"
	label var hearte "Heart problems"
	label var rstroke "Stroke"
	label var psyche "Psychiatric problems"
	label var arthre "Arthritis"
	label var no_ltci "No LTCI Source"
	label var govmd_current "Medicaid"
	label var govva_current "VA"
	label var hiltc_current "Private LTCI"
	label var exp_total "Total"
	label var exp_hosp "Hospital"
	label var exp_nh "Nursing home"
	label var exp_doc "Doctor"
	label var exp_drug "Prescription drug"
	label var exp_other "Other"
	
	
	
	
********************************************************************************	
	
loc outcome     exp_total exp_hosp exp_nh exp_doc exp_drug exp_other 

loc vars        male age nonhispanic_white white hispan lhs hs_ged some_col itot ///
				hibpe diabe cancre lunge hearte rstroke psyche arthre ///
				no_ltci govmd_current govva_current hiltc_current
				
			
loc vars1               nonhispanic_white white hispan lhs hs_ged some_col 
loc vars2               hibpe diabe cancre lunge hearte rstroke psyche arthre			
loc vars3               no_ltci govmd_current govva_current hiltc_current

         *get first-matched pairs in wave before diagnosis
         keep if time==0&num==1
 
         estpost su `vars' `outcome'
         est sto E

         estpost su `vars' `outcome' if casecontrol==1
         est sto F

         estpost su `vars' `outcome' if casecontrol==0
         est sto G

  
		*produce and save p-values 
           capture prtest male, by(casecontrol)
           replace male = r(p)

           ttest age, by(casecontrol)
           replace age = r(p)
 
         foreach w in `vars1' {
           di "`w'"
           capture prtest `w', by(casecontrol)
           replace `w' = r(p)
           }
 
           ttest itot, by(casecontrol)
           replace itot = r(p)
 
         foreach x in `vars2' {
           di "`x'"
           capture prtest `x', by(casecontrol)
           replace `x' = r(p)
           }   
 
         foreach y in `vars3' {
           di "`y'"
           capture prtest `y', by(casecontrol)
           replace `y' = r(p)
           }
		   
         foreach z in `outcome' {
           di "`z'"
           ttest `z', by(casecontrol)
           replace `z' = r(p)
           }


         estpost su male age `vars1' itot `vars2' `vars3' `outcome' 
         est sto H

 
         esttab E F G H using `table2', ti("Table 1. Summarizing Out-of-Pocket Costs and Respondent Characteristics at Baseline, by Dementia Status") mtitles("Full sample" "Received a dementia - qualifying score" "Never received a dementia - qualifying score" "Diff. (p-value)") addnote("Notes: All variables are at the respondent level and unweighted. The baseline period is defined as the wave prior to the wave in which the respondent received a dementia-qualifying score. Insurance categories are not mutually exclusive.") cells("mean(fmt(a3))") l replace
         
 capture log close

 
 
 
 /*Other stats for draft 
 
 use "$data\match.dta", clear

 *average number of waves (2.8)
 bys id: egen wave_count = sum(obs2)
	su wave_count

 *unique individuals (5751)
 so hhidpn time
 bys hhidpn time: g unique = cond(_N==0, 0, _n)
	ta unique if unique==1&time==1
	
 *cases, controls, or both	(3303, 2132, 316)
 keep if time==1
 collapse (mean) casecontrol, by(hhidpn)
	recode casecontrol (0=0) (1=1) (else=.5)
	ta casecontrol
	
clear	
 */