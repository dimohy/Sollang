namespace Sollang.Compiler.Shared;

#if !BUILDING_GENERATOR
[SelfHostPolicy("sollang.compiler.semantic.function_type_binding_policy",
    "selfhost/semantic/generated/function_type_binding_policy.slg",
    "src/Sollang.Compiler/Shared/Policies/FunctionTypeBindingPolicy.cs")]
#endif
internal static class FunctionTypeBindingPolicy
{
    public static ulong GenericParameterInlineSize() => 8UL;

    public static string ParallelRoleNames() =>
        "sys.runtime.parallel|sys.runtime.tryParallel";

    public static bool BindReturnTypeEagerly(bool hasTemplate, bool intrinsic, bool parallelRole) =>
        !hasTemplate || intrinsic && !parallelRole;

    public static bool BindOwnershipTypeEagerly(bool hasTemplate, bool valueGeneric, bool explicitOwnership) =>
        hasTemplate && !valueGeneric && explicitOwnership;

    public static bool BindCallbackResultEagerly(bool hasCallbackInput) => hasCallbackInput;
}
