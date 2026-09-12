[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = [System.IO.Path]::GetFullPath($RepositoryRoot)
$guidePath = Join-Path $root "docs\AI_AGENT_GUIDE.md"
$practicePath = Join-Path $root "docs\AI_SLG_BEST_PRACTICES.md"
$readmePath = Join-Path $root "README.md"
$llmsPath = Join-Path $root "llms.txt"
$contractPath = Join-Path $root "scripts\contracts\ai-slg-best-practices.json"
$schemaPath = Join-Path $root "scripts\contracts\ai-slg-best-practices.schema.json"
$fixturePath = Join-Path $root "examples\regression\1218-ai-slg-best-practices.slg"
$expectedPath = Join-Path $root "examples\regression\expected\1218-ai-slg-best-practices.stdout.txt"
$grammarPath = Join-Path $root "syntax\sollang.grammar"
foreach ($path in @($guidePath, $practicePath, $readmePath, $llmsPath, $contractPath, $schemaPath, $fixturePath, $expectedPath, $grammarPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "AI SLG best-practices evidence is missing: $path"
    }
}

$contractText = [System.IO.File]::ReadAllText($contractPath)
if (-not (Test-Json -Json $contractText -SchemaFile $schemaPath)) {
    throw "AI SLG best-practices feature coverage contract does not satisfy its schema"
}
$contract = $contractText | ConvertFrom-Json
if ([string]$contract.document -cne "docs/AI_SLG_BEST_PRACTICES.md") {
    throw "The syntax/style contract must name the single AI guide"
}
if ([string]$contract.grammar -cne "syntax/sollang.grammar") {
    throw "AI SLG best-practices contract must derive its inventory from syntax/sollang.grammar"
}
$grammar = [System.IO.File]::ReadAllText($grammarPath)
$grammarRules = [System.Text.RegularExpressions.Regex]::Matches(
    $grammar,
    "(?m)^rule ([A-Za-z0-9_]+) ="
) | ForEach-Object { $_.Groups[1].Value }
$contractRules = @($contract.grammarRuleInventory | ForEach-Object { [string]$_ })
if (($grammarRules -join "`n") -cne ($contractRules -join "`n")) {
    $missing = @($grammarRules | Where-Object { $_ -cnotin $contractRules })
    $stale = @($contractRules | Where-Object { $_ -cnotin $grammarRules })
    throw "AI SLG grammar inventory drifted. Missing: $($missing -join ', '); stale: $($stale -join ', '). Review every grammar rule before changing the contract."
}

$guide = [System.IO.File]::ReadAllText($guidePath)
if (-not $guide.Contains('(AI_SLG_BEST_PRACTICES.md)', [System.StringComparison]::Ordinal)) {
    throw "AI Agent guide no longer routes Agents through AI_SLG_BEST_PRACTICES.md"
}
if ([System.Text.Encoding]::UTF8.GetByteCount($guide) -gt 1024) {
    throw "AI_AGENT_GUIDE.md must remain a short compatibility pointer, not a second guide"
}
if (-not [System.IO.File]::ReadAllText($readmePath).Contains('[SLG best practices for AI Agents](docs/AI_SLG_BEST_PRACTICES.md)', [System.StringComparison]::Ordinal)) {
    throw "README AI discovery order no longer includes AI_SLG_BEST_PRACTICES.md"
}
if (-not [System.IO.File]::ReadAllText($llmsPath).Contains('[docs/AI_SLG_BEST_PRACTICES.md](docs/AI_SLG_BEST_PRACTICES.md)', [System.StringComparison]::Ordinal)) {
    throw "llms.txt discovery order no longer includes AI_SLG_BEST_PRACTICES.md"
}

$practice = [System.IO.File]::ReadAllText($practicePath)
if ($practice.Contains('after reading the Agent guide', [System.StringComparison]::Ordinal) -or
    $practice.Contains('Read `docs/AI_AGENT_GUIDE.md`', [System.StringComparison]::Ordinal)) {
    throw "The single AI guide must not require reading a second AI guide"
}
foreach ($entry in @('AGENTS.md', 'CLAUDE.md', '.github/copilot-instructions.md')) {
    $entryText = [System.IO.File]::ReadAllText((Join-Path $root $entry))
    if (-not $entryText.Contains('docs/AI_SLG_BEST_PRACTICES.md', [System.StringComparison]::Ordinal)) {
        throw "$entry must point to the single AI guide"
    }
}
foreach ($required in @(
    "## 1. Design model to internalize first",
    "## 3. Organize modules, visibility, and foreign boundaries",
    "## 4. Model data with struct, enum, products, Option, and Result",
    "## 5. Build abstractions with functions, generics, traits, impl, and blocks",
    "## 8. Make ownership visible and zero-copy by default",
    "## 9. Put behavior on instances",
    "## 11. Express control flow in SLG rhythm",
    "## 14. Use flow junctions instead of temporary plumbing",
    "## 15. Build lazy Stream and bounded EventStream pipelines",
    "## 16. Use structured async, await, yield, and cancellation",
    "## 17. Design stdlib surfaces as contracts",
    "## 19. Focused verification ladder",
    "## 20. AI pre-edit and pre-completion checklists",
    "## 22. Feature coverage map",
    "Reading and applying this document is mandatory",
    "Beautiful SLG is not ornamental formatting",
    "N001 reports",
    "N002 reports",
    "scripts/format-authoritative-slg.ps1 -Check",
    "Do not repeatedly run the full compiler gate"
)) {
    if (-not $practice.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "AI SLG best-practices contract is missing: $required"
    }
}

$familyIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($family in $contract.featureFamilies) {
    if (-not $familyIds.Add([string]$family.id)) {
        throw "AI SLG best-practices feature family is duplicated: $($family.id)"
    }
    foreach ($term in $family.requiredTerms) {
        if (-not $practice.Contains([string]$term, [System.StringComparison]::Ordinal)) {
            throw "AI SLG best-practices family $($family.id) is missing documented term: $term"
        }
    }
    foreach ($example in $family.examples) {
        $examplePath = Join-Path $root ([string]$example).Replace('/', '\')
        if (-not (Test-Path -LiteralPath $examplePath -PathType Leaf)) {
            throw "AI SLG best-practices family $($family.id) is missing example: $example"
        }
    }
}

$fixture = [System.IO.File]::ReadAllText($fixturePath)
foreach ($required in @(
    "enum Priority",
    "trait Magnitude",
    "impl Magnitude for Counter",
    "readMagnitude<T>",
    "where T: Magnitude",
    "public next: mut self",
    "22 => values![1]",
    "value > 0 -> unless",
    "positive? => sum",
    "score -> when",
    "-> branch {",
    "-> parallel branch {",
    "-> map item",
    "-> take(3)",
    "task -> await"
)) {
    if (-not $fixture.Contains($required, [System.StringComparison]::Ordinal)) {
        throw "AI SLG best-practices fixture no longer proves: $required"
    }
}

if ([System.IO.File]::ReadAllText($expectedPath).Trim() -cne "best-practice=222") {
    throw "AI SLG best-practices fixture output contract changed"
}

Write-Host "[AI SLG best practices] PASS $($contract.featureFamilies.Count) feature families, $($grammarRules.Count) grammar rules, mandatory guide routing, checklist, and executable fixture contract."
