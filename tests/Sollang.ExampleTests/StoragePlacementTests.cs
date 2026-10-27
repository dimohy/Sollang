using System.Collections;
using System.Reflection;
using System.Runtime.Loader;
using System.Security.Cryptography;
using System.Text.Json;

internal static class StoragePlacementTests
{
    private sealed record Snapshot(int[] SlotSizes, int[] SlotAlignments,
        int[] SlotsByCandidate, int[][] Ends);

    private static readonly JsonSerializerOptions Json = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true
    };

    private static object Property(object value, string name) =>
        value.GetType().GetProperty(name,
            BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)!
            .GetValue(value)!;

    private static int[] Integers(JsonElement values) =>
        values.EnumerateArray().Select(value => value.GetInt32()).ToArray();

    public static int Run(string compilerPath, string fixturePath, string resultPath)
    {
        var compiler = Path.GetFullPath(compilerPath);
        var fixture = Path.GetFullPath(fixturePath);
        var result = Path.GetFullPath(resultPath);
        if (File.Exists(result)) throw new IOException("A new result path is required.");
        string Hash(string path) => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path)));
        var compilerHash = Hash(compiler);
        var fixtureHash = Hash(fixture);
        using var document = JsonDocument.Parse(File.ReadAllBytes(fixture));
        var root = document.RootElement;
        if (root.GetProperty("schemaVersion").GetInt32() != 1)
            throw new InvalidDataException("Unsupported stack placement fixture schema.");

        var context = new AssemblyLoadContext("storage-placement-reference", isCollectible: true);
        var assembly = context.LoadFromAssemblyPath(compiler);
        if (!string.Equals(assembly.Location, compiler, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("The supplied compiler product was not loaded.");
        var analyzer = assembly.GetType("Sollang.Compiler.Semantics.StoragePlacementAnalyzer", true)!;
        var budget = (int)analyzer.GetField("StackPromotionBudgetBytes",
            BindingFlags.NonPublic | BindingFlags.Static)!.GetRawConstantValue()!;
        if (budget != root.GetProperty("budgetBytes").GetInt32())
            throw new InvalidDataException("Production frame budget differs from the fixture contract.");
        var candidateType = analyzer.GetNestedType("StackCandidate", BindingFlags.NonPublic)!;
        var constructor = candidateType.GetConstructors(
            BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)
            .Single(value => value.GetParameters().Length == 6);
        var allocator = analyzer.GetMethod("AllocateFrame", BindingFlags.NonPublic | BindingFlags.Static)!;
        var cases = new List<object>();
        var identifiers = new HashSet<string>(StringComparer.Ordinal);
        var completed = 0;
        foreach (var item in root.GetProperty("cases").EnumerateArray())
        {
            var id = item.GetProperty("id").GetString()!;
            if (string.IsNullOrWhiteSpace(id) || !identifiers.Add(id))
                throw new InvalidDataException("Missing or duplicate fixture identity.");
            var list = (IList)Activator.CreateInstance(typeof(List<>).MakeGenericType(candidateType))!;
            var units = new List<object>();
            var endUnits = new SortedDictionary<int, object>();
            foreach (var entry in item.GetProperty("candidates").EnumerateArray())
            {
                var size = entry.GetProperty("size").GetInt32();
                var start = entry.GetProperty("start").GetInt32();
                var end = entry.GetProperty("end").GetInt32();
                if (size < 0 || start < 0 || end < start)
                    throw new InvalidDataException("Production candidate preconditions are required.");
                var unit = new object();
                units.Add(unit);
                if (!endUnits.ContainsKey(end)) endUnits.Add(end, new object());
                list.Add(constructor.Invoke([unit, size, start, end, endUnits[end],
                    entry.GetProperty("automaticEnd").GetBoolean()]));
            }
            var plan = allocator.Invoke(null, [list])!;
            var slots = ((IEnumerable)Property(plan, "Slots")).Cast<object>().ToArray();
            var allocations = (IDictionary)Property(plan, "Allocations");
            var endings = plan.GetType().GetMethod("GetLifetimesEndingAfter")!;
            var ends = new List<int[]>();
            foreach (var (position, unit) in endUnits)
                foreach (var allocation in (IEnumerable)endings.Invoke(plan, [unit])!)
                    ends.Add([position, (int)Property(allocation, "SlotIndex"),
                        (int)Property(allocation, "Size")]);
            var actual = new Snapshot(
                slots.Select(slot => (int)Property(slot, "Size")).ToArray(),
                slots.Select(slot => (int)Property(slot, "Alignment")).ToArray(),
                units.Select(unit => allocations.Contains(unit)
                    ? (int)Property(allocations[unit]!, "SlotIndex") : -1).ToArray(),
                ends.ToArray());
            var expectedItem = item.GetProperty("expected");
            var expected = new Snapshot(Integers(expectedItem.GetProperty("slotSizes")),
                Integers(expectedItem.GetProperty("slotAlignments")),
                Integers(expectedItem.GetProperty("slotsByCandidate")),
                expectedItem.GetProperty("ends").EnumerateArray().Select(Integers).ToArray());
            var passed = JsonSerializer.Serialize(actual, Json) == JsonSerializer.Serialize(expected, Json);
            if (passed) completed++;
            cases.Add(new { id, status = passed ? "passed" : "failed", passed, expected, actual });
        }
        if (cases.Count == 0) throw new InvalidDataException("At least one fixture is required.");
        var stable = Hash(compiler) == compilerHash && Hash(fixture) == fixtureHash;
        var accepted = stable && completed == cases.Count;
        Directory.CreateDirectory(Path.GetDirectoryName(result)!);
        File.WriteAllText(result, JsonSerializer.Serialize(new
        {
            schemaVersion = 1,
            scope = "production-stack-frame-allocation-reference",
            status = accepted ? "passed" : "failed",
            completed,
            total = cases.Count,
            compiler,
            compilerDllSha256 = compilerHash,
            fixture,
            fixtureSha256 = fixtureHash,
            budgetBytes = budget,
            inputsStable = stable,
            cases
        }, Json) + "\n");
        context.Unload();
        return accepted ? 0 : 1;
    }
}
