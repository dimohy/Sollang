param(
    [string]$Distribution = "Ubuntu"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactsDir = Join-Path $repoRoot "artifacts\example-tests"
$runnerProject = Join-Path $repoRoot "tests\Sollang.ExampleTests\Sollang.ExampleTests.csproj"
$llvmDir = Join-Path $repoRoot ".tools\llvm-22.1.8"
$clangPath = Join-Path $llvmDir "bin\clang.exe"
$name = "400-selfhost-llvm-recursive-container-drop"
$llvmPath = Join-Path $artifactsDir "$name.stdout.ll"
$objectPath = Join-Path $artifactsDir "$name.asan.o"
$expectedPath = Join-Path $repoRoot "examples\expected\$name.stdout.llvm.linux.execute.txt"

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

Write-Host "[recursive-drop 1/3] Emit and validate recursive container drop LLVM."
& dotnet run --project $runnerProject -c Release --no-build -- `
    --exact $name `
    --jobs 1
if ($LASTEXITCODE -ne 0) {
    throw "Recursive container drop example failed"
}
Write-Host "[recursive-drop 1/3] PASS LLVM snapshot and assembly"

Write-Host "[recursive-drop 2/3] Instrument the Linux object with AddressSanitizer."
& $clangPath --target=x86_64-unknown-linux-gnu -c $llvmPath -O0 `
    -fsanitize=address -fno-omit-frame-pointer -o $objectPath
if ($LASTEXITCODE -ne 0) {
    throw "Recursive container drop AddressSanitizer instrumentation failed"
}
$wslObject = Convert-ToWslPath $objectPath
$wslExecutable = "/tmp/sollang-recursive-container-drop-asan"
Invoke-Wsl @(
    "gcc",
    $wslObject,
    "-fsanitize=address",
    "-o",
    $wslExecutable
) | Out-Null
Write-Host "[recursive-drop 2/3] PASS instrumented Linux executable"

Write-Host "[recursive-drop 3/3] Execute with leak and double-free detection."
$actual = Invoke-Wsl @(
    "env",
    "ASAN_OPTIONS=detect_leaks=1:halt_on_error=1:exitcode=97",
    $wslExecutable
)
$expected = ([System.IO.File]::ReadAllText($expectedPath)).TrimEnd("`r", "`n")
if ($actual -ne $expected) {
    throw "Recursive container drop execution mismatch.`nEXPECTED:`n$expected`nACTUAL:`n$actual"
}
Write-Host "[recursive-drop 3/3] PASS recursive owned elements are leak- and double-free-clean"
