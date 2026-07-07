using SLang.Compiler.Diagnostics;
using SLang.Compiler.Lexing;
using SLang.Compiler.Syntax;

namespace SLang.Compiler.Parsing;

internal sealed class Parser(IReadOnlyList<Token> tokens)
{
    private int _index;

    public SlangProgram Parse()
    {
        SkipNewLines();
        var main = ExpectIdentifier("main");
        if (main.Text != "main")
        {
            throw Error(main, "expected 'main' block");
        }

        Expect(TokenKind.LeftBrace);
        var statements = new List<Statement>();
        SkipNewLines();

        while (!Check(TokenKind.RightBrace) && !Check(TokenKind.End))
        {
            statements.Add(ParseStatement());
            SkipNewLines();
        }

        Expect(TokenKind.RightBrace);
        SkipNewLines();
        Expect(TokenKind.End);
        return new SlangProgram(statements);
    }

    private Statement ParseStatement()
    {
        if (Check(TokenKind.Identifier) && CheckNext(TokenKind.Equal))
        {
            var name = Advance();
            Advance();
            var expr = ParseExpression();
            ExpectStatementEnd();
            return new BindingStatement(name.Text, expr, name.Line, name.Column);
        }

        var expression = ParseExpression();
        ExpectStatementEnd();
        return new ExpressionStatement(expression);
    }

    private Expression ParseExpression()
    {
        if (Match(TokenKind.String, out var stringToken))
        {
            return new StringExpression(ParseStringSegments(stringToken), stringToken.Line, stringToken.Column);
        }

        if (Match(TokenKind.Identifier, out var identifier))
        {
            var path = new List<string> { identifier.Text };
            while (Match(TokenKind.Dot, out _))
            {
                path.Add(ExpectIdentifier().Text);
            }

            if (Match(TokenKind.LeftParen, out _))
            {
                var arguments = new List<Expression>();
                if (!Check(TokenKind.RightParen))
                {
                    do
                    {
                        arguments.Add(ParseExpression());
                    }
                    while (Match(TokenKind.Comma, out _));
                }

                Expect(TokenKind.RightParen);
                return new CallExpression(path, arguments, identifier.Line, identifier.Column);
            }

            if (path.Count != 1)
            {
                throw Error(identifier, "path values are reserved for calls and interpolation");
            }

            return new NameExpression(identifier.Text, identifier.Line, identifier.Column);
        }

        throw Error(Peek(), "expected expression");
    }

    private static IReadOnlyList<StringSegment> ParseStringSegments(Token token)
    {
        var segments = new List<StringSegment>();
        var text = token.Text;
        var start = 0;

        for (var i = 0; i < text.Length; i++)
        {
            if (text[i] == '}')
            {
                throw ErrorAt(token, "unexpected '}' in string literal");
            }

            if (text[i] != '{')
            {
                continue;
            }

            if (i > start)
            {
                segments.Add(new TextSegment(text[start..i]));
            }

            var close = text.IndexOf('}', i + 1);
            if (close < 0)
            {
                throw ErrorAt(token, "unterminated interpolation in string literal");
            }

            var pathText = text[(i + 1)..close];
            var path = ParseInterpolationPath(pathText, token);
            segments.Add(new InterpolationSegment(path));
            i = close;
            start = i + 1;
        }

        if (start < text.Length)
        {
            segments.Add(new TextSegment(text[start..]));
        }

        return segments;
    }

    private static IReadOnlyList<string> ParseInterpolationPath(string text, Token token)
    {
        if (text.Length == 0)
        {
            throw ErrorAt(token, "empty interpolation is not allowed");
        }

        var parts = text.Split('.');
        foreach (var part in parts)
        {
            if (part.Length == 0 || !IsIdentifier(part))
            {
                throw ErrorAt(token, $"invalid interpolation path '{{{text}}}'");
            }
        }

        return parts;
    }

    private static bool IsIdentifier(string value)
    {
        if (value.Length == 0 || !(value[0] == '_' || char.IsLetter(value[0])))
        {
            return false;
        }

        return value.Skip(1).All(c => c == '_' || char.IsLetterOrDigit(c));
    }

    private void ExpectStatementEnd()
    {
        if (Check(TokenKind.NewLine) || Check(TokenKind.RightBrace) || Check(TokenKind.End))
        {
            return;
        }

        throw Error(Peek(), "expected end of statement");
    }

    private void SkipNewLines()
    {
        while (Check(TokenKind.NewLine))
        {
            Advance();
        }
    }

    private Token Expect(TokenKind kind)
    {
        if (Match(kind, out var token))
        {
            return token;
        }

        throw Error(Peek(), $"expected {kind}");
    }

    private Token ExpectIdentifier(string? text = null)
    {
        var token = Expect(TokenKind.Identifier);
        if (text is not null && token.Text != text)
        {
            throw Error(token, $"expected '{text}'");
        }

        return token;
    }

    private bool Match(TokenKind kind, out Token token)
    {
        if (Check(kind))
        {
            token = Advance();
            return true;
        }

        token = default;
        return false;
    }

    private bool Check(TokenKind kind)
    {
        return Peek().Kind == kind;
    }

    private bool CheckNext(TokenKind kind)
    {
        return _index + 1 < tokens.Count && tokens[_index + 1].Kind == kind;
    }

    private Token Advance()
    {
        return tokens[_index++];
    }

    private Token Peek()
    {
        return tokens[_index];
    }

    private static SlangException Error(Token token, string message)
    {
        return new SlangException($"parse error at {token.Line}:{token.Column}: {message}");
    }

    private static SlangException ErrorAt(Token token, string message)
    {
        return new SlangException($"parse error at {token.Line}:{token.Column}: {message}");
    }
}
