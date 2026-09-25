-- 48's network_persisted_l1_observation, latest row: its three paths, each answered from a carry.
WITH RECURSIVE
w_refresh AS (
SELECT block_number, block_hash, log_index, false AS length_update
FROM issuance_allocator__target_allocation_updated
WHERE target = '0x971b9d3d0ae3eca029cab5ea1fb0f72c85e6a525'
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM l2_gateway__withdrawal_initiated
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM l2_gateway__deposit_finalized
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM graph_payments__graph_payment_collected
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM dispute_legacy__parameter_updated
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM dispute_horizon__arbitrator_set
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM dispute_horizon__dispute_accepted
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM dispute_horizon__dispute_period_set
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM dispute_horizon__fisherman_reward_cut_set
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM dispute_horizon__max_slashing_cut_set
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM graph_token__transfer
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM graph_token__approval
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM controller__set_contract_proxy
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM controller__new_ownership
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM controller__partial_pause_changed
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM controller__pause_changed
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM controller__new_pause_guardian
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM epoch_manager__epoch_run
UNION ALL
SELECT block_number, block_hash, log_index, true AS length_update FROM epoch_manager__epoch_length_update
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM subgraph_service__allocation_closed
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM subgraph_service__allocation_created
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM subgraph_service__indexing_rewards_collected
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM subgraph_service__query_fees_collected
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM subgraph_service__p_o_i_presented
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM staking_legacy__allocation_collected
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM staking_legacy__rebate_claimed
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM staking_legacy__allocation_closed_f672
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM staking_legacy__allocation_closed_7203
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM staking_legacy__allocation_created
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM staking_legacy__asset_holder_update
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM staking_legacy__delegation_parameters_updated
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM staking_legacy__rebate_collected
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM staking_legacy__slasher_update
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM staking_legacy__stake_delegated_locked
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM staking_legacy__stake_deposited
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM staking_legacy__stake_locked
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM staking_legacy__stake_slashed
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM staking_legacy__stake_withdrawn
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM staking_parameters__parameter_updated
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM gns__n_signal_burned
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM gns__n_signal_minted
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM gns__subgraph_deprecated_cd16
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM gns__subgraph_deprecated_905d
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM gns__signal_burned
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM gns__signal_minted
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM horizon_staking__delegation_slashed
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM horizon_staking__delegation_slashing_enabled
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM horizon_staking__horizon_stake_deposited
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM horizon_staking__horizon_stake_locked
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM horizon_staking__horizon_stake_withdrawn
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM horizon_staking__max_thawing_period_set
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM horizon_staking__provision_created
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM horizon_staking__provision_increased
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM horizon_staking__provision_slashed
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM horizon_staking__provision_thawed
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM horizon_staking__thawing_period_cleared
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM horizon_staking__tokens_deprovisioned
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM horizon_staking__tokens_to_delegation_pool_added
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM horizon_staking__tokens_undelegated
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM rewards__parameter_updated
UNION ALL
SELECT block_number, block_hash, log_index, false AS length_update FROM rewards__rewards_assigned
UNION ALL
SELECT r.block_number, r.block_hash, r.log_index, false AS length_update
FROM rewards__horizon_rewards_assigned r
WHERE EXISTS (SELECT 1 FROM legacy_allocs__carry a WHERE a.id = r."allocationID")
   OR EXISTS (
       SELECT 1 FROM staking_legacy__allocation_created a WHERE a."allocationID" = r."allocationID"
       AND (a.block_number < r.block_number OR (a.block_number = r.block_number AND a.log_index <= r.log_index))
   )
), w_v4 AS (
SELECT e.block_number, e.log_index, e.length_update,
       CASE WHEN c.result IS NULL THEN error('network epoch clock requires a pinned EpochManager.blockNum() read')
            WHEN c.reverted OR c.result = '0x' THEN 0
            ELSE CAST(nuthatch_uint256(c.result) AS BIGINT) END AS l1_block
FROM w_refresh e
LEFT JOIN epoch_manager_l1_block c ON c.block_number = e.block_number AND c.block_hash = e.block_hash
),
w_len AS (
SELECT block_number, log_index, epoch, length, l1_block,
       (SELECT coalesce(max(seq), 0) FROM schedule__carry)
         + row_number() OVER (ORDER BY block_number, log_index) AS seq
FROM epoch_length_event
), w_sched(seq, block_number, log_index, epoch, length, start_block) AS (
    SELECT * FROM (
        SELECT seq, block_number, log_index, epoch, length, start_block FROM schedule__carry
        UNION ALL
        SELECT seq, block_number, log_index, epoch, length, l1_block FROM w_len WHERE seq = 1
    )
    UNION ALL
    SELECT e.seq, e.block_number, e.log_index, e.epoch, e.length,
           s.start_block + ((e.l1_block - s.start_block) // s.length) * s.length
    FROM w_sched s JOIN w_len e ON e.seq = s.seq + 1
),
clock_stream AS (
    SELECT 0::UBIGINT AS block_number, 0::UBIGINT AS log_index, false AS length_update,
           last_l1 AS l1_block, true AS pseudo FROM clock__carry
    UNION ALL SELECT block_number, log_index, length_update, l1_block, false FROM w_v4
    UNION ALL SELECT block_number, log_index, false, NULL::BIGINT, false FROM curation__signalled
), observations AS (
    SELECT block_number, log_index, length_update, pseudo,
           coalesce(l1_block, last_value(l1_block IGNORE NULLS) OVER (
               ORDER BY block_number, log_index
               ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
           ), 0) AS l1_block
    FROM clock_stream
), w_obs AS (
SELECT o.block_number, o.log_index, o.l1_block, s.length,
       CASE WHEN o.length_update THEN s.epoch
            ELSE s.epoch + (o.l1_block - s.start_block) // s.length END AS epoch,
       CASE WHEN o.length_update THEN s.start_block
            ELSE s.start_block + ((o.l1_block - s.start_block) // s.length) * s.length END AS start_block
FROM observations o
JOIN LATERAL (
    SELECT * FROM w_sched s
    WHERE s.block_number < o.block_number OR (s.block_number = o.block_number AND s.log_index <= o.log_index)
    ORDER BY s.block_number DESC, s.log_index DESC LIMIT 1
) s ON true
WHERE o.l1_block > 0 AND NOT o.pseudo
),
w_persisted AS (
SELECT o.block_number, o.log_index, o.l1_block
FROM w_v4 o
WHERE NOT EXISTS (
    SELECT 1 FROM graph_token__approval a
    WHERE a.block_number = o.block_number AND a.log_index = o.log_index
) AND NOT EXISTS (
    SELECT 1 FROM subgraph_service__p_o_i_presented p
    WHERE p.block_number = o.block_number AND p.log_index = o.log_index
) AND NOT EXISTS (
    SELECT 1 FROM staking_legacy__delegation_parameters_updated p
    WHERE p.block_number = o.block_number AND p.log_index = o.log_index
      AND (EXISTS (SELECT 1 FROM indexers__carry i WHERE i.indexer = p.indexer)
           OR EXISTS (
          SELECT 1 FROM indexer_identity_event i WHERE i.indexer = p.indexer
          AND (i.block_number < p.block_number OR
               (i.block_number = p.block_number AND i.log_index < p.log_index))
      ))
) AND NOT EXISTS (
    SELECT 1 FROM graph_token__transfer t
    WHERE t.block_number = o.block_number AND t.log_index = o.log_index
      AND (t."from" = t."to" OR
           (t."from" <> '0x0000000000000000000000000000000000000000'
            AND t."to" <> '0x0000000000000000000000000000000000000000'))
)
UNION ALL
SELECT block_number, log_index, l1_block FROM (
    SELECT block_number, log_index, l1_block, epoch,
           row_number() OVER (PARTITION BY epoch ORDER BY block_number, log_index) AS ordinal
    FROM w_obs
) first_epoch WHERE ordinal = 1 AND epoch NOT IN (SELECT epoch FROM epochs__carry)
UNION ALL
SELECT block_number, log_index, l1_block FROM (
    SELECT block_number, log_index, l1_block FROM w_v4 ORDER BY block_number, log_index LIMIT 1
) initial_network WHERE NOT coalesce((SELECT any_v4 FROM clock__carry), false)
)
SELECT block_number, log_index, l1_block FROM (
    SELECT block_number, log_index, l1_block FROM persisted__carry
    UNION ALL SELECT block_number, log_index, l1_block FROM w_persisted
) ORDER BY block_number DESC, log_index DESC LIMIT 1
