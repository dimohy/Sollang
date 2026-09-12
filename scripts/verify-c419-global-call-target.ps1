[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [Parameter(Mandatory)]
    [string]$CandidateCompiler
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$managed = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$llvmAs = Join-Path $llvm 'bin/llvm-as.exe'
$clang = Join-Path $llvm 'bin/clang.exe'
$formatter = Join-Path $root 'scripts/format-authoritative-slg.ps1'
$closureVerifier = Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1'
$output = Join-Path $root ('artifacts/scratch/c419-global-call-target-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($output)

$cases = @(
    [pscustomobject]@{
        Id = 'C419-global-inside-inherent'
        Source = Join-Path $root 'scripts/contracts/fixtures/c419-global-call-inside-inherent.slg'
        Expected = Join-Path $root 'scripts/contracts/fixtures/c419-global-call-inside-inherent.stdout.txt'
        Targets = @(
            [pscustomobject]@{ Name = 'scanValue'; CallText = 'scanValue(self, depth)'; Parent = -1; RequireReceiver = $false }
        )
    },
    [pscustomobject]@{
        Id = 'C417-receiver-controls'
        Source = Join-Path $root 'scripts/contracts/fixtures/c417-instance-method-arity-controls.slg'
        Expected = Join-Path $root 'scripts/contracts/fixtures/c417-instance-method-arity-controls.stdout.txt'
        Targets = @(
            [pscustomobject]@{ Name = 'weighted'; CallText = 'counter.weighted(6, 2)'; Parent = -2; RequireReceiver = $true },
            [pscustomobject]@{ Name = 'weighted'; CallText = 'counter -> weighted(4, 1)'; Parent = -2; RequireReceiver = $true },
            [pscustomobject]@{ Name = 'useCounter'; CallText = 'counter -> useCounter'; Parent = -1; RequireReceiver = $true }
        )
    }
)

$CandidateCompiler = [IO.Path]::GetFullPath($CandidateCompiler)
$required = @($managed, $llvmAs, $clang, $formatter, $closureVerifier, $PSCommandPath, $CandidateCompiler)
$required += @($cases | ForEach-Object { $_.Source; $_.Expected })
$inputHashes = [ordered]@{}
foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "C419 verifier input is missing: $path" }
    $inputHashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}

function Normalize([string]$Text) { $Text.Replace("`r`n", "`n").TrimEnd("`n") }

function Invoke-CapturedProcess([string]$FilePath, [string[]]$Arguments) {
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $startInfo.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw "Failed to start C419 verifier process: $FilePath" }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $result = [pscustomobject]@{
        ExitCode = $process.ExitCode
        Stdout = $stdoutTask.GetAwaiter().GetResult()
        Stderr = $stderrTask.GetAwaiter().GetResult()
    }
    $process.Dispose()
    return $result
}

function Find-TargetSymbol {
    param([string]$Symbols, [string]$SourceText, [string]$Name, [int]$ExpectedParent)
    $symbolMatches = [Collections.Generic.List[object]]::new()
    foreach ($line in ($Symbols -split "`r?`n")) {
        if ($line -notmatch '^symbol source (?<module>\d+) local (?<symbol>\d+) kind \d+ parent (?<parent>-?\d+) ast \d+ nameToken -?\d+ span (?<start>-?\d+)/(?<length>-?\d+)$') { continue }
        $start = [int]$Matches.start
        $length = [int]$Matches.length
        if ($start -lt 0 -or $length -lt 0 -or $start + $length -gt $SourceText.Length) { continue }
        $actualParent = [int]$Matches.parent
        $parentMatches = if ($ExpectedParent -eq -2) { $actualParent -ge 0 } else { $actualParent -eq $ExpectedParent }
        if ($SourceText.Substring($start, $length) -ceq $Name -and $parentMatches) {
            $symbolMatches.Add([pscustomobject]@{ Module = [int]$Matches.module; Symbol = [int]$Matches.symbol })
        }
    }
    if ($symbolMatches.Count -ne 1) { throw "Expected one symbol '$Name' with parent $ExpectedParent; found $($symbolMatches.Count)." }
    return $symbolMatches[0]
}

function Find-CallAst {
    param([string]$Calls, [string]$SourceText, [string]$CallText, [string]$ExpectedTarget)
    $matchingAst = [Collections.Generic.List[int]]::new()
    foreach ($line in ($Calls -split "`r?`n")) {
        if ($line -notmatch '^resolution (?<module>\d+):(?<ast>\d+) kind \d+ start (?<start>\d+) length (?<length>\d+) parent -?\d+ first -?\d+ target (?<targetModule>-?\d+):(?<targetSymbol>-?\d+) source -?\d+ status (?<status>\d+)$') { continue }
        $start = [int]$Matches.start
        $length = [int]$Matches.length
        if ($start + $length -gt $SourceText.Length) { continue }
        if ($SourceText.Substring($start, $length) -ceq $CallText) {
            if ([int]$Matches.status -ne 0 -or "$($Matches.targetModule):$($Matches.targetSymbol)" -cne $ExpectedTarget) {
                throw "Semantic call '$CallText' did not retain global/inherent target $ExpectedTarget`: $line"
            }
            $matchingAst.Add([int]$Matches.ast)
        }
    }
    if ($matchingAst.Count -ne 1) { throw "Expected one semantic call '$CallText'; found $($matchingAst.Count)." }
    return $matchingAst[0]
}

function Assert-TypedIrCall {
    param([string]$Calls, [int]$Ast, [string]$ExpectedTarget, [bool]$RequireReceiver)
    $typedMatches = @($Calls -split "`r?`n" | Where-Object { $_ -match "^call \d+ source \d+ ast $Ast target " })
    if ($typedMatches.Count -ne 1) { throw "Expected one final Typed IR call for AST $Ast; found $($typedMatches.Count)." }
    if ($typedMatches[0] -notmatch '^call \d+ source \d+ ast \d+ target (?<target>-?\d+:-?\d+) operand (?<operand>-?\d+) parent -?\d+ type -?\d+$' -or
        $Matches.target -cne $ExpectedTarget) {
        throw "Final Typed IR call for AST $Ast did not retain target $ExpectedTarget`: $($typedMatches[0])"
    }
    if ($RequireReceiver -and [int]$Matches.operand -lt 0) {
        throw "C417 receiver call lost its receiver operand: $($typedMatches[0])"
    }
}

$record = [ordered]@{
    schemaVersion = 1
    status = 'running'
    scope = 'global-call-target-inside-inherent-with-direct-inherent-negative-control'
    managed = [ordered]@{ completed = 0; total = 2 }
    selfhostTopology = [ordered]@{ completed = 0; total = 8; status = 'running' }
    selfhostNative = [ordered]@{ completed = 0; total = 2; status = 'running' }
    inputHashes = $inputHashes
    checks = @()
    resultPath = Join-Path $output 'result.json'
}
function Save-Result {
    [IO.File]::WriteAllText($record.resultPath, (($record | ConvertTo-Json -Depth 7) + "`n"), [Text.UTF8Encoding]::new($false))
}

try {
    Save-Result
    foreach ($case in $cases) {
        & $formatter -Check -Source $case.Source
        if ($LASTEXITCODE -ne 0) { throw "$($case.Id) authoritative format failed." }
        $expected = Normalize ([IO.File]::ReadAllText($case.Expected))
        $managedExe = Join-Path $output "$($case.Id)-managed.exe"
        $managedRun = Invoke-CapturedProcess 'dotnet' @($managed, 'run', $case.Source, '--llvm', $llvm, '-o', $managedExe, '--keep-temps', '-O0')
        if ($managedRun.ExitCode -ne 0 -or
            (Normalize $managedRun.Stdout) -cne $expected -or
            -not [string]::IsNullOrWhiteSpace($managedRun.Stderr)) {
            throw "$($case.Id) managed exact execution failed: stdout=$($managedRun.Stdout) stderr=$($managedRun.Stderr)"
        }
        $record.managed.completed++
        $record.checks += "$($case.Id)-managed-exact"
        Save-Result
    }

    foreach ($case in $cases) {
        foreach ($targetContract in $case.Targets) {
            $sourceText = [IO.File]::ReadAllText($case.Source).Replace("`r`n", "`n")
            $symbolQuery = Invoke-CapturedProcess $CandidateCompiler @('symbols', $case.Source)
            if ($symbolQuery.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($symbolQuery.Stderr)) {
                throw "$($case.Id) symbol query failed: stdout=$($symbolQuery.Stdout) stderr=$($symbolQuery.Stderr)"
            }
            $symbols = $symbolQuery.Stdout
            $target = Find-TargetSymbol -Symbols $symbols -SourceText $sourceText -Name $targetContract.Name -ExpectedParent $targetContract.Parent
            $targetIdentity = "$($target.Module):$($target.Symbol)"
            $callQuery = Invoke-CapturedProcess $CandidateCompiler @('typed-ir-calls', $case.Source)
            if ($callQuery.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($callQuery.Stderr)) {
                throw "$($case.Id) semantic/Typed IR call query failed: stdout=$($callQuery.Stdout) stderr=$($callQuery.Stderr)"
            }
            $calls = $callQuery.Stdout
            $callAst = Find-CallAst -Calls $calls -SourceText $sourceText -CallText $targetContract.CallText -ExpectedTarget $targetIdentity
            $record.selfhostTopology.completed++
            Assert-TypedIrCall -Calls $calls -Ast $callAst -ExpectedTarget $targetIdentity -RequireReceiver $targetContract.RequireReceiver
            $record.selfhostTopology.completed++
            $record.checks += "$($case.Id)-$($targetContract.Name)-semantic-and-typed-ir-target-$targetIdentity"
        }

        $llvmPath = Join-Path $output "$($case.Id)-candidate.ll"
        $emit = Invoke-CapturedProcess $CandidateCompiler @('windows', '--jobs', '1', $case.Source)
        if ($emit.ExitCode -ne 0 -or
            [string]::IsNullOrWhiteSpace($emit.Stdout) -or
            -not [string]::IsNullOrWhiteSpace($emit.Stderr)) {
            throw "$($case.Id) selfhost emission failed or emitted diagnostics: stdout=$($emit.Stdout) stderr=$($emit.Stderr)"
        }
        [IO.File]::WriteAllText($llvmPath, $emit.Stdout, [Text.UTF8Encoding]::new($false))
        $assemble = Invoke-CapturedProcess $llvmAs @($llvmPath, '-o', (Join-Path $output "$($case.Id)-candidate.bc"))
        if ($assemble.ExitCode -ne 0 -or
            -not [string]::IsNullOrWhiteSpace($assemble.Stdout) -or
            -not [string]::IsNullOrWhiteSpace($assemble.Stderr)) {
            throw "$($case.Id) llvm-as failed or emitted diagnostics: stdout=$($assemble.Stdout) stderr=$($assemble.Stderr)"
        }
        $closure = Invoke-CapturedProcess 'pwsh' @('-NoProfile', '-File', $closureVerifier, '-LlvmPath', $llvmPath)
        if ($closure.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($closure.Stderr)) {
            throw "$($case.Id) direct-call closure failed: stdout=$($closure.Stdout) stderr=$($closure.Stderr)"
        }
        $candidateExe = Join-Path $output "$($case.Id)-candidate.exe"
        $link = Invoke-CapturedProcess $clang @($llvmPath, '-O0', '-Werror', '-Wno-override-module', '-o', $candidateExe)
        if ($link.ExitCode -ne 0 -or
            -not [string]::IsNullOrWhiteSpace($link.Stdout) -or
            -not [string]::IsNullOrWhiteSpace($link.Stderr)) {
            throw "$($case.Id) native link failed or emitted diagnostics: stdout=$($link.Stdout) stderr=$($link.Stderr)"
        }
        $candidateRun = Invoke-CapturedProcess $candidateExe @()
        if ($candidateRun.ExitCode -ne 0 -or
            (Normalize $candidateRun.Stdout) -cne (Normalize ([IO.File]::ReadAllText($case.Expected))) -or
            -not [string]::IsNullOrWhiteSpace($candidateRun.Stderr)) {
            throw "$($case.Id) selfhost exact execution failed: stdout=$($candidateRun.Stdout) stderr=$($candidateRun.Stderr)"
        }
        $record.selfhostNative.completed++
        Save-Result
    }
    $record.selfhostTopology.status = 'passed'
    $record.selfhostNative.status = 'passed'
    if ($record.managed.completed -ne $record.managed.total -or
        $record.selfhostTopology.completed -ne $record.selfhostTopology.total -or
        $record.selfhostNative.completed -ne $record.selfhostNative.total) {
        throw 'C419 verifier did not complete every frozen managed, topology, and native check.'
    }

    foreach ($path in $inputHashes.Keys) {
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $inputHashes[$path]) {
            throw "C419 verifier input changed during execution: $path"
        }
    }
    $record.status = 'passed'
    Save-Result
    Write-Host "[C419 global call target] PASS managed $($record.managed.completed)/$($record.managed.total); selfhost topology $($record.selfhostTopology.completed)/$($record.selfhostTopology.total) $($record.selfhostTopology.status); selfhost native $($record.selfhostNative.completed)/$($record.selfhostNative.total) $($record.selfhostNative.status); $($record.resultPath)"
} catch {
    $record.status = 'failed'
    $record.failure = $_.Exception.Message
    Save-Result
    throw
}
