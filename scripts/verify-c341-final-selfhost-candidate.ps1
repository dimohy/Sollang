[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CandidateCompiler,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCandidateSha256,
    [string]$GenerationRecord = '',
    [string]$SeedCompiler = 'artifacts/incremental-selfhost/selfhost-slg-seed.exe',
    [string]$OutputDirectory = '',
    [switch]$ValidateInputsOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'verification-process.ps1')
function RootPath([string]$Path) { if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $root $Path)) } }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Normalize([string]$Text) { $Text.Replace("`r`n", "`n").TrimEnd() }
function Run([string]$File, [string[]]$Arguments, [string]$Description) {
    Invoke-VerificationProcessCapture -FilePath $File -ArgumentList $Arguments -WorkingDirectory $root -Description $Description -TimeoutMilliseconds 120000
}

$candidate = (Resolve-Path -LiteralPath (RootPath $CandidateCompiler)).Path
$ExpectedCandidateSha256 = $ExpectedCandidateSha256.ToUpperInvariant()
$output = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { Join-Path $root ('artifacts/scratch/c341-final-selfhost-' + [guid]::NewGuid().ToString('N')) } else { RootPath $OutputDirectory }
[IO.Directory]::CreateDirectory($output) | Out-Null
$contractPath = RootPath 'scripts/contracts/c341-final-selfhost-candidate.json'
$schemaPath = RootPath 'scripts/contracts/c341-final-selfhost-candidate-result.schema.json'
$sharedContractPath = RootPath 'scripts/contracts/direct-owned-field-binding.json'
$sharedSchemaPath = RootPath 'scripts/contracts/direct-owned-field-binding.schema.json'
$selfhostVerifier = RootPath 'scripts/verify-selfhost-direct-owned-field-binding.ps1'
$selfhostResultSchema = RootPath 'scripts/contracts/selfhost-direct-owned-field-binding-result.schema.json'
$closureVerifier = RootPath 'scripts/verify-llvm-direct-call-closure.ps1'
$llvmRoot = RootPath '.tools/llvm-22.1.8'
$llvmAs = RootPath '.tools/llvm-22.1.8/bin/llvm-as.exe'
$clang = RootPath '.tools/llvm-22.1.8/bin/clang.exe'
$contract = [IO.File]::ReadAllText($contractPath) | ConvertFrom-Json
if ($contract.schemaVersion -ne 1 -or $contract.defectId -cne 'C2026-09-06-341' -or $contract.selfhostCaseCount -ne 20 -or @($contract.productionCases).Count -ne 3) { throw 'C341 final contract shape mismatch' }
$sharedText = [IO.File]::ReadAllText($sharedContractPath)
if (-not ($sharedText | Test-Json -SchemaFile $sharedSchemaPath -ErrorAction Stop) -or (Hash $sharedContractPath) -cne $contract.sharedContractSha256) { throw 'C341 authoritative 20-case contract mismatch' }
$shared = $sharedText | ConvertFrom-Json
if (@($shared.cases).Count -ne 20 -or @($shared.cases.id | Sort-Object -Unique).Count -ne 20) { throw 'C341 authoritative contract requires twenty unique cases' }

$inputs = [ordered]@{ compiler=$candidate; contract=$contractPath; schema=$schemaPath; sharedContract=$sharedContractPath; sharedSchema=$sharedSchemaPath; selfhostVerifier=$selfhostVerifier; selfhostResultSchema=$selfhostResultSchema; closureVerifier=$closureVerifier; llvmAs=$llvmAs; clang=$clang }
foreach ($case in $contract.productionCases) {
    $path = RootPath ([string]$case.source)
    if ((Hash $path) -cne [string]$case.sourceSha256) { throw "C341 production fixture hash mismatch: $($case.id)" }
    $inputs["source:$($case.id)"] = $path
}
$hashes = [ordered]@{}
foreach ($entry in $inputs.GetEnumerator()) { $hashes[$entry.Key] = Hash $entry.Value }
if ($hashes.compiler -cne $ExpectedCandidateSha256) { throw "C341 candidate hash mismatch: expected=$ExpectedCandidateSha256 actual=$($hashes.compiler)" }
if ($ValidateInputsOnly) {
    Write-Host "[C341 final selfhost input preflight] PASS contract=20 production=3 candidate=$($hashes.compiler); execution remains unverified"
    return
}
if ([string]::IsNullOrWhiteSpace($GenerationRecord)) { $GenerationRecord = [IO.Path]::ChangeExtension($candidate, '.generation.json') } else { $GenerationRecord = RootPath $GenerationRecord }
$SeedCompiler = RootPath $SeedCompiler

$selfhostBundle = [ordered]@{completed=0;total=20;result=$null}
$productionCases = @()
$failureIds = [Collections.Generic.List[string]]::new()
$failureMessage = $null
$phase = 'SELFHOST20'
try {
    $selfhostOutput = Join-Path $output 'selfhost20'
    & $selfhostVerifier -CandidateCompiler $candidate -GenerationRecord $GenerationRecord -SeedCompiler $SeedCompiler -OutputDirectory $selfhostOutput
    $selfhostResultPath = Join-Path $selfhostOutput 'result.json'
    $selfhostResultText = [IO.File]::ReadAllText($selfhostResultPath)
    if (-not ($selfhostResultText | Test-Json -SchemaFile $selfhostResultSchema -ErrorAction Stop)) { throw 'C341 child result schema failure' }
    $selfhostResult = $selfhostResultText | ConvertFrom-Json
    if ($selfhostResult.runStatus -cne 'passed' -or $selfhostResult.completionStatus -cne 'complete' -or $selfhostResult.completed -ne 20 -or $selfhostResult.total -ne 20 -or $selfhostResult.compilerSha256 -cne $ExpectedCandidateSha256) { throw 'C341 child did not pass exact 20/20 under candidate SHA' }
    foreach ($definition in $shared.cases) {
        $actual = $selfhostResult.cases | Where-Object id -CEQ $definition.id | Select-Object -First 1
        if ($null -eq $actual -or -not $actual.passed -or -not $actual.warningNoteFree) { throw "C341 child case failed: $($definition.id)" }
        if ($definition.kind -ceq 'positive' -and ($actual.compileExit -ne 0 -or -not $actual.targetLlvmProduced -or $actual.llvmAsExit -ne 0 -or $actual.closureExit -ne 0 -or $actual.nativeExit -ne 0)) { throw "C341 positive proof incomplete: $($definition.id)" }
        if ($definition.PSObject.Properties.Name -contains 'auditAllocations' -and $actual.auditExit -ne 0) { throw "C341 allocation proof incomplete: $($definition.id)" }
        if ($definition.kind -ceq 'negative' -and ($actual.compileExit -ne 1 -or $actual.targetLlvmProduced -or $actual.diagnosticCount -ne 1 -or -not $actual.diagnosticMatched)) { throw "C341 semantic negative proof incomplete: $($definition.id)" }
    }
    $selfhostBundle.completed=20; $selfhostBundle.result=$selfhostResultPath

    $phase = 'PRODUCTION'
    foreach ($definition in $contract.productionCases) {
        $item = [ordered]@{id=[string]$definition.id;kind=[string]$definition.kind;passed=$false;compileExit=-1;llvmProduced=$false;llvmAsExit=$null;closureExit=$null;nativeExit=$null;stdoutExact=$null;diagnosticCount=0;diagnosticMatched=$null;warningNoteFree=$false;failure=$null}
        try {
            $source = $inputs["source:$($definition.id)"]
            $compile = Run $candidate @('windows', $source) "$($definition.id) selfhost production compile"
            $item.compileExit = $compile.ExitCode
            $stdout = Normalize $compile.Stdout
            $item.warningNoteFree = ($compile.Stdout + $compile.Stderr) -notmatch '(?im)\b(?:warning|note)\b'
            $item.llvmProduced = $stdout -match '(?m)^target datalayout = ' -and $stdout -match '(?m)^define(?: [^{\r\n]+)? i32 @main\('
            if ($definition.kind -ceq 'negative') {
                $lines = @($stdout -split '\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                $item.diagnosticCount = [regex]::Matches($stdout, '(?im)^;\s*sollang error\[E\d+\]:').Count
                $item.diagnosticMatched = $lines.Count -gt 0 -and $stdout.Contains([string]$definition.diagnostic, [StringComparison]::Ordinal)
                if ($compile.ExitCode -ne 1 -or $item.llvmProduced -or $item.diagnosticCount -ne 1 -or -not $item.diagnosticMatched -or -not $item.warningNoteFree -or -not [string]::IsNullOrWhiteSpace($compile.Stderr)) { throw 'semantic-only negative mismatch' }
            } else {
                if ($compile.ExitCode -ne 0 -or -not $item.llvmProduced -or -not $item.warningNoteFree -or -not [string]::IsNullOrWhiteSpace($compile.Stderr)) { throw 'production positive compile mismatch' }
                $ll = Join-Path $output "$($definition.id).ll"; [IO.File]::WriteAllText($ll, $compile.Stdout + "`n", [Text.UTF8Encoding]::new($false))
                $assembled=Run $llvmAs @($ll,'-o',(Join-Path $output "$($definition.id).bc")) "$($definition.id) llvm-as";$item.llvmAsExit=$assembled.ExitCode
                $closure=Run 'pwsh' @('-NoProfile','-File',$closureVerifier,'-LlvmPath',$ll) "$($definition.id) V004";$item.closureExit=$closure.ExitCode
                $exe=Join-Path $output "$($definition.id).exe";$link=Run $clang @('-Wno-override-module',$ll,'-O1','-o',$exe,'-lws2_32','-lshell32','-lbcrypt') "$($definition.id) link";if($link.ExitCode-ne0){throw 'production link failed'}
                $native=Run $exe @() "$($definition.id) native";$item.nativeExit=$native.ExitCode;$item.stdoutExact=$native.ExitCode-eq0 -and [string]::IsNullOrWhiteSpace($native.Stderr) -and (Normalize $native.Stdout)-ceq [string]$definition.expectedText
                if($item.llvmAsExit-ne0 -or $item.closureExit-ne0 -or -not $item.stdoutExact){throw 'production exact/LLVM mismatch'}
            }
            $item.passed=$true
        } catch { $item.failure=$_.Exception.Message }
        $productionCases += [pscustomobject]$item
        if(-not $item.passed){throw "production case failed: $($item.id): $($item.failure)"}
    }
} catch { [void]$failureIds.Add("C341_$($phase)_FAILED");$failureMessage=$_.Exception.Message }

$drift=[Collections.Generic.List[string]]::new();foreach($entry in $inputs.GetEnumerator()){try{if((Hash $entry.Value)-cne$hashes[$entry.Key]){[void]$drift.Add($entry.Key)}}catch{[void]$drift.Add($entry.Key)}}
if($drift.Count){[void]$failureIds.Add('C341_INPUT_DRIFT');if([string]::IsNullOrWhiteSpace($failureMessage)){$failureMessage="C341 input drift: $($drift -join ', ')"}}
$endSha=try{Hash $candidate}catch{''};$shaMatched=$hashes.compiler-ceq$ExpectedCandidateSha256 -and $endSha-ceq$ExpectedCandidateSha256
if(-not $shaMatched){[void]$failureIds.Add('C341_CANDIDATE_SHA_DRIFT');if([string]::IsNullOrWhiteSpace($failureMessage)){$failureMessage='C341 candidate SHA changed'}}
$failureIds=@($failureIds|Select-Object -Unique);$completedProduction=@($productionCases|Where-Object passed).Count
$record=[ordered]@{schemaVersion=1;defectId='C2026-09-06-341';status=if($failureIds.Count){'failed'}else{'passed'};compilerSha256=$hashes.compiler;expectedCompilerSha256=$ExpectedCandidateSha256;candidateShaMatched=$shaMatched;inputStable=$drift.Count-eq0;inputDrift=@($drift);inputHashes=$hashes;selfhostContract=$selfhostBundle;productionDifferential=[ordered]@{completed=$completedProduction;total=3;cases=@($productionCases)};failureIds=$failureIds;failure=if($failureIds.Count){$failureMessage}else{$null}}
$resultPath=Join-Path $output 'result.json';$json=($record|ConvertTo-Json -Depth 10)+"`n";[IO.File]::WriteAllText($resultPath,$json,[Text.UTF8Encoding]::new($false));if(-not($json|Test-Json -SchemaFile $schemaPath -ErrorAction Stop)){throw "C341 final result schema failure: $resultPath"};if($record.status-ne'passed'){throw "C341 final failed: $($failureIds -join ', '); result=$resultPath"}
Write-Host "[C341 final selfhost] PASS selfhost 20/20 production 3/3 compiler=$($hashes.compiler) result=$resultPath"
