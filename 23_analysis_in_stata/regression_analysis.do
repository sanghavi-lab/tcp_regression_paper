*------------------------------------------------------------------------------*
* Project: Trauma Center Project (Regression Paper with Pre-Hospital)
* Author: Jessy Nguyen
* Last Updated: February 8, 2023
* Description: Regression analysis. Creates exhibits 1 and 4.
*------------------------------------------------------------------------------*

quietly{ /* Suppress outputs */

/*Overview: We examined the interaction effects of hospital type (level 1 trauma center vs non-trauma center) and ambulance
type (ALS vs BLS) on 30-day mortality.*/

* Place in terminal to run script
* do /mnt/labshares/sanghavi-lab/Jessy/hpc_utils/codes/python/trauma_center_project/final_regression_analysis_paper_two/23_analysis_in_stata/regression_analysis.do

* Set working directory
cd "/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/merged_ats_claims_for_stata/"

*___ Read in analytical final claims data ___*
* Notes: Data contains variables for choice, no choice, total population (county level), and traffic proximity (census block level)
* Choice is defined as individuals going to a hospital where nearby hospitals are different hospital types and exist in our analytical sample. Additionally, we only focused on lvl 1 with nearby non-traumas centers and vice versa (e.g. did not consider level 2's for this paper).
* No choice is defined as a hospital with no other hospital nearby.

* Read in Data for matched claims (i.e. trauma center data)
use final_matched_claims_w_tot_pop.dta, clear

* Append unmatched claims (i.e. nontrauma center data)
append using final_unmatched_claims_w_tot_pop

*___ Clean data ___*

* Create trauma level variable using state_des first.
gen TRAUMA_LEVEL = 6 /* Any in TRAUMA_LVL that did not get replaced will be assigned a 6 */
replace TRAUMA_LEVEL=1 if State_Des == "1"
replace TRAUMA_LEVEL=2 if State_Des == "2"
replace TRAUMA_LEVEL=3 if State_Des == "3"
replace TRAUMA_LEVEL=4 if State_Des == "4"
replace TRAUMA_LEVEL=4 if State_Des == "5" /* designate level 5 in the same category as level 4 */

* Prioritize ACS_Ver categorization over State_Des. (Same with Ellen's inventory paper)
replace TRAUMA_LEVEL=1 if ACS_Ver == "1"
replace TRAUMA_LEVEL=2 if ACS_Ver == "2"
replace TRAUMA_LEVEL=3 if ACS_Ver == "3"
replace TRAUMA_LEVEL=4 if ACS_Ver == "4"
replace TRAUMA_LEVEL=4 if ACS_Ver == "5" /* designate level 5 in the same category as level 4 */

* Appendix (Trauma level 1 and non-trauma centers receiving an ambulance ride traveling more than 30 miles)
* noisily table TRAUMA_LEVEL if MILES > 30 & amb==1 & less_than_90_bene_served==0, stat(freq) /* among large hospitals, what is the count of those who traveled above 30 miles*/

* Keep on parts A and B (i.e. FFS)
keep if parts_ab_ind==1

* Remove observations with NISS >=76 or 0
drop if niss>75 | niss < 1

* Drop those matched with ATS but has a "-" (i.e. unclear of trauma center level)
drop if (State_Des=="-" & ACS_Ver=="-")

* Remove observations if missing/unknown
drop if RTI_RACE_CD=="0"
drop if SEX_IDENT_CD=="0"

* Remove if admitted with trauma code but not primarily for trauma
drop if sec_secondary_trauma_ind==1

* Remove those under 65
drop if AGE < 65

* Keep ambulance claims
keep if amb_ind==1

* Drop small hospitals and ambulance claims that traveled more than 30 miles
drop if less_than_90_bene_served == 1 /* Drop small hospitals */
drop if MILES > 30 /* Drop those traveling long miles */

* Creating Bands for niss. May not be used in model but create just in case
gen niss_bands = .
replace niss_bands = 1 if niss<=15
replace niss_bands = 2 if niss>15 & niss<=24
replace niss_bands = 3 if niss>24 & niss<=40
replace niss_bands = 4 if niss>40 & niss<=49
replace niss_bands = 5 if niss>49

* Label the niss categorical variables
label define niss_label 1 "1-15" 2 "16-24" 3 "25-40" 4 "41-49" 5 "50+"
label values niss_bands niss_label

* Gen indicators for niss categories
gen n16_24 = 0
replace n16_24 = 1 if niss_bands == 2
gen n25_40 = 0
replace n25_40 = 1 if niss_bands == 3
gen n41 = 0
replace n41 = 1 if (niss_bands == 4) | (niss_bands == 5)

* Gen indicators for comorbidity  categories
gen cs1 = 0
replace cs1 = 1 if (comorbidityscore<1)
gen cs1_3 = 0
replace cs1_3 = 1 if ((comorbid>=1)&(comorbid<4))
gen cs4 = 0
replace cs4 = 1 if ((comorbid>=4))

* Gen indicators for num chronic condition categories
gen cc1_6 = 0
replace cc1_6 = 1 if (cc_otcc_count<7)
gen cc7 = 0
replace cc7 = 1 if (cc_otcc_count>=7)

* Destring and rename variables needed in the model
destring RTI_RACE_CD, generate(RACE)
destring SEX_IDENT_CD, generate(SEX)
destring STATE_COUNTY_SSA, generate(COUNTY) /* maybe I don't need since I want state level FE but create just in case */
destring STATE_CODE, generate(STATE)

* Label the variables that were de-stringed
label define RACE_label 1 "White" 2 "Black" 3 "Other" 4 "Asian/PI" 5 "Hispanic" 6 "Native Americans/Alaskan Native"
label values RACE RACE_label
label define SEX_label 1 "M" 2 "F"
label values SEX SEX_label
label define TRAUMA_LEVEL_label 1 "LVL 1" 2 "LVL 2" 3 "LVL 3" 4 "LVL 4/5" 6 "Non-trauma"
label values TRAUMA_LEVEL TRAUMA_LEVEL_label

* Rename for shorter name labels because -local- function only takes 32 characters max. -local- will be used later when creating macro's to save in an excel table
ren BLOOD_PT_FRNSH_QTY BLOODPT
ren comorbidityscore comorbid
ren median_hh_inc m_hh_inc
ren prop_below_pvrty_in_cnty pvrty
ren prop_female_in_cnty fem_cty
ren prop_65plus_in_cnty eld_cty
ren prop_w_cllge_edu_in_cnty cllge
ren prop_gen_md_in_cnty gen_md
ren prop_hos_w_med_school_in_cnty med_cty
ren cc_otcc_count cc_cnt

* Create variable for ambulance service type
gen amb_type = .
replace amb_type = 1 if HCPCS_CD == "A0429"
replace amb_type = 2 if inlist(HCPCS_CD, "A0427", "A0433")

* Label the ambulance type columns
label define amb_type_label 1 "BLS" 2 "ALS"
label values amb_type amb_type_label

*--- Create binary indicators ---*

* Create indicator variables for each race
tabulate RACE, generate(r)

* Rename columns to appropriate name. I tripled checked that r1 is white, r2 is black, ... , r6 is native american
ren r1 white, replace
ren r2 black, replace
ren r3 other, replace
ren r4 asian_pi, replace
ren r5 hispanic, replace
ren r6 native_am, replace

* Generate a new "other" race column that is designated as 1 if native american/alaskan native or other is 1. Goal is to combine native american with other since it's a small group
gen other_n = 0
replace other_n = 1 if other == 1 | native_am == 1

* Create indicator variable for metro, micro, or none
tabulate metro_micro_cnty, generate(m)

* Rename columns to appropriate name. I tripled check that m1 is not_metro_micro, etc...
ren m1 not_metro_micro, replace
ren m2 metro, replace
ren m3 micro, replace

* Create indicator for female
gen female = 1
replace female = 0  if SEX == 1
replace female = 1 if SEX == 2 /* only to double check */

* Create treatment indicators for each Trauma level (level 1, level 2, level 3, level 4/5, nontrauma)
tabulate TRAUMA_LEVEL, generate(t) /* This will create the following dummy variables: t1 = level 1, t2 = level 2, t3 = level 3, t4 = level 4/5, t5 = nontrauma */

* Create binary for mile
gen mile_binary_4 = 0
replace mile_binary_4 = 1 if MILES>4
label define mile_binary_4_label 0 "less_mi" 1 "more_mi"
label values mile_binary_4 mile_binary_4_label

* Keep only trauma level 1 and nontrauma centers
keep if (TRAUMA_LEVEL == 1 | TRAUMA_LEVEL == 6)
ren t1 treatment

/*
* For manuscript
noisily sum fall_ind /*82.6%*/
noisily sum motor_accident_ind /*5.9%*/
* others /*11.5%*/
*/


* for appendix
noisily table choice_ind_mi9, stat(freq) /*see no choice */


* Keep only hospitals within 9 miles of each other
keep if choice_ind_mi9 == 1

*--------------- Create macros for characteristic table (Unadjusted; exhibit 1) ---------------*

* Create list named covariates. Indicators were created above
local covariates niss riss AGE comorbid female white black other_n asian_pi hispanic BLOODPT m_hh_inc pvrty fem_cty eld_cty metro cllge gen_md med_cty cc_cnt n16_24 n25_40 n41 cs1 cs1_3 cs4 cc1_6 cc7 MILES

* Create list of hospital type (1 is level 1 and 6 is nontrauma)
local hos_type 1 6

* Create list of amb type (1 is BLS and 2 is ALS)
local amb_type 1 2

* Preserve original data
preserve

* Loop through each covariate to check mean and if there is statistically significant differences between the two groups (lvl1 and lvl2)
foreach a of local amb_type{

    foreach h of local hos_type{

        foreach c of local covariates{

            * Check summary
            sum `c' if TRAUMA_LEVEL==`h' & amb_type==`a'
            return list

            * Save sample size to macro
            local `h'`a' = string(`r(N)')

            * Save the means of the treatment and control groups in macros
            if inlist("`c'","female","white", "black", "other_n", "asian_pi", "hispanic")|inlist("`c'","pvrty", "fem_cty", "eld_cty", "metro", "cllge", "gen_md", "med_cty")|inlist("`c'","n16_24", "n25_40", "n41", "cs1", "cs1_3", "cs4", "cc1_6")|inlist("`c'","cc7"){
                *local `c'_p = string(`r(p)',"%3.2f")
                local `h'`a'`c' = string(`r(mean)'*100,"%9.1f")
            }
            else{ /* While the above requires conversion to percents, other variables like niss or AGE do not */
                *local `c'_p = string(`r(p)',"%3.2f")
                local `h'`a'`c' = string(`r(mean)',"%9.1f")
            }

        }
    }
}

* Retore original data
restore

************* REGRESSIONS ***************************************************************************

* To use 30 day death, need to drop last 30 days (Dec 2019)
drop if SRVC_BGN_DT >= mdyhms(12, 01, 2019, 0, 0, 0)

* Create macro for list of models
local model_spec l1 als mi hos_amb hosXamb hos_mi hosXmi amb_mi ambXmi hos_amb_mi hosXamb_mi hosXmi_amb ambXmi_hos hosXambXmi

* Create variable for the log of median household income to account for right skewness
gen median_hh_inc_ln = ln(m_hh_inc)

foreach a of local model_spec{

    noisily di "`a'"

    * Save original data as og
    tempfile og
    save `og'

    * Create splines for niss and riss to allow for flexibility based on bands from past literature
    mkspline niss`a'1 24 niss`a'2 40 niss`a'3 49 niss`a'4=niss
    mkspline riss`a'1 24 riss`a'2 40 riss`a'3 49 riss`a'4=riss

    * Create global macro for controls. Put within loop because of different spline names.
    global controls niss`a'1-niss`a'4 riss`a'1-riss`a'4 ib2.RACE ib1.SEX c.AGE##c.AGE c.comorbid##c.comorbid c.BLOODPT ///
                    c.mxaisbr_HeadNeck c.mxaisbr_Extremities c.mxaisbr_Chest c.mxaisbr_Abdomen c.maxais i.STATE i.year_fe AMI_EVER_ind ///
                    ALZH_EVER_ind ALZH_DEMEN_EVER_ind ATRIAL_FIB_EVER_ind CATARACT_EVER_ind CHRONICKIDNEY_EVER_ind COPD_EVER_ind CHF_EVER_ind ///
                    DIABETES_EVER_ind GLAUCOMA_EVER_ind ISCHEMICHEART_EVER_ind DEPRESSION_EVER_ind OSTEOPOROSIS_EVER_ind ///
                    RA_OA_EVER_ind STROKE_TIA_EVER_ind CANCER_BREAST_EVER_ind CANCER_COLORECTAL_EVER_ind CANCER_PROSTATE_EVER_ind CANCER_LUNG_EVER_ind ///
                    CANCER_ENDOMETRIAL_EVER_ind ANEMIA_EVER_ind ASTHMA_EVER_ind HYPERL_EVER_ind HYPERP_EVER_ind HYPERT_EVER_ind HYPOTH_EVER_ind ///
                    MULSCL_MEDICARE_EVER_ind OBESITY_MEDICARE_EVER_ind EPILEP_MEDICARE_EVER_ind median_hh_inc_ln pvrty fem_cty eld_cty ///
                    ib0.metro_micro_cnty cllge gen_md med_cty full_dual_ind SH_ind EH_ind NH_ind RH_ind

    if inlist("`a'", "l1"){

        * Specify model (ib1.amb_type i.mile_binary_4 i.treatment)
        reg thirty_day_death_ind i.treatment $controls

        * Put results into matrix table to access
        matrix list r(table) /* View regression result from thirty day death as a table */
        matrix reg_table = r(table) /* Put matrix in table labeled reg_table */

        * Save outputs as macro
        local `a'_c = string(_b[1.treatment]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_p = reg_table[4,2] /* Put pvalue in macro from matrix table */

    }

    else if inlist("`a'", "als"){

        * Specify model (ib1.amb_type i.mile_binary_4 i.treatment)
        reg thirty_day_death_ind ib1.amb_type $controls

        * Put results into matrix table to access
        matrix list r(table) /* View regression result from thirty day death as a table */
        matrix reg_table = r(table) /* Put matrix in table labeled reg_table */

        * Save outputs as macro
        local `a'_c = string(_b[2.amb_type]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_p = reg_table[4,2] /* Put pvalue in macro from matrix table */

    }

    else if inlist("`a'", "mi"){

        * Specify model (ib1.amb_type i.mile_binary_4 i.treatment)
        reg thirty_day_death_ind i.mile_binary_4 $controls

        * Put results into matrix table to access
        matrix list r(table) /* View regression result from thirty day death as a table */
        matrix reg_table = r(table) /* Put matrix in table labeled reg_table */

        * Save outputs as macro
        local `a'_c = string(_b[1.mile_binary_4]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_p = reg_table[4,2] /* Put pvalue in macro from matrix table */

    }

    else if inlist("`a'", "hos_amb"){

        * Specify model (ib1.amb_type i.mile_binary_4 i.treatment)
        reg thirty_day_death_ind i.treatment ib1.amb_type $controls

        * Put results into matrix table to access
        matrix list r(table) /* View regression result from thirty day death as a table */
        matrix reg_table = r(table) /* Put matrix in table labeled reg_table */

        * Save outputs as macro
        local `a'_hos_c = string(_b[1.treatment]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_amb_c = string(_b[2.amb_type]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_hos_p = reg_table[4,2] /* Put pvalue in macro from matrix table */
        local `a'_amb_p = reg_table[4,4] /* Put pvalue in macro from matrix table */

    }

    else if inlist("`a'", "hosXamb"){

        * Specify model (ib1.amb_type i.mile_binary_4 i.treatment)
        reg thirty_day_death_ind i.treatment##ib1.amb_type $controls

        * Put results into matrix table to access
        matrix list r(table) /* View regression result from thirty day death as a table */
        matrix reg_table = r(table) /* Put matrix in table labeled reg_table */

        * Save outputs as macro
        local `a'_hos_c = string(_b[1.treatment]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_amb_c = string(_b[2.amb_type]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_hosXamb_c = string(_b[1.treatment#2.amb_type]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_hos_p = reg_table[4,2] /* Put pvalue in macro from matrix table */
        local `a'_amb_p = reg_table[4,4] /* Put pvalue in macro from matrix table */
        local `a'_hosXamb_p = reg_table[4,8] /* Put pvalue in macro from matrix table */

    }

    else if inlist("`a'", "hos_mi"){

        * Specify model (ib1.amb_type i.mile_binary_4 i.treatment)
        reg thirty_day_death_ind i.treatment i.mile_binary_4 $controls

        * Put results into matrix table to access
        matrix list r(table) /* View regression result from thirty day death as a table */
        matrix reg_table = r(table) /* Put matrix in table labeled reg_table */

        * Save outputs as macro
        local `a'_hos_c = string(_b[1.treatment]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_mi_c = string(_b[1.mile_binary_4]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_hos_p = reg_table[4,2] /* Put pvalue in macro from matrix table */
        local `a'_mi_p = reg_table[4,4] /* Put pvalue in macro from matrix table */

    }

    else if inlist("`a'", "hosXmi"){

        * Specify model (ib1.amb_type i.mile_binary_4 i.treatment)
        reg thirty_day_death_ind i.treatment##i.mile_binary_4 $controls

        * Put results into matrix table to access
        matrix list r(table) /* View regression result from thirty day death as a table */
        matrix reg_table = r(table) /* Put matrix in table labeled reg_table */

        * Save outputs as macro
        local `a'_hos_c = string(_b[1.treatment]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_mi_c = string(_b[1.mile_binary_4]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_hosXmi_c = string(_b[1.treatment#1.mile_binary_4]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_hos_p = reg_table[4,2] /* Put pvalue in macro from matrix table */
        local `a'_mi_p = reg_table[4,4] /* Put pvalue in macro from matrix table */
        local `a'_hosXmi_p = reg_table[4,8] /* Put pvalue in macro from matrix table */

    }

    else if inlist("`a'", "amb_mi"){

        * Specify model (ib1.amb_type i.mile_binary_4 i.treatment)
        reg thirty_day_death_ind ib1.amb_type i.mile_binary_4 $controls

        * Put results into matrix table to access
        matrix list r(table) /* View regression result from thirty day death as a table */
        matrix reg_table = r(table) /* Put matrix in table labeled reg_table */

        * Save outputs as macro
        local `a'_amb_c = string(_b[2.amb_type]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_mi_c = string(_b[1.mile_binary_4]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_amb_p = reg_table[4,2] /* Put pvalue in macro from matrix table */
        local `a'_mi_p = reg_table[4,4] /* Put pvalue in macro from matrix table */

    }

    else if inlist("`a'", "ambXmi"){

        * Specify model (ib1.amb_type i.mile_binary_4 i.treatment)
        reg thirty_day_death_ind ib1.amb_type##i.mile_binary_4 $controls

        * Put results into matrix table to access
        matrix list r(table) /* View regression result from thirty day death as a table */
        matrix reg_table = r(table) /* Put matrix in table labeled reg_table */

        * Save outputs as macro
        local `a'_amb_c = string(_b[2.amb_type]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_mi_c = string(_b[1.mile_binary_4]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_ambXmi_c = string(_b[2.amb_type#1.mile_binary_4]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_amb_p = reg_table[4,2] /* Put pvalue in macro from matrix table */
        local `a'_mi_p = reg_table[4,4] /* Put pvalue in macro from matrix table */
        local `a'_ambXmi_p = reg_table[4,8] /* Put pvalue in macro from matrix table */

    }

    else if inlist("`a'", "hos_amb_mi"){

        * Specify model (ib1.amb_type i.mile_binary_4 i.treatment)
        reg thirty_day_death_ind i.treatment ib1.amb_type i.mile_binary_4 $controls

        * Put results into matrix table to access
        matrix list r(table) /* View regression result from thirty day death as a table */
        matrix reg_table = r(table) /* Put matrix in table labeled reg_table */

        * Save outputs as macro
        local `a'_hos_c = string(_b[1.treatment]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_amb_c = string(_b[2.amb_type]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_mi_c = string(_b[1.mile_binary_4]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_hos_p = reg_table[4,2] /* Put pvalue in macro from matrix table */
        local `a'_amb_p = reg_table[4,4] /* Put pvalue in macro from matrix table */
        local `a'_mi_p = reg_table[4,6] /* Put pvalue in macro from matrix table */

    }

    else if inlist("`a'", "hosXamb_mi"){

        * Specify model (ib1.amb_type i.mile_binary_4 i.treatment)
        reg thirty_day_death_ind i.treatment##ib1.amb_type i.mile_binary_4 $controls

        * Put results into matrix table to access
        matrix list r(table) /* View regression result from thirty day death as a table */
        matrix reg_table = r(table) /* Put matrix in table labeled reg_table */

        * Save outputs as macro
        local `a'_hos_c = string(_b[1.treatment]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_amb_c = string(_b[2.amb_type]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_hosXamb_c = string(_b[1.treatment#2.amb_type]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_mi_c = string(_b[1.mile_binary_4]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_hos_p = reg_table[4,2] /* Put pvalue in macro from matrix table */
        local `a'_amb_p = reg_table[4,4] /* Put pvalue in macro from matrix table */
        local `a'_hosXamb_p = reg_table[4,8] /* Put pvalue in macro from matrix table */
        local `a'_mi_p = reg_table[4,10] /* Put pvalue in macro from matrix table */

    }

    else if inlist("`a'", "hosXmi_amb"){

        * Specify model (ib1.amb_type i.mile_binary_4 i.treatment)
        reg thirty_day_death_ind i.treatment##i.mile_binary_4 ib1.amb_type $controls

        * Put results into matrix table to access
        matrix list r(table) /* View regression result from thirty day death as a table */
        matrix reg_table = r(table) /* Put matrix in table labeled reg_table */

        * Save outputs as macro
        local `a'_hos_c = string(_b[1.treatment]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_mi_c = string(_b[1.mile_binary_4]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_hosXmi_c = string(_b[1.treatment#1.mile_binary_4]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_amb_c = string(_b[2.amb_type]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_hos_p = reg_table[4,2] /* Put pvalue in macro from matrix table */
        local `a'_mi_p = reg_table[4,4] /* Put pvalue in macro from matrix table */
        local `a'_hosXmi_p = reg_table[4,8] /* Put pvalue in macro from matrix table */
        local `a'_amb_p = reg_table[4,10] /* Put pvalue in macro from matrix table */

    }

    else if inlist("`a'", "ambXmi_hos"){

        * Specify model (ib1.amb_type i.mile_binary_4 i.treatment)
        reg thirty_day_death_ind ib1.amb_type##i.mile_binary_4 i.treatment $controls

        * Put results into matrix table to access
        matrix list r(table) /* View regression result from thirty day death as a table */
        matrix reg_table = r(table) /* Put matrix in table labeled reg_table */

        * Save outputs as macro
        local `a'_amb_c = string(_b[2.amb_type]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_mi_c = string(_b[1.mile_binary_4]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_ambXmi_c = string(_b[2.amb_type#1.mile_binary_4]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_hos_c = string(_b[1.treatment]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_amb_p = reg_table[4,2] /* Put pvalue in macro from matrix table */
        local `a'_mi_p = reg_table[4,4] /* Put pvalue in macro from matrix table */
        local `a'_ambXmi_p = reg_table[4,8] /* Put pvalue in macro from matrix table */
        local `a'_hos_p = reg_table[4,10] /* Put pvalue in macro from matrix table */

    }

    else if inlist("`a'", "hosXambXmi"){

        * Specify model (ib1.amb_type i.mile_binary_4 i.treatment)
        reg thirty_day_death_ind i.treatment##ib1.amb_type##i.mile_binary_4 $controls

        * Put results into matrix table to access
        matrix list r(table) /* View regression result from thirty day death as a table */
        matrix reg_table = r(table) /* Put matrix in table labeled reg_table */

        * Save outputs as macro
        local `a'_hos_c = string(_b[1.treatment]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_amb_c = string(_b[2.amb_type]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_mi_c = string(_b[1.mile_binary_4]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_hosXamb_c = string(_b[1.treatment#2.amb_type]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_hosXmi_c = string(_b[1.treatment#1.mile_binary_4]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_ambXmi_c = string(_b[2.amb_type#1.mile_binary_4]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_hosXambXmi_c = string(_b[1.treatment#2.amb_type#1.mile_binary_4]*100,"%9.2f") /* Put coefficient in macro as percentage point */
        local `a'_hos_p = reg_table[4,2] /* Put pvalue in macro from matrix table */
        local `a'_amb_p = reg_table[4,4] /* Put pvalue in macro from matrix table */
        local `a'_hosXamb_p = reg_table[4,8] /* Put pvalue in macro from matrix table */
        local `a'_mi_p = reg_table[4,10] /* Put pvalue in macro from matrix table */
        local `a'_hosXmi_p = reg_table[4,14] /* Put pvalue in macro from matrix table */
        local `a'_ambXmi_p = reg_table[4,18] /* Put pvalue in macro from matrix table */
        local `a'_hosXambXmi_p = reg_table[4,26] /* Put pvalue in macro from matrix table */

    }

    * Restore original data
    use `og',clear

}





























*---------- CREATE BALANCE TABLE FOR EXCEL (BEFORE AND AFTER WEIGHTING) ------------*

* Set file name for excel sheet with modify option to create new table to store the balance tables
putexcel set "tab_char_no_labels.xlsx", sheet("bal_tab") replace

local per_bls_in_nt = string((`61'/(`61'+`62'))*100,"%9.0f")
local per_als_in_nt = string((`62'/(`61'+`62'))*100,"%9.0f")
local per_bls_in_t1 = string((`11'/(`11'+`12'))*100,"%9.0f")
local per_als_in_t1 = string((`12'/(`11'+`12'))*100,"%9.0f")

putexcel F1 = "`61' (`per_bls_in_nt'%)"
putexcel G1 = "`62' (`per_als_in_nt'%)"
putexcel H1 = "`11' (`per_bls_in_t1'%)"
putexcel I1 = "`12' (`per_als_in_t1'%)"

putexcel A1 = "`61AGE'"
putexcel B1 = "`62AGE'"
putexcel C1 = "`11AGE'"
putexcel D1 = "`12AGE'"

putexcel A2 = "`61female'"
putexcel B2 = "`62female'"
putexcel C2 = "`11female'"
putexcel D2 = "`12female'"

putexcel A4 = "`61white'"
putexcel B4 = "`62white'"
putexcel C4 = "`11white'"
putexcel D4 = "`12white'"

putexcel A5 = "`61black'"
putexcel B5 = "`62black'"
putexcel C5 = "`11black'"
putexcel D5 = "`12black'"

putexcel A6 = "`61other_n'"
putexcel B6 = "`62other_n'"
putexcel C6 = "`11other_n'"
putexcel D6 = "`12other_n'"

putexcel A7 = "`61asian_pi'"
putexcel B7 = "`62asian_pi'"
putexcel C7 = "`11asian_pi'"
putexcel D7 = "`12asian_pi'"

putexcel A8 = "`61hispanic'"
putexcel B8 = "`62hispanic'"
putexcel C8 = "`11hispanic'"
putexcel D8 = "`12hispanic'"

putexcel A9 = "`61cc_cnt'"
putexcel B9 = "`62cc_cnt'"
putexcel C9 = "`11cc_cnt'"
putexcel D9 = "`12cc_cnt'"

putexcel A11 = "`61cc1_6'"
putexcel B11 = "`62cc1_6'"
putexcel C11 = "`11cc1_6'"
putexcel D11 = "`12cc1_6'"

putexcel A12 = "`61cc7'"
putexcel B12 = "`62cc7'"
putexcel C12 = "`11cc7'"
putexcel D12 = "`12cc7'"

putexcel A13 = "`61comorbid'"
putexcel B13 = "`62comorbid'"
putexcel C13 = "`11comorbid'"
putexcel D13 = "`12comorbid'"

putexcel A15 = "`61cs1'"
putexcel B15 = "`62cs1'"
putexcel C15 = "`11cs1'"
putexcel D15 = "`12cs1'"

putexcel A16 = "`61cs1_3'"
putexcel B16 = "`62cs1_3'"
putexcel C16 = "`11cs1_3'"
putexcel D16 = "`12cs1_3'"

putexcel A17 = "`61cs4'"
putexcel B17 = "`62cs4'"
putexcel C17 = "`11cs4'"
putexcel D17 = "`12cs4'"

putexcel A18 = "`61niss'"
putexcel B18 = "`62niss'"
putexcel C18 = "`11niss'"
putexcel D18 = "`12niss'"

putexcel A20 = "`61n16_24'"
putexcel B20 = "`62n16_24'"
putexcel C20 = "`11n16_24'"
putexcel D20 = "`12n16_24'"

putexcel A21 = "`61n25_40'"
putexcel B21 = "`62n25_40'"
putexcel C21 = "`11n25_40'"
putexcel D21 = "`12n25_40'"

putexcel A22 = "`61n41'"
putexcel B22 = "`62n41'"
putexcel C22 = "`11n41'"
putexcel D22 = "`12n41'"

putexcel A23 = "`61riss'"
putexcel B23 = "`62riss'"
putexcel C23 = "`11riss'"
putexcel D23 = "`12riss'"

putexcel A24 = "`61BLOODPT'"
putexcel B24 = "`62BLOODPT'"
putexcel C24 = "`11BLOODPT'"
putexcel D24 = "`12BLOODPT'"

putexcel A25 = "`61MILES'"
putexcel B25 = "`62MILES'"
putexcel C25 = "`11MILES'"
putexcel D25 = "`12MILES'"

putexcel A26 = "`61m_hh_inc'"
putexcel B26 = "`62m_hh_inc'"
putexcel C26 = "`11m_hh_inc'"
putexcel D26 = "`12m_hh_inc'"

putexcel A28 = "`61pvrty'"
putexcel B28 = "`62pvrty'"
putexcel C28 = "`11pvrty'"
putexcel D28 = "`12pvrty'"

putexcel A29 = "`61fem_cty'"
putexcel B29 = "`62fem_cty'"
putexcel C29 = "`11fem_cty'"
putexcel D29 = "`12fem_cty'"

putexcel A30 = "`61eld_cty'"
putexcel B30 = "`62eld_cty'"
putexcel C30 = "`11eld_cty'"
putexcel D30 = "`12eld_cty'"

putexcel A31 = "`61metro'"
putexcel B31 = "`62metro'"
putexcel C31 = "`11metro'"
putexcel D31 = "`12metro'"

putexcel A32 = "`61cllge'"
putexcel B32 = "`62cllge'"
putexcel C32 = "`11cllge'"
putexcel D32 = "`12cllge'"

putexcel A33 = "`61gen_md'"
putexcel B33 = "`62gen_md'"
putexcel C33 = "`11gen_md'"
putexcel D33 = "`12gen_md'"

putexcel A34 = "`61med_cty'"
putexcel B34 = "`62med_cty'"
putexcel C34 = "`11med_cty'"
putexcel D34 = "`12med_cty'"

*---------- CREATE EXHIBIT 4 FOR EXCEL ------------*

* Set file name for excel sheet with modify option to create new table to store the balance tables
putexcel set "tab_char_no_labels.xlsx", sheet("exhibit_4") modify



*- - - Main Effect Hospital - - -*

if `l1_p' < 0.001{ /* if significant, put asterisk */
putexcel D12 = "`l1_c'***", hcenter vcenter
}
else if `l1_p' < 0.01{ /* if significant, put asterisk */
putexcel D12 = "`l1_c'**", hcenter vcenter
}
else if `l1_p' < 0.05{ /* if significant, put asterisk */
putexcel D12 = "`l1_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel D12 = "`l1_c'", hcenter vcenter
}

*- - - Main Effect Ambulance - - -*

if `als_p' < 0.001{ /* if significant, put asterisk */
putexcel F13 = "`als_c'***", hcenter vcenter
}
else if `als_p' < 0.01{ /* if significant, put asterisk */
putexcel F13 = "`als_c'**", hcenter vcenter
}
else if `als_p' < 0.05{ /* if significant, put asterisk */
putexcel F13 = "`als_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel F13 = "`als_c'", hcenter vcenter
}

*- - - Main Effect Miles - - -*

if `mi_p' < 0.001{ /* if significant, put asterisk */
putexcel H14 = "`mi_c'***", hcenter vcenter
}
else if `mi_p' < 0.01{ /* if significant, put asterisk */
putexcel H14 = "`mi_c'**", hcenter vcenter
}
else if `mi_p' < 0.05{ /* if significant, put asterisk */
putexcel H14 = "`mi_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel H14 = "`mi_c'", hcenter vcenter
}




*- - - Hospital and Ambulance - - -*

/*Hospital coeficient*/

if `hos_amb_hos_p' < 0.001{ /* if significant, put asterisk */
putexcel D16 = "`hos_amb_hos_c'***", hcenter vcenter
}
else if `hos_amb_hos_p' < 0.01{ /* if significant, put asterisk */
putexcel D16 = "`hos_amb_hos_c'**", hcenter vcenter
}
else if `hos_amb_hos_p' < 0.05{ /* if significant, put asterisk */
putexcel D16 = "`hos_amb_hos_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel D16 = "`hos_amb_hos_c'", hcenter vcenter
}

/*Ambulance coeficient*/

if `hos_amb_amb_p' < 0.001{ /* if significant, put asterisk */
putexcel F16 = "`hos_amb_amb_c'***", hcenter vcenter
}
else if `hos_amb_amb_p' < 0.01{ /* if significant, put asterisk */
putexcel F16 = "`hos_amb_amb_c'**", hcenter vcenter
}
else if `hos_amb_amb_p' < 0.05{ /* if significant, put asterisk */
putexcel F16 = "`hos_amb_amb_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel F16 = "`hos_amb_amb_c'", hcenter vcenter
}

*- - - Hospital X Ambulance - - -*

/*Hospital coeficient*/

if `hosXamb_hos_p' < 0.001{ /* if significant, put asterisk */
putexcel D17 = "`hosXamb_hos_c'***", hcenter vcenter
}
else if `hosXamb_hos_p' < 0.01{ /* if significant, put asterisk */
putexcel D17 = "`hosXamb_hos_c'**", hcenter vcenter
}
else if `hosXamb_hos_p' < 0.05{ /* if significant, put asterisk */
putexcel D17 = "`hosXamb_hos_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel D17 = "`hosXamb_hos_c'", hcenter vcenter
}

/*Ambulance coeficient*/

if `hosXamb_amb_p' < 0.001{ /* if significant, put asterisk */
putexcel F17 = "`hosXamb_amb_c'***", hcenter vcenter
}
else if `hosXamb_amb_p' < 0.01{ /* if significant, put asterisk */
putexcel F17 = "`hosXamb_amb_c'**", hcenter vcenter
}
else if `hosXamb_amb_p' < 0.05{ /* if significant, put asterisk */
putexcel F17 = "`hosXamb_amb_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel F17 = "`hosXamb_amb_c'", hcenter vcenter
}

/*Hospital X Ambulance coeficient*/

if `hosXamb_hosXamb_p' < 0.001{ /* if significant, put asterisk */
putexcel J17 = "`hosXamb_hosXamb_c'***", hcenter vcenter
}
else if `hosXamb_hosXamb_p' < 0.01{ /* if significant, put asterisk */
putexcel J17 = "`hosXamb_hosXamb_c'**", hcenter vcenter
}
else if `hosXamb_hosXamb_p' < 0.05{ /* if significant, put asterisk */
putexcel J17 = "`hosXamb_hosXamb_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel J17 = "`hosXamb_hosXamb_c'", hcenter vcenter
}




*- - - Hospital and Mileage - - -*

/*Hospital coeficient*/

if `hos_mi_hos_p' < 0.001{ /* if significant, put asterisk */
putexcel D19 = "`hos_mi_hos_c'***", hcenter vcenter
}
else if `hos_mi_hos_p' < 0.01{ /* if significant, put asterisk */
putexcel D19 = "`hos_mi_hos_c'**", hcenter vcenter
}
else if `hos_mi_hos_p' < 0.05{ /* if significant, put asterisk */
putexcel D19 = "`hos_mi_hos_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel D19 = "`hos_mi_hos_c'", hcenter vcenter
}

/*Mileage coeficient*/

if `hos_mi_mi_p' < 0.001{ /* if significant, put asterisk */
putexcel H19 = "`hos_mi_mi_c'***", hcenter vcenter
}
else if `hos_mi_mi_p' < 0.01{ /* if significant, put asterisk */
putexcel H19 = "`hos_mi_mi_c'**", hcenter vcenter
}
else if `hos_mi_mi_p' < 0.05{ /* if significant, put asterisk */
putexcel H19 = "`hos_mi_mi_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel H19 = "`hos_mi_mi_c'", hcenter vcenter
}

*- - - Hospital X Mileage - - -*

/*Hospital coeficient*/

if `hosXmi_hos_p' < 0.001{ /* if significant, put asterisk */
putexcel D20 = "`hosXmi_hos_c'***", hcenter vcenter
}
else if `hosXmi_hos_p' < 0.01{ /* if significant, put asterisk */
putexcel D20 = "`hosXmi_hos_c'**", hcenter vcenter
}
else if `hosXmi_hos_p' < 0.05{ /* if significant, put asterisk */
putexcel D20 = "`hosXmi_hos_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel D17 = "`hosXmi_hos_c'", hcenter vcenter
}

/*Mileage coeficient*/

if `hosXmi_mi_p' < 0.001{ /* if significant, put asterisk */
putexcel H20 = "`hosXmi_mi_c'***", hcenter vcenter
}
else if `hosXmi_mi_p' < 0.01{ /* if significant, put asterisk */
putexcel H20 = "`hosXmi_mi_c'**", hcenter vcenter
}
else if `hosXmi_mi_p' < 0.05{ /* if significant, put asterisk */
putexcel H20 = "`hosXmi_mi_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel H20 = "`hosXmi_mi_c'", hcenter vcenter
}

/*Hospital X Mileage coeficient*/

if `hosXmi_hosXmi_p' < 0.001{ /* if significant, put asterisk */
putexcel L20 = "`hosXmi_hosXmi_c'***", hcenter vcenter
}
else if `hosXmi_hosXmi_p' < 0.01{ /* if significant, put asterisk */
putexcel L20 = "`hosXmi_hosXmi_c'**", hcenter vcenter
}
else if `hosXmi_hosXmi_p' < 0.05{ /* if significant, put asterisk */
putexcel L20 = "`hosXmi_hosXmi_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel L20 = "`hosXmi_hosXmi_c'", hcenter vcenter
}




*- - - Ambulance and Mileage - - -*

/*Ambulance coeficient*/

if `amb_mi_amb_p' < 0.001{ /* if significant, put asterisk */
putexcel F22 = "`amb_mi_amb_c'***", hcenter vcenter
}
else if `amb_mi_amb_p' < 0.01{ /* if significant, put asterisk */
putexcel F22 = "`amb_mi_amb_c'**", hcenter vcenter
}
else if `amb_mi_amb_p' < 0.05{ /* if significant, put asterisk */
putexcel F22 = "`amb_mi_amb_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel F22 = "`amb_mi_amb_c'", hcenter vcenter
}

/*Mileage coeficient*/

if `amb_mi_mi_p' < 0.001{ /* if significant, put asterisk */
putexcel H22 = "`amb_mi_mi_c'***", hcenter vcenter
}
else if `amb_mi_mi_p' < 0.01{ /* if significant, put asterisk */
putexcel H22 = "`amb_mi_mi_c'**", hcenter vcenter
}
else if `amb_mi_mi_p' < 0.05{ /* if significant, put asterisk */
putexcel H22 = "`amb_mi_mi_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel H22 = "`amb_mi_mi_c'", hcenter vcenter
}

*- - - Ambulance X Mileage - - -*

/*Ambulance coeficient*/

if `ambXmi_amb_p' < 0.001{ /* if significant, put asterisk */
putexcel F23 = "`ambXmi_amb_c'***", hcenter vcenter
}
else if `ambXmi_amb_p' < 0.01{ /* if significant, put asterisk */
putexcel F23 = "`ambXmi_amb_c'**", hcenter vcenter
}
else if `ambXmi_amb_p' < 0.05{ /* if significant, put asterisk */
putexcel F23 = "`ambXmi_amb_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel F23 = "`ambXmi_amb_c'", hcenter vcenter
}

/*Mileage coeficient*/

if `ambXmi_mi_p' < 0.001{ /* if significant, put asterisk */
putexcel H23 = "`ambXmi_mi_c'***", hcenter vcenter
}
else if `ambXmi_mi_p' < 0.01{ /* if significant, put asterisk */
putexcel H23 = "`ambXmi_mi_c'**", hcenter vcenter
}
else if `ambXmi_mi_p' < 0.05{ /* if significant, put asterisk */
putexcel H23 = "`ambXmi_mi_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel H23 = "`ambXmi_mi_c'", hcenter vcenter
}

/*Ambulance X Mileage coeficient*/

if `ambXmi_ambXmi_p' < 0.001{ /* if significant, put asterisk */
putexcel N23 = "`ambXmi_ambXmi_c'***", hcenter vcenter
}
else if `ambXmi_ambXmi_p' < 0.01{ /* if significant, put asterisk */
putexcel N23 = "`ambXmi_ambXmi_c'**", hcenter vcenter
}
else if `ambXmi_ambXmi_p' < 0.05{ /* if significant, put asterisk */
putexcel N23 = "`ambXmi_ambXmi_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel N23 = "`ambXmi_ambXmi_c'", hcenter vcenter
}





*- - - Hospital and Ambulance and Mileage - - -*

/*Hospital coeficient*/

if `hos_amb_mi_hos_p' < 0.001{ /* if significant, put asterisk */
putexcel D25 = "`hos_amb_mi_hos_c'***", hcenter vcenter
}
else if `hos_amb_mi_hos_p' < 0.01{ /* if significant, put asterisk */
putexcel D25 = "`hos_amb_mi_hos_c'**", hcenter vcenter
}
else if `hos_amb_mi_hos_p' < 0.05{ /* if significant, put asterisk */
putexcel D25 = "`hos_amb_mi_hos_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel D25 = "`hos_amb_mi_hos_c'", hcenter vcenter
}

/*Ambulance coeficient*/

if `hos_amb_mi_amb_p' < 0.001{ /* if significant, put asterisk */
putexcel F25 = "`hos_amb_mi_amb_c'***", hcenter vcenter
}
else if `hos_amb_mi_amb_p' < 0.01{ /* if significant, put asterisk */
putexcel F25 = "`hos_amb_mi_amb_c'**", hcenter vcenter
}
else if `hos_amb_mi_amb_p' < 0.05{ /* if significant, put asterisk */
putexcel F25 = "`hos_amb_mi_amb_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel F25 = "`hos_amb_mi_amb_c'", hcenter vcenter
}

/*Mileage coeficient*/

if `hos_amb_mi_mi_p' < 0.001{ /* if significant, put asterisk */
putexcel H25 = "`hos_amb_mi_mi_c'***", hcenter vcenter
}
else if `hos_amb_mi_mi_p' < 0.01{ /* if significant, put asterisk */
putexcel H25 = "`hos_amb_mi_mi_c'**", hcenter vcenter
}
else if `hos_amb_mi_mi_p' < 0.05{ /* if significant, put asterisk */
putexcel H25 = "`hos_amb_mi_mi_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel H25 = "`hos_amb_mi_mi_c'", hcenter vcenter
}





*- - - Hospital X Ambulance and Mileage - - -*

/*Hospital coeficient*/

if `hosXamb_mi_hos_p' < 0.001{ /* if significant, put asterisk */
putexcel D26 = "`hosXamb_mi_hos_c'***", hcenter vcenter
}
else if `hosXamb_mi_hos_p' < 0.01{ /* if significant, put asterisk */
putexcel D26 = "`hosXamb_mi_hos_c'**", hcenter vcenter
}
else if `hosXamb_mi_hos_p' < 0.05{ /* if significant, put asterisk */
putexcel D26 = "`hosXamb_mi_hos_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel D26 = "`hosXamb_mi_hos_c'", hcenter vcenter
}

/*Ambulance coeficient*/

if `hosXamb_mi_amb_p' < 0.001{ /* if significant, put asterisk */
putexcel F26 = "`hosXamb_mi_amb_c'***", hcenter vcenter
}
else if `hosXamb_mi_amb_p' < 0.01{ /* if significant, put asterisk */
putexcel F26 = "`hosXamb_mi_amb_c'**", hcenter vcenter
}
else if `hosXamb_mi_amb_p' < 0.05{ /* if significant, put asterisk */
putexcel F26 = "`hosXamb_mi_amb_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel F26 = "`hosXamb_mi_amb_c'", hcenter vcenter
}

/*Hospital X Ambulance coeficient*/

if `hosXamb_mi_hosXamb_p' < 0.001{ /* if significant, put asterisk */
putexcel J26 = "`hosXamb_mi_hosXamb_c'***", hcenter vcenter
}
else if `hosXamb_mi_hosXamb_p' < 0.01{ /* if significant, put asterisk */
putexcel J26 = "`hosXamb_mi_hosXamb_c'**", hcenter vcenter
}
else if `hosXamb_mi_hosXamb_p' < 0.05{ /* if significant, put asterisk */
putexcel J26 = "`hosXamb_mi_hosXamb_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel J26 = "`hosXamb_mi_hosXamb_c'", hcenter vcenter
}

/*Mileage coeficient*/

if `hosXamb_mi_mi_p' < 0.001{ /* if significant, put asterisk */
putexcel H26 = "`hosXamb_mi_mi_c'***", hcenter vcenter
}
else if `hosXamb_mi_mi_p' < 0.01{ /* if significant, put asterisk */
putexcel H26 = "`hosXamb_mi_mi_c'**", hcenter vcenter
}
else if `hosXamb_mi_mi_p' < 0.05{ /* if significant, put asterisk */
putexcel H26 = "`hosXamb_mi_mi_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel H26 = "`hosXamb_mi_mi_c'", hcenter vcenter
}





*- - - Hospital X Mileage and Ambulance - - -*

/*Hospital coeficient*/

if `hosXmi_amb_hos_p' < 0.001{ /* if significant, put asterisk */
putexcel D27 = "`hosXmi_amb_hos_c'***", hcenter vcenter
}
else if `hosXmi_amb_hos_p' < 0.01{ /* if significant, put asterisk */
putexcel D27 = "`hosXmi_amb_hos_c'**", hcenter vcenter
}
else if `hosXmi_amb_hos_p' < 0.05{ /* if significant, put asterisk */
putexcel D27 = "`hosXmi_amb_hos_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel D27 = "`hosXmi_amb_hos_c'", hcenter vcenter
}

/*Mileage coeficient*/

if `hosXmi_amb_mi_p' < 0.001{ /* if significant, put asterisk */
putexcel H27 = "`hosXmi_amb_mi_c'***", hcenter vcenter
}
else if `hosXmi_amb_mi_p' < 0.01{ /* if significant, put asterisk */
putexcel H27 = "`hosXmi_amb_mi_c'**", hcenter vcenter
}
else if `hosXmi_amb_mi_p' < 0.05{ /* if significant, put asterisk */
putexcel H27 = "`hosXmi_amb_mi_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel H27 = "`hosXmi_amb_mi_c'", hcenter vcenter
}

/*Hospital X Mileage coeficient*/

if `hosXmi_amb_hosXmi_p' < 0.001{ /* if significant, put asterisk */
putexcel L27 = "`hosXmi_amb_hosXmi_c'***", hcenter vcenter
}
else if `hosXmi_amb_hosXmi_p' < 0.01{ /* if significant, put asterisk */
putexcel L27 = "`hosXmi_amb_hosXmi_c'**", hcenter vcenter
}
else if `hosXmi_amb_hosXmi_p' < 0.05{ /* if significant, put asterisk */
putexcel L27 = "`hosXmi_amb_hosXmi_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel L27 = "`hosXmi_amb_hosXmi_c'", hcenter vcenter
}

/*Ambulance coeficient*/

if `hosXmi_amb_amb_p' < 0.001{ /* if significant, put asterisk */
putexcel F27 = "`hosXmi_amb_amb_c'***", hcenter vcenter
}
else if `hosXmi_amb_amb_p' < 0.01{ /* if significant, put asterisk */
putexcel F27 = "`hosXmi_amb_amb_c'**", hcenter vcenter
}
else if `hosXmi_amb_amb_p' < 0.05{ /* if significant, put asterisk */
putexcel F27 = "`hosXmi_amb_amb_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel F27 = "`hosXmi_amb_amb_c'", hcenter vcenter
}





*- - - Ambulance X Mileage and Hospital - - -*

/*Ambulance coefficient*/

if `ambXmi_hos_amb_p' < 0.001{ /* if significant, put asterisk */
putexcel F28 = "`ambXmi_hos_amb_c'***", hcenter vcenter
}
else if `ambXmi_hos_amb_p' < 0.01{ /* if significant, put asterisk */
putexcel F28 = "`ambXmi_hos_amb_c'**", hcenter vcenter
}
else if `ambXmi_hos_amb_p' < 0.05{ /* if significant, put asterisk */
putexcel F28 = "`ambXmi_hos_amb_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel F28 = "`ambXmi_hos_amb_c'", hcenter vcenter
}

/*Mileage coefficient*/

if `ambXmi_hos_mi_p' < 0.001{ /* if significant, put asterisk */
putexcel H28 = "`ambXmi_hos_mi_c'***", hcenter vcenter
}
else if `ambXmi_hos_mi_p' < 0.01{ /* if significant, put asterisk */
putexcel H28 = "`ambXmi_hos_mi_c'**", hcenter vcenter
}
else if `ambXmi_hos_mi_p' < 0.05{ /* if significant, put asterisk */
putexcel H28 = "`ambXmi_hos_mi_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel H28 = "`ambXmi_hos_mi_c'", hcenter vcenter
}

/*Ambulance X Mileage coefficient*/

if `ambXmi_hos_ambXmi_p' < 0.001{ /* if significant, put asterisk */
putexcel N28 = "`ambXmi_hos_ambXmi_c'***", hcenter vcenter
}
else if `ambXmi_hos_ambXmi_p' < 0.01{ /* if significant, put asterisk */
putexcel N28 = "`ambXmi_hos_ambXmi_c'**", hcenter vcenter
}
else if `ambXmi_hos_ambXmi_p' < 0.05{ /* if significant, put asterisk */
putexcel N28 = "`ambXmi_hos_ambXmi_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel N28 = "`ambXmi_hos_ambXmi_c'", hcenter vcenter
}

/*Hospital coefficient*/

if `ambXmi_hos_hos_p' < 0.001{ /* if significant, put asterisk */
putexcel D28 = "`ambXmi_hos_hos_c'***", hcenter vcenter
}
else if `ambXmi_hos_hos_p' < 0.01{ /* if significant, put asterisk */
putexcel D28 = "`ambXmi_hos_hos_c'**", hcenter vcenter
}
else if `ambXmi_hos_hos_p' < 0.05{ /* if significant, put asterisk */
putexcel D28 = "`ambXmi_hos_hos_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel D28 = "`ambXmi_hos_hos_c'", hcenter vcenter
}





*- - - Hospital X Ambulance X Mileage - - -*

/*Hospital coefficient*/

if `hosXambXmi_hos_p' < 0.001{ /* if significant, put asterisk */
putexcel D29 = "`hosXambXmi_hos_c'***", hcenter vcenter
}
else if `hosXambXmi_hos_p' < 0.01{ /* if significant, put asterisk */
putexcel D29 = "`hosXambXmi_hos_c'**", hcenter vcenter
}
else if `hosXambXmi_hos_p' < 0.05{ /* if significant, put asterisk */
putexcel D29 = "`hosXambXmi_hos_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel D29 = "`hosXambXmi_hos_c'", hcenter vcenter
}

/*Ambulance coefficient*/

if `hosXambXmi_amb_p' < 0.001{ /* if significant, put asterisk */
putexcel F29 = "`hosXambXmi_amb_c'***", hcenter vcenter
}
else if `hosXambXmi_amb_p' < 0.01{ /* if significant, put asterisk */
putexcel F29 = "`hosXambXmi_amb_c'**", hcenter vcenter
}
else if `hosXambXmi_amb_p' < 0.05{ /* if significant, put asterisk */
putexcel F29 = "`hosXambXmi_amb_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel F29 = "`hosXambXmi_amb_c'", hcenter vcenter
}

/*Mileage coefficient*/

if `hosXambXmi_mi_p' < 0.001{ /* if significant, put asterisk */
putexcel H29 = "`hosXambXmi_mi_c'***", hcenter vcenter
}
else if `hosXambXmi_mi_p' < 0.01{ /* if significant, put asterisk */
putexcel H29 = "`hosXambXmi_mi_c'**", hcenter vcenter
}
else if `hosXambXmi_mi_p' < 0.05{ /* if significant, put asterisk */
putexcel H29 = "`hosXambXmi_mi_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel H29 = "`hosXambXmi_mi_c'", hcenter vcenter
}

/*Hospital X Ambulance coefficient*/

if `hosXambXmi_hosXamb_p' < 0.001{ /* if significant, put asterisk */
putexcel J29 = "`hosXambXmi_hosXamb_c'***", hcenter vcenter
}
else if `hosXambXmi_hosXamb_p' < 0.01{ /* if significant, put asterisk */
putexcel J29 = "`hosXambXmi_hosXamb_c'**", hcenter vcenter
}
else if `hosXambXmi_hosXamb_p' < 0.05{ /* if significant, put asterisk */
putexcel J29 = "`hosXambXmi_hosXamb_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel J29 = "`hosXambXmi_hosXamb_c'", hcenter vcenter
}

/*Hospital X Mileage coefficient*/

if `hosXambXmi_hosXmi_p' < 0.001{ /* if significant, put asterisk */
putexcel L29 = "`hosXambXmi_hosXmi_c'***", hcenter vcenter
}
else if `hosXambXmi_hosXmi_p' < 0.01{ /* if significant, put asterisk */
putexcel L29 = "`hosXambXmi_hosXmi_c'**", hcenter vcenter
}
else if `hosXambXmi_hosXmi_p' < 0.05{ /* if significant, put asterisk */
putexcel L29 = "`hosXambXmi_hosXmi_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel L29 = "`hosXambXmi_hosXmi_c'", hcenter vcenter
}

/*Ambulance X Mileage coefficient*/

if `hosXambXmi_ambXmi_p' < 0.001{ /* if significant, put asterisk */
putexcel N29 = "`hosXambXmi_ambXmi_c'***", hcenter vcenter
}
else if `hosXambXmi_ambXmi_p' < 0.01{ /* if significant, put asterisk */
putexcel N29 = "`hosXambXmi_ambXmi_c'**", hcenter vcenter
}
else if `hosXambXmi_ambXmi_p' < 0.05{ /* if significant, put asterisk */
putexcel N29 = "`hosXambXmi_ambXmi_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel N29 = "`hosXambXmi_ambXmi_c'", hcenter vcenter
}

/* Hospital X Ambulance X Mileage coefficient*/

if `hosXambXmi_hosXambXmi_p' < 0.001{ /* if significant, put asterisk */
putexcel P29 = "`hosXambXmi_hosXambXmi_c'***", hcenter vcenter
}
else if `hosXambXmi_hosXambXmi_p' < 0.01{ /* if significant, put asterisk */
putexcel P29 = "`hosXambXmi_hosXambXmi_c'**", hcenter vcenter
}
else if `hosXambXmi_hosXambXmi_p' < 0.05{ /* if significant, put asterisk */
putexcel P29 = "`hosXambXmi_hosXambXmi_c'*", hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel P29 = "`hosXambXmi_hosXambXmi_c'", hcenter vcenter
}







* scp jessyjkn@phs-rs24.bsd.uchicago.edu:/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/merged_ats_claims_for_stata/tab_char_no_labels.xlsx /Users/jessyjkn/Desktop/Job/Data/trauma_center_project/regression_results

} /* for quietly*/