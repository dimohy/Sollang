#!/usr/bin/env python3
"""Check a pre-IR lexical display decision and its paired user behavior."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
POSITIVE = ROOT / "examples/regression/1827-interpolation-bool-displayable.slg"
NEGATIVE = ROOT / "examples/regression/diagnostics/interpolation-float-not-displayable.slg"
SOURCE_ORDER = ROOT / "artifacts/scratch/c527-semantic-source-order-20260929-01.json"
EXPECTED_POSITIVE = "flag=true\n"
EXPECTED_NEGATIVE = (
    "sollang: semantic error at 3:5: [module '<main>'] "
    "string interpolation expects Text, Int, or Bool but received Float\n"
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def run(name: str, command: list[str], output: Path, timeout: int = 180) -> dict:
    result = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=timeout, check=False)
    (output / f"{name}.stdout.txt").write_bytes(result.stdout)
    (output / f"{name}.stderr.txt").write_bytes(result.stderr)
    return {
        "exitCode": result.returncode,
        "stdout": result.stdout.decode("utf-8", errors="replace").replace("\r\n", "\n"),
        "stderr": result.stderr.decode("utf-8", errors="replace").replace("\r\n", "\n"),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--managed", required=True, type=Path)
    parser.add_argument("--selfhost", required=True, type=Path)
    parser.add_argument("--selfhost-build-result", required=True, type=Path)
    parser.add_argument("--probe", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise ValueError(f"output already exists: {output}")
    managed = args.managed.resolve(strict=True)
    selfhost = args.selfhost.resolve(strict=True)
    probe = args.probe.resolve(strict=True)
    build_result = json.loads(args.selfhost_build_result.read_text(encoding="utf-8"))
    source_order = json.loads(SOURCE_ORDER.read_text(encoding="utf-8"))
    if build_result["status"] != "passed" or not build_result["inputsStable"]:
        raise ValueError("selfhost compiler build is not stable and passed")
    if build_result["compilerSha256"] != sha256(selfhost):
        raise ValueError("selfhost compiler hash differs from its build result")
    if source_order["status"] != "passed":
        raise ValueError("C527 source order is unverified")
    for relative, expected in source_order["sourceSha256"].items():
        if sha256(ROOT / relative) != expected:
            raise ValueError(f"source order proof drifted: {relative}")

    inputs = [managed, selfhost, probe, POSITIVE, NEGATIVE, SOURCE_ORDER, Path(__file__).resolve()]
    start_hashes = {str(path): sha256(path) for path in inputs}
    output.mkdir(parents=True)
    probe_run = run("preir-probe", [str(probe)], output)
    runs = {"preIrProbe": {"exitCode": probe_run["exitCode"], "stdout": probe_run["stdout"]}}
    for name, compiler in (("managed", managed), ("selfhost", selfhost)):
        executable = output / f"{name}-positive.exe"
        command = [str(compiler), "build", str(POSITIVE), "-o", str(executable), "--target", "windows-x64"]
        if name == "selfhost":
            command += ["--llvm", str(ROOT / ".tools/llvm-22.1.8"), "-O1", "--stdlib", str(ROOT / "stdlib")]
        positive_build = run(f"{name}-positive-build", command, output)
        positive_native = run(f"{name}-positive-native", [str(executable)], output) if positive_build["exitCode"] == 0 and executable.is_file() else None
        negative_executable = output / f"{name}-negative.exe"
        negative_command = [str(compiler), "build", str(NEGATIVE), "-o", str(negative_executable), "--target", "windows-x64"]
        if name == "selfhost":
            negative_command += ["--llvm", str(ROOT / ".tools/llvm-22.1.8"), "-O1", "--stdlib", str(ROOT / "stdlib")]
        negative_build = run(f"{name}-negative-build", negative_command, output)
        runs[name] = {
            "positiveBuildExit": positive_build["exitCode"],
            "positiveNativeExit": None if positive_native is None else positive_native["exitCode"],
            "positiveStdout": None if positive_native is None else positive_native["stdout"],
            "negativeBuildExit": negative_build["exitCode"],
            "negativeStderr": negative_build["stderr"],
        }
        if positive_build["stderr"] or negative_build["stdout"] or negative_executable.exists():
            raise ValueError(f"unexpected compiler output or negative executable: {name}")

    stable = start_hashes == {str(path): sha256(path) for path in inputs}
    passed = (
        stable
        and probe_run["exitCode"] == 0
        and probe_run["stdout"] == "kind=1 invalid=20\nkind=1 invalid=-1\n"
        and probe_run["stderr"] == ""
        and all(
            runs[name]["positiveBuildExit"] == 0
            and runs[name]["positiveNativeExit"] == 0
            and runs[name]["positiveStdout"] == EXPECTED_POSITIVE
            and runs[name]["negativeBuildExit"] == 1
            and runs[name]["negativeStderr"] == EXPECTED_NEGATIVE
            for name in ("managed", "selfhost")
        )
    )
    record = {
        "schemaVersion": 1,
        "unit": "C527-direct-lexical-builtin-displayability-before-Typed-IR",
        "status": "passed" if passed else "failed",
        "completed": 1 if passed else 0,
        "total": 1,
        "inputStable": stable,
        "inputSha256": start_hashes,
        "selfhostBuildResult": str(args.selfhost_build_result.resolve()),
        "sourceOrderProof": str(SOURCE_ORDER),
        "runs": runs,
        "fullPreIrExpressionClosure": False,
        "structuralPhasesClosed": "0/7",
    }
    (output / "result.json").write_text(json.dumps(record, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    if not passed:
        raise ValueError(f"focused C527 verification failed: {output / 'result.json'}")
    print(f"PASS {output / 'result.json'}: pre-IR probe 1/1, paired positive 2/2, exact negative 2/2")


if __name__ == "__main__":
    main()
