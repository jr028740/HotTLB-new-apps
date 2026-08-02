#!/bin/bash
set -euo pipefail

DATAPATH=$(dirname "$(realpath -e "${BASH_SOURCE[0]:-$0}")")
DATETIME=$(date +'%m%d%H%M')

PERF_SCRIPT="/home/l1/Documents/HotTLB-new-tools/perf-scripts/common-perf-tlbmiss-process.sh"
DB_PATH="/home/l1/Documents/dbbench_data_64B_speedb"
OUTPUT_FILE="$DATAPATH/readrandom.out.$DATETIME.vanilla"

NUM_ENTRIES=1811939328
THREADS=32
TOTAL_READS=200000000
MEASURED_ITERATIONS=20

DBBENCH_PID=""
PERF_SCRIPT_PID=""

cleanup() {
    if [[ -n "$DBBENCH_PID" ]] && kill -0 "$DBBENCH_PID" 2>/dev/null; then
        kill -TERM "$DBBENCH_PID" 2>/dev/null || true
        wait "$DBBENCH_PID" 2>/dev/null || true
    fi

    if [[ -n "$PERF_SCRIPT_PID" ]] && kill -0 "$PERF_SCRIPT_PID" 2>/dev/null; then
        kill -TERM "$PERF_SCRIPT_PID" 2>/dev/null || true
        wait "$PERF_SCRIPT_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

if [[ ! -x "$DATAPATH/db_bench" ]]; then
    echo "Speedb binary not found: $DATAPATH/db_bench"
    exit 1
fi

if [[ ! -d "$DB_PATH" ]]; then
    echo "Speedb database not found: $DB_PATH"
    exit 1
fi

if [[ ! -x "$PERF_SCRIPT" ]]; then
    echo "Perf script not found or not executable: $PERF_SCRIPT"
    exit 1
fi

mkdir -p /tmp/enablement
rm -f /tmp/enablement/speedb_watch

cd "$DATAPATH"

taskset -a -c 0-31 \
    ./db_bench \
    --benchmarks=readrandom2 \
    --num="$NUM_ENTRIES" \
    --reads="$TOTAL_READS" \
    --threads="$THREADS" \
    --value_size=64 \
    --histogram=1 \
    --db="$DB_PATH" \
    --use_existing_db=1 \
    &>>"$OUTPUT_FILE" &

DBBENCH_PID=$!

echo "Speedb vanilla started with PID $DBBENCH_PID"
echo "Database: $DB_PATH"
echo "Configured entries: $NUM_ENTRIES"
echo "Working-set size: 108 GiB"
echo "Threads: $THREADS"
echo "Aggregate reads per iteration: $TOTAL_READS"
echo "Measured iterations: $MEASURED_ITERATIONS"
echo "Output: $OUTPUT_FILE"

datapath="$DATAPATH" \
datetime="$DATETIME" \
"$PERF_SCRIPT" speedb-vanilla "$DBBENCH_PID" &

PERF_SCRIPT_PID=$!

set +e
wait "$DBBENCH_PID"
DBBENCH_STATUS=$?
set -e

DBBENCH_PID=""

if [[ -n "$PERF_SCRIPT_PID" ]]; then
    wait "$PERF_SCRIPT_PID" 2>/dev/null || true
    PERF_SCRIPT_PID=""
fi

trap - EXIT INT TERM

echo "Speedb vanilla exit status: $DBBENCH_STATUS"
echo "Output: $OUTPUT_FILE"
echo "Done."

exit "$DBBENCH_STATUS"
