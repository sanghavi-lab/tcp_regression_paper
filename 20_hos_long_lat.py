#----------------------------------------------------------------------------------------------------------------------#
# Project: (REG) Trauma center analysis using Medicare data
# Author: Jessy Nguyen
# Last Updated: September 12, 2022
# Description: The script will perform a cartesian merge to link hospital with hospitals and hospital with census block
#              centroid.
#----------------------------------------------------------------------------------------------------------------------#

############################################# IMPORT MODULES ###########################################################

import geopy.distance
import pandas as pd

############################################## CARTESIAN MERGE ########################################################
# Process takes ~ 4.5 hours to run using pandas

# Disable SettingWithCopyWarning (i.e. chained assignments)
pd.options.mode.chained_assignment = None

#___ Read in and prepare data ___#

# Define columns for ATS data
cols_ats = ['AHA_num', 'ACS_Ver', 'State_Des']

# Define columns for crosswalk AHA data
cols_xwalk = ['LONG', 'LAT', 'ID','MCRNUM']

# Read in trauma data from ATS and crosswalk data
trauma_ats_df = pd.read_excel(f'/mnt/labshares/sanghavi-lab/data/public_data/data/trauma_center_data/AM_TRAUMA_DATA_FIRST_TAB_UNLOCKED_2017.xlsx', usecols=cols_ats,dtype=str)
trauma_xwalk_df = pd.read_excel(f'/mnt/labshares/sanghavi-lab/data/public_data/data/trauma_center_data/NPINUM_MCRNUM_AHAID_CROSSWALK_2017.xlsx', header=3, dtype=str,usecols=cols_xwalk)

# Convert LONG/LAT to float
trauma_xwalk_df[['LONG','LAT']]=trauma_xwalk_df[['LONG','LAT']].astype('float')

# Merge trauma data and crosswalk on AHA ID (American Hospital Association ID) and keep all rows
trauma_ats_xwalk_df = pd.merge(trauma_xwalk_df,trauma_ats_df, left_on=['ID'], right_on=['AHA_num'],how='outer')

# Create column for Trauma Level based on state's designation
trauma_ats_xwalk_df['TRAUMA_LEVEL'] = 6 # all of the "-" are assumed to be nontrauma centers
trauma_ats_xwalk_df.loc[trauma_ats_xwalk_df['State_Des'] == "1", 'TRAUMA_LEVEL'] = 1
trauma_ats_xwalk_df.loc[trauma_ats_xwalk_df['State_Des'] == "2", 'TRAUMA_LEVEL'] = 2
trauma_ats_xwalk_df.loc[trauma_ats_xwalk_df['State_Des'] == "3", 'TRAUMA_LEVEL'] = 3
trauma_ats_xwalk_df.loc[trauma_ats_xwalk_df['State_Des'] == "4", 'TRAUMA_LEVEL'] = 4
trauma_ats_xwalk_df.loc[trauma_ats_xwalk_df['State_Des'] == "5", 'TRAUMA_LEVEL'] = 5

# Replace the TRAUMA_LVL based on American College of Surgeon
trauma_ats_xwalk_df.loc[trauma_ats_xwalk_df['ACS_Ver'] == "1", 'TRAUMA_LEVEL'] = 1
trauma_ats_xwalk_df.loc[trauma_ats_xwalk_df['ACS_Ver'] == "2", 'TRAUMA_LEVEL'] = 2
trauma_ats_xwalk_df.loc[trauma_ats_xwalk_df['ACS_Ver'] == "3", 'TRAUMA_LEVEL'] = 3
trauma_ats_xwalk_df.loc[trauma_ats_xwalk_df['ACS_Ver'] == "4", 'TRAUMA_LEVEL'] = 4
trauma_ats_xwalk_df.loc[trauma_ats_xwalk_df['ACS_Ver'] == "5", 'TRAUMA_LEVEL'] = 5

# remove unnecessary columns
trauma_ats_xwalk_df = trauma_ats_xwalk_df.drop(['AHA_num','ID'],axis=1)

# Reset index in preparation for loop (see below)
trauma_ats_xwalk_df = trauma_ats_xwalk_df.reset_index(drop=True)

# Keep if both LAT and LONG are not missing
trauma_ats_xwalk_df = trauma_ats_xwalk_df[~((trauma_ats_xwalk_df['LAT'].isnull()) | (trauma_ats_xwalk_df['LONG'].isnull()))]

# Keep if provider ID is not missing
trauma_ats_xwalk_df = trauma_ats_xwalk_df[~trauma_ats_xwalk_df['MCRNUM'].isnull()]

# Find number of rows minus 1 since index starts at zero
num_rows = trauma_ats_xwalk_df.shape[0] - 1

# Create function to calculate miles between two coordinate points
def distance_calc(row):
    start = (row['LAT'], row['LONG'])
    stop = (row['LAT_b'], row['LONG_b'])

    return geopy.distance.geodesic(start, stop).miles
    # This method is based on vincenty's formulae (https://en.wikipedia.org/wiki/Vincenty%27s_formulae)
    # They are based on the assumption that the figure of the Earth is an oblate spheroid, and hence are
    # more accurate than methods that assume a spherical Earth, such as great-circle distance.

# Create empty dictionary to store DF's
df_dict={}

# Create empty list to store DF names
df_list=[]

# Loop through each row (index starts at 0)
for i in range(0,num_rows):

    # This process is basically performing a cartesian merge. I found my way to be slightly faster than using the "cross" argument from pd.merge (e.g. df1.merge(df2, how='cross'))

    # Grab a row based on the index
    df_of_one_row = trauma_ats_xwalk_df.iloc[[i]]

    # Create column to merge on
    trauma_ats_xwalk_df['merge_col'] = i
    df_of_one_row['merge_col'] = i

    # Rename column name of the one row
    df_of_one_row = df_of_one_row.add_suffix('_b')

    # Merge such that every row from trauma_ats_xwalk_df gets the one row from df_of_one_row. Then put merged product into dictionary.
    df_dict[i] = pd.merge(trauma_ats_xwalk_df,df_of_one_row,right_on=['merge_col_b'],left_on=['merge_col'],how='left')

    # Clean df
    df_dict[i] = df_dict[i].drop(['merge_col','merge_col_b'],axis=1)

    # Calculate the distance between the hospitals
    df_dict[i]['distance'] = df_dict[i].apply(lambda row: distance_calc(row),axis=1)

    # Append name of DF to list
    df_list.append(df_dict[i])

# Concat all merged DF's
concat_df = pd.concat(df_list,axis=0)
del df_dict
del df_list

# Read out
concat_df.to_csv('/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/hos_w_dist_long_lat/hos_distance_2017.csv',index=False)


############################################## CARTESIAN MERGE ########################################################
# Perform the same cartesian merge but between census blocks and hospitals. This will be used to help create a graph that
# shows traffic proximity within #-mile radius.
# Process takes ~ 35 hours to run using pandas

# Note: 2017_Gaz_tracts_national was a txt file when obtained from the internet. I needed to convert file to csv.

# Read in crosswalk (long/lat to census block id)
census_long_lat_block = pd.read_csv('/mnt/labshares/sanghavi-lab/data/public_data/data/tract_to_long_lat_2017/2017_Gaz_tracts_national.csv')

# Replace all empty spaces with empty string in column name
census_long_lat_block.columns = census_long_lat_block.columns.str.replace(' ', '')

# Retain only relevant columns
census_long_lat_block = census_long_lat_block[['GEOID','INTPTLAT','INTPTLONG']]

# Convert ID to str
census_long_lat_block['GEOID'] = census_long_lat_block['GEOID'].astype(str)

# If GEOID has 10 characters, add a "0" in the beginning. GEOID should have 11 characters total but after converting to CSV, some "0" were omitted in the beginning.
census_long_lat_block['GEOID'] = census_long_lat_block['GEOID'].mask(census_long_lat_block['GEOID'].str.len() == 10,'0'+census_long_lat_block['GEOID'])

# Define columns
cols_xwalk = ['LONG', 'LAT','MCRNUM']

# Read in AHA data containing long/lat of hospitals
trauma_xwalk_df = pd.read_excel(f'/mnt/labshares/sanghavi-lab/data/public_data/data/trauma_center_data/NPINUM_MCRNUM_AHAID_CROSSWALK_2017.xlsx', header=3, dtype=str,usecols=cols_xwalk)

# Keep if both LAT and LONG are not missing
census_long_lat_block = census_long_lat_block[~((census_long_lat_block['INTPTLAT'].isnull()) | (census_long_lat_block['INTPTLONG'].isnull()))]
trauma_xwalk_df = trauma_xwalk_df[~((trauma_xwalk_df['LAT'].isnull()) | (trauma_xwalk_df['LONG'].isnull()))]

# Find number of rows minus 1 since index starts at zero
num_rows = trauma_xwalk_df.shape[0] - 1

# Create function to calculate miles between two coordinate points
def distance_calc(row):
    start = (row['LAT'], row['LONG'])
    stop = (row['INTPTLAT'], row['INTPTLONG'])

    return geopy.distance.geodesic(start, stop).miles
    # This method is based on vincenty's formulae (https://en.wikipedia.org/wiki/Vincenty%27s_formulae)
    # They are based on the assumption that the figure of the Earth is an oblate spheroid, and hence are
    # more accurate than methods that assume a spherical Earth, such as great-circle distance.

# Create empty dictionary to store DF's
df_dict={}

# Create empty list to store DF names
df_list=[]

# Loop through each row (index starts at 0)
for i in range(0,num_rows):

    # This process is basically performing a cartesian merge. I found my way to be slightly faster than using the "cross" argument from pd.merge (e.g. df1.merge(df2, how='cross'))

    # Grab a row based on the index
    df_of_one_row = trauma_xwalk_df.iloc[[i]]

    # Create column to merge on
    census_long_lat_block['merge_col_block'] = i
    df_of_one_row['merge_col_hos'] = i

    # Merge such that every row from trauma_ats_xwalk_df gets the one row from df_of_one_row. Then put merged product into dictionary.
    df_dict[i] = pd.merge(census_long_lat_block,df_of_one_row,right_on=['merge_col_hos'],left_on=['merge_col_block'],how='left')

    # Clean df
    df_dict[i] = df_dict[i].drop(['merge_col_hos','merge_col_block'],axis=1)

    # Calculate the distance between the hospitals
    df_dict[i]['distance'] = df_dict[i].apply(lambda row: distance_calc(row),axis=1)

    # Keep only if distance is within 100 miles for more efficiency
    df_dict[i] = df_dict[i][df_dict[i]['distance']<101]

    # Append name of DF to list
    df_list.append(df_dict[i])

# Concat all merged DF's
concat_df = pd.concat(df_list,axis=0)
del df_dict
del df_list

# Read out
concat_df.to_csv('/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/hos_w_dist_w_other_census_blocks/2017_w_pd.csv',index=False)



