using System.Reflection;
using System.Text.Json;

var assembly = Assembly.LoadFrom(args[0]);
var tableType = assembly.GetType("Sollang.Compiler.Semantics.TypeDefinitionTable", true)!;
var constructor = tableType.GetConstructors(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance).Single();
var parameters = constructor.GetParameters();
var inputs = parameters.Select(parameter => parameter.HasDefaultValue ? parameter.DefaultValue
    : parameter.ParameterType == typeof(int) ? 8
    : Activator.CreateInstance(typeof(Dictionary<,>).MakeGenericType(parameter.ParameterType.GetGenericArguments()))).ToArray();
var table = constructor.Invoke(inputs);
var add = tableType.GetMethod("GetOrAddBoundedArray")!;
var typeId = add.GetParameters()[0].ParameterType;
var integer = Enum.Parse(typeId, "Int");
var get = tableType.GetMethod("GetBoundedArray")!;
foreach (var capacity in new[] { 1, 536870907, 536870908, 536870909, 536870910, 536870912, int.MaxValue })
{
    try
    {
        var id = add.Invoke(table, [integer, capacity]);
        var definition = get.Invoke(table, [id])!;
        var size = (int)definition.GetType().GetProperty("Size")!.GetValue(definition)!;
        Console.WriteLine(JsonSerializer.Serialize(new { capacity, status = "known", size }));
    }
    catch (TargetInvocationException error) when (
        error.InnerException?.GetType().FullName == "Sollang.Compiler.Diagnostics.SollangException"
        && error.InnerException.Message == "bounded array storage layout exceeds the Int32 size limit")
    {
        Console.WriteLine(JsonSerializer.Serialize(new { capacity, status = "overflow" }));
    }
}
