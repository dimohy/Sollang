import { chromium } from "playwright-core";
import { mkdir, readFile } from "node:fs/promises";

const baseUrl = process.env.SOLLANG_PLAYGROUND_URL ?? "http://127.0.0.1:3210";
const implicitTableSource = await readFile(
  new URL("./Sollang.ExampleTests/Fixtures/browser-stage2-implicit-main-multiplication-table.slg", import.meta.url),
  "utf8"
);
const implicitTableOutput = await readFile(
  new URL("./Sollang.ExampleTests/Fixtures/browser-stage2-implicit-main-multiplication-table.stdout.txt", import.meta.url),
  "utf8"
);
const implicitDefaultEachSource = await readFile(
  new URL("../examples/regression/846-implicit-main-default-each-print.slg", import.meta.url),
  "utf8"
);
const implicitDefaultEachOutput = await readFile(
  new URL("../examples/regression/expected/846-implicit-main-default-each-print.stdout.txt", import.meta.url),
  "utf8"
);
const inclusiveAndHalfOpenEachSource = await readFile(
  new URL("../examples/regression/847-inclusive-and-half-open-each.slg", import.meta.url),
  "utf8"
);
const inclusiveAndHalfOpenEachOutput = await readFile(
  new URL("../examples/regression/expected/847-inclusive-and-half-open-each.stdout.txt", import.meta.url),
  "utf8"
);
const barePrintlnSource = await readFile(
  new URL("../examples/regression/diagnostics/848-bare-println-expression.slg", import.meta.url),
  "utf8"
);
const unterminatedPrintlnSource = await readFile(
  new URL("../examples/regression/diagnostics/849-unterminated-flow-println.slg", import.meta.url),
  "utf8"
);
const printlnCallTableSource = await readFile(
  new URL("../examples/regression/575-multiplication-table.slg", import.meta.url),
  "utf8"
);
const printlnCallTableOutput = await readFile(
  new URL("../examples/regression/expected/575-multiplication-table.stdout.txt", import.meta.url),
  "utf8"
);
const browser = await chromium.launch({
  executablePath: "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
  headless: true
});

async function openLocalizedPage(locale, readyText) {
  const context = await browser.newContext({
    locale,
    viewport: { width: 1440, height: 1080 }
  });
  const page = await context.newPage();
  page.on("console", message => console.log(`[browser:${message.type()}] ${message.text()}`));
  page.on("pageerror", error => console.error(`[browser:error] ${error.stack ?? error.message}`));
  page.on("response", response => {
    if (!response.ok()) console.error(`[browser:http] ${response.status()} ${response.url()}`);
  });
  await page.goto(baseUrl, { waitUntil: "networkidle" });
  await page.getByText(readyText).waitFor({ timeout: 60_000 });
  return { context, page };
}

try {
  const { context: englishContext, page } = await openLocalizedPage("en-US", "WASM ready");
  if (await page.locator("html").getAttribute("lang") !== "en") {
    throw new Error("English browser locale did not set html[lang=en].");
  }

  const sampleIds = await page.locator("#sample option").evaluateAll(
    options => options.map(option => option.value)
  );
  const expectedSampleIds = [
    "hello", "main-block", "arithmetic", "input", "flow", "local-functions",
    "loop", "when", "each-repeat", "custom-block", "fold", "containers",
    "immutable-containers", "compile-time-collections", "struct",
    "mutable-method", "enum", "traits-generics", "numeric-widths",
    "associated-types", "value-generics", "result-propagation", "async-await",
    "dynamic-trait", "effects", "readonly-references", "ownership",
    "raw-strings", "sensor-stream", "nested-stream", "risk-stream",
    "flow-junction-tour", "flow-branch", "flow-branch-order", "flow-tap",
    "flow-parallel-branch", "labeled-product", "ordinary-product",
    "stream-partition", "stream-zip", "stream-merge", "stream-concat-latest"
  ];
  const expectedSampleOutputs = {
    hello: "Hello from Sollang!\nValues flow from left to right.",
    "main-block": "Sollang says square = 49",
    arithmetic: "Arithmetic is correct.",
    input: "First number: Second number: Sum = 42",
    flow: "Result = 158",
    "local-functions": "Local function result = 21",
    loop: "fib = 0\nfib = 1\nfib = 1\nfib = 2\nfib = 3\nfib = 5\nfib = 8\nfib = 13",
    when: "Grade B\nwhen completed",
    "each-repeat": "Range item\nRange item\nRange item",
    "custom-block": "notify invoked its user block",
    fold: "Sum from 1 to 100 = 5050",
    containers: "count = 3, sum = 6",
    "immutable-containers": "immutable values count = 3, sum = 14",
    "compile-time-collections": "collection count = 5, sum = 15",
    struct: "Distance squared = 25",
    "mutable-method": "counter = 42",
    enum: "value = 42, number\nmissing = missing\nlabel = sensor",
    "traits-generics": "trait-ready point measure = 42",
    "numeric-widths": "Int8 = 42, UInt16 = 42",
    "associated-types": "Associated-type source = 42",
    "value-generics": "value-generic input = 7",
    "result-propagation": "matched result value = 42",
    "async-await": "Async values = 36, 42",
    "dynamic-trait": "dynamic sounds = 11, 22",
    effects: "Effect sets are checked transitively.",
    "readonly-references": "Readonly-reference value = 41",
    ownership: "moved owned point total = 42",
    "raw-strings": "first \"quoted\" line\nC:\\raw\\path\ninline \"quotes\" and C:\\raw",
    "sensor-stream": "Alert 1: sensor 7 = 59 C\nAlert 2: sensor 14 = 58 C\nAlert 3: sensor 21 = 57 C\nAlert 4: sensor 47 = 59 C\nAlert 5: sensor 54 = 58 C\nStopped after scanning 54 of 1 billion values",
    "nested-stream": "14\n15\n16\n17\nScanned = 7",
    "risk-stream": "Warning: transaction 5, total 1250\nWarning: transaction 6, total 1650\nWarning: transaction 7, total 1750\nWarning: transaction 8, total 1900\nWarning: transaction 9, total 2100\nScanned = 9",
    "flow-junction-tour": "audit=19\nresult=19",
    "flow-branch": "16",
    "flow-branch-order": "first\nsecond\n22",
    "flow-tap": "side=18\n10",
    "labeled-product": "left=4, right=2, total=42",
    "ordinary-product": "60",
    "stream-partition": "other=1\neven=2\nlarge=3\neven=4\nlarge=5\neven=6",
    "stream-zip": "1+10\n2+11\n3+12",
    "stream-merge": "1\n10\n2\n11\n3\n12",
    "stream-concat-latest": "concat=1\nconcat=2\nconcat=4\nconcat=5\nlatest=1+10\nlatest=2+10\nlatest=2+11\nlatest=2+12"
  };
  const expectedSampleDiagnostics = {
    "flow-parallel-branch": "parallel execution is unavailable on wasm32-browser because the target does not provide a compute worker pool"
  };
  if (JSON.stringify(sampleIds) !== JSON.stringify(expectedSampleIds)) {
    throw new Error(
      `syntax catalog mismatch\nexpected ${JSON.stringify(expectedSampleIds)}\nactual   ${JSON.stringify(sampleIds)}`
    );
  }

  const longEditorSource = [
    "main {",
    ...Array.from({ length: 120 }, (_, index) =>
      `    # scroll verification line ${index + 1}`),
    '    "scroll verification" -> println',
    "}"
  ].join("\n");
  await page.locator(".monaco-editor").evaluate((node, source) => {
    window.monaco.editor.getModels()[0]?.setValue(source);
    window.monaco.editor.getEditors()[0]?.setScrollTop(0);
    node.scrollIntoView({ block: "center" });
  }, longEditorSource);
  await page.locator(".monaco-editor").hover();
  await page.mouse.wheel(0, 480);
  await page.waitForFunction(() =>
    (window.monaco.editor.getEditors()[0]?.getScrollTop() ?? 0) > 0
  );
  const wheelScrollTop = await page.locator(".monaco-editor").evaluate(() =>
    window.monaco.editor.getEditors()[0]?.getScrollTop() ?? 0
  );
  await page.locator(".monaco-editor").evaluate(node => {
    const editor = window.monaco.editor.getEditors()[0];
    editor?.setScrollTop(0);
    const touch = clientY => new Touch({
      identifier: 1,
      target: node,
      clientX: 120,
      clientY,
      pageX: 120,
      pageY: clientY,
      screenX: 120,
      screenY: clientY
    });
    node.dispatchEvent(new TouchEvent("touchstart", {
      bubbles: true,
      cancelable: true,
      touches: [touch(420)],
      targetTouches: [touch(420)],
      changedTouches: [touch(420)]
    }));
    node.dispatchEvent(new TouchEvent("touchmove", {
      bubbles: true,
      cancelable: true,
      touches: [touch(180)],
      targetTouches: [touch(180)],
      changedTouches: [touch(180)]
    }));
  });
  const touchScrollTop = await page.locator(".monaco-editor").evaluate(() =>
    window.monaco.editor.getEditors()[0]?.getScrollTop() ?? 0
  );
  if (wheelScrollTop <= 0 || touchScrollTop <= 0) {
    throw new Error(
      `editor scrolling failed: wheel=${wheelScrollTop}, touch=${touchScrollTop}`
    );
  }
  await page.locator("#sample").selectOption("hello");

  const whileTokens = await page.locator(".monaco-editor").evaluate(() =>
    window.monaco.editor.tokenize("count! < 8 -> while {", "sollang")[0]
  );
  if (!whileTokens.some(token => token.offset === 14 && token.type.includes("keyword"))) {
    throw new Error(`while was not highlighted as a keyword: ${JSON.stringify(whileTokens)}`);
  }
  const rangeTokens = await page.locator(".monaco-editor").evaluate(() =>
    window.monaco.editor.tokenize("2..9 2..<10", "sollang")[0]
  );
  const highlightedRanges = rangeTokens.filter(token => token.type.includes("operator.range"));
  if (highlightedRanges.length !== 2 || highlightedRanges[0].offset !== 1 || highlightedRanges[1].offset !== 6) {
    throw new Error(`inclusive and half-open ranges do not share range styling: ${JSON.stringify(rangeTokens)}`);
  }
  await page.locator("#sample").selectOption("loop");
  await page.screenshot({
    path: "artifacts/browser/playground-while-keyword.png",
    fullPage: true
  });

  const sampleFailures = [];
  const sampleOutputs = {};
  let previousSource = await page.locator(".monaco-editor").evaluate(() =>
    window.monaco.editor.getModels()[0]?.getValue() ?? ""
  );
  for (const sampleId of sampleIds) {
    await page.locator("#sample").selectOption(sampleId);
    await page.waitForFunction(
      source => window.monaco.editor.getModels()[0]?.getValue() !== source,
      previousSource
    );
    const source = await page.locator(".monaco-editor").evaluate(() => {
      const monacoApi = window.monaco;
      return monacoApi?.editor.getModels()[0]?.getValue() ?? "";
    });
    previousSource = source;
    if (!source || /[가-힣]/u.test(source)) {
      throw new Error(`${sampleId} source is missing or is not English-only.`);
    }

    await page.getByRole("button", { name: /^Run/ }).click();
    await page.locator(".result-ok, .result-error").waitFor({ timeout: 120_000 });
    const expectedDiagnostic = expectedSampleDiagnostics[sampleId];
    if (await page.locator(".result-error").isVisible()) {
      const diagnostic = (await page.locator(".terminal").innerText()).replace(/\s+/g, " ").trim();
      if (!expectedDiagnostic || !diagnostic.toLowerCase().includes(expectedDiagnostic)) {
        sampleFailures.push(`${sampleId}: ${diagnostic}`);
      }
    } else {
      const output = (await page.locator(".terminal pre").innerText()).replace(/\r\n?/g, "\n").trimEnd();
      sampleOutputs[sampleId] = output;
      if (expectedDiagnostic) {
        sampleFailures.push(`${sampleId}: expected target capability diagnostic but execution succeeded`);
      } else if (!output.trim()) {
        sampleFailures.push(`${sampleId}: execution succeeded without observable output`);
      } else if (output !== expectedSampleOutputs[sampleId]) {
        sampleFailures.push(
          `${sampleId}: stdout mismatch\nexpected ${JSON.stringify(expectedSampleOutputs[sampleId])}\nactual   ${JSON.stringify(output)}`
        );
      }
    }
  }
  if (process.env.SOLLANG_DUMP_SAMPLE_OUTPUTS === "1") {
    console.log(JSON.stringify(sampleOutputs, null, 2));
  }
  if (sampleFailures.length > 0) {
    throw new Error(`browser sample failures:\n${sampleFailures.join("\n")}`);
  }

  await page.locator("#sample").selectOption("input");
  if (await page.locator("#stdin").inputValue() !== "12\n30") {
    throw new Error("Input sample did not populate stdin.");
  }
  await page.getByRole("button", { name: /^Run/ }).click();
  await page.getByText("Sum = 42", { exact: false }).waitFor({ timeout: 120_000 });

  await page.locator("#sample").selectOption("hello");
  await page.locator(".monaco-editor .view-lines").click();
  await page.keyboard.press(process.platform === "darwin" ? "Meta+A" : "Control+A");
  await page.keyboard.insertText('main {\n    "Browser edit succeeded." -> println\n}');
  await page.getByRole("button", { name: /^Run/ }).click();
  await page.getByText("Browser edit succeeded.", { exact: true }).waitFor();

  await page.locator(".monaco-editor .view-lines").click();
  await page.keyboard.press(process.platform === "darwin" ? "Meta+A" : "Control+A");
  await page.keyboard.insertText('"test" -> println');
  await page.getByRole("button", { name: /^Run/ }).click();
  await page.waitForFunction(() =>
    document.querySelector(".terminal pre")?.textContent === "test\n"
  , undefined, { timeout: 120_000 });

  await page.locator(".monaco-editor .view-lines").click();
  await page.keyboard.press(process.platform === "darwin" ? "Meta+A" : "Control+A");
  await page.keyboard.insertText(implicitTableSource);
  await page.getByRole("button", { name: /^Run/ }).click();
  await page.waitForFunction(expected =>
    document.querySelector(".terminal pre")?.textContent === expected
  , implicitTableOutput, { timeout: 120_000 });

  await page.locator(".monaco-editor .view-lines").click();
  await page.keyboard.press(process.platform === "darwin" ? "Meta+A" : "Control+A");
  await page.keyboard.insertText(implicitDefaultEachSource);
  await page.getByRole("button", { name: /^Run/ }).click();
  await page.waitForFunction(expected =>
    document.querySelector(".terminal pre")?.textContent === expected
  , implicitDefaultEachOutput, { timeout: 120_000 });

  await page.locator(".monaco-editor .view-lines").click();
  await page.keyboard.press(process.platform === "darwin" ? "Meta+A" : "Control+A");
  await page.keyboard.insertText(inclusiveAndHalfOpenEachSource);
  await page.getByRole("button", { name: /^Run/ }).click();
  await page.waitForFunction(expected =>
    document.querySelector(".terminal pre")?.textContent === expected
  , inclusiveAndHalfOpenEachOutput, { timeout: 120_000 });

  await page.locator(".monaco-editor .view-lines").click();
  await page.keyboard.press(process.platform === "darwin" ? "Meta+A" : "Control+A");
  await page.keyboard.insertText('main {\n    "shortcut" -> println\n}');
  await page.keyboard.press(process.platform === "darwin" ? "Meta+Enter" : "Control+Enter");
  await page.waitForFunction(() =>
    document.querySelector(".terminal pre")?.textContent === "shortcut\n"
  , undefined, { timeout: 120_000 });

  await page.locator(".monaco-editor .view-lines").click();
  await page.keyboard.press(process.platform === "darwin" ? "Meta+A" : "Control+A");
  await page.keyboard.insertText(
    'main {\n'
    + '    "dimohy" => dimohy\n'
    + '    "$dimohySuffix" -> println\n'
    + '}'
  );
  await page.getByRole("button", { name: /^Run/ }).click();
  await page.locator(".result-error").waitFor({ timeout: 120_000 });
  const interpolationDiagnostic = await page.locator(".terminal pre").innerText();
  if (
    !interpolationDiagnostic.includes("Unknown interpolation binding 'dimohySuffix'")
    || !interpolationDiagnostic.includes("'$(dimohy)Suffix'")
    || interpolationDiagnostic.includes("FS error")
  ) {
    throw new Error(`unfriendly English interpolation diagnostic: ${interpolationDiagnostic}`);
  }

  await page.locator(".monaco-editor .view-lines").click();
  await page.keyboard.press(process.platform === "darwin" ? "Meta+A" : "Control+A");
  await page.keyboard.insertText(
    'main {\n'
    + '    "Values flow from left to right." -> println2\n'
    + '}'
  );
  await page.getByRole("button", { name: /^Run/ }).click();
  await page.locator(".result-error").waitFor({ timeout: 120_000 });
  const unresolvedCallDiagnostic = await page.locator(".terminal pre").innerText();
  if (
    !unresolvedCallDiagnostic.includes("Unknown function call 'println2'")
    || unresolvedCallDiagnostic.includes("FS error")
  ) {
    throw new Error(`missing English unresolved-call diagnostic: ${unresolvedCallDiagnostic}`);
  }

  await page.locator(".monaco-editor .view-lines").click();
  await page.keyboard.press(process.platform === "darwin" ? "Meta+A" : "Control+A");
  await page.keyboard.insertText(barePrintlnSource);
  await page.getByRole("button", { name: /^Run/ }).click();
  await page.locator(".result-error").waitFor({ timeout: 120_000 });
  const barePrintlnDiagnostic = await page.locator(".terminal pre").innerText();
  if (!barePrintlnDiagnostic.includes("function 'println' expects an argument and must use call or flow syntax")) {
    throw new Error(`missing bare-function diagnostic: ${barePrintlnDiagnostic}`);
  }

  await page.locator(".monaco-editor .view-lines").click();
  await page.keyboard.press(process.platform === "darwin" ? "Meta+A" : "Control+A");
  await page.keyboard.insertText(unterminatedPrintlnSource);
  await page.getByRole("button", { name: /^Run/ }).click();
  await page.waitForFunction(() =>
    document.querySelector(".terminal pre")?.textContent?.includes("unterminated string literal")
  , undefined, { timeout: 120_000 });

  await page.locator(".monaco-editor .view-lines").click();
  await page.keyboard.press(process.platform === "darwin" ? "Meta+A" : "Control+A");
  await page.keyboard.insertText(printlnCallTableSource);
  await page.getByRole("button", { name: /^Run/ }).click();
  await page.waitForFunction(expected =>
    document.querySelector(".terminal pre")?.textContent === expected
  , printlnCallTableOutput, { timeout: 120_000 });

  const tokenColors = await page.locator(".view-lines span[class*='mtk']").evaluateAll(
    nodes => new Set(nodes.map(node => getComputedStyle(node).color)).size
  );
  if (tokenColors < 3) {
    throw new Error(`expected syntax highlighting colors, got ${tokenColors}`);
  }

  await mkdir("artifacts/browser", { recursive: true });
  await page.screenshot({ path: "artifacts/browser/playground-desktop.png", fullPage: true });
  await page.setViewportSize({ width: 390, height: 844 });
  const mobileLayout = await page.locator(".site-shell").evaluate(shell => {
    const intro = shell.querySelector(".intro")?.getBoundingClientRect();
    const workbench = shell.querySelector(".workbench")?.getBoundingClientRect();
    const footer = shell.querySelector("footer")?.getBoundingClientRect();
    return {
      introTop: intro?.top ?? -1,
      workbenchBottom: workbench?.bottom ?? -1,
      footerBottom: footer?.bottom ?? -1
    };
  });
  if (
    mobileLayout.introTop < mobileLayout.workbenchBottom
    || mobileLayout.introTop < mobileLayout.footerBottom
  ) {
    throw new Error(`mobile intro was not placed at the page bottom: ${JSON.stringify(mobileLayout)}`);
  }
  await page.screenshot({ path: "artifacts/browser/playground-mobile.png", fullPage: true });
  await englishContext.close();

  for (const [locale, readyText, htmlLang, localizedLabel, localizedSampleTitle] of [
    ["ko-KR", "WASM 준비됨", "ko", "입력 (stdin)", "인사와 문자열 보간"],
    ["ja-JP", "WASM 準備完了", "ja", "入力 (stdin)", "挨拶と文字列補間"],
    ["zh-CN", "WASM 已就绪", "zh", "输入 (stdin)", "问候与字符串插值"]
  ]) {
    const { context, page: localizedPage } = await openLocalizedPage(locale, readyText);
    if (await localizedPage.locator("html").getAttribute("lang") !== htmlLang) {
      throw new Error(`${locale} did not set html[lang=${htmlLang}].`);
    }
    await localizedPage.getByText(localizedLabel, { exact: true }).waitFor();
    if (await localizedPage.locator("#sample option:checked").innerText() !== localizedSampleTitle) {
      throw new Error(`${locale} did not localize sample titles.`);
    }
    await context.close();
  }

  console.log(
    `PASS browser playground (${sampleIds.length} samples, 4 locales, `
    + `${tokenColors} syntax colors, wheel=${wheelScrollTop}, touch=${touchScrollTop})`
  );
} finally {
  await browser.close();
}
