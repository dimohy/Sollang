using System;
using System.Collections.Generic;
using System.Linq;

public sealed partial class DropProbe
{
    private readonly List<string> trace = new();
    private int counter;
    private string _currentBlockLabel = "entry";
    private readonly ProbeProgram _program = new();
    private int materializations;
    private int ownedDropCalls;
    private int otherSwitchBranches;
    private string? materializedSourceOwner;
    private string? droppedValue;

    // The classifier itself is extracted unchanged from production. This table
    // supplies explicit owned/non-owned type facts; it is not a compiler model.
    private enum BoundType { SourceText, OwnedStruct, OwnedEnum, Box, StaticInt, StaticText, StaticInline, Scalar }
    private sealed class ProbeProgram { public ProbeTypes Types { get; } = new(); }
    private sealed class ProbeTypes
    {
        public bool IsBox(BoundType type) => type == BoundType.Box;
        public bool IsDynTrait(BoundType type) => false;
        public bool IsStaticArray(BoundType type) => type is BoundType.StaticInt or BoundType.StaticText or BoundType.StaticInline;
        public (int? FixedLength, int Unused) GetStaticArray(BoundType type) => (1, 0);
        public bool IsBoundedArray(BoundType type) => false;
        public bool IsBoundedDictionary(BoundType type) => false;
        public bool IsStruct(BoundType type) => type is BoundType.SourceText or BoundType.OwnedStruct;
        public bool IsEnum(BoundType type) => type == BoundType.OwnedEnum;
        public bool ContainsOwnedStorage(BoundType type) => type != BoundType.Scalar;
    }
    private abstract record RuntimeValue(BoundType Type);
    private sealed record RuntimeOther(BoundType ValueType) : RuntimeValue(ValueType);
    private sealed record RuntimeStaticIntArray() : RuntimeValue(BoundType.StaticInt);
    private sealed record RuntimeStaticTextArray() : RuntimeValue(BoundType.StaticText);
    private sealed record RuntimeStaticInlineArray() : RuntimeValue(BoundType.StaticInline);
    private sealed record Materialized(string ValueName);
    private Materialized MaterializeAggregateValue(RuntimeValue value)
    {
        materializations++;
        materializedSourceOwner = (value as RuntimeSourceText)?.BasePointerName;
        return new Materialized("%materialized");
    }
    private void EmitOwnedDropCall(BoundType type, string value)
    {
        ownedDropCalls++;
        droppedValue = value;
    }

    private string NextTemp(string name) => $"%{name}_{counter++}";
    private string NextLabel(string name) => $"{name}_{counter++}";
    private void EmitCompare(string name, string op, string type, string left, string right)
        => trace.Add($"{name} = icmp {op} {type} {left}, {right}");
    private void EmitConditionalBranch(string condition, string yes, string no)
        => trace.Add($"br {condition}, {yes}, {no}");
    private void EmitFunctionLine() => trace.Add("");
    private void EmitLabel(string label) => trace.Add(label + ":");
    private void EmitBranch(string label) => trace.Add("br " + label);
    private void EmitCall(string? target, string type, string symbol, string arguments)
        => trace.Add($"call {type} @{symbol}({arguments})");

    public (string[] Trace, int Counter, string Block) Observe(string owner, string length)
    {
        EmitSourceTextUnmap(owner, length);
        return (trace.ToArray(), counter, _currentBlockLabel);
    }

    public Route ObserveRoute(string kind, string owner = "null", string length = "0")
    {
        RuntimeValue value = kind switch
        {
            "source" => new RuntimeSourceText("%data", "8", owner, length),
            "struct" => new RuntimeOther(BoundType.OwnedStruct),
            "enum" => new RuntimeOther(BoundType.OwnedEnum),
            "box" => new RuntimeOther(BoundType.Box),
            "static-int" => new RuntimeStaticIntArray(),
            "static-text" => new RuntimeStaticTextArray(),
            "static-inline" => new RuntimeStaticInlineArray(),
            "scalar" => new RuntimeOther(BoundType.Scalar),
            _ => throw new ArgumentException("Unknown probe value.")
        };
        DropOwnedRuntimeValue(value);
        return new(trace.ToArray(), counter, _currentBlockLabel, materializations,
            ownedDropCalls, otherSwitchBranches, materializedSourceOwner, droppedValue);
    }
}

public sealed record Route(string[] Trace, int Counter, string Block, int Materializations,
    int OwnedDrops, int OtherSwitchBranches, string? OriginalSourceOwner, string? DroppedValue);

public static class Program
{
    public static void Main(string[] args)
    {
        bool candidate = args.Single() == "candidate";
        string[] lengths = ["0", "-1", "%mapped_length"];
        int checks = 0;
        foreach (string length in lengths)
        {
            var borrowed = new DropProbe().Observe("null", length);
            if (candidate)
            {
                if (borrowed.Trace.Length != 0 || borrowed.Counter != 0 || borrowed.Block != "entry")
                    throw new Exception("Known borrowed owner must emit nothing and preserve block/name state.");
            }
            else if (!borrowed.Trace.Any(line => line.Contains("@sollang_free(", StringComparison.Ordinal)) ||
                !borrowed.Trace.Any(line => line.Contains("@sollang_mapped_unmap(", StringComparison.Ordinal)))
            {
                throw new Exception("Baseline no longer demonstrates the dead cleanup branches.");
            }
            Console.WriteLine($"null/{length}={borrowed.Trace.Length},{borrowed.Counter},{borrowed.Block}");
            checks++;

            // Unknown owners may be borrowed, heap-backed, or mapped at runtime.
            // Their existing null and ownership-kind checks must remain intact.
            var dynamic = new DropProbe().Observe("%owner", length);
            if (!dynamic.Trace.Any(line => line.Contains("icmp ne ptr %owner, null", StringComparison.Ordinal)) ||
                !dynamic.Trace.Any(line => line.Contains($"icmp eq i64 {length}, -1", StringComparison.Ordinal)) ||
                dynamic.Trace.Count(line => line.Contains("@sollang_free(", StringComparison.Ordinal)) != 1 ||
                dynamic.Trace.Count(line => line.Contains("@sollang_mapped_unmap(", StringComparison.Ordinal)) != 1)
                throw new Exception("Dynamic owner lost its guarded exactly-once heap/map cleanup.");
            Console.WriteLine($"dynamic/{length}={string.Join('|', dynamic.Trace)}");
            checks++;
        }
        var similarName = new DropProbe().Observe("%null_owner", "0");
        if (similarName.Trace.Length == 0) throw new Exception("A name containing null is not a null constant.");
        Console.WriteLine($"HELPER PASS {checks + 1}/7");
        int dispatchChecks = 0;
        foreach (string length in lengths)
        {
            foreach (string owner in new[] { "null", "%owner" })
            {
                Route route = new DropProbe().ObserveRoute("source", owner, length);
                if (candidate)
                {
                    var direct = new DropProbe().Observe(owner, length);
                    if (route.Materializations != 0 || route.OwnedDrops != 0 || route.OtherSwitchBranches != 0 ||
                        !route.Trace.SequenceEqual(direct.Trace) || route.Counter != direct.Counter || route.Block != direct.Block)
                        throw new Exception("SourceText dispatch did not reach the unchanged direct cleanup helper.");
                }
                else if (route.Materializations != 1 || route.OwnedDrops != 1 || route.OtherSwitchBranches != 0 ||
                    route.OriginalSourceOwner != owner || route.DroppedValue != "%materialized" || route.Trace.Length != 0)
                    throw new Exception("Baseline no longer exposes SourceText materialization before cleanup.");
                Console.WriteLine($"dispatch/source/{owner}/{length}=materialize:{route.Materializations},owned:{route.OwnedDrops},other:{route.OtherSwitchBranches},helper-lines:{route.Trace.Length}");
                dispatchChecks++;
            }
        }
        foreach (string kind in new[] { "struct", "enum", "box" })
        {
            Route route = new DropProbe().ObserveRoute(kind);
            if (route.Materializations != 1 || route.OwnedDrops != 1 || route.OtherSwitchBranches != 0 || route.DroppedValue != "%materialized")
                throw new Exception($"Existing custom-owned {kind} fast path changed.");
            Console.WriteLine($"dispatch/control/{kind}=materialize:{route.Materializations},owned:{route.OwnedDrops},other:{route.OtherSwitchBranches}");
            dispatchChecks++;
        }
        foreach (string kind in new[] { "static-int", "static-text", "static-inline", "scalar" })
        {
            Route route = new DropProbe().ObserveRoute(kind);
            // Only dispatch is under test for these cases, not the omitted drop
            // switch bodies. The synthetic default records reaching the switch.
            if (route.Materializations != 0 || route.OwnedDrops != 0 || route.OtherSwitchBranches != 1)
                throw new Exception($"Existing excluded/non-owned {kind} dispatch changed.");
            Console.WriteLine($"dispatch/control/{kind}=materialize:{route.Materializations},owned:{route.OwnedDrops},other:{route.OtherSwitchBranches}");
            dispatchChecks++;
        }
        Console.WriteLine($"DISPATCH PASS {dispatchChecks}/13");
        Console.WriteLine($"PASS {checks + 1 + dispatchChecks}/20");
    }
}
