namespace Sollang.Compiler.Semantics;

internal static class IntDictionaryLayout
{
    public const int EntryStride = sizeof(int) * 2;

    public static long CapacityForLength(int length)
    {
        var minimum = Math.Max((long)length * 2, 4);
        var capacity = 1L;
        while (capacity < minimum)
        {
            capacity = checked(capacity * 2);
        }

        return capacity;
    }

    public static long EntriesOffsetForCapacity(long capacity)
    {
        return checked((capacity + 23) & ~7);
    }

    public static long AllocationBytesForCapacity(long capacity)
    {
        return checked(EntriesOffsetForCapacity(capacity) + (capacity * EntryStride));
    }
}
