#!/usr/bin/env bash
# probe-invariance.sh <cuts_file> <ckpt_cut_root> <ckpt_regular_root> <mut_root> <mut_sql>
# At the first refresh-event block after every cut, the fold from the cut's checkpoint must equal
# the fold from the regular partition's checkpoint. The mutated fold from its own cut checkpoint
# is reported alongside; a mutation the test can see differs somewhere.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
cuts=$1 cutroot=$2 regroot=$3 mutroot=$4 mutsql=$5
nest=${NEST:-$HOME/.local/state/network-facade/nest-parity-20260920}
inv_ok=0 inv_bad=0 mut_caught=0 mut_missed=0
for c in $(head -n -1 "$cuts"); do
    q=$(mktemp "$here/out/probe.XXXX.sql")
    { cat "$here/macros.sql"; "$here/gen-raw.sh" "$nest" "$c" $((c + 5000000)); for v in "$here"/views/*.sql; do cat "$v"; echo; done; cat "$here/first-refresh.sql"; } > "$q"
    n=$("$here/bin/duckdb" -f "$q" 2>/dev/null | tail -1); rm -f "$q"
    [ -z "$n" ] && { echo "cut=$c no refresh event within 5M blocks"; continue; }
    a=$("$here/eval-at.sh" "$cutroot" "$n" 2>/dev/null | jq -S -c .)
    b=$("$here/eval-at.sh" "$regroot" "$n" 2>/dev/null | jq -S -c .)
    m=$(FOLD_SQL=$mutsql "$here/eval-at.sh" "$mutroot" "$n" 2>/dev/null | jq -S -c .)
    if [ -n "$a" ] && [ "$a" = "$b" ]; then inv_ok=$((inv_ok+1)); else inv_bad=$((inv_bad+1)); echo "INVARIANCE-FAIL cut=$c n=$n cut:$a regular:$b"; fi
    if [ "$m" != "$a" ]; then mut_caught=$((mut_caught+1)); echo "mutation-visible cut=$c n=$n l1 correct=$(echo "$a" | jq -r .currentL1BlockNumber) mutated=$(echo "$m" | jq -r .currentL1BlockNumber)"; else mut_missed=$((mut_missed+1)); fi
done
echo "SUMMARY invariance_ok=$inv_ok invariance_fail=$inv_bad mutation_visible=$mut_caught mutation_invisible=$mut_missed"
