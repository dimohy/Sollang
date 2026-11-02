using System;
using System.IO;
using System.Reflection;
using System.Text.Json;

var assembly = Assembly.LoadFrom(args[0]);
var type = assembly.GetType("Sollang.Compiler.Tooling.WindowsLinker", throwOnError: true)!;
var toolchainType = assembly.GetType("Sollang.Compiler.Tooling.LlvmToolchain", throwOnError: true)!;
var tools = toolchainType.GetMethod("From", BindingFlags.Public | BindingFlags.Static)!.Invoke(null, [args[1]]);
using var document = JsonDocument.Parse(File.ReadAllText(args[2]));
foreach (var test in document.RootElement.GetProperty("cases").EnumerateArray())
{
    var linker = Activator.CreateInstance(type, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance,
        binder: null, args: [tools], culture: null)!;
    int? maximum = test.TryGetProperty("maximum", out var explicitValue) ? explicitValue.GetInt32() : null;
    type.GetProperty("MaximumWorkers")!.SetValue(linker, maximum);
    Environment.SetEnvironmentVariable("SOLLANG_NATIVE_JOBS", test.GetProperty("environment").GetString());
    try
    {
        var count = (int)type.GetMethod("NativeJobLimit", BindingFlags.NonPublic | BindingFlags.Instance)!
            .Invoke(linker, [test.GetProperty("processors").GetInt32()])!;
        Console.WriteLine(JsonSerializer.Serialize(new { id = test.GetProperty("id").GetString(), workers = count }));
    }
    catch (TargetInvocationException error)
    {
        Console.WriteLine(JsonSerializer.Serialize(new { id = test.GetProperty("id").GetString(), error = error.InnerException!.Message }));
    }
}
