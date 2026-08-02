#!/bin/bash
set -euo pipefail

DATAPATH=$(dirname "$(realpath -e "${BASH_SOURCE[0]:-$0}")")
DATETIME=$(date +'%m%d%H%M')

GAPBS_DIR="/home/l1/Documents/HotTLB-new-apps/gapbs-1.5"
OUTPUT_FILE="$DATAPATH/pr.out.$DATETIME.vanilla"

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

./switch_bench_profile.sh vanilla pr

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

echo "GAPBS PR vanilla started with PID $PR_PID"

set +e
wait "$PR_PID"
PR_STATUS=$?
set -e

PR_PID=""

GRAPH_LINE=$(grep -m1 '^Graph has ' "$OUTPUT_FILE" || true)

if [[ -n "$GRAPH_LINE" ]]; then
    NODES=$(awk '{print $3}' <<<"$GRAPH_LINE")
    EDGES=$(awk '{print $6}' <<<"$GRAPH_LINE")

    awk -v nodes="$NODES" -v edges="$EDGES" \
        'BEGIN {
            bytes = (16 * nodes) + (8 * edges) + 8
            printf "Exact PR working set: %.2f GiB\n", bytes / 1073741824
        }'
fi

trap - EXIT INT TERM

echo "GAPBS PR vanilla exit status: $PR_STATUS"
echo "Output: $OUTPUT_FILE"
echo "Done."

exit "$PR_STATUS"
