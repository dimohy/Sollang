[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory)][string]$CompilerPath,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCompilerSha256,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$WslDistribution = 'Ubuntu',
    [string]$PythonPath = '',
    [switch]$ValidateInputsOnly,
    [switch]$ValidateSemanticPreflightOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$scratchRoot = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
$output = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $root $OutputDirectory }))
$scratchPrefix = $scratchRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not ($output + [IO.Path]::DirectorySeparatorChar).StartsWith($scratchPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "output must be under artifacts/scratch: $output" }
if (Test-Path -LiteralPath $output) {
    if (-not (Test-Path -LiteralPath $output -PathType Container) -or @(Get-ChildItem -LiteralPath $output -Force).Count -ne 0) { throw "output must be new or empty: $output" }
}
[IO.Directory]::CreateDirectory($output) | Out-Null

$compiler = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($CompilerPath)) { $CompilerPath } else { Join-Path $root $CompilerPath }))
$ExpectedCompilerSha256 = $ExpectedCompilerSha256.ToUpperInvariant()
$compilerExtension = [IO.Path]::GetExtension($compiler).ToLowerInvariant()
$dotnetCommand = if ($compilerExtension -ceq '.dll') { Get-Command dotnet -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 } else { $null }
$dotnet = if ($null -eq $dotnetCommand) { 'unavailable' } else { $dotnetCommand.Source }
$pythonCommand = if ([string]::IsNullOrWhiteSpace($PythonPath)) { Get-Command python -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 } else { $null }
$python = if (-not [string]::IsNullOrWhiteSpace($PythonPath)) { [IO.Path]::GetFullPath($PythonPath) } elseif ($null -eq $pythonCommand) { 'unavailable' } else { $pythonCommand.Source }
$nodeCommand = Get-Command node -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$node = if ($null -eq $nodeCommand) { 'unavailable' } else { $nodeCommand.Source }
$wslCommand = Get-Command wsl.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$wsl = if ($null -eq $wslCommand) { 'unavailable' } else { $wslCommand.Source }
$pwsh = @((Get-Command pwsh -CommandType Application -ErrorAction Stop))[0].Source
$llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
$llvmAs = Join-Path $llvmRoot 'bin/llvm-as.exe'
$contractPath = Join-Path $root 'scripts/contracts/zip-deflate-method8.json'
$contractSchemaPath = Join-Path $root 'scripts/contracts/zip-deflate-method8.schema.json'
$resultSchemaPath = Join-Path $root 'scripts/contracts/zip-deflate-method8-result.schema.json'
$resultVerifier = Join-Path $root 'scripts/verify-zip-deflate-method8-result.ps1'
$contractVerifier = Join-Path $root 'scripts/verify-zip-deflate-method8-contract.ps1'
$fixturePath = Join-Path $root 'examples/regression/1756-zip-deflate-method8.slg'
$expectedPath = Join-Path $root 'examples/regression/expected/1756-zip-deflate-method8.stdout.txt'
$oraclePath = Join-Path $root 'scripts/probes/zip-deflate-method8/verify_python_oracle.py'
$formatVerifier = Join-Path $root 'scripts/format-authoritative-slg.ps1'
$closureVerifier = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$browserRunner = Join-Path $root 'scripts/verify-browser-program.mjs'
$negativeIds = @('affine-writer-reuse', 'affine-decoder-reuse')

function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Hash-Bytes([byte[]]$Bytes) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)) }
function Relative([string]$Path) { [IO.Path]::GetRelativePath($root, $Path).Replace('\', '/') }
function Wsl-Path([string]$Path) { $full = [IO.Path]::GetFullPath($Path); '/mnt/' + $full.Substring(0, 1).ToLowerInvariant() + $full.Substring(2).Replace('\', '/') }
function Empty-Check([string]$Optimization) { [ordered]@{ optimization=$Optimization;status='not-run';stdoutSha256=$null;stdoutBytes=$null;llvmSha256=$null;bitcodeSha256=$null;artifactSha256=$null;warningCount=$null;noteCount=$null } }
function Snapshot($Paths) { $map=[ordered]@{}; foreach ($entry in $Paths.GetEnumerator()) { if(Test-Path -LiteralPath $entry.Value -PathType Leaf){$map[$entry.Key]=Hash $entry.Value} }; $map }
function Descendants([int]$ProcessId) {
    $records=@(Get-CimInstance Win32_Process);$seen=[Collections.Generic.HashSet[int]]::new();[void]$seen.Add($ProcessId);$changed=$true
    while($changed){$changed=$false;foreach($record in $records){if($seen.Contains([int]$record.ParentProcessId)-and$seen.Add([int]$record.ProcessId)){$changed=$true}}}
    @($seen|Where-Object{$_-ne$ProcessId}|Sort-Object -Unique)
}
function Run([string]$Id,[string]$File,[string[]]$Arguments) {
    $start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=$File;$start.WorkingDirectory=$root;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    foreach($argument in $Arguments){[void]$start.ArgumentList.Add($argument)}
    $process=[Diagnostics.Process]::new();$process.StartInfo=$start
    try {
        if(-not$process.Start()){throw "$Id did not start"};$processId=$process.Id;$observed=[Collections.Generic.HashSet[int]]::new();$stdoutTask=$process.StandardOutput.BaseStream.CopyToAsync(($stdout=[IO.MemoryStream]::new()));$stderrTask=$process.StandardError.BaseStream.CopyToAsync(($stderr=[IO.MemoryStream]::new()));$deadline=[DateTimeOffset]::UtcNow.AddSeconds(180)
        while(-not$process.WaitForExit(20)-and[DateTimeOffset]::UtcNow-lt$deadline){foreach($child in @(Descendants $processId)){[void]$observed.Add($child)}}
        if(-not$process.HasExited){$process.Kill($true);$process.WaitForExit();throw "$Id exceeded 180000ms"};$process.WaitForExit();foreach($child in @(Descendants $processId)){[void]$observed.Add($child)};$stdoutTask.GetAwaiter().GetResult()|Out-Null;$stderrTask.GetAwaiter().GetResult()|Out-Null
        $stdoutBytes=$stdout.ToArray();$stderrBytes=$stderr.ToArray();$safe=$Id-replace'[^A-Za-z0-9_.-]','-';$stdoutPath=Join-Path $output "$safe.stdout.bin";$stderrPath=Join-Path $output "$safe.stderr.bin";[IO.File]::WriteAllBytes($stdoutPath,$stdoutBytes);[IO.File]::WriteAllBytes($stderrPath,$stderrBytes)
        $descendants=@($observed|Sort-Object -Unique);$orphans=@($descendants|Where-Object{Get-Process -Id $_ -ErrorAction SilentlyContinue});$audit=[ordered]@{id=$Id;processId=$processId;exitCode=$process.ExitCode;stdoutPath=Relative $stdoutPath;stderrPath=Relative $stderrPath;stdoutSha256=Hash $stdoutPath;stdoutBytes=$stdoutBytes.Length;stderrSha256=Hash $stderrPath;stderrBytes=$stderrBytes.Length;descendantProcessIds=$descendants;orphanProcessIds=$orphans}
        $script:record.processAudit.rootProcessIds+=$processId;$script:record.processAudit.descendantProcessIds+=$descendants;$script:record.processAudit.orphanProcessIds+=$orphans;$script:record.processAudit.invocations+=$audit
        [pscustomobject]@{ExitCode=$process.ExitCode;StdoutBytes=$stdoutBytes;StderrBytes=$stderrBytes;Audit=$audit}
    } finally { $process.Dispose() }
}
function Compiler-Run([string]$Id,[string[]]$Arguments) { if($compilerExtension-ceq'.dll'){Run $Id $dotnet (@($compiler)+$Arguments)}else{Run $Id $compiler $Arguments} }
function Require-Success($Invocation,[string]$FailureId,[switch]$RejectDiagnostics) {
    if($Invocation.ExitCode-ne 0-or$Invocation.StderrBytes.Length-ne 0-or@($Invocation.Audit.orphanProcessIds).Count-ne 0){$script:currentFailureId=$FailureId;throw "$($Invocation.Audit.id) failed"}
    if($RejectDiagnostics-and([Text.Encoding]::UTF8.GetString($Invocation.StdoutBytes)-match'(?im)(?:^|\r?\n)\s*(?:warning|note)\b')){$script:currentFailureId=$FailureId;throw "$($Invocation.Audit.id) emitted warning/note"}
}
function Normalize-Audit { $record.processAudit.rootProcessIds=@($record.processAudit.rootProcessIds|Sort-Object -Unique);$record.processAudit.descendantProcessIds=@($record.processAudit.descendantProcessIds|Sort-Object -Unique);$record.processAudit.orphanProcessIds=@($record.processAudit.orphanProcessIds|Sort-Object -Unique);foreach($item in $record.processAudit.invocations){$item.descendantProcessIds=@($item.descendantProcessIds|Sort-Object -Unique);$item.orphanProcessIds=@($item.orphanProcessIds|Sort-Object -Unique)} }

$paths=[ordered]@{compiler=$compiler;verifier=$PSCommandPath;contract=$contractPath;contractSchema=$contractSchemaPath;resultSchema=$resultSchemaPath;resultVerifier=$resultVerifier;contractVerifier=$contractVerifier;fixture=$fixturePath;expected=$expectedPath;oracle=$oraclePath;formatter=$formatVerifier;closure=$closureVerifier;browserRunner=$browserRunner;llvmAs=$llvmAs}
if($ValidateSemanticPreflightOnly){foreach($key in @('expected','oracle','closure','browserRunner','llvmAs')){$paths.Remove($key)}}
foreach($id in $negativeIds){$paths["negative:$id"]=Join-Path $root "scripts/probes/zip-deflate-method8/$id.slg";$paths["negativeExpected:$id"]=Join-Path $root "scripts/probes/zip-deflate-method8/$id.stderr.contains.txt"}
foreach($source in @(Get-ChildItem -LiteralPath (Join-Path $root 'stdlib') -Recurse -File -Filter '*.slg'|Sort-Object FullName)){$paths['stdlib:'+(Relative $source.FullName)]=$source.FullName}
$mode=if($ValidateInputsOnly){'input-validation'}elseif($ValidateSemanticPreflightOnly){'semantic-preflight'}else{'full'}
$record=[ordered]@{schemaVersion=1;capabilityId='zip-deflate-method8';mode=$mode;status='failed';planned=6;completed=0;compiler=[ordered]@{path=$compiler;sha256Start=$null;sha256End=$null};inputs=[ordered]@{start=[ordered]@{};end=[ordered]@{}};windows=[ordered]@{status='not-run';planned=2;completed=0;checks=@((Empty-Check O0),(Empty-Check O2))};linux=[ordered]@{status='not-run';planned=2;completed=0;checks=@((Empty-Check O0),(Empty-Check O2))};browser=[ordered]@{status='not-run';completed=0;artifactProduced=$false;wasmMagicValid=$false;exactOutput=$false;stdoutSha256=$null;stdoutBytes=$null;llvmSha256=$null;bitcodeSha256=$null;artifactSha256=$null;warningCount=$null;noteCount=$null};python=[ordered]@{status='not-run';completed=0;stdoutSha256=$null;stdoutBytes=$null};semanticNegatives=[ordered]@{planned=2;completed=0;failureIds=@()};processAudit=[ordered]@{rootProcessIds=@();descendantProcessIds=@();orphanProcessIds=@();invocations=@()};failureIds=@();startedUtc=[DateTimeOffset]::UtcNow.ToString('O');finishedUtc=[DateTimeOffset]::UtcNow.ToString('O')}
$currentFailureId='VERIFIER_EXCEPTION';$caught=$null
try {
    $record.inputs.start=Snapshot $paths
    $record.compiler.sha256Start=if($record.inputs.start.Contains('compiler')){$record.inputs.start.compiler}else{$null}
    foreach($entry in $paths.GetEnumerator()){if(-not(Test-Path -LiteralPath $entry.Value -PathType Leaf)){$currentFailureId='INPUT_MISSING';throw "missing input $($entry.Key): $($entry.Value)"}}
    if($compilerExtension-cnotin@('.dll','.exe')){$currentFailureId='COMPILER_EXTENSION_INVALID';throw 'compiler must be .dll or .exe'}
    if($compilerExtension-ceq'.dll'-and[string]::IsNullOrWhiteSpace($dotnet)){$currentFailureId='DOTNET_MISSING';throw 'dotnet is missing'}
    if($record.compiler.sha256Start-cne$ExpectedCompilerSha256){$currentFailureId='COMPILER_HASH_MISMATCH';throw 'compiler hash mismatch'}
    $contract=[IO.File]::ReadAllText($contractPath);if(-not($contract|Test-Json -SchemaFile $contractSchemaPath)){$currentFailureId='CONTRACT_SCHEMA_INVALID';throw 'contract schema rejected contract'}
    if($ValidateInputsOnly){$record.status='validated-inputs'}else{
        $formatSources=@($fixturePath)+@($negativeIds|ForEach-Object{$paths["negative:$_"]})
        foreach($source in $formatSources){$check=@(Run ('format-'+[IO.Path]::GetFileNameWithoutExtension($source)) $pwsh @('-NoProfile','-File',$formatVerifier,'-Check','-Compiler',$compiler,'-Source',$source))[-1];Require-Success $check FORMAT_FAILED -RejectDiagnostics}
        foreach($id in $negativeIds){
            $artifact=Join-Path $output "$id.exe";$negative=@(Compiler-Run "negative-$id" @('build',$paths["negative:$id"],'-o',$artifact,'--target','windows-x64','--llvm',$llvmRoot,'-O0','--keep-temps'))[-1];$diagnostic=[Text.Encoding]::UTF8.GetString($negative.StdoutBytes)+[Text.Encoding]::UTF8.GetString($negative.StderrBytes);$expectedDiagnostic=[IO.File]::ReadAllText($paths["negativeExpected:$id"]).Trim()
            if($negative.ExitCode-eq 0){$record.semanticNegatives.failureIds+=$id;$currentFailureId='SEMANTIC_NEGATIVE_ACCEPTED';throw "semantic negative was accepted: $id"}
            if(Test-Path -LiteralPath $artifact){$record.semanticNegatives.failureIds+=$id;$currentFailureId='SEMANTIC_NEGATIVE_ARTIFACT_PRODUCED';throw "semantic negative produced an artifact: $id"}
            if(-not$diagnostic.Contains($expectedDiagnostic,[StringComparison]::Ordinal)){$record.semanticNegatives.failureIds+=$id;$currentFailureId=if($diagnostic-match'(?m)^sollang: (?:semantic|parser|lexer) error'){'SEMANTIC_NEGATIVE_BLOCKED_BY_INPUT_DIAGNOSTIC'}else{'SEMANTIC_NEGATIVE_DIAGNOSTIC_MISMATCH'};throw "semantic negative did not reach its expected diagnostic: $id"}
            $record.semanticNegatives.completed++
        }
        if($ValidateSemanticPreflightOnly){$record.status='validated-semantic-negatives'}else{
        $expectedBytes=[IO.File]::ReadAllBytes($expectedPath)
        $windowsO0Stdout=$null
        foreach($platformName in @('windows','linux')){$platform=$record[$platformName];$platform.status='failed';foreach($optimization in @('O0','O2')){$check=@($platform.checks|Where-Object optimization -CEQ $optimization)[0];$check.status='failed';$target=if($platformName-ceq'windows'){'windows-x64'}else{'linux-x64'};$suffix=if($platformName-ceq'windows'){'.exe'}else{'.linux'};$artifact=Join-Path $output "1756-$platformName-$optimization$suffix";$compile=@(Compiler-Run "1756-$platformName-$optimization-compile" @('build',$fixturePath,'-o',$artifact,'--target',$target,'--llvm',$llvmRoot,"-$optimization",'--keep-temps'))[-1];Require-Success $compile "${platformName}_${optimization}_COMPILE_FAILED" -RejectDiagnostics;$check.warningCount=0;$check.noteCount=0;$stem=[IO.Path]::GetFileNameWithoutExtension($artifact);$ll=Join-Path $output "$stem.slg-tmp/$stem.ll";$closure=@(Run "1756-$platformName-$optimization-V004" $pwsh @('-NoProfile','-File',$closureVerifier,'-LlvmPath',$ll))[-1];Require-Success $closure "${platformName}_${optimization}_V004_FAILED" -RejectDiagnostics;$bc=Join-Path $output "$stem.bc";$assembly=@(Run "1756-$platformName-$optimization-llvm-as" $llvmAs @($ll,'-o',$bc))[-1];Require-Success $assembly "${platformName}_${optimization}_LLVM_AS_FAILED" -RejectDiagnostics;$runtime=if($platformName-ceq'windows'){@(Run "1756-$platformName-$optimization-runtime" $artifact @())[-1]}else{@(Run "1756-$platformName-$optimization-runtime" $wsl @('-d',$WslDistribution,'--',(Wsl-Path $artifact)))[-1]};Require-Success $runtime "${platformName}_${optimization}_RUNTIME_FAILED";if((Hash-Bytes $runtime.StdoutBytes)-cne(Hash-Bytes $expectedBytes)){$currentFailureId="${platformName}_${optimization}_STDOUT_MISMATCH";throw 'exact stdout mismatch'};if($platformName-ceq'windows'-and$optimization-ceq'O0'){$windowsO0Stdout=Join-Path $root $runtime.Audit.stdoutPath};$check.status='passed';$check.stdoutSha256=$runtime.Audit.stdoutSha256;$check.stdoutBytes=$runtime.Audit.stdoutBytes;$check.llvmSha256=Hash $ll;$check.bitcodeSha256=Hash $bc;$check.artifactSha256=Hash $artifact;$platform.completed++;$record.completed++};$platform.status='passed'}
        $record.python.status='failed';$oracle=@(Run '1756-python-zipfile-oracle' $python @($oraclePath,$windowsO0Stdout))[-1];Require-Success $oracle PYTHON_ORACLE_FAILED;$record.python.status='passed';$record.python.completed=1;$record.python.stdoutSha256=$oracle.Audit.stdoutSha256;$record.python.stdoutBytes=$oracle.Audit.stdoutBytes;$record.completed++
        $record.browser.status='failed';$wasm=Join-Path $output '1756-browser.wasm';$compile=@(Compiler-Run '1756-browser-compile' @('build',$fixturePath,'-o',$wasm,'--target','wasm32-browser','--llvm',$llvmRoot,'-O0','--keep-temps'))[-1];Require-Success $compile BROWSER_COMPILE_FAILED -RejectDiagnostics;$record.browser.warningCount=0;$record.browser.noteCount=0;$record.browser.artifactProduced=Test-Path -LiteralPath $wasm;$bytes=[IO.File]::ReadAllBytes($wasm);$record.browser.wasmMagicValid=$bytes.Length-ge 4-and$bytes[0]-eq 0-and$bytes[1]-eq 0x61-and$bytes[2]-eq 0x73-and$bytes[3]-eq 0x6D;if(-not$record.browser.wasmMagicValid){$currentFailureId='BROWSER_MAGIC_INVALID';throw 'invalid wasm magic'};$stem=[IO.Path]::GetFileNameWithoutExtension($wasm);$ll=Join-Path $output "$stem.slg-tmp/$stem.ll";$closure=@(Run '1756-browser-V004' $pwsh @('-NoProfile','-File',$closureVerifier,'-LlvmPath',$ll))[-1];Require-Success $closure BROWSER_V004_FAILED -RejectDiagnostics;$bc=Join-Path $output '1756-browser.bc';$assembly=@(Run '1756-browser-llvm-as' $llvmAs @($ll,'-o',$bc))[-1];Require-Success $assembly BROWSER_LLVM_AS_FAILED -RejectDiagnostics;$runtime=@(Run '1756-browser-node-exact' $node @($browserRunner,$wasm,$expectedPath))[-1];Require-Success $runtime BROWSER_RUNTIME_FAILED;$browserExpected=[Text.Encoding]::UTF8.GetBytes("PASS browser program: $($expectedBytes.Length) output characters`n");$record.browser.exactOutput=(Hash-Bytes $runtime.StdoutBytes)-ceq(Hash-Bytes $browserExpected);if(-not$record.browser.exactOutput){$currentFailureId='BROWSER_STDOUT_MISMATCH';throw 'browser exact output mismatch'};$record.browser.status='passed';$record.browser.completed=1;$record.browser.stdoutSha256=$runtime.Audit.stdoutSha256;$record.browser.stdoutBytes=$runtime.Audit.stdoutBytes;$record.browser.llvmSha256=Hash $ll;$record.browser.bitcodeSha256=Hash $bc;$record.browser.artifactSha256=Hash $wasm;$record.completed++;$record.status='passed'
        }
    }
}catch{$caught=$_;$record.status='failed';$record.failureIds=@($currentFailureId)}finally{$record.inputs.end=Snapshot $paths;$record.compiler.sha256End=if($record.inputs.end.Contains('compiler')){$record.inputs.end.compiler}else{$null};foreach($key in @($record.inputs.start.Keys)+@($record.inputs.end.Keys)|Sort-Object -Unique){if($record.inputs.start[$key]-cne$record.inputs.end[$key]){$record.failureIds+= "INPUT_DRIFT:$key";$record.status='failed'}};$record.failureIds=@($record.failureIds|Sort-Object -Unique);Normalize-Audit;$record.finishedUtc=[DateTimeOffset]::UtcNow.ToString('O');$json=($record|ConvertTo-Json -Depth 20)+"`n";if(-not($json|Test-Json -SchemaFile $resultSchemaPath)){throw 'result schema rejected verifier result'};[IO.File]::WriteAllText((Join-Path $output 'result.json'),$json,[Text.UTF8Encoding]::new($false));Write-Host "[ZIP DEFLATE] $($record.status) $($record.completed)/$($record.planned); result=$(Join-Path $output 'result.json')"}
if($record.compiler.sha256Start-ceq$ExpectedCompilerSha256-and$record.compiler.sha256End-ceq$ExpectedCompilerSha256){& $resultVerifier -RepositoryRoot $root -ResultPath (Join-Path $output 'result.json') -ExpectedCompilerSha256 $ExpectedCompilerSha256}
if($null-ne$caught){throw $caught}
