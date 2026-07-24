import { access, mkdir, readFile, readdir, rm, writeFile } from "node:fs/promises";
import path from "node:path";

const repoRoot = path.resolve(import.meta.dirname, "..");
const stdlibRoot = path.join(repoRoot, "stdlib");
const publicRoot = path.join(repoRoot, "public");
const compilerDestination = path.join(publicRoot, "sollangc-stage2-0.2.260723.wasm");
const browserLlvmSourceRoot = path.join(repoRoot, ".tools", "browser-llvm");
const publicLlvmRoot = path.join(publicRoot, "llvm-16");
const toolChunkBytes = 20 * 1024 * 1024;

async function publishToolChunks(toolName) {
  const source = await readFile(path.join(browserLlvmSourceRoot, `${toolName}.wasm`));
  const existing = await readdir(publicLlvmRoot);
  await Promise.all(existing
    .filter(name => name.startsWith(`${toolName}.wasm.part-`))
    .map(name => rm(path.join(publicLlvmRoot, name))));

  const parts = [];
  for (let offset = 0, index = 0; offset < source.byteLength; offset += toolChunkBytes, index++) {
    const name = `${toolName}.wasm.part-${index.toString().padStart(2, "0")}`;
    await writeFile(
      path.join(publicLlvmRoot, name),
      source.subarray(offset, Math.min(offset + toolChunkBytes, source.byteLength))
    );
    parts.push(name);
  }
  return parts;
}

async function slgFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const nested = await Promise.all(entries.map(async entry => {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) return slgFiles(fullPath);
    return entry.isFile() && entry.name.endsWith(".slg") ? [fullPath] : [];
  }));
  return nested.flat();
}

const paths = (await slgFiles(stdlibRoot)).sort((left, right) =>
  left.localeCompare(right, "en")
);
const sources = await Promise.all(paths.map(async sourcePath => ({
  namespace: (await readFile(sourcePath, "utf8"))
    .match(/^\s*namespace\s+([A-Za-z_][A-Za-z0-9_.]*)/m)?.[1] ?? "",
  source: await readFile(sourcePath, "utf8")
})));

await mkdir(publicRoot, { recursive: true });
await mkdir(publicLlvmRoot, { recursive: true });
await writeFile(
  path.join(publicRoot, "stdlib-0.2.260723.json"),
  JSON.stringify(sources),
  "utf8"
);
await access(compilerDestination);
const llvmToolParts = {
  llc: await publishToolChunks("llc"),
  lld: await publishToolChunks("lld")
};
await writeFile(
  path.join(publicLlvmRoot, "tools.json"),
  JSON.stringify(llvmToolParts),
  "utf8"
);

console.log(
  `Verified Stage2 WASM, prepared ${sources.length} standard-library sources, `
  + `and split LLVM into ${llvmToolParts.llc.length + llvmToolParts.lld.length} deployable chunks.`
);
