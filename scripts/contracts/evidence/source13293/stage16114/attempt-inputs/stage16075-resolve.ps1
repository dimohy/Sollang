. scripts/source-module-header.ps1
$taskBase = Join-Path (Get-Location) 'artifacts/scratch/resume-20261006-owner-continuation22'
$taskManifest = 'tests/Sollang.ExampleTests/Fixtures/selfhost-compiler-runtime.sources.txt'
$taskOriginal = [IO.File]::ReadAllBytes($taskManifest)
[IO.File]::WriteAllBytes((Join-Path $taskBase 'stage16075-runtime-before.txt'), $taskOriginal)
$taskPaths = [Collections.Generic.List[string]]::new()
$taskPaths.AddRange([string[]]([IO.File]::ReadAllLines('tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt')))
$taskPaths.AddRange([string[]]([IO.File]::ReadAllLines($taskManifest)))
$taskModules = @{}
foreach ($taskPath in $taskPaths) {
    $taskHeader = Get-SollangModuleHeader -Source ([IO.File]::ReadAllText($taskPath))
    if ($taskHeader.Namespace.Length -gt 0) { $taskModules[$taskHeader.Namespace] = $taskPath }
}
$taskStdModules = @{}
foreach ($taskFile in Get-ChildItem stdlib -Recurse -Filter *.slg) {
    $taskHeader = Get-SollangModuleHeader -Source ([IO.File]::ReadAllText($taskFile.FullName))
    if ($taskHeader.Namespace.Length -gt 0) {
        if (-not $taskStdModules.ContainsKey($taskHeader.Namespace)) { $taskStdModules[$taskHeader.Namespace] = @() }
        $taskStdModules[$taskHeader.Namespace] += [IO.Path]::GetRelativePath((Get-Location).Path,$taskFile.FullName).Replace('\','/')
    }
}
$taskAdded = [Collections.Generic.List[string]]::new()
for ($taskIndex=0; $taskIndex -lt $taskPaths.Count; $taskIndex++) {
    $taskHeader = Get-SollangModuleHeader -Source ([IO.File]::ReadAllText($taskPaths[$taskIndex]))
    foreach ($taskImport in $taskHeader.Imports) {
        if ($taskModules.ContainsKey($taskImport)) { continue }
        if (-not $taskStdModules.ContainsKey($taskImport)) { throw "unresolved import: $taskImport" }
        $taskModules[$taskImport] = $taskStdModules[$taskImport]
        foreach ($taskPath in $taskStdModules[$taskImport]) {
            $taskAdded.Add($taskPath)
            $taskPaths.Add($taskPath)
        }
    }
}
$taskRecord = @{schemaVersion=1;status='resolved-not-executed';runtimeManifest=$taskManifest;addedEntries=@($taskAdded);originalEntryCount=[IO.File]::ReadAllLines($taskManifest).Length;finalEntryCount=([IO.File]::ReadAllLines($taskManifest).Length+$taskAdded.Count);fileAbiProjectionPreserved=($taskModules['sys.file'] -eq 'selfhost/runtime/file.slg');claimsStagePassed=$false}
$taskRecord | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $taskBase 'stage16075-runtime-closure-plan.json') -Encoding utf8
$taskRecord | ConvertTo-Json -Depth 5
