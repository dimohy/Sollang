# Sollang Language Support

VS Code language support for Sollang `.slg` files.

## Features

- Registers `.slg` as `sollang`.
- Highlights comments, strings, `$name` and `$(expr)` interpolation, function
  declarations, receiver-only and parenthesized flow calls, `=>` bindings,
  `name!` mutable owner bindings, arrays, dictionaries, block-function calls,
  conditionals, types, numbers, namespaces, imports, block parameters, `fold`
  bindings, `yield()`, and operators.
- Adds Sollang-only default token colors for comments, strings, variables,
  parameters, keywords, types, namespaces, constants, numbers, operators, and
  punctuation while leaving function colors to the active VS Code theme.
- Adds indentation and bracket pairing for `{}`, `[]`, `()`, and `"`.
- Provides snippets for `main`, functions, flow calls, `each`, `repeat`,
  `fold`, `when`, mutable bindings, dollar interpolation, namespaces, and
  imports.

## Package And Install

From this folder:

```powershell
npx --yes @vscode/vsce package --no-dependencies --allow-missing-repository
code --install-extension .\sollang-language-support-0.3.0.vsix
```

For extension development, open this folder in VS Code and run the extension host
debug target.
