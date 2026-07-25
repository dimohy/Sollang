[CmdletBinding()]
param(
    [ValidateSet("windows-x64", "linux-x64", "all")]
    [string]$Target = "all"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repoRoot "tests\native-interop\native_fixture.c"
$outputRoot = Join-Path $repoRoot "artifacts\native-interop"
$llvmRoot = if ([string]::IsNullOrWhiteSpace($env:SOLLANG_LLVM_HOME)) {
    Join-Path $repoRoot ".tools\llvm-22.1.8"
} else {
    $env:SOLLANG_LLVM_HOME
}
$clang = Join-Path $llvmRoot "bin\clang.exe"
$lldLink = Join-Path $llvmRoot "bin\lld-link.exe"

New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

function Convert-ToWslPath {
    param([string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if ($fullPath.Length -lt 3 -or $fullPath[1] -ne ':') {
        throw "cannot convert path to WSL path: $fullPath"
    }
    $drive = [char]::ToLowerInvariant($fullPath[0])
    return "/mnt/$drive/" + $fullPath.Substring(3).Replace("\", "/")
}

if ($Target -in @("windows-x64", "all")) {
    $object = Join-Path $outputRoot "native_fixture.windows.obj"
    $output = Join-Path $outputRoot "native_fixture.dll"
    & $clang `
        -target x86_64-pc-windows-msvc `
        -O3 `
        -fno-addrsig `
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
        /export:native_add `
        /export:native_mul_i64 `
        /export:native_hypot_squared `
        $object `
        /out:$output
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "Wrote $output"
}

if ($Target -in @("linux-x64", "all")) {
    $linuxSource = Convert-ToWslPath $source
    $output = Join-Path $outputRoot "libnative_fixture.so"
    $linuxOutput = Convert-ToWslPath $output
    & wsl.exe --exec cc -shared -fPIC -O3 $linuxSource -o $linuxOutput
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "Wrote $output"
}
