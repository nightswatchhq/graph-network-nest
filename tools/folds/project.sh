#!/usr/bin/env bash
# project.sh <nest> <block> <outdir>: reads every fold at <block> with `nuthatch fold read`, writes
# <outdir>/<fold>.jsonl, and prints ref-project.sql's ten values as one key-sorted JSON line.
# Bounds go to <outdir>/bounds.csv in the reference's CSV shape.
set -euo pipefail
nest=$1 n=$2 out=$3
bin=${NUTHATCH:-$HOME/nuthatch-folds/target/release/nuthatch}
mkdir -p "$out"
for f in ${FOLDS:-schedule clock epochs latest_obs persisted pause last_run}; do
    "$bin" fold read --dir "$nest" --fold "$f" --at "$n" > "$out/$f.jsonl"
done
jq -s '.' "$out/epochs.jsonl" > "$out/epochs.json"
{ echo 'id,startBlock,endBlock'
  jq -r 'sort_by(.epoch)[] | "\(.epoch),\(.start_block),\(.start_block + .length)"' "$out/epochs.json"; } > "$out/bounds.csv"
digest=$(if [ "$(jq length "$out/epochs.json")" -eq 0 ]; then echo null; else
    printf '%s' "$(jq -r 'sort_by(.epoch) | map("\(.epoch):\(.start_block):\(.start_block + .length)") | join(",")' "$out/epochs.json")" \
      | md5sum | awk '{print "\"" $1 "\""}'; fi)
first() { local r; r=$(head -1 "$out/$1.jsonl"); echo "${r:-null}"; }
jq -n -S -c \
  --argjson sched "$(first schedule)" \
  --argjson latest "$(first latest_obs)" \
  --argjson run "$(first last_run)" \
  --argjson pers "$(first persisted)" \
  --slurpfile pause "$out/pause.jsonl" \
  --argjson count "$(jq length "$out/epochs.json")" \
  --argjson digest "$digest" '
  {currentEpoch: ($latest.epoch // 0),
   epochLength: ($sched.length // 0),
   lastRunEpoch: (($run.epoch // "0") | tonumber),
   lastLengthUpdateEpoch: ($sched.epoch // 0),
   lastLengthUpdateBlock: ($sched.start_block // 0),
   epochCount: $count,
   currentL1BlockNumber: (($pers.l1_block // 0) | tostring),
   isPaused: ([$pause[] | select(.kind == "pause") | .value][0] // false),
   isPartialPaused: ([$pause[] | select(.kind == "partial") | .value][0] // false),
   epochBoundsDigest: $digest}'
