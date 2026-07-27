[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$compilerProject = Join-Path $repoRoot "src\Sollang.Compiler\Sollang.Compiler.csproj"
$compiler = Join-Path $repoRoot "src\Sollang.Compiler\bin\Release\net11.0\Sollang.Compiler.dll"
$selfhostCompiler = Join-Path $repoRoot "artifacts\example-tests\selfhost-sollangc-driver.exe"
$llvmHome = Join-Path $repoRoot ".tools\llvm-22.1.8"
$header = Join-Path $repoRoot "tests\cpp-interop\cpp_fixture.hpp"
$throwingHeader = Join-Path $repoRoot "tests\cpp-interop\throwing_fixture.hpp"
$consumer = Join-Path $repoRoot "tests\cpp-interop\consumer.slg"
$handleFixture = Join-Path $repoRoot "tests\cpp-interop\handle_fixture.cpp"
$handleConsumer = Join-Path $repoRoot "tests\cpp-interop\handle_consumer.slg"
$handleForgery = Join-Path $repoRoot "tests\cpp-interop\handle_forgery.slg"
$stage2GeneratedConsumer = Join-Path $repoRoot "tests\cpp-interop\stage2_generated_consumer.slg"
$stage2GeneratedExpected = ([IO.File]::ReadAllText(
    (Join-Path $repoRoot "tests\cpp-interop\stage2_generated_consumer.expected.stdout.txt"))).Trim()
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
    -O2 `
    --keep-temps
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$actual = (& $executable | Out-String).Replace("`r`n", "`n").TrimEnd("`n")
if ($LASTEXITCODE -ne 0) {
    throw "generated C++ binding consumer failed"
}
if ($actual -ne $expected) {
    throw "generated C++ binding output mismatch: expected '$expected', actual '$actual'"
}
$consumerLlvmPath = Get-ChildItem `
    ([System.IO.Path]::ChangeExtension($executable, ".slg-tmp")) `
    -Filter "*.ll" | Select-Object -ExpandProperty FullName -First 1
$consumerLlvm = [System.IO.File]::ReadAllText($consumerLlvmPath)
foreach ($functionName in @("riskySuccess", "riskyConstructorFailure", "riskyMethodFailure")) {
    $functionNameOffset = $consumerLlvm.IndexOf(
        " @sollang_fn_$functionName(",
        [StringComparison]::Ordinal)
    if ($functionNameOffset -lt 0) {
        throw "missing LLVM body for status-out test function '$functionName'"
    }
    $functionStart = $consumerLlvm.LastIndexOf(
        "define internal ",
        $functionNameOffset,
        [StringComparison]::Ordinal)
    $functionEnd = $consumerLlvm.IndexOf(
        "`n}",
        $functionStart,
        [StringComparison]::Ordinal)
    $functionLlvm = $consumerLlvm.Substring($functionStart, $functionEnd - $functionStart)
    if ($functionLlvm.Contains("@sollang_alloc", [StringComparison]::Ordinal) -or
        -not $functionLlvm.Contains("alloca", [StringComparison]::Ordinal)) {
        throw "status-out Result ABI allocation contract regressed in '$functionName'"
    }
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

if (-not (Test-Path -LiteralPath $selfhostCompiler)) {
    throw "self-host compiler is missing; run example 365 before C++ interop verification"
}
$stage2GeneratedWindowsLlvm = Join-Path $outputDirectory "stage2-generated-consumer.ll"
$stage2GeneratedWindowsError = Join-Path $outputDirectory "stage2-generated-consumer.stderr.txt"
$stage2GeneratedWindowsExecutable = Join-Path $outputDirectory "stage2-generated-consumer.exe"
$stage2GeneratedWindowsProcess = Start-Process `
    -FilePath $selfhostCompiler `
    -ArgumentList @("windows", "--jobs", "1", $generatedSource, $stage2GeneratedConsumer) `
    -RedirectStandardOutput $stage2GeneratedWindowsLlvm `
    -RedirectStandardError $stage2GeneratedWindowsError `
    -PassThru `
    -WindowStyle Hidden
$stage2GeneratedWindowsProcess.WaitForExit()
if ($stage2GeneratedWindowsProcess.ExitCode -ne 0) {
    throw "Stage2 generated Windows binding emission failed: $([IO.File]::ReadAllText($stage2GeneratedWindowsError))"
}
& (Join-Path $llvmHome "bin\clang.exe") -target x86_64-pc-windows-msvc `
    -Wno-override-module -O2 $stage2GeneratedWindowsLlvm `
    -o $stage2GeneratedWindowsExecutable -Xlinker /subsystem:console
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$stage2GeneratedActual = (& $stage2GeneratedWindowsExecutable | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $stage2GeneratedActual -ne $stage2GeneratedExpected) {
    throw "Stage2 generated Windows binding output mismatch: expected '$stage2GeneratedExpected', actual '$stage2GeneratedActual'"
}
$stage2GeneratedWindowsText = [IO.File]::ReadAllText($stage2GeneratedWindowsLlvm)
if ($stage2GeneratedWindowsText.Contains("@sollang_alloc", [StringComparison]::Ordinal) -or
    ([regex]::Matches($stage2GeneratedWindowsText, "call void %drop_target\(ptr %value\)")).Count -ne 2) {
    throw "Stage2 generated Windows binding allocation/drop contract regressed"
}
$stage2HandleWindowsLlvm = Join-Path $handleOutputDirectory "stage2-handle-consumer.ll"
$stage2HandleWindowsError = Join-Path $handleOutputDirectory "stage2-handle-consumer.stderr.txt"
$stage2HandleWindowsExecutable = Join-Path $handleOutputDirectory "stage2-handle-consumer.exe"
$stage2HandleWindowsProcess = Start-Process `
    -FilePath $selfhostCompiler `
    -ArgumentList @("windows", "--jobs", "1", $handleWindowsSource) `
    -RedirectStandardOutput $stage2HandleWindowsLlvm `
    -RedirectStandardError $stage2HandleWindowsError `
    -PassThru `
    -WindowStyle Hidden
$stage2HandleWindowsProcess.WaitForExit()
if ($stage2HandleWindowsProcess.ExitCode -ne 0) {
    throw "Stage2 Windows affine handle emission failed: $([IO.File]::ReadAllText($stage2HandleWindowsError))"
}
& (Join-Path $llvmHome "bin\clang.exe") -target x86_64-pc-windows-msvc `
    -Wno-override-module -O2 $stage2HandleWindowsLlvm `
    -o $stage2HandleWindowsExecutable -Xlinker /subsystem:console
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$stage2HandleActual = (& $stage2HandleWindowsExecutable | Out-String).Replace("`r`n", "`n").TrimEnd("`n")
if ($LASTEXITCODE -ne 0 -or $stage2HandleActual -ne "50,1") {
    throw "Stage2 Windows affine C++ handle failed: '$stage2HandleActual'"
}
$stage2HandleWindowsText = [IO.File]::ReadAllText($stage2HandleWindowsLlvm)
if (([regex]::Matches($stage2HandleWindowsText, "call void %drop_target\(ptr %value\)")).Count -ne 1 -or
    ([regex]::Matches($stage2HandleWindowsText, "call ptr @GetProcAddress")).Count -ne 4 -or
    ([regex]::Matches($stage2HandleWindowsText, "icmp ne ptr %v\d+, null")).Count -ne 1 -or
    $stage2HandleWindowsText.Contains("@sollang_alloc", [StringComparison]::Ordinal)) {
    throw "Stage2 Windows affine handle validation, drop cache, or zero-heap contract regressed"
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
$stage2HandleForgeryOutput = Join-Path $handleOutputDirectory "stage2-forgery.stdout.txt"
$stage2HandleForgeryError = Join-Path $handleOutputDirectory "stage2-forgery.stderr.txt"
$stage2HandleForgeryProcess = Start-Process `
    -FilePath $selfhostCompiler `
    -ArgumentList @("windows", "--jobs", "1", $handleForgery) `
    -RedirectStandardOutput $stage2HandleForgeryOutput `
    -RedirectStandardError $stage2HandleForgeryError `
    -PassThru `
    -WindowStyle Hidden
$stage2HandleForgeryProcess.WaitForExit()
if ($stage2HandleForgeryProcess.ExitCode -eq 0) {
    throw "Stage2 allowed an opaque native handle to be forged with a struct literal"
}
$stage2HandleForgeryDiagnostic = [IO.File]::ReadAllText($stage2HandleForgeryOutput)
if (-not $stage2HandleForgeryDiagnostic.Contains(
        "can only be created by its native constructor",
        [StringComparison]::Ordinal)) {
    throw "Stage2 opaque handle forgery produced the wrong diagnostic: $stage2HandleForgeryDiagnostic"
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

$diagnosticOutput = Join-Path $repoRoot "artifacts\cpp-interop\throwing-test"
dotnet $compiler bind-cpp $throwingHeader `
    --module throwingFixture `
    --library throwingFixture_shim `
    --output $diagnosticOutput `
    --target windows-x64 `
    --llvm $llvmHome `
    --build
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$throwingSource = [System.IO.File]::ReadAllText(
    (Join-Path $diagnosticOutput "throwingFixture.slg"))
$throwingShim = [System.IO.File]::ReadAllText(
    (Join-Path $diagnosticOutput "throwingFixture_shim.cpp"))
if (-not $throwingSource.Contains("try may_throw", [StringComparison]::Ordinal) -or
    -not $throwingShim.Contains("catch (...)", [StringComparison]::Ordinal) -or
    -not $throwingShim.Contains("return 1;", [StringComparison]::Ordinal)) {
    throw "potentially throwing C++ function was not translated to status-out Result ABI"
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

$stage2GeneratedLinuxLlvm = Join-Path $linuxOutputDirectory "stage2-generated-consumer.ll"
$stage2GeneratedLinuxError = Join-Path $linuxOutputDirectory "stage2-generated-consumer.stderr.txt"
$stage2GeneratedLinuxObject = Join-Path $linuxOutputDirectory "stage2-generated-consumer.o"
$stage2GeneratedLinuxExecutable = Join-Path $linuxOutputDirectory "stage2-generated-consumer"
$stage2GeneratedLinuxProcess = Start-Process `
    -FilePath $selfhostCompiler `
    -ArgumentList @("linux", "--jobs", "1", $linuxGeneratedSource, $stage2GeneratedConsumer) `
    -RedirectStandardOutput $stage2GeneratedLinuxLlvm `
    -RedirectStandardError $stage2GeneratedLinuxError `
    -PassThru `
    -WindowStyle Hidden
$stage2GeneratedLinuxProcess.WaitForExit()
if ($stage2GeneratedLinuxProcess.ExitCode -ne 0) {
    throw "Stage2 generated Linux binding emission failed: $([IO.File]::ReadAllText($stage2GeneratedLinuxError))"
}
& (Join-Path $llvmHome "bin\clang.exe") -target x86_64-unknown-linux-gnu `
    -O2 -c $stage2GeneratedLinuxLlvm -o $stage2GeneratedLinuxObject
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$wslStage2GeneratedLinuxObject = Convert-ToWslPath $stage2GeneratedLinuxObject
$wslStage2GeneratedLinuxExecutable = Convert-ToWslPath $stage2GeneratedLinuxExecutable
& wsl.exe --exec cc $wslStage2GeneratedLinuxObject -o $wslStage2GeneratedLinuxExecutable -ldl
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$stage2GeneratedActual = (& wsl.exe --exec env `
    "LD_LIBRARY_PATH=$wslOutputDirectory" $wslStage2GeneratedLinuxExecutable |
    Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $stage2GeneratedActual -ne $stage2GeneratedExpected) {
    throw "Stage2 generated Linux binding output mismatch: expected '$stage2GeneratedExpected', actual '$stage2GeneratedActual'"
}
$stage2GeneratedLinuxText = [IO.File]::ReadAllText($stage2GeneratedLinuxLlvm)
if ($stage2GeneratedLinuxText.Contains("@sollang_alloc", [StringComparison]::Ordinal) -or
    ([regex]::Matches($stage2GeneratedLinuxText, "call void %drop_target\(ptr %value\)")).Count -ne 2) {
    throw "Stage2 generated Linux binding allocation/drop contract regressed"
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

$stage2HandleLinuxLlvm = Join-Path $handleLinuxOutputDirectory "stage2-handle-consumer.ll"
$stage2HandleLinuxError = Join-Path $handleLinuxOutputDirectory "stage2-handle-consumer.stderr.txt"
$stage2HandleLinuxObject = Join-Path $handleLinuxOutputDirectory "stage2-handle-consumer.o"
$stage2HandleLinuxExecutable = Join-Path $handleLinuxOutputDirectory "stage2-handle-consumer"
$stage2HandleLinuxProcess = Start-Process `
    -FilePath $selfhostCompiler `
    -ArgumentList @("linux", "--jobs", "1", $handleLinuxSource) `
    -RedirectStandardOutput $stage2HandleLinuxLlvm `
    -RedirectStandardError $stage2HandleLinuxError `
    -PassThru `
    -WindowStyle Hidden
$stage2HandleLinuxProcess.WaitForExit()
if ($stage2HandleLinuxProcess.ExitCode -ne 0) {
    throw "Stage2 Linux affine handle emission failed: $([IO.File]::ReadAllText($stage2HandleLinuxError))"
}
& (Join-Path $llvmHome "bin\clang.exe") -target x86_64-unknown-linux-gnu `
    -O2 -c $stage2HandleLinuxLlvm -o $stage2HandleLinuxObject
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$wslStage2HandleLinuxObject = Convert-ToWslPath $stage2HandleLinuxObject
$wslStage2HandleLinuxExecutable = Convert-ToWslPath $stage2HandleLinuxExecutable
& wsl.exe --exec cc $wslStage2HandleLinuxObject -o $wslStage2HandleLinuxExecutable -ldl
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$stage2HandleActual = (& wsl.exe --exec env `
    "LD_LIBRARY_PATH=$wslHandleLinuxDirectory" $wslStage2HandleLinuxExecutable |
    Out-String).Replace("`r`n", "`n").TrimEnd("`n")
if ($LASTEXITCODE -ne 0 -or $stage2HandleActual -ne "50,1") {
    throw "Stage2 Linux affine C++ handle failed: '$stage2HandleActual'"
}
$stage2HandleLinuxText = [IO.File]::ReadAllText($stage2HandleLinuxLlvm)
if (([regex]::Matches($stage2HandleLinuxText, "call void %drop_target\(ptr %value\)")).Count -ne 1 -or
    ([regex]::Matches($stage2HandleLinuxText, "call ptr @dlsym")).Count -ne 4 -or
    ([regex]::Matches($stage2HandleLinuxText, "icmp ne ptr %v\d+, null")).Count -ne 1 -or
    $stage2HandleLinuxText.Contains("@sollang_alloc", [StringComparison]::Ordinal)) {
    throw "Stage2 Linux affine handle validation, drop cache, or zero-heap contract regressed"
}

Write-Host "PASS C++ interop: generated Stage1/Stage2 Windows/Linux bindings, affine handle RAII, zero wrapper allocation, libclang AST, compile database, exception-to-Result ABI, C shim, overloads, deterministic manifest"
