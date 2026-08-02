#!/bin/bash
set -euo pipefail

DATAPATH=$(dirname "$(realpath -e "${BASH_SOURCE[0]:-$0}")")
DATETIME=$(date +'%m%d%H%M')

GAPBS_DIR="/home/l1/Documents/HotTLB-new-apps/gapbs-1.5"
OUTPUT_FILE="$DATAPATH/cc.out.$DATETIME.vanilla"

CC_PID=""

cleanup() {
    if [[ -n "$CC_PID" ]] && kill -0 "$CC_PID" 2>/dev/null; then
        kill -TERM "$CC_PID" 2>/dev/null || true
        wait "$CC_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

mkdir -p /tmp/enablement

export OMP_NUM_THREADS=32
export OMP_DYNAMIC=FALSE
export OMP_PROC_BIND=TRUE
export OMP_PLACES=cores

cd "$GAPBS_DIR"

./switch_bench_profile.sh vanilla cc

taskset -a -c 0-31 \
    "$GAPBS_DIR/cc" \
    -g 30 \
    -k 12\
    -n 5 \
    &>>"$OUTPUT_FILE" &

CC_PID=$!

echo "GAPBS CC vanilla started with PID $CC_PID"

set +e
wait "$CC_PID"
CC_STATUS=$?
set -e

CC_PID=""

trap - EXIT INT TERM

echo "GAPBS CC vanilla exit status: $CC_STATUS"
echo "Output: $OUTPUT_FILE"
echo "Done."

exit "$CC_STATUS"
