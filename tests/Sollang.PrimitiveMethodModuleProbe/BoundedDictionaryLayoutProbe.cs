using System.Collections;
using System.Reflection;
using System.Runtime.Loader;
using System.Text.Json;

internal static class BoundedDictionaryLayoutProbe
{
    private const BindingFlags Flags = BindingFlags.Instance | BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic;
    private static object Get(object value, string name) => value.GetType().GetProperty(name, Flags)!.GetValue(value)!;
    private static object Call(object value, string name, params object?[] args) =>
        value.GetType().GetMethods(Flags).Single(method => method.Name == name && method.GetParameters().Length == args.Length).Invoke(value, args)!;

    private static object CompileTypes(Assembly assembly, string fixture)
    {
        var app = assembly.GetType("Sollang.Compiler.Cli.CompilerApp", true)!;
        var target = Enum.Parse(assembly.GetType("Sollang.Compiler.CompilationTarget", true)!, "WindowsX64");
        var loaded = app.GetMethod("LoadProgram", Flags)!.Invoke(null, [new[] { Path.GetFullPath(fixture) }, null, target])!;
        var semantic = assembly.GetType("Sollang.Compiler.Semantics.SemanticCompiler", true)!;
        var compiler = Activator.CreateInstance(semantic, Flags, null, [Get(loaded, "Program"), 64], null)!;
        return Get(Call(compiler, "Compile", (object?)null), "Types");
    }

    public static int Run(string compilerPath, string fixture)
    {
        var rows = new List<object>();
        using var context = new ProbeContext();
        try
        {
            var assembly = context.LoadFromAssemblyPath(Path.GetFullPath(compilerPath));
            var idType = assembly.GetType("Sollang.Compiler.Semantics.TypeId", true)!;
            var byteType = Enum.Parse(idType, "UInt8");
            foreach (var capacity in new[] { 8, 268435455, 268435456 })
            foreach (var entryPoint in new[] { "intern", "register" })
            {
                // Only compiler metadata is constructed; no dictionary backing or LLVM is generated.
                var table = CompileTypes(assembly, fixture);
                object id;
                if (entryPoint == "intern")
                    id = Call(table, "GetOrAddBoundedDictionary", byteType, byteType, capacity);
                else
                {
                    var method = table.GetType().GetMethod("RegisterBoundedDictionaries", Flags)!;
                    var types = method.GetParameters()[0].ParameterType.GetGenericArguments();
                    var definitions = (IDictionary)Activator.CreateInstance(typeof(Dictionary<,>).MakeGenericType(types))!;
                    id = Enum.ToObject(idType, 900000);
                    definitions.Add(id, Activator.CreateInstance(types[1], byteType, byteType, capacity)!);
                    Call(table, "RegisterBoundedDictionaries", definitions);
                }
                var layout = Call(table, "GetBoundedDictionary", id);
                var actual = new[] { "BucketCapacity", "EntriesOffset", "StorageSize", "Size" }
                    .Select(name => (int)Get(layout, name)).ToArray();
                int[] expected = capacity == 8 ? [16, 32, 64, 72] : [536870912, 536870928, 1610612752, 1610612760];
                if (!actual.SequenceEqual(expected))
                    throw new InvalidOperationException($"{entryPoint}/{capacity}: unexpected layout {string.Join(',', actual)}");
                rows.Add(new { entryPoint, capacity, actual });
            }
            Console.WriteLine(JsonSerializer.Serialize(new { status = "passed", completed = rows.Count, total = 6, rows, codegenInvoked = false }));
            return 0;
        }
        catch (Exception error)
        {
            while (error is TargetInvocationException { InnerException: { } inner }) error = inner;
            Console.WriteLine(JsonSerializer.Serialize(new { status = "failed", completed = rows.Count, total = 6, rows, error = error.Message, codegenInvoked = false }));
            return 1;
        }
    }

    private sealed class ProbeContext() : AssemblyLoadContext(isCollectible: true), IDisposable
    {
        public void Dispose() => Unload();
    }
}
