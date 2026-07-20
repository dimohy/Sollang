param(
    [string]$Distribution = "Ubuntu"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactsDir = Join-Path $repoRoot "artifacts\example-tests"
$linuxArtifactsDir = Join-Path $artifactsDir "linux-x64"
$compilerProject = Join-Path $repoRoot "src\Sollang.Compiler\Sollang.Compiler.csproj"
$runnerProject = Join-Path $repoRoot "tests\Sollang.ExampleTests\Sollang.ExampleTests.csproj"
$llvmDir = Join-Path $repoRoot ".tools\llvm-22.1.8"
$clangPath = Join-Path $llvmDir "bin\clang.exe"
$referenceName = "446-owned-indexed-replacement"
$selfHostName = "447-selfhost-llvm-owned-indexed-replacement"

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

New-Item -ItemType Directory -Force -Path $artifactsDir | Out-Null

Write-Host "[owned-replace 1/4] Verify reference and self-host behavior on Linux."
& dotnet run --project $runnerProject -c Release --no-build -- `
    --exact $referenceName `
    --exact $selfHostName `
    --target linux-x64 `
    --jobs 2
if ($LASTEXITCODE -ne 0) {
    throw "Owned indexed replacement examples failed"
}
Write-Host "[owned-replace 1/4] PASS Linux reference and self-host execution"

Write-Host "[owned-replace 2/4] Emit the reference LLVM module."
$referenceOutput = Join-Path $artifactsDir "$referenceName-asan"
& dotnet run --project $compilerProject -c Release --no-build -- build `
    (Join-Path $repoRoot "examples\$referenceName.slg") `
    -o $referenceOutput `
    --target linux-x64 `
    --llvm $llvmDir `
    -O0 `
    --keep-temps
if ($LASTEXITCODE -ne 0) {
    throw "Reference owned indexed replacement LLVM emission failed"
}
Write-Host "[owned-replace 2/4] PASS reference LLVM emission"

Write-Host "[owned-replace 3/4] Instrument reference and self-host LLVM with sanitizers."
$referenceLlvmPath = [System.IO.Path]::ChangeExtension($referenceOutput, ".ll")
$selfHostLlvmPath = Join-Path $linuxArtifactsDir "$selfHostName.stdout.ll"
$modules = @(
    @($referenceName, $referenceLlvmPath),
    @($selfHostName, $selfHostLlvmPath)
)
foreach ($module in $modules) {
    $name = $module[0]
    $llvmPath = $module[1]
    $objectPath = Join-Path $artifactsDir "$name.asan.o"
    & $clangPath "--target=x86_64-unknown-linux-gnu" -c $llvmPath -O1 -g `
        "-fsanitize=address,undefined" -fno-omit-frame-pointer -o $objectPath
    if ($LASTEXITCODE -ne 0) {
        throw "Sanitizer instrumentation failed: $name"
    }
    Invoke-Wsl @(
        "gcc",
        (Convert-ToWslPath $objectPath),
        "-fsanitize=address,undefined",
        "-o",
        "/tmp/$name-asan"
    ) | Out-Null
}
Write-Host "[owned-replace 3/4] PASS instrumented executables"

Write-Host "[owned-replace 4/4] Execute with leak, double-free, and UB detection."
foreach ($module in $modules) {
    $name = $module[0]
    $actual = Invoke-Wsl @(
        "env",
        "ASAN_OPTIONS=detect_leaks=1:halt_on_error=1:exitcode=97",
        "UBSAN_OPTIONS=halt_on_error=1:exitcode=98",
        "/tmp/$name-asan"
    )
    $expectedPath = if ($name -eq $referenceName) {
        Join-Path $repoRoot "examples\expected\$name.stdout.txt"
    } else {
        Join-Path $repoRoot "examples\expected\$name.stdout.llvm.linux.execute.txt"
    }
    $expected = ([System.IO.File]::ReadAllText($expectedPath)).TrimEnd("`r", "`n")
    if ($actual -ne $expected) {
        throw "Owned indexed replacement mismatch for $name.`nEXPECTED:`n$expected`nACTUAL:`n$actual"
    }
}
Write-Host "[owned-replace 4/4] PASS replacement owners are leak-, double-free-, and UB-clean"
