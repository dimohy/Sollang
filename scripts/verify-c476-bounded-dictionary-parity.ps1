[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$ManagedCompiler,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$ManagedCompilerSha256,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$SelfhostCompiler,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$SelfhostCompilerSha256,
    [Parameter(Mandatory, ParameterSetName = 'Run')][string]$OutputDirectory,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$LlvmRoot = '.tools/llvm-22.1.8',
    [string]$StdlibRoot = 'stdlib',
    [ValidateRange(1000, 3600000)][int]$TimeoutMilliseconds = 180000,
    [switch]$ValidateInputsOnly,
    [Parameter(Mandatory, ParameterSetName = 'SelfTest')][switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$verificationProcess = Join-Path $PSScriptRoot 'verification-process.ps1'
. $verificationProcess

$schema = Join-Path $PSScriptRoot 'contracts/c476-bounded-dictionary-parity-result.schema.json'
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$scratchRoot = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
$fixtures = @(
    @{ Id = 'entry'; Kind = 'positive'; Source = 'scripts/probes/dictionary/c476-bounded-populated-entry.slg'; SourceSha = 'A55091E03607BE60189C47A1DBF02F610F2E732EDCA7FE1958994F6AA58C3D92'; Expected = 'scripts/probes/dictionary/c476-bounded-populated-entry.stdout.txt'; ExpectedSha = '6F96C6CEF9A520835C84D27C42538906EB8C2B9203235370722D78ED846E4484' },
    @{ Id = 'return'; Kind = 'positive'; Source = 'scripts/probes/dictionary/c476-bounded-populated-return.slg'; SourceSha = '1DC437ADE5B125F1D1B75F0830CD953D5B0269C4C1F1DBEE2CF668966D45A91E'; Expected = 'scripts/probes/dictionary/c476-bounded-populated-return.stdout.txt'; ExpectedSha = '6F96C6CEF9A520835C84D27C42538906EB8C2B9203235370722D78ED846E4484' },
    @{ Id = 'typed'; Kind = 'positive'; Source = 'scripts/probes/dictionary/c476-bounded-populated-typed.slg'; SourceSha = 'DDB6E4F14A0C11573A33644F04E6A534B9204D6AA40B272E3C64ACBF2BC12FAA'; Expected = 'scripts/probes/dictionary/c476-bounded-populated-typed.stdout.txt'; ExpectedSha = 'CF8129FFDC4423B78E3026A2DFC7410567D7452D06A1B0598157B3851E8D0728' },
    @{ Id = 'overflow'; Kind = 'negative'; Source = 'examples/regression/diagnostics/bounded-dictionary-initializer-overflow.slg'; SourceSha = '0B8543ECA3952025BCD0763D173B8AD1058059CC60E960750C5EE4CBF410459F'; Expected = 'examples/regression/diagnostics/bounded-dictionary-initializer-overflow.stderr.contains.txt'; ExpectedSha = '1A2823502FA7C0D835D9B87C1F9D0B6D33372EF1B0D9574DD146980FB862C6E6' }
)
$scope = 'bounded-root-wait-and-post-exit-CIM-descendant-snapshot-with-creation-time;exited-or-reparented-descendants-not-proven'
$structureScope = 'selfhost-ast-expression-typed-ir-and-user-function-llvm;managed-user-function-llvm-only;source-abi-and-returned-stack-lifetime-not-proven'

function Resolve-Input([string]$Path) {
    $full = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $root $Path)) }
    return (Resolve-Path -LiteralPath $full -ErrorAction Stop).ProviderPath
}
function Get-Sha([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Assert-NoReparse([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $cursor = [IO.Path]::GetPathRoot($full)
    foreach ($part in ($full.Substring($cursor.Length) -split '[\\/]')) {
        if (-not $part) { continue }
        $cursor = Join-Path $cursor $part
        if (-not (Test-Path -LiteralPath $cursor)) { break }
        if (((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "C476_REPARSE_PATH: $cursor" }
    }
}
function Assert-Pin([string]$Path, [string]$Expected) {
    Assert-NoReparse $Path
    if ((Get-Sha $Path) -cne $Expected) { throw "C476_INPUT_SHA_MISMATCH: $Path" }
}
function Assert-OutputUnderScratch([string]$Path) {
    $prefix = $scratchRoot.TrimEnd([char]'\', [char]'/') + [IO.Path]::DirectorySeparatorChar
    if (-not $Path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "C476_OUTPUT_OUTSIDE_SCRATCH: $Path"
    }
}
function Get-InputFingerprint {
    $entries = [Collections.Generic.List[string]]::new()
    foreach ($item in @($managedPath, $managedDll, $managedDeps, $managedRuntimeConfig, $selfhostPath, $assembler, $clang, $linker, $archiver, $librarian, $splitter, $closure, $verificationProcess, $schema, $PSCommandPath, $pwshPath)) {
        Assert-NoReparse $item
        $entries.Add("$item|$(Get-Sha $item)")
    }
    foreach ($fixture in $fixtures) {
        $source = Resolve-Input $fixture.Source
        $expected = Resolve-Input $fixture.Expected
        Assert-Pin $source $fixture.SourceSha
        Assert-Pin $expected $fixture.ExpectedSha
        $entries.Add("$source|$($fixture.SourceSha)")
        $entries.Add("$expected|$($fixture.ExpectedSha)")
    }
    $standardFiles = @(Get-ChildItem -LiteralPath $stdlibPath -Recurse -File -Filter '*.slg' | Sort-Object FullName)
    if ($standardFiles.Count -eq 0) { throw 'C476_STDLIB_EMPTY' }
    foreach ($file in $standardFiles) {
        Assert-NoReparse $file.FullName
        $entries.Add("$($file.FullName)|$(Get-Sha $file.FullName)")
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes(($entries -join "`n") + "`n")
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
}
function Get-UnexpectedNegativeProducts([string]$Directory, [string[]]$AllowedFiles) {
    return @(Get-ChildItem -LiteralPath $Directory -Force | Where-Object {
        $_.PSIsContainer -or $_.FullName -cnotin $AllowedFiles
    })
}
function Test-PositiveBuildStdout([string]$Text, [string]$Compiler, [string]$Exe, [string]$Ll) {
    $content = $Text.TrimEnd("`r", "`n")
    if ($content.Length -eq 0) { return $false }
    $lines = @($content -split "`r?`n")
    if ($Compiler -ceq 'selfhost') {
        return $lines.Count -eq 2 -and $lines[0] -ceq "Kept $Ll" -and $lines[1] -ceq "Wrote $Exe"
    }
    $wrote = '^Wrote ' + [regex]::Escape($Exe) + ' \(([0-9][0-9,]*) bytes\)$'
    if ($lines[-1] -cnotmatch $wrote) { return $false }
    if ([long]($Matches[1] -replace ',', '') -ne (Get-Item -LiteralPath $Exe).Length) { return $false }
    if ($lines.Count -gt 1) {
        foreach ($line in $lines[0..($lines.Count - 2)]) {
            if ($line -cnotmatch '^\[(?:frontend|codegen|semantic|product)-cache\] ' -and
                $line -cnotmatch '^\[native [1-9][0-9]*/[1-9][0-9]*\] optimized partition$') { return $false }
        }
    }
    return $true
}
function Assert-Schema([object]$Record) {
    $json = $Record | ConvertTo-Json -Depth 12
    if (-not (Test-Json -Json $json -SchemaFile $schema -ErrorAction SilentlyContinue)) { throw 'C476_RESULT_SCHEMA_REJECTED' }
    return $json
}
function New-Case([string]$Compiler, [hashtable]$Fixture, [string]$Directory) {
    return [ordered]@{
        compiler = $Compiler; fixture = $Fixture.Id; kind = $Fixture.Kind; state = 'not-run'
        sourceSha256 = $Fixture.SourceSha; expectedSha256 = $Fixture.ExpectedSha
        caseDirectory = $Directory; buildExitCode = $null; closureExitCode = $null
        llvmAsExitCode = $null; runExitCode = $null; buildStdoutMatched = $null; diagnosticMatched = $null
        productsAbsent = $null; exeSha256 = $null; llvmSha256 = $null
        bitcodeSha256 = $null; stdoutSha256 = $null; structureProof = $null; failure = $null
    }
}
function Get-LiveDescendants([int]$RootId, [datetime]$RootCreatedUtc, [object[]]$Records) {
    $seen = [Collections.Generic.HashSet[int]]::new()
    $created = [Collections.Generic.Dictionary[int, datetime]]::new()
    $created.Add($RootId, $RootCreatedUtc)
    $frontier = @($RootId)
    while ($frontier.Count -gt 0) {
        $next = @()
        foreach ($record in $Records) {
            $id = [int]$record.ProcessId
            $parent = [int]$record.ParentProcessId
            if ($frontier -contains $parent -and $id -ne $RootId -and -not $seen.Contains($id)) {
                if ($null -eq $record.CreationDate) { throw "C476_PROCESS_IDENTITY_MISSING: $id" }
                $childCreatedUtc = ([datetime]$record.CreationDate).ToUniversalTime()
                if ($childCreatedUtc -ge $created[$parent]) {
                    [void]$seen.Add($id)
                    $created.Add($id, $childCreatedUtc)
                    $next += $id
                }
            }
        }
        $frontier = $next
    }
    return @($seen | Sort-Object)
}
function Invoke-Logged([string]$File, [string[]]$Arguments, [string]$Cwd, [string]$Label, [string]$Out, [string]$Err) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $File; $start.WorkingDirectory = $Cwd
    $start.UseShellExecute = $false; $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new(); $process.StartInfo = $start
    $stdout = [IO.File]::Create($Out); $stderr = [IO.File]::Create($Err)
    $started = $false
    try {
        if (-not $process.Start()) { throw "C476_SPAWN_FAILED: $Label" }
        $started = $true
        try { $rootCreatedUtc = $process.StartTime.ToUniversalTime() }
        catch { throw "C476_PROCESS_IDENTITY_FAILED: $Label" }
        $outCopy = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
        $errCopy = $process.StandardError.BaseStream.CopyToAsync($stderr)
        $waitError = $null
        try { Wait-VerificationProcess -Process $process -Description $Label -TimeoutMilliseconds $TimeoutMilliseconds }
        catch { $waitError = $_ }
        if (-not $process.WaitForExit(0)) {
            try { $process.Kill($true) } catch { try { $process.Kill() } catch { } }
            if (-not $process.WaitForExit(5000)) {
                [void]$script:orphans.Add($process.Id)
                throw "C476_ROOT_SURVIVED: $($process.Id)"
            }
        }
        try { $descendants = @(Get-LiveDescendants $process.Id $rootCreatedUtc @(Get-CimInstance Win32_Process -ErrorAction Stop)) }
        catch { throw "C476_PROCESS_INSPECTION_FAILED: $($_.Exception.Message)" }
        if ($descendants.Count -gt 0) {
            foreach ($id in $descendants) { [void]$script:orphans.Add($id) }
            throw "C476_LIVE_DESCENDANTS: $($descendants -join ',')"
        }
        $drain = [Threading.Tasks.Task]::WhenAll([Threading.Tasks.Task[]]@($outCopy, $errCopy))
        if (-not $drain.Wait(5000)) { throw "C476_LOG_DRAIN_TIMEOUT: $Label" }
        $drain.GetAwaiter().GetResult(); $stdout.Flush(); $stderr.Flush()
        if ($null -ne $waitError) { throw $waitError }
        return $process.ExitCode
    } finally {
        if ($started -and -not $process.WaitForExit(0)) {
            try { $process.Kill($true) } catch { try { $process.Kill() } catch { } }
            if (-not $process.WaitForExit(5000)) { [void]$script:orphans.Add($process.Id) }
        }
        $process.Dispose(); $stdout.Dispose(); $stderr.Dispose()
    }
}
function Test-Warning([string]$Text) {
    return $Text -match '(?im)^\s*(?:warning(?:\s|:)|note(?:\s|:)|sollang:\s*(?:warning|note)(?:\s|:))'
}
function Test-BytesEqual([byte[]]$Left, [byte[]]$Right) {
    if ($Left.Length -ne $Right.Length) { return $false }
    for ($index = 0; $index -lt $Left.Length; $index++) {
        if ($Left[$index] -ne $Right[$index]) { return $false }
    }
    return $true
}
function Get-TextSha([string]$Value) {
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Value)))
}
function Get-BoundedTypeProof([string]$AstText, [string]$ExpressionText, [string]$IrText) {
    $literalNodes = @([regex]::Matches($AstText, '(?m)^ast source (?<source>\d+) node (?<ast>\d+) kind 38\b[^\r\n]*$'))
    if ($literalNodes.Count -ne 1) { throw "C476_STRUCTURE_AST_LITERAL_COUNT: $($literalNodes.Count)" }
    $source = [int]$literalNodes[0].Groups['source'].Value
    $ast = [int]$literalNodes[0].Groups['ast'].Value
    $expressionLines = @($ExpressionText -split '\r?\n' | Where-Object { $_ -match "^expression \d+ source $source ast $ast kind 38\b" })
    $irLines = @($IrText -split '\r?\n' | Where-Object { $_ -match "^node \d+ kind 16\b.*\bsource $source ast $ast\b" })
    if ($expressionLines.Count -ne 1 -or $irLines.Count -ne 1) {
        throw "C476_STRUCTURE_AST_JOIN: expression=$($expressionLines.Count) ir=$($irLines.Count) source=$source ast=$ast"
    }
    $expressionType = [regex]::Match($expressionLines[0], ' type (?<id>\d+)/(?<kind>\d+)/-?\d+/-?\d+/-?\d+/-?\d+/-?\d+/(?<length>-?\d+) status 0$')
    $irType = [regex]::Match($irLines[0], ' type (?<id>\d+)/(?<kind>\d+)/')
    if (-not $expressionType.Success -or -not $irType.Success) { throw 'C476_STRUCTURE_RECORD_FORMAT' }
    $expressionId = [int]$expressionType.Groups['id'].Value
    $expressionKind = [int]$expressionType.Groups['kind'].Value
    $expressionLength = [int]$expressionType.Groups['length'].Value
    $irId = [int]$irType.Groups['id'].Value
    $irKind = [int]$irType.Groups['kind'].Value
    if ($expressionKind -ne 13 -or $expressionLength -ne 3 -or $irKind -ne 13 -or $expressionId -ne $irId) {
        throw "C476_STRUCTURE_BOUNDED_TYPE: source=$source ast=$ast expression=$expressionId/$expressionKind/$expressionLength ir=$irId/$irKind"
    }
    return [ordered]@{ astSource = $source; astNode = $ast; expressionTypeId = $expressionId; expressionTypeKind = $expressionKind; expressionTypeLength = $expressionLength; irTypeId = $irId; irTypeKind = $irKind }
}
function Get-LlvmFunction([string]$LlvmText, [string]$Name) {
    $pattern = '(?ms)^define[^\r\n]*@' + [regex]::Escape($Name) + '\([^\r\n]*\)[^\r\n]*\{\r?\n.*?^\}'
    $matches = @([regex]::Matches($LlvmText, $pattern))
    if ($matches.Count -ne 1) { throw "C476_STRUCTURE_LLVM_FUNCTION: $Name count=$($matches.Count)" }
    return $matches[0].Value
}
function Get-BoundedLlvmProof([string]$LlvmText, [string]$Compiler, [string]$Fixture) {
    [string[]]$functionNames = if ($Compiler -ceq 'managed') { @('sollang_start') } else { @('main') }
    if ($Fixture -ceq 'return') {
        if ($Compiler -ceq 'managed') { $functionNames += 'sollang_fn_makeValues' }
        else {
            $main = Get-LlvmFunction $LlvmText 'main'
            $called = @([regex]::Matches($main, 'call [^\r\n]*@(?<name>sollang_m\d+_s0)\(') | ForEach-Object { $_.Groups['name'].Value } | Select-Object -Unique)
            if ($called.Count -ne 1) { throw "C476_STRUCTURE_RETURN_FUNCTION: $($called.Count)" }
            $functionNames += $called[0]
        }
    }
    $bodies = @($functionNames | ForEach-Object { Get-LlvmFunction $LlvmText $_ })
    $userBody = $bodies -join "`n"
    if ($Compiler -ceq 'selfhost') {
        $stores = @([regex]::Matches($userBody, '(?m)^\s*%(?<id>v\d+)_storage = getelementptr inbounds %sollang\.bounded_dictionary\.t(?<type>\d+), ptr %\k<id>_owner, i32 0, i32 1, i32 0\r?$'))
        if ($stores.Count -ne 1) { throw "C476_STRUCTURE_INLINE_STORAGE: selfhost $Fixture count=$($stores.Count)" }
        $id = $stores[0].Groups['id'].Value
        $boundedType = '%sollang.bounded_dictionary.t' + $stores[0].Groups['type'].Value
        $inline = [regex]::IsMatch($LlvmText, '(?m)^' + [regex]::Escape($boundedType) + ' = type \{ i64, \[[1-9]\d* x i8\] \}\r?$') -and
            [regex]::IsMatch($userBody, '(?m)^\s*%' + [regex]::Escape($id) + '_owner = alloca ' + [regex]::Escape($boundedType) + ', align [1-9]\d*\r?$') -and
            [regex]::IsMatch($userBody, '(?m)^\s*%' + [regex]::Escape($id) + ' = load ' + [regex]::Escape($boundedType) + ', ptr %' + [regex]::Escape($id) + '_owner, align [1-9]\d*\r?$')
        $dynamic = [regex]::IsMatch($userBody, '(?m)^\s*[^\r\n]*\bcall ptr @(malloc|realloc|sollang_malloc)\(')
    } else {
        $stores = @([regex]::Matches($userBody, '(?m)^\s*%(?<id>bounded_dict_storage\d+) = alloca \[[1-9]\d* x i8\], align 8\r?$'))
        if ($stores.Count -ne 1) { throw "C476_STRUCTURE_INLINE_STORAGE: managed $Fixture count=$($stores.Count)" }
        $id = $stores[0].Groups['id'].Value
        $inline = [regex]::IsMatch($userBody, 'getelementptr i8, ptr %' + [regex]::Escape($id) + ', i64 ')
        # These fixed integer-only user functions need no heap allocation.
        # Runtime/stdlib functions outside this function set are deliberately excluded.
        $dynamic = [regex]::IsMatch($userBody, '(?m)^\s*[^\r\n]*\bcall ptr @(malloc|realloc|sollang_malloc)\(')
    }
    if (-not $inline -or $dynamic) { throw "C476_STRUCTURE_DYNAMIC_HEAP: $Compiler $Fixture inline=$inline dynamic=$dynamic" }
    return [ordered]@{ llvmFunctionNames = @($functionNames); llvmBodySha256 = Get-TextSha $userBody; inlineStorageObserved = $inline; dynamicDictionaryHeapAbsent = -not $dynamic }
}
function Write-Result {
    $json = Assert-Schema $record
    $target = Join-Path $outputPath 'result.json'
    $temporary = "$target.tmp-$([guid]::NewGuid().ToString('N'))"
    $backup = "$target.backup-$([guid]::NewGuid().ToString('N'))"
    $published = $false
    try {
        [IO.File]::WriteAllText($temporary, "$json`n", [Text.UTF8Encoding]::new($false))
        if ([IO.File]::Exists($target)) { [IO.File]::Replace($temporary, $target, $backup) }
        else { [IO.File]::Move($temporary, $target) }
        $published = $true
    } finally {
        if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
        if ($published -and [IO.File]::Exists($backup)) { [IO.File]::Delete($backup) }
    }
}

if ($SelfTest) {
    Assert-OutputUnderScratch (Join-Path $scratchRoot 'bounded-parity-selftest')
    $outsideRejected = $false
    try { Assert-OutputUnderScratch (Join-Path (Split-Path -Parent $scratchRoot) 'scratch-sibling/bounded-parity-selftest') }
    catch { $outsideRejected = $_.Exception.Message -match '^C476_OUTPUT_OUTSIDE_SCRATCH:' }
    if (-not $outsideRejected) { throw 'C476_SELFTEST_OUTPUT_SCOPE_FAILED' }
    $selftestDirectory = Join-Path ([IO.Path]::GetTempPath()) ('c476-bounded-parity-' + [guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($selftestDirectory)
    try {
        $testOut = Join-Path $selftestDirectory 'build.stdout.txt'
        $testErr = Join-Path $selftestDirectory 'build.stderr.txt'
        [IO.File]::WriteAllText($testOut, '')
        [IO.File]::WriteAllText($testErr, '')
        if (@(Get-UnexpectedNegativeProducts $selftestDirectory @($testOut, $testErr)).Count -ne 0) { throw 'C476_SELFTEST_CLEAN_NEGATIVE_REJECTED' }
        $leakedLock = Join-Path $selftestDirectory 'probe.exe.sollang-txn-lock'
        [IO.File]::WriteAllText($leakedLock, 'lock')
        if (@(Get-UnexpectedNegativeProducts $selftestDirectory @($testOut, $testErr)).Count -ne 1) { throw 'C476_SELFTEST_LEAKED_LOCK_ACCEPTED' }
        [IO.File]::Delete($leakedLock)
        $testExe = Join-Path $selftestDirectory 'probe.exe'
        $testLl = "$testExe.ll"
        [IO.File]::WriteAllBytes($testExe, [byte[]]@(1, 2, 3, 4))
        if (-not (Test-PositiveBuildStdout "Kept $testLl`nWrote $testExe`n" 'selfhost' $testExe $testLl) -or
            -not (Test-PositiveBuildStdout "[frontend-cache] cold`nWrote $testExe (4 bytes)`n" 'managed' $testExe $testLl) -or
            -not (Test-PositiveBuildStdout "[native 1/2] optimized partition`n[product-cache] rebuilt`nWrote $testExe (4 bytes)`n" 'managed' $testExe $testLl) -or
            (Test-PositiveBuildStdout "Wrote $testExe (5 bytes)`n" 'managed' $testExe $testLl)) {
            throw 'C476_SELFTEST_POSITIVE_STDOUT_CONTRACT_FAILED'
        }
        $script:orphans = [Collections.Generic.HashSet[int]]::new()
        $testPwsh = (Get-Process -Id $PID).Path
        $exitCode = Invoke-Logged $testPwsh @('-NoProfile', '-Command', 'exit 7') $selftestDirectory 'injected closure failure' (Join-Path $selftestDirectory 'closure.stdout.txt') (Join-Path $selftestDirectory 'closure.stderr.txt')
        if ($exitCode -ne 7 -or $script:orphans.Count -ne 0) { throw 'C476_SELFTEST_CLOSURE_EXIT_LOST' }
    } finally {
        [IO.Directory]::Delete($selftestDirectory, $true)
    }
    $created = [datetime]::SpecifyKind([datetime]'2026-09-24T00:00:00', [DateTimeKind]::Utc)
    $sample = @(
        [pscustomobject]@{ ProcessId = 101; ParentProcessId = 100; CreationDate = $created.AddSeconds(1) },
        [pscustomobject]@{ ProcessId = 102; ParentProcessId = 101; CreationDate = $created.AddSeconds(2) },
        [pscustomobject]@{ ProcessId = 103; ParentProcessId = 100; CreationDate = $created.AddSeconds(-1) }
    )
    $descendants = @(Get-LiveDescendants 100 $created $sample)
    if ($descendants.Count -ne 2 -or $descendants[0] -ne 101 -or $descendants[1] -ne 102) {
        throw "C476_SELFTEST_PROCESS_IDENTITY_FAILED: $($descendants.Count) [$($descendants -join ',')]"
    }
    if (-not (Test-BytesEqual ([byte[]]@(1, 2)) ([byte[]]@(1, 2))) -or
        (Test-BytesEqual ([byte[]]@(1, 2)) ([byte[]]@(1, 3))) -or
        (Test-BytesEqual ([byte[]]@(1, 2)) ([byte[]]@(1, 2, 3)))) {
        throw 'C476_SELFTEST_BYTE_COMPARISON_FAILED'
    }
    $sampleAst = 'ast source 0 node 3 kind 38 parent 2 start 87 length 19 tokens 7/16 payload 7 operator -1 rule 93 flags 0'
    $sampleExpression = 'expression 20 source 0 ast 3 kind 38 parent 2 start 87 type 27/13/-1/-1/-1/2/2/3 status 0'
    $sampleIr = 'node 2 kind 16 parent 1 source 0 ast 3 symbol -1 target -1 type 27/13/15/2/2/3 payload 7 opcode 3 operands 3/-1/-1 flags 0'
    $sampleType = Get-BoundedTypeProof $sampleAst $sampleExpression $sampleIr
    if ($sampleType.expressionTypeKind -ne 13 -or $sampleType.expressionTypeLength -ne 3 -or $sampleType.irTypeKind -ne 13) {
        throw 'C476_SELFTEST_BOUNDED_TYPE_REJECTED'
    }
    $dynamicTypeRejected = $false
    try { [void](Get-BoundedTypeProof $sampleAst ($sampleExpression.Replace('/13/', '/5/')) $sampleIr) }
    catch { $dynamicTypeRejected = $_.Exception.Message -match '^C476_STRUCTURE_BOUNDED_TYPE:' }
    if (-not $dynamicTypeRejected) { throw 'C476_SELFTEST_DYNAMIC_TYPE_ACCEPTED' }
    $sampleLlvm = "%sollang.bounded_dictionary.t27 = type { i64, [160 x i8] }`ndefine i32 @main() {`nentry:`n  %v17_owner = alloca %sollang.bounded_dictionary.t27, align 8`n  %v17_storage = getelementptr inbounds %sollang.bounded_dictionary.t27, ptr %v17_owner, i32 0, i32 1, i32 0`n  %v17 = load %sollang.bounded_dictionary.t27, ptr %v17_owner, align 8`n  ret i32 0`n}`n"
    $sampleLlvmProof = Get-BoundedLlvmProof $sampleLlvm 'selfhost' 'entry'
    if (-not $sampleLlvmProof.inlineStorageObserved -or -not $sampleLlvmProof.dynamicDictionaryHeapAbsent) { throw 'C476_SELFTEST_INLINE_STORAGE_REJECTED' }
    $dynamicLlvmRejected = $false
    try { [void](Get-BoundedLlvmProof ($sampleLlvm.Replace('  ret i32 0', "  %heap = call ptr @malloc(i64 15)`n  ret i32 0")) 'selfhost' 'entry') }
    catch { $dynamicLlvmRejected = $_.Exception.Message -match '^C476_STRUCTURE_DYNAMIC_HEAP:' }
    if (-not $dynamicLlvmRejected) { throw 'C476_SELFTEST_DYNAMIC_LLVM_ACCEPTED' }
    $a = 'A' * 64
    $cases = @()
    foreach ($compiler in @('managed', 'selfhost')) {
        foreach ($fixture in $fixtures) {
            $case = New-Case $compiler $fixture 'case'
            $case.state = 'passed'; $case.buildExitCode = 0; $case.buildStdoutMatched = $true; $case.failure = $null
            if ($fixture.Kind -ceq 'positive') {
                $case.closureExitCode = 0; $case.llvmAsExitCode = 0; $case.runExitCode = 0
                $case.exeSha256 = $a; $case.llvmSha256 = $a; $case.bitcodeSha256 = $a; $case.stdoutSha256 = $a
                $case.structureProof = [ordered]@{
                    astSource = $(if ($compiler -ceq 'selfhost') { 0 } else { $null })
                    astNode = $(if ($compiler -ceq 'selfhost') { 3 } else { $null })
                    expressionTypeId = $(if ($compiler -ceq 'selfhost') { 27 } else { $null })
                    expressionTypeKind = $(if ($compiler -ceq 'selfhost') { 13 } else { $null })
                    expressionTypeLength = $(if ($compiler -ceq 'selfhost') { 3 } else { $null })
                    irTypeId = $(if ($compiler -ceq 'selfhost') { 27 } else { $null })
                    irTypeKind = $(if ($compiler -ceq 'selfhost') { 13 } else { $null })
                    astOutputSha256 = $(if ($compiler -ceq 'selfhost') { $a } else { $null })
                    expressionOutputSha256 = $(if ($compiler -ceq 'selfhost') { $a } else { $null })
                    irOutputSha256 = $(if ($compiler -ceq 'selfhost') { $a } else { $null })
                    llvmFunctionNames = @('main'); llvmBodySha256 = $a
                    inlineStorageObserved = $true; dynamicDictionaryHeapAbsent = $true
                }
            } else { $case.buildExitCode = 1; $case.diagnosticMatched = $true; $case.productsAbsent = $true }
            $cases += $case
        }
    }
    $record = [ordered]@{
        schemaVersion = 1; gate = 'c476-bounded-dictionary-parity'; state = 'passed'
        total = 8; completed = 8; passed = 8
        managedCompilerSha256 = $a; managedDllSha256 = $a; selfhostCompilerSha256 = $a
        inputFingerprintStart = $a; inputFingerprintEnd = $a; inputsStable = $true
        processObservationScope = $scope; structureObservationScope = $structureScope
        orphanProcessIds = @(); cases = $cases
        failureId = $null; failure = $null
    }
    [void](Assert-Schema $record)
    $cases[1].fixture = 'entry'
    if (Test-Json -Json ($record | ConvertTo-Json -Depth 12) -SchemaFile $schema -ErrorAction SilentlyContinue) { throw 'C476_SELFTEST_DUPLICATE_CASE_ACCEPTED' }
    $cases[1].fixture = 'return'
    $cases[3].diagnosticMatched = $false
    if (Test-Json -Json ($record | ConvertTo-Json -Depth 12) -SchemaFile $schema -ErrorAction SilentlyContinue) { throw 'C476_SELFTEST_MISSING_DIAGNOSTIC_ACCEPTED' }
    $cases[3].diagnosticMatched = $true
    $cases[3].buildStdoutMatched = $false
    if (Test-Json -Json ($record | ConvertTo-Json -Depth 12) -SchemaFile $schema -ErrorAction SilentlyContinue) { throw 'C476_SELFTEST_NEGATIVE_STDOUT_ACCEPTED' }
    $cases[3].buildStdoutMatched = $true
    $savedStructureProof = $cases[0].structureProof
    $cases[0].structureProof = $null
    if (Test-Json -Json ($record | ConvertTo-Json -Depth 12) -SchemaFile $schema -ErrorAction SilentlyContinue) { throw 'C476_SELFTEST_MISSING_STRUCTURE_ACCEPTED' }
    $cases[0].structureProof = $savedStructureProof
    $cases[4].structureProof.expressionTypeKind = 5
    if (Test-Json -Json ($record | ConvertTo-Json -Depth 12) -SchemaFile $schema -ErrorAction SilentlyContinue) { throw 'C476_SELFTEST_DYNAMIC_STRUCTURE_ACCEPTED' }
    $cases[4].structureProof.expressionTypeKind = 13
    $record.orphanProcessIds = @(1234)
    if (Test-Json -Json ($record | ConvertTo-Json -Depth 12) -SchemaFile $schema -ErrorAction SilentlyContinue) { throw 'C476_SELFTEST_ORPHAN_ACCEPTED' }
    $record.orphanProcessIds = @()
    $resultTestDirectory = Join-Path ([IO.Path]::GetTempPath()) ('c476-bounded-result-' + [guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($resultTestDirectory)
    try {
        $outputPath = $resultTestDirectory
        Write-Result
        $record.state = 'failed'; $record.failureId = 'C476_SELFTEST_FAILURE'; $record.failure = 'injected failure'
        Write-Result
        $persisted = Get-Content -LiteralPath (Join-Path $resultTestDirectory 'result.json') -Raw | ConvertFrom-Json
        if ($persisted.state -cne 'failed' -or $persisted.failureId -cne 'C476_SELFTEST_FAILURE' -or
            @(Get-ChildItem -LiteralPath $resultTestDirectory -Force).Count -ne 1) {
            throw 'C476_SELFTEST_FAILED_RESULT_PERSISTENCE_FAILED'
        }
    } finally {
        [IO.Directory]::Delete($resultTestDirectory, $true)
    }
    Write-Output 'C476_BOUNDED_PARITY_SELFTEST_PASS: schema, artifact inventory, build stdout, output scope, process identity, bounded type and inline LLVM controls; compilers not run'
    return
}

$managedPath = Resolve-Input $ManagedCompiler
$managedDll = Join-Path (Split-Path -Parent $managedPath) 'Sollang.Compiler.dll'
$managedDeps = Join-Path (Split-Path -Parent $managedPath) 'Sollang.Compiler.deps.json'
$managedRuntimeConfig = Join-Path (Split-Path -Parent $managedPath) 'Sollang.Compiler.runtimeconfig.json'
$selfhostPath = Resolve-Input $SelfhostCompiler
$pwshPath = Resolve-Input (Get-Process -Id $PID).Path
$stdlibPath = Resolve-Input $StdlibRoot
$llvmRootPath = Resolve-Input $LlvmRoot
$assembler = Resolve-Input (Join-Path $llvmRootPath 'bin/llvm-as.exe')
$clang = Resolve-Input (Join-Path $llvmRootPath 'bin/clang.exe')
$linker = Resolve-Input (Join-Path $llvmRootPath 'bin/lld-link.exe')
$archiver = Resolve-Input (Join-Path $llvmRootPath 'bin/llvm-ar.exe')
$librarian = Resolve-Input (Join-Path $llvmRootPath 'bin/llvm-lib.exe')
$splitter = Resolve-Input (Join-Path $llvmRootPath 'bin/llvm-split.exe')
$closure = Resolve-Input (Join-Path $PSScriptRoot 'verify-llvm-direct-call-closure.ps1')
$outputPath = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $root $OutputDirectory }))
Assert-OutputUnderScratch $outputPath
Assert-NoReparse $outputPath
if (-not (Test-Path -LiteralPath (Split-Path -Parent $outputPath) -PathType Container)) { throw 'C476_OUTPUT_PARENT_MISSING' }
Assert-Pin $managedPath $ManagedCompilerSha256
Assert-Pin $selfhostPath $SelfhostCompilerSha256
Assert-NoReparse $managedDll
$managedDllSha = Get-Sha $managedDll
$startFingerprint = Get-InputFingerprint
if (Test-Path -LiteralPath $outputPath) { throw "C476_OUTPUT_EXISTS: $outputPath" }
if ($ValidateInputsOnly) {
    Write-Output "C476_BOUNDED_PARITY_INPUTS_VALID: 8 fixed cases; fingerprint $startFingerprint; no compiler run"
    return
}
[void][IO.Directory]::CreateDirectory($outputPath)
$script:orphans = [Collections.Generic.HashSet[int]]::new()
$cases = @()
foreach ($compiler in @('managed', 'selfhost')) {
    foreach ($fixture in $fixtures) {
        $cases += (New-Case $compiler $fixture (Join-Path $outputPath "$compiler-$($fixture.Id)"))
    }
}
$record = [ordered]@{
    schemaVersion = 1; gate = 'c476-bounded-dictionary-parity'; state = 'running'
    total = 8; completed = 0; passed = 0
    managedCompilerSha256 = $ManagedCompilerSha256; managedDllSha256 = $managedDllSha
    selfhostCompilerSha256 = $SelfhostCompilerSha256
    inputFingerprintStart = $startFingerprint; inputFingerprintEnd = $null; inputsStable = $false
    processObservationScope = $scope; structureObservationScope = $structureScope
    orphanProcessIds = @(); cases = $cases
    failureId = $null; failure = $null
}
Write-Result
try {
    for ($index = 0; $index -lt $cases.Count; $index++) {
        $case = $cases[$index]
        $fixture = $fixtures[$index % 4]
        if ((Get-InputFingerprint) -cne $startFingerprint) { throw 'C476_INPUT_DRIFT' }
        [void][IO.Directory]::CreateDirectory($case.caseDirectory)
        $case.state = 'running'; Write-Result
        $exe = Join-Path $case.caseDirectory 'probe.exe'
        $ll = if ($case.compiler -ceq 'managed') { Join-Path $case.caseDirectory 'probe.ll' } else { "$exe.ll" }
        $bc = Join-Path $case.caseDirectory 'probe.bc'
        $source = Resolve-Input $fixture.Source
        $expected = Resolve-Input $fixture.Expected
        $compilerFile = if ($case.compiler -ceq 'managed') { $managedPath } else { $selfhostPath }
        $arguments = @('build', $source, '-o', $exe, '--target', 'windows-x64', '--llvm', $llvmRootPath)
        if ($case.compiler -ceq 'selfhost') { $arguments += @('--stdlib', $stdlibPath, '--jobs', '1') }
        $arguments += @('-O1', '--keep-temps')
        $buildOut = Join-Path $case.caseDirectory 'build.stdout.txt'
        $buildErr = Join-Path $case.caseDirectory 'build.stderr.txt'
        $case.buildExitCode = Invoke-Logged $compilerFile $arguments $case.caseDirectory "$($case.compiler) $($case.fixture) build" $buildOut $buildErr
        $buildStdout = [IO.File]::ReadAllText($buildOut)
        $buildStderr = [IO.File]::ReadAllText($buildErr)
        if (Test-Warning ($buildStdout + $buildStderr)) { throw "C476_WARNING_OR_NOTE: $($case.compiler) $($case.fixture)" }
        if ($case.kind -ceq 'negative') {
            $diagnostic = [IO.File]::ReadAllText($expected).TrimEnd("`r", "`n")
            $case.diagnosticMatched = $buildStderr.Contains($diagnostic, [StringComparison]::Ordinal)
            $case.buildStdoutMatched = (Get-Item -LiteralPath $buildOut).Length -eq 0
            $products = @(Get-UnexpectedNegativeProducts $case.caseDirectory @($buildOut, $buildErr))
            $case.productsAbsent = $products.Count -eq 0
            if ($case.buildExitCode -eq 0 -or -not $case.buildStdoutMatched -or -not $case.diagnosticMatched -or -not $case.productsAbsent) {
                throw "C476_NEGATIVE_MISMATCH: $($case.compiler) exit=$($case.buildExitCode) stdout=$($case.buildStdoutMatched) diagnostic=$($case.diagnosticMatched) productsAbsent=$($case.productsAbsent) products=$($products.FullName -join ',')"
            }
        } else {
            if ($case.buildExitCode -ne 0 -or $buildStderr.Length -ne 0 -or -not (Test-Path -LiteralPath $exe -PathType Leaf) -or -not (Test-Path -LiteralPath $ll -PathType Leaf)) {
                throw "C476_POSITIVE_BUILD_FAILED: $($case.compiler) $($case.fixture) exit=$($case.buildExitCode) stderr=$buildStderr"
            }
            $case.buildStdoutMatched = Test-PositiveBuildStdout $buildStdout $case.compiler $exe $ll
            if (-not $case.buildStdoutMatched) { throw "C476_BUILD_STDOUT_MISMATCH: $($case.compiler) $($case.fixture)" }
            $llvmProof = Get-BoundedLlvmProof ([IO.File]::ReadAllText($ll)) $case.compiler $case.fixture
            $typeProof = $null
            $astSha = $null; $expressionSha = $null; $irSha = $null
            if ($case.compiler -ceq 'selfhost') {
                $probeText = @{}
                foreach ($probe in @(
                    @{ Name = 'ast'; Command = 'ast-nodes' },
                    @{ Name = 'expression'; Command = 'expression-type-records' },
                    @{ Name = 'ir'; Command = 'typed-ir-nodes' }
                )) {
                    $probeOut = Join-Path $case.caseDirectory "$($probe.Name).stdout.txt"
                    $probeErr = Join-Path $case.caseDirectory "$($probe.Name).stderr.txt"
                    $probeExit = Invoke-Logged $selfhostPath @($probe.Command, $source) $case.caseDirectory "$($case.fixture) $($probe.Name) structure" $probeOut $probeErr
                    if ($probeExit -ne 0 -or (Get-Item -LiteralPath $probeErr).Length -ne 0 -or (Get-Item -LiteralPath $probeOut).Length -eq 0) {
                        throw "C476_STRUCTURE_PROBE_FAILED: $($case.fixture) $($probe.Name) exit=$probeExit"
                    }
                    $probeText[$probe.Name] = [IO.File]::ReadAllText($probeOut)
                }
                $typeProof = Get-BoundedTypeProof $probeText.ast $probeText.expression $probeText.ir
                $astSha = Get-Sha (Join-Path $case.caseDirectory 'ast.stdout.txt')
                $expressionSha = Get-Sha (Join-Path $case.caseDirectory 'expression.stdout.txt')
                $irSha = Get-Sha (Join-Path $case.caseDirectory 'ir.stdout.txt')
            }
            $case.structureProof = [ordered]@{
                astSource = $(if ($null -ne $typeProof) { $typeProof.astSource } else { $null })
                astNode = $(if ($null -ne $typeProof) { $typeProof.astNode } else { $null })
                expressionTypeId = $(if ($null -ne $typeProof) { $typeProof.expressionTypeId } else { $null })
                expressionTypeKind = $(if ($null -ne $typeProof) { $typeProof.expressionTypeKind } else { $null })
                expressionTypeLength = $(if ($null -ne $typeProof) { $typeProof.expressionTypeLength } else { $null })
                irTypeId = $(if ($null -ne $typeProof) { $typeProof.irTypeId } else { $null })
                irTypeKind = $(if ($null -ne $typeProof) { $typeProof.irTypeKind } else { $null })
                astOutputSha256 = $astSha; expressionOutputSha256 = $expressionSha; irOutputSha256 = $irSha
                llvmFunctionNames = $llvmProof.llvmFunctionNames; llvmBodySha256 = $llvmProof.llvmBodySha256
                inlineStorageObserved = $llvmProof.inlineStorageObserved
                dynamicDictionaryHeapAbsent = $llvmProof.dynamicDictionaryHeapAbsent
            }
            Write-Result
            $closureOut = Join-Path $case.caseDirectory 'closure.stdout.txt'
            $closureErr = Join-Path $case.caseDirectory 'closure.stderr.txt'
            $case.closureExitCode = Invoke-Logged $pwshPath @('-NoProfile', '-File', $closure, '-LlvmPath', $ll) $case.caseDirectory "$($case.compiler) $($case.fixture) closure" $closureOut $closureErr
            $closureText = [IO.File]::ReadAllText($closureOut).TrimEnd("`r", "`n")
            if ($case.closureExitCode -ne 0 -or $closureText -cne "[LLVM direct-call closure] PASS $ll" -or (Get-Item -LiteralPath $closureErr).Length -ne 0) {
                throw "C476_CLOSURE_FAILED: $($case.compiler) $($case.fixture) exit=$($case.closureExitCode)"
            }
            $asOut = Join-Path $case.caseDirectory 'llvm-as.stdout.txt'
            $asErr = Join-Path $case.caseDirectory 'llvm-as.stderr.txt'
            $case.llvmAsExitCode = Invoke-Logged $assembler @($ll, '-o', $bc) $case.caseDirectory "$($case.compiler) $($case.fixture) llvm-as" $asOut $asErr
            if ($case.llvmAsExitCode -ne 0 -or (Get-Item $asOut).Length -ne 0 -or (Get-Item $asErr).Length -ne 0) { throw "C476_LLVM_AS_FAILED: $($case.compiler) $($case.fixture)" }
            $runOut = Join-Path $case.caseDirectory 'run.stdout.txt'
            $runErr = Join-Path $case.caseDirectory 'run.stderr.txt'
            $case.runExitCode = Invoke-Logged $exe @() $case.caseDirectory "$($case.compiler) $($case.fixture) native" $runOut $runErr
            $actualBytes = [IO.File]::ReadAllBytes($runOut)
            $expectedBytes = [IO.File]::ReadAllBytes($expected)
            if ($case.runExitCode -ne 0 -or (Get-Item $runErr).Length -ne 0 -or -not (Test-BytesEqual $actualBytes $expectedBytes)) {
                throw "C476_NATIVE_OUTPUT_MISMATCH: $($case.compiler) $($case.fixture)"
            }
            $case.exeSha256 = Get-Sha $exe; $case.llvmSha256 = Get-Sha $ll
            $case.bitcodeSha256 = Get-Sha $bc; $case.stdoutSha256 = Get-Sha $runOut
        }
        $case.state = 'passed'
        $record.completed++; $record.passed++
        Write-Result
    }
    $record.inputFingerprintEnd = Get-InputFingerprint
    $record.inputsStable = $record.inputFingerprintStart -ceq $record.inputFingerprintEnd
    if (-not $record.inputsStable) { throw 'C476_INPUT_DRIFT' }
    $record.state = 'passed'
    Write-Result
    Write-Output "C476_BOUNDED_PARITY_PASS: 8/8 exact cases; $(Join-Path $outputPath 'result.json')"
} catch {
    $message = $_.Exception.Message
    if ($null -ne $case -and $case.state -ceq 'running') { $case.state = 'failed'; $case.failure = $message; $record.completed++ }
    $record.orphanProcessIds = @($script:orphans | Sort-Object)
    $record.failureId = if ($script:orphans.Count -gt 0) { 'C476_PROCESS_ORPHANED' }
        elseif ($message -match '^C476_[A-Z_]+') { ($message -split ':')[0] }
        else { 'C476_GATE_FAILED' }
    $record.failure = $message
    try {
        $record.inputFingerprintEnd = Get-InputFingerprint
        $record.inputsStable = $record.inputFingerprintStart -ceq $record.inputFingerprintEnd
    } catch { $record.failure += "; fingerprint failure: $($_.Exception.Message)" }
    $record.state = 'failed'
    Write-Result
    throw
}
