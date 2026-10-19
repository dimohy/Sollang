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
$cases = @('box-unsupported-fixed-array', 'box-unsupported-dynamic-array',
    'box-unsupported-bounded-array', 'box-unsupported-dictionary',
    'box-unsupported-nested-box', 'box-unsupported-bitset')
$positive = Join-Path $root 'examples/regression/1823-box-nominal-positive.slg'
$llvmAs = Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe'
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw "C506 output already exists: $output" }
$inputs = @($managed, $selfhost, $llvmAs, $positive, $PSCommandPath,
    (Join-Path $PSScriptRoot 'verification-process.ps1')) + @(
    foreach ($id in $cases) {
        Join-Path $root "examples/regression/diagnostics/$id.slg"
        Join-Path $root "examples/regression/diagnostics/$id.stderr.contains.txt"
    }
)
$hashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C506_INPUT_MISSING: $path" }
    $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
[IO.Directory]::CreateDirectory($output) | Out-Null
$rows = @()
$failures = [Collections.Generic.List[string]]::new()
foreach ($id in $cases) {
    $source = Join-Path $root "examples/regression/diagnostics/$id.slg"
    $golden = Join-Path $root "examples/regression/diagnostics/$id.stderr.contains.txt"
    $product = Join-Path $output "$id.exe"
    $managedRun = Invoke-VerificationProcessCapture -FilePath $managed `
        -ArgumentList @('build', $source, '--target', 'windows-x64', '-o', $product) `
        -Description "C506 managed $id"
    $selfhostRun = Invoke-VerificationProcessCapture -FilePath $selfhost `
        -ArgumentList @('windows', $source) -Description "C506 selfhost $id"
    $managedText = $managedRun.Stdout + $managedRun.Stderr
    $selfhostText = $selfhostRun.Stdout + $selfhostRun.Stderr
    $pattern = [regex]::Escape([IO.File]::ReadAllText($golden).Trim())
    $managedMatch = [regex]::Match($managedText, "semantic error at (?<line>\d+):(?<column>\d+): .*$pattern")
    $selfhostMatch = [regex]::Match($selfhostText, "error\[E29\]: $pattern at (?<line>\d+):(?<column>\d+)")
    $passed = $managedRun.ExitCode -eq 1 -and $selfhostRun.ExitCode -eq 1 -and
        $managedMatch.Success -and $selfhostMatch.Success -and
        [int]$managedMatch.Groups['line'].Value -eq 2 -and [int]$managedMatch.Groups['column'].Value -eq 5 -and
        [int]$selfhostMatch.Groups['line'].Value -eq 2 -and [int]$selfhostMatch.Groups['column'].Value -eq 5 -and
        [regex]::Matches($managedText, 'semantic error at').Count -eq 1 -and
        [regex]::Matches($selfhostText, 'error\[E29\]').Count -eq 1 -and
        -not $selfhostText.Contains('target triple') -and -not (Test-Path -LiteralPath $product)
    if (-not $passed) { $failures.Add("C506_BOX_MISMATCH:$id") }
    $rows += [ordered]@{ id = $id; passed = $passed; managedExit = $managedRun.ExitCode
        selfhostExit = $selfhostRun.ExitCode; managedText = $managedText; selfhostText = $selfhostText }
}
$positiveProduct = Join-Path $output '1823-box-nominal-positive.exe'
$positiveLl = Join-Path $output '1823-box-nominal-positive.ll'
$positiveBc = Join-Path $output '1823-box-nominal-positive.bc'
$managedPositive = Invoke-VerificationProcessCapture -FilePath $managed `
    -ArgumentList @('build', $positive, '--target', 'windows-x64', '-o', $positiveProduct) `
    -Description 'C506 managed nominal positive'
$selfhostPositive = Invoke-VerificationProcessCapture -FilePath $selfhost `
    -ArgumentList @('windows', $positive) -Description 'C506 selfhost nominal positive'
if ($selfhostPositive.ExitCode -eq 0) {
    [IO.File]::WriteAllText($positiveLl, $selfhostPositive.Stdout, [Text.UTF8Encoding]::new($false))
}
$assembly = if (Test-Path -LiteralPath $positiveLl) {
    Invoke-VerificationProcessCapture -FilePath $llvmAs -ArgumentList @($positiveLl, '-o', $positiveBc) `
        -Description 'C506 nominal LLVM assembly'
} else { $null }
$positivePassed = $managedPositive.ExitCode -eq 0 -and $selfhostPositive.ExitCode -eq 0 -and
    (Test-Path -LiteralPath $positiveProduct) -and $selfhostPositive.Stdout.Contains('target triple') -and
    $null -ne $assembly -and $assembly.ExitCode -eq 0 -and (Test-Path -LiteralPath $positiveBc)
if (-not $positivePassed) { $failures.Add('C506_NOMINAL_POSITIVE_MISMATCH') }
$endHashes = [ordered]@{}
foreach ($path in $inputs) { $endHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$stable = @($inputs | Where-Object { $hashes[$_] -cne $endHashes[$_] }).Count -eq 0
if (-not $stable) { $failures.Add('C506_INPUT_DRIFT') }
$record = [ordered]@{
    schemaVersion = 1; status = if ($failures.Count -eq 0) { 'passed' } else { 'failed' }
    completed = @($rows | Where-Object passed).Count + [int]$positivePassed
    total = $cases.Count + 1; inputStable = $stable
    inputHashes = $hashes; inputHashesEnd = $endHashes
    cases = $rows
    positive = [ordered]@{ passed = $positivePassed; managedExit = $managedPositive.ExitCode
        selfhostExit = $selfhostPositive.ExitCode; llvmAsExit = if ($null -ne $assembly) { $assembly.ExitCode } else { $null } }
    failureIds = @($failures)
}
$result = Join-Path $output 'result.json'
[IO.File]::WriteAllText($result, (($record | ConvertTo-Json -Depth 6) + "`n"), [Text.UTF8Encoding]::new($false))
if ($failures.Count -gt 0) { throw "C506 collection box failed: $($failures -join ', '); result=$result" }
Write-Host "[C506 collection box] PASS $($record.completed)/$($record.total) pairs; result=$result"
