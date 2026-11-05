import fs from "node:fs";
import { parseArgs } from "node:util";

const { values: options, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    "write-status": { type: "string", default: "1" },
    "expected-exit": { type: "string", default: "0" }
  }
});
const [wasmPath, expectedPath, inputPath] = positionals;
if (!wasmPath || !expectedPath || positionals.length > 3) {
  throw new Error("usage: verify-browser-program.mjs <program.wasm> <expected.txt> [input.txt] [--write-status int32] [--expected-exit int32]");
}
function int32Option(name) {
  const text = options[name];
  const value = Number(text);
  if (!/^-?(0|[1-9]\d*)$/.test(text) || !Number.isInteger(value) || value < -2147483648 || value > 2147483647) {
    throw new Error(`invalid --${name}: expected an Int32`);
  }
  return value;
}
const writeStatus = int32Option("write-status");
const expectedExit = int32Option("expected-exit");

const decoder = new TextDecoder();
const chunks = [];
const encoder = new TextEncoder();
const inputLines = inputPath
  ? fs.readFileSync(inputPath, "utf8").replace(/\r\n?/g, "\n").split("\n")
  : [];
let inputLine = 0;
let memory;
let heapCursor = 0;
const allocationSizes = new Map();

function allocate(rawLength) {
  const length = Math.max(Number(rawLength), 1);
  const pointer = Math.ceil(heapCursor / 16) * 16;
  const end = pointer + length;
  if (end > memory.buffer.byteLength) {
    memory.grow(Math.ceil((end - memory.buffer.byteLength) / 65536));
  }
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

const { instance } = await WebAssembly.instantiate(fs.readFileSync(wasmPath), {
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
    sollang_browser_source_count: () => 0,
    sollang_browser_source_pointer: () => 0,
    sollang_browser_source_length: () => 0,
    sollang_browser_read(pointer, capacity) {
      if (inputLine >= inputLines.length || capacity <= 0) return 0;
      const line = encoder.encode(`${inputLines[inputLine++]}\n`);
      const length = Math.min(line.byteLength, capacity);
      new Uint8Array(memory.buffer, pointer, length).set(line.subarray(0, length));
      return length;
    },
    sollang_browser_write(pointer, length) {
      if (writeStatus !== 0) {
        chunks.push(new Uint8Array(memory.buffer.slice(pointer, pointer + length)));
      }
      return writeStatus;
    },
    sollang_browser_eprint(pointer, length) {
      process.stderr.write(decoder.decode(new Uint8Array(memory.buffer, pointer, length)));
      return 1;
    },
    sollang_browser_panic(pointer, length) {
      const message = decoder.decode(new Uint8Array(memory.buffer, pointer, length));
      throw new Error(`browser program panic: ${message}`);
    }
  }
});

memory = instance.exports.memory;
heapCursor = memory.buffer.byteLength;
const exitCode = instance.exports.sollang_start();
const actual = chunks.map(chunk => decoder.decode(chunk, { stream: true })).join("")
  + decoder.decode();
const expected = fs.readFileSync(expectedPath, "utf8").replaceAll("\r\n", "\n");
const normalizedActual = actual.replaceAll("\r\n", "\n").replace(/\n+$/, "");
const normalizedExpected = expected.replace(/\n+$/, "");

if (exitCode !== expectedExit || normalizedActual !== normalizedExpected) {
  throw new Error(
    `browser program mismatch: exit=${exitCode}\n`
    + `expected:\n${expected}\nactual:\n${actual}`
  );
}

console.log(`PASS browser program: ${actual.length} output characters`);
