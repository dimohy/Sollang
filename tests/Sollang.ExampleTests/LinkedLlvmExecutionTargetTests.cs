using System.Text.Json;

internal static class LinkedLlvmExecutionTargetTests
{
    internal static int Run(string resultPath)
    {
        resultPath = Path.GetFullPath(resultPath);
        if (File.Exists(resultPath)) throw new IOException("Test result already exists.");
        var cases = new List<object>();
        const string windows = "target triple = \"x86_64-pc-windows-msvc\"\n";
        const string linux = "target triple = \"x86_64-unknown-linux-gnu\"\n";
        var failed = false;
        string? failure = null;
        void Check(string id, Action action)
        {
            action();
            cases.Add(new { id, status = "passed" });
        }
        void Require(bool value)
        {
            if (!value) throw new InvalidOperationException("Unexpected execution target.");
        }
        void Rejected(string llvm, string? mode, string code)
        {
            try { LinkedLlvmExecutionTarget.Resolve(llvm, mode); }
            catch (InvalidOperationException error) when (error.Message == code) { return; }
            throw new InvalidOperationException("Missing rejection: " + code);
        }
        try
        {
            Check("windows-native", () => Require(LinkedLlvmExecutionTarget.Resolve(windows, "windows") == TestTarget.WindowsX64));
            Check("linux-emission-on-windows-host", () => Require(LinkedLlvmExecutionTarget.Resolve(linux, "linux") == TestTarget.LinuxX64));
            Check("module-target-without-reusable-driver", () => Require(LinkedLlvmExecutionTarget.Resolve(linux) == TestTarget.LinuxX64));
            Check("declared-mode-mismatch", () => Rejected(linux, "windows", "LLVM_EXECUTION_TARGET_MISMATCH"));
            Check("missing-triple", () => Rejected("define i32 @main() { ret i32 0 }", null, "LLVM_EXECUTION_TRIPLE_INVALID"));
            Check("duplicate-triple", () => Rejected(windows + linux, null, "LLVM_EXECUTION_TRIPLE_INVALID"));
            Check("wasm-is-not-host-executable", () => Rejected("target triple = \"wasm32-unknown-unknown\"\n", null, "LLVM_EXECUTION_TARGET_UNSUPPORTED"));
            Check("unknown-mode-no-fallback", () => Rejected(windows, "unknown", "LLVM_EXECUTION_DECLARED_MODE_UNSUPPORTED"));
        }
        catch (Exception error)
        {
            failed = true;
            failure = error.ToString();
        }
        AtomicResultFile.Write(resultPath, JsonSerializer.Serialize(new
        {
            status = failed ? "failed" : "passed", completed = cases.Count, total = 8,
            cases, failure
        }, new JsonSerializerOptions { WriteIndented = true }));
        return failed ? 1 : 0;
    }
}
