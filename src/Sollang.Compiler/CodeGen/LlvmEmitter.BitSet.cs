using System.Globalization;
using Sollang.Compiler.Semantics;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private (string Slot, string Mask) EmitBitSetLocation(RuntimeBitSet bitSet, RuntimeInt index)
    {
        var definition = _program.Types.GetBitSet(bitSet.Type);
        var inBounds = NextTemp("bitset_in_bounds");
        EmitCompare(inBounds, "ult", "i32", index.ValueName,
            definition.BitCount.ToString(CultureInfo.InvariantCulture));
        EmitTrapUnless(inBounds, "bitset_bounds");
        var wideIndex = NextTemp("bitset_index");
        EmitAssign(wideIndex, $"zext i32 {index.ValueName} to i64");
        var wordIndex = NextTemp("bitset_word_index");
        EmitAssign(wordIndex, $"lshr i64 {wideIndex}, 6");
        var bitIndex = NextTemp("bitset_bit_index");
        EmitBinary(bitIndex, "and", "i64", wideIndex, "63");
        var mask = NextTemp("bitset_mask");
        EmitAssign(mask, $"shl i64 1, {bitIndex}");
        var slot = NextTemp("bitset_slot");
        EmitAssign(slot, $"getelementptr i64, ptr {bitSet.PointerName}, i64 {wordIndex}");
        return (slot, mask);
    }

    private RuntimeBool EmitBitSetContains(RuntimeBitSet bitSet, RuntimeInt index)
    {
        var (slot, mask) = EmitBitSetLocation(bitSet, index);
        var word = NextTemp("bitset_word");
        EmitLoad(word, "i64", slot, 8);
        var selected = NextTemp("bitset_selected");
        EmitBinary(selected, "and", "i64", word, mask);
        var present = NextTemp("bitset_present");
        EmitCompare(present, "ne", "i64", selected, "0");
        return new RuntimeBool(present);
    }

    private void EmitBitSetMutation(RuntimeBitSet bitSet, RuntimeInt index, bool set)
    {
        var (slot, mask) = EmitBitSetLocation(bitSet, index);
        var word = NextTemp("bitset_word");
        EmitLoad(word, "i64", slot, 8);
        var updated = NextTemp("bitset_updated");
        if (set)
        {
            EmitBinary(updated, "or", "i64", word, mask);
        }
        else
        {
            var inverse = NextTemp("bitset_inverse_mask");
            EmitBinary(inverse, "xor", "i64", mask, "-1");
            EmitBinary(updated, "and", "i64", word, inverse);
        }
        EmitStore("i64", updated, slot, 8);
    }

    private RuntimeInt EmitBitSetCount(RuntimeBitSet bitSet)
    {
        var definition = _program.Types.GetBitSet(bitSet.Type);
        var total = "0";
        for (var wordIndex = 0; wordIndex < definition.WordCount; wordIndex++)
        {
            var slot = NextTemp("bitset_count_slot");
            EmitAssign(slot, $"getelementptr i64, ptr {bitSet.PointerName}, i64 {wordIndex}");
            var word = NextTemp("bitset_count_word");
            EmitLoad(word, "i64", slot, 8);
            if (wordIndex == definition.WordCount - 1 && definition.BitCount % 64 is var tailBits and > 0)
            {
                var tailMask = unchecked((1UL << tailBits) - 1UL);
                var masked = NextTemp("bitset_tail_word");
                EmitBinary(masked, "and", "i64", word, tailMask.ToString(CultureInfo.InvariantCulture));
                word = masked;
            }
            var count = NextTemp("bitset_word_count");
            EmitCall(count, "i64", "llvm.ctpop.i64", $"i64 {word}");
            var next = NextTemp("bitset_count");
            EmitBinary(next, "add", "i64", total, count);
            total = next;
        }
        var result = NextTemp("bitset_count_value");
        EmitAssign(result, $"trunc i64 {total} to i32");
        return new RuntimeInt(result);
    }
}
