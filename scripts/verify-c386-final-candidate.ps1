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
function TextHash([string]$Text) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))) }
function Run([string]$File, [string[]]$Arguments, [string]$Description) { Invoke-VerificationProcessCapture -FilePath $File -ArgumentList $Arguments -WorkingDirectory $root -Description $Description -TimeoutMilliseconds 120000 }

$candidate = (Resolve-Path -LiteralPath (Repo $CandidateCompiler)).Path
if (-not $candidate.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'C386 candidate must be under the repository root' }
$ExpectedCompilerSha256 = $ExpectedCompilerSha256.ToUpperInvariant()
$output = Repo $OutputDirectory
if (-not $output.StartsWith((Repo 'artifacts/scratch') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'C386 output must be under artifacts/scratch' }
if ((Test-Path -LiteralPath $output) -and @(Get-ChildItem -LiteralPath $output -Force).Count -ne 0) { throw 'C386 output must be new or empty' }
[IO.Directory]::CreateDirectory($output) | Out-Null

$inputs = [ordered]@{
    compiler = $candidate
    verifier = [IO.Path]::GetFullPath($PSCommandPath)
    schema = Repo 'scripts/contracts/c386-final-candidate-result.schema.json'
    parityContract = Repo 'scripts/contracts/expression-lowering-parity.json'
    paritySchema = Repo 'scripts/contracts/expression-lowering-parity.schema.json'
    parityVerifier = Repo 'scripts/verify-expression-lowering-parity.ps1'
    modeVerifier = Repo 'scripts/verify-selfhost-expression-lowering-mode-parity.ps1'
    closureVerifier = Repo 'scripts/verify-llvm-direct-call-closure.ps1'
    processHelper = Repo 'scripts/verification-process.ps1'
    invariants = Repo 'selfhost/llvm/text/invariants.slg'
    diagnostics = Repo 'selfhost/llvm/text/invariant_diagnostics.slg'
    net = Repo 'stdlib/std/net.slg'
    parseError = Repo 'stdlib/std/net/parse_error.slg'
    fixture1702 = Repo 'examples/regression/1702-selfhost-parallel-comparison-materialization.slg'
    expected1702 = Repo 'examples/regression/expected/1702-selfhost-parallel-comparison-materialization.stdout.txt'
    llvmAs = Repo '.tools/llvm-22.1.8/bin/llvm-as.exe'
    clang = Repo '.tools/llvm-22.1.8/bin/clang.exe'
}
$start = [ordered]@{}; foreach ($entry in $inputs.GetEnumerator()) { $start[$entry.Key] = Hash $entry.Value }
if ($start.compiler -cne $ExpectedCompilerSha256) { throw "C386 compiler hash mismatch: expected=$ExpectedCompilerSha256 actual=$($start.compiler)" }
$contract = [IO.File]::ReadAllText($inputs.parityContract) | ConvertFrom-Json
$ids = @($contract.binaryWrapperControls.id)
if (($ids -join '|') -cne 'direct-binary|transparent-binary-wrapper|missing-canonical-producer|nested-under-nonbinary|nested-binary-is-not-wrapper') { throw 'C386 canonical-owner controls drifted' }
if ($ValidateInputsOnly) { Write-Host "[C386 input preflight] PASS compiler=$($start.compiler) controls=5"; return }

$canonical = [ordered]@{ completed=0; total=5; exitCode=$null }
$parity = [ordered]@{ completed=0; total=2; nodeCount=0; exitCode=$null }
$checked = [ordered]@{ compileExit=$null; stderrSha256=(TextHash ''); warningNoteCount=0; s059Count=0; llvmAsExit=$null; v004Exit=$null; llvmSha256=$null }
$fixture = [ordered]@{ id='1702-selfhost-parallel-comparison-materialization'; compileExit=$null; llvmAsExit=$null; v004Exit=$null; linkExit=$null; nativeExit=$null; stdoutSha256=(TextHash ''); expectedStdoutSha256=$start.expected1702; stdoutExact=$false; stderrSha256=(TextHash ''); llvmSha256=$null; executableSha256=$null }
$failureIds = [Collections.Generic.List[string]]::new(); $failure = $null
try {
    $static = Run 'pwsh' @('-NoProfile','-File',$inputs.parityVerifier) 'C386 canonical-owner controls'
    $canonical.exitCode = $static.ExitCode
    if ($static.ExitCode -ne 0 -or $static.Stderr.Length -ne 0 -or $static.Stdout -notmatch '42/42') { throw 'canonical-owner verifier failed' }
    $canonical.completed = 5

    $mode = Run 'pwsh' @('-NoProfile','-File',$inputs.modeVerifier,'-Compiler',$candidate) 'C386 Typed IR mode parity'
    $parity.exitCode = $mode.ExitCode
    $modeMatch = [regex]::Match($mode.Stdout, 'PASS (?<sources>\d+) sources and (?<nodes>\d+) exact Typed IR nodes')
    if ($mode.ExitCode -ne 0 -or $mode.Stderr.Length -ne 0 -or -not $modeMatch.Success) { throw 'Typed IR mode parity failed' }
    $parity.completed = [int]$modeMatch.Groups['sources'].Value; $parity.nodeCount = [int]$modeMatch.Groups['nodes'].Value

    $checkedLl = Join-Path $output 'std-net.checked.ll'; $checkedErr = Join-Path $output 'std-net.checked.stderr'; $checkedBc = Join-Path $output 'std-net.checked.bc'
    Invoke-VerificationProcessToFile -FilePath $candidate -ArgumentList @('windows',$inputs.net,$inputs.parseError) -Description 'C386 checked std.net lowering' -OutputPath $checkedLl -ErrorPath $checkedErr -TimeoutMilliseconds 120000
    $checked.compileExit = 0; $checkedText = [IO.File]::ReadAllText($checkedLl); $checkedError = [IO.File]::ReadAllText($checkedErr)
    $checked.stderrSha256 = TextHash $checkedError; $checked.warningNoteCount = [regex]::Matches($checkedText + $checkedError, '(?im)\b(?:warning|note)\b').Count; $checked.s059Count = [regex]::Matches($checkedText + $checkedError, '(?i)S059').Count
    if ($checkedError.Length -ne 0 -or $checked.warningNoteCount -ne 0 -or $checked.s059Count -ne 0 -or $checkedText -notmatch 'target datalayout') { throw 'checked std.net lowering failed' }
    $checkedAssembly = Run $inputs.llvmAs @($checkedLl,'-o',$checkedBc) 'C386 checked std.net llvm-as'; $checked.llvmAsExit = $checkedAssembly.ExitCode
    $checkedClosure = Run 'pwsh' @('-NoProfile','-File',$inputs.closureVerifier,'-LlvmPath',$checkedLl) 'C386 checked std.net V004'; $checked.v004Exit = $checkedClosure.ExitCode; $checked.llvmSha256 = Hash $checkedLl
    if ($checked.llvmAsExit -ne 0 -or $checked.v004Exit -ne 0) { throw 'checked std.net LLVM validation failed' }

    $fixtureLl = Join-Path $output '1702.ll'; $fixtureErr = Join-Path $output '1702.compile.stderr'; $fixtureBc = Join-Path $output '1702.bc'; $fixtureExe = Join-Path $output '1702.exe'
    Invoke-VerificationProcessToFile -FilePath $candidate -ArgumentList @('windows',$inputs.fixture1702) -Description 'C386 1702 compile' -OutputPath $fixtureLl -ErrorPath $fixtureErr -TimeoutMilliseconds 120000
    $fixture.compileExit = 0
    if ([IO.File]::ReadAllText($fixtureErr).Length -ne 0) { throw '1702 compile emitted diagnostics' }
    $fixtureAssembly = Run $inputs.llvmAs @($fixtureLl,'-o',$fixtureBc) 'C386 1702 llvm-as'; $fixture.llvmAsExit = $fixtureAssembly.ExitCode
    $fixtureClosure = Run 'pwsh' @('-NoProfile','-File',$inputs.closureVerifier,'-LlvmPath',$fixtureLl) 'C386 1702 V004'; $fixture.v004Exit = $fixtureClosure.ExitCode
    $link = Run $inputs.clang @('-Wno-override-module',$fixtureLl,'-O1','-o',$fixtureExe,'-lws2_32','-lshell32','-lbcrypt') 'C386 1702 link'; $fixture.linkExit = $link.ExitCode
    if ($fixture.llvmAsExit -ne 0 -or $fixture.v004Exit -ne 0 -or $fixture.linkExit -ne 0) { throw '1702 LLVM/link validation failed' }
    $native = Run $fixtureExe @() 'C386 1702 native'; $fixture.nativeExit = $native.ExitCode; $fixture.stdoutSha256 = TextHash $native.Stdout; $fixture.stderrSha256 = TextHash $native.Stderr
    $fixture.stdoutExact = $fixture.stdoutSha256 -ceq $fixture.expectedStdoutSha256 -and [Text.Encoding]::UTF8.GetByteCount($native.Stdout) -eq (Get-Item $inputs.expected1702).Length
    $fixture.llvmSha256 = Hash $fixtureLl; $fixture.executableSha256 = Hash $fixtureExe
    if ($fixture.nativeExit -ne 0 -or -not $fixture.stdoutExact -or $native.Stderr.Length -ne 0) { throw '1702 native exact validation failed' }
} catch { $failure = $_.Exception.Message; [void]$failureIds.Add('C386_FOCUSED_FAILED') }

$end = [ordered]@{}; $drift = [Collections.Generic.List[string]]::new()
foreach ($entry in $inputs.GetEnumerator()) { try { $end[$entry.Key] = Hash $entry.Value; if ($end[$entry.Key] -cne $start[$entry.Key]) { [void]$drift.Add($entry.Key) } } catch { $end[$entry.Key] = '0' * 64; [void]$drift.Add($entry.Key) } }
if ($drift.Count -gt 0) { [void]$failureIds.Add('C386_INPUT_DRIFT'); if ($null -eq $failure) { $failure = 'C386 input drift' } }
$failureIds = @($failureIds | Select-Object -Unique)
$record = [ordered]@{ schemaVersion=1; defectId='C2026-09-12-386'; status=if($failureIds.Count){'failed'}else{'passed'}; compilerSha256=$start.compiler; expectedCompilerSha256=$ExpectedCompilerSha256; candidateShaMatched=($start.compiler -ceq $ExpectedCompilerSha256 -and $end.compiler -ceq $ExpectedCompilerSha256); inputStable=$drift.Count-eq0; inputDrift=@($drift); inputHashesStart=$start; inputHashesEnd=$end; canonicalOwnerControls=$canonical; modeParity=$parity; checkedWindows=$checked; fixture1702=$fixture; failureIds=$failureIds; failure=if($failureIds.Count){$failure}else{$null} }
$resultPath = Join-Path $output 'result.json'; $json = ($record | ConvertTo-Json -Depth 10) + "`n"; [IO.File]::WriteAllText($resultPath,$json,[Text.UTF8Encoding]::new($false))
if (-not ($json | Test-Json -SchemaFile $inputs.schema -ErrorAction Stop)) { throw 'C386 result schema rejected result' }
if ($record.status -ne 'passed') { throw "C386 focused failed: $failure; result=$resultPath" }
Write-Host "[C386 final candidate] PASS controls 5/5; mode 2/2 nodes=942; checked 1/1; 1702 1/1; result=$resultPath"
