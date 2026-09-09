[CmdletBinding()]
param([ValidateRange(1, 200)][int]$Iterations = 25)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')

$completed = 0
for ($index = 0; $index -lt $Iterations; $index++) {
    $process = Start-Process -FilePath $env:ComSpec -ArgumentList @('/d', '/c', 'exit 0') -PassThru -WindowStyle Hidden
    try {
        $null = Get-VerificationProcessTreeSnapshot -RootProcessId $process.Id
        $process.WaitForExit()
        $null = Get-VerificationProcessTreeSnapshot -RootProcessId $process.Id
        $completed++
    } finally {
        $process.Dispose()
    }
}

$verificationProcessSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'verification-process.ps1'))
if ($verificationProcessSource.Contains('$process.TotalProcessorTime.TotalSeconds') -or
    $verificationProcessSource.Contains('($observedAt - $previousTelemetryAt).TotalSeconds')) {
    throw 'verification telemetry still contains a chained TotalSeconds access'
}

Write-Host "[verification process exit race] PASS $completed/$Iterations live-to-exited snapshots and no chained TotalSeconds access."
