using Sollang.Compiler.Diagnostics;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private RuntimeText EmitTextSlice(RuntimeText text, string start, string length)
    {
        var startInBounds = NextTemp("text_slice_start_in_bounds");
        EmitCompare(startInBounds, "ule", "i64", start, text.LengthName);
        EmitTrapUnless(startInBounds, "text_slice_start_bounds");
        var remaining = NextTemp("text_slice_remaining");
        EmitAssign(remaining, $"sub i64 {text.LengthName}, {start}");
        var lengthInBounds = NextTemp("text_slice_length_in_bounds");
        EmitCompare(lengthInBounds, "ule", "i64", length, remaining);
        EmitTrapUnless(lengthInBounds, "text_slice_length_bounds");
        var end = NextTemp("text_slice_end");
        EmitAssign(end, $"add i64 {start}, {length}");
        EmitTextBoundaryCheck(text, start, "text_slice_start");
        EmitTextBoundaryCheck(text, end, "text_slice_end");
        var pointer = NextTemp("text_slice_ptr");
        EmitAssign(pointer, $"getelementptr i8, ptr {text.PointerName}, i64 {start}");
        return new RuntimeText(pointer, length);
    }

    private void EmitTextBoundaryCheck(RuntimeText text, string offset, string prefix)
    {
        var atEnd = NextTemp(prefix + "_at_end");
        EmitCompare(atEnd, "eq", "i64", offset, text.LengthName);
        var checkLabel = NextLabel(prefix + "_check");
        var validLabel = NextLabel(prefix + "_valid");
        EmitConditionalBranch(atEnd, validLabel, checkLabel);

        EmitLabel(checkLabel);
        _currentBlockLabel = checkLabel;
        var pointer = NextTemp(prefix + "_ptr");
        EmitAssign(pointer, $"getelementptr i8, ptr {text.PointerName}, i64 {offset}");
        var value = NextTemp(prefix + "_byte");
        EmitLoad(value, "i8", pointer, 1);
        var prefixBits = NextTemp(prefix + "_prefix");
        EmitAssign(prefixBits, $"and i8 {value}, -64");
        var isContinuation = NextTemp(prefix + "_continuation");
        EmitCompare(isContinuation, "eq", "i8", prefixBits, "-128");
        var boundary = NextTemp(prefix + "_boundary");
        EmitAssign(boundary, $"xor i1 {isContinuation}, true");
        EmitTrapUnless(boundary, prefix + "_utf8_boundary");
        EmitBranch(validLabel);

        EmitLabel(validLabel);
        _currentBlockLabel = validLabel;
    }
}
