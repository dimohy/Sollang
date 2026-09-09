using System.Globalization;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Semantics;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private RuntimeEnum EmitRuntimeDnsLookup(
        BoundFunction function,
        RuntimeValue? argument,
        IReadOnlyList<RuntimeValue> additionalArguments)
    {
        var resolver = RequireSocketStruct(argument, function.Name, "std.net.dns.Resolver");
        if (additionalArguments.Count != 2)
        {
            throw new SollangException("DNS lookup expects Text and UInt16");
        }
        var host = SocketText(additionalArguments[0]);
        if (additionalArguments[1] is not RuntimeInt { Type: var portType } port
            || portType != BoundType.UInt16)
        {
            throw new SollangException("DNS lookup port must be UInt16");
        }

        var family = SocketStructField(resolver, "family") as RuntimeEnum
            ?? throw new SollangException("DNS resolver family must be AddressFamily");
        var maximum = SocketStructField(resolver, "maxResults") as RuntimeInt
            ?? throw new SollangException("DNS resolver maxResults must be UIntSize");
        var maximumHostBytes = SocketStructField(resolver, "maxHostBytes") as RuntimeInt
            ?? throw new SollangException("DNS resolver maxHostBytes must be UIntSize");
        var familyTag = NextTemp("dns_family");
        EmitAssign(familyTag, $"extractvalue {LlvmEnumType(family.Type)} {family.ValueName}, 0");

        var descriptors = NextTemp("dns_descriptors");
        EmitAlloca(descriptors, "[2048 x i8]", 8);
        EmitCall(null, "void", "llvm.memset.p0.i64", $"ptr {descriptors}, i8 0, i64 2048, i1 false");
        var raw = EmitSocketPlatformResult(
            "sollang_platform_dns_lookup",
            $"i32 {familyTag}, ptr {host.PointerName}, i64 {host.LengthName}, i16 {port.ValueName}, "
            + $"i64 {maximumHostBytes.ValueName}, i64 {maximum.ValueName}, ptr {descriptors}");

        if (!_program.Types.TryGetResultTypes(function.ReturnType, out var resultTypes)
            || !_program.Types.IsDynamicArray(resultTypes.Ok)
            || !IsRuntimeNamedEnum(_program.Types.GetDynamicArray(resultTypes.Ok).ElementType, "std.net.Endpoint")
            || !IsRuntimeNamedStruct(resultTypes.Error, "std.net.dns.Error"))
        {
            throw new SollangException($"{function.Name} has an invalid DNS result type");
        }

        var definition = _program.Types.GetDynamicArray(resultTypes.Ok);
        var succeeded = NextTemp("dns_succeeded");
        EmitCompare(succeeded, "slt", "i32", raw.Kind, "0");
        var successLabel = NextLabel("dns_success");
        var failureLabel = NextLabel("dns_failure");
        var endLabel = NextLabel("dns_result_end");
        EmitConditionalBranch(succeeded, successLabel, failureLabel);

        EmitLabel(successLabel);
        _currentBlockLabel = successLabel;
        var bytes = NextTemp("dns_endpoint_bytes");
        EmitBinary(bytes, "mul", "i64", raw.Value,
            definition.ElementSize.ToString(CultureInfo.InvariantCulture));
        var endpointStorage = EmitHeapAllocate(bytes);
        var loopLabel = NextLabel("dns_copy");
        var latchLabel = NextLabel("dns_copy_next");
        var copiedLabel = NextLabel("dns_copied");
        EmitBranch(loopLabel);
        var loopEntry = _currentBlockLabel;

        EmitLabel(loopLabel);
        _currentBlockLabel = loopLabel;
        var index = NextTemp("dns_index");
        var next = NextTemp("dns_index_next");
        EmitPhi(index, "i64", ("0", loopEntry), (next, latchLabel));
        var done = NextTemp("dns_copy_done");
        EmitCompare(done, "uge", "i64", index, raw.Value);
        var itemLabel = NextLabel("dns_copy_item");
        EmitConditionalBranch(done, copiedLabel, itemLabel);

        EmitLabel(itemLabel);
        _currentBlockLabel = itemLabel;
        var descriptorOffset = NextTemp("dns_descriptor_offset");
        EmitBinary(descriptorOffset, "mul", "i64", index, "32");
        var descriptor = NextTemp("dns_descriptor");
        EmitAssign(descriptor, $"getelementptr i8, ptr {descriptors}, i64 {descriptorOffset}");
        var endpoint = EmitSocketEndpointFromDescriptor(definition.ElementType, descriptor);
        StoreDynamicInlineArrayElement(endpointStorage, definition, index, endpoint);
        EmitBranch(latchLabel);

        EmitLabel(latchLabel);
        _currentBlockLabel = latchLabel;
        EmitBinary(next, "add", "i64", index, "1");
        EmitBranch(loopLabel);

        EmitLabel(copiedLabel);
        _currentBlockLabel = copiedLabel;
        var endpoints = new RuntimeDynamicInlineArray(
            resultTypes.Ok, definition.ElementType, endpointStorage, raw.Value, raw.Value);
        var resultDefinition = _program.Types.GetEnum(function.ReturnType);
        var okVariant = resultDefinition.Variants.First(variant => variant.Name == "Ok");
        var errVariant = resultDefinition.Variants.First(variant => variant.Name == "Err");
        var success = EmitEnumValue(function.ReturnType, okVariant, endpoints);
        EmitBranch(endLabel);
        var successExit = _currentBlockLabel;

        EmitLabel(failureLabel);
        _currentBlockLabel = failureLabel;
        var errorDefinition = _program.Types.GetStruct(resultTypes.Error);
        var kindField = errorDefinition.GetField("kind");
        _ = errorDefinition.GetField("code");
        var kind = EmitRuntimeEnumTag(kindField.Type, raw.Kind, "dns_error_kind");
        var error = EmitSocketStructValue(
            resultTypes.Error,
            [("kind", kind), ("code", new RuntimeInt(BoundType.Int, raw.Code))]);
        var failure = EmitEnumValue(function.ReturnType, errVariant, error);
        EmitBranch(endLabel);
        var failureExit = _currentBlockLabel;

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        return EmitEnumPhi(
            "dns_result",
            function.ReturnType,
            [(success, successExit), (failure, failureExit)]);
    }

}
