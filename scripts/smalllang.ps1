param(
    [string]$Source = "examples/01-function-basic-hello.sl",
    [string]$Output,
    [ValidateSet("windows-x64", "linux-x64", "wasm32-browser")]
    [string]$Target = "windows-x64",
    [switch]$KeepTemps
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceName = [System.IO.Path]::GetFileNameWithoutExtension($Source)
if ([string]::IsNullOrWhiteSpace($Output)) {
    $Output = switch ($Target) {
        "windows-x64" { "artifacts/$sourceName.exe" }
        "linux-x64" { "artifacts/$sourceName" }
        "wasm32-browser" { "artifacts/$sourceName.wasm" }
    }
}

$llvmVersion = "22.1.8"
$llvmDir = Join-Path $repoRoot ".tools\llvm-$llvmVersion"
$clang = Join-Path $llvmDir "bin\clang.exe"

if (-not (Test-Path $clang)) {
    $toolsDir = Join-Path $repoRoot ".tools"
    New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null

    $archiveName = "clang+llvm-$llvmVersion-x86_64-pc-windows-msvc.tar.xz"
    $archivePath = Join-Path $toolsDir $archiveName
    $url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-$llvmVersion/clang%2Bllvm-$llvmVersion-x86_64-pc-windows-msvc.tar.xz"

    if (-not (Test-Path $archivePath)) {
        Write-Host "Downloading LLVM $llvmVersion..."
        Invoke-WebRequest -Uri $url -OutFile $archivePath -Headers @{ "User-Agent" = "SmallLang-bootstrap" }
    }

    $extractTemp = Join-Path $toolsDir "llvm-$llvmVersion.extracting"
    if (Test-Path $extractTemp) {
        Remove-Item -LiteralPath $extractTemp -Recurse -Force
    }

    New-Item -ItemType Directory -Force -Path $extractTemp | Out-Null
    Write-Host "Extracting LLVM $llvmVersion..."
    tar -xf $archivePath -C $extractTemp --strip-components 1

    if (Test-Path $llvmDir) {
        Remove-Item -LiteralPath $llvmDir -Recurse -Force
    }

    Move-Item -LiteralPath $extractTemp -Destination $llvmDir
}

$env:SLANG_LLVM_HOME = $llvmDir

dotnet build (Join-Path $repoRoot "src\SmallLang.Compiler\SmallLang.Compiler.csproj") -c Release --nologo
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$compilerArgs = @(
    "build",
    (Join-Path $repoRoot $Source),
    "-o",
    (Join-Path $repoRoot $Output),
    "--target",
    $Target,
    "--llvm",
    $llvmDir
)

if ($KeepTemps) {
    $compilerArgs += "--keep-temps"
}

dotnet run --project (Join-Path $repoRoot "src\SmallLang.Compiler\SmallLang.Compiler.csproj") -c Release --no-build -- @compilerArgs
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
