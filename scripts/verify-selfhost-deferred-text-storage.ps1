[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$CandidateCompiler = 'artifacts/incremental-selfhost/selfhost-stage1-host-o0.exe',
    [switch]$SeedDeltaOnly,
    [string]$PriorGuardResult = '',
    [switch]$RequireCandidateGate
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
if (-not [IO.Path]::IsPathRooted($CandidateCompiler)) { $CandidateCompiler = Join-Path $root $CandidateCompiler }
$compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$output = Join-Path $root ('artifacts/scratch/selfhost-deferred-text-storage-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($output)
$resultPath = Join-Path $output 'result.json'
$record = [ordered]@{schemaVersion=1;status='running';scope='current-SLG-production-guard-over-actual-candidate-IR';cases=@();baseline=@();stage2Stage3Executed=$false}
function Save-Result { [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 8) + "`n")) }
function Read-Declaration([string]$Path, [string]$Name) {
    $source = Get-Content -LiteralPath $Path -Raw
    $matches = [regex]::Matches($source, '(?ms)^' + [regex]::Escape($Name) + ' [^\r\n]*\{.*?^\}')
    if ($matches.Count -ne 1) { throw "Expected one production declaration $Name in $Path" }
    return $matches[0].Value
}
try {
    $ownershipPath = Join-Path $root 'selfhost/semantic/ownership_check.slg'
    $typedPath = Join-Path $root 'selfhost/ir/typed.slg'
    $helperNames = @('deferredTextStorageConsumes','preservesDeferredText','analyzeDeferredTextStorage','deferredTextStringSeeds')
    $helpers = @($helperNames | ForEach-Object { Read-Declaration $ownershipPath $_ })
    $nodeType = Read-Declaration $typedPath 'public struct TypedIrNode'
    $managedVerifier = Join-Path $root 'scripts/verify-deferred-text-storage.ps1'
    $parseErrors = $null; $parseTokens = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($managedVerifier, [ref]$parseTokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) { throw 'Managed C400 fixture inventory did not parse' }
    $assignment = @($ast.FindAll({param($n) $n -is [Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$names'}, $true))[0]
    $names = @($assignment.Right.FindAll({param($n) $n -is [Management.Automation.Language.StringConstantExpressionAst]}, $true) | ForEach-Object Value)
    if ($names.Count -ne 16 -or @($names | Sort-Object -Unique).Count -ne 16) { throw 'C400 negative inventory must contain sixteen distinct sources' }
    $cases = @($names | ForEach-Object { @{id=$_;source="examples/regression/diagnostics/$_.slg";reject=$true} })
    $cases += @{id='control-result';source='scripts/probes/deferred-text-storage-controls.slg';reject=$true}
    $cases += @{id='1725';source='examples/regression/1725-materialized-text-storage-boundaries.slg';reject=$false}
    $cases += @{id='581';source='examples/regression/581-materialized-text-arena.slg';reject=$false}
    $cases += @{id='immediate-and-raw';source='scripts/probes/deferred-text-storage-immediate.slg';reject=$false}
    if ($SeedDeltaOnly) { $cases = @() }
    $edgesPath = Join-Path $root 'scripts/probes/deferred-text-storage-edges.slg'
    $edgeExpected = @('edge-binding=true,false','edge-index=true,true,false','edge-field=true,false',
        'edge-push=false,true','edge-put=false,true,true','edge-user-call=false,false',
        'edge-region=false,true,true','edge-control=false,true','edge-materialize=false,false',
        'seed-modules=true,false,true,false,false,false','seed-offset-order=true,false,true,false,false,false')
    $sources = @($cases | ForEach-Object { Join-Path $root $_.source })
    $inputs = @($PSCommandPath,$compiler,$CandidateCompiler,$ownershipPath,$typedPath,$managedVerifier,
        (Join-Path $root 'selfhost/llvm/emitter/diagnostics.slg'), $edgesPath, (Join-Path $root 'scripts/contracts/fixtures/deferred-text-seeds.cs')) + $sources
    if ($RequireCandidateGate) {
        $inputs += @($names | ForEach-Object { Join-Path $root "examples/regression/diagnostics/$_.slg" })
        $inputs += Join-Path $root 'examples/regression/1725-materialized-text-storage-boundaries.slg'
        $inputs += Join-Path $root 'scripts/verify-native-exact-fixture.ps1'
    }
    $hashes = @{}
    foreach ($path in $inputs) { $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
    $record.inputHashes=$hashes
    $record.candidateCompilerSha256=$hashes[$CandidateCompiler]
    $record.managedCompilerSha256=$hashes[$compiler]
    $record.seedDeltaOnly = [bool]$SeedDeltaOnly
    $record.helperDeclarationSha256 = @{}
    for ($i=0;$i -lt $helperNames.Count;$i++) {
        $record.helperDeclarationSha256[$helperNames[$i]] = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($helpers[$i].Replace("`r`n", "`n"))))
    }
    if ($PriorGuardResult) {
        $priorPath = [IO.Path]::GetFullPath($PriorGuardResult)
        $prior = Get-Content -LiteralPath $priorPath -Raw | ConvertFrom-Json
        if ($prior.status -ne 'passed' -or $prior.scope -ne $record.scope) { throw 'Prior guard evidence is not a successful matching scope' }
        $priorSource = Join-Path (Split-Path -Parent $priorPath) 'guard.slg'
        foreach ($name in $helperNames[0..2]) {
            $declaration = (Read-Declaration $priorSource $name).Replace("`r`n", "`n")
            $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($declaration)))
            if ($hash -cne $record.helperDeclarationSha256[$name]) { throw "Prior guard declaration changed: $name" }
        }
        $record.priorGuardEvidence = @{result=$priorPath;resultSha256=(Get-FileHash $priorPath -Algorithm SHA256).Hash;preservedSourceSha256=(Get-FileHash $priorSource -Algorithm SHA256).Hash;reusedCases=$prior.cases.Count;unchangedDeclarations=3}
    }
    $literals = @(); $rowsByCase = @{}; $stringIds = @{}
    $fieldNames = @('index','kind','parent','sourceModule','astNode','symbol','targetModule','typeId','typeKind','typeOrigin','typeModule','typeSymbol','typeFlags','payloadToken','opcode','operand0','operand1','nextOperand','flags')
    foreach ($case in $cases) {
        $path = Join-Path $root $case.source
        $astOutput = (& $CandidateCompiler ast-nodes $path 2>&1) -join "`n"
        if ($LASTEXITCODE -ne 0) { throw "Candidate AST failed: $($case.id)" }
        [IO.File]::WriteAllText((Join-Path $output "$($case.id).ast.log"), $astOutput + "`n")
        $sourceBytes = [IO.File]::ReadAllBytes($path)
        foreach ($match in [regex]::Matches($astOutput, '(?m)^ast source 0 node (\d+) kind 13 parent -?\d+ start (\d+) length (\d+) tokens \d+/\d+ payload (\d+) ')) {
            $id = "$($case.id)/$($match.Groups[1].Value)"
            $lexeme = [Text.Encoding]::UTF8.GetString($sourceBytes, [int]$match.Groups[2].Value, [int]$match.Groups[3].Value)
            $literals += @{id=$id;lexeme=$lexeme}
            $stringIds[$id]=$true
        }
        $irOutput = (& $CandidateCompiler typed-ir-nodes $path 2>&1) -join "`n"
        if ($LASTEXITCODE -ne 0) { throw "Candidate IR failed: $($case.id)" }
        [IO.File]::WriteAllText((Join-Path $output "$($case.id).ir.log"), $irOutput + "`n")
        $rows = @($irOutput -split '\r?\n' | ForEach-Object {
            if ($_ -notmatch '^node \d+ kind ') { throw "Unexpected IR output: $_" }
            $numbers=@([regex]::Matches($_,'-?\d+') | ForEach-Object { [int]$_.Value })
            if ($numbers.Count -ne $fieldNames.Count) { throw 'Unexpected IR field count' }
            $row=[ordered]@{}
            for($i=0;$i -lt $fieldNames.Count;$i++){ $row[$fieldNames[$i]]=$numbers[$i] }
            [pscustomobject]$row
        })
        for($i=0;$i -lt $rows.Count;$i++){ if($rows[$i].index -ne $i){throw 'Noncontiguous candidate IR'} }
        $rowsByCase[$case.id]=$rows
        if ($case.reject) {
            $validation = (& $CandidateCompiler validate $path 2>&1) -join "`n"
            $exit = $LASTEXITCODE
            [IO.File]::WriteAllText((Join-Path $output "$($case.id).baseline.log"),$validation+"`n")
            $record.baseline += @{id=$case.id;exitCode=$exit;output=$validation}
        }
    }
    $literalPath=Join-Path $output 'literals.json'
    [IO.File]::WriteAllText($literalPath, (ConvertTo-Json -InputObject $literals -Depth 3))
    $seedProject=Join-Path $output 'Seeds.csproj'
    $seedSource=Join-Path $root 'scripts/contracts/fixtures/deferred-text-seeds.cs'
    [IO.File]::WriteAllText($seedProject, "<Project Sdk=`"Microsoft.NET.Sdk`"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net11.0</TargetFramework><ImplicitUsings>enable</ImplicitUsings><Nullable>enable</Nullable><EnableDefaultCompileItems>false</EnableDefaultCompileItems><TreatWarningsAsErrors>true</TreatWarningsAsErrors></PropertyGroup><ItemGroup><Compile Include=`"$seedSource`" /></ItemGroup></Project>")
    $seeds=@{}
    if (-not $SeedDeltaOnly) {
        $seedOutput=(& dotnet run --project $seedProject -c Release -- $compiler $literalPath 2>&1) -join "`n"
        [IO.File]::WriteAllText((Join-Path $output 'reference-seeds.log'),$seedOutput+"`n")
        if($LASTEXITCODE -ne 0){throw "Reference literal parser failed: $seedOutput"}
        $seeds=$seedOutput | ConvertFrom-Json -AsHashtable
    }
    $program=@('namespace sollang.compiler.semantic.ownership_check','import sollang.compiler.ir.typed as typedIr')+$helpers
    $expected=@()
    $ordinal=0
    foreach($case in $cases){
        $rows=$rowsByCase[$case.id]
        $program += "probe$ordinal`: -> Unit uses Console {`n    [typedIr.TypedIrNode; ~] => nodes!"
        foreach($row in $rows){
            $fields=$fieldNames | Select-Object -Skip 1 | ForEach-Object { "        $_`: $($row.$_)" }
            $program += "    nodes! -> push(typedIr.TypedIrNode {`n$($fields -join "`n")`n    })"
        }
        $flags=@($rows | ForEach-Object { if($_.kind -eq 2 -and $seeds["$($case.id)/$($_.astNode)"]){'true'}else{'false'} })
        $program += "    [$($flags -join ', '); ~] => deferred`n    nodes! -> analyzeDeferredTextStorage(deferred) -> len => failures`n    `"$($case.id)=`$failures`" -> println`n}"
        $ordinal++
    }
    $program += 'public run: -> Unit uses Console {'
    for($i=0;$i -lt $cases.Count;$i++){ $program += "    probe$i()" }
    $program += '    runEdges()'
    $program += '}'
    $helperPath=Join-Path $output 'guard.slg'
    $typesPath=Join-Path $output 'types.slg'
    $entryPath=Join-Path $output 'entry.slg'
    [IO.File]::WriteAllText($helperPath, ($program -join "`n")+"`n")
    [IO.File]::WriteAllText($typesPath, "namespace sollang.compiler.ir.typed`n$nodeType`n")
    [IO.File]::WriteAllText($entryPath, "import sollang.compiler.semantic.ownership_check as probe`nmain { probe.run() }`n")
    $llvm=Join-Path $root '.tools/llvm-22.1.8'
    $exe=Join-Path $output 'guard.exe'
    $actual=(& dotnet $compiler run $entryPath $helperPath $typesPath $edgesPath --llvm $llvm -o $exe --keep-temps 2>&1) -join "`n"
    [IO.File]::WriteAllText((Join-Path $output 'guard.run.log'),$actual+"`n")
    if($LASTEXITCODE -ne 0){throw "Production guard run failed: $actual"}
    $lines=@($actual -split '\r?\n')
    if($lines.Count -ne $cases.Count+$edgeExpected.Count){throw "Unexpected production guard output: $actual"}
    for($i=0;$i -lt $cases.Count;$i++){
        $case=$cases[$i]
        if($lines[$i] -notmatch ('^'+[regex]::Escape($case.id)+'=(\d+)$')){throw 'Guard output identity mismatch'}
        $count=[int]$Matches[1]
        $pass=if($case.reject){$count -gt 0}else{$count -eq 0}
        if($case.id -eq 'control-result'){ $pass=$count -eq 3 }
        $record.cases += @{id=$case.id;expectedReject=$case.reject;diagnostics=$count;passed=$pass}
    }
    for($i=0;$i -lt $edgeExpected.Count;$i++){
        $record.cases += @{id=$edgeExpected[$i].Split('=')[0];passed=($lines[$cases.Count+$i] -ceq $edgeExpected[$i]);actual=$lines[$cases.Count+$i];expected=$edgeExpected[$i]}
    }
    if(@($record.cases | Where-Object {-not $_.passed}).Count -gt 0){throw 'Production guard acceptance mismatch'}
    & (Join-Path $llvm 'bin/llvm-as.exe') (Join-Path $output 'guard.ll') -o (Join-Path $output 'guard.bc')
    if($LASTEXITCODE -ne 0){throw 'Production guard LLVM did not assemble'}
    & (Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1') -LlvmPath (Join-Path $output 'guard.ll')
    $record.artifactHashes=@{}
    foreach($path in @($helperPath,$typesPath,$entryPath,$exe,(Join-Path $output 'guard.ll'),(Join-Path $output 'guard.run.log'))){$record.artifactHashes[$path]=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash}
    foreach($path in $hashes.Keys){if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $hashes[$path]){throw "Input drift: $path"}}
    $record.completed=$record.cases.Count; $record.total=$record.cases.Count
    $record.lexicalSeeds='actual candidate AST spans decoded by existing managed StringLiteralParser; selfhost interpolation adapter requires final integration'
    $record.integration='new selfhost compiler, E35 checked output, all-target native execution and Stage2/3 pending'
    if ($RequireCandidateGate) {
        # Run this optional post-rebuild gate under the established supervisor
        # when its complete command may exceed one minute. No compiler is built.
        $record.candidateGate=@{scope='checked-windows-sixteen-negatives-and-native1725';completed=0;total=17;cases=@();status='running'}
        $gateFailures=@()
        foreach($name in $names){
            $path=Join-Path $root "examples/regression/diagnostics/$name.slg"
            $failure=(& $CandidateCompiler windows $path 2>&1) -join "`n"
            $failureExit=$LASTEXITCODE
            $log=Join-Path $output "$name.checked.log"
            [IO.File]::WriteAllText($log,$failure+"`n")
            $emittedLlvm=$failure -match '(?m)^(target (triple|datalayout)|define |declare |@|%[^;\r\n]*= type)'
            $diagnostic=$failure -match '(?m)^; sollang semantic error\[E35\]: deferred interpolation cannot be stored; materialize it into an explicit Arena owner '
            $passed=$failureExit -ne 0 -and $diagnostic -and -not $emittedLlvm -and $failure -notmatch '(?im)warning|\bN00[12]\b'
            $record.candidateGate.cases+=@{id=$name;exitCode=$failureExit;passed=$passed;generatedLlvm=$emittedLlvm;log=$log;sourceSha256=(Get-FileHash $path -Algorithm SHA256).Hash}
            if($passed){$record.candidateGate.completed++}else{$gateFailures+=$name}
            Save-Result
        }
        if($gateFailures.Count -gt 0){$record.candidateGate.status='failed';throw "Selfhost storage gate did not reject before LLVM: $($gateFailures -join ', ')"}
        $nativeOutput=Join-Path $output '1725-native'
        & (Join-Path $root 'scripts/verify-native-exact-fixture.ps1') -Compiler $CandidateCompiler -Label 'C400-storage' `
            -Fixture '1725-materialized-text-storage-boundaries' -Platform windows -LlvmRoot $llvm `
            -StdlibRoot (Join-Path $root 'stdlib') -RepositoryRoot $root -OutputDirectory $nativeOutput -Jobs 1
        if(-not $?){throw 'Selfhost1725 native exact gate failed'}
        $record.candidateGate.cases+=@{id='1725';passed=$true;output=$nativeOutput}
        $record.candidateGate.completed++
        $record.candidateGate.status='passed'
        $record.integration='checked selfhost Windows16 negatives plus native1725 passed; remaining targets and accumulated Stage2/3 are separate'
    }
    foreach($path in $hashes.Keys){if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $hashes[$path]){throw "Final input drift: $path"}}
    $record.status='passed'
} catch { $record.status='failed';$record.failure=$_.Exception.Message;throw } finally { Save-Result }
Write-Output "Selfhost deferred storage production guard PASS $($record.completed)/$($record.total): $resultPath"
