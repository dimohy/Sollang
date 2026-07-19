using System.Text;

namespace Sollang.Compiler.CodeGen;

internal enum LlvmCodegenUnitKind : byte
{
    SharedPrefix = 0,
    Module = 1,
    SharedSuffix = 2
}

internal sealed record LlvmCodegenUnit(
    LlvmCodegenUnitKind Kind,
    string Identity,
    LlvmCodegenKey CacheKey,
    string Text,
    bool Reused)
{
    public static ulong StableIdentity(string identity)
    {
        return StableIdentity(Encoding.UTF8.GetBytes(identity));
    }

    public static ulong StableIdentity(ReadOnlySpan<byte> identity)
    {
        const ulong offset = 1469598103934665603;
        const ulong prime = 1099511628211;
        var hash = offset;
        foreach (var value in identity)
        {
            hash = unchecked(hash * prime + value);
        }
        return hash;
    }
}

internal readonly record struct LlvmCodegenKey(ulong InterfaceHash, ulong ImplementationHash);

internal sealed class LlvmCodegenOutput(IReadOnlyList<LlvmCodegenUnit> units)
{
    public IReadOnlyList<LlvmCodegenUnit> Units { get; } = units;

    public int ReusedCount => Units.Count(static unit => unit.Reused);

    public void CopyTo(ITextOutputSink output)
    {
        ArgumentNullException.ThrowIfNull(output);
        foreach (var unit in Units)
        {
            output.Write(unit.Text);
        }
    }

    public override string ToString()
    {
        var output = new MemoryOutputSink();
        CopyTo(output);
        return output.ToString();
    }
}

internal sealed record LlvmCodegenReuse(
    LlvmCodegenKey PrefixKey,
    LlvmCodegenKey SuffixKey,
    IReadOnlyDictionary<string, LlvmCodegenKey> ModuleKeys,
    IReadOnlyDictionary<(LlvmCodegenUnitKind Kind, string Identity, LlvmCodegenKey CacheKey), string> Fragments)
{
    public bool TryGet(
        LlvmCodegenUnitKind kind,
        string identity,
        LlvmCodegenKey cacheKey,
        out string fragment) => Fragments.TryGetValue((kind, identity, cacheKey), out fragment!);
}
