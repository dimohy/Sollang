package main

import (
    "fmt"
    "runtime"
    "time"
)

func workload(count int) (int64, int) {
    values := make(map[int]struct{}, count)
    for value := 0; value < count; value++ { values[value] = struct{}{} }
    var checksum int64
    for value := 0; value < count; value++ {
        if _, ok := values[value]; ok { checksum += int64(value) }
    }
    for value := 0; value < count; value += 2 {
        if _, ok := values[value]; ok { delete(values, value); checksum++ }
    }
    return checksum, len(values)
}

func main() {
    workload(10_000)
    runtime.GC()
    var before, after runtime.MemStats
    runtime.ReadMemStats(&before)
    started := time.Now()
    checksum, length := workload(10_000_000)
    elapsed := time.Since(started).Nanoseconds()
    runtime.ReadMemStats(&after)
    fmt.Printf("checksum=%d elapsed_ns=%d len=%d capacity=unavailable allocations=%d allocated_bytes=%d\n",
        checksum, elapsed, length, after.Mallocs-before.Mallocs, after.TotalAlloc-before.TotalAlloc)
}
