using System.Globalization;
using SmallLang.Compiler.Diagnostics;
using SmallLang.Compiler.Semantics;
using SmallLang.Compiler.Syntax;

namespace SmallLang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private void EmitParallelCallbacks()
    {
        if (!_usesParallel)
        {
            return;
        }

        var previousFunction = _currentFunction;
        var previousFunctions = _currentFunctions;
        try
        {
            CollectParallelCallbacks(_program.MainStatements);
            foreach (var function in EnumerateEmittableFunctions(_program.Functions.Values))
            {
                if (function.IsStandardLibrary)
                {
                    continue;
                }
                _currentFunction = function;
                _currentFunctions = FunctionScope(function);
                CollectParallelCallbacks(function.BlockBody);
            }
        }
        finally
        {
            _currentFunction = previousFunction;
            _currentFunctions = previousFunctions;
        }
    }

    private void CollectParallelCallbacks(IReadOnlyList<Statement> statements)
    {
        foreach (var statement in statements)
        {
            if (statement is not BlockFunctionCallStatement block)
            {
                continue;
            }

            if (_program.ResolvedGenericCalls.TryGetValue(block, out var specialization)
                && specialization.Kind == BoundFunctionKind.RuntimeParallel
                && TryResolveDirectParallelTarget(block, out var target))
            {
                EmitDirectParallelCallback(block, specialization, target);
            }
            CollectParallelCallbacks(block.Body);
        }
    }

    private bool TryResolveDirectParallelTarget(
        BlockFunctionCallStatement block,
        out BoundFunction target)
    {
        target = null!;
        if (block.Body.Count != 1
            || block.Body[0] is not ExpressionStatement
            {
                Expression: FlowExpression
                {
                    Source: NameExpression source,
                    Targets.Count: 1
                } flow
            }
            || source.Name != block.ItemName
            || flow.Targets[0].Arguments.Count != 0
            || !TryResolveFunction(flow.Targets[0].Path, out target)
            || target.Kind != BoundFunctionKind.User
            || target.IsAsync)
        {
            target = null!;
            return false;
        }
        return true;
    }

    private void EmitDirectParallelCallback(
        BlockFunctionCallStatement block,
        BoundFunction specialization,
        BoundFunction target)
    {
        var inputType = specialization.BlockInputType
            ?? throw new SmallLangException("parallel input type was not specialized");
        var resultType = specialization.BlockResultType
            ?? throw new SmallLangException("parallel result type was not specialized");
        if (target.InputType != inputType || target.ReturnType != resultType)
        {
            return;
        }

        var inputArrayType = specialization.InputType!.Value;
        var inputSize = inputArrayType == BoundType.DynamicIntArray
            ? 4
            : _program.Types.GetDynamicArray(inputArrayType).ElementSize;
        var inputAlignment = inputArrayType == BoundType.DynamicIntArray
            ? 4
            : _program.Types.GetDynamicArray(inputArrayType).ElementAlignment;
        var outputSize = specialization.ReturnType == BoundType.DynamicIntArray
            ? 4
            : _program.Types.GetDynamicArray(specialization.ReturnType).ElementSize;
        var outputAlignment = specialization.ReturnType == BoundType.DynamicIntArray
            ? 4
            : _program.Types.GetDynamicArray(specialization.ReturnType).ElementAlignment;
        var callbackName = "smalllang_parallel_callback_"
            + _parallelCallbacks.Count.ToString(CultureInfo.InvariantCulture);
        var captures = CapturedBindingsForFunction(target);
        _parallelCallbacks.Add(block, new ParallelCallbackInfo(callbackName, target, captures));

        EmitFunctionLine($"define internal void @{callbackName}(ptr %group, i64 %index) #0 {{");
        EmitFunctionLine("entry:");
        EmitFunctionLine("  %input_slot = getelementptr %smalllang.compute_group, ptr %group, i32 0, i32 1");
        EmitFunctionLine("  %input = load ptr, ptr %input_slot, align 8");
        EmitFunctionLine($"  %input_offset = mul i64 %index, {inputSize.ToString(CultureInfo.InvariantCulture)}");
        EmitFunctionLine("  %input_address = getelementptr i8, ptr %input, i64 %input_offset");
        EmitFunctionLine($"  %item = load {LlvmType(inputType)}, ptr %input_address, align {inputAlignment.ToString(CultureInfo.InvariantCulture)}");
        var captureArguments = new List<string>();
        if (captures.Count > 0)
        {
            var captureType = ParallelCaptureType(captures);
            EmitFunctionLine("  %capture_environment_slot = getelementptr %smalllang.compute_group, ptr %group, i32 0, i32 4");
            EmitFunctionLine("  %capture_environment = load ptr, ptr %capture_environment_slot, align 8");
            for (var captureIndex = 0; captureIndex < captures.Count; captureIndex++)
            {
                var capture = captures[captureIndex];
                var captureTypeName = LlvmType(capture.Value);
                EmitFunctionLine($"  %capture_address_{captureIndex.ToString(CultureInfo.InvariantCulture)} = getelementptr {captureType}, ptr %capture_environment, i32 0, i32 {captureIndex.ToString(CultureInfo.InvariantCulture)}");
                EmitFunctionLine($"  %capture_value_{captureIndex.ToString(CultureInfo.InvariantCulture)} = load {captureTypeName}, ptr %capture_address_{captureIndex.ToString(CultureInfo.InvariantCulture)}, align {RuntimeAlignment(capture.Value).ToString(CultureInfo.InvariantCulture)}");
                captureArguments.Add($"{captureTypeName} %capture_value_{captureIndex.ToString(CultureInfo.InvariantCulture)}");
            }
        }
        captureArguments.Add($"{LlvmType(inputType)} %item");
        EmitFunctionLine($"  %mapped = call {LlvmType(resultType)} {SymbolForFunction(target)}(ptr null, ptr null, ptr null, ptr null, ptr null, {string.Join(", ", captureArguments)})");
        EmitFunctionLine("  %output_slot = getelementptr %smalllang.compute_group, ptr %group, i32 0, i32 2");
        EmitFunctionLine("  %output = load ptr, ptr %output_slot, align 8");
        EmitFunctionLine($"  %output_offset = mul i64 %index, {outputSize.ToString(CultureInfo.InvariantCulture)}");
        EmitFunctionLine("  %output_address = getelementptr i8, ptr %output, i64 %output_offset");
        EmitFunctionLine($"  store {LlvmType(resultType)} %mapped, ptr %output_address, align {outputAlignment.ToString(CultureInfo.InvariantCulture)}");
        EmitFunctionLine("  ret void");
        EmitFunctionLine("}");
        EmitFunctionLine();
    }

    private string ParallelCaptureType(IReadOnlyList<KeyValuePair<string, BoundType>> captures)
    {
        return "{ " + string.Join(", ", captures.Select(capture => LlvmType(capture.Value))) + " }";
    }
}
