#!/bin/bash
set -euo pipefail

DATAPATH=$(dirname "$(realpath -e "${BASH_SOURCE[0]:-$0}")")
DATETIME=$(date +'%m%d%H%M')

GAPBS_DIR="/home/l1/Documents/HotTLB-new-apps/gapbs-1.5"
HOTTLB_DIR="/home/l1/Documents/HotTLB-new-tools/hottlb_enable_scripts"

PMDMON_START="$HOTTLB_DIR/pmdmon_start_hottlb_cc"
PMDMON_STOP="$HOTTLB_DIR/pmdmon_stop"

OUTPUT_FILE="$DATAPATH/cc.out.$DATETIME.hottlb"

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
    echo "HotTLB start script not found or not executable: $PMDMON_START"
    exit 1
fi

if [[ ! -x "$PMDMON_STOP" ]]; then
    echo "HotTLB stop script not found or not executable: $PMDMON_STOP"
    exit 1
fi

mkdir -p /tmp/enablement

export OMP_NUM_THREADS=32
export OMP_DYNAMIC=FALSE
export OMP_PROC_BIND=TRUE
export OMP_PLACES=cores

cd "$GAPBS_DIR"

./switch_bench_profile.sh hottlb cc

taskset -a -c 0-31 \
    "$GAPBS_DIR/cc" \
    -g 30 \
    -k 12\
    -n 5 \
    &>>"$OUTPUT_FILE" &

CC_PID=$!

echo "GAPBS CC HotTLB started with PID $CC_PID"

"$PMDMON_START" cc
PMDMON_STARTED=1

set +e
wait "$CC_PID"
CC_STATUS=$?
set -e

CC_PID=""

"$PMDMON_STOP"
PMDMON_STARTED=0

GRAPH_LINE=$(grep -m1 '^Graph has ' "$OUTPUT_FILE" || true)

if [[ -n "$GRAPH_LINE" ]]; then
    NODES=$(awk '{print $3}' <<<"$GRAPH_LINE")
    EDGES=$(awk '{print $6}' <<<"$GRAPH_LINE")
    WSS_BYTES=$((NODES * 4 + (NODES + 1) * 8 + EDGES * 8))

    awk -v bytes="$WSS_BYTES" \
        'BEGIN {
            printf "Exact structural CC working set: %.2f GiB (%d bytes)\n",
                   bytes / 1073741824, bytes
        }'
fi

trap - EXIT INT TERM

echo "GAPBS CC HotTLB exit status: $CC_STATUS"
echo "Output: $OUTPUT_FILE"
echo "Done."

exit "$CC_STATUS"
