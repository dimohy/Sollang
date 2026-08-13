#include <atomic>
#include <chrono>
#include <cstdlib>
#include <iostream>
#include <new>
#include <unordered_set>

static std::atomic<unsigned long long> allocations{0};
static std::atomic<unsigned long long> allocated_bytes{0};

void* operator new(std::size_t size) {
    allocations.fetch_add(1, std::memory_order_relaxed);
    allocated_bytes.fetch_add(size, std::memory_order_relaxed);
    if (void* value = std::malloc(size)) return value;
    throw std::bad_alloc();
}
void operator delete(void* pointer) noexcept { std::free(pointer); }
void operator delete(void* pointer, std::size_t) noexcept { std::free(pointer); }

struct Result { long long checksum; std::size_t length; std::size_t capacity; };

Result workload(int count) {
    std::unordered_set<int> values;
    values.reserve(static_cast<std::size_t>(count));
    for (int value = 0; value < count; ++value) values.insert(value);
    long long checksum = 0;
    for (int value = 0; value < count; ++value)
        if (values.contains(value)) checksum += value;
    for (int value = 0; value < count; value += 2)
        if (values.erase(value) != 0) ++checksum;
    return {checksum, values.size(), values.bucket_count()};
}

int main() {
    static_cast<void>(workload(10'000));
    const auto a0 = allocations.load(std::memory_order_relaxed);
    const auto b0 = allocated_bytes.load(std::memory_order_relaxed);
    const auto started = std::chrono::steady_clock::now();
    const auto result = workload(10'000'000);
    const auto elapsed = std::chrono::duration_cast<std::chrono::nanoseconds>(
        std::chrono::steady_clock::now() - started).count();
    std::cout << "checksum=" << result.checksum << " elapsed_ns=" << elapsed
              << " len=" << result.length << " capacity=" << result.capacity
              << " allocations=" << allocations.load(std::memory_order_relaxed) - a0
              << " allocated_bytes=" << allocated_bytes.load(std::memory_order_relaxed) - b0 << '\n';
}
