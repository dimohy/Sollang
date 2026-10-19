[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ManagedTargetCompiler,
    [string]$SelfhostTargetCompiler,
    [string]$OutputDirectory,
    [ValidateRange(1000, 3600000)][int]$TimeoutMilliseconds = 180000,
    [switch]$SelfTest,
    [switch]$ValidateInputsOnly,
    [switch]$Run
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ([int]$SelfTest.IsPresent + [int]$ValidateInputsOnly.IsPresent + [int]$Run.IsPresent -ne 1) {
    throw 'C482_MODE_REQUIRED: choose exactly one mode'
}
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$rootPrefix = $root.TrimEnd([char]'\', [char]'/') + [IO.Path]::DirectorySeparatorChar
$contractPath = Join-Path $PSScriptRoot 'contracts/c482-move-input-eligibility.json'
$contractSchema = Join-Path $PSScriptRoot 'contracts/c482-move-input-eligibility.schema.json'
$resultSchema = Join-Path $PSScriptRoot 'contracts/c482-move-input-eligibility-result.schema.json'
$closurePath = Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1'
$processPath = Join-Path $PSScriptRoot 'verification-process.ps1'

function Resolve-Input([string]$Path) {
    $full = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) }
        else { [IO.Path]::GetFullPath((Join-Path $root $Path)) }
    if (-not $full.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "C482_OUTSIDE_REPOSITORY: $full"
    }
    $cursor = [IO.Path]::GetPathRoot($full)
    foreach ($part in ($full.Substring($cursor.Length) -split '[\\/]')) {
        if (-not $part) { continue }
        $cursor = Join-Path $cursor $part
        if (-not (Test-Path -LiteralPath $cursor)) { break }
        if (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "C482_REPARSE_PATH: $cursor"
        }
    }
    return (Resolve-Path -LiteralPath $full -ErrorAction Stop).ProviderPath
}
function Get-Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Assert-NoWarnings([string]$Text) {
    if ($Text -match '(?im)^\s*(?:warning(?:\s|:)|note(?:\s|:)|sollang:\s*(?:warning|note)(?:\s|:))') {
        throw 'C482_WARNING_OR_NOTE'
    }
}
function Test-ExactDiagnostic([string]$Compiler, [int]$ExitCode, [string]$Stdout, [string]$Stderr, [string]$Expected, [bool]$ProductsAbsent) {
    if ($ExitCode -ne 1 -or $Stdout.Length -ne 0 -or -not $ProductsAbsent) { return $false }
    $lines = @($Stderr.TrimEnd("`r", "`n") -split "`r?`n")
    if ($Compiler -ceq 'managed') {
        return $lines.Count -eq 1 -and
            $lines[0] -ceq "sollang: semantic error at 1:19: [module '<main>'] $Expected"
    }
    if ($Compiler -ceq 'selfhost') {
        if ($lines.Count -eq 2 -and $lines[0] -ceq '; sollang workers = 1') { return $lines[1] -ceq $Expected }
        return $lines.Count -eq 1 -and $lines[0] -ceq $Expected
    }
    throw "C482_UNKNOWN_COMPILER: $Compiler"
}
function Test-BytesEqual([byte[]]$Left, [byte[]]$Right) {
    if ($Left.Length -ne $Right.Length) { return $false }
    for ($i = 0; $i -lt $Left.Length; $i++) { if ($Left[$i] -ne $Right[$i]) { return $false } }
    return $true
}
function Get-Contract {
    $json = [IO.File]::ReadAllText((Resolve-Input $contractPath))
    if (-not (Test-Json -Json $json -SchemaFile $contractSchema -ErrorAction SilentlyContinue)) {
        throw 'C482_CONTRACT_SCHEMA_REJECTED'
    }
    $value = $json | ConvertFrom-Json -Depth 16
    foreach ($case in $value.cases) {
        if ((Get-Sha (Resolve-Input $case.source)) -cne $case.sourceSha256) {
            throw "C482_SOURCE_PIN_MISMATCH: $($case.id)"
        }
    }
    if ((Resolve-Input $value.build.stdlibRoot) -cne (Resolve-Input (Join-Path $root 'stdlib'))) {
        throw 'C482_STDLIB_ROOT_MISMATCH: Managed build uses repository stdlib'
    }
    return $value
}
function Get-InputFingerprint($Contract, [string]$Managed, [string]$Selfhost) {
    $paths = [Collections.Generic.List[string]]::new()
    foreach ($path in @($PSCommandPath, $processPath, $closurePath, $contractPath, $contractSchema, $resultSchema, $Managed, $Selfhost)) {
        $paths.Add((Resolve-Input $path))
    }
    $managedDirectory = Split-Path -Parent (Resolve-Input $Managed)
    foreach ($name in 'Sollang.Compiler.dll', 'Sollang.Compiler.deps.json', 'Sollang.Compiler.runtimeconfig.json') {
        $paths.Add((Resolve-Input (Join-Path $managedDirectory $name)))
    }
    foreach ($case in $Contract.cases) { $paths.Add((Resolve-Input $case.source)) }
    foreach ($name in 'clang.exe', 'llvm-as.exe', 'lld-link.exe', 'llvm-ar.exe') {
        $paths.Add((Resolve-Input (Join-Path $Contract.build.llvmRoot "bin/$name")))
    }
    $stdlib = Resolve-Input $Contract.build.stdlibRoot
    $stdlibFiles = @(Get-ChildItem -LiteralPath $stdlib -Recurse -File -Filter '*.slg' | Sort-Object FullName)
    if ($stdlibFiles.Count -eq 0) { throw 'C482_STDLIB_EMPTY' }
    foreach ($file in $stdlibFiles) { $paths.Add((Resolve-Input $file.FullName)) }
    $entries = @($paths | Sort-Object -Unique | ForEach-Object { "$_|$(Get-Sha $_)" })
    $bytes = [Text.Encoding]::UTF8.GetBytes(($entries -join "`n") + "`n")
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
}
function Invoke-GateProcess([string]$File, [string[]]$Arguments, [string]$Cwd, [string]$Label, [string]$Out, [string]$Err) {
    $observation = Invoke-VerificationProcessCapture -FilePath $File -ArgumentList $Arguments -WorkingDirectory $Cwd -Description $Label -TimeoutMilliseconds $TimeoutMilliseconds
    [IO.File]::WriteAllText($Out, $observation.Stdout, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($Err, $observation.Stderr, [Text.UTF8Encoding]::new($false))
    return [int]$observation.ExitCode
}
function Assert-SelfhostCounts([string]$Source, [System.Collections.IDictionary]$Case, [int]$Semantic, [int]$Ir) {
    $out = Join-Path $Case.directory 'diagnostic-counts.stdout.txt'
    $err = Join-Path $Case.directory 'diagnostic-counts.stderr.txt'
    $exit = Invoke-GateProcess $selfhostPath @('diagnostic-counts', $Source) $Case.directory "$($Case.fixture) diagnostic-counts" $out $err
    $stdout = [IO.File]::ReadAllText($out)
    $stderr = [IO.File]::ReadAllText($err)
    if ($exit -ne 0 -or $stdout -cnotmatch "^checked diagnostics = $($Semantic + $Ir)\r?\n$" -or
        $stderr -cnotmatch "^semantic diagnostics = $Semantic\r?\nir diagnostics = $Ir\r?\n$") {
        throw "C482_DIAGNOSTIC_PHASE_MISMATCH: $($Case.fixture); $stdout $stderr"
    }
    $Case.semanticCount = $Semantic
    $Case.irCount = $Ir
}
function Write-Result {
    $json = $script:record | ConvertTo-Json -Depth 14
    if (-not (Test-Json -Json $json -SchemaFile $resultSchema -ErrorAction SilentlyContinue)) {
        throw 'C482_RESULT_SCHEMA_REJECTED'
    }
    $target = Join-Path $script:outputPath 'result.json'
    $temporary = "$target.tmp-$PID-$([guid]::NewGuid().ToString('N'))"
    $backup = "$target.backup-$PID-$([guid]::NewGuid().ToString('N'))"
    [IO.File]::WriteAllText($temporary, $json + "`n", [Text.UTF8Encoding]::new($false))
    try {
        if (Test-Path -LiteralPath $target -PathType Leaf) {
            [IO.File]::Replace($temporary, $target, $backup)
            if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force }
        } else { [IO.File]::Move($temporary, $target) }
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
}

$contract = Get-Contract
if ($SelfTest) {
    $good = [IO.File]::ReadAllText($contractPath)
    foreach ($mutation in @('sourceSha256', 'classification', 'caseCount')) {
        $bad = $good | ConvertFrom-Json -Depth 16
        if ($mutation -ceq 'sourceSha256') { $bad.cases[0].sourceSha256 = 'invalid' }
        if ($mutation -ceq 'classification') { $bad.cases[0].classification = 'positive' }
        if ($mutation -ceq 'caseCount') { $bad.caseCount = 2 }
        if (Test-Json -Json ($bad | ConvertTo-Json -Depth 16) -SchemaFile $contractSchema -ErrorAction SilentlyContinue) {
            throw "C482_SELFTEST_CONTRACT_MUTATION_ACCEPTED: $mutation"
        }
    }
    try { [void](Resolve-Input '../outside.slg'); throw 'C482_SELFTEST_TRAVERSAL_ACCEPTED' }
    catch { if ($_.Exception.Message -like '*TRAVERSAL_ACCEPTED*') { throw } }
    $expected = $contract.cases[0].expectedDiagnostic
    $managed = "sollang: semantic error at 1:19: [module '<main>'] $expected`n"
    if (-not (Test-ExactDiagnostic 'managed' 1 '' $managed $expected $true) -or
        -not (Test-ExactDiagnostic 'selfhost' 1 '' "; sollang workers = 1`n$expected`n" $expected $true) -or
        (Test-ExactDiagnostic 'selfhost' 1 '' "; sollang workers = 1`nwrong`n" $expected $true) -or
        (Test-ExactDiagnostic 'managed' 1 '' $managed $expected $false) -or
        (Test-ExactDiagnostic 'managed' 0 '' $managed $expected $true) -or
        (Test-BytesEqual ([byte[]](52, 10)) ([byte[]](52, 13, 10)))) {
        throw 'C482_SELFTEST_BOUNDARY_FAILED'
    }
    $sampleCase = [ordered]@{
        compiler = 'managed'; fixture = 'additional-bounded-negative'; classification = 'semantic-negative'
        state = 'passed'; directory = 'sample'; sourceSha256 = ('A' * 64); buildExitCode = 1
        buildStdoutSha256 = ('A' * 64); buildStderrSha256 = ('A' * 64)
        diagnosticMatched = $true; semanticCount = $null; irCount = $null; productsAbsent = $true
        llvmSha256 = $null; llvmAsExitCode = $null; bitcodeSha256 = $null; exeSha256 = $null
        nativeExitCode = $null; nativeStdoutSha256 = $null; stdoutMatched = $null; failure = $null
    }
    $sample = [ordered]@{
        schemaVersion = 1; gate = 'c482-move-input-eligibility-target'; state = 'passed'
        total = 6; completed = 6; passed = 6; managedCompilerSha256 = ('A' * 64)
        managedDllSha256 = ('A' * 64); selfhostCompilerSha256 = ('A' * 64)
        inputFingerprintStart = ('A' * 64); inputFingerprintEnd = ('A' * 64)
        inputsStable = $true; historicalBaselineReexecuted = $false
        proofScope = 'Source and toolchain SHA stability, compiler diagnostic boundary, LLVM assembly and exact native stdout; no full Stage or ownership-lifetime proof.'
        cases = @(1..6 | ForEach-Object { $sampleCase }); failureId = $null; failure = $null
    }
    $sampleJson = $sample | ConvertTo-Json -Depth 14
    if (-not (Test-Json -Json $sampleJson -SchemaFile $resultSchema -ErrorAction SilentlyContinue)) {
        throw 'C482_SELFTEST_RESULT_SCHEMA_REJECTED'
    }
    $badResult = $sampleJson | ConvertFrom-Json -Depth 14
    $badResult.cases[0].productsAbsent = $false
    if (Test-Json -Json ($badResult | ConvertTo-Json -Depth 14) -SchemaFile $resultSchema -ErrorAction SilentlyContinue) {
        throw 'C482_SELFTEST_RESULT_MUTATION_ACCEPTED'
    }
    [pscustomobject]@{ state = 'passed'; contractSchema = $true; resultSchema = $true; rejectedContractMutations = 3; rejectedResultMutations = 1; boundaryControls = 6 }
    return
}

if (-not $ManagedTargetCompiler -or -not $SelfhostTargetCompiler) {
    throw 'C482_COMPILERS_REQUIRED'
}
$managedPath = Resolve-Input $ManagedTargetCompiler
$selfhostPath = Resolve-Input $SelfhostTargetCompiler
$start = Get-InputFingerprint $contract $managedPath $selfhostPath
$managedSha = Get-Sha $managedPath
$managedDllSha = Get-Sha (Resolve-Input (Join-Path (Split-Path -Parent $managedPath) 'Sollang.Compiler.dll'))
$selfhostSha = Get-Sha $selfhostPath
$end = Get-InputFingerprint $contract $managedPath $selfhostPath
if ($start -cne $end) { throw 'C482_INPUT_DRIFT: preflight' }
if ($ValidateInputsOnly) {
    [ordered]@{
        state = 'validated'; gate = $contract.gate; cases = 3; targetExecutions = 6
        managedCompilerSha256 = $managedSha; managedDllSha256 = $managedDllSha
        selfhostCompilerSha256 = $selfhostSha
        inputFingerprintStart = $start; inputFingerprintEnd = $end; inputsStable = $true
    } | ConvertTo-Json -Depth 4
    return
}
if (-not $OutputDirectory) { throw 'C482_OUTPUT_REQUIRED' }
$script:outputPath = [IO.Path]::GetFullPath($OutputDirectory)
$scratch = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
$scratchPrefix = $scratch.TrimEnd([char]'\', [char]'/') + [IO.Path]::DirectorySeparatorChar
if (-not $outputPath.StartsWith($scratchPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "C482_OUTPUT_OUTSIDE_SCRATCH: $outputPath"
}
[void](Resolve-Input (Split-Path -Parent $outputPath))
if (Test-Path -LiteralPath $outputPath) { throw "C482_OUTPUT_EXISTS: $outputPath" }
$llvmRoot = Resolve-Input $contract.build.llvmRoot
$stdlibRoot = Resolve-Input $contract.build.stdlibRoot
$assembler = Resolve-Input (Join-Path $llvmRoot 'bin/llvm-as.exe')
$pwsh = (Get-Process -Id $PID).Path
if (-not $pwsh) { throw 'C482_PWSH_PATH_MISSING' }
[void][IO.Directory]::CreateDirectory($outputPath)
$cases = @()
foreach ($compiler in @('managed', 'selfhost')) {
    foreach ($fixture in $contract.cases) {
        $cases += [ordered]@{
            compiler = $compiler; fixture = $fixture.id; classification = $fixture.classification
            state = 'not-run'; directory = (Join-Path $outputPath "$compiler-$($fixture.id)")
            sourceSha256 = $fixture.sourceSha256; buildExitCode = $null
            buildStdoutSha256 = $null; buildStderrSha256 = $null
            diagnosticMatched = $null; semanticCount = $null; irCount = $null; productsAbsent = $null
            llvmSha256 = $null; llvmAsExitCode = $null; bitcodeSha256 = $null; exeSha256 = $null
            nativeExitCode = $null; nativeStdoutSha256 = $null; stdoutMatched = $null; failure = $null
        }
    }
}
$script:record = [ordered]@{
    schemaVersion = 1; gate = 'c482-move-input-eligibility-target'; state = 'running'
    total = 6; completed = 0; passed = 0
    managedCompilerSha256 = $managedSha; managedDllSha256 = $managedDllSha; selfhostCompilerSha256 = $selfhostSha
    inputFingerprintStart = $start; inputFingerprintEnd = $null; inputsStable = $false
    historicalBaselineReexecuted = $false
    proofScope = 'Source and toolchain SHA stability, compiler diagnostic boundary, LLVM assembly and exact native stdout; no full Stage or ownership-lifetime proof.'
    cases = $cases; failureId = $null; failure = $null
}
Write-Result
$active = $null
try {
    for ($index = 0; $index -lt $cases.Count; $index++) {
        if ((Get-InputFingerprint $contract $managedPath $selfhostPath) -cne $start) { throw 'C482_INPUT_DRIFT: before case' }
        $active = $cases[$index]
        $fixture = $contract.cases[$index % 3]
        [void][IO.Directory]::CreateDirectory($active.directory)
        $active.state = 'running'; Write-Result
        $source = Resolve-Input $fixture.source
        $exe = Join-Path $active.directory 'probe.exe'
        $ll = if ($active.compiler -ceq 'managed') { Join-Path $active.directory 'probe.ll' } else { "$exe.ll" }
        $bc = Join-Path $active.directory 'probe.bc'
        $compilerPath = if ($active.compiler -ceq 'managed') { $managedPath } else { $selfhostPath }
        $arguments = @('build', $source, '-o', $exe, '--target', 'windows-x64', '--llvm', $llvmRoot)
        if ($active.compiler -ceq 'selfhost') { $arguments += @('--stdlib', $stdlibRoot, '--jobs', '1') }
        $arguments += @('-O1', '--keep-temps')
        $buildOut = Join-Path $active.directory 'build.stdout.txt'
        $buildErr = Join-Path $active.directory 'build.stderr.txt'
        $active.buildExitCode = Invoke-GateProcess $compilerPath $arguments $active.directory "$($active.compiler) $($active.fixture) build" $buildOut $buildErr
        $active.buildStdoutSha256 = Get-Sha $buildOut
        $active.buildStderrSha256 = Get-Sha $buildErr
        $stdout = [IO.File]::ReadAllText($buildOut)
        $stderr = [IO.File]::ReadAllText($buildErr)
        Assert-NoWarnings ($stdout + $stderr)
        if ($fixture.classification -ceq 'semantic-negative') {
            $active.productsAbsent = @((Get-ChildItem -LiteralPath $active.directory -Force | Where-Object { $_.Name -cnotin @('build.stdout.txt', 'build.stderr.txt') })).Count -eq 0
            $active.diagnosticMatched = Test-ExactDiagnostic $active.compiler $active.buildExitCode $stdout $stderr $fixture.expectedDiagnostic $active.productsAbsent
            if (-not $active.diagnosticMatched) { throw "C482_NEGATIVE_MISMATCH: $($active.compiler) $($active.fixture)" }
            if ($active.compiler -ceq 'selfhost') { Assert-SelfhostCounts $source $active 1 0 }
        } else {
            if ($active.buildExitCode -ne 0 -or -not (Test-Path -LiteralPath $exe -PathType Leaf) -or
                -not (Test-Path -LiteralPath $ll -PathType Leaf) -or
                ($active.compiler -ceq 'managed' -and $stderr.Length -ne 0)) {
                throw "C482_POSITIVE_BUILD_FAILED: $($active.compiler) $($active.fixture); exit=$($active.buildExitCode); stderr=$stderr"
            }
            if ($active.compiler -ceq 'selfhost') { Assert-SelfhostCounts $source $active 0 0 }
            $active.llvmSha256 = Get-Sha $ll
            $asOut = Join-Path $active.directory 'llvm-as.stdout.txt'
            $asErr = Join-Path $active.directory 'llvm-as.stderr.txt'
            $active.llvmAsExitCode = Invoke-GateProcess $assembler @($ll, '-o', $bc) $active.directory "$($active.compiler) $($active.fixture) llvm-as" $asOut $asErr
            if ($active.llvmAsExitCode -ne 0 -or (Get-Item -LiteralPath $asOut).Length -ne 0 -or
                (Get-Item -LiteralPath $asErr).Length -ne 0) {
                throw "C482_LLVM_AS_FAILED: $($active.compiler) $($active.fixture)"
            }
            $active.bitcodeSha256 = Get-Sha $bc
            $runOut = Join-Path $active.directory 'run.stdout.txt'
            $runErr = Join-Path $active.directory 'run.stderr.txt'
            $active.nativeExitCode = Invoke-GateProcess $exe @() $active.directory "$($active.compiler) $($active.fixture) native" $runOut $runErr
            $expectedBytes = [Text.Encoding]::UTF8.GetBytes($fixture.expectedStdout)
            $active.stdoutMatched = Test-BytesEqual ([IO.File]::ReadAllBytes($runOut)) $expectedBytes
            if ($active.nativeExitCode -ne 0 -or (Get-Item -LiteralPath $runErr).Length -ne 0 -or -not $active.stdoutMatched) {
                throw "C482_NATIVE_MISMATCH: $($active.compiler) $($active.fixture); exit=$($active.nativeExitCode)"
            }
            $active.exeSha256 = Get-Sha $exe
            $active.nativeStdoutSha256 = Get-Sha $runOut
        }
        $active.state = 'passed'; $record.completed++; $record.passed++; Write-Result
    }
    $record.inputFingerprintEnd = Get-InputFingerprint $contract $managedPath $selfhostPath
    $record.inputsStable = $record.inputFingerprintStart -ceq $record.inputFingerprintEnd
    if (-not $record.inputsStable) { throw 'C482_INPUT_DRIFT: after cases' }
    $record.state = 'passed'; Write-Result
    Write-Output "C482_TARGET_PASS: 6/6; $(Join-Path $outputPath 'result.json')"
} catch {
    $message = $_.Exception.Message
    if ($null -ne $active -and $active.state -ceq 'running') {
        $active.state = 'failed'; $active.failure = $message; $record.completed++
    }
    $record.failureId = if ($message -match '^C482_[A-Z_]+') { ($message -split ':')[0] } else { 'C482_GATE_FAILED' }
    $record.failure = $message
    try {
        $record.inputFingerprintEnd = Get-InputFingerprint $contract $managedPath $selfhostPath
        $record.inputsStable = $record.inputFingerprintStart -ceq $record.inputFingerprintEnd
    } catch { $record.failure += "; end fingerprint failed: $($_.Exception.Message)" }
    $record.state = 'failed'; Write-Result
    throw
}
