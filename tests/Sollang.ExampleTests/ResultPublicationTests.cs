using System.Text.Json;

internal static class ResultPublicationTests
{
    internal static int Run(string resultPath)
    {
        if (!OperatingSystem.IsWindows())
            throw new PlatformNotSupportedException("Windows result publication regression requires Windows.");
        resultPath = Path.GetFullPath(resultPath);
        if (File.Exists(resultPath)) throw new IOException("Test result already exists.");
        var root = resultPath + ".cases";
        if (Directory.Exists(root)) throw new IOException("Test case directory already exists.");
        Directory.CreateDirectory(root);
        var cases = new List<object>();
        try
        {
            void Check(string id, Action action)
            {
                action();
                cases.Add(new { id, status = "passed" });
            }
            string Destination(string id)
            {
                var directory = Path.Combine(root, id);
                Directory.CreateDirectory(directory);
                var path = Path.Combine(directory, "result.json");
                File.WriteAllText(path, "{\"version\":0}");
                return path;
            }
            void Require(bool value, string id)
            {
                if (!value) throw new InvalidOperationException(id);
            }
            Check("normal-atomic-replace", () =>
            {
                var path = Destination("normal");
                AtomicResultFile.Write(path, "{\"version\":1}");
                Require(File.ReadAllText(path) == "{\"version\":1}" && !File.Exists(path + ".tmp"), "normal replacement failed");
            });
            Check("transient-reader-lock-recovers", () =>
            {
                var path = Destination("transient");
                using var observer = File.OpenRead(path);
                using var started = new ManualResetEventSlim();
                var publication = Task.Run(() =>
                {
                    started.Set();
                    AtomicResultFile.Write(path, "{\"version\":2}");
                });
                started.Wait();
                Thread.Sleep(75);
                Require(!publication.IsCompleted, "reader did not exercise replacement collision");
                observer.Dispose();
                publication.GetAwaiter().GetResult();
                Require(File.ReadAllText(path) == "{\"version\":2}", "transient replacement lost new result");
            });
            Check("persistent-reader-lock-explicit-failure", () =>
            {
                var path = Destination("persistent");
                using var observer = File.OpenRead(path);
                try
                {
                    AtomicResultFile.Write(path, "{\"version\":3}");
                    throw new InvalidOperationException("persistent collision was bypassed");
                }
                catch (IOException error) when (error.Message.StartsWith("RESULT_PUBLICATION_RENAME_BLOCKED:", StringComparison.Ordinal))
                {
                    Require(File.ReadAllText(path) == "{\"version\":0}", "persistent failure damaged prior result");
                    Require(File.ReadAllText(path + ".tmp") == "{\"version\":3}", "persistent failure discarded pending result");
                }
            });
            Check("invalid-parent-explicit-failure", () =>
            {
                var path = Path.Combine(root, "missing", "result.json");
                try
                {
                    AtomicResultFile.Write(path, "{}");
                    throw new InvalidOperationException("missing parent was silently replaced");
                }
                catch (DirectoryNotFoundException) { }
            });
            Check("concurrent-delete-sharing-reader-never-sees-partial-json", () =>
            {
                var path = Destination("concurrent");
                using var cancellation = new CancellationTokenSource();
                using var started = new ManualResetEventSlim();
                var reads = 0;
                var observer = Task.Run(() =>
                {
                    while (!cancellation.IsCancellationRequested)
                    {
                        using var file = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
                        using var document = JsonDocument.Parse(file);
                        document.RootElement.GetProperty("version").GetInt32();
                        Interlocked.Increment(ref reads);
                        started.Set();
                    }
                });
                try
                {
                    started.Wait();
                    for (var version = 1; version <= 40; version++)
                        AtomicResultFile.Write(path, JsonSerializer.Serialize(new { version, padding = new string('x', 65536) }));
                }
                finally
                {
                    cancellation.Cancel();
                    observer.GetAwaiter().GetResult();
                }
                Require(reads > 0, "concurrent observer never read a result");
                using var final = JsonDocument.Parse(File.ReadAllText(path));
                Require(final.RootElement.GetProperty("version").GetInt32() == 40, "final publication was lost");
            });
            AtomicResultFile.Write(resultPath, JsonSerializer.Serialize(new
            {
                schemaVersion = 1, status = "passed", completed = cases.Count, total = 5,
                cases, processesStopped = true
            }, new JsonSerializerOptions { WriteIndented = true }));
            Console.WriteLine($"Result publication regression PASS {cases.Count}/5");
            return 0;
        }
        catch (Exception error)
        {
            File.WriteAllText(resultPath, JsonSerializer.Serialize(new
            {
                schemaVersion = 1, status = "failed", completed = cases.Count, total = 5,
                cases, failure = error.ToString(), processesStopped = true
            }));
            Console.Error.WriteLine(error);
            return 1;
        }
    }
}
