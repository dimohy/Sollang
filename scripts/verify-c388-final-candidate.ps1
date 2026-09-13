[CmdletBinding()]
param(
    [string]$CandidateCompiler = '',
    [string]$ExpectedCompilerSha256 = '',
    [string]$OutputDirectory = '',
    [switch]$ValidateInputsOnly,
    [switch]$ValidateSchemaControlsOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'verification-process.ps1')

function Repo([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $root $Path))
}
function Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Hash-Bytes([byte[]]$Bytes) { return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)) }
function Get-C388InputDrift($StartHashes, $EndHashes, [string[]]$Keys) {
    return @($Keys | Where-Object {
        -not $StartHashes.Contains($_) -or -not $EndHashes.Contains($_) -or $StartHashes[$_] -cne $EndHashes[$_]
    })
}

$schemaPath = Repo 'scripts/contracts/c388-final-candidate-result.schema.json'
$emptySha = Hash-Bytes ([byte[]]::new(0))
$inputKeys = @(
    'compiler','verifier','schema','parityContract','paritySchema','parityVerifier','processHelper','closureVerifier',
    'v004Undefined','v004CrossFunction','v004Forward','v004CommentString','v004Parameter',
    'sharedAuthority','entryConsumer','functionConsumer','regionConsumer',
    'fixture1704','expected1704','fixture1218','expected1218','sequence','llvmAs','clang'
)
$invocationIds = @(
    'parity-contract','v004-undefined','v004-cross-function','v004-forward','v004-comment-string','v004-parameter',
    'typed-ir-sequential','typed-ir-parallel',
    '1704-compile','1704-llvm-as','1704-v004','1704-link','1704-native',
    '1218-compile','1218-llvm-as','1218-v004','1218-link','1218-native'
)

function New-C388SchemaControlRecord([string]$Status = 'passed') {
    $hashes = [ordered]@{}
    foreach ($key in $inputKeys) { $hashes[$key] = 'A' * 64 }
    $audits = foreach ($id in $invocationIds) {
        $expectedExit = if ($id -in @('v004-undefined','v004-cross-function')) { 1 } else { 0 }
        [ordered]@{
            id=$id; rootProcessId=1; descendantProcessIds=@(); orphanProcessIds=@(); rootTerminated=$true; timedOut=$false
            expectedExitCode=$expectedExit; exitCode=$expectedExit; exitMatched=$true
            stdoutPath="invocations/$id.stdout.bin"; stdoutSha256='B'*64; stdoutBytes=1
            stderrPath="invocations/$id.stderr.bin"; stderrSha256='C'*64; stderrBytes=1; warningNoteCount=0
        }
    }
    return [ordered]@{
        schemaVersion=2; defectId='C2026-09-12-388'; status=$Status
        compilerSha256='A'*64; expectedCompilerSha256='A'*64; candidateShaMatched=$true
        inputStable=$true; inputHashesEqual=$true; inputDrift=@(); inputHashesStart=$hashes; inputHashesEnd=$hashes
        threeConsumerContract=[ordered]@{completed=3;total=3;exitCode=0;consumerCount=3;sequentialHelperDefinitions=2;parallelHelperDefinitions=1;v004ControlsCompleted=5;v004ControlsTotal=5}
        modeParity=[ordered]@{completed=2;total=2;sourceCount=3;nodeCount=389;exitCode=0}
        fixtures=@(
            [ordered]@{id='1704-selfhost-control-region-sequential-branch';compileExit=0;llvmAsExit=0;v004Exit=0;linkExit=0;nativeExit=0;stdoutSha256='D'*64;expectedStdoutSha256='D'*64;stdoutBytes=3;expectedStdoutBytes=3;stdoutExact=$true;stderrSha256=$emptySha;warningNoteCount=0;llvmSha256='E'*64;executableSha256='F'*64},
            [ordered]@{id='1218-ai-slg-best-practices';compileExit=0;llvmAsExit=0;v004Exit=0;linkExit=0;nativeExit=0;stdoutSha256='1'*64;expectedStdoutSha256='1'*64;stdoutBytes=18;expectedStdoutBytes=18;stdoutExact=$true;stderrSha256=$emptySha;warningNoteCount=0;llvmSha256='2'*64;executableSha256='3'*64}
        )
        processAudits=@($audits); failureIds=@(); failure=$null
    }
}

function Assert-C388SchemaControls {
    $positive = New-C388SchemaControlRecord
    if (-not (($positive | ConvertTo-Json -Depth 12) | Test-Json -SchemaFile $schemaPath -ErrorAction Stop)) { throw 'C388 schema rejected the canonical positive control' }
    $failedPositive = (($positive | ConvertTo-Json -Depth 12) | ConvertFrom-Json -AsHashtable -Depth 12)
    $failedPositive.status='failed'; $failedPositive.failureIds=@('C388_FOCUSED_FAILED'); $failedPositive.failure='focused failure'
    if (-not (($failedPositive | ConvertTo-Json -Depth 12) | Test-Json -SchemaFile $schemaPath -ErrorAction Stop)) { throw 'C388 schema rejected the canonical failed control' }
    $equalityStart=[ordered]@{}; foreach($key in $inputKeys){$equalityStart[$key]='A'*64}; $equalityEnd=[ordered]@{}; foreach($key in $inputKeys){$equalityEnd[$key]=$equalityStart[$key]}; $equalityEnd.compiler='B'*64
    if ((Get-C388InputDrift $equalityStart $equalityEnd $inputKeys) -cne 'compiler') { throw 'C388 input equality control did not detect compiler drift' }
    $negativeControls = [Collections.Generic.List[object]]::new()
    foreach ($mutation in @('missing-input','extra-input','unequal-input','unstable-input','wrong-exit','orphan','warning','duplicate-invocation','empty-failure')) {
        $record = (($positive | ConvertTo-Json -Depth 12) | ConvertFrom-Json -Depth 12)
        switch ($mutation) {
            'missing-input' { $record.inputHashesStart.psobject.Properties.Remove('compiler') }
            'extra-input' { $record.inputHashesStart | Add-Member -NotePropertyName forged -NotePropertyValue ('4'*64) }
            'unequal-input' { $record.inputHashesEnd.compiler='B'*64; $record.inputHashesEqual=$false; $record.inputStable=$false; $record.inputDrift=@('compiler') }
            'unstable-input' { $record.inputStable = $false }
            'wrong-exit' { $record.processAudits[0].exitCode = 9 }
            'orphan' { $record.processAudits[0].orphanProcessIds = @(99) }
            'warning' { $record.processAudits[0].warningNoteCount = 1 }
            'duplicate-invocation' { $record.processAudits[17].id = $record.processAudits[16].id }
            'empty-failure' { $record.status='failed'; $record.failure='failed'; $record.failureIds=@() }
        }
        $negativeControls.Add([pscustomobject]@{ id=$mutation; record=$record })
    }
    foreach ($control in $negativeControls) {
        if (($control.record | ConvertTo-Json -Depth 12) | Test-Json -SchemaFile $schemaPath -ErrorAction SilentlyContinue) { throw "C388 schema accepted forged control $($control.id)" }
    }
    Write-Host "[C388 schema controls] PASS passed/failed positive 2/2; negatives $($negativeControls.Count)/$($negativeControls.Count); hash equality 1/1"
}

if ($ValidateSchemaControlsOnly) { Assert-C388SchemaControls; return }
if ([string]::IsNullOrWhiteSpace($CandidateCompiler) -or $ExpectedCompilerSha256 -notmatch '^[A-Fa-f0-9]{64}$' -or [string]::IsNullOrWhiteSpace($OutputDirectory)) { throw 'C388 requires -CandidateCompiler, 64-hex -ExpectedCompilerSha256, and -OutputDirectory' }

$candidate = (Resolve-Path -LiteralPath (Repo $CandidateCompiler)).Path
if (-not $candidate.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'C388 candidate must be repository-contained' }
$ExpectedCompilerSha256 = $ExpectedCompilerSha256.ToUpperInvariant()
$output = Repo $OutputDirectory
if (-not $output.StartsWith((Repo 'artifacts/scratch') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'C388 output must be under artifacts/scratch' }
if ((Test-Path -LiteralPath $output) -and @(Get-ChildItem -LiteralPath $output -Force).Count -ne 0) { throw 'C388 output must be new or empty' }
[IO.Directory]::CreateDirectory($output) | Out-Null
[IO.Directory]::CreateDirectory((Join-Path $output 'invocations')) | Out-Null

$inputs = [ordered]@{
    compiler=$candidate; verifier=[IO.Path]::GetFullPath($PSCommandPath); schema=$schemaPath
    parityContract=Repo 'scripts/contracts/expression-lowering-parity.json'; paritySchema=Repo 'scripts/contracts/expression-lowering-parity.schema.json'; parityVerifier=Repo 'scripts/verify-expression-lowering-parity.ps1'
    processHelper=Repo 'scripts/verification-process.ps1'; closureVerifier=Repo 'scripts/verify-llvm-direct-call-closure.ps1'
    v004Undefined=Repo 'scripts/contracts/fixtures/v004-undefined-generated-ssa.ll'; v004CrossFunction=Repo 'scripts/contracts/fixtures/v004-cross-function-generated-ssa.ll'; v004Forward=Repo 'scripts/contracts/fixtures/v004-forward-generated-ssa.ll'; v004CommentString=Repo 'scripts/contracts/fixtures/v004-comment-string-generated-ssa.ll'; v004Parameter=Repo 'scripts/contracts/fixtures/v004-parameter-generated-ssa.ll'
    sharedAuthority=Repo 'selfhost/llvm/text/control_region_expressions.slg'; entryConsumer=Repo 'selfhost/llvm/text/entry_expressions.slg'; functionConsumer=Repo 'selfhost/llvm/text/functions.slg'; regionConsumer=Repo 'selfhost/llvm/text/control_region_expressions.slg'
    fixture1704=Repo 'examples/regression/1704-selfhost-control-region-sequential-branch.slg'; expected1704=Repo 'examples/regression/expected/1704-selfhost-control-region-sequential-branch.stdout.txt'
    fixture1218=Repo 'examples/regression/1218-ai-slg-best-practices.slg'; expected1218=Repo 'examples/regression/expected/1218-ai-slg-best-practices.stdout.txt'; sequence=Repo 'stdlib/std/sequence.slg'
    llvmAs=Repo '.tools/llvm-22.1.8/bin/llvm-as.exe'; clang=Repo '.tools/llvm-22.1.8/bin/clang.exe'
}
if (($inputs.Keys -join '|') -cne ($inputKeys -join '|')) { throw 'C388 exact 24-key input authority drifted' }
$start = [ordered]@{}; foreach ($entry in $inputs.GetEnumerator()) { $start[$entry.Key] = Hash $entry.Value }
if ($start.compiler -cne $ExpectedCompilerSha256) { throw "C388 compiler hash mismatch expected=$ExpectedCompilerSha256 actual=$($start.compiler)" }
$contract = [IO.File]::ReadAllText($inputs.parityContract) | ConvertFrom-Json
if (@($contract.branchMaterialization.consumers).Count -ne 3 -or $contract.branchMaterialization.sharedAggregateEmitter -cne 'emitSequentialBranchAggregate' -or $contract.branchMaterialization.sharedArmEmitter -cne 'emitSequentialBranchArmValue' -or $contract.branchMaterialization.sharedParallelEmitter -cne 'emitParallelBranchValue') { throw 'C388 three-consumer contract drifted' }
if ($ValidateInputsOnly) { Assert-C388SchemaControls; Write-Host "[C388 input preflight] PASS compiler=$($start.compiler) inputs=24"; return }

$processAudits = [Collections.Generic.List[object]]::new()
function Get-C388Descendants([int]$RootProcessId) {
    $records = @(Get-CimInstance Win32_Process | Select-Object ProcessId,ParentProcessId)
    $found = [Collections.Generic.HashSet[int]]::new(); $frontier = @($RootProcessId)
    while ($frontier.Count -gt 0) {
        $children = @($records | Where-Object { $frontier -contains [int]$_.ParentProcessId }); $frontier = @()
        foreach ($child in $children) { $id=[int]$child.ProcessId; if ($found.Add($id)) { $frontier += $id } }
    }
    return @($found | Sort-Object)
}
function Invoke-C388RawProcess([string]$Id,[string]$File,[string[]]$Arguments,[int]$ExpectedExitCode,[int]$TimeoutMilliseconds=120000) {
    if (-not $IsWindows) { throw 'C388 process-tree authority currently requires Windows' }
    $stdoutRelative="invocations/$Id.stdout.bin"; $stderrRelative="invocations/$Id.stderr.bin"
    $stdoutPath=Join-Path $output ($stdoutRelative-replace'/',[IO.Path]::DirectorySeparatorChar); $stderrPath=Join-Path $output ($stderrRelative-replace'/',[IO.Path]::DirectorySeparatorChar)
    $startInfo=[Diagnostics.ProcessStartInfo]::new(); $startInfo.FileName=$File; $startInfo.WorkingDirectory=$root; $startInfo.UseShellExecute=$false; $startInfo.CreateNoWindow=$true; $startInfo.RedirectStandardOutput=$true; $startInfo.RedirectStandardError=$true
    foreach($argument in $Arguments){[void]$startInfo.ArgumentList.Add($argument)}
    $process=[Diagnostics.Process]::new(); $process.StartInfo=$startInfo; $descendants=[Collections.Generic.HashSet[int]]::new(); $timedOut=$false; $stdoutStream=$null; $stderrStream=$null
    try {
        if(-not$process.Start()){throw "C388 invocation could not start: $Id"}; $rootProcessId=$process.Id
        $stdoutStream=[IO.File]::Open($stdoutPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read); $stderrStream=[IO.File]::Open($stderrPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
        $stdoutTask=$process.StandardOutput.BaseStream.CopyToAsync($stdoutStream); $stderrTask=$process.StandardError.BaseStream.CopyToAsync($stderrStream); $deadline=[DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
        while(-not$process.WaitForExit(50)){foreach($idFound in @(Get-C388Descendants $rootProcessId)){[void]$descendants.Add($idFound)};if((Test-VerificationCancellationRequested)-or[DateTimeOffset]::UtcNow-ge$deadline){$timedOut=$true;break}}
        foreach($idFound in @(Get-C388Descendants $rootProcessId)){[void]$descendants.Add($idFound)}
        if($timedOut-and-not$process.HasExited){$process.Kill($true)};if(-not$process.WaitForExit(5000)){throw "C388 invocation tree did not terminate: $Id"};$process.WaitForExit();$stdoutTask.GetAwaiter().GetResult();$stderrTask.GetAwaiter().GetResult()
        $stdoutStream.Flush();$stderrStream.Flush();$stdoutStream.Dispose();$stdoutStream=$null;$stderrStream.Dispose();$stderrStream=$null
        $orphanIds=@($descendants|Where-Object{$null-ne(Get-Process -Id $_ -ErrorAction SilentlyContinue)}|Sort-Object);$stdoutBytes=[IO.File]::ReadAllBytes($stdoutPath);$stderrBytes=[IO.File]::ReadAllBytes($stderrPath);$strictUtf8=[Text.UTF8Encoding]::new($false,$true);$stdoutText=$strictUtf8.GetString($stdoutBytes);$stderrText=$strictUtf8.GetString($stderrBytes);$exitCode=$process.ExitCode
        $audit=[ordered]@{id=$Id;rootProcessId=$rootProcessId;descendantProcessIds=@($descendants|Sort-Object);orphanProcessIds=$orphanIds;rootTerminated=$true;timedOut=$timedOut;expectedExitCode=$ExpectedExitCode;exitCode=$exitCode;exitMatched=$exitCode-eq$ExpectedExitCode;stdoutPath=$stdoutRelative;stdoutSha256=Hash-Bytes $stdoutBytes;stdoutBytes=$stdoutBytes.Length;stderrPath=$stderrRelative;stderrSha256=Hash-Bytes $stderrBytes;stderrBytes=$stderrBytes.Length;warningNoteCount=[regex]::Matches($stdoutText+$stderrText,'(?im)\b(?:warning|note)\b').Count}
        $processAudits.Add($audit);if($timedOut-or$orphanIds.Count-ne0-or-not$audit.exitMatched-or$audit.warningNoteCount-ne0){throw "C388 invocation audit failed: $Id"}
        return [pscustomobject]@{Audit=$audit;StdoutBytes=$stdoutBytes;StderrBytes=$stderrBytes;Stdout=$stdoutText;Stderr=$stderrText}
    } finally {if($null-ne$stdoutStream){$stdoutStream.Dispose()};if($null-ne$stderrStream){$stderrStream.Dispose()};$process.Dispose()}
}

$three=[ordered]@{completed=0;total=3;exitCode=$null;consumerCount=0;sequentialHelperDefinitions=0;parallelHelperDefinitions=0;v004ControlsCompleted=0;v004ControlsTotal=5};$mode=[ordered]@{completed=0;total=2;sourceCount=0;nodeCount=0;exitCode=$null};$fixtures=[Collections.Generic.List[object]]::new();$failureIds=[Collections.Generic.List[string]]::new();$failure=$null
try {
    $static=Invoke-C388RawProcess 'parity-contract' 'pwsh' @('-NoProfile','-File',$inputs.parityVerifier) 0;$three.exitCode=$static.Audit.exitCode;if($static.StderrBytes.Length-ne0-or$static.Stdout-notmatch'42/42'){throw 'C388 schema/static contract failed'}
    $authority=[IO.File]::ReadAllText($inputs.sharedAuthority);$three.sequentialHelperDefinitions=[regex]::Matches($authority,'(?m)^emitSequentialBranch(?:ArmValue|Aggregate)\s').Count;$three.parallelHelperDefinitions=[regex]::Matches($authority,'(?m)^emitParallelBranchValue\s').Count
    foreach($consumer in @($contract.branchMaterialization.consumers)){$text=[IO.File]::ReadAllText((Repo $consumer));if($text-notmatch'(?s)kind == 37.*?emitSequentialBranchAggregate'-or$text-notmatch'(?s)kind == 39.*?emitSequentialBranchArmValue'-or$text-notmatch'(?s)kind == 38 and context\.supportsComputePool.*?emitParallelBranchValue'){throw "C388 consumer bypasses shared authority: $consumer"};$three.consumerCount++};if($three.sequentialHelperDefinitions-ne2-or$three.parallelHelperDefinitions-ne1){throw 'C388 helper definition count failed'}
    foreach($control in @(@('v004-undefined',$inputs.v004Undefined),@('v004-cross-function',$inputs.v004CrossFunction))){$run=Invoke-C388RawProcess $control[0] 'pwsh' @('-NoProfile','-File',$inputs.closureVerifier,'-LlvmPath',$control[1]) 1;if(($run.Stdout+$run.Stderr)-notmatch'V004: emitted LLVM uses generated SSA values without definitions'){throw "C388 V004 negative diagnostic mismatch: $($control[0])"};$three.v004ControlsCompleted++}
    foreach($control in @(@('v004-forward',$inputs.v004Forward),@('v004-comment-string',$inputs.v004CommentString),@('v004-parameter',$inputs.v004Parameter))){$run=Invoke-C388RawProcess $control[0] 'pwsh' @('-NoProfile','-File',$inputs.closureVerifier,'-LlvmPath',$control[1]) 0;if($run.StderrBytes.Length-ne0){throw "C388 V004 positive emitted stderr: $($control[0])"};$three.v004ControlsCompleted++};$three.completed=3
    $sources=@($inputs.fixture1704,$inputs.fixture1218,$inputs.sequence);$seq=Invoke-C388RawProcess 'typed-ir-sequential' $candidate (@('typed-ir-nodes')+$sources) 0;$par=Invoke-C388RawProcess 'typed-ir-parallel' $candidate (@('typed-ir-nodes-parallel')+$sources) 0;$mode.exitCode=0;$sl=@($seq.Stdout.Replace("`r`n","`n").TrimEnd("`n")-split"`n");$pl=@($par.Stdout.Replace("`r`n","`n").TrimEnd("`n")-split"`n");if($seq.StderrBytes.Length-ne0-or$par.StderrBytes.Length-ne0-or($sl-join"`n")-cne($pl-join"`n")){throw 'C388 Typed IR identity failed'};$mode.sourceCount=3;$mode.nodeCount=$sl.Count;$mode.completed=2
    foreach($case in @(@{short='1704';id='1704-selfhost-control-region-sequential-branch';source=@($inputs.fixture1704);expected=$inputs.expected1704},@{short='1218';id='1218-ai-slg-best-practices';source=@($inputs.fixture1218,$inputs.sequence);expected=$inputs.expected1218})){
        $item=[ordered]@{id=$case.id;compileExit=$null;llvmAsExit=$null;v004Exit=$null;linkExit=$null;nativeExit=$null;stdoutSha256=$emptySha;expectedStdoutSha256=Hash $case.expected;stdoutBytes=0;expectedStdoutBytes=(Get-Item $case.expected).Length;stdoutExact=$false;stderrSha256=$emptySha;warningNoteCount=0;llvmSha256=$null;executableSha256=$null};$ll=Join-Path $output "$($case.id).ll";$bc=Join-Path $output "$($case.id).bc";$exe=Join-Path $output "$($case.id).exe"
        $compile=Invoke-C388RawProcess "$($case.short)-compile" $candidate (@('windows')+$case.source) 0;$item.compileExit=$compile.Audit.exitCode;[IO.File]::WriteAllBytes($ll,$compile.StdoutBytes);if($compile.StderrBytes.Length-ne0-or$compile.Stdout-notmatch'target datalayout'){throw "C388 $($case.id) compile failed"}
        $as=Invoke-C388RawProcess "$($case.short)-llvm-as" $inputs.llvmAs @($ll,'-o',$bc) 0;$item.llvmAsExit=$as.Audit.exitCode;$v=Invoke-C388RawProcess "$($case.short)-v004" 'pwsh' @('-NoProfile','-File',$inputs.closureVerifier,'-LlvmPath',$ll) 0;$item.v004Exit=$v.Audit.exitCode;$link=Invoke-C388RawProcess "$($case.short)-link" $inputs.clang @('-Wno-override-module',$ll,'-O1','-o',$exe,'-lws2_32','-lshell32','-lbcrypt') 0;$item.linkExit=$link.Audit.exitCode
        $native=Invoke-C388RawProcess "$($case.short)-native" $exe @() 0;$item.nativeExit=$native.Audit.exitCode;$item.stdoutSha256=$native.Audit.stdoutSha256;$item.stdoutBytes=$native.Audit.stdoutBytes;$item.stderrSha256=$native.Audit.stderrSha256;$item.warningNoteCount=$compile.Audit.warningNoteCount+$as.Audit.warningNoteCount+$v.Audit.warningNoteCount+$link.Audit.warningNoteCount+$native.Audit.warningNoteCount;$item.stdoutExact=$item.stdoutSha256-ceq$item.expectedStdoutSha256-and$item.stdoutBytes-eq$item.expectedStdoutBytes;$item.llvmSha256=Hash $ll;$item.executableSha256=Hash $exe;if(-not$item.stdoutExact-or$native.StderrBytes.Length-ne0-or$item.warningNoteCount-ne0){throw "C388 $($case.id) native exact failed"};$fixtures.Add($item)
    }
}catch{$failure=$_.Exception.Message;[void]$failureIds.Add('C388_FOCUSED_FAILED');if($failure-match'(?i)invocation (?:audit|tree)|process audit'){[void]$failureIds.Add('C388_PROCESS_AUDIT_FAILED')}}
$end=[ordered]@{};foreach($entry in $inputs.GetEnumerator()){try{$end[$entry.Key]=Hash $entry.Value}catch{$end[$entry.Key]='0'*64}};$drift=@(Get-C388InputDrift $start $end $inputKeys);$inputHashesEqual=$drift.Count-eq0;if(-not$inputHashesEqual){[void]$failureIds.Add('C388_INPUT_DRIFT');if($null-eq$failure){$failure='C388 input drift'}};if($processAudits.Count-ne18){[void]$failureIds.Add('C388_PROCESS_AUDIT_INCOMPLETE');if($null-eq$failure){$failure='C388 process audit incomplete'}};$failureIds=@($failureIds|Select-Object -Unique)
$record=[ordered]@{schemaVersion=2;defectId='C2026-09-12-388';status=if($failureIds.Count){'failed'}else{'passed'};compilerSha256=$start.compiler;expectedCompilerSha256=$ExpectedCompilerSha256;candidateShaMatched=$start.compiler-ceq$ExpectedCompilerSha256-and$end.compiler-ceq$ExpectedCompilerSha256;inputStable=$drift.Count-eq0;inputHashesEqual=$inputHashesEqual;inputDrift=@($drift);inputHashesStart=$start;inputHashesEnd=$end;threeConsumerContract=$three;modeParity=$mode;fixtures=@($fixtures);processAudits=@($processAudits);failureIds=$failureIds;failure=if($failureIds.Count){$failure}else{$null}};$result=Join-Path $output 'result.json';$json=($record|ConvertTo-Json -Depth 12)+"`n";[IO.File]::WriteAllText($result,$json,[Text.UTF8Encoding]::new($false));if(-not($json|Test-Json -SchemaFile $inputs.schema -ErrorAction Stop)){throw 'C388 result schema rejected result'};if($record.status-ne'passed'){throw "C388 focused failed: $failure; result=$result"};Write-Host "[C388 final candidate] PASS contract 3/3; V004 controls 5/5; mode 2/2 nodes=389; fixtures 2/2; processes 18/18 orphan=0; result=$result"
