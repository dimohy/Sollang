using System.Globalization;
using System.Numerics;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Semantics;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private RuntimeSourceText EmitBorrowSourceText(RuntimeValue value)
    {
        var text = value as RuntimeText
            ?? throw new SollangException("borrowText expects Text");
        return new RuntimeSourceText(text.PointerName, text.LengthName, "null", "0");
    }

    private RuntimeSourceText EmitBorrowSourceBytes(RuntimeValue value)
    {
        if (value is RuntimeReference reference)
        {
            value = LoadReference(reference);
        }
        if (value is not RuntimeDynamicInlineArray bytes || bytes.ElementType != BoundType.UInt8)
        {
            throw new SollangException("borrowBytes expects ref [UInt8; ~]");
        }
        return new RuntimeSourceText(bytes.PointerName, bytes.LengthName, "null", "0");
    }

    private RuntimeSourceText EmitMapSourceText(RuntimeValue value)
    {
        if (!_platform.SupportsMemoryMapping)
        {
            throw new SollangException("mapText is unavailable on the current target");
        }
        var path = value as RuntimeText
            ?? throw new SollangException("mapText path must be Text");
        var aggregate = NextTemp("source_text_mapped");
        EmitCall(aggregate, "%sollang.mapped_bytes", "sollang_map_file",
            $"ptr {path.PointerName}, i64 {path.LengthName}, i64 0, i64 0, i64 0, i1 false");
        var data = NextTemp("source_text_data");
        EmitAssign(data, $"extractvalue %sollang.mapped_bytes {aggregate}, 0");
        var valid = NextTemp("source_text_valid");
        EmitCompare(valid, "ne", "ptr", data, "null");
        EmitTrapUnless(valid, "source_text_open");
        var length = NextTemp("source_text_length");
        EmitAssign(length, $"extractvalue %sollang.mapped_bytes {aggregate}, 1");
        var basePointer = NextTemp("source_text_base");
        EmitAssign(basePointer, $"extractvalue %sollang.mapped_bytes {aggregate}, 2");
        var mappedLength = NextTemp("source_text_mapped_length");
        EmitAssign(mappedLength, $"extractvalue %sollang.mapped_bytes {aggregate}, 3");
        return new RuntimeSourceText(data, length, basePointer, mappedLength);
    }

    private RuntimeSourceText EmitReadStandardInputSourceText()
    {
        var bufferSlot = NextTemp("stdin_source_buffer_slot");
        EmitAlloca(bufferSlot, "ptr", 8);
        var lengthSlot = NextTemp("stdin_source_length_slot");
        EmitAlloca(lengthSlot, "i64", 8);
        var capacitySlot = NextTemp("stdin_source_capacity_slot");
        EmitAlloca(capacitySlot, "i64", 8);
        var initialBuffer = NextTemp("stdin_source_initial_buffer");
        EmitCall(initialBuffer, "ptr", "sollang_alloc", "i64 4096");
        var allocated = NextTemp("stdin_source_allocated");
        EmitCompare(allocated, "ne", "ptr", initialBuffer, "null");
        EmitTrapUnless(allocated, "stdin_source_allocate");
        EmitStore("ptr", initialBuffer, bufferSlot, 8);
        EmitStore("i64", "0", lengthSlot, 8);
        EmitStore("i64", "4096", capacitySlot, 8);

        var readLabel = NextLabel("stdin_source_read");
        var growLabel = NextLabel("stdin_source_grow");
        var doneLabel = NextLabel("stdin_source_done");
        EmitBranch(readLabel);
        EmitFunctionLine();

        EmitLabel(readLabel);
        _currentBlockLabel = readLabel;
        var buffer = NextTemp("stdin_source_buffer");
        EmitLoad(buffer, "ptr", bufferSlot, 8);
        var length = NextTemp("stdin_source_length");
        EmitLoad(length, "i64", lengthSlot, 8);
        var capacity = NextTemp("stdin_source_capacity");
        EmitLoad(capacity, "i64", capacitySlot, 8);
        var available = NextTemp("stdin_source_available");
        EmitAssign(available, $"sub i64 {capacity}, {length}");
        var destination = NextTemp("stdin_source_destination");
        EmitAssign(destination, $"getelementptr i8, ptr {buffer}, i64 {length}");
        var readOk = NextTemp("stdin_source_read_ok");
        EmitCall(readOk, "i32", "sollang_read_stdin",
            $"ptr %stdin, ptr {destination}, i64 {available}, ptr %read");
        var succeeded = NextTemp("stdin_source_read_succeeded");
        EmitCompare(succeeded, "ne", "i32", readOk, "0");
        EmitTrapUnless(succeeded, "stdin_source_read");
        var read32 = NextTemp("stdin_source_read32");
        EmitLoad(read32, "i32", "%read", 4);
        var read64 = NextTemp("stdin_source_read64");
        EmitAssign(read64, $"zext i32 {read32} to i64");
        var eof = NextTemp("stdin_source_eof");
        EmitCompare(eof, "eq", "i64", read64, "0");
        var nextLength = NextTemp("stdin_source_next_length");
        EmitAssign(nextLength, $"add i64 {length}, {read64}");
        EmitStore("i64", nextLength, lengthSlot, 8);
        EmitConditionalBranch(eof, doneLabel, growLabel);
        EmitFunctionLine();

        EmitLabel(growLabel);
        _currentBlockLabel = growLabel;
        var needsGrowth = NextTemp("stdin_source_needs_growth");
        EmitCompare(needsGrowth, "eq", "i64", nextLength, capacity);
        var resizeLabel = NextLabel("stdin_source_resize");
        EmitConditionalBranch(needsGrowth, resizeLabel, readLabel);
        EmitFunctionLine();

        EmitLabel(resizeLabel);
        _currentBlockLabel = resizeLabel;
        var nextCapacity = NextTemp("stdin_source_next_capacity");
        EmitAssign(nextCapacity, $"mul i64 {capacity}, 2");
        var resized = NextTemp("stdin_source_resized");
        EmitCall(resized, "ptr", "sollang_alloc", $"i64 {nextCapacity}");
        var resizeOk = NextTemp("stdin_source_resize_ok");
        EmitCompare(resizeOk, "ne", "ptr", resized, "null");
        EmitTrapUnless(resizeOk, "stdin_source_resize");
        var copyEntryLabel = _currentBlockLabel;
        var copyLabel = NextLabel("stdin_source_copy");
        var copyBodyLabel = NextLabel("stdin_source_copy_body");
        var copyDoneLabel = NextLabel("stdin_source_copy_done");
        EmitBranch(copyLabel);
        EmitFunctionLine();

        EmitLabel(copyLabel);
        _currentBlockLabel = copyLabel;
        var copyIndex = NextTemp("stdin_source_copy_index");
        var copyNext = NextTemp("stdin_source_copy_next");
        EmitInstruction($"{copyIndex} = phi i64 [ 0, %{copyEntryLabel} ], [ {copyNext}, %{copyBodyLabel} ]");
        var copyComplete = NextTemp("stdin_source_copy_complete");
        EmitCompare(copyComplete, "eq", "i64", copyIndex, nextLength);
        EmitConditionalBranch(copyComplete, copyDoneLabel, copyBodyLabel);
        EmitFunctionLine();

        EmitLabel(copyBodyLabel);
        _currentBlockLabel = copyBodyLabel;
        var oldByteAddress = NextTemp("stdin_source_old_byte_address");
        EmitAssign(oldByteAddress, $"getelementptr i8, ptr {buffer}, i64 {copyIndex}");
        var copiedByte = NextTemp("stdin_source_copied_byte");
        EmitLoad(copiedByte, "i8", oldByteAddress, 1);
        var newByteAddress = NextTemp("stdin_source_new_byte_address");
        EmitAssign(newByteAddress, $"getelementptr i8, ptr {resized}, i64 {copyIndex}");
        EmitStore("i8", copiedByte, newByteAddress, 1);
        EmitInstruction($"{copyNext} = add i64 {copyIndex}, 1");
        EmitBranch(copyLabel);
        EmitFunctionLine();

        EmitLabel(copyDoneLabel);
        _currentBlockLabel = copyDoneLabel;
        EmitCall(target: null, "void", "sollang_free", $"ptr {buffer}");
        EmitStore("ptr", resized, bufferSlot, 8);
        EmitStore("i64", nextCapacity, capacitySlot, 8);
        EmitBranch(readLabel);
        EmitFunctionLine();

        EmitLabel(doneLabel);
        _currentBlockLabel = doneLabel;
        var finalBuffer = NextTemp("stdin_source_final_buffer");
        EmitLoad(finalBuffer, "ptr", bufferSlot, 8);
        var finalLength = NextTemp("stdin_source_final_length");
        EmitLoad(finalLength, "i64", lengthSlot, 8);
        return new RuntimeSourceText(finalBuffer, finalLength, finalBuffer, "-1");
    }

    private RuntimeSourceText EmitMapSourcePath(RuntimeValue value)
    {
        if (value is not RuntimeStruct path
            || !_program.Types.IsStruct(path.Type)
            || _program.Types.GetStruct(path.Type) is not { Name: "sys.path.Path" } definition)
        {
            throw new SollangException("mapPath expects sys.path.Path");
        }

        var bytesField = definition.Fields.First(field => field.Name == "bytes");
        var styleField = definition.Fields.First(field => field.Name == "style");
        var bytesAggregate = NextTemp("source_path_bytes");
        EmitAssign(bytesAggregate,
            $"extractvalue {LlvmStructType(path.Type)} {path.ValueName}, {bytesField.Index.ToString(CultureInfo.InvariantCulture)}");
        if (DematerializeAggregateValue(bytesField.Type, bytesAggregate) is not RuntimeDynamicInlineArray bytes
            || bytes.ElementType != BoundType.UInt8)
        {
            throw new SollangException("sys.path.Path.bytes must be [UInt8; ~]");
        }

        var styleAggregate = NextTemp("source_path_style");
        EmitAssign(styleAggregate,
            $"extractvalue {LlvmStructType(path.Type)} {path.ValueName}, {styleField.Index.ToString(CultureInfo.InvariantCulture)}");
        var styleTag = NextTemp("source_path_style_tag");
        EmitAssign(styleTag, $"extractvalue {LlvmEnumType(styleField.Type)} {styleAggregate}, 0");
        var expectedStyle = _platform is WindowsLlvmRuntimePlatform ? 1 : 0;
        var validStyle = NextTemp("source_path_style_valid");
        EmitCompare(validStyle, "eq", "i32", styleTag, expectedStyle.ToString(CultureInfo.InvariantCulture));
        EmitTrapUnless(validStyle, "source_path_style");

        return EmitMapSourceText(new RuntimeText(bytes.PointerName, bytes.LengthName));
    }

    private RuntimeText EmitRuntimePathText(RuntimeValue value)
    {
        if (value is RuntimeReference reference)
        {
            value = LoadReference(reference);
        }
        else if (value is RuntimeMutableStructReference mutableReference)
        {
            var loaded = NextTemp("path_text_value");
            EmitLoad(
                loaded,
                LlvmType(mutableReference.TargetType),
                mutableReference.PointerAddress,
                RuntimeAlignment(mutableReference.TargetType));
            value = DematerializeAggregateValue(mutableReference.TargetType, loaded);
        }

        if (value is not RuntimeStruct path
            || !_program.Types.IsStruct(path.Type)
            || _program.Types.GetStruct(path.Type) is not { Name: "sys.path.Path" } definition)
        {
            throw new SollangException("pathText expects sys.path.Path");
        }

        var bytesField = definition.Fields.First(field => field.Name == "bytes");
        var bytesAggregate = NextTemp("path_text_bytes");
        EmitAssign(bytesAggregate,
            $"extractvalue {LlvmStructType(path.Type)} {path.ValueName}, {bytesField.Index.ToString(CultureInfo.InvariantCulture)}");
        if (DematerializeAggregateValue(bytesField.Type, bytesAggregate) is not RuntimeDynamicInlineArray bytes
            || bytes.ElementType != BoundType.UInt8)
        {
            throw new SollangException("sys.path.Path.bytes must be [UInt8; ~]");
        }

        return new RuntimeText(bytes.PointerName, bytes.LengthName);
    }

    private RuntimeEnum EmitRuntimePathStyle(BoundFunction function)
    {
        if (!_program.Types.IsEnum(function.ReturnType)
            || _program.Types.GetEnum(function.ReturnType) is not { Name: "sys.path.Style" } definition)
        {
            throw new SollangException("sys.path.nativeStyle must return sys.path.Style");
        }
        var variantName = _platform is WindowsLlvmRuntimePlatform ? "Windows" : "Posix";
        var variant = definition.Variants.First(candidate => candidate.Name == variantName);
        return EmitEnumValue(function.ReturnType, variant, payload: null);
    }

    private RuntimeMappedBytes EmitMapExpression(MapExpression expression)
    {
        if (!_platform.SupportsMemoryMapping)
        {
            throw new SollangException("map read/write is unavailable on the current target");
        }
        var path = EmitExpression(expression.Path) as RuntimeText
            ?? throw new SollangException("map path must be Text");
        var offset = EmitMapInteger(expression.Offset, BoundType.UInt64, "map_offset");
        var length = EmitMapInteger(expression.Length, BoundType.UIntSize, "map_length");
        var fileSize = EmitMapInteger(expression.FileSize, BoundType.UInt64, "map_file_size");
        var aggregate = NextTemp("mapped");
        EmitCall(aggregate, "%sollang.mapped_bytes", "sollang_map_file",
            $"ptr {path.PointerName}, i64 {path.LengthName}, i64 {offset}, i64 {length}, i64 {fileSize}, i1 {(expression.Mode == MapAccessMode.Write ? "true" : "false")}");
        var data = NextTemp("mapped_data");
        EmitAssign(data, $"extractvalue %sollang.mapped_bytes {aggregate}, 0");
        var valid = NextTemp("mapped_valid");
        EmitCompare(valid, "ne", "ptr", data, "null");
        EmitTrapUnless(valid, "mapped_open");
        var viewLength = NextTemp("mapped_length");
        EmitAssign(viewLength, $"extractvalue %sollang.mapped_bytes {aggregate}, 1");
        var basePointer = NextTemp("mapped_base");
        EmitAssign(basePointer, $"extractvalue %sollang.mapped_bytes {aggregate}, 2");
        var mappedLength = NextTemp("mapped_base_length");
        EmitAssign(mappedLength, $"extractvalue %sollang.mapped_bytes {aggregate}, 3");
        return new RuntimeMappedBytes(
            expression.Mode == MapAccessMode.Write ? BoundType.MutableMappedBytes : BoundType.MappedBytes,
            data,
            viewLength,
            basePointer,
            mappedLength);
    }

    private RuntimeInt EmitMappedLoad(RuntimeMappedBytes mapped, Expression indexExpression)
    {
        var index = EmitMapInteger(indexExpression, BoundType.UIntSize, "mapped_index");
        return EmitMappedLoad(mapped, index);
    }

    private RuntimeInt EmitMappedLoad(RuntimeMappedBytes mapped, string index)
    {
        EmitMappedBoundsCheck(index, mapped.LengthName);
        var slot = NextTemp("mapped_slot");
        EmitAssign(slot, $"getelementptr i8, ptr {mapped.DataPointerName}, i64 {index}");
        var value = NextTemp("mapped_byte");
        EmitLoad(value, "i8", slot, 1);
        return new RuntimeInt(BoundType.UInt8, value);
    }

    private void EmitMappedStore(RuntimeMappedBytes mapped, Expression indexExpression, RuntimeInt value)
    {
        var index = EmitMapInteger(indexExpression, BoundType.UIntSize, "mapped_index");
        EmitMappedBoundsCheck(index, mapped.LengthName);
        var slot = NextTemp("mapped_slot");
        EmitAssign(slot, $"getelementptr i8, ptr {mapped.DataPointerName}, i64 {index}");
        EmitStore("i8", value.ValueName, slot, 1);
    }

    private void EmitMappedBoundsCheck(string index, string length)
    {
        var inBounds = NextTemp("mapped_in_bounds");
        EmitCompare(inBounds, "ult", "i64", index, length);
        EmitTrapUnless(inBounds, "mapped_bounds");
    }

    private string EmitMapInteger(Expression? expression, BoundType expectedType, string prefix)
    {
        if (expression is null)
        {
            return "0";
        }
        if (expression is NumberExpression literal)
        {
            var value = BigInteger.Parse(literal.Text, CultureInfo.InvariantCulture);
            if (value < BigInteger.Zero || value > ulong.MaxValue)
            {
                throw new SollangException($"{prefix} literal is outside UInt64 range");
            }
            return value.ToString(CultureInfo.InvariantCulture);
        }
        var runtime = EmitExpression(expression) as RuntimeInt
            ?? throw new SollangException($"{prefix} must be an integer");
        EnsureRuntimeType(runtime, expectedType, prefix);
        if (NumericBitWidth(runtime.Type) == 64)
        {
            return runtime.ValueName;
        }
        var widened = NextTemp(prefix);
        EmitAssign(widened, $"zext {LlvmType(runtime.Type)} {runtime.ValueName} to i64");
        return widened;
    }
}
