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
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw "C385 unary output already exists: $output" }
$cases = @(
    @{ Id = 'unary-not-non-bool'; Line = 2; Column = 9; Message = "'not' expects Bool" },
    @{ Id = 'unary-not-logical-precedence'; Line = 2; Column = 15; Message = "'not' expects Bool" },
    @{ Id = 'unary-negate-non-numeric'; Line = 2; Column = 6; Message = "operand of unary '-' must be a signed numeric value" },
    @{ Id = 'unary-negate-unsigned'; Line = 2; Column = 6; Message = "operand of unary '-' must be a signed numeric value" },
    @{ Id = 'unary-nested-inner-error'; Line = 2; Column = 10; Message = "'not' expects Bool" }
)
$inputs = @($managed, $selfhost, $PSCommandPath, (Join-Path $PSScriptRoot 'verification-process.ps1')) + @(
    foreach ($case in $cases) {
        Join-Path $root "examples/regression/diagnostics/$($case.Id).slg"
        Join-Path $root "examples/regression/diagnostics/$($case.Id).stderr.contains.txt"
    }
)
$hashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C385_UNARY_INPUT_MISSING: $path" }
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
        -Description "C385 managed $($case.Id)"
    $selfhostRun = Invoke-VerificationProcessCapture -FilePath $selfhost `
        -ArgumentList @('windows', $source) -Description "C385 selfhost $($case.Id)"
    $managedText = $managedRun.Stdout + $managedRun.Stderr
    $selfhostText = $selfhostRun.Stdout + $selfhostRun.Stderr
    $messagePattern = [regex]::Escape($case.Message)
    $managedMatch = [regex]::Match($managedText, "semantic error at (?<line>\d+):(?<column>\d+): .*$messagePattern")
    $selfhostMatch = [regex]::Match($selfhostText, "error\[E29\]: $messagePattern at (?<line>\d+):(?<column>\d+)")
    $passed = $managedRun.ExitCode -eq 1 -and $selfhostRun.ExitCode -eq 1 -and
        $managedMatch.Success -and $selfhostMatch.Success -and
        [int]$managedMatch.Groups['line'].Value -eq $case.Line -and
        [int]$managedMatch.Groups['column'].Value -eq $case.Column -and
        [int]$selfhostMatch.Groups['line'].Value -eq $case.Line -and
        [int]$selfhostMatch.Groups['column'].Value -eq $case.Column -and
        $managedText.Contains($expected) -and $selfhostText.Contains($expected) -and
        [regex]::Matches($managedText, 'semantic error at').Count -eq 1 -and
        [regex]::Matches($selfhostText, 'error\[E29\]').Count -eq 1 -and
        -not (Test-Path -LiteralPath $product)
    if (-not $passed) { $failures.Add("C385_UNARY_DIAGNOSTIC_MISMATCH:$($case.Id)") }
    $rows += [ordered]@{
        id = $case.Id; passed = $passed; managedExit = $managedRun.ExitCode
        selfhostExit = $selfhostRun.ExitCode; expectedLine = $case.Line
        expectedColumn = $case.Column; managedText = $managedText; selfhostText = $selfhostText
    }
}
$endHashes = [ordered]@{}
foreach ($path in $inputs) { $endHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$stable = @($inputs | Where-Object { $hashes[$_] -cne $endHashes[$_] }).Count -eq 0
if (-not $stable) { $failures.Add('C385_UNARY_INPUT_DRIFT') }
$record = [ordered]@{
    schemaVersion = 1; status = if ($failures.Count -eq 0) { 'passed' } else { 'failed' }
    completed = @($rows | Where-Object passed).Count; total = $cases.Count
    inputStable = $stable; inputHashes = $hashes; inputHashesEnd = $endHashes
    cases = $rows; failureIds = @($failures)
}
$result = Join-Path $output 'result.json'
[IO.File]::WriteAllText($result, (($record | ConvertTo-Json -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
if ($failures.Count -gt 0) { throw "C385 unary diagnostics failed: $($failures -join ', '); result=$result" }
Write-Host "[C385 unary diagnostics] PASS $($record.completed)/$($record.total) managed/selfhost pairs; result=$result"
