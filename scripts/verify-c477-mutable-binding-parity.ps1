[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$ManagedCompiler,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$ManagedCompilerSha256,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$SelfhostCompiler,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$SelfhostCompilerSha256,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$OutputDirectory,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$LlvmRoot = '.tools/llvm-22.1.8',
    [string]$StdlibRoot = 'stdlib',
    [ValidateRange(1000, 3600000)][int]$TimeoutMilliseconds = 180000,
    [switch]$ValidateInputsOnly,
    [Parameter(Mandatory, ParameterSetName = 'SelfTest')][switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$manifestPath = Join-Path $PSScriptRoot 'contracts/c477-mutable-binding-parity.json'
$manifestSchemaPath = Join-Path $PSScriptRoot 'contracts/c477-mutable-binding-parity.schema.json'
$resultSchemaPath = Join-Path $PSScriptRoot 'contracts/c477-mutable-binding-parity-result.schema.json'
$negativeRunnerPath = Join-Path $PSScriptRoot 'verify-compiler-parity-negative-fixture.ps1'
$negativeResultSchemaPath = Join-Path $PSScriptRoot 'contracts/compiler-parity-negative-fixture-result.schema.json'
$closurePath = Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1'
$stepNames = @('negativePair', 'managedLocal', 'selfhostLocal', 'managedParameter', 'selfhostParameter')
$pinnedManifestSha256 = 'DE1CEB2B8297AD02FD92D7C8B1D12DE9DB19BA3B8DB5C5A12B5DD2D56FEF29F4'
$pinnedFixtures = @(
    @('mutable-local-missing-bang', 'scripts/probes/typed/c476-mutable-read-missing-bang.slg', '7DF54907E9FDB98292A7659BA8FE5FAE5D65F63B221A8586F229D5FBF6943351', 'scripts/probes/typed/c476-mutable-read-missing-bang.stderr.contains.txt', '5CCECD405C6D137A3E4AE86822FF8C28EEB038061385EE45E1BF34E16C8C0C0E'),
    @('mutable-local-compound-condition', 'scripts/probes/typed/c477-mutable-local-compound-condition.slg', '6AD68CB39AAB4B17E637B60008E086B877DF3CE0664408D62DD23F5A09D57271', 'scripts/probes/typed/c477-mutable-local-compound-condition.stdout.txt', '18D4F5D7612E48A8CC43889E5FF97C6335CDF727422C721E2A66CE1F10DAE559'),
    @('bare-mutable-parameter', 'scripts/probes/typed/c477-bare-mutable-parameter.slg', 'DDCBF2AF361E3F79DF14198BDB268A3F4A6C961C6BD8433162C53C54522E52E0', 'scripts/probes/typed/c477-bare-mutable-parameter.stdout.txt', '1E5040B4DB14CA674E235DE801FD4C74B1F0448E6EB1F838D1E9D4E443D99074')
)

function Resolve-Input([string]$Path) {
    $full = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $root $Path)) }
    return (Resolve-Path -LiteralPath $full -ErrorAction Stop).ProviderPath
}
function Get-Sha([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Test-BuildWarningOrNote([string]$Text) {
    return $Text -match '(?im)^\s*(?:warning(?:\s|:)|note(?:\s|:)|sollang:\s*(?:warning|note)(?:\s|:))'
}
function Assert-NoReparse([string]$Path) {
    $cursor = [IO.Path]::GetPathRoot($Path)
    foreach ($segment in ($Path.Substring($cursor.Length) -split '[\\/]')) {
        if (-not $segment) { continue }
        $cursor = Join-Path $cursor $segment
        if (-not (Test-Path -LiteralPath $cursor)) { break }
        if (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "C477_REPARSE_PATH: $cursor" }
    }
}
function New-ExclusiveDirectory([string]$Path) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw "C477_PARENT_MISSING: $parent" }
    Assert-NoReparse $parent
    if (-not ('C477OutputDirectoryNative' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class C477OutputDirectoryNative {
    [DllImport("kernel32.dll", EntryPoint = "CreateDirectoryW", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CreateDirectory(string path, IntPtr securityAttributes);
}
'@
    }
    if (-not [C477OutputDirectoryNative]::CreateDirectory($Path, [IntPtr]::Zero)) {
        $code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "C477_OUTPUT_EXISTS_OR_CREATE_FAILED: exclusive directory creation failed ($code): $Path"
    }
    Assert-NoReparse $Path
}
function Assert-FixturePin([object]$Fixture, [int]$Index) {
    $pin = $pinnedFixtures[$Index]
    if ($Fixture.id -cne $pin[0] -or $Fixture.source -cne $pin[1] -or $Fixture.sourceSha256 -cne $pin[2] -or $Fixture.expected -cne $pin[3] -or $Fixture.expectedSha256 -cne $pin[4]) {
        throw "C477_FIXTURE_PIN: fixture $Index differs from independent identity"
    }
}
function Assert-Manifest([string]$CandidatePath = $manifestPath) {
    if ((Get-Sha $CandidatePath) -cne $pinnedManifestSha256) { throw 'C477_MANIFEST_PIN: manifest bytes changed' }
    $json = [IO.File]::ReadAllText($CandidatePath)
    if (-not (Test-Json -Json $json -SchemaFile $manifestSchemaPath)) { throw 'C477_MANIFEST_INVALID: schema rejected' }
    $value = $json | ConvertFrom-Json
    $fixtures = @($value.negative) + @($value.positives)
    for ($i = 0; $i -lt 3; $i++) {
        $fixture = $fixtures[$i]
        Assert-FixturePin $fixture $i
        $source = Resolve-Input $fixture.source
        $expected = Resolve-Input $fixture.expected
        foreach ($path in @($source, $expected)) { Assert-NoReparse $path }
        if ((Get-Sha $source) -cne $fixture.sourceSha256 -or (Get-Sha $expected) -cne $fixture.expectedSha256) { throw "C477_MANIFEST_SHA: fixture $($fixture.id) changed" }
        if ((Get-Item -LiteralPath $expected).Length -eq 0) { throw "C477_EXPECTATION_EMPTY: $expected" }
    }
    return $value
}
function New-Step([string]$FixtureId, [string]$CompilerKind) {
    return [ordered]@{
        state = 'not-run'; fixtureId = $FixtureId; compiler = $CompilerKind; resultPath = $null
        buildExitCode = $null; runExitCode = $null; buildStdoutPath = $null; buildStderrPath = $null
        assemblyStdoutPath = $null; assemblyStderrPath = $null
        runStdoutPath = $null; runStderrPath = $null; llvmPath = $null; bitcodePath = $null
        executablePath = $null; validationExitCode = $null; validationStdoutPath = $null
        validationStderrPath = $null; diagnosticCountsExitCode = $null
        diagnosticCountsStdoutPath = $null; diagnosticCountsStderrPath = $null
        semanticDiagnosticCount = $null; irDiagnosticCount = $null; failure = $null
    }
}
function Write-AtomicResult([string]$Path, [string]$Json) {
    $temp = "$Path.tmp-$PID-$([guid]::NewGuid().ToString('N'))"
    $backup = "$Path.backup-$PID-$([guid]::NewGuid().ToString('N'))"
    $replaced = $false
    try {
        [IO.File]::WriteAllText($temp, $Json, [Text.UTF8Encoding]::new($false))
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            [IO.File]::Replace($temp, $Path, $backup)
            $replaced = $true
        } else { [IO.File]::Move($temp, $Path) }
    } finally {
        if (Test-Path -LiteralPath $temp -PathType Leaf) { Remove-Item -LiteralPath $temp -Force }
        if ($replaced -and (Test-Path -LiteralPath $backup -PathType Leaf)) { Remove-Item -LiteralPath $backup -Force }
    }
}
function Assert-ExactNames([string]$Directory, [string[]]$Expected) {
    $entries = @(Get-ChildItem -LiteralPath $Directory -Force)
    $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($entry in $entries) {
        if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "C477_ARTIFACT_REPARSE: $($entry.FullName)" }
        if (-not $names.Add($entry.Name)) { throw "C477_ARTIFACT_DUPLICATE: $($entry.FullName)" }
    }
    if ($names.Count -ne $Expected.Count) { throw "C477_ARTIFACT_SET: $Directory contains $($names.Count) entries, expected $($Expected.Count): $($entries.Name -join ',')" }
    foreach ($name in $Expected) {
        if (-not $names.Contains($name)) { throw "C477_ARTIFACT_SET: $Directory missing $name; found $($entries.Name -join ',')" }
    }
}
function Assert-PositiveCaseTree([string]$CaseDirectory, [bool]$Managed) {
    $files = @('probe.exe', 'probe.bc', 'build.stdout.txt', 'build.stderr.txt', 'llvm-as.stdout.txt', 'llvm-as.stderr.txt', 'run.stdout.txt', 'run.stderr.txt')
    $files += 'probe.exe.ll'
    if ($Managed) { $files += '.sollang-cache' }
    Assert-ExactNames $CaseDirectory $files
    foreach ($name in $files) {
        $path = Join-Path $CaseDirectory $name
        if ($name -eq '.sollang-cache') {
            if (-not (Test-Path -LiteralPath $path -PathType Container)) { throw "C477_ARTIFACT_TYPE: $path must be a directory" }
        } elseif (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C477_ARTIFACT_TYPE: $path must be a file" }
    }
    if (-not $Managed) { return }
    $cache = Join-Path $CaseDirectory '.sollang-cache'
    $cacheEntries = @(Get-ChildItem -LiteralPath $cache -Force)
    if ($cacheEntries.Count -ne 4) { throw "C477_CACHE_SET: expected four cache files; found $($cacheEntries.Count)" }
    $stem = $null
    $suffixes = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($entry in $cacheEntries) {
        if ($entry.PSIsContainer -or ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $entry.Name -cnotmatch '^(probe\.windows-x64\..+\.o1-executable)\.(cgu|product|semantic|sources)$') { throw "C477_CACHE_SET: unexpected cache entry $($entry.FullName)" }
        if ($null -eq $stem) { $stem = $Matches[1] }
        elseif ($stem -cne $Matches[1]) { throw 'C477_CACHE_SET: cache stems differ' }
        if (-not $suffixes.Add($Matches[2])) { throw "C477_CACHE_SET: duplicate cache suffix $($Matches[2])" }
    }
}
function Get-LiveDescendantIds([int]$RootId, [datetime]$RootStartUtc, [object[]]$Records) {
    $seen = [Collections.Generic.HashSet[int]]::new()
    $frontier = @($RootId)
    while ($frontier.Count -gt 0) {
        $next = @()
        foreach ($record in $Records) {
            $id = [int]$record.ProcessId
            if ([datetime]$record.CreationDate -lt $RootStartUtc.ToLocalTime()) { continue }
            if ($frontier -contains [int]$record.ParentProcessId -and $id -ne $RootId -and $seen.Add($id)) { $next += $id }
        }
        $frontier = $next
    }
    return @($seen | Sort-Object)
}
function Invoke-Logged([string]$File, [string[]]$Arguments, [string]$WorkingDirectory, [string]$Description, [string]$StdoutPath, [string]$StderrPath) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $File; $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false; $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new(); $process.StartInfo = $start
    $stdout = [IO.File]::Create($StdoutPath); $stderr = [IO.File]::Create($StderrPath)
    $started = $false
    $rootStartUtc = [datetime]::MinValue
    try {
        if (-not $process.Start()) { throw "C477_SPAWN_FAILED: $Description" }
        $started = $true
        $rootStartUtc = $process.StartTime.ToUniversalTime()
        $outCopy = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
        $errCopy = $process.StandardError.BaseStream.CopyToAsync($stderr)
        $waitFailure = $null
        try { Wait-VerificationProcess -Process $process -Description $Description -TimeoutMilliseconds $TimeoutMilliseconds }
        catch { $waitFailure = $_ }
        if (-not $process.WaitForExit(0)) {
            try { $process.Kill($true) } catch { try { $process.Kill() } catch { } }
            if (-not $process.WaitForExit(5000)) { $script:orphanIds.Add($process.Id); throw "C477_PROCESS_ORPHANED: root $($process.Id)" }
        }
        try { $descendants = @(Get-LiveDescendantIds $process.Id $rootStartUtc @(Get-CimInstance Win32_Process)) }
        catch { throw "C477_PROCESS_INSPECTION_FAILED: $($_.Exception.Message)" }
        if ($descendants.Count -gt 0) {
            foreach ($id in $descendants) { if (-not $script:orphanIds.Contains($id)) { $script:orphanIds.Add($id) } }
            throw "C477_PROCESS_ORPHANED: observed descendants $($descendants -join ',')"
        }
        $copies = [Threading.Tasks.Task]::WhenAll([Threading.Tasks.Task[]]@($outCopy, $errCopy))
        if (-not $copies.Wait(5000)) { throw "C477_LOG_DRAIN_TIMEOUT: $Description" }
        $copies.GetAwaiter().GetResult(); $stdout.Flush(); $stderr.Flush()
        if ($null -ne $waitFailure) { throw $waitFailure }
        return $process.ExitCode
    } catch {
        $original = $_
        if ($started) {
            if (-not $process.WaitForExit(0)) {
                try { $process.Kill($true) } catch { try { $process.Kill() } catch { } }
                if (-not $process.WaitForExit(5000) -and -not $script:orphanIds.Contains($process.Id)) { $script:orphanIds.Add($process.Id) }
            }
            try {
                foreach ($id in @(Get-LiveDescendantIds $process.Id $rootStartUtc @(Get-CimInstance Win32_Process))) {
                    if (-not $script:orphanIds.Contains($id)) { $script:orphanIds.Add($id) }
                }
            } catch { throw "C477_PROCESS_INSPECTION_FAILED: cleanup inspection failed: $($_.Exception.Message); original: $($original.Exception.Message)" }
        }
        if ($script:orphanIds.Count -gt 0) { throw "C477_PROCESS_ORPHANED: observed IDs $($script:orphanIds -join ','); original: $($original.Exception.Message)" }
        throw $original
    } finally {
        $process.Dispose(); $stdout.Dispose(); $stderr.Dispose()
    }
}

$manifest = Assert-Manifest
if ($SelfTest) {
    $rootStart = [datetime]::UtcNow
    $recycledParent = @(
        [pscustomobject]@{ ProcessId = 101; ParentProcessId = 100; CreationDate = $rootStart.AddMinutes(-5).ToLocalTime() },
        [pscustomobject]@{ ProcessId = 102; ParentProcessId = 101; CreationDate = $rootStart.AddMinutes(-5).ToLocalTime() }
    )
    if (@(Get-LiveDescendantIds 100 $rootStart $recycledParent).Count -ne 0) {
        throw 'C477_SELFTEST: process predating recycled root PID was reported as a child'
    }
    $liveChild = [pscustomobject]@{ ProcessId = 103; ParentProcessId = 100; CreationDate = $rootStart.AddSeconds(1).ToLocalTime() }
    if (@(Get-LiveDescendantIds 100 $rootStart @($liveChild)).Count -ne 1) {
        throw 'C477_SELFTEST: live child was missed'
    }
    foreach ($diagnostic in @("warning: issue`n", "note: issue`n", "sollang: warning: issue`n", "sollang: note: issue`n")) {
        if (-not (Test-BuildWarningOrNote $diagnostic)) { throw "C477_SELFTEST: build diagnostic escaped warning gate: $diagnostic" }
    }
    if (Test-BuildWarningOrNote "build complete`n") { throw 'C477_SELFTEST: ordinary build output rejected' }
    for ($i = 0; $i -lt 3; $i++) {
        foreach ($field in @('sourceSha256', 'expectedSha256')) {
            $changedManifest = ($manifest | ConvertTo-Json -Depth 8) | ConvertFrom-Json
            $changedFixture = (@($changedManifest.negative) + @($changedManifest.positives))[$i]
            $changedFixture.PSObject.Properties[$field].Value = ('0' * 64)
            $rejected = $false
            try { Assert-FixturePin $changedFixture $i } catch { $rejected = $_.Exception.Message.StartsWith('C477_FIXTURE_PIN:') }
            if (-not $rejected) { throw "C477_SELFTEST: mutated $field fixture $i accepted" }
        }
    }
    $sampleSteps = [ordered]@{
        negativePair = New-Step $manifest.negative.id 'pair'
        managedLocal = New-Step $manifest.positives[0].id 'managed'
        selfhostLocal = New-Step $manifest.positives[0].id 'selfhost'
        managedParameter = New-Step $manifest.positives[1].id 'managed'
        selfhostParameter = New-Step $manifest.positives[1].id 'selfhost'
    }
    $sample = [ordered]@{
        schemaVersion = 1; gate = 'c477-mutable-binding-parity'; state = 'running'
        manifestPath = 'manifest'; manifestSha256 = ('A' * 64)
        managedCompilerPath = 'managed'; managedCompilerSha256 = ('B' * 64)
        selfhostCompilerPath = 'selfhost'; selfhostCompilerSha256 = ('C' * 64)
        inputFingerprintStart = ('D' * 64); inputFingerprintEnd = $null; inputsStable = $false
        negativeProofScope = 'pre-llvm-semantic-count-positive-and-strict-cli-nonzero-diagnostic-substring'
        negativeArtifactAuditScope = 'validation-directory-exact-and-strict-nested-compiler-output-only;negative-pair-root-and-cwd-stage-not-audited'
        positiveArtifactAuditScope = 'exact-case-tree-including-managed-cache-and-keep-temps'
        processObservationScope = 'single-post-exit-CIM-parent-chain-snapshot;exited-intermediate-descendants-not-proven'
        completed = 0; passed = 0; steps = $sampleSteps; orphanProcessIds = @(); failureId = $null; failure = $null
    }
    if (-not (Test-Json -Json ($sample | ConvertTo-Json -Depth 12) -SchemaFile $resultSchemaPath)) { throw 'C477_SELFTEST: running result schema rejected' }
    $failedSample = ($sample | ConvertTo-Json -Depth 12) | ConvertFrom-Json
    $sample.state = 'passed'; $sample.completed = 5; $sample.passed = 5; $sample.inputsStable = $true; $sample.inputFingerprintEnd = ('D' * 64)
    if (Test-Json -Json ($sample | ConvertTo-Json -Depth 12) -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) { throw 'C477_SELFTEST: result schema accepted unfinished pass' }
    foreach ($name in $stepNames) {
        $sample.steps[$name].state = 'passed'
        if ($name -ceq 'negativePair') {
            $sample.steps[$name].resultPath = 'negative-result'
            $sample.steps[$name].validationExitCode = 0; $sample.steps[$name].diagnosticCountsExitCode = 0
            $sample.steps[$name].validationStdoutPath = 'validate-stdout'; $sample.steps[$name].validationStderrPath = 'validate-stderr'
            $sample.steps[$name].diagnosticCountsStdoutPath = 'counts-stdout'; $sample.steps[$name].diagnosticCountsStderrPath = 'counts-stderr'
            $sample.steps[$name].semanticDiagnosticCount = 1; $sample.steps[$name].irDiagnosticCount = 0
        }
        else {
            $sample.steps[$name].buildExitCode = 0; $sample.steps[$name].runExitCode = 0
            $sample.steps[$name].llvmPath = 'llvm'; $sample.steps[$name].bitcodePath = 'bitcode'
            $sample.steps[$name].executablePath = 'exe'
        }
    }
    if (-not (Test-Json -Json ($sample | ConvertTo-Json -Depth 12) -SchemaFile $resultSchemaPath)) { throw 'C477_SELFTEST: complete pass rejected' }
    $sample.orphanProcessIds = @(1234)
    if (Test-Json -Json ($sample | ConvertTo-Json -Depth 12) -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) { throw 'C477_SELFTEST: orphaned pass accepted' }
    $script:selfTestDirectory = Join-Path ([IO.Path]::GetTempPath()) ("c477-selftest-$PID-$([guid]::NewGuid().ToString('N'))")
    [IO.Directory]::CreateDirectory($script:selfTestDirectory) | Out-Null
    try {
        $changedManifestPath = Join-Path $script:selfTestDirectory 'changed-manifest.json'
        [IO.File]::WriteAllText($changedManifestPath, ([IO.File]::ReadAllText($manifestPath) + [Environment]::NewLine))
        $rejected = $false
        try { Assert-Manifest $changedManifestPath | Out-Null } catch { $rejected = $_.Exception.Message.StartsWith('C477_MANIFEST_PIN:') }
        if (-not $rejected) { throw 'C477_SELFTEST: changed manifest bytes accepted' }
        Remove-Item -LiteralPath $changedManifestPath
        [IO.File]::WriteAllText((Join-Path $script:selfTestDirectory 'probe.exe'), '')
        Assert-ExactNames $script:selfTestDirectory @('probe.exe')
        [IO.File]::WriteAllText((Join-Path $script:selfTestDirectory 'probe.stage'), '')
        $rejected = $false
        try { Assert-ExactNames $script:selfTestDirectory @('probe.exe') } catch { $rejected = $_.Exception.Message.StartsWith('C477_ARTIFACT_SET:') }
        if (-not $rejected) { throw 'C477_SELFTEST: unexpected stage accepted' }
        Remove-Item -LiteralPath (Join-Path $script:selfTestDirectory 'probe.stage')
        foreach ($name in @('probe.bc', 'probe.exe.ll', 'build.stdout.txt', 'build.stderr.txt', 'llvm-as.stdout.txt', 'llvm-as.stderr.txt', 'run.stdout.txt', 'run.stderr.txt')) {
            [IO.File]::WriteAllText((Join-Path $script:selfTestDirectory $name), 'x')
        }
        $cache = [IO.Directory]::CreateDirectory((Join-Path $script:selfTestDirectory '.sollang-cache')).FullName
        foreach ($suffix in @('cgu', 'product', 'semantic', 'sources')) {
            [IO.File]::WriteAllText((Join-Path $cache "probe.windows-x64.cpu1-d-r1-a3fe-f0.o1-executable.$suffix"), 'x')
        }
        Assert-PositiveCaseTree $script:selfTestDirectory $true
        [IO.File]::WriteAllText((Join-Path $script:selfTestDirectory '.l0.ll'), 'x')
        $rejected = $false
        try { Assert-PositiveCaseTree $script:selfTestDirectory $true } catch { $rejected = $_.Exception.Message.StartsWith('C477_ARTIFACT_SET:') }
        if (-not $rejected) { throw 'C477_SELFTEST: retained stage accepted' }
        $nestedPath = Join-Path $script:selfTestDirectory 'nested-failed.json'
        [IO.File]::WriteAllText($nestedPath, '{"state":"failed","failureId":"NEGATIVE_CHECK_FAILED","orphanProcessIds":[]}')
        $selfTestResultPath = Join-Path $script:selfTestDirectory 'failed-result.json'
        Write-AtomicResult $selfTestResultPath ($failedSample | ConvertTo-Json -Depth 12)
        $nested = [IO.File]::ReadAllText($nestedPath) | ConvertFrom-Json
        if ($nested.state -cne 'failed') { throw 'C477_SELFTEST: nested failure fixture invalid' }
        $failedSample.steps.negativePair.resultPath = $nestedPath
        $failedSample.steps.negativePair.state = 'failed'
        $failedSample.steps.negativePair.failure = 'C477_NEGATIVE_FAILED: nested result failed'
        $failedSample.completed = 1
        $failedSample.inputFingerprintEnd = $failedSample.inputFingerprintStart
        $failedSample.inputsStable = $true
        $failedSample.failureId = 'C477_NEGATIVE_FAILED'
        $failedSample.failure = $failedSample.steps.negativePair.failure
        $failedSample.state = 'failed'
        $failedJson = $failedSample | ConvertTo-Json -Depth 12
        if (-not (Test-Json -Json $failedJson -SchemaFile $resultSchemaPath)) { throw 'C477_SELFTEST: failed result schema rejected' }
        Write-AtomicResult $selfTestResultPath $failedJson
        $persisted = [IO.File]::ReadAllText($selfTestResultPath) | ConvertFrom-Json
        if ($persisted.state -cne 'failed' -or $persisted.steps.negativePair.state -cne 'failed' -or $persisted.failureId -cne 'C477_NEGATIVE_FAILED' -or $persisted.completed -ne 1 -or $persisted.passed -ne 0) { throw 'C477_SELFTEST: nested failure left stale running result' }
        if (-not (Test-Json -Json ([IO.File]::ReadAllText($selfTestResultPath)) -SchemaFile $resultSchemaPath)) { throw 'C477_SELFTEST: persisted failed result schema rejected' }
        if (@(Get-ChildItem -LiteralPath $script:selfTestDirectory -File -Force | Where-Object { $_.Name -like 'failed-result.json.*' }).Count -ne 0) { throw 'C477_SELFTEST: atomic write left temporary files' }
    } finally { Remove-Item -LiteralPath $script:selfTestDirectory -Recurse -Force }
    Write-Host '[c477 mutable binding] self-test passed; no compiler launched'
    return
}

if (-not $IsWindows) { throw 'C477_PLATFORM_UNSUPPORTED: windows-x64 only' }
$managedPath = Resolve-Input $ManagedCompiler
$selfhostPath = Resolve-Input $SelfhostCompiler
$llvmPath = Resolve-Input $LlvmRoot
$stdlibPath = Resolve-Input $StdlibRoot
$dotnetPath = (Get-Command dotnet -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
$llvmAsPath = Join-Path $llvmPath 'bin/llvm-as.exe'
foreach ($path in @($managedPath, $selfhostPath, $llvmPath, $stdlibPath, $dotnetPath, $llvmAsPath, $negativeRunnerPath, $negativeResultSchemaPath, $closurePath)) { Assert-NoReparse $path }
if (-not (Test-Path -LiteralPath $llvmAsPath -PathType Leaf)) { throw "C477_TOOL_MISSING: $llvmAsPath" }
if ($ManagedCompilerSha256 -cnotmatch '^[0-9a-fA-F]{64}$' -or (Get-Sha $managedPath) -cne $ManagedCompilerSha256.ToUpperInvariant()) { throw 'C477_MANAGED_SHA: compiler identity differs' }
if ($SelfhostCompilerSha256 -cnotmatch '^[0-9a-fA-F]{64}$' -or (Get-Sha $selfhostPath) -cne $SelfhostCompilerSha256.ToUpperInvariant()) { throw 'C477_SELFHOST_SHA: compiler identity differs' }

function Get-InputFingerprint {
    $managedCommon = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root -CompilerPath $managedPath -StdlibRoot $stdlibPath -LlvmRoot $llvmPath
    $selfhostCommon = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root -CompilerPath $selfhostPath -StdlibRoot $stdlibPath -LlvmRoot $llvmPath
    $settings = [ordered]@{ gate = 'c477-mutable-binding-parity-v1'; managedCommon = $managedCommon; selfhostCommon = $selfhostCommon; timeoutMilliseconds = [string]$TimeoutMilliseconds }
    $files = @($PSCommandPath, $manifestPath, $manifestSchemaPath, $resultSchemaPath, $negativeRunnerPath, $negativeResultSchemaPath, $closurePath, $dotnetPath)
    foreach ($fixture in @($manifest.negative) + @($manifest.positives)) { $files += @((Resolve-Input $fixture.source), (Resolve-Input $fixture.expected)) }
    return Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root -Settings $settings -InputPath $files
}
$outputPath = if ([IO.Path]::IsPathRooted($OutputDirectory)) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory)) }
$scratch = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
if (-not $outputPath.StartsWith($scratch + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "C477_OUTPUT_SCOPE: output must be below $scratch" }
Assert-NoReparse $outputPath
if (Test-Path -LiteralPath $outputPath) { throw "C477_OUTPUT_EXISTS: $outputPath" }
$fingerprintStart = Get-InputFingerprint
$negativeOutput = Join-Path $outputPath 'negativePair'
$negativePreflightText = & $negativeRunnerPath -ManagedCompiler $managedPath -SelfhostCompiler $selfhostPath -ManagedCompilerSha256 $ManagedCompilerSha256 -SelfhostCompilerSha256 $SelfhostCompilerSha256 -Source (Resolve-Input $manifest.negative.source) -Expected (Resolve-Input $manifest.negative.expected) -OutputDirectory $negativeOutput -RepositoryRoot $root -LlvmRoot $llvmPath -StdlibRoot $stdlibPath -TimeoutMilliseconds $TimeoutMilliseconds -ValidateInputsOnly
$negativePreflight = $negativePreflightText | ConvertFrom-Json
if ($negativePreflight.status -cne 'preflight-passed') { throw 'C477_NEGATIVE_PREFLIGHT: negative runner did not validate fixed inputs' }
if ((Get-InputFingerprint) -cne $fingerprintStart) { throw 'C477_INPUT_DRIFT: input changed during preflight' }
if ($ValidateInputsOnly) {
    [pscustomobject]@{ status = 'preflight-passed'; managedCompilerSha256 = Get-Sha $managedPath; selfhostCompilerSha256 = Get-Sha $selfhostPath; manifestSha256 = Get-Sha $manifestPath; inputFingerprint = $fingerprintStart } | ConvertTo-Json -Compress
    return
}

New-ExclusiveDirectory $outputPath
$script:orphanIds = [Collections.Generic.List[int]]::new()
$steps = [ordered]@{
    negativePair = New-Step $manifest.negative.id 'pair'
    managedLocal = New-Step $manifest.positives[0].id 'managed'
    selfhostLocal = New-Step $manifest.positives[0].id 'selfhost'
    managedParameter = New-Step $manifest.positives[1].id 'managed'
    selfhostParameter = New-Step $manifest.positives[1].id 'selfhost'
}
$record = [ordered]@{
    schemaVersion = 1; gate = 'c477-mutable-binding-parity'; state = 'running'
    manifestPath = $manifestPath; manifestSha256 = Get-Sha $manifestPath
    managedCompilerPath = $managedPath; managedCompilerSha256 = Get-Sha $managedPath
    selfhostCompilerPath = $selfhostPath; selfhostCompilerSha256 = Get-Sha $selfhostPath
    inputFingerprintStart = $fingerprintStart; inputFingerprintEnd = $null; inputsStable = $false
    negativeProofScope = 'pre-llvm-semantic-count-positive-and-strict-cli-nonzero-diagnostic-substring'
    negativeArtifactAuditScope = 'validation-directory-exact-and-strict-nested-compiler-output-only;negative-pair-root-and-cwd-stage-not-audited'
    positiveArtifactAuditScope = 'exact-case-tree-including-managed-cache-and-keep-temps'
    processObservationScope = 'single-post-exit-CIM-parent-chain-snapshot;exited-intermediate-descendants-not-proven'
    completed = 0; passed = 0; steps = $steps; orphanProcessIds = @(); failureId = $null; failure = $null
}
$resultPath = Join-Path $outputPath 'result.json'
function Write-Result {
    $json = $record | ConvertTo-Json -Depth 12
    if (-not (Test-Json -Json $json -SchemaFile $resultSchemaPath)) { throw 'C477_RESULT_SCHEMA: result rejected' }
    Write-AtomicResult $resultPath $json
}
Write-Result

$active = $null
$activeCounted = $false
try {
    foreach ($name in $stepNames) {
        if ((Get-InputFingerprint) -cne $fingerprintStart) { throw 'C477_INPUT_DRIFT: input changed before step' }
        $step = $record.steps[$name]
        $caseDir = Join-Path $outputPath $name
        if ($name -cne 'negativePair') { New-ExclusiveDirectory $caseDir }
        $active = $name; $activeCounted = $false
        if ($name -ceq 'negativePair') {
            $validationDir = Join-Path $outputPath 'negativeValidation'
            New-ExclusiveDirectory $validationDir
            $step.validationStdoutPath = Join-Path $validationDir 'validate.stdout.txt'
            $step.validationStderrPath = Join-Path $validationDir 'validate.stderr.txt'
            $step.diagnosticCountsStdoutPath = Join-Path $validationDir 'diagnostic-counts.stdout.txt'
            $step.diagnosticCountsStderrPath = Join-Path $validationDir 'diagnostic-counts.stderr.txt'
            $negativeSource = Resolve-Input $manifest.negative.source
            $step.validationExitCode = Invoke-Logged $selfhostPath @('validate', $negativeSource) $validationDir 'c477 negative validate' $step.validationStdoutPath $step.validationStderrPath
            $validationText = [IO.File]::ReadAllText($step.validationStdoutPath)
            if ($step.validationExitCode -ne 0 -or (Get-Item -LiteralPath $step.validationStderrPath).Length -ne 0 -or $validationText -cnotmatch '^checked diagnostics = ([1-9][0-9]*)\r?\n$') { throw 'C477_PRE_LLVM_VALIDATION_FAILED: expected one exact nonzero checked diagnostic count and empty stderr' }
            $validatedCount = [int]$Matches[1]
            $step.diagnosticCountsExitCode = Invoke-Logged $selfhostPath @('diagnostic-counts', $negativeSource) $validationDir 'c477 negative diagnostic counts' $step.diagnosticCountsStdoutPath $step.diagnosticCountsStderrPath
            $countsStdout = [IO.File]::ReadAllText($step.diagnosticCountsStdoutPath)
            $countsStderr = [IO.File]::ReadAllText($step.diagnosticCountsStderrPath)
            if ($step.diagnosticCountsExitCode -ne 0 -or $countsStdout -cnotmatch '^checked diagnostics = ([1-9][0-9]*)\r?\n$') { throw 'C477_SEMANTIC_COUNTS_FAILED: expected one exact nonzero diagnostic count' }
            $countedTotal = [int]$Matches[1]
            if ($countsStderr -cnotmatch '^semantic diagnostics = ([1-9][0-9]*)\r?\nir diagnostics = ([0-9]+)\r?\n$') { throw 'C477_SEMANTIC_COUNTS_FAILED: expected exact semantic and IR counts' }
            $step.semanticDiagnosticCount = [int]$Matches[1]
            $step.irDiagnosticCount = [int]$Matches[2]
            if ($validatedCount -ne $countedTotal -or $countedTotal -ne ($step.semanticDiagnosticCount + $step.irDiagnosticCount)) { throw 'C477_SEMANTIC_COUNTS_MISMATCH: validate and diagnostic-counts differ' }
            if ($step.irDiagnosticCount -ne 0) { throw "C477_IR_DIAGNOSTICS_PRESENT: expected semantic-only blocking; found $($step.irDiagnosticCount) IR diagnostics" }
            Assert-ExactNames $validationDir @('validate.stdout.txt', 'validate.stderr.txt', 'diagnostic-counts.stdout.txt', 'diagnostic-counts.stderr.txt')
            $step.resultPath = Join-Path $caseDir 'result.json'
            & $negativeRunnerPath -ManagedCompiler $managedPath -SelfhostCompiler $selfhostPath -ManagedCompilerSha256 $ManagedCompilerSha256 -SelfhostCompilerSha256 $SelfhostCompilerSha256 -Source (Resolve-Input $manifest.negative.source) -Expected (Resolve-Input $manifest.negative.expected) -OutputDirectory $caseDir -RepositoryRoot $root -LlvmRoot $llvmPath -StdlibRoot $stdlibPath -TimeoutMilliseconds $TimeoutMilliseconds
            $negativeJson = [IO.File]::ReadAllText($step.resultPath)
            if (-not (Test-Json -Json $negativeJson -SchemaFile $negativeResultSchemaPath)) { throw 'C477_NEGATIVE_RESULT_SCHEMA: nested result rejected' }
            $negativeResult = $negativeJson | ConvertFrom-Json
            if ($negativeResult.state -cne 'passed' -or -not $negativeResult.inputsStable -or $negativeResult.orphanProcessIds.Count -ne 0) { throw 'C477_NEGATIVE_FAILED: strict managed/selfhost result did not pass' }
        } else {
            $fixture = if ($name -like '*Local') { $manifest.positives[0] } else { $manifest.positives[1] }
            $source = Resolve-Input $fixture.source
            $expected = Resolve-Input $fixture.expected
            $step.executablePath = Join-Path $caseDir 'probe.exe'
            $managed = $name -like 'managed*'
            $step.llvmPath = "$($step.executablePath).ll"
            $step.bitcodePath = Join-Path $caseDir 'probe.bc'
            $step.buildStdoutPath = Join-Path $caseDir 'build.stdout.txt'
            $step.buildStderrPath = Join-Path $caseDir 'build.stderr.txt'
            $step.assemblyStdoutPath = Join-Path $caseDir 'llvm-as.stdout.txt'
            $step.assemblyStderrPath = Join-Path $caseDir 'llvm-as.stderr.txt'
            $step.runStdoutPath = Join-Path $caseDir 'run.stdout.txt'
            $step.runStderrPath = Join-Path $caseDir 'run.stderr.txt'
            $buildFile = if ($managed) { $dotnetPath } else { $selfhostPath }
            [string[]]$arguments = @()
            if ($managed) { $arguments += $managedPath }
            $arguments += @('build', $source, '-o', $step.executablePath, '--target', 'windows-x64', '--llvm', $llvmPath)
            if (-not $managed) { $arguments += @('--stdlib', $stdlibPath, '--jobs', '1') }
            $arguments += @('-O1', '--keep-temps')
            $step.buildExitCode = Invoke-Logged $buildFile $arguments $caseDir "c477 $name build" $step.buildStdoutPath $step.buildStderrPath
            $buildText = [IO.File]::ReadAllText($step.buildStdoutPath) + [IO.File]::ReadAllText($step.buildStderrPath)
            if ($step.buildExitCode -ne 0 -or (Test-BuildWarningOrNote $buildText)) { throw "C477_BUILD_FAILED: $name exit=$($step.buildExitCode) or warning/note" }
            if (-not (Test-Path -LiteralPath $step.executablePath -PathType Leaf) -or -not (Test-Path -LiteralPath $step.llvmPath -PathType Leaf)) { throw "C477_PRODUCTS_MISSING: $name" }
            if ((Get-Item -LiteralPath $step.executablePath).Length -eq 0 -or (Get-Item -LiteralPath $step.llvmPath).Length -eq 0) { throw "C477_PRODUCTS_EMPTY: $name" }
            & $closurePath -LlvmPath $step.llvmPath
            if (-not $?) { throw "C477_DIRECT_CALL_CLOSURE: $name" }
            $assemblyExit = Invoke-Logged $llvmAsPath @($step.llvmPath, '-o', $step.bitcodePath) $caseDir "c477 $name llvm-as" $step.assemblyStdoutPath $step.assemblyStderrPath
            if ($assemblyExit -ne 0 -or -not (Test-Path -LiteralPath $step.bitcodePath -PathType Leaf) -or (Get-Item -LiteralPath $step.bitcodePath).Length -eq 0) { throw "C477_LLVM_ASSEMBLY_FAILED: $name exit=$assemblyExit" }
            $step.runExitCode = Invoke-Logged $step.executablePath @() $caseDir "c477 $name native run" $step.runStdoutPath $step.runStderrPath
            if ($step.runExitCode -ne 0 -or (Get-Item -LiteralPath $step.runStderrPath).Length -ne 0) { throw "C477_NATIVE_RUN_FAILED: $name exit=$($step.runExitCode)" }
            if (-not [Linq.Enumerable]::SequenceEqual([IO.File]::ReadAllBytes($step.runStdoutPath), [IO.File]::ReadAllBytes($expected))) { throw "C477_STDOUT_MISMATCH: $name" }
            Assert-PositiveCaseTree $caseDir $managed
        }
        if ((Get-InputFingerprint) -cne $fingerprintStart) { throw 'C477_INPUT_DRIFT: input changed during step' }
        $step.state = 'passed'; $record.completed++; $record.passed++; $activeCounted = $true
        Write-Result
        $active = $null
    }
    $record.inputFingerprintEnd = Get-InputFingerprint
    $record.inputsStable = $record.inputFingerprintStart -ceq $record.inputFingerprintEnd
    if (-not $record.inputsStable) { throw 'C477_INPUT_DRIFT: final input changed' }
    $record.state = 'passed'; Write-Result
    Write-Host "[c477 mutable binding] PASS 5/5 checks; $resultPath"
} catch {
    $message = $_.Exception.Message
    if ($null -ne $active) {
        $step = $record.steps[$active]
        $step.state = 'failed'; $step.failure = $message
        if ($activeCounted) { $record.passed-- } else { $record.completed++ }
        if ($active -ceq 'negativePair' -and (Test-Path -LiteralPath $step.resultPath -PathType Leaf)) {
            try {
                $nested = [IO.File]::ReadAllText($step.resultPath) | ConvertFrom-Json
                foreach ($id in @($nested.orphanProcessIds)) {
                    if ($id -gt 0 -and -not $script:orphanIds.Contains([int]$id)) { $script:orphanIds.Add([int]$id) }
                }
            } catch { $message += "; nested orphan inspection failed: $($_.Exception.Message)" }
        }
    }
    $record.orphanProcessIds = @($script:orphanIds)
    $record.failureId = if ($message -match '^C477_[A-Z_]+:') { ($message -split ':')[0] }
        elseif ($message -match 'exceeded the configured verification limit') { 'C477_PROCESS_TIMEOUT' }
        else { 'C477_STEP_FAILED' }
    $record.failure = $message
    try { $record.inputFingerprintEnd = Get-InputFingerprint; $record.inputsStable = $record.inputFingerprintStart -ceq $record.inputFingerprintEnd }
    catch { $record.failure += "; final fingerprint failed: $($_.Exception.Message)" }
    $record.state = 'failed'; Write-Result
    throw
}
