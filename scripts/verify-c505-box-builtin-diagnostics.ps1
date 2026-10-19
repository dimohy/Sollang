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
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw "C505 box output already exists: $output" }
$cases = @(
    @{ Id = 'box-unsupported-uintsize'; Type = 'UIntSize' },
    @{ Id = 'box-unsupported-int8'; Type = 'Int8' }
)
$positive = Join-Path $root 'examples/regression/1822-box-bool-positive.slg'
$inputs = @($managed, $selfhost, $llvmAs, $PSCommandPath, (Join-Path $PSScriptRoot 'verification-process.ps1'), $positive) + @(
    foreach ($case in $cases) {
        Join-Path $root "examples/regression/diagnostics/$($case.Id).slg"
        Join-Path $root "examples/regression/diagnostics/$($case.Id).stderr.contains.txt"
    }
)
$hashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C505_BOX_INPUT_MISSING: $path" }
    $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
[IO.Directory]::CreateDirectory($output) | Out-Null
$rows = @()
$failures = [Collections.Generic.List[string]]::new()
foreach ($case in $cases) {
    $source = Join-Path $root "examples/regression/diagnostics/$($case.Id).slg"
    $expected = [IO.File]::ReadAllText((Join-Path $root "examples/regression/diagnostics/$($case.Id).stderr.contains.txt")).Trim()
    $product = Join-Path $output "$($case.Id).exe"
    $managedRun = Invoke-VerificationProcessCapture -FilePath $managed `
        -ArgumentList @('build', $source, '--target', 'windows-x64', '-o', $product) `
        -Description "C505 managed $($case.Id)"
    $selfhostRun = Invoke-VerificationProcessCapture -FilePath $selfhost `
        -ArgumentList @('windows', $source) -Description "C505 selfhost $($case.Id)"
    $managedText = $managedRun.Stdout + $managedRun.Stderr
    $selfhostText = $selfhostRun.Stdout + $selfhostRun.Stderr
    $message = [regex]::Escape($expected)
    $managedMatch = [regex]::Match($managedText, "semantic error at (?<line>\d+):(?<column>\d+): .*$message")
    $selfhostMatch = [regex]::Match($selfhostText, "error\[E29\]: $message at (?<line>\d+):(?<column>\d+)")
    $passed = $managedRun.ExitCode -eq 1 -and $selfhostRun.ExitCode -eq 1 -and
        $managedMatch.Success -and $selfhostMatch.Success -and
        [int]$managedMatch.Groups['line'].Value -eq 2 -and [int]$managedMatch.Groups['column'].Value -eq 5 -and
        [int]$selfhostMatch.Groups['line'].Value -eq 2 -and [int]$selfhostMatch.Groups['column'].Value -eq 5 -and
        [regex]::Matches($managedText, 'semantic error at').Count -eq 1 -and
        [regex]::Matches($selfhostText, 'error\[E29\]').Count -eq 1 -and
        -not (Test-Path -LiteralPath $product)
    if (-not $passed) { $failures.Add("C505_BOX_DIAGNOSTIC_MISMATCH:$($case.Id)") }
    $rows += [ordered]@{
        id = $case.Id; passed = $passed; managedExit = $managedRun.ExitCode
        selfhostExit = $selfhostRun.ExitCode; managedText = $managedText; selfhostText = $selfhostText
    }
}
$positiveProduct = Join-Path $output '1822-box-bool-positive.exe'
$positiveLl = Join-Path $output '1822-box-bool-positive.ll'
$positiveBc = Join-Path $output '1822-box-bool-positive.bc'
$managedPositive = Invoke-VerificationProcessCapture -FilePath $managed `
    -ArgumentList @('build', $positive, '--target', 'windows-x64', '-o', $positiveProduct) `
    -Description 'C505 managed positive'
$selfhostPositive = Invoke-VerificationProcessCapture -FilePath $selfhost `
    -ArgumentList @('windows', $positive) -Description 'C505 selfhost positive'
if ($selfhostPositive.ExitCode -eq 0) {
    [IO.File]::WriteAllText($positiveLl, $selfhostPositive.Stdout, [Text.UTF8Encoding]::new($false))
}
$assembly = if (Test-Path -LiteralPath $positiveLl) {
    Invoke-VerificationProcessCapture -FilePath $llvmAs -ArgumentList @($positiveLl, '-o', $positiveBc) `
        -Description 'C505 positive LLVM assembly'
} else { $null }
$positivePassed = $managedPositive.ExitCode -eq 0 -and $selfhostPositive.ExitCode -eq 0 -and
    (Test-Path -LiteralPath $positiveProduct) -and $selfhostPositive.Stdout.Contains('target triple') -and
    $null -ne $assembly -and $assembly.ExitCode -eq 0 -and (Test-Path -LiteralPath $positiveBc)
if (-not $positivePassed) { $failures.Add('C505_BOX_POSITIVE_MISMATCH') }
$endHashes = [ordered]@{}
foreach ($path in $inputs) { $endHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$stable = @($inputs | Where-Object { $hashes[$_] -cne $endHashes[$_] }).Count -eq 0
if (-not $stable) { $failures.Add('C505_BOX_INPUT_DRIFT') }
$record = [ordered]@{
    schemaVersion = 1; status = if ($failures.Count -eq 0) { 'passed' } else { 'failed' }
    completed = @($rows | Where-Object passed).Count + [int]$positivePassed; total = $cases.Count + 1
    inputStable = $stable; inputHashes = $hashes; inputHashesEnd = $endHashes
    cases = $rows
    positive = [ordered]@{ passed = $positivePassed; managedExit = $managedPositive.ExitCode
        selfhostExit = $selfhostPositive.ExitCode; llvmAsExit = if ($null -ne $assembly) { $assembly.ExitCode } else { $null } }
    failureIds = @($failures)
}
$result = Join-Path $output 'result.json'
[IO.File]::WriteAllText($result, (($record | ConvertTo-Json -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
if ($failures.Count -gt 0) { throw "C505 box builtin diagnostics failed: $($failures -join ', '); result=$result" }
Write-Host "[C505 box builtin] PASS $($record.completed)/$($record.total) managed/selfhost cases; result=$result"
