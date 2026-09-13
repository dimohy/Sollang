function Get-GzipSelfhostExpectedInputHashes {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$CompilerPath,
        [Parameter(Mandatory)][string]$FocusedContractPath,
        [Parameter(Mandatory)][string]$ResultSchemaPath
    )

    $root = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
    function Resolve-GzipAuthorityFile([string]$Relative) {
        $path = [IO.Path]::GetFullPath((Join-Path $root $Relative))
        if (-not $path.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
            -not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "GZIP worker authority input is missing or outside repository: $Relative" }
        $path
    }
    function Add-GzipInputHash([Collections.Specialized.OrderedDictionary]$Hashes, [string]$Key, [string]$Path) {
        $Hashes[$Key] = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }

    $focused = [IO.File]::ReadAllText($FocusedContractPath) | ConvertFrom-Json -ErrorAction Stop
    $authorityPath = Resolve-GzipAuthorityFile $focused.authorityContract
    $authority = [IO.File]::ReadAllText($authorityPath) | ConvertFrom-Json -ErrorAction Stop
    $hashes = [ordered]@{}
    Add-GzipInputHash $hashes 'compiler' $CompilerPath
    Add-GzipInputHash $hashes 'focusedContract' $FocusedContractPath
    Add-GzipInputHash $hashes 'focusedSchema' (Resolve-GzipAuthorityFile 'scripts/contracts/gzip-selfhost-focused.schema.json')
    Add-GzipInputHash $hashes 'resultSchema' $ResultSchemaPath
    Add-GzipInputHash $hashes 'authorityContract' $authorityPath
    Add-GzipInputHash $hashes 'authoritySchema' (Resolve-GzipAuthorityFile 'scripts/contracts/gzip-stream-api.schema.json')
    Add-GzipInputHash $hashes 'authorityVerifier' (Resolve-GzipAuthorityFile 'scripts/verify-gzip-stream-api-contract.ps1')
    Add-GzipInputHash $hashes 'contractVerifier' (Resolve-GzipAuthorityFile 'scripts/verify-gzip-selfhost-focused-contract.ps1')
    Add-GzipInputHash $hashes 'verifier' (Resolve-GzipAuthorityFile 'scripts/verify-gzip-selfhost-focused.ps1')
    Add-GzipInputHash $hashes 'processHelper' (Resolve-GzipAuthorityFile 'scripts/verification-process.ps1')
    Add-GzipInputHash $hashes 'closureVerifier' (Resolve-GzipAuthorityFile 'scripts/verify-llvm-direct-call-closure.ps1')
    Add-GzipInputHash $hashes 'llvmAs' (Resolve-GzipAuthorityFile '.tools/llvm-22.1.8/bin/llvm-as.exe')
    Add-GzipInputHash $hashes 'clang' (Resolve-GzipAuthorityFile '.tools/llvm-22.1.8/bin/clang.exe')
    foreach ($relative in @($authority.sources)) { Add-GzipInputHash $hashes "source:$relative" (Resolve-GzipAuthorityFile $relative) }
    foreach ($property in @($focused.additionalSourcesByCase.PSObject.Properties)) {
        foreach ($relative in @($property.Value)) { Add-GzipInputHash $hashes "additional:$($property.Name):$relative" (Resolve-GzipAuthorityFile $relative) }
    }
    foreach ($case in @($authority.positiveCases)) {
        Add-GzipInputHash $hashes "positive:$($case.id):source" (Resolve-GzipAuthorityFile $case.source)
        if ($case.PSObject.Properties.Name -contains 'expected') { Add-GzipInputHash $hashes "positive:$($case.id):expected" (Resolve-GzipAuthorityFile $case.expected) }
    }
    foreach ($case in @($authority.negativeCases)) { Add-GzipInputHash $hashes "negative:$($case.id):source" (Resolve-GzipAuthorityFile $case.source) }
    $hashes
}

function Read-GzipSelfhostWorkerResult {
    param(
        [Parameter(Mandatory)][string]$ResultPath,
        [Parameter(Mandatory)][string]$SchemaPath,
        [Parameter(Mandatory)][string]$FocusedContractPath,
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$CompilerPath,
        [Parameter(Mandatory)][string]$ExpectedCompilerSha256,
        [Parameter(Mandatory)][int]$TargetExitCode
    )
    function Invalid-GzipWorkerResult([string]$FailureId) { [pscustomobject]@{ valid = $false; failureId = $FailureId; workerFailureIds = @() } }
    if (-not (Test-Path -LiteralPath $ResultPath -PathType Leaf)) { return Invalid-GzipWorkerResult 'GZIP_SELFHOST_RESULT_MISSING' }
    try {
        $json = [IO.File]::ReadAllText($ResultPath)
        if (-not ($json | Test-Json -SchemaFile $SchemaPath -ErrorAction Stop)) { return Invalid-GzipWorkerResult 'GZIP_SELFHOST_RESULT_INVALID' }
        $result = $json | ConvertFrom-Json -ErrorAction Stop
        $focused = [IO.File]::ReadAllText($FocusedContractPath) | ConvertFrom-Json -ErrorAction Stop
        $expectedInputHashes = Get-GzipSelfhostExpectedInputHashes -RepositoryRoot $RepositoryRoot -CompilerPath $CompilerPath -FocusedContractPath $FocusedContractPath -ResultSchemaPath $SchemaPath
    } catch { return Invalid-GzipWorkerResult 'GZIP_SELFHOST_RESULT_INVALID' }

    $expected = $ExpectedCompilerSha256.ToUpperInvariant()
    if ($result.expectedCompilerSha256 -cne $expected -or $result.compilerSha256Start -cne $expected -or
        $result.compilerSha256End -cne $expected -or $result.toolHashes.compiler -cne $expected) { return Invalid-GzipWorkerResult 'GZIP_SELFHOST_COMPILER_SHA_MISMATCH' }
    $workerFailures = @($result.failureIds)
    if ($result.phase -ceq 'preflight') {
        $allowedPreflightFailures = @('GZIP_SELFHOST_PREFLIGHT_FAILED', 'GZIP_SELFHOST_INPUT_DRIFT')
        if ($TargetExitCode -eq 0 -or $result.status -cne 'failed' -or $result.attempted -ne 0 -or
            @($result.cases).Count -ne 0 -or $result.completed -ne 0 -or
            $result.positive.completed -ne 0 -or $result.negative.completed -ne 0 -or
            $workerFailures -cnotcontains 'GZIP_SELFHOST_PREFLIGHT_FAILED') {
            return Invalid-GzipWorkerResult 'GZIP_SELFHOST_RESULT_INVALID'
        }
        foreach ($workerFailure in $workerFailures) {
            if ($allowedPreflightFailures -cnotcontains $workerFailure) { return Invalid-GzipWorkerResult 'GZIP_SELFHOST_RESULT_INVALID' }
        }
        return [pscustomobject]@{ valid = $true; failureId = $null; workerFailureIds = $workerFailures }
    }
    if ($result.phase -cne 'execution') { return Invalid-GzipWorkerResult 'GZIP_SELFHOST_RESULT_INVALID' }
    $startProperties = @($result.inputHashesStart.PSObject.Properties)
    $endProperties = @($result.inputHashesEnd.PSObject.Properties)
    if ($startProperties.Count -ne $expectedInputHashes.Count -or $endProperties.Count -ne $expectedInputHashes.Count) { return Invalid-GzipWorkerResult 'GZIP_SELFHOST_RESULT_INVALID' }
    $hashDrift = [Collections.Generic.List[string]]::new()
    foreach ($entry in $expectedInputHashes.GetEnumerator()) {
        if ($result.inputHashesStart.PSObject.Properties.Name -cnotcontains $entry.Key -or
            $result.inputHashesEnd.PSObject.Properties.Name -cnotcontains $entry.Key -or
            $result.inputHashesEnd.PSObject.Properties[$entry.Key].Value -cne $entry.Value) { return Invalid-GzipWorkerResult 'GZIP_SELFHOST_RESULT_INVALID' }
        if ($result.inputHashesStart.PSObject.Properties[$entry.Key].Value -cne $result.inputHashesEnd.PSObject.Properties[$entry.Key].Value) { $hashDrift.Add($entry.Key) }
    }
    $recordedDrift = @($result.inputDrift)
    if (($hashDrift -join "`n") -cne ($recordedDrift -join "`n") -or
        ($result.inputStable -ne ($hashDrift.Count -eq 0)) -or
        ($hashDrift.Count -gt 0 -and $workerFailures -cnotcontains 'GZIP_SELFHOST_INPUT_DRIFT') -or
        ($hashDrift.Count -eq 0 -and $workerFailures -ccontains 'GZIP_SELFHOST_INPUT_DRIFT')) { return Invalid-GzipWorkerResult 'GZIP_SELFHOST_RESULT_INVALID' }
    if ($result.toolHashes.llvmAs -cne $expectedInputHashes.llvmAs -or $result.toolHashes.clang -cne $expectedInputHashes.clang -or
        $result.toolHashes.closureVerifier -cne $expectedInputHashes.closureVerifier) { return Invalid-GzipWorkerResult 'GZIP_SELFHOST_RESULT_INVALID' }

    $expectedCases = [Collections.Generic.List[object]]::new()
    foreach ($caseId in @($focused.positiveCaseIds)) {
        foreach ($optimization in @($focused.optimizations)) { $expectedCases.Add([pscustomobject]@{ id = "$caseId-$($optimization.ToLowerInvariant())"; kind = 'positive'; optimization = $optimization }) }
    }
    foreach ($caseId in @($focused.negativeCaseIds)) { $expectedCases.Add([pscustomobject]@{ id = $caseId; kind = 'negative'; optimization = $null }) }
    $cases = @($result.cases)
    if ($result.attempted -ne 23 -or $cases.Count -ne 23 -or $expectedCases.Count -ne 23) { return Invalid-GzipWorkerResult 'GZIP_SELFHOST_RESULT_INVALID' }
    $failedCaseIds = [Collections.Generic.List[string]]::new()
    $completed = 0; $positiveCompleted = 0; $negativeCompleted = 0
    for ($index = 0; $index -lt 23; $index++) {
        $case = $cases[$index]; $expectedCase = $expectedCases[$index]
        if ($case.id -cne $expectedCase.id -or $case.kind -cne $expectedCase.kind -or
            (($null -eq $case.optimization) -ne ($null -eq $expectedCase.optimization)) -or
            ($null -ne $case.optimization -and $case.optimization -cne $expectedCase.optimization)) { return Invalid-GzipWorkerResult 'GZIP_SELFHOST_RESULT_INVALID' }
        if ($case.passed) {
            if (-not $case.exact -or $null -ne $case.failure) { return Invalid-GzipWorkerResult 'GZIP_SELFHOST_RESULT_INVALID' }
            if ($case.kind -ceq 'positive' -and
                ($case.compileExit -ne 0 -or -not $case.diagnosticFree -or -not $case.llvmProduced -or
                 $case.llvmAsExit -ne 0 -or $case.closureExit -ne 0 -or $case.linkExit -ne 0 -or
                 $case.nativeExit -ne 0 -or [string]::IsNullOrWhiteSpace($case.stdoutSha256))) { return Invalid-GzipWorkerResult 'GZIP_SELFHOST_RESULT_INVALID' }
            if ($case.kind -ceq 'negative' -and
                ($case.compileExit -ne 1 -or $case.diagnosticFree -or $case.llvmProduced -or
                 $null -ne $case.llvmAsExit -or $null -ne $case.closureExit -or $null -ne $case.linkExit -or
                 $null -ne $case.nativeExit -or $null -ne $case.stdoutSha256)) { return Invalid-GzipWorkerResult 'GZIP_SELFHOST_RESULT_INVALID' }
            $completed++
            if ($case.kind -ceq 'positive') { $positiveCompleted++ } else { $negativeCompleted++ }
        } else {
            if ($case.exact -or [string]::IsNullOrWhiteSpace($case.failure)) { return Invalid-GzipWorkerResult 'GZIP_SELFHOST_RESULT_INVALID' }
            $failedCaseIds.Add($case.id)
        }
    }
    if ($result.completed -ne $completed -or $result.positive.completed -ne $positiveCompleted -or $result.negative.completed -ne $negativeCompleted) { return Invalid-GzipWorkerResult 'GZIP_SELFHOST_RESULT_INVALID' }
    $allowedInfrastructureFailures = @('dynamic-writer-determinism', 'GZIP_SELFHOST_EXECUTION_FAILED', 'GZIP_SELFHOST_INPUT_DRIFT')
    foreach ($failedCaseId in $failedCaseIds) { if ($workerFailures -cnotcontains $failedCaseId) { return Invalid-GzipWorkerResult 'GZIP_SELFHOST_RESULT_INVALID' } }
    foreach ($workerFailure in $workerFailures) {
        if ($failedCaseIds -cnotcontains $workerFailure -and $allowedInfrastructureFailures -cnotcontains $workerFailure) { return Invalid-GzipWorkerResult 'GZIP_SELFHOST_RESULT_INVALID' }
    }
    $dynamicO0 = @($cases | Where-Object id -CEQ 'dynamic-writer-o0')[0]
    $dynamicO2 = @($cases | Where-Object id -CEQ 'dynamic-writer-o2')[0]
    if ($dynamicO0.passed -and $dynamicO2.passed -and
        ($result.dynamic.btype -ne 2 -or -not $result.dynamic.decodedExact -or -not $result.dynamic.deterministicAcrossOptimizations -or
         $result.dynamic.stdoutSha256O0 -cne $dynamicO0.stdoutSha256 -or
         $result.dynamic.stdoutSha256O2 -cne $dynamicO2.stdoutSha256 -or
         $result.dynamic.stdoutSha256O0 -cne $result.dynamic.stdoutSha256O2)) { return Invalid-GzipWorkerResult 'GZIP_SELFHOST_RESULT_INVALID' }
    $passed = $result.status -ceq 'passed' -and $completed -eq 23 -and $workerFailures.Count -eq 0
    $failed = $result.status -ceq 'failed' -and $workerFailures.Count -gt 0
    if (($TargetExitCode -eq 0 -and -not $passed) -or ($TargetExitCode -ne 0 -and -not $failed)) { return Invalid-GzipWorkerResult 'GZIP_SELFHOST_RESULT_INVALID' }
    [pscustomobject]@{ valid = $true; failureId = $null; workerFailureIds = $workerFailures }
}
