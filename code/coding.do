/*==============================================================
  Project: SNAP and Household Nutrition (FoodAPS)
  Author:  Baimat Niiazaliev
  Date:    April 2026

  Description:
    Full reproducible pipeline:
    - data cleaning
    - merging
    - OLS regressions
    - matching (NN, PSM)
    - IPW
    - tables and figures

    Uses relative paths (REPRODUCIBLE)
==============================================================*/

clear all
set more off

*--------------------------------------------------------------*
* 0. Project paths (REPRODUCIBLE)
*--------------------------------------------------------------*

global root = "`c(pwd)'"

global data_raw    "$root/data/raw"
global data_clean  "$root/data/clean"
global output      "$root/output"
global figures     "$output/figures"
global tables      "$output/tables"
global logs        "$output/logs"

* Create folders if needed
capture mkdir "$data_clean"
capture mkdir "$output"
capture mkdir "$figures"
capture mkdir "$tables"
capture mkdir "$logs"

*--------------------------------------------------------------*
* 1. Log file
*--------------------------------------------------------------*

capture log close

local today = c(current_date)
local d = date("`today'", "DMY")

local logdate = string(year(`d'), "%04.0f") + ///
               string(month(`d'), "%02.0f") + ///
               string(day(`d'), "%02.0f")

log using "$logs/log_`logdate'.log", replace text

di "========================================================"
di " Log started: $S_DATE $S_TIME"
di "========================================================"

*--------------------------------------------------------------*
* 2. Load household data
*--------------------------------------------------------------*

use "$data_raw/faps_household_puf.dta", clear

keep ///
    hhnum snapnowhh inchhavg_r region rural hhsize ///
    foodsufficient adltfscat housingpub housingsub ///
    liqassets caraccess primstoredist_d ///
    healthycost healthytime dietstatushh

save "$data_clean/hh_temp.dta", replace

*--------------------------------------------------------------*
* 3. Load nutrient data
*--------------------------------------------------------------*

use "$data_raw/faps_fafhnutrient_puf.dta", clear

*--------------------------------------------------------------*
* 4. Merge
*--------------------------------------------------------------*

merge m:1 hhnum using "$data_clean/hh_temp.dta"
drop if _merge == 2
drop _merge

*--------------------------------------------------------------*
* 5. Outcomes
*--------------------------------------------------------------*

gen calories  = energy
gen sugar     = totsug
gen sodium_mg = sodium
gen fat       = totfat

gen calories_pc = calories / hhsize
gen ln_calories = log(calories + 1)

*--------------------------------------------------------------*
* 6. Collapse
*--------------------------------------------------------------*

collapse ///
    (sum) calories sugar sodium_mg fat ///
    (mean) calories_pc ln_calories ///
    , by(hhnum snapnowhh inchhavg_r region rural hhsize ///
         foodsufficient adltfscat housingpub housingsub ///
         liqassets caraccess primstoredist_d ///
         healthycost healthytime dietstatushh)

*--------------------------------------------------------------*
* 7. Cleaning
*--------------------------------------------------------------*

drop if snapnowhh < 0
rename inchhavg_r income
rename sodium_mg sodium
drop if income < 0

save "$data_clean/analysis_dataset.dta", replace

*--------------------------------------------------------------*
* 8. Descriptive stats
*--------------------------------------------------------------*

tab snapnowhh

summ calories if snapnowhh==1
summ calories if snapnowhh==0

*--------------------------------------------------------------*
* 9. OLS
*--------------------------------------------------------------*

reg calories snapnowhh

reg calories ///
    snapnowhh income rural i.region, robust

reg calories ///
    snapnowhh income rural i.region ///
    hhsize foodsufficient liqassets caraccess ///
    primstoredist_d healthycost healthytime, robust

*--------------------------------------------------------------*
* 10. Propensity score
*--------------------------------------------------------------*

logit snapnowhh ///
    income rural i.region hhsize foodsufficient ///
    liqassets caraccess primstoredist_d ///
    healthycost healthytime

predict pscore, pr

*--------------------------------------------------------------*
* 11. Graphs
*--------------------------------------------------------------*

twoway ///
 (kdensity pscore if snapnowhh==1) ///
 (kdensity pscore if snapnowhh==0), ///
 legend(label(1 "SNAP") label(2 "Non-SNAP")) ///
 title("Propensity Score Overlap")

graph export "$figures/pscore.png", replace

*--------------------------------------------------------------*
* 12. Matching
*--------------------------------------------------------------*

teffects nnmatch ///
    (calories income rural region hhsize ///
     foodsufficient liqassets caraccess) ///
    (snapnowhh), atet

teffects psmatch ///
    (calories) ///
    (snapnowhh income rural region hhsize ///
     foodsufficient liqassets caraccess ///
     primstoredist_d healthycost healthytime), atet

tebalance summarize

*--------------------------------------------------------------*
* 13. IPW
*--------------------------------------------------------------*

teffects ipw ///
    (calories) ///
    (snapnowhh income rural region hhsize ///
     foodsufficient liqassets caraccess), atet

*--------------------------------------------------------------*
* 14. Table
*--------------------------------------------------------------*

eststo clear

eststo ols: reg calories ///
    snapnowhh income rural i.region ///
    hhsize foodsufficient liqassets caraccess ///
    primstoredist_d healthycost healthytime, robust

eststo psm: teffects psmatch ///
    (calories) ///
    (snapnowhh income rural region hhsize ///
     foodsufficient liqassets caraccess ///
     primstoredist_d healthycost healthytime), atet

esttab ols psm using "$tables/results.rtf", replace ///
    se star(* 0.10 ** 0.05 *** 0.01)

*--------------------------------------------------------------*
* 15. Close log
*--------------------------------------------------------------*

di "========================================================"
di " Log closed: $S_DATE $S_TIME"
di "========================================================"

log close
