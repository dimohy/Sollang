[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$PublishGolden
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $root 'scripts/contracts/csv-writer.json'
$schemaPath = Join-Path $root 'scripts/contracts/csv-writer.schema.json'
$contractText = Get-Content -LiteralPath $contractPath -Raw
if (-not (Test-Json -Json $contractText -SchemaFile $schemaPath)) { throw 'CSV writer contract schema validation failed' }
$contract = $contractText | ConvertFrom-Json
if ($contract.schemaVersion -ne 1 -or $contract.scope -cne 'bounded-transactional-utf8-record-writer-over-caller-output' -or
    $contract.referenceCases.Count -ne 7 -or $contract.invariants.Count -ne 14 -or $contract.requiredFailureKinds.Count -ne 10 -or
    @($contract.referenceCases.label | Sort-Object -Unique).Count -ne 7) {
    throw 'CSV writer contract dimensions or scope drifted'
}
$compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$module = Join-Path $root $contract.module
$fixture = Join-Path $root "examples/regression/$($contract.fixture).slg"
$golden = Join-Path $root "examples/regression/expected/$($contract.fixture).stdout.txt"
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$auditPath = Join-Path $root 'scripts/llvm-no-allocation-audit.ps1'
$output = Join-Path $root ('artifacts/scratch/csv-writer-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($output) | Out-Null
$resultPath = Join-Path $output 'result.json'
$record = [ordered]@{
    schemaVersion = 1; scope = 'managed-windows-csv-writer-focused'
    status = 'running'; completed = 0; total = 11; checks = @()
    integration = 'required selfhost/target closure remains separate'
}
function Save-Record { [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 6) + "`n")) }
function Complete-Check([string]$Name) { $record.completed++; $record.checks += $Name; Save-Record }
try {
    $inputHashes = @{}
    $inputs = @($compiler, $module, $fixture, $contractPath, $schemaPath, $auditPath, $PSCommandPath)
    if (-not $PublishGolden) { $inputs += $golden }
    $negativeDiagnostics = @{}
    foreach ($name in $contract.negativeFixtures) {
        $inputs += Join-Path $root "examples/regression/diagnostics/$name.slg"
        $diagnosticPath = Join-Path $root "examples/regression/diagnostics/$name.stderr.contains.txt"
        $inputs += $diagnosticPath
        $diagnostic = (Get-Content -LiteralPath $diagnosticPath -Raw).Trim()
        if ([string]::IsNullOrWhiteSpace($diagnostic)) { throw "CSV writer negative diagnostic is empty: $name" }
        $negativeDiagnostics[$name] = $diagnostic
    }
    foreach ($path in $inputs) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "CSV writer input is missing: $path" }
        $inputHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }
    $record.inputHashes = $inputHashes
    $record.compilerSha256 = $inputHashes[$compiler]
    Save-Record
    & (Join-Path $root 'scripts/format-authoritative-slg.ps1') -Check -Source @($module, $fixture)
    $exe = Join-Path $output 'csv-writer.exe'
    $actual = (& dotnet $compiler run $fixture --llvm $llvm -o $exe --keep-temps 2>&1) -join "`n"
    $runExit = $LASTEXITCODE
    [IO.File]::WriteAllText((Join-Path $output 'run.log'), $actual + "`n")
    $record.exitCode = $runExit
    if ($runExit -ne 0) { throw "CSV writer execution failed: $actual" }
    $actual = $actual.Replace("`r`n", "`n").TrimEnd()
    $expectedLines = @()
    foreach ($case in $contract.referenceCases) {
        # Independent .NET byte construction plus an unrelated CSV parser:
        # encoding and decoded field identity must both agree with the SLG run.
        $encodedFields = foreach ($field in $case.fields) {
            if ($field.Length -eq 0 -or $field.IndexOfAny([char[]]",`"`r`n") -ge 0) {
                '"' + $field.Replace('"', '""') + '"'
            } else { $field }
        }
        $encoded = ($encodedFields -join ',') + $case.lineEnding
        $bytes = [Text.Encoding]::UTF8.GetBytes($encoded)
        $parser = [Microsoft.VisualBasic.FileIO.TextFieldParser]::new([IO.StringReader]::new($encoded))
        $parser.SetDelimiters(','); $parser.HasFieldsEnclosedInQuotes = $true; $parser.TrimWhiteSpace = $false
        try {
            $parsed = $parser.ReadFields()
            if ($parsed.Count -ne $case.fields.Count -or -not $parser.EndOfData) { throw "CSV writer reference $($case.label) row count differs" }
            for ($index = 0; $index -lt $parsed.Count; $index++) {
                if ($parsed[$index] -cne $case.fields[$index]) { throw "CSV writer reference $($case.label) field $index differs" }
            }
        } finally { $parser.Dispose() }
        $dataLine = '{0}={1}:{2},' -f $case.label, $bytes.Count, ($bytes -join ',')
        $stateLine = '{0}-state={1},1,len=64,capacity=true,tail=true' -f $case.label, $bytes.Count
        foreach ($line in @($dataLine, $stateLine)) {
            if (@($actual -split "`n" | Where-Object { $_ -ceq $line }).Count -ne 1) {
                throw "CSV writer reference/state output differs: $line"
            }
            $expectedLines += $line
        }
        Complete-Check "reference-$($case.label)-bytes-parser-and-storage"
    }
    foreach ($label in @('negative-output', 'negative-records', 'negative-fields', 'negative-bytes')) {
        $expectedLines += "$label=InvalidLimits@0/0,unchanged=true"
    }
    foreach ($label in @('either', 'negative-columns', 'columns-over-limit')) {
        $expectedLines += "$label=InvalidOptions@0/0,unchanged=true"
    }
    $failures = [ordered]@{
        'empty-record' = 'InvalidRecord'; 'too-many-fields' = 'FieldCountLimit'
        'columns' = 'ColumnCountMismatch'; 'output-budget' = 'OutputLimit'
        'field-bytes' = 'FieldSizeLimit'; 'later-control' = 'InvalidControl'
        'zero-output' = 'OutputLimit'; 'zero-records' = 'RecordLimit'
    }
    foreach ($entry in $failures.GetEnumerator()) {
        foreach ($attempt in 0..1) { $expectedLines += "$($entry.Key)-$attempt=$($entry.Value)@0/0,unchanged=true" }
    }
    $expectedLines += @(
        'retry=OutputTooSmall@0/7,unchanged=true'
        'retried=7,bytes=7,records=1,tail=true,len=12,capacity=true'
        'second=3,bytes=10,records=2,tail=true'
        'record-budget=RecordLimit@10/0,unchanged=true'
    )
    $expected = $expectedLines -join "`n"
    [IO.File]::WriteAllText((Join-Path $output 'reference.stdout.txt'), $expected + "`n")
    if ($actual -cne $expected) { throw "CSV writer exact output, boundary controls, or warning-zero contract differs; see $output/run.log and reference.stdout.txt" }
    foreach ($kind in $contract.requiredFailureKinds) {
        if ($actual -notmatch ('(?m)^[^=]+=' + [regex]::Escape($kind) + '@\d+/\d+,unchanged=true$')) {
            throw "CSV writer did not execute its $kind failure control"
        }
    }
    Complete-Check 'exact-native-execution-ten-errors-retry-and-cumulative-budgets'
    $ir = [IO.Path]::ChangeExtension($exe, '.ll')
    & (Join-Path $llvm 'bin/llvm-as.exe') $ir -o ([IO.Path]::ChangeExtension($exe, '.bc'))
    if ($LASTEXITCODE -ne 0) { throw 'CSV writer LLVM assembly failed' }
    & (Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1') -LlvmPath $ir
    . $auditPath
    $audit = Assert-LlvmNoAllocation -LlvmText (Get-Content -LiteralPath $ir -Raw) `
        -RootSymbolPattern '^sollang_fn_std_text_csv_' -AllowedExternalSymbols $contract.allowedWindowsExternals
    $record.libraryRootCount = $audit.RootCount
    $record.reachableBodyCount = $audit.ReachableBodyCount
    $record.llvmSha256 = (Get-FileHash -LiteralPath $ir -Algorithm SHA256).Hash
    $record.executableSha256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
    Complete-Check 'llvm-assembly-closure-transitive-no-allocation'
    $record.ownershipChecks = @()
    $failedOwnershipChecks = @()
    foreach ($name in $contract.negativeFixtures) {
        $negativeSource = Join-Path $root "examples/regression/diagnostics/$name.slg"
        $negativeExe = Join-Path $output "$name.exe"
        $negativeLlvm = Join-Path $output "$name.ll"
        $temporaryLlvm = Join-Path $output "$name.slg-tmp/$name.ll"
        $failure = (& dotnet $compiler build $negativeSource --llvm $llvm -o $negativeExe --keep-temps 2>&1) -join "`n"
        $failureExit = $LASTEXITCODE
        $failureLog = Join-Path $output "$name.log"
        [IO.File]::WriteAllText($failureLog, $failure + "`n")
        $products = @(@($negativeLlvm, $negativeExe, $temporaryLlvm) | Where-Object { Test-Path -LiteralPath $_ })
        $diagnosticMatched = $failure.Contains($negativeDiagnostics[$name], [StringComparison]::Ordinal)
        $semanticFailure = $failure -match 'semantic error'
        $passed = $failureExit -ne 0 -and $semanticFailure -and $diagnosticMatched -and $products.Count -eq 0
        $record.ownershipChecks += [ordered]@{
            name = $name; status = if ($passed) { 'passed' } else { 'failed' }
            exitCode = $failureExit; semanticFailure = $semanticFailure
            expectedDiagnosticMatched = $diagnosticMatched; generatedProducts = $products; log = $failureLog
        }
        if ($passed) { Complete-Check $name } else { $failedOwnershipChecks += $name; Save-Record }
    }
    foreach ($path in $inputHashes.Keys) {
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $inputHashes[$path]) { throw "CSV writer input changed: $path" }
    }
    $record.inputsStable = $true
    if ($failedOwnershipChecks.Count -gt 0) {
        throw "CSV writer ownership/privacy controls did not fail before LLVM with their expected diagnostics: $($failedOwnershipChecks -join ', ')"
    }
    # ExampleTests.Normalize publishes LF and UTF-8 without a BOM. The same
    # byte identity is required when verifying an existing golden, not just publishing.
    $verifiedBytes = [Text.Encoding]::UTF8.GetBytes($actual + "`n")
    $verifiedHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($verifiedBytes))
    $record.verifiedOutputSha256 = $verifiedHash
    if ($PublishGolden) {
        $publication = (& dotnet run --project (Join-Path $root 'tests/Sollang.ExampleTests') --no-build -c Release -- `
            --exact $contract.fixture --skip-bootstrap --update-expected --jobs 1 2>&1) -join "`n"
        $publicationExit = $LASTEXITCODE
        [IO.File]::WriteAllText((Join-Path $output 'golden-publication.log'), $publication + "`n")
        if ($publicationExit -ne 0) { throw "CSV writer authoritative golden publication failed: $publication" }
        $record.goldenPublication = 'authoritative-update-command-and-verified-actual-byte-equality'
    }
    $goldenHash = (Get-FileHash -LiteralPath $golden -Algorithm SHA256).Hash
    if ($goldenHash -cne $verifiedHash) { throw 'CSV writer golden bytes differ from verified actual output' }
    $record.goldenSha256 = $goldenHash
    foreach ($path in $inputHashes.Keys) {
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $inputHashes[$path]) { throw "CSV writer input changed during publication: $path" }
    }
    $record.outputLines = $expectedLines.Count
    if ($record.completed -ne $record.total) { throw 'CSV writer focused count differs from its contract' }
    $record.status = 'passed'
} catch {
    $record.status = 'failed'; $record.failure = $_.Exception.Message
    throw
} finally { Save-Record }
Write-Host "[CSV writer focused] PASS $($record.completed)/$($record.total); $resultPath"
