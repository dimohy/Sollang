[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory)][string]$CompilerPath,
    [Parameter(Mandatory)][ValidatePattern('^[0-9A-Fa-f]{64}$')][string]$ExpectedCompilerSha256,
    [string]$OutputDirectory = '',
    [string]$PythonPath = '',
    [switch]$ValidateInputsOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$scratch = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory = Join-Path $scratch ('zip-stored-stream-' + [guid]::NewGuid().ToString('N')) }
$output = [IO.Path]::GetFullPath($OutputDirectory)
$scratchPrefix = $scratch.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not ($output + [IO.Path]::DirectorySeparatorChar).StartsWith($scratchPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "ZIP focused output must be under artifacts/scratch: $output" }
if (Test-Path -LiteralPath $output) {
    if (-not (Test-Path -LiteralPath $output -PathType Container) -or @(Get-ChildItem -LiteralPath $output -Force).Count -ne 0) { throw "ZIP focused output must be a new or empty directory: $output" }
}
[IO.Directory]::CreateDirectory($output) | Out-Null

$compilerInput = if ([IO.Path]::IsPathRooted($CompilerPath)) { $CompilerPath } else { Join-Path $root $CompilerPath }
$compiler = [IO.Path]::GetFullPath($compilerInput)
$ExpectedCompilerSha256 = $ExpectedCompilerSha256.ToUpperInvariant()
$compilerExtension = [IO.Path]::GetExtension($compiler).ToLowerInvariant()
$dotnetCommand = if ($compilerExtension -ceq '.dll') { Get-Command dotnet -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 } else { $null }
$pythonCandidate = if ([string]::IsNullOrWhiteSpace($PythonPath)) { Get-Command python -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 } else { $null }
$python = if ([string]::IsNullOrWhiteSpace($PythonPath)) {
    if ($null -eq $pythonCandidate) { 'unavailable' } else { [IO.Path]::GetFullPath($pythonCandidate.Source) }
} else { [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($PythonPath)) { $PythonPath } else { Join-Path $root $PythonPath })) }
$dotnetPath = if ($null -eq $dotnetCommand) { $null } else { [IO.Path]::GetFullPath($dotnetCommand.Source) }

$contractPath = Join-Path $root 'scripts/contracts/zip-stored-stream.json'
$contractSchemaPath = Join-Path $root 'scripts/contracts/zip-stored-stream.schema.json'
$resultSchemaPath = Join-Path $root 'scripts/contracts/zip-stored-stream-result.schema.json'
$fixturePath = Join-Path $root 'examples/regression/1754-zip-stored-stream.slg'
$expectedPath = Join-Path $root 'examples/regression/expected/1754-zip-stored-stream.stdout.txt'
$zipSource = Join-Path $root 'stdlib/std/archive/zip.slg'
$errorSource = Join-Path $root 'stdlib/std/archive/zip/error.slg'
$phaseSource = Join-Path $root 'stdlib/std/archive/zip/decoder_phase.slg'
$formatVerifier = Join-Path $root 'scripts/format-authoritative-slg.ps1'
$closureVerifier = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
$llvmAs = Join-Path $llvmRoot 'bin/llvm-as.exe'
$pwshPath = @((Get-Command pwsh -CommandType Application -ErrorAction Stop))[0].Source

function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Hash-Bytes([byte[]]$Bytes) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)) }
function Bytes-Equal([byte[]]$Left, [byte[]]$Right) { $Left.Length -eq $Right.Length -and (Hash-Bytes $Left) -ceq (Hash-Bytes $Right) }
function Snapshot([Collections.Specialized.OrderedDictionary]$Paths) {
    $snapshot = [ordered]@{}
    foreach ($entry in $Paths.GetEnumerator()) { $snapshot[$entry.Key] = if (Test-Path -LiteralPath $entry.Value -PathType Leaf) { Hash $entry.Value } else { $null } }
    $snapshot
}
function Get-ProcessRecords {
    if (-not $IsWindows) { throw 'ZIP focused process genealogy currently requires Windows' }
    @(Get-CimInstance Win32_Process -ErrorAction Stop | Select-Object ProcessId, ParentProcessId, CreationDate)
}
function Update-Descendants([Collections.Generic.Dictionary[string, object]]$Observed, [string]$RootIdentity) {
    $records = @(Get-ProcessRecords); $byId = @{}
    foreach ($record in $records) { $byId[[int]$record.ProcessId] = $record }
    $pending = [Collections.Generic.Queue[string]]::new(); foreach ($identity in @($Observed.Keys)) { $pending.Enqueue($identity) }
    $visited = [Collections.Generic.HashSet[string]]::new()
    while ($pending.Count -gt 0) {
        $identity = $pending.Dequeue(); if (-not $visited.Add($identity)) { continue }
        $parent = $Observed[$identity]; $parentId = [int]$parent.ProcessId; $parentTicks = [long]$parent.CreatedTicks
        if (-not $byId.ContainsKey($parentId) -or $byId[$parentId].CreationDate.ToUniversalTime().Ticks -ne $parentTicks) { continue }
        foreach ($record in $records) {
            if ([int]$record.ParentProcessId -ne $parentId) { continue }
            $created = $record.CreationDate.ToUniversalTime().Ticks; if ($created -lt $parentTicks) { continue }
            $childId = [int]$record.ProcessId; $childIdentity = "${childId}:$created"
            if (-not $Observed.ContainsKey($childIdentity)) { $Observed.Add($childIdentity, [pscustomobject]@{ ProcessId = $childId; CreatedTicks = $created }) }
            $pending.Enqueue($childIdentity)
        }
    }
    @($Observed.GetEnumerator() | Where-Object Key -cne $RootIdentity | ForEach-Object {
        $processId = [int]$_.Value.ProcessId
        if ($byId.ContainsKey($processId) -and $byId[$processId].CreationDate.ToUniversalTime().Ticks -eq [long]$_.Value.CreatedTicks) { $processId }
    })
}
function Run-Raw([string]$Id, [string]$FilePath, [string[]]$Arguments, [int]$TimeoutMilliseconds = 60000) {
    $start = [Diagnostics.ProcessStartInfo]::new(); $start.FileName = $FilePath; $start.WorkingDirectory = $root
    $start.UseShellExecute = $false; $start.CreateNoWindow = $true; $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new(); $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw "$Id could not start '$FilePath'" }
        $rootProcessId = $process.Id; $rootRecord = @(Get-ProcessRecords | Where-Object { [int]$_.ProcessId -eq $rootProcessId })
        $rootTicks = if ($rootRecord.Count -eq 1) { $rootRecord[0].CreationDate.ToUniversalTime().Ticks } else { $process.StartTime.ToUniversalTime().Ticks }
        $rootIdentity = "${rootProcessId}:$rootTicks"; $observed = [Collections.Generic.Dictionary[string, object]]::new()
        $observed.Add($rootIdentity, [pscustomobject]@{ ProcessId = $rootProcessId; CreatedTicks = $rootTicks })
        $stdout = [IO.MemoryStream]::new(); $stderr = [IO.MemoryStream]::new()
        $stdoutTask = $process.StandardOutput.BaseStream.CopyToAsync($stdout); $stderrTask = $process.StandardError.BaseStream.CopyToAsync($stderr)
        $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
        while (-not $process.WaitForExit(10) -and [DateTimeOffset]::UtcNow -lt $deadline) { Update-Descendants $observed $rootIdentity | Out-Null }
        if (-not $process.HasExited) { $process.Kill($true); $process.WaitForExit(); throw "$Id exceeded $TimeoutMilliseconds ms" }
        $process.WaitForExit(); $stdoutTask.GetAwaiter().GetResult(); $stderrTask.GetAwaiter().GetResult()
        $orphanDeadline = [DateTimeOffset]::UtcNow.AddSeconds(5)
        do { $orphans = @(Update-Descendants $observed $rootIdentity); if ($orphans.Count -eq 0 -or [DateTimeOffset]::UtcNow -ge $orphanDeadline) { break }; Start-Sleep -Milliseconds 25 } while ($true)
        [pscustomobject]@{ Id=$Id; ExitCode=$process.ExitCode; StdoutBytes=$stdout.ToArray(); StderrBytes=$stderr.ToArray(); RootProcessId=$rootProcessId
            DescendantProcessIds=@($observed.GetEnumerator() | Where-Object Key -cne $rootIdentity | ForEach-Object { [int]$_.Value.ProcessId } | Sort-Object -Unique)
            OrphanProcessIds=@($orphans | Sort-Object -Unique) }
    } finally { $process.Dispose() }
}
function Invoke-Captured([string]$Id, [string]$FilePath, [string[]]$Arguments) {
    $capture = @(Run-Raw $Id $FilePath $Arguments)[-1]; $safeId = $Id -replace '[^A-Za-z0-9_.-]', '-'
    $stdoutPath = Join-Path $output "$safeId.stdout.bin"; $stderrPath = Join-Path $output "$safeId.stderr.bin"
    [IO.File]::WriteAllBytes($stdoutPath, $capture.StdoutBytes); [IO.File]::WriteAllBytes($stderrPath, $capture.StderrBytes)
    $artifact = [ordered]@{ id=$Id; exitCode=$capture.ExitCode; rootProcessId=$capture.RootProcessId
        descendantProcessIds=@($capture.DescendantProcessIds); orphanProcessIds=@($capture.OrphanProcessIds)
        stdoutPath=[IO.Path]::GetRelativePath($root,$stdoutPath).Replace('\','/'); stderrPath=[IO.Path]::GetRelativePath($root,$stderrPath).Replace('\','/')
        stdoutSha256=Hash $stdoutPath; stderrSha256=Hash $stderrPath; stdoutBytes=$capture.StdoutBytes.Length; stderrBytes=$capture.StderrBytes.Length }
    $script:record.processAudit.invocations += $artifact; $script:record.processAudit.rootProcessIds += $capture.RootProcessId
    $script:record.processAudit.descendantProcessIds += @($capture.DescendantProcessIds); $script:record.processAudit.orphanProcessIds += @($capture.OrphanProcessIds)
    [pscustomobject]@{ Capture=$capture; Artifact=$artifact }
}
function Require-Success($Run, [string]$FailureId, [switch]$RejectDiagnostics) {
    if ($Run.Capture.ExitCode -ne 0 -or $Run.Capture.StderrBytes.Length -ne 0 -or $Run.Capture.OrphanProcessIds.Count -ne 0) {
        $script:currentFailureId=$FailureId; throw "$($Run.Capture.Id) failed exit=$($Run.Capture.ExitCode), stderrBytes=$($Run.Capture.StderrBytes.Length), orphans=$($Run.Capture.OrphanProcessIds.Count)"
    }
    if ($RejectDiagnostics) {
        $text=[Text.Encoding]::UTF8.GetString($Run.Capture.StdoutBytes)+"`n"+[Text.Encoding]::UTF8.GetString($Run.Capture.StderrBytes)
        if ($text -match '(?im)(?:^|\r?\n)\s*(?:warning|note)\b') { $script:currentFailureId=$FailureId; throw "$($Run.Capture.Id) emitted a warning or note" }
    }
}
function Invoke-Compiler([string]$Id,[string[]]$Arguments) {
    if ($script:record.compilerDispatch -ceq 'dotnet') { Invoke-Captured $Id $script:dotnetPath (@($compiler)+$Arguments) } else { Invoke-Captured $Id $compiler $Arguments }
}
function Save-Result {
    $json=($script:record|ConvertTo-Json -Depth 12)+"`n"
    if (-not ($json|Test-Json -SchemaFile $resultSchemaPath)) { throw 'ZIP focused result does not match its schema' }
    [IO.File]::WriteAllText((Join-Path $output 'result.json'),$json,[Text.UTF8Encoding]::new($false))
}
function Crc32([byte[]]$Bytes) {
    [uint32]$state=[uint32]::MaxValue; [uint32]$polynomial=[uint32]::Parse('EDB88320',[Globalization.NumberStyles]::HexNumber)
    foreach($byte in $Bytes){$state=$state -bxor [uint32]$byte;for($bit=0;$bit-lt 8;$bit++){if(($state-band 1)-ne 0){$state=[uint32](($state-shr 1)-bxor $polynomial)}else{$state=[uint32]($state-shr 1)}}}; [uint32](-bnot $state)
}

$record=[ordered]@{schemaVersion=1;mode='zip-stored-stream-focused';status='failed';completed=0;total=3;failureIds=@()
    compilerPath=$compiler;expectedCompilerSha256=$ExpectedCompilerSha256;compilerSha256Start=$null;compilerSha256End=$null;compilerDispatch='unavailable'
    inputStable=$false;inputDrift=@();inputHashesStart=[ordered]@{bootstrap=$null};inputHashesEnd=[ordered]@{bootstrap=$null}
    managedWindows=[ordered]@{completed=0;total=2;checks=@(
        [ordered]@{optimization='O0';status='not-run';warningCount=$null;noteCount=$null;nativeStdoutSha256=$null;nativeStdoutBytes=$null;llvmSha256=$null;bitcodeSha256=$null;executableSha256=$null},
        [ordered]@{optimization='O2';status='not-run';warningCount=$null;noteCount=$null;nativeStdoutSha256=$null;nativeStdoutBytes=$null;llvmSha256=$null;bitcodeSha256=$null;executableSha256=$null})}
    independentPython=[ordered]@{completed=0;total=1;status='not-run';path=$python;sha256=$null;archiveSha256=$null;decodedCrc32=$null}
    processAudit=[ordered]@{rootProcessIds=@();descendantProcessIds=@();orphanProcessIds=@();invocations=@()}}
$inputPaths=[ordered]@{compiler=$compiler;contract=$contractPath;contractSchema=$contractSchemaPath;resultSchema=$resultSchemaPath;verifier=$PSCommandPath
    fixture=$fixturePath;expected=$expectedPath;zipSource=$zipSource;errorSource=$errorSource;phaseSource=$phaseSource;formatter=$formatVerifier;closure=$closureVerifier;llvmAs=$llvmAs;pwsh=$pwshPath;python=$python}
if($null-ne$dotnetPath){$inputPaths.dotnet=$dotnetPath}
foreach($source in @(Get-ChildItem -LiteralPath (Join-Path $root 'stdlib') -Recurse -File -Filter '*.slg' | Sort-Object FullName)){$relative=[IO.Path]::GetRelativePath($root,$source.FullName).Replace('\','/');$inputPaths["stdlib:$relative"]=$source.FullName}
$currentFailureId='VERIFIER_EXCEPTION';$failure=$null
try{
    $record.inputHashesStart=Snapshot $inputPaths
    if(-not(Test-Path -LiteralPath $compiler -PathType Leaf)){$currentFailureId='COMPILER_MISSING';throw "ZIP focused compiler is missing: $compiler"}
    if($compilerExtension -notin @('.dll','.exe')){$currentFailureId='COMPILER_EXTENSION_INVALID';throw "ZIP focused compiler must be a .dll or .exe: $compiler"}
    if($compilerExtension -ceq '.dll' -and $null-eq$dotnetPath){$currentFailureId='DOTNET_MISSING';throw 'ZIP focused dotnet host is missing'}
    if(-not(Test-Path -LiteralPath $python -PathType Leaf)){$currentFailureId='PYTHON_MISSING';throw "ZIP focused Python is missing: $python"}
    $record.compilerSha256Start=$record.inputHashesStart.compiler
    if($record.compilerSha256Start -cne $ExpectedCompilerSha256){$currentFailureId='COMPILER_HASH_MISMATCH';throw "ZIP focused compiler SHA-256 drifted: expected=$ExpectedCompilerSha256 actual=$($record.compilerSha256Start)"}
    $record.compilerDispatch=if($compilerExtension-ceq'.dll'){'dotnet'}else{'direct'};$record.independentPython.sha256=$record.inputHashesStart.python
    foreach($entry in $inputPaths.GetEnumerator()){if($null-eq$record.inputHashesStart[$entry.Key]){$currentFailureId='AUTHORITY_INPUT_MISSING';throw "ZIP focused input is missing: $($entry.Value)"}}
    $contractText=[IO.File]::ReadAllText($contractPath);if(-not($contractText|Test-Json -SchemaFile $contractSchemaPath)){$currentFailureId='CONTRACT_SCHEMA_INVALID';throw 'ZIP contract does not satisfy its schema'}
    $contract=$contractText|ConvertFrom-Json;$encoded=[Convert]::FromBase64String($contract.reference.encodedBase64)
    if($encoded.Length-ne$contract.reference.encodedLength-or(Hash-Bytes $encoded)-cne$contract.reference.encodedSha256){$currentFailureId='REFERENCE_IDENTITY_MISMATCH';throw 'ZIP reference identity drifted'}
    $decoded=[byte[]]@($contract.reference.decodedBytes);if((Crc32 $decoded).ToString('X8')-cne$contract.reference.decodedCrc32){$currentFailureId='REFERENCE_CRC_MISMATCH';throw 'ZIP CRC authority drifted'}
    foreach($source in @($zipSource,$errorSource,$phaseSource,$fixturePath)){$format=Invoke-Captured ('format-'+[IO.Path]::GetFileNameWithoutExtension($source)) $pwshPath @('-NoProfile','-File',$formatVerifier,'-Check','-Source',$source);Require-Success $format 'FORMAT_FAILED' -RejectDiagnostics}
    if($ValidateInputsOnly){$record.status='inputs-validated'}else{
        $expectedBytes=[IO.File]::ReadAllBytes($expectedPath)
        foreach($optimization in @('O0','O2')){$check=@($record.managedWindows.checks|Where-Object optimization -CEQ $optimization)[0];try{
            $artifact=Join-Path $output "1754-$optimization.exe";$compile=Invoke-Compiler "1754-$optimization-compile" @('build',$fixturePath,'-o',$artifact,'--target','windows-x64','--llvm',$llvmRoot,"-$optimization",'--keep-temps')
            Require-Success $compile "MANAGED_${optimization}_COMPILE_FAILED" -RejectDiagnostics;$compileText=[Text.Encoding]::UTF8.GetString($compile.Capture.StdoutBytes)
            $check.warningCount=[regex]::Matches($compileText,'(?im)(?:^|\r?\n)\s*warning\b').Count;$check.noteCount=[regex]::Matches($compileText,'(?im)(?:^|\r?\n)\s*note\b').Count
            $stem=[IO.Path]::GetFileNameWithoutExtension($artifact);$llvm=Join-Path $output "$stem.slg-tmp/$stem.ll";if(-not(Test-Path -LiteralPath $llvm -PathType Leaf)){$currentFailureId="MANAGED_${optimization}_LLVM_MISSING";throw "$optimization LLVM missing"}
            $closure=Invoke-Captured "1754-$optimization-V004" $pwshPath @('-NoProfile','-File',$closureVerifier,'-LlvmPath',$llvm);Require-Success $closure "MANAGED_${optimization}_V004_FAILED" -RejectDiagnostics
            $bitcode=Join-Path $output "$stem.bc";$assembly=Invoke-Captured "1754-$optimization-llvm-as" $llvmAs @($llvm,'-o',$bitcode);Require-Success $assembly "MANAGED_${optimization}_LLVM_AS_FAILED" -RejectDiagnostics
            $native=Invoke-Captured "1754-$optimization-native" $artifact @();Require-Success $native "MANAGED_${optimization}_NATIVE_FAILED"
            if(-not(Bytes-Equal $native.Capture.StdoutBytes $expectedBytes)){$currentFailureId="MANAGED_${optimization}_STDOUT_BYTES_MISMATCH";throw "$optimization raw stdout mismatch"}
            $check.status='passed';$check.nativeStdoutSha256=$native.Artifact.stdoutSha256;$check.nativeStdoutBytes=$native.Artifact.stdoutBytes;$check.llvmSha256=Hash $llvm;$check.bitcodeSha256=Hash $bitcode;$check.executableSha256=Hash $artifact
            $record.managedWindows.completed++;$record.completed++
        }catch{$check.status='failed';throw}}
        $pythonScript="import base64,io,json,sys,zipfile,zlib; b=base64.b64decode(sys.argv[1]); z=zipfile.ZipFile(io.BytesIO(b)); n=z.namelist(); i=z.getinfo(n[0]); d=z.read(n[0]); print(json.dumps({'names':n,'method':i.compress_type,'data':list(d),'crc':'%08X'%(zlib.crc32(d)&0xffffffff)},separators=(',',':')))"
        $pythonRun=Invoke-Captured 'python-zip-differential' $python @('-c',$pythonScript,$contract.reference.encodedBase64);Require-Success $pythonRun 'PYTHON_DIFFERENTIAL_FAILED'
        $reference=[Text.Encoding]::UTF8.GetString($pythonRun.Capture.StdoutBytes)|ConvertFrom-Json
        if(@($reference.names).Count-ne 1-or$reference.names[0]-cne$contract.reference.entryName-or$reference.method-ne 0-or(@($reference.data)-join',')-cne(@($contract.reference.decodedBytes)-join',')-or$reference.crc-cne$contract.reference.decodedCrc32){$currentFailureId='PYTHON_DIFFERENTIAL_MISMATCH';throw 'Python ZIP differential mismatch'}
        $record.independentPython.completed=1;$record.independentPython.status='passed';$record.independentPython.archiveSha256=$contract.reference.encodedSha256;$record.independentPython.decodedCrc32=$reference.crc;$record.completed++
    }
}catch{$failure=$_;if($currentFailureId-like'PYTHON_*'){$record.independentPython.status='failed'};if($record.failureIds-notcontains$currentFailureId){$record.failureIds+=$currentFailureId};$record.failure=$_.Exception.Message}
finally{
    $record.inputHashesEnd=Snapshot $inputPaths;$record.compilerSha256End=$record.inputHashesEnd.compiler;$keys=@($record.inputHashesStart.Keys)+@($record.inputHashesEnd.Keys)|Sort-Object -Unique
    foreach($key in $keys){if($record.inputHashesStart[$key]-cne$record.inputHashesEnd[$key]){$record.inputDrift+=$key}};$record.inputDrift=@($record.inputDrift|Sort-Object -Unique);$record.inputStable=$record.inputDrift.Count-eq 0
    if(-not$record.inputStable-and$record.failureIds-notcontains'INPUT_DRIFT'){$record.failureIds+='INPUT_DRIFT'}
    $record.processAudit.rootProcessIds=@($record.processAudit.rootProcessIds|Sort-Object -Unique);$record.processAudit.descendantProcessIds=@($record.processAudit.descendantProcessIds|Sort-Object -Unique);$record.processAudit.orphanProcessIds=@($record.processAudit.orphanProcessIds|Sort-Object -Unique)
    if($record.processAudit.orphanProcessIds.Count-ne 0-and$record.failureIds-notcontains'ORPHAN_PROCESS'){$record.failureIds+='ORPHAN_PROCESS'};$record.failureIds=@($record.failureIds|Sort-Object -Unique)
    if(-not$ValidateInputsOnly){$record.status=if($record.completed-eq 3-and$record.inputStable-and$record.processAudit.orphanProcessIds.Count-eq 0-and$record.failureIds.Count-eq 0){'passed'}else{'failed'}}elseif($record.failureIds.Count-ne 0){$record.status='failed'}
    Save-Result;Write-Host "[ZIP stored stream focused] $($record.status) $($record.completed)/$($record.total); result=$(Join-Path $output 'result.json')"
}
if($record.status-eq'failed'){if($null-ne$failure){throw $failure};throw "ZIP focused failed: $($record.failureIds-join', ')"}
