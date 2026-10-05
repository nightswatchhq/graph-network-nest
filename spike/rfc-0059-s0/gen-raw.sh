#!/usr/bin/env bash
# Emit a DuckDB raw layer for the window (lo, hi]: every declared table, typed from
# schema.json, with only the catalogue segments that overlap the window unioned on.
set -euo pipefail
nest=$1 lo=$2 hi=$3
here=$(cd "$(dirname "$0")" && pwd)
jq -r --argjson lo "$lo" --argjson hi "$hi" --arg dir "$nest/segments" \
    --slurpfile m "$nest/segments/manifest.json" \
    -f "$here/gen-raw.jq" "$nest/schema.json"
