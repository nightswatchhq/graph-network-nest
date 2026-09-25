#!/usr/bin/env bash
# gen-folds.sh <nest>: writes <nest>/folds/ from the nest's own view text plus the carries below.
# The refresh union is extracted from views/26-network-clock.sql so it cannot drift by retyping;
# only its last branch (the legacy-allocation history lookup) is replaced.
set -euo pipefail
nest=$1
out=$nest/folds
mkdir -p "$out"
src=$nest/views/26-network-clock.sql
union=$(sed -n '/CREATE VIEW network_refresh_event AS/,/^CREATE VIEW network_l1_observation/p' "$src" | sed -n '2,125p')
[ "$(printf '%s\n' "$union" | tail -1)" = "UNION ALL" ] || { echo "26-network-clock.sql changed shape" >&2; exit 1; }

# The window's refresh events and their pinned L1 reads (26's network_l1_observation), with the
# legacy-allocation lookup answered by legacy_allocs__carry plus this window's creations.
read -r -d '' V4 <<EOF || true
w_refresh AS (
$union
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
)
EOF

# 05's epoch schedule, with the carried last row as the recursion's base.
read -r -d '' SCHED <<'EOF' || true
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
)
EOF

# 26's network_epoch_observation. The carried clock enters at (0, 0), so a Signalled log early in
# the window carries forward the clock from before it.
read -r -d '' OBS <<'EOF' || true
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
)
EOF

cat > "$out/10-legacy_allocs.sql" <<'EOF'
-- Every legacy allocation id: 26 reads allocation_creation's history to filter HorizonRewardsAssigned.
SELECT DISTINCT "allocationID" AS id FROM staking_legacy__allocation_created
EOF

cat > "$out/20-indexers.sql" <<'EOF'
-- Every indexer seen: 48 asks whether a DelegationParametersUpdated indexer already existed.
SELECT DISTINCT indexer FROM indexer_identity_event
EOF

cat > "$out/30-schedule.sql" <<EOF
-- The last epoch_schedule row.
WITH RECURSIVE
$SCHED
SELECT seq, block_number, log_index, epoch, length, start_block FROM w_sched
ORDER BY seq DESC LIMIT 1
EOF

cat > "$out/40-clock.sql" <<EOF
-- The last refresh's L1 read, and whether any refresh has happened.
WITH
$V4
SELECT coalesce((SELECT l1_block FROM w_v4 ORDER BY block_number DESC, log_index DESC LIMIT 1),
                (SELECT last_l1 FROM clock__carry)) AS last_l1,
       coalesce((SELECT any_v4 FROM clock__carry), false) OR EXISTS (SELECT 1 FROM w_v4) AS any_v4
EOF

cat > "$out/50-epochs.sql" <<EOF
-- epoch_bounds: the latest observation of each epoch the window touched.
WITH RECURSIVE
$V4,
$SCHED,
$OBS
SELECT epoch, block_number, log_index, start_block, length FROM w_obs
QUALIFY row_number() OVER (PARTITION BY epoch ORDER BY block_number DESC, log_index DESC) = 1
EOF

cat > "$out/60-latest_obs.sql" <<'EOF'
-- The latest observation overall is the latest of each epoch's latest.
SELECT block_number, log_index, epoch FROM epochs
ORDER BY block_number DESC, log_index DESC LIMIT 1
EOF

cat > "$out/70-persisted.sql" <<EOF
-- 48's network_persisted_l1_observation, latest row: its three paths, each answered from a carry.
WITH RECURSIVE
$V4,
$SCHED,
$OBS,
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
EOF

cat > "$out/80-pause.sql" <<'EOF'
-- controller_state's two pause flags, latest per kind.
SELECT kind, block_number, log_index, value FROM (
    SELECT 'pause' AS kind, block_number, log_index, CAST("isPaused" AS BOOLEAN) AS value FROM controller__pause_changed
    UNION ALL
    SELECT 'partial', block_number, log_index, CAST("isPaused" AS BOOLEAN) FROM controller__partial_pause_changed
) QUALIFY row_number() OVER (PARTITION BY kind ORDER BY block_number DESC, log_index DESC) = 1
EOF

cat > "$out/90-last_run.sql" <<'EOF'
-- The last EpochRun.
SELECT block_number, log_index, epoch FROM (
    SELECT block_number, log_index, epoch FROM last_run__carry
    UNION ALL SELECT block_number, log_index, epoch FROM epoch_manager__epoch_run
) ORDER BY block_number DESC, log_index DESC LIMIT 1
EOF

cat > "$out/folds.toml" <<'EOF'
[[fold]]
name = "legacy_allocs"
key = ["id"]
carry = ["id VARCHAR"]
max_rows = 1000000

[[fold]]
name = "indexers"
key = ["indexer"]
carry = ["indexer VARCHAR"]
max_rows = 10000

[[fold]]
name = "schedule"
key = "singleton"
carry = ["seq BIGINT", "block_number UBIGINT", "log_index UBIGINT", "epoch BIGINT", "length BIGINT", "start_block BIGINT"]
max_rows = 1

[[fold]]
name = "clock"
key = "singleton"
carry = ["last_l1 BIGINT", "any_v4 BOOLEAN"]
max_rows = 1

[[fold]]
name = "epochs"
key = ["epoch"]
carry = ["epoch BIGINT", "block_number UBIGINT", "log_index UBIGINT", "start_block BIGINT", "length BIGINT"]
max_rows = 100000

[[fold]]
name = "latest_obs"
key = "singleton"
carry = ["block_number UBIGINT", "log_index UBIGINT", "epoch BIGINT"]
max_rows = 1

[[fold]]
name = "persisted"
key = "singleton"
carry = ["block_number UBIGINT", "log_index UBIGINT", "l1_block BIGINT"]
max_rows = 1

[[fold]]
name = "pause"
key = ["kind"]
carry = ["kind VARCHAR", "block_number UBIGINT", "log_index UBIGINT", "value BOOLEAN"]
max_rows = 2

[[fold]]
name = "last_run"
key = "singleton"
carry = ["block_number UBIGINT", "log_index UBIGINT", "epoch VARCHAR"]
max_rows = 1
EOF
echo "wrote $(ls "$out" | wc -l) files to $out"
