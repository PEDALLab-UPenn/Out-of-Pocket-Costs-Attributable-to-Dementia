**README file for posted estimation files**

**&quot;Out-of-pocket costs attributable to dementia: A longitudinal analysis&quot;**

by Melissa Oney, Lindsay White, and Norma B. Coe

**Overview:**

Before running the code:

- Copy file contents into project folder with the following subfolders: do, output, log, and data

- Change the file path of the folder global (&quot;gl folder&quot;) in 000\_master.do to the location of the project folder

- Save all data in the data subfolder (and additional subfolders as described below)

- Select which sample to run by changing local values from 0 to 1 (local macros in lines 46-58 of 00master.do).

Once these changes have been made, running the master file will produce the tables corresponding to the selected sections (noted after each local in 000\_master.do). The number of replications and iterations can be adjusted in &quot;gl reps&quot; of 000\_master.do.

For questions about the code, please contact Melissa Oney (Melissa.oney@pennmedicine.upenn.edu).

**Data required:**

Register for access to the HRS and RAND HRS data on the HRS website ([https://hrs.isr.umich.edu/data-products](https://hrs.isr.umich.edu/data-products)), then download the following files (both .dct and .da, or .dta where noted):

- Supplementary files: COGIMP9216A\_R
- HRS tracker file: trk2018tr\_r.dta
- RAND HRS Fat Files: ad95f2b, h96f4a, hd98f2c, h00f1c, h02f2c, h04f1b, h06f3a, h08f3a, hd10f5e, h12f2a, h14f2a, h16e2a
- RAND HRS Longitudinal File: randhrs1992\_2016v2.dta
- RAND HRS Detailed Imputations File: randhrsimp1992\_2014v2.dta

Place all data files in the data folder. Ensure that the paths in the .dct files point to the location of the .da files.

**Running the code:**

This code is for Stata, and has been verified to run in version 16. The estout package is required to output tables.

**Description of files:**

The following describes how the files correspond to the inputs and output:

| File | Description | Inputs/Outputs | Notes |
| --- | --- | --- | --- |
| 000\_master.do | Sets macros for all variables, specifications, and replications used in the other files |
 | Only edit the global folder and the individual global macros |
| 00\_langaweir.do | Cleans supplementary data – Langa-Weir Classification of Cognitive Function, and adds in proxy responses | Input: COGIMP9216A\_R, RAND HRS Fat files, randhrs1992\_2016v2.dta
Output: lw\_data.dta |
 |
| 01\_cleanandmerge.do | Cleans and merges all raw data files | Input: HRS tracker file, RAND HRS Fat files, randhrs1992\_2016v2.dta, randhrsimp1992\_2014v2.dta, lw\_data.dta,
Output: match.dta |
 |
| 02\_est.do | Runs Basu and Manning method | Input: match.dta
Output: Sample-specific tables | Use the local macros in 000\_master.do to select which set of tables to produce |
| 03\_summarystatistics.do | Creates summary statistics | Input: match.dta
Output: Sample-specific summary statistics tables |
 |
