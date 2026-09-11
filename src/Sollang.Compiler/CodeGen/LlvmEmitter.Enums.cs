using System.Globalization;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Semantics;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private bool TryEmitEnumConstructor(CallExpression expression, out RuntimeValue value)
    {
        value = null!;
        if (expression.Path.Count < 2
            || !_program.Types.TryResolveInModule(string.Join('.', expression.Path.Take(expression.Path.Count - 1)), _currentFunction?.ModuleName, out var type)
            || !_program.Types.IsEnum(type))
        {
            return false;
        }

        var definition = _program.Types.GetEnum(type);
        var variantName = expression.Path[^1];
        var variant = definition.Variants.FirstOrDefault(candidate => candidate.Name == variantName)
            ?? throw new SollangException($"enum '{definition.Name}' has no variant '{variantName}'");
        var payloadType = variant.PayloadType
            ?? throw new SollangException($"payload-free variant '{definition.Name}.{variant.Name}' uses member syntax without parentheses");
        var payload = EmitFunctionArgumentExpression(expression.Arguments[0], payloadType);
        EnsureRuntimeType(payload, payloadType, $"{definition.Name}.{variant.Name}");
        value = EmitEnumValue(type, variant, payload);
        if (_program.Types.ContainsOwnedStorage(payloadType))
        {
            RemoveOwnedLiteralSources(expression.Arguments[0], payloadType);
        }
        return true;
    }

    private bool TryEmitPayloadlessEnumVariant(FieldAccessExpression expression, out RuntimeValue value)
    {
        value = null!;
        if (expression.Source is not NameExpression typeName
            || _locals.ContainsKey(typeName.Name)
            || !_program.Types.TryResolveInModule(typeName.Name, _currentFunction?.ModuleName, out var type)
            || !_program.Types.IsEnum(type))
        {
            return false;
        }

        var definition = _program.Types.GetEnum(type);
        var variant = definition.Variants.FirstOrDefault(candidate => candidate.Name == expression.FieldName)
            ?? throw new SollangException($"enum '{definition.Name}' has no variant '{expression.FieldName}'");
        if (variant.PayloadType is { } payloadType
            && payloadType != BoundType.Unit)
        {
            throw new SollangException($"variant '{definition.Name}.{variant.Name}' requires a payload argument");
        }

        value = EmitEnumValue(
            type,
            variant,
            variant.PayloadType == BoundType.Unit ? RuntimeUnit.Instance : null);
        return true;
    }

    private RuntimeEnum EmitEnumValue(BoundType type, BoundEnumVariant variant, RuntimeValue? payload)
    {
        var llvmType = LlvmEnumType(type);
        var slot = NextTemp("enum_init_slot");
        EmitAlloca(slot, llvmType, 8);
        EmitStore(llvmType, "zeroinitializer", slot, 8);
        var tagAddress = NextTemp("enum_tag_addr");
        EmitAssign(tagAddress, $"getelementptr inbounds {llvmType}, ptr {slot}, i32 0, i32 0");
        EmitStore("i32", variant.Tag.ToString(CultureInfo.InvariantCulture), tagAddress, 4);

        // Unit is a semantic payload but has no runtime storage. Treat it like
        // the native try lowering does: the variant tag carries the complete
        // value and no zero-width payload field is materialized.
        if (payload is not null and not RuntimeUnit)
        {
            var payloadAddress = NextTemp("enum_payload_addr");
            EmitAssign(payloadAddress, $"getelementptr inbounds {llvmType}, ptr {slot}, i32 0, i32 1");
            var materialized = MaterializeAggregateValue(payload);
            EmitStore(materialized.TypeName, materialized.ValueName, payloadAddress, RuntimeAlignment(payload.Type));
        }

        var aggregate = NextTemp("enum_value");
        EmitLoad(aggregate, llvmType, slot, 8);
        return new RuntimeEnum(type, aggregate);
    }

    private RuntimeValue EmitEnumMatchExpression(
        EnumMatchExpression expression,
        BoundType? expectedResultType = null)
    {
        var subject = EmitExpression(expression.Subject) as RuntimeEnum
            ?? throw new SollangException("enum when expects a runtime enum subject");
        var definition = _program.Types.GetEnum(subject.Type);
        var tag = NextTemp("enum_tag");
        EmitAssign(tag, $"extractvalue {LlvmEnumType(subject.Type)} {subject.ValueName}, 0");

        var ownsStorage = _program.Types.ContainsOwnedStorage(subject.Type);
        var anonymousSubject = IsAnonymousOwnedExpression(expression.Subject);
        var armTransfers = expression.Arms.ToDictionary(
            arm => arm,
            arm => arm.Condition is EnumPatternExpression { BindingName: { } bindingName } pattern
                && definition.Variants.First(candidate => candidate.Name == pattern.VariantName).PayloadType is { } payloadType
                && _program.Types.ContainsOwnedStorage(payloadType)
                && TransfersOwnerName(arm.Body, bindingName, payloadType));
        var subjectOwnerName = expression.Subject switch
        {
            NameExpression name => name.Name,
            FieldAccessExpression { Source: NameExpression owner } => owner.Name,
            _ => null
        };
        var outerOwnedLocals = _locals
            .Where(local => !string.Equals(local.Key, subjectOwnerName, StringComparison.Ordinal)
                && local.Value != subject
                && !_borrowedOwnedLocals.Contains(local.Key)
                && !_mutableLocals.Contains(local.Key)
                && _program.Types.ContainsOwnedStorage(local.Value.Type))
            .ToDictionary(static local => local.Key, static local => local.Value, StringComparer.Ordinal);
        var transfersAnyPayload = armTransfers.Values.Any(static transfers => transfers);
        var removedNamedSubject = false;
        RuntimeStruct? removedProjectedOwner = null;
        BoundStructField? projectedSubjectField = null;
        if (ownsStorage
            && transfersAnyPayload
            && expression.Subject is NameExpression subjectName)
        {
            foreach (var alias in _locals
                .Where(local => local.Value == subject)
                .Select(static local => local.Key)
                .Append(subjectName.Name)
                .Distinct(StringComparer.Ordinal)
                .ToArray())
            {
                RemoveLocal(alias);
            }
            removedNamedSubject = true;
        }
        else if (ownsStorage
            && transfersAnyPayload
            && expression.Subject is FieldAccessExpression
            {
                Source: NameExpression ownerName,
                FieldName: var fieldName
            }
            && !_mutableLocals.Contains(ownerName.Name)
            && !_borrowedOwnedLocals.Contains(ownerName.Name)
            && _locals.TryGetValue(ownerName.Name, out var ownerValue)
            && ownerValue is RuntimeStruct ownerStruct
            && _program.Types.IsStruct(ownerStruct.Type)
            && _program.Types.GetStruct(ownerStruct.Type).Fields.FirstOrDefault(
                field => string.Equals(field.Name, fieldName, StringComparison.Ordinal)) is { } ownerField
            && ownerField.Type == subject.Type)
        {
            removedProjectedOwner = ownerStruct;
            projectedSubjectField = ownerField;
            RemoveLocal(ownerName.Name);
        }

        var entryScope = CaptureLocals();
        var endLabel = NextLabel("enum_when_end");
        var valueResults = new List<(RuntimeValue Value, string Label)>();
        var scopeResults = new List<(LocalScope Scope, string Label)>();
        var continuingPaths = new List<EnumContinuingPath>();
        var hasEndPredecessor = false;
        var nextConditionLabel = _currentBlockLabel;
        foreach (var arm in expression.Arms)
        {
            RestoreLocals(entryScope);
            _currentBlockLabel = nextConditionLabel;
            var pattern = (EnumPatternExpression)arm.Condition;
            var variant = definition.Variants.First(candidate => candidate.Name == pattern.VariantName);
            var armLabel = NextLabel("enum_when_arm");
            var nextLabel = NextLabel("enum_when_next");
            var matches = NextTemp("enum_matches");
            EmitCompare(matches, "eq", "i32", tag, variant.Tag.ToString(CultureInfo.InvariantCulture));
            EmitConditionalBranch(matches, armLabel, nextLabel);

            EmitLabel(armLabel);
            _currentBlockLabel = armLabel;
            RuntimeValue? payload = null;
            string? payloadTransferFlag = null;
            if (variant.PayloadType is { } payloadType)
            {
                payload = ExtractEnumPayload(subject, payloadType);
                if (pattern.BindingName is not null
                    && _program.Types.ContainsOwnedStorage(payloadType))
                {
                    payloadTransferFlag = NextTemp("enum_payload_owned");
                    EmitAlloca(payloadTransferFlag, "i1", 1);
                    EmitStore("i1", "true", payloadTransferFlag, 1);
                }
            }

            var armResult = EmitEnumArmBody(
                arm.Body,
                pattern.BindingName,
                payload,
                payloadTransferFlag,
                expectedResultType);
            var armTerminated = _currentBlockTerminated;
            if (!armTerminated && removedProjectedOwner is not null)
            {
                if (payloadTransferFlag is not null)
                {
                    if (armTransfers[arm])
                    {
                        DropOwnedStructFieldsExcept(
                            removedProjectedOwner,
                            projectedSubjectField!.Name);
                    }
                    else
                    {
                        DropOwnedProjectedSubjectIfRetained(
                            payloadTransferFlag,
                            removedProjectedOwner,
                            projectedSubjectField!.Name);
                    }
                }
                else if (armTransfers[arm])
                {
                    DropOwnedStructFieldsExcept(removedProjectedOwner, projectedSubjectField!.Name);
                }
                else
                {
                    DropOwnedRuntimeValue(removedProjectedOwner);
                }
            }
            else if (!armTerminated
                && ownsStorage
                && (anonymousSubject || removedNamedSubject)
                && payloadTransferFlag is not null)
            {
                if (!armTransfers[arm])
                {
                    DropOwnedRuntimeValueIfRetained(payloadTransferFlag, subject);
                }
            }
            else if (!armTerminated
                && ownsStorage
                && (anonymousSubject || removedNamedSubject)
                && !armTransfers[arm])
            {
                DropOwnedRuntimeValue(subject);
            }
            if (!armTerminated)
            {
                continuingPaths.Add(new EnumContinuingPath(
                    armResult.Value,
                    armResult.ExitScope,
                    _currentBlockLabel,
                    _activeFunctions.CreateInsertionPoint()));
                EmitBranch(endLabel);
                hasEndPredecessor = true;
            }

            EmitLabel(nextLabel);
            nextConditionLabel = nextLabel;
        }

        _currentBlockLabel = nextConditionLabel;
        RestoreLocals(entryScope);
        if (expression.Else is not null)
        {
            var elseResult = EmitScopedBlockBody(expression.Else, expectedResultType);
            var elseTerminated = _currentBlockTerminated;
            if (!elseTerminated && removedProjectedOwner is not null)
            {
                DropOwnedRuntimeValue(removedProjectedOwner);
            }
            else if (!elseTerminated && ownsStorage && (anonymousSubject || removedNamedSubject))
            {
                DropOwnedRuntimeValue(subject);
            }
            if (!elseTerminated)
            {
                continuingPaths.Add(new EnumContinuingPath(
                    elseResult.Value,
                    elseResult.ExitScope,
                    _currentBlockLabel,
                    _activeFunctions.CreateInsertionPoint()));
                EmitBranch(endLabel);
                hasEndPredecessor = true;
            }
        }
        else
        {
            EmitTrap();
        }

        if (!hasEndPredecessor)
        {
            return RuntimeUnit.Instance;
        }

        NormalizeEnumOuterOwnerScopes(outerOwnedLocals, continuingPaths);
        foreach (var path in continuingPaths)
        {
            if (path.Value is not null)
            {
                valueResults.Add((path.Value, path.Label));
            }
            scopeResults.Add((path.Scope, path.Label));
        }

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        if (_activeAsyncCfg is not null)
        {
            MergeAsyncOuterScope(entryScope, scopeResults);
        }
        else
        {
            MergeSynchronousOuterScope(entryScope, scopeResults);
        }
        var result = valueResults.Count == 0
            ? RuntimeUnit.Instance
            : EmitPhiValue("enum_when", valueResults);
        return result;
    }

    private void NormalizeEnumOuterOwnerScopes(
        IReadOnlyDictionary<string, RuntimeValue> outerOwnedLocals,
        IReadOnlyList<EnumContinuingPath> continuingPaths)
    {
        if (continuingPaths.Count < 2 || outerOwnedLocals.Count == 0)
        {
            return;
        }

        var normalizedNames = new HashSet<string>(StringComparer.Ordinal);
        var previousFunctions = _activeFunctions;
        var previousLabel = _currentBlockLabel;
        var previousTerminated = _currentBlockTerminated;
        try
        {
            foreach (var (name, _) in outerOwnedLocals)
            {
                var presentPaths = continuingPaths
                    .Where(path => path.Scope.Locals.ContainsKey(name))
                    .ToArray();
                if (presentPaths.Length == 0 || presentPaths.Length == continuingPaths.Count)
                {
                    continue;
                }

                normalizedNames.Add(name);
                foreach (var path in presentPaths)
                {
                    _activeFunctions = path.Cleanup;
                    _currentBlockLabel = path.Label;
                    _currentBlockTerminated = false;
                    DropOwnedRuntimeValue(path.Scope.Locals[name]);
                    path.Label = _currentBlockLabel;
                }
            }
        }
        finally
        {
            _activeFunctions = previousFunctions;
            _currentBlockLabel = previousLabel;
            _currentBlockTerminated = previousTerminated;
        }

        if (normalizedNames.Count == 0)
        {
            return;
        }
        foreach (var path in continuingPaths)
        {
            path.Scope = RemoveLocalsFromScope(path.Scope, normalizedNames);
        }
    }

    private static LocalScope RemoveLocalsFromScope(LocalScope scope, IReadOnlySet<string> removed)
    {
        return new LocalScope(
            scope.Locals
                .Where(local => !removed.Contains(local.Key))
                .ToDictionary(static local => local.Key, static local => local.Value, StringComparer.Ordinal),
            scope.MutableLocals.Where(name => !removed.Contains(name)).ToHashSet(StringComparer.Ordinal),
            scope.BorrowedMutableLocals.Where(name => !removed.Contains(name)).ToHashSet(StringComparer.Ordinal),
            scope.BorrowedOwnedLocals.Where(name => !removed.Contains(name)).ToHashSet(StringComparer.Ordinal),
            scope.MovedOwnedStructFields
                .Where(item => !removed.Contains(item.Key))
                .ToDictionary(
                    static item => item.Key,
                    static item => new HashSet<string>(item.Value, StringComparer.Ordinal),
                    StringComparer.Ordinal),
            scope.MutableContainerSlots
                .Where(slot => !removed.Contains(slot.Key))
                .ToDictionary(static slot => slot.Key, static slot => slot.Value, StringComparer.Ordinal),
            scope.MutableStructSlots
                .Where(slot => !removed.Contains(slot.Key))
                .ToDictionary(static slot => slot.Key, static slot => slot.Value, StringComparer.Ordinal),
            scope.MutableScalarSlots
                .Where(slot => !removed.Contains(slot.Key))
                .ToDictionary(static slot => slot.Key, static slot => slot.Value, StringComparer.Ordinal),
            scope.ReadonlyCaptureBorrowPointers
                .Where(pointer => !removed.Contains(pointer.Key))
                .ToDictionary(static pointer => pointer.Key, static pointer => pointer.Value, StringComparer.Ordinal),
            scope.ReadonlyValueSlots);
    }

    private void DropOwnedStructFieldsExcept(RuntimeStruct owner, params string[] excludedFieldNames)
    {
        var definition = _program.Types.GetStruct(owner.Type);
        var llvmType = LlvmStructType(owner.Type);
        foreach (var field in definition.Fields.Where(field =>
                     !excludedFieldNames.Contains(field.Name, StringComparer.Ordinal)
                     && _program.Types.ContainsOwnedStorage(field.Type)))
        {
            var value = NextTemp("drop_remaining_field");
            EmitAssign(
                value,
                $"extractvalue {llvmType} {owner.ValueName}, {field.Index.ToString(CultureInfo.InvariantCulture)}");
            EmitOwnedDropCall(field.Type, value);
        }
    }

    private BlockResult EmitEnumArmBody(
        BlockBody body,
        string? bindingName,
        RuntimeValue? payload,
        string? payloadTransferFlag,
        BoundType? expectedResultType = null)
    {
        var outerLocals = CaptureLocals();
        string? previousTransferFlag = null;
        var hadPreviousTransferFlag = bindingName is not null
            && _borrowedOwnedTransferFlags.TryGetValue(bindingName, out previousTransferFlag);
        try
        {
            if (bindingName is not null && payload is not null)
            {
                _locals[bindingName] = payload;
                if (_program.Types.ContainsOwnedStorage(payload.Type))
                {
                    _borrowedOwnedLocals.Add(bindingName);
                    if (payloadTransferFlag is not null)
                    {
                        _borrowedOwnedTransferFlags[bindingName] = payloadTransferFlag;
                    }
                }
            }
            return EmitScopedBlockBody(body, expectedResultType);
        }
        finally
        {
            if (bindingName is not null)
            {
                if (hadPreviousTransferFlag)
                {
                    _borrowedOwnedTransferFlags[bindingName] = previousTransferFlag!;
                }
                else
                {
                    _borrowedOwnedTransferFlags.Remove(bindingName);
                }
            }
            RestoreLocals(outerLocals);
        }
    }

    private void DropOwnedRuntimeValueIfRetained(string retainedFlag, RuntimeValue value)
    {
        var retained = NextTemp("enum_payload_retained");
        EmitLoad(retained, "i1", retainedFlag, 1);
        var dropLabel = NextLabel("enum_payload_drop");
        var doneLabel = NextLabel("enum_payload_drop_done");
        EmitConditionalBranch(retained, dropLabel, doneLabel);
        EmitFunctionLine();
        EmitLabel(dropLabel);
        _currentBlockLabel = dropLabel;
        DropOwnedRuntimeValue(value);
        EmitBranch(doneLabel);
        EmitFunctionLine();
        EmitLabel(doneLabel);
        _currentBlockLabel = doneLabel;
    }

    private void DropOwnedProjectedSubjectIfRetained(
        string retainedFlag,
        RuntimeStruct owner,
        string projectedFieldName)
    {
        var retained = NextTemp("enum_payload_retained");
        EmitLoad(retained, "i1", retainedFlag, 1);
        var retainedLabel = NextLabel("enum_payload_owner_drop");
        var movedLabel = NextLabel("enum_payload_owner_partial_drop");
        var doneLabel = NextLabel("enum_payload_owner_drop_done");
        EmitConditionalBranch(retained, retainedLabel, movedLabel);
        EmitFunctionLine();
        EmitLabel(retainedLabel);
        _currentBlockLabel = retainedLabel;
        DropOwnedRuntimeValue(owner);
        EmitBranch(doneLabel);
        EmitFunctionLine();
        EmitLabel(movedLabel);
        _currentBlockLabel = movedLabel;
        DropOwnedStructFieldsExcept(owner, projectedFieldName);
        EmitBranch(doneLabel);
        EmitFunctionLine();
        EmitLabel(doneLabel);
        _currentBlockLabel = doneLabel;
    }

    private RuntimeValue ExtractEnumPayload(RuntimeEnum value, BoundType payloadType)
    {
        if (payloadType == BoundType.Unit)
        {
            return RuntimeUnit.Instance;
        }
        var llvmType = LlvmEnumType(value.Type);
        var slot = NextTemp("enum_match_slot");
        EmitAlloca(slot, llvmType, 8);
        EmitStore(llvmType, value.ValueName, slot, 8);
        var payloadAddress = NextTemp("enum_payload_addr");
        EmitAssign(payloadAddress, $"getelementptr inbounds {llvmType}, ptr {slot}, i32 0, i32 1");
        var payload = NextTemp("enum_payload");
        EmitLoad(payload, LlvmType(payloadType), payloadAddress, RuntimeAlignment(payloadType));
        return DematerializeAggregateValue(payloadType, payload);
    }

    private RuntimeValue EmitTryExpression(TryExpression expression)
    {
        var result = EmitExpression(expression.Value) as RuntimeEnum
            ?? throw new SollangException("'?' expects a Result value");
        if (!_program.Types.TryGetResultTypes(result.Type, out var operandTypes))
        {
            throw new SollangException("'?' expects a Result value");
        }
        var function = _currentFunction
            ?? throw new SollangException("'?' requires an enclosing Result function");
        if (!_program.Types.TryGetResultTypes(function.ReturnType, out var outerTypes)
            || outerTypes.Error != operandTypes.Error)
        {
            throw new SollangException("'?' enclosing function has an incompatible Result error type");
        }
        if ((_program.Types.ContainsOwnedStorage(operandTypes.Ok)
                || _program.Types.ContainsOwnedStorage(operandTypes.Error))
            && expression.Value is NameExpression consumedName)
        {
            RemoveLocal(consumedName.Name);
        }

        var tag = NextTemp("try_tag");
        EmitAssign(tag, $"extractvalue {LlvmEnumType(result.Type)} {result.ValueName}, 0");
        var isError = NextTemp("try_is_error");
        EmitCompare(isError, "eq", "i32", tag, "1");
        var errorLabel = NextLabel("try_error");
        var okLabel = NextLabel("try_ok");
        EmitConditionalBranch(isError, errorLabel, okLabel);

        EmitLabel(errorLabel);
        _currentBlockLabel = errorLabel;
        var errorPayload = ExtractEnumPayload(result, operandTypes.Error);
        var outerDefinition = _program.Types.GetEnum(function.ReturnType);
        var errorVariant = outerDefinition.Variants.First(variant => variant.Name == "Err");
        var propagated = EmitEnumValue(function.ReturnType, errorVariant, errorPayload);
        DropOwnedLocals();
        EmitPropagatedResultReturn(function, propagated);

        EmitLabel(okLabel);
        _currentBlockLabel = okLabel;
        return ExtractEnumPayload(result, operandTypes.Ok);
    }

    private int RuntimeAlignment(BoundType type)
    {
        return _program.Types.AlignmentOf(type);
    }

    private sealed class EnumContinuingPath(
        RuntimeValue? value,
        LocalScope scope,
        string label,
        MemoryOutputSink cleanup)
    {
        public RuntimeValue? Value { get; } = value;
        public LocalScope Scope { get; set; } = scope;
        public string Label { get; set; } = label;
        public MemoryOutputSink Cleanup { get; } = cleanup;
    }
}
