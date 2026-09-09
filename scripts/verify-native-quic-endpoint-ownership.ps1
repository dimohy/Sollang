[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Compiler,
    [string]$Label = "candidate",
    [string]$LlvmHome = ".tools\llvm-22.1.8",
    [string]$StdlibRoot = "stdlib",
    [string]$RepositoryRoot = "",
    [ValidateRange(1, 64)][int]$Jobs = 4
)

$ErrorActionPreference = "Stop"
$repoRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    Split-Path -Parent $PSScriptRoot
} else {
    [IO.Path]::GetFullPath($RepositoryRoot)
}
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$llvmCandidate = if ([IO.Path]::IsPathFullyQualified($LlvmHome)) { $LlvmHome } else { Join-Path $repoRoot $LlvmHome }
$stdlibCandidate = if ([IO.Path]::IsPathFullyQualified($StdlibRoot)) { $StdlibRoot } else { Join-Path $repoRoot $StdlibRoot }
$llvmPath = (Resolve-Path -LiteralPath $llvmCandidate).Path
$stdlibPath = (Resolve-Path -LiteralPath $stdlibCandidate).Path
$outputDirectory = Join-Path $repoRoot "artifacts\scratch\quic-endpoint-ownership-$Label"
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

$cases = @(
    [ordered]@{
        Name = "move-method-owned-field-drop"
        Source = Join-Path $repoRoot "examples\regression\1166-move-method-owned-field-drop.slg"
        Expected = "closed"
    },
    [ordered]@{
        Name = "quic-endpoint-two-connection-routing"
        Source = Join-Path $repoRoot "examples\regression\1167-quic-endpoint-two-connection-routing.slg"
        Expected = "quic-two-routes=true"
    },
    [ordered]@{
        Name = "quic-bidirectional-multi-stream-routing"
        Source = Join-Path $repoRoot "examples\regression\1206-quic-bidirectional-multi-stream-routing.slg"
        Expected = "quic-multi-stream=true"
    },
    [ordered]@{
        Name = "quic-connection-options-queue-limits"
        Source = Join-Path $repoRoot "examples\regression\1209-quic-connection-options-queue-limits.slg"
        Expected = "quic-options=true"
    },
    [ordered]@{
        Name = "quic-unidirectional-stream-owners"
        Source = Join-Path $repoRoot "examples\regression\1297-quic-unidirectional-stream-owners.slg"
        Expected = "quic-unidirectional-owners=true"
    }
)

$completedCases = 0
$totalCases = $cases.Count
foreach ($case in $cases) {
    $caseNumber = $completedCases + 1
    Write-Host "[native QUIC Endpoint ownership $caseNumber/$totalCases] BUILD $Label $($case.Name)."
    $program = Join-Path $outputDirectory "$($case.Name).exe"
    $stdout = Join-Path $outputDirectory "$($case.Name).stdout.log"
    $stderr = Join-Path $outputDirectory "$($case.Name).stderr.log"
    Remove-Item -LiteralPath $program, $stdout, $stderr -ErrorAction SilentlyContinue

    & $compilerPath build $case.Source -o $program --target windows-x64 `
        --llvm $llvmPath --stdlib $stdlibPath --jobs $Jobs -O1 --keep-temps
    if ($LASTEXITCODE -ne 0) {
        throw "$Label $($case.Name) build failed"
    }
    & (Join-Path $PSScriptRoot "verify-llvm-direct-call-closure.ps1") -LlvmPath "$program.ll"
    if (-not $?) { throw "$Label $($case.Name) LLVM direct-call closure verification failed" }

    $process = Start-Process `
        -FilePath $program `
        -WorkingDirectory $repoRoot `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr `
        -PassThru `
        -WindowStyle Hidden
    if (-not $process.WaitForExit(20000)) {
        Stop-Process -Id $process.Id -Force
        throw "$Label $($case.Name) timed out"
    }
    if ($process.ExitCode -ne 0) {
        throw "$Label $($case.Name) exited $($process.ExitCode): $([IO.File]::ReadAllText($stderr))"
    }
    $actual = [IO.File]::ReadAllText($stdout).Replace("`r`n", "`n").Trim()
    if ($actual -cne $case.Expected) {
        throw "$Label $($case.Name) output mismatch. Expected '$($case.Expected)', actual '$actual'"
    }
    $completedCases += 1
    Write-Host "[native QUIC Endpoint ownership $completedCases/$totalCases] PASS $Label $($case.Name)."
}

Write-Host "[native QUIC Endpoint ownership] PASS $Label $completedCases/$totalCases partial move cleanup, two-connection routing, bidirectional multi-stream demux, and atomic configured queue limits."
