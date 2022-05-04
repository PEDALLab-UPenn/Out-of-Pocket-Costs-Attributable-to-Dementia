
*****************************************
*  This file imports COGIMP9216A_R.da   *
* 		and creates lw_data.dta 		*
* 	containing impairment index lw* 	*
*****************************************
*Normal (12-27; 0), CIND (7-11; 1), Dementia (0-6; 2)

clear all

infile using "$data/COGIMP9216A_R.dct", using("$data/COGIMP9216A_R.da")

	destring HHID, g(hhid)
	tostring hhid, replace
	g hhidpn = hhid+PN

	forval x = 3/13 {
		egen score`x'=rowtotal(R`x'IMRC R`x'DLRC R`x'SER7 R`x'BWC20)
		replace score`x'=. if R`x'IMRC==.|R`x'DLRC==.|R`x'SER7==.|R`x'BWC20==.
		recode score`x' (0/6=2) (7/11=1) (12/27=0), g(lw`x')
	}

keep hhidpn lw*
sa "$data/lw_data.dta", replace
clear

************************************************
*COGIMP9216A_R does not code proxy responses
*Normal (0-2; 0), CIND (3-5; 1), Dementia (6-11; 2)


** The RAND file did not have all of the needed variables to calculate cognitive scores. Grab extra variables from each RAND core fat file. **
	loc x d1056 	e1056 	f1373  /* rates memory 1 (excellent) to 5 (poor) */
**# Bookmark #1
	loc y ad95f2b 	h96f4a 	hd98f2c
	loc n : word count `x'
	forval i=1/3 {
		loc a : word `i' of `x'
		loc b : word `i' of `y'
	use hhidpn `a' using "$data/`b'.dta", clear
	so hhidpn 
	tempfile temp`i'
	sa `temp`i''
	clear
	}

	loc t g1527 	hd501 	jd501 	kd501 	ld501 	md501 	nd501 	od501  pd501 
	loc u g517 		ha011 	ja011 	ka011 	la011 	ma011 	na011 	oa011  pa011
	loc v h00f1c 	h02f2c 	h04f1b 	h06f3a 	h08f3a 	hd10f5e h12f2a 	h14f2a h16f2a
	loc n : word count `t'
	loc g 4
	forval j=1/`n' {
		loc a : word `j' of `t'
		loc b : word `j' of `u'
		loc c : word `j' of `v'
	use hhidpn `a' `b' using "$data/`c'.dta", clear
	so hhidpn 
	tempfile temp`g'
	sa `temp`g''
	loc g = `g'+1
	clear
	}

** Merge all of the extra core variables onto the RAND dataset
use `temp1'
forval z = 2/12 {
merge 1:1 hhidpn using `temp`z'', nogen
}

	** Fill with scores if proxy completed interview - clean up the variables that were not included in RAND dataset so consistently coded
		** Proxy assessment of respondent's memory
		g pcratememory3=d1056
		replace pcratememory3=e1056 if missing(d1056)
		recode pcratememory3 (1=0) (2=1) (3=2) (4=3) (5=4) (else=.)

		loc d  f1373 		 g1527 		   hd501 		 jd501 		   kd501 		 ld501 		   md501 		  nd501 		 od501 		    pd501
		loc e  pcratememory4 pcratememory5 pcratememory6 pcratememory7 pcratememory8 pcratememory9 pcratememory10 pcratememory11 pcratememory12 pcratememory13
		loc n : word count `d'
		forval f=1/`n' {
			loc g : word `f' of `d'
			loc h : word `f' of `e'
			recode `g' (1=0) (2=1) (3=2) (4=3) (5=4) (else=.), g(`h')
		}

		** Interviewer's assessment of difficulty completing interview
		recode g517 (1=0) (2=1) (3/4=2) (else=.), g(diffcompint5)
		loc j ha011 	   ja011 		ka011 		 la011 		  ma011 		na011 		  oa011 	    pa011 
		loc k diffcompint6 diffcompint7 diffcompint8 diffcompint9 diffcompint10 diffcompint11 diffcompint12 diffcompint13
		loc n : word count `j'
		forval z=1/`n' {
			loc l : word `z' of `j'
			loc m : word `z' of `k'
			recode `l' (1=0) (2=1) (3=2) (else=.), g(`m')
		}
		
		tempfile cogimp
		sa `cogimp'
		
	use hhidpn hhid pn r*iadlza using "$data/randhrs1992_2016v1.dta", clear
	merge 1:1 hhidpn using `cogimp', keep(matched) nogen

	keep hhidpn *iadlza pcrate* diffcomp*
	drop r2iadlza
		
forval x = 5/13 {
	egen proxy_score`x' = rowtotal(r`x'iadlza pcratememory`x' diffcompint`x')
		replace proxy_score`x'=. if r`x'iadlza==. & pcratememory`x'==. & diffcompint`x'==.
	recode proxy_score`x' (0/2=0) (3/5=1) (6/11=2), g(proxy_lw`x')
}	
	
	keep hhidpn proxy_lw*
	tostring hhidpn, replace
	merge 1:1 hhidpn using "$data/lw_data.dta"
	
	order hhidpn *3 *4 *5 *6 *7 *8 *9 *10 *11 *12 *13
	
forval x = 5/13 {
	replace lw`x' = proxy_lw`x' if lw`x'==.
}
keep hhidpn lw*	
order lw13, last
sa "$data/lw_data.dta", replace
