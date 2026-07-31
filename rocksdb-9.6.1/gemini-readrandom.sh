#!/bin/bash
set -x

sync_result() {
    while true; do
        local monitor=$(pidof "$1")
        if [[ -n "$monitor" ]]; then
            echo "$monitor" # Output the successful PID
            break
        fi
        sleep 1 
    done
}

DATAPATH=$(dirname "$(realpath -e "${BASH_SOURCE[0]:-$0}")")
DATETIME=$(date +'%m%d%H%M')

taskset -a -c 7 ./db_bench --benchmarks=readrandom2 --num=2768240640 --reads=200000000 --value_size=64 --histogram=1 --db=./dbbench_data --use_existing_db=1 &>> ./readrandom.out.$DATETIME.gemini &

DBBENCH_PID=$(sync_result db_bench)

/path/to/pmdmon_start_gemini db_bench

datapath=$DATAPATH datetime=$DATETIME /path/to/perf-scripts/common-perf-tlbmiss-process.sh rocksdb-gemini db_bench &

wait $DBBENCH_PID

sudo killall perf

/path/to/pmdmon_stop
