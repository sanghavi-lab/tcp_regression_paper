#----------------------------------------------------------------------------------------------------------------------#
# Project: (REG) Trauma center analysis using Medicare data
# Author: Jessy Nguyen
# Last Updated: February 8, 2023
# Description: This script gathers diagnosis columns from raw IP, OP, and ambulance claims and exports files to parquet
# format. This information will be used when calculating comorbidity scores to risk adjust when creating
# hospital quality measures. Note that I have gathered raw diagnosis information before. However, this one will be for
# bene's with surgical drgs, specifically.
#----------------------------------------------------------------------------------------------------------------------#

################################################ IMPORT MODULES ########################################################

# Read in relevant libraries
import dask.dataframe as dd
import numpy as np

############################################ MODULE FOR CLUSTER ########################################################

# Read in libraries to use cluster
from dask.distributed import Client
client = Client('127.0.0.1:3500')

####################################### CREATE SUBSETS FOR OP AND CARRIER ##############################################
# The carrier and OP files are too large. I created subsets if the carrier/op contained only bene_id's from the sample

#___ Carrier ___#

# Specify Years
years=[*range(2011,2020)]

# Specify columns with dx columns
columns_BCARRB = ['BENE_ID', 'CLM_FROM_DT', 'PRNCPAL_DGNS_CD'] + [f'ICD_DGNS_CD{i}' for i in range(1, 13)]              # for any carrier file

for y in years:

    #___ Read in analytical sample to subset relevant bene ids ___#
    # Because IP/OP/CARR raw files are large, I only want a subset of raw files that are relevant with my analytical files.

    # Define Columns
    columns_processed = ['BENE_ID']

    # Read in final analytical data. Since we do not have 2010 data, we can only gather full info for 2012-2017.
    if y in [*range(2011,2019)]: # 2011-2018 since we have the following year
        current_year = dd.read_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/hospital_quality_measure/bene_with_surgical_drgs/{y}/',
                                   engine='fastparquet',columns=columns_processed) # e.g. for 2013 loop, this will gather everyone from 2013
        next_year = dd.read_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/hospital_quality_measure/bene_with_surgical_drgs/{y+1}/',
                                   engine='fastparquet',columns=columns_processed) # e.g. for 2013 loop, this will gather everyone from 2014 to account for the year prior when the 2013 raw is needed for 2014.
        processed_df = dd.concat([current_year,next_year],axis=0)
        del current_year # Recover memory
        del next_year # Recover memory
            # Since comorbidity scores require the current year and one year PRIOR, I need to gather all dx info for everyone in the current year and year prior.
            # E.g. say we want 2012 raw data. We need the 2012 data and all 2011 data. If the currently loop is on 2011, the "next_year" df will account for
            # everyone from 2012 who also have info in 2011. That way, we have FULL information of all dx codes for 2012 from the current year and year prior (2011) when
            # calculating the comorbidity scores.
    else: # 2019 since we don't have 2020 data
        processed_df = dd.read_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/hospital_quality_measure/bene_with_surgical_drgs/{y}/',
                                   engine='fastparquet',columns=columns_processed)

    #___ Read in raw carrier claims and subset relevant bene_ids ___#

    if y in [*range(2011, 2018, 1)]: # list from 2011-2017

        # Read in BCARRB
        df_BCARRB = dd.read_csv(f'/mnt/data/medicare-share/data/{y}/BCARRB/csv/bcarrier_claims_k.csv',usecols=columns_BCARRB,sep=',',
                                engine='c', dtype='object', na_filter=False, skipinitialspace=True, low_memory=False)
    elif y in [2018,2019]:

        # Read in BCARRB (saved in different directory for 18-19
        df_BCARRB = dd.read_csv(f'/mnt/data/medicare-share/data/{y}/bcar/bcar_rb/csv/bcarrier_claims.csv',usecols=columns_BCARRB,sep=',',
                            engine='c', dtype='object', na_filter=False, skipinitialspace=True, low_memory=False)

    # Merge data to keep on relevant bene ids
    rel_bene_carr = dd.merge(df_BCARRB,processed_df,on=['BENE_ID'],how='inner')

    # Delete extra DFs
    del df_BCARRB
    del processed_df

    #___ Export final raw file with dx info ___#

    # Export all raw dx information. Will be used in another code to calculate the comorbidity scores.
    rel_bene_carr.to_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/hospital_quality_measure/bene_with_surgical_drgs/carr_subset/{y}/',engine='fastparquet',compression='gzip')

    # Recover memory
    del rel_bene_carr

#___ Outpatient ___#

# Specify Years
years=[*range(2011,2020)]

# Specify columns with dx columns
columns_op = ['BENE_ID', 'CLM_FROM_DT', 'PRVDR_NUM', 'PRNCPAL_DGNS_CD'] + [f'ICD_DGNS_CD{i}' for i in range(1, 26)]     # for OP

for y in years:

    #___ Read in analytical sample to subset relevant bene ids ___#
    # Because IP/OP/CARR raw files are large, I only want a subset of raw files that are relevant with my analytical files.

    # Define Columns
    columns_processed = ['BENE_ID']

    # Read in final analytical data. Since we do not have 2010 data, we can only gather full info for 2012-2017.
    if y in [*range(2011,2019)]: # 2011-2018 since we have the following year
        current_year = dd.read_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/hospital_quality_measure/bene_with_surgical_drgs/{y}',
                                   engine='pyarrow',columns=columns_processed) # e.g. for 2013 loop, this will gather everyone from 2013
        next_year = dd.read_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/hospital_quality_measure/bene_with_surgical_drgs/{y+1}',
                                   engine='pyarrow',columns=columns_processed) # e.g. for 2013 loop, this will gather everyone from 2014 to account for the year prior when the 2013 raw is needed for 2014.
        processed_df = dd.concat([current_year,next_year],axis=0)
        del current_year # Recover memory
        del next_year # Recover memory
            # Since comorbidity scores require the current year and one year PRIOR, I need to gather all dx info for everyone in the current year and year prior.
            # E.g. say we want 2012 raw data. We need the 2012 data and all 2011 data. If the currently loop is on 2011, the "next_year" df will account for
            # everyone from 2012 who also have info in 2011. That way, we have FULL information of all dx codes for 2012 from the current year and year prior (2011) when
            # calculating the comorbidity scores.
    else: # 2019 since we don't have 2020 data.
        processed_df = dd.read_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/hospital_quality_measure/bene_with_surgical_drgs/{y}',
                                   engine='pyarrow',columns=columns_processed)

    #___ Read in raw OP and subset relevant bene_ids ___#

    # Read in OP claims
    op = dd.read_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project/opb/{y}/parquet/',
                         engine='pyarrow', columns=columns_op)

    # Merge data to keep on relevant subset of bene ids
    rel_bene_op = dd.merge(op,processed_df,on=['BENE_ID'],how='inner')

    # Delete extra DFs
    del op

    #___ Export final raw file with dx info ___#

    # Export all raw dx information. Will be used in another code to calculate the comorbidity scores.
    rel_bene_op.to_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/hospital_quality_measure/bene_with_surgical_drgs/op_subset_comorbid/{y}/',engine='pyarrow',compression='gzip')

    # Recover memory
    del rel_bene_op

####################### GRAB HOSPITAL AND CARR DX CODES FOR COMORBIDITY CALCULATIONS ##############################

# Specify Years
years=[*range(2011,2020)]

# Specify columns with dx columns
columns_ip = ['BENE_ID', 'ADMSN_DT', 'PRVDR_NUM', 'ADMTG_DGNS_CD'] + [f'DGNS_{i}_CD' for i in range(1, 26)]             # for IP
columns_op = ['BENE_ID', 'CLM_FROM_DT', 'PRVDR_NUM', 'PRNCPAL_DGNS_CD'] + [f'ICD_DGNS_CD{i}' for i in range(1, 26)]     # for OP
columns_BCARRB = ['BENE_ID', 'CLM_FROM_DT', 'PRNCPAL_DGNS_CD'] + [f'ICD_DGNS_CD{i}' for i in range(1, 13)]              # for any carrier file

for y in years:

    #___ Read in analytical sample to subset relevant bene ids ___#
    # Because IP/OP/CARR raw files are large, I only want a subset of raw files that are relevant with my analytical files.

    # Define Columns
    columns_processed = ['BENE_ID','ADMSN_DT']

    # Read in final analytical data. Since we do not have 2010 data, we can only gather full info for 2012-2017.
    if y in [*range(2011,2019)]: # 2011-2018 since we have the following year
        current_year = dd.read_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/hospital_quality_measure/bene_with_surgical_drgs/{y}',
                                   engine='fastparquet',columns=columns_processed) # e.g. for 2013 loop, this will gather everyone from 2013
        next_year = dd.read_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/hospital_quality_measure/bene_with_surgical_drgs/{y+1}',
                                   engine='fastparquet',columns=columns_processed) # e.g. for 2013 loop, this will gather everyone from 2014 to account for the year prior when the 2013 raw is needed for 2014.
        processed_df = dd.concat([current_year,next_year],axis=0)
        del current_year # Recover memory
        del next_year # Recover memory
            # Since comorbidity scores require the current year and one year PRIOR, I need to gather all dx info for everyone in the current year and year prior.
            # E.g. say we want 2012 raw data. We need the 2012 data and all 2011 data. If the currently loop is on 2011, the "next_year" df will account for
            # everyone from 2012 who also have info in 2011. That way, we have FULL information of all dx codes for 2012 from the current year and year prior (2011) when
            # calculating the comorbidity scores.
    else: # 2019 since we don't have 2020 data
        processed_df = dd.read_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/hospital_quality_measure/bene_with_surgical_drgs/{y}',
                                   engine='fastparquet',columns=columns_processed)

    # Convert to Datetime
    processed_df['ADMSN_DT'] = dd.to_datetime(processed_df['ADMSN_DT'])

    # Rename column
    processed_df=processed_df.rename(columns={'ADMSN_DT':'SRVC_BGN_DT_HOS'})

    #___ Read in raw IP and subset relevant bene_ids ___#

    # Read in IP claims (planning to use MEDPAR to obtain info from both IP and SNF
    if y in [2018,2019]:
        # Read in data from MedPAR (2018/19 were saved under different folder names)
        ip = dd.read_csv(f'/mnt/data/medicare-share/data/{y}/medpar/csv/medpar.csv', usecols=columns_ip,sep=',', engine='c',
                                dtype='object', na_filter=False, skipinitialspace=True, low_memory=False)
    else:
        ip = dd.read_csv(f'/mnt/data/medicare-share/data/{y}/MEDPAR/csv/medpar_{y}.csv',usecols=columns_ip,sep=',', engine='c',
                                dtype='object', na_filter=False, skipinitialspace=True, low_memory=False)

    # Rename IP data and primary dx column so concatenating is easier
    ip=ip.rename(columns={'ADMSN_DT':'SRVC_BGN_DT','ADMTG_DGNS_CD':'dx1'})

    # Rename remaining dx columns using loop.
    for n in range(1,26):
        ip = ip.rename(columns={f'DGNS_{n}_CD': f'dx{n+1}'}) # Need the n+1 since the primary diagnosis code is dx1

    # Convert to Datetime
    ip['SRVC_BGN_DT'] = dd.to_datetime(ip['SRVC_BGN_DT'])

    # Merge data to keep on relevant subset of bene ids
    rel_bene_ip = dd.merge(ip,processed_df,on=['BENE_ID'],how='inner')

    # Delete extra DFs
    del ip

    # Keep only if the raw file service data is on or before the processed service date. This is because we need diagnosis codes that are one year before (not after) the injury event.
    rel_bene_ip = rel_bene_ip[rel_bene_ip['SRVC_BGN_DT']<=rel_bene_ip['SRVC_BGN_DT_HOS']]

    #___ Read in raw OP and subset relevant bene_ids ___#

    # Read in OP claims
    op = dd.read_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/hospital_quality_measure/bene_with_surgical_drgs/op_subset_comorbid/{y}',
                         engine='fastparquet', columns=columns_op)

    # Rename OP data and primary dx column so concatenating is easier
    op = op.rename(columns={'CLM_FROM_DT': 'SRVC_BGN_DT','PRNCPAL_DGNS_CD':'dx1'})

    # Rename remaining dx columns using loop.
    for n in range(1,26):
        op = op.rename(columns={f'ICD_DGNS_CD{n}': f'dx{n+1}'}) # Need the n+1 since the primary diagnosis code is dx1

    # Convert to Datetime
    op['SRVC_BGN_DT'] = dd.to_datetime(op['SRVC_BGN_DT'])

    # Merge data to keep on relevant subset of bene ids
    rel_bene_op = dd.merge(op,processed_df,on=['BENE_ID'],how='inner')

    # Delete extra DFs
    del op

    # Keep only if the raw file service data is on or before the processed service date. This is because we need diagnosis codes that are one year before (not after) the injury event.
    rel_bene_op = rel_bene_op[rel_bene_op['SRVC_BGN_DT']<=rel_bene_op['SRVC_BGN_DT_HOS']]

    #___ Combine IP and OP claims first ___#
    # We concatenate the ip/op claims first to drop duplicates within institutional claims

    # Concatenate IP and OP
    ip_op = dd.concat([rel_bene_ip,rel_bene_op],axis=0)

    # Delete extra DFs
    del rel_bene_ip
    del rel_bene_op

    # Drop duplicated claims on BENE_ID, SERVICE DATE, and PROVIDER ID (PRVDR_NUM was specified to make sure the claims were from the same hospital when dropping duplicates)
    ip_op = ip_op.shuffle(on=['BENE_ID','SRVC_BGN_DT','PRVDR_NUM']).map_partitions(lambda x: x.drop_duplicates(subset=['BENE_ID','SRVC_BGN_DT','PRVDR_NUM'],keep='first'))
        # Sometimes, individuals may have both and IP and OP claim from one hospital. This is an error on CMS side. Thus, dropping duplicates and keeping first will allow me to prioritize keeping inpatient claims (not outpatient) if CMS did make this error.

    # Drop provider id
    ip_op = ip_op.drop(['PRVDR_NUM'],axis=1)

    #___ Read in raw carrier claims and subset relevant bene_ids ___#

    # Read in data
    df_BCARRB = dd.read_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/hospital_quality_measure/bene_with_surgical_drgs/carr_subset/{y}/',
                         engine='fastparquet', columns=columns_BCARRB)

    # Rename data and primary dx column so concatenating is easier
    df_BCARRB=df_BCARRB.rename(columns={'CLM_FROM_DT':'SRVC_BGN_DT','PRNCPAL_DGNS_CD':'dx1'})

    # Rename remaining dx columns using loop.
    for n in range(1,13):
        df_BCARRB = df_BCARRB.rename(columns={f'ICD_DGNS_CD{n}': f'dx{n+1}'}) # Need the n+1 since the primary diagnosis code is dx1

    # Convert to Datetime
    df_BCARRB['SRVC_BGN_DT'] = dd.to_datetime(df_BCARRB['SRVC_BGN_DT'])

    # Merge data to keep on relevant bene ids
    rel_bene_carr = dd.merge(df_BCARRB,processed_df,on=['BENE_ID'],how='inner')

    # Delete extra DFs
    del df_BCARRB
    del processed_df

    # Keep only if the raw file service data is on or before the processed service date. This is because we need diagnosis codes that are one year before (not after) the injury event.
    rel_bene_carr = rel_bene_carr[rel_bene_carr['SRVC_BGN_DT']<=rel_bene_carr['SRVC_BGN_DT_HOS']]

    #___ Combine with carr claims ___#

    # Finally, concat ip_op with carr dx columns. Do NOT drop duplicates. Otherwise, I will drop carr or hos dx information that is needed within the same service date.
    ip_op_carr = dd.concat([ip_op,rel_bene_carr],axis=0)

    # Delete extra DFs
    del ip_op
    del rel_bene_carr

    # Drop date column from processed data
    ip_op_carr = ip_op_carr.drop(['SRVC_BGN_DT_HOS'],axis=1)

    #___ Export final raw file with dx info ___#

    # Export all raw dx information. Will be used in another code to calculate the comorbidity scores.
    ip_op_carr.to_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/hospital_quality_measure/final_raw_dx_for_comorbidity/{y}/',engine='fastparquet',compression='gzip')

    # Recover memory
    del ip_op_carr











