[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$contractPath = Join-Path $PSScriptRoot "contracts/selfhost-source-structure.json"
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json

if ($contract.schemaVersion -ne 2) {
    throw "Unsupported selfhost source structure schema version '$($contract.schemaVersion)'."
}
foreach ($removedProperty in @('fileLineLimit', 'declarationLineLimit', 'fileExceptions', 'declarationExceptions')) {
    if ($contract.PSObject.Properties.Name -contains $removedProperty) {
        throw "Selfhost structure contract must not restore line-count policy '$removedProperty'."
    }
}

$entryPoints = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($path in @($contract.entryPointFiles)) {
    if ([string]::IsNullOrWhiteSpace($path) -or -not $entryPoints.Add($path)) {
        throw "Selfhost structure contract has an empty or duplicate entry point."
    }
}

$sourceRoot = Join-Path $repoRoot $contract.root
$files = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter "*.slg" | Sort-Object FullName)
$modules = [Collections.Generic.Dictionary[string, Collections.Generic.List[string]]]::new([StringComparer]::Ordinal)
$moduleDependencies = @{}
$violations = [Collections.Generic.List[string]]::new()

function Assert-AcyclicModuleGraph {
    param(
        [Parameter(Mandatory)][hashtable]$Dependencies,
        [Parameter(Mandatory)][string]$Identity
    )

    $color = @{}
    $stack = [Collections.Generic.List[string]]::new()
    $cycle = [Collections.Generic.List[string]]::new()

    function Visit-Module {
        param([Parameter(Mandatory)][string]$Module)

        if ($cycle.Count -gt 0) { return }
        $color[$Module] = 1
        $stack.Add($Module)
        foreach ($dependency in @($Dependencies[$Module] | Sort-Object)) {
            if (-not $Dependencies.ContainsKey($dependency) -or $dependency -ceq $Module) { continue }
            if ($color[$dependency] -eq 1) {
                $start = $stack.IndexOf($dependency)
                for ($index = $start; $index -lt $stack.Count; $index++) {
                    $cycle.Add($stack[$index])
                }
                $cycle.Add($dependency)
                return
            }
            if ($color[$dependency] -ne 2) {
                Visit-Module -Module $dependency
                if ($cycle.Count -gt 0) { return }
            }
        }
        $stack.RemoveAt($stack.Count - 1)
        $color[$Module] = 2
    }

    foreach ($module in @($Dependencies.Keys | Sort-Object)) {
        if ($color[$module] -ne 2) { Visit-Module -Module $module }
        if ($cycle.Count -gt 0) {
            throw "$Identity module import cycle: $($cycle -join ' -> ')"
        }
    }
}

foreach ($file in $files) {
    $relativePath = [IO.Path]::GetRelativePath($repoRoot, $file.FullName).Replace('\', '/')
    $lines = [IO.File]::ReadAllLines($file.FullName)
    $namespaceLines = @($lines | Where-Object { $_ -match '^namespace\s+(?<name>[A-Za-z_][A-Za-z0-9_.]*)\s*$' })

    if ($entryPoints.Contains($relativePath)) {
        if ($namespaceLines.Count -ne 0 -or -not ($lines -match '^main\s*\{\s*$')) {
            $violations.Add("$relativePath must be an explicit namespace-free executable root with one main block.")
        }
        continue
    }

    if ($namespaceLines.Count -ne 1) {
        $violations.Add("$relativePath must declare exactly one explicit namespace module boundary; found $($namespaceLines.Count).")
        continue
    }

    $namespace = [regex]::Match($namespaceLines[0], '^namespace\s+(?<name>[A-Za-z_][A-Za-z0-9_.]*)\s*$').Groups['name'].Value
    $allowedNamespace = @($contract.allowedNamespacePrefixes | Where-Object {
        $namespace.StartsWith($_, [StringComparison]::Ordinal)
    }).Count -gt 0
    if (-not $allowedNamespace) {
        $violations.Add("$relativePath namespace '$namespace' is outside allowed module roots '$($contract.allowedNamespacePrefixes -join ', ')'.")
        continue
    }
    if (-not $modules.ContainsKey($namespace)) {
        $modules[$namespace] = [Collections.Generic.List[string]]::new()
    }
    $modules[$namespace].Add($relativePath)
    if (-not $moduleDependencies.ContainsKey($namespace)) {
        $moduleDependencies[$namespace] = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    }
    foreach ($line in $lines) {
        if ($line -match '^import\s+(?<name>[A-Za-z_][A-Za-z0-9_.]*)') {
            [void]$moduleDependencies[$namespace].Add($Matches.name)
        }
    }
}

foreach ($entryPoint in $entryPoints) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $entryPoint) -PathType Leaf)) {
        $violations.Add("Declared selfhost entry point is missing: $entryPoint")
    }
}

$parallel = $contract.parallelCompilation
$parallelDocumentPath = Join-Path $repoRoot $parallel.documentPath
$codegenUnitPath = Join-Path $repoRoot $parallel.codegenUnitPath
if (-not (Test-Path -LiteralPath $parallelDocumentPath -PathType Leaf)) {
    $violations.Add("Parallel compilation contract document is missing: $($parallel.documentPath)")
} else {
    $parallelDocument = [IO.File]::ReadAllText($parallelDocumentPath)
    foreach ($term in @($parallel.requiredDocumentTerms)) {
        if (-not $parallelDocument.Contains($term, [StringComparison]::Ordinal)) {
            $violations.Add("Parallel compilation contract document is missing required term: $term")
        }
    }
}
if (-not (Test-Path -LiteralPath $codegenUnitPath -PathType Leaf)) {
    $violations.Add("Parallel codegen-unit implementation is missing: $($parallel.codegenUnitPath)")
} else {
    $codegenUnitSource = [IO.File]::ReadAllText($codegenUnitPath)
    foreach ($term in @($parallel.requiredCodeTerms)) {
        if (-not $codegenUnitSource.Contains($term, [StringComparison]::Ordinal)) {
            $violations.Add("Parallel codegen-unit implementation is missing required term: $term")
        }
    }
}

# A deliberately large module proves that line count is irrelevant. Missing
# module boundaries remain a deterministic failure instead.
$longModule = @('namespace test.large') + @(1..6000 | ForEach-Object { '# content' })
if (@($longModule | Where-Object { $_ -match '^namespace\s+[A-Za-z_][A-Za-z0-9_.]*\s*$' }).Count -ne 1) {
    throw "Selfhost structure long-module positive control failed."
}
$missingModule = @('import test.other', 'value {', '}')
if (@($missingModule | Where-Object { $_ -match '^namespace\s+[A-Za-z_][A-Za-z0-9_.]*\s*$' }).Count -ne 0) {
    throw "Selfhost structure missing-module negative control failed."
}
$dagControl = @{
    'control.a' = [Collections.Generic.HashSet[string]]::new([string[]]@('control.b'), [StringComparer]::Ordinal)
    'control.b' = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
}
Assert-AcyclicModuleGraph -Dependencies $dagControl -Identity 'DAG positive control'
foreach ($cycleControl in @(
    @{
        'control.a' = [Collections.Generic.HashSet[string]]::new([string[]]@('control.b'), [StringComparer]::Ordinal)
        'control.b' = [Collections.Generic.HashSet[string]]::new([string[]]@('control.a'), [StringComparer]::Ordinal)
    },
    @{
        'control.a' = [Collections.Generic.HashSet[string]]::new([string[]]@('control.b'), [StringComparer]::Ordinal)
        'control.b' = [Collections.Generic.HashSet[string]]::new([string[]]@('control.c'), [StringComparer]::Ordinal)
        'control.c' = [Collections.Generic.HashSet[string]]::new([string[]]@('control.a'), [StringComparer]::Ordinal)
    }
)) {
    $rejected = $false
    try {
        Assert-AcyclicModuleGraph -Dependencies $cycleControl -Identity 'cycle negative control'
    } catch {
        if ($_.Exception.Message -like 'cycle negative control module import cycle:*') {
            $rejected = $true
        } else {
            throw
        }
    }
    if (-not $rejected) { throw 'Selfhost structure import-cycle negative control was accepted.' }
}

if ($violations.Count -gt 0) {
    throw "Selfhost source structure contracts failed:`n$($violations -join "`n")"
}
Assert-AcyclicModuleGraph -Dependencies $moduleDependencies -Identity 'selfhost'

$fragmentedModules = @($modules.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 })
Write-Host "PASS selfhost source structure: files=$($files.Count), explicit-modules=$($modules.Count), acyclic-modules=$($moduleDependencies.Count), multi-file-modules=$($fragmentedModules.Count), entry-points=$($entryPoints.Count), fixed-line-limits=0, parallel-codegen-unit=verified"
