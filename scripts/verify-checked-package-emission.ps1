[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Contract,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [Parameter(Mandatory)][string]$FormatCompiler
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$validator = Join-Path $PSScriptRoot 'verify-checked-package-emitter.py'
$runner = Join-Path $PSScriptRoot 'verify-c385-preir-call-numeric.py'
Push-Location -LiteralPath $root
try {
    & python $validator --contract $Contract
    if ($LASTEXITCODE -ne 0) { throw 'CHECKED_PACKAGE_PREFLIGHT_FAILED' }
    & python $runner --mode managed --format-compiler $FormatCompiler --contract $Contract --output $OutputDirectory
    if ($LASTEXITCODE -ne 0) { throw 'CHECKED_PACKAGE_EXECUTION_FAILED' }
} finally {
    Pop-Location
}
