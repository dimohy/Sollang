using Sollang.Compiler.Lexing;
using Sollang.Compiler.Syntax;

namespace Sollang.Compiler.Parsing;

internal static class SourceStyleAnalyzer
{
    internal const int ControlConditionInlineLimit = 45;

    private const string RedundantControlParenthesesMessage =
        "whole control conditions do not need parentheses; remove the outer '(' and ')'";

    public static IReadOnlyList<SourceStyleNote> Analyze(
        IReadOnlyList<Token> tokens,
        string moduleName)
    {
        var notes = new List<SourceStyleNote>();
        foreach (var condition in LongInlineControlConditions(tokens))
        {
            notes.Add(new SourceStyleNote(
                "N001",
                moduleName,
                condition.Line,
                condition.Column,
                $"control condition is {condition.Length} characters; keep conditions under {ControlConditionInlineLimit} on the same line as '{condition.Role}', or put the condition on its own line and then write '-> {condition.Role} {{' on the next line"));
        }
        foreach (var pair in RedundantControlParentheses(tokens))
        {
            var opening = tokens[pair.Opening];
            notes.Add(new SourceStyleNote(
                "N002",
                moduleName,
                opening.Line,
                opening.Column,
                RedundantControlParenthesesMessage));
        }
        return notes;
    }

    private static IReadOnlyList<(int Line, int Column, int Length, string Role)> LongInlineControlConditions(
        IReadOnlyList<Token> tokens)
    {
        var conditions = new List<(int Line, int Column, int Length, string Role)>();
        for (var arrowIndex = 0; arrowIndex < tokens.Count; arrowIndex++)
        {
            var arrow = tokens[arrowIndex];
            if (arrow.Kind != TokenKind.Arrow)
            {
                continue;
            }

            var targetIndex = NextNonNewLine(tokens, arrowIndex + 1);
            if (targetIndex >= tokens.Count
                || tokens[targetIndex].Kind != TokenKind.Identifier
                || tokens[targetIndex].Text is not ("if" or "unless" or "while")
                || tokens[targetIndex].Line != arrow.Line)
            {
                continue;
            }

            var endIndex = PreviousNonNewLine(tokens, arrowIndex - 1);
            if (endIndex < 0 || tokens[endIndex].Line != arrow.Line)
            {
                continue;
            }

            var startIndex = endIndex;
            while (startIndex > 0
                && tokens[startIndex - 1].Line == arrow.Line
                && tokens[startIndex - 1].Kind is not TokenKind.LeftBrace
                && tokens[startIndex - 1].Kind is not TokenKind.FatArrow)
            {
                startIndex--;
            }

            var start = tokens[startIndex];
            var end = tokens[endIndex];
            var length = end.Column + end.Text.Length - start.Column;
            if (length >= ControlConditionInlineLimit)
            {
                conditions.Add((start.Line, start.Column, length, tokens[targetIndex].Text));
            }
        }
        return conditions;
    }

    public static IReadOnlyList<(int Opening, int Closing)> RedundantControlParentheses(
        IReadOnlyList<Token> tokens)
    {
        var pairs = new List<(int Opening, int Closing)>();
        for (var arrowIndex = 0; arrowIndex < tokens.Count; arrowIndex++)
        {
            if (tokens[arrowIndex].Kind != TokenKind.Arrow)
            {
                continue;
            }

            var targetIndex = NextNonNewLine(tokens, arrowIndex + 1);
            if (targetIndex >= tokens.Count
                || tokens[targetIndex].Kind != TokenKind.Identifier
                || tokens[targetIndex].Text is not ("if" or "unless" or "while")
                || tokens[targetIndex].Line != tokens[arrowIndex].Line)
            {
                continue;
            }

            var closingIndex = PreviousNonNewLine(tokens, arrowIndex - 1);
            if (closingIndex < 0 || tokens[closingIndex].Kind != TokenKind.RightParen)
            {
                continue;
            }

            var openingIndex = MatchingOpeningParenthesis(tokens, closingIndex);
            if (openingIndex < 0
                || !BeginsExpression(tokens, openingIndex))
            {
                continue;
            }

            pairs.Add((openingIndex, closingIndex));
        }
        return pairs;
    }

    private static int MatchingOpeningParenthesis(IReadOnlyList<Token> tokens, int closingIndex)
    {
        var depth = 0;
        for (var index = closingIndex; index >= 0; index--)
        {
            if (tokens[index].Kind == TokenKind.RightParen)
            {
                depth++;
            }
            else if (tokens[index].Kind == TokenKind.LeftParen && --depth == 0)
            {
                return index;
            }
        }
        return -1;
    }

    private static bool BeginsExpression(IReadOnlyList<Token> tokens, int openingIndex)
    {
        if (openingIndex == 0)
        {
            return true;
        }

        return tokens[openingIndex - 1].Kind is
            TokenKind.NewLine or
            TokenKind.LeftBrace or
            TokenKind.LeftBracket or
            TokenKind.LeftParen or
            TokenKind.Comma or
            TokenKind.Colon or
            TokenKind.FatArrow;
    }

    private static int NextNonNewLine(IReadOnlyList<Token> tokens, int index)
    {
        while (index < tokens.Count && tokens[index].Kind == TokenKind.NewLine)
        {
            index++;
        }
        return index;
    }

    private static int PreviousNonNewLine(IReadOnlyList<Token> tokens, int index)
    {
        while (index >= 0 && tokens[index].Kind == TokenKind.NewLine)
        {
            index--;
        }
        return index;
    }
}
