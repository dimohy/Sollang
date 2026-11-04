namespace Sollang.Compiler.Shared;

// Runtime context entries are LLVM opaque pointers. This order also owns the
// prefix of an asynchronous function's context frame.
[SelfHostPolicy("sollang.compiler.llvm.function_runtime_context",
    "selfhost/llvm/function_runtime_context.slg",
    "src/Sollang.Compiler/Shared/Policies/FunctionRuntimeContextSlot.cs")]
internal enum FunctionRuntimeContextSlot
{
    stdin,
    stdout,
    written,
    read,
    ok_state,
    Count
}

internal static class FunctionRuntimeContext
{
    public static IReadOnlyList<FunctionRuntimeContextSlot> Slots { get; } = CreateSlots();

    public static string Parameters { get; } =
        string.Join(", ", Arguments(static slot => $"%{slot}"));

    public static IEnumerable<string> Arguments(Func<FunctionRuntimeContextSlot, string> valueForSlot) =>
        Slots.Select(slot => $"ptr {valueForSlot(slot)}");

    private static IReadOnlyList<FunctionRuntimeContextSlot> CreateSlots()
    {
        var slots = Enum.GetValues<FunctionRuntimeContextSlot>();
        if (slots.Length != (int)FunctionRuntimeContextSlot.Count + 1
            || slots.Where((slot, index) => (int)slot != index).Any())
        {
            throw new InvalidOperationException("Runtime context slots must be contiguous and end with Count.");
        }
        return Array.AsReadOnly(slots[..^1]);
    }
}
