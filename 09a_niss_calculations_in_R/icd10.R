# Read in packages
library(icdpicr)
#library(tidyverse)

# Step 1: Read in data with all dx as characters (remember to specify the years you need)
data.in <- read.csv('/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/niss_calculation/for_R/2019_after_drop_duplicates.csv', stringsAsFactors = F)

# Step 2: Find AIS and ISS (for ICD10, this will use the gem min method by default)
data.out <- cat_trauma(data.in,'dx',icd10='cm', i10_iss_method='gem_min')

# Step 3: Read out data
write.csv(data.out,'/mnt/labshares/sanghavi-lab/Jessy/data/trauma_center_project_all_hos_claims/niss_calculation/from_R/2019_icdpic_r_output.csv')


