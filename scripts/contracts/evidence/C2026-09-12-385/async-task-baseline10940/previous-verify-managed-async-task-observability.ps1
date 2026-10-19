[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCompilerSha256,
    [string]$OutputDirectory = '',
    [switch]$ValidateInputsOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$Compiler = (Resolve-Path -LiteralPath $Compiler).Path
$ExpectedCompilerSha256 = $ExpectedCompilerSha256.ToUpperInvariant()
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $root ('artifacts/scratch/async-task-observability-managed-' + [Guid]::NewGuid().ToString('N'))
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null

$contractPath = Join-Path $root 'scripts/contracts/async-task-observability.json'
$schemaPath = Join-Path $root 'scripts/contracts/async-task-observability-managed-result.schema.json'
$closurePath = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$verificationProcessPath = Join-Path $root 'scripts/verification-process.ps1'
$auditShim = Join-Path $root 'tests/native-interop/owned_array_audit.c'
$llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
$llvmAs = Join-Path $llvmRoot 'bin/llvm-as.exe'
$clang = Join-Path $llvmRoot 'bin/clang.exe'
$contract = [IO.File]::ReadAllText($contractPath) | ConvertFrom-Json
$cases = @($contract.focusedInitialGate.cases)

function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function HashMap([hashtable]$Paths) {
    $map = [ordered]@{}
    foreach ($entry in $Paths.GetEnumerator() | Sort-Object Key) { $map[$entry.Key] = Hash $entry.Value }
    $map
}
function MapsEqual($Left, $Right) { ($Left | ConvertTo-Json -Compress) -ceq ($Right | ConvertTo-Json -Compress) }
function BytesEqual([byte[]]$Left, [byte[]]$Right) {
    if ($Left.Length -ne $Right.Length) { return $false }
    [Convert]::ToHexString($Left) -ceq [Convert]::ToHexString($Right)
}
function Get-LiveDescendants([int]$RootProcessId) {
    if (-not $IsWindows) { return @() }
    $records = @(Get-CimInstance Win32_Process)
    $known = [Collections.Generic.HashSet[int]]::new()
    [void]$known.Add($RootProcessId)
    $frontier = @($RootProcessId)
    while ($frontier.Count -gt 0) {
        $next = @()
        foreach ($record in $records | Where-Object { $frontier -contains [int]$_.ParentProcessId }) {
            $pidValue = [int]$record.ProcessId
            if ($known.Add($pidValue)) { $next += $pidValue }
        }
        $frontier = $next
    }
    @($known | Where-Object { $_ -ne $RootProcessId })
}
function Run([string]$File, [string[]]$Arguments, [string]$Description) {
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $File
    $startInfo.WorkingDirectory = $root
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $startInfo.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    foreach ($argument in $Arguments) { [void]$startInfo.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) { throw "$Description could not start '$File'" }
        $rootProcessId = $process.Id
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $descendants = [Collections.Generic.HashSet[int]]::new()
        $deadline = [DateTimeOffset]::Now.AddMilliseconds(120000)
        while (-not $process.WaitForExit(100) -and [DateTimeOffset]::Now -lt $deadline) {
            foreach ($processId in @(Get-LiveDescendants $rootProcessId)) { [void]$descendants.Add($processId) }
        }
        if (-not $process.HasExited) {
            $process.Kill($true)
            $process.WaitForExit()
            throw "$Description exceeded 120000 ms"
        }
        $process.WaitForExit()
        $orphans = @(Get-LiveDescendants $rootProcessId)
        foreach ($processId in $orphans) { [void]$descendants.Add($processId) }
        $stdoutBytes = [Text.Encoding]::UTF8.GetBytes($stdoutTask.GetAwaiter().GetResult())
        $stderrBytes = [Text.Encoding]::UTF8.GetBytes($stderrTask.GetAwaiter().GetResult())
        [pscustomobject]@{
            ExitCode = $process.ExitCode
            StdoutBytes = $stdoutBytes
            StderrBytes = $stderrBytes
            RootProcessId = $rootProcessId
            DescendantProcessIds = @($descendants | Sort-Object)
            OrphanProcessIds = $orphans
        }
    } finally { $process.Dispose() }
}
function Save-Capture([string]$Directory, [string]$Stem, $Capture) {
    $stdoutPath = Join-Path $Directory "$Stem.stdout.txt"
    $stderrPath = Join-Path $Directory "$Stem.stderr.txt"
    [IO.File]::WriteAllBytes($stdoutPath, $Capture.StdoutBytes)
    [IO.File]::WriteAllBytes($stderrPath, $Capture.StderrBytes)
    [ordered]@{
        exit = $Capture.ExitCode; rootProcessId = $Capture.RootProcessId
        descendantProcessIds = @($Capture.DescendantProcessIds)
        orphanProcessIds = @($Capture.OrphanProcessIds)
        stdoutSha256 = Hash $stdoutPath; stderrSha256 = Hash $stderrPath
        stdoutBytes = $Capture.StdoutBytes.Length; stderrBytes = $Capture.StderrBytes.Length
    }
}

$paths = @{
    compiler = $Compiler; contract = $contractPath; schema = $schemaPath; verifier = $PSCommandPath
    closure = $closurePath; verificationProcess = $verificationProcessPath; auditShim = $auditShim
    llvmAs = $llvmAs; clang = $clang
}
foreach ($case in $cases) {
    $paths["source:$($case.id)"] = Join-Path $root $case.source
    $paths["expected:$($case.id)"] = Join-Path $root $case.expectedOutput
}
foreach ($path in $paths.Values) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "missing managed observability input: $path" }
}
$startHashes = HashMap $paths
if ($startHashes.compiler -cne $ExpectedCompilerSha256) {
    throw "compiler hash mismatch: expected=$ExpectedCompilerSha256 actual=$($startHashes.compiler)"
}
if ($cases.Count -ne 4 -or @($cases.id | Sort-Object -Unique).Count -ne 4) {
    throw 'managed observability initial case identity drifted'
}

$record = [ordered]@{
    schemaVersion = 1; status = 'failed'; scope = 'async-task-observability-managed-initial'
    compilerPath = $Compiler; expectedCompilerSha256 = $ExpectedCompilerSha256
    compilerSha256Start = $startHashes.compiler; compilerSha256End = $startHashes.compiler; compilerDrift = $false
    inputHashesStart = $startHashes; inputHashesEnd = $startHashes; inputDrift = $false
    completed = 0; total = 4; cases = @(); failureIds = @(); rootProcessIds = @(); descendantProcessIds = @(); orphanProcessIds = @()
    schemaControls = [ordered]@{ positiveAccepted = $false; negativeRejected = 0; negativeTotal = 5 }
}
$resultPath = Join-Path $OutputDirectory 'result.json'
$failureId = 'ASYNC_TASK_OBSERVABILITY_MANAGED_PREFLIGHT_FAILED'
try {
    if (-not $ValidateInputsOnly) {
        foreach ($case in $cases) {
            $caseDirectory = Join-Path $OutputDirectory $case.id
            [IO.Directory]::CreateDirectory($caseDirectory) | Out-Null
            $exe = Join-Path $caseDirectory 'probe.exe'
            $caseToken = $case.id.Replace('-', '_').ToUpperInvariant()
            $failureId = "ASYNC_TASK_OBSERVABILITY_${caseToken}_COMPILE_FAILED"
            $compile = Run 'dotnet' @($Compiler, 'build', $paths["source:$($case.id)"], '-o', $exe, '--target', 'windows-x64', '--llvm', $llvmRoot, '-O0', '--keep-temps') "$($case.id) compile"
            $compileArtifact = Save-Capture $caseDirectory 'compile' $compile
            $record.rootProcessIds += $compile.RootProcessId
            $record.descendantProcessIds += @($compile.DescendantProcessIds)
            $record.orphanProcessIds += @($compile.OrphanProcessIds)
            $ll = Get-ChildItem $caseDirectory -Recurse -Filter '*.ll' | Where-Object FullName -Like '*slg-tmp*' | Select-Object -First 1 -ExpandProperty FullName
            if ($compile.ExitCode -ne 0 -or -not $ll) { throw "$($case.id) compile failed" }
            $diagnostics = [Text.Encoding]::UTF8.GetString($compile.StdoutBytes + $compile.StderrBytes)
            $warningCount = [regex]::Matches($diagnostics, '(?im)\bwarning\b').Count
            $noteCount = [regex]::Matches($diagnostics, '(?im)\bnote\b').Count
            if ($warningCount -ne 0 -or $noteCount -ne 0 -or $compile.StderrBytes.Length -ne 0) { throw "$($case.id) compile emitted diagnostics" }

            $failureId = "ASYNC_TASK_OBSERVABILITY_${caseToken}_NATIVE_EXACT_FAILED"
            $native = Run $exe @() "$($case.id) native"
            $nativeArtifact = Save-Capture $caseDirectory 'native' $native
            $record.rootProcessIds += $native.RootProcessId
            $record.descendantProcessIds += @($native.DescendantProcessIds)
            $record.orphanProcessIds += @($native.OrphanProcessIds)
            $expectedBytes = [IO.File]::ReadAllBytes($paths["expected:$($case.id)"])
            $nativeExact = $native.ExitCode -eq 0 -and $native.StderrBytes.Length -eq 0 -and (BytesEqual $native.StdoutBytes $expectedBytes)
            if (-not $nativeExact) { throw "$($case.id) native raw-byte mismatch" }

            $failureId = "ASYNC_TASK_OBSERVABILITY_${caseToken}_LLVM_FAILED"
            $bc = Join-Path $caseDirectory 'probe.bc'
            $assembled = Run $llvmAs @($ll, '-o', $bc) "$($case.id) llvm-as"
            $llvmAsArtifact = Save-Capture $caseDirectory 'llvm-as' $assembled
            $closed = Run 'pwsh' @('-NoProfile', '-File', $closurePath, '-LlvmPath', $ll) "$($case.id) V004"
            $v004Artifact = Save-Capture $caseDirectory 'v004' $closed
            $record.rootProcessIds += @($assembled.RootProcessId, $closed.RootProcessId)
            $record.descendantProcessIds += @($assembled.DescendantProcessIds) + @($closed.DescendantProcessIds)
            $record.orphanProcessIds += @($assembled.OrphanProcessIds) + @($closed.OrphanProcessIds)
            if ($assembled.ExitCode -ne 0 -or $assembled.StdoutBytes.Length -ne 0 -or $assembled.StderrBytes.Length -ne 0 -or $closed.ExitCode -ne 0 -or $closed.StderrBytes.Length -ne 0) {
                throw "$($case.id) LLVM verification failed"
            }

            $item = [ordered]@{
                id = $case.id; sourceSha256 = Hash $paths["source:$($case.id)"]; expectedSha256 = Hash $paths["expected:$($case.id)"]
                compileExit = $compile.ExitCode; warningCount = $warningCount; noteCount = $noteCount
                nativeExit = $native.ExitCode; nativeExact = $nativeExact; llvmSha256 = Hash $ll; bitcodeSha256 = Hash $bc
                llvmAsExit = $assembled.ExitCode; v004Exit = $closed.ExitCode; passed = $true
                artifacts = [ordered]@{ compile = $compileArtifact; native = $nativeArtifact; llvmAs = $llvmAsArtifact; v004 = $v004Artifact }
                taskControlBytes = $null; diagnosticSymbolCount = $null; allocationCount = $null; releaseCount = $null; invalidReleaseCount = $null; locator = $null
            }
            if ($case.id -ceq 'normal-suspension-locator') {
                $source = [IO.File]::ReadAllText($paths["source:$($case.id)"]).Replace("`r`n", "`n")
                $locations = [ordered]@{}
                foreach ($token in @('sleep', 'await')) {
                    $match = [regex]::Match($source, "\b$token\b")
                    $prefix = $source.Substring(0, $match.Index)
                    $line = 1 + [regex]::Matches($prefix, "`n").Count
                    $lastNewLine = $prefix.LastIndexOf("`n", [StringComparison]::Ordinal)
                    $locations[$token] = [ordered]@{ utf8ByteOffset = [Text.Encoding]::UTF8.GetByteCount($prefix); line = $line; column = $match.Index - $lastNewLine }
                }
                if ($locations.await.utf8ByteOffset -ne $case.locatorExpectation.utf8ByteOffset -or $locations.await.line -ne $case.locatorExpectation.line -or $locations.await.column -ne $case.locatorExpectation.column -or
                    $locations.sleep.utf8ByteOffset -ne 2888 -or $locations.sleep.line -ne 78 -or $locations.sleep.column -ne 30) { throw 'Unicode locator independent source calculation drifted' }
                $item.locator = $locations
            }
            if ($case.id -ceq 'production-off-zero-overhead') {
                $failureId = 'ASYNC_TASK_OBSERVABILITY_PRODUCTION_OFF_AUDIT_FAILED'
                $llvmText = [IO.File]::ReadAllText($ll)
                $layout = '%sollang.task_control = type { ptr, ptr, ptr, ptr, i32, i32, ptr, ptr, i64, ptr, ptr, i32, i32, i64, i64, i32, ptr, i64, i64, i32, i32 }'
                $taskControlBytes = if ($llvmText.Contains($layout, [StringComparison]::Ordinal)) { 152 } else { 0 }
                $diagnosticSymbols = [regex]::Matches($llvmText, '(?i)sollang_diagnostic_|diagnostic_session|diagnostic_header').Count
                if ($taskControlBytes -ne $contract.productionOffGate.taskControlBytes -or $diagnosticSymbols -ne 0) { throw 'production-off ABI or zero-symbol invariant failed' }
                $auditText = $llvmText.Replace('call ptr @sollang_alloc(', 'call ptr @audit_malloc(').Replace('call void @sollang_free(', 'call void @audit_free(').Replace('ptr @sollang_free', 'ptr @audit_free').Replace('@sollang_start()', '@slg_program_main()')
                $auditText += "`ndeclare ptr @audit_malloc(i64)`ndeclare void @audit_free(ptr)`n"
                $auditLl = Join-Path $caseDirectory 'probe.audit.ll'
                [IO.File]::WriteAllText($auditLl, $auditText, [Text.UTF8Encoding]::new($false))
                $auditExe = Join-Path $caseDirectory 'probe.audit.exe'
                $expectedAllocations = [int]$contract.productionOffGate.allocationCount
                $auditLink = Run $clang @('-Wno-override-module', "-DEXPECTED_ALLOCATIONS=$expectedAllocations", $auditLl, $auditShim, '-O1', '-o', $auditExe) 'production-off allocation link'
                $auditLinkArtifact = Save-Capture $caseDirectory 'audit-link' $auditLink
                if ($auditLink.ExitCode -ne 0 -or $auditLink.StdoutBytes.Length -ne 0 -or $auditLink.StderrBytes.Length -ne 0) { throw 'production-off allocation link failed' }
                $audit = Run $auditExe @() 'production-off allocation execute'
                $auditArtifact = Save-Capture $caseDirectory 'audit' $audit
                $record.rootProcessIds += @($auditLink.RootProcessId, $audit.RootProcessId)
                $record.descendantProcessIds += @($auditLink.DescendantProcessIds) + @($audit.DescendantProcessIds)
                $record.orphanProcessIds += @($auditLink.OrphanProcessIds) + @($audit.OrphanProcessIds)
                $auditOutput = [Text.Encoding]::UTF8.GetString($audit.StdoutBytes)
                $auditMatch = [regex]::Match($auditOutput, '(?m)^allocations=(?<a>\d+),releases=(?<r>\d+)\r?$')
                $allocations = if ($auditMatch.Success) { [int]$auditMatch.Groups['a'].Value } else { -1 }
                $releases = if ($auditMatch.Success) { [int]$auditMatch.Groups['r'].Value } else { -1 }
                $invalid = [regex]::Matches([Text.Encoding]::UTF8.GetString($audit.StderrBytes), 'invalid (?:release|realloc):').Count
                if ($audit.ExitCode -ne 0 -or $allocations -ne $contract.productionOffGate.allocationCount -or $releases -ne $contract.productionOffGate.releaseCount -or
                    $invalid -ne $contract.productionOffGate.invalidReleaseCount -or $audit.StderrBytes.Length -ne 0) { throw 'production-off exact allocation baseline failed' }
                $item.taskControlBytes = $taskControlBytes; $item.diagnosticSymbolCount = $diagnosticSymbols
                $item.allocationCount = $allocations; $item.releaseCount = $releases; $item.invalidReleaseCount = $invalid
                $item.artifacts.auditLink = $auditLinkArtifact; $item.artifacts.audit = $auditArtifact
            }
            if ($record.orphanProcessIds.Count -ne 0) { throw 'managed observability process left live descendants' }
            $record.cases += [pscustomobject]$item
            $record.completed++
        }
        $record.status = 'passed'
    }
} catch {
    $record.failureIds = @($failureId)
    $record.failure = $_.Exception.Message
} finally {
    $record.compilerSha256End = Hash $Compiler
    $record.compilerDrift = $record.compilerSha256Start -cne $record.compilerSha256End
    $record.inputHashesEnd = HashMap $paths
    $record.inputDrift = -not (MapsEqual $record.inputHashesStart $record.inputHashesEnd)
    $record.rootProcessIds = @($record.rootProcessIds | Sort-Object -Unique)
    $record.descendantProcessIds = @($record.descendantProcessIds | Sort-Object -Unique)
    $record.orphanProcessIds = @($record.orphanProcessIds | Sort-Object -Unique)
    if (($record.compilerDrift -or $record.inputDrift) -and $record.failureIds.Count -eq 0) {
        $record.status = 'failed'; $record.failureIds = @('ASYNC_TASK_OBSERVABILITY_INPUT_DRIFT'); $record.failure = 'managed observability inputs drifted'
    }
}

if ($ValidateInputsOnly) {
    $record.status = 'passed'; $record.completed = 4
    foreach ($case in $cases) {
        $fakeArtifact = [ordered]@{ exit=0; rootProcessId=1; descendantProcessIds=@(); orphanProcessIds=@(); stdoutSha256=('C' * 64); stderrSha256=('D' * 64); stdoutBytes=0; stderrBytes=0 }
        $fakeArtifacts = [ordered]@{ compile=$fakeArtifact; native=$fakeArtifact; llvmAs=$fakeArtifact; v004=$fakeArtifact }
        if ($case.id -ceq 'production-off-zero-overhead') { $fakeArtifacts.auditLink=$fakeArtifact; $fakeArtifacts.audit=$fakeArtifact }
        $record.cases += [pscustomobject]@{
            id=$case.id; sourceSha256=Hash $paths["source:$($case.id)"]; expectedSha256=Hash $paths["expected:$($case.id)"]
            compileExit=0; warningCount=0; noteCount=0; nativeExit=0; nativeExact=$true
            llvmSha256=('A' * 64); bitcodeSha256=('B' * 64); llvmAsExit=0; v004Exit=0; passed=$true; artifacts=$fakeArtifacts
            taskControlBytes=if($case.id -ceq 'production-off-zero-overhead'){152}else{$null}
            diagnosticSymbolCount=if($case.id -ceq 'production-off-zero-overhead'){0}else{$null}
            allocationCount=if($case.id -ceq 'production-off-zero-overhead'){2}else{$null}
            releaseCount=if($case.id -ceq 'production-off-zero-overhead'){2}else{$null}
            invalidReleaseCount=if($case.id -ceq 'production-off-zero-overhead'){0}else{$null}
            locator=if($case.id -ceq 'normal-suspension-locator'){@{sleep=@{utf8ByteOffset=2888;line=78;column=30};await=@{utf8ByteOffset=2897;line=78;column=39}}}else{$null}
        }
    }
}

$record.schemaControls.positiveAccepted = $true
$record.schemaControls.negativeRejected = 5
$record.schemaControls.positiveAccepted = (($record | ConvertTo-Json -Depth 16) | Test-Json -SchemaFile $schemaPath -ErrorAction SilentlyContinue)
if (-not $record.schemaControls.positiveAccepted) { throw 'managed observability result schema rejected the positive control' }
$negativeRejected = 0
$negativeControls = @(
    { param($r) $r.cases = @($r.cases[0], $r.cases[0], $r.cases[2], $r.cases[3]) },
    { param($r) $r.cases = @($r.cases | Select-Object -First 3) },
    { param($r) $r.cases[0].nativeExit = 1 },
    { param($r) $r.cases[2].locator = $null },
    { param($r) $r.cases[3].allocationCount = 3 }
)
foreach ($mutate in $negativeControls) {
    $negative = (($record | ConvertTo-Json -Depth 16) | ConvertFrom-Json)
    & $mutate $negative
    if (-not (($negative | ConvertTo-Json -Depth 16) | Test-Json -SchemaFile $schemaPath -ErrorAction SilentlyContinue)) { $negativeRejected++ }
}
$record.schemaControls.negativeRejected = $negativeRejected
if ($record.schemaControls.negativeRejected -ne $record.schemaControls.negativeTotal) { throw 'managed observability result schema accepted a negative control' }
[IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 16) + "`n"), [Text.UTF8Encoding]::new($false))
if ($ValidateInputsOnly) { Write-Host "[async task observability managed inputs] PASS positive1/1 negative5/5; $resultPath"; return }
if ($record.status -ne 'passed') { throw $record.failure }
Write-Host "[async task observability managed] PASS 4/4; schema positive1/1 negative5/5; $resultPath"
