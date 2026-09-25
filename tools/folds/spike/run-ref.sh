#!/usr/bin/env bash
# Reference: the nest's own views, unchanged, over sealed facts in (0, n].
# Prints the clock fields as JSON and writes epoch bounds to out/ref-<n>-bounds.csv.
set -euo pipefail
n=$1
here=$(cd "$(dirname "$0")" && pwd)
nest=${NEST:-$HOME/.local/state/network-facade/nest-parity-20260920}
mkdir -p "$here/out"
sql=$here/out/ref-$n.sql
{
    echo "SET memory_limit = '8GB'; SET threads = 8; SET preserve_insertion_order = false; SET temp_directory = '$here/out/tmp-ref-$n-$$';"
    cat "$here/macros.sql"
    "$here/gen-raw.sh" "$nest" 0 "$n"
    for view in "$here"/views/*.sql; do cat "$view"; echo; done
    sed "s|__BOUNDS__|$here/out/ref-$n-bounds.csv|" "$here/ref-project.sql"
} > "$sql"
exec "$here/measure.sh" "ref-$n" "$here/bin/duckdb" -f "$sql"
