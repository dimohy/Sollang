import java.lang.management.ManagementFactory;
import java.util.HashSet;

public final class HashSetMixed {
    private record Result(long checksum, int length) {}

    private static Result workload(int count) {
        var values = new HashSet<Integer>((int)Math.ceil(count / 0.75));
        for (var value = 0; value < count; value++) values.add(value);
        long checksum = 0;
        for (var value = 0; value < count; value++)
            if (values.contains(value)) checksum += value;
        for (var value = 0; value < count; value += 2)
            if (values.remove(value)) checksum++;
        return new Result(checksum, values.size());
    }

    public static void main(String[] args) {
        for (var warmup = 0; warmup < 5; warmup++) workload(10_000);
        System.gc();
        var bean = (com.sun.management.ThreadMXBean)ManagementFactory.getThreadMXBean();
        var thread = Thread.currentThread().getId();
        var bytes0 = bean.isThreadAllocatedMemorySupported() ? bean.getThreadAllocatedBytes(thread) : -1;
        var started = System.nanoTime();
        var result = workload(10_000_000);
        var elapsed = System.nanoTime() - started;
        var allocated = bytes0 < 0 ? -1 : bean.getThreadAllocatedBytes(thread) - bytes0;
        System.out.printf("checksum=%d elapsed_ns=%d len=%d capacity=unavailable allocations=unavailable allocated_bytes=%s%n",
            result.checksum(), elapsed, result.length(), allocated < 0 ? "unavailable" : Long.toString(allocated));
    }
}
