[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$fixtureId = '1735-unit-value-return-in-enum-arm'
$fixture = Join-Path $root "examples/regression/$fixtureId.slg"
$fixtureExpected = Join-Path $root "examples/regression/expected/$fixtureId.stdout.txt"
$selfhostId = '1393-selfhost-opaque-struct-diagnostics'
$selfhostManifest = Join-Path $root "examples/regression/expected/$selfhostId.sources.txt"
$selfhostExpected = Join-Path $root "examples/regression/expected/$selfhostId.stdout.txt"
$emitter = Join-Path $root 'src/Sollang.Compiler/CodeGen/LlvmEmitter.Statements.cs'
$selfhostOwnership = Join-Path $root 'selfhost/llvm/text/ownership.slg'
$output = Join-Path $root ('artifacts/scratch/unit-value-return-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($output) | Out-Null
$resultPath = Join-Path $output 'result.json'
$record = [ordered]@{
    schemaVersion = 1
    scope = 'unit-value-return-and-selfhost-llvm-text'
    status = 'running'
    completed = 0
    total = 6
    checks = @()
    inputHashes = [ordered]@{}
}

function Save-Result {
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 6) + "`n"))
}

function Complete-Check([string]$Name) {
    $record.completed++
    $record.checks += $Name
    Save-Result
}

function Invoke-Exact(
    [string]$Name,
    [string[]]$Sources,
    [string]$ExpectedPath
) {
    $product = Join-Path $output "$Name.exe"
    $actual = (& dotnet $compiler run @Sources --llvm $llvm -o $product --keep-temps 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "$Name failed: $actual" }
    $expected = [IO.File]::ReadAllText($ExpectedPath).Replace("`r`n", "`n").TrimEnd()
    if ($actual.Replace("`r`n", "`n").TrimEnd() -cne $expected) {
        throw "$Name exact output differs"
    }
    return [IO.Path]::ChangeExtension($product, '.ll')
}

try {
    foreach ($path in @($compiler, $fixture, $fixtureExpected, $selfhostManifest, $selfhostExpected, $emitter, $selfhostOwnership)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "required input is missing: $path" }
        $relative = [IO.Path]::GetRelativePath($root, $path).Replace('\', '/')
        $record.inputHashes[$relative] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }
    Complete-Check 'inputs-and-hashes'

    $emitterText = [IO.File]::ReadAllText($emitter).Replace("`r`n", "`n")
    $unitReturn = @'
        if (function.ReturnType == BoundType.Unit)
        {
            EnsureRuntimeType(value, BoundType.Unit, function.Name);
            DropOwnedLocals();
            EmitInstruction("ret void");
            return;
        }
'@
    if (-not $emitterText.Contains($unitReturn.Replace("`r`n", "`n"), [StringComparison]::Ordinal)) {
        throw 'Unit value return no longer lowers through the direct void-return path'
    }
    Complete-Check 'managed-unit-return-authority'

    $fixtureLlvm = Invoke-Exact -Name $fixtureId -Sources @($fixture) -ExpectedPath $fixtureExpected
    Complete-Check 'unit-value-return-exact-output'
    if (-not (Test-Path -LiteralPath $fixtureLlvm -PathType Leaf)) { throw 'unit return LLVM output is missing' }
    $fixtureText = [IO.File]::ReadAllText($fixtureLlvm)
    if (-not $fixtureText.Contains('define internal void @sollang_fn_finishEarly', [StringComparison]::Ordinal) -or
        -not $fixtureText.Contains('ret void', [StringComparison]::Ordinal)) {
        throw 'unit value return did not retain the void function ABI and ret void'
    }
    Complete-Check 'unit-value-return-llvm-shape'

    & (Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1') -LlvmPath $fixtureLlvm
    if (-not $?) { throw 'unit value return direct-call closure failed' }
    Complete-Check 'unit-value-return-direct-call-closure'

    $selfhostSources = @(Get-Content -LiteralPath $selfhostManifest | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { Join-Path $root $_ })
    Invoke-Exact -Name $selfhostId -Sources $selfhostSources -ExpectedPath $selfhostExpected | Out-Null
    Complete-Check 'selfhost-llvm-text-exact-output'

    $record.status = 'passed'
    Save-Result
    Write-Host "[unit value return focused] PASS $($record.completed)/$($record.total); $resultPath"
} catch {
    $record.status = 'failed'
    $record.failure = $_.Exception.Message
    Save-Result
    throw
}
