using System.Collections;
using System.Reflection;
using System.Text;
static class LocatorProbe {
 static object Get(object value,string name) => value.GetType().GetProperty(name,BindingFlags.Public|BindingFlags.Instance)!.GetValue(value)!;
 static object Invoke(MethodInfo method,object? value,object?[] arguments) {
  try { return method.Invoke(value,arguments)!; }
  catch(TargetInvocationException error) when(error.InnerException is not null) { System.Runtime.ExceptionServices.ExceptionDispatchInfo.Capture(error.InnerException).Throw(); throw; }
 }

 static bool Walk(object? value,Dictionary<object,bool> memo,HashSet<string> coverage) {
  if(value is null || value is string) return false;
  if(memo.TryGetValue(value,out var known)) return known;
  memo[value]=false;var contains=false;
  if(value is IEnumerable values) {
   foreach(var child in values) contains=Walk(child,memo,coverage)||contains;
   memo[value]=contains;return contains;
  }
  var type=value.GetType();if(type.Namespace!="Sollang.Compiler.Syntax") return false;
  if(type.Name=="FlowExpression") {
   foreach(var target in (IEnumerable)Get(value,"Targets")) {
    var path=((IEnumerable)Get(target,"Path")).Cast<object>().Select(x=>x.ToString()).ToArray();
    if(path.Length==1 && path[0]=="await" && !((IEnumerable)Get(target,"Arguments")).Cast<object>().Any()) contains=true;
   }
  }
  if(type.Name=="ExpressionStatement") {
   var expression=Get(value,"Expression");
   if(expression.GetType().Name=="NameExpression" && (string)Get(expression,"Name")=="yield") contains=true;
  }
  foreach(var property in type.GetProperties(BindingFlags.Instance|BindingFlags.Public))
   if(property.GetIndexParameters().Length==0) contains=Walk(property.GetValue(value),memo,coverage)||contains;
  memo[value]=contains;
  if(contains && (type.Name.EndsWith("Expression",StringComparison.Ordinal)||type.Name.EndsWith("Statement",StringComparison.Ordinal))) coverage.Add(type.Name);
  return contains;
 }

 static int Main(string[] args) {
  if(args.Length is not (3 or 4)) throw new ArgumentException("compiler DLL, source file and declared namespace prefix required");
  var prefix=args[2]+".";
  var assembly=Assembly.LoadFrom(Path.GetFullPath(args[0]));
  var app=assembly.GetType("Sollang.Compiler.Cli.CompilerApp",true)!;
  var target=Enum.Parse(assembly.GetType("Sollang.Compiler.CompilationTarget",true)!,"WindowsX64");
  var loaded=Invoke(app.GetMethod("LoadProgram",BindingFlags.Static|BindingFlags.NonPublic)!,null,[new[]{Path.GetFullPath(args[1])},null,target]);
  var semanticType=assembly.GetType("Sollang.Compiler.Semantics.SemanticCompiler",true)!;
  var semantic=Activator.CreateInstance(semanticType,BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic,null,[Get(loaded,"Program"),64],null)!;
  var bound=Invoke(semanticType.GetMethod("Compile",BindingFlags.Public|BindingFlags.Instance)!,semantic,[null]);
  var warnings=((IEnumerable)Get(bound,"Warnings")).Cast<object>().ToArray();
  if(warnings.Length!=0) throw new InvalidOperationException(string.Join("\n",warnings.Select(x=>x.ToString())));

  if(args.Length==4) {
   foreach(var item in ((IEnumerable)Get(bound,"Functions")).Cast<object>()) {
    var function=Get(item,"Value");var full=(string)Get(function,"Name");
    if(!full.StartsWith(prefix,StringComparison.Ordinal) || !(bool)Get(function,"IsAsync")) continue;
    var coverage=new HashSet<string>(StringComparer.Ordinal);var memo=new Dictionary<object,bool>(ReferenceEqualityComparer.Instance);
    Walk(Get(function,"BlockBody"),memo,coverage);Walk(Get(function,"Body"),memo,coverage);
    foreach(var type in coverage.Order(StringComparer.Ordinal)) Console.WriteLine($"visit|{full[prefix.Length..]}|{type}");
   }
   return 0;
  }
  var entries=((IEnumerable)Get(bound,"AsyncSuspensionLocations")).Cast<object>().Select(x=>Get(x,"Value")).ToArray();
  entries=entries.Where(x=>((string)Get(Get(x,"Function"),"Name")).StartsWith(prefix,StringComparison.Ordinal)).ToArray();
  var bytes=File.ReadAllBytes(args[1]);var counters=new Dictionary<object,int>(ReferenceEqualityComparer.Instance);
  foreach(var location in entries.OrderBy(x=>(string)Get(Get(x,"Function"),"Name"),StringComparer.Ordinal).ThenBy(x=>(int)Get(x,"ByteOffset"))) {
   var function=Get(location,"Function");var name=((string)Get(function,"Name"))[prefix.Length..];var offset=(int)Get(location,"ByteOffset");
   var token=Encoding.UTF8.GetString(bytes.AsSpan(offset,5));
   if(token!="yield" && token!="await") throw new InvalidOperationException("Source token does not identify a suspension site.");
   counters.TryGetValue(function,out var state);counters[function]=++state;
   Console.WriteLine($"point|{name}|{state}|{(token=="yield"?1:0)}|{offset}|{Get(location,"Line")}|{Get(location,"Column")}");
  }
  return 0;
 }
}
