[CmdletBinding()]
param(
    [string]$Compiler = '',
    [ValidatePattern('^$|^[A-Fa-f0-9]{64}$')]
    [string]$ExpectedCompilerSha256 = '',
    [string]$OutputDirectory = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $root 'scripts/verification-process.ps1')

$compilerWasExplicit = -not [string]::IsNullOrWhiteSpace($Compiler)
if ([string]::IsNullOrWhiteSpace($Compiler)) {
    $Compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
} elseif (-not [IO.Path]::IsPathRooted($Compiler)) {
    $Compiler = Join-Path $root $Compiler
}
$Compiler = (Resolve-Path -LiteralPath $Compiler).Path
if ($compilerWasExplicit -and [string]::IsNullOrWhiteSpace($ExpectedCompilerSha256)) {
    throw 'C92 explicit -Compiler requires -ExpectedCompilerSha256'
}
$ExpectedCompilerSha256 = $ExpectedCompilerSha256.ToUpperInvariant()
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $root ('artifacts/scratch/c92-additional-move-' + [guid]::NewGuid().ToString('N'))
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null

$schema = Join-Path $root 'scripts/contracts/additional-move-ownership-result.schema.json'
$auditContractPath = Join-Path $root 'scripts/contracts/p1206-deterministic-allocation-audit.json'
$closure = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$auditShim = Join-Path $root 'tests/native-interop/owned_array_audit.c'
$deterministicRandomShim = Join-Path $root 'tests/native-interop/p1206_deterministic_bcrypt_audit.c'
$llvmRoot = Join-Path $root '.tools/llvm-22.1.8'
$llvmAs = Join-Path $llvmRoot 'bin/llvm-as.exe'
$clang = Join-Path $llvmRoot 'bin/clang.exe'
$auditContractText = [IO.File]::ReadAllText($auditContractPath)
$auditContract = $auditContractText | ConvertFrom-Json
if ($auditContract.schemaVersion -ne 1 -or
    $auditContract.mode -cne 'p1206-deterministic-allocation-audit' -or
    $auditContract.provider -cne 'audit-only-xorshift64' -or
    [string]$auditContract.seedHex -notmatch '^[A-F0-9]{16}$' -or
    [int]$auditContract.auditRuns -lt 3 -or
    [int]$auditContract.expectedAllocationCount -le 0 -or
    [int]$auditContract.expectedReleaseCount -ne [int]$auditContract.expectedAllocationCount -or
    [int]$auditContract.expectedInvalidReleaseCount -ne 0) {
    throw 'P1206 deterministic allocation audit contract is invalid'
}
$seedBytes = [Text.Encoding]::UTF8.GetBytes([string]$auditContract.seedHex)
$seedSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($seedBytes))
if ($seedSha256 -cne [string]$auditContract.seedSha256) {
    throw "P1206 deterministic seed hash mismatch: expected=$($auditContract.seedSha256) actual=$seedSha256"
}
$cases = @(
    [ordered]@{
        id = 'P1207'
        kind = 'positive'
        source = 'examples/regression/1207-enum-owned-payload-projected-queue.slg'
        expected = 'examples/regression/expected/1207-enum-owned-payload-projected-queue.stdout.txt'
    },
    [ordered]@{
        id = 'P1206'
        kind = 'positive'
        source = 'examples/regression/1206-quic-bidirectional-multi-stream-routing.slg'
        expected = 'examples/regression/expected/1206-quic-bidirectional-multi-stream-routing.stdout.txt'
        auditAllocations = [int]$auditContract.expectedAllocationCount
    },
    [ordered]@{
        id = 'N1'
        kind = 'negative'
        source = 'examples/regression/diagnostics/additional-move-owner-reuse.slg'
        expected = 'scripts/probes/additional-move-ownership/flow-order-invalid.stderr.txt'
    },
    [ordered]@{
        id = 'N2'
        kind = 'negative'
        source = 'scripts/probes/additional-move-ownership/direct-owner-reuse.slg'
        expected = 'scripts/probes/additional-move-ownership/direct-owner-reuse.stderr.txt'
    },
    [ordered]@{
        id = 'P2'
        kind = 'positive'
        source = 'scripts/probes/additional-move-ownership/projected-sibling-retained.slg'
        expected = 'scripts/probes/additional-move-ownership/projected-sibling-retained.stdout.txt'
        auditAllocations = 4
    },
    [ordered]@{
        id = 'N3'
        kind = 'negative'
        source = 'scripts/probes/additional-move-ownership/projected-path-reuse.slg'
        expected = 'scripts/probes/additional-move-ownership/projected-path-reuse.stderr.txt'
    }
)

function Hash([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function ExactBytes([byte[]]$Left, [byte[]]$Right) {
    if ($Left.Length -ne $Right.Length) { return $false }
    for ($index = 0; $index -lt $Left.Length; $index++) {
        if ($Left[$index] -ne $Right[$index]) { return $false }
    }
    return $true
}

function Normalize([string]$Text) {
    return $Text.Replace("`r`n", "`n").TrimEnd()
}

function Run([string]$File, [string[]]$Arguments, [string]$Description) {
    return Invoke-VerificationProcessCapture `
        -FilePath $File `
        -ArgumentList $Arguments `
        -WorkingDirectory $root `
        -Description $Description `
        -TimeoutMilliseconds 120000
}

function Write-Log([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

$paths = [ordered]@{
    compiler = $Compiler
    schema = $schema
    verifier = $PSCommandPath
    closure = $closure
    auditShim = $auditShim
    auditContract = $auditContractPath
    deterministicRandomShim = $deterministicRandomShim
    llvmAs = $llvmAs
    clang = $clang
}
foreach ($case in $cases) {
    $paths["source:$($case.id)"] = Join-Path $root $case.source
    $paths["expected:$($case.id)"] = Join-Path $root $case.expected
}
foreach ($entry in $paths.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $entry.Value -PathType Leaf) -or
        (Get-Item -LiteralPath $entry.Value).Length -eq 0) {
        throw "C92 input missing or empty: $($entry.Value)"
    }
}
$hashes = [ordered]@{}
foreach ($entry in $paths.GetEnumerator()) { $hashes[$entry.Key] = Hash $entry.Value }
if (-not [string]::IsNullOrWhiteSpace($ExpectedCompilerSha256) -and
    $hashes.compiler -cne $ExpectedCompilerSha256) {
    throw "C92 compiler hash mismatch: expected=$ExpectedCompilerSha256 actual=$($hashes.compiler)"
}

$results = foreach ($case in $cases) {
    $source = $paths["source:$($case.id)"]
    $prefix = Join-Path $OutputDirectory $case.id
    $exe = "$prefix.exe"
    $ll = "$prefix.ll"
    $item = [ordered]@{
        id = $case.id
        passed = $false
        compileExit = -1
        llvmProduced = $false
        nativeExit = $null
        expectedStdout = $null
        nativeExact = $null
        llvmAsExit = $null
        closureExit = $null
        diagnosticMatched = $null
        auditLinkExit = $null
        auditExit = $null
        expectedAllocationCount = if ($case.Contains('auditAllocations')) { [int]$case.auditAllocations } else { $null }
        allocationCount = $null
        releaseCount = $null
        invalidReleaseCount = $null
        allocationBalanced = $null
        auditRunCount = if ($case.Contains('auditAllocations')) { [int]$auditContract.auditRuns } else { $null }
        deterministicSeedSha256 = if ($case.Contains('auditAllocations')) { $seedSha256 } else { $null }
        deterministicAuditExact = if ($case.Contains('auditAllocations')) { $false } else { $null }
        productionUsesRealBCrypt = if ($case.Contains('auditAllocations')) { $false } else { $null }
        auditUsesDeterministicRandom = if ($case.Contains('auditAllocations')) { $false } else { $null }
        rawStdoutExact = $false
        stdoutSha256 = $null
        stderrSha256 = $null
        warningNoteFree = $false
        diagnosticCount = $null
        auditRuns = @()
        failure = $null
    }
    try {
        $compile = Run 'dotnet' @(
            $Compiler, 'build', $source, '-o', $exe,
            '--target', 'windows-x64', '--llvm', $llvmRoot, '-O1', '--keep-temps'
        ) "$($case.id) compile"
        $item.compileExit = $compile.ExitCode
        $item.llvmProduced = Test-Path -LiteralPath $ll -PathType Leaf
        Write-Log "$prefix.compile.stdout" $compile.Stdout
        Write-Log "$prefix.compile.stderr" $compile.Stderr
        $compileText = $compile.Stdout + $compile.Stderr
        $item.warningNoteFree = $compileText -notmatch '(?im)\b(?:warning|note)\b'
        if ($case.kind -eq 'negative') {
            $expectedText = [IO.File]::ReadAllText($paths["expected:$($case.id)"]).TrimEnd([char[]]@("`r", "`n"))
            $expectedBytes = [Text.UTF8Encoding]::new($false).GetBytes($expectedText + "`r`n")
            $stdoutBytes = [IO.File]::ReadAllBytes("$prefix.compile.stdout")
            $stderrBytes = [IO.File]::ReadAllBytes("$prefix.compile.stderr")
            $item.stdoutSha256 = Hash "$prefix.compile.stdout"
            $item.stderrSha256 = Hash "$prefix.compile.stderr"
            $diagnosticLines = @($compileText.Replace("`r`n", "`n") -split "`n" |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            $item.diagnosticCount = $diagnosticLines.Count
            $item.diagnosticMatched = $diagnosticLines.Count -eq 1 -and
                (ExactBytes $stderrBytes $expectedBytes)
            $item.rawStdoutExact = $stdoutBytes.Length -eq 0
            if ($compile.ExitCode -eq 0) { throw 'negative compiled successfully' }
            if ($item.llvmProduced) { throw 'negative produced LLVM' }
            if (-not $item.diagnosticMatched) { throw "negative diagnostic mismatch: $compileText" }
            if (-not $item.warningNoteFree) { throw 'negative emitted a warning or note beside its diagnostic' }
            $item.passed = $true
        } else {
            if ($compile.ExitCode -ne 0) { throw "positive compile failed: $($compile.Stdout) $($compile.Stderr)" }
            if (-not $item.llvmProduced) { throw 'positive produced no LLVM' }
            if (-not [string]::IsNullOrWhiteSpace($compile.Stderr) -or
                ($compile.Stdout + "`n" + $compile.Stderr) -match '(?im)\b(?:warning|note)\b|(?:semantic )?error(?:\[E\d+\])?:') {
                throw "positive compile emitted a warning, note, or diagnostic: $($compile.Stdout) $($compile.Stderr)"
            }

            $native = Run $exe @() "$($case.id) native"
            $item.nativeExit = $native.ExitCode
            Write-Log "$prefix.native.stdout" $native.Stdout
            Write-Log "$prefix.native.stderr" $native.Stderr
            $expectedBytes = [IO.File]::ReadAllBytes($paths["expected:$($case.id)"])
            $stdoutBytes = [IO.File]::ReadAllBytes("$prefix.native.stdout")
            $stderrBytes = [IO.File]::ReadAllBytes("$prefix.native.stderr")
            $item.stdoutSha256 = Hash "$prefix.native.stdout"
            $item.stderrSha256 = Hash "$prefix.native.stderr"
            $item.rawStdoutExact = ExactBytes $stdoutBytes $expectedBytes
            $item.expectedStdout = [Text.UTF8Encoding]::new($false).GetString($expectedBytes).TrimEnd("`r", "`n")
            $item.nativeExact = $native.ExitCode -eq 0 -and
                $stderrBytes.Length -eq 0 -and $item.rawStdoutExact
            if (-not $item.nativeExact) {
                throw "native exact mismatch: $($native.Stdout) $($native.Stderr)"
            }

            $assembled = Run $llvmAs @($ll, '-o', "$prefix.bc") "$($case.id) llvm-as"
            $item.llvmAsExit = $assembled.ExitCode
            if ($assembled.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($assembled.Stdout + $assembled.Stderr)) {
                throw "llvm-as failed or emitted diagnostics: $($assembled.Stdout) $($assembled.Stderr)"
            }
            $closed = Run 'pwsh' @('-NoProfile', '-File', $closure, '-LlvmPath', $ll) "$($case.id) V004"
            $item.closureExit = $closed.ExitCode
            if ($closed.ExitCode -ne 0) { throw "V004 failed: $($closed.Stdout) $($closed.Stderr)" }

            if ($case.Contains('auditAllocations')) {
                $auditLl = "$prefix.audit.ll"
                $llvmText = [IO.File]::ReadAllText($ll)
                if ($case.id -eq 'P1206' -and ($llvmText -notmatch 'declare dllimport i32 @BCryptGenRandom\(ptr, ptr, i32, i32\)' -or
                    $llvmText -notmatch 'call i32 @BCryptGenRandom\(')) {
                    throw 'P1206 production LLVM does not retain the real BCrypt provider'
                }
                $item.productionUsesRealBCrypt = if ($case.id -eq 'P1206') { $true } else { $null }
                $auditText = $llvmText.Replace('call ptr @sollang_alloc(', 'call ptr @audit_malloc(').Replace('call void @sollang_free(', 'call void @audit_free(').Replace('@sollang_start()', '@slg_program_main()').Replace('declare dllimport i32 @BCryptGenRandom(ptr, ptr, i32, i32)', 'declare i32 @audit_BCryptGenRandom(ptr, ptr, i32, i32)').Replace('call i32 @BCryptGenRandom(', 'call i32 @audit_BCryptGenRandom(')
                $item.auditUsesDeterministicRandom = if ($case.id -eq 'P1206') {
                    $auditText -match 'call i32 @audit_BCryptGenRandom\(' -and
                        $auditText -notmatch 'call i32 @BCryptGenRandom\('
                } else { $null }
                if ($case.id -eq 'P1206' -and -not $item.auditUsesDeterministicRandom) {
                    throw 'P1206 audit LLVM did not isolate the deterministic Random provider'
                }
                $auditText += "`ndeclare ptr @audit_malloc(i64)`ndeclare void @audit_free(ptr)`n"
                Write-Log $auditLl $auditText
                $auditExe = "$prefix.audit.exe"
                $auditLink = Run $clang @(
                    '-Wno-override-module', "-DEXPECTED_ALLOCATIONS=$($case.auditAllocations)",
                    "-DAUDIT_XORSHIFT_SEED=0x$($auditContract.seedHex)ULL",
                    $auditLl, $auditShim, $deterministicRandomShim, '-O1', '-o', $auditExe,
                    '-lws2_32', '-lshell32', '-lbcrypt'
                ) "$($case.id) allocation link"
                $item.auditLinkExit = $auditLink.ExitCode
                if ($auditLink.ExitCode -ne 0) { throw "allocation link failed: $($auditLink.Stdout) $($auditLink.Stderr)" }

                for ($runIndex = 1; $runIndex -le [int]$auditContract.auditRuns; $runIndex++) {
                    $audit = Run $auditExe @() "$($case.id) deterministic allocation execute $runIndex/$($auditContract.auditRuns)"
                    $item.auditExit = $audit.ExitCode
                    $auditOutput = Normalize $audit.Stdout
                    $auditMatch = [regex]::Match($auditOutput, '(?m)^allocations=(?<allocations>\d+),releases=(?<releases>\d+)$')
                    $allocationCount = if ($auditMatch.Success) { [int]$auditMatch.Groups['allocations'].Value } else { $null }
                    $releaseCount = if ($auditMatch.Success) { [int]$auditMatch.Groups['releases'].Value } else { $null }
                    $invalidReleaseCount = [regex]::Matches($audit.Stderr, 'invalid (?:release|realloc):').Count
                    $expectedAuditOutput = $item.expectedStdout + "`nallocations=$($case.auditAllocations),releases=$($case.auditAllocations)"
                    $runExact = $audit.ExitCode -eq 0 -and
                        $allocationCount -eq [int]$case.auditAllocations -and
                        $releaseCount -eq [int]$case.auditAllocations -and
                        $invalidReleaseCount -eq [int]$auditContract.expectedInvalidReleaseCount -and
                        [string]::IsNullOrWhiteSpace($audit.Stderr) -and
                        $auditOutput -ceq $expectedAuditOutput
                    $item.auditRuns += [pscustomobject]@{
                        run = $runIndex
                        exit = $audit.ExitCode
                        allocationCount = $allocationCount
                        releaseCount = $releaseCount
                        invalidReleaseCount = $invalidReleaseCount
                        exact = $runExact
                    }
                    if (-not $runExact) {
                        throw "deterministic allocation audit $runIndex mismatch: $($audit.Stdout) $($audit.Stderr)"
                    }
                }
                $firstAudit = $item.auditRuns[0]
                $item.allocationCount = $firstAudit.allocationCount
                $item.releaseCount = $firstAudit.releaseCount
                $item.invalidReleaseCount = $firstAudit.invalidReleaseCount
                $item.allocationBalanced = $true
                $item.deterministicAuditExact = $true
            }
            $item.passed = $true
        }
    } catch {
        $item.failure = $_.Exception.Message
    }
    [pscustomobject]$item
}

$drift = @()
foreach ($entry in $paths.GetEnumerator()) {
    if ((Hash $entry.Value) -cne $hashes[$entry.Key]) { $drift += $entry.Key }
}
$failures = @($results | Where-Object { -not $_.passed } | ForEach-Object id)
if ($drift.Count -gt 0) { $failures += 'C92_INPUT_DRIFT' }
$failures = @($failures | Select-Object -Unique)
$record = [ordered]@{
    schemaVersion = 2
    mode = 'managed-additional-move-ownership'
    defectId = 'C2026-08-28-92'
    coveredDefectIds = @('C2026-08-28-92', 'C2026-09-13-424')
    status = if ($failures.Count -eq 0) { 'passed' } else { 'failed' }
    completed = @($results | Where-Object passed).Count
    total = 6
    compilerSha256 = $hashes.compiler
    expectedCompilerSha256 = if ([string]::IsNullOrWhiteSpace($ExpectedCompilerSha256)) { $null } else { $ExpectedCompilerSha256 }
    auditContractSha256 = $hashes.auditContract
    deterministicRandomShimSha256 = $hashes.deterministicRandomShim
    deterministicSeedSha256 = $seedSha256
    inputStable = $drift.Count -eq 0
    inputDrift = $drift
    inputHashes = $hashes
    cases = @($results)
    failureIds = $failures
}
$json = ($record | ConvertTo-Json -Depth 8) + "`n"
$resultPath = Join-Path $OutputDirectory 'result.json'
[IO.File]::WriteAllText($resultPath, $json, [Text.UTF8Encoding]::new($false))
if (-not ($json | Test-Json -SchemaFile $schema -ErrorAction Stop)) {
    throw "C92 result schema failure: $resultPath"
}
if ($record.status -ne 'passed') {
    throw "C92 failed: $($failures -join ', '); result=$resultPath"
}
Write-Host "[C92 additional move ownership] PASS 6/6 compiler=$($hashes.compiler) result=$resultPath"
