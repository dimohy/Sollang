$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "browser-stage2-input-fingerprint.ps1")

$temporaryRoot = [System.IO.Path]::GetFullPath((Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ("sollang-browser-fingerprint-contract-" + [guid]::NewGuid().ToString("N"))))
try {
    $sourcePath = Join-Path $temporaryRoot "selfhost\browser.slg"
    $fixturePath = Join-Path $temporaryRoot "tests\case.slg"
    $expectedPath = Join-Path $temporaryRoot "tests\case.stdout.txt"
    $manifestPath = Join-Path $temporaryRoot "selfhost\browser.sources.txt"
    $buildScriptPath = Join-Path $temporaryRoot "scripts\build.ps1"
    $stage2Path = Join-Path $temporaryRoot "artifacts\stage2.exe"
    $llvmAsPath = Join-Path $temporaryRoot "tools\llvm-as.exe"
    $clangPath = Join-Path $temporaryRoot "tools\clang.exe"
    $wasmLdPath = Join-Path $temporaryRoot "tools\wasm-ld.exe"
    foreach ($directory in @(
        (Split-Path -Parent $sourcePath),
        (Split-Path -Parent $fixturePath),
        (Split-Path -Parent $buildScriptPath),
        (Split-Path -Parent $stage2Path),
        (Split-Path -Parent $llvmAsPath)
    )) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    [System.IO.File]::WriteAllText($sourcePath, "namespace sample")
    [System.IO.File]::WriteAllText($fixturePath, "1 -> println")
    [System.IO.File]::WriteAllText($expectedPath, "1")
    [System.IO.File]::WriteAllText($manifestPath, "selfhost/browser.slg`n")
    [System.IO.File]::WriteAllText(
        $buildScriptPath,
        '@("tests\case.slg", "tests\case.stdout.txt")')
    [System.IO.File]::WriteAllText($stage2Path, "stage2")
    [System.IO.File]::WriteAllText($llvmAsPath, "llvm-as")
    [System.IO.File]::WriteAllText($clangPath, "clang")
    [System.IO.File]::WriteAllText($wasmLdPath, "wasm-ld")

    $arguments = @{
        RepositoryRoot = $temporaryRoot
        Stage2Path = $stage2Path
        ManifestPath = $manifestPath
        BuildScriptPath = $buildScriptPath
        LlvmAsPath = $llvmAsPath
        ClangPath = $clangPath
        WasmLdPath = $wasmLdPath
    }
    $baseline = Get-BrowserStage2InputFingerprint @arguments
    if ($baseline -isnot [string] -or $baseline.Length -ne 64) {
        throw "browser input fingerprint must return one 64-character SHA-256 string"
    }
    [System.IO.File]::WriteAllText($fixturePath, "2 -> println")
    $changedFixture = Get-BrowserStage2InputFingerprint @arguments
    if ($changedFixture -ceq $baseline) {
        throw "browser input fingerprint did not change with an executable fixture"
    }
    [System.IO.File]::WriteAllText($fixturePath, "1 -> println")
    [System.IO.File]::WriteAllText((Join-Path $temporaryRoot "unrelated.txt"), "unrelated")
    if ((Get-BrowserStage2InputFingerprint @arguments) -cne $baseline) {
        throw "browser input fingerprint changed with an unrelated file"
    }
    [System.IO.File]::WriteAllText($llvmAsPath, "changed llvm-as")
    if ((Get-BrowserStage2InputFingerprint @arguments) -ceq $baseline) {
        throw "browser input fingerprint did not change with its LLVM tool"
    }
    [System.IO.File]::WriteAllText($llvmAsPath, "llvm-as")
    Remove-Item -LiteralPath $expectedPath
    $missingRejected = $false
    try {
        Get-BrowserStage2InputFingerprint @arguments | Out-Null
    } catch {
        $missingRejected = $_.Exception.Message -like "browser Stage2 referenced fixture contract is missing:*"
    }
    if (-not $missingRejected) {
        throw "browser input fingerprint accepted a missing referenced fixture contract"
    }

    Write-Host "[browser Stage2 input fingerprint contract] PASS scalar SHA-256 output, fixture/tool mutation, unrelated-file stability, and missing-fixture rejection."
} finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
