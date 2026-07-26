using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Runtime.InteropServices;
using Sollang.Compiler.Cli;
using Sollang.Compiler.Diagnostics;

namespace Sollang.Compiler.Tooling;

internal static class CppBindingGenerator
{
    private const int CursorFunctionDeclaration = 8;
    private const int CursorNamespace = 22;
    private const int TypeVoid = 2;
    private const int TypeCharUnsigned = 4;
    private const int TypeUnsignedChar = 5;
    private const int TypeUnsignedShort = 8;
    private const int TypeUnsignedInt = 9;
    private const int TypeUnsignedLong = 10;
    private const int TypeUnsignedLongLong = 11;
    private const int TypeCharSigned = 13;
    private const int TypeSignedChar = 14;
    private const int TypeShort = 16;
    private const int TypeInt = 17;
    private const int TypeLong = 18;
    private const int TypeLongLong = 19;
    private const int TypeFloat = 21;
    private const int TypeDouble = 22;

    public static CppBindingResult Generate(
        CppBindingOptions options,
        LlvmToolchain toolchain)
    {
        ClangNative.Configure(toolchain.Home);
        var clangArguments = CompilationArguments.Load(options);
        var index = ClangNative.clang_createIndex(0, 0);
        if (index == 0)
        {
            throw new SollangException("libclang failed to create an index");
        }

        nint translationUnit = 0;
        using var nativeArguments = new NativeUtf8Arguments(clangArguments);
        try
        {
            var parseResult = ClangNative.clang_parseTranslationUnit2(
                index,
                options.HeaderPath,
                nativeArguments.Pointer,
                clangArguments.Count,
                0,
                0,
                0,
                out translationUnit);
            if (parseResult != 0 || translationUnit == 0)
            {
                throw new SollangException(
                    $"libclang failed to parse '{options.HeaderPath}' (error {parseResult})");
            }
            ThrowForDiagnostics(translationUnit);
            var functions = ReadFunctions(translationUnit, options);
            var classes = CppClassBindingReader.Read(translationUnit, options);
            if (functions.Count == 0 && classes.Count == 0)
            {
                throw new SollangException(
                    "the C++ header contains no supported public noexcept scalar functions or classes");
            }
            return Emit(options, clangArguments, functions, classes);
        }
        finally
        {
            if (translationUnit != 0)
            {
                ClangNative.clang_disposeTranslationUnit(translationUnit);
            }
            ClangNative.clang_disposeIndex(index);
        }
    }

    private static void ThrowForDiagnostics(nint translationUnit)
    {
        var errors = new List<string>();
        var count = ClangNative.clang_getNumDiagnostics(translationUnit);
        for (uint index = 0; index < count; index++)
        {
            var diagnostic = ClangNative.clang_getDiagnostic(translationUnit, index);
            try
            {
                if (ClangNative.clang_getDiagnosticSeverity(diagnostic) >= 3)
                {
                    errors.Add(ClangNative.ToManagedString(
                        ClangNative.clang_formatDiagnostic(
                            diagnostic,
                            ClangNative.clang_defaultDiagnosticDisplayOptions())));
                }
            }
            finally
            {
                ClangNative.clang_disposeDiagnostic(diagnostic);
            }
        }
        if (errors.Count > 0)
        {
            throw new SollangException(
                "Clang rejected the C++ translation unit:"
                + Environment.NewLine
                + string.Join(Environment.NewLine, errors));
        }
    }

    private static List<CppFunction> ReadFunctions(
        nint translationUnit,
        CppBindingOptions options)
    {
        var functions = new List<CppFunction>();
        var seen = new HashSet<string>(StringComparer.Ordinal);

        void Visit(ClangNative.Cursor parent, IReadOnlyList<string> namespaces)
        {
            ClangNative.CursorVisitor? visitor = null;
            visitor = (cursor, _, _) =>
            {
                if (ClangNative.clang_Location_isFromMainFile(
                        ClangNative.clang_getCursorLocation(cursor)) == 0)
                {
                    return 1;
                }
                if (cursor.Kind == CursorNamespace)
                {
                    var name = ClangNative.ToManagedString(
                        ClangNative.clang_getCursorSpelling(cursor));
                    Visit(cursor, [.. namespaces, name]);
                    return 1;
                }
                if (cursor.Kind == CursorFunctionDeclaration)
                {
                    var usr = ClangNative.ToManagedString(ClangNative.clang_getCursorUSR(cursor));
                    if (seen.Add(usr))
                    {
                        functions.Add(ReadFunction(cursor, namespaces, options));
                    }
                }
                return 1;
            };
            ClangNative.clang_visitChildren(parent, visitor, 0);
            GC.KeepAlive(visitor);
        }

        Visit(ClangNative.clang_getTranslationUnitCursor(translationUnit), []);
        return functions.OrderBy(function => function.QualifiedName, StringComparer.Ordinal)
            .ThenBy(function => function.Signature, StringComparer.Ordinal)
            .ToList();
    }

    private static CppFunction ReadFunction(
        ClangNative.Cursor cursor,
        IReadOnlyList<string> namespaces,
        CppBindingOptions options)
    {
        var name = ClangNative.ToManagedString(ClangNative.clang_getCursorSpelling(cursor));
        var qualifiedName = namespaces.Count == 0
            ? name
            : string.Join("::", namespaces) + "::" + name;
        if (ClangNative.clang_Cursor_isVariadic(cursor) != 0)
        {
            throw Unsupported(qualifiedName, "variadic functions are not ABI-safe");
        }
        var exceptionKind = ClangNative.clang_getCursorExceptionSpecificationType(cursor);
        if (exceptionKind is not (1 or 4 or 9))
        {
            throw Unsupported(
                qualifiedName,
                "functions must be declared noexcept so no C++ exception can cross the C ABI");
        }

        var result = MapType(
            ClangNative.clang_getCursorResultType(cursor),
            options,
            qualifiedName,
            "result");
        var parameters = new List<CppParameter>();
        var count = ClangNative.clang_Cursor_getNumArguments(cursor);
        for (var index = 0; index < count; index++)
        {
            var argument = ClangNative.clang_Cursor_getArgument(cursor, (uint)index);
            var parameterName = ClangNative.ToManagedString(
                ClangNative.clang_getCursorSpelling(argument));
            if (string.IsNullOrWhiteSpace(parameterName))
            {
                parameterName = "value" + (index + 1).ToString(
                    System.Globalization.CultureInfo.InvariantCulture);
            }
            parameters.Add(new CppParameter(
                SanitizeIdentifier(parameterName),
                MapType(
                    ClangNative.clang_getCursorType(argument),
                    options,
                    qualifiedName,
                    $"parameter {index + 1}")));
        }

        var signature = result.SollangName
            + "("
            + string.Join(",", parameters.Select(parameter => parameter.Type.SollangName))
            + ")";
        var hash = Convert.ToHexString(
            SHA256.HashData(Encoding.UTF8.GetBytes(qualifiedName + ":" + signature)))
            .ToLowerInvariant()[..12];
        var memberName = SanitizeIdentifier(name);
        var symbol = "sollang_cpp_"
            + SanitizeIdentifier(string.Join("_", [.. namespaces, name]))
            + "_"
            + hash;
        return new CppFunction(
            memberName,
            qualifiedName,
            symbol,
            signature,
            result,
            parameters);
    }

    private static CppType MapType(
        ClangNative.Type type,
        CppBindingOptions options,
        string function,
        string position)
    {
        var canonical = ClangNative.clang_getCanonicalType(type);
        var spelling = ClangNative.ToManagedString(ClangNative.clang_getTypeSpelling(type));
        var kind = canonical.Kind;
        return kind switch
        {
            TypeVoid => new("Unit", "void"),
            TypeCharUnsigned or TypeUnsignedChar => new("UInt8", "unsigned char"),
            TypeCharSigned or TypeSignedChar => new("Int8", "signed char"),
            TypeUnsignedShort => new("UInt16", "unsigned short"),
            TypeUnsignedInt => new("UInt32", "unsigned int"),
            TypeUnsignedLong => options.Target == CompilationTarget.WindowsX64
                ? new("UInt32", "unsigned long")
                : new("UInt64", "unsigned long"),
            TypeUnsignedLongLong => new("UInt64", "unsigned long long"),
            TypeShort => new("Int16", "short"),
            TypeInt => new("Int32", "int"),
            TypeLong => options.Target == CompilationTarget.WindowsX64
                ? new("Int32", "long")
                : new("Int64", "long"),
            TypeLongLong => new("Int64", "long long"),
            TypeFloat => new("Float32", "float"),
            TypeDouble => new("Float64", "double"),
            _ => throw Unsupported(
                function,
                $"{position} type '{spelling}' is outside the scalar ABI slice")
        };
    }

    private static CppBindingResult Emit(
        CppBindingOptions options,
        IReadOnlyList<string> clangArguments,
        IReadOnlyList<CppFunction> functions,
        IReadOnlyList<CppClass> classes)
    {
        var duplicateNames = functions.GroupBy(function => function.MemberName)
            .Where(group => group.Count() > 1)
            .Select(group => group.Key)
            .ToHashSet(StringComparer.Ordinal);
        var resolved = functions.Select(function => duplicateNames.Contains(function.MemberName)
                ? function with
                {
                    MemberName = function.MemberName
                        + function.Parameters.Aggregate(
                            string.Empty,
                            (value, parameter) => value + parameter.Type.SollangName)
                }
                : function)
            .ToArray();
        if (resolved.GroupBy(function => function.MemberName).Any(group => group.Count() > 1))
        {
            throw new SollangException(
                "overloaded C++ functions still collide after type-based Sollang naming");
        }

        var sollang = new StringBuilder();
        sollang.Append("native ").Append(options.ModuleName)
            .Append(" from \"").Append(EscapeSollang(options.LibraryName)).AppendLine("\" {");
        foreach (var cppClass in classes)
        {
            sollang.Append("    handle ").Append(cppClass.Name)
                .Append(" drop \"").Append(cppClass.DropSymbol).AppendLine("\"");
        }
        foreach (var function in resolved)
        {
            sollang.Append("    ").Append(function.MemberName);
            if (function.Parameters.Count > 0)
            {
                sollang.Append(' ').Append(string.Join(", ", function.Parameters.Select(
                    parameter => parameter.Name + ": " + parameter.Type.SollangName)));
            }
            sollang.Append(" -> ").Append(function.Result.SollangName)
                .Append(" as \"").Append(function.Symbol).AppendLine("\"");
        }
        foreach (var cppClass in classes)
        {
            for (var index = 0; index < cppClass.Constructors.Count; index++)
            {
                var constructor = cppClass.Constructors[index];
                sollang.Append("    create").Append(cppClass.Name);
                if (index > 0)
                {
                    sollang.Append(index + 1);
                }
                AppendSollangParameters(sollang, constructor.Parameters);
                sollang.Append(" -> ").Append(options.ModuleName).Append('.').Append(cppClass.Name)
                    .Append(" as \"").Append(constructor.Symbol).AppendLine("\"");
            }
            foreach (var method in cppClass.Methods)
            {
                sollang.Append("    ").Append(LowerFirst(cppClass.Name))
                    .Append(UpperFirst(method.Name))
                    .Append(" self: ref ").Append(options.ModuleName).Append('.').Append(cppClass.Name);
                if (method.Parameters.Count > 0)
                {
                    sollang.Append(", ").Append(string.Join(", ", method.Parameters.Select(
                        parameter => parameter.Name + ": " + parameter.Type.SollangName)));
                }
                sollang.Append(" -> ").Append(method.Result.SollangName)
                    .Append(" as \"").Append(method.Symbol).AppendLine("\"");
            }
        }
        sollang.AppendLine("}");

        var header = Path.GetRelativePath(options.OutputDirectory, options.HeaderPath)
            .Replace('\\', '/');
        var shim = new StringBuilder();
        shim.AppendLine("// Generated by Sollang bind-cpp. Do not edit.");
        shim.Append("#include \"").Append(EscapeCpp(header)).AppendLine("\"");
        if (classes.Count > 0)
        {
            shim.AppendLine("#include <new>");
        }
        shim.AppendLine("#if defined(_WIN32)");
        shim.AppendLine("#define SOLLANG_CPP_EXPORT extern \"C\" __declspec(dllexport)");
        shim.AppendLine("#else");
        shim.AppendLine("#define SOLLANG_CPP_EXPORT extern \"C\" __attribute__((visibility(\"default\")))");
        shim.AppendLine("#endif");
        shim.AppendLine();
        foreach (var cppClass in classes)
        {
            shim.Append("struct sollang_handle_").Append(cppClass.Name)
                .AppendLine(" { unsigned long long handle; };");
        }
        if (classes.Count > 0)
        {
            shim.AppendLine();
        }
        foreach (var function in resolved)
        {
            shim.Append("SOLLANG_CPP_EXPORT ").Append(function.Result.CppName)
                .Append(' ').Append(function.Symbol).Append('(')
                .Append(string.Join(", ", function.Parameters.Select(
                    parameter => parameter.Type.CppName + " " + parameter.Name)))
                .AppendLine(") noexcept {");
            shim.Append("    ");
            if (function.Result.SollangName != "Unit")
            {
                shim.Append("return ");
            }
            shim.Append("::").Append(function.QualifiedName).Append('(')
                .Append(string.Join(", ", function.Parameters.Select(parameter => parameter.Name)))
                .AppendLine(");");
            shim.AppendLine("}");
            shim.AppendLine();
        }
        foreach (var cppClass in classes)
        {
            foreach (var constructor in cppClass.Constructors)
            {
                shim.Append("SOLLANG_CPP_EXPORT sollang_handle_").Append(cppClass.Name)
                    .Append(' ').Append(constructor.Symbol).Append('(')
                    .Append(string.Join(", ", constructor.Parameters.Select(
                        parameter => parameter.Type.CppName + " " + parameter.Name)))
                    .AppendLine(") noexcept {");
                shim.Append("    return { reinterpret_cast<unsigned long long>(new (std::nothrow) ::")
                    .Append(cppClass.QualifiedName).Append('(')
                    .Append(string.Join(", ", constructor.Parameters.Select(value => value.Name)))
                    .AppendLine(")) };");
                shim.AppendLine("}");
            }
            foreach (var method in cppClass.Methods)
            {
                shim.Append("SOLLANG_CPP_EXPORT ").Append(method.Result.CppName)
                    .Append(' ').Append(method.Symbol)
                    .Append("(const sollang_handle_").Append(cppClass.Name).Append("* self");
                if (method.Parameters.Count > 0)
                {
                    shim.Append(", ").Append(string.Join(", ", method.Parameters.Select(
                        parameter => parameter.Type.CppName + " " + parameter.Name)));
                }
                shim.AppendLine(") noexcept {");
                shim.Append("    ");
                if (method.Result.SollangName != "Unit")
                {
                    shim.Append("return ");
                }
                shim.Append("reinterpret_cast<");
                if (method.IsConst)
                {
                    shim.Append("const ");
                }
                shim.Append("::").Append(cppClass.QualifiedName).Append("*>(self->handle)->")
                    .Append(method.CppName).Append('(')
                    .Append(string.Join(", ", method.Parameters.Select(value => value.Name)))
                    .AppendLine(");");
                shim.AppendLine("}");
            }
            shim.Append("SOLLANG_CPP_EXPORT void ").Append(cppClass.DropSymbol)
                .AppendLine("(unsigned long long handle) noexcept {");
            shim.Append("    delete reinterpret_cast<::").Append(cppClass.QualifiedName)
                .AppendLine("*>(handle);");
            shim.AppendLine("}");
            shim.AppendLine();
        }

        var sollangPath = Path.Combine(options.OutputDirectory, options.ModuleName + ".slg");
        var shimPath = Path.Combine(options.OutputDirectory, options.ModuleName + "_shim.cpp");
        var manifestPath = Path.Combine(
            options.OutputDirectory,
            options.ModuleName + "." + options.TargetName + ".cppbind.json");
        var libraryPath = Path.Combine(
            options.OutputDirectory,
            options.Target == CompilationTarget.WindowsX64
                ? options.ModuleName + "_shim.dll"
                : "lib" + options.ModuleName + "_shim.so");
        var manifest = JsonSerializer.SerializeToUtf8Bytes(
            new CppBindingManifest(
                2,
                options.ModuleName,
                options.TargetName,
                Path.GetFullPath(options.HeaderPath).Replace('\\', '/'),
                Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(options.HeaderPath)))
                    .ToLowerInvariant(),
                options.LibraryName,
                clangArguments,
                resolved.Select(function => new CppBindingManifestFunction(
                    function.MemberName,
                    function.QualifiedName,
                    function.Symbol,
                    function.Signature))
                    .Concat(classes.SelectMany(cppClass =>
                        cppClass.Constructors.Select((constructor, index) =>
                                new CppBindingManifestFunction(
                                    "create" + cppClass.Name + (index == 0 ? "" : (index + 1).ToString()),
                                    cppClass.QualifiedName + "::" + cppClass.Name,
                                    constructor.Symbol,
                                    "owner(" + string.Join(",", constructor.Parameters.Select(
                                        parameter => parameter.Type.SollangName)) + ")"))
                            .Concat(cppClass.Methods.Select(method =>
                                new CppBindingManifestFunction(
                                    LowerFirst(cppClass.Name) + UpperFirst(method.Name),
                                    cppClass.QualifiedName + "::" + method.CppName,
                                    method.Symbol,
                                    method.Result.SollangName + "(" + string.Join(
                                        ",",
                                        method.Parameters.Select(parameter =>
                                            parameter.Type.SollangName)) + ")")))
                            .Append(new CppBindingManifestFunction(
                                "__drop" + cppClass.Name,
                                cppClass.QualifiedName + "::~" + cppClass.Name,
                                cppClass.DropSymbol,
                                "drop(owner)"))))
                    .ToArray()),
            new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                WriteIndented = true,
                DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
            });
        return new CppBindingResult(
            sollangPath,
            shimPath,
            manifestPath,
            libraryPath,
            sollang.ToString(),
            shim.ToString(),
            manifest,
            resolved.Length + classes.Sum(value =>
                value.Constructors.Count + value.Methods.Count + 1));
    }

    private static void AppendSollangParameters(
        StringBuilder builder,
        IReadOnlyList<CppParameter> parameters)
    {
        if (parameters.Count == 0)
        {
            builder.Append(':');
            return;
        }
        builder.Append(' ').Append(string.Join(", ", parameters.Select(
            parameter => parameter.Name + ": " + parameter.Type.SollangName)));
    }

    private static string LowerFirst(string value) =>
        char.ToLowerInvariant(value[0]) + value[1..];

    private static string UpperFirst(string value) =>
        char.ToUpperInvariant(value[0]) + value[1..];

    private static SollangException Unsupported(string function, string reason) =>
        new($"cannot bind C++ function '{function}': {reason}");

    private static string SanitizeIdentifier(string value)
    {
        var result = new string(value.Select(character =>
            char.IsLetterOrDigit(character) || character == '_' ? character : '_').ToArray());
        if (result.Length == 0)
        {
            return "value";
        }
        return char.IsDigit(result[0]) ? "_" + result : result;
    }

    private static string EscapeSollang(string value) =>
        value.Replace("\\", "\\\\", StringComparison.Ordinal)
            .Replace("\"", "\\\"", StringComparison.Ordinal);

    private static string EscapeCpp(string value) =>
        value.Replace("\\", "\\\\", StringComparison.Ordinal)
            .Replace("\"", "\\\"", StringComparison.Ordinal);
}

internal static class CompilationArguments
{
    public static IReadOnlyList<string> Load(CppBindingOptions options)
    {
        var result = options.CompilationDatabase is null
            ? new List<string>()
            : LoadDatabase(options);
        result.AddRange(options.ClangArguments);
        if (!result.Any(argument => argument.StartsWith("-std=", StringComparison.Ordinal)))
        {
            result.Add("-std=c++20");
        }
        if (!result.Contains("-x", StringComparer.Ordinal))
        {
            result.Add("-x");
            result.Add("c++");
        }
        if (!result.Any(argument => argument.StartsWith("--target=", StringComparison.Ordinal)))
        {
            result.Add(options.Target == CompilationTarget.WindowsX64
                ? "--target=x86_64-pc-windows-msvc"
                : "--target=x86_64-unknown-linux-gnu");
        }
        return result;
    }

    private static List<string> LoadDatabase(CppBindingOptions options)
    {
        var path = options.CompilationDatabase!;
        if (Directory.Exists(path))
        {
            path = Path.Combine(path, "compile_commands.json");
        }
        if (!File.Exists(path))
        {
            throw new SollangException($"compilation database was not found: {path}");
        }
        var entries = JsonSerializer.Deserialize<CompilationDatabaseEntry[]>(
            File.ReadAllBytes(path),
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
            ?? [];
        var requested = options.CompilationEntry ?? options.HeaderPath;
        var entry = entries.FirstOrDefault(candidate =>
            string.Equals(
                Path.GetFullPath(candidate.File, candidate.Directory),
                requested,
                OperatingSystem.IsWindows()
                    ? StringComparison.OrdinalIgnoreCase
                    : StringComparison.Ordinal));
        entry ??= entries.Length == 1 ? entries[0] : null;
        if (entry is null)
        {
            throw new SollangException(
                $"compile_commands.json has no unambiguous entry for '{requested}'; "
                + "use --compile-entry <source.cpp>");
        }
        if (entry.Arguments is null || entry.Arguments.Length == 0)
        {
            throw new SollangException(
                "the selected compile_commands.json entry uses 'command'; "
                + "regenerate it with the lossless 'arguments' array");
        }

        var result = new List<string>
        {
            "-working-directory=" + entry.Directory
        };
        for (var index = 1; index < entry.Arguments.Length; index++)
        {
            var argument = entry.Arguments[index];
            if (argument is "-c" or "/c")
            {
                continue;
            }
            if (argument is "-o" or "/Fo")
            {
                index++;
                continue;
            }
            if (string.Equals(
                Path.GetFullPath(argument, entry.Directory),
                Path.GetFullPath(entry.File, entry.Directory),
                OperatingSystem.IsWindows()
                    ? StringComparison.OrdinalIgnoreCase
                    : StringComparison.Ordinal))
            {
                continue;
            }
            result.Add(argument);
        }
        return result;
    }

    private sealed record CompilationDatabaseEntry(
        string Directory,
        string File,
        string[]? Arguments);
}

internal sealed record CppBindingResult(
    string SollangPath,
    string ShimPath,
    string ManifestPath,
    string LibraryPath,
    string SollangSource,
    string ShimSource,
    byte[] Manifest,
    int FunctionCount);

internal sealed record CppType(string SollangName, string CppName);
internal sealed record CppParameter(string Name, CppType Type);
internal sealed record CppFunction(
    string MemberName,
    string QualifiedName,
    string Symbol,
    string Signature,
    CppType Result,
    IReadOnlyList<CppParameter> Parameters);
internal sealed record CppBindingManifest(
    int SchemaVersion,
    string Module,
    string Target,
    string Header,
    string HeaderSha256,
    string Library,
    IReadOnlyList<string> ClangArguments,
    IReadOnlyList<CppBindingManifestFunction> Functions);
internal sealed record CppBindingManifestFunction(
    string Name,
    string CppName,
    string Symbol,
    string Signature);

internal sealed class NativeUtf8Arguments : IDisposable
{
    private readonly nint[] strings;
    public nint Pointer { get; }

    public NativeUtf8Arguments(IReadOnlyList<string> arguments)
    {
        strings = arguments.Select(Marshal.StringToCoTaskMemUTF8).ToArray();
        Pointer = Marshal.AllocHGlobal(IntPtr.Size * strings.Length);
        Marshal.Copy(strings, 0, Pointer, strings.Length);
    }

    public void Dispose()
    {
        foreach (var value in strings)
        {
            Marshal.FreeCoTaskMem(value);
        }
        Marshal.FreeHGlobal(Pointer);
    }
}
