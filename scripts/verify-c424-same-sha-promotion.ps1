[CmdletBinding()]
param(
    [string]$Compiler,
    [ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCompilerSha256,
    [string]$OutputDirectory = '',
    [switch]$SourceFreezeApproved,
    [switch]$ValidateInputsOnly,
    [switch]$ValidateSchemaControlsOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$utf8 = [Text.UTF8Encoding]::new($false, $true)
$emptySha = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([byte[]]::new(0)))
$caseIds = @('P1', 'R424A', 'N1', 'N2', 'R424N1', 'R424N2')
$expectedProcessIds = @(
    'P1-compile', 'P1-native', 'P1-llvm-as', 'P1-v004', 'P1-audit-link', 'P1-audit-native',
    'R424A-compile', 'R424A-native', 'R424A-llvm-as', 'R424A-v004', 'R424A-audit-link', 'R424A-audit-native',
    'N1-compile', 'N2-compile', 'R424N1-compile', 'R424N2-compile'
)

function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Hash-Bytes([byte[]]$Bytes) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)) }
function Hash-Text([string]$Text) { Hash-Bytes $utf8.GetBytes($Text) }
function Relative([string]$Path) { [IO.Path]::GetRelativePath($root, $Path).Replace('\', '/') }
function Is-RepositoryPath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $prefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
}

function Snapshot-Stdlib {
    $entries = @(Get-ChildItem -LiteralPath (Join-Path $root 'stdlib') -Recurse -File -Filter '*.slg' |
        Sort-Object { Relative $_.FullName } |
        ForEach-Object { [ordered]@{ path = Relative $_.FullName; sha256 = Hash $_.FullName } })
    $canonical = ($entries | ForEach-Object { "$($_.path)=$($_.sha256)`n" }) -join ''
    [ordered]@{ entries = $entries; sha256 = Hash-Text $canonical }
}

function Snapshot-Inputs([System.Collections.IDictionary]$Paths) {
    $snapshot = [ordered]@{}
    foreach ($entry in $Paths.GetEnumerator()) {
        $snapshot[$entry.Key] = if (Test-Path -LiteralPath $entry.Value -PathType Leaf) { Hash $entry.Value } else { '0' * 64 }
    }
    $snapshot
}

function Find-Drift([System.Collections.IDictionary]$Start, [System.Collections.IDictionary]$End) {
    @(@($Start.Keys) + @($End.Keys) | Sort-Object -Unique | Where-Object {
        -not $Start.Contains($_) -or -not $End.Contains($_) -or $Start[$_] -cne $End[$_]
    })
}

function Save-Stream([byte[]]$Bytes, [string]$Path) {
    [IO.File]::WriteAllBytes($Path, $Bytes)
    [ordered]@{ path = Relative $Path; sha256 = Hash-Bytes $Bytes; byteCount = $Bytes.Length }
}

function Observe-Descendants([int]$RootProcessId, [Collections.Generic.HashSet[int]]$Observed) {
    $rows = @(Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId -ErrorAction Stop)
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

$allRootProcessIds = [Collections.Generic.HashSet[int]]::new()
$allDescendantProcessIds = [Collections.Generic.HashSet[int]]::new()
$allOrphanProcessIds = [Collections.Generic.HashSet[int]]::new()
$processAuditIds = [Collections.Generic.List[string]]::new()

function Run-Tracked(
    [string]$Id,
    [string]$File,
    [string[]]$Arguments,
    [int]$ExpectedExitCode,
    [string]$LogPrefix,
    [string]$WorkingDirectory = $root
) {
    if ($processAuditIds.Contains($Id)) { throw "C424 duplicate process audit id: $Id" }
    $processAuditIds.Add($Id)
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $File
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $stdout = [IO.MemoryStream]::new()
    $stderr = [IO.MemoryStream]::new()
    $observed = [Collections.Generic.HashSet[int]]::new()
    try {
        if (-not $process.Start()) { throw "C424 process could not start: $Id" }
        $pid = $process.Id
        [void]$allRootProcessIds.Add($pid)
        $stdoutCopy = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
        $stderrCopy = $process.StandardError.BaseStream.CopyToAsync($stderr)
        $watch = [Diagnostics.Stopwatch]::StartNew()
        while (-not $process.WaitForExit(50)) {
            Observe-Descendants $pid $observed
            if ($watch.ElapsedMilliseconds -ge 120000) {
                Observe-Descendants $pid $observed
                foreach ($child in $observed) {
                    [void]$allDescendantProcessIds.Add($child)
                    if (Get-Process -Id $child -ErrorAction SilentlyContinue) { [void]$allOrphanProcessIds.Add($child) }
                }
                throw "C424 $Id exceeded 120000 ms; use the detached supervisor for a live process tree"
            }
        }
        Observe-Descendants $pid $observed
        $process.WaitForExit()
        $stdoutCopy.GetAwaiter().GetResult()
        $stderrCopy.GetAwaiter().GetResult()
        $deadline = [DateTime]::UtcNow.AddSeconds(2)
        do {
            $live = @($observed | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue })
            if ($live.Count -eq 0) { break }
            Start-Sleep -Milliseconds 50
        } while ([DateTime]::UtcNow -lt $deadline)
        $orphans = @($observed | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue } | Sort-Object -Unique)
        foreach ($child in $observed) { [void]$allDescendantProcessIds.Add($child) }
        foreach ($child in $orphans) { [void]$allOrphanProcessIds.Add($child) }
        $stdoutBytes = $stdout.ToArray()
        $stderrBytes = $stderr.ToArray()
        $combinedText = $utf8.GetString($stdoutBytes) + $utf8.GetString($stderrBytes)
        [ordered]@{
            id = $Id
            expectedExitCode = $ExpectedExitCode
            actualExitCode = $process.ExitCode
            exitMatched = $process.ExitCode -eq $ExpectedExitCode
            rootProcessId = $pid
            rootTerminated = $process.HasExited
            descendantProcessIds = @($observed | Sort-Object)
            orphanProcessIds = $orphans
            warningNoteCount = [regex]::Matches($combinedText, '(?im)\b(?:warning|note)\b').Count
            stdout = Save-Stream $stdoutBytes "$LogPrefix.stdout.bin"
            stderr = Save-Stream $stderrBytes "$LogPrefix.stderr.bin"
        }
    } finally {
        $stdout.Dispose()
        $stderr.Dispose()
        $process.Dispose()
    }
}

function Function-Body([string]$Llvm, [string]$FunctionName) {
    $match = [regex]::Match($Llvm, "(?ms)^define[^`r`n]*@$([regex]::Escape($FunctionName))\([^`r`n]*\)[^`r`n]*\{(?<body>.*?)^\}")
    if (-not $match.Success) { throw "C424 cannot isolate LLVM function @$FunctionName" }
    $match.Groups['body'].Value
}

function Inspect-P1-DropStructure([string]$Llvm) {
    $candidates = @()
    foreach ($child in [regex]::Matches($Llvm, '^(?<type>%sollang\.struct\.\d+)\s*=\s*type\s*\{\s*%sollang\.dynamic_int_array\s*,\s*i32\s*\}\s*$', 'Multiline')) {
        $childType = $child.Groups['type'].Value
        foreach ($parent in [regex]::Matches($Llvm, '^(?<type>%sollang\.struct\.\d+)\s*=\s*type\s*\{\s*' + [regex]::Escape($childType) + '\s*,\s*i32\s*\}\s*$', 'Multiline')) {
            $parentType = $parent.Groups['type'].Value
            $childDrops = [regex]::Matches($Llvm, '^define internal void @(?<name>sollang_drop_\d+)\(' + [regex]::Escape($childType) + '\s+%value\)[^\r\n]*\{\s*$', 'Multiline')
            $parentDrops = [regex]::Matches($Llvm, '^define internal void @(?<name>sollang_drop_\d+)\(' + [regex]::Escape($parentType) + '\s+%value\)[^\r\n]*\{\s*$', 'Multiline')
            if ($childDrops.Count -ne 1 -or $parentDrops.Count -ne 1) { continue }
            $childDrop = $childDrops[0].Groups['name'].Value
            $parentDrop = $parentDrops[0].Groups['name'].Value
            $childPattern = '(?m)^\s*call void @' + [regex]::Escape($childDrop) + '\('
            $parentPattern = '(?m)^\s*call void @' + [regex]::Escape($parentDrop) + '\('
            $childInParent = [regex]::Matches((Function-Body $Llvm $parentDrop), $childPattern).Count
            $independent = [regex]::Matches($Llvm, $childPattern).Count - $childInParent
            $parentCalls = [regex]::Matches($Llvm, $parentPattern).Count
            if ($childInParent -eq 1 -and $independent -eq 0 -and $parentCalls -eq 1) {
                $candidates += [ordered]@{
                    childType = $childType; parentType = $parentType
                    childDropFunction = $childDrop; parentDropFunction = $parentDrop
                    childDropCallsInParent = $childInParent; independentChildDropCalls = $independent; parentDropCalls = $parentCalls
                }
            }
        }
    }
    if ($candidates.Count -ne 1) { throw "C424 P1 expected one exact drop chain, found $($candidates.Count)" }
    $candidates[0]
}

function New-EmptyCase([object]$Authority, [string]$SourcePath) {
    [ordered]@{
        id = [string]$Authority.id; kind = [string]$Authority.kind; status = 'not-run'
        source = Relative $SourcePath; sourceSha256 = Hash $SourcePath
        compile = $null; run = $null; llvmPath = $null; llvmSha256 = $null; llvmAs = $null; v004 = $null; audit = $null
        expectedStdoutSha256 = if ($Authority.kind -eq 'positive') { Hash-Text ([string]$Authority.expectedStdout) } else { $null }
        expectedStdoutByteCount = if ($Authority.kind -eq 'positive') { $utf8.GetByteCount([string]$Authority.expectedStdout) } else { $null }
        outputExact = $false; diagnosticCount = 0; diagnosticExact = $false; llvmProduced = $false; warningNoteCount = 0
        dropStructure = $null; passed = $false; failureId = $null
    }
}

function New-DummyStream([int]$Bytes = 0) {
    [ordered]@{ path = 'artifacts/scratch/c424-static/stream.bin'; sha256 = if ($Bytes -eq 0) { $emptySha } else { 'A' * 64 }; byteCount = $Bytes }
}
function New-DummyProcess([string]$Id, [int]$Exit, [int]$StdoutBytes = 0, [int]$StderrBytes = 0) {
    [ordered]@{ id=$Id; expectedExitCode=$Exit; actualExitCode=$Exit; exitMatched=$true; rootProcessId=1; rootTerminated=$true; descendantProcessIds=@(); orphanProcessIds=@(); warningNoteCount=0; stdout=New-DummyStream $StdoutBytes; stderr=New-DummyStream $StderrBytes }
}
function New-DummyPassedCase([string]$Id, [string]$Kind) {
    $positive = $Kind -eq 'positive'
    $stdoutBytes = if ($Id -eq 'P1') { 17 } elseif ($Id -eq 'R424A') { 11 } else { 0 }
    $stdoutSha = if ($Id -eq 'P1') { '43BFC8AFF8A11C543CA36CC722EFFE95F3EA1AA021D1A35A13A0F3BC33EAF990' } elseif ($Id -eq 'R424A') { '99087F276C5EF3D2217EA023A7416891E472C10F3A73875BF9F2C3D82B9DC8B6' } else { $null }
    $compileExit = if ($positive) { 0 } else { 1 }
    $compileStderrBytes = if ($positive) { 0 } else { 1 }
    $compile = New-DummyProcess "$Id-compile" $compileExit 0 $compileStderrBytes
    $audit = if ($positive) {
        $count = if ($Id -eq 'P1') { 1 } else { 2 }
        [ordered]@{ link=New-DummyProcess "$Id-audit-link" 0; execute=New-DummyProcess "$Id-audit-native" 0 ($stdoutBytes + 36); allocationCount=$count; releaseCount=$count; invalidReleaseCount=0; balanced=$true }
    } else { $null }
    $item = [ordered]@{
        id=$Id; kind=$Kind; status='passed'; source='scripts/probes/example.slg'; sourceSha256='A'*64; compile=$compile
        run=if($positive){New-DummyProcess "$Id-native" 0 $stdoutBytes}else{$null}
        llvmPath=if($positive){"artifacts/scratch/c424-static/$Id.ll"}else{$null}; llvmSha256=if($positive){'B'*64}else{$null}
        llvmAs=if($positive){New-DummyProcess "$Id-llvm-as" 0}else{$null}; v004=if($positive){New-DummyProcess "$Id-v004" 0 1}else{$null}; audit=$audit
        expectedStdoutSha256=$stdoutSha; expectedStdoutByteCount=if($positive){$stdoutBytes}else{$null}; outputExact=$true
        diagnosticCount=if($positive){0}else{1}; diagnosticExact=$true; llvmProduced=$positive; warningNoteCount=0
        dropStructure=if($Id-eq'P1'){[ordered]@{childType='%sollang.struct.1';parentType='%sollang.struct.2';childDropFunction='sollang_drop_1';parentDropFunction='sollang_drop_2';childDropCallsInParent=1;independentChildDropCalls=0;parentDropCalls=1}}else{$null}
        passed=$true; failureId=$null
    }
    if ($positive) { $item.run.stdout.sha256 = $stdoutSha }
    $item
}

function New-DummyPassedRecord {
    $manifest = @([ordered]@{ path='stdlib/std/example.slg'; sha256='A'*64 })
    $hashes = [ordered]@{}
    1..15 | ForEach-Object { $hashes["input$_"] = 'A' * 64 }
    $manifestEnd = @(($manifest | ConvertTo-Json -Depth 10) | ConvertFrom-Json)
    $hashesEnd = (($hashes | ConvertTo-Json -Depth 10) | ConvertFrom-Json -AsHashtable)
    [ordered]@{
        schemaVersion=1; mode='execute'; defectId='C2026-09-13-424'; status='passed'; completed=6; total=6; caseIds=$caseIds
        compilerPath='artifacts/scratch/compiler/Sollang.Compiler.dll'; compilerSha256='A'*64; expectedCompilerSha256='A'*64; candidateShaMatched=$true
        sourceFreezeApproved=$true; currentSourceFreezeValidated=$true
        stdlibSourceCountStart=1; stdlibSourceCountEnd=1; stdlibManifestStart=$manifest; stdlibManifestEnd=$manifestEnd
        stdlibManifestSha256Start='B'*64; stdlibManifestSha256End='B'*64; stdlibManifestCountMatched=$true; stdlibManifestExact=$true
        inputHashesStart=$hashes; inputHashesEnd=$hashesEnd; inputHashesEqual=$true; inputDrift=@(); processAuditIds=$expectedProcessIds
        rootProcessIds=@(1); descendantProcessIds=@(); orphanProcessIds=@()
        cases=@(New-DummyPassedCase 'P1' 'positive'; New-DummyPassedCase 'R424A' 'positive'; New-DummyPassedCase 'N1' 'negative'; New-DummyPassedCase 'N2' 'negative'; New-DummyPassedCase 'R424N1' 'negative'; New-DummyPassedCase 'R424N2' 'negative')
        failureIds=@()
    }
}

function Assert-RecordInvariants([System.Collections.IDictionary]$Record) {
    if ($Record.compilerSha256 -cne $Record.expectedCompilerSha256 -or -not $Record.candidateShaMatched) { throw 'C424 record compiler SHA invariant failed' }
    if (($Record.caseIds -join "`n") -cne ($caseIds -join "`n") -or (@($Record.cases.id) -join "`n") -cne ($caseIds -join "`n")) { throw 'C424 record case identity invariant failed' }
    $hashesEqual = ($Record.inputHashesStart | ConvertTo-Json -Compress) -ceq ($Record.inputHashesEnd | ConvertTo-Json -Compress)
    if ($Record.inputHashesEqual -ne $hashesEqual) { throw 'C424 record input start/end equality invariant failed' }
    $manifestsEqual = ($Record.stdlibManifestStart | ConvertTo-Json -Compress) -ceq ($Record.stdlibManifestEnd | ConvertTo-Json -Compress)
    if ($Record.stdlibManifestExact -ne ($Record.stdlibManifestCountMatched -and $manifestsEqual -and $Record.stdlibManifestSha256Start -ceq $Record.stdlibManifestSha256End)) { throw 'C424 record stdlib start/end equality invariant failed' }
    if ($Record.status -eq 'passed') {
        if (($Record.processAuditIds -join "`n") -cne ($expectedProcessIds -join "`n")) { throw 'C424 record process audit identity invariant failed' }
        foreach ($item in $Record.cases | Where-Object kind -eq 'positive') {
            if ($item.run.stdout.sha256 -cne $item.expectedStdoutSha256 -or $item.run.stdout.byteCount -ne $item.expectedStdoutByteCount) { throw "C424 $($item.id) raw stdout identity invariant failed" }
        }
    }
}

function Test-SchemaControls([string]$ContractPath, [string]$ContractSchemaPath, [string]$ResultSchemaPath) {
    $contractText = [IO.File]::ReadAllText($ContractPath)
    if (-not ($contractText | Test-Json -SchemaFile $ContractSchemaPath -ErrorAction Stop)) { throw 'C424 contract schema rejected authority' }
    $passed = New-DummyPassedRecord
    $passedJson = $passed | ConvertTo-Json -Depth 100
    Assert-RecordInvariants $passed
    if (-not ($passedJson | Test-Json -SchemaFile $ResultSchemaPath -ErrorAction Stop)) { throw 'C424 result schema rejected canonical passed control' }
    $validated = New-DummyPassedRecord
    $validated.mode='validate-inputs';$validated.status='validated';$validated.completed=0;$validated.sourceFreezeApproved=$false;$validated.currentSourceFreezeValidated=$false
    $validated.processAuditIds=@();$validated.rootProcessIds=@();$validated.descendantProcessIds=@();$validated.orphanProcessIds=@()
    foreach($item in $validated.cases){$item.status='not-run';$item.compile=$null;$item.run=$null;$item.llvmPath=$null;$item.llvmSha256=$null;$item.llvmAs=$null;$item.v004=$null;$item.audit=$null;$item.outputExact=$false;$item.diagnosticCount=0;$item.diagnosticExact=$false;$item.llvmProduced=$false;$item.dropStructure=$null;$item.passed=$false}
    Assert-RecordInvariants $validated
    if (-not (($validated | ConvertTo-Json -Depth 100) | Test-Json -SchemaFile $ResultSchemaPath -ErrorAction Stop)) { throw 'C424 result schema rejected canonical validate-inputs control' }
    $failed = New-DummyPassedRecord
    $failed.status='failed'; $failed.completed=5; $failed.currentSourceFreezeValidated=$false; $failed.failureIds=@('C424_STATIC_FAILURE'); $failed.cases[5].status='failed'; $failed.cases[5].passed=$false; $failed.cases[5].failureId='C424_STATIC_FAILURE'
    if (-not (($failed | ConvertTo-Json -Depth 100) | Test-Json -SchemaFile $ResultSchemaPath -ErrorAction Stop)) { throw 'C424 result schema rejected canonical failed control' }
    $forgeries = @()
    $x=New-DummyPassedRecord;$x.candidateShaMatched=$false;$forgeries+=$x
    $x=New-DummyPassedRecord;$x.inputHashesEqual=$false;$forgeries+=$x
    $x=New-DummyPassedRecord;$x.inputDrift=@('compiler');$forgeries+=$x
    $x=New-DummyPassedRecord;$x.stdlibManifestExact=$false;$forgeries+=$x
    $x=New-DummyPassedRecord;$x.currentSourceFreezeValidated=$false;$forgeries+=$x
    $x=New-DummyPassedRecord;$x.orphanProcessIds=@(9);$forgeries+=$x
    $x=New-DummyPassedRecord;$x.processAuditIds=$x.processAuditIds[0..14];$forgeries+=$x
    $x=New-DummyPassedRecord;$x.caseIds=@('P1','R424A','N1','N2','R424N1','R424N1');$forgeries+=$x
    $x=New-DummyPassedRecord;$x.cases[0].audit.allocationCount=2;$forgeries+=$x
    $x=New-DummyPassedRecord;$x.cases[0].dropStructure.independentChildDropCalls=1;$forgeries+=$x
    $x=New-DummyPassedRecord;$x.cases[2].diagnosticCount=0;$forgeries+=$x
    $x=New-DummyPassedRecord;$x.cases[2].llvmProduced=$true;$forgeries+=$x
    $x=New-DummyPassedRecord;$x.cases[0].compile.warningNoteCount=1;$forgeries+=$x
    $x=New-DummyPassedRecord;$x.cases[0].run.stderr.byteCount=1;$forgeries+=$x
    $x=New-DummyPassedRecord;$x.status='failed';$x.completed=5;$x.currentSourceFreezeValidated=$false;$x.failureIds=@();$forgeries+=$x
    $x=New-DummyPassedRecord;$x.extra='forbidden';$forgeries+=$x
    $x=New-DummyPassedRecord;$x.inputHashesEnd.input1='B'*64;$forgeries+=$x
    $x=New-DummyPassedRecord;$x.cases[0].run.stdout.sha256='C'*64;$forgeries+=$x
    for ($i=0; $i -lt $forgeries.Count; $i++) {
        $accepted = $false
        try {
            Assert-RecordInvariants $forgeries[$i]
            $accepted = (($forgeries[$i] | ConvertTo-Json -Depth 100) | Test-Json -SchemaFile $ResultSchemaPath -ErrorAction SilentlyContinue)
        } catch { $accepted = $false }
        if ($accepted) {
            throw "C424 result schema accepted forged control $($i + 1)"
        }
    }
    Write-Host "[C424 same-SHA static] PASS contract=1/1 schema-positive=3/3 schema-negative=$($forgeries.Count)/$($forgeries.Count)"
}

$contractPath = Join-Path $root 'scripts/contracts/c424-same-sha-promotion.json'
$contractSchemaPath = Join-Path $root 'scripts/contracts/c424-same-sha-promotion.schema.json'
$resultSchemaPath = Join-Path $root 'scripts/contracts/c424-same-sha-promotion-result.schema.json'
Test-SchemaControls $contractPath $contractSchemaPath $resultSchemaPath
if ($ValidateSchemaControlsOnly) { exit 0 }

if ([string]::IsNullOrWhiteSpace($Compiler) -or [string]::IsNullOrWhiteSpace($ExpectedCompilerSha256)) { throw 'C424 requires explicit -Compiler and -ExpectedCompilerSha256' }
if ($ValidateInputsOnly -and $SourceFreezeApproved) { throw '-ValidateInputsOnly cannot assert -SourceFreezeApproved' }
if (-not $ValidateInputsOnly -and -not $SourceFreezeApproved) { throw 'C424 execution requires explicit -SourceFreezeApproved after current-source freeze' }
$compilerPath = [IO.Path]::GetFullPath((Join-Path $root $Compiler))
if ([IO.Path]::IsPathRooted($Compiler)) { $compilerPath = [IO.Path]::GetFullPath($Compiler) }
if (-not (Is-RepositoryPath $compilerPath)) { throw 'C424 compiler must be a repository-contained immutable candidate' }
if (-not (Test-Path -LiteralPath $compilerPath -PathType Leaf)) { throw "C424 compiler missing: $compilerPath" }
$expectedSha = $ExpectedCompilerSha256.ToUpperInvariant()
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory = Join-Path $root ('artifacts/scratch/c424-same-sha-' + [guid]::NewGuid().ToString('N')) }
$output = [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory))
if ([IO.Path]::IsPathRooted($OutputDirectory)) { $output = [IO.Path]::GetFullPath($OutputDirectory) }
if (-not (Is-RepositoryPath $output)) { throw 'C424 output directory must be repository-contained' }
[IO.Directory]::CreateDirectory($output) | Out-Null

$contract = ([IO.File]::ReadAllText($contractPath) | ConvertFrom-Json)
if ($contract.total -ne 6 -or (@($contract.cases.id) -join "`n") -cne ($caseIds -join "`n")) { throw 'C424 authority must contain the exact ordered six cases' }
$closurePath = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$auditShimPath = Join-Path $root 'tests/native-interop/owned_array_audit.c'
$llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
$llvmAsPath = Join-Path $llvmRoot 'bin/llvm-as.exe'
$clangPath = Join-Path $llvmRoot 'bin/clang.exe'
$paths = [ordered]@{ compiler=$compilerPath; verifier=$PSCommandPath; contract=$contractPath; contractSchema=$contractSchemaPath; resultSchema=$resultSchemaPath; closure=$closurePath; auditShim=$auditShimPath; llvmAs=$llvmAsPath; clang=$clangPath }
foreach ($case in $contract.cases) { $paths["source:$($case.id)"] = Join-Path $root ([string]$case.source) }
foreach ($entry in $paths.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $entry.Value -PathType Leaf) -or (Get-Item -LiteralPath $entry.Value).Length -eq 0) { throw "C424 authority input missing or empty: $($entry.Value)" }
}
$manifestStart = Snapshot-Stdlib
$inputStart = Snapshot-Inputs $paths
if ($inputStart.compiler -cne $expectedSha) { throw "C424 compiler hash mismatch: expected=$expectedSha actual=$($inputStart.compiler)" }
$items = @($contract.cases | ForEach-Object { New-EmptyCase $_ $paths["source:$($_.id)"] })
$record = [ordered]@{
    schemaVersion=1; mode=if($ValidateInputsOnly){'validate-inputs'}else{'execute'}; defectId='C2026-09-13-424'; status=if($ValidateInputsOnly){'validated'}else{'failed'}
    completed=0; total=6; caseIds=$caseIds; compilerPath=Relative $compilerPath; compilerSha256=$inputStart.compiler; expectedCompilerSha256=$expectedSha; candidateShaMatched=$true
    sourceFreezeApproved=[bool]$SourceFreezeApproved; currentSourceFreezeValidated=$false
    stdlibSourceCountStart=$manifestStart.entries.Count; stdlibSourceCountEnd=$manifestStart.entries.Count; stdlibManifestStart=$manifestStart.entries; stdlibManifestEnd=$manifestStart.entries
    stdlibManifestSha256Start=$manifestStart.sha256; stdlibManifestSha256End=$manifestStart.sha256; stdlibManifestCountMatched=$true; stdlibManifestExact=$true
    inputHashesStart=$inputStart; inputHashesEnd=$inputStart; inputHashesEqual=$true; inputDrift=@(); processAuditIds=@(); rootProcessIds=@(); descendantProcessIds=@(); orphanProcessIds=@()
    cases=$items; failureIds=@()
}

try {
    if (-not $ValidateInputsOnly) {
        for ($index=0; $index -lt $contract.cases.Count; $index++) {
            $authority = $contract.cases[$index]; $item = $record.cases[$index]
            $caseDir = Join-Path $output ([string]$authority.id); [IO.Directory]::CreateDirectory($caseDir) | Out-Null
            $exe = Join-Path $caseDir 'case.exe'; $ll = Join-Path $caseDir 'case.ll'
            $compile = Run-Tracked "$($authority.id)-compile" 'dotnet' @($compilerPath, 'build', $paths["source:$($authority.id)"], '-o', $exe, '--target', 'windows-x64', '--llvm', $llvmRoot, '-O1', '--keep-temps') ([int]$authority.expectedExitCode) (Join-Path $caseDir 'compile')
            $item.compile = $compile; $item.warningNoteCount = $compile.warningNoteCount; $item.llvmProduced = Test-Path -LiteralPath $ll -PathType Leaf
            if ($authority.kind -eq 'negative') {
                $stderrText = $utf8.GetString([IO.File]::ReadAllBytes((Join-Path $root $compile.stderr.path)))
                $normalized = $stderrText.Replace("`r`n", "`n")
                $lines = @($normalized.Split("`n") | Where-Object { $_.Length -gt 0 })
                $item.diagnosticCount = $lines.Count
                $item.diagnosticExact = $lines.Count -eq 1 -and $lines[0] -match '^sollang: semantic error(?:\[E\d+\])? at \d+:\d+: ' -and $lines[0].EndsWith([string]$authority.expectedDiagnosticPayload, [StringComparison]::Ordinal)
                $item.outputExact = $compile.stdout.byteCount -eq 0
                if (-not $compile.exitMatched -or -not $compile.rootTerminated -or $compile.orphanProcessIds.Count -ne 0 -or $compile.warningNoteCount -ne 0 -or -not $item.outputExact -or -not $item.diagnosticExact -or $item.llvmProduced) { throw "C424 $($authority.id) negative contract mismatch" }
            } else {
                if (-not $compile.exitMatched -or -not $compile.rootTerminated -or $compile.orphanProcessIds.Count -ne 0 -or $compile.stderr.byteCount -ne 0 -or $compile.warningNoteCount -ne 0 -or -not $item.llvmProduced) { throw "C424 $($authority.id) compile contract mismatch" }
                $llvmText = [IO.File]::ReadAllText($ll)
                if ($authority.id -eq 'P1') { $item.dropStructure = Inspect-P1-DropStructure $llvmText }
                $item.llvmPath = Relative $ll; $item.llvmSha256 = Hash $ll
                $item.run = Run-Tracked "$($authority.id)-native" $exe @() 0 (Join-Path $caseDir 'native') $caseDir
                $actualBytes = [IO.File]::ReadAllBytes((Join-Path $root $item.run.stdout.path)); $expectedBytes = $utf8.GetBytes([string]$authority.expectedStdout)
                $item.outputExact = [Convert]::ToBase64String($actualBytes) -ceq [Convert]::ToBase64String($expectedBytes)
                $item.diagnosticExact = $true
                $item.llvmAs = Run-Tracked "$($authority.id)-llvm-as" $llvmAsPath @($ll, '-o', (Join-Path $caseDir 'case.bc')) 0 (Join-Path $caseDir 'llvm-as')
                $item.v004 = Run-Tracked "$($authority.id)-v004" 'pwsh' @('-NoProfile', '-File', $closurePath, '-LlvmPath', $ll) 0 (Join-Path $caseDir 'v004')
                if (-not $item.run.exitMatched -or $item.run.stderr.byteCount -ne 0 -or -not $item.outputExact -or $item.llvmAs.stdout.byteCount -ne 0 -or $item.llvmAs.stderr.byteCount -ne 0 -or -not $item.llvmAs.exitMatched -or $item.v004.stderr.byteCount -ne 0 -or -not $item.v004.exitMatched) { throw "C424 $($authority.id) native/LLVM contract mismatch" }
                $auditLl = Join-Path $caseDir 'case.audit.ll'
                $auditText = $llvmText.Replace('call ptr @sollang_alloc(', 'call ptr @audit_malloc(').Replace('call void @sollang_free(', 'call void @audit_free(').Replace('@sollang_start()', '@slg_program_main()')
                $auditText += "`ndeclare ptr @audit_malloc(i64)`ndeclare void @audit_free(ptr)`n"
                [IO.File]::WriteAllText($auditLl, $auditText, $utf8)
                $auditExe = Join-Path $caseDir 'case.audit.exe'
                $auditLink = Run-Tracked "$($authority.id)-audit-link" $clangPath @('-Wno-override-module', "-DEXPECTED_ALLOCATIONS=$($authority.expectedAllocations)", $auditLl, $auditShimPath, '-O1', '-o', $auditExe) 0 (Join-Path $caseDir 'audit-link')
                $auditRun = Run-Tracked "$($authority.id)-audit-native" $auditExe @() 0 (Join-Path $caseDir 'audit-native') $caseDir
                $auditStdout = $utf8.GetString([IO.File]::ReadAllBytes((Join-Path $root $auditRun.stdout.path))).Replace("`r`n", "`n")
                $match = [regex]::Match($auditStdout, '(?m)^allocations=(?<a>\d+),releases=(?<r>\d+)$')
                $a = if ($match.Success) { [int]$match.Groups['a'].Value } else { -1 }; $r = if ($match.Success) { [int]$match.Groups['r'].Value } else { -1 }
                $invalid = [regex]::Matches($utf8.GetString([IO.File]::ReadAllBytes((Join-Path $root $auditRun.stderr.path))), 'invalid (?:release|realloc):').Count
                $item.audit = [ordered]@{ link=$auditLink; execute=$auditRun; allocationCount=$a; releaseCount=$r; invalidReleaseCount=$invalid; balanced=($a-eq[int]$authority.expectedAllocations-and$r-eq$a-and$invalid-eq0) }
                $expectedAudit = [string]$authority.expectedStdout + "allocations=$($authority.expectedAllocations),releases=$($authority.expectedAllocations)`n"
                if (-not $auditLink.exitMatched -or $auditLink.stdout.byteCount -ne 0 -or $auditLink.stderr.byteCount -ne 0 -or -not $auditRun.exitMatched -or $auditRun.stderr.byteCount -ne 0 -or $auditStdout -cne $expectedAudit -or -not $item.audit.balanced) { throw "C424 $($authority.id) allocation audit mismatch" }
            }
            $item.status='passed'; $item.passed=$true; $record.completed++
        }
    }
} catch {
    $failureId = if ($record.completed -lt 6) { "C424_$($caseIds[$record.completed])_FAILED" } else { 'C424_HARNESS_FAILED' }
    if ($record.failureIds -notcontains $failureId) { $record.failureIds += $failureId }
    if ($record.completed -lt 6) { $record.cases[$record.completed].status='failed'; $record.cases[$record.completed].failureId=$failureId }
    Write-Error $_ -ErrorAction Continue
} finally {
    $manifestEnd = Snapshot-Stdlib; $inputEnd = Snapshot-Inputs $paths
    $record.stdlibSourceCountEnd=$manifestEnd.entries.Count; $record.stdlibManifestEnd=$manifestEnd.entries; $record.stdlibManifestSha256End=$manifestEnd.sha256
    $record.stdlibManifestCountMatched=$record.stdlibSourceCountStart-eq$record.stdlibSourceCountEnd-and$record.stdlibManifestStart.Count-eq$record.stdlibSourceCountStart-and$record.stdlibManifestEnd.Count-eq$record.stdlibSourceCountEnd
    $record.stdlibManifestExact=$record.stdlibManifestCountMatched-and$record.stdlibManifestSha256Start-ceq$record.stdlibManifestSha256End-and(($record.stdlibManifestStart|ConvertTo-Json -Compress)-ceq($record.stdlibManifestEnd|ConvertTo-Json -Compress))
    $record.inputHashesEnd=$inputEnd; $record.inputDrift=@(Find-Drift $inputStart $inputEnd); $record.inputHashesEqual=$record.inputDrift.Count-eq0
    $record.processAuditIds=@($processAuditIds); $record.rootProcessIds=@($allRootProcessIds|Sort-Object); $record.descendantProcessIds=@($allDescendantProcessIds|Sort-Object); $record.orphanProcessIds=@($allOrphanProcessIds|Sort-Object)
    if(-not$record.inputHashesEqual-and$record.failureIds-notcontains'C424_INPUT_DRIFT'){$record.failureIds+='C424_INPUT_DRIFT'}
    if(-not$record.stdlibManifestExact-and$record.failureIds-notcontains'C424_STDLIB_DRIFT'){$record.failureIds+='C424_STDLIB_DRIFT'}
    if($record.orphanProcessIds.Count-and$record.failureIds-notcontains'C424_ORPHAN_PROCESS'){$record.failureIds+='C424_ORPHAN_PROCESS'}
    if(-not$ValidateInputsOnly-and(@($record.processAuditIds)-join"`n")-cne($expectedProcessIds-join"`n")-and$record.failureIds-notcontains'C424_PROCESS_TOPOLOGY'){$record.failureIds+='C424_PROCESS_TOPOLOGY'}
    $fullPass=-not$ValidateInputsOnly-and$record.completed-eq6-and$record.failureIds.Count-eq0-and$record.inputHashesEqual-and$record.stdlibManifestExact-and$record.orphanProcessIds.Count-eq0
    if($fullPass){$record.status='passed';$record.currentSourceFreezeValidated=[bool]$SourceFreezeApproved}elseif(-not$ValidateInputsOnly){$record.status='failed'}
    $resultPath=Join-Path $output 'result.json';$json=($record|ConvertTo-Json -Depth 100)+"`n";[IO.File]::WriteAllText($resultPath,$json,$utf8)
    Assert-RecordInvariants $record
    if(-not($json|Test-Json -SchemaFile $resultSchemaPath -ErrorAction Stop)){throw "C424 result schema rejected result: $resultPath"}
    Write-Host "[C424 same-SHA] $($record.status) $($record.completed)/6 compiler=$($record.compilerSha256) result=$resultPath"
}
if($record.status-eq'failed'){exit 1}
