using System.Text.RegularExpressions;

internal static class LinkedLlvmExecutionTarget
{
    internal static TestTarget Resolve(string llvm, string? declaredMode = null)
    {
        var triples = Regex.Matches(llvm,
            "^[ \\t]*target[ \\t]+triple[ \\t]*=[ \\t]*\"(?<triple>[^\"]+)\"[ \\t]*\\r?$",
            RegexOptions.Multiline | RegexOptions.CultureInvariant);
        if (triples.Count != 1)
            throw new InvalidOperationException("LLVM_EXECUTION_TRIPLE_INVALID");

        var target = triples[0].Groups["triple"].Value switch
        {
            "x86_64-pc-windows-msvc" => TestTarget.WindowsX64,
            "x86_64-unknown-linux-gnu" => TestTarget.LinuxX64,
            _ => throw new InvalidOperationException("LLVM_EXECUTION_TARGET_UNSUPPORTED")
        };
        if (declaredMode is not null)
        {
            var declared = declaredMode switch
            {
                "windows" => TestTarget.WindowsX64,
                "linux" => TestTarget.LinuxX64,
                _ => throw new InvalidOperationException("LLVM_EXECUTION_DECLARED_MODE_UNSUPPORTED")
            };
            if (target != declared)
                throw new InvalidOperationException("LLVM_EXECUTION_TARGET_MISMATCH");
        }
        return target;
    }
}
