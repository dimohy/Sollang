using System.Reflection;

var compiler = Assembly.LoadFrom(args[0]);
var type = compiler.GetType("Sollang.Compiler.Tooling.WindowsLinker", throwOnError: true)!;
var method = type.GetMethod("UsesComInterop", BindingFlags.NonPublic | BindingFlags.Static)!;
try
{
    Console.WriteLine((bool)method.Invoke(null, [args[1]])! ? "true" : "false");
}
catch (TargetInvocationException error) when (error.InnerException is IOException or UnauthorizedAccessException)
{
    Console.WriteLine("error");
}
