using SmallLang.Compiler.Diagnostics;
using SmallLang.Compiler.Lexing;

namespace SmallLang.Compiler.Cli;

internal sealed record ProjectManifest(
    string Path,
    string Name,
    IReadOnlyDictionary<string, string> Products,
    IReadOnlyDictionary<string, string> Dependencies)
{
    public const string FileName = "smalllang.project";

    public string Directory => System.IO.Path.GetDirectoryName(Path)
        ?? System.IO.Directory.GetCurrentDirectory();

    public ProjectProduct SelectProduct(string? requestedName)
    {
        if (requestedName is not null)
        {
            if (!Products.TryGetValue(requestedName, out var selectedRoot))
            {
                throw new SmallLangException(
                    $"project '{Name}' has no product '{requestedName}'; available products: "
                    + string.Join(", ", Products.Keys.Order(StringComparer.Ordinal)));
            }
            return new ProjectProduct(requestedName, selectedRoot);
        }

        if (Products.Count != 1)
        {
            throw new SmallLangException(
                $"project '{Name}' has multiple products; select one with --product: "
                + string.Join(", ", Products.Keys.Order(StringComparer.Ordinal)));
        }

        var only = Products.Single();
        return new ProjectProduct(only.Key, only.Value);
    }

    public static ProjectManifest Load(string pathOrDirectory)
    {
        var manifestPath = System.IO.Directory.Exists(pathOrDirectory)
            ? System.IO.Path.Combine(pathOrDirectory, FileName)
            : pathOrDirectory;
        manifestPath = System.IO.Path.GetFullPath(manifestPath);
        if (!File.Exists(manifestPath))
        {
            throw new SmallLangException($"project manifest not found: {manifestPath}");
        }

        var source = File.ReadAllText(manifestPath);
        var parser = new ManifestParser(new Lexer(source).Lex(), manifestPath);
        var parsed = parser.Parse();
        ValidateProjectName(parsed.Name, manifestPath);

        if (parsed.Root is not null && parsed.Products is not null)
        {
            throw new SmallLangException(
                $"project manifest cannot declare both 'root' and 'products': {manifestPath}");
        }
        if (parsed.Root is null && parsed.Products is null)
        {
            throw new SmallLangException(
                $"project manifest requires either 'root' or 'products': {manifestPath}");
        }

        var projectDirectory = System.IO.Path.GetDirectoryName(manifestPath)
            ?? System.IO.Directory.GetCurrentDirectory();
        IReadOnlyDictionary<string, string> products;
        if (parsed.Root is not null)
        {
            products = new Dictionary<string, string>(StringComparer.Ordinal)
            {
                [parsed.Name] = ResolveRoot(parsed.Root, projectDirectory, manifestPath)
            };
        }
        else
        {
            if (parsed.Products!.Count == 0)
            {
                throw new SmallLangException($"project 'products' must not be empty: {manifestPath}");
            }
            products = parsed.Products.ToDictionary(
                pair => ValidateEntryName(pair.Key, "product", manifestPath),
                pair => ResolveRoot(pair.Value, projectDirectory, manifestPath),
                StringComparer.Ordinal);
        }

        var dependencies = (parsed.Dependencies ?? new Dictionary<string, string>(StringComparer.Ordinal))
            .ToDictionary(
                pair => ValidateEntryName(pair.Key, "dependency", manifestPath),
                pair => ResolveDependencyPath(pair.Value, projectDirectory, manifestPath),
                StringComparer.Ordinal);
        return new ProjectManifest(manifestPath, parsed.Name, products, dependencies);
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

    private static string ResolveRoot(string root, string projectDirectory, string manifestPath)
    {
        if (System.IO.Path.IsPathRooted(root))
        {
            throw new SmallLangException($"project root must be relative to the manifest: {root}");
        }

        var rootSource = System.IO.Path.GetFullPath(root, projectDirectory);
        var relativeRoot = System.IO.Path.GetRelativePath(projectDirectory, rootSource);
        if (relativeRoot == ".."
            || relativeRoot.StartsWith(".." + System.IO.Path.DirectorySeparatorChar, StringComparison.Ordinal)
            || relativeRoot.StartsWith(".." + System.IO.Path.AltDirectorySeparatorChar, StringComparison.Ordinal))
        {
            throw new SmallLangException($"project root escapes the manifest directory: {root}");
        }
        if (!string.Equals(System.IO.Path.GetExtension(rootSource), ".sl", StringComparison.OrdinalIgnoreCase))
        {
            throw new SmallLangException($"project root must be an .sl source file: {root}");
        }
        if (!File.Exists(rootSource))
        {
            throw new SmallLangException($"project root source not found: {rootSource}");
        }
        return rootSource;
    }

    private static string ResolveDependencyPath(string path, string projectDirectory, string manifestPath)
    {
        if (System.IO.Path.IsPathRooted(path))
        {
            throw new SmallLangException(
                $"dependency path must be relative to the manifest in {manifestPath}: {path}");
        }
        return System.IO.Path.GetFullPath(path, projectDirectory);
    }

    private static void ValidateProjectName(string name, string manifestPath)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new SmallLangException($"project name must not be empty in {manifestPath}");
        }
        if (name.Any(static character => character < ' ' || "<>:\"/\\|?*".Contains(character)))
        {
            throw new SmallLangException($"project name is not a portable file name: {name}");
        }
    }

    private static string ValidateEntryName(string name, string kind, string manifestPath)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new SmallLangException($"{kind} name must not be empty in {manifestPath}");
        }
        if (!IsIdentifierStart(name[0]) || name.Skip(1).Any(static character => !IsIdentifierPart(character)))
        {
            throw new SmallLangException(
                $"{kind} name must be an import-safe identifier in {manifestPath}: {name}");
        }
        return name;
    }

    private static bool IsIdentifierStart(char character) => character == '_' || char.IsLetter(character);

    private static bool IsIdentifierPart(char character) => character == '_' || char.IsLetterOrDigit(character);

    private sealed class ManifestParser(IReadOnlyList<Token> tokens, string path)
    {
        private int _index;

        public ParsedManifest Parse()
        {
            SkipNewLines();
            var project = Expect(TokenKind.Identifier, "'project'");
            if (!string.Equals(project.Text, "project", StringComparison.Ordinal))
            {
                throw Error(project, "project manifest must start with 'project'");
            }
            Expect(TokenKind.LeftBrace, "'{'");

            string? name = null;
            string? root = null;
            Dictionary<string, string>? products = null;
            Dictionary<string, string>? dependencies = null;
            SkipSeparators();
            while (!Check(TokenKind.RightBrace))
            {
                var field = Expect(TokenKind.Identifier, "field name");
                Expect(TokenKind.Colon, "':'");
                switch (field.Text)
                {
                    case "name" when name is null:
                        name = Expect(TokenKind.String, "string literal").Text;
                        break;
                    case "root" when root is null:
                        root = Expect(TokenKind.String, "string literal").Text;
                        break;
                    case "products" when products is null:
                        products = ParseStringMap("products");
                        break;
                    case "dependencies" when dependencies is null:
                        dependencies = ParseStringMap("dependencies");
                        break;
                    case "name" or "root" or "products" or "dependencies":
                        throw Error(field, $"duplicate project field '{field.Text}'");
                    default:
                        throw Error(field, $"unknown project field '{field.Text}'");
                }

                RequireSeparator("project fields");
                SkipSeparators();
            }

            Expect(TokenKind.RightBrace, "'}'");
            SkipNewLines();
            Expect(TokenKind.End, "end of file");
            if (name is null)
            {
                throw new SmallLangException($"project manifest is missing required field 'name': {path}");
            }
            return new ParsedManifest(name, root, products, dependencies);
        }

        private Dictionary<string, string> ParseStringMap(string fieldName)
        {
            Expect(TokenKind.LeftBrace, "'{'");
            var values = new Dictionary<string, string>(StringComparer.Ordinal);
            SkipSeparators();
            while (!Check(TokenKind.RightBrace))
            {
                var key = Expect(TokenKind.Identifier, $"{fieldName} entry name");
                Expect(TokenKind.Colon, "':'");
                var value = Expect(TokenKind.String, "string literal");
                if (!values.TryAdd(key.Text, value.Text))
                {
                    throw Error(key, $"duplicate {fieldName} entry '{key.Text}'");
                }
                RequireSeparator($"{fieldName} entries");
                SkipSeparators();
            }
            Expect(TokenKind.RightBrace, "'}'");
            return values;
        }

        private void RequireSeparator(string description)
        {
            if (!Check(TokenKind.RightBrace)
                && !Check(TokenKind.NewLine)
                && !Check(TokenKind.Comma))
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

        private SmallLangException Error(Token token, string message) =>
            new($"{path}({token.Line},{token.Column}): {message}");
    }

    private sealed record ParsedManifest(
        string Name,
        string? Root,
        Dictionary<string, string>? Products,
        Dictionary<string, string>? Dependencies);
}

internal sealed record ProjectProduct(string Name, string RootSource);
