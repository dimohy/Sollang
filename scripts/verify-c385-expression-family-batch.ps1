[CmdletBinding()]
param(
    [string]$ManagedCompilerPath = '',
    [ValidatePattern('^$|^[A-Fa-f0-9]{64}$')][string]$ExpectedManagedCompilerSha256 = '',
    [string]$SelfhostCompilerPath = '',
    [ValidatePattern('^$|^[A-Fa-f0-9]{64}$')][string]$ExpectedSelfhostCompilerSha256 = '',
    [string]$OutputDirectory = '',
    [switch]$ValidateContractOnly
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
function BytesHash([byte[]]$Bytes) { return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)) }
function EmptyHash { return BytesHash ([byte[]]::new(0)) }
function Run([string]$File, [string[]]$Arguments, [string]$Description) {
    return Invoke-VerificationProcessCapture -FilePath $File -ArgumentList $Arguments -WorkingDirectory $root -Description $Description -TimeoutMilliseconds 120000
}
function Resolve-ContainedFile([string]$Path, [string]$Label) {
    $resolved = (Resolve-Path -LiteralPath (Repo $Path)).Path
    if (-not $resolved.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "C385 $Label must be under the repository root"
    }
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf) -or (Get-Item -LiteralPath $resolved).Length -eq 0) {
        throw "C385 $Label is missing or empty: $resolved"
    }
    return $resolved
}
function Find-NthBytes([byte[]]$Haystack, [byte[]]$Needle, [int]$Occurrence) {
    $seen = 0
    for ($start = 0; $start -le $Haystack.Length - $Needle.Length; $start++) {
        $equal = $true
        for ($offset = 0; $offset -lt $Needle.Length; $offset++) {
            if ($Haystack[$start + $offset] -ne $Needle[$offset]) { $equal = $false; break }
        }
        if ($equal) {
            if ($seen -eq $Occurrence) { return $start }
            $seen++
        }
    }
    return -1
}
function Assert-ContractAuthority($Contract, $ParityContract) {
    $expectedIds = @('1700-selfhost-binary-binding-after-propagation','1701-expression-context-shape-parity','25-arrays-dictionaries','16-condition-when-subject')
    if ((@($Contract.fixtures.id) -join '|') -cne ($expectedIds -join '|')) { throw 'C385 fixture identity/order drifted' }
    $probes = @($Contract.fixtures.probes)
    if ($Contract.fixtureCount -ne 4 -or $Contract.familyCount -ne 13 -or $probes.Count -ne 13 -or @($probes.family | Sort-Object -Unique).Count -ne 13) {
        throw 'C385 fixture/family denominator drifted'
    }
    foreach ($fixture in $Contract.fixtures) {
        $source = Resolve-ContainedFile $fixture.source "fixture $($fixture.id)"
        $expected = Resolve-ContainedFile $fixture.expected "expected $($fixture.id)"
        if ((Get-Item -LiteralPath $expected).Length -eq 0) { throw "C385 expected output is empty: $($fixture.id)" }
        $sourceBytes = [IO.File]::ReadAllBytes($source)
        foreach ($probe in $fixture.probes) {
            $mapping = @($ParityContract.mappings | Where-Object managedExpression -CEQ $probe.family)
            if ($mapping.Count -ne 1 -or (@($mapping[0].selfhostAstKinds) -join '/') -cne (@($probe.astKinds) -join '/') -or
                (@($mapping[0].typedIrKinds) -join '/') -cne (@($probe.typedIrKinds) -join '/')) {
                throw "C385 probe does not match parity authority: $($probe.family)"
            }
            $anchor = [Text.Encoding]::UTF8.GetBytes([string]$probe.anchor)
            if ((Find-NthBytes $sourceBytes $anchor ([int]$probe.occurrence)) -lt 0) { throw "C385 anchor is absent: $($probe.family)" }
        }
    }
}
function New-RunRecord {
    return [ordered]@{ compileExit=$null; warningNoteCount=0; llvmAsExit=$null; v004Exit=$null; nativeExit=$null; stdoutSha256=(EmptyHash); stderrSha256=(EmptyHash); stdoutExact=$false }
}
function New-SchemaControlRecord([string]$Status) {
    $sha = 'A' * 64
    $runs = @()
    foreach ($id in @('1700-selfhost-binary-binding-after-propagation','1701-expression-context-shape-parity','25-arrays-dictionaries','16-condition-when-subject')) {
        $run = [ordered]@{compileExit=0;warningNoteCount=0;llvmAsExit=0;v004Exit=0;nativeExit=0;stdoutSha256=$sha;stderrSha256='E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855';stdoutExact=$true}
        $selfhostRun = [ordered]@{compileExit=0;warningNoteCount=0;llvmAsExit=0;v004Exit=0;nativeExit=0;stdoutSha256=$sha;stderrSha256='E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855';stdoutExact=$true}
        $runs += [ordered]@{id=$id;expectedSha256=$sha;managed=$run;selfhost=$selfhostRun}
    }
    $hashes = [ordered]@{}; 1..12 | ForEach-Object { $hashes["input$_"] = $sha }
    $endHashes = [ordered]@{}; foreach ($entry in $hashes.GetEnumerator()) { $endHashes[$entry.Key] = $entry.Value }
    return [ordered]@{schemaVersion=1;defectId='C2026-09-12-385';status=$Status;managedCompiler=[ordered]@{path='managed.dll';sha256=$sha;expectedSha256=$sha;matched=$true};selfhostCompiler=[ordered]@{path='selfhost.exe';sha256=$sha;expectedSha256=$sha;matched=$true};inputStable=$true;inputDrift=@();inputHashesStart=$hashes;inputHashesEnd=$endHashes;authority=[ordered]@{completed=3;total=3;fixtureCount=4;familyCount=13};typedIr=[ordered]@{completed=2;total=2;sequentialParallelExact=$true;sourceSpanChecks=13;sourceSpanTotal=13};fixtures=$runs;failureIds=@();failure=$null}
}
function Test-ResultSchemaControls([string]$SchemaPath) {
    $positive = New-SchemaControlRecord 'passed'
    if (-not (($positive | ConvertTo-Json -Depth 12) | Test-Json -SchemaFile $SchemaPath -ErrorAction Stop)) { throw 'C385 positive schema control failed' }
    $forgedCount = New-SchemaControlRecord 'passed'; $forgedCount.typedIr.sourceSpanChecks = 12
    $forgedSha = New-SchemaControlRecord 'passed'; $forgedSha.selfhostCompiler.matched = $false
    $emptyFailure = New-SchemaControlRecord 'failed'; $emptyFailure.failure = 'failed'
    $unstable = New-SchemaControlRecord 'passed'; $unstable.inputStable = $false; $unstable.inputDrift = @('fixture')
    foreach ($negative in @($forgedCount,$forgedSha,$emptyFailure,$unstable)) {
        if (($negative | ConvertTo-Json -Depth 12) | Test-Json -SchemaFile $SchemaPath -ErrorAction SilentlyContinue) { throw 'C385 negative schema control was accepted' }
    }
    return 5
}
function Invoke-RawProcess([string]$File, [string[]]$Arguments, [string]$Description, [string]$StdoutPath, [string]$StderrPath) {
    $process = Start-Process -FilePath $File -ArgumentList $Arguments -WorkingDirectory $root -RedirectStandardOutput $StdoutPath -RedirectStandardError $StderrPath -PassThru -WindowStyle Hidden
    try { Wait-VerificationProcess -Process $process -Description $Description -TimeoutMilliseconds 120000; $process.WaitForExit(); return $process.ExitCode }
    finally { $process.Dispose() }
}
function CompilerInvocation([string]$Compiler, [string[]]$Arguments) {
    if ([IO.Path]::GetExtension($Compiler) -ieq '.dll') { return [pscustomobject]@{File='dotnet';Args=@($Compiler)+$Arguments} }
    return [pscustomobject]@{File=$Compiler;Args=$Arguments}
}
function Verify-Native([string]$Compiler, [string]$CompilerLabel, $Fixture, [string]$Output, [string]$LlvmRoot, [string]$ClosureVerifier) {
    $record = New-RunRecord
    $prefix = Join-Path $Output "$($Fixture.id).$CompilerLabel"
    $exe = "$prefix.exe"; $ll = "$prefix.ll"; $compileOut="$prefix.compile.stdout"; $compileErr="$prefix.compile.stderr"
    $args = @('build',(Repo $Fixture.source),'-o',$exe,'--target','windows-x64','--llvm',$LlvmRoot,'--stdlib',(Repo 'stdlib'),'--jobs','4','-O1','--keep-temps')
    $invocation = CompilerInvocation $Compiler $args
    $record.compileExit = Invoke-RawProcess $invocation.File $invocation.Args "C385 $CompilerLabel $($Fixture.id) compile" $compileOut $compileErr
    $diagnostics = [IO.File]::ReadAllText($compileOut) + [IO.File]::ReadAllText($compileErr)
    $record.warningNoteCount = [regex]::Matches($diagnostics, '(?im)^(?:warning|note)\b').Count
    if ($record.compileExit -ne 0 -or $record.warningNoteCount -ne 0 -or (Get-Item $compileErr).Length -ne 0 -or -not (Test-Path $ll) -or -not (Test-Path $exe)) { throw "C385 $CompilerLabel $($Fixture.id) compile failed or diagnosed" }
    $as = Run (Join-Path $LlvmRoot 'bin/llvm-as.exe') @($ll,'-o',"$prefix.bc") "C385 $CompilerLabel $($Fixture.id) llvm-as"; $record.llvmAsExit=$as.ExitCode
    $v004 = Run 'pwsh' @('-NoProfile','-File',$ClosureVerifier,'-LlvmPath',$ll) "C385 $CompilerLabel $($Fixture.id) V004"; $record.v004Exit=$v004.ExitCode
    if ($record.llvmAsExit -ne 0 -or $record.v004Exit -ne 0) { throw "C385 $CompilerLabel $($Fixture.id) LLVM validation failed" }
    $nativeOut="$prefix.native.stdout"; $nativeErr="$prefix.native.stderr"
    $record.nativeExit = Invoke-RawProcess $exe @() "C385 $CompilerLabel $($Fixture.id) native" $nativeOut $nativeErr
    $actual=[IO.File]::ReadAllBytes($nativeOut); $expected=[IO.File]::ReadAllBytes((Repo $Fixture.expected)); $stderr=[IO.File]::ReadAllBytes($nativeErr)
    $record.stdoutSha256=BytesHash $actual; $record.stderrSha256=BytesHash $stderr
    $record.stdoutExact=[Linq.Enumerable]::SequenceEqual[byte]($actual,$expected)
    if ($record.nativeExit-ne0 -or -not $record.stdoutExact -or $stderr.Length-ne0) { throw "C385 $CompilerLabel $($Fixture.id) native exact failed" }
    return $record
}

$contractPath = Repo 'scripts/contracts/c385-expression-family-batch.json'
$contractSchemaPath = Repo 'scripts/contracts/c385-expression-family-batch.schema.json'
$resultSchemaPath = Repo 'scripts/contracts/c385-expression-family-batch-result.schema.json'
$parityPath = Repo 'scripts/contracts/expression-lowering-parity.json'
$closurePath = Repo 'scripts/verify-llvm-direct-call-closure.ps1'
$processPath = Repo 'scripts/verification-process.ps1'
$llvmRoot = Repo '.tools/llvm-22.1.8'
$contractText = [IO.File]::ReadAllText($contractPath)
if (-not ($contractText | Test-Json -SchemaFile $contractSchemaPath -ErrorAction Stop)) { throw 'C385 contract schema failed' }
$contract = $contractText | ConvertFrom-Json
$parity = [IO.File]::ReadAllText($parityPath) | ConvertFrom-Json
Assert-ContractAuthority $contract $parity
$schemaControls = Test-ResultSchemaControls $resultSchemaPath
if ($ValidateContractOnly) {
    Write-Host "[C385 contract] PASS contract 1/1; authority 13/13; result schema controls $schemaControls/5"
    return
}

if ([string]::IsNullOrWhiteSpace($ManagedCompilerPath) -or [string]::IsNullOrWhiteSpace($SelfhostCompilerPath) -or
    [string]::IsNullOrWhiteSpace($ExpectedManagedCompilerSha256) -or [string]::IsNullOrWhiteSpace($ExpectedSelfhostCompilerSha256) -or [string]::IsNullOrWhiteSpace($OutputDirectory)) {
    throw 'C385 execution requires paired managed/selfhost compiler paths and SHA-256 values plus OutputDirectory'
}
$managed = Resolve-ContainedFile $ManagedCompilerPath 'managed compiler'
$selfhost = Resolve-ContainedFile $SelfhostCompilerPath 'selfhost compiler'
$ExpectedManagedCompilerSha256=$ExpectedManagedCompilerSha256.ToUpperInvariant(); $ExpectedSelfhostCompilerSha256=$ExpectedSelfhostCompilerSha256.ToUpperInvariant()
$output=Repo $OutputDirectory
if (-not $output.StartsWith((Repo 'artifacts/scratch')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'C385 output must be under artifacts/scratch' }
if ((Test-Path $output) -and @(Get-ChildItem $output -Force).Count) { throw 'C385 output must be new or empty' }
[IO.Directory]::CreateDirectory($output)|Out-Null

$inputs = [ordered]@{ managedCompiler=$managed; selfhostCompiler=$selfhost; contract=$contractPath; contractSchema=$contractSchemaPath; resultSchema=$resultSchemaPath; parityContract=$parityPath; verifier=[IO.Path]::GetFullPath($PSCommandPath); processHelper=$processPath; closureVerifier=$closurePath; llvmAs=(Join-Path $llvmRoot 'bin/llvm-as.exe'); clang=(Join-Path $llvmRoot 'bin/clang.exe') }
foreach ($fixture in $contract.fixtures) {
    $inputs["source-$($fixture.id)"] = Repo $fixture.source
    $inputs["expected-$($fixture.id)"] = Repo $fixture.expected
}
$stdlibIndex = 0
$stdlibPaths = @([IO.Directory]::GetFiles((Repo 'stdlib'), '*.slg', [IO.SearchOption]::AllDirectories) | Sort-Object)
foreach ($path in $stdlibPaths) { $inputs[('stdlib-{0:D4}' -f $stdlibIndex)] = $path; $stdlibIndex++ }
$start = [ordered]@{}
foreach ($entry in $inputs.GetEnumerator()) { $start[$entry.Key] = Hash $entry.Value }
if ($start.managedCompiler -cne $ExpectedManagedCompilerSha256) { throw "C385 managed compiler hash mismatch: expected=$ExpectedManagedCompilerSha256 actual=$($start.managedCompiler)" }
if ($start.selfhostCompiler -cne $ExpectedSelfhostCompilerSha256) { throw "C385 selfhost compiler hash mismatch: expected=$ExpectedSelfhostCompilerSha256 actual=$($start.selfhostCompiler)" }

$authority=[ordered]@{completed=3;total=3;fixtureCount=4;familyCount=13}
$typed=[ordered]@{completed=0;total=2;sequentialParallelExact=$false;sourceSpanChecks=0;sourceSpanTotal=13}
$fixtureResults=@();$failureIds=[Collections.Generic.List[string]]::new();$failure=$null
try {
    foreach($fixture in $contract.fixtures){
        $source=Repo $fixture.source
        $ast = Run $selfhost @('ast-nodes',$source) "C385 $($fixture.id) AST"
        if ($ast.ExitCode -ne 0 -or $ast.Stderr.Length -ne 0) { throw "C385 $($fixture.id) AST failed" }
        $seq = Run $selfhost @('typed-ir-nodes',$source) "C385 $($fixture.id) sequential Typed IR"
        $par = Run $selfhost @('typed-ir-nodes-parallel',$source) "C385 $($fixture.id) parallel Typed IR"
        if ($seq.ExitCode -ne 0 -or $par.ExitCode -ne 0 -or $seq.Stderr.Length -ne 0 -or $par.Stderr.Length -ne 0 -or $seq.Stdout -cne $par.Stdout) { throw "C385 $($fixture.id) Typed IR identity failed" }
        $astNodes=@();foreach($line in $ast.Stdout.Replace("`r`n","`n")-split"`n"){if($line-match'^node (?<id>\d+) kind (?<kind>\d+) parent -?\d+ start (?<start>\d+) length (?<length>\d+)'){$astNodes += [pscustomobject]@{id=[int]$Matches.id;kind=[int]$Matches.kind;start=[int]$Matches.start;length=[int]$Matches.length}}}
        $irNodes=@();foreach($line in $seq.Stdout.Replace("`r`n","`n")-split"`n"){if($line-match'^node \d+ kind (?<kind>\d+) parent -?\d+ source (?<source>-?\d+) ast (?<ast>-?\d+)'){$irNodes += [pscustomobject]@{kind=[int]$Matches.kind;source=[int]$Matches.source;ast=[int]$Matches.ast}}}
        $sourceBytes=[IO.File]::ReadAllBytes($source)
        foreach($probe in $fixture.probes){
            $anchor=[Text.Encoding]::UTF8.GetBytes([string]$probe.anchor);$startByte=Find-NthBytes $sourceBytes $anchor ([int]$probe.occurrence);$endByte=$startByte+$anchor.Length
            $candidates = @($astNodes | Where-Object { $_.kind -in @($probe.astKinds) -and (if ($probe.selector -ceq 'exact') { $_.start -eq $startByte -and $_.length -eq $anchor.Length } else { $_.start -le $startByte -and ($_.start + $_.length) -ge $endByte }) } | Sort-Object length)
            if ($candidates.Count -eq 0) { throw "C385 AST span missing: $($probe.family)" }
            $selected = $candidates[0]
            if (@($irNodes | Where-Object { $_.ast -eq $selected.id -and $_.kind -in @($probe.typedIrKinds) }).Count -eq 0) { throw "C385 Typed IR kind missing: $($probe.family)" }
            $typed.sourceSpanChecks++
        }
        $fixtureResults += [ordered]@{ id=$fixture.id; expectedSha256=(Hash (Repo $fixture.expected)); managed=(Verify-Native $managed 'managed' $fixture $output $llvmRoot $closurePath); selfhost=(Verify-Native $selfhost 'selfhost' $fixture $output $llvmRoot $closurePath) }
    }
    $typed.sequentialParallelExact=$true;$typed.completed=2
}catch{$failure=$_.Exception.Message;[void]$failureIds.Add('C385_FOCUSED_FAILED')}
$end = [ordered]@{}; $drift = [Collections.Generic.List[string]]::new()
foreach ($entry in $inputs.GetEnumerator()) { try { $end[$entry.Key] = Hash $entry.Value; if ($end[$entry.Key] -cne $start[$entry.Key]) { [void]$drift.Add($entry.Key) } } catch { $end[$entry.Key] = '0' * 64; [void]$drift.Add($entry.Key) } }
if ($drift.Count -gt 0) { [void]$failureIds.Add('C385_INPUT_DRIFT'); if ($null -eq $failure) { $failure='C385 input drift' } }
$failureIds = @($failureIds | Select-Object -Unique)
$record=[ordered]@{schemaVersion=1;defectId='C2026-09-12-385';status=if($failureIds.Count){'failed'}else{'passed'};managedCompiler=[ordered]@{path=[IO.Path]::GetRelativePath($root,$managed).Replace('\','/');sha256=$start.managedCompiler;expectedSha256=$ExpectedManagedCompilerSha256;matched=($start.managedCompiler-ceq$ExpectedManagedCompilerSha256-and$end.managedCompiler-ceq$ExpectedManagedCompilerSha256)};selfhostCompiler=[ordered]@{path=[IO.Path]::GetRelativePath($root,$selfhost).Replace('\','/');sha256=$start.selfhostCompiler;expectedSha256=$ExpectedSelfhostCompilerSha256;matched=($start.selfhostCompiler-ceq$ExpectedSelfhostCompilerSha256-and$end.selfhostCompiler-ceq$ExpectedSelfhostCompilerSha256)};inputStable=$drift.Count-eq0;inputDrift=@($drift);inputHashesStart=$start;inputHashesEnd=$end;authority=$authority;typedIr=$typed;fixtures=$fixtureResults;failureIds=$failureIds;failure=if($failureIds.Count){$failure}else{$null}}
$resultPath = Join-Path $output 'result.json'; $json = ($record | ConvertTo-Json -Depth 12) + "`n"; [IO.File]::WriteAllText($resultPath,$json,[Text.UTF8Encoding]::new($false))
if (-not ($json | Test-Json -SchemaFile $resultSchemaPath -ErrorAction Stop)) { throw 'C385 result schema rejected result' }
if ($record.status -ne 'passed') { throw "C385 focused failed: $failure; result=$resultPath" }
Write-Host "[C385 13-family batch] PASS authority 3/3; Typed IR 13/13 and 2/2; managed/selfhost exact 4/4 each; result=$resultPath"
