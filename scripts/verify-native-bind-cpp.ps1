[CmdletBinding()]
param(
    [string]$ManagedCompiler = "",
    [string]$NativeCompiler = "",
    [ValidateSet("windows-x64", "linux-x64")]
    [string]$Target = "windows-x64",
    [string]$Distribution = "Ubuntu"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ManagedCompiler)) {
    $ManagedCompiler = Join-Path $repoRoot "src\Sollang.Compiler\bin\Release\net11.0\Sollang.Compiler.dll"
}
if ([string]::IsNullOrWhiteSpace($NativeCompiler)) {
    $NativeCompiler = if ($Target -eq "windows-x64") {
        Join-Path $repoRoot "artifacts\example-tests\selfhost-stage3.exe"
    }
    else {
        Join-Path $repoRoot "artifacts\example-tests\selfhost-stage3-linux"
    }
}
$ManagedCompiler = (Resolve-Path -LiteralPath $ManagedCompiler).Path
$NativeCompiler = (Resolve-Path -LiteralPath $NativeCompiler).Path
$header = Join-Path $repoRoot "tests\cpp-interop\cpp_fixture.hpp"
$consumer = Join-Path $repoRoot "tests\cpp-interop\consumer.slg"
$expected = [IO.File]::ReadAllText(
    (Join-Path $repoRoot "tests\cpp-interop\expected.stdout.txt")).Replace("`r`n", "`n").TrimEnd("`n")
$artifacts = Join-Path $repoRoot "artifacts\native-bind-cpp\$Target"
$managedOutput = Join-Path $artifacts "managed\generated"
$nativeOutput = Join-Path $artifacts "native\generated"
$managedLlvm = Join-Path $repoRoot ".tools\llvm-22.1.8"
$nativeLlvm = if ($Target -eq "windows-x64") {
    $managedLlvm
}
else {
    Join-Path $repoRoot "scripts\linux-cross-llvm"
}
$stdlib = Join-Path $repoRoot "stdlib"
New-Item -ItemType Directory -Path $managedOutput, $nativeOutput -Force | Out-Null

function Convert-ToWslPath {
    param([Parameter(Mandatory)] [string]$Path)

    $absolute = [IO.Path]::GetFullPath($Path)
    $drive = $absolute.Substring(0, 1).ToLowerInvariant()
    $tail = $absolute.Substring(3).Replace('\', '/')
    "/mnt/$drive/$tail"
}

function Convert-NativeArgument {
    param([string]$Argument)

    if ($Target -eq "linux-x64" -and $Argument -match '^[A-Za-z]:[\\/]') {
        return Convert-ToWslPath $Argument
    }
    $Argument
}

function Invoke-Compiler {
    param(
        [bool]$Native,
        [string[]]$Arguments
    )

    $start = [Diagnostics.ProcessStartInfo]::new()
    if ($Native) {
        if ($Target -eq "linux-x64") {
            $start.FileName = "wsl.exe"
            $start.ArgumentList.Add("-d")
            $start.ArgumentList.Add($Distribution)
            $start.ArgumentList.Add("--")
            $start.ArgumentList.Add((Convert-ToWslPath $NativeCompiler))
        }
        else {
            $start.FileName = $NativeCompiler
        }
    }
    else {
        $start.FileName = "dotnet"
        $start.ArgumentList.Add($ManagedCompiler)
    }
    foreach ($argument in $Arguments) {
        $start.ArgumentList.Add($(if ($Native) { Convert-NativeArgument $argument } else { $argument }))
    }
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($start)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    [pscustomobject]@{
        ExitCode = $process.ExitCode
        Stdout = $stdout.Replace("`r`n", "`n").Replace("`r", "`n")
        Stderr = $stderr.Replace("`r`n", "`n").Replace("`r", "`n")
    }
}

function Assert-EquivalentFailure {
    param(
        [string]$Name,
        [string[]]$Arguments
    )

    $managed = Invoke-Compiler $false $Arguments
    $native = Invoke-Compiler $true $Arguments
    if ($managed.ExitCode -ne 1 -or $native.ExitCode -ne 1 -or
        $managed.Stdout -ne $native.Stdout -or $managed.Stderr -ne $native.Stderr) {
        throw "$Name differs.`nmanaged: exit=$($managed.ExitCode) stdout='$($managed.Stdout)' stderr='$($managed.Stderr)'`nnative: exit=$($native.ExitCode) stdout='$($native.Stdout)' stderr='$($native.Stderr)'"
    }
}

function Normalize-SuccessOutput {
    param(
        [string]$Text,
        [string]$OutputRoot,
        [bool]$Native
    )

    $path = if ($Native -and $Target -eq "linux-x64") {
        Convert-ToWslPath $OutputRoot
    }
    else {
        [IO.Path]::GetFullPath($OutputRoot)
    }
    $Text.Replace($path.Replace('\', '/'), "<output>").Replace($path, "<output>").Replace('\', '/')
}

function Get-NormalizedGeneratedText {
    param(
        [string]$Path,
        [bool]$Native
    )

    $text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n").Replace("`r", "`n")
    $headerText = if ($Native -and $Target -eq "linux-x64") {
        Convert-ToWslPath $header
    }
    else {
        [IO.Path]::GetFullPath($header).Replace('\', '/')
    }
    $text.Replace($headerText, "<header>")
}

Write-Output "[native bind-cpp 1/6] Usage, option, target, and module diagnostics."
Assert-EquivalentFailure "usage" @("bind-cpp")
Assert-EquivalentFailure "unknown option" @("bind-cpp", "--unknown")
Assert-EquivalentFailure "missing module value" @("bind-cpp", $header, "--module")
Assert-EquivalentFailure "unsupported target" @("bind-cpp", $header, "--target", "wasm32")
Assert-EquivalentFailure "invalid module" @("bind-cpp", $header, "--module", "not-valid")
Assert-EquivalentFailure "duplicate header" @("bind-cpp", $header, $header)

Write-Output "[native bind-cpp 2/6] Managed/native generation parity."
$managedArguments = @(
    "bind-cpp", $header,
    "--module", "cppFixture",
    "--library", "cppFixture_shim",
    "--output", $managedOutput,
    "--target", $Target,
    "--llvm", $managedLlvm,
    "--clang-arg", "-Wno-pragma-once-outside-header"
)
$nativeArguments = @(
    "bind-cpp", $header,
    "--module", "cppFixture",
    "--library", "cppFixture_shim",
    "--output", $nativeOutput,
    "--target", $Target,
    "--llvm", $nativeLlvm,
    "--clang-arg", "-Wno-pragma-once-outside-header"
)
$managed = Invoke-Compiler $false $managedArguments
$native = Invoke-Compiler $true $nativeArguments
if ($managed.ExitCode -ne 0 -or $native.ExitCode -ne 0 -or $managed.Stderr -ne "" -or $native.Stderr -ne "") {
    throw "bind-cpp generation failed.`nmanaged: $($managed.Stderr)`nnative: $($native.Stderr)"
}
$managedStdout = Normalize-SuccessOutput $managed.Stdout $managedOutput $false
$nativeStdout = Normalize-SuccessOutput $native.Stdout $nativeOutput $true
if ($managedStdout -ne $nativeStdout) {
    throw "bind-cpp success output differs.`nmanaged: $managedStdout`nnative: $nativeStdout"
}

$manifestName = "cppFixture.$Target.cppbind.json"
foreach ($name in @("cppFixture.slg", "cppFixture_shim.cpp", $manifestName)) {
    $managedPath = Join-Path $managedOutput $name
    $nativePath = Join-Path $nativeOutput $name
    if (-not (Test-Path -LiteralPath $managedPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $nativePath -PathType Leaf)) {
        throw "bind-cpp omitted generated artifact '$name'"
    }
    $managedText = Get-NormalizedGeneratedText $managedPath $false
    $nativeText = Get-NormalizedGeneratedText $nativePath $true
    if ($managedText -ne $nativeText) {
        throw "bind-cpp generated artifact differs: $name"
    }
}

Write-Output "[native bind-cpp 3/6] Deterministic native regeneration."
$before = @{}
foreach ($name in @("cppFixture.slg", "cppFixture_shim.cpp", $manifestName)) {
    $before[$name] = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $nativeOutput $name)).Hash
}
$repeat = Invoke-Compiler $true $nativeArguments
if ($repeat.ExitCode -ne 0 -or $repeat.Stdout -ne $native.Stdout -or $repeat.Stderr -ne "") {
    throw "native bind-cpp regeneration changed its command contract"
}
foreach ($name in $before.Keys) {
    $after = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $nativeOutput $name)).Hash
    if ($after -ne $before[$name]) {
        throw "native bind-cpp regeneration is not deterministic: $name"
    }
}

Write-Output "[native bind-cpp 4/6] Native --build and --build-arg."
$buildArguments = $nativeArguments + @("--build", "--build-arg", $(if ($Target -eq "linux-x64") { "-fPIC" } else { "-Wno-unused-command-line-argument" }))
$built = Invoke-Compiler $true $buildArguments
if ($built.ExitCode -ne 0 -or $built.Stderr -ne "") {
    throw "native bind-cpp --build failed: $($built.Stderr)"
}
$library = if ($Target -eq "windows-x64") {
    Join-Path $nativeOutput "cppFixture_shim.dll"
}
else {
    Join-Path $nativeOutput "libcppFixture_shim.so"
}
if (-not (Test-Path -LiteralPath $library -PathType Leaf)) {
    throw "native bind-cpp --build omitted $library"
}

Write-Output "[native bind-cpp 5/6] Compile generated binding with the same native CLI."
$executable = if ($Target -eq "windows-x64") {
    Join-Path $nativeOutput "cpp-consumer.exe"
}
else {
    Join-Path $nativeOutput "cpp-consumer"
}
$build = Invoke-Compiler $true @(
    "build", (Join-Path $nativeOutput "cppFixture.slg"), $consumer,
    "-o", $executable,
    "--target", $Target,
    "--llvm", $nativeLlvm,
    "--stdlib", $stdlib,
    "-O2"
)
if ($build.ExitCode -ne 0) {
    throw "native compiler rejected its generated binding.`nstdout: $($build.Stdout)`nstderr: $($build.Stderr)"
}

Write-Output "[native bind-cpp 6/6] Execute generated binding consumer."
if ($Target -eq "windows-x64") {
    $actual = (& $executable | Out-String).Replace("`r`n", "`n").TrimEnd("`n")
}
else {
    $wslDirectory = Convert-ToWslPath $nativeOutput
    $wslExecutable = Convert-ToWslPath $executable
    $actual = (& wsl.exe -d $Distribution -- env "LD_LIBRARY_PATH=$wslDirectory" $wslExecutable |
        Out-String).Replace("`r`n", "`n").TrimEnd("`n")
}
if ($LASTEXITCODE -ne 0 -or $actual -ne $expected) {
    throw "generated binding consumer differs: expected '$expected', actual '$actual'"
}

Write-Output "Native bind-cpp verification passed for $Target (6/6)."
