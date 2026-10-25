using System.Reflection;
using System.Runtime.ExceptionServices;
using System.Text.Json;

// Temporary adapter to the existing production frontend. Remove when the
// managed compiler exposes a canonical semantic-only check command.
internal static class SemanticPreflight
{
    private static object? Invoke(MethodInfo method, object? owner, object?[] args)
    {
        try { return method.Invoke(owner, args); }
        catch (TargetInvocationException error) when (error.InnerException is { } inner)
        {
            ExceptionDispatchInfo.Capture(inner).Throw();
            throw;
        }
    }

    public static int Main(string[] args)
    {
        try
        {
            if (args.Length < 2) throw new ArgumentException("compiler DLL and source paths required");
            var assembly = Assembly.LoadFrom(Path.GetFullPath(args[0]));
            var app = assembly.GetType("Sollang.Compiler.Cli.CompilerApp", true)!;
            var target = Enum.Parse(assembly.GetType("Sollang.Compiler.CompilationTarget", true)!, "WindowsX64");
            var loaded = Invoke(app.GetMethod("LoadProgram", BindingFlags.Static | BindingFlags.NonPublic)!,
                null, [args[1..].Select(Path.GetFullPath).ToArray(), null, target])!;
            var program = loaded.GetType().GetProperty("Program")!.GetValue(loaded)!;
            var semanticType = assembly.GetType("Sollang.Compiler.Semantics.SemanticCompiler", true)!;
            var semantic = Activator.CreateInstance(semanticType,
                BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic, null, [program, 64], null)!;
            var bound = Invoke(semanticType.GetMethod("Compile", BindingFlags.Instance | BindingFlags.Public)!,
                semantic, [null])!;
            object? Get(object o, string n) => o.GetType().GetProperty(n, BindingFlags.Public|BindingFlags.NonPublic|BindingFlags.Instance)!.GetValue(o);
            var functions = (System.Collections.IEnumerable)Get(bound,"Functions")!;
            var types = semanticType.GetField("_types",BindingFlags.NonPublic|BindingFlags.Instance)!.GetValue(semantic)!;
            foreach(var pair in functions) {
                var f=Get(pair!,"Value")!;
                if(Get(f,"Name")?.ToString()?.StartsWith("work")!=true) continue;
                var input=Get(f,"InputType"); var ownership=Get(f,"InputOwnership");
                var supported=Invoke(semanticType.GetMethod("IsAsyncInputTypeSupported",BindingFlags.NonPublic|BindingFlags.Instance)!,semantic,[input,ownership]);
                var owns=input==null?null:Invoke(types.GetType().GetMethod("ContainsOwnedStorage",BindingFlags.Public|BindingFlags.Instance)!,types,[input]);
                Console.WriteLine(JsonSerializer.Serialize(new { name=Get(f,"Name"),input=input?.ToString(),ownership=ownership?.ToString(),asyncInputSupported=supported,containsOwnedStorage=owns,isAsync=Get(f,"IsAsync"),fixedArray=Get(f,"HasValueGenericFixedArrayInput"),specialized=Get(f,"SpecializedValue")?.ToString() }));
            }
            return 0;
        }
        catch (Exception error)
        {
            while (error is TargetInvocationException { InnerException: { } inner }) error = inner;
            Console.Error.WriteLine(error.ToString());
            Console.WriteLine(JsonSerializer.Serialize(new { status = "failed", codegenInvoked = true }));
            return 1;
        }
    }
}
