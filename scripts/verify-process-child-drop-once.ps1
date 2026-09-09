param(
    [Parameter(Mandatory = $true)]
    [string]$LlvmPath
)

$ErrorActionPreference = "Stop"

$resolvedLlvmPath = (Resolve-Path -LiteralPath $LlvmPath).Path
$llvm = [System.IO.File]::ReadAllText($resolvedLlvmPath).Replace("`r`n", "`n")
$dropDefinitions = [regex]::Matches(
    $llvm,
    '(?ms)^define(?:\s+internal)?\s+void\s+@(?<name>sollang_drop_(?:t)?\d+)\([^\r\n]*\)[^{]*\{(?<body>.*?)^\}')

if ($dropDefinitions.Count -eq 0) {
    throw "process Child drop verification found no generated Sollang drop glue in '$resolvedLlvmPath'"
}

$dropBodies = @{}
foreach ($definition in $dropDefinitions) {
    $dropBodies[$definition.Groups['name'].Value] = $definition.Groups['body'].Value
}

$processChildDropNames = @(
    $dropBodies.Keys |
        Where-Object { $dropBodies[$_].Contains('call void @sollang_drop_process_child(i64') }
)
if ($processChildDropNames.Count -ne 1) {
    throw "process Child drop verification expected one direct Child drop glue, found $($processChildDropNames.Count) in '$resolvedLlvmPath'"
}

$ownedDropNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$null = $ownedDropNames.Add($processChildDropNames[0])
$changed = $true
while ($changed) {
    $changed = $false
    foreach ($candidateName in $dropBodies.Keys) {
        if ($ownedDropNames.Contains($candidateName)) {
            continue
        }
        foreach ($ownedDropName in @($ownedDropNames)) {
            if ($dropBodies[$candidateName] -match "call void @$([regex]::Escape($ownedDropName))\(") {
                $null = $ownedDropNames.Add($candidateName)
                $changed = $true
                break
            }
        }
    }
}

$rootDropNames = @(
    $ownedDropNames |
        Where-Object {
            $candidateName = $_
            -not ($dropBodies.Keys | Where-Object {
                $_ -ne $candidateName -and
                $ownedDropNames.Contains($_) -and
                $dropBodies[$_] -match "call void @$([regex]::Escape($candidateName))\("
            })
        }
)
if ($rootDropNames.Count -ne 1) {
    throw "process Child drop verification expected one outer owned drop root, found $($rootDropNames.Count) in '$resolvedLlvmPath'"
}

$externalRootCalls = 0
$externalNestedCalls = [System.Collections.Generic.List[string]]::new()
$dropCalls = [regex]::Matches($llvm, '(?m)^\s*call void @(?<name>sollang_drop_(?:t)?\d+)\(')
foreach ($dropCall in $dropCalls) {
    $insideDropDefinition = $false
    foreach ($definition in $dropDefinitions) {
        if ($dropCall.Index -ge $definition.Index -and
            $dropCall.Index -lt $definition.Index + $definition.Length) {
            $insideDropDefinition = $true
            break
        }
    }
    if ($insideDropDefinition) {
        continue
    }

    $dropName = $dropCall.Groups['name'].Value
    if (-not $ownedDropNames.Contains($dropName)) {
        continue
    }
    if ($rootDropNames -contains $dropName) {
        $externalRootCalls += 1
    } else {
        $externalNestedCalls.Add($dropName)
    }
}

if ($externalNestedCalls.Count -ne 0) {
    throw "process Child consumed by wait must not receive a direct nested cleanup; found $($externalNestedCalls.Count) call(s) to $($externalNestedCalls -join ', ') in '$resolvedLlvmPath'"
}
if ($externalRootCalls -gt 1) {
    throw "process Child owner must not be cleaned up a second time after its consuming wait; generated outer drop $($rootDropNames[0]) has $externalRootCalls external call sites in '$resolvedLlvmPath'"
}

Write-Host "PASS process Child consuming wait has no second cleanup (outer calls $externalRootCalls, nested calls 0)."
