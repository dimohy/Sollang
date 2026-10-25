using System.Reflection;
using System.Runtime.Loader;
using System.Text.Json;
var assembly = new AssemblyLoadContext("type-substitution-probe", true).LoadFromAssemblyPath(Path.GetFullPath(args[0]));
var app = assembly.GetType("Sollang.Compiler.Cli.CompilerApp", true)!;
var target = Enum.Parse(assembly.GetType("Sollang.Compiler.CompilationTarget", true)!, "WindowsX64");
var loaded = app.GetMethod("LoadProgram", BindingFlags.NonPublic | BindingFlags.Static)!.Invoke(null, new object?[] { new[] {Path.GetFullPath(args[1])}, null, target })!;
var program = loaded.GetType().GetProperty("Program")!.GetValue(loaded)!;
var compilerType = assembly.GetType("Sollang.Compiler.Semantics.SemanticCompiler", true)!;
var semantic = Activator.CreateInstance(compilerType, BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic, null, new object[] {program,64}, null)!;
var table = compilerType.GetField("_types", BindingFlags.NonPublic | BindingFlags.Instance)!.GetValue(semantic)!;
var id = assembly.GetType("Sollang.Compiler.Semantics.TypeId", true)!;
var parameter = Enum.Parse(id, "GenericParameter"); var integer = Enum.Parse(id,"Int");
object ArrayOf(object element) => table.GetType().GetMethod("GetOrAddDynamicArray")!.Invoke(table,new[] {element})!;
var arrayT = ArrayOf(parameter); var arrayInt = ArrayOf(integer); var nestedT = ArrayOf(arrayT);
var method = compilerType.GetMethods(BindingFlags.NonPublic | BindingFlags.Instance).Single(m => m.Name=="SubstituteGenericType" && m.GetParameters().Length==4);
var cases = new[] { ("identity",parameter,parameter,parameter), ("parameter-to-containing-array",parameter,arrayT,arrayT), ("nested-identity",arrayT,parameter,arrayT), ("nested-containing-replacement",arrayT,arrayT,nestedT), ("concrete-replacement",arrayT,integer,arrayInt), ("unrelated-type",integer,arrayT,integer) };
var rows = new List<object>();
foreach (var (name,input,replacement,expected) in cases) {
 var actual = method.Invoke(semantic,new object?[] {input,replacement,null,null})!;
 if (!actual.Equals(expected)) throw new Exception(name+": "+actual+" != "+expected);
 rows.Add(new {name, input=input.ToString(), replacement=replacement.ToString(), expected=expected.ToString(),actual=actual.ToString(),passed=true});
}
Console.WriteLine(JsonSerializer.Serialize(new {passed=rows.Count,total=rows.Count,rows}));
