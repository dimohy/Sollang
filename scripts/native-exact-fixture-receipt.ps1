Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "stage2-artifact-receipt.ps1")

function Assert-NativeExactCompilerDiagnostics {
    param([AllowEmptyString()][string]$Stdout, [AllowEmptyString()][string]$Stderr,
        [AllowEmptyString()][string]$ExpectedExactPath = '')
    $diagnostic = '(?m)^(?:warning S|note N)\d+\b'
    if ([string]::IsNullOrEmpty($ExpectedExactPath)) {
        if ([regex]::IsMatch($Stdout, $diagnostic) -or [regex]::IsMatch($Stderr, $diagnostic)) {
            throw 'EXACT_COMPILER_DIAGNOSTIC_UNEXPECTED'
        }
        return
    }
    if (-not (Test-Path -LiteralPath $ExpectedExactPath -PathType Leaf)) { throw 'EXACT_COMPILER_DIAGNOSTIC_CONTRACT_MISSING' }
    $expected = [IO.File]::ReadAllText($ExpectedExactPath, [Text.Encoding]::UTF8).Replace("`r`n", "`n")
    if ([string]::IsNullOrWhiteSpace($expected) -or -not $expected.EndsWith("`n", [StringComparison]::Ordinal)) {
        throw 'EXACT_COMPILER_DIAGNOSTIC_CONTRACT_INVALID'
    }
    foreach ($line in $expected.Substring(0, $expected.Length - 1).Split("`n")) {
        if (-not [regex]::IsMatch($line, $diagnostic)) { throw 'EXACT_COMPILER_DIAGNOSTIC_CONTRACT_INVALID' }
    }
    if ([regex]::IsMatch($Stdout, $diagnostic) -or $Stderr.Replace("`r`n", "`n") -cne $expected) {
        throw 'EXACT_COMPILER_STDERR_MISMATCH'
    }
}

function Get-NativeExactLlvmContracts {
    param([Parameter(Mandatory)][string]$ExpectedRoot,
        [Parameter(Mandatory)][string]$Fixture,
        [bool]$CompilerIsManagedDll = $false,
        [ValidateSet('', 'managed', 'selfhost')][string]$CompilerSide = '',
        [bool]$PhaseContractProvided = $false)
    if ($CompilerIsManagedDll -and $CompilerSide -ceq 'selfhost') {
        throw 'EXACT_LLVM_PRODUCER_IDENTITY_CONFLICT'
    }
    if ($CompilerSide -ceq 'managed' -and -not $CompilerIsManagedDll -and -not $PhaseContractProvided) {
        throw 'EXACT_LLVM_MANAGED_APPHOST_REQUIRES_PHASE_IDENTITY'
    }
    $producer = if ($CompilerIsManagedDll -or $CompilerSide -ceq 'managed') { 'managed' } else { 'selfhost' }
    $prefix = if ($producer -ceq 'managed') { 'llvm' } else { 'selfhost.llvm' }
    $negativeSuffixes = if ($producer -ceq 'managed') {
        @('llvm.not-contains.txt')
    } else { @('selfhost.llvm.not-contains.txt', 'llvm.not-contains.txt') }
    $negativePaths = @($negativeSuffixes | ForEach-Object { Join-Path $ExpectedRoot "$Fixture.$_" })
    $counts = Join-Path $ExpectedRoot "$Fixture.$prefix.regex-counts.txt"
    $ordered = Join-Path $ExpectedRoot "$Fixture.$prefix.ordered-regex.txt"
    [pscustomobject]@{ Producer = $producer; NotContains = $negativePaths; RegexCounts = $counts;
        OrderedRegex = $ordered; InputPaths = @(@($negativePaths) + @($counts, $ordered) |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }) }
}

function Assert-NativeExactLlvmContracts {
    param([Parameter(Mandatory)][string]$LlvmPath, [Parameter(Mandatory)]$Contracts)
    $llvm = [IO.File]::ReadAllText($LlvmPath)
    foreach ($path in $Contracts.InputPaths) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "EXACT_LLVM_CONTRACT_DISAPPEARED: $path" }
    }
    foreach ($path in $Contracts.NotContains) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            foreach ($forbidden in [IO.File]::ReadAllLines($path) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) {
                if ($llvm.Contains($forbidden.Trim(), [StringComparison]::Ordinal)) {
                    throw "EXACT_LLVM_FORBIDDEN_TEXT: $($forbidden.Trim())"
                }
            }
        }
    }
    if (Test-Path -LiteralPath $Contracts.RegexCounts -PathType Leaf) {
        $lines = @([IO.File]::ReadAllLines($Contracts.RegexCounts) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($lines.Count -eq 0) { throw 'EXACT_LLVM_EMPTY_REGEX_COUNTS' }
        foreach ($line in $lines) {
            $fields = $line.Split("`t", 2)
            if ($fields.Length -ne 2) { throw "EXACT_LLVM_INVALID_REGEX_COUNT: $line" }
            $actual = [regex]::Matches($llvm, $fields[1]).Count
            if ($actual -ne [int]$fields[0]) { throw "EXACT_LLVM_REGEX_COUNT: expected $($fields[0]), actual $actual, pattern $($fields[1])" }
        }
    }
    if (Test-Path -LiteralPath $Contracts.OrderedRegex -PathType Leaf) {
        $lines = @([IO.File]::ReadAllLines($Contracts.OrderedRegex) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($lines.Count -eq 0) { throw 'EXACT_LLVM_EMPTY_ORDERED_REGEX' }
        $cursor = 0
        foreach ($pattern in $lines) {
            $match = ([regex]::new($pattern)).Match($llvm, $cursor)
            if (-not $match.Success) { throw "EXACT_LLVM_ORDERED_REGEX: byte $cursor, pattern $pattern" }
            $cursor = $match.Index + $match.Length
        }
    }
}

function Assert-NativeExactFixturePlan {
    param([Parameter(Mandatory)][string[]]$Fixture)

    if ($Fixture.Count -eq 0) {
        throw "Native exact fixture plan requires at least one fixture"
    }

    $seen = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $Fixture) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw "Native exact fixture plan contains a blank fixture name"
        }
        if (-not $seen.Add($name)) {
            throw "Native exact fixture plan repeats fixture '$name'; each output and receipt must have exactly one writer"
        }
    }
}

function Get-NativeExactOrderedSourceClosure {
    param([Parameter(Mandatory)][string]$Root)

    $rootPath = (Resolve-Path -LiteralPath $Root).Path
    $paths = [string[]][System.IO.Directory]::GetFiles(
        $rootPath,
        "*.slg",
        [System.IO.SearchOption]::AllDirectories)
    [System.Array]::Sort($paths, [System.StringComparer]::Ordinal)
    if ($paths.Count -eq 0) {
        throw "Native exact source closure is empty: $rootPath"
    }
    return $paths
}

function Get-NativeExactWindowsCommonInputFingerprint {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$CompilerPath,
        [Parameter(Mandatory)][string]$StdlibRoot,
        [Parameter(Mandatory)][string]$LlvmRoot
    )

    $contractPath = Join-Path $PSScriptRoot "contracts\native-exact-fixture-receipt.json"
    $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
    $verificationPaths = @(
        (Join-Path $PSScriptRoot "verify-native-exact-fixture.ps1"),
        (Join-Path $PSScriptRoot "native-exact-fixture-receipt.ps1"),
        (Join-Path $PSScriptRoot "stage2-artifact-receipt.ps1"),
        (Join-Path $PSScriptRoot "verification-process.ps1"),
        (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1"),
        $contractPath
    )
    $toolPaths = @($contract.platformEnvironment.windows.contentHashedTools | ForEach-Object {
        Join-Path $LlvmRoot "bin\$_"
    })
    $settings = [ordered]@{
        nativeJobLimit = [string]$env:SOLLANG_NATIVE_JOBS
        platform = "windows"
        processorCount = [Environment]::ProcessorCount.ToString(
            [System.Globalization.CultureInfo]::InvariantCulture)
    }
    $paths = @((Resolve-Path -LiteralPath $CompilerPath).Path)
    $paths += @(Get-NativeExactOrderedSourceClosure -Root $StdlibRoot)
    $paths += $verificationPaths
    $paths += $toolPaths
    return Get-NativeExactFixtureInputFingerprint `
        -RepositoryRoot $RepositoryRoot `
        -Settings $settings `
        -InputPath $paths
}

function Get-NativeExactPerFixtureInputFingerprint {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$CommonFingerprint,
        [Parameter(Mandatory)][string]$Fixture,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][ValidateSet("windows", "linux")][string]$Platform,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Distribution,
        [Parameter(Mandatory)][ValidateRange(1, 64)][int]$Jobs,
        [Parameter(Mandatory)][ValidateRange(0, 2147483647)][long]$ExpectedStdoutLength,
        [Parameter(Mandatory)][string[]]$InputPath
    )

    if ($CommonFingerprint -cnotmatch '^[0-9A-F]{64}$') {
        throw "Native exact common fingerprint must be an uppercase SHA-256 value"
    }
    $settings = [ordered]@{
        commonFingerprint = $CommonFingerprint
        distribution = $Distribution
        expectedStdoutLength = $ExpectedStdoutLength.ToString(
            [System.Globalization.CultureInfo]::InvariantCulture)
        fixture = $Fixture
        jobs = $Jobs.ToString([System.Globalization.CultureInfo]::InvariantCulture)
        label = $Label
        platform = $Platform
    }
    return Get-NativeExactFixtureInputFingerprint `
        -RepositoryRoot $RepositoryRoot `
        -Settings $settings `
        -InputPath $InputPath
}

function Get-NativeExactFixtureInputFingerprint {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Settings,
        [Parameter(Mandatory)][string[]]$InputPath
    )

    $root = [System.IO.Path]::GetFullPath($RepositoryRoot)
    if ($Settings.Count -eq 0) {
        throw "Native exact input fingerprint requires at least one setting"
    }
    if ($InputPath.Count -eq 0) {
        throw "Native exact input fingerprint requires at least one file"
    }

    $hash = [System.Security.Cryptography.IncrementalHash]::CreateHash(
        [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    try {
        function Add-FingerprintText {
            param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

            $hash.AppendData([System.Text.Encoding]::UTF8.GetBytes($Text))
            $hash.AppendData([byte[]]@(0))
        }

        Add-FingerprintText "native-exact-fixture-input-v1"

        $settingNames = [string[]]@($Settings.Keys | ForEach-Object { [string]$_ })
        [System.Array]::Sort($settingNames, [System.StringComparer]::Ordinal)
        foreach ($name in $settingNames) {
            if ([string]::IsNullOrWhiteSpace($name)) {
                throw "Native exact input setting name must not be blank"
            }
            Add-FingerprintText "setting"
            Add-FingerprintText $name
            Add-FingerprintText ([string]$Settings[$name])
        }

        for ($index = 0; $index -lt $InputPath.Count; $index += 1) {
            $path = [System.IO.Path]::GetFullPath($InputPath[$index])
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                throw "Native exact input is missing: $path"
            }

            $relativePath = [System.IO.Path]::GetRelativePath($root, $path).Replace('\', '/')
            Add-FingerprintText "input"
            Add-FingerprintText $index.ToString([System.Globalization.CultureInfo]::InvariantCulture)
            Add-FingerprintText $relativePath
            $hash.AppendData([System.IO.File]::ReadAllBytes($path))
            $hash.AppendData([byte[]]@(0))
        }

        return [Convert]::ToHexString($hash.GetHashAndReset())
    } finally {
        $hash.Dispose()
    }
}

function Test-NativeExactFixtureInputReceipt {
    param(
        [Parameter(Mandatory)][string]$Fingerprint,
        [Parameter(Mandatory)][string]$ReceiptPath
    )

    if (-not (Test-Path -LiteralPath $ReceiptPath -PathType Leaf)) {
        return $false
    }

    $recorded = [System.IO.File]::ReadAllText($ReceiptPath).Trim()
    return $recorded -cmatch '^[0-9A-F]{64}$' -and $recorded -ceq $Fingerprint
}

function Write-NativeExactFixtureInputReceipt {
    param(
        [Parameter(Mandatory)][string]$Fingerprint,
        [Parameter(Mandatory)][string]$ReceiptPath
    )

    if ($Fingerprint -cnotmatch '^[0-9A-F]{64}$') {
        throw "Native exact input fingerprint must be an uppercase SHA-256 value"
    }

    $directory = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($ReceiptPath))
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    $candidatePath = "$ReceiptPath.$([guid]::NewGuid().ToString('N')).candidate"
    try {
        [System.IO.File]::WriteAllText($candidatePath, $Fingerprint)
        [System.IO.File]::Move($candidatePath, $ReceiptPath, $true)
    } finally {
        Remove-Item -LiteralPath $candidatePath -ErrorAction SilentlyContinue
    }
}

function Test-NativeExactFixtureReceipt {
    param(
        [Parameter(Mandatory)][string]$InputFingerprint,
        [Parameter(Mandatory)][string]$InputReceiptPath,
        [Parameter(Mandatory)][string]$LlvmPath,
        [Parameter(Mandatory)][string]$BitcodePath,
        [Parameter(Mandatory)][string]$ExecutablePath,
        [Parameter(Mandatory)][string]$OutputReceiptPath
    )

    return (Test-NativeExactFixtureInputReceipt `
            -Fingerprint $InputFingerprint `
            -ReceiptPath $InputReceiptPath) -and
        (Test-Stage2ArtifactReceipt `
            -LlvmPath $LlvmPath `
            -BitcodePath $BitcodePath `
            -ExecutablePath $ExecutablePath `
            -ReceiptPath $OutputReceiptPath)
}

function Publish-NativeExactFixtureReceipt {
    param(
        [Parameter(Mandatory)][string]$InputFingerprint,
        [Parameter(Mandatory)][string]$InputReceiptPath,
        [Parameter(Mandatory)][string]$LlvmPath,
        [Parameter(Mandatory)][string]$BitcodePath,
        [Parameter(Mandatory)][string]$ExecutablePath,
        [Parameter(Mandatory)][string]$OutputReceiptPath
    )

    # The input receipt is the commit marker. Publishing it last prevents a
    # canceled verification from authenticating a partially written output set.
    Write-Stage2ArtifactReceipt `
        -LlvmPath $LlvmPath `
        -BitcodePath $BitcodePath `
        -ExecutablePath $ExecutablePath `
        -ReceiptPath $OutputReceiptPath
    Write-NativeExactFixtureInputReceipt `
        -Fingerprint $InputFingerprint `
        -ReceiptPath $InputReceiptPath
}

# Optional phase evidence consumes reviewed authority. It never manufactures a
# source comparison, compiler build, or successful execution from a mode name.
function Get-NativeExactPhasePathRoot {
    param([string]$RepositoryRoot, [string]$FullPath)
    $root = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($RepositoryRoot))
    if ($FullPath.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { return $root }
    $policy = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'contracts/artifact-lifecycle.json') -Raw | ConvertFrom-Json
    if ($policy.externalOutputRoot -cne 'LOCALAPPDATA/Sollang') { throw 'PHASE_EXECUTION_ARTIFACT_POLICY_INVALID' }
    if ($IsWindows -and -not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $external = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Sollang')))
        if ($FullPath.StartsWith($external + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { return $external }
    }
    return ''
}

function Get-NativeExactPhaseFile {
    param([string]$RepositoryRoot, [string]$Path)
    $root = [IO.Path]::GetFullPath($RepositoryRoot)
    $full = [IO.Path]::GetFullPath($Path, $root)
    $allowedRoot = Get-NativeExactPhasePathRoot $root $full
    if ([string]::IsNullOrWhiteSpace($allowedRoot) -or
        -not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "PHASE_EXECUTION_FILE_BOUNDARY: $Path"
    }
    $ancestor = Get-Item -LiteralPath $full
    while ($null -ne $ancestor) {
        if ($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "PHASE_EXECUTION_REPARSE_POINT: $Path" }
        $ancestor = if ($ancestor -is [IO.DirectoryInfo]) { $ancestor.Parent } else { $ancestor.Directory }
    }
    return $full
}

function Get-NativeExactPhaseReference {
    param([string]$RepositoryRoot, [string]$Path)
    $full = Get-NativeExactPhaseFile $RepositoryRoot $Path
    $referencePath = if ($full.StartsWith([IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($RepositoryRoot)) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        [IO.Path]::GetRelativePath($RepositoryRoot, $full)
    } else { $full }
    return [ordered]@{ path = $referencePath.Replace('\', '/');
        sha256 = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLowerInvariant() }
}

function Assert-NativeExactPhaseOutputPath {
    param([string]$RepositoryRoot, [string]$Path)
    $root = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($RepositoryRoot))
    $full = [IO.Path]::GetFullPath($Path, $root)
    if ([string]::IsNullOrWhiteSpace((Get-NativeExactPhasePathRoot $root $full))) {
        throw 'PHASE_EXECUTION_OUTPUT_BOUNDARY'
    }
    $ancestor = $full
    while ($ancestor) {
        if (Test-Path -LiteralPath $ancestor) {
            if ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw 'PHASE_EXECUTION_OUTPUT_REPARSE_POINT'
            }
        }
        $ancestor = [IO.Path]::GetDirectoryName($ancestor)
    }
    return $full
}

function Read-NativeExactPhaseReference {
    param([string]$RepositoryRoot, $Reference)
    $actual = Get-NativeExactPhaseReference $RepositoryRoot $Reference.path
    if ($actual.sha256 -ine $Reference.sha256) { throw "PHASE_EXECUTION_REFERENCE_DRIFT: $($Reference.path)" }
    return Get-Content -LiteralPath ([IO.Path]::GetFullPath($actual.path, $RepositoryRoot)) -Raw | ConvertFrom-Json
}

function Get-NativeExactPhaseHashes {
    param([string]$RepositoryRoot, [string[]]$Path)
    $hashes = [ordered]@{}
    foreach ($name in $Path) {
        $reference = Get-NativeExactPhaseReference $RepositoryRoot $name
        $hashes[$reference.path] = $reference.sha256
    }
    return $hashes
}

function Get-NativeExactPhaseCompilerRuntimeHashes {
    param([string]$CompilerPath)
    $hashes = [ordered]@{}
    if ([IO.Path]::GetExtension($CompilerPath) -ieq '.dll') {
        foreach ($file in Get-ChildItem -LiteralPath ([IO.Path]::GetDirectoryName($CompilerPath)) -File |
            Where-Object { $_.Extension -ieq '.dll' -or $_.Name.EndsWith('.deps.json') -or $_.Name.EndsWith('.runtimeconfig.json') }) {
            $hashes[$file.FullName] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }
    return $hashes
}

function Assert-NativeExactPhaseHashes {
    param([string]$RepositoryRoot, [Collections.IDictionary]$Hashes)
    foreach ($name in $Hashes.Keys) {
        $actual = Get-NativeExactPhaseReference $RepositoryRoot $name
        if ($actual.sha256 -ine $Hashes[$name]) { throw "PHASE_EXECUTION_INPUT_DRIFT: $name" }
    }
}

function Get-NativeExactPhaseExpectedStage {
    param($Case, [string]$Stage, [string]$CompilerSide)
    if ($CompilerSide -cnotin @('managed','selfhost')) { throw 'PHASE_EXECUTION_COMPILER_SIDE_INVALID' }
    $value = $Case.expectedStages.$Stage
    $names = @($value.PSObject.Properties.Name)
    $validate = {
        param($candidate)
        $keys = @($candidate.PSObject.Properties.Name)
        if ($keys.Count -notin @(3,4) -or @($keys | Where-Object { $_ -cnotin @('exitCode','stdout','stderr','stdoutPolicy') }).Count -gt 0 -or
            ($candidate.exitCode -isnot [int] -and $candidate.exitCode -isnot [long]) -or
            $candidate.stdout -isnot [string] -or $candidate.stderr -isnot [string]) { throw 'PHASE_EXECUTION_EXACT_ORACLE_REQUIRED' }
        if ('stdoutPolicy' -cin $keys -and ($candidate.stdoutPolicy -cne 'compiler-build-telemetry-v1' -or
            $Stage -cne 'compile' -or $candidate.exitCode -ne 0 -or $candidate.stdout -cne '' -or $candidate.stderr -cne '')) {
            throw 'PHASE_EXECUTION_BUILD_STDOUT_POLICY_SCOPE'
        }
    }
    if ('compilerSides' -cin $names) {
        if ($Stage -cnotin @('compile','grammar') -or $names.Count -ne 1) { throw 'PHASE_EXECUTION_COMPILE_SIDE_ORACLE_ONLY' }
        $sides = $value.compilerSides
        $sideNames = @($sides.PSObject.Properties.Name)
        if ($sideNames.Count -ne 2 -or 'managed' -cnotin $sideNames -or 'selfhost' -cnotin $sideNames) { throw 'PHASE_EXECUTION_BOTH_SIDE_ORACLES_REQUIRED' }
        & $validate $sides.managed
        & $validate $sides.selfhost
        if ($sides.managed.exitCode -ne $sides.selfhost.exitCode) { throw 'PHASE_EXECUTION_SIDE_EXITS_DIFFER' }
        return $sides.$CompilerSide
    }
    & $validate $value
    return $value
}

function Get-NativeExactPhaseContext {
    param([string]$RepositoryRoot, [string]$ContractPath, [ValidateSet('managed', 'selfhost')][string]$CompilerSide,
        [string]$CompilerPath, [string]$RunnerPath, [string[]]$WholeFixturePlan=@())
    $root = [IO.Path]::GetFullPath($RepositoryRoot)
    $contractRef = Get-NativeExactPhaseReference $root $ContractPath
    $contract = Get-Content -LiteralPath ([IO.Path]::GetFullPath($contractRef.path, $root)) -Raw | ConvertFrom-Json
    if ($contract.schemaVersion -ne 1 -or [string]::IsNullOrWhiteSpace($contract.phase)) { throw 'PHASE_EXECUTION_CONTRACT_INVALID' }
    $inventory = Read-NativeExactPhaseReference $root $contract.reviewedInventory
    if ($inventory.status -cne 'reviewed' -or $inventory.phase -cne $contract.phase) { throw 'PHASE_EXECUTION_INVENTORY_UNREVIEWED' }
    $schemaPath = Join-Path $PSScriptRoot 'contracts/native-exact-phase-execution.schema.json'
    if (-not (Test-Json -Json ($contract | ConvertTo-Json -Depth 50) -SchemaFile $schemaPath -ErrorAction Stop)) {
        throw 'PHASE_EXECUTION_CONTRACT_INVALID'
    }
    $authorityPath = Join-Path $PSScriptRoot 'contracts/structural-parity-detail.json'
    $authority = Get-Content -LiteralPath $authorityPath -Raw | ConvertFrom-Json
    $phase = @($authority.phaseProgress | Where-Object phase -CEQ $contract.phase)
    if ($phase.Count -ne 1 -or
        (ConvertTo-Json -InputObject $inventory.sourceScopes -Depth 8 -Compress) -cne
        (ConvertTo-Json -InputObject $phase[0].decisionInventory.sourceScopes -Depth 8 -Compress)) {
        throw 'PHASE_EXECUTION_SOURCE_SCOPE_NARROWED'
    }
    if ($phase[0].decisionInventory.status -cne 'reviewed' -or
        (ConvertTo-Json -InputObject $phase[0].decisionInventory.decisions -Depth 30 -Compress) -cne
        (ConvertTo-Json -InputObject $inventory.decisions -Depth 30 -Compress) -or
        (@($phase[0].decisionInventory.requiredDecisionIds) -join "`0") -cne (@($inventory.requiredDecisionIds) -join "`0")) {
        throw 'PHASE_EXECUTION_REVIEW_AUTHORITY_MISMATCH'
    }
    $ids = @($inventory.requiredDecisionIds)
    if ($ids.Count -eq 0 -or @($ids | Select-Object -Unique).Count -ne $ids.Count -or
        ($ids -join "`0") -cne (@($contract.decisionIds) -join "`0") -or
        (@($inventory.decisions.id) -join "`0") -cne ($ids -join "`0")) { throw 'PHASE_EXECUTION_DECISION_INVENTORY_INVALID' }
    $sourceHashes = [ordered]@{}
    foreach ($side in @('managed', 'selfhost')) {
        $extension = if ($side -eq 'managed') { '.cs' } else { '.slg' }
        $sources = @($inventory.sourceScopes.$side | ForEach-Object {
            $path = [IO.Path]::GetFullPath($_, $root)
            if (-not $path.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
                throw 'PHASE_EXECUTION_SOURCE_SCOPE_BOUNDARY'
            }
            if (Test-Path -LiteralPath $path -PathType Container) {
                Get-ChildItem -LiteralPath $path -Recurse -File -Filter "*$extension" | ForEach-Object { Get-NativeExactPhaseFile $root $_.FullName }
            } else { Get-NativeExactPhaseFile $root $_ }
        } | Select-Object -Unique)
        $covered = @($inventory.decisions | ForEach-Object { $_.($side + 'Sources') } | Select-Object -Unique)
        $relativeSources = @($sources | ForEach-Object { [IO.Path]::GetRelativePath($root, $_).Replace('\', '/') })
        if (@(Compare-Object $relativeSources $covered -CaseSensitive).Count -ne 0) { throw 'PHASE_EXECUTION_SOURCE_REVIEW_INCOMPLETE' }
        foreach ($entry in (Get-NativeExactPhaseHashes $root $sources).GetEnumerator()) { $sourceHashes[$entry.Key] = $entry.Value }
    }
    foreach ($decision in $inventory.decisions) {
        if ($decision.status -cne 'complete') { throw 'PHASE_EXECUTION_DECISION_PENDING' }
        foreach ($field in @('structure', 'branches', 'logic', 'diagnostics')) {
            if ([string]::IsNullOrWhiteSpace($decision.$field)) { throw "PHASE_EXECUTION_DECISION_FIELD_MISSING: $field" }
        }
    }
    $expectedShared = @()
    if ($contract.phase -ceq 'parsing') {
        $expectedShared = @($phase[0].decisionInventory.sharedDependencies)
        if ((@($inventory.sharedDependencies) -join "`0") -cne ($expectedShared -join "`0")) { throw 'PHASE_EXECUTION_SHARED_SCOPE_NARROWED' }
        foreach ($entry in (Get-NativeExactPhaseHashes $root $expectedShared).GetEnumerator()) { $sourceHashes[$entry.Key] = $entry.Value }
        [void](Read-NativeExactPhaseReference $root $contract.generationRecord)
    }
    $parseTokens = $null; $parseErrors = $null
    $defaultAst = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'verify-native-exact-fixture-batch.ps1'), [ref]$parseTokens, [ref]$parseErrors)
    if ($parseErrors.Count -ne 0) { throw 'PHASE_EXECUTION_RUNNER_PARSE_FAILED' }
    $defaultPlan = @((($defaultAst.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Fixture' }).DefaultValue).SafeGetValue())
    if ((@($contract.wholeFixturePlan) -join "`0") -cne ($defaultPlan -join "`0") -or
        ($WholeFixturePlan.Count -gt 0 -and ($WholeFixturePlan -join "`0") -cne ($defaultPlan -join "`0"))) { throw 'PHASE_EXECUTION_WHOLE_PLAN_NARROWED' }
    $wholeInputs = [Collections.Generic.List[string]]::new()
    foreach ($fixtureName in $defaultPlan) {
        $wholeInputs.Add((Get-NativeExactPhaseFile $root "examples/regression/$fixtureName.slg"))
        $wholeInputs.Add((Get-NativeExactPhaseFile $root "examples/regression/expected/$fixtureName.stdout.txt"))
        foreach ($gold in Get-ChildItem -LiteralPath (Join-Path $root 'examples/regression/expected') -File -Filter "$fixtureName.*") {
            $wholeInputs.Add($gold.FullName)
        }
        $manifest = Join-Path $root "examples/regression/expected/$fixtureName.sources.txt"
        if (Test-Path -LiteralPath $manifest) {
            foreach ($line in [IO.File]::ReadAllLines($manifest)) {
                if (-not [string]::IsNullOrWhiteSpace($line)) { $wholeInputs.Add((Get-NativeExactPhaseFile $root $line.Trim())) }
            }
        }
    }
    $comparisonReference = $null; $comparison = $null
    # CPP-first capture has no dependency on its own future comparison link.
    # The immutable contract declares that link's path; selfhost consumes the
    # actual compared file only after CPP execution has completed.
    if ($CompilerSide -ceq 'selfhost') {
    $comparisonReference = if ($contract.sourceComparisonRecord -is [string]) {
        Get-NativeExactPhaseReference $root $contract.sourceComparisonRecord
    } else { $contract.sourceComparisonRecord }
    $comparison = Read-NativeExactPhaseReference $root $comparisonReference
    if ($comparison.status -cne 'compared' -or $comparison.phase -cne $contract.phase) { throw 'PHASE_EXECUTION_COMPARISON_MISSING' }
    $comparisonHashes = $comparison.sourceHashes
    foreach ($name in $sourceHashes.Keys) {
        $hash = if ($name -cin $expectedShared) { $comparison.sharedDependencyHashes.$name } else { $comparisonHashes.$name }
        if ($hash -ine $sourceHashes[$name]) { throw 'PHASE_EXECUTION_COMPARISON_STALE' }
    }
    if ((ConvertTo-Json -InputObject $comparison.decisions -Depth 30 -Compress) -cne
        (ConvertTo-Json -InputObject $inventory.decisions -Depth 30 -Compress)) { throw 'PHASE_EXECUTION_COMPARISON_DECISIONS_DIFFER' }
    if ($comparison.managedFirstRecord.path -cne $inventory.managedFirstRecord) { throw 'PHASE_EXECUTION_MANAGED_FIRST_LINK_MISSING' }
    $managedFirst = Read-NativeExactPhaseReference $root $comparison.managedFirstRecord
    if ($managedFirst.status -cne 'passed' -or $managedFirst.phase -cne $contract.phase -or $managedFirst.inputStable -ne $true -or
        $managedFirst.exitCode -ne 0 -or $managedFirst.canceled -ne $false -or @($managedFirst.failureIds).Count -ne 0 -or
        @($managedFirst.orphanProcessIds).Count -ne 0) { throw 'PHASE_EXECUTION_MANAGED_FIRST_INVALID' }
    }
    $binary = $contract.compilerBinaries.$CompilerSide
    if ([IO.Path]::GetFullPath($binary.path, $root) -cne [IO.Path]::GetFullPath($CompilerPath, $root) -or
        (Get-FileHash -LiteralPath $CompilerPath -Algorithm SHA256).Hash -ine $binary.sha256) { throw 'PHASE_EXECUTION_COMPILER_MISMATCH' }
    $build = Read-NativeExactPhaseReference $root ([pscustomobject]@{path=$binary.buildRecord;sha256=$binary.buildRecordSha256})
    if ($build.status -cne 'passed' -or $build.phase -cne $contract.phase -or $build.compilerSide -cne $CompilerSide -or
        $build.inputStable -ne $true -or $build.exitCode -ne 0 -or $build.canceled -ne $false -or
        @($build.failureIds).Count -ne 0 -or @($build.orphanProcessIds).Count -ne 0 -or
        $build.completed -ne 1 -or $build.total -ne 1 -or $build.binary.sha256 -ine $binary.sha256 -or
        $build.binary.path -cne $binary.path) { throw 'PHASE_EXECUTION_BUILD_AUTHORITY_MISSING' }
    $sideHashes = [ordered]@{}
    foreach ($name in $sourceHashes.Keys) {
        if ($name -in $expectedShared -or $name.EndsWith($(if ($CompilerSide -eq 'managed') { '.cs' } else { '.slg' }))) {
            $sideHashes[$name] = $sourceHashes[$name]
        }
    }
    foreach ($name in $sideHashes.Keys) {
        if ($build.sourceHashesStart.$name -ine $sideHashes[$name] -or $build.sourceHashesEnd.$name -ine $sideHashes[$name]) {
            throw 'PHASE_EXECUTION_BUILD_SOURCE_DRIFT'
        }
    }
    $cases = @($contract.cases)
    if ($cases.Count -eq 0 -or @($cases.id | Select-Object -Unique).Count -ne $cases.Count) { throw 'PHASE_EXECUTION_CASES_INVALID' }
    $covered = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $fixtureIdentities = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $caseIdentities = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($case in $cases) {
        if (-not $fixtureIdentities.Add($case.fixture.path) -or -not $caseIdentities.Add($case.id)) { throw 'PHASE_EXECUTION_DUPLICATE_FIXTURE_OR_OUTPUT' }
        $fixtureReference = Get-NativeExactPhaseReference $root $case.fixture.path
        if ($fixtureReference.sha256 -ine $case.fixture.sha256) { throw 'PHASE_EXECUTION_FIXTURE_DRIFT' }
        if (@($case.decisionIds).Count -eq 0) { throw 'PHASE_EXECUTION_CASE_DECISION_MISSING' }
        if ('grammarCommand' -cin @($case.PSObject.Properties.Name)) {
            Assert-NativeExactPhaseGrammarCase $root $case $CompilerSide
            foreach ($reference in @($case.grammarCommand.lexer,$case.grammarCommand.grammar)) {
                $actual = Get-NativeExactPhaseReference $root $reference.path
                $wholeInputs.Add((Get-NativeExactPhaseFile $root $actual.path))
            }
            foreach ($id in $case.decisionIds) { if ($id -cnotin $ids) { throw 'PHASE_EXECUTION_UNKNOWN_DECISION' }; [void]$covered.Add($id) }
            continue
        }
        $compileExpected = Get-NativeExactPhaseExpectedStage $case compile $CompilerSide
        if ($compileExpected.exitCode -eq 0) {
            # Additional phase witnesses supplement, rather than replace, the
            # immutable405 batch. They use the same canonical fixture verifier.
            if ($case.fixture.path -cnotmatch '^examples/regression/[^/\\]+\.slg$') {
                throw 'PHASE_EXECUTION_POSITIVE_FIXTURE_BOUNDARY'
            }
            $fixtureName = [IO.Path]::GetFileNameWithoutExtension($case.fixture.path)
            $wholeInputs.Add((Get-NativeExactPhaseFile $root "examples/regression/expected/$fixtureName.stdout.txt"))
            foreach ($gold in Get-ChildItem -LiteralPath (Join-Path $root 'examples/regression/expected') -File -Filter "$fixtureName.*") {
                $wholeInputs.Add($gold.FullName)
            }
            $manifest = Join-Path $root "examples/regression/expected/$fixtureName.sources.txt"
            if (Test-Path -LiteralPath $manifest) {
                foreach ($line in [IO.File]::ReadAllLines($manifest)) {
                    if (-not [string]::IsNullOrWhiteSpace($line)) { $wholeInputs.Add((Get-NativeExactPhaseFile $root $line.Trim())) }
                }
            }
        }
        foreach ($id in $case.decisionIds) { if ($id -cnotin $ids) { throw 'PHASE_EXECUTION_UNKNOWN_DECISION' }; [void]$covered.Add($id) }
        $stageNames = @($case.expectedStages.PSObject.Properties.Name)
        if ('compile' -cnotin $stageNames -or @($stageNames | Where-Object { $_ -cnotin @('compile','run') }).Count -gt 0 -or
            (($compileExpected.exitCode -eq 0) -ne ('run' -cin $stageNames))) { throw 'PHASE_EXECUTION_STAGE_PLAN_INVALID' }
        if ('run' -cin $stageNames -and $case.expectedStages.run.exitCode -ne 0) { throw 'PHASE_EXECUTION_RUN_SUCCESS_REQUIRED' }
        foreach ($stage in $stageNames) {
            $expected = Get-NativeExactPhaseExpectedStage $case $stage $CompilerSide
            if (($expected.exitCode -isnot [int] -and $expected.exitCode -isnot [long]) -or
                $expected.stdout -isnot [string] -or $expected.stderr -isnot [string]) { throw 'PHASE_EXECUTION_EXACT_ORACLE_REQUIRED' }
        }
    }
    if ($covered.Count -ne $ids.Count) { throw 'PHASE_EXECUTION_DECISION_UNCOVERED' }
    [void](Assert-NativeExactPhaseOutputPath $root $contract.evidenceDirectory)
    foreach ($side in @('managed','selfhost')) { [void](Assert-NativeExactPhaseOutputPath $root $contract.batchReports.$side) }
    $canonicalRunner = Join-Path $PSScriptRoot 'verify-native-exact-fixture-batch.ps1'
    $comparisonInputs = @()
    if ($null -ne $comparison) { $comparisonInputs = @($comparisonReference.path, $comparison.managedFirstRecord.path) }
    # The immutable reviewed inventory is pinned below. Canonical scopes and
    # decisions are checked against it on entry and again during completion.
    # Do not hash the mutable progress container: recording phase completion
    # would otherwise invalidate the very execution evidence used to close it.
    $buildStdoutPython = $null
    $buildStdoutInputs = @()
    if (@($cases | Where-Object { (Get-NativeExactPhaseExpectedStage $_ $(if ('grammarCommand' -cin @($_.PSObject.Properties.Name)) {'grammar'} else {'compile'}) $CompilerSide).PSObject.Properties.Name -contains 'stdoutPolicy' }).Count -gt 0) {
        $buildStdoutPython = (Get-Command python -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
        $probe = & $buildStdoutPython -c 'import sys; assert sys.version_info >= (3, 9); print(sys.executable)'
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $probe -PathType Leaf)) { throw 'PHASE_EXECUTION_BUILD_STDOUT_PYTHON_UNAVAILABLE' }
        $buildStdoutInputs = @((Get-NativeExactPhaseFile $root (Join-Path $PSScriptRoot 'verification_build_stdout.py')))
    }
    $inputs = Get-NativeExactPhaseHashes $root (@($sourceHashes.Keys) + @($contractRef.path, $contract.reviewedInventory.path,
        $binary.buildRecord, $RunnerPath, $canonicalRunner, (Join-Path $PSScriptRoot 'verification-process.ps1'),
        (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1'),
        (Join-Path $PSScriptRoot 'contracts/artifact-lifecycle.json'), $schemaPath) + @($cases.fixture.path) + $comparisonInputs + @($wholeInputs) + $buildStdoutInputs)

    return [pscustomobject]@{ Root=$root; Contract=$contract; ContractReference=$contractRef; CompilerSide=$CompilerSide;
        CompilerBinary=[ordered]@{path=$binary.path;sha256=$binary.sha256}; RunnerReference=(Get-NativeExactPhaseReference $root $canonicalRunner);
        InputHashes=$inputs; SourceHashes=$sourceHashes; SideSourceHashes=$sideHashes; SourceComparisonReference=$comparisonReference;
        BuildStdoutPython=$buildStdoutPython;
        ActualRunnerPath=$RunnerPath; CompilerRuntimeHashes=(Get-NativeExactPhaseCompilerRuntimeHashes ([IO.Path]::GetFullPath($CompilerPath, $root))) }
}

function Get-NativeExactPhaseOutcomePrefix {
    param($Context, $Case)
    if ($Case.id -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { throw 'PHASE_EXECUTION_CASE_ID_INVALID' }
    $directory = Assert-NativeExactPhaseOutputPath $Context.Root $Context.Contract.evidenceDirectory
    [void][IO.Directory]::CreateDirectory($directory)
    return Join-Path $directory "$($Context.CompilerSide)-$($Case.id)"
}

function Complete-NativeExactPhaseExecution {
    param($Context)
    [void](Get-NativeExactPhaseCommandInputs $Context)
    # Re-enumeration detects newly created source/oracle inputs as well as edits
    # to existing files. A missing input is never replaced by an old receipt.
    if ($Context.PSObject.Properties.Name -contains 'ActualRunnerPath') {
        $endContext = Get-NativeExactPhaseContext $Context.Root $Context.ContractReference.path $Context.CompilerSide `
            ([IO.Path]::GetFullPath($Context.CompilerBinary.path, $Context.Root)) $Context.ActualRunnerPath
        if (@(Compare-Object @($Context.InputHashes.Keys) @($endContext.InputHashes.Keys) -CaseSensitive).Count -ne 0) {
            throw 'PHASE_EXECUTION_INPUT_MEMBERSHIP_DRIFT'
        }
    }
    $batchPath = [IO.Path]::GetFullPath($Context.Contract.batchReports.($Context.CompilerSide), $Context.Root)
    if (-not (Test-Path -LiteralPath $batchPath -PathType Leaf)) { return $false }
    $batchReference = Get-NativeExactPhaseReference $Context.Root $batchPath
    $batch = Read-NativeExactPhaseReference $Context.Root ([pscustomobject]$batchReference)
    if ($batch.state -cne 'passed' -or $batch.total -ne 405 -or $batch.completed -ne 405 -or
        $batch.passed -ne 405 -or $batch.failed -ne 0 -or $batch.missing -ne 0 -or
        $batch.compilerSha256 -ine $Context.CompilerBinary.sha256 -or
        (@($batch.phaseFixturePlan) -join "`0") -cne (@($Context.Contract.wholeFixturePlan) -join "`0") -or
        @($batch.results).Count -ne 405 -or @($batch.results | Where-Object { $_.Success -ne $true }).Count -ne 0 -or
        @(Compare-Object @($batch.results.Fixture) @($Context.Contract.wholeFixturePlan) -CaseSensitive).Count -ne 0) {
        throw 'PHASE_EXECUTION_WHOLE_BATCH_UNVERIFIED'
    }
    $rows = @()
    foreach ($case in $Context.Contract.cases) {
        $prefix = Get-NativeExactPhaseOutcomePrefix $Context $case
        $stages = [ordered]@{}
        foreach ($stage in $case.expectedStages.PSObject.Properties.Name) {
            if (-not (Test-Path -LiteralPath "$prefix.$stage.json" -PathType Leaf)) { return $false }
            $reference = Get-NativeExactPhaseReference $Context.Root "$prefix.$stage.json"
            $outcome = Read-NativeExactPhaseReference $Context.Root ([pscustomobject]$reference)
            if ($outcome.status -cne 'passed' -or $outcome.compilerSide -cne $Context.CompilerSide -or $outcome.stage -cne $stage) {
                throw 'PHASE_EXECUTION_OUTCOME_IDENTITY_INVALID'
            }
            Assert-NativeExactPhaseHashes $Context.Root ([Collections.IDictionary]($outcome.inputHashesStart | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable))
            $stages[$stage] = $reference
        }
        $binaries = [ordered]@{}; $binaries[$Context.CompilerSide] = $Context.Contract.compilerBinaries.($Context.CompilerSide)
        $outcomes = [ordered]@{}; $outcomes[$Context.CompilerSide] = $stages
        $rows += [ordered]@{id=$case.id;fixture=$case.fixture;decisionIds=@($case.decisionIds);status='passed';
            exitCode=0;failureIds=@();orphanProcessIds=@();canceled=$false;compilerBinaries=$binaries;outcomes=$outcomes}
    }
    $sideRecord = [ordered]@{schemaVersion=1;phase=$Context.Contract.phase;status='passed';mode='phase-exhaustive';
        exitCode=0;failureIds=@();orphanProcessIds=@();canceled=$false;inputStable=$true;completed=$rows.Count;total=$rows.Count;
        decisionIds=@($Context.Contract.decisionIds);sourceHashesStart=$Context.SideSourceHashes;sourceHashesEnd=$Context.SideSourceHashes;
        wholeFixtureInputHashesStart=$Context.InputHashes;wholeFixtureInputHashesEnd=$Context.InputHashes;
        compilerRuntimeHashesStart=@{};compilerRuntimeHashesEnd=@{};
        compilerBinaries=$binaries;cases=$rows;executionInputs=[ordered]@{runner=$Context.RunnerReference;contract=$Context.ContractReference};
        wholeFixtureBatch=$batchReference;
        consumerState='pending-structural-phase-validation'}
    if ($Context.CompilerSide -ceq 'selfhost') { $sideRecord.sourceComparisonRecord=$Context.SourceComparisonReference }
    if ($Context.PSObject.Properties.Name -contains 'CompilerRuntimeHashes') {
        $sideRecord.compilerRuntimeHashesStart=$Context.CompilerRuntimeHashes; $sideRecord.compilerRuntimeHashesEnd=$Context.CompilerRuntimeHashes
    }
    if ($Context.Contract.phase -ceq 'parsing') { $sideRecord.generationRecord=$Context.Contract.generationRecord }
    $path = Join-Path ([IO.Path]::GetDirectoryName($prefix)) "$($Context.CompilerSide)-phase-execution.json"
    if (Test-Path -LiteralPath $path) { throw 'PHASE_EXECUTION_RECORD_ALREADY_EXISTS' }
    [IO.File]::WriteAllText($path, ($sideRecord | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
    # Individual sides are retained. A paired record is written only after both
    # sides have real outcomes for every contracted case; no partial promotion.
    $managedPath = Join-Path ([IO.Path]::GetDirectoryName($path)) 'managed-phase-execution.json'
    $selfhostPath = Join-Path ([IO.Path]::GetDirectoryName($path)) 'selfhost-phase-execution.json'
    if ($Context.CompilerSide -ceq 'selfhost' -and (Test-Path -LiteralPath $managedPath) -and (Test-Path -LiteralPath $selfhostPath)) {
        $managed = Get-Content -LiteralPath $managedPath -Raw | ConvertFrom-Json
        $selfhost = Get-Content -LiteralPath $selfhostPath -Raw | ConvertFrom-Json
        if ($managed.executionInputs.contract.sha256 -ine $Context.ContractReference.sha256 -or
            $selfhost.executionInputs.contract.sha256 -ine $Context.ContractReference.sha256) { throw 'PHASE_EXECUTION_SIDE_CONTRACT_MISMATCH' }
        $comparison = Read-NativeExactPhaseReference $Context.Root $Context.SourceComparisonReference
        $managedReference = Get-NativeExactPhaseReference $Context.Root $managedPath
        if ($comparison.managedFirstRecord.path -cne $managedReference.path -or $comparison.managedFirstRecord.sha256 -ine $managedReference.sha256) {
            throw 'PHASE_EXECUTION_MANAGED_FIRST_LINK_DIFFER'
        }
        foreach ($side in @($managed,$selfhost)) {
            [void](Read-NativeExactPhaseReference $Context.Root $side.wholeFixtureBatch)
            $sideName = @($side.compilerBinaries.PSObject.Properties.Name)[0]
            $currentRuntime = Get-NativeExactPhaseCompilerRuntimeHashes ([IO.Path]::GetFullPath($side.compilerBinaries.$sideName.path, $Context.Root))
            $runtime = $side.compilerRuntimeHashesStart | ConvertTo-Json -Depth 8 | ConvertFrom-Json -AsHashtable
            if (@(Compare-Object @($currentRuntime.Keys) @($runtime.Keys) -CaseSensitive).Count -gt 0) { throw 'PHASE_EXECUTION_COMPILER_RUNTIME_MEMBERSHIP_DRIFT' }
            foreach ($name in $runtime.Keys) {
                if ($runtime[$name] -ine $currentRuntime[$name]) { throw 'PHASE_EXECUTION_COMPILER_RUNTIME_DRIFT' }
            }
        }
        $pairedBinaries = [ordered]@{managed=$Context.Contract.compilerBinaries.managed;selfhost=$Context.Contract.compilerBinaries.selfhost}
        for ($index=0; $index -lt $rows.Count; $index++) {
            $rows[$index].compilerBinaries=$pairedBinaries
            $rows[$index].outcomes=[ordered]@{managed=$managed.cases[$index].outcomes.managed;selfhost=$selfhost.cases[$index].outcomes.selfhost}
        }
        $sideRecord.compilerBinaries=$pairedBinaries; $sideRecord.cases=$rows
        $sideRecord.sourceHashesStart=$Context.SourceHashes; $sideRecord.sourceHashesEnd=$Context.SourceHashes
        $sideRecord.wholeFixtureBatches=[ordered]@{managed=$managed.wholeFixtureBatch;selfhost=$selfhost.wholeFixtureBatch}
        $pairedPath = Join-Path ([IO.Path]::GetDirectoryName($path)) 'paired-phase-execution.json'
        if (Test-Path -LiteralPath $pairedPath) { throw 'PHASE_EXECUTION_RECORD_ALREADY_EXISTS' }
        [IO.File]::WriteAllText($pairedPath, ($sideRecord | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
    }
    return $true
}

function Get-NativeExactPhaseCommandInputs {
    param($Context, [string[]]$AdditionalInput=@())
    Assert-NativeExactPhaseHashes $Context.Root $Context.InputHashes
    $compiler = [IO.Path]::GetFullPath($Context.CompilerBinary.path, $Context.Root)
    if ((Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash -ine $Context.CompilerBinary.sha256) { throw 'PHASE_EXECUTION_COMPILER_DRIFT' }
    if ($Context.PSObject.Properties.Name -contains 'CompilerRuntimeHashes') {
        $runtime = Get-NativeExactPhaseCompilerRuntimeHashes $compiler
        if (@(Compare-Object @($runtime.Keys) @($Context.CompilerRuntimeHashes.Keys) -CaseSensitive).Count -gt 0) { throw 'PHASE_EXECUTION_COMPILER_RUNTIME_MEMBERSHIP_DRIFT' }
        foreach ($path in $runtime.Keys) {
            if ($runtime[$path] -ine $Context.CompilerRuntimeHashes[$path]) { throw 'PHASE_EXECUTION_COMPILER_RUNTIME_DRIFT' }
        }
    }
    return Get-NativeExactPhaseHashes $Context.Root (@($Context.InputHashes.Keys) + $AdditionalInput)
}

function Write-NativeExactPhaseOutcome {
    param($Context, $Case, [ValidateSet('compile','run','grammar')][string]$Stage, [string]$ProcessRecordPath,
        [string]$OutputPath, [string]$BinaryPath='', [Parameter(Mandatory)][Collections.IDictionary]$InputHashesStart)
    Assert-NativeExactPhaseHashes $Context.Root $Context.InputHashes
    $processReference = Get-NativeExactPhaseReference $Context.Root $ProcessRecordPath
    $process = Read-NativeExactPhaseReference $Context.Root ([pscustomobject]$processReference)
    if ($process.pid -isnot [long] -and $process.pid -isnot [int]) { throw 'PHASE_EXECUTION_REAL_PROCESS_MISSING' }
    if ($process.pid -le 0 -or @($process.command).Count -eq 0 -or $process.finishedAtUtc -eq $null -or
        $process.processesStopped -ne $true -or $process.failure -ne $null -or
        $process.status -cnotin @('passed','failed')) { throw 'PHASE_EXECUTION_PROCESS_UNCONFIRMED' }
    $expected = Get-NativeExactPhaseExpectedStage $Case $Stage $Context.CompilerSide
    if ($Stage -ceq 'grammar') {
        Assert-NativeExactPhaseGrammarCase $Context.Root $Case $Context.CompilerSide
        $expectedCommand = @(Get-NativeExactPhaseGrammarCommand $Context $Case $OutputPath)
        if ((@($process.command) -join "`0") -cne ($expectedCommand -join "`0")) {
            throw 'PHASE_EXECUTION_GRAMMAR_COMMAND_MISMATCH'
        }
        foreach ($reference in @($Case.grammarCommand.lexer,$Case.grammarCommand.grammar)) {
            if ($InputHashesStart[$reference.path] -ine $reference.sha256) { throw 'PHASE_EXECUTION_GRAMMAR_INPUT_NOT_PINNED' }
        }
        if (Test-Path -LiteralPath "$OutputPath.generated.slg") { throw 'PHASE_EXECUTION_NEGATIVE_PRODUCT' }
    }
    $stdout = [IO.File]::ReadAllText((Get-NativeExactPhaseFile $Context.Root $process.stdoutPath))
    $stderr = [IO.File]::ReadAllText((Get-NativeExactPhaseFile $Context.Root $process.stderrPath))
    $stdoutComparison = $null
    $semanticStdout = $stdout
    if ('stdoutPolicy' -cin @($expected.PSObject.Properties.Name)) {
        if ($process.exit -ne 0) { throw 'PHASE_EXECUTION_EXACT_OUTCOME_MISMATCH' }
        $command = @($process.command)
        $outputFlags = @(for ($i=0; $i -lt $command.Count; $i++) { if ($command[$i] -ceq '-o') { $i } })
        $offset = if ([IO.Path]::GetExtension($Context.CompilerBinary.path) -ieq '.dll') { 2 } else { 1 }
        if ($command.Count -le $offset -or $command[$offset] -cne 'build' -or $outputFlags.Count -ne 1 -or
            $outputFlags[0]+1 -ge $command.Count -or
            [IO.Path]::GetFullPath($command[$outputFlags[0]+1]) -cne [IO.Path]::GetFullPath($BinaryPath)) {
            throw 'PHASE_EXECUTION_BUILD_STDOUT_PRODUCT_COMMAND_MISMATCH'
        }
        $helper = Join-Path $PSScriptRoot 'verification_build_stdout.py'
        $helperRef = Get-NativeExactPhaseReference $Context.Root $helper
        if ($InputHashesStart[$helperRef.path] -ine $helperRef.sha256 -or
            $Context.PSObject.Properties.Name -cnotcontains 'BuildStdoutPython' -or -not $Context.BuildStdoutPython) {
            throw 'PHASE_EXECUTION_BUILD_STDOUT_DEPENDENCY_NOT_PINNED'
        }
        $comparisonJson = & $Context.BuildStdoutPython $helper --stdout-path $process.stdoutPath --binary-path $BinaryPath --compiler-side $Context.CompilerSide
        if ($LASTEXITCODE -ne 0) { throw 'PHASE_EXECUTION_BUILD_STDOUT_INVALID' }
        $stdoutComparison = $comparisonJson | ConvertFrom-Json
        $semanticStdout = $stdoutComparison.semanticStdout
    }
    if ($process.exit -ne $expected.exitCode -or $semanticStdout -cne $expected.stdout -or $stderr -cne $expected.stderr) { throw 'PHASE_EXECUTION_EXACT_OUTCOME_MISMATCH' }
    foreach ($name in $Context.InputHashes.Keys) {
        if ($InputHashesStart[$name] -ine $Context.InputHashes[$name]) { throw 'PHASE_EXECUTION_START_INPUT_NOT_PINNED' }
    }
    if ($Stage -ceq 'compile') {
        $compilerPath = [IO.Path]::GetFullPath($Context.CompilerBinary.path, $Context.Root)
        $commandCompiler = if ([IO.Path]::GetExtension($compilerPath) -ieq '.dll') {
            if (@($process.command).Count -lt 2) { throw 'PHASE_EXECUTION_COMPILER_COMMAND_MISMATCH' }
            $process.command[1]
        } else { $process.command[0] }
        if ($commandCompiler -cne $compilerPath -or
            [IO.Path]::GetFullPath($Case.fixture.path, $Context.Root) -cnotin @($process.command)) {
            throw 'PHASE_EXECUTION_COMPILER_COMMAND_MISMATCH'
        }
    }
    $inputs = Get-NativeExactPhaseCommandInputs $Context @($InputHashesStart.Keys)
    Assert-NativeExactPhaseHashes $Context.Root $InputHashesStart
    $record = [ordered]@{schemaVersion=1;phase=$Context.Contract.phase;compilerSide=$Context.CompilerSide;stage=$Stage;status='passed';exitCode=$process.exit;expectedExitCode=$expected.exitCode;
        actualStdout=$stdout;actualStderr=$stderr;failureIds=@();orphanProcessIds=@();canceled=$false;processesStopped=$true;
        compilerBinary=$Context.CompilerBinary;processRecord=$processReference;
        stdoutRecord=(Get-NativeExactPhaseReference $Context.Root $process.stdoutPath);
        stderrRecord=(Get-NativeExactPhaseReference $Context.Root $process.stderrPath);
        inputHashesStart=$InputHashesStart;inputHashesEnd=$inputs}
    if ($null -ne $stdoutComparison) { $record.stdoutComparison=$stdoutComparison }
    if ($Context.PSObject.Properties.Name -contains 'CompilerRuntimeHashes') {
        $record.compilerRuntimeHashesStart=$Context.CompilerRuntimeHashes; $record.compilerRuntimeHashesEnd=$Context.CompilerRuntimeHashes
    }
    if ($process.exit -eq 0) {
        if ([string]::IsNullOrWhiteSpace($BinaryPath)) { throw 'PHASE_EXECUTION_BINARY_MISSING' }
        $binary = Get-NativeExactPhaseReference $Context.Root $BinaryPath
        if ($Stage -eq 'run') {
            $compiled = Get-Content -LiteralPath "$OutputPath.compile.json" -Raw | ConvertFrom-Json
            if ($binary.path -cne $compiled.outputBinary.path -or $binary.sha256 -ine $compiled.outputBinary.sha256 -or
                $process.command[0] -cne [IO.Path]::GetFullPath($BinaryPath)) { throw 'PHASE_EXECUTION_DIFFERENT_EXECUTABLE' }
            if ($InputHashesStart[$binary.path] -ine $binary.sha256) { throw 'PHASE_EXECUTION_RUN_BINARY_NOT_PINNED' }
            $record.executableBinary=$binary
        } else { $record.outputBinary=$binary }
    } elseif (-not [string]::IsNullOrWhiteSpace($BinaryPath) -and (Test-Path -LiteralPath $BinaryPath)) { throw 'PHASE_EXECUTION_NEGATIVE_PRODUCT' }
    $path = "$OutputPath.$Stage.json"
    if (Test-Path -LiteralPath $path) { throw 'PHASE_EXECUTION_RECORD_ALREADY_EXISTS' }
    [IO.File]::WriteAllText($path, ($record | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
    return Get-NativeExactPhaseReference $Context.Root $path
}

# Grammar rejection is a public command decision, not a program compilation.
# Its strict nonzero oracle cannot substitute for a positive compile/run case.
function Assert-NativeExactPhaseGrammarCase {
    param([string]$Root, $Case, [string]$CompilerSide)
    if ((@($Case.expectedStages.PSObject.Properties.Name) -join "`0") -cne 'grammar' -or
        (Get-NativeExactPhaseExpectedStage $Case grammar $CompilerSide).exitCode -ne 1 -or
        ($Case.fixture | ConvertTo-Json -Compress) -cne ($Case.grammarCommand.grammar | ConvertTo-Json -Compress)) {
        throw 'PHASE_EXECUTION_GRAMMAR_CASE_INVALID'
    }
    foreach ($reference in @($Case.grammarCommand.lexer,$Case.grammarCommand.grammar)) {
        $actual = Get-NativeExactPhaseReference $Root $reference.path
        if ($actual.sha256 -ine $reference.sha256) { throw 'PHASE_EXECUTION_GRAMMAR_INPUT_DRIFT' }
    }
}

function Get-NativeExactPhaseGrammarCommand {
    param($Context, $Case, [string]$Prefix)
    $compiler = [IO.Path]::GetFullPath($Context.CompilerBinary.path, $Context.Root)
    $command = @($compiler)
    if ([IO.Path]::GetExtension($compiler) -ieq '.dll') {
        $command = @((Get-Command dotnet -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source,$compiler)
    }
    return $command + @('grammar','build',
        (Get-NativeExactPhaseFile $Context.Root $Case.grammarCommand.lexer.path),
        (Get-NativeExactPhaseFile $Context.Root $Case.grammarCommand.grammar.path),'-o',
        (Assert-NativeExactPhaseOutputPath $Context.Root "$Prefix.generated.slg"))
}

function Invoke-NativeExactPhaseGrammarCase {
    param($Context, $Case)
    Assert-NativeExactPhaseGrammarCase $Context.Root $Case $Context.CompilerSide
    $prefix = Get-NativeExactPhaseOutcomePrefix $Context $Case
    if ((Test-Path -LiteralPath "$prefix.grammar.json") -or (Test-Path -LiteralPath "$prefix.generated.slg")) {
        throw 'PHASE_EXECUTION_RECORD_ALREADY_EXISTS'
    }
    $inputs = Get-NativeExactPhaseCommandInputs $Context @($Case.grammarCommand.lexer.path,$Case.grammarCommand.grammar.path)
    $command = @(Get-NativeExactPhaseGrammarCommand $Context $Case $prefix)
    $processPath = "$prefix.grammar.execution.json"
    $null = Invoke-VerificationProcessCapture -FilePath $command[0] -ArgumentList $command[1..($command.Count-1)] `
        -WorkingDirectory $Context.Root -Description 'phase grammar rejection' -TimeoutMilliseconds 120000 `
        -ExecutionRecordPath $processPath
    return Write-NativeExactPhaseOutcome $Context $Case grammar $processPath $prefix -InputHashesStart $inputs
}
