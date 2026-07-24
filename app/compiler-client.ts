export type CompilerResult = {
  success: boolean;
  output: string;
  diagnostics: string;
  compileMilliseconds: number;
  executeMilliseconds: number;
};

const decoder = new TextDecoder("utf-8");
const encoder = new TextEncoder();
let stage2BytesPromise: Promise<ArrayBuffer> | undefined;
type StandardLibrarySource = {
  namespace: string;
  source: string;
};

let standardLibraryPromise: Promise<StandardLibrarySource[]> | undefined;
const toolBinaryPromises = new Map<string, Promise<ArrayBuffer>>();
let toolManifestPromise: Promise<Record<string, string[]>> | undefined;

type ToolModule = {
  FS: {
    writeFile(path: string, data: string | Uint8Array): void;
    readFile(path: string): Uint8Array;
  };
  callMain(arguments_: string[]): Promise<void> | void;
};

type ToolFactory = (options?: Record<string, unknown>) => Promise<ToolModule>;

export function preloadStage2(): Promise<ArrayBuffer> {
  stage2BytesPromise ??= fetch("/sollangc-stage2-0.2.260723.wasm").then(response => {
    if (!response.ok) {
      throw new Error(`Stage2 WASM을 불러오지 못했습니다 (${response.status})`);
    }
    return response.arrayBuffer();
  });
  return stage2BytesPromise;
}

function loadStandardLibrary(): Promise<StandardLibrarySource[]> {
  standardLibraryPromise ??= fetch("/stdlib-0.2.260723.json").then(async response => {
    if (!response.ok) {
      throw new Error(`표준 라이브러리를 불러오지 못했습니다 (${response.status})`);
    }
    return await response.json() as StandardLibrarySource[];
  });
  return standardLibraryPromise;
}

function importedNamespaces(source: string): string[] {
  return [...source.matchAll(/^\s*import\s+([A-Za-z_][A-Za-z0-9_.]*)/gm)]
    .map(match => match[1]);
}

function selectStandardLibrary(
  source: string,
  library: StandardLibrarySource[]
): StandardLibrarySource[] {
  const byNamespace = new Map(library.map(entry => [entry.namespace, entry]));
  const selected: StandardLibrarySource[] = [];
  const visited = new Set<string>();
  const pending = importedNamespaces(source);
  while (pending.length > 0) {
    const namespace = pending.shift()!;
    if (visited.has(namespace)) continue;
    visited.add(namespace);
    const entry = byNamespace.get(namespace);
    if (!entry) continue;
    selected.push(entry);
    pending.push(...importedNamespaces(entry.source));
  }
  return selected;
}

function loadToolBinary(url: string): Promise<ArrayBuffer> {
  let pending = toolBinaryPromises.get(url);
  if (!pending) {
    pending = fetch(url).then(response => {
      if (!response.ok) throw new Error(`${url}을 불러오지 못했습니다 (${response.status})`);
      return response.arrayBuffer();
    });
    toolBinaryPromises.set(url, pending);
  }
  return pending;
}

function loadChunkedToolBinary(toolName: string): Promise<ArrayBuffer> {
  const cacheKey = `chunks:${toolName}`;
  let pending = toolBinaryPromises.get(cacheKey);
  if (!pending) {
    toolManifestPromise ??= fetch("/llvm-16/tools.json").then(async response => {
      if (!response.ok) {
        throw new Error(`LLVM 도구 목록을 불러오지 못했습니다 (${response.status})`);
      }
      return await response.json() as Record<string, string[]>;
    });
    pending = toolManifestPromise.then(async manifest => {
      const partNames = manifest[toolName];
      if (!partNames?.length) throw new Error(`${toolName} LLVM 도구 조각이 없습니다`);
      const parts = await Promise.all(
        partNames.map(name => loadToolBinary(`/llvm-16/${name}`))
      );
      const byteLength = parts.reduce((total, part) => total + part.byteLength, 0);
      const merged = new Uint8Array(byteLength);
      let offset = 0;
      for (const part of parts) {
        merged.set(new Uint8Array(part), offset);
        offset += part.byteLength;
      }
      return merged.buffer;
    });
    toolBinaryPromises.set(cacheKey, pending);
  }
  return pending;
}

async function compileWithStage2(source: string): Promise<string> {
  const library = selectStandardLibrary(source, await loadStandardLibrary());
  const sourceBuffers = [source, ...library.map(entry => entry.source)]
    .map(value => encoder.encode(value));
  const outputChunks: Uint8Array[] = [];
  let memory: WebAssembly.Memory;
  let heapCursor = 0;
  const sourcePointers: number[] = [];
  const allocationSizes = new Map<number, number>();

  const sizeClass = (rawLength: bigint | number) => {
    const requested = Math.max(Number(rawLength), 1);
    let blockSize = 16;
    while (blockSize < requested) blockSize *= 2;
    return blockSize;
  };

  const allocate = (rawLength: bigint | number) => {
    const byteLength = Number(rawLength) === 0 ? 1024 : sizeClass(rawLength);
    const pointer = Math.ceil(heapCursor / 16) * 16;
    const end = pointer + byteLength;
    if (end > memory.buffer.byteLength) {
      memory.grow(Math.ceil((end - memory.buffer.byteLength) / 65536));
    }
    heapCursor = end;
    allocationSizes.set(pointer, byteLength);
    return pointer;
  };

  const reallocate = (oldPointer: number, rawLength: bigint | number) => {
    const normalizedOldPointer = oldPointer >>> 0;
    const oldLength = allocationSizes.get(normalizedOldPointer) ?? 0;
    const newLength = sizeClass(rawLength);
    if (normalizedOldPointer !== 0 && oldLength >= newLength) {
      return normalizedOldPointer;
    }
    const newPointer = allocate(newLength);
    const copyLength = Math.min(oldLength, Number(rawLength));
    if (normalizedOldPointer !== 0 && copyLength > 0) {
      new Uint8Array(memory.buffer, newPointer, copyLength)
        .set(new Uint8Array(memory.buffer, normalizedOldPointer, copyLength));
    }
    return newPointer;
  };

  const imports = {
    env: {
      sollang_browser_alloc: allocate,
      sollang_browser_realloc: reallocate,
      sollang_browser_now_millis: () => BigInt(Math.trunc(performance.now())),
      sollang_browser_source_count: () => sourceBuffers.length,
      sollang_browser_source_pointer: (index: number) => sourcePointers[index],
      sollang_browser_source_length: (index: number) => sourceBuffers[index].byteLength,
      sollang_browser_write: (pointer: number, length: number) => {
        outputChunks.push(new Uint8Array(memory.buffer.slice(pointer, pointer + length)));
        return 1;
      },
      sollang_browser_panic: (pointer: number, length: number) => {
        outputChunks.push(encoder.encode(
          `\n; sollang browser panic: ${decoder.decode(new Uint8Array(memory.buffer, pointer, length))}\n`
        ));
      }
    }
  };

  const { instance } = await WebAssembly.instantiate(await preloadStage2(), imports);
  memory = instance.exports.memory as WebAssembly.Memory;
  heapCursor = memory.buffer.byteLength;
  for (const buffer of sourceBuffers) {
    const pointer = Number((instance.exports.sollang_alloc as (length: bigint) => number)(
      BigInt(buffer.byteLength)
    ));
    sourcePointers.push(pointer);
    new Uint8Array(memory.buffer, pointer, buffer.byteLength).set(buffer);
  }
  const exitCode = (instance.exports.sollang_start as () => number)();
  const llvm = outputChunks.map(chunk => decoder.decode(chunk, { stream: true })).join("")
    + decoder.decode();

  if (exitCode !== 0 || !llvm.includes('target triple = "wasm32-unknown-unknown-wasm"')) {
    throw new Error(llvm.trim() || `Stage2 compiler exited ${exitCode}`);
  }
  return llvm;
}

async function lowerLlvmToWasm(llvm: string): Promise<Uint8Array> {
  const llcModuleUrl = "/llvm-16/llc.js";
  const lldModuleUrl = "/llvm-16/lld.js";
  const [{ default: createLlc }, { default: createLld }, llcBinary, lldBinary] = await Promise.all([
    import(/* @vite-ignore */ llcModuleUrl) as Promise<{ default: ToolFactory }>,
    import(/* @vite-ignore */ lldModuleUrl) as Promise<{ default: ToolFactory }>,
    loadChunkedToolBinary("llc"),
    loadChunkedToolBinary("lld")
  ]);

  const llc = await createLlc({
    noInitialRun: true,
    wasmBinary: llcBinary,
    locateFile: (file: string) => `/llvm-16/${file}`
  });
  llc.FS.writeFile("main.ll", llvm);
  await llc.callMain([
    "-mtriple=wasm32-unknown-unknown-wasm",
    "-filetype=obj",
    "main.ll",
    "-o",
    "main.o"
  ]);
  const object = llc.FS.readFile("main.o");

  const lld = await createLld({
    noInitialRun: true,
    wasmBinary: lldBinary,
    locateFile: (file: string) => `/llvm-16/${file}`
  });
  lld.FS.writeFile("main.o", object);
  await lld.callMain([
    "-flavor",
    "wasm",
    "--no-entry",
    "--export=sollang_start",
    "--export-memory",
    "--allow-undefined",
    "--gc-sections",
    "main.o",
    "-o",
    "main.wasm"
  ]);
  return lld.FS.readFile("main.wasm");
}

async function executeWasm(wasm: Uint8Array): Promise<string> {
  const chunks: Uint8Array[] = [];
  let memory: WebAssembly.Memory;
  const write = (pointer: number, length: number) => {
    chunks.push(new Uint8Array(memory.buffer.slice(pointer, pointer + length)));
  };
  const { instance } = await WebAssembly.instantiate(wasm, {
    env: {
      sollang_write: write,
      sollang_browser_write: write,
      sollang_browser_now_millis() {
        return BigInt(Math.trunc(performance.now()));
      }
    }
  });
  memory = instance.exports.memory as WebAssembly.Memory;
  const exitCode = (instance.exports.sollang_start as () => number)();
  if (exitCode !== 0) {
    throw new Error(`program exited ${exitCode}`);
  }
  return chunks.map(chunk => decoder.decode(chunk, { stream: true })).join("") + decoder.decode();
}

export async function compileAndRun(source: string): Promise<CompilerResult> {
  const compileStarted = performance.now();
  try {
    const llvm = await compileWithStage2(source);
    const wasm = await lowerLlvmToWasm(llvm);
    const compileMilliseconds = performance.now() - compileStarted;
    const executeStarted = performance.now();
    const output = await executeWasm(wasm);
    return {
      success: true,
      output,
      diagnostics: "",
      compileMilliseconds,
      executeMilliseconds: performance.now() - executeStarted
    };
  } catch (error) {
    return {
      success: false,
      output: "",
      diagnostics: error instanceof Error ? error.message : String(error),
      compileMilliseconds: performance.now() - compileStarted,
      executeMilliseconds: 0
    };
  }
}
