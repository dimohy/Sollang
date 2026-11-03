using System.Globalization;
using System.Text;

namespace Sollang.Compiler.Shared;

// Keep the source identity separate from LLVM quoting and auxiliary suffixes.
// Function declarations, calls and adapters must use the same encoded identity.
internal readonly record struct FunctionSymbolIdentity(string Symbol)
{
    public static string CanonicalName(string module, string name) =>
        module.Length == 0 || name.StartsWith(module + ".", StringComparison.Ordinal)
            ? name
            : module + "." + name;

    public static FunctionSymbolIdentity Create(
        string module, string name, bool isLocal, int line, int column)
    {
        var canonical = CanonicalName(module, name);
        // The escape marker is outside the legacy alphabet, preserving boundaries.
        var encoded = canonical.All(static c => char.IsAsciiLetterOrDigit(c) || c == '.')
            ? canonical.Replace('.', '_')
            : "$" + Convert.ToHexString(Encoding.UTF8.GetBytes(canonical));
        var symbol = "sollang_fn_" + encoded;
        if (isLocal)
        {
            var localModule = string.Concat(module.Select(
                static c => char.IsLetterOrDigit(c) || c == '_' ? c : '_'));
            symbol += "_local_m" + localModule + "_" + line.ToString(CultureInfo.InvariantCulture)
                + "_" + column.ToString(CultureInfo.InvariantCulture);
        }
        return new FunctionSymbolIdentity(symbol);
    }
}
