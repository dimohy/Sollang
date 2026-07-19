namespace Sollang.Compiler.Semantics;

internal sealed record SemanticFunctionReuse(
    string Identity,
    string ModuleName,
    IReadOnlyDictionary<string, string> Bindings,
    IReadOnlyDictionary<string, string> CapturedBindings);

internal sealed record SemanticReusePlan(
    byte[] DeclarationFingerprint,
    IReadOnlyDictionary<string, SemanticFunctionReuse> Functions);
