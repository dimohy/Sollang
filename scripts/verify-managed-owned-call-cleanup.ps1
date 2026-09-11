[CmdletBinding()]
param(
    [string]$CompilerAssembly = '',
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$FixtureRoot = '',
    [string]$LlvmRoot = '',
    [string[]]$Fixture = @()
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
. (Join-Path $repoRoot 'scripts/verification-process.ps1')
if (!$CompilerAssembly) { $CompilerAssembly = Join-Path $repoRoot 'src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.dll' }
if (!$FixtureRoot) { $FixtureRoot = Join-Path $repoRoot 'examples/regression' }
if (!$LlvmRoot) { $LlvmRoot = Join-Path $repoRoot '.tools/llvm-22.1.8' }
$compiler = (Resolve-Path -LiteralPath $CompilerAssembly).Path
$fixtures = (Resolve-Path -LiteralPath $FixtureRoot).Path
$clang = (Resolve-Path -LiteralPath (Join-Path $LlvmRoot 'bin/clang.exe')).Path
$shim = (Resolve-Path -LiteralPath (Join-Path $repoRoot 'tests/native-interop/owned_array_audit.c')).Path
$cases = @(
    @{name='1631-boxed-enum-member-consume';allocations=1},
    @{name='1632-boxed-enum-member-borrow-reuse';allocations=1},
    @{name='1633-boxed-temporary-readonly-call';allocations=1},
    @{name='1646-owned-runtime-result-field-cleanup';allocations=1},
    @{name='1647-borrowed-runtime-result-field-reuse';allocations=1},
    @{name='1623-owned-option-enum-payload-cleanup';allocations=1},
    @{name='1624-owned-result-enum-payload-cleanup';allocations=1},
    @{name='1626-boxed-recursive-enum-cleanup';allocations=1},
    @{name='1627-boxed-enum-named-match-reuse';allocations=1},
    @{name='1628-boxed-enum-payload-transfer';allocations=1},
    @{name='1629-boxed-primitive-cleanup';allocations=1},
    @{name='1630-boxed-nested-cleanup';allocations=2},
    @{name='1499-projected-owned-call-lifetime';allocations=12},
    @{name='1500-readonly-call-temporary-lifetime';allocations=10},
    @{name='1527-projected-table-push-loop';allocations=5},
    @{name='1529-fixed-field-named';allocations=2},
    @{name='1536-branch-value-fixed';allocations=2},
    @{name='1537-branch-fixed-mixed-storage';allocations=2},
    @{name='1538-branch-fixed-outer-reuse';allocations=4},
    @{name='1539-branch-fixed-owned-elements';allocations=4},
    @{name='1540-branch-fixed-mutable-local';allocations=2},
    @{name='1541-branch-fixed-return';allocations=2},
    @{name='1543-fixed-int-branch-result';allocations=2},
    @{name='1544-fixed-text-branch-result';allocations=2},
    @{name='1545-fixed-field-copy-independence';allocations=6},
    @{name='1547-owned-branch-taken';allocations=3},
    @{name='1548-owned-nested-terminating-branch';allocations=6},
    @{name='1549-owned-when-terminating-branch';allocations=6},
    @{name='1553-projected-push-sibling-reuse';allocations=2},
    @{name='1554-borrowed-fixed-field-copy-independence';allocations=3},
    @{name='1563-borrowed-fixed-return-copy-independence';allocations=1},
    @{name='1564-borrowed-nested-fixed-field-copy-independence';allocations=3},
    @{name='1567-borrowed-temporary-record-cleanup';allocations=1},
    @{name='1568-borrowed-named-record-reuse';allocations=1},
    @{name='1569-borrowed-flow-temporary-cleanup';allocations=1},
    @{name='1570-borrowed-temporary-enum-cleanup';allocations=1},
    @{name='1571-borrowed-temporary-independent-result';allocations=2},
    @{name='1572-borrowed-nested-flow-argument-cleanup';allocations=1},
    @{name='1573-named-mutable-receiver-borrow-reuse';allocations=1},
    @{name='1574-consuming-temporary-receiver-cleanup';allocations=1},
    @{name='1575-borrowed-enum-variant-tag-cleanup';allocations=2},
    @{name='1576-consuming-enum-match-cleanup';allocations=2},
    @{name='1577-consuming-enum-payload-transfer';allocations=3},
    @{name='1578-borrowed-named-enum-reuse';allocations=1},
    @{name='1579-borrowed-record-literal-cleanup';allocations=1},
    @{name='1580-borrowed-array-literal-cleanup';allocations=1},
    @{name='1581-borrowed-enum-literal-cleanup';allocations=1}
)
if ($Fixture.Count -gt 0) {
    $unknown = @($Fixture | Where-Object { $_ -notin $cases.name })
    if ($unknown.Count -gt 0) { throw "Unknown cleanup fixture: $($unknown -join ', ')" }
    $cases = @($cases | Where-Object { $_.name -in $Fixture })
}
foreach ($case in $cases) {
    $case.source = (Resolve-Path -LiteralPath (Join-Path $fixtures "$($case.name).slg")).Path
    $case.expected = (Resolve-Path -LiteralPath (Join-Path $fixtures "expected/$($case.name).stdout.txt")).Path
}
$compilerHash = (Get-FileHash -LiteralPath $compiler).Hash
$output = Join-Path $repoRoot "artifacts/managed-owned-call-cleanup/$compilerHash"
if ($Fixture.Count -gt 0) {
    $selection = [Text.Encoding]::UTF8.GetBytes(($cases.name -join "`n"))
    $selectionHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($selection))
    $output = Join-Path $output "selected-$selectionHash"
}
New-Item -ItemType Directory -Path $output -Force | Out-Null
function Invoke-CheckedCleanupProcess {
    param([string]$Program, [string[]]$Arguments, [string]$Description)
    $result = Invoke-VerificationProcessCapture -FilePath $Program -ArgumentList $Arguments -WorkingDirectory $repoRoot -Description $Description -TimeoutMilliseconds 120000
    if ($result.ExitCode -ne 0 -or ![string]::IsNullOrWhiteSpace($result.Stderr) -or $result.Stdout -match '(?m)^(warning|note) ') {
        throw "$Description exit=$($result.ExitCode): $($result.Stdout) $($result.Stderr)"
    }
    return $result.Stdout
}
$results = foreach ($case in $cases) {
    $prefix = Join-Path $output $case.name
    $item = [ordered]@{fixture=$case.name;sourceSha256=(Get-FileHash $case.source).Hash;expectedSha256=(Get-FileHash $case.expected).Hash;allocations=$case.allocations;passed=$false;output='';error=$null}
    try {
        $null = Invoke-CheckedCleanupProcess 'dotnet' @($compiler,'build',$case.source,'-o',"$prefix.exe",'--target','windows-x64','--llvm',$LlvmRoot,'-O1','--keep-temps') "$($case.name) managed build"
        $llvm = Get-Content -LiteralPath "$prefix.ll" -Raw
        if ($llvm -notmatch 'define dso_local i32 @sollang_start\(\)') { throw 'Missing managed Windows program entry' }
        # Replace only the generated program allocation wrappers. The same C
        # shim used by the native ownership gate audits balanced program drops.
        $audit = $llvm.Replace('call ptr @sollang_alloc(', 'call ptr @audit_malloc(').Replace('call void @sollang_free(', 'call void @audit_free(').Replace('@sollang_start()', '@slg_program_main()')
        $audit += "`ndeclare ptr @audit_malloc(i64)`ndeclare void @audit_free(ptr)`n"
        [IO.File]::WriteAllText("$prefix.audit.ll",$audit,[Text.UTF8Encoding]::new($false))
        $null = Invoke-CheckedCleanupProcess $clang @('-Wno-override-module',"-DEXPECTED_ALLOCATIONS=$($case.allocations)","$prefix.audit.ll",$shim,'-O1','-o',"$prefix.audit.exe") "$($case.name) allocation link"
        $item.output = (Invoke-CheckedCleanupProcess "$prefix.audit.exe" @() "$($case.name) allocation execute").Replace("`r`n","`n").TrimEnd()
        $expected = (Get-Content -LiteralPath $case.expected -Raw).Replace("`r`n","`n").TrimEnd()
        if ($item.output -cne "$expected`nallocations=$($case.allocations),releases=$($case.allocations)") { throw 'Exact output or allocation/release mismatch' }
        $item.passed = $true
    } catch { $item.error = $_.Exception.Message }
    [pscustomobject]$item
}
if ((Get-FileHash -LiteralPath $compiler).Hash -ne $compilerHash) { throw 'Managed compiler changed during cleanup verification' }
$report = [ordered]@{compiler=$compiler;compilerSha256=$compilerHash;shimSha256=(Get-FileHash $shim).Hash;passed=@($results|Where-Object passed).Count;total=$cases.Count;cases=@($results)}
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $output 'results.json') -Encoding utf8
if ($report.passed -ne $report.total) { throw "Managed owned call cleanup $($report.passed)/$($report.total): $($results|ConvertTo-Json -Depth 4 -Compress)" }
Write-Host "[managed owned call cleanup] PASS $($report.passed)/$($report.total) exact allocation/release counts."
