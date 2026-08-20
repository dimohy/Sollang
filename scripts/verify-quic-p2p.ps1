[CmdletBinding()]
param(
    [string]$Compiler = "P:\Utils\sollang\sollang.exe",
    [string]$LlvmHome = ".tools\llvm-22.1.8"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$llvmPath = (Resolve-Path -LiteralPath (Join-Path $repoRoot $LlvmHome)).Path
$stdlibPath = Join-Path $repoRoot "stdlib"
$scratchPath = Join-Path $repoRoot "artifacts\scratch\quic-p2p"
$serverSource = Join-Path $repoRoot "examples\interop\quic-p2p-chat-server.slg"
$clientSource = Join-Path $repoRoot "examples\interop\quic-p2p-chat-client.slg"
$serverProgram = Join-Path $scratchPath "quic-p2p-chat-server.exe"
$clientProgram = Join-Path $scratchPath "quic-p2p-chat-client.exe"
$serverOutput = Join-Path $scratchPath "server.stdout.log"
$serverError = Join-Path $scratchPath "server.stderr.log"
$clientOutput = Join-Path $scratchPath "client.stdout.log"
$clientError = Join-Path $scratchPath "client.stderr.log"

New-Item -ItemType Directory -Force -Path $scratchPath | Out-Null

Write-Host "[p2p 1/3] Build both peers with the selected native compiler."
& $compilerPath build $serverSource -o $serverProgram --target windows-x64 --llvm $llvmPath --stdlib $stdlibPath -O1
if ($LASTEXITCODE -ne 0) { throw "P2P server build failed" }
& $compilerPath build $clientSource -o $clientProgram --target windows-x64 --llvm $llvmPath --stdlib $stdlibPath -O1
if ($LASTEXITCODE -ne 0) { throw "P2P client build failed" }

Write-Host "[p2p 2/3] Run authenticated peer discovery, protocol negotiation, and chat."
$server = Start-Process `
    -FilePath $serverProgram `
    -WorkingDirectory $repoRoot `
    -RedirectStandardOutput $serverOutput `
    -RedirectStandardError $serverError `
    -PassThru `
    -WindowStyle Hidden

try {
    # Native stdout is package-buffered until process exit. Give the UDP bind
    # a deterministic startup window instead of treating redirected stdout as
    # a readiness channel.
    Start-Sleep -Milliseconds 750
    if ($server.HasExited) {
        throw "P2P server exited during startup: $([IO.File]::ReadAllText($serverError))"
    }

    $client = Start-Process `
        -FilePath $clientProgram `
        -WorkingDirectory $repoRoot `
        -RedirectStandardOutput $clientOutput `
        -RedirectStandardError $clientError `
        -PassThru `
        -WindowStyle Hidden `
        -Wait
    if ($client.ExitCode -ne 0) {
        throw "P2P client failed with exit code $($client.ExitCode): $([IO.File]::ReadAllText($clientError))"
    }
    if (-not $server.WaitForExit(10000)) {
        throw "P2P server did not complete"
    }
    if ($server.ExitCode -ne 0) {
        throw "P2P server failed with exit code $($server.ExitCode): $([IO.File]::ReadAllText($serverError))"
    }
} finally {
    if (-not $server.HasExited) {
        Stop-Process -Id $server.Id -Force
    }
}

Write-Host "[p2p 3/3] Verify exact application results."
$actualServer = [IO.File]::ReadAllText($serverOutput).Replace("`r`n", "`n").Trim()
$actualClient = [IO.File]::ReadAllText($clientOutput).Replace("`r`n", "`n").Trim()
$expectedServer = "p2p-ready=44434`nserver-received=10`np2p-server-complete"
$expectedClient = "client-received=12`np2p-client-complete"
if ($actualServer -ne $expectedServer) {
    throw "P2P server output mismatch.`nExpected:`n$expectedServer`nActual:`n$actualServer"
}
if ($actualClient -ne $expectedClient) {
    throw "P2P client output mismatch.`nExpected:`n$expectedClient`nActual:`n$actualClient"
}
Write-Host "QUIC P2P verification passed."
