namespace Sollang.Compiler.Semantics;

internal sealed partial class SemanticCompiler
{
    // Type constructors nest independently. In a bounded capacity, <= is an
    // operator and must not open a generic argument list.
    private static int FindTopLevelTypeSeparator(ReadOnlySpan<char> text, char separator)
    {
        var angle = 0;
        var paren = 0;
        var bracket = 0;
        var brace = 0;
        for (var index = 0; index < text.Length; index++)
        {
            if (text[index] == separator && angle == 0 && paren == 0 && bracket == 0 && brace == 0)
                return index;
            switch (text[index])
            {
                case '<' when index + 1 == text.Length || text[index + 1] != '=': angle++; break;
                case '>': angle--; break;
                case '(': paren++; break;
                case ')': paren--; break;
                case '[': bracket++; break;
                case ']': bracket--; break;
                case '{': brace++; break;
                case '}': brace--; break;
            }
            if (angle < 0 || paren < 0 || bracket < 0 || brace < 0)
                return -1;
        }
        return -1;
    }

    private static int FindEnclosedTypeSeparator(string text, char separator)
    {
        if (text.Length < 2) return -1;
        var index = FindTopLevelTypeSeparator(text.AsSpan(1, text.Length - 2), separator);
        return index < 0 ? -1 : index + 1;
    }

    private static int FindBoundedTypeSeparator(string text)
    {
        var separator = FindEnclosedTypeSeparator(text, ';');
        return separator >= 0 && text.AsSpan(separator + 1).TrimStart().StartsWith("<=", StringComparison.Ordinal)
            ? separator : -1;
    }

    private static IReadOnlyList<string> SplitTopLevelTypeFields(string text)
    {
        var fields = new List<string>();
        var start = 0;
        int separator;
        while ((separator = FindTopLevelTypeSeparator(text.AsSpan(start), ',')) >= 0)
        {
            fields.Add(text.Substring(start, separator).Trim());
            start += separator + 1;
        }
        fields.Add(text[start..].Trim());
        return fields;
    }
}
