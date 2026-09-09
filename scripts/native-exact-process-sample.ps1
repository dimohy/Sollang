Set-StrictMode -Version Latest

function Get-NativeExactProcessSample {
    param([Parameter(Mandatory)][object]$Process)

    # PowerShell's Process adapter can return null for CPU time when a process
    # exits between enumeration and observation. Preserve this coverage gap;
    # never reinterpret an unavailable CPU sample as measured zero CPU.
    $workingSet = $Process.WorkingSet64
    $cpuTime = $Process.TotalProcessorTime
    if ($null -ne $cpuTime -and $cpuTime -isnot [TimeSpan]) {
        throw "Unexpected process CPU sample type: $($cpuTime.GetType().FullName)"
    }
    [pscustomobject]@{
        WorkingSetBytes = $workingSet
        CpuMilliseconds = if ($null -eq $cpuTime) { $null } else { [long]$cpuTime.TotalMilliseconds }
        CpuAvailable = $null -ne $cpuTime
    }
}
