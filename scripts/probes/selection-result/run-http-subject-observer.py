"""Observe the pinned HTTP enum subject failure without claiming gate completion."""
import argparse
import hashlib
import json
import re
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts"))
from verification_execution import VerificationExecution
from verification_fingerprints import managed_runtime_inputs
from completed_artifact_plan import initialize_output


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def validate_trace_source(source):
    if re.search(r"\$[A-Za-z_]\w*!", source):
        raise ValueError("HTTP_SUBJECT_OBSERVER_MUTABLE_INTERPOLATION_REQUIRES_PARENTHESES")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    stdlib = sorted((ROOT / "stdlib").rglob("*.slg"))
    if len(stdlib) <= 66 or stdlib[66] != ROOT / "stdlib/std/net/http/client.slg":
        raise ValueError("HTTP_SUBJECT_OBSERVER_SOURCE_ORDER_CHANGED")
    if output.exists():
        raise ValueError("HTTP_SUBJECT_OBSERVER_FRESH_OUTPUT_REQUIRED")
    compiler = ROOT / "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe"
    manifest = ROOT / "tests/Sollang.ExampleTests/Fixtures/selfhost-sollangc-driver.sources.txt"
    compiler_sources = [ROOT / line.strip() for line in manifest.read_text().splitlines()
                        if line.strip() and not line.strip().endswith("selfhost-sollangc-driver.slg")]
    helper = Path(__file__).with_name("http-subject-observer.slg")
    validate_trace_source(helper.read_text(encoding="utf-8-sig"))
    for path in [helper, manifest, *compiler_sources, *managed_runtime_inputs(compiler)]:
        if not path.is_file():
            raise ValueError("HTTP_SUBJECT_OBSERVER_INPUT_MISSING: " + str(path))
    initialize_output(ROOT, output)
    output.mkdir(parents=True)
    probe = output / "active-probe.slg"
    probe.write_bytes(b"main {}\n")
    driver = output / "driver.slg"
    paths = [probe, *stdlib]
    source = ('import sollang.compiler.llvm.text as observer\nmain {\n    [Text; ~] => paths!\n'
              + "".join("    paths! -> push(" + json.dumps(path.as_posix()) + ")\n" for path in paths)
              + "    paths! -> observer.traceHttpSubject\n}\n")
    driver.write_bytes(source.encode("utf-8"))
    sources = [driver, helper, *compiler_sources]
    inputs = list(dict.fromkeys([*sources, probe, *stdlib, manifest, Path(__file__).resolve(),
                                *managed_runtime_inputs(compiler)]))
    pins = {str(path): sha(path) for path in inputs}
    stable = lambda: all(path.is_file() and sha(path) == pins[str(path)] for path in inputs)
    result = {"schemaVersion": 1, "status": "running", "inputHashes": pins,
              "scope": "HTTP subject AST and IR observation only; no native parity completion"}
    runner = VerificationExecution(ROOT, output, result, stable, sha)
    error = None
    try:
        build = runner.run([str(compiler), "build", *map(str, sources), "-o", str(output / "observer.exe"),
                            "--target", "windows-x64", "--llvm", str(ROOT / ".tools/llvm-22.1.8"),
                            "--keep-temps"], output / "build", 600)
        if build.returncode or build.stderr.strip():
            raise ValueError("HTTP_SUBJECT_OBSERVER_BUILD_FAILED")
        run = runner.run([str(output / "observer.exe")], output / "run", 180)
        if run.returncode or run.stderr.strip():
            raise ValueError("HTTP_SUBJECT_OBSERVER_RUN_FAILED")
        result["status"] = "observed"
        print(run.stdout)
    except BaseException as exc:
        error = exc
        raise
    finally:
        runner.finalize(error)


if __name__ == "__main__":
    main()
