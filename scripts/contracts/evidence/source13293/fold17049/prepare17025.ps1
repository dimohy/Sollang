$ErrorActionPreference = 'Stop'
. ./scripts/source-module-header.ps1
$taskBase = 'artifacts/scratch/resume-20261006-owner-continuation22'
$plan = Get-Content -LiteralPath "$taskBase/interp17015-contract8.json" -Raw | ConvertFrom-Json
$probe = "$taskBase/fold17025-type-probe.slg"
$byNamespace = @{}
$headers = @{}
foreach ($sourcePath in $plan.reusableCheckedProducer.additionalSources) {
    $header = Get-SollangModuleHeader -Source ([IO.File]::ReadAllText((Join-Path $PWD $sourcePath)))
    $headers[$sourcePath] = $header
    if (-not $byNamespace.ContainsKey($header.Namespace)) { $byNamespace[$header.Namespace] = [Collections.Generic.List[string]]::new() }
    $byNamespace[$header.Namespace].Add($sourcePath)
}
$pending = [Collections.Generic.Queue[string]]::new()
$seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$selected = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$rootHeader = Get-SollangModuleHeader -Source ([IO.File]::ReadAllText((Join-Path $PWD $probe)))
foreach ($namespace in $rootHeader.Imports) { $pending.Enqueue($namespace) }
while ($pending.Count -gt 0) {
    $namespace = $pending.Dequeue()
    if (-not $seen.Add($namespace)) { continue }
    if (-not $byNamespace.ContainsKey($namespace)) {
        if ($namespace.StartsWith('sollang.compiler.') -or $namespace.StartsWith('syntax.generated.')) { throw "Missing fixed provider: $namespace" }
        continue
    }
    foreach ($sourcePath in $byNamespace[$namespace]) {
        if ($selected.Add($sourcePath)) {
            foreach ($dependency in $headers[$sourcePath].Imports) { $pending.Enqueue($dependency) }
        }
    }
}
$additional = @($plan.reusableCheckedProducer.additionalSources | Where-Object { $selected.Contains($_) })
$contract = [ordered]@{
    schemaVersion = 1
    scope = 'Bounded C744 diagnostic: compare committed AST root type with actual IR root and fold result. Exact failing fragment; no LLVM emitter build and no original acceptance credit.'
    expectedManagedDllSha256 = $plan.expectedManagedDllSha256
    formatCheckSources = @($probe)
    cases = @([ordered]@{ id = 'fold-source-type'; source = $probe; additionalSources = $additional; exit = 0; stderr = ''; stdout = "ast-root=2`nir-root=2`nir-fold=2" })
}
[IO.File]::WriteAllText((Join-Path $PWD "$taskBase/fold17025-type-contract.json"), (($contract | ConvertTo-Json -Depth 30) + "`n"), [Text.UTF8Encoding]::new($false))
Write-Output "NAMESPACE_PROVIDERS=$($additional.Count)"
