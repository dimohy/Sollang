[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][string]$RunId,
    [ValidateRange(1, 64)][int]$Jobs = 16,
    [ValidateRange(1, 64)][int]$MinimumCompilerJobs = 4,
    [string]$Fixture = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$contractPath = Join-Path $PSScriptRoot 'contracts\expression-lowering-parity.json'
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
$fixtures = @(
    if ([string]::IsNullOrWhiteSpace($Fixture)) {
        $contract.representativeFixtures
    } else {
        $Fixture
    }
)
if ($fixtures.Count -eq 0) {
    throw 'expression lowering representative fixture set is empty'
}

& (Join-Path $PSScriptRoot 'verify-native-exact-fixture-batch.ps1') `
    -Compiler $Compiler `
    -Label "expression-lowering-$RunId" `
    -Platform windows `
    -LlvmRoot (Join-Path $root '.tools\llvm-22.1.8') `
    -StdlibRoot (Join-Path $root 'stdlib') `
    -RepositoryRoot $root `
    -OutputDirectory (Join-Path $root "artifacts\scratch\expression-lowering-$RunId") `
    -Jobs $Jobs `
    -MinimumCompilerJobs $MinimumCompilerJobs `
    -Fixture $fixtures
