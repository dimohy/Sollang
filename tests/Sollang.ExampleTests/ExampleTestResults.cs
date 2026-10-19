using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

// Opt-in results for the existing runner; assertion decisions stay in Program.
internal sealed class ExampleTestResults
{
    internal static ExampleTestResults? Current { get; private set; }
    private static readonly AsyncLocal<string?> CaseName = new();
    private readonly object gate = new();
    private readonly string output;
    private readonly Dictionary<string, string> inputHashes;
    private readonly Dictionary<string, string> fixtureInputHashes;
    private readonly List<FileStream> inputLeases = [];
    private readonly Dictionary<string, CaseRecord> cases;
    private readonly List<ProcessRecord> processes = [];
    private readonly Dictionary<int, Process> active = [];
    private readonly string target;
    private readonly string compiler;
    private readonly string[] catalog;
    private readonly string verificationScope;
    private string status = "running";
    private bool finished;
    private bool inputsStable = true;
    internal bool Cancelled { get; private set; }

    internal ExampleTestResults(string output, string compiler, string target,
        string[] catalog, IEnumerable<string> fixtureInputs, IEnumerable<string> toolInputs,
        IEnumerable<string>? reusableSelfHostCases = null, string verificationScope = "regression")
    {
        this.output = output;
        this.compiler = compiler;
        this.target = target;
        this.catalog = catalog;
        this.verificationScope = verificationScope;
        var reusable = (reusableSelfHostCases ?? []).ToHashSet(StringComparer.Ordinal);
        cases = catalog.ToDictionary(name => name, name => new CaseRecord
        {
            Id = name, RequiresSelfHostCompiler = reusable.Contains(name)
        }, StringComparer.Ordinal);
        try
        {
            fixtureInputHashes = Pin(fixtureInputs);
            inputHashes = new(fixtureInputHashes, StringComparer.Ordinal);
            foreach (var (path, hash) in Pin(toolInputs)) inputHashes[path] = hash;
        }
        catch
        {
            foreach (var lease in inputLeases) lease.Dispose();
            throw;
        }
        Current = this;
        Console.CancelKeyPress += OnCancel;
        AppDomain.CurrentDomain.ProcessExit += (_, _) => Finish(false);
        AppDomain.CurrentDomain.UnhandledException += (_, _) => Finish(false);
        Save();
    }

    private Dictionary<string, string> Pin(IEnumerable<string> paths)
    {
        var pins = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var path in paths.Select(Path.GetFullPath).Distinct(StringComparer.OrdinalIgnoreCase).Order(StringComparer.Ordinal))
        {
            // Deny writes/deletion for the complete run, not only the hash probes.
            var lease = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
            inputLeases.Add(lease);
            pins.Add(path, Convert.ToHexString(SHA256.HashData(lease)));
        }
        return pins;
    }

    internal static void StartCase(string name)
    {
        CaseName.Value = name;
        if (Current is not { } results) return;
        lock (results.gate)
        {
            results.cases[name].Status = "running";
            results.Save(name);
        }
    }

    internal static void CompleteCase(string name, bool passed, TimeSpan elapsed)
    {
        if (Current is { } results)
        {
            lock (results.gate)
            {
                var row = results.cases[name];
                row.Status = results.Cancelled ? "cancelled" : passed ? "passed" : "failed";
                row.DurationMilliseconds = elapsed.TotalMilliseconds;
                results.Save(name);
            }
        }
        CaseName.Value = null;
    }

    internal static void Oracle(string kind, string expectedPath, bool requiredLlvmAssertions)
    {
        if (Current is not { } results || CaseName.Value is not { } name) return;
        lock (results.gate)
        {
            results.cases[name].Oracle = new { kind, expectedPath, requiredLlvmAssertions };
            results.Save(name);
        }
    }

    internal static Dictionary<string, string>? CommandInputs(string executable,
        IReadOnlyList<string> arguments, string workingDirectory)
    {
        if (Current is null) return null;
        var hashes = new Dictionary<string, string>(StringComparer.Ordinal);
        void Add(string file)
        {
            if (File.Exists(file)) hashes[file] = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(file)));
        }
        Add(Path.GetFullPath(executable, workingDirectory));
        for (var index = 0; index < arguments.Count; index++)
        {
            if (index > 0 && arguments[index - 1] is "-o" or "--output") continue;
            var path = Path.Combine(workingDirectory, arguments[index]);
            if (File.Exists(path)) Add(Path.GetFullPath(path));
            else if (Directory.Exists(path) && index > 0 && arguments[index - 1] is "--project" or "--workspace")
                foreach (var file in Directory.EnumerateFiles(path, "*", SearchOption.AllDirectories)
                    .Where(file => Path.GetExtension(file) is ".slg" or ".project" or ".workspace" or ".lock")) Add(file);
        }
        return hashes;
    }

    internal static ProcessRecord? Started(Process process, string fileName,
        IReadOnlyList<string> arguments, string workingDirectory, string? input,
        IReadOnlyDictionary<string, string>? environment, string role, Dictionary<string, string>? commandInputs)
    {
        if (Current is not { } results) return null;
        lock (results.gate)
        {
            var row = new ProcessRecord
            {
                Pid = process.Id, Command = [fileName, .. arguments], WorkingDirectory = workingDirectory,
                Input = input, Environment = environment, Role = role, Case = CaseName.Value,
                StartedAtUtc = DateTimeOffset.UtcNow, Index = results.processes.Count, CommandInputHashes = commandInputs
            };
            results.processes.Add(row);
            results.active.Add(process.Id, process);
            if (row.Case is { } name) results.cases[name].Processes.Add(row.Index);
            results.Save(row.Case, publishRun: row.Case is null);
            return row;
        }
    }

    internal static void Ended(ProcessRecord? row, Process process, ProcessResult? result, string? error = null, string? rawStdout = null, string? rawStderr = null)
    {
        if (Current is not { } results) return;
        lock (results.gate)
        {
            row ??= results.processes.LastOrDefault(item => item.Pid == process.Id);
            if (row is null) return;
            row.Exit = result?.ExitCode;
            row.ActualExit = process.ExitCode;
            row.Stdout = rawStdout ?? result?.Stdout;
            row.Stderr = rawStderr ?? result?.Stderr;
            row.DiagnosticOutput = row.Role == "compile" && result is not null
                ? string.Concat(Regex.Matches(row.Stdout + row.Stderr,
                    @"(?m)^(?:sollang:|; sollang (?:semantic|source root)|warning S\d{3}\b|note N\d{3}\b).*?(?:\r?\n|$)")
                    .Select(match => match.Value)) : null;
            row.Error = error;
            row.FinishedAtUtc = DateTimeOffset.UtcNow;
            row.ShutdownConfirmed = process.HasExited;
            results.active.Remove(row.Pid);
            var folder = row.Case is { } name
                ? Path.Combine(results.output, "cases", Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(name))))
                : Path.Combine(results.output, "setup");
            Directory.CreateDirectory(folder);
            if (row.Stdout is not null)
            {
                row.StdoutPath = Path.Combine(folder, $"{row.Index:D5}.stdout");
                File.WriteAllText(row.StdoutPath, row.Stdout, new UTF8Encoding(false));
                row.StdoutSha256 = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(row.StdoutPath)));
            }
            if (row.Stderr is not null)
            {
                row.StderrPath = Path.Combine(folder, $"{row.Index:D5}.stderr");
                File.WriteAllText(row.StderrPath, row.Stderr, new UTF8Encoding(false));
                row.StderrSha256 = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(row.StderrPath)));
            }
            results.Save(row.Case, publishRun: row.Case is null);
        }
    }

    private void OnCancel(object? sender, ConsoleCancelEventArgs args)
    {
        args.Cancel = true;
        lock (gate)
        {
            Cancelled = true;
            foreach (var process in active.Values)
                if (!process.HasExited) process.Kill(entireProcessTree: true);
            Save();
        }
    }

    internal bool Finish(bool success)
    {
        lock (gate)
        {
            if (finished) return status == "passed";
            inputsStable = InputsStable();
            status = Cancelled ? "cancelled"
                : success && inputsStable && cases.Values.All(row => row.Status == "passed")
                    && processes.All(row => row.ShutdownConfirmed) && active.Count == 0 ? "passed" : "failed";
            Save();
            finished = true;
            Console.CancelKeyPress -= OnCancel;
            foreach (var lease in inputLeases) lease.Dispose();
            return status == "passed";
        }
    }

    private bool InputsStable() => inputHashes.All(pin => File.Exists(pin.Key)
        && Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(pin.Key))) == pin.Value);

    internal bool CompleteInputPreflight()
    {
        lock (gate)
        {
            if (finished || processes.Count != 0 || active.Count != 0)
                throw new InvalidOperationException("INPUT_PREFLIGHT_ALREADY_EXECUTED");
            inputsStable = InputsStable();
            status = inputsStable ? "validated" : "failed";
            Save();
            finished = true;
            Console.CancelKeyPress -= OnCancel;
            foreach (var lease in inputLeases) lease.Dispose();
            return inputsStable;
        }
    }

    private void Save(string? changedCase = null, bool publishRun = true)
    {
        var record = new
        {
            status, verificationScope, completed = cases.Values.Count(row => row.Status is "passed" or "failed" or "cancelled"),
            total = cases.Count, inputHashes, fixtureInputHashes, selectedCatalog = catalog, target, compiler, outputDirectory = output,
            compilerSha256 = inputHashes.GetValueOrDefault(compiler),
            inputsStable, processesStopped = status != "running" && active.Count == 0 && processes.All(row => row.ShutdownConfirmed),
            cases = catalog.Select(name => cases[name]),
            processes = processes.Select(row => new { row.Index, row.Pid, row.Command, row.WorkingDirectory, row.Case, row.Role,
                row.StartedAtUtc, row.FinishedAtUtc, row.Exit, row.ActualExit, row.Error, row.ShutdownConfirmed, row.CommandInputHashes,
                row.StdoutPath, row.StderrPath, row.StdoutSha256, row.StderrSha256 }),
            shutdownScope = "existing-runner-root-process; timeout/cancellation kills entire process tree"
        };
        foreach (var row in cases.Values.Where(row => row.Id == changedCase))
        {
            var directory = Path.Combine(output, "cases", Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(row.Id))));
            Directory.CreateDirectory(directory);
            row.ResultPath = Path.Combine(directory, "result.json");
            File.WriteAllText(row.ResultPath, JsonSerializer.Serialize(new { row.Id, row.Status, row.DurationMilliseconds, row.Oracle, row.RequiresSelfHostCompiler,
                processes = row.Processes.Select(index => processes[index]) }, JsonOptions), new UTF8Encoding(false));
            row.ResultSha256 = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(row.ResultPath)));
        }
        if (!publishRun) return;
        // Publish the case-file fingerprint with the same atomic run checkpoint.
        AtomicResultFile.Write(Path.Combine(output, "result.json"), JsonSerializer.Serialize(record, JsonOptions));
    }

    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true, PropertyNamingPolicy = JsonNamingPolicy.CamelCase };

    internal sealed class CaseRecord
    {
        public required string Id { get; init; }
        public bool RequiresSelfHostCompiler { get; init; }
        public string Status { get; set; } = "pending";
        public double? DurationMilliseconds { get; set; }
        public object? Oracle { get; set; }
        public List<int> Processes { get; } = [];
        public string? ResultPath { get; set; }
        public string? ResultSha256 { get; set; }
    }

    internal sealed class ProcessRecord
    {
        public int Index { get; init; }
        public int Pid { get; init; }
        public required string[] Command { get; init; }
        public required string WorkingDirectory { get; init; }
        public string? Case { get; init; }
        public required string Role { get; init; }
        public string? Input { get; init; }
        public IReadOnlyDictionary<string, string>? Environment { get; init; }
        public DateTimeOffset StartedAtUtc { get; init; }
        public DateTimeOffset? FinishedAtUtc { get; set; }
        public int? Exit { get; set; }
        public int? ActualExit { get; set; }
        public Dictionary<string, string>? CommandInputHashes { get; init; }
        [JsonIgnore] public string? Stdout { get; set; }
        [JsonIgnore] public string? Stderr { get; set; }
        public string? Error { get; set; }
        public string? DiagnosticOutput { get; set; }
        public string? StdoutPath { get; set; }
        public string? StderrPath { get; set; }
        public string? StdoutSha256 { get; set; }
        public string? StderrSha256 { get; set; }
        public bool ShutdownConfirmed { get; set; }
    }

    internal static int Compare(string managedPath, string nativePath, Func<string, string> normalize)
    {
        try
        {
            using var managed = JsonDocument.Parse(File.ReadAllText(managedPath));
            using var native = JsonDocument.Parse(File.ReadAllText(nativePath));
            var left = managed.RootElement;
            var right = native.RootElement;
            Validate(left);
            Validate(right);
            if (!string.Equals(Path.GetExtension(left.GetProperty("compiler").GetString()), ".dll", StringComparison.OrdinalIgnoreCase)
                || !string.Equals(Path.GetExtension(right.GetProperty("compiler").GetString()), ".exe", StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("Comparison requires managed DLL then native EXE records");
            if (left.GetProperty("target").GetString() != right.GetProperty("target").GetString()
                || !left.GetProperty("selectedCatalog").EnumerateArray().Select(item => item.GetString())
                    .SequenceEqual(right.GetProperty("selectedCatalog").EnumerateArray().Select(item => item.GetString()))
                || !Pins(left.GetProperty("fixtureInputHashes")).SequenceEqual(Pins(right.GetProperty("fixtureInputHashes"))))
                throw new InvalidOperationException("Comparison catalog, target or fixture inputs differ");
            var leftCases = left.GetProperty("cases").EnumerateArray().ToArray();
            var rightCases = right.GetProperty("cases").EnumerateArray().ToArray();
            for (var index = 0; index < leftCases.Length; index++)
            {
                using var leftCase = ReadCase(leftCases[index], left);
                using var rightCase = ReadCase(rightCases[index], right);
                var a = leftCase.RootElement;
                var b = rightCase.RootElement;
                if (a.GetProperty("oracle").GetRawText() != b.GetProperty("oracle").GetRawText())
                    throw new InvalidOperationException("Comparison oracle declarations differ");
                if (!SourcePins(a, left.GetProperty("outputDirectory").GetString()!)
                    .SequenceEqual(SourcePins(b, right.GetProperty("outputDirectory").GetString()!)))
                    throw new InvalidOperationException($"Actual command source inputs differ: {a.GetProperty("id").GetString()}");
                var compilesA = a.GetProperty("processes").EnumerateArray().Where(item => item.GetProperty("role").GetString() == "compile").ToArray();
                var compilesB = b.GetProperty("processes").EnumerateArray().Where(item => item.GetProperty("role").GetString() == "compile").ToArray();
                if (compilesA.Length != compilesB.Length
                    || !compilesA.Select(item => normalize(item.GetProperty("diagnosticOutput").GetString() ?? string.Empty))
                        .SequenceEqual(compilesB.Select(item => normalize(item.GetProperty("diagnosticOutput").GetString() ?? string.Empty)))
                    || !compilesA.Select(item => normalize(Stream(item, "stderr"))).SequenceEqual(compilesB.Select(item => normalize(Stream(item, "stderr"))))
                    || !compilesA.Select(item => item.GetProperty("exit").GetInt32()).SequenceEqual(compilesB.Select(item => item.GetProperty("exit").GetInt32())))
                    throw new InvalidOperationException("Actual compiler diagnostic stages differ or are missing");
                var kind = a.GetProperty("oracle").GetProperty("kind").GetString();
                if (kind == "compiler-diagnostic")
                {
                    var ac = a.GetProperty("processes").EnumerateArray().First(item => item.GetProperty("role").GetString() == "compile");
                    var bc = b.GetProperty("processes").EnumerateArray().First(item => item.GetProperty("role").GetString() == "compile");
                    if (ac.GetProperty("exit").GetInt32() != bc.GetProperty("exit").GetInt32()
                        || normalize(Stream(ac, "stdout")) != normalize(Stream(bc, "stdout"))
                        || normalize(Stream(ac, "stderr")) != normalize(Stream(bc, "stderr")))
                        throw new InvalidOperationException($"Actual compiler diagnostics differ: {a.GetProperty("id").GetString()}");
                }
                else if (kind is "runtime" or "llvm")
                {
                    var ar = a.GetProperty("processes").EnumerateArray().Where(item => item.GetProperty("role").GetString() == "run").ToArray();
                    var br = b.GetProperty("processes").EnumerateArray().Where(item => item.GetProperty("role").GetString() == "run").ToArray();
                    if (kind == "runtime" && ar.Length == 0 || ar.Length != br.Length) throw new InvalidOperationException("Runtime stage counts differ or are missing");
                    for (var stage = 0; stage < ar.Length; stage++)
                        if (ar[stage].GetProperty("exit").GetInt32() != br[stage].GetProperty("exit").GetInt32()
                            || normalize(Stream(ar[stage], "stdout")) != normalize(Stream(br[stage], "stdout"))
                            || normalize(Stream(ar[stage], "stderr")) != normalize(Stream(br[stage], "stderr")))
                            throw new InvalidOperationException($"Actual runtime results differ: {a.GetProperty("id").GetString()}");
                }
                // Compile-only cases retain their existing exact snapshot and
                // required LLVM assertion decisions; raw compiler IR identities,
                // timings and product/output command paths are not equality keys.
                else if (kind != "compile-only")
                    throw new InvalidOperationException("Unknown comparison oracle kind");
            }
            var leftRegression = left.TryGetProperty("regressionTestOnly", out var leftFlag) && leftFlag.ValueKind == JsonValueKind.True;
            var rightRegression = right.TryGetProperty("regressionTestOnly", out var rightFlag) && rightFlag.ValueKind == JsonValueKind.True;
            if (leftRegression != rightRegression)
                throw new InvalidOperationException("Cannot mix synthetic regression fixtures with producer execution records");
            Console.WriteLine(leftRegression
                ? $"PASS consumer regression {leftCases.Length}/{leftCases.Length}; synthetic fixtures; no producer comparison proof"
                : $"PASS actual managed/native results {leftCases.Length}/{leftCases.Length}");
            return 0;
        }
        catch (Exception error) when (error is IOException or JsonException or InvalidOperationException or KeyNotFoundException)
        {
            Console.Error.WriteLine($"Result comparison rejected: {error.Message}");
            return 1;
        }
    }

    private static IEnumerable<string> SourcePins(JsonElement results, string output)
    {
        var sources = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var process in results.GetProperty("processes").EnumerateArray())
            foreach (var pin in process.GetProperty("commandInputHashes").EnumerateObject())
                if (Path.GetExtension(pin.Name) is ".slg" or ".project" or ".workspace" or ".lock" or ".h" or ".hpp")
                {
                    var key = pin.Name.StartsWith(output + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)
                        ? "<output>/" + Path.GetRelativePath(output, pin.Name) : pin.Name;
                    // Multiple compiler stages may intentionally mutate generated
                    // lock state; keep every distinct observed input, not last-win.
                    sources[key + "=" + pin.Value.GetString()] = pin.Value.GetString()!;
                }
        return sources.Keys.Order(StringComparer.Ordinal);
    }

    private static string Stream(JsonElement process, string stream) => File.ReadAllText(process.GetProperty(stream + "Path").GetString()!, Encoding.UTF8);

    private static IEnumerable<string> Pins(JsonElement pins) => pins.EnumerateObject()
        .OrderBy(item => item.Name, StringComparer.Ordinal).Select(item => item.Name + "=" + item.Value.GetString());

    private static void Validate(JsonElement record)
    {
        if (record.TryGetProperty("verificationScope", out var scope) && scope.GetString() != "regression")
            throw new InvalidOperationException("Maintenance candidates cannot substitute for regression acceptance");
        if (record.GetProperty("status").GetString() != "passed" || !record.GetProperty("inputsStable").GetBoolean()
            || !record.GetProperty("processesStopped").GetBoolean()
            || record.GetProperty("completed").GetInt32() != record.GetProperty("total").GetInt32()
            || record.GetProperty("total").GetInt32() <= 0)
            throw new InvalidOperationException("Record is failed, cancelled, incomplete or input-unstable");
        if (record.GetProperty("cases").GetArrayLength() != record.GetProperty("total").GetInt32()
            || record.GetProperty("selectedCatalog").GetArrayLength() != record.GetProperty("total").GetInt32())
            throw new InvalidOperationException("Record case/catalog counts differ");
        if (!record.GetProperty("cases").EnumerateArray().Select(row => row.GetProperty("id").GetString())
            .SequenceEqual(record.GetProperty("selectedCatalog").EnumerateArray().Select(item => item.GetString())))
            throw new InvalidOperationException("Record cases do not match selected catalog");
        foreach (var pin in record.GetProperty("inputHashes").EnumerateObject())
            if (Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(pin.Name))) != pin.Value.GetString())
                throw new InvalidOperationException("Record input hash changed");
        foreach (var process in record.GetProperty("processes").EnumerateArray())
        {
            if (!process.GetProperty("shutdownConfirmed").GetBoolean() || process.GetProperty("exit").ValueKind != JsonValueKind.Number)
                throw new InvalidOperationException("Process record is incomplete");
            foreach (var stream in new[] { "stdout", "stderr" })
                if (Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(process.GetProperty(stream + "Path").GetString()!)))
                    != process.GetProperty(stream + "Sha256").GetString())
                    throw new InvalidOperationException("Actual process output changed");
        }
    }

    private static JsonDocument ReadCase(JsonElement row, JsonElement record)
    {
        if (row.GetProperty("status").GetString() != "passed") throw new InvalidOperationException("Case did not pass");
        var bytes = File.ReadAllBytes(row.GetProperty("resultPath").GetString()!);
        if (Convert.ToHexString(SHA256.HashData(bytes)) != row.GetProperty("resultSha256").GetString())
            throw new InvalidOperationException("Case record changed");
        var document = JsonDocument.Parse(bytes);
        if (document.RootElement.GetProperty("id").GetString() != row.GetProperty("id").GetString()
            || document.RootElement.GetProperty("status").GetString() != "passed")
        {
            document.Dispose();
            throw new InvalidOperationException("Case record identity or status differs");
        }
        if (document.RootElement.GetProperty("processes").GetArrayLength() == 0
            || !document.RootElement.GetProperty("processes").EnumerateArray().All(process =>
                process.GetProperty("case").GetString() == row.GetProperty("id").GetString()))
        {
            document.Dispose();
            throw new InvalidOperationException("Case process association differs");
        }
        var actualProcesses = document.RootElement.GetProperty("processes").EnumerateArray().ToArray();
        if (!row.GetProperty("processes").EnumerateArray().Select(item => item.GetInt32())
            .SequenceEqual(actualProcesses.Select(item => item.GetProperty("index").GetInt32())))
            throw new InvalidOperationException("Case process indices differ from run record");
        foreach (var process in actualProcesses)
        {
            var index = process.GetProperty("index").GetInt32();
            if (index < 0 || index >= record.GetProperty("processes").GetArrayLength())
                throw new InvalidOperationException("Case process index is outside run record");
            var global = record.GetProperty("processes")[index];
            foreach (var field in new[] { "index", "pid", "case", "role", "exit", "actualExit", "shutdownConfirmed", "stdoutPath", "stderrPath", "stdoutSha256", "stderrSha256", "command", "commandInputHashes" })
                if (process.GetProperty(field).GetRawText() != global.GetProperty(field).GetRawText())
                    throw new InvalidOperationException("Case process differs from run record");
        }
        foreach (var process in actualProcesses)
            foreach (var stream in new[] { "stdout", "stderr" })
                if (Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(process.GetProperty(stream + "Path").GetString()!)))
                    != process.GetProperty(stream + "Sha256").GetString())
                {
                    document.Dispose();
                    throw new InvalidOperationException("Case process output changed");
                }
        return document;
    }
}
