using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Sollang.Compiler.CodeGen;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Semantics;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.Cli;

internal sealed record SollangLibraryParameter(string Name, string Type);

internal sealed record SollangLibraryExport(
    string Name,
    string QualifiedName,
    string Symbol,
    IReadOnlyList<SollangLibraryParameter> Parameters,
    string Result,
    string SignatureHash);

internal sealed record SollangLibraryManifestDocument(
    int Schema,
    string Abi,
    string Target,
    string LibraryFile,
    string AbiHash,
    IReadOnlyList<SollangLibraryExport> Exports);

internal static class SollangLibraryManifest
{
    public const int CurrentSchema = 1;
    public const string CurrentAbi = "sollang-c-v1";

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow
    };

    public static SollangLibraryManifestDocument Create(
        SollangProgram syntax,
        BoundProgram bound,
        CompilationTarget target,
        string outputPath)
    {
        var declarations = syntax.Functions
            .Where(static function =>
                function.IsPublic
                && !function.IsStandardLibrary
                && function.NativeLibrary is null)
            .OrderBy(static function => function.Name, StringComparer.Ordinal)
            .ToArray();
        if (declarations.Length == 0)
        {
            throw new SollangException(
                "a Sollang shared library must declare at least one public function");
        }

        var exports = new List<SollangLibraryExport>(declarations.Length);
        var boundExports = declarations
            .Select(declaration => bound.Functions.TryGetValue(declaration.Name, out var function)
                ? function
                : throw new SollangException(
                    $"public library function '{declaration.Name}' was not bound"))
            .ToArray();
        var abiHash = LlvmEmitter.LibraryAbiHash(boundExports);
        var memberNames = new HashSet<string>(StringComparer.Ordinal);
        for (var index = 0; index < declarations.Length; index++)
        {
            var declaration = declarations[index];
            var function = boundExports[index];

            ValidateDeclaration(declaration, function);
            var memberName = declaration.Name[(declaration.Name.LastIndexOf('.') + 1)..];
            if (!memberNames.Add(memberName))
            {
                throw new SollangException(
                    $"library member name collision for '{memberName}'");
            }

            var parameters = Parameters(declaration);
            var symbol = LlvmEmitter.LibraryExportSymbol(function, abiHash);
            var signature = Signature(memberName, symbol, parameters, declaration.ReturnType);
            exports.Add(new SollangLibraryExport(
                memberName,
                declaration.Name,
                symbol,
                parameters,
                declaration.ReturnType,
                Hash(signature)));
        }

        var ordered = exports.OrderBy(static export => export.QualifiedName, StringComparer.Ordinal).ToArray();
        return new SollangLibraryManifestDocument(
            CurrentSchema,
            CurrentAbi,
            TargetName(target),
            Path.GetFileName(outputPath),
            abiHash,
            ordered);
    }

    public static void Write(string outputPath, SollangLibraryManifestDocument document)
    {
        var path = PathForOutput(outputPath, document.Target);
        var directory = Path.GetDirectoryName(path)
            ?? throw new InvalidOperationException("library manifest path has no directory");
        Directory.CreateDirectory(directory);
        var bytes = JsonSerializer.SerializeToUtf8Bytes(document, JsonOptions);
        var temporaryPath = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            using (var stream = new FileStream(
                       temporaryPath,
                       FileMode.CreateNew,
                       FileAccess.Write,
                       FileShare.None,
                       bufferSize: 16 * 1024,
                       FileOptions.WriteThrough))
            {
                stream.Write(bytes);
                stream.WriteByte((byte)'\n');
                stream.Flush(flushToDisk: true);
            }
            File.Move(temporaryPath, path, overwrite: true);
        }
        finally
        {
            if (File.Exists(temporaryPath))
            {
                File.Delete(temporaryPath);
            }
        }
    }

    public static (IReadOnlyList<FunctionDeclaration> Functions, CompilationInput Input) Load(
        NativeLibraryImport import,
        string sourcePath,
        CompilationTarget target)
    {
        var sourceDirectory = Path.GetDirectoryName(sourcePath)
            ?? Directory.GetCurrentDirectory();
        var libraryBase = Path.GetFullPath(import.Library, sourceDirectory);
        var runtimeLibrary = RuntimeLibraryPath(libraryBase, target);
        var manifestPath = libraryBase + "." + TargetName(target) + ".slglib.json";
        if (!File.Exists(manifestPath))
        {
            throw new SollangException(
                $"{import.Line}:{import.Column}: Sollang library interface not found: {manifestPath}");
        }

        byte[] bytes;
        SollangLibraryManifestDocument document;
        try
        {
            bytes = File.ReadAllBytes(manifestPath);
            document = JsonSerializer.Deserialize<SollangLibraryManifestDocument>(bytes, JsonOptions)
                ?? throw new InvalidDataException("document is empty");
        }
        catch (Exception error) when (error is IOException or JsonException or InvalidDataException)
        {
            throw new SollangException(
                $"{import.Line}:{import.Column}: invalid Sollang library interface "
                + $"'{manifestPath}': {error.Message}");
        }

        ValidateDocument(document, target, manifestPath);
        var names = new HashSet<string>(StringComparer.Ordinal);
        var functions = new List<FunctionDeclaration>(document.Exports.Count);
        foreach (var export in document.Exports)
        {
            ValidateExport(export, manifestPath);
            if (!names.Add(export.Name))
            {
                throw new SollangException(
                    $"duplicate Sollang library member '{export.Name}' in '{manifestPath}'");
            }

            var first = export.Parameters.Count == 0 ? null : export.Parameters[0];
            var additional = export.Parameters.Skip(1)
                .Select(parameter => new FunctionParameterDeclaration(
                    parameter.Name,
                    parameter.Type,
                    FunctionInputOwnership.Default,
                    import.Line,
                    import.Column))
                .ToArray();
            functions.Add(new FunctionDeclaration(
                import.Alias + "." + export.Name,
                first?.Name,
                first?.Type,
                FunctionInputOwnership.Default,
                export.Result,
                BlockInputName: null,
                BlockInputType: null,
                LocalFunctions: [],
                Body: null,
                BlockBody: [],
                import.Line,
                import.Column,
                IsIntrinsic: false,
                IsStandardLibrary: false,
                AdditionalParameters: additional,
                NativeLibrary: runtimeLibrary,
                NativeSymbol: export.Symbol));
        }
        return (functions, new CompilationInput(manifestPath, bytes));
    }

    public static string PathForOutput(string outputPath, string target)
    {
        var directory = Path.GetDirectoryName(outputPath) ?? Directory.GetCurrentDirectory();
        var name = Path.GetFileNameWithoutExtension(outputPath);
        if (Path.GetExtension(outputPath).Equals(".so", StringComparison.OrdinalIgnoreCase)
            && name.StartsWith("lib", StringComparison.Ordinal)
            && name.Length > 3)
        {
            name = name[3..];
        }
        return Path.Combine(directory, name + "." + target + ".slglib.json");
    }

    public static string PathForOutput(string outputPath, CompilationTarget target) =>
        PathForOutput(outputPath, TargetName(target));

    public static void PublishCache(
        IncrementalCacheLocation location,
        string outputPath,
        CompilationTarget target)
    {
        CopyAtomically(PathForOutput(outputPath, target), CachePath(location));
    }

    public static void RestoreCache(
        IncrementalCacheLocation location,
        string outputPath,
        CompilationTarget target)
    {
        var cachedPath = CachePath(location);
        if (!File.Exists(cachedPath))
        {
            throw new SollangException(
                $"cached Sollang library interface is missing: {cachedPath}");
        }
        CopyAtomically(cachedPath, PathForOutput(outputPath, target));
    }

    internal static string CachePath(IncrementalCacheLocation location) =>
        location.ProductPath + ".slglib.json";

    private static void CopyAtomically(string sourcePath, string destinationPath)
    {
        if (File.Exists(destinationPath) && FilesEqual(sourcePath, destinationPath))
        {
            return;
        }
        var directory = Path.GetDirectoryName(destinationPath)
            ?? throw new InvalidOperationException("library interface path has no directory");
        Directory.CreateDirectory(directory);
        var temporaryPath = destinationPath + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            File.Copy(sourcePath, temporaryPath, overwrite: false);
            File.Move(temporaryPath, destinationPath, overwrite: true);
        }
        finally
        {
            if (File.Exists(temporaryPath))
            {
                File.Delete(temporaryPath);
            }
        }
    }

    private static bool FilesEqual(string leftPath, string rightPath)
    {
        var leftInfo = new FileInfo(leftPath);
        var rightInfo = new FileInfo(rightPath);
        if (leftInfo.Length != rightInfo.Length)
        {
            return false;
        }
        using var left = new FileStream(
            leftPath,
            FileMode.Open,
            FileAccess.Read,
            FileShare.Read,
            bufferSize: 16 * 1024,
            FileOptions.SequentialScan);
        using var right = new FileStream(
            rightPath,
            FileMode.Open,
            FileAccess.Read,
            FileShare.Read,
            bufferSize: 16 * 1024,
            FileOptions.SequentialScan);
        Span<byte> leftBytes = stackalloc byte[16 * 1024];
        Span<byte> rightBytes = stackalloc byte[leftBytes.Length];
        while (true)
        {
            var leftCount = left.Read(leftBytes);
            var rightCount = right.Read(rightBytes);
            if (leftCount != rightCount
                || !leftBytes[..leftCount].SequenceEqual(rightBytes[..rightCount]))
            {
                return false;
            }
            if (leftCount == 0)
            {
                return true;
            }
        }
    }

    private static void ValidateDeclaration(
        FunctionDeclaration declaration,
        BoundFunction function)
    {
        ValidateAbiType(declaration.InputType, declaration.Name, "input");
        foreach (var parameter in declaration.AdditionalParameters ?? [])
        {
            ValidateAbiType(parameter.TypeName, declaration.Name, $"parameter '{parameter.Name}'");
        }
        ValidateAbiType(declaration.ReturnType, declaration.Name, "result");
        if (function.Effects is { Count: > 0 })
        {
            throw new SollangException(
                $"public library function '{declaration.Name}' must not require effects");
        }
    }

    private static void ValidateAbiType(string? type, string function, string role)
    {
        if (type is null or "Unit"
            or "Int8" or "Int16" or "Int32" or "Int64"
            or "UInt8" or "UInt16" or "UInt32" or "UInt64"
            or "Float32" or "Float64")
        {
            return;
        }
        throw new SollangException(
            $"public library function '{function}' {role} type '{type}' is not ABI-safe; "
            + "use Unit or a fixed-width numeric scalar");
    }

    private static IReadOnlyList<SollangLibraryParameter> Parameters(FunctionDeclaration function)
    {
        var parameters = new List<SollangLibraryParameter>();
        if (function.InputType is not null)
        {
            parameters.Add(new SollangLibraryParameter(function.InputName ?? "value", function.InputType));
        }
        parameters.AddRange((function.AdditionalParameters ?? [])
            .Select(static parameter => new SollangLibraryParameter(parameter.Name, parameter.TypeName)));
        return parameters;
    }

    private static void ValidateDocument(
        SollangLibraryManifestDocument document,
        CompilationTarget target,
        string path)
    {
        if (document.Schema != CurrentSchema || document.Abi != CurrentAbi)
        {
            throw new SollangException(
                $"unsupported Sollang library ABI in '{path}': schema {document.Schema}, ABI '{document.Abi}'");
        }
        var expectedTarget = TargetName(target);
        if (document.Target != expectedTarget)
        {
            throw new SollangException(
                $"Sollang library target mismatch in '{path}': expected '{expectedTarget}', "
                + $"found '{document.Target}'");
        }
        if (document.Exports.Count == 0)
        {
            throw new SollangException($"Sollang library interface '{path}' has no exports");
        }
        if (Path.GetFileName(document.LibraryFile) != document.LibraryFile
            || document.LibraryFile.Length == 0)
        {
            throw new SollangException($"invalid library file name in '{path}'");
        }
        var actualAbiHash = Hash(string.Join(
            "\n",
            document.Exports
                .OrderBy(static export => export.QualifiedName, StringComparer.Ordinal)
                .Select(static export =>
                    export.QualifiedName
                    + "\0"
                    + string.Join("\0", export.Parameters.Select(static parameter => parameter.Type))
                    + "\0->"
                    + export.Result)));
        if (!FixedHashEquals(document.AbiHash, actualAbiHash))
        {
            throw new SollangException($"Sollang library ABI hash mismatch in '{path}'");
        }
    }

    private static void ValidateExport(SollangLibraryExport export, string path)
    {
        var qualifiedParts = export.QualifiedName.Split('.');
        if (!IsIdentifier(export.Name)
            || qualifiedParts.Length == 0
            || qualifiedParts.Any(static part => !IsIdentifier(part))
            || qualifiedParts[^1] != export.Name
            || !IsIdentifier(export.Symbol))
        {
            throw new SollangException(
                $"invalid export name, qualified name, or symbol for '{export.Name}' in '{path}'");
        }
        var parameterNames = new HashSet<string>(StringComparer.Ordinal);
        foreach (var parameter in export.Parameters)
        {
            if (!IsIdentifier(parameter.Name) || !parameterNames.Add(parameter.Name))
            {
                throw new SollangException(
                    $"invalid or duplicate parameter name '{parameter.Name}' "
                    + $"for '{export.Name}' in '{path}'");
            }
            ValidateAbiType(parameter.Type, export.QualifiedName, $"parameter '{parameter.Name}'");
        }
        ValidateAbiType(export.Result, export.QualifiedName, "result");
        var signature = Signature(export.Name, export.Symbol, export.Parameters, export.Result);
        if (!FixedHashEquals(export.SignatureHash, Hash(signature)))
        {
            throw new SollangException(
                $"Sollang library signature hash mismatch for '{export.Name}' in '{path}'");
        }
    }

    private static string Signature(
        string name,
        string symbol,
        IReadOnlyList<SollangLibraryParameter> parameters,
        string result) =>
        name + "\0" + symbol + "\0"
        + string.Join("\0", parameters.Select(static parameter => parameter.Name + ":" + parameter.Type))
        + "\0->" + result;

    private static string Hash(string value) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();

    private static bool FixedHashEquals(string declared, string actual)
    {
        if (!IsSha256(declared) || declared.Length != actual.Length)
        {
            return false;
        }
        return CryptographicOperations.FixedTimeEquals(
            Encoding.ASCII.GetBytes(declared),
            Encoding.ASCII.GetBytes(actual));
    }

    private static bool IsSha256(string value) =>
        value.Length == 64
        && value.All(static character =>
            character is >= '0' and <= '9'
            or >= 'a' and <= 'f');

    private static bool IsIdentifier(string value)
    {
        if (value.Length == 0
            || !(char.IsAsciiLetter(value[0]) || value[0] == '_'))
        {
            return false;
        }
        for (var index = 1; index < value.Length; index++)
        {
            if (!(char.IsAsciiLetterOrDigit(value[index]) || value[index] == '_'))
            {
                return false;
            }
        }
        return true;
    }

    private static string TargetName(CompilationTarget target) => target switch
    {
        CompilationTarget.WindowsX64 => "windows-x64",
        CompilationTarget.LinuxX64 => "linux-x64",
        CompilationTarget.Wasm32Browser => "wasm32-browser",
        _ => throw new SollangException($"unsupported target '{target}'")
    };

    private static string RuntimeLibraryPath(string path, CompilationTarget target)
    {
        if (target != CompilationTarget.LinuxX64 || !OperatingSystem.IsWindows())
        {
            return path;
        }
        if (path.Length < 3 || !char.IsAsciiLetter(path[0]) || path[1] != ':')
        {
            throw new SollangException(
                $"cannot map Windows library path '{path}' to the linux-x64 target");
        }
        return "/mnt/"
            + char.ToLowerInvariant(path[0])
            + "/"
            + path[3..].Replace('\\', '/');
    }
}
