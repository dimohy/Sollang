[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][string]$Label,
    [ValidateSet("windows", "linux")][string]$Platform = "windows",
    [string]$Distribution = "Ubuntu",
    [Parameter(Mandatory)][string]$LlvmRoot,
    [Parameter(Mandatory)][string]$StdlibRoot,
    [Parameter(Mandatory)][string]$RepositoryRoot,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateRange(1, 64)][int]$Jobs = 4,
    [string[]]$Fixture = @(
        "1151-mutable-parameter-indexing-matrix",
        "1153-checked-index-control-before-logical-result",
        "1157-call-wrapped-checked-index-after-early-return"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ($Fixture.Count -eq 0) {
    throw "checked-index batch requires at least one fixture"
}

$verifierPath = Join-Path $PSScriptRoot "verify-native-mutable-parameter-indexing.ps1"
$parallelism = [Math]::Min($Fixture.Count, $Jobs)
$jobsPerFixture = [Math]::Max(1, [Math]::Floor($Jobs / $parallelism))
Write-Host "[checked index batch] $Label $Platform runs $($Fixture.Count) fixtures with $parallelism outer workers and $jobsPerFixture compiler jobs each."

$results = @($Fixture | ForEach-Object -ThrottleLimit $parallelism -Parallel {
    $fixtureName = $_
    try {
        $transcript = (& $using:verifierPath `
            -Compiler $using:Compiler `
            -Label $using:Label `
            -Platform $using:Platform `
            -Distribution $using:Distribution `
            -LlvmRoot $using:LlvmRoot `
            -StdlibRoot $using:StdlibRoot `
            -RepositoryRoot $using:RepositoryRoot `
            -OutputDirectory $using:OutputDirectory `
            -Jobs $using:jobsPerFixture `
            -Fixture $fixtureName 2>&1 | Out-String)
        [pscustomobject]@{
            Fixture = $fixtureName
            Success = $true
            Transcript = $transcript
            Error = ""
        }
    } catch {
        [pscustomobject]@{
            Fixture = $fixtureName
            Success = $false
            Transcript = ""
            Error = $_.Exception.Message
        }
    }
})

$failures = [System.Collections.Generic.List[string]]::new()
foreach ($fixtureName in $Fixture) {
    $result = $results | Where-Object { $_.Fixture -ceq $fixtureName } | Select-Object -First 1
    if ($null -eq $result) {
        $failures.Add("$fixtureName produced no batch result")
        continue
    }
    if (-not [string]::IsNullOrWhiteSpace($result.Transcript)) {
        Write-Host $result.Transcript.TrimEnd()
    }
    if (-not $result.Success) {
        $failures.Add("$fixtureName`: $($result.Error)")
    }
}

if ($failures.Count -gt 0) {
    throw "checked-index batch failed:`n$($failures -join "`n")"
}

Write-Host "[checked index batch] PASS $Label $Platform $($Fixture.Count) fixtures."
