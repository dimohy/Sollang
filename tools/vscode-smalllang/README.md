# SmallLang Language Support

VS Code language support for SmallLang `.sl` files.

## Features

- Registers `.sl` as `smalllang`.
- Highlights comments, strings, interpolation, function declarations, function
  calls, value-flow arrows, block-function calls, conditionals, types, numbers,
  namespaces, imports, block parameters, `fold` bindings, `yield()`, and
  operators.
- Adds indentation and bracket pairing for `{}`, `()`, and `"`.
- Provides snippets for `main`, functions, flow calls, `each`, `repeat`, and
  `fold`, `when`, namespaces, and imports.

## Package And Install

From this folder:

```powershell
npx --yes @vscode/vsce package --no-dependencies --allow-missing-repository
code --install-extension .\smalllang-language-support-0.1.2.vsix
```

For extension development, open this folder in VS Code and run the extension host
debug target.
