param(
    [ValidateSet("windows-x64", "linux-x64")]
    [string]$Target = "windows-x64",
    [string]$CompilerPath,
    [string]$Distribution = "Ubuntu",
    [string]$LlvmHome
)

$ErrorActionPreference = "Stop"
$started = [Diagnostics.Stopwatch]::StartNew()
$repoRoot = Split-Path -Parent $PSScriptRoot
$bootstrapCompiler = Get-ChildItem -LiteralPath (Join-Path $repoRoot "src/Sollang.Compiler/bin/Release") `
    -Recurse -Filter "Sollang.Compiler.dll" | Sort-Object LastWriteTimeUtc -Descending | `
    Select-Object -First 1 -ExpandProperty FullName
$compiler = if ([string]::IsNullOrWhiteSpace($CompilerPath)) {
    $bootstrapCompiler
} else {
    (Resolve-Path -LiteralPath $CompilerPath).Path
}
$successProject = Join-Path $repoRoot "tests/Sollang.NativeTestFixtures/success"
$failureSource = Join-Path $repoRoot "tests/Sollang.NativeTestFixtures/failure.slg"
$invalidSource = Join-Path $repoRoot "tests/Sollang.NativeTestFixtures/invalid-signature.slg"
$noTestsSource = Join-Path $repoRoot "tests/Sollang.NativeTestFixtures/no-tests.slg"
$duplicateSourceA = Join-Path $repoRoot "tests/Sollang.NativeTestFixtures/duplicate-a.slg"
$duplicateSourceB = Join-Path $repoRoot "tests/Sollang.NativeTestFixtures/duplicate-b.slg"
$llvm = if ([string]::IsNullOrWhiteSpace($LlvmHome)) {
    if ($Target -eq "linux-x64") {
        Join-Path $repoRoot "scripts/linux-cross-llvm"
    } else {
        Join-Path $repoRoot ".tools/llvm-22.1.8"
    }
} else {
    [IO.Path]::GetFullPath($LlvmHome)
}
$stdlib = Join-Path $repoRoot "stdlib"
$stdlibArguments = if ([IO.Path]::GetExtension($compiler) -eq ".dll") {
    @()
} else {
    @("--stdlib", $stdlib)
}
$commonArguments = @("--target", $Target, "--llvm", $llvm) + $stdlibArguments + @("-O1")
$caseCount = 10
$isManagedCompiler = [IO.Path]::GetExtension($compiler) -eq ".dll"
$isLinuxNativeCompiler = $Target -eq "linux-x64" -and -not $isManagedCompiler

function Convert-ToWslPath {
    param([string]$Path)

    $absolute = [IO.Path]::GetFullPath($Path)
    $drive = $absolute.Substring(0, 1).ToLowerInvariant()
    $tail = $absolute.Substring(3).Replace('\', '/')
    "/mnt/$drive/$tail"
}

function Convert-CompilerArgument {
    param([string]$Argument)

    if ($isLinuxNativeCompiler -and $Argument -match '^[A-Za-z]:[\\/]') {
        return Convert-ToWslPath $Argument
    }
    $Argument
}

$compilerExecutable = if ($isLinuxNativeCompiler) {
    "wsl.exe"
} elseif ($isManagedCompiler) {
    "dotnet"
} else {
    $compiler
}
$compilerPrefix = if ($isLinuxNativeCompiler) {
    @("-d", $Distribution, "--", (Convert-ToWslPath $compiler))
} elseif ($isManagedCompiler) {
    @($compiler)
} else {
    @()
}

function Invoke-Compiler {
    param([string[]]$Arguments)

    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $compilerExecutable
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @($compilerPrefix) + $Arguments) {
        $start.ArgumentList.Add((Convert-CompilerArgument $argument))
    }
    $process = [Diagnostics.Process]::Start($start)
    if ($null -eq $process) {
        throw "failed to start compiler: $compilerExecutable"
    }
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit([int][TimeSpan]::FromMinutes(5).TotalMilliseconds)) {
        $process.Kill($true)
        throw "compiler exceeded the five-minute timeout"
    }
    [Threading.Tasks.Task]::WaitAll(@($stdout, $stderr))
    [pscustomobject]@{
        ExitCode = $process.ExitCode
        Output = $stdout.Result + $stderr.Result
    }
}

function Invoke-Case {
    param(
        [int]$Index,
        [string]$Name,
        [string[]]$Arguments,
        [int]$ExpectedExit,
        [string[]]$ExpectedText,
        [string[]]$ForbiddenText = @()
    )

    $percent = [int]($Index * 100 / $caseCount)
    Write-Host "[$Index/$caseCount] $percent% $Name (elapsed $([math]::Round($started.Elapsed.TotalSeconds, 1))s)"
    $result = Invoke-Compiler -Arguments $Arguments
    $exitCode = $result.ExitCode
    $output = $result.Output
    if ($exitCode -ne $ExpectedExit) {
        throw "$Name exited $exitCode instead of $ExpectedExit`n$output"
    }
    $position = 0
    foreach ($text in $ExpectedText) {
        $next = $output.IndexOf($text, $position, [StringComparison]::Ordinal)
        if ($next -lt 0) {
            throw "$Name did not contain '$text' in contract order`n$output"
        }
        $position = $next + $text.Length
    }
    foreach ($text in $ForbiddenText) {
        if ($output.Contains($text, [StringComparison]::Ordinal)) {
            throw "$Name unexpectedly contained '$text'`n$output"
        }
    }
}

if (-not $compiler -or -not (Test-Path -LiteralPath $compiler)) {
    throw "Release compiler not found: $compiler"
}

Invoke-Case 1 "project discovery and ordering" (@("test", "--project", $successProject) + $commonArguments) 0 @(
    "test native_tests.tests.test_addition ... ok",
    "test native_tests.tests.test_only_import ... ok",
    "test native_tests.tests.test_subtraction ... ok",
    "3 passed; 0 failed"
)
Invoke-Case 2 "name filtering" (@("test", "--project", $successProject, "--filter", "addition") + $commonArguments) 0 @(
    "running 1 tests",
    "test native_tests.tests.test_addition ... ok",
    "1 passed; 0 failed"
) @("test_subtraction", "test_only_import")
Invoke-Case 3 "native failure status" (@("test", $failureSource) + $commonArguments) 1 @("0 passed; 1 failed")
Invoke-Case 4 "signature validation" (@("test", $invalidSource) + $commonArguments) 1 @(
    "must be a non-generic, zero-input, non-intrinsic function returning Bool"
)
Invoke-Case 5 "no-test discovery diagnostic" (@("test", $noTestsSource) + $commonArguments) 1 @(
    "no tests found; declare a zero-input Bool function whose name starts with 'test_'; available functions: helper"
)
Invoke-Case 6 "unmatched filter diagnostic" (@("test", "--project", $successProject, "--filter", "missing") + $commonArguments) 1 @(
    "no tests matched filter 'missing'"
)
Invoke-Case 7 "duplicate filter diagnostic" (@("test", "--project", $successProject, "--filter", "addition", "--filter", "subtraction") + $commonArguments) 1 @(
    "--filter may be specified only once"
)
Invoke-Case 8 "missing filter value diagnostic" (@("test", "--project", $successProject) + $commonArguments + @("--filter")) 1 @(
    "missing value for --filter"
)
Invoke-Case 9 "duplicate qualified test names" (@("test", $duplicateSourceA, $duplicateSourceB) + $commonArguments) 1 @(
    "test names must be unique after module qualification"
)

$suffix = if ($Target -eq "windows-x64") { ".tests.exe" } else { ".tests" }
$projectOutput = Join-Path $successProject ".sollang/test/$Target/native_tests$suffix"
$sourceOutput = Join-Path (Split-Path -Parent $failureSource) ".sollang/test/$Target/failure$suffix"
$percent = [int](10 * 100 / $caseCount)
Write-Host "[10/$caseCount] $percent% output naming (elapsed $([math]::Round($started.Elapsed.TotalSeconds, 1))s)"
if (-not (Test-Path -LiteralPath $projectOutput)) {
    throw "project test output was not written to $projectOutput"
}
if (-not (Test-Path -LiteralPath $sourceOutput)) {
    throw "direct-source test output was not written to $sourceOutput"
}

Write-Host "[$caseCount/$caseCount] 100% native test framework verified for $Target with $compiler (elapsed $([math]::Round($started.Elapsed.TotalSeconds, 1))s)"
exit 0
