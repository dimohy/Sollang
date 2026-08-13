using System.Globalization;
using System.Text;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Semantics;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private string EmitRoundUpPowerOfTwo(string value, string prefix)
    {
        var atLeastOne = NextTemp(prefix + "_at_least_one");
        var positive = NextTemp(prefix + "_positive");
        EmitCompare(positive, "ugt", "i64", value, "0");
        EmitSelect(atLeastOne, positive, $"i64 {value}", "i64 1");
        var current = NextTemp(prefix + "_minus_one");
        EmitBinary(current, "sub", "i64", atLeastOne, "1");
        foreach (var shift in new[] { 1, 2, 4, 8, 16, 32 })
        {
            var shifted = NextTemp(prefix + "_shifted");
            EmitBinary(shifted, "lshr", "i64", current, shift.ToString(CultureInfo.InvariantCulture));
            var combined = NextTemp(prefix + "_combined");
            EmitBinary(combined, "or", "i64", current, shifted);
            current = combined;
        }
        var result = NextTemp(prefix + "_power_of_two");
        EmitBinary(result, "add", "i64", current, "1");
        return result;
    }

    private string EmitDictionaryCapacityForEntries(string entries, string prefix)
    {
        var scaled = NextTemp(prefix + "_scaled");
        EmitBinary(scaled, "mul", "i64", entries, "8");
        var rounded = NextTemp(prefix + "_rounded");
        EmitBinary(rounded, "add", "i64", scaled, "6");
        var required = NextTemp(prefix + "_required");
        EmitBinary(required, "udiv", "i64", rounded, "7");
        var power = EmitRoundUpPowerOfTwo(required, prefix + "_buckets");
        var belowMinimum = NextTemp(prefix + "_below_minimum");
        EmitCompare(belowMinimum, "ult", "i64", power, "16");
        var capacity = NextTemp(prefix + "_capacity");
        EmitSelect(capacity, belowMinimum, "i64 16", $"i64 {power}");
        return capacity;
    }

    private RuntimeDynamicIntArray EmitDynamicArrayPush(RuntimeDynamicIntArray array, string value)
    {
        var hasCapacity = NextTemp("array_has_capacity");
        EmitCompare(hasCapacity, "ult", "i64", array.LengthName, array.CapacityName);

        var appendLabel = NextLabel("array_push_append");
        var growLabel = NextLabel("array_push_grow");
        var doneLabel = NextLabel("array_push_done");
        EmitConditionalBranch(hasCapacity, appendLabel, growLabel);
        EmitFunctionLine();

        EmitLabel(appendLabel);
        _currentBlockLabel = appendLabel;
        StoreDynamicArrayElement(array.PointerName, array.LengthName, value);
        var appendNextLen = NextTemp("array_next_len");
        EmitBinary(appendNextLen, "add", "i64", array.LengthName, "1");
        EmitBranch(doneLabel);
        var appendEnd = appendLabel;
        EmitFunctionLine();

        EmitLabel(growLabel);
        _currentBlockLabel = growLabel;
        var hasAnyCapacity = NextTemp("array_has_any_capacity");
        EmitCompare(hasAnyCapacity, "eq", "i64", array.CapacityName, "0");
        var doubledCapacity = NextTemp("array_doubled_capacity");
        EmitBinary(doubledCapacity, "mul", "i64", array.CapacityName, "2");
        var newCapacity = NextTemp("array_new_capacity");
        EmitSelect(newCapacity, hasAnyCapacity, "i64 4", $"i64 {doubledCapacity}");
        var newBytes = NextTemp("array_new_bytes");
        EmitBinary(newBytes, "mul", "i64", newCapacity, "4");
        var newPointer = EmitHeapAllocate(newBytes);
        EmitCopyIntBuffer(array.PointerName, newPointer, array.LengthName, "array_copy");
        EmitCall(target: null, "void", "sollang_free", $"ptr {array.PointerName}");
        StoreDynamicArrayElement(newPointer, array.LengthName, value);
        var growNextLen = NextTemp("array_next_len");
        EmitBinary(growNextLen, "add", "i64", array.LengthName, "1");
        EmitBranch(doneLabel);
        var growEnd = _currentBlockLabel;
        EmitFunctionLine();

        EmitLabel(doneLabel);
        _currentBlockLabel = doneLabel;
        var resultPointer = NextTemp("array_ptr");
        EmitPhi(resultPointer, "ptr", (array.PointerName, appendEnd), (newPointer, growEnd));
        var resultLength = NextTemp("array_len");
        EmitPhi(resultLength, "i64", (appendNextLen, appendEnd), (growNextLen, growEnd));
        var resultCapacity = NextTemp("array_capacity");
        EmitPhi(resultCapacity, "i64", (array.CapacityName, appendEnd), (newCapacity, growEnd));
        return new RuntimeDynamicIntArray(resultPointer, resultLength, resultCapacity);
    }

    private RuntimeDynamicIntArray EmitDynamicArrayAppendMove(RuntimeDynamicIntArray array, string value)
    {
        return EmitDynamicArrayPush(array, value);
    }

    private RuntimeDynamicIntArray EmitDynamicArrayReserve(RuntimeDynamicIntArray array, string requested)
    {
        var grow = NextTemp("array_reserve_grow");
        EmitCompare(grow, "ugt", "i64", requested, array.CapacityName);
        var allocate = NextLabel("array_reserve_allocate");
        var keep = NextLabel("array_reserve_keep");
        var done = NextLabel("array_reserve_done");
        EmitConditionalBranch(grow, allocate, keep); EmitFunctionLine();

        EmitLabel(keep);
        _currentBlockLabel = keep;
        EmitBranch(done);
        var keepEnd = _currentBlockLabel; EmitFunctionLine();

        EmitLabel(allocate);
        _currentBlockLabel = allocate;
        var bytes = NextTemp("array_reserve_bytes");
        EmitBinary(bytes, "mul", "i64", requested, "4");
        var pointer = EmitHeapAllocate(bytes);
        EmitCopyIntBuffer(array.PointerName, pointer, array.LengthName, "array_reserve_copy");
        EmitCall(null, "void", "sollang_free", $"ptr {array.PointerName}");
        EmitBranch(done);
        var allocateEnd = _currentBlockLabel; EmitFunctionLine();

        EmitLabel(done);
        var resultPointer = NextTemp("array_reserve_ptr");
        EmitPhi(resultPointer, "ptr", (array.PointerName, keepEnd), (pointer, allocateEnd));
        var capacity = NextTemp("array_reserve_capacity");
        EmitPhi(capacity, "i64", (array.CapacityName, keepEnd), (requested, allocateEnd));
        _currentBlockLabel = done;
        return array with { PointerName = resultPointer, CapacityName = capacity };
    }

    private RuntimeDynamicIntArray EmitDynamicArrayPushAll(
        RuntimeDynamicIntArray array,
        RuntimeStaticIntArray source)
    {
        var total = EmitCheckedCollectionLengthSum(
            array.LengthName, source.LengthName, "array_push_all");
        var reserved = EmitDynamicArrayReserve(array, total);
        EmitCopyBufferAtOffset(
            source.PointerName,
            reserved.PointerName,
            source.LengthName,
            array.LengthName,
            "i32",
            4,
            "array_push_all_copy");
        return reserved with { LengthName = total };
    }

    private (RuntimeDynamicIntArray Array, RuntimeInt Value) EmitDynamicArrayTake(
        RuntimeDynamicIntArray array,
        string index)
    {
        var value = EmitDynamicArrayLoad(array, index);
        var nextLength = NextTemp("array_take_length");
        EmitBinary(nextLength, "sub", "i64", array.LengthName, "1");
        var entry = _currentBlockLabel;
        var loop = NextLabel("array_take_shift");
        var body = NextLabel("array_take_shift_body");
        var done = NextLabel("array_take_shift_done");
        var next = NextTemp("array_take_next");
        EmitBranch(loop); EmitFunctionLine();
        EmitLabel(loop);
        var current = NextTemp("array_take_current");
        EmitPhi(current, "i64", (index, entry), (next, body));
        var active = NextTemp("array_take_active");
        EmitCompare(active, "ult", "i64", current, nextLength);
        EmitConditionalBranch(active, body, done); EmitFunctionLine();
        EmitLabel(body);
        var sourceIndex = NextTemp("array_take_source_index");
        EmitBinary(sourceIndex, "add", "i64", current, "1");
        var sourceSlot = NextTemp("array_take_source");
        EmitAssign(sourceSlot, $"getelementptr i32, ptr {array.PointerName}, i64 {sourceIndex}");
        var moved = LoadInt(sourceSlot, "array_take_moved");
        StoreDynamicArrayElement(array.PointerName, current, moved.ValueName);
        EmitBinary(next, "add", "i64", current, "1");
        EmitBranch(loop); EmitFunctionLine();
        EmitLabel(done);
        _currentBlockLabel = done;
        return (array with { LengthName = nextLength }, value);
    }

    private RuntimeDynamicIntArray EmitDynamicArrayUpdatedMove(RuntimeDynamicIntArray array, string index, string value)
    {
        var inBounds = NextTemp("array_update_in_bounds");
        EmitCompare(inBounds, "ult", "i64", index, array.LengthName);
        EmitTrapUnless(inBounds, "array_update_bounds");

        StoreDynamicArrayElement(array.PointerName, index, value);
        return array;
    }

    private RuntimeIntDictionary EmitDictionaryPut(RuntimeIntDictionary dictionary, string key, string value)
    {
        var found = EmitDictionaryFindSlot(dictionary, key);

        var updateLabel = NextLabel("dict_put_update");
        var insertLabel = NextLabel("dict_put_insert");
        var currentInsertLabel = NextLabel("dict_put_insert_current");
        var growInsertLabel = NextLabel("dict_put_insert_grow");
        var doneLabel = NextLabel("dict_put_done");
        EmitConditionalBranch(found.FoundName, updateLabel, insertLabel);
        EmitFunctionLine();

        EmitLabel(updateLabel);
        _currentBlockLabel = updateLabel;
        StoreDictionaryEntry(dictionary, found.SlotName, key, value);
        EmitBranch(doneLabel);
        var updateEnd = updateLabel;
        EmitFunctionLine();

        EmitLabel(insertLabel);
        _currentBlockLabel = insertLabel;
        var nextLength = NextTemp("dict_next_len");
        EmitBinary(nextLength, "add", "i64", dictionary.LengthName, "1");
        var loadNumerator = NextTemp("dict_load_numerator");
        EmitBinary(loadNumerator, "mul", "i64", nextLength, "8");
        var loadDenominator = NextTemp("dict_load_denominator");
        EmitBinary(loadDenominator, "mul", "i64", dictionary.CapacityName, "7");
        var shouldGrow = NextTemp("dict_should_grow");
        EmitCompare(shouldGrow, "ugt", "i64", loadNumerator, loadDenominator);
        EmitConditionalBranch(shouldGrow, growInsertLabel, currentInsertLabel);
        EmitFunctionLine();

        EmitLabel(currentInsertLabel);
        _currentBlockLabel = currentInsertLabel;
        StoreDictionaryEntry(dictionary, found.SlotName, key, value);
        StoreDictionaryControl(dictionary, found.SlotName, found.H2ByteName);
        EmitBranch(doneLabel);
        var currentInsertEnd = _currentBlockLabel;
        EmitFunctionLine();

        EmitLabel(growInsertLabel);
        _currentBlockLabel = growInsertLabel;
        var grown = EmitDictionaryGrow(dictionary);
        EmitDictionaryInsertUnique(grown, key, value);
        EmitBranch(doneLabel);
        var growInsertEnd = _currentBlockLabel;
        EmitFunctionLine();

        EmitLabel(doneLabel);
        _currentBlockLabel = doneLabel;
        var resultPointer = NextTemp("dict_ptr");
        EmitPhi(resultPointer, "ptr", (dictionary.PointerName, updateEnd), (dictionary.PointerName, currentInsertEnd), (grown.PointerName, growInsertEnd));
        var resultLength = NextTemp("dict_len");
        EmitPhi(resultLength, "i64", (dictionary.LengthName, updateEnd), (nextLength, currentInsertEnd), (nextLength, growInsertEnd));
        var resultCapacity = NextTemp("dict_capacity");
        EmitPhi(resultCapacity, "i64", (dictionary.CapacityName, updateEnd), (dictionary.CapacityName, currentInsertEnd), (grown.CapacityName, growInsertEnd));
        return new RuntimeIntDictionary(resultPointer, resultLength, resultCapacity);
    }

    private (RuntimeIntDictionary Dictionary, RuntimeBool Inserted) EmitDictionaryPutIfAbsent(
        RuntimeIntDictionary dictionary,
        string key,
        string value)
    {
        var found = EmitDictionaryFindSlot(dictionary, key);
        var duplicate = NextLabel("dict_put_if_absent_duplicate");
        var insert = NextLabel("dict_put_if_absent_insert");
        var current = NextLabel("dict_put_if_absent_current");
        var grow = NextLabel("dict_put_if_absent_grow");
        var done = NextLabel("dict_put_if_absent_done");
        EmitConditionalBranch(found.FoundName, duplicate, insert); EmitFunctionLine();

        EmitLabel(duplicate);
        _currentBlockLabel = duplicate;
        EmitBranch(done);
        var duplicateEnd = _currentBlockLabel; EmitFunctionLine();

        EmitLabel(insert);
        _currentBlockLabel = insert;
        var nextLength = NextTemp("dict_put_if_absent_length");
        EmitBinary(nextLength, "add", "i64", dictionary.LengthName, "1");
        var numerator = NextTemp("dict_put_if_absent_load_num");
        var denominator = NextTemp("dict_put_if_absent_load_den");
        EmitBinary(numerator, "mul", "i64", nextLength, "8");
        EmitBinary(denominator, "mul", "i64", dictionary.CapacityName, "7");
        var shouldGrow = NextTemp("dict_put_if_absent_should_grow");
        EmitCompare(shouldGrow, "ugt", "i64", numerator, denominator);
        EmitConditionalBranch(shouldGrow, grow, current); EmitFunctionLine();

        EmitLabel(current);
        _currentBlockLabel = current;
        StoreDictionaryEntry(dictionary, found.SlotName, key, value);
        StoreDictionaryControl(dictionary, found.SlotName, found.H2ByteName);
        EmitBranch(done);
        var currentEnd = _currentBlockLabel; EmitFunctionLine();

        EmitLabel(grow);
        _currentBlockLabel = grow;
        var grown = EmitDictionaryGrow(dictionary);
        EmitDictionaryInsertUnique(grown, key, value);
        EmitBranch(done);
        var growEnd = _currentBlockLabel; EmitFunctionLine();

        EmitLabel(done);
        var pointer = NextTemp("dict_put_if_absent_ptr");
        EmitPhi(pointer, "ptr", (dictionary.PointerName, duplicateEnd), (dictionary.PointerName, currentEnd), (grown.PointerName, growEnd));
        var length = NextTemp("dict_put_if_absent_length_result");
        EmitPhi(length, "i64", (dictionary.LengthName, duplicateEnd), (nextLength, currentEnd), (nextLength, growEnd));
        var capacity = NextTemp("dict_put_if_absent_capacity");
        EmitPhi(capacity, "i64", (dictionary.CapacityName, duplicateEnd), (dictionary.CapacityName, currentEnd), (grown.CapacityName, growEnd));
        var inserted = NextTemp("dict_put_if_absent_inserted");
        EmitPhi(inserted, "i1", ("false", duplicateEnd), ("true", currentEnd), ("true", growEnd));
        _currentBlockLabel = done;
        return (new RuntimeIntDictionary(pointer, length, capacity), new RuntimeBool(inserted));
    }

    private RuntimeIntDictionary EmitDictionaryUpdatedMove(RuntimeIntDictionary dictionary, string key, string value)
    {
        return EmitDictionaryPut(dictionary, key, value);
    }

    private RuntimeIntDictionary EmitDictionaryReserve(RuntimeIntDictionary dictionary, string requestedEntries)
    {
        var requestedCapacity = EmitDictionaryCapacityForEntries(requestedEntries, "dict_reserve");
        var grow = NextTemp("dict_reserve_grow");
        EmitCompare(grow, "ugt", "i64", requestedCapacity, dictionary.CapacityName);
        var allocate = NextLabel("dict_reserve_allocate");
        var keep = NextLabel("dict_reserve_keep");
        var done = NextLabel("dict_reserve_done");
        EmitConditionalBranch(grow, allocate, keep); EmitFunctionLine();

        EmitLabel(keep);
        _currentBlockLabel = keep;
        EmitBranch(done);
        var keepEnd = _currentBlockLabel; EmitFunctionLine();

        EmitLabel(allocate);
        _currentBlockLabel = allocate;
        var target = new RuntimeIntDictionary(
            EmitDictionaryAllocate(requestedCapacity),
            dictionary.LengthName,
            requestedCapacity);
        EmitDictionaryRehash(dictionary, target);
        EmitCall(null, "void", "sollang_free", $"ptr {dictionary.PointerName}");
        EmitBranch(done);
        var allocateEnd = _currentBlockLabel; EmitFunctionLine();

        EmitLabel(done);
        var pointer = NextTemp("dict_reserve_ptr");
        EmitPhi(pointer, "ptr", (dictionary.PointerName, keepEnd), (target.PointerName, allocateEnd));
        var capacity = NextTemp("dict_reserve_capacity_result");
        EmitPhi(capacity, "i64", (dictionary.CapacityName, keepEnd), (requestedCapacity, allocateEnd));
        _currentBlockLabel = done;
        return dictionary with { PointerName = pointer, CapacityName = capacity };
    }

    private (RuntimeIntDictionary Dictionary, RuntimeInt Value) EmitDictionaryTake(
        RuntimeIntDictionary dictionary,
        string key)
    {
        var found = EmitDictionaryFindSlot(dictionary, key);
        EmitTrapUnless(found.FoundName, "dict_take_missing");
        var value = LoadDictionaryValue(dictionary, found.SlotName);
        var nextLength = NextTemp("dict_take_length");
        EmitBinary(nextLength, "sub", "i64", dictionary.LengthName, "1");
        var target = new RuntimeIntDictionary(
            EmitDictionaryAllocate(dictionary.CapacityName),
            nextLength,
            dictionary.CapacityName);
        EmitDictionaryRehashExcept(dictionary, target, found.SlotName);
        EmitCall(target: null, "void", "sollang_free", $"ptr {dictionary.PointerName}");
        return (target, value);
    }

    private RuntimeDynamicInlineArray EmitDynamicInlineArrayPush(
        RuntimeDynamicInlineArray array,
        RuntimeValue value)
    {
        if (_program.Types.IsBoundedArray(array.ArrayType))
        {
            var bounded = _program.Types.GetBoundedArray(array.ArrayType);
            var hasRoom = NextTemp("bounded_array_has_room");
            EmitCompare(hasRoom, "ult", "i64", array.LengthName,
                bounded.Capacity.ToString(CultureInfo.InvariantCulture));
            EmitTrapUnless(hasRoom, "bounded_array_capacity");
            StoreBoundedArrayElement(array.PointerName, bounded, array.LengthName, value);
            var nextLength = NextTemp("bounded_array_next_len");
            EmitBinary(nextLength, "add", "i64", array.LengthName, "1");
            return array with { LengthName = nextLength };
        }
        var definition = _program.Types.GetDynamicArray(array.ArrayType);
        var hasCapacity = NextTemp("generic_array_has_capacity");
        EmitCompare(hasCapacity, "ult", "i64", array.LengthName, array.CapacityName);
        var appendLabel = NextLabel("generic_array_push_append");
        var growLabel = NextLabel("generic_array_push_grow");
        var doneLabel = NextLabel("generic_array_push_done");
        EmitConditionalBranch(hasCapacity, appendLabel, growLabel);
        EmitFunctionLine();

        EmitLabel(appendLabel);
        _currentBlockLabel = appendLabel;
        StoreDynamicInlineArrayElement(array.PointerName, definition, array.LengthName, value);
        var appendNextLen = NextTemp("generic_array_next_len");
        EmitBinary(appendNextLen, "add", "i64", array.LengthName, "1");
        EmitBranch(doneLabel);
        var appendEnd = appendLabel;
        EmitFunctionLine();

        EmitLabel(growLabel);
        _currentBlockLabel = growLabel;
        var empty = NextTemp("generic_array_empty");
        EmitCompare(empty, "eq", "i64", array.CapacityName, "0");
        var doubled = NextTemp("generic_array_doubled");
        EmitBinary(doubled, "mul", "i64", array.CapacityName, "2");
        var newCapacity = NextTemp("generic_array_new_capacity");
        EmitSelect(newCapacity, empty, "i64 4", $"i64 {doubled}");
        var newBytes = NextTemp("generic_array_new_bytes");
        EmitBinary(
            newBytes,
            "mul",
            "i64",
            newCapacity,
            definition.ElementSize.ToString(CultureInfo.InvariantCulture));
        var newPointer = EmitHeapAllocate(newBytes);
        EmitCopyInlineBuffer(array.PointerName, newPointer, array.LengthName, definition, "generic_array_copy");
        EmitCall(target: null, "void", "sollang_free", $"ptr {array.PointerName}");
        StoreDynamicInlineArrayElement(newPointer, definition, array.LengthName, value);
        var growNextLen = NextTemp("generic_array_next_len");
        EmitBinary(growNextLen, "add", "i64", array.LengthName, "1");
        EmitBranch(doneLabel);
        var growEnd = _currentBlockLabel;
        EmitFunctionLine();

        EmitLabel(doneLabel);
        _currentBlockLabel = doneLabel;
        var resultPointer = NextTemp("generic_array_ptr");
        EmitPhi(resultPointer, "ptr", (array.PointerName, appendEnd), (newPointer, growEnd));
        var resultLength = NextTemp("generic_array_len");
        EmitPhi(resultLength, "i64", (appendNextLen, appendEnd), (growNextLen, growEnd));
        var resultCapacity = NextTemp("generic_array_capacity");
        EmitPhi(resultCapacity, "i64", (array.CapacityName, appendEnd), (newCapacity, growEnd));
        return array with
        {
            PointerName = resultPointer,
            LengthName = resultLength,
            CapacityName = resultCapacity
        };
    }

    private RuntimeDynamicInlineArray EmitDynamicInlineArrayReserve(
        RuntimeDynamicInlineArray array,
        string requested)
    {
        var definition = _program.Types.GetDynamicArray(array.ArrayType);
        var grow = NextTemp("generic_array_reserve_grow");
        EmitCompare(grow, "ugt", "i64", requested, array.CapacityName);
        var allocate = NextLabel("generic_array_reserve_allocate");
        var keep = NextLabel("generic_array_reserve_keep");
        var done = NextLabel("generic_array_reserve_done");
        EmitConditionalBranch(grow, allocate, keep); EmitFunctionLine();

        EmitLabel(keep);
        _currentBlockLabel = keep;
        EmitBranch(done);
        var keepEnd = _currentBlockLabel; EmitFunctionLine();

        EmitLabel(allocate);
        _currentBlockLabel = allocate;
        var bytes = NextTemp("generic_array_reserve_bytes");
        EmitBinary(bytes, "mul", "i64", requested,
            definition.ElementSize.ToString(CultureInfo.InvariantCulture));
        var pointer = EmitHeapAllocate(bytes);
        EmitCopyInlineBuffer(array.PointerName, pointer, array.LengthName, definition, "generic_array_reserve_copy");
        EmitCall(null, "void", "sollang_free", $"ptr {array.PointerName}");
        EmitBranch(done);
        var allocateEnd = _currentBlockLabel; EmitFunctionLine();

        EmitLabel(done);
        var resultPointer = NextTemp("generic_array_reserve_ptr");
        EmitPhi(resultPointer, "ptr", (array.PointerName, keepEnd), (pointer, allocateEnd));
        var capacity = NextTemp("generic_array_reserve_capacity");
        EmitPhi(capacity, "i64", (array.CapacityName, keepEnd), (requested, allocateEnd));
        _currentBlockLabel = done;
        return array with { PointerName = resultPointer, CapacityName = capacity };
    }

    private RuntimeDynamicInlineArray EmitDynamicInlineArrayPushAll(
        RuntimeDynamicInlineArray array,
        RuntimeValue source)
    {
        var (sourcePointer, sourceLength) = source switch
        {
            RuntimeStaticTextArray text => (text.PointerName, text.LengthName),
            RuntimeStaticInlineArray inline => (inline.PointerName, inline.LengthName),
            _ => throw new SollangException("pushAll expects a fixed-array source")
        };
        var definition = _program.Types.GetDynamicArray(array.ArrayType);
        var total = EmitCheckedCollectionLengthSum(
            array.LengthName, sourceLength, "generic_array_push_all");
        var reserved = EmitDynamicInlineArrayReserve(array, total);
        EmitCopyBufferAtOffset(
            sourcePointer,
            reserved.PointerName,
            sourceLength,
            array.LengthName,
            LlvmType(definition.ElementType),
            definition.ElementAlignment,
            "generic_array_push_all_copy");
        return reserved with { LengthName = total };
    }

    private string EmitCheckedCollectionLengthSum(string left, string right, string prefix)
    {
        var total = NextTemp(prefix + "_total");
        EmitBinary(total, "add", "i64", left, right);
        var valid = NextTemp(prefix + "_no_overflow");
        EmitCompare(valid, "uge", "i64", total, left);
        EmitTrapUnless(valid, prefix + "_overflow");
        return total;
    }

    private void EmitCopyBufferAtOffset(
        string sourcePointer,
        string targetPointer,
        string count,
        string targetOffset,
        string llvmType,
        int alignment,
        string prefix)
    {
        var entry = _currentBlockLabel;
        var loop = NextLabel(prefix);
        var body = NextLabel(prefix + "_body");
        var done = NextLabel(prefix + "_done");
        var next = NextTemp(prefix + "_next");
        EmitBranch(loop); EmitFunctionLine();

        EmitLabel(loop);
        var index = NextTemp(prefix + "_index");
        EmitPhi(index, "i64", ("0", entry), (next, body));
        var active = NextTemp(prefix + "_active");
        EmitCompare(active, "ult", "i64", index, count);
        EmitConditionalBranch(active, body, done); EmitFunctionLine();

        EmitLabel(body);
        _currentBlockLabel = body;
        var sourceSlot = NextTemp(prefix + "_source");
        EmitAssign(sourceSlot, $"getelementptr {llvmType}, ptr {sourcePointer}, i64 {index}");
        var item = NextTemp(prefix + "_item");
        EmitLoad(item, llvmType, sourceSlot, alignment);
        var targetIndex = NextTemp(prefix + "_target_index");
        EmitBinary(targetIndex, "add", "i64", targetOffset, index);
        var targetSlot = NextTemp(prefix + "_target");
        EmitAssign(targetSlot, $"getelementptr {llvmType}, ptr {targetPointer}, i64 {targetIndex}");
        EmitStore(llvmType, item, targetSlot, alignment);
        EmitBinary(next, "add", "i64", index, "1");
        EmitBranch(loop); EmitFunctionLine();

        EmitLabel(done);
        _currentBlockLabel = done;
    }

    private (RuntimeDynamicInlineArray Array, RuntimeValue Value) EmitDynamicInlineArrayTake(
        RuntimeDynamicInlineArray array,
        string index)
    {
        var value = EmitDynamicInlineArrayLoad(array, index);
        var elementType = array.ElementType;
        var elementAlignment = _program.Types.IsBoundedArray(array.ArrayType)
            ? _program.Types.GetBoundedArray(array.ArrayType).ElementAlignment
            : _program.Types.GetDynamicArray(array.ArrayType).ElementAlignment;
        var llvmType = LlvmType(elementType);
        var nextLength = NextTemp("generic_array_take_length");
        EmitBinary(nextLength, "sub", "i64", array.LengthName, "1");
        var entry = _currentBlockLabel;
        var loop = NextLabel("generic_array_take_shift");
        var body = NextLabel("generic_array_take_shift_body");
        var done = NextLabel("generic_array_take_shift_done");
        var next = NextTemp("generic_array_take_next");
        EmitBranch(loop); EmitFunctionLine();
        EmitLabel(loop);
        var current = NextTemp("generic_array_take_current");
        EmitPhi(current, "i64", (index, entry), (next, body));
        var active = NextTemp("generic_array_take_active");
        EmitCompare(active, "ult", "i64", current, nextLength);
        EmitConditionalBranch(active, body, done); EmitFunctionLine();
        EmitLabel(body);
        var sourceIndex = NextTemp("generic_array_take_source_index");
        EmitBinary(sourceIndex, "add", "i64", current, "1");
        var sourceSlot = NextTemp("generic_array_take_source");
        EmitAssign(sourceSlot, $"getelementptr {llvmType}, ptr {array.PointerName}, i64 {sourceIndex}");
        var moved = NextTemp("generic_array_take_moved");
        EmitLoad(moved, llvmType, sourceSlot, elementAlignment);
        var targetSlot = NextTemp("generic_array_take_target");
        EmitAssign(targetSlot, $"getelementptr {llvmType}, ptr {array.PointerName}, i64 {current}");
        EmitStore(llvmType, moved, targetSlot, elementAlignment);
        EmitBinary(next, "add", "i64", current, "1");
        EmitBranch(loop); EmitFunctionLine();
        EmitLabel(done);
        _currentBlockLabel = done;
        return (array with { LengthName = nextLength }, value);
    }

    private void EmitDictionaryAssignExisting(RuntimeIntDictionary dictionary, string key, string value)
    {
        var found = EmitDictionaryFindSlot(dictionary, key);
        EmitTrapUnless(found.FoundName, "dict_assign_missing");
        StoreDictionaryEntry(dictionary, found.SlotName, key, value);
    }

    private RuntimeIntDictionary EmitDictionaryGrow(RuntimeIntDictionary dictionary)
    {
        var hasAnyCapacity = NextTemp("dict_has_capacity");
        EmitCompare(hasAnyCapacity, "eq", "i64", dictionary.CapacityName, "0");
        var doubledCapacity = NextTemp("dict_doubled_capacity");
        EmitBinary(doubledCapacity, "mul", "i64", dictionary.CapacityName, "2");
        var newCapacity = NextTemp("dict_new_capacity");
        EmitSelect(newCapacity, hasAnyCapacity, "i64 4", $"i64 {doubledCapacity}");
        var newDictionary = new RuntimeIntDictionary(
            EmitDictionaryAllocate(newCapacity),
            dictionary.LengthName,
            newCapacity);
        EmitDictionaryRehash(dictionary, newDictionary);
        EmitCall(target: null, "void", "sollang_free", $"ptr {dictionary.PointerName}");
        return newDictionary;
    }

    private void EmitDictionaryRehash(RuntimeIntDictionary source, RuntimeIntDictionary target)
    {
        var entryLabel = _currentBlockLabel;
        var loopLabel = NextLabel("dict_rehash");
        var bodyLabel = NextLabel("dict_rehash_body");
        var moveLabel = NextLabel("dict_rehash_move");
        var nextLabel = NextLabel("dict_rehash_next");
        var doneLabel = NextLabel("dict_rehash_done");
        var nextI = NextTemp("dict_rehash_next_i");
        EmitBranch(loopLabel);
        EmitFunctionLine();
        EmitLabel(loopLabel);
        var i = NextTemp("dict_rehash_i");
        EmitPhi(i, "i64", ("0", entryLabel), (nextI, nextLabel));
        var active = NextTemp("dict_rehash_active");
        EmitCompare(active, "ult", "i64", i, source.CapacityName);
        EmitConditionalBranch(active, bodyLabel, doneLabel);
        EmitFunctionLine();
        EmitLabel(bodyLabel);
        var control = LoadDictionaryControl(source, i);
        var isFull = NextTemp("dict_rehash_full");
        EmitCompare(isFull, "ne", "i8", control, "0");
        EmitConditionalBranch(isFull, moveLabel, nextLabel);
        EmitFunctionLine();

        EmitLabel(moveLabel);
        _currentBlockLabel = moveLabel;
        var key = LoadDictionaryKey(source, i);
        var value = LoadDictionaryValue(source, i);
        EmitDictionaryInsertUnique(target, key.ValueName, value.ValueName);
        EmitBranch(nextLabel);
        EmitFunctionLine();

        EmitLabel(nextLabel);
        _currentBlockLabel = nextLabel;
        EmitBinary(nextI, "add", "i64", i, "1");
        EmitBranch(loopLabel);
        EmitFunctionLine();
        EmitLabel(doneLabel);
        _currentBlockLabel = doneLabel;
    }

    private DictionaryFindResult EmitDictionaryFindSlot(
        RuntimeIntDictionary dictionary,
        string key)
    {
        var hash = EmitHashInt(key);
        var h2 = EmitDictionaryH2Byte(hash);
        var capacityMask = EmitDictionaryCapacityMask(dictionary.CapacityName);
        var startSlot = EmitDictionaryStartSlot(hash, capacityMask);
        var entryLabel = _currentBlockLabel;
        var groupLoop = NextLabel("dict_group_find");
        var groupBody = NextLabel("dict_group_body");
        var candidateLoop = NextLabel("dict_group_candidates");
        var candidateBody = NextLabel("dict_group_candidate_body");
        var candidateNext = NextLabel("dict_group_candidate_next");
        var decision = NextLabel("dict_group_decision");
        var emptyLabel = NextLabel("dict_group_empty");
        var matchLabel = NextLabel("dict_group_match");
        var nextGroup = NextLabel("dict_group_next");
        var missLabel = NextLabel("dict_group_miss");
        var doneLabel = NextLabel("dict_group_done");
        var nextProbe = NextTemp("dict_group_next_probe");
        EmitBranch(groupLoop); EmitFunctionLine();

        EmitLabel(groupLoop); _currentBlockLabel = groupLoop;
        var probe = NextTemp("dict_group_probe");
        EmitPhi(probe, "i64", ("0", entryLabel), (nextProbe, nextGroup));
        var active = NextTemp("dict_group_active");
        EmitCompare(active, "ult", "i64", probe, dictionary.CapacityName);
        EmitConditionalBranch(active, groupBody, missLabel); EmitFunctionLine();

        EmitLabel(groupBody); _currentBlockLabel = groupBody;
        var unwrapped = NextTemp("dict_group_unwrapped");
        EmitBinary(unwrapped, "add", "i64", startSlot, probe);
        var groupStart = NextTemp("dict_group_start");
        EmitBinary(groupStart, "and", "i64", unwrapped, capacityMask);
        var groupPointer = NextTemp("dict_group_pointer");
        EmitAssign(groupPointer, $"getelementptr i8, ptr {dictionary.PointerName}, i64 {groupStart}");
        var controls = NextTemp("dict_group_controls");
        EmitLoad(controls, "<16 x i8>", groupPointer, 1);
        var h2Seed = NextTemp("dict_group_h2_seed");
        EmitAssign(h2Seed, $"insertelement <16 x i8> poison, i8 {h2}, i64 0");
        var h2Vector = NextTemp("dict_group_h2_vector");
        EmitAssign(h2Vector, $"shufflevector <16 x i8> {h2Seed}, <16 x i8> poison, <16 x i32> zeroinitializer");
        var matchesVector = NextTemp("dict_group_matches_vector");
        EmitAssign(matchesVector, $"icmp eq <16 x i8> {controls}, {h2Vector}");
        var matchBits = NextTemp("dict_group_match_bits");
        EmitAssign(matchBits, $"bitcast <16 x i1> {matchesVector} to i16");
        var emptyVector = NextTemp("dict_group_empty_vector");
        EmitAssign(emptyVector, $"icmp eq <16 x i8> {controls}, zeroinitializer");
        var emptyBits = NextTemp("dict_group_empty_bits");
        EmitAssign(emptyBits, $"bitcast <16 x i1> {emptyVector} to i16");
        EmitBranch(candidateLoop); EmitFunctionLine();

        EmitLabel(candidateLoop); _currentBlockLabel = candidateLoop;
        var candidateBits = NextTemp("dict_group_candidate_bits");
        var clearedBits = NextTemp("dict_group_cleared_bits");
        EmitPhi(candidateBits, "i16", (matchBits, groupBody), (clearedBits, candidateNext));
        var hasCandidate = NextTemp("dict_group_has_candidate");
        EmitCompare(hasCandidate, "ne", "i16", candidateBits, "0");
        EmitConditionalBranch(hasCandidate, candidateBody, decision); EmitFunctionLine();

        EmitLabel(candidateBody); _currentBlockLabel = candidateBody;
        var offset16 = NextTemp("dict_group_candidate_offset16");
        EmitCall(offset16, "i16", "llvm.cttz.i16", $"i16 {candidateBits}, i1 false");
        var offset = NextTemp("dict_group_candidate_offset");
        EmitAssign(offset, $"zext i16 {offset16} to i64");
        var candidateUnwrapped = NextTemp("dict_group_candidate_unwrapped");
        EmitBinary(candidateUnwrapped, "add", "i64", groupStart, offset);
        var candidateSlot = NextTemp("dict_group_candidate_slot");
        EmitBinary(candidateSlot, "and", "i64", candidateUnwrapped, capacityMask);
        var entryKey = LoadDictionaryKey(dictionary, candidateSlot);
        var keyMatch = NextTemp("dict_group_key_match");
        EmitCompare(keyMatch, "eq", "i32", entryKey.ValueName, key);
        EmitConditionalBranch(keyMatch, matchLabel, candidateNext); EmitFunctionLine();

        EmitLabel(candidateNext); _currentBlockLabel = candidateNext;
        var bitsMinusOne = NextTemp("dict_group_bits_minus_one");
        EmitBinary(bitsMinusOne, "sub", "i16", candidateBits, "1");
        EmitBinary(clearedBits, "and", "i16", candidateBits, bitsMinusOne);
        EmitBranch(candidateLoop); EmitFunctionLine();

        EmitLabel(decision); _currentBlockLabel = decision;
        var hasEmpty = NextTemp("dict_group_has_empty");
        EmitCompare(hasEmpty, "ne", "i16", emptyBits, "0");
        EmitConditionalBranch(hasEmpty, emptyLabel, nextGroup); EmitFunctionLine();

        EmitLabel(emptyLabel); _currentBlockLabel = emptyLabel;
        var emptyOffset16 = NextTemp("dict_group_empty_offset16");
        EmitCall(emptyOffset16, "i16", "llvm.cttz.i16", $"i16 {emptyBits}, i1 false");
        var emptyOffset = NextTemp("dict_group_empty_offset");
        EmitAssign(emptyOffset, $"zext i16 {emptyOffset16} to i64");
        var emptyUnwrapped = NextTemp("dict_group_empty_unwrapped");
        EmitBinary(emptyUnwrapped, "add", "i64", groupStart, emptyOffset);
        var emptySlot = NextTemp("dict_group_empty_slot");
        EmitBinary(emptySlot, "and", "i64", emptyUnwrapped, capacityMask);
        EmitBranch(doneLabel); EmitFunctionLine();

        EmitLabel(matchLabel); _currentBlockLabel = matchLabel;
        EmitBranch(doneLabel); EmitFunctionLine();

        EmitLabel(nextGroup); _currentBlockLabel = nextGroup;
        EmitBinary(nextProbe, "add", "i64", probe, "16");
        EmitBranch(groupLoop); EmitFunctionLine();

        EmitLabel(missLabel); _currentBlockLabel = missLabel;
        EmitBranch(doneLabel); EmitFunctionLine();

        EmitLabel(doneLabel);
        _currentBlockLabel = doneLabel;
        var foundName = NextTemp("dict_find_found");
        EmitPhi(foundName, "i1", ("false", emptyLabel), ("true", matchLabel), ("false", missLabel));
        var foundSlot = NextTemp("dict_find_found_slot");
        EmitPhi(foundSlot, "i64", (emptySlot, emptyLabel), (candidateSlot, matchLabel), ("0", missLabel));
        return new DictionaryFindResult(foundName, foundSlot, h2);
    }

    private void EmitDictionaryInsertUnique(RuntimeIntDictionary dictionary, string key, string value)
    {
        var found = EmitDictionaryFindSlot(dictionary, key);
        StoreDictionaryEntry(dictionary, found.SlotName, key, value);
        StoreDictionaryControl(dictionary, found.SlotName, found.H2ByteName);
    }

    private string LoadDictionaryControl(RuntimeIntDictionary dictionary, string slot)
    {
        var pointer = NextTemp("dict_control_slot");
        EmitAssign(pointer, $"getelementptr i8, ptr {dictionary.PointerName}, i64 {slot}");
        var control = NextTemp("dict_control");
        EmitLoad(control, "i8", pointer, 1);
        return control;
    }

    private void StoreDictionaryControl(RuntimeIntDictionary dictionary, string slot, string control)
    {
        var pointer = NextTemp("dict_control_slot");
        EmitAssign(pointer, $"getelementptr i8, ptr {dictionary.PointerName}, i64 {slot}");
        EmitStore("i8", control, pointer, 1);
        var mirrored = NextTemp("dict_control_mirrored");
        EmitCompare(mirrored, "ult", "i64", slot, "16");
        var mirror = NextLabel("dict_control_mirror");
        var done = NextLabel("dict_control_done");
        EmitConditionalBranch(mirrored, mirror, done); EmitFunctionLine();
        EmitLabel(mirror);
        var mirrorIndex = NextTemp("dict_control_mirror_index");
        EmitBinary(mirrorIndex, "add", "i64", dictionary.CapacityName, slot);
        var mirrorPointer = NextTemp("dict_control_mirror_slot");
        EmitAssign(mirrorPointer, $"getelementptr i8, ptr {dictionary.PointerName}, i64 {mirrorIndex}");
        EmitStore("i8", control, mirrorPointer, 1);
        EmitBranch(done); EmitFunctionLine();
        EmitLabel(done);
        _currentBlockLabel = done;
    }

    private string EmitHashInt(string key)
    {
        var wideKey = NextTemp("hash_key");
        EmitAssign(wideKey, $"sext i32 {key} to i64");
        return EmitHashWideInt(wideKey);
    }

    private string EmitHashInteger(RuntimeInt integer)
    {
        var width = NumericBitWidth(integer.Type);
        string wideKey;
        if (width == 64)
        {
            wideKey = integer.ValueName;
        }
        else
        {
            wideKey = NextTemp("hash_key");
            var extension = IsSignedIntegerType(integer.Type) ? "sext" : "zext";
            EmitAssign(wideKey, $"{extension} {LlvmType(integer.Type)} {integer.ValueName} to i64");
        }
        return EmitHashWideInt(wideKey);
    }

    private string EmitHashWideInt(string wideKey)
    {
        var folded = NextTemp("hash_fold");
        var high = NextTemp("hash_high");
        EmitBinary(high, "lshr", "i64", wideKey, "32");
        EmitBinary(folded, "xor", "i64", wideKey, high);
        var hash = NextTemp("hash");
        EmitBinary(hash, "mul", "i64", folded, "-7046029254386353131");
        return hash;
    }

    private string EmitDictionaryH2Byte(string hash)
    {
        var h2Shifted = NextTemp("dict_h2_shifted");
        EmitBinary(h2Shifted, "lshr", "i64", hash, "57");
        var h2Raw = NextTemp("dict_h2_raw");
        EmitBinary(h2Raw, "and", "i64", h2Shifted, "127");
        var isZero = NextTemp("dict_h2_zero");
        EmitCompare(isZero, "eq", "i64", h2Raw, "0");
        var h2 = NextTemp("dict_h2");
        EmitSelect(h2, isZero, "i64 1", $"i64 {h2Raw}");
        var h2Byte = NextTemp("dict_h2_byte");
        EmitAssign(h2Byte, $"trunc i64 {h2} to i8");
        return h2Byte;
    }

    private string EmitDictionaryCapacityMask(string capacity)
    {
        var mask = NextTemp("dict_capacity_mask");
        EmitBinary(mask, "sub", "i64", capacity, "1");
        return mask;
    }

    private string EmitDictionaryStartSlot(string hash, string capacityMask)
    {
        var slot = NextTemp("dict_start_slot");
        EmitBinary(slot, "and", "i64", hash, capacityMask);
        return slot;
    }

    private void EmitZeroByteBuffer(string pointer, string count, string prefix)
    {
        EmitInstruction($"call void @llvm.memset.p0.i64(ptr {pointer}, i8 0, i64 {count}, i1 false)");
    }

    private void EmitCopyIntBuffer(string sourcePointer, string targetPointer, string count, string prefix)
    {
        var entryLabel = _currentBlockLabel;
        var loopLabel = NextLabel(prefix);
        var bodyLabel = NextLabel(prefix + "_body");
        var doneLabel = NextLabel(prefix + "_done");
        var nextI = NextTemp(prefix + "_next_i");
        EmitBranch(loopLabel);
        EmitFunctionLine();
        EmitLabel(loopLabel);
        var i = NextTemp(prefix + "_i");
        EmitPhi(i, "i64", ("0", entryLabel), (nextI, bodyLabel));
        var active = NextTemp(prefix + "_active");
        EmitCompare(active, "ult", "i64", i, count);
        EmitConditionalBranch(active, bodyLabel, doneLabel);
        EmitFunctionLine();
        EmitLabel(bodyLabel);
        var sourceSlot = NextTemp(prefix + "_src");
        EmitAssign(sourceSlot, $"getelementptr i32, ptr {sourcePointer}, i64 {i}");
        var targetSlot = NextTemp(prefix + "_dst");
        EmitAssign(targetSlot, $"getelementptr i32, ptr {targetPointer}, i64 {i}");
        var value = LoadInt(sourceSlot, prefix + "_value");
        EmitStore("i32", value.ValueName, targetSlot, 4);
        EmitBinary(nextI, "add", "i64", i, "1");
        EmitBranch(loopLabel);
        EmitFunctionLine();
        EmitLabel(doneLabel);
        _currentBlockLabel = doneLabel;
    }

    private void EmitDictionaryRehashExcept(
        RuntimeIntDictionary source,
        RuntimeIntDictionary target,
        string removedSlot)
    {
        var entry = _currentBlockLabel;
        var loop = NextLabel("dict_take_rehash");
        var body = NextLabel("dict_take_rehash_body");
        var inspect = NextLabel("dict_take_rehash_inspect");
        var move = NextLabel("dict_take_rehash_move");
        var next = NextLabel("dict_take_rehash_next");
        var done = NextLabel("dict_take_rehash_done");
        var nextI = NextTemp("dict_take_rehash_next_i");
        EmitBranch(loop); EmitFunctionLine();
        EmitLabel(loop);
        var i = NextTemp("dict_take_rehash_i");
        EmitPhi(i, "i64", ("0", entry), (nextI, next));
        var active = NextTemp("dict_take_rehash_active");
        EmitCompare(active, "ult", "i64", i, source.CapacityName);
        EmitConditionalBranch(active, body, done); EmitFunctionLine();
        EmitLabel(body);
        var removed = NextTemp("dict_take_rehash_removed");
        EmitCompare(removed, "eq", "i64", i, removedSlot);
        EmitConditionalBranch(removed, next, inspect); EmitFunctionLine();
        EmitLabel(inspect);
        var control = LoadDictionaryControl(source, i);
        var occupied = NextTemp("dict_take_rehash_occupied");
        EmitCompare(occupied, "ne", "i8", control, "0");
        EmitConditionalBranch(occupied, move, next); EmitFunctionLine();
        EmitLabel(move);
        _currentBlockLabel = move;
        var key = LoadDictionaryKey(source, i);
        var value = LoadDictionaryValue(source, i);
        EmitDictionaryInsertUnique(target, key.ValueName, value.ValueName);
        EmitBranch(next); EmitFunctionLine();
        EmitLabel(next);
        _currentBlockLabel = next;
        EmitBinary(nextI, "add", "i64", i, "1");
        EmitBranch(loop); EmitFunctionLine();
        EmitLabel(done);
        _currentBlockLabel = done;
    }

    private void EmitCopyInlineBuffer(
        string sourcePointer,
        string targetPointer,
        string count,
        BoundDynamicArrayDefinition definition,
        string prefix)
    {
        var entryLabel = _currentBlockLabel;
        var loopLabel = NextLabel(prefix);
        var bodyLabel = NextLabel(prefix + "_body");
        var doneLabel = NextLabel(prefix + "_done");
        var nextI = NextTemp(prefix + "_next_i");
        var llvmType = LlvmType(definition.ElementType);
        EmitBranch(loopLabel);
        EmitFunctionLine();
        EmitLabel(loopLabel);
        var i = NextTemp(prefix + "_i");
        EmitPhi(i, "i64", ("0", entryLabel), (nextI, bodyLabel));
        var active = NextTemp(prefix + "_active");
        EmitCompare(active, "ult", "i64", i, count);
        EmitConditionalBranch(active, bodyLabel, doneLabel);
        EmitFunctionLine();
        EmitLabel(bodyLabel);
        var sourceSlot = NextTemp(prefix + "_src");
        EmitAssign(sourceSlot, $"getelementptr {llvmType}, ptr {sourcePointer}, i64 {i}");
        var targetSlot = NextTemp(prefix + "_dst");
        EmitAssign(targetSlot, $"getelementptr {llvmType}, ptr {targetPointer}, i64 {i}");
        var item = NextTemp(prefix + "_value");
        EmitLoad(item, llvmType, sourceSlot, definition.ElementAlignment);
        EmitStore(llvmType, item, targetSlot, definition.ElementAlignment);
        EmitBinary(nextI, "add", "i64", i, "1");
        EmitBranch(loopLabel);
        EmitFunctionLine();
        EmitLabel(doneLabel);
        _currentBlockLabel = doneLabel;
    }

}

