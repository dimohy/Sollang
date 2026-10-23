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

    private void EmitTrapUnless(string condition, string prefix, string? diagnosticCode = null)
    {
        var okLabel = NextLabel(prefix + "_ok");
        var failLabel = NextLabel(prefix + "_fail");
        var diagnosticIdentity = diagnosticCode ?? failLabel;
        var functionName = _currentFunction is null
            ? null
            : diagnosticCode is null
                ? _currentFunction.Name
                : _currentFunction.DeclarationName
                    ?? throw new SollangException("runtime diagnostic requires a source function declaration identity");
        var trapMessage = _currentFunction is null
            ? $"main:{diagnosticIdentity}"
            : $"{_currentFunction.ModuleName}.{functionName}:{diagnosticIdentity}";
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
        var (left, right) = EmitBinaryOperands(expression.Left, expression.Right);
        var integerOp = IsSignedIntegerType(left.Type) ? "sdiv" : "udiv";
        return EmitNumericBinary(left, right, integerOp, "fdiv", "div");
    }

    private RuntimeValue EmitModuloExpression(ModuloExpression expression)
    {
        var (left, right) = EmitBinaryOperands(expression.Left, expression.Right);
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
        var (left, right) = EmitBinaryOperands(leftExpression, rightExpression);
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
        var (left, right) = EmitBinaryOperands(expression.Left, expression.Right);
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

    private (RuntimeValue Left, RuntimeValue Right) EmitBinaryOperands(Expression leftExpression, Expression rightExpression)
    {
        // A numeric literal has no effects. Its single evaluated peer supplies
        // the width before literal emission, including a nested numeric peer.
        if (TryGetNumericLiteralText(leftExpression, out _))
        {
            var peer = EmitExpression(rightExpression);
            return (EmitFunctionArgumentExpression(leftExpression, peer.Type), peer);
        }

        var left = EmitExpression(leftExpression);
        if (left is RuntimeFormattedText or RuntimeTextChoice)
        {
            left = EmitTransientText(left);
        }
        var right = EmitFunctionArgumentExpression(rightExpression, left.Type);
        if (right is RuntimeFormattedText or RuntimeTextChoice)
        {
            right = EmitTransientText(right);
        }
        return (left, right);
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

    private BoundType? CommittedNumericResultType(Expression expression, BoundType? requestedType)
    {
        if (!_program.ContextualNumericTypes.TryGetValue(expression, out var committedType))
            return requestedType;
        if (requestedType is { } requested && requested != committedType)
            throw new SollangException("contextual numeric result disagrees with its committed semantic type");
        return committedType;
    }

    private RuntimeValue EmitIfExpression(IfExpression expression, BoundType? expectedResultType = null)
    {
        expectedResultType = CommittedNumericResultType(expression, expectedResultType);
        var condition = EmitBoolExpression(expression.Condition);
        var conditionLabel = _currentBlockLabel;
        var entryScope = CaptureLocals();
        var continuationScopes = CaptureAsyncContinuationBranchScopes();
        var continuationEdges = new List<(LocalScope[] Scopes, string Label)>();
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
            continuationEdges.Add((SnapshotAsyncContinuationScopes(continuationScopes), thenEndLabel));
            EmitBranch(endLabel);
        }

        RestoreAsyncContinuationScopes(continuationScopes);

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
                continuationEdges.Add((SnapshotAsyncContinuationScopes(continuationScopes), elseResult.EndLabel));
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
            continuationEdges.Add((continuationScopes.Select(item => item.Entry).ToArray(), conditionLabel));
        }
        else if (!elseTerminated)
        {
            incomingScopes.Add((elseResult!.ExitScope, elseResult.EndLabel));
        }
        if (HasCurrentFunctionAsyncCfg() || continuationScopes.Count > 0)
        {
            MergeAsyncOuterScope(entryScope, incomingScopes);
        }
        else
        {
            MergeSynchronousOuterScope(entryScope, incomingScopes);
        }
        MergeAsyncContinuationScopes(continuationScopes, continuationEdges, entryScope, incomingScopes);

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
        expectedResultType = CommittedNumericResultType(expression, expectedResultType);
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

        if (HasCurrentFunctionAsyncCfg())
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
        var source = EmitExpression(expression.Source);
        return source is RuntimeStruct { Type: BoundType.Range } range
            ? EmitRangeFoldExpression(expression, range)
            : EmitArrayFoldExpression(expression, source);
    }

    private RuntimeInt EmitRangeFoldExpression(FoldExpression expression, RuntimeStruct range)
    {
        var llvmType = LlvmStructType(BoundType.Range);
        var start = NextTemp("fold_range_start");
        EmitAssign(start, $"extractvalue {llvmType} {range.ValueName}, 0");
        var end = NextTemp("fold_range_end");
        EmitAssign(end, $"extractvalue {llvmType} {range.ValueName}, 1");
        var initial = EmitIntExpression(expression.Initial);
        var bodyLabel = NextLabel("fold_body");
        var continueLabel = NextLabel("fold_continue");
        var endLabel = NextLabel("fold_end");
        var entryLabel = _currentBlockLabel;
        var nextItem = NextTemp("fold_next");
        var initialDone = NextTemp("fold_done");

        EmitCompare(initialDone, "sgt", "i32", start, end);
        EmitConditionalBranch(initialDone, endLabel, bodyLabel);

        EmitLabel(bodyLabel);
        _currentBlockLabel = bodyLabel;
        var item = NextTemp(expression.ItemName);
        EmitPhi(item, "i32", (start, entryLabel), (nextItem, continueLabel));

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
        // Inclusive iteration ends on the current last item, before a wrapped
        // next item could re-enter a range whose end is Int.MaxValue.
        EmitCompare(done, "sge", "i32", item, end);
        EmitConditionalBranch(done, endLabel, bodyLabel);

        EmitLabel(endLabel);
        _currentBlockLabel = endLabel;
        var result = NextTemp("fold");
        EmitPhi(result, "i32", (initial.ValueName, entryLabel), (nextAccumulator, continueLabel));
        return new RuntimeInt(result);
    }

    private RuntimeInt EmitArrayFoldExpression(FoldExpression expression, RuntimeValue source)
    {
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
        if (HasCurrentFunctionAsyncCfg())
        {
            _asyncScopeSnapshots.Push(outerLocals);
        }
        try
        {
            EmitStatements(body.Statements, body.Value);
            if (_currentBlockTerminated)
            {
                return new BlockResult(null, _currentBlockLabel, CaptureLocals());
            }
            var value = body.Value is null
                ? null
                : expectedResultType is { } expected
                    ? EmitFunctionArgumentExpression(body.Value, expected)
                    : EmitExpression(body.Value);
            if (_currentBlockTerminated)
            {
                return new BlockResult(null, _currentBlockLabel, CaptureLocals());
            }
            var copiedOuterFixedStorage = false;
            if (value is RuntimeStaticIntArray or RuntimeStaticTextArray or RuntimeStaticInlineArray)
            {
                var copyExistingValue = _program.Types.IsCopyableFixedArray(value.Type)
                    && (body.Value is NameExpression resultName && outerLocals.Locals.ContainsKey(resultName.Name)
                        || body.Value is FieldAccessExpression
                            && RegisterOwnedFieldProjectionTransfer(body.Value, value.Type,
                                new Dictionary<string, List<IReadOnlyList<string>>>(StringComparer.Ordinal)));
                value = PrepareStaticArrayBlockResult(value, copyExistingValue);
                copiedOuterFixedStorage = copyExistingValue;
            }
            if (value is RuntimeStruct && _program.Types.RequiresFixedStorageCopy(value.Type)
                && (body.Value is NameExpression structName && outerLocals.Locals.ContainsKey(structName.Name)
                    || body.Value is FieldAccessExpression
                        && RegisterOwnedFieldProjectionTransfer(body.Value, value.Type,
                            new Dictionary<string, List<IReadOnlyList<string>>>(StringComparer.Ordinal))))
            {
                value = CopyFixedStorageValue(value);
                copiedOuterFixedStorage = true;
            }
            var transferredOwnerName = body.Value is not null
                && value is not null
                && !copiedOuterFixedStorage
                && IsOwnedContainerRuntimeValue(value)
                    ? GetBlockResultTransferredOwnerName(body.Value)
                    : null;
            DropOwnedLocalsCreatedSince(outerLocals, transferredOwnerName, body.Value);
            if (transferredOwnerName is not null
                && outerLocals.Locals.ContainsKey(transferredOwnerName)
                && !(_movedOwnedStructFields.TryGetValue(transferredOwnerName, out var transferredFields)
                    && transferredFields.Count > 0
                    // A match payload still owns its untransferred fields even
                    // when no later expression reads the binding.
                    && (OwnerReadInContinuation(transferredOwnerName)
                        || HasOwnedMatchPayloadCleanup(transferredOwnerName))))
            {
                RemoveLocal(transferredOwnerName);
            }
            return new BlockResult(value, _currentBlockLabel, CaptureLocals());
        }
        finally
        {
            if (HasCurrentFunctionAsyncCfg())
            {
                _asyncScopeSnapshots.Pop();
            }
            RestoreLocals(outerLocals);
        }
    }

    private sealed record AsyncContinuationBranchScope(LocalScope Scope, LocalScope Entry);

    private static LocalScope SnapshotAsyncContinuationScope(LocalScope scope)
    {
        var snapshot = KeepLocalsInScope(scope, scope.Locals.Keys);
        foreach (var (value, pointer) in scope.ReadonlyValueSlots)
            snapshot.ReadonlyValueSlots[value] = pointer;
        return snapshot;
    }

    private List<AsyncContinuationBranchScope> CaptureAsyncContinuationBranchScopes(bool includeLoopSnapshots = false)
    {
        if (_activeAsyncCfg is null)
            return [];
        var scopes = _asyncHiddenScopes
            .SelectMany(hidden => new[] { hidden.Scope }.Concat(hidden.Mirrors))
            .Concat(includeLoopSnapshots ? _asyncScopeSnapshots : Enumerable.Empty<LocalScope>());
        return scopes
            .Distinct<LocalScope>(ReferenceEqualityComparer.Instance)
            .Select(scope => new AsyncContinuationBranchScope(scope, SnapshotAsyncContinuationScope(scope)))
            .ToList();
    }

    private static LocalScope[] SnapshotAsyncContinuationScopes(
        IReadOnlyList<AsyncContinuationBranchScope> scopes) =>
        scopes.Select(item => SnapshotAsyncContinuationScope(item.Scope)).ToArray();

    private static void ReplaceAsyncContinuationScope(LocalScope target, LocalScope source)
    {
        static void CopyMap<TKey, TValue>(Dictionary<TKey, TValue> target, Dictionary<TKey, TValue> source)
            where TKey : notnull
        {
            target.Clear();
            foreach (var (key, value) in source) target.Add(key, value);
        }
        static void CopySet(HashSet<string> target, HashSet<string> source)
        {
            target.Clear();
            target.UnionWith(source);
        }
        CopyMap(target.Locals, source.Locals);
        CopySet(target.MutableLocals, source.MutableLocals);
        CopySet(target.BorrowedMutableLocals, source.BorrowedMutableLocals);
        CopySet(target.BorrowedOwnedLocals, source.BorrowedOwnedLocals);
        target.MovedOwnedStructFields.Clear();
        foreach (var (name, fields) in source.MovedOwnedStructFields)
            target.MovedOwnedStructFields.Add(name, new HashSet<string>(fields, StringComparer.Ordinal));
        CopyMap(target.MutableContainerSlots, source.MutableContainerSlots);
        CopyMap(target.MutableStructSlots, source.MutableStructSlots);
        CopyMap(target.MutableScalarSlots, source.MutableScalarSlots);
        CopyMap(target.ReadonlyCaptureBorrowPointers, source.ReadonlyCaptureBorrowPointers);
        CopyMap(target.ReadonlyValueSlots, source.ReadonlyValueSlots);
        CopyMap(target.BorrowedOwnedTransferFlags, source.BorrowedOwnedTransferFlags);
        target.TerminatingOwnedCleanupObligations.Clear();
        target.TerminatingOwnedCleanupObligations.AddRange(source.TerminatingOwnedCleanupObligations);
    }

    private static void RestoreAsyncContinuationScopes(IReadOnlyList<AsyncContinuationBranchScope> scopes)
    {
        foreach (var item in scopes) ReplaceAsyncContinuationScope(item.Scope, item.Entry);
    }

    private void MergeAsyncContinuationScopes(
        IReadOnlyList<AsyncContinuationBranchScope> scopes,
        IReadOnlyList<(LocalScope[] Scopes, string Label)> edges,
        LocalScope activeEntry,
        IReadOnlyList<(LocalScope Scope, string Label)> activeEdges,
        bool preserveBindingOwnership = false)
    {
        if (scopes.Count == 0 || edges.Count == 0) return;
        if (!edges.Select(edge => edge.Label).SequenceEqual(activeEdges.Select(edge => edge.Label)))
            throw new SollangException("async continuation branch predecessors do not match active scope");
        var activeMerged = CaptureLocals();
        var merged = scopes.Select(item => SnapshotAsyncContinuationScope(item.Entry)).ToArray();
        var aliases = new List<(LocalScope Entry, string Name, LocalScope Merged, LocalScope[] Incoming)>();
        foreach (var name in activeEntry.Locals.Keys)
            aliases.Add((activeEntry, name, activeMerged, activeEdges.Select(edge => edge.Scope).ToArray()));
        try
        {
            for (var index = 0; index < scopes.Count; index++)
            {
                var entry = scopes[index].Entry;
                var incoming = edges.Select(edge => edge.Scopes[index]).ToArray();
                foreach (var name in entry.Locals.Keys)
                {
                    var aliasIndex = aliases.FindIndex(alias =>
                        AsyncScopeSharesBinding(alias.Entry, alias.Name, entry, name)
                        && incoming.Select((scope, edge) =>
                        {
                            var aliasPresent = alias.Incoming[edge].Locals.ContainsKey(alias.Name);
                            var present = scope.Locals.ContainsKey(name);
                            return aliasPresent == present && (!present || AsyncScopeSharesBinding(
                                alias.Incoming[edge], alias.Name, scope, name));
                        }).All(static matches => matches));
                    if (aliasIndex >= 0)
                    {
                        var alias = aliases[aliasIndex];
                        // A cleanup snapshot can retain a borrowed view after
                        // the active owner transfers. Only reuse an alias whose
                        // incoming bindings still agree; otherwise join this
                        // scope's values and ownership independently below.
                        if (preserveBindingOwnership)
                            RestoreAsyncLoopBinding(merged[index], alias.Merged, name, alias.Name);
                        else
                            RestoreAsyncShadowedBinding(merged[index], alias.Merged, name, alias.Name);
                        continue;
                    }
                    var selected = incoming.Select((scope, edge) =>
                        (KeepLocalsInScope(scope, [name]), edges[edge].Label)).ToArray();
                    MergeAsyncOuterScope(KeepLocalsInScope(entry, [name]), selected);
                    var value = CaptureLocals();
                    if (preserveBindingOwnership)
                        RestoreAsyncLoopBinding(merged[index], value, name);
                    else
                        RestoreAsyncShadowedBinding(merged[index], value, name);
                    aliases.Add((entry, name, value, incoming));
                }
            }
            for (var index = 0; index < scopes.Count; index++)
                ReplaceAsyncContinuationScope(scopes[index].Scope, merged[index]);
        }
        finally
        {
            RestoreLocals(activeMerged);
        }
    }

    private static void RestoreAsyncLoopBinding(
        LocalScope target, LocalScope source, string name, string? sourceName = null)
    {
        sourceName ??= name;
        var borrowedOwned = target.BorrowedOwnedLocals.Contains(name);
        var borrowedMutable = target.BorrowedMutableLocals.Contains(name);
        var obligations = target.TerminatingOwnedCleanupObligations
            .Where(obligation => obligation.BindingName == name).ToArray();
        RestoreAsyncShadowedBinding(target, source, name, sourceName);
        if (borrowedOwned) target.BorrowedOwnedLocals.Add(name);
        else target.BorrowedOwnedLocals.Remove(name);
        if (borrowedMutable) target.BorrowedMutableLocals.Add(name);
        else target.BorrowedMutableLocals.Remove(name);
        target.TerminatingOwnedCleanupObligations.RemoveAll(obligation => obligation.BindingName == name);
        if (target.Locals.TryGetValue(name, out var value))
            target.TerminatingOwnedCleanupObligations.AddRange(obligations.Select(obligation => obligation with
            {
                Value = value,
                RetainedFlag = target.BorrowedOwnedTransferFlags.GetValueOrDefault(name) ?? obligation.RetainedFlag
            }));
    }

    private void MergeAsyncLoopScopes(
        LocalScope activeEntry,
        IReadOnlyList<(LocalScope Scope, string Label)> activeEdges,
        IReadOnlyList<AsyncContinuationBranchScope> continuations,
        IReadOnlyList<(LocalScope[] Scopes, string Label)> continuationEdges)
    {
        MergeAsyncOuterScope(activeEntry, activeEdges);
        var merged = CaptureLocals();
        var canonical = new List<string>();
        foreach (var name in activeEntry.Locals.Keys)
        {
            var alias = canonical.FirstOrDefault(candidate =>
                AsyncScopeSharesBinding(activeEntry, candidate, activeEntry, name)
                && activeEdges.All(edge =>
                    edge.Scope.Locals.ContainsKey(candidate) == edge.Scope.Locals.ContainsKey(name)
                    && (!edge.Scope.Locals.ContainsKey(name)
                        || AsyncScopeSharesBinding(edge.Scope, candidate, edge.Scope, name))));
            if (alias is null) canonical.Add(name);
            else RestoreAsyncLoopBinding(merged, merged, name, alias);
        }
        RestoreLocals(merged);
        MergeAsyncContinuationScopes(continuations, continuationEdges,
            activeEntry, activeEdges, preserveBindingOwnership: true);
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
        var removedLocals = new List<string>();
        foreach (var (name, entryValue) in entryScope.Locals)
        {
            var presentCount = incoming.Count(item => item.Scope.Locals.ContainsKey(name));
            if (presentCount == 0)
            {
                removedLocals.Add(name);
                continue;
            }
            if (presentCount != incoming.Count
                && entryScope.BorrowedOwnedLocals.Contains(name))
            {
                var borrowedValues = incoming
                    .Select(item => (
                        Value: item.Scope.Locals.GetValueOrDefault(name, PoisonRuntimeValue(entryValue)),
                        item.Label))
                    .ToArray();
                _locals[name] = EmitAsyncScopePhi($"async_{name}", entryValue.Type, borrowedValues);
                continue;
            }
            if (presentCount != incoming.Count)
            {
                throw new SollangException(
                    $"binding '{name}' has inconsistent ownership across async branch paths in '{_currentFunction?.Name ?? "<entry>"}'");
            }
            if (entryScope.MutableLocals.Contains(name))
            {
                MergeAsyncMutableSlot(name, entryScope, incoming);
                continue;
            }
            if (incoming.All(item => AsyncScopeSharesBinding(entryScope, name, item.Scope, name)))
            {
                _locals[name] = entryValue;
                continue;
            }
            var values = incoming
                .Select(item => (Value: item.Scope.Locals[name], item.Label))
                .ToArray();
            _locals[name] = EmitAsyncScopePhi($"async_{name}", entryValue.Type, values);
        }

        foreach (var (name, entryPointer) in entryScope.BorrowedOwnedTransferFlags)
        {
            var pointers = incoming
                .Select(item => item.Scope.BorrowedOwnedTransferFlags.GetValueOrDefault(name, entryPointer))
                .Distinct(StringComparer.Ordinal)
                .ToArray();
            _borrowedOwnedTransferFlags[name] = pointers.Length == 1
                ? pointers[0]
                : EmitAsyncPointerPhi(
                    $"async_{name}_owned_flag",
                    incoming.Select(item => (
                        item.Scope.BorrowedOwnedTransferFlags.GetValueOrDefault(name, entryPointer),
                        item.Label)).ToArray());
        }

        MergeOwnedStructFieldMoves(entryScope, incoming, requireEntryMask: false);
        foreach (var name in removedLocals)
        {
            RemoveLocal(name);
        }
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

        MergeOwnedStructFieldMoves(entryScope, incoming, requireEntryMask: false);
    }

    private void MergeOwnedStructFieldMoves(
        LocalScope entryScope,
        IReadOnlyList<(LocalScope Scope, string Label)> incoming,
        bool requireEntryMask)
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

            var mergedMask = masks[0];
            var entryMask = entryScope.MovedOwnedStructFields.TryGetValue(name, out var entryFields)
                ? entryFields
                : EmptyMovedFieldMask;
            if (requireEntryMask
                    ? masks.Any(mask => !entryMask.SetEquals(mask))
                    : masks.Skip(1).Any(mask => !mergedMask.SetEquals(mask)))
            {
                var changedFields = masks
                    .SelectMany(static mask => mask)
                    .Concat(requireEntryMask ? entryMask : EmptyMovedFieldMask)
                    .Distinct(StringComparer.Ordinal)
                    .Order(StringComparer.Ordinal);
                throw new SollangException(
                    $"sollang error[E20]: partial move of owned field(s) "
                    + $"'{string.Join(", ", changedFields)}' from binding '{name}' exits a branch; "
                    + "reinitialize each moved field before the branch exits or return from the moving branch");
            }
            if (mergedMask.Count == 0)
            {
                _movedOwnedStructFields.Remove(name);
            }
            else
            {
                _movedOwnedStructFields[name] = new HashSet<string>(mergedMask, StringComparer.Ordinal);
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
        if (incoming.All(item => item.Value.Type == BoundType.Text)
            && incoming.Any(item => item.Value is RuntimeFormattedText or RuntimeTextChoice))
        {
            // Keep deferred formatting as a tagged SSA choice. Each inactive
            // alternative has poison components, read only after its tag wins.
            // No branch is formatted, copied or allocated at the join.
            var tag = NextTemp($"{prefix}_text_tag");
            EmitPhi(tag, "i64", incoming.Select((item, index) =>
                (index.ToString(CultureInfo.InvariantCulture), item.Label)).ToArray());
            var alternatives = new List<RuntimeValue>(incoming.Count);
            for (var index = 0; index < incoming.Count; index++)
            {
                var template = incoming[index].Value;
                var active = index;
                var components = incoming.Select((item, position) => (
                    Value: position == active ? template : PoisonRuntimeValue(template),
                    item.Label)).ToArray();
                alternatives.Add(EmitDeferredTextComponentsPhi(prefix, template, components));
            }
            return new RuntimeTextChoice(tag, alternatives);
        }
        return incoming[0].Value switch
        {
            RuntimeArguments => new RuntimeArguments(EmitScalarPhi(prefix, "i64", incoming)),
            RuntimeMappedBytes mapped => EmitMappedBytesPhi(prefix, mapped, incoming),
            RuntimeInt integer => new RuntimeInt(integer.Type, EmitScalarPhi(prefix, LlvmType(integer.Type), incoming)),
            RuntimeFloat floating => new RuntimeFloat(floating.Type, EmitScalarPhi(prefix, LlvmType(floating.Type), incoming)),
            RuntimeBool => new RuntimeBool(EmitScalarPhi(prefix, "i1", incoming)),
            RuntimeText => EmitTextPhi(prefix, incoming),
            RuntimeTask task => EmitTaskPhi(prefix, task, incoming),
            RuntimeProducerStream stream => EmitProducerStreamPhi(prefix, stream, incoming),
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

    private RuntimeValue EmitDeferredTextComponentsPhi(
        string prefix,
        RuntimeValue template,
        IReadOnlyList<(RuntimeValue Value, string Label)> incoming)
    {
        if (template is RuntimeFormattedText formatted)
        {
            var segments = new List<RuntimeFormattedTextSegment>(formatted.Segments.Count);
            for (var index = 0; index < formatted.Segments.Count; index++)
            {
                var active = index;
                var segment = formatted.Segments[index];
                var components = incoming.Select(item => (
                    Value: ((RuntimeFormattedText)item.Value).Segments[active] switch
                    {
                        RuntimeFormattedTextLiteral literal => (RuntimeValue)literal.Text,
                        RuntimeFormattedTextValue value => value.Value,
                        _ => throw new SollangException("unsupported deferred text segment")
                    }, item.Label)).ToArray();
                var value = EmitDeferredTextComponentsPhi(prefix, components[0].Value, components);
                segments.Add(segment is RuntimeFormattedTextLiteral
                    ? new RuntimeFormattedTextLiteral((RuntimeText)value)
                    : new RuntimeFormattedTextValue(value));
            }
            return new RuntimeFormattedText(segments);
        }
        if (template is RuntimeTextChoice choice)
        {
            var tag = NextTemp($"{prefix}_nested_text_tag");
            EmitPhi(tag, "i64", incoming.Select(item =>
                (((RuntimeTextChoice)item.Value).TagName, item.Label)).ToArray());
            var alternatives = new List<RuntimeValue>(choice.Alternatives.Count);
            for (var index = 0; index < choice.Alternatives.Count; index++)
            {
                var active = index;
                var components = incoming.Select(item => (
                    Value: ((RuntimeTextChoice)item.Value).Alternatives[active], item.Label)).ToArray();
                alternatives.Add(EmitDeferredTextComponentsPhi(prefix, choice.Alternatives[index], components));
            }
            return new RuntimeTextChoice(tag, alternatives);
        }
        return EmitPhiValue(prefix, incoming);
    }

    private RuntimeValue EmitConsumeTextChoice(RuntimeTextChoice choice, Func<RuntimeValue, RuntimeValue> consume)
    {
        var end = NextLabel("text_choice_end");
        var incoming = new List<(RuntimeValue Value, string Label)>(choice.Alternatives.Count);
        for (var index = 0; index < choice.Alternatives.Count; index++)
        {
            var arm = NextLabel("text_choice_arm");
            string? next = null;
            if (index + 1 < choice.Alternatives.Count)
            {
                next = NextLabel("text_choice_next");
                var selected = NextTemp("text_choice_selected");
                EmitCompare(selected, "eq", "i64", choice.TagName, index.ToString(CultureInfo.InvariantCulture));
                EmitConditionalBranch(selected, arm, next);
            }
            else
            {
                // Tags are emitted solely from the exhaustive predecessor list.
                EmitBranch(arm);
            }
            EmitLabel(arm);
            var value = consume(choice.Alternatives[index]);
            incoming.Add((value, _currentBlockLabel));
            EmitBranch(end);
            if (next is not null) EmitLabel(next);
        }
        EmitLabel(end);
        return EmitPhiValue("text_choice_result", incoming);
    }

    private static RuntimeValue PoisonRuntimeValue(RuntimeValue template) => template switch
    {
        RuntimeArguments value => value with { LengthName = "poison" },
        RuntimeMappedBytes value => value with
        {
            DataPointerName = "poison", LengthName = "poison",
            BasePointerName = "poison", MappedLengthName = "poison"
        },
        RuntimeInt value => value with { ValueName = "poison" },
        RuntimeFloat value => value with { ValueName = "poison" },
        RuntimeBool value => value with { ValueName = "poison" },
        RuntimeText value => value with { PointerName = "poison", LengthName = "poison" },
        RuntimeFormattedText value => new RuntimeFormattedText(value.Segments.Select(segment => segment switch
        {
            RuntimeFormattedTextLiteral literal => (RuntimeFormattedTextSegment)new RuntimeFormattedTextLiteral(
                (RuntimeText)PoisonRuntimeValue(literal.Text)),
            RuntimeFormattedTextValue item => new RuntimeFormattedTextValue(PoisonRuntimeValue(item.Value)),
            _ => throw new SollangException("unsupported deferred text segment")
        }).ToArray()),
        RuntimeTextChoice value => new RuntimeTextChoice("poison", value.Alternatives.Select(PoisonRuntimeValue).ToArray()),
        RuntimeTask value => value with { HandleName = "poison", ContextName = "poison" },
        RuntimeProducerStream value => value with
        {
            ContextName = "poison", NextName = "poison", DropName = "poison"
        },
        RuntimeBox value => value with { PointerName = "poison" },
        RuntimeReference value => value with { PointerName = "poison" },
        RuntimeInlineSlice value => value with { PointerName = "poison", LengthName = "poison" },
        RuntimeStaticIntArray value => value with { PointerName = "poison", LengthName = "poison" },
        RuntimeStaticTextArray value => value with { PointerName = "poison", LengthName = "poison" },
        RuntimeStaticInlineArray value => value with { PointerName = "poison", LengthName = "poison" },
        RuntimeDynamicIntArray value => value with
        {
            PointerName = "poison", LengthName = "poison", CapacityName = "poison"
        },
        RuntimeDynamicInlineArray value => value with
        {
            PointerName = "poison", LengthName = "poison", CapacityName = "poison"
        },
        RuntimeIntDictionary value => value with
        {
            PointerName = "poison", LengthName = "poison", CapacityName = "poison"
        },
        RuntimeInlineDictionary value => value with
        {
            PointerName = "poison", LengthName = "poison", CapacityName = "poison"
        },
        RuntimeStruct value => value with { ValueName = "poison" },
        RuntimeEnum value => value with { ValueName = "poison" },
        _ => throw new SollangException(
            $"unsupported borrowed async phi value {template.GetType().Name}")
    };

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

    private RuntimeMappedBytes EmitMappedBytesPhi(
        string prefix,
        RuntimeMappedBytes first,
        IReadOnlyList<(RuntimeValue Value, string Label)> incoming)
    {
        if (incoming.Any(item => item.Value is not RuntimeMappedBytes mapped
            || mapped.MappedType != first.MappedType))
        {
            throw new SollangException("MappedBytes phi inputs disagree on runtime shape");
        }
        var data = NextTemp(prefix + "_data");
        EmitPhi(data, "ptr", FormatPhiIncoming(incoming,
            static value => ((RuntimeMappedBytes)value).DataPointerName));
        var length = NextTemp(prefix + "_len");
        EmitPhi(length, "i64", FormatPhiIncoming(incoming,
            static value => ((RuntimeMappedBytes)value).LengthName));
        var basePointer = NextTemp(prefix + "_base");
        EmitPhi(basePointer, "ptr", FormatPhiIncoming(incoming,
            static value => ((RuntimeMappedBytes)value).BasePointerName));
        var mappedLength = NextTemp(prefix + "_mapped_len");
        EmitPhi(mappedLength, "i64", FormatPhiIncoming(incoming,
            static value => ((RuntimeMappedBytes)value).MappedLengthName));
        return first with
        {
            DataPointerName = data, LengthName = length,
            BasePointerName = basePointer, MappedLengthName = mappedLength
        };
    }

    private RuntimeText EmitTextPhi(string prefix, IReadOnlyList<(RuntimeValue Value, string Label)> incoming)
    {
        var pointer = NextTemp(prefix + "_ptr");
        EmitPhi(pointer, "ptr", FormatPhiIncoming(incoming, static value => ((RuntimeText)value).PointerName));

        var length = NextTemp(prefix + "_len");
        EmitPhi(length, "i64", FormatPhiIncoming(incoming, static value => ((RuntimeText)value).LengthName));

        return new RuntimeText(pointer, length);
    }

    private RuntimeProducerStream EmitProducerStreamPhi(
        string prefix,
        RuntimeProducerStream first,
        IReadOnlyList<(RuntimeValue Value, string Label)> incoming)
    {
        if (incoming.Any(item => item.Value is not RuntimeProducerStream stream
            || stream.Type != first.Type || stream.ElementType != first.ElementType
            || stream.IsEvent != first.IsEvent))
            throw new SollangException("Stream phi inputs disagree on runtime shape");
        var context = NextTemp(prefix + "_context");
        EmitPhi(context, "ptr", FormatPhiIncoming(incoming,
            static value => ((RuntimeProducerStream)value).ContextName));
        var next = NextTemp(prefix + "_next");
        EmitPhi(next, "ptr", FormatPhiIncoming(incoming,
            static value => ((RuntimeProducerStream)value).NextName));
        var drop = NextTemp(prefix + "_drop");
        EmitPhi(drop, "ptr", FormatPhiIncoming(incoming,
            static value => ((RuntimeProducerStream)value).DropName));
        return first with { ContextName = context, NextName = next, DropName = drop };
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
        return first with
        {
            HandleName = handle,
            ContextName = context,
            DiagnosticHeaderName = first.DiagnosticHeaderName is null
                ? null
                : AsyncContextField(
                    context, first.InputType, first.ResultType, 10, "async_phi_task_diagnostic_header")
        };
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

