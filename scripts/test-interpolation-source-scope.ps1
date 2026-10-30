[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($RepositoryRoot)
. (Join-Path $root 'scripts/verification-artifact-identity.ps1')
$verifier = Get-Content -LiteralPath (Join-Path $root 'scripts/verify-interpolation-semantic-parity.ps1') -Raw
$start = $verifier.IndexOf('$unknownScopeSources = @(', [StringComparison]::Ordinal)
$end = $verifier.IndexOf('if ($unknownBinding.status', $start, [StringComparison]::Ordinal)
if ($start -lt 0 -or $end -le $start) { throw 'Unknown-source production guard not found' }
$guard = [scriptblock]::Create($verifier.Substring($start, $end - $start))
$contract = Get-Content -LiteralPath (Join-Path $root 'scripts/contracts/interpolation-semantic-parity.json') -Raw | ConvertFrom-Json
$reference = $contract.currentUnknownBindingEvidence
$comparison = Get-Content -LiteralPath (Resolve-CompilerEvidencePath $root $reference.sourceComparison) -Raw | ConvertFrom-Json
$paired = Get-Content -LiteralPath (Resolve-CompilerEvidencePath $root $reference.paired) -Raw | ConvertFrom-Json
function Copy-Record($Record) { $Record | ConvertTo-Json -Depth 50 | ConvertFrom-Json }
function Invoke-SourceGuard($Comparison, $Paired) {
    $unknownScopeComparison = $Comparison
    $unknownScopePaired = $Paired
    & $guard
}
Invoke-SourceGuard $comparison $paired
$sources = @($comparison.sourceHashes.PSObject.Properties.Name)
if ($sources.Count -ne 10) { throw 'Expected the current ten-source closure' }
$rejected = 0
foreach ($source in $sources) {
    $pin = @($paired.inputHashes.PSObject.Properties.Name | Where-Object {
        (Resolve-CompilerEvidencePath $root $_).Equals((Resolve-CompilerEvidencePath $root $source), [StringComparison]::OrdinalIgnoreCase)
    })
    if ($pin.Count -ne 1) { throw "Current source pin is ambiguous: $source" }
    foreach ($mutation in @('missing-review', 'wrong-review', 'missing-producer-pin', 'wrong-producer-pin')) {
        $reviewCopy = Copy-Record $comparison
        $pairedCopy = Copy-Record $paired
        switch ($mutation) {
            'missing-review' { $reviewCopy.sourceHashes.PSObject.Properties.Remove($source) }
            'wrong-review' { $reviewCopy.sourceHashes.$source = '0' * 64 }
            'missing-producer-pin' { $pairedCopy.inputHashes.PSObject.Properties.Remove($pin[0]) }
            'wrong-producer-pin' { $pairedCopy.inputHashes.($pin[0]) = '0' * 64 }
        }
        $failure = $null
        try { Invoke-SourceGuard $reviewCopy $pairedCopy } catch { $failure = $_.Exception.Message }
        if (-not $failure -or $failure -notmatch 'CURRENT_UNKNOWN_SOURCE_COMPARISON_INVALID|ARTIFACT_PINNED_PATH_IDENTITY_INVALID') {
            throw "Source mutation was not rejected by the production guard: $source $mutation $failure"
        }
        $rejected++
    }
}
$extra = Copy-Record $comparison
$extra.sourceHashes | Add-Member -NotePropertyName 'docs/SPEC.md' -NotePropertyValue (Get-FileHash -LiteralPath (Join-Path $root 'docs/SPEC.md')).Hash
$failure = $null
try { Invoke-SourceGuard $extra $paired } catch { $failure = $_.Exception.Message }
if ($failure -cne 'CURRENT_UNKNOWN_SOURCE_COMPARISON_INVALID') { throw 'Unexpected review scope was not rejected' }
$rejected++
if ($rejected -ne 41) { throw 'Source-scope rejection count changed' }
Write-Host '[interpolation source scope] PASS 42/42: current closure and41 missing, changed or additional source/pin controls.'
