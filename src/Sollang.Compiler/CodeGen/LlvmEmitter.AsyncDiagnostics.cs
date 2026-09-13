using System.Globalization;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Semantics;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private const int AsyncDiagnosticRecordBytes = 112;
    private const int AsyncDiagnosticHeaderBytes = 32;

    private RuntimeValue EmitAsyncDiagnosticCall(
        BoundFunction function,
        RuntimeValue? argument,
        IReadOnlyList<RuntimeValue> additionalArguments) => function.Kind switch
    {
        BoundFunctionKind.RuntimeDiagnosticSessionStart =>
            EmitDiagnosticSessionStart(function, argument, additionalArguments),
        BoundFunctionKind.RuntimeDiagnosticSessionTrack =>
            EmitDiagnosticSessionTrack(function, argument, additionalArguments),
        BoundFunctionKind.RuntimeDiagnosticSessionSnapshot =>
            EmitDiagnosticSessionSnapshot(function, argument, additionalArguments),
        BoundFunctionKind.RuntimeDiagnosticSessionClose =>
            EmitDiagnosticSessionClose(function, argument, additionalArguments),
        _ => throw new SollangException($"unsupported async diagnostic intrinsic '{function.Name}'")
    };

    private RuntimeEnum EmitDiagnosticSessionStart(
        BoundFunction function,
        RuntimeValue? argument,
        IReadOnlyList<RuntimeValue> additionalArguments)
    {
        if (argument is not RuntimeStruct limits || additionalArguments.Count != 0)
            throw new SollangException("startDiagnosticSession expects DiagnosticLimits");
        var maximum = NextTemp("diagnostic_maximum");
        EmitAssign(maximum, $"extractvalue {LlvmStructType(limits.Type)} {limits.ValueName}, 0");
        var maximumWide = NextTemp("diagnostic_maximum_wide");
        EmitAssign(maximumWide, $"sext i32 {maximum} to i64");
        var minimumOk = NextTemp("diagnostic_minimum_ok");
        EmitCompare(minimumOk, "sge", "i64", maximumWide, "1");
        var maximumOk = NextTemp("diagnostic_maximum_ok");
        EmitCompare(maximumOk, "sle", "i64", maximumWide, "65535");
        var valid = NextTemp("diagnostic_capacity_valid");
        EmitAssign(valid, $"and i1 {minimumOk}, {maximumOk}");
        var validLabel = NextLabel("diagnostic_start_valid");
        var invalidLabel = NextLabel("diagnostic_start_invalid");
        var mergeLabel = NextLabel("diagnostic_start_merge");
        EmitConditionalBranch(valid, validLabel, invalidLabel);

        EmitLabel(invalidLabel);
        var invalid = EmitDiagnosticError(function, "InvalidCapacity");
        EmitBranch(mergeLabel);
        var invalidExit = _currentBlockLabel;

        EmitLabel(validLabel);
        var sessionId = NextTemp("diagnostic_session_id");
        EmitLoad(sessionId, "i64", "@sollang_diagnostic_next_session_id", 8);
        var sessionIdAvailable = NextTemp("diagnostic_session_id_available");
        EmitCompare(sessionIdAvailable, "ne", "i64", sessionId, "18446744073709551615");
        var sessionIdAvailableLabel = NextLabel("diagnostic_start_session_id_available");
        var sessionIdExhaustedLabel = NextLabel("diagnostic_start_session_id_exhausted");
        EmitConditionalBranch(sessionIdAvailable, sessionIdAvailableLabel, sessionIdExhaustedLabel);

        EmitLabel(sessionIdExhaustedLabel);
        var sessionIdExhausted = EmitDiagnosticError(function, "SessionIdExhausted");
        EmitBranch(mergeLabel);
        var sessionIdExhaustedExit = _currentBlockLabel;

        EmitLabel(sessionIdAvailableLabel);
        var recordsBytes = NextTemp("diagnostic_records_bytes");
        EmitBinary(recordsBytes, "mul", "i64", maximumWide,
            AsyncDiagnosticRecordBytes.ToString(CultureInfo.InvariantCulture));
        var allocationBytes = NextTemp("diagnostic_allocation_bytes");
        EmitBinary(allocationBytes, "add", "i64", recordsBytes, "40");
        var session = NextTemp("diagnostic_session");
        EmitCall(session, "ptr", "sollang_alloc", $"i64 {allocationBytes}");
        var allocationOk = NextTemp("diagnostic_allocation_ok");
        EmitCompare(allocationOk, "ne", "ptr", session, "null");
        var allocatedLabel = NextLabel("diagnostic_start_allocated");
        var allocationFailedLabel = NextLabel("diagnostic_start_allocation_failed");
        EmitConditionalBranch(allocationOk, allocatedLabel, allocationFailedLabel);

        EmitLabel(allocationFailedLabel);
        var allocationFailed = EmitDiagnosticError(function, "AllocationFailed");
        EmitBranch(mergeLabel);
        var allocationFailedExit = _currentBlockLabel;

        EmitLabel(allocatedLabel);
        var nextSessionId = NextTemp("diagnostic_next_session_id");
        EmitBinary(nextSessionId, "add", "i64", sessionId, "1");
        EmitStore("i64", nextSessionId, "@sollang_diagnostic_next_session_id", 8);
        StoreDiagnosticSessionField(session, 0, "i64", sessionId, 8);
        StoreDiagnosticSessionField(session, 1, "i64", maximumWide, 8);
        StoreDiagnosticSessionField(session, 2, "i64", "0", 8);
        StoreDiagnosticSessionField(session, 3, "i64", "0", 8);
        var records = NextTemp("diagnostic_records");
        EmitAssign(records, $"getelementptr i8, ptr {session}, i64 40");
        StoreDiagnosticSessionField(session, 4, "ptr", records, 8);
        var token = NextTemp("diagnostic_session_token");
        EmitAssign(token, $"ptrtoint ptr {session} to i64");
        var sessionValue = EmitRuntimeStructAggregate(
            DiagnosticResultTypes(function.ReturnType).Ok,
            [new RuntimeInt(BoundType.UInt64, token)],
            "diagnostic_session_value");
        var resultDefinition = _program.Types.GetEnum(function.ReturnType);
        var success = EmitEnumValue(
            function.ReturnType,
            resultDefinition.Variants.First(static variant => variant.Name == "Ok"),
            sessionValue);
        EmitBranch(mergeLabel);
        var successExit = _currentBlockLabel;

        EmitLabel(mergeLabel);
        return EmitEnumPhi("diagnostic_start_result", function.ReturnType,
            [(invalid, invalidExit), (sessionIdExhausted, sessionIdExhaustedExit),
                (allocationFailed, allocationFailedExit), (success, successExit)]);
    }

    private RuntimeEnum EmitDiagnosticError(BoundFunction function, string errorName)
    {
        var resultDefinition = _program.Types.GetEnum(function.ReturnType);
        var errorType = DiagnosticResultTypes(function.ReturnType).Error;
        var errorDefinition = _program.Types.GetEnum(errorType);
        var error = EmitEnumValue(errorType,
            errorDefinition.Variants.First(variant => variant.Name == errorName), null);
        return EmitEnumValue(function.ReturnType,
            resultDefinition.Variants.First(static variant => variant.Name == "Err"), error);
    }

    private RuntimeEnum EmitDiagnosticSessionTrack(
        BoundFunction function,
        RuntimeValue? argument,
        IReadOnlyList<RuntimeValue> additionalArguments)
    {
        if (argument is not RuntimeMutableStructReference sessionReference
            || additionalArguments is not [RuntimeTask task]
            || DiagnosticHeaderForTask(task) is not { } header)
            throw new SollangException("DiagnosticSession.track expects mut session and move Task<U>");

        var session = LoadDiagnosticSessionPointer(sessionReference);
        var existingSessionSlot = DiagnosticHeaderField(header, 0, "diagnostic_existing_session_slot");
        var existingSession = NextTemp("diagnostic_existing_session");
        EmitLoad(existingSession, "ptr", existingSessionSlot, 8);
        var existingRecordSlot = DiagnosticHeaderField(header, 1, "diagnostic_existing_record_slot");
        var existingRecord = NextTemp("diagnostic_existing_record");
        EmitLoad(existingRecord, "ptr", existingRecordSlot, 8);
        var untracked = NextTemp("diagnostic_untracked");
        EmitCompare(untracked, "eq", "ptr", existingSession, "null");
        var attachLabel = NextLabel("diagnostic_track_attach");
        var alreadyLabel = NextLabel("diagnostic_track_already");
        var mergeLabel = NextLabel("diagnostic_track_merge");
        EmitConditionalBranch(untracked, attachLabel, alreadyLabel);

        EmitLabel(alreadyLabel);
        var sameSession = NextTemp("diagnostic_same_session");
        EmitCompare(sameSession, "eq", "ptr", existingSession, session);
        var alreadyFailureLabel = NextLabel("diagnostic_track_same_session");
        var crossFailureLabel = NextLabel("diagnostic_track_cross_session");
        var sameSessionLabel = NextLabel("diagnostic_track_same_session_inspect");
        EmitConditionalBranch(sameSession, sameSessionLabel, crossFailureLabel);
        EmitLabel(sameSessionLabel);
        var capacityRejected = NextTemp("diagnostic_track_capacity_rejected");
        EmitCompare(capacityRejected, "eq", "ptr", existingRecord, "null");
        var capacityRetryLabel = NextLabel("diagnostic_track_capacity_retry");
        EmitConditionalBranch(capacityRejected, capacityRetryLabel, alreadyFailureLabel);
        EmitLabel(capacityRetryLabel);
        var capacityRetry = EmitDiagnosticTrackFailure(function, task, "Capacity");
        EmitBranch(mergeLabel);
        var capacityRetryExit = _currentBlockLabel;
        EmitLabel(alreadyFailureLabel);
        var already = EmitDiagnosticTrackFailure(function, task, "AlreadyTracked");
        EmitBranch(mergeLabel);
        var alreadyExit = _currentBlockLabel;
        EmitLabel(crossFailureLabel);
        var cross = EmitDiagnosticTrackFailure(function, task, "CrossSession");
        EmitBranch(mergeLabel);
        var crossExit = _currentBlockLabel;

        EmitLabel(attachLabel);
        var attached = EmitAttachDiagnosticRecord(session, header, task.HandleName, "0");
        var successLabel = NextLabel("diagnostic_track_success");
        var capacityLabel = NextLabel("diagnostic_track_capacity");
        EmitConditionalBranch(attached, successLabel, capacityLabel);
        EmitLabel(capacityLabel);
        var capacity = EmitDiagnosticTrackFailure(function, task, "Capacity");
        EmitBranch(mergeLabel);
        var capacityExit = _currentBlockLabel;
        EmitLabel(successLabel);
        var resultDefinition = _program.Types.GetEnum(function.ReturnType);
        var success = EmitEnumValue(function.ReturnType,
            resultDefinition.Variants.First(static variant => variant.Name == "Ok"), task);
        EmitBranch(mergeLabel);
        var successExit = _currentBlockLabel;

        EmitLabel(mergeLabel);
        return EmitEnumPhi("diagnostic_track_result", function.ReturnType,
            [(capacityRetry, capacityRetryExit), (already, alreadyExit), (cross, crossExit),
                (capacity, capacityExit), (success, successExit)]);
    }

    private RuntimeEnum EmitDiagnosticTrackFailure(BoundFunction function, RuntimeTask task, string name)
    {
        var resultTypes = DiagnosticResultTypes(function.ReturnType);
        var product = _program.Types.GetStruct(resultTypes.Error);
        var kindType = product.Fields[1].Type;
        var kindDefinition = _program.Types.GetEnum(kindType);
        var kind = EmitEnumValue(kindType,
            kindDefinition.Variants.First(variant => variant.Name == name), null);
        var payload = EmitRuntimeStructAggregate(resultTypes.Error, [task, kind], "diagnostic_track_failure");
        var resultDefinition = _program.Types.GetEnum(function.ReturnType);
        return EmitEnumValue(function.ReturnType,
            resultDefinition.Variants.First(static variant => variant.Name == "Err"), payload);
    }

    private RuntimeValue EmitDiagnosticSessionSnapshot(
        BoundFunction function,
        RuntimeValue? argument,
        IReadOnlyList<RuntimeValue> additionalArguments)
    {
        if (additionalArguments is not [RuntimeStaticInlineArray output])
            throw new SollangException("DiagnosticSession.snapshot expects a mutable fixed TaskSnapshot array");
        var session = argument switch
        {
            RuntimeStruct value => ExtractDiagnosticSessionPointer(value.Type, value.ValueName),
            RuntimeMutableStructReference reference => LoadDiagnosticSessionPointer(reference),
            _ => throw new SollangException("DiagnosticSession.snapshot expects a session receiver")
        };
        var count = LoadDiagnosticSessionField(session, 2, "i64", 8, "diagnostic_snapshot_count");
        var records = LoadDiagnosticSessionField(session, 4, "ptr", 8, "diagnostic_snapshot_records");
        var snapshotType = output.ElementType;
        for (var index = 0; index < output.Length; index++)
        {
            var present = NextTemp("diagnostic_snapshot_present");
            EmitCompare(present, "ugt", "i64", count, index.ToString(CultureInfo.InvariantCulture));
            var writeLabel = NextLabel("diagnostic_snapshot_write");
            var doneLabel = NextLabel("diagnostic_snapshot_write_done");
            EmitConditionalBranch(present, writeLabel, doneLabel);
            EmitLabel(writeLabel);
            var record = NextTemp("diagnostic_snapshot_record");
            EmitAssign(record,
                $"getelementptr %sollang.diagnostic_record, ptr {records}, i64 {index.ToString(CultureInfo.InvariantCulture)}");
            var snapshot = EmitDiagnosticTaskSnapshot(snapshotType, record);
            var destination = NextTemp("diagnostic_snapshot_destination");
            EmitAssign(destination,
                $"getelementptr {LlvmStructType(snapshotType)}, ptr {output.PointerName}, i64 {index.ToString(CultureInfo.InvariantCulture)}");
            EmitStore(LlvmStructType(snapshotType), snapshot.ValueName, destination, RuntimeAlignment(snapshotType));
            EmitBranch(doneLabel);
            EmitLabel(doneLabel);
        }

        var sessionId = LoadDiagnosticSessionField(session, 0, "i64", 8, "diagnostic_snapshot_session_id");
        var outputLength = output.Length.ToString(CultureInfo.InvariantCulture);
        var truncated = NextTemp("diagnostic_snapshot_truncated");
        EmitCompare(truncated, "ugt", "i64", count, outputLength);
        var written = NextTemp("diagnostic_snapshot_written");
        EmitAssign(written, $"select i1 {truncated}, i64 {outputLength}, i64 {count}");
        return EmitRuntimeStructAggregate(function.ReturnType,
        [
            new RuntimeInt(BoundType.UInt64, sessionId),
            new RuntimeInt(BoundType.UIntSize, written),
            new RuntimeInt(BoundType.UIntSize, count),
            new RuntimeBool(truncated)
        ], "diagnostic_snapshot_result");
    }

    private RuntimeStruct EmitDiagnosticTaskSnapshot(BoundType snapshotType, string record)
    {
        var taskId = LoadDiagnosticRecordField(record, 0, "i64", 8, "diagnostic_snapshot_task_id");
        var parentId = LoadDiagnosticRecordField(record, 1, "i64", 8, "diagnostic_snapshot_parent_id");
        var control = LoadDiagnosticRecordField(record, 2, "ptr", 8, "diagnostic_snapshot_control");
        var terminalStatus = LoadDiagnosticRecordField(record, 3, "i32", 4, "diagnostic_snapshot_terminal_status");
        var isTerminal = NextTemp("diagnostic_snapshot_is_terminal");
        EmitCompare(isTerminal, "sge", "i32", terminalStatus, "0");
        var hasControl = NextTemp("diagnostic_snapshot_has_control");
        EmitCompare(hasControl, "ne", "ptr", control, "null");
        var notTerminal = NextTemp("diagnostic_snapshot_not_terminal");
        EmitAssign(notTerminal, $"xor i1 {isTerminal}, true");
        var hasLiveControl = NextTemp("diagnostic_snapshot_has_live_control");
        EmitAssign(hasLiveControl, $"and i1 {hasControl}, {notTerminal}");
        var loadLiveLabel = NextLabel("diagnostic_snapshot_load_live");
        var noLiveLabel = NextLabel("diagnostic_snapshot_no_live");
        var statusMergeLabel = NextLabel("diagnostic_snapshot_status_merge");
        EmitConditionalBranch(hasLiveControl, loadLiveLabel, noLiveLabel);
        EmitLabel(loadLiveLabel);
        var statusSlot = NextTemp("diagnostic_snapshot_status_slot");
        EmitAssign(statusSlot, $"getelementptr %sollang.task_control, ptr {control}, i32 0, i32 4");
        var liveStatus = NextTemp("diagnostic_snapshot_live_status");
        EmitLoad(liveStatus, "i32", statusSlot, 4);
        EmitBranch(statusMergeLabel);
        var liveExit = _currentBlockLabel;
        EmitLabel(noLiveLabel);
        EmitBranch(statusMergeLabel);
        var noLiveExit = _currentBlockLabel;
        EmitLabel(statusMergeLabel);
        var observedLiveStatus = NextTemp("diagnostic_snapshot_observed_live_status");
        EmitPhi(observedLiveStatus, "i32", [(liveStatus, liveExit), ("0", noLiveExit)]);
        var status = NextTemp("diagnostic_snapshot_status");
        EmitAssign(status, $"select i1 {isTerminal}, i32 {terminalStatus}, i32 {observedLiveStatus}");

        var definition = _program.Types.GetStruct(snapshotType);
        var parentOption = EmitDiagnosticOptionalUInt64(definition.Fields[1].Type, parentId);
        var lifecycle = EmitDiagnosticLifecycle(definition.Fields[2].Type, status);
        var waitState = EmitDiagnosticWaitState(definition.Fields[3].Type, status);
        var awaitedId = LoadDiagnosticRecordField(record, 5, "i64", 8, "diagnostic_snapshot_awaited_id");
        var awaitedOption = EmitDiagnosticOptionalUInt64(definition.Fields[4].Type, awaitedId);
        var deadline = LoadDiagnosticRecordField(record, 6, "i64", 8, "diagnostic_snapshot_deadline");
        var timerWaiting = NextTemp("diagnostic_snapshot_timer_waiting");
        EmitCompare(timerWaiting, "eq", "i32", status, "4");
        var visibleDeadline = NextTemp("diagnostic_snapshot_visible_deadline");
        EmitAssign(visibleDeadline, $"select i1 {timerWaiting}, i64 {deadline}, i64 0");
        var suspensionType = definition.Fields[6].Type;
        var suspension = EmitDiagnosticSuspensionOption(suspensionType, record, status, deadline);
        return EmitRuntimeStructAggregate(snapshotType,
        [
            new RuntimeInt(BoundType.UInt64, taskId),
            parentOption,
            lifecycle,
            waitState,
            awaitedOption,
            new RuntimeInt(BoundType.UInt64, visibleDeadline),
            suspension
        ], "diagnostic_task_snapshot");
    }

    private RuntimeEnum EmitDiagnosticSuspensionOption(
        BoundType optionType,
        string record,
        string status,
        string deadline)
    {
        var resumeState = LoadDiagnosticRecordField(
            record, 4, "i32", 4, "diagnostic_snapshot_resume_state");
        var hasLocation = NextTemp("diagnostic_snapshot_has_location");
        EmitCompare(hasLocation, "ne", "i32", resumeState, "0");
        var isTimerRecord = NextTemp("diagnostic_snapshot_is_timer_record");
        EmitCompare(isTimerRecord, "ne", "i64", deadline, "0");
        var timerWaiting = NextTemp("diagnostic_snapshot_locator_timer_waiting");
        EmitCompare(timerWaiting, "eq", "i32", status, "4");
        var nonTimerRecord = NextTemp("diagnostic_snapshot_is_non_timer_record");
        EmitAssign(nonTimerRecord, $"xor i1 {isTimerRecord}, true");
        var visibleState = NextTemp("diagnostic_snapshot_locator_visible_state");
        EmitAssign(visibleState, $"or i1 {nonTimerRecord}, {timerWaiting}");
        var present = NextTemp("diagnostic_snapshot_has_suspension");
        EmitAssign(present, $"and i1 {hasLocation}, {visibleState}");
        var someLabel = NextLabel("diagnostic_suspension_some");
        var noneLabel = NextLabel("diagnostic_suspension_none");
        var mergeLabel = NextLabel("diagnostic_suspension_merge");
        EmitConditionalBranch(present, someLabel, noneLabel);

        var optionDefinition = _program.Types.GetEnum(optionType);
        var someVariant = optionDefinition.Variants.First(static variant => variant.Name == "Some");
        var noneVariant = optionDefinition.Variants.First(static variant => variant.Name == "None");
        var locatorType = someVariant.PayloadType
            ?? throw new SollangException("diagnostic SuspensionLocator option has no payload");

        EmitLabel(someLabel);
        var modulePointer = LoadDiagnosticRecordField(
            record, 7, "ptr", 8, "diagnostic_snapshot_module_pointer");
        var moduleLength = LoadDiagnosticRecordField(
            record, 8, "i64", 8, "diagnostic_snapshot_module_length");
        var functionPointer = LoadDiagnosticRecordField(
            record, 9, "ptr", 8, "diagnostic_snapshot_function_pointer");
        var functionLength = LoadDiagnosticRecordField(
            record, 10, "i64", 8, "diagnostic_snapshot_function_length");
        var byteOffset = LoadDiagnosticRecordField(
            record, 11, "i64", 8, "diagnostic_snapshot_byte_offset");
        var lineWide = LoadDiagnosticRecordField(
            record, 12, "i64", 8, "diagnostic_snapshot_line_wide");
        var columnWide = LoadDiagnosticRecordField(
            record, 13, "i64", 8, "diagnostic_snapshot_column_wide");
        var line = NextTemp("diagnostic_snapshot_line");
        EmitAssign(line, $"trunc i64 {lineWide} to i32");
        var column = NextTemp("diagnostic_snapshot_column");
        EmitAssign(column, $"trunc i64 {columnWide} to i32");
        var locator = EmitRuntimeStructAggregate(locatorType,
        [
            new RuntimeText(modulePointer, moduleLength),
            new RuntimeText(functionPointer, functionLength),
            new RuntimeInt(BoundType.Int, resumeState),
            new RuntimeInt(BoundType.UIntSize, byteOffset),
            new RuntimeInt(BoundType.Int, line),
            new RuntimeInt(BoundType.Int, column)
        ], "diagnostic_suspension_locator");
        var some = EmitEnumValue(optionType, someVariant, locator);
        EmitBranch(mergeLabel);
        var someExit = _currentBlockLabel;

        EmitLabel(noneLabel);
        var none = EmitEnumValue(optionType, noneVariant, null);
        EmitBranch(mergeLabel);
        var noneExit = _currentBlockLabel;

        EmitLabel(mergeLabel);
        return EmitEnumPhi("diagnostic_suspension", optionType, [(some, someExit), (none, noneExit)]);
    }

    private RuntimeEnum EmitDiagnosticOptionalUInt64(BoundType optionType, string value)
    {
        var definition = _program.Types.GetEnum(optionType);
        var some = definition.Variants.First(static variant => variant.Name == "Some");
        var none = definition.Variants.First(static variant => variant.Name == "None");
        var present = NextTemp("diagnostic_option_present");
        EmitCompare(present, "ne", "i64", value, "0");
        var someLabel = NextLabel("diagnostic_option_some");
        var noneLabel = NextLabel("diagnostic_option_none");
        var mergeLabel = NextLabel("diagnostic_option_merge");
        EmitConditionalBranch(present, someLabel, noneLabel);
        EmitLabel(someLabel);
        var someValue = EmitEnumValue(optionType, some, new RuntimeInt(BoundType.UInt64, value));
        EmitBranch(mergeLabel);
        var someExit = _currentBlockLabel;
        EmitLabel(noneLabel);
        var noneValue = EmitEnumValue(optionType, none, null);
        EmitBranch(mergeLabel);
        var noneExit = _currentBlockLabel;
        EmitLabel(mergeLabel);
        return EmitEnumPhi("diagnostic_option", optionType, [(someValue, someExit), (noneValue, noneExit)]);
    }

    private RuntimeEnum EmitDiagnosticLifecycle(BoundType type, string status)
    {
        var completed = NextTemp("diagnostic_lifecycle_completed");
        EmitCompare(completed, "eq", "i32", status, "2");
        var cancelled = NextTemp("diagnostic_lifecycle_cancelled");
        EmitCompare(cancelled, "eq", "i32", status, "3");
        var running = NextTemp("diagnostic_lifecycle_running");
        EmitCompare(running, "eq", "i32", status, "1");
        var pendingOrRunning = NextTemp("diagnostic_lifecycle_pending_or_running");
        EmitAssign(pendingOrRunning, $"select i1 {running}, i32 1, i32 0");
        var completedOrEarlier = NextTemp("diagnostic_lifecycle_completed_or_earlier");
        EmitAssign(completedOrEarlier, $"select i1 {completed}, i32 2, i32 {pendingOrRunning}");
        var tag = NextTemp("diagnostic_lifecycle_tag");
        EmitAssign(tag, $"select i1 {cancelled}, i32 3, i32 {completedOrEarlier}");
        return EmitDiagnosticPayloadlessEnum(type, tag, "diagnostic_lifecycle");
    }

    private RuntimeEnum EmitDiagnosticWaitState(BoundType type, string status)
    {
        var ready = NextTemp("diagnostic_wait_ready");
        EmitCompare(ready, "eq", "i32", status, "0");
        var timer = NextTemp("diagnostic_wait_timer");
        EmitCompare(timer, "eq", "i32", status, "4");
        var awaited = NextTemp("diagnostic_wait_awaited");
        EmitCompare(awaited, "eq", "i32", status, "5");
        var readyTag = NextTemp("diagnostic_wait_ready_tag");
        EmitAssign(readyTag, $"select i1 {ready}, i32 1, i32 0");
        var timerTag = NextTemp("diagnostic_wait_timer_tag");
        EmitAssign(timerTag, $"select i1 {timer}, i32 2, i32 {readyTag}");
        var tag = NextTemp("diagnostic_wait_tag");
        EmitAssign(tag, $"select i1 {awaited}, i32 3, i32 {timerTag}");
        return EmitDiagnosticPayloadlessEnum(type, tag, "diagnostic_wait");
    }

    private RuntimeEnum EmitDiagnosticPayloadlessEnum(BoundType type, string tag, string prefix)
    {
        var llvmType = LlvmEnumType(type);
        var slot = NextTemp(prefix + "_slot");
        EmitAlloca(slot, llvmType, 8);
        EmitStore(llvmType, "zeroinitializer", slot, 8);
        var tagSlot = NextTemp(prefix + "_tag_slot");
        EmitAssign(tagSlot, $"getelementptr inbounds {llvmType}, ptr {slot}, i32 0, i32 0");
        EmitStore("i32", tag, tagSlot, 4);
        var value = NextTemp(prefix + "_value");
        EmitLoad(value, llvmType, slot, 8);
        return new RuntimeEnum(type, value);
    }

    private RuntimeValue EmitDiagnosticSessionClose(
        BoundFunction function,
        RuntimeValue? argument,
        IReadOnlyList<RuntimeValue> additionalArguments)
    {
        if (argument is not RuntimeStruct sessionValue || additionalArguments.Count != 0)
            throw new SollangException("DiagnosticSession.close expects one moved session owner");
        var session = ExtractDiagnosticSessionPointer(sessionValue.Type, sessionValue.ValueName);
        var count = LoadDiagnosticSessionField(session, 2, "i64", 8, "diagnostic_close_count");
        var records = LoadDiagnosticSessionField(session, 4, "ptr", 8, "diagnostic_close_records");
        var indexSlot = NextTemp("diagnostic_close_index_slot");
        EmitAlloca(indexSlot, "i64", 8);
        EmitStore("i64", "0", indexSlot, 8);
        var busySlot = NextTemp("diagnostic_close_busy_slot");
        EmitAlloca(busySlot, "i1", 1);
        EmitStore("i1", "false", busySlot, 1);
        var loopLabel = NextLabel("diagnostic_close_loop");
        var inspectLabel = NextLabel("diagnostic_close_inspect");
        var doneLabel = NextLabel("diagnostic_close_done");
        EmitBranch(loopLabel);
        EmitLabel(loopLabel);
        var index = NextTemp("diagnostic_close_index");
        EmitLoad(index, "i64", indexSlot, 8);
        var more = NextTemp("diagnostic_close_more");
        EmitCompare(more, "ult", "i64", index, count);
        EmitConditionalBranch(more, inspectLabel, doneLabel);
        EmitLabel(inspectLabel);
        var record = NextTemp("diagnostic_close_record");
        EmitAssign(record, $"getelementptr %sollang.diagnostic_record, ptr {records}, i64 {index}");
        var terminal = LoadDiagnosticRecordField(record, 3, "i32", 4, "diagnostic_close_terminal");
        var frozen = NextTemp("diagnostic_close_frozen");
        EmitCompare(frozen, "sge", "i32", terminal, "2");
        var control = LoadDiagnosticRecordField(record, 2, "ptr", 8, "diagnostic_close_control");
        var loadLiveLabel = NextLabel("diagnostic_close_load_live");
        var noLiveLabel = NextLabel("diagnostic_close_no_live");
        var statusMergeLabel = NextLabel("diagnostic_close_status_merge");
        EmitConditionalBranch(frozen, noLiveLabel, loadLiveLabel);
        EmitLabel(loadLiveLabel);
        var statusSlot = NextTemp("diagnostic_close_status_slot");
        EmitAssign(statusSlot, $"getelementptr %sollang.task_control, ptr {control}, i32 0, i32 4");
        var liveStatus = NextTemp("diagnostic_close_live_status");
        EmitLoad(liveStatus, "i32", statusSlot, 4);
        EmitBranch(statusMergeLabel);
        var liveExit = _currentBlockLabel;
        EmitLabel(noLiveLabel);
        EmitBranch(statusMergeLabel);
        var noLiveExit = _currentBlockLabel;
        EmitLabel(statusMergeLabel);
        var observed = NextTemp("diagnostic_close_observed_status");
        EmitPhi(observed, "i32", [(liveStatus, liveExit), (terminal, noLiveExit)]);
        var completed = NextTemp("diagnostic_close_completed");
        EmitCompare(completed, "eq", "i32", observed, "2");
        var cancelled = NextTemp("diagnostic_close_cancelled");
        EmitCompare(cancelled, "eq", "i32", observed, "3");
        var terminalStatus = NextTemp("diagnostic_close_terminal");
        EmitAssign(terminalStatus, $"or i1 {completed}, {cancelled}");
        var active = NextTemp("diagnostic_close_active");
        EmitAssign(active, $"xor i1 {terminalStatus}, true");
        var previousBusy = NextTemp("diagnostic_close_previous_busy");
        EmitLoad(previousBusy, "i1", busySlot, 1);
        var busy = NextTemp("diagnostic_close_busy");
        EmitAssign(busy, $"or i1 {previousBusy}, {active}");
        EmitStore("i1", busy, busySlot, 1);
        var next = NextTemp("diagnostic_close_next");
        EmitBinary(next, "add", "i64", index, "1");
        EmitStore("i64", next, indexSlot, 8);
        EmitBranch(loopLabel);
        EmitLabel(doneLabel);
        var anyBusy = NextTemp("diagnostic_close_any_busy");
        EmitLoad(anyBusy, "i1", busySlot, 1);
        var busyLabel = NextLabel("diagnostic_close_busy_result");
        var successLabel = NextLabel("diagnostic_close_success");
        var mergeLabel = NextLabel("diagnostic_close_merge");
        EmitConditionalBranch(anyBusy, busyLabel, successLabel);

        EmitLabel(busyLabel);
        var resultTypes = DiagnosticResultTypes(function.ReturnType);
        var failureDefinition = _program.Types.GetStruct(resultTypes.Error);
        var kindType = failureDefinition.Fields[1].Type;
        var kindDefinition = _program.Types.GetEnum(kindType);
        var busyKind = EmitEnumValue(kindType,
            kindDefinition.Variants.First(static variant => variant.Name == "Busy"), null);
        var failure = EmitRuntimeStructAggregate(resultTypes.Error,
            [sessionValue, busyKind], "diagnostic_close_failure");
        var resultDefinition = _program.Types.GetEnum(function.ReturnType);
        var failureResult = EmitEnumValue(function.ReturnType,
            resultDefinition.Variants.First(static variant => variant.Name == "Err"), failure);
        EmitBranch(mergeLabel);
        var failureExit = _currentBlockLabel;

        EmitLabel(successLabel);
        EmitDetachAllDiagnosticRecords(records, count);
        var sessionId = LoadDiagnosticSessionField(session, 0, "i64", 8, "diagnostic_close_session_id");
        var untracked = LoadDiagnosticSessionField(session, 3, "i64", 8, "diagnostic_close_untracked");
        var summary = EmitRuntimeStructAggregate(resultTypes.Ok,
        [
            new RuntimeInt(BoundType.UInt64, sessionId),
            new RuntimeInt(BoundType.UIntSize, count),
            new RuntimeInt(BoundType.UIntSize, untracked)
        ], "diagnostic_close_summary");
        EmitCall(target: null, "void", "sollang_free", $"ptr {session}");
        var successResult = EmitEnumValue(function.ReturnType,
            resultDefinition.Variants.First(static variant => variant.Name == "Ok"), summary);
        EmitBranch(mergeLabel);
        var successExit = _currentBlockLabel;

        EmitLabel(mergeLabel);
        return EmitEnumPhi("diagnostic_close_result", function.ReturnType,
            [(failureResult, failureExit), (successResult, successExit)]);
    }

    private void EmitDetachAllDiagnosticRecords(string records, string count)
    {
        var indexSlot = NextTemp("diagnostic_detach_all_index_slot");
        EmitAlloca(indexSlot, "i64", 8);
        EmitStore("i64", "0", indexSlot, 8);
        var loopLabel = NextLabel("diagnostic_detach_all_loop");
        var inspectLabel = NextLabel("diagnostic_detach_all_inspect");
        var detachLabel = NextLabel("diagnostic_detach_all_header");
        var advanceLabel = NextLabel("diagnostic_detach_all_advance");
        var doneLabel = NextLabel("diagnostic_detach_all_done");
        EmitBranch(loopLabel);
        EmitLabel(loopLabel);
        var index = NextTemp("diagnostic_detach_all_index");
        EmitLoad(index, "i64", indexSlot, 8);
        var more = NextTemp("diagnostic_detach_all_more");
        EmitCompare(more, "ult", "i64", index, count);
        EmitConditionalBranch(more, inspectLabel, doneLabel);
        EmitLabel(inspectLabel);
        var record = NextTemp("diagnostic_detach_all_record");
        EmitAssign(record, $"getelementptr %sollang.diagnostic_record, ptr {records}, i64 {index}");
        var terminal = LoadDiagnosticRecordField(record, 3, "i32", 4, "diagnostic_detach_all_terminal");
        var frozen = NextTemp("diagnostic_detach_all_frozen");
        EmitCompare(frozen, "sge", "i32", terminal, "2");
        var frozenLabel = NextLabel("diagnostic_detach_all_frozen_status");
        var liveLabel = NextLabel("diagnostic_detach_all_live_status");
        var statusMergeLabel = NextLabel("diagnostic_detach_all_status_merge");
        EmitConditionalBranch(frozen, frozenLabel, liveLabel);
        EmitLabel(liveLabel);
        var control = LoadDiagnosticRecordField(record, 2, "ptr", 8, "diagnostic_detach_all_control");
        var statusSlot = NextTemp("diagnostic_detach_all_status_slot");
        EmitAssign(statusSlot, $"getelementptr %sollang.task_control, ptr {control}, i32 0, i32 4");
        var liveStatus = NextTemp("diagnostic_detach_all_live_status_value");
        EmitLoad(liveStatus, "i32", statusSlot, 4);
        EmitBranch(statusMergeLabel);
        var liveExit = _currentBlockLabel;
        EmitLabel(frozenLabel);
        EmitBranch(statusMergeLabel);
        var frozenExit = _currentBlockLabel;
        EmitLabel(statusMergeLabel);
        var observed = NextTemp("diagnostic_detach_all_observed_status");
        EmitPhi(observed, "i32", [(liveStatus, liveExit), (terminal, frozenExit)]);
        StoreDiagnosticRecordField(record, 3, "i32", observed, 4);
        StoreDiagnosticRecordField(record, 2, "ptr", "null", 8);
        var header = LoadDiagnosticRecordField(record, 14, "ptr", 8, "diagnostic_detach_all_header_pointer");
        var hasHeader = NextTemp("diagnostic_detach_all_has_header");
        EmitCompare(hasHeader, "ne", "ptr", header, "null");
        EmitConditionalBranch(hasHeader, detachLabel, advanceLabel);
        EmitLabel(detachLabel);
        EmitStore("ptr", "null", DiagnosticHeaderField(header, 0, "diagnostic_detach_all_session_slot"), 8);
        EmitStore("ptr", "null", DiagnosticHeaderField(header, 1, "diagnostic_detach_all_record_slot"), 8);
        StoreDiagnosticRecordField(record, 14, "ptr", "null", 8);
        EmitBranch(advanceLabel);
        EmitLabel(advanceLabel);
        var next = NextTemp("diagnostic_detach_all_next");
        EmitBinary(next, "add", "i64", index, "1");
        EmitStore("i64", next, indexSlot, 8);
        EmitBranch(loopLabel);
        EmitLabel(doneLabel);
    }

    private string LoadDiagnosticSessionPointer(RuntimeMutableStructReference reference)
    {
        var value = NextTemp("diagnostic_session_value");
        EmitLoad(value, LlvmStructType(reference.Type), reference.PointerAddress, 8);
        return ExtractDiagnosticSessionPointer(reference.Type, value);
    }

    private string ExtractDiagnosticSessionPointer(BoundType sessionType, string value)
    {
        var token = NextTemp("diagnostic_session_token");
        EmitAssign(token, $"extractvalue {LlvmStructType(sessionType)} {value}, 0");
        var pointer = NextTemp("diagnostic_session_pointer");
        EmitAssign(pointer, $"inttoptr i64 {token} to ptr");
        return pointer;
    }

    private string EmitAttachDiagnosticRecord(string session, string header, string control, string parentTaskId)
    {
        var capacity = LoadDiagnosticSessionField(session, 1, "i64", 8, "diagnostic_capacity");
        var count = LoadDiagnosticSessionField(session, 2, "i64", 8, "diagnostic_count");
        var available = NextTemp("diagnostic_record_available");
        EmitCompare(available, "ult", "i64", count, capacity);
        var attachLabel = NextLabel("diagnostic_record_attach");
        var fullLabel = NextLabel("diagnostic_record_full");
        var mergeLabel = NextLabel("diagnostic_record_attach_merge");
        EmitConditionalBranch(available, attachLabel, fullLabel);

        EmitLabel(fullLabel);
        EmitStore("ptr", session, DiagnosticHeaderField(header, 0, "diagnostic_capacity_session"), 8);
        var untracked = LoadDiagnosticSessionField(session, 3, "i64", 8, "diagnostic_untracked_count");
        var incrementedUntracked = NextTemp("diagnostic_untracked_next");
        EmitBinary(incrementedUntracked, "add", "i64", untracked, "1");
        StoreDiagnosticSessionField(session, 3, "i64", incrementedUntracked, 8);
        EmitBranch(mergeLabel);
        var fullExit = _currentBlockLabel;

        EmitLabel(attachLabel);
        var records = LoadDiagnosticSessionField(session, 4, "ptr", 8, "diagnostic_records");
        var record = NextTemp("diagnostic_record");
        EmitAssign(record, $"getelementptr %sollang.diagnostic_record, ptr {records}, i64 {count}");
        var taskId = NextTemp("diagnostic_task_id");
        EmitBinary(taskId, "add", "i64", count, "1");
        StoreDiagnosticRecordField(record, 0, "i64", taskId, 8);
        StoreDiagnosticRecordField(record, 1, "i64", parentTaskId, 8);
        StoreDiagnosticRecordField(record, 2, "ptr", control, 8);
        StoreDiagnosticRecordField(record, 3, "i32", "-1", 4);
        StoreDiagnosticRecordField(record, 4, "i32", "0", 4);
        foreach (var field in new[] { 5, 6, 8, 10, 11, 12, 13 })
            StoreDiagnosticRecordField(record, field, "i64", "0", 8);
        StoreDiagnosticRecordField(record, 7, "ptr", "null", 8);
        StoreDiagnosticRecordField(record, 9, "ptr", "null", 8);
        StoreDiagnosticRecordField(record, 14, "ptr", header, 8);
        EmitStore("ptr", session, DiagnosticHeaderField(header, 0, "diagnostic_header_session"), 8);
        EmitStore("ptr", record, DiagnosticHeaderField(header, 1, "diagnostic_header_record"), 8);
        EmitStore("i64", taskId, DiagnosticHeaderField(header, 2, "diagnostic_header_task_id"), 8);
        EmitStore("i64", parentTaskId, DiagnosticHeaderField(header, 3, "diagnostic_header_parent_id"), 8);
        var nextCount = NextTemp("diagnostic_count_next");
        EmitBinary(nextCount, "add", "i64", count, "1");
        StoreDiagnosticSessionField(session, 2, "i64", nextCount, 8);
        EmitBranch(mergeLabel);
        var attachExit = _currentBlockLabel;

        EmitLabel(mergeLabel);
        var attached = NextTemp("diagnostic_record_attached");
        EmitPhi(attached, "i1", [("false", fullExit), ("true", attachExit)]);
        return attached;
    }

    private void EmitAttachInheritedDiagnosticRecord(string header, string control)
    {
        var sessionSlot = DiagnosticHeaderField(header, 0, "diagnostic_inherited_session_slot");
        var session = NextTemp("diagnostic_inherited_session");
        EmitLoad(session, "ptr", sessionSlot, 8);
        var hasSession = NextTemp("diagnostic_has_inherited_session");
        EmitCompare(hasSession, "ne", "ptr", session, "null");
        var attachLabel = NextLabel("diagnostic_inherited_attach");
        var doneLabel = NextLabel("diagnostic_inherited_done");
        EmitConditionalBranch(hasSession, attachLabel, doneLabel);
        EmitLabel(attachLabel);
        var parentTaskIdSlot = DiagnosticHeaderField(header, 3, "diagnostic_inherited_parent_id_slot");
        var parentTaskId = NextTemp("diagnostic_inherited_parent_id");
        EmitLoad(parentTaskId, "i64", parentTaskIdSlot, 8);
        _ = EmitAttachDiagnosticRecord(session, header, control, parentTaskId);
        EmitBranch(doneLabel);
        EmitLabel(doneLabel);
    }

    private void EmitMarkCurrentDiagnosticTerminal(int status)
    {
        if (!_usesAsyncDiagnostics)
            return;
        EmitMarkDiagnosticHeaderTerminal(_currentAsyncDiagnosticHeader, status);
    }

    private void EmitMarkTaskDiagnosticTerminal(RuntimeTask task, int status)
    {
        if (!_usesAsyncDiagnostics || DiagnosticHeaderForTask(task) is not { } header)
            return;
        EmitMarkDiagnosticHeaderTerminal(header, status);
    }

    private void EmitMarkDiagnosticHeaderTerminal(string header, int status)
    {
        var recordSlot = DiagnosticHeaderField(
            header, 1, "diagnostic_terminal_record_slot");
        var record = NextTemp("diagnostic_terminal_record");
        EmitLoad(record, "ptr", recordSlot, 8);
        var tracked = NextTemp("diagnostic_terminal_tracked");
        EmitCompare(tracked, "ne", "ptr", record, "null");
        var markLabel = NextLabel("diagnostic_terminal_mark");
        var doneLabel = NextLabel("diagnostic_terminal_done");
        EmitConditionalBranch(tracked, markLabel, doneLabel);
        EmitLabel(markLabel);
        StoreDiagnosticRecordField(record, 2, "ptr", "null", 8);
        StoreDiagnosticRecordField(record, 14, "ptr", header, 8);
        StoreDiagnosticRecordField(record, 3, "i32", status.ToString(CultureInfo.InvariantCulture), 4);
        StoreDiagnosticRecordField(record, 4, "i32", "0", 4);
        StoreDiagnosticRecordField(record, 5, "i64", "0", 8);
        StoreDiagnosticRecordField(record, 6, "i64", "0", 8);
        StoreDiagnosticRecordField(record, 7, "ptr", "null", 8);
        StoreDiagnosticRecordField(record, 8, "i64", "0", 8);
        StoreDiagnosticRecordField(record, 9, "ptr", "null", 8);
        foreach (var field in new[] { 10, 11, 12, 13 })
            StoreDiagnosticRecordField(record, field, "i64", "0", 8);
        EmitBranch(doneLabel);
        EmitLabel(doneLabel);
    }

    private void EmitDetachDiagnosticHeader(string header)
    {
        if (!_usesAsyncDiagnostics)
            return;
        var recordSlot = DiagnosticHeaderField(header, 1, "diagnostic_detach_record_slot");
        var record = NextTemp("diagnostic_detach_record");
        EmitLoad(record, "ptr", recordSlot, 8);
        var attached = NextTemp("diagnostic_detach_attached");
        EmitCompare(attached, "ne", "ptr", record, "null");
        var detachLabel = NextLabel("diagnostic_detach");
        var doneLabel = NextLabel("diagnostic_detach_done");
        EmitConditionalBranch(attached, detachLabel, doneLabel);
        EmitLabel(detachLabel);
        StoreDiagnosticRecordField(record, 2, "ptr", "null", 8);
        StoreDiagnosticRecordField(record, 14, "ptr", "null", 8);
        EmitStore("ptr", "null", DiagnosticHeaderField(header, 0, "diagnostic_detach_session_slot"), 8);
        EmitStore("ptr", "null", recordSlot, 8);
        EmitBranch(doneLabel);
        EmitLabel(doneLabel);
    }

    private void EmitRecordCurrentDiagnosticSuspension(
        AsyncCfgSuspendPoint point,
        RuntimeTask? child,
        Expression? taskExpression) =>
        EmitRecordCurrentDiagnosticSuspension(point.Site, point.State, child, taskExpression);

    private void EmitRecordCurrentDiagnosticSuspension(
        object site,
        int resumeState,
        RuntimeTask? child,
        Expression? taskExpression)
    {
        if (!_usesAsyncDiagnostics)
            return;
        if (!TryResolveAsyncSuspensionLocation(site, resumeState, out var location))
        {
            _ = TryGetSuspensionCoordinates(site, out var requestedByte, out var requestedLine, out var requestedColumn);
            var indexed = string.Join(",", _program.AsyncSuspensionLocations.Values
                .Where(candidate => string.Equals(
                    candidate.Function.Name, _currentFunction?.Name, StringComparison.Ordinal))
                .Select(candidate => $"{candidate.Function.ModuleName}:{candidate.ByteOffset}:{candidate.Line}:{candidate.Column}"));
            throw new SollangException(
                $"async suspension in '{_currentFunction?.ModuleName}.{_currentFunction?.Name ?? "main"}' has no source locator "
                + $"(requested: {requestedByte}:{requestedLine}:{requestedColumn}; indexed coordinates: {indexed})");
        }

        var childHeader = child is null ? null : DiagnosticHeaderForTask(child);
        var childTaskId = "0";
        if (childHeader is not null)
        {
            childTaskId = NextTemp("diagnostic_awaited_task_id");
            EmitLoad(childTaskId, "i64", DiagnosticHeaderField(
                childHeader, 2, "diagnostic_awaited_task_id_slot"), 8);
        }

        var record = NextTemp("diagnostic_suspension_record");
        EmitLoad(record, "ptr", DiagnosticHeaderField(
            _currentAsyncDiagnosticHeader, 1, "diagnostic_suspension_record_slot"), 8);
        var tracked = NextTemp("diagnostic_suspension_tracked");
        EmitCompare(tracked, "ne", "ptr", record, "null");
        var markLabel = NextLabel("diagnostic_suspension_mark");
        var doneLabel = NextLabel("diagnostic_suspension_done");
        EmitConditionalBranch(tracked, markLabel, doneLabel);
        EmitLabel(markLabel);
        EmitStoreDiagnosticSuspensionLocation(record, resumeState, childTaskId, "0", location);
        EmitBranch(doneLabel);
        EmitLabel(doneLabel);

        if (child is null
            || childHeader is null
            || taskExpression is not FlowExpression { Targets.Count: > 0 } flow
            || flow.Targets[^1] is not { Path.Count: 1 } producer
            || !string.Equals(producer.Path[0], "sleep", StringComparison.Ordinal))
        {
            return;
        }

        var childRecord = NextTemp("diagnostic_child_suspension_record");
        EmitLoad(childRecord, "ptr", DiagnosticHeaderField(
            childHeader, 1, "diagnostic_child_suspension_record_slot"), 8);
        var childTracked = NextTemp("diagnostic_child_suspension_tracked");
        EmitCompare(childTracked, "ne", "ptr", childRecord, "null");
        var childMarkLabel = NextLabel("diagnostic_child_suspension_mark");
        var childDoneLabel = NextLabel("diagnostic_child_suspension_done");
        EmitConditionalBranch(childTracked, childMarkLabel, childDoneLabel);
        EmitLabel(childMarkLabel);
        var deadlineSlot = NextTemp("diagnostic_child_deadline_slot");
        EmitAssign(deadlineSlot,
            $"getelementptr %sollang.task_control, ptr {child.HandleName}, i32 0, i32 8");
        var deadline = NextTemp("diagnostic_child_deadline");
        EmitLoad(deadline, "i64", deadlineSlot, 8);
        var producerLocation = new BoundAsyncSuspensionLocation(
            location.Function,
            producer.ByteOffset,
            producer.Line,
            producer.Column);
        EmitStoreDiagnosticSuspensionLocation(
            childRecord, resumeState, "0", deadline, producerLocation);
        EmitBranch(childDoneLabel);
        EmitLabel(childDoneLabel);
    }

    private bool TryResolveAsyncSuspensionLocation(
        object site,
        int resumeState,
        out BoundAsyncSuspensionLocation location)
    {
        if (_program.AsyncSuspensionLocations.TryGetValue(site, out location!))
            return true;
        if (_currentFunction is null)
        {
            location = null!;
            return false;
        }

        var functionLocations = _program.AsyncSuspensionLocations.Values
            .Where(candidate =>
                string.Equals(candidate.Function.ModuleName, _currentFunction.ModuleName, StringComparison.Ordinal)
                && string.Equals(candidate.Function.Name, _currentFunction.Name, StringComparison.Ordinal))
            .Distinct()
            .OrderBy(static candidate => candidate.ByteOffset)
            .ToArray();
        if (TryGetSuspensionCoordinates(site, out var byteOffset, out var line, out var column))
        {
            var exact = functionLocations.Where(candidate =>
                    candidate.ByteOffset == byteOffset
                    && candidate.Line == line
                    && candidate.Column == column)
                .ToArray();
            if (exact.Length == 1)
            {
                location = exact[0];
                return true;
            }
        }
        if (resumeState < 1 || resumeState > functionLocations.Length)
        {
            location = null!;
            return false;
        }
        location = functionLocations[resumeState - 1];
        return true;
    }

    private static bool TryGetSuspensionCoordinates(
        object site,
        out int byteOffset,
        out int line,
        out int column)
    {
        Expression? expression = site switch
        {
            BindingStatement binding => binding.Value,
            ExpressionStatement statement => statement.Expression,
            Expression value => value,
            _ => null
        };
        if (expression is NameExpression { Name: "yield" } yield)
        {
            byteOffset = yield.ByteOffset;
            line = yield.Line;
            column = yield.Column;
            return byteOffset >= 0;
        }
        if (expression is FlowExpression { Targets.Count: > 0 } flow
            && flow.Targets[^1] is { Path.Count: 1 } target
            && string.Equals(target.Path[0], "await", StringComparison.Ordinal)
            && target.Arguments.Count == 0)
        {
            byteOffset = target.ByteOffset;
            line = target.Line;
            column = target.Column;
            return byteOffset >= 0;
        }

        byteOffset = -1;
        line = 0;
        column = 0;
        return false;
    }

    private string? DiagnosticHeaderForTask(RuntimeTask task)
    {
        if (task.DiagnosticHeaderName is not null)
            return task.DiagnosticHeaderName;
        return !_usesAsyncDiagnostics
            ? null
            : AsyncContextField(
                task.ContextName,
                task.InputType,
                task.ResultType,
                10,
                "diagnostic_task_header");
    }

    private void EmitStoreDiagnosticSuspensionLocation(
        string record,
        int resumeState,
        string awaitedTaskId,
        string deadline,
        BoundAsyncSuspensionLocation location)
    {
        var module = AddGlobalString(location.Function.ModuleName);
        var qualifiedName = location.Function.Name;
        var separator = qualifiedName.LastIndexOf('.', StringComparison.Ordinal);
        var symbol = AddGlobalString(separator < 0 ? qualifiedName : qualifiedName[(separator + 1)..]);
        StoreDiagnosticRecordField(record, 4, "i32", resumeState.ToString(CultureInfo.InvariantCulture), 4);
        StoreDiagnosticRecordField(record, 5, "i64", awaitedTaskId, 8);
        StoreDiagnosticRecordField(record, 6, "i64", deadline, 8);
        StoreDiagnosticRecordField(record, 7, "ptr", module.Name, 8);
        StoreDiagnosticRecordField(record, 8, "i64", module.Length.ToString(CultureInfo.InvariantCulture), 8);
        StoreDiagnosticRecordField(record, 9, "ptr", symbol.Name, 8);
        StoreDiagnosticRecordField(record, 10, "i64", symbol.Length.ToString(CultureInfo.InvariantCulture), 8);
        StoreDiagnosticRecordField(record, 11, "i64", location.ByteOffset.ToString(CultureInfo.InvariantCulture), 8);
        StoreDiagnosticRecordField(record, 12, "i64", location.Line.ToString(CultureInfo.InvariantCulture), 8);
        StoreDiagnosticRecordField(record, 13, "i64", location.Column.ToString(CultureInfo.InvariantCulture), 8);
    }

    private string DiagnosticHeaderField(string header, int field, string prefix)
    {
        var slot = NextTemp(prefix);
        EmitAssign(slot, $"getelementptr {{ ptr, ptr, i64, i64 }}, ptr {header}, i32 0, i32 {field}");
        return slot;
    }

    private string LoadDiagnosticSessionField(
        string session, int field, string type, int alignment, string prefix)
    {
        var slot = NextTemp(prefix + "_slot");
        EmitAssign(slot, $"getelementptr %sollang.diagnostic_session, ptr {session}, i32 0, i32 {field}");
        var value = NextTemp(prefix);
        EmitLoad(value, type, slot, alignment);
        return value;
    }

    private void StoreDiagnosticSessionField(
        string session, int field, string type, string value, int alignment)
    {
        var slot = NextTemp("diagnostic_session_field");
        EmitAssign(slot, $"getelementptr %sollang.diagnostic_session, ptr {session}, i32 0, i32 {field}");
        EmitStore(type, value, slot, alignment);
    }

    private void StoreDiagnosticRecordField(
        string record, int field, string type, string value, int alignment)
    {
        var slot = NextTemp("diagnostic_record_field");
        EmitAssign(slot, $"getelementptr %sollang.diagnostic_record, ptr {record}, i32 0, i32 {field}");
        EmitStore(type, value, slot, alignment);
    }

    private string LoadDiagnosticRecordField(
        string record, int field, string type, int alignment, string prefix)
    {
        var slot = NextTemp(prefix + "_slot");
        EmitAssign(slot, $"getelementptr %sollang.diagnostic_record, ptr {record}, i32 0, i32 {field}");
        var value = NextTemp(prefix);
        EmitLoad(value, type, slot, alignment);
        return value;
    }

    private (BoundType Ok, BoundType Error) DiagnosticResultTypes(BoundType type)
    {
        if (!_program.Types.TryGetResultTypes(type, out var resultTypes))
            throw new SollangException("async diagnostic intrinsic has a non-Result return type");
        return resultTypes;
    }
}
