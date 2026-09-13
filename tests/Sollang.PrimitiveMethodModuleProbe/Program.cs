using System.Collections;
using System.Reflection;

if (args.Length != 3)
{
    Console.Error.WriteLine("expected two primitive-method and one array-method module fixture paths");
    return 2;
}

var compiler = Assembly.Load("Sollang.Compiler");
var lexerType = compiler.GetType("Sollang.Compiler.Lexing.Lexer", throwOnError: true)!;
var parserType = compiler.GetType("Sollang.Compiler.Parsing.Parser", throwOnError: true)!;
var expected = new[]
{
    "std.alpha.UInt64.encode",
    "std.beta.UInt64.encode",
    "std.gamma.[UInt8].firstPlus"
};

for (var index = 0; index < args.Length; index++)
{
    var source = File.ReadAllText(args[index]);
    var lexer = Activator.CreateInstance(
        lexerType,
        BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic,
        binder: null,
        args: new object[] { source },
        culture: null)!;
    var tokens = lexerType.GetMethod("Lex", BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic)!
        .Invoke(lexer, null)!;
    var parser = Activator.CreateInstance(
        parserType,
        BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic,
        binder: null,
        args: new[] { tokens, true, null },
        culture: null)!;
    var program = parserType.GetMethod("Parse", BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic)!
        .Invoke(parser, null)!;
    var functions = (IEnumerable)program.GetType().GetProperty("Functions")!.GetValue(program)!;
    var names = functions.Cast<object>()
        .Select(function => (string)function.GetType().GetProperty("Name")!.GetValue(function)!)
        .ToArray();
    if (!names.Contains(expected[index], StringComparer.Ordinal))
    {
        Console.Error.WriteLine($"expected method identity '{expected[index]}', found [{string.Join(", ", names)}]");
        return 1;
    }
}

Console.WriteLine("[builtin method parser identity] PASS 3/3");
return 0;
