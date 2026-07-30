#include <iostream>
#include <algorithm>
#include <vector>
#include <string>
#include <random>
#include <chrono>
#include <lmdb.h>
#include <hdr/hdr_histogram.h>

#include <sys/time.h>

#define NUM_ELEM 600000000UL

void print_summary(struct hdr_histogram *hist) {
	std::cout << "Latency (ns) histogram summary:\n";
	std::cout << "Min:     " << hdr_min(hist) << "\n";
	std::cout << "Max:     " << hdr_max(hist) << "\n";
	std::cout << "Mean:    " << hdr_mean(hist) << "\n";
	std::cout << "95th:    " << hdr_value_at_percentile(hist, 95.0) << "\n";
	std::cout << "99th:  " << hdr_value_at_percentile(hist, 99.0) << "\n";	
}

static uint64_t lfsr_fast(uint64_t lfsr) {
	lfsr ^= lfsr >> 7;
	lfsr ^= lfsr << 9;
	lfsr ^= lfsr >> 13;
	return lfsr;
}


int main(int argc, char **argv) {
	const char* db_path = "../lmdb-data";
	MDB_env* env;
	MDB_dbi dbi;
	MDB_txn* txn;
	MDB_cursor* cursor;
	MDB_val key, data;
	
	// Create and open environment
	mdb_env_create(&env);
	mdb_env_set_maxdbs(env, 1);
	mdb_env_open(env, db_path, 0, 0664);
	
	// Begin read transaction
	mdb_txn_begin(env, nullptr, MDB_RDONLY, &txn);
	mdb_dbi_open(txn, nullptr, 0, &dbi);  // default database
	
	// Open cursor for iteration
	mdb_cursor_open(txn, dbi, &cursor);
	
	// std::vector<std::string> values;
	std::string *values = new std::string[NUM_ELEM];
	size_t idx = 0;
	
	struct hdr_histogram *hist;
	if (hdr_init(10, 100LL * 1000 * 1000 * 1000, 3, &hist) != 0) {
		std::cerr << "Failed to create histogram.\n";
		return 1;
	}
	
	// Iterate over all key-value pairs
	while (mdb_cursor_get(cursor, &key, &data, MDB_NEXT) == 0) {
		std::string value_str(static_cast<char*>(data.mv_data), 8);
		values[idx] = value_str;
		++idx;
	}

	//	for ( ; idx < 2 * NUM_ELEM; ++idx) {
	//		values[idx] = values[idx - NUM_ELEM];
	//		++idx;
	//	}
	
	// Cleanup
	mdb_cursor_close(cursor);
	mdb_txn_abort(txn);  // read txn can be aborted safely
	mdb_dbi_close(env, dbi);
	mdb_env_close(env);

	srand(1234);
	uint64_t lfsr = rand();

	std::cout << "First 5 runs for warming up." << std::endl;

	for (int iter = 0; iter < 5; ++iter) {
		// Print values
		for (int i = 0; i < 200000000; ++i) {
			size_t index;
			if (lfsr_fast(lfsr) % 100 < 80) {
				lfsr = lfsr_fast(lfsr);
				index = lfsr % (uint64_t)(0.2 * NUM_ELEM) + (uint64_t)(0.7 * NUM_ELEM);
			} else {
				lfsr = lfsr_fast(lfsr);
				index = lfsr % NUM_ELEM;
			}

			std::string *value = &values[index];
			std::reverse(values[index].begin(), values[index].end());
		}
	}

	fprintf(stderr, "signalling readyness to /tmp/enablement/lmdb_watch\n");
	FILE *fd2 = fopen("/tmp/enablement/lmdb_watch", "w+");
	
	if (fd2 == NULL) {
		fprintf (stderr, "ERROR: could not create the shared memory file descriptor\n");
		fprintf (stderr, "Automatic scheme invocation not available\n");
	}
	else {
		fprintf(fd2, "%lu\n", (unsigned long) time(NULL));
		fclose(fd2);
	}

	for (int iter = 0; iter < 10; ++iter) {
		auto elapsed_start = std::chrono::high_resolution_clock::now();
		// Print values
		for (int i = 0; i < 200000000; ++i) {
			size_t index;
			if (lfsr_fast(lfsr) % 100 < 80) {
				lfsr = lfsr_fast(lfsr);
				index = lfsr % (uint64_t)(0.2 * NUM_ELEM) + (uint64_t)(0.7 * NUM_ELEM);
			} else {
				lfsr = lfsr_fast(lfsr);
				index = lfsr % NUM_ELEM;
			}

			auto start = std::chrono::high_resolution_clock::now();
			std::string *value = &values[index];
			std::reverse(values[index].begin(), values[index].end());
			auto end = std::chrono::high_resolution_clock::now();
			auto latency_ns = std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();
			hdr_record_value(hist, latency_ns);
		}
		auto elapsed_end = std::chrono::high_resolution_clock::now();

		std::chrono::duration<double> elapsed_seconds = elapsed_end - elapsed_start;

		std::cout << "Elapsed time: " << elapsed_seconds.count() << std::endl;
	}

	print_summary(hist);
	hdr_close(hist);

	delete [] values;

	return 0;
}
