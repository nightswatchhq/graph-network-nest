-- The clock-chain fields, spelled exactly as views/60-network.sql spells them.
COPY (
SELECT
  CAST(coalesce((SELECT epoch FROM network_epoch_observation ORDER BY block_number DESC, log_index DESC LIMIT 1), 0) AS INTEGER) AS "currentEpoch",
  CAST(coalesce((SELECT length FROM epoch_schedule ORDER BY seq DESC LIMIT 1), 0) AS INTEGER) AS "epochLength",
  CAST(coalesce((SELECT epoch FROM epoch_manager__epoch_run ORDER BY block_number DESC, log_index DESC LIMIT 1), '0') AS INTEGER) AS "lastRunEpoch",
  CAST(coalesce((SELECT epoch FROM epoch_schedule ORDER BY seq DESC LIMIT 1), 0) AS INTEGER) AS "lastLengthUpdateEpoch",
  CAST(coalesce((SELECT start_block FROM epoch_schedule ORDER BY seq DESC LIMIT 1), 0) AS INTEGER) AS "lastLengthUpdateBlock",
  CAST((SELECT count(*) FROM epoch_bounds) AS INTEGER) AS "epochCount",
  CAST(coalesce((SELECT l1_block FROM network_persisted_l1_observation ORDER BY block_number DESC, log_index DESC LIMIT 1), 0) AS VARCHAR) AS "currentL1BlockNumber",
  coalesce((SELECT "isPaused" FROM controller_state), false) AS "isPaused",
  coalesce((SELECT "isPartialPaused" FROM controller_state), false) AS "isPartialPaused",
  (SELECT md5(string_agg(id || ':' || "startBlock" || ':' || "endBlock", ',' ORDER BY epoch)) FROM epoch_bounds) AS "epochBoundsDigest"
) TO '/dev/stdout' (FORMAT json);
COPY (SELECT id, "startBlock", "endBlock" FROM epoch_bounds ORDER BY epoch) TO '__BOUNDS__' (FORMAT csv, HEADER);
