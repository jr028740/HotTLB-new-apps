#!/bin/bash

#{ time ./svm-train -c 4 -t 0 -e 0.1 -m 800 -v 5 ./data/kddb-raw-libsvm.orig ; } &>> ./result
#{ time ./svm-train -c 4 -t 0 -e 0.1 -m 800 -v 5 ./data/test2 ; } &>> ./result.$(date +'%m%d%H%M')
# { taskset -a -c 7 ./svm-train -c 4 -t 0 -e 0.1 -m 800 -v 5 ./data/test2 ; }
taskset -a -c 4-19 ./svm-train -c 4 -t 0 -e 0.1 -m 800 -v 5 ./data/test2
