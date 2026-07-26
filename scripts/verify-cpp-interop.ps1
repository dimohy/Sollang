[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$compilerProject = Join-Path $repoRoot "src\Sollang.Compiler\Sollang.Compiler.csproj"
$compiler = Join-Path $repoRoot "src\Sollang.Compiler\bin\Release\net11.0\Sollang.Compiler.dll"
$llvmHome = Join-Path $repoRoot ".tools\llvm-22.1.8"
$header = Join-Path $repoRoot "tests\cpp-interop\cpp_fixture.hpp"
$throwingHeader = Join-Path $repoRoot "tests\cpp-interop\throwing_fixture.hpp"
$consumer = Join-Path $repoRoot "tests\cpp-interop\consumer.slg"
$handleFixture = Join-Path $repoRoot "tests\cpp-interop\handle_fixture.cpp"
$handleConsumer = Join-Path $repoRoot "tests\cpp-interop\handle_consumer.slg"
$handleForgery = Join-Path $repoRoot "tests\cpp-interop\handle_forgery.slg"
$expected = ([System.IO.File]::ReadAllText(
    (Join-Path $repoRoot "tests\cpp-interop\expected.stdout.txt"))).Replace("`r`n", "`n").TrimEnd("`n")
$outputDirectory = Join-Path $repoRoot "artifacts\cpp-interop\windows-x64"
$linuxOutputDirectory = Join-Path $repoRoot "artifacts\cpp-interop\linux-x64"

function Convert-ToWslPath {
    param([Parameter(Mandatory)][string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $drive = [char]::ToLowerInvariant($fullPath[0])
    return "/mnt/$drive/" + $fullPath.Substring(3).Replace("\", "/")
}

dotnet build $compilerProject -c Release --nologo
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

dotnet $compiler bind-cpp $header `
    --module cppFixture `
    --library cppFixture_shim `
    --output $outputDirectory `
    --target windows-x64 `
    --llvm $llvmHome `
    --build
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$generatedSource = Join-Path $outputDirectory "cppFixture.slg"
$executable = Join-Path $outputDirectory "cpp-consumer.exe"
dotnet $compiler build $generatedSource $consumer `
    -o $executable `
    --target windows-x64 `
    --llvm $llvmHome `
    -O2
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$actual = (& $executable | Out-String).Replace("`r`n", "`n").TrimEnd("`n")
if ($LASTEXITCODE -ne 0) {
    throw "generated C++ binding consumer failed"
}
if ($actual -ne $expected) {
    throw "generated C++ binding output mismatch: expected '$expected', actual '$actual'"
}

$handleOutputDirectory = Join-Path $repoRoot "artifacts\cpp-interop\handle-windows-x64"
New-Item -ItemType Directory -Force -Path $handleOutputDirectory | Out-Null
$handleWindowsLibrary = Join-Path $handleOutputDirectory "handle_fixture.dll"
& (Join-Path $llvmHome "bin\clang.exe") -x c++ -std=c++20 -shared -O2 `
    $handleFixture -o $handleWindowsLibrary
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$handleWindowsSource = Join-Path $handleOutputDirectory "handle_consumer.slg"
Copy-Item -LiteralPath $handleConsumer -Destination $handleWindowsSource -Force
$handleWindowsExecutable = Join-Path $handleOutputDirectory "handle-consumer.exe"
dotnet $compiler build $handleWindowsSource `
    -o $handleWindowsExecutable `
    --target windows-x64 `
    --llvm $llvmHome `
    -O2 `
    --keep-temps
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$handleActual = (& $handleWindowsExecutable | Out-String).Replace("`r`n", "`n").TrimEnd("`n")
if ($LASTEXITCODE -ne 0 -or $handleActual -ne "50,1") {
    throw "affine Windows C++ handle failed: '$handleActual'"
}
$handleLlvmPath = Get-ChildItem `
    ([System.IO.Path]::ChangeExtension($handleWindowsExecutable, ".slg-tmp")) `
    -Filter "*.ll" | Select-Object -ExpandProperty FullName -First 1
$handleLlvm = [System.IO.File]::ReadAllText($handleLlvmPath)
$exerciseStart = $handleLlvm.IndexOf(
    "define internal i32 @sollang_fn_exercise",
    [StringComparison]::Ordinal)
$exerciseEnd = $handleLlvm.IndexOf(
    "`n}",
    $exerciseStart,
    [StringComparison]::Ordinal)
$exerciseLlvm = $handleLlvm.Substring($exerciseStart, $exerciseEnd - $exerciseStart)
if ($exerciseLlvm.Contains("@sollang_alloc", [StringComparison]::Ordinal) -or
    ([regex]::Matches($exerciseLlvm, "call void @sollang_drop_")).Count -ne 1) {
    throw "affine handle steady-state allocation/drop contract regressed"
}
$handleForgeryError = Join-Path $handleOutputDirectory "forgery.stderr.txt"
dotnet $compiler build $handleForgery `
    -o (Join-Path $handleOutputDirectory "forgery.exe") `
    --target windows-x64 `
    --llvm $llvmHome 2> $handleForgeryError
if ($LASTEXITCODE -eq 0) {
    throw "opaque native handle could be forged with a struct literal"
}
$handleForgeryDiagnostic = [System.IO.File]::ReadAllText($handleForgeryError)
if (-not $handleForgeryDiagnostic.Contains(
        "can only be created by its native constructor",
        [StringComparison]::Ordinal)) {
    throw "opaque native handle forgery produced the wrong diagnostic: $handleForgeryDiagnostic"
}

$manifestPath = Join-Path $outputDirectory "cppFixture.windows-x64.cppbind.json"
$firstManifest = [System.IO.File]::ReadAllBytes($manifestPath)
dotnet $compiler bind-cpp $header `
    --module cppFixture `
    --library cppFixture_shim `
    --output $outputDirectory `
    --target windows-x64 `
    --llvm $llvmHome
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$secondManifest = [System.IO.File]::ReadAllBytes($manifestPath)
if (-not [System.Linq.Enumerable]::SequenceEqual[byte]($firstManifest, $secondManifest)) {
    throw "C++ binding manifest is not deterministic"
}

$compileDatabaseDirectory = Join-Path $repoRoot "artifacts\cpp-interop\compilation-database"
New-Item -ItemType Directory -Force -Path $compileDatabaseDirectory | Out-Null
$compileDatabase = @(
    @{
        directory = $repoRoot
        file = $header
        arguments = @("clang++", "-DSOLLANG_CPP_BIND_TEST=1", "-c", $header, "-o", "ignored.o")
    }
) | ConvertTo-Json -Depth 4 -AsArray
[System.IO.File]::WriteAllText(
    (Join-Path $compileDatabaseDirectory "compile_commands.json"),
    $compileDatabase)
$databaseOutput = Join-Path $repoRoot "artifacts\cpp-interop\database-test"
dotnet $compiler bind-cpp $header `
    --module cppFixture `
    --output $databaseOutput `
    --target windows-x64 `
    --llvm $llvmHome `
    --compile-commands $compileDatabaseDirectory
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$databaseManifest = [System.IO.File]::ReadAllText(
    (Join-Path $databaseOutput "cppFixture.windows-x64.cppbind.json"))
if (-not $databaseManifest.Contains("-DSOLLANG_CPP_BIND_TEST=1", [StringComparison]::Ordinal)) {
    throw "compile_commands.json arguments were not preserved"
}

$diagnosticOutput = Join-Path $repoRoot "artifacts\cpp-interop\diagnostic-test"
$diagnosticError = Join-Path $repoRoot "artifacts\cpp-interop\diagnostic.stderr.txt"
dotnet $compiler bind-cpp $throwingHeader `
    --module throwingFixture `
    --output $diagnosticOutput `
    --target windows-x64 `
    --llvm $llvmHome 2> $diagnosticError
if ($LASTEXITCODE -eq 0) {
    throw "potentially throwing C++ function unexpectedly generated a binding"
}
$diagnostic = [System.IO.File]::ReadAllText($diagnosticError)
if (-not $diagnostic.Contains(
        "functions must be declared noexcept so no C++ exception can cross the C ABI",
        [StringComparison]::Ordinal)) {
    throw "potentially throwing C++ function produced the wrong diagnostic: $diagnostic"
}

dotnet $compiler bind-cpp $header `
    --module cppFixture `
    --library cppFixture_shim `
    --output $linuxOutputDirectory `
    --target linux-x64 `
    --llvm $llvmHome
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$linuxShim = Join-Path $linuxOutputDirectory "cppFixture_shim.cpp"
$linuxLibrary = Join-Path $linuxOutputDirectory "libcppFixture_shim.so"
$wslShim = Convert-ToWslPath $linuxShim
$wslLibrary = Convert-ToWslPath $linuxLibrary
& wsl.exe --exec c++ -std=c++20 -shared -fPIC -O2 $wslShim -o $wslLibrary
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$linuxGeneratedSource = Join-Path $linuxOutputDirectory "cppFixture.slg"
$linuxExecutable = Join-Path $linuxOutputDirectory "cpp-consumer"
dotnet $compiler build $linuxGeneratedSource $consumer `
    -o $linuxExecutable `
    --target linux-x64 `
    --llvm $llvmHome `
    -O2
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$wslExecutable = Convert-ToWslPath $linuxExecutable
$wslOutputDirectory = Convert-ToWslPath $linuxOutputDirectory
$actual = (& wsl.exe --exec env "LD_LIBRARY_PATH=$wslOutputDirectory" $wslExecutable |
    Out-String).Replace("`r`n", "`n").TrimEnd("`n")
if ($LASTEXITCODE -ne 0) {
    throw "generated Linux C++ binding consumer failed"
}
if ($actual -ne $expected) {
    throw "generated Linux C++ binding output mismatch: expected '$expected', actual '$actual'"
}

$handleLinuxOutputDirectory = Join-Path $repoRoot "artifacts\cpp-interop\handle-linux-x64"
New-Item -ItemType Directory -Force -Path $handleLinuxOutputDirectory | Out-Null
$handleLinuxLibrary = Join-Path $handleLinuxOutputDirectory "libhandle_fixture.so"
$wslHandleFixture = Convert-ToWslPath $handleFixture
$wslHandleLinuxLibrary = Convert-ToWslPath $handleLinuxLibrary
& wsl.exe --exec c++ -std=c++20 -shared -fPIC -O2 `
    $wslHandleFixture -o $wslHandleLinuxLibrary
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$handleLinuxSource = Join-Path $handleLinuxOutputDirectory "handle_consumer.slg"
Copy-Item -LiteralPath $handleConsumer -Destination $handleLinuxSource -Force
$handleLinuxExecutable = Join-Path $handleLinuxOutputDirectory "handle-consumer"
dotnet $compiler build $handleLinuxSource `
    -o $handleLinuxExecutable `
    --target linux-x64 `
    --llvm $llvmHome `
    -O2
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$wslHandleLinuxDirectory = Convert-ToWslPath $handleLinuxOutputDirectory
$wslHandleLinuxExecutable = Convert-ToWslPath $handleLinuxExecutable
$handleActual = (& wsl.exe --exec env `
    "LD_LIBRARY_PATH=$wslHandleLinuxDirectory" $wslHandleLinuxExecutable |
    Out-String).Replace("`r`n", "`n").TrimEnd("`n")
if ($LASTEXITCODE -ne 0 -or $handleActual -ne "50,1") {
    throw "affine Linux C++ handle failed: '$handleActual'"
}

Write-Host "PASS C++ interop: Windows/Linux, affine handle RAII, zero wrapper allocation, libclang AST, compile database, exception rejection, C shim, overloads, deterministic manifest"
