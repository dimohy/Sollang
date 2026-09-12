[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$AllowMissingGolden
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'llvm-no-allocation-audit.ps1')
$root = [IO.Path]::GetFullPath($RepositoryRoot)
$compiler = Join-Path $root 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll'
$module = Join-Path $root 'stdlib/std/path.slg'
$fixture = Join-Path $root 'examples/regression/1726-path-components.slg'
$golden = Join-Path $root 'examples/regression/expected/1726-path-components.stdout.txt'
$contractPath = Join-Path $root 'scripts/contracts/path-components.json'
$schemaPath = Join-Path $root 'scripts/contracts/path-components.schema.json'
$negative = Join-Path $root 'examples/regression/diagnostics/path-components-source-escape.slg'
$negativeExpected = Join-Path $root 'examples/regression/diagnostics/path-components-source-escape.stderr.contains.txt'
$llvm = Join-Path $root '.tools/llvm-22.1.8'
$auditHelper = Join-Path $root 'scripts/llvm-no-allocation-audit.ps1'
$allowedDiagnosticExternals = @('GetStdHandle', 'WriteFile', 'llvm.trap')
$output = Join-Path $root ('artifacts/scratch/path-components-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($output) | Out-Null
$resultPath = Join-Path $output 'result.json'
$goldenExists = Test-Path -LiteralPath $golden -PathType Leaf
if (-not $goldenExists -and -not $AllowMissingGolden) { throw "path components golden is missing: $golden" }
$inputs = @($compiler, $module, $fixture, $contractPath, $schemaPath, $negative, $negativeExpected, $auditHelper, $PSCommandPath)
if ($goldenExists) { $inputs += $golden }
$hashes = [ordered]@{}
foreach ($path in $inputs) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "path components input is missing: $path" }
    $hashes[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$record = [ordered]@{
    schemaVersion = 1
    scope = 'managed-windows-bounded-lexical-path-components'
    status = 'running'
    completed = 0
    total = if ($goldenExists) { 9 } else { 8 }
    goldenPublished = $goldenExists
    artifactDirectory = $output
    runLog = Join-Path $output 'run.log'
    inputHashes = $hashes
    integration = 'focused managed only; selfhost and Stage2/Stage3 not executed'
    checks = @()
}
function Write-Record {
    [IO.File]::WriteAllText($resultPath, (($record | ConvertTo-Json -Depth 8) + "`n"), [Text.UTF8Encoding]::new($false))
}
function Complete-Check([string]$Name) {
    $record.completed++
    $record.checks += $Name
    Write-Record
}
function Test-Separator([byte]$Byte, [bool]$Windows) {
    return $Byte -eq 47 -or ($Windows -and $Byte -eq 92)
}
function Get-ReferenceLines([string]$Label, [string]$Text, [bool]$Windows) {
    [byte[]]$bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    $length = $bytes.Length
    $lines = [Collections.Generic.List[string]]::new()
    $index = 0
    if (-not $Windows -and $length -gt 0 -and $bytes[0] -eq 47) {
        $lines.Add("$Label=PosixRoot@0+1")
        $index = 1
    } elseif ($Windows -and $length -ge 2 -and $bytes[1] -eq 58) {
        $lines.Add("$Label=DrivePrefix@0+2")
        $index = 2
        if ($length -ge 3 -and (Test-Separator $bytes[2] $true)) {
            $lines.Add("$Label=WindowsRoot@2+1")
            $index = 3
        }
    } elseif ($Windows -and $length -ge 2 -and
        (Test-Separator $bytes[0] $true) -and (Test-Separator $bytes[1] $true)) {
        $cursor = 2
        while ($cursor -lt $length -and -not (Test-Separator $bytes[$cursor] $true)) { $cursor++ }
        $cursor++
        while ($cursor -lt $length -and -not (Test-Separator $bytes[$cursor] $true)) { $cursor++ }
        $lines.Add("$Label=UncRoot@0+$cursor")
        $index = $cursor
    } elseif ($Windows -and $length -gt 0 -and (Test-Separator $bytes[0] $true)) {
        $lines.Add("$Label=WindowsRoot@0+1")
        $index = 1
    }
    while ($true) {
        while ($index -lt $length -and (Test-Separator $bytes[$index] $Windows)) { $index++ }
        if ($index -eq $length) { break }
        $start = $index
        while ($index -lt $length -and -not (Test-Separator $bytes[$index] $Windows)) { $index++ }
        $componentLength = $index - $start
        $kind = if ($componentLength -eq 1 -and $bytes[$start] -eq 46) {
            'CurrentDirectory'
        } elseif ($componentLength -eq 2 -and $bytes[$start] -eq 46 -and $bytes[$start + 1] -eq 46) {
            'ParentDirectory'
        } else {
            'Normal'
        }
        $lines.Add("$Label=$kind@$start+$componentLength")
    }
    $lines.Add("$Label=end@$length")
    return $lines.ToArray()
}

try {
    $contractText = [IO.File]::ReadAllText($contractPath)
    if (-not (Test-Json -Json $contractText -SchemaFile $schemaPath -ErrorAction Stop)) {
        throw 'path components contract does not satisfy its schema'
    }
    $contract = $contractText | ConvertFrom-Json
    if ($contract.referenceCases.Count -ne 9 -or
        @($contract.referenceCases.label | Sort-Object -Unique).Count -ne 9 -or
        $contract.componentKinds.Count -ne 7 -or $contract.errorKinds.Count -ne 7) {
        throw 'path components contract dimensions differ from the fixed profile'
    }
    foreach ($case in $contract.referenceCases) {
        [byte[]]$caseBytes = [Text.Encoding]::UTF8.GetBytes([string]$case.input)
        $previousEnd = 0
        foreach ($component in $case.components) {
            if ($component.length -le 0 -or $component.offset -lt $previousEnd -or
                $component.offset + $component.length -gt $caseBytes.Length) {
                throw "path components contract contains an invalid UTF-8 byte span: $($case.label)"
            }
            $previousEnd = $component.offset + $component.length
        }
        $derived = @(Get-ReferenceLines $case.label $case.input ($case.style -ceq 'Windows'))
        $declared = @($case.components | ForEach-Object { "$($case.label)=$($_.kind)@$($_.offset)+$($_.length)" }) +
            "$($case.label)=end@$($caseBytes.Length)"
        if (($derived -join "`n") -cne ($declared -join "`n")) {
            throw "path components reference case differs from independent lexical parsing: $($case.label)"
        }
    }
    Complete-Check 'contract-schema-and-independent-reference-shape'
    $diagnostic = ([IO.File]::ReadAllText($negativeExpected)).Trim()
    if ([string]::IsNullOrWhiteSpace($diagnostic)) { throw 'path components source-escape diagnostic must not be empty' }
    & (Join-Path $root 'scripts/format-authoritative-slg.ps1') -Check -Source @($module, $fixture, $negative)
    Complete-Check 'authoritative-format'
    $exe = Join-Path $output 'path-components.exe'
    $actual = (& dotnet $compiler run $fixture --llvm $llvm -o $exe --keep-temps 2>&1) -join "`n"
    $exitCode = $LASTEXITCODE
    [IO.File]::WriteAllText((Join-Path $output 'run.log'), $actual + "`n")
    if ($exitCode -ne 0 -or -not (Test-Path -LiteralPath $exe -PathType Leaf) -or $actual -match '(?m)^warning\s') {
        throw "path components warning-free assemble/link/execute failed (exit $exitCode): $actual"
    }
    $record.executableSha256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
    Complete-Check 'warning-free-native-assemble-link-execute'
    $actual = $actual.Replace("`r`n", "`n").TrimEnd()
    $reference = [Collections.Generic.List[string]]::new()
    foreach ($case in $contract.referenceCases) {
        foreach ($line in Get-ReferenceLines $case.label $case.input ($case.style -ceq 'Windows')) { $reference.Add($line) }
    }
    foreach ($case in @(
        @{ label = 'posix-repeat'; text = '///a//'; windows = $false },
        @{ label = 'posix-colon'; text = 'a:b'; windows = $false },
        @{ label = 'windows-repeat'; text = 'foo\\bar'; windows = $true }
    )) {
        foreach ($line in Get-ReferenceLines $case.label $case.text $case.windows) { $reference.Add($line) }
    }
    foreach ($line in @(
        'invalid-limits=InvalidLimits@0',
        'input-limit=InputLimit@0',
        'nul=InvalidNul@1',
        'namespace=UnsupportedNamespace@0',
        'triple-root=InvalidPrefix@0',
        'unc-incomplete=InvalidPrefix@0',
        'unc-dot-share=InvalidPrefix@0',
        'count-prior=PosixRoot@0+1',
        'count-0=ComponentLimit@1,stable=true',
        'count-1=ComponentLimit@1,stable=true',
        'size-prior=PosixRoot@0+1',
        'size-0=ComponentSizeLimit@1,stable=true',
        'size-1=ComponentSizeLimit@1,stable=true',
        'precedence-0=ComponentLimit@0,stable=true',
        'precedence-1=ComponentLimit@0,stable=true'
    )) { $reference.Add($line) }
    foreach ($line in Get-ReferenceLines 'exact' '/abc' $false) { $reference.Add($line) }
    $reference.Add('metadata=Normal@0+1')
    $referenceText = ($reference -join "`n").TrimEnd()
    [IO.File]::WriteAllText((Join-Path $output 'reference.stdout.txt'), $referenceText + "`n")
    if ($actual -cne $referenceText) { throw 'path components output differs from the independent UTF-8 lexical reference' }
    Complete-Check 'independent-utf8-lexical-reference'
    if ($goldenExists) {
        [byte[]]$goldenBytes = [IO.File]::ReadAllBytes($golden)
        $goldenText = [Text.UTF8Encoding]::new($false, $true).GetString($goldenBytes)
        if (($goldenBytes.Length -ge 3 -and $goldenBytes[0] -eq 239 -and $goldenBytes[1] -eq 187 -and $goldenBytes[2] -eq 191) -or
            $goldenText.Contains("`r") -or -not $goldenText.EndsWith("`n", [StringComparison]::Ordinal)) {
            throw 'path components golden must be BOM-free canonical LF UTF-8 ending in one newline'
        }
        $actualCanonical = Join-Path $output 'actual.stdout.txt'
        [IO.File]::WriteAllText($actualCanonical, $actual + "`n", [Text.UTF8Encoding]::new($false))
        if ((Get-FileHash -LiteralPath $actualCanonical -Algorithm SHA256).Hash -cne
            (Get-FileHash -LiteralPath $golden -Algorithm SHA256).Hash) {
            throw 'path components canonical output hash differs from the published golden'
        }
        Complete-Check 'published-golden'
    }
    $irPath = [IO.Path]::ChangeExtension($exe, '.ll')
    & (Join-Path $llvm 'bin/llvm-as.exe') $irPath -o ([IO.Path]::ChangeExtension($exe, '.bc'))
    if ($LASTEXITCODE -ne 0) { throw 'path components LLVM assembly failed' }
    & (Join-Path $root 'scripts/verify-llvm-direct-call-closure.ps1') -LlvmPath $irPath
    $record.llvmSha256 = (Get-FileHash -LiteralPath $irPath -Algorithm SHA256).Hash
    Complete-Check 'llvm-assembly-and-direct-call-closure'
    $audit = Assert-LlvmNoAllocation -LlvmText ([IO.File]::ReadAllText($irPath)) `
        -RootSymbolPattern '^sollang_fn_std_path_' -AllowedExternalSymbols $allowedDiagnosticExternals
    $record.allocationAuditExternalSymbols = @($audit.ExternalSymbols)
    Complete-Check 'transitive-library-no-allocation'
    $negativeExe = Join-Path $output 'path-components-source-escape.exe'
    $negativeLlvm = [IO.Path]::ChangeExtension($negativeExe, '.ll')
    $negativeTemporaryLlvm = Join-Path $output 'path-components-source-escape.slg-tmp/path-components-source-escape.ll'
    $failure = (& dotnet $compiler build $negative --llvm $llvm -o $negativeExe --keep-temps 2>&1) -join "`n"
    $failureExit = $LASTEXITCODE
    [IO.File]::WriteAllText((Join-Path $output 'source-escape.log'), $failure + "`n")
    $products = @(@($negativeExe, $negativeLlvm, $negativeTemporaryLlvm) | Where-Object { Test-Path -LiteralPath $_ })
    if ($failureExit -eq 0 -or $failure -notmatch 'semantic error' -or
        -not $failure.Contains($diagnostic, [StringComparison]::Ordinal) -or $products.Count -ne 0) {
        throw 'path components source escape did not fail before LLVM with the expected diagnostic'
    }
    Complete-Check 'source-owner-escape-negative'
    foreach ($path in $hashes.Keys) {
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $hashes[$path]) {
            throw "path components verification input changed during execution: $path"
        }
    }
    $record.inputsStable = $true
    Complete-Check 'input-hash-stability'
    $record.referenceLineCount = $reference.Count
    $record.libraryBodyCount = $audit.RootCount
    $record.reachableBodyCount = $audit.ReachableBodyCount
    if ($record.completed -ne $record.total) { throw 'path components focused check count differs from contract' }
    $record.status = 'passed'
} catch {
    $record.status = 'failed'
    $record.failure = $_.Exception.Message
    throw
} finally {
    Write-Record
    Write-Host "[path components focused] $($record.status) $($record.completed)/$($record.total); $resultPath"
}
