using System.Collections;
using System.Diagnostics;
using System.Reflection;
using System.Runtime.Loader;
using System.Text.Json;

internal static class DropReachabilityProbe
{
    private const BindingFlags Flags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.Static;
    private static object Get(object value, string name) => value.GetType().GetProperty(name, Flags)!.GetValue(value)!;
    private static object Call(object value, string name, params object?[] arguments) => value.GetType().GetMethods(Flags).Single(method => method.Name == name && method.GetParameters().Length == arguments.Length).Invoke(value, arguments)!;
    private static object Create(Type type, params object?[] arguments) => Activator.CreateInstance(type, Flags, null, arguments, null)!;
    private static Type Type(Assembly assembly, string name) => assembly.GetType("Sollang.Compiler." + name, true)!;
    private static void Assert(bool condition, string message) { if (!condition) throw new InvalidOperationException(message); }
    private static object Compile(Assembly assembly, string source)
    {
        var path = File.Exists(source) ? Path.GetFullPath(source) : Path.Combine(AppContext.BaseDirectory, "drop-source-" + Guid.NewGuid().ToString("N") + ".slg");
        if (!File.Exists(source)) File.WriteAllText(path, source);
        var target = Enum.Parse(Type(assembly, "CompilationTarget"), "WindowsX64");
        var loaded = Type(assembly, "Cli.CompilerApp").GetMethod("LoadProgram", Flags)!.Invoke(null, [new[] { path }, null, target])!;
        return Call(Create(Type(assembly, "Semantics.SemanticCompiler"), Get(loaded, "Program"), 64), "Compile", (object?)null);
    }
    private static object Emitter(Assembly assembly, object program, bool shared = false)
    {
        var target = Enum.Parse(Type(assembly, "CompilationTarget"), "WindowsX64");
        var platform = Type(assembly, "CodeGen.LlvmRuntimePlatform").GetMethod("Create", Flags)!.Invoke(null, [target]);
        var contract = Type(assembly, "TargetContract").GetMethod("For", Flags)!.Invoke(null, [target]);
        return Create(Type(assembly, "CodeGen.LlvmEmitter"), program, platform, contract, shared);
    }
    private static object Id(Assembly assembly, int value) => Enum.ToObject(Type(assembly, "Semantics.TypeId"), value);
    private static long Counter(object emitter, string name) => (long)emitter.GetType().GetField(name, Flags)!.GetValue(emitter)!;
    private static int[] Targets(object table)
    {
        var ids = new HashSet<int>();
        foreach (var name in new[] { "Structs", "Enums", "Boxes", "References", "Slices", "StaticArrays", "DynamicArrays", "BoundedArrays", "Dictionaries", "BoundedDictionaries", "BitSets", "DynTraits" })
            foreach (var item in (IEnumerable)Get(table, name)) ids.Add(Convert.ToInt32(Get(item!, "Id")));
        foreach (var id in Enum.GetValues(table.GetType().Assembly.GetType("Sollang.Compiler.Semantics.TypeId")!)) ids.Add(Convert.ToInt32(id));
        ids.Add(987654); // Absent target must stay unreachable.
        return ids.Order().ToArray();
    }
    public static int Run(string baselinePath, string[] fixtures)
    {
        var context = new AssemblyLoadContext("exact-current-before", isCollectible: true);
        var baseline = context.LoadFromAssemblyPath(Path.GetFullPath(baselinePath));
        var current = Assembly.Load("Sollang.Compiler");
        var measureOnly = fixtures.Length > 0 && fixtures[0] == "--measure-only";
        if (measureOnly) fixtures = fixtures.Skip(1).ToArray();
        if (fixtures.SequenceEqual(new[] { "--mutations-only" }))
        {
            ReservedMutation(current);
            MutationCoverage(current);
            Console.WriteLine("{\"status\":\"passed\",\"reservedMutation\":true,\"mutationCoverage\":true,\"inputSnapshotIsolation\":true}");
            return 0;
        }
        var results = new List<object>();
        var publicFixture = Path.Combine(AppContext.BaseDirectory, "drop-public-library.slg");
        File.WriteAllText(publicFixture, "public identity value: Int -> Int { value }\nmain { 7 -> identity => result }\n");
        foreach (var fixture in measureOnly ? fixtures : fixtures.Append(publicFixture))
        {
            var source = File.ReadAllText(fixture);
            foreach (var shared in measureOnly ? new[] { false } : new[] { false, true })
            {
                var oldProgram = Compile(baseline, fixture);
                var newProgram = Compile(current, fixture);
                var oldEmitter = Emitter(baseline, oldProgram, shared);
                var newEmitter = Emitter(current, newProgram, shared);
                var targets = Targets(Get(newProgram, "Types"));
                // Warm both reflection/JIT paths before the same target workload.
                foreach (var id in targets.Take(16))
                {
                    Call(oldEmitter, "IsDropTypeReachable", Id(baseline, id));
                    Call(newEmitter, "IsDropTypeReachable", Id(current, id));
                }
                var allocatedBefore = GC.GetAllocatedBytesForCurrentThread();
                var timer = Stopwatch.StartNew();
                var oldValues = targets.Select(id => (bool)Call(oldEmitter, "IsDropTypeReachable", Id(baseline, id))).ToArray();
                timer.Stop(); var oldMilliseconds = timer.Elapsed.TotalMilliseconds;
                var oldAllocatedBytes = GC.GetAllocatedBytesForCurrentThread() - allocatedBefore;
                allocatedBefore = GC.GetAllocatedBytesForCurrentThread();
                timer.Restart();
                var newValues = targets.Select(id => (bool)Call(newEmitter, "IsDropTypeReachable", Id(current, id))).ToArray();
                timer.Stop();
                var newMilliseconds = timer.Elapsed.TotalMilliseconds;
                var newAllocatedBytes = GC.GetAllocatedBytesForCurrentThread() - allocatedBefore;
                Assert(oldValues.SequenceEqual(newValues), "reachability mismatch " + fixture);
                Assert(Counter(newEmitter, "_dropReachabilityBuilds") == 1, "stable graph rebuilt");
                if (measureOnly)
                {
                    results.Add(new { fixture, targets = targets.Length, oldMilliseconds, newMilliseconds, oldAllocatedBytes, newAllocatedBytes,
                        builds = Counter(newEmitter, "_dropReachabilityBuilds"), nodes = Counter(newEmitter, "_dropReachabilityNodeVisits"),
                        edges = Counter(newEmitter, "_dropReachabilityEdgeVisits"), queries = Counter(newEmitter, "_dropReachabilityQueries") });
                    continue;
                }
                string oldLlvm;
                string newLlvm;
                try { oldLlvm = (string)Call(oldEmitter, "Emit"); }
                catch (TargetInvocationException failure) when (shared && failure.InnerException?.Message == "a Sollang shared library must declare at least one public function")
                {
                    try { Call(newEmitter, "Emit"); throw new InvalidOperationException("changed shared-library rejection"); }
                    catch (TargetInvocationException currentFailure)
                    { Assert(currentFailure.InnerException?.Message == failure.InnerException.Message, "different shared-library failure"); }
                    results.Add(new { fixture, shared, rejection = failure.InnerException.Message, targets = targets.Length });
                    continue;
                }
                newLlvm = (string)Call(newEmitter, "Emit");
                File.WriteAllText(Path.Combine(AppContext.BaseDirectory, Path.GetFileName(fixture) + shared + ".before.ll"), oldLlvm);
                File.WriteAllText(Path.Combine(AppContext.BaseDirectory, Path.GetFileName(fixture) + shared + ".after.ll"), newLlvm);
                Assert(oldLlvm == newLlvm, "exact LLVM differs " + fixture);
                results.Add(new { fixture, shared, targets = targets.Length, oldMilliseconds, newMilliseconds, oldAllocatedBytes, newAllocatedBytes,
                    builds = Counter(newEmitter, "_dropReachabilityBuilds"), nodes = Counter(newEmitter, "_dropReachabilityNodeVisits"),
                    edges = Counter(newEmitter, "_dropReachabilityEdgeVisits"), queries = Counter(newEmitter, "_dropReachabilityQueries") });
            }
        }
        Console.WriteLine(JsonSerializer.Serialize(new { completedGraphControls = results.Count, results }));
        ReservedMutation(current);
        Console.WriteLine(JsonSerializer.Serialize(new { status = "passed", results, reservedMutation = "passed", scope = "isolated exact graph/LLVM; reflection overhead timings not production speed" }));
        context.Unload();
        return 0;
    }
    private static void ReservedMutation(Assembly assembly)
    {
        var program = Compile(assembly, "main { 1 => value }");
        var emitter = Emitter(assembly, program);
        var table = Get(program, "Types");
        var element = Call(table, "GetOrAddReference", Enum.Parse(Type(assembly, "Semantics.TypeId"), "UInt64"));
        var reserved = Id(assembly, 777777);
        Assert((bool)Call(table, "TryReserveStaticArray", reserved, element, null), "reserve failed");
        ((IList)emitter.GetType().GetField("_dropReachabilityRoots", Flags)!.GetValue(emitter)!).Add(reserved);
        var initialBuilds = Counter(emitter, "_dropReachabilityBuilds");
        Assert(!(bool)Call(emitter, "IsDropTypeReachable", element), "unclassified reservation has an edge");
        var before = (long)Get(table, "TypeGraphRevision");
        Assert(Equals(Call(table, "GetOrAddStaticArray", element), reserved), "reservation ID changed");
        Assert((long)Get(table, "TypeGraphRevision") > before, "reserved classification did not advance revision");
        Assert((bool)Call(emitter, "IsDropTypeReachable", element), "stale negative cache");
        Assert(Counter(emitter, "_dropReachabilityBuilds") == initialBuilds + 2, "mutation did not rebuild once");
        before = (long)Get(table, "TypeGraphRevision");
        Call(table, "GetOrAddStaticArray", element);
        Assert((long)Get(table, "TypeGraphRevision") == before, "intern hit advanced revision");
        var additional = Call(table, "GetOrAddSlice", element);
        Assert((long)Get(table, "TypeGraphRevision") > before, "new edge revision missing");
        Call(emitter, "IsDropTypeReachable", additional);
        Assert(Counter(emitter, "_dropReachabilityBuilds") == initialBuilds + 3, "new classification did not rebuild");
        var product = Compile(assembly, "struct Holder { value: Int } enum Choice { Some(Int), None } main { Holder { value: 1 } => value }");
        foreach (var pair in new[] { ("Structs", "Fields"), ("Enums", "Variants") })
        {
            var definitions = (IEnumerable)Get(Get(product, "Types"), pair.Item1);
            foreach (var definition in definitions)
            {
                var list = (IList)Get(definition!, pair.Item2);
                Assert(list.IsReadOnly, "externally mutable graph collection");
                if (list.Count > 0)
                {
                    try { list[0] = list[0]; throw new InvalidOperationException("graph edge mutated without revision"); }
                    catch (NotSupportedException) { }
                }
            }
        }
    }
    private static void MutationCoverage(Assembly assembly)
    {
        var program = Compile(assembly, "struct Holder { value: Int } enum Choice { Some(Int), None } main { Holder { value: 1 } => value }");
        var table = Get(program, "Types");
        var intType = Enum.Parse(Type(assembly, "Semantics.TypeId"), "Int");
        var element = Call(table, "GetOrAddReference", intType);
        var cases = new (string Name, object?[] Arguments)[]
        {
            ("GetOrAddReference", [element]), ("GetOrAddStaticArray", [element]),
            ("GetOrAddFixedStaticArray", [element, 13]), ("GetOrAddDynamicArray", [element]),
            ("GetOrAddBoundedArray", [element, 13]), ("GetOrAddDictionary", [intType, element]),
            ("GetOrAddBoundedDictionary", [intType, element, 13]), ("GetOrAddBinaryHeap", [element]),
            ("GetOrAddDeque", [element]), ("GetOrAddSet", [element]),
            ("GetOrAddOption", [element, "probe.OptionRef"]), ("GetOrAddResult", [element, intType, "probe.ResultRef"]),
            ("GetOrAddStream", [element]), ("GetOrAddEventStream", [element]), ("GetOrAddSlice", [element])
        };
        foreach (var test in cases)
        {
            var before = (long)Get(table, "TypeGraphRevision");
            var id = Call(table, test.Name, test.Arguments);
            Assert((long)Get(table, "TypeGraphRevision") > before, test.Name + " did not advance graph revision");
            before = (long)Get(table, "TypeGraphRevision");
            Assert(Equals(Call(table, test.Name, test.Arguments), id), test.Name + " interning changed identity");
            Assert((long)Get(table, "TypeGraphRevision") == before, test.Name + " interning hit changed graph");
        }
        // RegisterDynamicArrays replaces the existing definition's layout, but
        // retains its exact element edge: this must not create a false epoch.
        var dynamicId = Call(table, "GetOrAddDynamicArray", element);
        var definitions = (IDictionary)Activator.CreateInstance(typeof(Dictionary<,>).MakeGenericType(intType.GetType(), intType.GetType()))!;
        definitions.Add(dynamicId, element);
        var revision = (long)Get(table, "TypeGraphRevision");
        Call(table, "RegisterDynamicArrays", definitions);
        Assert((long)Get(table, "TypeGraphRevision") == revision, "layout-only replacement changed graph");
        Assert(Equals(Get(Call(table, "GetDynamicArray", dynamicId), "ElementType"), element), "layout replacement changed edge");
        var registerElement = Call(table, "GetOrAddReference", Call(table, "GetOrAddReference", element));
        var registrationCases = new (string Name, object? Value)[]
        {
            ("RegisterStaticArrays", null), ("RegisterFixedStaticArrays", 17),
            ("RegisterDynamicArrays", registerElement), ("RegisterBoundedArrays", 17),
            ("RegisterBoundedDictionaries", 17)
        };
        var nextId = 880000;
        foreach (var test in registrationCases)
        {
            var method = table.GetType().GetMethods(Flags).Single(item => item.Name == test.Name);
            var pairTypes = method.GetParameters()[0].ParameterType.GetGenericArguments();
            var dictionary = (IDictionary)Activator.CreateInstance(typeof(Dictionary<,>).MakeGenericType(pairTypes))!;
            object? value;
            if (test.Name == "RegisterDynamicArrays") value = registerElement;
            else if (test.Name == "RegisterBoundedDictionaries") value = Activator.CreateInstance(pairTypes[1], intType, registerElement, 17);
            else value = Activator.CreateInstance(pairTypes[1], registerElement, test.Value);
            dictionary.Add(Id(assembly, nextId++), value);
            revision = (long)Get(table, "TypeGraphRevision");
            Call(table, test.Name, dictionary);
            Assert((long)Get(table, "TypeGraphRevision") > revision, test.Name + " missed initial classification epoch");
        }
        revision = (long)Get(table, "TypeGraphRevision");
        var singleElement = Call(table, "GetOrAddReference", registerElement);
        revision = (long)Get(table, "TypeGraphRevision");
        Call(table, "RegisterDynamicArray", Id(assembly, nextId), singleElement);
        Assert((long)Get(table, "TypeGraphRevision") > revision, "single dynamic registration missed epoch");

        // The semantic builder's input array is copied at publication. Mutating
        // that original array after publication must not mutate graph edges.
        var ctor = table.GetType().GetConstructors(Flags).Single();
        var arguments = new object?[ctor.GetParameters().Length];
        var fields = new[] { "_names", "_structs", "_enums", "_boxes", "_references" };
        for (var index = 0; index < fields.Length; index++)
        {
            var original = (IDictionary)table.GetType().GetField(fields[index], Flags)!.GetValue(table)!;
            var dictionary = (IDictionary)Activator.CreateInstance(original.GetType())!;
            foreach (DictionaryEntry pair in original) dictionary.Add(pair.Key, pair.Value);
            arguments[index] = dictionary;
        }
        arguments[5] = 8;
        var structs = (IDictionary)arguments[1]!;
        var first = structs.Values.Cast<object>().First();
        var clone = first.GetType().GetMethod("MemberwiseClone", Flags)!.Invoke(first, null)!;
        var originalFields = ((IEnumerable)Get(first, "Fields")).Cast<object>().ToArray();
        var mutableFields = Array.CreateInstance(originalFields[0].GetType(), originalFields.Length);
        for (var index = 0; index < originalFields.Length; index++) mutableFields.SetValue(originalFields[index], index);
        clone.GetType().GetProperty("Fields", Flags)!.SetValue(clone, mutableFields);
        structs[Get(clone, "Id")] = clone;
        var published = Create(table.GetType(), arguments);
        mutableFields.SetValue(null, 0);
        Assert(((IEnumerable)Get(Call(published, "GetStruct", Get(clone, "Id")), "Fields")).Cast<object>().First() is not null,
            "publication retained mutable input array alias");
        mutableFields.SetValue(originalFields[0], 0);
        var enums = (IDictionary)arguments[2]!;
        var enumDefinition = enums.Values.Cast<object>().First();
        var enumClone = enumDefinition.GetType().GetMethod("MemberwiseClone", Flags)!.Invoke(enumDefinition, null)!;
        var originalVariants = ((IEnumerable)Get(enumDefinition, "Variants")).Cast<object>().ToArray();
        var mutableVariants = Array.CreateInstance(originalVariants[0].GetType(), originalVariants.Length);
        for (var index = 0; index < originalVariants.Length; index++) mutableVariants.SetValue(originalVariants[index], index);
        enumClone.GetType().GetProperty("Variants", Flags)!.SetValue(enumClone, mutableVariants);
        enums[Get(enumClone, "Id")] = enumClone;
        published = Create(table.GetType(), arguments);
        mutableVariants.SetValue(null, 0);
        Assert(((IEnumerable)Get(Call(published, "GetEnum", Get(enumClone, "Id")), "Variants")).Cast<object>().First() is not null,
            "publication retained mutable variant array alias");
    }
}
