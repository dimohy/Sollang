using System.Collections;
using System.Reflection;
using System.Security.Cryptography;
using System.Text.Json;
using static StoragePlacementTests;

internal static class StoragePlacementMergeTests
{
    internal static int Run(Assembly assembly, Type analyzer, JsonElement root, string result,
        string compiler, string fixture, string compilerHash, string fixtureHash)
    {
        var slotType = assembly.GetType("Sollang.Compiler.Semantics.StackSlotPlan", true)!;
        var allocationType = assembly.GetType("Sollang.Compiler.Semantics.StackAllocationPlan", true)!;
        var frameType = assembly.GetType("Sollang.Compiler.Semantics.StackFramePlan", true)!;
        var allocationList = typeof(IReadOnlyList<>).MakeGenericType(allocationType);
        object List(Type type) => Activator.CreateInstance(typeof(List<>).MakeGenericType(type))!;
        IDictionary Dictionary(Type value) => (IDictionary)Activator.CreateInstance(
            typeof(Dictionary<,>).MakeGenericType(typeof(object), value))!;
        var cases = new List<object>();
        var completed = 0;
        foreach (var item in root.GetProperty("cases").EnumerateArray())
        {
            var units = new Dictionary<int, object>();
            object Unit(int id)
            {
                if (!units.TryGetValue(id, out var unit)) units.Add(id, unit = new object());
                return unit;
            }
            object Frame(JsonElement input)
            {
                var slots = (IList)List(slotType);
                foreach (var size in input.GetProperty("slots").EnumerateArray())
                    slots.Add(Activator.CreateInstance(slotType, slots.Count, size.GetInt32(), 8)!);
                var allocations = Dictionary(allocationType);
                foreach (var entry in input.GetProperty("allocations").EnumerateArray())
                    allocations.Add(Unit(entry[0].GetInt32()),
                        Activator.CreateInstance(allocationType, entry[1].GetInt32(), entry[2].GetInt32(), 8)!);
                var endings = Dictionary(allocationList);
                foreach (var entry in input.GetProperty("ends").EnumerateArray())
                {
                    var unit = Unit(entry[0].GetInt32());
                    if (!endings.Contains(unit)) endings.Add(unit, List(allocationType));
                    ((IList)endings[unit]!).Add(Activator.CreateInstance(allocationType,
                        entry[1].GetInt32(), entry[2].GetInt32(), 8)!);
                }
                return Activator.CreateInstance(frameType, slots, allocations, endings)!;
            }
            var primary = Frame(item.GetProperty("primary"));
            var inline = (IList)List(frameType);
            foreach (var frame in item.GetProperty("inline").EnumerateArray()) inline.Add(Frame(frame));
            var merged = analyzer.GetMethod("MergeFramePlans", BindingFlags.NonPublic | BindingFlags.Static)!
                .Invoke(null, [primary, inline])!;
            var allocations = (IDictionary)Property(merged, "Allocations");
            var endings = (IDictionary)Property(merged, "LifetimeEndsAfter");
            var actual = new
            {
                slots = ((IEnumerable)Property(merged, "Slots")).Cast<object>()
                    .Select(slot => (int)Property(slot, "Size")).ToArray(),
                allocations = units.OrderBy(pair => pair.Key).Where(pair => allocations.Contains(pair.Value))
                    .Select(pair => new[] { pair.Key, (int)Property(allocations[pair.Value]!, "SlotIndex"),
                        (int)Property(allocations[pair.Value]!, "Size") }).ToArray(),
                ends = units.OrderBy(pair => pair.Key).Where(pair => endings.Contains(pair.Value))
                    .SelectMany(pair => ((IEnumerable)endings[pair.Value]!).Cast<object>()
                        .Select(allocation => new[] { pair.Key, (int)Property(allocation, "SlotIndex"),
                            (int)Property(allocation, "Size") })).ToArray()
            };
            var expected = item.GetProperty("expected");
            var passed = JsonSerializer.Serialize(actual) == JsonSerializer.Serialize(expected);
            if (passed) completed++;
            cases.Add(new { id = item.GetProperty("id").GetString(), passed, expected, actual });
        }
        string Hash(string path) => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path)));
        var stable = Hash(compiler) == compilerHash && Hash(fixture) == fixtureHash;
        var accepted = cases.Count > 0 && stable && completed == cases.Count;
        File.WriteAllText(result, JsonSerializer.Serialize(new
        {
            schemaVersion = 1, scope = "production-stack-frame-merge-reference",
            status = accepted ? "passed" : "failed", completed, total = cases.Count,
            compiler, compilerHash, fixture, fixtureHash, inputsStable = stable, cases
        }, new JsonSerializerOptions { WriteIndented = true }) + "\n");
        return accepted ? 0 : 1;
    }
}
