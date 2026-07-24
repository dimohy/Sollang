param(
    [switch]$RebuildStage2,
    [ValidateRange(1, 64)]
    [int]$Jobs = 8
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactsDir = Join-Path $repoRoot "artifacts\example-tests"
$manifestPath = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-sollangc-driver.sources.txt"
$runtimeManifestPath = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-compiler-runtime.sources.txt"
$compilerRuntimeSources = Get-Content $runtimeManifestPath |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { Join-Path $repoRoot $_.Trim() }
$stage2LlvmPath = Join-Path $artifactsDir "selfhost-stage2.ll"
$stage2Path = Join-Path $artifactsDir "selfhost-stage2.exe"
$stage3LlvmPath = Join-Path $artifactsDir "selfhost-stage3.ll"
$stage3BitcodePath = Join-Path $artifactsDir "selfhost-stage3.bc"
$stage3Path = Join-Path $artifactsDir "selfhost-stage3.exe"
$stage3ErrorPath = Join-Path $artifactsDir "selfhost-stage3.err.log"
$llvmAsPath = Join-Path $repoRoot ".tools\llvm-22.1.8\bin\llvm-as.exe"
$clangPath = Join-Path $repoRoot ".tools\llvm-22.1.8\bin\clang.exe"

function Get-NormalizedHash {
    param([string]$Path)

    $content = [System.IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
    return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes))
}

if ($RebuildStage2) {
    Write-Host "[stage3 1/3] Rebuild and verify stage 2."
    & (Join-Path $PSScriptRoot "verify-selfhost-stage2.ps1") -Rebuild -Stage2BuildJobs $Jobs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    Write-Host "[stage3 1/3] Verify that the existing stage 2 is current."
}

if (-not (Test-Path $stage2Path) -or -not (Test-Path $stage2LlvmPath)) {
    throw "stage 2 is missing; rerun with -RebuildStage2"
}

$sourcePaths = Get-Content $manifestPath |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { (Resolve-Path (Join-Path $repoRoot $_.Trim())).Path }
$sourcePaths += $compilerRuntimeSources | ForEach-Object { (Resolve-Path $_).Path }
$stage2Time = (Get-Item $stage2Path).LastWriteTimeUtc
$staleInput = @($manifestPath, $runtimeManifestPath) + $sourcePaths |
    Where-Object { (Get-Item $_).LastWriteTimeUtc -gt $stage2Time } |
    Select-Object -First 1
if ($staleInput) {
    throw "stage 2 is older than '$staleInput'; rerun with -RebuildStage2"
}
Write-Host "[stage3 1/3] PASS current stage 2."

Write-Host "[stage3 2/3] Generate stage 3 from the stage-2 compiler."
Remove-Item -LiteralPath $stage3LlvmPath, $stage3ErrorPath -ErrorAction SilentlyContinue
$process = Start-Process `
    -FilePath $stage2Path `
    -ArgumentList (@("windows", "--jobs", $Jobs.ToString([System.Globalization.CultureInfo]::InvariantCulture)) + $sourcePaths) `
    -RedirectStandardOutput $stage3LlvmPath `
    -RedirectStandardError $stage3ErrorPath `
    -PassThru `
    -WindowStyle Hidden
$stage3StartedAt = [DateTimeOffset]::Now
while (-not $process.WaitForExit(30000)) {
    $elapsed = [DateTimeOffset]::Now - $stage3StartedAt
    $outputBytes = if (Test-Path -LiteralPath $stage3LlvmPath) { (Get-Item -LiteralPath $stage3LlvmPath).Length } else { 0 }
    $errorBytes = if (Test-Path -LiteralPath $stage3ErrorPath) { (Get-Item -LiteralPath $stage3ErrorPath).Length } else { 0 }
    Write-Host ("[stage3 2/3] running {0:hh\:mm\:ss}; output {1:N0} bytes; errors {2:N0} bytes." -f $elapsed, $outputBytes, $errorBytes)
}
$process.Refresh()
if ($process.ExitCode -ne 0) {
    $details = if (Test-Path $stage3ErrorPath) { Get-Content $stage3ErrorPath -Raw } else { "" }
    throw "stage-3 LLVM emission failed with exit code $($process.ExitCode).`n$details"
}
Write-Host "[stage3 2/3] PASS $((Get-Item $stage3LlvmPath).Length) LLVM bytes."

Write-Host "[stage3 3/3] Compare the complete compiler fixed point and assemble LLVM."
$stage2Hash = Get-NormalizedHash $stage2LlvmPath
$stage3Hash = Get-NormalizedHash $stage3LlvmPath
if ($stage2Hash -ne $stage3Hash) {
    throw "complete compiler fixed point differs: stage2=$stage2Hash stage3=$stage3Hash"
}
& $llvmAsPath $stage3LlvmPath -o $stage3BitcodePath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $clangPath -Wno-override-module $stage3LlvmPath -O1 -o $stage3Path
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "[stage3 3/3] PASS fixed point $stage3Hash"
