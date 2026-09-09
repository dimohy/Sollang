[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][string]$RepositoryRoot
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "verification-process.ps1")

$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$repoRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$cases = @(
    @("logical-and-flow-result", "right operand of 'and' must be Bool", "E29"),
    @("enum-non-exhaustive", "non-exhaustive enum when", "E30")
)
$positiveCases = @("1546-logical-flow-bool")

foreach ($case in $cases) {
    $source = Join-Path $repoRoot "examples\regression\diagnostics\$($case[0]).slg"
    $result = Invoke-VerificationProcessCapture `
        -FilePath $compilerPath `
        -ArgumentList @("windows", $source) `
        -Description "self-host semantic parity $($case[0])"
    $text = $result.Stdout + $result.Stderr
    if ($result.ExitCode -ne 1 -or $text -notmatch [regex]::Escape($case[1])) {
        throw "$($case[0]) did not fail once with its actionable semantic diagnostic under $compilerPath.`n$text"
    }
    if ([regex]::Matches($text, "error\[$($case[2])\]").Count -ne 1 -or $text -match '(?m)^target (datalayout|triple)') {
        throw "$($case[0]) did not stop exactly once before LLVM emission under $compilerPath.`n$text"
    }
}

foreach ($case in $positiveCases) {
    $source = Join-Path $repoRoot "examples\regression\$case.slg"
    $result = Invoke-VerificationProcessCapture `
        -FilePath $compilerPath `
        -ArgumentList @("windows", $source) `
        -Description "self-host semantic parity $case"
    $text = $result.Stdout + $result.Stderr
    if ($result.ExitCode -ne 0 -or $text -notmatch '(?m)^target triple' -or $text -match 'error\[E29\]') {
        throw "$case did not preserve its Bool flow operand through LLVM emission under $compilerPath.`n$text"
    }
}

Write-Host '[selfhost semantic parity] PASS Bool flow operands compile, while non-Bool logical operands and non-exhaustive enum matches fail before LLVM.'
