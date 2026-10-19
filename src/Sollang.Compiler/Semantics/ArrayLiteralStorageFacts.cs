using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.Semantics;

internal static class ArrayLiteralStorageFacts
{
    // Only ordinary compile-time numeric literals have immutable global backing.
    // Runtime, dynamic, and bounded arrays retain their local storage owner.
    public static bool HasStaticReadonlyBacking(Expression? expression) =>
        expression is ArrayLiteralExpression { IsDynamic: false, BoundedCapacity: null } literal
        && literal.Elements.All(static element => element is NumberExpression
            or NegateExpression { Value: NumberExpression });
}
