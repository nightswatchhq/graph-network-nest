#!/usr/bin/env bash
# Fold a real redb clock/transfer tail over a sealed checkpoint. This is an
# operator probe, not a general redb reader: exports come from `nuthatch sql`.
set -euo pipefail

if [ "$#" -ne 7 ]; then
    echo "usage: $0 lo hi previous_checkpoint output_dir observations.jsonl transfers.jsonl approvals.jsonl" >&2
    exit 2
fi

lo=$1 hi=$2 prev=$3 out=$4 observations=$5 transfers=$6 approvals=$7
here=$(cd "$(dirname "$0")" && pwd)
nest=${NEST:-$HOME/.local/state/network-facade/nest-parity-20260920}

for path in "$observations" "$transfers" "$approvals"; do
    if [ ! -s "$path" ]; then
        echo "missing or empty hot-tail export: $path" >&2
        exit 2
    fi
    if [[ "$path" == *"'"* ]]; then
        echo "export path cannot contain a single quote: $path" >&2
        exit 2
    fi
done

for path in "$observations" "$transfers" "$approvals"; do
    if ! jq -se --argjson lo "$lo" --argjson hi "$hi" \
        'length > 0 and all(.[]; .block_number > $lo and .block_number <= $hi)' "$path" >/dev/null; then
        echo "hot-tail export has a row outside ($lo, $hi]: $path" >&2
        exit 2
    fi
done

mkdir -p "$out"
sql=$out/hot-tail-step.sql
{
    echo "SET memory_limit = '${MEM:-8GB}'; SET threads = ${THREADS:-8}; SET preserve_insertion_order = false; SET temp_directory = '$out/tmp';"
    cat "$here/macros.sql"
    "$here/gen-raw.sh" "$nest" "$lo" "$hi"
    for view in "$here"/views/*.sql; do cat "$view"; echo; done

    # The exported observations include the pinned blockNum() result. Transfer
    # and approval rows are needed by the persisted-clock exclusion rule.
    cat <<SQL
CREATE TEMP TABLE sealed_graph_token_transfer AS SELECT * FROM graph_token__transfer;
CREATE OR REPLACE VIEW graph_token__transfer AS
SELECT * FROM sealed_graph_token_transfer
UNION ALL BY NAME SELECT * FROM read_json_auto('$transfers');
CREATE TEMP TABLE sealed_graph_token_approval AS SELECT * FROM graph_token__approval;
CREATE OR REPLACE VIEW graph_token__approval AS
SELECT * FROM sealed_graph_token_approval
UNION ALL BY NAME SELECT * FROM read_json_auto('$approvals');
CREATE OR REPLACE VIEW network_l1_observation AS
SELECT block_number, log_index, length_update, l1_block
FROM read_json_auto('$observations');
SQL
    sed -e "s|__PREV__|$prev|g" -e "s|__OUT__|$out|g" "$here/fold-step.sql"
} > "$sql"

exec "$here/measure.sh" "hot-tail-$lo-$hi" "$here/bin/duckdb" -f "$sql"
