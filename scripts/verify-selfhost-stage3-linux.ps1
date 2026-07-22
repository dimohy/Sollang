param(
    [string]$Distribution = "Ubuntu",
    [ValidateRange(1, 64)]
    [int]$Jobs = 4,
    [switch]$RebuildStage2
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactsDir = Join-Path $repoRoot "artifacts\example-tests"
$manifestPath = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-sollangc-driver.sources.txt"
$runtimeManifestPath = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-compiler-runtime.sources.txt"
$stage2LlvmPath = Join-Path $artifactsDir "selfhost-stage2-linux.ll"
$stage2Path = Join-Path $artifactsDir "selfhost-stage2-linux"
$stage3LlvmPath = Join-Path $artifactsDir "selfhost-stage3-linux.ll"
$stage3BitcodePath = Join-Path $artifactsDir "selfhost-stage3-linux.bc"
$stage3ObjectPath = Join-Path $artifactsDir "selfhost-stage3-linux.o"
$stage3Path = Join-Path $artifactsDir "selfhost-stage3-linux"
$stage3ErrorPath = Join-Path $artifactsDir "selfhost-stage3-linux.err.log"
$llvmAsPath = Join-Path $repoRoot ".tools\llvm-22.1.8\bin\llvm-as.exe"
$clangPath = Join-Path $repoRoot ".tools\llvm-22.1.8\bin\clang.exe"
$linuxStackLinkerOption = "-Wl,-z,stack-size=268435456"
$stage3RunnerPath = Join-Path $PSScriptRoot "run-selfhost-stage3-linux.sh"

function Convert-ToWslPath {
    param([string]$Path)

    $absolute = [System.IO.Path]::GetFullPath($Path)
    $drive = $absolute.Substring(0, 1).ToLowerInvariant()
    $tail = $absolute.Substring(3).Replace('\', '/')
    "/mnt/$drive/$tail"
}

function Get-NormalizedHash {
    param([string]$Path)

    $content = [System.IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
    [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes))
}

if ($RebuildStage2) {
    Write-Host "[linux-stage3 1/3] Rebuild and verify Linux stage 2."
    & (Join-Path $PSScriptRoot "verify-selfhost-stage2-linux.ps1") -Distribution $Distribution -Jobs $Jobs -Rebuild
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    Write-Host "[linux-stage3 1/3] Reuse the existing Linux stage 2."
}

if (-not (Test-Path $stage2Path) -or -not (Test-Path $stage2LlvmPath)) {
    throw "Linux stage 2 is missing; rerun with -RebuildStage2"
}

$sourcePaths = Get-Content $manifestPath |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { (Resolve-Path (Join-Path $repoRoot $_.Trim())).Path }
$sourcePaths += Get-Content $runtimeManifestPath |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { (Resolve-Path (Join-Path $repoRoot $_.Trim())).Path }

$stage2Time = (Get-Item $stage2Path).LastWriteTimeUtc
$staleInput = @($manifestPath, $runtimeManifestPath) + $sourcePaths |
    Where-Object { (Get-Item $_).LastWriteTimeUtc -gt $stage2Time } |
    Select-Object -First 1
if ($staleInput) {
    throw "Linux stage 2 is older than '$staleInput'; rerun with -RebuildStage2"
}
Write-Host "[linux-stage3 1/3] PASS current Linux stage 2."

Write-Host "[linux-stage3 2/3] Generate Linux stage 3 from the stage-2 compiler."
Remove-Item -LiteralPath $stage3LlvmPath, $stage3ErrorPath -ErrorAction SilentlyContinue
$stage3Arguments = @(
    "-d", $Distribution, "--",
    "bash", (Convert-ToWslPath $stage3RunnerPath),
    (Convert-ToWslPath $stage2Path), "linux", "--jobs", $Jobs.ToString()
)
$stage3Arguments += $sourcePaths | ForEach-Object { Convert-ToWslPath $_ }
$process = Start-Process `
    -FilePath "wsl.exe" `
    -ArgumentList $stage3Arguments `
    -RedirectStandardOutput $stage3LlvmPath `
    -RedirectStandardError $stage3ErrorPath `
    -PassThru `
    -WindowStyle Hidden
$stage3StartedAt = [DateTimeOffset]::Now
while (-not $process.WaitForExit(30000)) {
    $elapsed = [DateTimeOffset]::Now - $stage3StartedAt
    $outputBytes = if (Test-Path -LiteralPath $stage3LlvmPath) { (Get-Item -LiteralPath $stage3LlvmPath).Length } else { 0 }
    $errorBytes = if (Test-Path -LiteralPath $stage3ErrorPath) { (Get-Item -LiteralPath $stage3ErrorPath).Length } else { 0 }
    Write-Host ("[linux-stage3 2/3] running {0:hh\:mm\:ss}; output {1:N0} bytes; errors {2:N0} bytes." -f $elapsed, $outputBytes, $errorBytes)
}
$process.Refresh()
if ($process.ExitCode -ne 0) {
    $details = if (Test-Path $stage3ErrorPath) { Get-Content $stage3ErrorPath -Raw } else { "" }
    throw "Linux stage-3 LLVM emission failed with exit code $($process.ExitCode).`n$details"
}
Write-Host "[linux-stage3 2/3] PASS $((Get-Item $stage3LlvmPath).Length) LLVM bytes."

Write-Host "[linux-stage3 3/3] Compare the fixed point, assemble, and link the native compiler."
$stage2Hash = Get-NormalizedHash $stage2LlvmPath
$stage3Hash = Get-NormalizedHash $stage3LlvmPath
if ($stage2Hash -ne $stage3Hash) {
    throw "Linux compiler fixed point differs: stage2=$stage2Hash stage3=$stage3Hash"
}
& $llvmAsPath $stage3LlvmPath -o $stage3BitcodePath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $clangPath --target=x86_64-unknown-linux-gnu -c $stage3LlvmPath -O1 -o $stage3ObjectPath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& wsl.exe -d $Distribution -- gcc (Convert-ToWslPath $stage3ObjectPath) -pthread $linuxStackLinkerOption -o (Convert-ToWslPath $stage3Path)
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& wsl.exe -d $Distribution -- test -x (Convert-ToWslPath $stage3Path)
if ($LASTEXITCODE -ne 0) { throw "Linux stage-3 compiler is not executable" }
Write-Host "[linux-stage3 3/3] PASS fixed point $stage3Hash"
