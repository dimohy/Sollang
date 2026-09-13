[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCompilerSha256,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [switch]$SourceFreezeApproved,
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$utf8 = [Text.UTF8Encoding]::new($false, $true)

function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Hash-Bytes([byte[]]$Bytes) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)) }
function Hash-Text([string]$Text) { Hash-Bytes $utf8.GetBytes($Text) }
function Relative([string]$Path) { [IO.Path]::GetRelativePath($root, $Path).Replace('\', '/') }

function Snapshot-Stdlib {
    $entries = @(Get-ChildItem -LiteralPath (Join-Path $root 'stdlib') -Recurse -File -Filter '*.slg' |
        Sort-Object { Relative $_.FullName } |
        ForEach-Object { [ordered]@{ path = Relative $_.FullName; sha256 = Hash $_.FullName } })
    $canonical = ($entries | ForEach-Object { "$($_.path)=$($_.sha256)`n" }) -join ''
    [ordered]@{ entries = $entries; sha256 = Hash-Text $canonical }
}

function Snapshot-Inputs([System.Collections.IDictionary]$Paths, [object]$Manifest) {
    $snapshot = [ordered]@{}
    foreach ($entry in $Paths.GetEnumerator()) { $snapshot[$entry.Key] = Hash $entry.Value }
    foreach ($entry in $Manifest.entries) { $snapshot["stdlib:$($entry.path)"] = $entry.sha256 }
    $snapshot
}

function Find-Drift([System.Collections.IDictionary]$Start, [System.Collections.IDictionary]$End) {
    @(@($Start.Keys) + @($End.Keys) | Sort-Object -Unique | Where-Object {
        -not $Start.Contains($_) -or -not $End.Contains($_) -or $Start[$_] -cne $End[$_]
    })
}

function Observe-Descendants([int]$RootProcessId, [Collections.Generic.HashSet[int]]$Observed) {
    $rows = @(Get-CimInstance Win32_Process -Property ProcessId,ParentProcessId -ErrorAction Stop)
    $frontier = [Collections.Generic.Queue[int]]::new()
    $frontier.Enqueue($RootProcessId)
    while ($frontier.Count -gt 0) {
        $parent = $frontier.Dequeue()
        foreach ($row in $rows | Where-Object ParentProcessId -eq $parent) {
            $pid = [int]$row.ProcessId
            if ($Observed.Add($pid)) { $frontier.Enqueue($pid) }
        }
    }
}

function Save-Stream([byte[]]$Bytes, [string]$Path) {
    [IO.File]::WriteAllBytes($Path, $Bytes)
    [ordered]@{ path = Relative $Path; sha256 = Hash-Bytes $Bytes; byteCount = $Bytes.Length; text = $utf8.GetString($Bytes) }
}

function Test-StreamEvidence([object]$Stream) {
    $path = [IO.Path]::GetFullPath((Join-Path $root ([string]$Stream.path)))
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
    $bytes = [IO.File]::ReadAllBytes($path)
    return $bytes.Length -eq [int]$Stream.byteCount -and
        (Hash-Bytes $bytes) -ceq [string]$Stream.sha256 -and
        $utf8.GetString($bytes) -ceq [string]$Stream.text
}

function Test-ProcessEvidence([object]$Process) {
    return $null -ne $Process -and (Test-StreamEvidence $Process.stdout) -and (Test-StreamEvidence $Process.stderr)
}

$rootProcessIds = [Collections.Generic.HashSet[int]]::new()
$descendantProcessIds = [Collections.Generic.HashSet[int]]::new()
$orphanProcessIds = [Collections.Generic.HashSet[int]]::new()

function Run-Tracked([string]$File, [string[]]$Arguments, [string]$Description, [string]$LogPrefix, [string]$WorkingDirectory = $root) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $File; $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false; $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new(); $process.StartInfo = $start
    $stdout = [IO.MemoryStream]::new(); $stderr = [IO.MemoryStream]::new()
    $observed = [Collections.Generic.HashSet[int]]::new()
    try {
        if (-not $process.Start()) { throw "$Description could not start" }
        $pid = $process.Id; [void]$rootProcessIds.Add($pid)
        $stdoutCopy = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
        $stderrCopy = $process.StandardError.BaseStream.CopyToAsync($stderr)
        $watch = [Diagnostics.Stopwatch]::StartNew()
        while (-not $process.WaitForExit(50)) {
            Observe-Descendants $pid $observed
            if ($watch.ElapsedMilliseconds -ge 120000) {
                Observe-Descendants $pid $observed
                foreach ($child in $observed) { [void]$descendantProcessIds.Add($child); if (Get-Process -Id $child -ErrorAction SilentlyContinue) { [void]$orphanProcessIds.Add($child) } }
                [void]$orphanProcessIds.Add($pid)
                throw "$Description exceeded 120000 ms; detached supervisor must resolve the live process tree"
            }
        }
        Observe-Descendants $pid $observed
        $process.WaitForExit(); $stdoutCopy.GetAwaiter().GetResult(); $stderrCopy.GetAwaiter().GetResult()
        $deadline = [DateTime]::UtcNow.AddSeconds(2)
        do {
            $live = @($observed | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue })
            if ($live.Count -eq 0) { break }
            Start-Sleep -Milliseconds 50
        } while ([DateTime]::UtcNow -lt $deadline)
        $orphans = @($observed | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue } | Sort-Object -Unique)
        foreach ($child in $observed) { [void]$descendantProcessIds.Add($child) }
        foreach ($child in $orphans) { [void]$orphanProcessIds.Add($child) }
        $stdoutBytes = $stdout.ToArray(); $stderrBytes = $stderr.ToArray()
        [pscustomobject][ordered]@{
            exitCode = $process.ExitCode; rootProcessId = $pid
            descendantProcessIds = @($observed | Sort-Object); orphanProcessIds = $orphans
            stdout = Save-Stream $stdoutBytes "$LogPrefix.stdout.bin"
            stderr = Save-Stream $stderrBytes "$LogPrefix.stderr.bin"
        }
    } finally {
        $stdout.Dispose(); $stderr.Dispose(); $process.Dispose()
    }
}

function Empty-Case([object]$Case, [string]$SourcePath) {
    [ordered]@{
        id = [string]$Case.id; kind = if ([bool]$Case.requiresLlvm) { 'positive' } else { 'negative' }
        status = 'not-run'; source = Relative $SourcePath; sourceSha256 = Hash $SourcePath
        compile = $null; run = $null; warningCount = 0; llvmPath = $null; llvmSha256 = $null
        llvmAs = $null; v004 = $null; audit = $null; passed = $false
    }
}

if ($ValidateOnly -and $SourceFreezeApproved) { throw '-ValidateOnly cannot assert -SourceFreezeApproved' }
if (-not $ValidateOnly -and -not $SourceFreezeApproved) { throw 'C437 current-source execution requires explicit -SourceFreezeApproved after ZIP/QUIC source freeze' }
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$expectedSha = $ExpectedCompilerSha256.ToUpperInvariant()
$output = [IO.Path]::GetFullPath($OutputDirectory); [IO.Directory]::CreateDirectory($output) | Out-Null
$contractPath = Join-Path $root 'scripts/contracts/evidence/C2026-09-13-437/focused-contract.json'
$contractSchemaPath = Join-Path $root 'scripts/contracts/evidence/C2026-09-13-437/focused-contract.schema.json'
$resultSchemaPath = Join-Path $root 'scripts/contracts/c437-current-source-result.schema.json'
$closurePath = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$ownerAuditPath = Join-Path $root 'tests/native-interop/c399_owned_payload_audit.c'
$allocationAuditPath = Join-Path $root 'tests/native-interop/c437_allocation_audit.c'
$llvmRoot = Join-Path $root '.tools/llvm-22.1.8'; $llvmAsPath = Join-Path $llvmRoot 'bin/llvm-as.exe'; $clangPath = Join-Path $llvmRoot 'bin/clang.exe'
$caseIds = @('W01_DIRECT','W02_PENDING','W03_CANCEL','REDUCED_POSITIVE','COMPLETION_COMPAT','C424_COPY_TAIL','C399_CONTROL','C424_NESTED_CONTROL','ZSTD_CONTROL','DIVERGENT_BRANCH','LOOP_BRANCH','LOOP_BREAK','LOOP_CONTINUE','LOOP_BACKEDGE')

$contractText = [IO.File]::ReadAllText($contractPath)
if (-not ($contractText | Test-Json -SchemaFile $contractSchemaPath -ErrorAction Stop)) { throw 'C437 focused contract schema rejected authority' }
$contract = $contractText | ConvertFrom-Json
if ($contract.total -ne 14 -or (@($contract.cases.id) -join "`n") -cne ($caseIds -join "`n") -or
    @($contract.cases | Where-Object requiresLlvm).Count -ne 9 -or
    @($contract.cases | Where-Object { -not $_.requiresLlvm }).Count -ne 5) {
    throw 'C437 contract must contain the exact ordered 9-positive/5-negative topology'
}
$paths = [ordered]@{ compiler=$compilerPath; verifier=$PSCommandPath; resultSchema=$resultSchemaPath; contract=$contractPath; contractSchema=$contractSchemaPath; closure=$closurePath; ownerAudit=$ownerAuditPath; allocationAudit=$allocationAuditPath; llvmAs=$llvmAsPath; clang=$clangPath }
foreach ($case in $contract.cases) { $paths["source:$($case.id)"] = Join-Path $root ([string]$case.source) }
foreach ($entry in $paths.GetEnumerator()) { if (-not (Test-Path -LiteralPath $entry.Value -PathType Leaf) -or (Get-Item $entry.Value).Length -eq 0) { throw "C437 authority input missing or empty: $($entry.Value)" } }
$manifestStart = Snapshot-Stdlib; $inputStart = Snapshot-Inputs $paths $manifestStart
if ($inputStart.compiler -cne $expectedSha) { throw "C437 compiler hash mismatch: expected=$expectedSha actual=$($inputStart.compiler)" }
$record = [ordered]@{
    schemaVersion=2; defectId='C2026-09-13-437'; status=if($ValidateOnly){'validate-only'}else{'failed'}; completed=0; total=14; caseIds=$caseIds
    compilerPath=$compilerPath; compilerSha256=$inputStart.compiler; expectedCompilerSha256=$expectedSha
    sourceFreezeApproved=[bool]$SourceFreezeApproved; currentSourceFreezeValidated=$false
    stdlibSourceCountStart=$manifestStart.entries.Count; stdlibSourceCountEnd=$manifestStart.entries.Count
    stdlibManifestStart=$manifestStart.entries; stdlibManifestEnd=$manifestStart.entries
    stdlibManifestSha256Start=$manifestStart.sha256; stdlibManifestSha256End=$manifestStart.sha256
    stdlibManifestCountMatched=$true; stdlibManifestExact=$true
    inputHashesStart=$inputStart; inputHashesEnd=$inputStart; inputDrift=@()
    rootProcessIds=@(); descendantProcessIds=@(); orphanProcessIds=@()
    cases=@($contract.cases|ForEach-Object{Empty-Case $_ $paths["source:$($_.id)"]}); failureIds=@()
}

try {
    if (-not $ValidateOnly) {
        $ownerDll = Join-Path $output 'c399_owner.dll'
        $ownerBuild = Run-Tracked $clangPath @('-shared',$ownerAuditPath,'-O1','-o',$ownerDll) 'C437 owner audit build' (Join-Path $output 'owner-audit-build')
        if ($ownerBuild.exitCode -ne 0 -or $ownerBuild.stdout.byteCount -ne 0 -or $ownerBuild.stderr.byteCount -ne 0) { throw 'C437 owner audit build failed or emitted diagnostics' }
        for ($index=0; $index -lt 14; $index++) {
            $case=$contract.cases[$index]; $item=$record.cases[$index]; $caseDir=Join-Path $output ([string]$case.id); [IO.Directory]::CreateDirectory($caseDir)|Out-Null
            Copy-Item $ownerDll (Join-Path $caseDir 'c399_owner.dll') -Force
            $exe=Join-Path $caseDir 'case.exe'; $ll=Join-Path $caseDir 'case.ll'
            $item.compile=Run-Tracked 'dotnet' @($compilerPath,'build',$paths["source:$($case.id)"],'-o',$exe,'--target','windows-x64','--llvm',$llvmRoot,'-O1','--keep-temps') "C437 $($case.id) compile" (Join-Path $caseDir 'compile')
            $item.warningCount=[regex]::Matches($item.compile.stdout.text+$item.compile.stderr.text,'(?im)\bwarning\b').Count
            if (-not [bool]$case.requiresLlvm) {
                if ($item.compile.exitCode -ne [int]$case.expectedExitCode -or $item.compile.stdout.byteCount -ne 0 -or $item.compile.stderr.text -cne [string]$case.expectedStderr -or $item.warningCount -ne 0 -or (Test-Path $ll)) { throw "C437 $($case.id) negative topology mismatch" }
            } else {
                if ($item.compile.exitCode -ne 0 -or $item.compile.stderr.byteCount -ne 0 -or $item.warningCount -ne 0 -or -not(Test-Path $ll)) { throw "C437 $($case.id) compile topology mismatch" }
                $item.run=Run-Tracked $exe @() "C437 $($case.id) execute" (Join-Path $caseDir 'run') $caseDir
                if ($item.run.exitCode -ne 0 -or $item.run.stdout.text -cne [string]$case.expectedStdout -or $item.run.stderr.byteCount -ne 0) { throw "C437 $($case.id) raw execution mismatch" }
                $item.llvmPath=Relative $ll; $item.llvmSha256=Hash $ll
                $item.llvmAs=Run-Tracked $llvmAsPath @($ll,'-o',(Join-Path $caseDir 'case.bc')) "C437 $($case.id) llvm-as" (Join-Path $caseDir 'llvm-as')
                if ($item.llvmAs.exitCode -ne 0 -or $item.llvmAs.stdout.byteCount -ne 0 -or $item.llvmAs.stderr.byteCount -ne 0) { throw "C437 $($case.id) llvm-as diagnostics" }
                $item.v004=Run-Tracked 'pwsh' @('-NoProfile','-File',$closurePath,'-LlvmPath',$ll) "C437 $($case.id) V004" (Join-Path $caseDir 'v004')
                if ($item.v004.exitCode -ne 0 -or $item.v004.stderr.byteCount -ne 0) { throw "C437 $($case.id) V004 failed" }
                $auditLl=Join-Path $caseDir 'case.audit.ll'
                $auditText=[IO.File]::ReadAllText($ll).Replace('call ptr @sollang_alloc(','call ptr @c437_audit_malloc(').Replace('call void @sollang_free(','call void @c437_audit_free(').Replace('call ptr @sollang_realloc(','call ptr @c437_audit_realloc(').Replace('@sollang_start()','@slg_program_main()')
                $auditText+="`ndeclare ptr @c437_audit_malloc(i64)`ndeclare void @c437_audit_free(ptr)`ndeclare ptr @c437_audit_realloc(ptr, i64)`n"; [IO.File]::WriteAllText($auditLl,$auditText,$utf8)
                $auditExe=Join-Path $caseDir 'case.audit.exe'
                $auditLink=Run-Tracked $clangPath @('-Wno-override-module',$auditLl,$allocationAuditPath,'-O1','-o',$auditExe,'-lws2_32','-lshell32','-lbcrypt') "C437 $($case.id) audit link" (Join-Path $caseDir 'audit-link')
                if ($auditLink.exitCode -ne 0 -or $auditLink.stdout.byteCount -ne 0 -or $auditLink.stderr.byteCount -ne 0) { throw "C437 $($case.id) audit link diagnostics" }
                $auditRun=Run-Tracked $auditExe @() "C437 $($case.id) allocation audit" (Join-Path $caseDir 'audit-run') $caseDir
                $match=[regex]::Match($auditRun.stdout.text,'(?m)^allocations=(?<a>\d+),releases=(?<r>\d+),invalid=(?<i>\d+)\r?$')
                $a=if($match.Success){[int]$match.Groups['a'].Value}else{-1};$r=if($match.Success){[int]$match.Groups['r'].Value}else{-1};$invalid=if($match.Success){[int]$match.Groups['i'].Value}else{-1}
                $item.audit=[ordered]@{link=$auditLink;execute=$auditRun;allocationCount=$a;releaseCount=$r;invalidReleaseCount=$invalid;balanced=($auditRun.exitCode-eq0-and$a-eq$r-and$invalid-eq0)}
                if (-not $item.audit.balanced -or $auditRun.stderr.byteCount -ne 0) { throw "C437 $($case.id) allocation audit failed" }
            }
            $item.status='passed';$item.passed=$true;$record.completed++
        }
    }
} catch {
    if($record.failureIds-notcontains'HARNESS_EXECUTION_FAILURE'){$record.failureIds+='HARNESS_EXECUTION_FAILURE'}
    Write-Error $_ -ErrorAction Continue
} finally {
    $manifestEnd=Snapshot-Stdlib;$inputEnd=Snapshot-Inputs $paths $manifestEnd
    $record.stdlibSourceCountEnd=$manifestEnd.entries.Count;$record.stdlibManifestEnd=$manifestEnd.entries;$record.stdlibManifestSha256End=$manifestEnd.sha256
    $record.stdlibManifestCountMatched=$record.stdlibSourceCountStart-eq$record.stdlibSourceCountEnd-and$record.stdlibSourceCountStart-eq$record.stdlibManifestStart.Count-and$record.stdlibSourceCountEnd-eq$record.stdlibManifestEnd.Count
    $record.stdlibManifestExact=$record.stdlibManifestCountMatched-and$record.stdlibManifestSha256Start-ceq$record.stdlibManifestSha256End-and(($record.stdlibManifestStart|ConvertTo-Json -Compress)-ceq($record.stdlibManifestEnd|ConvertTo-Json -Compress))
    $record.inputHashesEnd=$inputEnd;$record.inputDrift=@(Find-Drift $inputStart $inputEnd)
    $record.rootProcessIds=@($rootProcessIds|Sort-Object);$record.descendantProcessIds=@($descendantProcessIds|Sort-Object);$record.orphanProcessIds=@($orphanProcessIds|Sort-Object)
    $evidenceBound=$true
    foreach($item in $record.cases|Where-Object{$null-ne$_.compile}){
        $evidenceBound=$evidenceBound-and(Test-ProcessEvidence $item.compile)
        if($null-ne$item.run){$evidenceBound=$evidenceBound-and(Test-ProcessEvidence $item.run)}
        if($null-ne$item.llvmAs){$evidenceBound=$evidenceBound-and(Test-ProcessEvidence $item.llvmAs)}
        if($null-ne$item.v004){$evidenceBound=$evidenceBound-and(Test-ProcessEvidence $item.v004)}
        if($null-ne$item.audit){$evidenceBound=$evidenceBound-and(Test-ProcessEvidence $item.audit.link)-and(Test-ProcessEvidence $item.audit.execute)}
    }
    if(-not$evidenceBound-and$record.failureIds-notcontains'EVIDENCE_BINDING_FAILURE'){$record.failureIds+='EVIDENCE_BINDING_FAILURE'}
    if($record.inputDrift.Count-and$record.failureIds-notcontains'INPUT_DRIFT'){$record.failureIds+='INPUT_DRIFT'}
    if($record.orphanProcessIds.Count-and$record.failureIds-notcontains'ORPHAN_PROCESS'){$record.failureIds+='ORPHAN_PROCESS'}
    if(-not$record.stdlibManifestExact-and$record.failureIds-notcontains'STDLIB_MANIFEST_DRIFT'){$record.failureIds+='STDLIB_MANIFEST_DRIFT'}
    $fullPass=-not$ValidateOnly-and$record.completed-eq14-and$record.failureIds.Count-eq0-and$record.inputDrift.Count-eq0-and$record.orphanProcessIds.Count-eq0-and$record.stdlibManifestExact
    $record.currentSourceFreezeValidated=[bool]$SourceFreezeApproved-and$fullPass
    if($fullPass){$record.status='passed'}elseif(-not$ValidateOnly){$record.status='failed'}
    $resultPath=Join-Path $output 'result.json';$json=($record|ConvertTo-Json -Depth 100)+"`n";[IO.File]::WriteAllText($resultPath,$json,$utf8)
    if(-not($json|Test-Json -SchemaFile $resultSchemaPath -ErrorAction Stop)){throw 'C437 result schema rejected result'}
    Write-Host "[C437 current source] $($record.status) $($record.completed)/14; result=$resultPath"
}
if($record.status-eq'failed'){exit 1}
