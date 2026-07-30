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

time taskset -a -c 4-19 ./svm-train -c 4 -t 0 -e 0.1 -m 800 -v 5 ./data/test2 &>> ./svm.out.$DATETIME.thp &

SVM_PID=$!

datapath=$DATAPATH datetime=$DATETIME /home/dmt/perf-scripts/common-perf-tlbmiss-process.sh svm-thp svm-train &

wait $SVM_PID

sudo killall perf
