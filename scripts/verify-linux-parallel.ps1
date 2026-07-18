param(
    [string]$Distribution = "Ubuntu"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactsDir = Join-Path $repoRoot "artifacts\example-tests"
$compilerProject = Join-Path $repoRoot "src\Sollang.Compiler\Sollang.Compiler.csproj"
$runnerProject = Join-Path $repoRoot "tests\Sollang.ExampleTests\Sollang.ExampleTests.csproj"
$llvmDir = Join-Path $repoRoot ".tools\llvm-22.1.8"
$clangPath = Join-Path $llvmDir "bin\clang.exe"

function Convert-ToWslPath {
    param([string]$Path)

    $absolute = [System.IO.Path]::GetFullPath($Path)
    $drive = $absolute.Substring(0, 1).ToLowerInvariant()
    $tail = $absolute.Substring(3).Replace('\', '/')
    return "/mnt/$drive/$tail"
}

function Invoke-Wsl {
    param([string[]]$Arguments)

    $output = & wsl.exe -d $Distribution -- @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "WSL command failed ($LASTEXITCODE): $($Arguments -join ' ')"
    }
    return ($output | Out-String).TrimEnd("`r", "`n")
}

function Build-And-RunReferenceExample {
    param(
        [string]$Name,
        [string]$Expected
    )

    $sourcePath = Join-Path $repoRoot "examples\$Name.slg"
    $outputPath = Join-Path $artifactsDir "$Name.linux"
    & dotnet run --project $compilerProject -c Release --no-build -- build `
        $sourcePath -o $outputPath --target linux-x64 --llvm $llvmDir -O0
    if ($LASTEXITCODE -ne 0) {
        throw "Linux reference build failed: $Name"
    }

    $actual = Invoke-Wsl @((Convert-ToWslPath $outputPath))
    if ($actual -ne $Expected) {
        throw "Linux reference execution mismatch for $Name.`nEXPECTED:`n$Expected`nACTUAL:`n$actual"
    }
}

New-Item -ItemType Directory -Force -Path $artifactsDir | Out-Null

Write-Host "[linux 1/6] Verify WSL2 and the native Linux toolchain."
$kernel = Invoke-Wsl @("uname", "-sr")
$gcc = Invoke-Wsl @("gcc", "--version")
Write-Host "[linux 1/6] PASS $kernel; $($gcc.Split("`n")[0])"

Write-Host "[linux 2/6] Execute ordered per-index output sinks."
Build-And-RunReferenceExample `
    "375-ordered-parallel-memory-output-sink" `
    "[8][1][6][3][7][2][5][4] results=16,8"
Write-Host "[linux 2/6] PASS ordered output sinks"

Write-Host "[linux 3/6] Execute parent-assisted waiting with one native worker."
Build-And-RunReferenceExample `
    "381-parallel-parent-help" `
    "workers=1, parent-helped=true, results=8"
Write-Host "[linux 3/6] PASS parent-assisted waiting"

Write-Host "[linux 4/6] Reuse the bounded pool across 100 generations."
Build-And-RunReferenceExample `
    "383-parallel-reusable-generations" `
    "generations=100, checksum=1800, workers=2"
Write-Host "[linux 4/6] PASS 100 reusable generations"

Write-Host "[linux 5/6] Execute LLVM emitted by the native self-host compiler."
& dotnet run --project $runnerProject -c Release --no-build -- `
    --exact 382-selfhost-llvm-linux-parallel-pool `
    --exact 396-selfhost-llvm-owned-try-parallel-cleanup `
    --jobs 1
if ($LASTEXITCODE -ne 0) {
    throw "Self-host Linux LLVM regression failed"
}

$selfHostLlvm = Join-Path $artifactsDir "382-selfhost-llvm-linux-parallel-pool.stdout.ll"
$selfHostObject = Join-Path $artifactsDir "382-selfhost-llvm-linux-parallel-pool.o"
& $clangPath --target=x86_64-unknown-linux-gnu -c $selfHostLlvm -O0 -o $selfHostObject
if ($LASTEXITCODE -ne 0) {
    throw "Self-host Linux LLVM object generation failed"
}

$wslObject = Convert-ToWslPath $selfHostObject
$wslExecutable = "/tmp/sollang-selfhost-linux-parallel"
Invoke-Wsl @("gcc", $wslObject, "-pthread", "-o", $wslExecutable) | Out-Null
$selfHostActual = Invoke-Wsl @($wslExecutable)
$selfHostExpectedPath = Join-Path $repoRoot `
    "examples\expected\382-selfhost-llvm-linux-parallel-pool.stdout.llvm.linux.execute.txt"
$selfHostExpected = ([System.IO.File]::ReadAllText($selfHostExpectedPath)).TrimEnd("`r", "`n")
if ($selfHostActual -ne $selfHostExpected) {
    throw "Self-host Linux execution mismatch.`nEXPECTED:`n$selfHostExpected`nACTUAL:`n$selfHostActual"
}
Write-Host "[linux 5/6] PASS self-host emitted Linux pool"

Write-Host "[linux 6/6] Verify owned tryParallel cleanup with AddressSanitizer."
$ownedLlvm = Join-Path $artifactsDir "396-selfhost-llvm-owned-try-parallel-cleanup.stdout.ll"
$ownedObject = Join-Path $artifactsDir "396-selfhost-llvm-owned-try-parallel-cleanup.asan.o"
& $clangPath --target=x86_64-unknown-linux-gnu -c $ownedLlvm -O0 `
    -fsanitize=address -fno-omit-frame-pointer -o $ownedObject
if ($LASTEXITCODE -ne 0) {
    throw "Owned tryParallel AddressSanitizer instrumentation failed"
}

$wslOwnedObject = Convert-ToWslPath $ownedObject
$wslOwnedExecutable = "/tmp/sollang-selfhost-owned-tryparallel-asan"
Invoke-Wsl @(
    "gcc",
    $wslOwnedObject,
    "-pthread",
    "-fsanitize=address",
    "-o",
    $wslOwnedExecutable
) | Out-Null
$ownedActual = Invoke-Wsl @(
    "env",
    "ASAN_OPTIONS=detect_leaks=1:halt_on_error=1:exitcode=97",
    $wslOwnedExecutable
)
$ownedExpectedPath = Join-Path $repoRoot `
    "examples\expected\396-selfhost-llvm-owned-try-parallel-cleanup.stdout.llvm.linux.execute.txt"
$ownedExpected = ([System.IO.File]::ReadAllText($ownedExpectedPath)).TrimEnd("`r", "`n")
if ($ownedActual -ne $ownedExpected) {
    throw "Owned tryParallel execution mismatch.`nEXPECTED:`n$ownedExpected`nACTUAL:`n$ownedActual"
}
Write-Host "[linux 6/6] PASS owned Result payloads are leak- and double-free-clean"
