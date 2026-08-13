using System.Diagnostics;

static (long Checksum, int Length) Workload(int count)
{
    var values = new HashSet<int>(count);
    for (var value = 0; value < count; value++) values.Add(value);
    long checksum = 0;
    for (var value = 0; value < count; value++)
        if (values.Contains(value)) checksum += value;
    for (var value = 0; value < count; value += 2)
        if (values.Remove(value)) checksum++;
    return (checksum, values.Count);
}

_ = Workload(10_000);
GC.Collect();
GC.WaitForPendingFinalizers();
GC.Collect();
var bytes0 = GC.GetAllocatedBytesForCurrentThread();
var started = Stopwatch.GetTimestamp();
var result = Workload(10_000_000);
var elapsed = Stopwatch.GetElapsedTime(started).TotalNanoseconds;
var bytes = GC.GetAllocatedBytesForCurrentThread() - bytes0;
Console.WriteLine($"checksum={result.Checksum} elapsed_ns={elapsed:F0} len={result.Length} capacity=unavailable allocations=unavailable allocated_bytes={bytes}");
