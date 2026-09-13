using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private RuntimeFlowResult EmitArrayExchange(
        Expression source,
        FlowTarget target,
        RuntimeValue current)
    {
        if (target.Arguments.Count != 2)
        {
            throw new SollangException("exchange expects exactly two Int indices");
        }

        if (source is NameExpression)
        {
            RequireMutableContainerSource(source, "exchange");
        }
        else
        {
            RequireMutableContainerProjection(source, "exchange");
        }

        var left = EmitIntAsSize(EmitIntExpression(target.Arguments[0]), "exchange_left");
        var right = EmitIntAsSize(EmitIntExpression(target.Arguments[1]), "exchange_right");
        switch (current)
        {
            case RuntimeDynamicIntArray integers:
                EmitArrayExchange(
                    integers.PointerName,
                    integers.LengthName,
                    left,
                    right,
                    "i32",
                    4);
                break;
            case RuntimeDynamicInlineArray inline:
                EmitArrayExchange(
                    inline.PointerName,
                    inline.LengthName,
                    left,
                    right,
                    LlvmType(inline.ElementType),
                    RuntimeAlignment(inline.ElementType));
                break;
            default:
                throw new SollangException("exchange requires a mutable growable array owner");
        }

        return new RuntimeFlowResult(null, null, _mainOk);
    }

    private void EmitArrayExchange(
        string pointer,
        string length,
        string left,
        string right,
        string elementType,
        int alignment)
    {
        var leftInBounds = NextTemp("exchange_left_in_bounds");
        EmitCompare(leftInBounds, "ult", "i64", left, length);
        var rightInBounds = NextTemp("exchange_right_in_bounds");
        EmitCompare(rightInBounds, "ult", "i64", right, length);
        var inBounds = NextTemp("exchange_in_bounds");
        EmitBinary(inBounds, "and", "i1", leftInBounds, rightInBounds);
        EmitTrapUnless(inBounds, "exchange_bounds");

        var same = NextTemp("exchange_same");
        EmitCompare(same, "eq", "i64", left, right);
        var swap = NextLabel("exchange_swap");
        var done = NextLabel("exchange_done");
        EmitConditionalBranch(same, done, swap);
        EmitFunctionLine();

        EmitLabel(swap);
        var leftPointer = NextTemp("exchange_left_ptr");
        EmitAssign(leftPointer, $"getelementptr {elementType}, ptr {pointer}, i64 {left}");
        var rightPointer = NextTemp("exchange_right_ptr");
        EmitAssign(rightPointer, $"getelementptr {elementType}, ptr {pointer}, i64 {right}");
        var leftValue = NextTemp("exchange_left_value");
        EmitLoad(leftValue, elementType, leftPointer, alignment);
        var rightValue = NextTemp("exchange_right_value");
        EmitLoad(rightValue, elementType, rightPointer, alignment);
        EmitStore(elementType, rightValue, leftPointer, alignment);
        EmitStore(elementType, leftValue, rightPointer, alignment);
        EmitBranch(done);
        EmitFunctionLine();

        EmitLabel(done);
    }
}
