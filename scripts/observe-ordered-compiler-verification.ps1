[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Plan,
    [Parameter(Mandatory)][string]$Record,
    [Parameter(Mandatory)][string]$ProgressLog
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$planPath = (Resolve-Path -LiteralPath $Plan).Path
$recordPath = [IO.Path]::GetFullPath($Record, $root)
$progressPath = [IO.Path]::GetFullPath($ProgressLog, $root)
foreach ($path in @($recordPath, $progressPath)) {
    if (Test-Path -LiteralPath $path) { throw 'ORDERED_OBSERVATION_FRESH_OUTPUT_REQUIRED' }
    if (-not $path.StartsWith((Join-Path $root 'artifacts') + [IO.Path]::DirectorySeparatorChar)) {
        throw 'ORDERED_OBSERVATION_OUTPUT_BOUNDARY_INVALID'
    }
}
$planData = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json
$output = [IO.Path]::GetFullPath($planData.output, $root)
$python = (Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
& $python --version > "$progressPath.python-version.txt" 2>&1
if ($LASTEXITCODE -ne 0) { throw 'ORDERED_OBSERVATION_PYTHON_PROBE_FAILED' }
$runner = Join-Path $PSScriptRoot 'run-ordered-focused-verification.py'
$arguments = @($runner, '--plan', $planPath, '--record', $recordPath) | ForEach-Object {
    if ($_ -match '["\r\n]') { throw 'ORDERED_OBSERVATION_ARGUMENT_INVALID' }
    '"' + $_ + '"'
}
$child = Start-Process -FilePath $python -ArgumentList $arguments -WorkingDirectory $root -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput "$progressPath.stdout.txt" -RedirectStandardError "$progressPath.stderr.txt"
try {
    do {
        $processes = @(Get-CimInstance Win32_Process)
        $ids = [Collections.Generic.HashSet[int]]::new()
        [void]$ids.Add($child.Id)
        do {
            $changed = $false
            foreach ($process in $processes) {
                if ($ids.Contains([int]$process.ParentProcessId) -and $ids.Add([int]$process.ProcessId)) { $changed = $true }
            }
        } while ($changed)
        $rows = @($processes | Where-Object { $ids.Contains([int]$_.ProcessId) } | ForEach-Object {
            [ordered]@{ pid=$_.ProcessId; parent=$_.ParentProcessId; executable=$_.Name;
                cpu100ns=([long]$_.KernelModeTime + [long]$_.UserModeTime); workingSetBytes=$_.WorkingSetSize }
        })
        $files = @(if (Test-Path -LiteralPath $output) {
            Get-ChildItem -LiteralPath $output -Recurse -File | Where-Object { $_.Extension -in @('.ll','.bc','.obj','.exe') } |
                ForEach-Object { [ordered]@{ path=$_.FullName; bytes=$_.Length; modifiedUtc=$_.LastWriteTimeUtc.ToString('o') } }
        })
        [IO.File]::AppendAllText($progressPath, (([ordered]@{timeUtc=[DateTime]::UtcNow.ToString('o'); processes=$rows; generatedFiles=$files} | ConvertTo-Json -Depth 5 -Compress) + "`n"))
        [void]$child.WaitForExit(10000)
        $child.Refresh()
    } while (-not $child.HasExited)
    $child.WaitForExit()
    if ($child.ExitCode -ne 0) { throw "ORDERED_VERIFICATION_FAILED: exit=$($child.ExitCode)" }
} finally {
    $child.Refresh()
    if (-not $child.HasExited) {
        & taskkill /PID $child.Id /T /F > "$progressPath.cancel.stdout.txt" 2> "$progressPath.cancel.stderr.txt"
        $child.WaitForExit()
    }
}
