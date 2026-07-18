param(
    [string]$Source = "examples/01-function-basic-hello.slg",
    [string]$SourcesFile,
    [string]$Output,
    [ValidateSet("windows-x64", "linux-x64", "wasm32-browser")]
    [string]$Target = "windows-x64",
    [switch]$KeepTemps
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$sources = if ([string]::IsNullOrWhiteSpace($SourcesFile)) {
    @($Source)
} else {
    Get-Content (Join-Path $repoRoot $SourcesFile) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.Trim() }
}
if ($sources.Count -eq 0) {
    throw "source list is empty"
}
$sourceName = [System.IO.Path]::GetFileNameWithoutExtension($sources[0])
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
        Invoke-WebRequest -Uri $url -OutFile $archivePath -Headers @{ "User-Agent" = "Sollang-bootstrap" }
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

$env:SOLLANG_LLVM_HOME = $llvmDir

dotnet build (Join-Path $repoRoot "src\Sollang.Compiler\Sollang.Compiler.csproj") -c Release --nologo
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$compilerArgs = @("build")
foreach ($sourcePath in $sources) {
    $compilerArgs += (Join-Path $repoRoot $sourcePath)
}
$compilerArgs += @(
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

dotnet run --project (Join-Path $repoRoot "src\Sollang.Compiler\Sollang.Compiler.csproj") -c Release --no-build -- @compilerArgs
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
