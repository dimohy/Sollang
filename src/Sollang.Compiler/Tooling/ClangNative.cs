using System.Reflection;
using System.Runtime.InteropServices;
using Sollang.Compiler.Diagnostics;

namespace Sollang.Compiler.Tooling;

internal static class ClangNative
{
    private const string LibraryName = "sollang-libclang";
    private static nint libraryHandle;
    private static bool resolverInstalled;

    public static void Configure(string llvmHome)
    {
        if (libraryHandle != 0)
        {
            return;
        }

        var candidates = OperatingSystem.IsWindows()
            ? new[] { Path.Combine(llvmHome, "bin", "libclang.dll") }
            : LinuxCandidates(llvmHome).ToArray();
        var path = candidates.FirstOrDefault(File.Exists)
            ?? throw new SollangException(
                "libclang was not found in the LLVM toolchain; checked: "
                + string.Join(", ", candidates));
        libraryHandle = NativeLibrary.Load(path);
        if (!resolverInstalled)
        {
            NativeLibrary.SetDllImportResolver(
                typeof(ClangNative).Assembly,
                ResolveLibrary);
            resolverInstalled = true;
        }
    }

    private static IEnumerable<string> LinuxCandidates(string llvmHome)
    {
        yield return Path.Combine(llvmHome, "lib", "libclang.so");
        yield return Path.Combine(llvmHome, "lib64", "libclang.so");
        if (Directory.Exists("/usr/lib"))
        {
            foreach (var directory in Directory.EnumerateDirectories("/usr/lib", "llvm-*")
                         .OrderByDescending(path => path, StringComparer.Ordinal))
            {
                yield return Path.Combine(directory, "lib", "libclang.so");
            }
        }
    }

    private static nint ResolveLibrary(
        string libraryName,
        Assembly assembly,
        DllImportSearchPath? searchPath) =>
        libraryName == LibraryName ? libraryHandle : 0;

    [StructLayout(LayoutKind.Sequential)]
    internal readonly struct Cursor(int kind, int xdata, nint data0, nint data1, nint data2)
    {
        public readonly int Kind = kind;
        public readonly int XData = xdata;
        public readonly nint Data0 = data0;
        public readonly nint Data1 = data1;
        public readonly nint Data2 = data2;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal readonly struct Type(int kind, nint data0, nint data1)
    {
        public readonly int Kind = kind;
        public readonly nint Data0 = data0;
        public readonly nint Data1 = data1;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal readonly struct String(nint data, uint privateFlags)
    {
        public readonly nint Data = data;
        public readonly uint PrivateFlags = privateFlags;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal readonly struct SourceLocation(nint ptrData0, nint ptrData1, uint intData)
    {
        public readonly nint PtrData0 = ptrData0;
        public readonly nint PtrData1 = ptrData1;
        public readonly uint IntData = intData;
    }

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    internal delegate int CursorVisitor(Cursor cursor, Cursor parent, nint clientData);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern nint clang_createIndex(int excludeDeclarationsFromPch, int displayDiagnostics);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void clang_disposeIndex(nint index);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern int clang_parseTranslationUnit2(
        nint index,
        [MarshalAs(UnmanagedType.LPUTF8Str)] string sourceFilename,
        nint commandLineArguments,
        int numberOfCommandLineArguments,
        nint unsavedFiles,
        uint numberOfUnsavedFiles,
        uint options,
        out nint translationUnit);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void clang_disposeTranslationUnit(nint translationUnit);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern Cursor clang_getTranslationUnitCursor(nint translationUnit);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern uint clang_visitChildren(
        Cursor parent,
        CursorVisitor visitor,
        nint clientData);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern String clang_getCursorSpelling(Cursor cursor);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern String clang_getCursorUSR(Cursor cursor);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern SourceLocation clang_getCursorLocation(Cursor cursor);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern int clang_Location_isFromMainFile(SourceLocation location);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern int clang_Cursor_getNumArguments(Cursor cursor);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern Cursor clang_Cursor_getArgument(Cursor cursor, uint index);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern Type clang_getCursorType(Cursor cursor);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern Type clang_getCursorResultType(Cursor cursor);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern Type clang_getCanonicalType(Type type);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern String clang_getTypeSpelling(Type type);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern uint clang_Cursor_isVariadic(Cursor cursor);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern int clang_getCursorExceptionSpecificationType(Cursor cursor);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern int clang_getCXXAccessSpecifier(Cursor cursor);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern uint clang_CXXMethod_isStatic(Cursor cursor);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern uint clang_CXXMethod_isConst(Cursor cursor);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern uint clang_getNumDiagnostics(nint translationUnit);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern nint clang_getDiagnostic(nint translationUnit, uint index);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern uint clang_getDiagnosticSeverity(nint diagnostic);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern String clang_formatDiagnostic(nint diagnostic, uint options);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern uint clang_defaultDiagnosticDisplayOptions();

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    internal static extern void clang_disposeDiagnostic(nint diagnostic);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    private static extern nint clang_getCString(String value);

    [DllImport(LibraryName, CallingConvention = CallingConvention.Cdecl)]
    private static extern void clang_disposeString(String value);

    internal static string ToManagedString(String value)
    {
        try
        {
            return Marshal.PtrToStringUTF8(clang_getCString(value)) ?? string.Empty;
        }
        finally
        {
            clang_disposeString(value);
        }
    }
}
