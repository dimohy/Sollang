function Get-SollangModuleHeader {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Source)

    # SourceFile in syntax/sollang.grammar permits namespace/import/library
    # declarations only before the first ordinary declaration or statement.
    # Stop there: source text embedded in a body is not a module dependency.
    $path = '[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*'
    $end = '[ \t]*(?:\#[^\r\n]*)?(?:\r?\n|\z)'
    $string = '(?: (?<raw>"{3,}) (?s:.*?) \k<raw> | " (?: \\. | [^"\\] )* " )'
    $pattern = '(?x)\G(?:\s+|\#[^\r\n]*'
    $pattern += '|namespace\s+(?<module>' + $path + ')' + $end
    $pattern += '|import\s+(?<dependency>' + $path + ')(?:[ \t]+as[ \t]+[A-Za-z_][A-Za-z0-9_]*)?' + $end
    $pattern += '|library[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]+from[ \t]+' + $string + $end + ')'
    $module = ''
    $imports = [Collections.Generic.List[string]]::new()
    foreach ($match in [regex]::Matches($Source, $pattern)) {
        if ($match.Groups['module'].Success) { $module = $match.Groups['module'].Value }
        if ($match.Groups['dependency'].Success) { $imports.Add($match.Groups['dependency'].Value) }
    }
    [pscustomobject]@{ Namespace = $module; Imports = $imports.ToArray() }
}
