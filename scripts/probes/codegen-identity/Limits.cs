using System.Reflection;
using System.Text.Json;

if (args.Length is not (2 or 3)
    || args.Length == 3 && args[2] != "declared-lengths")
    throw new ArgumentException("compiler assembly, artifact directory, and optional declared-lengths mode required");
var assembly = Assembly.LoadFrom(Path.GetFullPath(args[0]));
var directory = Path.GetFullPath(args[1]);
Directory.CreateDirectory(directory);
var unitType = assembly.GetType("Sollang.Compiler.CodeGen.LlvmCodegenUnit", true)!;
var keyType = assembly.GetType("Sollang.Compiler.CodeGen.LlvmCodegenKey", true)!;
var kindType = assembly.GetType("Sollang.Compiler.CodeGen.LlvmCodegenUnitKind", true)!;
var outputType = assembly.GetType("Sollang.Compiler.CodeGen.LlvmCodegenOutput", true)!;
var cacheType = assembly.GetType("Sollang.Compiler.Cli.IncrementalCodegenCache", true)!;
var encode = cacheType.GetMethod("Encode", BindingFlags.NonPublic | BindingFlags.Static)!;
var read = cacheType.GetMethod("Read", BindingFlags.NonPublic | BindingFlags.Static)!;

if (args.Length == 3)
{
    var checkedLength = cacheType.GetMethod("CheckedLength", BindingFlags.NonPublic | BindingFlags.Static)!;
    var identityMaximum = Convert.ToInt64(cacheType.GetField("MaximumIdentityBytes", BindingFlags.NonPublic | BindingFlags.Static)!.GetRawConstantValue());
    var fragmentMaximum = Convert.ToInt64(cacheType.GetField("MaximumFragmentBytes", BindingFlags.NonPublic | BindingFlags.Static)!.GetRawConstantValue());
    foreach (var (description, maximum) in new[]
    {
        ("identity", identityMaximum),
        ("fragment", fragmentMaximum),
        ("fragment words", (long)int.MaxValue)
    })
    {
        foreach (var value in new[] { 0UL, (ulong)maximum - 1, (ulong)maximum, (ulong)maximum + 1, ulong.MaxValue })
        {
            var accepted = true;
            int? result = null;
            string? diagnostic = null;
            try
            {
                result = (int)checkedLength.Invoke(null, [value, maximum, description])!;
            }
            catch (TargetInvocationException error) when (error.InnerException is InvalidDataException)
            {
                accepted = false;
                diagnostic = error.InnerException.Message;
            }
            Console.WriteLine(JsonSerializer.Serialize(new { description, maximum, value, accepted, result, diagnostic }));
        }
    }
    return;
}

foreach (var length in new[] { 0, 1, 1048576, 1048577 })
{
    var units = Array.CreateInstance(unitType, 3);
    for (var index = 0; index < units.Length; index++)
    {
        var key = Activator.CreateInstance(keyType, [101UL, 202UL])!;
        var identity = index == 1 ? new string('x', length) : "";
        units.SetValue(Activator.CreateInstance(unitType,
            [Enum.ToObject(kindType, index), identity, key, "", false]), index);
    }
    var output = Activator.CreateInstance(outputType, [units])!;
    var words = (IReadOnlyList<ulong>)encode.Invoke(null, [output, 101UL, 202UL, 303UL])!;
    var path = Path.Combine(directory, $"identity-{length}.cgu");
    using (var stream = File.Create(path))
    using (var writer = new BinaryWriter(stream))
        foreach (var word in words) writer.Write(word);
    var accepted = true;
    string? diagnostic = null;
    try
    {
        read.Invoke(null, [path, 101UL, 202UL, 303UL]);
    }
    catch (TargetInvocationException error) when (error.InnerException is InvalidDataException)
    {
        accepted = false;
        diagnostic = error.InnerException.Message;
    }
    Console.WriteLine(JsonSerializer.Serialize(new { length, accepted, diagnostic }));
}
