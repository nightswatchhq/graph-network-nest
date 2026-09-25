#!/usr/bin/env bash
# run-compare.sh <nest> <tag>: the full differential. Projections at every spike block against the
# spike-fold reference (MATCH-verified against the one-shot views in diff-a.log) and the one-shot
# epoch bounds; then every carry against the spike's checkpoints.
set -uo pipefail
nest=$1 tag=$2
cd ~/fold-port
res=results-$tag; mkdir -p "$res"
: > "$res/projection.log"
for n in $(cat ~/spike-0059/diff.blocks) 450001618 500000152; do
    got=$(tools/measure.sh "read-$n" tools/project.sh "$nest" "$n" "$res/out/$n" 2> "$res/out-$n.err")
    exp=$(jq -S -c . ref/spikefold-$n.json)
    v=MATCH; [ "$got" = "$exp" ] || v=MISMATCH
    b=MISSING; rb=~/spike-0059/out/ref-$n-bounds.csv
    [ -f "$rb" ] && { cmp -s "$rb" "$res/out/$n/bounds.csv" && b=MATCH || b=MISMATCH; }
    echo "$v n=$n bounds_vs_oneshot=$b $(grep -o 'wall_s=[0-9.]*' "$res/out-$n.err")" >> "$res/projection.log"
    [ "$v" = MATCH ] || { echo "  exp: $exp"; echo "  got: $got"; } >> "$res/projection.log"
done
cmp -s ~/spike-0059/gw-123m-bounds.csv "$res/out/123615752/bounds.csv" \
  && echo "MATCH gw-123m-bounds.csv" >> "$res/projection.log" || echo "MISMATCH gw-123m-bounds.csv" >> "$res/projection.log"
: > "$res/carries.log"
for n in ${CARRY_BLOCKS:-50000000 100000000 150000000 200000000 250000000 300000000 350000000 400000000 450000000 500000000 506179123 507079123 507177123}; do
    tools/carries.sh "$nest" "$n" ~/spike-0059/ckpt-a/$n "$res/carries/$n" >> "$res/carries.log" 2>&1
done
echo DONE >> "$res/carries.log"
