#----------------------------------------------------------------------------------------------------------------------#
# Project: (REG) Trauma center analysis using Medicare data
# Author: Jessy Nguyen
# Last Updated: February 8, 2023
# Description: The script will obtain additional columns relating to DX codes and population parameters
#----------------------------------------------------------------------------------------------------------------------#

############################################# IMPORT MODULES ###########################################################

# Read in relevant libraries
from datetime import datetime, timedelta
import pandas as pd
import numpy as np

########################################################################################################################

# Read in data with choice and no choice indicators
final_matched_claims_allyears = pd.read_stata('/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/merged_ats_claims_for_stata/final_matched_allyears_w_hos_qual_n_choice_anltcl_1nt.dta')
final_unmatched_claims_allyears = pd.read_stata('/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/merged_ats_claims_for_stata/final_unmatched_allyears_w_hos_qual_n_choice_anltcl_1nt.dta')

print(list(final_matched_claims_allyears.columns))
print(list(final_unmatched_claims_allyears.columns))

# Drop trauma level column from final_unmatched_claims_allyears df
final_unmatched_claims_allyears = final_unmatched_claims_allyears.drop(['TRAUMA_LEVEL'],axis=1)

# Create empty dictionary to store DFs
df_dict = {}

# Define diagnosis columns
diag_col = [f'dx{i}' for i in range(1, 39)]

#____ Count number of dx _____#
# Will be used to create DX distribution figure for main exhibit
# Process time ~ 10 minutes

for m in ['match','unmatch']:

    for i in ['icd9','icd10']:

        #--- Clean and subset data ---#

        if (m in ['match']) and (i in ['icd9']):

            df_dict[i+m] = final_matched_claims_allyears[final_matched_claims_allyears['SRVC_BGN_DT'].dt.year.isin([2011,2012,2013,2014,2015])][['patid']+diag_col] # keep only years with icd9 and relevant columns

            for d in diag_col:
                df_dict[i+m].loc[~df_dict[i+m][f'{d}'].str.startswith(('8','9','E')),f'{d}'] = 'nan' # Replace if dx col is not an injury code

        elif (m in ['unmatch']) and (i in ['icd9']):

            df_dict[i+m] = final_unmatched_claims_allyears[final_unmatched_claims_allyears['SRVC_BGN_DT'].dt.year.isin([2011,2012,2013,2014,2015])][['patid']+diag_col] # keep only years with icd9 and relevant columns

            for d in diag_col:
                df_dict[i+m].loc[~df_dict[i+m][f'{d}'].str.startswith(('8','9','E')),f'{d}'] = 'nan' # Replace if dx is not an injury code

        elif (m in ['match']) and (i in ['icd10']):

            df_dict[i+m] = final_matched_claims_allyears[final_matched_claims_allyears['SRVC_BGN_DT'].dt.year.isin([2016,2017,2018,2019])][['patid']+diag_col] # keep only years with icd9 and relevant columns

            for d in diag_col:
                df_dict[i+m].loc[~df_dict[i+m][f'{d}'].str.startswith(('S','T','V','W','X','Y')),f'{d}'] = 'nan' # Replace if dx is not an injury code

        elif (m in ['unmatch']) and (i in ['icd10']):

            df_dict[i+m] = final_unmatched_claims_allyears[final_unmatched_claims_allyears['SRVC_BGN_DT'].dt.year.isin([2016,2017,2018,2019])][['patid']+diag_col] # keep only years with icd9 and relevant columns

            for d in diag_col:
                df_dict[i+m].loc[~df_dict[i+m][f'{d}'].str.startswith(('S','T','V','W','X','Y')),f'{d}'] = 'nan' # Replace if dx is not an injury code

        df_dict[i+m] = df_dict[i+m].apply(lambda row: pd.Series(row).drop_duplicates(keep='first'),axis='columns')  # drop duplicates across each row

        # --- Count number of unique injury codes ---#

        diag_col_nodup = df_dict[i+m].columns[df_dict[i+m].columns.str.startswith('dx')].tolist()  # to list
        df_dict[i+m]['num_of_diag_codes_nodup'] = df_dict[i+m][(df_dict[i+m] != 'nan')][diag_col_nodup].count(axis='columns')  # Count diagnosis codes (same as doing .count(1))

# Concat icd9 and icd10 df for match and unmatch df
match_w_only_dx = pd.concat([df_dict['icd9match'],df_dict['icd10match']],axis=0)
unmatch_w_only_dx = pd.concat([df_dict['icd9unmatch'],df_dict['icd10unmatch']],axis=0)

# Keep only relevant columns to merge back with analytical sample
match_w_only_dx = match_w_only_dx[['patid','num_of_diag_codes_nodup']]
unmatch_w_only_dx = unmatch_w_only_dx[['patid','num_of_diag_codes_nodup']]

# Merge with analytical
final_matched_claims_allyears = pd.merge(final_matched_claims_allyears,match_w_only_dx,on=['patid'])
final_unmatched_claims_allyears = pd.merge(final_unmatched_claims_allyears,unmatch_w_only_dx,on=['patid'])

#____ Obtain zip from aha data ____#
# Need zip of hospital to obtain county FIPS in the next step

# read in aha data from 2017
trauma_xwalk_df = pd.read_excel(f'/mnt/labshares/sanghavi-lab/data/public_data/data/trauma_center_data/NPINUM_MCRNUM_AHAID_CROSSWALK_2017.xlsx',
    header=3, dtype=str, usecols=['MCRNUM','MLOCZIP'])

# Drop duplicates because multiple hospitals have the same provider id
trauma_xwalk_df = trauma_xwalk_df.drop_duplicates(subset=['MCRNUM'],keep='first')

# Rename
trauma_xwalk_df = trauma_xwalk_df.rename(columns={'MCRNUM':'PRVDR_NUM'})

# Keep only the first five digits from zipcode
trauma_xwalk_df['MLOCZIP'] = trauma_xwalk_df['MLOCZIP'].str[:5]

# Merge with analytical sample to obtain zip
final_matched_claims_allyears_zip = pd.merge(final_matched_claims_allyears,trauma_xwalk_df,how='left',on='PRVDR_NUM')
final_unmatched_claims_allyears_zip = pd.merge(final_unmatched_claims_allyears,trauma_xwalk_df,how='left',on='PRVDR_NUM')

#____ Merge with crosswalk to obtain county FIPS ____#
# Need county FIPS to obtain population count from AHRF data

# read in zip to county fips crosswalk
zip_fips_county_xwalk = pd.read_excel(f'/mnt/labshares/sanghavi-lab/data/public_data/data/zip_to_fips_county_2017/ZIP_COUNTY_122017.xlsx', dtype=str, usecols=['zip','county'])

# Drop duplicates
zip_fips_county_xwalk = zip_fips_county_xwalk.drop_duplicates(subset=['zip'],keep='first')

# Merge with analytical sample on zip obtained above
final_matched_claims_allyears_FIPS = pd.merge(final_matched_claims_allyears_zip,zip_fips_county_xwalk,how='left',left_on='MLOCZIP',right_on='zip')
final_unmatched_claims_allyears_FIPS = pd.merge(final_unmatched_claims_allyears_zip,zip_fips_county_xwalk,how='left',left_on='MLOCZIP',right_on='zip')

#____ Merge with AHRF to obtain population count ___#

# Read in AHRF file
ahrf_df = pd.read_csv('/mnt/labshares/sanghavi-lab/data/public_data/data/AHRF_SAS/ahrf2019.csv', dtype=str,usecols=['f1198415','f00002'])
# F11984-15 : Population Estimate (total 2015)
# F00002 : County FIPS

# Drop duplicates on county fips
ahrf_df = ahrf_df.drop_duplicates(subset=['f00002'],keep='first')

# Convert numeric columns to float
num_list = ['f1198415']
for n in num_list:
    ahrf_df[f'{n}'] = ahrf_df[f'{n}'].astype(float)

# Rename variables according to AHRF 2018-2019 Technical Documentation (see below)
ahrf_df = ahrf_df.rename(
    columns={'f1198415': 'tot_pop_in_cnty',
             'f00002': 'county'}) # 'f12424': 'state_abbr', 'f00010': 'county_name'

# Merge on FIPS code
final_matched_claims_allyears_tot_pop = pd.merge(final_matched_claims_allyears_FIPS, ahrf_df, how='left', on=['county'])
final_unmatched_claims_allyears_tot_pop = pd.merge(final_unmatched_claims_allyears_FIPS, ahrf_df, how='left', on=['county'])

#____ Merge with EPA to obtain traffic proximity data ___#

# Read in data
epa_df = pd.read_csv('/mnt/labshares/sanghavi-lab/data/public_data/data/epa_ejscreen/EJSCREEN_2017_USPR_Public.csv',dtype=str,usecols=['ID','PTRAF','ACSTOTPOP'])
# PTRAF: traffic proximity on block level
# ACSTOTPOP: count of population on block level
# ID: block level ID

# Convert to float
epa_df['PTRAF'] = epa_df['PTRAF'].astype(float)
epa_df['ACSTOTPOP'] = epa_df['ACSTOTPOP'].astype(float)

#--- Merge on census block/tract id ---#

# Read in dataset from cartesian merge between hospital and census block centroid from script 20 (this dataset is a provider id to block level id with the distance measure between hos and block centroid)
hos_w_dist_w_census_100mi = pd.read_csv('/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/hos_w_dist_w_other_census_blocks/2017_w_pd.csv',dtype=str) # use dtype=str because some columns have mix dtypes
hos_w_dist_w_census_100mi['distance'] = hos_w_dist_w_census_100mi['distance'].astype(float)

# Take first 11 numbers which would correspond with the fips block id from the crosswalk. EPA ID length is 12 but the ID from hos_w_dist_w_census_100mi is only 11.
epa_df['GEOID'] = epa_df['ID'].str[:11]

# Group by on tract id and take mean of traffic proximity and population count.
epa_df = epa_df.groupby(['GEOID'])['PTRAF','ACSTOTPOP'].mean().reset_index()

# Merge. Now, the census block has traffic prox and pop count information.
merge_epa_dist = pd.merge(epa_df, hos_w_dist_w_census_100mi, how='right', on=['GEOID'])

# Create list for different mile radius around hospital from 1-9 miles
distance_list = [*range(1,10)]

for d in distance_list:

    # Keep if within d distance of hospital
    distance_d_df = merge_epa_dist[merge_epa_dist['distance']<=d]

    # Group by hospital to find mean if centroid of census block is included in the distance radius (e.g. if d is 3 miles then take mean of all traffic prox and pop count if block's centroid is within 3 miles of hospital)
    distance_d_df = distance_d_df.groupby(['MCRNUM'])['PTRAF','ACSTOTPOP'].mean().reset_index()

    # Rename column
    distance_d_df = distance_d_df.rename(columns={'PTRAF':f'PTRAF_dist{d}','ACSTOTPOP':f'ACSTOTPOP_dist{d}','MCRNUM':'PRVDR_NUM'})

    # Merge with analytical sample
    final_matched_claims_allyears_tot_pop = pd.merge(final_matched_claims_allyears_tot_pop, distance_d_df, how='left',
                                                 on='PRVDR_NUM')
    final_unmatched_claims_allyears_tot_pop = pd.merge(final_unmatched_claims_allyears_tot_pop, distance_d_df, how='left',
                                                   on='PRVDR_NUM')

# Read out
final_matched_claims_allyears_tot_pop.to_stata('/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/merged_ats_claims_for_stata/final_matched_claims_w_tot_pop.dta',write_index=False)
final_unmatched_claims_allyears_tot_pop.to_stata('/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/merged_ats_claims_for_stata/final_unmatched_claims_w_tot_pop.dta',write_index=False)




