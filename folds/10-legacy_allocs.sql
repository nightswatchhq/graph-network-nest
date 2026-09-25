-- Every legacy allocation id: 26 reads allocation_creation's history to filter HorizonRewardsAssigned.
SELECT DISTINCT "allocationID" AS id FROM staking_legacy__allocation_created
