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
$referenceNames = @(
    "448-owned-dictionary-indexed-replacement",
    "450-owned-dictionary-put-transfer"
)
$selfHostName = "449-selfhost-llvm-owned-dictionary-indexed-replacement"

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

Write-Host "[owned-dictionary 1/4] Verify reference and self-host behavior on Linux."
& dotnet run --project $runnerProject -c Release --no-build -- `
    --exact $referenceNames[0] `
    --exact $selfHostName `
    --exact $referenceNames[1] `
    --target linux-x64 `
    --jobs 3
if ($LASTEXITCODE -ne 0) {
    throw "Owned dictionary replacement examples failed"
}
Write-Host "[owned-dictionary 1/4] PASS Linux reference and self-host execution"

Write-Host "[owned-dictionary 2/4] Emit reference LLVM modules."
$modules = @()
foreach ($name in $referenceNames) {
    $output = Join-Path $artifactsDir "$name-asan"
    & dotnet run --project $compilerProject -c Release --no-build -- build `
        (Join-Path $repoRoot "examples\$name.slg") `
        -o $output `
        --target linux-x64 `
        --llvm $llvmDir `
        -O0 `
        --keep-temps
    if ($LASTEXITCODE -ne 0) {
        throw "Reference owned dictionary LLVM emission failed: $name"
    }
    $modules += [pscustomobject]@{
        Name = $name
        Llvm = [System.IO.Path]::ChangeExtension($output, ".ll")
        Expected = Join-Path $repoRoot "examples\expected\$name.stdout.txt"
    }
}
$modules += [pscustomobject]@{
    Name = $selfHostName
    Llvm = Join-Path $linuxArtifactsDir "$selfHostName.stdout.ll"
    Expected = Join-Path $repoRoot "examples\expected\$selfHostName.stdout.llvm.linux.execute.txt"
}
Write-Host "[owned-dictionary 2/4] PASS reference LLVM emission"

Write-Host "[owned-dictionary 3/4] Instrument all LLVM modules with sanitizers."
foreach ($module in $modules) {
    $objectPath = Join-Path $artifactsDir "$($module.Name).asan.o"
    & $clangPath "--target=x86_64-unknown-linux-gnu" -c $module.Llvm -O1 -g `
        "-fsanitize=address,undefined" -fno-omit-frame-pointer -o $objectPath
    if ($LASTEXITCODE -ne 0) {
        throw "Sanitizer instrumentation failed: $($module.Name)"
    }
    Invoke-Wsl @(
        "gcc",
        (Convert-ToWslPath $objectPath),
        "-fsanitize=address,undefined",
        "-o",
        "/tmp/$($module.Name)-asan"
    ) | Out-Null
}
Write-Host "[owned-dictionary 3/4] PASS instrumented executables"

Write-Host "[owned-dictionary 4/4] Execute with leak, double-free, and UB detection."
foreach ($module in $modules) {
    $actual = Invoke-Wsl @(
        "env",
        "ASAN_OPTIONS=detect_leaks=1:halt_on_error=1:exitcode=97",
        "UBSAN_OPTIONS=halt_on_error=1:exitcode=98",
        "/tmp/$($module.Name)-asan"
    )
    $expected = ([System.IO.File]::ReadAllText($module.Expected)).TrimEnd("`r", "`n")
    if ($actual -ne $expected) {
        throw "Owned dictionary replacement mismatch for $($module.Name).`nEXPECTED:`n$expected`nACTUAL:`n$actual"
    }
}
Write-Host "[owned-dictionary 4/4] PASS replacement paths are leak-, double-free-, and UB-clean"
