using System.Text.Json;
using Sollang.Compiler.Semantics;

using var document = JsonDocument.Parse(File.ReadAllText(args[0]));
foreach (var row in document.RootElement.GetProperty("rows").EnumerateArray())
{
    var length = row.GetProperty("length").GetInt32();
    var capacity = row.GetProperty("capacity").GetInt64();
    var offset = row.GetProperty("entriesOffset").GetInt64();
    var bytes = row.GetProperty("allocationBytes").GetInt64();
    if (IntDictionaryLayout.CapacityForLength(length) != capacity
        || IntDictionaryLayout.EntriesOffsetForCapacity(capacity) != offset
        || IntDictionaryLayout.AllocationBytesForCapacity(capacity) != bytes)
    {
        throw new InvalidOperationException($"dictionary arithmetic mismatch at length {length}");
    }
    Console.WriteLine($"{length},{capacity},{offset},{bytes}");
}
if (IntDictionaryLayout.EntryStride != document.RootElement.GetProperty("expectedStride").GetInt32()
    || sizeof(int) != document.RootElement.GetProperty("expectedValueOffset").GetInt32()
    || sizeof(int) != document.RootElement.GetProperty("expectedAlignment").GetInt32())
{
    throw new InvalidOperationException("Int dictionary entry stride mismatch");
}
Console.WriteLine($"layout={sizeof(int)},{IntDictionaryLayout.EntryStride},{sizeof(int)}");
