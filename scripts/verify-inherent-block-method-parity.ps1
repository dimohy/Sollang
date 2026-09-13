[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$CompilerAssembly,
    [string]$OutputDirectory,
    [switch]$RunManaged
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repo = [IO.Path]::GetFullPath($RepositoryRoot)
$contractPath = Join-Path $repo 'scripts/contracts/inherent-block-method-parity.json'
$schemaPath = Join-Path $repo 'scripts/contracts/inherent-block-method-parity.schema.json'
$compiler = if ([string]::IsNullOrWhiteSpace($CompilerAssembly)) {
    Join-Path $repo 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
} else {
    [IO.Path]::GetFullPath($CompilerAssembly)
}
$llvm = Join-Path $repo '.tools/llvm-22.1.8'
$output = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    Join-Path $repo ('artifacts/scratch/inherent-block-method-parity/' + [guid]::NewGuid().ToString('N'))
} else {
    [IO.Path]::GetFullPath($OutputDirectory)
}

function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Normalize([string]$Value) { $Value.Replace("`r`n", "`n").TrimEnd() }
function Assert-ExactSet([object[]]$Actual, [string[]]$Expected, [string]$Name) {
    $values = @($Actual | ForEach-Object { [string]$_ })
    if ($values.Count -ne $Expected.Count -or
        @($values | Sort-Object -Unique).Count -ne $Expected.Count -or
        @(Compare-Object ($Expected | Sort-Object) ($values | Sort-Object)).Count -ne 0) {
        throw "$Name must retain the exact unique authority set"
    }
}

$contractJson = Get-Content -LiteralPath $contractPath -Raw
if (-not ($contractJson | Test-Json -SchemaFile $schemaPath)) {
    throw 'inherent block-method parity contract schema validation failed'
}
$contract = $contractJson | ConvertFrom-Json
$expectedCases = @('P1', 'N1', 'N2', 'N3')
$cases = @($contract.positive) + @($contract.negative)
Assert-ExactSet @($cases | ForEach-Object id) $expectedCases 'inherent block-method cases'

$paths = [ordered]@{
    contract = $contractPath
    schema = $schemaPath
    verifier = [IO.Path]::GetFullPath($PSCommandPath)
    selfhostResolution = Join-Path $repo $contract.selfhostImplementation.resolutionSource
    selfhostSpecialization = Join-Path $repo $contract.selfhostImplementation.specializationSource
}
foreach ($case in $cases) {
    $paths["source:$($case.id)"] = Join-Path $repo $case.source
    $paths["expected:$($case.id)"] = Join-Path $repo $case.expected
}
foreach ($entry in $paths.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $entry.Value -PathType Leaf)) { throw "missing authority input: $($entry.Value)" }
}
$hashes = [ordered]@{}
foreach ($entry in $paths.GetEnumerator()) { $hashes[$entry.Key] = Hash $entry.Value }

$positiveSource = Get-Content -LiteralPath $paths['source:P1'] -Raw
if ([regex]::Matches($positiveSource, '(?m)^\s*partitionPoint<T>: self, values: \[T\] -> Int block item: ref T -> Bool \{').Count -ne 2 -or
    $positiveSource -cnotmatch 'values\[middle\] -> yield => inPrefix' -or
    $positiveSource -cnotmatch 'algorithms -> partitionPoint\(values!\) entry \{' -or
    $positiveSource -cnotmatch 'struct OwnedEntry \{ key: Int, payload: box Int \}') {
    throw 'positive reducer lost exact-owner collision, declared ref T role, yield, or noncopyable ownership evidence'
}
if ($positiveSource -match '(?m)^(?:public\s+)?partitionPoint<T>') {
    throw 'positive reducer must not introduce a top-level global fallback'
}
$wrongOwnerSource = Get-Content -LiteralPath $paths['source:N1'] -Raw
if ($wrongOwnerSource -cnotmatch 'left -> RightAlgorithms\.partitionPoint\(values\)') {
    throw 'N1 must retain an explicitly wrong receiver owner'
}
$declaredRoleSource = Get-Content -LiteralPath $paths['source:N2'] -Raw
if ($declaredRoleSource -cnotmatch 'block item: ref T -> Bool' -or $declaredRoleSource -cnotmatch 'self -> yield') {
    throw 'N2 must distinguish self from the declared callback role'
}
$callbackResultSource = Get-Content -LiteralPath $paths['source:N3'] -Raw
if ($callbackResultSource -cnotmatch 'block item: ref T -> Bool' -or $callbackResultSource -cnotmatch 'item \+ 1') {
    throw 'N3 must retain a typed callback result mismatch'
}

$selfhostResolution = Get-Content -LiteralPath $paths.selfhostResolution -Raw
if ($selfhostResolution -cnotmatch 'localCallNode\.kind == 10\s+or localCallNode\.kind == 48\s+or dottedDirectReceiver!' -or
    $selfhostResolution -cnotmatch 'localCallNode\.kind != 48\s+or receiverMethod\.blockNameToken >= 0' -or
    $selfhostResolution -cnotmatch 'qualifiedInherentBlockMethod! -> if \{' -or
    $selfhostResolution -cnotmatch 'resolvedFunctionSymbol! != qualifiedBlockTarget\.targetSymbol') {
    throw 'selfhost block calls must share exact nominal receiver lookup and reject non-block or wrong-owner methods'
}
$selfhostSpecialization = Get-Content -LiteralPath $paths.selfhostSpecialization -Raw
if ($selfhostSpecialization -cnotmatch 'roleFunction\.kind == 31 -> if \{' -or
    $selfhostSpecialization -cnotmatch 'roleParameter\.astNode != roleFunction\.astNode' -or
    $selfhostSpecialization -cnotmatch 'roleParameter\.typeNode => roleInputTypeAst!' -or
    $selfhostSpecialization -cnotmatch 'roleFunction\.kind == 31\s+and roleSourceAfterTarget') {
    throw 'selfhost inherent block methods must specialize the declared explicit input, never self'
}

$formatSources = @($cases | ForEach-Object { $paths["source:$($_.id)"] })
$formatSources += @($paths.selfhostResolution, $paths.selfhostSpecialization)
& (Join-Path $repo 'scripts/format-authoritative-slg.ps1') -Check -Source $formatSources
if ($LASTEXITCODE -ne 0) { throw 'inherent block-method reducer format check failed' }
foreach ($entry in $paths.GetEnumerator()) {
    if ((Hash $entry.Value) -cne $hashes[$entry.Key]) { throw "authority input drifted during static verification: $($entry.Key)" }
}

if (-not $RunManaged) {
    Write-Host '[inherent block-method parity] PREPARED static 4/4; managed 0/4 not run'
    return
}

if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) { throw "managed compiler missing: $compiler" }
$compilerHash = Hash $compiler
New-Item -ItemType Directory -Path $output -Force | Out-Null
$results = @()
foreach ($case in $cases) {
    $source = $paths["source:$($case.id)"]
    $expectedPath = $paths["expected:$($case.id)"]
    $executable = Join-Path $output "$($case.id).exe"
    $irPath = [IO.Path]::ChangeExtension($executable, '.ll')
    $bcPath = [IO.Path]::ChangeExtension($executable, '.bc')
    if ($case.id -eq 'P1') {
        $actual = (& dotnet $compiler run $source --llvm $llvm -o $executable --keep-temps 2>&1) -join "`n"
        if ($LASTEXITCODE -ne 0 -or (Normalize $actual) -cne (Normalize (Get-Content -LiteralPath $expectedPath -Raw))) {
            throw "P1 did not resolve the exact receiver and declared ref T callback role: $actual"
        }
        $assembly = (& (Join-Path $llvm 'bin/llvm-as.exe') $irPath -o $bcPath 2>&1) -join "`n"
        if ($LASTEXITCODE -ne 0 -or -not [string]::IsNullOrWhiteSpace($assembly)) { throw "P1 LLVM assembly failed: $assembly" }
        & (Join-Path $repo 'scripts/verify-llvm-direct-call-closure.ps1') -LlvmPath $irPath
        $results += [ordered]@{ id = 'P1'; status = 'passed'; exactReceiverOwner = 'LeftAlgorithms'; callbackInput = 'ref OwnedEntry' }
        continue
    }
    $actual = (& dotnet $compiler build $source --llvm $llvm -o $executable 2>&1) -join "`n"
    $lines = @($actual.Replace("`r`n", "`n") -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $expected = (Get-Content -LiteralPath $expectedPath -Raw).Trim()
    if ($LASTEXITCODE -eq 0 -or $lines.Count -ne 1 -or
        -not $lines[0].Contains($expected, [StringComparison]::Ordinal) -or
        (Test-Path -LiteralPath $executable) -or (Test-Path -LiteralPath $irPath) -or (Test-Path -LiteralPath $bcPath)) {
        throw "$($case.id) did not fail early with its one required diagnostic: $actual"
    }
    $results += [ordered]@{ id = $case.id; status = 'passed'; diagnostic = $expected }
}
foreach ($entry in $paths.GetEnumerator()) {
    if ((Hash $entry.Value) -cne $hashes[$entry.Key]) { throw "authority input drifted during managed verification: $($entry.Key)" }
}
if ((Hash $compiler) -cne $compilerHash) { throw 'managed compiler drifted during focused verification' }
$record = [ordered]@{
    schemaVersion = 1
    status = 'passed'
    completed = @($results | Where-Object status -eq 'passed').Count
    total = 4
    compilerSha256 = $compilerHash
    inputHashes = $hashes
    cases = $results
    failureIds = @()
}
$resultPath = Join-Path $output 'result.json'
[IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
Write-Host "[inherent block-method parity] PASS 4/4 result=$resultPath"
