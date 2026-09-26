#!/usr/bin/env bash
# rss-series.sh <series_file> <cmd...>: run cmd, sampling VmRSS/VmHWM every 0.25 s into series_file.
set -uo pipefail
series=$1; shift
start=$(date +%s%N)
"$@" &
pid=$!
while kill -0 "$pid" 2>/dev/null; do
    awk -v t="$(( ($(date +%s%N) - start) / 1000000 ))" '/^VmRSS:/ {r=$2} /^VmHWM:/ {h=$2} END {if (r) printf "%d %d %d\n", t, r/1024, h/1024}' "/proc/$pid/status" 2>/dev/null >> "$series"
    sleep 0.25
done
wait "$pid"
