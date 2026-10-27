using System.Collections;
using System.Reflection;
using System.Security.Cryptography;
using System.Text.Json;
using static StoragePlacementTests;

internal static class StoragePlacementSourceTests
{
    private sealed record UnitReference(string Frame, string Kind, int Line, int Column, int Position);
    private sealed record CandidateReference(string Frame, string Kind, int Line, int Column,
        int Size, int StartPosition, int EndPosition, string EndKind, int EndLine, int EndColumn,
        bool EmitAutomaticEnd);

    private static IEnumerable<CandidateReference> ObserveCandidates(string frame, Type analyzer,
        object statements, object? result, object functions)
    {
        var flags = BindingFlags.NonPublic | BindingFlags.Static;
        var positions = analyzer.GetMethod("BuildUnitPositions", flags)!.Invoke(null, [statements, result])!;
        var candidateType = analyzer.GetNestedType("StackCandidate", BindingFlags.NonPublic)!;
        var candidates = Activator.CreateInstance(typeof(List<>).MakeGenericType(candidateType))!;
        analyzer.GetMethod("CollectScopeCandidates", flags)!.Invoke(null,
            [statements, result, functions, positions, candidates]);
        foreach (var candidate in (IEnumerable)candidates)
        {
            var allocation = Property(candidate, "AllocationUnit");
            var end = Property(candidate, "EndUnit");
            var endLocation = end.GetType().Name == "ExpressionStatement" ? Property(end, "Expression") : end;
            yield return new CandidateReference(frame, allocation.GetType().Name,
                (int)Property(allocation, "Line"), (int)Property(allocation, "Column"),
                (int)Property(candidate, "Size"), (int)Property(candidate, "StartPosition"),
                (int)Property(candidate, "EndPosition"), end.GetType().Name,
                (int)Property(endLocation, "Line"), (int)Property(endLocation, "Column"),
                (bool)Property(candidate, "EmitAutomaticEnd"));
        }
    }
    private static IEnumerable<DictionaryEntry> Entries(object dictionary)
    {
        var iterator = ((IDictionary)dictionary).GetEnumerator();
        while (iterator.MoveNext()) yield return iterator.Entry;
    }

    private static string UnitIdentity(object unit)
    {
        var location = unit.GetType().Name == "ExpressionStatement" ? Property(unit, "Expression") : unit;
        return unit.GetType().Name + "@" + Property(location, "Line");
    }

    private static IEnumerable<string> ObserveFrame(string name, object plan)
    {
        yield return name + "|slots:" + string.Join(",", ((IEnumerable)Property(plan, "Slots"))
            .Cast<object>().Select(slot => Property(slot, "Size") + "/" + Property(slot, "Alignment")));
        var allocations = Entries(Property(plan, "Allocations"))
            .Select(pair => (Id: UnitIdentity(pair.Key), Value: pair.Value!)).OrderBy(pair => pair.Id, StringComparer.Ordinal).ToArray();
        if (allocations.Select(pair => pair.Id).Distinct(StringComparer.Ordinal).Count() != allocations.Length)
            throw new InvalidDataException("Source fixture allocation locations must be distinct within a frame.");
        foreach (var pair in allocations)
            yield return name + "|alloc:" + pair.Id + "," + Property(pair.Value, "SlotIndex") + "," + Property(pair.Value, "Size");
        foreach (var pair in Entries(Property(plan, "LifetimeEndsAfter"))
            .OrderBy(pair => UnitIdentity(pair.Key), StringComparer.Ordinal))
            foreach (var allocation in (IEnumerable)pair.Value!)
                yield return name + "|end:" + UnitIdentity(pair.Key) + "," + Property(allocation, "SlotIndex") + "," + Property(allocation, "Size");
    }

    private static IEnumerable<UnitReference> ObserveUnits(string name, MethodInfo index,
        object statements, object? result)
    {
        var positions = index.Invoke(null, [statements, result])!;
        foreach (var pair in Entries(positions).OrderBy(pair => (int)pair.Value!))
        {
            var location = pair.Key.GetType().Name == "ExpressionStatement" ? Property(pair.Key, "Expression") : pair.Key;
            yield return new UnitReference(name, pair.Key.GetType().Name,
                (int)Property(location, "Line"), (int)Property(location, "Column"), (int)pair.Value!);
        }
    }

    internal static int Run(Assembly assembly, JsonElement root, string result,
        string compiler, string fixture, string compilerHash, string fixtureHash)
    {
        var app = assembly.GetType("Sollang.Compiler.Cli.CompilerApp", true)!;
        var loadProgram = app.GetMethod("LoadProgram", BindingFlags.NonPublic | BindingFlags.Static)!;
        var target = Enum.Parse(assembly.GetType("Sollang.Compiler.CompilationTarget", true)!, "WindowsX64");
        var semanticType = assembly.GetType("Sollang.Compiler.Semantics.SemanticCompiler", true)!;
        var analyzer = assembly.GetType("Sollang.Compiler.Semantics.StoragePlacementAnalyzer", true)!;
        var indexUnits = analyzer.GetMethod("BuildUnitPositions", BindingFlags.NonPublic | BindingFlags.Static)!;
        var cases = new List<object>();
        var identifiers = new HashSet<string>(StringComparer.Ordinal);
        var loadedInputs = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        var completed = 0;
        foreach (var item in root.GetProperty("cases").EnumerateArray())
        {
            var id = item.GetProperty("id").GetString()!;
            if (string.IsNullOrWhiteSpace(id) || !id.All(value => char.IsAsciiLetterOrDigit(value) || value == '-')
                || !identifiers.Add(id))
                throw new InvalidDataException("Missing or duplicate source fixture identity.");
            var source = item.GetProperty("source").GetString()!;
            var expected = item.GetProperty("expected").EnumerateArray().Select(value => value.GetString()!).ToArray();
            var expectedWarnings = item.GetProperty("warnings").EnumerateArray().Select(value => value.GetString()!).ToArray();
            var observed = new List<string>();
            var unitReferences = new List<UnitReference>();
            var candidateReferences = new List<CandidateReference>();
            var warnings = Array.Empty<string>();
            string? failure = null;
            try
            {
                var sourceDirectory = Path.Combine(Path.GetDirectoryName(result)!, "sources");
                Directory.CreateDirectory(sourceDirectory);
                var sourcePath = Path.Combine(sourceDirectory, id + ".slg");
                if (File.Exists(sourcePath)) throw new IOException("A new source snapshot path is required.");
                File.WriteAllText(sourcePath, source);
                var loaded = loadProgram.Invoke(null, [new[] { sourcePath }, null, target])!;
                foreach (var input in ((IEnumerable)Property(loaded, "Sources")).Cast<object>())
                {
                    var path = (string)Property(input, "Path");
                    var hash = Convert.ToHexString(SHA256.HashData((byte[])Property(input, "SourceBytes")));
                    if (loadedInputs.TryGetValue(path, out var previous) && previous != hash)
                        throw new InvalidDataException("A production-loaded source changed between cases.");
                    loadedInputs[path] = hash;
                }
                var program = Property(loaded, "Program");
                var semantic = Activator.CreateInstance(semanticType, [program, 64])!;
                var bound = semanticType.GetMethod("Compile")!.Invoke(semantic, [null])!;
                warnings = ((IEnumerable)Property(bound, "Warnings")).Cast<object>()
                    .Select(warning => Property(warning, "Code") + "@" + Property(warning, "Line")).ToArray();
                observed.AddRange(ObserveFrame("main", Property(bound, "MainStackFrame")));
                unitReferences.AddRange(ObserveUnits("main", indexUnits,
                    Property(bound, "MainStatements"), null));
                candidateReferences.AddRange(ObserveCandidates("main", analyzer,
                    Property(bound, "MainStatements"), null, Property(bound, "Functions")));
                foreach (var pair in Entries(Property(bound, "FunctionStackFrames"))
                    .OrderBy(pair => (string)Property(pair.Key, "Name"), StringComparer.Ordinal)
                    .ThenBy(pair => (int)Property(pair.Key, "Line")))
                {
                    var name = "function:" + Property(pair.Key, "Name") + "@" + Property(pair.Key, "Line");
                    observed.AddRange(ObserveFrame(name, pair.Value!));
                    unitReferences.AddRange(ObserveUnits(name, indexUnits,
                        Property(pair.Key, "BlockBody"), Property(pair.Key, "Body")));
                    var scopedFunctions = analyzer.GetMethod("CreateFunctionScope",
                        BindingFlags.NonPublic | BindingFlags.Static)!.Invoke(null,
                            [Property(bound, "Functions"), Property(pair.Key, "LocalFunctions")])!;
                    candidateReferences.AddRange(ObserveCandidates(name, analyzer,
                        Property(pair.Key, "BlockBody"), Property(pair.Key, "Body"), scopedFunctions));
                }
            }
            catch (TargetInvocationException error) when (error.InnerException is not null)
            {
                failure = error.InnerException.ToString();
            }
            var passed = failure is null && expected.SequenceEqual(observed) && expectedWarnings.SequenceEqual(warnings);
            if (passed) completed++;
            cases.Add(new { id, status = passed ? "passed" : "failed", passed, source, expected,
                actual = observed,
                observedUnitPositions = unitReferences.Select(unit => unit.Frame + "|unit:" + unit.Kind + "@" + unit.Line + "," + unit.Position),
                unitReferences, candidateReferences, expectedWarnings, warnings, failure });
        }
        if (cases.Count == 0) throw new InvalidDataException("At least one source frame fixture is required.");
        string Hash(string path) => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path)));
        var stable = Hash(compiler) == compilerHash && Hash(fixture) == fixtureHash
            && loadedInputs.All(pair => Hash(pair.Key) == pair.Value);
        var accepted = stable && completed == cases.Count;
        Directory.CreateDirectory(Path.GetDirectoryName(result)!);
        File.WriteAllText(result, JsonSerializer.Serialize(new
        {
            schemaVersion = 1, scope = "production-source-frame-analysis-reference",
            status = accepted ? "passed" : "failed", completed, total = cases.Count,
            compiler, compilerDllSha256 = compilerHash, fixture, fixtureSha256 = fixtureHash,
            inputsStable = stable, productionLoadedInputs = loadedInputs, cases
        }, new JsonSerializerOptions { WriteIndented = true }) + "\n");
        return accepted ? 0 : 1;
    }
}
