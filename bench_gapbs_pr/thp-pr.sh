#!/bin/bash
set -euo pipefail

DATAPATH=$(dirname "$(realpath -e "${BASH_SOURCE[0]:-$0}")")
DATETIME=$(date +'%m%d%H%M')

GAPBS_DIR="/home/l1/Documents/HotTLB-new-apps/gapbs-1.5"
OUTPUT_FILE="$DATAPATH/pr.out.$DATETIME.thp"

PR_PID=""

cleanup() {
    if [[ -n "$PR_PID" ]] && kill -0 "$PR_PID" 2>/dev/null; then
        kill -TERM "$PR_PID" 2>/dev/null || true
        wait "$PR_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

mkdir -p /tmp/enablement

export OMP_NUM_THREADS=32
export OMP_DYNAMIC=FALSE
export OMP_PROC_BIND=TRUE
export OMP_PLACES=cores

cd "$GAPBS_DIR"

./switch_bench_profile.sh thp pr

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

echo "GAPBS PR THP started with PID $PR_PID"

set +e
wait "$PR_PID"
PR_STATUS=$?
set -e

PR_PID=""

trap - EXIT INT TERM

echo "GAPBS PR THP exit status: $PR_STATUS"
echo "Output: $OUTPUT_FILE"
echo "Done."

exit "$PR_STATUS"
