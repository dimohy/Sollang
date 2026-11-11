using System;
using System.IO;
using System.Reflection;
using System.Text.Json;

try
{
    var assembly = Assembly.LoadFrom(args[0]);
    var type = assembly.GetType("Sollang.Compiler.Cli.NativeOutputTransaction", throwOnError: true)!;
    var transaction = (IDisposable)Activator.CreateInstance(type, [Path.Combine(args[1], "output.exe")])!;
    try
    {
        Console.WriteLine(JsonSerializer.Serialize(new
        {
            llvmStage = (string)type.GetProperty("LlvmStagePath")!.GetValue(transaction)!,
            executableStage = (string)type.GetProperty("ExecutableStagePath")!.GetValue(transaction)!,
            workDirectory = (string)type.GetProperty("WorkDirectory")!.GetValue(transaction)!
        }));
    }
    finally
    {
        // Intentionally unpublished: verify that diagnostic stages survive disposal.
        transaction.Dispose();
    }
    return 0;
}
catch (Exception error)
{
    while (error is TargetInvocationException { InnerException: { } inner }) error = inner;
    Console.Error.WriteLine(error.GetType().Name + ": " + error.Message);
    return 1;
}
