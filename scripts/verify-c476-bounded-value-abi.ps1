[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ManagedTargetCompiler,
    [string]$SelfhostTargetCompiler,
    [string]$OutputDirectory,
    [ValidateRange(1000, 3600000)][int]$TimeoutMilliseconds = 180000,
    [switch]$SelfTest,
    [switch]$ValidateInputsOnly,
    [switch]$Run
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ([int]$SelfTest.IsPresent + [int]$ValidateInputsOnly.IsPresent + [int]$Run.IsPresent -ne 1) {
    throw 'C476_ABI_MODE_REQUIRED: choose exactly one of -SelfTest, -ValidateInputsOnly, or -Run'
}
$verificationProcess = Join-Path $PSScriptRoot 'verification-process.ps1'
. $verificationProcess
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$rootPrefix = $root.TrimEnd([char]'\', [char]'/') + [IO.Path]::DirectorySeparatorChar
$contractPath = Join-Path $PSScriptRoot 'contracts/c476-bounded-value-abi.json'
$schemaPath = Join-Path $PSScriptRoot 'contracts/c476-bounded-value-abi.schema.json'
$script:resultSchema = Join-Path $PSScriptRoot 'contracts/c476-bounded-value-abi-result.schema.json'

function Resolve-Input([string]$Path) {
    $full = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $root $Path)) }
    if (-not $full.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "C476_ABI_OUTSIDE_REPOSITORY: $full"
    }
    $cursor = [IO.Path]::GetPathRoot($full)
    foreach ($part in ($full.Substring($cursor.Length) -split '[\\/]')) {
        if (-not $part) { continue }
        $cursor = Join-Path $cursor $part
        if (-not (Test-Path -LiteralPath $cursor)) { break }
        if (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "C476_ABI_REPARSE_PATH: $cursor"
        }
    }
    return (Resolve-Path -LiteralPath $full -ErrorAction Stop).ProviderPath
}
function Get-Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Assert-ManagedStdlibRoot($Contract) {
    # Managed CompilerApp discovers stdlib from the source repository root;
    # its build command has no --stdlib override. Keep the fingerprint aligned.
    $managedStdlib = Resolve-Input (Join-Path $root 'stdlib')
    $contractStdlib = Resolve-Input $Contract.build.stdlibRoot
    if (-not [string]::Equals($contractStdlib, $managedStdlib, [StringComparison]::OrdinalIgnoreCase)) {
        throw "C476_ABI_STDLIB_ROOT_MISMATCH: Managed uses $managedStdlib but contract selects $contractStdlib"
    }
}
function Assert-Pin([string]$Path, [string]$Expected) {
    $resolved = Resolve-Input $Path
    if ((Get-Sha $resolved) -cne $Expected) { throw "C476_ABI_SHA_MISMATCH: $resolved" }
    return $resolved
}
function Get-Contract {
    $json = Get-Content -LiteralPath $contractPath -Raw
    if (-not (Test-Json -Json $json -SchemaFile $schemaPath -ErrorAction SilentlyContinue)) {
        throw 'C476_ABI_SCHEMA_REJECTED'
    }
    return ($json | ConvertFrom-Json -Depth 30)
}
function Assert-BaselinePins($Contract) {
    $managed = Assert-Pin $Contract.managedCompiler.path $Contract.managedCompiler.sha256
    $managedDirectory = Split-Path -Parent $managed
    [void](Assert-Pin (Join-Path $managedDirectory 'Sollang.Compiler.dll') $Contract.managedCompiler.dllSha256)
    [void](Assert-Pin (Join-Path $managedDirectory 'Sollang.Compiler.deps.json') $Contract.managedCompiler.depsSha256)
    [void](Assert-Pin (Join-Path $managedDirectory 'Sollang.Compiler.runtimeconfig.json') $Contract.managedCompiler.runtimeConfigSha256)
    [void](Assert-Pin $Contract.selfhostBaseline.path $Contract.selfhostBaseline.sha256)
    foreach ($case in $Contract.cases) {
        [void](Assert-Pin $case.source $case.sourceSha256)
        if ($null -ne $case.expected) { [void](Assert-Pin $case.expected $case.expectedSha256) }
    }
    $crash = $Contract.cases[8]
    $logDirectory = Resolve-Input $crash.managedBaseline.logs
    $logPins = @{
        'build.stdout.txt' = $crash.managedBaseline.buildStdoutSha256
        'build.stderr.txt' = $crash.managedBaseline.buildStderrSha256
        'probe.ll' = $crash.managedBaseline.llvmSha256
        'probe.exe' = $crash.managedBaseline.exeSha256
        'run1.stdout.txt' = $crash.managedBaseline.runStdoutSha256
        'run2.stdout.txt' = $crash.managedBaseline.runStdoutSha256
        'run1.stderr.txt' = $crash.managedBaseline.runStderrSha256
        'run2.stderr.txt' = $crash.managedBaseline.runStderrSha256
        'run-exits.json' = $crash.managedBaseline.runExitsSha256
    }
    foreach ($name in $logPins.Keys) { [void](Assert-Pin (Join-Path $logDirectory $name) $logPins[$name]) }
    $exits = Get-Content -LiteralPath (Join-Path $logDirectory 'run-exits.json') -Raw | ConvertFrom-Json
    if ($exits.compilerSha256 -cne $Contract.managedCompiler.sha256 -or
        $exits.buildExitCode -ne 0 -or $exits.run1ExitCode -ne -1073740940 -or
        $exits.run2ExitCode -ne -1073740940 -or $exits.fixture -cne $crash.source) {
        throw 'C476_ABI_BASELINE_EXIT_RECORD_MISMATCH'
    }
}
function Get-InputFingerprint($Contract, [string]$ManagedTarget, [string]$SelfhostTarget) {
    $paths = [Collections.Generic.List[string]]::new()
    foreach ($path in @($PSCommandPath, $verificationProcess, (Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1'), $contractPath, $schemaPath, $script:resultSchema, $Contract.managedCompiler.path, $Contract.selfhostBaseline.path)) {
        $paths.Add((Resolve-Input $path))
    }
    $managedDirectory = Split-Path -Parent (Resolve-Input $Contract.managedCompiler.path)
    foreach ($name in 'Sollang.Compiler.dll', 'Sollang.Compiler.deps.json', 'Sollang.Compiler.runtimeconfig.json') {
        $paths.Add((Resolve-Input (Join-Path $managedDirectory $name)))
    }
    foreach ($case in $Contract.cases) {
        $paths.Add((Resolve-Input $case.source))
        if ($null -ne $case.expected) { $paths.Add((Resolve-Input $case.expected)) }
    }
    $logDirectory = Resolve-Input $Contract.cases[8].managedBaseline.logs
    foreach ($name in 'build.stdout.txt', 'build.stderr.txt', 'probe.ll', 'probe.exe', 'run1.stdout.txt', 'run2.stdout.txt', 'run1.stderr.txt', 'run2.stderr.txt', 'run-exits.json') {
        $paths.Add((Resolve-Input (Join-Path $logDirectory $name)))
    }
    foreach ($path in @($ManagedTarget, $SelfhostTarget)) {
        if ($path) { $paths.Add((Resolve-Input $path)) }
    }
    if ($ManagedTarget) {
        $targetDirectory = Split-Path -Parent (Resolve-Input $ManagedTarget)
        foreach ($name in 'Sollang.Compiler.dll', 'Sollang.Compiler.deps.json', 'Sollang.Compiler.runtimeconfig.json') {
            $paths.Add((Resolve-Input (Join-Path $targetDirectory $name)))
        }
    }
    foreach ($name in 'clang.exe', 'llvm-as.exe', 'lld-link.exe', 'llvm-ar.exe') {
        $paths.Add((Resolve-Input (Join-Path $Contract.build.llvmRoot "bin/$name")))
    }
    $stdlib = Resolve-Input $Contract.build.stdlibRoot
    $stdlibFiles = @(Get-ChildItem -LiteralPath $stdlib -Recurse -File -Filter '*.slg' | Sort-Object FullName)
    if ($stdlibFiles.Count -eq 0) { throw 'C476_ABI_STDLIB_EMPTY' }
    foreach ($file in $stdlibFiles) { $paths.Add((Resolve-Input $file.FullName)) }
    $entries = @($paths | Sort-Object -Unique | ForEach-Object { "$_|$(Get-Sha $_)" })
    $bytes = [Text.Encoding]::UTF8.GetBytes(($entries -join "`n") + "`n")
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
}
function Get-LiveDescendants([int]$RootId, [datetime]$RootCreatedUtc, [object[]]$Records) {
    $seen = [Collections.Generic.HashSet[int]]::new()
    $created = [Collections.Generic.Dictionary[int, datetime]]::new()
    $created.Add($RootId, $RootCreatedUtc)
    $frontier = @($RootId)
    while ($frontier.Count -gt 0) {
        $next = @()
        foreach ($record in $Records) {
            $id = [int]$record.ProcessId
            $parent = [int]$record.ParentProcessId
            if ($frontier -contains $parent -and $id -ne $RootId -and -not $seen.Contains($id)) {
                if ($null -eq $record.CreationDate) { throw "C476_ABI_PROCESS_IDENTITY_MISSING: $id" }
                $childCreatedUtc = ([datetime]$record.CreationDate).ToUniversalTime()
                if ($childCreatedUtc -ge $created[$parent]) {
                    [void]$seen.Add($id)
                    $created.Add($id, $childCreatedUtc)
                    $next += $id
                }
            }
        }
        $frontier = $next
    }
    return @($seen | Sort-Object)
}
function Invoke-GateProcess([string]$File, [string[]]$Arguments, [string]$Cwd, [string]$Label, [string]$Out, [string]$Err) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $File; $start.WorkingDirectory = $Cwd
    $start.UseShellExecute = $false; $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new(); $process.StartInfo = $start
    $stdout = [IO.File]::Create($Out); $stderr = [IO.File]::Create($Err)
    $started = $false
    try {
        if (-not $process.Start()) { throw "C476_ABI_SPAWN_FAILED: $Label" }
        $started = $true
        try { $rootCreatedUtc = $process.StartTime.ToUniversalTime() }
        catch { throw "C476_ABI_PROCESS_IDENTITY_FAILED: $Label" }
        $outCopy = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
        $errCopy = $process.StandardError.BaseStream.CopyToAsync($stderr)
        $waitError = $null
        try { Wait-VerificationProcess -Process $process -Description $Label -TimeoutMilliseconds $TimeoutMilliseconds }
        catch { $waitError = $_ }
        if (-not $process.WaitForExit(0)) {
            try { $process.Kill($true) } catch { try { $process.Kill() } catch { } }
            if (-not $process.WaitForExit(5000)) {
                [void]$script:orphans.Add($process.Id)
                throw "C476_ABI_ROOT_SURVIVED: $($process.Id)"
            }
        }
        try { $descendants = @(Get-LiveDescendants $process.Id $rootCreatedUtc @(Get-CimInstance Win32_Process -ErrorAction Stop)) }
        catch { throw "C476_ABI_PROCESS_INSPECTION_FAILED: $($_.Exception.Message)" }
        if ($descendants.Count -gt 0) {
            foreach ($id in $descendants) { [void]$script:orphans.Add($id) }
            throw "C476_ABI_LIVE_DESCENDANTS: $($descendants -join ',')"
        }
        $drain = [Threading.Tasks.Task]::WhenAll([Threading.Tasks.Task[]]@($outCopy, $errCopy))
        if (-not $drain.Wait(5000)) { throw "C476_ABI_LOG_DRAIN_TIMEOUT: $Label" }
        $drain.GetAwaiter().GetResult(); $stdout.Flush(); $stderr.Flush()
        if ($null -ne $waitError) { throw $waitError }
        return $process.ExitCode
    } finally {
        if ($started -and -not $process.WaitForExit(0)) {
            try { $process.Kill($true) } catch { try { $process.Kill() } catch { } }
            if (-not $process.WaitForExit(5000)) { [void]$script:orphans.Add($process.Id) }
        }
        $process.Dispose(); $stdout.Dispose(); $stderr.Dispose()
    }
}
function Assert-NoWarnings([string]$Text, [string]$Label) {
    if ($Text -match '(?im)^\s*(?:warning(?:\s|:)|note(?:\s|:)|sollang:\s*(?:warning|note)(?:\s|:))') {
        throw "C476_ABI_WARNING_OR_NOTE: $Label"
    }
}
function Test-BytesEqual([byte[]]$Left, [byte[]]$Right) {
    if ($Left.Length -ne $Right.Length) { return $false }
    for ($index = 0; $index -lt $Left.Length; $index++) {
        if ($Left[$index] -ne $Right[$index]) { return $false }
    }
    return $true
}
function Test-PositiveBuildStdout([string]$Text, [string]$Compiler, [string]$Exe, [string]$Ll) {
    $lines = @($Text.TrimEnd("`r", "`n") -split "`r?`n")
    if ($Compiler -ceq 'selfhost') {
        return $lines.Count -eq 2 -and $lines[0] -ceq "Kept $Ll" -and $lines[1] -ceq "Wrote $Exe"
    }
    $wrote = '^Wrote ' + [regex]::Escape($Exe) + ' \(([0-9][0-9,]*) bytes\)$'
    if ($lines[-1] -cnotmatch $wrote) { return $false }
    if ([long]($Matches[1] -replace ',', '') -ne (Get-Item -LiteralPath $Exe).Length) { return $false }
    if ($lines.Count -gt 1) {
        foreach ($line in $lines[0..($lines.Count - 2)]) {
            if ($line -cnotmatch '^\[(?:frontend|codegen|semantic|product)-cache\] ' -and
                $line -cnotmatch '^\[native [1-9][0-9]*/[1-9][0-9]*\] optimized partition$') { return $false }
        }
    }
    return $true
}
function Assert-SelfhostDiagnosticCounts([string]$Source, [System.Collections.IDictionary]$Case, [int]$ExpectedSemantic, [int]$ExpectedIr) {
    $countsOut = Join-Path $Case.caseDirectory 'diagnostic-counts.stdout.txt'
    $countsErr = Join-Path $Case.caseDirectory 'diagnostic-counts.stderr.txt'
    $countsExit = Invoke-GateProcess $script:selfhostPath @('diagnostic-counts', $Source) $Case.caseDirectory "$($Case.fixture) diagnostic-counts" $countsOut $countsErr
    $countsText = [IO.File]::ReadAllText($countsOut)
    $detailsText = [IO.File]::ReadAllText($countsErr)
    $total = $ExpectedSemantic + $ExpectedIr
    if ($countsExit -ne 0 -or $countsText -cnotmatch "^checked diagnostics = $total\r?\n$" -or
        $detailsText -cnotmatch "^semantic diagnostics = $ExpectedSemantic\r?\nir diagnostics = $ExpectedIr\r?\n$") {
        throw "C476_ABI_DIAGNOSTIC_PHASE_MISMATCH: $($Case.fixture)"
    }
    $Case.semanticCount = $ExpectedSemantic; $Case.irCount = $ExpectedIr
}
function Test-NegativeBuildBoundary([string]$Compiler, [int]$ExitCode, [string]$Stdout, [string]$Stderr, [string]$Expected, [bool]$ProductsAbsent) {
    if ($ExitCode -ne 1 -or $Stdout.Length -ne 0 -or
        -not $Stderr.Contains($Expected, [StringComparison]::Ordinal) -or -not $ProductsAbsent) {
        return $false
    }
    if ($Compiler -ceq 'managed') {
        return $Stderr -match '(?m)^sollang: semantic error\b'
    }
    if ($Compiler -ceq 'selfhost') { return $true }
    throw "C476_ABI_UNKNOWN_COMPILER: $Compiler"
}
function Write-GateResult {
    $json = $script:record | ConvertTo-Json -Depth 16
    if (-not (Test-Json -Json $json -SchemaFile $script:resultSchema -ErrorAction SilentlyContinue)) {
        throw 'C476_ABI_RESULT_SCHEMA_REJECTED'
    }
    $target = Join-Path $script:outputPath 'result.json'
    $temporary = "$target.tmp-$PID-$([guid]::NewGuid().ToString('N'))"
    $backup = "$target.backup-$PID-$([guid]::NewGuid().ToString('N'))"
    [IO.File]::WriteAllText($temporary, $json + "`n", [Text.UTF8Encoding]::new($false))
    try {
        if (Test-Path -LiteralPath $target -PathType Leaf) {
            [IO.File]::Replace($temporary, $target, $backup)
            if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force }
        } else { [IO.File]::Move($temporary, $target) }
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
}

$contract = Get-Contract
if ($SelfTest) {
    Assert-ManagedStdlibRoot $contract
    $badStdlib = (Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json -Depth 30)
    $badStdlib.build.stdlibRoot = 'scripts'
    try { Assert-ManagedStdlibRoot $badStdlib; throw 'C476_ABI_SELFTEST_STDLIB_MISMATCH_ACCEPTED' }
    catch {
        if ($_.Exception.Message -like '*SELFTEST_STDLIB_MISMATCH_ACCEPTED*' -or
            $_.Exception.Message -notlike 'C476_ABI_STDLIB_ROOT_MISMATCH:*') { throw }
    }
    $good = Get-Content -LiteralPath $contractPath -Raw
    $badHash = $good | ConvertFrom-Json -Depth 30
    $badHash.cases[0].sourceSha256 = 'invalid'
    $badClass = $good | ConvertFrom-Json -Depth 30
    $badClass.cases[8].classification = 'positive'
    $badCount = $good | ConvertFrom-Json -Depth 30
    $badCount.cases = @($badCount.cases | Select-Object -First 8)
    $badInference = $good | ConvertFrom-Json -Depth 30
    $badInference.cases[8].inferredTarget.verified = $true
    foreach ($mutation in @($badHash, $badClass, $badCount, $badInference)) {
        $json = $mutation | ConvertTo-Json -Depth 30
        if (Test-Json -Json $json -SchemaFile $schemaPath -ErrorAction SilentlyContinue) {
            throw 'C476_ABI_SELFTEST_MUTATION_ACCEPTED'
        }
    }
    try { [void](Resolve-Input '../outside.slg'); throw 'C476_ABI_SELFTEST_TRAVERSAL_ACCEPTED' }
    catch { if ($_.Exception.Message -like '*TRAVERSAL_ACCEPTED*') { throw } }
    $sampleCase = [ordered]@{
        compiler = 'managed'; fixture = 'direct-populated'; classification = 'positive'
        state = 'passed'; caseDirectory = 'scratch-case'; sourceSha256 = ('A' * 64)
        expectedSha256 = ('A' * 64); buildExitCode = 0
        buildStdoutSha256 = ('A' * 64); buildStderrSha256 = ('A' * 64)
        diagnosticPhase = 'accepted-build'; semanticCount = $null; irCount = $null
        diagnosticMatched = $null; productsAbsent = $null; closureExitCode = 0
        llvmAsExitCode = 0; runExitCode = 0; llvmSha256 = ('A' * 64)
        bitcodeSha256 = ('A' * 64); exeSha256 = ('A' * 64)
        stdoutSha256 = ('A' * 64); stdoutMatched = $true
        llvmObservation = [ordered]@{
            wholeModuleSha256 = ('A' * 64)
            userFunctionScope = 'not-yet-isolated;whole-module-assembly-only'
            stackPointerEscapeProvenAbsent = $false; lifetimeProven = $false
        }; failure = $null
    }
    $sample = [ordered]@{
        schemaVersion = 1; gate = 'c476-bounded-value-abi-target'; state = 'passed'
        total = 18; completed = 18; passed = 18
        managedTargetSha256 = ('A' * 64); managedTargetDllSha256 = ('A' * 64)
        selfhostTargetSha256 = ('A' * 64)
        inputFingerprintStart = ('A' * 64); inputFingerprintEnd = ('A' * 64)
        inputsStable = $true; historicalBaselineReexecuted = $false
        processObservationScope = 'bounded-root-wait-and-post-exit-CIM-descendant-snapshot-with-creation-time;exited-or-reparented-descendants-not-proven'
        proofScope = 'partial'; orphanProcessIds = @()
        cases = @(1..18 | ForEach-Object { $sampleCase }); failureId = $null; failure = $null
    }
    $sampleText = $sample | ConvertTo-Json -Depth 16
    if (-not (Test-Json -Json $sampleText -SchemaFile $script:resultSchema -ErrorAction SilentlyContinue)) {
        throw 'C476_ABI_SELFTEST_RESULT_SCHEMA_REJECTED'
    }
    foreach ($mutation in @('historicalBaselineReexecuted', 'orphanProcessIds', 'completed')) {
        $bad = $sampleText | ConvertFrom-Json -Depth 16
        if ($mutation -eq 'historicalBaselineReexecuted') { $bad.historicalBaselineReexecuted = $true }
        if ($mutation -eq 'orphanProcessIds') { $bad.orphanProcessIds = @(123) }
        if ($mutation -eq 'completed') { $bad.completed = 17 }
        if (Test-Json -Json ($bad | ConvertTo-Json -Depth 16) -SchemaFile $script:resultSchema -ErrorAction SilentlyContinue) {
            throw "C476_ABI_SELFTEST_RESULT_MUTATION_ACCEPTED: $mutation"
        }
    }
    $rawDiagnostic = 'owned container values must be created directly at their binding site in the current slice'
    if (-not (Test-NegativeBuildBoundary 'selfhost' 1 '' $rawDiagnostic $rawDiagnostic $true) -or
        (Test-NegativeBuildBoundary 'managed' 1 '' $rawDiagnostic $rawDiagnostic $true) -or
        -not (Test-NegativeBuildBoundary 'managed' 1 '' "sollang: semantic error: $rawDiagnostic" $rawDiagnostic $true) -or
        (Test-NegativeBuildBoundary 'selfhost' 0 '' $rawDiagnostic $rawDiagnostic $true) -or
        (Test-NegativeBuildBoundary 'selfhost' 2 '' $rawDiagnostic $rawDiagnostic $true) -or
        (Test-NegativeBuildBoundary 'selfhost' 1 '' $rawDiagnostic 'wrong diagnostic' $true) -or
        (Test-NegativeBuildBoundary 'selfhost' 1 '' $rawDiagnostic $rawDiagnostic $false)) {
        throw 'C476_ABI_SELFTEST_NEGATIVE_BOUNDARY_FAILED'
    }
    [pscustomobject]@{ state = 'passed'; contractSchema = $true; resultSchema = $true; rejectedMutations = 4; rejectedResultMutations = 3; rejectedTraversal = $true; rejectedStdlibMismatch = $true; negativeBoundaryControls = 7 }
    return
}

Assert-BaselinePins $contract
Assert-ManagedStdlibRoot $contract
if ($Run) {
    if (-not $ManagedTargetCompiler -or -not $SelfhostTargetCompiler -or -not $OutputDirectory) {
        throw 'C476_ABI_RUN_ARGUMENTS_REQUIRED: target compilers and output directory'
    }
}
$start = Get-InputFingerprint $contract $ManagedTargetCompiler $SelfhostTargetCompiler
$managedTargetSha = if ($ManagedTargetCompiler) { Get-Sha (Resolve-Input $ManagedTargetCompiler) } else { $null }
$managedTargetDllSha = if ($ManagedTargetCompiler) { Get-Sha (Resolve-Input (Join-Path (Split-Path -Parent (Resolve-Input $ManagedTargetCompiler)) 'Sollang.Compiler.dll')) } else { $null }
$selfhostTargetSha = if ($SelfhostTargetCompiler) { Get-Sha (Resolve-Input $SelfhostTargetCompiler) } else { $null }
$end = Get-InputFingerprint $contract $ManagedTargetCompiler $SelfhostTargetCompiler
if ($start -cne $end) { throw 'C476_ABI_INPUT_DRIFT' }
if ($ValidateInputsOnly) {
    [pscustomobject]@{
        state = 'validated'; gate = $contract.gate; cases = $contract.caseCount
        positive = $contract.positiveCount; semanticNegative = $contract.semanticNegativeCount
        baselineFailing = $contract.baselineFailingCount
        managedBaselineSha256 = $contract.managedCompiler.sha256
        selfhostBaselineSha256 = $contract.selfhostBaseline.sha256
        managedTargetSha256 = $managedTargetSha; managedTargetDllSha256 = $managedTargetDllSha
        selfhostTargetSha256 = $selfhostTargetSha
        inputFingerprintStart = $start; inputFingerprintEnd = $end; inputsStable = $true
    } | ConvertTo-Json -Depth 6
    return
}

$script:outputPath = [IO.Path]::GetFullPath($OutputDirectory)
$scratchRoot = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
$scratchPrefix = $scratchRoot.TrimEnd([char]'\', [char]'/') + [IO.Path]::DirectorySeparatorChar
if (-not $outputPath.StartsWith($scratchPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "C476_ABI_OUTPUT_OUTSIDE_SCRATCH: $outputPath"
}
[void](Resolve-Input (Split-Path -Parent $outputPath))
if (Test-Path -LiteralPath $outputPath) { throw "C476_ABI_OUTPUT_EXISTS: $outputPath" }
$managedPath = Resolve-Input $ManagedTargetCompiler
$script:selfhostPath = Resolve-Input $SelfhostTargetCompiler
$assembler = Resolve-Input (Join-Path $contract.build.llvmRoot 'bin/llvm-as.exe')
$llvmRoot = Resolve-Input $contract.build.llvmRoot
$stdlibRoot = Resolve-Input $contract.build.stdlibRoot
$closure = Resolve-Input (Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1')
$pwsh = (Get-Process -Id $PID).Path
if (-not $pwsh) { throw 'C476_ABI_PWSH_PATH_MISSING' }
[void][IO.Directory]::CreateDirectory($outputPath)
$script:orphans = [Collections.Generic.HashSet[int]]::new()
$cases = @()
foreach ($compiler in @('managed', 'selfhost')) {
    foreach ($fixture in $contract.cases) {
        $cases += [ordered]@{
            compiler = $compiler; fixture = $fixture.id; classification = $fixture.classification
            state = 'not-run'; caseDirectory = (Join-Path $outputPath "$compiler-$($fixture.id)")
            sourceSha256 = $fixture.sourceSha256; expectedSha256 = $fixture.expectedSha256
            buildExitCode = $null; buildStdoutSha256 = $null; buildStderrSha256 = $null
            diagnosticPhase = 'not-run'; semanticCount = $null; irCount = $null
            diagnosticMatched = $null; productsAbsent = $null
            closureExitCode = $null; llvmAsExitCode = $null; runExitCode = $null
            llvmSha256 = $null; bitcodeSha256 = $null; exeSha256 = $null
            stdoutSha256 = $null; stdoutMatched = $null; llvmObservation = $null; failure = $null
        }
    }
}
$script:record = [ordered]@{
    schemaVersion = 1; gate = 'c476-bounded-value-abi-target'; state = 'running'
    total = 18; completed = 0; passed = 0
    managedTargetSha256 = $managedTargetSha; managedTargetDllSha256 = $managedTargetDllSha
    selfhostTargetSha256 = $selfhostTargetSha
    inputFingerprintStart = $start; inputFingerprintEnd = $null; inputsStable = $false
    historicalBaselineReexecuted = $false
    processObservationScope = 'bounded-root-wait-and-post-exit-CIM-descendant-snapshot-with-creation-time;exited-or-reparented-descendants-not-proven'
    proofScope = 'LLVM assembly and native exact output are checked; no static pointer chain or lifetime proof is claimed.'
    orphanProcessIds = @(); cases = $cases; failureId = $null; failure = $null
}
Write-GateResult
$activeCase = $null
try {
    for ($index = 0; $index -lt $cases.Count; $index++) {
        if ((Get-InputFingerprint $contract $ManagedTargetCompiler $SelfhostTargetCompiler) -cne $start) {
            throw 'C476_ABI_INPUT_DRIFT: before case'
        }
        $case = $cases[$index]
        $activeCase = $case
        $fixture = $contract.cases[$index % $contract.caseCount]
        [void][IO.Directory]::CreateDirectory($case.caseDirectory)
        $case.state = 'running'; Write-GateResult
        $source = Resolve-Input $fixture.source
        $exe = Join-Path $case.caseDirectory 'probe.exe'
        $ll = if ($case.compiler -ceq 'managed') { Join-Path $case.caseDirectory 'probe.ll' } else { "$exe.ll" }
        $bc = Join-Path $case.caseDirectory 'probe.bc'
        $compilerFile = if ($case.compiler -ceq 'managed') { $managedPath } else { $selfhostPath }
        $arguments = @('build', $source, '-o', $exe, '--target', 'windows-x64', '--llvm', $llvmRoot)
        if ($case.compiler -ceq 'selfhost') { $arguments += @('--stdlib', $stdlibRoot, '--jobs', '1') }
        $arguments += @('-O1', '--keep-temps')
        $buildOut = Join-Path $case.caseDirectory 'build.stdout.txt'
        $buildErr = Join-Path $case.caseDirectory 'build.stderr.txt'
        $case.buildExitCode = Invoke-GateProcess $compilerFile $arguments $case.caseDirectory "$($case.compiler) $($case.fixture) build" $buildOut $buildErr
        $case.buildStdoutSha256 = Get-Sha $buildOut
        $case.buildStderrSha256 = Get-Sha $buildErr
        $buildStdout = [IO.File]::ReadAllText($buildOut)
        $buildStderr = [IO.File]::ReadAllText($buildErr)
        Assert-NoWarnings ($buildStdout + $buildStderr) "$($case.compiler) $($case.fixture) build"
        if ($case.classification -ceq 'semantic-negative') {
            $expected = [IO.File]::ReadAllText((Resolve-Input $fixture.expected)).TrimEnd("`r", "`n")
            $case.diagnosticMatched = $buildStderr.Contains($expected, [StringComparison]::Ordinal)
            $case.diagnosticPhase = 'failed'
            $case.productsAbsent = @((Get-ChildItem -LiteralPath $case.caseDirectory -Force | Where-Object { $_.Name -cnotin @('build.stdout.txt', 'build.stderr.txt') })).Count -eq 0
            if (-not (Test-NegativeBuildBoundary $case.compiler $case.buildExitCode $buildStdout $buildStderr $expected $case.productsAbsent)) {
                throw "C476_ABI_NEGATIVE_MISMATCH: $($case.compiler) $($case.fixture)"
            }
            if ($case.compiler -ceq 'selfhost') {
                Assert-SelfhostDiagnosticCounts $source $case 1 0
            }
            $case.diagnosticPhase = 'semantic'
        } else {
            if ($case.buildExitCode -ne 0 -or $buildStderr.Length -ne 0 -or
                -not (Test-Path -LiteralPath $exe -PathType Leaf) -or -not (Test-Path -LiteralPath $ll -PathType Leaf)) {
                throw "C476_ABI_POSITIVE_BUILD_FAILED: $($case.compiler) $($case.fixture) exit=$($case.buildExitCode) stderr=$buildStderr"
            }
            if (-not (Test-PositiveBuildStdout $buildStdout $case.compiler $exe $ll)) {
                throw "C476_ABI_BUILD_STDOUT_MISMATCH: $($case.compiler) $($case.fixture)"
            }
            $case.diagnosticPhase = 'accepted-build'
            if ($case.compiler -ceq 'selfhost') { Assert-SelfhostDiagnosticCounts $source $case 0 0 }
            $case.llvmSha256 = Get-Sha $ll
            $case.llvmObservation = [ordered]@{
                wholeModuleSha256 = $case.llvmSha256
                userFunctionScope = 'not-yet-isolated;whole-module-assembly-only'
                stackPointerEscapeProvenAbsent = $false; lifetimeProven = $false
            }
            $closureOut = Join-Path $case.caseDirectory 'closure.stdout.txt'
            $closureErr = Join-Path $case.caseDirectory 'closure.stderr.txt'
            $case.closureExitCode = Invoke-GateProcess $pwsh @('-NoProfile', '-File', $closure, '-LlvmPath', $ll) $case.caseDirectory "$($case.compiler) $($case.fixture) closure" $closureOut $closureErr
            $closureText = [IO.File]::ReadAllText($closureOut).TrimEnd("`r", "`n")
            if ($case.closureExitCode -ne 0 -or $closureText -cne "[LLVM direct-call closure] PASS $ll" -or
                (Get-Item -LiteralPath $closureErr).Length -ne 0) {
                throw "C476_ABI_CLOSURE_FAILED: $($case.compiler) $($case.fixture)"
            }
            $asOut = Join-Path $case.caseDirectory 'llvm-as.stdout.txt'
            $asErr = Join-Path $case.caseDirectory 'llvm-as.stderr.txt'
            $case.llvmAsExitCode = Invoke-GateProcess $assembler @($ll, '-o', $bc) $case.caseDirectory "$($case.compiler) $($case.fixture) llvm-as" $asOut $asErr
            if ($case.llvmAsExitCode -ne 0 -or (Get-Item -LiteralPath $asOut).Length -ne 0 -or
                (Get-Item -LiteralPath $asErr).Length -ne 0) {
                throw "C476_ABI_LLVM_AS_FAILED: $($case.compiler) $($case.fixture)"
            }
            $case.bitcodeSha256 = Get-Sha $bc
            $runOut = Join-Path $case.caseDirectory 'run.stdout.txt'
            $runErr = Join-Path $case.caseDirectory 'run.stderr.txt'
            $case.runExitCode = Invoke-GateProcess $exe @() $case.caseDirectory "$($case.compiler) $($case.fixture) native" $runOut $runErr
            $expectedBytes = if ($case.classification -ceq 'baseline-failing') {
                [Text.Encoding]::UTF8.GetBytes($fixture.inferredTarget.stdout)
            } else { [IO.File]::ReadAllBytes((Resolve-Input $fixture.expected)) }
            $case.stdoutMatched = Test-BytesEqual ([IO.File]::ReadAllBytes($runOut)) $expectedBytes
            if ($case.runExitCode -ne 0 -or (Get-Item -LiteralPath $runErr).Length -ne 0 -or -not $case.stdoutMatched) {
                throw "C476_ABI_NATIVE_OUTPUT_MISMATCH: $($case.compiler) $($case.fixture) exit=$($case.runExitCode)"
            }
            $case.exeSha256 = Get-Sha $exe
            $case.stdoutSha256 = Get-Sha $runOut
        }
        $case.state = 'passed'; $record.completed++; $record.passed++
        Write-GateResult
    }
    $record.inputFingerprintEnd = Get-InputFingerprint $contract $ManagedTargetCompiler $SelfhostTargetCompiler
    $record.inputsStable = $record.inputFingerprintStart -ceq $record.inputFingerprintEnd
    if (-not $record.inputsStable) { throw 'C476_ABI_INPUT_DRIFT: after cases' }
    $record.orphanProcessIds = @($script:orphans | Sort-Object)
    if ($record.orphanProcessIds.Count -ne 0) { throw 'C476_ABI_PROCESS_ORPHANED' }
    $record.state = 'passed'; Write-GateResult
    Write-Output "C476_ABI_TARGET_PASS: 18/18 exact target cases; $(Join-Path $outputPath 'result.json')"
} catch {
    $message = $_.Exception.Message
    if ($null -ne $activeCase -and $activeCase.state -ceq 'running') {
        $activeCase.state = 'failed'; $activeCase.failure = $message; $record.completed++
    }
    $record.orphanProcessIds = @($script:orphans | Sort-Object)
    $record.failureId = if ($script:orphans.Count -gt 0) { 'C476_ABI_PROCESS_ORPHANED' }
        elseif ($message -match '^C476_ABI_[A-Z_]+') { ($message -split ':')[0] }
        else { 'C476_ABI_GATE_FAILED' }
    $record.failure = $message
    try {
        $record.inputFingerprintEnd = Get-InputFingerprint $contract $ManagedTargetCompiler $SelfhostTargetCompiler
        $record.inputsStable = $record.inputFingerprintStart -ceq $record.inputFingerprintEnd
    } catch { $record.failure += "; end fingerprint failed: $($_.Exception.Message)" }
    $record.state = 'failed'; Write-GateResult
    throw
}
