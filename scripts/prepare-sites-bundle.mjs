import { access, copyFile, mkdir } from "node:fs/promises";

async function ensureJavaScriptEntry(path) {
  try {
    await access(`${path}.js`);
  } catch {
    await copyFile(`${path}.mjs`, `${path}.js`);
  }
}

await ensureJavaScriptEntry("dist/server/index");
await ensureJavaScriptEntry("dist/server/ssr/index");
await mkdir("dist/.openai", { recursive: true });
await copyFile(".openai/hosting.json", "dist/.openai/hosting.json");
