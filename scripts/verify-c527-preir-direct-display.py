#!/usr/bin/env python3
"""Compare focused SLG direct interpolation decisions with pinned C# behavior."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROOF = ROOT / "artifacts/scratch/c527-direct-display-managed-first-20260929-01/result.json"
SOURCE = ROOT / "selfhost/semantic/interpolation_inference.slg"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def run(command: list[str], stdout: Path, stderr: Path) -> int:
    with stdout.open("wb") as out, stderr.open("wb") as err:
        return subprocess.run(command, cwd=ROOT, stdout=out, stderr=err, check=False).returncode


def contents(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    build, output = args.build.resolve(), args.output.resolve()
    if output.exists():
        raise ValueError(f"proof output exists: {output}")
    build_result = json.loads((build / "result.json").read_text(encoding="utf-8"))
    compiler = build / "compiler.exe"
    if build_result["status"] != "passed" or not build_result["inputsStable"] or build_result["compilerSha256"] != sha(compiler):
        raise ValueError("focused compiler build is not a stable pass")
    managed = json.loads(PROOF.read_text(encoding="utf-8"))
    if managed["status"] != "passed" or not managed["inputStable"]:
        raise ValueError("C# first proof is not complete")
    source = SOURCE.read_text(encoding="utf-8-sig")
    pre_ir = source.split("public preIrInvalidDirectDisplayTypeByNode prepared:", 1)[1].split(
        "public invalidDisplayTypeByNode prepared:", 1)[0]
    direct_type = source.split("preIrDirectTypeId prepared:", 1)[1].split(
        "preIrDirectBinaryTypeId prepared:", 1)[0] if "preIrDirectTypeId prepared:" in source else ""
    inline_direct = "node.kind == 14" in pre_ir and "node.kind == 0" in pre_ir
    delegated_direct = ("node.kind == 14" in direct_type and "node.kind == 0" in direct_type
                        and "prepared -> preIrDirectTypeId(bindingFacts, memberTypes, nodeIndex!)" in pre_ir)
    if not (inline_direct or delegated_direct):
        raise ValueError("direct nominal and float decisions did not move before Typed IR")
    inputs = [PROOF, SOURCE, compiler, build / "result.json", Path(__file__).resolve()]
    for case in managed["cases"].values():
        inputs.append(ROOT / case["source"])
    before = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    cases = {}
    for key, expected in managed["cases"].items():
        case_dir = output / key
        case_dir.mkdir()
        exe = case_dir / "probe.exe"
        command = [str(compiler), "build", expected["source"], "-o", str(exe),
                   "--target", "windows-x64", "--llvm", ".tools/llvm-22.1.8",
                   "--stdlib", "stdlib", "-O1"]
        build_exit = run(command, case_dir / "build.stdout.txt", case_dir / "build.stderr.txt")
        stderr = contents(case_dir / "build.stderr.txt")
        run_exit = None
        stdout = None
        if build_exit == 0:
            run_exit = run([str(exe)], case_dir / "run.stdout.txt", case_dir / "run.stderr.txt")
            stdout = contents(case_dir / "run.stdout.txt")
        passed = ((build_exit != 0) == (expected["buildExit"] != 0)
                  and stderr == expected["buildStderr"]
                  and (build_exit != 0 or (run_exit == 0 and stdout == expected["runStdout"])))
        cases[key] = {"status": "passed" if passed else "failed", "buildExit": build_exit,
                      "buildStderr": stderr, "runExit": run_exit, "runStdout": stdout}
        print(f"{key}: {'PASS' if passed else 'FAIL'}", flush=True)
    stable = before == {str(path): sha(path) for path in inputs}
    completed = sum(case["status"] == "passed" for case in cases.values())
    result = {"schemaVersion": 1, "unit": "C527 direct nominal and float pre-IR displayability",
              "status": "passed" if completed == len(cases) and stable else "failed",
              "completed": completed, "total": len(cases), "inputStable": stable,
              "compilerSha256": sha(compiler), "inputSha256": before,
              "sourceDecision": "Direct nominal and floating literal types are classified before Typed IR; later diagnostics retain C# initializer error precedence.",
              "cases": cases}
    (output / "result.json").write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    if result["status"] != "passed":
        raise ValueError(f"paired direct display behavior failed: {completed}/{len(cases)}")


if __name__ == "__main__":
    main()
