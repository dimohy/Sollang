[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [Parameter(Mandatory)][string]$CancellationRequestPath,
    [Parameter(Mandatory)][string]$CancellationRunId,
    [Parameter(Mandatory)][string]$CancellationAcknowledgementPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
trap [OperationCanceledException] { exit 130 }

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path
& (Join-Path $root 'scripts\verify-native-exact-fixture-batch.ps1') `
    -Compiler $Compiler `
    -Label 'c465-active-cancellation' `
    -Fixture @(
        '1396-selfhost-binary-operand-topology',
        '1410-selfhost-constant-expression-plan'
    ) `
    -Platform windows `
    -LlvmRoot (Join-Path $root '.tools\llvm-22.1.8') `
    -StdlibRoot (Join-Path $root 'stdlib') `
    -RepositoryRoot $root `
    -OutputDirectory $OutputDirectory `
    -Jobs 2 `
    -MinimumCompilerJobs 2 `
    -CancellationRequestPath $CancellationRequestPath `
    -CancellationRunId $CancellationRunId `
    -CancellationAcknowledgementPath $CancellationAcknowledgementPath

