[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $repoRoot "src\Sollang.Compiler\bin\Release\net11.0\Sollang.Compiler.dll"
$source = Join-Path $repoRoot "tests\native-interop\sollang_fixture.slg"
$consumer = Join-Path $repoRoot "tests\native-interop\sollang_consumer.slg"
$expectedPath = Join-Path $repoRoot "tests\native-interop\sollang_consumer.stdout.txt"
$outputRoot = Join-Path $repoRoot "artifacts\native-interop"
$llvmHome = Join-Path $repoRoot ".tools\llvm-22.1.8"
$selfHostCompiler = Join-Path $repoRoot "artifacts\example-tests\selfhost-sollangc-driver.exe"
$selfHostManifest = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-sollangc-driver.sources.txt"
$exampleRunner = Join-Path $repoRoot "tests\Sollang.ExampleTests\Sollang.ExampleTests.csproj"
$expected = ([System.IO.File]::ReadAllText($expectedPath)).Replace("`r`n", "`n").TrimEnd("`n")

New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

function Convert-ToWslPath {
    param([Parameter(Mandatory)][string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $drive = [char]::ToLowerInvariant($fullPath[0])
    return "/mnt/$drive/" + $fullPath.Substring(3).Replace("\", "/")
}

function Assert-Output {
    param(
        [Parameter(Mandatory)][string]$Executable,
        [switch]$Linux
    )

    if ($Linux) {
        $linuxRepo = Convert-ToWslPath $repoRoot
        $linuxExecutable = Convert-ToWslPath $Executable
        $actual = (& wsl.exe --exec sh -lc "cd '$linuxRepo' && '$linuxExecutable'" | Out-String)
    } else {
        $actual = (& $Executable | Out-String)
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Sollang library consumer failed: $Executable"
    }
    $normalized = $actual.Replace("`r`n", "`n").TrimEnd("`n")
    if ($normalized -ne $expected) {
        throw "Sollang library output mismatch: expected '$expected', actual '$normalized'"
    }
}

function Assert-CompileFailure {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Expected
    )

    $failureOutput = Join-Path $outputRoot "invalid-library.dll"
    $diagnostic = (& dotnet $compiler build $Source --library --target windows-x64 `
        --llvm $llvmHome -O2 -o $failureOutput 2>&1 | Out-String)
    if ($LASTEXITCODE -eq 0) {
        throw "Expected Sollang library compilation to fail: $Source"
    }
    if (-not $diagnostic.Contains($Expected, [StringComparison]::Ordinal)) {
        throw "Expected diagnostic '$Expected', actual: $diagnostic"
    }
}

function Ensure-SelfHostCompiler {
    $rebuild = -not (Test-Path -LiteralPath $selfHostCompiler)
    if (-not $rebuild) {
        $compilerTime = (Get-Item -LiteralPath $selfHostCompiler).LastWriteTimeUtc
        foreach ($relative in Get-Content -LiteralPath $selfHostManifest) {
            if ([string]::IsNullOrWhiteSpace($relative)) { continue }
            $input = Join-Path $repoRoot $relative.Trim()
            if ((Get-Item -LiteralPath $input).LastWriteTimeUtc -gt $compilerTime) {
                $rebuild = $true
                break
            }
        }
    }
    if ($rebuild) {
        & dotnet run --project $exampleRunner -c Release --no-build -- `
            --exact 365-selfhost-llvm-stage2-single-smoke
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to build the current self-host compiler."
        }
    }
}

function Invoke-SelfHostLibraryConsumer {
    param(
        [Parameter(Mandatory)][ValidateSet("windows", "linux")][string]$Target,
        [Parameter(Mandatory)][string]$OutputStem
    )

    $llvmPath = "$OutputStem.ll"
    $errorPath = "$OutputStem.err"
    Remove-Item -LiteralPath $llvmPath, $errorPath -ErrorAction SilentlyContinue
    $process = Start-Process `
        -FilePath $selfHostCompiler `
        -ArgumentList @($Target, [System.IO.Path]::GetFullPath($consumer)) `
        -RedirectStandardOutput $llvmPath `
        -RedirectStandardError $errorPath `
        -PassThru `
        -WindowStyle Hidden
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
        $details = if (Test-Path $errorPath) { Get-Content -Raw $errorPath } else { "" }
        throw "Self-host $Target library consumer emission failed.`n$details"
    }

    $selfHostIr = [System.IO.File]::ReadAllText($llvmPath)
    if ($selfHostIr -notmatch 'call i64 %native_target_[0-9]+\(i64 6, i64 7\)') {
        throw "Self-host fixture.multiply(6, 7) did not infer direct Int64 constants."
    }
    if ($selfHostIr -notmatch 'call double %native_target_[0-9]+\(double 3\.0, double 4\.0\)') {
        throw "Self-host fixture.hypotSquared(3, 4) did not infer direct Float64 constants."
    }
    if ($selfHostIr -match 'sollang_library_call_wrapper|malloc.*native_target|HeapAlloc.*native_target') {
        throw "Self-host library call introduced a runtime allocation wrapper."
    }

    if ($Target -eq "windows") {
        $executable = "$OutputStem.exe"
        & (Join-Path $llvmHome "bin\clang.exe") $llvmPath -O1 -Wno-override-module -o $executable
        if ($LASTEXITCODE -ne 0) { throw "Self-host Windows library consumer link failed." }
        Assert-Output $executable
    } else {
        $objectPath = "$OutputStem.o"
        & (Join-Path $llvmHome "bin\clang.exe") `
            -target x86_64-unknown-linux-gnu -O1 -c $llvmPath -o $objectPath
        if ($LASTEXITCODE -ne 0) { throw "Self-host Linux library consumer compile failed." }
        $linuxRepo = Convert-ToWslPath $repoRoot
        $linuxObject = Convert-ToWslPath $objectPath
        $linuxExecutable = Convert-ToWslPath $OutputStem
        & wsl.exe --exec sh -lc `
            "cd '$linuxRepo' && cc '$linuxObject' -ldl -pthread -o '$linuxExecutable'"
        if ($LASTEXITCODE -ne 0) { throw "Self-host Linux library consumer link failed." }
        Assert-Output $OutputStem -Linux
    }
}

function Assert-SelfHostCompileFailure {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Expected
    )

    $outputPath = Join-Path $outputRoot "selfhost-invalid-library.ll"
    $errorPath = Join-Path $outputRoot "selfhost-invalid-library.err"
    Remove-Item -LiteralPath $outputPath, $errorPath -ErrorAction SilentlyContinue
    $process = Start-Process `
        -FilePath $selfHostCompiler `
        -ArgumentList @("windows", [System.IO.Path]::GetFullPath($Source)) `
        -RedirectStandardOutput $outputPath `
        -RedirectStandardError $errorPath `
        -PassThru `
        -WindowStyle Hidden
    $process.WaitForExit()
    if ($process.ExitCode -eq 0) {
        throw "Expected self-host library compilation to fail: $Source"
    }
    $diagnostic = ""
    if (Test-Path $outputPath) { $diagnostic += Get-Content -Raw $outputPath }
    if (Test-Path $errorPath) { $diagnostic += Get-Content -Raw $errorPath }
    if (-not $diagnostic.Contains($Expected, [StringComparison]::Ordinal)) {
        throw "Expected self-host diagnostic '$Expected', actual: $diagnostic"
    }
}

Ensure-SelfHostCompiler
Assert-SelfHostCompileFailure `
    (Join-Path $repoRoot "tests\library-interop\invalid_export.slg") `
    "unresolved library export"
Assert-SelfHostCompileFailure `
    (Join-Path $repoRoot "tests\library-interop\invalid_arity.slg") `
    "invalid library call code 2"
$windowsLibrary = Join-Path $outputRoot "sollang_fixture.dll"
$windowsConsumer = Join-Path $outputRoot "sollang-library-consumer-windows.exe"
dotnet $compiler build $source --library --target windows-x64 --llvm $llvmHome -O2 -o $windowsLibrary
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$windowsManifestPath = Join-Path $outputRoot "sollang_fixture.windows-x64.slglib.json"
$windowsInterfaceCache = Join-Path $outputRoot `
    ".sollang-cache\sollang_fixture.windows-x64.o2-library.product.slglib.json"
Remove-Item -LiteralPath $windowsManifestPath
$restoreLog = (& dotnet $compiler build $source --library --target windows-x64 `
    --llvm $llvmHome -O2 -o $windowsLibrary | Out-String)
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $windowsManifestPath)) {
    throw "Exact library build did not restore its output interface."
}
if (-not $restoreLog.Contains("[product-cache] exact hit", [StringComparison]::Ordinal)) {
    throw "Restored library interface did not preserve the exact product-cache hit."
}
Remove-Item -LiteralPath $windowsInterfaceCache
$recoveryLog = (& dotnet $compiler build $source --library --target windows-x64 `
    --llvm $llvmHome -O2 -o $windowsLibrary | Out-String)
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $windowsInterfaceCache)) {
    throw "Missing cached library interface was not regenerated."
}
if (-not $recoveryLog.Contains(
        "cached Sollang library interface is missing",
        [StringComparison]::Ordinal)) {
    throw "Missing cached library interface did not produce an explicit cache miss."
}
dotnet $compiler build $consumer --target windows-x64 --llvm $llvmHome -O2 --keep-temps -o $windowsConsumer
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Assert-Output $windowsConsumer
Invoke-SelfHostLibraryConsumer `
    -Target windows `
    -OutputStem (Join-Path $outputRoot "selfhost-sollang-library-consumer-windows")

$windowsManifest = Get-Content -Raw $windowsManifestPath | ConvertFrom-Json
if ($windowsManifest.target -ne "windows-x64" -or $windowsManifest.exports.Count -ne 3) {
    throw "Windows Sollang library interface is invalid."
}
$windowsSymbols = @($windowsManifest.exports | ForEach-Object { $_.symbol })
$readObject = Join-Path $llvmHome "bin\llvm-readobj.exe"
$windowsExports = & $readObject --coff-exports $windowsLibrary | Out-String
foreach ($symbol in $windowsSymbols) {
    if (-not $windowsExports.Contains($symbol, [StringComparison]::Ordinal)) {
        throw "Windows Sollang library is missing export '$symbol'"
    }
}

$windowsIr = [System.IO.File]::ReadAllText(
    [System.IO.Path]::ChangeExtension($windowsConsumer, ".ll"))
if ($windowsIr -notmatch 'call i64 %[^(]+\(i64 6, i64 7\)') {
    throw "fixture.multiply(6, 7) was not emitted directly as Int64 constants."
}
if ($windowsIr -notmatch 'call double %[^(]+\(double 3\.0, double 4\.0\)') {
    throw "fixture.hypotSquared(3, 4) was not emitted directly as Float64 constants."
}

$linuxLibrary = Join-Path $outputRoot "libsollang_fixture.so"
$linuxConsumer = Join-Path $outputRoot "sollang-library-consumer-linux"
dotnet $compiler build $source --library --target linux-x64 --llvm $llvmHome -O2 -o $linuxLibrary
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
dotnet $compiler build $consumer --target linux-x64 --llvm $llvmHome -O2 --keep-temps -o $linuxConsumer
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Assert-Output $linuxConsumer -Linux
Invoke-SelfHostLibraryConsumer `
    -Target linux `
    -OutputStem (Join-Path $outputRoot "selfhost-sollang-library-consumer-linux")

$linuxManifestPath = Join-Path $outputRoot "sollang_fixture.linux-x64.slglib.json"
$linuxManifest = Get-Content -Raw $linuxManifestPath | ConvertFrom-Json
if ($linuxManifest.target -ne "linux-x64" -or $linuxManifest.exports.Count -ne 3) {
    throw "Linux Sollang library interface is invalid."
}
$linuxLibraryPath = Convert-ToWslPath $linuxLibrary
$linuxExports = & wsl.exe --exec nm -D --defined-only $linuxLibraryPath | Out-String
foreach ($symbol in @($linuxManifest.exports | ForEach-Object { $_.symbol })) {
    if (-not $linuxExports.Contains($symbol, [StringComparison]::Ordinal)) {
        throw "Linux Sollang library is missing export '$symbol'"
    }
}

Assert-CompileFailure `
    (Join-Path $repoRoot "tests\native-interop\sollang_invalid_int_export.slg") `
    "type 'Int' is not ABI-safe"
Assert-CompileFailure `
    (Join-Path $repoRoot "tests\native-interop\sollang_no_exports.slg") `
    "must declare at least one public function"

Write-Host "Sollang shared-library export verification passed on Windows/Linux."
