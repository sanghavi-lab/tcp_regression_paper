#----------------------------------------------------------------------------------------------------------------------#
# Project: (REG) Trauma center analysis using Medicare data
# Author: Jessy Nguyen
# Last Updated: January 30, 2023
# Description: This script's goal is to obtain mileage information by merging the ambulance claims with mileage
#----------------------------------------------------------------------------------------------------------------------#

################################################ IMPORT MODULES ########################################################

# Read in relevant libraries
from datetime import datetime, timedelta
import pandas as pd
import dask.dataframe as dd
import numpy as np

############################################ MODULE FOR CLUSTER ########################################################

# Read in libraries to use cluster
from dask.distributed import Client
client = Client('127.0.0.1:3500')

########################### MERGE EMERGENCY AMBULANCE CLAIMS WITH MILEAGE INFORMATION ##################################

# Specify years
years=[*range(2011,2020)]

for y in years:

    # Specify Columns for Mileage DF
    columns_mi = ['CLM_ID','HCPCS_CD','HCPCS_1ST_MDFR_CD','HCPCS_2ND_MDFR_CD','LINE_1ST_EXPNS_DT','LINE_LAST_EXPNS_DT',
                  'LINE_PRCSG_IND_CD','CARR_LINE_MTUS_CNT','CLM_THRU_DT']

    if y in [*range(2011, 2018, 1)]: # list from 2011-2016

        # Read in carrier line data for the particular year to obtain mileage information
        df_BCARRL = dd.read_csv(f'/mnt/data/medicare-share/data/{y}/BCARRL/csv/bcarrier_line_k.csv',usecols=columns_mi,sep=',',
                                engine='c', dtype='object', na_filter=False, skipinitialspace=True, low_memory=False)
    elif y in [2018,2019]:

        # Read in carrier line
        df_BCARRL = dd.read_csv(f'/mnt/data/medicare-share/data/{y}/bcar/bcar_rl/csv/bcarrier_line.csv',usecols=columns_mi, sep=',',
                                 engine='c', dtype='object', na_filter=False, skipinitialspace=True, low_memory=False)


    # Keep mileage information from the carrier line file
    mileage_cd = ['A0425']
    payment_allowed_cd = ['A']
    mileage = df_BCARRL.loc[(df_BCARRL['HCPCS_CD'].isin(mileage_cd)) & (df_BCARRL['LINE_PRCSG_IND_CD'].isin(payment_allowed_cd))]

    # Recover memory
    del df_BCARRL

    # Keep modifiers in emergency ambulances that are dropoff to hospitals
    pickup_dropoff_cd = ['EH', 'NH', 'RH', 'SH']
    mileage = mileage.loc[(mileage['HCPCS_1ST_MDFR_CD'].isin(pickup_dropoff_cd)) | (mileage['HCPCS_2ND_MDFR_CD'].isin(pickup_dropoff_cd))]

    # Clean DF
    mileage = mileage.drop(['LINE_PRCSG_IND_CD','HCPCS_CD','HCPCS_1ST_MDFR_CD','HCPCS_2ND_MDFR_CD'],axis=1)

    # Convert to datetime
    mileage['LINE_1ST_EXPNS_DT'] = dd.to_datetime(mileage['LINE_1ST_EXPNS_DT'])
    mileage['LINE_LAST_EXPNS_DT'] = dd.to_datetime(mileage['LINE_LAST_EXPNS_DT'])

    # Create column of ones to count number matched
    mileage['ind_for_mi_match'] = 1

    # Convert miles column to float and rename
    mileage['CARR_LINE_MTUS_CNT'] = mileage['CARR_LINE_MTUS_CNT'].astype(float) # convert to float
    mileage = mileage.rename(columns={'CARR_LINE_MTUS_CNT':'MILES'}) # rename

    # Add miles together from multiple rows by clm_id if there are multiple rows of the same claim id
    mileage_sum_mi_across_clm_id = mileage.groupby(['CLM_ID'])['MILES'].sum().to_frame().reset_index()
        # B/c i kept only EH, NH, RH, SH, grouping by claim id and summing is okay. (e.g. i don't have to worry that I may include HH in my summation)

    # Merge new added values to original mileage df
    mileage_final = dd.merge(mileage,mileage_sum_mi_across_clm_id,on=['CLM_ID'],suffixes=['_NOT_SUM','_SUM'], how='left')

    # Recover memory
    del mileage
    del mileage_sum_mi_across_clm_id

    # Clean DF
    mileage_final = mileage_final.drop(['MILES_NOT_SUM'],axis=1)
    mileage_final = mileage_final.rename(columns={'MILES_SUM':'MILES'})

    # Read in Ambulance Claims
    amb = dd.read_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project/emergency_ambulance_claims/{y}/parquet/', engine='fastparquet')

    # Clean DF
    amb = amb.drop(['LINE_PRCSG_IND_CD','CARR_CLM_PMT_DNL_CD'],axis=1)

    # Keep only to hospital, HH, and QL
    pickup_dropoff_cd = ['EH', 'NH', 'RH','SH']
    amb = amb.loc[(amb['HCPCS_1ST_MDFR_CD'].isin(pickup_dropoff_cd)) | (amb['HCPCS_2ND_MDFR_CD'].isin(pickup_dropoff_cd))]

    # Convert all relevant columns to datetime
    amb['CLM_THRU_DT'] = dd.to_datetime(amb['CLM_THRU_DT'])
    amb['LINE_1ST_EXPNS_DT'] = dd.to_datetime(amb['LINE_1ST_EXPNS_DT'])
    amb['LINE_LAST_EXPNS_DT'] = dd.to_datetime(amb['LINE_LAST_EXPNS_DT'])
    amb['BENE_BIRTH_DT'] = dd.to_datetime(amb['BENE_BIRTH_DT'])
    amb['BENE_DEATH_DT'] = dd.to_datetime(amb['BENE_DEATH_DT'])
    amb['BENE_DEATH_DT_FOLLOWING_YEAR'] = dd.to_datetime(amb['BENE_DEATH_DT_FOLLOWING_YEAR'])

    # Drop duplicated claim IDs
    amb = amb.drop_duplicates(subset=['CLM_ID','CLM_THRU_DT'], keep = 'last')

    # # CHECK number of amb before merging
    # print('Number of total amb before merge: ',amb.shape[0].compute())

    # Merge Amb with Mileage on 'left' DF. This will allow me to retain all of amb claims to calculate the correct denominator
    merge_amb_mi = dd.merge(amb,mileage_final,on=['CLM_ID','LINE_1ST_EXPNS_DT','LINE_LAST_EXPNS_DT'], how='left')

    # Recover Memory
    del amb
    del mileage_final

    # # CHECK proportion matched
    # total_amb_after_merge_and_drop_dup = merge_amb_mi.shape[0].compute()
    # total_amb_matched = merge_amb_mi['ind_for_mi_match'].sum().compute()
    # print('Number of total amb after merge and drop dup (should be same as top number): ',total_amb_after_merge_and_drop_dup)
    # print('Number of total amb after dropping those not matched: ',total_amb_matched)
    # print('Proportion matched: ', total_amb_matched/total_amb_after_merge_and_drop_dup)

    # Export to parquet.
    merge_amb_mi.to_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project/merged_amb_mi/{y}/parquet/', compression='gzip', engine='fastparquet')
        # Note that I did not drop those who did not match. If you read in this data, you will need to drop those
        # with ind_for_mi_match == 1 and then delete the column ind_for_mi_match before merging it with IP/OP. I kept
        # those who did not match only to calculate the proportion matched.









