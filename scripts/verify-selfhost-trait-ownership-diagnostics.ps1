[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string[]]$Fixture = @()
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$repoRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$contract = Get-Content (Join-Path $repoRoot 'scripts/contracts/trait-ownership-diagnostics.json') -Raw | ConvertFrom-Json
if ($contract.schemaVersion -ne 1 -or $contract.cases.Count -eq 0) { throw 'Invalid trait/ownership diagnostic contract' }
$ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($case in $contract.cases) {
    if (-not $ids.Add($case.id) -or $case.expectedExit -ne 1 -or $case.outputContains.Count -eq 0) { throw "Invalid diagnostic case: $($case.id)" }
    if ($case.PSObject.Properties['timeoutMilliseconds'] -and $case.timeoutMilliseconds -le 0) { throw "Invalid diagnostic timeout: $($case.id)" }
    if ($case.PSObject.Properties['dependencySources']) {
        foreach ($dependency in $case.dependencySources) {
            $dependencyPath = [IO.Path]::GetFullPath((Join-Path $repoRoot $dependency))
            if (-not $dependencyPath.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $dependencyPath -PathType Leaf)) { throw "Invalid diagnostic dependency: $dependency" }
        }
    }
    $source = [IO.Path]::GetFullPath((Join-Path $repoRoot $case.source))
    if (-not $source.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Invalid diagnostic source: $($case.source)" }
}
if ($Fixture.Count -gt 0) {
    $requested = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($id in $Fixture) {
        if (-not $requested.Add($id)) { throw "Duplicate diagnostic selection: $id" }
        if (-not $ids.Contains($id)) { throw "Unknown diagnostic selection: $id" }
    }
    $contract.cases = @($contract.cases | Where-Object { $requested.Contains($_.id) })
}
$compilerHash = (Get-FileHash -LiteralPath $compilerPath).Hash
$failures = [Collections.Generic.List[string]]::new()
$passed = 0
foreach ($case in $contract.cases) {
    $arguments = @('windows')
    if ($case.PSObject.Properties['dependencySources']) {
        $arguments += @($case.dependencySources | ForEach-Object { Join-Path $repoRoot $_ })
    }
    $arguments += Join-Path $repoRoot $case.source
    $timeout = if ($case.PSObject.Properties['timeoutMilliseconds']) { $case.timeoutMilliseconds } else { 3600000 }
    $result = Invoke-VerificationProcessCapture -FilePath $compilerPath -ArgumentList $arguments -Description "trait/ownership $($case.id)" -TimeoutMilliseconds $timeout
    $output = $result.Stdout + $result.Stderr
    $missing = @($case.outputContains | Where-Object { -not $output.Contains($_) })
    if ($result.ExitCode -ne $case.expectedExit -or $missing.Count -gt 0 -or $output -match '(?m)^target (datalayout|triple)') {
        $failures.Add("$($case.id): exit=$($result.ExitCode), missing=$($missing -join '; '), output=$output")
    } else { $passed++ }
}
if ((Get-FileHash -LiteralPath $compilerPath).Hash -ne $compilerHash) { throw 'Diagnostic compiler changed during verification' }
if ($failures.Count -gt 0) { throw "Trait/ownership diagnostics $passed/$($contract.cases.Count) passed:`n$($failures -join "`n")" }
Write-Host "[trait/ownership diagnostics] PASS $passed/$($contract.cases.Count) actionable errors before LLVM."