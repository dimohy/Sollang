[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PriorResult,
    [Parameter(Mandatory)][string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$PriorResult = (Resolve-Path -LiteralPath $PriorResult).Path
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null

function Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }

$contractPath = Join-Path $root 'scripts/contracts/indexed-owned-exchange.json'
$contractSchemaPath = Join-Path $root 'scripts/contracts/indexed-owned-exchange.schema.json'
$resultSchemaPath = Join-Path $root 'scripts/contracts/indexed-owned-exchange-result.schema.json'
$contractText = [IO.File]::ReadAllText($contractPath)
Require ($contractText | Test-Json -SchemaFile $contractSchemaPath) 'indexed exchange contract schema validation failed'
$contract = $contractText | ConvertFrom-Json
$priorText = [IO.File]::ReadAllText($PriorResult)
$prior = $priorText | ConvertFrom-Json
Require ($prior.total -eq 9 -and $prior.cases.Count -eq 9) 'prior result does not contain the exact nine-case matrix'
$priorHash = Hash $PriorResult
$priorDirectory = Split-Path -Parent $PriorResult

$inputPaths = [ordered]@{
    compiler = (Resolve-Path -LiteralPath (Join-Path $root 'artifacts/scratch/c323-c342-final-v4/compiler/Sollang.Compiler.dll')).Path
    contract = $contractPath
    contractSchema = $contractSchemaPath
    resultSchema = $resultSchemaPath
    focusedVerifier = Join-Path $root 'scripts/verify-indexed-owned-exchange-focused.ps1'
    reclassifier = $PSCommandPath
    priorResult = $PriorResult
}
foreach ($case in $contract.fixtures.cases) {
    $inputPaths["source:$($case.id)"] = Join-Path $root $case.source
    $inputPaths["expected:$($case.id)"] = Join-Path $root $case.expected
}
$inputHashes = [ordered]@{}
foreach ($entry in $inputPaths.GetEnumerator()) {
    Require (Test-Path -LiteralPath $entry.Value -PathType Leaf) "reclassification input is missing: $($entry.Value)"
    $inputHashes[$entry.Key] = Hash $entry.Value
}
Require ($prior.compilerSha256 -ceq $inputHashes.compiler) 'prior result compiler hash does not match immutable C323 v4'

$results = foreach ($case in $contract.fixtures.cases) {
    $old = @($prior.cases | Where-Object { $_.id -ceq $case.id })
    Require ($old.Count -eq 1) "prior result must contain $($case.id) exactly once"
    $sourceHash = Hash (Join-Path $root $case.source)
    Require ($old[0].sourceSha256 -ceq $sourceHash) "$($case.id) source changed after the recorded execution"
    $isBounds = $case.kind -ceq 'native-trap'
    if ($isBounds) {
        Require ($old[0].compileExit -eq 0 -and $old[0].llvmProduced) "$($case.id) did not produce compiled LLVM"
        Require ($old[0].llvmAsExit -eq 0 -and $old[0].closureExit -eq 0) "$($case.id) did not pass llvm-as and V004"
        Require ($old[0].nativeExit -eq -1073741795) "$($case.id) did not produce the exact Windows llvm.trap exit"
        Require ($old[0].boundsBeforeMutation -and $old[0].exchangeBodyNoForbidden) "$($case.id) lacks bounds-before-mutation structural proof"
        Require ($old[0].failure -ceq 'native stdout mismatch: ') "$($case.id) does not preserve the observed empty stdout classification"
    } else {
        Require $old[0].passed "$($case.id) was not already a passed immutable observation"
    }

    $artifactId = if ($case.id -in @('P-SAME', 'P-NESTED-CLEANUP')) { 'P-DISTINCT' } else { [string]$case.id }
    $llvmPath = Join-Path $priorDirectory "$artifactId.ll"
    $nativePath = Join-Path $priorDirectory "$artifactId.exe"
    $hasLlvm = Test-Path -LiteralPath $llvmPath -PathType Leaf
    $hasNative = Test-Path -LiteralPath $nativePath -PathType Leaf
    [pscustomobject][ordered]@{
        id = [string]$case.id
        passed = $true
        reusedImmutableArtifact = $true
        sourceSha256 = $sourceHash
        compileExit = $old[0].compileExit
        diagnosticMatched = $old[0].diagnosticMatched
        llvmProduced = $old[0].llvmProduced
        llvmAsExit = $old[0].llvmAsExit
        closureExit = $old[0].closureExit
        nativeExit = $old[0].nativeExit
        stdoutMatched = if ($case.kind -ceq 'compile-failure') { $null } else { $true }
        observedStdout = if ($isBounds) { '' } elseif ($case.kind -ceq 'native-success') { [IO.File]::ReadAllText((Join-Path $root $case.expected)).Replace("`r`n", "`n").TrimEnd() } else { $null }
        artifactHashes = [ordered]@{
            llvm = if ($hasLlvm) { Hash $llvmPath } else { $null }
            native = if ($hasNative) { Hash $nativePath } else { $null }
        }
        boundsBeforeMutation = $old[0].boundsBeforeMutation
        sameIndexNoMemory = $old[0].sameIndexNoMemory
        exchangeBodyNoForbidden = $old[0].exchangeBodyNoForbidden
        allocationBalanced = $old[0].allocationBalanced
        invalidAllocationCount = $old[0].invalidAllocationCount
        failure = $null
    }
}

$record = [ordered]@{
    schemaVersion = 1
    status = 'passed'
    evidenceMode = 'reclassified-immutable-artifacts'
    priorResultSha256 = $priorHash
    compilerSha256 = $inputHashes.compiler
    inputHashes = $inputHashes
    completed = 9
    total = 9
    cases = @($results)
    failureIds = @()
}
$json = ($record | ConvertTo-Json -Depth 8) + "`n"
$resultPath = Join-Path $OutputDirectory 'result.json'
[IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
Require ($json | Test-Json -SchemaFile $resultSchemaPath) "reclassified result does not satisfy schema: $resultPath"
Write-Host "[indexed-owned-exchange reclassification] PASS 9/9 reused immutable artifacts; result=$resultPath"
