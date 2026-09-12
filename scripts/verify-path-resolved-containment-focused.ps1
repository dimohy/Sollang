[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$module = Join-Path $root 'stdlib/sys/path.slg'
$probe = Join-Path $root 'scripts/probes/text-data-paths/resolved-containment.slg'
$expected = Join-Path $root 'scripts/probes/text-data-paths/resolved-containment.stdout.txt'
$scratch = Join-Path $root ('artifacts/scratch/path-resolved-containment-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($scratch) | Out-Null
$resultPath = Join-Path $scratch 'result.json'
$inputs = @($compiler, $module, $probe, $expected, $PSCommandPath)
$hashes = [ordered]@{}
foreach ($input in $inputs) {
    if (-not (Test-Path -LiteralPath $input -PathType Leaf)) { throw "resolved-containment input is missing: $input" }
    $hashes[$input] = (Get-FileHash -LiteralPath $input -Algorithm SHA256).Hash
}
$record = [ordered]@{
    schemaVersion = 1
    scope = 'managed-windows-canonical-query-snapshot-containment'
    status = 'running'
    completed = 0
    total = 5
    artifactDirectory = $scratch
    inputHashes = $hashes
    failureIds = @()
    checks = @()
    limitation = 'snapshot check only; handle-relative race-free open remains pending'
}
function Write-Record {
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
}
function Complete-Check([string]$Name) {
    $record.completed++
    $record.checks += $Name
    Write-Record
}

try {
    & (Join-Path $root 'scripts/format-authoritative-slg.ps1') -Check -Source @($module, $probe)
    Complete-Check 'authoritative-format'
    $moduleText = [IO.File]::ReadAllText($module)
    if ($moduleText -notmatch 'public containsResolved: self, candidate: ref Path -> Result<Bool, Text> uses File' -or
        $moduleText -notmatch 'rootQueried -> normalizeResolvedCanonical\? => rootCanonical' -or
        $moduleText -notmatch 'candidateQueried -> normalizeResolvedCanonical\? => candidateCanonical' -or
        $moduleText -notmatch 'rootCanonical -> containsLexically\(candidateCanonical\)') {
        throw 'resolved containment does not compose canonical query with component-boundary lexical containment'
    }
    Complete-Check 'canonical-query-composition'

    $exe = Join-Path $scratch 'resolved-containment.exe'
    $build = (& dotnet $compiler build $probe --llvm $llvm -o $exe --keep-temps 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $build -match '(?m)^warning\s' -or -not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        throw "resolved containment build failed: $build"
    }
    $rootDirectory = Join-Path $scratch 'root'
    $outsideDirectory = Join-Path $scratch 'outside'
    [IO.Directory]::CreateDirectory((Join-Path $rootDirectory 'child')) | Out-Null
    [IO.Directory]::CreateDirectory($outsideDirectory) | Out-Null
    New-Item -ItemType Junction -Path (Join-Path $rootDirectory 'escape') -Target $outsideDirectory | Out-Null
    Push-Location $scratch
    try { $actual = (& $exe 2>&1) -join "`n"; $exitCode = $LASTEXITCODE }
    finally { Pop-Location }
    if ($exitCode -ne 0 -or $actual.Replace("`r`n", "`n").TrimEnd() -cne
        ([IO.File]::ReadAllText($expected).Replace("`r`n", "`n").TrimEnd())) {
        throw "resolved containment exact output failed (exit $exitCode): $actual"
    }
    Complete-Check 'real-child-and-junction-exact-output'
    & (Join-Path $llvm 'bin/llvm-as.exe') ([IO.Path]::ChangeExtension($exe, '.ll')) -o ([IO.Path]::ChangeExtension($exe, '.bc'))
    if ($LASTEXITCODE -ne 0) { throw 'resolved containment LLVM assembly failed' }
    & (Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1') -LlvmPath ([IO.Path]::ChangeExtension($exe, '.ll'))
    Complete-Check 'llvm-assembly-and-direct-call-closure'
    foreach ($input in $hashes.Keys) {
        if ((Get-FileHash -LiteralPath $input -Algorithm SHA256).Hash -cne $hashes[$input]) {
            throw "resolved containment input changed during execution: $input"
        }
    }
    $record.inputsStable = $true
    Complete-Check 'input-hash-stability'
    if ($record.completed -ne $record.total) { throw 'resolved containment denominator differs from fixed total' }
    $record.status = 'passed'
} catch {
    $record.status = 'failed'
    $record.failureIds = @('RESOLVED_CONTAINMENT_FAILED')
    $record.failure = $_.Exception.Message
    throw
} finally {
    Write-Record
    Write-Host "[path resolved containment] $($record.status) $($record.completed)/$($record.total); $resultPath"
}
