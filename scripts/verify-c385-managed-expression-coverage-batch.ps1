[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][string]$ExpectedCompilerSha256,
    [Parameter(Mandatory)][string]$ArtifactDirectory,
    [Parameter(Mandatory)][string]$ResultDirectory,
    [string]$PlanPath = 'artifacts/scratch/c385-expression-coverage-candidate34-20260924-01-plan.json',
    [switch]$ValidateInputsOnly
)

# Remove this focused runner after the shared native-exact verifier recognizes
# the managed compiler's published <output>.ll sidecar and equivalent current
# input evidence has been produced through that shared path.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'verification-process.ps1')

function RepoFile([string]$Relative) {
    $path = [IO.Path]::GetFullPath((Join-Path $repo $Relative))
    if (-not $path.StartsWith($repo + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C385_MANAGED_INPUT_MISSING: $Relative" }
    return $path
}
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Run([string]$File, [string[]]$Arguments, [string]$Prefix) {
    $stdout = "$Prefix.stdout"
    $stderr = "$Prefix.stderr"
    $process = Start-Process -FilePath $File -ArgumentList $Arguments -WorkingDirectory $repo `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -WindowStyle Hidden
    try {
        Wait-VerificationProcess -Process $process -Description "C385 managed $Prefix" -TimeoutMilliseconds 3600000
        $process.WaitForExit()
        return $process.ExitCode
    } finally { $process.Dispose() }
}

$planPath = RepoFile $PlanPath
$plan = [IO.File]::ReadAllText($planPath) | ConvertFrom-Json
$planSchema = RepoFile 'scripts/contracts/c385-expression-coverage-plan.schema.json'
if (-not (([IO.File]::ReadAllText($planPath)) | Test-Json -SchemaFile $planSchema -ErrorAction Stop)) { throw 'C385_MANAGED_PLAN_SCHEMA' }
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$ExpectedCompilerSha256 = $ExpectedCompilerSha256.ToUpperInvariant()
if ((Hash $compilerPath) -cne $ExpectedCompilerSha256 -or $plan.cases.Count -ne 14) { throw 'C385_MANAGED_COMPILER_OR_PLAN_DRIFT' }
$fixtures = @($plan.cases.fixture | Select-Object -Unique)
if ($fixtures.Count -ne 12) { throw 'C385_MANAGED_FIXTURE_DENOMINATOR' }
$llvm = [IO.Path]::GetFullPath((Join-Path $repo '.tools/llvm-22.1.8'))
$as = Join-Path $llvm 'bin/llvm-as.exe'
$closure = RepoFile 'scripts/verify-llvm-direct-call-closure.ps1'
$inputs = [ordered]@{ compiler=$compilerPath; plan=$planPath; schema=$planSchema; verifier=$PSCommandPath; processHelper=(RepoFile 'scripts/verification-process.ps1'); closure=$closure; llvmAs=$as; clang=(Join-Path $llvm 'bin/clang.exe') }
foreach ($fixture in $fixtures) {
    $inputs["source:$fixture"] = RepoFile "examples/regression/$fixture.slg"
    $inputs["expected:$fixture"] = RepoFile "examples/regression/expected/$fixture.stdout.txt"
    if (Test-Path -LiteralPath (Join-Path $repo "examples/regression/expected/$fixture.args.txt")) { throw "C385_MANAGED_ARGS_UNSUPPORTED: $fixture" }
    if (Test-Path -LiteralPath (Join-Path $repo "examples/regression/expected/$fixture.sources.txt")) { throw "C385_MANAGED_SOURCES_UNSUPPORTED: $fixture" }
}
$stdlib = [IO.Path]::GetFullPath((Join-Path $repo 'stdlib'))
$index = 0
foreach ($path in @([IO.Directory]::GetFiles($stdlib, '*.slg', [IO.SearchOption]::AllDirectories) | Sort-Object)) {
    $inputs[('stdlib:{0:D4}' -f $index)] = $path
    $index++
}
$start = [ordered]@{}
foreach ($entry in $inputs.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $entry.Value -PathType Leaf)) { throw "C385_MANAGED_TOOL_MISSING: $($entry.Key)" }
    $start[$entry.Key] = Hash $entry.Value
}
if ($ValidateInputsOnly) { Write-Host "[C385 managed coverage preflight] PASS $($fixtures.Count)/12 fixture inputs; execution unverified"; return }

$artifacts = [IO.Path]::GetFullPath($ArtifactDirectory)
$resultRoot = [IO.Path]::GetFullPath($ResultDirectory)
$scratch = [IO.Path]::GetFullPath((Join-Path $repo 'artifacts/scratch'))
if (-not $resultRoot.StartsWith($scratch + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
    (Test-Path -LiteralPath $artifacts) -or (Test-Path -LiteralPath $resultRoot)) { throw 'C385_MANAGED_OUTPUT_MUST_BE_FRESH' }
[IO.Directory]::CreateDirectory($artifacts) | Out-Null
[IO.Directory]::CreateDirectory($resultRoot) | Out-Null
$label = Split-Path -Leaf $resultRoot
$resultPath = Join-Path $resultRoot "$label-batch-results.json"
$results = [Collections.Generic.List[object]]::new()
function Write-Report([string]$State) {
    $pass = @($results | Where-Object Success).Count
    $record = [ordered]@{
        schemaVersion=1; label=$label; platform='windows'; state=$State
        compilerSha256=$ExpectedCompilerSha256; commonInputFingerprint=$start.compiler
        completed=$results.Count; passed=$pass; failed=$results.Count-$pass
        missing=$fixtures.Count-$results.Count; total=$fixtures.Count
        inputHashesStart=$start; results=@($results | Select-Object Fixture,Success,Error)
    }
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 6) + "`n"), [Text.UTF8Encoding]::new($false))
}
Write-Report 'running'
foreach ($fixture in $fixtures) {
    $failure = $null
    try {
        $prefix = Join-Path $artifacts $fixture
        $exe = "$prefix.exe"
        $ll = "$exe.ll"
        $source = $inputs["source:$fixture"]
        $expected = $inputs["expected:$fixture"]
        if ((Run 'dotnet' @($compilerPath,'build',$source,'-o',$exe,'--target','windows-x64','--llvm',$llvm,'-O1','--keep-temps') "$prefix.compile") -ne 0) { throw 'COMPILE_EXIT' }
        $diagnostics = [IO.File]::ReadAllText("$prefix.compile.stdout") + [IO.File]::ReadAllText("$prefix.compile.stderr")
        if (([regex]::Matches($diagnostics, '(?im)^(?:warning|note)\b')).Count -ne 0 -or
            (Get-Item "$prefix.compile.stderr").Length -ne 0 -or
            -not (Test-Path -LiteralPath $exe -PathType Leaf) -or
            -not (Test-Path -LiteralPath $ll -PathType Leaf)) { throw 'COMPILE_ARTIFACT_OR_DIAGNOSTIC' }
        if ((Run $as @($ll,'-o',"$prefix.bc") "$prefix.llvm-as") -ne 0) { throw 'LLVM_AS_EXIT' }
        if ((Run 'pwsh' @('-NoProfile','-File',$closure,'-LlvmPath',$ll) "$prefix.v004") -ne 0) { throw 'V004_EXIT' }
        if ((Run $exe @() "$prefix.native") -ne 0) { throw 'NATIVE_EXIT' }
        if ((Get-Item "$prefix.native.stderr").Length -ne 0 -or
            -not [Linq.Enumerable]::SequenceEqual[byte]([IO.File]::ReadAllBytes("$prefix.native.stdout"), [IO.File]::ReadAllBytes($expected))) { throw 'NATIVE_EXACT_MISMATCH' }
    } catch { $failure = $_.Exception.Message }
    $results.Add([pscustomobject]@{ Fixture=$fixture; Success=($null -eq $failure); Error=if($failure){$failure}else{''} })
    Write-Report 'running'
    Write-Host "[C385 managed coverage $($results.Count)/$($fixtures.Count)] $(if($failure){'FAIL'}else{'PASS'}) $fixture $failure"
}
$end = [ordered]@{}
foreach ($entry in $inputs.GetEnumerator()) { $end[$entry.Key] = Hash $entry.Value }
$stable = -not [bool]@(Compare-Object @($start.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) @($end.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }))
if (-not $stable) { $results.Add([pscustomobject]@{ Fixture='INPUT_DRIFT'; Success=$false; Error='INPUT_DRIFT' }) }
Write-Report $(if ($stable -and @($results | Where-Object { -not $_.Success }).Count -eq 0) { 'passed' } else { 'failed' })
if (-not $stable -or @($results | Where-Object { -not $_.Success }).Count -gt 0) { throw "C385_MANAGED_COVERAGE_FAILED: $resultPath" }
Write-Host "[C385 managed coverage] PASS $($fixtures.Count)/$($fixtures.Count); result=$resultPath"
