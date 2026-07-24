import { chromium } from "playwright-core";
import { mkdir } from "node:fs/promises";

const baseUrl = process.env.SOLLANG_PLAYGROUND_URL ?? "http://127.0.0.1:3210";
const browser = await chromium.launch({
  executablePath: "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
  headless: true
});

try {
  const page = await browser.newPage({ viewport: { width: 1440, height: 1080 } });
  page.on("console", message => console.log(`[browser:${message.type()}] ${message.text()}`));
  page.on("pageerror", error => console.error(`[browser:error] ${error.stack ?? error.message}`));
  page.on("response", response => {
    if (!response.ok()) console.error(`[browser:http] ${response.status()} ${response.url()}`);
  });
  await page.goto(baseUrl, { waitUntil: "networkidle" });
  await page.getByText("WASM 준비됨").waitFor({ timeout: 60_000 });

  const sampleOutputs = [
    ["hello", "Hello from Sollang!"],
    ["flow", "결과 = 158"],
    ["struct", "거리의 제곱 = 25"],
    ["loop", "fib = 13"],
    ["sensor-stream", "10억 개 중 54개만 검사"],
    ["nested-stream", "scanned=7"],
    ["risk-stream", "scanned=9"]
  ];
  for (const [sample, expected] of sampleOutputs) {
    await page.locator("#sample").selectOption(sample);
    await page.getByRole("button", { name: /실행/ }).click();
    await page.locator(".result-ok, .result-error").waitFor({ timeout: 120_000 });
    if (await page.locator(".result-error").isVisible()) {
      throw new Error(`${sample} browser compilation failed: ${await page.locator(".terminal").innerText()}`);
    }
    await page.locator(".terminal pre").getByText(expected, { exact: false }).waitFor();
  }

  await page.locator("#sample").selectOption("hello");
  await page.locator(".monaco-editor .view-lines").click();
  await page.keyboard.press(process.platform === "darwin" ? "Meta+A" : "Control+A");
  await page.keyboard.insertText('main {\n    "브라우저 편집 성공" -> println\n}');
  await page.getByRole("button", { name: /실행/ }).click();
  await page.getByText("브라우저 편집 성공", { exact: true }).waitFor();

  const tokenColors = await page.locator(".view-lines span[class*='mtk']").evaluateAll(
    nodes => new Set(nodes.map(node => getComputedStyle(node).color)).size
  );
  if (tokenColors < 3) {
    throw new Error(`expected syntax highlighting colors, got ${tokenColors}`);
  }

  await mkdir("artifacts/browser", { recursive: true });
  await page.screenshot({ path: "artifacts/browser/playground-desktop.png", fullPage: true });
  await page.setViewportSize({ width: 390, height: 844 });
  await page.screenshot({ path: "artifacts/browser/playground-mobile.png", fullPage: true });
  console.log(`PASS browser playground (${tokenColors} syntax colors)`);
} finally {
  await browser.close();
}
