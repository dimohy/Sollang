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
if (args.Length > 1 && args[1] == "dictionary")
{
    var dictionaryAdd = tableType.GetMethod("GetOrAddBoundedDictionary")!;
    var dictionaryGet = tableType.GetMethod("GetBoundedDictionary")!;
    var register = tableType.GetMethod("RegisterBoundedDictionaries")!;
    var dictionaryTypeId = dictionaryAdd.GetParameters()[0].ParameterType;
    var dictionaryInteger = Enum.Parse(dictionaryTypeId, "Int");
    var definitionMapType = typeof(Dictionary<,>).MakeGenericType(dictionaryTypeId,
        typeof(ValueTuple<,,>).MakeGenericType(dictionaryTypeId, dictionaryTypeId, typeof(int)));
    foreach (var restored in new[] { false, true })
    foreach (var capacity in new[] { 1, 14, 15, 117440512, 117440513, 939524097, 1879048192, int.MaxValue })
    {
        var currentTable = constructor.Invoke(inputs);
        try
        {
            object id;
            if (restored)
            {
                id = Enum.ToObject(dictionaryTypeId, 1000000);
                var definitions = (System.Collections.IDictionary)Activator.CreateInstance(definitionMapType)!;
                definitions.Add(id, Activator.CreateInstance(definitionMapType.GetGenericArguments()[1],
                    dictionaryInteger, dictionaryInteger, capacity)!);
                register.Invoke(currentTable, [definitions]);
            }
            else
            {
                id = dictionaryAdd.Invoke(currentTable, [dictionaryInteger, dictionaryInteger, capacity])!;
            }
            var definition = dictionaryGet.Invoke(currentTable, [id])!;
            var size = (int)definition.GetType().GetProperty("Size")!.GetValue(definition)!;
            var buckets = (int)definition.GetType().GetProperty("BucketCapacity")!.GetValue(definition)!;
            Console.WriteLine(JsonSerializer.Serialize(new { restored, capacity, status = "known", size, buckets }));
        }
        catch (TargetInvocationException error) when (
            error.InnerException?.GetType().FullName == "Sollang.Compiler.Diagnostics.SollangException"
            && error.InnerException.Message == "bounded dictionary storage layout exceeds the Int32 size limit")
        {
            Console.WriteLine(JsonSerializer.Serialize(new { restored, capacity, status = "overflow" }));
        }
    }
    return;
}
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
