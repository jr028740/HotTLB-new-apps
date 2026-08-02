#!/bin/bash
set -euo pipefail

DATAPATH=$(dirname "$(realpath -e "${BASH_SOURCE[0]:-$0}")")
DATETIME=$(date +'%m%d%H%M')

PERF_SCRIPT="/home/l1/Documents/HotTLB-new-tools/perf-scripts/common-perf-tlbmiss-process.sh"
OUTPUT_FILE="$DATAPATH/lmdb.out.$DATETIME.vanilla"

LMDB_PID=""
PERF_SCRIPT_PID=""

cleanup() {
    if [[ -n "$LMDB_PID" ]] && kill -0 "$LMDB_PID" 2>/dev/null; then
        kill -TERM "$LMDB_PID" 2>/dev/null || true
        wait "$LMDB_PID" 2>/dev/null || true
    fi

    if [[ -n "$PERF_SCRIPT_PID" ]] && kill -0 "$PERF_SCRIPT_PID" 2>/dev/null; then
        kill -TERM "$PERF_SCRIPT_PID" 2>/dev/null || true
        wait "$PERF_SCRIPT_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

if [[ ! -x "$PERF_SCRIPT" ]]; then
    echo "Perf script not found or not executable: $PERF_SCRIPT"
    exit 1
fi

mkdir -p /tmp/enablement
rm -f /tmp/enablement/lmdb_watch

export LD_LIBRARY_PATH="$DATAPATH/../lmdb_build/lib:$DATAPATH/../HdrHistogram_c/src${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

cd "$DATAPATH"

taskset -a -c 0-31 \
    ./lmdb_run \
    &>>"$OUTPUT_FILE" &

LMDB_PID=$!

echo "LMDB vanilla started with PID $LMDB_PID"

datapath="$DATAPATH" \
datetime="$DATETIME" \
"$PERF_SCRIPT" lmdb-vanilla "$LMDB_PID" &

PERF_SCRIPT_PID=$!

set +e
wait "$LMDB_PID"
LMDB_STATUS=$?
set -e

LMDB_PID=""

if [[ -n "$PERF_SCRIPT_PID" ]]; then
    wait "$PERF_SCRIPT_PID" 2>/dev/null || true
    PERF_SCRIPT_PID=""
fi

trap - EXIT INT TERM

echo "LMDB vanilla exit status: $LMDB_STATUS"
echo "Output: $OUTPUT_FILE"
echo "Perf outputs:"
find "$DATAPATH" -maxdepth 1 -type f \
    -name '*lmdb-vanilla*' \
    -newermt "-5 minutes" \
    -printf '%f\n'
echo "Done."

exit "$LMDB_STATUS"
