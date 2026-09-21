#!/usr/bin/env bash
# walk.sh <root> <b1> <b2> ...: build checkpoints root/<b> from an empty genesis at root/0.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$1; shift
mkdir -p "$root/0"
sed "s|__OUT__|$root/0|g" "$here/init-carry.sql" > "$root/0/init.sql"
"$here/bin/duckdb" -f "$root/0/init.sql"
prev=0
for b in "$@"; do
    mkdir -p "$root/$b"
    "$here/step.sh" "$prev" "$b" "$root/$prev" "$root/$b" > "$root/$b/state.json" 2> "$root/$b/step.err" \
        || { echo "step ($prev, $b] failed"; tail -5 "$root/$b/step.err"; exit 1; }
    grep MEASURE "$root/$b/step.err"
    prev=$b
done
