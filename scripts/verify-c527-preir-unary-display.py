#!/usr/bin/env python3
"""Compare C# and SLG unary interpolation display on one pinned compiler build."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANAGED_PROOFS = (
    ROOT / "artifacts/scratch/c527-unary-display-managed-first-20260929-02/result.json",
    ROOT / "artifacts/scratch/c527-direct-display-managed-first-20260929-01/result.json",
)
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
    compiler = build / "compiler.exe"
    built = json.loads((build / "result.json").read_text(encoding="utf-8"))
    if built["status"] != "passed" or not built["inputsStable"] or built["compilerSha256"] != sha(compiler):
        raise ValueError("focused build is not a stable pass")
    unary, direct = [json.loads(path.read_text(encoding="utf-8")) for path in MANAGED_PROOFS]
    if any(proof["status"] != "passed" or not proof["inputStable"] for proof in (unary, direct)):
        raise ValueError("C# first proof is not complete")
    cases = dict(unary["cases"])
    cases["nominalControl"] = direct["cases"]["nominal"]
    source = SOURCE.read_text(encoding="utf-8-sig")
    pre_ir = source.split("public preIrInvalidDirectDisplayTypeByNode prepared:", 1)[1].split(
        "public invalidDisplayTypeByNode prepared:", 1)[0]
    direct_type = source.split("preIrDirectTypeId prepared:", 1)[1].split(
        "preIrDirectBinaryTypeId prepared:", 1)[0] if "preIrDirectTypeId prepared:" in source else ""
    inline_unary = "node.kind == 2 and nodeIndex! < (bindingFacts.interpolationUnaryTypeByNode -> len)" in pre_ir
    delegated_unary = ("node.kind == 2 and nodeIndex < (bindingFacts.interpolationUnaryTypeByNode -> len)" in direct_type
                       and "prepared -> preIrDirectTypeId(bindingFacts, memberTypes, nodeIndex!)" in pre_ir)
    if not (inline_unary or delegated_unary):
        raise ValueError("unary semantic type is not consumed before Typed IR")
    inputs = [SOURCE, compiler, build / "result.json", Path(__file__).resolve(), *MANAGED_PROOFS]
    inputs += [ROOT / case["source"] for case in cases.values()]
    before = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    results = {}
    for key, expected in cases.items():
        case_dir = output / key
        case_dir.mkdir()
        exe = case_dir / "probe.exe"
        build_exit = run([str(compiler), "build", expected["source"], "-o", str(exe),
                          "--target", "windows-x64", "--llvm", ".tools/llvm-22.1.8",
                          "--stdlib", "stdlib", "-O1"],
                         case_dir / "build.stdout.txt", case_dir / "build.stderr.txt")
        stderr = contents(case_dir / "build.stderr.txt")
        run_exit = None
        stdout = None
        if build_exit == 0:
            run_exit = run([str(exe)], case_dir / "run.stdout.txt", case_dir / "run.stderr.txt")
            stdout = contents(case_dir / "run.stdout.txt")
        passed = ((build_exit != 0) == (expected["buildExit"] != 0)
                  and stderr == expected["buildStderr"]
                  and (build_exit != 0 or (run_exit == 0 and stdout == expected["runStdout"])))
        results[key] = {"status": "passed" if passed else "failed", "buildExit": build_exit,
                        "buildStderr": stderr, "runExit": run_exit, "runStdout": stdout}
        print(f"{key}: {'PASS' if passed else 'FAIL'}", flush=True)
    stable = before == {str(path): sha(path) for path in inputs}
    completed = sum(case["status"] == "passed" for case in results.values())
    result = {"schemaVersion": 1, "unit": "C527 unary root pre-IR displayability",
              "status": "passed" if completed == len(results) and stable else "failed",
              "completed": completed, "total": len(results), "inputStable": stable,
              "compilerSha256": sha(compiler), "inputSha256": before, "cases": results}
    (output / "result.json").write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    if result["status"] != "passed":
        raise ValueError(f"paired unary display behavior failed: {completed}/{len(results)}")


if __name__ == "__main__":
    main()
