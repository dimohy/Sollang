import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const wasmPath = process.argv[2] ?? path.join(repoRoot, "artifacts", "sollangc-browser.wasm");
const sourcePath = process.argv[3] ?? path.join(
  repoRoot,
  "examples",
  "regression",
  "23-webassembly-browser.slg"
);
const outputPath = process.argv[4] ?? path.join(repoRoot, "artifacts", "browser-stage2-output.ll");
const optionalArguments = process.argv.slice(5);
let expectedDiagnostic;
let additionalSourceManifest;
for (let index = 0; index < optionalArguments.length; index += 2) {
  const option = optionalArguments[index];
  const value = optionalArguments[index + 1];
  if (value === undefined) {
    throw new Error(`missing value for browser verifier option ${option}`);
  }
  if (option === "--expect-diagnostic") expectedDiagnostic = value;
  else if (option === "--expect-diagnostic-base64") {
    expectedDiagnostic = Buffer.from(value, "base64").toString("utf8");
  }
  else if (option === "--source-manifest") additionalSourceManifest = value;
  else throw new Error(`unknown browser verifier option ${option}`);
}
const wasmBytes = fs.readFileSync(wasmPath);
const sourceBytes = fs.readFileSync(sourcePath);
const stdlibRoot = path.join(repoRoot, "stdlib");
const stdlibPaths = [];
function collectStdlib(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) collectStdlib(fullPath);
    else if (entry.isFile() && entry.name.endsWith(".slg")) stdlibPaths.push(fullPath);
  }
}
collectStdlib(stdlibRoot);
stdlibPaths.sort();
const stdlib = stdlibPaths.map(file => {
  const source = fs.readFileSync(file, "utf8");
  return {
    namespace: source.match(/^\s*namespace\s+([A-Za-z_][A-Za-z0-9_.]*)/m)?.[1] ?? "",
    path: path.relative(repoRoot, file).replaceAll("\\", "/"),
    source: Buffer.from(source)
  };
});
function importedNamespaces(source) {
  return [...source.toString("utf8").matchAll(/^\s*import\s+([A-Za-z_][A-Za-z0-9_.]*)/gm)]
    .map(match => match[1]);
}
const stdlibByNamespace = new Map();
for (const entry of stdlib) {
  const fragments = stdlibByNamespace.get(entry.namespace) ?? [];
  fragments.push(entry);
  stdlibByNamespace.set(entry.namespace, fragments);
}
const explicitSources = [];
if (additionalSourceManifest) {
  const manifestPath = path.resolve(repoRoot, additionalSourceManifest);
  for (const line of fs.readFileSync(manifestPath, "utf8").split(/\r?\n/)) {
    const relative = line.trim();
    if (!relative || relative.startsWith("#")) continue;
    const explicitPath = path.resolve(repoRoot, relative);
    if (explicitPath === path.resolve(sourcePath)) continue;
    explicitSources.push({
      path: relative.replaceAll("\\", "/"),
      source: fs.readFileSync(explicitPath)
    });
  }
}
const selectedStdlib = [];
const visitedNamespaces = new Set();
const pendingNamespaces = [
  ...importedNamespaces(sourceBytes),
  ...explicitSources.flatMap(entry => importedNamespaces(entry.source))
];
while (pendingNamespaces.length > 0) {
  const namespace = pendingNamespaces.shift();
  if (visitedNamespaces.has(namespace)) continue;
  visitedNamespaces.add(namespace);
  const fragments = stdlibByNamespace.get(namespace) ?? [];
  for (const entry of fragments) {
    selectedStdlib.push(entry);
    pendingNamespaces.push(...importedNamespaces(entry.source));
  }
}
const explicitPaths = new Set(explicitSources.map(entry => entry.path));
const sourceBuffers = [
  sourceBytes,
  ...explicitSources.map(entry => entry.source),
  ...selectedStdlib.filter(entry => !explicitPaths.has(entry.path)).map(entry => entry.source)
];
const selectedStdlibSummary = selectedStdlib.map(entry => entry.path).join(", ");
const decoder = new TextDecoder();
const outputChunks = [];
const diagnosticChunks = [];

let memory;
let heapCursor = 0;
const sourcePointers = [];
const allocationSizes = new Map();
const sourceLengthRequests = [];

function sizeClass(byteLength) {
  const requested = Math.max(Number(byteLength), 1);
  let blockSize = 16;
  while (blockSize < requested) blockSize *= 2;
  return blockSize;
}

function allocate(byteLength) {
  const requested = Number(byteLength) === 0 ? 1024 : sizeClass(byteLength);
  const aligned = Math.ceil(heapCursor / 16) * 16;
  const end = aligned + requested;
  const available = memory.buffer.byteLength;
  if (end > available) {
    memory.grow(Math.ceil((end - available) / 65536));
  }
  heapCursor = end;
  allocationSizes.set(aligned, requested);
  return aligned;
}

function reallocate(oldPointer, byteLength) {
  const normalizedOldPointer = oldPointer >>> 0;
  const requested = sizeClass(byteLength);
  const oldLength = allocationSizes.get(normalizedOldPointer) ?? 0;
  if (normalizedOldPointer !== 0 && oldLength >= requested) {
    return normalizedOldPointer;
  }
  const newPointer = allocate(requested);
  const copyLength = Math.min(oldLength, Number(byteLength));
  if (normalizedOldPointer !== 0 && copyLength > 0) {
    new Uint8Array(memory.buffer, newPointer, copyLength)
      .set(new Uint8Array(memory.buffer, normalizedOldPointer, copyLength));
  }
  return newPointer;
}

const imports = {
  env: {
    sollang_browser_alloc(bytes) {
      return allocate(bytes);
    },
    sollang_browser_realloc(pointer, bytes) {
      return reallocate(pointer, bytes);
    },
    sollang_browser_now_millis() {
      return BigInt(Math.trunc(performance.now()));
    },
    sollang_browser_utc_now_millis() {
      return BigInt(Date.now());
    },
    sollang_browser_source_count() {
      return sourceBuffers.length;
    },
    sollang_browser_source_pointer(index) {
      return sourcePointers[index];
    },
    sollang_browser_source_length(index) {
      const length = sourceBuffers[index]?.byteLength ?? 0;
      sourceLengthRequests.push(`${index}:${length}`);
      return length;
    },
    sollang_browser_read() {
      return 0;
    },
    sollang_browser_write(pointer, length) {
      outputChunks.push(new Uint8Array(memory.buffer.slice(pointer, pointer + length)));
      return 1;
    },
    sollang_browser_eprint(pointer, length) {
      diagnosticChunks.push(new Uint8Array(memory.buffer.slice(pointer, pointer + length)));
      return 1;
    },
    sollang_browser_panic(pointer, length) {
      console.error(`PANIC: ${decoder.decode(new Uint8Array(memory.buffer, pointer, length))}`);
    }
  }
};

const { instance } = await WebAssembly.instantiate(wasmBytes, imports);
memory = instance.exports.memory;
heapCursor = memory.buffer.byteLength;
for (const buffer of sourceBuffers) {
  const pointer = instance.exports.sollang_alloc(BigInt(buffer.byteLength));
  sourcePointers.push(pointer);
  new Uint8Array(memory.buffer, pointer, buffer.byteLength).set(buffer);
}

let exitCode;
try {
  exitCode = instance.exports.sollang_start();
} catch (error) {
  const partial = outputChunks.map(chunk => decoder.decode(chunk, { stream: true })).join("");
  console.error(`PARTIAL OUTPUT:\n${partial.slice(-2000)}`);
  console.error(`ALLOCATOR: ${allocationSizes.size} live allocations, ${heapCursor} heap bytes`);
  throw error;
}
const diagnosticDecoder = new TextDecoder();
const diagnostics = diagnosticChunks
  .map(chunk => diagnosticDecoder.decode(chunk, { stream: true })).join("")
  + diagnosticDecoder.decode();
const output = outputChunks.map(chunk => decoder.decode(chunk, { stream: true })).join("")
  + decoder.decode();
fs.writeFileSync(outputPath, output);

if (expectedDiagnostic) {
  const compilerMessages = diagnostics + output;
  if (!compilerMessages.includes(expectedDiagnostic)
      || output.includes('target triple = "wasm32-unknown-unknown-wasm"')) {
    throw new Error(
      `Stage2 browser compiler diagnostic mismatch: expected=${JSON.stringify(expectedDiagnostic)}, `
      + `exit=${exitCode}, diagnostics=${diagnostics.slice(0, 800)}, output=${output.slice(0, 800)}`
    );
  }
  console.log(`PASS Stage2 browser diagnostic: ${expectedDiagnostic}`);
  process.exit(0);
}

if (exitCode !== 0 || !output.includes('target triple = "wasm32-unknown-unknown-wasm"')) {
  throw new Error(
    `Stage2 browser compiler failed: exit=${exitCode}, diagnostics=${diagnostics.slice(0, 400)}, `
    + `output=${output.slice(0, 400)}; stdlib=[${selectedStdlibSummary}]; `
    + `sourceLengths=[${sourceBuffers.map(buffer => buffer.byteLength).join(",")}]; `
    + `lengthRequests=[${sourceLengthRequests.slice(-32).join(",")}]`
  );
}

const sourceName = path.basename(sourcePath);
if (sourceName === "1135-wasm-uintsize-interpolation-width.slg"
    && (output.includes("zext i32 %v6_expression0 to i64")
      || !output.includes("call void @sollang_runtime_print_i64(i64 %v6_expression0"))) {
  throw new Error("Stage2 browser compiler did not preserve the emitted i64 array-length width through interpolation");
}
if (sourceName === "1136-wasm-trailing-value-if-effect.slg"
    && (!/\bif\d+_then:/m.test(output)
      || !output.includes("call void @sollang_runtime_print("))) {
  throw new Error("Stage2 browser compiler silently omitted the trailing value-if or its console consumer");
}

for (const intrinsic of ["llvm.memcpy.p0.p0.i64", "llvm.memset.p0.i64"]) {
  if (output.includes(`call void @${intrinsic}`)
      && !output.includes(`declare void @${intrinsic}`)) {
    throw new Error(`Stage2 browser compiler omitted the declaration for @${intrinsic}`);
  }
}

const formatterCalls = new Set(
  [...output.matchAll(/call void @(sollang_runtime_(?:e?print)_(?:i1|i32|i64))\(/g)]
    .map(match => match[1])
);
for (const helper of formatterCalls) {
  const definition = new RegExp(`define(?: internal)? void @${helper}\\(`);
  if (!definition.test(output)) {
    throw new Error(`Stage2 browser compiler emitted a call without its runtime definition: @${helper}`);
  }
}

console.log(
  `PASS Stage2 browser compiler: ${sourceBytes.byteLength} source bytes -> ${output.length} LLVM characters; `
  + `${allocationSizes.size} allocations, ${heapCursor} heap bytes`
);
