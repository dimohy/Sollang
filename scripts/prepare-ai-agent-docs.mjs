import { copyFile, mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const publicRoot = path.join(repoRoot, "public");
const publicAiRoot = path.join(publicRoot, "ai");
const canonicalGuide = "AI_SLG_BEST_PRACTICES.md";
const documents = [
  canonicalGuide, "AI_AGENT_GUIDE.md", "PHILOSOPHY.md", "SPEC.md",
  "DECISIONS.md", "GETTING_STARTED.md", "FLOW_JUNCTIONS.md", "ARRAYS.md",
  "ROLE_BLOCKS.md", "GRAMMAR_BOOTSTRAP.md", "EXAMPLE_CATALOG.md", "STAGE3_COMPILER.md"
];
const guide = await readFile(path.join(repoRoot, "docs", canonicalGuide), "utf8");
for (const document of documents.slice(2)) {
  if (!guide.includes(`(${document})`)) {
    throw new Error(`Single AI guide must link to docs/${document}`);
  }
}
for (const name of ["sollang.lexer", "sollang.grammar"]) {
  if (!guide.includes(`../syntax/${name}`)) {
    throw new Error(`Single AI guide must link to syntax/${name}`);
  }
}
// Update only owned outputs. Keep repository-relative source links while
// adapting syntax links to the generated /ai/syntax/ directory on the website.
await mkdir(path.join(publicAiRoot, "syntax"), { recursive: true });
for (const document of documents) {
  const text = await readFile(path.join(repoRoot, "docs", document), "utf8");
  await writeFile(path.join(publicAiRoot, document), text.replaceAll("../syntax/", "syntax/"), "utf8");
}
for (const name of ["sollang.lexer", "sollang.grammar"]) {
  await copyFile(path.join(repoRoot, "syntax", name), path.join(publicAiRoot, "syntax", name));
}
function discovery(prefix, web) {
  const title = web ? "SLG best practices for AI Agents" : `docs/${canonicalGuide}`;
  const example = web ? "Repository examples/user/README.md" : "[User examples](examples/user/README.md)";
  return `# Sollang

> A flow-first native programming language.

## Single AI guide

Read [${title}](${prefix}${canonicalGuide}) for current SLG syntax and beautiful code.
It covers the language model, ownership, effects, storage, flow, and verification.
AI_AGENT_GUIDE.md is only a compatibility pointer; no second AI guide is required.

## Focused sources when needed

- [Specification](${prefix}SPEC.md) — detailed normative contracts and target boundaries
- [Philosophy](${prefix}PHILOSOPHY.md) — design intent
- ${example} — executable examples
- [Lexer](${web ? "/ai/" : ""}syntax/sollang.lexer) and [grammar](${web ? "/ai/" : ""}syntax/sollang.grammar) — exact syntax

Do not infer Sollang syntax from another language or one isolated fixture.
Keep the single guide current when syntax or coding criteria change; keep progress logs out of it.
`;
}
await writeFile(path.join(repoRoot, "llms.txt"), discovery("docs/", false), "utf8");
await writeFile(path.join(publicRoot, "llms.txt"), discovery("/ai/", true), "utf8");
console.log(`Prepared ${documents.length + 4} AI documentation assets from the single guide.`);
