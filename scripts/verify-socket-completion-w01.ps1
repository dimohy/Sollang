[CmdletBinding()]
param(
    [string]$Compiler = '',
    [string]$OutputDirectory = ''
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $root 'scripts/verification-process.ps1')
if ([string]::IsNullOrWhiteSpace($Compiler)) { $Compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll' }
$Compiler = (Resolve-Path -LiteralPath $Compiler).Path
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory = Join-Path $root ('artifacts/scratch/socket-completion/w01-' + [guid]::NewGuid().ToString('N')) }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$paths = [ordered]@{
    compiler = $Compiler
    probe = Join-Path $root 'scripts/probes/socket-completion/w01-create-capacity.slg'
    contract = Join-Path $root 'scripts/contracts/socket-completion-reactor.json'
    contractSchema = Join-Path $root 'scripts/contracts/socket-completion-reactor.schema.json'
    resultSchema = Join-Path $root 'scripts/contracts/socket-completion-w01-result.schema.json'
    verifier = $PSCommandPath
    authorityVerifier = Join-Path $root 'scripts/verify-socket-reactor-contract.ps1'
    closureVerifier = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
    windowsRuntime = Join-Path $root 'src/Sollang.Compiler/CodeGen/WindowsLlvmRuntimePlatform.Socket.cs'
    linuxRuntime = Join-Path $root 'src/Sollang.Compiler/CodeGen/LinuxLlvmRuntimePlatform.Socket.cs'
}
function Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Hash-StatusNormalizedContract([string]$Path) {
    $contract = [IO.File]::ReadAllText($Path) | ConvertFrom-Json
    ($contract.verificationMatrix | Where-Object id -CEQ 'W01').status = 'pending'
    $bytes = [Text.Encoding]::UTF8.GetBytes(($contract | ConvertTo-Json -Depth 30 -Compress))
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
}
function Run([string]$File, [string[]]$Arguments, [string]$Description) {
    return Invoke-VerificationProcessCapture -FilePath $File -ArgumentList $Arguments -WorkingDirectory $root -Description $Description -TimeoutMilliseconds 120000
}
foreach ($path in $paths.Values) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "W01 input missing: $path" } }
$hashes = [ordered]@{}
foreach ($entry in $paths.GetEnumerator()) {
    $hashes[$entry.Key] = if ($entry.Key -ceq 'contract') { Hash-StatusNormalizedContract $entry.Value } else { Hash $entry.Value }
}
$exe = Join-Path $OutputDirectory 'w01.exe'
$ll = Join-Path $OutputDirectory 'w01.ll'
$expected = "duplicate=true,code=0,portsDistinct=true,returnedB=true,removedA=true,removedB=true`ncapacity=true,code=0,portsDistinct=true,returnedC=true,removedA=true,removedB=true`nw01=complete"
$failureIds = [Collections.Generic.List[string]]::new()
$compileExit = -1
$compileDiagnosticsClean = $false
$nativeExit = $null
$llvmAsExit = $null
$closureExit = $null
$authorityExit = $null
$stdout = ''
try {
    $compile = Run 'dotnet' @($Compiler, 'build', $paths.probe, '-o', $exe, '--target', 'windows-x64', '--llvm', (Join-Path $root '.tools/llvm-22.1.8'), '-O1', '--keep-temps') 'W01 compile'
    $compileExit = $compile.ExitCode
    $compileDiagnostics = $compile.Stdout + "`n" + $compile.Stderr
    $compileDiagnosticsClean = [string]::IsNullOrWhiteSpace($compile.Stderr) -and
        -not [regex]::IsMatch($compileDiagnostics, '(?im)^(warning|note|error)\b')
    if ($compileExit -ne 0 -or -not (Test-Path -LiteralPath $ll -PathType Leaf)) { $failureIds.Add('W01_COMPILE') }
    if (-not $compileDiagnosticsClean) { $failureIds.Add('W01_COMPILE_DIAGNOSTIC') }
    if ($failureIds.Count -eq 0) {
        $native = Run $exe @() 'W01 native'
        $nativeExit = $native.ExitCode
        $stdout = $native.Stdout.Replace("`r`n", "`n").TrimEnd()
        if ($nativeExit -ne 0 -or -not [string]::IsNullOrWhiteSpace($native.Stderr) -or $stdout -cne $expected) { $failureIds.Add('W01_NATIVE_EXACT') }
        $assembled = Run (Join-Path $root '.tools/llvm-22.1.8/bin/llvm-as.exe') @($ll, '-o', (Join-Path $OutputDirectory 'w01.bc')) 'W01 llvm-as'
        $llvmAsExit = $assembled.ExitCode
        if ($llvmAsExit -ne 0) { $failureIds.Add('W01_LLVM_AS') }
        $closure = Run 'pwsh' @('-NoProfile', '-File', $paths.closureVerifier, '-LlvmPath', $ll) 'W01 V004'
        $closureExit = $closure.ExitCode
        if ($closureExit -ne 0) { $failureIds.Add('W01_V004') }
        $authority = Run 'pwsh' @('-NoProfile', '-File', $paths.authorityVerifier) 'W01 authority'
        $authorityExit = $authority.ExitCode
        if ($authorityExit -ne 0) { $failureIds.Add('W01_REGISTER_PRE_EFFECT') }
    }
} catch {
    $failureIds.Add('W01_RUNNER_EXCEPTION')
}
foreach ($entry in $paths.GetEnumerator()) {
    $endHash = if ($entry.Key -ceq 'contract') { Hash-StatusNormalizedContract $entry.Value } else { Hash $entry.Value }
    if ($endHash -cne $hashes[$entry.Key]) { $failureIds.Add('W01_INPUT_DRIFT'); break }
}
$record = [ordered]@{
    schemaVersion = 1
    caseId = 'W01'
    status = if ($failureIds.Count -eq 0) { 'passed' } else { 'failed' }
    compilerSha256 = $hashes.compiler
    inputHashes = $hashes
    compileExit = $compileExit
    compileDiagnosticsClean = $compileDiagnosticsClean
    nativeExit = $nativeExit
    llvmAsExit = $llvmAsExit
    closureExit = $closureExit
    authorityExit = $authorityExit
    stdout = $stdout
    failureIds = @($failureIds)
}
$json = ($record | ConvertTo-Json -Depth 6) + "`n"
$resultPath = Join-Path $OutputDirectory 'result.json'
[IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
if (-not ($json | Test-Json -SchemaFile $paths.resultSchema)) { throw "W01 result schema failure: $resultPath" }
if ($record.compilerSha256 -cne $record.inputHashes.compiler) { throw "W01 compiler/input hash mismatch: $resultPath" }
if ($record.status -ne 'passed') { throw "W01 failed: $($record.failureIds -join ', '); result=$resultPath" }
Write-Host "[socket completion W01] PASS result=$resultPath"
