#----------------------------------------------------------------------------------------------------------------------#
# Project: (REG) Trauma center analysis using Medicare data
# Author: Jessy Nguyen
# Last Updated: February 8, 2023
# Description: The script will create indicator for two area types: choice and no choice. Choice = hospital destination
# with at least one surrounding hospital of the opposite type; No choice = hospital destination with no surrounding
# hospitals.
#----------------------------------------------------------------------------------------------------------------------#

############################################# IMPORT MODULES ###########################################################

# Read in relevant libraries
from datetime import datetime, timedelta
import pandas as pd
import numpy as np

######################################### REDUCE DF FROM CARTESIAN MERGE ###############################################
# Data created from script 20 is large. This section will take that dataset and reduce it. The resulting subset will be used
# to help identify hospitals in "choice" vs "no choice"

#____ For Choice: keep if less than 30 miles ___#

# Define columns
columns = ['MCRNUM','TRAUMA_LEVEL','MCRNUM_b','TRAUMA_LEVEL_b','distance']

# Read in dataset
hos_w_distance = pd.read_csv('/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/hos_w_dist_long_lat/hos_distance_2017.csv',dtype=str,usecols=columns) # use dtype=str because some columns have mix dtypes

# Convert to float
hos_w_distance['distance'] = hos_w_distance['distance'].astype(float)

# Keep if distance is less than 30 miles and the two hospitals are different
hos_w_distance = hos_w_distance[(hos_w_distance['distance']<=30)&(hos_w_distance['MCRNUM']!=hos_w_distance['MCRNUM_b'])]

# For duplicated provider ID, sort by trauma level so that higher trauma level is at the top
hos_w_distance = hos_w_distance.sort_values(by=['TRAUMA_LEVEL'], ascending=True)

# Drop duplicates and keep the first one (i.e. keep the higher trauma level. Reasoning: I manually search some of them and the higher level is the most up-to-date)
hos_w_distance = hos_w_distance.drop_duplicates(subset=['MCRNUM','MCRNUM_b'],keep='first') # subset on both mcrnum and mcrnum_b to keep the first and second destination. If I only subset on mcrnum, then I would lose all of the second destinations.

# Read out
hos_w_distance.to_csv(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/hos_w_dist_long_lat/hos_distance_subset.csv',index=False)

#____ For No Choice: keep if different hospital types ___#

# Define columns
columns = ['MCRNUM','distance','MCRNUM_b']

# Read in same dataset as above
hos_w_distance = pd.read_csv('/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/hos_w_dist_long_lat/hos_distance_2017.csv',dtype=str,usecols=columns) # use dtype=str because some columns have mix dtypes

# Convert to float
hos_w_distance['distance'] = hos_w_distance['distance'].astype(float)

# Keep if the two trauma levels are different
hos_w_distance = hos_w_distance[(hos_w_distance['MCRNUM']!=hos_w_distance['MCRNUM_b'])]

# Read out
hos_w_distance.to_csv(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/hos_w_dist_long_lat/hos_distance_subset_nochoice.csv',index=False)

#################################### KEEP ONLY HOSPITALS FROM MY ANALYTICAL SAMPLE #####################################
# Goal is to keep hospitals from hos_distance_subset (choice only) that are present from my analytical sample.

# Read in analytical sample
final_matched_claims_allyears = pd.read_stata('/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/merged_ats_claims_for_stata/final_matched_claims_allyears_w_hos_qual.dta',columns=['PRVDR_NUM','less_than_90_bene_served'])
final_unmatched_claims_allyears = pd.read_stata('/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/merged_ats_claims_for_stata/final_unmatched_claims_allyears_w_hos_qual.dta',columns=['PRVDR_NUM','less_than_90_bene_served'])

# Keep on those that serve 90 plus major trauma benes in a year
final_matched_claims_allyears=final_matched_claims_allyears[final_matched_claims_allyears['less_than_90_bene_served']!=1]
final_unmatched_claims_allyears=final_unmatched_claims_allyears[final_unmatched_claims_allyears['less_than_90_bene_served']!=1]

# Concat
concat_df = pd.concat([final_matched_claims_allyears,final_unmatched_claims_allyears],axis=0)

# Put provider id in list
list_analytical = concat_df['PRVDR_NUM'].to_list()

# Recover memory
del final_unmatched_claims_allyears
del final_matched_claims_allyears
del concat_df

# Read in hospital with distance information data
hos_w_distance_30mi = pd.read_csv(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/hos_w_dist_long_lat/hos_distance_subset.csv',dtype=str)
    # Note that this df only contains pairs of hospitals that are within 30 miles of each other

# Keep if in hospital is from analytical sample
hos_w_distance_analytical_only = hos_w_distance_30mi[(hos_w_distance_30mi['MCRNUM'].isin(list_analytical))&(hos_w_distance_30mi['MCRNUM_b'].isin(list_analytical))]

# Read out
hos_w_distance_analytical_only.to_csv(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/hos_w_dist_long_lat/hos_distance_analytical_only.csv',index=False)


##################################### CREATE DATASET WITH VARYING MILE RADIUS ##########################################
# Goal is to create "choice" and "no choice" area types. E.g. two hospitals within 3-mile radius (choice) and an isolated
# hospital within 3-mile radius (no choice)

#___ Prepare data for choice ___#

# Read in hospital dataset with distance below 30 miles that contains only bene's from analytical sample AND convert distance to float
hos_w_distance = pd.read_csv(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/hos_w_dist_long_lat/hos_distance_analytical_only.csv',usecols=['distance', 'TRAUMA_LEVEL', 'TRAUMA_LEVEL_b', 'MCRNUM', 'MCRNUM_b'],dtype=str)
hos_w_distance['distance'] = hos_w_distance['distance'].astype(float) # Convert to float

# Read in final analytical claims with only patid and PRVDR_NUM to crosswalk
final_matched_claims_allyears = pd.read_stata('/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/merged_ats_claims_for_stata/final_matched_claims_allyears_w_hos_qual.dta',columns=['patid','PRVDR_NUM'])
final_unmatched_claims_allyears = pd.read_stata('/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/merged_ats_claims_for_stata/final_unmatched_claims_allyears_w_hos_qual.dta',columns=['patid','PRVDR_NUM'])

# Concat
concat_df = pd.concat([final_matched_claims_allyears,final_unmatched_claims_allyears],axis=0)
del final_matched_claims_allyears
del final_unmatched_claims_allyears

# Obtain patid from concat_df
merge_df = pd.merge(hos_w_distance,concat_df,left_on=['MCRNUM'],right_on=['PRVDR_NUM'],how='inner')
del hos_w_distance
del concat_df

#___ Prepare data for no choice ___#

# Read in
hos_w_distance_nochoice = pd.read_csv(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/hos_w_dist_long_lat/hos_distance_subset_nochoice.csv',dtype=str,usecols=['distance', 'MCRNUM'])
hos_w_distance_nochoice['distance'] = hos_w_distance_nochoice['distance'].astype(float)
    # Will be used to help identify hospitals that do not have any other hospitals surrounding it

# Read in final analytical claims file with all columns. Will match on newly obtained patid
final_matched_claims_allyears = pd.read_stata('/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/merged_ats_claims_for_stata/final_matched_claims_allyears_w_hos_qual.dta')
final_unmatched_claims_allyears = pd.read_stata('/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/merged_ats_claims_for_stata/final_unmatched_claims_allyears_w_hos_qual.dta')

# Create list
miles_list = [x * 0.5 for x in range(2, 20)]

for m in miles_list:

    #___ Create choice (begin) ___#
    # Keep if distance is less than m miles, the two trauma levels are different, and it's only lvl 1 and non-trauma
    subset_merge_df = merge_df[(merge_df['distance']<=m)&(merge_df['TRAUMA_LEVEL']!=merge_df['TRAUMA_LEVEL_b'])&(merge_df['TRAUMA_LEVEL'].isin(['1','6']))&(merge_df['TRAUMA_LEVEL_b'].isin(['1','6']))] # 6 is nontrauma

    # Keep only relevant columns. Now this DF contains claims that have another hospital within m miles.
    subset_merge_df = subset_merge_df[['patid']]

    # Drop duplicated patid
    subset_merge_df = subset_merge_df.drop_duplicates(subset=['patid'],keep='first')

    # Create choice indicator column (e.g. choice_ind_mi5_5 or choice_ind_mi5 is at least one different hospital within 5.5 or 5 miles respectively)
    if str(m).endswith('.5'):
        subset_merge_df[f'choice_ind_mi{str(m)[0]}_5'] = 1 # take first digit. need to do this because stata doesn't take decimals as variable names
    else:
        subset_merge_df[f'choice_ind_mi{int(m)}'] = 1

    # Merge left
    final_matched_claims_allyears = pd.merge(final_matched_claims_allyears,subset_merge_df,on=['patid'],how='left')
    final_unmatched_claims_allyears = pd.merge(final_unmatched_claims_allyears,subset_merge_df,on=['patid'],how='left')
    del subset_merge_df

    # Replace nan with 0
    if str(m).endswith('.5'):
        final_matched_claims_allyears.loc[final_matched_claims_allyears[f'choice_ind_mi{str(m)[0]}_5']!=1,f'choice_ind_mi{str(m)[0]}_5'] = 0 # the str(m)[0] would grab the first character and convert to string. This is necessary since decimals in a column name will generate an error.
        final_unmatched_claims_allyears.loc[final_unmatched_claims_allyears[f'choice_ind_mi{str(m)[0]}_5']!=1,f'choice_ind_mi{str(m)[0]}_5'] = 0
    else:
        final_matched_claims_allyears.loc[final_matched_claims_allyears[f'choice_ind_mi{int(m)}']!=1,f'choice_ind_mi{int(m)}'] = 0
        final_unmatched_claims_allyears.loc[final_unmatched_claims_allyears[f'choice_ind_mi{int(m)}']!=1,f'choice_ind_mi{int(m)}'] = 0
    #___ Create choice (end) ___#

    #___ Create no choice (begin) ___#

    hos_with_another_hos_list = hos_w_distance_nochoice[(hos_w_distance_nochoice['distance']<=m)]['MCRNUM'].to_list() # put into list the provider id of any hospitals that have another hospital within m miles
    list_to_keep = hos_w_distance_nochoice[~(hos_w_distance_nochoice['MCRNUM'].isin(hos_with_another_hos_list))]['MCRNUM'].to_list() # take same hos_w_distance_nochoice df and drop all hospital if another hospital is within m miles
        # The remaining hospitals are those that do not have any hospitals within that m mile

    # Keep the hospitals from list from main analytical sample
    match_no_hos_nearby = final_matched_claims_allyears[final_matched_claims_allyears['PRVDR_NUM'].isin(list_to_keep)]
    unmatch_no_hos_nearby = final_unmatched_claims_allyears[final_unmatched_claims_allyears['PRVDR_NUM'].isin(list_to_keep)]

    # Keep relevant columns
    match_no_hos_nearby = match_no_hos_nearby[['patid']]
    unmatch_no_hos_nearby = unmatch_no_hos_nearby[['patid']]

    # Create no choice indicator (e.g. only_hos_at_mi5_5 or only_hos_at_mi5 is no hospital within 5.5 or 5 miles respectively)
    if str(m).endswith('.5'):
        match_no_hos_nearby[f'only_hos_at_mi{str(m)[0]}_5'] = 1  # the str(m)[0] would grab the first character and convert to string. This is necessary since decimals in a column name will generate an error.
        unmatch_no_hos_nearby[f'only_hos_at_mi{str(m)[0]}_5'] = 1
    else:
        match_no_hos_nearby[f'only_hos_at_mi{int(m)}'] = 1
        unmatch_no_hos_nearby[f'only_hos_at_mi{int(m)}'] = 1

    # # CHECK no choice: as you go higher radius, number of hospitals should decrease
    # if str(m).endswith('.5'):
    #     print(f'{m}', match_no_hos_nearby[f'only_hos_at_mi{str(m)[0]}_5'].sum())
    #     print(f'{m}', match_no_hos_nearby.shape[0])
    #     print(f'{m}', unmatch_no_hos_nearby[f'only_hos_at_mi{str(m)[0]}_5'].sum())
    #     print(f'{m}', unmatch_no_hos_nearby.shape[0])
    # else:
    #     print(f'{m}', match_no_hos_nearby[f'only_hos_at_mi{int(m)}'].sum())
    #     print(f'{m}', match_no_hos_nearby.shape[0])
    #     print(f'{m}', unmatch_no_hos_nearby[f'only_hos_at_mi{int(m)}'].sum())
    #     print(f'{m}', unmatch_no_hos_nearby.shape[0])

    # Merge left
    final_matched_claims_allyears = pd.merge(final_matched_claims_allyears,match_no_hos_nearby,on=['patid'],how='left')
    final_unmatched_claims_allyears = pd.merge(final_unmatched_claims_allyears,unmatch_no_hos_nearby,on=['patid'],how='left')

    # replace nan with 0
    if str(m).endswith('.5'):
        final_matched_claims_allyears.loc[final_matched_claims_allyears[f'only_hos_at_mi{str(m)[0]}_5']!=1,f'only_hos_at_mi{str(m)[0]}_5'] = 0
        final_unmatched_claims_allyears.loc[final_unmatched_claims_allyears[f'only_hos_at_mi{str(m)[0]}_5']!=1,f'only_hos_at_mi{str(m)[0]}_5'] = 0
    else:
        final_matched_claims_allyears.loc[final_matched_claims_allyears[f'only_hos_at_mi{int(m)}']!=1,f'only_hos_at_mi{int(m)}'] = 0
        final_unmatched_claims_allyears.loc[final_unmatched_claims_allyears[f'only_hos_at_mi{int(m)}']!=1,f'only_hos_at_mi{int(m)}'] = 0
    #___ Create no choice (end) ___#

# Replace nan with 0 for the amb_ind column
final_matched_claims_allyears.loc[final_matched_claims_allyears['amb_ind']!=1,'amb_ind'] = 0
final_unmatched_claims_allyears.loc[final_unmatched_claims_allyears['amb_ind']!=1,'amb_ind'] = 0

# Read out data to stata
final_matched_claims_allyears.to_stata(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/merged_ats_claims_for_stata/final_matched_allyears_w_hos_qual_n_choice_anltcl_1nt.dta',write_index=False)
final_unmatched_claims_allyears.to_stata(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/merged_ats_claims_for_stata/final_unmatched_allyears_w_hos_qual_n_choice_anltcl_1nt.dta',write_index=False)






















