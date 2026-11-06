using System.Reflection;
using System.Security.Cryptography;
using System.Text.Json;
using System.Globalization;
using System.Text.RegularExpressions;
using System.Text;
using System.Collections;
using System.Runtime.ExceptionServices;

static (Assembly Assembly, string Digest) LoadPinnedCompiler(string path, string expected)
{
    var digest = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path)));
    if (!string.Equals(digest, expected, StringComparison.Ordinal))
        throw new InvalidOperationException("COMPILER_LINK_BRIDGE_ASSEMBLY_DRIFT");
    return (Assembly.LoadFrom(path), digest);
}

static string CompilerEntryPoint(Assembly assembly)
{
    var policy = assembly.GetType("Sollang.Compiler.Shared.WindowsLinkPolicy", throwOnError: true)!;
    var getter = policy.GetMethod("EntryPoint", BindingFlags.Public | BindingFlags.Static)
        ?? throw new MissingMethodException("COMPILER_LINK_BRIDGE_ENTRY_POLICY_MISSING");
    var value = getter.Invoke(null, null) as string;
    if (value is null || !Regex.IsMatch(value, @"\A[A-Za-z_][A-Za-z_0-9]*\z"))
        throw new InvalidOperationException("COMPILER_LINK_BRIDGE_ENTRY_POLICY_INVALID");
    return value;
}

static object InvokeCompiler(MethodInfo method, object? owner, object?[] arguments)
{
    try { return method.Invoke(owner, arguments)!; }
    catch (TargetInvocationException error) when (error.InnerException is { } inner)
    {
        ExceptionDispatchInfo.Capture(inner).Throw();
        throw;
    }
}

// Reuse the production frontend and streaming emitter without invoking a linker.
// The supervising verification consumer owns separate emission and link budgets.
if (args.Length == 5 && args[0] == "emit")
{
    try
    {
        var (compiler, compilerDigest) = LoadPinnedCompiler(Path.GetFullPath(args[1]), args[2]);
        using var manifest = JsonDocument.Parse(File.ReadAllBytes(args[3]));
        var contract = manifest.RootElement;
        if (contract.GetProperty("schemaVersion").GetInt32() != 1
            || contract.GetProperty("target").GetString() != "windows-x64"
            || contract.GetProperty("outputKind").GetString() != "executable")
            throw new InvalidOperationException("COMPILER_EMISSION_CONTRACT_INVALID");
        var sources = contract.GetProperty("sourcePaths").EnumerateArray()
            .Select(item => item.GetString() ?? throw new InvalidOperationException("COMPILER_EMISSION_SOURCE_INVALID"))
            .ToArray();
        var pins = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var property in contract.GetProperty("inputHashes").EnumerateObject())
        {
            if (!Path.IsPathFullyQualified(property.Name)
                || !pins.TryAdd(Path.GetFullPath(property.Name), property.Value.GetString() ?? ""))
                throw new InvalidOperationException("COMPILER_EMISSION_INPUT_INVALID");
        }
        if (sources.Length == 0 || sources.Any(path => !Path.IsPathFullyQualified(path)
                || !pins.ContainsKey(Path.GetFullPath(path)))
            || sources.Distinct(StringComparer.OrdinalIgnoreCase).Count() != sources.Length)
            throw new InvalidOperationException("COMPILER_EMISSION_SOURCES_INVALID");
        void CheckPins()
        {
            foreach (var (path, expected) in pins)
                if (!File.Exists(path) || Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path))) != expected)
                    throw new InvalidOperationException("COMPILER_EMISSION_INPUT_DRIFT: " + path);
        }
        CheckPins();
        var llvmOutput = Path.GetFullPath(args[4]);
        if (File.Exists(llvmOutput) || Directory.Exists(llvmOutput)
            || !Directory.Exists(Path.GetDirectoryName(llvmOutput)))
            throw new InvalidOperationException("COMPILER_EMISSION_OUTPUT_INVALID");
        var app = compiler.GetType("Sollang.Compiler.Cli.CompilerApp", true)!;
        var target = Enum.Parse(compiler.GetType("Sollang.Compiler.CompilationTarget", true)!, "WindowsX64");
        var loaded = InvokeCompiler(app.GetMethod("LoadProgram", BindingFlags.Static | BindingFlags.NonPublic)!,
            null, [sources.Select(Path.GetFullPath).ToArray(), null, target]);
        void CheckLoadedInput(object input)
        {
            var type = input.GetType();
            var path = Path.GetFullPath((string)type.GetProperty("Path")!.GetValue(input)!);
            var bytesProperty = type.GetProperty("SourceBytes") ?? type.GetProperty("Bytes")!;
            var bytes = (byte[])bytesProperty.GetValue(input)!;
            if (!pins.TryGetValue(path, out var expected)
                || Convert.ToHexString(SHA256.HashData(bytes)) != expected)
                throw new InvalidOperationException("COMPILER_EMISSION_UNDECLARED_LOADED_INPUT: " + path);
        }
        foreach (var source in (IEnumerable)loaded.GetType().GetProperty("Sources")!.GetValue(loaded)!)
        {
            CheckLoadedInput(source);
            if (source.GetType().GetProperty("AdditionalInputs")!.GetValue(source) is IEnumerable additional)
                foreach (var input in additional) CheckLoadedInput(input);
        }
        var program = loaded.GetType().GetProperty("Program")!.GetValue(loaded)!;
        var semanticType = compiler.GetType("Sollang.Compiler.Semantics.SemanticCompiler", true)!;
        var semantic = Activator.CreateInstance(semanticType,
            BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic, null, [program, 64], null)!;
        var bound = InvokeCompiler(semanticType.GetMethod("Compile", BindingFlags.Instance | BindingFlags.Public)!,
            semantic, [null]);
        var warnings = ((IEnumerable)bound.GetType().GetProperty("Warnings")!.GetValue(bound)!)
            .Cast<object>().Select(warning => warning.ToString()).ToArray();
        var generator = compiler.GetType("Sollang.Compiler.CodeGen.LlvmIrGenerator", true)!;
        using (var stream = new FileStream(llvmOutput, FileMode.CreateNew, FileAccess.Write, FileShare.None))
        using (var writer = new StreamWriter(stream, new UTF8Encoding(false)))
            InvokeCompiler(generator.GetMethod("WriteProgram", BindingFlags.Static | BindingFlags.Public)!,
                null, [bound, target, writer, false]);
        CheckPins();
        if (Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(args[1]))) != compilerDigest)
            throw new InvalidOperationException("COMPILER_LINK_BRIDGE_ASSEMBLY_DRIFT");
        Console.WriteLine(JsonSerializer.Serialize(new { status = "passed", mode = "emit",
            scope = "llvm-generation-only-not-compiler-acceptance", compilerAssemblySha256 = compilerDigest,
            sourceCount = sources.Length, declaredInputCount = pins.Count, warnings,
            outputSha256 = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(llvmOutput))),
            outputBytes = new FileInfo(llvmOutput).Length }));
    }
    catch (Exception error)
    {
        Console.Error.WriteLine("sollang: " + error.Message);
        Console.WriteLine(JsonSerializer.Serialize(new { status = "failed", mode = "emit" }));
        Environment.ExitCode = 1;
    }
    return;
}

if (args.Length == 3 && args[0] == "policy")
{
    var (policyAssembly, policyDigest) = LoadPinnedCompiler(Path.GetFullPath(args[1]), args[2]);
    Console.WriteLine(JsonSerializer.Serialize(new { status = "passed", compilerAssemblySha256 = policyDigest,
        entryPoint = CompilerEntryPoint(policyAssembly) }));
    return;
}

if (args.Length > 0 && args[0] is "probe-slg-main" or "link-slg-main")
    throw new ArgumentException("COMPILER_LINK_BRIDGE_LEGACY_ENTRY_UNSUPPORTED: use the compiled entry policy and production linker");

if (args.Length is not (8 or 9) || args[0] is not ("probe" or "link"))
    throw new ArgumentException("COMPILER_LINK_BRIDGE_EXPLICIT_CONTRACT_REQUIRED: mode compiler.dll sha256 llvmHome input.ll output.exe workDir optimization [positive-worker-limit]");
int? maximumWorkers = null;
if (args.Length == 9)
{
    if (!int.TryParse(args[8], NumberStyles.None, CultureInfo.InvariantCulture, out var requested) || requested < 1)
        throw new ArgumentException("COMPILER_LINK_BRIDGE_WORKER_LIMIT_INVALID");
    maximumWorkers = requested;
}
var optimization = args[7];
if (optimization is not ("-O0" or "-O1" or "-O2" or "-O3"))
    throw new ArgumentException("COMPILER_LINK_BRIDGE_OPTIMIZATION_INVALID");

var assemblyPath = Path.GetFullPath(args[1]);
var (assembly, digest) = LoadPinnedCompiler(assemblyPath, args[2]);
var llvmHome = Path.GetFullPath(args[3]);
var input = Path.GetFullPath(args[4]);
var output = Path.GetFullPath(args[5]);
var work = Path.GetFullPath(args[6]);
if (File.Exists(output) || !Directory.Exists(work) || !File.Exists(input))
    throw new InvalidOperationException("COMPILER_LINK_BRIDGE_PATH_CONTRACT_INVALID");
foreach (var tool in new[] { "clang.exe", "lld-link.exe", "llvm-lib.exe" })
    if (!File.Exists(Path.Combine(llvmHome, "bin", tool)))
        throw new FileNotFoundException("COMPILER_LINK_BRIDGE_TOOL_MISSING", tool);
if (!File.ReadLines(input).Take(5).Contains("target triple = \"x86_64-pc-windows-msvc\""))
    throw new InvalidOperationException("COMPILER_LINK_BRIDGE_TARGET_ABI_MISMATCH");
var entryPoint = CompilerEntryPoint(assembly);
if (Regex.Matches(File.ReadAllText(input), @"^\s*define\b[^@\r\n]*@" + Regex.Escape(entryPoint) + @"\s*\(", RegexOptions.Multiline).Count != 1)
    throw new InvalidOperationException("COMPILER_LINK_BRIDGE_ENTRY_REQUIRED");
var toolchainType = assembly.GetType("Sollang.Compiler.Tooling.LlvmToolchain", throwOnError: true)!;
var from = toolchainType.GetMethod("From", BindingFlags.Public | BindingFlags.Static,
    binder: null, types: [typeof(string)], modifiers: null)
    ?? throw new MissingMethodException("COMPILER_LINK_BRIDGE_TOOLCHAIN_CONTRACT_MISSING");
var linkerType = assembly.GetType("Sollang.Compiler.Tooling.WindowsLinker", throwOnError: true)!;
var constructor = linkerType.GetConstructor(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance,
    binder: null, types: [toolchainType], modifiers: null)
    ?? throw new MissingMethodException("COMPILER_LINK_BRIDGE_CONSTRUCTOR_MISSING");
var link = linkerType.GetMethod("LinkLlvmIr", BindingFlags.Public | BindingFlags.Instance,
    binder: null, types: [typeof(string), typeof(string), typeof(string), typeof(string), typeof(bool)], modifiers: null)
    ?? throw new MissingMethodException("COMPILER_LINK_BRIDGE_LINK_CONTRACT_MISSING");
var toolchain = from.Invoke(null, [llvmHome]);
var linker = constructor.Invoke([toolchain]);
int? resolvedWorkerLimit = null;
if (maximumWorkers is { } workers)
{
    var property = linkerType.GetProperty("MaximumWorkers")
        ?? throw new MissingMemberException("COMPILER_LINK_BRIDGE_WORKER_LIMIT_CONTRACT_MISSING");
    property.SetValue(linker, workers);
    var resolver = linkerType.GetMethod("NativeJobLimit", BindingFlags.NonPublic | BindingFlags.Instance)
        ?? throw new MissingMethodException("COMPILER_LINK_BRIDGE_WORKER_RESOLVER_MISSING");
    resolvedWorkerLimit = (int)resolver.Invoke(linker, [Environment.ProcessorCount])!;
}
if (args[0] == "link")
    link.Invoke(linker, [input, output, work, optimization, false]);
Console.WriteLine(JsonSerializer.Serialize(new { status = "passed", mode = args[0],
    scope = "diagnostic-link-only-not-compiler-acceptance", compilerAssemblySha256 = digest, optimization,
    entryPoint, maximumWorkers, resolvedWorkerLimit }));
