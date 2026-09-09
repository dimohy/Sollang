[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [ValidateSet('windows', 'linux')][string]$Target = 'windows',
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')

$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
$Compiler = [IO.Path]::GetFullPath((Join-Path $RepositoryRoot $Compiler))
$fixture = Join-Path $RepositoryRoot 'tests\Sollang.ExampleTests\Fixtures\selfhost-stage2-reference-stored-array.slg'
if (-not (Test-Path -LiteralPath $Compiler -PathType Leaf) -or
    (Get-Item -LiteralPath $Compiler).Length -eq 0) {
    throw "stored-array E23 compiler is missing or empty: $Compiler"
}

$result = Invoke-VerificationProcessCapture `
    -FilePath $Compiler `
    -ArgumentList @($Target, $fixture) `
    -Description 'stored-array readonly-reference E23 diagnostic' `
    -WorkingDirectory $RepositoryRoot `
    -TimeoutMilliseconds 120000

if ($result.ExitCode -ne 1) {
    throw "stored-array readonly-reference diagnostic exited $($result.ExitCode), expected source-error exit 1"
}
$matches = [regex]::Matches($result.Stdout, 'error\[E23\].*owner mutation conflicts with a live readonly reference')
if ($matches.Count -ne 1) {
    throw "stored-array readonly-reference diagnostic expected exactly one E23: '$($result.Stdout)'"
}
if ($result.Stdout -match 'S052|compiler-integrity defect|^target (datalayout|triple)' -or
    -not [string]::IsNullOrWhiteSpace($result.Stderr)) {
    throw "stored-array readonly-reference diagnostic reached a late or abnormal compiler path: stdout='$($result.Stdout)' stderr='$($result.Stderr)'"
}

Write-Host '[stored-array reference diagnostic] PASS exactly one E23 before LLVM; no S052 or abnormal termination.'
