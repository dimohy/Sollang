[CmdletBinding()]
param(
    [string]$SelfhostCompiler = "",
    [string]$ManagedCompilerAssembly = "",
    [string]$LlvmHome = "",
    [string]$Fixture = "",
    [string]$ExpectedPath = "",
    [string]$ArtifactDirectory = "",
    [ValidateRange(1, 1000)]
    [int]$CaseCount = 3
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "verification-process.ps1")

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($SelfhostCompiler)) {
    $SelfhostCompiler = Join-Path $repoRoot "artifacts\example-tests\selfhost-sollangc-driver.exe"
}
if ([string]::IsNullOrWhiteSpace($ManagedCompilerAssembly)) {
    $ManagedCompilerAssembly = Join-Path $repoRoot "src\Sollang.Compiler\bin\Release\net11.0\Sollang.Compiler.dll"
}
if ([string]::IsNullOrWhiteSpace($LlvmHome)) {
    $LlvmHome = Join-Path $repoRoot ".tools\llvm-22.1.8"
}
$SelfhostCompiler = [System.IO.Path]::GetFullPath($SelfhostCompiler)
$ManagedCompilerAssembly = [System.IO.Path]::GetFullPath($ManagedCompilerAssembly)
$LlvmHome = [System.IO.Path]::GetFullPath($LlvmHome)
$clang = Join-Path $LlvmHome "bin\clang.exe"
$llvmReadObj = Join-Path $LlvmHome "bin\llvm-readobj.exe"
$runtimeManifest = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-compiler-runtime.sources.txt"
if ([string]::IsNullOrWhiteSpace($Fixture)) {
    $Fixture = Join-Path $repoRoot "examples\regression\1226-aes128-cpu-dispatch-differential.slg"
}
if ([string]::IsNullOrWhiteSpace($ExpectedPath)) {
    $ExpectedPath = Join-Path $repoRoot "examples\regression\expected\1226-aes128-cpu-dispatch-differential.stdout.txt"
}
$fixture = [System.IO.Path]::GetFullPath($Fixture)
$expectedPath = [System.IO.Path]::GetFullPath($ExpectedPath)
$selfhostSources = @(
    "stdlib\std\crypto\aes128.slg",
    "stdlib\std\crypto\bits.slg"
) | ForEach-Object { Join-Path $repoRoot $_ }
foreach ($required in @(
    $SelfhostCompiler,
    $ManagedCompilerAssembly,
    $clang,
    $llvmReadObj,
    $runtimeManifest,
    $fixture,
    $expectedPath) + $selfhostSources) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "CPU AES differential dependency is missing: $required"
    }
}

function Assert-WindowsX64Llvm {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $llvm = [System.IO.File]::ReadAllText($Path)
    if ($llvm -notmatch '(?m)^target triple = "x86_64-pc-windows-msvc"$') {
        throw "$Description must target windows-x64 (x86_64-pc-windows-msvc)"
    }
}

function Assert-WindowsX64Executable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $headers = (& $llvmReadObj --file-headers $Path 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw "$Description PE header inspection failed.`n$headers"
    }
    foreach ($requiredHeader in @(
        'Format: COFF-x86-64',
        'Arch: x86_64',
        'AddressSize: 64bit',
        'Machine: IMAGE_FILE_MACHINE_AMD64 (0x8664)',
        'Magic: 0x20B')) {
        if (-not $headers.Contains($requiredHeader, [StringComparison]::Ordinal)) {
            throw "$Description is not a windows-x64 PE32+ executable; missing '$requiredHeader'"
        }
    }
}

if ([string]::IsNullOrWhiteSpace($ArtifactDirectory)) {
    $ArtifactDirectory = Join-Path $repoRoot "artifacts\cpu-aes-differential"
}
$artifacts = [System.IO.Path]::GetFullPath($ArtifactDirectory)
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
$managedExecutable = Join-Path $artifacts "managed.exe"
$managedLlvm = Join-Path $artifacts "managed.ll"
$managedStdout = Join-Path $artifacts "managed.compile.stdout.log"
$managedStderr = Join-Path $artifacts "managed.compile.stderr.log"
$selfhostLlvm = Join-Path $artifacts "selfhost.ll"
$selfhostStderr = Join-Path $artifacts "selfhost.compile.stderr.log"
Remove-Item -LiteralPath $managedExecutable, $managedLlvm, $managedStdout, $managedStderr, $selfhostLlvm, $selfhostStderr -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $artifacts "managed.slg-tmp") -Recurse -Force -ErrorAction SilentlyContinue

$managed = Start-Process `
    -FilePath "dotnet" `
    -ArgumentList @(
        $ManagedCompilerAssembly,
        "build",
        $fixture,
        "-o",
        $managedExecutable,
        "--target",
        "windows-x64",
        "--llvm",
        $LlvmHome,
        "-O0",
        "--keep-temps") `
    -WorkingDirectory $repoRoot `
    -RedirectStandardOutput $managedStdout `
    -RedirectStandardError $managedStderr `
    -WindowStyle Hidden `
    -PassThru
Wait-VerificationProcess $managed "managed CPU AES differential build"
if ($managed.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $managedLlvm -PathType Leaf)) {
    throw "managed CPU AES differential emission failed.`n$([System.IO.File]::ReadAllText($managedStdout))`n$([System.IO.File]::ReadAllText($managedStderr))"
}
if (-not [string]::IsNullOrWhiteSpace([System.IO.File]::ReadAllText($managedStderr))) {
    throw "managed CPU AES differential emitted unexpected diagnostics"
}
Assert-WindowsX64Llvm $managedLlvm "managed CPU AES differential LLVM"
Assert-WindowsX64Executable $managedExecutable "managed CPU AES differential executable"

$runtimeSources = [System.IO.File]::ReadAllLines($runtimeManifest) |
    ForEach-Object { $_.Trim() } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { Join-Path $repoRoot $_ }
$selfhostArguments = @(
    "windows",
    "--jobs",
    "4",
    $fixture
) + $selfhostSources + $runtimeSources
$selfhost = Start-Process `
    -FilePath $SelfhostCompiler `
    -ArgumentList $selfhostArguments `
    -WorkingDirectory $repoRoot `
    -RedirectStandardOutput $selfhostLlvm `
    -RedirectStandardError $selfhostStderr `
    -WindowStyle Hidden `
    -PassThru
Wait-VerificationProcess $selfhost "selfhost CPU AES differential build"
if ($selfhost.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $selfhostLlvm -PathType Leaf)) {
    throw "selfhost CPU AES differential emission failed.`n$([System.IO.File]::ReadAllText($selfhostStderr))"
}
if (-not [string]::IsNullOrWhiteSpace([System.IO.File]::ReadAllText($selfhostStderr))) {
    throw "selfhost CPU AES differential emitted unexpected diagnostics"
}
Assert-WindowsX64Llvm $selfhostLlvm "selfhost CPU AES differential LLVM"

$expected = [System.IO.File]::ReadAllText($expectedPath).Replace("`r`n", "`n").TrimEnd("`n")
foreach ($backend in @(
    [ordered]@{ Name = "managed"; Llvm = $managedLlvm; Entry = "sollang_start"; LibraryDirectory = (Join-Path $artifacts "managed.slg-tmp") },
    [ordered]@{ Name = "selfhost"; Llvm = $selfhostLlvm; Entry = ""; LibraryDirectory = "" }
)) {
    $original = [System.IO.File]::ReadAllText($backend.Llvm)
    $initializer = [regex]::Match(
        $original,
        '@sollang_aes128_selected = internal global ptr (?<resolver>@[^,\r\n]+), align 8')
    if (-not $initializer.Success) {
        throw "$($backend.Name) CPU AES differential LLVM omitted the resolver initializer"
    }
    $resolver = $initializer.Groups['resolver'].Value
    if (-not $resolver.EndsWith("_resolve", [StringComparison]::Ordinal)) {
        throw "$($backend.Name) CPU AES differential resolver has an unexpected identity: $resolver"
    }
    $base = $resolver.Substring(0, $resolver.Length - "_resolve".Length)
    foreach ($mode in @("portable", "x86")) {
        $selected = "${base}_${mode}"
        if ($original -notmatch [regex]::Escape($selected)) {
            throw "$($backend.Name) CPU AES differential LLVM omitted $mode"
        }
        $forced = $original.Replace($initializer.Value, "@sollang_aes128_selected = internal global ptr $selected, align 8")
        $forcedLlvm = Join-Path $artifacts "$($backend.Name)-$mode.ll"
        $forcedExecutable = Join-Path $artifacts "$($backend.Name)-$mode.exe"
        [System.IO.File]::WriteAllText($forcedLlvm, $forced)
        $linkArguments = @(
            "-Wno-override-module",
            $forcedLlvm,
            "-O1",
            "-o",
            $forcedExecutable,
            "-Xlinker",
            "/subsystem:console",
            "-lshell32",
            "-lws2_32",
            "-lbcrypt")
        if (-not [string]::IsNullOrWhiteSpace($backend.Entry)) {
            $linkArguments += @("-Xlinker", "/entry:$($backend.Entry)")
        }
        if (-not [string]::IsNullOrWhiteSpace($backend.LibraryDirectory)) {
            $linkArguments += @(
                "-L$($backend.LibraryDirectory)",
                "-lkernel32",
                "-lshell32",
                "-lucrtbase")
        }
        & $clang @linkArguments
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $forcedExecutable -PathType Leaf)) {
            throw "$($backend.Name) CPU AES $mode differential LLVM failed to link"
        }
        Assert-WindowsX64Llvm $forcedLlvm "$($backend.Name) CPU AES $mode differential LLVM"
        Assert-WindowsX64Executable $forcedExecutable "$($backend.Name) CPU AES $mode differential executable"
        $run = Invoke-VerificationProcessCapture `
            -FilePath $forcedExecutable `
            -Description "$($backend.Name) CPU AES $mode differential executable"
        $actual = $run.Stdout.Replace("`r`n", "`n").TrimEnd("`n")
        if ($run.ExitCode -ne 0 -or $actual -ne $expected) {
            throw "$($backend.Name) CPU AES $mode differential failed.`nExpected:`n$expected`nActual:`n$actual`n$($run.Stderr)"
        }
    }
}

$totalChecks = $CaseCount * 4
Write-Host "[CPU AES differential] PASS windows-x64 PE32+ target; $CaseCount case(s) x managed/selfhost x portable/x64-AES-NI: $totalChecks exact path checks."
