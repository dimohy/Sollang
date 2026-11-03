namespace Sollang.Compiler.Shared;

[AttributeUsage(AttributeTargets.Class | AttributeTargets.Enum)]
internal sealed class SelfHostPolicyAttribute(string module, string output, string source) : Attribute
{
    public string Module { get; } = module;
    public string Output { get; } = output;
    public string Source { get; } = source;
    public bool MultilineText { get; init; }
    public string? Region { get; init; }
}
