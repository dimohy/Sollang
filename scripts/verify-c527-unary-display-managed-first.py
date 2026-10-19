#!/usr/bin/env python3
"""Prove C# unary interpolation display and error precedence before SLG changes."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
COMPILER = ROOT / "src/Sollang.Compiler/bin/Release/net11.0/Sollang.Compiler.exe"
MANAGED = ROOT / "src/Sollang.Compiler/Semantics/SemanticCompiler.cs"
SELFHOST = ROOT / "selfhost/semantic/interpolation_inference.slg"
CASES = {
    "float": ("c527-unary-float-display.slg", "string interpolation expects Text, Int, or Bool but received Float", None),
    "bool": ("c527-unary-bool-display.slg", None, "value=false\n"),
    "invalidOperand": ("c527-unary-invalid-operand.slg", "'not' expects Bool", None),
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def run(command: list[str], stdout: Path, stderr: Path) -> int:
    with stdout.open("wb") as out, stderr.open("wb") as err:
        return subprocess.run(command, cwd=ROOT, stdout=out, stderr=err, check=False).returncode


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        raise ValueError(f"proof output exists: {output}")
    managed = MANAGED.read_text(encoding="utf-8-sig")
    selfhost = SELFHOST.read_text(encoding="utf-8-sig")
    if managed.index("var interpolationType = InferExpression(") >= managed.index("EnsureDisplayable(interpolationType, expression.Line"):
        raise ValueError("C# semantic decision order drift")
    pre_ir = selfhost.split("public preIrInvalidDirectDisplayTypeByNode prepared:", 1)[1].split(
        "public invalidDisplayTypeByNode prepared:", 1)[0]
    if "node.kind == 2" in pre_ir:
        raise ValueError("unary display already has a pre-IR decision")
    inputs = [COMPILER, MANAGED, SELFHOST, Path(__file__).resolve()]
    inputs += [ROOT / "scripts/probes/interpolation" / name for name, _, _ in CASES.values()]
    before = {str(path): sha(path) for path in inputs}
    output.mkdir(parents=True)
    cases = {}
    for key, (name, expected_error, expected_run) in CASES.items():
        case_dir = output / key
        case_dir.mkdir()
        exe = case_dir / "probe.exe"
        source = ROOT / "scripts/probes/interpolation" / name
        build_exit = run([str(COMPILER), "build", str(source), "-o", str(exe),
                          "--target", "windows-x64"],
                         case_dir / "build.stdout.txt", case_dir / "build.stderr.txt")
        stderr = (case_dir / "build.stderr.txt").read_text(encoding="utf-8-sig").replace("\r\n", "\n")
        run_exit = None
        stdout = None
        if build_exit == 0:
            run_exit = run([str(exe)], case_dir / "run.stdout.txt", case_dir / "run.stderr.txt")
            stdout = (case_dir / "run.stdout.txt").read_text(encoding="utf-8-sig").replace("\r\n", "\n")
        passed = (expected_error in stderr if expected_error else build_exit == 0 and run_exit == 0 and stdout == expected_run)
        cases[key] = {"status": "passed" if passed else "failed", "source": str(source.relative_to(ROOT)),
                      "buildExit": build_exit, "buildStderr": stderr, "runExit": run_exit,
                      "runStdout": stdout}
        print(f"{key}: {'PASS' if passed else 'FAIL'}", flush=True)
    stable = before == {str(path): sha(path) for path in inputs}
    completed = sum(case["status"] == "passed" for case in cases.values())
    result = {"schemaVersion": 1, "unit": "C527 unary interpolation display C# first and source comparison",
              "status": "passed" if completed == len(CASES) and stable else "failed",
              "completed": completed, "total": len(CASES), "inputStable": stable,
              "inputSha256": before,
              "sourceComparison": "C# validates unary operand then checks the inferred root display type; SLG has pre-IR unary type facts but currently uses them for display only after Typed IR.",
              "cases": cases}
    (output / "result.json").write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    if result["status"] != "passed":
        raise ValueError(f"C# unary focused proof failed: {completed}/{len(CASES)}")


if __name__ == "__main__":
    main()
