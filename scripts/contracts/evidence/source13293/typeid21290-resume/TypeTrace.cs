using System.Reflection;
using System.Collections;
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
            static object Snapshot(object table) {
                static IEnumerable<DictionaryEntry> Entries(object dictionary) { foreach(DictionaryEntry item in (IDictionary)dictionary) yield return item; }
                var t=table.GetType();
                object Read(string n)=>t.GetField(n,BindingFlags.Instance|BindingFlags.NonPublic)!.GetValue(table)!;
                var counts=new Dictionary<string,int>();
                foreach(var n in new[]{"_names","_structs","_enums","_boxes","_references","_staticArrays","_dynamicArrays","_boundedArrays","_resultsByTypes","_optionsByValue"}) counts[n]=((IDictionary)Read(n)).Count;
                var names=Entries(Read("_names")).ToDictionary(x=>(string)x.Key,x=>Convert.ToInt32(x.Value));
                var refs=Entries(Read("_references")).Select(x=>new {id=Convert.ToInt32(x.Key),element=Convert.ToInt32(x.Value!.GetType().GetProperty("ElementType")!.GetValue(x.Value))}).ToArray();
                var shapes=new[]{"_staticArrays","_dynamicArrays","_boxes","_slices"}.ToDictionary(n=>n,n=>Entries(Read(n)).Select(x=>new {id=Convert.ToInt32(x.Key),value=x.Value}).ToArray());
                return new {next=Read("_nextParametricTypeId"),counts,names,refs,shapes};
            }
            var table=semanticType.GetField("_types",BindingFlags.Instance|BindingFlags.NonPublic)!.GetValue(semantic)!;
            var before=Snapshot(table);
            var inferred=Invoke(semanticType.GetMethod("InferPrivateFunctionSignatures",BindingFlags.Instance|BindingFlags.NonPublic)!,semantic,[program])!;
            semanticType.GetField("_program",BindingFlags.Instance|BindingFlags.NonPublic)!.SetValue(semantic,inferred);
            var afterInference=Snapshot(table);
            var declared=(IDictionary)Invoke(semanticType.GetMethod("DeclareFunctions",BindingFlags.Instance|BindingFlags.NonPublic)!,semantic,[])!;
            var declarationEcho=declared["echo"]!;
            var prefixInputType=Convert.ToInt32(declarationEcho.GetType().GetProperty("InputType")!.GetValue(declarationEcho));
            var afterDeclarations=Snapshot(table);
            semantic=Activator.CreateInstance(semanticType,BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic,null,[program,64],null)!;
            table=semanticType.GetField("_types",BindingFlags.Instance|BindingFlags.NonPublic)!.GetValue(semantic)!;
            var bound = Invoke(semanticType.GetMethod("Compile", BindingFlags.Instance | BindingFlags.Public)!,
                semantic, [null])!;
            var functions=(IDictionary)bound.GetType().GetProperty("Functions")!.GetValue(bound)!;
            var echo=functions["echo"]!;
            var input=echo.GetType().GetProperty("InputType")!.GetValue(echo);
            var declarations=((IEnumerable)program.GetType().GetProperty("Structs")!.GetValue(program)!).Cast<object>().Select(x=>x.GetType().GetProperty("Name")!.GetValue(x)).ToArray();
            Console.WriteLine(JsonSerializer.Serialize(new {status="passed",codegenInvoked=false,inputType=Convert.ToInt32(input),prefixInputType,structDeclarations=declarations,before,afterInference,afterDeclarations,after=Snapshot(table)}));
            return 0;
        }
        catch (Exception error)
        {
            while (error is TargetInvocationException { InnerException: { } inner }) error = inner;
            Console.Error.WriteLine("sollang: " + error.Message);
            Console.WriteLine(JsonSerializer.Serialize(new { status = "failed", codegenInvoked = false }));
            return 1;
        }
    }
}
