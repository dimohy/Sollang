[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Compiler,
    [string]$Label = "selfhost",
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "verification-process.ps1")

$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$sourcePath = (Resolve-Path -LiteralPath (Join-Path `
    $RepositoryRoot `
    "examples/regression/diagnostics/1316-unit-value-binding.slg")).Path
$result = Invoke-VerificationProcessCapture `
    -FilePath $compilerPath `
    -ArgumentList @("windows", $sourcePath) `
    -Description "$Label Unit value-binding diagnostic"
$text = $result.Stdout + $result.Stderr
$expected = "cannot bind a unit value"
if ($result.ExitCode -eq 0 -or
    -not $text.Contains($expected) -or
    [regex]::Matches($text, [regex]::Escape($expected)).Count -ne 1 -or
    $text -match '(?m)^target (datalayout|triple)') {
    throw "Unit value binding did not fail once before LLVM under $Label ($compilerPath)"
}

Write-Host "[selfhost Unit binding] PASS $Label rejects Unit binding once before LLVM emission."
