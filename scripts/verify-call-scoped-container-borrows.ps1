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
$referenceName = "456-owned-dictionary-value-call-borrow"
$selfHostName = "457-selfhost-llvm-owned-dictionary-value-call-borrow"

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

Write-Host "[call-borrow 1/4] Verify reference and self-host behavior on Linux."
& dotnet run --project $runnerProject -c Release --no-build -- `
    --exact $referenceName `
    --exact $selfHostName `
    --target linux-x64 `
    --skip-bootstrap `
    --jobs 2
if ($LASTEXITCODE -ne 0) {
    throw "Call-scoped container borrow examples failed"
}
Write-Host "[call-borrow 1/4] PASS Linux reference and self-host execution"

Write-Host "[call-borrow 2/4] Emit reference LLVM and collect self-host LLVM."
$referenceOutput = Join-Path $artifactsDir "$referenceName-asan"
& dotnet run --project $compilerProject -c Release --no-build -- build `
    (Join-Path $repoRoot "examples\$referenceName.slg") `
    -o $referenceOutput `
    --target linux-x64 `
    --llvm $llvmDir `
    -O0 `
    --keep-temps
if ($LASTEXITCODE -ne 0) {
    throw "Reference call-scoped borrow LLVM emission failed"
}
$modules = @(
    [pscustomobject]@{
        Name = $referenceName
        Llvm = [System.IO.Path]::ChangeExtension($referenceOutput, ".ll")
        Expected = Join-Path $repoRoot "examples\expected\$referenceName.stdout.txt"
    },
    [pscustomobject]@{
        Name = $selfHostName
        Llvm = Join-Path $linuxArtifactsDir "$selfHostName.stdout.ll"
        Expected = Join-Path $repoRoot "examples\expected\$selfHostName.stdout.llvm.linux.execute.txt"
    }
)
Write-Host "[call-borrow 2/4] PASS LLVM modules collected"

Write-Host "[call-borrow 3/4] Instrument both modules with ASan and UBSan."
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
Write-Host "[call-borrow 3/4] PASS instrumented executables"

Write-Host "[call-borrow 4/4] Detect leaks, double-free, use-after-free, and UB."
foreach ($module in $modules) {
    $actual = Invoke-Wsl @(
        "env",
        "ASAN_OPTIONS=detect_leaks=1:halt_on_error=1:exitcode=97",
        "UBSAN_OPTIONS=halt_on_error=1:exitcode=98",
        "/tmp/$($module.Name)-asan"
    )
    $expected = ([System.IO.File]::ReadAllText($module.Expected)).TrimEnd("`r", "`n")
    $normalizedActual = $actual.Replace("`r`n", "`n")
    $normalizedExpected = $expected.Replace("`r`n", "`n")
    if ($normalizedActual -ne $normalizedExpected) {
        throw "Call-scoped container borrow mismatch for $($module.Name).`nEXPECTED:`n$expected`nACTUAL:`n$actual"
    }
}
Write-Host "[call-borrow 4/4] PASS call-scoped indexed borrows are sanitizer-clean"
