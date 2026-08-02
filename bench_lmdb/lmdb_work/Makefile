CXX := g++
CXXFLAGS := -std=c++17 -O3 -pthread
CPPFLAGS := -I../lmdb_build/include -I../HdrHistogram_c/include
LDFLAGS := -L../lmdb_build/lib -L../HdrHistogram_c/src
LDLIBS := -llmdb -lhdr_histogram -pthread

WORKING_SET_GIB ?= 1
OPS_PER_ITERATION ?= 1000000
WARMUP_RUNS ?= 1
MEASURED_RUNS ?= 2

DEFINES := \
	-DWORKING_SET_GIB=$(WORKING_SET_GIB) \
	-DOPS_PER_ITERATION=$(OPS_PER_ITERATION) \
	-DWARMUP_RUNS=$(WARMUP_RUNS) \
	-DMEASURED_RUNS=$(MEASURED_RUNS)

all: lmdb_run

lmdb_run: lmdb_run.cc
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) $(DEFINES) $< $(LDFLAGS) $(LDLIBS) -o $@

clean:
	rm -f lmdb_run

.PHONY: all clean
