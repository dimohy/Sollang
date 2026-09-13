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
if ([string]::IsNullOrWhiteSpace($ContractPath)) { $ContractPath = Join-Path $root 'scripts/contracts/json-float-conversion.json' }
if ([string]::IsNullOrWhiteSpace($Llvm)) { $Llvm = Join-Path $root '.tools/llvm-22.1.8' }
$compiler = [IO.Path]::GetFullPath($Compiler)
$contractPath = [IO.Path]::GetFullPath($ContractPath)
$schemaPath = Join-Path $root 'scripts/contracts/json-capability-candidate.schema.json'
$referencePath = Join-Path $root 'scripts/contracts/json-float-reference.json'
$controlPath = Join-Path $root 'scripts/probes/json-float-conversion/float-control.slg'
$parsePath = Join-Path $root 'scripts/probes/json-float-conversion/dynamic-text-to-float.slg'
$formatPath = Join-Path $root 'scripts/probes/json-float-conversion/float-shortest-format.slg'
$classifyPath = Join-Path $root 'scripts/probes/json-float-conversion/float-classification.slg'
$output = Join-Path $root ('artifacts/scratch/json-float-conversion-' + [Guid]::NewGuid().ToString('N'))
$resultPath = Join-Path $output 'result.json'
[IO.Directory]::CreateDirectory($output) | Out-Null

$record = [ordered]@{
    schemaVersion = 1
    status = 'running'
    capabilityStatus = 'unknown'
    productionImplemented = $false
    completed = 0
    total = 32
    staticCompleted = 0
    staticTotal = 6
    referenceCompleted = 0
    referenceTotal = 21
    capabilityCompleted = 0
    capabilityTotal = 4
    inputStabilityCompleted = 0
    inputStabilityTotal = 1
    checks = @()
    failureIds = @()
    blockerIds = @()
}
$failureId = 'FLOAT_POLICY_CONTRACT_MISMATCH'

function Save-Result {
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
}

function Complete([string]$Group, [string]$Name) {
    $record.completed++
    $record.checks += $Name
    switch ($Group) {
        'static' { $record.staticCompleted++ }
        'reference' { $record.referenceCompleted++ }
        'capability' { $record.capabilityCompleted++ }
        'stability' { $record.inputStabilityCompleted++ }
    }
    Save-Result
}

function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

function Test-JsonFloatApiSurface([string]$Source) {
    $owner = $null
    $depth = 0
    foreach ($line in $Source.Replace("`r`n", "`n").Split("`n")) {
        if ($null -eq $owner -and $line -match '^\s*impl\s+(Reader|Writer)\s*\{') {
            $owner = $Matches[1]
            $depth = ([regex]::Matches($line, '\{').Count - [regex]::Matches($line, '\}').Count)
            if ($line -match '\{\s*public\s+(float32|float64)(?:\s|:)') { return $true }
            if ($depth -le 0) {
                $owner = $null
                $depth = 0
            }
            continue
        }
        if ($null -eq $owner) { continue }
        if ($line -match '^\s*public\s+(float32|float64)(?:\s|:)') { return $true }
        $depth += [regex]::Matches($line, '\{').Count - [regex]::Matches($line, '\}').Count
        if ($depth -le 0) {
            $owner = $null
            $depth = 0
        }
    }
    $false
}

function Run-Probe([string]$Name, [string]$Path) {
    $target = Join-Path $output ($Name + '.exe')
    $text = (& dotnet $compiler run $Path --llvm $Llvm -o $target --keep-temps 2>&1) -join "`n"
    $exit = $LASTEXITCODE
    [IO.File]::WriteAllText((Join-Path $output ($Name + '.log')), $text + "`n")
    [pscustomobject]@{ ExitCode = $exit; Text = $text }
}

try {
    $inputs = @($contractPath, $schemaPath, $referencePath, $controlPath, $parsePath, $formatPath,
        $classifyPath, (Join-Path $root 'stdlib/std/text/json.slg'), $compiler, $PSCommandPath)
    $inputHashes = [ordered]@{}
    foreach ($path in $inputs) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "float input missing: $path" }
        $inputHashes[[IO.Path]::GetFullPath($path)] = Hash $path
    }
    $record.inputHashes = $inputHashes

    if ((Hash $contractPath) -cne '9FD6AE2C32841890CF8E9C4846F8C8F5E44E447F9FD7A0B4168870429D69B631' -or
        (Hash $referencePath) -cne '14248C225748F1A4CBC04257736A0A0AD8473FA9BD3A2180726B0A17DC690B5A' -or
        (Hash $schemaPath) -cne '2A0490C8899408A3B6F1A0D664C9CF5E11F1ED87FB763BCA3AFDC2EB734FFB4B' -or
        (Hash $controlPath) -cne 'EE9FA19F75D0393946EF6EDDF0350CC84332F3032858BA41AE01736BFF96E9C3' -or
        (Hash $parsePath) -cne 'FB0CC7B66E5EB9C1E3174B0326B1422CDE9971455BE58F412B5C582EBF51C3E4' -or
        (Hash $classifyPath) -cne 'E10E7B0657523379CF3AADAF3F6E134F0ADBB7B09578C5F656600E4E91AA1273' -or
        (Hash $formatPath) -cne '4961973C9AEFD33369DF4C5A745BD3D9BEA7FB31A6EFB61CB7D2FDC9B2734B19') {
        throw 'float contract/reference/schema/probe tuple changed'
    }
    Complete static 'pinned-contract-reference-api'

    $contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json
    if (-not (Test-Json -LiteralPath $contractPath -SchemaFile $schemaPath -ErrorAction SilentlyContinue) -or
        $contract.capabilityId -cne 'float32-float64-conversion' -or
        $contract.authority -cne 'detail-authority' -or $contract.implementationStatus -cne 'blocked' -or
        $contract.productionImplemented -ne $false -or
        $contract.policy.rounding -cne 'IEEE-754 roundTiesToEven only' -or
        $contract.policy.overflow -cne 'reject when the rounded result is positive or negative infinity' -or
        $contract.policy.underflow -cne 'accept subnormal results; reject a nonzero mathematical lexeme that rounds to signed zero' -or
        $contract.policy.negativeZero -cne 'preserve an exact negative-zero lexeme and emit -0; positive zero emits 0' -or
        $contract.policy.finiteOnly -cne 'reader and writer never return or emit NaN or Infinity' -or
        $contract.policy.invalidSpellings.Count -ne 3) {
        throw 'float policy differs from independent finite/rounding matrix'
    }
    Complete static 'exact-finite-rounding-zero-policy'

    if (($contract.readerApi -join '|') -cne 'Reader.float32(Token, FloatPolicy) -> Result<Float32, Error>|Reader.float64(Token, FloatPolicy) -> Result<Float64, Error>' -or
        ($contract.writerApi -join '|') -cne 'Writer.float32(Float32, FloatPolicy) -> Result<Unit, Error>|Writer.float64(Float64, FloatPolicy) -> Result<Unit, Error>') {
        throw 'float reader/writer API contract differs'
    }
    Complete static 'explicit-reader-writer-api-draft'

    $reference = Get-Content -Raw -LiteralPath $referencePath | ConvertFrom-Json
    if ($contract.reference.tupleCount -ne 21 -or $reference.tuples.Count -ne 21 -or
        $contract.verifier.total -ne 32 -or $contract.verifier.referenceTupleChecks -ne 21 -or
        $contract.verifier.capabilityChecks -ne 4) {
        throw 'float reference or verifier denominator drifted'
    }
    Complete static 'reference-and-verifier-denominator'

    if ($contract.contractSchema -cne 'scripts/contracts/json-capability-candidate.schema.json' -or
        $contract.module -cne 'stdlib/std/text/json.slg' -or
        $contract.verifier.path -cne 'scripts/verify-json-float-conversion.ps1') {
        throw 'float envelope schema or authority linkage changed'
    }
    Complete static 'envelope-schema-and-authority-linkage'

    $jsonSource = Get-Content -Raw -LiteralPath (Join-Path $root 'stdlib/std/text/json.slg')
    foreach ($cleanControl in @(
        "public float32 value: Float32 -> Float32 => value",
        "impl Other {`n    public float64 value: Float64 -> Float64 => value`n}"
    )) {
        if (Test-JsonFloatApiSurface $cleanControl) { throw 'JSON float surface clean control was rejected' }
    }
    foreach ($forgedSurface in @(
        "impl Reader {`n    public float32 token: Token, policy: FloatPolicy -> Result<Float32, Error> { }`n}",
        "impl Reader {`n    public float64 token: Token, policy: FloatPolicy -> Result<Float64, Error> { }`n}",
        "impl Writer {`n    public float32 value: Float32, policy: FloatPolicy -> Result<Unit, Error> { }`n}",
        "impl Writer {`n    public float64 value: Float64, policy: FloatPolicy -> Result<Unit, Error> { }`n}",
        "impl Reader { public float32 token: Token, policy: FloatPolicy -> Result<Float32, Error> { } }"
    )) {
        if (-not (Test-JsonFloatApiSurface $forgedSurface)) { throw 'JSON float surface forgery was not detected' }
    }
    if ($contract.productionImplemented -eq $false -and (Test-JsonFloatApiSurface $jsonSource)) {
        throw 'production JSON Reader/Writer float API exists while productionImplemented=false'
    }
    Complete static 'production-float-api-absence-and-controls'

    $failureId = 'FLOAT_REFERENCE_MISMATCH'
    foreach ($tuple in $reference.tuples) {
        $style = [Globalization.NumberStyles]::Float
        $culture = [Globalization.CultureInfo]::InvariantCulture
        if ($tuple.type -ceq 'Float64') {
            [double]$value = 0
            if (-not [double]::TryParse($tuple.lexeme, $style, $culture, [ref]$value)) { throw "reference parse failed: $($tuple.lexeme)" }
            $bits = '{0:X16}' -f [BitConverter]::DoubleToUInt64Bits($value)
            $finite = [double]::IsFinite($value)
            $roundTrip = $value.ToString('R', $culture)
        } else {
            [single]$value = 0
            if (-not [single]::TryParse($tuple.lexeme, $style, $culture, [ref]$value)) { throw "reference parse failed: $($tuple.lexeme)" }
            $bits = '{0:X8}' -f [BitConverter]::SingleToUInt32Bits($value)
            $finite = [single]::IsFinite($value)
            $roundTrip = $value.ToString('R', $culture)
        }
        $mantissa = ($tuple.lexeme -split '[eE]')[0]
        $mathematicalNonzero = $mantissa -match '[1-9]'
        $zeroBits = $bits.TrimStart('8', '0').Length -eq 0
        $outcome = if (-not $finite) { 'overflow' } elseif ($zeroBits -and $mathematicalNonzero) { 'underflow' } else { 'finite' }
        if ($bits -cne $tuple.bits -or $roundTrip -cne $tuple.roundTrip -or $outcome -cne $tuple.outcome) {
            throw "reference mismatch: $($tuple.type) $($tuple.lexeme) bits=$bits roundTrip=$roundTrip outcome=$outcome"
        }
        Complete reference ("reference-$($tuple.type)-$($tuple.lexeme)")
    }

    $failureId = 'FLOAT_CAPABILITY_DIAGNOSTIC_DRIFT'
    $control = Run-Probe 'float-control' $controlPath
    if ($control.ExitCode -ne 0 -or $control.Text.Replace("`r`n", "`n") -cne '4') {
        throw "basic Float arithmetic control failed: $($control.Text)"
    }
    Complete capability 'float-arithmetic-control'

    $dynamic = Run-Probe 'dynamic-text-to-float' $parsePath
    if ($dynamic.ExitCode -eq 0 -or $dynamic.Text -notmatch "numeric conversion 'Float64' expects a numeric value, got Text") {
        throw "dynamic Text-to-Float capability diagnostic changed: $($dynamic.Text)"
    }
    Complete capability 'dynamic-text-to-float-missing'

    $classification = Run-Probe 'float-classification' $classifyPath
    if ($classification.ExitCode -eq 0 -or $classification.Text -notmatch "unknown value-flow target 'isFinite'") {
        throw "Float classification capability diagnostic changed: $($classification.Text)"
    }
    Complete capability 'float-classification-missing'

    $format = Run-Probe 'float-shortest-format' $formatPath
    if ($format.ExitCode -eq 0 -or $format.Text -notmatch 'string interpolation expects Text, Int, or Bool but received Double') {
        throw "Float shortest-format capability diagnostic changed: $($format.Text)"
    }
    Complete capability 'float-shortest-format-missing'

    $failureId = 'FLOAT_INPUT_DRIFT'
    foreach ($path in $inputHashes.Keys) {
        if ((Hash $path) -cne $inputHashes[$path]) { throw "float input changed during verification: $path" }
    }
    Complete stability 'input-stability'
    if ($record.completed -ne $record.total -or $record.staticCompleted -ne $record.staticTotal -or
        $record.referenceCompleted -ne $record.referenceTotal -or
        $record.capabilityCompleted -ne $record.capabilityTotal -or
        $record.inputStabilityCompleted -ne $record.inputStabilityTotal) {
        throw 'float verifier denominator drifted'
    }
    $record.capabilityStatus = 'blocked'
    $record.blockerIds = @(
        'JSON_FLOAT_DYNAMIC_PARSE_PRIMITIVE_MISSING',
        'JSON_FLOAT_CLASSIFICATION_PRIMITIVE_MISSING',
        'JSON_FLOAT_SHORTEST_FORMAT_PRIMITIVE_MISSING'
    )
    $record.status = 'passed'
} catch {
    $record.status = 'failed'
    $record.failureIds = @($failureId)
    $record.failure = $_.Exception.Message
    throw
} finally {
    Save-Result
}

Write-Host "[JSON float conversion candidate] PASS $($record.completed)/$($record.total); capability=blocked; productionImplemented=false; $resultPath"
