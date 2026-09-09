[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "verification-process.ps1")

$contractPath = Join-Path $PSScriptRoot "verify-stage2-artifact-receipt.ps1"
$powershellPath = (Get-Command pwsh -ErrorAction Stop).Source
$processes = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()

try {
    1..2 | ForEach-Object {
        $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $powershellPath
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.ArgumentList.Add("-NoProfile")
        $startInfo.ArgumentList.Add("-File")
        $startInfo.ArgumentList.Add($contractPath)
        $process = [System.Diagnostics.Process]::Start($startInfo)
        if ($null -eq $process) {
            throw "parallel Stage2 receipt contract process did not start"
        }
        $processes.Add($process)
    }

    foreach ($process in $processes) {
        Wait-VerificationProcess $process "parallel Stage2 artifact receipt contract" 10000
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        if ($process.ExitCode -ne 0) {
            throw "parallel Stage2 receipt contract failed with exit code $($process.ExitCode).`n$stdout`n$stderr"
        }
        if (-not $stdout.Contains("[stage2 receipt] PASS", [System.StringComparison]::Ordinal)) {
            throw "parallel Stage2 receipt contract did not report PASS.`n$stdout`n$stderr"
        }
    }
}
finally {
    foreach ($process in $processes) {
        $process.Dispose()
    }
}

Write-Host "[stage2 receipt concurrency] PASS two simultaneous default runs own distinct artifact directories."
