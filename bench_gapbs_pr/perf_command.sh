#!/bin/bash

if [ -z "$1" ]
	then echo "Provide a config (vanilla/hgpt/xhgpt) to continue."
	exit 1
fi

if [ -z "$2" ]
	then echo "Provide a pid to continue."
	exit 1
fi


datetime=$(date +'%m%d%H%M%S')

APP_NAME="gapbs_pr"

PERF_PATH="/opt/perf"
PERF_ITEMS="mem_inst_retired.stlb_miss_loads,mem_inst_retired.stlb_miss_stores"

taskset -a -c 0-1 "$PERF_PATH" stat record -e "$PERF_ITEMS" -o "./perf.data" -I 5000 -p "$2" >> "./perf-$APP_NAME-$1.log.$datetime" 2>&1
