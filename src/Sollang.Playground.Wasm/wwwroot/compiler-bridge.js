let ready = false;

async function boot() {
  try {
    await Blazor.start();
    ready = true;
    window.parent.postMessage({ type: "sollang-compiler-ready" }, window.location.origin);
  } catch (error) {
    window.parent.postMessage({
      type: "sollang-compiler-failed",
      message: error instanceof Error ? error.message : String(error)
    }, window.location.origin);
  }
}

window.addEventListener("message", async event => {
  if (event.origin !== window.location.origin || event.data?.type !== "sollang-compile-run") {
    return;
  }

  const id = event.data.id;
  if (!ready) {
    window.parent.postMessage({
      type: "sollang-compile-result",
      id,
      result: JSON.stringify({
        success: false,
        output: "",
        diagnostics: "sollang: compiler runtime is still loading",
        compileMilliseconds: 0,
        executeMilliseconds: 0
      })
    }, window.location.origin);
    return;
  }

  try {
    const result = await DotNet.invokeMethodAsync(
      "Sollang.Playground.Wasm",
      "CompileAndRun",
      event.data.source
    );
    window.parent.postMessage({ type: "sollang-compile-result", id, result }, window.location.origin);
  } catch (error) {
    window.parent.postMessage({
      type: "sollang-compile-result",
      id,
      result: JSON.stringify({
        success: false,
        output: "",
        diagnostics: `sollang: ${error instanceof Error ? error.message : String(error)}`,
        compileMilliseconds: 0,
        executeMilliseconds: 0
      })
    }, window.location.origin);
  }
});

boot();
