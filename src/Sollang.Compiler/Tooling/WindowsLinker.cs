using System.Diagnostics;
using System.Text;
using Sollang.Compiler.Diagnostics;

namespace Sollang.Compiler.Tooling;

internal sealed class WindowsLinker(LlvmToolchain toolchain)
{
    private const long TargetBytesPerPartition = 1024 * 1024;

    public void LinkLlvmIr(
        string llPath,
        string outputPath,
        string workDir,
        string? optimizationLevel,
        bool sharedLibrary = false)
    {
        var outputName = Path.GetFileNameWithoutExtension(outputPath);
        var objectPath = Path.Combine(workDir, outputName + ".obj");
        var importLib = CreateKernel32ImportLibrary(workDir);
        var shellImportLib = CreateShell32ImportLibrary(workDir);
        var oleImportLib = UsesComInterop(llPath) ? CreateOle32ImportLibrary(workDir) : null;
        var ucrtImportLib = CreateUcrtBaseImportLibrary(workDir);

        var objects = optimizationLevel == "-O0"
            ? CompileSingleModule(llPath, objectPath, "-O0")
            : CompilePartitioned(llPath, workDir, outputName, optimizationLevel ?? "-O3");

        var linkArguments = new List<string>
        {
            "/nologo",
            "/machine:x64",
            "/nodefaultlib",
            "/opt:ref",
            "/opt:icf",
            "/fixed",
            "/stack:8388608,65536",
            "/merge:.rdata=.text",
            "/merge:.pdata=.text",
            "/merge:.xdata=.text",
        };
        if (sharedLibrary)
        {
            linkArguments.Add("/dll");
            linkArguments.Add("/noentry");
        }
        else
        {
            linkArguments.Add("/subsystem:console");
            linkArguments.Add("/entry:sollang_start");
        }
        linkArguments.AddRange(objects);
        linkArguments.AddRange([importLib, shellImportLib]);
        if (oleImportLib is not null)
        {
            linkArguments.Add(oleImportLib);
        }
        linkArguments.AddRange([ucrtImportLib, "/out:" + outputPath]);
        Run(toolchain.LldLink, linkArguments);
    }

    private IReadOnlyList<string> CompileSingleModule(string llPath, string objectPath, string optimizationLevel)
    {
        Run(toolchain.Clang,
        [
            "-target", "x86_64-pc-windows-msvc", optimizationLevel,
            "-fno-addrsig", "-mno-stack-arg-probe", "-Werror", "-Wno-override-module",
            "-c", llPath, "-o", objectPath
        ]);
        return [objectPath];
    }

    private IReadOnlyList<string> CompilePartitioned(
        string llPath,
        string workDir,
        string outputName,
        string optimizationLevel)
    {
        var processorCount = Math.Max(1, Environment.ProcessorCount);
        var maxPartitionCount = NativeJobLimit(processorCount);
        var llvmByteLength = new FileInfo(llPath).Length;
        // llvm-split and each clang process have a fixed cost. Keep small modules
        // whole and add parallelism only as the amount of IR grows.
        var sizeBasedPartitionCount = Math.Max(
            1,
            (int)Math.Min(
                processorCount,
                ((llvmByteLength - 1) / TargetBytesPerPartition) + 1));
        var partitionCount = Math.Min(maxPartitionCount, sizeBasedPartitionCount);
        if (partitionCount == 1)
        {
            return CompileSingleModule(
                llPath,
                Path.Combine(workDir, outputName + ".obj"),
                optimizationLevel);
        }

        var bitcodePath = Path.Combine(workDir, outputName + ".partition-input.bc");
        var partitionPrefix = Path.Combine(workDir, outputName + ".partition.bc");

        Run(toolchain.Clang,
        [
            "-target", "x86_64-pc-windows-msvc", "-O0", "-flto=full", "-emit-llvm",
            "-Werror", "-Wno-override-module", "-c", llPath, "-o", bitcodePath
        ]);
        Run(toolchain.LlvmSplit,
        [
            "-j", partitionCount.ToString(System.Globalization.CultureInfo.InvariantCulture),
            "--round-robin", "-o", partitionPrefix, bitcodePath
        ]);

        var objectPaths = Enumerable.Range(0, partitionCount)
            .Select(index => Path.Combine(workDir, $"{outputName}.partition.{index}.obj"))
            .ToArray();
        var completed = 0;
        var progressGate = new object();
        var tasks = Enumerable.Range(0, partitionCount).Select(index => Task.Run(() =>
        {
            var partitionPath = partitionPrefix + index.ToString(System.Globalization.CultureInfo.InvariantCulture);
            Run(toolchain.Clang,
            [
                "-target", "x86_64-pc-windows-msvc", optimizationLevel,
                "-fno-addrsig", "-mno-stack-arg-probe", "-Werror", "-Wno-override-module",
                "-x", "ir", "-c", partitionPath, "-o", objectPaths[index]
            ]);
            lock (progressGate)
            {
                completed++;
                Console.WriteLine($"[native {completed}/{partitionCount}] optimized partition");
            }
        })).ToArray();
        Task.WhenAll(tasks).GetAwaiter().GetResult();
        return objectPaths;
    }

    private static int NativeJobLimit(int processorCount)
    {
        var configured = Environment.GetEnvironmentVariable("SOLLANG_NATIVE_JOBS");
        if (string.IsNullOrWhiteSpace(configured))
        {
            return processorCount;
        }

        if (!int.TryParse(configured, out var requested) || requested < 1)
        {
            throw new SollangException("SOLLANG_NATIVE_JOBS must be a positive integer");
        }

        return Math.Min(requested, processorCount);
    }

    private string CreateKernel32ImportLibrary(string workDir)
    {
        var defPath = Path.Combine(workDir, "kernel32.def");
        var libPath = Path.Combine(workDir, "kernel32.lib");
        File.WriteAllText(defPath, """
            LIBRARY kernel32.dll
            EXPORTS
            GetStdHandle
            ExitProcess
            GetConsoleMode
            WriteConsoleW
            CreateProcessW
            GetExitCodeProcess
            ReadFile
            GetOverlappedResult
            WriteFile
            CreateFileA
            CreateFileW
            CloseHandle
            GetCurrentProcess
            DuplicateHandle
            SetFilePointerEx
            GetFileSizeEx
            GetFinalPathNameByHandleW
            GetFileInformationByHandle
            SetEndOfFile
            CreateFileMappingA
            MapViewOfFile
            FlushViewOfFile
            FlushFileBuffers
            MoveFileExA
            UnmapViewOfFile
            GetTickCount64
            Sleep
            GetCommandLineW
            WideCharToMultiByte
            MultiByteToWideChar
            GetEnvironmentVariableW
            GetLastError
            SetLastError
            LoadLibraryA
            GetProcAddress
            FreeLibrary
            FindFirstFileA
            FindNextFileA
            FindClose
            LocalFree
            GetProcessHeap
            HeapAlloc
            HeapFree
            CreateThread
            CreateEventA
            SetEvent
            SetConsoleMode
            ReadConsoleInputW
            CancelSynchronousIo
            ResetEvent
            CreateSemaphoreA
            ReleaseSemaphore
            GetActiveProcessorCount
            WaitForSingleObject
            __chkstk
            """, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));

        Run(toolchain.LlvmLib,
        [
            "/nologo",
            "/machine:x64",
            "/def:" + defPath,
            "/out:" + libPath
        ]);

        return libPath;
    }

    private string CreateShell32ImportLibrary(string workDir)
    {
        var defPath = Path.Combine(workDir, "shell32.def");
        var libPath = Path.Combine(workDir, "shell32.lib");
        File.WriteAllText(defPath, """
            LIBRARY shell32.dll
            EXPORTS
            CommandLineToArgvW
            """, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));

        Run(toolchain.LlvmLib,
        [
            "/nologo",
            "/machine:x64",
            "/def:" + defPath,
            "/out:" + libPath
        ]);

        return libPath;
    }

    private string CreateUcrtBaseImportLibrary(string workDir)
    {
        var defPath = Path.Combine(workDir, "ucrtbase.def");
        var libPath = Path.Combine(workDir, "ucrtbase.lib");
        File.WriteAllText(defPath, """
            LIBRARY ucrtbase.dll
            EXPORTS
            _wspawnvp
            memcpy
            """, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));

        Run(toolchain.LlvmLib,
        [
            "/nologo",
            "/machine:x64",
            "/def:" + defPath,
            "/out:" + libPath
        ]);

        return libPath;
    }

    private string CreateOle32ImportLibrary(string workDir)
    {
        var defPath = Path.Combine(workDir, "ole32.def");
        var libPath = Path.Combine(workDir, "ole32.lib");
        File.WriteAllText(defPath, """
            LIBRARY ole32.dll
            EXPORTS
            CoInitializeEx
            CoUninitialize
            CoCreateInstance
            """, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));

        Run(toolchain.LlvmLib,
        [
            "/nologo",
            "/machine:x64",
            "/def:" + defPath,
            "/out:" + libPath
        ]);

        return libPath;
    }

    private static bool UsesComInterop(string llPath)
    {
        const int PrefixLimit = 1024 * 1024;
        ReadOnlySpan<byte> marker = "declare dllimport i32 @CoInitializeEx"u8;
        using var stream = File.OpenRead(llPath);
        Span<byte> buffer = stackalloc byte[4096];
        var remaining = Math.Min(stream.Length, PrefixLimit);
        var matched = 0;
        while (remaining > 0)
        {
            var read = stream.Read(buffer[..(int)Math.Min(buffer.Length, remaining)]);
            if (read == 0)
            {
                break;
            }
            remaining -= read;
            foreach (var value in buffer[..read])
            {
                matched = value == marker[matched]
                    ? matched + 1
                    : value == marker[0] ? 1 : 0;
                if (matched == marker.Length)
                {
                    return true;
                }
            }
        }
        return false;
    }

    private static void Run(string fileName, IReadOnlyList<string> arguments)
    {
        var psi = new ProcessStartInfo(fileName)
        {
            UseShellExecute = false,
            RedirectStandardError = true,
            RedirectStandardOutput = true
        };

        foreach (var argument in arguments)
        {
            psi.ArgumentList.Add(argument);
        }

        using var process = Process.Start(psi)
            ?? throw new SollangException($"failed to start {fileName}");

        var stdout = process.StandardOutput.ReadToEnd();
        var stderr = process.StandardError.ReadToEnd();
        process.WaitForExit();

        if (process.ExitCode != 0)
        {
            var message = new StringBuilder();
            message.AppendLine($"{Path.GetFileName(fileName)} failed with exit code {process.ExitCode}");
            if (!string.IsNullOrWhiteSpace(stdout))
            {
                message.AppendLine(stdout.TrimEnd());
            }

            if (!string.IsNullOrWhiteSpace(stderr))
            {
                message.AppendLine(stderr.TrimEnd());
            }

            throw new SollangException(message.ToString().TrimEnd());
        }
    }
}
