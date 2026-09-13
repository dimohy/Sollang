[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCompilerSha256
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$verifier = Join-Path $PSScriptRoot 'verify-c437-current-source.ps1'
$schema = Join-Path $PSScriptRoot 'contracts/c437-current-source-result.schema.json'
$tokens = $null
$parseErrors = $null
[Management.Automation.Language.Parser]::ParseFile($verifier, [ref]$tokens, [ref]$parseErrors) | Out-Null
if ($parseErrors.Count -ne 0) { throw "C437 current-source verifier parse failed: $($parseErrors.Message -join '; ')" }

$text = [IO.File]::ReadAllText($verifier)
foreach ($required in @(
    'SourceFreezeApproved', 'Snapshot-Stdlib', 'stdlibManifestSha256Start', 'stdlibManifestSha256End',
    'inputHashesStart', 'inputHashesEnd', 'inputDrift', 'currentSourceFreezeValidated',
    'Run-Tracked', 'Observe-Descendants', 'Save-Stream', 'Test-StreamEvidence', 'orphanProcessIds',
    'c437_allocation_audit.c', 'invalidReleaseCount', 'stdlibManifestExact',
    'verify-llvm-direct-call-closure.ps1', 'llvm-as.exe'
)) {
    if (-not $text.Contains($required, [StringComparison]::Ordinal)) { throw "C437 verifier omits static authority '$required'" }
}

$temp = Join-Path ([IO.Path]::GetTempPath()) ('sollang-c437-contract-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($temp) | Out-Null
try {
    $guardOutput = & pwsh -NoProfile -File $verifier -Compiler $Compiler -ExpectedCompilerSha256 $ExpectedCompilerSha256 -OutputDirectory $temp 2>&1 | Out-String
    $guardExit = $LASTEXITCODE
    if ($guardExit -eq 0 -or -not $guardOutput.Contains('requires explicit -SourceFreezeApproved', [StringComparison]::Ordinal)) {
        throw "C437 source-freeze guard failed: exit=$guardExit output=$guardOutput"
    }
    & pwsh -NoProfile -File $verifier -Compiler $Compiler -ExpectedCompilerSha256 $ExpectedCompilerSha256 -OutputDirectory $temp -ValidateOnly
    if ($LASTEXITCODE -ne 0) { throw "C437 validate-only failed with exit $LASTEXITCODE" }
    $resultPath = Join-Path $temp 'result.json'
    $json = [IO.File]::ReadAllText($resultPath)
    if (-not ($json | Test-Json -SchemaFile $schema -ErrorAction Stop)) { throw 'C437 validate-only result was rejected' }
    $record = $json | ConvertFrom-Json
    if ($record.status -cne 'validate-only' -or $record.completed -ne 0 -or $record.total -ne 14 -or
        $record.currentSourceFreezeValidated -or $record.sourceFreezeApproved -or $record.cases.Count -ne 14) {
        throw 'C437 validate-only result semantics drifted'
    }
    if(@($record.cases|Where-Object kind -eq 'positive').Count-ne9-or@($record.cases|Where-Object kind -eq 'negative').Count-ne5){throw 'C437 validate-only topology is not 9 positive / 5 negative'}

    $zeroSha = '0' * 64
    $emptyStream = [ordered]@{ path='evidence.bin'; sha256=$zeroSha; byteCount=0; text='' }
    $emptyProcess = [ordered]@{ exitCode=0; rootProcessId=1; descendantProcessIds=@(); orphanProcessIds=@(); stdout=$emptyStream; stderr=$emptyStream }
    $passed = $json | ConvertFrom-Json
    $passed.status='passed';$passed.completed=14;$passed.sourceFreezeApproved=$true;$passed.currentSourceFreezeValidated=$true
    for($index=0;$index-lt14;$index++){
        $case=$passed.cases[$index];$case.status='passed';$case.passed=$true;$case.warningCount=0
        $compile=($emptyProcess|ConvertTo-Json -Depth 10|ConvertFrom-Json)
        if($case.kind-ceq'positive'){
            $case.compile=$compile;$case.run=($emptyProcess|ConvertTo-Json -Depth 10|ConvertFrom-Json);$case.llvmPath='case.ll';$case.llvmSha256=$zeroSha
            $case.llvmAs=($emptyProcess|ConvertTo-Json -Depth 10|ConvertFrom-Json);$case.v004=($emptyProcess|ConvertTo-Json -Depth 10|ConvertFrom-Json)
            $case.audit=[ordered]@{link=($emptyProcess|ConvertTo-Json -Depth 10|ConvertFrom-Json);execute=($emptyProcess|ConvertTo-Json -Depth 10|ConvertFrom-Json);allocationCount=0;releaseCount=0;invalidReleaseCount=0;balanced=$true}
        }else{
            $compile.exitCode=1;$compile.stderr.byteCount=1;$compile.stderr.text='x';$case.compile=$compile
        }
    }
    $passedJson=$passed|ConvertTo-Json -Depth 100
    if(-not($passedJson|Test-Json -SchemaFile $schema -ErrorAction Stop)){throw 'C437 synthetic passed topology was rejected'}
    $controls = @(
        { param($copy) $copy.total = 13 },
        { param($copy) $copy.cases[0].id = 'W02_PENDING' },
        { param($copy) $copy.status = 'failed'; $copy.failureIds=@('X'); $copy.currentSourceFreezeValidated = $true },
        { param($copy) $copy.orphanProcessIds = @(1234) },
        { param($copy) $copy.stdlibManifestCountMatched = $false },
        { param($copy) $copy.cases[0].audit.invalidReleaseCount = 1 },
        { param($copy) $copy.cases[9].run = $copy.cases[0].run }
    )
    $rejected = 0
    foreach ($control in $controls) {
        $copy = $passedJson | ConvertFrom-Json
        & $control $copy
        $forged = $copy | ConvertTo-Json -Depth 100
        if (-not ($forged | Test-Json -SchemaFile $schema -ErrorAction SilentlyContinue)) { $rejected++ }
    }
    if ($rejected -ne $controls.Count) { throw "C437 result schema rejected $rejected/$($controls.Count) forgeries" }
    Write-Host "[C437 current-source contract] PASS parser 1/1; execution guard 1/1; validate-only 1/1; passed topology 1/1 (9 positive allocation audits/5 negative); schema forgeries $rejected/$($controls.Count); stdlib=$($record.stdlibSourceCountStart) sha256=$($record.stdlibManifestSha256Start)."
} finally {
    if (Test-Path -LiteralPath $temp -PathType Container) {
        $resolvedTemp = (Resolve-Path -LiteralPath $temp).Path
        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
        if (-not $resolvedTemp.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) { throw "refusing to remove non-temp path: $resolvedTemp" }
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
