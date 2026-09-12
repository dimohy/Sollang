[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot), [switch]$AllowMissingGolden)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'llvm-no-allocation-audit.ps1')
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$module = Join-Path $root 'stdlib/std/text/regex.slg'
$fixture = Join-Path $root 'examples/regression/1729-regex-bounded-search.slg'
$golden = Join-Path $root 'examples/regression/expected/1729-regex-bounded-search.stdout.txt'
$contractPath = Join-Path $root 'scripts/contracts/text-regex.json'
$schemaPath = Join-Path $root 'scripts/contracts/text-regex.schema.json'
$referencePath = Join-Path $root 'scripts/contracts/fixtures/regex-reference.go'
$go = (Get-Command go -CommandType Application).Source
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$output = Join-Path $root ('artifacts/scratch/text-regex-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($output)
$resultPath = Join-Path $output 'result.json'
$hasGolden = Test-Path -LiteralPath $golden -PathType Leaf
if (-not $hasGolden -and -not $AllowMissingGolden) { throw 'Regex golden is not published; use explicit pre-publication mode' }
$negativeNames = @('regex-source-escape','regex-private-state')
$inputs = @($compiler,$module,$fixture,$contractPath,$schemaPath,$PSCommandPath,$referencePath,$go,
    (Join-Path $PSScriptRoot 'llvm-no-allocation-audit.ps1'),
    (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1'),
    (Join-Path $PSScriptRoot 'stage2-artifact-receipt.ps1'))
foreach ($name in $negativeNames) {
    $inputs += Join-Path $root "examples/regression/diagnostics/$name.slg"
    $inputs += Join-Path $root "examples/regression/diagnostics/$name.stderr.contains.txt"
}
if ($hasGolden) { $inputs += $golden }
$hashes = [ordered]@{}
foreach ($path in $inputs) { $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$stdlibSources = Get-NativeExactOrderedSourceClosure -Root (Join-Path $root 'stdlib')
$stdlibFingerprintSettings = [ordered]@{ platform = 'windows'; scope = '1729-text-regex-stdlib' }
$stdlibFingerprint = Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root -Settings $stdlibFingerprintSettings -InputPath $stdlibSources
$record = [ordered]@{schemaVersion=1;status='running';scope='managed-windows-bounded-regex-search';completed=0;total=$(if($hasGolden){10}else{9});inputHashes=$hashes;stdlibSourceCount=$stdlibSources.Count;stdlibSourceFingerprint=$stdlibFingerprint;checks=@();integration='selfhost and Stage deferred'}
function Save-Record { [IO.File]::WriteAllText($resultPath,(($record | ConvertTo-Json -Depth 8) + "`n")) }
function Complete-Check([string]$Name) { $record.completed++; $record.checks += $Name; Save-Record }
try {
    Save-Record
    $contractText = [IO.File]::ReadAllText($contractPath)
    if (-not (Test-Json -Json $contractText -SchemaFile $schemaPath)) { throw 'Regex contract/schema mismatch' }
    $contract = $contractText | ConvertFrom-Json
    if (@($contract.referenceCases.label | Sort-Object -Unique).Count -ne $contract.referenceCases.Count) { throw 'Regex reference labels are not unique' }
    if ($contract.referenceCases.Count -ne $contract.referenceCaseCount -or
        $contract.boundaryLines.Count -ne $contract.boundaryLineCount) {
        throw 'Regex contract case denominator drifted'
    }
    Complete-Check 'contract-schema'
    # Go's independent RE2 implementation selects leftmost-longest matches.
    $reference = (& $go run $referencePath $contractPath 2>&1) -join "`n"
    $referenceExit = $LASTEXITCODE
    [IO.File]::WriteAllText((Join-Path $output 'go-reference.log'),$reference + "`n")
    if ($referenceExit -ne 0) { throw "Go reference failed: $reference" }
    $referenceLines = @($reference.Replace("`r`n","`n").TrimEnd("`n") -split "`n")
    if ($referenceLines.Count -ne $contract.referenceCaseCount) { throw 'Go reference denominator drifted' }
    $expected = [Collections.Generic.List[string]]::new()
    for ($i=0; $i -lt $referenceLines.Count; $i++) {
        if ($referenceLines[$i] -notmatch ('^' + [regex]::Escape($contract.referenceCases[$i].label) + '=(none|[0-9]+,[0-9]+)$')) { throw 'Go reference labels/output shape drifted' }
        $expected.Add($referenceLines[$i])
    }
    $record.goVersion = (& $go version) -join ''
    if ($LASTEXITCODE -ne 0) { throw 'Go version failed' }
    foreach ($line in $contract.boundaryLines) { $expected.Add($line) }
    $expectedText = ($expected -join "`n") + "`n"
    [IO.File]::WriteAllText((Join-Path $output 'reference.stdout.txt'),$expectedText)
    $record.referenceCaseCount = $contract.referenceCases.Count
    $record.boundaryLineCount = $contract.boundaryLines.Count
    Complete-Check 'independent-go-longest-reference'
    $formatSources = @($module,$fixture) + @($negativeNames | ForEach-Object { Join-Path $root "examples/regression/diagnostics/$_.slg" })
    & (Join-Path $PSScriptRoot 'format-authoritative-slg.ps1') -Check -Source $formatSources
    Complete-Check 'focused-authoritative-format'
    $exe = Join-Path $output 'regex.exe'
    $actual = (& dotnet $compiler run $fixture --llvm $llvm -o $exe --keep-temps -O0 2>&1) -join "`n"
    $exitCode = $LASTEXITCODE
    [IO.File]::WriteAllText((Join-Path $output 'run.log'),$actual + "`n")
    if ($exitCode -ne 0 -or $actual -match '(?m)^(warning S|note N)' -or -not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw "Regex native execution failed: $actual" }
    $actualText = $actual.Replace("`r`n","`n").TrimEnd("`n") + "`n"
    if ($actualText -cne $expectedText) { throw 'Regex native output differs from independent cases or fixed boundary observations' }
    [IO.File]::WriteAllText((Join-Path $output 'actual.stdout.txt'),$actualText,[Text.UTF8Encoding]::new($false))
    $record.executableSha256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
    Complete-Check 'warning-free-native-exact-output'
    $ir = [IO.Path]::ChangeExtension($exe,'.ll')
    & (Join-Path $llvm 'bin/llvm-as.exe') $ir -o ([IO.Path]::ChangeExtension($exe,'.bc'))
    if ($LASTEXITCODE -ne 0) { throw 'Regex LLVM assembly failed' }
    & (Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1') -LlvmPath $ir
    Complete-Check 'llvm-assembly-and-closure'
    $audit = Assert-LlvmNoAllocation -LlvmText ([IO.File]::ReadAllText($ir)) -RootSymbolPattern '^sollang_fn_std_text_regex_' -AllowedExternalSymbols @('GetStdHandle','WriteFile','llvm.trap')
    $record.libraryBodyCount = $audit.RootCount
    $record.reachableBodyCount = $audit.ReachableBodyCount
    $record.allocationExternals = @($audit.ExternalSymbols)
    Complete-Check 'transitive-module-no-allocation'
    foreach ($name in $negativeNames) {
        $negative = Join-Path $root "examples/regression/diagnostics/$name.slg"
        $diagnostic = [IO.File]::ReadAllText((Join-Path $root "examples/regression/diagnostics/$name.stderr.contains.txt")).Trim()
        if ([string]::IsNullOrWhiteSpace($diagnostic)) { throw "Empty diagnostic for $name" }
        $negativeExe = Join-Path $output "$name.exe"
        $failure = (& dotnet $compiler build $negative --llvm $llvm -o $negativeExe --keep-temps 2>&1) -join "`n"
        $failureExit = $LASTEXITCODE
        [IO.File]::WriteAllText((Join-Path $output "$name.log"),$failure + "`n")
        $products = @(@($negativeExe,[IO.Path]::ChangeExtension($negativeExe,'.ll'),(Join-Path $output "$name.slg-tmp/$name.ll")) | Where-Object { Test-Path -LiteralPath $_ })
        if ($failureExit -eq 0 -or $failure -notmatch 'semantic error at' -or $failure -match '(?m)^(warning S|note N)' -or -not $failure.Contains($diagnostic,[StringComparison]::Ordinal) -or $products.Count -ne 0) { throw "Regex negative did not fail before LLVM: $name" }
        Complete-Check $name
    }
    if ($hasGolden) {
        if ((Get-FileHash -LiteralPath $golden -Algorithm SHA256).Hash -cne (Get-FileHash -LiteralPath (Join-Path $output 'actual.stdout.txt') -Algorithm SHA256).Hash) { throw 'Regex golden byte hash differs' }
        Complete-Check 'published-golden-byte-hash'
    }
    foreach ($path in $hashes.Keys) {
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $hashes[$path]) { throw "Regex input changed: $path" }
    }
    $endingStdlibFingerprint = Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root -Settings $stdlibFingerprintSettings -InputPath (Get-NativeExactOrderedSourceClosure -Root (Join-Path $root 'stdlib'))
    if ($endingStdlibFingerprint -cne $stdlibFingerprint) { throw 'Regex stdlib source closure changed during verification' }
    $record.inputsStable = $true
    Complete-Check 'input-hash-stability'
    if ($record.completed -ne $record.total) { throw 'Regex check denominator drifted' }
    $record.status='passed'
} catch { $record.status='failed'; $record.failure=$_.Exception.Message; throw }
finally { Save-Record; Write-Host "[text regex focused] $($record.status) $($record.completed)/$($record.total); $resultPath" }
