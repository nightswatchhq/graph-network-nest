-- The legacy allocations that can still be rewarded. A legacy allocation takes rewards once, when it
-- closes, so after its reward event it can never be one 26's filter needs: dropped (#1503).
SELECT id FROM (
    SELECT id FROM legacy_allocs__carry
    UNION
    SELECT "allocationID" AS id FROM staking_legacy__allocation_created
) s
WHERE NOT EXISTS (SELECT 1 FROM rewards__rewards_assigned r WHERE r."allocationID" = s.id)
  AND NOT EXISTS (SELECT 1 FROM rewards__horizon_rewards_assigned r WHERE r."allocationID" = s.id)
