[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ManagedCompiler,
    [Parameter(Mandatory)][string]$SelfhostCompiler,
    [Parameter(Mandatory)][string[]]$Fixture,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateRange(1000, 180000)][int]$TimeoutMilliseconds = 120000,
    [string[]]$AdditionalInput = @(),
    [string[]]$ReusableCompilerDirectories = @(),
    [string]$FormatCheckCompiler = '',
    [string[]]$FormatCheckSource = @(),
    [string]$LlvmObservationContract = '',
    [ValidateRange(1, 64)][int]$Jobs = 1
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')
. (Join-Path $PSScriptRoot 'ArtifactLifecycle.ps1')
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$managed = (Resolve-Path -LiteralPath $ManagedCompiler).Path
$selfhost = (Resolve-Path -LiteralPath $SelfhostCompiler).Path
$llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
$llvmAs = Join-Path $llvmRoot 'bin/llvm-as.exe'
$closure = Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1'
$sourceClosure = Join-Path $PSScriptRoot 'verify-source-manifest-closure.ps1'
$stdlib = Join-Path $root 'stdlib'
$output = [IO.Path]::GetFullPath($OutputDirectory, $root)
$seedOutput = [IO.Path]::GetDirectoryName($selfhost)
$usesPrivateSeed = $seedOutput.StartsWith((Join-Path $root 'artifacts/scratch') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and
    (Test-Path -LiteralPath (Join-Path $seedOutput 'result.json'))
if ($usesPrivateSeed) {
    $ReusableCompilerDirectories = @($ReusableCompilerDirectories | ForEach-Object {
        (Resolve-Path -LiteralPath $_).Path
    } | Select-Object -Unique)
    if ($seedOutput -notin $ReusableCompilerDirectories -or $ReusableCompilerDirectories.Count -gt 3) {
        throw 'Paired private compiler requires an explicit reusable compiler selection containing its producer (maximum three)'
    }
}
Initialize-ArtifactOutput -OutputDirectory $output -ReusableCompilerDirectories $ReusableCompilerDirectories
if (Test-Path -LiteralPath $output) { throw "Paired fixture output already exists: $output" }
if ($managed -ceq $selfhost) { throw 'Paired fixture compilers must be separate artifacts' }

$runtimeByFixture = @{}
if ($LlvmObservationContract) {
    $runtimeContract = Get-Content -LiteralPath $LlvmObservationContract -Raw | ConvertFrom-Json
    foreach ($fixtureContract in $runtimeContract.fixtures) {
        if ($fixtureContract.PSObject.Properties['runtime']) {
            $runtimeByFixture[$fixtureContract.name] = $fixtureContract.runtime
        }
    }
}
$cases = @(
    foreach ($name in $Fixture) {
        if ($name -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_-]*(?:\.[A-Za-z0-9][A-Za-z0-9_-]*)*$') { throw "Invalid fixture name: $name" }
        $source = Join-Path $root "examples/regression/$name.slg"
        $expected = Join-Path $root "examples/regression/expected/$name.stdout.txt"
        if (-not (Test-Path -LiteralPath $source -PathType Leaf) -or
            (-not $runtimeByFixture.ContainsKey($name) -and -not (Test-Path -LiteralPath $expected -PathType Leaf))) {
            throw "Paired fixture source or expected output is missing: $name"
        }
        $manifest = Join-Path $root "examples/regression/expected/$name.sources.txt"
        $sources = @(if (Test-Path -LiteralPath $manifest -PathType Leaf) {
            Get-Content -LiteralPath $manifest | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                ForEach-Object {
                    $entry = $_.Trim()
                    if ([IO.Path]::IsPathRooted($entry)) { throw "Absolute fixture source: $entry" }
                    $resolved = [IO.Path]::GetFullPath((Join-Path $root $entry))
                    if (-not $resolved.StartsWith($root + [IO.Path]::DirectorySeparatorChar,
                            [StringComparison]::OrdinalIgnoreCase) -or
                        [IO.Path]::GetExtension($resolved) -cne '.slg' -or
                        -not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
                        throw "Invalid fixture source: $entry"
                    }
                    $resolved
                }
        } else { $source })
        if ($sources.Count -eq 0 -or $source -notin $sources -or
            @($sources | Select-Object -Unique).Count -ne $sources.Count) {
            throw "Invalid fixture source manifest: $manifest"
        }
        $warningExpected = Join-Path $root "examples/regression/expected/$name.compiler.stderr.contains.txt"
        $compilerStderr = if (Test-Path -LiteralPath $warningExpected -PathType Leaf) {
            $text = [IO.File]::ReadAllText($warningExpected).Replace("`r`n", "`n").TrimEnd("`r", "`n")
            if ([string]::IsNullOrWhiteSpace($text)) { throw "Blank compiler diagnostic oracle: $warningExpected" }
            $text
        } else { '' }
        [pscustomobject]@{
            Name = $name; Source = $source; Sources = $sources; Expected = $expected
            CompilerStderr = $compilerStderr
            Runtime = if ($runtimeByFixture.ContainsKey($name)) { $runtimeByFixture[$name] } else { $null }
            CompilerStderrExpected = if (Test-Path -LiteralPath $warningExpected -PathType Leaf) { $warningExpected } else { $null }
            Manifest = if (Test-Path -LiteralPath $manifest -PathType Leaf) { $manifest } else { $null }
        }
    }
)
if ($cases.Count -eq 0 -or @($cases.Name | Select-Object -Unique).Count -ne $cases.Count) {
    throw 'Paired fixtures must contain distinct names'
}
$managedRuntime = @('Sollang.Compiler.dll', 'Sollang.Compiler.deps.json',
    'Sollang.Compiler.runtimeconfig.json') | ForEach-Object {
    Join-Path (Split-Path -Parent $managed) $_
}
$stdlibSources = @(Get-ChildItem -LiteralPath $stdlib -Recurse -File -Filter '*.slg' |
    Sort-Object -Property FullName | ForEach-Object { $_.FullName })
$extraInputs = @($AdditionalInput | ForEach-Object { (Resolve-Path -LiteralPath $_).Path })
$observationScript = Join-Path $PSScriptRoot 'verification_llvm_observations.py'
$observationContract = if ($LlvmObservationContract) { (Resolve-Path -LiteralPath $LlvmObservationContract).Path } else { $null }
$observationPython = if ($observationContract) { (Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source } else { $null }
if ($observationContract) {
    & $observationPython -X utf8 $observationScript --repo $root --contract $observationContract --check-fixtures ($Fixture -join ',')
    if ($LASTEXITCODE -ne 0) { throw 'LLVM_OBSERVATION_PREFLIGHT_FAILED' }
}
if (($FormatCheckSource.Count -gt 0) -ne (-not [string]::IsNullOrWhiteSpace($FormatCheckCompiler))) {
    throw 'Format preflight requires both compiler and source inputs'
}
$formatExecutable = if ($FormatCheckSource.Count -gt 0) { (Resolve-Path -LiteralPath $FormatCheckCompiler).Path } else { $null }
$formatSources = @($FormatCheckSource | ForEach-Object {
    $resolved = (Resolve-Path -LiteralPath $_).Path
    if (-not $resolved.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetExtension($resolved) -ine '.slg') { throw "Invalid format preflight source: $_" }
    $resolved
} | Select-Object -Unique)
$inputs = @($managed, $selfhost, $llvmAs, $closure, $sourceClosure,
    (Join-Path $PSScriptRoot 'source-module-header.ps1'), $PSCommandPath,
    (Join-Path $PSScriptRoot 'verification-process.ps1')) +
    $managedRuntime + $stdlibSources +
    @($cases | ForEach-Object { $_.Sources; if (-not $_.Runtime) { $_.Expected }; if ($_.Manifest) { $_.Manifest }; if ($_.CompilerStderrExpected) { $_.CompilerStderrExpected } }) +
    $extraInputs + @($formatSources) + @(if ($formatExecutable) { $formatExecutable }) +
    @(if ($observationContract) { $observationContract; $observationScript; $observationPython })
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing paired fixture input: $path" }
}
function InputHashes {
    $hashes = [ordered]@{}
    foreach ($path in $inputs) { $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
    $hashes
}
$script:pairedCaseClock = $null
function Invoke-CaseProcess([string]$file, [string[]]$arguments, [string]$description, [string]$prefix, [int]$processTimeoutMilliseconds = $TimeoutMilliseconds) {
    if ($null -ne $script:pairedCaseClock) {
        $remaining = [long]$TimeoutMilliseconds - $script:pairedCaseClock.ElapsedMilliseconds
        if ($remaining -le 0) { throw "PAIRED_CASE_BUDGET_EXHAUSTED: $description" }
        $processTimeoutMilliseconds = [int][Math]::Min($processTimeoutMilliseconds, $remaining)
    }
    $run = Invoke-VerificationProcessCapture -FilePath $file -ArgumentList $arguments `
        -WorkingDirectory $root -Description $description -TimeoutMilliseconds $processTimeoutMilliseconds `
        -ExecutionRecordPath "$prefix.execution.json"
    [IO.File]::WriteAllText("$prefix.stdout.txt", $run.Stdout, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText("$prefix.stderr.txt", $run.Stderr, [Text.UTF8Encoding]::new($false))
    if ($null -ne $script:pairedCaseClock -and $script:pairedCaseClock.ElapsedMilliseconds -gt $TimeoutMilliseconds) {
        throw "PAIRED_CASE_BUDGET_EXHAUSTED: $description"
    }
    $run
}
function Normalized([string]$value) { $value.Replace("`r`n", "`n") }

$startHashes = InputHashes
[IO.Directory]::CreateDirectory($output) | Out-Null
$rows = [System.Collections.Generic.List[object]]::new()
$formatRows = [System.Collections.Generic.List[object]]::new()
$sourceClosureRows = [System.Collections.Generic.List[object]]::new()
$failure = $null
try {
    # Resolve every declared import before starting either compiler. A retained
    # fixture manifest can become incomplete when a shared module adds imports.
    foreach ($case in $cases) {
        $sourceClosureLog = Join-Path $output "$($case.Name).source-closure.stdout.txt"
        $additionalStdlibSources = @($stdlibSources | Where-Object { $_ -notin $case.Sources })
        & $sourceClosure -SourcePath @($case.Sources + $additionalStdlibSources) > $sourceClosureLog
        $sourceClosureRows.Add([pscustomobject]@{ Fixture = $case.Name; Status = 'passed'; Log = $sourceClosureLog })
    }
    foreach ($source in $formatSources) {
        $prefix = Join-Path $output "format-preflight$($formatRows.Count)"
        $format = Invoke-CaseProcess $formatExecutable @('format', $source, '--check') `
            "paired format preflight $source" $prefix ([Math]::Min(10000, $TimeoutMilliseconds))
        $formatRows.Add([pscustomobject]@{ Source = $source; Exit = $format.ExitCode; ExecutionRecord = "$prefix.execution.json" })
        if ($format.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($format.Stderr)) {
            throw "FORMAT_PREFLIGHT_FAILED: $source"
        }
    }
    foreach ($case in $cases) {
        $expected = if ($case.Runtime) { Normalized $case.Runtime.stdout } else { Normalized ([IO.File]::ReadAllText($case.Expected)) }
        foreach ($compiler in @(
            [pscustomobject]@{ Name = 'managed'; Path = $managed; Stdlib = $false },
            [pscustomobject]@{ Name = 'selfhost'; Path = $selfhost; Stdlib = $true }
        )) {
            $script:pairedCaseClock = [Diagnostics.Stopwatch]::StartNew()
            $prefix = Join-Path $output "$($case.Name).$($compiler.Name)"
            $exe = "$prefix.exe"
            $arguments = @('build') + @($case.Sources) + @('-o', $exe, '--target', 'windows-x64',
                '--llvm', $llvmRoot, '-O1', '--jobs', [string]$Jobs, '--keep-temps')
            if ($compiler.Stdlib) { $arguments += @('--stdlib', $stdlib) }
            if ([IO.Path]::GetExtension($compiler.Path) -ieq '.dll') {
                $build = Invoke-CaseProcess 'dotnet' (@($compiler.Path) + $arguments) `
                    "paired $($case.Name) $($compiler.Name) build" "$prefix.build"
            } else {
                $build = Invoke-CaseProcess $compiler.Path $arguments `
                    "paired $($case.Name) $($compiler.Name) build" "$prefix.build"
            }
            $llvmPaths = @(@("$prefix.ll", "$exe.ll") | Where-Object {
                Test-Path -LiteralPath $_ -PathType Leaf
            })
            # This paired consumer requires the entire declared compiler stderr,
            # including every warning line. A fragment-only catalog oracle does
            # not authorize accepting extra diagnostics or a different channel.
            $compilerStderr = (Normalized $build.Stderr).TrimEnd("`r", "`n")
            if ($build.ExitCode -ne 0 -or $compilerStderr -cne $case.CompilerStderr -or
                [regex]::IsMatch($build.Stdout, '(?im)^(warning|note)\b') -or
                $llvmPaths.Count -ne 1) {
                throw "Paired build failed or diagnosed: $($case.Name) $($compiler.Name)"
            }
            $llvmPath = $llvmPaths[0]
            $assemble = Invoke-CaseProcess $llvmAs @($llvmPath, '-o', "$prefix.bc") `
                "paired $($case.Name) LLVM assemble" "$prefix.as"
            $directCalls = Invoke-CaseProcess 'pwsh' @('-NoProfile', '-File', $closure, '-LlvmPath', $llvmPath) `
                "paired $($case.Name) direct-call closure" "$prefix.closure"
            $observationLink = $null
            if ($observationContract -and $compiler.Name -ceq 'selfhost') {
                $observationPath = "$prefix.llvm-observation.json"
                $observation = Invoke-CaseProcess $observationPython @('-X', 'utf8', $observationScript,
                    '--repo', $root, '--contract', $observationContract, '--fixture', $case.Name,
                    '--llvm', $llvmPath, '--compiler', $compiler.Path, '--output', $observationPath) `
                    "paired $($case.Name) LLVM observations" "$prefix.observations"
                if ($observation.ExitCode -ne 0) { throw "LLVM_OBSERVATION_FAILED: $($case.Name)" }
                $observationLink = @{ path = $observationPath; sha256 = (Get-FileHash -LiteralPath $observationPath -Algorithm SHA256).Hash }
            }
            $native = Invoke-CaseProcess $exe @() "paired $($case.Name) native run" "$prefix.native"
            $actual = Normalized $native.Stdout
            $expectedExit = if ($case.Runtime) { [int]$case.Runtime.exit } else { 0 }
            $expectedStderr = if ($case.Runtime) { $case.Runtime.stderr.($compiler.Name) } else { '' }
            $actualStderr = if ($case.Runtime) { (Normalized $native.Stderr).TrimEnd("`r", "`n") } else { Normalized $native.Stderr }
            if ($assemble.ExitCode -ne 0 -or $directCalls.ExitCode -ne 0 -or
                $native.ExitCode -ne $expectedExit -or $actualStderr -cne $expectedStderr -or $actual -cne $expected) {
                throw "Paired native or LLVM result failed: $($case.Name) $($compiler.Name)"
            }
            $rows.Add([ordered]@{
                fixture = $case.Name
                compiler = $compiler.Name
                compilerSha256 = $startHashes[$compiler.Path]
                sourceSha256 = $startHashes[$case.Source]
                stdoutSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData(
                    [Text.Encoding]::UTF8.GetBytes($actual)))
                expectedCompilerStderr = $case.CompilerStderr
                actualCompilerStderr = $compilerStderr
                buildExit = $build.ExitCode
                llvmAsExit = $assemble.ExitCode
                directCallExit = $directCalls.ExitCode
                nativeExit = $native.ExitCode
                runtimeStdout = $actual
                runtimeStderr = $actualStderr
                llvmObservation = $observationLink
                caseBudgetMilliseconds = $TimeoutMilliseconds
                caseElapsedMilliseconds = $script:pairedCaseClock.ElapsedMilliseconds
            })
            $script:pairedCaseClock.Stop()
            $script:pairedCaseClock = $null
        }
    }
} catch {
    $failure = $_.Exception.Message
} finally {
    $endHashes = InputHashes
    $drift = @($inputs | Where-Object { $startHashes[$_] -cne $endHashes[$_] })
    if ($drift.Count -gt 0) { $failure = "Input drift: $($drift -join ', '); $failure" }
    $processRecords = @(Get-ChildItem -LiteralPath $output -File -Filter '*.execution.json' |
        ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json })
    $processesStopped = $processRecords.Count -gt 0 -and @($processRecords | Where-Object processesStopped -ne $true).Count -eq 0
    if (-not $processesStopped) { $failure = "PAIRED_PROCESS_SHUTDOWN_UNVERIFIED: $failure" }
    $generatedHashes = [ordered]@{}
    Get-ChildItem -LiteralPath $output -Recurse -File | Where-Object {
        $_.Extension -cin @('.exe', '.dll', '.ll', '.bc', '.obj', '.o', '.pdb') -or $_.FullName.Contains('.sollang-cache')
    } | ForEach-Object { $generatedHashes[$_.FullName] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    $result = [ordered]@{
        schemaVersion = 1
        status = if ($null -eq $failure -and $rows.Count -eq 2 * $cases.Count) { 'passed' } else { 'failed' }
        completed = [int][Math]::Floor($rows.Count / 2.0)
        total = $cases.Count
        timeoutMilliseconds = $TimeoutMilliseconds
        jobs = $Jobs
        inputStable = $drift.Count -eq 0
        inputsStable = $drift.Count -eq 0
        processesStopped = $processesStopped
        generatedOutputHashes = $generatedHashes
        inputHashesStart = $startHashes
        inputHashesEnd = $endHashes
        runs = @($rows.ToArray())
        formatPreflightRuns = @($formatRows.ToArray())
        sourceManifestPreflightRuns = @($sourceClosureRows.ToArray())
        failure = $failure
    }
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $output 'result.json') -Encoding utf8
}
if ($null -ne $failure) { throw "$failure result=$(Join-Path $output 'result.json')" }
Complete-VerifiedArtifactOutput -OutputDirectory $output -ReusableCompilerDirectories $ReusableCompilerDirectories
# The caller owns the shared compiler's lifecycle and any other pending consumers.
# This consumer closes only the fixture output it created.
Write-Host "[compiler paired native] PASS $($cases.Count)/$($cases.Count); result=$(Join-Path $output 'result.json')"
