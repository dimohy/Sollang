import { createHash } from "node:crypto";
import { readFile, stat, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const compiler = process.argv[2];
const timingsPath = process.argv[3];
if (compiler === undefined || timingsPath === undefined) {
  throw new Error("usage: perf100-build-report.mjs <sollang-compiler> <timings.tsv>");
}

const definitions = [
  ["cpp", "benchmarks/perf100/cpp/runner.cpp", "artifacts/perf100/bin/cpp"],
  ["rust", "benchmarks/perf100/rust/runner.rs", "artifacts/perf100/bin/rust"],
  ["csharp-nativeaot", "benchmarks/perf100/csharp/Program.cs", "artifacts/perf100/bin/csharp-nativeaot/Perf100"],
  ["go", "benchmarks/perf100/go/runner.go", "artifacts/perf100/bin/go"],
  ["java", "benchmarks/perf100/java/Perf100.java", "artifacts/perf100/bin/java.jar"],
  ["sollang", "benchmarks/perf100/sollang/runner.slg", "artifacts/perf100/bin/sollang"],
];

async function identity(path) {
  const absolute = resolve(root, path);
  const bytes = await readFile(absolute);
  const info = await stat(absolute);
  return { path: path.replaceAll("\\", "/"), bytes: info.size, sha256: createHash("sha256").update(bytes).digest("hex") };
}

const timingRows = (await readFile(timingsPath, "utf8")).trim().split(/\r?\n/).map((line) => line.split("\t"));
const timings = Object.fromEntries(timingRows.map(([language, elapsedMs]) => [language, Number.parseInt(elapsedMs, 10)]));
const entries = {};
for (const [language, source, artifact] of definitions) {
  const elapsedMs = timings[language];
  if (!Number.isInteger(elapsedMs) || elapsedMs < 0) throw new Error(`missing build timing for ${language}`);
  entries[language] = { elapsedMs, source: await identity(source), artifact: await identity(artifact) };
}

const compilerPath = compiler.replaceAll("\\", "/");
const report = {
  schema: 1,
  completedUtc: new Date().toISOString(),
  measurement: "wall-clock build command elapsed time in milliseconds",
  sollangCompiler: await identity(compilerPath),
  entries,
};
await writeFile(resolve(root, "artifacts/perf100/build-report.json"), `${JSON.stringify(report, null, 2)}\n`, "utf8");
