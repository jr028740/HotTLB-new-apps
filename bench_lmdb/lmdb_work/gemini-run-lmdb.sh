#!/bin/bash
set -euo pipefail

DATAPATH=$(dirname "$(realpath -e "${BASH_SOURCE[0]:-$0}")")
DATETIME=$(date +'%m%d%H%M')

PERF_SCRIPT="/home/l1/Documents/HotTLB-new-tools/perf-scripts/common-perf-tlbmiss-process.sh"
GEMINI_DIR="/home/l1/Documents/HotTLB-new-tools/gemini_enable_scripts"

PMDMON_START="$GEMINI_DIR/pmdmon_start_gemini_lmdb"
PMDMON_STOP="$GEMINI_DIR/pmdmon_stop"

OUTPUT_FILE="$DATAPATH/lmdb.out.$DATETIME.gemini"

LMDB_PID=""
PERF_SCRIPT_PID=""
PMDMON_STARTED=0

cleanup() {
    if [[ -n "$LMDB_PID" ]] && kill -0 "$LMDB_PID" 2>/dev/null; then
        kill -TERM "$LMDB_PID" 2>/dev/null || true
        wait "$LMDB_PID" 2>/dev/null || true
    fi

    if [[ -n "$PERF_SCRIPT_PID" ]] && kill -0 "$PERF_SCRIPT_PID" 2>/dev/null; then
        kill -TERM "$PERF_SCRIPT_PID" 2>/dev/null || true
        wait "$PERF_SCRIPT_PID" 2>/dev/null || true
    fi

    if [[ "$PMDMON_STARTED" -eq 1 ]]; then
        "$PMDMON_STOP" 2>/dev/null || true
        PMDMON_STARTED=0
    fi
}

trap cleanup EXIT INT TERM

if [[ ! -x "$DATAPATH/lmdb_run" ]]; then
    echo "LMDB binary not found: $DATAPATH/lmdb_run"
    exit 1
fi

if [[ ! -x "$PERF_SCRIPT" ]]; then
    echo "Perf script not found or not executable: $PERF_SCRIPT"
    exit 1
fi

if [[ ! -x "$PMDMON_START" ]]; then
    echo "Gemini start script not found or not executable: $PMDMON_START"
    exit 1
fi

if [[ ! -x "$PMDMON_STOP" ]]; then
    echo "Gemini stop script not found or not executable: $PMDMON_STOP"
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

echo "LMDB Gemini started with PID $LMDB_PID"

"$PMDMON_START" lmdb_run
PMDMON_STARTED=1

datapath="$DATAPATH" \
datetime="$DATETIME" \
"$PERF_SCRIPT" lmdb-gemini "$LMDB_PID" &

PERF_SCRIPT_PID=$!

set +e
wait "$LMDB_PID"
LMDB_STATUS=$?
set -e

LMDB_PID=""

"$PMDMON_STOP"
PMDMON_STARTED=0

if [[ -n "$PERF_SCRIPT_PID" ]]; then
    wait "$PERF_SCRIPT_PID" 2>/dev/null || true
    PERF_SCRIPT_PID=""
fi

trap - EXIT INT TERM

echo "LMDB Gemini exit status: $LMDB_STATUS"
echo "Output: $OUTPUT_FILE"
echo "Done."

exit "$LMDB_STATUS"
