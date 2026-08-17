using System.Globalization;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Semantics;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private RuntimeValue EmitRuntimeSocketCall(
        BoundFunction function,
        RuntimeValue? argument,
        IReadOnlyList<RuntimeValue> additionalArguments)
    {
        return function.Kind switch
        {
            BoundFunctionKind.RuntimeSocketListen => EmitSocketListen(
                function,
                RequireSocketStruct(argument, function.Name, "sys.socket.ListenOptions")),
            BoundFunctionKind.RuntimeSocketAccept => EmitSocketAccept(
                function,
                RequireSocketStruct(argument, function.Name, "sys.socket.TcpListener")),
            BoundFunctionKind.RuntimeSocketConnect => EmitSocketConnect(
                function,
                RequireSocketStruct(argument, function.Name, "sys.socket.Endpoint")),
            BoundFunctionKind.RuntimeSocketReceive => EmitSocketReceive(
                function,
                RequireSocketStruct(argument, function.Name, "sys.socket.TcpStream"),
                RequireSocketAdditional<RuntimeInt>(additionalArguments, function.Name)),
            BoundFunctionKind.RuntimeSocketSend => EmitSocketSend(
                function,
                RequireSocketStruct(argument, function.Name, "sys.socket.TcpStream"),
                SocketByteArray(RequireSocketAdditional<RuntimeValue>(additionalArguments, function.Name))),
            BoundFunctionKind.RuntimeSocketSendText => EmitSocketSendText(
                function,
                RequireSocketStruct(argument, function.Name, "sys.socket.TcpStream"),
                SocketText(RequireSocketAdditional<RuntimeValue>(additionalArguments, function.Name))),
            BoundFunctionKind.RuntimeSocketShutdown => EmitSocketShutdown(
                function,
                RequireSocketStruct(argument, function.Name, "sys.socket.TcpStream")),
            BoundFunctionKind.RuntimeSocketBindDatagram => EmitSocketBindDatagram(
                function,
                RequireSocketStruct(argument, function.Name, "sys.socket.DatagramBindOptions")),
            BoundFunctionKind.RuntimeSocketLocalPort => EmitSocketLocalPort(
                function,
                RequireSocketStruct(argument, function.Name, "sys.socket.UdpSocket")),
            BoundFunctionKind.RuntimeSocketSendTo => EmitSocketSendTo(
                function,
                RequireSocketStruct(argument, function.Name, "sys.socket.UdpSocket"),
                additionalArguments),
            BoundFunctionKind.RuntimeSocketReceiveFrom => EmitSocketReceiveFrom(
                function,
                RequireSocketStruct(argument, function.Name, "sys.socket.UdpSocket"),
                RequireSocketAdditional<RuntimeInt>(additionalArguments, function.Name)),
            _ => throw new SollangException($"unsupported socket intrinsic '{function.Name}'")
        };
    }

    private RuntimeEnum EmitSocketListen(BoundFunction function, RuntimeStruct options)
    {
        var endpoint = SocketStructField(options, "endpoint") as RuntimeStruct
            ?? throw new SollangException("socket listen endpoint must be a runtime struct");
        var address = SocketStructField(endpoint, "address") as RuntimeText
            ?? throw new SollangException("socket endpoint address must be Text");
        var port = SocketStructField(endpoint, "port") as RuntimeInt
            ?? throw new SollangException("socket endpoint port must be UInt16");
        var backlog = SocketStructField(options, "backlog") as RuntimeInt
            ?? throw new SollangException("socket listen backlog must be Int");
        var reuseAddress = SocketStructField(options, "reuseAddress") as RuntimeBool
            ?? throw new SollangException("socket reuseAddress must be Bool");
        var backlog64 = EmitRuntimeIntegerAsI64(backlog, "socket_backlog");
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_listen",
            $"ptr {address.PointerName}, i64 {address.LengthName}, i16 {port.ValueName}, "
            + $"i64 {backlog64}, i1 {reuseAddress.ValueName}");
        return EmitSocketOwnerResult(function, raw, "sys.socket.TcpListener");
    }

    private RuntimeEnum EmitSocketConnect(BoundFunction function, RuntimeStruct endpoint)
    {
        var address = SocketStructField(endpoint, "address") as RuntimeText
            ?? throw new SollangException("socket endpoint address must be Text");
        var port = SocketStructField(endpoint, "port") as RuntimeInt
            ?? throw new SollangException("socket endpoint port must be UInt16");
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_connect",
            $"ptr {address.PointerName}, i64 {address.LengthName}, i16 {port.ValueName}");
        return EmitSocketOwnerResult(function, raw, "sys.socket.TcpStream");
    }

    private RuntimeEnum EmitSocketAccept(BoundFunction function, RuntimeStruct listener)
    {
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_accept",
            $"i64 {ExtractSocketHandle(listener, "sys.socket.TcpListener")}");
        return EmitSocketOwnerResult(function, raw, "sys.socket.TcpStream");
    }

    private RuntimeEnum EmitSocketReceive(
        BoundFunction function,
        RuntimeStruct stream,
        RuntimeInt maximum)
    {
        if (maximum.Type != BoundType.UIntSize)
        {
            throw new SollangException("socket receive maxBytes must be UIntSize");
        }
        var maximumIsZero = NextTemp("socket_receive_maximum_is_zero");
        EmitCompare(maximumIsZero, "eq", "i64", maximum.ValueName, "0");
        var allocatedBytes = NextTemp("socket_receive_allocated_bytes");
        EmitSelect(allocatedBytes, maximumIsZero, "i64 1", $"i64 {maximum.ValueName}");
        var buffer = EmitHeapAllocate(allocatedBytes);
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_receive",
            $"i64 {ExtractSocketHandle(stream, "sys.socket.TcpStream")}, ptr {buffer}, i64 {maximum.ValueName}");
        var resultTypes = ValidateSocketResult(function);
        if (!_program.Types.IsDynamicArray(resultTypes.Ok)
            || _program.Types.GetDynamicArray(resultTypes.Ok).ElementType != BoundType.UInt8)
        {
            throw new SollangException($"{function.Name} must return a UInt8 array result");
        }
        var bytes = new RuntimeDynamicInlineArray(
            resultTypes.Ok,
            BoundType.UInt8,
            buffer,
            raw.Value,
            maximum.ValueName);
        return EmitSocketResult(function, raw, bytes, () =>
            EmitCall(target: null, "void", "sollang_free", $"ptr {buffer}"));
    }

    private RuntimeEnum EmitSocketSend(
        BoundFunction function,
        RuntimeStruct stream,
        RuntimeDynamicInlineArray bytes)
    {
        if (bytes.ElementType != BoundType.UInt8)
        {
            throw new SollangException("socket send bytes must be a UInt8 array");
        }
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_send",
            $"i64 {ExtractSocketHandle(stream, "sys.socket.TcpStream")}, ptr {bytes.PointerName}, i64 {bytes.LengthName}");
        return EmitSocketCountResult(function, raw);
    }

    private RuntimeEnum EmitSocketSendText(
        BoundFunction function,
        RuntimeStruct stream,
        RuntimeText text)
    {
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_send",
            $"i64 {ExtractSocketHandle(stream, "sys.socket.TcpStream")}, ptr {text.PointerName}, i64 {text.LengthName}");
        return EmitSocketCountResult(function, raw);
    }

    private RuntimeEnum EmitSocketShutdown(BoundFunction function, RuntimeStruct stream)
    {
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_shutdown",
            $"i64 {ExtractSocketHandle(stream, "sys.socket.TcpStream")}");
        return EmitSocketResult(function, raw, RuntimeUnit.Instance);
    }

    private RuntimeEnum EmitSocketBindDatagram(BoundFunction function, RuntimeStruct options)
    {
        var endpoint = SocketStructField(options, "endpoint") as RuntimeStruct
            ?? throw new SollangException("datagram bind endpoint must be a runtime struct");
        var address = SocketStructField(endpoint, "address") as RuntimeText
            ?? throw new SollangException("socket endpoint address must be Text");
        var port = SocketStructField(endpoint, "port") as RuntimeInt
            ?? throw new SollangException("socket endpoint port must be UInt16");
        var reuseAddress = SocketStructField(options, "reuseAddress") as RuntimeBool
            ?? throw new SollangException("socket reuseAddress must be Bool");
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_bind_datagram",
            $"ptr {address.PointerName}, i64 {address.LengthName}, i16 {port.ValueName}, i1 {reuseAddress.ValueName}");
        return EmitSocketOwnerResult(function, raw, "sys.socket.UdpSocket");
    }

    private RuntimeEnum EmitSocketSendTo(
        BoundFunction function,
        RuntimeStruct socket,
        IReadOnlyList<RuntimeValue> arguments)
    {
        if (arguments.Count != 2)
        {
            throw new SollangException("socket sendTo expects Endpoint and ref [UInt8; ~]");
        }
        var endpoint = RequireSocketStruct(arguments[0], function.Name, "sys.socket.Endpoint");
        var address = SocketStructField(endpoint, "address") as RuntimeText
            ?? throw new SollangException("socket endpoint address must be Text");
        var port = SocketStructField(endpoint, "port") as RuntimeInt
            ?? throw new SollangException("socket endpoint port must be UInt16");
        var bytes = SocketByteArray(arguments[1]);
        if (bytes.ElementType != BoundType.UInt8)
        {
            throw new SollangException("socket sendTo bytes must be a UInt8 array");
        }
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_send_to",
            $"i64 {ExtractSocketHandle(socket, "sys.socket.UdpSocket")}, ptr {address.PointerName}, i64 {address.LengthName}, "
            + $"i16 {port.ValueName}, ptr {bytes.PointerName}, i64 {bytes.LengthName}");
        return EmitSocketCountResult(function, raw);
    }

    private RuntimeEnum EmitSocketLocalPort(BoundFunction function, RuntimeStruct socket)
    {
        var resultTypes = ValidateSocketResult(function);
        if (resultTypes.Ok != BoundType.UInt16)
        {
            throw new SollangException($"{function.Name} must return a UInt16 result");
        }
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_local_port",
            $"i64 {ExtractSocketHandle(socket, "sys.socket.UdpSocket")}");
        var port = NextTemp("socket_local_port");
        EmitInstruction($"{port} = trunc i64 {raw.Value} to i16");
        return EmitSocketResult(function, raw, new RuntimeInt(BoundType.UInt16, port));
    }

    private RuntimeEnum EmitSocketReceiveFrom(
        BoundFunction function,
        RuntimeStruct socket,
        RuntimeInt maximum)
    {
        if (maximum.Type != BoundType.UIntSize)
        {
            throw new SollangException("socket receiveFrom maxBytes must be UIntSize");
        }
        var resultTypes = ValidateSocketResult(function);
        if (!IsRuntimeNamedStruct(resultTypes.Ok, "sys.socket.Datagram"))
        {
            throw new SollangException($"{function.Name} must return a Datagram result");
        }
        var datagramDefinition = _program.Types.GetStruct(resultTypes.Ok);
        var addressField = datagramDefinition.GetField("sourceAddress");
        var portField = datagramDefinition.GetField("sourcePort");
        var bytesField = datagramDefinition.GetField("bytes");
        var maximumIsZero = NextTemp("socket_datagram_maximum_is_zero");
        EmitCompare(maximumIsZero, "eq", "i64", maximum.ValueName, "0");
        var allocatedBytes = NextTemp("socket_datagram_allocated_bytes");
        EmitSelect(allocatedBytes, maximumIsZero, "i64 1", $"i64 {maximum.ValueName}");
        var bytesBuffer = EmitHeapAllocate(allocatedBytes);
        var addressBuffer = EmitHeapAllocate("46");
        var addressLengthSlot = NextTemp("socket_datagram_address_length_slot");
        EmitAlloca(addressLengthSlot, "i64", 8);
        EmitStore("i64", "0", addressLengthSlot, 8);
        var portSlot = NextTemp("socket_datagram_port_slot");
        EmitAlloca(portSlot, "i16", 2);
        EmitStore("i16", "0", portSlot, 2);
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_receive_from",
            $"i64 {ExtractSocketHandle(socket, "sys.socket.UdpSocket")}, ptr {bytesBuffer}, i64 {maximum.ValueName}, "
            + $"ptr {addressBuffer}, ptr {addressLengthSlot}, ptr {portSlot}");
        var addressLength = NextTemp("socket_datagram_address_length");
        EmitLoad(addressLength, "i64", addressLengthSlot, 8);
        var sourcePort = NextTemp("socket_datagram_source_port");
        EmitLoad(sourcePort, "i16", portSlot, 2);
        var addressArray = new RuntimeDynamicInlineArray(
            addressField.Type, BoundType.UInt8, addressBuffer, addressLength, "46");
        var bytesArray = new RuntimeDynamicInlineArray(
            bytesField.Type, BoundType.UInt8, bytesBuffer, raw.Value, maximum.ValueName);
        var addressValue = MaterializeAggregateValue(addressArray);
        var bytesValue = MaterializeAggregateValue(bytesArray);
        var withAddress = NextTemp("socket_datagram_with_address");
        EmitAssign(withAddress,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} poison, {addressValue.TypeName} {addressValue.ValueName}, {addressField.Index.ToString(CultureInfo.InvariantCulture)}");
        var withPort = NextTemp("socket_datagram_with_port");
        EmitAssign(withPort,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} {withAddress}, i16 {sourcePort}, {portField.Index.ToString(CultureInfo.InvariantCulture)}");
        var aggregate = NextTemp("socket_datagram_value");
        EmitAssign(aggregate,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} {withPort}, {bytesValue.TypeName} {bytesValue.ValueName}, {bytesField.Index.ToString(CultureInfo.InvariantCulture)}");
        return EmitSocketResult(function, raw, new RuntimeStruct(resultTypes.Ok, aggregate), () =>
        {
            EmitCall(target: null, "void", "sollang_free", $"ptr {addressBuffer}");
            EmitCall(target: null, "void", "sollang_free", $"ptr {bytesBuffer}");
        });
    }

    private RuntimeEnum EmitSocketOwnerResult(
        BoundFunction function,
        SocketPlatformResult raw,
        string expectedOwnerName)
    {
        var resultTypes = ValidateSocketResult(function);
        if (!IsRuntimeNamedStruct(resultTypes.Ok, expectedOwnerName))
        {
            throw new SollangException($"{function.Name} must return {expectedOwnerName}");
        }
        var aggregate = NextTemp("socket_owner_value");
        EmitAssign(
            aggregate,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} poison, i64 {raw.Value}, 0");
        return EmitSocketResult(function, raw, new RuntimeStruct(resultTypes.Ok, aggregate));
    }

    private RuntimeEnum EmitSocketCountResult(BoundFunction function, SocketPlatformResult raw)
    {
        var resultTypes = ValidateSocketResult(function);
        if (resultTypes.Ok != BoundType.UIntSize)
        {
            throw new SollangException($"{function.Name} must return a UIntSize result");
        }
        return EmitSocketResult(function, raw, new RuntimeInt(BoundType.UIntSize, raw.Value));
    }

    private RuntimeEnum EmitSocketResult(
        BoundFunction function,
        SocketPlatformResult raw,
        RuntimeValue successPayload,
        Action? failureCleanup = null)
    {
        var resultTypes = ValidateSocketResult(function);
        var definition = _program.Types.GetEnum(function.ReturnType);
        var okVariant = definition.Variants.First(variant => variant.Name == "Ok");
        var errVariant = definition.Variants.First(variant => variant.Name == "Err");
        var succeeded = NextTemp("socket_succeeded");
        EmitCompare(succeeded, "slt", "i32", raw.Kind, "0");
        var successLabel = NextLabel("socket_success");
        var failureLabel = NextLabel("socket_failure");
        var endLabel = NextLabel("socket_result_end");
        EmitConditionalBranch(succeeded, successLabel, failureLabel);

        EmitLabel(successLabel);
        _currentBlockLabel = successLabel;
        var success = EmitEnumValue(
            function.ReturnType,
            okVariant,
            resultTypes.Ok == BoundType.Unit ? null : successPayload);
        EmitBranch(endLabel);
        var successExit = _currentBlockLabel;

        EmitLabel(failureLabel);
        _currentBlockLabel = failureLabel;
        failureCleanup?.Invoke();
        var error = EmitSocketError(resultTypes.Error, raw.Kind, raw.Code);
        var failure = EmitEnumValue(function.ReturnType, errVariant, error);
        EmitBranch(endLabel);
        var failureExit = _currentBlockLabel;

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        return EmitEnumPhi(
            "socket_result",
            function.ReturnType,
            [(success, successExit), (failure, failureExit)]);
    }

    private RuntimeStruct EmitSocketError(BoundType errorType, string kind, string code)
    {
        if (!IsRuntimeNamedStruct(errorType, "sys.socket.SocketError"))
        {
            throw new SollangException("socket error result must be sys.socket.SocketError");
        }
        var definition = _program.Types.GetStruct(errorType);
        var kindField = definition.GetField("kind");
        var codeField = definition.GetField("code");
        var kindValue = EmitRuntimeEnumTag(kindField.Type, kind, "socket_error_kind");
        var materializedKind = MaterializeAggregateValue(kindValue);
        var withKind = NextTemp("socket_error_with_kind");
        EmitAssign(
            withKind,
            $"insertvalue {LlvmStructType(errorType)} poison, {materializedKind.TypeName} {materializedKind.ValueName}, {kindField.Index.ToString(CultureInfo.InvariantCulture)}");
        var aggregate = NextTemp("socket_error_value");
        EmitAssign(
            aggregate,
            $"insertvalue {LlvmStructType(errorType)} {withKind}, i32 {code}, {codeField.Index.ToString(CultureInfo.InvariantCulture)}");
        return new RuntimeStruct(errorType, aggregate);
    }

    private RuntimeEnum EmitRuntimeEnumTag(BoundType enumType, string tag, string prefix)
    {
        if (!_program.Types.IsEnum(enumType))
        {
            throw new SollangException("socket error kind must be an enum");
        }
        var llvmType = LlvmEnumType(enumType);
        var slot = NextTemp(prefix + "_slot");
        EmitAlloca(slot, llvmType, 8);
        EmitStore(llvmType, "zeroinitializer", slot, 8);
        var tagAddress = NextTemp(prefix + "_tag_address");
        EmitAssign(tagAddress, $"getelementptr inbounds {llvmType}, ptr {slot}, i32 0, i32 0");
        EmitStore("i32", tag, tagAddress, 4);
        var value = NextTemp(prefix);
        EmitLoad(value, llvmType, slot, 8);
        return new RuntimeEnum(enumType, value);
    }

    private SocketPlatformResult EmitSocketPlatformResult(string target, string arguments)
    {
        var raw = NextTemp("socket_platform_result");
        EmitCall(raw, "%sollang.socket_result", target, arguments);
        var value = NextTemp("socket_platform_value");
        EmitAssign(value, $"extractvalue %sollang.socket_result {raw}, 0");
        var kind = NextTemp("socket_platform_kind");
        EmitAssign(kind, $"extractvalue %sollang.socket_result {raw}, 1");
        var code = NextTemp("socket_platform_code");
        EmitAssign(code, $"extractvalue %sollang.socket_result {raw}, 2");
        return new SocketPlatformResult(value, kind, code);
    }

    private RuntimeValue SocketStructField(RuntimeStruct value, string fieldName)
    {
        var definition = _program.Types.GetStruct(value.Type);
        var field = definition.GetField(fieldName);
        var extracted = NextTemp("socket_field");
        EmitAssign(
            extracted,
            $"extractvalue {LlvmStructType(value.Type)} {value.ValueName}, {field.Index.ToString(CultureInfo.InvariantCulture)}");
        return DematerializeAggregateValue(field.Type, extracted);
    }

    private RuntimeStruct RequireSocketStruct(RuntimeValue? value, string operation, string expectedName)
    {
        if (value is not RuntimeStruct structure || !IsRuntimeNamedStruct(structure.Type, expectedName))
        {
            throw new SollangException($"{operation} expects {expectedName}");
        }
        return structure;
    }

    private T RequireSocketAdditional<T>(IReadOnlyList<RuntimeValue> values, string operation)
        where T : RuntimeValue
    {
        if (values.Count != 1 || values[0] is not T value)
        {
            throw new SollangException($"{operation} expects exactly one additional argument");
        }
        return value;
    }

    private RuntimeDynamicInlineArray SocketByteArray(RuntimeValue value)
    {
        value = value is RuntimeReference reference ? LoadReference(reference) : value;
        return value as RuntimeDynamicInlineArray
            ?? throw new SollangException("socket send expects ref [UInt8; ~]");
    }

    private RuntimeText SocketText(RuntimeValue value)
    {
        value = value is RuntimeFormattedText ? EmitTransientText(value) : value;
        return value as RuntimeText
            ?? throw new SollangException("socket sendText expects Text");
    }

    private string ExtractSocketHandle(RuntimeStruct owner, string expectedName)
    {
        if (!IsRuntimeNamedStruct(owner.Type, expectedName))
        {
            throw new SollangException($"socket operation expects {expectedName}");
        }
        var handle = NextTemp("socket_handle");
        EmitAssign(handle, $"extractvalue {LlvmStructType(owner.Type)} {owner.ValueName}, 0");
        return handle;
    }

    private bool IsRuntimeNamedStruct(BoundType type, string expectedName) =>
        _program.Types.IsStruct(type)
        && string.Equals(_program.Types.GetStruct(type).Name, expectedName, StringComparison.Ordinal);

    private (BoundType Ok, BoundType Error) ValidateSocketResult(BoundFunction function)
    {
        if (!_program.Types.TryGetResultTypes(function.ReturnType, out var resultTypes)
            || !IsRuntimeNamedStruct(resultTypes.Error, "sys.socket.SocketError"))
        {
            throw new SollangException($"{function.Name} has an invalid socket result type");
        }
        return resultTypes;
    }

    private sealed record SocketPlatformResult(string Value, string Kind, string Code);
}
