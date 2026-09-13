[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$Compiler,
    [string]$ContractPath,
    [string]$Llvm
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
if ([string]::IsNullOrWhiteSpace($Compiler)) { $Compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll' }
if ([string]::IsNullOrWhiteSpace($ContractPath)) { $ContractPath = Join-Path $root 'scripts/contracts/json-schema-mapping.json' }
if ([string]::IsNullOrWhiteSpace($Llvm)) { $Llvm = Join-Path $root '.tools/llvm-22.1.8' }
$contractPath = [IO.Path]::GetFullPath($ContractPath)
$schemaPath = Join-Path $root 'scripts/contracts/json-capability-candidate.schema.json'
$fixturePath = Join-Path $root 'scripts/probes/json-schema-mapping/schema-mapping.slg'
$expectedPath = Join-Path $root 'scripts/probes/json-schema-mapping/schema-mapping.stdout.txt'
$jsonPath = Join-Path $root 'stdlib/std/text/json.slg'
$outputDirectory = Join-Path $root ('artifacts/scratch/json-schema-mapping-' + [Guid]::NewGuid().ToString('N'))
$resultPath = Join-Path $outputDirectory 'result.json'
[IO.Directory]::CreateDirectory($outputDirectory) | Out-Null

$record = [ordered]@{
    schemaVersion = 1
    status = 'running'
    capabilityStatus = 'candidate-only'
    productionImplemented = $false
    completed = 0
    total = 18
    staticCompleted = 0
    staticTotal = 5
    isolatedCompleted = 0
    isolatedTotal = 12
    inputStabilityCompleted = 0
    inputStabilityTotal = 1
    checks = @()
    failureIds = @()
}
$currentFailureId = 'SCHEMA_CONTRACT_MISMATCH'

function Save-Result {
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
}

function Complete-Static([string]$Name) {
    $record.completed++
    $record.staticCompleted++
    $record.checks += $Name
    Save-Result
}

function Complete-Isolated([string]$Name) {
    $record.completed++
    $record.isolatedCompleted++
    $record.checks += $Name
    Save-Result
}

function Hash([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

try {
    $inputs = @($contractPath, $schemaPath, $fixturePath, $expectedPath, $jsonPath, $Compiler, $PSCommandPath)
    $inputHashes = [ordered]@{}
    foreach ($path in $inputs) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "schema input missing: $path" }
        $inputHashes[[IO.Path]::GetFullPath($path)] = Hash $path
    }
    $record.inputHashes = $inputHashes

    if ((Hash $contractPath) -cne '5FA8C0A90F6BCA6299DDF1A1FB67BD5EF1A0A22A10E282BEE168AF11972297DE' -or
        (Hash $fixturePath) -cne '9F653809B28211E8292F4413B4154B524B0B3FE326CA0970E1744864938AF017' -or
        (Hash $expectedPath) -cne 'DE1BCB9D745E662C57B92C6E94C6D0B588FC66CFEB31709026954F892311D1D3') {
        throw 'pinned schema contract, fixture, or expected bytes changed'
    }
    Complete-Static 'pinned-artifact-tuple'

    $contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json
    if (-not (Test-Json -LiteralPath $contractPath -SchemaFile $schemaPath -ErrorAction SilentlyContinue) -or
        $contract.schemaVersion -ne 1 -or
        $contract.contractSchema -cne 'scripts/contracts/json-capability-candidate.schema.json' -or
        $contract.capabilityId -cne 'schema-driven-user-mapping' -or
        $contract.authority -cne 'detail-authority' -or
        $contract.implementationStatus -cne 'candidate-only' -or $contract.productionImplemented -ne $false -or
        $contract.reflection -cne 'forbidden' -or
        $contract.model.fieldOrder -cne 'schema declaration order on write; input order ignored on read' -or
        $contract.model.required -cne 'each required field occurs exactly once' -or
        $contract.model.duplicateKnownField -cne 'reject regardless of unknown-member policy' -or
        ($contract.model.unknownMembers -join ',') -cne 'Reject,Skip' -or
        $contract.model.unknownEnumTag -cne 'reject; no catch-all or numeric ordinal fallback' -or
        $contract.verifier.total -ne 18 -or $contract.verifier.staticChecks -ne 5 -or
        $contract.verifier.isolatedCaseChecks -ne 12 -or $contract.verifier.inputStabilityChecks -ne 1 -or
        $contract.fixtureCases.Count -ne 12) {
        throw 'schema policy or denominator differs from the independent matrix'
    }
    Complete-Static 'exact-schema-policy-and-denominator'

    $source = Get-Content -Raw -LiteralPath $fixturePath
    foreach ($required in @(
        'enum UnknownMemberPolicy', 'struct UserSchema', 'struct User', 'enum UserDecodeResult',
        'decodeUser document: ref json.Document', 'maxOwnedBytes: Int',
        'stageUserDocument user: ref User', 'maxStagingBytes: Int',
        'writer! -> document(document)', 'MappingErrorKind.DuplicateField',
        'MappingErrorKind.UnknownEnumTag', 'MappingErrorKind.OwnedByteLimitExceeded')) {
        if (-not $source.Contains($required, [StringComparison]::Ordinal)) {
            $currentFailureId = 'SCHEMA_SURFACE_MISMATCH'
            throw "schema surface missing: $required"
        }
    }
    Complete-Static 'explicit-schema-surface'

    $currentFailureId = 'REFLECTION_OR_IMPLICIT_MAPPING_FOUND'
    foreach ($forbidden in @('dyn ', 'box ', 'reflect', 'runtimeType', 'fieldByName', 'ordinal')) {
        if ($source.Contains($forbidden, [StringComparison]::OrdinalIgnoreCase)) {
            throw "implicit/reflection mapping marker found: $forbidden"
        }
    }
    Complete-Static 'no-reflection-or-implicit-enum-fallback'

    $currentFailureId = 'SCHEMA_SURFACE_MISMATCH'
    if ((Hash $schemaPath) -cne '2A0490C8899408A3B6F1A0D664C9CF5E11F1ED87FB763BCA3AFDC2EB734FFB4B' -or
        $contract.module -cne 'stdlib/std/text/json.slg' -or $contract.verifier.path -cne 'scripts/verify-json-schema-mapping.ps1') {
        throw 'shared candidate schema or authority linkage changed'
    }
    Complete-Static 'shared-envelope-schema-and-authority-linkage'

    $currentFailureId = 'ISOLATED_COMPILE_FAILED'
    $executable = Join-Path $outputDirectory 'schema-user-mapping.exe'
    $actual = (& dotnet $Compiler run $fixturePath --llvm $Llvm -o $executable --keep-temps 2>&1) -join "`n"
    [IO.File]::WriteAllText((Join-Path $outputDirectory 'managed.log'), $actual + "`n")
    if ($LASTEXITCODE -ne 0) {
        [IO.File]::WriteAllText((Join-Path $outputDirectory 'compile.log'), $actual + "`n")
        throw "isolated schema compile/run failed: $actual"
    }
    $actualLines = $actual.Replace("`r`n", "`n").TrimEnd("`n").Split("`n")
    $expectedBytes = [IO.File]::ReadAllBytes($expectedPath)
    if ($expectedBytes.Length -ge 3 -and $expectedBytes[0] -eq 239 -and $expectedBytes[1] -eq 187 -and $expectedBytes[2] -eq 191) {
        throw 'expected output must be BOM-free UTF-8'
    }
    $expectedText = [Text.UTF8Encoding]::new($false, $true).GetString($expectedBytes)
    if ($expectedText.Contains("`r", [StringComparison]::Ordinal) -or -not $expectedText.EndsWith("`n", [StringComparison]::Ordinal)) {
        throw 'expected output must use LF and one terminal newline'
    }
    $expectedLines = $expectedText.TrimEnd("`n").Split("`n")
    if ($actualLines.Count -ne 12 -or $expectedLines.Count -ne 12) {
        $currentFailureId = 'ISOLATED_CASE_FAILED'
        throw "isolated case denominator mismatch: actual=$($actualLines.Count), expected=$($expectedLines.Count)"
    }
    for ($index = 0; $index -lt 12; $index++) {
        $currentFailureId = 'ISOLATED_CASE_FAILED'
        if ($actualLines[$index] -cne $expectedLines[$index] -or
            $contract.fixtureCases[$index].expected -cne $expectedLines[$index]) {
            throw "isolated case mismatch at $index`: expected '$($expectedLines[$index])', actual '$($actualLines[$index])'"
        }
        Complete-Isolated $contract.fixtureCases[$index].id
    }

    $currentFailureId = 'INPUT_DRIFT'
    foreach ($path in $inputHashes.Keys) {
        if ((Hash $path) -cne $inputHashes[$path]) { throw "schema input changed during verification: $path" }
    }
    $record.completed++
    $record.inputStabilityCompleted++
    $record.checks += 'input-stability'
    if ($record.completed -ne $record.total -or $record.staticCompleted -ne $record.staticTotal -or
        $record.isolatedCompleted -ne $record.isolatedTotal -or
        $record.inputStabilityCompleted -ne $record.inputStabilityTotal) {
        throw 'schema verifier denominator drifted'
    }
    $record.status = 'passed'
} catch {
    $record.status = 'failed'
    $record.failureIds = @($currentFailureId)
    $record.failure = $_.Exception.Message
    throw
} finally {
    Save-Result
}

Write-Host "[JSON schema mapping candidate] PASS $($record.completed)/$($record.total); productionImplemented=false; $resultPath"
