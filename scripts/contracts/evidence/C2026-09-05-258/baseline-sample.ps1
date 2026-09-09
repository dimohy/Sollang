# Minimal frozen reproduction of the pre-fix profiler CPU-property access.
# The live Windows run also failed at this access and left its batch running.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$observed = [pscustomobject]@{ WorkingSet64 = 42L; TotalProcessorTime = $null }
$cpuMilliseconds = [long]$observed.TotalProcessorTime.TotalMilliseconds
