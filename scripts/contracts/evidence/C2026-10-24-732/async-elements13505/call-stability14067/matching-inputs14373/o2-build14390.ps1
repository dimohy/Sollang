$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$taskPlan = Get-Content -LiteralPath 'scripts/contracts/evidence/C2026-10-24-732/async-elements13505/call-stability14067/matching-inputs14373/native-plan14389.json' -Raw | ConvertFrom-Json -AsHashtable
$taskParameters = $taskPlan.parameters
& 'scripts/build-focused-selfhost-compiler.ps1' @taskParameters
