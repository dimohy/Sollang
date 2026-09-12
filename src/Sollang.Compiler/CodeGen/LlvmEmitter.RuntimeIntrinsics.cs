using System.Globalization;
using System.Text;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Semantics;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private RuntimeValue EmitFlowSource(Expression source)
    {
        return EmitExpression(source);
    }

    private string EmitPrintFlowSource(Expression expression, string ok)
    {
        return EmitPrintFlowSource(expression, ok, standardError: false);
    }

    private string EmitPrintFlowSource(Expression expression, string ok, bool standardError)
    {
        if (expression is StringExpression str)
        {
            return EmitPrintArgument(str, ok, standardError);
        }

        var value = EmitFlowSource(expression);
        return EmitWriteValue(value, ok, standardError);
    }

    private RuntimeInt EmitReadIntPrompt(RuntimeValue prompt)
    {
        EnsureRuntimeType(prompt, BoundType.Text, "sys.io.readInt");
        _mainOk = EmitWriteValue(prompt, _mainOk);
        return EmitReadIntAfterPrompt();
    }

    private RuntimeInt EmitReadIntPromptExpression(Expression prompt)
    {
        _mainOk = EmitPrintArgument(prompt, _mainOk);
        return EmitReadIntAfterPrompt();
    }

    private RuntimeInt EmitReadIntAfterPrompt()
    {
        var result = NextTemp("read_int");
        EmitCall(result, "%sollang.read_int_result", "sollang_read_i64", "ptr %stdin, ptr %read");

        var value = NextTemp("read_value");
        EmitAssign(value, $"extractvalue %sollang.read_int_result {result}, 0");

        var ok = NextTemp("read_ok");
        EmitAssign(ok, $"extractvalue %sollang.read_int_result {result}, 1");

        _mainOk = CombineWriteOk(ok, _mainOk);
        EmitReturnIfReadFailed(ok);
        var narrowed = NextTemp("read_int32");
        EmitAssign(narrowed, $"trunc i64 {value} to i32");
        return new RuntimeInt(narrowed);
    }

    private RuntimeInt EmitRuntimeNowMillisIntrinsic(string path)
    {
        _ = path;
        var value = NextTemp("now_ms");
        EmitCall(value, "i64", "sollang_now_millis", "");
        return new RuntimeInt(BoundType.Int64, value);
    }

    private RuntimeInt EmitRuntimeUtcNowMillisIntrinsic(string path)
    {
        _ = path;
        var value = NextTemp("utc_now_ms");
        EmitCall(value, "i64", "sollang_utc_now_millis", "");
        return new RuntimeInt(BoundType.Int64, value);
    }

    private RuntimeInt EmitRuntimeMonotonicSuspendPolicyIntrinsic(string path)
    {
        _ = path;
        var value = _platform switch
        {
            WindowsLlvmRuntimePlatform => "0",
            LinuxLlvmRuntimePlatform => "1",
            _ => "2"
        };
        return new RuntimeInt(BoundType.UInt8, value);
    }

    private RuntimeProducerStream EmitRuntimeRangeStream(
        BoundFunction function,
        RuntimeValue argument,
        string path)
    {
        if (argument is not RuntimeStruct { Type: BoundType.Range } range
            || !_program.Types.TryGetStreamValue(function.ReturnType, out var elementType)
            || elementType != BoundType.Int)
        {
            throw new SollangException($"{path} expects Range and returns Stream<Int>");
        }
        if (!_platform.SupportsHeapAllocation)
        {
            throw new SollangException(
                $"{path} crosses a runtime Stream boundary and requires heap allocation on this target");
        }

        var context = NextTemp("range_stream_context");
        EmitCall(context, "ptr", "sollang_alloc", "i64 12");
        var allocated = NextTemp("range_stream_allocated");
        EmitCompare(allocated, "ne", "ptr", context, "null");
        EmitTrapUnless(allocated, "range_stream_allocation");

        var llvmRangeType = LlvmStructType(BoundType.Range);
        var start = NextTemp("range_stream_start");
        EmitAssign(start, $"extractvalue {llvmRangeType} {range.ValueName}, 0");
        var end = NextTemp("range_stream_end");
        EmitAssign(end, $"extractvalue {llvmRangeType} {range.ValueName}, 1");
        EmitStore("i32", start, context, 4);
        var endAddress = NextTemp("range_stream_end_address");
        EmitAssign(endAddress, $"getelementptr i8, ptr {context}, i64 4");
        EmitStore("i32", end, endAddress, 4);
        var doneAddress = NextTemp("range_stream_done_address");
        EmitAssign(doneAddress, $"getelementptr i8, ptr {context}, i64 8");
        EmitStore("i1", "false", doneAddress, 1);

        return new RuntimeProducerStream(
            function.ReturnType,
            BoundType.Int,
            context,
            "@sollang_range_stream_next",
            "@sollang_stream_heap_drop",
            IsEvent: false);
    }

    private RuntimeProducerStream EmitRuntimeMouseEvents(
        BoundFunction function,
        RuntimeValue sourceValue,
        string path)
    {
        if (!_program.Types.TryGetEventStreamValue(function.ReturnType, out var elementType)
            || !_program.Types.TryResolve("sys.input.mouse.Event", out var mouseEventType)
            || elementType != mouseEventType)
        {
            throw new SollangException($"{path} must return EventStream<sys.input.mouse.Event>");
        }
        if (sourceValue is not RuntimeStruct source
            || !_program.Types.IsStruct(source.Type)
            || _program.Types.GetStruct(source.Type) is not { Name: "sys.input.mouse.Source" } sourceDefinition)
        {
            throw new SollangException($"{path} expects sys.input.mouse.Source");
        }

        var capacityField = sourceDefinition.GetField("capacity");
        var overflowField = sourceDefinition.GetField("overflow");
        var capacity = NextTemp("mouse_event_capacity");
        EmitAssign(
            capacity,
            $"extractvalue {LlvmStructType(source.Type)} {source.ValueName}, {capacityField.Index}");
        var overflow = NextTemp("mouse_event_overflow_value");
        EmitAssign(
            overflow,
            $"extractvalue {LlvmStructType(source.Type)} {source.ValueName}, {overflowField.Index}");

        var overflowTag = NextTemp("mouse_event_overflow");
        EmitAssign(
            overflowTag,
            $"extractvalue {LlvmEnumType(overflowField.Type)} {overflow}, 0");
        var context = NextTemp("mouse_event_context");
        EmitCall(
            context,
            "ptr",
            "sollang_mouse_event_stream_create",
            $"i32 {capacity}, i32 {overflowTag}");
        var created = NextTemp("mouse_event_stream_created");
        EmitCompare(created, "ne", "ptr", context, "null");
        EmitTrapUnless(created, "mouse_event_stream_create");
        return new RuntimeProducerStream(
            function.ReturnType,
            elementType,
            context,
            "@sollang_mouse_event_stream_next",
            "@sollang_mouse_event_stream_drop",
            IsEvent: true);
    }

    private RuntimeInt EmitRuntimeParallelWorkersIntrinsic(string path)
    {
        _ = path;
        var value = NextTemp("parallel_workers");
        EmitCall(value, "i32", "sollang_compute_workers", "");
        return new RuntimeInt(value);
    }

    private RuntimeInt EmitRuntimeLimitParallelWorkersIntrinsic(RuntimeValue argument, string path)
    {
        if (argument is not RuntimeInt integer || integer.Type != BoundType.Int)
        {
            throw new SollangException($"{path} expects Int");
        }
        var value = NextTemp("parallel_worker_limit");
        EmitCall(value, "i32", "sollang_compute_limit_workers", $"i32 {integer.ValueName}");
        return new RuntimeInt(value);
    }

    private RuntimeInt EmitRuntimeParallelPeakWorkersIntrinsic(string path)
    {
        _ = path;
        var value = NextTemp("parallel_peak_workers");
        EmitCall(value, "i32", "sollang_compute_peak_workers", "");
        return new RuntimeInt(value);
    }

    private RuntimeTask EmitRuntimeSleepIntrinsic(
        BoundFunction function,
        RuntimeValue argument,
        string path)
    {
        EnsureRuntimeType(argument, function.InputType!.Value, path);
        if (argument is not RuntimeStruct duration)
        {
            throw new SollangException($"{path} expects Duration");
        }

        var millis = NextTemp("sleep_millis");
        EmitAssign(
            millis,
            $"extractvalue {LlvmStructType(duration.Type)} {duration.ValueName}, 0");
        var positive = NextTemp("sleep_positive");
        EmitCompare(positive, "sgt", "i64", millis, "0");
        var normalized = NextTemp("sleep_normalized");
        EmitAssign(normalized, $"select i1 {positive}, i64 {millis}, i64 0");
        var now = NextTemp("sleep_now");
        EmitCall(now, "i64", "sollang_now_millis", "");
        var maximumRemaining = NextTemp("sleep_maximum_remaining");
        EmitAssign(maximumRemaining, $"sub i64 9223372036854775807, {now}");
        var tooLarge = NextTemp("sleep_too_large");
        EmitCompare(tooLarge, "sgt", "i64", normalized, maximumRemaining);
        var finiteDeadline = NextTemp("sleep_finite_deadline");
        EmitAssign(finiteDeadline, $"add i64 {now}, {normalized}");
        var deadline = NextTemp("sleep_deadline");
        EmitAssign(
            deadline,
            $"select i1 {tooLarge}, i64 9223372036854775807, i64 {finiteDeadline}");

        var context = NextTemp("sleep_context");
        EmitCall(context, "ptr", "sollang_alloc", $"i64 {AsyncContextSize(null, BoundType.Unit)}");
        var allocated = NextTemp("sleep_context_allocated");
        EmitCompare(allocated, "ne", "ptr", context, "null");
        var initializeLabel = NextLabel("sleep_initialize");
        var allocationFailedLabel = NextLabel("sleep_allocation_failed");
        EmitConditionalBranch(allocated, initializeLabel, allocationFailedLabel);
        EmitLabel(allocationFailedLabel);
        EmitTrap();
        EmitLabel(initializeLabel);

        var resultAddress = AsyncContextField(
            context,
            null,
            BoundType.Unit,
            6,
            "sleep_result_address");
        EmitStore("i8", "0", resultAddress, 1);
        var handle = NextTemp("sleep_handle");
        EmitCall(
            handle,
            "ptr",
            "sollang_task_start",
            $"ptr @sollang_sleep_worker, ptr @sollang_free, ptr @sollang_sleep_cancel, ptr {context}");
        var started = NextTemp("sleep_started");
        EmitCompare(started, "ne", "ptr", handle, "null");
        var readyLabel = NextLabel("sleep_ready");
        var startFailedLabel = NextLabel("sleep_start_failed");
        EmitConditionalBranch(started, readyLabel, startFailedLabel);
        EmitLabel(startFailedLabel);
        EmitCall(target: null, "void", "sollang_free", $"ptr {context}");
        EmitTrap();
        EmitLabel(readyLabel);
        var deadlineAddress = NextTemp("sleep_deadline_address");
        EmitAssign(
            deadlineAddress,
            $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 8");
        EmitStore("i64", deadline, deadlineAddress, 8);

        return new RuntimeTask(
            _program.Types.GetOrAddTask(BoundType.Unit),
            null,
            BoundType.Unit,
            handle,
            context);
    }

    private RuntimeTask EmitRuntimeReadScalarAsync(BoundFunction function)
    {
        return EmitRuntimeReadScalarAsync(function, file: null, offsetExpression: null);
    }

    private RuntimeTask EmitRuntimeReadScalarAsync(
        BoundFunction function,
        RuntimeStruct? file,
        Expression? offsetExpression)
    {
        if (function.SpecializedType is not { } scalarType
            || (scalarType != BoundType.Bool && !IsNumericType(scalarType) && scalarType != BoundType.CodePoint)
            || !_program.Types.TryGetResultTypes(function.ReturnType, out var resultTypes)
            || !_program.Types.TryGetOptionValue(resultTypes.Ok, out var optionValue)
            || optionValue != scalarType
            || resultTypes.Error != BoundType.Text)
        {
            throw new SollangException($"{function.Name} has an invalid asynchronous scalar specialization");
        }

        var contextSize = AsyncContextSize(null, function.ReturnType);
        var context = NextTemp("file_async_context");
        EmitCall(context, "ptr", "sollang_alloc", $"i64 {contextSize}");
        var allocated = NextTemp("file_async_context_allocated");
        EmitCompare(allocated, "ne", "ptr", context, "null");
        var initializeLabel = NextLabel("file_async_initialize");
        var allocationFailedLabel = NextLabel("file_async_allocation_failed");
        EmitConditionalBranch(allocated, initializeLabel, allocationFailedLabel);
        EmitLabel(allocationFailedLabel);
        EmitTrap();
        EmitLabel(initializeLabel);

        var handle = NextTemp("file_async_handle");
        EmitCall(
            handle,
            "ptr",
            "sollang_task_start",
            $"ptr @sollang_file_operation_task_worker, ptr @sollang_free, " +
            $"ptr @sollang_file_operation_task_cancel, ptr {context}");
        var started = NextTemp("file_async_started");
        EmitCompare(started, "ne", "ptr", handle, "null");
        var readyLabel = NextLabel("file_async_ready");
        var startFailedLabel = NextLabel("file_async_start_failed");
        EmitConditionalBranch(started, readyLabel, startFailedLabel);
        EmitLabel(startFailedLabel);
        EmitCall(target: null, "void", "sollang_free", $"ptr {context}");
        EmitTrap();
        EmitLabel(readyLabel);

        var sizeAddress = NextTemp("file_async_size_address");
        EmitAssign(
            sizeAddress,
            $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 11");
        EmitStore(
            "i32",
            RuntimeScalarByteSize(scalarType).ToString(CultureInfo.InvariantCulture),
            sizeAddress,
            4);

        if (file is not null)
        {
            var sourceHandle = ExtractOwnedFileHandle(file);
            var ownedHandle = NextTemp("file_async_owned_handle");
            EmitCall(
                ownedHandle,
                "i64",
                "sollang_platform_duplicate_owned_file",
                $"i64 {sourceHandle}");
            var handleAddress = NextTemp("file_async_owned_handle_address");
            EmitAssign(
                handleAddress,
                $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 17");
            EmitStore("i64", ownedHandle, handleAddress, 8);
            var offset = EmitMapInteger(
                offsetExpression!,
                BoundType.UInt64,
                "file_async_offset");
            var offsetAddress = NextTemp("file_async_offset_address");
            EmitAssign(
                offsetAddress,
                $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 18");
            EmitStore("i64", offset, offsetAddress, 8);
            var explicitAddress = NextTemp("file_async_explicit_address");
            EmitAssign(
                explicitAddress,
                $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 19");
            EmitStore("i32", "1", explicitAddress, 4);
        }

        return new RuntimeTask(
            _program.Types.GetOrAddTask(function.ReturnType),
            null,
            function.ReturnType,
            handle,
            context,
            function);
    }

    private RuntimeTask EmitRuntimeWriteScalarAtAsync(
        BoundFunction function,
        RuntimeStruct writer,
        Expression valueExpression,
        Expression offsetExpression)
    {
        if (function.SpecializedType is not { } scalarType
            || (scalarType != BoundType.Bool
                && !IsNumericType(scalarType)
                && scalarType != BoundType.CodePoint)
            || !_program.Types.TryGetResultTypes(function.ReturnType, out var resultTypes)
            || resultTypes.Ok != BoundType.Unit
            || resultTypes.Error != BoundType.Text)
        {
            throw new SollangException($"{function.Name} has an invalid asynchronous scalar specialization");
        }

        RuntimeValue value = valueExpression is NumberExpression literal && IsIntegerType(scalarType)
            ? new RuntimeInt(scalarType, literal.Text)
            : EmitExpression(valueExpression);
        EnsureRuntimeType(value, scalarType, function.Name);
        var materialized = MaterializeAggregateValue(value);

        var contextSize = AsyncContextSize(null, function.ReturnType);
        var context = NextTemp("file_async_write_context");
        EmitCall(context, "ptr", "sollang_alloc", $"i64 {contextSize}");
        var allocated = NextTemp("file_async_write_context_allocated");
        EmitCompare(allocated, "ne", "ptr", context, "null");
        var initializeLabel = NextLabel("file_async_write_initialize");
        var allocationFailedLabel = NextLabel("file_async_write_allocation_failed");
        EmitConditionalBranch(allocated, initializeLabel, allocationFailedLabel);
        EmitLabel(allocationFailedLabel);
        EmitTrap();
        EmitLabel(initializeLabel);

        var handle = NextTemp("file_async_write_handle");
        EmitCall(
            handle,
            "ptr",
            "sollang_task_start",
            $"ptr @sollang_file_operation_task_worker, ptr @sollang_free, " +
            $"ptr @sollang_file_operation_task_cancel, ptr {context}");
        var started = NextTemp("file_async_write_started");
        EmitCompare(started, "ne", "ptr", handle, "null");
        var readyLabel = NextLabel("file_async_write_ready");
        var startFailedLabel = NextLabel("file_async_write_start_failed");
        EmitConditionalBranch(started, readyLabel, startFailedLabel);
        EmitLabel(startFailedLabel);
        EmitCall(target: null, "void", "sollang_free", $"ptr {context}");
        EmitTrap();
        EmitLabel(readyLabel);

        var byteSize = RuntimeScalarByteSize(scalarType);
        var sizeAddress = NextTemp("file_async_write_size_address");
        EmitAssign(sizeAddress, $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 11");
        EmitStore("i32", byteSize.ToString(CultureInfo.InvariantCulture), sizeAddress, 4);
        var dataAddress = NextTemp("file_async_write_data_address");
        EmitAssign(dataAddress, $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 13");
        EmitStore(materialized.TypeName, materialized.ValueName, dataAddress, RuntimeAlignment(scalarType));

        var sourceHandle = ExtractOwnedFileHandle(writer, "sys.file.FileWriter");
        var ownedHandle = NextTemp("file_async_write_owned_handle");
        EmitCall(
            ownedHandle,
            "i64",
            "sollang_platform_duplicate_owned_file",
            $"i64 {sourceHandle}");
        var handleAddress = NextTemp("file_async_write_owned_handle_address");
        EmitAssign(handleAddress, $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 17");
        EmitStore("i64", ownedHandle, handleAddress, 8);
        var offset = EmitMapInteger(offsetExpression, BoundType.UInt64, "file_async_write_offset");
        var offsetAddress = NextTemp("file_async_write_offset_address");
        EmitAssign(offsetAddress, $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 18");
        EmitStore("i64", offset, offsetAddress, 8);
        var explicitAddress = NextTemp("file_async_write_explicit_address");
        EmitAssign(explicitAddress, $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 19");
        EmitStore("i32", "1", explicitAddress, 4);
        var operationAddress = NextTemp("file_async_write_operation_address");
        EmitAssign(operationAddress, $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 20");
        EmitStore("i32", "1", operationAddress, 4);

        return new RuntimeTask(
            _program.Types.GetOrAddTask(function.ReturnType),
            null,
            function.ReturnType,
            handle,
            context,
            function);
    }

    private RuntimeTask EmitRuntimeSyncFileAsync(
        BoundFunction function,
        RuntimeStruct writer)
    {
        if (!_program.Types.TryGetResultTypes(function.ReturnType, out var resultTypes)
            || resultTypes.Ok != BoundType.Unit
            || resultTypes.Error != BoundType.Text)
        {
            throw new SollangException($"{function.Name} has an invalid asynchronous sync result");
        }

        var contextSize = AsyncContextSize(null, function.ReturnType);
        var context = NextTemp("file_async_sync_context");
        EmitCall(context, "ptr", "sollang_alloc", $"i64 {contextSize}");
        var allocated = NextTemp("file_async_sync_context_allocated");
        EmitCompare(allocated, "ne", "ptr", context, "null");
        var initializeLabel = NextLabel("file_async_sync_initialize");
        var allocationFailedLabel = NextLabel("file_async_sync_allocation_failed");
        EmitConditionalBranch(allocated, initializeLabel, allocationFailedLabel);
        EmitLabel(allocationFailedLabel);
        EmitTrap();
        EmitLabel(initializeLabel);

        var handle = NextTemp("file_async_sync_handle");
        EmitCall(
            handle,
            "ptr",
            "sollang_task_start",
            $"ptr @sollang_file_operation_task_worker, ptr @sollang_free, " +
            $"ptr @sollang_file_operation_task_cancel, ptr {context}");
        var started = NextTemp("file_async_sync_started");
        EmitCompare(started, "ne", "ptr", handle, "null");
        var readyLabel = NextLabel("file_async_sync_ready");
        var startFailedLabel = NextLabel("file_async_sync_start_failed");
        EmitConditionalBranch(started, readyLabel, startFailedLabel);
        EmitLabel(startFailedLabel);
        EmitCall(target: null, "void", "sollang_free", $"ptr {context}");
        EmitTrap();
        EmitLabel(readyLabel);

        var sizeAddress = NextTemp("file_async_sync_size_address");
        EmitAssign(sizeAddress, $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 11");
        EmitStore("i32", "0", sizeAddress, 4);
        var sourceHandle = ExtractOwnedFileHandle(writer, "sys.file.FileWriter");
        var ownedHandle = NextTemp("file_async_sync_owned_handle");
        EmitCall(
            ownedHandle,
            "i64",
            "sollang_platform_duplicate_owned_file",
            $"i64 {sourceHandle}");
        var handleAddress = NextTemp("file_async_sync_owned_handle_address");
        EmitAssign(handleAddress, $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 17");
        EmitStore("i64", ownedHandle, handleAddress, 8);
        var explicitAddress = NextTemp("file_async_sync_explicit_address");
        EmitAssign(explicitAddress, $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 19");
        EmitStore("i32", "1", explicitAddress, 4);
        var operationAddress = NextTemp("file_async_sync_operation_address");
        EmitAssign(operationAddress, $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 20");
        EmitStore("i32", "2", operationAddress, 4);

        return new RuntimeTask(
            _program.Types.GetOrAddTask(function.ReturnType),
            null,
            function.ReturnType,
            handle,
            context,
            function);
    }

    private RuntimeBool EmitRuntimeSyncFile(RuntimeStruct writer)
    {
        var handle = ExtractOwnedFileHandle(writer, "sys.file.FileWriter");
        var raw = NextTemp("file_sync_result");
        EmitCall(raw, "i32", "sollang_platform_sync_owned_file", $"i64 {handle}");
        var succeeded = NextTemp("file_sync_succeeded");
        EmitCompare(succeeded, "ne", "i32", raw, "0");
        return new RuntimeBool(succeeded);
    }

    private RuntimeBool EmitRuntimeAtomicReplaceFile(BoundFunction function, RuntimeStruct request)
    {
        var definition = _program.Types.GetStruct(request.Type);
        var temporaryField = definition.GetField("temporary");
        var destinationField = definition.GetField("destination");
        var temporaryAggregate = NextTemp("atomic_replace_temporary");
        EmitAssign(temporaryAggregate,
            $"extractvalue {LlvmStructType(request.Type)} {request.ValueName}, {temporaryField.Index}");
        var temporary = DematerializeAggregateValue(temporaryField.Type, temporaryAggregate) as RuntimeText
            ?? throw new SollangException($"{function.Name} expects a Text temporary path");
        var destinationAggregate = NextTemp("atomic_replace_destination");
        EmitAssign(destinationAggregate,
            $"extractvalue {LlvmStructType(request.Type)} {request.ValueName}, {destinationField.Index}");
        var destination = DematerializeAggregateValue(destinationField.Type, destinationAggregate) as RuntimeText
            ?? throw new SollangException($"{function.Name} expects a Text destination path");
        var raw = NextTemp("atomic_replace_result");
        EmitCall(raw, "i32", "sollang_platform_atomic_replace_file",
            $"ptr {temporary.PointerName}, i64 {temporary.LengthName}, " +
            $"ptr {destination.PointerName}, i64 {destination.LengthName}");
        var succeeded = NextTemp("atomic_replace_succeeded");
        EmitCompare(succeeded, "ne", "i32", raw, "0");
        return new RuntimeBool(succeeded);
    }

    private RuntimeEnum EmitRuntimeOpenFile(BoundFunction function, RuntimeValue argument)
    {
        var path = argument as RuntimeText
            ?? throw new SollangException($"{function.Name} expects Text");
        var openSymbol = IsWriteOpenFunction(function.Kind)
            ? "sollang_platform_open_owned_write_file"
            : "sollang_platform_open_owned_read_file";

        var raw = NextTemp("file_open_result");
        EmitCall(
            raw,
            "%sollang.file_handle_result",
            openSymbol,
            $"ptr {path.PointerName}, i64 {path.LengthName}");
        var handle = NextTemp("file_open_handle");
        EmitAssign(handle, $"extractvalue %sollang.file_handle_result {raw}, 0");
        var ok = NextTemp("file_open_ok");
        EmitAssign(ok, $"extractvalue %sollang.file_handle_result {raw}, 1");
        return EmitRuntimeOpenFileResult(function, handle, ok);
    }

    private RuntimeEnum EmitRuntimeReadDirectory(BoundFunction function, RuntimeValue argument)
    {
        if (argument is not RuntimeStruct path
            || !_program.Types.IsStruct(path.Type)
            || _program.Types.GetStruct(path.Type) is not { Name: "sys.path.Path" } pathDefinition)
        {
            throw new SollangException($"{function.Name} expects sys.path.Path");
        }

        var bytesField = pathDefinition.Fields.First(field => field.Name == "bytes");
        var styleField = pathDefinition.Fields.First(field => field.Name == "style");
        var bytesAggregate = NextTemp("directory_path_bytes");
        EmitAssign(
            bytesAggregate,
            $"extractvalue {LlvmStructType(path.Type)} {path.ValueName}, {bytesField.Index.ToString(CultureInfo.InvariantCulture)}");
        if (DematerializeAggregateValue(bytesField.Type, bytesAggregate) is not RuntimeDynamicInlineArray bytes
            || bytes.ElementType != BoundType.UInt8)
        {
            throw new SollangException("sys.path.Path.bytes must be [UInt8; ~]");
        }

        var styleAggregate = NextTemp("directory_path_style");
        EmitAssign(
            styleAggregate,
            $"extractvalue {LlvmStructType(path.Type)} {path.ValueName}, {styleField.Index.ToString(CultureInfo.InvariantCulture)}");
        var styleTag = NextTemp("directory_path_style_tag");
        EmitAssign(styleTag, $"extractvalue {LlvmEnumType(styleField.Type)} {styleAggregate}, 0");

        var platformResult = NextTemp("directory_platform_result");
        EmitCall(
            platformResult,
            "%sollang.directory_result",
            "sollang_platform_read_directory",
            $"ptr {bytes.PointerName}, i64 {bytes.LengthName}, i32 {styleTag}");
        var rawPointer = NextTemp("directory_raw_pointer");
        EmitAssign(rawPointer, $"extractvalue %sollang.directory_result {platformResult}, 0");
        var rawLength = NextTemp("directory_raw_length");
        EmitAssign(rawLength, $"extractvalue %sollang.directory_result {platformResult}, 1");
        var entryCount = NextTemp("directory_entry_count");
        EmitAssign(entryCount, $"extractvalue %sollang.directory_result {platformResult}, 2");
        var status = NextTemp("directory_status");
        EmitAssign(status, $"extractvalue %sollang.directory_result {platformResult}, 3");
        var succeeded = NextTemp("directory_succeeded");
        EmitCompare(succeeded, "sgt", "i32", status, "0");

        if (!_program.Types.TryGetResultTypes(function.ReturnType, out var resultTypes)
            || !_program.Types.IsStruct(resultTypes.Ok)
            || _program.Types.GetStruct(resultTypes.Ok) is not { Name: "sys.directory.Raw" } rawDefinition
            || resultTypes.Error != BoundType.Text)
        {
            throw new SollangException($"{function.Name} has an invalid directory result type");
        }
        var rawBytesField = rawDefinition.Fields.First(field => field.Name == "bytes");
        var rawCountField = rawDefinition.Fields.First(field => field.Name == "count");
        var entryCountValue = entryCount;
        if (_platform.PointerBitWidth == 32 && rawCountField.Type == BoundType.UIntSize)
        {
            entryCountValue = NextTemp("directory_entry_count_size");
            EmitAssign(entryCountValue, $"trunc i64 {entryCount} to i32");
        }
        var rawArray = new RuntimeDynamicInlineArray(
            rawBytesField.Type,
            BoundType.UInt8,
            rawPointer,
            rawLength,
            rawLength);
        var arrayAggregate = BuildDynamicArrayAggregate(
            rawArray.PointerName,
            rawArray.LengthName,
            rawArray.CapacityName);

        var definition = _program.Types.GetEnum(function.ReturnType);
        var okVariant = definition.Variants.First(variant => variant.Name == "Ok");
        var errVariant = definition.Variants.First(variant => variant.Name == "Err");
        var successLabel = NextLabel("directory_success");
        var errorLabel = NextLabel("directory_error");
        var endLabel = NextLabel("directory_end");
        EmitConditionalBranch(succeeded, successLabel, errorLabel);

        EmitLabel(successLabel);
        _currentBlockLabel = successLabel;
        var rawWithBytes = NextTemp("directory_raw_with_bytes");
        EmitAssign(
            rawWithBytes,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} poison, %sollang.dynamic_int_array {arrayAggregate}, {rawBytesField.Index.ToString(CultureInfo.InvariantCulture)}");
        var rawValue = NextTemp("directory_raw_value");
        EmitAssign(
            rawValue,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} {rawWithBytes}, {LlvmType(rawCountField.Type)} {entryCountValue}, {rawCountField.Index.ToString(CultureInfo.InvariantCulture)}");
        var success = EmitEnumValue(
            function.ReturnType,
            okVariant,
            new RuntimeStruct(resultTypes.Ok, rawValue));
        EmitBranch(endLabel);
        var successExit = _currentBlockLabel;

        EmitLabel(errorLabel);
        _currentBlockLabel = errorLabel;
        var failure = EmitEnumValue(function.ReturnType, errVariant, EmitRuntimeErrorText("io"));
        EmitBranch(endLabel);
        var errorExit = _currentBlockLabel;

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        return EmitEnumPhi(
            "directory_result",
            function.ReturnType,
            [(success, successExit), (failure, errorExit)]);
    }

    private RuntimeEnum EmitRuntimePathQuery(BoundFunction function, RuntimeValue argument)
    {
        if (argument is not RuntimeStruct path
            || !_program.Types.IsStruct(path.Type)
            || _program.Types.GetStruct(path.Type) is not { Name: "sys.path.Path" } pathDefinition)
        {
            throw new SollangException($"{function.Name} expects sys.path.Path");
        }

        var bytesField = pathDefinition.Fields.First(field => field.Name == "bytes");
        var styleField = pathDefinition.Fields.First(field => field.Name == "style");
        var bytesAggregate = NextTemp("path_query_input_bytes");
        EmitAssign(bytesAggregate,
            $"extractvalue {LlvmStructType(path.Type)} {path.ValueName}, {bytesField.Index.ToString(CultureInfo.InvariantCulture)}");
        if (DematerializeAggregateValue(bytesField.Type, bytesAggregate) is not RuntimeDynamicInlineArray bytes
            || bytes.ElementType != BoundType.UInt8)
        {
            throw new SollangException("sys.path.Path.bytes must be [UInt8; ~]");
        }
        var styleAggregate = NextTemp("path_query_input_style");
        EmitAssign(styleAggregate,
            $"extractvalue {LlvmStructType(path.Type)} {path.ValueName}, {styleField.Index.ToString(CultureInfo.InvariantCulture)}");
        var styleTag = NextTemp("path_query_input_style_tag");
        EmitAssign(styleTag, $"extractvalue {LlvmEnumType(styleField.Type)} {styleAggregate}, 0");

        var platformResult = NextTemp("path_query_platform_result");
        EmitCall(platformResult, "%sollang.path_query_result", "sollang_platform_query_path",
            $"ptr {bytes.PointerName}, i64 {bytes.LengthName}, i32 {styleTag}");
        string Extract(string name, int index)
        {
            var value = NextTemp(name);
            EmitAssign(value, $"extractvalue %sollang.path_query_result {platformResult}, {index.ToString(CultureInfo.InvariantCulture)}");
            return value;
        }
        var canonicalPointer = Extract("path_query_canonical_pointer", 0);
        var canonicalLength = Extract("path_query_canonical_length", 1);
        var kindCode = Extract("path_query_kind", 2);
        var byteLength = Extract("path_query_byte_length", 3);
        var modifiedNanos = Extract("path_query_modified_nanos", 4);
        var status = Extract("path_query_status", 5);
        var succeeded = NextTemp("path_query_succeeded");
        EmitCompare(succeeded, "sgt", "i32", status, "0");

        if (!_program.Types.TryGetResultTypes(function.ReturnType, out var resultTypes)
            || !_program.Types.IsStruct(resultTypes.Ok)
            || _program.Types.GetStruct(resultTypes.Ok) is not { Name: "sys.path.RawInfo" } rawDefinition
            || resultTypes.Error != BoundType.Text)
        {
            throw new SollangException($"{function.Name} has an invalid path query result type");
        }
        var rawBytesField = rawDefinition.Fields.First(field => field.Name == "bytes");
        var kindField = rawDefinition.Fields.First(field => field.Name == "kindCode");
        var lengthField = rawDefinition.Fields.First(field => field.Name == "byteLength");
        var modifiedField = rawDefinition.Fields.First(field => field.Name == "modifiedNanos");
        var rawArray = new RuntimeDynamicInlineArray(
            rawBytesField.Type, BoundType.UInt8, canonicalPointer, canonicalLength, canonicalLength);
        var arrayAggregate = BuildDynamicArrayAggregate(
            rawArray.PointerName, rawArray.LengthName, rawArray.CapacityName);

        var definition = _program.Types.GetEnum(function.ReturnType);
        var okVariant = definition.Variants.First(variant => variant.Name == "Ok");
        var errVariant = definition.Variants.First(variant => variant.Name == "Err");
        var successLabel = NextLabel("path_query_success");
        var errorLabel = NextLabel("path_query_error");
        var endLabel = NextLabel("path_query_end");
        EmitConditionalBranch(succeeded, successLabel, errorLabel);

        EmitLabel(successLabel);
        _currentBlockLabel = successLabel;
        var withBytes = NextTemp("path_query_raw_bytes");
        EmitAssign(withBytes,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} poison, %sollang.dynamic_int_array {arrayAggregate}, {rawBytesField.Index.ToString(CultureInfo.InvariantCulture)}");
        var withKind = NextTemp("path_query_raw_kind");
        EmitAssign(withKind,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} {withBytes}, i8 {kindCode}, {kindField.Index.ToString(CultureInfo.InvariantCulture)}");
        var withLength = NextTemp("path_query_raw_length");
        EmitAssign(withLength,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} {withKind}, i64 {byteLength}, {lengthField.Index.ToString(CultureInfo.InvariantCulture)}");
        var rawValue = NextTemp("path_query_raw_value");
        EmitAssign(rawValue,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} {withLength}, i64 {modifiedNanos}, {modifiedField.Index.ToString(CultureInfo.InvariantCulture)}");
        var success = EmitEnumValue(function.ReturnType, okVariant, new RuntimeStruct(resultTypes.Ok, rawValue));
        EmitBranch(endLabel);
        var successExit = _currentBlockLabel;

        EmitLabel(errorLabel);
        _currentBlockLabel = errorLabel;
        var failure = EmitEnumValue(function.ReturnType, errVariant, EmitRuntimeErrorText("io"));
        EmitBranch(endLabel);
        var errorExit = _currentBlockLabel;

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        return EmitEnumPhi("path_query_result", function.ReturnType,
            [(success, successExit), (failure, errorExit)]);
    }

    private RuntimeBool EmitRuntimeCreateDirectory(BoundFunction function, RuntimeValue argument)
    {
        if (argument is not RuntimeStruct path
            || !_program.Types.IsStruct(path.Type)
            || _program.Types.GetStruct(path.Type) is not { Name: "sys.path.Path" } pathDefinition)
        {
            throw new SollangException($"{function.Name} expects sys.path.Path");
        }

        var bytesField = pathDefinition.Fields.First(field => field.Name == "bytes");
        var styleField = pathDefinition.Fields.First(field => field.Name == "style");
        var bytesAggregate = NextTemp("create_directory_input_bytes");
        EmitAssign(bytesAggregate,
            $"extractvalue {LlvmStructType(path.Type)} {path.ValueName}, {bytesField.Index.ToString(CultureInfo.InvariantCulture)}");
        if (DematerializeAggregateValue(bytesField.Type, bytesAggregate) is not RuntimeDynamicInlineArray bytes
            || bytes.ElementType != BoundType.UInt8)
        {
            throw new SollangException("sys.path.Path.bytes must be [UInt8; ~]");
        }
        var styleAggregate = NextTemp("create_directory_input_style");
        EmitAssign(styleAggregate,
            $"extractvalue {LlvmStructType(path.Type)} {path.ValueName}, {styleField.Index.ToString(CultureInfo.InvariantCulture)}");
        var styleTag = NextTemp("create_directory_input_style_tag");
        EmitAssign(styleTag, $"extractvalue {LlvmEnumType(styleField.Type)} {styleAggregate}, 0");
        var status = NextTemp("create_directory_status");
        EmitCall(status, "i32", "sollang_platform_create_directory",
            $"ptr {bytes.PointerName}, i64 {bytes.LengthName}, i32 {styleTag}");
        var succeeded = NextTemp("create_directory_succeeded");
        EmitCompare(succeeded, "sgt", "i32", status, "0");
        return new RuntimeBool(succeeded);
    }

    private RuntimeTask EmitRuntimeOpenFileAsync(BoundFunction function, RuntimeValue argument)
    {
        var path = argument as RuntimeText
            ?? throw new SollangException($"{function.Name} expects Text");
        ValidateRuntimeOpenFileResult(function);

        var contextSize = AsyncContextSize(null, function.ReturnType);
        var allocationSize = NextTemp("file_async_open_allocation_size");
        EmitAssign(allocationSize, $"add i64 {contextSize}, {path.LengthName}");
        var context = NextTemp("file_async_open_context");
        EmitCall(context, "ptr", "sollang_alloc", $"i64 {allocationSize}");
        var allocated = NextTemp("file_async_open_context_allocated");
        EmitCompare(allocated, "ne", "ptr", context, "null");
        var initializeLabel = NextLabel("file_async_open_initialize");
        var allocationFailedLabel = NextLabel("file_async_open_allocation_failed");
        EmitConditionalBranch(allocated, initializeLabel, allocationFailedLabel);
        EmitLabel(allocationFailedLabel);
        EmitTrap();
        EmitLabel(initializeLabel);

        var ownedPath = NextTemp("file_async_open_owned_path");
        EmitAssign(ownedPath, $"getelementptr i8, ptr {context}, i64 {contextSize}");
        EmitInstruction(
            $"call void @llvm.memcpy.p0.p0.i64(ptr {ownedPath}, ptr {path.PointerName}, "
            + $"i64 {path.LengthName}, i1 false)");

        var handle = NextTemp("file_async_open_handle");
        EmitCall(
            handle,
            "ptr",
            "sollang_task_start",
            $"ptr @sollang_file_operation_task_worker, ptr @sollang_free, " +
            $"ptr @sollang_file_operation_task_cancel, ptr {context}");
        var started = NextTemp("file_async_open_started");
        EmitCompare(started, "ne", "ptr", handle, "null");
        var readyLabel = NextLabel("file_async_open_ready");
        var startFailedLabel = NextLabel("file_async_open_start_failed");
        EmitConditionalBranch(started, readyLabel, startFailedLabel);
        EmitLabel(startFailedLabel);
        EmitCall(target: null, "void", "sollang_free", $"ptr {context}");
        EmitTrap();
        EmitLabel(readyLabel);

        var sizeAddress = NextTemp("file_async_open_size_address");
        EmitAssign(sizeAddress, $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 11");
        EmitStore("i32", "0", sizeAddress, 4);
        var dataAddress = NextTemp("file_async_open_data_address");
        EmitAssign(dataAddress, $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 13");
        EmitStore("ptr", ownedPath, dataAddress, 8);
        var ownedHandleAddress = NextTemp("file_async_open_owned_handle_address");
        EmitAssign(ownedHandleAddress, $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 17");
        EmitStore("i64", "-1", ownedHandleAddress, 8);
        var pathLengthAddress = NextTemp("file_async_open_path_length_address");
        EmitAssign(pathLengthAddress, $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 18");
        EmitStore("i64", path.LengthName, pathLengthAddress, 8);
        var ownershipAddress = NextTemp("file_async_open_ownership_address");
        EmitAssign(ownershipAddress, $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 19");
        EmitStore("i32", "2", ownershipAddress, 4);
        var operationAddress = NextTemp("file_async_open_operation_address");
        EmitAssign(operationAddress, $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 20");
        EmitStore(
            "i32",
            IsWriteOpenFunction(function.Kind) ? "4" : "3",
            operationAddress,
            4);

        return new RuntimeTask(
            _program.Types.GetOrAddTask(function.ReturnType),
            null,
            function.ReturnType,
            handle,
            context,
            function);
    }

    private RuntimeEnum EmitRuntimeCompletedOpenFile(
        BoundFunction function,
        string completedTaskControl)
    {
        var handleSlot = NextTemp("file_async_open_handle_slot");
        EmitAssign(
            handleSlot,
            $"getelementptr %sollang.task_control, ptr {completedTaskControl}, i32 0, i32 17");
        var handle = NextTemp("file_async_open_result_handle");
        EmitLoad(handle, "i64", handleSlot, 8);
        var okSlot = NextTemp("file_async_open_ok_slot");
        EmitAssign(
            okSlot,
            $"getelementptr %sollang.task_control, ptr {completedTaskControl}, i32 0, i32 15");
        var ok = NextTemp("file_async_open_ok");
        EmitLoad(ok, "i32", okSlot, 4);
        var ownershipSlot = NextTemp("file_async_open_ownership_slot");
        EmitAssign(
            ownershipSlot,
            $"getelementptr %sollang.task_control, ptr {completedTaskControl}, i32 0, i32 19");
        EmitStore("i32", "0", ownershipSlot, 4);
        return EmitRuntimeOpenFileResult(function, handle, ok);
    }

    private RuntimeEnum EmitRuntimeOpenFileResult(
        BoundFunction function,
        string handle,
        string ok)
    {
        var resultTypes = ValidateRuntimeOpenFileResult(function);
        var succeeded = NextTemp("file_open_succeeded");
        EmitCompare(succeeded, "ne", "i32", ok, "0");

        var definition = _program.Types.GetEnum(function.ReturnType);
        var okVariant = definition.Variants.First(variant => variant.Name == "Ok");
        var errVariant = definition.Variants.First(variant => variant.Name == "Err");
        var successLabel = NextLabel("file_open_success");
        var errorLabel = NextLabel("file_open_error");
        var endLabel = NextLabel("file_open_end");
        EmitConditionalBranch(succeeded, successLabel, errorLabel);

        EmitLabel(successLabel);
        _currentBlockLabel = successLabel;
        var fileAggregate = NextTemp("file_value");
        EmitAssign(
            fileAggregate,
            $"insertvalue {LlvmStructType(resultTypes.Ok)} poison, i64 {handle}, 0");
        var success = EmitEnumValue(
            function.ReturnType,
            okVariant,
            new RuntimeStruct(resultTypes.Ok, fileAggregate));
        EmitBranch(endLabel);
        var successExit = _currentBlockLabel;

        EmitLabel(errorLabel);
        _currentBlockLabel = errorLabel;
        var errorText = AddGlobalString("io");
        var failure = EmitEnumValue(
            function.ReturnType,
            errVariant,
            new RuntimeText(errorText.Name, errorText.Length.ToString(CultureInfo.InvariantCulture)));
        EmitBranch(endLabel);
        var errorExit = _currentBlockLabel;

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        return EmitEnumPhi(
            "file_open_result",
            function.ReturnType,
            [(success, successExit), (failure, errorExit)]);
    }

    private (BoundType Ok, BoundType Error) ValidateRuntimeOpenFileResult(BoundFunction function)
    {
        var expectedTypeName = IsWriteOpenFunction(function.Kind)
            ? "sys.file.FileWriter"
            : "sys.file.File";
        if (!_program.Types.TryGetResultTypes(function.ReturnType, out var resultTypes)
            || !_program.Types.IsStruct(resultTypes.Ok)
            || !string.Equals(
                _program.Types.GetStruct(resultTypes.Ok).Name,
                expectedTypeName,
                StringComparison.Ordinal)
            || resultTypes.Error != BoundType.Text)
        {
            throw new SollangException($"{function.Name} has an invalid File result type");
        }
        return resultTypes;
    }

    private static bool IsWriteOpenFunction(BoundFunctionKind kind) =>
        kind is BoundFunctionKind.RuntimeOpenWriteFile
            or BoundFunctionKind.RuntimeOpenWriteFileAsync;

    private string ExtractOwnedFileHandle(RuntimeStruct file, string expectedTypeName = "sys.file.File")
    {
        var definition = _program.Types.GetStruct(file.Type);
        if (!string.Equals(definition.Name, expectedTypeName, StringComparison.Ordinal))
        {
            throw new SollangException($"file operation expects {expectedTypeName}");
        }
        var handle = NextTemp("file_owned_handle");
        EmitAssign(
            handle,
            $"extractvalue {LlvmStructType(file.Type)} {file.ValueName}, 0");
        return handle;
    }

    private RuntimeValue EmitRuntimeFileBufferCall(
        BoundFunction function,
        RuntimeStruct file,
        IReadOnlyList<RuntimeValue> arguments)
    {
        return function.Kind switch
        {
            BoundFunctionKind.RuntimeReadBytesAt => EmitRuntimeReadBytesAt(function, file, arguments),
            BoundFunctionKind.RuntimeWriteBytesAt => EmitRuntimeWriteBytesAt(function, file, arguments),
            BoundFunctionKind.RuntimeReadBytesAtAsync => EmitRuntimeReadBytesAtAsync(function, file, arguments),
            BoundFunctionKind.RuntimeWriteBytesAtAsync => EmitRuntimeWriteBytesAtAsync(function, file, arguments),
            _ => throw new SollangException($"unsupported file buffer intrinsic '{function.Name}'")
        };
    }

    private RuntimeTask EmitRuntimeReadBytesAtAsync(
        BoundFunction function,
        RuntimeStruct file,
        IReadOnlyList<RuntimeValue> arguments)
    {
        if (arguments.Count != 3
            || arguments[0] is not RuntimeDynamicInlineArray output
            || output.ElementType != BoundType.UInt8
            || arguments[1] is not RuntimeInt { Type: BoundType.UInt64 } offset
            || arguments[2] is not RuntimeBool cancelled)
        {
            throw new SollangException($"{function.Name} expects move [UInt8; ~], UInt64, Bool");
        }

        ValidateAsyncFileBufferResult(function, read: true);
        var operation = NextTemp("file_async_read_into_operation");
        EmitAssign(operation, $"select i1 {cancelled.ValueName}, i32 8, i32 5");
        return EmitRuntimeFileBufferTask(
            function,
            file,
            output,
            output.PointerName,
            output.LengthName,
            offset.ValueName,
            operation,
            "file_async_read_into");
    }

    private RuntimeTask EmitRuntimeWriteBytesAtAsync(
        BoundFunction function,
        RuntimeStruct writer,
        IReadOnlyList<RuntimeValue> arguments)
    {
        if (arguments.Count != 5
            || arguments[1] is not RuntimeInt { Type: BoundType.UIntSize } inputOffset
            || arguments[2] is not RuntimeInt { Type: BoundType.UIntSize } length
            || arguments[3] is not RuntimeInt { Type: BoundType.UInt64 } fileOffset
            || arguments[4] is not RuntimeBool cancelled)
        {
            throw new SollangException($"{function.Name} expects move [UInt8; ~], UIntSize, UIntSize, UInt64, Bool");
        }

        if (arguments[0] is not RuntimeDynamicInlineArray input
            || input.ElementType != BoundType.UInt8)
        {
            throw new SollangException($"{function.Name} expects move [UInt8; ~]");
        }

        ValidateAsyncFileBufferResult(function, read: false);
        var inputOffset64 = EmitRuntimeIntegerAsI64(inputOffset, "file_async_write_range_offset64");
        var length64 = EmitRuntimeIntegerAsI64(length, "file_async_write_range_length64");
        var offsetInBounds = NextTemp("file_async_write_range_offset_in_bounds");
        EmitCompare(offsetInBounds, "ule", "i64", inputOffset64, input.LengthName);
        var remaining = NextTemp("file_async_write_range_remaining");
        EmitAssign(remaining, $"sub i64 {input.LengthName}, {inputOffset64}");
        var lengthInBounds = NextTemp("file_async_write_range_length_in_bounds");
        EmitCompare(lengthInBounds, "ule", "i64", length64, remaining);
        var rangeValid = NextTemp("file_async_write_range_valid");
        EmitAssign(rangeValid, $"and i1 {offsetInBounds}, {lengthInBounds}");
        var pointer = NextTemp("file_async_write_range_pointer");
        EmitAssign(pointer, $"getelementptr i8, ptr {input.PointerName}, i64 {inputOffset64}");
        var validOperation = NextTemp("file_async_write_range_valid_operation");
        EmitAssign(validOperation, $"select i1 {rangeValid}, i32 6, i32 7");
        var operation = NextTemp("file_async_write_range_operation");
        EmitAssign(operation, $"select i1 {cancelled.ValueName}, i32 8, i32 {validOperation}");
        return EmitRuntimeFileBufferTask(
            function,
            writer,
            input,
            pointer,
            length64,
            fileOffset.ValueName,
            operation,
            "file_async_write_range");
    }

    private RuntimeTask EmitRuntimeFileBufferTask(
        BoundFunction function,
        RuntimeStruct file,
        RuntimeDynamicInlineArray buffer,
        string pointer,
        string length,
        string offset,
        string operation,
        string prefix)
    {
        var contextSize = AsyncContextSize(function);
        var context = NextTemp(prefix + "_context");
        EmitCall(context, "ptr", "sollang_alloc", $"i64 {contextSize}");
        var allocated = NextTemp(prefix + "_context_allocated");
        EmitCompare(allocated, "ne", "ptr", context, "null");
        var initializeLabel = NextLabel(prefix + "_initialize");
        var allocationFailedLabel = NextLabel(prefix + "_allocation_failed");
        EmitConditionalBranch(allocated, initializeLabel, allocationFailedLabel);
        EmitLabel(allocationFailedLabel);
        EmitTrap();
        EmitLabel(initializeLabel);

        var handle = NextTemp(prefix + "_handle");
        EmitCall(
            handle,
            "ptr",
            "sollang_task_start",
            $"ptr @sollang_file_operation_task_worker, ptr @sollang_free, "
            + $"ptr @{AsyncFileBufferCancelSymbol(function)}, ptr {context}");
        var started = NextTemp(prefix + "_started");
        EmitCompare(started, "ne", "ptr", handle, "null");
        var readyLabel = NextLabel(prefix + "_ready");
        var startFailedLabel = NextLabel(prefix + "_start_failed");
        EmitConditionalBranch(started, readyLabel, startFailedLabel);
        EmitLabel(startFailedLabel);
        EmitCall(target: null, "void", "sollang_free", $"ptr {context}");
        EmitTrap();
        EmitLabel(readyLabel);

        var fileValue = MaterializeAggregateValue(file);
        EmitAsyncFunctionContextStore(
            context,
            function,
            5,
            fileValue.TypeName,
            fileValue.ValueName,
            RuntimeAlignment(file.Type));
        var bufferValue = MaterializeAggregateValue(buffer);
        EmitAsyncFunctionContextStore(
            context,
            function,
            10,
            bufferValue.TypeName,
            bufferValue.ValueName,
            RuntimeAlignment(buffer.Type));
        EmitAsyncFunctionContextStore(
            context,
            function,
            6,
            AsyncStorageLlvmType(function.ReturnType),
            "zeroinitializer",
            RuntimeAlignment(function.ReturnType));

        var boundedLength = NextTemp(prefix + "_bounded_length");
        var lengthFits = NextTemp(prefix + "_length_fits");
        EmitCompare(lengthFits, "ule", "i64", length, "2147483647");
        EmitAssign(boundedLength, $"select i1 {lengthFits}, i64 {length}, i64 2147483647");
        var size = NextTemp(prefix + "_size");
        EmitAssign(size, $"trunc i64 {boundedLength} to i32");
        var sizeAddress = NextTemp(prefix + "_size_address");
        EmitAssign(sizeAddress, $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 11");
        EmitStore("i32", size, sizeAddress, 4);
        var pointerValue = NextTemp(prefix + "_pointer_value");
        EmitAssign(pointerValue, $"ptrtoint ptr {pointer} to i64");
        var dataAddress = NextTemp(prefix + "_data_address");
        EmitAssign(dataAddress, $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 13");
        EmitStore("i64", pointerValue, dataAddress, 8);

        var expectedTypeName = function.Kind == BoundFunctionKind.RuntimeReadBytesAtAsync
            ? "sys.file.File"
            : "sys.file.FileWriter";
        var sourceHandle = ExtractOwnedFileHandle(file, expectedTypeName);
        var ownedHandle = NextTemp(prefix + "_owned_handle");
        EmitCall(ownedHandle, "i64", "sollang_platform_duplicate_owned_file", $"i64 {sourceHandle}");
        var handleAddress = NextTemp(prefix + "_owned_handle_address");
        EmitAssign(handleAddress, $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 17");
        EmitStore("i64", ownedHandle, handleAddress, 8);
        var offsetAddress = NextTemp(prefix + "_offset_address");
        EmitAssign(offsetAddress, $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 18");
        EmitStore("i64", offset, offsetAddress, 8);
        var explicitAddress = NextTemp(prefix + "_explicit_address");
        EmitAssign(explicitAddress, $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 19");
        EmitStore("i32", "1", explicitAddress, 4);
        var operationAddress = NextTemp(prefix + "_operation_address");
        EmitAssign(operationAddress, $"getelementptr %sollang.task_control, ptr {handle}, i32 0, i32 20");
        EmitStore("i32", operation, operationAddress, 4);

        return new RuntimeTask(
            _program.Types.GetOrAddTask(function.ReturnType),
            function.InputType,
            function.ReturnType,
            handle,
            context,
            function);
    }

    private void EmitAsyncFileBufferCancelFunctions()
    {
        foreach (var function in _reachableFunctions
                     .Where(static function => function.Kind is
                         BoundFunctionKind.RuntimeReadBytesAtAsync
                         or BoundFunctionKind.RuntimeWriteBytesAtAsync))
        {
            _currentFunction = function;
            _tempId = 0;
            _labelId = 0;
            ClearLocalState();
            EmitFunctionLine($"define internal void @{AsyncFileBufferCancelSymbol(function)}(ptr %control) #0 {{");
            EmitLabel("entry");
            _currentBlockLabel = "entry";
            var contextSlot = NextTemp("file_buffer_cancel_context_slot");
            EmitAssign(contextSlot, "getelementptr %sollang.task_control, ptr %control, i32 0, i32 0");
            EmitLoad("%context", "ptr", contextSlot, 8);
            var explicitSlot = NextTemp("file_buffer_cancel_explicit_slot");
            EmitAssign(explicitSlot, "getelementptr %sollang.task_control, ptr %control, i32 0, i32 19");
            var explicitValue = NextTemp("file_buffer_cancel_explicit");
            EmitLoad(explicitValue, "i32", explicitSlot, 4);
            var ownsDuplicate = NextTemp("file_buffer_cancel_owns_duplicate");
            EmitCompare(ownsDuplicate, "ne", "i32", explicitValue, "0");
            var closeLabel = NextLabel("file_buffer_cancel_close_duplicate");
            var dropLabel = NextLabel("file_buffer_cancel_drop_owners");
            EmitConditionalBranch(ownsDuplicate, closeLabel, dropLabel);

            EmitLabel(closeLabel);
            _currentBlockLabel = closeLabel;
            var handleSlot = NextTemp("file_buffer_cancel_handle_slot");
            EmitAssign(handleSlot, "getelementptr %sollang.task_control, ptr %control, i32 0, i32 17");
            var handle = NextTemp("file_buffer_cancel_handle");
            EmitLoad(handle, "i64", handleSlot, 8);
            EmitCall(target: null, "void", "sollang_platform_close_owned_file", $"i64 {handle}");
            EmitStore("i32", "0", explicitSlot, 4);
            EmitBranch(dropLabel);

            EmitLabel(dropLabel);
            _currentBlockLabel = dropLabel;
            DropCancelledAsyncInput(function);
            DropCancelledAsyncAdditionalInputs(function);
            EmitCall(target: null, "void", "sollang_free", "ptr %context");
            EmitInstruction("ret void");
            _currentBlockTerminated = true;
            EmitFunctionLine("}");
            EmitFunctionLine();
        }
    }

    private static string AsyncFileBufferCancelSymbol(BoundFunction function) =>
        SymbolForFunction(function)[1..] + "_file_buffer_cancel";

    private RuntimeEnum EmitRuntimeCompletedFileBuffer(
        BoundFunction function,
        string completedTaskControl,
        string context)
    {
        var read = function.Kind == BoundFunctionKind.RuntimeReadBytesAtAsync;
        ValidateAsyncFileBufferResult(function, read);
        var fileAggregate = NextTemp("file_async_owner");
        EmitAsyncFunctionContextLoad(
            fileAggregate,
            context,
            function,
            5,
            AsyncStorageLlvmType(function.InputType),
            RuntimeAlignment(function.InputType!.Value));
        var file = new RuntimeStruct(function.InputType.Value, fileAggregate);
        var bufferType = function.AdditionalParameters![0].Type;
        var bufferAggregate = NextTemp("file_async_buffer_owner");
        EmitAsyncFunctionContextLoad(
            bufferAggregate,
            context,
            function,
            10,
            AsyncStorageLlvmType(bufferType),
            RuntimeAlignment(bufferType));
        var buffer = (RuntimeDynamicInlineArray)DematerializeAggregateValue(bufferType, bufferAggregate);

        var countSlot = NextTemp("file_async_count_slot");
        EmitAssign(countSlot, $"getelementptr %sollang.task_control, ptr {completedTaskControl}, i32 0, i32 14");
        var count = NextTemp("file_async_count");
        EmitLoad(count, "i64", countSlot, 8);
        var okSlot = NextTemp("file_async_ok_slot");
        EmitAssign(okSlot, $"getelementptr %sollang.task_control, ptr {completedTaskControl}, i32 0, i32 15");
        var platformOk = NextTemp("file_async_ok");
        EmitLoad(platformOk, "i32", okSlot, 4);
        var succeeded = NextTemp("file_async_succeeded");
        EmitCompare(succeeded, "ne", "i32", platformOk, "0");
        var operationSlot = NextTemp("file_async_operation_slot");
        EmitAssign(operationSlot, $"getelementptr %sollang.task_control, ptr {completedTaskControl}, i32 0, i32 20");
        var operation = NextTemp("file_async_operation");
        EmitLoad(operation, "i32", operationSlot, 4);

        var resultDefinition = _program.Types.GetEnum(function.ReturnType);
        var okVariant = resultDefinition.Variants.First(static variant => variant.Name == "Ok");
        var errVariant = resultDefinition.Variants.First(static variant => variant.Name == "Err");
        var successLabel = NextLabel("file_async_success");
        var failureLabel = NextLabel("file_async_failure");
        var endLabel = NextLabel("file_async_result_end");
        EmitConditionalBranch(succeeded, successLabel, failureLabel);

        EmitLabel(successLabel);
        _currentBlockLabel = successLabel;
        var countValue = new RuntimeInt(BoundType.UIntSize, EmitUIntSizeFromI64(count));
        RuntimeStruct successPayload;
        if (read)
        {
            var countIsZero = NextTemp("file_async_count_zero");
            EmitCompare(countIsZero, "eq", "i64", count, "0");
            var requestWasNonempty = NextTemp("file_async_request_nonempty");
            EmitCompare(requestWasNonempty, "ne", "i64", buffer.LengthName, "0");
            var end = NextTemp("file_async_end");
            EmitAssign(end, $"and i1 {countIsZero}, {requestWasNonempty}");
            successPayload = EmitRuntimeStructAggregate(
                resultDefinition.Variants.First(static variant => variant.Name == "Ok").PayloadType!.Value,
                [file, buffer, countValue, new RuntimeBool(end)],
                "file_async_read_success");
        }
        else
        {
            successPayload = EmitRuntimeStructAggregate(
                resultDefinition.Variants.First(static variant => variant.Name == "Ok").PayloadType!.Value,
                [file, buffer, countValue],
                "file_async_write_success");
        }
        var success = EmitEnumValue(function.ReturnType, okVariant, successPayload);
        EmitBranch(endLabel);
        var successExit = _currentBlockLabel;

        EmitLabel(failureLabel);
        _currentBlockLabel = failureLabel;
        var failureType = errVariant.PayloadType!.Value;
        var failureDefinition = _program.Types.GetStruct(failureType);
        var errorType = failureDefinition.GetField("error").Type;
        var error = EmitAsyncFileBufferError(errorType, operation);
        var failurePayload = EmitRuntimeStructAggregate(
            failureType,
            [file, buffer, error],
            read ? "file_async_read_failure" : "file_async_write_failure");
        var failure = EmitEnumValue(function.ReturnType, errVariant, failurePayload);
        EmitBranch(endLabel);
        var failureExit = _currentBlockLabel;

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        return EmitEnumPhi(
            read ? "file_async_read_result" : "file_async_write_result",
            function.ReturnType,
            [(success, successExit), (failure, failureExit)]);
    }

    private RuntimeEnum EmitAsyncFileBufferError(BoundType errorType, string operation)
    {
        var definition = _program.Types.GetEnum(errorType);
        var io = definition.Variants.First(static variant => variant.Name == "Io");
        var invalidRange = definition.Variants.First(static variant => variant.Name == "InvalidRange");
        var cancelled = definition.Variants.First(static variant => variant.Name == "Cancelled");
        var cancelledCondition = NextTemp("file_async_error_cancelled");
        EmitCompare(cancelledCondition, "eq", "i32", operation, "8");
        var cancelledLabel = NextLabel("file_async_error_cancelled");
        var inspectRangeLabel = NextLabel("file_async_error_inspect_range");
        var rangeLabel = NextLabel("file_async_error_range");
        var ioLabel = NextLabel("file_async_error_io");
        var endLabel = NextLabel("file_async_error_end");
        EmitConditionalBranch(cancelledCondition, cancelledLabel, inspectRangeLabel);

        EmitLabel(cancelledLabel);
        _currentBlockLabel = cancelledLabel;
        var cancelledValue = EmitEnumValue(errorType, cancelled, payload: null);
        EmitBranch(endLabel);
        var cancelledExit = _currentBlockLabel;

        EmitLabel(inspectRangeLabel);
        _currentBlockLabel = inspectRangeLabel;
        var rangeCondition = NextTemp("file_async_error_invalid_range");
        EmitCompare(rangeCondition, "eq", "i32", operation, "7");
        EmitConditionalBranch(rangeCondition, rangeLabel, ioLabel);

        EmitLabel(rangeLabel);
        _currentBlockLabel = rangeLabel;
        var rangeValue = EmitEnumValue(errorType, invalidRange, payload: null);
        EmitBranch(endLabel);
        var rangeExit = _currentBlockLabel;

        EmitLabel(ioLabel);
        _currentBlockLabel = ioLabel;
        var ioValue = EmitEnumValue(errorType, io, EmitRuntimeErrorText("io"));
        EmitBranch(endLabel);
        var ioExit = _currentBlockLabel;

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        return EmitEnumPhi(
            "file_async_error",
            errorType,
            [(cancelledValue, cancelledExit), (rangeValue, rangeExit), (ioValue, ioExit)]);
    }

    private RuntimeStruct EmitRuntimeStructAggregate(
        BoundType type,
        IReadOnlyList<RuntimeValue> values,
        string prefix)
    {
        var definition = _program.Types.GetStruct(type);
        if (definition.Fields.Count != values.Count)
        {
            throw new SollangException($"{definition.Name} has an invalid file async payload shape");
        }
        var aggregate = "poison";
        for (var index = 0; index < values.Count; index++)
        {
            var value = values[index];
            EnsureRuntimeType(value, definition.Fields[index].Type, definition.Name);
            var materialized = MaterializeAggregateValue(value);
            var next = NextTemp(prefix);
            EmitAssign(next,
                $"insertvalue {LlvmStructType(type)} {aggregate}, {materialized.TypeName} {materialized.ValueName}, {index}");
            aggregate = next;
        }
        return new RuntimeStruct(type, aggregate);
    }

    private void ValidateAsyncFileBufferResult(BoundFunction function, bool read)
    {
        if (!_program.Types.TryGetResultTypes(function.ReturnType, out var resultTypes)
            || !IsRuntimeStructNamed(resultTypes.Ok, read ? "sys.file.ReadAtSuccess" : "sys.file.WriteAtSuccess")
            || !IsRuntimeStructNamed(resultTypes.Error, read ? "sys.file.ReadAtFailure" : "sys.file.WriteAtFailure"))
        {
            throw new SollangException($"{function.Name} has an invalid asynchronous file buffer result");
        }
    }

    private bool IsRuntimeStructNamed(BoundType type, string name) =>
        _program.Types.IsStruct(type)
        && string.Equals(_program.Types.GetStruct(type).Name, name, StringComparison.Ordinal);

    private RuntimeEnum EmitRuntimeReadBytesAt(
        BoundFunction function,
        RuntimeStruct file,
        IReadOnlyList<RuntimeValue> arguments)
    {
        if (arguments.Count != 2
            || arguments[0] is not RuntimeMutableContainerReference output
            || !_program.Types.IsDynamicArray(output.TargetType)
            || _program.Types.GetDynamicArray(output.TargetType).ElementType != BoundType.UInt8
            || arguments[1] is not RuntimeInt { Type: BoundType.UInt64 } offset)
        {
            throw new SollangException($"{function.Name} expects mut [UInt8; ~], UInt64");
        }

        ValidateFileByteCountResult(function);
        var pointer = NextTemp("file_read_into_pointer");
        var length = NextTemp("file_read_into_length");
        EmitLoad(pointer, "ptr", output.PointerAddress, 8);
        EmitLoad(length, "i64", output.LengthAddress, 8);
        var raw = NextTemp("file_read_into_result");
        EmitCall(
            raw,
            "%sollang.file_count_result",
            "sollang_platform_read_owned_file_at",
            $"i64 {ExtractOwnedFileHandle(file)}, ptr {pointer}, i64 {length}, i64 {offset.ValueName}");
        return EmitFileByteCountResult(function, raw, "file_read_into");
    }

    private RuntimeEnum EmitRuntimeWriteBytesAt(
        BoundFunction function,
        RuntimeStruct writer,
        IReadOnlyList<RuntimeValue> arguments)
    {
        if (arguments.Count != 4
            || arguments[1] is not RuntimeInt { Type: BoundType.UIntSize } inputOffset
            || arguments[2] is not RuntimeInt { Type: BoundType.UIntSize } length
            || arguments[3] is not RuntimeInt { Type: BoundType.UInt64 } fileOffset)
        {
            throw new SollangException($"{function.Name} expects ref [UInt8; ~], UIntSize, UIntSize, UInt64");
        }

        var inputValue = arguments[0] is RuntimeReference reference
            ? LoadReference(reference)
            : arguments[0];
        if (inputValue is not RuntimeDynamicInlineArray input
            || input.ElementType != BoundType.UInt8)
        {
            throw new SollangException($"{function.Name} expects ref [UInt8; ~]");
        }

        ValidateFileByteCountResult(function);
        var inputOffset64 = EmitRuntimeIntegerAsI64(inputOffset, "file_write_range_offset64");
        var length64 = EmitRuntimeIntegerAsI64(length, "file_write_range_length64");
        var offsetInBounds = NextTemp("file_write_range_offset_in_bounds");
        EmitCompare(offsetInBounds, "ule", "i64", inputOffset64, input.LengthName);
        var remaining = NextTemp("file_write_range_remaining");
        EmitAssign(remaining, $"sub i64 {input.LengthName}, {inputOffset64}");
        var lengthInBounds = NextTemp("file_write_range_length_in_bounds");
        EmitCompare(lengthInBounds, "ule", "i64", length64, remaining);
        var rangeValid = NextTemp("file_write_range_valid");
        EmitAssign(rangeValid, $"and i1 {offsetInBounds}, {lengthInBounds}");

        var performLabel = NextLabel("file_write_range_perform");
        var rangeErrorLabel = NextLabel("file_write_range_invalid");
        var platformSuccessLabel = NextLabel("file_write_range_success");
        var platformErrorLabel = NextLabel("file_write_range_io_error");
        var endLabel = NextLabel("file_write_range_end");
        var incoming = new List<(RuntimeValue Value, string Label)>();
        var definition = _program.Types.GetEnum(function.ReturnType);
        var okVariant = definition.Variants.First(variant => variant.Name == "Ok");
        var errVariant = definition.Variants.First(variant => variant.Name == "Err");
        EmitConditionalBranch(rangeValid, performLabel, rangeErrorLabel);

        EmitLabel(rangeErrorLabel);
        _currentBlockLabel = rangeErrorLabel;
        var rangeError = EmitRuntimeErrorText("range");
        incoming.Add((EmitEnumValue(function.ReturnType, errVariant, rangeError), _currentBlockLabel));
        EmitBranch(endLabel);

        EmitLabel(performLabel);
        _currentBlockLabel = performLabel;
        var pointer = NextTemp("file_write_range_pointer");
        EmitAssign(pointer, $"getelementptr i8, ptr {input.PointerName}, i64 {inputOffset64}");
        var raw = NextTemp("file_write_range_result");
        EmitCall(
            raw,
            "%sollang.file_count_result",
            "sollang_platform_write_owned_file_at",
            $"i64 {ExtractOwnedFileHandle(writer, "sys.file.FileWriter")}, ptr {pointer}, i64 {length64}, i64 {fileOffset.ValueName}");
        var count = NextTemp("file_write_range_count");
        EmitAssign(count, $"extractvalue %sollang.file_count_result {raw}, 0");
        var platformOk = NextTemp("file_write_range_ok");
        EmitAssign(platformOk, $"extractvalue %sollang.file_count_result {raw}, 1");
        var succeeded = NextTemp("file_write_range_succeeded");
        EmitCompare(succeeded, "ne", "i32", platformOk, "0");
        EmitConditionalBranch(succeeded, platformSuccessLabel, platformErrorLabel);

        EmitLabel(platformSuccessLabel);
        _currentBlockLabel = platformSuccessLabel;
        incoming.Add((EmitEnumValue(
            function.ReturnType,
            okVariant,
            new RuntimeInt(BoundType.UIntSize, EmitUIntSizeFromI64(count))), _currentBlockLabel));
        EmitBranch(endLabel);

        EmitLabel(platformErrorLabel);
        _currentBlockLabel = platformErrorLabel;
        var ioError = EmitRuntimeErrorText("io");
        incoming.Add((EmitEnumValue(function.ReturnType, errVariant, ioError), _currentBlockLabel));
        EmitBranch(endLabel);

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        return EmitEnumPhi("file_write_range_result", function.ReturnType, incoming);
    }

    private RuntimeEnum EmitFileByteCountResult(
        BoundFunction function,
        string raw,
        string prefix)
    {
        var definition = _program.Types.GetEnum(function.ReturnType);
        var okVariant = definition.Variants.First(variant => variant.Name == "Ok");
        var errVariant = definition.Variants.First(variant => variant.Name == "Err");
        var count = NextTemp(prefix + "_count");
        EmitAssign(count, $"extractvalue %sollang.file_count_result {raw}, 0");
        var platformOk = NextTemp(prefix + "_ok");
        EmitAssign(platformOk, $"extractvalue %sollang.file_count_result {raw}, 1");
        var succeeded = NextTemp(prefix + "_succeeded");
        EmitCompare(succeeded, "ne", "i32", platformOk, "0");
        var successLabel = NextLabel(prefix + "_success");
        var errorLabel = NextLabel(prefix + "_error");
        var endLabel = NextLabel(prefix + "_end");
        EmitConditionalBranch(succeeded, successLabel, errorLabel);

        EmitLabel(successLabel);
        _currentBlockLabel = successLabel;
        var success = EmitEnumValue(
            function.ReturnType,
            okVariant,
            new RuntimeInt(BoundType.UIntSize, EmitUIntSizeFromI64(count)));
        EmitBranch(endLabel);
        var successExit = _currentBlockLabel;

        EmitLabel(errorLabel);
        _currentBlockLabel = errorLabel;
        var error = EmitEnumValue(
            function.ReturnType,
            errVariant,
            EmitRuntimeErrorText("io"));
        EmitBranch(endLabel);
        var errorExit = _currentBlockLabel;

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        return EmitEnumPhi(prefix + "_result", function.ReturnType, [(success, successExit), (error, errorExit)]);
    }

    private void ValidateFileByteCountResult(BoundFunction function)
    {
        if (!_program.Types.TryGetResultTypes(function.ReturnType, out var resultTypes)
            || resultTypes.Ok != BoundType.UIntSize
            || resultTypes.Error != BoundType.Text)
        {
            throw new SollangException($"{function.Name} must return Result<UIntSize, Text>");
        }
    }

    private void EmitReturnIfReadFailed(string readOk)
    {
        var isOk = NextTemp("read_is_ok");
        var failLabel = NextLabel("read_fail");
        var continueLabel = NextLabel("read_continue");

        EmitCompare(isOk, "ne", "i32", readOk, "0");
        EmitConditionalBranch(isOk, continueLabel, failLabel);
        EmitLabel(failLabel);
        EmitRet("i32", "1");
        EmitLabel(continueLabel);
        _currentBlockLabel = continueLabel;
    }

    private RuntimeUnit EmitRuntimeUnitIntrinsic(BoundFunction function, RuntimeValue? argument, string path)
    {
        return EmitRuntimeUnitIntrinsic(function.Kind, argument, path);
    }

    private RuntimeUnit EmitRuntimeUnitIntrinsic(BoundFunctionKind kind, RuntimeValue? argument, string path)
    {
        if (_usesAsync
            && kind is BoundFunctionKind.RuntimeOpenIntReader or BoundFunctionKind.RuntimeCloseIntReader)
        {
            EmitCall(target: null, "void", "sollang_file_wait_idle", "");
        }

        var ok = kind switch
        {
            BoundFunctionKind.RuntimeSeedRandom => EmitRuntimeIntStatusCall(
                "sollang_seed_random",
                argument,
                path),
            BoundFunctionKind.RuntimeOpenIntWriter => EmitRuntimeTextStatusCall(
                "sollang_open_write_i64_file",
                argument,
                path),
            BoundFunctionKind.RuntimeWriteInt => EmitRuntimeIntStatusCall(
                "sollang_write_i64_file",
                argument,
                path),
            BoundFunctionKind.RuntimeCloseIntWriter => EmitRuntimeNoArgumentStatusCall(
                "sollang_close_write_i64_file",
                argument,
                path),
            BoundFunctionKind.RuntimeOpenIntReader => EmitRuntimeTextStatusCall(
                "sollang_platform_open_read_file",
                argument,
                path),
            BoundFunctionKind.RuntimeCloseIntReader => EmitRuntimeNoArgumentStatusCall(
                "sollang_platform_close_read_file",
                argument,
                path),
            _ => throw new SollangException($"unsupported runtime unit intrinsic '{kind}'")
        };

        _mainOk = CombineWriteOk(ok, _mainOk);
        EmitReturnIfReadFailed(ok);
        return RuntimeUnit.Instance;
    }

    private string EmitRuntimeNoArgumentStatusCall(string functionName, RuntimeValue? argument, string path)
    {
        if (argument is not null)
        {
            throw new SollangException($"{path} does not accept an argument");
        }

        var ok = NextTemp("runtime_ok");
        EmitCall(ok, "i32", functionName, "");
        return ok;
    }

    private string EmitRuntimeTextStatusCall(string functionName, RuntimeValue? argument, string path)
    {
        if (argument is not RuntimeText text)
        {
            throw new SollangException($"{path} expects Text");
        }

        var ok = NextTemp("runtime_ok");
        EmitCall(ok, "i32", functionName, $"ptr {text.PointerName}, i64 {text.LengthName}");
        return ok;
    }

    private string EmitRuntimeIntStatusCall(string functionName, RuntimeValue? argument, string path)
    {
        if (argument is not RuntimeInt integer)
        {
            throw new SollangException($"{path} expects Int");
        }

        var ok = NextTemp("runtime_ok");
        var wide = EmitRuntimeIntegerAsI64(integer, "runtime_argument");
        EmitCall(ok, "i32", functionName, $"i64 {wide}");
        return ok;
    }

    private RuntimeInt EmitRuntimeIntIntrinsic(BoundFunction function, RuntimeValue argument, string path)
    {
        return EmitRuntimeIntIntrinsic(function.Kind, argument, path);
    }

    private RuntimeInt EmitRuntimeIntIntrinsic(BoundFunctionKind kind, RuntimeValue argument, string path)
    {
        if (argument is not RuntimeInt integer)
        {
            throw new SollangException($"{path} expects Int");
        }

        var helperName = kind switch
        {
            BoundFunctionKind.RuntimeRandomBelow => "sollang_random_below",
            BoundFunctionKind.RuntimeClosestInt => "sollang_closest_i64_file",
            _ => throw new SollangException($"unsupported runtime int intrinsic '{kind}'")
        };

        var result = NextTemp("runtime_int");
        var wide = EmitRuntimeIntegerAsI64(integer, "runtime_argument");
        EmitCall(result, "%sollang.file_int_result", helperName, $"i64 {wide}");

        var value = NextTemp("runtime_value");
        EmitAssign(value, $"extractvalue %sollang.file_int_result {result}, 0");

        var ok = NextTemp("runtime_ok");
        EmitAssign(ok, $"extractvalue %sollang.file_int_result {result}, 1");

        _mainOk = CombineWriteOk(ok, _mainOk);
        EmitReturnIfReadFailed(ok);
        var narrowed = NextTemp("runtime_int32");
        EmitAssign(narrowed, $"trunc i64 {value} to i32");
        return new RuntimeInt(narrowed);
    }

    private RuntimeEnum EmitRuntimeSecureRandomBytes(
        BoundFunction function,
        RuntimeValue argument,
        string path)
    {
        if (argument is not RuntimeInt { Type: BoundType.UIntSize } count)
        {
            throw new SollangException($"{path} expects UIntSize");
        }
        if (!_program.Types.TryGetResultTypes(function.ReturnType, out var resultTypes)
            || resultTypes.Ok != TypeId.DynamicUInt8Array
            || !_program.Types.IsEnum(resultTypes.Error)
            || _program.Types.GetEnum(resultTypes.Error).Name != "std.crypto.random.Error")
        {
            throw new SollangException($"{path} has an invalid secure random result type");
        }

        var allocationSize = NextTemp("secure_random_allocation_size");
        var empty = NextTemp("secure_random_empty");
        EmitCompare(empty, "eq", "i64", count.ValueName, "0");
        EmitSelect(allocationSize, empty, "i64 1", $"i64 {count.ValueName}");
        var buffer = EmitHeapAllocate(allocationSize);
        var filled = NextTemp("secure_random_filled");
        EmitCall(
            filled,
            "i1",
            "sollang_secure_random_fill",
            $"ptr {buffer}, i64 {count.ValueName}");

        var resultDefinition = _program.Types.GetEnum(function.ReturnType);
        var okVariant = resultDefinition.Variants.First(variant => variant.Name == "Ok");
        var errVariant = resultDefinition.Variants.First(variant => variant.Name == "Err");
        var successLabel = NextLabel("secure_random_success");
        var failureLabel = NextLabel("secure_random_failure");
        var endLabel = NextLabel("secure_random_end");
        EmitConditionalBranch(filled, successLabel, failureLabel);

        EmitLabel(successLabel);
        _currentBlockLabel = successLabel;
        var bytes = new RuntimeDynamicInlineArray(
            resultTypes.Ok,
            BoundType.UInt8,
            buffer,
            count.ValueName,
            count.ValueName);
        var success = EmitEnumValue(function.ReturnType, okVariant, bytes);
        EmitBranch(endLabel);
        var successExit = _currentBlockLabel;

        EmitLabel(failureLabel);
        _currentBlockLabel = failureLabel;
        EmitCall(target: null, "void", "sollang_free", $"ptr {buffer}");
        var errorDefinition = _program.Types.GetEnum(resultTypes.Error);
        var unavailableVariant = errorDefinition.Variants.First(
            variant => variant.Name == "Unavailable");
        var unavailable = EmitEnumValue(resultTypes.Error, unavailableVariant, payload: null);
        var failure = EmitEnumValue(function.ReturnType, errVariant, unavailable);
        EmitBranch(endLabel);
        var failureExit = _currentBlockLabel;

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        return EmitEnumPhi(
            "secure_random_result",
            function.ReturnType,
            [(success, successExit), (failure, failureExit)]);
    }

    private string EmitRuntimeIntegerAsI64(RuntimeInt integer, string prefix)
    {
        if (NumericBitWidth(integer.Type) == 64)
        {
            return integer.ValueName;
        }
        var wide = NextTemp(prefix);
        var extension = IsSignedIntegerType(integer.Type) ? "sext" : "zext";
        EmitAssign(wide, $"{extension} {LlvmType(integer.Type)} {integer.ValueName} to i64");
        return wide;
    }

    private RuntimeUnit EmitRuntimeWriteScalar(BoundFunction function, RuntimeValue value)
    {
        if (function.SpecializedType is not { } scalarType || value.Type != scalarType)
        {
            throw new SollangException($"{function.Name} has an invalid scalar specialization");
        }
        if (scalarType != BoundType.Bool && !IsNumericType(scalarType) && scalarType != BoundType.CodePoint)
        {
            throw new SollangException($"{function.Name} does not support {scalarType}");
        }

        var materialized = MaterializeAggregateValue(value);
        var slot = NextTemp("file_scalar");
        EmitAlloca(slot, materialized.TypeName, RuntimeAlignment(scalarType));
        EmitStore(materialized.TypeName, materialized.ValueName, slot, RuntimeAlignment(scalarType));

        var flushOk = NextTemp("file_scalar_flush_ok");
        EmitCall(flushOk, "i32", "sollang_flush_i64_file", "");
        var writeOk = NextTemp("file_scalar_write_ok");
        EmitCall(writeOk, "i32", "sollang_platform_write_file_bytes",
            $"ptr {slot}, i64 {RuntimeScalarByteSize(scalarType)}");
        var ok = NextTemp("file_scalar_ok");
        EmitAssign(ok, $"and i32 {flushOk}, {writeOk}");
        _mainOk = CombineWriteOk(ok, _mainOk);
        EmitReturnIfReadFailed(ok);
        return RuntimeUnit.Instance;
    }

    private RuntimeEnum EmitRuntimeWriteScalarAt(
        BoundFunction function,
        RuntimeStruct writer,
        Expression valueExpression,
        Expression offsetExpression)
    {
        if (function.SpecializedType is not { } scalarType
            || (scalarType != BoundType.Bool
                && !IsNumericType(scalarType)
                && scalarType != BoundType.CodePoint))
        {
            throw new SollangException($"{function.Name} has an invalid scalar specialization");
        }
        if (!_program.Types.TryGetResultTypes(function.ReturnType, out var resultTypes)
            || resultTypes.Ok != BoundType.Unit
            || resultTypes.Error != BoundType.Text)
        {
            throw new SollangException($"{function.Name} must return Result<Unit, Text>");
        }

        RuntimeValue value = valueExpression is NumberExpression literal && IsIntegerType(scalarType)
            ? new RuntimeInt(scalarType, literal.Text)
            : EmitExpression(valueExpression);
        EnsureRuntimeType(value, scalarType, function.Name);
        var materialized = MaterializeAggregateValue(value);
        var slot = NextTemp("file_scalar_write_at");
        EmitAlloca(slot, materialized.TypeName, RuntimeAlignment(scalarType));
        EmitStore(materialized.TypeName, materialized.ValueName, slot, RuntimeAlignment(scalarType));

        var handle = ExtractOwnedFileHandle(writer, "sys.file.FileWriter");
        var offset = EmitMapInteger(offsetExpression, BoundType.UInt64, "file_write_at_offset");
        var byteSize = RuntimeScalarByteSize(scalarType);
        var raw = NextTemp("file_scalar_write_at_result");
        EmitCall(
            raw,
            "%sollang.file_count_result",
            "sollang_platform_write_owned_file_at",
            $"i64 {handle}, ptr {slot}, i64 {byteSize}, i64 {offset}");
        var count = NextTemp("file_scalar_write_at_count");
        EmitAssign(count, $"extractvalue %sollang.file_count_result {raw}, 0");
        var platformOk = NextTemp("file_scalar_write_at_ok");
        EmitAssign(platformOk, $"extractvalue %sollang.file_count_result {raw}, 1");
        return EmitRuntimeWriteScalarResult(function, count, platformOk, byteSize);
    }

    private RuntimeEnum EmitRuntimeWriteScalarResult(
        BoundFunction function,
        string count,
        string platformOk,
        int byteSize)
    {
        var callSucceeded = NextTemp("file_scalar_write_at_call_succeeded");
        EmitCompare(callSucceeded, "ne", "i32", platformOk, "0");
        var full = NextTemp("file_scalar_write_at_full");
        EmitCompare(full, "eq", "i64", count, byteSize.ToString(CultureInfo.InvariantCulture));
        var succeeded = NextTemp("file_scalar_write_at_succeeded");
        EmitAssign(succeeded, $"and i1 {callSucceeded}, {full}");

        var definition = _program.Types.GetEnum(function.ReturnType);
        var okVariant = definition.Variants.First(variant => variant.Name == "Ok");
        var errVariant = definition.Variants.First(variant => variant.Name == "Err");
        var successLabel = NextLabel("file_write_at_success");
        var errorLabel = NextLabel("file_write_at_error");
        var endLabel = NextLabel("file_write_at_end");
        EmitConditionalBranch(succeeded, successLabel, errorLabel);

        EmitLabel(successLabel);
        _currentBlockLabel = successLabel;
        var success = EmitEnumValue(function.ReturnType, okVariant, payload: null);
        EmitBranch(endLabel);
        var successExit = _currentBlockLabel;

        EmitLabel(errorLabel);
        _currentBlockLabel = errorLabel;
        var failure = EmitEnumValue(function.ReturnType, errVariant, EmitRuntimeErrorText("io"));
        EmitBranch(endLabel);
        var errorExit = _currentBlockLabel;

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        return EmitEnumPhi(
            "file_write_at_result",
            function.ReturnType,
            [(success, successExit), (failure, errorExit)]);
    }

    private RuntimeEnum EmitRuntimeCompletedWriteScalarAt(
        BoundFunction function,
        string completedTaskControl)
    {
        if (function.SpecializedType is not { } scalarType
            || !_program.Types.TryGetResultTypes(function.ReturnType, out var resultTypes)
            || resultTypes.Ok != BoundType.Unit
            || resultTypes.Error != BoundType.Text)
        {
            throw new SollangException($"{function.Name} has an invalid completed write result");
        }
        var countSlot = NextTemp("file_async_write_count_slot");
        EmitAssign(
            countSlot,
            $"getelementptr %sollang.task_control, ptr {completedTaskControl}, i32 0, i32 14");
        var count = NextTemp("file_async_write_count");
        EmitLoad(count, "i64", countSlot, 8);
        var okSlot = NextTemp("file_async_write_ok_slot");
        EmitAssign(
            okSlot,
            $"getelementptr %sollang.task_control, ptr {completedTaskControl}, i32 0, i32 15");
        var platformOk = NextTemp("file_async_write_ok");
        EmitLoad(platformOk, "i32", okSlot, 4);
        return EmitRuntimeWriteScalarResult(
            function,
            count,
            platformOk,
            RuntimeScalarByteSize(scalarType));
    }

    private RuntimeEnum EmitRuntimeCompletedSyncFile(
        BoundFunction function,
        string completedTaskControl)
    {
        if (!_program.Types.TryGetResultTypes(function.ReturnType, out var resultTypes)
            || resultTypes.Ok != BoundType.Unit
            || resultTypes.Error != BoundType.Text)
        {
            throw new SollangException($"{function.Name} has an invalid completed sync result");
        }
        var okSlot = NextTemp("file_async_sync_ok_slot");
        EmitAssign(
            okSlot,
            $"getelementptr %sollang.task_control, ptr {completedTaskControl}, i32 0, i32 15");
        var platformOk = NextTemp("file_async_sync_ok");
        EmitLoad(platformOk, "i32", okSlot, 4);
        return EmitRuntimeWriteScalarResult(function, "0", platformOk, 0);
    }

    private RuntimeEnum EmitRuntimeReadScalar(
        BoundFunction function,
        string? completedTaskControl = null,
        RuntimeStruct? file = null,
        Expression? offsetExpression = null)
    {
        if (function.SpecializedType is not { } scalarType
            || (scalarType != BoundType.Bool && !IsNumericType(scalarType) && scalarType != BoundType.CodePoint))
        {
            throw new SollangException($"{function.Name} has an invalid scalar specialization");
        }
        if (!_program.Types.TryGetResultTypes(function.ReturnType, out var resultTypes)
            || !_program.Types.TryGetOptionValue(resultTypes.Ok, out var optionValue)
            || optionValue != scalarType)
        {
            throw new SollangException($"{function.Name} has an invalid scalar result type");
        }
        if (completedTaskControl is null && file is null && _usesAsync)
        {
            EmitCall(target: null, "void", "sollang_file_wait_idle", "");
        }

        var resultDefinition = _program.Types.GetEnum(function.ReturnType);
        var okVariant = resultDefinition.Variants.First(variant => variant.Name == "Ok");
        var errVariant = resultDefinition.Variants.First(variant => variant.Name == "Err");
        var optionDefinition = _program.Types.GetEnum(resultTypes.Ok);
        var someVariant = optionDefinition.Variants.First(variant => variant.Name == "Some");
        var noneVariant = optionDefinition.Variants.First(variant => variant.Name == "None");
        if (resultTypes.Error != BoundType.Text)
        {
            throw new SollangException($"{function.Name} requires Text errors");
        }

        var byteSize = RuntimeScalarByteSize(scalarType);
        var storageType = scalarType == BoundType.Bool ? "i8" : LlvmType(scalarType);
        string slot;
        string count;
        string readOk;
        if (completedTaskControl is null)
        {
            slot = NextTemp("file_scalar_read");
            EmitAlloca(slot, storageType, RuntimeAlignment(scalarType));
            var readResult = NextTemp("file_scalar_read_result");
            if (file is null)
            {
                EmitCall(readResult, "%sollang.file_count_result", "sollang_platform_read_file_bytes",
                    $"ptr {slot}, i64 {byteSize}");
            }
            else
            {
                var fileHandle = ExtractOwnedFileHandle(file);
                var offset = EmitMapInteger(
                    offsetExpression!,
                    BoundType.UInt64,
                    "file_read_at_offset");
                EmitCall(
                    readResult,
                    "%sollang.file_count_result",
                    "sollang_platform_read_owned_file_at",
                    $"i64 {fileHandle}, ptr {slot}, i64 {byteSize}, i64 {offset}");
            }
            count = NextTemp("file_scalar_read_count");
            EmitAssign(count, $"extractvalue %sollang.file_count_result {readResult}, 0");
            readOk = NextTemp("file_scalar_read_ok");
            EmitAssign(readOk, $"extractvalue %sollang.file_count_result {readResult}, 1");
        }
        else
        {
            slot = NextTemp("file_async_scalar_data");
            EmitAssign(
                slot,
                $"getelementptr %sollang.task_control, ptr {completedTaskControl}, i32 0, i32 13");
            var countSlot = NextTemp("file_async_scalar_count_slot");
            EmitAssign(
                countSlot,
                $"getelementptr %sollang.task_control, ptr {completedTaskControl}, i32 0, i32 14");
            count = NextTemp("file_async_scalar_count");
            EmitLoad(count, "i64", countSlot, 8);
            var okSlot = NextTemp("file_async_scalar_ok_slot");
            EmitAssign(
                okSlot,
                $"getelementptr %sollang.task_control, ptr {completedTaskControl}, i32 0, i32 15");
            readOk = NextTemp("file_async_scalar_ok");
            EmitLoad(readOk, "i32", okSlot, 4);
        }

        var ioLabel = NextLabel("file_scalar_io");
        var countLabel = NextLabel("file_scalar_count");
        var eofLabel = NextLabel("file_scalar_eof");
        var nonEofLabel = NextLabel("file_scalar_non_eof");
        var fullLabel = NextLabel("file_scalar_full");
        var truncatedLabel = NextLabel("file_scalar_truncated");
        var invalidLabel = NextLabel("file_scalar_invalid");
        var validLabel = NextLabel("file_scalar_valid");
        var endLabel = NextLabel("file_scalar_end");
        var incoming = new List<(RuntimeValue Value, string Label)>();
        var isReadOk = NextTemp("file_scalar_is_read_ok");
        EmitCompare(isReadOk, "ne", "i32", readOk, "0");
        EmitConditionalBranch(isReadOk, countLabel, ioLabel);

        EmitLabel(ioLabel);
        _currentBlockLabel = ioLabel;
        var ioError = EmitRuntimeErrorText("io");
        incoming.Add((EmitEnumValue(function.ReturnType, errVariant, ioError), _currentBlockLabel));
        EmitBranch(endLabel);

        EmitLabel(countLabel);
        _currentBlockLabel = countLabel;
        var isEof = NextTemp("file_scalar_is_eof");
        EmitCompare(isEof, "eq", "i64", count, "0");
        EmitConditionalBranch(isEof, eofLabel, nonEofLabel);

        EmitLabel(eofLabel);
        _currentBlockLabel = eofLabel;
        var none = EmitEnumValue(resultTypes.Ok, noneVariant, null);
        incoming.Add((EmitEnumValue(function.ReturnType, okVariant, none), _currentBlockLabel));
        EmitBranch(endLabel);

        EmitLabel(nonEofLabel);
        _currentBlockLabel = nonEofLabel;
        var isFull = NextTemp("file_scalar_is_full");
        EmitCompare(isFull, "eq", "i64", count, byteSize.ToString(CultureInfo.InvariantCulture));
        EmitConditionalBranch(isFull, fullLabel, truncatedLabel);

        EmitLabel(truncatedLabel);
        _currentBlockLabel = truncatedLabel;
        var truncatedError = EmitRuntimeErrorText("truncated");
        incoming.Add((EmitEnumValue(function.ReturnType, errVariant, truncatedError), _currentBlockLabel));
        EmitBranch(endLabel);

        EmitLabel(fullLabel);
        _currentBlockLabel = fullLabel;
        var loaded = NextTemp("file_scalar_loaded");
        EmitLoad(loaded, storageType, slot, RuntimeAlignment(scalarType));
        string? encodingValid = null;
        if (scalarType == BoundType.Bool)
        {
            encodingValid = NextTemp("file_bool_valid");
            EmitCompare(encodingValid, "ule", "i8", loaded, "1");
        }
        else if (scalarType == BoundType.CodePoint)
        {
            var withinRange = NextTemp("file_codepoint_range");
            EmitCompare(withinRange, "ule", "i32", loaded, "1114111");
            var belowSurrogate = NextTemp("file_codepoint_below_surrogate");
            EmitCompare(belowSurrogate, "ult", "i32", loaded, "55296");
            var aboveSurrogate = NextTemp("file_codepoint_above_surrogate");
            EmitCompare(aboveSurrogate, "ugt", "i32", loaded, "57343");
            var outsideSurrogate = NextTemp("file_codepoint_outside_surrogate");
            EmitAssign(outsideSurrogate, $"or i1 {belowSurrogate}, {aboveSurrogate}");
            encodingValid = NextTemp("file_codepoint_valid");
            EmitAssign(encodingValid, $"and i1 {withinRange}, {outsideSurrogate}");
        }
        if (encodingValid is not null)
        {
            EmitConditionalBranch(encodingValid, validLabel, invalidLabel);
        }
        else
        {
            EmitBranch(validLabel);
        }

        EmitLabel(invalidLabel);
        _currentBlockLabel = invalidLabel;
        var invalidError = EmitRuntimeErrorText("invalid");
        incoming.Add((EmitEnumValue(function.ReturnType, errVariant, invalidError), _currentBlockLabel));
        EmitBranch(endLabel);

        EmitLabel(validLabel);
        _currentBlockLabel = validLabel;
        RuntimeValue scalar = scalarType switch
        {
            BoundType.Bool => new RuntimeBool(EmitBoolFromByte(loaded)),
            BoundType.Float32 or BoundType.Float64 => new RuntimeFloat(scalarType, loaded),
            _ => new RuntimeInt(scalarType, loaded)
        };
        var some = EmitEnumValue(resultTypes.Ok, someVariant, scalar);
        incoming.Add((EmitEnumValue(function.ReturnType, okVariant, some), _currentBlockLabel));
        EmitBranch(endLabel);

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        return EmitEnumPhi("file_scalar_result", function.ReturnType, incoming);
    }

    private string EmitBoolFromByte(string value)
    {
        var result = NextTemp("file_bool");
        EmitCompare(result, "ne", "i8", value, "0");
        return result;
    }

    private RuntimeText EmitRuntimeErrorText(string text)
    {
        var global = AddGlobalString(text);
        return new RuntimeText(global.Name, global.Length.ToString(CultureInfo.InvariantCulture));
    }

    private int RuntimeScalarByteSize(BoundType type) => type switch
    {
        BoundType.Bool or BoundType.Int8 or BoundType.UInt8 => 1,
        BoundType.Int16 or BoundType.UInt16 => 2,
        BoundType.Int or BoundType.UInt32 or BoundType.Float32 or BoundType.CodePoint => 4,
        BoundType.Int64 or BoundType.UInt64 or BoundType.Float64 => 8,
        BoundType.Size or BoundType.UIntSize => _platform.PointerBitWidth / 8,
        _ => throw new SollangException($"{type} is not a binary scalar")
    };

}

