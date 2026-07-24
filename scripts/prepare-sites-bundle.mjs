import { spawn } from "node:child_process";
import {
  access,
  copyFile,
  mkdir,
  readFile,
  readdir,
  rm,
  writeFile
} from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

async function ensureJavaScriptEntry(path) {
  try {
    await access(`${path}.js`);
  } catch {
    await copyFile(`${path}.mjs`, `${path}.js`);
  }
}

await ensureJavaScriptEntry("dist/server/index");
await ensureJavaScriptEntry("dist/server/ssr/index");

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const previewPort = 41739;
const preview = spawn(
  process.execPath,
  [
    path.join(repoRoot, "node_modules", "vinext", "dist", "cli.js"),
    "start",
    "--host",
    "127.0.0.1",
    "--port",
    String(previewPort)
  ],
  {
    cwd: repoRoot,
    stdio: "ignore",
    windowsHide: true
  }
);

let html;
try {
  for (let attempt = 0; attempt < 100; attempt++) {
    try {
      const response = await fetch(`http://127.0.0.1:${previewPort}/`);
      if (response.ok) {
        html = await response.text();
        break;
      }
    } catch {
      // The preview server is still starting.
    }
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  if (!html) throw new Error("vinext preview did not produce the static playground HTML");
} finally {
  preview.kill();
}

const clientRoot = path.join(repoRoot, "dist", "client");
const externalLldData = path.join(clientRoot, "llvm-16", "lld.data");
await rm(externalLldData);

function contentType(filePath) {
  if (filePath.endsWith(".css")) return "text/css; charset=utf-8";
  if (filePath.endsWith(".js")) return "text/javascript; charset=utf-8";
  if (filePath.endsWith(".json")) return "application/json; charset=utf-8";
  if (filePath.endsWith(".svg")) return "image/svg+xml";
  if (filePath.endsWith(".wasm")) return "application/wasm";
  return "application/octet-stream";
}

async function collectClientAssets(directory, relative = "") {
  const entries = await readdir(directory, { withFileTypes: true });
  const assets = [];
  for (const entry of entries) {
    const relativePath = path.posix.join(relative, entry.name);
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      assets.push(...await collectClientAssets(fullPath, relativePath));
      continue;
    }
    const bytes = await readFile(fullPath);
    const textual = /\.(?:css|js|json|svg)$/.test(entry.name);
    assets.push([
      `/${relativePath}`,
      {
        contentType: contentType(entry.name),
        encoding: textual ? "text" : "base64",
        body: textual ? bytes.toString("utf8") : bytes.toString("base64")
      }
    ]);
  }
  return assets;
}

const clientAssets = Object.fromEntries(await collectClientAssets(clientRoot));
const workerSource = `
const playgroundHtml = ${JSON.stringify(html)};
const clientAssets = ${JSON.stringify(clientAssets)};

function decodeBase64(value) {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) bytes[index] = binary.charCodeAt(index);
  return bytes;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/" || url.pathname === "/index.html") {
      return new Response(playgroundHtml, {
        headers: {
          "content-type": "text/html; charset=utf-8",
          "cache-control": "public, max-age=300"
        }
      });
    }
    const asset = clientAssets[url.pathname];
    if (asset) {
      return new Response(
        asset.encoding === "base64" ? decodeBase64(asset.body) : asset.body,
        {
          headers: {
            "content-type": asset.contentType,
            "cache-control": "public, max-age=31536000, immutable"
          }
        }
      );
    }
    return new Response("Not Found", { status: 404 });
  }
};
`;
await writeFile("dist/server/index.js", workerSource, "utf8");

await mkdir("dist/.openai", { recursive: true });
await copyFile(".openai/hosting.json", "dist/.openai/hosting.json");
