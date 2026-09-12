using System.Globalization;
using System.Text;
using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Semantics;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private RuntimeInt LoadInt(string pointer, string prefix)
    {
        var value = NextTemp(prefix);
        EmitLoad(value, "i32", pointer, 4);
        return new RuntimeInt(value);
    }

    private void EmitTrapUnless(string condition, string prefix)
    {
        var okLabel = NextLabel(prefix + "_ok");
        var failLabel = NextLabel(prefix + "_fail");
        var trapMessage = _currentFunction is null
            ? $"main:{failLabel}"
            : $"{_currentFunction.ModuleName}.{_currentFunction.Name}:{failLabel}";
        EmitConditionalBranch(condition, okLabel, failLabel);
        EmitFunctionLine();
        EmitLabel(failLabel);
        if (_platform is WasmBrowserLlvmRuntimePlatform)
        {
            var message = AddGlobalString(trapMessage);
            EmitCall(
                target: null,
                "void",
                "sollang_browser_panic",
                $"ptr {message.Name}, i32 {message.Length}");
        }
        else if (_platform is WindowsLlvmRuntimePlatform)
        {
            var message = AddGlobalString(trapMessage);
            var stderr = NextTemp("trap_stderr");
            var written = NextTemp("trap_written");
            EmitAlloca(written, "i32", 4);
            EmitCall(stderr, "ptr", "GetStdHandle", "i32 -12");
            EmitCall(
                target: null,
                "i32",
                "WriteFile",
                $"ptr {stderr}, ptr {message.Name}, i32 {message.Length}, ptr {written}, ptr null");
        }
        EmitTrap();
        EmitFunctionLine();
        EmitLabel(okLabel);
        _currentBlockLabel = okLabel;
    }

    private RuntimeInt EmitIntExpression(Expression expression)
    {
        var value = EmitExpression(expression);
        return value as RuntimeInt
            ?? throw new SollangException("expected runtime integer expression");
    }

    private RuntimeBool EmitBoolExpression(Expression expression)
    {
        var value = EmitExpression(expression);
        return value as RuntimeBool
            ?? throw new SollangException("expected runtime boolean expression");
    }

    private RuntimeValue EmitAddExpression(AddExpression expression)
    {
        return EmitNumericBinary(expression.Left, expression.Right, "add", "fadd", "add");
    }

    private RuntimeValue EmitMultiplyExpression(MultiplyExpression expression)
    {
        return EmitNumericBinary(expression.Left, expression.Right, "mul", "fmul", "mul");
    }

    private RuntimeValue EmitSubtractExpression(SubtractExpression expression)
    {
        return EmitNumericBinary(expression.Left, expression.Right, "sub", "fsub", "sub");
    }

    private RuntimeValue EmitDivideExpression(DivideExpression expression)
    {
        var left = EmitExpression(expression.Left);
        var right = EmitFunctionArgumentExpression(expression.Right, left.Type);
        if (left.Type != right.Type && TryGetNumericLiteralText(expression.Left, out _))
        {
            right = EmitExpression(expression.Right);
            left = EmitFunctionArgumentExpression(expression.Left, right.Type);
        }
        var integerOp = IsSignedIntegerType(left.Type) ? "sdiv" : "udiv";
        return EmitNumericBinary(left, right, integerOp, "fdiv", "div");
    }

    private RuntimeValue EmitModuloExpression(ModuloExpression expression)
    {
        var left = EmitExpression(expression.Left);
        var right = EmitFunctionArgumentExpression(expression.Right, left.Type);
        if (left.Type != right.Type && TryGetNumericLiteralText(expression.Left, out _))
        {
            right = EmitExpression(expression.Right);
            left = EmitFunctionArgumentExpression(expression.Left, right.Type);
        }
        var integerOp = IsSignedIntegerType(left.Type) ? "srem" : "urem";
        return EmitNumericBinary(left, right, integerOp, "frem", "mod");
    }

    private RuntimeValue EmitNegateExpression(NegateExpression expression)
    {
        var value = EmitExpression(expression.Value);
        var result = NextTemp("neg");
        if (value is RuntimeInt integer)
        {
            EmitBinary(result, "sub", LlvmType(value.Type), "0", integer.ValueName);
            return new RuntimeInt(value.Type, result);
        }
        if (value is RuntimeFloat floating)
        {
            EmitBinary(result, "fsub", LlvmType(value.Type), "-0.0", floating.ValueName);
            return new RuntimeFloat(value.Type, result);
        }
        throw new SollangException("unary '-' expects a numeric value");
    }

    private RuntimeValue EmitNumericBinary(
        Expression leftExpression,
        Expression rightExpression,
        string integerOperation,
        string floatOperation,
        string prefix)
    {
        var left = EmitExpression(leftExpression);
        var right = EmitFunctionArgumentExpression(rightExpression, left.Type);
        if (left.Type != right.Type && TryGetNumericLiteralText(leftExpression, out _))
        {
            right = EmitExpression(rightExpression);
            left = EmitFunctionArgumentExpression(leftExpression, right.Type);
        }
        if (left.Type != right.Type)
        {
            throw new SollangException(
                $"codegen error at {leftExpression.Line}:{leftExpression.Column}: numeric operands must have the same runtime type; got {left.Type} and {right.Type}");
        }
        return EmitNumericBinary(left, right, integerOperation, floatOperation, prefix);
    }

    private RuntimeValue EmitNumericBinary(
        RuntimeValue left,
        RuntimeValue right,
        string integerOperation,
        string floatOperation,
        string prefix)
    {
        var result = NextTemp(prefix);
        if (left is RuntimeInt leftInt && right is RuntimeInt rightInt && left.Type == right.Type)
        {
            EmitBinary(result, integerOperation, LlvmType(left.Type), leftInt.ValueName, rightInt.ValueName);
            return new RuntimeInt(left.Type, result);
        }
        if (left is RuntimeFloat leftFloat && right is RuntimeFloat rightFloat && left.Type == right.Type)
        {
            EmitBinary(result, floatOperation, LlvmType(left.Type), leftFloat.ValueName, rightFloat.ValueName);
            return new RuntimeFloat(left.Type, result);
        }
        throw new SollangException(
            $"numeric operands must have the same runtime type; got {left.Type} and {right.Type}");
    }

    private RuntimeValue EmitContextualNumericBinary(Expression expression, BoundType expectedType)
    {
        var (leftExpression, rightExpression, integerOperation, floatOperation, prefix) = expression switch
        {
            AddExpression value => (value.Left, value.Right, "add", "fadd", "add"),
            SubtractExpression value => (value.Left, value.Right, "sub", "fsub", "sub"),
            MultiplyExpression value => (value.Left, value.Right, "mul", "fmul", "mul"),
            DivideExpression value => (
                value.Left,
                value.Right,
                IsSignedIntegerType(expectedType) ? "sdiv" : "udiv",
                "fdiv",
                "div"),
            ModuloExpression value => (
                value.Left,
                value.Right,
                IsSignedIntegerType(expectedType) ? "srem" : "urem",
                "frem",
                "mod"),
            _ => throw new SollangException("contextual numeric emission expects a binary numeric expression")
        };
        var left = EmitFunctionArgumentExpression(leftExpression, expectedType);
        var right = EmitFunctionArgumentExpression(rightExpression, expectedType);
        return EmitNumericBinary(left, right, integerOperation, floatOperation, prefix);
    }

    private RuntimeBool EmitCompareExpression(CompareExpression expression)
    {
        var left = EmitExpression(expression.Left);
        var right = EmitFunctionArgumentExpression(expression.Right, left.Type);
        if (left.Type != right.Type && TryGetNumericLiteralText(expression.Left, out _))
        {
            right = EmitExpression(expression.Right);
            left = EmitFunctionArgumentExpression(expression.Left, right.Type);
        }
        if (left is RuntimeInt leftInt && right is RuntimeInt rightInt)
        {
            return EmitIntegerComparison(leftInt, expression.Operator, rightInt);
        }
        if (left is RuntimeText leftText && right is RuntimeText rightText)
        {
            if (expression.Operator is not (ComparisonOperator.Equal or ComparisonOperator.NotEqual))
            {
                throw new SollangException("Text supports only '==' and '!=' comparisons");
            }
            var equal = EmitValuesEqual(leftText, rightText);
            if (expression.Operator == ComparisonOperator.Equal)
            {
                return new RuntimeBool(equal);
            }
            var different = NextTemp("text_ne");
            EmitBinary(different, "xor", "i1", equal, "true");
            return new RuntimeBool(different);
        }
        if (left is RuntimeFloat leftFloat && right is RuntimeFloat rightFloat)
        {
            var result = NextTemp("fcmp");
            var instruction = expression.Operator switch
            {
                ComparisonOperator.Equal => "oeq",
                ComparisonOperator.NotEqual => "one",
                ComparisonOperator.Less => "olt",
                ComparisonOperator.LessOrEqual => "ole",
                ComparisonOperator.Greater => "ogt",
                ComparisonOperator.GreaterOrEqual => "oge",
                _ => throw new SollangException($"unsupported comparison operator '{expression.Operator}'")
            };
            EmitInstruction($"{result} = fcmp {instruction} {LlvmType(left.Type)} {leftFloat.ValueName}, {rightFloat.ValueName}");
            return new RuntimeBool(result);
        }
        throw new SollangException("comparison operands must have the same numeric runtime type");
    }

    private RuntimeBool EmitIntegerComparison(RuntimeInt left, ComparisonOperator comparisonOperator, RuntimeInt right)
    {
        var result = NextTemp("cmp");
        var instruction = comparisonOperator switch
        {
            ComparisonOperator.Equal => "eq",
            ComparisonOperator.NotEqual => "ne",
            ComparisonOperator.Less => "slt",
            ComparisonOperator.LessOrEqual => "sle",
            ComparisonOperator.Greater => "sgt",
            ComparisonOperator.GreaterOrEqual => "sge",
            _ => throw new SollangException($"unsupported comparison operator '{comparisonOperator}'")
        };
        if (!IsSignedIntegerType(left.Type))
        {
            instruction = instruction switch { "slt" => "ult", "sle" => "ule", "sgt" => "ugt", "sge" => "uge", _ => instruction };
        }
        EmitCompare(result, instruction, LlvmType(left.Type), left.ValueName, right.ValueName);
        return new RuntimeBool(result);
    }

    private RuntimeBool EmitAndExpression(AndExpression expression)
    {
        var left = EmitBoolExpression(expression.Left);
        var rhsLabel = NextLabel("and_rhs");
        var endLabel = NextLabel("and_end");
        var entryLabel = _currentBlockLabel;

        EmitConditionalBranch(left.ValueName, rhsLabel, endLabel);

        EmitLabel(rhsLabel);
        _currentBlockLabel = rhsLabel;
        var right = EmitBoolExpression(expression.Right);
        var rightLabel = _currentBlockLabel;
        EmitBranch(endLabel);

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        var result = NextTemp("and");
        EmitPhi(result, "i1", ("false", entryLabel), (right.ValueName, rightLabel));
        return new RuntimeBool(result);
    }

    private RuntimeBool EmitOrExpression(OrExpression expression)
    {
        var left = EmitBoolExpression(expression.Left);
        var rhsLabel = NextLabel("or_rhs");
        var endLabel = NextLabel("or_end");
        var entryLabel = _currentBlockLabel;

        EmitConditionalBranch(left.ValueName, endLabel, rhsLabel);

        EmitLabel(rhsLabel);
        _currentBlockLabel = rhsLabel;
        var right = EmitBoolExpression(expression.Right);
        var rightLabel = _currentBlockLabel;
        EmitBranch(endLabel);

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        var result = NextTemp("or");
        EmitPhi(result, "i1", ("true", entryLabel), (right.ValueName, rightLabel));
        return new RuntimeBool(result);
    }

    private RuntimeBool EmitNotExpression(NotExpression expression)
    {
        var value = EmitBoolExpression(expression.Value);
        var result = NextTemp("not");
        EmitBinary(result, "xor", "i1", value.ValueName, "true");
        return new RuntimeBool(result);
    }

    private RuntimeValue EmitIfExpression(IfExpression expression, BoundType? expectedResultType = null)
    {
        var condition = EmitBoolExpression(expression.Condition);
        var conditionLabel = _currentBlockLabel;
        var entryScope = CaptureLocals();
        var thenLabel = NextLabel("if_then");
        var elseLabel = expression.Else is null ? null : NextLabel("if_else");
        var endLabel = NextLabel("if_end");

        EmitConditionalBranch(condition.ValueName, thenLabel, elseLabel ?? endLabel);

        EmitLabel(thenLabel);
        _currentBlockLabel = thenLabel;
        RestoreLocals(entryScope);
        var thenResult = EmitScopedBlockBody(expression.Then, expectedResultType);
        var thenEndLabel = _currentBlockLabel;
        var thenTerminated = _currentBlockTerminated;
        if (!thenTerminated)
        {
            EmitBranch(endLabel);
        }

        BlockResult? elseResult = null;
        var elseTerminated = false;
        if (expression.Else is not null)
        {
            var activeElseLabel = elseLabel!;
            EmitLabel(activeElseLabel);
            _currentBlockLabel = activeElseLabel;
            RestoreLocals(entryScope);
            elseResult = EmitScopedBlockBody(expression.Else, expectedResultType);
            elseTerminated = _currentBlockTerminated;
            if (!elseTerminated)
            {
                EmitBranch(endLabel);
            }
        }

        if (expression.Else is not null && thenTerminated && elseTerminated)
        {
            return RuntimeUnit.Instance;
        }

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;

        var incomingScopes = new List<(LocalScope Scope, string Label)>();
        if (!thenTerminated)
        {
            incomingScopes.Add((thenResult.ExitScope, thenEndLabel));
        }
        if (expression.Else is null)
        {
            incomingScopes.Add((entryScope, conditionLabel));
        }
        else if (!elseTerminated)
        {
            incomingScopes.Add((elseResult!.ExitScope, elseResult.EndLabel));
        }
        if (_activeAsyncCfg is not null)
        {
            MergeAsyncOuterScope(entryScope, incomingScopes);
        }
        else
        {
            MergeSynchronousOuterScope(entryScope, incomingScopes);
        }

        if (expression.Else is null)
        {
            return RuntimeUnit.Instance;
        }

        if (thenTerminated)
        {
            return elseResult?.Value ?? RuntimeUnit.Instance;
        }
        if (elseTerminated)
        {
            return thenResult.Value ?? RuntimeUnit.Instance;
        }
        if (thenResult.Value is null || elseResult?.Value is null)
        {
            return RuntimeUnit.Instance;
        }

        return EmitPhiValue("if", thenResult.Value, thenEndLabel, elseResult.Value, elseResult.EndLabel);
    }

    private RuntimeValue EmitWhenExpression(WhenExpression expression, BoundType? expectedResultType = null)
    {
        var endLabel = NextLabel("when_end");
        var valueResults = new List<(RuntimeValue Value, string Label)>();
        var scopeResults = new List<(LocalScope Scope, string Label)>();
        var hasEndPredecessor = false;
        var hasSubjectConditions = expression.Arms.Any(static arm => IsSubjectWhenCondition(arm.Condition));
        var subject = expression.Subject is not null
            ? EmitIntExpression(expression.Subject)
            : hasSubjectConditions
                ? ResolveLocal("it") as RuntimeInt
                    ?? throw new SollangException("subject-style when without an explicit subject requires runtime integer binding 'it'")
                : null;
        var entryScope = CaptureLocals();
        var nextConditionLabel = _currentBlockLabel;

        foreach (var arm in expression.Arms)
        {
            RestoreLocals(entryScope);
            _currentBlockLabel = nextConditionLabel;
            var armLabel = NextLabel("when_arm");
            var nextLabel = NextLabel("when_next");
            var condition = subject is null
                ? EmitBoolExpression(arm.Condition)
                : EmitSubjectWhenCondition(subject, arm.Condition);
            EmitConditionalBranch(condition.ValueName, armLabel, nextLabel);

            EmitLabel(armLabel);
            _currentBlockLabel = armLabel;
            var armResult = EmitScopedBlockBody(arm.Body, expectedResultType);
            if (!_currentBlockTerminated && armResult.Value is not null)
            {
                valueResults.Add((armResult.Value, armResult.EndLabel));
            }
            if (!_currentBlockTerminated)
            {
                scopeResults.Add((armResult.ExitScope, armResult.EndLabel));
            }

            if (!_currentBlockTerminated)
            {
                EmitBranch(endLabel);
                hasEndPredecessor = true;
            }
            EmitLabel(nextLabel);
            nextConditionLabel = nextLabel;
        }

        _currentBlockLabel = nextConditionLabel;
        RestoreLocals(entryScope);
        var elseResult = EmitScopedBlockBody(expression.Else, expectedResultType);
        if (!_currentBlockTerminated && elseResult.Value is not null)
        {
            valueResults.Add((elseResult.Value, elseResult.EndLabel));
        }
        if (!_currentBlockTerminated)
        {
            scopeResults.Add((elseResult.ExitScope, elseResult.EndLabel));
        }

        if (!_currentBlockTerminated)
        {
            EmitBranch(endLabel);
            hasEndPredecessor = true;
        }
        if (!hasEndPredecessor)
        {
            return RuntimeUnit.Instance;
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

        if (valueResults.Count == 0)
        {
            return RuntimeUnit.Instance;
        }

        return EmitPhiValue("when", valueResults);
    }

    private static bool IsSubjectWhenCondition(Expression condition)
    {
        return condition is SubjectCompareExpression or SubjectRangeExpression;
    }

    private RuntimeBool EmitSubjectWhenCondition(RuntimeInt subject, Expression condition)
    {
        RuntimeInt EmitOperand(Expression operand) =>
            EmitFunctionArgumentExpression(operand, subject.Type) as RuntimeInt
            ?? throw new SollangException("value-flow when operand must be an integer");

        if (condition is SubjectCompareExpression compare)
        {
            return EmitIntegerComparison(subject, compare.Operator, EmitOperand(compare.Right));
        }

        if (condition is not SubjectRangeExpression range)
        {
            throw new SollangException("value-flow when arm must start with a comparison operator or range");
        }

        var lower = EmitIntegerComparison(subject, ComparisonOperator.GreaterOrEqual, EmitOperand(range.Start));
        var upper = EmitIntegerComparison(
            subject,
            range.IsEndExclusive ? ComparisonOperator.Less : ComparisonOperator.LessOrEqual,
            EmitOperand(range.End));
        var result = NextTemp("range");
        EmitBinary(result, "and", "i1", lower.ValueName, upper.ValueName);
        return new RuntimeBool(result);
    }

    private RuntimeInt EmitFoldExpression(FoldExpression expression)
    {
        return expression.Source is RangeExpression range
            ? EmitRangeFoldExpression(expression, range)
            : EmitArrayFoldExpression(expression);
    }

    private RuntimeInt EmitRangeFoldExpression(FoldExpression expression, RangeExpression range)
    {
        var start = EmitIntExpression(range.Start);
        var end = EmitIntExpression(range.End);
        var initial = EmitIntExpression(expression.Initial);
        var bodyLabel = NextLabel("fold_body");
        var continueLabel = NextLabel("fold_continue");
        var endLabel = NextLabel("fold_end");
        var entryLabel = _currentBlockLabel;
        var nextItem = NextTemp("fold_next");
        var initialDone = NextTemp("fold_done");

        EmitCompare(initialDone, range.IsEndExclusive ? "sge" : "sgt", "i32", start.ValueName, end.ValueName);
        EmitConditionalBranch(initialDone, endLabel, bodyLabel);

        EmitLabel(bodyLabel);
        _currentBlockLabel = bodyLabel;
        var item = NextTemp(expression.ItemName);
        EmitPhi(item, "i32", (start.ValueName, entryLabel), (nextItem, continueLabel));

        var nextAccumulator = NextTemp("fold_acc_next");
        var accumulator = NextTemp(expression.AccumulatorName);
        EmitPhi(accumulator, "i32", (initial.ValueName, entryLabel), (nextAccumulator, continueLabel));

        var outerLocals = CaptureLocals();
        _locals[expression.AccumulatorName] = new RuntimeInt(accumulator);
        _locals[expression.ItemName] = new RuntimeInt(item);
        var bodyResult = EmitScopedBlockBody(expression.Body);
        RestoreLocals(outerLocals);
        if (bodyResult.Value is not RuntimeInt bodyValue)
        {
            throw new SollangException("fold body must return an integer accumulator value");
        }

        EmitBinary(nextAccumulator, "add", "i32", bodyValue.ValueName, "0");
        EmitBranch(continueLabel);

        EmitLabel(continueLabel);
        _currentBlockLabel = continueLabel;
        EmitBinary(nextItem, "add", "i32", item, "1");
        var done = NextTemp("fold_done");
        EmitCompare(done, range.IsEndExclusive ? "sge" : "sgt", "i32", nextItem, end.ValueName);
        EmitConditionalBranch(done, endLabel, bodyLabel);

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        var result = NextTemp("fold");
        EmitPhi(result, "i32", (initial.ValueName, entryLabel), (nextAccumulator, continueLabel));
        return new RuntimeInt(result);
    }

    private RuntimeInt EmitArrayFoldExpression(FoldExpression expression)
    {
        var source = EmitExpression(expression.Source);
        var (pointer, length, staticLength) = source switch
        {
            RuntimeIntSlice slice => (slice.PointerName, slice.LengthName, null),
            RuntimeStaticIntArray array => (array.PointerName, array.LengthName, (int?)array.AllocatedLength),
            RuntimeDynamicIntArray array => (array.PointerName, array.LengthName, null),
            _ => throw new SollangException("fold expects a range or Int array input")
        };

        var initial = EmitIntExpression(expression.Initial);
        var bodyLabel = NextLabel("array_fold_body");
        var continueLabel = NextLabel("array_fold_continue");
        var endLabel = NextLabel("array_fold_end");
        var entryLabel = _currentBlockLabel;
        var nextIndex = NextTemp("array_fold_next");
        var initialDone = NextTemp("array_fold_done");

        EmitCompare(initialDone, "eq", "i64", length, "0");
        EmitConditionalBranch(initialDone, endLabel, bodyLabel);

        EmitLabel(bodyLabel);
        _currentBlockLabel = bodyLabel;
        var index = NextTemp("array_fold_i");
        EmitPhi(index, "i64", ("0", entryLabel), (nextIndex, continueLabel));

        var nextAccumulator = NextTemp("array_fold_acc_next");
        var accumulator = NextTemp(expression.AccumulatorName);
        EmitPhi(accumulator, "i32", (initial.ValueName, entryLabel), (nextAccumulator, continueLabel));

        RuntimeInt item;
        if (staticLength is { } allocatedLength)
        {
            item = EmitStaticArrayLoad(new RuntimeStaticIntArray(pointer, length, allocatedLength), index);
        }
        else if (source is RuntimeIntSlice)
        {
            item = EmitIntSliceLoad(new RuntimeIntSlice(pointer, length), index);
        }
        else
        {
            item = EmitDynamicArrayLoad(new RuntimeDynamicIntArray(pointer, length, length), index);
        }

        var outerLocals = CaptureLocals();
        _locals[expression.AccumulatorName] = new RuntimeInt(accumulator);
        _locals[expression.ItemName] = item;
        var bodyResult = EmitScopedBlockBody(expression.Body);
        RestoreLocals(outerLocals);
        if (bodyResult.Value is not RuntimeInt bodyValue)
        {
            throw new SollangException("fold body must return an integer accumulator value");
        }

        EmitBinary(nextAccumulator, "add", "i32", bodyValue.ValueName, "0");
        EmitBranch(continueLabel);

        EmitLabel(continueLabel);
        _currentBlockLabel = continueLabel;
        EmitBinary(nextIndex, "add", "i64", index, "1");
        var done = NextTemp("array_fold_done");
        EmitCompare(done, "eq", "i64", nextIndex, length);
        EmitConditionalBranch(done, endLabel, bodyLabel);

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        var result = NextTemp("array_fold");
        EmitPhi(result, "i32", (initial.ValueName, entryLabel), (nextAccumulator, continueLabel));
        return new RuntimeInt(result);
    }

    private BlockResult EmitScopedBlockBody(BlockBody body, BoundType? expectedResultType = null)
    {
        var outerLocals = CaptureLocals();
        if (_activeAsyncCfg is not null)
        {
            _asyncScopeSnapshots.Push(outerLocals);
        }
        try
        {
            EmitStatements(body.Statements);
            if (_currentBlockTerminated)
            {
                return new BlockResult(null, _currentBlockLabel, CaptureLocals());
            }
            var transferredOwnerName = body.Value is null
                ? null
                : GetBlockResultTransferredOwnerName(body.Value);
            var value = body.Value is null
                ? null
                : expectedResultType is { } expected
                    ? EmitFunctionArgumentExpression(body.Value, expected)
                    : EmitExpression(body.Value);
            if (_currentBlockTerminated)
            {
                return new BlockResult(null, _currentBlockLabel, CaptureLocals());
            }
            if (value is RuntimeStaticIntArray or RuntimeStaticTextArray or RuntimeStaticInlineArray)
            {
                var copyExistingValue = _program.Types.IsCopyableFixedArray(value.Type)
                    && (body.Value is NameExpression resultName && outerLocals.Locals.ContainsKey(resultName.Name)
                        || body.Value is FieldAccessExpression
                            && RegisterOwnedFieldProjectionTransfer(body.Value, value.Type,
                                new Dictionary<string, List<IReadOnlyList<string>>>(StringComparer.Ordinal)));
                value = PrepareStaticArrayBlockResult(value, copyExistingValue);
            }
            if (value is RuntimeStruct && _program.Types.RequiresFixedStorageCopy(value.Type)
                && (body.Value is NameExpression structName && outerLocals.Locals.ContainsKey(structName.Name)
                    || body.Value is FieldAccessExpression
                        && RegisterOwnedFieldProjectionTransfer(body.Value, value.Type,
                            new Dictionary<string, List<IReadOnlyList<string>>>(StringComparer.Ordinal))))
            {
                value = CopyFixedStorageValue(value);
            }
            DropOwnedLocalsCreatedSince(outerLocals, transferredOwnerName, body.Value);
            return new BlockResult(value, _currentBlockLabel, CaptureLocals());
        }
        finally
        {
            if (_activeAsyncCfg is not null)
            {
                _asyncScopeSnapshots.Pop();
            }
            RestoreLocals(outerLocals);
        }
    }

    private void MergeAsyncOuterScope(
        LocalScope entryScope,
        IReadOnlyList<(LocalScope Scope, string Label)> incoming)
    {
        if (incoming.Count == 0)
        {
            RestoreLocals(entryScope);
            return;
        }

        RestoreLocals(entryScope);
        foreach (var (name, entryValue) in entryScope.Locals)
        {
            if (entryScope.BorrowedOwnedLocals.Contains(name))
            {
                continue;
            }
            var presentCount = incoming.Count(item => item.Scope.Locals.ContainsKey(name));
            if (presentCount == 0)
            {
                RemoveLocal(name);
                continue;
            }
            if (presentCount != incoming.Count)
            {
                throw new SollangException(
                    $"binding '{name}' has inconsistent ownership across async branch paths");
            }
            if (entryScope.MutableLocals.Contains(name))
            {
                MergeAsyncMutableSlot(name, entryScope, incoming);
                continue;
            }
            var values = incoming
                .Select(item => (Value: item.Scope.Locals[name], item.Label))
                .ToArray();
            _locals[name] = EmitAsyncScopePhi($"async_{name}", entryValue.Type, values);
        }

        MergeOwnedStructFieldMoves(entryScope, incoming);
    }

    private void MergeSynchronousOuterScope(
        LocalScope entryScope,
        IReadOnlyList<(LocalScope Scope, string Label)> incoming)
    {
        RestoreLocals(entryScope);
        if (incoming.Count == 0)
        {
            return;
        }

        foreach (var (name, entryValue) in entryScope.Locals)
        {
            if (entryScope.BorrowedOwnedLocals.Contains(name)
                || !_program.Types.ContainsOwnedStorage(entryValue.Type))
            {
                continue;
            }
            var presentCount = incoming.Count(item => item.Scope.Locals.ContainsKey(name));
            if (presentCount == 0)
            {
                RemoveLocal(name);
                continue;
            }
            if (presentCount != incoming.Count)
            {
                var presentLabels = string.Join(
                    ",",
                    incoming.Where(item => item.Scope.Locals.ContainsKey(name)).Select(item => item.Label));
                var missingLabels = string.Join(
                    ",",
                    incoming.Where(item => !item.Scope.Locals.ContainsKey(name)).Select(item => item.Label));
                throw new SollangException(
                    $"function '{_currentFunction?.Name ?? "main"}' binding '{name}' has inconsistent ownership across branch paths "
                    + $"(present: {presentLabels}; moved: {missingLabels})");
            }
        }

        MergeOwnedStructFieldMoves(entryScope, incoming);
    }

    private void MergeOwnedStructFieldMoves(
        LocalScope entryScope,
        IReadOnlyList<(LocalScope Scope, string Label)> incoming)
    {
        foreach (var name in entryScope.Locals.Keys)
        {
            if (incoming.Any(item => !item.Scope.Locals.ContainsKey(name)))
            {
                continue;
            }
            var masks = incoming.Select(item =>
                item.Scope.MovedOwnedStructFields.TryGetValue(name, out var fields)
                    ? fields
                    : EmptyMovedFieldMask).ToArray();
            if (masks.Length == 0)
            {
                continue;
            }

            var entryMask = entryScope.MovedOwnedStructFields.TryGetValue(name, out var entryFields)
                ? entryFields
                : EmptyMovedFieldMask;
            if (masks.Any(mask => !entryMask.SetEquals(mask)))
            {
                var changedFields = masks
                    .SelectMany(static mask => mask)
                    .Distinct(StringComparer.Ordinal)
                    .Order(StringComparer.Ordinal);
                throw new SollangException(
                    $"sollang error[E20]: partial move of owned field(s) "
                    + $"'{string.Join(", ", changedFields)}' from binding '{name}' exits a branch; "
                    + "reinitialize each moved field before the branch exits or return from the moving branch");
            }
        }
    }

    private static readonly HashSet<string> EmptyMovedFieldMask = new(StringComparer.Ordinal);

    private void MergeAsyncMutableSlot(
        string name,
        LocalScope entryScope,
        IReadOnlyList<(LocalScope Scope, string Label)> incoming)
    {
        var prefix = name.TrimEnd('!');
        if (entryScope.MutableScalarSlots.ContainsKey(name))
        {
            _mutableScalarSlots[name] = EmitAsyncPointerPhi(
                $"async_{prefix}_slot",
                incoming.Select(item =>
                    (item.Scope.MutableScalarSlots[name], item.Label)).ToArray());
            return;
        }
        if (entryScope.MutableStructSlots.ContainsKey(name))
        {
            _mutableStructSlots[name] = EmitAsyncPointerPhi(
                $"async_{prefix}_struct_slot",
                incoming.Select(item =>
                    (item.Scope.MutableStructSlots[name], item.Label)).ToArray());
            return;
        }
        if (entryScope.MutableContainerSlots.ContainsKey(name))
        {
            _mutableContainerSlots[name] = new MutableContainerSlot(
                EmitAsyncPointerPhi(
                    $"async_{prefix}_ptr_slot",
                    incoming.Select(item =>
                        (item.Scope.MutableContainerSlots[name].PointerAddress, item.Label)).ToArray()),
                EmitAsyncPointerPhi(
                    $"async_{prefix}_len_slot",
                    incoming.Select(item =>
                        (item.Scope.MutableContainerSlots[name].LengthAddress, item.Label)).ToArray()),
                EmitAsyncPointerPhi(
                    $"async_{prefix}_capacity_slot",
                    incoming.Select(item =>
                        (item.Scope.MutableContainerSlots[name].CapacityAddress, item.Label)).ToArray()),
                StackAllocation: null);
            return;
        }

        throw new SollangException(
            $"mutable binding '{name}' has no storage slot at async branch join");
    }

    private string EmitAsyncPointerPhi(
        string prefix,
        IReadOnlyList<(string Pointer, string Label)> incoming)
    {
        var result = NextTemp(prefix);
        EmitPhi(
            result,
            "ptr",
            incoming.Select(item => (Value: item.Pointer, item.Label)).ToArray());
        return result;
    }

    private RuntimeValue EmitAsyncScopePhi(
        string prefix,
        BoundType type,
        IReadOnlyList<(RuntimeValue Value, string Label)> incoming)
    {
        if (incoming.Any(item => item.Value.Type != type))
        {
            throw new SollangException(
                $"async branch binding '{prefix}' has inconsistent runtime types");
        }

        // A join block must start with all PHI instructions. Materializing an
        // aggregate here emits insertvalue/extractvalue instructions before the
        // PHI and produces invalid LLVM. Merge the existing runtime components
        // directly; predecessor blocks already own their concrete values.
        return EmitPhiValue(prefix, incoming);
    }

    private RuntimeValue EmitPhiValue(
        string prefix,
        RuntimeValue left,
        string leftLabel,
        RuntimeValue right,
        string rightLabel)
    {
        return EmitPhiValue(prefix, [(left, leftLabel), (right, rightLabel)]);
    }

    private RuntimeValue EmitPhiValue(string prefix, IReadOnlyList<(RuntimeValue Value, string Label)> incoming)
    {
        return incoming[0].Value switch
        {
            RuntimeArguments => new RuntimeArguments(EmitScalarPhi(prefix, "i64", incoming)),
            RuntimeInt integer => new RuntimeInt(integer.Type, EmitScalarPhi(prefix, LlvmType(integer.Type), incoming)),
            RuntimeFloat floating => new RuntimeFloat(floating.Type, EmitScalarPhi(prefix, LlvmType(floating.Type), incoming)),
            RuntimeBool => new RuntimeBool(EmitScalarPhi(prefix, "i1", incoming)),
            RuntimeText => EmitTextPhi(prefix, incoming),
            RuntimeTask task => EmitTaskPhi(prefix, task, incoming),
            RuntimeBox box => EmitBoxPhi(prefix, box, incoming),
            RuntimeReference reference => EmitReferencePhi(prefix, reference, incoming),
            RuntimeInlineSlice slice => EmitInlineSlicePhi(prefix, slice, incoming),
            RuntimeStaticIntArray or RuntimeStaticTextArray or RuntimeStaticInlineArray =>
                EmitStaticArrayPhi(prefix, incoming),
            RuntimeDynamicIntArray => EmitDynamicArrayPhi(prefix, incoming),
            RuntimeDynamicInlineArray array => EmitDynamicInlineArrayPhi(prefix, array, incoming),
            RuntimeIntDictionary => EmitIntDictionaryPhi(prefix, incoming),
            RuntimeInlineDictionary dictionary => EmitInlineDictionaryPhi(prefix, dictionary, incoming),
            RuntimeStruct structure => EmitStructPhi(prefix, structure.Type, incoming),
            RuntimeEnum enumeration => EmitEnumPhi(prefix, enumeration.Type, incoming),
            RuntimeUnit => RuntimeUnit.Instance,
            _ => throw new SollangException($"unsupported phi value {incoming[0].Value.GetType().Name}")
        };
    }

    private static (string Pointer, string Length, BoundType ElementType, RuntimeContainerStorage Storage)
        StaticArrayPhiStorage(RuntimeValue value) => value switch
        {
            RuntimeStaticIntArray array => (array.PointerName, array.LengthName, BoundType.Int, array.Storage),
            RuntimeStaticTextArray array => (array.PointerName, array.LengthName, BoundType.Text, array.Storage),
            RuntimeStaticInlineArray array => (array.PointerName, array.LengthName, array.ElementType, array.Storage),
            _ => throw new SollangException("static array phi received a non-array value")
        };

    private static RuntimeValue WithStaticArrayPhiStorage(
        RuntimeValue value, string pointer, string length, RuntimeContainerStorage storage) => value switch
        {
            RuntimeStaticIntArray array => array with { PointerName = pointer, LengthName = length, Storage = storage },
            RuntimeStaticTextArray array => array with { PointerName = pointer, LengthName = length, Storage = storage },
            RuntimeStaticInlineArray array => array with { PointerName = pointer, LengthName = length, Storage = storage },
            _ => throw new SollangException("static array phi received a non-array value")
        };

    private RuntimeValue PrepareStaticArrayBlockResult(RuntimeValue value, bool copyExistingValue = false)
    {
        var storage = StaticArrayPhiStorage(value);
        if (storage.Storage == RuntimeContainerStorage.Heap && !copyExistingValue) return value;

        // Normalize each predecessor before its terminator, so the join has a
        // single cleanup contract even when a literal and a call return meet.
        var elementSize = _program.Types.GetStaticArray(
            _program.Types.GetOrAddStaticArray(storage.ElementType)).ElementSize;
        var bytes = NextTemp("block_fixed_bytes");
        EmitBinary(bytes, "mul", "i64", storage.Length, elementSize.ToString(CultureInfo.InvariantCulture));
        var pointer = EmitHeapAllocate(bytes);
        EmitCall(target: null, "void", "llvm.memcpy.p0.p0.i64",
            $"ptr {pointer}, ptr {storage.Pointer}, i64 {bytes}, i1 false");
        return WithStaticArrayPhiStorage(value, pointer, storage.Length, RuntimeContainerStorage.Heap);
    }

    private RuntimeValue EmitStaticArrayPhi(
        string prefix, IReadOnlyList<(RuntimeValue Value, string Label)> incoming)
    {
        var first = incoming[0].Value;
        var storage = StaticArrayPhiStorage(first);
        if (incoming.Any(item => item.Value.Type != first.Type
            || StaticArrayPhiStorage(item.Value).ElementType != storage.ElementType
            || StaticArrayPhiStorage(item.Value).Storage != storage.Storage))
        {
            throw new SollangException("static array phi inputs disagree on type or storage");
        }
        var pointer = NextTemp(prefix + "_ptr");
        EmitPhi(pointer, "ptr", FormatPhiIncoming(incoming, static value => StaticArrayPhiStorage(value).Pointer));
        var length = NextTemp(prefix + "_len");
        EmitPhi(length, "i64", FormatPhiIncoming(incoming, static value => StaticArrayPhiStorage(value).Length));
        return WithStaticArrayPhiStorage(first, pointer, length, storage.Storage);
    }

    private string EmitScalarPhi(string prefix, string typeName, IReadOnlyList<(RuntimeValue Value, string Label)> incoming)
    {
        var result = NextTemp(prefix);
        var incomingList = FormatPhiIncoming(incoming, static value => value switch
        {
            RuntimeArguments arguments => arguments.LengthName,
            RuntimeInt integer => integer.ValueName,
            RuntimeFloat floating => floating.ValueName,
            RuntimeBool boolean => boolean.ValueName,
            _ => throw new SollangException($"unsupported scalar phi value {value.GetType().Name}")
        });
        EmitPhi(result, typeName, incomingList);
        return result;
    }

    private RuntimeText EmitTextPhi(string prefix, IReadOnlyList<(RuntimeValue Value, string Label)> incoming)
    {
        var pointer = NextTemp(prefix + "_ptr");
        EmitPhi(pointer, "ptr", FormatPhiIncoming(incoming, static value => ((RuntimeText)value).PointerName));

        var length = NextTemp(prefix + "_len");
        EmitPhi(length, "i64", FormatPhiIncoming(incoming, static value => ((RuntimeText)value).LengthName));

        return new RuntimeText(pointer, length);
    }

    private RuntimeTask EmitTaskPhi(
        string prefix,
        RuntimeTask first,
        IReadOnlyList<(RuntimeValue Value, string Label)> incoming)
    {
        if (incoming.Any(item => item.Value is not RuntimeTask task
            || task.TaskType != first.TaskType
            || task.InputType != first.InputType
            || task.ResultType != first.ResultType
            || task.RuntimeFunction != first.RuntimeFunction))
        {
            throw new SollangException("Task phi inputs disagree on runtime shape");
        }
        var handle = NextTemp(prefix + "_handle");
        EmitPhi(handle, "ptr", FormatPhiIncoming(incoming, static value => ((RuntimeTask)value).HandleName));
        var context = NextTemp(prefix + "_context");
        EmitPhi(context, "ptr", FormatPhiIncoming(incoming, static value => ((RuntimeTask)value).ContextName));
        return first with { HandleName = handle, ContextName = context };
    }

    private RuntimeBox EmitBoxPhi(
        string prefix,
        RuntimeBox first,
        IReadOnlyList<(RuntimeValue Value, string Label)> incoming)
    {
        if (incoming.Any(item => item.Value is not RuntimeBox box
            || box.BoxType != first.BoxType
            || box.ElementType != first.ElementType))
        {
            throw new SollangException("Box phi inputs disagree on runtime shape");
        }
        var pointer = NextTemp(prefix + "_ptr");
        EmitPhi(pointer, "ptr", FormatPhiIncoming(incoming, static value => ((RuntimeBox)value).PointerName));
        return first with { PointerName = pointer };
    }

    private RuntimeReference EmitReferencePhi(
        string prefix,
        RuntimeReference first,
        IReadOnlyList<(RuntimeValue Value, string Label)> incoming)
    {
        if (incoming.Any(item => item.Value is not RuntimeReference reference
            || reference.ReferenceType != first.ReferenceType
            || reference.ElementType != first.ElementType))
        {
            throw new SollangException("reference phi inputs disagree on runtime shape");
        }
        var pointer = NextTemp(prefix + "_ptr");
        EmitPhi(pointer, "ptr", FormatPhiIncoming(incoming, static value => ((RuntimeReference)value).PointerName));
        return first with { PointerName = pointer };
    }

    private RuntimeInlineSlice EmitInlineSlicePhi(
        string prefix,
        RuntimeInlineSlice first,
        IReadOnlyList<(RuntimeValue Value, string Label)> incoming)
    {
        var pointer = NextTemp(prefix + "_ptr");
        EmitPhi(
            pointer,
            "ptr",
            FormatPhiIncoming(incoming, static value => ((RuntimeInlineSlice)value).PointerName));
        var length = NextTemp(prefix + "_len");
        EmitPhi(
            length,
            "i64",
            FormatPhiIncoming(incoming, static value => ((RuntimeInlineSlice)value).LengthName));
        return new RuntimeInlineSlice(first.Type, first.ElementType, pointer, length);
    }

    private RuntimeDynamicIntArray EmitDynamicArrayPhi(string prefix, IReadOnlyList<(RuntimeValue Value, string Label)> incoming)
    {
        var pointer = NextTemp(prefix + "_ptr");
        EmitPhi(pointer, "ptr", FormatPhiIncoming(incoming, static value => ((RuntimeDynamicIntArray)value).PointerName));

        var length = NextTemp(prefix + "_len");
        EmitPhi(length, "i64", FormatPhiIncoming(incoming, static value => ((RuntimeDynamicIntArray)value).LengthName));

        var capacity = NextTemp(prefix + "_capacity");
        EmitPhi(capacity, "i64", FormatPhiIncoming(incoming, static value => ((RuntimeDynamicIntArray)value).CapacityName));

        return new RuntimeDynamicIntArray(pointer, length, capacity);
    }

    private RuntimeDynamicInlineArray EmitDynamicInlineArrayPhi(
        string prefix,
        RuntimeDynamicInlineArray first,
        IReadOnlyList<(RuntimeValue Value, string Label)> incoming)
    {
        if (incoming.Any(item => item.Value is not RuntimeDynamicInlineArray array
            || array.ArrayType != first.ArrayType
            || array.ElementType != first.ElementType
            || array.Storage != first.Storage))
        {
            throw new SollangException("dynamic inline array phi inputs disagree on type or storage");
        }

        var pointer = NextTemp(prefix + "_ptr");
        EmitPhi(
            pointer,
            "ptr",
            FormatPhiIncoming(incoming, static value => ((RuntimeDynamicInlineArray)value).PointerName));
        var length = NextTemp(prefix + "_len");
        EmitPhi(
            length,
            "i64",
            FormatPhiIncoming(incoming, static value => ((RuntimeDynamicInlineArray)value).LengthName));
        var capacity = NextTemp(prefix + "_capacity");
        EmitPhi(
            capacity,
            "i64",
            FormatPhiIncoming(incoming, static value => ((RuntimeDynamicInlineArray)value).CapacityName));
        return first with { PointerName = pointer, LengthName = length, CapacityName = capacity };
    }

    private RuntimeIntDictionary EmitIntDictionaryPhi(string prefix, IReadOnlyList<(RuntimeValue Value, string Label)> incoming)
    {
        var pointer = NextTemp(prefix + "_ptr");
        EmitPhi(pointer, "ptr", FormatPhiIncoming(incoming, static value => ((RuntimeIntDictionary)value).PointerName));

        var length = NextTemp(prefix + "_len");
        EmitPhi(length, "i64", FormatPhiIncoming(incoming, static value => ((RuntimeIntDictionary)value).LengthName));

        var capacity = NextTemp(prefix + "_capacity");
        EmitPhi(capacity, "i64", FormatPhiIncoming(incoming, static value => ((RuntimeIntDictionary)value).CapacityName));

        return new RuntimeIntDictionary(pointer, length, capacity);
    }

    private RuntimeInlineDictionary EmitInlineDictionaryPhi(
        string prefix,
        RuntimeInlineDictionary first,
        IReadOnlyList<(RuntimeValue Value, string Label)> incoming)
    {
        if (incoming.Any(item => item.Value is not RuntimeInlineDictionary dictionary
            || dictionary.DictionaryType != first.DictionaryType
            || dictionary.KeyType != first.KeyType
            || dictionary.ValueType != first.ValueType
            || dictionary.Storage != first.Storage))
        {
            throw new SollangException("dictionary phi inputs disagree on type or storage");
        }
        var pointer = NextTemp(prefix + "_ptr");
        EmitPhi(pointer, "ptr", FormatPhiIncoming(incoming, static value => ((RuntimeInlineDictionary)value).PointerName));
        var length = NextTemp(prefix + "_len");
        EmitPhi(length, "i64", FormatPhiIncoming(incoming, static value => ((RuntimeInlineDictionary)value).LengthName));
        var capacity = NextTemp(prefix + "_capacity");
        EmitPhi(capacity, "i64", FormatPhiIncoming(incoming, static value => ((RuntimeInlineDictionary)value).CapacityName));
        return first with { PointerName = pointer, LengthName = length, CapacityName = capacity };
    }

    private RuntimeStruct EmitStructPhi(
        string prefix,
        BoundType type,
        IReadOnlyList<(RuntimeValue Value, string Label)> incoming)
    {
        var value = NextTemp(prefix);
        EmitPhi(
            value,
            LlvmStructType(type),
            FormatPhiIncoming(incoming, static item => ((RuntimeStruct)item).ValueName));
        return new RuntimeStruct(type, value);
    }

    private RuntimeEnum EmitEnumPhi(
        string prefix,
        BoundType type,
        IReadOnlyList<(RuntimeValue Value, string Label)> incoming)
    {
        var value = NextTemp(prefix);
        EmitPhi(
            value,
            LlvmEnumType(type),
            FormatPhiIncoming(incoming, static item => ((RuntimeEnum)item).ValueName));
        return new RuntimeEnum(type, value);
    }

    private static (string Value, string Label)[] FormatPhiIncoming(
        IReadOnlyList<(RuntimeValue Value, string Label)> incoming,
        Func<RuntimeValue, string> getValueName)
    {
        return incoming
            .Select(item => (getValueName(item.Value), item.Label))
            .ToArray();
    }

}

