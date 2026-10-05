#!/usr/bin/env bash
# diff-at.sh <root> <n>: the one-shot views from genesis against the fold from the nearest
# checkpoint, at block n. All ten projected fields are compared, as JSON, after key-sorting.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$1 n=$2
mkdir -p "$here/out"
ref=$("$here/run-ref.sh" "$n" 2> "$here/out/diff-ref-$n.err")
fold=$("$here/eval-at.sh" "$root" "$n" 2> "$here/out/diff-fold-$n.err")
r=$(echo "$ref" | jq -S -c .) f=$(echo "$fold" | jq -S -c .)
rm_=$(grep -o 'wall_s=[0-9.]* peak_rss_mib=[0-9.]*' "$here/out/diff-ref-$n.err")
fm_=$(grep -o 'from=[0-9]* .*wall_s=[0-9.]* peak_rss_mib=[0-9.]*' "$here/out/diff-fold-$n.err" | sed 's/MEASURE [^ ]* exit=0 //')
if [ "$r" = "$f" ]; then v=MATCH; else v=MISMATCH; fi
echo "$v n=$n ref[$rm_] fold[$fm_] $(echo "$f" | jq -r '"currentEpoch=\(.currentEpoch) epochCount=\(.epochCount) l1=\(.currentL1BlockNumber)"')"
[ "$v" = MATCH ] || { echo "  ref:  $r"; echo "  fold: $f"; }
