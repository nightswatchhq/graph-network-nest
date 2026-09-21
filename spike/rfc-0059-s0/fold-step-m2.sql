-- One fold step over the window the raw layer is bound to: carries in from __PREV__,
-- carries out to __OUT__. Nothing here can see history except through a carry.

CREATE TEMP TABLE c_sched AS SELECT * FROM read_parquet('__PREV__/c_sched.parquet');
CREATE TEMP TABLE c_clock AS SELECT * FROM read_parquet('__PREV__/c_clock.parquet');
CREATE TEMP TABLE c_epochs AS SELECT * FROM read_parquet('__PREV__/c_epochs.parquet');
CREATE TEMP TABLE c_persisted AS SELECT * FROM read_parquet('__PREV__/c_persisted.parquet');
CREATE TEMP TABLE c_latest_obs AS SELECT * FROM read_parquet('__PREV__/c_latest_obs.parquet');
CREATE TEMP TABLE c_indexers AS SELECT * FROM read_parquet('__PREV__/c_indexers.parquet');
CREATE TEMP TABLE c_legacy_allocs AS SELECT * FROM read_parquet('__PREV__/c_legacy_allocs.parquet');
CREATE TEMP TABLE c_pause AS SELECT * FROM read_parquet('__PREV__/c_pause.parquet');
CREATE TEMP TABLE c_last_run AS SELECT * FROM read_parquet('__PREV__/c_last_run.parquet');

-- Set-membership carries re-enter the nest's own views as events at block 0, so the original
-- EXISTS rules in 26-network-clock and 48-network-clock-saved run unchanged.
-- Bodies copied from views/20-allocations.sql and views/45-indexer.sql.
CREATE OR REPLACE VIEW allocation_creation AS
SELECT id, NULL::VARCHAR AS indexer, NULL::VARCHAR AS deployment, NULL::VARCHAR AS tokens, NULL::INTEGER AS epoch,
       0::UBIGINT AS block_number, NULL::VARCHAR AS block_hash, NULL::UBIGINT AS block_timestamp,
       0::UBIGINT AS log_index, true AS legacy
FROM c_legacy_allocs
UNION ALL
SELECT "allocationId" AS id, indexer, "subgraphDeploymentId" AS deployment, tokens,
       CAST("currentEpoch" AS INTEGER) AS epoch, block_number, block_hash, block_timestamp, log_index, false AS legacy
FROM subgraph_service__allocation_created
UNION ALL
SELECT "allocationID", indexer, "subgraphDeploymentID", tokens, CAST(epoch AS INTEGER),
       block_number, block_hash, block_timestamp, log_index, true FROM staking_legacy__allocation_created;

CREATE OR REPLACE VIEW w_identity_event AS
SELECT indexer, block_number, log_index, block_timestamp, true AS legacy FROM staking_legacy__stake_deposited
UNION ALL SELECT indexer, block_number, log_index, block_timestamp, true FROM staking_legacy__stake_delegated
UNION ALL SELECT indexer, block_number, log_index, block_timestamp, true FROM staking_legacy__delegation_parameters_updated
UNION ALL SELECT indexer, block_number, log_index, block_timestamp, true FROM service_registry__service_registered
UNION ALL SELECT indexer, block_number, log_index, block_timestamp, false FROM horizon_registration WHERE registration IS NOT NULL
UNION ALL SELECT "serviceProvider", block_number, log_index, block_timestamp, NULL FROM horizon_staking__horizon_stake_deposited
UNION ALL SELECT "serviceProvider", block_number, log_index, block_timestamp, NULL FROM horizon_staking__tokens_delegated
UNION ALL SELECT "serviceProvider", block_number, log_index, block_timestamp, NULL FROM horizon_staking__delegation_fee_cut_set
UNION ALL SELECT indexer, block_number, log_index, block_timestamp, NULL FROM subgraph_service__rewards_destination_set;

CREATE OR REPLACE VIEW indexer_identity_event AS
SELECT indexer, 0::UBIGINT AS block_number, 0::UBIGINT AS log_index, NULL::UBIGINT AS block_timestamp,
       NULL::BOOLEAN AS legacy FROM c_indexers
UNION ALL SELECT * FROM w_identity_event;

-- The window's refresh observations: 26's view, now carry-aware through allocation_creation.
CREATE TEMP TABLE w_v4 AS SELECT block_number, log_index, length_update, l1_block FROM network_l1_observation;

-- Epoch schedule: the carry row is the recursion's base; a genesis window starts from seq 1.
CREATE TEMP TABLE w_len AS
SELECT block_number, log_index, epoch, length, l1_block,
       (SELECT coalesce(max(seq), 0) FROM c_sched)
         + row_number() OVER (ORDER BY block_number, log_index) AS seq
FROM epoch_length_event;

CREATE TEMP TABLE w_sched AS
WITH RECURSIVE s(seq, block_number, log_index, epoch, length, start_block) AS (
    SELECT * FROM (
        SELECT seq, block_number, log_index, epoch, length, start_block FROM c_sched
        UNION ALL
        SELECT seq, block_number, log_index, epoch, length, l1_block FROM w_len WHERE seq = 1
    )
    UNION ALL
    SELECT e.seq, e.block_number, e.log_index, e.epoch, e.length,
           s.start_block + ((e.l1_block - s.start_block) // s.length) * s.length
    FROM s JOIN w_len e ON e.seq = s.seq + 1
)
SELECT * FROM s;

-- Observations: the carried clock value enters as a pseudo-row at (0, 0) so a Signalled log
-- early in the window carries forward the clock from before it, exactly as the one-shot view.
CREATE TEMP TABLE w_obs AS
WITH clock_stream AS (
    SELECT 0::UBIGINT AS block_number, 0::UBIGINT AS log_index, false AS length_update,
           last_l1 AS l1_block, true AS pseudo FROM c_clock
    UNION ALL SELECT block_number, log_index, length_update, l1_block, false FROM w_v4
    UNION ALL SELECT block_number, log_index, false, NULL::BIGINT, false FROM curation__signalled
), observations AS (
    SELECT block_number, log_index, length_update, pseudo,
           coalesce(l1_block, last_value(l1_block IGNORE NULLS) OVER (
               ORDER BY block_number, log_index
               ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
           ), 0) AS l1_block
    FROM clock_stream
)
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
WHERE o.l1_block > 0 AND NOT o.pseudo;

-- 48's three persisted paths, each window-scoped with its carry.
CREATE TEMP TABLE w_persisted AS
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
      AND EXISTS (
          SELECT 1 FROM indexer_identity_event i WHERE i.indexer = p.indexer
          AND (i.block_number < p.block_number OR
               (i.block_number = p.block_number AND i.log_index < p.log_index))
      )
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
) first_epoch WHERE ordinal = 1
UNION ALL
SELECT block_number, log_index, l1_block FROM (
    SELECT block_number, log_index, l1_block FROM w_v4 ORDER BY block_number, log_index LIMIT 1
) initial_network WHERE NOT (SELECT any_v4 FROM c_clock);

-- Carries out.
CREATE TEMP TABLE n_sched AS SELECT * FROM w_sched ORDER BY seq DESC LIMIT 1;
CREATE TEMP TABLE n_clock AS
SELECT coalesce((SELECT l1_block FROM w_v4 ORDER BY block_number DESC, log_index DESC LIMIT 1),
                (SELECT last_l1 FROM c_clock)) AS last_l1,
       (SELECT any_v4 FROM c_clock) OR EXISTS (SELECT 1 FROM w_v4) AS any_v4;
CREATE TEMP TABLE n_epochs AS
SELECT epoch, block_number, log_index, start_block, length FROM (
    SELECT epoch, block_number, log_index, start_block, length FROM c_epochs
    UNION ALL SELECT epoch, block_number, log_index, start_block, length FROM w_obs
) QUALIFY row_number() OVER (PARTITION BY epoch ORDER BY block_number DESC, log_index DESC) = 1;
CREATE TEMP TABLE n_persisted AS
SELECT * FROM (SELECT * FROM c_persisted UNION ALL SELECT * FROM w_persisted)
ORDER BY block_number DESC, log_index DESC LIMIT 1;
CREATE TEMP TABLE n_latest_obs AS
SELECT * FROM (SELECT * FROM c_latest_obs UNION ALL SELECT block_number, log_index, epoch FROM w_obs)
ORDER BY block_number DESC, log_index DESC LIMIT 1;
CREATE TEMP TABLE n_indexers AS
SELECT DISTINCT indexer FROM (SELECT indexer FROM c_indexers UNION ALL SELECT indexer FROM w_identity_event);
CREATE TEMP TABLE n_legacy_allocs AS
SELECT DISTINCT id FROM (SELECT id FROM c_legacy_allocs
                         UNION ALL SELECT "allocationID" FROM staking_legacy__allocation_created);
CREATE TEMP TABLE n_pause AS
SELECT kind, block_number, log_index, value FROM (
    SELECT * FROM c_pause
    UNION ALL SELECT 'pause', block_number, log_index, CAST("isPaused" AS BOOLEAN) FROM controller__pause_changed
    UNION ALL SELECT 'partial', block_number, log_index, CAST("isPaused" AS BOOLEAN) FROM controller__partial_pause_changed
) QUALIFY row_number() OVER (PARTITION BY kind ORDER BY block_number DESC, log_index DESC) = 1;
CREATE TEMP TABLE n_last_run AS
SELECT * FROM (SELECT * FROM c_last_run UNION ALL SELECT block_number, log_index, epoch FROM epoch_manager__epoch_run)
ORDER BY block_number DESC, log_index DESC LIMIT 1;

COPY n_sched TO '__OUT__/c_sched.parquet' (FORMAT parquet);
COPY n_clock TO '__OUT__/c_clock.parquet' (FORMAT parquet);
COPY n_epochs TO '__OUT__/c_epochs.parquet' (FORMAT parquet);
COPY n_persisted TO '__OUT__/c_persisted.parquet' (FORMAT parquet);
COPY n_latest_obs TO '__OUT__/c_latest_obs.parquet' (FORMAT parquet);
COPY n_indexers TO '__OUT__/c_indexers.parquet' (FORMAT parquet);
COPY n_legacy_allocs TO '__OUT__/c_legacy_allocs.parquet' (FORMAT parquet);
COPY n_pause TO '__OUT__/c_pause.parquet' (FORMAT parquet);
COPY n_last_run TO '__OUT__/c_last_run.parquet' (FORMAT parquet);

-- The same projection as ref-project.sql, read from the carries.
COPY (
SELECT
  CAST(coalesce((SELECT epoch FROM n_latest_obs), 0) AS INTEGER) AS "currentEpoch",
  CAST(coalesce((SELECT length FROM n_sched), 0) AS INTEGER) AS "epochLength",
  CAST(coalesce((SELECT epoch FROM n_last_run), '0') AS INTEGER) AS "lastRunEpoch",
  CAST(coalesce((SELECT epoch FROM n_sched), 0) AS INTEGER) AS "lastLengthUpdateEpoch",
  CAST(coalesce((SELECT start_block FROM n_sched), 0) AS INTEGER) AS "lastLengthUpdateBlock",
  CAST((SELECT count(*) FROM n_epochs) AS INTEGER) AS "epochCount",
  CAST(coalesce((SELECT l1_block FROM n_persisted), 0) AS VARCHAR) AS "currentL1BlockNumber",
  coalesce((SELECT value FROM n_pause WHERE kind = 'pause'), false) AS "isPaused",
  coalesce((SELECT value FROM n_pause WHERE kind = 'partial'), false) AS "isPartialPaused",
  (SELECT md5(string_agg(CAST(epoch AS VARCHAR) || ':' || CAST(start_block AS INTEGER) || ':'
                         || CAST(start_block + length AS INTEGER), ',' ORDER BY epoch)) FROM n_epochs) AS "epochBoundsDigest"
) TO '/dev/stdout' (FORMAT json);
