using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.Semantics;

internal sealed partial class SemanticCompiler
{
    private void RestoreEnumConstructorAliases(
        string ownerCallPrefix,
        string moduleName,
        IReadOnlyDictionary<string, object> syntaxCallsByIdentity)
    {
        // Cached bindings restore canonical type shapes, not every spelling
        // used by their unchanged bodies. Constructors are not function-call
        // targets, so restoring the resolved-call table cannot restore them.
        // Resolve their type syntax in its original module before lowering.
        var previousModule = _currentModuleName;
        _currentModuleName = moduleName;
        try
        {
            foreach (var pair in syntaxCallsByIdentity)
            {
                if (!pair.Key.StartsWith(ownerCallPrefix, StringComparison.Ordinal))
                    continue;
                var typeName = pair.Value switch
                {
                    CallExpression call when call.Path.Count >= 2 =>
                        string.Join('.', call.Path.Take(call.Path.Count - 1)),
                    FieldAccessExpression { Source: NameExpression name } => name.Name,
                    _ => null
                };
                if (typeName is null
                    || (!typeName.StartsWith("Option<", StringComparison.Ordinal)
                        && !typeName.StartsWith("Result<", StringComparison.Ordinal))
                    || _types.TryResolveInModule(typeName, moduleName, out _))
                    continue;
                var expression = (Expression)pair.Value;
                ParseType(typeName, expression.Line, expression.Column);
            }
        }
        finally
        {
            _currentModuleName = previousModule;
        }
    }
}
