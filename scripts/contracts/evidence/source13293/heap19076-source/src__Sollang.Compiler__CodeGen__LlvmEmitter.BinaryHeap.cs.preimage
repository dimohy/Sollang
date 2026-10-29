using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Semantics;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private RuntimeDynamicInlineArray EmitBinaryHeapPush(
        RuntimeDynamicInlineArray heap,
        RuntimeValue value)
    {
        var result = EmitDynamicInlineArrayPush(heap, value);
        var indexAddress = NextTemp("heap_up_index_addr");
        EmitAlloca(indexAddress, "i64", 8);
        var lastIndex = NextTemp("heap_up_last");
        EmitBinary(lastIndex, "sub", "i64", result.LengthName, "1");
        EmitStore("i64", lastIndex, indexAddress, 8);

        var loop = NextLabel("heap_up_loop");
        var compare = NextLabel("heap_up_compare");
        var swap = NextLabel("heap_up_swap");
        var done = NextLabel("heap_up_done");
        EmitBranch(loop); EmitFunctionLine();
        EmitLabel(loop);
        var index = NextTemp("heap_up_index");
        EmitLoad(index, "i64", indexAddress, 8);
        var hasParent = NextTemp("heap_up_has_parent");
        EmitCompare(hasParent, "ugt", "i64", index, "0");
        EmitConditionalBranch(hasParent, compare, done); EmitFunctionLine();

        EmitLabel(compare);
        var indexMinusOne = NextTemp("heap_up_index_minus_one");
        EmitBinary(indexMinusOne, "sub", "i64", index, "1");
        var parentIndex = NextTemp("heap_up_parent_index");
        EmitBinary(parentIndex, "udiv", "i64", indexMinusOne, "2");
        var child = EmitBinaryHeapLoadUnchecked(result, index, "heap_up_child");
        var parent = EmitBinaryHeapLoadUnchecked(result, parentIndex, "heap_up_parent");
        var rises = EmitBinaryHeapGreater(child, parent, "heap_up_rises");
        EmitConditionalBranch(rises, swap, done); EmitFunctionLine();

        EmitLabel(swap);
        EmitBinaryHeapStoreUnchecked(result, index, parent);
        EmitBinaryHeapStoreUnchecked(result, parentIndex, child);
        EmitStore("i64", parentIndex, indexAddress, 8);
        EmitBranch(loop); EmitFunctionLine();

        EmitLabel(done);
        _currentBlockLabel = done;
        return result;
    }

    private RuntimeValue EmitBinaryHeapPeek(RuntimeDynamicInlineArray heap)
    {
        return EmitDynamicInlineArrayLoad(heap, "0");
    }

    private (RuntimeDynamicInlineArray Heap, RuntimeValue Value) EmitBinaryHeapPop(
        RuntimeDynamicInlineArray heap)
    {
        var root = EmitBinaryHeapPeek(heap);
        var nextLength = NextTemp("heap_pop_length");
        EmitBinary(nextLength, "sub", "i64", heap.LengthName, "1");
        var hasElements = NextTemp("heap_pop_has_elements");
        EmitCompare(hasElements, "ugt", "i64", nextLength, "0");

        var initialize = NextLabel("heap_down_init");
        var loop = NextLabel("heap_down_loop");
        var chooseRight = NextLabel("heap_down_choose_right");
        var checkRight = NextLabel("heap_down_check_right");
        var updateRight = NextLabel("heap_down_update_right");
        var compare = NextLabel("heap_down_compare");
        var swap = NextLabel("heap_down_swap");
        var done = NextLabel("heap_down_done");
        var indexAddress = NextTemp("heap_down_index_addr");
        var bestAddress = NextTemp("heap_down_best_addr");
        EmitAlloca(indexAddress, "i64", 8);
        EmitAlloca(bestAddress, "i64", 8);
        EmitConditionalBranch(hasElements, initialize, done); EmitFunctionLine();

        EmitLabel(initialize);
        var last = EmitBinaryHeapLoadUnchecked(heap, nextLength, "heap_pop_last");
        EmitBinaryHeapStoreUnchecked(heap, "0", last);
        EmitStore("i64", "0", indexAddress, 8);
        EmitBranch(loop); EmitFunctionLine();

        EmitLabel(loop);
        var index = NextTemp("heap_down_index");
        EmitLoad(index, "i64", indexAddress, 8);
        var twice = NextTemp("heap_down_twice");
        EmitBinary(twice, "mul", "i64", index, "2");
        var left = NextTemp("heap_down_left");
        EmitBinary(left, "add", "i64", twice, "1");
        var hasLeft = NextTemp("heap_down_has_left");
        EmitCompare(hasLeft, "ult", "i64", left, nextLength);
        EmitConditionalBranch(hasLeft, chooseRight, done); EmitFunctionLine();

        EmitLabel(chooseRight);
        EmitStore("i64", left, bestAddress, 8);
        var right = NextTemp("heap_down_right");
        EmitBinary(right, "add", "i64", left, "1");
        var hasRight = NextTemp("heap_down_has_right");
        EmitCompare(hasRight, "ult", "i64", right, nextLength);
        EmitConditionalBranch(hasRight, checkRight, compare); EmitFunctionLine();

        EmitLabel(checkRight);
        var rightValue = EmitBinaryHeapLoadUnchecked(heap, right, "heap_down_right_value");
        var leftValue = EmitBinaryHeapLoadUnchecked(heap, left, "heap_down_left_value");
        var rightGreater = EmitBinaryHeapGreater(rightValue, leftValue, "heap_down_right_greater");
        EmitConditionalBranch(rightGreater, updateRight, compare); EmitFunctionLine();

        EmitLabel(updateRight);
        EmitStore("i64", right, bestAddress, 8);
        EmitBranch(compare); EmitFunctionLine();

        EmitLabel(compare);
        var best = NextTemp("heap_down_best");
        EmitLoad(best, "i64", bestAddress, 8);
        var child = EmitBinaryHeapLoadUnchecked(heap, best, "heap_down_child");
        var parent = EmitBinaryHeapLoadUnchecked(heap, index, "heap_down_parent");
        var descends = EmitBinaryHeapGreater(child, parent, "heap_down_descends");
        EmitConditionalBranch(descends, swap, done); EmitFunctionLine();

        EmitLabel(swap);
        EmitBinaryHeapStoreUnchecked(heap, index, child);
        EmitBinaryHeapStoreUnchecked(heap, best, parent);
        EmitStore("i64", best, indexAddress, 8);
        EmitBranch(loop); EmitFunctionLine();

        EmitLabel(done);
        _currentBlockLabel = done;
        return (heap with { LengthName = nextLength }, root);
    }

    private RuntimeValue EmitBinaryHeapLoadUnchecked(
        RuntimeDynamicInlineArray heap,
        string index,
        string prefix)
    {
        var definition = _program.Types.GetDynamicArray(heap.ArrayType);
        var llvmType = LlvmType(heap.ElementType);
        var slot = NextTemp(prefix + "_slot");
        EmitAssign(slot, $"getelementptr {llvmType}, ptr {heap.PointerName}, i64 {index}");
        var loaded = NextTemp(prefix);
        EmitLoad(loaded, llvmType, slot, definition.ElementAlignment);
        return DematerializeAggregateValue(heap.ElementType, loaded);
    }

    private void EmitBinaryHeapStoreUnchecked(
        RuntimeDynamicInlineArray heap,
        string index,
        RuntimeValue value)
    {
        StoreDynamicInlineArrayElement(
            heap.PointerName,
            _program.Types.GetDynamicArray(heap.ArrayType),
            index,
            value);
    }

    private string EmitBinaryHeapGreater(RuntimeValue left, RuntimeValue right, string prefix)
    {
        var result = NextTemp(prefix);
        if (left is RuntimeFloat leftFloat && right is RuntimeFloat rightFloat)
        {
            EmitInstruction($"{result} = fcmp ogt {LlvmType(left.Type)} {leftFloat.ValueName}, {rightFloat.ValueName}");
            return result;
        }
        if (left is RuntimeInt leftInt && right is RuntimeInt rightInt)
        {
            EmitCompare(result, IsSignedIntegerType(left.Type) ? "sgt" : "ugt",
                LlvmType(left.Type), leftInt.ValueName, rightInt.ValueName);
            return result;
        }
        throw new SollangException("BinaryHeap elements must have an ordered scalar runtime type");
    }
}
