[CmdletBinding()]
param(
    [string[]]$Fixture = @("examples/regression/582-billion-sensor-alerts.slg"),
    [ValidateSet("windows", "linux")]
    [string]$Target = "windows",
    [string]$WslDistribution = "Ubuntu",
    [ValidateSet("O0", "O1")]
    [string]$Stage1Optimization = "O0",
    [switch]$Stage1AddressSanitizer,
    [ValidateRange(0, 256)]
    [int]$FixtureBuildJobs = 0,
    [ValidateRange(1000, 3600000)]
    [int]$CompilerTimeoutMilliseconds = 3600000,
    [ValidateSet("Slg", "ManagedRecovery")]
    [string]$SeedMode = "Slg",
    [string]$SlgSeedCompiler = "",
    [bool]$ManagedDifferential = $true,
    [switch]$ManagedOracleOnly,
    [bool]$CompareStage2 = $true,
    [switch]$BootstrapStage2,
    [switch]$RebuildStage2,
    [switch]$NoExecute,
    [switch]$ProfilePhases,
    [switch]$ProfileExpressionTypesOnly,
    [switch]$ProfileArtifacts,
    [ValidateRange(0, 1000000)]
    [int]$ProfileSourcePrefix = 0,
    [ValidateRange(0, 1000000)]
    [int]$ProfileFunctionPrefix = 0,
    [string]$ProfileOutput = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$compilerProject = Join-Path $repoRoot "src\Sollang.Compiler\Sollang.Compiler.csproj"
$managedFormatterCompiler = Join-Path $repoRoot "src\Sollang.Compiler\bin\Release\net11.0\Sollang.Compiler.dll"
. (Join-Path $PSScriptRoot "verification-process.ps1")
. (Join-Path $PSScriptRoot "compiler-emission-fingerprint.ps1")
$fixtureRoots = @($Fixture | ForEach-Object {
    (Resolve-Path (Join-Path $repoRoot $_)).Path
})
$fixtureEntrypointRoots = @($fixtureRoots | Where-Object {
    [System.IO.File]::ReadAllText($_) -match '(?m)^main\s*\{'
})
if ($fixtureEntrypointRoots.Count -gt 1) {
    $relativeEntrypoints = $fixtureEntrypointRoots | ForEach-Object {
        [System.IO.Path]::GetRelativePath($repoRoot, $_).Replace('\', '/')
    }
    throw "-Fixture accepts one executable root plus its support sources; independent roots must be verified separately: $($relativeEntrypoints -join ', ')"
}
if ($ProfileArtifacts -and -not $ProfilePhases) {
    throw "-ProfileArtifacts requires -ProfilePhases."
}
if ($ProfileSourcePrefix -gt 0 -and ($ProfilePhases -or $ProfileExpressionTypesOnly -or $ProfileArtifacts)) {
    throw "-ProfileSourcePrefix is a focused diagnostic mode and cannot be combined with other profile modes."
}
if ($ProfileFunctionPrefix -gt 0 -and $ProfileSourcePrefix -le 0) {
    throw "-ProfileFunctionPrefix requires -ProfileSourcePrefix."
}
if (-not [string]::IsNullOrWhiteSpace($ProfileOutput) -and
    -not ($ProfilePhases -or $ProfileExpressionTypesOnly)) {
    throw "-ProfileOutput requires -ProfilePhases or -ProfileExpressionTypesOnly."
}
if (-not (Test-Path -LiteralPath $managedFormatterCompiler -PathType Leaf)) {
    Write-Host "[preflight] Managed formatter compiler is missing; building Release output."
    & dotnet build $compilerProject -c Release --nologo
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $managedFormatterCompiler -PathType Leaf)) {
        throw "managed formatter compiler build did not produce $managedFormatterCompiler"
    }
}
& (Join-Path $PSScriptRoot "verify-selfhost-compiler-contracts.ps1") `
    -RepositoryRoot $repoRoot
& (Join-Path $PSScriptRoot "format-authoritative-slg.ps1") -Check
& (Join-Path $PSScriptRoot "verify-each-call-result-source-selection.ps1") `
    -RepositoryRoot $repoRoot
$manifestPath = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-sollangc-driver.sources.txt"
$runtimeManifestPath = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures\selfhost-compiler-runtime.sources.txt"
& (Join-Path $PSScriptRoot "verify-source-manifest-closure.ps1") `
    -Manifest @($manifestPath, $runtimeManifestPath) `
    -RepositoryRoot $repoRoot
$llvmRoot = Join-Path $repoRoot ".tools\llvm-22.1.8"
$llvmAs = Join-Path $llvmRoot "bin\llvm-as.exe"
$clang = Join-Path $llvmRoot "bin\clang.exe"
$cacheRoot = Join-Path $repoRoot "artifacts\incremental-selfhost"
$stage1OptimizationName = $Stage1Optimization.ToLowerInvariant()
$stage1VariantName = if ($Stage1AddressSanitizer) {
    "$stage1OptimizationName-asan"
} else {
    $stage1OptimizationName
}
$stage1Compiler = Join-Path $cacheRoot "selfhost-stage1-host-$stage1VariantName.exe"
$managedStage1HostLlvm = [System.IO.Path]::ChangeExtension($stage1Compiler, ".ll")
$stage1Fingerprint = Join-Path $cacheRoot "selfhost-stage1-host-$stage1VariantName.inputs.sha256"
$stage1Receipt = [System.IO.Path]::ChangeExtension($stage1Compiler, ".sha256")
$stage1GenerationReceipt = [System.IO.Path]::ChangeExtension($stage1Compiler, ".generation.json")
$stage1HostLlvm = Join-Path $cacheRoot "selfhost-stage1-host.ll"
$stage1HostLlvmFingerprint = Join-Path $cacheRoot "selfhost-stage1-host.ll.sha256"
$stage2Compiler = Join-Path $cacheRoot "selfhost-stage2.exe"
$stage2Llvm = Join-Path $cacheRoot "selfhost-stage2.ll"
$stage2Fingerprint = Join-Path $cacheRoot "selfhost-stage2.sha256"
$bootstrapPerformancePairReceipt = Join-Path $cacheRoot "selfhost-bootstrap-performance-pair.json"
$defaultSlgSeedCompiler = Join-Path $cacheRoot "selfhost-slg-seed.exe"

if ($SeedMode -eq "Slg" -and -not $ManagedOracleOnly) {
    if ([string]::IsNullOrWhiteSpace($SlgSeedCompiler)) {
        $SlgSeedCompiler = $defaultSlgSeedCompiler
    }
    $SlgSeedCompiler = [System.IO.Path]::GetFullPath($SlgSeedCompiler)
    if ([string]::Equals(
        $SlgSeedCompiler,
        [System.IO.Path]::GetFullPath($stage1Compiler),
        [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "SLG seed compiler must not be the Stage1 output path: $SlgSeedCompiler. Use the receipt-bound stable seed at $defaultSlgSeedCompiler or another immutable verified seed."
    }
    $slgSeedReceipt = [System.IO.Path]::ChangeExtension($SlgSeedCompiler, ".sha256")
    if (-not (Test-Path -LiteralPath $SlgSeedCompiler) -or
        (Get-Item -LiteralPath $SlgSeedCompiler).Length -eq 0) {
        throw "verified SLG seed compiler is missing: $SlgSeedCompiler. Use -SeedMode ManagedRecovery only for an explicit bootstrap bridge."
    }
    if (-not (Test-Path -LiteralPath $slgSeedReceipt)) {
        throw "SLG seed has no completed verification receipt: $slgSeedReceipt"
    }
    $recordedSlgSeedHash = [System.IO.File]::ReadAllText($slgSeedReceipt).Trim()
    $actualSlgSeedHash = (Get-FileHash -LiteralPath $SlgSeedCompiler -Algorithm SHA256).Hash
    if ($recordedSlgSeedHash -ne $actualSlgSeedHash) {
        throw "SLG seed does not match its verification receipt: $SlgSeedCompiler"
    }
}

New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null

function Resolve-Manifest {
    param([string]$Path)
    Get-Content -LiteralPath $Path |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { (Resolve-Path (Join-Path $repoRoot $_.Trim())).Path }
}

function Get-ContentFingerprint {
    param([string[]]$Paths)
    $hash = [System.Security.Cryptography.IncrementalHash]::CreateHash(
        [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    foreach ($path in $Paths) {
        $relative = [System.IO.Path]::GetRelativePath($repoRoot, $path).Replace("\", "/")
        $nameBytes = [System.Text.Encoding]::UTF8.GetBytes("$relative`0")
        $hash.AppendData($nameBytes)
        $hash.AppendData([System.IO.File]::ReadAllBytes($path))
    }
    [Convert]::ToHexString($hash.GetHashAndReset())
}

function Get-NormalizedTextHash {
    param([string]$Path)
    $text = [System.IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes))
}

function Test-Fingerprint {
    param([string]$Path, [string]$Expected)
    (Test-Path -LiteralPath $Path) -and
        ([System.IO.File]::ReadAllText($Path).Trim() -eq $Expected)
}

function Test-ArtifactReceipt {
    param([string]$Artifact, [string]$Receipt)
    if (-not (Test-Path -LiteralPath $Artifact) -or
        -not (Test-Path -LiteralPath $Receipt)) {
        return $false
    }
    $recorded = [System.IO.File]::ReadAllText($Receipt).Trim()
    $actual = (Get-FileHash -LiteralPath $Artifact -Algorithm SHA256).Hash
    return $recorded -eq $actual
}

function Write-ProfileRecord {
    param([System.Collections.IDictionary]$Profile)

    if ([string]::IsNullOrWhiteSpace($ProfileOutput)) { return }
    $profilePath = if ([System.IO.Path]::IsPathRooted($ProfileOutput)) {
        [System.IO.Path]::GetFullPath($ProfileOutput)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $repoRoot $ProfileOutput))
    }
    $profileDirectory = [System.IO.Path]::GetDirectoryName($profilePath)
    [System.IO.Directory]::CreateDirectory($profileDirectory) | Out-Null
    $json = ($Profile | ConvertTo-Json -Depth 5) + "`n"
    $schemaPath = Join-Path $repoRoot "scripts\contracts\selfhost-profile.schema.json"
    if (-not ($json | Test-Json -SchemaFile $schemaPath -ErrorAction Stop)) {
        throw "structured profile does not match $schemaPath"
    }

    $temporaryPath = Join-Path $profileDirectory ([System.IO.Path]::GetRandomFileName())
    try {
        [System.IO.File]::WriteAllText(
            $temporaryPath,
            $json,
            [System.Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temporaryPath -Destination $profilePath -Force
    } finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
    Write-Host "[profile] Wrote validated structured profile $profilePath."
}

function Invoke-ProfilePhase {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Description
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $stage1Compiler
    $startInfo.WorkingDirectory = $repoRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) {
        [void]$startInfo.ArgumentList.Add($argument)
    }

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [long]$peakWorkingSetBytes = 0
    [long]$processorMilliseconds = 0
    try {
        if (-not $process.Start()) {
            throw "$Description could not start the Stage1 compiler"
        }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $deadline = [DateTimeOffset]::Now.AddMilliseconds($CompilerTimeoutMilliseconds)
        $nextTelemetry = [DateTimeOffset]::Now.AddSeconds(60)
        do {
            $process.Refresh()
            $peakWorkingSetBytes = [Math]::Max($peakWorkingSetBytes, [long]$process.PeakWorkingSet64)
            $processorMilliseconds = [Math]::Max(
                $processorMilliseconds,
                [long]$process.TotalProcessorTime.TotalMilliseconds)
            if ($process.WaitForExit(25)) {
                break
            }
            if ([DateTimeOffset]::Now -ge $deadline) {
                try {
                    $process.Kill($true)
                } catch {
                    $process.Kill()
                }
                if (-not $process.WaitForExit(5000)) {
                    throw "$Description exceeded the $CompilerTimeoutMilliseconds millisecond profile limit and its process tree did not terminate within 5000 milliseconds"
                }
                throw "$Description exceeded the $CompilerTimeoutMilliseconds millisecond profile limit"
            }
            if ([DateTimeOffset]::Now -ge $nextTelemetry) {
                Write-Host ("[profile wait] {0} active for {1:N0}ms; CPU {2:N0}ms; peak {3:N0} MiB." -f `
                    $Description,
                    $stopwatch.ElapsedMilliseconds,
                    $processorMilliseconds,
                    ($peakWorkingSetBytes / 1MB))
                $nextTelemetry = [DateTimeOffset]::Now.AddSeconds(60)
            }
        } while ($true)
        $process.WaitForExit()
        $stopwatch.Stop()
        $process.Refresh()
        $peakWorkingSetBytes = [Math]::Max($peakWorkingSetBytes, [long]$process.PeakWorkingSet64)
        $processorMilliseconds = [Math]::Max(
            $processorMilliseconds,
            [long]$process.TotalProcessorTime.TotalMilliseconds)
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) {
            $details = @($stdout.TrimEnd(), $stderr.TrimEnd()) |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            $suffix = if ($details.Count -gt 0) { "`n" + ($details -join "`n") } else { "" }
            throw "$Description failed with exit code $($process.ExitCode)$suffix"
        }
        if ($peakWorkingSetBytes -le 0) {
            throw "$Description completed without an observed positive peak working set"
        }
        [pscustomobject]@{
            WallMilliseconds = [long]$stopwatch.ElapsedMilliseconds
            ProcessorMilliseconds = $processorMilliseconds
            PeakWorkingSetBytes = $peakWorkingSetBytes
        }
    } finally {
        $process.Dispose()
    }
}

function Expand-ImportedSources {
    param(
        [string[]]$Roots,
        [string[]]$Candidates
    )
    $moduleMap = @{}
    foreach ($candidate in $Candidates) {
        $source = [System.IO.File]::ReadAllText($candidate)
        $namespaceMatch = [regex]::Match(
            $source,
            '(?m)^\s*namespace\s+([A-Za-z_][A-Za-z0-9_.]*)\s*$')
        if (-not $namespaceMatch.Success) { continue }
        $namespace = $namespaceMatch.Groups[1].Value
        if (-not $moduleMap.ContainsKey($namespace)) {
            $moduleMap[$namespace] = [System.Collections.Generic.List[string]]::new()
        }
        $moduleMap[$namespace].Add($candidate)
    }

    $resolved = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)
    $pending = [System.Collections.Generic.Queue[string]]::new()
    foreach ($root in $Roots) {
        if ($seen.Add($root)) {
            $resolved.Add($root)
            $pending.Enqueue($root)
        }
    }

    while ($pending.Count -gt 0) {
        $path = $pending.Dequeue()
        $source = [System.IO.File]::ReadAllText($path)
        $imports = [regex]::Matches(
            $source,
            '(?m)^\s*import\s+([A-Za-z_][A-Za-z0-9_.]*)\b')
        foreach ($import in $imports) {
            $namespace = $import.Groups[1].Value
            if (-not $moduleMap.ContainsKey($namespace)) { continue }
            foreach ($dependency in $moduleMap[$namespace]) {
                if ($seen.Add($dependency)) {
                    $resolved.Add($dependency)
                    $pending.Enqueue($dependency)
                }
            }
        }
    }
    $resolved.ToArray()
}

function Invoke-ToFile {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$OutputPath,
        [string]$ErrorPath
    )
    $processName = [System.IO.Path]::GetFileName($FilePath)
    Invoke-VerificationProcessToFile `
        -FilePath $FilePath `
        -ArgumentList $Arguments `
        -Description "$processName compiler emission" `
        -OutputPath $OutputPath `
        -ErrorPath $ErrorPath `
        -TimeoutMilliseconds $CompilerTimeoutMilliseconds
}

function Assert-SlgSeedBootstrapCapabilities {
    param([string]$Compiler)

    $mutableSuffixFixture = Join-Path $repoRoot "examples\regression\1267-mutable-name-suffix-resolution.slg"
    $probeLlvm = Join-Path $cacheRoot "seed-capability-1267.ll"
    $probeError = Join-Path $cacheRoot "seed-capability-1267.err"
    Invoke-ToFile $Compiler @("windows", $mutableSuffixFixture) $probeLlvm $probeError
    $probeText = if (Test-Path -LiteralPath $probeLlvm) {
        [System.IO.File]::ReadAllText($probeLlvm)
    } else { "" }
    $probeErrors = if (Test-Path -LiteralPath $probeError) {
        [System.IO.File]::ReadAllText($probeError)
    } else { "" }
    if ([string]::IsNullOrWhiteSpace($probeText) -or
        "$probeText`n$probeErrors" -match '(?m)^;?\s*sollang (?:semantic |ir |compiler )?(?:error|verification failure)') {
        throw "SLG seed capability preflight failed for mutable-name suffix resolution (1267). The receipt proves artifact identity, not source-language capability. Use -SeedMode ManagedRecovery for one explicit bootstrap bridge, then return to Stage2/Stage3 SLG fixed-point verification."
    }
    & $llvmAs $probeLlvm -disable-output
    if ($LASTEXITCODE -ne 0) {
        throw "SLG seed capability preflight emitted invalid LLVM for mutable-name suffix resolution (1267). The receipt proves artifact identity, not source-language capability. Use -SeedMode ManagedRecovery for one explicit bootstrap bridge, then return to Stage2/Stage3 SLG fixed-point verification."
    }
    Write-Host "[seed capability] PASS mutable-name suffix resolution 1267."
}

function Convert-ToWslPath {
    param([string]$Path)

    $absolute = [System.IO.Path]::GetFullPath($Path)
    if ($absolute.Length -lt 3 -or $absolute[1] -ne ':' -or $absolute[2] -ne '\') {
        throw "WSL paths must be drive-qualified Windows paths: $absolute"
    }
    $drive = $absolute.Substring(0, 1).ToLowerInvariant()
    $tail = $absolute.Substring(3).Replace('\', '/')
    return "/mnt/$drive/$tail"
}

function Link-FocusedExecutable {
    param(
        [string]$LlvmPath,
        [string]$ExecutablePath
    )

    if ($Target -eq "windows") {
        & $clang -Wno-override-module $LlvmPath -O1 -o $ExecutablePath @platformLibraries
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        return
    }

    $objectPath = [System.IO.Path]::ChangeExtension($ExecutablePath, ".o")
    & $clang --target=x86_64-unknown-linux-gnu -Wno-override-module -c $LlvmPath -O1 -o $objectPath
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & wsl.exe -d $WslDistribution -- gcc `
        (Convert-ToWslPath $objectPath) -pthread -ldl -o (Convert-ToWslPath $ExecutablePath)
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

function Invoke-FocusedExecutable {
    param([string]$ExecutablePath)

    if ($Target -eq "windows") {
        return (& $ExecutablePath | Out-String)
    }
    return (& wsl.exe -d $WslDistribution -- (Convert-ToWslPath $ExecutablePath) | Out-String)
}

function Assert-FocusedLlvmContract {
    param(
        [string]$LlvmPath,
        [string]$ExpectedDirectory,
        [string]$FixtureName
    )

    $llvm = [System.IO.File]::ReadAllText($LlvmPath)
    if ($llvm.Contains(") #0 {") -and
        -not $llvm.Contains("attributes #0 = { nounwind }")) {
        throw "focused LLVM references attribute group #0 without its canonical nounwind definition"
    }
    if ($llvm -match "(?m)^\s*%[^\r\n]* = call [^\r\n]*@sollang_platform_dns_lookup" -and
        $llvm -notmatch "(?m)^\s*%[^\r\n]*_dns_bytes = mul i64 [^\r\n]+, 40\s*$") {
        throw "focused DNS LLVM must allocate the 40-byte std.net.Endpoint ABI stride"
    }

    $containsPath = Join-Path $ExpectedDirectory "$FixtureName.selfhost.llvm.contains.txt"
    if (Test-Path -LiteralPath $containsPath) {
        foreach ($required in [System.IO.File]::ReadAllLines($containsPath)) {
            if ($required.Length -gt 0 -and -not $llvm.Contains($required)) {
                throw "focused self-host LLVM does not contain '$required'"
            }
        }
    }

    $notContainsPath = Join-Path $ExpectedDirectory "$FixtureName.selfhost.llvm.not-contains.txt"
    if (Test-Path -LiteralPath $notContainsPath) {
        foreach ($forbidden in [System.IO.File]::ReadAllLines($notContainsPath)) {
            if ($forbidden.Length -gt 0 -and $llvm.Contains($forbidden)) {
                throw "focused self-host LLVM unexpectedly contains '$forbidden'"
            }
        }
    }

    $regexCountsPath = Join-Path $ExpectedDirectory "$FixtureName.selfhost.llvm.regex-counts.txt"
    if (Test-Path -LiteralPath $regexCountsPath) {
        foreach ($countContract in ([System.IO.File]::ReadAllLines($regexCountsPath) |
                Where-Object { $_.Length -gt 0 })) {
            $fields = $countContract.Split("`t", 2)
            if ($fields.Count -ne 2) {
                throw "invalid focused self-host LLVM regex-count contract '$countContract'"
            }
            $expectedCount = 0
            if (-not [int]::TryParse($fields[0], [ref]$expectedCount) -or $expectedCount -lt 0) {
                throw "invalid focused self-host LLVM regex count '$($fields[0])'"
            }
            $actualCount = ([regex]::Matches($llvm, $fields[1])).Count
            if ($actualCount -ne $expectedCount) {
                throw "focused self-host LLVM regex '$($fields[1])' matched $actualCount times instead of $expectedCount"
            }
        }
    }

    $orderedRegexPath = Join-Path $ExpectedDirectory "$FixtureName.selfhost.llvm.ordered-regex.txt"
    if (Test-Path -LiteralPath $orderedRegexPath) {
        $cursor = 0
        foreach ($pattern in ([System.IO.File]::ReadAllLines($orderedRegexPath) |
                Where-Object { $_.Length -gt 0 })) {
            $matcher = [regex]::new($pattern)
            $match = $matcher.Match($llvm, $cursor)
            if (-not $match.Success) {
                throw "focused self-host LLVM did not match ordered regex '$pattern' after byte $cursor"
            }
            $cursor = $match.Index + $match.Length
        }
    }
}

function Invoke-ManagedOracle {
    param(
        [string[]]$FixturePaths,
        [string]$FixtureHash,
        [string]$ExpectedPath,
        [string]$Expected
    )

    $managedFixturePaths = @($FixturePaths | Where-Object {
        $relativeManagedPath = [System.IO.Path]::GetRelativePath($repoRoot, $_).Replace("\", "/")
        -not $relativeManagedPath.StartsWith("stdlib/") -and
            $relativeManagedPath -ne "selfhost/runtime/file.slg"
    })
    $managedActionText = "$managedCompilerHash|$FixtureHash|$Target|managed-differential-v1"
    $managedActionHash = [Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData(
            [System.Text.Encoding]::UTF8.GetBytes($managedActionText))).Substring(0, 20)
    $managedTarget = if ($Target -eq "windows") { "windows-x64" } else { "linux-x64" }
    $managedExecutable = if ($Target -eq "windows") {
        Join-Path $cacheRoot "$managedActionHash-managed.exe"
    } else {
        Join-Path $cacheRoot "$managedActionHash-managed.linux"
    }
    if (-not (Test-Path -LiteralPath $managedExecutable) -or
        (Get-Item -LiteralPath $managedExecutable).Length -eq 0) {
        Write-Host "[managed differential] C# oracle build starts."
        $managedArguments = @(
            "run", "--project", $compilerProject, "-c", "Release", "--",
            "build"
        # The managed compiler resolves stdlib and its native sys.file itself, while
        # selfhost-only modules still need the expanded project source closure.
        ) + $managedFixturePaths + @(
            "-o", $managedExecutable, "--target", $managedTarget, "-O0"
        )
        & dotnet @managedArguments
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    } else {
        Write-Host "[managed differential] C# oracle cache HIT."
    }
    if (-not $NoExecute -and (Test-Path -LiteralPath $ExpectedPath)) {
        $managedActual = (Invoke-FocusedExecutable $managedExecutable).Replace("`r`n", "`n").TrimEnd("`n")
        if ($LASTEXITCODE -ne 0 -or $managedActual -ne $Expected) {
            throw "managed differential execution differs from $ExpectedPath`nexpected: $Expected`nactual: $managedActual"
        }
        Write-Host "[managed differential] C# oracle execution PASS."
    }
}

$compilerSources = @(Resolve-Manifest $manifestPath)
$runtimeSources = @(Resolve-Manifest $runtimeManifestPath)
$compilerInputSources = @($compilerSources + $runtimeSources | Select-Object -Unique)
$compilerEmissionSourceFingerprint = Get-CompilerEmissionInputFingerprint `
    -RepositoryRoot $repoRoot `
    -Path $compilerInputSources
$compilerHash = Get-ContentFingerprint $compilerInputSources
$managedCompilerInputs = @(
    Get-ChildItem -LiteralPath (Join-Path $repoRoot "src\Sollang.Compiler") -File -Recurse |
        Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' } |
        ForEach-Object { $_.FullName }
    Get-ChildItem -LiteralPath (Join-Path $repoRoot "src\Sollang.Compiler.Generators") -File -Recurse |
        Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' } |
        ForEach-Object { $_.FullName }
    (Resolve-Path (Join-Path $repoRoot "syntax\sollang.lexer")).Path
    (Resolve-Path (Join-Path $repoRoot "syntax\sollang.grammar")).Path
) | Sort-Object -Unique
$managedCompilerHash = Get-ContentFingerprint $managedCompilerInputs
$seedIdentity = if ($ManagedOracleOnly) {
    "managed-oracle-only"
} elseif ($SeedMode -eq "Slg") {
    "slg|$((Get-FileHash -LiteralPath $SlgSeedCompiler -Algorithm SHA256).Hash)"
} else {
    "managed-recovery|$managedCompilerHash"
}
$bootstrapInputHash = [Convert]::ToHexString(
    [System.Security.Cryptography.SHA256]::HashData(
        [System.Text.Encoding]::UTF8.GetBytes("$compilerHash|$seedIdentity")))
$stage1SanitizerProfile = if ($Stage1AddressSanitizer) { "asan" } else { "none" }
$stage1Profile = "windows-x64|$Stage1Optimization|$stage1SanitizerProfile|slg-first-feedback-v2"
$stage1BuildHash = [Convert]::ToHexString(
    [System.Security.Cryptography.SHA256]::HashData(
        [System.Text.Encoding]::UTF8.GetBytes("$bootstrapInputHash|$stage1Profile")))
$stage2Profile = "$Target|incremental-final-v1"
$stage2BuildHash = [Convert]::ToHexString(
    [System.Security.Cryptography.SHA256]::HashData(
        [System.Text.Encoding]::UTF8.GetBytes("$bootstrapInputHash|$stage2Profile")))
$legacyStage1Compiler = Join-Path $cacheRoot "selfhost-stage1-host.exe"
$legacyStage1Fingerprint = Join-Path $cacheRoot "selfhost-stage1-host.sha256"
if ($Stage1Optimization -eq "O0" -and
    -not (Test-Path -LiteralPath $stage1Compiler) -and
    (Test-Path -LiteralPath $legacyStage1Compiler) -and
    (Test-Fingerprint $legacyStage1Fingerprint $stage1BuildHash)) {
    Copy-Item -LiteralPath $legacyStage1Compiler -Destination $stage1Compiler
    [System.IO.File]::WriteAllText($stage1Fingerprint, $stage1BuildHash)
}
if (-not (Test-Path -LiteralPath $stage1HostLlvmFingerprint) -and
    (Test-Path -LiteralPath $stage1HostLlvm) -and
    (Get-Item -LiteralPath $stage1HostLlvm).Length -gt 0 -and
    (Test-Fingerprint $legacyStage1Fingerprint $stage1BuildHash)) {
    [System.IO.File]::WriteAllText($stage1HostLlvmFingerprint, $bootstrapInputHash)
}
$started = Get-Date
$platformLibraries = if ($Target -eq "windows") {
    @("-lws2_32", "-lshell32", "-lbcrypt")
} else {
    @("-pthread", "-ldl")
}

if (-not $ManagedOracleOnly -and $SeedMode -eq "Slg") {
    Assert-SlgSeedBootstrapCapabilities $SlgSeedCompiler
}

if ($Target -eq "linux" -and $BootstrapStage2) {
    throw "Linux Stage2 bootstrap belongs to scripts/verify-selfhost-stage2-linux.ps1; the focused incremental gate only links and executes Linux fixtures."
}

if (-not $ManagedOracleOnly -and
    (-not (Test-Path -LiteralPath $stage1Compiler) -or
        -not (Test-Fingerprint $stage1Fingerprint $stage1BuildHash) -or
        ((Test-Path -LiteralPath $stage1Receipt) -and
            -not (Test-ArtifactReceipt $stage1Compiler $stage1Receipt)))) {
    Write-Host "[fast 1/5] SLG-first selfhost compiler cache MISS ($SeedMode)."
    # A receipt authenticates one exact executable, never an output path. Drop
    # it before replacement so profile-only runs cannot leave a fresh Stage1
    # paired with a stale receipt and force every later run back onto the cold
    # compiler-generation path.
    Remove-Item -LiteralPath $stage1Receipt -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stage1GenerationReceipt -ErrorAction SilentlyContinue
    $stage1BuildStarted = Get-Date
    if ($SeedMode -eq "Slg") {
        $stage1HostError = Join-Path $cacheRoot "selfhost-stage1-host.err"
        $stage1HostBitcode = Join-Path $cacheRoot "selfhost-stage1-host.bc"
        if (-not (Test-Path -LiteralPath $stage1HostLlvm) -or
            -not (Test-Fingerprint $stage1HostLlvmFingerprint $bootstrapInputHash)) {
            Write-Host "[stage1 llvm] cache MISS; verified SLG seed emits compiler LLVM once."
            $stage1HostLlvmStarted = Get-Date
            Invoke-ToFile $SlgSeedCompiler (@("windows") + $compilerInputSources) $stage1HostLlvm $stage1HostError
            $stage1HostLlvmMs = [int]((Get-Date) - $stage1HostLlvmStarted).TotalMilliseconds
            Write-Host "[timing] SLG seed compiler LLVM emission ${stage1HostLlvmMs}ms."
            & (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1") -LlvmPath $stage1HostLlvm
            & $llvmAs $stage1HostLlvm -o $stage1HostBitcode
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
            [System.IO.File]::WriteAllText($stage1HostLlvmFingerprint, $bootstrapInputHash)
        } else {
            Write-Host "[stage1 llvm] cache HIT; linking the requested native optimization profile only."
        }
        $hostOptimization = if ($Stage1Optimization -eq "O0") { "-O0" } else { "-O1" }
        $hostSanitizer = if ($Stage1AddressSanitizer) {
            @("-fsanitize=address", "-fno-omit-frame-pointer")
        } else {
            @()
        }
        & $clang -Wno-override-module $stage1HostLlvm $hostOptimization @hostSanitizer -o $stage1Compiler @platformLibraries
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    } else {
        Write-Warning "ManagedRecovery is an explicit bootstrap bridge; complete the SLG implementation and return to -SeedMode Slg."
        $arguments = @(
            "run", "--project", $compilerProject, "-c", "Release", "--",
            "build"
        ) + $compilerSources + @(
            "-o", $stage1Compiler, "--target", "windows-x64", "-$Stage1Optimization", "--keep-temps"
        )
        & dotnet @arguments
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    [System.IO.File]::WriteAllText($stage1Fingerprint, $stage1BuildHash)
    $stage1BuildMs = [int]((Get-Date) - $stage1BuildStarted).TotalMilliseconds
    Write-Host "[timing] Stage1 feedback compiler build ${stage1BuildMs}ms."
} elseif (-not $ManagedOracleOnly) {
    Write-Host "[fast 1/5] SLG-first selfhost compiler cache HIT ($SeedMode)."
}

if (-not $ManagedOracleOnly) {
    & (Join-Path $PSScriptRoot "verify-each-call-result-source-selection.ps1") `
        -RepositoryRoot $repoRoot `
        -CandidateCompiler $stage1Compiler
}

if ($BootstrapStage2 -and $SeedMode -eq "ManagedRecovery") {
    $managedMaterializeArguments = @(
        "run", "--project", $compilerProject, "-c", "Release", "--",
        "build"
    ) + $compilerSources + @(
        "-o", $stage1Compiler, "--target", "windows-x64", "-$Stage1Optimization", "--keep-temps"
    )
    & dotnet @managedMaterializeArguments
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if (-not (Test-Path -LiteralPath $managedStage1HostLlvm) -or
        (Get-Item -LiteralPath $managedStage1HostLlvm).Length -eq 0) {
        throw "ManagedRecovery did not materialize the Stage1 host LLVM provenance artifact: $managedStage1HostLlvm"
    }
}

if ($Stage1AddressSanitizer -and -not $ManagedOracleOnly) {
    $asanRuntime = Join-Path $llvmRoot "lib\clang\22\lib\windows\clang_rt.asan_dynamic-x86_64.dll"
    if (-not (Test-Path -LiteralPath $asanRuntime -PathType Leaf)) {
        throw "LLVM AddressSanitizer runtime is missing: $asanRuntime"
    }
    Copy-Item -LiteralPath $asanRuntime -Destination $cacheRoot -Force
}

$standardLibrarySources = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot "stdlib") `
    -Filter "*.slg" -File -Recurse | ForEach-Object { $_.FullName })
$regressionFixtureSources = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot "examples\regression\fixtures") `
    -Filter "*.slg" -File -Recurse | ForEach-Object { $_.FullName })
$importCandidates = @($compilerInputSources + $standardLibrarySources + $regressionFixtureSources | Select-Object -Unique)
$fixturePaths = @(Expand-ImportedSources $fixtureRoots $importCandidates)
$fixtureHash = Get-ContentFingerprint $fixturePaths
$fixtureCompilerArguments = @($Target)
if ($FixtureBuildJobs -gt 0) {
    $fixtureCompilerArguments += @("--jobs", [string]$FixtureBuildJobs)
}
$fixtureCompilerArguments += $fixturePaths
$fixtureName = [System.IO.Path]::GetFileNameWithoutExtension($fixturePaths[0])
$expectedDir = Join-Path $repoRoot "examples\regression\expected"
$expectedTargetName = if ($Target -eq "windows") { "windows-x64" } else { "linux-x64" }
$targetExpectedPath = Join-Path $expectedDir "$fixtureName.stdout.$expectedTargetName.txt"
$defaultExpectedPath = Join-Path $expectedDir "$fixtureName.stdout.txt"
$expectedPath = if (Test-Path -LiteralPath $targetExpectedPath) {
    $targetExpectedPath
} else {
    $defaultExpectedPath
}
$expected = if (Test-Path -LiteralPath $expectedPath) {
    [System.IO.File]::ReadAllText($expectedPath).Replace("`r`n", "`n").TrimEnd("`n")
} else { "" }

if ($ManagedOracleOnly) {
    Invoke-ManagedOracle $fixturePaths $fixtureHash $expectedPath $expected
    Write-Host "[diagnostic complete] Managed oracle only; this is not SLG completion evidence."
    exit 0
}

if ($ProfileSourcePrefix -gt 0) {
    if ($ProfileFunctionPrefix -gt 0) {
        $typedIrPrefixProfile = Invoke-ProfilePhase `
            -Arguments (@("typed-ir-function-prefix", [string]$ProfileSourcePrefix, [string]$ProfileFunctionPrefix) + $fixturePaths) `
            -Description "self-host Typed IR source-prefix $ProfileSourcePrefix function-prefix $ProfileFunctionPrefix profile"
        Write-Host "[profile] Typed IR source prefix $ProfileSourcePrefix function prefix $ProfileFunctionPrefix completed in $($typedIrPrefixProfile.WallMilliseconds)ms."
    } else {
        $typedIrPrefixProfile = Invoke-ProfilePhase `
            -Arguments (@("typed-ir-prefix", [string]$ProfileSourcePrefix) + $fixturePaths) `
            -Description "self-host Typed IR source-prefix $ProfileSourcePrefix profile"
        Write-Host "[profile] Typed IR source prefix $ProfileSourcePrefix completed in $($typedIrPrefixProfile.WallMilliseconds)ms."
    }
    exit 0
}

if ($ProfilePhases -or $ProfileExpressionTypesOnly) {
    $semanticProfile = Invoke-ProfilePhase `
        -Arguments (@("prepare") + $fixturePaths) `
        -Description "self-host semantic preparation profile"
    $semanticMs = $semanticProfile.WallMilliseconds
    Write-Host "[profile] Semantic prepare ${semanticMs}ms."

    $expressionTypeProfile = Invoke-ProfilePhase `
        -Arguments (@("expression-type-ids") + $fixturePaths) `
        -Description "self-host expression type ID profile"
    $expressionTypeMs = $expressionTypeProfile.WallMilliseconds
    Write-Host "[profile] Semantic prepare + expression type IDs ${expressionTypeMs}ms."
    Write-Host "[profile] Expression type ID delta $($expressionTypeMs - $semanticMs)ms."

    if ($ProfileExpressionTypesOnly) {
        if (-not [string]::IsNullOrWhiteSpace($ProfileOutput)) {
            $profile = [ordered]@{
                schemaVersion = 3
                mode = "expression-types"
                measurement = "single-process-wall-clock-cpu-peak-working-set"
                semanticBaseline = "prepare-only"
                sampleCount = 1
                seedMode = $SeedMode
                target = $Target
                optimization = $Stage1Optimization
                environment = [ordered]@{
                    osDescription = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
                    processArchitecture = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
                    processorCount = [System.Environment]::ProcessorCount
                }
                fixtureRoots = @($Fixture)
                expandedSourceCount = $fixturePaths.Count
                compilerFingerprint = $stage1BuildHash
                fixtureFingerprint = $fixtureHash
                semanticPreparationMs = $semanticMs
                semanticPreparationCpuMs = $semanticProfile.ProcessorMilliseconds
                semanticPreparationPeakWorkingSetBytes = $semanticProfile.PeakWorkingSetBytes
                expressionTypeIdsTotalMs = $expressionTypeMs
                expressionTypeIdsDeltaMs = $expressionTypeMs - $semanticMs
                expressionTypeIdsTotalCpuMs = $expressionTypeProfile.ProcessorMilliseconds
                expressionTypeIdsPeakWorkingSetBytes = $expressionTypeProfile.PeakWorkingSetBytes
                typedIrTotalMs = $null
                typedIrDeltaMs = $null
                postExpressionTypeTypedIrDeltaMs = $null
                typedIrTotalCpuMs = $null
                typedIrPeakWorkingSetBytes = $null
                artifactTotalMs = $null
                artifactEncodeDeltaMs = $null
                artifactTotalCpuMs = $null
                artifactPeakWorkingSetBytes = $null
            }
            Write-ProfileRecord $profile
        }
        exit 0
    }

    $typedIrIndexProfile = Invoke-ProfilePhase `
        -Arguments (@("typed-ir-index") + $fixturePaths) `
        -Description "self-host Typed IR shared-index profile"
    $typedIrIndexMs = $typedIrIndexProfile.WallMilliseconds
    Write-Host "[profile] Semantic prepare + Typed IR shared indexes ${typedIrIndexMs}ms."
    Write-Host "[profile] Typed IR shared-index delta $($typedIrIndexMs - $expressionTypeMs)ms."

    $typedIrLowerProfile = Invoke-ProfilePhase `
        -Arguments (@("typed-ir-lower") + $fixturePaths) `
        -Description "self-host Typed IR source-lowering profile"
    $typedIrLowerMs = $typedIrLowerProfile.WallMilliseconds
    Write-Host "[profile] Semantic prepare + Typed IR source lowering ${typedIrLowerMs}ms."
    Write-Host "[profile] Typed IR source-lowering delta $($typedIrLowerMs - $typedIrIndexMs)ms."

    $typedIrNormalizeProfile = Invoke-ProfilePhase `
        -Arguments (@("typed-ir-normalize") + $fixturePaths) `
        -Description "self-host Typed IR normalization profile"
    $typedIrNormalizeMs = $typedIrNormalizeProfile.WallMilliseconds
    Write-Host "[profile] Semantic prepare + Typed IR normalization ${typedIrNormalizeMs}ms."
    Write-Host "[profile] Typed IR normalization delta $($typedIrNormalizeMs - $typedIrLowerMs)ms."

    $typedIrSealProfile = Invoke-ProfilePhase `
        -Arguments (@("typed-ir-seal") + $fixturePaths) `
        -Description "self-host Typed IR sealing profile"
    $typedIrSealMs = $typedIrSealProfile.WallMilliseconds
    Write-Host "[profile] Semantic prepare + Typed IR sealing ${typedIrSealMs}ms."
    Write-Host "[profile] Typed IR sealing delta $($typedIrSealMs - $typedIrNormalizeMs)ms."

    $typedIrProfile = Invoke-ProfilePhase `
        -Arguments (@("typed-ir") + $fixturePaths) `
        -Description "self-host Typed IR profile"
    $typedIrMs = $typedIrProfile.WallMilliseconds
    Write-Host "[profile] Semantic prepare + Typed IR ${typedIrMs}ms."
    Write-Host "[profile] Typed IR delta $($typedIrMs - $semanticMs)ms."
    Write-Host "[profile] Post-expression-type Typed IR delta $($typedIrMs - $expressionTypeMs)ms."

    $artifactMs = $null
    $artifactProfile = $null
    if ($ProfileArtifacts) {
        $artifactProfile = Invoke-ProfilePhase `
            -Arguments (@("module-artifacts") + $fixturePaths) `
            -Description "self-host module artifact profile"
        $artifactMs = $artifactProfile.WallMilliseconds
        Write-Host "[profile] Semantic prepare + Typed IR artifact ${artifactMs}ms."
        Write-Host "[profile] Artifact encode delta $($artifactMs - $typedIrMs)ms."
    }
    if (-not [string]::IsNullOrWhiteSpace($ProfileOutput)) {
        $profile = [ordered]@{
            schemaVersion = 3
            mode = if ($ProfileArtifacts) { "artifacts" } else { "typed-ir" }
            measurement = "single-process-wall-clock-cpu-peak-working-set"
            semanticBaseline = "prepare-only"
            sampleCount = 1
            seedMode = $SeedMode
            target = $Target
            optimization = $Stage1Optimization
            environment = [ordered]@{
                osDescription = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
                processArchitecture = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
                processorCount = [System.Environment]::ProcessorCount
            }
            fixtureRoots = @($Fixture)
            expandedSourceCount = $fixturePaths.Count
            compilerFingerprint = $stage1BuildHash
            fixtureFingerprint = $fixtureHash
            semanticPreparationMs = $semanticMs
            semanticPreparationCpuMs = $semanticProfile.ProcessorMilliseconds
            semanticPreparationPeakWorkingSetBytes = $semanticProfile.PeakWorkingSetBytes
            expressionTypeIdsTotalMs = $expressionTypeMs
            expressionTypeIdsDeltaMs = $expressionTypeMs - $semanticMs
            expressionTypeIdsTotalCpuMs = $expressionTypeProfile.ProcessorMilliseconds
            expressionTypeIdsPeakWorkingSetBytes = $expressionTypeProfile.PeakWorkingSetBytes
            typedIrTotalMs = $typedIrMs
            typedIrDeltaMs = $typedIrMs - $semanticMs
            postExpressionTypeTypedIrDeltaMs = $typedIrMs - $expressionTypeMs
            typedIrTotalCpuMs = $typedIrProfile.ProcessorMilliseconds
            typedIrPeakWorkingSetBytes = $typedIrProfile.PeakWorkingSetBytes
            artifactTotalMs = $artifactMs
            artifactEncodeDeltaMs = if ($null -eq $artifactMs) { $null } else { $artifactMs - $typedIrMs }
            artifactTotalCpuMs = if ($null -eq $artifactProfile) { $null } else { $artifactProfile.ProcessorMilliseconds }
            artifactPeakWorkingSetBytes = if ($null -eq $artifactProfile) { $null } else { $artifactProfile.PeakWorkingSetBytes }
        }
        Write-ProfileRecord $profile
    }
    exit 0
}

$actionText = "$stage1BuildHash|$fixtureHash|$Target|jobs=$FixtureBuildJobs"
$actionHash = [Convert]::ToHexString(
    [System.Security.Cryptography.SHA256]::HashData(
        [System.Text.Encoding]::UTF8.GetBytes($actionText))).Substring(0, 20)
$stage1Llvm = Join-Path $cacheRoot "$actionHash-stage1.ll"
$stage1Error = Join-Path $cacheRoot "$actionHash-stage1.err"
$stage1Bitcode = [System.IO.Path]::ChangeExtension($stage1Llvm, ".bc")
$stage1Executable = if ($Target -eq "windows") {
    [System.IO.Path]::ChangeExtension($stage1Llvm, ".exe")
} else {
    [System.IO.Path]::ChangeExtension($stage1Llvm, ".linux")
}
$stage1LlvmCacheHit = (Test-Path -LiteralPath $stage1Llvm) -and
    (Get-Item -LiteralPath $stage1Llvm).Length -gt 0

if (-not $stage1LlvmCacheHit) {
    Write-Host "[fast 2/5] Focused Stage1 LLVM cache MISS."
    $stage1EmitStarted = Get-Date
    Invoke-ToFile $stage1Compiler $fixtureCompilerArguments $stage1Llvm $stage1Error
    $stage1EmitMs = [int]((Get-Date) - $stage1EmitStarted).TotalMilliseconds
    Write-Host "[timing] Focused Stage1 LLVM emission ${stage1EmitMs}ms."
} else {
    Write-Host "[fast 2/5] Focused Stage1 LLVM cache HIT."
}
Assert-FocusedLlvmContract $stage1Llvm $expectedDir $fixtureName
& (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1") -LlvmPath $stage1Llvm
$stage1VerifyStarted = Get-Date
if ($stage1LlvmCacheHit -and
    (Test-Path -LiteralPath $stage1Bitcode) -and
    (Get-Item -LiteralPath $stage1Bitcode).Length -gt 0) {
    Write-Host "[fast 3/5] Focused LLVM verifier cache HIT."
} else {
    & $llvmAs $stage1Llvm -o $stage1Bitcode
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
$stage1VerifyMs = [int]((Get-Date) - $stage1VerifyStarted).TotalMilliseconds
Write-Host "[fast 3/5] Focused LLVM verifier PASS ${stage1VerifyMs}ms."

if (-not $NoExecute) {
    if (Test-Path -LiteralPath $expectedPath) {
        $executionStarted = Get-Date
        if ($stage1LlvmCacheHit -and
            (Test-Path -LiteralPath $stage1Executable) -and
            (Get-Item -LiteralPath $stage1Executable).Length -gt 0) {
            Write-Host "[fast 4/5] Focused executable cache HIT."
        } else {
            Link-FocusedExecutable $stage1Llvm $stage1Executable
        }
        $actual = (Invoke-FocusedExecutable $stage1Executable).Replace("`r`n", "`n").TrimEnd("`n")
        if ($LASTEXITCODE -ne 0 -or $actual -ne $expected) {
            throw "focused execution differs from $expectedPath`nexpected: $expected`nactual: $actual"
        }
        $executionMs = [int]((Get-Date) - $executionStarted).TotalMilliseconds
        Write-Host "[fast 4/5] Focused link and execution PASS ${executionMs}ms."
    } else {
        Write-Host "[fast 4/5] No expected stdout; execution skipped."
    }
} else {
    Write-Host "[fast 4/5] Execution skipped by request."
}

if ($ManagedDifferential) {
    Invoke-ManagedOracle $fixturePaths $fixtureHash $expectedPath $expected
} else {
    Write-Host "[managed differential] disabled explicitly."
}

if ($BootstrapStage2 -and $Stage1Optimization -eq "O1") {
    $stage2Reusable = -not $RebuildStage2 -and
        (Test-Path -LiteralPath $stage2Llvm) -and
        (Get-Item -LiteralPath $stage2Llvm).Length -gt 0 -and
        (Test-Path -LiteralPath $stage2Compiler) -and
        (Get-Item -LiteralPath $stage2Compiler).Length -gt 0 -and
        (Test-Fingerprint $stage2Fingerprint $stage2BuildHash)
    if ($stage2Reusable) {
        Write-Host "[final gate] Stage2 bootstrap cache HIT; verified compiler reused."
    } else {
        Write-Host "[final gate] Stage2 bootstrap cache MISS; full self-build starts once."
        $stage2Error = Join-Path $cacheRoot "selfhost-stage2.err"
        $stage2EmitStarted = Get-Date
        Invoke-ToFile $stage1Compiler (@($Target) + $compilerSources + $runtimeSources) $stage2Llvm $stage2Error
        $stage2EmitMs = [int]((Get-Date) - $stage2EmitStarted).TotalMilliseconds
        Write-Host "[final gate] Stage2 LLVM emission ${stage2EmitMs}ms."
        & (Join-Path $PSScriptRoot "verify-selfhost-parallel-callback-llvm.ps1") `
            -LlvmPath $stage2Llvm `
            -MinimumCallbackCount 4 `
            -RequireNominalTransfer
        $stage2VerifyStarted = Get-Date
        & $llvmAs $stage2Llvm -o ([System.IO.Path]::ChangeExtension($stage2Llvm, ".bc"))
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        $stage2VerifyMs = [int]((Get-Date) - $stage2VerifyStarted).TotalMilliseconds
        Write-Host "[final gate] Stage2 LLVM verification ${stage2VerifyMs}ms."
        $stage2LinkStarted = Get-Date
        & $clang -Wno-override-module $stage2Llvm -O1 -o $stage2Compiler @platformLibraries
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        $stage2LinkMs = [int]((Get-Date) - $stage2LinkStarted).TotalMilliseconds
        Write-Host "[final gate] Stage2 native link ${stage2LinkMs}ms."
        [System.IO.File]::WriteAllText($stage2Fingerprint, $stage2BuildHash)
    }
}

if ($BootstrapStage2 -and $Stage1Optimization -eq "O1") {
    $callbackVerifier = Join-Path $PSScriptRoot "verify-selfhost-parallel-callback-llvm.ps1"
    $baselineLlvm = if ($SeedMode -eq "ManagedRecovery") { $managedStage1HostLlvm } else { $stage1HostLlvm }
    $baselineCallbacks = if ($SeedMode -eq "ManagedRecovery") {
        & $callbackVerifier -LlvmPath $baselineLlvm -MinimumCallbackCount 3 -PassThru
    } else {
        & $callbackVerifier -LlvmPath $baselineLlvm -MinimumCallbackCount 4 -RequireNominalTransfer -PassThru
    }
    if ($SeedMode -eq "ManagedRecovery" -and
        ($baselineCallbacks.CallbackCount -ne 3 -or
            $baselineCallbacks.NominalTransferCallbackCount -ne 0)) {
        throw "ManagedRecovery Stage1 is not the exact three-callback/no-nominal adjacent bootstrap control"
    }
    $candidateCallbacks = & $callbackVerifier `
        -LlvmPath $stage2Llvm `
        -MinimumCallbackCount 4 `
        -RequireNominalTransfer `
        -PassThru
    $seedCompilerHash = if ($SeedMode -eq "Slg") {
        (Get-FileHash -LiteralPath $SlgSeedCompiler -Algorithm SHA256).Hash
    } else {
        $managedCompilerHash
    }
    $stage1CompilerHash = (Get-FileHash -LiteralPath $stage1Compiler -Algorithm SHA256).Hash
    $pair = [ordered]@{
        schemaVersion = 1
        mode = "adjacent-bootstrap-performance-pair"
        target = $Target
        sourceFingerprint = Get-CompilerEmissionInputFingerprint `
            -RepositoryRoot $repoRoot `
            -Path $compilerInputSources
        baseline = [ordered]@{
            compilerPath = [System.IO.Path]::GetRelativePath($repoRoot, $stage1Compiler).Replace('\', '/')
            compilerFingerprint = $stage1CompilerHash
            llvmPath = [System.IO.Path]::GetRelativePath($repoRoot, $baselineLlvm).Replace('\', '/')
            llvmFingerprint = (Get-FileHash -LiteralPath $baselineLlvm -Algorithm SHA256).Hash
            generatedByCompilerFingerprint = $seedCompilerHash
            optimization = $Stage1Optimization
            parallelCallbackCount = $baselineCallbacks.CallbackCount
            nominalTransferCallbackCount = $baselineCallbacks.NominalTransferCallbackCount
        }
        candidate = [ordered]@{
            compilerPath = [System.IO.Path]::GetRelativePath($repoRoot, $stage2Compiler).Replace('\', '/')
            compilerFingerprint = (Get-FileHash -LiteralPath $stage2Compiler -Algorithm SHA256).Hash
            llvmPath = [System.IO.Path]::GetRelativePath($repoRoot, $stage2Llvm).Replace('\', '/')
            llvmFingerprint = (Get-FileHash -LiteralPath $stage2Llvm -Algorithm SHA256).Hash
            generatedByCompilerFingerprint = $stage1CompilerHash
            optimization = "O1"
            parallelCallbackCount = $candidateCallbacks.CallbackCount
            nominalTransferCallbackCount = $candidateCallbacks.NominalTransferCallbackCount
        }
    }
    $pairJson = ($pair | ConvertTo-Json -Depth 5) + "`n"
    $pairSchema = Join-Path $repoRoot "scripts/contracts/selfhost-bootstrap-performance-pair.schema.json"
    if (-not ($pairJson | Test-Json -SchemaFile $pairSchema -ErrorAction Stop)) {
        throw "bootstrap performance pair does not match $pairSchema"
    }
    $pairTemporaryPath = "$bootstrapPerformancePairReceipt.tmp-$([Guid]::NewGuid().ToString('N'))"
    [System.IO.File]::WriteAllText($pairTemporaryPath, $pairJson, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $pairTemporaryPath -Destination $bootstrapPerformancePairReceipt -Force
    Write-Host "[final gate] Bootstrap performance pair receipt PASS $bootstrapPerformancePairReceipt"
} elseif ($BootstrapStage2) {
    Write-Host "[final gate] Bootstrap performance pair deferred: Stage1 $Stage1Optimization is a functional feedback compiler, not an O1 performance control."
}

if ($Target -eq "linux" -and $CompareStage2) {
    Write-Host "[fast 5/5] Linux Stage2 parity is owned by scripts/verify-selfhost-stage2-linux.ps1."
} elseif ($CompareStage2 -and
    (Test-Path -LiteralPath $stage2Compiler) -and
    (Test-Fingerprint $stage2Fingerprint $stage2BuildHash)) {
    $stage2FocusedLlvm = Join-Path $cacheRoot "$actionHash-stage2.ll"
    $stage2FocusedError = Join-Path $cacheRoot "$actionHash-stage2.err"
    if (-not (Test-Path -LiteralPath $stage2FocusedLlvm) -or
        (Get-Item -LiteralPath $stage2FocusedLlvm).Length -eq 0) {
        Write-Host "[fast 5/5] Focused Stage2 LLVM cache MISS."
        $stage2EmitStarted = Get-Date
        Invoke-ToFile $stage2Compiler $fixtureCompilerArguments $stage2FocusedLlvm $stage2FocusedError
        $stage2EmitMs = [int]((Get-Date) - $stage2EmitStarted).TotalMilliseconds
        Write-Host "[timing] Focused Stage2 LLVM emission ${stage2EmitMs}ms."
    } else {
        Write-Host "[fast 5/5] Focused Stage2 LLVM cache HIT."
    }
    $stage2VerifyStarted = Get-Date
    & $llvmAs $stage2FocusedLlvm -o ([System.IO.Path]::ChangeExtension($stage2FocusedLlvm, ".bc"))
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $stage2VerifyMs = [int]((Get-Date) - $stage2VerifyStarted).TotalMilliseconds
    $stage1Hash = Get-NormalizedTextHash $stage1Llvm
    $stage2Hash = Get-NormalizedTextHash $stage2FocusedLlvm
    if ($stage1Hash -ne $stage2Hash) {
        throw "Stage1/Stage2 focused LLVM differs: stage1=$stage1Hash stage2=$stage2Hash"
    }
    Write-Host "[fast 5/5] Stage1/Stage2 LLVM parity PASS ${stage2VerifyMs}ms $stage2Hash"
} elseif ($CompareStage2) {
    Write-Host "[fast 5/5] Stage2 is stale; parity deferred to the explicit final bootstrap gate."
} else {
    Write-Host "[fast 5/5] Stage2 comparison disabled."
}

# The input fingerprint is a cache key, not an artifact verification receipt.
# Publish the executable hash only after LLVM verification and focused native
# execution have completed, so full self-host gates cannot accept a stale or
# merely linked feedback compiler as a verified SLG seed.
if (-not $ManagedOracleOnly -and
    -not $NoExecute -and
    (Test-Path -LiteralPath $expectedPath)) {
    $verifiedSourceFingerprint = Get-CompilerEmissionInputFingerprint `
        -RepositoryRoot $repoRoot `
        -Path $compilerInputSources
    if ($verifiedSourceFingerprint -cne $compilerEmissionSourceFingerprint) {
        throw "Stage1 compiler sources changed during verification; discard the candidate and rerun"
    }
    $verifiedStage1Hash = (Get-FileHash -LiteralPath $stage1Compiler -Algorithm SHA256).Hash
    [System.IO.File]::WriteAllText($stage1Receipt, $verifiedStage1Hash)
    $stage1GeneratorHash = if ($SeedMode -eq "Slg") {
        (Get-FileHash -LiteralPath $SlgSeedCompiler -Algorithm SHA256).Hash
    } else {
        $managedCompilerHash
    }
    $generation = [ordered]@{
        schemaVersion = 1
        mode = "verified-selfhost-stage1-generation"
        hostTarget = "windows"
        verificationTarget = $Target
        optimization = $Stage1Optimization
        seedMode = $SeedMode
        generatedByCompilerFingerprint = $stage1GeneratorHash
        sourceFingerprint = $verifiedSourceFingerprint
        compilerPath = [System.IO.Path]::GetRelativePath($repoRoot, $stage1Compiler).Replace('\', '/')
        compilerFingerprint = $verifiedStage1Hash
        llvmPath = [System.IO.Path]::GetRelativePath($repoRoot, $stage1HostLlvm).Replace('\', '/')
        llvmFingerprint = (Get-FileHash -LiteralPath $stage1HostLlvm -Algorithm SHA256).Hash
        focusedExecutionVerified = $true
        managedDifferential = $ManagedDifferential
    }
    $generationJson = ($generation | ConvertTo-Json -Depth 4) + "`n"
    $generationSchema = Join-Path $repoRoot "scripts/contracts/selfhost-stage1-generation.schema.json"
    if (-not ($generationJson | Test-Json -SchemaFile $generationSchema -ErrorAction Stop)) {
        throw "Stage1 generation receipt does not match $generationSchema"
    }
    $generationTemporaryPath = "$stage1GenerationReceipt.tmp-$([Guid]::NewGuid().ToString('N'))"
    [System.IO.File]::WriteAllText(
        $generationTemporaryPath,
        $generationJson,
        [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $generationTemporaryPath -Destination $stage1GenerationReceipt -Force
    Write-Host "[stage1 generation] Receipt PASS $stage1GenerationReceipt"
}

$elapsed = [int]((Get-Date) - $started).TotalMilliseconds
Write-Host "[fast complete] ${elapsed}ms selfhost=$($compilerHash.Substring(0, 12)) managed=$($managedCompilerHash.Substring(0, 12)) profile=$Stage1Optimization fixture=$($fixtureHash.Substring(0, 12))"
