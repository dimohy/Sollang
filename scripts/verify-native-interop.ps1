[CmdletBinding()]
param(
    [switch]$SkipStage1,
    [switch]$SkipStage2
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $repoRoot "src\Sollang.Compiler\bin\Release\net11.0\Sollang.Compiler.dll"
$selfhostCompiler = Join-Path $repoRoot "artifacts\example-tests\selfhost-sollangc-driver.exe"
$source = Join-Path $repoRoot "examples\regression\590-native-c-abi.slg"
$expectedPath = Join-Path $repoRoot "examples\regression\expected\590-native-c-abi.stdout.txt"
$contextSource = Join-Path $repoRoot "examples\regression\595-native-call-contexts.slg"
$contextExpectedPath = Join-Path $repoRoot "examples\regression\expected\595-native-call-contexts.stdout.txt"
$aggregateSource = Join-Path $repoRoot "examples\regression\597-native-abi-structs.slg"
$aggregateExpectedPath = Join-Path $repoRoot "examples\regression\expected\597-native-abi-structs.stdout.txt"
$minimalAggregateSource = Join-Path $repoRoot "examples\regression\599-native-abi-struct-minimal.slg"
$minimalAggregateExpectedPath = Join-Path $repoRoot "examples\regression\expected\599-native-abi-struct-minimal.stdout.txt"
$pointAggregateSource = Join-Path $repoRoot "examples\regression\600-native-abi-point-return.slg"
$pointAggregateExpectedPath = Join-Path $repoRoot "examples\regression\expected\600-native-abi-point-return.stdout.txt"
$pressureSource = Join-Path $repoRoot "examples\regression\602-native-abi-sysv-pressure.slg"
$pressureExpectedPath = Join-Path $repoRoot "examples\regression\expected\602-native-abi-sysv-pressure.stdout.txt"
$trySource = Join-Path $repoRoot "examples\regression\625-native-try-result.slg"
$tryExpectedPath = Join-Path $repoRoot "examples\regression\expected\625-native-try-result.stdout.txt"
$outputRoot = Join-Path $repoRoot "artifacts\native-interop"
$clang = Join-Path $repoRoot ".tools\llvm-22.1.8\bin\clang.exe"
$expected = ([System.IO.File]::ReadAllText($expectedPath)).Replace("`r`n", "`n").TrimEnd("`n")
$contextExpected = ([System.IO.File]::ReadAllText($contextExpectedPath)).Replace("`r`n", "`n").TrimEnd("`n")
$aggregateExpected = ([System.IO.File]::ReadAllText($aggregateExpectedPath)).Replace("`r`n", "`n").TrimEnd("`n")
$minimalAggregateExpected = ([System.IO.File]::ReadAllText($minimalAggregateExpectedPath)).Replace("`r`n", "`n").TrimEnd("`n")
$pointAggregateExpected = ([System.IO.File]::ReadAllText($pointAggregateExpectedPath)).Replace("`r`n", "`n").TrimEnd("`n")
$pressureExpected = ([System.IO.File]::ReadAllText($pressureExpectedPath)).Replace("`r`n", "`n").TrimEnd("`n")
$tryExpected = ([System.IO.File]::ReadAllText($tryExpectedPath)).Replace("`r`n", "`n").TrimEnd("`n")

New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

function Convert-ToWslPath {
    param([Parameter(Mandatory)][string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if ($fullPath.Length -lt 3 -or $fullPath[1] -ne ':') {
        throw "cannot convert path to WSL path: $fullPath"
    }
    $drive = [char]::ToLowerInvariant($fullPath[0])
    return "/mnt/$drive/" + $fullPath.Substring(3).Replace("\", "/")
}

function Assert-Output {
    param(
        [Parameter(Mandatory)][string]$Executable,
        [string]$ExpectedText = $expected,
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
        throw "native interop executable failed: $Executable"
    }
    $normalized = $actual.Replace("`r`n", "`n").TrimEnd("`n")
    if ($normalized -ne $ExpectedText) {
        throw "native interop output mismatch for '$Executable': expected '$ExpectedText', actual '$normalized'"
    }
}

& (Join-Path $PSScriptRoot "build-native-interop-fixture.ps1") -Target all
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not $SkipStage1) {
    if (-not (Test-Path $compiler)) {
        dotnet build (Join-Path $repoRoot "Sollang.slnx") -c Release --no-restore
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    $stage1Windows = Join-Path $outputRoot "stage1-native-windows.exe"
    dotnet $compiler build $source -o $stage1Windows --target windows-x64 --llvm (Split-Path -Parent (Split-Path -Parent $clang)) -O2
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Assert-Output -Executable $stage1Windows

    $stage1Linux = Join-Path $outputRoot "stage1-native-linux"
    dotnet $compiler build $source -o $stage1Linux --target linux-x64 --llvm (Split-Path -Parent (Split-Path -Parent $clang)) -O2
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Assert-Output -Executable $stage1Linux -Linux

    $stage1TryWindows = Join-Path $outputRoot "stage1-native-try-windows.exe"
    dotnet $compiler build $trySource -o $stage1TryWindows --target windows-x64 --llvm (Split-Path -Parent (Split-Path -Parent $clang)) -O2
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Assert-Output -Executable $stage1TryWindows -ExpectedText $tryExpected

    $stage1TryLinux = Join-Path $outputRoot "stage1-native-try-linux"
    dotnet $compiler build $trySource -o $stage1TryLinux --target linux-x64 --llvm (Split-Path -Parent (Split-Path -Parent $clang)) -O2
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Assert-Output -Executable $stage1TryLinux -ExpectedText $tryExpected -Linux

    $stage1ContextWindows = Join-Path $outputRoot "stage1-native-contexts-windows.exe"
    dotnet $compiler build $contextSource -o $stage1ContextWindows --target windows-x64 --llvm (Split-Path -Parent (Split-Path -Parent $clang)) -O2
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Assert-Output -Executable $stage1ContextWindows -ExpectedText $contextExpected

    $stage1ContextLinux = Join-Path $outputRoot "stage1-native-contexts-linux"
    dotnet $compiler build $contextSource -o $stage1ContextLinux --target linux-x64 --llvm (Split-Path -Parent (Split-Path -Parent $clang)) -O2
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Assert-Output -Executable $stage1ContextLinux -ExpectedText $contextExpected -Linux

    $stage1AggregateWindows = Join-Path $outputRoot "stage1-native-abi-structs-windows.exe"
    dotnet $compiler build $aggregateSource -o $stage1AggregateWindows --target windows-x64 --llvm (Split-Path -Parent (Split-Path -Parent $clang)) -O2 --keep-temps
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Assert-Output -Executable $stage1AggregateWindows -ExpectedText $aggregateExpected
    $aggregateWindowsTemp = [System.IO.Path]::ChangeExtension($stage1AggregateWindows, ".slg-tmp")
    $aggregateWindowsLlvmPath = Join-Path $aggregateWindowsTemp (
        [System.IO.Path]::GetFileNameWithoutExtension($stage1AggregateWindows) + ".ll")
    $aggregateWindowsLlvm = [System.IO.File]::ReadAllText($aggregateWindowsLlvmPath)
    if ($aggregateWindowsLlvm -notmatch "call double %native_target\d+\(ptr %native_byval" -or
        $aggregateWindowsLlvm -notmatch "ptr sret\(%sollang\.struct\." -or
        $aggregateWindowsLlvm -notmatch "call i32 %native_target\d+\(i64 %native_arg" -or
        $aggregateWindowsLlvm -notmatch "call float %native_target\d+\(i64 %native_arg" -or
        $aggregateWindowsLlvm -notmatch "call signext i16 %native_target\d+\(i16 signext 123\)" -or
        $aggregateWindowsLlvm -notmatch "call zeroext i16 %native_target\d+\(i16 zeroext 40000, i16 zeroext 20000\)") {
        throw "Stage1 Windows aggregate C ABI lowering regressed"
    }

    $stage1AggregateLinux = Join-Path $outputRoot "stage1-native-abi-structs-linux"
    dotnet $compiler build $aggregateSource -o $stage1AggregateLinux --target linux-x64 --llvm (Split-Path -Parent (Split-Path -Parent $clang)) -O2 --keep-temps
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Assert-Output -Executable $stage1AggregateLinux -ExpectedText $aggregateExpected -Linux
    $aggregateLinuxTemp = $stage1AggregateLinux + ".slg-tmp"
    $aggregateLinuxLlvmPath = Join-Path $aggregateLinuxTemp (
        [System.IO.Path]::GetFileName($stage1AggregateLinux) + ".ll")
    $aggregateLinuxLlvm = [System.IO.File]::ReadAllText($aggregateLinuxLlvmPath)
    if ($aggregateLinuxLlvm -notmatch "call double %native_target\d+\(double %native_arg\d+, double %native_arg" -or
        $aggregateLinuxLlvm -notmatch "call \{ double, double \} %native_target" -or
        $aggregateLinuxLlvm -notmatch "call \{ i32, double \} %native_target" -or
        $aggregateLinuxLlvm -notmatch "call <2 x float> %native_target" -or
        $aggregateLinuxLlvm -notmatch "call signext i16 %native_target\d+\(i16 signext 123\)" -or
        $aggregateLinuxLlvm -notmatch "call zeroext i16 %native_target\d+\(i16 zeroext 40000, i16 zeroext 20000\)" -or
        $aggregateLinuxLlvm -notmatch "ptr byval\(%sollang\.struct\." -or
        $aggregateLinuxLlvm -notmatch "ptr sret\(%sollang\.struct\." -or
        ([regex]::Matches($aggregateLinuxLlvm, "ptr byval\(%sollang\.struct\.")).Count -lt 4) {
        throw "Stage1 Linux SysV aggregate C ABI lowering regressed"
    }
}

if (-not $SkipStage2) {
    if (-not (Test-Path $selfhostCompiler)) {
        throw "self-host compiler is missing; run an LLVM self-host example or verify-selfhost-stage2.ps1 first"
    }

    $stage2WindowsLlvm = Join-Path $outputRoot "stage2-native-windows.ll"
    $stage2WindowsError = Join-Path $outputRoot "stage2-native-windows.stderr.txt"
    $stage2WindowsExecutable = Join-Path $outputRoot "stage2-native-windows.exe"
    $windowsProcess = Start-Process `
        -FilePath $selfhostCompiler `
        -ArgumentList @("windows", $source) `
        -RedirectStandardOutput $stage2WindowsLlvm `
        -RedirectStandardError $stage2WindowsError `
        -PassThru `
        -WindowStyle Hidden
    $windowsProcess.WaitForExit()
    if ($windowsProcess.ExitCode -ne 0) {
        throw "Stage2 Windows emission failed: $([System.IO.File]::ReadAllText($stage2WindowsError))"
    }
    & $clang -target x86_64-pc-windows-msvc -Wno-override-module -O2 $stage2WindowsLlvm -o $stage2WindowsExecutable -Xlinker /subsystem:console
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Assert-Output -Executable $stage2WindowsExecutable

    $windowsLlvm = [System.IO.File]::ReadAllText($stage2WindowsLlvm)
    $windowsMain = $windowsLlvm.Substring($windowsLlvm.IndexOf("define i32 @main", [StringComparison]::Ordinal))
    if ($windowsMain.Contains("GetProcAddress", [StringComparison]::Ordinal) -or
        ([regex]::Matches($windowsLlvm, "call ptr @GetProcAddress")).Count -ne 3 -or
        ([regex]::Matches($windowsMain, "load ptr, ptr @sollang_native_function_")).Count -ne 3) {
        throw "Stage2 Windows steady-state native call contract regressed"
    }

    $stage2LinuxLlvm = Join-Path $outputRoot "stage2-native-linux.ll"
    $stage2LinuxError = Join-Path $outputRoot "stage2-native-linux.stderr.txt"
    $stage2LinuxObject = Join-Path $outputRoot "stage2-native-linux.o"
    $stage2LinuxExecutable = Join-Path $outputRoot "stage2-native-linux"
    $linuxProcess = Start-Process `
        -FilePath $selfhostCompiler `
        -ArgumentList @("linux", $source) `
        -RedirectStandardOutput $stage2LinuxLlvm `
        -RedirectStandardError $stage2LinuxError `
        -PassThru `
        -WindowStyle Hidden
    $linuxProcess.WaitForExit()
    if ($linuxProcess.ExitCode -ne 0) {
        throw "Stage2 Linux emission failed: $([System.IO.File]::ReadAllText($stage2LinuxError))"
    }
    & $clang -target x86_64-unknown-linux-gnu -O2 -c $stage2LinuxLlvm -o $stage2LinuxObject
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $linuxObject = Convert-ToWslPath $stage2LinuxObject
    $linuxExecutable = Convert-ToWslPath $stage2LinuxExecutable
    & wsl.exe --exec cc $linuxObject -o $linuxExecutable -ldl
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Assert-Output -Executable $stage2LinuxExecutable -Linux

    $linuxLlvm = [System.IO.File]::ReadAllText($stage2LinuxLlvm)
    $linuxMain = $linuxLlvm.Substring($linuxLlvm.IndexOf("define i32 @main", [StringComparison]::Ordinal))
    if ($linuxMain.Contains("@dlsym", [StringComparison]::Ordinal) -or
        ([regex]::Matches($linuxLlvm, "call ptr @dlsym")).Count -ne 3 -or
        ([regex]::Matches($linuxMain, "load ptr, ptr @sollang_native_function_")).Count -ne 3) {
        throw "Stage2 Linux steady-state native call contract regressed"
    }

    $stage2TryWindowsLlvm = Join-Path $outputRoot "stage2-native-try-windows.ll"
    $stage2TryWindowsError = Join-Path $outputRoot "stage2-native-try-windows.stderr.txt"
    $stage2TryWindowsExecutable = Join-Path $outputRoot "stage2-native-try-windows.exe"
    $tryWindowsProcess = Start-Process `
        -FilePath $selfhostCompiler `
        -ArgumentList @("windows", $trySource) `
        -RedirectStandardOutput $stage2TryWindowsLlvm `
        -RedirectStandardError $stage2TryWindowsError `
        -PassThru `
        -WindowStyle Hidden
    $tryWindowsProcess.WaitForExit()
    if ($tryWindowsProcess.ExitCode -ne 0) {
        throw "Stage2 Windows try-native emission failed: $([System.IO.File]::ReadAllText($stage2TryWindowsError))"
    }
    & $clang -target x86_64-pc-windows-msvc -Wno-override-module -O2 $stage2TryWindowsLlvm -o $stage2TryWindowsExecutable -Xlinker /subsystem:console
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Assert-Output -Executable $stage2TryWindowsExecutable -ExpectedText $tryExpected
    $tryWindowsLlvm = [System.IO.File]::ReadAllText($stage2TryWindowsLlvm)
    if ($tryWindowsLlvm -notmatch "call i32 %native_target_\d+\(i32 21, ptr %native_try_out_" -or
        $tryWindowsLlvm -notmatch "native_try_error_" -or
        $tryWindowsLlvm -notmatch "native_try_result_slot_") {
        throw "Stage2 Windows status-out Result lowering regressed"
    }

    $stage2TryLinuxLlvm = Join-Path $outputRoot "stage2-native-try-linux.ll"
    $stage2TryLinuxError = Join-Path $outputRoot "stage2-native-try-linux.stderr.txt"
    $stage2TryLinuxObject = Join-Path $outputRoot "stage2-native-try-linux.o"
    $stage2TryLinuxExecutable = Join-Path $outputRoot "stage2-native-try-linux"
    $tryLinuxProcess = Start-Process `
        -FilePath $selfhostCompiler `
        -ArgumentList @("linux", $trySource) `
        -RedirectStandardOutput $stage2TryLinuxLlvm `
        -RedirectStandardError $stage2TryLinuxError `
        -PassThru `
        -WindowStyle Hidden
    $tryLinuxProcess.WaitForExit()
    if ($tryLinuxProcess.ExitCode -ne 0) {
        throw "Stage2 Linux try-native emission failed: $([System.IO.File]::ReadAllText($stage2TryLinuxError))"
    }
    & $clang -target x86_64-unknown-linux-gnu -O2 -c $stage2TryLinuxLlvm -o $stage2TryLinuxObject
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $tryLinuxObject = Convert-ToWslPath $stage2TryLinuxObject
    $tryLinuxExecutable = Convert-ToWslPath $stage2TryLinuxExecutable
    & wsl.exe --exec cc $tryLinuxObject -o $tryLinuxExecutable -ldl
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Assert-Output -Executable $stage2TryLinuxExecutable -ExpectedText $tryExpected -Linux
    $tryLinuxLlvm = [System.IO.File]::ReadAllText($stage2TryLinuxLlvm)
    if ($tryLinuxLlvm -notmatch "call i32 %native_target_\d+\(i32 21, ptr %native_try_out_" -or
        $tryLinuxLlvm -notmatch "native_try_error_" -or
        $tryLinuxLlvm -notmatch "native_try_result_slot_") {
        throw "Stage2 Linux status-out Result lowering regressed"
    }

    $stage2ContextWindowsLlvm = Join-Path $outputRoot "stage2-native-contexts-windows.ll"
    $stage2ContextWindowsError = Join-Path $outputRoot "stage2-native-contexts-windows.stderr.txt"
    $stage2ContextWindowsExecutable = Join-Path $outputRoot "stage2-native-contexts-windows.exe"
    $contextWindowsProcess = Start-Process `
        -FilePath $selfhostCompiler `
        -ArgumentList @("windows", $contextSource) `
        -RedirectStandardOutput $stage2ContextWindowsLlvm `
        -RedirectStandardError $stage2ContextWindowsError `
        -PassThru `
        -WindowStyle Hidden
    $contextWindowsProcess.WaitForExit()
    if ($contextWindowsProcess.ExitCode -ne 0) {
        throw "Stage2 Windows contextual emission failed: $([System.IO.File]::ReadAllText($stage2ContextWindowsError))"
    }
    & $clang -target x86_64-pc-windows-msvc -Wno-override-module -O2 $stage2ContextWindowsLlvm -o $stage2ContextWindowsExecutable -Xlinker /subsystem:console
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Assert-Output -Executable $stage2ContextWindowsExecutable -ExpectedText $contextExpected
    $contextWindowsLlvm = [System.IO.File]::ReadAllText($stage2ContextWindowsLlvm)
    if (([regex]::Matches($contextWindowsLlvm, "load ptr, ptr @sollang_native_function_")).Count -ne 3) {
        throw "Stage2 Windows nested native call lowering regressed"
    }

    $stage2MinimalAggregateWindowsLlvm = Join-Path $outputRoot "stage2-native-aggregate-minimal-windows.ll"
    $stage2MinimalAggregateWindowsError = Join-Path $outputRoot "stage2-native-aggregate-minimal-windows.stderr.txt"
    $stage2MinimalAggregateWindowsExecutable = Join-Path $outputRoot "stage2-native-aggregate-minimal-windows.exe"
    $minimalAggregateWindowsProcess = Start-Process `
        -FilePath $selfhostCompiler `
        -ArgumentList @("windows", $minimalAggregateSource) `
        -RedirectStandardOutput $stage2MinimalAggregateWindowsLlvm `
        -RedirectStandardError $stage2MinimalAggregateWindowsError `
        -PassThru `
        -WindowStyle Hidden
    $minimalAggregateWindowsProcess.WaitForExit()
    if ($minimalAggregateWindowsProcess.ExitCode -ne 0) {
        throw "Stage2 Windows minimal aggregate emission failed: $([System.IO.File]::ReadAllText($stage2MinimalAggregateWindowsError))"
    }
    & $clang -target x86_64-pc-windows-msvc -Wno-override-module -O2 $stage2MinimalAggregateWindowsLlvm -o $stage2MinimalAggregateWindowsExecutable -Xlinker /subsystem:console
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Assert-Output -Executable $stage2MinimalAggregateWindowsExecutable -ExpectedText $minimalAggregateExpected
    $minimalAggregateWindowsLlvm = [System.IO.File]::ReadAllText($stage2MinimalAggregateWindowsLlvm)
    if ($minimalAggregateWindowsLlvm -notmatch "call i32 %native_target_\d+\(i64 %native_arg_bits_") {
        throw "Stage2 Windows direct aggregate register coercion regressed"
    }

    $stage2PointAggregateWindowsLlvm = Join-Path $outputRoot "stage2-native-aggregate-point-windows.ll"
    $stage2PointAggregateWindowsError = Join-Path $outputRoot "stage2-native-aggregate-point-windows.stderr.txt"
    $stage2PointAggregateWindowsExecutable = Join-Path $outputRoot "stage2-native-aggregate-point-windows.exe"
    $pointAggregateWindowsProcess = Start-Process `
        -FilePath $selfhostCompiler `
        -ArgumentList @("windows", $pointAggregateSource) `
        -RedirectStandardOutput $stage2PointAggregateWindowsLlvm `
        -RedirectStandardError $stage2PointAggregateWindowsError `
        -PassThru `
        -WindowStyle Hidden
    $pointAggregateWindowsProcess.WaitForExit()
    if ($pointAggregateWindowsProcess.ExitCode -ne 0) {
        throw "Stage2 Windows point aggregate emission failed: $([System.IO.File]::ReadAllText($stage2PointAggregateWindowsError))"
    }
    & $clang -target x86_64-pc-windows-msvc -Wno-override-module -O2 $stage2PointAggregateWindowsLlvm -o $stage2PointAggregateWindowsExecutable -Xlinker /subsystem:console
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Assert-Output -Executable $stage2PointAggregateWindowsExecutable -ExpectedText $pointAggregateExpected
    $pointAggregateWindowsLlvm = [System.IO.File]::ReadAllText($stage2PointAggregateWindowsLlvm)
    if ($pointAggregateWindowsLlvm -notmatch "call void %native_target_\d+\(ptr sret\(%sollang\.struct\." -or
        $pointAggregateWindowsLlvm -notmatch "call double %native_target_\d+\(ptr %native_arg_" -or
        $pointAggregateWindowsLlvm -notmatch "call void %native_target_\d+\(ptr %slot") {
        throw "Stage2 Windows by-reference aggregate ABI lowering regressed"
    }

    $stage2AggregateWindowsLlvm = Join-Path $outputRoot "stage2-native-aggregate-windows.ll"
    $stage2AggregateWindowsError = Join-Path $outputRoot "stage2-native-aggregate-windows.stderr.txt"
    $stage2AggregateWindowsExecutable = Join-Path $outputRoot "stage2-native-aggregate-windows.exe"
    $aggregateWindowsProcess = Start-Process `
        -FilePath $selfhostCompiler `
        -ArgumentList @("windows", $aggregateSource) `
        -RedirectStandardOutput $stage2AggregateWindowsLlvm `
        -RedirectStandardError $stage2AggregateWindowsError `
        -PassThru `
        -WindowStyle Hidden
    $aggregateWindowsProcess.WaitForExit()
    if ($aggregateWindowsProcess.ExitCode -ne 0) {
        throw "Stage2 Windows aggregate matrix emission failed: $([System.IO.File]::ReadAllText($stage2AggregateWindowsError))"
    }
    & $clang -target x86_64-pc-windows-msvc -Wno-override-module -O2 $stage2AggregateWindowsLlvm -o $stage2AggregateWindowsExecutable -Xlinker /subsystem:console
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Assert-Output -Executable $stage2AggregateWindowsExecutable -ExpectedText $aggregateExpected
    $aggregateWindowsLlvm = [System.IO.File]::ReadAllText($stage2AggregateWindowsLlvm)
    if ($aggregateWindowsLlvm -notmatch "call signext i16 %native_target_\d+\(i16 signext 123\)" -or
        $aggregateWindowsLlvm -notmatch "call zeroext i16 %native_target_\d+\(i16 zeroext 40000, i16 zeroext 20000\)") {
        throw "Stage2 Windows aggregate matrix or narrow scalar lowering regressed"
    }

    $stage2ContextLinuxLlvm = Join-Path $outputRoot "stage2-native-contexts-linux.ll"
    $stage2ContextLinuxError = Join-Path $outputRoot "stage2-native-contexts-linux.stderr.txt"
    $stage2ContextLinuxObject = Join-Path $outputRoot "stage2-native-contexts-linux.o"
    $stage2ContextLinuxExecutable = Join-Path $outputRoot "stage2-native-contexts-linux"
    $contextLinuxProcess = Start-Process `
        -FilePath $selfhostCompiler `
        -ArgumentList @("linux", $contextSource) `
        -RedirectStandardOutput $stage2ContextLinuxLlvm `
        -RedirectStandardError $stage2ContextLinuxError `
        -PassThru `
        -WindowStyle Hidden
    $contextLinuxProcess.WaitForExit()
    if ($contextLinuxProcess.ExitCode -ne 0) {
        throw "Stage2 Linux contextual emission failed: $([System.IO.File]::ReadAllText($stage2ContextLinuxError))"
    }
    & $clang -target x86_64-unknown-linux-gnu -O2 -c $stage2ContextLinuxLlvm -o $stage2ContextLinuxObject
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $contextLinuxObject = Convert-ToWslPath $stage2ContextLinuxObject
    $contextLinuxExecutable = Convert-ToWslPath $stage2ContextLinuxExecutable
    & wsl.exe --exec cc $contextLinuxObject -o $contextLinuxExecutable -ldl
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Assert-Output -Executable $stage2ContextLinuxExecutable -ExpectedText $contextExpected -Linux
    $contextLinuxLlvm = [System.IO.File]::ReadAllText($stage2ContextLinuxLlvm)
    if (([regex]::Matches($contextLinuxLlvm, "load ptr, ptr @sollang_native_function_")).Count -ne 3) {
        throw "Stage2 Linux nested native call lowering regressed"
    }

    $stage2PressureLinuxLlvm = Join-Path $outputRoot "stage2-native-pressure-linux.ll"
    $stage2PressureLinuxError = Join-Path $outputRoot "stage2-native-pressure-linux.stderr.txt"
    $stage2PressureLinuxObject = Join-Path $outputRoot "stage2-native-pressure-linux.o"
    $stage2PressureLinuxExecutable = Join-Path $outputRoot "stage2-native-pressure-linux"
    $pressureLinuxProcess = Start-Process `
        -FilePath $selfhostCompiler `
        -ArgumentList @("linux", $pressureSource) `
        -RedirectStandardOutput $stage2PressureLinuxLlvm `
        -RedirectStandardError $stage2PressureLinuxError `
        -PassThru `
        -WindowStyle Hidden
    $pressureLinuxProcess.WaitForExit()
    if ($pressureLinuxProcess.ExitCode -ne 0) {
        throw "Stage2 Linux pressure emission failed: $([System.IO.File]::ReadAllText($stage2PressureLinuxError))"
    }
    & $clang -target x86_64-unknown-linux-gnu -O2 -c $stage2PressureLinuxLlvm -o $stage2PressureLinuxObject
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $pressureLinuxObject = Convert-ToWslPath $stage2PressureLinuxObject
    $pressureLinuxExecutable = Convert-ToWslPath $stage2PressureLinuxExecutable
    & wsl.exe --exec cc $pressureLinuxObject -o $pressureLinuxExecutable -ldl
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Assert-Output -Executable $stage2PressureLinuxExecutable -ExpectedText $pressureExpected -Linux
    $pressureLinuxLlvm = [System.IO.File]::ReadAllText($stage2PressureLinuxLlvm)
    if (([regex]::Matches($pressureLinuxLlvm, "ptr byval\(%sollang\.struct\.")).Count -lt 2 -or
        $pressureLinuxLlvm -notmatch "call signext i16 %native_target_\d+\(i16 signext 123\)" -or
        $pressureLinuxLlvm -notmatch "call zeroext i16 %native_target_\d+\(i16 zeroext 40000, i16 zeroext 20000\)") {
        throw "Stage2 Linux SysV register rollback or narrow scalar lowering regressed"
    }

    $stage2AggregateLinuxLlvm = Join-Path $outputRoot "stage2-native-aggregate-linux.ll"
    $stage2AggregateLinuxError = Join-Path $outputRoot "stage2-native-aggregate-linux.stderr.txt"
    $stage2AggregateLinuxObject = Join-Path $outputRoot "stage2-native-aggregate-linux.o"
    $stage2AggregateLinuxExecutable = Join-Path $outputRoot "stage2-native-aggregate-linux"
    $aggregateLinuxProcess = Start-Process `
        -FilePath $selfhostCompiler `
        -ArgumentList @("linux", $aggregateSource) `
        -RedirectStandardOutput $stage2AggregateLinuxLlvm `
        -RedirectStandardError $stage2AggregateLinuxError `
        -PassThru `
        -WindowStyle Hidden
    $aggregateLinuxProcess.WaitForExit()
    if ($aggregateLinuxProcess.ExitCode -ne 0) {
        throw "Stage2 Linux aggregate matrix emission failed: $([System.IO.File]::ReadAllText($stage2AggregateLinuxError))"
    }
    & $clang -target x86_64-unknown-linux-gnu -O2 -c $stage2AggregateLinuxLlvm -o $stage2AggregateLinuxObject
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $aggregateLinuxObject = Convert-ToWslPath $stage2AggregateLinuxObject
    $aggregateLinuxExecutable = Convert-ToWslPath $stage2AggregateLinuxExecutable
    & wsl.exe --exec cc $aggregateLinuxObject -o $aggregateLinuxExecutable -ldl
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Assert-Output -Executable $stage2AggregateLinuxExecutable -ExpectedText $aggregateExpected -Linux
    $aggregateLinuxLlvm = [System.IO.File]::ReadAllText($stage2AggregateLinuxLlvm)
    if (([regex]::Matches($aggregateLinuxLlvm, "ptr byval\(%sollang\.struct\.")).Count -lt 4 -or
        $aggregateLinuxLlvm -notmatch "call signext i16 %native_target_\d+\(i16 signext 123\)" -or
        $aggregateLinuxLlvm -notmatch "call zeroext i16 %native_target_\d+\(i16 zeroext 40000, i16 zeroext 20000\)") {
        throw "Stage2 Linux aggregate matrix lowering regressed"
    }
}

$verifiedStages = if ($SkipStage2) { "Stage1" } elseif ($SkipStage1) { "Stage2" } else { "Stage1/Stage2" }
Write-Host "Native interop verification passed for $verifiedStages on Windows/Linux."
