using Sollang.Compiler.Semantics;

namespace Sollang.Compiler.CodeGen;

internal sealed partial class LlvmEmitter
{
    private bool _usesAes128CpuSpecialization;

    private bool IsAes128CpuSpecialization(BoundFunction function)
    {
        return _targetContract.Architecture == TargetArchitecture.X86_64
            && _targetContract.DispatchPolicy == CpuDispatchPolicy.RuntimeDetect
            && (_targetContract.AllowedFeatures & TargetFeature.Aes) != 0
            && string.Equals(
                CanonicalFunctionName(function),
                "std.crypto.aes128.Key.encryptBlock",
                StringComparison.Ordinal)
            && !function.IsAsync
            && function.InputType is { } receiverType
            && _program.Types.IsStruct(receiverType)
            && string.Equals(
                _program.Types.GetStruct(receiverType).Name,
                "std.crypto.aes128.Key",
                StringComparison.Ordinal)
            && function.AdditionalParameters is { Count: 1 }
            && CapturedBindingsForFunction(function).Count == 0
            && _program.Types.IsStaticArray(function.ReturnType);
    }

    private bool TryEmitCpuSpecializedFunction(BoundFunction function)
    {
        if (!IsAes128CpuSpecialization(function)
            || function.InputType is not { } receiverType
            || function.AdditionalParameters is not { Count: 1 } parameters)
        {
            return false;
        }

        EmitAes128FunctionSet(function, receiverType, parameters[0].Type);
        return true;
    }

    private void EmitAes128FunctionSet(
        BoundFunction function,
        BoundType receiverType,
        BoundType inputType)
    {
        var symbol = SymbolForFunction(function);
        var portableSymbol = symbol + "_portable";
        var x86Symbol = symbol + "_x86";
        var resolverSymbol = symbol + "_resolve";
        var returnType = LlvmType(function.ReturnType);
        var receiverLlvmType = LlvmType(receiverType);
        var inputLlvmType = LlvmType(inputType);
        var parameters = ParameterListForFunction(function);
        var arguments = "ptr %stdin, ptr %stdout, ptr %written, ptr %read, ptr %ok_state, "
            + $"{receiverLlvmType} %it, {inputLlvmType} %arg_0";

        EmitStructFunction(function, portableSymbol);

        EmitFunctionLine("@sollang_cpu_features = internal global i64 -1, align 8");
        EmitFunctionLine($"@sollang_aes128_selected = internal global ptr {resolverSymbol}, align 8");
        EmitFunctionLine("declare <2 x i64> @llvm.x86.aesni.aesenc(<2 x i64>, <2 x i64>)");
        EmitFunctionLine("declare <2 x i64> @llvm.x86.aesni.aesenclast(<2 x i64>, <2 x i64>)");
        EmitFunctionLine();

        EmitFunctionLine("define internal i64 @sollang_cpu_features_once() {");
        EmitFunctionLine("entry:");
        EmitFunctionLine("  %cached = load atomic i64, ptr @sollang_cpu_features monotonic, align 8");
        EmitFunctionLine("  %initialized = icmp ne i64 %cached, -1");
        EmitFunctionLine("  br i1 %initialized, label %ready, label %detect");
        EmitFunctionLine("detect:");
        EmitFunctionLine("  %leaf1 = call { i32, i32, i32, i32 } asm \"xchgq %rbx, ${1:q}\\0Acpuid\\0Axchgq %rbx, ${1:q}\", \"={ax},=r,={cx},={dx},0,2\"(i32 1, i32 0)");
        EmitFunctionLine("  %leaf1_ecx = extractvalue { i32, i32, i32, i32 } %leaf1, 2");
        EmitFunctionLine("  %leaf1_edx = extractvalue { i32, i32, i32, i32 } %leaf1, 3");
        EmitFunctionLine("  %sse2_bits = and i32 %leaf1_edx, 67108864");
        EmitFunctionLine("  %has_sse2 = icmp ne i32 %sse2_bits, 0");
        EmitFunctionLine("  %sse2_mask = select i1 %has_sse2, i64 1, i64 0");
        EmitFunctionLine("  %aes_bits = and i32 %leaf1_ecx, 33554432");
        EmitFunctionLine("  %has_aes = icmp ne i32 %aes_bits, 0");
        EmitFunctionLine("  %aes_mask = select i1 %has_aes, i64 8, i64 0");
        EmitFunctionLine("  %detected = or i64 %sse2_mask, %aes_mask");
        EmitFunctionLine("  %installed = cmpxchg ptr @sollang_cpu_features, i64 -1, i64 %detected monotonic monotonic");
        EmitFunctionLine("  %observed = extractvalue { i64, i1 } %installed, 0");
        EmitFunctionLine("  %won = extractvalue { i64, i1 } %installed, 1");
        EmitFunctionLine("  %features = select i1 %won, i64 %detected, i64 %observed");
        EmitFunctionLine("  ret i64 %features");
        EmitFunctionLine("ready:");
        EmitFunctionLine("  ret i64 %cached");
        EmitFunctionLine("}");
        EmitFunctionLine();

        EmitFunctionLine($"define internal {returnType} {x86Symbol}({parameters}) #1 {{");
        EmitFunctionLine("entry:");
        EmitFunctionLine($"  %expanded_slice = extractvalue {receiverLlvmType} %it, 0");
        EmitFunctionLine("  %expanded = extractvalue %sollang.dynamic_int_array %expanded_slice, 0");
        EmitFunctionLine($"  %input = extractvalue {inputLlvmType} %arg_0, 0");
        EmitFunctionLine("  %output = call ptr @sollang_alloc(i64 16)");
        EmitFunctionLine("  %allocated = icmp ne ptr %output, null");
        EmitFunctionLine("  br i1 %allocated, label %encrypt, label %allocation_failed");
        EmitFunctionLine("allocation_failed:");
        EmitFunctionLine("  call void @llvm.trap()");
        EmitFunctionLine("  unreachable");
        EmitFunctionLine("encrypt:");
        EmitFunctionLine("  %input_value = load <2 x i64>, ptr %input, align 1");
        EmitFunctionLine("  %round0 = load <2 x i64>, ptr %expanded, align 1");
        EmitFunctionLine("  %state0 = xor <2 x i64> %input_value, %round0");
        for (var round = 1; round < 10; round++)
        {
            var previousRound = round - 1;
            var keyOffset = round * 16;
            EmitFunctionLine($"  %key{round}_ptr = getelementptr i8, ptr %expanded, i64 {keyOffset}");
            EmitFunctionLine($"  %key{round} = load <2 x i64>, ptr %key{round}_ptr, align 1");
            EmitFunctionLine($"  %state{round} = call <2 x i64> @llvm.x86.aesni.aesenc(<2 x i64> %state{previousRound}, <2 x i64> %key{round})");
        }
        EmitFunctionLine("  %key10_ptr = getelementptr i8, ptr %expanded, i64 160");
        EmitFunctionLine("  %key10 = load <2 x i64>, ptr %key10_ptr, align 1");
        EmitFunctionLine("  %state10 = call <2 x i64> @llvm.x86.aesni.aesenclast(<2 x i64> %state9, <2 x i64> %key10)");
        EmitFunctionLine("  store <2 x i64> %state10, ptr %output, align 1");
        EmitFunctionLine($"  %result0 = insertvalue {returnType} poison, ptr %output, 0");
        EmitFunctionLine($"  %result = insertvalue {returnType} %result0, i64 16, 1");
        EmitFunctionLine($"  ret {returnType} %result");
        EmitFunctionLine("}");
        EmitFunctionLine();

        EmitFunctionLine($"define internal {returnType} {resolverSymbol}({parameters}) {{");
        EmitFunctionLine("entry:");
        EmitFunctionLine("  %features = call i64 @sollang_cpu_features_once()");
        EmitFunctionLine("  %aes_feature = and i64 %features, 8");
        EmitFunctionLine("  %has_aes = icmp eq i64 %aes_feature, 8");
        EmitFunctionLine($"  %selected = select i1 %has_aes, ptr {x86Symbol}, ptr {portableSymbol}");
        EmitFunctionLine("  store atomic ptr %selected, ptr @sollang_aes128_selected monotonic, align 8");
        EmitFunctionLine($"  %result = tail call {returnType} %selected({arguments})");
        EmitFunctionLine($"  ret {returnType} %result");
        EmitFunctionLine("}");
        EmitFunctionLine();

        EmitFunctionLine($"define internal {returnType} {symbol}({parameters}) {{");
        EmitFunctionLine("entry:");
        EmitFunctionLine("  %selected = load atomic ptr, ptr @sollang_aes128_selected monotonic, align 8");
        EmitFunctionLine($"  %result = tail call {returnType} %selected({arguments})");
        EmitFunctionLine($"  ret {returnType} %result");
        EmitFunctionLine("}");
        EmitFunctionLine();
    }
}
