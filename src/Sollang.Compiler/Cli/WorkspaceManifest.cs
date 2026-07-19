using Sollang.Compiler.Diagnostics;
using Sollang.Compiler.Lexing;

namespace Sollang.Compiler.Cli;

internal sealed record WorkspaceManifest(
    string Path,
    IReadOnlyList<ProjectManifest> Members)
{
    public const string FileName = "sollang.workspace";

    public string Directory => System.IO.Path.GetDirectoryName(Path)
        ?? System.IO.Directory.GetCurrentDirectory();

    public ProjectManifest SelectMember(string? requestedName)
    {
        if (requestedName is not null)
        {
            var selected = Members.SingleOrDefault(
                member => string.Equals(member.Name, requestedName, StringComparison.Ordinal));
            if (selected is null)
            {
                throw new SollangException(
                    $"workspace has no package '{requestedName}'; available packages: "
                    + string.Join(", ", Members.Select(static member => member.Name)));
            }
            return selected;
        }

        if (Members.Count != 1)
        {
            throw new SollangException(
                "workspace has multiple packages; select one with --package: "
                + string.Join(", ", Members.Select(static member => member.Name)));
        }
        return Members[0];
    }

    public static WorkspaceManifest Load(string pathOrDirectory)
    {
        var manifestPath = System.IO.Directory.Exists(pathOrDirectory)
            ? System.IO.Path.Combine(pathOrDirectory, FileName)
            : pathOrDirectory;
        manifestPath = System.IO.Path.GetFullPath(manifestPath);
        if (!File.Exists(manifestPath))
        {
            throw new SollangException($"workspace manifest not found: {manifestPath}");
        }

        var source = File.ReadAllText(manifestPath);
        var parser = new ManifestParser(new Lexer(source).Lex(), manifestPath);
        var memberPaths = parser.Parse();
        if (memberPaths.Count == 0)
        {
            throw new SollangException($"workspace 'members' must not be empty: {manifestPath}");
        }

        var workspaceDirectory = System.IO.Path.GetDirectoryName(manifestPath)
            ?? System.IO.Directory.GetCurrentDirectory();
        var paths = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var names = new Dictionary<string, string>(StringComparer.Ordinal);
        var members = new List<ProjectManifest>(memberPaths.Count);
        foreach (var memberPath in memberPaths)
        {
            var resolvedPath = ResolveMemberPath(memberPath, workspaceDirectory, manifestPath);
            var member = ProjectManifest.Load(resolvedPath);
            if (!paths.Add(member.Path))
            {
                throw new SollangException(
                    $"workspace declares project '{member.Path}' more than once: {manifestPath}");
            }
            if (names.TryGetValue(member.Name, out var existingPath))
            {
                throw new SollangException(
                    $"workspace package name '{member.Name}' is declared by both "
                    + $"'{existingPath}' and '{member.Path}'");
            }
            names.Add(member.Name, member.Path);
            members.Add(member);
        }

        return new WorkspaceManifest(
            manifestPath,
            members.OrderBy(static member => member.Name, StringComparer.Ordinal).ToArray());
    }

    public static string? FindFrom(string startDirectory)
    {
        for (var current = new DirectoryInfo(System.IO.Path.GetFullPath(startDirectory));
             current is not null;
             current = current.Parent)
        {
            var candidate = System.IO.Path.Combine(current.FullName, FileName);
            if (File.Exists(candidate))
            {
                return candidate;
            }
        }
        return null;
    }

    private static string ResolveMemberPath(
        string path,
        string workspaceDirectory,
        string manifestPath)
    {
        if (System.IO.Path.IsPathRooted(path))
        {
            throw new SollangException(
                $"workspace member path must be relative in {manifestPath}: {path}");
        }

        var memberPath = System.IO.Path.GetFullPath(path, workspaceDirectory);
        var relativePath = System.IO.Path.GetRelativePath(workspaceDirectory, memberPath);
        if (relativePath == ".."
            || relativePath.StartsWith(".." + System.IO.Path.DirectorySeparatorChar, StringComparison.Ordinal)
            || relativePath.StartsWith(".." + System.IO.Path.AltDirectorySeparatorChar, StringComparison.Ordinal))
        {
            throw new SollangException($"workspace member escapes the workspace directory: {path}");
        }

        return System.IO.Directory.Exists(memberPath)
            ? System.IO.Path.Combine(memberPath, ProjectManifest.FileName)
            : memberPath;
    }

    private sealed class ManifestParser(IReadOnlyList<Token> tokens, string path)
    {
        private int _index;

        public IReadOnlyList<string> Parse()
        {
            SkipNewLines();
            var workspace = Expect(TokenKind.Identifier, "'workspace'");
            if (!string.Equals(workspace.Text, "workspace", StringComparison.Ordinal))
            {
                throw Error(workspace, "workspace manifest must start with 'workspace'");
            }
            Expect(TokenKind.LeftBrace, "'{'");

            List<string>? members = null;
            SkipSeparators();
            while (!Check(TokenKind.RightBrace))
            {
                var field = Expect(TokenKind.Identifier, "field name");
                Expect(TokenKind.Colon, "':'");
                switch (field.Text)
                {
                    case "members" when members is null:
                        members = ParseStringArray("members");
                        break;
                    case "members":
                        throw Error(field, "duplicate workspace field 'members'");
                    default:
                        throw Error(field, $"unknown workspace field '{field.Text}'");
                }
                RequireSeparator("workspace fields");
                SkipSeparators();
            }

            Expect(TokenKind.RightBrace, "'}'");
            SkipNewLines();
            Expect(TokenKind.End, "end of file");
            return members
                ?? throw new SollangException(
                    $"workspace manifest is missing required field 'members': {path}");
        }

        private List<string> ParseStringArray(string fieldName)
        {
            Expect(TokenKind.LeftBracket, "'['");
            var values = new List<string>();
            var unique = new HashSet<string>(StringComparer.Ordinal);
            SkipSeparators();
            while (!Check(TokenKind.RightBracket))
            {
                var value = Expect(TokenKind.String, "string literal");
                if (!unique.Add(value.Text))
                {
                    throw Error(value, $"duplicate {fieldName} entry '{value.Text}'");
                }
                values.Add(value.Text);
                RequireSeparator($"{fieldName} entries", TokenKind.RightBracket);
                SkipSeparators();
            }
            Expect(TokenKind.RightBracket, "']'");
            return values;
        }

        private void RequireSeparator(string description, TokenKind closing = TokenKind.RightBrace)
        {
            if (!Check(closing) && !Check(TokenKind.NewLine) && !Check(TokenKind.Comma))
            {
                throw Error(Peek(), $"{description} must be separated by a newline or comma");
            }
        }

        private void SkipSeparators()
        {
            while (Check(TokenKind.NewLine) || Check(TokenKind.Comma))
            {
                _index++;
            }
        }

        private void SkipNewLines()
        {
            while (Check(TokenKind.NewLine))
            {
                _index++;
            }
        }

        private Token Expect(TokenKind kind, string expected)
        {
            var token = Peek();
            if (token.Kind != kind)
            {
                throw Error(token, $"expected {expected}");
            }
            _index++;
            return token;
        }

        private bool Check(TokenKind kind) => Peek().Kind == kind;

        private Token Peek() => tokens[Math.Min(_index, tokens.Count - 1)];

        private SollangException Error(Token token, string message) =>
            new($"{path}({token.Line},{token.Column}): {message}");
    }
}
