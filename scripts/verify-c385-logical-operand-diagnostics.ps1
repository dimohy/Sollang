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
New-Item -ItemType Directory -Path $output -Force | Out-Null
$cases = @(
    @{ Id = 'logical-and-both-non-bool'; Operator = 'and'; Side = 'left'; Line = 2; Column = 5 },
    @{ Id = 'logical-and-flow-result'; Operator = 'and'; Side = 'right'; Line = 2; Column = 23 },
    @{ Id = 'logical-or-both-non-bool'; Operator = 'or'; Side = 'left'; Line = 2; Column = 5 }
)
$inputs = @($managed, $selfhost, $PSCommandPath, (Join-Path $PSScriptRoot 'verification-process.ps1')) + @(
    foreach ($case in $cases) { Join-Path $root "examples/regression/diagnostics/$($case.Id).slg" }
)
$hashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C385_LOGICAL_INPUT_MISSING: $path" }
    $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}

$rows = @()
$failureIds = [Collections.Generic.List[string]]::new()
foreach ($case in $cases) {
    $source = Join-Path $root "examples/regression/diagnostics/$($case.Id).slg"
    $managedOutput = Join-Path $output "$($case.Id).exe"
    $managedResult = Invoke-VerificationProcessCapture -FilePath $managed `
        -ArgumentList @('build', $source, '--target', 'windows-x64', '-o', $managedOutput) `
        -Description "C385 managed $($case.Id)"
    $selfhostResult = Invoke-VerificationProcessCapture -FilePath $selfhost `
        -ArgumentList @('windows', $source) -Description "C385 selfhost $($case.Id)"
    $managedText = $managedResult.Stdout + $managedResult.Stderr
    $selfhostText = $selfhostResult.Stdout + $selfhostResult.Stderr
    $operatorPattern = [regex]::Escape($case.Operator)
    $managedMatches = @([regex]::Matches($managedText,
        "semantic error at (?<line>\d+):(?<column>\d+): .* (?<side>left|right) operand of '$operatorPattern' must be Bool"))
    $selfhostMatches = @([regex]::Matches($selfhostText,
        "error\[E29\]: (?<side>left|right) operand of '$operatorPattern' must be Bool at (?<line>\d+):(?<column>\d+)"))
    $passed = $managedResult.ExitCode -eq 1 -and $selfhostResult.ExitCode -eq 1 -and
        $managedMatches.Count -eq 1 -and $selfhostMatches.Count -eq 1 -and
        [regex]::Matches($managedText, 'sollang: semantic error at').Count -eq 1 -and
        [regex]::Matches($selfhostText, 'error\[E29\]').Count -eq 1 -and
        $managedMatches[0].Groups['side'].Value -ceq $case.Side -and
        $selfhostMatches[0].Groups['side'].Value -ceq $case.Side -and
        [int]$managedMatches[0].Groups['line'].Value -eq $case.Line -and
        [int]$managedMatches[0].Groups['column'].Value -eq $case.Column -and
        [int]$selfhostMatches[0].Groups['line'].Value -eq $case.Line -and
        [int]$selfhostMatches[0].Groups['column'].Value -eq $case.Column -and
        $managedText -notmatch '(?m)^target (?:datalayout|triple)' -and
        $selfhostText -notmatch '(?m)^target (?:datalayout|triple)' -and
        -not (Test-Path -LiteralPath $managedOutput)
    if (-not $passed) { $failureIds.Add("C385_LOGICAL_DIAGNOSTIC_MISMATCH:$($case.Id)") }
    $rows += [ordered]@{
        id = $case.Id; passed = $passed; managedExit = $managedResult.ExitCode
        selfhostExit = $selfhostResult.ExitCode; operator = $case.Operator; expectedSide = $case.Side
        expectedLine = $case.Line; expectedColumn = $case.Column
        managedText = $managedText; selfhostText = $selfhostText
    }
}

$hashesEnd = [ordered]@{}
foreach ($path in $inputs) { $hashesEnd[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$inputStable = @($inputs | Where-Object { $hashes[$_] -cne $hashesEnd[$_] }).Count -eq 0
if (-not $inputStable) { $failureIds.Add('C385_LOGICAL_INPUT_DRIFT') }
$record = [ordered]@{
    schemaVersion = 1; status = if ($failureIds.Count -eq 0) { 'passed' } else { 'failed' }
    completed = @($rows | Where-Object passed).Count; total = $cases.Count
    inputStable = $inputStable; inputHashes = $hashes; inputHashesEnd = $hashesEnd
    cases = $rows; failureIds = @($failureIds)
}
$resultPath = Join-Path $output 'result.json'
[IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
if ($failureIds.Count -gt 0) { throw "C385 logical diagnostics failed: $($failureIds -join ', '); result=$resultPath" }
Write-Host "[C385 logical diagnostics] PASS $($record.completed)/$($record.total) managed/selfhost pairs; result=$resultPath"
