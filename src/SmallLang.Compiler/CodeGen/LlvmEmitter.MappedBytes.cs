using System.Globalization;
using System.Numerics;
using SmallLang.Compiler.Diagnostics;
using SmallLang.Compiler.Semantics;
using SmallLang.Compiler.Syntax;

namespace SmallLang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private RuntimeMappedBytes EmitMapExpression(MapExpression expression)
    {
        if (!_platform.SupportsMemoryMapping)
        {
            throw new SmallLangException("map read/write is unavailable on the current target");
        }
        var path = EmitExpression(expression.Path) as RuntimeText
            ?? throw new SmallLangException("map path must be Text");
        var offset = EmitMapInteger(expression.Offset, BoundType.UInt64, "map_offset");
        var length = EmitMapInteger(expression.Length, BoundType.UIntSize, "map_length");
        var fileSize = EmitMapInteger(expression.FileSize, BoundType.UInt64, "map_file_size");
        var aggregate = NextTemp("mapped");
        EmitCall(aggregate, "%smalllang.mapped_bytes", "smalllang_map_file",
            $"ptr {path.PointerName}, i64 {path.LengthName}, i64 {offset}, i64 {length}, i64 {fileSize}, i1 {(expression.Mode == MapAccessMode.Write ? "true" : "false")}");
        var data = NextTemp("mapped_data");
        EmitAssign(data, $"extractvalue %smalllang.mapped_bytes {aggregate}, 0");
        var valid = NextTemp("mapped_valid");
        EmitCompare(valid, "ne", "ptr", data, "null");
        EmitTrapUnless(valid, "mapped_open");
        var viewLength = NextTemp("mapped_length");
        EmitAssign(viewLength, $"extractvalue %smalllang.mapped_bytes {aggregate}, 1");
        var basePointer = NextTemp("mapped_base");
        EmitAssign(basePointer, $"extractvalue %smalllang.mapped_bytes {aggregate}, 2");
        var mappedLength = NextTemp("mapped_base_length");
        EmitAssign(mappedLength, $"extractvalue %smalllang.mapped_bytes {aggregate}, 3");
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
                throw new SmallLangException($"{prefix} literal is outside UInt64 range");
            }
            return value.ToString(CultureInfo.InvariantCulture);
        }
        var runtime = EmitExpression(expression) as RuntimeInt
            ?? throw new SmallLangException($"{prefix} must be an integer");
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
