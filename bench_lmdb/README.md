# LMDB Evaluation
## 1. Run `./build.sh` for building the binaries. Run `./clean.sh` for cleaning the binaries.
## 2. Evaluation scripts and folders are at `lmdb_work`
## 3. Download the lmdb_data from this [link](https://drive.google.com/file/d/1pafJZncdG2HtJmWWaGZ44mBrWTL5SuT-/view?usp=sharing), and decompress it at this directory. It requires an additional 25GB disk space.
## 4. In  `[system]-run-lmdb.sh`, change the  `/path/to/perf-scripts`  to the path of the  `perf-scripts`  directory provided in `HotTLB-new-tools`, and change the  `/path/to/pmdmon_XXX`  to the directory saving the pmdmon scripts.

# Original README.md
# YCSB-cpp

Yahoo! Cloud Serving Benchmark([YCSB](https://github.com/brianfrankcooper/YCSB/wiki)) written in C++.
This is a fork of [YCSB-C](https://github.com/basicthinker/YCSB-C) with some additions

 * Tail latency report using [HdrHistogram_c](https://github.com/HdrHistogram/HdrHistogram_c)
 * Modified the workload more similar to the original YCSB
 * Supported databases: LevelDB, RocksDB, LMDB, WiredTiger, SQLite

# Build YCSB-cpp

## Build with Makefile on POSIX

Initialize submodule and use `make` to build.

```
git clone https://github.com/ls4154/YCSB-cpp.git
cd YCSB-cpp
git submodule update --init
make
```

Databases to bind must be specified as build options. You may also need to add additional link flags (e.g., `-lsnappy`).

To bind LevelDB:
```
make BIND_LEVELDB=1
```

To build with additional libraries and include directories:
```
make BIND_LEVELDB=1 EXTRA_CXXFLAGS=-I/example/leveldb/include \
                    EXTRA_LDFLAGS="-L/example/leveldb/build -lsnappy"
```

Or modify config section in `Makefile`.

RocksDB build example:
```
EXTRA_CXXFLAGS ?= -I/example/rocksdb/include
EXTRA_LDFLAGS ?= -L/example/rocksdb -ldl -lz -lsnappy -lzstd -lbz2 -llz4

BIND_ROCKSDB ?= 1
```

## Build with CMake on POSIX

```shell
git submodule update --init
mkdir build
cd build
cmake -DBIND_ROCKSDB=1 -DBIND_WIREDTIGER=1 -DBIND_LMDB=1 -DBIND_LEVELDB=1 -DWITH_SNAPPY=1 -DWITH_LZ4=1 -DWITH_ZSTD=1 ..
make
```

## Build with CMake+vcpkg on Windows

see [BUILD_ON_WINDOWS](BUILD_ON_WINDOWS.md)

## Running

Load data with leveldb:
```
./ycsb -load -db leveldb -P workloads/workloada -P leveldb/leveldb.properties -s
```

Run workload A with leveldb:
```
./ycsb -run -db leveldb -P workloads/workloada -P leveldb/leveldb.properties -s
```

Load and run workload B with rocksdb:
```
./ycsb -load -run -db rocksdb -P workloads/workloadb -P rocksdb/rocksdb.properties -s
```

Pass additional properties:
```
./ycsb -load -db leveldb -P workloads/workloadb -P rocksdb/rocksdb.properties \
    -p threadcount=4 -p recordcount=10000000 -p leveldb.cache_size=134217728 -s
```
