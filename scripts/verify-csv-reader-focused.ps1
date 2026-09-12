[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$allocationAudit = Join-Path $root 'scripts/llvm-no-allocation-audit.ps1'
. $allocationAudit
$contractPath = Join-Path $root 'scripts/contracts/csv-reader.json'
$schemaPath = Join-Path $root 'scripts/contracts/csv-reader.schema.json'
$contractText = Get-Content -LiteralPath $contractPath -Raw
if (-not (Test-Json -Json $contractText -SchemaFile $schemaPath)) { throw 'CSV reader contract does not satisfy its schema' }
$contract = $contractText | ConvertFrom-Json
if ($contract.schemaVersion -ne 1 -or $contract.scope -cne 'bounded-utf8-field-stream-over-borrowed-text' -or
    $contract.referenceCases.Count -ne 4 -or $contract.errors.Count -ne 13 -or $contract.invariants.Count -ne 12 -or
    $contract.negativeFixtures.Count -ne 2) {
    throw 'CSV reader contract dimensions or scope drifted'
}
if (@($contract.referenceCases.label | Sort-Object -Unique).Count -ne 4) { throw 'CSV reference labels must be unique' }
$compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$module = Join-Path $root $contract.module
$fixture = Join-Path $root ("examples/regression/$($contract.fixture).slg")
$expectation = Join-Path $root ("examples/regression/expected/$($contract.fixture).stdout.txt")
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$output = Join-Path $root ('artifacts/scratch/csv-reader-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($output) | Out-Null
$resultPath = Join-Path $output 'result.json'
$record = [ordered]@{
    schemaVersion = 1
    scope = 'managed-windows-csv-focused-execution-and-independent-reference'
    status = 'running'
    completed = 0
    total = 8
    checks = @()
    integration = 'selfhost and additional targets pending'
}
function Complete-Check([string]$Name) {
    $record.completed++
    $record.checks += $Name
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 5) + "`n"))
}
try {
    $fingerprints = @{}
    $inputs = @($compiler, $contractPath, $schemaPath, $allocationAudit, $module, $fixture, $expectation, $PSCommandPath)
    foreach ($name in $contract.negativeFixtures) {
        $inputs += Join-Path $root "examples/regression/diagnostics/$name.slg"
        $inputs += Join-Path $root "examples/regression/diagnostics/$name.stderr.contains.txt"
    }
    foreach ($path in $inputs) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "CSV input is missing: $path" }
        $fingerprints[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }
    # A failed ownership control is evidence too: retain the exact inputs before
    # running any compiler command, rather than recording hashes only on success.
    $record.inputHashes = $fingerprints
    $record.compilerSha256 = $fingerprints[$compiler]
    $record.moduleSha256 = $fingerprints[$module]
    $record.fixtureSha256 = $fingerprints[$fixture]
    $record.expectedSha256 = $fingerprints[$expectation]
    $record.contractSha256 = $fingerprints[$contractPath]
    $record.verifierSha256 = $fingerprints[$PSCommandPath]
    $record.allocationAuditSha256 = $fingerprints[$allocationAudit]
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 5) + "`n"))
    & (Join-Path $root 'scripts/format-authoritative-slg.ps1') -Check -Source @($module, $fixture)
    $exe = Join-Path $output 'csv-reader.exe'
    $actual = (& dotnet $compiler run $fixture --llvm $llvm -o $exe --keep-temps 2>&1) -join "`n"
    $exitCode = $LASTEXITCODE
    [IO.File]::WriteAllText((Join-Path $output 'run.log'), $actual + "`n")
    if ($exitCode -ne 0) { throw "CSV execution failed (exit $exitCode): $actual" }
    $actual = $actual.Replace("`r`n", "`n").TrimEnd()
    $expected = (Get-Content -LiteralPath $expectation -Raw).Replace("`r`n", "`n").TrimEnd()
    if ($actual -cne $expected) { throw "CSV exact output differs, or contains an unexpected warning/note: $actual" }
    foreach ($kind in $contract.errors) {
        if ($actual -notmatch ('(?m)^[^=]+=' + [regex]::Escape($kind) + '@\d+/\d+,unchanged=true$')) {
            throw "CSV fixture did not execute its $kind error/cursor/output preservation control"
        }
    }
    Complete-Check 'exact-native-execution-and-thirteen-error-controls'

    # Independent parser, deliberately limited to shared RFC-style cases. Empty
    # records, control bytes, limits, and our explicit dialect policies are tested
    # by the SLG fixture, not misrepresented as TextFieldParser conformance.
    $referenceLines = @()
    foreach ($case in $contract.referenceCases) {
        $parser = [Microsoft.VisualBasic.FileIO.TextFieldParser]::new([IO.StringReader]::new($case.input))
        $parser.SetDelimiters(',')
        $parser.HasFieldsEnclosedInQuotes = $true
        $parser.TrimWhiteSpace = $false
        $lines = @()
        $row = 0
        try {
            while (-not $parser.EndOfData) {
                $fields = $parser.ReadFields()
                if ($fields.Count -ne $case.expectedColumns) { throw "reference case $($case.label) has unexpected columns" }
                for ($column = 0; $column -lt $fields.Count; $column++) {
                    $bytes = [Text.Encoding]::UTF8.GetBytes($fields[$column])
                    $tail = if ($bytes.Count -eq 0) { '' } else { ($bytes -join ',') + ',' }
                    $last = ($column -eq $fields.Count - 1).ToString().ToLowerInvariant()
                    $lines += '{0}={1},{2},{3},{4}:{5}' -f $case.label, $row, $column, $bytes.Count, $last, $tail
                }
                $row++
            }
        } finally { $parser.Dispose() }
        $lines += '{0}=end@{1}' -f $case.label, [Text.Encoding]::UTF8.GetByteCount($case.input)
        $actualCase = @($actual -split "`n" | Where-Object { $_.StartsWith($case.label + '=', [StringComparison]::Ordinal) })
        if (($actualCase -join "`n") -cne ($lines -join "`n")) { throw "CSV $($case.label) disagrees with independent TextFieldParser UTF-8 bytes" }
        $referenceLines += $lines
        Complete-Check ("reference-$($case.label)")
    }
    [IO.File]::WriteAllText((Join-Path $output 'reference.stdout.txt'), ($referenceLines -join "`n") + "`n")

    $irPath = [IO.Path]::ChangeExtension($exe, '.ll')
    & (Join-Path $llvm 'bin/llvm-as.exe') $irPath -o ([IO.Path]::ChangeExtension($exe, '.bc'))
    if ($LASTEXITCODE -ne 0) { throw 'CSV LLVM assembly failed' }
    & (Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1') -LlvmPath $irPath
    $ir = Get-Content -LiteralPath $irPath -Raw
    $audit = Assert-LlvmNoAllocation -LlvmText $ir -RootSymbolPattern '^sollang_fn_std_text_csv_' `
        -AllowedExternalSymbols $contract.allowedWindowsExternals
    Complete-Check 'llvm-assembly-direct-closure-and-transitive-library-allocation-audit'
    $record.ownershipChecks = @()
    $failedOwnershipChecks = @()
    foreach ($name in $contract.negativeFixtures) {
        $negativeSource = Join-Path $root "examples/regression/diagnostics/$name.slg"
        $negativeExpected = Join-Path $root "examples/regression/diagnostics/$name.stderr.contains.txt"
        $diagnostic = (Get-Content -LiteralPath $negativeExpected -Raw).Trim()
        if ([string]::IsNullOrWhiteSpace($diagnostic)) { throw "CSV negative diagnostic is empty: $name" }
        $negativeLlvm = Join-Path $output "$name.ll"
        $negativeExe = Join-Path $output "$name.exe"
        $temporaryLlvm = Join-Path $output "$name.slg-tmp/$name.ll"
        $failure = (& dotnet $compiler build $negativeSource --llvm $llvm -o $negativeExe --keep-temps 2>&1) -join "`n"
        $failureExitCode = $LASTEXITCODE
        [IO.File]::WriteAllText((Join-Path $output "$name.log"), $failure + "`n")
        $products = @(@($negativeLlvm, $negativeExe, $temporaryLlvm) | Where-Object { Test-Path -LiteralPath $_ })
        $diagnosticMatched = $failure.Contains($diagnostic, [StringComparison]::Ordinal)
        $semanticFailure = $failure -match 'semantic error'
        $passed = $failureExitCode -ne 0 -and $semanticFailure -and $diagnosticMatched -and $products.Count -eq 0
        $record.ownershipChecks += [ordered]@{
            name = $name
            status = if ($passed) { 'passed' } else { 'failed' }
            exitCode = $failureExitCode
            semanticFailure = $semanticFailure
            expectedDiagnosticMatched = $diagnosticMatched
            generatedProducts = $products
            log = Join-Path $output "$name.log"
        }
        if ($passed) {
            Complete-Check $name
        } else {
            # These two small controls are independent. Record both outcomes so
            # one failure does not require repeating the six successful checks.
            $failedOwnershipChecks += $name
        }
    }
    foreach ($path in $fingerprints.Keys) {
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $fingerprints[$path]) { throw "CSV verification input changed during execution: $path" }
    }
    $record.inputsStable = $true
    if ($failedOwnershipChecks.Count -gt 0) {
        throw "CSV ownership controls did not fail before LLVM with their expected diagnostics: $($failedOwnershipChecks -join ', '); see $resultPath and per-case logs"
    }
    $record.executableSha256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
    $record.libraryBodyCount = $audit.RootCount
    $record.reachableBodyCount = $audit.ReachableBodyCount
    $record.allowedExternalSymbols = $audit.ExternalSymbols
    $record.referenceOutputLines = $referenceLines.Count
    if ($record.completed -ne $record.total) { throw 'CSV focused verification count differs from contract' }
    $record.status = 'passed'
} catch {
    $record.status = 'failed'
    $record.failure = $_.Exception.Message
    throw
} finally {
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 5) + "`n"))
}
Write-Host "[CSV focused] PASS $($record.completed)/$($record.total); $resultPath"
