using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.IO;
using System.Linq;
using System.Text;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.Text;

namespace SmallLang.Compiler.Generators;

[Generator(LanguageNames.CSharp)]
public sealed class LexerSourceGenerator : IIncrementalGenerator
{
    private static readonly DiagnosticDescriptor InvalidSpec = new(
        id: "SLANGGEN001",
        title: "Invalid SmallLang lexer specification",
        messageFormat: "{0}",
        category: "SmallLang.Lexer",
        defaultSeverity: DiagnosticSeverity.Error,
        isEnabledByDefault: true);

    public void Initialize(IncrementalGeneratorInitializationContext context)
    {
        var specs = context.AdditionalTextsProvider
            .Where(static text => Path.GetFileName(text.Path).Equals("smalllang.lexer", StringComparison.OrdinalIgnoreCase))
            .Select(static (text, cancellationToken) => LexerSpec.Parse(
                text.Path,
                text.GetText(cancellationToken)?.ToString() ?? string.Empty));

        context.RegisterSourceOutput(specs, static (sourceProductionContext, spec) =>
        {
            if (spec.Error is not null)
            {
                sourceProductionContext.ReportDiagnostic(Diagnostic.Create(InvalidSpec, Location.None, spec.Error));
                return;
            }

            sourceProductionContext.AddSource(
                "GeneratedLexer.g.cs",
                SourceText.From(LexerEmitter.Emit(spec), Encoding.UTF8));
        });
    }
}

internal sealed record LexerSpec(
    string LexerType,
    ImmutableArray<TokenRule> Tokens,
    ImmutableArray<SkipRule> Skips,
    string? Error)
{
    public static LexerSpec Parse(string path, string text)
    {
        var lexerType = "SmallLang.Compiler.Lexing.Lexer";
        var tokens = ImmutableArray.CreateBuilder<TokenRule>();
        var skips = ImmutableArray.CreateBuilder<SkipRule>();
        var hasEnd = false;

        var lines = text.Replace("\r\n", "\n").Replace('\r', '\n').Split('\n');
        for (var i = 0; i < lines.Length; i++)
        {
            var lineNumber = i + 1;
            var line = StripComment(lines[i]).Trim();
            if (line.Length == 0)
            {
                continue;
            }

            if (line.StartsWith("lexer ", StringComparison.Ordinal))
            {
                lexerType = line.Substring("lexer ".Length).Trim();
                if (!IsQualifiedIdentifier(lexerType))
                {
                    return Failure(path, lineNumber, $"invalid lexer type '{lexerType}'");
                }

                continue;
            }

            if (line.StartsWith("skip ", StringComparison.Ordinal))
            {
                var parsed = ParseRule(line.Substring("skip ".Length), path, lineNumber, SkipRule.Create);
                if (parsed.Error is not null)
                {
                    return parsed.Error;
                }

                skips.Add(parsed.Rule!);
                continue;
            }

            if (line.StartsWith("token ", StringComparison.Ordinal))
            {
                var parsed = ParseRule(line.Substring("token ".Length), path, lineNumber, TokenRule.Create);
                if (parsed.Error is not null)
                {
                    return parsed.Error;
                }

                if (parsed.Rule!.Pattern == "end")
                {
                    hasEnd = true;
                }

                tokens.Add(parsed.Rule);
                continue;
            }

            return Failure(path, lineNumber, $"expected 'lexer', 'token', or 'skip', got '{line}'");
        }

        if (!hasEnd)
        {
            return Failure(path, 0, "lexer specification must declare 'token End = end'");
        }

        return new LexerSpec(lexerType, tokens.ToImmutable(), skips.ToImmutable(), null);
    }

    private static ParseResult<TRule> ParseRule<TRule>(
        string line,
        string path,
        int lineNumber,
        Func<string, string, TRule> create)
        where TRule : class
    {
        var equal = line.IndexOf('=');
        if (equal < 0)
        {
            return ParseResult<TRule>.Fail(Failure(path, lineNumber, "rule must use '='"));
        }

        var name = line.Substring(0, equal).Trim();
        var pattern = line.Substring(equal + 1).Trim();
        if (!IsIdentifier(name))
        {
            return ParseResult<TRule>.Fail(Failure(path, lineNumber, $"invalid rule name '{name}'"));
        }

        if (pattern.Length == 0)
        {
            return ParseResult<TRule>.Fail(Failure(path, lineNumber, $"rule '{name}' has an empty pattern"));
        }

        return ParseResult<TRule>.Ok(create(name, pattern));
    }

    private static string StripComment(string line)
    {
        var comment = line.IndexOf('#');
        return comment >= 0 ? line.Substring(0, comment) : line;
    }

    private static bool IsQualifiedIdentifier(string value)
    {
        return value.Split('.').All(IsIdentifier);
    }

    private static bool IsIdentifier(string value)
    {
        if (value.Length == 0 || !(value[0] == '_' || char.IsLetter(value[0])))
        {
            return false;
        }

        for (var i = 1; i < value.Length; i++)
        {
            if (!(value[i] == '_' || char.IsLetterOrDigit(value[i])))
            {
                return false;
            }
        }

        return true;
    }

    private static LexerSpec Failure(string path, int line, string message)
    {
        var prefix = line > 0 ? $"{path}:{line}" : path;
        return new LexerSpec(
            "SmallLang.Compiler.Lexing.Lexer",
            ImmutableArray<TokenRule>.Empty,
            ImmutableArray<SkipRule>.Empty,
            $"{prefix}: {message}");
    }
}

internal sealed record TokenRule(string Name, string Pattern)
{
    public static TokenRule Create(string name, string pattern) => new(name, pattern);
}

internal sealed record SkipRule(string Name, string Pattern)
{
    public static SkipRule Create(string name, string pattern) => new(name, pattern);
}

internal sealed record ParseResult<TRule>(TRule? Rule, LexerSpec? Error)
    where TRule : class
{
    public static ParseResult<TRule> Ok(TRule rule) => new(rule, null);

    public static ParseResult<TRule> Fail(LexerSpec error) => new(null, error);
}

internal static class LexerEmitter
{
    public static string Emit(LexerSpec spec)
    {
        var lastDot = spec.LexerType.LastIndexOf('.');
        var ns = lastDot >= 0 ? spec.LexerType.Substring(0, lastDot) : "SmallLang.Compiler.Lexing";
        var typeName = lastDot >= 0 ? spec.LexerType.Substring(lastDot + 1) : spec.LexerType;
        var literalRules = spec.Tokens
            .Where(static rule => rule.Pattern.StartsWith("\"", StringComparison.Ordinal) && rule.Pattern.EndsWith("\"", StringComparison.Ordinal))
            .ToArray();
        var literalRulesByFirstCharacter = literalRules
            .Select(static rule => new LiteralTokenRule(rule.Name, Unquote(rule.Pattern)))
            .GroupBy(static rule => rule.Literal[0])
            .ToArray();
        var hasWhitespaceSkip = spec.Skips.Any(static rule => rule.Pattern == "whitespace");
        var hasLineCommentSkip = spec.Skips.Any(static rule => rule.Pattern == "line_comment");
        var hasNewLine = spec.Tokens.Any(static rule => rule.Pattern == "newline");
        var hasString = spec.Tokens.Any(static rule => rule.Pattern == "quoted_string");
        var hasIdentifier = spec.Tokens.Any(static rule => rule.Pattern == "identifier");
        var hasNumber = spec.Tokens.Any(static rule => rule.Pattern == "number");

        var builder = new StringBuilder();
        builder.AppendLine("// <auto-generated />");
        builder.AppendLine("using System;");
        builder.AppendLine("using System.Collections.Generic;");
        builder.AppendLine("using SmallLang.Compiler.Diagnostics;");
        builder.AppendLine();
        builder.Append("namespace ").Append(ns).AppendLine(";");
        builder.AppendLine();
        EmitTokenKind(builder, spec.Tokens);
        builder.AppendLine();
        builder.Append("internal sealed class ").Append(typeName).AppendLine("(string source)");
        builder.AppendLine("{");
        builder.AppendLine("    private readonly List<Token> _tokens = [];");
        builder.AppendLine("    private int _index;");
        builder.AppendLine("    private int _line = 1;");
        builder.AppendLine("    private int _column = 1;");
        builder.AppendLine();
        builder.AppendLine("    public IReadOnlyList<Token> Lex()");
        builder.AppendLine("    {");
        builder.AppendLine("        while (!IsAtEnd)");
        builder.AppendLine("        {");
        builder.AppendLine("            var c = Current;");
        builder.AppendLine("            switch (c)");
        builder.AppendLine("            {");

        if (hasWhitespaceSkip)
        {
            builder.AppendLine("                case ' ' or '\\t':");
            builder.AppendLine("                    Advance();");
            builder.AppendLine("                    break;");
        }

        if (hasNewLine)
        {
            builder.AppendLine("                case '\\r' or '\\n':");
            builder.AppendLine("                    LexNewLine();");
            builder.AppendLine("                    break;");
        }

        if (hasLineCommentSkip)
        {
            builder.AppendLine("                case '#':");
            builder.AppendLine("                    SkipLineComment();");
            builder.AppendLine("                    break;");
        }

        foreach (var group in literalRulesByFirstCharacter)
        {
            var orderedRules = group
                .OrderByDescending(static rule => rule.Literal.Length)
                .ToArray();
            builder.Append("                case '").Append(EscapeChar(group.Key)).AppendLine("':");
            EmitLiteralTokenCase(builder, orderedRules);
            builder.AppendLine("                    break;");
        }

        if (hasString)
        {
            builder.AppendLine("                case '\"':");
            builder.AppendLine("                    LexString();");
            builder.AppendLine("                    break;");
        }

        builder.AppendLine("                default:");
        if (hasIdentifier || hasNumber)
        {
            if (hasIdentifier)
            {
                builder.AppendLine("                    if (IsIdentifierStart(c))");
                builder.AppendLine("                    {");
                builder.AppendLine("                        LexIdentifier();");
                builder.AppendLine("                    }");
            }

            if (hasNumber)
            {
                builder.Append(hasIdentifier ? "                    else if" : "                    if")
                    .AppendLine(" (char.IsDigit(c))");
                builder.AppendLine("                    {");
                builder.AppendLine("                        LexNumber();");
                builder.AppendLine("                    }");
            }

            builder.AppendLine("                    else");
            builder.AppendLine("                    {");
            builder.AppendLine("                        throw Error($\"unexpected character '{c}'\");");
            builder.AppendLine("                    }");
        }
        else
        {
            builder.AppendLine("                    throw Error($\"unexpected character '{c}'\");");
        }

        builder.AppendLine("                    break;");
        builder.AppendLine("            }");
        builder.AppendLine("        }");
        builder.AppendLine();
        builder.AppendLine("        _tokens.Add(new Token(TokenKind.End, \"\", _line, _column));");
        builder.AppendLine("        return _tokens;");
        builder.AppendLine("    }");
        builder.AppendLine();
        builder.AppendLine("    private bool IsAtEnd => _index >= source.Length;");
        builder.AppendLine();
        builder.AppendLine("    private char Current => source[_index];");
        builder.AppendLine();
        builder.AppendLine("    private void AddSingle(TokenKind kind)");
        builder.AppendLine("    {");
        builder.AppendLine("        _tokens.Add(new Token(kind, Current.ToString(), _line, _column));");
        builder.AppendLine("        Advance();");
        builder.AppendLine("    }");
        builder.AppendLine();
        builder.AppendLine("    private void AddLiteral(string literal, TokenKind kind)");
        builder.AppendLine("    {");
        builder.AppendLine("        var line = _line;");
        builder.AppendLine("        var column = _column;");
        builder.AppendLine("        for (var i = 0; i < literal.Length; i++)");
        builder.AppendLine("        {");
        builder.AppendLine("            if (IsAtEnd || Current != literal[i])");
        builder.AppendLine("            {");
        builder.AppendLine("                throw ErrorAt(line, column, $\"expected '{literal}'\");");
        builder.AppendLine("            }");
        builder.AppendLine();
        builder.AppendLine("            Advance();");
        builder.AppendLine("        }");
        builder.AppendLine();
        builder.AppendLine("        _tokens.Add(new Token(kind, literal, line, column));");
        builder.AppendLine("    }");
        builder.AppendLine();
        builder.AppendLine("    private bool MatchesLiteral(string literal)");
        builder.AppendLine("    {");
        builder.AppendLine("        if (_index + literal.Length > source.Length)");
        builder.AppendLine("        {");
        builder.AppendLine("            return false;");
        builder.AppendLine("        }");
        builder.AppendLine();
        builder.AppendLine("        for (var i = 0; i < literal.Length; i++)");
        builder.AppendLine("        {");
        builder.AppendLine("            if (source[_index + i] != literal[i])");
        builder.AppendLine("            {");
        builder.AppendLine("                return false;");
        builder.AppendLine("            }");
        builder.AppendLine("        }");
        builder.AppendLine();
        builder.AppendLine("        return true;");
        builder.AppendLine("    }");
        builder.AppendLine();
        builder.AppendLine("    private void LexNewLine()");
        builder.AppendLine("    {");
        builder.AppendLine("        var line = _line;");
        builder.AppendLine("        var column = _column;");
        builder.AppendLine("        if (Current == '\\r')");
        builder.AppendLine("        {");
        builder.AppendLine("            AdvanceRaw();");
        builder.AppendLine("            if (!IsAtEnd && Current == '\\n')");
        builder.AppendLine("            {");
        builder.AppendLine("                AdvanceRaw();");
        builder.AppendLine("            }");
        builder.AppendLine("        }");
        builder.AppendLine("        else");
        builder.AppendLine("        {");
        builder.AppendLine("            AdvanceRaw();");
        builder.AppendLine("        }");
        builder.AppendLine();
        builder.AppendLine("        _line++;");
        builder.AppendLine("        _column = 1;");
        builder.AppendLine("        _tokens.Add(new Token(TokenKind.NewLine, \"\\n\", line, column));");
        builder.AppendLine("    }");
        builder.AppendLine();
        if (hasLineCommentSkip)
        {
            builder.AppendLine("    private void SkipLineComment()");
            builder.AppendLine("    {");
            builder.AppendLine("        while (!IsAtEnd && Current is not ('\\r' or '\\n'))");
            builder.AppendLine("        {");
            builder.AppendLine("            Advance();");
            builder.AppendLine("        }");
            builder.AppendLine("    }");
            builder.AppendLine();
        }

        builder.AppendLine("    private void LexIdentifier()");
        builder.AppendLine("    {");
        builder.AppendLine("        var line = _line;");
        builder.AppendLine("        var column = _column;");
        builder.AppendLine("        var start = _index;");
        builder.AppendLine();
        builder.AppendLine("        while (!IsAtEnd && IsIdentifierPart(Current))");
        builder.AppendLine("        {");
        builder.AppendLine("            Advance();");
        builder.AppendLine("        }");
        builder.AppendLine();
        builder.AppendLine("        _tokens.Add(new Token(TokenKind.Identifier, source[start.._index], line, column));");
        builder.AppendLine("    }");
        builder.AppendLine();
        if (hasNumber)
        {
            builder.AppendLine("    private void LexNumber()");
            builder.AppendLine("    {");
            builder.AppendLine("        var line = _line;");
            builder.AppendLine("        var column = _column;");
            builder.AppendLine("        var start = _index;");
            builder.AppendLine();
            builder.AppendLine("        while (!IsAtEnd && (char.IsDigit(Current) || (Current == '_' && _index + 1 < source.Length && char.IsDigit(source[_index + 1]))))");
            builder.AppendLine("        {");
            builder.AppendLine("            Advance();");
            builder.AppendLine("        }");
            builder.AppendLine();
            builder.AppendLine("        if (!IsAtEnd && Current == '.' && _index + 1 < source.Length && char.IsDigit(source[_index + 1]))");
            builder.AppendLine("        {");
            builder.AppendLine("            Advance();");
            builder.AppendLine("            while (!IsAtEnd && (char.IsDigit(Current) || (Current == '_' && _index + 1 < source.Length && char.IsDigit(source[_index + 1])))) Advance();");
            builder.AppendLine("        }");
            builder.AppendLine();
            builder.AppendLine("        if (!IsAtEnd && (Current == 'e' || Current == 'E'))");
            builder.AppendLine("        {");
            builder.AppendLine("            Advance();");
            builder.AppendLine("            if (!IsAtEnd && (Current == '+' || Current == '-')) Advance();");
            builder.AppendLine("            while (!IsAtEnd && (char.IsDigit(Current) || (Current == '_' && _index + 1 < source.Length && char.IsDigit(source[_index + 1])))) Advance();");
            builder.AppendLine("        }");
            builder.AppendLine();
            builder.AppendLine("        _tokens.Add(new Token(TokenKind.Number, source[start.._index].Replace(\"_\", \"\"), line, column));");
            builder.AppendLine("    }");
            builder.AppendLine();
        }

        builder.AppendLine("    private void LexString()");
        builder.AppendLine("    {");
        builder.AppendLine("        if (_index + 2 < source.Length && source[_index + 1] == '\"' && source[_index + 2] == '\"')");
        builder.AppendLine("        {");
        builder.AppendLine("            LexRawString();");
        builder.AppendLine("            return;");
        builder.AppendLine("        }");
        builder.AppendLine();
        builder.AppendLine("        var line = _line;");
        builder.AppendLine("        var column = _column;");
        builder.AppendLine("        Advance();");
        builder.AppendLine("        var start = _index;");
        builder.AppendLine();
        builder.AppendLine("        while (!IsAtEnd && Current != '\"')");
        builder.AppendLine("        {");
        builder.AppendLine("            if (Current is '\\r' or '\\n')");
        builder.AppendLine("            {");
        builder.AppendLine("                throw ErrorAt(line, column, \"unterminated string literal\");");
        builder.AppendLine("            }");
        builder.AppendLine();
        builder.AppendLine("            Advance();");
        builder.AppendLine("        }");
        builder.AppendLine();
        builder.AppendLine("        if (IsAtEnd)");
        builder.AppendLine("        {");
        builder.AppendLine("            throw ErrorAt(line, column, \"unterminated string literal\");");
        builder.AppendLine("        }");
        builder.AppendLine();
        builder.AppendLine("        var text = source[start.._index];");
        builder.AppendLine("        Advance();");
        builder.AppendLine("        _tokens.Add(new Token(TokenKind.String, text, line, column));");
        builder.AppendLine("    }");
        builder.AppendLine();
        builder.AppendLine("    private void LexRawString()");
        builder.AppendLine("    {");
        builder.AppendLine("        var line = _line;");
        builder.AppendLine("        var column = _column;");
        builder.AppendLine("        Advance();");
        builder.AppendLine("        Advance();");
        builder.AppendLine("        Advance();");
        builder.AppendLine("        var start = _index;");
        builder.AppendLine();
        builder.AppendLine("        while (!IsAtEnd && !(_index + 2 < source.Length && Current == '\"' && source[_index + 1] == '\"' && source[_index + 2] == '\"'))");
        builder.AppendLine("        {");
        builder.AppendLine("            if (Current == '\\r')");
        builder.AppendLine("            {");
        builder.AppendLine("                AdvanceRaw();");
        builder.AppendLine("                if (!IsAtEnd && Current == '\\n') AdvanceRaw();");
        builder.AppendLine("                _line++;");
        builder.AppendLine("                _column = 1;");
        builder.AppendLine("            }");
        builder.AppendLine("            else if (Current == '\\n')");
        builder.AppendLine("            {");
        builder.AppendLine("                AdvanceRaw();");
        builder.AppendLine("                _line++;");
        builder.AppendLine("                _column = 1;");
        builder.AppendLine("            }");
        builder.AppendLine("            else");
        builder.AppendLine("            {");
        builder.AppendLine("                Advance();");
        builder.AppendLine("            }");
        builder.AppendLine("        }");
        builder.AppendLine();
        builder.AppendLine("        if (IsAtEnd)");
        builder.AppendLine("        {");
        builder.AppendLine("            throw ErrorAt(line, column, \"unterminated raw string literal\");");
        builder.AppendLine("        }");
        builder.AppendLine();
        builder.AppendLine("        var text = source[start.._index];");
        builder.AppendLine("        Advance();");
        builder.AppendLine("        Advance();");
        builder.AppendLine("        Advance();");
        builder.AppendLine("        _tokens.Add(new Token(TokenKind.String, text, line, column, true));");
        builder.AppendLine("    }");
        builder.AppendLine();
        builder.AppendLine("    private void Advance()");
        builder.AppendLine("    {");
        builder.AppendLine("        AdvanceRaw();");
        builder.AppendLine("        _column++;");
        builder.AppendLine("    }");
        builder.AppendLine();
        builder.AppendLine("    private void AdvanceRaw()");
        builder.AppendLine("    {");
        builder.AppendLine("        _index++;");
        builder.AppendLine("    }");
        builder.AppendLine();
        builder.AppendLine("    private static bool IsIdentifierStart(char c)");
        builder.AppendLine("    {");
        builder.AppendLine("        return c == '_' || char.IsLetter(c);");
        builder.AppendLine("    }");
        builder.AppendLine();
        builder.AppendLine("    private static bool IsIdentifierPart(char c)");
        builder.AppendLine("    {");
        builder.AppendLine("        return c == '_' || char.IsLetterOrDigit(c);");
        builder.AppendLine("    }");
        builder.AppendLine();
        builder.AppendLine("    private SmallLangException Error(string message)");
        builder.AppendLine("    {");
        builder.AppendLine("        return ErrorAt(_line, _column, message);");
        builder.AppendLine("    }");
        builder.AppendLine();
        builder.AppendLine("    private static SmallLangException ErrorAt(int line, int column, string message)");
        builder.AppendLine("    {");
        builder.AppendLine("        return new SmallLangException($\"lex error at {line}:{column}: {message}\");");
        builder.AppendLine("    }");
        builder.AppendLine("}");
        return builder.ToString();
    }

    private static void EmitTokenKind(StringBuilder builder, ImmutableArray<TokenRule> tokenRules)
    {
        builder.AppendLine("internal enum TokenKind");
        builder.AppendLine("{");
        foreach (var token in tokenRules)
        {
            builder.Append("    ").Append(token.Name).AppendLine(",");
        }

        builder.AppendLine("}");
    }

    private static void EmitLiteralTokenCase(StringBuilder builder, LiteralTokenRule[] orderedRules)
    {
        if (orderedRules.Length == 1 && orderedRules[0].Literal.Length == 1)
        {
            builder.Append("                    AddSingle(TokenKind.").Append(orderedRules[0].Name).AppendLine(");");
            return;
        }

        for (var i = 0; i < orderedRules.Length; i++)
        {
            var rule = orderedRules[i];
            if (i == orderedRules.Length - 1)
            {
                builder.Append("                    AddLiteral(\"")
                    .Append(EscapeString(rule.Literal))
                    .Append("\", TokenKind.")
                    .Append(rule.Name)
                    .AppendLine(");");
                return;
            }

            builder.Append("                    if (MatchesLiteral(\"")
                .Append(EscapeString(rule.Literal))
                .AppendLine("\"))");
            builder.AppendLine("                    {");
            builder.Append("                        AddLiteral(\"")
                .Append(EscapeString(rule.Literal))
                .Append("\", TokenKind.")
                .Append(rule.Name)
                .AppendLine(");");
            builder.AppendLine("                        break;");
            builder.AppendLine("                    }");
            builder.AppendLine();
        }
    }

    private static string Unquote(string value)
    {
        return value.Length >= 2 && value[0] == '"' && value[value.Length - 1] == '"'
            ? value.Substring(1, value.Length - 2)
            : value;
    }

    private static string EscapeChar(char c)
    {
        return c switch
        {
            '\\' => "\\\\",
            '\'' => "\\'",
            '\n' => "\\n",
            '\r' => "\\r",
            '\t' => "\\t",
            _ => c.ToString()
        };
    }

    private static string EscapeString(string value)
    {
        var builder = new StringBuilder(value.Length);
        foreach (var c in value)
        {
            builder.Append(c switch
            {
                '\\' => "\\\\",
                '"' => "\\\"",
                '\n' => "\\n",
                '\r' => "\\r",
                '\t' => "\\t",
                _ => c.ToString()
            });
        }

        return builder.ToString();
    }
}

internal sealed record LiteralTokenRule(string Name, string Literal);
