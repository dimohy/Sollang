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
$llvmAs = Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe'
$cases = @('1840-map-unused-function-positive', '1841-map-unused-main-positive')
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw "C510 output already exists: $output" }
$inputs = @($managed, $selfhost, $llvmAs, $PSCommandPath,
    (Join-Path $PSScriptRoot 'verification-process.ps1')) + @(
    foreach ($id in $cases) { Join-Path $root "examples/regression/$id.slg" }
)
$hashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C510_INPUT_MISSING: $path" }
    $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
[IO.Directory]::CreateDirectory($output) | Out-Null

$rows = @()
$failures = [Collections.Generic.List[string]]::new()
foreach ($id in $cases) {
    $source = Join-Path $root "examples/regression/$id.slg"
    $product = Join-Path $output "$id.exe"
    $ll = Join-Path $output "$id.ll"
    $bc = Join-Path $output "$id.bc"
    $managedRun = Invoke-VerificationProcessCapture -FilePath $managed `
        -ArgumentList @('build', $source, '--target', 'windows-x64', '-o', $product) `
        -Description "C510 managed $id"
    $selfhostRun = Invoke-VerificationProcessCapture -FilePath $selfhost `
        -ArgumentList @('windows', $source) -Description "C510 selfhost $id"
    if ($selfhostRun.ExitCode -eq 0) {
        [IO.File]::WriteAllText($ll, $selfhostRun.Stdout, [Text.UTF8Encoding]::new($false))
    }
    $assembly = if (Test-Path -LiteralPath $ll) {
        Invoke-VerificationProcessCapture -FilePath $llvmAs -ArgumentList @($ll, '-o', $bc) `
            -Description "C510 LLVM assembly $id"
    } else { $null }
    $passed = $managedRun.ExitCode -eq 0 -and $selfhostRun.ExitCode -eq 0 -and
        (Test-Path -LiteralPath $product) -and $selfhostRun.Stdout.Contains('target triple') -and
        -not $selfhostRun.Stdout.Contains('S060') -and
        $null -ne $assembly -and $assembly.ExitCode -eq 0 -and (Test-Path -LiteralPath $bc)
    if (-not $passed) { $failures.Add("C510_MAP_PRODUCER_MISMATCH:$id") }
    $rows += [ordered]@{ id = $id; passed = $passed; managedExit = $managedRun.ExitCode;
        selfhostExit = $selfhostRun.ExitCode; llvmAsExit = if ($null -ne $assembly) { $assembly.ExitCode } else { $null };
        selfhostText = if ($passed) { '' } else { $selfhostRun.Stdout + $selfhostRun.Stderr } }
}

$endHashes = [ordered]@{}
foreach ($path in $inputs) { $endHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$stable = @($inputs | Where-Object { $hashes[$_] -cne $endHashes[$_] }).Count -eq 0
if (-not $stable) { $failures.Add('C510_INPUT_DRIFT') }
$record = [ordered]@{
    schemaVersion = 1; status = if ($failures.Count -eq 0) { 'passed' } else { 'failed' }
    completed = @($rows | Where-Object passed).Count; total = $cases.Count; inputStable = $stable
    inputHashes = $hashes; inputHashesEnd = $endHashes; cases = $rows; failureIds = @($failures)
}
$result = Join-Path $output 'result.json'
[IO.File]::WriteAllText($result, (($record | ConvertTo-Json -Depth 6) + "`n"), [Text.UTF8Encoding]::new($false))
if ($failures.Count -gt 0) { throw "C510 map producer failed: $($failures -join ', '); result=$result" }
Write-Host "[C510 map producer] PASS $($record.completed)/$($record.total) cases; result=$result"
