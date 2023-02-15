#----------------------------------------------------------------------------------------------------------------------#
# Project: (REG) Trauma center analysis using Medicare data
# Author: Jessy Nguyen
# Last Updated: February 8, 2023
# Description: The script will create figures 1, 2, and 3
#----------------------------------------------------------------------------------------------------------------------#

############################################# IMPORT MODULES ###########################################################

# Read in relevant libraries
from datetime import datetime, timedelta
import pandas as pd
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt
from matplotlib.patches import Patch

############################################# CHOICE V NO CHOICE GRAPH #################################################
# Figure 2

#_____________________ PANEL A _______________________#

col = ['_margin','_term','_m1','_m2']

mile_binary = [4] # focus on > 4 or <=4 miles

radius=[3,5]

for b in mile_binary:

    df_dict_c_nc = {}

    df_list_c_nc = []

    for r in radius:

        for c in ['choice','nochoice']:

            # Read in all data needed
            df_dict_c_nc[str(r)+c] = pd.read_stata(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/merged_ats_claims_for_stata/radius{r}_binary{b}_{c}_panel_a.dta',columns=col)

            # Keep if row corresponds to interaction
            df_dict_c_nc[str(r)+c] = df_dict_c_nc[str(r)+c][df_dict_c_nc[str(r)+c]['_term']=='treatment#amb_type']

            # Relabel _m1 (binary for hospital type)
            df_dict_c_nc[str(r)+c]['hos_type'] = ''
            df_dict_c_nc[str(r)+c].loc[df_dict_c_nc[str(r)+c]['_m1']==1,'hos_type'] = 'lvl1'
            df_dict_c_nc[str(r)+c].loc[df_dict_c_nc[str(r)+c]['_m1']==0,'hos_type'] = 'NT'

            # Create another columns combining hospital type and bls. Will be used to graph
            df_dict_c_nc[str(r)+c]['_m2'] = df_dict_c_nc[str(r)+c]['_m2'].astype(str)
            df_dict_c_nc[str(r)+c]['hos_amb_type'] = df_dict_c_nc[str(r)+c]['hos_type'] + "_" + df_dict_c_nc[str(r)+c]['_m2']

            # Create new labels
            if (r in [3]):
                df_dict_c_nc[str(r)+c]['Radius'] = f'{r} miles'
            if (r in [5]):
                df_dict_c_nc[str(r)+c]['Radius'] = f'{r} miles'

            # Create new labels for hue when graphing bars
            if (c in ['choice']):
                df_dict_c_nc[str(r)+c]['Area type'] = "Both hospital types in area"
            if (c in ['nochoice']):
                df_dict_c_nc[str(r)+c]['Area type'] = "No other hospitals in area"

            # Append df name to list
            df_list_c_nc.append(df_dict_c_nc[str(r) + c])

    # Concat all
    concat_df = pd.concat(df_list_c_nc, axis=0)

    # Convert to percent
    concat_df['_margin'] = concat_df['_margin'] * 100

    # Rename
    concat_df['Adjusted 30 day mortality (%)'] = concat_df['_margin']

    #___ Graph ___#

    hue_order = ['NT_BLS', 'lvl1_BLS', 'NT_ALS', 'lvl1_ALS']
    palette_colors = {"NT_BLS": "blue", "lvl1_BLS": "green", "NT_ALS": "orange", "lvl1_ALS": "red"}
    ax = sns.catplot(x="Area type", y="Adjusted 30 day mortality (%)", hue = "hos_amb_type", col = "Radius", data = concat_df, kind = "bar",legend=False,hue_order=hue_order,palette=palette_colors)

    #___ Apply additional colors to specific bars ___#
    for ax in ax.axes.ravel(): # need this to bypass error 'FacetGrid' object has no attribute 'patches'
        for i,thisbar in enumerate(ax.patches): # Loop through each bar
            if i in [0,1,8,9]: # Define positions of bar
                color = "navy"
            elif i in [2,3,10,11]: # Define positions of bar
                color = "darkgreen"
            elif i in [4,5,12,13]: # Define positions of bar
                color = "darkgoldenrod"
            elif i in [6,7,14,15]: # Define positions of bar
                color = "maroon"

            # Change edge color using above color specifications
            thisbar.set_edgecolor(color)

            # Set specifications for bar modifications to decrease size of bar and change position
            current_width = thisbar.get_width()
            diff = current_width - (-0.15)

            # Change the bar width
            thisbar.set_width(-0.15)

            # Recenter the bar using specifications
            thisbar.set_x(thisbar.get_x() + diff * .5)

    #--- Set up legend ---#
    c1 = Patch(facecolor='blue',edgecolor='navy')
    c2 = Patch(facecolor='green',edgecolor='darkgreen')
    c3 = Patch(facecolor='orange',edgecolor='darkgoldenrod')
    c4 = Patch(facecolor='red',edgecolor='maroon')
    #
    legend1 = plt.legend(handles=[c1, c2, c3, c4],
              labels=['BLS to Non-trauma','BLS to Lvl 1','ALS to Non-trauma','ALS to Lvl 1'],
              ncol=1, handletextpad=0.5, handlelength=1.0, columnspacing=-0.5,
              fontsize='small',bbox_to_anchor=(1, 1), loc=2, borderaxespad=0,title=None, frameon=False)

    sns.despine()  # Trim off the edges that are not the axis

    plt.savefig(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/figures/exhibit4_binary{b}_panel_a.pdf',bbox_inches="tight")  # Save figure

    plt.show()
    plt.close()
#_____________________ PANEL B _______________________#

col = ['_margin','_m1']

mile_binary = [3,4,5]

radius=[3,5]

for b in mile_binary:

    df_dict_c_nc = {}

    df_list_c_nc = []

    for r in radius:

        for c in ['choice','nochoice']:

            # Read in
            df_dict_c_nc[str(r)+c] = pd.read_stata(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/merged_ats_claims_for_stata/radius{r}_binary{b}_{c}_panel_b.dta',columns=col)

            # Create new values for x axis when graphing bars (use empty spaces for now)
            if r in [3]:
                df_dict_c_nc[str(r)+c]['for_x'] = ' '
            if r in [5]:
                df_dict_c_nc[str(r)+c]['for_x'] = '  '

            # Create new labels for hue when graphing bars
            if c in ['choice']:
                df_dict_c_nc[str(r)+c]['for_hue'] = 'choice'
            if c in ['nochoice']:
                df_dict_c_nc[str(r)+c]['for_hue'] = 'nochoice'

            # Append df name to list
            df_list_c_nc.append(df_dict_c_nc[str(r)+c])

    # Concat all
    concat_df = pd.concat(df_list_c_nc,axis=0)

    # Convert to percent
    concat_df['_margin'] = concat_df['_margin'] * 100

    # Split into two dfs (less mi and more mi)
    concat_df_less = concat_df[concat_df['_m1']=='less_mi']
    concat_df_more = concat_df[concat_df['_m1']=='more_mi']

    # Specify colors
    palette_less ={"choice": "maroon", "nochoice": "midnightblue"}
    palette_more ={"choice": "lightsalmon", "nochoice": "lightblue"}

    #___ graph for less mileage ___#
    ax = sns.barplot(data=concat_df_less,x="for_x",y='_margin',hue='for_hue',zorder=1,alpha=1,palette=palette_less)

    #___ graph for more mileage ___#
    sns.barplot(data=concat_df_more,x="for_x",y='_margin',hue='for_hue',zorder=0,alpha=0.7,ax=ax,palette=palette_more)

    #___ Manually create x labels ___#

    plt.text(-0.23, -2, "Both hospital \ntypes in area", horizontalalignment='center', size='medium', color='black')
    plt.text(0.20, -2, "No other \nhospitals in area", horizontalalignment='center', size='medium', color='black')
    plt.text(.77, -2, "Both hospital \ntypes in area", horizontalalignment='center', size='medium', color='black')
    plt.text(1.20, -2, "No other \nhospitals in area", horizontalalignment='center', size='medium', color='black')

    plt.text(0, -3.2, "Radius = 3 miles", horizontalalignment='center', size='medium', color='black')
    plt.text(0.99, -3.2, "Radius = 5 miles", horizontalalignment='center', size='medium', color='black')

    plt.tight_layout() # include everything

    #___ Apply additional colors to specific bars ___#
    for i,thisbar in enumerate(ax.patches): # Loop through each bar
        if i in [0,1]: # Define positions of bar
            color = "darkslategray"
        elif i in [2,3]: # Define positions of bar
            color = "darkslategray"
        elif i in [4,5]: # Define positions of bar
            color = "maroon"
        elif i in [6,7]: # Define positions of bar
            color = "navy"

        # Change edge color using above color specifications
        thisbar.set_edgecolor(color)

        # Set specifications for bar modifications to decrease size of bar and change position
        current_width = thisbar.get_width()
        diff = current_width - (-0.19)

        # Change the bar width
        thisbar.set_width(-0.19)

        # Recenter the bar using specifications
        thisbar.set_x(thisbar.get_x() + diff * .5)

        # After centering, we want to offset the bars in the back
        if i in [*range(0,4)]:

            thisbar.set_x(thisbar.get_x() + .05)

        elif i in [*range(4,8)]:

            thisbar.set_x(thisbar.get_x() - .05)

    # Plot star to signify statistical significance differences (see stata output if difference is significant)
    plt.plot(-0.20, 21, linewidth=1, color='black',marker='*',ms=10)
    plt.plot(0.80, 21, linewidth=1, color='black',marker='*',ms=10)

    plt.xlabel(' ')
    plt.ylabel('Adjusted 30 day mortality (%)')  # y label

    #--- Set up legend ---#
    pl1 = Patch(facecolor='maroon',edgecolor='darkslategray') # less mi
    pm1 = Patch(facecolor='lightsalmon',alpha=0.5,edgecolor='maroon') # more mi
    #
    pl2 = Patch(facecolor='midnightblue',edgecolor='darkslategray') # less mi
    pm2 = Patch(facecolor='lightblue',alpha=0.5,edgecolor='navy') # more mi
    #
    legend2 = plt.legend(handles=[pl1, pm1, pl2, pm2],
              labels=['', '',f'Traveled ≤ {b} miles',f'Traveled > {b} miles'],
              ncol=2, handletextpad=0.5, handlelength=1.0, columnspacing=-0.5,
              fontsize='small', loc="best",title=None, frameon=False)

    sns.despine()  # Trim off the edges that are not the axis

    plt.savefig(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/figures/exhibit4_binary{b}_panel_b.pdf',bbox_inches="tight")  # Save figure

    plt.show()
    plt.close()

    del df_dict_c_nc
    del df_list_c_nc


# For appendix
# scp jessyjkn@phs-rs24.bsd.uchicago.edu:/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/figures/exhibit4_binary3_panel_b.pdf /Users/jessyjkn/Desktop/Job/figures_from_server/trauma_center_project/reg_final_exhibits/
# scp jessyjkn@phs-rs24.bsd.uchicago.edu:/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/figures/exhibit4_binary5_panel_b.pdf /Users/jessyjkn/Desktop/Job/figures_from_server/trauma_center_project/reg_final_exhibits/

# for main exhibit
# scp jessyjkn@phs-rs24.bsd.uchicago.edu:/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/figures/exhibit4_binary4_panel_a.pdf /Users/jessyjkn/Desktop/Job/figures_from_server/trauma_center_project/reg_final_exhibits/
# scp jessyjkn@phs-rs24.bsd.uchicago.edu:/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/figures/exhibit4_binary4_panel_b.pdf /Users/jessyjkn/Desktop/Job/figures_from_server/trauma_center_project/reg_final_exhibits/


########################################## HISTOGRAMS ##################################################################

# FOR (1) NISS, (2) COUNT OF DX CODES, (3) POPULATION ON COUNTY LEVEL ,and (4) TRAFFIC PROXIMITY

#_________ Prepare data and read out in csv___________#

# Specify columns
col = ['amb_ind','State_Des','ACS_Ver','parts_ab_ind','niss','RTI_RACE_CD','SEX_IDENT_CD','sec_secondary_trauma_ind','less_than_90_bene_served','MILES','num_of_diag_codes_nodup','PTRAF_dist6','PTRAF_dist5','PTRAF_dist3','PTRAF_dist9','tot_pop_in_cnty','only_hos_at_mi6','only_hos_at_mi3','choice_ind_mi6','choice_ind_mi3','only_hos_at_mi5','choice_ind_mi5']

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

# Read out prepared data to bypass reindexing error from concatenating
concat_df.to_csv('/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/data_for_graphs/all_hos_types.csv',index=False)

#___ Graph distributions using prepared data ___#

# Read in
concat_df = pd.read_csv('/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/data_for_graphs/all_hos_types.csv')

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
plt.savefig(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/figures/niss_dist.pdf',bbox_inches="tight")  # Save figure

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
plt.savefig(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/figures/num_of_dx_nodup.pdf',bbox_inches="tight")  # Save figure

plt.show()
plt.close()

#--- POPULATION ---#

# Store means in variables
choice_mean_pop = concat_df[(concat_df['choice_ind_mi5']==1)&(concat_df['TRAUMA_LEVEL'].isin(['1','NT']))]['tot_pop_in_cnty'].mean()
nochoice_mean_pop = concat_df[(concat_df['only_hos_at_mi5']==1)&(concat_df['TRAUMA_LEVEL'].isin(['1','NT']))]['tot_pop_in_cnty'].mean()

# Plot graph and text to display mean
sns.histplot(data=concat_df[(concat_df['choice_ind_mi5']==1)&(concat_df['TRAUMA_LEVEL'].isin(['1','NT']))],x='tot_pop_in_cnty',alpha=0.8,zorder=0,stat='percent',color='coral',edgecolor='orangered',bins=40).annotate('', xy=(choice_mean_pop, 25), xytext=(choice_mean_pop+1400000, 29.5),arrowprops=dict(facecolor='coral', edgecolor='orangered'))
sns.histplot(data=concat_df[(concat_df['only_hos_at_mi5']==1)&(concat_df['TRAUMA_LEVEL'].isin(['1','NT']))],x='tot_pop_in_cnty',alpha=0.8,zorder=1,stat='percent',color='cornflowerblue',edgecolor='royalblue',bins=20).annotate('Mean', xy=(nochoice_mean_pop, 27), xytext=(nochoice_mean_pop+2100000, 30),arrowprops=dict(facecolor='cornflowerblue', edgecolor='royalblue'))

# Get rid of scientific notation
plt.ticklabel_format(style='plain', axis='x')

# Plot a line that resembles the mean. ymin and ymax options do NOT refer to the coordinates
plt.axvline(x=choice_mean_pop,ymin=0,ymax=1,color='coral',zorder=0)
plt.axvline(x=nochoice_mean_pop,ymin=0,ymax=1,color='cornflowerblue',zorder=1)

plt.xlabel('Population (county)')  # x label
plt.ylabel('Percent')  # y label
legend_elements = [Patch(facecolor='coral', edgecolor='orangered', label='Both hospital types in area',alpha=0.8),
                   Patch(facecolor='cornflowerblue', edgecolor='royalblue', label='No other hospitals in area',alpha=0.8)]
plt.legend(handles=legend_elements, fontsize='small', loc='upper right', title=None,frameon=False)

sns.despine()  # Trim off the edges that are not the axis
plt.savefig(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/figures/tot_pop_in_cnty.pdf',bbox_inches="tight")  # Save figure

plt.show()
plt.close()

#--- TRAFFIC PROXIMITY ---#

mi_n = [3,5] # using mile radius 3 and 5

for mi_n in mi_n:

    # Store means in variables (choice/nochoice AND traffic proximity at 3 mile radius)
    choice_mean_traf = concat_df[(concat_df[f'choice_ind_mi{mi_n}']==1)&(concat_df['TRAUMA_LEVEL'].isin(['1','NT']))][f'PTRAF_dist{mi_n}'].mean() # 3 mile radius
    nochoice_mean_traf = concat_df[(concat_df[f'only_hos_at_mi{mi_n}']==1)&(concat_df['TRAUMA_LEVEL'].isin(['1','NT']))][f'PTRAF_dist{mi_n}'].mean() # 3 mile radius

    # Plot graph and text to display mean (choice/nochoice AND traffic proximity at 3 mile radius) (Note: i see that as we shorten radius of traffic proximity, we may see higher. Note that these are averages so the larger the radius, the more blocks that have smaller traffic are considered in the average so the average may go down)
    sns.histplot(data=concat_df[(concat_df[f'choice_ind_mi{mi_n}']==1)&(concat_df['TRAUMA_LEVEL'].isin(['1','NT']))],x=f'PTRAF_dist{mi_n}',alpha=0.8,zorder=0,stat='percent',color='coral',edgecolor='orangered',bins=40).annotate('Mean', xy=(choice_mean_traf, 15.5), xytext=(choice_mean_traf+450, 18.5),arrowprops=dict(facecolor='coral', edgecolor='orangered'))
    if mi_n in [5]:
        sns.histplot(data=concat_df[(concat_df[f'only_hos_at_mi{mi_n}']==1)&(concat_df['TRAUMA_LEVEL'].isin(['1','NT']))],x=f'PTRAF_dist{mi_n}',alpha=0.8,zorder=1,stat='percent',color='cornflowerblue',edgecolor='royalblue',bins=20).annotate(' ', xy=(nochoice_mean_traf, 15.5), xytext=(nochoice_mean_traf+1700, 18.5),arrowprops=dict(facecolor='cornflowerblue', edgecolor='royalblue'))
    else:
        sns.histplot(data=concat_df[(concat_df[f'only_hos_at_mi{mi_n}']==1)&(concat_df['TRAUMA_LEVEL'].isin(['1','NT']))],x=f'PTRAF_dist{mi_n}',alpha=0.8,zorder=1,stat='percent',color='cornflowerblue',edgecolor='royalblue',bins=35).annotate(' ', xy=(nochoice_mean_traf, 15.5), xytext=(nochoice_mean_traf+1650, 18.3),arrowprops=dict(facecolor='cornflowerblue', edgecolor='royalblue'))

    # Plot a line that resembles the mean. ymin and ymax options do NOT refer to the coordinates
    plt.axvline(x=choice_mean_traf,ymin=0,ymax=1,color='coral',zorder=0)
    plt.axvline(x=nochoice_mean_traf,ymin=0,ymax=1,color='cornflowerblue',zorder=1)

    plt.xlabel(f'Traffic proximity ({mi_n}-mile radius)')  # x label
    plt.ylabel('Percent')  # y label
    legend_elements = [Patch(facecolor='coral', edgecolor='orangered', label='Both hospital types in area',alpha=0.8),
                       Patch(facecolor='cornflowerblue', edgecolor='royalblue', label='No other hospitals in area',alpha=0.8)]
    plt.legend(handles=legend_elements, fontsize='small', loc='upper right', title=None,frameon=False)

    sns.despine()  # Trim off the edges that are not the axis
    plt.savefig(f'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/figures/trffc_prox_{mi_n}.pdf',bbox_inches="tight")  # Save figure

    plt.show()
    plt.close()

# scp jessyjkn@phs-rs24.bsd.uchicago.edu:/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/figures/tot_pop_in_cnty.pdf /Users/jessyjkn/Desktop/Job/figures_from_server/trauma_center_project/reg_final_exhibits/
# scp jessyjkn@phs-rs24.bsd.uchicago.edu:/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/figures/num_of_dx_nodup.pdf /Users/jessyjkn/Desktop/Job/figures_from_server/trauma_center_project/reg_final_exhibits/
# scp jessyjkn@phs-rs24.bsd.uchicago.edu:/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/figures/niss_dist.pdf /Users/jessyjkn/Desktop/Job/figures_from_server/trauma_center_project/reg_final_exhibits/
# scp jessyjkn@phs-rs24.bsd.uchicago.edu:/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/figures/trffc_prox_5.pdf /Users/jessyjkn/Desktop/Job/figures_from_server/trauma_center_project/reg_final_exhibits/

# For appendix
# scp jessyjkn@phs-rs24.bsd.uchicago.edu:/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims_for_reg/figures/trffc_prox_3.pdf /Users/jessyjkn/Desktop/Job/figures_from_server/trauma_center_project/reg_final_exhibits/







