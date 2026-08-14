import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { benchmarkCases, benchmarkFamilies } from "../benchmarks/perf100/cases.mjs";

const root = resolve(import.meta.dirname, "..");
const outputDirectory = resolve(root, "artifacts", "perf100");
await mkdir(outputDirectory, { recursive: true });

const manifest = {
  schema: 1,
  comparisonLanguages: ["sollang", "cpp", "rust", "csharp-nativeaot", "go", "java"],
  requiredSollangRank: 3,
  preferredSollangRank: 1,
  familyCount: benchmarkFamilies.length,
  caseCount: benchmarkCases.length,
  families: benchmarkFamilies,
  cases: benchmarkCases,
};

const output = resolve(outputDirectory, "manifest.json");
await writeFile(output, `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
process.stdout.write(`Wrote ${benchmarkCases.length} benchmark cases to ${output}\n`);
