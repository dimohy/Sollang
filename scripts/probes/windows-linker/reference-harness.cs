using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text.Json;

try
{
    var importsOnly = args.Length == 5 && args[1] == "--imports";
    var assembly = Assembly.LoadFrom(args[0]);
    var toolchainType = assembly.GetType("Sollang.Compiler.Tooling.LlvmToolchain", throwOnError: true)!;
    var linkerType = assembly.GetType("Sollang.Compiler.Tooling.WindowsLinker", throwOnError: true)!;
    var toolchain = toolchainType.GetMethod("From", BindingFlags.Public | BindingFlags.Static)!.Invoke(null, [args[importsOnly ? 2 : 1]]);
    var linker = Activator.CreateInstance(linkerType, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance,
        binder: null, args: [toolchain], culture: null)!;
    if (importsOnly)
    {
        Directory.CreateDirectory(args[4]);
        linkerType.GetMethod("CreateImportLibraries", BindingFlags.NonPublic | BindingFlags.Instance)!
            .Invoke(linker, [args[3], args[4]]);
        Console.WriteLine(JsonSerializer.Serialize(new { definitions = Definitions(args[4]) }));
        return 0;
    }
    int? maximumWorkers = args[6] == "none" ? null : int.Parse(args[6]);
    linkerType.GetProperty("MaximumWorkers")!.SetValue(linker, maximumWorkers);
    if (args[8] != "inherit") Environment.SetEnvironmentVariable("SOLLANG_NATIVE_JOBS", args[8]);
    var processors = Math.Max(1, Environment.ProcessorCount);
    var workers = (int)linkerType.GetMethod("NativeJobLimit", BindingFlags.NonPublic | BindingFlags.Instance)!
        .Invoke(linker, [processors])!;
    Directory.CreateDirectory(args[4]);
    linkerType.GetMethod("LinkLlvmIr")!.Invoke(linker, [args[2], args[3], args[4], args[5], args[7] == "true"]);
    var definitions = Definitions(args[4]);
    Console.WriteLine(JsonSerializer.Serialize(new
    {
        processors, workers, maximumWorkers,
        objects = Directory.GetFiles(args[4], "*.obj").Order(StringComparer.Ordinal).ToArray(),
        definitions
    }));
    return 0;
}

catch (Exception error)
{
    while (error is TargetInvocationException { InnerException: { } inner }) error = inner;
    Console.Error.WriteLine("sollang: " + error.Message);
    return 1;
}

static System.Collections.Generic.Dictionary<string, string> Definitions(string directory) =>
    Directory.GetFiles(directory, "*.def").Order(StringComparer.Ordinal)
        .ToDictionary(path => Path.GetFileName(path)!, path => File.ReadAllText(path).ReplaceLineEndings("\n"));
