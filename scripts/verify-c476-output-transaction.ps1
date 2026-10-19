[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$Compiler,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$CompilerSha256,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$NegativeSource,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$NegativeExpectedStderr,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$PositiveSource,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$PositiveExpectedStdout,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$OutputDirectory,
    [Parameter(ParameterSetName = 'Run')][switch]$RunAliasCollision,
    [Parameter(ParameterSetName = 'Run')][switch]$ManagedCompiler,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$LlvmRoot = '.tools/llvm-22.1.8',
    [string]$StdlibRoot = 'stdlib',
    [ValidateRange(1000, 3600000)][int]$TimeoutMilliseconds = 180000,
    [Parameter(Mandatory, ParameterSetName = 'Validate')][switch]$ValidateContractOnly,
    [Parameter(Mandatory, ParameterSetName = 'SelfTest')][switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $PSScriptRoot 'contracts/c476-output-transaction.json'
$contractSchemaPath = Join-Path $PSScriptRoot 'contracts/c476-output-transaction.schema.json'
$resultSchemaPath = Join-Path $PSScriptRoot 'contracts/c476-output-transaction-result.schema.json'
$frozenContractSha256 = '65EACDEC301F36F7052E84C989EE9BB8AA0A8AB37E2E3C754F1F9913E7DEAD61'
$focused = @('semanticFailureFresh', 'existingSentinelSemanticFailure', 'successKeepTempsOn', 'successKeepTempsOff')
$allNames = @('semanticFailureFresh', 'emitterFailureFresh', 'linkerFailureFresh', 'successKeepTempsOn', 'successKeepTempsOff', 'existingSentinelSemanticFailure', 'existingSentinelEmitterFailure', 'existingSentinelLinkerFailure', 'sameOutputParallel', 'differentOutputParallel', 'stageCleanup', 'publicationFailure', 'spawnFailure')

function Resolve-Input([string]$Path) {
    $full = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $root $Path)) }
    return (Resolve-Path -LiteralPath $full -ErrorAction Stop).ProviderPath
}
function Get-Sha([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Assert-ContractFingerprint([byte[]]$Bytes) {
    $actual = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes))
    if ($actual -cne $frozenContractSha256) { throw "OUTPUT_CONTRACT_DRIFT: expected $frozenContractSha256, actual $actual" }
}
function Assert-OutputResourceAlias {
    $directory = Join-Path $root 'artifacts/scratch/c476-output-alias-model'
    $firstOutput = Join-Path $directory 'foo'
    $secondOutput = "$firstOutput.ll"
    $firstLl = "$firstOutput.ll"
    $secondLl = "$secondOutput.ll"
    if (-not [string]::Equals($firstLl, $secondOutput, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'OUTPUT_ALIAS_MODEL_INVALID: foo LLVM target must equal foo.ll executable target'
    }
    $firstLocks = @("$firstOutput.sollang-txn-lock", "$firstLl.sollang-txn-lock")
    $secondLocks = @("$secondOutput.sollang-txn-lock", "$secondLl.sollang-txn-lock")
    if (-not [string]::Equals($firstLocks[1], $secondLocks[0], [StringComparison]::OrdinalIgnoreCase)) {
        throw 'OUTPUT_ALIAS_MODEL_INVALID: colliding final paths do not share a resource lock'
    }
    $independent = Join-Path $directory 'bar'
    foreach ($lock in @("$independent.sollang-txn-lock", "$independent.ll.sollang-txn-lock")) {
        if ($firstLocks -icontains $lock -or $secondLocks -icontains $lock) {
            throw 'OUTPUT_ALIAS_MODEL_INVALID: independent output was incorrectly serialized'
        }
    }
}
function Assert-NoReparsePath([string]$Path) {
    $cursor = [IO.Path]::GetPathRoot($Path)
    foreach ($segment in ($Path.Substring($cursor.Length) -split '[\\/]')) {
        if ([string]::IsNullOrEmpty($segment)) { continue }
        $cursor = Join-Path $cursor $segment
        if (-not (Test-Path -LiteralPath $cursor)) { break }
        if (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "OUTPUT_REPARSE_PATH: $cursor"
        }
    }
}
function New-ExclusiveOutputDirectory([string]$Path) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw "OUTPUT_PARENT_MISSING: $parent" }
    Assert-NoReparsePath $parent
    if (-not ('C476OutputDirectoryNative' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class C476OutputDirectoryNative {
    [DllImport("kernel32.dll", EntryPoint = "CreateDirectoryW", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CreateDirectory(string path, IntPtr securityAttributes);
}
'@
    }
    if (-not [C476OutputDirectoryNative]::CreateDirectory($Path, [IntPtr]::Zero)) {
        $errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "OUTPUT_PATH_EXISTS_OR_CREATE_FAILED: exclusive CreateDirectoryW failed ($errorCode): $Path"
    }
    Assert-NoReparsePath $Path
}
function Assert-Contract {
    Assert-ContractFingerprint ([IO.File]::ReadAllBytes($contractPath))
    Assert-OutputResourceAlias
    $json = [IO.File]::ReadAllText($contractPath)
    if (-not (Test-Json -Json $json -SchemaFile $contractSchemaPath)) { throw 'OUTPUT_CONTRACT_INVALID: frozen contract failed its schema' }
    $contract = $json | ConvertFrom-Json
    if ($contract.status -cne 'requirements-frozen-unverified') { throw 'OUTPUT_CONTRACT_INVALID: contract status changed' }
    $names = @($contract.scenarios.PSObject.Properties.Name)
    if ($names.Count -ne $allNames.Count) { throw 'OUTPUT_CONTRACT_INVALID: scenario count differs from the fixed 13' }
    foreach ($name in $allNames) {
        if ($names -cnotcontains $name -or $contract.scenarios.$name.proofStatus -cne 'not-run') {
            throw "OUTPUT_CONTRACT_INVALID: scenario identity or initial proof status changed: $name"
        }
    }
    if ($contract.scenarios.sameOutputParallel.assertions -cnotcontains 'cross-output-alias-blocked-before-publication') {
        throw 'OUTPUT_CONTRACT_INVALID: foo/foo.ll collision assertion is missing'
    }
    return $contract
}
function New-Case {
    return [ordered]@{
        state = 'not-run'; exitCode = $null; buildStdoutPath = $null; buildStderrPath = $null
        runStdoutPath = $null; runStderrPath = $null; products = @(); assertionsPassed = $false; failure = $null
    }
}
function New-AliasCase {
    return [ordered]@{
        state = 'not-run'; firstOutput = $null; secondOutput = $null
        firstExitCode = $null; secondExitCode = $null
        firstStdoutPath = $null; firstStderrPath = $null
        secondStdoutPath = $null; secondStderrPath = $null
        lockObserved = $false; overlapObserved = $false
        products = @(); failure = $null
    }
}
function Set-FailedCase([System.Collections.IDictionary]$Record, [string]$Name, [bool]$AlreadyCounted, [string]$Failure) {
    if ($AlreadyCounted) { $Record.focusedPassed-- } else { $Record.completed++ }
    $case = $Record.scenarios[$Name]
    $case.state = 'failed'; $case.assertionsPassed = $false; $case.failure = $Failure
}
function Assert-ArtifactNames([string[]]$Actual, [string[]]$Expected) {
    $actualSorted = @($Actual | Sort-Object -CaseSensitive)
    $expectedSorted = @($Expected | Sort-Object -CaseSensitive)
    if ($actualSorted.Count -ne $expectedSorted.Count) { throw "OUTPUT_ARTIFACT_SET: actual=$($actualSorted -join ',') expected=$($expectedSorted -join ',')" }
    for ($i = 0; $i -lt $actualSorted.Count; $i++) {
        if ($actualSorted[$i] -cne $expectedSorted[$i]) { throw "OUTPUT_ARTIFACT_SET: actual=$($actualSorted -join ',') expected=$($expectedSorted -join ',')" }
    }
}
function Get-ArtifactNames([string]$Directory) {
    return @(Get-ChildItem -LiteralPath $Directory -Force | ForEach-Object Name)
}
function Assert-ManagedCache([string]$ArtifactDirectory, [string[]]$OutputNames) {
    $cacheDirectory = Join-Path $ArtifactDirectory '.sollang-cache'
    if (-not (Test-Path -LiteralPath $cacheDirectory -PathType Container)) { throw 'OUTPUT_MANAGED_CACHE_MISSING' }
    Assert-NoReparsePath $cacheDirectory
    $groups = @{}
    foreach ($file in @(Get-ChildItem -LiteralPath $cacheDirectory -Force)) {
        if ($file.PSIsContainer -or $file.Length -eq 0 -or $file.Extension -notin @('.cgu', '.product', '.semantic', '.sources')) {
            throw "OUTPUT_MANAGED_CACHE_INVALID: $($file.Name)"
        }
        Assert-NoReparsePath $file.FullName
        $stem = $file.Name.Substring(0, $file.Name.Length - $file.Extension.Length)
        $allowed = $false
        foreach ($name in $OutputNames) { if ($stem.StartsWith("$name.", [StringComparison]::Ordinal)) { $allowed = $true } }
        if (-not $allowed) { throw "OUTPUT_MANAGED_CACHE_OWNER_INVALID: $($file.Name)" }
        if (-not $groups.ContainsKey($stem)) { $groups[$stem] = @() }
        $groups[$stem] += $file.Extension
    }
    if ($groups.Count -eq 0) { throw 'OUTPUT_MANAGED_CACHE_EMPTY' }
    foreach ($stem in $groups.Keys) {
        Assert-ArtifactNames @($groups[$stem]) @('.cgu', '.product', '.semantic', '.sources')
    }
}
function Assert-RootSurface([string]$RootDirectory, [int]$CaseCount, [bool]$IncludeAlias) {
    if ($CaseCount -lt 0 -or $CaseCount -gt $focused.Count) { throw 'OUTPUT_ROOT_CASE_COUNT_INVALID' }
    $expected = @('result.json')
    for ($index = 0; $index -lt $CaseCount; $index++) { $expected += $focused[$index] }
    if ($IncludeAlias) { $expected += 'aliasCollision' }
    Assert-ArtifactNames @(Get-ArtifactNames $RootDirectory) $expected
}
function Assert-EmptyLog([string]$Path, [string]$Description) {
    if ((Get-Item -LiteralPath $Path).Length -ne 0) { throw "OUTPUT_ASSERTION_FAILED: $Description must be empty" }
}
function Publish-JsonResult([string]$Path, [string]$Json) {
    $temporary = "$Path.tmp-$PID-$([guid]::NewGuid().ToString('N'))"
    try {
        [IO.File]::WriteAllText($temporary, $Json, [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temporary, $Path, $true)
    } finally {
        if (Test-Path -LiteralPath $temporary -PathType Leaf) { Remove-Item -LiteralPath $temporary -Force }
    }
}
function Assert-CaseSurface([string]$RootDirectory, [string]$CaseName, [bool]$NativeRun, [bool]$LlvmAsChecked, [int]$ExpectedCaseCount) {
    $caseDirectory = Join-Path $RootDirectory $CaseName
    $caseNames = @('artifacts', 'build.stdout.txt', 'build.stderr.txt')
    if ($LlvmAsChecked) { $caseNames += @('llvm-as.stdout.txt', 'llvm-as.stderr.txt') }
    if ($NativeRun) { $caseNames += @('run.stdout.txt', 'run.stderr.txt') }
    Assert-ArtifactNames @(Get-ArtifactNames $caseDirectory) $caseNames
    Assert-RootSurface $RootDirectory $ExpectedCaseCount $false
}
function Assert-PublishedLlvm([string]$LlvmFile, [string]$WorkingDirectory, [string]$StdoutPath, [string]$StderrPath) {
    $exitCode = Invoke-LoggedProcess -File $llvmAsPath -Arguments @($LlvmFile, '--disable-output') `
        -Description "published LLVM assembly: $LlvmFile" -WorkingDirectory $WorkingDirectory `
        -StdoutPath $StdoutPath -StderrPath $StderrPath
    if ($exitCode -ne 0) { throw "OUTPUT_LLVM_AS_FAILED: published LLVM assembly exited $exitCode; stderr: $StderrPath" }
    Assert-EmptyLog $StdoutPath 'published LLVM assembler stdout'
    Assert-EmptyLog $StderrPath 'published LLVM assembler stderr'
}
function Get-LiveDescendantIds([int]$RootId, [datetime]$RootStartUtc, [object[]]$Records) {
    $descendants = [Collections.Generic.HashSet[int]]::new()
    $frontier = @($RootId)
    while ($frontier.Count -gt 0) {
        $next = @()
        foreach ($record in $Records) {
            $id = [int]$record.ProcessId
            if ([datetime]$record.CreationDate -lt $RootStartUtc.ToLocalTime()) { continue }
            if ($frontier -contains [int]$record.ParentProcessId -and $id -ne $RootId -and $descendants.Add($id)) { $next += $id }
        }
        $frontier = $next
    }
    return @($descendants | Sort-Object)
}
function Invoke-LoggedProcess([string]$File, [string[]]$Arguments, [string]$Description, [string]$WorkingDirectory, [string]$StdoutPath, [string]$StderrPath) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $File
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $stdout = [IO.File]::Create($StdoutPath)
    $stderr = [IO.File]::Create($StderrPath)
    $started = $false
    $rootStartUtc = [datetime]::MinValue
    try {
        if (-not $process.Start()) { throw "OUTPUT_SPAWN_FAILED: $Description" }
        $started = $true
        $rootStartUtc = $process.StartTime.ToUniversalTime()
        $outCopy = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
        $errCopy = $process.StandardError.BaseStream.CopyToAsync($stderr)
        $waitFailure = $null
        try { Wait-VerificationProcess -Process $process -Description $Description -TimeoutMilliseconds $TimeoutMilliseconds }
        catch { $waitFailure = $_ }
        if (-not $process.WaitForExit(0)) {
            try { $process.Kill($true) }
            catch { try { $process.Kill() } catch { } }
            if (-not $process.WaitForExit(5000)) {
                $script:orphanProcessIds.Add($process.Id)
                throw "OUTPUT_PROCESS_ORPHANED: $Description root $($process.Id) survived cleanup"
            }
            if ($null -eq $waitFailure) { $waitFailure = [Exception]::new("OUTPUT_PROCESS_ORPHANED: $Description root remained active after bounded wait") }
        }
        try { $descendants = @(Get-LiveDescendantIds $process.Id $rootStartUtc @(Get-CimInstance Win32_Process)) }
        catch { throw "OUTPUT_PROCESS_INSPECTION_FAILED: $Description $($_.Exception.Message)" }
        if ($descendants.Count -gt 0) {
            foreach ($id in $descendants) {
                if (-not $script:orphanProcessIds.Contains($id)) { $script:orphanProcessIds.Add($id) }
            }
            throw "OUTPUT_PROCESS_ORPHANED: $Description exited with observed descendants $($descendants -join ','); no PID-based termination attempted"
        }
        $copies = [Threading.Tasks.Task]::WhenAll([Threading.Tasks.Task[]]@($outCopy, $errCopy))
        if (-not $copies.Wait(5000)) { throw "OUTPUT_LOG_DRAIN_TIMEOUT: $Description" }
        $copies.GetAwaiter().GetResult()
        $stdout.Flush(); $stderr.Flush()
        if ($null -ne $waitFailure) { throw $waitFailure }
        return $process.ExitCode
    } catch {
        $originalFailure = $_
        $inspectionFailure = $null
        if ($started) {
            if (-not $process.WaitForExit(0)) {
                try { $process.Kill($true) }
                catch { try { $process.Kill() } catch { } }
                if (-not $process.WaitForExit(5000) -and -not $script:orphanProcessIds.Contains($process.Id)) {
                    $script:orphanProcessIds.Add($process.Id)
                }
            }
            try {
                $remainingDescendants = @(Get-LiveDescendantIds $process.Id $rootStartUtc @(Get-CimInstance Win32_Process))
                foreach ($id in $remainingDescendants) {
                    if (-not $script:orphanProcessIds.Contains($id)) { $script:orphanProcessIds.Add($id) }
                }
            } catch { $inspectionFailure = $_.Exception.Message }
            if ($null -ne $inspectionFailure) {
                throw "OUTPUT_PROCESS_INSPECTION_FAILED: cleanup descendant inspection failed: $inspectionFailure; original: $($originalFailure.Exception.Message)"
            }
        }
        if ($script:orphanProcessIds.Count -gt 0) { throw "OUTPUT_PROCESS_ORPHANED: observed process IDs $($script:orphanProcessIds -join ','); original: $($originalFailure.Exception.Message)" }
        throw $originalFailure
    } finally {
        $process.Dispose(); $stdout.Dispose(); $stderr.Dispose()
    }
}
function Start-LoggedChild([string]$File, [string[]]$Arguments, [string]$Description, [string]$WorkingDirectory, [string]$StdoutPath, [string]$StderrPath) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $File
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $stdout = [IO.File]::Create($StdoutPath)
    $stderr = [IO.File]::Create($StderrPath)
    $started = $false
    try {
        if (-not $process.Start()) { throw "OUTPUT_SPAWN_FAILED: $Description" }
        $started = $true
        return [pscustomobject]@{
            Process = $process; Description = $Description; Stdout = $stdout; Stderr = $stderr
            StartedAt = [DateTimeOffset]::Now
            StdoutCopy = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
            StderrCopy = $process.StandardError.BaseStream.CopyToAsync($stderr)
        }
    } catch {
        if ($started -and -not $process.HasExited) {
            try { $process.Kill($true) }
            catch { try { $process.Kill() } catch { } }
            if (-not $process.WaitForExit(5000) -and -not $script:orphanProcessIds.Contains($process.Id)) {
                $script:orphanProcessIds.Add($process.Id)
            }
        }
        $process.Dispose(); $stdout.Dispose(); $stderr.Dispose()
        throw
    }
}
function Wait-LoggedChild([object]$Child) {
    Wait-VerificationProcess -Process $Child.Process -Description $Child.Description -TimeoutMilliseconds $TimeoutMilliseconds -TimeoutStartedAt $Child.StartedAt
    if (-not $Child.Process.WaitForExit(0)) { throw "OUTPUT_PROCESS_TIMEOUT: $($Child.Description) did not reach a terminal state" }
    try { $descendants = @(Get-LiveDescendantIds $Child.Process.Id $Child.StartedAt.UtcDateTime @(Get-CimInstance Win32_Process)) }
    catch { throw "OUTPUT_PROCESS_INSPECTION_FAILED: $($Child.Description) $($_.Exception.Message)" }
    if ($descendants.Count -gt 0) {
        foreach ($id in $descendants) { if (-not $script:orphanProcessIds.Contains($id)) { $script:orphanProcessIds.Add($id) } }
        throw "OUTPUT_PROCESS_ORPHANED: $($Child.Description) exited with observed descendants $($descendants -join ',')"
    }
    $copies = [Threading.Tasks.Task]::WhenAll([Threading.Tasks.Task[]]@($Child.StdoutCopy, $Child.StderrCopy))
    if (-not $copies.Wait(5000)) { throw "OUTPUT_LOG_DRAIN_TIMEOUT: $($Child.Description)" }
    $copies.GetAwaiter().GetResult()
    $Child.Stdout.Flush(); $Child.Stderr.Flush()
    return $Child.Process.ExitCode
}
function Close-LoggedChild([object]$Child) {
    if ($null -eq $Child) { return }
    try {
        if (-not $Child.Process.HasExited) {
            try { $Child.Process.Kill($true) }
            catch { try { $Child.Process.Kill() } catch { } }
            if (-not $Child.Process.WaitForExit(5000)) {
                if (-not $script:orphanProcessIds.Contains($Child.Process.Id)) { $script:orphanProcessIds.Add($Child.Process.Id) }
                throw "OUTPUT_PROCESS_ORPHANED: owned $($Child.Description) root survived bounded cleanup"
            }
        }
        try { $descendants = @(Get-LiveDescendantIds $Child.Process.Id $Child.StartedAt.UtcDateTime @(Get-CimInstance Win32_Process)) }
        catch { throw "OUTPUT_PROCESS_INSPECTION_FAILED: cleanup of $($Child.Description) $($_.Exception.Message)" }
        foreach ($id in $descendants) { if (-not $script:orphanProcessIds.Contains($id)) { $script:orphanProcessIds.Add($id) } }
        if ($descendants.Count -gt 0) { throw "OUTPUT_PROCESS_ORPHANED: owned $($Child.Description) has observed descendants $($descendants -join ',')" }
        $copies = [Threading.Tasks.Task]::WhenAll([Threading.Tasks.Task[]]@($Child.StdoutCopy, $Child.StderrCopy))
        if (-not $copies.Wait(5000)) { throw "OUTPUT_LOG_DRAIN_TIMEOUT: cleanup of $($Child.Description)" }
        $copies.GetAwaiter().GetResult()
        $Child.Stdout.Flush(); $Child.Stderr.Flush()
    } finally {
        $Child.Process.Dispose(); $Child.Stdout.Dispose(); $Child.Stderr.Dispose()
    }
}

$contract = Assert-Contract
if ($ValidateContractOnly) {
    Write-Host '[c476 output transaction] original contract 13/13 frozen not-run; focused executable subset 4/13; supplemental alias 0/1 not-run'
    return
}
if ($SelfTest) {
    $rootStart = [datetime]::UtcNow
    $oldChild = [pscustomobject]@{ ProcessId = 301; ParentProcessId = 300; CreationDate = $rootStart.AddMinutes(-5).ToLocalTime() }
    if (@(Get-LiveDescendantIds 300 $rootStart @($oldChild)).Count -ne 0) {
        throw 'OUTPUT_SELFTEST_FAILED: process predating recycled root PID was reported as a child'
    }
    $liveChild = [pscustomobject]@{ ProcessId = 302; ParentProcessId = 300; CreationDate = $rootStart.AddSeconds(1).ToLocalTime() }
    if (@(Get-LiveDescendantIds 300 $rootStart @($liveChild)).Count -ne 1) {
        throw 'OUTPUT_SELFTEST_FAILED: live child was missed'
    }
    $llvmAsPath = Join-Path (Resolve-Input $LlvmRoot) 'bin/llvm-as.exe'
    if (-not (Test-Path -LiteralPath $llvmAsPath -PathType Leaf)) { throw "OUTPUT_LLVM_AS_MISSING: $llvmAsPath" }
    $contractBytes = [IO.File]::ReadAllBytes($contractPath)
    Assert-ContractFingerprint $contractBytes
    $mutatedContract = [byte[]]$contractBytes.Clone()
    $mutatedContract[0] = $mutatedContract[0] -bxor 1
    $rejectedContractMutation = $false
    try { Assert-ContractFingerprint $mutatedContract }
    catch { $rejectedContractMutation = $_.Exception.Message -match '^OUTPUT_CONTRACT_DRIFT:' }
    if (-not $rejectedContractMutation) { throw 'OUTPUT_SELFTEST_FAILED: changed frozen contract was accepted' }
    Assert-OutputResourceAlias
    if ([IO.File]::ReadAllText($PSCommandPath).Contains(('[Diagnostics.Process]::GetProcess' + 'ById('))) { throw 'OUTPUT_SELFTEST_FAILED: unsafe PID-based process termination returned' }
    $countProbe = [ordered]@{ completed = 1; focusedPassed = 1; scenarios = [ordered]@{ example = New-Case } }
    Set-FailedCase $countProbe 'example' $true 'record publication failed'
    if ($countProbe.completed -ne 1 -or $countProbe.focusedPassed -ne 0 -or $countProbe.scenarios.example.state -cne 'failed') { throw 'OUTPUT_SELFTEST_FAILED: already-counted case was counted twice' }
    $countProbe = [ordered]@{ completed = 0; focusedPassed = 0; scenarios = [ordered]@{ example = New-Case } }
    Set-FailedCase $countProbe 'example' $false 'build failed'
    if ($countProbe.completed -ne 1 -or $countProbe.focusedPassed -ne 0) { throw 'OUTPUT_SELFTEST_FAILED: failed case was not counted exactly once' }
    if ($IsWindows) {
        $exclusiveTestPath = Join-Path $root ("artifacts/scratch/c476-output-transaction-selftest-$([guid]::NewGuid().ToString('N'))")
        New-ExclusiveOutputDirectory $exclusiveTestPath
        try {
            $publicationPath = Join-Path $exclusiveTestPath 'result.json'
            Publish-JsonResult $publicationPath '{"step":1}'
            Publish-JsonResult $publicationPath '{"step":2}'
            if ([IO.File]::ReadAllText($publicationPath) -cne '{"step":2}') { throw 'OUTPUT_SELFTEST_FAILED: result replacement did not publish the second value' }
            foreach ($name in $focused) { [void][IO.Directory]::CreateDirectory((Join-Path $exclusiveTestPath $name)) }
            Assert-RootSurface $exclusiveTestPath $focused.Count $false
            Remove-Item -LiteralPath (Join-Path $exclusiveTestPath $focused[0]) -Force
            $rejectedMissingCase = $false
            try { Assert-RootSurface $exclusiveTestPath $focused.Count $false }
            catch { $rejectedMissingCase = $_.Exception.Message -match '^OUTPUT_ARTIFACT_SET:' }
            if (-not $rejectedMissingCase) { throw 'OUTPUT_SELFTEST_FAILED: missing completed case directory was accepted' }
            foreach ($name in $focused) {
                $ownedCase = Join-Path $exclusiveTestPath $name
                if (Test-Path -LiteralPath $ownedCase -PathType Container) { Remove-Item -LiteralPath $ownedCase -Force }
            }
            $semanticStdout = Join-Path $exclusiveTestPath 'semantic.stdout.txt'
            [IO.File]::WriteAllText($semanticStdout, 'unexpected output')
            $rejectedSemanticStdout = $false
            try { Assert-EmptyLog $semanticStdout 'semantic failure stdout' }
            catch { $rejectedSemanticStdout = $_.Exception.Message -match '^OUTPUT_ASSERTION_FAILED:' }
            if (-not $rejectedSemanticStdout) { throw 'OUTPUT_SELFTEST_FAILED: nonempty semantic-failure stdout was accepted' }
            [IO.File]::WriteAllText($semanticStdout, '')
            Assert-EmptyLog $semanticStdout 'semantic failure stdout'
            Remove-Item -LiteralPath $semanticStdout -Force
            $publishedLlvm = Join-Path $exclusiveTestPath 'published.ll'
            $assemblyStdout = Join-Path $exclusiveTestPath 'llvm-as.stdout.txt'
            $assemblyStderr = Join-Path $exclusiveTestPath 'llvm-as.stderr.txt'
            [IO.File]::WriteAllText($publishedLlvm, "define i32 @main() {`nentry:`n  ret i32 0`n}`n")
            Assert-PublishedLlvm $publishedLlvm $exclusiveTestPath $assemblyStdout $assemblyStderr
            [IO.File]::WriteAllText($publishedLlvm, "define i32 @main() {`nentry:`n")
            $rejectedTruncatedLlvm = $false
            try { Assert-PublishedLlvm $publishedLlvm $exclusiveTestPath $assemblyStdout $assemblyStderr }
            catch { $rejectedTruncatedLlvm = $_.Exception.Message -match '^OUTPUT_LLVM_AS_FAILED:' }
            if (-not $rejectedTruncatedLlvm) { throw 'OUTPUT_SELFTEST_FAILED: truncated published LLVM was accepted' }
            foreach ($ownedFile in @($publishedLlvm, $assemblyStdout, $assemblyStderr, $publicationPath)) {
                if (Test-Path -LiteralPath $ownedFile -PathType Leaf) { Remove-Item -LiteralPath $ownedFile -Force }
            }
            $rejectedExistingDirectory = $false
            try { New-ExclusiveOutputDirectory $exclusiveTestPath }
            catch { $rejectedExistingDirectory = $true }
            if (-not $rejectedExistingDirectory) { throw 'OUTPUT_SELFTEST_FAILED: existing output directory reused' }
        } finally {
            if (Test-Path -LiteralPath $exclusiveTestPath -PathType Container) {
                foreach ($name in $focused) {
                    $ownedCase = Join-Path $exclusiveTestPath $name
                    if (Test-Path -LiteralPath $ownedCase -PathType Container) { Remove-Item -LiteralPath $ownedCase -Force }
                }
                foreach ($name in @('result.json', 'semantic.stdout.txt', 'published.ll', 'llvm-as.stdout.txt', 'llvm-as.stderr.txt')) {
                    $ownedFile = Join-Path $exclusiveTestPath $name
                    if (Test-Path -LiteralPath $ownedFile -PathType Leaf) { Remove-Item -LiteralPath $ownedFile -Force }
                }
                Remove-Item -LiteralPath $exclusiveTestPath -Force
            }
        }
    }
    Assert-ArtifactNames @() @()
    Assert-ArtifactNames @('probe.exe', 'probe.exe.ll') @('probe.exe.ll', 'probe.exe')
    $rejectedExtra = $false
    try { Assert-ArtifactNames @('probe.exe', 'probe.exe.ll', 'probe.stage') @('probe.exe', 'probe.exe.ll') }
    catch { $rejectedExtra = $true }
    if (-not $rejectedExtra) { throw 'OUTPUT_SELFTEST_FAILED: stage residue accepted' }
    $rejectedLl = $false
    try { Assert-ArtifactNames @('probe.exe', 'probe.exe.ll') @('probe.exe') }
    catch { $rejectedLl = $true }
    if (-not $rejectedLl) { throw 'OUTPUT_SELFTEST_FAILED: keep-temps-off LLVM accepted' }
    $scenarios = [ordered]@{}
    foreach ($name in $allNames) { $scenarios[$name] = New-Case }
    $sample = [ordered]@{
        schemaVersion = 1; gate = 'c476-output-transaction-focused'; state = 'running'
        contractPath = 'contract'; contractSha256 = ('A' * 64); compilerPath = 'compiler'; compilerSha256 = ('B' * 64)
        negativeSource = 'negative'; negativeSourceSha256 = ('C' * 64)
        negativeExpectedStderr = 'negative stderr'; negativeExpectedStderrSha256 = ('D' * 64)
        positiveSource = 'positive'; positiveSourceSha256 = ('E' * 64)
        positiveExpectedStdout = 'positive stdout'; positiveExpectedStdoutSha256 = ('F' * 64)
        llvmRoot = 'llvm'; stdlibRoot = 'stdlib'; stageAuditScope = 'case-output-tree-and-isolated-working-directory'
        sourceObservationScope = 'historical-contract-only-not-current-input'
        fixtureSelectionScope = 'caller-supplied-source-and-exact-expected-bytes'; inputFingerprintStart = ('1' * 64)
        inputFingerprintEnd = $null; inputsStable = $false; completed = 0; focusedPassed = 0
        aliasRequested = $false; aliasCompleted = 0; aliasPassed = 0; aliasCollision = New-AliasCase
        fullContractPassed = $false; orphanProcessIds = @(); scenarios = $scenarios; failureId = $null; failure = $null
    }
    if (-not (Test-Json -Json ($sample | ConvertTo-Json -Depth 12) -SchemaFile $resultSchemaPath)) { throw 'OUTPUT_SELFTEST_FAILED: running schema rejected' }
    $sample.fullContractPassed = $true
    if (Test-Json -Json ($sample | ConvertTo-Json -Depth 12) -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) { throw 'OUTPUT_SELFTEST_FAILED: full-contract overclaim accepted' }
    $sample.fullContractPassed = $false
    $sample.scenarios.emitterFailureFresh.state = 'passed'
    $sample.scenarios.emitterFailureFresh.assertionsPassed = $true
    $sample.scenarios.emitterFailureFresh.exitCode = 0
    if (Test-Json -Json ($sample | ConvertTo-Json -Depth 12) -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) { throw 'OUTPUT_SELFTEST_FAILED: unimplemented scenario passed' }
    $sample.scenarios.emitterFailureFresh = New-Case
    $sample.state = 'focused-passed'; $sample.completed = 4; $sample.focusedPassed = 4
    $sample.inputFingerprintEnd = ('1' * 64); $sample.inputsStable = $true
    if (Test-Json -Json ($sample | ConvertTo-Json -Depth 12) -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) { throw 'OUTPUT_SELFTEST_FAILED: focused pass without four cases accepted' }
    foreach ($name in $focused) {
        $sample.scenarios[$name].state = 'passed'
        $sample.scenarios[$name].exitCode = if ($name -in @('semanticFailureFresh', 'existingSentinelSemanticFailure')) { 1 } else { 0 }
        $sample.scenarios[$name].assertionsPassed = $true
    }
    if (-not (Test-Json -Json ($sample | ConvertTo-Json -Depth 12) -SchemaFile $resultSchemaPath)) { throw 'OUTPUT_SELFTEST_FAILED: focused pass rejected' }
    $sample.aliasRequested = $true
    if (Test-Json -Json ($sample | ConvertTo-Json -Depth 12) -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) {
        throw 'OUTPUT_SELFTEST_FAILED: requested but unrun alias collision was accepted as focused pass'
    }
    $sample.aliasCompleted = 1; $sample.aliasPassed = 1
    $sample.aliasCollision.state = 'passed'
    $sample.aliasCollision.firstExitCode = 0
    $sample.aliasCollision.secondExitCode = 1
    $sample.aliasCollision.lockObserved = $true
    $sample.aliasCollision.overlapObserved = $true
    if (-not (Test-Json -Json ($sample | ConvertTo-Json -Depth 12) -SchemaFile $resultSchemaPath)) {
        throw 'OUTPUT_SELFTEST_FAILED: supervised alias pass was rejected'
    }
    $sample.aliasCollision.overlapObserved = $false
    if (Test-Json -Json ($sample | ConvertTo-Json -Depth 12) -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) {
        throw 'OUTPUT_SELFTEST_FAILED: alias pass without observed overlap was accepted'
    }
    Write-Host '[c476 output transaction] self-test passed; original contract 13 scenarios, supplemental alias 1 scenario; no compiler launched'
    return
}

if (-not $IsWindows) { throw 'OUTPUT_PLATFORM_UNSUPPORTED: this runner currently proves windows-x64 only' }
$compilerPath = Resolve-Input $Compiler
$negativePath = Resolve-Input $NegativeSource
$negativeExpectedPath = Resolve-Input $NegativeExpectedStderr
$positivePath = Resolve-Input $PositiveSource
$positiveExpectedPath = Resolve-Input $PositiveExpectedStdout
$llvmPath = Resolve-Input $LlvmRoot
$stdlibPath = Resolve-Input $StdlibRoot
$managedDependencies = @()
if ($ManagedCompiler) {
    if ([IO.Path]::GetFileName($compilerPath) -cne 'Sollang.Compiler.exe') { throw 'OUTPUT_MANAGED_COMPILER_PATH_INVALID' }
    $compilerDirectory = [IO.Path]::GetDirectoryName($compilerPath)
    $managedDependencies = @('Sollang.Compiler.dll', 'Sollang.Compiler.deps.json', 'Sollang.Compiler.runtimeconfig.json') |
        ForEach-Object { Resolve-Input (Join-Path $compilerDirectory $_) }
}
$buildOptions = @('--target', 'windows-x64', '--llvm', $llvmPath)
if (-not $ManagedCompiler) { $buildOptions += @('--stdlib', $stdlibPath, '--jobs', '1') }
$buildOptions += '-O1'
$llvmAsPath = Join-Path $llvmPath 'bin/llvm-as.exe'
if (-not (Test-Path -LiteralPath $llvmAsPath -PathType Leaf)) { throw "OUTPUT_LLVM_AS_MISSING: $llvmAsPath" }
$outputPath = if ([IO.Path]::IsPathRooted($OutputDirectory)) { [IO.Path]::GetFullPath($OutputDirectory) } else { [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory)) }
$scratchRoot = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
if (-not $outputPath.StartsWith($scratchRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "OUTPUT_PATH_INVALID: output must be below $scratchRoot"
}
foreach ($path in (@($compilerPath, $negativePath, $negativeExpectedPath, $positivePath, $positiveExpectedPath, $llvmPath, $stdlibPath, $outputPath) + $managedDependencies)) { Assert-NoReparsePath $path }
if (Test-Path -LiteralPath $outputPath) { throw "OUTPUT_PATH_EXISTS: $outputPath" }
if ($CompilerSha256 -cnotmatch '^[0-9A-Fa-f]{64}$' -or (Get-Sha $compilerPath) -cne $CompilerSha256.ToUpperInvariant()) { throw 'OUTPUT_COMPILER_IDENTITY: compiler SHA-256 differs from the fixed input' }
if ((Get-Item -LiteralPath $negativeExpectedPath).Length -eq 0 -or (Get-Item -LiteralPath $positiveExpectedPath).Length -eq 0) { throw 'OUTPUT_EXPECTATION_EMPTY: expected byte files must not be empty' }
if ([IO.File]::ReadAllText($negativeExpectedPath) -notmatch '(?m);?\s*sollang:?\s+semantic error') { throw 'OUTPUT_EXPECTATION_NOT_SEMANTIC: exact negative stderr lacks a Sollang semantic-error marker' }

function Get-InputFingerprint {
    $common = Get-NativeExactWindowsCommonInputFingerprint -RepositoryRoot $root -CompilerPath $compilerPath -StdlibRoot $stdlibPath -LlvmRoot $llvmPath
    $settings = [ordered]@{ gate = 'c476-output-transaction-focused-v2'; common = $common; compilerSha256 = $CompilerSha256.ToUpperInvariant(); timeoutMilliseconds = [string]$TimeoutMilliseconds; runAliasCollision = [string][bool]$RunAliasCollision; managedCompiler = [string][bool]$ManagedCompiler }
    return Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root -Settings $settings -InputPath (@($PSCommandPath, $contractPath, $contractSchemaPath, $resultSchemaPath, $negativePath, $negativeExpectedPath, $positivePath, $positiveExpectedPath) + $managedDependencies)
}
$fingerprintStart = Get-InputFingerprint
New-ExclusiveOutputDirectory $outputPath
$script:orphanProcessIds = [Collections.Generic.List[int]]::new()
$scenarios = [ordered]@{}
foreach ($name in $allNames) { $scenarios[$name] = New-Case }
$record = [ordered]@{
    schemaVersion = 1; gate = 'c476-output-transaction-focused'; state = 'running'
    contractPath = $contractPath; contractSha256 = Get-Sha $contractPath
    compilerPath = $compilerPath; compilerSha256 = Get-Sha $compilerPath
    negativeSource = $negativePath; negativeSourceSha256 = Get-Sha $negativePath
    negativeExpectedStderr = $negativeExpectedPath; negativeExpectedStderrSha256 = Get-Sha $negativeExpectedPath
    positiveSource = $positivePath; positiveSourceSha256 = Get-Sha $positivePath
    positiveExpectedStdout = $positiveExpectedPath; positiveExpectedStdoutSha256 = Get-Sha $positiveExpectedPath
    llvmRoot = $llvmPath; stdlibRoot = $stdlibPath; stageAuditScope = 'case-output-tree-and-isolated-working-directory'
    sourceObservationScope = 'historical-contract-only-not-current-input'
    fixtureSelectionScope = 'caller-supplied-source-and-exact-expected-bytes'
    inputFingerprintStart = $fingerprintStart; inputFingerprintEnd = $null; inputsStable = $false
    completed = 0; focusedPassed = 0; fullContractPassed = $false; orphanProcessIds = @()
    aliasRequested = [bool]$RunAliasCollision; aliasCompleted = 0; aliasPassed = 0; aliasCollision = New-AliasCase
    scenarios = $scenarios; failureId = $null; failure = $null
}
$resultPath = Join-Path $outputPath 'result.json'
function Write-Result {
    $json = $record | ConvertTo-Json -Depth 12
    if (-not (Test-Json -Json $json -SchemaFile $resultSchemaPath)) { throw 'OUTPUT_RESULT_SCHEMA_INVALID: result rejected' }
    Publish-JsonResult $resultPath $json
}
Write-Result

function Invoke-AliasCollision {
    $alias = $record.aliasCollision
    $caseDir = Join-Path $outputPath 'aliasCollision'
    $artifactDir = Join-Path $caseDir 'artifacts'
    New-ExclusiveOutputDirectory $caseDir
    New-ExclusiveOutputDirectory $artifactDir
    $firstOutput = Join-Path $artifactDir 'foo'
    $secondOutput = "$firstOutput.ll"
    $alias.firstOutput = $firstOutput
    $alias.secondOutput = $secondOutput
    $alias.firstStdoutPath = Join-Path $caseDir 'first.stdout.txt'
    $alias.firstStderrPath = Join-Path $caseDir 'first.stderr.txt'
    $alias.secondStdoutPath = Join-Path $caseDir 'second.stdout.txt'
    $alias.secondStderrPath = Join-Path $caseDir 'second.stderr.txt'
    Write-Result
    $common = @($buildOptions) + @('--keep-temps')
    $firstArgs = @('build', $positivePath, '-o', $firstOutput) + $common
    $secondArgs = @('build', $positivePath, '-o', $secondOutput) + $common
    $first = $null
    $second = $null
    $primaryFailure = $null
    try {
        $first = Start-LoggedChild -File $compilerPath -Arguments $firstArgs -Description 'c476 alias foo build' -WorkingDirectory $caseDir -StdoutPath $alias.firstStdoutPath -StderrPath $alias.firstStderrPath
        $lockPath = "$secondOutput.sollang-txn-lock"
        $watch = [Diagnostics.Stopwatch]::StartNew()
        # The compiler can spend more than 30 seconds lowering the source before
        # the driver reaches its output claim. Bound this observation by the
        # caller's process timeout so a slow valid build is not misclassified.
        $lockWaitLimit = $TimeoutMilliseconds
        while ($watch.ElapsedMilliseconds -lt $lockWaitLimit) {
            if ((Test-Path -LiteralPath $lockPath -PathType Leaf) -and -not $first.Process.HasExited) {
                $alias.lockObserved = $true
                break
            }
            if ($first.Process.HasExited) { break }
            Start-Sleep -Milliseconds 10
        }
        if (-not $alias.lockObserved) { throw 'OUTPUT_ALIAS_LOCK_NOT_OBSERVED: foo LLVM lock was not held while its build was active' }
        $second = Start-LoggedChild -File $compilerPath -Arguments $secondArgs -Description 'c476 alias foo.ll build' -WorkingDirectory $caseDir -StdoutPath $alias.secondStdoutPath -StderrPath $alias.secondStderrPath
        $alias.overlapObserved = -not $first.Process.HasExited
        if (-not $alias.overlapObserved) { throw 'OUTPUT_ALIAS_OVERLAP_NOT_OBSERVED: first build ended before second started' }
        $alias.secondExitCode = Wait-LoggedChild $second
        $alias.firstExitCode = Wait-LoggedChild $first
    } catch {
        $primaryFailure = $_
    }
    $cleanupFailures = [Collections.Generic.List[string]]::new()
    foreach ($child in @($second, $first)) {
        try { Close-LoggedChild $child }
        catch { $cleanupFailures.Add($_.Exception.Message) }
    }
    if ($cleanupFailures.Count -gt 0) {
        $prefix = if ($null -ne $primaryFailure) { "$($primaryFailure.Exception.Message); " } else { '' }
        throw "OUTPUT_ALIAS_CHILD_CLEANUP_FAILED: $prefix$($cleanupFailures -join '; ')"
    }
    if ($null -ne $primaryFailure) { throw $primaryFailure }
    $alias.products = @(Get-ArtifactNames $artifactDir)
    if ($alias.firstExitCode -ne 0) { throw "OUTPUT_ALIAS_ASSERTION_FAILED: foo build exited $($alias.firstExitCode)" }
    if ($alias.secondExitCode -eq 0) { throw 'OUTPUT_ALIAS_ASSERTION_FAILED: foo.ll build published through an active alias lock' }
    if ((Get-Item -LiteralPath $alias.firstStderrPath).Length -ne 0) { throw 'OUTPUT_ALIAS_ASSERTION_FAILED: successful foo build wrote stderr' }
    $secondDiagnostic = [IO.File]::ReadAllText($alias.secondStderrPath)
    if ($secondDiagnostic -notmatch '(?is)sollang:.*(lock|busy|in use|reserved|already)') {
        throw 'OUTPUT_ALIAS_ASSERTION_FAILED: foo.ll collision lacked an actionable stderr diagnostic'
    }
    $aliasExpectedNames = @('foo', 'foo.ll')
    if ($ManagedCompiler) {
        Assert-ManagedCache $artifactDir @('foo', 'foo.ll')
        $aliasExpectedNames += '.sollang-cache'
    }
    Assert-ArtifactNames $alias.products $aliasExpectedNames
    if ((Get-Item -LiteralPath $firstOutput).Length -eq 0 -or (Get-Item -LiteralPath $secondOutput).Length -eq 0) {
        throw 'OUTPUT_ALIAS_ASSERTION_FAILED: a completed final artifact is empty'
    }
    if ([IO.File]::ReadAllText($secondOutput) -notmatch '(?m)^define\s') {
        throw 'OUTPUT_ALIAS_ASSERTION_FAILED: shared final path does not contain complete LLVM'
    }
    Assert-PublishedLlvm $secondOutput $caseDir (Join-Path $caseDir 'llvm-as.stdout.txt') (Join-Path $caseDir 'llvm-as.stderr.txt')
    Assert-ArtifactNames @(Get-ArtifactNames $caseDir) @('artifacts', 'first.stdout.txt', 'first.stderr.txt', 'second.stdout.txt', 'second.stderr.txt', 'llvm-as.stdout.txt', 'llvm-as.stderr.txt')
    Assert-RootSurface $outputPath $focused.Count $true
    $alias.state = 'passed'
    $record.aliasCompleted = 1
    $record.aliasPassed = 1
    Write-Result
}

$activeCase = $null
$activeCaseCounted = $false
$activeAlias = $false
try {
    foreach ($name in $focused) {
        if ((Get-InputFingerprint) -cne $fingerprintStart) { throw 'OUTPUT_INPUT_DRIFT: input changed before case' }
        $case = $record.scenarios[$name]
        $caseDir = Join-Path $outputPath $name
        $artifactDir = Join-Path $caseDir 'artifacts'
        New-ExclusiveOutputDirectory $caseDir
        New-ExclusiveOutputDirectory $artifactDir
        $exe = Join-Path $artifactDir 'probe.exe'
        $ll = "$exe.ll"
        $negative = $name -in @('semanticFailureFresh', 'existingSentinelSemanticFailure')
        $sentinel = $name -ceq 'existingSentinelSemanticFailure'
        $keepTemps = $name -in @('semanticFailureFresh', 'existingSentinelSemanticFailure', 'successKeepTempsOn')
        if ($sentinel) {
            [IO.File]::WriteAllBytes($exe, [Text.Encoding]::ASCII.GetBytes('C476-existing-executable-sentinel'))
            [IO.File]::WriteAllBytes($ll, [Text.Encoding]::ASCII.GetBytes('C476-existing-llvm-sentinel'))
            $exeBefore = Get-Sha $exe; $llBefore = Get-Sha $ll
        }
        $case.buildStdoutPath = Join-Path $caseDir 'build.stdout.txt'
        $case.buildStderrPath = Join-Path $caseDir 'build.stderr.txt'
        Write-Result
        $source = if ($negative) { $negativePath } else { $positivePath }
        $arguments = @('build', $source, '-o', $exe) + @($buildOptions)
        if ($keepTemps) { $arguments += '--keep-temps' }
        $activeCase = $name
        $activeCaseCounted = $false
        $case.exitCode = Invoke-LoggedProcess -File $compilerPath -Arguments $arguments -Description "c476 $name build" -WorkingDirectory $caseDir -StdoutPath $case.buildStdoutPath -StderrPath $case.buildStderrPath
        $case.products = @(Get-ArtifactNames $artifactDir)
        if ($negative) {
            if ($case.exitCode -eq 0) { throw 'OUTPUT_ASSERTION_FAILED: semantic failure exited zero' }
            Assert-EmptyLog $case.buildStdoutPath 'semantic failure stdout'
            $actual = [IO.File]::ReadAllBytes($case.buildStderrPath)
            $expected = [IO.File]::ReadAllBytes($negativeExpectedPath)
            if (-not [Linq.Enumerable]::SequenceEqual($actual, $expected)) { throw 'OUTPUT_ASSERTION_FAILED: semantic stderr bytes differ' }
            $expectedNames = if ($sentinel) { @('probe.exe', 'probe.exe.ll') } else { @() }
            Assert-ArtifactNames $case.products $expectedNames
            if ($sentinel -and ((Get-Sha $exe) -cne $exeBefore -or (Get-Sha $ll) -cne $llBefore)) { throw 'OUTPUT_ASSERTION_FAILED: existing sentinel changed' }
        } else {
            if ($case.exitCode -ne 0) { throw "OUTPUT_ASSERTION_FAILED: successful build exited $($case.exitCode)" }
            if ((Get-Item -LiteralPath $case.buildStderrPath).Length -ne 0) { throw 'OUTPUT_ASSERTION_FAILED: successful build wrote stderr' }
            $expectedNames = @(if ($keepTemps) { 'probe.exe'; 'probe.exe.ll' } else { 'probe.exe' })
            if ($ManagedCompiler) {
                Assert-ManagedCache $artifactDir @('probe')
                $expectedNames += '.sollang-cache'
            }
            Assert-ArtifactNames $case.products $expectedNames
            if ((Get-Item -LiteralPath $exe).Length -eq 0) { throw 'OUTPUT_ASSERTION_FAILED: executable is empty' }
            if ($keepTemps -and ((Get-Item -LiteralPath $ll).Length -eq 0 -or [IO.File]::ReadAllText($ll) -notmatch '(?m)^define\s')) { throw 'OUTPUT_ASSERTION_FAILED: LLVM file is empty or diagnostic-only' }
            if ($keepTemps) {
                Assert-PublishedLlvm $ll $caseDir (Join-Path $caseDir 'llvm-as.stdout.txt') (Join-Path $caseDir 'llvm-as.stderr.txt')
            }
            $case.runStdoutPath = Join-Path $caseDir 'run.stdout.txt'
            $case.runStderrPath = Join-Path $caseDir 'run.stderr.txt'
            $runExit = Invoke-LoggedProcess -File $exe -Arguments @() -Description "c476 $name native run" -WorkingDirectory $caseDir -StdoutPath $case.runStdoutPath -StderrPath $case.runStderrPath
            if ($runExit -ne 0 -or (Get-Item -LiteralPath $case.runStderrPath).Length -ne 0) { throw 'OUTPUT_ASSERTION_FAILED: native execution failed or wrote stderr' }
            if (-not [Linq.Enumerable]::SequenceEqual([IO.File]::ReadAllBytes($case.runStdoutPath), [IO.File]::ReadAllBytes($positiveExpectedPath))) { throw 'OUTPUT_ASSERTION_FAILED: native stdout bytes differ' }
            Assert-ArtifactNames @(Get-ArtifactNames $artifactDir) $expectedNames
        }
        Assert-CaseSurface $outputPath $name (-not $negative) ($keepTemps -and -not $negative) ($record.completed + 1)
        if ((Get-InputFingerprint) -cne $fingerprintStart) { throw 'OUTPUT_INPUT_DRIFT: input changed during case' }
        $case.state = 'passed'; $case.assertionsPassed = $true
        $record.completed++; $record.focusedPassed++
        $activeCaseCounted = $true
        Write-Result
        $activeCase = $null
    }
    if ($RunAliasCollision) {
        if ((Get-InputFingerprint) -cne $fingerprintStart) { throw 'OUTPUT_INPUT_DRIFT: input changed before alias collision case' }
        $activeAlias = $true
        Invoke-AliasCollision
        if ((Get-InputFingerprint) -cne $fingerprintStart) { throw 'OUTPUT_INPUT_DRIFT: input changed during alias collision case' }
        $activeAlias = $false
    }
    $record.inputFingerprintEnd = Get-InputFingerprint
    $record.inputsStable = $record.inputFingerprintStart -ceq $record.inputFingerprintEnd
    if (-not $record.inputsStable) { throw 'OUTPUT_INPUT_DRIFT: final input changed' }
    Assert-RootSurface $outputPath $focused.Count ([bool]$RunAliasCollision)
    $record.state = 'focused-passed'
    Write-Result
    $aliasText = if ($RunAliasCollision) { 'supplemental alias 1/1 passed' } else { 'supplemental alias 0/1 not-run' }
    Write-Host "[c476 output transaction] focused 4/4 passed; original contract 4/13 executed, 9/13 not-run; $aliasText; $resultPath"
} catch {
    $message = $_.Exception.Message
    if ($null -ne $activeCase) {
        $case = $record.scenarios[$activeCase]
        $artifactDir = Join-Path (Join-Path $outputPath $activeCase) 'artifacts'
        if (Test-Path -LiteralPath $artifactDir -PathType Container) { $case.products = @(Get-ArtifactNames $artifactDir) }
        Set-FailedCase $record $activeCase $activeCaseCounted $message
    }
    if ($activeAlias) {
        $record.aliasCollision.state = 'failed'
        $record.aliasCollision.failure = $message
        $record.aliasCompleted = 1
        $record.aliasPassed = 0
        $aliasArtifactDir = Join-Path (Join-Path $outputPath 'aliasCollision') 'artifacts'
        if (Test-Path -LiteralPath $aliasArtifactDir -PathType Container) { $record.aliasCollision.products = @(Get-ArtifactNames $aliasArtifactDir) }
    }
    $record.orphanProcessIds = @($script:orphanProcessIds)
    $record.failureId = if ($message -match '^OUTPUT_[A-Z_]+:') { ($message -split ':')[0] }
        elseif ($message -match 'exceeded the configured verification limit') { 'OUTPUT_PROCESS_TIMEOUT' }
        else { 'OUTPUT_ASSERTION_FAILED' }
    $record.failure = $message
    try {
        $record.inputFingerprintEnd = Get-InputFingerprint
        $record.inputsStable = $record.inputFingerprintStart -ceq $record.inputFingerprintEnd
    } catch { $record.failure += "; end fingerprint failed: $($_.Exception.Message)" }
    $record.state = 'failed'
    Write-Result
    throw
}
