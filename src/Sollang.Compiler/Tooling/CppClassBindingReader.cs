using System.Security.Cryptography;
using System.Text;
using Sollang.Compiler.Cli;
using Sollang.Compiler.Diagnostics;

namespace Sollang.Compiler.Tooling;

internal static class CppClassBindingReader
{
    private const int CursorStruct = 2;
    private const int CursorClass = 4;
    private const int CursorMethod = 21;
    private const int CursorNamespace = 22;
    private const int CursorConstructor = 24;

    public static IReadOnlyList<CppClass> Read(
        nint translationUnit,
        CppBindingOptions options)
    {
        var classes = new List<CppClass>();
        var seen = new HashSet<string>(StringComparer.Ordinal);

        void Visit(ClangNative.Cursor parent, IReadOnlyList<string> namespaces)
        {
            ClangNative.CursorVisitor? visitor = null;
            visitor = (cursor, _, _) =>
            {
                if (ClangNative.clang_Location_isFromMainFile(
                        ClangNative.clang_getCursorLocation(cursor)) == 0)
                {
                    return 1;
                }
                if (cursor.Kind == CursorNamespace)
                {
                    var name = ClangNative.ToManagedString(
                        ClangNative.clang_getCursorSpelling(cursor));
                    Visit(cursor, [.. namespaces, name]);
                    return 1;
                }
                if (cursor.Kind is CursorClass or CursorStruct)
                {
                    var usr = ClangNative.ToManagedString(ClangNative.clang_getCursorUSR(cursor));
                    if (seen.Add(usr))
                    {
                        classes.Add(ReadClass(cursor, namespaces, options));
                    }
                }
                return 1;
            };
            ClangNative.clang_visitChildren(parent, visitor, 0);
            GC.KeepAlive(visitor);
        }

        Visit(ClangNative.clang_getTranslationUnitCursor(translationUnit), []);
        return classes.OrderBy(value => value.QualifiedName, StringComparer.Ordinal).ToArray();
    }

    private static CppClass ReadClass(
        ClangNative.Cursor cursor,
        IReadOnlyList<string> namespaces,
        CppBindingOptions options)
    {
        var name = ClangNative.ToManagedString(ClangNative.clang_getCursorSpelling(cursor));
        var qualifiedName = namespaces.Count == 0
            ? name
            : string.Join("::", namespaces) + "::" + name;
        var constructors = new List<CppConstructor>();
        var methods = new List<CppMethod>();
        ClangNative.CursorVisitor? visitor = null;
        visitor = (member, _, _) =>
        {
            if (ClangNative.clang_getCXXAccessSpecifier(member) != 1)
            {
                return 1;
            }
            if (member.Kind == CursorConstructor)
            {
                var parameters = ReadParameters(member, options, qualifiedName);
                constructors.Add(new CppConstructor(
                    parameters,
                    Symbol(qualifiedName, "create", Signature("owner", parameters))));
            }
            else if (member.Kind == CursorMethod
                     && ClangNative.clang_CXXMethod_isStatic(member) == 0)
            {
                var methodName = ClangNative.ToManagedString(
                    ClangNative.clang_getCursorSpelling(member));
                var methodQualifiedName = qualifiedName + "::" + methodName;
                var isNoexcept = IsNoexcept(member);
                var parameters = ReadParameters(member, options, methodQualifiedName);
                var result = MapType(
                    ClangNative.clang_getCursorResultType(member),
                    options,
                    methodQualifiedName,
                    "result");
                methods.Add(new CppMethod(
                    Identifier(methodName),
                    methodName,
                    Symbol(qualifiedName, methodName, Signature(result.SollangName, parameters)),
                    result,
                    parameters,
                    ClangNative.clang_CXXMethod_isConst(member) != 0,
                    isNoexcept));
            }
            return 1;
        };
        ClangNative.clang_visitChildren(cursor, visitor, 0);
        GC.KeepAlive(visitor);
        if (constructors.Count == 0)
        {
            throw Error(
                qualifiedName,
                "classes require at least one explicit public constructor");
        }
        return new CppClass(
            Identifier(name),
            qualifiedName,
            Symbol(qualifiedName, "drop", "owner"),
            constructors,
            methods);
    }

    private static IReadOnlyList<CppParameter> ReadParameters(
        ClangNative.Cursor cursor,
        CppBindingOptions options,
        string owner)
    {
        var result = new List<CppParameter>();
        var count = ClangNative.clang_Cursor_getNumArguments(cursor);
        for (var index = 0; index < count; index++)
        {
            var argument = ClangNative.clang_Cursor_getArgument(cursor, (uint)index);
            var name = ClangNative.ToManagedString(ClangNative.clang_getCursorSpelling(argument));
            result.Add(new CppParameter(
                Identifier(string.IsNullOrWhiteSpace(name) ? $"value{index + 1}" : name),
                MapType(ClangNative.clang_getCursorType(argument), options, owner, $"parameter {index + 1}")));
        }
        return result;
    }

    private static bool IsNoexcept(ClangNative.Cursor cursor) =>
        ClangNative.clang_getCursorExceptionSpecificationType(cursor) is 1 or 4 or 9;

    private static CppType MapType(
        ClangNative.Type type,
        CppBindingOptions options,
        string function,
        string position)
    {
        var canonical = ClangNative.clang_getCanonicalType(type);
        var spelling = ClangNative.ToManagedString(ClangNative.clang_getTypeSpelling(type));
        return canonical.Kind switch
        {
            2 => new("Unit", "void"),
            4 or 5 => new("UInt8", "unsigned char"),
            13 or 14 => new("Int8", "signed char"),
            8 => new("UInt16", "unsigned short"),
            9 => new("UInt32", "unsigned int"),
            10 => options.Target == CompilationTarget.WindowsX64
                ? new("UInt32", "unsigned long")
                : new("UInt64", "unsigned long"),
            11 => new("UInt64", "unsigned long long"),
            16 => new("Int16", "short"),
            17 => new("Int32", "int"),
            18 => options.Target == CompilationTarget.WindowsX64
                ? new("Int32", "long")
                : new("Int64", "long"),
            19 => new("Int64", "long long"),
            21 => new("Float32", "float"),
            22 => new("Float64", "double"),
            _ => throw Error(
                function,
                $"{position} type '{spelling}' is outside the scalar class-binding slice")
        };
    }

    private static string Signature(string result, IReadOnlyList<CppParameter> parameters) =>
        result + "(" + string.Join(",", parameters.Select(value => value.Type.SollangName)) + ")";

    private static string Symbol(string owner, string operation, string signature)
    {
        var hash = Convert.ToHexString(
            SHA256.HashData(Encoding.UTF8.GetBytes(owner + ":" + operation + ":" + signature)))
            .ToLowerInvariant()[..12];
        return "sollang_cpp_" + Identifier(owner.Replace("::", "_", StringComparison.Ordinal))
            + "_" + Identifier(operation) + "_" + hash;
    }

    private static string Identifier(string value)
    {
        var result = new string(value.Select(character =>
            char.IsLetterOrDigit(character) || character == '_' ? character : '_').ToArray());
        return result.Length > 0 && char.IsDigit(result[0]) ? "_" + result : result;
    }

    private static SollangException Error(string name, string reason) =>
        new($"cannot bind C++ class member '{name}': {reason}");
}

internal sealed record CppClass(
    string Name,
    string QualifiedName,
    string DropSymbol,
    IReadOnlyList<CppConstructor> Constructors,
    IReadOnlyList<CppMethod> Methods);

internal sealed record CppConstructor(
    IReadOnlyList<CppParameter> Parameters,
    string Symbol);

internal sealed record CppMethod(
    string Name,
    string CppName,
    string Symbol,
    CppType Result,
    IReadOnlyList<CppParameter> Parameters,
    bool IsConst,
    bool IsNoexcept);
