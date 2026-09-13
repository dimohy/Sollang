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
if ([string]::IsNullOrWhiteSpace($ContractPath)) { $ContractPath = Join-Path $root 'scripts/contracts/json-fixed-decimal.json' }
if ([string]::IsNullOrWhiteSpace($Llvm)) { $Llvm = Join-Path $root '.tools/llvm-22.1.8' }
$compiler = [IO.Path]::GetFullPath($Compiler)
$contractPath = [IO.Path]::GetFullPath($ContractPath)
$schemaPath = Join-Path $root 'scripts/contracts/json-capability-candidate.schema.json'
$referencePath = Join-Path $root 'scripts/contracts/json-fixed-decimal-reference.json'
$controlPath = Join-Path $root 'scripts/probes/json-fixed-decimal/int64-decimal-control.slg'
$widePath = Join-Path $root 'scripts/probes/json-fixed-decimal/int128-intermediate.slg'
$readerPath = Join-Path $root 'scripts/probes/json-fixed-decimal/json-decimal-reader.slg'
$writerPath = Join-Path $root 'scripts/probes/json-fixed-decimal/json-decimal-writer.slg'
$output = Join-Path $root ('artifacts/scratch/json-fixed-decimal-' + [Guid]::NewGuid().ToString('N'))
$resultPath = Join-Path $output 'result.json'
[IO.Directory]::CreateDirectory($output) | Out-Null

$record = [ordered]@{
    schemaVersion = 1
    status = 'running'
    capabilityStatus = 'unknown'
    productionImplemented = $false
    completed = 0
    total = 40
    staticCompleted = 0
    staticTotal = 7
    referenceCompleted = 0
    referenceTotal = 28
    capabilityCompleted = 0
    capabilityTotal = 4
    inputStabilityCompleted = 0
    inputStabilityTotal = 1
    checks = @()
    failureIds = @()
    blockerIds = @()
}
$failureId = 'DECIMAL_POLICY_CONTRACT_MISMATCH'

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
function Power10([int]$Exponent) { [Numerics.BigInteger]::Pow([Numerics.BigInteger]10, $Exponent) }

function Round-Quotient(
    [Numerics.BigInteger]$Magnitude,
    [Numerics.BigInteger]$Divisor,
    [bool]$Negative,
    [string]$Mode
) {
    [Numerics.BigInteger]$remainder = 0
    $quotient = [Numerics.BigInteger]::DivRem($Magnitude, $Divisor, [ref]$remainder)
    if ($remainder.IsZero) { return [pscustomobject]@{ Outcome = 'ok'; Value = $(if ($Negative) { -$quotient } else { $quotient }) } }
    $increment = $false
    switch ($Mode) {
        'Exact' { return [pscustomobject]@{ Outcome = 'RoundingRequired'; Value = [Numerics.BigInteger]::Zero } }
        'TowardZero' { }
        'TowardPositive' { $increment = -not $Negative }
        'TowardNegative' { $increment = $Negative }
        'NearestTiesToEven' {
            $comparison = ($remainder * 2).CompareTo($Divisor)
            $increment = $comparison -gt 0 -or ($comparison -eq 0 -and -not $quotient.IsEven)
        }
        default { throw "unknown rounding mode: $Mode" }
    }
    if ($increment) { $quotient += [Numerics.BigInteger]::One }
    [pscustomobject]@{ Outcome = 'ok'; Value = $(if ($Negative) { -$quotient } else { $quotient }) }
}

function Canonical([Numerics.BigInteger]$Coefficient, [int]$Scale) {
    $negative = $Coefficient.Sign -lt 0
    $digits = [Numerics.BigInteger]::Abs($Coefficient).ToString([Globalization.CultureInfo]::InvariantCulture)
    if ($Scale -eq 0) { return $(if ($negative) { '-' + $digits } else { $digits }) }
    if ($digits.Length -le $Scale) { $digits = ('0' * ($Scale + 1 - $digits.Length)) + $digits }
    $integer = $digits.Substring(0, $digits.Length - $Scale)
    $fraction = $digits.Substring($digits.Length - $Scale)
    $(if ($negative) { '-' } else { '' }) + $integer + '.' + $fraction
}

function Convert-Lexeme([string]$Lexeme, [int]$Precision, [int]$Scale, [string]$Mode) {
    $match = [regex]::Match($Lexeme, '^(?<sign>-?)(?<integer>0|[1-9][0-9]*)(?:\.(?<fraction>[0-9]+))?(?:[eE](?<exponent>[+-]?[0-9]+))?$')
    if (-not $match.Success) { return [pscustomobject]@{ Outcome = 'InvalidNumber' } }
    $fraction = $match.Groups['fraction'].Value
    $digits = $match.Groups['integer'].Value + $fraction
    $magnitude = [Numerics.BigInteger]::Parse($digits, [Globalization.CultureInfo]::InvariantCulture)
    $explicitExponent = if ($match.Groups['exponent'].Success) { [int]$match.Groups['exponent'].Value } else { 0 }
    $shift = $explicitExponent - $fraction.Length + $Scale
    if ($shift -ge 0) {
        $rounded = [pscustomobject]@{
            Outcome = 'ok'
            Value = $magnitude * (Power10 $shift) * $(if ($match.Groups['sign'].Value -eq '-') { -1 } else { 1 })
        }
    } else {
        $rounded = Round-Quotient $magnitude (Power10 (-$shift)) ($match.Groups['sign'].Value -eq '-') $Mode
    }
    if ($rounded.Outcome -ne 'ok') { return $rounded }
    $limit = (Power10 $Precision) - 1
    if ([Numerics.BigInteger]::Abs($rounded.Value) -gt $limit) { return [pscustomobject]@{ Outcome = 'Overflow' } }
    [pscustomobject]@{ Outcome = 'ok'; Value = $rounded.Value; Canonical = Canonical $rounded.Value $Scale }
}

function Run-Probe([string]$Name, [string]$Path) {
    $target = Join-Path $output ($Name + '.exe')
    $text = (& dotnet $compiler run $Path --llvm $Llvm -o $target --keep-temps 2>&1) -join "`n"
    $exit = $LASTEXITCODE
    [IO.File]::WriteAllText((Join-Path $output ($Name + '.log')), $text + "`n")
    [pscustomobject]@{ ExitCode = $exit; Text = $text }
}

try {
    $inputs = @($contractPath, $schemaPath, $referencePath, $controlPath, $widePath, $readerPath, $writerPath,
        (Join-Path $root 'stdlib/std/text/json.slg'), $compiler, $PSCommandPath)
    $inputHashes = [ordered]@{}
    foreach ($path in $inputs) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "decimal input missing: $path" }
        $inputHashes[[IO.Path]::GetFullPath($path)] = Hash $path
    }
    $record.inputHashes = $inputHashes

    if ((Hash $contractPath) -cne '3E0C4157120BDAEDF47350E6A03E90107CCE9071C2C65537AAF283FFC3EDE21B' -or
        (Hash $referencePath) -cne '148E8E4B1559FB29396FDD0C8D74AF099C99B9460C426E0514104F152B980F2E' -or
        (Hash $schemaPath) -cne '2A0490C8899408A3B6F1A0D664C9CF5E11F1ED87FB763BCA3AFDC2EB734FFB4B' -or
        (Hash $controlPath) -cne '0414DA4D77E98BE07F4F34E41821245B21B6E7FDAF1454C531F0854C7A8796F2' -or
        (Hash $widePath) -cne '4091A0907750F0C495E46C3519B7950F34E7DC456DA6CFC7E0E960D01FD19FE6' -or
        (Hash $readerPath) -cne '9F9637ED90E1EF94856D8FC90AA623211AA35E2BA9832495AC41F072BEA55B0B' -or
        (Hash $writerPath) -cne '264E507314E372C7C7A8DDBDDA821878A76D1D09701FD9194FDDFF856397CBDD') {
        throw 'decimal contract/reference/schema/probe tuple changed'
    }
    Complete static 'pinned-contract-reference-api'

    $contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json
    if (-not (Test-Json -LiteralPath $contractPath -SchemaFile $schemaPath -ErrorAction SilentlyContinue) -or
        $contract.capabilityId -cne 'fixed-decimal-conversion' -or
        $contract.authority -cne 'detail-authority' -or $contract.implementationStatus -cne 'blocked' -or
        $contract.productionImplemented -ne $false -or
        $contract.type.precision -cne '1 through 18 decimal digits' -or
        $contract.type.scale -cne '0 through precision' -or
        $contract.type.signedZero -cne 'not represented; every zero has coefficient 0 and formats without a minus sign' -or
        $contract.type.forgeability -cne 'construction only through validating factories') {
        throw 'decimal type/storage policy differs'
    }
    Complete static 'bounded-private-type-policy'

    if (($contract.roundingModes -join ',') -cne 'Exact,NearestTiesToEven,TowardZero,TowardPositive,TowardNegative' -or
        $contract.parse.exactMode -cne 'any discarded nonzero decimal digit returns RoundingRequired') {
        throw 'decimal explicit rounding policy differs'
    }
    Complete static 'explicit-rounding-policy'

    if ($contract.format.form -cne 'base-10 fixed notation without exponent' -or
        $contract.format.scale -cne 'exactly scale digits follow the decimal point; trailing zeros are retained' -or
        $contract.parse.input -cne 'one authenticated complete RFC 8259 number lexeme') {
        throw 'decimal JSON parse/format policy differs'
    }
    Complete static 'json-lexeme-and-canonical-format-policy'

    if ($contract.arithmetic.addSubtract -notmatch 'exact checked' -or
        $contract.arithmetic.multiply -notmatch 'exact wide intermediate' -or
        $contract.requiredPrimitive -notmatch 'at least 128 bits') {
        throw 'decimal exact arithmetic/overflow policy differs'
    }
    Complete static 'exact-arithmetic-and-wide-intermediate-policy'

    if ($contract.schemaMapping.fieldContract -notmatch 'precision, scale, and rounding mode' -or
        $contract.schemaMapping.ownership -notmatch 'copyable bounded scalar' -or
        ($contract.jsonApi -join '|') -cne 'fixedDecimal(coefficient: Int64, precision: UInt8, scale: UInt8) -> Result<FixedDecimal, DecimalError>|Reader.fixedDecimal(Token, DecimalPolicy) -> Result<FixedDecimal, Error>|valueFixedDecimal(ref Value, DecimalPolicy) -> Result<FixedDecimal, Error>|Writer.fixedDecimal(ref FixedDecimal) -> Result<Unit, Error>') {
        throw 'decimal schema mapping integration differs'
    }
    Complete static 'schema-mapping-integration'

    $reference = Get-Content -Raw -LiteralPath $referencePath | ConvertFrom-Json
    if ($reference.conversions.Count -ne 22 -or $reference.arithmetic.Count -ne 6 -or
        $contract.verifier.total -ne 40 -or $contract.verifier.referenceChecks -ne 28 -or
        $contract.contractSchema -cne 'scripts/contracts/json-capability-candidate.schema.json' -or
        $contract.module -cne 'stdlib/std/text/json.slg' -or
        $contract.verifier.path -cne 'scripts/verify-json-fixed-decimal.ps1') {
        throw 'decimal denominator or immutable compiler identity differs'
    }
    Complete static 'denominator-and-immutable-isolation'

    $failureId = 'DECIMAL_REFERENCE_MISMATCH'
    foreach ($tuple in $reference.conversions) {
        $actual = Convert-Lexeme $tuple.lexeme $tuple.precision $tuple.scale $tuple.rounding
        if ($actual.Outcome -cne $tuple.outcome -or
            ($actual.Outcome -ceq 'ok' -and ($actual.Value.ToString() -cne $tuple.coefficient -or $actual.Canonical -cne $tuple.canonical))) {
            throw "decimal conversion reference mismatch: $($tuple.id)"
        }
        Complete reference ('conversion-' + $tuple.id)
    }

    foreach ($tuple in $reference.arithmetic) {
        $left = [Numerics.BigInteger]::Parse($tuple.left, [Globalization.CultureInfo]::InvariantCulture)
        $right = if ($tuple.PSObject.Properties.Name -contains 'right') {
            [Numerics.BigInteger]::Parse($tuple.right, [Globalization.CultureInfo]::InvariantCulture)
        } else { [Numerics.BigInteger]::Zero }
        switch ($tuple.operation) {
            'add' { $rounded = [pscustomobject]@{ Outcome = 'ok'; Value = $left + $right } }
            'subtract' { $rounded = [pscustomobject]@{ Outcome = 'ok'; Value = $left - $right } }
            'multiply' {
                $product = $left * $right
                $rounded = Round-Quotient ([Numerics.BigInteger]::Abs($product)) (Power10 $tuple.scale) ($product.Sign -lt 0) $tuple.rounding
            }
            'rescale' {
                $shift = $tuple.scale - $tuple.sourceScale
                if ($shift -ge 0) { $rounded = [pscustomobject]@{ Outcome = 'ok'; Value = $left * (Power10 $shift) } }
                else { $rounded = Round-Quotient ([Numerics.BigInteger]::Abs($left)) (Power10 (-$shift)) ($left.Sign -lt 0) $tuple.rounding }
            }
            default { throw "unknown decimal operation: $($tuple.operation)" }
        }
        $limit = (Power10 $tuple.precision) - 1
        if ($rounded.Outcome -eq 'ok' -and [Numerics.BigInteger]::Abs($rounded.Value) -gt $limit) {
            $rounded = [pscustomobject]@{ Outcome = 'Overflow' }
        }
        if ($rounded.Outcome -cne $tuple.outcome -or
            ($rounded.Outcome -ceq 'ok' -and ($rounded.Value.ToString() -cne $tuple.coefficient -or
                (Canonical $rounded.Value $tuple.scale) -cne $tuple.canonical))) {
            throw "decimal arithmetic reference mismatch: $($tuple.id)"
        }
        Complete reference ('arithmetic-' + $tuple.id)
    }

    $failureId = 'DECIMAL_CAPABILITY_DIAGNOSTIC_DRIFT'
    $control = Run-Probe 'int64-decimal-control' $controlPath
    if ($control.ExitCode -ne 0 -or $control.Text.Replace("`r`n", "`n") -cne '350') {
        throw "Int64 decimal control failed: $($control.Text)"
    }
    Complete capability 'int64-control'

    $wide = Run-Probe 'int128-intermediate' $widePath
    if ($wide.ExitCode -eq 0 -or $wide.Text -notmatch "unknown type 'Int128'") {
        throw "wide intermediate diagnostic changed: $($wide.Text)"
    }
    Complete capability 'int128-intermediate-missing'

    $reader = Run-Probe 'json-decimal-reader' $readerPath
    if ($reader.ExitCode -eq 0 -or $reader.Text -notmatch "unknown value-flow target 'fixedDecimal'") {
        throw "JSON decimal reader diagnostic changed: $($reader.Text)"
    }
    Complete capability 'json-decimal-reader-api-missing'

    $writer = Run-Probe 'json-decimal-writer' $writerPath
    if ($writer.ExitCode -eq 0 -or $writer.Text -notmatch "unknown value-flow target 'fixedDecimal'") {
        throw "JSON decimal writer diagnostic changed: $($writer.Text)"
    }
    Complete capability 'json-decimal-writer-api-missing'

    $failureId = 'DECIMAL_INPUT_DRIFT'
    foreach ($path in $inputHashes.Keys) {
        if ((Hash $path) -cne $inputHashes[$path]) { throw "decimal input changed during verification: $path" }
    }
    Complete stability 'input-stability'
    if ($record.completed -ne $record.total -or $record.staticCompleted -ne $record.staticTotal -or
        $record.referenceCompleted -ne $record.referenceTotal -or
        $record.capabilityCompleted -ne $record.capabilityTotal -or
        $record.inputStabilityCompleted -ne $record.inputStabilityTotal) {
        throw 'decimal verifier denominator drifted'
    }
    $record.capabilityStatus = 'blocked'
    $record.blockerIds = @($contract.blockerIds)
    $record.status = 'passed'
} catch {
    $record.status = 'failed'
    $record.failureIds = @($failureId)
    $record.failure = $_.Exception.Message
    throw
} finally {
    Save-Result
}

Write-Host "[JSON fixed decimal candidate] PASS $($record.completed)/$($record.total); capability=blocked; productionImplemented=false; $resultPath"
