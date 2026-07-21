# Sollang Language Support

VS Code language support for Sollang `.slg` files and language-shaped project
manifests.

Parser-backed formatting invokes `sollang format --stdin`. Set
`sollang.compilerPath` when the compiler is not available on `PATH`; invalid
source is left unchanged and the compiler's real parser diagnostic is shown.

## Features

- Registers `.slg`, `sollang.project`, and `sollang.workspace` as `sollang`.
- Highlights comments, interpolated strings, indentation-normalized raw multiline
  strings, declarations (`struct`, nested `struct`, `enum`, `effect`, `trait`,
  `impl`), generics, async/effect clauses, `await`/`cancel` flow targets,
  receiver-only and parenthesized flow
  calls, bindings, owned values, compile-time ranges, arrays, dictionaries,
  memory mapping, fixed-width integer and floating-point types, Result
  propagation, loop controls, namespaces, imports, workspace/project manifest
  fields, and operators.
- Adds Sollang-only default token colors for comments, strings, variables,
  parameters, keywords, types, namespaces, constants, numbers, operators, and
  punctuation while leaving function colors to the active VS Code theme.
- Adds indentation and bracket pairing for `{}`, `[]`, `()`, and `"`.
- Formats `.slg` documents with the compiler's generated parser.
- Provides snippets for `main`, functions, async functions, structs, enums,
  trait implementations, raw multiline strings, flow calls, `each`, `repeat`,
  `fold`, `when`, mutable bindings, interpolation, namespaces, and imports.

## Package And Install

From this folder:

```powershell
npx --yes @vscode/vsce package --no-dependencies --allow-missing-repository
code --install-extension .\sollang-language-support-0.5.1.vsix --force
```

For extension development, open this folder in VS Code and run the extension host
debug target.
