using System.Globalization;
using System.Text;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Semantics;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private void EmitMain()
    {
        ClearLocalState();
        _currentFunctions = _program.Functions;
        _currentStackFramePlan = _program.MainStackFrame;
        _mainOk = "true";
        _currentBlockLabel = "entry";
        EmitFunctionLine($"define dso_local i32 @{_platform.EntryPointName}({_platform.EntryPointParameters}) local_unnamed_addr {{");
        EmitLabel("entry");
        EmitStackFrameAllocations();
        EmitAlloca("%written", "i32", 4);
        EmitAlloca("%read", "i32", 4);
        EmitAlloca("%ok_state", "i1", 1);
        EmitStore("i1", "true", "%ok_state", 1);
        EmitPlatformFunctionBlock(_platform.EmitEntryHandles);
        EmitNativeBinding();
        EmitComBinding();
        if (_usesProcessArguments)
        {
            EmitPlatformFunctionBlock(_platform.EmitProcessEntry);
        }

        EmitStatements(_program.MainStatements);

        DropOwnedLocals();
        if (_usesAsync)
        {
            EmitCall(target: null, "void", "sollang_async_shutdown", "");
        }
        if (_usesParallel)
        {
            EmitCall(target: null, "void", "sollang_compute_shutdown", "");
        }
        if (_usesProcessEnvironment)
        {
            EmitPlatformFunctionBlock(_platform.EmitEnvironmentCleanup);
        }
        if (_usesProcessArguments)
        {
            EmitPlatformFunctionBlock(_platform.EmitExitCleanup);
        }
        EmitNativeCleanup();
        EmitComCleanup();
        EmitPlatformFunctionBlock(_platform.EmitExitHandles);

        var finalOk = NextTemp("final_ok");
        EmitLoad(finalOk, "i1", "%ok_state", 1);
        var exit = NextTemp("exit");
        EmitSelect(exit, finalOk, "i32 0", "i32 1");
        EmitRet("i32", exit);
        EmitFunctionLine("}");
        EmitFunctionLine();
    }

    private sealed record StatementContinuation(
        BoundFunction? Function,
        IReadOnlyList<Statement> Statements,
        int Start,
        Expression? Result)
    {
        public Dictionary<string, bool> OwnerReads { get; } = new(StringComparer.Ordinal);
    }

    private readonly Stack<StatementContinuation> _statementContinuations = [];

    private void EmitStatements(IReadOnlyList<Statement> statements, Expression? result = null)
    {
        if (result is null && ReferenceEquals(statements, _currentFunction?.BlockBody))
            result = _currentFunction?.Body;
        for (var index = 0; index < statements.Count && !_currentBlockTerminated; index++)
        {
            _statementContinuations.Push(new StatementContinuation(
                _currentFunction, statements, index + 1, result));
            try { EmitStatement(statements[index]); }
            finally { _statementContinuations.Pop(); }
        }
    }

    private bool OwnerReadInContinuation(string name)
    {
        Expression? child = null;
        foreach (var (function, parent) in _expressionContinuations)
        {
            if (!ReferenceEquals(function, _currentFunction))
            {
                child = null;
                continue;
            }
            if (child is not null && !ReferenceEquals(child, parent))
            {
                var children = parent switch
                {
                    FlowExpression flow => new[] { flow.Source }.Concat(
                        flow.Targets.SelectMany(static target => target.Arguments)),
                    CallExpression call => call.Arguments,
                    _ => ExpressionChildren(parent)
                };
                var reachedChild = false;
                foreach (var expression in children)
                {
                    if (reachedChild && StoragePlacementAnalyzer.ReferencesName(expression, name))
                        return true;
                    reachedChild |= ReferenceEquals(expression, child);
                }
            }
            child = parent;
        }
        foreach (var continuation in _statementContinuations)
        {
            if (!ReferenceEquals(continuation.Function, _currentFunction))
                continue;
            if (!continuation.OwnerReads.TryGetValue(name, out var read))
            {
                var shadowed = false;
                for (var index = continuation.Start; index < continuation.Statements.Count; index++)
                {
                    var statement = continuation.Statements[index];
                    if (StoragePlacementAnalyzer.ReferencesName(statement, name))
                    {
                        read = true;
                        break;
                    }
                    if (statement is BindingStatement binding && binding.Name == name)
                    {
                        shadowed = true;
                        break;
                    }
                }
                read |= !shadowed && continuation.Result is not null
                    && StoragePlacementAnalyzer.ReferencesName(continuation.Result, name);
                continuation.OwnerReads[name] = read;
            }
            if (read) return true;
        }
        return false;
    }

    private void EmitStatement(Statement statement)
    {
        if (_program.DeferredStreamDeclarations.Contains(statement))
        {
            return;
        }
        if (_program.DeferredStreamConsumers.TryGetValue(statement, out var expandedStream))
        {
            EmitBlockFunctionPipeline(expandedStream);
            EmitStackLifetimeEndsAfter(statement);
            return;
        }
        if (_program.EventStreamConsumers.TryGetValue(statement, out var runtimeStream))
        {
            EmitRuntimeProducerPipeline(runtimeStream);
            EmitStackLifetimeEndsAfter(statement);
            return;
        }
        if (_program.PartitionConsumers.TryGetValue(statement, out var partition))
        {
            EmitPartitionPipeline(partition);
            EmitStackLifetimeEndsAfter(statement);
            return;
        }
        if (_program.StreamJoinConsumers.TryGetValue(statement, out var join))
        {
            EmitStreamJoinPipeline(join);
            EmitStackLifetimeEndsAfter(statement);
            return;
        }

        if (statement is ExpressionStatement cfgYield && TryEmitCfgYieldStatement(cfgYield))
        {
            EmitStackLifetimeEndsAfter(statement);
            return;
        }
        if (statement is ExpressionStatement cfgAwaitExpression
            && TryEmitCfgAwaitExpressionStatement(cfgAwaitExpression))
        {
            EmitStackLifetimeEndsAfter(statement);
            return;
        }
        if (statement is BindingStatement cfgAwait && TryEmitCfgAwaitBinding(cfgAwait))
        {
            EmitStackLifetimeEndsAfter(statement);
            return;
        }

        switch (statement)
        {
            case BindingStatement binding:
                string? movedSourceName = GetMoveConsumingContainerSourceName(binding.Value)
                    ?? (binding.Value is NameExpression directOwnedSource
                        && _locals.TryGetValue(directOwnedSource.Name, out var directOwnedValue)
                        && IsOwnedContainerRuntimeValue(directOwnedValue)
                            ? directOwnedSource.Name
                            : null);
                var value = binding.IsMutable
                    && _locals.TryGetValue(binding.Name, out var reboundLocal)
                        ? EmitFunctionArgumentExpression(binding.Value, reboundLocal.Type)
                        : EmitExpression(binding.Value);
                var copiesFixedStorage = CopiesFixedStorageField(binding.Value, value.Type);
                if (copiesFixedStorage)
                {
                    value = CopyFixedStorageValue(value);
                    movedSourceName = null;
                }
                var movedOwnedField = copiesFixedStorage
                    ? null
                    : GetMoveConsumingOwnedField(binding.Value, value);
                if (binding.IsMutable
                    && _mutableScalarSlots.TryGetValue(binding.Name, out var reboundPointer))
                {
                    var previous = _locals[binding.Name];
                    EnsureRuntimeType(value, previous.Type, binding.Name);
                    var reboundValue = MaterializeAggregateValue(value);
                    EmitStore(reboundValue.TypeName, reboundValue.ValueName, reboundPointer,
                        RuntimeAlignment(value.Type));
                    break;
                }
                if (binding.IsMutable
                    && _mutableStructSlots.TryGetValue(binding.Name, out reboundPointer))
                {
                    var previous = _locals[binding.Name];
                    EnsureRuntimeType(value, previous.Type, binding.Name);
                    var reboundValue = MaterializeAggregateValue(value);
                    EmitStore(reboundValue.TypeName, reboundValue.ValueName, reboundPointer,
                        RuntimeAlignment(value.Type));
                    break;
                }
                if (RequiresHeapAllocation(value) && !_platform.SupportsHeapAllocation)
                {
                    throw new SollangException("dynamic arrays and dictionaries require heap allocation; wasm32-browser does not support them yet");
                }

                if (movedSourceName is not null)
                {
                    RemoveLocal(movedSourceName);
                }
                if (movedOwnedField is not null)
                {
                    MarkMovedOwnedStructField(
                        movedOwnedField.Value.OwnerName,
                        movedOwnedField.Value.FieldPath);
                }
                // A direct field extracted from `move self` leaves a partially
                // live aggregate.  Its exact moved-field mask replaces the
                // generic aggregate-literal transfer path, which consumes the
                // complete projected owner.
                if (movedOwnedField is null && !copiesFixedStorage)
                {
                    RemoveOwnedLiteralSources(binding.Value, value.Type);
                }

                ClearShadowedLocalBinding(binding.Name);
                _locals.Add(binding.Name, value);
                if (binding.IsMutable)
                {
                    _mutableLocals.Add(binding.Name);
                    if (value is RuntimeStruct structure)
                    {
                        CreateMutableStructSlot(binding.Name, structure);
                    }
                    else
                    {
                        CreateMutableContainerSlot(binding, value);
                    }
                }
                break;
            case IndexAssignmentStatement assignment:
                EmitIndexAssignmentStatement(assignment);
                break;
            case FieldAssignmentStatement assignment:
                EmitFieldAssignmentStatement(assignment);
                break;
            case BlockFunctionCallStatement blockFunctionCall:
                EmitBlockFunctionCall(blockFunctionCall);
                break;
            case BlockFunctionPipelineStatement pipeline:
                EmitBlockFunctionPipeline(pipeline);
                break;
            case LoopControlStatement loopControl:
                EmitLoopControlStatement(loopControl);
                return;
            case GuardLoopControlStatement guardLoopControl:
                EmitGuardLoopControlStatement(guardLoopControl);
                break;
            case StreamStopStatement:
                if (_currentStreamCancellationSlot is null)
                {
                    throw new SollangException("'stop' requires an active stream pipeline");
                }
                EmitStore("i1", "true", ResolveAsyncStreamCancellationSlot(_currentStreamCancellationSlot), 1);
                break;
            case ReturnStatement returnStatement:
                EmitReturnStatement(returnStatement);
                return;
            case ExpressionStatement expressionStatement:
                _mainOk = EmitExpressionStatement(expressionStatement.Expression, _mainOk);
                break;
            default:
                throw new SollangException($"unsupported runtime statement {statement.GetType().Name}");
        }

        EmitStackLifetimeEndsAfter(statement);
    }

    private void EmitLoopControlStatement(LoopControlStatement statement)
    {
        if (!_loopContexts.TryPeek(out var loop))
        {
            throw new SollangException($"'{statement.Kind.ToString().ToLowerInvariant()}' is only valid inside a loop");
        }

        MergeOwnedStructFieldMoves(loop.OuterScope, [(CaptureLocals(), _currentBlockLabel)], requireEntryMask: true);
        var callbackDroppedBindings = new List<(LocalScope Scope, string Name)>();
        DropOwnedLocalsCreatedSince(loop.OuterScope, transferredOwnerName: null,
            droppedBindings: callbackDroppedBindings);
        DropAbandonedCallbackProducerScopes(loop, callbackDroppedBindings);
        var edges = statement.Kind == LoopControlKind.Break
            ? loop.BreakEdges
            : loop.ContinueEdges;
        edges?.Add((CaptureLocals(), _currentBlockLabel));
        loop.CaptureContinuationEdge?.Invoke(statement.Kind, _currentBlockLabel);
        EmitBranch(statement.Kind == LoopControlKind.Break ? loop.BreakLabel : loop.ContinueLabel);
    }

    private void EmitReturnStatement(ReturnStatement statement)
    {
        var function = _currentFunction
            ?? throw new SollangException("'return' is only valid inside a function");
        if (statement.Value is null)
        {
            if (function.ReturnType != BoundType.Unit)
            {
                throw new SollangException($"return requires {function.ReturnType} but received Unit");
            }

            DropOwnedLocals();
            EmitRet("void", string.Empty);
            return;
        }

        if (_program.Types.IsReference(function.ReturnType))
        {
            var reference = EmitReferencePlace(statement.Value, function.ReturnType);
            DropOwnedLocals();
            EmitRet("ptr", reference.PointerName);
            return;
        }

        var value = _program.Types.IsSlice(function.ReturnType)
            && statement.Value is ArrayLiteralExpression literal
            && ArrayLiteralStorageFacts.HasStaticReadonlyBacking(literal)
                ? EmitReadonlyStaticArrayLiteral(literal, function.ReturnType)
                : EmitFunctionArgumentExpression(statement.Value, function.ReturnType);
        if (function.ReturnType == BoundType.Unit)
        {
            EnsureRuntimeType(value, BoundType.Unit, function.Name);
            DropOwnedLocals();
            EmitRet("void", string.Empty);
            return;
        }

        value = PrepareBorrowedFixedStorageReturn(statement.Value, value);
        EnsureRuntimeType(value, function.ReturnType, function.Name);
        var transferredOwnerName = IsOwnedContainerRuntimeValue(value)
            ? GetFunctionResultTransferredOwnerName(function, statement.Value)
            : null;
        DropOwnedLocals(transferredOwnerName, statement.Value);
        var materialized = MaterializeAggregateValue(value);
        EmitRet(materialized.TypeName, materialized.ValueName);
    }

    private void EmitGuardLoopControlStatement(GuardLoopControlStatement statement)
    {
        if (!_loopContexts.TryPeek(out var loop))
        {
            throw new SollangException(
                $"'{statement.Kind.ToString().ToLowerInvariant()}' guard is only valid inside a loop");
        }

        var condition = EmitBoolExpression(statement.Condition);
        var exitLabel = NextLabel("guard_exit");
        var nextLabel = NextLabel("guard_next");
        EmitConditionalBranch(condition.ValueName, exitLabel, nextLabel);

        EmitLabel(exitLabel);
        _currentBlockLabel = exitLabel;
        MergeOwnedStructFieldMoves(loop.OuterScope, [(CaptureLocals(), _currentBlockLabel)], requireEntryMask: true);
        var callbackDroppedBindings = new List<(LocalScope Scope, string Name)>();
        DropOwnedLocalsCreatedSince(loop.OuterScope, transferredOwnerName: null,
            droppedBindings: callbackDroppedBindings);
        DropAbandonedCallbackProducerScopes(loop, callbackDroppedBindings);
        var edges = statement.Kind == LoopControlKind.Break
            ? loop.BreakEdges
            : loop.ContinueEdges;
        edges?.Add((CaptureLocals(), _currentBlockLabel));
        loop.CaptureContinuationEdge?.Invoke(statement.Kind, _currentBlockLabel);
        EmitBranch(statement.Kind == LoopControlKind.Break ? loop.BreakLabel : loop.ContinueLabel);

        EmitLabel(nextLabel);
        _currentBlockLabel = nextLabel;
    }

    private void EmitLoopBody(
        IReadOnlyList<Statement> statements,
        LocalScope outerScope,
        string continueLabel,
        string breakLabel,
        List<(LocalScope Scope, string Label)>? continueEdges = null,
        List<(LocalScope Scope, string Label)>? breakEdges = null,
        Action? emitBody = null,
        Action<LoopControlKind, string>? captureContinuationEdge = null)
    {
        _loopContexts.Push(new LoopContext(
            continueLabel,
            breakLabel,
            outerScope,
            continueEdges,
            breakEdges,
            captureContinuationEdge));
        try
        {
            if (emitBody is null)
                EmitStatements(statements);
            else
                emitBody();
            if (!_currentBlockTerminated)
            {
                MergeOwnedStructFieldMoves(outerScope, [(CaptureLocals(), _currentBlockLabel)], requireEntryMask: true);
                DropOwnedLocalsCreatedSince(outerScope, transferredOwnerName: null);
            }
            if (!_currentBlockTerminated && _currentStreamCancellationSlot is { } cancellationSlot)
            {
                var cancelled = NextTemp("stream_cancelled");
                EmitLoad(cancelled, "i1", ResolveAsyncStreamCancellationSlot(cancellationSlot), 1);
                var cancelLabel = NextLabel("stream_cancel");
                var keepRunningLabel = NextLabel("stream_continue");
                EmitConditionalBranch(cancelled, cancelLabel, keepRunningLabel);

                EmitLabel(cancelLabel);
                _currentBlockLabel = cancelLabel;
                breakEdges?.Add((CaptureLocals(), cancelLabel));
                captureContinuationEdge?.Invoke(LoopControlKind.Break, cancelLabel);
                EmitBranch(breakLabel);

                EmitLabel(keepRunningLabel);
                _currentBlockLabel = keepRunningLabel;
            }
        }
        finally
        {
            _loopContexts.Pop();
        }
    }

    private void CreateMutableStructSlot(string name, RuntimeStruct value)
    {
        var pointer = NextTemp("mutable_struct_slot");
        var llvmType = LlvmStructType(value.Type);
        EmitAlloca(pointer, llvmType, 8);
        EmitStore(llvmType, value.ValueName, pointer, 8);
        _mutableStructSlots.Add(name, pointer);
    }

    private void EmitFieldAssignmentStatement(FieldAssignmentStatement assignment)
    {
        if (!_mutableStructSlots.TryGetValue(assignment.Name, out var pointer))
        {
            throw new SollangException(
                $"field assignment requires a mutable struct owner; use '{assignment.Name.TrimEnd('!')}!'");
        }

        var type = _locals[assignment.Name].Type;
        var definition = _program.Types.GetStruct(type);
        var field = definition.Fields.First(candidate => candidate.Name == assignment.FieldName);
        var movedSourceName = GetMoveConsumingContainerSourceName(assignment.Value);
        var structFieldSourceNames = GetOwnedStructFieldSourceNames(assignment.Value);
        var directOwnedSourceName = _program.Types.ContainsOwnedStorage(field.Type)
            && assignment.Value is NameExpression sourceName
            && _locals.TryGetValue(sourceName.Name, out var sourceValue)
            && sourceValue.Type == field.Type
                ? sourceName.Name
                : null;
        var value = EmitFunctionArgumentExpression(assignment.Value, field.Type);
        EnsureRuntimeType(value, field.Type, $"{definition.Name}.{field.Name}");
        var fieldAddress = NextTemp("field_addr");
        EmitAssign(
            fieldAddress,
            $"getelementptr inbounds {LlvmStructType(type)}, ptr {pointer}, i32 0, i32 {field.Index.ToString(CultureInfo.InvariantCulture)}");
        if (_program.Types.ContainsOwnedStorage(field.Type))
        {
            if (!IsMovedOwnedStructField(assignment.Name, field.Name))
            {
                var previous = NextTemp("field_previous");
                EmitLoad(previous, LlvmType(field.Type), fieldAddress, RuntimeAlignment(field.Type));
                DropOwnedRuntimeValue(DematerializeAggregateValue(field.Type, previous));
            }
        }
        var materialized = MaterializeAggregateValue(value);
        EmitStore(materialized.TypeName, materialized.ValueName, fieldAddress, RuntimeAlignment(field.Type));
        RepairMovedOwnedStructField(assignment.Name, field.Name);
        if (movedSourceName is not null)
        {
            RemoveLocal(movedSourceName);
        }
        if (directOwnedSourceName is not null)
        {
            RemoveLocal(directOwnedSourceName);
        }
        foreach (var transferredName in structFieldSourceNames)
        {
            RemoveLocal(transferredName);
        }
    }

    private void EmitIndexAssignmentStatement(IndexAssignmentStatement assignment)
    {
        if (!_mutableLocals.Contains(assignment.Name))
        {
            throw new SollangException($"indexed assignment requires a mutable owner binding; use '=> {assignment.Name.TrimEnd('!')}!'");
        }

        var target = ResolveLocal(assignment.Name);
        if (target is RuntimeMappedBytes mapped)
        {
            var mappedValue = EmitFunctionArgumentExpression(assignment.Value, BoundType.UInt8) as RuntimeInt
                ?? throw new SollangException("mapped byte assignment expects an integer runtime value");
            EnsureRuntimeType(mappedValue, BoundType.UInt8, "mapped byte assignment");
            EmitMappedStore(mapped, assignment.Index, mappedValue);
            return;
        }
        var movedSourceName = GetMoveConsumingContainerSourceName(assignment.Value);
        var structFieldSourceNames = GetOwnedStructFieldSourceNames(assignment.Value);
        var expectedValueType = target switch
        {
            RuntimeStaticInlineArray array => array.ElementType,
            RuntimeDynamicInlineArray array => array.ElementType,
            RuntimeInlineDictionary dictionary => dictionary.ValueType,
            _ => (BoundType?)null
        };
        var directOwnedSourceName = assignment.Value is NameExpression sourceName
            && _locals.TryGetValue(sourceName.Name, out var sourceValue)
            && expectedValueType == sourceValue.Type
            && _program.Types.ContainsOwnedStorage(sourceValue.Type)
                ? sourceName.Name
                : null;
        var value = expectedValueType is { } contextualValueType
            ? EmitFunctionArgumentExpression(assignment.Value, contextualValueType)
            : EmitExpression(assignment.Value);
        switch (target)
        {
            case RuntimeStaticIntArray array:
                var staticIndex = EmitIntExpression(assignment.Index);
                EmitStaticArrayAssign(array, EmitIntAsSize(staticIndex, "assignment_index"), ((RuntimeInt)value).ValueName);
                return;
            case RuntimeStaticInlineArray array:
                var staticInlineIndex = EmitIntExpression(assignment.Index);
                EnsureRuntimeType(value, array.ElementType, "array indexed assignment");
                EmitStaticInlineArrayAssign(
                    array,
                    EmitIntAsSize(staticInlineIndex, "assignment_index"),
                    value);
                if (movedSourceName is not null)
                {
                    RemoveLocal(movedSourceName);
                }
                if (directOwnedSourceName is not null)
                {
                    RemoveLocal(directOwnedSourceName);
                }
                foreach (var transferredName in structFieldSourceNames)
                {
                    RemoveLocal(transferredName);
                }
                return;
            case RuntimeDynamicIntArray array:
                var dynamicIndex = EmitIntExpression(assignment.Index);
                EmitDynamicArrayAssign(array, EmitIntAsSize(dynamicIndex, "assignment_index"), ((RuntimeInt)value).ValueName);
                return;
            case RuntimeDynamicInlineArray array:
                var inlineIndex = EmitIntExpression(assignment.Index);
                EnsureRuntimeType(value, array.ElementType, "array indexed assignment");
                EmitDynamicInlineArrayAssign(array, EmitIntAsSize(inlineIndex, "assignment_index"), value);
                if (movedSourceName is not null)
                {
                    RemoveLocal(movedSourceName);
                }
                if (directOwnedSourceName is not null)
                {
                    RemoveLocal(directOwnedSourceName);
                }
                foreach (var transferredName in structFieldSourceNames)
                {
                    RemoveLocal(transferredName);
                }
                return;
            case RuntimeIntDictionary dictionary:
                var dictionaryIndex = EmitIntExpression(assignment.Index);
                EmitDictionaryAssignExisting(dictionary, dictionaryIndex.ValueName, ((RuntimeInt)value).ValueName);
                return;
            case RuntimeInlineDictionary dictionary:
                var inlineDictionaryKey = assignment.Index is DictionaryLiteralExpression contextualKey
                    && _program.Types.IsStruct(dictionary.KeyType)
                        ? EmitContextualStructLiteral(contextualKey, dictionary.KeyType)
                        : EmitExpression(assignment.Index);
                EnsureRuntimeType(inlineDictionaryKey, dictionary.KeyType, "dictionary indexed assignment key");
                EnsureRuntimeType(value, dictionary.ValueType, "dictionary indexed assignment value");
                EmitInlineDictionaryAssignExisting(dictionary, inlineDictionaryKey, value);
                if (movedSourceName is not null)
                {
                    RemoveLocal(movedSourceName);
                }
                if (directOwnedSourceName is not null)
                {
                    RemoveLocal(directOwnedSourceName);
                }
                foreach (var transferredName in structFieldSourceNames)
                {
                    RemoveLocal(transferredName);
                }
                return;
            default:
                throw new SollangException(
                    $"indexed assignment to '{assignment.Name}' expects an array or dictionary owner, " +
                    $"but code generation resolved '{target.GetType().Name}' for type id {(int)target.Type} " +
                    $"(static-array={_program.Types.IsStaticArray(target.Type)}, function={_currentFunction?.Name}, " +
                    $"struct={(_program.Types.IsStruct(target.Type) ? _program.Types.GetStruct(target.Type).Name : "none")}, " +
                    $"input={_currentFunction?.InputName}, ownership={_currentFunction?.InputOwnership}) " +
                    $"at {assignment.Line}:{assignment.Column}");
        }
    }

    private (string OwnerName, string FieldPath)? GetMoveConsumingOwnedField(
        Expression expression,
        RuntimeValue value)
    {
        if (!TryGetOwnedFieldProjection(expression, out var ownerName, out var fieldPath)
            || !_locals.TryGetValue(ownerName, out var ownerValue)
            || ownerValue is not RuntimeStruct
            || _borrowedOwnedLocals.Contains(ownerName)
            || !_program.Types.ContainsOwnedStorage(value.Type))
        {
            return null;
        }

        return (ownerName, string.Join('.', fieldPath));
    }

    private void EmitBlockFunctionCall(BlockFunctionCallStatement statement)
    {
        var target = string.Join('.', statement.Target);
        switch (target)
        {
            case "each":
                EmitArrayEachBlockFunctionCall(statement);
                return;
            case "eachKey":
                EmitDictionaryEachBlockFunctionCall(statement, bindKey: true);
                return;
            case "eachValue":
                EmitDictionaryEachBlockFunctionCall(statement, bindKey: false);
                return;
            case "repeat":
                EmitRepeatBlockFunctionCall(statement);
                return;
            case "while":
                EmitWhileBlockFunctionCall(statement);
                return;
            default:
                var resolvedGeneric = _program.ResolvedGenericCalls.TryGetValue(statement, out var function);
                if ((resolvedGeneric || TryResolveFunction(statement.Target, out function))
                    && function is { Kind: BoundFunctionKind.RuntimeParallel })
                {
                    EmitParallelBlockFunctionCall(statement, function);
                    return;
                }
                if ((resolvedGeneric || TryResolveFunction(statement.Target, out function))
                    && function is { Kind: BoundFunctionKind.RuntimeTryParallel })
                {
                    EmitTryParallelBlockFunctionCall(statement, function);
                    return;
                }
                if ((resolvedGeneric || TryResolveFunction(statement.Target, out function))
                    && function is { Kind: BoundFunctionKind.UserBlock })
                {
                    EmitUserBlockFunctionCall(statement, function);
                    return;
                }

                throw new SollangException($"unknown block function '{target}'");
        }
    }

    private void EmitBlockFunctionPipeline(BlockFunctionPipelineStatement pipeline)
    {
        var firstCall = pipeline.Calls[0];
        if ((_program.ResolvedGenericCalls.TryGetValue(firstCall.ResolutionSite, out var firstFunction)
                || TryResolveFunction(firstCall.Target, out firstFunction))
            && firstFunction.StreamElementType is not null)
        {
            EmitStreamingPipeline(pipeline, firstFunction);
            return;
        }

        foreach (var call in pipeline.Calls)
        {
            EmitBlockFunctionCall(call);
        }
    }

    private void EmitStreamingPipeline(
        BlockFunctionPipelineStatement pipeline,
        BoundFunction firstFunction)
    {
        var previousCancellationSlot = _currentStreamCancellationSlot;
        var cancellationSlot = NextTemp("stream_cancelled");
        EmitAlloca(cancellationSlot, "i1", 1);
        EmitStore("i1", "false", cancellationSlot, 1);
        RegisterAsyncStreamCancellationSlot(cancellationSlot);
        _currentStreamCancellationSlot = cancellationSlot;

        var callSite = new RuntimeStreamCallSite(
            CaptureLocals(), _currentFunctions, _currentFunction, _asyncScopeSnapshots.ToArray(),
            CaptureCallbackLoopAuthority());
        var lastCall = pipeline.Calls[^1];
        RuntimeStreamSink sink;
        if (string.Join('.', lastCall.Target) == "each")
        {
            sink = new RuntimeStreamConsumer(new RuntimeBlockInvocation(
                lastCall.ItemName,
                [],
                lastCall.Body,
                CaptureLocals(),
                _currentFunctions,
                _currentFunction,
                BoundType.Unit,
                OwnsItem: true,
                CallerAsyncScopes: callSite.AsyncScopes,
                LoopAuthority: callSite.LoopAuthority));
        }
        else
        {
            if (!(_program.ResolvedGenericCalls.TryGetValue(lastCall.ResolutionSite, out var terminalFunction)
                    || TryResolveFunction(lastCall.Target, out terminalFunction))
                || terminalFunction.Kind != BoundFunctionKind.UserBlock
                || terminalFunction.ReturnType != BoundType.Unit)
            {
                throw new SollangException("a streaming pipeline must end with each or a Unit block function");
            }
            var terminalArguments = (lastCall.Arguments ?? []).Select(EmitExpression).ToArray();
            sink = new RuntimeStreamTerminalStage(lastCall, terminalFunction, callSite, terminalArguments);
        }

        for (var index = pipeline.Calls.Count - 2; index >= 1; index--)
        {
            var call = pipeline.Calls[index];
            if (!(_program.ResolvedGenericCalls.TryGetValue(call.ResolutionSite, out var function)
                    || TryResolveFunction(call.Target, out function))
                || function.StreamElementType is null)
            {
                throw new SollangException("a streaming pipeline may contain only stream functions before its final each");
            }
            var arguments = (call.Arguments ?? []).Select(EmitExpression).ToArray();
            if ((function.Kind == BoundFunctionKind.User
                    && function.BlockInputType is null)
                || function.BlockBody.Any(static statement =>
                    statement is BindingStatement { IsStreamState: true }))
            {
                sink = CreateUserStreamStage(call, function, sink, callSite, arguments, cancellationSlot);
            }
            else
            {
                sink = new RuntimeStreamStage(call, function, sink, callSite, arguments);
            }
        }

        try
        {
            EmitUserBlockFunctionCall(
                firstCall: pipeline.Calls[0] with { ResultName = null, ResultIsSynthetic = false },
                function: firstFunction,
                continuation: sink);
        }
        finally
        {
            UnregisterAsyncStreamCancellationSlot(cancellationSlot);
            _currentStreamCancellationSlot = previousCancellationSlot;
        }
    }

    private void EmitRuntimeProducerPipeline(BoundEventStreamPipeline pipeline)
    {
        var source = EmitExpression(pipeline.Source) as RuntimeProducerStream
            ?? throw new SollangException("runtime Stream<T> source did not produce a producer handle");
        if (source.ElementType != pipeline.SourceElementType || source.IsEvent != pipeline.IsEvent)
        {
            throw new SollangException("runtime Stream<T> producer ABI type mismatch");
        }
        if (pipeline.Source is NameExpression sourceName)
        {
            RemoveLocal(sourceName.Name);
        }

        var previousCancellationSlot = _currentStreamCancellationSlot;
        var cancellationSlot = NextTemp("stream_cancelled");
        EmitAlloca(cancellationSlot, "i1", 1);
        EmitStore("i1", "false", cancellationSlot, 1);
        RegisterAsyncStreamCancellationSlot(cancellationSlot);
        _currentStreamCancellationSlot = cancellationSlot;

        var sink = BuildRuntimeStreamSink(pipeline.Calls, cancellationSlot);

        if (HasAsyncStreamSuspension(sink))
        {
            EmitAsyncProducerLoop([source], sink, cancellationSlot);
            UnregisterAsyncStreamCancellationSlot(cancellationSlot);
            _currentStreamCancellationSlot = previousCancellationSlot;
            return;
        }

        var elementType = LlvmType(source.ElementType);
        var elementAddress = NextTemp("stream_element_address");
        EmitAlloca(elementAddress, elementType, RuntimeAlignment(source.ElementType));
        var nextLabel = NextLabel("stream_next");
        var valueLabel = NextLabel("stream_value");
        var continueLabel = NextLabel("stream_continue");
        var doneLabel = NextLabel("stream_done");
        EmitBranch(nextLabel);
        EmitFunctionLine();
        EmitLabel(nextLabel);
        var hasValue = NextTemp("stream_has_value");
        EmitIndirectCall(
            hasValue,
            "i1",
            source.NextName,
            $"ptr {source.ContextName}, ptr {elementAddress}");
        EmitConditionalBranch(hasValue, valueLabel, doneLabel);
        EmitFunctionLine();
        EmitLabel(valueLabel);
        var materializedElement = NextTemp("stream_element");
        EmitLoad(
            materializedElement,
            elementType,
            elementAddress,
            RuntimeAlignment(source.ElementType));
        EmitStreamValue(
            DematerializeAggregateValue(source.ElementType, materializedElement),
            sink);
        if (!_currentBlockTerminated)
        {
            EmitBranch(continueLabel);
        }
        EmitFunctionLine();
        EmitLabel(continueLabel);
        var cancelled = NextTemp("stream_cancelled");
        EmitLoad(cancelled, "i1", ResolveAsyncStreamCancellationSlot(cancellationSlot), 1);
        EmitConditionalBranch(cancelled, doneLabel, nextLabel);
        EmitFunctionLine();
        EmitLabel(doneLabel);
        _currentBlockLabel = doneLabel;
        DropOwnedRuntimeValue(source);
        UnregisterAsyncStreamCancellationSlot(cancellationSlot);
        _currentStreamCancellationSlot = previousCancellationSlot;
    }

    private RuntimeStreamSink BuildRuntimeStreamSink(
        IReadOnlyList<BlockFunctionCallStatement> calls,
        string cancellationSlot)
    {
        var callSite = new RuntimeStreamCallSite(
            CaptureLocals(), _currentFunctions, _currentFunction, _asyncScopeSnapshots.ToArray(),
            CaptureCallbackLoopAuthority());
        var lastCall = calls[^1];
        RuntimeStreamSink sink;
        if (string.Join('.', lastCall.Target) == "each")
        {
            sink = new RuntimeStreamConsumer(new RuntimeBlockInvocation(
                lastCall.ItemName,
                [],
                lastCall.Body,
                CaptureLocals(),
                _currentFunctions,
                _currentFunction,
                BoundType.Unit,
                OwnsItem: true,
                CallerAsyncScopes: callSite.AsyncScopes,
                LoopAuthority: callSite.LoopAuthority));
        }
        else
        {
            if (!(_program.ResolvedGenericCalls.TryGetValue(lastCall.ResolutionSite, out var terminalFunction)
                    || TryResolveFunction(lastCall.Target, out terminalFunction))
                || terminalFunction.Kind != BoundFunctionKind.UserBlock
                || terminalFunction.ReturnType != BoundType.Unit)
            {
                throw new SollangException("a runtime Stream<T> pipeline must end with each or a Unit block function");
            }
            var terminalArguments = (lastCall.Arguments ?? []).Select(EmitExpression).ToArray();
            sink = new RuntimeStreamTerminalStage(lastCall, terminalFunction, callSite, terminalArguments);
        }

        for (var index = calls.Count - 2; index >= 0; index--)
        {
            var call = calls[index];
            if (!(_program.ResolvedGenericCalls.TryGetValue(call.ResolutionSite, out var function)
                    || TryResolveFunction(call.Target, out function))
                || function.StreamElementType is null)
            {
                throw new SollangException(
                    "a runtime Stream<T> pipeline may contain only stream functions before its terminal");
            }
            var arguments = (call.Arguments ?? []).Select(EmitExpression).ToArray();
            if ((function.Kind == BoundFunctionKind.User && function.BlockInputType is null)
                || function.BlockBody.Any(static statement =>
                    statement is BindingStatement { IsStreamState: true }))
            {
                sink = CreateUserStreamStage(call, function, sink, callSite, arguments, cancellationSlot);
            }
            else
            {
                sink = new RuntimeStreamStage(call, function, sink, callSite, arguments);
            }
        }
        return HasAsyncStreamSuspension(sink) ? BindAsyncStreamArguments(sink) : sink;
    }

    private void EmitPartitionPipeline(BoundPartitionPipeline pipeline)
    {
        var source = EmitExpression(pipeline.Source) as RuntimeProducerStream
            ?? throw new SollangException("partition source did not produce a Stream<T> producer handle");
        if (source.ElementType != pipeline.SourceElementType || source.IsEvent != pipeline.IsEvent)
        {
            throw new SollangException("partition source producer ABI type mismatch");
        }
        if (pipeline.Source is NameExpression sourceName)
        {
            RemoveLocal(sourceName.Name);
        }

        var previousCancellationSlot = _currentStreamCancellationSlot;
        var cancellationSlot = NextTemp("partition_cancelled");
        EmitAlloca(cancellationSlot, "i1", 1);
        EmitStore("i1", "false", cancellationSlot, 1);
        RegisterAsyncStreamCancellationSlot(cancellationSlot);
        _currentStreamCancellationSlot = cancellationSlot;
        var sinks = pipeline.Routes
            .Select(route => BuildRuntimeStreamSink(route.Consumer.Calls, cancellationSlot))
            .ToArray();

        if (sinks.Any(HasAsyncStreamSuspension))
        {
            EmitAsyncProducerLoop([source], sinks[0], cancellationSlot, item =>
            {
                var outer = CaptureLocals();
                var continuationScopes = CaptureAsyncContinuationBranchScopes(includeLoopSnapshots: true);
                var continuationEdges = new List<(LocalScope[] Scopes, string Label)>();
                var protectedBinding = KeepLocalsInScope(outer, [pipeline.ItemName]);
                protectedBinding.TerminatingOwnedCleanupObligations.RemoveAll(
                    obligation => obligation.BindingName is null);
                ForgetAsyncSpillCarrier(pipeline.ItemName);
                _terminatingOwnedCleanupObligations.RemoveAll(
                    obligation => obligation.BindingName == pipeline.ItemName);
                _locals.Add(pipeline.ItemName, item);
                var continueLabel = NextLabel("async_partition_continue");
                var incoming = new List<(LocalScope Scope, string Label)>();
                LocalScope CaptureExit()
                {
                    var exit = CaptureLocals();
                    RestoreAsyncShadowedBinding(exit, protectedBinding, pipeline.ItemName);
                    return exit;
                }
                void EmitRoute(int index)
                {
                    _asyncHiddenScopes.Push(new AsyncHiddenScope(protectedBinding, []));
                    try
                    {
                        EmitStreamValue(ResolveLocal(pipeline.ItemName), sinks[index]);
                    }
                    finally
                    {
                        _asyncHiddenScopes.Pop();
                    }
                }
                {
                    for (var index = 0; index < pipeline.Routes.Count; index++)
                    {
                        var route = pipeline.Routes[index];
                        if (route.Condition is null)
                        {
                            EmitRoute(index);
                            if (!_currentBlockTerminated)
                            {
                                incoming.Add((CaptureExit(), _currentBlockLabel));
                                continuationEdges.Add((SnapshotAsyncContinuationScopes(continuationScopes), _currentBlockLabel));
                                EmitBranch(continueLabel);
                            }
                            break;
                        }
                        var selected = NextLabel("async_partition_selected");
                        var next = NextLabel("async_partition_test");
                        var condition = EmitExpression(route.Condition) as RuntimeBool
                            ?? throw new SollangException("partition predicate did not produce Bool");
                        var rejectedScope = CaptureLocals();
                        var rejectedContinuationScopes = continuationScopes
                            .Select(scope => new AsyncContinuationBranchScope(
                                scope.Scope, SnapshotAsyncContinuationScope(scope.Scope)))
                            .ToArray();
                        var rejectedBinding = KeepLocalsInScope(protectedBinding, [pipeline.ItemName]);
                        rejectedBinding.TerminatingOwnedCleanupObligations.RemoveAll(
                            obligation => obligation.BindingName is null);
                        EmitConditionalBranch(condition.ValueName, selected, next);
                        EmitLabel(selected);
                        _currentBlockLabel = selected;
                        EmitRoute(index);
                        if (!_currentBlockTerminated)
                        {
                            incoming.Add((CaptureExit(), _currentBlockLabel));
                            continuationEdges.Add((SnapshotAsyncContinuationScopes(continuationScopes), _currentBlockLabel));
                            EmitBranch(continueLabel);
                        }
                        RestoreLocals(rejectedScope);
                        RestoreAsyncContinuationScopes(rejectedContinuationScopes);
                        protectedBinding = rejectedBinding;
                        EmitLabel(next);
                        _currentBlockLabel = next;
                    }
                    if (!_currentBlockTerminated)
                    {
                        incoming.Add((CaptureExit(), _currentBlockLabel));
                        continuationEdges.Add((SnapshotAsyncContinuationScopes(continuationScopes), _currentBlockLabel));
                        EmitBranch(continueLabel);
                    }
                    EmitLabel(continueLabel);
                    _currentBlockLabel = continueLabel;
                    MergeAsyncOuterScope(outer, incoming);
                    MergeAsyncContinuationScopes(continuationScopes, continuationEdges, outer, incoming,
                        preserveBindingOwnership: true);
                }
            }, continuationSinks: sinks);
            UnregisterAsyncStreamCancellationSlot(cancellationSlot);
            _currentStreamCancellationSlot = previousCancellationSlot;
            return;
        }

        var elementType = LlvmType(source.ElementType);
        var elementAddress = NextTemp("partition_element_address");
        EmitAlloca(elementAddress, elementType, RuntimeAlignment(source.ElementType));
        var nextLabel = NextLabel("partition_next");
        var valueLabel = NextLabel("partition_value");
        var continueLabel = NextLabel("partition_continue");
        var doneLabel = NextLabel("partition_done");
        EmitBranch(nextLabel);
        EmitFunctionLine();
        EmitLabel(nextLabel);
        var hasValue = NextTemp("partition_has_value");
        EmitIndirectCall(
            hasValue,
            "i1",
            source.NextName,
            $"ptr {source.ContextName}, ptr {elementAddress}");
        EmitConditionalBranch(hasValue, valueLabel, doneLabel);
        EmitFunctionLine();
        EmitLabel(valueLabel);
        var materializedElement = NextTemp("partition_element");
        EmitLoad(
            materializedElement,
            elementType,
            elementAddress,
            RuntimeAlignment(source.ElementType));
        var item = DematerializeAggregateValue(source.ElementType, materializedElement);
        var outerLocals = CaptureLocals();
        _locals[pipeline.ItemName] = item;
        try
        {
            for (var index = 0; index < pipeline.Routes.Count; index++)
            {
                var route = pipeline.Routes[index];
                if (route.Condition is null)
                {
                    EmitStreamValue(item, sinks[index]);
                    if (!_currentBlockTerminated)
                    {
                        EmitBranch(continueLabel);
                    }
                    break;
                }

                var routeLabel = NextLabel($"partition_{route.Label}");
                var nextRouteLabel = NextLabel("partition_test");
                var condition = EmitExpression(route.Condition) as RuntimeBool
                    ?? throw new SollangException($"partition route '{route.Label}' predicate did not produce Bool");
                EmitConditionalBranch(condition.ValueName, routeLabel, nextRouteLabel);
                EmitFunctionLine();
                EmitLabel(routeLabel);
                EmitStreamValue(item, sinks[index]);
                if (!_currentBlockTerminated)
                {
                    EmitBranch(continueLabel);
                }
                EmitFunctionLine();
                EmitLabel(nextRouteLabel);
            }
        }
        finally
        {
            RestoreLocals(outerLocals);
        }

        EmitFunctionLine();
        EmitLabel(continueLabel);
        var cancelled = NextTemp("partition_cancelled");
        EmitLoad(cancelled, "i1", ResolveAsyncStreamCancellationSlot(cancellationSlot), 1);
        EmitConditionalBranch(cancelled, doneLabel, nextLabel);
        EmitFunctionLine();
        EmitLabel(doneLabel);
        _currentBlockLabel = doneLabel;
        DropOwnedRuntimeValue(source);
        UnregisterAsyncStreamCancellationSlot(cancellationSlot);
        _currentStreamCancellationSlot = previousCancellationSlot;
    }

    private void EmitStreamJoinPipeline(BoundStreamJoinPipeline pipeline)
    {
        if (pipeline.Join.Policy is StreamJoinPolicy.Merge or StreamJoinPolicy.Latest
            && pipeline.Join.Inputs.Any(static input => input.IsEvent))
        {
            EmitRuntimeProducerPipeline(new BoundEventStreamPipeline(
                pipeline.Expression,
                pipeline.Consumer.Calls,
                pipeline.Join.OutputElementType,
                IsEvent: true));
            return;
        }
        switch (pipeline.Join.Policy)
        {
            case StreamJoinPolicy.Zip:
                EmitZipPipeline(pipeline);
                return;
            case StreamJoinPolicy.Concat:
                EmitConcatPipeline(pipeline);
                return;
            case StreamJoinPolicy.Merge:
                EmitMergePipeline(pipeline);
                return;
            case StreamJoinPolicy.Latest:
                EmitLatestPipeline(pipeline);
                return;
            default:
                throw new InvalidOperationException("unknown stream join policy");
        }
    }

    private RuntimeProducerStream[] EmitStreamJoinSources(BoundStreamJoinPipeline pipeline)
    {
        var product = EmitExpression(pipeline.Expression.Source) as RuntimeStruct
            ?? throw new SollangException("stream join source did not produce a product");
        if (product.Type != pipeline.Join.InputProductType)
        {
            throw new SollangException("stream join input product type mismatch");
        }
        var productType = LlvmStructType(product.Type);
        var sources = new RuntimeProducerStream[pipeline.Join.Inputs.Count];
        for (var index = 0; index < sources.Length; index++)
        {
            var input = pipeline.Join.Inputs[index];
            var aggregate = NextTemp("join_source");
            EmitAssign(
                aggregate,
                $"extractvalue {productType} {product.ValueName}, {index.ToString(CultureInfo.InvariantCulture)}");
            sources[index] = DematerializeAggregateValue(input.StreamType, aggregate) as RuntimeProducerStream
                ?? throw new SollangException("stream join field did not contain a producer handle");
            if (sources[index].ElementType != input.ElementType
                || sources[index].IsEvent != input.IsEvent)
            {
                throw new SollangException("stream join producer ABI type mismatch");
            }
        }
        if (pipeline.Expression.Source is NameExpression productOwner
            && _program.Types.IsProduct(product.Type)
            && _program.Types.ContainsOwnedStorage(product.Type))
        {
            // Semantic GetOwnedLiteralSourceNames transfers the named product
            // as a whole. Its extracted producer fields now own the handles.
            RemoveLocal(productOwner.Name);
        }
        return sources;
    }

    private void EmitConcatPipeline(BoundStreamJoinPipeline pipeline)
    {
        var sources = EmitStreamJoinSources(pipeline);
        var previousCancellationSlot = _currentStreamCancellationSlot;
        var cancellationSlot = NextTemp("concat_cancelled");
        EmitAlloca(cancellationSlot, "i1", 1);
        EmitStore("i1", "false", cancellationSlot, 1);
        RegisterAsyncStreamCancellationSlot(cancellationSlot);
        _currentStreamCancellationSlot = cancellationSlot;
        var sink = BuildRuntimeStreamSink(pipeline.Consumer.Calls, cancellationSlot);
        var doneLabel = NextLabel("concat_done");

        if (HasAsyncStreamSuspension(sink))
        {
            EmitAsyncProducerLoop(sources, sink, cancellationSlot);
            UnregisterAsyncStreamCancellationSlot(cancellationSlot);
            _currentStreamCancellationSlot = previousCancellationSlot;
            return;
        }

        foreach (var source in sources)
        {
            var elementType = LlvmType(source.ElementType);
            var elementAddress = NextTemp("concat_element_address");
            EmitAlloca(elementAddress, elementType, RuntimeAlignment(source.ElementType));
            var nextLabel = NextLabel("concat_next");
            var valueLabel = NextLabel("concat_value");
            var continueLabel = NextLabel("concat_continue");
            var sourceDoneLabel = NextLabel("concat_source_done");
            EmitBranch(nextLabel);
            EmitFunctionLine();
            EmitLabel(nextLabel);
            var hasValue = NextTemp("concat_has_value");
            EmitIndirectCall(
                hasValue,
                "i1",
                source.NextName,
                $"ptr {source.ContextName}, ptr {elementAddress}");
            EmitConditionalBranch(hasValue, valueLabel, sourceDoneLabel);
            EmitFunctionLine();
            EmitLabel(valueLabel);
            var materialized = NextTemp("concat_element");
            EmitLoad(materialized, elementType, elementAddress, RuntimeAlignment(source.ElementType));
            EmitStreamValue(DematerializeAggregateValue(source.ElementType, materialized), sink);
            if (!_currentBlockTerminated)
            {
                EmitBranch(continueLabel);
            }
            EmitFunctionLine();
            EmitLabel(continueLabel);
            var cancelled = NextTemp("concat_cancelled");
            EmitLoad(cancelled, "i1", ResolveAsyncStreamCancellationSlot(cancellationSlot), 1);
            EmitConditionalBranch(cancelled, doneLabel, nextLabel);
            EmitFunctionLine();
            EmitLabel(sourceDoneLabel);
        }
        EmitBranch(doneLabel);
        EmitFunctionLine();
        EmitLabel(doneLabel);
        foreach (var source in sources)
        {
            DropOwnedRuntimeValue(source);
        }
        UnregisterAsyncStreamCancellationSlot(cancellationSlot);
        _currentStreamCancellationSlot = previousCancellationSlot;
    }

    private void EmitZipPipeline(BoundStreamJoinPipeline pipeline)
    {
        var sources = EmitStreamJoinSources(pipeline);
        var previousCancellationSlot = _currentStreamCancellationSlot;
        var cancellationSlot = NextTemp("zip_cancelled");
        EmitAlloca(cancellationSlot, "i1", 1);
        EmitStore("i1", "false", cancellationSlot, 1);
        RegisterAsyncStreamCancellationSlot(cancellationSlot);
        _currentStreamCancellationSlot = cancellationSlot;
        var sink = BuildRuntimeStreamSink(pipeline.Consumer.Calls, cancellationSlot);
        if (HasAsyncStreamSuspension(sink))
        {
            EmitAsyncJoinedStream(pipeline, sources, sink, cancellationSlot);
            UnregisterAsyncStreamCancellationSlot(cancellationSlot);
            _currentStreamCancellationSlot = previousCancellationSlot;
            return;
        }
        var addresses = sources.Select(source =>
        {
            var address = NextTemp("zip_element_address");
            EmitAlloca(address, LlvmType(source.ElementType), RuntimeAlignment(source.ElementType));
            return address;
        }).ToArray();
        var nextLabel = NextLabel("zip_next");
        var emitLabel = NextLabel("zip_emit");
        var continueLabel = NextLabel("zip_continue");
        var doneLabel = NextLabel("zip_done");
        var failureLabels = sources.Select((_, index) =>
            index == 0 ? doneLabel : NextLabel("zip_partial_done")).ToArray();
        EmitBranch(nextLabel);
        EmitFunctionLine();
        EmitLabel(nextLabel);
        for (var index = 0; index < sources.Length; index++)
        {
            var source = sources[index];
            var successLabel = index == sources.Length - 1
                ? emitLabel
                : NextLabel("zip_pull");
            var hasValue = NextTemp("zip_has_value");
            EmitIndirectCall(
                hasValue,
                "i1",
                source.NextName,
                $"ptr {source.ContextName}, ptr {addresses[index]}");
            EmitConditionalBranch(hasValue, successLabel, failureLabels[index]);
            if (index != sources.Length - 1)
            {
                EmitFunctionLine();
                EmitLabel(successLabel);
            }
        }
        EmitFunctionLine();
        EmitLabel(emitLabel);
        var outputDefinition = _program.Types.GetStruct(pipeline.Join.OutputElementType);
        var outputAggregate = "poison";
        for (var index = 0; index < sources.Length; index++)
        {
            var source = sources[index];
            var loaded = NextTemp("zip_element");
            EmitLoad(
                loaded,
                LlvmType(source.ElementType),
                addresses[index],
                RuntimeAlignment(source.ElementType));
            var next = NextTemp("zip_product");
            EmitAssign(
                next,
                $"insertvalue {LlvmStructType(outputDefinition.Id)} {outputAggregate}, {LlvmType(source.ElementType)} {loaded}, {index.ToString(CultureInfo.InvariantCulture)}");
            outputAggregate = next;
        }
        EmitStreamValue(new RuntimeStruct(outputDefinition.Id, outputAggregate), sink);
        if (!_currentBlockTerminated)
        {
            EmitBranch(continueLabel);
        }
        EmitFunctionLine();
        EmitLabel(continueLabel);
        var cancelled = NextTemp("zip_cancelled");
        EmitLoad(cancelled, "i1", ResolveAsyncStreamCancellationSlot(cancellationSlot), 1);
        EmitConditionalBranch(cancelled, doneLabel, nextLabel);

        for (var failureIndex = 1; failureIndex < sources.Length; failureIndex++)
        {
            EmitFunctionLine();
            EmitLabel(failureLabels[failureIndex]);
            for (var pulledIndex = failureIndex - 1; pulledIndex >= 0; pulledIndex--)
            {
                var pulled = sources[pulledIndex];
                var loaded = NextTemp("zip_unmatched");
                EmitLoad(
                    loaded,
                    LlvmType(pulled.ElementType),
                    addresses[pulledIndex],
                    RuntimeAlignment(pulled.ElementType));
                DropOwnedRuntimeValue(DematerializeAggregateValue(pulled.ElementType, loaded));
            }
            EmitBranch(doneLabel);
        }
        EmitFunctionLine();
        EmitLabel(doneLabel);
        foreach (var source in sources)
        {
            DropOwnedRuntimeValue(source);
        }
        UnregisterAsyncStreamCancellationSlot(cancellationSlot);
        _currentStreamCancellationSlot = previousCancellationSlot;
    }

    private void EmitMergePipeline(BoundStreamJoinPipeline pipeline)
    {
        var sources = EmitStreamJoinSources(pipeline);
        if (sources.Any(static source => source.IsEvent))
        {
            throw new SollangException("merge of EventStream<T> inputs requires the bounded concurrent join runtime");
        }
        var previousCancellationSlot = _currentStreamCancellationSlot;
        var cancellationSlot = NextTemp("merge_cancelled");
        EmitAlloca(cancellationSlot, "i1", 1);
        EmitStore("i1", "false", cancellationSlot, 1);
        RegisterAsyncStreamCancellationSlot(cancellationSlot);
        _currentStreamCancellationSlot = cancellationSlot;
        var sink = BuildRuntimeStreamSink(pipeline.Consumer.Calls, cancellationSlot);
        if (HasAsyncStreamSuspension(sink))
        {
            EmitAsyncJoinedStream(pipeline, sources, sink, cancellationSlot);
            UnregisterAsyncStreamCancellationSlot(cancellationSlot);
            _currentStreamCancellationSlot = previousCancellationSlot;
            return;
        }
        var activeSlots = sources.Select(_ =>
        {
            var slot = NextTemp("merge_active");
            EmitAlloca(slot, "i1", 1);
            EmitStore("i1", "true", slot, 1);
            return slot;
        }).ToArray();
        var elementType = LlvmType(pipeline.Join.OutputElementType);
        var elementAddress = NextTemp("merge_element_address");
        EmitAlloca(elementAddress, elementType, RuntimeAlignment(pipeline.Join.OutputElementType));
        var cycleLabel = NextLabel("merge_cycle");
        var doneLabel = NextLabel("merge_done");
        EmitBranch(cycleLabel);
        EmitFunctionLine();
        EmitLabel(cycleLabel);

        for (var index = 0; index < sources.Length; index++)
        {
            var source = sources[index];
            var pullLabel = NextLabel("merge_pull");
            var valueLabel = NextLabel("merge_value");
            var exhaustedLabel = NextLabel("merge_exhausted");
            var afterLabel = NextLabel("merge_after_input");
            var active = NextTemp("merge_active");
            EmitLoad(active, "i1", activeSlots[index], 1);
            EmitConditionalBranch(active, pullLabel, afterLabel);
            EmitFunctionLine();
            EmitLabel(pullLabel);
            var hasValue = NextTemp("merge_has_value");
            EmitIndirectCall(
                hasValue,
                "i1",
                source.NextName,
                $"ptr {source.ContextName}, ptr {elementAddress}");
            EmitConditionalBranch(hasValue, valueLabel, exhaustedLabel);
            EmitFunctionLine();
            EmitLabel(valueLabel);
            var materialized = NextTemp("merge_element");
            EmitLoad(
                materialized,
                elementType,
                elementAddress,
                RuntimeAlignment(pipeline.Join.OutputElementType));
            EmitStreamValue(DematerializeAggregateValue(pipeline.Join.OutputElementType, materialized), sink);
            if (!_currentBlockTerminated)
            {
                EmitBranch(afterLabel);
            }
            EmitFunctionLine();
            EmitLabel(exhaustedLabel);
            EmitStore("i1", "false", activeSlots[index], 1);
            EmitBranch(afterLabel);
            EmitFunctionLine();
            EmitLabel(afterLabel);
            var cancelled = NextTemp("merge_cancelled");
            EmitLoad(cancelled, "i1", ResolveAsyncStreamCancellationSlot(cancellationSlot), 1);
            var nextInputLabel = index == sources.Length - 1
                ? NextLabel("merge_cycle_check")
                : NextLabel("merge_next_input");
            EmitConditionalBranch(cancelled, doneLabel, nextInputLabel);
            EmitFunctionLine();
            EmitLabel(nextInputLabel);
        }

        string? anyActive = null;
        for (var index = 0; index < activeSlots.Length; index++)
        {
            var active = NextTemp("merge_active");
            EmitLoad(active, "i1", activeSlots[index], 1);
            if (anyActive is null)
            {
                anyActive = active;
            }
            else
            {
                var combined = NextTemp("merge_any_active");
                EmitBinary(combined, "or", "i1", anyActive, active);
                anyActive = combined;
            }
        }
        EmitConditionalBranch(anyActive!, cycleLabel, doneLabel);
        EmitFunctionLine();
        EmitLabel(doneLabel);
        foreach (var source in sources)
        {
            DropOwnedRuntimeValue(source);
        }
        UnregisterAsyncStreamCancellationSlot(cancellationSlot);
        _currentStreamCancellationSlot = previousCancellationSlot;
    }

    private void EmitLatestPipeline(BoundStreamJoinPipeline pipeline)
    {
        var sources = EmitStreamJoinSources(pipeline);
        if (sources.Any(static source => source.IsEvent))
        {
            throw new SollangException("latest of EventStream<T> inputs requires the bounded concurrent join runtime");
        }
        var previousCancellationSlot = _currentStreamCancellationSlot;
        var cancellationSlot = NextTemp("latest_cancelled");
        EmitAlloca(cancellationSlot, "i1", 1);
        EmitStore("i1", "false", cancellationSlot, 1);
        RegisterAsyncStreamCancellationSlot(cancellationSlot);
        _currentStreamCancellationSlot = cancellationSlot;
        var sink = BuildRuntimeStreamSink(pipeline.Consumer.Calls, cancellationSlot);
        if (HasAsyncStreamSuspension(sink))
        {
            EmitAsyncJoinedStream(pipeline, sources, sink, cancellationSlot);
            UnregisterAsyncStreamCancellationSlot(cancellationSlot);
            _currentStreamCancellationSlot = previousCancellationSlot;
            return;
        }
        var valueSlots = sources.Select(source =>
        {
            var slot = NextTemp("latest_value");
            EmitAlloca(slot, LlvmType(source.ElementType), RuntimeAlignment(source.ElementType));
            return slot;
        }).ToArray();
        var activeSlots = sources.Select(_ =>
        {
            var slot = NextTemp("latest_active");
            EmitAlloca(slot, "i1", 1);
            EmitStore("i1", "true", slot, 1);
            return slot;
        }).ToArray();
        var initialDoneLabel = NextLabel("latest_initial_done");
        var doneLabel = NextLabel("latest_done");
        for (var index = 0; index < sources.Length; index++)
        {
            var hasValue = NextTemp("latest_has_initial");
            EmitIndirectCall(
                hasValue,
                "i1",
                sources[index].NextName,
                $"ptr {sources[index].ContextName}, ptr {valueSlots[index]}");
            var nextLabel = index == sources.Length - 1
                ? initialDoneLabel
                : NextLabel("latest_initial_next");
            EmitConditionalBranch(hasValue, nextLabel, doneLabel);
            EmitFunctionLine();
            EmitLabel(nextLabel);
        }
        EmitLatestSnapshot(pipeline, sources, valueSlots, sink);
        var cancelledAfterInitial = NextTemp("latest_cancelled");
        EmitLoad(cancelledAfterInitial, "i1", ResolveAsyncStreamCancellationSlot(cancellationSlot), 1);
        var cycleLabel = NextLabel("latest_cycle");
        EmitConditionalBranch(cancelledAfterInitial, doneLabel, cycleLabel);
        EmitFunctionLine();
        EmitLabel(cycleLabel);

        for (var index = 0; index < sources.Length; index++)
        {
            var source = sources[index];
            var pullLabel = NextLabel("latest_pull");
            var updateLabel = NextLabel("latest_update");
            var exhaustedLabel = NextLabel("latest_exhausted");
            var afterLabel = NextLabel("latest_after_input");
            var active = NextTemp("latest_active");
            EmitLoad(active, "i1", activeSlots[index], 1);
            EmitConditionalBranch(active, pullLabel, afterLabel);
            EmitFunctionLine();
            EmitLabel(pullLabel);
            var hasValue = NextTemp("latest_has_value");
            EmitIndirectCall(
                hasValue,
                "i1",
                source.NextName,
                $"ptr {source.ContextName}, ptr {valueSlots[index]}");
            EmitConditionalBranch(hasValue, updateLabel, exhaustedLabel);
            EmitFunctionLine();
            EmitLabel(updateLabel);
            EmitLatestSnapshot(pipeline, sources, valueSlots, sink);
            if (!_currentBlockTerminated)
            {
                EmitBranch(afterLabel);
            }
            EmitFunctionLine();
            EmitLabel(exhaustedLabel);
            EmitStore("i1", "false", activeSlots[index], 1);
            EmitBranch(afterLabel);
            EmitFunctionLine();
            EmitLabel(afterLabel);
            var cancelled = NextTemp("latest_cancelled");
            EmitLoad(cancelled, "i1", ResolveAsyncStreamCancellationSlot(cancellationSlot), 1);
            var nextInputLabel = index == sources.Length - 1
                ? NextLabel("latest_cycle_check")
                : NextLabel("latest_next_input");
            EmitConditionalBranch(cancelled, doneLabel, nextInputLabel);
            EmitFunctionLine();
            EmitLabel(nextInputLabel);
        }

        string? anyActive = null;
        for (var index = 0; index < activeSlots.Length; index++)
        {
            var active = NextTemp("latest_active");
            EmitLoad(active, "i1", activeSlots[index], 1);
            if (anyActive is null)
            {
                anyActive = active;
            }
            else
            {
                var combined = NextTemp("latest_any_active");
                EmitBinary(combined, "or", "i1", anyActive, active);
                anyActive = combined;
            }
        }
        EmitConditionalBranch(anyActive!, cycleLabel, doneLabel);
        EmitFunctionLine();
        EmitLabel(doneLabel);
        foreach (var source in sources)
        {
            DropOwnedRuntimeValue(source);
        }
        UnregisterAsyncStreamCancellationSlot(cancellationSlot);
        _currentStreamCancellationSlot = previousCancellationSlot;
    }

    private void EmitLatestSnapshot(
        BoundStreamJoinPipeline pipeline,
        IReadOnlyList<RuntimeProducerStream> sources,
        IReadOnlyList<string> valueSlots,
        RuntimeStreamSink sink)
    {
        var outputDefinition = _program.Types.GetStruct(pipeline.Join.OutputElementType);
        var aggregate = "poison";
        for (var index = 0; index < sources.Count; index++)
        {
            var source = sources[index];
            var loaded = NextTemp("latest_value");
            EmitLoad(
                loaded,
                LlvmType(source.ElementType),
                valueSlots[index],
                RuntimeAlignment(source.ElementType));
            var next = NextTemp("latest_product");
            EmitAssign(
                next,
                $"insertvalue {LlvmStructType(outputDefinition.Id)} {aggregate}, {LlvmType(source.ElementType)} {loaded}, {index.ToString(CultureInfo.InvariantCulture)}");
            aggregate = next;
        }
        EmitStreamValue(new RuntimeStruct(outputDefinition.Id, aggregate), sink);
    }

    private RuntimeUserStreamStage CreateUserStreamStage(
        BlockFunctionCallStatement call,
        BoundFunction function,
        RuntimeStreamSink next,
        RuntimeStreamCallSite callSite,
        IReadOnlyList<RuntimeValue> arguments,
        string cancellationSlot)
    {
        var outerLocals = CaptureLocals();
        var previousFunction = _currentFunction;
        var previousFunctions = _currentFunctions;
        try
        {
            var stateLocals = new LocalScope(
                new Dictionary<string, RuntimeValue>(StringComparer.Ordinal),
                new HashSet<string>(StringComparer.Ordinal),
                new HashSet<string>(StringComparer.Ordinal),
                new HashSet<string>(StringComparer.Ordinal),
                new Dictionary<string, HashSet<string>>(StringComparer.Ordinal),
                new Dictionary<string, MutableContainerSlot>(StringComparer.Ordinal),
                new Dictionary<string, string>(StringComparer.Ordinal),
                new Dictionary<string, string>(StringComparer.Ordinal),
                new Dictionary<string, string>(StringComparer.Ordinal),
                new Dictionary<RuntimeValue, string>(),
                new Dictionary<string, string>(StringComparer.Ordinal),
                []);
            var parameters = function.AdditionalParameters ?? [];
            if (parameters.Count != arguments.Count)
            {
                throw new SollangException(
                    $"stream function '{function.Name}' expects {parameters.Count} additional argument(s)");
            }
            for (var index = 0; index < parameters.Count; index++)
            {
                EnsureRuntimeType(arguments[index], parameters[index].Type, parameters[index].Name);
                stateLocals.Locals[parameters[index].Name] = arguments[index];
            }

            RestoreLocals(stateLocals);
            _currentFunction = function;
            _currentFunctions = CreateFunctionScope(callSite.Functions, function.LocalFunctions);
            foreach (var stateBinding in function.BlockBody.OfType<BindingStatement>()
                         .Where(static binding => binding.IsStreamState))
            {
                EmitStatement(stateBinding);
            }
            return new RuntimeUserStreamStage(
                call,
                function,
                next,
                CaptureLocals(),
                callSite,
                arguments,
                cancellationSlot);
        }
        finally
        {
            _currentFunction = previousFunction;
            _currentFunctions = previousFunctions;
            RestoreLocals(outerLocals);
        }
    }

    private void EmitRangeEachBlockFunctionCall(
        BlockFunctionCallStatement statement,
        RuntimeStruct range)
    {
        if (HasPlannedCfgSuspension(statement.Body))
        {
            EmitAsyncRangeEachBlockFunctionCall(statement, range);
            return;
        }
        var llvmType = LlvmStructType(BoundType.Range);
        var start = NextTemp("range_start");
        EmitAssign(start, $"extractvalue {llvmType} {range.ValueName}, 0");
        var end = NextTemp("range_end");
        EmitAssign(end, $"extractvalue {llvmType} {range.ValueName}, 1");
        var bodyLabel = NextLabel("each_body");
        var continueLabel = NextLabel("each_continue");
        var endLabel = NextLabel("each_end");
        var entryLabel = _currentBlockLabel;
        var next = NextTemp("each_next");
        var initialDone = NextTemp("each_done");

        EmitCompare(initialDone, "sgt", "i32", start, end);
        EmitConditionalBranch(initialDone, endLabel, bodyLabel);

        EmitLabel(bodyLabel);
        _currentBlockLabel = bodyLabel;
        var item = NextTemp(statement.ItemName);
        EmitPhi(item, "i32", (start, entryLabel), (next, continueLabel));

        var outerLocals = CaptureLocals();
        try
        {
            _locals[statement.ItemName] = new RuntimeInt(item);
            EmitLoopBody(statement.Body, outerLocals, continueLabel, endLabel);
        }
        finally
        {
            RestoreLocals(outerLocals);
        }

        if (!_currentBlockTerminated)
        {
            EmitBranch(continueLabel);
        }
        EmitLabel(continueLabel);
        _currentBlockLabel = continueLabel;
        EmitBinary(next, "add", "i32", item, "1");
        var done = NextTemp("each_done");
        EmitCompare(done, "sge", "i32", item, end);
        EmitConditionalBranch(done, endLabel, bodyLabel);
        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
    }

    private void EmitArrayEachBlockFunctionCall(BlockFunctionCallStatement statement)
    {
        var source = EmitExpression(statement.Source);
        if (source is RuntimeInlineDictionary set && _program.Types.IsSet(set.DictionaryType))
        {
            EmitDictionaryEachBlockFunctionCall(statement, bindKey: true, source);
            return;
        }
        if (source is RuntimeStruct { Type: BoundType.Range } range)
        {
            EmitRangeEachBlockFunctionCall(statement, range);
            return;
        }
        if (source is RuntimeText text)
        {
            EmitTextEachBlockFunctionCall(statement, text);
            return;
        }
        var length = ArrayEachLength(source);

        if (HasPlannedCfgSuspension(statement.Body))
        {
            EmitAsyncIndexedBlockFunctionCall(
                statement, source, ArrayEachLength, ArrayEachItem);
            return;
        }

        var bodyLabel = NextLabel("array_each_body");
        var continueLabel = NextLabel("array_each_continue");
        var endLabel = NextLabel("array_each_end");
        var entryLabel = _currentBlockLabel;
        var next = NextTemp("array_each_next");
        var initialDone = NextTemp("array_each_done");

        EmitCompare(initialDone, "eq", "i64", length, "0");
        EmitConditionalBranch(initialDone, endLabel, bodyLabel);

        EmitLabel(bodyLabel);
        _currentBlockLabel = bodyLabel;
        var index = NextTemp("array_each_i");
        EmitPhi(index, "i64", ("0", entryLabel), (next, continueLabel));

        var item = ArrayEachItem(source, index);

        var outerLocals = CaptureLocals();
        try
        {
            _locals[statement.ItemName] = item;
            if (_program.Types.ContainsOwnedStorage(item.Type))
            {
                _borrowedOwnedLocals.Add(statement.ItemName);
            }
            EmitLoopBody(statement.Body, outerLocals, continueLabel, endLabel);
        }
        finally
        {
            RestoreLocals(outerLocals);
        }

        if (!_currentBlockTerminated)
        {
            EmitBranch(continueLabel);
        }
        EmitLabel(continueLabel);
        _currentBlockLabel = continueLabel;
        EmitBinary(next, "add", "i64", index, "1");
        var done = NextTemp("array_each_done");
        EmitCompare(done, "eq", "i64", next, length);
        EmitConditionalBranch(done, endLabel, bodyLabel);
        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
    }

    private void EmitUserBlockFunctionCall(
        BlockFunctionCallStatement firstCall,
        BoundFunction function,
        RuntimeStreamSink? continuation = null,
        RuntimeValue? streamedArgument = null,
        RuntimeStreamCallSite? callSite = null,
        IReadOnlyList<RuntimeValue>? streamedAdditionalArguments = null)
    {
        var statement = firstCall;
        if (function.InputType is null || function.BlockInputType is null)
        {
            throw new SollangException($"block function '{function.Name}' is not callable");
        }

        var argument = streamedArgument ?? (function.InputOwnership == BoundFunctionInputOwnership.MutableBorrow
            ? CreateMutableBorrowArgument(
                statement.Source,
                function.InputType.Value,
                function.Name,
                function.InputName ?? "it")
            : EmitFlowAdditionalValue(function.InputType.Value, statement.Source));
        EnsureRuntimeType(argument, function.InputType.Value, function.Name);
        var additionalParameters = function.AdditionalParameters ?? [];
        var argumentExpressions = statement.Arguments ?? [];
        if (argumentExpressions.Count != additionalParameters.Count)
        {
            throw new SollangException(
                $"block function '{function.Name}' expects {additionalParameters.Count} additional argument(s)");
        }
        var additionalArguments = streamedAdditionalArguments
            ?? argumentExpressions.Select((expression, index) =>
            {
                var parameter = additionalParameters[index];
                return parameter.Ownership == BoundFunctionInputOwnership.MutableBorrow
                    ? CreateMutableBorrowArgument(expression, parameter.Type, function.Name, parameter.Name)
                    : EmitFlowAdditionalValue(parameter.Type, expression);
            }).ToArray();

        var returnLocals = CaptureLocals();
        var callerLocals = callSite?.Locals ?? returnLocals;
        var callerAsyncScopes = _asyncScopeSnapshots.ToArray();
        var callerFunctions = callSite?.Functions ?? _currentFunctions;
        var callerFunction = callSite?.Function ?? _currentFunction;
        var callerLoopAuthority = callSite?.LoopAuthority ?? CaptureCallbackLoopAuthority();
        var previousInvocation = _currentBlockInvocation;
        var previousStreamContinuation = _currentStreamContinuation;
        var previousFunctions = _currentFunctions;
        var previousFunction = _currentFunction;
        var blockLocals = new LocalScope(
            new Dictionary<string, RuntimeValue>(StringComparer.Ordinal),
            new HashSet<string>(StringComparer.Ordinal),
            new HashSet<string>(StringComparer.Ordinal),
            new HashSet<string>(StringComparer.Ordinal),
            new Dictionary<string, HashSet<string>>(StringComparer.Ordinal),
            new Dictionary<string, MutableContainerSlot>(StringComparer.Ordinal),
            new Dictionary<string, string>(StringComparer.Ordinal),
            new Dictionary<string, string>(StringComparer.Ordinal),
            new Dictionary<string, string>(StringComparer.Ordinal),
            new Dictionary<RuntimeValue, string>(),
            new Dictionary<string, string>(StringComparer.Ordinal),
            []);
        var additionalBlockParameters = function.AdditionalBlockParameters ?? [];
        var additionalItemNames = statement.AdditionalItemNames ?? [];
        if (additionalItemNames.Count != additionalBlockParameters.Count)
        {
            throw new SollangException(
                $"block function '{function.Name}' expects {1 + additionalBlockParameters.Count} block item name(s)");
        }

        _currentBlockInvocation = new RuntimeBlockInvocation(
            statement.ItemName,
            additionalItemNames.Select((name, index) =>
                (name, additionalBlockParameters[index].Type)).ToArray(),
            statement.Body,
            callerLocals,
            callerFunctions,
            callerFunction,
            function.BlockResultType ?? BoundType.Unit,
            OwnsItem: false,
            CallerAsyncScopes: callerAsyncScopes,
            LoopAuthority: callerLoopAuthority);
        _currentStreamContinuation = function.StreamElementType is null
            ? null
            : continuation ?? throw new SollangException($"stream function '{function.Name}' requires a downstream consumer");
        _currentFunctions = CreateFunctionScope(_currentFunctions, function.LocalFunctions);
        _currentFunction = function;
        RestoreLocals(blockLocals);
        BindInlineFunctionParameters(function, argument, additionalArguments);
        RuntimeValue result = RuntimeUnit.Instance;
        var preserveCaller = _activeAsyncCfg is not null;
        if (preserveCaller)
        {
            _asyncHiddenScopes.Push(new AsyncHiddenScope(returnLocals, callerAsyncScopes));
            _asyncScopeSnapshots.Clear();
        }
        try
        {
            EmitStatements(function.BlockBody);
            if (_currentBlockTerminated) return;
            result = function.Body is null
                ? RuntimeUnit.Instance
                : EmitExpression(function.Body);
            EnsureRuntimeType(result, function.ReturnType, function.Name);
            var transferredOwnerName = statement.ResultName is not null
                && function.Body is not null
                && IsOwnedContainerRuntimeValue(result)
                    ? GetFunctionResultTransferredOwnerName(function, function.Body)
                    : null;
            DropOwnedLocalsCreatedSince(blockLocals, transferredOwnerName, function.Body);
            if (function.ReturnType == BoundType.Unit)
            {
                foreach (var parameter in additionalParameters.Where(parameter =>
                    parameter.Ownership == BoundFunctionInputOwnership.Move))
                {
                    if (_locals.TryGetValue(parameter.Name, out var movedValue))
                    {
                        DropOwnedLocal(parameter.Name, movedValue);
                        RemoveLocal(parameter.Name);
                    }
                }
                if (function.InputOwnership == BoundFunctionInputOwnership.Move
                    && _locals.TryGetValue(function.InputName ?? "it", out var movedInput))
                {
                    DropOwnedLocal(function.InputName ?? "it", movedInput);
                    RemoveLocal(function.InputName ?? "it");
                }
            }
        }
        finally
        {
            if (preserveCaller)
            {
                _asyncHiddenScopes.Pop();
                _asyncScopeSnapshots.Clear();
                foreach (var scope in callerAsyncScopes.Reverse())
                    _asyncScopeSnapshots.Push(scope);
            }
            _currentBlockInvocation = previousInvocation;
            _currentStreamContinuation = previousStreamContinuation;
            _currentFunctions = previousFunctions;
            _currentFunction = previousFunction;
            RestoreLocals(returnLocals);
        }

        if (statement.ResultName is null)
        {
            return;
        }

        if (RequiresHeapAllocation(result) && !_platform.SupportsHeapAllocation)
        {
            throw new SollangException(
                "dynamic arrays and dictionaries require heap allocation; wasm32-browser does not support them yet");
        }

        _locals.Add(statement.ResultName, result);
        if (statement.ResultIsMutable)
        {
            _mutableLocals.Add(statement.ResultName);
            if (result is RuntimeStruct structure)
            {
                CreateMutableStructSlot(statement.ResultName, structure);
            }
            else
            {
                var binding = new BindingStatement(
                    statement.ResultName,
                    statement.Source,
                    statement.Line,
                    statement.Column,
                    IsMutable: true);
                CreateMutableContainerSlot(binding, result);
            }
        }
    }

    private void EmitParallelBlockFunctionCall(BlockFunctionCallStatement statement, BoundFunction function)
    {
        var source = EmitExpression(statement.Source);
        var length = source switch
        {
            RuntimeDynamicIntArray array => array.LengthName,
            RuntimeDynamicInlineArray array => array.LengthName,
            _ => throw new SollangException("parallel expects a growable array")
        };
        if (statement.Body.Count == 0 || statement.Body[^1] is not ExpressionStatement callbackResult)
        {
            throw new SollangException("parallel callback requires a final expression");
        }

        var resultType = function.BlockResultType
            ?? throw new SollangException("parallel callback result type was not specialized");
        RuntimeValue resultArray;
        string outputPointer;
        if (resultType == BoundType.Int)
        {
            outputPointer = EmitHeapAllocateProduct(length, "4", "parallel_result_bytes");
            resultArray = new RuntimeDynamicIntArray(outputPointer, length, length);
        }
        else
        {
            var outputDefinition = _program.Types.GetDynamicArray(function.ReturnType);
            outputPointer = EmitHeapAllocateProduct(
                length,
                outputDefinition.ElementSize.ToString(CultureInfo.InvariantCulture),
                "parallel_result_bytes");
            resultArray = new RuntimeDynamicInlineArray(
                function.ReturnType,
                resultType,
                outputPointer,
                length,
                length);
        }

        if (_parallelCallbacks.TryGetValue(statement, out var callback))
        {
            var inputPointer = source switch
            {
                RuntimeDynamicIntArray array => array.PointerName,
                RuntimeDynamicInlineArray array => array.PointerName,
                _ => throw new SollangException("parallel expects a growable array")
            };
            var group = NextTemp("parallel_group");
            EmitAlloca(group, "%sollang.compute_group", 8);
            var callbackSlot = NextTemp("parallel_callback_slot");
            EmitInstruction($"{callbackSlot} = getelementptr %sollang.compute_group, ptr {group}, i32 0, i32 0");
            EmitStore("ptr", $"@{callback.Name}", callbackSlot, 8);
            var inputSlot = NextTemp("parallel_input_slot");
            EmitInstruction($"{inputSlot} = getelementptr %sollang.compute_group, ptr {group}, i32 0, i32 1");
            EmitStore("ptr", inputPointer, inputSlot, 8);
            var outputSlot = NextTemp("parallel_output_slot");
            EmitInstruction($"{outputSlot} = getelementptr %sollang.compute_group, ptr {group}, i32 0, i32 2");
            EmitStore("ptr", outputPointer, outputSlot, 8);
            var countSlot = NextTemp("parallel_count_slot");
            EmitInstruction($"{countSlot} = getelementptr %sollang.compute_group, ptr {group}, i32 0, i32 3");
            EmitStore("i64", length, countSlot, 8);
            var captureEnvironment = EmitParallelCaptureEnvironment(callback, "parallel");
            var captureSlot = NextTemp("parallel_capture_slot");
            EmitInstruction($"{captureSlot} = getelementptr %sollang.compute_group, ptr {group}, i32 0, i32 4");
            EmitStore("ptr", captureEnvironment, captureSlot, 8);
            var sinkBytes = NextTemp("parallel_sink_bytes");
            EmitInstruction($"{sinkBytes} = mul i64 {length}, 24");
            var sinks = NextTemp("parallel_sinks");
            EmitCall(sinks, "ptr", "sollang_alloc", $"i64 {sinkBytes}");
            EmitCall(target: null, "void", "llvm.memset.p0.i64", $"ptr {sinks}, i8 0, i64 {sinkBytes}, i1 false");
            var sinksSlot = NextTemp("parallel_sinks_slot");
            EmitInstruction($"{sinksSlot} = getelementptr %sollang.compute_group, ptr {group}, i32 0, i32 5");
            EmitStore("ptr", sinks, sinksSlot, 8);
            var runtimeValues = new[] { "%stdin", "%stdout", "%written", "%read", "%ok_state" };
            for (var runtimeIndex = 0; runtimeIndex < runtimeValues.Length; runtimeIndex++)
            {
                var runtimeSlot = NextTemp("parallel_runtime_slot");
                EmitInstruction($"{runtimeSlot} = getelementptr %sollang.compute_group, ptr {group}, i32 0, i32 {runtimeIndex + 6}");
                EmitStore("ptr", runtimeValues[runtimeIndex], runtimeSlot, 8);
            }
            var failureLimitSlot = NextTemp("parallel_failure_limit_slot");
            EmitInstruction($"{failureLimitSlot} = getelementptr %sollang.compute_group, ptr {group}, i32 0, i32 11");
            EmitStore("i64", length, failureLimitSlot, 8);
            var initializedSlot = NextTemp("parallel_initialized_slot");
            EmitInstruction($"{initializedSlot} = getelementptr %sollang.compute_group, ptr {group}, i32 0, i32 12");
            EmitStore("ptr", "null", initializedSlot, 8);
            EmitCall(target: null, "void", "sollang_compute_execute", $"ptr {group}");
            BindParallelResult(statement, resultArray);
            return;
        }

        var bodyLabel = NextLabel("parallel_body");
        var continueLabel = NextLabel("parallel_continue");
        var endLabel = NextLabel("parallel_end");
        var entryLabel = _currentBlockLabel;
        var next = NextTemp("parallel_next");
        var initialDone = NextTemp("parallel_done");
        EmitCompare(initialDone, "eq", "i64", length, "0");
        EmitConditionalBranch(initialDone, endLabel, bodyLabel);

        EmitLabel(bodyLabel);
        _currentBlockLabel = bodyLabel;
        var index = NextTemp("parallel_i");
        EmitPhi(index, "i64", ("0", entryLabel), (next, continueLabel));
        RuntimeValue item = source switch
        {
            RuntimeDynamicIntArray array => EmitDynamicArrayLoad(array, index),
            RuntimeDynamicInlineArray array => EmitDynamicInlineArrayLoad(array, index),
            _ => throw new SollangException("parallel expects a growable array")
        };

        var outerLocals = CaptureLocals();
        try
        {
            _locals[statement.ItemName] = item;
            var callbackLocals = CaptureLocals();
            EmitStatements(statement.Body.Take(statement.Body.Count - 1).ToArray());
            var mapped = EmitExpression(callbackResult.Expression);
            EnsureRuntimeType(mapped, resultType, "parallel callback");
            switch (resultArray)
            {
                case RuntimeDynamicIntArray integers:
                    EmitDynamicArrayAssign(integers, index, ((RuntimeInt)mapped).ValueName);
                    break;
                case RuntimeDynamicInlineArray inline:
                    StoreDynamicInlineArrayElement(
                        inline.PointerName,
                        _program.Types.GetDynamicArray(inline.Type),
                        index,
                        mapped);
                    break;
            }
            var transferred = IsOwnedContainerRuntimeValue(mapped)
                ? GetMoveConsumingContainerSourceName(callbackResult.Expression)
                : null;
            DropOwnedLocalsCreatedSince(callbackLocals, transferred, callbackResult.Expression);
        }
        finally
        {
            RestoreLocals(outerLocals);
        }
        if (!_currentBlockTerminated)
        {
            EmitBranch(continueLabel);
        }
        EmitLabel(continueLabel);
        _currentBlockLabel = continueLabel;
        EmitBinary(next, "add", "i64", index, "1");
        var done = NextTemp("parallel_done");
        EmitCompare(done, "eq", "i64", next, length);
        EmitConditionalBranch(done, endLabel, bodyLabel);
        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;

        BindParallelResult(statement, resultArray);
    }

    private string EmitParallelCaptureEnvironment(ParallelCallbackInfo callback, string prefix)
    {
        var environmentValueCount = callback.Captures.Count + callback.AdditionalArguments.Count;
        if (environmentValueCount == 0)
        {
            return "null";
        }

        var captureType = ParallelCaptureType(callback.Captures, callback.AdditionalArguments);
        var captureEnvironment = NextTemp(prefix + "_capture_environment");
        EmitAlloca(captureEnvironment, captureType, 8);
        var environmentIndex = 0;
        foreach (var capture in callback.Captures)
        {
            var captureValue = ResolveLocal(capture.Key);
            EnsureFunctionArgumentRuntimeType(captureValue, capture.Value, callback.Target.Name);
            StoreParallelEnvironmentValue(
                prefix,
                captureType,
                captureEnvironment,
                environmentIndex++,
                capture.Value,
                captureValue);
        }
        foreach (var argument in callback.AdditionalArguments)
        {
            var argumentValue = argument.Ownership == BoundFunctionInputOwnership.MutableBorrow
                ? CreateMutableBorrowArgument(
                    argument.Expression,
                    argument.Type,
                    callback.Target.Name,
                    "parallel argument")
                : _program.Types.IsReference(argument.Type)
                    ? CreateReadonlyReferenceArgument(
                        argument.Expression,
                        argument.Type,
                        callback.Target.Name)
                    : EmitFunctionArgumentExpression(argument.Expression, argument.Type);
            EnsureFunctionArgumentRuntimeType(argumentValue, argument.Type, callback.Target.Name);
            StoreParallelEnvironmentValue(
                prefix,
                captureType,
                captureEnvironment,
                environmentIndex++,
                argument.Type,
                argumentValue);
        }
        return captureEnvironment;
    }

    private void StoreParallelEnvironmentValue(
        string prefix,
        string captureType,
        string captureEnvironment,
        int environmentIndex,
        BoundType type,
        RuntimeValue value)
    {
        var materialized = MaterializeAggregateValue(value);
        var captureAddress = NextTemp(prefix + "_capture_address");
        EmitInstruction(
            $"{captureAddress} = getelementptr {captureType}, ptr {captureEnvironment}, i32 0, i32 {environmentIndex.ToString(CultureInfo.InvariantCulture)}");
        EmitStore(
            materialized.TypeName,
            materialized.ValueName,
            captureAddress,
            RuntimeAlignment(type));
    }

    private void BindParallelResult(BlockFunctionCallStatement statement, RuntimeValue resultArray)
    {
        if (statement.ResultName is not null)
        {
            _locals.Add(statement.ResultName, resultArray);
            if (statement.ResultIsMutable)
            {
                _mutableLocals.Add(statement.ResultName);
                CreateMutableContainerSlot(new BindingStatement(
                    statement.ResultName,
                    statement.Source,
                    statement.Line,
                    statement.Column,
                    IsMutable: true), resultArray);
            }
        }
    }

    private void EmitTryParallelBlockFunctionCall(
        BlockFunctionCallStatement statement,
        BoundFunction function)
    {
        var source = EmitExpression(statement.Source);
        var length = source switch
        {
            RuntimeDynamicIntArray array => array.LengthName,
            RuntimeDynamicInlineArray array => array.LengthName,
            _ => throw new SollangException("tryParallel expects a growable array")
        };
        if (statement.Body.Count == 0 || statement.Body[^1] is not ExpressionStatement callbackResult)
        {
            throw new SollangException("tryParallel callback requires a final Result expression");
        }
        if (function.BlockResultType is not { } callbackResultType
            || !_program.Types.TryGetResultTypes(callbackResultType, out var callbackTypes)
            || !_program.Types.TryGetResultTypes(function.ReturnType, out var outerTypes))
        {
            throw new SollangException("tryParallel Result types were not specialized");
        }

        RuntimeValue resultArray;
        string outputPointer;
        if (callbackTypes.Ok == BoundType.Int)
        {
            outputPointer = EmitHeapAllocateProduct(length, "4", "try_parallel_result_bytes");
            resultArray = new RuntimeDynamicIntArray(outputPointer, length, length);
        }
        else
        {
            var outputDefinition = _program.Types.GetDynamicArray(outerTypes.Ok);
            outputPointer = EmitHeapAllocateProduct(
                length,
                outputDefinition.ElementSize.ToString(CultureInfo.InvariantCulture),
                "try_parallel_result_bytes");
            resultArray = new RuntimeDynamicInlineArray(
                outerTypes.Ok,
                callbackTypes.Ok,
                outputPointer,
                length,
                length);
        }

        if (_parallelCallbacks.TryGetValue(statement, out var callback))
        {
            var callbackStride = _program.Types.InlineSizeOf(callbackResultType);
            var callbackBytes = NextTemp("try_parallel_callback_bytes");
            EmitInstruction($"{callbackBytes} = mul i64 {length}, {callbackStride.ToString(CultureInfo.InvariantCulture)}");
            var callbackResults = NextTemp("try_parallel_callback_results");
            EmitCall(callbackResults, "ptr", "sollang_alloc", $"i64 {callbackBytes}");
            var initialized = NextTemp("try_parallel_initialized");
            EmitCall(initialized, "ptr", "sollang_alloc", $"i64 {length}");
            EmitCall(target: null, "void", "llvm.memset.p0.i64", $"ptr {initialized}, i8 0, i64 {length}, i1 false");
            var sinksBytes = NextTemp("try_parallel_sink_bytes");
            EmitInstruction($"{sinksBytes} = mul i64 {length}, 24");
            var sinks = NextTemp("try_parallel_sinks");
            EmitCall(sinks, "ptr", "sollang_alloc", $"i64 {sinksBytes}");
            EmitCall(target: null, "void", "llvm.memset.p0.i64", $"ptr {sinks}, i8 0, i64 {sinksBytes}, i1 false");

            var inputPointer = source switch
            {
                RuntimeDynamicIntArray array => array.PointerName,
                RuntimeDynamicInlineArray array => array.PointerName,
                _ => throw new SollangException("tryParallel expects a growable array")
            };
            var group = NextTemp("try_parallel_group");
            EmitAlloca(group, "%sollang.compute_group", 8);
            EmitComputeGroupField(group, 0, "ptr", $"@{callback.Name}");
            EmitComputeGroupField(group, 1, "ptr", inputPointer);
            EmitComputeGroupField(group, 2, "ptr", callbackResults);
            EmitComputeGroupField(group, 3, "i64", length);

            var captureEnvironment = EmitParallelCaptureEnvironment(callback, "try_parallel");
            EmitComputeGroupField(group, 4, "ptr", captureEnvironment);
            EmitComputeGroupField(group, 5, "ptr", sinks);
            var runtimeValues = new[] { "%stdin", "%stdout", "%written", "%read", "%ok_state" };
            for (var runtimeIndex = 0; runtimeIndex < runtimeValues.Length; runtimeIndex++)
            {
                EmitComputeGroupField(group, runtimeIndex + 6, "ptr", runtimeValues[runtimeIndex]);
            }
            EmitComputeGroupField(group, 11, "i64", length);
            EmitComputeGroupField(group, 12, "ptr", initialized);
            EmitCall(target: null, "void", "sollang_compute_execute", $"ptr {group}");
            var collectedResult = EmitCollectTryParallelResults(
                group,
                function,
                resultArray,
                outputPointer,
                callbackResults,
                initialized,
                length,
                callbackResultType,
                callbackTypes,
                callbackStride);
            BindParallelResult(statement, collectedResult);
            return;
        }

        var bodyLabel = NextLabel("try_parallel_body");
        var continueLabel = NextLabel("try_parallel_continue");
        var successLabel = NextLabel("try_parallel_success");
        var mergeLabel = NextLabel("try_parallel_merge");
        var entryLabel = _currentBlockLabel;
        var next = NextTemp("try_parallel_next");
        var initialDone = NextTemp("try_parallel_done");
        EmitCompare(initialDone, "eq", "i64", length, "0");
        EmitConditionalBranch(initialDone, successLabel, bodyLabel);

        EmitLabel(bodyLabel);
        _currentBlockLabel = bodyLabel;
        var index = NextTemp("try_parallel_i");
        EmitPhi(index, "i64", ("0", entryLabel), (next, continueLabel));
        RuntimeValue item = source switch
        {
            RuntimeDynamicIntArray array => EmitDynamicArrayLoad(array, index),
            RuntimeDynamicInlineArray array => EmitDynamicInlineArrayLoad(array, index),
            _ => throw new SollangException("tryParallel expects a growable array")
        };

        RuntimeEnum errorResult;
        string errorResultLabel;
        var outerLocals = CaptureLocals();
        try
        {
            _locals[statement.ItemName] = item;
            var callbackLocals = CaptureLocals();
            EmitStatements(statement.Body.Take(statement.Body.Count - 1).ToArray());
            var mapped = EmitExpression(callbackResult.Expression) as RuntimeEnum
                ?? throw new SollangException("tryParallel callback must return Result<R, E>");
            EnsureRuntimeType(mapped, callbackResultType, "tryParallel callback");
            var tag = NextTemp("try_parallel_tag");
            EmitAssign(tag, $"extractvalue {LlvmEnumType(mapped.Type)} {mapped.ValueName}, 0");
            var isError = NextTemp("try_parallel_is_error");
            EmitCompare(isError, "eq", "i32", tag, "1");
            var errorLabel = NextLabel("try_parallel_error");
            var okLabel = NextLabel("try_parallel_ok");
            EmitConditionalBranch(isError, errorLabel, okLabel);

            EmitLabel(okLabel);
            _currentBlockLabel = okLabel;
            var successful = ExtractEnumPayload(mapped, callbackTypes.Ok);
            switch (resultArray)
            {
                case RuntimeDynamicIntArray integers:
                    StoreDynamicArrayElement(integers.PointerName, index, ((RuntimeInt)successful).ValueName);
                    break;
                case RuntimeDynamicInlineArray inline:
                    StoreDynamicInlineArrayElement(
                        inline.PointerName,
                        _program.Types.GetDynamicArray(inline.Type),
                        index,
                        successful);
                    break;
            }
            DropOwnedLocalsCreatedSince(callbackLocals, transferredOwnerName: null);
            EmitBranch(continueLabel);

            EmitLabel(errorLabel);
            _currentBlockLabel = errorLabel;
            var error = ExtractEnumPayload(mapped, callbackTypes.Error);
            DropOwnedLocalsCreatedSince(callbackLocals, transferredOwnerName: null);
            EmitDropTryParallelPrefix(outputPointer, callbackTypes.Ok, index);
            var outerDefinition = _program.Types.GetEnum(function.ReturnType);
            var errorVariant = outerDefinition.Variants.First(variant => variant.Name == "Err");
            errorResult = EmitEnumValue(function.ReturnType, errorVariant, error);
            errorResultLabel = _currentBlockLabel;
            EmitBranch(mergeLabel);
        }
        finally
        {
            RestoreLocals(outerLocals);
        }

        EmitLabel(continueLabel);
        _currentBlockLabel = continueLabel;
        EmitBinary(next, "add", "i64", index, "1");
        var done = NextTemp("try_parallel_done");
        EmitCompare(done, "eq", "i64", next, length);
        EmitConditionalBranch(done, successLabel, bodyLabel);

        EmitLabel(successLabel);
        _currentBlockLabel = successLabel;
        var resultDefinition = _program.Types.GetEnum(function.ReturnType);
        var okVariant = resultDefinition.Variants.First(variant => variant.Name == "Ok");
        var successResult = EmitEnumValue(function.ReturnType, okVariant, resultArray);
        var successResultLabel = _currentBlockLabel;
        EmitBranch(mergeLabel);

        EmitLabel(mergeLabel);
        _currentBlockLabel = mergeLabel;
        var result = EmitEnumPhi(
            "try_parallel_result",
            function.ReturnType,
            [(errorResult, errorResultLabel), (successResult, successResultLabel)]);
        BindParallelResult(statement, result);
    }

    private void EmitComputeGroupField(string group, int index, string type, string value)
    {
        var slot = NextTemp("compute_group_slot");
        EmitInstruction($"{slot} = getelementptr %sollang.compute_group, ptr {group}, i32 0, i32 {index.ToString(CultureInfo.InvariantCulture)}");
        EmitStore(type, value, slot, 8);
    }

    private RuntimeEnum EmitCollectTryParallelResults(
        string group,
        BoundFunction function,
        RuntimeValue resultArray,
        string outputPointer,
        string callbackResults,
        string initialized,
        string length,
        BoundType callbackResultType,
        (BoundType Ok, BoundType Error) callbackTypes,
        int callbackStride)
    {
        var groupFailureSlot = NextTemp("try_parallel_failure_slot");
        EmitInstruction($"{groupFailureSlot} = getelementptr %sollang.compute_group, ptr {group}, i32 0, i32 11");
        var failureIndex = NextTemp("try_parallel_failure_index");
        EmitInstruction($"{failureIndex} = load atomic i64, ptr {groupFailureSlot} acquire, align 8");
        var hasFailure = NextTemp("try_parallel_has_failure");
        EmitCompare(hasFailure, "ult", "i64", failureIndex, length);
        var errorLabel = NextLabel("try_parallel_collect_error");
        var successLabel = NextLabel("try_parallel_collect_success");
        var mergeLabel = NextLabel("try_parallel_collect_merge");
        EmitConditionalBranch(hasFailure, errorLabel, successLabel);

        EmitLabel(errorLabel);
        _currentBlockLabel = errorLabel;
        var selected = EmitLoadTryParallelCallbackResult(
            callbackResults, failureIndex, callbackResultType, callbackStride, "try_parallel_selected");
        var errorPayload = ExtractEnumPayload(selected, callbackTypes.Error);
        EmitDropInitializedTryParallelResults(
            callbackResults,
            initialized,
            length,
            failureIndex,
            callbackResultType,
            callbackTypes,
            callbackStride);
        EmitCall(target: null, "void", "sollang_free", $"ptr {callbackResults}");
        EmitCall(target: null, "void", "sollang_free", $"ptr {initialized}");
        EmitCall(target: null, "void", "sollang_free", $"ptr {outputPointer}");
        var resultDefinition = _program.Types.GetEnum(function.ReturnType);
        var errorVariant = resultDefinition.Variants.First(variant => variant.Name == "Err");
        var errorResult = EmitEnumValue(function.ReturnType, errorVariant, errorPayload);
        var errorResultLabel = _currentBlockLabel;
        EmitBranch(mergeLabel);

        EmitLabel(successLabel);
        _currentBlockLabel = successLabel;
        var copyLoopLabel = NextLabel("try_parallel_copy_loop");
        var copyBodyLabel = NextLabel("try_parallel_copy_body");
        var copyDoneLabel = NextLabel("try_parallel_copy_done");
        var copyEntryLabel = _currentBlockLabel;
        var copyNext = NextTemp("try_parallel_copy_next");
        EmitBranch(copyLoopLabel);
        EmitLabel(copyLoopLabel);
        _currentBlockLabel = copyLoopLabel;
        var copyIndex = NextTemp("try_parallel_copy_i");
        EmitPhi(copyIndex, "i64", ("0", copyEntryLabel), (copyNext, copyBodyLabel));
        var copyInRange = NextTemp("try_parallel_copy_in_range");
        EmitCompare(copyInRange, "ult", "i64", copyIndex, length);
        EmitConditionalBranch(copyInRange, copyBodyLabel, copyDoneLabel);
        EmitLabel(copyBodyLabel);
        _currentBlockLabel = copyBodyLabel;
        var callbackResult = EmitLoadTryParallelCallbackResult(
            callbackResults, copyIndex, callbackResultType, callbackStride, "try_parallel_copy_result");
        var successful = ExtractEnumPayload(callbackResult, callbackTypes.Ok);
        switch (resultArray)
        {
            case RuntimeDynamicIntArray integers:
                StoreDynamicArrayElement(integers.PointerName, copyIndex, ((RuntimeInt)successful).ValueName);
                break;
            case RuntimeDynamicInlineArray inline:
                StoreDynamicInlineArrayElement(
                    inline.PointerName,
                    _program.Types.GetDynamicArray(inline.Type),
                    copyIndex,
                    successful);
                break;
        }
        EmitBinary(copyNext, "add", "i64", copyIndex, "1");
        EmitBranch(copyLoopLabel);
        EmitLabel(copyDoneLabel);
        _currentBlockLabel = copyDoneLabel;
        EmitCall(target: null, "void", "sollang_free", $"ptr {callbackResults}");
        EmitCall(target: null, "void", "sollang_free", $"ptr {initialized}");
        var okVariant = resultDefinition.Variants.First(variant => variant.Name == "Ok");
        var successResult = EmitEnumValue(function.ReturnType, okVariant, resultArray);
        var successResultLabel = _currentBlockLabel;
        EmitBranch(mergeLabel);

        EmitLabel(mergeLabel);
        _currentBlockLabel = mergeLabel;
        return EmitEnumPhi(
            "try_parallel_collected",
            function.ReturnType,
            [(errorResult, errorResultLabel), (successResult, successResultLabel)]);
    }

    private RuntimeEnum EmitLoadTryParallelCallbackResult(
        string pointer,
        string index,
        BoundType resultType,
        int stride,
        string prefix)
    {
        var offset = NextTemp(prefix + "_offset");
        EmitInstruction($"{offset} = mul i64 {index}, {stride.ToString(CultureInfo.InvariantCulture)}");
        var address = NextTemp(prefix + "_address");
        EmitInstruction($"{address} = getelementptr i8, ptr {pointer}, i64 {offset}");
        var loaded = NextTemp(prefix + "_value");
        EmitLoad(loaded, LlvmEnumType(resultType), address, RuntimeAlignment(resultType));
        return new RuntimeEnum(resultType, loaded);
    }

    private void EmitDropInitializedTryParallelResults(
        string callbackResults,
        string initialized,
        string length,
        string selectedIndex,
        BoundType callbackResultType,
        (BoundType Ok, BoundType Error) callbackTypes,
        int callbackStride)
    {
        if (!_program.Types.ContainsOwnedStorage(callbackTypes.Ok)
            && !_program.Types.ContainsOwnedStorage(callbackTypes.Error))
        {
            return;
        }

        var entryLabel = _currentBlockLabel;
        var loopLabel = NextLabel("try_parallel_cleanup_loop");
        var inspectLabel = NextLabel("try_parallel_cleanup_inspect");
        var okLabel = NextLabel("try_parallel_cleanup_ok");
        var errorLabel = NextLabel("try_parallel_cleanup_error");
        var nextLabel = NextLabel("try_parallel_cleanup_next");
        var doneLabel = NextLabel("try_parallel_cleanup_done");
        var next = NextTemp("try_parallel_cleanup_next_i");
        EmitBranch(loopLabel);
        EmitLabel(loopLabel);
        _currentBlockLabel = loopLabel;
        var index = NextTemp("try_parallel_cleanup_i");
        EmitPhi(index, "i64", ("0", entryLabel), (next, nextLabel));
        var inRange = NextTemp("try_parallel_cleanup_in_range");
        EmitCompare(inRange, "ult", "i64", index, length);
        var checkLabel = NextLabel("try_parallel_cleanup_check");
        EmitConditionalBranch(inRange, checkLabel, doneLabel);
        EmitLabel(checkLabel);
        _currentBlockLabel = checkLabel;
        var flagAddress = NextTemp("try_parallel_cleanup_flag_address");
        EmitInstruction($"{flagAddress} = getelementptr i8, ptr {initialized}, i64 {index}");
        var flag = NextTemp("try_parallel_cleanup_flag");
        EmitInstruction($"{flag} = load atomic i8, ptr {flagAddress} acquire, align 1");
        var wasInitialized = NextTemp("try_parallel_cleanup_initialized");
        EmitCompare(wasInitialized, "ne", "i8", flag, "0");
        var isSelected = NextTemp("try_parallel_cleanup_selected");
        EmitCompare(isSelected, "eq", "i64", index, selectedIndex);
        var notSelected = NextTemp("try_parallel_cleanup_not_selected");
        EmitInstruction($"{notSelected} = xor i1 {isSelected}, true");
        var shouldInspect = NextTemp("try_parallel_cleanup_should_inspect");
        EmitInstruction($"{shouldInspect} = and i1 {wasInitialized}, {notSelected}");
        EmitConditionalBranch(shouldInspect, inspectLabel, nextLabel);

        EmitLabel(inspectLabel);
        _currentBlockLabel = inspectLabel;
        var value = EmitLoadTryParallelCallbackResult(
            callbackResults, index, callbackResultType, callbackStride, "try_parallel_cleanup_result");
        var tag = NextTemp("try_parallel_cleanup_tag");
        EmitAssign(tag, $"extractvalue {LlvmEnumType(callbackResultType)} {value.ValueName}, 0");
        var isError = NextTemp("try_parallel_cleanup_is_error");
        EmitCompare(isError, "eq", "i32", tag, "1");
        EmitConditionalBranch(isError, errorLabel, okLabel);

        EmitLabel(okLabel);
        _currentBlockLabel = okLabel;
        if (_program.Types.ContainsOwnedStorage(callbackTypes.Ok))
        {
            DropOwnedRuntimeValue(ExtractEnumPayload(value, callbackTypes.Ok));
        }
        EmitBranch(nextLabel);

        EmitLabel(errorLabel);
        _currentBlockLabel = errorLabel;
        if (_program.Types.ContainsOwnedStorage(callbackTypes.Error))
        {
            DropOwnedRuntimeValue(ExtractEnumPayload(value, callbackTypes.Error));
        }
        EmitBranch(nextLabel);

        EmitLabel(nextLabel);
        _currentBlockLabel = nextLabel;
        EmitBinary(next, "add", "i64", index, "1");
        EmitBranch(loopLabel);
        EmitLabel(doneLabel);
        _currentBlockLabel = doneLabel;
    }

    private void EmitDropTryParallelPrefix(string pointer, BoundType elementType, string length)
    {
        if (_program.Types.ContainsOwnedStorage(elementType))
        {
            var entryLabel = _currentBlockLabel;
            var loopLabel = NextLabel("try_parallel_drop_loop");
            var bodyLabel = NextLabel("try_parallel_drop_body");
            var endLabel = NextLabel("try_parallel_drop_end");
            var next = NextTemp("try_parallel_drop_next");
            EmitBranch(loopLabel);
            EmitLabel(loopLabel);
            _currentBlockLabel = loopLabel;
            var index = NextTemp("try_parallel_drop_i");
            EmitPhi(index, "i64", ("0", entryLabel), (next, bodyLabel));
            var inRange = NextTemp("try_parallel_drop_in_range");
            EmitCompare(inRange, "ult", "i64", index, length);
            EmitConditionalBranch(inRange, bodyLabel, endLabel);
            EmitLabel(bodyLabel);
            _currentBlockLabel = bodyLabel;
            var address = NextTemp("try_parallel_drop_address");
            EmitAssign(address, $"getelementptr {LlvmType(elementType)}, ptr {pointer}, i64 {index}");
            var loaded = NextTemp("try_parallel_drop_value");
            EmitLoad(loaded, LlvmType(elementType), address, RuntimeAlignment(elementType));
            DropOwnedRuntimeValue(DematerializeAggregateValue(elementType, loaded));
            EmitBinary(next, "add", "i64", index, "1");
            EmitBranch(loopLabel);
            EmitLabel(endLabel);
            _currentBlockLabel = endLabel;
        }
        EmitCall(target: null, "void", "sollang_free", $"ptr {pointer}");
    }

    private string EmitHeapAllocateProduct(string count, string stride, string name)
    {
        var bytes = NextTemp(name);
        EmitBinary(bytes, "mul", "i64", count, stride);
        return EmitHeapAllocate(bytes);
    }

    private void EmitWhileBlockFunctionCall(BlockFunctionCallStatement statement)
    {
        if (HasPlannedCfgSuspension(statement.Body))
        {
            EmitAsyncWhileBlockFunctionCall(statement);
            return;
        }

        var conditionLabel = NextLabel("while_condition");
        var bodyLabel = NextLabel("while_body");
        var endLabel = NextLabel("while_end");
        EmitBranch(conditionLabel);

        EmitLabel(conditionLabel);
        _currentBlockLabel = conditionLabel;
        var condition = EmitExpression(statement.Source) as RuntimeBool
            ?? throw new SollangException("while condition must be Bool");
        EmitConditionalBranch(condition.ValueName, bodyLabel, endLabel);

        EmitLabel(bodyLabel);
        _currentBlockLabel = bodyLabel;
        var outerLocals = CaptureLocals();
        try
        {
            EmitLoopBody(statement.Body, outerLocals, conditionLabel, endLabel);
        }
        finally
        {
            RestoreLocals(outerLocals);
        }
        if (!_currentBlockTerminated)
        {
            EmitBranch(conditionLabel);
        }

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
    }

    private bool HasPlannedCfgSuspension(IReadOnlyList<Statement> statements)
    {
        if (_activeAsyncCfg is not { } lowering)
        {
            return false;
        }

        var candidates = new List<AsyncCfgCandidate>();
        CollectCfgSuspensions(statements, nested: true, candidates);
        if (candidates.Any(candidate => lowering.Plan.BySite.ContainsKey(candidate.Site)))
        {
            return true;
        }
        // An inline block producer contains value -> yield, while the async
        // suspension site belongs to the original caller callback body.
        if (_currentBlockInvocation is { } invocation)
        {
            candidates.Clear();
            CollectCfgSuspensions(invocation.Body, nested: true, candidates);
            if (candidates.Any(candidate => lowering.Plan.BySite.ContainsKey(candidate.Site)))
                return true;
        }
        var sink = _currentStreamContinuation;
        while (sink is not null)
        {
            if (sink is RuntimeStreamConsumer consumer)
            {
                candidates.Clear();
                CollectCfgSuspensions(consumer.Invocation.Body, nested: true, candidates);
                return candidates.Any(candidate => lowering.Plan.BySite.ContainsKey(candidate.Site));
            }
            sink = sink switch
            {
                RuntimeStreamStage stage => stage.Next,
                RuntimeUserStreamStage stage => stage.Next,
                _ => null
            };
        }
        return false;
    }

    private void EmitAsyncWhileBlockFunctionCall(BlockFunctionCallStatement statement)
    {
        EmitAsyncLoop(
            statement.Body,
            () => EmitExpression(statement.Source) as RuntimeBool
                ?? throw new SollangException("while condition must be Bool"));
    }

    private void EmitAsyncRangeEachBlockFunctionCall(
        BlockFunctionCallStatement statement,
        RuntimeStruct range)
    {
        var start = NextTemp("range_start");
        var end = NextTemp("range_end");
        var llvmType = LlvmStructType(BoundType.Range);
        EmitAssign(start, $"extractvalue {llvmType} {range.ValueName}, 0");
        EmitAssign(end, $"extractvalue {llvmType} {range.ValueName}, 1");
        EmitAsyncIntEachBlockFunctionCall(statement, new RuntimeInt(start), new RuntimeInt(end));
    }

    private RuntimeStreamSink BindAsyncStreamArguments(RuntimeStreamSink sink)
    {
        IReadOnlyList<string> CaptureArguments(
            BlockFunctionCallStatement call, RuntimeStreamCallSite callSite,
            IReadOnlyList<RuntimeValue> arguments)
        {
            var names = new string[arguments.Count];
            for (var index = 0; index < arguments.Count; index++)
            {
                var name = NextAsyncBindingName("stream_argument");
                names[index] = name;
                callSite.Locals.Locals.Add(name, arguments[index]);
                callSite.Locals.BorrowedOwnedLocals.Add(name);
                RetainAsyncIteratorTemporaries((call.Arguments ?? [])[index], arguments[index]);
            }
            return names;
        }
        return sink switch
        {
            RuntimeStreamStage stage => stage with
            {
                AdditionalArgumentNames = CaptureArguments(stage.Call, stage.CallSite, stage.AdditionalArguments),
                Next = BindAsyncStreamArguments(stage.Next)
            },
            RuntimeUserStreamStage stage => stage with { Next = BindAsyncStreamArguments(stage.Next) },
            RuntimeStreamTerminalStage stage => stage with
            {
                AdditionalArgumentNames = CaptureArguments(stage.Call, stage.CallSite, stage.AdditionalArguments)
            },
            _ => sink
        };
    }

    private bool HasAsyncStreamSuspension(RuntimeStreamSink sink)
    {
        if (_activeAsyncCfg is null)
            return false;
        return sink switch
        {
            RuntimeStreamConsumer consumer => HasPlannedCfgSuspension(consumer.Invocation.Body),
            RuntimeStreamStage stage => HasPlannedCfgSuspension(stage.Function.BlockBody)
                || HasPlannedCfgSuspension(stage.Call.Body) || HasAsyncStreamSuspension(stage.Next),
            RuntimeUserStreamStage stage => HasPlannedCfgSuspension(stage.Function.BlockBody)
                || HasPlannedCfgSuspension(stage.Call.Body) || HasAsyncStreamSuspension(stage.Next),
            RuntimeStreamTerminalStage stage => HasPlannedCfgSuspension(stage.Function.BlockBody)
                || HasPlannedCfgSuspension(stage.Call.Body),
            _ => false
        };
    }

    private static IEnumerable<LocalScope> AsyncInvocationContinuationScopes(RuntimeBlockInvocation invocation)
    {
        yield return invocation.CallerLocals;
        foreach (var scope in invocation.CallerAsyncScopes ?? []) yield return scope;
    }

    private static IEnumerable<LocalScope> AsyncCallSiteContinuationScopes(RuntimeStreamCallSite callSite)
    {
        yield return callSite.Locals;
        foreach (var scope in callSite.AsyncScopes ?? []) yield return scope;
    }

    private static IEnumerable<LocalScope> AsyncStreamContinuationScopes(RuntimeStreamSink sink)
    {
        switch (sink)
        {
            case RuntimeStreamConsumer consumer:
                foreach (var scope in AsyncInvocationContinuationScopes(consumer.Invocation)) yield return scope;
                break;
            case RuntimeStreamStage stage:
                foreach (var scope in AsyncCallSiteContinuationScopes(stage.CallSite)) yield return scope;
                foreach (var scope in AsyncStreamContinuationScopes(stage.Next)) yield return scope;
                break;
            case RuntimeUserStreamStage stage:
                yield return stage.StateLocals;
                foreach (var scope in AsyncCallSiteContinuationScopes(stage.CallSite)) yield return scope;
                foreach (var scope in AsyncStreamContinuationScopes(stage.Next)) yield return scope;
                break;
            case RuntimeStreamTerminalStage stage:
                foreach (var scope in AsyncCallSiteContinuationScopes(stage.CallSite)) yield return scope;
                break;
            default:
                throw new SollangException("unknown runtime stream sink");
        }
    }

    private IEnumerable<LocalScope> CurrentAsyncContinuationScopes()
    {
        if (_currentBlockInvocation is { } invocation)
            foreach (var scope in AsyncInvocationContinuationScopes(invocation)) yield return scope;
        if (_currentStreamContinuation is { } continuation)
            foreach (var scope in AsyncStreamContinuationScopes(continuation)) yield return scope;
    }

    private string RegisterAsyncProducerOwner(RuntimeProducerStream source)
    {
        var name = NextAsyncBindingName("stream_owner");
        _locals.Add(name, source);
        return name;
    }

    private RuntimeProducerStream ResolveAsyncProducerOwner(string name) =>
        ResolveLocal(name) as RuntimeProducerStream
        ?? throw new SollangException("async stream owner lost its canonical producer shape");

    private void DropAsyncProducerOwners(IReadOnlyList<string> names)
    {
        foreach (var name in names)
        {
            DropOwnedRuntimeValue(ResolveAsyncProducerOwner(name));
            RemoveLocal(name);
        }
    }

    private RuntimeBool EmitAsyncStreamPull(
        string sourceName, string address, string cancellationSlot)
    {
        var cancelled = NextTemp("async_stream_cancelled");
        EmitLoad(cancelled, "i1", ResolveAsyncStreamCancellationSlot(cancellationSlot), 1);
        var cancelledLabel = NextLabel("async_stream_cancelled");
        var pullLabel = NextLabel("async_stream_pull");
        var joinLabel = NextLabel("async_stream_pull_result");
        EmitConditionalBranch(cancelled, cancelledLabel, pullLabel);
        EmitLabel(cancelledLabel);
        EmitBranch(joinLabel);
        EmitLabel(pullLabel);
        var source = ResolveAsyncProducerOwner(sourceName);
        var available = NextTemp("async_stream_available");
        EmitIndirectCall(available, "i1", source.NextName,
            $"ptr {source.ContextName}, ptr {address}");
        EmitBranch(joinLabel);
        EmitLabel(joinLabel);
        _currentBlockLabel = joinLabel;
        var result = NextTemp("async_stream_pull_result");
        EmitPhi(result, "i1", ("false", cancelledLabel), (available, pullLabel));
        return new RuntimeBool(result);
    }

    private void EmitAsyncProducerLoop(
        IReadOnlyList<RuntimeProducerStream> sources,
        RuntimeStreamSink sink,
        string cancellationSlot,
        Action<RuntimeValue>? emitItem = null,
        IReadOnlyList<RuntimeStreamSink>? continuationSinks = null)
    {
        var names = sources.Select(RegisterAsyncProducerOwner).ToArray();
        if (sources.Count == 0 || sources.Any(source => source.ElementType != sources[0].ElementType))
            throw new SollangException("async concatenation requires homogeneous producer elements");
        var cursor = RegisterAsyncStreamCursor();
        var type = sources[0].ElementType;
        var address = NextTemp("async_stream_element");
        EmitAlloca(address, LlvmType(type), RuntimeAlignment(type));
        EmitAsyncLoop([], () => EmitAsyncConcatPull(names, cursor, address, cancellationSlot),
            emitBody: () =>
            {
                var item = LoadAsyncStreamElement(type, address);
                if (emitItem is null) EmitStreamValue(item, sink);
                else emitItem(item);
            }, futureScopes: continuationSinks is null
                ? AsyncStreamContinuationScopes(sink)
                : continuationSinks.SelectMany(AsyncStreamContinuationScopes));
        ForgetAsyncSpillCarrier(cursor);
        DropAsyncProducerOwners(names);
    }

    private string RegisterAsyncStreamCursor()
    {
        var name = NextAsyncBindingName("stream_cursor");
        _locals.Add(name, new RuntimeInt(BoundType.Int, "0"));
        CreateResumedMutableSlot(name, _locals[name]);
        return name;
    }

    private RuntimeBool EmitAsyncConcatPull(
        IReadOnlyList<string> owners, string cursor, string address, string cancellationSlot)
    {
        var join = NextLabel("async_concat_ready");
        var incoming = new List<(string Value, string Label)>();
        for (var index = 0; index < owners.Count; index++)
        {
            var selected = NextLabel("async_concat_selected");
            var next = NextLabel("async_concat_scan");
            var position = (RuntimeInt)ResolveLocal(cursor);
            var matches = NextTemp("async_concat_cursor");
            EmitCompare(matches, "eq", LlvmType(position.Type), position.ValueName, index.ToString(CultureInfo.InvariantCulture));
            EmitConditionalBranch(matches, selected, next);
            EmitLabel(selected);
            _currentBlockLabel = selected;
            var available = EmitAsyncStreamPull(owners[index], address, cancellationSlot);
            var ready = NextLabel("async_concat_value");
            var exhausted = NextLabel("async_concat_exhausted");
            EmitConditionalBranch(available.ValueName, ready, exhausted);
            EmitLabel(ready);
            _currentBlockLabel = ready;
            incoming.Add(("true", ready));
            EmitBranch(join);
            EmitLabel(exhausted);
            _currentBlockLabel = exhausted;
            EmitStore(LlvmType(position.Type), (index + 1).ToString(CultureInfo.InvariantCulture),
                _mutableScalarSlots[cursor], RuntimeAlignment(position.Type));
            EmitBranch(next);
            EmitLabel(next);
            _currentBlockLabel = next;
        }
        incoming.Add(("false", _currentBlockLabel));
        EmitBranch(join);
        EmitLabel(join);
        _currentBlockLabel = join;
        var result = NextTemp("async_concat_ready");
        EmitPhi(result, "i1", incoming.ToArray());
        return new RuntimeBool(result);
    }

    private void EmitAsyncStreamBranch(RuntimeBool condition, Action selected, Action? rejected = null)
    {
        var entry = CaptureLocals();
        var continuationScopes = CaptureAsyncContinuationBranchScopes();
        var continuationEdges = new List<(LocalScope[] Scopes, string Label)>();
        var selectedLabel = NextLabel("async_stream_selected");
        var rejectedLabel = NextLabel("async_stream_rejected");
        var join = NextLabel("async_stream_join");
        var incoming = new List<(LocalScope Scope, string Label)>();
        EmitConditionalBranch(condition.ValueName, selectedLabel, rejectedLabel);
        EmitLabel(selectedLabel);
        _currentBlockLabel = selectedLabel;
        selected();
        if (!_currentBlockTerminated)
        {
            incoming.Add((CaptureLocals(), _currentBlockLabel));
            continuationEdges.Add((SnapshotAsyncContinuationScopes(continuationScopes), _currentBlockLabel));
            EmitBranch(join);
        }
        RestoreLocals(entry);
        RestoreAsyncContinuationScopes(continuationScopes);
        EmitLabel(rejectedLabel);
        _currentBlockLabel = rejectedLabel;
        rejected?.Invoke();
        if (!_currentBlockTerminated)
        {
            incoming.Add((CaptureLocals(), _currentBlockLabel));
            continuationEdges.Add((SnapshotAsyncContinuationScopes(continuationScopes), _currentBlockLabel));
            EmitBranch(join);
        }
        EmitLabel(join);
        _currentBlockLabel = join;
        MergeAsyncOuterScope(entry, incoming);
        MergeAsyncContinuationScopes(continuationScopes, continuationEdges, entry, incoming);
    }

    private string RegisterAsyncStreamActive()
    {
        var name = NextAsyncBindingName("stream_active");
        _locals.Add(name, new RuntimeBool("true"));
        CreateResumedMutableSlot(name, _locals[name]);
        return name;
    }

    private RuntimeBool EmitAsyncStreamAnyActive(IReadOnlyList<string> names)
    {
        string? active = null;
        foreach (var name in names)
        {
            var value = (RuntimeBool)ResolveLocal(name);
            if (active is null)
                active = value.ValueName;
            else
            {
                var combined = NextTemp("async_stream_any_active");
                EmitBinary(combined, "or", "i1", active, value.ValueName);
                active = combined;
            }
        }
        return new RuntimeBool(active ?? "false");
    }

    private RuntimeValue LoadAsyncStreamElement(BoundType type, string address)
    {
        var loaded = NextTemp("async_stream_element_value");
        EmitLoad(loaded, LlvmType(type), address, RuntimeAlignment(type));
        return DematerializeAggregateValue(type, loaded);
    }

    private RuntimeStruct BuildAsyncStreamProduct(
        BoundType productType, IReadOnlyList<RuntimeValue> values)
    {
        var aggregate = "poison";
        for (var index = 0; index < values.Count; index++)
        {
            var field = MaterializeAggregateValue(values[index]);
            var next = NextTemp("async_stream_product");
            EmitAssign(next,
                $"insertvalue {LlvmStructType(productType)} {aggregate}, {field.TypeName} {field.ValueName}, {index.ToString(CultureInfo.InvariantCulture)}");
            aggregate = next;
        }
        return new RuntimeStruct(productType, aggregate);
    }

    private void EmitAsyncJoinedStream(
        BoundStreamJoinPipeline pipeline,
        IReadOnlyList<RuntimeProducerStream> sources,
        RuntimeStreamSink sink,
        string cancellationSlot)
    {
        if (pipeline.Join.Policy is not (StreamJoinPolicy.Zip or StreamJoinPolicy.Merge or StreamJoinPolicy.Latest))
            throw new InvalidOperationException("async joined stream requires zip, merge, or latest");
        var owners = sources.Select(RegisterAsyncProducerOwner).ToArray();
        var addresses = sources.Select(source =>
        {
            var address = NextTemp("async_join_element");
            EmitAlloca(address, LlvmType(source.ElementType), RuntimeAlignment(source.ElementType));
            return address;
        }).ToArray();
        if (pipeline.Join.Policy == StreamJoinPolicy.Zip)
        {
            EmitAsyncLoop([], () =>
            {
                var failed = NextLabel("async_zip_failed");
                var completed = NextLabel("async_zip_completed");
                var join = NextLabel("async_zip_ready");
                var failures = sources.Select((_, index) =>
                    index == 0 ? failed : NextLabel("async_zip_partial")).ToArray();
                for (var index = 0; index < sources.Count; index++)
                {
                    var available = EmitAsyncStreamPull(owners[index], addresses[index], cancellationSlot);
                    var next = index == sources.Count - 1 ? completed : NextLabel("async_zip_pull");
                    EmitConditionalBranch(available.ValueName, next, failures[index]);
                    if (index != sources.Count - 1)
                    {
                        EmitLabel(next);
                        _currentBlockLabel = next;
                    }
                }
                EmitLabel(completed);
                EmitBranch(join);
                for (var index = 1; index < sources.Count; index++)
                {
                    EmitLabel(failures[index]);
                    _currentBlockLabel = failures[index];
                    for (var previous = index - 1; previous >= 0; previous--)
                        DropOwnedRuntimeValue(LoadAsyncStreamElement(sources[previous].ElementType, addresses[previous]));
                    EmitBranch(failed);
                }
                EmitLabel(failed);
                EmitBranch(join);
                EmitLabel(join);
                _currentBlockLabel = join;
                var ready = NextTemp("async_zip_ready");
                EmitPhi(ready, "i1", ("true", completed), ("false", failed));
                return new RuntimeBool(ready);
            }, emitBody: () => EmitStreamValue(BuildAsyncStreamProduct(pipeline.Join.OutputElementType,
                sources.Select((source, index) => LoadAsyncStreamElement(source.ElementType, addresses[index])).ToArray()), sink),
                futureScopes: AsyncStreamContinuationScopes(sink));
            DropAsyncProducerOwners(owners);
            return;
        }

        var activeNames = sources.Select(_ => RegisterAsyncStreamActive()).ToArray();
        var cacheNames = sources.Select(_ => NextAsyncBindingName("latest_value")).ToArray();
        var end = NextLabel("async_join_done");
        if (pipeline.Join.Policy == StreamJoinPolicy.Latest)
        {
            // The semantic owner rejects non-Copy elements for latest. Install
            // each cache only after a successful pull; no poison/uninitialized
            // cache crosses a suspension or becomes an owned drop responsibility.
            for (var index = 0; index < sources.Count; index++)
            {
                var available = EmitAsyncStreamPull(owners[index], addresses[index], cancellationSlot);
                var initialized = NextLabel("async_latest_initialized");
                var empty = NextLabel("async_latest_empty");
                EmitConditionalBranch(available.ValueName, initialized, empty);
                EmitLabel(empty);
                _currentBlockLabel = empty;
                foreach (var owner in owners)
                    DropOwnedRuntimeValue(ResolveAsyncProducerOwner(owner));
                EmitBranch(end);
                EmitLabel(initialized);
                _currentBlockLabel = initialized;
                _locals.Add(cacheNames[index], LoadAsyncStreamElement(sources[index].ElementType, addresses[index]));
            }
        }
        var cursor = RegisterAsyncStreamCursor();
        var readyName = RegisterAsyncStreamActive();
        EmitStore("i1", "false", _mutableScalarSlots[readyName], 1);
        var firstName = pipeline.Join.Policy == StreamJoinPolicy.Latest ? RegisterAsyncStreamActive() : null;
        EmitAsyncLoop([], () =>
        {
            var active = EmitAsyncStreamAnyActive(activeNames);
            if (firstName is null) return active;
            var condition = NextTemp("async_latest_first_or_active");
            EmitBinary(condition, "or", "i1", ((RuntimeBool)ResolveLocal(firstName)).ValueName, active.ValueName);
            return new RuntimeBool(condition);
        }, emitBody: () =>
        {
            EmitStore("i1", "false", _mutableScalarSlots[readyName], 1);
            void Poll()
            {
                EmitAsyncJoinedStreamPoll(pipeline.Join.Policy, sources, owners, addresses,
                    activeNames, cacheNames, cursor, readyName, cancellationSlot);
            }
            if (firstName is null) Poll();
            else EmitAsyncStreamBranch((RuntimeBool)ResolveLocal(firstName), () =>
            {
                EmitStore("i1", "false", _mutableScalarSlots[firstName], 1);
                EmitStore("i1", "true", _mutableScalarSlots[readyName], 1);
            }, Poll);
            EmitAsyncStreamBranch((RuntimeBool)ResolveLocal(readyName), () =>
                EmitStreamValue(pipeline.Join.Policy == StreamJoinPolicy.Latest
                    ? BuildAsyncStreamProduct(pipeline.Join.OutputElementType, cacheNames.Select(ResolveLocal).ToArray())
                    : LoadAsyncStreamElement(pipeline.Join.OutputElementType, addresses[0]), sink));
        }, futureScopes: AsyncStreamContinuationScopes(sink));
        DropAsyncProducerOwners(owners);
        foreach (var name in activeNames.Concat(cacheNames))
            ForgetAsyncSpillCarrier(name);
        ForgetAsyncSpillCarrier(cursor);
        ForgetAsyncSpillCarrier(readyName);
        if (firstName is not null) ForgetAsyncSpillCarrier(firstName);
        EmitBranch(end);
        EmitLabel(end);
        _currentBlockLabel = end;
    }

    private void EmitAsyncJoinedStreamPoll(
        StreamJoinPolicy policy,
        IReadOnlyList<RuntimeProducerStream> sources,
        IReadOnlyList<string> owners,
        IReadOnlyList<string> addresses,
        IReadOnlyList<string> activeNames,
        IReadOnlyList<string> cacheNames,
        string cursor, string readyName, string cancellationSlot)
    {
        var position = (RuntimeInt)ResolveLocal(cursor);
        for (var index = 0; index < sources.Count; index++)
        {
            var selected = index;
            var matches = NextTemp("async_join_cursor");
            EmitCompare(matches, "eq", LlvmType(position.Type), position.ValueName, index.ToString(CultureInfo.InvariantCulture));
            EmitAsyncStreamBranch(new RuntimeBool(matches), () =>
            {
                EmitStore(LlvmType(position.Type), ((selected + 1) % sources.Count).ToString(CultureInfo.InvariantCulture),
                    _mutableScalarSlots[cursor], RuntimeAlignment(position.Type));
                EmitAsyncStreamBranch((RuntimeBool)ResolveLocal(activeNames[selected]), () =>
                {
                    var address = policy == StreamJoinPolicy.Merge ? addresses[0] : addresses[selected];
                    var available = EmitAsyncStreamPull(owners[selected], address, cancellationSlot);
                    EmitAsyncStreamBranch(available, () =>
                    {
                        if (policy == StreamJoinPolicy.Latest)
                            _locals[cacheNames[selected]] = LoadAsyncStreamElement(sources[selected].ElementType, address);
                        EmitStore("i1", "true", _mutableScalarSlots[readyName], 1);
                    }, () => EmitStore("i1", "false", _mutableScalarSlots[activeNames[selected]], 1));
                });
            });
        }
    }

    private string NextAsyncBindingName(string role) => ".async." + NextLabel(role);

    private void EmitAsyncIntEachBlockFunctionCall(
        BlockFunctionCallStatement statement, RuntimeInt start, RuntimeInt end)
    {
        var indexName = NextAsyncBindingName("each_index");
        var endName = NextAsyncBindingName("each_limit");
        // The hidden cursor must represent the position after Int.MaxValue.
        // Source elements remain Int; the wider cursor is ordinary spill state.
        var wideStart = NextTemp("async_each_start");
        var wideEnd = NextTemp("async_each_end");
        EmitAssign(wideStart, $"sext i32 {start.ValueName} to i64");
        EmitAssign(wideEnd, $"sext i32 {end.ValueName} to i64");
        _locals.Add(indexName, new RuntimeInt(BoundType.Int64, wideStart));
        _locals.Add(endName, new RuntimeInt(BoundType.Int64, wideEnd));
        try
        {
            EmitAsyncLoop(
                statement.Body,
                () =>
                {
                    var current = (RuntimeInt)ResolveLocal(indexName);
                    var limit = (RuntimeInt)ResolveLocal(endName);
                    var condition = NextTemp("async_each_condition");
                    EmitCompare(condition, "sle", "i64", current.ValueName, limit.ValueName);
                    return new RuntimeBool(condition);
                },
                () =>
                {
                    var current = (RuntimeInt)ResolveLocal(indexName);
                    var item = NextTemp("async_each_item");
                    EmitAssign(item, $"trunc i64 {current.ValueName} to i32");
                    _locals[statement.ItemName] = new RuntimeInt(item);
                },
                () =>
                {
                    var current = (RuntimeInt)ResolveLocal(indexName);
                    var next = NextTemp("async_each_next");
                    EmitBinary(next, "add", "i64", current.ValueName, "1");
                    _locals[indexName] = new RuntimeInt(BoundType.Int64, next);
                });
        }
        finally
        {
            RemoveLocal(indexName);
            RemoveLocal(endName);
        }
    }

    private static string ArrayEachLength(RuntimeValue source) => source switch
    {
        RuntimeIntSlice slice => slice.LengthName,
        RuntimeInlineSlice slice => slice.LengthName,
        RuntimeStaticIntArray array => array.LengthName,
        RuntimeStaticTextArray array => array.LengthName,
        RuntimeStaticInlineArray array => array.LengthName,
        RuntimeDynamicIntArray array => array.LengthName,
        RuntimeDynamicInlineArray array => array.LengthName,
        RuntimeMappedBytes mapped => mapped.LengthName,
        RuntimeArguments arguments => arguments.LengthName,
        _ => throw new SollangException("each expects a range, Text, or array input")
    };

    private RuntimeValue ArrayEachItem(RuntimeValue source, string index) => source switch
    {
        RuntimeIntSlice slice => EmitIntSliceLoad(slice, index),
        RuntimeInlineSlice slice => EmitInlineSliceLoad(slice, index),
        RuntimeStaticIntArray array => EmitStaticArrayLoad(array, index),
        RuntimeStaticTextArray array => EmitStaticTextArrayLoad(array, index),
        RuntimeStaticInlineArray array => EmitStaticInlineArrayLoad(array, index),
        RuntimeDynamicIntArray array => EmitDynamicArrayLoad(array, index),
        RuntimeDynamicInlineArray array when _program.Types.IsDeque(array.ArrayType) =>
            EmitDequeLoadUnchecked(array, index, "deque_each_item"),
        RuntimeDynamicInlineArray array => EmitDynamicInlineArrayLoad(array, index),
        RuntimeMappedBytes mapped => EmitMappedLoad(mapped, index),
        RuntimeArguments => EmitArgumentLoad(index),
        _ => throw new SollangException("each expects a range, Text, or array input")
    };

    private RuntimeValue DictionaryEachItem(RuntimeValue source, string slot, bool bindKey)
    {
        if (source is RuntimeIntDictionary dictionary)
            return bindKey ? LoadDictionaryKey(dictionary, slot) : LoadDictionaryValue(dictionary, slot);
        if (source is not RuntimeInlineDictionary inline)
            throw new SollangException("dictionary iterator source was not lowered");
        var definition = _program.Types.GetDictionary(inline.DictionaryType);
        return bindKey
            ? LoadInlineDictionaryField(inline, slot, definition.KeyType, 0,
                definition.KeyAlignment, "dictionary_each_key")
            : LoadInlineDictionaryField(inline, slot, definition.ValueType,
                definition.ValueOffset, definition.ValueAlignment, "dictionary_each_value");
    }

    private void EmitAsyncIndexedBlockFunctionCall(
        BlockFunctionCallStatement statement,
        RuntimeValue source,
        Func<RuntimeValue, string> length,
        Func<RuntimeValue, string, RuntimeValue> item,
        Func<RuntimeValue, string, RuntimeBool>? occupied = null,
        RuntimeValue? ownershipSource = null)
    {
        var outer = CaptureLocals();
        var sourceName = NextAsyncBindingName("each_source");
        var indexName = NextAsyncBindingName("each_index");
        RetainAsyncIteratorTemporaries(statement.Source, ownershipSource ?? source);
        _locals.Add(sourceName, source);
        _locals.Add(indexName, new RuntimeInt(BoundType.Int64, "0"));
        // The iterator carrier always borrows its backing. Fresh backing is
        // retained separately by the canonical readonly-temporary tracker.
        _borrowedOwnedLocals.Add(sourceName);
        _asyncScopeSnapshots.Push(outer);
        try
        {
            EmitAsyncLoop(
                statement.Body,
                () =>
                {
                    var condition = NextTemp("async_each_condition");
                    EmitCompare(condition, "ult", "i64",
                        ((RuntimeInt)ResolveLocal(indexName)).ValueName,
                        length(ResolveLocal(sourceName)));
                    return new RuntimeBool(condition);
                },
                () =>
                {
                    var value = item(ResolveLocal(sourceName), ((RuntimeInt)ResolveLocal(indexName)).ValueName);
                    _locals[statement.ItemName] = value;
                    if (_program.Types.ContainsOwnedStorage(value.Type))
                        _borrowedOwnedLocals.Add(statement.ItemName);
                },
                () =>
                {
                    var next = NextTemp("async_each_next");
                    EmitBinary(next, "add", "i64", ((RuntimeInt)ResolveLocal(indexName)).ValueName, "1");
                    _locals[indexName] = new RuntimeInt(BoundType.Int64, next);
                },
                occupied is null ? null : () => occupied(
                    ResolveLocal(sourceName), ((RuntimeInt)ResolveLocal(indexName)).ValueName));
        }
        finally
        {
            _asyncScopeSnapshots.Pop();
            DropOwnedLocalsCreatedSince(outer, transferredOwnerName: null);
            RestoreLocals(outer);
        }
    }

    private void EmitAsyncTextEachBlockFunctionCall(BlockFunctionCallStatement statement, RuntimeText text)
    {
        var outer = CaptureLocals();
        var sourceName = NextAsyncBindingName("text_source");
        var indexName = NextAsyncBindingName("text_index");
        var widthName = NextAsyncBindingName("text_width");
        RetainAsyncIteratorTemporaries(statement.Source, text);
        _locals.Add(sourceName, text);
        _locals.Add(indexName, new RuntimeInt(BoundType.Int64, "0"));
        _locals.Add(widthName, new RuntimeInt(BoundType.Int64, "0"));
        _borrowedOwnedLocals.Add(sourceName);
        _asyncScopeSnapshots.Push(outer);
        try
        {
            EmitAsyncLoop(
                statement.Body,
                () =>
                {
                    var source = (RuntimeText)ResolveLocal(sourceName);
                    var condition = NextTemp("text_each_condition");
                    EmitCompare(condition, "ult", "i64", ((RuntimeInt)ResolveLocal(indexName)).ValueName, source.LengthName);
                    return new RuntimeBool(condition);
                },
                () =>
                {
                    var source = (RuntimeText)ResolveLocal(sourceName);
                    var packed = NextTemp("utf8_decoded");
                    EmitCall(packed, "i64", "sollang_utf8_decode",
                        $"ptr {source.PointerName}, i64 {source.LengthName}, i64 {((RuntimeInt)ResolveLocal(indexName)).ValueName}");
                    var valid = NextTemp("utf8_valid");
                    EmitCompare(valid, "ne", "i64", packed, "-1");
                    var decoded = NextLabel("text_each_decoded");
                    var invalid = NextLabel("text_each_invalid");
                    EmitConditionalBranch(valid, decoded, invalid);
                    EmitLabel(invalid);
                    _currentBlockLabel = invalid;
                    EmitTrap();
                    EmitLabel(decoded);
                    _currentBlockLabel = decoded;
                    var codePoint = NextTemp(statement.ItemName);
                    var width = NextTemp("utf8_width");
                    EmitAssign(codePoint, $"trunc i64 {packed} to i32");
                    EmitAssign(width, $"lshr i64 {packed}, 32");
                    _locals[statement.ItemName] = new RuntimeInt(BoundType.CodePoint, codePoint);
                    _locals[widthName] = new RuntimeInt(BoundType.Int64, width);
                },
                () =>
                {
                    var next = NextTemp("text_each_next");
                    EmitBinary(next, "add", "i64",
                        ((RuntimeInt)ResolveLocal(indexName)).ValueName,
                        ((RuntimeInt)ResolveLocal(widthName)).ValueName);
                    _locals[indexName] = new RuntimeInt(BoundType.Int64, next);
                });
        }
        finally
        {
            _asyncScopeSnapshots.Pop();
            DropOwnedLocalsCreatedSince(outer, transferredOwnerName: null);
            RestoreLocals(outer);
        }
    }

    private void RetainAsyncIteratorTemporaries(Expression expression, RuntimeValue source)
    {
        var owners = new List<RuntimeValue>();
        TrackReadonlyCallTemporary(expression, source, owners);
        foreach (var owner in owners)
            _locals.Add(NextAsyncBindingName("iterator_owner"), owner);
    }

    private sealed record AsyncLoopCarryBinding(LocalScope Scope, string Name);

    private sealed record AsyncLoopCarryGroup(
        AsyncLoopCarryBinding Binding, List<AsyncLoopCarryBinding> Aliases);

    private static void PublishAsyncLoopCarry(
        AsyncLoopCarryGroup group, RuntimeValue value,
        string? scalar = null, string? structure = null,
        MutableContainerSlot? container = null, string? flag = null)
    {
        foreach (var binding in group.Aliases)
        {
            var scope = binding.Scope;
            var oldValue = scope.Locals[binding.Name];
            scope.Locals[binding.Name] = value;
            if (scalar is not null) scope.MutableScalarSlots[binding.Name] = scalar;
            if (structure is not null) scope.MutableStructSlots[binding.Name] = structure;
            if (container is not null) scope.MutableContainerSlots[binding.Name] = container;
            if (flag is not null) scope.BorrowedOwnedTransferFlags[binding.Name] = flag;
            for (var index = 0; index < scope.TerminatingOwnedCleanupObligations.Count; index++)
            {
                var obligation = scope.TerminatingOwnedCleanupObligations[index];
                if (obligation.BindingName == binding.Name && ReferenceEquals(obligation.Value, oldValue))
                    scope.TerminatingOwnedCleanupObligations[index] = obligation with
                    {
                        Value = value,
                        RetainedFlag = flag ?? obligation.RetainedFlag
                    };
            }
        }
    }

    private void EmitAsyncLoop(
        IReadOnlyList<Statement> body,
        Func<RuntimeBool> emitCondition,
        Action? bindItem = null,
        Action? advance = null,
        Func<RuntimeBool>? emitBodyCondition = null,
        Action? emitBody = null,
        IEnumerable<LocalScope>? futureScopes = null)
    {
        if (_activeAsyncCfg is null)
        {
            EmitAsyncLoopCore(body, emitCondition, bindItem, advance, emitBodyCondition, emitBody);
            return;
        }
        var registeredScopes = _asyncHiddenScopes
            .SelectMany(hidden => new[] { hidden.Scope }.Concat(hidden.Mirrors))
            .Concat(_asyncScopeSnapshots)
            .ToHashSet<LocalScope>(ReferenceEqualityComparer.Instance);
        var registrations = CurrentAsyncContinuationScopes().Concat(futureScopes ?? [])
            .Distinct<LocalScope>(ReferenceEqualityComparer.Instance)
            .Where(scope => !registeredScopes.Contains(scope))
            .Select(scope => new AsyncHiddenScope(scope, []))
            .ToArray();
        foreach (var registration in registrations) _asyncHiddenScopes.Push(registration);
        try
        {
            EmitAsyncLoopCore(body, emitCondition, bindItem, advance, emitBodyCondition, emitBody);
        }
        finally
        {
            for (var index = registrations.Length - 1; index >= 0; index--)
                if (!ReferenceEquals(_asyncHiddenScopes.Pop(), registrations[index]))
                    throw new SollangException("async loop continuation scope registration order changed");
        }
    }

    private void EmitAsyncLoopCore(
        IReadOnlyList<Statement> body,
        Func<RuntimeBool> emitCondition,
        Action? bindItem = null,
        Action? advance = null,
        Func<RuntimeBool>? emitBodyCondition = null,
        Action? emitBody = null)
    {
        if (_activeAsyncCfg is not { } lowering)
        {
            throw new SollangException("async while lowering requires an active CFG plan");
        }
        var entryLabel = _currentBlockLabel;
        var initialScope = CaptureLocals();
        var continuationScopes = CaptureAsyncContinuationBranchScopes(includeLoopSnapshots: true);
        var carryScope = SnapshotAsyncContinuationScope(initialScope);
        var continuationCarryScopes = continuationScopes
            .Select(item => SnapshotAsyncContinuationScope(item.Entry)).ToArray();
        var groups = new List<AsyncLoopCarryGroup>();
        foreach (var scope in new[] { carryScope }.Concat(continuationCarryScopes))
        {
            foreach (var name in scope.Locals.Keys)
            {
                if (AsyncScopeSharesBinding(scope, name, lowering.ResumeBaseLocals, name)) continue;
                var binding = new AsyncLoopCarryBinding(scope, name);
                var group = groups.FirstOrDefault(candidate => AsyncScopeSharesBinding(
                    candidate.Binding.Scope, candidate.Binding.Name, scope, name));
                if (group is null) groups.Add(new AsyncLoopCarryGroup(binding, [binding]));
                else group.Aliases.Add(binding);
            }
        }
        var continueEdges = new List<(LocalScope Scope, string Label)>
        {
            (initialScope, entryLabel)
        };
        var breakEdges = new List<(LocalScope Scope, string Label)>();
        var continuationContinueEdges = new List<(LocalScope[] Scopes, string Label)>
        {
            (continuationScopes.Select(item => item.Entry).ToArray(), entryLabel)
        };
        var continuationBreakEdges = new List<(LocalScope[] Scopes, string Label)>();
        void CaptureContinuationEdge(LoopControlKind kind, string label)
        {
            var edges = kind == LoopControlKind.Continue
                ? continuationContinueEdges : continuationBreakEdges;
            edges.Add((SnapshotAsyncContinuationScopes(continuationScopes), label));
        }
        var carriedNames = initialScope.Locals.Keys
            .Where(name => !AsyncScopeSharesBinding(initialScope, name, lowering.ResumeBaseLocals, name))
            .ToArray();
        var immutableCarries = new List<(
            AsyncLoopCarryGroup Group,
            string Name,
            BoundType Type,
            string LlvmType,
            string EntryValue,
            string NextValue)>();
        var scalarCarries = new List<(AsyncLoopCarryGroup Group, string Name, string EntryPointer, string NextPointer)>();
        var structCarries = new List<(AsyncLoopCarryGroup Group, string Name, string EntryPointer, string NextPointer)>();
        var containerCarries = new List<(
            AsyncLoopCarryGroup Group,
            string Name,
            MutableContainerSlot Entry,
            string NextPointer,
            string NextLength,
            string NextCapacity)>();
        var flagCarries = new List<(AsyncLoopCarryGroup Group, string Entry, string Next)>();

        foreach (var group in groups)
        {
            var scope = group.Binding.Scope;
            var name = group.Binding.Name;
            if (scope.BorrowedOwnedTransferFlags.TryGetValue(name, out var flag))
                flagCarries.Add((group, flag, NextTemp("async_loop_transfer_flag_next")));
            if (!scope.MutableLocals.Contains(name))
            {
                var value = scope.Locals[name];
                var materialized = MaterializeAggregateValue(value);
                immutableCarries.Add((
                    group,
                    name,
                    value.Type,
                    materialized.TypeName,
                    materialized.ValueName,
                    NextTemp($"async_loop_{name}_next")));
                continue;
            }
            var prefix = name.TrimEnd('!');
            if (scope.MutableScalarSlots.TryGetValue(name, out var scalar))
            {
                scalarCarries.Add((group, name, scalar, NextTemp($"async_loop_{prefix}_slot_next")));
                continue;
            }
            if (scope.MutableStructSlots.TryGetValue(name, out var structure))
            {
                structCarries.Add((group, name, structure, NextTemp($"async_loop_{prefix}_struct_next")));
                continue;
            }
            if (scope.MutableContainerSlots.TryGetValue(name, out var container))
            {
                containerCarries.Add((
                    group,
                    name,
                    container,
                    NextTemp($"async_loop_{prefix}_ptr_next"),
                    NextTemp($"async_loop_{prefix}_len_next"),
                    NextTemp($"async_loop_{prefix}_capacity_next")));
                continue;
            }
            throw new SollangException(
                $"mutable loop-carried binding '{name}' has no storage slot");
        }

        var conditionLabel = NextLabel("async_while_condition");
        var bodyLabel = NextLabel("async_while_body");
        var continueLabel = NextLabel("async_while_continue");
        var endLabel = NextLabel("async_while_end");
        // The statically-false edge makes the continue block a valid CFG
        // predecessor even when every source path breaks on its first
        // iteration. LLVM removes it, while the phi shape stays uniform.
        EmitConditionalBranch("false", continueLabel, conditionLabel);

        EmitLabel(conditionLabel);
        _currentBlockLabel = conditionLabel;
        var immutableHeaderValues = new List<(AsyncLoopCarryGroup Group, BoundType Type, string Value)>();
        foreach (var carry in immutableCarries)
        {
            var value = NextTemp($"async_loop_{carry.Name}");
            EmitPhi(
                value,
                carry.LlvmType,
                (carry.EntryValue, entryLabel),
                (carry.NextValue, continueLabel));
            immutableHeaderValues.Add((carry.Group, carry.Type, value));
        }
        foreach (var carry in scalarCarries)
        {
            var pointer = NextTemp($"async_loop_{carry.Name.TrimEnd('!')}_slot");
            EmitPhi(
                pointer,
                "ptr",
                (carry.EntryPointer, entryLabel),
                (carry.NextPointer, continueLabel));
            PublishAsyncLoopCarry(carry.Group, carry.Group.Binding.Scope.Locals[carry.Name], scalar: pointer);
        }
        foreach (var carry in structCarries)
        {
            var pointer = NextTemp($"async_loop_{carry.Name.TrimEnd('!')}_struct_slot");
            EmitPhi(
                pointer,
                "ptr",
                (carry.EntryPointer, entryLabel),
                (carry.NextPointer, continueLabel));
            PublishAsyncLoopCarry(carry.Group, carry.Group.Binding.Scope.Locals[carry.Name], structure: pointer);
        }
        foreach (var carry in containerCarries)
        {
            var prefix = carry.Name.TrimEnd('!');
            var pointer = NextTemp($"async_loop_{prefix}_ptr_slot");
            EmitPhi(
                pointer,
                "ptr",
                (carry.Entry.PointerAddress, entryLabel),
                (carry.NextPointer, continueLabel));
            var length = NextTemp($"async_loop_{prefix}_len_slot");
            EmitPhi(
                length,
                "ptr",
                (carry.Entry.LengthAddress, entryLabel),
                (carry.NextLength, continueLabel));
            var capacity = NextTemp($"async_loop_{prefix}_capacity_slot");
            EmitPhi(
                capacity,
                "ptr",
                (carry.Entry.CapacityAddress, entryLabel),
                (carry.NextCapacity, continueLabel));
            var slot = new MutableContainerSlot(
                pointer,
                length,
                capacity,
                StackAllocation: null);
            PublishAsyncLoopCarry(carry.Group, carry.Group.Binding.Scope.Locals[carry.Name], container: slot);
        }
        foreach (var carry in flagCarries)
        {
            var flag = NextTemp("async_loop_transfer_flag");
            EmitPhi(flag, "ptr", (carry.Entry, entryLabel), (carry.Next, continueLabel));
            PublishAsyncLoopCarry(carry.Group,
                carry.Group.Binding.Scope.Locals[carry.Group.Binding.Name], flag: flag);
        }

        foreach (var (group, type, value) in immutableHeaderValues)
        {
            PublishAsyncLoopCarry(group, DematerializeAggregateValue(type, value));
        }
        RestoreLocals(carryScope);
        for (var index = 0; index < continuationScopes.Count; index++)
            ReplaceAsyncContinuationScope(continuationScopes[index].Scope, continuationCarryScopes[index]);
        var headerContinuations = continuationScopes.Select(item => new AsyncContinuationBranchScope(
            item.Scope, SnapshotAsyncContinuationScope(item.Scope))).ToArray();

        var headerScope = CaptureLocals();
        var condition = emitCondition();
        var conditionExitLabel = _currentBlockLabel;
        var conditionExitScope = CaptureLocals();
        var conditionExitContinuations = SnapshotAsyncContinuationScopes(continuationScopes);
        EmitConditionalBranch(condition.ValueName, bodyLabel, endLabel);

        EmitLabel(bodyLabel);
        _currentBlockLabel = bodyLabel;
        if (emitBodyCondition is not null)
        {
            var bodyCondition = emitBodyCondition();
            var selectedLabel = NextLabel("async_loop_selected_body");
            continueEdges.Add((CaptureLocals(), _currentBlockLabel));
            CaptureContinuationEdge(LoopControlKind.Continue, _currentBlockLabel);
            EmitConditionalBranch(bodyCondition.ValueName, selectedLabel, continueLabel);
            EmitLabel(selectedLabel);
            _currentBlockLabel = selectedLabel;
        }
        bindItem?.Invoke();
        var loopBodyScope = CaptureLocals();
        _asyncScopeSnapshots.Push(loopBodyScope);
        LocalScope bodyExitScope;
        try
        {
            EmitLoopBody(
                body,
                loopBodyScope,
                continueLabel,
                endLabel,
                continueEdges,
                breakEdges,
                emitBody,
                CaptureContinuationEdge);
            bodyExitScope = CaptureLocals();
        }
        finally
        {
            _asyncScopeSnapshots.Pop();
        }
        if (!_currentBlockTerminated)
        {
            var bodyExitLabel = _currentBlockLabel;
            var nextScope = SnapshotAsyncContinuationScope(headerScope);
            foreach (var name in carriedNames)
            {
                if (!bodyExitScope.Locals.ContainsKey(name))
                {
                    throw new SollangException(
                        $"loop-carried binding '{name}' is consumed on the back-edge");
                }
                RestoreAsyncLoopBinding(nextScope, bodyExitScope, name);
            }
            RestoreLocals(nextScope);
            continueEdges.Add((CaptureLocals(), bodyExitLabel));
            CaptureContinuationEdge(LoopControlKind.Continue, bodyExitLabel);
            EmitBranch(continueLabel);
        }

        EmitLabel(continueLabel);
        _currentBlockLabel = continueLabel;
        MergeAsyncLoopScopes(headerScope, continueEdges, headerContinuations, continuationContinueEdges);
        advance?.Invoke();
        var mergedScope = CaptureLocals();
        LocalScope CurrentCarryScope(AsyncLoopCarryGroup group) =>
            ReferenceEquals(group.Binding.Scope, carryScope)
                ? mergedScope
                : continuationScopes[Array.FindIndex(continuationCarryScopes,
                    scope => ReferenceEquals(scope, group.Binding.Scope))].Scope;
        foreach (var carry in immutableCarries)
        {
            var current = MaterializeAggregateValue(CurrentCarryScope(carry.Group).Locals[carry.Name]);
            EmitAssign(
                carry.NextValue,
                $"select i1 true, {carry.LlvmType} {current.ValueName}, {carry.LlvmType} {current.ValueName}");
        }
        foreach (var carry in scalarCarries)
        {
            EmitAssign(
                carry.NextPointer,
                $"getelementptr i8, ptr {CurrentCarryScope(carry.Group).MutableScalarSlots[carry.Name]}, i64 0");
        }
        foreach (var carry in structCarries)
        {
            EmitAssign(
                carry.NextPointer,
                $"getelementptr i8, ptr {CurrentCarryScope(carry.Group).MutableStructSlots[carry.Name]}, i64 0");
        }
        foreach (var carry in containerCarries)
        {
            var slot = CurrentCarryScope(carry.Group).MutableContainerSlots[carry.Name];
            EmitAssign(carry.NextPointer, $"getelementptr i8, ptr {slot.PointerAddress}, i64 0");
            EmitAssign(carry.NextLength, $"getelementptr i8, ptr {slot.LengthAddress}, i64 0");
            EmitAssign(carry.NextCapacity, $"getelementptr i8, ptr {slot.CapacityAddress}, i64 0");
        }
        foreach (var carry in flagCarries)
            EmitAssign(carry.Next,
                $"getelementptr i8, ptr {CurrentCarryScope(carry.Group).BorrowedOwnedTransferFlags[carry.Group.Binding.Name]}, i64 0");
        EmitBranch(conditionLabel);

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        var exitEdges = new List<(LocalScope Scope, string Label)>
        {
            (conditionExitScope, conditionExitLabel)
        };
        exitEdges.AddRange(breakEdges);
        var continuationExitEdges = new List<(LocalScope[] Scopes, string Label)>
        {
            (conditionExitContinuations, conditionExitLabel)
        };
        continuationExitEdges.AddRange(continuationBreakEdges);
        MergeAsyncLoopScopes(headerScope, exitEdges, headerContinuations, continuationExitEdges);
    }

    private void EmitDictionaryEachBlockFunctionCall(
        BlockFunctionCallStatement statement,
        bool bindKey,
        RuntimeValue? preparedSource = null)
    {
        var sourceValue = preparedSource ?? EmitExpression(statement.Source);
        RuntimeValue source = sourceValue is RuntimeIntDictionaryView view
            ? new RuntimeIntDictionary(view.PointerName, view.LengthName, view.CapacityName)
            : sourceValue;
        var capacity = source switch
        {
            RuntimeIntDictionary dictionary => dictionary.CapacityName,
            RuntimeInlineDictionary dictionary => dictionary.CapacityName,
            _ => throw new SollangException($"{(bindKey ? "eachKey" : "eachValue")} expects a dictionary input")
        };

        if (HasPlannedCfgSuspension(statement.Body))
        {
            EmitAsyncIndexedBlockFunctionCall(
                statement, source,
                value => value switch
                {
                    RuntimeIntDictionary dictionary => dictionary.CapacityName,
                    RuntimeInlineDictionary dictionary => dictionary.CapacityName,
                    _ => throw new SollangException("dictionary iterator source was not lowered")
                },
                (value, slot) => DictionaryEachItem(value, slot, bindKey),
                (value, slot) =>
                {
                    var control = value switch
                    {
                        RuntimeIntDictionary dictionary => LoadDictionaryControl(dictionary, slot),
                        RuntimeInlineDictionary dictionary => LoadInlineDictionaryControl(dictionary, slot),
                        _ => throw new SollangException("dictionary iterator source was not lowered")
                    };
                    var occupied = NextTemp("dictionary_each_occupied");
                    EmitCompare(occupied, "sgt", "i8", control, "0");
                    return new RuntimeBool(occupied);
                },
                ownershipSource: sourceValue);
            return;
        }

        var loopLabel = NextLabel("dictionary_each");
        var bodyLabel = NextLabel("dictionary_each_body");
        var continueLabel = NextLabel("dictionary_each_continue");
        var endLabel = NextLabel("dictionary_each_end");
        var entryLabel = _currentBlockLabel;
        var next = NextTemp("dictionary_each_next");
        var empty = NextTemp("dictionary_each_empty");
        EmitCompare(empty, "eq", "i64", capacity, "0");
        EmitConditionalBranch(empty, endLabel, loopLabel);
        EmitFunctionLine();

        EmitLabel(loopLabel);
        _currentBlockLabel = loopLabel;
        var slot = NextTemp("dictionary_each_slot");
        EmitPhi(slot, "i64", ("0", entryLabel), (next, continueLabel));
        var control = source switch
        {
            RuntimeIntDictionary dictionary => LoadDictionaryControl(dictionary, slot),
            RuntimeInlineDictionary dictionary => LoadInlineDictionaryControl(dictionary, slot),
            _ => throw new SollangException("dictionary iterator source was not lowered")
        };
        var occupied = NextTemp("dictionary_each_occupied");
        EmitCompare(occupied, "sgt", "i8", control, "0");
        EmitConditionalBranch(occupied, bodyLabel, continueLabel);
        EmitFunctionLine();

        EmitLabel(bodyLabel);
        _currentBlockLabel = bodyLabel;
        var item = DictionaryEachItem(source, slot, bindKey);

        var outerLocals = CaptureLocals();
        try
        {
            _locals[statement.ItemName] = item;
            if (_program.Types.ContainsOwnedStorage(item.Type))
            {
                _borrowedOwnedLocals.Add(statement.ItemName);
            }
            EmitLoopBody(statement.Body, outerLocals, continueLabel, endLabel);
        }
        finally
        {
            RestoreLocals(outerLocals);
        }
        if (!_currentBlockTerminated)
        {
            EmitBranch(continueLabel);
        }
        EmitFunctionLine();

        EmitLabel(continueLabel);
        _currentBlockLabel = continueLabel;
        EmitBinary(next, "add", "i64", slot, "1");
        var done = NextTemp("dictionary_each_done");
        EmitCompare(done, "eq", "i64", next, capacity);
        EmitConditionalBranch(done, endLabel, loopLabel);
        EmitFunctionLine();
        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
    }

    private void EmitTextEachBlockFunctionCall(BlockFunctionCallStatement statement, RuntimeText text)
    {
        if (HasPlannedCfgSuspension(statement.Body))
        {
            EmitAsyncTextEachBlockFunctionCall(statement, text);
            return;
        }
        var bodyLabel = NextLabel("text_each_body");
        var continueLabel = NextLabel("text_each_continue");
        var invalidLabel = NextLabel("text_each_invalid");
        var endLabel = NextLabel("text_each_end");
        var entryLabel = _currentBlockLabel;
        var nextIndex = NextTemp("text_each_next");
        var initialDone = NextTemp("text_each_done");

        EmitCompare(initialDone, "eq", "i64", text.LengthName, "0");
        EmitConditionalBranch(initialDone, endLabel, bodyLabel);

        EmitLabel(bodyLabel);
        _currentBlockLabel = bodyLabel;
        var index = NextTemp("text_each_i");
        EmitPhi(index, "i64", ("0", entryLabel), (nextIndex, continueLabel));
        var packed = NextTemp("utf8_decoded");
        EmitCall(packed, "i64", "sollang_utf8_decode",
            $"ptr {text.PointerName}, i64 {text.LengthName}, i64 {index}");
        var valid = NextTemp("utf8_valid");
        EmitCompare(valid, "ne", "i64", packed, "-1");
        var decodedLabel = NextLabel("text_each_decoded");
        EmitConditionalBranch(valid, decodedLabel, invalidLabel);

        EmitLabel(invalidLabel);
        EmitTrap();

        EmitLabel(decodedLabel);
        _currentBlockLabel = decodedLabel;
        var codePoint = NextTemp(statement.ItemName);
        EmitAssign(codePoint, $"trunc i64 {packed} to i32");
        var width = NextTemp("utf8_width");
        EmitAssign(width, $"lshr i64 {packed}, 32");

        var outerLocals = CaptureLocals();
        try
        {
            _locals[statement.ItemName] = new RuntimeInt(BoundType.CodePoint, codePoint);
            EmitLoopBody(statement.Body, outerLocals, continueLabel, endLabel);
        }
        finally
        {
            RestoreLocals(outerLocals);
        }

        if (!_currentBlockTerminated)
        {
            EmitBranch(continueLabel);
        }
        EmitLabel(continueLabel);
        _currentBlockLabel = continueLabel;
        EmitBinary(nextIndex, "add", "i64", index, width);
        var done = NextTemp("text_each_done");
        EmitCompare(done, "uge", "i64", nextIndex, text.LengthName);
        EmitConditionalBranch(done, endLabel, bodyLabel);
        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
    }

    private void EmitRepeatBlockFunctionCall(BlockFunctionCallStatement statement)
    {
        var count = EmitIntExpression(statement.Source);
        if (HasPlannedCfgSuspension(statement.Body))
        {
            EmitAsyncIntEachBlockFunctionCall(statement, new RuntimeInt("1"), count);
            return;
        }
        var bodyLabel = NextLabel("repeat_body");
        var continueLabel = NextLabel("repeat_continue");
        var endLabel = NextLabel("repeat_end");
        var entryLabel = _currentBlockLabel;
        var next = NextTemp("repeat_next");
        var initialDone = NextTemp("repeat_done");

        EmitCompare(initialDone, "sle", "i32", count.ValueName, "0");
        EmitConditionalBranch(initialDone, endLabel, bodyLabel);

        EmitLabel(bodyLabel);
        _currentBlockLabel = bodyLabel;
        var item = NextTemp(statement.ItemName);
        EmitPhi(item, "i32", ("1", entryLabel), (next, continueLabel));

        var outerLocals = CaptureLocals();
        try
        {
            _locals[statement.ItemName] = new RuntimeInt(item);
            EmitLoopBody(statement.Body, outerLocals, continueLabel, endLabel);
        }
        finally
        {
            RestoreLocals(outerLocals);
        }

        if (!_currentBlockTerminated)
        {
            EmitBranch(continueLabel);
        }
        EmitLabel(continueLabel);
        _currentBlockLabel = continueLabel;
        EmitBinary(next, "add", "i32", item, "1");
        var done = NextTemp("repeat_done");
        EmitCompare(done, "sge", "i32", item, count.ValueName);
        EmitConditionalBranch(done, endLabel, bodyLabel);
        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
    }

}
