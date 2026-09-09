[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Baseline,
    [Parameter(Mandatory)][string]$Candidate,
    [string]$Output = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Resolve-InputFile {
    param([string]$Path, [string]$Label)

    $resolved = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf) -or
        (Get-Item -LiteralPath $resolved).Length -eq 0) {
        throw "$Label LLVM input is missing or empty: $resolved"
    }
    $resolved
}

function Get-FunctionHashes {
    param([string]$Path)

    $functions = [System.Collections.Generic.Dictionary[string, string]]::new(
        [System.StringComparer]::Ordinal)
    $lines = [System.IO.File]::ReadAllLines($Path)
    $name = $null
    $body = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $lines) {
        if ($null -eq $name) {
            if ($line -match '^define\s+.*?@(?<name>[-A-Za-z$._0-9]+)\(') {
                $name = $Matches.name
                $body.Clear()
                $body.Add($line)
            }
            continue
        }

        $body.Add($line)
        if ($line -cne '}') { continue }

        $text = [string]::Join("`n", $body)
        $hash = [Convert]::ToHexString(
            [System.Security.Cryptography.SHA256]::HashData(
                [System.Text.Encoding]::UTF8.GetBytes($text)))
        if (-not $functions.TryAdd($name, $hash)) {
            throw "duplicate LLVM function definition '$name' in $Path"
        }
        $name = $null
    }

    if ($null -ne $name) {
        throw "unterminated LLVM function definition '$name' in $Path"
    }
    $functions
}

$baselinePath = Resolve-InputFile $Baseline "baseline"
$candidatePath = Resolve-InputFile $Candidate "candidate"
$baselineHash = (Get-FileHash -LiteralPath $baselinePath -Algorithm SHA256).Hash
$candidateHash = (Get-FileHash -LiteralPath $candidatePath -Algorithm SHA256).Hash
$baselineFunctions = Get-FunctionHashes $baselinePath
$candidateFunctions = Get-FunctionHashes $candidatePath

$added = @($candidateFunctions.Keys |
    Where-Object { -not $baselineFunctions.ContainsKey($_) } |
    Sort-Object)
$removed = @($baselineFunctions.Keys |
    Where-Object { -not $candidateFunctions.ContainsKey($_) } |
    Sort-Object)
$changed = @($baselineFunctions.Keys |
    Where-Object {
        $candidateFunctions.ContainsKey($_) -and
        $baselineFunctions[$_] -cne $candidateFunctions[$_]
    } |
    Sort-Object)

$record = [ordered]@{
    schemaVersion = 1
    measurement = "llvm-function-body-sha256"
    baseline = [ordered]@{
        path = $baselinePath
        sha256 = $baselineHash
        functionCount = $baselineFunctions.Count
    }
    candidate = [ordered]@{
        path = $candidatePath
        sha256 = $candidateHash
        functionCount = $candidateFunctions.Count
    }
    added = $added
    removed = $removed
    changed = $changed
}
$json = ($record | ConvertTo-Json -Depth 6) + "`n"

if (-not [string]::IsNullOrWhiteSpace($Output)) {
    $outputPath = [System.IO.Path]::GetFullPath($Output)
    $outputDirectory = [System.IO.Path]::GetDirectoryName($outputPath)
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
        [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
    }
    $temporary = $outputPath + ".tmp"
    [System.IO.File]::WriteAllText($temporary, $json, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::Move($temporary, $outputPath, $true)
}

$json
