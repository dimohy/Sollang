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
    [pscustomobject]@{ Id = 'map-offset-binding'; Line = 3; Column = 28 },
    [pscustomobject]@{ Id = 'map-length-binding'; Line = 3; Column = 34 },
    [pscustomobject]@{ Id = 'map-size-binding'; Line = 3; Column = 31 }
)
$positives = @('1839-map-read-typed-clauses-positive', '1842-map-write-typed-size-positive')
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw "C511 output already exists: $output" }
$inputs = @($managed, $selfhost, $llvmAs, $PSCommandPath,
    (Join-Path $PSScriptRoot 'verification-process.ps1')) + @(
    foreach ($case in $negatives) {
        Join-Path $root "examples/regression/diagnostics/$($case.Id).slg"
        Join-Path $root "examples/regression/diagnostics/$($case.Id).stderr.contains.txt"
    }
    foreach ($id in $positives) { Join-Path $root "examples/regression/$id.slg" }
)
$hashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C511_INPUT_MISSING: $path" }
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
        -Description "C511 managed $($case.Id)"
    $selfhostRun = Invoke-VerificationProcessCapture -FilePath $selfhost `
        -ArgumentList @('windows', $source) -Description "C511 selfhost $($case.Id)"
    $managedText = $managedRun.Stdout + $managedRun.Stderr
    $selfhostText = $selfhostRun.Stdout + $selfhostRun.Stderr
    $expected = [regex]::Escape([IO.File]::ReadAllText($golden).Trim())
    $managedMatch = [regex]::Match($managedText, "semantic error at (?<line>\d+):(?<column>\d+): .*$expected")
    $selfhostMatch = [regex]::Match($selfhostText, "error\[E29\]: $expected at (?<line>\d+):(?<column>\d+)")
    $passed = $managedRun.ExitCode -eq 1 -and $selfhostRun.ExitCode -eq 1 -and
        $managedMatch.Success -and $selfhostMatch.Success -and
        [int]$managedMatch.Groups['line'].Value -eq $case.Line -and
        [int]$managedMatch.Groups['column'].Value -eq $case.Column -and
        [int]$selfhostMatch.Groups['line'].Value -eq $case.Line -and
        [int]$selfhostMatch.Groups['column'].Value -eq $case.Column -and
        [regex]::Matches($managedText, 'semantic error at').Count -eq 1 -and
        [regex]::Matches($selfhostText, 'error\[E29\]').Count -eq 1 -and
        -not $selfhostText.Contains('target triple') -and -not (Test-Path -LiteralPath $product)
    if (-not $passed) { $failures.Add("C511_MAP_CLAUSE_MISMATCH:$($case.Id)") }
    $rows += [ordered]@{ id = $case.Id; passed = $passed; managedExit = $managedRun.ExitCode;
        selfhostExit = $selfhostRun.ExitCode; managedText = $managedText; selfhostText = $selfhostText }
}
foreach ($id in $positives) {
    $source = Join-Path $root "examples/regression/$id.slg"
    $product = Join-Path $output "$id.exe"
    $ll = Join-Path $output "$id.ll"
    $bc = Join-Path $output "$id.bc"
    $managedRun = Invoke-VerificationProcessCapture -FilePath $managed `
        -ArgumentList @('build', $source, '--target', 'windows-x64', '-o', $product) `
        -Description "C511 managed $id"
    $selfhostRun = Invoke-VerificationProcessCapture -FilePath $selfhost `
        -ArgumentList @('windows', $source) -Description "C511 selfhost $id"
    if ($selfhostRun.ExitCode -eq 0) {
        [IO.File]::WriteAllText($ll, $selfhostRun.Stdout, [Text.UTF8Encoding]::new($false))
    }
    $assembly = if (Test-Path -LiteralPath $ll) {
        Invoke-VerificationProcessCapture -FilePath $llvmAs -ArgumentList @($ll, '-o', $bc) `
            -Description "C511 LLVM assembly $id"
    } else { $null }
    $passed = $managedRun.ExitCode -eq 0 -and $selfhostRun.ExitCode -eq 0 -and
        -not ($managedRun.Stdout + $managedRun.Stderr).Contains('warning ') -and
        (Test-Path -LiteralPath $product) -and $selfhostRun.Stdout.Contains('target triple') -and
        $null -ne $assembly -and $assembly.ExitCode -eq 0 -and (Test-Path -LiteralPath $bc)
    if (-not $passed) { $failures.Add("C511_MAP_CLAUSE_POSITIVE_MISMATCH:$id") }
    $rows += [ordered]@{ id = $id; passed = $passed; managedExit = $managedRun.ExitCode;
        selfhostExit = $selfhostRun.ExitCode; llvmAsExit = if ($null -ne $assembly) { $assembly.ExitCode } else { $null };
        managedText = if ($passed) { '' } else { $managedRun.Stdout + $managedRun.Stderr };
        selfhostText = if ($passed) { '' } else { $selfhostRun.Stdout + $selfhostRun.Stderr } }
}
$endHashes = [ordered]@{}
foreach ($path in $inputs) { $endHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$stable = @($inputs | Where-Object { $hashes[$_] -cne $endHashes[$_] }).Count -eq 0
if (-not $stable) { $failures.Add('C511_INPUT_DRIFT') }
$record = [ordered]@{
    schemaVersion = 1; status = if ($failures.Count -eq 0) { 'passed' } else { 'failed' }
    completed = @($rows | Where-Object passed).Count; total = $rows.Count; inputStable = $stable
    inputHashes = $hashes; inputHashesEnd = $endHashes; cases = $rows; failureIds = @($failures)
}
$result = Join-Path $output 'result.json'
[IO.File]::WriteAllText($result, (($record | ConvertTo-Json -Depth 6) + "`n"), [Text.UTF8Encoding]::new($false))
if ($failures.Count -gt 0) { throw "C511 map clause failed: $($failures -join ', '); result=$result" }
Write-Host "[C511 map clause] PASS $($record.completed)/$($record.total) cases; result=$result"
