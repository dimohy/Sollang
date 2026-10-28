[CmdletBinding()]
param(
    [string]$Compiler,
    [ValidateSet("windows-x64", "linux-x64")]
    [string]$Target = "windows-x64",
    [string]$Distribution = "Ubuntu",
    [string]$OutputDirectory = '',
    [string[]]$ReusableCompilerDirectories = @()
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "verification-process.ps1")
. (Join-Path $PSScriptRoot "ArtifactLifecycle.ps1")
if ([string]::IsNullOrWhiteSpace($Compiler)) {
    $Compiler = Join-Path $repoRoot "artifacts\example-tests\selfhost-stage3.exe"
}
$Compiler = [IO.Path]::GetFullPath($Compiler)
$fixtures = Join-Path $repoRoot "tests\Sollang.ExampleTests\Fixtures"
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot ("artifacts\scratch\native-cli-format-" + [guid]::NewGuid().ToString('N'))
}
$artifacts = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $artifacts) { throw 'Native format output must be fresh.' }
$artifactInitialization = @{ OutputDirectory = $artifacts }
if ($ReusableCompilerDirectories.Count -gt 0) {
    $artifactInitialization.ReusableCompilerDirectories = $ReusableCompilerDirectories
}
Initialize-ArtifactOutput @artifactInitialization
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null

$unformatted = Join-Path $fixtures "native-format-unformatted.slg"
$formatted = Join-Path $fixtures "native-format-formatted.slg"
$invalidCharacter = Join-Path $fixtures "native-format-invalid-character.slg"
$unterminatedString = Join-Path $fixtures "native-format-unterminated-string.slg"
$missingBrace = Join-Path $fixtures "native-format-invalid-missing-brace.slg"
$multilineParentheses = Join-Path $fixtures "native-format-multiline-parentheses-unformatted.slg"
$multilineParenthesesFormatted = Join-Path $fixtures "native-format-multiline-parentheses-formatted.slg"
$expectedFormatted = [IO.File]::ReadAllText($formatted).Replace("`r`n", "`n").Replace("`r", "`n")
$expectedMultilineParentheses = [IO.File]::ReadAllText($multilineParenthesesFormatted).Replace("`r`n", "`n").Replace("`r", "`n")

function Convert-ToWslPath {
    param([Parameter(Mandatory)] [string]$Path)

    $absolute = [IO.Path]::GetFullPath($Path)
    $drive = $absolute.Substring(0, 1).ToLowerInvariant()
    $tail = $absolute.Substring(3).Replace('\', '/')
    "/mnt/$drive/$tail"
}

function Get-CompilerPath {
    param([Parameter(Mandatory)] [string]$Path)

    if ($Target -eq "linux-x64") { Convert-ToWslPath $Path } else { $Path }
}

function Invoke-Format {
    param(
        [string[]]$Arguments,
        [string]$Name,
        [string]$StandardInput
    )

    $stdout = Join-Path $artifacts "$Name.stdout.txt"
    $stderr = Join-Path $artifacts "$Name.stderr.txt"
    $filePath = if ($Target -eq "linux-x64") { "wsl.exe" } else { $Compiler }
    $argumentList = if ($Target -eq "linux-x64") {
        @("-d", $Distribution, "--", (Convert-ToWslPath $Compiler), "format") + $Arguments
    } else {
        @("format") + $Arguments
    }
    $parameters = @{
        FilePath = $filePath
        ArgumentList = $argumentList
        RedirectStandardOutput = $stdout
        RedirectStandardError = $stderr
        PassThru = $true
        NoNewWindow = $true
    }
    if (-not [string]::IsNullOrWhiteSpace($StandardInput)) {
        # Start-Process opens redirected stdin exclusively on Windows. Keep the
        # authority fixture under its read lease and give the child owned bytes.
        $stdinSnapshot = Join-Path $artifacts "$Name.stdin.txt"
        [IO.File]::WriteAllBytes($stdinSnapshot, [IO.File]::ReadAllBytes($StandardInput))
        $parameters.RedirectStandardInput = $stdinSnapshot
    }
    $process = Start-Process @parameters
    Wait-VerificationProcess $process "$Name native format command"
    [pscustomobject]@{
        ExitCode = $process.ExitCode
        Stdout = [IO.File]::ReadAllText($stdout).Replace("`r`n", "`n").Replace("`r", "`n")
        Stderr = [IO.File]::ReadAllText($stderr).Replace("`r`n", "`n").Replace("`r", "`n")
    }
}

function Assert-Result {
    param(
        [object]$Actual,
        [int]$ExitCode,
        [string]$Stdout,
        [string]$Stderr,
        [string]$Name
    )

    if ($Actual.ExitCode -ne $ExitCode -or
        $Actual.Stdout -ne $Stdout -or
        $Actual.Stderr -ne $Stderr) {
        throw "$Name mismatch.`nexit: $($Actual.ExitCode), expected $ExitCode`nstdout:`n$($Actual.Stdout)`nstderr:`n$($Actual.Stderr)"
    }
}

Write-Host "[native format 1/17] Format stdin."
$result = Invoke-Format @("--stdin") "stdin-unformatted" $unformatted
Assert-Result $result 0 $expectedFormatted "" "stdin formatting"

Write-Host "[native format 2/17] Preserve formatter idempotence."
$result = Invoke-Format @("--stdin") "stdin-formatted" $formatted
Assert-Result $result 0 $expectedFormatted "" "stdin idempotence"

Write-Host "[native format 3/17] Remove a whole multiline control-condition parenthesis pair."
$result = Invoke-Format @("--stdin") "stdin-multiline-parentheses" $multilineParentheses
Assert-Result $result 0 $expectedMultilineParentheses "" "multiline control-parenthesis formatting"

Write-Host "[native format 4/17] Preserve multiline control-parenthesis formatter idempotence."
$result = Invoke-Format @("--stdin") "stdin-multiline-parentheses-formatted" $multilineParenthesesFormatted
Assert-Result $result 0 $expectedMultilineParentheses "" "multiline control-parenthesis idempotence"

Write-Host "[native format 5/17] Accept formatted input in check mode."
$result = Invoke-Format @("--check", (Get-CompilerPath $formatted)) "check-formatted" ""
Assert-Result $result 0 "" "" "formatted check"

Write-Host "[native format 6/17] Reject unformatted input in check mode without mutation."
$checkCopy = Join-Path $artifacts "check-unformatted.slg"
Copy-Item -LiteralPath $unformatted -Destination $checkCopy -Force
$before = [IO.File]::ReadAllBytes($checkCopy)
$result = Invoke-Format @("--check", (Get-CompilerPath $checkCopy)) "check-unformatted" ""
Assert-Result $result 1 "" "" "unformatted check"
$after = [IO.File]::ReadAllBytes($checkCopy)
if ([Convert]::ToHexString($before) -ne [Convert]::ToHexString($after)) {
    throw "format --check mutated its input"
}

Write-Host "[native format 7/17] Replace an unformatted file atomically."
$rewriteCopy = Join-Path $artifacts "rewrite.slg"
Copy-Item -LiteralPath $unformatted -Destination $rewriteCopy -Force
$result = Invoke-Format @((Get-CompilerPath $rewriteCopy)) "rewrite" ""
Assert-Result $result 0 "" "" "file rewrite"
$rewritten = [IO.File]::ReadAllText($rewriteCopy).Replace("`r`n", "`n").Replace("`r", "`n")
if ($rewritten -ne $expectedFormatted) {
    throw "file rewrite did not produce the canonical format"
}
if (Test-Path -LiteralPath "$rewriteCopy.sollang-format.tmp") {
    throw "atomic formatter replacement left its staging file behind"
}

Write-Host "[native format 8/17] Report an unexpected character."
$result = Invoke-Format @("--stdin") "invalid-character" $invalidCharacter
Assert-Result $result 1 "" "sollang: lex error at 1:8: unexpected character '@'`n" "unexpected-character diagnostic"

Write-Host "[native format 9/17] Report an unterminated string."
$result = Invoke-Format @("--stdin") "unterminated-string" $unterminatedString
Assert-Result $result 1 "" "sollang: lex error at 1:8: unterminated string literal`n" "unterminated-string diagnostic"

Write-Host "[native format 10/17] Report a missing closing brace."
$result = Invoke-Format @("--stdin") "missing-brace" $missingBrace
Assert-Result $result 1 "" "sollang: parse error at 2:1: expected RightBrace`n" "missing-brace diagnostic"

Write-Host "[native format 11/17] Require an input."
$result = Invoke-Format @() "missing-input" ""
Assert-Result $result 1 "" "sollang: usage: sollang format [--check] <source.slg> ... | --stdin`n" "missing-input diagnostic"

Write-Host "[native format 12/17] Reject unknown options."
$result = Invoke-Format @("--unknown") "unknown-option" ""
Assert-Result $result 1 "" "sollang: unknown format option '--unknown'`n" "unknown-option diagnostic"

Write-Host "[native format 13/17] Reject stdin/check conflicts."
$result = Invoke-Format @("--stdin", "--check") "stdin-check-conflict" $formatted
Assert-Result $result 1 "" "sollang: format --stdin cannot be combined with paths or --check`n" "stdin/check conflict diagnostic"

$rawTrailingWhitespace = Join-Path $fixtures "native-format-raw-trailing-whitespace.slg"
$expectedRawTrailingWhitespace = [IO.File]::ReadAllText($rawTrailingWhitespace).Replace("`r`n", "`n")
Write-Host "[native format 14/17] Preserve trailing whitespace inside multiline raw strings."
$result = Invoke-Format @("--stdin") "raw-trailing-whitespace" $rawTrailingWhitespace
Assert-Result $result 0 $expectedRawTrailingWhitespace "" "raw literal whitespace preservation"

Write-Host "[native format 15/17] Preserve raw literal formatter idempotence."
$rawFormatted = Join-Path $artifacts "raw-trailing-whitespace.stdout.txt"
$result = Invoke-Format @("--stdin") "raw-trailing-whitespace-idempotence" $rawFormatted
Assert-Result $result 0 $expectedRawTrailingWhitespace "" "raw literal whitespace idempotence"

$unicodeKeywordPrefix = Join-Path $fixtures "native-format-unicode-keyword-prefix.slg"
$expectedUnicodeKeywordPrefix = [IO.File]::ReadAllText($unicodeKeywordPrefix).Replace("`r`n", "`n")
Write-Host "[native format 16/17] Keep Unicode identifier prefixes out of continuation keywords."
$result = Invoke-Format @("--stdin") "unicode-keyword-prefix" $unicodeKeywordPrefix
Assert-Result $result 0 $expectedUnicodeKeywordPrefix "" "Unicode continuation keyword identity"

Write-Host "[native format 17/17] Preserve Unicode identifier formatter idempotence."
$unicodeFormatted = Join-Path $artifacts "unicode-keyword-prefix.stdout.txt"
$result = Invoke-Format @("--stdin") "unicode-keyword-prefix-idempotence" $unicodeFormatted
Assert-Result $result 0 $expectedUnicodeKeywordPrefix "" "Unicode continuation keyword idempotence"

Write-Host "Native format CLI verification passed (17/17)."
