import crypto from "node:crypto";
import fs from "node:fs";

const wasmPath = process.argv[2];
const expectedPath = process.argv[3];
if (!wasmPath || !expectedPath) {
  throw new Error("usage: verify-time-browser-program.mjs <program.wasm> <expected.txt>");
}

const bytes = fs.readFileSync(wasmPath);
const module = new WebAssembly.Module(bytes);
const imports = WebAssembly.Module.imports(module).map(item => `${item.module}:${item.name}`);
const allowedImports = new Set([
  "env:sollang_browser_alloc",
  "env:sollang_browser_realloc",
  "env:memset",
  "env:memcpy",
  "env:sollang_browser_write",
  "env:sollang_browser_panic",
  "env:sollang_browser_now_millis",
  "env:sollang_browser_utc_now_millis"
]);
if (new Set(imports).size !== imports.length || imports.some(item => !allowedImports.has(item))) {
  throw new Error(`browser import set escaped the clock probe allowlist: ${imports.join(",")}`);
}
for (const required of ["env:sollang_browser_now_millis", "env:sollang_browser_utc_now_millis"]) {
  if (!imports.includes(required)) throw new Error(`browser clock import is missing: ${required}`);
}

const decoder = new TextDecoder();
const chunks = [];
let memory;
let heapCursor = 0;
const allocationSizes = new Map();

function allocate(rawLength) {
  const length = Math.max(Number(rawLength), 1);
  const pointer = Math.ceil(heapCursor / 16) * 16;
  const end = pointer + length;
  if (end > memory.buffer.byteLength) memory.grow(Math.ceil((end - memory.buffer.byteLength) / 65536));
  heapCursor = end;
  allocationSizes.set(pointer, length);
  return pointer;
}

function reallocate(rawPointer, rawLength) {
  const pointer = Number(rawPointer) >>> 0;
  const length = Math.max(Number(rawLength), 1);
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

const { instance } = await WebAssembly.instantiate(module, {
  env: {
    sollang_browser_alloc: allocate,
    sollang_browser_realloc: reallocate,
    memset(pointer, value, length) {
      new Uint8Array(memory.buffer, pointer, length).fill(value & 0xff);
      return pointer;
    },
    memcpy(destination, source, length) {
      new Uint8Array(memory.buffer, destination, length)
        .set(new Uint8Array(memory.buffer, source, length));
      return destination;
    },
    sollang_browser_now_millis: () => BigInt(Math.trunc(performance.now())),
    sollang_browser_utc_now_millis: () => BigInt(Date.now()),
    sollang_browser_write(pointer, length) {
      chunks.push(new Uint8Array(memory.buffer.slice(pointer, pointer + length)));
      return 1;
    },
    sollang_browser_panic(pointer, length) {
      process.stderr.write(decoder.decode(new Uint8Array(memory.buffer, pointer, length)));
      return 1;
    }
  }
});

memory = instance.exports.memory;
heapCursor = memory.buffer.byteLength;
const exitCode = instance.exports.sollang_start();
const actual = chunks.map(chunk => decoder.decode(chunk, { stream: true })).join("") + decoder.decode();
const expected = fs.readFileSync(expectedPath, "utf8");
const normalize = value => value.replaceAll("\r\n", "\n").replace(/\n+$/, "");
if (exitCode !== 0 || normalize(actual) !== normalize(expected)) {
  throw new Error(`browser clock output mismatch: exit=${exitCode}\nexpected:\n${expected}\nactual:\n${actual}`);
}

const sha256 = value => crypto.createHash("sha256").update(value, "utf8").digest("hex").toUpperCase();
console.log(JSON.stringify({
  status: "passed",
  exitCode,
  exactOutput: normalize(actual),
  stdoutSha256: sha256(normalize(actual)),
  imports
}));
