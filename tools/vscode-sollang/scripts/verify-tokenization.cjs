const fs = require("fs");
const path = require("path");
const textmate = require("vscode-textmate");
const oniguruma = require("vscode-oniguruma");
const { findArrowOffsets } = require("../arrow-highlighting");
const Module = require("module");

const extensionRoot = path.resolve(__dirname, "..");
const repositoryRoot = path.resolve(extensionRoot, "..", "..");
const grammarPath = path.join(extensionRoot, "syntaxes", "sollang.tmLanguage.json");
const packagePath = path.join(extensionRoot, "package.json");
const wasmPath = require.resolve("vscode-oniguruma/release/onig.wasm");

function collectFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) return collectFiles(fullPath);
    return entry.isFile()
      && (entry.name.endsWith(".slg")
        || entry.name === "sollang.project"
        || entry.name === "sollang.workspace")
      ? [fullPath]
      : [];
  });
}

function scopesFor(tokens, line, text) {
  const start = line.indexOf(text);
  if (start < 0) throw new Error(`sample text not found: ${text}`);
  const token = tokens.find((candidate) => candidate.startIndex <= start && candidate.endIndex > start);
  if (!token) throw new Error(`token not found: ${text}`);
  return token.scopes;
}

function verifyDecorationRuntime() {
  const source = "value -> transform => result # -> =>\n\"-> =>\" -> println";
  const decorationTypes = [];
  const decorationCalls = [];
  const document = {
    languageId: "sollang",
    getText: () => source,
    positionAt: (offset) => offset
  };
  const editor = {
    document,
    setDecorations: (decoration, ranges) => decorationCalls.push({ decoration, ranges })
  };
  class ThemeColor {
    constructor(id) { this.id = id; }
  }
  class Range {
    constructor(start, end) {
      this.start = start;
      this.end = end;
    }
  }
  const disposable = () => ({ dispose() {} });
  const vscode = {
    ThemeColor,
    Range,
    DecorationRangeBehavior: { ClosedClosed: 1 },
    window: {
      visibleTextEditors: [editor],
      createTextEditorDecorationType: (options) => {
        const decoration = { options, dispose() {} };
        decorationTypes.push(decoration);
        return decoration;
      },
      onDidChangeVisibleTextEditors: disposable,
      showErrorMessage: () => Promise.resolve()
    },
    workspace: {
      onDidChangeTextDocument: disposable,
      getConfiguration: () => ({ get: (_name, fallback) => fallback })
    },
    languages: {
      registerDocumentFormattingEditProvider: disposable
    }
  };

  const originalLoad = Module._load;
  Module._load = function(request, parent, isMain) {
    return request === "vscode"
      ? vscode
      : originalLoad.call(this, request, parent, isMain);
  };
  try {
    const extensionPath = path.join(extensionRoot, "extension.js");
    delete require.cache[require.resolve(extensionPath)];
    const extension = require(extensionPath);
    extension.activate({ subscriptions: [] });
  } finally {
    Module._load = originalLoad;
  }

  const colors = decorationTypes.map((item) => item.options.color.id);
  if (JSON.stringify(colors) !== JSON.stringify([
    "sollang.flowArrowForeground",
    "sollang.bindingArrowForeground"
  ])) {
    throw new Error(`decoration theme colors mismatch: ${JSON.stringify(colors)}`);
  }
  if (decorationCalls.length !== 2
    || decorationCalls[0].ranges.length !== 2
    || decorationCalls[1].ranges.length !== 1) {
    throw new Error(`decoration activation mismatch: ${JSON.stringify(decorationCalls)}`);
  }
}

async function main() {
  const arrowFixture = [
    "value -> transform => result # -> =>",
    "\"-> =>\" -> println",
    "\"\"\"",
    "-> =>",
    "\"\"\" => rawText"
  ].join("\n");
  const highlighted = findArrowOffsets(arrowFixture);
  const highlightedText = (ranges) => ranges.map(([start, end]) => arrowFixture.slice(start, end));
  if (JSON.stringify(highlightedText(highlighted.flow)) !== JSON.stringify(["->", "->"])) {
    throw new Error(`flow decoration lexer mismatch: ${JSON.stringify(highlighted.flow)}`);
  }
  if (JSON.stringify(highlightedText(highlighted.binding)) !== JSON.stringify(["=>", "=>"])) {
    throw new Error(`binding decoration lexer mismatch: ${JSON.stringify(highlighted.binding)}`);
  }
  verifyDecorationRuntime();

  const wasm = fs.readFileSync(wasmPath);
  await oniguruma.loadWASM(wasm.buffer.slice(wasm.byteOffset, wasm.byteOffset + wasm.byteLength));
  const onigLib = Promise.resolve({
    createOnigScanner: (sources) => new oniguruma.OnigScanner(sources),
    createOnigString: (value) => new oniguruma.OnigString(value)
  });
  const registry = new textmate.Registry({
    onigLib,
    loadGrammar: async (scopeName) => scopeName === "source.sollang"
      ? textmate.parseRawGrammar(fs.readFileSync(grammarPath, "utf8"), grammarPath)
      : null
  });
  const grammar = await registry.loadGrammar("source.sollang");
  if (!grammar) throw new Error("Sollang grammar did not load");

  const assertions = [
    ["value -> transform => result", "->", "keyword.operator.flow.sollang"],
    ["value -> transform => result", "=>", "keyword.operator.binding.sollang"],
    ["task -> await => result", "await", "keyword.control.async.sollang"],
    ["task -> cancel", "cancel", "keyword.control.async.sollang"],
    ["Result<File, Text>.Ok(reader)", "File", "entity.name.type.nominal.sollang"],
    ["inner! == 2 -> if continue", "continue", "keyword.control.loop.sollang"],
    ["import sollang.compiler.lexer", "sollang.compiler.lexer", "entity.name.namespace.sollang"],
    ["workspace { members: [\"packages/base\"] }", "workspace", "keyword.control.declaration.manifest.sollang"],
    ["workspace { members: [\"packages/base\"] }", "members", "keyword.control.declaration.manifest.sollang"],
    ["project { dependencies: {} }", "dependencies", "keyword.control.declaration.manifest.sollang"],
    ["self -> inspect", "self", "variable.language.special.sollang"]
  ];
  for (const [line, text, expectedScope] of assertions) {
    const result = grammar.tokenizeLine(line);
    const scopes = scopesFor(result.tokens, line, text);
    if (!scopes.includes(expectedScope)) {
      throw new Error(`${JSON.stringify(text)} scopes ${scopes.join(" ")} do not include ${expectedScope}`);
    }
  }

  const extensionManifest = JSON.parse(fs.readFileSync(packagePath, "utf8"));
  const colorRules = extensionManifest.contributes.configurationDefaults
    ["editor.tokenColorCustomizations"].textMateRules;
  const expectedOperatorStyles = new Map([
    ["source.sollang keyword.operator.flow.sollang", "#00D7FF"],
    ["source.sollang keyword.operator.binding.sollang", "#FFD166"]
  ]);
  for (const [scope, foreground] of expectedOperatorStyles) {
    const rule = colorRules.find((candidate) => candidate.scope === scope);
    if (!rule || rule.settings.foreground !== foreground || rule.settings.fontStyle !== "bold") {
      throw new Error(`${scope} must be independently bold and colored ${foreground}`);
    }
  }

  const roots = ["examples", "selfhost", "stdlib"].map((name) => path.join(repositoryRoot, name));
  const files = roots.flatMap(collectFiles);
  let lines = 0;
  let tokens = 0;
  for (const file of files) {
    let ruleStack = textmate.INITIAL;
    for (const line of fs.readFileSync(file, "utf8").split(/\r?\n/)) {
      const result = grammar.tokenizeLine(line, ruleStack);
      ruleStack = result.ruleStack;
      lines += 1;
      tokens += result.tokens.length;
    }
  }
  process.stdout.write(`textmate ok files=${files.length} lines=${lines} tokens=${tokens}\n`);
}

main().catch((error) => {
  console.error(error.stack || error);
  process.exitCode = 1;
});
