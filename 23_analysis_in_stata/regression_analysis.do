*------------------------------------------------------------------------------*
* Project: Trauma Center Project (Regression Paper with Pre-Hospital)
* Author: Jessy Nguyen
* Last Updated: September 12, 2022
* Description: Regression analysis. Creates exhibits 1, part of exhibit 3, and output data for exhibit 2 and 4.
*------------------------------------------------------------------------------*

quietly{ /* Suppress outputs */

Overview: We examined the interaction effects of hospital type (level 1 trauma center vs non-trauma center) and ambulance
type (ALS vs BLS) on 30-day mortality.

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

* Keep only trauma level 1 and nontrauma centers
keep if (TRAUMA_LEVEL == 1 | TRAUMA_LEVEL == 6)
ren t1 treatment

*--------------- Create macros for characteristic table (Unadjusted; exhibit 1) ---------------*

* Create list named covariates. Indicators were created above
local covariates niss riss AGE comorbid female white black other_n asian_pi hispanic BLOODPT m_hh_inc pvrty fem_cty eld_cty metro cllge gen_md med_cty cc_cnt

* Create list of hospital type (1 is level 1 and 6 is nontrauma)
local hos_type 1 6

* Create list of amb type (1 is BLS and 2 is ALS)
local amb_type 1 2

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
            if inlist("`c'","female","white", "black", "other_n", "asian_pi", "hispanic")|inlist("`c'","pvrty", "fem_cty", "eld_cty", "metro", "cllge", "gen_md", "med_cty"){
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

************* REGRESSIONS ***************************************************************************

* Create variable for the log of median household income to account for right skewness
gen median_hh_inc_ln = ln(m_hh_inc)

*______ Exhibit 3 _______#

* Working with thirty day death
drop if SRVC_BGN_DT >= mdyhms(12, 01, 2017, 0, 0, 0) /* To use 30 day death, need to drop last 30 days (Dec 2017) */

* Create binary for miles variable at different threshold
gen mile_binary = 0
replace mile_binary = 1 if MILES>4

*---- Main effect: compare lvl 1 with nt (without amb type) ----#

* Create splines for niss and riss to allow for flexibility based on bands from past literature
mkspline niss1 24 niss2 40 niss3 49 niss4=niss
mkspline riss1 24 riss2 40 riss3 49 riss4=riss

* Outcome: Thirty Day Death
logit thirty_day_death_ind i.treatment i.mile_binary SH_ind EH_ind NH_ind RH_ind niss1-niss4 riss1-riss4 ib2.RACE ib1.SEX c.AGE##c.AGE c.comorbid##c.comorbid c.BLOODPT ///
        c.mxaisbr_HeadNeck c.mxaisbr_Extremities c.mxaisbr_Chest c.mxaisbr_Abdomen c.maxais i.STATE i.year_fe AMI_EVER_ind ///
        ALZH_EVER_ind ALZH_DEMEN_EVER_ind ATRIAL_FIB_EVER_ind CATARACT_EVER_ind CHRONICKIDNEY_EVER_ind COPD_EVER_ind CHF_EVER_ind ///
        DIABETES_EVER_ind GLAUCOMA_EVER_ind ISCHEMICHEART_EVER_ind DEPRESSION_EVER_ind OSTEOPOROSIS_EVER_ind ///
        RA_OA_EVER_ind STROKE_TIA_EVER_ind CANCER_BREAST_EVER_ind CANCER_COLORECTAL_EVER_ind CANCER_PROSTATE_EVER_ind CANCER_LUNG_EVER_ind ///
        CANCER_ENDOMETRIAL_EVER_ind ANEMIA_EVER_ind ASTHMA_EVER_ind HYPERL_EVER_ind HYPERP_EVER_ind HYPERT_EVER_ind HYPOTH_EVER_ind ///
        MULSCL_MEDICARE_EVER_ind OBESITY_MEDICARE_EVER_ind EPILEP_MEDICARE_EVER_ind median_hh_inc_ln pvrty fem_cty eld_cty ///
        ib0.metro_micro_cnty cllge gen_md med_cty full_dual_ind, cformat(%5.3f)

* Predict with margins
margins i.treatment, cformat(%9.3f) post coeflegend

* t tests between less and more miles
noisily di "L1 vs NT without amb type"
lincom _b[1.treatment] - _b[0bn.treatment]
local l1_minus_nt_c = string(r(estimate)*100,"%9.2f")
local l1_minus_nt_p = r(p)

*---- Main effect: compare als with bls (without amb type) ----#

* Outcome: Thirty Day Death
logit thirty_day_death_ind ib1.amb_type i.mile_binary SH_ind EH_ind NH_ind RH_ind niss1-niss4 riss1-riss4 ib2.RACE ib1.SEX c.AGE##c.AGE c.comorbid##c.comorbid c.BLOODPT ///
        c.mxaisbr_HeadNeck c.mxaisbr_Extremities c.mxaisbr_Chest c.mxaisbr_Abdomen c.maxais i.STATE i.year_fe AMI_EVER_ind ///
        ALZH_EVER_ind ALZH_DEMEN_EVER_ind ATRIAL_FIB_EVER_ind CATARACT_EVER_ind CHRONICKIDNEY_EVER_ind COPD_EVER_ind CHF_EVER_ind ///
        DIABETES_EVER_ind GLAUCOMA_EVER_ind ISCHEMICHEART_EVER_ind DEPRESSION_EVER_ind OSTEOPOROSIS_EVER_ind ///
        RA_OA_EVER_ind STROKE_TIA_EVER_ind CANCER_BREAST_EVER_ind CANCER_COLORECTAL_EVER_ind CANCER_PROSTATE_EVER_ind CANCER_LUNG_EVER_ind ///
        CANCER_ENDOMETRIAL_EVER_ind ANEMIA_EVER_ind ASTHMA_EVER_ind HYPERL_EVER_ind HYPERP_EVER_ind HYPERT_EVER_ind HYPOTH_EVER_ind ///
        MULSCL_MEDICARE_EVER_ind OBESITY_MEDICARE_EVER_ind EPILEP_MEDICARE_EVER_ind median_hh_inc_ln pvrty fem_cty eld_cty ///
        ib0.metro_micro_cnty cllge gen_md med_cty full_dual_ind, cformat(%5.3f)

* Predict with margins
margins ib1.amb_type, cformat(%9.3f) post coeflegend

* t tests between less and more miles
noisily di "ALS vs BLS without trauma center"
lincom _b[2.amb_type] - _b[1bn.amb_type]
local als_minus_bls_c = string(r(estimate)*100,"%9.2f")
local als_minus_bls_p = r(p)

*---- Interaction effect: hospital x ambulance (without miles) ----#

* Outcome: Thirty Day Death
logit thirty_day_death_ind i.treatment##ib1.amb_type SH_ind EH_ind NH_ind RH_ind niss1-niss4 riss1-riss4 ib2.RACE ib1.SEX c.AGE##c.AGE c.comorbid##c.comorbid c.BLOODPT ///
        c.mxaisbr_HeadNeck c.mxaisbr_Extremities c.mxaisbr_Chest c.mxaisbr_Abdomen c.maxais i.STATE i.year_fe AMI_EVER_ind ///
        ALZH_EVER_ind ALZH_DEMEN_EVER_ind ATRIAL_FIB_EVER_ind CATARACT_EVER_ind CHRONICKIDNEY_EVER_ind COPD_EVER_ind CHF_EVER_ind ///
        DIABETES_EVER_ind GLAUCOMA_EVER_ind ISCHEMICHEART_EVER_ind DEPRESSION_EVER_ind OSTEOPOROSIS_EVER_ind ///
        RA_OA_EVER_ind STROKE_TIA_EVER_ind CANCER_BREAST_EVER_ind CANCER_COLORECTAL_EVER_ind CANCER_PROSTATE_EVER_ind CANCER_LUNG_EVER_ind ///
        CANCER_ENDOMETRIAL_EVER_ind ANEMIA_EVER_ind ASTHMA_EVER_ind HYPERL_EVER_ind HYPERP_EVER_ind HYPERT_EVER_ind HYPOTH_EVER_ind ///
        MULSCL_MEDICARE_EVER_ind OBESITY_MEDICARE_EVER_ind EPILEP_MEDICARE_EVER_ind median_hh_inc_ln pvrty fem_cty eld_cty ///
        ib0.metro_micro_cnty cllge gen_md med_cty full_dual_ind, cformat(%5.3f)

* Predict with margins
margins i.treatment##ib1.amb_type, cformat(%9.3f) post coeflegend

* t tests
noisily di "w/in NT"
lincom _b[0bn.treatment#2.amb_type] - _b[0bn.treatment#1bn.amb_type]
local no_mi_als_minus_bls_in_nt_c = string(r(estimate)*100,"%9.2f")
local no_mi_als_minus_bls_in_nt_p = r(p)
local no_mi_als_minus_bls_in_nt_con = string(_b[0bn.treatment#1bn.amb_type]*100,"%9.2f")

noisily di "w/in L1"
lincom _b[1.treatment#2.amb_type] - _b[1.treatment#1bn.amb_type]
local no_mi_als_minus_bls_in_l1_c = string(r(estimate)*100,"%9.2f")
local no_mi_als_minus_bls_in_l1_p = r(p)
local no_mi_als_minus_bls_in_l1_con = string(_b[1.treatment#1bn.amb_type]*100,"%9.2f")

noisily di "w/in BLS"
lincom _b[1.treatment#1bn.amb_type] - _b[0bn.treatment#1bn.amb_type]
local no_mi_l1_minus_nt_in_bls_c = string(r(estimate)*100,"%9.2f")
local no_mi_l1_minus_nt_in_bls_p = r(p)
local no_mi_l1_minus_nt_in_bls_con = string(_b[0bn.treatment#1bn.amb_type]*100,"%9.2f")

noisily di "w/in ALS"
lincom _b[1.treatment#2.amb_type] - _b[0bn.treatment#2.amb_type]
local no_mi_l1_minus_nt_in_als_c = string(r(estimate)*100,"%9.2f")
local no_mi_l1_minus_nt_in_als_p = r(p)
local no_mi_l1_minus_nt_in_als_con = string(_b[0bn.treatment#2.amb_type]*100,"%9.2f")

*---- Interaction effect: hospital x ambulance (with miles) ----#

* Outcome: Thirty Day Death (read out coefficient for appendix)
asdoc logit thirty_day_death_ind i.treatment##ib1.amb_type i.mile_binary SH_ind EH_ind NH_ind RH_ind niss1-niss4 riss1-riss4 ib2.RACE ib1.SEX c.AGE##c.AGE c.comorbid##c.comorbid c.BLOODPT ///
        c.mxaisbr_HeadNeck c.mxaisbr_Extremities c.mxaisbr_Chest c.mxaisbr_Abdomen c.maxais i.STATE i.year_fe AMI_EVER_ind ///
        ALZH_EVER_ind ALZH_DEMEN_EVER_ind ATRIAL_FIB_EVER_ind CATARACT_EVER_ind CHRONICKIDNEY_EVER_ind COPD_EVER_ind CHF_EVER_ind ///
        DIABETES_EVER_ind GLAUCOMA_EVER_ind ISCHEMICHEART_EVER_ind DEPRESSION_EVER_ind OSTEOPOROSIS_EVER_ind ///
        RA_OA_EVER_ind STROKE_TIA_EVER_ind CANCER_BREAST_EVER_ind CANCER_COLORECTAL_EVER_ind CANCER_PROSTATE_EVER_ind CANCER_LUNG_EVER_ind ///
        CANCER_ENDOMETRIAL_EVER_ind ANEMIA_EVER_ind ASTHMA_EVER_ind HYPERL_EVER_ind HYPERP_EVER_ind HYPERT_EVER_ind HYPOTH_EVER_ind ///
        MULSCL_MEDICARE_EVER_ind OBESITY_MEDICARE_EVER_ind EPILEP_MEDICARE_EVER_ind median_hh_inc_ln pvrty fem_cty eld_cty ///
        ib0.metro_micro_cnty cllge gen_md med_cty full_dual_ind, save(appendix_logit_table_w_mile) replace cformat(%5.3f)

* Grab logit table with coefficients for appendix
* scp jessyjkn@phs-rs24.bsd.uchicago.edu:/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/merged_ats_claims_for_stata/appendix_logit_table_w_mile.doc /Users/jessyjkn/Desktop/

* Predict with margins
margins i.treatment##ib1.amb_type, cformat(%9.3f) post coeflegend

* t tests
noisily di "w/in NT"
lincom _b[0bn.treatment#2.amb_type] - _b[0bn.treatment#1bn.amb_type]
local mi_als_minus_bls_in_nt_c = string(r(estimate)*100,"%9.2f")
local mi_als_minus_bls_in_nt_p = r(p)
local mi_als_minus_bls_in_nt_con = string(_b[0bn.treatment#1bn.amb_type]*100,"%9.2f")

noisily di "w/in L1"
lincom _b[1.treatment#2.amb_type] - _b[1.treatment#1bn.amb_type]
local mi_als_minus_bls_in_l1_c = string(r(estimate)*100,"%9.2f")
local mi_als_minus_bls_in_l1_p = r(p)
local mi_als_minus_bls_in_l1_con = string(_b[1.treatment#1bn.amb_type]*100,"%9.2f")

noisily di "w/in BLS"
lincom _b[1.treatment#1bn.amb_type] - _b[0bn.treatment#1bn.amb_type]
local mi_l1_minus_nt_in_bls_c = string(r(estimate)*100,"%9.2f")
local mi_l1_minus_nt_in_bls_p = r(p)
local mi_l1_minus_nt_in_bls_con = string(_b[0bn.treatment#1bn.amb_type]*100,"%9.2f")

noisily di "w/in ALS"
lincom _b[1.treatment#2.amb_type] - _b[0bn.treatment#2.amb_type]
local mi_l1_minus_nt_in_als_c = string(r(estimate)*100,"%9.2f")
local mi_l1_minus_nt_in_als_p = r(p)
local mi_l1_minus_nt_in_als_con = string(_b[0bn.treatment#2.amb_type]*100,"%9.2f")

*______ Prepare dataset for Choice/NoChoice graphs (exhibit 4) ____________*

* Create list
local choice_nochoice_macro nochoice choice

* Create list of Panel A and Panel B
local panel_list panel_a panel_b

* Loop through each panel list to create data for panel A and panel B
foreach p of local panel_list{

    * Loop
    foreach g of local choice_nochoice_macro{

        preserve

        drop if SRVC_BGN_DT >= mdyhms(12, 01, 2017, 0, 0, 0) /* To use 30 day death, need to drop last 30 days (Dec 2017) */

        forvalues m=2(1)8 { /* Loop through different mile radius */

            tempfile og
            save `og'

            * Create mile binary
            noisily di "Mile threshold: radius of `m' for `g'"

            if inlist("`g'","choice"){
                keep if choice_ind_mi`m' == 1 /* choice */
                *noisily tab choice_ind_mi`m' /* See sample size */
            }
            else{
                keep if only_hos_at_mi`m' == 1 /* no choice */
                *noisily tab only_hos_at_mi`m' /* See sample size */
            }

            forvalues b=2(1)5{ /* Loop through different thresholds for mile binary indicator */

                * Create binary for miles variable at different threshold
                gen mile`b'_binary_w_radius`m' = 0
                replace mile`b'_binary_w_radius`m' = 1 if MILES>`b'
                label define mile`b'_binary_w_radius`m'_label 0 "less_mi" 1 "more_mi"
                label values mile`b'_binary_w_radius`m' mile`b'_binary_w_radius`m'_label

                if inlist("`p'","panel_b"){

                    * Logit regression
                    logit thirty_day_death_ind i.treatment ib1.amb_type i.mile`b'_binary_w_radius`m' niss1-niss4 riss1-riss4 ib2.RACE ib1.SEX c.AGE##c.AGE c.comorbid##c.comorbid c.BLOODPT ///
                    c.mxaisbr_HeadNeck c.mxaisbr_Extremities c.mxaisbr_Chest c.mxaisbr_Abdomen c.maxais i.STATE i.year_fe AMI_EVER_ind ///
                    ALZH_EVER_ind ALZH_DEMEN_EVER_ind ATRIAL_FIB_EVER_ind CATARACT_EVER_ind CHRONICKIDNEY_EVER_ind COPD_EVER_ind CHF_EVER_ind ///
                    DIABETES_EVER_ind GLAUCOMA_EVER_ind ISCHEMICHEART_EVER_ind DEPRESSION_EVER_ind OSTEOPOROSIS_EVER_ind ///
                    RA_OA_EVER_ind STROKE_TIA_EVER_ind CANCER_BREAST_EVER_ind CANCER_COLORECTAL_EVER_ind CANCER_PROSTATE_EVER_ind CANCER_LUNG_EVER_ind ///
                    CANCER_ENDOMETRIAL_EVER_ind ANEMIA_EVER_ind ASTHMA_EVER_ind HYPERL_EVER_ind HYPERP_EVER_ind HYPERT_EVER_ind HYPOTH_EVER_ind ///
                    MULSCL_MEDICARE_EVER_ind OBESITY_MEDICARE_EVER_ind EPILEP_MEDICARE_EVER_ind median_hh_inc_ln pvrty fem_cty eld_cty ///
                    ib0.metro_micro_cnty cllge gen_md med_cty full_dual_ind SH_ind EH_ind NH_ind RH_ind

                    noisily di "`g' with radius `m' and binary `b' for `p'"

                    table mile`b'_binary_w_radius`m', stat(freq) /* View sample size */

                    * Predict with margins
                    margins i.mile`b'_binary_w_radius`m', cformat(%9.3f) saving(radius`m'_binary`b'_`g'_`p', replace) post coeflegend

                    * t tests between less and more miles at each mile binary for choice and no choice
                    noisily lincom _b[1.mile`b'_binary_w_radius`m'] - _b[0bn.mile`b'_binary_w_radius`m']
                }
                else{ /* panel a */

                    * Logit regression (to have more power, I reduced CC indicators to categorical variables)
                    logit thirty_day_death_ind i.treatment##ib1.amb_type i.mile`b'_binary_w_radius`m' niss1-niss4 riss1-riss4 ib2.RACE ib1.SEX c.AGE##c.AGE c.comorbid##c.comorbid c.BLOODPT ///
                    c.mxaisbr_HeadNeck c.mxaisbr_Extremities c.mxaisbr_Chest c.mxaisbr_Abdomen c.maxais i.STATE i.year_fe AMI_EVER_ind ///
                    ALZH_EVER_ind ALZH_DEMEN_EVER_ind ATRIAL_FIB_EVER_ind CATARACT_EVER_ind CHRONICKIDNEY_EVER_ind COPD_EVER_ind CHF_EVER_ind ///
                    DIABETES_EVER_ind GLAUCOMA_EVER_ind ISCHEMICHEART_EVER_ind DEPRESSION_EVER_ind OSTEOPOROSIS_EVER_ind ///
                    RA_OA_EVER_ind STROKE_TIA_EVER_ind CANCER_BREAST_EVER_ind CANCER_COLORECTAL_EVER_ind CANCER_PROSTATE_EVER_ind CANCER_LUNG_EVER_ind ///
                    CANCER_ENDOMETRIAL_EVER_ind ANEMIA_EVER_ind ASTHMA_EVER_ind HYPERL_EVER_ind HYPERP_EVER_ind HYPERT_EVER_ind HYPOTH_EVER_ind ///
                    MULSCL_MEDICARE_EVER_ind OBESITY_MEDICARE_EVER_ind EPILEP_MEDICARE_EVER_ind median_hh_inc_ln pvrty fem_cty eld_cty ///
                    ib0.metro_micro_cnty cllge gen_md med_cty full_dual_ind SH_ind EH_ind NH_ind RH_ind

                    noisily di "`g' with radius `m' and binary `b' for `p'"

                    table TRAUMA_LEVEL amb_type, stat(freq) /* View sample size */

                    * Predict with margins
                    margins i.treatment##ib1.amb_type, cformat(%9.3f) saving(radius`m'_binary`b'_`g'_`p', replace) post coeflegend
                }


            }

            use `og',clear

        }

        restore
    }

}




*---------- CREATE BALANCE TABLE FOR EXCEL (BEFORE AND AFTER WEIGHTING) ------------*

* Set file name for excel sheet with modify option to create new table to store the balance tables
putexcel set "tab_char_no_labels.xlsx", sheet("bal_tab_`z'_`x'") replace

putexcel F1 = "`61'"
putexcel G1 = "`62'"
putexcel H1 = "`11'"
putexcel I1 = "`12'"

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

putexcel A10 = "`61comorbid'"
putexcel B10 = "`62comorbid'"
putexcel C10 = "`11comorbid'"
putexcel D10 = "`12comorbid'"

putexcel A11 = "`61niss'"
putexcel B11 = "`62niss'"
putexcel C11 = "`11niss'"
putexcel D11 = "`12niss'"

putexcel A12 = "`61riss'"
putexcel B12 = "`62riss'"
putexcel C12 = "`11riss'"
putexcel D12 = "`12riss'"

putexcel A13 = "`61BLOODPT'"
putexcel B13 = "`62BLOODPT'"
putexcel C13 = "`11BLOODPT'"
putexcel D13 = "`12BLOODPT'"

putexcel A14 = "`61m_hh_inc'"
putexcel B14 = "`62m_hh_inc'"
putexcel C14 = "`11m_hh_inc'"
putexcel D14 = "`12m_hh_inc'"

putexcel A16 = "`61pvrty'"
putexcel B16 = "`62pvrty'"
putexcel C16 = "`11pvrty'"
putexcel D16 = "`12pvrty'"

putexcel A17 = "`61fem_cty'"
putexcel B17 = "`62fem_cty'"
putexcel C17 = "`11fem_cty'"
putexcel D17 = "`12fem_cty'"

putexcel A18 = "`61eld_cty'"
putexcel B18 = "`62eld_cty'"
putexcel C18 = "`11eld_cty'"
putexcel D18 = "`12eld_cty'"

putexcel A19 = "`61metro'"
putexcel B19 = "`62metro'"
putexcel C19 = "`11metro'"
putexcel D19 = "`12metro'"

putexcel A20 = "`61cllge'"
putexcel B20 = "`62cllge'"
putexcel C20 = "`11cllge'"
putexcel D20 = "`12cllge'"

putexcel A21 = "`61gen_md'"
putexcel B21 = "`62gen_md'"
putexcel C21 = "`11gen_md'"
putexcel D21 = "`12gen_md'"

putexcel A22 = "`61med_cty'"
putexcel B22 = "`62med_cty'"
putexcel C22 = "`11med_cty'"
putexcel D22 = "`12med_cty'"

*---------- CREATE PART OF EXHIBIT 3 FOR EXCEL ------------*
* Only has results from regression. For results from propensity score, see script pscore.do

* Set file name for excel sheet with modify option to create new table to store the balance tables
putexcel set "tab_char_no_labels.xlsx", sheet("exhibit_3") modify

* - - - Main effect: L1 vs NT W/ Miles but without ambulance - - - #

if `l1_minus_nt_p' < 0.001{ /* if significant, put asterisk */
putexcel (A1:E1) = "`l1_minus_nt_c'***", merge hcenter vcenter
}
else if `l1_minus_nt_p' < 0.01{ /* if significant, put asterisk */
putexcel (A1:E1) = "`l1_minus_nt_c'**", merge hcenter vcenter
}
else if `l1_minus_nt_p' < 0.05{ /* if significant, put asterisk */
putexcel (A1:E1) = "`l1_minus_nt_c'*", merge hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel (A1:E1) = "`l1_minus_nt_c'", merge hcenter vcenter
}

* - - - Main effect: ALS vs BLS W/ Miles but without trauma center - - - #

if `als_minus_bls_p' < 0.001{ /* if significant, put asterisk */
putexcel (G1:K1) = "`als_minus_bls_c'***", merge hcenter vcenter
}
else if `als_minus_bls_p' < 0.01{ /* if significant, put asterisk */
putexcel (G1:K1) = "`als_minus_bls_c'**", merge hcenter vcenter
}
else if `als_minus_bls_p' < 0.05{ /* if significant, put asterisk */
putexcel (G1:K1) = "`als_minus_bls_c'*", merge hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel (G1:K1) = "`als_minus_bls_c'", merge hcenter vcenter
}

* - - - Without Miles - - - *

putexcel A7 = "`no_mi_als_minus_bls_in_l1_con'"

if `no_mi_als_minus_bls_in_l1_p' < 0.001{ /* if significant, put asterisk */
putexcel B7 = "`no_mi_als_minus_bls_in_l1_c'***"
}
else if `no_mi_als_minus_bls_in_l1_p' < 0.01{ /* if significant, put asterisk */
putexcel B7 = "`no_mi_als_minus_bls_in_l1_c'**"
}
else if `no_mi_als_minus_bls_in_l1_p' < 0.05{ /* if significant, put asterisk */
putexcel B7 = "`no_mi_als_minus_bls_in_l1_c'*"
}
else{ /* if NOT significant, omit asterisk */
putexcel B7 = "`no_mi_als_minus_bls_in_l1_c'"
}

putexcel D7 = "`no_mi_als_minus_bls_in_nt_con'"

if `no_mi_als_minus_bls_in_nt_p' < 0.001{ /* if significant, put asterisk */
putexcel E7 = "`no_mi_als_minus_bls_in_nt_c'***"
}
else if `no_mi_als_minus_bls_in_nt_p' < 0.01{ /* if significant, put asterisk */
putexcel E7 = "`no_mi_als_minus_bls_in_nt_c'**"
}
else if `no_mi_als_minus_bls_in_nt_p' < 0.05{ /* if significant, put asterisk */
putexcel E7 = "`no_mi_als_minus_bls_in_nt_c'*"
}
else{ /* if NOT significant, omit asterisk */
putexcel E7 = "`no_mi_als_minus_bls_in_nt_c'"
}

putexcel G7 = "`no_mi_l1_minus_nt_in_als_con'"

if `no_mi_l1_minus_nt_in_als_p' < 0.001{ /* if significant, put asterisk */
putexcel H7 = "`no_mi_l1_minus_nt_in_als_c'***"
}
else if `no_mi_l1_minus_nt_in_als_p' < 0.01{ /* if significant, put asterisk */
putexcel H7 = "`no_mi_l1_minus_nt_in_als_c'**"
}
else if `no_mi_l1_minus_nt_in_als_p' < 0.05{ /* if significant, put asterisk */
putexcel H7 = "`no_mi_l1_minus_nt_in_als_c'*"
}
else{ /* if NOT significant, omit asterisk */
putexcel H7 = "`no_mi_l1_minus_nt_in_als_c'"
}

putexcel J7 = "`no_mi_l1_minus_nt_in_bls_con'"

if `no_mi_l1_minus_nt_in_bls_p' < 0.001{ /* if significant, put asterisk */
putexcel K7 = "`no_mi_l1_minus_nt_in_bls_c'***"
}
else if `no_mi_l1_minus_nt_in_bls_p' < 0.01{ /* if significant, put asterisk */
putexcel K7 = "`no_mi_l1_minus_nt_in_bls_c'**"
}
else if `no_mi_l1_minus_nt_in_bls_p' < 0.05{ /* if significant, put asterisk */
putexcel K7 = "`no_mi_l1_minus_nt_in_bls_c'*"
}
else{ /* if NOT significant, omit asterisk */
putexcel K7 = "`no_mi_l1_minus_nt_in_bls_c'"
}

* - - - With Miles - - - *

putexcel A9 = "`mi_als_minus_bls_in_l1_con'"

if `mi_als_minus_bls_in_l1_p' < 0.001{ /* if significant, put asterisk */
putexcel B9 = "`mi_als_minus_bls_in_l1_c'***"
}
else if `mi_als_minus_bls_in_l1_p' < 0.01{ /* if significant, put asterisk */
putexcel B9 = "`mi_als_minus_bls_in_l1_c'**"
}
else if `mi_als_minus_bls_in_l1_p' < 0.05{ /* if significant, put asterisk */
putexcel B9 = "`mi_als_minus_bls_in_l1_c'*"
}
else{ /* if NOT significant, omit asterisk */
putexcel B9 = "`mi_als_minus_bls_in_l1_c'"
}

putexcel D9 = "`mi_als_minus_bls_in_nt_con'"

if `mi_als_minus_bls_in_nt_p' < 0.001{ /* if significant, put asterisk */
putexcel E9 = "`mi_als_minus_bls_in_nt_c'***"
}
else if `mi_als_minus_bls_in_nt_p' < 0.01{ /* if significant, put asterisk */
putexcel E9 = "`mi_als_minus_bls_in_nt_c'**"
}
else if `mi_als_minus_bls_in_nt_p' < 0.05{ /* if significant, put asterisk */
putexcel E9 = "`mi_als_minus_bls_in_nt_c'*"
}
else{ /* if NOT significant, omit asterisk */
putexcel E9 = "`mi_als_minus_bls_in_nt_c'"
}

putexcel G9 = "`mi_l1_minus_nt_in_als_con'"

if `mi_l1_minus_nt_in_als_p' < 0.001{ /* if significant, put asterisk */
putexcel H9 = "`mi_l1_minus_nt_in_als_c'***"
}
else if `mi_l1_minus_nt_in_als_p' < 0.01{ /* if significant, put asterisk */
putexcel H9 = "`mi_l1_minus_nt_in_als_c'**"
}
else if `mi_l1_minus_nt_in_als_p' < 0.05{ /* if significant, put asterisk */
putexcel H9 = "`mi_l1_minus_nt_in_als_c'*"
}
else{ /* if NOT significant, omit asterisk */
putexcel H9 = "`mi_l1_minus_nt_in_als_c'"
}

putexcel J9 = "`mi_l1_minus_nt_in_bls_con'"

if `mi_l1_minus_nt_in_bls_p' < 0.001{ /* if significant, put asterisk */
putexcel K9 = "`mi_l1_minus_nt_in_bls_c'***"
}
else if `mi_l1_minus_nt_in_bls_p' < 0.01{ /* if significant, put asterisk */
putexcel K9 = "`mi_l1_minus_nt_in_bls_c'**"
}
else if `mi_l1_minus_nt_in_bls_p' < 0.05{ /* if significant, put asterisk */
putexcel K9 = "`mi_l1_minus_nt_in_bls_c'*"
}
else{ /* if NOT significant, omit asterisk */
putexcel K9 = "`mi_l1_minus_nt_in_bls_c'"
}

* scp jessyjkn@phs-rs24.bsd.uchicago.edu:/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/merged_ats_claims_for_stata/tab_char_no_labels.xlsx /Users/jessyjkn/Desktop/Job/Data/trauma_center_project/regression_results

} /* for quietly*/