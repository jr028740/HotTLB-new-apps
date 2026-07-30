all: lmdb_run

lmdb_run:
	g++ lmdb_run.cc -I../lmdb_build/include -I../HdrHistogram_c/include -L../lmdb_build/lib -L../HdrHistogram_c/src -llmdb -lhdr_histogram -o lmdb_run

clean:
	rm lmdb_run

.PHONY: all clean
