using System.Reflection;
using System.Text.Json;

if (args.Length is not (2 or 3)
    || args.Length == 3 && args[2] is not ("declared-lengths" or "declared-records" or "context-records" or "hash-vectors" or "key-rule-vectors" or "module-source-vectors" or "module-interface-vectors" or "module-catalog-vectors" or "module-dependency-vectors" or "module-standard-dependency-vectors" or "type-universe-vectors" or "interface-vectors" or "loaded-interface-vectors" or "declaration-vectors" or "member-rule-vectors" or "function-tuple-rule-vectors" or "interface-rule-vectors" or "type-name-vectors"))
    throw new ArgumentException("compiler assembly, artifact directory, and optional probe mode required");
var assembly = Assembly.LoadFrom(Path.GetFullPath(args[0]));
var directory = Path.GetFullPath(args[1]);
Directory.CreateDirectory(directory);
var unitType = assembly.GetType("Sollang.Compiler.CodeGen.LlvmCodegenUnit", true)!;
var keyType = assembly.GetType("Sollang.Compiler.CodeGen.LlvmCodegenKey", true)!;
var kindType = assembly.GetType("Sollang.Compiler.CodeGen.LlvmCodegenUnitKind", true)!;
var outputType = assembly.GetType("Sollang.Compiler.CodeGen.LlvmCodegenOutput", true)!;
var cacheType = assembly.GetType("Sollang.Compiler.Cli.IncrementalCodegenCache", true)!;
var encode = cacheType.GetMethod("Encode", BindingFlags.NonPublic | BindingFlags.Static)!;
var read = cacheType.GetMethod("Read", BindingFlags.NonPublic | BindingFlags.Static)!;

if (args.Length == 3 && args[2] == "type-universe-vectors")
{
    var tableType = assembly.GetType("Sollang.Compiler.Semantics.TypeDefinitionTable", true)!;
    var typeIdType = assembly.GetType("Sollang.Compiler.Semantics.TypeId", true)!;
    object ConvertFact(Type type, JsonElement value)
    {
        if (value.ValueKind == JsonValueKind.Null) return null!;
        type = Nullable.GetUnderlyingType(type) ?? type;
        if (type.IsEnum) return Enum.ToObject(type, value.GetInt32());
        if (type == typeof(string)) return value.GetString()!;
        if (type == typeof(int)) return value.GetInt32();
        if (type == typeof(bool)) return value.GetBoolean();
        if (type.IsGenericType && type.GetGenericTypeDefinition() == typeof(IReadOnlyList<>))
        {
            var element = type.GetGenericArguments()[0];
            var array = Array.CreateInstance(element, value.GetArrayLength());
            var index = 0;
            foreach (var item in value.EnumerateArray()) array.SetValue(ConvertFact(element, item), index++);
            return array;
        }
        var constructor = type.GetConstructors().Single();
        return constructor.Invoke(constructor.GetParameters().Select(parameter =>
            value.TryGetProperty(parameter.Name!, out var item) ? ConvertFact(parameter.ParameterType, item)
            : parameter.HasDefaultValue ? parameter.DefaultValue
            : throw new InvalidOperationException($"missing {type.Name}.{parameter.Name}")).ToArray());
    }
    object Dictionary(string category, JsonElement facts)
    {
        var recordType = tableType.GetProperty(category)!.PropertyType.GetGenericArguments()[0];
        var dictionary = Activator.CreateInstance(typeof(Dictionary<,>).MakeGenericType(typeIdType, recordType))!;
        foreach (var fact in facts.GetProperty(category).EnumerateArray())
            dictionary.GetType().GetMethod("Add")!.Invoke(dictionary,
                [Enum.ToObject(typeIdType, fact.GetProperty("Id").GetInt32()), ConvertFact(recordType, fact)]);
        return dictionary;
    }
    var build = cacheType.GetMethod("BuildTypeUniverseHash", BindingFlags.Static | BindingFlags.NonPublic)!;
    var hash = cacheType.GetMethod("HashFields", BindingFlags.Static | BindingFlags.NonPublic)!;
    using var vectors = JsonDocument.Parse(File.ReadAllText(Path.Combine(directory, "vectors.json")));
    ulong? baseline = null;
    foreach (var vector in vectors.RootElement.EnumerateArray())
    {
        var facts = vector.GetProperty("facts");
        var names = Activator.CreateInstance(typeof(Dictionary<,>).MakeGenericType(typeof(string), typeIdType))!;
        var table = tableType.GetConstructors().Single().Invoke([names,
            Dictionary("Structs", facts), Dictionary("Enums", facts), Dictionary("Boxes", facts),
            Dictionary("References", facts), 8, null, null, null]);
        foreach (var (category, member) in new[] { ("DynTraits", "_dynTraits"), ("StaticArrays", "_staticArrays"),
                     ("DynamicArrays", "_dynamicArrays"), ("Dictionaries", "_dictionaries") })
        {
            var target = tableType.GetField(member, BindingFlags.Instance | BindingFlags.NonPublic)!.GetValue(table)!;
            var records = (System.Collections.IEnumerable)Dictionary(category, facts);
            foreach (var record in records)
                target.GetType().GetMethod("Add")!.Invoke(target,
                    [record.GetType().GetProperty("Key")!.GetValue(record), record.GetType().GetProperty("Value")!.GetValue(record)]);
        }
        var fields = vector.GetProperty("fields").EnumerateArray().Select(field => field.GetString()!).ToArray();
        var actual = (ulong)build.Invoke(null, [table])!;
        if (actual != (ulong)hash.Invoke(null, [fields])!)
            throw new InvalidOperationException("type universe field stream changed: " + vector.GetProperty("id").GetString());
        if (baseline is null) baseline = actual;
        else if (baseline == actual) throw new InvalidOperationException("type universe mutation was ignored");
        Console.WriteLine(JsonSerializer.Serialize(new { id = vector.GetProperty("id").GetString(), fields, hash = actual }));
    }
    return;
}

if (args.Length == 3 && args[2] == "function-tuple-rule-vectors")
{
    var app = assembly.GetType("Sollang.Compiler.Cli.CompilerApp", true)!;
    var paths = Directory.GetFiles(directory, "*.slg").Order(StringComparer.Ordinal).ToArray();
    var target = Enum.Parse(assembly.GetType("Sollang.Compiler.CompilationTarget", true)!, "WindowsX64");
    var loaded = app.GetMethod("LoadProgram", BindingFlags.NonPublic | BindingFlags.Static)!
        .Invoke(null, [paths, null, target])!;
    var sources = ((System.Collections.IEnumerable)loaded.GetType().GetProperty("Sources")!.GetValue(loaded)!).Cast<object>()
        .Where(source => paths.Contains((string)source.GetType().GetProperty("Path")!.GetValue(source)!, StringComparer.Ordinal));
    var functions = sources.SelectMany(source =>
    {
        var program = source.GetType().GetProperty("Program")!.GetValue(source)!;
        return ((System.Collections.IEnumerable)program.GetType().GetProperty("Functions")!.GetValue(program)!).Cast<object>();
    }).ToDictionary(function => (string)function.GetType().GetProperty("Name")!.GetValue(function)!, StringComparer.Ordinal);
    var partType = assembly.GetType("Sollang.Compiler.Shared.CodegenKeyPart", true)!;
    var ruleType = assembly.GetType("Sollang.Compiler.Shared.CodegenKeyRule", true)!;
    var render = assembly.GetType("Sollang.Compiler.Cli.SelfHostPolicyCompiler", true)!
        .GetMethod("RenderKeyRule", BindingFlags.NonPublic | BindingFlags.Static)!;
    var generated = "namespace sollang.compiler.llvm.codegen_cache_key_policy\n";
    var rules = new Dictionary<string, object>(StringComparer.Ordinal);
    foreach (var (group, original) in new[]
    {
        ("Block", new[] { "BlockInput", "BlockResult" }),
        ("Generic", new[] { "GenericPrimary", "GenericSecondary", "GenericTertiary",
            "GenericTraitBound", "GenericAssociatedName", "GenericAssociatedType" })
    })
        foreach (var variant in new[] { "Original", "Reordered", "Relabeled", "Unavailable" })
        {
            var names = variant == "Unavailable" ? ["Identity"]
                : variant == "Reordered" ? original.Reverse().ToArray() : original;
            var parts = Array.CreateInstance(partType, names.Length);
            for (var index = 0; index < names.Length; index++) parts.SetValue(Enum.Parse(partType, names[index]), index);
            var rule = Activator.CreateInstance(ruleType, [variant == "Relabeled" ? "changed-label" : "original", parts])!;
            rules.Add(group + variant, rule);
            generated += "\n" + (string)render.Invoke(null, [group + variant, rule])!;
        }
    foreach (var functionName in new[] { "cache.interfaces.chooseFourth", "cache.remaining.constrained", "cache.tuples.project", "cache.tuples.visit" })
    {
        var group = functionName.StartsWith("cache.tuples.", StringComparison.Ordinal) ? "Block" : "Generic";
        var method = cacheType.GetMethod("Function" + group + "Fields", BindingFlags.NonPublic | BindingFlags.Static)!;
        foreach (var variant in new[] { "Original", "Reordered", "Relabeled", "Unavailable" })
        {
            var name = functionName + "|" + group + variant;
            try
            {
                var fields = ((IEnumerable<string>)method.Invoke(null, [rules[group + variant], functions[functionName]])!).ToArray();
                Console.WriteLine(JsonSerializer.Serialize(new { name, fields, unavailable = false }));
            }
            catch (InvalidOperationException) when (variant == "Unavailable")
            {
                Console.WriteLine(JsonSerializer.Serialize(new { name, fields = Array.Empty<string>(), unavailable = true }));
            }
        }
    }
    File.WriteAllText(Path.Combine(directory, "function-tuple-rules.slg"), generated);
    return;
}

if (args.Length == 3 && args[2] is "module-interface-vectors" or "module-catalog-vectors" or "module-dependency-vectors" or "module-standard-dependency-vectors")
{
    var app = assembly.GetType("Sollang.Compiler.Cli.CompilerApp", true)!;
    var paths = Directory.GetFiles(directory, "*.slg").Order(StringComparer.Ordinal).ToArray();
    var target = Enum.Parse(assembly.GetType("Sollang.Compiler.CompilationTarget", true)!, "WindowsX64");
    var loaded = app.GetMethod("LoadProgram", BindingFlags.NonPublic | BindingFlags.Static)!
        .Invoke(null, [paths, null, target])!;
    var sources = ((System.Collections.IEnumerable)loaded.GetType().GetProperty("Sources")!.GetValue(loaded)!)
        .Cast<object>().Where(source => paths.Contains(
            (string)source.GetType().GetProperty("Path")!.GetValue(source)!, StringComparer.Ordinal)).ToArray();
    var sourceType = assembly.GetType("Sollang.Compiler.Cli.CompilationSource", true)!;
    var create = cacheType.GetMethod("CreateModuleIdentity", BindingFlags.NonPublic | BindingFlags.Static)!;
    var fieldsMethod = cacheType.GetMethod("PublicInterfaceFields", BindingFlags.NonPublic | BindingFlags.Static)!;
    var hashMethod = cacheType.GetMethod("HashFields", BindingFlags.NonPublic | BindingFlags.Static)!;
    if (args[2] is "module-catalog-vectors" or "module-dependency-vectors" or "module-standard-dependency-vectors")
    {
        if (args[2] == "module-standard-dependency-vectors")
            foreach (var source in sources.Take(2))
                sourceType.GetProperty("IsStandardLibrary")!.SetValue(source, true);
        var stable = unitType.GetMethod("StableIdentity", [typeof(string)])!;
        var identities = sources.GroupBy(source =>
            (string)sourceType.GetProperty("ModuleName")!.GetValue(source)!, StringComparer.Ordinal)
            .Select(group => {
                var array = Array.CreateInstance(sourceType, group.Count());
                var index = 0;
                foreach (var source in group) array.SetValue(source, index++);
                return create.Invoke(null, [group.Key, array])!;
            }).ToArray();
        object Property(object value, string name) => value.GetType().GetProperty(name)!.GetValue(value)!;
        if (args[2] != "module-catalog-vectors")
        {
            var dictionaryType = typeof(Dictionary<,>).MakeGenericType(typeof(string), identities[0].GetType());
            var modules = Activator.CreateInstance(dictionaryType)!;
            foreach (var identity in identities)
                dictionaryType.GetMethod("Add")!.Invoke(modules, [Property(identity, "Identity"), identity]);
            var ordered = identities.OrderBy(value => (ulong)stable.Invoke(null, [Property(value, "Identity")])!)
                .ThenBy(value => (string)Property(value, "Identity"), StringComparer.Ordinal).ToArray();
            string Hex(object value) => ((ulong)value).ToString("x16", System.Globalization.CultureInfo.InvariantCulture);
            var ambientFields = ordered.Where(value => (bool)Property(value, "IsStandardLibrary"))
                .SelectMany(value => new[] { (string)Property(value, "Identity"), Hex(Property(value, "InterfaceHash")) }).ToArray();
            var ambientHash = (ulong)hashMethod.Invoke(null, [ambientFields])!;
            var collect = cacheType.GetMethod("CollectDependencyInterfaces", BindingFlags.NonPublic | BindingFlags.Static)!;
            foreach (var identity in ordered)
                Console.WriteLine(JsonSerializer.Serialize(new {
                    name = Property(identity, "Identity"), ambientHash,
                    dependencyFields = collect.Invoke(null, [identity, modules])
                }));
            return;
        }
        foreach (var identity in identities.OrderBy(value => (ulong)stable.Invoke(null, [Property(value, "Identity")])!)
                     .ThenBy(value => (string)Property(value, "Identity"), StringComparer.Ordinal))
            Console.WriteLine(JsonSerializer.Serialize(new {
                name = Property(identity, "Identity"),
                stableHash = stable.Invoke(null, [Property(identity, "Identity")]),
                implementationHash = Property(identity, "ImplementationHash"),
                interfaceHash = Property(identity, "InterfaceHash"),
                imports = Property(identity, "Imports"),
                isStandardLibrary = Property(identity, "IsStandardLibrary")
            }));
        return;
    }
    foreach (var group in sources.GroupBy(source =>
                 (string)sourceType.GetProperty("ModuleName")!.GetValue(source)!, StringComparer.Ordinal)
                 .OrderBy(group => group.Key, StringComparer.Ordinal))
    {
        var ordered = group.OrderBy(source => (string)sourceType.GetProperty("Path")!.GetValue(source)!, StringComparer.Ordinal).ToArray();
        ulong InterfaceHash(IEnumerable<object> values)
        {
            var input = values.ToArray();
            var array = Array.CreateInstance(sourceType, input.Length);
            for (var index = 0; index < input.Length; index++) array.SetValue(input[index], index);
            var identity = create.Invoke(null, [group.Key, array])!;
            return (ulong)identity.GetType().GetProperty("InterfaceHash")!.GetValue(identity)!;
        }
        var fields = ordered.SelectMany(source => (IEnumerable<string>)fieldsMethod.Invoke(null,
            [sourceType.GetProperty("Program")!.GetValue(source)!])!).ToArray();
        var hash = InterfaceHash(ordered);
        if (hash != (ulong)hashMethod.Invoke(null, [fields])! || hash != InterfaceHash(ordered.Reverse()))
            throw new InvalidOperationException("module interface field stream or source ordering differs");
        Console.WriteLine(JsonSerializer.Serialize(new { name = group.Key, fields, hash,
            sources = ordered.Select(source => Path.GetFileName((string)sourceType.GetProperty("Path")!.GetValue(source)!)) }));
    }
    return;
}

if (args.Length == 3 && args[2] == "member-rule-vectors")
{
    var partType = assembly.GetType("Sollang.Compiler.Shared.CodegenKeyPart", true)!;
    var ruleType = assembly.GetType("Sollang.Compiler.Shared.CodegenKeyRule", true)!;
    var member = cacheType.GetMethod("MemberFields", BindingFlags.NonPublic | BindingFlags.Static)!;
    var render = assembly.GetType("Sollang.Compiler.Cli.SelfHostPolicyCompiler", true)!
        .GetMethod("RenderKeyRule", BindingFlags.NonPublic | BindingFlags.Static)!;
    var generated = "namespace sollang.compiler.llvm.codegen_cache_key_policy\n";
    foreach (var (name, domain, names) in new[]
    {
        ("MemberOriginal", "original", new[] { "MemberName", "MemberType" }),
        ("MemberReordered", "original", new[] { "MemberType", "MemberName" }),
        ("MemberRelabeled", "changed-diagnostic-label", new[] { "MemberName", "MemberType" }),
        ("MemberUnavailable", "unavailable", new[] { "Identity" })
    })
    {
        var parts = Array.CreateInstance(partType, names.Length);
        for (var index = 0; index < names.Length; index++) parts.SetValue(Enum.Parse(partType, names[index]), index);
        var rule = Activator.CreateInstance(ruleType, [domain, parts])!;
        generated += "\n" + (string)render.Invoke(null, [name, rule])!;
        try
        {
            var fields = ((IEnumerable<string>)member.Invoke(null, [rule, "value", "Text", null])!).ToArray();
            Console.WriteLine(JsonSerializer.Serialize(new { name, fields, unavailable = false }));
        }
        catch (InvalidOperationException)
        {
            if (name != "MemberUnavailable") throw;
            Console.WriteLine(JsonSerializer.Serialize(new { name, fields = Array.Empty<string>(), unavailable = true }));
        }
    }
    File.WriteAllText(Path.Combine(directory, "member-rule-smoke.slg"), generated);
    return;
}

if (args.Length == 3 && args[2] == "type-name-vectors")
{
    var parser = assembly.GetType("Sollang.Compiler.Parsing.Parser", true)!;
    var builtin = parser.GetMethod("IsBuiltinTypeName", BindingFlags.NonPublic | BindingFlags.Static)!;
    var names = "Unit|Text|Bool|Self|Int|Long|Int8|Int16|Int32|Int64|UInt8|UInt16|UInt32|UInt64|Size|UIntSize|CodePoint|Arena|Arguments|SourceText|MappedBytes|MutableMappedBytes|Float|Double|Float32|Float64|Range|Option|Result|Unknown|cache.Int".Split('|');
    foreach (var name in names)
        Console.WriteLine(JsonSerializer.Serialize(new { name, builtin = (bool)builtin.Invoke(null, [name])! }));
    return;
}

if (args.Length == 3 && args[2] is "interface-vectors" or "loaded-interface-vectors" or "declaration-vectors")
{
    var app = assembly.GetType("Sollang.Compiler.Cli.CompilerApp", true)!;
    var parse = app.GetMethod("ParseSourceFile", BindingFlags.NonPublic | BindingFlags.Static)!;
    var fieldsMethod = cacheType.GetMethod("PublicInterfaceFields", BindingFlags.NonPublic | BindingFlags.Static)!;
    var hashMethod = cacheType.GetMethod("HashFields", BindingFlags.NonPublic | BindingFlags.Static)!;
    var paths = Directory.GetFiles(directory, "*.slg").Order(StringComparer.Ordinal).ToArray();
    if (args[2] is "loaded-interface-vectors" or "declaration-vectors")
    {
        var target = Enum.Parse(assembly.GetType("Sollang.Compiler.CompilationTarget", true)!, "WindowsX64");
        var loaded = app.GetMethod("LoadProgram", BindingFlags.NonPublic | BindingFlags.Static)!
            .Invoke(null, [paths, null, target])!;
        var sources = (System.Collections.IEnumerable)loaded.GetType().GetProperty("Sources")!.GetValue(loaded)!;
        foreach (var source in sources.Cast<object>().Where(source =>
                     paths.Contains((string)source.GetType().GetProperty("Path")!.GetValue(source)!, StringComparer.Ordinal)))
        {
            var program = source.GetType().GetProperty("Program")!.GetValue(source)!;
            var path = (string)source.GetType().GetProperty("Path")!.GetValue(source)!;
            IEnumerable<object> Items(object owner, string property) =>
                ((System.Collections.IEnumerable)owner.GetType().GetProperty(property)!.GetValue(owner)!).Cast<object>();
            string Text(object owner, string property) => (string)owner.GetType().GetProperty(property)!.GetValue(owner)!;
            bool Public(object owner) => (bool)owner.GetType().GetProperty("IsPublic")!.GetValue(owner)!;
            if (args[2] == "declaration-vectors")
            {
                var constructor = program.GetType().GetConstructors().Single();
                var parameters = constructor.GetParameters();
                foreach (var category in new[] { "Structs", "Enums", "Traits", "Functions" })
                    foreach (var declaration in Items(program, category).Where(Public)
                                 .OrderBy(value => Text(value, "Name"), StringComparer.Ordinal))
                    {
                        var arguments = parameters.Select(parameter =>
                            (object)Array.CreateInstance(parameter.ParameterType.GetGenericArguments()[0], 0)).ToArray();
                        var slot = Array.FindIndex(parameters, parameter =>
                            string.Equals(parameter.Name, category, StringComparison.OrdinalIgnoreCase));
                        var singleton = Array.CreateInstance(parameters[slot].ParameterType.GetGenericArguments()[0], 1);
                        singleton.SetValue(declaration, 0);
                        arguments[slot] = singleton;
                        var isolated = constructor.Invoke(arguments);
                        var declarationFields = ((IEnumerable<string>)fieldsMethod.Invoke(null, [isolated])!).ToArray();
                        Console.WriteLine(JsonSerializer.Serialize(new { category, name = Text(declaration, "Name"),
                            fields = declarationFields, hash = (ulong)hashMethod.Invoke(null, [declarationFields])! }));
                    }
                continue;
            }
            var types = Items(program, "Structs").Where(Public).OrderBy(value => Text(value, "Name"), StringComparer.Ordinal)
                .SelectMany(value => Items(value, "Fields").Select(field => Text(field, "TypeName")))
                .Concat(Items(program, "Enums").Where(Public).OrderBy(value => Text(value, "Name"), StringComparer.Ordinal)
                    .SelectMany(value => Items(value, "Variants").Select(variant => Text(variant, "PayloadType"))).Where(value => value is not null))
                .Concat(Items(program, "Traits").Where(Public).OrderBy(value => Text(value, "Name"), StringComparer.Ordinal)
                    .SelectMany(value => Items(value, "Methods").Select(method => Text(method, "ReturnType"))))
                .Concat(Items(program, "Functions").Where(Public).OrderBy(value => Text(value, "Name"), StringComparer.Ordinal)
                    .Select(value => Text(value, "InputType") ?? Text(value, "ReturnType"))).ToArray();
            var fields = ((IEnumerable<string>)fieldsMethod.Invoke(null, [program])!).ToArray();
            Console.WriteLine(JsonSerializer.Serialize(new { name = Path.GetFileNameWithoutExtension(path), types, fields,
                hash = (ulong)hashMethod.Invoke(null, [fields])! }));
        }
        return;
    }
    foreach (var path in paths)
    {
        var parsed = parse.Invoke(null, [path, false, null])!;
        var program = parsed.GetType().GetProperty("Program")!.GetValue(parsed)!;
        var fields = ((IEnumerable<string>)fieldsMethod.Invoke(null, [program])!).ToArray();
        var hash = (ulong)hashMethod.Invoke(null, [fields])!;
        Console.WriteLine(JsonSerializer.Serialize(new { name = Path.GetFileNameWithoutExtension(path), fields, hash }));
    }
    return;
}

if (args.Length == 3 && args[2] == "module-source-vectors")
{
    var programType = assembly.GetType("Sollang.Compiler.Syntax.SollangProgram", true)!;
    var sourceType = assembly.GetType("Sollang.Compiler.Cli.CompilationSource", true)!;
    var programConstructor = programType.GetConstructors().Single();
    var programArguments = programConstructor.GetParameters().Select(parameter =>
        (object)Array.CreateInstance(parameter.ParameterType.GetGenericArguments()[0], 0)).ToArray();
    programArguments[0] = new[] { "same" };
    var program = programConstructor.Invoke(programArguments);
    var identity = cacheType.GetMethod("CreateModuleIdentity", BindingFlags.NonPublic | BindingFlags.Static)!;
    ulong Hash((string Path, string Text)[] files)
    {
        var sources = Array.CreateInstance(sourceType, files.Length);
        for (var index = 0; index < files.Length; index++)
            sources.SetValue(Activator.CreateInstance(sourceType,
                [files[index].Path, program, null, false,
                    System.Text.Encoding.UTF8.GetBytes("namespace same\n# " + files[index].Text + "\n"), null]), index);
        var result = identity.Invoke(null, ["same", sources])!;
        return (ulong)result.GetType().GetProperty("ImplementationHash")!.GetValue(result)!;
    }
    foreach (var (name, files) in new (string, (string, string)[])[]
    {
        ("mixed-case", [("Z.slg", "last"), ("a.slg", "first")]),
        ("case-distinct", [("A.slg", "upper"), ("a.slg", "lower")]),
        ("utf16-order", [("\uE000.slg", "bmp"), ("𐀀.slg", "supplementary")])
    })
        Console.WriteLine(JsonSerializer.Serialize(new { name, hash = Hash(files),
            reversed = Hash(files.Reverse().ToArray()), scope = "virtual CompilationSource metadata; not platform file loading" }));
    Console.WriteLine(JsonSerializer.Serialize(new { name = "comments", hash = Hash([("a.slg", "body")]),
        changed = Hash([("a.slg", "body # comment")]) }));
    var binaryFields = cacheType.GetMethod("HashBinaryFields", BindingFlags.NonPublic | BindingFlags.Static)!;
    ulong Binary(params string[] values) => (ulong)binaryFields.Invoke(null,
        [values.Select(System.Text.Encoding.UTF8.GetBytes).ToArray()])!;
    Console.WriteLine(JsonSerializer.Serialize(new { name = "field-boundaries", hash = Binary("ab", "c"),
        changed = Binary("a", "bc") }));
    return;
}

if (args.Length == 3 && args[2] is "key-rule-vectors" or "interface-rule-vectors")
{
    var policies = assembly.GetType("Sollang.Compiler.Shared.CodegenCacheKeyPolicy", true)!;
    var ruleType = assembly.GetType("Sollang.Compiler.Shared.CodegenKeyRule", true)!;
    var partType = assembly.GetType("Sollang.Compiler.Shared.CodegenKeyPart", true)!;
    var apply = cacheType.GetMethod("HashRule", BindingFlags.NonPublic | BindingFlags.Static)!;
    var invoke = typeof(KeyRuleSmoke).GetMethod(nameof(KeyRuleSmoke.Apply))!.MakeGenericMethod(partType);
    var render = assembly.GetType("Sollang.Compiler.Cli.SelfHostPolicyCompiler", true)!
        .GetMethod("RenderKeyRule", BindingFlags.NonPublic | BindingFlags.Static)!;
    string Hex(ulong value) => value.ToString("x16", System.Globalization.CultureInfo.InvariantCulture);
    var fields = new Dictionary<int, string[]>
    {
        [0] = ["cache.한글.𐀀"], [1] = [Hex(1)], [2] = [Hex(ulong.MaxValue)],
        [3] = [Hex(1UL << 63)], [4] = [Hex(0)],
        [5] = ["alpha", Hex(2), "beta", Hex(3)], [6] = ["cache.한글.𐀀", Hex(4)],
        [7] = ["cache.한글.𐀀", Hex(5), Hex(6)], [8] = [Hex(7)], [9] = [Hex(8)],
        [10] = ["Parent"], [11] = ["public"], [12] = ["first", "Int", "second", "Text"],
        [13] = ["None", "", "Some", "Text"], [14] = ["Item"],
        [15] = ["read", "0", "Item", "1", "Text", "0"],
        [16] = ["Int", "0"], [17] = ["Text"], [18] = ["Int", "Text"], [19] = ["Int"],
        [20] = ["sync"], [21] = ["T", "U", "V", "Display", "Item", "Int"],
        [22] = ["Console", "File"], [23] = ["count", "Int", "0"], [24] = ["Item", "Text"]
    };
    void Output(string name, object rule, Dictionary<int, string[]> input) => Console.WriteLine(
        JsonSerializer.Serialize(new { name, hash = (ulong)invoke.Invoke(null, [apply, rule, input])! }));
    var names = args[2] == "interface-rule-vectors"
        ? new[] { "StructInterface", "EnumInterface", "TraitInterface", "FunctionInterface" }
        : new[] { "ModuleImplementation", "SyntheticInterface", "SyntheticImplementation",
            "WholeInterface", "WholeImplementation", "PrefixInterface", "PrefixImplementation", "SuffixInterface", "SuffixImplementation" };
    foreach (var name in names)
        Output(name, policies.GetMethod(name)!.Invoke(null, null)!, fields);
    if (args[2] == "interface-rule-vectors") return;
    object Rule(string domain, params int[] parts)
    {
        var values = Array.CreateInstance(partType, parts.Length);
        for (var index = 0; index < parts.Length; index++) values.SetValue(Enum.ToObject(partType, parts[index]), index);
        return Activator.CreateInstance(ruleType, [domain, values])!;
    }
    var generated = "namespace sollang.compiler.llvm.codegen_cache_key_policy\n";
    foreach (var (name, rule) in new[]
    {
        ("ChangedOrder", Rule("module-implementation", 5, 4, 3, 2, 1, 0)),
        ("ChangedDomain", Rule("changed-domain", 0, 1, 2, 3, 4, 5)),
        ("DomainOnly", Rule("domain-only")), ("Repeated", Rule("repeated", 0, 0))
    })
    {
        generated += "\n" + (string)render.Invoke(null, [name, rule])!;
        Output(name, rule, fields);
    }
    File.WriteAllText(Path.Combine(directory, "key-rule-smoke.slg"), generated);
    return;
}

if (args.Length == 3 && args[2] == "hash-vectors")
{
    var policy = assembly.GetType("Sollang.Compiler.Shared.CodegenCachePolicy", true)!;
    var checksum = policy.GetMethod("ChecksumMix")!;
    var fingerprint = policy.GetMethod("FingerprintMix")!;
    var render = assembly.GetType("Sollang.Compiler.Cli.SelfHostPolicyCompiler", true)!
        .GetMethod("RenderDecision", BindingFlags.NonPublic | BindingFlags.Static)!;
    var smoke = "namespace cache.hash.smoke\n";
    foreach (var method in typeof(ArithmeticSmoke).GetMethods(BindingFlags.Public | BindingFlags.Static))
        smoke += "\n" + (string)render.Invoke(null, [method])!;
    File.WriteAllText(Path.Combine(directory, "arithmetic-smoke.slg"), smoke);
    ulong[] values = [0, 1, 255, uint.MaxValue, (ulong)uint.MaxValue + 1,
        long.MaxValue, (ulong)long.MaxValue + 1, ulong.MaxValue];
    foreach (var hash in values)
    foreach (var value in values)
        Console.WriteLine(JsonSerializer.Serialize(new { hash, value,
            checksum = (ulong)checksum.Invoke(null, [hash, value])!,
            fingerprint = (ulong)fingerprint.Invoke(null, [hash, value])!,
            subtraction = ArithmeticSmoke.Subtract(hash, value),
            changed = ArithmeticSmoke.Changed(hash, value) }));
    return;
}

if (args.Length == 3 && args[2] == "declared-lengths")
{
    var checkedLength = cacheType.GetMethod("CheckedLength", BindingFlags.NonPublic | BindingFlags.Static)!;
    var identityMaximum = Convert.ToInt64(cacheType.GetField("MaximumIdentityBytes", BindingFlags.NonPublic | BindingFlags.Static)!.GetRawConstantValue());
    var fragmentMaximum = Convert.ToInt64(cacheType.GetField("MaximumFragmentBytes", BindingFlags.NonPublic | BindingFlags.Static)!.GetRawConstantValue());
    foreach (var (description, maximum) in new[]
    {
        ("identity", identityMaximum),
        ("fragment", fragmentMaximum),
        ("fragment words", (long)int.MaxValue)
    })
    {
        foreach (var value in new[] { 0UL, (ulong)maximum - 1, (ulong)maximum, (ulong)maximum + 1, ulong.MaxValue })
        {
            var accepted = true;
            int? result = null;
            string? diagnostic = null;
            try
            {
                result = (int)checkedLength.Invoke(null, [value, maximum, description])!;
            }
            catch (TargetInvocationException error) when (error.InnerException is InvalidDataException)
            {
                accepted = false;
                diagnostic = error.InnerException.Message;
            }
            Console.WriteLine(JsonSerializer.Serialize(new { description, maximum, value, accepted, result, diagnostic }));
        }
    }
    return;
}

if (args.Length == 3)
{
    var units = Array.CreateInstance(unitType, 2);
    for (var index = 0; index < units.Length; index++)
        units.SetValue(Activator.CreateInstance(unitType,
            [Enum.ToObject(kindType, index * 2), "", Activator.CreateInstance(keyType, [101UL, 202UL])!, "", false]), index);
    var output = Activator.CreateInstance(outputType, [units])!;
    if (args[2] == "context-records")
    {
        var words = (IReadOnlyList<ulong>)encode.Invoke(null, [output, 101UL, 202UL, 303UL])!;
        var path = Path.Combine(directory, "context.cgu");
        using (var stream = File.Create(path))
        using (var writer = new BinaryWriter(stream))
            foreach (var word in words) writer.Write(word);
        for (var row = 0; row < 8; row++)
        {
            var accepted = true;
            string? diagnostic = null;
            var compiler = (row & 1) != 0 ? 101UL : 102UL;
            var target = (row & 2) != 0 ? 202UL : 203UL;
            var configuration = (row & 4) != 0 ? 303UL : 304UL;
            try { read.Invoke(null, [path, compiler, target, configuration]); }
            catch (TargetInvocationException error) when (error.InnerException is InvalidDataException)
            {
                accepted = false;
                diagnostic = error.InnerException.Message;
            }
            Console.WriteLine(JsonSerializer.Serialize(new { row, compiler, target, configuration, accepted, diagnostic }));
        }
        return;
    }
    var checksum = cacheType.GetMethod("Checksum", BindingFlags.NonPublic | BindingFlags.Static)!;
    void Observe(ulong kind, ulong declaredFragmentBytes, string label)
    {
        var words = ((IReadOnlyList<ulong>)encode.Invoke(null, [output, 101UL, 202UL, 303UL])!).ToArray();
        words[8] = kind;
        words[13] = declaredFragmentBytes;
        words[7] = (ulong)checksum.Invoke(null, [words, 8, words.Length - 8, 7809847782465536322UL])!;
        var path = Path.Combine(directory, label + ".cgu");
        using (var stream = File.Create(path))
        using (var writer = new BinaryWriter(stream))
            foreach (var word in words) writer.Write(word);
        var accepted = true;
        string? diagnostic = null;
        try { read.Invoke(null, [path, 101UL, 202UL, 303UL]); }
        catch (TargetInvocationException error) when (error.InnerException is InvalidDataException)
        {
            accepted = false;
            diagnostic = error.InnerException.Message;
        }
        Console.WriteLine(JsonSerializer.Serialize(new { label, kind, declaredFragmentBytes, accepted, diagnostic, words }));
    }
    foreach (var length in new[] { 0UL, 1073741825UL, 4294967296UL, 4294967297UL, 9223372036854775808UL, ulong.MaxValue })
        Observe(0, length, $"fragment-{length}");
    foreach (var kind in new[] { 3UL, 4294967296UL, ulong.MaxValue })
        Observe(kind, 0, $"kind-{kind}");
    return;
}

foreach (var length in new[] { 0, 1, 1048576, 1048577 })
{
    var units = Array.CreateInstance(unitType, 3);
    for (var index = 0; index < units.Length; index++)
    {
        var key = Activator.CreateInstance(keyType, [101UL, 202UL])!;
        var identity = index == 1 ? new string('x', length) : "";
        units.SetValue(Activator.CreateInstance(unitType,
            [Enum.ToObject(kindType, index), identity, key, "", false]), index);
    }
    var output = Activator.CreateInstance(outputType, [units])!;
    var words = (IReadOnlyList<ulong>)encode.Invoke(null, [output, 101UL, 202UL, 303UL])!;
    var path = Path.Combine(directory, $"identity-{length}.cgu");
    using (var stream = File.Create(path))
    using (var writer = new BinaryWriter(stream))
        foreach (var word in words) writer.Write(word);
    var accepted = true;
    string? diagnostic = null;
    try
    {
        read.Invoke(null, [path, 101UL, 202UL, 303UL]);
    }
    catch (TargetInvocationException error) when (error.InnerException is InvalidDataException)
    {
        accepted = false;
        diagnostic = error.InnerException.Message;
    }
    Console.WriteLine(JsonSerializer.Serialize(new { length, accepted, diagnostic }));
}

internal static class ArithmeticSmoke
{
    public static ulong Subtract(ulong hash, ulong value) => unchecked(hash - value);
    public static ulong Changed(ulong hash, ulong value) => unchecked(hash * 3 + value);
}

internal static class KeyRuleSmoke
{
    public static ulong Apply<T>(MethodInfo apply, object rule, Dictionary<int, string[]> fields) where T : struct, Enum
    {
        IEnumerable<string> Resolve(T part) => fields[Convert.ToInt32(part)];
        return (ulong)apply.Invoke(null, [rule, (Func<T, IEnumerable<string>>)Resolve])!;
    }
}
