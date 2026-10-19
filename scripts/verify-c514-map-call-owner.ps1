[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ManagedCompiler,
    [Parameter(Mandatory)][string]$SelfhostCompiler,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$RepositoryRoot = (Join-Path $PSScriptRoot '..')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')

$root = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$managed = (Resolve-Path -LiteralPath $ManagedCompiler).Path
$selfhost = (Resolve-Path -LiteralPath $SelfhostCompiler).Path
$source = Join-Path $root 'examples/regression/diagnostics/map-call-immutable-owner.slg'
$golden = Join-Path $root 'examples/regression/diagnostics/map-call-immutable-owner.stderr.contains.txt'
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw "C514 output already exists: $output" }
$inputs = @($managed, $selfhost, $source, $golden, $PSCommandPath,
    (Join-Path $PSScriptRoot 'verification-process.ps1'))
$hashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C514_INPUT_MISSING: $path" }
    $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
[IO.Directory]::CreateDirectory($output) | Out-Null

$product = Join-Path $output 'map-call-immutable-owner.exe'
$managedRun = Invoke-VerificationProcessCapture -FilePath $managed `
    -ArgumentList @('build', $source, '--target', 'windows-x64', '-o', $product) `
    -Description 'C514 managed map call owner'
$selfhostRun = Invoke-VerificationProcessCapture -FilePath $selfhost `
    -ArgumentList @('windows', $source) -Description 'C514 selfhost map call owner'
$managedText = $managedRun.Stdout + $managedRun.Stderr
$selfhostText = $selfhostRun.Stdout + $selfhostRun.Stderr
$expected = [regex]::Escape([IO.File]::ReadAllText($golden).Trim())
$managedMatch = [regex]::Match($managedText, "semantic error at (?<line>\d+):(?<column>\d+): .*$expected")
$selfhostMatch = [regex]::Match($selfhostText, "error\[E29\]: $expected at (?<line>\d+):(?<column>\d+)")
$passed = $managedRun.ExitCode -eq 1 -and $selfhostRun.ExitCode -eq 1 -and
    $managedMatch.Success -and $selfhostMatch.Success -and
    [int]$managedMatch.Groups['line'].Value -eq 7 -and [int]$managedMatch.Groups['column'].Value -eq 18 -and
    [int]$selfhostMatch.Groups['line'].Value -eq 7 -and [int]$selfhostMatch.Groups['column'].Value -eq 18 -and
    [regex]::Matches($managedText, 'semantic error at').Count -eq 1 -and
    [regex]::Matches($selfhostText, 'error\[E29\]').Count -eq 1 -and
    -not $selfhostText.Contains('target triple') -and -not (Test-Path -LiteralPath $product)
$endHashes = [ordered]@{}
foreach ($path in $inputs) { $endHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$stable = @($inputs | Where-Object { $hashes[$_] -cne $endHashes[$_] }).Count -eq 0
$failures = @()
if (-not $passed) { $failures += 'C514_MAP_CALL_OWNER_MISMATCH' }
if (-not $stable) { $failures += 'C514_INPUT_DRIFT' }
$record = [ordered]@{
    schemaVersion = 1; status = if ($failures.Count -eq 0) { 'passed' } else { 'failed' }
    completed = [int]$passed; total = 1; inputStable = $stable
    inputHashes = $hashes; inputHashesEnd = $endHashes
    case = [ordered]@{ id = 'map-call-immutable-owner'; passed = $passed;
        managedExit = $managedRun.ExitCode; selfhostExit = $selfhostRun.ExitCode;
        managedText = $managedText; selfhostText = $selfhostText }
    failureIds = $failures
}
$result = Join-Path $output 'result.json'
[IO.File]::WriteAllText($result, (($record | ConvertTo-Json -Depth 6) + "`n"), [Text.UTF8Encoding]::new($false))
if ($failures.Count -gt 0) { throw "C514 map call owner failed: $($failures -join ', '); result=$result" }
Write-Host "[C514 map call owner] PASS 1/1 case; result=$result"
