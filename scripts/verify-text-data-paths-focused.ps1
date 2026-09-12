[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$csv = Join-Path $root 'stdlib/std/text/csv.slg'
$pathModule = Join-Path $root 'stdlib/sys/path.slg'
$directoryModule = Join-Path $root 'stdlib/sys/directory.slg'
$contractPath = Join-Path $root 'scripts/contracts/text-data-paths.json'
$migrationPath = Join-Path $root 'scripts/contracts/text-data-paths-migration.json'
$probe = Join-Path $root 'scripts/probes/text-data-paths/path-security.slg'
$expected = Join-Path $root 'scripts/probes/text-data-paths/path-security.stdout.txt'
$negative = Join-Path $root 'examples/regression/diagnostics/path-private-construction.slg'
$negativeExpected = Join-Path $root 'examples/regression/diagnostics/path-private-construction.stderr.contains.txt'
$closure = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$migratedConsumers = @(
    'selfhost/cli_package_lock.slg',
    'selfhost/cli_project.slg',
    'selfhost/source_root.slg',
    'selfhost/semantic/library_imports.slg',
    'selfhost/llvm/source_root.slg',
    'examples/regression/656-selfhost-qualified-move-when-ir.slg',
    'examples/regression/683-selfhost-cli-package-lock-render.slg'
) | ForEach-Object { Join-Path $root $_ }
$scratch = Join-Path $root ('artifacts/scratch/text-data-paths-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($scratch) | Out-Null
$resultPath = Join-Path $scratch 'result.json'
$inputs = @($compiler, $csv, $pathModule, $directoryModule, $contractPath, $migrationPath, $probe, $expected, $negative, $negativeExpected, $closure, $PSCommandPath) + $migratedConsumers
$hashes = [ordered]@{}
foreach ($input in $inputs) {
    if (-not (Test-Path -LiteralPath $input -PathType Leaf)) { throw "text/path input is missing: $input" }
    $hashes[$input] = (Get-FileHash -LiteralPath $input -Algorithm SHA256).Hash
}
$record = [ordered]@{
    schemaVersion = 1
    scope = 'managed-text-data-owned-path-security'
    status = 'running'
    completed = 0
    total = 11
    artifactDirectory = $scratch
    inputHashes = $hashes
    failureIds = @()
    checks = @()
    integration = 'focused managed only; selfhost canonical-module migration and Stage2/Stage3 are pending'
}
function Write-Record {
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 10) + "`n"), [Text.UTF8Encoding]::new($false))
}
function Complete-Check([string]$Name) {
    $record.completed++
    $record.checks += $Name
    Write-Record
}
function Get-TextSha256([string]$Value) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [Convert]::ToHexString($sha.ComputeHash([Text.UTF8Encoding]::new($false).GetBytes($Value))) }
    finally { $sha.Dispose() }
}

try {
    $contract = [IO.File]::ReadAllText($contractPath) | ConvertFrom-Json
    $expectedCsv = @(
        [pscustomobject]@{ ordinal = 1; literal = "'`"'"; purpose = 'opening quote' },
        [pscustomobject]@{ ordinal = 2; literal = "'`"'"; purpose = 'closing quote' },
        [pscustomobject]@{ ordinal = 3; literal = "','"; purpose = 'field delimiter' },
        [pscustomobject]@{ ordinal = 4; literal = "'\r'"; purpose = 'CRLF carriage return' },
        [pscustomobject]@{ ordinal = 5; literal = "'\n'"; purpose = 'record line feed' }
    )
    $csvTuples = @($contract.csvCharacterWrites | ForEach-Object { "$($_.ordinal)`t$($_.literal)`t$($_.purpose)" }) -join "`n"
    $expectedCsvTuples = @($expectedCsv | ForEach-Object { "$($_.ordinal)`t$($_.literal)`t$($_.purpose)" }) -join "`n"
    if ($csvTuples -cne $expectedCsvTuples -or (Get-TextSha256 $csvTuples) -cne 'ED4535486EEC06B3D142BA0BE4A0E77101C2E609F92EF42174473FC06EDEFBE4') {
        throw 'CSV character-write tuple contract differs from the independent fixed matrix/hash'
    }
    $counts = $contract.originalDirectPathConstructionInventory
    if ($counts.total -ne 27 -or $counts.productionInternal -ne 7 -or $counts.productionExternal -ne 12 -or
        $counts.fixtureInternal -ne 6 -or $counts.fixtureExternal -ne 2) {
        throw 'original direct Path construction aggregate differs from the fixed 27-case inventory'
    }
    Complete-Check 'contract-exact-tuples-and-counts'

    $csvText = [IO.File]::ReadAllText($csv)
    $writeLiterals = @([regex]::Matches($csvText, "(?m)^\s*(?<literal>'(?:\\.|[^'])+') => output\[written!\]") | ForEach-Object { $_.Groups['literal'].Value })
    $expectedLiterals = @($expectedCsv.literal)
    if (($writeLiterals -join "`n") -cne ($expectedLiterals -join "`n") -or
        $csvText -match '(?m)^\s*(34|44|13|10) => output\[written!\]') {
        throw 'CSV output syntax is not the exact five canonical character-literal writes'
    }
    Complete-Check 'csv-canonical-character-write-surface'

    $baselineInventory = @(
        @('stdlib/sys/path.slg', 5, 'productionInternal'),
        @('selfhost/runtime/path.slg', 2, 'productionInternal'),
        @('stdlib/sys/directory.slg', 1, 'productionExternal'),
        @('selfhost/cli_package_lock.slg', 3, 'productionExternal'),
        @('selfhost/cli_project.slg', 3, 'productionExternal'),
        @('selfhost/source_root.slg', 2, 'productionExternal'),
        @('selfhost/semantic/library_imports.slg', 3, 'productionExternal'),
        @('examples/regression/424-selfhost-llvm-owned-path-module.slg', 2, 'fixtureInternal'),
        @('examples/regression/427-selfhost-llvm-native-path-map.linux-x64.slg', 1, 'fixtureInternal'),
        @('examples/regression/427-selfhost-llvm-native-path-map.slg', 1, 'fixtureInternal'),
        @('examples/regression/565-selfhost-llvm-canonical-path-info.linux-x64.slg', 1, 'fixtureInternal'),
        @('examples/regression/565-selfhost-llvm-canonical-path-info.slg', 1, 'fixtureInternal'),
        @('examples/regression/656-selfhost-qualified-move-when-ir.slg', 1, 'fixtureExternal'),
        @('examples/regression/683-selfhost-cli-package-lock-render.slg', 1, 'fixtureExternal')
    )
    $baselineText = @($baselineInventory | ForEach-Object { $_ -join "`t" }) -join "`n"
    $contractInventoryText = @($counts.files | ForEach-Object { "$($_.path)`t$($_.count)`t$($_.category)" }) -join "`n"
    if ($contractInventoryText -cne $baselineText -or
        (Get-TextSha256 $contractInventoryText) -cne 'FBD599389A48A981648C28ECF3D54C4947DFDA02A92E57F5FD09218B001273D3' -or
        (Get-TextSha256 $baselineText) -cne 'FBD599389A48A981648C28ECF3D54C4947DFDA02A92E57F5FD09218B001273D3' -or
        ($baselineInventory | ForEach-Object { $_[1] } | Measure-Object -Sum).Sum -ne 27) {
        throw 'independent original Path construction inventory/hash is not the fixed 27-case set'
    }
    Complete-Check 'original-27-construction-inventory-hash'

    $pathText = [IO.File]::ReadAllText($pathModule)
    if ($pathText -notmatch 'public struct Path\s*\{\s*bytes: \[UInt8; ~\]\s*style: Style' -or
        $pathText -notmatch 'public fromBytes value: move \[UInt8; ~\], style: Style -> Result<Path, Text>' -or
        $pathText -notmatch 'public containsLexically: self, candidate: ref Path -> Result<Bool, Text>' -or
        $pathText -notmatch 'public containsResolved: self, candidate: ref Path -> Result<Bool, Text> uses File') {
        throw 'owned Path privacy, validated factory, or lexical containment surface is missing'
    }
    $directoryText = [IO.File]::ReadAllText($directoryModule)
    $remainingExternalForges = @($migratedConsumers | Where-Object { [IO.File]::ReadAllText($_) -match 'path\.Path \{ bytes:' })
    if ($directoryText -match 'path\.Path \{ bytes:' -or $remainingExternalForges.Count -ne 0) {
        throw 'conflict-free external Path consumers still forge private state'
    }
    $negativeForgeCount = ([regex]::Matches([IO.File]::ReadAllText($negative), 'path\.Path \{ bytes:')).Count
    if ($negativeForgeCount -ne 1) { throw 'the single retained external Path forgery negative changed' }
    Complete-Check 'private-state-and-consumer-migration-surface'

    & (Join-Path $root 'scripts/format-authoritative-slg.ps1') -Check -Source (@($csv, $pathModule, $directoryModule, $probe, $negative) + $migratedConsumers)
    Complete-Check 'authoritative-format'

    $exe = Join-Path $scratch 'path-security.exe'
    $runLog = Join-Path $scratch 'run.log'
    $output = (& dotnet $compiler run $probe --llvm $llvm -o $exe --keep-temps 2>&1) -join "`n"
    $exitCode = $LASTEXITCODE
    [IO.File]::WriteAllText($runLog, $output + "`n", [Text.UTF8Encoding]::new($false))
    if ($exitCode -ne 0 -or $output -match '(?m)^warning\s' -or -not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        throw "path security warning-free native execution failed (exit $exitCode): $output"
    }
    $actual = $output.Replace("`r`n", "`n").TrimEnd()
    $expectedText = [IO.File]::ReadAllText($expected).Replace("`r`n", "`n").TrimEnd()
    if ($actual -cne $expectedText) { throw 'path security stdout differs from the exact expected output' }
    $record.outputLineCount = ($actual -split "`n").Count
    $record.executableSha256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
    Complete-Check 'warning-free-native-exact-output'

    $ir = [IO.Path]::ChangeExtension($exe, '.ll')
    & (Join-Path $llvm 'bin/llvm-as.exe') $ir -o ([IO.Path]::ChangeExtension($exe, '.bc'))
    if ($LASTEXITCODE -ne 0) { throw 'path security LLVM assembly failed' }
    & $closure -LlvmPath $ir
    $record.llvmSha256 = (Get-FileHash -LiteralPath $ir -Algorithm SHA256).Hash
    Complete-Check 'llvm-assembly-and-direct-call-closure'

    $negativeExe = Join-Path $scratch 'private-construction.exe'
    $failure = (& dotnet $compiler build $negative --llvm $llvm -o $negativeExe --keep-temps 2>&1) -join "`n"
    $failureExit = $LASTEXITCODE
    [IO.File]::WriteAllText((Join-Path $scratch 'negative.log'), $failure + "`n", [Text.UTF8Encoding]::new($false))
    $diagnostic = ([IO.File]::ReadAllText($negativeExpected)).Trim()
    $negativeProducts = @(@($negativeExe, [IO.Path]::ChangeExtension($negativeExe, '.ll'),
        (Join-Path $scratch 'private-construction.slg-tmp/private-construction.ll')) | Where-Object { Test-Path -LiteralPath $_ })
    if ($failureExit -eq 0 -or $failure -notmatch 'semantic error' -or
        -not $failure.Contains($diagnostic, [StringComparison]::Ordinal) -or $negativeProducts.Count -ne 0) {
        throw 'private Path construction did not fail pre-LLVM with the exact diagnostic'
    }
    Complete-Check 'private-construction-pre-llvm-negative'

    $migration = [IO.File]::ReadAllText($migrationPath) | ConvertFrom-Json
    $expectedBlockers = @('stdlib-canonical-module', 'selfhost-owned-path-runtime-parity', 'symlink-aware-containment', 'browser-path-capability')
    $expectedStates = @('blocked', 'blocked', 'partial', 'blocked')
    if ((@($migration.blockers.id) -join "`n") -cne ($expectedBlockers -join "`n") -or
        (@($migration.blockers.state) -join "`n") -cne ($expectedStates -join "`n") -or
        ($migration.blockers | Where-Object id -eq 'browser-path-capability').forbiddenFallback -cne 'io') {
        throw 'required compiler/selfhost, symlink, or browser capability blocker manifest changed'
    }
    Complete-Check 'deferred-boundary-manifest'

    foreach ($input in $hashes.Keys) {
        if ((Get-FileHash -LiteralPath $input -Algorithm SHA256).Hash -cne $hashes[$input]) {
            throw "text/path verification input changed during execution: $input"
        }
    }
    $record.inputsStable = $true
    Complete-Check 'input-hash-stability'

    $ownedPaths = (@($csv, $pathModule, $directoryModule, $contractPath, $migrationPath, $probe, $expected, $negative, $negativeExpected, $PSCommandPath) + $migratedConsumers) |
        ForEach-Object { [IO.Path]::GetRelativePath($root, $_).Replace('\', '/') }
    $diffOutput = (& git -C $root diff --check -- @ownedPaths 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "git diff --check failed: $diffOutput" }
    Complete-Check 'owned-diff-check'

    if ($record.completed -ne $record.total) { throw 'text/path focused denominator differs from the fixed total' }
    $record.status = 'passed'
} catch {
    $record.status = 'failed'
    $record.failureIds = @('TEXT_PATH_FOCUSED_FAILED')
    $record.failure = $_.Exception.Message
    throw
} finally {
    Write-Record
    Write-Host "[text data paths focused] $($record.status) $($record.completed)/$($record.total); $resultPath"
}
