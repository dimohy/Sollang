using System.Reflection;

namespace Sollang.Compiler.Cli;

internal static class CompilerVersion
{
    public static string Current { get; } =
        typeof(CompilerVersion).Assembly
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()
            ?.InformationalVersion
            .Split('+', 2)[0]
        ?? throw new InvalidOperationException("compiler version metadata is missing");
}
