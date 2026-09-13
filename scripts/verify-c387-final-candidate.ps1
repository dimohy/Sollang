[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CandidateCompiler,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCompilerSha256,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [switch]$ValidateInputsOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'verification-process.ps1')
function Repo([string]$Path) { if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $root $Path)) } }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function ByteHash([byte[]]$Bytes) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)) }
function TextHash([string]$Text) { ByteHash ([Text.Encoding]::UTF8.GetBytes($Text)) }
function Run([string]$File, [string[]]$Arguments, [string]$Description) { Invoke-VerificationProcessCapture -FilePath $File -ArgumentList $Arguments -WorkingDirectory $root -Description $Description -TimeoutMilliseconds 120000 }

$candidate = (Resolve-Path -LiteralPath (Repo $CandidateCompiler)).Path
if (-not $candidate.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'C387 candidate must be under the repository root' }
$ExpectedCompilerSha256 = $ExpectedCompilerSha256.ToUpperInvariant()
$output = Repo $OutputDirectory
if (-not $output.StartsWith((Repo 'artifacts/scratch') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'C387 output must be under artifacts/scratch' }
if ((Test-Path -LiteralPath $output) -and @(Get-ChildItem -LiteralPath $output -Force).Count -ne 0) { throw 'C387 output must be new or empty' }
[IO.Directory]::CreateDirectory($output) | Out-Null

$inputs = [ordered]@{
    compiler = $candidate
    verifier = [IO.Path]::GetFullPath($PSCommandPath)
    schema = Repo 'scripts/contracts/c387-final-candidate-result.schema.json'
    parityContract = Repo 'scripts/contracts/expression-lowering-parity.json'
    paritySchema = Repo 'scripts/contracts/expression-lowering-parity.schema.json'
    parityVerifier = Repo 'scripts/verify-expression-lowering-parity.ps1'
    modeVerifier = Repo 'scripts/verify-selfhost-expression-lowering-mode-parity.ps1'
    closureVerifier = Repo 'scripts/verify-llvm-direct-call-closure.ps1'
    processHelper = Repo 'scripts/verification-process.ps1'
    astAuthority = Repo 'selfhost/syntax/ast.slg'
    invariants = Repo 'selfhost/llvm/text/invariants.slg'
    diagnostics = Repo 'selfhost/llvm/text/invariant_diagnostics.slg'
    pathKind = Repo 'stdlib/sys/directory/kind.slg'
    path = Repo 'stdlib/sys/path.slg'
    pathRuntime = Repo 'stdlib/sys/runtime/path.slg'
    fixture1703 = Repo 'examples/regression/1703-selfhost-type-application-angle-ownership.slg'
    expected1703 = Repo 'examples/regression/expected/1703-selfhost-type-application-angle-ownership.stdout.txt'
    llvmAs = Repo '.tools/llvm-22.1.8/bin/llvm-as.exe'
    clang = Repo '.tools/llvm-22.1.8/bin/clang.exe'
}
$start = [ordered]@{}; foreach ($entry in $inputs.GetEnumerator()) { $start[$entry.Key] = Hash $entry.Value }
if ($start.compiler -cne $ExpectedCompilerSha256) { throw "C387 compiler hash mismatch: expected=$ExpectedCompilerSha256 actual=$($start.compiler)" }
$contract = [IO.File]::ReadAllText($inputs.parityContract) | ConvertFrom-Json
if ($contract.operatorTokenOwnership.typeSyntaxAngles -cne 'type-annotation-plus-balanced-application-clause' -or
    -not $contract.operatorTokenOwnership.callArgumentsExcluded -or
    $contract.operatorTokenOwnership.operatorlessEnvelope -cne 'omit' -or
    $contract.operatorTokenOwnership.nestedComparisonControl -cne 'Result<Bool, Text>.Ok(3 > 2)') { throw 'C387 operator-token ownership contract drifted' }
if ($ValidateInputsOnly) { Write-Host "[C387 input preflight] PASS compiler=$($start.compiler) inputs=$($start.Count)"; return }

$static = [ordered]@{ completed=0; total=4; exitCode=$null }
$ast = [ordered]@{ completed=0; total=3; exitCode=$null; kind19NodeCount=0; comparisonSpanCount=0; genericFalseOwnerCount=0; nestedComparisonOwnerCount=0; standaloneComparisonOwnerCount=0; stdoutSha256=(TextHash ''); stderrSha256=(TextHash '') }
$mode = [ordered]@{ completed=0; total=2; sourceCount=0; nodeCount=0; exitCode=$null }
$checked = [ordered]@{ compileExit=$null; stderrSha256=(TextHash ''); warningNoteCount=0; s059Count=0; llvmAsExit=$null; v004Exit=$null; llvmSha256=$null }
$fixture = [ordered]@{ id='1703-selfhost-type-application-angle-ownership'; compileExit=$null; llvmAsExit=$null; v004Exit=$null; linkExit=$null; nativeExit=$null; stdoutSha256=(TextHash ''); expectedStdoutSha256=$start.expected1703; stdoutExact=$false; stderrSha256=(TextHash ''); warningNoteCount=0; llvmSha256=$null; executableSha256=$null }
$failureIds = [Collections.Generic.List[string]]::new(); $failure = $null
$sourceSet = @(
    'stdlib/sys/directory/kind.slg',
    'stdlib/sys/path.slg',
    'stdlib/sys/runtime/path.slg',
    'examples/regression/1703-selfhost-type-application-angle-ownership.slg'
)
try {
    $staticRun = Run 'pwsh' @('-NoProfile','-File',$inputs.parityVerifier) 'C387 static operator ownership authority'
    $static.exitCode = $staticRun.ExitCode
    if ($staticRun.ExitCode -ne 0 -or $staticRun.Stderr.Length -ne 0 -or $staticRun.Stdout -notmatch '42/42') { throw 'C387 static authority failed' }
    $static.completed = 4

    $astRun = Run $candidate @('ast-nodes',$inputs.fixture1703) 'C387 AST operator controls'
    $ast.exitCode = $astRun.ExitCode; $ast.stdoutSha256 = TextHash $astRun.Stdout; $ast.stderrSha256 = TextHash $astRun.Stderr
    if ($astRun.ExitCode -ne 0 -or $astRun.Stderr.Length -ne 0) { throw 'C387 AST inventory failed' }
    $kind19 = @($astRun.Stdout -split "`n" | Where-Object { $_ -match ' kind 19 ' })
    $ast.kind19NodeCount = $kind19.Count
    $spans = @($kind19 | ForEach-Object { if ($_ -match ' start (?<start>\d+) length (?<length>\d+) ') { "$($Matches.start):$($Matches.length)" } } | Sort-Object -Unique)
    $ast.comparisonSpanCount = $spans.Count
    [byte[]]$fixtureBytes = [IO.File]::ReadAllBytes($inputs.fixture1703)
    $genericNeedle = [Text.Encoding]::UTF8.GetBytes('Result<Int, Text>.Err(message)')
    $genericStart = [Array]::IndexOf($fixtureBytes, $genericNeedle[0])
    while ($genericStart -ge 0) {
        $matches = $true; for ($i=0; $i -lt $genericNeedle.Length; $i++) { if ($fixtureBytes[$genericStart+$i] -ne $genericNeedle[$i]) { $matches=$false; break } }
        if ($matches) { break }
        $genericStart = [Array]::IndexOf($fixtureBytes, $genericNeedle[0], $genericStart + 1)
    }
    if ($genericStart -lt 0) { throw 'C387 generic constructor control is missing' }
    foreach ($line in $kind19) { if ($line -match ' start (?<start>\d+) length (?<length>\d+) ') { $s=[int]$Matches.start; $l=[int]$Matches.length; if ($s -lt $genericStart+$genericNeedle.Length -and $genericStart -lt $s+$l) { $ast.genericFalseOwnerCount++ } } }
    $comparisonSpans = @($spans | Where-Object { $parts=$_ -split ':'; [Text.Encoding]::UTF8.GetString($fixtureBytes,[int]$parts[0],[int]$parts[1]) -ceq '3 > 2' })
    if ($comparisonSpans.Count -ne 2) { throw 'C387 real comparison spans were not preserved exactly' }
    $ordered = @($comparisonSpans | Sort-Object { [int](($_ -split ':')[0]) })
    $ast.nestedComparisonOwnerCount = @($kind19 | Where-Object { $_ -match " start $([regex]::Escape(($ordered[0] -split ':')[0])) length 5 " }).Count
    $ast.standaloneComparisonOwnerCount = @($kind19 | Where-Object { $_ -match " start $([regex]::Escape(($ordered[1] -split ':')[0])) length 5 " }).Count
    if ($ast.kind19NodeCount -ne 4 -or $ast.comparisonSpanCount -ne 2 -or $ast.genericFalseOwnerCount -ne 0 -or $ast.nestedComparisonOwnerCount -ne 2 -or $ast.standaloneComparisonOwnerCount -ne 2) { throw 'C387 AST positive/negative ownership controls failed' }
    $ast.completed = 3

    $sequential = Run $candidate (@('typed-ir-nodes') + $sourceSet) 'C387 sequential Typed IR inventory'
    $parallel = Run $candidate (@('typed-ir-nodes-parallel') + $sourceSet) 'C387 production-parallel Typed IR inventory'
    $mode.exitCode = if ($sequential.ExitCode -ne 0) { $sequential.ExitCode } else { $parallel.ExitCode }
    $sequentialLines = @($sequential.Stdout.Replace("`r`n","`n").TrimEnd("`n") -split "`n")
    $parallelLines = @($parallel.Stdout.Replace("`r`n","`n").TrimEnd("`n") -split "`n")
    if ($mode.exitCode -ne 0 -or $sequential.Stderr.Length -ne 0 -or $parallel.Stderr.Length -ne 0 -or
        ($sequentialLines -join "`n") -cne ($parallelLines -join "`n")) { throw 'C387 Typed IR mode parity failed' }
    $mode.sourceCount=$sourceSet.Count; $mode.nodeCount=$sequentialLines.Count; $mode.completed=2

    $checkedLl=Join-Path $output 'std-path.checked.ll'; $checkedErr=Join-Path $output 'std-path.checked.stderr'; $checkedBc=Join-Path $output 'std-path.checked.bc'
    Invoke-VerificationProcessToFile -FilePath $candidate -ArgumentList @('windows',$inputs.pathKind,$inputs.path,$inputs.pathRuntime) -Description 'C387 checked std.path lowering' -OutputPath $checkedLl -ErrorPath $checkedErr -TimeoutMilliseconds 120000
    $checked.compileExit=0; $checkedText=[IO.File]::ReadAllText($checkedLl); $checkedError=[IO.File]::ReadAllText($checkedErr); $checked.stderrSha256=TextHash $checkedError
    $checked.warningNoteCount=[regex]::Matches($checkedText+$checkedError,'(?im)\b(?:warning|note)\b').Count; $checked.s059Count=[regex]::Matches($checkedText+$checkedError,'(?i)S059').Count
    if ($checkedError.Length-ne0 -or $checked.warningNoteCount-ne0 -or $checked.s059Count-ne0 -or $checkedText-notmatch 'target datalayout') { throw 'C387 checked std.path lowering failed' }
    $checkedAs=Run $inputs.llvmAs @($checkedLl,'-o',$checkedBc) 'C387 checked std.path llvm-as'; $checked.llvmAsExit=$checkedAs.ExitCode
    $checkedV004=Run 'pwsh' @('-NoProfile','-File',$inputs.closureVerifier,'-LlvmPath',$checkedLl) 'C387 checked std.path V004'; $checked.v004Exit=$checkedV004.ExitCode; $checked.llvmSha256=Hash $checkedLl
    if ($checked.llvmAsExit-ne0 -or $checked.v004Exit-ne0) { throw 'C387 checked std.path LLVM validation failed' }

    $ll=Join-Path $output '1703.ll'; $err=Join-Path $output '1703.compile.stderr'; $bc=Join-Path $output '1703.bc'; $exe=Join-Path $output '1703.exe'
    Invoke-VerificationProcessToFile -FilePath $candidate -ArgumentList @('windows',$inputs.fixture1703) -Description 'C387 1703 compile' -OutputPath $ll -ErrorPath $err -TimeoutMilliseconds 120000
    $fixture.compileExit=0; $compileError=[IO.File]::ReadAllText($err); $llvmText=[IO.File]::ReadAllText($ll); $fixture.warningNoteCount=[regex]::Matches($llvmText+$compileError,'(?im)\b(?:warning|note)\b').Count
    if ($compileError.Length-ne0 -or $fixture.warningNoteCount-ne0) { throw 'C387 1703 compile emitted diagnostics' }
    $asRun=Run $inputs.llvmAs @($ll,'-o',$bc) 'C387 1703 llvm-as'; $fixture.llvmAsExit=$asRun.ExitCode
    $v004=Run 'pwsh' @('-NoProfile','-File',$inputs.closureVerifier,'-LlvmPath',$ll) 'C387 1703 V004'; $fixture.v004Exit=$v004.ExitCode
    $link=Run $inputs.clang @('-Wno-override-module',$ll,'-O1','-o',$exe,'-lws2_32','-lshell32','-lbcrypt') 'C387 1703 link'; $fixture.linkExit=$link.ExitCode
    if ($fixture.llvmAsExit-ne0 -or $fixture.v004Exit-ne0 -or $fixture.linkExit-ne0) { throw 'C387 1703 LLVM/link validation failed' }
    $native=Run $exe @() 'C387 1703 native'; $fixture.nativeExit=$native.ExitCode; $fixture.stdoutSha256=TextHash $native.Stdout; $fixture.stderrSha256=TextHash $native.Stderr
    $fixture.stdoutExact=$fixture.stdoutSha256-ceq$fixture.expectedStdoutSha256 -and [Text.Encoding]::UTF8.GetByteCount($native.Stdout)-eq(Get-Item $inputs.expected1703).Length
    $fixture.llvmSha256=Hash $ll; $fixture.executableSha256=Hash $exe
    if ($fixture.nativeExit-ne0 -or -not $fixture.stdoutExact -or $native.Stderr.Length-ne0) { throw 'C387 1703 native exact validation failed' }
} catch { $failure=$_.Exception.Message; [void]$failureIds.Add('C387_FOCUSED_FAILED') }

$end=[ordered]@{}; $drift=[Collections.Generic.List[string]]::new()
foreach($entry in $inputs.GetEnumerator()){try{$end[$entry.Key]=Hash $entry.Value;if($end[$entry.Key]-cne$start[$entry.Key]){[void]$drift.Add($entry.Key)}}catch{$end[$entry.Key]='0'*64;[void]$drift.Add($entry.Key)}}
if($drift.Count-gt0){[void]$failureIds.Add('C387_INPUT_DRIFT');if($null-eq$failure){$failure='C387 input drift'}}
$failureIds=@($failureIds|Select-Object -Unique)
$record=[ordered]@{schemaVersion=1;defectId='C2026-09-12-387';status=if($failureIds.Count){'failed'}else{'passed'};compilerSha256=$start.compiler;expectedCompilerSha256=$ExpectedCompilerSha256;candidateShaMatched=($start.compiler-ceq$ExpectedCompilerSha256 -and $end.compiler-ceq$ExpectedCompilerSha256);inputStable=$drift.Count-eq0;inputDrift=@($drift);inputHashesStart=$start;inputHashesEnd=$end;staticAuthority=$static;astOperatorControls=$ast;modeParity=$mode;checkedWindows=$checked;fixture1703=$fixture;failureIds=$failureIds;failure=if($failureIds.Count){$failure}else{$null}}
$resultPath=Join-Path $output 'result.json';$json=($record|ConvertTo-Json -Depth 10)+"`n";[IO.File]::WriteAllText($resultPath,$json,[Text.UTF8Encoding]::new($false))
if(-not($json|Test-Json -SchemaFile $inputs.schema -ErrorAction Stop)){throw 'C387 result schema rejected result'}
if($record.status-ne'passed'){throw "C387 focused failed: $failure; result=$resultPath"}
Write-Host "[C387 final candidate] PASS static 4/4; AST 3/3; mode 2/2 nodes=2011; checked 1/1; 1703 1/1; result=$resultPath"
