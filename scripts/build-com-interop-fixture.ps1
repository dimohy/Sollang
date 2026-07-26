[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repoRoot "tests\com-interop\com_fixture.c"
$outputRoot = Join-Path $repoRoot "artifacts\com-interop"
$llvmRoot = if ([string]::IsNullOrWhiteSpace($env:SOLLANG_LLVM_HOME)) {
    Join-Path $repoRoot ".tools\llvm-22.1.8"
} else {
    $env:SOLLANG_LLVM_HOME
}
$clang = Join-Path $llvmRoot "bin\clang.exe"
$lldLink = Join-Path $llvmRoot "bin\lld-link.exe"

New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
$object = Join-Path $outputRoot "com_fixture.windows.obj"
$output = Join-Path $outputRoot "com_fixture.dll"

& $clang `
    -target x86_64-pc-windows-msvc `
    -O3 `
    -fno-addrsig `
    -ffreestanding `
    -c $source `
    -o $object
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $lldLink `
    /nologo `
    /dll `
    /noentry `
    /machine:x64 `
    /nodefaultlib `
    /opt:ref `
    /opt:icf `
    /export:DllGetClassObject `
    /export:com_fixture_live_references `
    $object `
    /out:$output
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Wrote $output"
