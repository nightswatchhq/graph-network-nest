#!/usr/bin/env bash
# probe.sh <nest> <tag>: RFC-0059 §8's probe-point check. At the first refresh event after every
# interior checkpoint of <nest>, its fold read (which starts from that checkpoint) must equal the
# reference there. The probe block is located with the spike's own raw layer and views.
set -uo pipefail
nest=$1 tag=$2
sp=~/spike-0059
cd ~/fold-port
res=results-$tag; mkdir -p "$res/probe"
: > "$res/probe.log"
cuts=$(jq -r '.checkpoints[].block' "$nest"/checkpoints/*/manifest.json | sort -un | head -n -1)
for c in $cuts; do
    q=$res/probe/find-$c.sql
    { echo "SET temp_directory='$res/probe/tmp-$c';"; cat $sp/macros.sql
      $sp/gen-raw.sh ~/.local/state/network-facade/nest-parity-20260920 "$c" $((c + 5000000))
      for v in $sp/views/*.sql; do cat "$v"; echo; done; cat $sp/first-refresh.sql; } > "$q"
    n=$($sp/bin/duckdb -f "$q" 2>/dev/null | tail -1)
    [ -z "$n" ] && { echo "cut=$c no refresh event within 5M blocks" >> "$res/probe.log"; continue; }
    got=$(tools/project.sh "$nest" "$n" "$res/probe/$n" 2> "$res/probe/$n.err")
    exp=$($sp/eval-at.sh ~/fold-port/spike-root "$n" 2>/dev/null | jq -S -c .)
    v=MATCH; { [ -n "$got" ] && [ "$got" = "$exp" ]; } || v=MISMATCH
    echo "$v cut=$c probe=$n l1=$(echo "$got" | jq -r .currentL1BlockNumber) epochCount=$(echo "$got" | jq -r .epochCount)" >> "$res/probe.log"
    [ "$v" = MATCH ] || { echo "  exp: $exp"; echo "  got: $got"; } >> "$res/probe.log"
done
echo DONE >> "$res/probe.log"
