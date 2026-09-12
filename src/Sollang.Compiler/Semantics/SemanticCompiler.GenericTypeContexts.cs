namespace Sollang.Compiler.Semantics;

internal sealed partial class SemanticCompiler
{
    // A readonly slice and an explicit reference describe a borrowed view of
    // the argument, not a new generic scope. Infer their element with the same
    // compatibility rules used after specialization; place/escape checks still
    // run at the concrete call boundary.
    private bool TryGetBorrowedGenericElement(
        string typeTemplate,
        BoundType actualType,
        int line,
        int column,
        out string elementTemplate,
        out BoundType elementType)
    {
        if (typeTemplate.StartsWith("ref ", StringComparison.Ordinal))
        {
            elementTemplate = typeTemplate[4..].Trim();
            elementType = _types.IsReference(actualType)
                ? _types.GetReference(actualType).ElementType
                : actualType;
            return true;
        }
        if (typeTemplate.StartsWith('[', StringComparison.Ordinal)
            && typeTemplate.EndsWith(']')
            && FindEnclosedTypeSeparator(typeTemplate, ';') < 0)
        {
            elementTemplate = typeTemplate[1..^1].Trim();
            if (!TryGetContextualArrayElementType(actualType, out elementType))
                throw Error(line, column,
                    $"expected a readonly array view but received {FormatType(actualType)}");
            return true;
        }
        elementTemplate = "";
        elementType = default;
        return false;
    }
}
