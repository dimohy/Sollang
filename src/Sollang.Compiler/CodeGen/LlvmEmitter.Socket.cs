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
                RequireSocketStruct(argument, function.Name, "std.net.socket.ListenOptions")),
            BoundFunctionKind.RuntimeSocketAccept => EmitSocketAccept(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.TcpListener")),
            BoundFunctionKind.RuntimeSocketTryClone => EmitSocketTryClone(
                function,
                RequireSocketOwner(argument, function.Name)),
            BoundFunctionKind.RuntimeSocketConnect => EmitSocketConnect(
                function,
                RequireSocketEnum(argument, function.Name, "std.net.Endpoint")),
            BoundFunctionKind.RuntimeSocketReceive => EmitSocketReceive(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.TcpStream"),
                RequireSocketAdditional<RuntimeValue>(additionalArguments, function.Name)),
            BoundFunctionKind.RuntimeSocketReceiveAppend => EmitSocketReceiveAppend(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.TcpStream"),
                RequireSocketAdditional<RuntimeValue>(additionalArguments, function.Name)),
            BoundFunctionKind.RuntimeSocketReceiveVectored => EmitSocketReceiveVectored(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.TcpStream"),
                RequireSocketAdditional<RuntimeValue>(additionalArguments, function.Name)),
            BoundFunctionKind.RuntimeSocketPeek => EmitSocketReceiveInto(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.TcpStream"),
                RequireSocketAdditional<RuntimeValue>(additionalArguments, function.Name),
                peek: true),
            BoundFunctionKind.RuntimeSocketSend => EmitSocketSend(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.TcpStream"),
                SocketByteArray(RequireSocketAdditional<RuntimeValue>(additionalArguments, function.Name))),
            BoundFunctionKind.RuntimeSocketSendRange => EmitSocketSendRange(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.TcpStream"),
                additionalArguments),
            BoundFunctionKind.RuntimeSocketSendVectored => EmitSocketSendVectored(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.TcpStream"),
                RequireSocketAdditional<RuntimeInlineSlice>(additionalArguments, function.Name)),
            BoundFunctionKind.RuntimeSocketSendText => EmitSocketSendText(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.TcpStream"),
                SocketText(RequireSocketAdditional<RuntimeValue>(additionalArguments, function.Name))),
            BoundFunctionKind.RuntimeSocketShutdown => EmitSocketShutdown(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.TcpStream"),
                RequireSocketAdditional<RuntimeEnum>(additionalArguments, function.Name)),
            BoundFunctionKind.RuntimeSocketBindDatagram => EmitSocketBindDatagram(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.DatagramBindOptions")),
            BoundFunctionKind.RuntimeSocketLocalPort => EmitSocketLocalPort(
                function,
                RequireSocketOwner(argument, function.Name)),
            BoundFunctionKind.RuntimeSocketLocalEndpoint => EmitSocketObservedEndpoint(
                function,
                RequireSocketOwner(argument, function.Name),
                remote: false),
            BoundFunctionKind.RuntimeSocketRemoteEndpoint => EmitSocketObservedEndpoint(
                function,
                RequireSocketOwner(argument, function.Name),
                remote: true),
            BoundFunctionKind.RuntimeSocketSetNoDelay => EmitSocketSetNoDelay(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.TcpStream"),
                RequireSocketAdditional<RuntimeBool>(additionalArguments, function.Name)),
            BoundFunctionKind.RuntimeSocketNoDelay => EmitSocketNoDelay(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.TcpStream")),
            BoundFunctionKind.RuntimeSocketSetKeepAlive => EmitSocketSetKeepAlive(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.TcpStream"),
                RequireSocketAdditional<RuntimeBool>(additionalArguments, function.Name)),
            BoundFunctionKind.RuntimeSocketKeepAlive => EmitSocketKeepAlive(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.TcpStream")),
            BoundFunctionKind.RuntimeSocketSetLinger => EmitSocketSetLinger(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.TcpStream"),
                RequireSocketAdditional<RuntimeEnum>(additionalArguments, function.Name)),
            BoundFunctionKind.RuntimeSocketLinger => EmitSocketLinger(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.TcpStream")),
            BoundFunctionKind.RuntimeSocketSetReadTimeout => EmitSocketSetTimeout(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.TcpStream"),
                RequireSocketAdditional<RuntimeEnum>(additionalArguments, function.Name),
                write: false),
            BoundFunctionKind.RuntimeSocketReadTimeout => EmitSocketTimeout(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.TcpStream"),
                write: false),
            BoundFunctionKind.RuntimeSocketSetWriteTimeout => EmitSocketSetTimeout(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.TcpStream"),
                RequireSocketAdditional<RuntimeEnum>(additionalArguments, function.Name),
                write: true),
            BoundFunctionKind.RuntimeSocketWriteTimeout => EmitSocketTimeout(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.TcpStream"),
                write: true),
            BoundFunctionKind.RuntimeSocketSendTo => EmitSocketSendTo(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.UdpSocket"),
                additionalArguments),
            BoundFunctionKind.RuntimeSocketReceiveFrom => EmitSocketReceiveFrom(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.UdpSocket"),
                RequireSocketAdditional<RuntimeValue>(additionalArguments, function.Name),
                peek: false),
            BoundFunctionKind.RuntimeSocketPeekFrom => EmitSocketReceiveFrom(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.UdpSocket"),
                RequireSocketAdditional<RuntimeValue>(additionalArguments, function.Name),
                peek: true),
            BoundFunctionKind.RuntimeSocketSetNonblocking => EmitSocketSetNonblocking(
                function,
                RequireSocketOwner(argument, function.Name),
                RequireSocketAdditional<RuntimeBool>(additionalArguments, function.Name)),
            BoundFunctionKind.RuntimeSocketPoll => EmitSocketPoll(
                function,
                RequireSocketOwner(argument, function.Name),
                additionalArguments),
            BoundFunctionKind.RuntimeSocketReactorWait => EmitSocketReactorWait(
                function,
                RequireSocketStruct(argument, function.Name, "std.net.socket.Reactor"),
                additionalArguments),
            BoundFunctionKind.RuntimeSocketClose => EmitSocketClose(
                RequireSocketOwner(argument, function.Name)),
            _ => throw new SollangException($"unsupported socket intrinsic '{function.Name}'")
        };
    }

    private RuntimeValue EmitSocketClose(RuntimeStruct owner)
    {
        var ownerName = _program.Types.GetStruct(owner.Type).Name;
        var handle = ExtractSocketHandle(owner, ownerName);
        EmitCall(target: null, "void", "sollang_platform_close_socket", $"i64 {handle}");
        return RuntimeUnit.Instance;
    }

    private RuntimeEnum EmitSocketSetNonblocking(
        BoundFunction function,
        RuntimeStruct owner,
        RuntimeBool enabled)
    {
        var ownerName = _program.Types.GetStruct(owner.Type).Name;
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_set_nonblocking",
            $"i64 {ExtractSocketHandle(owner, ownerName)}, i1 {enabled.ValueName}");
        return EmitSocketResult(function, raw, RuntimeUnit.Instance);
    }

    private RuntimeEnum EmitSocketPoll(
        BoundFunction function,
        RuntimeStruct owner,
        IReadOnlyList<RuntimeValue> arguments)
    {
        if (arguments.Count != 2
            || arguments[0] is not RuntimeEnum mode
            || arguments[1] is not RuntimeEnum timeout)
        {
            throw new SollangException($"{function.Name} expects PollMode and Option<Duration>");
        }
        if (!_program.Types.TryGetOptionValue(timeout.Type, out var durationType)
            || !IsRuntimeNamedStruct(durationType, "std.time.Duration"))
        {
            throw new SollangException($"{function.Name} timeout must be Option<std.time.Duration>");
        }
        var modeTag = NextTemp("socket_poll_mode");
        EmitAssign(modeTag, $"extractvalue {LlvmEnumType(mode.Type)} {mode.ValueName}, 0");
        var optionDefinition = _program.Types.GetEnum(timeout.Type);
        var someVariant = optionDefinition.Variants.First(variant => variant.Name == "Some");
        var timeoutTag = NextTemp("socket_poll_timeout_tag");
        EmitAssign(timeoutTag, $"extractvalue {LlvmEnumType(timeout.Type)} {timeout.ValueName}, 0");
        var hasTimeout = NextTemp("socket_poll_has_timeout");
        EmitCompare(hasTimeout, "eq", "i32", timeoutTag,
            someVariant.Tag.ToString(CultureInfo.InvariantCulture));
        var duration = ExtractEnumPayload(timeout, durationType) as RuntimeStruct
            ?? throw new SollangException($"{function.Name} timeout payload must be std.time.Duration");
        var millis = SocketStructField(duration, "millis") as RuntimeInt
            ?? throw new SollangException("std.time.Duration.millis must be Long");
        var ownerName = _program.Types.GetStruct(owner.Type).Name;
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_poll",
            $"i64 {ExtractSocketHandle(owner, ownerName)}, i32 {modeTag}, i1 {hasTimeout}, i64 {millis.ValueName}");
        var ready = NextTemp("socket_poll_ready");
        EmitCompare(ready, "ne", "i64", raw.Value, "0");
        return EmitSocketResult(function, raw, new RuntimeBool(ready));
    }

    private RuntimeEnum EmitSocketReactorWait(
        BoundFunction function,
        RuntimeStruct reactor,
        IReadOnlyList<RuntimeValue> arguments)
    {
        if (arguments.Count != 2
            || arguments[0] is not RuntimeMutableContainerReference events
            || arguments[1] is not RuntimeEnum timeout)
        {
            throw new SollangException($"{function.Name} expects mut [ReadyEvent; ~] and Option<Duration>");
        }
        var interests = SocketStructField(reactor, "interests") as RuntimeDynamicInlineArray
            ?? throw new SollangException("socket Reactor.interests must be [Interest; ~]");
        if (!_program.Types.IsStruct(interests.ElementType)
            || _program.Types.GetStruct(interests.ElementType) is not { Name: "std.net.socket.Interest" } interestDefinition
            || interestDefinition.Fields.Count != 3)
        {
            throw new SollangException("socket reactor interests must be [std.net.socket.Interest]");
        }
        if (!_program.Types.IsDynamicArray(events.TargetType))
        {
            throw new SollangException("socket reactor events must be mut [std.net.socket.ReadyEvent; ~]");
        }
        var eventType = _program.Types.GetDynamicArray(events.TargetType).ElementType;
        if (!_program.Types.IsStruct(eventType)
            || _program.Types.GetStruct(eventType) is not { Name: "std.net.socket.ReadyEvent" } eventDefinition
            || eventDefinition.Fields.Count != 4)
        {
            throw new SollangException("socket reactor events must be mut [std.net.socket.ReadyEvent; ~]");
        }
        if (!_program.Types.TryGetOptionValue(timeout.Type, out var durationType)
            || !IsRuntimeNamedStruct(durationType, "std.time.Duration"))
        {
            throw new SollangException("socket reactor timeout must be Option<std.time.Duration>");
        }

        var keyField = interestDefinition.GetField("key");
        var sourceField = interestDefinition.GetField("source");
        var modeField = interestDefinition.GetField("mode");
        if (keyField.Type != BoundType.UInt64
            || !_program.Types.IsEnum(sourceField.Type)
            || _program.Types.GetEnum(sourceField.Type).Name != "std.net.socket.SocketSource"
            || !_program.Types.IsEnum(modeField.Type)
            || _program.Types.GetEnum(modeField.Type).Name != "std.net.socket.InterestMode")
        {
            throw new SollangException("socket Interest ABI must be UInt64, SocketSource, InterestMode");
        }

        var eventKeyField = eventDefinition.GetField("key");
        var readableField = eventDefinition.GetField("readable");
        var writableField = eventDefinition.GetField("writable");
        var errorField = eventDefinition.GetField("error");
        if (eventKeyField.Type != BoundType.UInt64
            || readableField.Type != BoundType.Bool
            || writableField.Type != BoundType.Bool
            || errorField.Type != BoundType.Bool)
        {
            throw new SollangException("socket ReadyEvent ABI must be UInt64, Bool, Bool, Bool");
        }

        var maximumEvents = SocketStructField(reactor, "maximumEvents") as RuntimeInt
            ?? throw new SollangException("socket Reactor.maximumEvents must be UIntSize");
        var eventPointer = NextTemp("socket_reactor_event_pointer");
        var eventCapacity = NextTemp("socket_reactor_event_capacity");
        EmitLoad(eventPointer, "ptr", events.PointerAddress, 8);
        EmitLoad(eventCapacity, "i64", events.CapacityAddress, 8);

        var optionDefinition = _program.Types.GetEnum(timeout.Type);
        var someVariant = optionDefinition.Variants.First(variant => variant.Name == "Some");
        var timeoutTag = NextTemp("socket_reactor_timeout_tag");
        EmitAssign(timeoutTag, $"extractvalue {LlvmEnumType(timeout.Type)} {timeout.ValueName}, 0");
        var hasTimeout = NextTemp("socket_reactor_has_timeout");
        EmitCompare(hasTimeout, "eq", "i32", timeoutTag,
            someVariant.Tag.ToString(CultureInfo.InvariantCulture));
        var duration = ExtractEnumPayload(timeout, durationType) as RuntimeStruct
            ?? throw new SollangException("socket reactor timeout payload must be std.time.Duration");
        var millis = SocketStructField(duration, "millis") as RuntimeInt
            ?? throw new SollangException("std.time.Duration.millis must be Long");

        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_reactor_wait",
            $"ptr {interests.PointerName}, i64 {interests.LengthName}, i64 {_program.Types.InlineSizeOf(interests.ElementType)}, "
            + $"i64 {_program.Types.FieldOffsetOf(interests.ElementType, keyField.Index)}, "
            + $"i64 {_program.Types.FieldOffsetOf(interests.ElementType, sourceField.Index)}, "
            + $"i64 {_program.Types.FieldOffsetOf(interests.ElementType, modeField.Index)}, "
            + $"i64 {maximumEvents.ValueName}, ptr {eventPointer}, ptr {events.LengthAddress}, i64 {eventCapacity}, "
            + $"i64 {_program.Types.InlineSizeOf(eventType)}, "
            + $"i64 {_program.Types.FieldOffsetOf(eventType, eventKeyField.Index)}, "
            + $"i64 {_program.Types.FieldOffsetOf(eventType, readableField.Index)}, "
            + $"i64 {_program.Types.FieldOffsetOf(eventType, writableField.Index)}, "
            + $"i64 {_program.Types.FieldOffsetOf(eventType, errorField.Index)}, "
            + $"i1 {hasTimeout}, i64 {millis.ValueName}");
        return EmitSocketCountResult(function, raw);
    }

    private RuntimeEnum EmitSocketListen(BoundFunction function, RuntimeStruct options)
    {
        var endpoint = SocketStructField(options, "endpoint") as RuntimeEnum
            ?? throw new SollangException("socket listen endpoint must be std.net.Endpoint");
        var endpointPointer = EmitSocketEndpointDescriptor(endpoint);
        var backlog = SocketStructField(options, "backlog") as RuntimeInt
            ?? throw new SollangException("socket listen backlog must be Int");
        var reuseAddress = SocketStructField(options, "reuseAddress") as RuntimeBool
            ?? throw new SollangException("socket reuseAddress must be Bool");
        var backlog64 = EmitRuntimeIntegerAsI64(backlog, "socket_backlog");
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_listen",
            $"ptr {endpointPointer}, i64 {backlog64}, i1 {reuseAddress.ValueName}");
        return EmitSocketOwnerResult(function, raw, "std.net.socket.TcpListener");
    }

    private RuntimeEnum EmitSocketConnect(BoundFunction function, RuntimeEnum endpoint)
    {
        var endpointPointer = EmitSocketEndpointDescriptor(endpoint);
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_connect",
            $"ptr {endpointPointer}");
        return EmitSocketOwnerResult(function, raw, "std.net.socket.TcpStream");
    }

    private RuntimeEnum EmitSocketAccept(BoundFunction function, RuntimeStruct listener)
    {
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_accept",
            $"i64 {ExtractSocketHandle(listener, "std.net.socket.TcpListener")}");
        return EmitSocketOwnerResult(function, raw, "std.net.socket.TcpStream");
    }

    private RuntimeEnum EmitSocketTryClone(BoundFunction function, RuntimeStruct owner)
    {
        var ownerName = _program.Types.GetStruct(owner.Type).Name;
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_try_clone",
            $"i64 {ExtractSocketHandle(owner, ownerName)}");
        return EmitSocketOwnerResult(function, raw, ownerName);
    }

    private RuntimeEnum EmitSocketReceive(
        BoundFunction function,
        RuntimeStruct stream,
        RuntimeValue target)
    {
        return target is RuntimeInt maximum
            ? EmitSocketReceiveAllocated(function, stream, maximum)
            : EmitSocketReceiveInto(function, stream, target, peek: false);
    }

    private RuntimeEnum EmitSocketReceiveAllocated(
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
            $"i64 {ExtractSocketHandle(stream, "std.net.socket.TcpStream")}, ptr {buffer}, i64 {maximum.ValueName}, i32 0");
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

    private RuntimeEnum EmitSocketReceiveInto(
        BoundFunction function,
        RuntimeStruct stream,
        RuntimeValue target,
        bool peek)
    {
        if (target is not RuntimeMutableContainerReference buffer
            || !_program.Types.IsDynamicArray(buffer.TargetType)
            || _program.Types.GetDynamicArray(buffer.TargetType).ElementType != BoundType.UInt8)
        {
            throw new SollangException("socket receiveInto expects mut [UInt8; ~]");
        }
        var pointer = NextTemp("socket_receive_into_pointer");
        var capacity = NextTemp("socket_receive_into_capacity");
        EmitLoad(pointer, "ptr", buffer.PointerAddress, 8);
        EmitLoad(capacity, "i64", buffer.CapacityAddress, 8);
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_receive",
            $"i64 {ExtractSocketHandle(stream, "std.net.socket.TcpStream")}, ptr {pointer}, i64 {capacity}, i32 {(peek ? "2" : "0")}");
        return EmitSocketResult(
            function,
            raw,
            new RuntimeInt(BoundType.UIntSize, raw.Value),
            successAction: () => EmitStore("i64", raw.Value, buffer.LengthAddress, 8));
    }

    private RuntimeEnum EmitSocketReceiveAppend(
        BoundFunction function,
        RuntimeStruct stream,
        RuntimeValue target)
    {
        if (target is not RuntimeMutableContainerReference buffer
            || !_program.Types.IsDynamicArray(buffer.TargetType)
            || _program.Types.GetDynamicArray(buffer.TargetType).ElementType != BoundType.UInt8)
        {
            throw new SollangException("socket receiveAppend expects mut [UInt8; ~]");
        }
        var pointer = NextTemp("socket_receive_append_pointer");
        var length = NextTemp("socket_receive_append_length");
        var capacity = NextTemp("socket_receive_append_capacity");
        EmitLoad(pointer, "ptr", buffer.PointerAddress, 8);
        EmitLoad(length, "i64", buffer.LengthAddress, 8);
        EmitLoad(capacity, "i64", buffer.CapacityAddress, 8);
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_receive_append",
            $"i64 {ExtractSocketHandle(stream, "std.net.socket.TcpStream")}, ptr {pointer}, i64 {length}, i64 {capacity}");
        return EmitSocketResult(
            function,
            raw,
            new RuntimeInt(BoundType.UIntSize, raw.Value),
            successAction: () =>
            {
                var publishedLength = NextTemp("socket_receive_append_published_length");
                EmitAssign(publishedLength, $"add i64 {length}, {raw.Value}");
                EmitStore("i64", publishedLength, buffer.LengthAddress, 8);
            });
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
            $"i64 {ExtractSocketHandle(stream, "std.net.socket.TcpStream")}, ptr {bytes.PointerName}, i64 {bytes.LengthName}");
        return EmitSocketCountResult(function, raw);
    }

    private RuntimeEnum EmitSocketSendText(
        BoundFunction function,
        RuntimeStruct stream,
        RuntimeText text)
    {
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_send",
            $"i64 {ExtractSocketHandle(stream, "std.net.socket.TcpStream")}, ptr {text.PointerName}, i64 {text.LengthName}");
        return EmitSocketCountResult(function, raw);
    }

    private RuntimeEnum EmitSocketSendRange(
        BoundFunction function,
        RuntimeStruct stream,
        IReadOnlyList<RuntimeValue> arguments)
    {
        if (arguments.Count != 3
            || arguments[1] is not RuntimeInt { Type: BoundType.UIntSize } offset
            || arguments[2] is not RuntimeInt { Type: BoundType.UIntSize } length)
        {
            throw new SollangException("socket sendRange expects ref [UInt8; ~], UIntSize, UIntSize");
        }
        var bytes = SocketByteArray(arguments[0]);
        if (bytes.ElementType != BoundType.UInt8)
        {
            throw new SollangException("socket sendRange bytes must be a UInt8 array");
        }
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_send_range",
            $"i64 {ExtractSocketHandle(stream, "std.net.socket.TcpStream")}, ptr {bytes.PointerName}, i64 {bytes.LengthName}, i64 {offset.ValueName}, i64 {length.ValueName}");
        return EmitSocketCountResult(function, raw);
    }

    private RuntimeEnum EmitSocketSendVectored(
        BoundFunction function,
        RuntimeStruct stream,
        RuntimeInlineSlice buffers)
    {
        if (!_program.Types.IsStruct(buffers.ElementType)
            || _program.Types.GetStruct(buffers.ElementType) is not { Name: "std.net.socket.SendBuffer" } definition
            || definition.Fields.Count != 3)
        {
            throw new SollangException("socket sendVectored expects [std.net.socket.SendBuffer]");
        }

        var bytesField = definition.GetField("bytes");
        var offsetField = definition.GetField("offset");
        var lengthField = definition.GetField("length");
        var bytesType = _program.Types.IsReference(bytesField.Type)
            ? _program.Types.GetReference(bytesField.Type).ElementType
            : BoundType.Unit;
        if (!_program.Types.IsReference(bytesField.Type)
            || !_program.Types.IsDynamicArray(bytesType)
            || _program.Types.GetDynamicArray(bytesType).ElementType != BoundType.UInt8
            || offsetField.Type != BoundType.UIntSize
            || lengthField.Type != BoundType.UIntSize)
        {
            throw new SollangException("socket SendBuffer must contain ref [UInt8; ~], UIntSize, UIntSize");
        }

        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_send_vectored",
            $"i64 {ExtractSocketHandle(stream, "std.net.socket.TcpStream")}, ptr {buffers.PointerName}, i64 {buffers.LengthName}, "
            + $"i64 {_program.Types.InlineSizeOf(buffers.ElementType)}, "
            + $"i64 {_program.Types.FieldOffsetOf(buffers.ElementType, bytesField.Index)}, "
            + $"i64 {_program.Types.FieldOffsetOf(buffers.ElementType, offsetField.Index)}, "
            + $"i64 {_program.Types.FieldOffsetOf(buffers.ElementType, lengthField.Index)}");
        return EmitSocketCountResult(function, raw);
    }

    private RuntimeEnum EmitSocketReceiveVectored(
        BoundFunction function,
        RuntimeStruct stream,
        RuntimeValue target)
    {
        if (target is not RuntimeMutableContainerReference buffers
            || !_program.Types.IsDynamicArray(buffers.TargetType))
        {
            throw new SollangException("socket receiveVectored expects mut [std.net.socket.ReceiveBuffer; ~]");
        }

        var elementType = _program.Types.GetDynamicArray(buffers.TargetType).ElementType;
        if (!_program.Types.IsStruct(elementType)
            || _program.Types.GetStruct(elementType) is not { Name: "std.net.socket.ReceiveBuffer" } definition
            || definition.Fields.Count != 1)
        {
            throw new SollangException("socket receiveVectored expects mut [std.net.socket.ReceiveBuffer; ~]");
        }

        var bytesField = definition.GetField("bytes");
        if (!_program.Types.IsDynamicArray(bytesField.Type)
            || _program.Types.GetDynamicArray(bytesField.Type).ElementType != BoundType.UInt8)
        {
            throw new SollangException("socket ReceiveBuffer must contain [UInt8; ~]");
        }

        var pointer = NextTemp("socket_receive_vectored_pointer");
        var length = NextTemp("socket_receive_vectored_length");
        EmitLoad(pointer, "ptr", buffers.PointerAddress, 8);
        EmitLoad(length, "i64", buffers.LengthAddress, 8);
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_receive_vectored",
            $"i64 {ExtractSocketHandle(stream, "std.net.socket.TcpStream")}, ptr {pointer}, i64 {length}, "
            + $"i64 {_program.Types.InlineSizeOf(elementType)}, "
            + $"i64 {_program.Types.FieldOffsetOf(elementType, bytesField.Index)}");
        return EmitSocketCountResult(function, raw);
    }

    private RuntimeEnum EmitSocketShutdown(
        BoundFunction function,
        RuntimeStruct stream,
        RuntimeEnum direction)
    {
        if (!string.Equals(
                _program.Types.GetEnum(direction.Type).Name,
                "std.net.socket.ShutdownDirection",
                StringComparison.Ordinal))
        {
            throw new SollangException("socket shutdown direction must be std.net.socket.ShutdownDirection");
        }
        var directionTag = NextTemp("socket_shutdown_direction");
        EmitAssign(directionTag, $"extractvalue {LlvmEnumType(direction.Type)} {direction.ValueName}, 0");
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_shutdown",
            $"i64 {ExtractSocketHandle(stream, "std.net.socket.TcpStream")}, i32 {directionTag}");
        return EmitSocketResult(function, raw, RuntimeUnit.Instance);
    }

    private RuntimeEnum EmitSocketSetNoDelay(
        BoundFunction function,
        RuntimeStruct stream,
        RuntimeBool enabled)
    {
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_set_no_delay",
            $"i64 {ExtractSocketHandle(stream, "std.net.socket.TcpStream")}, i1 {enabled.ValueName}");
        return EmitSocketResult(function, raw, RuntimeUnit.Instance);
    }

    private RuntimeEnum EmitSocketNoDelay(BoundFunction function, RuntimeStruct stream)
    {
        var resultTypes = ValidateSocketResult(function);
        if (resultTypes.Ok != BoundType.Bool)
        {
            throw new SollangException($"{function.Name} must return a Bool result");
        }
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_no_delay",
            $"i64 {ExtractSocketHandle(stream, "std.net.socket.TcpStream")}");
        var enabled = NextTemp("socket_no_delay");
        EmitCompare(enabled, "ne", "i64", raw.Value, "0");
        return EmitSocketResult(function, raw, new RuntimeBool(enabled));
    }

    private RuntimeEnum EmitSocketSetKeepAlive(
        BoundFunction function,
        RuntimeStruct stream,
        RuntimeBool enabled)
    {
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_set_keep_alive",
            $"i64 {ExtractSocketHandle(stream, "std.net.socket.TcpStream")}, i1 {enabled.ValueName}");
        return EmitSocketResult(function, raw, RuntimeUnit.Instance);
    }

    private RuntimeEnum EmitSocketKeepAlive(BoundFunction function, RuntimeStruct stream)
    {
        var resultTypes = ValidateSocketResult(function);
        if (resultTypes.Ok != BoundType.Bool)
        {
            throw new SollangException($"{function.Name} must return a Bool result");
        }
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_keep_alive",
            $"i64 {ExtractSocketHandle(stream, "std.net.socket.TcpStream")}");
        var enabled = NextTemp("socket_keep_alive");
        EmitCompare(enabled, "ne", "i64", raw.Value, "0");
        return EmitSocketResult(function, raw, new RuntimeBool(enabled));
    }

    private RuntimeEnum EmitSocketSetLinger(
        BoundFunction function,
        RuntimeStruct stream,
        RuntimeEnum linger)
    {
        if (!_program.Types.TryGetOptionValue(linger.Type, out var durationType)
            || !IsRuntimeNamedStruct(durationType, "std.time.Duration"))
        {
            throw new SollangException($"{function.Name} linger must be Option<std.time.Duration>");
        }
        var optionDefinition = _program.Types.GetEnum(linger.Type);
        var someVariant = optionDefinition.Variants.First(variant => variant.Name == "Some");
        var tag = NextTemp("socket_linger_tag");
        EmitAssign(tag, $"extractvalue {LlvmEnumType(linger.Type)} {linger.ValueName}, 0");
        var enabled = NextTemp("socket_linger_enabled");
        EmitCompare(
            enabled,
            "eq",
            "i32",
            tag,
            someVariant.Tag.ToString(CultureInfo.InvariantCulture));
        var duration = ExtractEnumPayload(linger, durationType) as RuntimeStruct
            ?? throw new SollangException($"{function.Name} linger payload must be std.time.Duration");
        var millis = SocketStructField(duration, "millis") as RuntimeInt
            ?? throw new SollangException("std.time.Duration.millis must be Long");
        if (millis.Type != BoundType.Int64)
        {
            throw new SollangException("std.time.Duration.millis must be Long");
        }
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_set_linger",
            $"i64 {ExtractSocketHandle(stream, "std.net.socket.TcpStream")}, i1 {enabled}, i64 {millis.ValueName}");
        return EmitSocketResult(function, raw, RuntimeUnit.Instance);
    }

    private RuntimeEnum EmitSocketLinger(BoundFunction function, RuntimeStruct stream)
    {
        var resultTypes = ValidateSocketResult(function);
        if (!_program.Types.TryGetOptionValue(resultTypes.Ok, out var durationType)
            || !IsRuntimeNamedStruct(durationType, "std.time.Duration"))
        {
            throw new SollangException($"{function.Name} must return Result<Option<Duration>, SocketError>");
        }
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_linger",
            $"i64 {ExtractSocketHandle(stream, "std.net.socket.TcpStream")}");
        var present = NextTemp("socket_linger_present");
        EmitCompare(present, "sge", "i64", raw.Value, "0");
        var someLabel = NextLabel("socket_linger_some");
        var noneLabel = NextLabel("socket_linger_none");
        var endLabel = NextLabel("socket_linger_end");
        EmitConditionalBranch(present, someLabel, noneLabel);

        var optionDefinition = _program.Types.GetEnum(resultTypes.Ok);
        var someVariant = optionDefinition.Variants.First(variant => variant.Name == "Some");
        var noneVariant = optionDefinition.Variants.First(variant => variant.Name == "None");
        EmitLabel(someLabel);
        _currentBlockLabel = someLabel;
        var durationValue = NextTemp("socket_linger_duration");
        EmitAssign(durationValue,
            $"insertvalue {LlvmStructType(durationType)} poison, i64 {raw.Value}, 0");
        var some = EmitEnumValue(
            resultTypes.Ok,
            someVariant,
            new RuntimeStruct(durationType, durationValue));
        EmitBranch(endLabel);
        var someExit = _currentBlockLabel;

        EmitLabel(noneLabel);
        _currentBlockLabel = noneLabel;
        var none = EmitEnumValue(resultTypes.Ok, noneVariant, payload: null);
        EmitBranch(endLabel);
        var noneExit = _currentBlockLabel;

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        var linger = EmitEnumPhi(
            "socket_linger_option",
            resultTypes.Ok,
            [(some, someExit), (none, noneExit)]);
        return EmitSocketResult(function, raw, linger);
    }

    private RuntimeEnum EmitSocketSetTimeout(
        BoundFunction function,
        RuntimeStruct stream,
        RuntimeEnum timeout,
        bool write)
    {
        if (!_program.Types.TryGetOptionValue(timeout.Type, out var durationType)
            || !IsRuntimeNamedStruct(durationType, "std.time.Duration"))
        {
            throw new SollangException($"{function.Name} timeout must be Option<std.time.Duration>");
        }
        var optionDefinition = _program.Types.GetEnum(timeout.Type);
        var someVariant = optionDefinition.Variants.First(variant => variant.Name == "Some");
        var tag = NextTemp("socket_timeout_tag");
        EmitAssign(tag, $"extractvalue {LlvmEnumType(timeout.Type)} {timeout.ValueName}, 0");
        var hasTimeout = NextTemp("socket_timeout_present");
        EmitCompare(
            hasTimeout,
            "eq",
            "i32",
            tag,
            someVariant.Tag.ToString(CultureInfo.InvariantCulture));
        var duration = ExtractEnumPayload(timeout, durationType) as RuntimeStruct
            ?? throw new SollangException($"{function.Name} timeout payload must be std.time.Duration");
        var millis = SocketStructField(duration, "millis") as RuntimeInt
            ?? throw new SollangException("std.time.Duration.millis must be Long");
        if (millis.Type != BoundType.Int64)
        {
            throw new SollangException("std.time.Duration.millis must be Long");
        }
        var operation = write ? "write" : "read";
        var raw = EmitSocketPlatformResult(
            $"sollang_platform_socket_set_{operation}_timeout",
            $"i64 {ExtractSocketHandle(stream, "std.net.socket.TcpStream")}, i1 {hasTimeout}, i64 {millis.ValueName}");
        return EmitSocketResult(function, raw, RuntimeUnit.Instance);
    }

    private RuntimeEnum EmitSocketTimeout(
        BoundFunction function,
        RuntimeStruct stream,
        bool write)
    {
        var resultTypes = ValidateSocketResult(function);
        if (!_program.Types.TryGetOptionValue(resultTypes.Ok, out var durationType)
            || !IsRuntimeNamedStruct(durationType, "std.time.Duration"))
        {
            throw new SollangException($"{function.Name} must return Result<Option<Duration>, SocketError>");
        }
        var operation = write ? "write" : "read";
        var raw = EmitSocketPlatformResult(
            $"sollang_platform_socket_{operation}_timeout",
            $"i64 {ExtractSocketHandle(stream, "std.net.socket.TcpStream")}");
        var present = NextTemp("socket_timeout_present");
        EmitCompare(present, "sge", "i64", raw.Value, "0");
        var someLabel = NextLabel("socket_timeout_some");
        var noneLabel = NextLabel("socket_timeout_none");
        var endLabel = NextLabel("socket_timeout_end");
        EmitConditionalBranch(present, someLabel, noneLabel);

        var optionDefinition = _program.Types.GetEnum(resultTypes.Ok);
        var someVariant = optionDefinition.Variants.First(variant => variant.Name == "Some");
        var noneVariant = optionDefinition.Variants.First(variant => variant.Name == "None");
        EmitLabel(someLabel);
        _currentBlockLabel = someLabel;
        var durationValue = NextTemp("socket_timeout_duration");
        EmitAssign(durationValue,
            $"insertvalue {LlvmStructType(durationType)} poison, i64 {raw.Value}, 0");
        var some = EmitEnumValue(
            resultTypes.Ok,
            someVariant,
            new RuntimeStruct(durationType, durationValue));
        EmitBranch(endLabel);
        var someExit = _currentBlockLabel;

        EmitLabel(noneLabel);
        _currentBlockLabel = noneLabel;
        var none = EmitEnumValue(resultTypes.Ok, noneVariant, payload: null);
        EmitBranch(endLabel);
        var noneExit = _currentBlockLabel;

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        var timeout = EmitEnumPhi(
            "socket_timeout_option",
            resultTypes.Ok,
            [(some, someExit), (none, noneExit)]);
        return EmitSocketResult(function, raw, timeout);
    }

    private RuntimeEnum EmitSocketBindDatagram(BoundFunction function, RuntimeStruct options)
    {
        var endpoint = SocketStructField(options, "endpoint") as RuntimeEnum
            ?? throw new SollangException("datagram bind endpoint must be std.net.Endpoint");
        var endpointPointer = EmitSocketEndpointDescriptor(endpoint);
        var reuseAddress = SocketStructField(options, "reuseAddress") as RuntimeBool
            ?? throw new SollangException("socket reuseAddress must be Bool");
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_bind_datagram",
            $"ptr {endpointPointer}, i1 {reuseAddress.ValueName}");
        return EmitSocketOwnerResult(function, raw, "std.net.socket.UdpSocket");
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
        var endpoint = RequireSocketEnum(arguments[0], function.Name, "std.net.Endpoint");
        var endpointPointer = EmitSocketEndpointDescriptor(endpoint);
        var bytes = SocketByteArray(arguments[1]);
        if (bytes.ElementType != BoundType.UInt8)
        {
            throw new SollangException("socket sendTo bytes must be a UInt8 array");
        }
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_send_to",
            $"i64 {ExtractSocketHandle(socket, "std.net.socket.UdpSocket")}, ptr {endpointPointer}, "
            + $"ptr {bytes.PointerName}, i64 {bytes.LengthName}");
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
            $"i64 {ExtractSocketHandle(socket, _program.Types.GetStruct(socket.Type).Name)}");
        var port = NextTemp("socket_local_port");
        EmitInstruction($"{port} = trunc i64 {raw.Value} to i16");
        return EmitSocketResult(function, raw, new RuntimeInt(BoundType.UInt16, port));
    }

    private RuntimeEnum EmitSocketObservedEndpoint(
        BoundFunction function,
        RuntimeStruct socket,
        bool remote)
    {
        var resultTypes = ValidateSocketResult(function);
        if (!IsRuntimeNamedEnum(resultTypes.Ok, "std.net.Endpoint"))
        {
            throw new SollangException($"{function.Name} must return a std.net.Endpoint result");
        }
        var descriptor = NextTemp(remote ? "socket_remote_endpoint_descriptor" : "socket_local_endpoint_descriptor");
        EmitAlloca(descriptor, "[32 x i8]", 8);
        EmitCall(
            target: null,
            "void",
            "llvm.memset.p0.i64",
            $"ptr {descriptor}, i8 0, i64 32, i1 false");
        var operation = remote ? "remote_endpoint" : "local_endpoint";
        var raw = EmitSocketPlatformResult(
            $"sollang_platform_socket_{operation}",
            $"i64 {ExtractSocketHandle(socket, _program.Types.GetStruct(socket.Type).Name)}, ptr {descriptor}");
        var endpoint = EmitSocketEndpointFromDescriptor(resultTypes.Ok, descriptor);
        return EmitSocketResult(function, raw, endpoint);
    }

    private RuntimeEnum EmitSocketReceiveFrom(
        BoundFunction function,
        RuntimeStruct socket,
        RuntimeValue target,
        bool peek)
    {
        return target switch
        {
            RuntimeInt maximum when !peek => EmitSocketReceiveFromAllocated(function, socket, maximum),
            RuntimeMutableContainerReference buffer => EmitSocketReceiveFromInto(function, socket, buffer, peek),
            _ => throw new SollangException("socket receiveFrom expects UIntSize or mut [UInt8; ~]")
        };
    }

    private RuntimeEnum EmitSocketReceiveFromAllocated(
        BoundFunction function,
        RuntimeStruct socket,
        RuntimeInt maximum)
    {
        if (maximum.Type != BoundType.UIntSize)
        {
            throw new SollangException("socket receiveFrom maxBytes must be UIntSize");
        }
        var resultTypes = ValidateSocketResult(function);
        if (!IsRuntimeNamedStruct(resultTypes.Ok, "std.net.socket.Datagram"))
        {
            throw new SollangException($"{function.Name} must return a Datagram result");
        }
        var datagramDefinition = _program.Types.GetStruct(resultTypes.Ok);
        var sourceField = datagramDefinition.GetField("source");
        if (!IsRuntimeNamedEnum(sourceField.Type, "std.net.Endpoint"))
        {
            throw new SollangException("std.net.socket.Datagram.source must be std.net.Endpoint");
        }
        var bytesField = datagramDefinition.GetField("bytes");
        var truncatedField = datagramDefinition.GetField("truncated");
        if (truncatedField.Type != BoundType.Bool)
        {
            throw new SollangException("std.net.socket.Datagram.truncated must be Bool");
        }
        var maximumIsZero = NextTemp("socket_datagram_maximum_is_zero");
        EmitCompare(maximumIsZero, "eq", "i64", maximum.ValueName, "0");
        var allocatedBytes = NextTemp("socket_datagram_allocated_bytes");
        EmitSelect(allocatedBytes, maximumIsZero, "i64 1", $"i64 {maximum.ValueName}");
        var bytesBuffer = EmitHeapAllocate(allocatedBytes);
        var endpointDescriptor = NextTemp("socket_datagram_endpoint_descriptor");
        EmitAlloca(endpointDescriptor, "[32 x i8]", 8);
        EmitCall(
            target: null,
            "void",
            "llvm.memset.p0.i64",
            $"ptr {endpointDescriptor}, i8 0, i64 32, i1 false");
        var truncatedAddress = NextTemp("socket_datagram_truncated_address");
        EmitAlloca(truncatedAddress, "i8", 1);
        EmitStore("i8", "0", truncatedAddress, 1);
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_receive_from",
            $"i64 {ExtractSocketHandle(socket, "std.net.socket.UdpSocket")}, ptr {bytesBuffer}, i64 {maximum.ValueName}, "
            + $"i32 0, ptr {endpointDescriptor}, ptr {truncatedAddress}");
        var source = EmitSocketEndpointFromDescriptor(sourceField.Type, endpointDescriptor);
        var bytesArray = new RuntimeDynamicInlineArray(
            bytesField.Type, BoundType.UInt8, bytesBuffer, raw.Value, maximum.ValueName);
        var sourceValue = MaterializeAggregateValue(source);
        var bytesValue = MaterializeAggregateValue(bytesArray);
        var withSource = NextTemp("socket_datagram_with_source");
        EmitAssign(withSource,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} poison, {sourceValue.TypeName} {sourceValue.ValueName}, {sourceField.Index.ToString(CultureInfo.InvariantCulture)}");
        var aggregate = NextTemp("socket_datagram_value");
        EmitAssign(aggregate,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} {withSource}, {bytesValue.TypeName} {bytesValue.ValueName}, {bytesField.Index.ToString(CultureInfo.InvariantCulture)}");
        var truncatedByte = NextTemp("socket_datagram_truncated_byte");
        EmitLoad(truncatedByte, "i8", truncatedAddress, 1);
        var truncated = NextTemp("socket_datagram_truncated");
        EmitCompare(truncated, "ne", "i8", truncatedByte, "0");
        var completed = NextTemp("socket_datagram_completed");
        EmitAssign(completed,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} {aggregate}, i1 {truncated}, {truncatedField.Index.ToString(CultureInfo.InvariantCulture)}");
        return EmitSocketResult(function, raw, new RuntimeStruct(resultTypes.Ok, completed), () =>
        {
            EmitCall(target: null, "void", "sollang_free", $"ptr {bytesBuffer}");
        });
    }

    private RuntimeEnum EmitSocketReceiveFromInto(
        BoundFunction function,
        RuntimeStruct socket,
        RuntimeMutableContainerReference buffer,
        bool peek)
    {
        if (!_program.Types.IsDynamicArray(buffer.TargetType)
            || _program.Types.GetDynamicArray(buffer.TargetType).ElementType != BoundType.UInt8)
        {
            throw new SollangException("socket receiveFromInto expects mut [UInt8; ~]");
        }
        var resultTypes = ValidateSocketResult(function);
        if (!IsRuntimeNamedStruct(resultTypes.Ok, "std.net.socket.DatagramReceipt"))
        {
            throw new SollangException($"{function.Name} must return a DatagramReceipt result");
        }
        var receiptDefinition = _program.Types.GetStruct(resultTypes.Ok);
        var sourceField = receiptDefinition.GetField("source");
        if (!IsRuntimeNamedEnum(sourceField.Type, "std.net.Endpoint"))
        {
            throw new SollangException("std.net.socket.DatagramReceipt.source must be std.net.Endpoint");
        }
        var countField = receiptDefinition.GetField("count");
        if (countField.Type != BoundType.UIntSize)
        {
            throw new SollangException("std.net.socket.DatagramReceipt.count must be UIntSize");
        }
        var truncatedField = receiptDefinition.GetField("truncated");
        if (truncatedField.Type != BoundType.Bool)
        {
            throw new SollangException("std.net.socket.DatagramReceipt.truncated must be Bool");
        }
        var pointer = NextTemp("socket_datagram_into_pointer");
        var capacity = NextTemp("socket_datagram_into_capacity");
        EmitLoad(pointer, "ptr", buffer.PointerAddress, 8);
        EmitLoad(capacity, "i64", buffer.CapacityAddress, 8);
        var endpointDescriptor = NextTemp("socket_datagram_into_endpoint_descriptor");
        EmitAlloca(endpointDescriptor, "[32 x i8]", 8);
        EmitCall(
            target: null,
            "void",
            "llvm.memset.p0.i64",
            $"ptr {endpointDescriptor}, i8 0, i64 32, i1 false");
        var truncatedAddress = NextTemp("socket_datagram_into_truncated_address");
        EmitAlloca(truncatedAddress, "i8", 1);
        EmitStore("i8", "0", truncatedAddress, 1);
        var raw = EmitSocketPlatformResult(
            "sollang_platform_socket_receive_from",
            $"i64 {ExtractSocketHandle(socket, "std.net.socket.UdpSocket")}, ptr {pointer}, i64 {capacity}, "
            + $"i32 {(peek ? "2" : "0")}, ptr {endpointDescriptor}, ptr {truncatedAddress}");
        var source = MaterializeAggregateValue(
            EmitSocketEndpointFromDescriptor(sourceField.Type, endpointDescriptor));
        var withSource = NextTemp("socket_datagram_receipt_with_source");
        EmitAssign(withSource,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} poison, {source.TypeName} {source.ValueName}, {sourceField.Index.ToString(CultureInfo.InvariantCulture)}");
        var receipt = NextTemp("socket_datagram_receipt");
        EmitAssign(receipt,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} {withSource}, i64 {raw.Value}, {countField.Index.ToString(CultureInfo.InvariantCulture)}");
        var truncatedByte = NextTemp("socket_datagram_into_truncated_byte");
        EmitLoad(truncatedByte, "i8", truncatedAddress, 1);
        var truncated = NextTemp("socket_datagram_into_truncated");
        EmitCompare(truncated, "ne", "i8", truncatedByte, "0");
        var completed = NextTemp("socket_datagram_receipt_completed");
        EmitAssign(completed,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} {receipt}, i1 {truncated}, {truncatedField.Index.ToString(CultureInfo.InvariantCulture)}");
        return EmitSocketResult(
            function,
            raw,
            new RuntimeStruct(resultTypes.Ok, completed),
            successAction: () => EmitStore("i64", raw.Value, buffer.LengthAddress, 8));
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
        Action? failureCleanup = null,
        Action? successAction = null)
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
        successAction?.Invoke();
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
        if (!IsRuntimeNamedStruct(errorType, "std.net.socket.SocketError"))
        {
            throw new SollangException("socket error result must be std.net.socket.SocketError");
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

    // Canonical native socket descriptor (32 bytes, host-order scalar fields):
    // family:i32, address:[8 x i16], port:i16, padding:i16,
    // flowInfo:i32, scopeId:i32. IPv4 stores its four octets in the low byte of
    // the first four address groups. The platform runtime performs only ABI
    // packing and byte-order conversion; it never reparses text or resolves DNS.
    private string EmitSocketEndpointDescriptor(RuntimeEnum endpoint)
    {
        if (!IsRuntimeNamedEnum(endpoint.Type, "std.net.Endpoint"))
        {
            throw new SollangException("socket endpoint must be std.net.Endpoint");
        }

        var definition = _program.Types.GetEnum(endpoint.Type);
        var ipv4Variant = definition.Variants.FirstOrDefault(static variant => variant.Name == "V4")
            ?? throw new SollangException("std.net.Endpoint must define V4");
        var ipv6Variant = definition.Variants.FirstOrDefault(static variant => variant.Name == "V6")
            ?? throw new SollangException("std.net.Endpoint must define V6");
        var ipv4Type = ipv4Variant.PayloadType
            ?? throw new SollangException("std.net.Endpoint.V4 must carry std.net.Ipv4Endpoint");
        var ipv6Type = ipv6Variant.PayloadType
            ?? throw new SollangException("std.net.Endpoint.V6 must carry std.net.Ipv6Endpoint");
        if (!IsRuntimeNamedStruct(ipv4Type, "std.net.Ipv4Endpoint")
            || !IsRuntimeNamedStruct(ipv6Type, "std.net.Ipv6Endpoint"))
        {
            throw new SollangException("std.net.Endpoint has invalid payload types");
        }

        var descriptor = NextTemp("socket_endpoint_descriptor");
        EmitAlloca(descriptor, "[32 x i8]", 8);
        EmitCall(target: null, "void", "llvm.memset.p0.i64", $"ptr {descriptor}, i8 0, i64 32, i1 false");
        var tag = NextTemp("socket_endpoint_tag");
        EmitAssign(tag, $"extractvalue {LlvmEnumType(endpoint.Type)} {endpoint.ValueName}, 0");
        var isIpv4 = NextTemp("socket_endpoint_is_ipv4");
        EmitCompare(
            isIpv4,
            "eq",
            "i32",
            tag,
            ipv4Variant.Tag.ToString(CultureInfo.InvariantCulture));
        var ipv4Label = NextLabel("socket_endpoint_ipv4");
        var ipv6Label = NextLabel("socket_endpoint_ipv6");
        var completeLabel = NextLabel("socket_endpoint_complete");
        EmitConditionalBranch(isIpv4, ipv4Label, ipv6Label);

        EmitLabel(ipv4Label);
        _currentBlockLabel = ipv4Label;
        var ipv4 = ExtractEnumPayload(endpoint, ipv4Type) as RuntimeStruct
            ?? throw new SollangException("std.net.Endpoint.V4 payload must be a struct");
        var ipv4Address = SocketStructField(ipv4, "address") as RuntimeStruct
            ?? throw new SollangException("std.net.Ipv4Endpoint.address must be a struct");
        StoreSocketDescriptor(descriptor, 0, "i32", "4", 4, "family4");
        foreach (var (field, offset) in new[] { ("a", 4), ("b", 6), ("c", 8), ("d", 10) })
        {
            var octet = SocketStructField(ipv4Address, field) as RuntimeInt
                ?? throw new SollangException($"std.net.Ipv4Address.{field} must be UInt8");
            var widened = NextTemp("socket_ipv4_octet");
            EmitInstruction($"{widened} = zext i8 {octet.ValueName} to i16");
            StoreSocketDescriptor(descriptor, offset, "i16", widened, 2, "ipv4_" + field);
        }
        var ipv4Port = SocketStructField(ipv4, "port") as RuntimeInt
            ?? throw new SollangException("std.net.Ipv4Endpoint.port must be UInt16");
        StoreSocketDescriptor(descriptor, 20, "i16", ipv4Port.ValueName, 2, "port4");
        EmitBranch(completeLabel);

        EmitLabel(ipv6Label);
        _currentBlockLabel = ipv6Label;
        var ipv6 = ExtractEnumPayload(endpoint, ipv6Type) as RuntimeStruct
            ?? throw new SollangException("std.net.Endpoint.V6 payload must be a struct");
        var ipv6Address = SocketStructField(ipv6, "address") as RuntimeStruct
            ?? throw new SollangException("std.net.Ipv6Endpoint.address must be a struct");
        StoreSocketDescriptor(descriptor, 0, "i32", "6", 4, "family6");
        var ipv6Fields = new[] { "a", "b", "c", "d", "e", "f", "g", "h" };
        for (var index = 0; index < ipv6Fields.Length; index++)
        {
            var group = SocketStructField(ipv6Address, ipv6Fields[index]) as RuntimeInt
                ?? throw new SollangException($"std.net.Ipv6Address.{ipv6Fields[index]} must be UInt16");
            StoreSocketDescriptor(
                descriptor,
                4 + index * 2,
                "i16",
                group.ValueName,
                2,
                "ipv6_" + ipv6Fields[index]);
        }
        var ipv6Port = SocketStructField(ipv6, "port") as RuntimeInt
            ?? throw new SollangException("std.net.Ipv6Endpoint.port must be UInt16");
        var flowInfo = SocketStructField(ipv6, "flowInfo") as RuntimeInt
            ?? throw new SollangException("std.net.Ipv6Endpoint.flowInfo must be UInt32");
        var scopeId = SocketStructField(ipv6, "scopeId") as RuntimeInt
            ?? throw new SollangException("std.net.Ipv6Endpoint.scopeId must be UInt32");
        StoreSocketDescriptor(descriptor, 20, "i16", ipv6Port.ValueName, 2, "port6");
        StoreSocketDescriptor(descriptor, 24, "i32", flowInfo.ValueName, 4, "flow6");
        StoreSocketDescriptor(descriptor, 28, "i32", scopeId.ValueName, 4, "scope6");
        EmitBranch(completeLabel);

        EmitLabel(completeLabel);
        _currentBlockLabel = completeLabel;
        return descriptor;
    }

    private RuntimeEnum EmitSocketEndpointFromDescriptor(BoundType endpointType, string descriptor)
    {
        if (!IsRuntimeNamedEnum(endpointType, "std.net.Endpoint"))
        {
            throw new SollangException("socket endpoint descriptor target must be std.net.Endpoint");
        }

        var definition = _program.Types.GetEnum(endpointType);
        var ipv4Variant = definition.Variants.First(static variant => variant.Name == "V4");
        var ipv6Variant = definition.Variants.First(static variant => variant.Name == "V6");
        var ipv4Type = ipv4Variant.PayloadType
            ?? throw new SollangException("std.net.Endpoint.V4 payload is missing");
        var ipv6Type = ipv6Variant.PayloadType
            ?? throw new SollangException("std.net.Endpoint.V6 payload is missing");
        var family = LoadSocketDescriptor(descriptor, 0, "i32", 4, "source_family");
        var isIpv4 = NextTemp("socket_source_is_ipv4");
        EmitCompare(isIpv4, "eq", "i32", family, "4");
        var ipv4Label = NextLabel("socket_source_ipv4");
        var ipv6Label = NextLabel("socket_source_ipv6");
        var completeLabel = NextLabel("socket_source_complete");
        EmitConditionalBranch(isIpv4, ipv4Label, ipv6Label);

        EmitLabel(ipv4Label);
        _currentBlockLabel = ipv4Label;
        var ipv4Definition = _program.Types.GetStruct(ipv4Type);
        var ipv4AddressType = ipv4Definition.GetField("address").Type;
        var ipv4Address = EmitSocketStructValue(
            ipv4AddressType,
            new[] { "a", "b", "c", "d" }.Select((name, index) =>
            {
                var group = LoadSocketDescriptor(descriptor, 4 + index * 2, "i16", 2, "source_ipv4_" + name);
                var octet = NextTemp("socket_source_ipv4_octet");
                EmitInstruction($"{octet} = trunc i16 {group} to i8");
                return (name, (RuntimeValue)new RuntimeInt(BoundType.UInt8, octet));
            }).ToArray());
        var ipv4Port = LoadSocketDescriptor(descriptor, 20, "i16", 2, "source_ipv4_port");
        var ipv4Endpoint = EmitSocketStructValue(
            ipv4Type,
            [("address", ipv4Address), ("port", new RuntimeInt(BoundType.UInt16, ipv4Port))]);
        var ipv4 = EmitEnumValue(endpointType, ipv4Variant, ipv4Endpoint);
        EmitBranch(completeLabel);
        var ipv4Exit = _currentBlockLabel;

        EmitLabel(ipv6Label);
        _currentBlockLabel = ipv6Label;
        var ipv6Definition = _program.Types.GetStruct(ipv6Type);
        var ipv6AddressType = ipv6Definition.GetField("address").Type;
        var ipv6Address = EmitSocketStructValue(
            ipv6AddressType,
            new[] { "a", "b", "c", "d", "e", "f", "g", "h" }.Select((name, index) =>
                (name, (RuntimeValue)new RuntimeInt(
                    BoundType.UInt16,
                    LoadSocketDescriptor(descriptor, 4 + index * 2, "i16", 2, "source_ipv6_" + name))))
                .ToArray());
        var ipv6Port = LoadSocketDescriptor(descriptor, 20, "i16", 2, "source_ipv6_port");
        var flowInfo = LoadSocketDescriptor(descriptor, 24, "i32", 4, "source_ipv6_flow");
        var scopeId = LoadSocketDescriptor(descriptor, 28, "i32", 4, "source_ipv6_scope");
        var ipv6Endpoint = EmitSocketStructValue(
            ipv6Type,
            [
                ("address", ipv6Address),
                ("port", new RuntimeInt(BoundType.UInt16, ipv6Port)),
                ("flowInfo", new RuntimeInt(BoundType.UInt32, flowInfo)),
                ("scopeId", new RuntimeInt(BoundType.UInt32, scopeId))
            ]);
        var ipv6 = EmitEnumValue(endpointType, ipv6Variant, ipv6Endpoint);
        EmitBranch(completeLabel);
        var ipv6Exit = _currentBlockLabel;

        EmitLabel(completeLabel);
        _currentBlockLabel = completeLabel;
        return EmitEnumPhi("socket_source_endpoint", endpointType, [(ipv4, ipv4Exit), (ipv6, ipv6Exit)]);
    }

    private RuntimeStruct EmitSocketStructValue(
        BoundType type,
        IReadOnlyList<(string Name, RuntimeValue Value)> fields)
    {
        var definition = _program.Types.GetStruct(type);
        var aggregate = "poison";
        foreach (var (name, value) in fields)
        {
            var field = definition.GetField(name);
            var materialized = MaterializeAggregateValue(value);
            var inserted = NextTemp("socket_struct_field");
            EmitAssign(
                inserted,
                $"insertvalue {LlvmStructType(type)} {aggregate}, {materialized.TypeName} {materialized.ValueName}, {field.Index.ToString(CultureInfo.InvariantCulture)}");
            aggregate = inserted;
        }
        return new RuntimeStruct(type, aggregate);
    }

    private string LoadSocketDescriptor(
        string descriptor,
        int offset,
        string llvmType,
        int alignment,
        string suffix)
    {
        var address = NextTemp("socket_endpoint_" + suffix + "_address");
        EmitAssign(address, $"getelementptr i8, ptr {descriptor}, i64 {offset.ToString(CultureInfo.InvariantCulture)}");
        var value = NextTemp("socket_endpoint_" + suffix);
        EmitLoad(value, llvmType, address, alignment);
        return value;
    }

    private void StoreSocketDescriptor(
        string descriptor,
        int offset,
        string llvmType,
        string value,
        int alignment,
        string suffix)
    {
        var address = NextTemp("socket_endpoint_" + suffix);
        EmitAssign(address, $"getelementptr i8, ptr {descriptor}, i64 {offset.ToString(CultureInfo.InvariantCulture)}");
        EmitStore(llvmType, value, address, alignment);
    }

    private RuntimeStruct RequireSocketStruct(RuntimeValue? value, string operation, string expectedName)
    {
        if (value is not RuntimeStruct structure || !IsRuntimeNamedStruct(structure.Type, expectedName))
        {
            throw new SollangException($"{operation} expects {expectedName}");
        }
        return structure;
    }

    private RuntimeStruct RequireSocketOwner(RuntimeValue? value, string operation)
    {
        if (value is not RuntimeStruct structure
            || !_program.Types.IsStruct(structure.Type)
            || _program.Types.GetStruct(structure.Type).Name is not (
                "std.net.socket.TcpListener"
                or "std.net.socket.TcpStream"
                or "std.net.socket.UdpSocket"))
        {
            throw new SollangException($"{operation} expects an owned socket");
        }
        return structure;
    }

    private RuntimeEnum RequireSocketEnum(RuntimeValue? value, string operation, string expectedName)
    {
        if (value is not RuntimeEnum enumeration || !IsRuntimeNamedEnum(enumeration.Type, expectedName))
        {
            throw new SollangException($"{operation} expects {expectedName}");
        }
        return enumeration;
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

    private bool IsRuntimeNamedEnum(BoundType type, string expectedName) =>
        _program.Types.IsEnum(type)
        && string.Equals(_program.Types.GetEnum(type).Name, expectedName, StringComparison.Ordinal);

    private (BoundType Ok, BoundType Error) ValidateSocketResult(BoundFunction function)
    {
        if (!_program.Types.TryGetResultTypes(function.ReturnType, out var resultTypes)
            || !IsRuntimeNamedStruct(resultTypes.Error, "std.net.socket.SocketError"))
        {
            throw new SollangException($"{function.Name} has an invalid socket result type");
        }
        return resultTypes;
    }

    private sealed record SocketPlatformResult(string Value, string Kind, string Code);
}
