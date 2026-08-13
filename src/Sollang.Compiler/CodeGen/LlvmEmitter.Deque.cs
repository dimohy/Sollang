using System.Globalization;
using Sollang.Compiler.Semantics;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private RuntimeDynamicInlineArray EmitDequePush(
        RuntimeDynamicInlineArray deque,
        RuntimeValue value,
        bool front)
    {
        var target = EmitDequeEnsureRoom(deque);
        if (front)
        {
            var head = EmitDequeLoadHead(target);
            var decremented = NextTemp("deque_front_head_minus_one");
            EmitBinary(decremented, "sub", "i64", head, "1");
            var mask = NextTemp("deque_front_mask");
            EmitBinary(mask, "sub", "i64", target.CapacityName, "1");
            var nextHead = NextTemp("deque_front_head");
            EmitBinary(nextHead, "and", "i64", decremented, mask);
            EmitStore("i64", nextHead, target.PointerName, 8);
            EmitDequeStoreUnchecked(target, "0", value);
        }
        else
        {
            EmitDequeStoreUnchecked(target, target.LengthName, value);
        }
        var nextLength = NextTemp("deque_push_length");
        EmitBinary(nextLength, "add", "i64", target.LengthName, "1");
        return target with { LengthName = nextLength };
    }

    private RuntimeValue EmitDequePeek(RuntimeDynamicInlineArray deque, bool front)
    {
        var nonempty = NextTemp("deque_peek_nonempty");
        EmitCompare(nonempty, "ugt", "i64", deque.LengthName, "0");
        EmitTrapUnless(nonempty, "deque_empty");
        if (front)
        {
            return EmitDequeLoadUnchecked(deque, "0", "deque_front");
        }
        var last = NextTemp("deque_back_index");
        EmitBinary(last, "sub", "i64", deque.LengthName, "1");
        return EmitDequeLoadUnchecked(deque, last, "deque_back");
    }

    private (RuntimeDynamicInlineArray Deque, RuntimeValue Value) EmitDequePop(
        RuntimeDynamicInlineArray deque,
        bool front)
    {
        var value = EmitDequePeek(deque, front);
        var nextLength = NextTemp("deque_pop_length");
        EmitBinary(nextLength, "sub", "i64", deque.LengthName, "1");
        if (front)
        {
            var head = EmitDequeLoadHead(deque);
            var incremented = NextTemp("deque_pop_front_head_plus_one");
            EmitBinary(incremented, "add", "i64", head, "1");
            var mask = NextTemp("deque_pop_front_mask");
            EmitBinary(mask, "sub", "i64", deque.CapacityName, "1");
            var nextHead = NextTemp("deque_pop_front_head");
            EmitBinary(nextHead, "and", "i64", incremented, mask);
            EmitStore("i64", nextHead, deque.PointerName, 8);
        }
        return (deque with { LengthName = nextLength }, value);
    }

    private RuntimeDynamicInlineArray EmitDequeEnsureRoom(RuntimeDynamicInlineArray deque)
    {
        var hasRoom = NextTemp("deque_has_room");
        EmitCompare(hasRoom, "ult", "i64", deque.LengthName, deque.CapacityName);
        var keep = NextLabel("deque_keep_storage");
        var grow = NextLabel("deque_grow_storage");
        var done = NextLabel("deque_storage_ready");
        EmitConditionalBranch(hasRoom, keep, grow); EmitFunctionLine();

        EmitLabel(keep);
        _currentBlockLabel = keep;
        EmitBranch(done);
        var keepEnd = _currentBlockLabel; EmitFunctionLine();

        EmitLabel(grow);
        _currentBlockLabel = grow;
        var definition = _program.Types.GetDynamicArray(deque.ArrayType);
        var doubled = NextTemp("deque_grown_capacity");
        EmitBinary(doubled, "mul", "i64", deque.CapacityName, "2");
        var payloadBytes = NextTemp("deque_grown_payload_bytes");
        EmitBinary(payloadBytes, "mul", "i64", doubled,
            definition.ElementSize.ToString(CultureInfo.InvariantCulture));
        var totalBytes = NextTemp("deque_grown_bytes");
        EmitBinary(totalBytes, "add", "i64", payloadBytes, "8");
        var newPointer = EmitHeapAllocate(totalBytes);
        EmitStore("i64", "0", newPointer, 8);
        var grownView = deque with { PointerName = newPointer, CapacityName = doubled };

        var entry = _currentBlockLabel;
        var loop = NextLabel("deque_grow_copy");
        var body = NextLabel("deque_grow_copy_body");
        var copied = NextLabel("deque_grow_copy_done");
        var next = NextTemp("deque_grow_copy_next");
        EmitBranch(loop); EmitFunctionLine();
        EmitLabel(loop);
        _currentBlockLabel = loop;
        var index = NextTemp("deque_grow_copy_index");
        EmitPhi(index, "i64", ("0", entry), (next, body));
        var active = NextTemp("deque_grow_copy_active");
        EmitCompare(active, "ult", "i64", index, deque.LengthName);
        EmitConditionalBranch(active, body, copied); EmitFunctionLine();
        EmitLabel(body);
        _currentBlockLabel = body;
        var item = EmitDequeLoadUnchecked(deque, index, "deque_grow_item");
        EmitDequeStoreUnchecked(grownView, index, item);
        EmitBinary(next, "add", "i64", index, "1");
        EmitBranch(loop); EmitFunctionLine();
        EmitLabel(copied);
        _currentBlockLabel = copied;
        EmitCall(null, "void", "sollang_free", $"ptr {deque.PointerName}");
        EmitBranch(done);
        var growEnd = _currentBlockLabel; EmitFunctionLine();

        EmitLabel(done);
        var pointer = NextTemp("deque_storage");
        EmitPhi(pointer, "ptr", (deque.PointerName, keepEnd), (newPointer, growEnd));
        var capacity = NextTemp("deque_capacity");
        EmitPhi(capacity, "i64", (deque.CapacityName, keepEnd), (doubled, growEnd));
        _currentBlockLabel = done;
        return deque with { PointerName = pointer, CapacityName = capacity };
    }

    private RuntimeDynamicInlineArray EmitDequeReserve(RuntimeDynamicInlineArray deque, string requested)
    {
        var rounded = EmitRoundUpPowerOfTwo(requested, "deque_reserve");
        var growStorage = NextTemp("deque_reserve_grow");
        EmitCompare(growStorage, "ugt", "i64", rounded, deque.CapacityName);
        var keep = NextLabel("deque_reserve_keep");
        var grow = NextLabel("deque_reserve_grow_storage");
        var done = NextLabel("deque_reserve_done");
        EmitConditionalBranch(growStorage, grow, keep); EmitFunctionLine();

        EmitLabel(keep);
        _currentBlockLabel = keep;
        EmitBranch(done);
        var keepEnd = _currentBlockLabel; EmitFunctionLine();

        EmitLabel(grow);
        _currentBlockLabel = grow;
        var definition = _program.Types.GetDynamicArray(deque.ArrayType);
        var payloadBytes = NextTemp("deque_reserve_payload_bytes");
        EmitBinary(payloadBytes, "mul", "i64", rounded,
            definition.ElementSize.ToString(CultureInfo.InvariantCulture));
        var totalBytes = NextTemp("deque_reserve_bytes");
        EmitBinary(totalBytes, "add", "i64", payloadBytes, "8");
        var pointer = EmitHeapAllocate(totalBytes);
        EmitStore("i64", "0", pointer, 8);
        var target = deque with { PointerName = pointer, CapacityName = rounded };
        var entry = _currentBlockLabel;
        var loop = NextLabel("deque_reserve_copy");
        var body = NextLabel("deque_reserve_copy_body");
        var copied = NextLabel("deque_reserve_copy_done");
        var next = NextTemp("deque_reserve_copy_next");
        EmitBranch(loop); EmitFunctionLine();
        EmitLabel(loop); _currentBlockLabel = loop;
        var index = NextTemp("deque_reserve_copy_index");
        EmitPhi(index, "i64", ("0", entry), (next, body));
        var active = NextTemp("deque_reserve_copy_active");
        EmitCompare(active, "ult", "i64", index, deque.LengthName);
        EmitConditionalBranch(active, body, copied); EmitFunctionLine();
        EmitLabel(body); _currentBlockLabel = body;
        EmitDequeStoreUnchecked(target, index, EmitDequeLoadUnchecked(deque, index, "deque_reserve_item"));
        EmitBinary(next, "add", "i64", index, "1");
        EmitBranch(loop); EmitFunctionLine();
        EmitLabel(copied); _currentBlockLabel = copied;
        EmitCall(null, "void", "sollang_free", $"ptr {deque.PointerName}");
        EmitBranch(done);
        var growEnd = _currentBlockLabel; EmitFunctionLine();

        EmitLabel(done);
        var resultPointer = NextTemp("deque_reserve_ptr");
        EmitPhi(resultPointer, "ptr", (deque.PointerName, keepEnd), (pointer, growEnd));
        var capacity = NextTemp("deque_reserve_capacity_result");
        EmitPhi(capacity, "i64", (deque.CapacityName, keepEnd), (rounded, growEnd));
        _currentBlockLabel = done;
        return deque with { PointerName = resultPointer, CapacityName = capacity };
    }

    private string EmitDequeLoadHead(RuntimeDynamicInlineArray deque)
    {
        var head = NextTemp("deque_head");
        EmitLoad(head, "i64", deque.PointerName, 8);
        return head;
    }

    private string EmitDequeElementPointer(
        RuntimeDynamicInlineArray deque,
        string logicalIndex,
        string prefix)
    {
        var head = EmitDequeLoadHead(deque);
        var unwrapped = NextTemp(prefix + "_unwrapped");
        EmitBinary(unwrapped, "add", "i64", head, logicalIndex);
        var mask = NextTemp(prefix + "_mask");
        EmitBinary(mask, "sub", "i64", deque.CapacityName, "1");
        var physical = NextTemp(prefix + "_physical");
        EmitBinary(physical, "and", "i64", unwrapped, mask);
        var data = NextTemp(prefix + "_data");
        EmitAssign(data, $"getelementptr i8, ptr {deque.PointerName}, i64 8");
        var slot = NextTemp(prefix + "_slot");
        EmitAssign(slot, $"getelementptr {LlvmType(deque.ElementType)}, ptr {data}, i64 {physical}");
        return slot;
    }

    private RuntimeValue EmitDequeLoadUnchecked(
        RuntimeDynamicInlineArray deque,
        string logicalIndex,
        string prefix)
    {
        var definition = _program.Types.GetDynamicArray(deque.ArrayType);
        var value = NextTemp(prefix);
        EmitLoad(value, LlvmType(deque.ElementType),
            EmitDequeElementPointer(deque, logicalIndex, prefix), definition.ElementAlignment);
        return DematerializeAggregateValue(deque.ElementType, value);
    }

    private void EmitDequeStoreUnchecked(
        RuntimeDynamicInlineArray deque,
        string logicalIndex,
        RuntimeValue value)
    {
        var definition = _program.Types.GetDynamicArray(deque.ArrayType);
        var materialized = MaterializeAggregateValue(value);
        EmitStore(materialized.TypeName, materialized.ValueName,
            EmitDequeElementPointer(deque, logicalIndex, "deque_store"), definition.ElementAlignment);
    }
}
