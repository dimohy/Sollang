[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCompilerSha256,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputDirectory = '',
    [switch]$ValidateInputsOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$Compiler = (Resolve-Path -LiteralPath $Compiler).Path
$ExpectedCompilerSha256 = $ExpectedCompilerSha256.ToUpperInvariant()
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $root ('artifacts/scratch/async-task-observability-managed-matrix-' + [Guid]::NewGuid().ToString('N'))
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null

$contractPath = Join-Path $root 'scripts/contracts/async-task-observability.json'
$schemaPath = Join-Path $root 'scripts/contracts/async-task-observability-managed-matrix-result.schema.json'
$closurePath = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$auditShim = Join-Path $root 'tests/native-interop/owned_array_audit.c'
$llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
$llvmAs = Join-Path $llvmRoot 'bin/llvm-as.exe'
$clang = Join-Path $llvmRoot 'bin/clang.exe'
$contract = [IO.File]::ReadAllText($contractPath) | ConvertFrom-Json
$cases = @($contract.probeMatrix | Where-Object managed)

$expectedById = @{
    'normal-parent-child-states' = 'parent-child-states.expected.txt'
    'normal-stable-id-transitions' = 'stable-id-transitions.expected.txt'
    'normal-suspension-locator' = 'unicode-suspension-locator.expected.txt'
    'boundary-caller-buffer-truncation' = 'bounded-snapshot.expected.txt'
    'boundary-record-capacity' = 'capacity-saturation.expected.txt'
    'boundary-close-busy-owner-return' = 'session-close-reuse.expected.txt'
    'boundary-session-id-no-reuse' = 'session-close-reuse.expected.txt'
    'production-off-zero-overhead' = 'production-off.expected.txt'
}
$diagnosticById = @{
    'negative-affine-session-copy' = "unknown binding 'session'"
    'negative-use-after-close' = "unknown binding 'session'"
    'negative-ambient-registry' = "unknown function or method 'std.async.diagnostics.allTasks'"
    'negative-scheduler-control' = "unknown function or method 'std.async.diagnostics.resumeTask'"
    'browser-async-actionable-rejection' = 'async functions are unavailable on the current target'
}

function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function HashMap([hashtable]$Paths) {
    $map = [ordered]@{}
    foreach ($entry in $Paths.GetEnumerator() | Sort-Object Key) { $map[$entry.Key] = Hash $entry.Value }
    $map
}
function MapsEqual($Left, $Right) { (($Left | ConvertTo-Json -Compress) -ceq ($Right | ConvertTo-Json -Compress)) }
function BytesEqual([byte[]]$Left, [byte[]]$Right) {
    $Left.Length -eq $Right.Length -and [Convert]::ToHexString($Left) -ceq [Convert]::ToHexString($Right)
}
function Get-LiveDescendants([int]$RootProcessId) {
    if (-not $IsWindows) { return @() }
    $records = @(Get-CimInstance Win32_Process)
    $known = [Collections.Generic.HashSet[int]]::new()
    [void]$known.Add($RootProcessId)
    $frontier = @($RootProcessId)
    while ($frontier.Count -gt 0) {
        $next = @()
        foreach ($processRecord in $records | Where-Object { $frontier -contains [int]$_.ParentProcessId }) {
            $processId = [int]$processRecord.ProcessId
            if ($known.Add($processId)) { $next += $processId }
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
        [pscustomobject]@{
            ExitCode = $process.ExitCode
            StdoutBytes = [Text.Encoding]::UTF8.GetBytes($stdoutTask.GetAwaiter().GetResult())
            StderrBytes = [Text.Encoding]::UTF8.GetBytes($stderrTask.GetAwaiter().GetResult())
            RootProcessId = $rootProcessId
            DescendantProcessIds = @($descendants | Sort-Object)
            OrphanProcessIds = $orphans
        }
    } finally { $process.Dispose() }
}
function Save-Capture([string]$Directory, [string]$Stem, $Capture) {
    [IO.File]::WriteAllBytes((Join-Path $Directory "$Stem.stdout.txt"), $Capture.StdoutBytes)
    [IO.File]::WriteAllBytes((Join-Path $Directory "$Stem.stderr.txt"), $Capture.StderrBytes)
}
function Add-ProcessEvidence($Capture, [hashtable]$Item) {
    $Item.rootProcessIds += $Capture.RootProcessId
    $Item.descendantProcessIds += @($Capture.DescendantProcessIds)
    $Item.orphanProcessIds += @($Capture.OrphanProcessIds)
}

if ($cases.Count -ne 13 -or @($cases.id | Sort-Object -Unique).Count -ne 13) { throw 'managed observability matrix identity drifted' }
$paths = @{ compiler=$Compiler; contract=$contractPath; schema=$schemaPath; verifier=$PSCommandPath; closure=$closurePath; auditShim=$auditShim; llvmAs=$llvmAs; clang=$clang }
foreach ($case in $cases) {
    $paths["source:$($case.id)"] = Join-Path $root $case.source
    if ($expectedById.ContainsKey($case.id)) {
        $paths["expected:$($case.id)"] = Join-Path $root ('scripts/probes/async-task-observability/' + $expectedById[$case.id])
    }
}
foreach ($path in $paths.Values) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "missing managed matrix input: $path" } }
$startHashes = HashMap $paths
if ($startHashes.compiler -cne $ExpectedCompilerSha256) { throw "compiler hash mismatch: expected=$ExpectedCompilerSha256 actual=$($startHashes.compiler)" }

$record = [ordered]@{
    schemaVersion=1; status='failed'; scope='async-task-observability-managed-matrix'
    compilerPath=$Compiler; expectedCompilerSha256=$ExpectedCompilerSha256
    compilerSha256Start=$startHashes.compiler; compilerSha256End=$startHashes.compiler; compilerDrift=$false
    inputHashesStart=$startHashes; inputHashesEnd=$startHashes; inputDrift=$false
    completed=0; total=13; cases=@(); failureIds=@(); rootProcessIds=@(); descendantProcessIds=@(); orphanProcessIds=@()
    schemaControls=[ordered]@{ positiveAccepted=$false; negativeRejected=0; negativeTotal=7 }
}
$resultPath = Join-Path $OutputDirectory 'result.json'
$failureId = 'ASYNC_TASK_OBSERVABILITY_MANAGED_MATRIX_PREFLIGHT_FAILED'
try {
    foreach ($case in $cases) {
        $item = [ordered]@{
            id=$case.id; class=$case.class; target=if($case.id -ceq 'browser-async-actionable-rejection'){'wasm32-browser'}else{'windows-x64'}
            expectation=$case.expectation; sourceSha256=Hash $paths["source:$($case.id)"]
            compileExit=0; warningCount=0; noteCount=0; diagnosticMatched=$null; nativeExit=$null; nativeExact=$null
            llvmAsExit=$null; v004Exit=$null; allocationParity=$null; passed=$true
            rootProcessIds=@(); descendantProcessIds=@(); orphanProcessIds=@()
        }
        if (-not $ValidateInputsOnly) {
            $caseDirectory = Join-Path $OutputDirectory $case.id
            [IO.Directory]::CreateDirectory($caseDirectory) | Out-Null
            $outputName = if ($item.target -ceq 'wasm32-browser') { 'probe.wasm' } else { 'probe.exe' }
            $nativePath = Join-Path $caseDirectory $outputName
            $compile = Run 'dotnet' @($Compiler, 'build', $paths["source:$($case.id)"], '-o', $nativePath, '--target', $item.target, '--llvm', $llvmRoot, '-O0', '--keep-temps') "$($case.id) compile"
            Save-Capture $caseDirectory 'compile' $compile
            Add-ProcessEvidence $compile $item
            $item.compileExit = $compile.ExitCode
            $diagnostics = [Text.Encoding]::UTF8.GetString($compile.StdoutBytes + $compile.StderrBytes)
            $item.warningCount = [regex]::Matches($diagnostics, '(?im)\bwarning\b').Count
            $item.noteCount = [regex]::Matches($diagnostics, '(?im)\bnote\b').Count
            if ($case.expectation -ceq 'compiler-rejected') {
                $failureId = ('ASYNC_TASK_OBSERVABILITY_' + $case.id.Replace('-', '_').ToUpperInvariant() + '_REJECTION_FAILED')
                $item.diagnosticMatched = $diagnosticById.ContainsKey($case.id) -and $diagnostics.Contains($diagnosticById[$case.id], [StringComparison]::Ordinal)
                if ($compile.ExitCode -eq 0 -or -not $item.diagnosticMatched -or (Test-Path -LiteralPath $nativePath)) { throw "$($case.id) did not fail closed with its actionable diagnostic" }
            } else {
                $failureId = ('ASYNC_TASK_OBSERVABILITY_' + $case.id.Replace('-', '_').ToUpperInvariant() + '_EXECUTION_FAILED')
                if ($compile.ExitCode -ne 0 -or $compile.StderrBytes.Length -ne 0 -or $item.warningCount -ne 0 -or $item.noteCount -ne 0) { throw "$($case.id) compile failed or emitted diagnostics" }
                $ll = Get-ChildItem $caseDirectory -Recurse -Filter '*.ll' | Where-Object FullName -Like '*slg-tmp*' | Select-Object -First 1 -ExpandProperty FullName
                if (-not $ll) { throw "$($case.id) emitted no LLVM" }
                $native = Run $nativePath @() "$($case.id) native"
                Save-Capture $caseDirectory 'native' $native
                Add-ProcessEvidence $native $item
                $item.nativeExit = $native.ExitCode
                $item.nativeExact = $native.ExitCode -eq 0 -and $native.StderrBytes.Length -eq 0 -and (BytesEqual $native.StdoutBytes ([IO.File]::ReadAllBytes($paths["expected:$($case.id)"])) )
                if (-not $item.nativeExact) { throw "$($case.id) native raw-byte mismatch" }
                $bc = Join-Path $caseDirectory 'probe.bc'
                $assembled = Run $llvmAs @($ll, '-o', $bc) "$($case.id) llvm-as"
                $closed = Run 'pwsh' @('-NoProfile', '-File', $closurePath, '-LlvmPath', $ll) "$($case.id) V004"
                Save-Capture $caseDirectory 'llvm-as' $assembled
                Save-Capture $caseDirectory 'v004' $closed
                Add-ProcessEvidence $assembled $item
                Add-ProcessEvidence $closed $item
                $item.llvmAsExit = $assembled.ExitCode
                $item.v004Exit = $closed.ExitCode
                if ($assembled.ExitCode -ne 0 -or $assembled.StdoutBytes.Length -ne 0 -or $assembled.StderrBytes.Length -ne 0 -or $closed.ExitCode -ne 0 -or $closed.StderrBytes.Length -ne 0) { throw "$($case.id) LLVM verification failed" }
                if ($case.id -ceq 'production-off-zero-overhead') {
                    $llvmText = [IO.File]::ReadAllText($ll)
                    $layout = '%sollang.task_control = type { ptr, ptr, ptr, ptr, i32, i32, ptr, ptr, i64, ptr, ptr, i32, i32, i64, i64, i32, ptr, i64, i64, i32, i32 }'
                    if (-not $llvmText.Contains($layout, [StringComparison]::Ordinal) -or [regex]::Matches($llvmText, '(?i)sollang_diagnostic_|diagnostic_session|diagnostic_header').Count -ne 0) { throw 'production-off layout or symbol parity failed' }
                    $auditText = $llvmText.Replace('call ptr @sollang_alloc(', 'call ptr @audit_malloc(').Replace('call void @sollang_free(', 'call void @audit_free(').Replace('ptr @sollang_free', 'ptr @audit_free').Replace('@sollang_start()', '@slg_program_main()')
                    $auditText += "`ndeclare ptr @audit_malloc(i64)`ndeclare void @audit_free(ptr)`n"
                    $auditLl = Join-Path $caseDirectory 'probe.audit.ll'
                    [IO.File]::WriteAllText($auditLl, $auditText, [Text.UTF8Encoding]::new($false))
                    $auditExe = Join-Path $caseDirectory 'probe.audit.exe'
                    $auditLink = Run $clang @('-Wno-override-module', '-DEXPECTED_ALLOCATIONS=2', $auditLl, $auditShim, '-O1', '-o', $auditExe) 'production-off audit link'
                    $audit = Run $auditExe @() 'production-off allocation audit'
                    Save-Capture $caseDirectory 'audit-link' $auditLink
                    Save-Capture $caseDirectory 'audit' $audit
                    Add-ProcessEvidence $auditLink $item
                    Add-ProcessEvidence $audit $item
                    $auditOutput = [Text.Encoding]::UTF8.GetString($audit.StdoutBytes)
                    $item.allocationParity = $auditLink.ExitCode -eq 0 -and $auditLink.StdoutBytes.Length -eq 0 -and $auditLink.StderrBytes.Length -eq 0 -and $audit.ExitCode -eq 0 -and $audit.StderrBytes.Length -eq 0 -and $auditOutput.Contains('allocations=2,releases=2', [StringComparison]::Ordinal)
                    if (-not $item.allocationParity) { throw 'production-off allocation parity failed' }
                }
            }
            $item.rootProcessIds = @($item.rootProcessIds | Sort-Object -Unique)
            $item.descendantProcessIds = @($item.descendantProcessIds | Sort-Object -Unique)
            $item.orphanProcessIds = @($item.orphanProcessIds | Sort-Object -Unique)
            if ($item.orphanProcessIds.Count -ne 0) { throw "$($case.id) left live descendants" }
        } elseif ($case.expectation -ceq 'compiler-rejected') {
            $item.compileExit = 1
            $item.diagnosticMatched = $true
        } else {
            $item.nativeExit = 0; $item.nativeExact = $true; $item.llvmAsExit = 0; $item.v004Exit = 0
            if ($case.id -ceq 'production-off-zero-overhead') { $item.allocationParity = $true }
        }
        $record.cases += [pscustomobject]$item
        $record.completed++
    }
    $record.status = 'passed'
} catch {
    $record.failureIds = @($failureId)
    $record.failure = $_.Exception.Message
} finally {
    $record.compilerSha256End = Hash $Compiler
    $record.compilerDrift = $record.compilerSha256Start -cne $record.compilerSha256End
    $record.inputHashesEnd = HashMap $paths
    $record.inputDrift = -not (MapsEqual $record.inputHashesStart $record.inputHashesEnd)
    $allRootProcessIds = @()
    $allDescendantProcessIds = @()
    $allOrphanProcessIds = @()
    foreach ($caseRecord in $record.cases) {
        $allRootProcessIds += @($caseRecord.rootProcessIds)
        $allDescendantProcessIds += @($caseRecord.descendantProcessIds)
        $allOrphanProcessIds += @($caseRecord.orphanProcessIds)
    }
    $record.rootProcessIds = @($allRootProcessIds | Sort-Object -Unique)
    $record.descendantProcessIds = @($allDescendantProcessIds | Sort-Object -Unique)
    $record.orphanProcessIds = @($allOrphanProcessIds | Sort-Object -Unique)
    if (($record.compilerDrift -or $record.inputDrift) -and $record.failureIds.Count -eq 0) {
        $record.status='failed'; $record.failureIds=@('ASYNC_TASK_OBSERVABILITY_MANAGED_MATRIX_INPUT_DRIFT'); $record.failure='managed matrix inputs drifted'
    }
}

[IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 16) + "`n"), [Text.UTF8Encoding]::new($false))
$record.schemaControls.positiveAccepted = $true
$record.schemaControls.negativeRejected = $record.schemaControls.negativeTotal
$record.schemaControls.positiveAccepted = (($record | ConvertTo-Json -Depth 16) | Test-Json -SchemaFile $schemaPath -ErrorAction SilentlyContinue)
if (-not $record.schemaControls.positiveAccepted) { throw 'managed matrix schema rejected the positive record' }
if ($record.status -ne 'passed') {
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 16) + "`n"), [Text.UTF8Encoding]::new($false))
    throw $record.failure
}
$negativeRejected = 0
$mutations = @(
    { param($r) $r.cases = @($r.cases | Select-Object -First 12) },
    { param($r) $r.cases[1].id = $r.cases[0].id },
    { param($r) $r.completed = 12 },
    { param($r) $r.cases[0].passed = $false },
    { param($r) $r.orphanProcessIds = @(99999) },
    { param($r) $r.compilerDrift = $true },
    { param($r) $r.failureIds = @('FORGED_SUCCESS') }
)
foreach ($mutate in $mutations) {
    $negative = (($record | ConvertTo-Json -Depth 16) | ConvertFrom-Json)
    & $mutate $negative
    if (-not (($negative | ConvertTo-Json -Depth 16) | Test-Json -SchemaFile $schemaPath -ErrorAction SilentlyContinue)) { $negativeRejected++ }
}
$record.schemaControls.negativeRejected = $negativeRejected
if ($negativeRejected -ne $record.schemaControls.negativeTotal) { throw 'managed matrix schema accepted a negative control' }
[IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 16) + "`n"), [Text.UTF8Encoding]::new($false))
Write-Host "[async task observability managed matrix] PASS 13/13; schema positive1/1 negative7/7; $resultPath"
