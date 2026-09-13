[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory)][string]$CompilerPath,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCompilerSha256,
    [string]$OutputDirectory = '',
    [string]$PythonPath = '',
    [string]$WslDistribution = 'Ubuntu',
    [string]$ResumeNativeResultPath = '',
    [switch]$ContractOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$scratch = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory = Join-Path $scratch ('zip-stored-writer-' + [guid]::NewGuid().ToString('N')) }
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (-not ($output + [IO.Path]::DirectorySeparatorChar).StartsWith($scratch.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "ZIP writer output must be under artifacts/scratch: $output" }
if (Test-Path -LiteralPath $output) {
    if (-not (Test-Path -LiteralPath $output -PathType Container) -or @(Get-ChildItem -LiteralPath $output -Force).Count -ne 0) { throw "ZIP writer output must be new or empty: $output" }
}
[IO.Directory]::CreateDirectory($output) | Out-Null

$compiler = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($CompilerPath)) { $CompilerPath } else { Join-Path $root $CompilerPath }))
$resumeResult = if ([string]::IsNullOrWhiteSpace($ResumeNativeResultPath)) { $null } else { [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($ResumeNativeResultPath)) { $ResumeNativeResultPath } else { Join-Path $root $ResumeNativeResultPath })) }
$ExpectedCompilerSha256 = $ExpectedCompilerSha256.ToUpperInvariant()
$pythonCommand = if ([string]::IsNullOrWhiteSpace($PythonPath)) { Get-Command python -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 } else { $null }
$python = if ([string]::IsNullOrWhiteSpace($PythonPath)) { if ($null -eq $pythonCommand) { 'unavailable' } else { $pythonCommand.Source } } else { [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($PythonPath)) { $PythonPath } else { Join-Path $root $PythonPath })) }
$contractPath = Join-Path $root 'scripts/contracts/zip-stored-writer.json'
$contractSchemaPath = Join-Path $root 'scripts/contracts/zip-stored-writer.schema.json'
$resultSchemaPath = Join-Path $root 'scripts/contracts/zip-stored-writer-result.schema.json'
$fixturePath = Join-Path $root 'examples/regression/1755-zip-stored-streaming-writer.slg'
$expectedPath = Join-Path $root 'examples/regression/expected/1755-zip-stored-streaming-writer.stdout.txt'
$browserFixturePath = Join-Path $root 'scripts/probes/zip-stored-writer/browser-focused.slg'
$browserExpectedPath = Join-Path $root 'scripts/probes/zip-stored-writer/browser-focused.stdout.txt'
$zipSource = Join-Path $root 'stdlib/std/archive/zip.slg'
$errorSource = Join-Path $root 'stdlib/std/archive/zip/error.slg'
$phaseSource = Join-Path $root 'stdlib/std/archive/zip/encoder_phase.slg'
$decoderPhaseSource = Join-Path $root 'stdlib/std/archive/zip/decoder_phase.slg'
$formatVerifier = Join-Path $root 'scripts/format-authoritative-slg.ps1'
$closureVerifier = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$browserRunner = Join-Path $root 'scripts/verify-browser-program.mjs'
$fieldMigrationVerifier = Join-Path $root 'scripts/verify-struct-field-migration.ps1'
$llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
$llvmAs = Join-Path $llvmRoot 'bin/llvm-as.exe'
$pwsh = @((Get-Command pwsh -CommandType Application -ErrorAction Stop))[0].Source
$wsl = @((Get-Command wsl.exe -CommandType Application -ErrorAction Stop))[0].Source
$nodeCommand = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$node = if ($null -eq $nodeCommand) { 'unavailable' } else { $nodeCommand.Source }
$compilerExtension = [IO.Path]::GetExtension($compiler).ToLowerInvariant()
$dotnetCommand = if ($compilerExtension -ceq '.dll') { Get-Command dotnet -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 } else { $null }
$dotnet = if ($null -eq $dotnetCommand) { 'unavailable' } else { $dotnetCommand.Source }

function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Hash-Bytes([byte[]]$Bytes) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)) }
function Bytes-Equal([byte[]]$Left,[byte[]]$Right) { $Left.Length-eq$Right.Length-and(Hash-Bytes $Left)-ceq(Hash-Bytes $Right) }
function Snapshot($Paths) { $map = [ordered]@{}; foreach ($entry in $Paths.GetEnumerator()) { $map[$entry.Key] = if (Test-Path -LiteralPath $entry.Value -PathType Leaf) { Hash $entry.Value } else { $null } }; $map }
function Empty-Check([string]$Optimization) { [ordered]@{ optimization=$Optimization;status='not-run';stdoutSha256=$null;stdoutBytes=$null;llvmSha256=$null;bitcodeSha256=$null;artifactSha256=$null;warningCount=$null;noteCount=$null } }
function Wsl-Path([string]$Path) { $full=[IO.Path]::GetFullPath($Path);'/mnt/'+$full.Substring(0,1).ToLowerInvariant()+$full.Substring(2).Replace('\','/') }
function Descendants([int]$RootProcessId) {
    $records=@(Get-CimInstance Win32_Process -ErrorAction Stop);$ids=[Collections.Generic.HashSet[int]]::new();[void]$ids.Add($RootProcessId);$changed=$true
    while($changed){$changed=$false;foreach($record in $records){if($ids.Contains([int]$record.ParentProcessId)-and$ids.Add([int]$record.ProcessId)){$changed=$true}}}
    @($ids|Where-Object{$_-ne$RootProcessId}|Sort-Object -Unique)
}
function Run-Process([string]$Id,[string]$FilePath,[string[]]$Arguments) {
    $start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=$FilePath;$start.WorkingDirectory=$root;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    foreach($argument in $Arguments){[void]$start.ArgumentList.Add($argument)}
    $process=[Diagnostics.Process]::new();$process.StartInfo=$start
    try {
        if(-not$process.Start()){throw "$Id did not start"};$rootProcessId=$process.Id;$observed=[Collections.Generic.HashSet[int]]::new();$stdoutStream=[IO.MemoryStream]::new();$stderrStream=[IO.MemoryStream]::new();$stdout=$process.StandardOutput.BaseStream.CopyToAsync($stdoutStream);$stderr=$process.StandardError.BaseStream.CopyToAsync($stderrStream);$deadline=[DateTimeOffset]::UtcNow.AddSeconds(180)
        while(-not$process.WaitForExit(20)-and[DateTimeOffset]::UtcNow-lt$deadline){foreach($idValue in @(Descendants $rootProcessId)){[void]$observed.Add($idValue)}}
        if(-not$process.HasExited){$process.Kill($true);$process.WaitForExit();throw "$Id exceeded 180000ms"};$process.WaitForExit();foreach($idValue in @(Descendants $rootProcessId)){[void]$observed.Add($idValue)}
        $stdout.GetAwaiter().GetResult() | Out-Null;$stderr.GetAwaiter().GetResult() | Out-Null;$stdoutBytes=$stdoutStream.ToArray();$stderrBytes=$stderrStream.ToArray();$safe=$Id-replace'[^A-Za-z0-9_.-]','-';$stdoutPath=Join-Path $output "$safe.stdout.bin";$stderrPath=Join-Path $output "$safe.stderr.bin"
        [IO.File]::WriteAllBytes($stdoutPath,$stdoutBytes);[IO.File]::WriteAllBytes($stderrPath,$stderrBytes)
        $descendantIds=@($observed|Sort-Object -Unique);$orphans=@($descendantIds|Where-Object{Get-Process -Id $_ -ErrorAction SilentlyContinue})
        $artifact=[ordered]@{id=$Id;exitCode=$process.ExitCode;rootProcessId=$rootProcessId;descendantProcessIds=$descendantIds;orphanProcessIds=@($orphans);stdoutPath=[IO.Path]::GetRelativePath($root,$stdoutPath).Replace('\','/');stderrPath=[IO.Path]::GetRelativePath($root,$stderrPath).Replace('\','/');stdoutSha256=Hash $stdoutPath;stderrSha256=Hash $stderrPath;stdoutBytes=$stdoutBytes.Length;stderrBytes=$stderrBytes.Length}
        $script:record.processAudit.rootProcessIds+= $rootProcessId;$script:record.processAudit.descendantProcessIds+= $descendantIds;$script:record.processAudit.orphanProcessIds+=@($orphans);$script:record.processAudit.invocations+=$artifact
        [pscustomobject]@{ExitCode=$process.ExitCode;StdoutBytes=$stdoutBytes;StderrBytes=$stderrBytes;Artifact=$artifact}
    } finally {$process.Dispose()}
}
function Require-Success($Run,[string]$Id,[switch]$RejectDiagnostics){if($Run.ExitCode-ne 0-or$Run.StderrBytes.Length-ne 0-or@($Run.Artifact.orphanProcessIds).Count-ne 0){$script:failureId=$Id;throw "$($Run.Artifact.id) failed exit=$($Run.ExitCode) stderrBytes=$($Run.StderrBytes.Length) orphans=$(@($Run.Artifact.orphanProcessIds).Count)"};if($RejectDiagnostics){$text=[Text.Encoding]::UTF8.GetString($Run.StdoutBytes);if($text-match'(?im)(?:^|\r?\n)\s*(?:warning|note)\b'){$script:failureId=$Id;throw "$($Run.Artifact.id) emitted warning/note"}}}
function Compiler-Run([string]$Id,[string[]]$Arguments){if($script:record.compilerDispatch-ceq'dotnet'){Run-Process $Id $dotnet (@($compiler)+$Arguments)}else{Run-Process $Id $compiler $Arguments}}
function Normalize-ProcessAudit($Target) {
    $Target.rootProcessIds=@($Target.rootProcessIds|Sort-Object -Unique)
    $Target.descendantProcessIds=@($Target.descendantProcessIds|Sort-Object -Unique)
    $Target.orphanProcessIds=@($Target.orphanProcessIds|Sort-Object -Unique)
    foreach($invocation in @($Target.invocations)){$invocation.descendantProcessIds=@($invocation.descendantProcessIds|Sort-Object -Unique);$invocation.orphanProcessIds=@($invocation.orphanProcessIds|Sort-Object -Unique)}
}
function Save-Result { Normalize-ProcessAudit $script:record.processAudit;$script:record.schemaControls.duplicateNormalizationAccepted=$true;$json=($script:record|ConvertTo-Json -Depth 20)+"`n";if(-not($json|Test-Json -SchemaFile $resultSchemaPath)){throw 'ZIP writer result schema rejected verifier output'};[IO.File]::WriteAllText((Join-Path $output 'result.json'),$json,[Text.UTF8Encoding]::new($false)) }

$negativeSources=@('affine-finish-reuse','private-state'|ForEach-Object{Join-Path $root "scripts/probes/zip-stored-writer/$_.slg"})
$negativeExpected=@('affine-finish-reuse','private-state'|ForEach-Object{Join-Path $root "scripts/probes/zip-stored-writer/$_.stderr.contains.txt"})
$paths=[ordered]@{compiler=$compiler;contract=$contractPath;contractSchema=$contractSchemaPath;resultSchema=$resultSchemaPath;verifier=$PSCommandPath;python=$python;fixture=$fixturePath;expected=$expectedPath;browserFixture=$browserFixturePath;browserExpected=$browserExpectedPath;zipSource=$zipSource;errorSource=$errorSource;encoderPhase=$phaseSource;decoderPhase=$decoderPhaseSource;formatter=$formatVerifier;closure=$closureVerifier;browserRunner=$browserRunner;fieldMigration=$fieldMigrationVerifier;llvmAs=$llvmAs;pwsh=$pwsh;wsl=$wsl;node=$node;negativeReuse=$negativeSources[0];negativeReuseExpected=$negativeExpected[0];negativePrivate=$negativeSources[1];negativePrivateExpected=$negativeExpected[1]}
if($null-ne$resumeResult){$paths.resumeNativeResult=$resumeResult}
foreach($source in @(Get-ChildItem -LiteralPath (Join-Path $root 'stdlib') -Recurse -File -Filter '*.slg'|Sort-Object FullName)){$paths['stdlib:'+[IO.Path]::GetRelativePath($root,$source.FullName).Replace('\','/')]=$source.FullName}
$record=[ordered]@{schemaVersion=1;mode='zip-stored-streaming-writer-focused';status='failed';completed=0;total=6;failureIds=@();compilerPath=$compiler;expectedCompilerSha256=$ExpectedCompilerSha256;compilerSha256Start=$null;compilerSha256End=$null;compilerDispatch='unavailable';inputStable=$false;inputDrift=@();inputHashesStart=[ordered]@{bootstrap=$null};inputHashesEnd=[ordered]@{bootstrap=$null};windows=[ordered]@{completed=0;total=2;checks=@((Empty-Check 'O0'),(Empty-Check 'O2'))};linux=[ordered]@{completed=0;total=2;checks=@((Empty-Check 'O0'),(Empty-Check 'O2'))};browser=[ordered]@{completed=0;total=1;status='not-run';artifactProduced=$null;wasmMagicValid=$null;exactOutput=$null;stdoutSha256=$null;stdoutBytes=$null;llvmSha256=$null;bitcodeSha256=$null;artifactSha256=$null;warningCount=$null;noteCount=$null};python=[ordered]@{completed=0;total=1;status='not-run';path=$python;sha256=$null;archiveSha256=$null;entryCount=$null;entryDigests=@()};evidence=[ordered]@{kind='direct';reusedResultPath=$null;reusedResultSha256=$null};processAudit=[ordered]@{rootProcessIds=@();descendantProcessIds=@();orphanProcessIds=@();invocations=@()};schemaControls=[ordered]@{positiveAccepted=$false;negativeRejected=0;negativeTotal=7;duplicateNormalizationAccepted=$false}}
$failure=$null;$failureId='VERIFIER_EXCEPTION'
try {
    $record.inputHashesStart=Snapshot $paths
    foreach($required in @($contractPath,$contractSchemaPath,$resultSchemaPath,$PSCommandPath)){if(-not(Test-Path -LiteralPath $required -PathType Leaf)){$failureId='CONTRACT_INPUT_MISSING';throw "missing contract input: $required"}}
    if(-not(Test-Path -LiteralPath $compiler -PathType Leaf)){$failureId='COMPILER_MISSING';throw "missing compiler: $compiler"};$record.compilerSha256Start=$record.inputHashesStart.compiler
    if($compilerExtension-cnotin@('.dll','.exe')){$failureId='COMPILER_EXTENSION_INVALID';throw 'compiler must be .dll or .exe'}
    if($compilerExtension-ceq'.dll'-and-not(Test-Path -LiteralPath $dotnet -PathType Leaf)){$failureId='DOTNET_MISSING';throw 'dotnet host missing'}
    if($record.compilerSha256Start-cne$ExpectedCompilerSha256){$failureId='COMPILER_HASH_MISMATCH';throw "compiler hash mismatch expected=$ExpectedCompilerSha256 actual=$($record.compilerSha256Start)"}
    $record.compilerDispatch=if($compilerExtension-ceq'.dll'){'dotnet'}else{'direct'}
    if(-not(Test-Path -LiteralPath $node -PathType Leaf)){$failureId='NODE_MISSING';throw 'Node.js host missing'}
    if(-not(Test-Path -LiteralPath $python -PathType Leaf)){$failureId='PYTHON_MISSING';throw "missing Python: $python"};$record.python.sha256=$record.inputHashesStart.python
    $contractText=[IO.File]::ReadAllText($contractPath);if(-not($contractText|Test-Json -SchemaFile $contractSchemaPath)){$failureId='CONTRACT_SCHEMA_INVALID';throw 'ZIP writer contract schema rejected contract'};$contract=$contractText|ConvertFrom-Json
    $archive=[Convert]::FromBase64String($contract.reference.encodedBase64);if($archive.Length-ne$contract.reference.encodedLength-or(Hash-Bytes $archive)-cne$contract.reference.encodedSha256){$failureId='ORACLE_IDENTITY_MISMATCH';throw 'ZIP writer oracle identity drifted'}
    if($null-ne$resumeResult){
        if(-not(Test-Path -LiteralPath $resumeResult -PathType Leaf)){$failureId='RESUME_RESULT_MISSING';throw "resume result missing: $resumeResult"}
        $resumeText=[IO.File]::ReadAllText($resumeResult);$prior=$resumeText|ConvertFrom-Json
        if($prior.status-cne'failed'-or$prior.completed-ne 5-or(@($prior.failureIds)-join',')-cne'BROWSER_RUNTIME_FAILED'-or-not$prior.inputStable-or@($prior.processAudit.orphanProcessIds).Count-ne 0){$failureId='RESUME_RESULT_STATE_INVALID';throw 'resume result is not the exact terminal p21 native authority'}
        if($prior.compilerSha256Start-cne$ExpectedCompilerSha256-or$prior.compilerSha256End-cne$ExpectedCompilerSha256){$failureId='RESUME_COMPILER_DRIFT';throw 'resume compiler provenance mismatch'}
        foreach($key in @('compiler','fixture','expected','zipSource','errorSource','encoderPhase','decoderPhase')){if($prior.inputHashesStart.$key-cne$record.inputHashesStart[$key]-or$prior.inputHashesEnd.$key-cne$record.inputHashesStart[$key]){$failureId='RESUME_INPUT_DRIFT';throw "resume authority input mismatch: $key"}}
        foreach($platformName in @('windows','linux')){$platform=$prior.$platformName;if($platform.completed-ne 2-or@($platform.checks|Where-Object status -CNE 'passed').Count-ne 0){$failureId='RESUME_NATIVE_INCOMPLETE';throw "resume native platform incomplete: $platformName"}}
        if($prior.python.completed-ne 1-or$prior.python.status-cne'passed'-or$prior.python.archiveSha256-cne$contract.reference.encodedSha256-or$prior.python.entryCount-ne 2){$failureId='RESUME_PYTHON_INCOMPLETE';throw 'resume Python evidence incomplete'}
        if(@($prior.processAudit.invocations|Where-Object id -CEQ '1755-browser-node-exact').Count-ne 1){$failureId='RESUME_BROWSER_ATTEMPT_MISSING';throw 'resume result lacks exact browser runtime attempt'}
        $record.windows=$prior.windows;$record.linux=$prior.linux;$record.python=$prior.python;$record.completed=5;$record.evidence.kind='reused-native';$record.evidence.reusedResultPath=[IO.Path]::GetRelativePath($root,$resumeResult).Replace('\','/');$record.evidence.reusedResultSha256=Hash $resumeResult
    } else {
        $oracle="import base64,hashlib,io,json,sys,zipfile,zlib;b=base64.b64decode(sys.argv[1]);z=zipfile.ZipFile(io.BytesIO(b));e=[];[(e.append({'name':i.filename,'method':i.compress_type,'size':i.file_size,'crc':'%08X'%i.CRC,'sha256':hashlib.sha256(z.read(i)).hexdigest().upper(),'bytes':list(z.read(i))})) for i in z.infolist()];print(json.dumps({'comment':z.comment.decode('ascii'),'entries':e},separators=(',',':')))"
        $run=@(Run-Process 'python-two-entry-oracle' $python @('-c',$oracle,$contract.reference.encodedBase64))[-1]
        if($run.ExitCode-ne 0-or$run.StderrBytes.Length-ne 0){$failureId='PYTHON_ORACLE_FAILED';throw 'Python two-entry oracle failed'};$observed=[Text.Encoding]::UTF8.GetString($run.StdoutBytes)|ConvertFrom-Json
        if($observed.comment-cne$contract.reference.archiveCommentAscii-or@($observed.entries).Count-ne 2){$failureId='PYTHON_ORACLE_MISMATCH';throw 'Python oracle archive metadata mismatch'}
        for($index=0;$index-lt 2;$index++){$actual=$observed.entries[$index];$expected=$contract.reference.entries[$index];if($actual.name-cne$expected.name-or$actual.method-ne 0-or$actual.size-ne$expected.size-or$actual.crc-cne$expected.crc32-or$actual.sha256-cne$expected.sha256-or(@($actual.bytes)-join',')-cne(@($expected.bytes)-join',')){$failureId='PYTHON_ORACLE_MISMATCH';throw "Python oracle entry mismatch: $index"}}
        $record.python.completed=1;$record.python.status='passed';$record.python.archiveSha256=$contract.reference.encodedSha256;$record.python.entryCount=2;$record.python.entryDigests=@($observed.entries.sha256);$record.completed=1
    }

    $control=($record|ConvertTo-Json -Depth 20)|ConvertFrom-Json;$control.status='passed';$control.completed=6;$control.compilerSha256Start='A'*64;$control.compilerSha256End='A'*64;$control.inputStable=$true;$control.inputDrift=@();$control.failureIds=@();$control.evidence.kind='direct';$control.evidence.reusedResultPath=$null;$control.evidence.reusedResultSha256=$null;$control.schemaControls.positiveAccepted=$true;$control.schemaControls.negativeRejected=7
    foreach($platform in @($control.windows,$control.linux)){$platform.completed=2;foreach($check in $platform.checks){$check.status='passed';$check.stdoutSha256='CCC3BBBA5578C822E2D9F4A6A105530CEE01796623E48B1935A103D988455B17';$check.stdoutBytes=289;$check.llvmSha256='B'*64;$check.bitcodeSha256='C'*64;$check.artifactSha256='D'*64;$check.warningCount=0;$check.noteCount=0}};$control.browser.completed=1;$control.browser.status='passed';$control.browser.artifactProduced=$true;$control.browser.wasmMagicValid=$true;$control.browser.exactOutput=$true;$control.browser.stdoutSha256='107D9AF2AA59C4308B07399134C8FFAF4A007791464B2EE3C0AF56C5AFECA5E3';$control.browser.stdoutBytes=44;$control.browser.llvmSha256='B'*64;$control.browser.bitcodeSha256='C'*64;$control.browser.artifactSha256='D'*64;$control.browser.warningCount=0;$control.browser.noteCount=0
    if(@($control.processAudit.invocations).Count-eq 0){$control.processAudit.invocations+= [pscustomobject]@{id='schema-control-0';exitCode=0;rootProcessId=1000;descendantProcessIds=@();orphanProcessIds=@();stdoutPath='schema-control.stdout.bin';stderrPath='schema-control.stderr.bin';stdoutSha256='A'*64;stderrSha256='B'*64;stdoutBytes=0;stderrBytes=0};$control.processAudit.rootProcessIds+=1000}
    $templateInvocation=$control.processAudit.invocations[0];while(@($control.processAudit.invocations).Count-lt 31){$copy=($templateInvocation|ConvertTo-Json -Depth 5)|ConvertFrom-Json;$copy.id='schema-control-'+@($control.processAudit.invocations).Count;$copy.rootProcessId=1000+@($control.processAudit.invocations).Count;$control.processAudit.invocations+= $copy;$control.processAudit.rootProcessIds+= $copy.rootProcessId}
    $control.processAudit.rootProcessIds+=@($control.processAudit.rootProcessIds[0]);Normalize-ProcessAudit $control.processAudit;$control.schemaControls.duplicateNormalizationAccepted=@($control.processAudit.rootProcessIds).Count-eq@($control.processAudit.rootProcessIds|Sort-Object -Unique).Count
    $record.schemaControls.positiveAccepted=(($control|ConvertTo-Json -Depth 20)|Test-Json -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue);if(-not$record.schemaControls.positiveAccepted){$failureId='RESULT_SCHEMA_POSITIVE_REJECTED';throw 'result schema rejected positive control'}
    $mutators=@({param($r)$r.processAudit.orphanProcessIds=@(999999)},{param($r)$r.windows.checks[0].stdoutSha256='E'*64},{param($r)$r.windows.completed=1},{param($r)$r.status='failed';$r.completed=0;$r.failureIds=@();$r|Add-Member -NotePropertyName failure -NotePropertyValue control},{param($r)$r.browser.artifactProduced=$false},{param($r)$r.status='failed';$r.completed=0;$r.failureIds=@('CONTROL_FAILURE');$r|Add-Member -NotePropertyName failure -NotePropertyValue control;$r.compilerSha256Start='not-a-sha'},{param($r)$r.status='failed';$r.completed=0;$r.failureIds=@('CONTROL_FAILURE');$r|Add-Member -NotePropertyName failure -NotePropertyValue control;$r.browser.status='not-run';$r.browser.completed=0;$r.processAudit.invocations[0].id='1755-browser-control'})
    foreach($mutator in $mutators){$negative=($control|ConvertTo-Json -Depth 20)|ConvertFrom-Json;&$mutator $negative;if(-not(($negative|ConvertTo-Json -Depth 20)|Test-Json -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue)){$record.schemaControls.negativeRejected++}}
    if($record.schemaControls.negativeRejected-ne 7){$failureId='RESULT_SCHEMA_NEGATIVE_ACCEPTED';throw 'result schema accepted a negative control'}
    if($ContractOnly){$record.status='contract-validated'}else{
        foreach($future in @($fixturePath,$expectedPath,$browserFixturePath,$browserExpectedPath,$phaseSource,$decoderPhaseSource,$formatVerifier,$closureVerifier,$browserRunner,$fieldMigrationVerifier,$llvmAs)+$negativeSources+$negativeExpected){if(-not(Test-Path -LiteralPath $future -PathType Leaf)){$failureId='AUTHORITY_INPUT_MISSING';throw "ZIP writer input missing: $future"}}
        $fixtureText=[IO.File]::ReadAllText($fixturePath)
        $browserFixtureText=[IO.File]::ReadAllText($browserFixturePath)
        foreach($text in @($fixtureText,$browserFixtureText)){foreach($natural in @("beginStored(['e', 'm', 'p', 't', 'y', '.', 'b', 'i', 'n']","beginStored(['d', 'a', 't', 'a', '.', 'b', 'i', 'n']")){if(-not$text.Contains($natural,[StringComparison]::Ordinal)){$failureId='TEXTUAL_NAME_CHARACTER_LITERAL_MISSING';throw 'textual ZIP entry names must use character literals'}};if($text-match'beginStored\(\[(?:101|100),'){$failureId='TEXTUAL_NAME_NUMERIC_SPELLING';throw 'textual ZIP entry name uses numeric ASCII spelling'}}
        if($null-ne$resumeResult){$fieldGate=@(Run-Process 'struct-field-migration' $pwsh @('-NoProfile','-File',$fieldMigrationVerifier,'-RepositoryRoot',$root))[-1];Require-Success $fieldGate 'STRUCT_FIELD_MIGRATION_FAILED' -RejectDiagnostics;$format=@(Run-Process 'format-browser-focused' $pwsh @('-NoProfile','-File',$formatVerifier,'-Check','-Compiler',$compiler,'-Source',$browserFixturePath))[-1];Require-Success $format 'FORMAT_FAILED' -RejectDiagnostics}else{
            $formatSources=@($zipSource,$errorSource,$phaseSource,$decoderPhaseSource,$fixturePath,$browserFixturePath)+$negativeSources
            foreach($source in $formatSources){$format=@(Run-Process ('format-'+[IO.Path]::GetFileNameWithoutExtension($source)) $pwsh @('-NoProfile','-File',$formatVerifier,'-Check','-Compiler',$compiler,'-Source',$source))[-1];Require-Success $format 'FORMAT_FAILED' -RejectDiagnostics}
            for($index=0;$index-lt$negativeSources.Count;$index++){$id=[IO.Path]::GetFileNameWithoutExtension($negativeSources[$index]);$artifact=Join-Path $output "negative-$id.exe";$negative=@(Compiler-Run "negative-$id" @('build',$negativeSources[$index],'-o',$artifact,'--target','windows-x64','--llvm',$llvmRoot,'-O0','--keep-temps'))[-1];$diagnostic=[Text.Encoding]::UTF8.GetString($negative.StdoutBytes)+[Text.Encoding]::UTF8.GetString($negative.StderrBytes);$expectedDiagnostic=[IO.File]::ReadAllText($negativeExpected[$index]).Trim();if($negative.ExitCode-eq 0-or-not$diagnostic.Contains($expectedDiagnostic,[StringComparison]::Ordinal)-or(Test-Path -LiteralPath $artifact)){$failureId='SEMANTIC_NEGATIVE_MISMATCH';throw "semantic negative mismatch: $id"}}
            $expectedBytes=[IO.File]::ReadAllBytes($expectedPath)
            foreach($platformName in @('windows','linux')){$target=if($platformName-ceq'windows'){'windows-x64'}else{'linux-x64'};$platform=$record[$platformName];foreach($optimization in @('O0','O2')){$check=@($platform.checks|Where-Object optimization -CEQ $optimization)[0];$suffix=if($platformName-ceq'windows'){'.exe'}else{'.linux'};$artifact=Join-Path $output "1755-$platformName-$optimization$suffix";$compile=@(Compiler-Run "1755-$platformName-$optimization-compile" @('build',$fixturePath,'-o',$artifact,'--target',$target,'--llvm',$llvmRoot,"-$optimization",'--keep-temps'))[-1];Require-Success $compile "${platformName}_${optimization}_COMPILE_FAILED" -RejectDiagnostics;$compileText=[Text.Encoding]::UTF8.GetString($compile.StdoutBytes);$check.warningCount=[regex]::Matches($compileText,'(?im)(?:^|\r?\n)\s*warning\b').Count;$check.noteCount=[regex]::Matches($compileText,'(?im)(?:^|\r?\n)\s*note\b').Count;$stem=[IO.Path]::GetFileNameWithoutExtension($artifact);$ll=Join-Path $output "$stem.slg-tmp/$stem.ll";if(-not(Test-Path -LiteralPath $ll)){$failureId="${platformName}_${optimization}_LLVM_MISSING";throw 'LLVM output missing'};$closure=@(Run-Process "1755-$platformName-$optimization-V004" $pwsh @('-NoProfile','-File',$closureVerifier,'-LlvmPath',$ll))[-1];Require-Success $closure "${platformName}_${optimization}_V004_FAILED" -RejectDiagnostics;$bc=Join-Path $output "$stem.bc";$assembly=@(Run-Process "1755-$platformName-$optimization-llvm-as" $llvmAs @($ll,'-o',$bc))[-1];Require-Success $assembly "${platformName}_${optimization}_LLVM_AS_FAILED" -RejectDiagnostics;$native=if($platformName-ceq'windows'){@(Run-Process "1755-$platformName-$optimization-native" $artifact @())[-1]}else{@(Run-Process "1755-$platformName-$optimization-native" $wsl @('-d',$WslDistribution,'--',(Wsl-Path $artifact)))[-1]};Require-Success $native "${platformName}_${optimization}_NATIVE_FAILED";if(-not(Bytes-Equal $native.StdoutBytes $expectedBytes)){$failureId="${platformName}_${optimization}_STDOUT_MISMATCH";throw 'native stdout mismatch'};$check.status='passed';$check.stdoutSha256=$native.Artifact.stdoutSha256;$check.stdoutBytes=$native.Artifact.stdoutBytes;$check.llvmSha256=Hash $ll;$check.bitcodeSha256=Hash $bc;$check.artifactSha256=Hash $artifact;$platform.completed++;$record.completed++}}
        }
        $record.browser.status='failed';$browserArtifact=Join-Path $output '1755-browser.wasm';$browser=@(Compiler-Run '1755-browser-compile' @('build',$browserFixturePath,'-o',$browserArtifact,'--target','wasm32-browser','--llvm',$llvmRoot,'-O0','--keep-temps'))[-1];Require-Success $browser 'BROWSER_COMPILE_FAILED' -RejectDiagnostics;$browserCompileText=[Text.Encoding]::UTF8.GetString($browser.StdoutBytes);$record.browser.warningCount=[regex]::Matches($browserCompileText,'(?im)(?:^|\r?\n)\s*warning\b').Count;$record.browser.noteCount=[regex]::Matches($browserCompileText,'(?im)(?:^|\r?\n)\s*note\b').Count;$record.browser.artifactProduced=Test-Path -LiteralPath $browserArtifact;if(-not$record.browser.artifactProduced){$failureId='BROWSER_ARTIFACT_MISSING';throw 'browser wasm artifact missing'};$record.browser.artifactSha256=Hash $browserArtifact;$wasmBytes=[IO.File]::ReadAllBytes($browserArtifact);$record.browser.wasmMagicValid=$wasmBytes.Length-ge 8-and$wasmBytes[0]-eq 0-and$wasmBytes[1]-eq 0x61-and$wasmBytes[2]-eq 0x73-and$wasmBytes[3]-eq 0x6D;if(-not$record.browser.wasmMagicValid){$failureId='BROWSER_WASM_MAGIC_INVALID';throw 'browser artifact has invalid wasm magic'};$browserStem=[IO.Path]::GetFileNameWithoutExtension($browserArtifact);$browserLl=Join-Path $output "$browserStem.slg-tmp/$browserStem.ll";if(-not(Test-Path -LiteralPath $browserLl)){$failureId='BROWSER_LLVM_MISSING';throw 'browser LLVM output missing'};$record.browser.llvmSha256=Hash $browserLl;$browserClosure=@(Run-Process '1755-browser-V004' $pwsh @('-NoProfile','-File',$closureVerifier,'-LlvmPath',$browserLl))[-1];Require-Success $browserClosure 'BROWSER_V004_FAILED' -RejectDiagnostics;$browserBc=Join-Path $output '1755-browser.bc';$browserAssembly=@(Run-Process '1755-browser-llvm-as' $llvmAs @($browserLl,'-o',$browserBc))[-1];Require-Success $browserAssembly 'BROWSER_LLVM_AS_FAILED' -RejectDiagnostics;$record.browser.bitcodeSha256=Hash $browserBc;$browserRun=@(Run-Process '1755-browser-node-exact' $node @($browserRunner,$browserArtifact,$browserExpectedPath))[-1];Require-Success $browserRun 'BROWSER_RUNTIME_FAILED';$browserExpectedBytes=[IO.File]::ReadAllBytes($browserExpectedPath);$browserExpected=[Text.Encoding]::UTF8.GetBytes("PASS browser program: $($browserExpectedBytes.Length) output characters`n");$record.browser.exactOutput=Bytes-Equal $browserRun.StdoutBytes $browserExpected;if(-not$record.browser.exactOutput){$failureId='BROWSER_RUNTIME_STDOUT_MISMATCH';throw 'browser harness stdout mismatch'};$record.browser.stdoutSha256=$browserRun.Artifact.stdoutSha256;$record.browser.stdoutBytes=$browserRun.Artifact.stdoutBytes;$record.browser.llvmSha256=Hash $browserLl;$record.browser.bitcodeSha256=Hash $browserBc;$record.browser.artifactSha256=Hash $browserArtifact;$record.browser.completed=1;$record.browser.status='passed';$record.completed++
        $record.status='passed'
    }
} catch {$failure=$_;$record.status='failed';$record.failureIds=@($failureId);$record.failure=$_.Exception.Message}
finally {$record.inputHashesEnd=Snapshot $paths;$record.compilerSha256End=$record.inputHashesEnd.compiler;$keys=@($record.inputHashesStart.Keys)+@($record.inputHashesEnd.Keys)|Sort-Object -Unique;foreach($key in $keys){if($record.inputHashesStart[$key]-cne$record.inputHashesEnd[$key]){$record.inputDrift+=$key}};$record.inputDrift=@($record.inputDrift|Sort-Object -Unique);$record.inputStable=$record.inputDrift.Count-eq 0;if(-not$record.inputStable-and$record.failureIds-notcontains'INPUT_DRIFT'){$record.failureIds+= 'INPUT_DRIFT';$record.status='failed'};Save-Result;Write-Host "[ZIP stored writer] $($record.status) $($record.completed)/$($record.total); result=$(Join-Path $output 'result.json')"}
if($record.status-eq'failed'){throw $failure}
