#!/bin/bash

if [ -z "$1" ]
        then echo "Provide a config (vanilla/thp/gemini/hottlb) to continue."
        exit 1
fi


if [ -z "$2" ]
	then echo "Provide an application (pr/bc/sssp) to continue."
        exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

make clean
echo "Using $DIR/src/benchmark_$1_$2.h as benchmark.h"
cp $DIR/src/benchmark_$1_$2.h $DIR/src/benchmark.h
make
