using System.Globalization;
using Sollang.Compiler.Semantics;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private RuntimeBool EmitSetContains(RuntimeInlineDictionary set, RuntimeValue key)
    {
        var found = EmitInlineDictionaryFindExistingSlot(set, key);
        return new RuntimeBool(found.FoundName);
    }

    private (RuntimeInlineDictionary Set, RuntimeBool Inserted) EmitSetInsert(
        RuntimeInlineDictionary set,
        RuntimeValue key)
    {
        var found = EmitInlineDictionaryFindSlot(set, key);
        var duplicate = NextLabel("set_insert_duplicate");
        var insert = NextLabel("set_insert_new");
        var current = NextLabel("set_insert_current");
        var grow = NextLabel("set_insert_grow");
        var done = NextLabel("set_insert_done");
        EmitConditionalBranch(found.FoundName, duplicate, insert); EmitFunctionLine();

        EmitLabel(duplicate);
        _currentBlockLabel = duplicate;
        if (_program.Types.ContainsOwnedStorage(set.KeyType))
        {
            DropOwnedRuntimeValue(key);
        }
        EmitBranch(done);
        var duplicateEnd = _currentBlockLabel; EmitFunctionLine();

        EmitLabel(insert);
        _currentBlockLabel = insert;
        var nextLength = NextTemp("set_insert_length");
        EmitBinary(nextLength, "add", "i64", set.LengthName, "1");
        var numerator = NextTemp("set_insert_load_num");
        EmitBinary(numerator, "mul", "i64", nextLength, "8");
        var denominator = NextTemp("set_insert_load_den");
        EmitBinary(denominator, "mul", "i64", set.CapacityName, "7");
        var shouldGrow = NextTemp("set_insert_should_grow");
        EmitCompare(shouldGrow, "ugt", "i64", numerator, denominator);
        EmitConditionalBranch(shouldGrow, grow, current); EmitFunctionLine();

        EmitLabel(current);
        _currentBlockLabel = current;
        EmitSetStoreKey(set, found.SlotName, key);
        StoreInlineDictionaryControl(set, found.SlotName, found.H2ByteName);
        EmitBranch(done);
        var currentEnd = _currentBlockLabel; EmitFunctionLine();

        EmitLabel(grow);
        _currentBlockLabel = grow;
        var grown = EmitSetGrow(set);
        EmitSetInsertUnique(grown, key);
        EmitBranch(done);
        var growEnd = _currentBlockLabel; EmitFunctionLine();

        EmitLabel(done);
        var pointer = NextTemp("set_pointer");
        EmitPhi(pointer, "ptr", (set.PointerName, duplicateEnd), (set.PointerName, currentEnd), (grown.PointerName, growEnd));
        var length = NextTemp("set_length");
        EmitPhi(length, "i64", (set.LengthName, duplicateEnd), (nextLength, currentEnd), (nextLength, growEnd));
        var capacity = NextTemp("set_capacity");
        EmitPhi(capacity, "i64", (set.CapacityName, duplicateEnd), (set.CapacityName, currentEnd), (grown.CapacityName, growEnd));
        var inserted = NextTemp("set_inserted");
        EmitPhi(inserted, "i1", ("false", duplicateEnd), ("true", currentEnd), ("true", growEnd));
        _currentBlockLabel = done;
        return (set with { PointerName = pointer, LengthName = length, CapacityName = capacity }, new RuntimeBool(inserted));
    }

    private (RuntimeInlineDictionary Set, RuntimeBool Removed) EmitSetRemove(
        RuntimeInlineDictionary set,
        RuntimeValue key)
    {
        var found = EmitInlineDictionaryFindExistingSlot(set, key);
        var remove = NextLabel("set_remove_found");
        var miss = NextLabel("set_remove_missing");
        var keep = NextLabel("set_remove_keep_tombstone");
        var compact = NextLabel("set_remove_compact");
        var done = NextLabel("set_remove_done");
        EmitConditionalBranch(found.FoundName, remove, miss); EmitFunctionLine();

        EmitLabel(remove);
        _currentBlockLabel = remove;
        if (_program.Types.ContainsOwnedStorage(set.KeyType))
        {
            var stored = EmitSetLoadKey(set, found.SlotName, "set_remove_key");
            DropOwnedRuntimeValue(stored);
        }
        StoreInlineDictionaryControl(set, found.SlotName, "-1");
        var nextLength = NextTemp("set_remove_length");
        EmitBinary(nextLength, "sub", "i64", set.LengthName, "1");
        var compactThreshold = NextTemp("set_remove_compact_threshold");
        EmitBinary(compactThreshold, "lshr", "i64", set.CapacityName, "3");
        var shouldCompact = NextTemp("set_remove_should_compact");
        EmitCompare(shouldCompact, "eq", "i64", nextLength, compactThreshold);
        EmitConditionalBranch(shouldCompact, compact, keep); EmitFunctionLine();

        EmitLabel(keep);
        _currentBlockLabel = keep;
        EmitBranch(done);
        var keepEnd = _currentBlockLabel; EmitFunctionLine();

        EmitLabel(compact);
        _currentBlockLabel = compact;
        var compacted = EmitSetRehash(set with { LengthName = nextLength }, set.CapacityName, "set_compact");
        EmitBranch(done);
        var compactEnd = _currentBlockLabel; EmitFunctionLine();

        EmitLabel(miss);
        _currentBlockLabel = miss;
        EmitBranch(done);
        var missEnd = _currentBlockLabel; EmitFunctionLine();

        EmitLabel(done);
        var pointer = NextTemp("set_pointer");
        EmitPhi(pointer, "ptr", (set.PointerName, keepEnd), (compacted.PointerName, compactEnd), (set.PointerName, missEnd));
        var length = NextTemp("set_length");
        EmitPhi(length, "i64", (nextLength, keepEnd), (nextLength, compactEnd), (set.LengthName, missEnd));
        var removed = NextTemp("set_removed");
        EmitPhi(removed, "i1", ("true", keepEnd), ("true", compactEnd), ("false", missEnd));
        _currentBlockLabel = done;
        return (set with { PointerName = pointer, LengthName = length }, new RuntimeBool(removed));
    }

    private RuntimeInlineDictionary EmitSetGrow(RuntimeInlineDictionary set)
    {
        var capacity = NextTemp("set_grown_capacity");
        EmitBinary(capacity, "mul", "i64", set.CapacityName, "2");
        return EmitSetRehash(set, capacity, "set_rehash");
    }

    private RuntimeInlineDictionary EmitSetReserve(RuntimeInlineDictionary set, string requestedEntries)
    {
        var requestedCapacity = EmitDictionaryCapacityForEntries(requestedEntries, "set_reserve");
        var grow = NextTemp("set_reserve_grow");
        EmitCompare(grow, "ugt", "i64", requestedCapacity, set.CapacityName);
        var allocate = NextLabel("set_reserve_allocate");
        var keep = NextLabel("set_reserve_keep");
        var done = NextLabel("set_reserve_done");
        EmitConditionalBranch(grow, allocate, keep); EmitFunctionLine();

        EmitLabel(keep);
        _currentBlockLabel = keep;
        EmitBranch(done);
        var keepEnd = _currentBlockLabel; EmitFunctionLine();

        EmitLabel(allocate);
        _currentBlockLabel = allocate;
        var target = EmitSetRehash(set, requestedCapacity, "set_reserve_rehash");
        EmitBranch(done);
        var allocateEnd = _currentBlockLabel; EmitFunctionLine();

        EmitLabel(done);
        var pointer = NextTemp("set_reserve_ptr");
        EmitPhi(pointer, "ptr", (set.PointerName, keepEnd), (target.PointerName, allocateEnd));
        var capacity = NextTemp("set_reserve_capacity_result");
        EmitPhi(capacity, "i64", (set.CapacityName, keepEnd), (requestedCapacity, allocateEnd));
        _currentBlockLabel = done;
        return set with { PointerName = pointer, CapacityName = capacity };
    }

    private RuntimeInlineDictionary EmitSetRehash(
        RuntimeInlineDictionary set,
        string capacity,
        string prefix)
    {
        var definition = _program.Types.GetDictionary(set.DictionaryType);
        var grown = set with
        {
            PointerName = EmitInlineDictionaryAllocate(capacity, definition),
            CapacityName = capacity
        };
        var entry = _currentBlockLabel;
        var loop = NextLabel(prefix);
        var body = NextLabel(prefix + "_body");
        var move = NextLabel(prefix + "_move");
        var next = NextLabel(prefix + "_next");
        var done = NextLabel(prefix + "_done");
        var nextIndex = NextTemp(prefix + "_next_index");
        EmitBranch(loop); EmitFunctionLine();
        EmitLabel(loop); _currentBlockLabel = loop;
        var index = NextTemp(prefix + "_index");
        EmitPhi(index, "i64", ("0", entry), (nextIndex, next));
        var active = NextTemp(prefix + "_active");
        EmitCompare(active, "ult", "i64", index, set.CapacityName);
        EmitConditionalBranch(active, body, done); EmitFunctionLine();
        EmitLabel(body); _currentBlockLabel = body;
        var control = LoadInlineDictionaryControl(set, index);
        var occupied = NextTemp(prefix + "_occupied");
        EmitCompare(occupied, "sgt", "i8", control, "0");
        EmitConditionalBranch(occupied, move, next); EmitFunctionLine();
        EmitLabel(move); _currentBlockLabel = move;
        EmitSetInsertUnique(grown, EmitSetLoadKey(set, index, prefix + "_key"));
        EmitBranch(next); EmitFunctionLine();
        EmitLabel(next); _currentBlockLabel = next;
        EmitBinary(nextIndex, "add", "i64", index, "1");
        EmitBranch(loop); EmitFunctionLine();
        EmitLabel(done); _currentBlockLabel = done;
        EmitCall(null, "void", "sollang_free", $"ptr {set.PointerName}");
        return grown;
    }

    private void EmitSetInsertUnique(RuntimeInlineDictionary set, RuntimeValue key)
    {
        var found = EmitInlineDictionaryFindSlot(set, key);
        EmitSetStoreKey(set, found.SlotName, key);
        StoreInlineDictionaryControl(set, found.SlotName, found.H2ByteName);
    }

    private void EmitSetStoreKey(RuntimeInlineDictionary set, string slot, RuntimeValue key)
    {
        var definition = _program.Types.GetDictionary(set.DictionaryType);
        var materialized = MaterializeAggregateValue(key);
        EmitStore(materialized.TypeName, materialized.ValueName,
            EmitInlineDictionaryEntryPointer(set, slot, 0, "set_key"), definition.KeyAlignment);
    }

    private RuntimeValue EmitSetLoadKey(RuntimeInlineDictionary set, string slot, string prefix)
    {
        var definition = _program.Types.GetDictionary(set.DictionaryType);
        return LoadInlineDictionaryField(
            set, slot, definition.KeyType, 0, definition.KeyAlignment, prefix);
    }
}
