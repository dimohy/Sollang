[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory)][string]$CandidateCompiler,
    [ValidateSet('C417', 'C418', 'All')][string]$Case = 'All'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$candidate = [IO.Path]::GetFullPath($CandidateCompiler)
$managed = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$llvmAs = Join-Path $llvm 'bin/llvm-as.exe'
$clang = Join-Path $llvm 'bin/clang.exe'
$output = Join-Path $root ('artifacts/scratch/selfhost-call-topology-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($output)

foreach ($path in @($candidate, $managed, $llvmAs, $clang)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "missing focused verifier input: $path" }
}

$cases = @(
    [pscustomobject]@{
        Id = 'C417'
        DefectId = 'C417'
        RequireResolvedCalls = $true
        Source = 'scripts/contracts/fixtures/c417-instance-method-additional-arguments.slg'
        Expected = 'scripts/contracts/fixtures/c417-instance-method-additional-arguments.stdout.txt'
    },
    [pscustomobject]@{
        Id = 'C417-arity-controls'
        DefectId = 'C417'
        RequireResolvedCalls = $true
        Source = 'scripts/contracts/fixtures/c417-instance-method-arity-controls.slg'
        Expected = 'scripts/contracts/fixtures/c417-instance-method-arity-controls.stdout.txt'
    },
    [pscustomobject]@{
        Id = 'C418'
        DefectId = 'C418'
        RequireResolvedCalls = $false
        Source = 'scripts/contracts/fixtures/c418-direct-owned-async-await.slg'
        Expected = 'scripts/contracts/fixtures/c418-direct-owned-async-await.stdout.txt'
    }
)
if ($Case -ne 'All') { $cases = @($cases | Where-Object DefectId -ceq $Case) }

$record = [ordered]@{
    schemaVersion = 1
    status = 'running'
    scope = 'selfhost-call-and-await-topology'
    completed = 0
    total = $cases.Count
    candidateSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $candidate).Hash
    checks = @()
    resultPath = Join-Path $output 'result.json'
}
function Save-Result {
    [IO.File]::WriteAllText($record.resultPath, (($record | ConvertTo-Json -Depth 6) + "`n"), [Text.UTF8Encoding]::new($false))
}
function Normalized([string]$Text) { $Text.Replace("`r`n", "`n").TrimEnd("`n") }

Save-Result
try {
    foreach ($item in $cases) {
        $source = Join-Path $root $item.Source
        $expectedPath = Join-Path $root $item.Expected
        foreach ($path in @($source, $expectedPath)) {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "missing $($item.Id) input: $path" }
        }
        & (Join-Path $root 'scripts/format-authoritative-slg.ps1') -Check -Source $source
        if (-not $?) { throw "$($item.Id) authoritative format failed" }

        $caseOutput = Join-Path $output $item.Id
        [void][IO.Directory]::CreateDirectory($caseOutput)
        $expected = Normalized ([IO.File]::ReadAllText($expectedPath))
        $managedExe = Join-Path $caseOutput 'managed.exe'
        $managedLog = (& dotnet $managed run $source --llvm $llvm -o $managedExe --keep-temps -O0 2>&1) -join "`n"
        if ($LASTEXITCODE -ne 0 -or (Normalized $managedLog) -cne $expected) {
            throw "$($item.Id) managed exact execution failed: $managedLog"
        }

        if ($item.RequireResolvedCalls) {
            $callTopology = (& $candidate typed-ir-calls $source 2>&1) -join "`n"
            if ($LASTEXITCODE -ne 0) { throw "$($item.Id) Typed IR call topology failed: $callTopology" }
            if ($callTopology -match '(?m)^resolution .* status [^0]\s*$') {
                throw "$($item.Id) retains an unresolved call before LLVM: $callTopology"
            }
        }

        $llvmPath = Join-Path $caseOutput 'candidate.ll'
        $stderrPath = Join-Path $caseOutput 'candidate.stderr.txt'
        $emit = Start-Process -FilePath $candidate -ArgumentList @('windows', '--jobs', '1', $source) `
            -NoNewWindow -Wait -PassThru -RedirectStandardOutput $llvmPath -RedirectStandardError $stderrPath
        $stderr = [IO.File]::ReadAllText($stderrPath)
        if ($emit.ExitCode -ne 0) {
            $emitted = if (Test-Path -LiteralPath $llvmPath) { [IO.File]::ReadAllText($llvmPath) } else { '' }
            throw "$($item.Id) selfhost emission failed: $stderr$emitted"
        }
        if ($stderr -match '(?m)^(warning|note) ') { throw "$($item.Id) selfhost emitted diagnostics: $stderr" }
        if ((Get-Item -LiteralPath $llvmPath).Length -eq 0) { throw "$($item.Id) selfhost emitted empty LLVM" }

        $bitcode = Join-Path $caseOutput 'candidate.bc'
        & $llvmAs $llvmPath -o $bitcode
        if ($LASTEXITCODE -ne 0) { throw "$($item.Id) llvm-as failed" }
        & (Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1') -LlvmPath $llvmPath
        if (-not $?) { throw "$($item.Id) direct-call closure failed" }

        $candidateExe = Join-Path $caseOutput 'candidate.exe'
        & $clang $llvmPath -O0 -Werror -Wno-override-module -o $candidateExe
        if ($LASTEXITCODE -ne 0) { throw "$($item.Id) native link failed" }
        $candidateLog = (& $candidateExe 2>&1) -join "`n"
        if ($LASTEXITCODE -ne 0 -or (Normalized $candidateLog) -cne $expected) {
            throw "$($item.Id) selfhost exact execution failed: $candidateLog"
        }

        $record.completed++
        $record.checks += $item.Id
        Save-Result
    }
    $record.status = 'passed'
    Save-Result
    Write-Host "[selfhost call topology] PASS $($record.completed)/$($record.total); $($record.resultPath)"
} catch {
    $record.status = 'failed'
    $record.failure = $_.Exception.Message
    Save-Result
    throw
}
