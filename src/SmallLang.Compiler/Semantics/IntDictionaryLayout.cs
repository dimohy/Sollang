namespace SmallLang.Compiler.Semantics;

internal static class IntDictionaryLayout
{
    public static int CapacityForLength(int length)
    {
        var minimum = Math.Max(checked(length * 2), 4);
        var capacity = 1;
        while (capacity < minimum)
        {
            capacity = checked(capacity * 2);
        }

        return capacity;
    }

    public static int EntriesOffsetForCapacity(int capacity)
    {
        return capacity == 4 ? 8 : capacity;
    }

    public static int AllocationBytesForCapacity(int capacity)
    {
        return checked(EntriesOffsetForCapacity(capacity) + (capacity * 8));
    }
}
