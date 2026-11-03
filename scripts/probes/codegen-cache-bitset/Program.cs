using System.Reflection;
using System.Text.Json;

var assembly = Assembly.LoadFrom(args[0]);
var tableType = assembly.GetType("Sollang.Compiler.Semantics.TypeDefinitionTable", true)!;
var constructor = tableType.GetConstructors(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance).Single();
var inputs = constructor.GetParameters().Select(parameter => parameter.HasDefaultValue ? parameter.DefaultValue
    : parameter.ParameterType == typeof(int) ? 8
    : Activator.CreateInstance(typeof(Dictionary<,>).MakeGenericType(parameter.ParameterType.GetGenericArguments()))).ToArray();
var table = constructor.Invoke(inputs);
var cache = assembly.GetType("Sollang.Compiler.Cli.IncrementalCodegenCache", true)!;
var hash = cache.GetMethod("BuildTypeUniverseHash", BindingFlags.NonPublic | BindingFlags.Static)!;
var add = tableType.GetMethod("GetOrAddBitSet")!;
var baseline = (ulong)hash.Invoke(null, [table])!;
if (args.Length > 1 && args[1] == "registration")
{
    var reference = tableType.GetMethod("GetOrAddReference")!;
    var first = add.Invoke(table, [130])!;
    var origin = Convert.ToInt32(first);
    var sequence = new[] { first, reference.Invoke(table, [first])!, add.Invoke(table, [130])!,
        add.Invoke(table, [int.MaxValue])!, add.Invoke(table, [int.MaxValue])!, add.Invoke(table, [64])! };
    for (var index = 0; index < sequence.Length; index++)
        Console.WriteLine(JsonSerializer.Serialize(new { kind = "identity", ordinal = index,
            identity = Convert.ToInt32(sequence[index]), relative = Convert.ToInt32(sequence[index]) - origin }));
    foreach (var bitCount in new[] { 0, -1 })
    {
        try
        {
            add.Invoke(table, [bitCount]);
            throw new InvalidOperationException("Invalid BitSet size was accepted");
        }
        catch (TargetInvocationException error) when (error.InnerException is ArgumentOutOfRangeException argument
            && argument.ParamName == "bitCount")
        {
            Console.WriteLine(JsonSerializer.Serialize(new { kind = "invalid", bitCount, rejected = true }));
        }
    }
    return;
}
foreach (var bitCount in new[] { 1, 64, 65, 130, int.MaxValue })
{
    add.Invoke(table, [bitCount]);
    var observed = (ulong)hash.Invoke(null, [table])!;
    if (observed != baseline)
        throw new InvalidOperationException("BitSet unexpectedly contributes a standalone type-universe record");
    Console.WriteLine(JsonSerializer.Serialize(new { bitCount, baseline = baseline.ToString("x16"),
        observed = observed.ToString("x16"), standaloneRecord = false }));
}
