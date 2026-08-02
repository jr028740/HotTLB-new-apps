#!/bin/bash
set -euo pipefail

DATAPATH=$(dirname "$(realpath -e "${BASH_SOURCE[0]:-$0}")")
DATETIME=$(date +'%m%d%H%M')

GAPBS_DIR="/home/l1/Documents/HotTLB-new-apps/gapbs-1.5"
GEMINI_DIR="/home/l1/Documents/HotTLB-new-tools/gemini_enable_scripts"

PMDMON_START="$GEMINI_DIR/pmdmon_start_gemini_pagerank"
PMDMON_STOP="$GEMINI_DIR/pmdmon_stop"

OUTPUT_FILE="$DATAPATH/pr.out.$DATETIME.gemini"

PR_PID=""
PMDMON_STARTED=0

cleanup() {
    if [[ -n "$PR_PID" ]] && kill -0 "$PR_PID" 2>/dev/null; then
        kill -TERM "$PR_PID" 2>/dev/null || true
        wait "$PR_PID" 2>/dev/null || true
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

./switch_bench_profile.sh gemini pr

taskset -a -c 0-31 \
    "$GAPBS_DIR/pr" \
    -g 30 \
    -k 12 \
    -m \
    -i 20 \
    -t 1e-4 \
    -n 11 \
    &>>"$OUTPUT_FILE" &

PR_PID=$!

echo "GAPBS PR Gemini started with PID $PR_PID"

"$PMDMON_START" pr
PMDMON_STARTED=1

set +e
wait "$PR_PID"
PR_STATUS=$?
set -e

PR_PID=""

"$PMDMON_STOP"
PMDMON_STARTED=0

trap - EXIT INT TERM

echo "GAPBS PR Gemini exit status: $PR_STATUS"
echo "Output: $OUTPUT_FILE"
echo "Done."

exit "$PR_STATUS"
