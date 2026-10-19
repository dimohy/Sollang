using System.Diagnostics;
using System.Text;

internal static class AtomicResultFile
{
    internal const int ReplacementDeadlineMilliseconds = 1000;

    internal static void Write(string path, string json)
    {
        var temporary = path + ".tmp";
        File.WriteAllText(temporary, json, new UTF8Encoding(false));
        var elapsed = Stopwatch.StartNew();
        while (true)
        {
            try
            {
                File.Move(temporary, path, overwrite: true);
                return;
            }
            catch (Exception error) when (IsWindowsReplacementCollision(error))
            {
                // Ordinary Windows readers can deny deletion while holding the
                // old result. Keep both complete payloads and wait briefly for
                // that handle; never publish by truncating the visible file.
                if (elapsed.ElapsedMilliseconds >= ReplacementDeadlineMilliseconds)
                {
                    throw new IOException(
                        $"RESULT_PUBLICATION_RENAME_BLOCKED: {path}; prior result and temporary payload retained",
                        error);
                }
                Thread.Sleep(10);
            }
        }
    }

    private static bool IsWindowsReplacementCollision(Exception error) =>
        OperatingSystem.IsWindows()
        && error is IOException or UnauthorizedAccessException
        && (error.HResult & 0xffff) is 5 or 32 or 33;
}
