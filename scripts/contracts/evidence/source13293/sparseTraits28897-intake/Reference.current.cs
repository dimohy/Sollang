using System.Collections;
using System.Reflection;
using System.Text.Json;
var assembly = Assembly.LoadFrom(Path.GetFullPath(args[0]));
var tableType = assembly.GetType("Sollang.Compiler.Semantics.TypeDefinitionTable", true)!;
var idType = assembly.GetType("Sollang.Compiler.Semantics.TypeId", true)!;
object Id(int value) => Enum.ToObject(idType, value);
object Builtin(string name) => Enum.Parse(idType, name);
var first = Convert.ToInt32(Builtin("FirstUserDefined"));
object Table() { var ctor = tableType.GetConstructors().Single(); return ctor.Invoke(ctor.GetParameters().Select(p => p.HasDefaultValue ? p.DefaultValue : p.ParameterType == typeof(int) ? (object)8 : Activator.CreateInstance(typeof(Dictionary<,>).MakeGenericType(p.ParameterType.GetGenericArguments()))).ToArray()); }
object Call(object table, string name, params object?[] values) => tableType.GetMethod(name)!.Invoke(table, values)!;
void Bounded(object table, object id, object child) { var method = tableType.GetMethod("RegisterBoundedArrays")!; var shapeType = method.GetParameters()[0].ParameterType.GetGenericArguments()[1]; var shapes = (IDictionary)Activator.CreateInstance(typeof(Dictionary<,>).MakeGenericType(idType,shapeType))!; shapes.Add(id,Activator.CreateInstance(shapeType,child,4)!); method.Invoke(table,[shapes]); }
var rows = new List<object>();
foreach (var kind in new[]{"fixed", "dynamic", "scalar", "reference", "nested"}) {
 var table=Table(); var high=Id(first+100); var low=Id(first+10); object child;
 if(kind=="fixed") { if(!(bool)Call(table,"TryReserveStaticArray",high,Builtin("Int"),4)) throw new Exception("reservation rejected"); child=Call(table,"GetOrAddFixedStaticArray",Builtin("Int"),4); if(!child.Equals(high)) throw new Exception("reserved child drift"); }
 else if(kind=="dynamic") { Call(table,"RegisterDynamicArray",high,Builtin("Int")); child=high; }
 else if(kind=="reference") child=Call(table,"GetOrAddReference",Builtin("Int"));
 else if(kind=="nested") { Call(table,"RegisterDynamicArray",high,Builtin("Int")); child=Id(first+90); Bounded(table,child,high); }
 else child=Builtin("Int");
 Bounded(table,low,child);
 var actual=(bool)Call(table,"ContainsOwnedStorage",low); var expected=kind is "fixed" or "dynamic" or "nested";
 if(actual!=expected)throw new Exception(kind+" ownership mismatch");
 rows.Add(new{kind,parent=Convert.ToInt32(low),child=Convert.ToInt32(child),expected,actual});
}
Console.WriteLine(JsonSerializer.Serialize(rows));
