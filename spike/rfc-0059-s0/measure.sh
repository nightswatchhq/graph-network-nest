#!/usr/bin/env bash
# measure.sh <label> <cmd...>: run cmd, report wall seconds and the process's peak RSS.
# VmHWM is the kernel's own high-water mark; it only rises, so the last sample
# before exit is the peak to within one poll interval.
set -uo pipefail
label=$1; shift
start=$(date +%s.%N)
"$@" &
pid=$!
peak=0
while kill -0 "$pid" 2>/dev/null; do
    hwm=$(awk '/^VmHWM:/ {print $2}' "/proc/$pid/status" 2>/dev/null || true)
    [ -n "${hwm:-}" ] && [ "$hwm" -gt "$peak" ] && peak=$hwm
    sleep 0.05
done
wait "$pid"; status=$?
end=$(date +%s.%N)
awk -v l="$label" -v s="$status" -v a="$start" -v b="$end" -v p="$peak" \
    'BEGIN { printf "MEASURE %s exit=%d wall_s=%.3f peak_rss_mib=%.1f\n", l, s, b - a, p / 1024 }' >&2
exit "$status"
