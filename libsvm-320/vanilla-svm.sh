#!/bin/bash
set -euo pipefail

DATAPATH=$(dirname "$(realpath -e "${BASH_SOURCE[0]:-$0}")")
DATETIME=$(date +'%m%d%H%M')

PERF_SCRIPT="/home/l1/Documents/HotTLB-new-tools/perf-scripts/common-perf-tlbmiss-process.sh"
DATASET="$DATAPATH/data/test2-10gb"
OUTPUT_FILE="$DATAPATH/svm.out.$DATETIME.vanilla"

SVM_PID=""
PERF_SCRIPT_PID=""

cleanup() {
    if [[ -n "$SVM_PID" ]] && kill -0 "$SVM_PID" 2>/dev/null; then
        kill -TERM "$SVM_PID" 2>/dev/null || true
        wait "$SVM_PID" 2>/dev/null || true
    fi

    if [[ -n "$PERF_SCRIPT_PID" ]] && kill -0 "$PERF_SCRIPT_PID" 2>/dev/null; then
        kill -TERM "$PERF_SCRIPT_PID" 2>/dev/null || true
        wait "$PERF_SCRIPT_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

if [[ ! -x "$DATAPATH/svm-train" ]]; then
    echo "SVM binary not found: $DATAPATH/svm-train"
    exit 1
fi

if [[ ! -f "$DATASET" ]]; then
    echo "SVM dataset not found: $DATASET"
    exit 1
fi

if [[ ! -x "$PERF_SCRIPT" ]]; then
    echo "Perf script not found or not executable: $PERF_SCRIPT"
    exit 1
fi

mkdir -p /tmp/enablement
rm -f /tmp/enablement/svm_watch

export OMP_NUM_THREADS=32
export OMP_DYNAMIC=FALSE
export OMP_PROC_BIND=TRUE
export OMP_PLACES=cores

cd "$DATAPATH"

START_NS=$(date +%s%N)

taskset -a -c 0-31 \
    ./svm-train \
    -c 4 \
    -t 0 \
    -e 0.1 \
    -m 8192 \
    -v 2 \
    "$DATASET" \
    &>>"$OUTPUT_FILE" &

SVM_PID=$!

echo "SVM vanilla started with PID $SVM_PID"

datapath="$DATAPATH" \
datetime="$DATETIME" \
"$PERF_SCRIPT" svm-vanilla "$SVM_PID" &

PERF_SCRIPT_PID=$!

set +e
wait "$SVM_PID"
SVM_STATUS=$?
set -e

END_NS=$(date +%s%N)

SVM_PID=""

if [[ -n "$PERF_SCRIPT_PID" ]]; then
    wait "$PERF_SCRIPT_PID" 2>/dev/null || true
    PERF_SCRIPT_PID=""
fi

awk \
    -v start="$START_NS" \
    -v end="$END_NS" \
    'BEGIN {
        seconds = (end - start) / 1000000000
        printf "Elapsed time: %.6f seconds\n", seconds
    }' |
    tee -a "$OUTPUT_FILE"

trap - EXIT INT TERM

echo "SVM vanilla exit status: $SVM_STATUS"
echo "Output: $OUTPUT_FILE"
echo "Done."

exit "$SVM_STATUS"
