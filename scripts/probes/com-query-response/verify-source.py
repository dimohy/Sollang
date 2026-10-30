"""Test actual emitted COM helper bytes in a retained failing Native module.

This source-unit experiment does not build or qualify a new Native compiler.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts"))
from completed_artifact_plan import initialize_output
from verification_execution import VerificationExecution
from verification_fingerprints import managed_compilation_inputs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--managed-compiler", type=Path, required=True)
    parser.add_argument("--managed-evidence", type=Path, required=True)
    parser.add_argument("--native-baseline", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--reusable-compiler-directory", type=Path, action="append", required=True)
    args = parser.parse_args()
    managed, output = args.managed_compiler.resolve(), args.output.resolve()
    probe, llvm = Path(__file__).resolve().parent, ROOT / ".tools/llvm-22.1.8"
    digest = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()
    previous = json.loads(args.native_baseline.read_text(encoding="utf-8-sig"))
    baseline = args.native_baseline.parent / "query.exe.ll"
    assert previous["inputsStable"] and previous["processesStopped"] and digest(baseline) == previous["llvmSha256"]
    managed_record = json.loads(args.managed_evidence.read_text(encoding="utf-8-sig"))
    assert managed_record["status"] == "passed" and managed_record["completed"] == managed_record["total"] == 3
    assert managed_record["inputsStable"] and managed_record["processesStopped"]
    for name, expected in managed_record["inputHashes"].items():
        assert digest(name) == expected, "COM_QUERY_MANAGED_INPUT_CHANGED:" + name
    wrapper = ROOT / "selfhost/llvm/text/runtime_preamble.slg"
    comparison = ROOT / "scripts/contracts/evidence/source13293/query20909-baseline/source-comparison.json"
    reviewed = json.loads(comparison.read_text(encoding="utf-8-sig"))
    assert digest(wrapper) == reviewed["sourceHashes"][str(wrapper.relative_to(ROOT)).replace("\\", "/")]
    bridge_project = ROOT / "scripts/tools/CompilerLinkBridge/CompilerLinkBridge.csproj"
    providers = [Path(__file__), comparison, baseline, args.native_baseline, args.managed_evidence,
                 wrapper, probe / "emit-runtime.slg", ROOT / "selfhost/llvm/emitter/com_runtime.slg",
                 *bridge_project.parent.glob("*.cs"), bridge_project,
                 *[llvm / "bin" / name for name in ("clang.exe", "lld-link.exe", "llvm-lib.exe", "llvm-as.exe")],
                 *[Path(name) for name in managed_record["inputHashes"]],
                 *managed_compilation_inputs(managed, ROOT / "stdlib"),
                 *list((ROOT / "scripts").glob("verification_*.py")), ROOT / "scripts/completed_artifact_plan.py"]
    pins = {str(path.resolve()): digest(path) for path in providers}
    initialize_output(ROOT, output, reusable_directories=[path.resolve() for path in args.reusable_compiler_directory])
    output.mkdir()
    stable = lambda: all(Path(path).is_file() and digest(path) == value for path, value in pins.items())
    result = dict(schemaVersion=1, status="running", completed=0, total=3, cases=[], inputHashes=pins,
                  maximumCaseSeconds=180, claimsGoalComplete=False, claimsNativeCompilerQualified=False,
                  scope="Source-unit integration: replace only query helper with exact production SLG emission; unchanged Native wrapper/module")
    execution = VerificationExecution(ROOT, output, result, stable, digest)
    started, error = time.monotonic(), None

    def run(command, label):
        remaining = 180 - (time.monotonic() - started)
        if remaining <= 0:
            raise TimeoutError("COM_QUERY_SOURCE_CASE_BUDGET_EXHAUSTED")
        return execution.run(list(map(str, command)), output / label, timeout=remaining)

    try:
        helper = output / "emitter.exe"
        done = run([managed, "build", probe / "emit-runtime.slg", ROOT / "selfhost/llvm/emitter/com_runtime.slg",
                    "-o", helper, "--target", "windows-x64", "--llvm", llvm, "--jobs", "1", "-O0"], "emitter-build")
        assert done.returncode == 0 and done.stderr == "", "COM_QUERY_SOURCE_HELPER_BUILD"
        done = run([helper], "emitter-run")
        assert done.returncode == 0 and done.stderr == "", "COM_QUERY_SOURCE_HELPER_EMIT"
        pattern = re.compile(r"^define internal \{ ptr, i32 \} @sollang_com_query\(.*?^\}", re.M | re.S)
        emitted = (output / "emitter-run.stdout").read_text(encoding="utf-8")
        original = baseline.read_text(encoding="utf-8-sig")
        assert len(pattern.findall(emitted)) == len(pattern.findall(original)) == 1, "COM_QUERY_HELPER_NOT_UNIQUE"
        replacement = pattern.search(emitted).group()
        assert "sollang_com_release" not in replacement and "effective_status" not in replacement
        patched, count = pattern.subn(lambda match: replacement, original)
        assert count == 1 and patched != original, "COM_QUERY_SOURCE_NOT_CHANGED"
        module = output / "query.ll"
        module.write_text(patched, encoding="utf-8")
        result["replacementSha256"] = hashlib.sha256(replacement.encode()).hexdigest().upper()
        result["llvmSha256"] = digest(module)
        assert run([llvm / "bin/llvm-as.exe", module, "-o", output / "query.bc"], "assemble").returncode == 0
        bridge = output / "bridge"
        done = run(["dotnet", "build", bridge_project, "-c", "Release", "-o", bridge,
                    "--artifacts-path", output / "dotnet-artifacts", "--disable-build-servers",
                    "-p:UseSharedCompilation=false", "-nodeReuse:false", "--nologo"], "bridge-build")
        assert done.returncode == 0 and done.stderr == "", "COM_QUERY_SOURCE_LINK_BRIDGE_BUILD"
        work = output / "link-work"
        work.mkdir()
        target = output / "query.exe"
        done = run(["dotnet", bridge / "CompilerLinkBridge.dll", "link-slg-main", managed.with_suffix(".dll"),
                    digest(managed.with_suffix(".dll")), llvm, module, target, work, "-O0", "1"], "link")
        assert done.returncode == 0 and done.stderr == "", "COM_QUERY_SOURCE_LINK"
        for index, expected in enumerate([case["expected"] for case in managed_record["cases"]]):
            done = run([target] + ["extra"] * index, f"run{index}")
            actual = (output / f"run{index}.stdout").read_text(encoding="utf-8")
            passed = done.returncode == 0 and actual == expected and done.stderr == ""
            result["cases"].append(dict(id=managed_record["cases"][index]["id"], passed=passed, expected=expected, actual=actual))
            result["completed"] += int(passed)
            execution.save()
        assert result["completed"] == result["total"], "COM_QUERY_SOURCE_RUNTIME_MISMATCH"
        result["status"] = "passed"
    except BaseException as caught:
        error = caught
    finally:
        execution.finalize(error, cleanup=False)
    print(json.dumps({key: result.get(key) for key in ("status", "completed", "total", "failure", "cases", "inputsStable", "processesStopped")}))
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
