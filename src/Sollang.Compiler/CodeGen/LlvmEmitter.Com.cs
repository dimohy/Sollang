using System.Globalization;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Semantics;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private IReadOnlyList<BoundFunction> ComFunctions() => _program.Functions.Values
        .Where(static function => function.Com is not null)
        .GroupBy(static function => function.Name, StringComparer.Ordinal)
        .Select(static group => group.First())
        .OrderBy(static function => function.Name, StringComparer.Ordinal)
        .ToArray();

    private bool UsesComInterop => _program.Functions.Values.Any(
        static function => function.Com is not null);

    private IReadOnlyList<ComFunctionMetadata> ComInterfaces() => ComFunctions()
        .Select(static function => function.Com!)
        .GroupBy(
            static metadata => metadata.InterfaceType,
            StringComparer.Ordinal)
        .Select(static group => group.First())
        .OrderBy(static metadata => metadata.InterfaceType, StringComparer.Ordinal)
        .ToArray();

    private IReadOnlyList<ComFunctionMetadata> DirectComFactories() => ComInterfaces()
        .Where(static metadata => metadata.Server is not null)
        .GroupBy(
            static metadata => metadata.Server + "\0" + metadata.ClassId,
            StringComparer.Ordinal)
        .Select(static group => group.First())
        .OrderBy(static metadata => metadata.Server, StringComparer.Ordinal)
        .ThenBy(static metadata => metadata.ClassId, StringComparer.Ordinal)
        .ToArray();

    private IReadOnlyList<string> DirectComServers() => ComInterfaces()
        .Select(static metadata => metadata.Server)
        .Where(static server => server is not null)
        .Cast<string>()
        .Distinct(StringComparer.Ordinal)
        .Order(StringComparer.Ordinal)
        .ToArray();

    private void EmitComGlobals()
    {
        if (!UsesComInterop)
        {
            return;
        }
        EnsureComTarget();
        EmitGuidGlobal(ComClassFactoryGuidGlobal, "00000001-0000-0000-C000-000000000046");

        foreach (var metadata in ComInterfaces()
                     .GroupBy(ComClassKey, StringComparer.Ordinal)
                     .Select(static group => group.First()))
        {
            EmitGuidGlobal(ComClassGuidGlobal(metadata), metadata.ClassId);
        }
        foreach (var metadata in ComInterfaces())
        {
            EmitGuidGlobal(ComInterfaceGuidGlobal(metadata), metadata.InterfaceId);
        }

        if (DirectComServers().Count != 0)
        {
            var symbolBytes = System.Text.Encoding.ASCII.GetBytes("DllGetClassObject\0");
            EmitGlobalLine(
                "@.slg.com.dll_get_class_object_name = private unnamed_addr constant "
                + $"[{symbolBytes.Length.ToString(CultureInfo.InvariantCulture)} x i8] "
                + $"c\"{EscapeLlvmBytes(symbolBytes)}\", align 1");
        }
        foreach (var server in DirectComServers())
        {
            var fileName = NativeLibraryFileName(server);
            var bytes = System.Text.Encoding.UTF8.GetBytes(fileName + "\0");
            EmitGlobalLine(
                $"{ComServerNameGlobal(server)} = private unnamed_addr constant "
                + $"[{bytes.Length.ToString(CultureInfo.InvariantCulture)} x i8] "
                + $"c\"{EscapeLlvmBytes(bytes)}\", align 1");
            EmitGlobalLine($"{ComServerHandleGlobal(server)} = internal global ptr null, align 8");
            EmitGlobalLine($"{ComDllGetClassObjectGlobal(server)} = internal global ptr null, align 8");
        }

        foreach (var metadata in DirectComFactories())
        {
            EmitGlobalLine($"{ComFactoryGlobal(metadata)} = internal global ptr null, align 8");
        }
    }

    private void EmitComDeclarations()
    {
        if (!UsesComInterop)
        {
            return;
        }
        EnsureComTarget();
        EmitFunctionLine("declare dllimport i32 @CoInitializeEx(ptr, i32)");
        EmitFunctionLine("declare dllimport void @CoUninitialize()");
        EmitFunctionLine("declare dllimport i32 @CoCreateInstance(ptr, ptr, i32, ptr, ptr)");
        if (!UsesNativeInterop && DirectComServers().Count != 0)
        {
            EmitFunctionLine("declare dllimport ptr @LoadLibraryA(ptr)");
            EmitFunctionLine("declare dllimport ptr @GetProcAddress(ptr, ptr)");
            EmitFunctionLine("declare dllimport i32 @FreeLibrary(ptr)");
        }
    }

    private void EmitComBinding()
    {
        if (!UsesComInterop)
        {
            return;
        }
        EnsureComTarget();
        var apartments = ComInterfaces()
            .Select(static metadata => metadata.Apartment)
            .Distinct()
            .ToArray();
        if (apartments.Length != 1)
        {
            throw new SollangException(
                "one thread cannot mix COM sta and mta declarations; split the work across explicit threads");
        }

        var coInit = apartments[0] == ComApartment.Sta ? 6 : 4;
        var initialized = NextTemp("com_initialized");
        EmitCall(initialized, "i32", "CoInitializeEx", $"ptr null, i32 {coInit}");
        var initializedOk = NextTemp("com_initialized_ok");
        EmitCompare(initializedOk, "sge", "i32", initialized, "0");
        EmitTrapUnless(initializedOk, "com_initialize");

        foreach (var server in DirectComServers())
        {
            var handle = NextTemp("com_server");
            EmitCall(handle, "ptr", "LoadLibraryA", $"ptr {ComServerNameGlobal(server)}");
            EmitTrapIfNull(handle, "com_server_load");
            EmitStore("ptr", handle, ComServerHandleGlobal(server), 8);

            var symbol = NextTemp("com_dll_get_class_object");
            EmitCall(
                symbol,
                "ptr",
                "GetProcAddress",
                $"ptr {handle}, ptr @.slg.com.dll_get_class_object_name");
            EmitTrapIfNull(symbol, "com_dll_get_class_object");
            EmitStore("ptr", symbol, ComDllGetClassObjectGlobal(server), 8);
        }

        foreach (var metadata in DirectComFactories())
        {
            var output = NextTemp("com_factory_out");
            EmitAlloca(output, "ptr", 8);
            EmitStore("ptr", "null", output, 8);
            var getClassObject = NextTemp("com_get_class_object");
            EmitLoad(getClassObject, "ptr", ComDllGetClassObjectGlobal(metadata.Server!), 8);
            var status = NextTemp("com_factory_status");
            EmitIndirectCall(
                status,
                "i32",
                getClassObject,
                $"ptr {ComClassGuidGlobal(metadata)}, ptr {ComClassFactoryGuidGlobal}, ptr {output}");
            var factory = NextTemp("com_factory");
            EmitLoad(factory, "ptr", output, 8);
            var statusOk = NextTemp("com_factory_status_ok");
            EmitCompare(statusOk, "sge", "i32", status, "0");
            var factoryOk = NextTemp("com_factory_pointer_ok");
            EmitCompare(factoryOk, "ne", "ptr", factory, "null");
            var ready = NextTemp("com_factory_ready");
            EmitBinary(ready, "and", "i1", statusOk, factoryOk);
            EmitTrapUnless(ready, "com_factory");
            EmitStore("ptr", factory, ComFactoryGlobal(metadata), 8);
        }
    }

    private void EmitComCleanup()
    {
        if (!UsesComInterop)
        {
            return;
        }
        foreach (var metadata in DirectComFactories().Reverse())
        {
            var factory = NextTemp("com_factory_close");
            EmitLoad(factory, "ptr", ComFactoryGlobal(metadata), 8);
            EmitComReleasePointer(factory);
        }
        foreach (var server in DirectComServers().Reverse())
        {
            var handle = NextTemp("com_server_close");
            EmitLoad(handle, "ptr", ComServerHandleGlobal(server), 8);
            EmitCall(NextTemp("com_server_closed"), "i32", "FreeLibrary", $"ptr {handle}");
        }
        EmitCall(target: null, "void", "CoUninitialize", "");
    }

    private RuntimeValue EmitComFunctionCall(
        BoundFunction function,
        RuntimeValue? argument,
        IReadOnlyList<RuntimeValue>? additionalArguments)
    {
        EnsureComTarget();
        var metadata = function.Com
            ?? throw new SollangException($"COM function '{function.Name}' has no metadata");
        return metadata.Operation switch
        {
            ComFunctionOperation.Activate => EmitComActivation(function, metadata, argument, additionalArguments),
            ComFunctionOperation.Clone => EmitComClone(function, argument, additionalArguments),
            ComFunctionOperation.Method => EmitComMethod(function, metadata, argument, additionalArguments),
            _ => throw new SollangException($"unsupported COM operation '{metadata.Operation}'")
        };
    }

    private RuntimeValue EmitComActivation(
        BoundFunction function,
        ComFunctionMetadata metadata,
        RuntimeValue? argument,
        IReadOnlyList<RuntimeValue>? additionalArguments)
    {
        if (argument is not null || (additionalArguments?.Count ?? 0) != 0)
        {
            throw new SollangException($"COM activation '{function.Name}' does not accept arguments");
        }

        var output = NextTemp("com_object_out");
        EmitAlloca(output, "ptr", 8);
        EmitStore("ptr", "null", output, 8);
        var status = NextTemp("com_activation_status");
        if (metadata.Server is null)
        {
            EmitCall(
                status,
                "i32",
                "CoCreateInstance",
                $"ptr {ComClassGuidGlobal(metadata)}, ptr null, i32 23, "
                + $"ptr {ComInterfaceGuidGlobal(metadata)}, ptr {output}");
        }
        else
        {
            var factory = NextTemp("com_factory");
            EmitLoad(factory, "ptr", ComFactoryGlobal(metadata), 8);
            var create = EmitComVtableMethod(factory, 3, "com_create_instance");
            EmitIndirectCall(
                status,
                "i32",
                create,
                $"ptr {factory}, ptr null, ptr {ComInterfaceGuidGlobal(metadata)}, ptr {output}");
        }

        var instance = NextTemp("com_object");
        EmitLoad(instance, "ptr", output, 8);
        var statusOk = NextTemp("com_activation_status_ok");
        EmitCompare(statusOk, "sge", "i32", status, "0");
        var pointerOk = NextTemp("com_activation_pointer_ok");
        EmitCompare(pointerOk, "ne", "ptr", instance, "null");
        var succeeded = NextTemp("com_activation_ok");
        EmitBinary(succeeded, "and", "i1", statusOk, pointerOk);
        var interfaceType = _program.Types.TryResolve(metadata.InterfaceType, out var resolved)
            ? resolved
            : throw new SollangException($"unknown COM interface type '{metadata.InterfaceType}'");
        var payload = EmitComInterfaceValue(interfaceType, instance);
        return EmitComResult(function.ReturnType, succeeded, payload, status, "com_activation_result");
    }

    private RuntimeValue EmitComClone(
        BoundFunction function,
        RuntimeValue? argument,
        IReadOnlyList<RuntimeValue>? additionalArguments)
    {
        if ((additionalArguments?.Count ?? 0) != 0)
        {
            throw new SollangException($"COM clone '{function.Name}' does not accept additional arguments");
        }
        var handle = EmitComHandle(argument, function.Name);
        var addRef = EmitComVtableMethod(handle, 1, "com_add_ref");
        EmitIndirectCall(NextTemp("com_reference_count"), "i32", addRef, $"ptr {handle}");
        return EmitComInterfaceValue(function.ReturnType, handle);
    }

    private RuntimeValue EmitComMethod(
        BoundFunction function,
        ComFunctionMetadata metadata,
        RuntimeValue? argument,
        IReadOnlyList<RuntimeValue>? additionalArguments)
    {
        var handle = EmitComHandle(argument, function.Name);
        var parameters = function.AdditionalParameters ?? [];
        additionalArguments ??= [];
        if (parameters.Count != additionalArguments.Count)
        {
            throw new SollangException(
                $"COM method '{function.Name}' expects {parameters.Count} additional argument(s)");
        }

        var arguments = new List<string> { $"ptr {handle}" };
        for (var index = 0; index < parameters.Count; index++)
        {
            var parameter = parameters[index];
            EnsureFunctionArgumentRuntimeType(additionalArguments[index], parameter.Type, function.Name);
            var value = MaterializeAggregateValue(additionalArguments[index]);
            var extension = NativeScalarExtension(parameter.Type);
            arguments.Add(
                value.TypeName + " "
                + (extension.Length == 0 ? "" : extension + " ")
                + value.ValueName);
        }

        if (!_program.Types.TryGetResultTypes(function.ReturnType, out var resultTypes))
        {
            throw new SollangException($"COM method '{function.Name}' must return Result");
        }
        string? output = null;
        if (resultTypes.Ok != BoundType.Unit)
        {
            output = NextTemp("com_method_out");
            EmitAlloca(output, LlvmType(resultTypes.Ok), RuntimeAlignment(resultTypes.Ok));
            EmitStore(LlvmType(resultTypes.Ok), "zeroinitializer", output, RuntimeAlignment(resultTypes.Ok));
            arguments.Add($"ptr {output}");
        }

        var method = EmitComVtableMethod(handle, metadata.VtableSlot, "com_method");
        var status = NextTemp("com_method_status");
        EmitIndirectCall(status, "i32", method, string.Join(", ", arguments));
        var succeeded = NextTemp("com_method_ok");
        EmitCompare(succeeded, "sge", "i32", status, "0");
        RuntimeValue? payload = null;
        if (output is not null)
        {
            var loaded = NextTemp("com_method_value");
            EmitLoad(loaded, LlvmType(resultTypes.Ok), output, RuntimeAlignment(resultTypes.Ok));
            payload = IsIntegerType(resultTypes.Ok)
                ? new RuntimeInt(resultTypes.Ok, loaded)
                : new RuntimeFloat(resultTypes.Ok, loaded);
        }
        return EmitComResult(function.ReturnType, succeeded, payload, status, "com_method_result");
    }

    private RuntimeEnum EmitComResult(
        BoundType resultType,
        string succeeded,
        RuntimeValue? successPayload,
        string status,
        string prefix)
    {
        var definition = _program.Types.GetEnum(resultType);
        var okVariant = definition.Variants.First(static variant => variant.Name == "Ok");
        var errorVariant = definition.Variants.First(static variant => variant.Name == "Err");
        var successLabel = NextLabel(prefix + "_ok");
        var errorLabel = NextLabel(prefix + "_error");
        var endLabel = NextLabel(prefix + "_end");
        EmitConditionalBranch(succeeded, successLabel, errorLabel);

        EmitLabel(successLabel);
        _currentBlockLabel = successLabel;
        var success = EmitEnumValue(resultType, okVariant, successPayload);
        var successIncoming = _currentBlockLabel;
        EmitBranch(endLabel);

        EmitLabel(errorLabel);
        _currentBlockLabel = errorLabel;
        var failure = EmitEnumValue(
            resultType,
            errorVariant,
            new RuntimeInt(BoundType.Int, status));
        var errorIncoming = _currentBlockLabel;
        EmitBranch(endLabel);

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        return EmitEnumPhi(
            prefix,
            resultType,
            [(success, successIncoming), (failure, errorIncoming)]);
    }

    private RuntimeStruct EmitComInterfaceValue(BoundType type, string pointer)
    {
        var pointerValue = NextTemp("com_handle");
        EmitAssign(pointerValue, $"ptrtoint ptr {pointer} to i64");
        var aggregate = NextTemp("com_interface");
        EmitAssign(aggregate, $"insertvalue {LlvmStructType(type)} poison, i64 {pointerValue}, 0");
        return new RuntimeStruct(type, aggregate);
    }

    private string EmitComHandle(RuntimeValue? value, string functionName)
    {
        if (value is not RuntimeReference reference)
        {
            throw new SollangException($"COM function '{functionName}' requires a readonly interface reference");
        }
        var loaded = LoadReference(reference) as RuntimeStruct
            ?? throw new SollangException($"COM function '{functionName}' received an invalid interface");
        var integer = NextTemp("com_handle_value");
        EmitAssign(integer, $"extractvalue {LlvmStructType(loaded.Type)} {loaded.ValueName}, 0");
        var pointer = NextTemp("com_handle_pointer");
        EmitAssign(pointer, $"inttoptr i64 {integer} to ptr");
        return pointer;
    }

    private string EmitComVtableMethod(string instance, int slotIndex, string prefix)
    {
        var vtable = NextTemp(prefix + "_vtable");
        EmitLoad(vtable, "ptr", instance, 8);
        var slot = NextTemp(prefix + "_slot");
        EmitAssign(
            slot,
            $"getelementptr ptr, ptr {vtable}, i64 {slotIndex.ToString(CultureInfo.InvariantCulture)}");
        var method = NextTemp(prefix + "_target");
        EmitLoad(method, "ptr", slot, 8);
        return method;
    }

    private void EmitComReleasePointer(string instance)
    {
        var release = EmitComVtableMethod(instance, 2, "com_release");
        EmitIndirectCall(NextTemp("com_reference_count"), "i32", release, $"ptr {instance}");
    }

    private void EmitGuidGlobal(string name, string value)
    {
        if (!Guid.TryParse(value, out var guid))
        {
            throw new SollangException($"invalid COM GUID '{value}'");
        }
        var bytes = guid.ToByteArray();
        EmitGlobalLine(
            $"{name} = private unnamed_addr constant [16 x i8] "
            + $"c\"{EscapeLlvmBytes(bytes)}\", align 4");
    }

    private void EnsureComTarget()
    {
        if (_platform is not WindowsLlvmRuntimePlatform)
        {
            throw new SollangException(
                "COM declarations require target windows-x64; Linux and wasm32-browser do not provide COM");
        }
    }

    private static string ComClassKey(ComFunctionMetadata metadata) =>
        (metadata.Server ?? "<registered>") + "\0" + metadata.ClassId;

    private static string ComInterfaceKey(ComFunctionMetadata metadata) =>
        ComClassKey(metadata) + "\0" + metadata.InterfaceId;

    private static string ComClassGuidGlobal(ComFunctionMetadata metadata) =>
        "@.slg.com.clsid." + NativeStableId(ComClassKey(metadata));

    private static string ComInterfaceGuidGlobal(ComFunctionMetadata metadata) =>
        "@.slg.com.iid." + NativeStableId(ComInterfaceKey(metadata));

    private const string ComClassFactoryGuidGlobal = "@.slg.com.iid.class_factory";

    private static string ComServerNameGlobal(string server) =>
        "@.slg.com.server.name." + NativeStableId(server);

    private static string ComServerHandleGlobal(string server) =>
        "@.slg.com.server.handle." + NativeStableId(server);

    private static string ComDllGetClassObjectGlobal(string server) =>
        "@.slg.com.server.get_class_object." + NativeStableId(server);

    private static string ComFactoryGlobal(ComFunctionMetadata metadata) =>
        "@.slg.com.factory." + NativeStableId(ComClassKey(metadata));
}
