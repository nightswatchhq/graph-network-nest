#!/usr/bin/env bash
# carries.sh <nest> <block> <spike_ckpt_dir> <outdir>: every fold at <block> against the spike's
# carry Parquet at the same block. Rows are loaded into the spike file's own column types, then
# compared both ways with EXCEPT ALL and digested exactly as ckpt-digest.sh digests a carry.
set -euo pipefail
nest=$1 n=$2 ck=$3 out=$4
bin=${NUTHATCH:-$HOME/nuthatch-folds/target/release/nuthatch}
duck=${DUCKDB:-$(cd "$(dirname "$0")" && pwd)/spike/bin/duckdb}
mkdir -p "$out"
for pair in sched:schedule clock:clock epochs:epochs persisted:persisted latest_obs:latest_obs \
            indexers:indexers legacy_allocs:legacy_allocs pause:pause last_run:last_run; do
    c=${pair%%:*} f=${pair#*:}
    "$bin" fold read --dir "$nest" --fold "$f" --at "$n" > "$out/$f.jsonl"
    load="CREATE TABLE mine AS SELECT * FROM read_parquet('$ck/c_$c.parquet') WHERE false;"
    [ -s "$out/$f.jsonl" ] && load="$load INSERT INTO mine BY NAME SELECT * FROM read_json_auto('$out/$f.jsonl');"
    res=$("$duck" -noheader -list -c "SET temp_directory='$out/tmp'; $load
      CREATE TABLE spike AS SELECT * FROM read_parquet('$ck/c_$c.parquet');
      SELECT (SELECT count(*) FROM (SELECT * FROM mine EXCEPT ALL SELECT * FROM spike)) || ' '
          || (SELECT count(*) FROM (SELECT * FROM spike EXCEPT ALL SELECT * FROM mine)) || ' '
          || (SELECT count(*) || ' ' || coalesce(md5(string_agg(r, '|' ORDER BY r)), '-') FROM (SELECT CAST(t AS VARCHAR) AS r FROM mine t)) || ' '
          || (SELECT count(*) || ' ' || coalesce(md5(string_agg(r, '|' ORDER BY r)), '-') FROM (SELECT CAST(t AS VARCHAR) AS r FROM spike t));")
    set -- $res
    v=MATCH; { [ "$1" = 0 ] && [ "$2" = 0 ] && [ "$4" = "$6" ]; } || v=MISMATCH
    echo "$v n=$n carry=c_$c fold=$f only_mine=$1 only_spike=$2 mine=[$3 $4] spike=[$5 $6]"
done
