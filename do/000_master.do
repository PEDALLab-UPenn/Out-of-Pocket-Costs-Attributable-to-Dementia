
********************************************************************************
*							OOP COSTS MASTER DO FILE			 			   *
********************************************************************************

/*
GENERAL NOTES:
- This is the master do-file for the OOP Costs project.
- This do-file defines folder and data globals and allows to choose which sections and tables to run.
- Adjust your folderpaths and globals in the respective fields.
*/

********************************************************************************

*DATA GLOBALS

if 1 {

*select path
gl name 1

	if $money {
	gl folder					""
	gl data						""
	gl RAND						""				/* update when ready to submit */
	gl HRS						""					/* update when ready to submit */
	}

}

*FOLDER GLOBALS

gl do			   				"$folder"
gl output		  				"$folder"
gl log			   				"$folder"
gl subfolder					"$do\createdataset"

*CHOOSE SECTIONS TO RUN
	
loc create_lw					0	/* Activate this section to create the LW dataset 		  */	
loc clean_merge					0 	/* Activate this section to run "01_cleanandmerge.do" */
loc estimation					0	/* Activate this section to run "02_est" 		 	  */ 
loc tables						0	/* Activate this section to run "03_tables" 		  */
loc medicaid					0 	/* Activate this section to run "04_medicaid.do" 	  */


gl reps 						1000

*Select sample to run 
** >> currently in est file << **


********************************************************************************
*					   PART 1:  RUN DO-FILES								   *
********************************************************************************

* PART 0: CREATE DATASET	

	if `create_lw' {
		do "$subfolder\000_langaweir.do"
	}	
	
* PART 1: CLEAN AND MERGE

	if `clean_merge' {
		do "$do\01_cleanandmerge.do"
	}
		

*PART 2: RUN ANALYSIS	
	
	if `estimation' {
		do "$do\02_est.do"
	}

* PART 3: CREATE TABLES	

	if `tables' {
		do "$do\03_tables.do"
	}

* PART 4: MEDICAID	

	if `medicaid' {
		do "$do\04_medicaid.do"
	}
	