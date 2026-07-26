using System.Globalization;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Semantics;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private IReadOnlyList<BoundFunction> NativeFunctions() => _program.Functions.Values
        .Where(static function => function.Kind == BoundFunctionKind.Native && function.Com is null)
        .GroupBy(static function => function.Name, StringComparer.Ordinal)
        .Select(static group => group.First())
        .OrderBy(static function => function.Name, StringComparer.Ordinal)
        .ToArray();

    private IReadOnlyList<BoundStructDefinition> NativeHandleTypes() => _program.Types.Structs
        .Where(static structure => structure.NativeHandle is not null)
        .OrderBy(static structure => structure.Name, StringComparer.Ordinal)
        .ToArray();

    private IReadOnlyList<string> NativeLibraries() => NativeFunctions()
        .Select(static function => function.NativeLibrary!)
        .Concat(NativeHandleTypes().Select(static structure => structure.NativeHandle!.Library))
        .Distinct(StringComparer.Ordinal)
        .Order(StringComparer.Ordinal)
        .ToArray();

    private bool UsesNativeInterop => _program.Functions.Values.Any(
        static function => function.Kind == BoundFunctionKind.Native && function.Com is null)
        || NativeHandleTypes().Count > 0;

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
        foreach (var structure in NativeHandleTypes())
        {
            var symbol = structure.NativeHandle!.DropSymbol;
            var bytes = System.Text.Encoding.UTF8.GetBytes(symbol + "\0");
            EmitGlobalLine(
                $"{NativeHandleDropSymbolNameGlobal(structure)} = private unnamed_addr constant "
                + $"[{bytes.Length.ToString(CultureInfo.InvariantCulture)} x i8] "
                + $"c\"{EscapeLlvmBytes(bytes)}\", align 1");
            EmitGlobalLine(
                $"{NativeHandleDropPointerGlobal(structure)} = internal global ptr null, align 8");
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
        foreach (var structure in NativeHandleTypes())
        {
            var library = structure.NativeHandle!.Library;
            var handle = NextTemp("native_handle_library");
            EmitLoad(handle, "ptr", NativeLibraryHandleGlobal(library), 8);
            var address = NextTemp("native_handle_drop_symbol");
            if (_platform is WindowsLlvmRuntimePlatform)
            {
                EmitCall(
                    address,
                    "ptr",
                    "GetProcAddress",
                    $"ptr {handle}, ptr {NativeHandleDropSymbolNameGlobal(structure)}");
            }
            else
            {
                EmitCall(
                    address,
                    "ptr",
                    "dlsym",
                    $"ptr {handle}, ptr {NativeHandleDropSymbolNameGlobal(structure)}");
            }
            EmitTrapIfNull(address, "native_handle_drop_symbol_load");
            EmitStore("ptr", address, NativeHandleDropPointerGlobal(structure), 8);
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
        if (function.Com is not null)
        {
            return EmitComFunctionCall(function, argument, additionalArguments);
        }
        var address = NextTemp("native_target");
        EmitLoad(address, "ptr", NativeFunctionPointerGlobal(function), 8);
        if (UsesNativeAggregateAbi(function))
        {
            return EmitNativeAggregateFunctionCall(function, argument, additionalArguments, address);
        }
        var arguments = string.Join(
            ", ",
            NativeAggregateCallArguments(function, argument, additionalArguments, hasIndirectResult: false));
        var returnType = NativeScalarReturnType(function.ReturnType);
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
                : _program.Types.IsStruct(function.ReturnType)
                    ? new RuntimeStruct(function.ReturnType, result)
                : throw new SollangException(
                    $"native result type '{function.ReturnType}' is not implemented");
    }

    private bool UsesNativeAggregateAbi(BoundFunction function)
    {
        if (_program.Types.IsStruct(function.ReturnType))
        {
            return true;
        }
        if (function.InputType is { } input
            && function.InputOwnership != BoundFunctionInputOwnership.MutableBorrow
            && _program.Types.IsStruct(input))
        {
            return true;
        }
        return (function.AdditionalParameters ?? []).Any(parameter =>
            parameter.Ownership != BoundFunctionInputOwnership.MutableBorrow
            && _program.Types.IsStruct(parameter.Type));
    }

    private RuntimeValue EmitNativeAggregateFunctionCall(
        BoundFunction function,
        RuntimeValue? argument,
        IReadOnlyList<RuntimeValue>? additionalArguments,
        string address)
    {
        var resultPlan = _program.Types.IsStruct(function.ReturnType)
            ? NativeAggregatePlan(function.ReturnType)
            : null;
        var arguments = NativeAggregateCallArguments(
            function,
            argument,
            additionalArguments,
            resultPlan?.IsIndirect == true);
        if (!_program.Types.IsStruct(function.ReturnType))
        {
            var returnType = NativeScalarReturnType(function.ReturnType);
            if (function.ReturnType == BoundType.Unit)
            {
                EmitIndirectCall(target: null, "void", address, string.Join(", ", arguments));
                return RuntimeUnit.Instance;
            }

            var scalarResult = NextTemp("native_result");
            EmitIndirectCall(scalarResult, returnType, address, string.Join(", ", arguments));
            return IsIntegerType(function.ReturnType)
                ? new RuntimeInt(function.ReturnType, scalarResult)
                : new RuntimeFloat(function.ReturnType, scalarResult);
        }

        resultPlan ??= NativeAggregatePlan(function.ReturnType);
        if (resultPlan.IsIndirect)
        {
            var resultPointer = NextTemp("native_sret");
            var structType = LlvmStructType(function.ReturnType);
            var alignment = RuntimeAlignment(function.ReturnType);
            EmitAlloca(resultPointer, structType, alignment);
            arguments.Insert(0, $"ptr sret({structType}) align {alignment.ToString(CultureInfo.InvariantCulture)} {resultPointer}");
            EmitIndirectCall(target: null, "void", address, string.Join(", ", arguments));
            var loaded = NextTemp("native_result");
            EmitLoad(loaded, structType, resultPointer, alignment);
            return ValidateNativeHandleResult(
                new RuntimeStruct(function.ReturnType, loaded));
        }

        var coercionType = AggregateCoercionReturnType(resultPlan);
        var coercedResult = NextTemp("native_result");
        EmitIndirectCall(coercedResult, coercionType, address, string.Join(", ", arguments));
        return ValidateNativeHandleResult(
            UnpackNativeAggregateResult(function.ReturnType, resultPlan, coercedResult));
    }

    private RuntimeStruct ValidateNativeHandleResult(RuntimeStruct result)
    {
        var structure = _program.Types.GetStruct(result.Type);
        if (structure.NativeHandle is null)
        {
            return result;
        }
        var handle = NextTemp("native_handle_result");
        EmitAssign(handle, $"extractvalue {LlvmStructType(result.Type)} {result.ValueName}, 0");
        var valid = NextTemp("native_handle_result_valid");
        EmitCompare(valid, "ne", "i64", handle, "0");
        EmitTrapUnless(valid, "native_handle_constructor");
        return result;
    }

    private List<string> NativeAggregateCallArguments(
        BoundFunction function,
        RuntimeValue? argument,
        IReadOnlyList<RuntimeValue>? additionalArguments,
        bool hasIndirectResult)
    {
        var result = new List<string>();
        var registers = _platform is LinuxLlvmRuntimePlatform
            ? new NativeAbiRegisterState(hasIndirectResult ? 1 : 0, 0)
            : null;
        if (function.InputType is { } inputType)
        {
            if (argument is null)
            {
                throw new SollangException($"function '{function.Name}' expects exactly one argument");
            }
            AppendNativeArgument(
                result,
                function.Name,
                function.InputName ?? "input",
                inputType,
                function.InputOwnership,
                argument,
                registers);
        }
        else if (argument is not null)
        {
            throw new SollangException($"function '{function.Name}' does not accept arguments");
        }

        var parameters = function.AdditionalParameters ?? [];
        additionalArguments ??= [];
        if (additionalArguments.Count != parameters.Count)
        {
            throw new SollangException(
                $"function '{function.Name}' expects {parameters.Count} additional argument(s)");
        }
        for (var index = 0; index < parameters.Count; index++)
        {
            var parameter = parameters[index];
            AppendNativeArgument(
                result,
                function.Name,
                parameter.Name,
                parameter.Type,
                parameter.Ownership,
                additionalArguments[index],
                registers);
        }
        return result;
    }

    private void AppendNativeArgument(
        List<string> arguments,
        string functionName,
        string parameterName,
        BoundType type,
        BoundFunctionInputOwnership ownership,
        RuntimeValue value,
        NativeAbiRegisterState? registers)
    {
        EnsureFunctionArgumentRuntimeType(value, type, functionName);
        if (ownership == BoundFunctionInputOwnership.MutableBorrow)
        {
            if (value is not RuntimeMutableStructReference mutable)
            {
                throw new SollangException(
                    $"function '{functionName}' parameter '{parameterName}' requires a mutable borrow");
            }
            arguments.Add($"ptr {mutable.PointerAddress}");
            registers?.ConsumeInteger();
            return;
        }
        if (_program.Types.IsReference(type))
        {
            if (value is not RuntimeReference reference || reference.Type != type)
            {
                throw new SollangException(
                    $"function '{functionName}' parameter '{parameterName}' requires {type}");
            }
            arguments.Add($"ptr {reference.PointerName}");
            registers?.ConsumeInteger();
            return;
        }
        if (_program.Types.IsStruct(type))
        {
            AppendNativeAggregateValue(arguments, type, value, registers);
            return;
        }

        var materialized = MaterializeAggregateValue(value);
        var extension = NativeScalarExtension(type);
        arguments.Add(
            $"{materialized.TypeName} "
            + (extension.Length == 0 ? "" : extension + " ")
            + materialized.ValueName);
        if (IsFloatType(type))
        {
            registers?.ConsumeSse();
        }
        else
        {
            registers?.ConsumeInteger();
        }
    }

    private void AppendNativeAggregateValue(
        List<string> arguments,
        BoundType type,
        RuntimeValue value,
        NativeAbiRegisterState? registers)
    {
        var materialized = MaterializeAggregateValue(value);
        var plan = NativeAggregatePlan(type, registers);
        if (plan.IsIndirect)
        {
            var pointer = NextTemp("native_byval");
            var alignment = _platform is WindowsLlvmRuntimePlatform
                ? 16
                : RuntimeAlignment(type);
            EmitAlloca(pointer, materialized.TypeName, alignment);
            EmitStore(materialized.TypeName, materialized.ValueName, pointer, alignment);
            arguments.Add(_platform is WindowsLlvmRuntimePlatform
                ? $"ptr {pointer}"
                : $"ptr byval({materialized.TypeName}) align {alignment.ToString(CultureInfo.InvariantCulture)} {pointer}");
            return;
        }

        var scratch = CreateNativeAggregateScratch(type, materialized);
        for (var index = 0; index < plan.CoercionTypes.Count; index++)
        {
            var pointer = NativeAggregateScratchAddress(scratch, index);
            var coercionType = plan.CoercionTypes[index];
            var loaded = NextTemp("native_arg");
            EmitLoad(loaded, coercionType, pointer, NativeCoercionAlignment(coercionType));
            arguments.Add($"{coercionType} {loaded}");
        }
    }

    private RuntimeStruct UnpackNativeAggregateResult(
        BoundType type,
        NativeAggregateAbiPlan plan,
        string coercedResult)
    {
        var scratch = NextTemp("native_result_storage");
        EmitAlloca(scratch, "[2 x i64]", 8);
        EmitStore("[2 x i64]", "zeroinitializer", scratch, 8);
        for (var index = 0; index < plan.CoercionTypes.Count; index++)
        {
            var coercionType = plan.CoercionTypes[index];
            var value = coercedResult;
            if (plan.CoercionTypes.Count > 1)
            {
                value = NextTemp("native_result_part");
                EmitAssign(
                    value,
                    $"extractvalue {AggregateCoercionReturnType(plan)} {coercedResult}, {index.ToString(CultureInfo.InvariantCulture)}");
            }
            var pointer = NativeAggregateScratchAddress(scratch, index);
            EmitStore(coercionType, value, pointer, NativeCoercionAlignment(coercionType));
        }

        var result = NextTemp("native_result_value");
        EmitLoad(result, LlvmStructType(type), scratch, RuntimeAlignment(type));
        return new RuntimeStruct(type, result);
    }

    private string CreateNativeAggregateScratch(
        BoundType type,
        (string TypeName, string ValueName) materialized)
    {
        var scratch = NextTemp("native_arg_storage");
        EmitAlloca(scratch, "[2 x i64]", 8);
        EmitStore("[2 x i64]", "zeroinitializer", scratch, 8);
        EmitStore(materialized.TypeName, materialized.ValueName, scratch, RuntimeAlignment(type));
        return scratch;
    }

    private string NativeAggregateScratchAddress(string scratch, int index)
    {
        if (index == 0)
        {
            return scratch;
        }
        var pointer = NextTemp("native_eightbyte");
        EmitAssign(pointer, $"getelementptr i8, ptr {scratch}, i64 {(index * 8).ToString(CultureInfo.InvariantCulture)}");
        return pointer;
    }

    private NativeAggregateAbiPlan NativeAggregatePlan(
        BoundType type,
        NativeAbiRegisterState? registers = null)
    {
        var size = _program.Types.InlineSizeOf(type);
        if (_platform is WindowsLlvmRuntimePlatform)
        {
            return size is 1 or 2 or 4 or 8
                ? new NativeAggregateAbiPlan(false, [$"i{size * 8}"])
                : new NativeAggregateAbiPlan(true, []);
        }
        if (size > 16)
        {
            return new NativeAggregateAbiPlan(true, []);
        }

        var classes = new NativeEightbyteClass[(size + 7) / 8];
        var meaningfulEnds = new int[classes.Length];
        var hasFloat64 = new bool[classes.Length];
        ClassifySysVFields(type, 0, classes, meaningfulEnds, hasFloat64);
        if (classes.Any(static value => value == NativeEightbyteClass.Memory))
        {
            return new NativeAggregateAbiPlan(true, []);
        }

        var coercions = new string[classes.Length];
        for (var index = 0; index < classes.Length; index++)
        {
            var bytes = Math.Clamp(meaningfulEnds[index] - index * 8, 1, 8);
            coercions[index] = classes[index] switch
            {
                NativeEightbyteClass.Sse when hasFloat64[index] => "double",
                NativeEightbyteClass.Sse when bytes <= 4 => "float",
                NativeEightbyteClass.Sse => "<2 x float>",
                _ => $"i{RoundIntegerAbiBits(bytes)}"
            };
        }
        if (registers is not null)
        {
            var integerCount = classes.Count(static value => value == NativeEightbyteClass.Integer);
            var sseCount = classes.Count(static value => value == NativeEightbyteClass.Sse);
            if (!registers.CanConsume(integerCount, sseCount))
            {
                return new NativeAggregateAbiPlan(true, []);
            }
            registers.Consume(integerCount, sseCount);
        }
        return new NativeAggregateAbiPlan(false, coercions);
    }

    private void ClassifySysVFields(
        BoundType type,
        int baseOffset,
        NativeEightbyteClass[] classes,
        int[] meaningfulEnds,
        bool[] hasFloat64)
    {
        var structure = _program.Types.GetStruct(type);
        foreach (var field in structure.Fields)
        {
            var offset = baseOffset + _program.Types.FieldOffsetOf(type, field.Index);
            if (_program.Types.IsStruct(field.Type))
            {
                ClassifySysVFields(field.Type, offset, classes, meaningfulEnds, hasFloat64);
                continue;
            }

            var size = _program.Types.InlineSizeOf(field.Type);
            var alignment = _program.Types.AlignmentOf(field.Type);
            if (offset % alignment != 0 || offset / 8 != (offset + size - 1) / 8)
            {
                classes[offset / 8] = NativeEightbyteClass.Memory;
                continue;
            }
            var index = offset / 8;
            var next = field.Type is BoundType.Float32 or BoundType.Float64
                ? NativeEightbyteClass.Sse
                : NativeEightbyteClass.Integer;
            classes[index] = MergeNativeEightbyteClass(classes[index], next);
            meaningfulEnds[index] = Math.Max(meaningfulEnds[index], offset + size);
            hasFloat64[index] |= field.Type == BoundType.Float64;
        }
    }

    private static NativeEightbyteClass MergeNativeEightbyteClass(
        NativeEightbyteClass left,
        NativeEightbyteClass right)
    {
        if (left == NativeEightbyteClass.Memory || right == NativeEightbyteClass.Memory)
        {
            return NativeEightbyteClass.Memory;
        }
        if (left == NativeEightbyteClass.Integer || right == NativeEightbyteClass.Integer)
        {
            return NativeEightbyteClass.Integer;
        }
        return right == NativeEightbyteClass.None ? left : right;
    }

    private static int RoundIntegerAbiBits(int bytes) => bytes switch
    {
        <= 1 => 8,
        <= 2 => 16,
        <= 4 => 32,
        _ => 64
    };

    private static int NativeCoercionAlignment(string type) =>
        type is "i8" ? 1 : type is "i16" ? 2 : type is "i32" or "float" ? 4 : 8;

    private string NativeScalarReturnType(BoundType type)
    {
        var llvmType = LlvmType(type);
        var extension = NativeScalarExtension(type);
        return extension.Length == 0 ? llvmType : extension + " " + llvmType;
    }

    private static string NativeScalarExtension(BoundType type) => type switch
    {
        BoundType.Int8 or BoundType.Int16 => "signext",
        BoundType.UInt8 or BoundType.UInt16 => "zeroext",
        _ => ""
    };

    private static string AggregateCoercionReturnType(NativeAggregateAbiPlan plan) =>
        plan.CoercionTypes.Count == 1
            ? plan.CoercionTypes[0]
            : "{ " + string.Join(", ", plan.CoercionTypes) + " }";

    private enum NativeEightbyteClass
    {
        None,
        Integer,
        Sse,
        Memory
    }

    private sealed record NativeAggregateAbiPlan(
        bool IsIndirect,
        IReadOnlyList<string> CoercionTypes);

    private sealed class NativeAbiRegisterState(int integerCount, int sseCount)
    {
        private int IntegerCount { get; set; } = integerCount;
        private int SseCount { get; set; } = sseCount;

        public bool CanConsume(int integers, int sse) =>
            IntegerCount + integers <= 6 && SseCount + sse <= 8;

        public void Consume(int integers, int sse)
        {
            IntegerCount = Math.Min(IntegerCount + integers, 6);
            SseCount = Math.Min(SseCount + sse, 8);
        }

        public void ConsumeInteger() => Consume(1, 0);

        public void ConsumeSse() => Consume(0, 1);
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

    private static string NativeHandleDropSymbolNameGlobal(BoundStructDefinition structure) =>
        $"@.slg.native.handle.drop.name.{NativeStableId(structure.Name)}";

    private static string NativeHandleDropPointerGlobal(BoundStructDefinition structure) =>
        $"@sollang_native_handle_drop_{NativeStableId(structure.Name)}";

    private static string NativeStableId(string value) =>
        LlvmCodegenUnit.StableIdentity(value).ToString("x16", CultureInfo.InvariantCulture);
}
