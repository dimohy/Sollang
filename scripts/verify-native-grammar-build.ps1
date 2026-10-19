[CmdletBinding()]
param(
    [string]$ManagedCompiler = "",
    [string]$NativeCompiler = "",
    [string]$OutputDirectory = "",
    [ValidateSet("windows-x64", "linux-x64")]
    [string]$Target = "windows-x64",
    [string]$Distribution = "Ubuntu"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "ArtifactLifecycle.ps1")
. (Join-Path $PSScriptRoot "verification-process.ps1")
if ([string]::IsNullOrWhiteSpace($ManagedCompiler)) {
    $ManagedCompiler = Join-Path $repoRoot "src\Sollang.Compiler\bin\Release\net11.0\Sollang.Compiler.dll"
}
if ([string]::IsNullOrWhiteSpace($NativeCompiler)) {
    $NativeCompiler = Join-Path $repoRoot "artifacts\example-tests\selfhost-sollangc-driver.exe"
}
$ManagedCompiler = (Resolve-Path -LiteralPath $ManagedCompiler).Path
$NativeCompiler = (Resolve-Path -LiteralPath $NativeCompiler).Path
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot ("artifacts\scratch\native-grammar-build-" + [Guid]::NewGuid().ToString("N"))
}
$artifacts = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $artifacts) {
    throw "GRAMMAR_OUTPUT_ALREADY_EXISTS: $artifacts"
}
Initialize-ArtifactOutput -OutputDirectory $artifacts
$casesRoot = Join-Path $artifacts "cases"
New-Item -ItemType Directory -Path $casesRoot -Force | Out-Null
$utf8 = [Text.UTF8Encoding]::new($false)
$normalizationContractPath = Join-Path $PSScriptRoot "contracts\grammar-source-normalization.json"
$normalizationContract = Get-Content -LiteralPath $normalizationContractPath -Raw | ConvertFrom-Json
$completedCases = [Collections.Generic.List[object]]::new()
$executionRecords = [Collections.Generic.List[string]]::new()
$inputPaths = @($ManagedCompiler, $NativeCompiler, $PSCommandPath,
    (Join-Path $PSScriptRoot "verification-process.ps1"), $normalizationContractPath,
    (Join-Path $PSScriptRoot "ArtifactLifecycle.ps1"),
    (Join-Path $PSScriptRoot "completed_artifact_plan.py"),
    (Join-Path $PSScriptRoot "Invoke-CompletedArtifactCleanup.ps1"),
    (Join-Path $PSScriptRoot "contracts\artifact-lifecycle.json"),
    (Join-Path $repoRoot "syntax\sollang.lexer"), (Join-Path $repoRoot "syntax\sollang.grammar"),
    (Join-Path $repoRoot "src\Sollang.Compiler\Cli\GrammarCompiler.cs"),
    (Join-Path $repoRoot "selfhost\cli_grammar.slg"),
    (Join-Path $repoRoot "selfhost\syntax\source_decoding.slg")) +
    @(Get-ChildItem (Join-Path $repoRoot "src\Sollang.Compiler.Generators") -Recurse -File -Filter '*.cs' |
        Where-Object FullName -NotMatch '[\\/]obj[\\/]|[\\/]bin[\\/]' | ForEach-Object FullName) +
    @(Get-ChildItem (Split-Path -Parent $ManagedCompiler) -File |
        Where-Object Extension -In '.dll', '.json' | ForEach-Object FullName)
function Get-GrammarInputHashes {
    Get-GrammarPathHashes $inputPaths
}
function Get-GrammarPathHashes([string[]]$Paths) {
    $hashes = [ordered]@{}
    foreach ($path in $Paths) {
        $hashes[[IO.Path]::GetFullPath($path)] = if (Test-Path -LiteralPath $path -PathType Leaf) {
            (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        } else { 'missing' }
    }
    $hashes
}
function Assert-GrammarCaseInputs($Start, $End) {
    if (($Start | ConvertTo-Json -Compress) -cne ($End | ConvertTo-Json -Compress)) {
        throw 'GRAMMAR_CASE_INPUT_DRIFT'
    }
}
$inputHashesStart = Get-GrammarInputHashes
$verificationPassed = $false
$verificationFailure = $null

function Convert-ToWslPath {
    param([Parameter(Mandatory)] [string]$Path)

    $absolute = [IO.Path]::GetFullPath($Path)
    $drive = $absolute.Substring(0, 1).ToLowerInvariant()
    $tail = $absolute.Substring(3).Replace('\', '/')
    "/mnt/$drive/$tail"
}

function Convert-NativeArgument {
    param([string]$Argument)

    if ($Target -eq "linux-x64" -and $Argument -match '^[A-Za-z]:[\\/]') {
        return Convert-ToWslPath $Argument
    }
    $Argument
}

function Invoke-Compiler {
    param(
        [bool]$Native,
        [string[]]$Arguments
    )

    $start = [Diagnostics.ProcessStartInfo]::new()
    if ($Native) {
        if ($Target -eq "linux-x64") {
            $start.FileName = "wsl.exe"
            $start.ArgumentList.Add("-d")
            $start.ArgumentList.Add($Distribution)
            $start.ArgumentList.Add("--")
            $start.ArgumentList.Add((Convert-ToWslPath $NativeCompiler))
        }
        else {
            $start.FileName = $NativeCompiler
        }
    }
    else {
        $start.FileName = "dotnet"
        $start.ArgumentList.Add($ManagedCompiler)
    }
    foreach ($argument in $Arguments) {
        $start.ArgumentList.Add($(if ($Native) { Convert-NativeArgument $argument } else { $argument }))
    }
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $executionPath = Join-Path $artifacts ("process-{0:D3}.json" -f ($executionRecords.Count + 1))
    $executionRecords.Add($executionPath)
    $capture = Invoke-VerificationProcessCapture -FilePath $start.FileName `
        -ArgumentList @($start.ArgumentList) -Description "Grammar command parity" `
        -WorkingDirectory $repoRoot -TimeoutMilliseconds 120000 -ExecutionRecordPath $executionPath
    [pscustomobject]@{
        ExitCode = $capture.ExitCode
        Stdout = $capture.Stdout.Replace("`r`n", "`n").Replace("`r", "`n")
        Stderr = $capture.Stderr.Replace("`r`n", "`n").Replace("`r", "`n")
        ExecutionRecord = $executionPath
    }
}

function Assert-EquivalentFailure {
    param(
        [string]$Name,
        [string[]]$Arguments
    )

    $caseInputs = if ($Arguments.Count -ge 4) { @($Arguments[2], $Arguments[3]) } else { @() }
    $caseHashesStart = Get-GrammarPathHashes $caseInputs
    $managed = Invoke-Compiler $false $Arguments
    $native = Invoke-Compiler $true $Arguments
    $caseHashesEnd = Get-GrammarPathHashes $caseInputs
    Assert-GrammarCaseInputs $caseHashesStart $caseHashesEnd
    if ($managed.ExitCode -ne 1 -or $native.ExitCode -ne 1) {
        throw "$Name exit mismatch: managed=$($managed.ExitCode), native=$($native.ExitCode)"
    }
    $managedStdout = $managed.Stdout
    $managedStderr = $managed.Stderr
    $nativeStdout = $native.Stdout
    $nativeStderr = $native.Stderr
    for ($argumentIndex = 0; $argumentIndex -lt $Arguments.Count; $argumentIndex++) {
        $argument = $Arguments[$argumentIndex]
        if ([IO.Path]::IsPathFullyQualified($argument)) {
            $managedPath = [IO.Path]::GetFullPath($argument)
            $nativePath = if ($Target -eq "linux-x64") { Convert-ToWslPath $argument } else { $managedPath }
            $marker = "<path-$argumentIndex>"
            $managedStdout = $managedStdout.Replace($managedPath, $marker)
            $managedStderr = $managedStderr.Replace($managedPath, $marker)
            $nativeStdout = $nativeStdout.Replace($nativePath, $marker)
            $nativeStderr = $nativeStderr.Replace($nativePath, $marker)
        }
    }
    if ($managedStdout -ne $nativeStdout -or $managedStderr -ne $nativeStderr) {
        throw "$Name output mismatch.`nmanaged stdout: $($managed.Stdout)`nnative stdout: $($native.Stdout)`nmanaged stderr: $($managed.Stderr)`nnative stderr: $($native.Stderr)"
    }
    $completedCases.Add([ordered]@{id=$Name; kind='diagnostic'; status='passed';
        inputHashesStart=$caseHashesStart; inputHashesEnd=$caseHashesEnd;
        managedExecution=$managed.ExecutionRecord; selfhostExecution=$native.ExecutionRecord})
}

function Assert-EquivalentBuild {
    param(
        [string]$Name,
        [string]$Lexer,
        [string]$Grammar,
        [string]$ExpectedSourceHash = ""
    )

    $managedOutput = Join-Path $artifacts "$Name-managed\deep\generated.slg"
    $nativeOutput = Join-Path $artifacts "$Name-native\deep\generated.slg"
    $caseHashesStart = Get-GrammarPathHashes @($Lexer, $Grammar)
    $managed = Invoke-Compiler $false @("grammar", "build", $Lexer, $Grammar, "-o", $managedOutput)
    $native = Invoke-Compiler $true @("grammar", "build", $Lexer, $Grammar, "-o", $nativeOutput)
    $caseHashesEnd = Get-GrammarPathHashes @($Lexer, $Grammar)
    Assert-GrammarCaseInputs $caseHashesStart $caseHashesEnd
    if ($managed.ExitCode -ne 0 -or $native.ExitCode -ne 0) {
        throw "$Name build failed.`nmanaged: exit=$($managed.ExitCode) stdout=$($managed.Stdout) stderr=$($managed.Stderr)`nnative: exit=$($native.ExitCode) stdout=$($native.Stdout) stderr=$($native.Stderr)"
    }
    $managedNormalized = $managed.Stdout.Replace([IO.Path]::GetFullPath($managedOutput), "<output>")
    $nativeOutputText = if ($Target -eq "linux-x64") {
        Convert-ToWslPath $nativeOutput
    }
    else {
        [IO.Path]::GetFullPath($nativeOutput)
    }
    $nativeNormalized = $native.Stdout.Replace($nativeOutputText, "<output>")
    if ($managedNormalized -ne $nativeNormalized -or $managed.Stderr -ne "" -or $native.Stderr -ne "") {
        throw "$Name success output mismatch.`nmanaged: $($managed.Stdout)`nnative: $($native.Stdout)"
    }
    $managedBytes = [IO.File]::ReadAllBytes($managedOutput)
    $nativeBytes = [IO.File]::ReadAllBytes($nativeOutput)
    if (-not [Linq.Enumerable]::SequenceEqual[byte]($managedBytes, $nativeBytes)) {
        throw "$Name generated module differs: managed=$((Get-FileHash $managedOutput -Algorithm SHA256).Hash), native=$((Get-FileHash $nativeOutput -Algorithm SHA256).Hash)"
    }
    if ($ExpectedSourceHash -ne "") {
        $generated = [IO.File]::ReadAllText($managedOutput)
        if (-not $generated.Contains("# Source SHA-256: $($ExpectedSourceHash.ToLowerInvariant())", [StringComparison]::OrdinalIgnoreCase) -or
            -not $generated.Contains("public parserProgram: -> [Int; ~] => [1, 0, 1, 1, 0; ~]", [StringComparison]::Ordinal)) {
            throw "$Name independent source hash or parser program oracle mismatch"
        }
    }
    $completedCases.Add([ordered]@{id=$Name; kind='generated-module'; status='passed';
        inputHashesStart=$caseHashesStart; inputHashesEnd=$caseHashesEnd;
        managedExecution=$managed.ExecutionRecord; selfhostExecution=$native.ExecutionRecord;
        generatedSha256=(Get-FileHash -LiteralPath $managedOutput -Algorithm SHA256).Hash})
}

$invalidCases = @(
    @{ Name = "lexer-no-token"; Lexer = "skip Space = whitespace`n"; Grammar = "parser X`nstart Root`nrule Root = Identifier`n" },
    @{ Name = "lexer-pattern"; Lexer = "token Identifier = mystery`n"; Grammar = "parser X`nstart Root`nrule Root = Identifier`n" },
    @{ Name = "lexer-duplicate"; Lexer = "token Identifier = identifier`ntoken Identifier = identifier`n"; Grammar = "parser X`nstart Root`nrule Root = Identifier`n" },
    @{ Name = "grammar-missing-start"; Lexer = "token Identifier = identifier`n"; Grammar = "parser X`nrule Root = Identifier`n" },
    @{ Name = "grammar-unknown-start"; Lexer = "token Identifier = identifier`n"; Grammar = "parser X`nstart Missing`nrule Root = Identifier`n" },
    @{ Name = "grammar-unknown-symbol"; Lexer = "token Identifier = identifier`n"; Grammar = "parser X`nstart Root`nrule Root = Missing`n" },
    @{ Name = "grammar-empty-choice"; Lexer = "token Identifier = identifier`n"; Grammar = "parser X`nstart Root`nrule Root = Identifier |`n" },
    @{ Name = "grammar-unclosed-group"; Lexer = "token Identifier = identifier`n"; Grammar = "parser X`nstart Root`nrule Root = (Identifier`n" },
    @{ Name = "grammar-lookahead-missing-close-unknown-token"; Lexer = "token End = end`n"; Grammar = "parser X`nstart Root`nrule Root = lookahead(Missing`n" },
    @{ Name = "grammar-keyword-missing-close-unknown-token"; Lexer = "token End = end`n"; Grammar = "parser X`nstart Root`nrule Root = Identifier(`"if`"`n" },
    @{ Name = "grammar-unknown-token"; Lexer = "token Identifier = identifier`n"; Grammar = "parser X`nstart Root`nrule Root = lookahead(Missing)`n" },
    @{ Name = "grammar-predicate"; Lexer = "token Identifier = identifier`n"; Grammar = "parser X`nstart Root`nrule Root = mystery(Identifier)`n" }
)
try {
$canonicalLexer = Join-Path $repoRoot "syntax\sollang.lexer"
$canonicalGrammar = Join-Path $repoRoot "syntax\sollang.grammar"
Assert-EquivalentBuild "canonical" $canonicalLexer $canonicalGrammar
Write-Output "[1/4] PASS canonical generated-module byte parity"

$completeLexer = Join-Path $casesRoot "complete.lexer"
$completeGrammar = Join-Path $casesRoot "complete.grammar"
[IO.File]::WriteAllText($completeLexer, @"
skip Space = whitespace
skip Comment = line_comment
token Identifier = identifier
token String = quoted_string
token Number = number
token Newline = newline
token End = end
token Plus = "+"
token AlsoPlus = "+"
"@.TrimStart(), $utf8)
[IO.File]::WriteAllText($completeGrammar, @"
parser Complete
start Root
rule Root = Header? (Identifier("if") | Name)+ Tail* lookahead(End) notKeyword("else")
rule Header = Newline
rule Name = Identifier
rule Tail = Number
"@.TrimStart(), $utf8)
Assert-EquivalentBuild "complete" $completeLexer $completeGrammar
Write-Output "[2/4] PASS sequence, choice, grouping, predicates, and quantifier parity"

Assert-EquivalentFailure "usage" @("grammar", "build")
$missingLexer = Join-Path $casesRoot "missing.lexer"
$missingGrammar = Join-Path $casesRoot "missing.grammar"
Assert-EquivalentFailure "missing lexer" @("grammar", "build", $missingLexer, $missingGrammar, "-o", (Join-Path $artifacts "missing.slg"))
Assert-EquivalentFailure "missing grammar" @("grammar", "build", $canonicalLexer, $missingGrammar, "-o", (Join-Path $artifacts "missing.slg"))
Write-Output "[3/4] PASS usage and missing-input diagnostic parity"

foreach ($case in $invalidCases) {
    $lexer = Join-Path $casesRoot "$($case.Name).lexer"
    $grammar = Join-Path $casesRoot "$($case.Name).grammar"
    [IO.File]::WriteAllText($lexer, $case.Lexer, $utf8)
    [IO.File]::WriteAllText($grammar, $case.Grammar, $utf8)
    Assert-EquivalentFailure $case.Name @("grammar", "build", $lexer, $grammar, "-o", (Join-Path $artifacts "$($case.Name).slg"))
}
Write-Output "[4/4] PASS lexer and production diagnostic parity"
foreach ($case in $normalizationContract.cases) {
    $lexer = Join-Path $casesRoot "$($case.id).lexer"
    $grammar = Join-Path $casesRoot "$($case.id).grammar"
    $encoding = [Text.UTF8Encoding]::new([bool]$case.utf8Bom)
    [IO.File]::WriteAllText($lexer, $case.lexer, $encoding)
    [IO.File]::WriteAllText($grammar, $case.grammar, $encoding)
    Assert-EquivalentBuild $case.id $lexer $grammar $case.expectedSourceHash
}
Write-Output "PASS source normalization and BOM parity ($($normalizationContract.cases.Count)/$($normalizationContract.cases.Count))"
$verificationPassed = $true
} catch {
    $verificationFailure = $_.Exception.Message
    throw
} finally {
    $inputHashesEnd = Get-GrammarInputHashes
    $inputsStable = ($inputHashesStart | ConvertTo-Json -Compress) -ceq ($inputHashesEnd | ConvertTo-Json -Compress)
    $processes = @($executionRecords | ForEach-Object { Get-Content -LiteralPath $_ -Raw | ConvertFrom-Json })
    $processesStopped = @($processes | Where-Object { $_.processesStopped -ne $true }).Count -eq 0
    $total = 2 + 3 + $invalidCases.Count + $normalizationContract.cases.Count
    $passed = $verificationPassed -and $inputsStable -and $processesStopped -and $completedCases.Count -eq $total
    $failureIds = @(
        if ($verificationFailure) { 'GRAMMAR_COMMAND_COMPARISON_FAILED' }
        if (-not $inputsStable) { 'GRAMMAR_INPUT_DRIFT' }
        if (-not $processesStopped) { 'GRAMMAR_PROCESS_SHUTDOWN_MISSING' }
        if ($verificationPassed -and $completedCases.Count -ne $total) { 'GRAMMAR_CASE_COUNT_MISMATCH' }
    )
    $result = [ordered]@{schemaVersion=1; status=$(if ($passed) {'passed'} else {'failed'});
        target=$Target; managedCompiler=$ManagedCompiler; selfhostCompiler=$NativeCompiler;
        scope='Grammar command generated bytes, diagnostics, normalization and BOM; not whole parsing phase';
        completed=$completedCases.Count; total=$total; cases=@($completedCases.ToArray());
        inputStable=$inputsStable; inputHashesStart=$inputHashesStart; inputHashesEnd=$inputHashesEnd;
        processesStopped=$processesStopped; processes=$processes; failure=$verificationFailure; failureIds=$failureIds;
        claimsPhaseComplete=$false; claimsGoalComplete=$false}
    [IO.File]::WriteAllText((Join-Path $artifacts 'result.json'), ($result | ConvertTo-Json -Depth 20), $utf8)
    if ($verificationPassed -and -not $passed) { throw 'GRAMMAR_VERIFICATION_COMPLETION_INVALID' }
    if ($passed) {
        try {
            Complete-VerifiedArtifactOutput -OutputDirectory $artifacts
        } catch {
            $result.status = 'failed'
            $result.failure = $_.Exception.Message
            $result.failureIds = @('GRAMMAR_ARTIFACT_CLEANUP_FAILED')
            [IO.File]::WriteAllText((Join-Path $artifacts 'result.json'), ($result | ConvertTo-Json -Depth 20), $utf8)
            throw
        }
        Write-Output "Native grammar build verification passed ($($completedCases.Count)/$total)."
    }
}
