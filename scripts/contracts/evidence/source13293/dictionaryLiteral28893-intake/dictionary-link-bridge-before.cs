using System.Reflection;
using System.Security.Cryptography;
using System.Text.Json;
using System.Globalization;
using System.Text.RegularExpressions;

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
