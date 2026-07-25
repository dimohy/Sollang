using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Semantics;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private void EmitLibraryExports()
    {
        var exports = _program.Functions.Values
            .Where(static function =>
                function.IsPublic
                && !function.IsStandardLibrary
                && !function.IsLocal)
            .OrderBy(static function => function.Name, StringComparer.Ordinal)
            .ToArray();
        if (exports.Length == 0)
        {
            throw new SollangException(
                "a Sollang shared library must declare at least one public function");
        }

        var symbols = new HashSet<string>(StringComparer.Ordinal);
        var abiHash = LibraryAbiHash(exports);
        foreach (var function in exports)
        {
            ValidateLibraryExport(function);
            var symbol = LibraryExportSymbol(function, abiHash);
            if (!symbols.Add(symbol))
            {
                throw new SollangException(
                    $"library export symbol collision for function '{function.Name}': '{symbol}'");
            }
            EmitLibraryExport(function, symbol);
        }
    }

    private void ValidateLibraryExport(BoundFunction function)
    {
        if (function.Kind != BoundFunctionKind.User
            || function.IsAsync
            || function.GenericParameterName is not null
            || function.BlockInputName is not null
            || function.AdditionalBlockParameters is { Count: > 0 }
            || function.StreamElementType is not null)
        {
            throw new SollangException(
                $"public library function '{function.Name}' must be a synchronous, "
                + "non-generic value function");
        }
        if (_program.FunctionCapturedBindings.TryGetValue(function, out var captures)
            && captures.Count > 0)
        {
            throw new SollangException(
                $"public library function '{function.Name}' cannot capture local state");
        }
        if (function.Effects is { Count: > 0 })
        {
            throw new SollangException(
                $"public library function '{function.Name}' must not require effects");
        }
        if (!IsLibraryAbiType(function.ReturnType))
        {
            throw LibraryAbiError(function, "result", function.ReturnType);
        }
        if (function.InputType is { } inputType)
        {
            if (function.InputOwnership != BoundFunctionInputOwnership.Default
                || !IsLibraryAbiType(inputType))
            {
                throw LibraryAbiError(function, "input", inputType);
            }
        }
        foreach (var parameter in function.AdditionalParameters ?? [])
        {
            if (parameter.Ownership != BoundFunctionInputOwnership.Default
                || !IsLibraryAbiType(parameter.Type))
            {
                throw LibraryAbiError(
                    function,
                    $"parameter '{parameter.Name}'",
                    parameter.Type);
            }
        }
    }

    private static SollangException LibraryAbiError(
        BoundFunction function,
        string role,
        BoundType type) => new(
        $"public library function '{function.Name}' {role} type '{type}' is not ABI-safe; "
        + "use Unit or a fixed-width numeric scalar");

    private static bool IsLibraryAbiType(BoundType type) => type is
        BoundType.Unit
        or BoundType.Int8
        or BoundType.Int16
        or BoundType.Int
        or BoundType.Int64
        or BoundType.UInt8
        or BoundType.UInt16
        or BoundType.UInt32
        or BoundType.UInt64
        or BoundType.Float32
        or BoundType.Float64;

    private void EmitLibraryExport(BoundFunction function, string symbol)
    {
        var returnType = LlvmType(function.ReturnType);
        var storage = _platform is WindowsLlvmRuntimePlatform
            ? "dllexport "
            : "protected ";
        EmitFunctionLine(
            $"define {storage}{returnType} @{symbol}({LibraryExportParameterList(function)}) #0 {{");
        EmitFunctionLine("entry:");
        var callArguments = LibraryExportCallArguments(function);
        if (function.ReturnType == BoundType.Unit)
        {
            EmitFunctionLine(
                $"  call void {SymbolForFunction(function)}({callArguments})");
            EmitFunctionLine("  ret void");
        }
        else
        {
            EmitFunctionLine(
                $"  %result = call {returnType} {SymbolForFunction(function)}({callArguments})");
            EmitFunctionLine($"  ret {returnType} %result");
        }
        EmitFunctionLine("}");
        EmitFunctionLine();
    }

    private string LibraryExportParameterList(BoundFunction function)
    {
        var parameters = new List<string>();
        if (function.InputType is { } inputType)
        {
            parameters.Add($"{LlvmType(inputType)} %it");
        }
        var additional = function.AdditionalParameters ?? [];
        for (var index = 0; index < additional.Count; index++)
        {
            parameters.Add(
                $"{LlvmType(additional[index].Type)} "
                + $"%arg_{index.ToString(CultureInfo.InvariantCulture)}");
        }
        return string.Join(", ", parameters);
    }

    private string LibraryExportCallArguments(BoundFunction function)
    {
        var arguments = new List<string>
        {
            "ptr null",
            "ptr null",
            "ptr null",
            "ptr null",
            "ptr null"
        };
        if (function.InputType is { } inputType)
        {
            arguments.Add($"{LlvmType(inputType)} %it");
        }
        var additional = function.AdditionalParameters ?? [];
        for (var index = 0; index < additional.Count; index++)
        {
            arguments.Add(
                $"{LlvmType(additional[index].Type)} "
                + $"%arg_{index.ToString(CultureInfo.InvariantCulture)}");
        }
        return string.Join(", ", arguments);
    }

    internal static string LibraryExportSymbol(BoundFunction function, string abiHash)
    {
        var result = new StringBuilder("slg_");
        result.Append(abiHash);
        result.Append('_');
        foreach (var character in function.Name)
        {
            result.Append(char.IsAsciiLetterOrDigit(character) ? character : '_');
        }
        return result.ToString();
    }

    internal static string LibraryAbiHash(IEnumerable<BoundFunction> functions)
    {
        var material = string.Join(
            "\n",
            functions
                .OrderBy(static function => function.Name, StringComparer.Ordinal)
                .Select(static function =>
                {
                    var parameters = new List<string>();
                    if (function.InputType is { } inputType)
                    {
                        parameters.Add(LibraryAbiTypeName(inputType));
                    }
                    parameters.AddRange((function.AdditionalParameters ?? [])
                        .Select(static parameter => LibraryAbiTypeName(parameter.Type)));
                    return function.Name
                        + "\0"
                        + string.Join("\0", parameters)
                        + "\0->"
                        + LibraryAbiTypeName(function.ReturnType);
                }));
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(material)))
            .ToLowerInvariant();
    }

    private static string LibraryAbiTypeName(BoundType type) => type switch
    {
        BoundType.Unit => "Unit",
        BoundType.Int8 => "Int8",
        BoundType.Int16 => "Int16",
        BoundType.Int => "Int32",
        BoundType.Int64 => "Int64",
        BoundType.UInt8 => "UInt8",
        BoundType.UInt16 => "UInt16",
        BoundType.UInt32 => "UInt32",
        BoundType.UInt64 => "UInt64",
        BoundType.Float32 => "Float32",
        BoundType.Float64 => "Float64",
        _ => throw new SollangException($"type '{type}' is not a fixed-width library ABI type")
    };
}
