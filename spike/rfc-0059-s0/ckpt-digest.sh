#!/usr/bin/env bash
# ckpt-digest.sh <ckpt_dir>: one order-independent digest per carry table.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
for f in "$1"/c_*.parquet; do
    printf '%s ' "$(basename "$f" .parquet)"
    "$here/bin/duckdb" -noheader -list -c \
        "SELECT count(*) || ' ' || coalesce(md5(string_agg(r, '|' ORDER BY r)), '-') FROM (SELECT CAST(t AS VARCHAR) AS r FROM read_parquet('$f') t)"
done
