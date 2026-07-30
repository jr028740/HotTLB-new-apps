#!/bin/bash

if [ ! -d "/tmp/enablement" ]
        then mkdir -p "/tmp/enablement"
fi

taskset -a -c 4-19 /path/to/gapbs-1.5/cc -g 27 -n 11

