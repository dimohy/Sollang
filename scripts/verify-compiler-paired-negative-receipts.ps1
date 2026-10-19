[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PlanPath,
    [Parameter(Mandatory)][string]$OutputFile
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$scratch = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/scratch'))
function RepoFile([string]$path) {
    $full = [IO.Path]::GetFullPath($path, $root)
    if (-not $full.StartsWith($root + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "Paired negative input is missing or outside the repository: $path"
    }
    $full
}
function Sha([string]$path) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }

$output = [IO.Path]::GetFullPath($OutputFile, $root)
if (-not $output.StartsWith($scratch + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase) -or
    (Test-Path -LiteralPath $output) -or
    -not (Test-Path -LiteralPath (Split-Path -Parent $output) -PathType Container)) {
    throw "Paired negative result must be a new file under an existing scratch directory: $output"
}
$planFile = RepoFile $PlanPath
$plan = [IO.File]::ReadAllText($planFile) | ConvertFrom-Json
if ($plan.schemaVersion -ne 1 -or @($plan.cases).Count -eq 0) {
    throw 'Paired negative plan must contain at least one case'
}
$managed = RepoFile $plan.managedCompiler
$selfhost = RepoFile $plan.selfhostCompiler
if ((Sha $managed) -cne $plan.managedSha256 -or (Sha $selfhost) -cne $plan.selfhostSha256) {
    throw 'Paired negative compiler identity differs from the plan'
}
$inputs = [ordered]@{ plan=$planFile; verifier=$PSCommandPath; managed=$managed; selfhost=$selfhost }
$names = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$cases = @(
    foreach ($case in $plan.cases) {
        if ($case.id -cnotmatch '^[a-z0-9][a-z0-9-]*$' -or -not $names.Add($case.id)) {
            throw "Invalid or duplicate paired negative case: $($case.id)"
        }
        $source = RepoFile $case.source
        $expected = RepoFile $case.expected
        $receipt = RepoFile $case.receipt
        $inputs["source:$($case.id)"] = $source
        $inputs["expected:$($case.id)"] = $expected
        $inputs["receipt:$($case.id)"] = $receipt
        [pscustomobject]@{ Name=$case.id; Source=$source; Expected=$expected; Receipt=$receipt }
    }
)
$start = [ordered]@{}
foreach ($entry in $inputs.GetEnumerator()) { $start[$entry.Key] = Sha $entry.Value }
$rows = [Collections.Generic.List[object]]::new()
foreach ($case in $cases) {
    $receipt = [IO.File]::ReadAllText($case.Receipt) | ConvertFrom-Json
    $valid = $receipt.schemaVersion -eq 1 -and $receipt.state -ceq 'passed' -and
        $receipt.inputsStable -eq $true -and
        $receipt.source -ceq $case.Source -and $receipt.expected -ceq $case.Expected -and
        $receipt.sourceSha256 -ceq (Sha $case.Source) -and
        $receipt.expectedSha256 -ceq (Sha $case.Expected) -and
        $receipt.managedCompilerSha256 -ceq $plan.managedSha256 -and
        $receipt.selfhostCompilerSha256 -ceq $plan.selfhostSha256 -and
        $receipt.managed.exitCode -eq 1 -and $receipt.selfhost.exitCode -eq 1 -and
        $receipt.managed.expectedInStderr -eq $true -and
        $receipt.selfhost.expectedInStderr -eq $true -and
        $receipt.managed.noEmittedProducts -eq $true -and
        $receipt.selfhost.noEmittedProducts -eq $true
    $rows.Add([ordered]@{ id=$case.Name; passed=$valid;
        receiptSha256=$start["receipt:$($case.Name)"] })
}
$end = [ordered]@{}
foreach ($entry in $inputs.GetEnumerator()) { $end[$entry.Key] = Sha $entry.Value }
$drift = @($start.Keys | Where-Object { $start[$_] -cne $end[$_] })
$passed = @($rows.ToArray() | Where-Object { $_.passed }).Count
$record = [ordered]@{
    schemaVersion=1
    status=if ($passed -eq $cases.Count -and $drift.Count -eq 0) { 'passed' } else { 'failed' }
    scope=$plan.scope
    passed=$passed
    total=$cases.Count
    inputStable=($drift.Count -eq 0)
    inputHashesStart=$start
    inputHashesEnd=$end
    inputDrift=@($drift)
    cases=@($rows.ToArray())
}
[IO.File]::WriteAllText($output, ($record | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
if ($record.status -cne 'passed') { throw "Paired negative receipt aggregate failed: $output" }
Write-Host "[compiler paired negatives] PASS $passed/$($cases.Count); result=$output"
