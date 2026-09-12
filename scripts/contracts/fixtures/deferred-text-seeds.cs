using System.Collections;
using System.Reflection;
using System.Text.Json;

// Reference lexical metadata only: the SLG production guard is executed separately.
var assembly = Assembly.LoadFrom(args[0]);
var tokenType = assembly.GetType("Sollang.Compiler.Lexing.Token", true)!;
var kindType = assembly.GetType("Sollang.Compiler.Lexing.TokenKind", true)!;
var parser = assembly.GetType("Sollang.Compiler.Parsing.StringLiteralParser", true)!;
var parse = parser.GetMethod("ParseStringSegments", BindingFlags.Public | BindingFlags.Static)!;
var kind = Enum.Parse(kindType, "String");
using var document = JsonDocument.Parse(File.ReadAllText(args[1]));
var result = new Dictionary<string, bool>();
foreach (var literal in document.RootElement.EnumerateArray())
{
    var lexeme = literal.GetProperty("lexeme").GetString()!;
    var raw = lexeme.StartsWith("\"\"\"", StringComparison.Ordinal);
    var contents = raw ? lexeme[3..^3] : lexeme[1..^1];
    var token = Activator.CreateInstance(tokenType, BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance,
        null, [kind, contents, 1, 1, raw], null)!;
    var segments = (IEnumerable)parse.Invoke(null, [token])!;
    result.Add(literal.GetProperty("id").GetString()!,
        segments.Cast<object>().Any(segment => segment.GetType().Name == "InterpolationSegment"));
}
Console.WriteLine(JsonSerializer.Serialize(result));
