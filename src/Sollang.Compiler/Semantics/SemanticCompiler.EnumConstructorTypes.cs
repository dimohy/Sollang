namespace Sollang.Compiler.Semantics;

internal sealed partial class SemanticCompiler
{
    private bool TryResolveConstructorType(string typeName, int line, int column, out BoundType type)
    {
        // The same Option<T>/Result<T,E> spelling can belong to multiple
        // specialized owners. Resolve it under the active generic environment,
        // before consulting aliases left by another declaration or call.
        if (typeName.StartsWith("Option<", StringComparison.Ordinal)
            || typeName.StartsWith("Result<", StringComparison.Ordinal))
        {
            type = ParseType(typeName, line, column);
            return true;
        }
        return _types.TryResolveInModule(typeName, _currentModuleName, out type);
    }
}
