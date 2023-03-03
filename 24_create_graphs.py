#----------------------------------------------------------------------------------------------------------------------#
# Project: (REG) Trauma center analysis using Medicare data
# Author: Jessy Nguyen
# Last Updated: February 8, 2023
# Description: The script will create figure 2
#----------------------------------------------------------------------------------------------------------------------#

############################################# IMPORT MODULES ###########################################################

# Read in relevant libraries
from datetime import datetime, timedelta
import pandas as pd
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt
from matplotlib.patches import Patch

########################################## HISTOGRAMS ##################################################################

# FOR (1) NISS, (2) COUNT OF DX CODES

#_________ Prepare data and read out in csv___________#

# Specify columns
col = ['amb_ind','State_Des','ACS_Ver','parts_ab_ind','niss','RTI_RACE_CD','SEX_IDENT_CD','sec_secondary_trauma_ind','less_than_90_bene_served','MILES','num_of_diag_codes_nodup','PTRAF_dist6','PTRAF_dist5','PTRAF_dist3','PTRAF_dist9','tot_pop_in_cnty','choice_ind_mi9']

# Read in
trauma_ats_df = pd.read_stata('/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/merged_ats_claims_for_stata/final_matched_claims_w_tot_pop.dta',columns=col)
ntrauma_ats_df = pd.read_stata('/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/merged_ats_claims_for_stata/final_unmatched_claims_w_tot_pop.dta',columns=col)

# Keep amb
trauma_ats_df=trauma_ats_df[trauma_ats_df['amb_ind']==1]
ntrauma_ats_df=ntrauma_ats_df[ntrauma_ats_df['amb_ind']==1]

# Create trauma_lvl column using State_Des first
trauma_ats_df['TRAUMA_LEVEL'] = np.where(trauma_ats_df['State_Des'] == '1', '1',
                                         np.where(trauma_ats_df['State_Des'] == '2', '2',
                                                  np.where(trauma_ats_df['State_Des'] == '3', '3',
                                                           np.where(trauma_ats_df['State_Des'] == '4', '4',
                                                                    np.where(trauma_ats_df['State_Des'] == '5', '5',
                                                                             np.where(trauma_ats_df['State_Des'] == '-',
                                                                                      '-', '-'))))))

# Then prioritize ACS (there is no lvl 4 or 5 in ACS_Ver column)
trauma_ats_df.loc[trauma_ats_df['ACS_Ver'] == '1', 'TRAUMA_LEVEL'] = '1'
trauma_ats_df.loc[trauma_ats_df['ACS_Ver'] == '2', 'TRAUMA_LEVEL'] = '2'
trauma_ats_df.loc[trauma_ats_df['ACS_Ver'] == '3', 'TRAUMA_LEVEL'] = '3'

# Assign nontrauma
ntrauma_ats_df['TRAUMA_LEVEL'] = 'NT'

#--- Clean data ---#

# Concat
concat_df = pd.concat([trauma_ats_df,ntrauma_ats_df],axis=0)

# Keep parts a and b
concat_df = concat_df[concat_df['parts_ab_ind']==1]

# Keep correct niss
concat_df = concat_df[(concat_df['niss']>=1)&(concat_df['niss']<=75)]

# Drop if both is "-"
concat_df = concat_df[~((concat_df['State_Des']=='-')&(concat_df['ACS_Ver']=='-'))]

# Drop missing race and sex
concat_df = concat_df[concat_df['RTI_RACE_CD']!=0]
concat_df = concat_df[concat_df['SEX_IDENT_CD']!=0]

# Drop second secondary trauma
concat_df = concat_df[concat_df['sec_secondary_trauma_ind']!=1]

# Keep only 90 mt and above
concat_df = concat_df[concat_df['less_than_90_bene_served']!=1]

# Keep 30 miles and below
concat_df = concat_df[concat_df['MILES']<=30]

# Keep if hospitals are within 9 mile radius
concat_df = concat_df[concat_df['choice_ind_mi9']==1]

# Read out prepared data to bypass reindexing error from concatenating
concat_df.to_csv('/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/data_for_graphs/9mi_all_hos_types.csv',index=False)

#___ Graph distributions using prepared data ___#

# Read in
concat_df = pd.read_csv('/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/data_for_graphs/9mi_all_hos_types.csv')

#--- NISS ---#

# Store means in variables
tl_one_mean_niss = concat_df[concat_df['TRAUMA_LEVEL']=='1']['niss'].mean()
nt_mean_niss = concat_df[concat_df['TRAUMA_LEVEL']=='NT']['niss'].mean()

# Plot graph and text to display mean
sns.histplot(data=concat_df[concat_df['TRAUMA_LEVEL']=='1'],x='niss',alpha=0.9,zorder=0,stat='percent',color='darkorchid',edgecolor='rebeccapurple',bins=40).annotate('Lvl 1 mean', xy=(tl_one_mean_niss, 30), xytext=(tl_one_mean_niss+8, 30),arrowprops=dict(facecolor='darkorchid', edgecolor='rebeccapurple'))
sns.histplot(data=concat_df[concat_df['TRAUMA_LEVEL']=='NT'],x='niss',alpha=0.8,zorder=1,stat='percent',color='powderblue',edgecolor='cadetblue',bins=35).annotate('Non-trauma mean', xy=(nt_mean_niss, 40), xytext=(nt_mean_niss+10, 40),arrowprops=dict(facecolor='powderblue', edgecolor='cadetblue'))

# Plot a line that resembles the mean. ymin and ymax options do NOT refer to the coordinates
plt.axvline(x=tl_one_mean_niss,ymin=0,ymax=1,color='darkorchid',zorder=0)
plt.axvline(x=nt_mean_niss,ymin=0,ymax=1,color='cadetblue',zorder=1)

plt.xlabel('New injury severity score')  # x label
plt.ylabel('Percent')  # y label
legend_elements = [Patch(facecolor='darkorchid', edgecolor='rebeccapurple', label='Level 1',alpha=0.9),
                   Patch(facecolor='powderblue', edgecolor='cadetblue', label='Non-trauma',alpha=0.8)]
plt.legend(handles=legend_elements, fontsize='small', loc='center right', title=None,frameon=False)

sns.despine()  # Trim off the edges that are not the axis
plt.savefig(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/figures/9mi_niss_dist.pdf',bbox_inches="tight")  # Save figure

plt.show()
plt.close()

#--- COUNT OF DX CODES ---#
# num_of_diag_codes_nodup only has a count of unique injury dx codes

# Store means in variables
tl_one_mean_dx = concat_df[concat_df['TRAUMA_LEVEL']=='1']['num_of_diag_codes_nodup'].mean()
nt_mean_dx = concat_df[concat_df['TRAUMA_LEVEL']=='NT']['num_of_diag_codes_nodup'].mean()

# Plot graph and text to display mean ,bins=40
sns.histplot(data=concat_df[concat_df['TRAUMA_LEVEL']=='1'],x='num_of_diag_codes_nodup',alpha=0.9,zorder=0,stat='percent',color='darkorchid',edgecolor='rebeccapurple',bins=30).annotate('Lvl 1 mean', xy=(tl_one_mean_dx, 30), xytext=(tl_one_mean_dx+2, 30),arrowprops=dict(facecolor='darkorchid', edgecolor='rebeccapurple'))
sns.histplot(data=concat_df[concat_df['TRAUMA_LEVEL']=='NT'],x='num_of_diag_codes_nodup',alpha=0.8,zorder=1,stat='percent',color='powderblue',edgecolor='cadetblue',bins=20).annotate('Non-trauma mean', xy=(nt_mean_dx, 40), xytext=(nt_mean_dx+2, 40),arrowprops=dict(facecolor='powderblue', edgecolor='cadetblue'))

# Plot a line that resembles the mean. ymin and ymax options do NOT refer to the coordinates
plt.axvline(x=tl_one_mean_dx,ymin=0,ymax=1,color='darkorchid',zorder=0)
plt.axvline(x=nt_mean_dx,ymin=0,ymax=1,color='cadetblue',zorder=1)

plt.xticks([*range(0,20)]) # change range of x axis

plt.xlabel('Unique injury diagnosis codes reported')  # x label
plt.ylabel('Percent')  # y label
legend_elements = [Patch(facecolor='darkorchid', edgecolor='rebeccapurple', label='Level 1',alpha=0.9),
                   Patch(facecolor='powderblue', edgecolor='cadetblue', label='Non-trauma',alpha=0.8)]
plt.legend(handles=legend_elements, fontsize='small', loc='center right', title=None,frameon=False)

sns.despine()  # Trim off the edges that are not the axis
plt.savefig(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/figures/9mi_num_of_dx_nodup.pdf',bbox_inches="tight")  # Save figure

plt.show()
plt.close()


# scp jessyjkn@phs-rs24.bsd.uchicago.edu:/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/figures/9mi_num_of_dx_nodup.pdf /Users/jessyjkn/Desktop/Job/figures_from_server/trauma_center_project/reg_final_exhibits/
# scp jessyjkn@phs-rs24.bsd.uchicago.edu:/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/figures/9mi_niss_dist.pdf /Users/jessyjkn/Desktop/Job/figures_from_server/trauma_center_project/reg_final_exhibits/






