#!/usr/bin/env bash
# timed-step.sh <lo> <hi> <prev> : the step's SQL with DuckDB's per-statement timer, summed by phase.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
lo=$1 hi=$2 prev=$3
out=$(mktemp -d)
nest=${NEST:-$HOME/.local/state/network-facade/nest-parity-20260920}
{
    echo "SET memory_limit = '8GB'; SET threads = 8; SET preserve_insertion_order = false;"
    cat "$here/macros.sql"
    "$here/gen-raw.sh" "$nest" "$lo" "$hi"
    for view in "$here"/views/*.sql; do cat "$view"; echo; done
    echo ".timer on"
    sed -e "s|__PREV__|$prev|g" -e "s|__OUT__|$out|g" "$here/fold-step.sql"
} > "$out/step.sql"
"$here/bin/duckdb" -f "$out/step.sql" 2>&1 | grep -o 'real [0-9.]*' | awk '{ s += $2; n++ } END { printf "fold statements: %d, summed real %.3f s\n", n, s }'
rm -rf "$out"
