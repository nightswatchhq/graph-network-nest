#!/usr/bin/env bash
# step.sh <lo> <hi> <prev_ckpt_dir> <out_dir>: one fold step over (lo, hi]; prints the projection.
set -euo pipefail
lo=$1 hi=$2 prev=$3 out=$4
here=$(cd "$(dirname "$0")" && pwd)
nest=${NEST:-$HOME/.local/state/network-facade/nest-parity-20260920}
mkdir -p "$out"
sql=$out/step.sql
{
    echo "SET memory_limit = '${MEM:-8GB}'; SET threads = ${THREADS:-8}; SET preserve_insertion_order = false; SET temp_directory = '$out/tmp';"
    cat "$here/macros.sql"
    "$here/gen-raw.sh" "$nest" "$lo" "$hi"
    for view in "$here"/views/*.sql; do cat "$view"; echo; done
    sed -e "s|__PREV__|$prev|g" -e "s|__OUT__|$out|g" "$here/${FOLD_SQL:-fold-step.sql}"
} > "$sql"
exec "$here/measure.sh" "step-$lo-$hi" "$here/bin/duckdb" -f "$sql"
