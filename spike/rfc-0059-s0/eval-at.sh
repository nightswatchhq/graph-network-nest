#!/usr/bin/env bash
# eval-at.sh <root> <n>: the fold's state at n, from the latest checkpoint at or below n.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$1 n=$2
c=$(ls "$root" | grep -E '^[0-9]+$' | awk -v n="$n" '$1 <= n' | sort -n | tail -1)
out=$(mktemp -d "$root/.eval-$n.XXXX")
"$here/step.sh" "$c" "$n" "$root/$c" "$out" 2> "$out/step.err" || { tail -5 "$out/step.err" >&2; exit 1; }
grep MEASURE "$out/step.err" | sed "s/^/from=$c /" >&2
rm -rf "$out"
