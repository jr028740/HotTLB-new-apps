#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <ctime>
#include <iostream>
#include <thread>
#include <vector>

#include <hdr/hdr_histogram.h>
#include <lmdb.h>

#include <sys/mman.h>

#ifndef WORKING_SET_GIB
#define WORKING_SET_GIB 1
#endif

#ifndef OPS_PER_ITERATION
#define OPS_PER_ITERATION 1000000ULL
#endif

#ifndef WARMUP_RUNS
#define WARMUP_RUNS 1
#endif

#ifndef MEASURED_RUNS
#define MEASURED_RUNS 2
#endif

constexpr uint64_t GIB = 1024ULL * 1024ULL * 1024ULL;
constexpr uint64_t WORKING_SET_BYTES =
    static_cast<uint64_t>(WORKING_SET_GIB) * GIB;
constexpr uint64_t NUM_ELEM =
    WORKING_SET_BYTES / sizeof(uint64_t);

constexpr int THREAD_COUNT = 32;
constexpr int WARMUP_ITERATIONS = WARMUP_RUNS;
constexpr int MEASURED_ITERATIONS = MEASURED_RUNS;
constexpr uint64_t OPERATIONS_PER_ITERATION =
    OPS_PER_ITERATION;

constexpr uint64_t HOT_START =
    NUM_ELEM * 70ULL / 100ULL;
constexpr uint64_t HOT_COUNT =
    NUM_ELEM * 20ULL / 100ULL;

void check_lmdb(int result, const char *operation) {
    if (result != MDB_SUCCESS) {
        std::cerr << operation << ": " << mdb_strerror(result) << "\n";
        std::exit(1);
    }
}

void print_summary(struct hdr_histogram *hist) {
    std::cout << "Latency (ns) histogram summary:\n";
    std::cout << "Min:     " << hdr_min(hist) << "\n";
    std::cout << "Max:     " << hdr_max(hist) << "\n";
    std::cout << "Mean:    " << hdr_mean(hist) << "\n";
    std::cout << "50th:    "
              << hdr_value_at_percentile(hist, 50.0) << "\n";
    std::cout << "95th:    "
              << hdr_value_at_percentile(hist, 95.0) << "\n";
    std::cout << "99th:    "
              << hdr_value_at_percentile(hist, 99.0) << "\n";
    std::cout << "99.9th:  "
              << hdr_value_at_percentile(hist, 99.9) << "\n";
}

uint64_t lfsr_fast(uint64_t value) {
    value ^= value >> 7;
    value ^= value << 9;
    value ^= value >> 13;
    return value;
}

uint64_t select_index(uint64_t &state) {
    state = lfsr_fast(state);

    if (state % 100ULL < 80ULL) {
        return HOT_START + state % HOT_COUNT;
    }

    state = lfsr_fast(state);
    return state % NUM_ELEM;
}

void access_value(uint64_t *values, uint64_t index) {
    uint64_t old_value =
        __atomic_load_n(&values[index], __ATOMIC_RELAXED);

    while (true) {
        uint64_t new_value = __builtin_bswap64(old_value);

        if (__atomic_compare_exchange_n(
                &values[index],
                &old_value,
                new_value,
                false,
                __ATOMIC_RELAXED,
                __ATOMIC_RELAXED)) {
            break;
        }
    }
}

uint64_t operations_for_thread(int thread_id) {
    uint64_t operations = OPERATIONS_PER_ITERATION / THREAD_COUNT;
    uint64_t remainder = OPERATIONS_PER_ITERATION % THREAD_COUNT;

    if (static_cast<uint64_t>(thread_id) < remainder) {
        operations++;
    }

    return operations;
}

void run_warmup_iteration(uint64_t *values, int iteration) {
    std::vector<std::thread> workers;
    workers.reserve(THREAD_COUNT);

    for (int thread_id = 0; thread_id < THREAD_COUNT; thread_id++) {
        workers.emplace_back([values, thread_id, iteration]() {
            uint64_t state =
                0x9e3779b97f4a7c15ULL ^
                (static_cast<uint64_t>(thread_id + 1) << 32) ^
                static_cast<uint64_t>(iteration + 1);

            uint64_t operations = operations_for_thread(thread_id);

            for (uint64_t operation = 0;
                 operation < operations;
                 operation++) {
                uint64_t index = select_index(state);
                access_value(values, index);
            }
        });
    }

    for (auto &worker : workers) {
        worker.join();
    }
}

double run_measured_iteration(
    uint64_t *values,
    int iteration,
    std::vector<struct hdr_histogram *> &histograms) {
    std::vector<std::thread> workers;
    workers.reserve(THREAD_COUNT);

    auto iteration_start =
        std::chrono::steady_clock::now();

    for (int thread_id = 0; thread_id < THREAD_COUNT; thread_id++) {
        workers.emplace_back(
            [values, thread_id, iteration, &histograms]() {
                struct hdr_histogram *histogram = nullptr;

                if (hdr_init(
                        1,
                        100LL * 1000LL * 1000LL * 1000LL,
                        3,
                        &histogram) != 0) {
                    std::cerr
                        << "Failed to create histogram for thread "
                        << thread_id << "\n";
                    std::exit(1);
                }

                uint64_t state =
                    0xd1b54a32d192ed03ULL ^
                    (static_cast<uint64_t>(thread_id + 1) << 32) ^
                    static_cast<uint64_t>(iteration + 1);

                uint64_t operations =
                    operations_for_thread(thread_id);

                for (uint64_t operation = 0;
                     operation < operations;
                     operation++) {
                    uint64_t index = select_index(state);

                    auto start =
                        std::chrono::steady_clock::now();

                    access_value(values, index);

                    auto end =
                        std::chrono::steady_clock::now();

                    int64_t latency_ns =
                        std::chrono::duration_cast<
                            std::chrono::nanoseconds>(
                            end - start)
                            .count();

                    latency_ns = std::max<int64_t>(1, latency_ns);
                    hdr_record_value(histogram, latency_ns);
                }

                histograms[thread_id] = histogram;
            });
    }

    for (auto &worker : workers) {
        worker.join();
    }

    auto iteration_end =
        std::chrono::steady_clock::now();

    return std::chrono::duration<double>(
               iteration_end - iteration_start)
        .count();
}

int main() {
    const char *db_path = "../lmdb-data";

    MDB_env *env = nullptr;
    MDB_dbi dbi;
    MDB_txn *txn = nullptr;
    MDB_cursor *cursor = nullptr;
    MDB_val key;
    MDB_val data;

    check_lmdb(mdb_env_create(&env), "mdb_env_create");
    check_lmdb(mdb_env_set_maxdbs(env, 1), "mdb_env_set_maxdbs");
    check_lmdb(mdb_env_open(env, db_path, 0, 0664), "mdb_env_open");
    check_lmdb(
        mdb_txn_begin(env, nullptr, MDB_RDONLY, &txn),
        "mdb_txn_begin");
    check_lmdb(
        mdb_dbi_open(txn, nullptr, 0, &dbi),
        "mdb_dbi_open");
    check_lmdb(
        mdb_cursor_open(txn, dbi, &cursor),
        "mdb_cursor_open");

    void *mapping = mmap(
        nullptr,
        WORKING_SET_BYTES,
        PROT_READ | PROT_WRITE,
        MAP_PRIVATE | MAP_ANONYMOUS,
        -1,
        0);

    if (mapping == MAP_FAILED) {
        std::cerr << "Failed to allocate "
                  << WORKING_SET_BYTES
                  << " bytes\n";
        return 1;
    }

    auto *values = static_cast<uint64_t *>(mapping);

    uint64_t loaded_elements = 0;
    int cursor_result =
        mdb_cursor_get(cursor, &key, &data, MDB_FIRST);

    while (cursor_result == MDB_SUCCESS &&
           loaded_elements < NUM_ELEM) {
        uint64_t value = 0;
        size_t copy_size =
            std::min<size_t>(sizeof(value), data.mv_size);

        std::memcpy(&value, data.mv_data, copy_size);
        values[loaded_elements] = value;
        loaded_elements++;

        cursor_result =
            mdb_cursor_get(cursor, &key, &data, MDB_NEXT);
    }

    if (loaded_elements == 0) {
        std::cerr << "LMDB database contains no records\n";
        return 1;
    }

    uint64_t populated_elements = loaded_elements;

    while (populated_elements < NUM_ELEM) {
        uint64_t copy_elements = std::min(
            populated_elements,
            NUM_ELEM - populated_elements);

        std::memcpy(
            values + populated_elements,
            values,
            copy_elements * sizeof(uint64_t));

        populated_elements += copy_elements;
    }

    mdb_cursor_close(cursor);
    mdb_txn_abort(txn);
    mdb_dbi_close(env, dbi);
    mdb_env_close(env);

    std::cout << "Threads: " << THREAD_COUNT << "\n";
    std::cout << "LMDB source records: "
              << loaded_elements << "\n";
    std::cout << "Working-set elements: "
              << NUM_ELEM << "\n";
    std::cout << "Working-set bytes: "
              << WORKING_SET_BYTES << "\n";
    std::cout << "Working-set size: "
              << static_cast<double>(WORKING_SET_BYTES) / GIB
              << " GiB\n";
    std::cout << "Operations per iteration: "
              << OPERATIONS_PER_ITERATION << "\n";
    std::cout << "First 5 runs for warming up.\n";

    for (int iteration = 0;
         iteration < WARMUP_ITERATIONS;
         iteration++) {
        auto start = std::chrono::steady_clock::now();

        run_warmup_iteration(values, iteration);

        auto end = std::chrono::steady_clock::now();
        double seconds =
            std::chrono::duration<double>(end - start).count();

        std::cout << "Warmup " << iteration + 1
                  << " elapsed time: "
                  << seconds << "\n";
    }

    std::fprintf(
        stderr,
        "signalling readiness to /tmp/enablement/lmdb_watch\n");

    FILE *ready_file =
        std::fopen("/tmp/enablement/lmdb_watch", "w+");

    if (ready_file == nullptr) {
        std::fprintf(
            stderr,
            "ERROR: could not create readiness file\n");
    } else {
        std::fprintf(
            ready_file,
            "%lu\n",
            static_cast<unsigned long>(std::time(nullptr)));
        std::fclose(ready_file);
    }

    struct hdr_histogram *combined_histogram = nullptr;

    if (hdr_init(
            1,
            100LL * 1000LL * 1000LL * 1000LL,
            3,
            &combined_histogram) != 0) {
        std::cerr << "Failed to create combined histogram\n";
        return 1;
    }

    double total_seconds = 0.0;
    uint64_t total_operations = 0;

    for (int iteration = 0;
         iteration < MEASURED_ITERATIONS;
         iteration++) {
        std::vector<struct hdr_histogram *> histograms(
            THREAD_COUNT,
            nullptr);

        double seconds =
            run_measured_iteration(
                values,
                iteration,
                histograms);

        for (struct hdr_histogram *histogram : histograms) {
            hdr_add(combined_histogram, histogram);
            hdr_close(histogram);
        }

        double throughput =
            static_cast<double>(OPERATIONS_PER_ITERATION) /
            seconds;

        total_seconds += seconds;
        total_operations += OPERATIONS_PER_ITERATION;

        std::cout << "Run " << iteration + 1
                  << " elapsed time: "
                  << seconds << "\n";
        std::cout << "Run " << iteration + 1
                  << " throughput (ops/sec): "
                  << throughput << "\n";
    }

    std::cout << "Aggregate operations: "
              << total_operations << "\n";
    std::cout << "Aggregate elapsed time: "
              << total_seconds << "\n";
    std::cout << "Aggregate throughput (ops/sec): "
              << static_cast<double>(total_operations) /
                     total_seconds
              << "\n";

    print_summary(combined_histogram);

    hdr_close(combined_histogram);
    munmap(mapping, WORKING_SET_BYTES);

    return 0;
}
