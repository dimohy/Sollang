[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory)][string]$ResultPath,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCompilerSha256
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$result = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($ResultPath)) { $ResultPath } else { Join-Path $root $ResultPath }))
$scratch = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch')).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $result.StartsWith($scratch, [StringComparison]::OrdinalIgnoreCase)) { throw 'result must be under artifacts/scratch' }
$schema = Join-Path $root 'scripts/contracts/zip-deflate-method8-result.schema.json'
$text = [IO.File]::ReadAllText($result)
if (-not ($text | Test-Json -SchemaFile $schema)) { throw 'ZIP DEFLATE result schema rejected result' }
$record = $text | ConvertFrom-Json
$ExpectedCompilerSha256 = $ExpectedCompilerSha256.ToUpperInvariant()

function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Equal-Map($Left, $Right) {
    $leftNames=@($Left.PSObject.Properties.Name|Sort-Object);$rightNames=@($Right.PSObject.Properties.Name|Sort-Object)
    if(($leftNames-join"`n")-cne($rightNames-join"`n")){return $false}
    foreach($name in $leftNames){if($Left.$name-cne$Right.$name){return $false}}
    $true
}
function Equal-Set($Left, $Right) { (@($Left|Sort-Object -Unique)-join',') -ceq (@($Right|Sort-Object -Unique)-join',') }
function Invocation([string]$Id) { $found=@($record.processAudit.invocations|Where-Object id -CEQ $Id);if($found.Count-ne 1){throw "expected one invocation: $Id"};$found[0] }
function Verify-Invocation($item) {
    foreach($member in @('stdoutPath','stderrPath')){$path=[IO.Path]::GetFullPath((Join-Path $root $item.$member));if(-not$path.StartsWith($scratch,[StringComparison]::OrdinalIgnoreCase)){throw "invocation path escaped scratch: $($item.id)"};if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "invocation log missing: $($item.id)"};$prefix=if($member-ceq'stdoutPath'){'stdout'}else{'stderr'};if((Hash $path)-cne$item."${prefix}Sha256"-or(Get-Item -LiteralPath $path).Length-ne$item."${prefix}Bytes"){throw "invocation log identity mismatch: $($item.id)"}}
}

if($record.compiler.sha256Start-cne$ExpectedCompilerSha256-or$record.compiler.sha256End-cne$ExpectedCompilerSha256){throw 'compiler provenance drift'}
if(-not(Test-Path -LiteralPath $record.compiler.path -PathType Leaf)-or(Hash $record.compiler.path)-cne$ExpectedCompilerSha256){throw 'compiler artifact identity mismatch'}
if(-not(Equal-Map $record.inputs.start $record.inputs.end)){throw 'input hash drift'}
$expectedInputs=[ordered]@{
    compiler=$record.compiler.path
    verifier=(Join-Path $root 'scripts/verify-zip-deflate-method8-focused.ps1')
    contract=(Join-Path $root 'scripts/contracts/zip-deflate-method8.json')
    contractSchema=(Join-Path $root 'scripts/contracts/zip-deflate-method8.schema.json')
    resultSchema=(Join-Path $root 'scripts/contracts/zip-deflate-method8-result.schema.json')
    resultVerifier=(Join-Path $root 'scripts/verify-zip-deflate-method8-result.ps1')
    contractVerifier=(Join-Path $root 'scripts/verify-zip-deflate-method8-contract.ps1')
    fixture=(Join-Path $root 'examples/regression/1756-zip-deflate-method8.slg')
    formatter=(Join-Path $root 'scripts/format-authoritative-slg.ps1')
}
if($record.mode-cne'semantic-preflight'){$expectedInputs.expected=Join-Path $root 'examples/regression/expected/1756-zip-deflate-method8.stdout.txt';$expectedInputs.oracle=Join-Path $root 'scripts/probes/zip-deflate-method8/verify_python_oracle.py';$expectedInputs.closure=Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1';$expectedInputs.browserRunner=Join-Path $root 'scripts/verify-browser-program.mjs';$expectedInputs.llvmAs=Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe'}
foreach($id in @('affine-writer-reuse','affine-decoder-reuse')){$expectedInputs["negative:$id"]=Join-Path $root "scripts/probes/zip-deflate-method8/$id.slg";$expectedInputs["negativeExpected:$id"]=Join-Path $root "scripts/probes/zip-deflate-method8/$id.stderr.contains.txt"}
foreach($source in @(Get-ChildItem -LiteralPath (Join-Path $root 'stdlib') -Recurse -File -Filter '*.slg'|Sort-Object FullName)){$relative=[IO.Path]::GetRelativePath($root,$source.FullName).Replace('\','/');$expectedInputs["stdlib:$relative"]=$source.FullName}
$observedInputNames=@($record.inputs.start.PSObject.Properties.Name|Sort-Object);$expectedInputNames=@($expectedInputs.Keys|Sort-Object);if(($observedInputNames-join"`n")-cne($expectedInputNames-join"`n")){throw 'input key topology mismatch'}
foreach($entry in $expectedInputs.GetEnumerator()){if(-not(Test-Path -LiteralPath $entry.Value -PathType Leaf)-or(Hash $entry.Value)-cne$record.inputs.start.($entry.Key)){throw "current input identity mismatch: $($entry.Key)"}}
foreach($item in $record.processAudit.invocations){Verify-Invocation $item}
$invocations=@($record.processAudit.invocations)
$invocationRoots=@($invocations|ForEach-Object{$_.processId});if(-not(Equal-Set $record.processAudit.rootProcessIds $invocationRoots)){throw 'root process audit mismatch'}
$invocationDescendants=@($invocations|ForEach-Object{$_.descendantProcessIds});if(-not(Equal-Set $record.processAudit.descendantProcessIds $invocationDescendants)){throw 'descendant process audit mismatch'}
$invocationOrphans=@($invocations|ForEach-Object{$_.orphanProcessIds});if(-not(Equal-Set $record.processAudit.orphanProcessIds $invocationOrphans)){throw 'orphan process audit mismatch'}

if($record.status-ceq'passed'){
    $expectedInvocationIds=[Collections.Generic.List[string]]::new()
    foreach($id in @('1756-zip-deflate-method8','affine-writer-reuse','affine-decoder-reuse')){$expectedInvocationIds.Add("format-$id")}
    foreach($id in @('affine-writer-reuse','affine-decoder-reuse')){$expectedInvocationIds.Add("negative-$id")}
    foreach($platformName in @('windows','linux')){foreach($optimization in @('O0','O2')){foreach($step in @('compile','V004','llvm-as','runtime')){$expectedInvocationIds.Add("1756-$platformName-$optimization-$step")}}}
    foreach($id in @('1756-python-zipfile-oracle','1756-browser-compile','1756-browser-V004','1756-browser-llvm-as','1756-browser-node-exact')){$expectedInvocationIds.Add($id)}
    $actualInvocationIds=@($record.processAudit.invocations.id);if($actualInvocationIds.Count-ne$expectedInvocationIds.Count-or-not(Equal-Set $actualInvocationIds $expectedInvocationIds)){throw 'invocation topology mismatch'}
    foreach($item in $record.processAudit.invocations){$negative=$item.id.StartsWith('negative-',[StringComparison]::Ordinal);if($negative){if($item.exitCode-eq 0-or$item.orphanProcessIds.Count-ne 0){throw "semantic negative process contract mismatch: $($item.id)"};$id=$item.id.Substring('negative-'.Length);$diagnosticPath=Join-Path $root "scripts/probes/zip-deflate-method8/$id.stderr.contains.txt";$diagnostic=[IO.File]::ReadAllText((Join-Path $root $item.stdoutPath))+[IO.File]::ReadAllText((Join-Path $root $item.stderrPath));if(-not$diagnostic.Contains([IO.File]::ReadAllText($diagnosticPath).Trim(),[StringComparison]::Ordinal)-or(Test-Path -LiteralPath (Join-Path (Split-Path -Parent $result) "$id.exe"))){throw "semantic negative evidence mismatch: $id"}}elseif($item.exitCode-ne 0-or$item.stderrBytes-ne 0-or$item.orphanProcessIds.Count-ne 0){throw "successful invocation contract mismatch: $($item.id)"}}
    $expected=Join-Path $root 'examples/regression/expected/1756-zip-deflate-method8.stdout.txt';$expectedHash=Hash $expected;$expectedBytes=(Get-Item -LiteralPath $expected).Length
    foreach($platformName in @('windows','linux')){foreach($check in $record.$platformName.checks){$compile=Invocation "1756-$platformName-$($check.optimization)-compile";$compileText=[IO.File]::ReadAllText((Join-Path $root $compile.stdoutPath));if($compileText-match'(?im)(?:^|\r?\n)\s*(?:warning|note)\b'){throw "compiler diagnostic contract mismatch: $platformName/$($check.optimization)"};$runtime=Invocation "1756-$platformName-$($check.optimization)-runtime";if($check.stdoutSha256-cne$expectedHash-or$check.stdoutBytes-ne$expectedBytes-or$runtime.stdoutSha256-cne$expectedHash-or$runtime.stdoutBytes-ne$expectedBytes){throw "native exact output mismatch: $platformName/$($check.optimization)"};$artifact=Join-Path (Split-Path -Parent $result) "1756-$platformName-$($check.optimization)$(if($platformName-ceq'windows'){'.exe'}else{'.linux'})";$stem=[IO.Path]::GetFileNameWithoutExtension($artifact);$ll=Join-Path (Split-Path -Parent $result) "$stem.slg-tmp/$stem.ll";$bc=Join-Path (Split-Path -Parent $result) "$stem.bc";if((Hash $artifact)-cne$check.artifactSha256-or(Hash $ll)-cne$check.llvmSha256-or(Hash $bc)-cne$check.bitcodeSha256){throw "native artifact identity mismatch: $platformName/$($check.optimization)"}}}
    $browser=Invocation '1756-browser-node-exact';if($browser.stdoutSha256-cne$record.browser.stdoutSha256-or$browser.stdoutBytes-ne$record.browser.stdoutBytes){throw 'browser runtime evidence mismatch'}
    $python=Invocation '1756-python-zipfile-oracle';if($python.stdoutSha256-cne$record.python.stdoutSha256-or$python.stdoutBytes-ne$record.python.stdoutBytes){throw 'Python oracle evidence mismatch'}
}elseif($record.status-ceq'validated-semantic-negatives'){
    $expectedInvocationIds=@('format-1756-zip-deflate-method8','format-affine-writer-reuse','format-affine-decoder-reuse','negative-affine-writer-reuse','negative-affine-decoder-reuse')
    $actualInvocationIds=@($record.processAudit.invocations.id);if($actualInvocationIds.Count-ne$expectedInvocationIds.Count-or-not(Equal-Set $actualInvocationIds $expectedInvocationIds)){throw 'semantic preflight invocation topology mismatch'}
    foreach($id in @('affine-writer-reuse','affine-decoder-reuse')){$item=Invocation "negative-$id";if($item.exitCode-eq0-or$item.orphanProcessIds.Count-ne0){throw "semantic preflight process mismatch: $id"};$diagnosticPath=Join-Path $root "scripts/probes/zip-deflate-method8/$id.stderr.contains.txt";$diagnostic=[IO.File]::ReadAllText((Join-Path $root $item.stdoutPath))+[IO.File]::ReadAllText((Join-Path $root $item.stderrPath));if(-not$diagnostic.Contains([IO.File]::ReadAllText($diagnosticPath).Trim(),[StringComparison]::Ordinal)-or(Test-Path -LiteralPath (Join-Path (Split-Path -Parent $result) "$id.exe"))){throw "semantic preflight evidence mismatch: $id"}}
}elseif($record.status-ceq'validated-inputs'-and$record.processAudit.invocations.Count-ne 0){
    throw 'validate-inputs result unexpectedly contains process invocations'
}

Write-Host "PASS ZIP DEFLATE result semantic validation: $($record.status) $($record.completed)/$($record.planned)"
