[CmdletBinding()]
param(
    [switch]$SkipStage1,
    [switch]$SkipStage2
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $repoRoot "src\Sollang.Compiler\bin\Release\net11.0\Sollang.Compiler.dll"
$selfhostCompiler = Join-Path $repoRoot "artifacts\example-tests\selfhost-sollangc-driver.exe"
$source = Join-Path $repoRoot "examples\590-native-c-abi.slg"
$expectedPath = Join-Path $repoRoot "examples\expected\590-native-c-abi.stdout.txt"
$contextSource = Join-Path $repoRoot "examples\595-native-call-contexts.slg"
$contextExpectedPath = Join-Path $repoRoot "examples\expected\595-native-call-contexts.stdout.txt"
$outputRoot = Join-Path $repoRoot "artifacts\native-interop"
$clang = Join-Path $repoRoot ".tools\llvm-22.1.8\bin\clang.exe"
$expected = ([System.IO.File]::ReadAllText($expectedPath)).Replace("`r`n", "`n").TrimEnd("`n")
$contextExpected = ([System.IO.File]::ReadAllText($contextExpectedPath)).Replace("`r`n", "`n").TrimEnd("`n")

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

    $stage1ContextWindows = Join-Path $outputRoot "stage1-native-contexts-windows.exe"
    dotnet $compiler build $contextSource -o $stage1ContextWindows --target windows-x64 --llvm (Split-Path -Parent (Split-Path -Parent $clang)) -O2
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Assert-Output -Executable $stage1ContextWindows -ExpectedText $contextExpected

    $stage1ContextLinux = Join-Path $outputRoot "stage1-native-contexts-linux"
    dotnet $compiler build $contextSource -o $stage1ContextLinux --target linux-x64 --llvm (Split-Path -Parent (Split-Path -Parent $clang)) -O2
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Assert-Output -Executable $stage1ContextLinux -ExpectedText $contextExpected -Linux
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
}

Write-Host "Native interop verification passed for Stage1/Stage2 on Windows/Linux."
