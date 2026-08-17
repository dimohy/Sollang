import { copyFile, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const guidePath = path.join(repoRoot, "docs", "AI_AGENT_GUIDE.md");
const publicRoot = path.join(repoRoot, "public");
const publicAiRoot = path.join(publicRoot, "ai");

const documents = [
  "AI_AGENT_GUIDE.md",
  "PHILOSOPHY.md",
  "SPEC.md",
  "DECISIONS.md",
  "GETTING_STARTED.md",
  "FLOW_JUNCTIONS.md",
  "ARRAYS.md",
  "ROLE_BLOCKS.md",
  "GRAMMAR_BOOTSTRAP.md",
  "EXAMPLE_CATALOG.md",
  "STAGE3_COMPILER.md"
];

const guide = await readFile(guidePath, "utf8");
for (const document of documents.slice(1)) {
  if (!guide.includes(`(${document})`)) {
    throw new Error(`AI agent guide must link to docs/${document}`);
  }
}
if (!guide.includes("../syntax/sollang.grammar") || !guide.includes("../syntax/sollang.lexer")) {
  throw new Error("AI agent guide must link to the canonical lexer and grammar");
}

await rm(publicAiRoot, { recursive: true, force: true });
await mkdir(publicAiRoot, { recursive: true });
for (const document of documents) {
  await copyFile(path.join(repoRoot, "docs", document), path.join(publicAiRoot, document));
}
await mkdir(path.join(publicAiRoot, "syntax"), { recursive: true });
await copyFile(path.join(repoRoot, "syntax", "sollang.lexer"), path.join(publicAiRoot, "syntax", "sollang.lexer"));
await copyFile(path.join(repoRoot, "syntax", "sollang.grammar"), path.join(publicAiRoot, "syntax", "sollang.grammar"));

const webLlms = `# Sollang

> A flow-first native programming language. Use the AI Agent Guide before generating code.

## Read in this order

1. [Philosophy](/ai/PHILOSOPHY.md) — design intent and the left-to-right rule
2. [AI Agent Guide](/ai/AI_AGENT_GUIDE.md) — current coding vocabulary and verification contract
3. Repository \`examples/user/README.md\` and its 20 small examples — preferred surface syntax
4. [Specification](/ai/SPEC.md) — normative semantics and target boundaries
5. [Decisions](/ai/DECISIONS.md) — accepted choices and rejected alternatives
6. [Flow Junctions](/ai/FLOW_JUNCTIONS.md) when branching, products, tap, partition, or parallel flow are involved
7. [Lexer](/ai/syntax/sollang.lexer) and [grammar](/ai/syntax/sollang.grammar) — canonical lexical and parser inputs

Do not infer Sollang syntax from another language, from README examples alone, or from one isolated fixture.

## Focused references

- [Getting started](/ai/GETTING_STARTED.md)
- [Arrays and ownership](/ai/ARRAYS.md)
- [Typed role blocks](/ai/ROLE_BLOCKS.md)
- [Grammar bootstrap](/ai/GRAMMAR_BOOTSTRAP.md)
- [Example catalog](/ai/EXAMPLE_CATALOG.md)
- [Stage 3 compiler](/ai/STAGE3_COMPILER.md)
`;

const repoLlms = `# Sollang

> A flow-first native programming language. Use docs/AI_AGENT_GUIDE.md before generating or changing Sollang code.

## Read in this order

1. [docs/PHILOSOPHY.md](docs/PHILOSOPHY.md) — design intent and the left-to-right rule
2. [docs/AI_AGENT_GUIDE.md](docs/AI_AGENT_GUIDE.md) — current coding vocabulary and verification contract
3. [examples/user/README.md](examples/user/README.md) and its 20 small examples — preferred surface syntax
4. [docs/SPEC.md](docs/SPEC.md) — normative semantics and target boundaries
5. [docs/DECISIONS.md](docs/DECISIONS.md) — accepted choices and rejected alternatives
6. [docs/FLOW_JUNCTIONS.md](docs/FLOW_JUNCTIONS.md) when branching, products, tap, partition, or parallel flow are involved
7. [syntax/sollang.lexer](syntax/sollang.lexer) and [syntax/sollang.grammar](syntax/sollang.grammar) — canonical lexical and parser inputs

Do not infer Sollang syntax from another language, from README examples alone, or from one isolated fixture.

## Discovery entry points

These files must stay short pointers. They must not copy the guide or teach a conflicting syntax.

- [AGENTS.md](AGENTS.md)
- [CLAUDE.md](CLAUDE.md)
- [.github/copilot-instructions.md](.github/copilot-instructions.md)
- [README.md](README.md)

## Focused references

- [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md)
- [docs/ARRAYS.md](docs/ARRAYS.md)
- [docs/ROLE_BLOCKS.md](docs/ROLE_BLOCKS.md)
- [docs/GRAMMAR_BOOTSTRAP.md](docs/GRAMMAR_BOOTSTRAP.md)
- [docs/EXAMPLE_CATALOG.md](docs/EXAMPLE_CATALOG.md)
- [docs/STAGE3_COMPILER.md](docs/STAGE3_COMPILER.md)
`;

await writeFile(path.join(publicRoot, "llms.txt"), webLlms, "utf8");
await writeFile(path.join(repoRoot, "llms.txt"), repoLlms, "utf8");

console.log(`Prepared ${documents.length + 4} AI-agent documentation assets.`);
