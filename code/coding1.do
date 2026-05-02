/*==============================================================
  Project: SNAP and Household Nutrition (FoodAPS)
  Author:  [Your Name]
  Date:    April 2026
  Description:
    Full pipeline — data merge, cleaning, descriptive stats,
    OLS regressions, propensity score matching, IPW.
    Outputs are organized into data/clean/ and output/.
==============================================================*/

clear all
set more off

*--------------------------------------------------------------*
* 0. Working directory and folder setup
*--------------------------------------------------------------*

cd "C:\Users\Admin\Desktop\advanced econometrics\project"

* Create subdirectories if they don't exist yet
capture mkdir "data\clean"
capture mkdir "output\figures"
capture mkdir "output\tables"
capture mkdir "output\logs"

*--------------------------------------------------------------*
* 1. Start log file
*--------------------------------------------------------------*

* Close any open log first (safe guard)
capture log close
local logdate = subinstr("`c(current_date)'"," ","",.)


log using "output\logs\coding_`logdate'.log", replace text

di "========================================================"
di "  Log started: $S_DATE $S_TIME"
di "========================================================"

*--------------------------------------------------------------*
* 2. Load and subset household data  (RAW — never modified)
*--------------------------------------------------------------*

use "data/raw/faps_household_puf.dta", clear

keep ///
    hhnum         ///
    snapnowhh     ///
    inchhavg_r    ///
    region        ///
    rural         ///
    hhsize        ///
    foodsufficient ///
    adltfscat     ///
    housingpub    ///
    housingsub    ///
    liqassets     ///
    caraccess     ///
    primstoredist_d ///
    healthycost   ///
    healthytime   ///
    dietstatushh

* Save cleaned household subset to data/clean/
save "data\clean\hh_temp.dta", replace
di ">> Saved: data\clean\hh_temp.dta"

*--------------------------------------------------------------*
* 3. Load nutrient data  (RAW)
*--------------------------------------------------------------*

use "data/raw/faps_fafhnutrient_PUF.dta", clear

*--------------------------------------------------------------*
* 4. Merge household information
*--------------------------------------------------------------*

merge m:1 hhnum using "data\clean\hh_temp.dta"

drop if _merge == 2   // households with no nutrient records
drop _merge

*--------------------------------------------------------------*
* 5. Create nutrition outcome variables
*--------------------------------------------------------------*

gen calories    = energy
gen sugar       = totsug
gen sodium_mg   = sodium
gen fat         = totfat

* Per-capita calories BEFORE collapse
gen calories_pc = calories / hhsize

* Log specification (safe)
gen ln_calories = log(calories + 1)

*--------------------------------------------------------------*
* 6. Collapse to household level
*--------------------------------------------------------------*

collapse                       ///
    (sum)  calories sugar sodium_mg fat  ///
    (mean) calories_pc ln_calories       ///
    , by(                      ///
        hhnum                  ///
        snapnowhh              ///
        inchhavg_r             ///
        region                 ///
        rural                  ///
        hhsize                 ///
        foodsufficient         ///
        adltfscat              ///
        housingpub             ///
        housingsub             ///
        liqassets              ///
        caraccess              ///
        primstoredist_d        ///
        healthycost            ///
        healthytime            ///
        dietstatushh           ///
    )

*--------------------------------------------------------------*
* 7. Clean variables
*--------------------------------------------------------------*

drop if snapnowhh < 0
rename inchhavg_r income
rename sodium_mg  sodium
drop if income < 0

*--------------------------------------------------------------*
* 7b. Winsorize outcomes at 1st-99th percentile
*     Removes extreme outliers (e.g. calories max = 49,278)
*     that inflate standard errors without reflecting true
*     household consumption.
*     Requires: ssc install winsor2
*--------------------------------------------------------------*

capture ssc install winsor2, replace

winsor2 calories,    cuts(1 99) suffix(_w)
winsor2 calories_pc, cuts(1 99) suffix(_w)
winsor2 sugar,       cuts(1 99) suffix(_w)
winsor2 sodium,      cuts(1 99) suffix(_w)

* Show effect of winsorising
di "=== Calories: raw vs winsorised ==="
summ calories
summ calories_w

di "=== Calories per capita: raw vs winsorised ==="
summ calories_pc
summ calories_pc_w

* Save final analytic dataset to data/clean/
save "data\clean\analysis_dataset.dta", replace
di ">> Saved: data\clean\analysis_dataset.dta"

*--------------------------------------------------------------*
* 8. Descriptive statistics
*--------------------------------------------------------------*

tab snapnowhh

summ calories sugar sodium if snapnowhh == 1
summ calories sugar sodium if snapnowhh == 0
summ calories_pc if snapnowhh == 1
summ calories_pc if snapnowhh == 0

*--------------------------------------------------------------*
* 9. Baseline OLS
*--------------------------------------------------------------*

reg calories snapnowhh

reg calories            ///
    snapnowhh           ///
    income              ///
    rural               ///
    i.region, robust

*--------------------------------------------------------------*
* 10. Main OLS with full controls
*--------------------------------------------------------------*

reg calories            ///
    snapnowhh           ///
    income              ///
    rural               ///
    i.region            ///
    hhsize              ///
    foodsufficient      ///
    liqassets           ///
    caraccess           ///
    primstoredist_d     ///
    healthycost         ///
    healthytime, robust

*--------------------------------------------------------------*
* 11. Other nutrition outcomes
*--------------------------------------------------------------*

reg sugar               ///
    snapnowhh           ///
    income              ///
    rural               ///
    i.region            ///
    hhsize              ///
    foodsufficient      ///
    liqassets           ///
    caraccess, robust

reg sodium              ///
    snapnowhh           ///
    income              ///
    rural               ///
    i.region            ///
    hhsize              ///
    foodsufficient      ///
    liqassets           ///
    caraccess, robust

*--------------------------------------------------------------*
* 12. Propensity score model (logit)
*--------------------------------------------------------------*

logit snapnowhh         ///
    income              ///
    rural               ///
    i.region            ///
    hhsize              ///
    foodsufficient      ///
    liqassets           ///
    caraccess           ///
    primstoredist_d     ///
    healthycost         ///
    healthytime

predict pscore, pr

*--------------------------------------------------------------*
* 13. Propensity score overlap — save figures
*--------------------------------------------------------------*

twoway                                                          ///
    (histogram pscore if snapnowhh == 1, percent width(.02))   ///
    (histogram pscore if snapnowhh == 0, percent width(.02)),  ///
    legend(label(1 "SNAP households")                          ///
           label(2 "Non-SNAP households"))                     ///
    title("Distribution of Propensity Scores")                 ///
    xtitle("Propensity score")                                 ///
    ytitle("Percent")

graph export "output\figures\fig1_pscore_histogram.png", replace width(1200)
di ">> Saved: output\figures\fig1_pscore_histogram.png"

twoway                                                          ///
    (kdensity pscore if snapnowhh == 1, lwidth(medthick))      ///
    (kdensity pscore if snapnowhh == 0, lpattern(dash)),       ///
    legend(label(1 "SNAP households")                          ///
           label(2 "Non-SNAP households"))                     ///
    title("Propensity Score Overlap")                          ///
    xtitle("Propensity score")                                 ///
    ytitle("Density")

graph export "output\figures\fig2_pscore_overlap.png", replace width(1200)
di ">> Saved: output\figures\fig2_pscore_overlap.png"

*--------------------------------------------------------------*
* 14. Nearest Neighbor Matching (ATT)
*--------------------------------------------------------------*

teffects nnmatch        ///
    (calories           ///
        income rural region ///
        hhsize foodsufficient ///
        liqassets caraccess) ///
    (snapnowhh), atet

teffects nnmatch        ///
    (calories_pc        ///
        income rural region ///
        hhsize foodsufficient ///
        liqassets caraccess) ///
    (snapnowhh), atet

* Bias-adjusted
teffects nnmatch        ///
    (calories_pc        ///
        income rural region ///
        hhsize foodsufficient ///
        liqassets caraccess) ///
    (snapnowhh),        ///
    atet                ///
    biasadj(income rural region hhsize)

*--------------------------------------------------------------*
* 15. Propensity Score Matching (main strategy)
*--------------------------------------------------------------*

teffects psmatch        ///
    (calories)          ///
    (snapnowhh          ///
        income          ///
        rural           ///
        region          ///
        hhsize          ///
        foodsufficient  ///
        liqassets       ///
        caraccess       ///
        primstoredist_d ///
        healthycost     ///
        healthytime),   ///
    atet

teffects psmatch        ///
    (calories_pc)       ///
    (snapnowhh          ///
        income          ///
        rural           ///
        region          ///
        hhsize          ///
        foodsufficient  ///
        liqassets       ///
        caraccess       ///
        primstoredist_d ///
        healthycost     ///
        healthytime),   ///
    atet

tebalance summarize

*==============================================================*
* 16. IMPROVED COMMON SUPPORT — три стратегии
*     (вставляется между основным PSM и IPW)
*==============================================================*

* ── СТРАТЕГИЯ A: Trimming по common support ────────────────*
*
* Сохраняем полный датасет, чтобы вернуться к нему после trim

preserve

    * Границы pscore в каждой группе
    summ pscore if snapnowhh == 1
    local pmin_snap = r(min)
    local pmax_snap = r(max)

    summ pscore if snapnowhh == 0
    local pmin_ctrl = r(min)
    local pmax_ctrl = r(max)

    * Пересечение = зона common support
    local cs_low  = max(`pmin_snap', `pmin_ctrl')
    local cs_high = min(`pmax_snap', `pmax_ctrl')

    di "Common support: [`cs_low', `cs_high']"
    di "Observations before trim: " _N

    keep if pscore >= `cs_low' & pscore <= `cs_high'

    di "Observations after trim:  " _N
    di "Dropped: " (4303 - _N)

    * PSM на trimmed sample
    di ""
    di "--- PSM на trimmed sample (common support) ---"
    teffects psmatch         ///
        (calories)           ///
        (snapnowhh           ///
            income rural region hhsize ///
            foodsufficient liqassets caraccess ///
            primstoredist_d healthycost healthytime), ///
        atet

    * Overlap после trim
    twoway                                                      ///
        (kdensity pscore if snapnowhh == 1, lwidth(medthick))   ///
        (kdensity pscore if snapnowhh == 0, lpattern(dash)),    ///
        legend(label(1 "SNAP") label(2 "Non-SNAP"))             ///
        title("Propensity Score Overlap — After Trimming")      ///
        xtitle("Propensity score") ytitle("Density")

    graph export "output\figures\fig4_pscore_trimmed.png", ///
        replace width(1200)
    di ">> Saved: output\figures\fig4_pscore_trimmed.png"

restore   // возвращаемся к полному датасету

* ── СТРАТЕГИЯ B: Caliper Matching ─────────────────────────*
*
* Caliper = 0.2 × SD(pscore) — стандартное правило Rosenbaum & Rubin

summ pscore
local caliper = 0.2 * r(sd)
di ""
di "Caliper = " `caliper'
di "--- PSM с caliper ---"

teffects psmatch             ///
    (calories)               ///
    (snapnowhh               ///
        income rural region hhsize ///
        foodsufficient liqassets caraccess ///
        primstoredist_d healthycost healthytime), ///
    atet caliper(`caliper')

tebalance summarize   // проверяем баланс после caliper

* ── СТРАТЕГИЯ C: PSM без проблемных переменных ────────────*
*
* healthytime и healthycost давали variance ratio > 3000 —
* исключаем их из pscore модели как robustness check

di ""
di "--- PSM без healthytime и healthycost (robustness) ---"

teffects psmatch             ///
    (calories)               ///
    (snapnowhh               ///
        income rural region hhsize ///
        foodsufficient liqassets caraccess), ///
    atet

tebalance summarize

* ── СРАВНИТЕЛЬНАЯ ТАБЛИЦА: все варианты PSM ───────────────*

eststo clear

* Базовый PSM (из секции 15)
eststo psm_base: teffects psmatch ///
    (calories)                    ///
    (snapnowhh income rural region hhsize ///
     foodsufficient liqassets caraccess   ///
     primstoredist_d healthycost healthytime), ///
    atet

* PSM с caliper
eststo psm_caliper: teffects psmatch ///
    (calories)                       ///
    (snapnowhh income rural region hhsize ///
     foodsufficient liqassets caraccess   ///
     primstoredist_d healthycost healthytime), ///
    atet caliper(`caliper')

* PSM без проблемных переменных
eststo psm_clean: teffects psmatch ///
    (calories)                     ///
    (snapnowhh income rural region hhsize ///
     foodsufficient liqassets caraccess), ///
    atet

esttab psm_base psm_caliper psm_clean, ///
    se star(* 0.10 ** 0.05 *** 0.01)   ///
    title("PSM Robustness: Common Support Improvements") ///
    mtitle("Base PSM" "With Caliper" "Clean Covariates")

esttab psm_base psm_caliper psm_clean ///
    using "output\tables\table2_psm_robustness.rtf", ///
    replace se star(* 0.10 ** 0.05 *** 0.01)         ///
    title("PSM Robustness: Common Support Improvements") ///
    mtitle("Base PSM" "With Caliper" "Clean Covariates")

di ">> Saved: output\tables\table2_psm_robustness.rtf"

* ── COEFFICIENT PLOT: все варианты PSM ────────────────────*

coefplot                                                           ///
    (psm_base,    keep(ATET:r1vs0.snapnowhh) label(Base PSM))     ///
    (psm_caliper, keep(ATET:r1vs0.snapnowhh) label(Caliper PSM))  ///
    (psm_clean,   keep(ATET:r1vs0.snapnowhh) label(Clean PSM)),   ///
    vertical xlabel(, noticks) xtitle("")                          ///
    yline(0, lpattern(dash))                                       ///
    title("PSM Estimates: Robustness to Common Support")           ///
    ylabel(, grid) legend(position(6))

graph export "output\figures\fig5_psm_robustness.png", ///
    replace width(1200)
di ">> Saved: output\figures\fig5_psm_robustness.png"

*--------------------------------------------------------------*
* 17. Inverse Probability Weighting (IPW)
*--------------------------------------------------------------*

* --- Raw outcomes ---
teffects ipw            ///
    (calories)          ///
    (snapnowhh          ///
        income rural region ///
        hhsize foodsufficient ///
        liqassets caraccess), ///
    atet

teffects ipw            ///
    (calories_pc)       ///
    (snapnowhh          ///
        income rural region ///
        hhsize foodsufficient ///
        liqassets caraccess), ///
    atet

* --- Winsorised outcomes ---
di "--- IPW on winsorised calories ---"
teffects ipw            ///
    (calories_w)        ///
    (snapnowhh          ///
        income rural region ///
        hhsize foodsufficient ///
        liqassets caraccess), ///
    atet

di "--- IPW on winsorised calories per capita ---"
teffects ipw            ///
    (calories_pc_w)     ///
    (snapnowhh          ///
        income rural region ///
        hhsize foodsufficient ///
        liqassets caraccess), ///
    atet

*--------------------------------------------------------------*
* 17b. Doubly-Robust IPWRA
*      Combines outcome regression + IPW weighting.
*      Consistent if EITHER the outcome model OR the propensity
*      score model is correctly specified — more robust than
*      either alone.
*--------------------------------------------------------------*

di ""
di "============================================================"
di "  DOUBLY-ROBUST IPWRA"
di "============================================================"

* Main outcome: calories per capita (winsorised) — primary result
di "--- IPWRA: calories_pc_w (PRIMARY OUTCOME) ---"
teffects ipwra                                     ///
    (calories_pc_w                                 ///
        income rural i.region hhsize               ///
        foodsufficient liqassets caraccess)        ///
    (snapnowhh                                     ///
        income rural i.region hhsize               ///
        foodsufficient liqassets caraccess),       ///
    atet

* Secondary outcome: total calories (winsorised)
di "--- IPWRA: calories_w (secondary) ---"
teffects ipwra                                     ///
    (calories_w                                    ///
        income rural i.region hhsize               ///
        foodsufficient liqassets caraccess)        ///
    (snapnowhh                                     ///
        income rural i.region hhsize               ///
        foodsufficient liqassets caraccess),       ///
    atet

* Sugar (winsorised)
di "--- IPWRA: sugar_w ---"
teffects ipwra                                     ///
    (sugar_w                                       ///
        income rural i.region hhsize               ///
        foodsufficient liqassets caraccess)        ///
    (snapnowhh                                     ///
        income rural i.region hhsize               ///
        foodsufficient liqassets caraccess),       ///
    atet

* Sodium (winsorised)
di "--- IPWRA: sodium_w ---"
teffects ipwra                                     ///
    (sodium_w                                      ///
        income rural i.region hhsize               ///
        foodsufficient liqassets caraccess)        ///
    (snapnowhh                                     ///
        income rural i.region hhsize               ///
        foodsufficient liqassets caraccess),       ///
    atet

*--------------------------------------------------------------*
* 18. MAIN COMPARISON TABLE
*     Primary outcome: calories_pc_w (per capita, winsorised)
*     Secondary: calories_w (total, winsorised)
*--------------------------------------------------------------*

eststo clear

* --- PRIMARY outcome: calories per capita (winsorised) ---

eststo ols_pc: reg calories_pc_w               ///
    snapnowhh income rural i.region            ///
    hhsize foodsufficient liqassets caraccess  ///
    primstoredist_d healthycost healthytime, robust

eststo nn_pc: teffects nnmatch                 ///
    (calories_pc_w                             ///
        income rural region hhsize             ///
        foodsufficient liqassets caraccess)    ///
    (snapnowhh), atet

eststo psm_pc: teffects psmatch                ///
    (calories_pc_w)                            ///
    (snapnowhh income rural region hhsize      ///
     foodsufficient liqassets caraccess), atet

eststo ipw_pc: teffects ipw                    ///
    (calories_pc_w)                            ///
    (snapnowhh income rural region hhsize      ///
     foodsufficient liqassets caraccess), atet

eststo ipwra_pc: teffects ipwra                ///
    (calories_pc_w                             ///
        income rural i.region hhsize           ///
        foodsufficient liqassets caraccess)    ///
    (snapnowhh income rural i.region hhsize    ///
     foodsufficient liqassets caraccess), atet

di "=== PRIMARY TABLE: Calories per capita (winsorised) ==="
esttab ols_pc nn_pc psm_pc ipw_pc ipwra_pc,   ///
    se star(* 0.10 ** 0.05 *** 0.01)           ///
    label                                      ///
    title("Effect of SNAP on Calories Per Capita (Winsorised)") ///
    mtitle("OLS" "NN" "PSM" "IPW" "IPWRA")

esttab ols_pc nn_pc psm_pc ipw_pc ipwra_pc    ///
    using "output\tables\table_primary.rtf",  ///
    replace se star(* 0.10 ** 0.05 *** 0.01)  ///
    label                                     ///
    title("Effect of SNAP on Calories Per Capita (Winsorised)") ///
    mtitle("OLS" "NN" "PSM" "IPW" "IPWRA")

di ">> Saved: output\tables\table_primary.rtf"

*--------------------------------------------------------------*
* 18. Coefficient plot — PRIMARY outcome (all 5 estimators)
*     Must come BEFORE eststo clear for secondary outcome
*--------------------------------------------------------------*

coefplot                                                         ///
    (ols_pc,   keep(snapnowhh)            label(OLS))            ///
    (nn_pc,    keep(ATET:r1vs0.snapnowhh) label(NN))             ///
    (psm_pc,   keep(ATET:r1vs0.snapnowhh) label(PSM))            ///
    (ipw_pc,   keep(ATET:r1vs0.snapnowhh) label(IPW))            ///
    (ipwra_pc, keep(ATET:r1vs0.snapnowhh) label(IPWRA)),         ///
    vertical                                                     ///
    xlabel(none)                                                 ///
    xtitle("Estimator")                                          ///
    ytitle("ATT (kcal per capita)")                              ///
    yline(0, lcolor(red) lpattern(dash))                         ///
    title("Effect of SNAP on Calories Per Capita"                ///
          "(Winsorised, All Estimators)")                        ///
    ylabel(, grid) legend(position(6))                           ///
    note("Outcome: winsorised calories per capita."              ///
         "Bars = 95% CI. IPWRA = doubly-robust estimator.")

graph export "output\figures\fig3_coefplot.png", replace width(1400)
di ">> Saved: output\figures\fig3_coefplot.png"

* --- SECONDARY outcome: total calories (winsorised) ---

eststo clear

eststo ols_tot: reg calories_w                 ///
    snapnowhh income rural i.region            ///
    hhsize foodsufficient liqassets caraccess  ///
    primstoredist_d healthycost healthytime, robust

eststo nn_tot: teffects nnmatch                ///
    (calories_w                                ///
        income rural region hhsize             ///
        foodsufficient liqassets caraccess)    ///
    (snapnowhh), atet

eststo psm_tot: teffects psmatch               ///
    (calories_w)                               ///
    (snapnowhh income rural region hhsize      ///
     foodsufficient liqassets caraccess), atet

eststo ipw_tot: teffects ipw                   ///
    (calories_w)                               ///
    (snapnowhh income rural region hhsize      ///
     foodsufficient liqassets caraccess), atet

eststo ipwra_tot: teffects ipwra               ///
    (calories_w                                ///
        income rural i.region hhsize           ///
        foodsufficient liqassets caraccess)    ///
    (snapnowhh income rural i.region hhsize    ///
     foodsufficient liqassets caraccess), atet

di "=== SECONDARY TABLE: Total calories (winsorised) ==="
esttab ols_tot nn_tot psm_tot ipw_tot ipwra_tot, ///
    se star(* 0.10 ** 0.05 *** 0.01)              ///
    label                                         ///
    title("Effect of SNAP on Total Calories (Winsorised)") ///
    mtitle("OLS" "NN" "PSM" "IPW" "IPWRA")

esttab ols_tot nn_tot psm_tot ipw_tot ipwra_tot  ///
    using "output\tables\table_secondary.rtf",   ///
    replace se star(* 0.10 ** 0.05 *** 0.01)     ///
    label                                        ///
    title("Effect of SNAP on Total Calories (Winsorised)") ///
    mtitle("OLS" "NN" "PSM" "IPW" "IPWRA")

di ">> Saved: output\tables\table_secondary.rtf"

*--------------------------------------------------------------*
* 19. Close log
*--------------------------------------------------------------*

di "========================================================"
di "  Log closed: $S_DATE $S_TIME"
di "========================================================"

log close
