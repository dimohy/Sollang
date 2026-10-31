using System.Globalization;
using System.Buffers.Binary;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Shared;

namespace Sollang.Compiler.Cli;

// Boolean decisions enumerate every input. UInt64 arithmetic is lowered from
// the actual compiled method's straight-line IL, with unsupported IL rejected.
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
            if (methods.Any(method => method.ReturnType == typeof(CodegenKeyRule)))
                text.Append(RenderKeyRuleTypes());
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
        if (method.ReturnType == typeof(CodegenKeyRule)) return RenderKeyRuleDecision(method);
        if (method.ReturnType == typeof(string)) return RenderTextConstant(method);
        if (method.ReturnType == typeof(ulong)) return RenderArithmetic(method);
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

    private static string RenderTextConstant(MethodInfo method)
    {
        if (!method.IsStatic || method.IsGenericMethod || method.GetParameters().Length != 0 || !Identifier(method.Name))
            throw new SollangException("SELFHOST_POLICY_TEXT_SIGNATURE_REQUIRED: " + method.Name);
        var body = method.GetMethodBody();
        var code = body?.GetILAsByteArray();
        if (body is null || code is null || code.Length != 6 || code[0] != 0x72 || code[5] != 0x2A
            || body.LocalVariables.Count != 0 || body.ExceptionHandlingClauses.Count != 0)
            throw new SollangException("SELFHOST_POLICY_TEXT_CONSTANT_REQUIRED: " + method.Name);
        var text = method.Module.ResolveString(BinaryPrimitives.ReadInt32LittleEndian(code.AsSpan(1, 4)));
        if (text.Length > 4096 || text.Any(character => character < 32 || character > 126))
            throw new SollangException("SELFHOST_POLICY_TEXT_LITERAL_UNSUPPORTED: " + method.Name);
        var name = char.ToLowerInvariant(method.Name[0]) + method.Name[1..];
        return "public " + name + ": -> Text {\n    \"" + text.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"\n}\n";
    }

    private static string RenderArithmetic(MethodInfo method)
    {
        var parameters = method.GetParameters();
        if (!method.IsStatic || method.IsGenericMethod || !Identifier(method.Name)
            || parameters.Length > 6 || parameters.Any(parameter => parameter.ParameterType != typeof(ulong)
                || parameter.IsOptional || parameter.Name is null || !Identifier(parameter.Name)))
            throw new SollangException("SELFHOST_POLICY_UINT64_SIGNATURE_REQUIRED: " + method.Name);
        var body = method.GetMethodBody();
        var code = body?.GetILAsByteArray();
        if (body is null || code is null || code.Length > 1024
            || body.LocalVariables.Count != 0 || body.ExceptionHandlingClauses.Count != 0)
            throw new SollangException("SELFHOST_POLICY_UINT64_BODY_UNSUPPORTED: " + method.Name);
        var stack = new List<string>();
        var cursor = 0;
        SollangException Invalid() => new("SELFHOST_POLICY_UINT64_IL_UNSUPPORTED: " + method.Name
            + " at " + cursor.ToString(CultureInfo.InvariantCulture));
        void Literal(ulong value) => stack.Add(value.ToString(CultureInfo.InvariantCulture));
        while (cursor < code.Length)
        {
            var op = code[cursor++];
            if (op == 0x00) continue; // nop
            if (op is >= 0x02 and <= 0x05 || op == 0x0E) // ldarg.0..3 / ldarg.s
            {
                var index = op == 0x0E ? cursor < code.Length ? code[cursor++] : -1 : op - 0x02;
                if (index < 0 || index >= parameters.Length) throw Invalid();
                stack.Add(parameters[index].Name!);
            }
            else if (op == 0x21) // ldc.i8: preserve all 64 bits, including high-bit literals
            {
                if (code.Length - cursor < 8) throw Invalid();
                Literal(BinaryPrimitives.ReadUInt64LittleEndian(code.AsSpan(cursor, 8)));
                cursor += 8;
            }
            else if (op is >= 0x15 and <= 0x20) // ldc.i4 followed by an explicit widening
            {
                int value;
                if (op <= 0x1E) value = op - 0x16;
                else if (op == 0x1F)
                {
                    if (cursor == code.Length) throw Invalid();
                    value = unchecked((sbyte)code[cursor++]);
                }
                else
                {
                    if (code.Length - cursor < 4) throw Invalid();
                    value = BinaryPrimitives.ReadInt32LittleEndian(code.AsSpan(cursor, 4));
                    cursor += 4;
                }
                if (cursor == code.Length) throw Invalid();
                var conversion = code[cursor++];
                if (conversion is not (0x6A or 0x6E)) throw Invalid(); // conv.i8 / conv.u8
                if (conversion == 0x6E && value < 0) throw Invalid();
                Literal(conversion == 0x6A ? unchecked((ulong)(long)value) : unchecked((uint)value));
            }
            else if (op is 0x58 or 0x59 or 0x5A) // unchecked add / sub / mul
            {
                if (stack.Count < 2) throw Invalid();
                var right = stack[^1]; var left = stack[^2];
                stack.RemoveRange(stack.Count - 2, 2);
                stack.Add("(" + left + (op == 0x58 ? " + " : op == 0x59 ? " - " : " * ") + right + ")");
            }
            else if (op == 0x2A) // ret; no hidden work may follow it
            {
                if (cursor != code.Length || stack.Count != 1) throw Invalid();
                var name = char.ToLowerInvariant(method.Name[0]) + method.Name[1..];
                var inputs = parameters.Length == 0 ? ":" : " " + string.Join(", ",
                    parameters.Select(parameter => parameter.Name + ": UInt64"));
                return "public " + name + inputs + " -> UInt64 {\n    " + stack[0] + "\n}\n";
            }
            else throw Invalid();
        }
        throw Invalid();
    }

    private static string RenderKeyRuleTypes()
    {
        var parts = Enum.GetValues<CodegenKeyPart>();
        if (parts.Where((part, index) => (int)part != index).Any()
            || Enum.GetNames<CodegenKeyPart>().Any(name => !Identifier(name)))
            throw new SollangException("SELFHOST_POLICY_KEY_PART_ENUM_INVALID");
        return "\npublic enum KeyPart { " + string.Join(", ", parts) + " }\n"
            + "\npublic struct KeyRule {\n    public domain: Text\n    public parts: [KeyPart; ~]\n}\n"
            + "\npublic partIndex part: KeyPart -> Int {\n    part -> when {\n"
            + string.Concat(parts.Select(part => "        " + part + " { "
                + ((int)part).ToString(CultureInfo.InvariantCulture) + " }\n"))
            + "    }\n}\n";
    }

    private static string RenderKeyRuleDecision(MethodInfo method)
    {
        if (!method.IsStatic || method.IsGenericMethod || method.GetParameters().Length != 0)
            throw new SollangException("SELFHOST_POLICY_KEY_RULE_SIGNATURE_REQUIRED: " + method.Name);
        var rule = (CodegenKeyRule)method.Invoke(null, null)!;
        var repeated = (CodegenKeyRule)method.Invoke(null, null)!;
        if (rule.Domain != repeated.Domain || rule.Parts is null || repeated.Parts is null
            || !rule.Parts.SequenceEqual(repeated.Parts))
            throw new SollangException("SELFHOST_POLICY_NONDETERMINISTIC: " + method.Name);
        return RenderKeyRule(method.Name, rule);
    }

    internal static string RenderKeyRule(string name, CodegenKeyRule rule)
    {
        if (!Identifier(name) || string.IsNullOrEmpty(rule.Domain) || rule.Domain.Length > 128
            || !char.IsAsciiLetter(rule.Domain[0])
            || rule.Domain.Any(character => !char.IsAsciiLetterOrDigit(character) && character != '-')
            || rule.Parts is null || rule.Parts.Count > 32 || rule.Parts.Any(part => !Enum.IsDefined(part)))
            throw new SollangException("SELFHOST_POLICY_KEY_RULE_INVALID: " + name);
        var output = char.ToLowerInvariant(name[0]) + name[1..];
        // A singleton qualified enum name in [name; ~] is parsed as an empty
        // typed array. Build typed enum values explicitly, including that case.
        var binding = rule.Parts.Count == 0 ? "parts" : "parts!";
        return "public " + output + ": -> KeyRule {\n    [KeyPart; ~] => " + binding + "\n"
            + string.Concat(rule.Parts.Select(part => "    parts! -> push(KeyPart." + part + ")\n"))
            + "    KeyRule {\n        domain: \"" + rule.Domain
            + "\"\n        parts: " + binding + "\n    }\n}\n";
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
