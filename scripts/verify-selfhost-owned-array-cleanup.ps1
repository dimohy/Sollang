[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Compiler,
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$LlvmRoot = '',
    [string[]]$Fixture = @()
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'verification-process.ps1')
$repoRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
if ([string]::IsNullOrWhiteSpace($LlvmRoot)) { $LlvmRoot = Join-Path $repoRoot '.tools/llvm-22.1.8' }
$assembler = (Resolve-Path (Join-Path $LlvmRoot 'bin/llvm-as.exe')).Path
$clang = (Resolve-Path (Join-Path $LlvmRoot 'bin/clang.exe')).Path
$shim = (Resolve-Path (Join-Path $repoRoot 'tests/native-interop/owned_array_audit.c')).Path
$compilerHash = (Get-FileHash -LiteralPath $compilerPath).Hash
$outputRoot = Join-Path $repoRoot "artifacts/owned-array-cleanup/$compilerHash"
[IO.Directory]::CreateDirectory($outputRoot) | Out-Null
$cases = @(
    @{name='882-stdlib-hmac-hkdf';expected='hmac-hkdf=ok';allocations=65},
    @{name='1631-boxed-enum-member-consume';allocations=1;expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1631-boxed-enum-member-consume.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd()},
    @{name='1632-boxed-enum-member-borrow-reuse';allocations=1;expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1632-boxed-enum-member-borrow-reuse.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd()},
    @{name='1633-boxed-temporary-readonly-call';allocations=1;expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1633-boxed-temporary-readonly-call.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd()},
    @{name='1626-boxed-recursive-enum-cleanup';allocations=1;expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1626-boxed-recursive-enum-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd()},
    @{name='1627-boxed-enum-named-match-reuse';allocations=1;expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1627-boxed-enum-named-match-reuse.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd()},
    @{name='1628-boxed-enum-payload-transfer';allocations=1;expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1628-boxed-enum-payload-transfer.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd()},
    @{name='1629-boxed-primitive-cleanup';allocations=1;expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1629-boxed-primitive-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd()},
    @{name='1630-boxed-nested-cleanup';allocations=2;expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1630-boxed-nested-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd()},
    @{name='1466-moving-fixed-array-implicit-cleanup';expected='2';allocations=2},
    @{name='1467-moving-fixed-array-explicit-cleanup';expected='2';allocations=2},
    @{name='1472-region-array-owned-transfer';expected='1';allocations=2},
    @{name='1475-region-array-partial-field-transfer';expected='1';allocations=3},
    @{name='1479-conditional-fixed-array-unconsumed-cleanup';expected='2';allocations=2},
    @{name='1481-resolved-call-early-return-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1481-resolved-call-early-return-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=6},
    @{name='1504-readonly-fixed-call-temporary-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1504-readonly-fixed-call-temporary-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=3},
    @{name='1505-readonly-independent-copy-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1505-readonly-independent-copy-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1},
    @{name='1506-readonly-owned-element-temporary-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1506-readonly-owned-element-temporary-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=2},
    @{name='1508-named-fixed-named-reuse-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1508-named-fixed-named-reuse-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1},
    @{name='1509-named-fixed-stack-literal-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1509-named-fixed-stack-literal-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=0},
    @{name='1510-named-fixed-implicit-return-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1510-named-fixed-implicit-return-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1},
    @{name='1511-named-fixed-explicit-return-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1511-named-fixed-explicit-return-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1},
    @{name='1512-named-fixed-early-scalar-return-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1512-named-fixed-early-scalar-return-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=2},
    @{name='1513-named-fixed-owned-element-named-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1513-named-fixed-owned-element-named-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=2},
    @{name='1514-named-fixed-moved-owner-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1514-named-fixed-moved-owner-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=2},
    @{name='1515-named-fixed-ref-return-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1515-named-fixed-ref-return-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=0},
    @{name='1516-named-fixed-before-binding-return-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1516-named-fixed-before-binding-return-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1},
    @{name='1517-named-fixed-loop-region-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1517-named-fixed-loop-region-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=2},
    @{name='1519-fixed-stack-argument-return';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1519-fixed-stack-argument-return.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1},
    @{name='1520-fixed-named-argument-return';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1520-fixed-named-argument-return.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=2},
    @{name='1521-fixed-implicit-moving-wrapper';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1521-fixed-implicit-moving-wrapper.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=2},
    @{name='1522-fixed-explicit-moving-wrapper';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1522-fixed-explicit-moving-wrapper.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=2},
    @{name='1523-fixed-owned-explicit-wrapper';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1523-fixed-owned-explicit-wrapper.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=3},
    @{name='1524-fixed-owned-implicit-wrapper';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1524-fixed-owned-implicit-wrapper.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=3},
    @{name='1525-fixed-additional-argument-return';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1525-fixed-additional-argument-return.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=2},
    @{name='1526-fixed-branch-explicit-return';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1526-fixed-branch-explicit-return.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=2},
    @{name='1527-projected-table-push-loop';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1527-projected-table-push-loop.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=5},
    @{name='1528-fixed-field-factory';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1528-fixed-field-factory.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1},
    @{name='1529-fixed-field-named';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1529-fixed-field-named.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1},
    @{name='1530-fixed-field-stack';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1530-fixed-field-stack.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=0},
    @{name='1531-fixed-field-owned';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1531-fixed-field-owned.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=2},
    @{name='1532-fixed-field-region';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1532-fixed-field-region.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=2},
    @{name='1533-fixed-branch-binding';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1533-fixed-branch-binding.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1},
    @{name='1534-fixed-branch-loop-binding';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1534-fixed-branch-loop-binding.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1},
    @{name='1535-branch-value-owner';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1535-branch-value-owner.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=2},
    @{name='1536-branch-value-fixed';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1536-branch-value-fixed.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=2},
    @{name='1537-branch-fixed-mixed-storage';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1537-branch-fixed-mixed-storage.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=2},
    @{name='1538-branch-fixed-outer-reuse';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1538-branch-fixed-outer-reuse.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=4},
    @{name='1539-branch-fixed-owned-elements';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1539-branch-fixed-owned-elements.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=4},
    @{name='1540-branch-fixed-mutable-local';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1540-branch-fixed-mutable-local.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=4},
    @{name='1541-branch-fixed-return';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1541-branch-fixed-return.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=2},
    @{name='1543-fixed-int-branch-result';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1543-fixed-int-branch-result.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=2},
    @{name='1544-fixed-text-branch-result';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1544-fixed-text-branch-result.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=2},
    @{name='1542-entry-branch-lifetime';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1542-entry-branch-lifetime.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=2},
    @{name='1545-fixed-field-copy-independence';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1545-fixed-field-copy-independence.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1},
    @{name='1554-borrowed-fixed-field-copy-independence';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1554-borrowed-fixed-field-copy-independence.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=2},
    @{name='1563-borrowed-fixed-return-copy-independence';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1563-borrowed-fixed-return-copy-independence.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1},
    @{name='1564-borrowed-nested-fixed-field-copy-independence';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1564-borrowed-nested-fixed-field-copy-independence.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1},
    @{name='1567-borrowed-temporary-record-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1567-borrowed-temporary-record-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1},
    @{name='1568-borrowed-named-record-reuse';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1568-borrowed-named-record-reuse.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1},
    @{name='1569-borrowed-flow-temporary-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1569-borrowed-flow-temporary-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1},
    @{name='1570-borrowed-temporary-enum-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1570-borrowed-temporary-enum-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1},
    @{name='1571-borrowed-temporary-independent-result';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1571-borrowed-temporary-independent-result.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=2},
    @{name='1572-borrowed-nested-flow-argument-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1572-borrowed-nested-flow-argument-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1},
    @{name='1573-named-mutable-receiver-borrow-reuse';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1573-named-mutable-receiver-borrow-reuse.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1},
    @{name='1574-consuming-temporary-receiver-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1574-consuming-temporary-receiver-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1},
    @{name='1575-borrowed-enum-variant-tag-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1575-borrowed-enum-variant-tag-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=2},
    @{name='1576-consuming-enum-match-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1576-consuming-enum-match-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=2},
    @{name='1577-consuming-enum-payload-transfer';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1577-consuming-enum-payload-transfer.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=3},
    @{name='1578-borrowed-named-enum-reuse';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1578-borrowed-named-enum-reuse.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1},
    @{name='1579-borrowed-record-literal-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1579-borrowed-record-literal-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1},
    @{name='1580-borrowed-array-literal-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1580-borrowed-array-literal-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1},
    @{name='1581-borrowed-enum-literal-cleanup';expected=(Get-Content (Join-Path $repoRoot 'examples/regression/expected/1581-borrowed-enum-literal-cleanup.stdout.txt') -Raw).Replace("`r`n","`n").TrimEnd();allocations=1}
)
if ($Fixture.Count -gt 0) {
    $unknown = @($Fixture | Where-Object { $_ -notin $cases.name })
    if ($unknown.Count -gt 0) { throw "Unknown cleanup fixture: $($unknown -join ', ')" }
    $cases = @($cases | Where-Object { $_.name -in $Fixture })
    $selection = [Text.Encoding]::UTF8.GetBytes(($cases.name -join "`n"))
    $selectionHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($selection))
    $outputRoot = Join-Path $outputRoot "selected-$selectionHash"
    [IO.Directory]::CreateDirectory($outputRoot) | Out-Null
}
foreach ($case in $cases) {
    $source = (Resolve-Path (Join-Path $repoRoot "examples/regression/$($case.name).slg")).Path
    $manifest = Join-Path $repoRoot "examples/regression/expected/$($case.name).sources.txt"
    $case.sourcePaths = @(if (Test-Path -LiteralPath $manifest) {
        Get-Content -LiteralPath $manifest | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { (Resolve-Path -LiteralPath (Join-Path $repoRoot $_.Trim())).Path }
    } else { $source })
    if (-not $case.sourcePaths.Contains($source)) { throw "Cleanup manifest must contain its executable root: $manifest" }
}
function Invoke-CleanupProcess {
    param([string]$FilePath, [string[]]$Arguments, [string]$Description)
    $result = Invoke-VerificationProcessCapture -FilePath $FilePath -ArgumentList $Arguments -WorkingDirectory $repoRoot -Description $Description -TimeoutMilliseconds 120000
    if ($result.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($result.Stderr)) {
        throw "$Description exit=$($result.ExitCode): $($result.Stdout) $($result.Stderr)"
    }
    $result.Stdout
}
$results = foreach ($case in $cases) {
    $source = Join-Path $repoRoot "examples/regression/$($case.name).slg"
    $prefix = Join-Path $outputRoot $case.name
    $item = [ordered]@{fixture=$case.name;sourceSha256=(Get-FileHash $source).Hash;sourceInputs=@($case.sourcePaths | ForEach-Object { @{path=$_;sha256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash} });passed=$false;output='';error=$null}
    try {
        $llvm = Invoke-CleanupProcess $compilerPath (@('windows') + $case.sourcePaths) "$($case.name) emit"
        if ($llvm -notmatch '(?m)^target triple' -or $llvm -notmatch 'define i32 @main\(\)') { throw 'Missing LLVM target or main entry' }
        [IO.File]::WriteAllText("$prefix.ll",$llvm,[Text.UTF8Encoding]::new($false))
        $null = Invoke-CleanupProcess $assembler @("$prefix.ll",'-o',"$prefix.bc") "$($case.name) assemble"
        # Instrument only the generated program; C library allocations are excluded.
        $auditLlvm = $llvm.Replace('@malloc(', '@audit_malloc(').Replace('@realloc(', '@audit_realloc(').Replace('@free(', '@audit_free(').Replace('@main()', '@slg_program_main()')
        [IO.File]::WriteAllText("$prefix.audit.ll",$auditLlvm,[Text.UTF8Encoding]::new($false))
        $null = Invoke-CleanupProcess $clang @('-Wno-override-module',"-DEXPECTED_ALLOCATIONS=$($case.allocations)","$prefix.audit.ll",$shim,'-O1','-o',"$prefix.exe") "$($case.name) link"
        $item.output = (Invoke-CleanupProcess "$prefix.exe" @() "$($case.name) execute").Replace("`r`n","`n").TrimEnd()
        if ($item.output -cne "$($case.expected)`nallocations=$($case.allocations),releases=$($case.allocations)") { throw "Cleanup count or stdout mismatch: $($item.output)" }
        $item.passed = $true
    } catch { $item.error = $_.Exception.Message }
    [pscustomobject]$item
}
if ((Get-FileHash -LiteralPath $compilerPath).Hash -ne $compilerHash) { throw 'Cleanup compiler changed during verification' }
$report = [ordered]@{compiler=$compilerPath;compilerSha256=$compilerHash;passed=@($results | Where-Object passed).Count;total=$cases.Count;cases=@($results)}
$report | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $outputRoot 'results.json') -Encoding utf8
if ($report.passed -ne $report.total) { throw "Owned array cleanup $($report.passed)/$($report.total): $($results | ConvertTo-Json -Depth 4 -Compress)" }
Write-Host "[owned array cleanup] PASS $($report.passed)/$($report.total) exact allocation/release counts."
