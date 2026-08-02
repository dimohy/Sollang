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

const llms = `# Sollang

> A flow-first native programming language. Use the AI Agent Guide before generating code.

## Start here

- [AI Agent Guide](/ai/AI_AGENT_GUIDE.md): operational syntax, ownership, Flow Junctions, CLI, and validation workflow
- [Philosophy](/ai/PHILOSOPHY.md): language intent and design tests
- [Specification](/ai/SPEC.md): normative language surface
- [Decisions](/ai/DECISIONS.md): accepted decisions and evidence
- [Grammar](/ai/syntax/sollang.grammar): checked-in parser grammar
- [Lexer](/ai/syntax/sollang.lexer): checked-in lexer rules

## Focused references

- [Getting started](/ai/GETTING_STARTED.md)
- [Flow Junctions](/ai/FLOW_JUNCTIONS.md)
- [Arrays and ownership](/ai/ARRAYS.md)
- [Typed role blocks](/ai/ROLE_BLOCKS.md)
- [Grammar bootstrap](/ai/GRAMMAR_BOOTSTRAP.md)
- [Example catalog](/ai/EXAMPLE_CATALOG.md)
- [Stage 3 compiler](/ai/STAGE3_COMPILER.md)
`;
await writeFile(path.join(publicRoot, "llms.txt"), llms, "utf8");

console.log(`Prepared ${documents.length + 3} AI-agent documentation assets.`);
