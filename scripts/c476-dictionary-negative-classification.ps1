Set-StrictMode -Version Latest

function Test-C476DiagnosticOnlyLlText([string]$Text, [string]$ExpectedDiagnostic) {
    if ([string]::IsNullOrWhiteSpace($ExpectedDiagnostic) -or
        $ExpectedDiagnostic.Contains("`n") -or $ExpectedDiagnostic.Contains("`r") -or
        $Text.Length -gt 4096) {
        return $false
    }
    $pattern = '\A; sollang workers = 1\n; sollang semantic error: ' +
        [regex]::Escape($ExpectedDiagnostic) + ' \(source [0-9]+\)\n\z'
    return [regex]::IsMatch($Text, $pattern, [Text.RegularExpressions.RegexOptions]::CultureInvariant)
}

function Test-C476DiagnosticOnlyLlProduct([string]$Path, [string]$OutputDirectory,
    [string]$ExpectedDiagnostic) {
    if ([string]::IsNullOrWhiteSpace($Path) -or [string]::IsNullOrWhiteSpace($OutputDirectory)) {
        return $false
    }
    $expectedPath = [IO.Path]::GetFullPath((Join-Path $OutputDirectory 'negative.exe.ll'))
    if (-not [IO.Path]::GetFullPath($Path).Equals($expectedPath,
            [StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }
    if (-not [IO.File]::Exists($expectedPath)) { return $false }
    $file = [IO.FileInfo]::new($expectedPath)
    if ($file.Length -lt 1 -or $file.Length -gt 4096) { return $false }
    $bytes = [IO.File]::ReadAllBytes($expectedPath)
    if ($bytes.Length -lt 1 -or $bytes.Length -gt 4096) { return $false }
    try {
        $content = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
    } catch [Text.DecoderFallbackException] {
        return $false
    }
    return Test-C476DiagnosticOnlyLlText $content $ExpectedDiagnostic
}

function Get-C476Evidence($Check, [string]$ExpectedDiagnostic) {
    if ($null -eq $Check) {
        return [ordered]@{ state = 'not-run'; nonzeroExit = $null; diagnosticInStderr = $null;
            noLoweringProduct = $null; noEmittedProducts = $null; generatedProducts = @() }
    }
    $products = @($Check.generatedProducts)
    $loweringProducts = @($products | Where-Object {
        $extension = [IO.Path]::GetExtension([string]$_).ToLowerInvariant()
        if ($extension -ceq '.ll') {
            -not (Test-C476DiagnosticOnlyLlProduct ([string]$_) ([string]$Check.outputDirectory) $ExpectedDiagnostic)
        } else {
            $extension -cin @('.bc', '.obj', '.o', '.exe')
        }
    })
    $nonzero = [bool]$Check.nonzeroExit
    $diagnostic = [bool]$Check.expectedInStderr
    $noLowering = $loweringProducts.Count -eq 0
    return [ordered]@{
        state = if ($nonzero -and $diagnostic -and $noLowering) { 'passed' } else { 'failed' }
        nonzeroExit = $nonzero
        diagnosticInStderr = $diagnostic
        noLoweringProduct = $noLowering
        noEmittedProducts = [bool]$Check.noEmittedProducts -and $products.Count -eq 0
        generatedProducts = $products
    }
}

function Test-C476SemanticEligibility($CaseResult) {
    if ($null -eq $CaseResult -or $CaseResult.state -ceq 'running' -or
        -not $CaseResult.inputsStable -or $null -eq $CaseResult.inputFingerprintEnd -or
        @($CaseResult.orphanProcessIds).Count -ne 0) {
        return $false
    }
    if ($CaseResult.state -ceq 'passed') {
        return $null -eq $CaseResult.failureId
    }
    if ($CaseResult.state -cne 'failed' -or $CaseResult.failureId -cne 'NEGATIVE_CHECK_FAILED') {
        return $false
    }
    return [string]$CaseResult.failure -cmatch
        '\A(managed|selfhost) negative fixture failed: exit=-?[0-9]+, expectedInStderr=(True|False), noEmittedProducts=(True|False)\z'
}
