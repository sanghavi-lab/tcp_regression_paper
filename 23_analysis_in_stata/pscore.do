*------------------------------------------------------------------------------*
* Project: Trauma Center Project (Regression Paper with Pre-Hospital)
* Author: Jessy Nguyen
* Last Updated: February 8, 2023
* Description: Propensity score analysis with overlap weights. Creates a section of exhibit 3.
*------------------------------------------------------------------------------*

quietly{ /* Suppress outputs */

/* Overview: For the propensity score-based analysis, we created four groups based on the possible combinations of hospital
and ambulance type and separately estimated overlap weights for each pair of comparisons. For example, to assess the effects
of hospital type among individuals who were transported by ALS ambulances, we modeled the propensity of an individual in the
sample of ALS patients to receive care at a level 1 trauma center (vs a non-trauma hospital), conditional on all observed
covariates. We then derived overlap weights for each observation by predicting probabilities p (i.e. propensity scores) of
receiving care at a level 1 trauma center from the fitted model and then assigning each individual who actually received care
at a level 1 trauma center a weight of (1 – p) and each individual who actually received care at a non-trauma center a weight
of p. Thus, individuals in each group that share characteristics with the opposite group, as measured by their propensity
scores, get higher weights than individuals who do not. We repeated this process for the other pairs. */

* Place in terminal to run script
* do /mnt/labshares/sanghavi-lab/Jessy/hpc_utils/codes/python/trauma_center_project/final_regression_analysis_paper_two/23_analysis_in_stata/pscore.do

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
*noisily table TRAUMA_LEVEL if MILES > 30 & amb==1 & less_than_90_bene_served==0, stat(freq) /* among large hospitals, what is the count of those who traveled above 30 miles*/

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

* Create outcome binary indicator for amb type
gen als_ind = 1
replace als_ind = 0 if amb_type == 1

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

* Create variable for the log of median household income to account for right skewness
gen median_hh_inc_ln = ln(m_hh_inc)

* Create list to loop through
local mile_nomile mile no_mile /* i.e. whether mile variable is specified in model or not */
local comp_groups_for_pscore nt_als_v_bls l1_als_v_bls als_l1_v_nt bls_l1_v_nt l1_v_nt als_v_bls /* different comparison groups */

* Loop
foreach m of local mile_nomile{

    * Loop through each comparison group
    foreach a of local comp_groups_for_pscore{

        noisily di "`m' `a'"

        tempfile og_hos_file
        save `og_hos_file'

        if "`a'" == "l1_als_v_bls"{
            keep if (inlist(TRAUMA_LEVEL,1) & inlist(amb_type,2)) | (inlist(TRAUMA_LEVEL,1) & inlist(amb_type,1))
        }

        else if "`a'" == "nt_als_v_bls"{
            keep if (inlist(TRAUMA_LEVEL,6) & inlist(amb_type,2)) | (inlist(TRAUMA_LEVEL,6) & inlist(amb_type,1))
        }

        else if "`a'" == "als_l1_v_nt"{
            keep if (inlist(TRAUMA_LEVEL,6) & inlist(amb_type,2)) | (inlist(TRAUMA_LEVEL,1) & inlist(amb_type,2))
        }

        else if "`a'" == "bls_l1_v_nt"{
            keep if (inlist(TRAUMA_LEVEL,6) & inlist(amb_type,1)) | (inlist(TRAUMA_LEVEL,1) & inlist(amb_type,1))
        }

        *____________ Step 1: Model P(D=1|X) using Logit ________________*

        * Create binary for miles (for now use threshold of 4 miles)
        gen mile_binary = 0
        replace mile_binary = 1 if MILES>4

        * Create splines for niss and riss to allow for flexibility based on bands from past literature
        mkspline `m'`a'niss1 24 `m'`a'niss2 40 `m'`a'niss3 49 `m'`a'niss4=niss
        mkspline `m'`a'riss1 24 `m'`a'riss2 40 `m'`a'riss3 49 `m'`a'riss4=riss

        if inlist("`m'","mile"){

            *--- "Main Effect" ---*

            if inlist("`a'","l1_v_nt"){

                * Step 1 logit
                logit treatment i.mile_binary `m'`a'niss1-`m'`a'niss4 `m'`a'riss1-`m'`a'riss4 ib2.RACE ib1.SEX c.AGE##c.AGE c.comorbid##c.comorbid c.BLOODPT ///
                c.mxaisbr_HeadNeck c.mxaisbr_Extremities c.mxaisbr_Chest c.mxaisbr_Abdomen c.maxais i.STATE i.year_fe AMI_EVER_ind ///
                ALZH_EVER_ind ALZH_DEMEN_EVER_ind ATRIAL_FIB_EVER_ind CATARACT_EVER_ind CHRONICKIDNEY_EVER_ind COPD_EVER_ind CHF_EVER_ind ///
                DIABETES_EVER_ind GLAUCOMA_EVER_ind ISCHEMICHEART_EVER_ind DEPRESSION_EVER_ind OSTEOPOROSIS_EVER_ind ///
                RA_OA_EVER_ind STROKE_TIA_EVER_ind CANCER_BREAST_EVER_ind CANCER_COLORECTAL_EVER_ind CANCER_PROSTATE_EVER_ind CANCER_LUNG_EVER_ind ///
                CANCER_ENDOMETRIAL_EVER_ind ANEMIA_EVER_ind ASTHMA_EVER_ind HYPERL_EVER_ind HYPERP_EVER_ind HYPERT_EVER_ind HYPOTH_EVER_ind ///
                MULSCL_MEDICARE_EVER_ind OBESITY_MEDICARE_EVER_ind EPILEP_MEDICARE_EVER_ind median_hh_inc_ln pvrty fem_cty eld_cty ///
                ib0.metro_micro_cnty cllge gen_md med_cty full_dual_ind SH_ind EH_ind NH_ind RH_ind
            }

            else if inlist("`a'","als_v_bls"){

                * Step 1 logit
                logit als_ind i.mile_binary `m'`a'niss1-`m'`a'niss4 `m'`a'riss1-`m'`a'riss4 ib2.RACE ib1.SEX c.AGE##c.AGE c.comorbid##c.comorbid c.BLOODPT ///
                c.mxaisbr_HeadNeck c.mxaisbr_Extremities c.mxaisbr_Chest c.mxaisbr_Abdomen c.maxais i.STATE i.year_fe AMI_EVER_ind ///
                ALZH_EVER_ind ALZH_DEMEN_EVER_ind ATRIAL_FIB_EVER_ind CATARACT_EVER_ind CHRONICKIDNEY_EVER_ind COPD_EVER_ind CHF_EVER_ind ///
                DIABETES_EVER_ind GLAUCOMA_EVER_ind ISCHEMICHEART_EVER_ind DEPRESSION_EVER_ind OSTEOPOROSIS_EVER_ind ///
                RA_OA_EVER_ind STROKE_TIA_EVER_ind CANCER_BREAST_EVER_ind CANCER_COLORECTAL_EVER_ind CANCER_PROSTATE_EVER_ind CANCER_LUNG_EVER_ind ///
                CANCER_ENDOMETRIAL_EVER_ind ANEMIA_EVER_ind ASTHMA_EVER_ind HYPERL_EVER_ind HYPERP_EVER_ind HYPERT_EVER_ind HYPOTH_EVER_ind ///
                MULSCL_MEDICARE_EVER_ind OBESITY_MEDICARE_EVER_ind EPILEP_MEDICARE_EVER_ind median_hh_inc_ln pvrty fem_cty eld_cty ///
                ib0.metro_micro_cnty cllge gen_md med_cty full_dual_ind SH_ind EH_ind NH_ind RH_ind
            }

            *--- "Interaction Effect" ---*

            else{

                if inlist("`a'","l1_als_v_bls"){
                    gen outcome_binary = 0
                    replace outcome_binary = 1 if (TRAUMA_LEVEL == 1) & (amb_type==2)
                }

                else if inlist("`a'","nt_als_v_bls"){
                    gen outcome_binary = 0
                    replace outcome_binary = 1 if (TRAUMA_LEVEL == 6) & (amb_type==2)
                }

                else if inlist("`a'","als_l1_v_nt"){
                    gen outcome_binary = 0
                    replace outcome_binary = 1 if (TRAUMA_LEVEL == 1) & (amb_type==2)
                }

                else if inlist("`a'","bls_l1_v_nt"){
                    gen outcome_binary = 0
                    replace outcome_binary = 1 if (TRAUMA_LEVEL == 1) & (amb_type==1)
                }

                * Step 1 logit
                logit outcome_binary i.mile_binary `m'`a'niss1-`m'`a'niss4 `m'`a'riss1-`m'`a'riss4 ib2.RACE ib1.SEX c.AGE##c.AGE c.comorbid##c.comorbid c.BLOODPT ///
                c.mxaisbr_HeadNeck c.mxaisbr_Extremities c.mxaisbr_Chest c.mxaisbr_Abdomen c.maxais i.STATE i.year_fe AMI_EVER_ind ///
                ALZH_EVER_ind ALZH_DEMEN_EVER_ind ATRIAL_FIB_EVER_ind CATARACT_EVER_ind CHRONICKIDNEY_EVER_ind COPD_EVER_ind CHF_EVER_ind ///
                DIABETES_EVER_ind GLAUCOMA_EVER_ind ISCHEMICHEART_EVER_ind DEPRESSION_EVER_ind OSTEOPOROSIS_EVER_ind ///
                RA_OA_EVER_ind STROKE_TIA_EVER_ind CANCER_BREAST_EVER_ind CANCER_COLORECTAL_EVER_ind CANCER_PROSTATE_EVER_ind CANCER_LUNG_EVER_ind ///
                CANCER_ENDOMETRIAL_EVER_ind ANEMIA_EVER_ind ASTHMA_EVER_ind HYPERL_EVER_ind HYPERP_EVER_ind HYPERT_EVER_ind HYPOTH_EVER_ind ///
                MULSCL_MEDICARE_EVER_ind OBESITY_MEDICARE_EVER_ind EPILEP_MEDICARE_EVER_ind median_hh_inc_ln pvrty fem_cty eld_cty ///
                ib0.metro_micro_cnty cllge gen_md med_cty full_dual_ind SH_ind EH_ind NH_ind RH_ind /* can't add in amb or treatment since the outcomes are both amb and treatment */
            }
        }

        else if inlist("`m'","no_mile"){

            *--- "Main Effect" ---*

            if inlist("`a'","l1_v_nt"){

                * Step 1 logit
                logit treatment `m'`a'niss1-`m'`a'niss4 `m'`a'riss1-`m'`a'riss4 ib2.RACE ib1.SEX c.AGE##c.AGE c.comorbid##c.comorbid c.BLOODPT ///
                c.mxaisbr_HeadNeck c.mxaisbr_Extremities c.mxaisbr_Chest c.mxaisbr_Abdomen c.maxais i.STATE i.year_fe AMI_EVER_ind ///
                ALZH_EVER_ind ALZH_DEMEN_EVER_ind ATRIAL_FIB_EVER_ind CATARACT_EVER_ind CHRONICKIDNEY_EVER_ind COPD_EVER_ind CHF_EVER_ind ///
                DIABETES_EVER_ind GLAUCOMA_EVER_ind ISCHEMICHEART_EVER_ind DEPRESSION_EVER_ind OSTEOPOROSIS_EVER_ind ///
                RA_OA_EVER_ind STROKE_TIA_EVER_ind CANCER_BREAST_EVER_ind CANCER_COLORECTAL_EVER_ind CANCER_PROSTATE_EVER_ind CANCER_LUNG_EVER_ind ///
                CANCER_ENDOMETRIAL_EVER_ind ANEMIA_EVER_ind ASTHMA_EVER_ind HYPERL_EVER_ind HYPERP_EVER_ind HYPERT_EVER_ind HYPOTH_EVER_ind ///
                MULSCL_MEDICARE_EVER_ind OBESITY_MEDICARE_EVER_ind EPILEP_MEDICARE_EVER_ind median_hh_inc_ln pvrty fem_cty eld_cty ///
                ib0.metro_micro_cnty cllge gen_md med_cty full_dual_ind SH_ind EH_ind NH_ind RH_ind

            }

            else if inlist("`a'","als_v_bls"){

                * Step 1 logit
                logit als_ind `m'`a'niss1-`m'`a'niss4 `m'`a'riss1-`m'`a'riss4 ib2.RACE ib1.SEX c.AGE##c.AGE c.comorbid##c.comorbid c.BLOODPT ///
                c.mxaisbr_HeadNeck c.mxaisbr_Extremities c.mxaisbr_Chest c.mxaisbr_Abdomen c.maxais i.STATE i.year_fe AMI_EVER_ind ///
                ALZH_EVER_ind ALZH_DEMEN_EVER_ind ATRIAL_FIB_EVER_ind CATARACT_EVER_ind CHRONICKIDNEY_EVER_ind COPD_EVER_ind CHF_EVER_ind ///
                DIABETES_EVER_ind GLAUCOMA_EVER_ind ISCHEMICHEART_EVER_ind DEPRESSION_EVER_ind OSTEOPOROSIS_EVER_ind ///
                RA_OA_EVER_ind STROKE_TIA_EVER_ind CANCER_BREAST_EVER_ind CANCER_COLORECTAL_EVER_ind CANCER_PROSTATE_EVER_ind CANCER_LUNG_EVER_ind ///
                CANCER_ENDOMETRIAL_EVER_ind ANEMIA_EVER_ind ASTHMA_EVER_ind HYPERL_EVER_ind HYPERP_EVER_ind HYPERT_EVER_ind HYPOTH_EVER_ind ///
                MULSCL_MEDICARE_EVER_ind OBESITY_MEDICARE_EVER_ind EPILEP_MEDICARE_EVER_ind median_hh_inc_ln pvrty fem_cty eld_cty ///
                ib0.metro_micro_cnty cllge gen_md med_cty full_dual_ind SH_ind EH_ind NH_ind RH_ind
            }

            *--- "Interaction Effect" ---*

            else{

                if inlist("`a'","l1_als_v_bls"){
                    gen outcome_binary = 0
                    replace outcome_binary = 1 if (TRAUMA_LEVEL == 1) & (amb_type==2)
                }

                else if inlist("`a'","nt_als_v_bls"){
                    gen outcome_binary = 0
                    replace outcome_binary = 1 if (TRAUMA_LEVEL == 6) & (amb_type==2)
                }

                else if inlist("`a'","als_l1_v_nt"){
                    gen outcome_binary = 0
                    replace outcome_binary = 1 if (TRAUMA_LEVEL == 1) & (amb_type==2)
                }

                else if inlist("`a'","bls_l1_v_nt"){
                    gen outcome_binary = 0
                    replace outcome_binary = 1 if (TRAUMA_LEVEL == 1) & (amb_type==1)
                }

                * Step 1 logit
                logit outcome_binary `m'`a'niss1-`m'`a'niss4 `m'`a'riss1-`m'`a'riss4 ib2.RACE ib1.SEX c.AGE##c.AGE c.comorbid##c.comorbid c.BLOODPT ///
                c.mxaisbr_HeadNeck c.mxaisbr_Extremities c.mxaisbr_Chest c.mxaisbr_Abdomen c.maxais i.STATE i.year_fe AMI_EVER_ind ///
                ALZH_EVER_ind ALZH_DEMEN_EVER_ind ATRIAL_FIB_EVER_ind CATARACT_EVER_ind CHRONICKIDNEY_EVER_ind COPD_EVER_ind CHF_EVER_ind ///
                DIABETES_EVER_ind GLAUCOMA_EVER_ind ISCHEMICHEART_EVER_ind DEPRESSION_EVER_ind OSTEOPOROSIS_EVER_ind ///
                RA_OA_EVER_ind STROKE_TIA_EVER_ind CANCER_BREAST_EVER_ind CANCER_COLORECTAL_EVER_ind CANCER_PROSTATE_EVER_ind CANCER_LUNG_EVER_ind ///
                CANCER_ENDOMETRIAL_EVER_ind ANEMIA_EVER_ind ASTHMA_EVER_ind HYPERL_EVER_ind HYPERP_EVER_ind HYPERT_EVER_ind HYPOTH_EVER_ind ///
                MULSCL_MEDICARE_EVER_ind OBESITY_MEDICARE_EVER_ind EPILEP_MEDICARE_EVER_ind median_hh_inc_ln pvrty fem_cty eld_cty ///
                ib0.metro_micro_cnty cllge gen_md med_cty full_dual_ind SH_ind EH_ind NH_ind RH_ind /* can't add in amb or treatment since the outcomes are both amb and treatment */
            }
        }

        *____________ Step 2: Predict Propensity score ________________*

        * Step 2 predict for each bene
        predict propensity_score

        *____________ Step 3: Determine the weights ________________*

        * Step 3 Generate weights

        *--- "Main Effect" ---*

        if inlist("`a'","l1_v_nt"){
            gen weights = .
            replace weights = propensity_score if treatment == 0
            replace weights = 1-propensity_score if treatment == 1
        }
        else if inlist("`a'","als_v_bls"){
            gen weights = .
            replace weights = propensity_score if als_ind == 0
            replace weights = 1-propensity_score if als_ind == 1
        }

        *--- "Interaction Effect" ---*

        else{

            /* In the script below, "higher" means level 1/als, nt/als, or level 1/bls. Will use this column when generating overlap weights since the "treatment" is the "higher" category */

            if inlist("`a'","l1_als_v_bls"){
                gen higher = 0
                replace higher = 1 if (TRAUMA_LEVEL == 1) & (amb_type==2)
            }

            else if inlist("`a'","nt_als_v_bls"){
                gen higher = 0
                replace higher = 1 if (TRAUMA_LEVEL == 6) & (amb_type==2)
            }

            else if inlist("`a'","als_l1_v_nt"){
                gen higher = 0
                replace higher = 1 if (TRAUMA_LEVEL == 1) & (amb_type==2)
            }

            else if inlist("`a'","bls_l1_v_nt"){
                gen higher = 0
                replace higher = 1 if (TRAUMA_LEVEL == 1) & (amb_type==1)
            }

            gen weights = .
            replace weights = propensity_score if higher == 0
            replace weights = 1-propensity_score if higher == 1
        }

        *____________ Step 4: Check Balance after weighting ________________*

        if inlist("`m'","mile"){ /* Check balance only for model with mile binary but the model w/o mile variable was also balanced */

            * Create list named covariates
            local covariates niss riss AGE comorbid female white black other_n asian_pi hispanic BLOODPT m_hh_inc pvrty fem_cty eld_cty metro cllge gen_md med_cty cc_cnt

            * Create macro to loop (i.e. control vs treatment group)
            local group_type 0 1

            foreach b of local group_type{

                * Store the sample size
                if inlist("`a'","l1_v_nt"){
                    tab treatment if treatment==`b'
                    local `a'`b'_n = string(`r(N)')
                }
                else if inlist("`a'","als_v_bls"){
                    tab als_ind if als_ind==`b'
                    local `a'`b'_n = string(`r(N)')
                }
                else{
                    tab outcome_binary if outcome_binary==`b'
                    local `a'`b'_n = string(`r(N)')
                }

                * Loop through each covariate to check mean and if there is statistically significant differences between the two groups (lvl1 and lvl2)
                foreach c of local covariates{

                    * Check summary with weights
                    if inlist("`a'","l1_v_nt"){
                        sum `c' [aw=weights] if treatment==`b'
                    }
                    else if inlist("`a'","als_v_bls"){
                        sum `c' [aw=weights] if als_ind==`b'
                    }
                    else{
                        sum `c' [aw=weights] if outcome_binary==`b'
                    }

                    * Save the means of the treatment and control groups to put into excel sheet
                    if inlist("`c'","female","white", "black", "other_n", "asian_pi", "hispanic")|inlist("`c'","pvrty", "fem_cty", "eld_cty", "metro", "cllge", "gen_md", "med_cty"){ /* use conditional function to convert these to percents. Also need to use two inlist functions separated with "|" to bypass error "Expression too long" */
                        local `a'`c'`b'_m = string(`r(mean)'*100,"%9.1f") /* Save macro for treatment group's mean and keep decimal at tenth place. "tn" is treatment group's mean before weighting. Multiply by 100 to convert to percent */
                    }
                    else{ /* While the above requires conversion to percents, other variables like niss or AGE do not */
                        local `a'`c'`b'_m = string(`r(mean)',"%9.1f") /* Save macro for treatment group's mean and keep decimal at tenth place. "tn" is treatment group's mean before weighting. Multiply by 100 to convert to percent */
                    }
                }
            }
        }

        *____________ Step 5: Run analysis without weights [unadjusted] and with weights [adjusted] ________________*

        /* In the script below, "binary" means level 1, als, level 1/als, nt/als, or level 1/bls. Will use this column when running analysis with overlap weights. This is similar to the "higher" variable above. */

        if "`a'" == "nt_als_v_bls"{
            gen binary = 0
            replace binary = 1 if (inlist(TRAUMA_LEVEL,6) & inlist(amb_type,2))
        }

        else if "`a'" == "l1_als_v_bls"{
            gen binary = 0
            replace binary = 1 if (inlist(TRAUMA_LEVEL,1) & inlist(amb_type,2))
        }

        else if "`a'" == "als_l1_v_nt"{
            gen binary = 0
            replace binary = 1 if (inlist(TRAUMA_LEVEL,1) & inlist(amb_type,2))
        }

        else if "`a'" == "bls_l1_v_nt"{
            gen binary = 0
            replace binary = 1 if (inlist(TRAUMA_LEVEL,1) & inlist(amb_type,1))
        }

        else if "`a'" == "l1_v_nt"{
            gen binary = 0
            replace binary = 1 if (inlist(TRAUMA_LEVEL,1))
        }

        else if "`a'" == "als_v_bls"{
            gen binary = 0
            replace binary = 1 if (inlist(amb_type,2))
        }

        * Drop last three months since we will work with thirty day death
        drop if SRVC_BGN_DT >= mdyhms(12, 01, 2017, 0, 0, 0) /* To use 30 day death, need to drop last 30 days (Dec 2017) */

        * Unadjusted: Regress (last month should have been dropped already)
        reg thirty_day_death_ind binary

        * Put into macros
        matrix list r(table) /* View regression result from thirty day death as a table */
        matrix reg_table = r(table) /* Put matrix in table labeled reg_table */
        local `a'_cu = string(_b[binary]*100,"%9.2f")
        local `a'_pu = reg_table[4,1]
        local `a'_conu = string(_b[_cons]*100,"%9.2f")

        * Adjusted: Regress (last month should have been dropped already)
        reg thirty_day_death_ind binary [pweight=weights]

        * Put into macros
        matrix list r(table) /* View regression result from thirty day death as a table */
        matrix reg_table = r(table) /* Put matrix in table labeled reg_table */
        local `m'_`a'_c = string(_b[binary]*100,"%9.2f")
        local `m'_`a'_p = reg_table[4,1]
        local `m'_`a'_con = string(_b[_cons]*100,"%9.2f")

        use `og_hos_file',clear

    }

}


*---------- CREATE BALANCE TABLE FOR EXCEL (BEFORE AND AFTER WEIGHTING) ------------*

local diff_group nt_als_v_bls l1_als_v_bls als_l1_v_nt bls_l1_v_nt l1_v_nt als_v_bls

foreach a of local diff_group{

    noisily di "Create table for `a'"

    * Set file name for excel sheet with replace option
    if inlist("`a'", "nt_als_v_bls"){ /* if first group then replace */
        putexcel set "tab_char_no_labels_pscore.xlsx", sheet("bal_tab_`a'") replace
    }
    else{ /* if not all hospital sample, then simply modify the existing excel sheet */
        putexcel set "tab_char_no_labels_pscore.xlsx", sheet("bal_tab_`a'") modify
    }

    putexcel A1 = "``a'AGE0_m'"
    putexcel B1 = "``a'AGE1_m'"

    putexcel A2 = "``a'female0_m'"
    putexcel B2 = "``a'female1_m'"

    putexcel A4 = "``a'white0_m'"
    putexcel B4 = "``a'white1_m'"

    putexcel A5 = "``a'black0_m'"
    putexcel B5 = "``a'black1_m'"

    putexcel A6 = "``a'other_n0_m'"
    putexcel B6 = "``a'other_n1_m'"

    putexcel A7 = "``a'asian_pi0_m'"
    putexcel B7 = "``a'asian_pi1_m'"

    putexcel A8 = "``a'hispanic0_m'"
    putexcel B8 = "``a'hispanic1_m'"

    putexcel A9 = "``a'cc_cnt0_m'"
    putexcel B9 = "``a'cc_cnt1_m'"

    putexcel A10 = "``a'comorbid0_m'"
    putexcel B10 = "``a'comorbid1_m'"

    putexcel A11 = "``a'niss0_m'"
    putexcel B11 = "``a'niss1_m'"

    putexcel A12 = "``a'riss0_m'"
    putexcel B12 = "``a'riss1_m'"

    putexcel A13 = "``a'BLOODPT0_m'"
    putexcel B13 = "``a'BLOODPT1_m'"

    putexcel A14 = "``a'm_hh_inc0_m'"
    putexcel B14 = "``a'm_hh_inc1_m'"

    putexcel A16 = "``a'pvrty0_m'"
    putexcel B16 = "``a'pvrty1_m'"

    putexcel A17 = "``a'fem_cty0_m'"
    putexcel B17 = "``a'fem_cty1_m'"

    putexcel A18 = "``a'eld_cty0_m'"
    putexcel B18 = "``a'eld_cty1_m'"

    putexcel A19 = "``a'metro0_m'"
    putexcel B19 = "``a'metro1_m'"

    putexcel A20 = "``a'cllge0_m'"
    putexcel B20 = "``a'cllge1_m'"

    putexcel A21 = "``a'gen_md0_m'"
    putexcel B21 = "``a'gen_md1_m'"

    putexcel A22 = "``a'med_cty0_m'"
    putexcel B22 = "``a'med_cty1_m'"

    putexcel A24 = "``a'0_n'"
    putexcel B24 = "``a'1_n'"

}


*---------- CREATE PART OF EXHIBIT 3 FOR EXCEL (BEFORE AND AFTER WEIGHTING) ------------*
* Only has results from pscore. For results from regression, see script 24_regression_analysis

noisily di "Creating table for pscore results"

* Set file name for excel sheet with modify option to create new table to store the balance tables
putexcel set "tab_char_no_labels_pscore.xlsx", sheet("exhibit_3_adjusted") modify

* - - - Main effect: L1 vs NT W/ Miles but without ambulance (adjusted) - - - #

if `mile_l1_v_nt_p' < 0.001{ /* if significant, put asterisk */
putexcel (A2:E2) = "`mile_l1_v_nt_c'***", merge hcenter vcenter
}
else if `mile_l1_v_nt_p' < 0.01{ /* if significant, put asterisk */
putexcel (A2:E2) = "`mile_l1_v_nt_c'**", merge hcenter vcenter
}
else if `mile_l1_v_nt_p' < 0.05{ /* if significant, put asterisk */
putexcel (A2:E2) = "`mile_l1_v_nt_c'*", merge hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel (A2:E2) = "`mile_l1_v_nt_c'", merge hcenter vcenter
}

* - - - Main effect: ALS vs BLS W/ Miles but without trauma center (adjusted) - - - #

if `mile_als_v_bls_p' < 0.001{ /* if significant, put asterisk */
putexcel (G2:K2) = "`mile_als_v_bls_c'***", merge hcenter vcenter
}
else if `mile_als_v_bls_p' < 0.01{ /* if significant, put asterisk */
putexcel (G2:K2) = "`mile_als_v_bls_c'**", merge hcenter vcenter
}
else if `mile_als_v_bls_p' < 0.05{ /* if significant, put asterisk */
putexcel (G2:K2) = "`mile_als_v_bls_c'*", merge hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel (G2:K2) = "`mile_als_v_bls_c'", merge hcenter vcenter
}

* - - - Interaction Effect: Without Miles (adjusted) - - - *

putexcel A8 = "`no_mile_l1_als_v_bls_con'"

if `no_mile_l1_als_v_bls_p' < 0.001{ /* if significant, put asterisk */
putexcel B8 = "`no_mile_l1_als_v_bls_c'***"
}
else if `no_mile_l1_als_v_bls_p' < 0.01{ /* if significant, put asterisk */
putexcel B8 = "`no_mile_l1_als_v_bls_c'**"
}
else if `no_mile_l1_als_v_bls_p' < 0.05{ /* if significant, put asterisk */
putexcel B8 = "`no_mile_l1_als_v_bls_c'*"
}
else{ /* if NOT significant, omit asterisk */
putexcel B8 = "`no_mile_l1_als_v_bls_c'"
}

putexcel D8 = "`no_mile_nt_als_v_bls_con'"

if `no_mile_nt_als_v_bls_p' < 0.001{ /* if significant, put asterisk */
putexcel E8 = "`no_mile_nt_als_v_bls_c'***"
}
else if `no_mile_nt_als_v_bls_p' < 0.01{ /* if significant, put asterisk */
putexcel E8 = "`no_mile_nt_als_v_bls_c'**"
}
else if `no_mile_nt_als_v_bls_p' < 0.05{ /* if significant, put asterisk */
putexcel E8 = "`no_mile_nt_als_v_bls_c'*"
}
else{ /* if NOT significant, omit asterisk */
putexcel E8 = "`no_mile_nt_als_v_bls_c'"
}

putexcel G8 = "`no_mile_als_l1_v_nt_con'"

if `no_mile_als_l1_v_nt_p' < 0.001{ /* if significant, put asterisk */
putexcel H8 = "`no_mile_als_l1_v_nt_c'***"
}
else if `no_mile_als_l1_v_nt_p' < 0.01{ /* if significant, put asterisk */
putexcel H8 = "`no_mile_als_l1_v_nt_c'**"
}
else if `no_mile_als_l1_v_nt_p' < 0.05{ /* if significant, put asterisk */
putexcel H8 = "`no_mile_als_l1_v_nt_c'*"
}
else{ /* if NOT significant, omit asterisk */
putexcel H8 = "`no_mile_als_l1_v_nt_c'"
}

putexcel J8 = "`no_mile_bls_l1_v_nt_con'"

if `no_mile_bls_l1_v_nt_p' < 0.001{ /* if significant, put asterisk */
putexcel K8 = "`no_mile_bls_l1_v_nt_c'***"
}
else if `no_mile_bls_l1_v_nt_p' < 0.01{ /* if significant, put asterisk */
putexcel K8 = "`no_mile_bls_l1_v_nt_c'**"
}
else if `no_mile_bls_l1_v_nt_p' < 0.05{ /* if significant, put asterisk */
putexcel K8 = "`no_mile_bls_l1_v_nt_c'*"
}
else{ /* if NOT significant, omit asterisk */
putexcel K8 = "`no_mile_bls_l1_v_nt_c'"
}

* - - - Interaction Effect: With Miles (adjusted) - - - *

putexcel A10 = "`mile_l1_als_v_bls_con'"

if `mile_l1_als_v_bls_p' < 0.001{ /* if significant, put asterisk */
putexcel B10 = "`mile_l1_als_v_bls_c'***"
}
else if `mile_l1_als_v_bls_p' < 0.01{ /* if significant, put asterisk */
putexcel B10 = "`mile_l1_als_v_bls_c'**"
}
else if `mile_l1_als_v_bls_p' < 0.05{ /* if significant, put asterisk */
putexcel B10 = "`mile_l1_als_v_bls_c'*"
}
else{ /* if NOT significant, omit asterisk */
putexcel B10 = "`mile_l1_als_v_bls_c'"
}

putexcel D10 = "`mile_nt_als_v_bls_con'"

if `mile_nt_als_v_bls_p' < 0.001{ /* if significant, put asterisk */
putexcel E10 = "`mile_nt_als_v_bls_c'***"
}
else if `mile_nt_als_v_bls_p' < 0.01{ /* if significant, put asterisk */
putexcel E10 = "`mile_nt_als_v_bls_c'**"
}
else if `mile_nt_als_v_bls_p' < 0.05{ /* if significant, put asterisk */
putexcel E10 = "`mile_nt_als_v_bls_c'*"
}
else{ /* if NOT significant, omit asterisk */
putexcel E10 = "`mile_nt_als_v_bls_c'"
}

putexcel G10 = "`mile_als_l1_v_nt_con'"

if `mile_als_l1_v_nt_p' < 0.001{ /* if significant, put asterisk */
putexcel H10 = "`mile_als_l1_v_nt_c'***"
}
else if `mile_als_l1_v_nt_p' < 0.01{ /* if significant, put asterisk */
putexcel H10 = "`mile_als_l1_v_nt_c'**"
}
else if `mile_als_l1_v_nt_p' < 0.05{ /* if significant, put asterisk */
putexcel H10 = "`mile_als_l1_v_nt_c'*"
}
else{ /* if NOT significant, omit asterisk */
putexcel H10 = "`mile_als_l1_v_nt_c'"
}

putexcel J10 = "`mile_bls_l1_v_nt_con'"

if `mile_bls_l1_v_nt_p' < 0.001{ /* if significant, put asterisk */
putexcel K10 = "`mile_bls_l1_v_nt_c'***"
}
else if `mile_bls_l1_v_nt_p' < 0.01{ /* if significant, put asterisk */
putexcel K10 = "`mile_bls_l1_v_nt_c'**"
}
else if `mile_bls_l1_v_nt_p' < 0.05{ /* if significant, put asterisk */
putexcel K10 = "`mile_bls_l1_v_nt_c'*"
}
else{ /* if NOT significant, omit asterisk */
putexcel K10 = "`mile_bls_l1_v_nt_c'"
}

* Set file name for excel sheet with modify option to create new table to store the balance tables
putexcel set "tab_char_no_labels_pscore.xlsx", sheet("exhibit_3_unadjusted") modify

* - - - Main effect: L1 vs NT (unadjusted) - - - #

if `l1_v_nt_pu' < 0.001{ /* if significant, put asterisk */
putexcel (A2:E2) = "`l1_v_nt_cu'***", merge hcenter vcenter
}
else if `l1_v_nt_pu' < 0.01{ /* if significant, put asterisk */
putexcel (A2:E2) = "`l1_v_nt_cu'**", merge hcenter vcenter
}
else if `l1_v_nt_pu' < 0.05{ /* if significant, put asterisk */
putexcel (A2:E2) = "`l1_v_nt_cu'*", merge hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel (A2:E2) = "`l1_v_nt_cu'", merge hcenter vcenter
}

* - - - Main effect: ALS vs BLS (unadjusted) - - - #

if `als_v_bls_pu' < 0.001{ /* if significant, put asterisk */
putexcel (G2:K2) = "`als_v_bls_cu'***", merge hcenter vcenter
}
else if `als_v_bls_pu' < 0.01{ /* if significant, put asterisk */
putexcel (G2:K2) = "`als_v_bls_cu'**", merge hcenter vcenter
}
else if `als_v_bls_pu' < 0.05{ /* if significant, put asterisk */
putexcel (G2:K2) = "`als_v_bls_cu'*", merge hcenter vcenter
}
else{ /* if NOT significant, omit asterisk */
putexcel (G2:K2) = "`als_v_bls_cu'", merge hcenter vcenter
}

* - - - Interaction Effect (unadjusted) - - - *

putexcel A8 = "`l1_als_v_bls_conu'"

if `l1_als_v_bls_pu' < 0.001{ /* if significant, put asterisk */
putexcel B8 = "`l1_als_v_bls_cu'***"
}
else if `l1_als_v_bls_pu' < 0.01{ /* if significant, put asterisk */
putexcel B8 = "`l1_als_v_bls_cu'**"
}
else if `l1_als_v_bls_pu' < 0.05{ /* if significant, put asterisk */
putexcel B8 = "`l1_als_v_bls_cu'*"
}
else{ /* if NOT significant, omit asterisk */
putexcel B8 = "`l1_als_v_bls_cu'"
}

putexcel D8 = "`nt_als_v_bls_conu'"

if `nt_als_v_bls_pu' < 0.001{ /* if significant, put asterisk */
putexcel E8 = "`nt_als_v_bls_cu'***"
}
else if `nt_als_v_bls_pu' < 0.01{ /* if significant, put asterisk */
putexcel E8 = "`nt_als_v_bls_cu'**"
}
else if `nt_als_v_bls_pu' < 0.05{ /* if significant, put asterisk */
putexcel E8 = "`nt_als_v_bls_cu'*"
}
else{ /* if NOT significant, omit asterisk */
putexcel E8 = "`nt_als_v_bls_cu'"
}

putexcel G8 = "`als_l1_v_nt_conu'"

if `als_l1_v_nt_pu' < 0.001{ /* if significant, put asterisk */
putexcel H8 = "`als_l1_v_nt_cu'***"
}
else if `als_l1_v_nt_pu' < 0.01{ /* if significant, put asterisk */
putexcel H8 = "`als_l1_v_nt_cu'**"
}
else if `als_l1_v_nt_pu' < 0.05{ /* if significant, put asterisk */
putexcel H8 = "`als_l1_v_nt_cu'*"
}
else{ /* if NOT significant, omit asterisk */
putexcel H8 = "`als_l1_v_nt_cu'"
}

putexcel J8 = "`bls_l1_v_nt_conu'"

if `bls_l1_v_nt_pu' < 0.001{ /* if significant, put asterisk */
putexcel K8 = "`bls_l1_v_nt_cu'***"
}
else if `bls_l1_v_nt_pu' < 0.01{ /* if significant, put asterisk */
putexcel K8 = "`bls_l1_v_nt_cu'**"
}
else if `bls_l1_v_nt_pu' < 0.05{ /* if significant, put asterisk */
putexcel K8 = "`bls_l1_v_nt_cu'*"
}
else{ /* if NOT significant, omit asterisk */
putexcel K8 = "`bls_l1_v_nt_cu'"
}

* scp jessyjkn@phs-rs24.bsd.uchicago.edu:/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/merged_ats_claims_for_stata/tab_char_no_labels_pscore.xlsx /Users/jessyjkn/Desktop/Job/Data/trauma_center_project/regression_results



}
