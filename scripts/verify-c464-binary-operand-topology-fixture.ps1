[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Stage1Compiler,
    [Parameter(Mandatory)][string]$Stage2Compiler,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateRange(1, 16)][int]$Jobs = 8
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($output) | Out-Null
$resultPath = Join-Path $output 'result.json'
$fixture = '1396-selfhost-binary-operand-topology'
$fixturePath = Join-Path $root "examples/regression/$fixture.slg"
$expectedPath = Join-Path $root "examples/regression/expected/$fixture.stdout.txt"
$manifestPath = Join-Path $root "examples/regression/expected/$fixture.sources.txt"
$grammarPath = Join-Path $root 'syntax/generated/sollang_grammar.slg'
$stage1 = (Resolve-Path -LiteralPath $Stage1Compiler).Path
$stage2 = (Resolve-Path -LiteralPath $Stage2Compiler).Path
$completed = 0
$total = 3
$failureIds = [Collections.Generic.List[string]]::new()

function Save-Result([string]$Status, [int]$ExitCode) {
    $inputs = @($fixturePath, $expectedPath, $manifestPath, $grammarPath, $stage1, $stage2)
    $inputHashes = [ordered]@{}
    $fingerprintLines = foreach ($path in $inputs) {
        $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/')
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        $inputHashes[$relative] = $hash
        "$relative=$hash"
    }
    $fingerprint = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData(
        [Text.Encoding]::UTF8.GetBytes(($fingerprintLines -join "`n"))))
    $record = [ordered]@{
        schemaVersion = 1
        defectId = 'C2026-09-23-464'
        status = $Status
        completed = $completed
        total = $total
        exitCode = $ExitCode
        failureIds = @($failureIds)
        orphanProcessIds = @()
        inputFingerprint = $fingerprint
        inputHashes = $inputHashes
        stage1CompilerSha256 = $inputHashes[[IO.Path]::GetRelativePath($root, $stage1).Replace('\', '/')]
        stage2CompilerSha256 = $inputHashes[[IO.Path]::GetRelativePath($root, $stage2).Replace('\', '/')]
    }
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 6) + "`n"), [Text.UTF8Encoding]::new($false))
}

try {
    & (Join-Path $PSScriptRoot 'format-authoritative-slg.ps1') -Check -Source @($fixturePath)
    if ($LASTEXITCODE -ne 0) { throw 'C464 fixture format failed' }
    $fixtureText = [IO.File]::ReadAllText($fixturePath)
    foreach ($required in @(
        'import syntax.generated.slg as grammar',
        'node.opcode == grammar.tokenIdPlus()',
        'ir[node.operand1].opcode == grammar.tokenIdPercent()')) {
        if (-not $fixtureText.Contains($required, [StringComparison]::Ordinal)) {
            throw "C464 fixture does not use the grammar authority: $required"
        }
    }
    if ($fixtureText.Contains('node.opcode == 14', [StringComparison]::Ordinal) -or
        $fixtureText.Contains('ir[node.operand1].opcode == 18', [StringComparison]::Ordinal)) {
        throw 'C464 fixture retains stale binary opcode magic numbers'
    }
    $completed++

    foreach ($generation in @(
        [ordered]@{ Label = 'c464-stage1'; Compiler = $stage1; Directory = 'stage1' },
        [ordered]@{ Label = 'c464-stage2'; Compiler = $stage2; Directory = 'stage2' })) {
        & (Join-Path $PSScriptRoot 'verify-native-exact-fixture.ps1') `
            -Compiler $generation.Compiler -Label $generation.Label -Fixture $fixture `
            -Platform windows -LlvmRoot (Join-Path $root '.tools/llvm-22.1.8') `
            -StdlibRoot (Join-Path $root 'stdlib') -RepositoryRoot $root `
            -OutputDirectory (Join-Path $output $generation.Directory) -Jobs $Jobs
        if ($LASTEXITCODE -ne 0) { throw "C464 $($generation.Label) exact fixture failed" }
        $completed++
    }

    Save-Result 'passed' 0
    Write-Host "[C464] PASS $completed/$total grammar-owned binary operand topology fixture."
} catch {
    $failureIds.Add('C464_GATE_FAILED')
    Save-Result 'failed' 1
    throw
}
