using Sollang.Compiler.Diagnostics;

namespace Sollang.Compiler.Cli;

/// <summary>
/// Owns the output claims and same-directory stages for one native build.
/// The executable is published only after code generation and linking succeed.
/// </summary>
internal sealed class NativeOutputTransaction : IDisposable
{
    private readonly string outputPath;
    private readonly string llvmOutputPath;
    private readonly string executableLockPath;
    private readonly string llvmLockPath;
    private FileStream? executableLock;
    private FileStream? llvmLock;
    private bool disposed;
    private bool published;

    public string LlvmStagePath { get; private set; } = "";
    public string ExecutableStagePath { get; private set; } = "";
    public string WorkDirectory { get; private set; } = "";

    public NativeOutputTransaction(string outputPath)
    {
        if (OperatingSystem.IsWindows()
            && outputPath.Length >= 2
            && char.IsLetter(outputPath[0])
            && outputPath[1] == ':'
            && (outputPath.Length < 3 || outputPath[2] is not ('/' or '\\')))
        {
            throw new SollangException($"output path is drive-relative and unsafe: {outputPath}");
        }
        this.outputPath = Path.GetFullPath(outputPath);
        llvmOutputPath = this.outputPath + ".ll";
        var directory = Path.GetDirectoryName(this.outputPath)
            ?? throw new SollangException($"output has no parent directory: {outputPath}");
        Directory.CreateDirectory(directory);
        executableLockPath = this.outputPath + ".sollang-txn-lock";
        llvmLockPath = llvmOutputPath + ".sollang-txn-lock";
        ValidateDestination(this.outputPath);
        ValidateDestination(llvmOutputPath);

        try
        {
            executableLock = ClaimLock(executableLockPath);
            llvmLock = ClaimLock(llvmLockPath);
            ClaimStages(directory);
        }
        catch
        {
            Dispose();
            throw;
        }
    }

    public void Publish(bool keepTemps)
    {
        if (!File.Exists(ExecutableStagePath)
            || new FileInfo(ExecutableStagePath).Length == 0)
        {
            throw new SollangException($"native linker did not produce an executable: {ExecutableStagePath}");
        }
        if (keepTemps)
        {
            File.Move(LlvmStagePath, llvmOutputPath, overwrite: true);
        }
        File.Move(ExecutableStagePath, outputPath, overwrite: true);
        published = true;
    }

    public void PublishLlvmOnly()
    {
        File.Move(LlvmStagePath, llvmOutputPath, overwrite: true);
        published = true;
    }

    public void Dispose()
    {
        if (disposed)
        {
            return;
        }
        disposed = true;

        try
        {
            if (published || WorkDirectory.Length == 0)
            {
                DeleteOwnedFile(LlvmStagePath);
                DeleteOwnedFile(ExecutableStagePath);
                if (WorkDirectory.Length > 0 && Directory.Exists(WorkDirectory))
                {
                    Directory.Delete(WorkDirectory, recursive: true);
                }
            }
            else
            {
                // A fully claimed but unpublished build owns diagnostic artifacts.
                // Keep them for the caller's failed-output retention lifecycle.
                if (File.Exists(LlvmStagePath))
                {
                    Console.Error.WriteLine($"sollang: retained failed LLVM stage: {LlvmStagePath}");
                }
                if (File.Exists(ExecutableStagePath))
                {
                    Console.Error.WriteLine($"sollang: retained failed executable stage: {ExecutableStagePath}");
                }
                if (Directory.Exists(WorkDirectory))
                {
                    Console.Error.WriteLine($"sollang: retained failed native work directory: {WorkDirectory}");
                }
            }
        }
        finally
        {
            llvmLock?.Dispose();
            executableLock?.Dispose();
            if (llvmLock is not null)
            {
                DeleteOwnedFile(llvmLockPath);
            }
            if (executableLock is not null)
            {
                DeleteOwnedFile(executableLockPath);
            }
        }
    }

    private static FileStream ClaimLock(string path)
    {
        try
        {
            return new FileStream(path, FileMode.CreateNew, FileAccess.ReadWrite, FileShare.None);
        }
        catch (IOException error)
        {
            throw new SollangException($"native build output lock is busy or unavailable: {path}: {error.Message}");
        }
    }

    private static void ValidateDestination(string path)
    {
        if (!OperatingSystem.IsWindows())
        {
            return;
        }

        var name = Path.GetFileName(path);
        if (name.Length == 0 || name[^1] is '.' or ' ')
        {
            throw new SollangException($"output path has an unsafe file name: {path}");
        }
        if (name.EndsWith(".sollang-txn-lock", StringComparison.OrdinalIgnoreCase))
        {
            throw new SollangException($"output path uses a reserved staging lock name: {path}");
        }

        var directory = Path.GetDirectoryName(path)!;
        var actualName = Directory.EnumerateFileSystemEntries(directory)
            .Select(Path.GetFileName)
            .FirstOrDefault(existing => string.Equals(existing, name, StringComparison.OrdinalIgnoreCase));
        if (actualName is not null && !File.Exists(path))
        {
            throw new SollangException($"output path exists but its identity cannot be verified: {path}");
        }
        if (actualName is null && File.Exists(path))
        {
            throw new SollangException($"output path aliases a different existing file name: {path}");
        }
        if (actualName is null && HasShortNameMarker(name))
        {
            throw new SollangException($"output path may be an unresolved short-name alias: {path}");
        }
        if (actualName is not null)
        {
            var attributes = File.GetAttributes(path);
            if ((attributes & FileAttributes.ReparsePoint) != 0
                || (attributes & FileAttributes.Directory) != 0)
            {
                throw new SollangException($"output path names an unsupported filesystem object: {path}");
            }
        }
    }

    private static bool HasShortNameMarker(string name)
    {
        for (var index = 0; index + 1 < name.Length; index++)
        {
            if (name[index] == '~' && char.IsAsciiDigit(name[index + 1]))
            {
                return true;
            }
        }
        return false;
    }

    private void ClaimStages(string directory)
    {
        for (var ordinal = 0; ordinal < 256; ordinal++)
        {
            var llvmStage = Path.Combine(directory, $".l{ordinal}.ll");
            var executableStage = Path.Combine(directory, $".e{ordinal}.exe");
            var workDirectory = Path.Combine(directory, $".w{ordinal}");
            if (Directory.Exists(workDirectory))
            {
                continue;
            }

            try
            {
                using (new FileStream(llvmStage, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                {
                }
            }
            catch (IOException)
            {
                continue;
            }

            try
            {
                using (new FileStream(executableStage, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                {
                }
            }
            catch (IOException)
            {
                File.Delete(llvmStage);
                continue;
            }

            try
            {
                if (Directory.Exists(workDirectory))
                {
                    File.Delete(llvmStage);
                    File.Delete(executableStage);
                    continue;
                }
                Directory.CreateDirectory(workDirectory);
            }
            catch
            {
                File.Delete(llvmStage);
                File.Delete(executableStage);
                throw;
            }

            LlvmStagePath = llvmStage;
            ExecutableStagePath = executableStage;
            WorkDirectory = workDirectory;
            return;
        }

        throw new SollangException($"native build staging slots exhausted in {directory}");
    }

    private static void DeleteOwnedFile(string path)
    {
        if (path.Length > 0 && File.Exists(path))
        {
            File.Delete(path);
        }
    }
}
