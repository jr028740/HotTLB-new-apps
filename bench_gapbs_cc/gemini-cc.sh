#!/bin/bash
set -euo pipefail

DATAPATH=$(dirname "$(realpath -e "${BASH_SOURCE[0]:-$0}")")
DATETIME=$(date +'%m%d%H%M')

GAPBS_DIR="/home/l1/Documents/HotTLB-new-apps/gapbs-1.5"
GEMINI_DIR="/home/l1/Documents/HotTLB-new-tools/gemini_enable_scripts"

PMDMON_START="$GEMINI_DIR/pmdmon_start_gemini_cc"
PMDMON_STOP="$GEMINI_DIR/pmdmon_stop"

OUTPUT_FILE="$DATAPATH/cc.out.$DATETIME.gemini"

CC_PID=""
PMDMON_STARTED=0

cleanup() {
    if [[ -n "$CC_PID" ]] && kill -0 "$CC_PID" 2>/dev/null; then
        kill -TERM "$CC_PID" 2>/dev/null || true
        wait "$CC_PID" 2>/dev/null || true
    fi

    if [[ "$PMDMON_STARTED" -eq 1 ]]; then
        "$PMDMON_STOP" 2>/dev/null || true
        PMDMON_STARTED=0
    fi
}

trap cleanup EXIT INT TERM

if [[ ! -x "$PMDMON_START" ]]; then
    echo "Gemini start script not found or not executable: $PMDMON_START"
    exit 1
fi

if [[ ! -x "$PMDMON_STOP" ]]; then
    echo "Gemini stop script not found or not executable: $PMDMON_STOP"
    exit 1
fi

mkdir -p /tmp/enablement

export OMP_NUM_THREADS=32
export OMP_DYNAMIC=FALSE
export OMP_PROC_BIND=TRUE
export OMP_PLACES=cores

cd "$GAPBS_DIR"

./switch_bench_profile.sh gemini cc

taskset -a -c 0-31 \
    "$GAPBS_DIR/cc" \
    -g 30 \
    -k 12\
    -n 5 \
    &>>"$OUTPUT_FILE" &

CC_PID=$!

echo "GAPBS CC Gemini started with PID $CC_PID"

"$PMDMON_START" cc
PMDMON_STARTED=1

set +e
wait "$CC_PID"
CC_STATUS=$?
set -e

CC_PID=""

"$PMDMON_STOP"
PMDMON_STARTED=0

trap - EXIT INT TERM

echo "GAPBS CC Gemini exit status: $CC_STATUS"
echo "Output: $OUTPUT_FILE"
echo "Done."

exit "$CC_STATUS"
