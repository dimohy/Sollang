using System.Reflection;
using System.Runtime.Loader;
using System.Security.Cryptography;
using System.Text.Json;

internal static class SemanticTypeCacheCodecTests
{
    // Run under the test project's matching .NET runtime; PowerShell cannot
    // load a compiler assembly targeting a newer runtime than its own host.
    public static int Run(string compilerPath, string resultPath)
    {
        var compiler = Path.GetFullPath(compilerPath);
        // The example runner references the compiler itself. Loading by assembly
        // identity in its default context can silently select that referenced
        // compiler instead of the supplied baseline product.
        var loadContext = new AssemblyLoadContext("semantic-cache-codec-product", isCollectible: true);
        var assembly = loadContext.LoadFromAssemblyPath(compiler);
        if (!string.Equals(assembly.Location, compiler, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("The supplied compiler product was not loaded.");
        var tableType = assembly.GetType("Sollang.Compiler.Semantics.TypeDefinitionTable", true)!;
        var identityType = assembly.GetType("Sollang.Compiler.Semantics.SemanticStableIdentity", true)!;
        var typeIdType = assembly.GetType("Sollang.Compiler.Semantics.TypeId", true)!;
        var intType = Enum.Parse(typeIdType, "Int");
        var constructor = tableType.GetConstructors().Single();
        var parameters = constructor.GetParameters();
        if (parameters.Length != 9 || parameters[5].Name != "pointerSize")
            throw new InvalidOperationException("TypeDefinitionTable constructor contract changed.");
        object CreateTable()
        {
            var arguments = new object?[parameters.Length];
            for (var index = 0; index < 5; index++)
                arguments[index] = Activator.CreateInstance(typeof(Dictionary<,>)
                    .MakeGenericType(parameters[index].ParameterType.GetGenericArguments()));
            arguments[5] = 8;
            return constructor.Invoke(arguments);
        }
        object Decode(object table, string identity) =>
            identityType.GetMethod("ResolveType")!.Invoke(null, [table, identity])!;
        var rows = new List<object>();
        var passed = 0;
        var methods = new[] { "GetOrAddBitSet", "GetOrAddBinaryHeap", "GetOrAddDeque", "GetOrAddSet", "GetOrAddDynamicArray" };
        foreach (var method in methods)
        {
            var table = CreateTable();
            var value = tableType.GetMethod(method)!.Invoke(table, [method == "GetOrAddBitSet" ? (object)8 : intType])!;
            foreach (var nested in new[] { false, true })
            {
                var tested = nested ? tableType.GetMethod("GetOrAddDynamicArray")!.Invoke(table, [value])! : value;
                var identity = (string)identityType.GetMethod("Type")!.Invoke(null, [table, tested])!;
                var exact = false;
                string? failure = null;
                try { exact = tested.Equals(Decode(table, identity)); }
                catch (TargetInvocationException error) when (error.InnerException is InvalidDataException)
                {
                    failure = error.InnerException.Message;
                }
                if (exact) passed++;
                rows.Add(new { id = method + (nested ? "/nested-array" : "/direct"), identity, passed = exact, failure });
            }
        }
        foreach (var identity in new[] { "BitSet<0>", "BitSet<2147483647>", "Set<builtin:Unknown>", "BinaryHeap<builtin:Int>trailing" })
        {
            var rejected = false;
            try { Decode(CreateTable(), identity); }
            catch (TargetInvocationException error) when (error.InnerException is InvalidDataException)
            {
                rejected = true;
            }
            if (rejected) passed++;
            rows.Add(new { id = "invalid/" + identity, identity, passed = rejected });
        }
        var firstTable = CreateTable();
        var secondTable = CreateTable();
        var bitSet = tableType.GetMethod("GetOrAddBitSet")!;
        var array = tableType.GetMethod("GetOrAddDynamicArray")!;
        var firstType = bitSet.Invoke(firstTable, [257])!;
        var unrelatedType = bitSet.Invoke(secondTable, [263])!;
        var secondType = bitSet.Invoke(secondTable, [257])!;
        foreach (var nested in new[] { false, true })
        {
            var left = nested ? array.Invoke(firstTable, [firstType])! : firstType;
            var right = nested ? array.Invoke(secondTable, [secondType])! : secondType;
            var leftIdentity = (string)identityType.GetMethod("Type")!.Invoke(null, [firstTable, left])!;
            var rightIdentity = (string)identityType.GetMethod("Type")!.Invoke(null, [secondTable, right])!;
            var stable = !left.Equals(right) && leftIdentity == rightIdentity;
            if (stable) passed++;
            rows.Add(new { id = "intern-order/" + (nested ? "nested-array" : "direct"), passed = stable, leftIdentity, rightIdentity });
        }
        var unrelatedIdentity = (string)identityType.GetMethod("Type")!.Invoke(null, [secondTable, unrelatedType])!;
        var targetIdentity = (string)identityType.GetMethod("Type")!.Invoke(null, [secondTable, secondType])!;
        var distinctCapacity = unrelatedIdentity != targetIdentity;
        if (distinctCapacity) passed++;
        rows.Add(new { id = "complete-capacity-identity", passed = distinctCapacity, unrelatedIdentity, targetIdentity });
        var cacheType = assembly.GetType("Sollang.Compiler.Cli.IncrementalSemanticCache", true)!;
        var checkedCount = cacheType.GetMethod("CheckedCount", BindingFlags.NonPublic | BindingFlags.Static)
            ?? throw new InvalidOperationException("Semantic cache count validator contract changed.");
        foreach (var (value, accepted) in new (ulong Value, bool Accepted)[]
                 { (0, true), (1_000_000, true), (1_000_001, false), (ulong.MaxValue, false) })
        {
            var matched = false;
            try
            {
                var decodedCount = (int)checkedCount.Invoke(null, [value])!;
                matched = accepted && decodedCount == (int)value;
            }
            catch (TargetInvocationException error) when (error.InnerException is InvalidDataException)
            {
                matched = !accepted;
            }
            if (matched) passed++;
            rows.Add(new { id = "record-count/" + value, accepted, passed = matched });
        }
        var success = passed == rows.Count;
        var record = new
        {
            schemaVersion = 1,
            status = success ? "passed" : "failed",
            scope = "Semantic type cache roundtrip, recursive collection identity and malformed-cache rejection",
            compiler,
            loadedCompiler = assembly.Location,
            compilerSha256 = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(compiler))),
            completed = passed,
            total = rows.Count,
            cases = rows,
            claimsGoalComplete = false
        };
        File.WriteAllText(resultPath, JsonSerializer.Serialize(record, new JsonSerializerOptions { WriteIndented = true }) + "\n");
        Console.WriteLine($"[semantic type cache codec] {(success ? "PASS" : "FAIL")} {passed}/{rows.Count}; result={resultPath}");
        loadContext.Unload();
        return success ? 0 : 1;
    }
}
