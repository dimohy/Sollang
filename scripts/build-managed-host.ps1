[CmdletBinding()]
param([Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9._-]+$')][string]$RunId)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'managed-reference-snapshot.ps1')
$root = Split-Path -Parent $PSScriptRoot
$output = Join-Path $root "artifacts/scratch/managed-host-$RunId"
if (Test-Path -LiteralPath $output) { throw "managed host build output already exists: $output" }
[IO.Directory]::CreateDirectory($output) | Out-Null
$project = Join-Path $root 'src/Sollang.Compiler/Sollang.Compiler.csproj'
$compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$dotnet = (Get-Command dotnet -CommandType Application).Source
# Ordinary incremental host build only: no solution, Rebuild, example suite,
# selfhost compiler-as-input, bootstrap, or Stage2/Stage3 command is involved.
$arguments = @('build', $project, '-c', 'Release', '--no-restore', '--nologo', '-v', 'minimal',
    '/nodeReuse:false', '/p:UseSharedCompilation=false', '/warnaserror')
$roots = @('src/Sollang.Compiler', 'src/Sollang.Compiler.Generators', 'stdlib', 'syntax' |
    ForEach-Object { Join-Path $root $_ })
$required = @($dotnet, $PSCommandPath)
foreach ($name in @('Directory.Build.props', 'Directory.Build.targets', 'global.json', 'NuGet.Config', 'nuget.config')) {
    $path = Join-Path $root $name
    if (Test-Path -LiteralPath $path -PathType Leaf) { $required += $path }
}
$result = [ordered]@{ schemaVersion = 1; scope = 'incremental-managed-host-only'; status = 'running'; stage2Stage3Executed = $false }
try {
    $before = Get-ManagedReferenceSnapshot -DirectoryRoots $roots -RequiredFiles $required -Command (@($dotnet) + $arguments)
    [IO.File]::WriteAllText((Join-Path $output 'inputs-before.json'), ($before | ConvertTo-Json -Depth 8))
    & $dotnet @arguments
    $exitCode = $LASTEXITCODE
    $after = Get-ManagedReferenceSnapshot -DirectoryRoots $roots -RequiredFiles $required -Command (@($dotnet) + $arguments)
    [IO.File]::WriteAllText((Join-Path $output 'inputs-after.json'), ($after | ConvertTo-Json -Depth 8))
    if ($exitCode -ne 0) { throw "dotnet host build exited $exitCode" }
    Assert-InputFingerprintStable -ExpectedFingerprint $before.fingerprint -CurrentFingerprint $after.fingerprint -Phase 'managed host build'
    $result.inputFingerprint = $before.fingerprint
    $result.compilerSha256 = (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash
    $result.exitCode = $exitCode
    $result.status = 'passed'
} catch {
    $result.status = 'failed'
    $result.failure = $_.Exception.Message
    Write-Error "FAIL MANAGED_HOST_BUILD_FAILED: $($_.Exception.Message)" -ErrorAction Continue
    throw
} finally {
    [IO.File]::WriteAllText((Join-Path $output 'result.json'), (($result | ConvertTo-Json -Depth 4) + "`n"))
}
Write-Host "[managed host] PASS incremental host only; $output/result.json"
