[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
$managedPath = Join-Path $RepositoryRoot "src/Sollang.Compiler/TargetContract.cs"
$cachePath = Join-Path $RepositoryRoot "src/Sollang.Compiler/Cli/IncrementalCodegenCache.cs"
$selfhostPath = Join-Path $RepositoryRoot "selfhost/llvm/target.slg"
$selfhostContextPath = Join-Path $RepositoryRoot "selfhost/llvm/emitter/context.slg"
$selfhostEntrypointsPath = Join-Path $RepositoryRoot "selfhost/llvm/text/entrypoints.slg"
$managed = [IO.File]::ReadAllText($managedPath)
$cache = [IO.File]::ReadAllText($cachePath)
$selfhost = [IO.File]::ReadAllText($selfhostPath)
$selfhostContext = [IO.File]::ReadAllText($selfhostContextPath)
$selfhostEntrypoints = [IO.File]::ReadAllText($selfhostEntrypointsPath)
$registryPath = Join-Path $RepositoryRoot "scripts/contracts/cpu-target-features.json"
$registrySchemaPath = Join-Path $RepositoryRoot "scripts/contracts/cpu-target-features.schema.json"
$registryJson = Get-Content -Raw -LiteralPath $registryPath
if (-not ($registryJson | Test-Json -SchemaFile $registrySchemaPath)) {
    throw "CPU target feature registry does not satisfy its JSON schema"
}
$registry = $registryJson | ConvertFrom-Json

if ($registry.schemaVersion -ne 1) {
    throw "unsupported CPU target feature registry schema '$($registry.schemaVersion)'"
}
$architectures = @($registry.architectures.PSObject.Properties)
$features = @($architectures | ForEach-Object { $_.Value.features })
foreach ($bitGroup in @($features | Group-Object bit)) {
    if (@($bitGroup.Group.managed | Select-Object -Unique).Count -ne 1) {
        throw "CPU target feature bit '$($bitGroup.Name)' maps to more than one semantic feature"
    }
}
foreach ($architecture in $architectures) {
    $knownIds = @($architecture.Value.features.id)
    $computedMask = [UInt64]0
    foreach ($feature in $architecture.Value.features) {
        $computedMask = $computedMask -bor ([UInt64]1 -shl [int]$feature.bit)
        $requiresProperty = $feature.PSObject.Properties['requires']
        $dependencies = if ($null -eq $requiresProperty) { @() } else { @($requiresProperty.Value) }
        foreach ($dependency in $dependencies) {
            if ($dependency -notin $knownIds) {
                throw "CPU feature '$($feature.id)' requires unknown '$dependency' in '$($architecture.Name)'"
            }
        }
    }
    $declaredMask = [UInt64]$architecture.Value.allowedMask -bor [UInt64]$architecture.Value.baselineMask
    if (($declaredMask -band (-bnot $computedMask)) -ne 0) {
        throw "CPU architecture '$($architecture.Name)' masks contain an unregistered feature bit"
    }
}
foreach ($specialization in $registry.specializations.PSObject.Properties) {
    foreach ($architecture in $specialization.Value.PSObject.Properties) {
        $registered = @($registry.architectures.($architecture.Name).features.id)
        foreach ($required in @($architecture.Value.required)) {
            if ($required -notin $registered) {
                throw "CPU specialization '$($specialization.Name)' requires unknown '$required' on '$($architecture.Name)'"
            }
        }
    }
}

foreach ($feature in $features.managed) {
    if (-not $managed.Contains($feature, [StringComparison]::Ordinal)) {
        throw "managed target feature registry is missing '$feature'"
    }
}
foreach ($field in @(
    "Architecture", "DispatchPolicy", "RequiredFeatures", "AllowedFeatures", "ForbiddenFeatures")) {
    if (-not $managed.Contains($field, [StringComparison]::Ordinal)) {
        throw "managed target contract is missing '$field'"
    }
    $selfhostField = $field.Substring(0, 1).ToLowerInvariant() + $field.Substring(1)
    if (-not $selfhost.Contains($selfhostField, [StringComparison]::Ordinal)) {
        throw "self-host target descriptor is missing '$selfhostField'"
    }
}
foreach ($contextField in @(
    "targetArchitecture", "cpuDispatchPolicy", "requiredCpuFeatures",
    "allowedCpuFeatures", "forbiddenCpuFeatures")) {
    if (-not $selfhostContext.Contains($contextField, [StringComparison]::Ordinal) -or
        -not $selfhostEntrypoints.Contains($contextField, [StringComparison]::Ordinal)) {
        throw "self-host LLVM context does not carry '$contextField' from the target descriptor"
    }
}
if (-not $cache.Contains("TargetContract.For(target).CacheKey", [StringComparison]::Ordinal)) {
    throw "incremental codegen cache identity omits the CPU target contract"
}
$generator = [IO.File]::ReadAllText(
    (Join-Path $RepositoryRoot "src/Sollang.Compiler/CodeGen/LlvmIrGenerator.cs"))
$emitter = [IO.File]::ReadAllText(
    (Join-Path $RepositoryRoot "src/Sollang.Compiler/CodeGen/LlvmEmitter.cs"))
if (-not $generator.Contains("TargetContract.For(target)", [StringComparison]::Ordinal) -or
    -not $emitter.Contains("_targetContract.CacheKey", [StringComparison]::Ordinal)) {
    throw "managed LLVM generation does not carry and identify the canonical CPU target contract"
}
$x64RequiredValue = [UInt64]$registry.architectures.x86_64.baselineMask
$x64AllowedValue = [UInt64]$registry.architectures.x86_64.allowedMask
$x64AllowedText = $x64AllowedValue.ToString('N0', [Globalization.CultureInfo]::InvariantCulture).Replace(',', '_')
$x64Required = [regex]::Matches($selfhost, "(?m)^\s*requiredFeatures: $x64RequiredValue$").Count
$x64Allowed = [regex]::Matches($selfhost, "(?m)^\s*allowedFeatures: $x64AllowedText$").Count
$browserBaseline = [regex]::IsMatch(
    $selfhost,
    '(?s)public wasm32Browser:.*?dispatchPolicy: 0.*?requiredFeatures: 0.*?allowedFeatures: 0.*?forbiddenFeatures: 0')
if ($x64Required -ne 2 -or $x64Allowed -ne 2 -or -not $browserBaseline) {
    throw "managed/self-host default target feature contracts are no longer aligned"
}

Write-Output (
    "CPU target contract PASS: {0} architectures, {1} typed features, {2} specializations, x64 runtime-detect defaults, browser baseline, and cache identity." -f
    $architectures.Count,
    $features.Count,
    @($registry.specializations.PSObject.Properties).Count)
