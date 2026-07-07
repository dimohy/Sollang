using System.Globalization;
using System.Text;
using SLang.Compiler.CodeGen;
using SLang.Compiler.Diagnostics;
using SLang.Compiler.Lexing;
using SLang.Compiler.Parsing;
using SLang.Compiler.Semantics;
using SLang.Compiler.Tooling;

namespace SLang.Compiler.Cli;

internal static class CompilerApp
{
    public static int Run(string[] args)
    {
        try
        {
            var options = CliOptions.Parse(args);
            Build(options);
            return 0;
        }
        catch (SlangException ex)
        {
            Console.Error.WriteLine($"slang: {ex.Message}");
            return 1;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"slang: unexpected failure: {ex.Message}");
            return 1;
        }
    }

    private static void Build(CliOptions options)
    {
        var sourceText = File.ReadAllText(options.SourcePath, Encoding.UTF8);
        var tokens = new Lexer(sourceText).Lex();
        var program = new Parser(tokens).Parse();
        var outputBytes = new SemanticCompiler(program).CompileToStdoutBytes();
        var llvmIr = LlvmIrGenerator.GenerateWindowsConsoleProgram(outputBytes);
        var toolchain = LlvmToolchain.From(options.LlvmHome);
        var linker = new WindowsLinker(toolchain);

        Directory.CreateDirectory(Path.GetDirectoryName(options.OutputPath)
            ?? Directory.GetCurrentDirectory());

        var workDir = Path.Combine(
            Path.GetDirectoryName(Path.GetFullPath(options.OutputPath))
                ?? Directory.GetCurrentDirectory(),
            Path.GetFileNameWithoutExtension(options.OutputPath) + ".slang-tmp");

        if (Directory.Exists(workDir))
        {
            Directory.Delete(workDir, recursive: true);
        }

        Directory.CreateDirectory(workDir);

        try
        {
            var llPath = Path.Combine(workDir, Path.GetFileNameWithoutExtension(options.OutputPath) + ".ll");
            File.WriteAllText(llPath, llvmIr, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
            linker.LinkLlvmIr(llPath, options.OutputPath, workDir);

            if (options.KeepTemps)
            {
                var keptLlPath = Path.ChangeExtension(options.OutputPath, ".ll");
                File.Copy(llPath, keptLlPath, overwrite: true);
            }
        }
        finally
        {
            if (!options.KeepTemps && Directory.Exists(workDir))
            {
                Directory.Delete(workDir, recursive: true);
            }
        }

        var exeInfo = new FileInfo(options.OutputPath);
        Console.WriteLine($"Wrote {exeInfo.FullName} ({exeInfo.Length.ToString("N0", CultureInfo.InvariantCulture)} bytes)");
    }
}
