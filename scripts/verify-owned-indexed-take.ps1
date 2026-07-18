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
$names = @(
    "403-selfhost-llvm-owned-indexed-take",
    "404-selfhost-llvm-owned-dictionary-take"
)

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

Write-Host "[owned-take 1/4] Emit, assemble, link, and execute both self-host LLVM cases."
foreach ($name in $names) {
    & dotnet run --project $runnerProject -c Release --no-build -- `
        --exact $name `
        --target linux-x64 `
        --skip-bootstrap `
        --jobs 1
    if ($LASTEXITCODE -ne 0) {
        throw "Owned indexed extraction example failed: $name"
    }
}
Write-Host "[owned-take 1/4] PASS self-host array and dictionary execution"

Write-Host "[owned-take 2/4] Emit the C# reference LLVM for the combined owned case."
$referenceName = "401-owned-indexed-take"
$referenceOutput = Join-Path $artifactsDir "$referenceName-asan"
& dotnet run --project $compilerProject -c Release --no-build -- build `
    (Join-Path $repoRoot "examples\$referenceName.slg") `
    -o $referenceOutput `
    --target linux-x64 `
    --llvm $llvmDir `
    -O0 `
    --keep-temps
if ($LASTEXITCODE -ne 0) {
    throw "Reference owned indexed extraction LLVM emission failed"
}
Write-Host "[owned-take 2/4] PASS reference LLVM emission"

Write-Host "[owned-take 3/4] Instrument all Linux modules with AddressSanitizer."
foreach ($name in $names) {
    $llvmPath = Join-Path $artifactsDir "$name.stdout.ll"
    $objectPath = Join-Path $artifactsDir "$name.asan.o"
    & $clangPath --target=x86_64-unknown-linux-gnu -c $llvmPath -O0 `
        -fsanitize=address -fno-omit-frame-pointer -o $objectPath
    if ($LASTEXITCODE -ne 0) {
        throw "AddressSanitizer instrumentation failed: $name"
    }
    Invoke-Wsl @(
        "gcc",
        (Convert-ToWslPath $objectPath),
        "-fsanitize=address",
        "-o",
        "/tmp/$name-asan"
    ) | Out-Null
}
$referenceLlvmPath = [System.IO.Path]::ChangeExtension($referenceOutput, ".ll")
$referenceObjectPath = Join-Path $artifactsDir "$referenceName.asan.o"
& $clangPath --target=x86_64-unknown-linux-gnu -c $referenceLlvmPath -O0 `
    -fsanitize=address -fno-omit-frame-pointer -o $referenceObjectPath
if ($LASTEXITCODE -ne 0) {
    throw "Reference AddressSanitizer instrumentation failed"
}
Invoke-Wsl @(
    "gcc",
    (Convert-ToWslPath $referenceObjectPath),
    "-fsanitize=address",
    "-o",
    "/tmp/$referenceName-asan"
) | Out-Null
Write-Host "[owned-take 3/4] PASS instrumented reference and self-host executables"

Write-Host "[owned-take 4/4] Execute with leak and double-free detection."
foreach ($name in $names) {
    $actual = Invoke-Wsl @(
        "env",
        "ASAN_OPTIONS=detect_leaks=1:halt_on_error=1:exitcode=97",
        "/tmp/$name-asan"
    )
    $expectedPath = Join-Path $repoRoot "examples\expected\$name.stdout.llvm.linux.execute.txt"
    $expected = ([System.IO.File]::ReadAllText($expectedPath)).TrimEnd("`r", "`n")
    if ($actual -ne $expected) {
        throw "Owned indexed extraction mismatch for $name.`nEXPECTED:`n$expected`nACTUAL:`n$actual"
    }
}
$referenceActual = Invoke-Wsl @(
    "env",
    "ASAN_OPTIONS=detect_leaks=1:halt_on_error=1:exitcode=97",
    "/tmp/$referenceName-asan"
)
$referenceExpectedPath = Join-Path $repoRoot "examples\expected\$referenceName.stdout.txt"
$referenceExpected = ([System.IO.File]::ReadAllText($referenceExpectedPath)).TrimEnd("`r", "`n")
if ($referenceActual -ne $referenceExpected) {
    throw "Reference owned indexed extraction mismatch.`nEXPECTED:`n$referenceExpected`nACTUAL:`n$referenceActual"
}
Write-Host "[owned-take 4/4] PASS extracted and remaining owners are leak- and double-free-clean"
