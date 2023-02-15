#----------------------------------------------------------------------------------------------------------------------#
# Project: (REG) Trauma center analysis using Medicare data
# Author: Jessy Nguyen
# Last Updated: February 8, 2023
# Description: The script will identify any claims that are not transferred claims ("first stop"). The goal of this study
# is to answer the research question of which first destination hospital is the BEST for patients with injuries. This script
# will drop any claims that are a result of a transfer from another hospital.
#----------------------------------------------------------------------------------------------------------------------#

################################################ IMPORT MODULES ########################################################

# Read in relevant libraries
import dask.dataframe as dd
from datetime import timedelta
import pandas as pd

############################################ MODULE FOR CLUSTER ########################################################

# Read in libraries to use cluster
from dask.distributed import Client
client = Client('127.0.0.1:3500')
    # Need to use 25/30 workers with 40 memory and 2 threads per worker
    # May need to rerun for the years that did not process due to workers killed.

############################################### IDENTIFY FIRST STOPS ###################################################

# Specify IP or OP
claim_type = ['ip','opb'] # opb is outpatient base file (not revenue file)

# Specify Years
years=[*range(2011,2020)]

for c in claim_type:

    for y in years:

        # Note the assumed definition of a transfer is that the service date within one day of another hospital's discharge date.

        # Read in raw IP. Raw files are needed to help identify which claim is within one day to be considered a transfer.
        raw_ip = dd.read_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project/ip/{y}/parquet/', engine='fastparquet', columns=['BENE_ID','DSCHRG_DT','PRVDR_NUM','ORG_NPI_NUM'])

        # Read in raw OP. Raw files are needed to help identify which claim is within one day to be considered a transfer.
        raw_op = dd.read_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project/opb/{y}/parquet', engine='fastparquet', columns=['BENE_ID','CLM_THRU_DT','PRVDR_NUM','ORG_NPI_NUM','CLM_FAC_TYPE_CD'])
        raw_op['CLM_FAC_TYPE_CD'] = raw_op['CLM_FAC_TYPE_CD'].astype(str)  # ensure that dtype is consistent
        raw_op = raw_op[raw_op['CLM_FAC_TYPE_CD'] == '1'] # keep only hospital op claims
        raw_op = raw_op.drop(['CLM_FAC_TYPE_CD'],axis=1) # drop column

        # Change column name
        raw_ip = raw_ip.rename(columns={'DSCHRG_DT':'END_DT'})
        raw_op = raw_op.rename(columns={'CLM_THRU_DT':'END_DT'})

        # Convert to datetime
        raw_ip['END_DT'] = dd.to_datetime(raw_ip['END_DT'])
        raw_op['END_DT'] = dd.to_datetime(raw_op['END_DT'])

        # Add one day. Will be used to determine if the claims from the analytical file is within this one day. If it is, then it's a transfer and NOT a first destination.
        raw_ip['END_DT_PLUSONE'] = raw_ip['END_DT'].map_partitions(lambda x: x + timedelta(days=1))
        raw_op['END_DT_PLUSONE'] = raw_op['END_DT'].map_partitions(lambda x: x + timedelta(days=1))

        # Concat
        raw_ip_op = dd.concat([raw_ip,raw_op],axis=0)

        # Recover memory
        del raw_ip
        del raw_op

        if c in ['ip']:

            print(c,y)

            # Read in ip data (analytical sample)
            df_hos_sample = dd.read_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/nonrural/{c}/{y}_dup_dropped',engine='fastparquet',
                                           columns=['MEDPAR_ID','BENE_ID','ADMSN_DT','PRVDR_NUM','ORG_NPI_NUM'])

            # Convert to datetime
            df_hos_sample['ADMSN_DT'] = dd.to_datetime(df_hos_sample['ADMSN_DT'])

            # Merge with raw ip and op
            df_hos_sample_merge = dd.merge(raw_ip_op,df_hos_sample,how='right',on=['BENE_ID'],suffixes=['_RAW','_ANALYTICAL'])

            # Recover memory
            del df_hos_sample
            del raw_ip_op

            # Keep "transfer" claims from analytical sample if the analytical sample has a different provider id (and different npi number) and the analytical claim's begin date is within one day of the raw data's end date
            # I am "keeping" to identify the transfers. Later in this code, I will use this dataframe to drop all claims that are "transfers"
            df_hos_sample_merge = df_hos_sample_merge[(df_hos_sample_merge['PRVDR_NUM_RAW']!=df_hos_sample_merge['PRVDR_NUM_ANALYTICAL']) &
                                                      (df_hos_sample_merge['ORG_NPI_NUM_RAW']!=df_hos_sample_merge['ORG_NPI_NUM_ANALYTICAL']) &
                                                      (df_hos_sample_merge['ADMSN_DT']<=df_hos_sample_merge['END_DT_PLUSONE']) & # w/in one day
                                                      (df_hos_sample_merge['ADMSN_DT']>=df_hos_sample_merge['END_DT'])] # at least the analytical file's end date
                # Reiterate: This assumes that the claims from the analytical sample is a "transfer" claim if it matches with the raw file, is within one day of the raw file end date, and has a different provider id from the raw file.

            # Create indicator. This will be used to identify transfers and drop them.
            df_hos_sample_merge['match_ind'] = 1

            # Clean columns
            df_hos_sample_merge = df_hos_sample_merge.drop(['BENE_ID', 'END_DT', 'PRVDR_NUM_RAW', 'ORG_NPI_NUM_RAW',
                                                            'END_DT_PLUSONE','ADMSN_DT', 'PRVDR_NUM_ANALYTICAL', 'ORG_NPI_NUM_ANALYTICAL'],axis=1)

            # Read in original ip analytical sample with all columns
            ip_analytical_sample = dd.read_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/nonrural/{c}/{y}_dup_dropped',
                engine='fastparquet')

            # Match original ip analytical sample with the DF that identified "transfer" claims on MEDPAR ID. Any that matched will be dropped since those are "transfer" claims.
            ip_merged = dd.merge(df_hos_sample_merge,ip_analytical_sample,how='right',on=['MEDPAR_ID'])

            # Recover memory
            del df_hos_sample_merge
            del ip_analytical_sample

            # # CHECK: Make sure that I did not drop any claims that was a result of emergency ambulance ride)
            # print(ip_merged['amb_ind'].sum().compute())
            # denom=ip_merged.shape[0].compute()

            # Keep those that did not match (i.e. the "first stops") using the created match_ind column or if the claim matched with an amb claim (i.e. also keep claims if they were a result of emergency ambulance ride)
            ip_merged = ip_merged[(ip_merged['match_ind'].isna())|(ip_merged['amb_ind']==1)]

            # # CHECK: Make sure that I did not drop any claims that was a result of emergency ambulance ride)
            # print(ip_merged['amb_ind'].sum().compute())
            # print(f'{c} ',ip_merged.shape[0].compute()/denom)

            # Clean columns
            ip_merged = ip_merged.drop(['match_ind'],axis=1)

            # Export only first destinations.
            ip_merged.to_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/first_stops/{c}/{y}',engine='fastparquet',compression='gzip')

        if c in ['opb']:

            print(c,y)

            # Read in op data (analytical sample)
            df_hos_sample = dd.read_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/nonrural/{c}/{y}_dup_dropped',engine='fastparquet',
                                           columns=['CLM_ID','BENE_ID','CLM_FROM_DT','PRVDR_NUM','ORG_NPI_NUM'])

            # Convert to datetime
            df_hos_sample['CLM_FROM_DT'] = dd.to_datetime(df_hos_sample['CLM_FROM_DT'])

            # Merge with raw ip and op
            df_hos_sample_merge = dd.merge(raw_ip_op,df_hos_sample,how='right',on=['BENE_ID'],suffixes=['_RAW','_ANALYTICAL'])

            # Recover memory
            del df_hos_sample
            del raw_ip_op

            # Keep "transfer" claims from analytical sample if the analytical sample has a different provider id (and different npi number) and the analytical claim's begin date is within one day of the raw data's end date
            # I am "keeping" to identify the transfers. Later in this code, I will use this dataframe to drop all claims that are "transfers"
            df_hos_sample_merge = df_hos_sample_merge[(df_hos_sample_merge['PRVDR_NUM_RAW']!=df_hos_sample_merge['PRVDR_NUM_ANALYTICAL']) &
                                                      (df_hos_sample_merge['ORG_NPI_NUM_RAW']!=df_hos_sample_merge['ORG_NPI_NUM_ANALYTICAL']) &
                                                      (df_hos_sample_merge['CLM_FROM_DT']<=df_hos_sample_merge['END_DT_PLUSONE']) & # w/in one day
                                                      (df_hos_sample_merge['CLM_FROM_DT']>=df_hos_sample_merge['END_DT'])] # at least the analytical file's end date
                # Reiterate: This assumes that the claims from the analytical sample is a "transfer" claim if it matches with the raw file, is within one day of the raw file end date, and has a different provider id from the raw file.

            # Create indicator. This will be used to identify transfers and drop them.
            df_hos_sample_merge['match_ind'] = 1

            # Clean columns
            df_hos_sample_merge = df_hos_sample_merge.drop(['BENE_ID', 'END_DT', 'PRVDR_NUM_RAW', 'ORG_NPI_NUM_RAW',
                                                            'END_DT_PLUSONE','CLM_FROM_DT', 'PRVDR_NUM_ANALYTICAL', 'ORG_NPI_NUM_ANALYTICAL'],axis=1)

            # Because OP claims are so large, I need to read it out then read it back in.... I did not need to do this for IP claims
            df_hos_sample_merge.to_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/nonrural/{c}/{y}_trnsfr_clms/',engine='fastparquet',compression='gzip')
            del df_hos_sample_merge

            # Something is wrong with parquet...will convert to csv using pandas then read it in
            df_hos_sample_merge = pd.read_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/nonrural/{c}/{y}_trnsfr_clms/',
                engine='fastparquet', columns=['CLM_ID', 'match_ind'])
            df_hos_sample_merge.to_csv(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/nonrural/{c}/{y}_trnsfr_clms.csv',index=False,index_label=False)
            del df_hos_sample_merge

            # Read in trnfr_clms after coverting to csv
            df_hos_sample_merge = dd.read_csv(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/nonrural/{c}/{y}_trnsfr_clms.csv',dtype=str)
            df_hos_sample_merge['CLM_ID']=df_hos_sample_merge['CLM_ID'].astype(str)
            df_hos_sample_merge['match_ind'] = df_hos_sample_merge['match_ind'].astype(int)

            # Read in original op analytical sample with all columns
            op_analytical_sample = dd.read_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/nonrural/{c}/{y}_dup_dropped',
                engine='pyarrow')

            # Match original op analytical sample with the DF that identified "transfer" claims on CLM ID. Any that matched will be dropped since those are "transfer" claims.
            op_merged = dd.merge(df_hos_sample_merge,op_analytical_sample,how='right',on=['CLM_ID'])

            # Recover memory
            del df_hos_sample_merge
            del op_analytical_sample

            # # CHECK: Make sure that I did not drop any claims that was a result of emergency ambulance ride)
            # print(op_merged['amb_ind'].sum().compute())
            # denom=op_merged.shape[0].compute()

            # Keep those that did not match (i.e. the "first stops") using the created match_ind column or if the claim matched with an amb claim (i.e. also keep claims if they were a result of emergency ambulance ride)
            op_merged = op_merged[(op_merged['match_ind'].isna())|(op_merged['amb_ind']==1)]

            # # CHECK: Make sure that I did not drop any claims that was a result of emergency ambulance ride)
            # print(op_merged['amb_ind'].sum().compute())
            # print(f'{c} ',op_merged.shape[0].compute()/denom)

            # Clean columns
            op_merged = op_merged.drop(['match_ind'],axis=1)

            # Export only first destinations.
            op_merged.to_parquet(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/first_stops/{c}/{y}',engine='pyarrow',compression='gzip')
















