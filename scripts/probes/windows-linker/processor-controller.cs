using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text.Json;

// Test adapter: configure this controller before creating the measured child.
// Affinity and the nested CPU job are inherited at child creation, before CLR
// startup can cache ProcessorCount. The outer verification job still owns both.
using var document = JsonDocument.Parse(File.ReadAllText(args[0]));
var test = document.RootElement.GetProperty("cases")[int.Parse(args[1])];
var api = new WindowsCpuConfiguration();
nint job = 0;
try
{
    if (test.TryGetProperty("affinity", out var affinity)) api.LimitAffinity(affinity.GetInt32());
    if (test.TryGetProperty("cpuRate", out var rate))
        job = api.LimitCpuRate(rate.GetUInt32(), test.TryGetProperty("minMax", out var minMax) && minMax.GetBoolean());
    var start = new ProcessStartInfo(args[2]) { UseShellExecute = false };
    for (var index = 3; index < args.Length; index++) start.ArgumentList.Add(args[index]);
    // Remove inherited overrides for a controlled query; do not mutate parent
    // environment or silently retry a failed configuration.
    foreach (var name in new[] { "DOTNET_PROCESSOR_COUNT", "COMPlus_PROCESSOR_COUNT", "DOTNET_ProcessorCount", "COMPlus_ProcessorCount" })
        start.Environment.Remove(name);
    if (test.TryGetProperty("environment", out var environment))
        foreach (var property in environment.EnumerateObject()) start.Environment[property.Name] = property.Value.GetString();
    using var child = Process.Start(start) ?? throw new Exception("PROCESSOR_PROBE_START_FAILED");
    child.WaitForExit();
    return child.ExitCode;
}
finally
{
    if (job != 0) WindowsCpuConfiguration.CloseHandle(job);
}

sealed class WindowsCpuConfiguration
{
    [DllImport("kernel32", SetLastError = true)] private static extern bool GetProcessAffinityMask(nint process, out nuint processMask, out nuint systemMask);
    [DllImport("kernel32", SetLastError = true)] private static extern bool SetProcessAffinityMask(nint process, nuint mask);
    [DllImport("kernel32")] private static extern nint GetCurrentProcess();
    [DllImport("kernel32", SetLastError = true)] private static extern nint CreateJobObjectW(nint attributes, nint name);
    [DllImport("kernel32", SetLastError = true)] private static extern bool SetInformationJobObject(nint job, int informationClass, ref CpuRate information, uint length);
    [DllImport("kernel32", SetLastError = true)] private static extern bool AssignProcessToJobObject(nint job, nint process);
    [DllImport("kernel32")] internal static extern bool CloseHandle(nint handle);
    [StructLayout(LayoutKind.Sequential)] private struct CpuRate { public uint Flags; public uint Rate; }

    public void LimitAffinity(int count)
    {
        if (!GetProcessAffinityMask(GetCurrentProcess(), out var available, out _)) throw new System.ComponentModel.Win32Exception();
        nuint selected = 0;
        for (var bit = 0; bit < 64 && count > 0; bit++)
        {
            var mask = (nuint)1 << bit;
            if ((available & mask) != 0) { selected |= mask; count--; }
        }
        if (count != 0) throw new Exception("PROCESSOR_PROBE_AFFINITY_UNAVAILABLE");
        if (!SetProcessAffinityMask(GetCurrentProcess(), selected)) throw new System.ComponentModel.Win32Exception();
    }

    public nint LimitCpuRate(uint rate, bool minMax)
    {
        var job = CreateJobObjectW(0, 0);
        if (job == 0) throw new System.ComponentModel.Win32Exception();
        try
        {
            var information = new CpuRate { Flags = minMax ? 0x11U : 5U, Rate = minMax ? (rate << 16) | 1U : rate };
            if (!SetInformationJobObject(job, 15, ref information, 8) || !AssignProcessToJobObject(job, GetCurrentProcess()))
                throw new System.ComponentModel.Win32Exception();
            return job;
        }
        catch { CloseHandle(job); throw; }
    }
}
