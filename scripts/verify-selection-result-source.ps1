[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$OutputDirectory,
    [Parameter(Mandatory)][string]$FormatCompiler
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path -Parent $PSScriptRoot
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'SELECTION_SOURCE_FRESH_OUTPUT_REQUIRED' }
$formatter = (Resolve-Path -LiteralPath $FormatCompiler).Path
$python = (Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source

Push-Location $root
try {
    & $python scripts/generate-selection-result-emitter.py --check
    if ($LASTEXITCODE -ne 0) { throw 'SELECTION_SOURCE_GENERATION_CHECK_FAILED' }
    & scripts/format-authoritative-slg.ps1 -Check -Compiler $formatter -Source @(
        'scripts/contracts/fixtures/c385-selection-result-facts.slg',
        'scripts/contracts/fixtures/c385-selection-result-facts-driver.slg',
        'scripts/contracts/fixtures/c385-selection-and-literal-flow-program.slg',
        'scripts/contracts/fixtures/c385-selection-and-literal-flow-emission.slg',
        'selfhost/semantic/expression_type_ids_paths.slg',
        'selfhost/ir/typed.slg',
        'selfhost/ir/typed/function_lowering.slg',
        'selfhost/ir/typed/source_lowering_finalize.slg',
        'selfhost/ir/typed/ordinary_function_finalize_phases.slg',
        'selfhost/ir/typed/resolved_context_seal.slg'
    )
    New-Item -ItemType Directory -Path $output | Out-Null
    & $python scripts/verify-c385-preir-call-numeric.py --mode managed `
        --contract scripts/contracts/c385-selection-and-literal-flow-program.json `
        --output (Join-Path $output 'managed')
    if ($LASTEXITCODE -ne 0) { throw 'SELECTION_SOURCE_MANAGED_BASELINE_FAILED' }
    & $python scripts/verify-c385-preir-call-numeric.py --mode managed `
        --contract scripts/contracts/c385-selection-result-source-facts.json `
        --output (Join-Path $output 'facts')
    if ($LASTEXITCODE -ne 0) { throw 'SELECTION_SOURCE_FACTS_FAILED' }
} finally {
    Pop-Location
}
