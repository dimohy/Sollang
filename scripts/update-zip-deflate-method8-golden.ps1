[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory)][string]$CompilerPath,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedCompilerSha256,
    [Parameter(Mandatory)][string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$scratchRoot = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
$output = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $root $OutputDirectory }))
$scratchPrefix = $scratchRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not ($output + [IO.Path]::DirectorySeparatorChar).StartsWith($scratchPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "output must be under artifacts/scratch: $output"
}
if (Test-Path -LiteralPath $output) {
    if (-not (Test-Path -LiteralPath $output -PathType Container) -or @(Get-ChildItem -LiteralPath $output -Force).Count -ne 0) {
        throw "output must be new or empty: $output"
    }
}
[IO.Directory]::CreateDirectory($output) | Out-Null

$compiler = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($CompilerPath)) { $CompilerPath } else { Join-Path $root $CompilerPath }))
$expectedCompilerHash = $ExpectedCompilerSha256.ToUpperInvariant()
$fixture = Join-Path $root 'examples/regression/1756-zip-deflate-method8.slg'
$published = Join-Path $root 'examples/regression/expected/1756-zip-deflate-method8.stdout.txt'
$oracle = Join-Path $root 'scripts/probes/zip-deflate-method8/verify_python_oracle.py'
$closureVerifier = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
$llvmAs = Join-Path $llvmRoot 'bin/llvm-as.exe'
$artifact = Join-Path $output '1756.exe'
$llvm = Join-Path $output '1756.slg-tmp/1756.ll'
$bitcode = Join-Path $output '1756.bc'
$stdoutPath = Join-Path $output '1756.stdout.txt'
$stderrPath = Join-Path $output '1756.stderr.txt'
$resultPath = Join-Path $output 'golden-update-result.json'

foreach ($path in @($compiler, $fixture, $oracle, $closureVerifier, $llvmAs)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "required input is missing: $path" }
}
if ((Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash -cne $expectedCompilerHash) {
    throw 'compiler hash mismatch'
}

function Invoke-Checked([string]$Id, [string]$FilePath, [string[]]$Arguments, [switch]$AllowStdout) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FilePath
    $start.WorkingDirectory = $root
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw "$Id did not start" }
        $stdout = [IO.MemoryStream]::new()
        $stderr = [IO.MemoryStream]::new()
        $stdoutTask = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
        $stderrTask = $process.StandardError.BaseStream.CopyToAsync($stderr)
        if (-not $process.WaitForExit(180000)) {
            $process.Kill($true)
            $process.WaitForExit()
            throw "$Id timed out"
        }
        $stdoutTask.GetAwaiter().GetResult() | Out-Null
        $stderrTask.GetAwaiter().GetResult() | Out-Null
        $stdoutBytes = $stdout.ToArray()
        $stderrBytes = $stderr.ToArray()
        if ($process.ExitCode -ne 0 -or $stderrBytes.Length -ne 0 -or (-not $AllowStdout -and $stdoutBytes.Length -ne 0)) {
            throw "$Id failed: exit=$($process.ExitCode), stdout=$($stdoutBytes.Length), stderr=$($stderrBytes.Length)"
        }
        [pscustomobject]@{ ExitCode = $process.ExitCode; StdoutBytes = $stdoutBytes; StderrBytes = $stderrBytes }
    }
    finally { $process.Dispose() }
}

$compilerExtension = [IO.Path]::GetExtension($compiler).ToLowerInvariant()
if ($compilerExtension -ceq '.dll') {
    $compilerCommand = @((Get-Command dotnet -CommandType Application -ErrorAction Stop))[0].Source
    $compilerArguments = @($compiler, 'build', $fixture, '-o', $artifact, '--target', 'windows-x64', '--llvm', $llvmRoot, '-O0', '--keep-temps')
}
elseif ($compilerExtension -ceq '.exe') {
    $compilerCommand = $compiler
    $compilerArguments = @('build', $fixture, '-o', $artifact, '--target', 'windows-x64', '--llvm', $llvmRoot, '-O0', '--keep-temps')
}
else { throw 'compiler must be a .dll or .exe' }

$compile = Invoke-Checked 'compile' $compilerCommand $compilerArguments -AllowStdout
$compileText = [Text.Encoding]::UTF8.GetString($compile.StdoutBytes)
if ($compileText -match '(?im)(?:^|\r?\n)\s*(?:warning|note)\b') { throw 'compile emitted a warning or note' }
if (-not (Test-Path -LiteralPath $artifact -PathType Leaf) -or -not (Test-Path -LiteralPath $llvm -PathType Leaf)) {
    throw 'compile did not produce the required native and LLVM artifacts'
}

$pwsh = @((Get-Command pwsh -CommandType Application -ErrorAction Stop))[0].Source
[void](Invoke-Checked 'direct-call-closure' $pwsh @('-NoProfile', '-File', $closureVerifier, '-LlvmPath', $llvm) -AllowStdout)
[void](Invoke-Checked 'llvm-as' $llvmAs @($llvm, '-o', $bitcode))
$runtime = Invoke-Checked 'native-runtime' $artifact @() -AllowStdout
[IO.File]::WriteAllBytes($stdoutPath, $runtime.StdoutBytes)
[IO.File]::WriteAllBytes($stderrPath, $runtime.StderrBytes)

$python = @((Get-Command python -CommandType Application -ErrorAction Stop))[0].Source
$oracleResult = Invoke-Checked 'python-oracle' $python @($oracle, $stdoutPath) -AllowStdout
$oracleText = [Text.Encoding]::UTF8.GetString($oracleResult.StdoutBytes).Trim()
if (-not $oracleText.StartsWith('PASS python zipfile method8 ', [StringComparison]::Ordinal)) {
    throw 'Python oracle did not emit its authority receipt'
}

$lines = [IO.File]::ReadAllLines($stdoutPath)
$requiredLines = @(
    'zip-deflate=true',
    'zip-deflate-method=true',
    'zip-deflate-errors=true,true,true,true,true,true,true',
    'zip-deflate-writer-transactional=true',
    'zip-deflate-writer-bounds=true,true',
    'zip-deflate-raw=true,true,true,true'
)
foreach ($requiredLine in $requiredLines) {
    if ($requiredLine -cnotin $lines) { throw "required runtime evidence is missing: $requiredLine" }
}

$compilerHashEnd = (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash
if ($compilerHashEnd -cne $expectedCompilerHash) { throw 'compiler drifted during golden generation' }
$candidateHash = (Get-FileHash -LiteralPath $stdoutPath -Algorithm SHA256).Hash
$temporaryPublished = "$published.$([Guid]::NewGuid().ToString('N')).tmp"
try {
    [IO.File]::WriteAllBytes($temporaryPublished, [IO.File]::ReadAllBytes($stdoutPath))
    Move-Item -LiteralPath $temporaryPublished -Destination $published -Force
}
finally {
    if (Test-Path -LiteralPath $temporaryPublished) { Remove-Item -LiteralPath $temporaryPublished -Force }
}
$publishedHash = (Get-FileHash -LiteralPath $published -Algorithm SHA256).Hash
if ($publishedHash -cne $candidateHash) { throw 'published golden bytes differ from the verified candidate' }

$result = [ordered]@{
    schemaVersion = 1
    status = 'passed'
    fixture = [IO.Path]::GetRelativePath($root, $fixture).Replace('\', '/')
    compilerSha256Start = $expectedCompilerHash
    compilerSha256End = $compilerHashEnd
    llvmSha256 = (Get-FileHash -LiteralPath $llvm -Algorithm SHA256).Hash
    bitcodeSha256 = (Get-FileHash -LiteralPath $bitcode -Algorithm SHA256).Hash
    artifactSha256 = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash
    oracleReceipt = $oracleText
    candidateStdoutSha256 = $candidateHash
    publishedStdoutSha256 = $publishedHash
    publishedPath = [IO.Path]::GetRelativePath($root, $published).Replace('\', '/')
}
[IO.File]::WriteAllText($resultPath, (($result | ConvertTo-Json -Depth 5) + "`n"), [Text.UTF8Encoding]::new($false))
Write-Host "[ZIP DEFLATE golden] PASS sha256=$publishedHash; result=$resultPath"
