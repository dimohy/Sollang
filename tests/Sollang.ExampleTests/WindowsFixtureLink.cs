using System.Runtime.Loader;
using System.Text;

internal sealed record WindowsFixtureLink(string Clang, string Librarian, string[] CompilerArguments,
    string[] LinkerArguments, (string Name, string Definition)[] Libraries)
{
    internal static WindowsFixtureLink? Create(IReadOnlyList<string> productionLink, string llvm,
        IReadOnlyList<string> explicitArguments)
    {
        // These flags request an import library even when the LLVM contains
        // no matching declaration. Keep them in the final clang invocation.
        if (explicitArguments.Any(argument => !argument.StartsWith("-l", StringComparison.Ordinal)))
            return null;

        var context = new AssemblyLoadContext("Sollang Windows fixture policy", isCollectible: true);
        try
        {
            var policy = context.LoadFromAssemblyPath(productionLink[2])
                .GetType("Sollang.Compiler.Shared.WindowsLinkPolicy", throwOnError: true)!;
            string Read(string method) =>
                policy.GetMethod(method)?.Invoke(null, null) as string
                ?? throw new InvalidOperationException("WINDOWS_FIXTURE_LINK_POLICY_MISSING: " + method);

            var rows = Read("ImportLibraries").Split('|').Select(row => row.Split(';')).ToArray();
            var requested = explicitArguments.Select(argument => argument[2..]).ToHashSet(StringComparer.Ordinal);
            if (!requested.IsSubsetOf(rows.Select(row => row[0])))
                return null;

            var bytes = Encoding.UTF8.GetBytes(llvm);
            var prefix = bytes.AsSpan(0, Math.Min(bytes.Length, 1024 * 1024));
            var libraries = new List<(string Name, string Definition)>();
            foreach (var row in rows)
            {
                if (row[2].Length == 0 || requested.Contains(row[0])
                    || prefix.IndexOf(Encoding.ASCII.GetBytes(row[2])) >= 0)
                    libraries.Add((row[0], "LIBRARY " + row[1] + "\nEXPORTS\n" + row[3].Replace(',', '\n')));
            }

            var bin = Path.Combine(productionLink[4], "bin");
            var objectArguments = Read("ObjectArguments").Split(';')
                .Select(argument => argument == ":optimization:" ? "-O0" : argument).ToArray();
            var linkerArguments = (Read("LinkArguments") + ";" + Read("ExecutableArguments"))
                .Split(';').SelectMany(argument => new[] { "-Xlinker", argument }).ToArray();
            return new WindowsFixtureLink(Path.Combine(bin, "clang.exe"), Path.Combine(bin, "llvm-lib.exe"),
                objectArguments, linkerArguments, libraries.ToArray());
        }
        finally
        {
            context.Unload();
        }
    }
}
