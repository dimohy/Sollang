[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot), [switch]$AllowMissingGolden)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'llvm-no-allocation-audit.ps1')
. (Join-Path $PSScriptRoot 'native-exact-fixture-receipt.ps1')
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$module = Join-Path $root 'stdlib/std/text/glob.slg'
$fixture = Join-Path $root 'examples/regression/1728-glob-bounded-pattern.slg'
$golden = Join-Path $root 'examples/regression/expected/1728-glob-bounded-pattern.stdout.txt'
$contractPath = Join-Path $root 'scripts/contracts/text-glob.json'
$schemaPath = Join-Path $root 'scripts/contracts/text-glob.schema.json'
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$output = Join-Path $root ('artifacts/scratch/text-glob-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($output)
$resultPath = Join-Path $output 'result.json'
$hasGolden = Test-Path -LiteralPath $golden -PathType Leaf
if (-not $hasGolden -and -not $AllowMissingGolden) { throw 'Glob golden is not published; use explicit pre-publication mode' }
$negativeNames = @('glob-source-escape','glob-private-state')
$inputs = @($compiler,$module,$fixture,$contractPath,$schemaPath,$PSCommandPath,
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
$stdlibFingerprintSettings = [ordered]@{ platform = 'windows'; scope = '1728-text-glob-stdlib' }
$stdlibFingerprint = Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root -Settings $stdlibFingerprintSettings -InputPath $stdlibSources
$record = [ordered]@{schemaVersion=1;status='running';scope='managed-windows-bounded-simple-glob';completed=0;total=$(if($hasGolden){10}else{9});inputHashes=$hashes;stdlibSourceCount=$stdlibSources.Count;stdlibSourceFingerprint=$stdlibFingerprint;checks=@();integration='selfhost and Stage deferred'}
function Save-Record { [IO.File]::WriteAllText($resultPath,(($record | ConvertTo-Json -Depth 8) + "`n")) }
function Complete-Check([string]$Name) { $record.completed++; $record.checks += $Name; Save-Record }
try {
    Save-Record
    $contractText = [IO.File]::ReadAllText($contractPath)
    if (-not (Test-Json -Json $contractText -SchemaFile $schemaPath)) { throw 'Glob contract/schema mismatch' }
    $contract = $contractText | ConvertFrom-Json
    if (@($contract.referenceCases.label | Sort-Object -Unique).Count -ne $contract.referenceCases.Count) { throw 'Glob reference labels are not unique' }
    if ($contract.referenceCases.Count -ne $contract.referenceCaseCount -or
        $contract.boundaryLines.Count -ne $contract.boundaryLineCount) {
        throw 'Glob contract case denominator drifted'
    }
    Complete-Check 'contract-schema'
    # Independent reference: a Rune-token dynamic-programming table, not the
    # production last-star retry state machine. Only the verifier allocates it.
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Text;
public static class GlobRuneReference {
    public static bool Match(string pattern, string input) {
        var tokens = new List<(int Kind, Rune Value)>();
        var source = new List<Rune>();
        foreach (Rune rune in pattern.EnumerateRunes()) source.Add(rune);
        for (int i = 0; i < source.Count; i++) {
            int value = source[i].Value;
            if (value == 92) {
                if (++i >= source.Count || (source[i].Value != 42 && source[i].Value != 63 && source[i].Value != 92))
                    throw new ArgumentException("Invalid reference escape");
                tokens.Add((0, source[i]));
            } else tokens.Add((value == 42 ? 1 : value == 63 ? 2 : 0, source[i]));
        }
        var text = new List<Rune>();
        foreach (Rune rune in input.EnumerateRunes()) text.Add(rune);
        var table = new bool[tokens.Count + 1, text.Count + 1];
        table[0, 0] = true;
        for (int p = 1; p <= tokens.Count; p++) {
            var token = tokens[p - 1];
            if (token.Kind == 1) table[p, 0] = table[p - 1, 0];
            for (int t = 1; t <= text.Count; t++)
                table[p, t] = token.Kind == 1
                    ? table[p - 1, t] || table[p, t - 1]
                    : table[p - 1, t - 1] && (token.Kind == 2 || token.Value == text[t - 1]);
        }
        return table[tokens.Count, text.Count];
    }
}
'@
    $expected = [Collections.Generic.List[string]]::new()
    foreach ($case in $contract.referenceCases) {
        $matched = [GlobRuneReference]::Match([string]$case.pattern,[string]$case.input)
        if ($matched -ne $case.match) { throw "Independent reference contradicts contract: $($case.label)" }
        $expected.Add("$($case.label)=$($matched.ToString().ToLowerInvariant())")
    }
    foreach ($line in $contract.boundaryLines) { $expected.Add($line) }
    $expectedText = ($expected -join "`n") + "`n"
    [IO.File]::WriteAllText((Join-Path $output 'reference.stdout.txt'),$expectedText)
    $record.referenceCaseCount = $contract.referenceCases.Count
    $record.boundaryLineCount = $contract.boundaryLines.Count
    Complete-Check 'independent-rune-dp-reference'
    $formatSources = @($module,$fixture) + @($negativeNames | ForEach-Object { Join-Path $root "examples/regression/diagnostics/$_.slg" })
    & (Join-Path $PSScriptRoot 'format-authoritative-slg.ps1') -Check -Source $formatSources
    Complete-Check 'focused-authoritative-format'
    $exe = Join-Path $output 'glob.exe'
    $actual = (& dotnet $compiler run $fixture --llvm $llvm -o $exe --keep-temps -O0 2>&1) -join "`n"
    $exitCode = $LASTEXITCODE
    [IO.File]::WriteAllText((Join-Path $output 'run.log'),$actual + "`n")
    if ($exitCode -ne 0 -or $actual -match '(?m)^(warning S|note N)' -or -not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw "Glob native execution failed: $actual" }
    $actualText = $actual.Replace("`r`n","`n").TrimEnd("`n") + "`n"
    if ($actualText -cne $expectedText) { throw 'Glob native output differs from independent cases or fixed boundary observations' }
    [IO.File]::WriteAllText((Join-Path $output 'actual.stdout.txt'),$actualText,[Text.UTF8Encoding]::new($false))
    $record.executableSha256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
    Complete-Check 'warning-free-native-exact-output'
    $ir = [IO.Path]::ChangeExtension($exe,'.ll')
    & (Join-Path $llvm 'bin/llvm-as.exe') $ir -o ([IO.Path]::ChangeExtension($exe,'.bc'))
    if ($LASTEXITCODE -ne 0) { throw 'Glob LLVM assembly failed' }
    & (Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1') -LlvmPath $ir
    Complete-Check 'llvm-assembly-and-closure'
    $audit = Assert-LlvmNoAllocation -LlvmText ([IO.File]::ReadAllText($ir)) -RootSymbolPattern '^sollang_fn_std_text_glob_' -AllowedExternalSymbols @('GetStdHandle','WriteFile','llvm.trap')
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
        if ($failureExit -eq 0 -or $failure -notmatch 'semantic error at' -or $failure -match '(?m)^(warning S|note N)' -or -not $failure.Contains($diagnostic,[StringComparison]::Ordinal) -or $products.Count -ne 0) { throw "Glob negative did not fail before LLVM: $name" }
        Complete-Check $name
    }
    if ($hasGolden) {
        if ((Get-FileHash -LiteralPath $golden -Algorithm SHA256).Hash -cne (Get-FileHash -LiteralPath (Join-Path $output 'actual.stdout.txt') -Algorithm SHA256).Hash) { throw 'Glob golden byte hash differs' }
        Complete-Check 'published-golden-byte-hash'
    }
    foreach ($path in $hashes.Keys) {
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $hashes[$path]) { throw "Glob input changed: $path" }
    }
    $endingStdlibFingerprint = Get-NativeExactFixtureInputFingerprint -RepositoryRoot $root -Settings $stdlibFingerprintSettings -InputPath (Get-NativeExactOrderedSourceClosure -Root (Join-Path $root 'stdlib'))
    if ($endingStdlibFingerprint -cne $stdlibFingerprint) { throw 'Glob stdlib source closure changed during verification' }
    $record.inputsStable = $true
    Complete-Check 'input-hash-stability'
    if ($record.completed -ne $record.total) { throw 'Glob check denominator drifted' }
    $record.status='passed'
} catch { $record.status='failed'; $record.failure=$_.Exception.Message; throw }
finally { Save-Record; Write-Host "[text glob focused] $($record.status) $($record.completed)/$($record.total); $resultPath" }
