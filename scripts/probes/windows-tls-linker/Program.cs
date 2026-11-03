using System.Reflection;

var assembly = Assembly.LoadFrom(args[0]);
var toolchainType = assembly.GetType("Sollang.Compiler.Tooling.LlvmToolchain", true)!;
var toolchain = toolchainType.GetMethod("From")!.Invoke(null, [args[1]])!;
var linkerType = assembly.GetType("Sollang.Compiler.Tooling.WindowsLinker", true)!;
var constructor = linkerType.GetConstructors(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance).Single();
var linker = constructor.Invoke([toolchain]);
linkerType.GetProperty("MaximumWorkers")!.SetValue(linker, 4);
Directory.CreateDirectory(args[4]);
try
{
    linkerType.GetMethod("LinkLlvmIr")!.Invoke(linker, [args[2], args[3], args[4], "-O0", false]);
    return 0;
}
catch (TargetInvocationException error) when (error.InnerException is not null)
{
    Console.Error.WriteLine(error.InnerException.Message);
    return 1;
}
