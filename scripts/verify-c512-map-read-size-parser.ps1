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
$negatives = @(
    [pscustomobject]@{ Id = 'map-read-size'; Column = 25 },
    [pscustomobject]@{ Id = 'map-read-range-size'; Column = 37 }
)
$positive = Join-Path $root 'examples/regression/1842-map-write-typed-size-positive.slg'
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw "C512 output already exists: $output" }
$inputs = @($managed, $selfhost, $llvmAs, $positive, $PSCommandPath,
    (Join-Path $PSScriptRoot 'verification-process.ps1')) + @(
    foreach ($case in $negatives) {
        Join-Path $root "examples/regression/diagnostics/$($case.Id).slg"
        Join-Path $root "examples/regression/diagnostics/$($case.Id).stderr.contains.txt"
    }
)
$hashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C512_INPUT_MISSING: $path" }
    $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
[IO.Directory]::CreateDirectory($output) | Out-Null

$rows = @()
$failures = [Collections.Generic.List[string]]::new()
foreach ($case in $negatives) {
    $source = Join-Path $root "examples/regression/diagnostics/$($case.Id).slg"
    $golden = Join-Path $root "examples/regression/diagnostics/$($case.Id).stderr.contains.txt"
    $product = Join-Path $output "$($case.Id).exe"
    $managedRun = Invoke-VerificationProcessCapture -FilePath $managed `
        -ArgumentList @('build', $source, '--target', 'windows-x64', '-o', $product) `
        -Description "C512 managed $($case.Id)"
    $selfhostRun = Invoke-VerificationProcessCapture -FilePath $selfhost `
        -ArgumentList @('windows', $source) -Description "C512 selfhost $($case.Id)"
    $managedText = $managedRun.Stdout + $managedRun.Stderr
    $selfhostText = $selfhostRun.Stdout + $selfhostRun.Stderr
    $expected = [regex]::Escape([IO.File]::ReadAllText($golden).Trim())
    $pattern = "parse error at (?<line>\d+):(?<column>\d+): $expected"
    $managedMatch = [regex]::Match($managedText, $pattern)
    $selfhostMatch = [regex]::Match($selfhostText, $pattern)
    $passed = $managedRun.ExitCode -eq 1 -and $selfhostRun.ExitCode -eq 1 -and
        $managedMatch.Success -and $selfhostMatch.Success -and
        [int]$managedMatch.Groups['line'].Value -eq 2 -and
        [int]$managedMatch.Groups['column'].Value -eq $case.Column -and
        [int]$selfhostMatch.Groups['line'].Value -eq 2 -and
        [int]$selfhostMatch.Groups['column'].Value -eq $case.Column -and
        [regex]::Matches($managedText, 'parse error at').Count -eq 1 -and
        [regex]::Matches($selfhostText, 'parse error at').Count -eq 1 -and
        -not $selfhostText.Contains('target triple') -and -not (Test-Path -LiteralPath $product)
    if (-not $passed) { $failures.Add("C512_MAP_READ_SIZE_MISMATCH:$($case.Id)") }
    $rows += [ordered]@{ id = $case.Id; passed = $passed; managedExit = $managedRun.ExitCode;
        selfhostExit = $selfhostRun.ExitCode; managedText = $managedText; selfhostText = $selfhostText }
}

$product = Join-Path $output 'map-write-size.exe'
$ll = Join-Path $output 'map-write-size.ll'
$bc = Join-Path $output 'map-write-size.bc'
$managedRun = Invoke-VerificationProcessCapture -FilePath $managed `
    -ArgumentList @('build', $positive, '--target', 'windows-x64', '-o', $product) `
    -Description 'C512 managed write-size positive'
$selfhostRun = Invoke-VerificationProcessCapture -FilePath $selfhost `
    -ArgumentList @('windows', $positive) -Description 'C512 selfhost write-size positive'
if ($selfhostRun.ExitCode -eq 0) {
    [IO.File]::WriteAllText($ll, $selfhostRun.Stdout, [Text.UTF8Encoding]::new($false))
}
$assembly = if (Test-Path -LiteralPath $ll) {
    Invoke-VerificationProcessCapture -FilePath $llvmAs -ArgumentList @($ll, '-o', $bc) `
        -Description 'C512 write-size LLVM assembly'
} else { $null }
$positivePassed = $managedRun.ExitCode -eq 0 -and $selfhostRun.ExitCode -eq 0 -and
    -not ($managedRun.Stdout + $managedRun.Stderr).Contains('warning ') -and
    (Test-Path -LiteralPath $product) -and $selfhostRun.Stdout.Contains('target triple') -and
    $null -ne $assembly -and $assembly.ExitCode -eq 0 -and (Test-Path -LiteralPath $bc)
if (-not $positivePassed) { $failures.Add('C512_MAP_WRITE_SIZE_POSITIVE_MISMATCH') }
$endHashes = [ordered]@{}
foreach ($path in $inputs) { $endHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$stable = @($inputs | Where-Object { $hashes[$_] -cne $endHashes[$_] }).Count -eq 0
if (-not $stable) { $failures.Add('C512_INPUT_DRIFT') }
$record = [ordered]@{
    schemaVersion = 1; status = if ($failures.Count -eq 0) { 'passed' } else { 'failed' }
    completed = @($rows | Where-Object passed).Count + [int]$positivePassed
    total = $negatives.Count + 1; inputStable = $stable
    inputHashes = $hashes; inputHashesEnd = $endHashes; cases = $rows
    positive = [ordered]@{ passed = $positivePassed; managedExit = $managedRun.ExitCode;
        selfhostExit = $selfhostRun.ExitCode; llvmAsExit = if ($null -ne $assembly) { $assembly.ExitCode } else { $null } }
    failureIds = @($failures)
}
$result = Join-Path $output 'result.json'
[IO.File]::WriteAllText($result, (($record | ConvertTo-Json -Depth 6) + "`n"), [Text.UTF8Encoding]::new($false))
if ($failures.Count -gt 0) { throw "C512 map read size failed: $($failures -join ', '); result=$result" }
Write-Host "[C512 map read size] PASS $($record.completed)/$($record.total) cases; result=$result"
