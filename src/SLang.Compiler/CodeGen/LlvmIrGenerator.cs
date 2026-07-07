using System.Globalization;
using System.Text;
using SLang.Compiler.Diagnostics;

namespace SLang.Compiler.CodeGen;

internal static class LlvmIrGenerator
{
    public static string GenerateWindowsConsoleProgram(byte[] output)
    {
        if (output.Length > int.MaxValue)
        {
            throw new SlangException("output is too large for the initial Windows backend");
        }

        var builder = new StringBuilder();
        builder.AppendLine("target triple = \"x86_64-pc-windows-msvc\"");
        builder.AppendLine();

        if (output.Length > 0)
        {
            var length = output.Length.ToString(CultureInfo.InvariantCulture);
            builder.Append("@.slang.out = private unnamed_addr constant [")
                .Append(length)
                .Append(" x i8] c\"")
                .Append(EscapeLlvmBytes(output))
                .AppendLine("\", align 1");
            builder.AppendLine();
            builder.AppendLine("declare dllimport ptr @GetStdHandle(i32)");
            builder.AppendLine("declare dllimport i32 @WriteFile(ptr, ptr, i32, ptr, ptr)");
            builder.AppendLine();
            builder.AppendLine("define dso_local i32 @slang_start() local_unnamed_addr {");
            builder.AppendLine("entry:");
            builder.AppendLine("  %written = alloca i32, align 4");
            builder.AppendLine("  %stdout = call ptr @GetStdHandle(i32 -11)");
            builder.AppendLine("  %ok = call i32 @WriteFile(ptr %stdout, ptr @.slang.out, i32 " + length + ", ptr %written, ptr null)");
            builder.AppendLine("  %is_ok = icmp ne i32 %ok, 0");
            builder.AppendLine("  %exit = select i1 %is_ok, i32 0, i32 1");
            builder.AppendLine("  ret i32 %exit");
            builder.AppendLine("}");
        }
        else
        {
            builder.AppendLine("define dso_local i32 @slang_start() local_unnamed_addr {");
            builder.AppendLine("entry:");
            builder.AppendLine("  ret i32 0");
            builder.AppendLine("}");
        }

        return builder.ToString();
    }

    private static string EscapeLlvmBytes(byte[] bytes)
    {
        var builder = new StringBuilder(bytes.Length);
        foreach (var b in bytes)
        {
            if (b is >= 0x20 and <= 0x7E && b != (byte)'\\' && b != (byte)'"')
            {
                builder.Append((char)b);
            }
            else
            {
                builder.Append('\\');
                builder.Append(b.ToString("X2", CultureInfo.InvariantCulture));
            }
        }

        return builder.ToString();
    }
}
