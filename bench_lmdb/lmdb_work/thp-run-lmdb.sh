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

LD_LIBRARY_PATH=../lmdb_build/lib:../HdrHistogram_c/src:$LD_LIBRARY_PATH taskset -a -c 7 ./lmdb_run &>> ./lmdb.out.$DATETIME.thp &

DBBENCH_PID=$(sync_result lmdb_run)

datapath=$DATAPATH datetime=$DATETIME /path/to/perf-scripts/common-perf-tlbmiss-process.sh lmdb-thp lmdb_run &

wait $DBBENCH_PID

sudo killall perf
