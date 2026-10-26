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
            if (args.Length < 3) throw new ArgumentException("compiler DLL and source paths required");
            var assembly = Assembly.LoadFrom(Path.GetFullPath(args[0]));
            var app = assembly.GetType("Sollang.Compiler.Cli.CompilerApp", true)!;
            var target = Enum.Parse(assembly.GetType("Sollang.Compiler.CompilationTarget", true)!, "WindowsX64");
            var loaded = Invoke(app.GetMethod("LoadProgram", BindingFlags.Static | BindingFlags.NonPublic)!,
                null, [args[2..].Select(Path.GetFullPath).ToArray(), null, target])!;
            var program = loaded.GetType().GetProperty("Program")!.GetValue(loaded)!;
            var semanticType = assembly.GetType("Sollang.Compiler.Semantics.SemanticCompiler", true)!;
            object? Get(object o, string n) => o.GetType().GetProperty(n, BindingFlags.Public|BindingFlags.NonPublic|BindingFlags.Instance)!.GetValue(o);
            foreach(var validate in new[] { false, true }) {
                var semantic = Activator.CreateInstance(semanticType, BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic,null,[program,64],null)!;
                var bound = Invoke(semanticType.GetMethod("Compile",BindingFlags.Instance|BindingFlags.Public)!,semantic,[null])!;
                var pairs=(System.Collections.IEnumerable)Get(bound,"Functions")!;
                var functions=pairs.Cast<object>().Select(pair=>Get(pair,"Value")!).ToArray();
                var template=functions.Single(f=>Get(f,"ModuleName")?.ToString()=="sample.value_generic_async_cache" && Get(f,"GenericParameterName")?.ToString()=="N" && Get(f,"SpecializedValue")==null);
                var bindings=Get(bound,"MainBindings")!; var input=bindings.GetType().GetProperty("Item")!.GetValue(bindings,["values"])!;
                var types=Get(bound,"Types")!;
                var owned=(bool)Invoke(types.GetType().GetMethod("ContainsOwnedStorage",BindingFlags.Public|BindingFlags.Instance)!,types,[input])!;
                var supported=(bool)Invoke(semanticType.GetMethod("IsAsyncInputTypeSupported",BindingFlags.NonPublic|BindingFlags.Instance)!,semantic,[input,Get(template,"InputOwnership")])!;
                if(!owned || supported) throw new InvalidOperationException("Fixture is not an unsupported owned async input");
                var dictionary=semanticType.GetField("_boundFunctions",BindingFlags.NonPublic|BindingFlags.Instance)!.GetValue(semantic)!;
                var before=(int)Get(dictionary,"Count")!;
                string? diagnostic=null;
                try { Invoke(semanticType.GetMethod("ResolveValueGenericSpecialization",BindingFlags.NonPublic|BindingFlags.Instance)!,semantic,[template,input,2,new object(),validate]); }
                catch(Exception error) when(error.GetType().FullName=="Sollang.Compiler.Diagnostics.SollangException") { diagnostic=error.Message; }
                var after=(int)Get(dictionary,"Count")!;
                var expected="semantic error at 3:8: [module 'sample.value_generic_async_cache'] async functions require a transferable result, a sendable input, and a non-local user declaration; owned inputs must use move";
                var rejected=diagnostic!=null;
                if(args[1]=="reject" ? diagnostic!=expected || after!=before : rejected || after!=before+1)
                    throw new InvalidOperationException($"Unexpected concrete signature outcome: validate={validate}; diagnostic={diagnostic}; counts={before}/{after}");
                Console.WriteLine(JsonSerializer.Serialize(new { validateSpecialization=validate,rejected,owned,supported,functionCountBefore=before,functionCountAfter=after,diagnostic }));
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
