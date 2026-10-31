using System.Globalization;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Shared;

namespace Sollang.Compiler.Cli;

// A finite Boolean decision is exported from the actual compiled C# method.
// Every possible input is enumerated; no independently maintained SLG rule exists.
internal static class SelfHostPolicyCompiler
{
    internal static void CheckGeneratedInputs(IReadOnlyList<string> sourcePaths)
    {
        var comparison = OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal;
        var roots = new HashSet<string>(OperatingSystem.IsWindows() ? StringComparer.OrdinalIgnoreCase : StringComparer.Ordinal);
        foreach (var type in typeof(SelfHostPolicyCompiler).Assembly.GetTypes())
        {
            if (type.GetCustomAttribute<SelfHostPolicyAttribute>() is not { } policy) continue;
            var suffix = Path.DirectorySeparatorChar + policy.Output.Replace('/', Path.DirectorySeparatorChar);
            foreach (var path in sourcePaths)
            {
                var full = Path.GetFullPath(path);
                if (full.EndsWith(suffix, comparison)) roots.Add(full[..^suffix.Length]);
            }
        }
        foreach (var root in roots) Synchronize(["--root", root, "--check"], verbose: false);
    }

    public static int Run(string[] args) => Synchronize(args, verbose: true);

    private static int Synchronize(string[] args, bool verbose)
    {
        var check = false;
        string? root = null;
        for (var index = 0; index < args.Length; index++)
        {
            if (args[index] == "--check") check = true;
            else if (args[index] == "--root" && ++index < args.Length) root = Path.GetFullPath(args[index]);
            else throw new SollangException("usage: selfhost-sync --root <repository> [--check]");
        }
        if (root is null) throw new SollangException("SELFHOST_POLICY_ROOT_REQUIRED");
        var assembly = typeof(SelfHostPolicyCompiler).Assembly;
        var outputs = new HashSet<string>(StringComparer.Ordinal);
        var policies = assembly.GetTypes().Select(type => (Type: type, Policy: type.GetCustomAttribute<SelfHostPolicyAttribute>()))
            .Where(item => item.Policy is not null).OrderBy(item => item.Policy!.Output, StringComparer.Ordinal).ToArray();
        var pending = new List<(string Path, string Content, string Source, string Hash)>();
        foreach (var (type, value) in policies)
        {
            var policy = value!;
            var output = WithinRoot(root, policy.Output);
            if (!policy.Output.StartsWith("selfhost/", StringComparison.Ordinal) || !policy.Output.EndsWith(".slg", StringComparison.Ordinal)
                || !outputs.Add(output) || !policy.Module.Split('.').All(Identifier))
                throw new SollangException("SELFHOST_POLICY_OUTPUT_INVALID");
            var source = WithinRoot(root, policy.Source);
            using var embedded = assembly.GetManifestResourceStream("Sollang.SharedPolicy." + Path.GetFileName(policy.Source))
                ?? throw new SollangException("SELFHOST_POLICY_SOURCE_RESOURCE_MISSING");
            using var reader = new StreamReader(embedded, Encoding.UTF8);
            var compiledSource = reader.ReadToEnd().ReplaceLineEndings("\n");
            var sourceHash = Hash(compiledSource);
            if (!File.Exists(source) || Hash(File.ReadAllText(source).ReplaceLineEndings("\n")) != sourceHash)
                throw new SollangException("SELFHOST_POLICY_SOURCE_DRIFT: rebuild the C# compiler before synchronizing");
            var text = new StringBuilder("# Generated from ").Append(policy.Source).Append("\n# source-sha256: ")
                .Append(sourceHash).Append("\nnamespace ").Append(policy.Module).Append('\n');
            var methods = type.GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static | BindingFlags.DeclaredOnly)
                .OrderBy(method => method.Name, StringComparer.Ordinal).ToArray();
            if (methods.Length == 0) throw new SollangException("SELFHOST_POLICY_EMPTY");
            foreach (var method in methods) text.Append('\n').Append(RenderDecision(method));
            var content = SourceFormatter.Format(text.ToString()).ReplaceLineEndings("\n");
            var same = File.Exists(output) && File.ReadAllText(output).ReplaceLineEndings("\n") == content;
            if (check && !same) throw new SollangException("SELFHOST_POLICY_OUTPUT_DRIFT: " + policy.Output);
            if (!check && !same) pending.Add((output, content, source, sourceHash));
        }
        foreach (var item in pending)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(item.Path)!);
            var temporary = item.Path + "." + Guid.NewGuid().ToString("N") + ".tmp";
            try
            {
                File.WriteAllText(temporary, item.Content, new UTF8Encoding(false));
                if (Hash(File.ReadAllText(item.Source).ReplaceLineEndings("\n")) != item.Hash)
                    throw new SollangException("SELFHOST_POLICY_SOURCE_CHANGED");
                File.Move(temporary, item.Path, overwrite: true);
            }
            finally { if (File.Exists(temporary)) File.Delete(temporary); }
        }
        if (verbose) Console.WriteLine($"[selfhost policies] {(check ? "checked" : "synchronized")} {policies.Length} module(s)");
        return 0;
    }

    internal static string RenderDecision(MethodInfo method)
    {
        var parameters = method.GetParameters();
        if (!method.IsStatic || method.IsGenericMethod || method.ReturnType != typeof(bool)
            || parameters.Length > 6 || parameters.Any(parameter => parameter.ParameterType != typeof(bool)
                || parameter.IsOptional || parameter.Name is null || !Identifier(parameter.Name)))
            throw new SollangException("SELFHOST_POLICY_BOOLEAN_SIGNATURE_REQUIRED: " + method.Name);
        if (!Identifier(method.Name)) throw new SollangException("SELFHOST_POLICY_NAME_INVALID");
        ulong mask = 0;
        for (var row = 0; row < 1 << parameters.Length; row++)
        {
            var values = Enumerable.Range(0, parameters.Length).Select(bit => (object)((row & (1 << bit)) != 0)).ToArray();
            var first = (bool)method.Invoke(null, values)!;
            if (first != (bool)method.Invoke(null, values)!)
                throw new SollangException("SELFHOST_POLICY_NONDETERMINISTIC: " + method.Name);
            if (first) mask |= 1UL << row;
        }
        var name = char.ToLowerInvariant(method.Name[0]) + method.Name[1..];
        var result = new StringBuilder("public ").Append(name);
        if (parameters.Length == 0) result.Append(':');
        else result.Append(' ').Append(string.Join(", ", parameters.Select(parameter => parameter.Name + ": Bool")));
        result.Append(" -> Bool {\n    UInt64(").Append(mask.ToString(CultureInfo.InvariantCulture)).Append(") => decision!\n");
        for (var bit = 0; bit < parameters.Length; bit++)
            result.Append("    ").Append(parameters[bit].Name).Append(" -> if { decision! / ")
                .Append((1UL << (1 << bit)).ToString(CultureInfo.InvariantCulture)).Append(" => decision! }\n");
        return result.Append("    decision! % 2 == 1\n}\n").ToString();
    }

    private static bool Identifier(string value) => value.Length > 0 && char.IsAsciiLetter(value[0])
        && value.All(character => char.IsAsciiLetterOrDigit(character) || character == '_');

    private static string WithinRoot(string root, string relative)
    {
        var full = Path.GetFullPath(Path.Combine(root, relative));
        var prefix = Path.TrimEndingDirectorySeparator(root) + Path.DirectorySeparatorChar;
        if (Path.IsPathRooted(relative) || !full.StartsWith(prefix,
                OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal))
            throw new SollangException("SELFHOST_POLICY_PATH_ESCAPE");
        return full;
    }

    private static string Hash(string value) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value)));
}
