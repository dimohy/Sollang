[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$expectedCompilerSha256 = '5AB9600547E2A3C3C4E88D76895C67DEDF212B6B404B49376E45FC8E5948BB71'
if ((Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash -cne $expectedCompilerSha256) {
    throw 'baseline compiler fingerprint drifted; do not reinterpret a newer compiler as the observed baseline'
}
$output = Join-Path $root ('artifacts/scratch/borrowed-source-text-return-baseline-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($output) | Out-Null
$completed = 0
$helpers = @{
    'csv-source-escape-negative' = 'escape'
    'csv-output-alias-negative' = 'alias'
}
foreach ($name in @('csv-source-escape-negative', 'csv-output-alias-negative')) {
    $source = Join-Path $root "examples/regression/diagnostics/$name.slg"
    $sourceText = [IO.File]::ReadAllText($source)
    if (-not $sourceText.Contains("    $($helpers[$name])() -> when {", [StringComparison]::Ordinal)) {
        throw "$name does not call and consume the unsafe helper from main"
    }
    $executable = Join-Path $output "$name.exe"
    $observed = (& dotnet $compiler build $source --llvm $llvm --keep-temps -o $executable 2>&1) -join "`n"
    [IO.File]::WriteAllText((Join-Path $output "$name.log"), $observed + "`n")
    $ir = [IO.Path]::ChangeExtension($executable, '.ll')
    if ($LASTEXITCODE -ne 0 -or $observed -match '(?m)^(warning|note) ' -or
        -not (Test-Path -LiteralPath $executable -PathType Leaf) -or
        -not (Test-Path -LiteralPath $ir -PathType Leaf)) {
        throw "$name no longer preserves the reachable warning-free unsafe-acceptance baseline: $observed"
    }
    $completed++
}
Write-Host "[borrowed SourceText baseline] PASS $completed/2 predicate-only managed compiler accepted both reachable forbidden programs; compiler=$expectedCompilerSha256; $output"
