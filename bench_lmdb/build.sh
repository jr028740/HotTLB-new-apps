#!/bin/bash

git clone https://github.com/HdrHistogram/HdrHistogram_c.git
./make_with_lmdb.sh

cd lmdb_work
make
