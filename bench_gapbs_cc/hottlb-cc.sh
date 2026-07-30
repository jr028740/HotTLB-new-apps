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

sync_result2() {
    while true; do
        local monitor=$(pidof "$1")
        if [[ -z "$monitor" ]]; then
            break
        fi
        sleep 1
    done
}

DATAPATH=$(dirname "$(realpath -e "${BASH_SOURCE[0]:-$0}")")
DATETIME=$(date +'%m%d%H%M')

cd /path/to/gapbs-1.5
./switch_bench_profile.sh hottlb cc

cd $DATAPATH

./run_cc.sh &>> ./cc.out.$DATETIME.hottlb &
PR_PID=$!

/path/to/pmdmon_start_hottlb_cc cc

wait $PR_PID

sudo killall perf

/path/to/pmdmon_stop
