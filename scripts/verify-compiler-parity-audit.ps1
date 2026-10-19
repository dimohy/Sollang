[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ContractPath,
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')

$root = [System.IO.Path]::GetFullPath($RepositoryRoot)
$schemaPath = Join-Path $root 'scripts/contracts/compiler-parity-audit.schema.json'
$authorityPath = Join-Path $root 'scripts/contracts/ai-slg-best-practices.json'
$submatrixPath = Join-Path $root 'scripts/contracts/expression-lowering-parity.json'
if (-not $ContractPath) {
    $ContractPath = Join-Path $root 'scripts/contracts/compiler-parity-audit.json'
}
foreach ($path in @($schemaPath, $authorityPath, $submatrixPath, $ContractPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Compiler parity audit input is missing: $path"
    }
}

$authority = Get-Content -LiteralPath $authorityPath -Raw | ConvertFrom-Json
$submatrix = Get-Content -LiteralPath $submatrixPath -Raw | ConvertFrom-Json
$expectedIds = @($authority.featureFamilies | ForEach-Object { [string]$_.id })
if ($expectedIds.Count -ne 30 -or @($expectedIds | Sort-Object -Unique).Count -ne 30) {
    throw 'The authoritative feature-family inventory is not 30 distinct identities; update the audit contract deliberately.'
}
if ([int]$submatrix.managedExpressionInventoryTotal -ne 42 -or @($submatrix.mappings).Count -ne 42) {
    throw 'The linked expression submatrix no longer has 42 exact managed-expression identities.'
}
$expressionIds = @($submatrix.mappings | ForEach-Object { [string]$_.managedExpression })
if (@($expressionIds | Sort-Object -Unique).Count -ne 42) {
    throw 'The linked expression submatrix has duplicate managed-expression identities.'
}

function Resolve-AuditPath {
    param([string]$RelativePath)
    if ($RelativePath -notmatch '^(src/Sollang\.Compiler/|selfhost/|examples/(user|regression)/|scripts/probes/|artifacts/)') {
        throw "Audit path is outside its allowed source/evidence roots: $RelativePath"
    }
    if ($RelativePath.Contains('..') -or $RelativePath.Contains('\')) {
        throw "Audit path contains a traversal or noncanonical separator: $RelativePath"
    }
    $full = [System.IO.Path]::GetFullPath((Join-Path $root $RelativePath))
    if (-not $full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Audit path escapes repository root: $RelativePath"
    }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "Audit path does not exist: $RelativePath"
    }
    Assert-AuditNoReparsePoints $full
    return $full
}

function Assert-AuditNoReparsePoints {
    param([string]$FullPath)
    $absolute = [IO.Path]::GetFullPath($FullPath)
    if (-not $absolute.StartsWith($root + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw "Audit proof path escapes repository root: $FullPath"
    }
    $relative = [IO.Path]::GetRelativePath($root, $absolute)
    $current = $root
    foreach ($segment in ($relative -split '[\\/]')) {
        $current = Join-Path $current $segment
        $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Audit proof path traverses a reparse point: $FullPath"
        }
    }
}

function Assert-AuditProbeExpectation {
    param([string]$Id, [string]$FixtureName, [string]$Source, [string]$Expected)
    if (-not $Source.StartsWith('scripts/probes/', [System.StringComparison]::Ordinal)) {
        if ($Expected -and $Expected.StartsWith('scripts/probes/', [System.StringComparison]::Ordinal)) {
            throw "$Id $FixtureName probe expectation needs a probe source."
        }
        return
    }
    if ($Source -cnotmatch '^scripts/probes/(?:[A-Za-z0-9_-]+/)*[A-Za-z0-9_-]+\.slg$') {
        throw "$Id $FixtureName probe source is not a canonical in-repository SLG path."
    }
    if (-not $Expected) { return }
    $stem = $Source.Substring(0, $Source.Length - '.slg'.Length)
    $suffix = if ($FixtureName -ceq 'positiveFixture') {
        '\.stdout\.txt'
    } else {
        '\.(?:compiler\.)?stderr(?:\.contains)?\.txt'
    }
    if ($Expected -cnotmatch ('^' + [regex]::Escape($stem) + $suffix + '$')) {
        throw "$Id $FixtureName probe expectation must share the source directory and filename stem."
    }
}

function Get-AuditFingerprint {
    param($Family)
    # Canonical per-family input closure: owner sources, both exact fixtures and expectations,
    # the authoritative inventory, and the linked expression submatrix where applicable.
    $paths = @(
        'scripts/contracts/ai-slg-best-practices.json',
        [string]$Family.managedOwner.path,
        [string]$Family.selfhostOwner.path,
        [string]$Family.positiveFixture.source,
        [string]$Family.positiveFixture.expected,
        [string]$Family.negativeFixture.source,
        [string]$Family.negativeFixture.expected
    )
    if ($Family.submatrix) { $paths += [string]$Family.submatrix }
    $lines = foreach ($relativePath in @($paths | Where-Object { $_ } | Sort-Object -Unique -CaseSensitive)) {
        $full = if ($relativePath.StartsWith('scripts/contracts/', [System.StringComparison]::Ordinal)) {
            Join-Path $root $relativePath
        } else {
            Resolve-AuditPath $relativePath
        }
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "Fingerprint input missing: $relativePath" }
        "$relativePath=$((Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLowerInvariant())"
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($lines -join "`n") + "`n")
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return [System.Convert]::ToHexString($hash).ToLowerInvariant()
}

function Read-AuditPinnedResult {
    param([string]$Id, [string]$Name, $Pin)
    if (-not $Pin -or -not $Pin.path -or -not $Pin.sha256) {
        throw "$Id $Name needs an exact path and SHA-256 pin."
    }
    $path = [string]$Pin.path
    if ($path -cnotmatch '^artifacts/scratch/.+\.json$') {
        throw "$Id $Name is not an artifacts/scratch JSON result: $path"
    }
    $full = Resolve-AuditPath $path
    $actualSha = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    if ($actualSha -cne ([string]$Pin.sha256).ToUpperInvariant()) {
        throw "$Id $Name SHA-256 pin differs from its result file: $path"
    }
    return [pscustomobject]@{
        Path = $full
        Json = (Get-Content -LiteralPath $full -Raw)
    }
}

function Assert-AuditPositiveBatch {
    param([string]$Id, [string]$Name, $Batch, [string]$ResultPath,
        [string]$CompilerSha, [string]$FixtureName)
    foreach ($field in @('schemaVersion', 'label', 'platform', 'state', 'compilerSha256',
            'commonInputFingerprint', 'completed',
            'passed', 'failed', 'missing', 'total', 'results')) {
        if (-not $Batch.PSObject.Properties[$field]) { throw "$Id $Name lacks $field." }
    }
    if ($Batch.schemaVersion -ne 1 -or $Batch.platform -cne 'windows' -or $Batch.state -cne 'passed' -or
        ([string]$Batch.compilerSha256).ToUpperInvariant() -cne $CompilerSha.ToUpperInvariant() -or
        [string]$Batch.label -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]+$' -or
        [string]$Batch.commonInputFingerprint -cnotmatch '^[a-fA-F0-9]{64}$' -or
        [IO.Path]::GetFileName($ResultPath) -cne "$($Batch.label)-batch-results.json") {
        throw "$Id $Name is not a passed Windows batch for the pinned compiler."
    }
    foreach ($field in @('completed', 'passed', 'failed', 'missing', 'total')) {
        if ($Batch.$field -isnot [int] -and $Batch.$field -isnot [long]) {
            throw "$Id $Name has a non-integer $field batch count."
        }
    }
    $results = @($Batch.results)
    if ($Batch.total -lt 1 -or $Batch.completed -ne $Batch.total -or $Batch.passed -ne $Batch.total -or
        $Batch.failed -ne 0 -or $Batch.missing -ne 0 -or $results.Count -ne $Batch.total) {
        throw "$Id $Name batch counts do not prove every planned fixture passed."
    }
    $names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($result in $results) {
        if (-not $result.PSObject.Properties['Fixture'] -or -not $result.PSObject.Properties['Success'] -or
            -not $result.PSObject.Properties['Error'] -or
            [string]$result.Fixture -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$' -or
            $result.Success -isnot [bool] -or $result.Success -cne $true -or
            -not [string]::IsNullOrEmpty([string]$result.Error) -or
            -not $names.Add([string]$result.Fixture)) {
            throw "$Id $Name has a missing, duplicate, or failed fixture result."
        }
    }
    if (-not $names.Contains($FixtureName)) {
        throw "$Id $Name does not include positive fixture $FixtureName."
    }
}

function Get-AuditExactFixtureInputPaths {
    param([string]$FixtureName)
    $source = Resolve-AuditPath "examples/regression/$FixtureName.slg"
    $expectedDirectory = Join-Path $root 'examples/regression/expected'
    $manifest = Join-Path $expectedDirectory "$FixtureName.sources.txt"
    $arguments = Join-Path $expectedDirectory "$FixtureName.args.txt"
    $expected = Resolve-AuditPath "examples/regression/expected/$FixtureName.stdout.txt"
    $sourcePaths = @()
    if (Test-Path -LiteralPath $manifest -PathType Leaf) {
        foreach ($line in (Get-Content -LiteralPath $manifest)) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $relative = $line.Trim()
            if ([IO.Path]::IsPathRooted($relative) -or $relative.Contains('..') -or $relative.Contains('\')) {
                throw "Exact fixture source manifest has an unsafe path: $relative"
            }
            $full = [IO.Path]::GetFullPath((Join-Path $root $relative))
            if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
                throw "Exact fixture source manifest input is missing: $relative"
            }
            Assert-AuditNoReparsePoints $full
            $sourcePaths += $full
        }
        if ($source -cnotin $sourcePaths) {
            throw "Exact fixture source manifest omits its executable root: $FixtureName"
        }
    } else {
        $sourcePaths = @($source)
    }
    $contracts = [System.Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath $arguments -PathType Leaf) {
        Assert-AuditNoReparsePoints $arguments
        $contracts.Add($arguments)
    }
    if (Test-Path -LiteralPath $manifest -PathType Leaf) {
        Assert-AuditNoReparsePoints $manifest
        $contracts.Add($manifest)
    }
    $contracts.Add($expected)
    foreach ($suffix in @('selfhost.llvm.not-contains.txt', 'llvm.not-contains.txt',
            'selfhost.llvm.regex-counts.txt', 'selfhost.llvm.ordered-regex.txt')) {
        $path = Join-Path $expectedDirectory "$FixtureName.$suffix"
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            Assert-AuditNoReparsePoints $path
            $contracts.Add($path)
        }
    }
    return @($sourcePaths) + @($contracts)
}

function Assert-AuditExactInputReceipt {
    param([string]$Id, [string]$Name, [string]$Fingerprint, [string]$ReceiptPath)
    if (-not (Test-NativeExactFixtureInputReceipt -Fingerprint $Fingerprint -ReceiptPath $ReceiptPath)) {
        throw "$Id $Name exact per-fixture input receipt is stale or invalid."
    }
}

function Assert-AuditPositiveReceipt {
    param([string]$Id, [string]$Name, $Pin, $Batch, [string]$BatchPath,
        [string]$CompilerSha, [string]$FixtureName)
    $compilerRelative = [string]$Pin.compilerPath
    $expectedCompilerPattern = if ($Name -ceq 'managed positive batch') {
        '^src/Sollang\.Compiler/.+\.dll$'
    } else {
        '^artifacts/scratch/.+\.exe$'
    }
    if ($compilerRelative -cnotmatch $expectedCompilerPattern -or $Pin.jobs -isnot [int] -and
        $Pin.jobs -isnot [long] -or $Pin.jobs -lt 1 -or $Pin.jobs -gt 64) {
        throw "$Id $Name has an invalid current compiler path or exact worker count."
    }
    $compilerPath = Resolve-AuditPath $compilerRelative
    if ((Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash -cne $CompilerSha.ToUpperInvariant()) {
        throw "$Id $Name current compiler differs from the pinned compiler."
    }
    $stdlibPath = Join-Path $root 'stdlib'
    $llvmPath = Join-Path $root '.tools/llvm-22.1.8'
    foreach ($directory in @($stdlibPath, $llvmPath)) {
        if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
            throw "$Id $Name current stdlib or LLVM root is missing."
        }
        Assert-AuditNoReparsePoints $directory
    }
    $common = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root `
        -CompilerPath $compilerPath -StdlibRoot $stdlibPath -LlvmRoot $llvmPath
    if ($common -cne ([string]$Batch.commonInputFingerprint).ToUpperInvariant()) {
        throw "$Id $Name current compiler, stdlib, LLVM, or runner inputs drifted from its batch."
    }
    $inputPaths = @(Get-AuditExactFixtureInputPaths $FixtureName)
    $inputFingerprint = Get-NativeExactPerFixtureInputFingerprint -RepositoryRoot $root `
        -CommonFingerprint $common -Fixture $FixtureName -Label ([string]$Batch.label) `
        -Platform windows -Distribution Ubuntu -Jobs ([int]$Pin.jobs) -ExpectedStdoutLength 0 `
        -InputPath $inputPaths
    $outputRoot = Split-Path -Parent $BatchPath
    $artifactBase = Join-Path $outputRoot "$($Batch.label)-exact-$FixtureName"
    $executable = "$artifactBase.exe"
    $llvm = if ($Name -ceq 'managed positive batch') {
        [IO.Path]::ChangeExtension($executable, '.ll')
    } else {
        "$executable.ll"
    }
    $inputReceipt = "$executable.inputs.sha256"
    $outputReceipt = "$executable.outputs.sha256"
    foreach ($path in @($executable, $llvm, "$executable.bc", $inputReceipt, $outputReceipt)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "$Id $Name exact per-fixture output or receipt is missing: $path"
        }
        Assert-AuditNoReparsePoints $path
    }
    Assert-AuditExactInputReceipt $Id $Name $inputFingerprint $inputReceipt
    if (-not (Test-Stage2ArtifactReceipt -LlvmPath $llvm -BitcodePath "$executable.bc" `
            -ExecutablePath $executable -ReceiptPath $outputReceipt)) {
        throw "$Id $Name exact per-fixture output receipt is stale or invalid."
    }
}

function Get-AuditNegativeCurrentFingerprint {
    param([string]$Id, $Negative, [string]$ManagedSha, [string]$SelfhostSha,
        [string]$SourcePath, [string]$ExpectedPath)
    $compilerPaths = @([string]$Negative.managedCompilerPath, [string]$Negative.selfhostCompilerPath)
    $shaValues = @($ManagedSha, $SelfhostSha)
    for ($index = 0; $index -lt 2; $index++) {
        $compilerPath = $compilerPaths[$index]
        if (-not [IO.Path]::IsPathRooted($compilerPath) -or
            -not (Test-Path -LiteralPath $compilerPath -PathType Leaf)) {
            throw "$Id negative compiler path is missing or not absolute."
        }
        Assert-AuditNoReparsePoints $compilerPath
        if ((Get-FileHash -LiteralPath $compilerPath -Algorithm SHA256).Hash -cne $shaValues[$index].ToUpperInvariant()) {
            throw "$Id negative current compiler differs from its pinned SHA."
        }
    }
    if ([IO.Path]::GetExtension($compilerPaths[0]) -cne '.dll' -or
        [IO.Path]::GetExtension($compilerPaths[1]) -cne '.exe') {
        throw "$Id negative compiler paths have the wrong kinds."
    }
    $stdlibPath = [string]$Negative.stdlibRoot
    $llvmPath = [string]$Negative.llvmRoot
    foreach ($directory in @($stdlibPath, $llvmPath)) {
        if (-not [IO.Path]::IsPathRooted($directory) -or
            -not (Test-Path -LiteralPath $directory -PathType Container)) {
            throw "$Id negative stdlib or LLVM root is missing or not absolute."
        }
        Assert-AuditNoReparsePoints $directory
    }
    $managedCommon = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root `
        -CompilerPath $compilerPaths[0] -StdlibRoot $stdlibPath -LlvmRoot $llvmPath
    $selfhostCommon = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root `
        -CompilerPath $compilerPaths[1] -StdlibRoot $stdlibPath -LlvmRoot $llvmPath
    $settings = [ordered]@{
        gate = 'compiler-parity-negative-fixture-v1'
        managedCommon = $managedCommon
        selfhostCommon = $selfhostCommon
        managedSha256 = $ManagedSha.ToUpperInvariant()
        selfhostSha256 = $SelfhostSha.ToUpperInvariant()
        timeoutMilliseconds = [string][int]$Negative.timeoutMilliseconds
    }
    $dotnetPath = (Get-Command dotnet -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $inputs = @(
        (Join-Path $PSScriptRoot 'verify-compiler-parity-negative-fixture.ps1'),
        (Join-Path $PSScriptRoot 'verification-process.ps1'),
        (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1'),
        (Join-Path $PSScriptRoot 'contracts/compiler-parity-negative-fixture-result.schema.json'),
        $dotnetPath, $SourcePath, $ExpectedPath
    )
    foreach ($path in $inputs) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "$Id negative current fingerprint input is missing: $path"
        }
        if ($path.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            Assert-AuditNoReparsePoints $path
        }
    }
    return Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root -Settings $settings -InputPath $inputs
}

function Assert-AuditNegativeResult {
    param([string]$Id, $Negative, [string]$ResultPath, [string]$SourcePath,
        [string]$ExpectedPath, [string]$ManagedSha, [string]$SelfhostSha,
        [string]$CurrentFingerprint)
    $schema = Join-Path $root 'scripts/contracts/compiler-parity-negative-fixture-result.schema.json'
    if (-not (Test-Path -LiteralPath $schema -PathType Leaf)) {
        throw "$Id negative result schema is missing."
    }
    $json = $Negative | ConvertTo-Json -Depth 12 -Compress
    if (-not (Test-Json -Json $json -SchemaFile $schema)) {
        throw "$Id negative result does not satisfy its result schema."
    }
    if ($Negative.state -cne 'passed' -or $Negative.gate -cne 'compiler-parity-negative-fixture' -or
        $Negative.inputsStable -cne $true -or
        ([string]$Negative.inputFingerprintStart).ToUpperInvariant() -cne
            ([string]$Negative.inputFingerprintEnd).ToUpperInvariant() -or
        ([string]$Negative.inputFingerprintStart).ToUpperInvariant() -cne $CurrentFingerprint.ToUpperInvariant() -or
        @($Negative.orphanProcessIds).Count -ne 0 -or $null -ne $Negative.failureId -or
        ([string]$Negative.managedCompilerSha256).ToUpperInvariant() -cne $ManagedSha.ToUpperInvariant() -or
        ([string]$Negative.selfhostCompilerSha256).ToUpperInvariant() -cne $SelfhostSha.ToUpperInvariant()) {
        throw "$Id negative result lacks a stable passed run with matching compiler identities."
    }
    if (-not [IO.Path]::IsPathRooted([string]$Negative.source) -or
        -not [IO.Path]::IsPathRooted([string]$Negative.expected) -or
        -not ([IO.Path]::GetFullPath([string]$Negative.source)).Equals($SourcePath, [StringComparison]::OrdinalIgnoreCase) -or
        -not ([IO.Path]::GetFullPath([string]$Negative.expected)).Equals($ExpectedPath, [StringComparison]::OrdinalIgnoreCase) -or
        ([string]$Negative.sourceSha256).ToUpperInvariant() -cne (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash -or
        ([string]$Negative.expectedSha256).ToUpperInvariant() -cne (Get-FileHash -LiteralPath $ExpectedPath -Algorithm SHA256).Hash) {
        throw "$Id negative result source or expectation differs from the current exact fixture."
    }
    $expectedFragment = [IO.File]::ReadAllText($ExpectedPath).Trim()
    if ([string]::IsNullOrWhiteSpace($expectedFragment)) {
        throw "$Id negative expectation is blank."
    }
    $resultDirectory = Split-Path -Parent $ResultPath
    foreach ($compilerName in @('managed', 'selfhost')) {
        $check = $Negative.$compilerName
        $stdoutPath = Join-Path $resultDirectory "$compilerName.stdout.txt"
        $stderrPath = Join-Path $resultDirectory "$compilerName.stderr.txt"
        $outputDirectory = Join-Path $resultDirectory $compilerName
        foreach ($path in @($stdoutPath, $stderrPath, $outputDirectory)) {
            if (Test-Path -LiteralPath $path) { Assert-AuditNoReparsePoints $path }
        }
        if ($check.exitCode -eq 0 -or $check.nonzeroExit -cne $true -or
            $check.expectedInStderr -cne $true -or $check.noEmittedProducts -cne $true -or
            @($check.generatedProducts).Count -ne 0 -or
            -not ([IO.Path]::GetFullPath([string]$check.stdoutPath)).Equals($stdoutPath, [StringComparison]::OrdinalIgnoreCase) -or
            -not ([IO.Path]::GetFullPath([string]$check.stderrPath)).Equals($stderrPath, [StringComparison]::OrdinalIgnoreCase) -or
            -not ([IO.Path]::GetFullPath([string]$check.outputDirectory)).Equals($outputDirectory, [StringComparison]::OrdinalIgnoreCase) -or
            -not ([IO.Path]::GetFullPath([string]$Negative.logs."$($compilerName)Stdout")).Equals($stdoutPath, [StringComparison]::OrdinalIgnoreCase) -or
            -not ([IO.Path]::GetFullPath([string]$Negative.logs."$($compilerName)Stderr")).Equals($stderrPath, [StringComparison]::OrdinalIgnoreCase) -or
            -not (Test-Path -LiteralPath $stdoutPath -PathType Leaf) -or
            -not (Test-Path -LiteralPath $stderrPath -PathType Leaf) -or
            -not (Test-Path -LiteralPath $outputDirectory -PathType Container) -or
            @((Get-ChildItem -LiteralPath $outputDirectory -Recurse -Force)).Count -ne 0 -or
            -not ([IO.File]::ReadAllText($stderrPath)).Contains($expectedFragment, [StringComparison]::Ordinal)) {
            throw "$Id negative $compilerName result lacks exact diagnostic, failure, or empty products."
        }
    }
}

function Assert-AuditPromotionProof {
    param([string]$Id, $Family)
    $proof = $Family.evidence.promotionProof
    if (-not $proof) { throw "$Id promoted evidence needs three SHA-pinned execution results." }
    $source = [string]$Family.positiveFixture.source
    if ($source -cnotmatch '^examples/regression/([A-Za-z0-9][A-Za-z0-9_-]*)\.slg$') {
        throw "$Id positive source cannot be identified by native exact batch; use a regression fixture."
    }
    $fixtureName = $Matches[1]
    if ([string]$Family.positiveFixture.expected -cne "examples/regression/expected/$fixtureName.stdout.txt") {
        throw "$Id positive expectation does not identify the exact batch fixture."
    }
    $negativeSource = [string]$Family.negativeFixture.source
    if ($negativeSource -cnotmatch '^scripts/probes/(?:[A-Za-z0-9_-]+/)*[A-Za-z0-9_-]+\.slg$' -or
        [string]$Family.negativeFixture.expected -cne
            ($negativeSource.Substring(0, $negativeSource.Length - '.slg'.Length) + '.stderr.contains.txt')) {
        throw "$Id negative fixture must be a same-stem probe supported by the exact negative verifier."
    }
    $managed = Read-AuditPinnedResult $Id 'managed positive batch' $proof.managedPositiveBatch
    $selfhost = Read-AuditPinnedResult $Id 'selfhost positive batch' $proof.selfhostPositiveBatch
    $negative = Read-AuditPinnedResult $Id 'negative result' $proof.negativeResult
    if ($managed.Path -ceq $selfhost.Path -or $managed.Path -ceq $negative.Path -or $selfhost.Path -ceq $negative.Path) {
        throw "$Id promotion results must be three distinct files."
    }
    $managedBatch = $managed.Json | ConvertFrom-Json
    $selfhostBatch = $selfhost.Json | ConvertFrom-Json
    Assert-AuditPositiveBatch $Id 'managed positive batch' $managedBatch `
        $managed.Path ([string]$Family.evidence.managedCompilerSha256) $fixtureName
    Assert-AuditPositiveBatch $Id 'selfhost positive batch' $selfhostBatch `
        $selfhost.Path ([string]$Family.evidence.selfhostCompilerSha256) $fixtureName
    Assert-AuditPositiveReceipt $Id 'managed positive batch' $proof.managedPositiveBatch $managedBatch `
        $managed.Path ([string]$Family.evidence.managedCompilerSha256) $fixtureName
    Assert-AuditPositiveReceipt $Id 'selfhost positive batch' $proof.selfhostPositiveBatch $selfhostBatch `
        $selfhost.Path ([string]$Family.evidence.selfhostCompilerSha256) $fixtureName
    $negativeRecord = $negative.Json | ConvertFrom-Json
    $negativeSourcePath = Resolve-AuditPath ([string]$Family.negativeFixture.source)
    $negativeExpectedPath = Resolve-AuditPath ([string]$Family.negativeFixture.expected)
    $currentNegativeFingerprint = Get-AuditNegativeCurrentFingerprint $Id $negativeRecord `
        ([string]$Family.evidence.managedCompilerSha256) ([string]$Family.evidence.selfhostCompilerSha256) `
        $negativeSourcePath $negativeExpectedPath
    Assert-AuditNegativeResult $Id $negativeRecord $negative.Path `
        $negativeSourcePath $negativeExpectedPath `
        ([string]$Family.evidence.managedCompilerSha256) ([string]$Family.evidence.selfhostCompilerSha256) `
        $currentNegativeFingerprint
}

function Assert-AuditContract {
    param($Audit)
    $json = $Audit | ConvertTo-Json -Depth 30 -Compress
    if (-not (Test-Json -Json $json -SchemaFile $schemaPath)) {
        throw 'Compiler parity audit does not satisfy its schema.'
    }
    $actualIds = @($Audit.families | ForEach-Object { [string]$_.id })
    if (($actualIds -join "`n") -cne ($expectedIds -join "`n")) {
        throw 'Compiler parity audit family identities/order drifted from ai-slg-best-practices.json; a count alone is insufficient.'
    }
    for ($index = 0; $index -lt $Audit.families.Count; $index++) {
        $family = $Audit.families[$index]
        $authorityFamily = $authority.featureFamilies[$index]
        $id = [string]$family.id
        $expectedSubmatrix = if ($id -ceq 'expressions-operators') { 'scripts/contracts/expression-lowering-parity.json' } else { $null }
        if ([string]$family.submatrix -cne [string]$expectedSubmatrix) {
            throw "$id has a missing or misplaced expression submatrix link."
        }
        foreach ($ownerName in @('managedOwner', 'selfhostOwner')) {
            $owner = $family.$ownerName
            if ($owner.state -ceq 'confirmed') {
                if (-not $owner.path) { throw "$id $ownerName claims confirmation without an exact source owner." }
                $expectedPrefix = if ($ownerName -ceq 'managedOwner') { 'src/Sollang.Compiler/' } else { 'selfhost/' }
                if (-not ([string]$owner.path).StartsWith($expectedPrefix, [System.StringComparison]::Ordinal)) {
                    throw "$id $ownerName points to the wrong compiler tree."
                }
                [void](Resolve-AuditPath $owner.path)
            } elseif ($owner.path) {
                throw "$id $ownerName has a path but remains unverified; confirm or remove the owner claim."
            }
        }
        foreach ($fixtureName in @('positiveFixture', 'negativeFixture')) {
            $fixture = $family.$fixtureName
            if ($fixture.state -ceq 'unverified') {
                if ($fixture.source -or $fixture.expected) {
                    throw "$id $fixtureName is unverified but carries fixture paths."
                }
            } else {
                if (-not $fixture.source) { throw "$id $fixtureName has no exact fixture source." }
                [void](Resolve-AuditPath $fixture.source)
                Assert-AuditProbeExpectation $id $fixtureName $fixture.source $fixture.expected
                if ($fixtureName -ceq 'positiveFixture' -and $fixture.state -ceq 'candidate' -and
                    -not ([string]$fixture.source).StartsWith('scripts/probes/', [System.StringComparison]::Ordinal) -and
                    $fixture.source -cnotin @($authorityFamily.examples)) {
                    throw "$id positive candidate is not one of its authoritative examples."
                }
                if ($fixture.state -in @('pass', 'fail')) {
                    if (-not $fixture.expected) { throw "$id $fixtureName claims an outcome without an exact expectation." }
                    if ($fixtureName -ceq 'positiveFixture' -and
                        [string]$fixture.expected -cnotmatch '^(?:examples/regression/expected/.+|scripts/probes/(?:[A-Za-z0-9_-]+/)*[A-Za-z0-9_-]+)\.stdout\.txt$') {
                        throw "$id positiveFixture needs an exact stdout expectation."
                    }
                    if ($fixtureName -ceq 'negativeFixture' -and
                        [string]$fixture.expected -cnotmatch '^(?:examples/regression/(diagnostics|expected)/.+|scripts/probes/(?:[A-Za-z0-9_-]+/)*[A-Za-z0-9_-]+)\.(?:compiler\.)?stderr(?:\.contains)?\.txt$') {
                        throw "$id negativeFixture needs an exact stderr expectation."
                    }
                    [void](Resolve-AuditPath $fixture.expected)
                } elseif ($fixture.expected) {
                    [void](Resolve-AuditPath $fixture.expected)
                }
            }
        }
        $evidence = $family.evidence
        if ($evidence.level -ceq 'stage-fixed-point') {
            throw "$id stage-fixed-point needs a dedicated Stage2/Stage3 fixed-point result; Windows exact proof is insufficient."
        }
        $contextStates = @($family.contexts.entry, $family.contexts.ordinary, $family.contexts.nested)
        $targetStates = @($family.targets.windows, $family.targets.linux, $family.targets.browser)
        $isPromoted = $evidence.level -in @('differential-exact', 'native-exact', 'stage-fixed-point')
        if ($isPromoted -and -not $evidence.PSObject.Properties['promotionProof']) {
            throw "$id promoted evidence needs three SHA-pinned execution results."
        }
        if (-not $isPromoted -and $evidence.PSObject.Properties['promotionProof']) {
            throw "$id unpromoted evidence cannot carry a promotion proof."
        }
        if ($evidence.level -ceq 'none') {
            if ($evidence.PSObject.Properties['managedCompilerSha256'] -or
                $evidence.PSObject.Properties['selfhostCompilerSha256']) {
                throw "$id has compiler hashes without run-scoped evidence."
            }
            if ($evidence.runId -or $evidence.sourceFingerprint -or @($evidence.artifacts).Count -gt 0) {
                throw "$id has run evidence while its evidence level is none."
            }
            if (@($contextStates | Where-Object { $_ -cne 'unverified' }).Count -gt 0 -or
                @($targetStates | Where-Object { $_ -cne 'unassessed' }).Count -gt 0 -or
                $family.positiveFixture.state -in @('pass', 'fail') -or
                $family.negativeFixture.state -in @('pass', 'fail')) {
                throw "$id claims an assessed result without run-scoped evidence."
            }
        } else {
            if (-not $evidence.runId -or -not $evidence.sourceFingerprint -or @($evidence.artifacts).Count -eq 0) {
                throw "$id evidence needs a run ID, source fingerprint, and exact artifact paths."
            }
            if ($evidence.level -in @('managed-exact', 'differential-exact', 'native-exact', 'stage-fixed-point') -and
                (-not $evidence.PSObject.Properties['managedCompilerSha256'] -or
                [string]$evidence.managedCompilerSha256 -cnotmatch '^[a-fA-F0-9]{64}$')) {
                throw "$id managed execution proof requires managedCompilerSha256."
            }
            if ($evidence.level -in @('differential-exact', 'native-exact', 'stage-fixed-point') -and
                (-not $evidence.PSObject.Properties['selfhostCompilerSha256'] -or
                [string]$evidence.selfhostCompilerSha256 -cnotmatch '^[a-fA-F0-9]{64}$')) {
                throw "$id cross-compiler proof requires selfhostCompilerSha256."
            }
            if ($family.managedOwner.state -cne 'confirmed' -or $family.selfhostOwner.state -cne 'confirmed') {
                throw "$id evidence needs confirmed managed and self-host source owners."
            }
            $currentFingerprint = Get-AuditFingerprint $family
            if ($currentFingerprint -cne ([string]$evidence.sourceFingerprint).ToLowerInvariant()) {
                throw "$id evidence source fingerprint drifted; rerun this family."
            }
            $checks = @()
            foreach ($artifact in $evidence.artifacts) {
                $artifactPath = Resolve-AuditPath $artifact
                $record = Get-Content -LiteralPath $artifactPath -Raw | ConvertFrom-Json
                foreach ($field in @('familyId', 'runId', 'sourceFingerprint', 'evidenceLevel', 'result', 'checks')) {
                    if (-not $record.PSObject.Properties[$field]) {
                        throw "$id artifact lacks exact identity field $field`: $artifact"
                    }
                }
                if ($record.familyId -cne $id -or $record.runId -cne $evidence.runId -or
                    $record.sourceFingerprint -cne $evidence.sourceFingerprint -or
                    $record.evidenceLevel -cne $evidence.level -or $record.result -cnotin @('pass', 'fail')) {
                    throw "$id artifact identity/result does not match the audit row: $artifact"
                }
                foreach ($compilerName in @('managedCompilerSha256', 'selfhostCompilerSha256')) {
                    if ($evidence.PSObject.Properties[$compilerName] -and
                        (-not $record.PSObject.Properties[$compilerName] -or
                        [string]$record.$compilerName -cne [string]$evidence.$compilerName)) {
                        throw "$id artifact compiler identity does not match $compilerName`: $artifact"
                    }
                }
                if (@($record.checks).Count -eq 0) { throw "$id artifact has no dimension-level checks: $artifact" }
                foreach ($check in $record.checks) {
                    if (-not $check.PSObject.Properties['dimension'] -or -not $check.PSObject.Properties['result']) {
                        throw "$id artifact has a check without dimension and result: $artifact"
                    }
                    if ($check.dimension -cnotin @('positiveFixture', 'negativeFixture', 'entry', 'ordinary', 'nested', 'windows', 'linux', 'browser') -or
                        $check.result -cnotin @('pass', 'fail', 'applicable', 'not-applicable')) {
                        throw "$id artifact contains an unknown dimension/result: $artifact"
                    }
                    $checks += $check
                }
            }
            foreach ($fixtureName in @('positiveFixture', 'negativeFixture')) {
                if ($family.$fixtureName.state -in @('pass', 'fail') -and
                    @($checks | Where-Object { $_.dimension -ceq $fixtureName -and $_.result -ceq $family.$fixtureName.state }).Count -eq 0) {
                    throw "$id $fixtureName outcome lacks a matching exact check."
                }
            }
            foreach ($contextName in @('entry', 'ordinary', 'nested')) {
                $contextState = $family.contexts.$contextName
                if ($contextState -cne 'unverified' -and
                    @($checks | Where-Object { $_.dimension -ceq $contextName -and $_.result -ceq $contextState }).Count -eq 0) {
                    throw "$id $contextName outcome lacks a matching exact check."
                }
            }
            foreach ($targetName in @('windows', 'linux', 'browser')) {
                $targetState = $family.targets.$targetName
                if ($targetState -cne 'unassessed' -and
                    @($checks | Where-Object { $_.dimension -ceq $targetName -and $_.result -ceq $targetState }).Count -eq 0) {
                    throw "$id $targetName applicability lacks a matching exact check."
                }
            }
            if ($evidence.level -ceq 'static' -and
                ($family.positiveFixture.state -in @('pass', 'fail') -or $family.negativeFixture.state -in @('pass', 'fail'))) {
                throw "$id cannot claim fixture execution from static evidence."
            }
            if ($evidence.level -in @('static', 'managed-exact') -and
                @($contextStates | Where-Object { $_ -cne 'unverified' }).Count -gt 0) {
                throw "$id cannot claim a cross-compiler emission context from static or managed-only evidence."
            }
            if ($evidence.level -in @('differential-exact', 'native-exact', 'stage-fixed-point')) {
                if ($family.positiveFixture.state -cne 'pass' -or $family.negativeFixture.state -cne 'pass') {
                    throw "$id differential or higher evidence requires exact positive and negative fixture passes."
                }
                if (@($contextStates | Where-Object { $_ -ceq 'pass' }).Count -eq 0) {
                    throw "$id differential or higher evidence needs an exact passing emission context."
                }
                Assert-AuditPromotionProof $id $family
            }
        }
    }
}

$audit = Get-Content -LiteralPath $ContractPath -Raw | ConvertFrom-Json
Assert-AuditContract $audit

if ($SelfTest) {
    function Assert-ProofRejected {
        param([string]$Name, [string]$Reason, [scriptblock]$Check)
        try {
            & $Check
        } catch {
            if ($_.Exception.Message -notmatch $Reason) {
                throw "Compiler parity audit self-test $Name failed for the wrong reason: $($_.Exception.Message)"
            }
            Write-Host "[compiler parity audit self-test] rejected $Name"
            return
        }
        throw "Compiler parity audit self-test accepted invalid proof: $Name"
    }
    function Assert-Accepted {
        param([string]$Name, [scriptblock]$Change)
        $copy = ($audit | ConvertTo-Json -Depth 30 | ConvertFrom-Json)
        & $Change $copy
        Assert-AuditContract $copy
        Write-Host "[compiler parity audit self-test] accepted $Name"
    }
    function Assert-Rejected {
        param([string]$Name, [scriptblock]$Change)
        $copy = ($audit | ConvertTo-Json -Depth 30 | ConvertFrom-Json)
        & $Change $copy
        try {
            Assert-AuditContract $copy
        } catch {
            Write-Host "[compiler parity audit self-test] rejected $Name"
            return
        }
        throw "Compiler parity audit self-test accepted invalid case: $Name"
    }
    Assert-Rejected 'missing family' { param($copy) $copy.families = @($copy.families | Select-Object -Skip 1) }
    Assert-Rejected 'duplicate family identity' { param($copy) $copy.families[1].id = $copy.families[0].id }
    Assert-Rejected 'count-only replacement' { param($copy) $copy.families[1].id = 'fabricated-family' }
    Assert-Rejected 'misplaced submatrix' { param($copy) $copy.families[0].submatrix = $copy.expressionSubmatrix }
    Assert-Rejected 'false differential claim' { param($copy) $copy.families[0].evidence.level = 'differential-exact' }
    Assert-Rejected 'compiler hash without run' {
        param($copy)
        $copy.families[0].evidence | Add-Member -NotePropertyName managedCompilerSha256 -NotePropertyValue ('0' * 64)
    }
    Assert-Rejected 'owner without path' { param($copy) $copy.families[0].managedOwner.state = 'confirmed' }
    Assert-Rejected 'assessment without run' { param($copy) $copy.families[0].contexts.entry = 'pass' }
    Assert-Rejected 'stale candidate identity' { param($copy) $copy.families[0].positiveFixture.source = 'examples/regression/01-function-basic-hello.slg' }
    Assert-Accepted 'matching positive probe candidate' {
        param($copy)
        $copy.families[0].positiveFixture.source = 'scripts/probes/borrowed-return-scalars/projection-alias.slg'
        $copy.families[0].positiveFixture.expected = 'scripts/probes/borrowed-return-scalars/projection-alias.stdout.txt'
    }
    Assert-Accepted 'matching negative probe candidate' {
        param($copy)
        $copy.families[0].negativeFixture.state = 'candidate'
        $copy.families[0].negativeFixture.source = 'scripts/probes/zip-stored-writer/private-state.slg'
        $copy.families[0].negativeFixture.expected = 'scripts/probes/zip-stored-writer/private-state.stderr.contains.txt'
    }
    Assert-Rejected 'mismatched positive probe expectation' {
        param($copy)
        $copy.families[0].positiveFixture.source = 'scripts/probes/borrowed-return-scalars/projection-alias.slg'
        $copy.families[0].positiveFixture.expected = 'scripts/probes/zip-stored-writer/browser-focused.stdout.txt'
    }
    Assert-Rejected 'probe expectation with example source' {
        param($copy)
        $copy.families[0].positiveFixture.expected = 'scripts/probes/borrowed-return-scalars/projection-alias.stdout.txt'
    }
    Assert-Rejected 'mismatched negative probe expectation' {
        param($copy)
        $copy.families[0].negativeFixture.state = 'candidate'
        $copy.families[0].negativeFixture.source = 'scripts/probes/zip-stored-writer/private-state.slg'
        $copy.families[0].negativeFixture.expected = 'scripts/probes/zip-stored-writer/affine-finish-reuse.stderr.contains.txt'
    }
    Assert-Rejected 'probe traversal' {
        param($copy)
        $copy.families[0].positiveFixture.source = 'scripts/probes/../borrowed-return-scalars/projection-alias.slg'
    }
    Assert-ProofRejected 'promotion without pins' 'three SHA-pinned' {
        $copy = ($audit | ConvertTo-Json -Depth 30 | ConvertFrom-Json)
        $copy.families[0].evidence.level = 'differential-exact'
        Assert-AuditContract $copy
    }
    Assert-ProofRejected 'Windows proof claiming Stage fixed point' 'dedicated Stage2/Stage3' {
        $copy = ($audit | ConvertTo-Json -Depth 30 | ConvertFrom-Json)
        $copy.families[0].evidence.level = 'stage-fixed-point'
        Assert-AuditContract $copy
    }

    $managedSha = 'A' * 64
    $selfhostSha = 'B' * 64
    $batchPath = Join-Path $root 'artifacts/scratch/selftest/selftest-batch-results.json'
    $batch = [pscustomobject]@{
        schemaVersion = 1; label = 'selftest'; platform = 'windows'; state = 'passed'
        compilerSha256 = $managedSha; commonInputFingerprint = ('C' * 64)
        completed = 1; passed = 1; failed = 0; missing = 0; total = 1
        results = @([pscustomobject]@{ Fixture = '1768-count-nominal-receiver-precedence'; Success = $true; Error = '' })
    }
    Assert-AuditPositiveBatch 'selftest' 'managed positive batch' $batch $batchPath $managedSha '1768-count-nominal-receiver-precedence'
    Write-Host '[compiler parity audit self-test] accepted exact positive batch'
    Assert-ProofRejected 'missing positive fixture identity' 'does not include positive fixture' {
        Assert-AuditPositiveBatch 'selftest' 'managed positive batch' $batch $batchPath $managedSha 'different-fixture'
    }
    Assert-ProofRejected 'wrong positive compiler' 'pinned compiler' {
        Assert-AuditPositiveBatch 'selftest' 'managed positive batch' $batch $batchPath $selfhostSha '1768-count-nominal-receiver-precedence'
    }
    Assert-ProofRejected 'positive batch count inflation' 'batch counts' {
        $copy = ($batch | ConvertTo-Json -Depth 5 | ConvertFrom-Json)
        $copy.total = 2
        Assert-AuditPositiveBatch 'selftest' 'managed positive batch' $copy $batchPath $managedSha '1768-count-nominal-receiver-precedence'
    }
    Assert-ProofRejected 'duplicate positive fixture' 'duplicate, or failed' {
        $copy = ($batch | ConvertTo-Json -Depth 5 | ConvertFrom-Json)
        $copy.total = 2; $copy.completed = 2; $copy.passed = 2
        $copy.results = @($copy.results[0], $copy.results[0])
        Assert-AuditPositiveBatch 'selftest' 'managed positive batch' $copy $batchPath $managedSha '1768-count-nominal-receiver-precedence'
    }

    $testParent = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
    $testDirectory = [IO.Path]::GetFullPath((Join-Path $testParent ("sollang-parity-audit-selftest-" + [guid]::NewGuid().ToString('N'))))
    if (-not $testDirectory.StartsWith($testParent + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase) -or
        (Test-Path -LiteralPath $testDirectory)) {
        throw 'Compiler parity audit self-test temp directory is unsafe.'
    }
    try {
        [void][IO.Directory]::CreateDirectory($testDirectory)
        $sourcePath = Resolve-AuditPath 'scripts/probes/zip-stored-writer/private-state.slg'
        $expectedPath = Resolve-AuditPath 'scripts/probes/zip-stored-writer/private-state.stderr.contains.txt'
        $fragment = [IO.File]::ReadAllText($expectedPath).Trim()
        $logs = [ordered]@{}
        $checks = [ordered]@{}
        foreach ($compilerName in @('managed', 'selfhost')) {
            $stdoutPath = Join-Path $testDirectory "$compilerName.stdout.txt"
            $stderrPath = Join-Path $testDirectory "$compilerName.stderr.txt"
            $outputDirectory = Join-Path $testDirectory $compilerName
            [void][IO.Directory]::CreateDirectory($outputDirectory)
            [IO.File]::WriteAllText($stdoutPath, '')
            [IO.File]::WriteAllText($stderrPath, "error: $fragment")
            $logs["${compilerName}Stdout"] = $stdoutPath
            $logs["${compilerName}Stderr"] = $stderrPath
            $checks[$compilerName] = [ordered]@{
                exitCode = 1; nonzeroExit = $true; expectedInStderr = $true
                noEmittedProducts = $true; generatedProducts = @()
                outputDirectory = $outputDirectory; stdoutPath = $stdoutPath; stderrPath = $stderrPath
            }
        }
        $negative = [pscustomobject]@{
            schemaVersion = 1; gate = 'compiler-parity-negative-fixture'; state = 'passed'
            source = $sourcePath; expected = $expectedPath
            sourceSha256 = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
            expectedSha256 = (Get-FileHash -LiteralPath $expectedPath -Algorithm SHA256).Hash
            managedCompilerPath = (Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll')
            selfhostCompilerPath = (Join-Path $root 'artifacts/scratch/selftest/compiler.exe')
            llvmRoot = (Join-Path $root '.tools/llvm-22.1.8')
            stdlibRoot = (Join-Path $root 'stdlib')
            timeoutMilliseconds = 120000
            managedCompilerSha256 = $managedSha; selfhostCompilerSha256 = $selfhostSha
            inputFingerprintStart = ('C' * 64); inputFingerprintEnd = ('C' * 64)
            inputsStable = $true; logs = [pscustomobject]$logs
            managed = [pscustomobject]$checks.managed; selfhost = [pscustomobject]$checks.selfhost
            orphanProcessIds = @(); failureId = $null; failure = $null
        }
        $resultPath = Join-Path $testDirectory 'result.json'
        Assert-AuditNegativeResult 'selftest' $negative $resultPath $sourcePath $expectedPath $managedSha $selfhostSha ('C' * 64)
        Write-Host '[compiler parity audit self-test] accepted exact negative result'
        Assert-ProofRejected 'drifted negative inputs' 'result schema|stable passed run' {
            $copy = ($negative | ConvertTo-Json -Depth 12 | ConvertFrom-Json)
            $copy.inputFingerprintEnd = 'D' * 64
            Assert-AuditNegativeResult 'selftest' $copy $resultPath $sourcePath $expectedPath $managedSha $selfhostSha ('C' * 64)
        }
        Assert-ProofRejected 'negative current environment drift' 'stable passed run' {
            Assert-AuditNegativeResult 'selftest' $negative $resultPath $sourcePath $expectedPath $managedSha $selfhostSha ('D' * 64)
        }
        Assert-ProofRejected 'wrong negative compiler' 'stable passed run' {
            Assert-AuditNegativeResult 'selftest' $negative $resultPath $sourcePath $expectedPath $selfhostSha $selfhostSha ('C' * 64)
        }
        Assert-ProofRejected 'wrong negative source hash' 'source or expectation' {
            $copy = ($negative | ConvertTo-Json -Depth 12 | ConvertFrom-Json)
            $copy.sourceSha256 = 'D' * 64
            Assert-AuditNegativeResult 'selftest' $copy $resultPath $sourcePath $expectedPath $managedSha $selfhostSha ('C' * 64)
        }
        Assert-ProofRejected 'asserted diagnostic absent from stderr' 'exact diagnostic' {
            [IO.File]::WriteAllText($negative.managed.stderrPath, 'different diagnostic')
            try {
                Assert-AuditNegativeResult 'selftest' $negative $resultPath $sourcePath $expectedPath $managedSha $selfhostSha ('C' * 64)
            } finally {
                [IO.File]::WriteAllText($negative.managed.stderrPath, "error: $fragment")
            }
        }
        Assert-ProofRejected 'unreported generated product' 'empty products' {
            $product = Join-Path $negative.selfhost.outputDirectory 'unreported.ll'
            [IO.File]::WriteAllText($product, 'unexpected')
            try {
                Assert-AuditNegativeResult 'selftest' $negative $resultPath $sourcePath $expectedPath $managedSha $selfhostSha ('C' * 64)
            } finally {
                Remove-Item -LiteralPath $product -Force
            }
        }
        $fixtureCopy = Join-Path $testDirectory 'fixture.slg'
        $expectedCopy = Join-Path $testDirectory 'fixture.stdout.txt'
        $receiptCopy = Join-Path $testDirectory 'fixture.inputs.sha256'
        [IO.File]::WriteAllText($fixtureCopy, 'main { "before" -> println }')
        [IO.File]::WriteAllText($expectedCopy, "before`n")
        $fingerprintSettings = [ordered]@{ gate = 'audit-fixture-freshness-selftest' }
        $originalFingerprint = Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root `
            -Settings $fingerprintSettings -InputPath @($fixtureCopy, $expectedCopy)
        [IO.File]::WriteAllText($receiptCopy, $originalFingerprint)
        Assert-AuditExactInputReceipt 'selftest' 'positive' $originalFingerprint $receiptCopy
        Write-Host '[compiler parity audit self-test] accepted current fixture input receipt'
        Assert-ProofRejected 'edited fixture with old positive receipt' 'stale or invalid' {
            [IO.File]::WriteAllText($fixtureCopy, 'main { "after" -> println }')
            $current = Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root `
                -Settings $fingerprintSettings -InputPath @($fixtureCopy, $expectedCopy)
            Assert-AuditExactInputReceipt 'selftest' 'positive' $current $receiptCopy
        }
        Assert-ProofRejected 'edited expectation with old positive receipt' 'stale or invalid' {
            [IO.File]::WriteAllText($fixtureCopy, 'main { "before" -> println }')
            [IO.File]::WriteAllText($expectedCopy, "after`n")
            $current = Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root `
                -Settings $fingerprintSettings -InputPath @($fixtureCopy, $expectedCopy)
            Assert-AuditExactInputReceipt 'selftest' 'positive' $current $receiptCopy
        }
    } finally {
        if ($testDirectory.StartsWith($testParent + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase) -and
            (Test-Path -LiteralPath $testDirectory)) {
            Remove-Item -LiteralPath $testDirectory -Recurse -Force
        }
    }
    $scratchParent = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
    $pinFolderName = 'compiler-parity-audit-pin-selftest-' + [guid]::NewGuid().ToString('N')
    $pinDirectory = [IO.Path]::GetFullPath((Join-Path $scratchParent $pinFolderName))
    if (-not $pinDirectory.StartsWith($scratchParent + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $pinDirectory)) {
        throw 'Compiler parity audit self-test pin directory is unsafe.'
    }
    try {
        [void][IO.Directory]::CreateDirectory($pinDirectory)
        $pinFile = Join-Path $pinDirectory 'result.json'
        [IO.File]::WriteAllText($pinFile, '{}')
        $pin = [pscustomobject]@{
            path = "artifacts/scratch/$pinFolderName/result.json"
            sha256 = (Get-FileHash -LiteralPath $pinFile -Algorithm SHA256).Hash
        }
        [void](Read-AuditPinnedResult 'selftest' 'pinned result' $pin)
        Write-Host '[compiler parity audit self-test] accepted exact result SHA pin'
        Assert-ProofRejected 'tampered result SHA pin' 'SHA-256 pin differs' {
            $wrong = [pscustomobject]@{ path = $pin.path; sha256 = ('D' * 64) }
            [void](Read-AuditPinnedResult 'selftest' 'pinned result' $wrong)
        }
        Assert-ProofRejected 'pinned result traversal' 'traversal' {
            $wrong = [pscustomobject]@{
                path = "artifacts/scratch/$pinFolderName/../result.json"
                sha256 = $pin.sha256
            }
            [void](Read-AuditPinnedResult 'selftest' 'pinned result' $wrong)
        }
    } finally {
        if ($pinDirectory.StartsWith($scratchParent + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $pinDirectory)) {
            Remove-Item -LiteralPath $pinDirectory -Recurse -Force
        }
    }
}

$claimed = @($audit.families | Where-Object { $_.evidence.level -cne 'none' }).Count
$proved = @($audit.families | Where-Object { $_.evidence.level -in @('differential-exact', 'native-exact', 'stage-fixed-point') }).Count
Write-Host "[compiler parity audit] PASS structural coverage $($audit.families.Count)/30; behavioral proof $proved/30; run-evidence claims $claimed/30; linked expression identities 42/42."
