[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Stage1Compiler,
    [Parameter(Mandatory)][string]$Stage2Compiler,
    [Parameter(Mandatory)][string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$stage1 = (Resolve-Path -LiteralPath $Stage1Compiler).Path
$stage2 = (Resolve-Path -LiteralPath $Stage2Compiler).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($output) | Out-Null
$fixture = Join-Path $root 'tests/Sollang.ExampleTests/Fixtures/selfhost-stage2-interpolation-len.slg'
$llvmAs = Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe'
$resultPath = Join-Path $output 'result.json'
$failureIds = [Collections.Generic.List[string]]::new()
$completed = 0
$total = 3

function Get-NormalizedHash([string]$Path) {
    $text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text)))
}

function Save-Result([string]$Status, [int]$ExitCode) {
    $inputs = @($fixture, $stage1, $stage2, $PSCommandPath)
    $fingerprintText = ($inputs | ForEach-Object {
        "$([IO.Path]::GetRelativePath($root, $_).Replace('\', '/'))=$((Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash)"
    }) -join "`n"
    $record = [ordered]@{
        schemaVersion = 1
        defectId = 'C2026-09-22-463'
        status = $Status
        completed = $completed
        total = $total
        exitCode = $ExitCode
        failureIds = @($failureIds)
        orphanProcessIds = @()
        inputFingerprint = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($fingerprintText)))
        stage1CompilerSha256 = (Get-FileHash -LiteralPath $stage1 -Algorithm SHA256).Hash
        stage2CompilerSha256 = (Get-FileHash -LiteralPath $stage2 -Algorithm SHA256).Hash
        normalizedLlvmSha256 = if ($completed -ge 2) { Get-NormalizedHash (Join-Path $output 'stage2.ll') } else { $null }
    }
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 5) + "`n"), [Text.UTF8Encoding]::new($false))
}

try {
    foreach ($path in @($fixture, $llvmAs)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C463 required input is missing: $path" }
    }
    $fixtureText = [IO.File]::ReadAllText($fixture)
    if ($fixtureText.Contains('"materialized=$count" => message', [StringComparison]::Ordinal) -or
        -not $fixtureText.Contains('"materialized=$count" -> materialize(storage!) -> println', [StringComparison]::Ordinal)) {
        throw 'C463 fixture does not directly materialize the deferred interpolation before storage'
    }
    $completed++

    foreach ($entry in @(
        @{ Name = 'stage1'; Compiler = $stage1 },
        @{ Name = 'stage2'; Compiler = $stage2 })) {
        Invoke-VerificationProcessToFile -FilePath $entry.Compiler `
            -ArgumentList @('windows', $fixture) `
            -Description "C463 $($entry.Name) interpolation length emission" `
            -OutputPath (Join-Path $output "$($entry.Name).ll") `
            -ErrorPath (Join-Path $output "$($entry.Name).err") `
            -TimeoutMilliseconds 300000
        if ((Get-Item -LiteralPath (Join-Path $output "$($entry.Name).err")).Length -ne 0) {
            throw "C463 $($entry.Name) emitted diagnostics"
        }
    }
    $stage1Hash = Get-NormalizedHash (Join-Path $output 'stage1.ll')
    $stage2Hash = Get-NormalizedHash (Join-Path $output 'stage2.ll')
    if ($stage1Hash -cne $stage2Hash) { throw "C463 normalized LLVM differs: stage1=$stage1Hash stage2=$stage2Hash" }
    $completed++

    foreach ($name in @('stage1', 'stage2')) {
        $llvmPath = Join-Path $output "$name.ll"
        & (Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1') -LlvmPath $llvmPath
        & $llvmAs $llvmPath -o (Join-Path $output "$name.bc")
        if ($LASTEXITCODE -ne 0) { throw "C463 $name llvm-as failed" }
    }
    $completed++

    Save-Result 'passed' 0
    Write-Host "[C463] PASS $completed/$total direct materialization and exact Stage1/Stage2 interpolation-length LLVM."
} catch {
    $failureIds.Add('C463_GATE_FAILED')
    Save-Result 'failed' 1
    throw
}
