import { mkdir, writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { getSamples } from "../app/samples.ts";

const repoRoot = path.resolve(import.meta.dirname, "..");
const auditRoot = path.join(repoRoot, "artifacts", "playground-reference");
const compiler = path.join(
  repoRoot,
  "src",
  "Sollang.Compiler",
  "bin",
  "Release",
  "net11.0",
  "Sollang.Compiler.dll"
);

await mkdir(auditRoot, { recursive: true });
const outputs = {};

for (const sample of getSamples("en")) {
  if (sample.input) {
    outputs[sample.id] = "<stdin is verified by the browser host regression>";
    continue;
  }
  const sourcePath = path.join(auditRoot, `${sample.id}.slg`);
  await writeFile(sourcePath, sample.code, "utf8");
  const result = spawnSync(
    "dotnet",
    [compiler, "run", sourcePath],
    {
      cwd: repoRoot,
      encoding: "utf8",
      input: sample.input ? `${sample.input}\n` : "",
      timeout: 120_000
    }
  );
  if (result.status !== 0) {
    throw new Error(
      `${sample.id} reference execution failed (${result.status})\n${result.stdout}\n${result.stderr}`
    );
  }
  outputs[sample.id] = result.stdout.replace(/\r\n?/g, "\n").trimEnd();
}

console.log(JSON.stringify(outputs, null, 2));
