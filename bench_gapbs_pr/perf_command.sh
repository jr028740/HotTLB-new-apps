#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Provide a config: vanilla/thp/gemini/hottlb"
    exit 1
fi

if [[ $# -lt 2 ]]; then
    echo "Provide a PID"
    exit 1
fi

CONFIG="$1"
MONITOR_PID="$2"

DATETIME=$(date +'%m%d%H%M%S%N')
APP_NAME="gapbs_pr"
PERF_PATH="/home/l1/Documents/HotTLB-kernel-New/tools/perf/perf"

SCRIPT_DIR=$(dirname "$(realpath -e "${BASH_SOURCE[0]:-$0}")")
OUTPUT_FILE="$SCRIPT_DIR/perf-$APP_NAME-$CONFIG.log.$DATETIME"

PERF_PID=""

stop_perf() {
    trap - TERM INT

    if [[ -n "$PERF_PID" ]] && kill -0 "$PERF_PID" 2>/dev/null; then
        kill -INT "$PERF_PID" 2>/dev/null || true
        wait "$PERF_PID" 2>/dev/null || true
    fi

    exit 0
}

trap stop_perf TERM INT

if [[ ! -x "$PERF_PATH" ]]; then
    echo "Perf binary not found or not executable: $PERF_PATH"
    exit 1
fi

if ! kill -0 "$MONITOR_PID" 2>/dev/null; then
    echo "PID does not exist: $MONITOR_PID"
    exit 1
fi

setsid taskset -a -c 0-1 \
    "$PERF_PATH" stat \
    -p "$MONITOR_PID" \
    -e r11d0 \
    -e r12d0 \
    -o "$OUTPUT_FILE" &

PERF_PID=$!

set +e
wait "$PERF_PID"
PERF_STATUS=$?
set -e

trap - TERM INT

exit "$PERF_STATUS"
