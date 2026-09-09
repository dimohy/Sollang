[CmdletBinding()]
param(
    [string]$Compiler = "",
    [ValidatePattern('^[a-z0-9-]+$')]
    [string]$Label = "stage2",
    [string]$LlvmHome = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "verification-process.ps1")

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Compiler)) {
    $Compiler = Join-Path $repoRoot "artifacts\example-tests\selfhost-sollangc-driver.exe"
}
if ([string]::IsNullOrWhiteSpace($LlvmHome)) {
    $LlvmHome = Join-Path $repoRoot ".tools\llvm-22.1.8"
}
$Compiler = [System.IO.Path]::GetFullPath($Compiler)
$clang = Join-Path ([System.IO.Path]::GetFullPath($LlvmHome)) "bin\clang.exe"
$runtimeManifest = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-compiler-runtime.sources.txt"
$focusedManifest = Join-Path $repoRoot "scripts\contracts\late-type-sealing.sources.txt"
$fixture = Join-Path $repoRoot "examples\regression\888-stdlib-aes128.slg"
$expectedPath = Join-Path $repoRoot "examples\regression\expected\888-stdlib-aes128.stdout.txt"
foreach ($required in @($Compiler, $clang, $runtimeManifest, $focusedManifest, $fixture, $expectedPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "late type sealing dependency is missing: $required"
    }
}

& (Join-Path $PSScriptRoot "verify-source-manifest-closure.ps1") `
    -Manifest $focusedManifest, $runtimeManifest `
    -RepositoryRoot $repoRoot
if (-not $?) { throw "late type sealing source manifest closure failed" }

$focusedSources = [System.IO.File]::ReadAllLines($focusedManifest) |
    ForEach-Object { $_.Trim() } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { Join-Path $repoRoot $_ }

$artifacts = Join-Path $repoRoot "artifacts\late-type-sealing"
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
$llvmPath = Join-Path $artifacts "$Label.ll"
$executablePath = Join-Path $artifacts "$Label.exe"
$stderrPath = Join-Path $artifacts "$Label.stderr.log"
Remove-Item -LiteralPath $llvmPath, $executablePath, $stderrPath -ErrorAction SilentlyContinue

$runtimeSources = [System.IO.File]::ReadAllLines($runtimeManifest) |
    ForEach-Object { $_.Trim() } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { Join-Path $repoRoot $_ }
$arguments = @(
    "windows",
    "--jobs",
    "4"
) + $focusedSources + $runtimeSources
$compile = Start-Process `
    -FilePath $Compiler `
    -ArgumentList $arguments `
    -WorkingDirectory $repoRoot `
    -RedirectStandardOutput $llvmPath `
    -RedirectStandardError $stderrPath `
    -WindowStyle Hidden `
    -PassThru
Wait-VerificationProcess $compile "$Label late type sealing focused build"
$compileErrors = [System.IO.File]::ReadAllText($stderrPath)
$compileOutput = if (Test-Path -LiteralPath $llvmPath -PathType Leaf) {
    [System.IO.File]::ReadAllText($llvmPath)
} else {
    ""
}
if ($compile.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $llvmPath -PathType Leaf)) {
    throw "$Label late type sealing emission failed or omitted LLVM.`n$compileOutput$compileErrors"
}
if (-not [string]::IsNullOrWhiteSpace($compileErrors)) {
    throw "$Label late type sealing emitted diagnostics for the valid focused closure.`n$compileErrors"
}

$llvm = [System.IO.File]::ReadAllText($llvmPath)
if ($llvm -match 'sollang compiler error S008' -or $llvm -match 'sollang compiler error S017') {
    throw "$Label late type sealing allowed a width or nominal-owner invariant failure into LLVM"
}

& $clang -Wno-override-module $llvmPath -O0 -o $executablePath -Xlinker /subsystem:console -lshell32 -lws2_32 -lbcrypt
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
    throw "$Label late type sealing LLVM failed to link"
}

$run = Invoke-VerificationProcessCapture `
    -FilePath $executablePath `
    -Description "$Label late type sealing executable"
if ($run.ExitCode -ne 0) {
    throw "$Label late type sealing executable exited with $($run.ExitCode).`n$($run.Stderr)"
}
$actual = $run.Stdout.Replace("`r`n", "`n").TrimEnd("`n")
$expected = [System.IO.File]::ReadAllText($expectedPath).Replace("`r`n", "`n").TrimEnd("`n")
if ($actual -ne $expected) {
    throw "$Label late type sealing output mismatch.`nExpected:`n$expected`nActual:`n$actual"
}

Write-Host "[selfhost late type sealing] PASS ${Label}: gzip/zstd size arithmetic, QUIC UInt64 stream IDs, exact nominal members, and fixture 888 output."
