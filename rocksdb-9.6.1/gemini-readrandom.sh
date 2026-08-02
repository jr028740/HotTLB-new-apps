#!/bin/bash
set -euo pipefail

DATAPATH=$(dirname "$(realpath -e "${BASH_SOURCE[0]:-$0}")")
DATETIME=$(date +'%m%d%H%M')

PERF_SCRIPT="/home/l1/Documents/HotTLB-new-tools/perf-scripts/common-perf-tlbmiss-process.sh"
GEMINI_DIR="/home/l1/Documents/HotTLB-new-tools/gemini_enable_scripts"

PMDMON_START="$GEMINI_DIR/pmdmon_start_gemini_rocksdb"
PMDMON_STOP="$GEMINI_DIR/pmdmon_stop"

DB_PATH="/home/l1/Documents/dbbench_data_64B_rocksdb"
OUTPUT_FILE="$DATAPATH/readrandom.out.$DATETIME.gemini"

NUM_ENTRIES=1811939328
THREADS=32
TOTAL_READS=200000000
MEASURED_ITERATIONS=20

DBBENCH_PID=""
PERF_SCRIPT_PID=""
PMDMON_STARTED=0

cleanup() {
    if [[ -n "$DBBENCH_PID" ]] && kill -0 "$DBBENCH_PID" 2>/dev/null; then
        kill -TERM "$DBBENCH_PID" 2>/dev/null || true
        wait "$DBBENCH_PID" 2>/dev/null || true
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

if [[ ! -x "$DATAPATH/db_bench" ]]; then
    echo "RocksDB binary not found: $DATAPATH/db_bench"
    exit 1
fi

if [[ ! -d "$DB_PATH" ]]; then
    echo "RocksDB database not found: $DB_PATH"
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
rm -f /tmp/enablement/rocksdb_watch

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

echo "RocksDB Gemini started with PID $DBBENCH_PID"
echo "Database: $DB_PATH"
echo "Configured entries: $NUM_ENTRIES"
echo "Working set: 114 GiB"
echo "Threads: $THREADS"
echo "Aggregate reads per iteration: $TOTAL_READS"
echo "Measured iterations: $MEASURED_ITERATIONS"
echo "Output: $OUTPUT_FILE"

"$PMDMON_START" db_bench
PMDMON_STARTED=1

datapath="$DATAPATH" \
datetime="$DATETIME" \
"$PERF_SCRIPT" rocksdb-gemini "$DBBENCH_PID" &

PERF_SCRIPT_PID=$!

set +e
wait "$DBBENCH_PID"
DBBENCH_STATUS=$?
set -e

DBBENCH_PID=""

"$PMDMON_STOP"
PMDMON_STARTED=0

if [[ -n "$PERF_SCRIPT_PID" ]]; then
    wait "$PERF_SCRIPT_PID" 2>/dev/null || true
    PERF_SCRIPT_PID=""
fi

trap - EXIT INT TERM

echo "RocksDB Gemini exit status: $DBBENCH_STATUS"
echo "Output: $OUTPUT_FILE"
echo "Done."

exit "$DBBENCH_STATUS"
