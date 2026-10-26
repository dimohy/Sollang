using System.Reflection;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text;
using System.Globalization;

if (args.Length is not (8 or 9) || args[0] is not ("probe" or "link" or "probe-slg-main" or "link-slg-main"))
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
var digest = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(assemblyPath)));
if (!string.Equals(digest, args[2], StringComparison.Ordinal))
    throw new InvalidOperationException("COMPILER_LINK_BRIDGE_ASSEMBLY_DRIFT");
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
var slgMain = args[0] is "probe-slg-main" or "link-slg-main";
var entryDeclaration = slgMain ? "define i32 @main()" : "define dso_local i32 @sollang_start()";
if (!File.ReadLines(input).Any(line => line.StartsWith(entryDeclaration, StringComparison.Ordinal)))
    throw new InvalidOperationException("COMPILER_LINK_BRIDGE_ENTRY_REQUIRED");
var allocatorDeclarations = new Dictionary<string, string> {
    ["malloc"] = "declare ptr @malloc(i64)", ["free"] = "declare void @free(ptr)",
    ["calloc"] = "declare ptr @calloc(i64, i64)", ["realloc"] = "declare ptr @realloc(ptr, i64)" };
var requiredAllocators = new List<string>();
if (slgMain)
    foreach (var (symbol, declaration) in allocatorDeclarations)
    {
        var declarations = File.ReadLines(input).Where(line => line.StartsWith("declare ", StringComparison.Ordinal)
            && line.Contains("@" + symbol + "(", StringComparison.Ordinal)).ToArray();
        if (declarations.Length == 0) continue;
        if (declarations.Length != 1 || declarations[0] != declaration)
            throw new InvalidOperationException("COMPILER_LINK_BRIDGE_ALLOCATOR_ABI_MISMATCH:" + symbol);
        requiredAllocators.Add(symbol);
    }

var assembly = Assembly.LoadFrom(assemblyPath);
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
if (slgMain)
{
    // Small SLG emission probes retain their actual main ABI. Reuse the pinned
    // production compiler's object compilation and import-library factories.
    var flags = BindingFlags.NonPublic | BindingFlags.Instance;
    var compile = linkerType.GetMethod("CompileSingleModule", flags,
        binder: null, types: [typeof(string), typeof(string), typeof(string)], modifiers: null)
        ?? throw new MissingMethodException("COMPILER_LINK_BRIDGE_COMPILE_CONTRACT_MISSING");
    var run = linkerType.GetMethod("Run", BindingFlags.NonPublic | BindingFlags.Static,
        binder: null, types: [typeof(string), typeof(IReadOnlyList<string>)], modifiers: null)
        ?? throw new MissingMethodException("COMPILER_LINK_BRIDGE_RUN_CONTRACT_MISSING");
    var libraries = new List<MethodInfo>();
    foreach (var name in new[] { "CreateKernel32ImportLibrary", "CreateShell32ImportLibrary", "CreateUcrtBaseImportLibrary" })
        libraries.Add(linkerType.GetMethod(name, flags, binder: null, types: [typeof(string)], modifiers: null)
            ?? throw new MissingMethodException("COMPILER_LINK_BRIDGE_IMPORT_CONTRACT_MISSING:" + name));
    foreach (var (predicate, factory) in new[] {
        ("UsesComInterop", "CreateOle32ImportLibrary"),
        ("UsesNetworkSockets", "CreateWs2_32ImportLibrary"),
        ("UsesSecureRandom", "CreateBcryptImportLibrary") })
    {
        var uses = linkerType.GetMethod(predicate, BindingFlags.NonPublic | BindingFlags.Static,
            binder: null, types: [typeof(string)], modifiers: null)
            ?? throw new MissingMethodException("COMPILER_LINK_BRIDGE_IMPORT_PROBE_MISSING:" + predicate);
        var library = linkerType.GetMethod(factory, flags, binder: null, types: [typeof(string)], modifiers: null)
            ?? throw new MissingMethodException("COMPILER_LINK_BRIDGE_IMPORT_CONTRACT_MISSING:" + factory);
        if ((bool)uses.Invoke(null, [input])!) libraries.Add(library);
    }
    if (args[0] == "link-slg-main")
    {
        var objects = (IReadOnlyList<string>)compile.Invoke(linker, [input, Path.Combine(work, "program.obj"), optimization])!;
        var arguments = new List<string> { "/nologo", "/machine:x64", "/nodefaultlib", "/opt:ref", "/opt:icf",
            "/fixed", "/stack:8388608,65536", "/subsystem:console", "/entry:main" };
        arguments.AddRange(objects);
        foreach (var library in libraries) arguments.Add((string)library.Invoke(linker, [work])!);
        if (requiredAllocators.Count > 0)
        {
            var definition = Path.Combine(work, "slg-allocators.def");
            var library = Path.Combine(work, "slg-allocators.lib");
            File.WriteAllText(definition, "LIBRARY ucrtbase.dll\nEXPORTS\n" + string.Join('\n', requiredAllocators) + "\n",
                new UTF8Encoding(false));
            run.Invoke(null, [Path.Combine(llvmHome, "bin", "llvm-lib.exe"),
                new List<string> { "/nologo", "/machine:x64", "/def:" + definition, "/out:" + library }]);
            arguments.Add(library);
        }
        arguments.Add("/out:" + output);
        run.Invoke(null, [Path.Combine(llvmHome, "bin", "lld-link.exe"), arguments]);
    }
}
else if (args[0] == "link")
    link.Invoke(linker, [input, output, work, optimization, false]);
Console.WriteLine(JsonSerializer.Serialize(new { status = "passed", mode = args[0],
    scope = "diagnostic-link-only-not-compiler-acceptance", compilerAssemblySha256 = digest, optimization,
    entryPoint = slgMain ? "main" : "sollang_start", maximumWorkers, resolvedWorkerLimit }));
