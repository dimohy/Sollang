using System.Globalization;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Semantics;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private IReadOnlyList<BoundFunction> NativeFunctions() => _program.Functions.Values
        .Where(static function => function.Kind == BoundFunctionKind.Native)
        .GroupBy(static function => function.Name, StringComparer.Ordinal)
        .Select(static group => group.First())
        .OrderBy(static function => function.Name, StringComparer.Ordinal)
        .ToArray();

    private IReadOnlyList<string> NativeLibraries() => NativeFunctions()
        .Select(static function => function.NativeLibrary!)
        .Distinct(StringComparer.Ordinal)
        .Order(StringComparer.Ordinal)
        .ToArray();

    private bool UsesNativeInterop => _program.Functions.Values.Any(
        static function => function.Kind == BoundFunctionKind.Native);

    private void EmitNativeGlobals()
    {
        if (!UsesNativeInterop)
        {
            return;
        }
        if (_platform is WasmBrowserLlvmRuntimePlatform)
        {
            throw new SollangException("native libraries are unavailable for wasm32-browser");
        }

        foreach (var library in NativeLibraries())
        {
            var fileName = NativeLibraryFileName(library);
            var bytes = System.Text.Encoding.UTF8.GetBytes(fileName + "\0");
            EmitGlobalLine(
                $"{NativeLibraryNameGlobal(library)} = private unnamed_addr constant "
                + $"[{bytes.Length.ToString(CultureInfo.InvariantCulture)} x i8] "
                + $"c\"{EscapeLlvmBytes(bytes)}\", align 1");
            EmitGlobalLine($"{NativeLibraryHandleGlobal(library)} = internal global ptr null, align 8");
        }

        foreach (var function in NativeFunctions())
        {
            var symbol = function.NativeSymbol
                ?? throw new SollangException($"native function '{function.Name}' has no symbol");
            var bytes = System.Text.Encoding.UTF8.GetBytes(symbol + "\0");
            EmitGlobalLine(
                $"{NativeSymbolNameGlobal(function)} = private unnamed_addr constant "
                + $"[{bytes.Length.ToString(CultureInfo.InvariantCulture)} x i8] "
                + $"c\"{EscapeLlvmBytes(bytes)}\", align 1");
            EmitGlobalLine($"{NativeFunctionPointerGlobal(function)} = internal global ptr null, align 8");
        }
    }

    private void EmitNativeDeclarations()
    {
        if (!UsesNativeInterop)
        {
            return;
        }

        if (_platform is WindowsLlvmRuntimePlatform)
        {
            EmitFunctionLine("declare dllimport ptr @LoadLibraryA(ptr)");
            EmitFunctionLine("declare dllimport ptr @GetProcAddress(ptr, ptr)");
            EmitFunctionLine("declare dllimport i32 @FreeLibrary(ptr)");
        }
        else if (_platform is LinuxLlvmRuntimePlatform)
        {
            EmitFunctionLine("declare ptr @dlopen(ptr, i32)");
            EmitFunctionLine("declare ptr @dlsym(ptr, ptr)");
            EmitFunctionLine("declare i32 @dlclose(ptr)");
        }
        else
        {
            throw new SollangException("native libraries are unavailable for this target");
        }
    }

    private void EmitNativeBinding()
    {
        if (!UsesNativeInterop)
        {
            return;
        }

        foreach (var library in NativeLibraries())
        {
            var handle = NextTemp("native_library");
            if (_platform is WindowsLlvmRuntimePlatform)
            {
                EmitCall(handle, "ptr", "LoadLibraryA", $"ptr {NativeLibraryNameGlobal(library)}");
            }
            else
            {
                EmitCall(handle, "ptr", "dlopen", $"ptr {NativeLibraryNameGlobal(library)}, i32 2");
            }
            EmitTrapIfNull(handle, "native_library_load");
            EmitStore("ptr", handle, NativeLibraryHandleGlobal(library), 8);
        }

        foreach (var function in NativeFunctions())
        {
            var library = function.NativeLibrary!;
            var handle = NextTemp("native_library_handle");
            EmitLoad(handle, "ptr", NativeLibraryHandleGlobal(library), 8);
            var address = NextTemp("native_symbol");
            if (_platform is WindowsLlvmRuntimePlatform)
            {
                EmitCall(
                    address,
                    "ptr",
                    "GetProcAddress",
                    $"ptr {handle}, ptr {NativeSymbolNameGlobal(function)}");
            }
            else
            {
                EmitCall(
                    address,
                    "ptr",
                    "dlsym",
                    $"ptr {handle}, ptr {NativeSymbolNameGlobal(function)}");
            }
            EmitTrapIfNull(address, "native_symbol_load");
            EmitStore("ptr", address, NativeFunctionPointerGlobal(function), 8);
        }
    }

    private void EmitNativeCleanup()
    {
        if (!UsesNativeInterop)
        {
            return;
        }

        foreach (var library in NativeLibraries().Reverse())
        {
            var handle = NextTemp("native_library_close");
            EmitLoad(handle, "ptr", NativeLibraryHandleGlobal(library), 8);
            if (_platform is WindowsLlvmRuntimePlatform)
            {
                EmitCall(NextTemp("native_library_closed"), "i32", "FreeLibrary", $"ptr {handle}");
            }
            else
            {
                EmitCall(NextTemp("native_library_closed"), "i32", "dlclose", $"ptr {handle}");
            }
        }
    }

    private RuntimeValue EmitNativeFunctionCall(
        BoundFunction function,
        RuntimeValue? argument,
        IReadOnlyList<RuntimeValue>? additionalArguments)
    {
        var address = NextTemp("native_target");
        EmitLoad(address, "ptr", NativeFunctionPointerGlobal(function), 8);
        var arguments = ExplicitFunctionCallArgumentList(function, argument, additionalArguments);
        var returnType = LlvmType(function.ReturnType);
        if (function.ReturnType == BoundType.Unit)
        {
            EmitIndirectCall(target: null, "void", address, arguments);
            return RuntimeUnit.Instance;
        }

        var result = NextTemp("native_result");
        EmitIndirectCall(result, returnType, address, arguments);
        return IsIntegerType(function.ReturnType)
            ? new RuntimeInt(function.ReturnType, result)
            : IsFloatType(function.ReturnType)
                ? new RuntimeFloat(function.ReturnType, result)
                : throw new SollangException(
                    $"native result type '{function.ReturnType}' is not implemented");
    }

    private void EmitTrapIfNull(string pointer, string prefix)
    {
        var found = NextTemp(prefix + "_found");
        EmitCompare(found, "ne", "ptr", pointer, "null");
        EmitTrapUnless(found, prefix);
    }

    private string NativeLibraryFileName(string library)
    {
        if (_platform is WindowsLlvmRuntimePlatform)
        {
            return library.EndsWith(".dll", StringComparison.OrdinalIgnoreCase)
                ? library
                : library + ".dll";
        }

        if (library.EndsWith(".so", StringComparison.Ordinal))
        {
            return library;
        }
        var separator = library.LastIndexOfAny(['/', '\\']);
        var prefix = separator >= 0 ? library[..(separator + 1)] : "";
        var name = separator >= 0 ? library[(separator + 1)..] : library;
        return prefix + (name.StartsWith("lib", StringComparison.Ordinal) ? name : "lib" + name) + ".so";
    }

    private static string NativeLibraryNameGlobal(string library) =>
        $"@.slg.native.library.name.{NativeStableId(library)}";

    private static string NativeLibraryHandleGlobal(string library) =>
        $"@sollang_native_library_{NativeStableId(library)}";

    private static string NativeSymbolNameGlobal(BoundFunction function) =>
        $"@.slg.native.symbol.name.{NativeStableId(function.Name)}";

    private static string NativeFunctionPointerGlobal(BoundFunction function) =>
        $"@sollang_native_function_{NativeStableId(function.Name)}";

    private static string NativeStableId(string value) =>
        LlvmCodegenUnit.StableIdentity(value).ToString("x16", CultureInfo.InvariantCulture);
}
