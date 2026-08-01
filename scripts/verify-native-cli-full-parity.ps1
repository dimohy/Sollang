[CmdletBinding()]
param(
    [ValidateSet("windows-x64", "linux-x64")]
    [string]$Target = "windows-x64",
    [string]$Compiler = "",
    [string]$ManagedCompiler = "",
    [string]$Distribution = "Ubuntu"
)

$ErrorActionPreference = "Stop"
$started = [Diagnostics.Stopwatch]::StartNew()
$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Compiler)) {
    $Compiler = if ($Target -eq "windows-x64") {
        Join-Path $repoRoot "artifacts\example-tests\selfhost-stage3.exe"
    }
    else {
        Join-Path $repoRoot "artifacts\example-tests\selfhost-stage3-linux"
    }
}
if ([string]::IsNullOrWhiteSpace($ManagedCompiler)) {
    $ManagedCompiler = Join-Path $repoRoot "src\Sollang.Compiler\bin\Release\net11.0\Sollang.Compiler.dll"
}
$Compiler = (Resolve-Path -LiteralPath $Compiler).Path
$ManagedCompiler = (Resolve-Path -LiteralPath $ManagedCompiler).Path
$stdlib = Join-Path $repoRoot "stdlib"
$llvm = if ($Target -eq "windows-x64") {
    Join-Path $repoRoot ".tools\llvm-22.1.8"
}
else {
    Join-Path $repoRoot "scripts\linux-cross-llvm"
}
$compilerHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Compiler).Hash
$expectedVersion = (& dotnet $ManagedCompiler --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($expectedVersion)) {
    throw "managed compiler version contract is unavailable"
}

function Convert-ToWslPath {
    param([Parameter(Mandatory)] [string]$Path)

    $absolute = [IO.Path]::GetFullPath($Path)
    $drive = $absolute.Substring(0, 1).ToLowerInvariant()
    $tail = $absolute.Substring(3).Replace('\', '/')
    "/mnt/$drive/$tail"
}

function Invoke-CompilerContract {
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
            $start.ArgumentList.Add((Convert-ToWslPath $Compiler))
        }
        else {
            $start.FileName = $Compiler
        }
    }
    else {
        $start.FileName = "dotnet"
        $start.ArgumentList.Add($ManagedCompiler)
    }
    foreach ($argument in $Arguments) {
        $start.ArgumentList.Add($argument)
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

function Invoke-Verifier {
    param(
        [string]$Name,
        [string]$Script,
        [string[]]$Arguments
    )

    Write-Host "[full parity] $Name"
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot $Script) @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Name verifier exited with $LASTEXITCODE"
    }
}

Write-Host "[full parity 1/7] Exact top-level command, alias, help, diagnostic, stream, and exit-code parity."
$contractCases = @(
    @{ Name = "empty"; Arguments = @() },
    @{ Name = "version"; Arguments = @("--version") },
    @{ Name = "short version"; Arguments = @("-v") },
    @{ Name = "help"; Arguments = @("--help") },
    @{ Name = "short help"; Arguments = @("-h") },
    @{ Name = "help command"; Arguments = @("help") },
    @{ Name = "unknown command"; Arguments = @("unknown") },
    @{ Name = "grammar usage"; Arguments = @("grammar") },
    @{ Name = "grammar subcommand"; Arguments = @("grammar", "unknown") },
    @{ Name = "build option"; Arguments = @("build", "--unknown") },
    @{ Name = "run option"; Arguments = @("run", "--unknown") },
    @{ Name = "test option"; Arguments = @("test", "--unknown") },
    @{ Name = "format option"; Arguments = @("format", "--unknown") },
    @{ Name = "resolve option"; Arguments = @("resolve", "--unknown") },
    @{ Name = "language-server arguments"; Arguments = @("language-server", "unexpected") },
    @{ Name = "bind-cpp option"; Arguments = @("bind-cpp", "--unknown") }
)
foreach ($case in $contractCases) {
    $managed = Invoke-CompilerContract $false $case.Arguments
    $native = Invoke-CompilerContract $true $case.Arguments
    if ($managed.ExitCode -ne $native.ExitCode -or
        $managed.Stdout -ne $native.Stdout -or
        $managed.Stderr -ne $native.Stderr) {
        throw "$($case.Name) differs.`nmanaged: exit=$($managed.ExitCode) stdout='$($managed.Stdout)' stderr='$($managed.Stderr)'`nnative: exit=$($native.ExitCode) stdout='$($native.Stdout)' stderr='$($native.Stderr)'"
    }
}

Write-Host "[full parity 2/7] Source, project, workspace, dependency, lock, build, run, and grammar contracts."
if ($Target -eq "windows-x64") {
    Invoke-Verifier "Windows native build/run" "verify-native-cli-build-run.ps1" @(
        "-Compiler", $Compiler,
        "-LlvmHome", $llvm,
        "-StdlibRoot", $stdlib)
}
else {
    Invoke-Verifier "Linux native build/run" "verify-native-cli-build-run-linux.ps1" @(
        "-Compiler", $Compiler,
        "-Distribution", $Distribution,
        "-LlvmHome", $llvm,
        "-StdlibRoot", $stdlib)
    Invoke-Verifier "Linux native grammar build" "verify-native-grammar-build.ps1" @(
        "-ManagedCompiler", $ManagedCompiler,
        "-NativeCompiler", $Compiler,
        "-Target", $Target,
        "-Distribution", $Distribution)
}

Write-Host "[full parity 3/7] Native test command matrix."
Invoke-Verifier "native test" "verify-native-tests.ps1" @(
    "-Target", $Target,
    "-CompilerPath", $Compiler,
    "-Distribution", $Distribution,
    "-LlvmHome", $llvm)

Write-Host "[full parity 4/7] Native format command matrix."
Invoke-Verifier "native format" "verify-native-cli-format.ps1" @(
    "-Target", $Target,
    "-Compiler", $Compiler,
    "-Distribution", $Distribution)

Write-Host "[full parity 5/7] Native streaming language-server matrix."
Invoke-Verifier "native language server" "verify-native-language-server.ps1" @(
    "-ManagedCompiler", $ManagedCompiler,
    "-NativeCompiler", $Compiler,
    "-Target", $Target,
    "-Distribution", $Distribution)

Write-Host "[full parity 6/7] Native bind-cpp generation, build, and execution matrix."
Invoke-Verifier "native bind-cpp" "verify-native-bind-cpp.ps1" @(
    "-ManagedCompiler", $ManagedCompiler,
    "-NativeCompiler", $Compiler,
    "-Target", $Target,
    "-Distribution", $Distribution)

Write-Host "[full parity 7/7] Bind proof to the immutable compiler hash and version."
$finalHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Compiler).Hash
if ($finalHash -ne $compilerHash) {
    throw "compiler changed during full parity verification: before=$compilerHash after=$finalHash"
}
$nativeVersion = (Invoke-CompilerContract $true @("--version"))
if ($nativeVersion.ExitCode -ne 0 -or $nativeVersion.Stdout.Trim() -ne $expectedVersion -or $nativeVersion.Stderr -ne "") {
    throw "native version contract changed during full parity verification"
}
$runtime = if ($Target -eq "windows-x64") { "win-x64" } else { "linux-x64" }
$proofRoot = Join-Path $repoRoot "artifacts\native-cli-full-parity"
New-Item -ItemType Directory -Path $proofRoot -Force | Out-Null
$proofPath = Join-Path $proofRoot "$runtime-$compilerHash.verified"
[IO.File]::WriteAllText($proofPath, $expectedVersion)
$evidence = [ordered]@{
    target = $Target
    compiler = $Compiler
    sha256 = $compilerHash
    version = $expectedVersion
    topLevelContractCases = $contractCases.Count
    verifiers = @("build-run", "grammar-build", "test", "format", "language-server", "bind-cpp")
    elapsedSeconds = [Math]::Round($started.Elapsed.TotalSeconds, 3)
}
$evidence | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$proofPath.json" -Encoding utf8NoBOM
Write-Host "Full native CLI parity verified for $Target and $compilerHash ($([Math]::Round($started.Elapsed.TotalMinutes, 1)) minutes)."
