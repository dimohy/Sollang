import fs from "node:fs";

const MAX_WASM_BYTES = 64 * 1024 * 1024;
const MAX_MEMORY_PAGES = 4096;
const MAX_ALLOCATION_BYTES = 64 * 1024 * 1024;
const MAX_OUTPUT_BYTES = 1024 * 1024;

const wasmPath = process.argv[2];
const expectedPath = process.argv[3];
if (!wasmPath || !expectedPath) {
  throw new Error("usage: verify-uri-browser-program.mjs <program.wasm> <expected.txt>");
}

const wasmBytes = fs.readFileSync(wasmPath);
if (wasmBytes.byteLength === 0 || wasmBytes.byteLength > MAX_WASM_BYTES) {
  throw new Error(`URI browser wasm size is outside 1..${MAX_WASM_BYTES}: ${wasmBytes.byteLength}`);
}
const module = new WebAssembly.Module(wasmBytes);
const imports = WebAssembly.Module.imports(module);
const allowedImports = new Set([
  "env:sollang_browser_alloc",
  "env:sollang_browser_realloc",
  "env:memset",
  "env:memcpy",
  "env:sollang_browser_write",
  "env:sollang_browser_panic"
]);
const importNames = imports.map(value => `${value.module}:${value.name}`);
const forbiddenImports = importNames.filter(value => !allowedImports.has(value));
const nonFunctionImports = imports.filter(value => value.kind !== "function");
if (forbiddenImports.length !== 0 || nonFunctionImports.length !== 0) {
  throw new Error(`URI browser program has effectful or unknown imports: ${forbiddenImports.join(", ")}`);
}

const decoder = new TextDecoder("utf-8", { fatal: true });
const chunks = [];
let memory;
let heapCursor = 0;
let outputBytes = 0;
const allocationSizes = new Map();

function checkedRange(rawPointer, rawLength, description) {
  const pointer = Number(rawPointer) >>> 0;
  const length = Number(rawLength) >>> 0;
  const end = pointer + length;
  if (!Number.isSafeInteger(end) || end > memory.buffer.byteLength) {
    throw new Error(`URI browser ${description} escaped linear memory: ${pointer}+${length}`);
  }
  return { pointer, length, end };
}

function allocate(rawLength) {
  const length = Math.max(Number(rawLength) >>> 0, 1);
  if (!Number.isSafeInteger(length) || length > MAX_ALLOCATION_BYTES) {
    throw new Error(`URI browser allocation exceeds ${MAX_ALLOCATION_BYTES}: ${length}`);
  }
  const pointer = Math.ceil(heapCursor / 16) * 16;
  const end = pointer + length;
  if (!Number.isSafeInteger(end)) throw new Error("URI browser allocation address overflow");
  if (end > memory.buffer.byteLength) {
    const growth = Math.ceil((end - memory.buffer.byteLength) / 65536);
    if (memory.buffer.byteLength / 65536 + growth > MAX_MEMORY_PAGES) {
      throw new Error(`URI browser memory exceeds ${MAX_MEMORY_PAGES} pages`);
    }
    memory.grow(growth);
  }
  heapCursor = end;
  allocationSizes.set(pointer, length);
  return pointer;
}

function reallocate(rawPointer, rawLength) {
  const pointer = Number(rawPointer) >>> 0;
  const length = Math.max(Number(rawLength) >>> 0, 1);
  const previousLength = allocationSizes.get(pointer) ?? 0;
  if (pointer !== 0 && previousLength >= length) return pointer;
  const replacement = allocate(length);
  const copyLength = Math.min(previousLength, length);
  if (pointer !== 0 && copyLength > 0) {
    new Uint8Array(memory.buffer, replacement, copyLength)
      .set(new Uint8Array(memory.buffer, pointer, copyLength));
  }
  return replacement;
}

const instance = await WebAssembly.instantiate(module, {
  env: {
    sollang_browser_alloc: allocate,
    sollang_browser_realloc: reallocate,
    memset(pointer, value, length) {
      const range = checkedRange(pointer, length, "memset");
      new Uint8Array(memory.buffer, range.pointer, range.length).fill(value & 0xff);
      return range.pointer;
    },
    memcpy(destination, source, length) {
      const target = checkedRange(destination, length, "memcpy destination");
      const origin = checkedRange(source, length, "memcpy source");
      new Uint8Array(memory.buffer, target.pointer, target.length)
        .set(new Uint8Array(memory.buffer, origin.pointer, origin.length));
      return target.pointer;
    },
    sollang_browser_write(pointer, length) {
      const range = checkedRange(pointer, length, "write");
      if (outputBytes + range.length > MAX_OUTPUT_BYTES) {
        throw new Error(`URI browser output exceeds ${MAX_OUTPUT_BYTES} bytes`);
      }
      outputBytes += range.length;
      chunks.push(new Uint8Array(memory.buffer.slice(range.pointer, range.end)));
      return 1;
    },
    sollang_browser_panic(pointer, length) {
      const range = checkedRange(pointer, length, "panic");
      throw new Error(`URI browser panic: ${decoder.decode(new Uint8Array(memory.buffer, range.pointer, range.length))}`);
    }
  }
});

memory = instance.exports.memory;
if (!(memory instanceof WebAssembly.Memory) || typeof instance.exports.sollang_start !== "function") {
  throw new Error("URI browser program must export memory and sollang_start");
}
if (memory.buffer.byteLength / 65536 > MAX_MEMORY_PAGES) {
  throw new Error(`URI browser initial memory exceeds ${MAX_MEMORY_PAGES} pages`);
}
heapCursor = memory.buffer.byteLength;
const exitCode = instance.exports.sollang_start();
const actual = chunks.map(chunk => decoder.decode(chunk, { stream: true })).join("")
  + decoder.decode();
const expected = fs.readFileSync(expectedPath, "utf8");
function normalizeExactProgramOutput(text) {
  const normalized = text.replaceAll("\r\n", "\n");
  return normalized.endsWith("\n") ? normalized.slice(0, -1) : normalized;
}
const normalizedActual = normalizeExactProgramOutput(actual);
const normalizedExpected = normalizeExactProgramOutput(expected);
if (exitCode !== 0 || normalizedActual !== normalizedExpected) {
  throw new Error(`URI browser output mismatch: exit=${exitCode}\nexpected:\n${expected}\nactual:\n${actual}`);
}

console.log(JSON.stringify({
  status: "passed",
  outputBytes,
  imports: importNames.sort()
}));
