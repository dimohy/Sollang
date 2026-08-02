using System.Globalization;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Semantics;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private void EmitStreamJoinRuntimeCallbacks()
    {
        var index = 0;
        foreach (var pair in _program.StreamJoins)
        {
            var join = pair.Value;
            var concurrent = RequiresConcurrentJoinRuntime(join);
            var fields = join.Inputs.Select(InputStreamLlvmType).ToList();
            if (concurrent)
            {
                fields.Add("ptr");
                if (join.Policy == StreamJoinPolicy.Latest)
                {
                    fields.Add("i32");
                    fields.Add($"[{join.Inputs.Count.ToString(CultureInfo.InvariantCulture)} x i1]");
                    fields.AddRange(join.Inputs.Select(input => LlvmType(input.ElementType)));
                }
            }
            else if (join.Policy is StreamJoinPolicy.Concat or StreamJoinPolicy.Merge or StreamJoinPolicy.Latest)
            {
                fields.Add("i32");
            }
            if (!concurrent && join.Policy == StreamJoinPolicy.Latest)
            {
                fields.Add("i1");
            }
            if (!concurrent && join.Policy is StreamJoinPolicy.Merge or StreamJoinPolicy.Latest)
            {
                fields.Add($"[{join.Inputs.Count.ToString(CultureInfo.InvariantCulture)} x i1]");
            }
            if (!concurrent && join.Policy == StreamJoinPolicy.Latest)
            {
                fields.AddRange(join.Inputs.Select(input => LlvmType(input.ElementType)));
            }
            var info = new StreamJoinRuntimeInfo(
                "sollang_stream_join_" + index.ToString(CultureInfo.InvariantCulture),
                "{ " + string.Join(", ", fields) + " }",
                join);
            index++;
            _streamJoinRuntimeInfos.Add(pair.Key, info);
            switch (join.Policy)
            {
                case StreamJoinPolicy.Zip:
                    EmitZipRuntimeCallbacks(info);
                    break;
                case StreamJoinPolicy.Concat:
                    EmitConcatRuntimeCallbacks(info);
                    break;
                case StreamJoinPolicy.Merge:
                    if (concurrent)
                    {
                        EmitConcurrentMergeRuntimeCallbacks(info);
                    }
                    else
                    {
                        EmitMergeRuntimeCallbacks(info);
                    }
                    break;
                case StreamJoinPolicy.Latest:
                    if (concurrent)
                    {
                        EmitConcurrentLatestRuntimeCallbacks(info);
                    }
                    else
                    {
                        EmitLatestRuntimeCallbacks(info);
                    }
                    break;
            }
        }
    }

    private static bool RequiresConcurrentJoinRuntime(BoundStreamJoin join) =>
        join.Policy is StreamJoinPolicy.Merge or StreamJoinPolicy.Latest
        && join.Inputs.Any(static input => input.IsEvent);

    private string InputStreamLlvmType(BoundStreamJoinInput input) =>
        input.IsEvent ? "%sollang.event_stream" : "%sollang.stream";

    private void EmitZipRuntimeCallbacks(StreamJoinRuntimeInfo info)
    {
        var nextName = info.Prefix + "_next";
        EmitFunctionLine($"define internal i1 @{nextName}(ptr %context, ptr %output) #0 {{");
        EmitFunctionLine("entry:");
        var failureLabels = info.Join.Inputs.Select((_, inputIndex) =>
            inputIndex == 0 ? NextLabel("zip_runtime_done") : NextLabel("zip_runtime_partial")).ToArray();
        for (var inputIndex = 0; inputIndex < info.Join.Inputs.Count; inputIndex++)
        {
            var input = info.Join.Inputs[inputIndex];
            var stream = EmitLoadJoinInput(info, inputIndex, input);
            var outputAddress = NextTemp("zip_runtime_output");
            EmitInstruction(
                $"{outputAddress} = getelementptr {LlvmStructType(info.Join.OutputElementType)}, ptr %output, i32 0, i32 {inputIndex.ToString(CultureInfo.InvariantCulture)}");
            var hasValue = NextTemp("zip_runtime_has_value");
            EmitIndirectCall(
                hasValue,
                "i1",
                stream.NextName,
                $"ptr {stream.ContextName}, ptr {outputAddress}");
            var successLabel = inputIndex == info.Join.Inputs.Count - 1
                ? NextLabel("zip_runtime_emit")
                : NextLabel("zip_runtime_pull");
            EmitConditionalBranch(hasValue, successLabel, failureLabels[inputIndex]);
            EmitFunctionLine();
            EmitLabel(successLabel);
            if (inputIndex == info.Join.Inputs.Count - 1)
            {
                EmitFunctionLine("  ret i1 true");
            }
        }

        for (var failureIndex = 1; failureIndex < info.Join.Inputs.Count; failureIndex++)
        {
            EmitFunctionLine();
            EmitLabel(failureLabels[failureIndex]);
            for (var pulledIndex = failureIndex - 1; pulledIndex >= 0; pulledIndex--)
            {
                var input = info.Join.Inputs[pulledIndex];
                if (!_program.Types.ContainsOwnedStorage(input.ElementType))
                {
                    continue;
                }
                var address = NextTemp("zip_runtime_unmatched_address");
                EmitInstruction(
                    $"{address} = getelementptr {LlvmStructType(info.Join.OutputElementType)}, ptr %output, i32 0, i32 {pulledIndex.ToString(CultureInfo.InvariantCulture)}");
                var loaded = NextTemp("zip_runtime_unmatched");
                EmitLoad(loaded, LlvmType(input.ElementType), address, RuntimeAlignment(input.ElementType));
                DropOwnedRuntimeValue(DematerializeAggregateValue(input.ElementType, loaded));
            }
            EmitBranch(failureLabels[0]);
        }
        EmitFunctionLine();
        EmitLabel(failureLabels[0]);
        EmitFunctionLine("  ret i1 false");
        EmitFunctionLine("}");
        EmitFunctionLine();
        EmitStreamJoinDropCallback(info);
    }

    private void EmitConcatRuntimeCallbacks(StreamJoinRuntimeInfo info)
    {
        var nextName = info.Prefix + "_next";
        EmitFunctionLine($"define internal i1 @{nextName}(ptr %context, ptr %output) #0 {{");
        EmitFunctionLine("entry:");
        var cursorAddress = NextTemp("concat_runtime_cursor_address");
        EmitInstruction(
            $"{cursorAddress} = getelementptr {info.ContextType}, ptr %context, i32 0, i32 {info.Join.Inputs.Count.ToString(CultureInfo.InvariantCulture)}");
        var cursor = NextTemp("concat_runtime_cursor");
        EmitLoad(cursor, "i32", cursorAddress, 4);
        var doneLabel = NextLabel("concat_runtime_done");
        var inputLabels = info.Join.Inputs.Select((_, inputIndex) =>
            NextLabel("concat_runtime_input_" + inputIndex.ToString(CultureInfo.InvariantCulture))).ToArray();
        EmitFunctionLine("  switch i32 " + cursor + ", label %" + doneLabel + " [");
        for (var inputIndex = 0; inputIndex < inputLabels.Length; inputIndex++)
        {
            EmitFunctionLine($"    i32 {inputIndex.ToString(CultureInfo.InvariantCulture)}, label %{inputLabels[inputIndex]}");
        }
        EmitFunctionLine("  ]");
        for (var inputIndex = 0; inputIndex < info.Join.Inputs.Count; inputIndex++)
        {
            EmitFunctionLine();
            EmitLabel(inputLabels[inputIndex]);
            var input = info.Join.Inputs[inputIndex];
            var stream = EmitLoadJoinInput(info, inputIndex, input);
            var hasValue = NextTemp("concat_runtime_has_value");
            EmitIndirectCall(
                hasValue,
                "i1",
                stream.NextName,
                $"ptr {stream.ContextName}, ptr %output");
            var emitLabel = NextLabel("concat_runtime_emit");
            var exhaustedLabel = NextLabel("concat_runtime_exhausted");
            EmitConditionalBranch(hasValue, emitLabel, exhaustedLabel);
            EmitFunctionLine();
            EmitLabel(emitLabel);
            EmitFunctionLine("  ret i1 true");
            EmitFunctionLine();
            EmitLabel(exhaustedLabel);
            EmitStore(
                "i32",
                (inputIndex + 1).ToString(CultureInfo.InvariantCulture),
                cursorAddress,
                4);
            EmitBranch(inputIndex == info.Join.Inputs.Count - 1
                ? doneLabel
                : inputLabels[inputIndex + 1]);
        }
        EmitFunctionLine();
        EmitLabel(doneLabel);
        EmitFunctionLine("  ret i1 false");
        EmitFunctionLine("}");
        EmitFunctionLine();
        EmitStreamJoinDropCallback(info);
    }

    private void EmitMergeRuntimeCallbacks(StreamJoinRuntimeInfo info)
    {
        var count = info.Join.Inputs.Count;
        EmitFunctionLine($"define internal i1 @{info.Prefix}_next(ptr %context, ptr %output) #0 {{");
        EmitFunctionLine("entry:");
        var scanSlot = NextTemp("merge_runtime_scan_slot");
        var checkedSlot = NextTemp("merge_runtime_checked_slot");
        EmitAlloca(scanSlot, "i32", 4);
        EmitAlloca(checkedSlot, "i32", 4);
        var cursorAddress = EmitJoinContextFieldAddress(info, count, "merge_runtime_cursor_address");
        var cursor = NextTemp("merge_runtime_cursor");
        EmitLoad(cursor, "i32", cursorAddress, 4);
        EmitStore("i32", cursor, scanSlot, 4);
        EmitStore("i32", "0", checkedSlot, 4);
        var loopLabel = NextLabel("merge_runtime_loop");
        var doneLabel = NextLabel("merge_runtime_done");
        var inputLabels = Enumerable.Range(0, count)
            .Select(index => NextLabel("merge_runtime_input_" + index.ToString(CultureInfo.InvariantCulture)))
            .ToArray();
        EmitBranch(loopLabel);
        EmitFunctionLine();
        EmitLabel(loopLabel);
        var checkedCount = NextTemp("merge_runtime_checked");
        EmitLoad(checkedCount, "i32", checkedSlot, 4);
        var exhausted = NextTemp("merge_runtime_exhausted");
        EmitCompare(exhausted, "eq", "i32", checkedCount, count.ToString(CultureInfo.InvariantCulture));
        var dispatchLabel = NextLabel("merge_runtime_dispatch");
        EmitConditionalBranch(exhausted, doneLabel, dispatchLabel);
        EmitFunctionLine();
        EmitLabel(dispatchLabel);
        var scan = NextTemp("merge_runtime_scan");
        EmitLoad(scan, "i32", scanSlot, 4);
        EmitFunctionLine("  switch i32 " + scan + ", label %" + doneLabel + " [");
        for (var index = 0; index < count; index++)
        {
            EmitFunctionLine($"    i32 {index.ToString(CultureInfo.InvariantCulture)}, label %{inputLabels[index]}");
        }
        EmitFunctionLine("  ]");

        for (var index = 0; index < count; index++)
        {
            EmitFunctionLine();
            EmitLabel(inputLabels[index]);
            var activeAddress = EmitJoinActiveAddress(info, index, latest: false);
            var active = NextTemp("merge_runtime_active");
            EmitLoad(active, "i1", activeAddress, 1);
            var pullLabel = NextLabel("merge_runtime_pull");
            var advanceLabel = NextLabel("merge_runtime_advance");
            EmitConditionalBranch(active, pullLabel, advanceLabel);
            EmitFunctionLine();
            EmitLabel(pullLabel);
            var source = EmitLoadJoinInput(info, index, info.Join.Inputs[index]);
            var hasValue = NextTemp("merge_runtime_has_value");
            EmitIndirectCall(hasValue, "i1", source.NextName, $"ptr {source.ContextName}, ptr %output");
            var emitLabel = NextLabel("merge_runtime_emit");
            var markExhaustedLabel = NextLabel("merge_runtime_mark_exhausted");
            EmitConditionalBranch(hasValue, emitLabel, markExhaustedLabel);
            EmitFunctionLine();
            EmitLabel(emitLabel);
            EmitStore("i32", ((index + 1) % count).ToString(CultureInfo.InvariantCulture), cursorAddress, 4);
            EmitFunctionLine("  ret i1 true");
            EmitFunctionLine();
            EmitLabel(markExhaustedLabel);
            EmitStore("i1", "false", activeAddress, 1);
            EmitBranch(advanceLabel);
            EmitFunctionLine();
            EmitLabel(advanceLabel);
            EmitStore("i32", ((index + 1) % count).ToString(CultureInfo.InvariantCulture), scanSlot, 4);
            var previousChecked = NextTemp("merge_runtime_previous_checked");
            EmitLoad(previousChecked, "i32", checkedSlot, 4);
            var nextChecked = NextTemp("merge_runtime_next_checked");
            EmitBinary(nextChecked, "add", "i32", previousChecked, "1");
            EmitStore("i32", nextChecked, checkedSlot, 4);
            EmitBranch(loopLabel);
        }

        EmitFunctionLine();
        EmitLabel(doneLabel);
        EmitFunctionLine("  ret i1 false");
        EmitFunctionLine("}");
        EmitFunctionLine();
        EmitStreamJoinDropCallback(info);
    }

    private void EmitLatestRuntimeCallbacks(StreamJoinRuntimeInfo info)
    {
        var count = info.Join.Inputs.Count;
        EmitFunctionLine($"define internal i1 @{info.Prefix}_next(ptr %context, ptr %output) #0 {{");
        EmitFunctionLine("entry:");
        var cursorAddress = EmitJoinContextFieldAddress(info, count, "latest_runtime_cursor_address");
        var initializedAddress = EmitJoinContextFieldAddress(info, count + 1, "latest_runtime_initialized_address");
        var initialized = NextTemp("latest_runtime_initialized");
        EmitLoad(initialized, "i1", initializedAddress, 1);
        var initialLabel = NextLabel("latest_runtime_initial");
        var scanEntryLabel = NextLabel("latest_runtime_scan_entry");
        var doneLabel = NextLabel("latest_runtime_done");
        EmitConditionalBranch(initialized, scanEntryLabel, initialLabel);
        EmitFunctionLine();
        EmitLabel(initialLabel);
        for (var index = 0; index < count; index++)
        {
            var source = EmitLoadJoinInput(info, index, info.Join.Inputs[index]);
            var cacheAddress = EmitJoinLatestCacheAddress(info, index);
            var hasValue = NextTemp("latest_runtime_has_initial");
            EmitIndirectCall(hasValue, "i1", source.NextName, $"ptr {source.ContextName}, ptr {cacheAddress}");
            var nextLabel = NextLabel("latest_runtime_initial_next");
            EmitConditionalBranch(hasValue, nextLabel, doneLabel);
            EmitFunctionLine();
            EmitLabel(nextLabel);
        }
        EmitStore("i1", "true", initializedAddress, 1);
        EmitStore("i32", "0", cursorAddress, 4);
        EmitLatestRuntimeSnapshot(info);

        EmitFunctionLine();
        EmitLabel(scanEntryLabel);
        var scanSlot = NextTemp("latest_runtime_scan_slot");
        var checkedSlot = NextTemp("latest_runtime_checked_slot");
        EmitAlloca(scanSlot, "i32", 4);
        EmitAlloca(checkedSlot, "i32", 4);
        var cursor = NextTemp("latest_runtime_cursor");
        EmitLoad(cursor, "i32", cursorAddress, 4);
        EmitStore("i32", cursor, scanSlot, 4);
        EmitStore("i32", "0", checkedSlot, 4);
        var loopLabel = NextLabel("latest_runtime_loop");
        var inputLabels = Enumerable.Range(0, count)
            .Select(index => NextLabel("latest_runtime_input_" + index.ToString(CultureInfo.InvariantCulture)))
            .ToArray();
        EmitBranch(loopLabel);
        EmitFunctionLine();
        EmitLabel(loopLabel);
        var checkedCount = NextTemp("latest_runtime_checked");
        EmitLoad(checkedCount, "i32", checkedSlot, 4);
        var exhausted = NextTemp("latest_runtime_exhausted");
        EmitCompare(exhausted, "eq", "i32", checkedCount, count.ToString(CultureInfo.InvariantCulture));
        var dispatchLabel = NextLabel("latest_runtime_dispatch");
        EmitConditionalBranch(exhausted, doneLabel, dispatchLabel);
        EmitFunctionLine();
        EmitLabel(dispatchLabel);
        var scan = NextTemp("latest_runtime_scan");
        EmitLoad(scan, "i32", scanSlot, 4);
        EmitFunctionLine("  switch i32 " + scan + ", label %" + doneLabel + " [");
        for (var index = 0; index < count; index++)
        {
            EmitFunctionLine($"    i32 {index.ToString(CultureInfo.InvariantCulture)}, label %{inputLabels[index]}");
        }
        EmitFunctionLine("  ]");

        for (var index = 0; index < count; index++)
        {
            EmitFunctionLine();
            EmitLabel(inputLabels[index]);
            var activeAddress = EmitJoinActiveAddress(info, index, latest: true);
            var active = NextTemp("latest_runtime_active");
            EmitLoad(active, "i1", activeAddress, 1);
            var pullLabel = NextLabel("latest_runtime_pull");
            var advanceLabel = NextLabel("latest_runtime_advance");
            EmitConditionalBranch(active, pullLabel, advanceLabel);
            EmitFunctionLine();
            EmitLabel(pullLabel);
            var source = EmitLoadJoinInput(info, index, info.Join.Inputs[index]);
            var cacheAddress = EmitJoinLatestCacheAddress(info, index);
            var hasValue = NextTemp("latest_runtime_has_value");
            EmitIndirectCall(hasValue, "i1", source.NextName, $"ptr {source.ContextName}, ptr {cacheAddress}");
            var emitLabel = NextLabel("latest_runtime_emit");
            var markExhaustedLabel = NextLabel("latest_runtime_mark_exhausted");
            EmitConditionalBranch(hasValue, emitLabel, markExhaustedLabel);
            EmitFunctionLine();
            EmitLabel(emitLabel);
            EmitStore("i32", ((index + 1) % count).ToString(CultureInfo.InvariantCulture), cursorAddress, 4);
            EmitLatestRuntimeSnapshot(info);
            EmitFunctionLine();
            EmitLabel(markExhaustedLabel);
            EmitStore("i1", "false", activeAddress, 1);
            EmitBranch(advanceLabel);
            EmitFunctionLine();
            EmitLabel(advanceLabel);
            EmitStore("i32", ((index + 1) % count).ToString(CultureInfo.InvariantCulture), scanSlot, 4);
            var previousChecked = NextTemp("latest_runtime_previous_checked");
            EmitLoad(previousChecked, "i32", checkedSlot, 4);
            var nextChecked = NextTemp("latest_runtime_next_checked");
            EmitBinary(nextChecked, "add", "i32", previousChecked, "1");
            EmitStore("i32", nextChecked, checkedSlot, 4);
            EmitBranch(loopLabel);
        }

        EmitFunctionLine();
        EmitLabel(doneLabel);
        EmitFunctionLine("  ret i1 false");
        EmitFunctionLine("}");
        EmitFunctionLine();
        EmitStreamJoinDropCallback(info);
    }

    private void EmitLatestRuntimeSnapshot(StreamJoinRuntimeInfo info)
    {
        var outputType = LlvmStructType(info.Join.OutputElementType);
        var aggregate = "poison";
        for (var index = 0; index < info.Join.Inputs.Count; index++)
        {
            var input = info.Join.Inputs[index];
            var cacheAddress = EmitJoinLatestCacheAddress(info, index);
            var value = NextTemp("latest_runtime_value");
            EmitLoad(value, LlvmType(input.ElementType), cacheAddress, RuntimeAlignment(input.ElementType));
            var next = NextTemp("latest_runtime_product");
            EmitAssign(next, $"insertvalue {outputType} {aggregate}, {LlvmType(input.ElementType)} {value}, {index.ToString(CultureInfo.InvariantCulture)}");
            aggregate = next;
        }
        EmitStore(outputType, aggregate, "%output", RuntimeAlignment(info.Join.OutputElementType));
        EmitFunctionLine("  ret i1 true");
    }

    private string EmitJoinContextFieldAddress(StreamJoinRuntimeInfo info, int fieldIndex, string prefix)
    {
        var address = NextTemp(prefix);
        EmitInstruction($"{address} = getelementptr {info.ContextType}, ptr %context, i32 0, i32 {fieldIndex.ToString(CultureInfo.InvariantCulture)}");
        return address;
    }

    private string EmitJoinActiveAddress(StreamJoinRuntimeInfo info, int inputIndex, bool latest)
    {
        var fieldIndex = info.Join.Inputs.Count + (latest ? 2 : 1);
        var address = NextTemp(latest ? "latest_runtime_active_address" : "merge_runtime_active_address");
        EmitInstruction($"{address} = getelementptr {info.ContextType}, ptr %context, i32 0, i32 {fieldIndex.ToString(CultureInfo.InvariantCulture)}, i32 {inputIndex.ToString(CultureInfo.InvariantCulture)}");
        return address;
    }

    private string EmitJoinLatestCacheAddress(StreamJoinRuntimeInfo info, int inputIndex)
    {
        var fieldIndex = info.Join.Inputs.Count + 3 + inputIndex;
        return EmitJoinContextFieldAddress(info, fieldIndex, "latest_runtime_cache_address");
    }

    private void EmitConcurrentMergeRuntimeCallbacks(StreamJoinRuntimeInfo info)
    {
        EmitConcurrentJoinInputCallbacks(info);
        EmitFunctionLine($"define internal i1 @{info.Prefix}_next(ptr %context, ptr %output) #0 {{");
        EmitFunctionLine("entry:");
        var runtime = EmitLoadConcurrentJoinRuntime(info);
        var indexAddress = NextTemp("merge_event_index_address");
        var kindAddress = NextTemp("merge_event_kind_address");
        var slotAddress = NextTemp("merge_event_slot_address");
        EmitAlloca(indexAddress, "i32", 4);
        EmitAlloca(kindAddress, "i32", 4);
        EmitAlloca(slotAddress, "ptr", 8);
        var waitLabel = NextLabel("merge_event_wait");
        var eventLabel = NextLabel("merge_event_received");
        var doneLabel = NextLabel("merge_event_done");
        EmitBranch(waitLabel);
        EmitFunctionLine();
        EmitLabel(waitLabel);
        var hasEvent = NextTemp("merge_event_available");
        EmitCall(hasEvent, "i1", "sollang_stream_join_runtime_next_event", $"ptr {runtime}, ptr {indexAddress}, ptr {kindAddress}, ptr {slotAddress}");
        EmitConditionalBranch(hasEvent, eventLabel, doneLabel);
        EmitFunctionLine();
        EmitLabel(eventLabel);
        var kind = NextTemp("merge_event_kind");
        EmitLoad(kind, "i32", kindAddress, 4);
        var isValue = NextTemp("merge_event_is_value");
        EmitCompare(isValue, "eq", "i32", kind, "0");
        var valueLabel = NextLabel("merge_event_value");
        EmitConditionalBranch(isValue, valueLabel, waitLabel);
        EmitFunctionLine();
        EmitLabel(valueLabel);
        var index = NextTemp("merge_event_index");
        EmitLoad(index, "i32", indexAddress, 4);
        var slot = NextTemp("merge_event_slot");
        EmitLoad(slot, "ptr", slotAddress, 8);
        var value = NextTemp("merge_event_value");
        EmitLoad(value, LlvmType(info.Join.OutputElementType), slot, RuntimeAlignment(info.Join.OutputElementType));
        EmitStore(LlvmType(info.Join.OutputElementType), value, "%output", RuntimeAlignment(info.Join.OutputElementType));
        EmitCall(target: null, "void", "sollang_stream_join_runtime_release", $"ptr {runtime}, i32 {index}");
        EmitFunctionLine("  ret i1 true");
        EmitFunctionLine();
        EmitLabel(doneLabel);
        EmitFunctionLine("  ret i1 false");
        EmitFunctionLine("}");
        EmitFunctionLine();
        EmitStreamJoinDropCallback(info);
    }

    private void EmitConcurrentLatestRuntimeCallbacks(StreamJoinRuntimeInfo info)
    {
        EmitConcurrentJoinInputCallbacks(info);
        var count = info.Join.Inputs.Count;
        EmitFunctionLine($"define internal i1 @{info.Prefix}_next(ptr %context, ptr %output) #0 {{");
        EmitFunctionLine("entry:");
        var runtime = EmitLoadConcurrentJoinRuntime(info);
        var indexAddress = NextTemp("latest_event_index_address");
        var kindAddress = NextTemp("latest_event_kind_address");
        var slotAddress = NextTemp("latest_event_slot_address");
        EmitAlloca(indexAddress, "i32", 4);
        EmitAlloca(kindAddress, "i32", 4);
        EmitAlloca(slotAddress, "ptr", 8);
        var waitLabel = NextLabel("latest_event_wait");
        var eventLabel = NextLabel("latest_event_received");
        var doneLabel = NextLabel("latest_event_done");
        var inputLabels = Enumerable.Range(0, count)
            .Select(index => NextLabel("latest_event_input_" + index.ToString(CultureInfo.InvariantCulture)))
            .ToArray();
        EmitBranch(waitLabel);
        EmitFunctionLine();
        EmitLabel(waitLabel);
        var hasEvent = NextTemp("latest_event_available");
        EmitCall(hasEvent, "i1", "sollang_stream_join_runtime_next_event", $"ptr {runtime}, ptr {indexAddress}, ptr {kindAddress}, ptr {slotAddress}");
        EmitConditionalBranch(hasEvent, eventLabel, doneLabel);
        EmitFunctionLine();
        EmitLabel(eventLabel);
        var index = NextTemp("latest_event_index");
        EmitLoad(index, "i32", indexAddress, 4);
        EmitFunctionLine("  switch i32 " + index + ", label %" + doneLabel + " [");
        for (var inputIndex = 0; inputIndex < count; inputIndex++)
        {
            EmitFunctionLine($"    i32 {inputIndex.ToString(CultureInfo.InvariantCulture)}, label %{inputLabels[inputIndex]}");
        }
        EmitFunctionLine("  ]");

        for (var inputIndex = 0; inputIndex < count; inputIndex++)
        {
            EmitFunctionLine();
            EmitLabel(inputLabels[inputIndex]);
            var kind = NextTemp("latest_event_kind");
            EmitLoad(kind, "i32", kindAddress, 4);
            var isValue = NextTemp("latest_event_is_value");
            EmitCompare(isValue, "eq", "i32", kind, "0");
            var valueLabel = NextLabel("latest_event_value");
            var completionLabel = NextLabel("latest_event_completion");
            var initializedAddress = EmitConcurrentLatestInitializedAddress(info, inputIndex);
            EmitConditionalBranch(isValue, valueLabel, completionLabel);
            EmitFunctionLine();
            EmitLabel(completionLabel);
            var wasInitialized = NextTemp("latest_event_was_initialized");
            EmitLoad(wasInitialized, "i1", initializedAddress, 1);
            var continueLabel = NextLabel("latest_event_completion_continue");
            var impossibleLabel = NextLabel("latest_event_initialization_impossible");
            EmitConditionalBranch(wasInitialized, continueLabel, impossibleLabel);
            EmitFunctionLine();
            EmitLabel(continueLabel);
            EmitBranch(waitLabel);
            EmitFunctionLine();
            EmitLabel(impossibleLabel);
            EmitCall(target: null, "void", "sollang_stream_join_runtime_cancel", $"ptr {runtime}");
            EmitFunctionLine("  ret i1 false");
            EmitFunctionLine();
            EmitLabel(valueLabel);
            var slot = NextTemp("latest_event_slot");
            EmitLoad(slot, "ptr", slotAddress, 8);
            var input = info.Join.Inputs[inputIndex];
            var value = NextTemp("latest_event_value");
            EmitLoad(value, LlvmType(input.ElementType), slot, RuntimeAlignment(input.ElementType));
            var cacheAddress = EmitConcurrentLatestCacheAddress(info, inputIndex);
            EmitStore(LlvmType(input.ElementType), value, cacheAddress, RuntimeAlignment(input.ElementType));
            EmitCall(target: null, "void", "sollang_stream_join_runtime_release", $"ptr {runtime}, i32 {inputIndex.ToString(CultureInfo.InvariantCulture)}");
            var alreadyInitialized = NextTemp("latest_event_already_initialized");
            EmitLoad(alreadyInitialized, "i1", initializedAddress, 1);
            var readyCheckLabel = NextLabel("latest_event_ready_check");
            var initializeLabel = NextLabel("latest_event_initialize_input");
            EmitConditionalBranch(alreadyInitialized, readyCheckLabel, initializeLabel);
            EmitFunctionLine();
            EmitLabel(initializeLabel);
            EmitStore("i1", "true", initializedAddress, 1);
            var initializedCountAddress = EmitJoinContextFieldAddress(info, count + 1, "latest_event_initialized_count_address");
            var initializedCount = NextTemp("latest_event_initialized_count");
            EmitLoad(initializedCount, "i32", initializedCountAddress, 4);
            var nextInitializedCount = NextTemp("latest_event_next_initialized_count");
            EmitBinary(nextInitializedCount, "add", "i32", initializedCount, "1");
            EmitStore("i32", nextInitializedCount, initializedCountAddress, 4);
            EmitBranch(readyCheckLabel);
            EmitFunctionLine();
            EmitLabel(readyCheckLabel);
            var currentInitializedCountAddress = EmitJoinContextFieldAddress(info, count + 1, "latest_event_current_initialized_count_address");
            var currentInitializedCount = NextTemp("latest_event_current_initialized_count");
            EmitLoad(currentInitializedCount, "i32", currentInitializedCountAddress, 4);
            var ready = NextTemp("latest_event_ready");
            EmitCompare(ready, "eq", "i32", currentInitializedCount, count.ToString(CultureInfo.InvariantCulture));
            var snapshotLabel = NextLabel("latest_event_snapshot");
            EmitConditionalBranch(ready, snapshotLabel, waitLabel);
            EmitFunctionLine();
            EmitLabel(snapshotLabel);
            EmitConcurrentLatestSnapshot(info);
        }

        EmitFunctionLine();
        EmitLabel(doneLabel);
        EmitFunctionLine("  ret i1 false");
        EmitFunctionLine("}");
        EmitFunctionLine();
        EmitStreamJoinDropCallback(info);
    }

    private void EmitConcurrentJoinInputCallbacks(StreamJoinRuntimeInfo info)
    {
        var count = info.Join.Inputs.Count;
        EmitFunctionLine($"define internal i1 @{info.Prefix}_pull(ptr %context, i32 %index, ptr %slot) #0 {{");
        EmitFunctionLine("entry:");
        var invalidLabel = NextLabel("stream_join_pull_invalid");
        var inputLabels = Enumerable.Range(0, count)
            .Select(index => NextLabel("stream_join_pull_" + index.ToString(CultureInfo.InvariantCulture)))
            .ToArray();
        EmitFunctionLine("  switch i32 %index, label %" + invalidLabel + " [");
        for (var index = 0; index < count; index++)
        {
            EmitFunctionLine($"    i32 {index.ToString(CultureInfo.InvariantCulture)}, label %{inputLabels[index]}");
        }
        EmitFunctionLine("  ]");
        for (var index = 0; index < count; index++)
        {
            EmitFunctionLine();
            EmitLabel(inputLabels[index]);
            var input = EmitLoadJoinInput(info, index, info.Join.Inputs[index]);
            var hasValue = NextTemp("stream_join_pulled");
            EmitIndirectCall(hasValue, "i1", input.NextName, $"ptr {input.ContextName}, ptr %slot");
            EmitFunctionLine($"  ret i1 {hasValue}");
        }
        EmitFunctionLine();
        EmitLabel(invalidLabel);
        EmitFunctionLine("  call void @llvm.trap()");
        EmitFunctionLine("  unreachable");
        EmitFunctionLine("}");
        EmitFunctionLine();

        EmitFunctionLine($"define internal void @{info.Prefix}_drop_item(ptr %context, i32 %index, ptr %slot) #0 {{");
        EmitFunctionLine("entry:");
        var ownedInputs = info.Join.Inputs
            .Select((input, index) => (input, index))
            .Where(pair => _program.Types.ContainsOwnedStorage(pair.input.ElementType))
            .ToArray();
        if (ownedInputs.Length == 0)
        {
            EmitFunctionLine("  ret void");
        }
        else
        {
            var doneLabel = NextLabel("stream_join_drop_item_done");
            var dropLabels = ownedInputs.Select(pair =>
                NextLabel("stream_join_drop_item_" + pair.index.ToString(CultureInfo.InvariantCulture))).ToArray();
            EmitFunctionLine("  switch i32 %index, label %" + doneLabel + " [");
            for (var ownedIndex = 0; ownedIndex < ownedInputs.Length; ownedIndex++)
            {
                EmitFunctionLine($"    i32 {ownedInputs[ownedIndex].index.ToString(CultureInfo.InvariantCulture)}, label %{dropLabels[ownedIndex]}");
            }
            EmitFunctionLine("  ]");
            for (var ownedIndex = 0; ownedIndex < ownedInputs.Length; ownedIndex++)
            {
                EmitFunctionLine();
                EmitLabel(dropLabels[ownedIndex]);
                var type = ownedInputs[ownedIndex].input.ElementType;
                var value = NextTemp("stream_join_pending_item");
                EmitLoad(value, LlvmType(type), "%slot", RuntimeAlignment(type));
                DropOwnedRuntimeValue(DematerializeAggregateValue(type, value));
                EmitBranch(doneLabel);
            }
            EmitFunctionLine();
            EmitLabel(doneLabel);
            EmitFunctionLine("  ret void");
        }
        EmitFunctionLine("}");
        EmitFunctionLine();
    }

    private string EmitLoadConcurrentJoinRuntime(StreamJoinRuntimeInfo info)
    {
        var address = EmitJoinContextFieldAddress(info, info.Join.Inputs.Count, "stream_join_runtime_address");
        var runtime = NextTemp("stream_join_runtime");
        EmitLoad(runtime, "ptr", address, 8);
        return runtime;
    }

    private string EmitConcurrentLatestInitializedAddress(StreamJoinRuntimeInfo info, int inputIndex)
    {
        var fieldIndex = info.Join.Inputs.Count + 2;
        var address = NextTemp("latest_event_initialized_address");
        EmitInstruction($"{address} = getelementptr {info.ContextType}, ptr %context, i32 0, i32 {fieldIndex.ToString(CultureInfo.InvariantCulture)}, i32 {inputIndex.ToString(CultureInfo.InvariantCulture)}");
        return address;
    }

    private string EmitConcurrentLatestCacheAddress(StreamJoinRuntimeInfo info, int inputIndex) =>
        EmitJoinContextFieldAddress(
            info,
            info.Join.Inputs.Count + 3 + inputIndex,
            "latest_event_cache_address");

    private void EmitConcurrentLatestSnapshot(StreamJoinRuntimeInfo info)
    {
        var outputType = LlvmStructType(info.Join.OutputElementType);
        var aggregate = "poison";
        for (var index = 0; index < info.Join.Inputs.Count; index++)
        {
            var input = info.Join.Inputs[index];
            var cacheAddress = EmitConcurrentLatestCacheAddress(info, index);
            var value = NextTemp("latest_event_snapshot_value");
            EmitLoad(value, LlvmType(input.ElementType), cacheAddress, RuntimeAlignment(input.ElementType));
            var next = NextTemp("latest_event_snapshot_product");
            EmitAssign(next, $"insertvalue {outputType} {aggregate}, {LlvmType(input.ElementType)} {value}, {index.ToString(CultureInfo.InvariantCulture)}");
            aggregate = next;
        }
        EmitStore(outputType, aggregate, "%output", RuntimeAlignment(info.Join.OutputElementType));
        EmitFunctionLine("  ret i1 true");
    }

    private void EmitStreamJoinDropCallback(StreamJoinRuntimeInfo info)
    {
        EmitFunctionLine($"define internal void @{info.Prefix}_drop(ptr %context) #0 {{");
        EmitFunctionLine("entry:");
        string? concurrentRuntime = null;
        if (RequiresConcurrentJoinRuntime(info.Join))
        {
            concurrentRuntime = EmitLoadConcurrentJoinRuntime(info);
            EmitCall(target: null, "void", "sollang_stream_join_runtime_cancel", $"ptr {concurrentRuntime}");
        }
        for (var inputIndex = 0; inputIndex < info.Join.Inputs.Count; inputIndex++)
        {
            DropOwnedRuntimeValue(EmitLoadJoinInput(info, inputIndex, info.Join.Inputs[inputIndex]));
        }
        if (concurrentRuntime is not null)
        {
            EmitCall(target: null, "void", "sollang_stream_join_runtime_join_destroy", $"ptr {concurrentRuntime}");
        }
        EmitCall(target: null, "void", "sollang_free", "ptr %context");
        EmitFunctionLine("  ret void");
        EmitFunctionLine("}");
        EmitFunctionLine();
    }

    private RuntimeProducerStream EmitLoadJoinInput(
        StreamJoinRuntimeInfo info,
        int inputIndex,
        BoundStreamJoinInput input)
    {
        var address = NextTemp("stream_join_input_address");
        EmitInstruction(
            $"{address} = getelementptr {info.ContextType}, ptr %context, i32 0, i32 {inputIndex.ToString(CultureInfo.InvariantCulture)}");
        var aggregate = NextTemp("stream_join_input");
        EmitLoad(aggregate, InputStreamLlvmType(input), address, 8);
        return DematerializeAggregateValue(input.StreamType, aggregate) as RuntimeProducerStream
            ?? throw new SollangException("stream join context field is not a producer handle");
    }

    private RuntimeProducerStream EmitRuntimeStreamJoinExpression(StreamJoinExpression expression)
    {
        if (!_streamJoinRuntimeInfos.TryGetValue(expression, out var info))
        {
            throw new SollangException("stream join runtime metadata is missing");
        }
        var product = EmitExpression(expression.Source) as RuntimeStruct
            ?? throw new SollangException("stream join source did not produce a product");
        if (product.Type != info.Join.InputProductType)
        {
            throw new SollangException("stream join input product type mismatch");
        }
        var contextSizePointer = NextTemp("stream_join_context_size_pointer");
        EmitInstruction($"{contextSizePointer} = getelementptr {info.ContextType}, ptr null, i32 1");
        var contextSize = NextTemp("stream_join_context_size");
        EmitInstruction($"{contextSize} = ptrtoint ptr {contextSizePointer} to i64");
        var context = NextTemp("stream_join_context");
        EmitCall(context, "ptr", "sollang_alloc", $"i64 {contextSize}");
        var allocated = NextTemp("stream_join_context_allocated");
        EmitCompare(allocated, "ne", "ptr", context, "null");
        EmitTrapUnless(allocated, "stream_join_context_alloc");
        var inputProductType = LlvmStructType(info.Join.InputProductType);
        for (var inputIndex = 0; inputIndex < info.Join.Inputs.Count; inputIndex++)
        {
            var input = info.Join.Inputs[inputIndex];
            var aggregate = NextTemp("stream_join_source");
            EmitAssign(
                aggregate,
                $"extractvalue {inputProductType} {product.ValueName}, {inputIndex.ToString(CultureInfo.InvariantCulture)}");
            var address = NextTemp("stream_join_context_input");
            EmitInstruction(
                $"{address} = getelementptr {info.ContextType}, ptr {context}, i32 0, i32 {inputIndex.ToString(CultureInfo.InvariantCulture)}");
            EmitStore(InputStreamLlvmType(input), aggregate, address, 8);
        }
        var concurrent = RequiresConcurrentJoinRuntime(info.Join);
        if (!concurrent && info.Join.Policy is StreamJoinPolicy.Concat or StreamJoinPolicy.Merge or StreamJoinPolicy.Latest)
        {
            var cursorAddress = NextTemp("concat_context_cursor");
            EmitInstruction(
                $"{cursorAddress} = getelementptr {info.ContextType}, ptr {context}, i32 0, i32 {info.Join.Inputs.Count.ToString(CultureInfo.InvariantCulture)}");
            EmitStore("i32", "0", cursorAddress, 4);
        }
        if (!concurrent && info.Join.Policy == StreamJoinPolicy.Latest)
        {
            var initializedAddress = NextTemp("latest_context_initialized");
            EmitInstruction($"{initializedAddress} = getelementptr {info.ContextType}, ptr {context}, i32 0, i32 {(info.Join.Inputs.Count + 1).ToString(CultureInfo.InvariantCulture)}");
            EmitStore("i1", "false", initializedAddress, 1);
        }
        if (!concurrent && info.Join.Policy is StreamJoinPolicy.Merge or StreamJoinPolicy.Latest)
        {
            var activeFieldIndex = info.Join.Inputs.Count
                + (info.Join.Policy == StreamJoinPolicy.Latest ? 2 : 1);
            for (var inputIndex = 0; inputIndex < info.Join.Inputs.Count; inputIndex++)
            {
                var activeAddress = NextTemp("stream_join_context_active");
                EmitInstruction($"{activeAddress} = getelementptr {info.ContextType}, ptr {context}, i32 0, i32 {activeFieldIndex.ToString(CultureInfo.InvariantCulture)}, i32 {inputIndex.ToString(CultureInfo.InvariantCulture)}");
                EmitStore("i1", "true", activeAddress, 1);
            }
        }
        if (concurrent)
        {
            if (info.Join.Policy == StreamJoinPolicy.Latest)
            {
                var initializedCountAddress = NextTemp("latest_event_initialized_count_address");
                EmitInstruction($"{initializedCountAddress} = getelementptr {info.ContextType}, ptr {context}, i32 0, i32 {(info.Join.Inputs.Count + 1).ToString(CultureInfo.InvariantCulture)}");
                EmitStore("i32", "0", initializedCountAddress, 4);
                var initializedFieldIndex = info.Join.Inputs.Count + 2;
                for (var inputIndex = 0; inputIndex < info.Join.Inputs.Count; inputIndex++)
                {
                    var initializedAddress = NextTemp("latest_event_initialized_address");
                    EmitInstruction($"{initializedAddress} = getelementptr {info.ContextType}, ptr {context}, i32 0, i32 {initializedFieldIndex.ToString(CultureInfo.InvariantCulture)}, i32 {inputIndex.ToString(CultureInfo.InvariantCulture)}");
                    EmitStore("i1", "false", initializedAddress, 1);
                }
            }
            var itemSize = EmitMaximumJoinItemSize(info);
            var runtime = NextTemp("stream_join_runtime");
            EmitCall(
                runtime,
                "ptr",
                "sollang_stream_join_runtime_create",
                $"i32 {info.Join.Inputs.Count.ToString(CultureInfo.InvariantCulture)}, i64 {itemSize}, ptr @{info.Prefix}_pull, ptr @{info.Prefix}_drop_item, ptr {context}");
            var runtimeCreated = NextTemp("stream_join_runtime_created");
            EmitCompare(runtimeCreated, "ne", "ptr", runtime, "null");
            EmitTrapUnless(runtimeCreated, "stream_join_runtime_create");
            var runtimeAddress = NextTemp("stream_join_runtime_address");
            EmitInstruction($"{runtimeAddress} = getelementptr {info.ContextType}, ptr {context}, i32 0, i32 {info.Join.Inputs.Count.ToString(CultureInfo.InvariantCulture)}");
            EmitStore("ptr", runtime, runtimeAddress, 8);
        }
        RemoveOwnedLiteralSources(expression.Source, info.Join.InputProductType);
        return new RuntimeProducerStream(
            info.Join.ResultType,
            info.Join.OutputElementType,
            context,
            "@" + info.Prefix + "_next",
            "@" + info.Prefix + "_drop",
            info.Join.IsEvent);
    }

    private string EmitMaximumJoinItemSize(StreamJoinRuntimeInfo info)
    {
        string? maximum = null;
        foreach (var input in info.Join.Inputs)
        {
            var sizePointer = NextTemp("stream_join_item_size_pointer");
            EmitInstruction($"{sizePointer} = getelementptr {LlvmType(input.ElementType)}, ptr null, i32 1");
            var size = NextTemp("stream_join_item_size");
            EmitInstruction($"{size} = ptrtoint ptr {sizePointer} to i64");
            if (maximum is null)
            {
                maximum = size;
                continue;
            }
            var larger = NextTemp("stream_join_item_size_larger");
            EmitCompare(larger, "ugt", "i64", size, maximum);
            var nextMaximum = NextTemp("stream_join_item_size_maximum");
            EmitAssign(nextMaximum, $"select i1 {larger}, i64 {size}, i64 {maximum}");
            maximum = nextMaximum;
        }
        return maximum ?? throw new SollangException("stream join requires at least one input");
    }
}
