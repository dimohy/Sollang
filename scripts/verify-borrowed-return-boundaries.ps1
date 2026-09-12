[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [ValidateSet('fallthrough', 'explicit-return', 'source-text-pass-through', 'projection-alias')]
    [string[]]$CaseId
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$output = Join-Path $root ('artifacts/scratch/borrowed-return-scalars-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($output) | Out-Null
$resultPath = Join-Path $output 'result.json'
$cases = @(
    @{ id = 'fallthrough'; mode = 'run'; expected = '42' },
    @{ id = 'explicit-return'; mode = 'run'; expected = '42' },
    @{ id = 'source-text-pass-through'; mode = 'build'; expected = 'while borrowed Text view' },
    @{ id = 'projection-alias'; mode = 'run'; expected = 'name' }
)
if ($PSBoundParameters.ContainsKey('CaseId')) {
    if (@($CaseId).Count -eq 0 -or @($CaseId | Select-Object -Unique).Count -ne $CaseId.Count) {
        throw 'CaseId must contain a nonempty unique selection'
    }
    $cases = @($cases | Where-Object { $_.id -cin $CaseId })
}
$compilerHash = (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash
$record = [ordered]@{
    schemaVersion = 1
    scope = 'actual-managed-borrowed-return-boundaries'
    status = 'running'
    compilerSha256 = $compilerHash
    completed = 0
    total = $cases.Count
    selectedIds = @(foreach ($selectedCase in $cases) { $selectedCase.id })
    integration = 'selfhost and Stage2/Stage3 not executed'
    cases = @()
}

try {
    foreach ($contract in $cases) {
        $id = $contract.id
        $source = Join-Path $root "scripts/probes/borrowed-return-scalars/$id.slg"
        $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        $exe = Join-Path $output "$id.exe"
        $ir = Join-Path $output "$id.ll"
        $log = Join-Path $output "$id.log"
        $actual = (& dotnet $compiler $contract.mode $source --llvm $llvm -o $exe --keep-temps 2>&1) -join "`n"
        $exitCode = $LASTEXITCODE
        [IO.File]::WriteAllText($log, $actual + "`n")
        $case = [ordered]@{
            id = $id
            mode = $contract.mode
            expected = $contract.expected
            source = $source
            sourceSha256 = $sourceHash
            exitCode = $exitCode
            status = 'failed'
            output = $actual
            log = $log
            generatedProducts = @(@($ir, $exe, (Join-Path $output "$id.slg-tmp/$id.ll")) | Where-Object { Test-Path -LiteralPath $_ })
        }
        if ($contract.mode -ceq 'build') {
            if ($exitCode -ne 0 -and $actual -match 'semantic error' -and
                $actual.Contains($contract.expected, [StringComparison]::Ordinal) -and
                $case.generatedProducts.Count -eq 0) {
                $case.status = 'passed'
                $record.completed++
            }
        } elseif ($exitCode -eq 0 -and $actual.Replace("`r`n", "`n").TrimEnd() -ceq $contract.expected) {
            $assembleLog = (& (Join-Path $llvm 'bin/llvm-as.exe') $ir -o (Join-Path $output "$id.bc") 2>&1) -join "`n"
            $assembleExit = $LASTEXITCODE
            [IO.File]::WriteAllText((Join-Path $output "$id.assemble.log"), $assembleLog + "`n")
            if ($assembleExit -ne 0) { throw "$id LLVM assembly failed: $assembleLog" }
            & (Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1') -LlvmPath $ir
            $case.llvmSha256 = (Get-FileHash -LiteralPath $ir -Algorithm SHA256).Hash
            $case.executableSha256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
            $case.llvmAssembly = 'passed'
            $case.directCallClosure = 'passed'
            $case.status = 'passed'
            $record.completed++
        }
        if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -cne $sourceHash) { throw "$id source changed during execution" }
        $record.cases += $case
        [IO.File]::WriteAllText($resultPath, ($record | ConvertTo-Json -Depth 6) + "`n")
    }
    if ((Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash -cne $compilerHash) { throw 'Compiler changed during execution' }
    $record.inputsStable = $true
    if ($record.completed -ne $record.total) { throw "Borrowed return boundary regression failed: $($record.completed)/$($record.total); see $resultPath" }
    $record.status = 'passed'
} catch {
    $record.status = 'failed'
    $record.failure = $_.Exception.Message
    throw
} finally {
    [IO.File]::WriteAllText($resultPath, ($record | ConvertTo-Json -Depth 6) + "`n")
    Write-Host "Borrowed return boundary result: $resultPath ($($record.completed)/$($record.total))"
}
