# Shared compiler invocation for public runtime validators. Native Linux tests
# use checked LLVM emission and an explicit external linker, not CLI cross-linking.
$script:VerificationCompilerBuildModule = $PSCommandPath
$script:VerificationCompilerBuildConfiguration = Join-Path $PSScriptRoot 'contracts/verification-compiler-build.json'

function Resolve-VerificationCompilerInvocation {
    param([Parameter(Mandatory)][string]$Compiler)
    $path = [IO.Path]::GetFullPath($Compiler)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'VERIFICATION_COMPILER_MISSING' }
    $extension = [IO.Path]::GetExtension($path)
    if ($extension -ieq '.dll') {
        $dotnet = (Get-Command dotnet -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
        return [pscustomobject]@{ FilePath = $dotnet; Prefix = @($path); Kind = 'managed'; Identity = $path }
    }
    if ($extension -ine '.exe') { throw 'VERIFICATION_COMPILER_FORMAT_UNSUPPORTED' }
    $stem = [IO.Path]::Combine([IO.Path]::GetDirectoryName($path), [IO.Path]::GetFileNameWithoutExtension($path))
    $managed = (Test-Path -LiteralPath "$stem.dll") -and (Test-Path -LiteralPath "$stem.runtimeconfig.json") -and (Test-Path -LiteralPath "$stem.deps.json")
    return [pscustomobject]@{ FilePath = $path; Prefix = @(); Kind = $(if ($managed) { 'managed' } else { 'native' }); Identity = $path }
}

function Invoke-VerificationCompilerBuild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Compiler,
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Output,
        [Parameter(Mandatory)][ValidateSet('windows-x64', 'linux-x64')][string]$Target,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$Description,
        [string]$Distribution = 'Ubuntu',
        [int]$TimeoutMilliseconds = 120000
    )
    $invocation = Resolve-VerificationCompilerInvocation -Compiler $Compiler
    $sourcePath = (Resolve-Path -LiteralPath $Source).Path
    $outputPath = [IO.Path]::GetFullPath($Output)
    $root = (Resolve-Path -LiteralPath $WorkingDirectory).Path
    $configurationPath = $script:VerificationCompilerBuildConfiguration
    $configuration = Get-Content -LiteralPath $configurationPath -Raw | ConvertFrom-Json
    if ($configuration.schemaVersion -ne 1) { throw 'VERIFICATION_COMPILER_CONFIGURATION_INVALID' }
    if ((Test-Path -LiteralPath $outputPath) -or (Test-Path -LiteralPath "$outputPath.ll")) { throw 'VERIFICATION_COMPILER_OUTPUT_NOT_FRESH' }
    $recordPath = "$outputPath.compiler-build.json"
    if (Test-Path -LiteralPath $recordPath) { throw 'VERIFICATION_COMPILER_RECORD_NOT_FRESH' }
    $inputs = @($invocation.Identity, $invocation.FilePath, $sourcePath, $configurationPath, $script:VerificationCompilerBuildModule)
    $stdlibSources = [IO.Directory]::GetFiles((Join-Path $root 'stdlib'), '*.slg', [IO.SearchOption]::AllDirectories)
    [Array]::Sort($stdlibSources, [StringComparer]::Ordinal)
    $inputs += @($stdlibSources)
    if ($invocation.Kind -eq 'managed') {
        $stem = $invocation.Identity.Substring(0, $invocation.Identity.Length - 4)
        $inputs += @("$stem.dll", "$stem.deps.json", "$stem.runtimeconfig.json")
    }
    $hashes = [ordered]@{}
    foreach ($path in $inputs) { $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
    $record = [ordered]@{ schemaVersion = 1; status = 'running'; target = $Target; compilerKind = $invocation.Kind; compiler = $invocation.Identity; output = $outputPath; inputHashes = $hashes; stdlibSourceOrder = $stdlibSources; steps = @(); inputsStable = $false; failure = $null }
    $clock = [Diagnostics.Stopwatch]::StartNew()
    function Save-CompilerBuildRecord {
        [IO.File]::WriteAllText($recordPath, ($record | ConvertTo-Json -Depth 12) + "`n", [Text.UTF8Encoding]::new($false))
    }
    function Invoke-CompilerBuildStep([string]$Id, [string]$File, [string[]]$Arguments) {
        $remaining = $TimeoutMilliseconds - [int]$clock.ElapsedMilliseconds
        if ($remaining -le 0) { throw 'VERIFICATION_COMPILER_TOTAL_BUDGET_EXHAUSTED' }
        $stepPath = "$outputPath.compiler-$Id.execution.json"
        $value = Invoke-VerificationProcessCapture -FilePath $File -ArgumentList $Arguments -WorkingDirectory $root -Description "$Description $Id" -TimeoutMilliseconds $remaining -ExecutionRecordPath $stepPath
        $record.steps += [ordered]@{ id = $Id; executionRecord = $stepPath; exitCode = $value.ExitCode }
        Save-CompilerBuildRecord
        return $value
    }
    Save-CompilerBuildRecord
    $result = $null
    try {
        if ($invocation.Kind -eq 'native' -and $Target -eq 'linux-x64') {
            $linux = $configuration.nativeLinux
            $record.mode = $linux.mode
            $wsl = (Get-Command wsl.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
            $version = Invoke-CompilerBuildStep 'clang-version' $wsl @('-d', $Distribution, '--', $linux.clangPath, '--version')
            if ($version.ExitCode -ne 0 -or -not $version.Stdout.Contains("clang version $($linux.clangVersion)")) { throw 'VERIFICATION_LINUX_CLANG_VERSION' }
            $identity = Invoke-CompilerBuildStep 'clang-hash' $wsl @('-d', $Distribution, '--', '/usr/bin/sha256sum', $linux.clangBinaryPath)
            if ($identity.ExitCode -ne 0 -or $identity.Stdout -notmatch '^([a-f0-9]{64})\s' -or $Matches[1].ToUpperInvariant() -cne $linux.clangSha256) { throw 'VERIFICATION_LINUX_CLANG_HASH' }
            $record.clangVersion = $version.Stdout.Trim()
            $record.clangSha256 = $linux.clangSha256
            $paths = @()
            foreach ($path in @("$outputPath.ll", $outputPath)) {
                $mapped = Invoke-CompilerBuildStep "path-$($paths.Count)" $wsl @('-d', $Distribution, '--', 'wslpath', '-a', $path.Replace('\', '/'))
                if ($mapped.ExitCode -ne 0 -or $mapped.Stdout.Trim() -notmatch '^/[^\r\n]+$') { throw 'VERIFICATION_LINUX_PATH_MAPPING' }
                $paths += $mapped.Stdout.Trim()
            }
            $emitted = Invoke-CompilerBuildStep 'emit-checked' $invocation.FilePath @($linux.emissionCommand, (Join-Path $root 'stdlib'), '--jobs', '4', $sourcePath)
            if ($emitted.ExitCode -ne 0) { $result = $emitted; return $result }
            [IO.File]::WriteAllText("$outputPath.ll", $emitted.Stdout, [Text.UTF8Encoding]::new($false))
            if (-not [string]::IsNullOrWhiteSpace($emitted.Stderr)) { throw 'VERIFICATION_LINUX_EMISSION_DIAGNOSTIC' }
            $triple = [regex]::Match($emitted.Stdout, '(?m)^target triple = "([^"\r\n]+)"')
            if (-not $triple.Success -or $triple.Groups[1].Value -cne $linux.targetTriple) { throw 'VERIFICATION_LINUX_TARGET_TRIPLE' }
            $record.llvmSha256 = (Get-FileHash -LiteralPath "$outputPath.ll" -Algorithm SHA256).Hash
            $seconds = [Math]::Floor(($TimeoutMilliseconds - $clock.ElapsedMilliseconds - 3000) / 1000)
            if ($seconds -lt 1) { throw 'VERIFICATION_COMPILER_TOTAL_BUDGET_EXHAUSTED' }
            $result = Invoke-CompilerBuildStep 'link-external' $wsl @('-d', $Distribution, '--', $linux.timeoutPath, '--kill-after=2s', "$($seconds)s", $linux.clangPath, "--target=$($linux.targetTriple)", '-O0', $paths[0], '-pthread', '-o', $paths[1])
            $identityAfter = Invoke-CompilerBuildStep 'clang-hash-final' $wsl @('-d', $Distribution, '--', '/usr/bin/sha256sum', $linux.clangBinaryPath)
            if ($identityAfter.ExitCode -ne 0 -or $identityAfter.Stdout -notmatch '^([a-f0-9]{64})\s' -or $Matches[1].ToUpperInvariant() -cne $linux.clangSha256) { throw 'VERIFICATION_LINUX_CLANG_CHANGED' }
        } else {
            $record.mode = "$($invocation.Kind)-build"
            $arguments = @($invocation.Prefix) + @('build', $sourcePath, '-o', $outputPath, '--target', $Target, '-O0', '--keep-temps')
            $arguments += @('--llvm', (Join-Path $root '.tools/llvm-22.1.8'))
            if ($invocation.Kind -eq 'native') { $arguments += @('--stdlib', (Join-Path $root 'stdlib'), '--jobs', '4') }
            $result = Invoke-CompilerBuildStep 'build' $invocation.FilePath $arguments
        }
        if ($result.ExitCode -eq 0 -and -not (Test-Path -LiteralPath $outputPath -PathType Leaf)) { throw 'VERIFICATION_COMPILER_OUTPUT_MISSING' }
        if ($result.ExitCode -eq 0 -and (Test-Path -LiteralPath "$outputPath.ll" -PathType Leaf)) {
            $record.llvmSha256 = (Get-FileHash -LiteralPath "$outputPath.ll" -Algorithm SHA256).Hash
        }
        return $result
    } catch {
        $record.failure = $_.Exception.Message
        throw
    } finally {
        $record.inputsStable = @($hashes.GetEnumerator() | Where-Object { -not (Test-Path -LiteralPath $_.Key -PathType Leaf) -or (Get-FileHash -LiteralPath $_.Key -Algorithm SHA256).Hash -cne $_.Value }).Count -eq 0
        $currentStdlibSources = [IO.Directory]::GetFiles((Join-Path $root 'stdlib'), '*.slg', [IO.SearchOption]::AllDirectories)
        [Array]::Sort($currentStdlibSources, [StringComparer]::Ordinal)
        $record.inputsStable = $record.inputsStable -and ($currentStdlibSources.Length -eq $stdlibSources.Length) -and ([string]::Join("`n", $currentStdlibSources) -ceq [string]::Join("`n", $stdlibSources))
        $record.processesStopped = @($record.steps | Where-Object { (Get-Content -LiteralPath $_.executionRecord -Raw | ConvertFrom-Json).processesStopped -ne $true }).Count -eq 0
        $record.status = if (-not $record.failure -and $result -and $result.ExitCode -eq 0 -and $record.inputsStable -and (Test-Path -LiteralPath $outputPath -PathType Leaf)) { 'passed' } else { 'failed' }
        Save-CompilerBuildRecord
        if (-not $record.inputsStable) { throw 'VERIFICATION_COMPILER_INPUT_DRIFT' }
    }
}

function Resolve-VerificationEmittedRuntime {
    param(
        [Parameter(Mandatory)][string]$LlvmPath,
        [Parameter(Mandatory)][string]$ProducerProof,
        [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCompilerSha256,
        [Parameter(Mandatory)][ValidateSet('windows-x64', 'linux-x64')][string]$Target,
        [Parameter(Mandatory)][string]$RepositoryRoot
    )
    $root = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $llvm = (Resolve-Path -LiteralPath $LlvmPath).Path
    $proofPath = (Resolve-Path -LiteralPath $ProducerProof).Path
    if (-not $llvm.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or
        -not $proofPath.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetExtension($llvm) -cne '.ll') { throw 'VERIFICATION_EMITTED_RUNTIME_BOUNDARY' }
    $proof = Get-Content -LiteralPath $proofPath -Raw | ConvertFrom-Json -AsHashtable
    if ($proof.status -cne 'passed' -or $proof.inputsStable -ne $true -or
        $proof.processesStopped -ne $true -or $proof.compilerKind -cne 'native' -or
        $proof.target -cne $Target -or $llvm -ine "$($proof.output).ll" -or
        $proof.llvmSha256 -cne (Get-FileHash -LiteralPath $llvm -Algorithm SHA256).Hash -or
        $proof.inputHashes[$proof.compiler] -cne $ExpectedCompilerSha256.ToUpperInvariant()) {
        throw 'VERIFICATION_EMITTED_RUNTIME_PRODUCER_INVALID'
    }
    foreach ($entry in $proof.inputHashes.GetEnumerator()) {
        if (-not (Test-Path -LiteralPath $entry.Key -PathType Leaf) -or
            (Get-FileHash -LiteralPath $entry.Key -Algorithm SHA256).Hash -cne $entry.Value) {
            throw "VERIFICATION_EMITTED_RUNTIME_INPUT_DRIFT: $($entry.Key)"
        }
    }
    if (@($proof.steps | Where-Object { $_.exitCode -ne 0 }).Count -ne 0) { throw 'VERIFICATION_EMITTED_RUNTIME_STAGE_FAILED' }
    $paths = @($llvm, $proofPath, $script:VerificationCompilerBuildModule, $script:VerificationCompilerBuildConfiguration) + @($proof.inputHashes.Keys)
    return [pscustomobject]@{ Path = $llvm; InputPaths = @($paths | Sort-Object -Unique); CompilerSha256 = $ExpectedCompilerSha256.ToUpperInvariant(); ProducerProof = $proofPath }
}
